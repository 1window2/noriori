"""Reference implementation of the option-A selector stitching (DESIGN §8.3), used to build the mockup.
Input: audit_render_test RENDER_DETAIL txt files (+ names.json) in <mock dir>. python3 tools/dev/stitch_mock.py <mock dir> <out json>"""
import json, re, sys, sqlite3, collections
D = sys.argv[1]; OUT = sys.argv[2]
NM = json.load(open(D + '/names.json'))
import os
REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
db = sqlite3.connect(REPO + '/build/master.sqlite')
ROUTES = {r[0]: dict(line=r[1], role=r[2]) for r in db.execute('select id,line_id,role from route')}
RNODES = collections.defaultdict(set)
for rid, nd in db.execute('select route_id,node_id from route_stop'): RNODES[rid].add(nd)
# official km of a stop on its own route, and whether that km is an estimate
RK, RKE = {}, set()
for _r, _n, _k, _e in db.execute('select route_id,node_id,km_cum,km_estimated from route_stop order by seq'):
    if (_r, _n) not in RK:
        RK[(_r, _n)] = _k
        if _e in (1, '1', True, 'true'): RKE.add((_r, _n))
RSTOP = collections.defaultdict(list)
for _r, _n, _k, _vf, _vt in db.execute('select route_id,node_id,km_cum,valid_from,valid_to from route_stop order by route_id,seq'):
    RSTOP[_r].append((_n, _k, _vf, _vt))
def _on(vf, vt, d): return (not vf or vf[:10] <= d) and (not vt or vt == 'ongoing' or d < vt[:10])
TODAY = [None]  # the newest dated screen of the example being built

def lo(v):
    if not v: return None
    v = v.strip('[]').split('..')[0]
    return v.replace('XX', '01')

def ko(node, date):
    n = NM.get(node) or {}
    if date:
        for lang, text, a, b in n.get('dated', []):
            if (not a or lo(a) <= date) and (not b or date < lo(b)): return text
    return n.get('ko') or node

def era_chain(out, date, used, P):
    """Display km = that day's 営業キロ. Chain the section distances along that day's path from the day's origin.
    A legally separate section counts from its own origin; stations before the origin go negative; a handover band
    shows the owning line's km; an estimate anywhere in the chain marks the result with '?' until the next fresh origin."""
    key = date or '모름'
    st = [i for i in out if i['t'] == 's']
    def dist(a, b):
        for r in [b.get('seg'), a.get('seg')] + sorted(used):
            if r and RK.get((r, a['node'])) is not None and RK.get((r, b['node'])) is not None:
                return abs(RK[(r, b['node'])] - RK[(r, a['node'])]), ((r, a['node']) in RKE or (r, b['node']) in RKE)
        return None, False
    def fresh(k, seg):
        st[k]['km'] = RK.get((seg, st[k]['node'])); st[k]['est'] = (seg, st[k]['node']) in RKE
        return st[k]['km'] is not None
    def live(r): return (not date) or (key in P.get(r, {}) and any(x['st'] == 'o' for x in stops(P[r][key])))
    has = lambda x: x.get('seg') and RK.get((x['seg'], x['node'])) is not None
    o = next((k for k, x in enumerate(st) if has(x) and live(x['seg'])), None)
    if o is None:  # nothing runs that day (the whole line is closed): count from the main route's origin
        o = next((k for k, x in enumerate(st) if has(x) and RK[(x['seg'], x['node'])] == 0), next((k for k, x in enumerate(st) if has(x)), None))
    if o is None: return out
    fresh(o, st[o]['seg'])
    pos = {}
    for k, x in enumerate(st): pos.setdefault(x['node'], k)
    dd = date or TODAY[0]
    def owner_km(note, x):
        for r, rows in RSTOP.items():
            if ROUTES.get(r, {}).get('line') == note.get('hline'):
                for n_, k_, vf, vt in rows:
                    if n_ == x['node'] and _on(vf, vt, dd): return k_
        return None
    inband = {}; starts = set()
    for x in out:
        if x['t'] == 'k' and x.get('kind') == 'hand' and x.get('top') in pos and x.get('bottom') in pos:
            t, b = pos[x['top']], pos[x['bottom']]
            for k in range(t + 1, b): inband[k] = x
            if b + 1 < len(st) and st[b + 1].get('seg') and st[b + 1].get('seg') != st[t].get('seg'): starts.add(b)
            else: inband[b] = x
    last = o; restart = False
    for k in range(o + 1, len(st)):
        if k in inband:
            st[k].update(km=owner_km(inband[k], st[k]), band=True, note='', est=False); restart = True; continue
        if k in starts or restart:
            restart = False
            if fresh(k, st[k + 1].get('seg') if (k in starts and k + 1 < len(st)) else st[k].get('seg')): last = k
            continue
        d, e = dist(st[last], st[k])
        if d is None: st[k]['km'] = None
        else: st[k]['km'] = round(st[last]['km'] + d, 1); st[k]['est'] = st[last].get('est') or e; last = k
    last = o
    for k in range(o - 1, -1, -1):
        d, e = dist(st[k], st[last])
        if d is None: st[k]['km'] = None
        else: st[k]['km'] = round(st[last]['km'] - d, 1); st[k]['est'] = st[last].get('est') or e; last = k
    # folds: chain from their junction on this screen, along their own path
    for fi, x in enumerate(out):
        if x['t'] != 'x': continue
        nxt = [i for i in out[fi + 1:] if i['t'] == 's'][:1]; prv = [i for i in out[:fi] if i['t'] == 's'][-1:]
        j = (nxt if x.get('up') else prv) or (prv or nxt)
        rows = [r for r in x['items'] if r['t'] == 's']
        if not j or j[0]['km'] is None:
            for r in rows: r['km'] = None
            continue
        if x.get('up'): rows = rows[::-1]
        a = j[0]
        for r in rows:
            d, e = dist(a, r)
            if d is None: r['km'] = None; continue
            r['km'] = round(a['km'] - d, 1) if x.get('up') else round(a['km'] + d, 1); r['est'] = a.get('est') or e; a = r
    return out

def lko(lid): return (NM.get(lid) or {}).get('ko') or lid

ROW = re.compile(r'^● (.*?)\[(n_[a-z0-9_]+)\] km=(\S+) 상태=(\S+)(.*)$')
LINK = re.compile(r'(.*?)\((l_[a-z0-9_]+)\)(?:@(.*?)\[(n_[a-z0-9_]+)\])?(?: 다음 (.*?)\[(n_[a-z0-9_]+)\] 끝 (.*?)\[(n_[a-z0-9_]+)\])?')

def parse(route):
    out = {}; cur = None; date = None
    for raw in open(f'{D}/{route}.txt', encoding='utf-8'):
        l = raw.rstrip('\n')
        if l.startswith('## 날짜'):
            m = re.match(r'## 날짜 (\d{4}-\d\d-\d\d|모름)', l); date = m.group(1); cur = out.setdefault(date, []); continue
        if cur is None or not l.strip(): continue
        dt = None if date == '모름' else date
        s = l.strip()
        m = ROW.match(s)
        if m:
            ja, node, km, st, rest = m.groups()
            yo = re.search(r'개업(\S+)', rest); yc = re.search(r'폐역(\S+)', rest)
            state = {'open': 'o', 'beforeOpen': 'f', 'closed': 'c', 'unknown': 'o', 'suspended': 'c'}.get(st, 'c')
            note = ''
            if state == 'f': note = f"{yo.group(1) if yo else '?'}~"
            elif state == 'c': note = f"~{yc.group(1) if yc else '?'}"
            elif st == 'unknown' and yc: note = f"~{yc.group(1)}?"
            cur.append(dict(t='s', node=node, ja=ja, ko=ko(node, dt), km=None if km == '?' else float(km), st=state,
                            sel='못고름' not in rest and state == 'o', note=note, tr=[], moved=None,
                            oy=(yo.group(1) if yo else None), cy=(yc.group(1) if yc else None)))
            continue
        if s.startswith('환승'):
            m = re.match(r'환승(?:#(\d+))?\((\w+)\): (.*)$', s)
            num, flow, body = m.groups()
            items = []
            for part in re.split(r' · ', body):
                gone = '(끝남' in part
                lm = LINK.match(re.sub(r'\{.*?\}', '', part).strip())
                if not lm or not lm.group(2): continue
                name = lko(lm.group(2)); stn = lm.group(4)
                yr = re.search(r'끝남 ~(\d{4})', part)
                items.append(dict(text=name + (f'({ko(stn, dt)})' if stn else ''), gone=gone, until=yr.group(1) if yr else None))
            if cur and cur[-1]['t'] == 's': cur[-1]['tr'].append(dict(num=int(num) if num else None, flow=flow, items=items))
            continue
        if s.startswith('이전:'):
            m = re.match(r'이전: (\S+) → (.*)$', s)
            if cur and cur[-1]['t'] == 's': cur[-1]['moved'] = f'{m.group(1)}년 {m.group(2)}(으)로 이전'
            continue
        m = re.match(r'([┌└▲▼]) (분기|끝이어짐)(?:\(병주\))? (.*)$', s)
        if m:
            sym, kind, body = m.groups(); up = sym in '┌▲'
            if body.startswith('열람전용'):
                am = re.match(r'열람전용 (.*?) ~(\S+)', body)
                cur.append(dict(t='b', up=up, name=am.group(1), arrow=None, tail='~' + am.group(2), gone=True, archive=True, line=None)); continue
            parts = []
            for part in re.split(r' · ', body):
                gone = '(끝남' in part
                lm = LINK.match(re.sub(r'\{.*?\}', '', part).strip())
                yr = re.search(r'끝남 ~(\d{4})', part)
                if not lm or not lm.group(2): continue
                parts.append(dict(line=lm.group(2), name=lko(lm.group(2)), nx=lm.group(6), term=lm.group(8), gone=gone, until=yr.group(1) if yr else None))
            if not parts: continue
            p0 = parts[0]
            nxt = ko(p0['nx'], dt) if p0['nx'] else None; trm = ko(p0['term'], dt) if p0['term'] else None
            arrow = None if not nxt else (nxt if not trm or trm == nxt else f'{nxt} › {trm}')
            allgone = all(p['gone'] for p in parts)
            it = dict(t='b' if kind == '분기' else 'e', up=up, name=p0['name'], line=p0['line'], nx=p0['nx'], arrow=arrow,
                      tail=(f"~{p0['until']}" if allgone and p0['until'] else None), gone=allgone)
            if it['t'] == 'e':
                nexts = list(dict.fromkeys(ko(p['nx'], dt) for p in parts if p['nx']))
                it['where'] = nexts[0] if len(nexts) == 1 else (('·'.join(nexts) + ' 방면') if nexts else None)
            cur.append(it); continue
        m = re.match(r'\[ 괄호 (\w+) (\S+?)~(\S+?)(?: (\S+))?(?: .*)?$', s)
        if m:
            kind, top, bot, yr = m.groups()
            it = dict(t='k', kind=kind, top=top, bottom=bot, year=yr)
            if kind == 'hand':
                hm = re.search(r'\((l_[a-z0-9_]+)\) (\d{4})-(\d\d)-(\d\d)', s)
                if hm: it.update(year=None, hline=hm.group(1), since=f'{hm.group(2)}.{int(hm.group(3))}.{int(hm.group(4))}')
            cur.append(it); continue
        m = re.match(r'○ 열람전용역 (.*?) ~(\S+)', s)
        if m:
            cur.append(dict(t='a', name=m.group(1), until=m.group(2))); continue
    return out

def notice_text(it):
    y = it.get('year') or '?'
    if it['kind'] == 'before': return f'{y}년 개업', '개업한 뒤 날짜로 기록할 수 있어요'
    if it['kind'] == 'closed': return (f'~{y} 폐지' if y != '?' else '폐지 구간'), '그 전 날짜로만 기록할 수 있어요'
    if it['kind'] == 'hand': return f"{it.get('since','?')}부터 {lko(it.get('hline'))}", '이 구간은 그 노선으로 기록돼요'
    return it['kind'], ''

def finalize(items):
    """notice: attach title/body; keep top/bottom as node ids (renderer resolves)."""
    for it in items:
        if it['t'] == 'k': it['title'], it['body'] = notice_text(it)
        if it['t'] == 'x': finalize(it['items'])
    return items

def stops(items): return [i for i in items if i['t'] == 's']

def period(rows):
    oy=[r['oy'] for r in rows if r.get('oy') and r['oy'][:4].isdigit()]; cy=[r['cy'] for r in rows if r.get('cy') and r['cy'][:4].isdigit()]
    return (min(oy)[:4] if oy else None, max(cy)[:4] if len(cy)==len(rows) and cy else None)

def built_year(route, path, close):
    """year the folded main alignment became the line's path: the later of the old alignment's close and the start of
    every edge's open period that lasts past that close (station years only as a fallback), or None"""
    built = close
    for p, q in zip(path, path[1:]):
        es = [r[0] for r in db.execute('select e.id from route_edge re join edge e on e.id=re.edge_id where re.route_id=? and ((e.from_node=? and e.to_node=?) or (e.from_node=? and e.to_node=?))', (route, p, q, q, p))]
        if not es: return None
        for e in es:
            fr = sorted(r[0] for r in db.execute("select valid_from, valid_to from edge_life where edge_id=? and coalesce(status,'')!='suspended' and valid_from is not null", (e,))
                        if close is None or not r[1] or r[1] == 'ongoing' or r[1] > close)
            if not fr: return None
            if built is None or fr[0] > built: built = fr[0]
    return built[:4] if built and built[:4].isdigit() else None

def span(rows):
    oy=[r['oy'][:4] for r in rows if r.get('oy') and r['oy'][:4].isdigit()]
    cy=[r['cy'][:4] for r in rows if r.get('cy') and r['cy'][:4].isdigit()]
    live=any(not r.get('cy') for r in rows)
    return (min(oy) if oy else '0000', '9999' if live or not cy else max(cy))
def exclusive(a, b):
    # two alignments replace each other: their active periods do not overlap (same year counts as hand-over)
    return a[1] <= b[0] or b[1] <= a[0]
CLAIMED = set()
import glob as _g
EXTRA = set()
for _f in _g.glob(REPO + '/data/source/routes/*.yaml'):
    for _l in open(_f, encoding='utf-8'):
        if '"extra": true' in _l: EXTRA.add(json.loads(_l[2:])['id'])
MAINLINE = [None]
def flip(x): return dict(x, up=(not x['up'])) if x['t'] in 'be' else dict(x)

def walk(r2items, a_node, b_node=None, same=False, fwd=None):
    """rows of r2 from a_node outward (a_node excluded), up to b_node (excluded); oriented for top-to-bottom listing in walk order"""
    keep = lambda x: x['t'] in 'sk' or (x['t'] in 'be' and (same or x.get('line') != MAINLINE[0]))
    idx = [k for k, x in enumerate(r2items) if x['t'] == 's']
    ka = next(k for k in idx if r2items[k]['node'] == a_node)
    kb = next((k for k in idx if b_node and r2items[k]['node'] == b_node), None)
    if fwd is None: fwd = (kb > ka) if kb is not None else (ka == idx[0])
    if fwd:
        return [dict(x) for x in r2items[ka + 1:kb] if keep(x)]
    lo = (kb + 1) if kb is not None else 0
    return [flip(x) for x in reversed(r2items[lo:ka]) if keep(x)]

def rebase(rows, km_a, km_a2, sign):
    return [dict(x, km=None if x['km'] is None else round(km_a + sign * abs(x['km'] - km_a2), 1)) if x['t'] == 's' else x for x in rows]

def fold_meta(rows, kind):
    st = [r for r in rows if r['t'] == 's']
    oy, cy = period(st)
    per = (f"~{cy}" if cy else '') if kind == 'old' else (f"{oy}~" if oy else '')
    return dict(per=per, nxt=st[0]['ko'] if st else '', last=st[-1]['ko'] if st else '', count=len(st))

def inner_notices(rows, first_anchor, last_anchor):
    """keep only brackets that cover part of the fold; anchors outside the fold become HEAD/TAIL"""
    nodes = [r['node'] for r in rows if r['t'] == 's']
    out = []
    for r in rows:
        if r['t'] != 'k': out.append(r); continue
        if not r.get('top') or not r.get('bottom') or r['top'] in ('HEAD','TAIL') and r['bottom'] in ('HEAD','TAIL'):
            if r.get('top') in ('HEAD',) and r.get('bottom') in nodes: pass
            elif r.get('top') in nodes and r.get('bottom') == 'TAIL': pass
            else: continue
        def pos(a):
            if a in nodes: return nodes.index(a)
            if a == 'HEAD': return -1
            if a == 'TAIL': return len(nodes)
            return len(nodes) if (last_anchor and a == last_anchor) else -1   # outside: the junction side unless it is the rejoin station
        p1, p2 = sorted((pos(r['top']), pos(r['bottom'])))
        lo, hi = max(p1, 0), min(p2, len(nodes) - 1)
        whole = (p1 < 0 and p2 >= len(nodes)) if last_anchor else (lo == 0 and hi == len(nodes) - 1)
        if whole: continue  # whole fold: the fold label already carries the period
        out.append(dict(r, top=nodes[lo] if p1 >= 0 else 'HEAD', bottom=nodes[hi] if p2 < len(nodes) else 'TAIL'))
    return out

EXCL = set()
def stitch(main_rid, date, P, excl=()):
    """One column for the line on that date (option A). excl: routes a branch chip must not take."""
    EXCL.clear(); EXCL.update(excl)
    key = date or '모름'
    line = ROUTES[main_rid]['line']; MAINLINE[0] = line
    items = [dict(i, seg=main_rid) if i['t'] == 's' else dict(i) for i in P[main_rid][key]]
    used = {main_rid}
    def free(r): return r not in used and r not in EXCL and r not in CLAIMED and r not in EXTRA and ROUTES[r]['line'] == line and key in P[r]
    def r2_of(it):
        c = [r for r in P if free(r) and it.get('nx') in RNODES[r]]
        return c[0] if c else None
    def open_on(r, d): return d in P[r] and any(x['st'] == 'o' for x in stops(P[r][d]))
    def today_of(r): return TODAY[0] if TODAY[0] in P[r] else key
    def tail_of(r2, last_node, closed):
        """a same-line section that continues r2 from its last station"""
        for x in P[r2][key]:
            if x['t'] in 'be' and x.get('line') == line and x.get('nx') not in RNODES[main_rid]:
                r3 = r2_of(x)
                if not r3: continue
                jn = next(s3['node'] for s3 in stops(P[r3][key]) if s3['node'] in RNODES[r2])
                if jn != last_node: continue  # it leaves r2 mid-way: a fold there, not a continuation
                if closed and open_on(r3, key if date else today_of(r3)): continue  # a section open that day keeps its own chip
                used.add(r3)
                return [dict(s3, seg=r3, st=('c' if closed else s3['st']), sel=(s3['sel'] and not closed)) for s3 in walk(P[r3][key], jn) if s3['t'] == 's']
        return []
    def mainidx(node): return next(k for k, x in enumerate(items) if x['t'] == 's' and x['node'] == node)
    def zero_own(r2):
        """a section with no station of its own: on its own dates it is that day's path between its ends, otherwise nothing is drawn"""
        used.add(r2)
        r2items = P[r2][key]; r2s = stops(r2items)
        ends = [x['node'] for x in r2s]
        ix = sorted(mainidx(n) for n in set(ends)); lo_, hi = ix[0], ix[-1]
        between_open = any(items[k]['t'] == 's' and items[k]['st'] == 'o' for k in range(lo_ + 1, hi))
        if not (date and len(set(ends)) >= 2 and all(x['st'] == 'o' for x in r2s) and not open_on(r2, today_of(r2)) and not between_open): return
        r2row = {x['node']: x for x in r2s}
        for k in range(lo_ + 1, hi + 1):
            if items[k]['t'] == 's': items[k] = dict(r2row.get(items[k]['node'], items[k]), st='o', sel=True, seg=r2, cy=None)
            elif items[k]['t'] == 'k' and items[k].get('kind') == 'before': items[k] = dict(items[k], drop=True)
        # the links at the far end come from the section in use that day
        sidx = [k for k, x in enumerate(r2items) if x['t'] == 's']
        far = items[hi]['node']
        endk = sidx[-1] if r2items[sidx[-1]]['node'] == far else (sidx[0] if r2items[sidx[0]]['node'] == far else None)
        if endk is not None and not (hi + 1 < len(items) and items[hi + 1]['t'] in 'be' and not items[hi + 1].get('up')):
            rng = r2items[endk + 1:] if endk == sidx[-1] else list(reversed(r2items[:endk]))
            items[hi + 1:hi + 1] = [dict(x) if endk == sidx[-1] else flip(x) for x in rng if x['t'] in 'be' and x.get('line') != line]
    guard = 0
    while guard < 50:
        guard += 1
        li = next((k for k, it in enumerate(items) if it['t'] in 'be' and it.get('line') == line and not it.get('done')), None)
        if li is None: break
        it = items[li]; r2 = r2_of(it)
        if not r2: it['done'] = True; continue
        r2items = P[r2][key]; r2s = stops(r2items)
        mn = {x['node'] for x in items if x['t'] == 's'}
        sh = [k for k, s in enumerate(r2s) if s['node'] in mn]
        if not sh: it.update(drop=True, done=True); continue
        tops = [x['node'] for x in items if x['t'] == 's']
        if len(tops) > 2 and tops[0] != tops[-1] and {r2s[0]['node'], r2s[-1]['node']} == {tops[0], tops[-1]}:
            # a piece joining the column's two ends closes a loop: it follows the last station and ends on the first one again
            used.add(r2); it.update(drop=True, done=True)
            closing = next(x for x in r2s if x['node'] == tops[0])
            rows = [dict(x, seg=r2) if x['t'] == 's' else x for x in walk(r2items, tops[-1], tops[0])]
            for kx in [x for x in items if x['t'] == 'k' and x.get('bottom') == tops[-1]]:
                # one closure bracket runs on round the loop instead of a second one for the closing piece
                if any(r['t'] == 'k' and r.get('kind') == kx.get('kind') and r.get('year') == kx.get('year') for r in rows):
                    kx['bottom'] = 'TAIL'; rows = [r for r in rows if not (r['t'] == 'k' and r.get('kind') == kx.get('kind') and r.get('year') == kx.get('year'))]
            items = items + rows + [dict(closing, seg=r2)]
            continue
        if all(x['node'] in mn for x in r2s):
            it.update(drop=True, done=True); zero_own(r2); continue
        bypass = 0 in sh and (len(r2s) - 1) in sh and len(r2s) > 2
        if bypass:
            A, B = r2s[0]['node'], r2s[-1]['node']
            ia, ib = mainidx(A), mainidx(B)
            if ia > ib: A, B, ia, ib = B, A, ib, ia
            own = walk(r2items, A, B)
            region = list(range(ia + 1, ib))
        else:
            jr = sh[-1] if sh[-1] < len(r2s) - 1 else sh[0]
            A = r2s[jr]['node']; B = None
            own = walk(r2items, A, same=True, fwd=(jr == sh[-1] and jr < len(r2s) - 1))  # away from the shared side
            ia = mainidx(A)
            region = list(range(ia + 1, len(items))) if not it['up'] else list(range(0, ia))
        own = [dict(x, seg=r2) if x['t'] == 's' else x for x in own]
        ownst = [x for x in own if x['t'] == 's']
        rstops = [k for k in region if items[k]['t'] == 's']
        main_live = any(items[k]['st'] == 'o' for k in rstops) if date else bool(rstops)
        r2_open = bool(date) and any(x['st'] == 'o' for x in ownst)
        # a section that ran alongside the main stretch is a real branch, unless it is that day's only path there (per date)
        if rstops:
            whole = lambda rid: stops(P[rid]['모름'] if '모름' in P[rid] else P[rid][key])
            r2own = [x for x in whole(r2) if x['node'] not in mn]
            reg_nodes = {items[k]['node'] for k in rstops}
            mainown = [x for x in whole(main_rid) if x['node'] in reg_nodes]
            if mainown and r2own and not exclusive(span(r2own), span(mainown)) and not (r2_open and not main_live):
                it['done'] = True; continue
        if open_on(r2, today_of(r2)) and (main_live or not date) and not bypass:
            it['done'] = True; continue
        used.add(r2)
        up = (not bypass) and it['up']
        if r2_open and not main_live:
            # that day's path runs on r2: splice it in, fold the main rows of the other period
            frows = [items[k] for k in region if items[k]['t'] == 's' or (items[k]['t'] in 'b' and items[k].get('line') != line)]
            if up: frows = [flip(x) for x in reversed(frows)]
            frows = [dict(x, seg=None, sel=False) if x['t'] == 's' else x for x in frows]
            grp = dict(t='x', up=up, rejoin=B, items=frows, **fold_meta(frows, 'new')) if any(x['t'] == 's' for x in frows) else None
            cys = [x['cy'][:4] for x in ownst if x.get('cy') and x['cy'][:4].isdigit()]
            # fold era starts at the later of: old alignment closes, first station of the folded alignment opens
            # (the date every edge of the folded main alignment A..B exists; station years only as a fallback)
            oys = [x['oy'][:4] for x in frows if x['t'] == 's' and x.get('oy') and x['oy'][:4].isdigit()]
            ccs = sorted(x['cy'] for x in ownst if x.get('cy'))
            built = built_year(main_rid, [A] + [x['node'] for x in frows if x['t'] == 's'] + [B], ccs[0] if ccs else None)
            if grp and bypass and built: grp['per'] = f"{built}~"
            elif grp and bypass and (cys or oys): grp['per'] = f"{max(filter(None, [min(cys) if cys else None, min(oys) if oys else None]))}~"
            tail = [] if bypass else tail_of(r2, ownst[-1]['node'], False)
            tblk = []
            if tail and all(s['st'] != 'o' for s in tail):
                tail = [dict(s, st='c', sel=False) for s in tail]
                tblk = [dict(t='k', kind='closed', top=ownst[-1]['node'], bottom=tail[-1]['node'], year=period(tail)[1])]
            seq = own + tblk + tail
            if bypass: items = items[:ia + 1] + ([grp] if grp else []) + seq + items[ib:]
            elif not up: items = items[:ia + 1] + ([grp] if grp else []) + seq
            else: items = [flip(x) for x in reversed(seq)] + ([grp] if grp else []) + items[ia:]
            continue
        own = [x for x in own if not (x['t'] in 'be' and x.get('line') == line)]
        ownst = [x for x in own if x['t'] == 's']
        if not rstops and not bypass:
            # a straight continuation beyond the column's end
            closed = bool(date) and all(s['st'] != 'o' for s in ownst)
            rows = [dict(s, st='c', sel=False) if closed and s['t'] == 's' else s for s in own]
            blk = [dict(t='k', kind='closed', top=A, bottom=ownst[-1]['node'], year=period(ownst)[1])] if closed else []
            items = ([flip(x) for x in reversed(rows)] + blk + items[ia:]) if it['up'] else (items[:ia + 1] + blk + rows + items[ia + 1:])
            continue
        # another period's alignment: one fold at the junction
        tail = [] if bypass else tail_of(r2, ownst[-1]['node'], bool(date))
        rows = [dict(x, sel=(not date)) if x['t'] == 's' else x for x in own + tail]
        meta = fold_meta(own, 'old')
        if tail and period(tail)[1] and period(tail)[1] != meta['per'].strip('~'):
            rows = own + [dict(t='k', kind='closed', top=ownst[-1]['node'], bottom=tail[-1]['node'], year=period(tail)[1])] + [dict(x, sel=(not date)) for x in tail]
        rows = inner_notices(rows, A, B)
        meta = dict(meta, last=[r for r in rows if r['t'] == 's'][-1]['ko'], count=len([r for r in rows if r['t'] == 's']))
        pos = ia + 1 if not up else ia
        items = items[:pos] + [dict(t='x', up=up, rejoin=B, items=rows, **meta)] + items[pos:]
    for r in [r for r in P if free(r)]:  # the same rule for such a section that no link points to
        rs = stops(P[r][key]); mn = {x['node'] for x in items if x['t'] == 's'}
        if rs and all(x['node'] in mn for x in rs): zero_own(r)
    # the column's open end goes on along exactly one same-line section that day: one line (a fork stays chips)
    while date:
        tops = [k for k, x in enumerate(items) if x['t'] == 's']
        T = items[tops[-1]]
        if T['st'] != 'o': break
        have = {items[k]['node'] for k in tops}
        cand = [r for r in P if free(r) and stops(P[r][key]) and stops(P[r][key])[0]['node'] == T['node']
                and all(x['st'] != 'f' for x in stops(P[r][key])[:2]) and not (have & {x['node'] for x in stops(P[r][key])[1:]})]
        if len(cand) != 1: break
        r3 = cand[0]; used.add(r3)
        items = items + [dict(x, seg=r3) if x['t'] == 's' else x for x in walk(P[r3][key], T['node'])]
    items = [i for i in items if not i.get('drop')]
    if not excl: CLAIMED.update(used - {main_rid})
    for i in items:
        if i['t'] == 'x' and sum(1 for r in i['items'] if r['t'] == 's') == 1: i['single'] = True
    if not date:
        # date unknown shows the newest state: a fold inside a stretch that has been closed dies with it
        tix = [k for k, x in enumerate(items) if x['t'] == 's']
        node_at = {}
        for n_, k in enumerate(tix): node_at.setdefault(items[k]['node'], n_)
        ranges = [(node_at.get(x['top'], 0) if x.get('top') != 'HEAD' else 0, len(tix) - 1 if x.get('bottom') == 'TAIL' else node_at.get(x['bottom'], -1))
                  for x in items if x['t'] == 'k' and x.get('kind') == 'closed']
        for fi, x in enumerate(items):
            if x['t'] != 'x': continue
            nxt = [n_ for n_, k in enumerate(tix) if k > fi][:1]; prv = [n_ for n_, k in enumerate(tix) if k < fi][-1:]
            seg = (prv[0], nxt[0]) if prv and nxt else ((prv or nxt)[0],) * 2
            if any(t <= seg[0] and seg[1] <= b for t, b in ranges):
                x['dead'] = True  # drawn dim; selectability stays the station's own (same as closed main-line stations when undated)
    out = [i for i in items if not (i['t'] in 'be' and i.get('line') == line and any(i.get('nx') in RNODES[r] for r in used if r != main_rid))]
    if date:  # a joining station is open when any joined section has it open that day
        openn = {}
        for r in sorted(used):
            if key in P[r]:
                for x in stops(P[r][key]):
                    if x['st'] == 'o': openn.setdefault(x['node'], dict(x, seg=r))
        out = [dict(openn[i['node']], km=i['km']) if i['t'] == 's' and i['st'] != 'o' and i['node'] in openn else i for i in out]
    return era_chain(out, date, used, P), used

LABELS = {}
def _rids(l): return [r[0] for r in db.execute("select id from route where line_id=? order by role!='main', id", (l,))]

# ---- data fixes the mockup assumes (each stands for a data change made at implementation, not a screen rule) ----
def fix_kik(P):
    """alignment-change move: the old 再春 site belongs only to the old alignment (DB has one node for both sites today)"""
    r2 = 'r_kikuchi_line_kumamoto_kosen_mae_miyoshi'
    RNODES[r2] = (RNODES[r2] - {'n_saishun_iryo_center_mae', 'n_kuroishi_kumamoto'}) | {'n_saishun_iryo_center_mae_old'}
    for d0, its in P[r2].items():
        nn = []
        for x in its:
            if x['t'] == 's' and x['node'] == 'n_kuroishi_kumamoto': continue
            if x['t'] == 's' and x['node'] == 'n_saishun_iryo_center_mae':
                x = dict(x, node='n_saishun_iryo_center_mae_old')
                if d0 in ('2026-11-22', '모름'): x['ko'] = '사이슌이료센터마에(구)'; x['ja'] = '再春医療センター前（旧）'
            nn.append(x)
        P[r2][d0] = nn
    for its in P['r_kikuchi_line'].values():
        for x in its:
            if x['t'] in 'be' and x.get('line') == 'l_kikuchi_line' and x.get('nx') == 'n_saishun_iryo_center_mae': x['nx'] = 'n_saishun_iryo_center_mae_old'
    RK[(r2, 'n_saishun_iryo_center_mae_old')] = RK.get((r2, 'n_saishun_iryo_center_mae'))

MEMBER = [r for r in sqlite3.connect(REPO + '/build/pack-master.sqlite').execute(
    "select line_id, from_node, to_node, member_line_id, valid_from, valid_to from line_period where kind='member' and member_line_id is not null and member_line_id != ''")]
def apply_membership(P, d, mr, ml, vfrom, until):
    """line_period 'member': route mr counts as line ml from vfrom until `until` (date unknown: it is one of ml's alignments)"""
    ROUTES[mr].setdefault('_line0', ROUTES[mr]['line'])
    on = d == '모름' or (vfrom or '0000') <= d < (until or '9999')
    ROUTES[mr]['line'] = ml if on else ROUTES[mr]['_line0']
    if not on: return
    for rr in P:
        if d in P[rr]:
            P[rr][d] = [dict(x, line=ml) if x['t'] in 'be' and x.get('line') == ROUTES[mr]['_line0'] and x.get('nx') in RNODES[mr] else x for x in P[rr][d]]
    uy = until[:4]
    # as a piece of this line it ends at the split; stations opened after it never belonged to this line
    def clip(x):
        if x['t'] != 's' or not (not x.get('cy') and d == '모름' or x.get('cy') and x['cy'] > uy): return x
        return dict(x, cy=uy, note=f'~{uy}') if d == '모름' else dict(x, cy=uy)
    P[mr][d] = [clip(x) for x in P[mr][d] if not (x['t'] == 's' and x.get('oy') and x['oy'] >= uy) and not (x['t'] == 'k' and x.get('kind') == 'closed' and (x.get('year') or '0') > uy)]
    if '모름' in P[mr] and d != '모름':
        P[mr]['모름'] = [dict(x, cy=uy) if x['t'] == 's' and (not x.get('cy') or x['cy'] > uy) else x for x in P[mr]['모름']]

def fix_shared_links(a, d):
    """shared stations list the other line both ways: straight on = through (already in data), reversing = transfer (missing in data)"""
    if d != TODAY[0]: return
    add = {'n_karatsu': '카라츠선(오니즈카·야마모토 방면)'}
    for it_ in a['items']:
        if it_['t'] == 's' and it_['node'] in add: it_['tr'] = it_['tr'] + [dict(num=None, flow='up', items=[dict(text=add[it_['node']], gone=False, until=None)])]
    br_ = a['branch'].get('r_chikuhi_line_yamamoto_imari')
    for it_ in (br_ or {}).get('items', []):
        if it_['t'] == 's' and it_['node'] == 'n_yamamoto': it_['tr'] = it_['tr'] + [dict(num=None, flow='up', items=[dict(text='카라츠선(혼무타베·쿠보타 방면)', gone=False, until=None)])]

CHIKUHI = ['r_chikuhi_line', 'r_chikuhi_line_meinohama_karatsu', 'r_chikuhi_line_nijinomatsubara_yamamoto', 'r_chikuhi_line_yamamoto_imari', 'r_chikuhi_line_hakata_old_chikuzenminoshima']
EXAMPLES = [
    # key, name, operator, routes (main first), dates, data fixes
    ('kik', '구마모토 전기철도 키쿠치선', '구마모토 전기철도', ['r_kikuchi_line', 'r_kikuchi_line_miyoshi_kikuchi', 'r_kikuchi_line_kumamoto_kosen_mae_miyoshi'], ['1980-06-01', '2000-06-01', '2026-11-22', '모름'], {'pre': fix_kik}),
    ('chi', '치토세선', 'JR 홋카이도', ['r_chitose_line', 'r_chitose_line_minami_chitose_new_chitose_airport', 'r_chitose_line_naebo_kita_hiroshima'], ['1965-06-01', '2026-11-22', '모름'], {}),
    ('uch', '우치코선', 'JR 시코쿠', ['r_uchiko_line', 'r_uchiko_line_kitayama_uchiko_uchiko_uchiko'], ['1980-06-01', '2026-11-22', '모름'], {}),
    ('enshu', '엔테츠선', '엔슈 철도', ['r_enshu_railway_line', 'r_enshu_railway_line_shin_hamamatsu_old_hachiman'], ['1980-06-01', '2026-11-22', '모름'], {}),
    ('chikuhi', '치쿠히선', 'JR 큐슈', CHIKUHI, ['1955-06-01', '2026-11-22'], {'post': fix_shared_links}),
    ('kago', '가고시마 본선', 'JR 큐슈', ['r_kagoshima_main_line', 'r_kagoshima_main_line_sendai_kagoshima', 'r_kagoshima_main_line_tobata_edamitsu'], ['1955-06-01', '2026-11-22'], {}),
    ('hoku', '호쿠리쿠 본선', 'JR 서일본', _rids('l_hokuriku_main_line'), ['1955-06-01', '1960-06-01', '모름'], {}),
    ('chuo', '츄오 본선', 'JR', _rids('l_chuo_main_line'), ['1955-06-01', '2026-11-22'], {}),
    ('mur', '무로란 본선', 'JR 홋카이도', ['r_muroran_main_line', 'r_muroran_main_line_kogane_moto_wanishi', 'r_muroran_main_line_higashi_muroran_muroran', 'r_muroran_main_line_shibun_iwamizawa', 'r_muroran_main_line_okishi_toyoura'], ['1965-06-01', '2026-11-22', '모름'], {}),
    ('loopn', '니시테츠 순환선', '니시테츠', _rids('l_loop_line_nishitetsu'), ['1955-06-01', '1965-06-01', '모름'], {}),
    ('loops', '센다이 시전 순환선', '센다이시 교통국', _rids('l_loop_line_sendai_city'), ['1955-06-01', '1965-06-01', '모름'], {}),
]
res = {}
for key, lname, op, rids, dates, fx in EXAMPLES:
    CLAIMED.clear()
    ML = ROUTES[rids[0]]['line']
    # whole lines that belonged to this line for a while (line_period 'member') join as this line's pieces in that period
    mem = [(r, row) for row in MEMBER if row[3] == ML and not row[1] for r in _rids(row[0])]
    rids = rids + [r for r, _ in mem if r not in rids]
    P = {}
    for r in rids:
        try: P[r] = parse(r)
        except FileNotFoundError: pass
    TODAY[0] = max(d for r in P for d in P[r] if d != '모름')
    for r in P:
        s = stops(next(iter(P[r].values())))
        LABELS[r] = '본선' if r == rids[0] else (f"{ko(s[0]['node'], None)}~{ko(s[-1]['node'], None)}" if s else r)
    if fx.get('pre'): fx['pre'](P)
    ex = dict(name=lname, op=op, dates={})
    for d in dates:
        for r, row in mem:
            if r in P: apply_membership(P, d, r, ML, row[4], row[5])
        CLAIMED.clear()
        a_items, used = stitch(rids[0], None if d == '모름' else d, P)
        own = [i for i in a_items if i['t'] == 's' and not i.get('band') and i['km'] is not None and (i['st'] == 'o' or d == '모름')]
        a_km = sum(b_['km'] - a_['km'] for a_, b_ in zip(own, own[1:]) if b_['km'] > a_['km'])  # the line's own sections added up
        chips = [r for r in rids if r in P and r not in used and ROUTES[r]['line'] == ML]
        a = dict(chips=[dict(id=r, label=LABELS[r]) for r in chips], km=round(a_km, 1), items=finalize(a_items), segs={r: LABELS[r] for r in used}, branch={})
        # a real branch (its own chip) is stitched from itself the same way, never mixed with the main line or other chips
        for r in chips:
            if d in P[r]:
                b_items, b_used = stitch(r, None if d == '모름' else d, P, {x for x in rids if x != r and (x == rids[0] or x in chips)})
                bst = [i for i in b_items if i['t'] == 's' and i['km'] is not None]
                a['branch'][r] = dict(items=finalize(b_items), km=round(max((x['km'] for x in bst), default=0) - min((x['km'] for x in bst), default=0), 1), segs={x: LABELS[x] for x in b_used})
        if fx.get('post'): fx['post'](a, d)
        ex['dates'][d] = dict(a=a)
    res[key] = ex
json.dump(res, open(OUT, 'w'), ensure_ascii=False)
for k, ex in res.items():
    for d, v in ex['dates'].items():
        print(k, d, v['a']['km'], [c['label'] for c in v['a']['chips']])
