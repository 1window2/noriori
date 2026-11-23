# -*- coding: utf-8 -*-
# 선택기 화면 전수 검사 (9회차 X: 연결·환승·승계 화면 이상). 렌더 도구가 낸 JSON을 읽어 역 줄마다 같은 상대 노선이 어떻게 나왔는지 본다.
#   렌더: cd packages/noriori_store && RENDER_OUT=<dir> RENDER_TODAY=<날> RENDER_JSON=1 flutter test test/audit_render_test.dart
#   검사: python3 -I tools/dev/screen_check.py <dir>/json [build]   → build/screen_check.json, 마지막 줄에 단계별 합계
# 원 DB 행 검사(비대칭·다음 역·근거 없는 다른 노드 이어짐)는 tools/audit_db.py K120–K125가 본다. 여기는 화면에 그려진 결과만 본다
import json, os, sys, collections, sqlite3
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
from lib import lohi
RJ = sys.argv[1]
B = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, 'build')
MAX = '9999-12-31'
m = sqlite3.connect(os.path.join(B, 'master.sqlite'))
nm = sqlite3.connect(os.path.join(B, 'names.sqlite'))
JA = {}
for t, i, x in nm.execute("select entity_type,entity_id,text from name where lang='ja' and line_id is null and valid_from is null"):
    JA.setdefault((t, i), x)
def nn(i): return JA.get(('node', i), i) if i else '-'
def ln(i): return JA.get(('line', i), i) if i else '-'
LIN = collections.defaultdict(set)
for line, lg in m.execute('select line_id,lineage_id from edge_attr'): LIN[line].add(lg)
ENDS = collections.defaultdict(set)
for rid, lo, hi in m.execute('select route_id,min(seq),max(seq) from route_stop where is_stop=1 or is_end_point=1 group by 1'): ENDS[rid] = {lo, hi}
F = collections.OrderedDict()
LVL = {}
def put(key, lvl, row):
    F.setdefault(key, []).append(row); LVL[key] = lvl
def ov(a, b): return (a.get('from') or '0000') < (b.get('to') or MAX) and (b.get('from') or '0000') < (a.get('to') or MAX)
def brief(cls, it, side): return (cls, it['kind'], side, it['from'], it['to'], nn(it['next']), it['gone'])
for fn in sorted(os.listdir(RJ)):
    J = json.load(open(os.path.join(RJ, fn), encoding='utf-8'))
    rid = J['route']
    for sc in J['screens']:
        date = sc['date'] or '모름'
        el = collections.defaultdict(list); node_of = {}
        for L in sc['lines']:
            t = L['t']
            if t == 'stop':
                node_of[L['seq']] = L['node']
                for g in L['transfers']:
                    for it in g['items']: el[L['seq']].append(('T', it, g['flow']))
            elif t == 'branch' and 'item' in L:
                el[L['atSeq']].append(('B', L['item'], 'up' if L['up'] else 'down'))
            elif t == 'end':
                for it in L['items']: el[L['atSeq']].append(('E', it, 'up' if L['up'] else 'down'))
        for seq, items in el.items():
            node = node_of.get(seq); base = dict(route=rid, date=date, at=nn(node))
            byline = collections.defaultdict(list)
            for cls, it, side in items:
                byline[it['line']].append((cls, it, side))
                chain = [b['line'] for b in it['before']]
                # 이관 앞 노선 사슬 (DESIGN §8.1 이관 노선 병기)
                if it['line'] in chain or len(set(chain)) < len(chain):
                    put('S03 이관 앞 노선 사슬에 같은 노선이 다시 나옴', 'err', dict(base, other=ln(it['line']), chain=[ln(x) for x in chain], ids=[rid, node, it['line'], *chain]))
                for x, y in zip(chain + [it['line']], chain[1:] + [it['line']]):
                    if x != y and LIN.get(x) and LIN.get(y) and not LIN[x] & LIN[y]:
                        put('S04 이관 앞 노선이 같은 사슬(lineage)이 아님', 'err', dict(base, before=ln(x), after=ln(y), ids=[rid, node, x, y]))
                if cls == 'T' and it['kind'] != 'transfer':
                    put('S05 환승 캡슐에 선로 연결 종류가 들어감', 'err', dict(base, other=ln(it['line']), kind=it['kind'], ids=[rid, node, it['line']]))
            for ol, xs in byline.items():
                if ol is None: continue
                T = [x for x in xs if x[0] == 'T']; K = [x for x in xs if x[0] in 'BE']
                row = dict(base, other=ln(ol), items=[brief(*x) for x in xs], ids=[rid, node, ol])
                # (a) 같은 상대가 선로 연결과 환승으로 함께. 둘 다 지나가는 X자 교차(환승① + 분기, 이 계통도 지나감)는 DESIGN §2.9 예외
                pairs = [(t, k) for t in T for k in K if ov(t[1], k[1])]
                # 끝 이어짐(직통)으로 잇는 노선의 반대 방향 환승(흐름 through, 다른 방면)은 일부러 적는 것이다(사용자 결정 2026-11-23, 唐津 唐津線 鬼塚 방면)
                bad = [(t, k) for t, k in pairs
                       if not (t[1]['flow'] == 'through' and k[1]['kind'] == 'branch' and seq not in ENDS[rid])
                       and not (t[1]['flow'] == 'through' and k[1]['kind'] == 'continue' and t[1].get('next') != k[1].get('next'))]
                if bad: put('S01 같은 역 줄에 같은 상대 노선이 선로 연결과 환승으로 같은 때 함께(X자 교차 아님)', 'err', row)
                elif T and K and not pairs: put('S02 같은 역 줄에 같은 상대 노선이 선로 연결과 환승으로 기간 이어 함께(직통 끝·시작, 확인 목록)', 'warn', row)
                # (b) 같은 상대가 두 번 이상: 환승 캡슐 둘, 같은 쪽 분기 줄 둘(같은 계통·방면), 같은 쪽 분기 줄과 끝 이어짐, 끝 이어짐 안 같은 방면 둘
                if len(T) > 1: put('S06 환승 캡슐에 같은 상대 노선이 둘 이상', 'err', row)
                by_side = collections.defaultdict(list)
                for x in K: by_side[x[2]].append(x)
                for side, ks in by_side.items():
                    Bs = [x for x in ks if x[0] == 'B']; Es = [x for x in ks if x[0] == 'E']
                    if len(Bs) > 1 and len({(x[1]['route'], x[1]['next']) for x in Bs}) < len(Bs):
                        put('S07 같은 쪽에 같은 상대 노선·같은 방면의 분기 줄이 둘 이상', 'err', row)
                    elif len(Bs) > 1:
                        put('S08 같은 쪽에 같은 상대 노선의 다른 계통·방면 분기 줄(확인 목록)', 'warn', row)
                    if Bs and Es and any(not ov(b[1], e[1]) for b in Bs for e in Es):
                        put('S09 같은 쪽에 같은 상대 노선의 분기 줄과 끝 이어짐이 기간만 나뉘어 함께', 'err', row)
                    c = collections.Counter((x[1]['next'], x[1]['terminal']) for x in Es)
                    if c and max(c.values()) > 1: put('S10 끝 이어짐 줄에 같은 노선·같은 방면이 둘 이상', 'err', row)
# ---- 10회차 G1 (S11–S15): DB에 있는데 화면에서 사라지는 것 (4회차 chubu_1-013·1-014·3-019, chugoku_shikoku_2-010)
# DB 연결 행: (계통, 순번, 상대 노선) → [(종류, 시작, 끝)]. 1950 뒤까지 이어진 것만 본다
DBL = collections.defaultdict(list)
for rid, sq, ol, kd, f_, t_ in m.execute("select route_id,seq,other_line_id,kind,valid_from,valid_to from route_link"):
    if ol is None: continue
    hi = '9999-12-31' if t_ in (None, 'ongoing') else (lohi(t_)[1] or '9999-12-31')
    if hi > '1950-01-01': DBL[(rid, sq, ol)].append((kd, f_, t_, hi))
DBN = collections.defaultdict(set)   # (계통, 순번, 상대 노선) → 그 연결의 다음 역
for rid, sq, ol, nx in m.execute("select route_id,seq,other_line_id,next_stop_node from route_link"):
    if ol is not None: DBN[(rid, sq, ol)].add(nx)
PAR = collections.defaultdict(list)
for rid, ol, a_, b_ in m.execute("select route_id,other_line_id,from_seq,to_seq from route_parallel"): PAR[(rid, ol)].append((a_, b_))
ARC = collections.Counter(r[0] for r in m.execute("select route_id from archive_stop where route_id is not null"))
for fn in sorted(os.listdir(RJ)):
    J = json.load(open(os.path.join(RJ, fn), encoding='utf-8'))
    rid = J['route']
    for sc in J['screens']:
        if sc['date'] is not None: continue
        seen = collections.defaultdict(lambda: collections.defaultdict(list))   # 순번 → 상대 노선 → [끝]
        kinds = collections.defaultdict(lambda: collections.defaultdict(set))
        hands = set(); narch = 0; seqs = set(); bands = []
        def note(sq, it, cls):
            seen[sq][it['line']].append(it['to'] or MAX); kinds[sq][it['line']].add(cls)
            for b in it['before']: seen[sq][b['line']].append(b['to'] or MAX); kinds[sq][b['line']].add('before')
        for L in sc['lines']:
            t = L['t']
            if t == 'stop':
                seqs.add(L['seq'])
                for g in L['transfers']:
                    for it in g['items']: note(L['seq'], it, 'T')
            elif t == 'branch' and 'item' in L: note(L['atSeq'], L['item'], 'B')
            elif t == 'end':
                for it in L['items']: note(L['atSeq'], it, 'E')
            elif t == 'hand': hands.add(L['line'])
            elif t == 'notice' and L.get('kind') == 'hand': bands.append(L)
            elif t == 'archive': narch += 1
        # 이관 띠(괄호)가 그리는 연결: 띠 끝 역에서 띠 안쪽으로 가는 그 노선(같은 계보) 연결. 띠 반대쪽 연결은 화면에 따로 있어야 한다
        order = [L['node'] for L in sc['lines'] if L['t'] == 'stop']
        def banded(node, ol, nxs):
            for bd in bands:
                if not (bd['line'] == ol or LIN[bd['line']] & LIN[ol]): continue
                if bd['top'] not in order or bd['bottom'] not in order: continue
                i, j = sorted((order.index(bd['top']), order.index(bd['bottom'])))
                inside = set(order[i:j + 1])
                if node not in inside: continue
                if all(nx is None or nx in inside for nx in nxs): return True
            return False
        for (r_, sq, ol), v in DBL.items():
            # 같은 노선 연결(옛 선형·지선)은 이어 그린 노선 화면이 그린다(DESIGN §8.3)
            if r_ != rid or sq not in seqs or ol in hands or ol == J['line']: continue
            if any(a_ <= sq <= b_ for a_, b_ in PAR.get((rid, ol), [])): continue
            node = next((L['node'] for L in sc['lines'] if L['t'] == 'stop' and L['seq'] == sq), None)
            if banded(node, ol, DBN[(rid, sq, ol)]): continue
            base = dict(route=rid, date='모름', at=nn(node), other=ln(ol), ids=[rid, node, ol])
            # 역마다 노선(같은 계보면 이어받은 노선)당 그날 연결 하나만 보인다(사용자 결정 2026-11-19). 같은 계보 노선이 보이면 그 노선의 연결이다
            got = seen[sq].get(ol) or [e for o2, ends in seen[sq].items() if LIN[o2] & LIN[ol] for e in ends]
            # S11 DB에 1950 뒤까지 이어진 연결 행이 있는데 날짜 모름 화면 그 역 줄에 그 노선(› 앞 노선 포함)이 없음
            if not got: put('S11 DB 연결 행의 상대 노선이 날짜 모름 화면 그 역 줄에 없음', 'err', dict(base, db=[(k, f, t) for k, f, t, _ in v])); continue
            # S15 화면에 보인 그 노선의 끝이 DB 그 키의 가장 늦은 끝보다 이름(옛 토막을 보임)
            dbmax = max(h for _, _, _, h in v); shown = max(got)
            if shown < dbmax and dbmax < MAX: put('S15 날짜 모름 화면에 보인 상대 노선 끝이 DB 그 키의 가장 늦은 끝보다 이름', 'err', dict(base, shown=shown, db=dbmax))
            elif shown < dbmax: put('S15 날짜 모름 화면에 보인 상대 노선 끝이 DB 그 키의 가장 늦은 끝보다 이름', 'err', dict(base, shown=shown, db='지금까지'))
            # S12 1950 뒤 선로 연결(이어짐·분기) 행이 있는데 그 역 줄에 선로 줄(분기·끝 이어짐)로 안 나오고 환승으로만 나옴(이관 띠 노선 제외)
            kd_ = set().union(*[kinds[sq][o2] for o2 in list(kinds[sq]) if o2 == ol or LIN[o2] & LIN[ol]])
            if any(k in ('continue', 'branch') for k, _, _, _ in v) and not (kd_ & {'B', 'E', 'before'}):
                put('S12 DB 선로 연결(이어짐·분기)이 화면에서 환승으로만 나옴', 'warn', dict(base, db=[(k, f, t) for k, f, t, _ in v]))
        # S13 열람 전용 역 행 수와 날짜 모름 화면 ○ 줄 수가 다름
        if ARC.get(rid, 0) != narch: put('S13 열람 전용 역 행 수와 화면 ○ 줄 수가 다름', 'err', dict(route=rid, db=ARC.get(rid, 0), shown=narch, ids=[rid]))
out = {k: dict(n=len(v), lvl=LVL[k], sample=v[:40], ids=sorted({i for r in v for i in r['ids'] if i})) for k, v in F.items()}
json.dump(out, open(os.path.join(B, 'screen_check.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=0)
for k, v in out.items(): print(f"{v['n']:6d} {v['lvl']:4s} {k}")
err = sum(v['n'] for v in out.values() if v['lvl'] == 'err'); warn = sum(v['n'] for v in out.values() if v['lvl'] == 'warn')
print(f'screen_check 오류 {err}건, 확인 목록 {warn}건')
