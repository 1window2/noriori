#!/usr/bin/env python3
"""근거 조사로 확정한 역 km를 구간(edge) km 보정 행으로 바꾼다.

쓰는 법: python3 -I tools/dev/apply_km_research.py <조사 결과 JSON>...

- 결과 항목 가운데 판정이 「가용」으로 시작하고 「확인 필요」가 아닌 것의 최종 km(`final_km`, 없으면 `value`)를 그 계통의 누계 km 목표로 둔다.
- 계통의 이웃 역 사이 길이가 목표와 달라지면 그 사이 edge km를 비례로 다시 나눈다(숨은 노드를 거쳐도 된다).
  이웃 역 사이에 갈래가 둘 이상(이설 병행)이면 고치지 않고 알린다.
- 같은 edge를 두 계통이 서로 다른 값으로 고치려 하면 고치지 않고 알린다.
- 확정한 역은 추정 표시(`km_estimated`)를 뗀다(`data/overrides/km_confirmed.json`).
- 보정 행은 `data/overrides/source_patch/km/research_r5.yaml`에 쓴다. 기준은 지금 빌드(build/master.sqlite)다.
  이미 그 파일의 보정이 들어간 빌드에서 다시 돌려도 앞 행은 남기고, 값이 바뀐 edge만 고친다.
"""
import collections
import json
import os
import sqlite3
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DB = sqlite3.connect(os.path.join(ROOT, 'build', 'master.sqlite'))
OUT_PATCH = os.path.join(ROOT, 'data', 'overrides', 'source_patch', 'km', 'research_r5.yaml')
OUT_CONF = os.path.join(ROOT, 'data', 'overrides', 'km_confirmed.json')


def items(path):
    d = json.load(open(path, encoding='utf-8'))
    rows = d['items'] if isinstance(d, dict) and 'items' in d else d
    return [x for x in (rows.values() if isinstance(rows, dict) else rows) if isinstance(x, dict)]


def final_km(x):
    v = x.get('final_km', x.get('value'))
    return float(v) if isinstance(v, (int, float)) or (isinstance(v, str) and v.replace('.', '', 1).isdigit()) else None


targets = {}
evidence = {}
for path in sys.argv[1:]:
    for x in items(path):
        verdict = x.get('verdict') or x.get('conclusion') or ''
        # 조사 담당이 정리한 최종 상태가 있으면 「확정」만 쓴다
        if 'final_status' in x and x['final_status'] != '확정':
            continue
        # 「공식 취급」(다른 역 구내 仮乗降場, 별도 営業キロ 없음)은 0 km 칸이 되므로 실제 위치의 추정 km를 둔다
        if not verdict.startswith('가용') or '확인 필요' in verdict or '공식 취급' in verdict or not x.get('node') or not x.get('route'):
            continue
        v = final_km(x)
        if v is None:
            continue
        targets[(x['route'], x['node'])] = v
        ev = x.get('evidence') or []
        evidence[(x['route'], x['node'])] = '; '.join(
            (e.get('src') or e.get('source') or str(e)) if isinstance(e, dict) else str(e) for e in ev
        )[:400] or x.get('calc') or ''

km = {e: k for e, k in DB.execute('select edge_id, km from edge_km')}
ends = {e: (a, b) for e, a, b in DB.execute('select id, from_node, to_node from edge')}
by_route = collections.defaultdict(list)
for r, n in targets:
    by_route[r].append(n)

new_km = {}
owner = {}
skipped = []
confirmed = []
for rid in sorted(by_route):
    st = DB.execute(
        'select node_id, km_cum, km_estimated from route_stop where route_id=? order by seq', (rid,)
    ).fetchall()
    if not st:
        skipped.append((rid, None, '계통 없음'))
        continue
    cur = [k for _, k, _ in st]
    want = list(cur)
    nodes = [n for n, _, _ in st]
    for i, n in enumerate(nodes):
        if (rid, n) in targets:
            want[i] = targets[(rid, n)]
    # 확정 역(조사 값이나 원래 확정이던 역) 사이에 남은 추정 역은 원래 상대 위치 비율대로 다시 펼친다.
    # 제자리에 두면 0 km 칸이나 거꾸로 선 순서가 생긴다(苗穂線·新大橋線). 끝 너머의 추정 역은 가까운 확정 역만큼 옮긴다
    anchor = [(rid, n) in targets or not est for n, (_, _, est) in zip(nodes, st)]
    idx = [i for i, a in enumerate(anchor) if a]
    for a, b in zip(idx, idx[1:]):
        if b - a < 2:
            continue
        span_old, span_new = cur[b] - cur[a], want[b] - want[a]
        for i in range(a + 1, b):
            ratio = (cur[i] - cur[a]) / span_old if span_old > 0 else (i - a) / (b - a)
            want[i] = round(want[a] + ratio * span_new, 3)
    if idx:
        for i in range(0, idx[0]):
            want[i] = round(cur[i] + want[idx[0]] - cur[idx[0]], 3)
        for i in range(idx[-1] + 1, len(nodes)):
            want[i] = round(cur[i] + want[idx[-1]] - cur[idx[-1]], 3)
    # 역 누계 km는 0.1 단위로 저장된다. 목표도 0.1 단위로 맞춰 구간 합과 어긋나지 않게 한다(앱 시뮬 S3).
    # 반올림하면 이웃 역과 같아지는 곳만 0.01 단위로 둔다
    r1 = [round(v, 1) for v in want]
    want = [r1[i] if (i == 0 or r1[i] - r1[i - 1] >= 0.1 - 1e-9) and (i == len(r1) - 1 or r1[i + 1] - r1[i] >= 0.1 - 1e-9) else round(want[i], 2) for i in range(len(want))]
    if any(b < a + 0.05 for a, b in zip(want, want[1:]) if True):
        skipped.append((rid, None, '목표 km가 순서대로 늘지 않거나 0.05 km 미만 칸이 생김'))
        continue
    graph = collections.defaultdict(list)
    for (e,) in DB.execute('select edge_id from route_edge where route_id=?', (rid,)):
        a, b = ends[e]
        graph[a].append((b, e))
        graph[b].append((a, e))
    stops = set(nodes)
    ok = True
    pending = {}
    for i in range(len(nodes) - 1):
        old, new = cur[i + 1] - cur[i], want[i + 1] - want[i]
        if abs(old - new) < 1e-6:
            continue
        p, q = nodes[i], nodes[i + 1]
        # 다른 역을 지나지 않는 모든 단순 갈래. 둘 이상이면 이설 병행이라 손으로 본다
        paths = []

        def walk(n, seen, path):
            if len(paths) > 1:
                return
            if n == q:
                paths.append(list(path))
                return
            for m, e in graph[n]:
                if m in seen or (m in stops and m != q):
                    continue
                seen.add(m)
                path.append(e)
                walk(m, seen, path)
                path.pop()
                seen.discard(m)

        walk(p, {p}, [])
        if len(paths) != 1:
            skipped.append((rid, f'{p}–{q}', '갈래 없음' if not paths else '이설 병행 갈래'))
            ok = False
            break
        es = paths[0]
        total = sum(km[e] for e in es)
        if total <= 0:
            share = [new] + [0.0] * (len(es) - 1)
        else:
            share = [round(km[e] * new / total, 2) for e in es]
            share[-1] = round(new - sum(share[:-1]), 2)
        for e, v in zip(es, share):
            pending[e] = v
    if not ok:
        continue
    for e, v in pending.items():
        if e in new_km and abs(new_km[e] - v) > 1e-6:
            skipped.append((rid, e, f'{owner[e]}와 값이 다름'))
            continue
        new_km[e] = v
        owner[e] = rid
    for n in by_route[rid]:
        confirmed.append({'route': rid, 'node': n, 'km': targets[(rid, n)], 'source': evidence.get((rid, n), '')})

old_rows = {}
if os.path.exists(OUT_PATCH):
    for line in open(OUT_PATCH, encoding='utf-8'):
        if line.startswith('- '):
            r = json.loads(line[2:])
            old_rows[r['edge']] = r
rows = dict(old_rows)
for e, v in sorted(new_km.items()):
    if abs(v - km[e]) > 1e-6:
        prev = old_rows[e]['why'].rsplit('(이전 ', 1)[-1].rstrip(')') if e in old_rows else km[e]
        rows[e] = {'patch': 'replace', 'edge': e, 'km': v, 'source': 'research_r5', 'why': f'{owner[e]} 근거 조사(R5 2026-11-12)로 확정한 역 km에 맞춘 구간 길이 (이전 {prev})'}
changed = sum(1 for e in rows if rows[e] is not old_rows.get(e))
rows = [rows[e] for e in sorted(rows)]
with open(OUT_PATCH, 'w', encoding='utf-8') as f:
    f.write('# 근거 조사(R5, 2026-11-12)로 확정한 역 km(끝 역·중간 역)에 맞춘 구간 길이. tools/dev/apply_km_research.py가 만든다\n')
    for r in rows:
        f.write('- ' + json.dumps(r, ensure_ascii=False) + '\n')
json.dump(sorted(confirmed, key=lambda x: (x['route'], x['node'])), open(OUT_CONF, 'w', encoding='utf-8'), ensure_ascii=False, indent=0)
print(f'목표 {len(targets)}, 계통 {len(by_route)}, 보정 행 {len(rows)}(이번에 바뀐 것 {changed}), 추정 뗌 {len(confirmed)}, 건너뜀 {len(skipped)}')
for s in skipped[:40]:
    print('  건너뜀', *s)
