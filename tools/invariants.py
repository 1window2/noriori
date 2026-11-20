# -*- coding: utf-8 -*-
# ARCHITECTURE §0.1의 불변식을 실제 데이터로 전수 확인한다. 앱 시뮬(appsim.py) 위에서 돈다
# 1. 도달성: 역 선택기로 입력할 수 있는 기록만으로 모든 분모 단위를 채울 수 있는가 (전 구간을 타면 100%)
# 2. 포함: 기록이 주는 크레딧은 분모 안에 있는가 (분자는 분모의 부분집합)
# 3. 합계: denominator, edge_pref가 단위 합과 맞는가
# 4. 구간 끄기: 조각을 다시 펼치면 원래 구간이 그대로 나오는가
# 6. 추정 km: 이웃 역 km·좌표를 그대로 받아 0 km 칸이 된 정차가 없는가
# 5. 가짜 역: 한 계통에 같은 역이 두 노드로 겹쳐 서지 않는가 (옛 이름·다른 노선 역이 따로 정차역이 된 꼴)
import collections,datetime,json,os,random,sys,time
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
import appsim
from appsim import App,FLOOR,MAXD

_d={}
FAIL=collections.Counter()   # 불변식 위반. 하나라도 있으면 실패로 끝난다
def dates_of(A,rid):
    """그 계통의 상태가 바뀌는 날짜들. 바뀌는 날과 그 전날을 대표로 쓴다"""
    if rid in _d:return _d[rid]
    out=set()
    def add(x):
        # 기준일 앞(범위의 열린 시작 0000-01-01 포함)은 볼 날이 없다
        if not x or x>=MAXD or x<FLOOR:return
        for v in (x,(datetime.date.fromisoformat(x)-datetime.timedelta(days=1)).isoformat()):
            if FLOOR<=v<=A.today:out.add(v)
    for s in A._stops[rid]:add(s['valid_from_lo']);add(s['valid_to_lo'])
    line=A.routes[rid]['line_id']
    for _,e,_,_ in A.route_edges(rid):
        for r in A._life[e]:add(r['valid_from_lo']);add(r['valid_to_lo'])
        for r in A.attrs_of(e,line):add(r['valid_from_lo']);add(r['valid_to_lo'])
    _d[rid]=sorted(out);return _d[rid]

_p={}
def picks(A,rid,d):
    k=(rid,d)
    if k not in _p:_p[k]=[x for x in A.picker(rid,d) if x['selectable']]
    return _p[k]

def ride_hits(A,rid,a,b,d):
    """저장 흐름 그대로 펼쳐 (노선, edge)를 돌려준다. 물어볼 경로는 답을 전부 시도한다"""
    res=[]
    if {a,b}&set([]):           # 끝 역 연장은 그 역의 계통으로 leg를 나눈다
        x=A.expand_any(rid,a,b,appsim.normalize_date(d))
        return set(A.ride_of(x,d)['edges']) if x['status']=='ok' else set()
    r=A.record(rid,a,b,d)
    if r['status']=='needs_input':
        if r.get('reason')=='relocated-parallel':
            for o in r.get('options') or []:res.append(A.record(rid,a,b,d,as_of=o['as_of']))
        else:
            for w in ('seq_up','seq_down'):res.append(A.record(rid,a,b,d,direction=w))
    elif A.routes[rid]['closed']:
        for w in ('seq_up','seq_down'):res.append(A.record(rid,a,b,d,direction=w))
    else:res.append(r)
    out=set()
    for x in res:
        if x['status'] in ('ok','partial'):
            out|=set(A.ride_of(x,x.get('saved_date'))['edges'])
    return out

def widen(rows,i,fn):
    """이웃 두 역으로 못 넣으면 반대 순서와 한 역씩 넓힌 구간으로 넣는다. 한 방향 정차역 둘이 마주 보면(士幌線 黒石平 하행만·電力所前 상행만)
    그 사이는 더 길게 타야만 지난다 (DESIGN §8 한 방향 정차)"""
    n=len(rows)
    for k in range(n):
        lo,hi=i-k,i+1+k
        if lo<0 and hi>=n:break
        lo,hi=max(lo,0),min(hi,n-1)
        for a,b in ((rows[lo]['node'],rows[hi]['node']),(rows[hi]['node'],rows[lo]['node'])):
            if a!=b and (h:=fn(a,b)):return h
    return set()

def reach(A):
    hits=set();calls=0;bad=collections.Counter();t=time.time()
    # 여객 영업 이력이 없는 화물선(rule_class hidden)은 목록·검색에 없어 고를 수 없다 (사용자 결정 2026-11-09)
    hidden={l for (l,) in A.db.execute("select id from line where rule_class='hidden'")}
    for rid in A.routes:
        if A.routes[rid]['line_id'] in hidden:continue
        for d in [None]+dates_of(A,rid):
            rows=picks(A,rid,d)
            for i,(p,q) in enumerate(zip(rows,rows[1:])):
                calls+=1
                if p['node']==q['node']:continue
                h=ride_hits(A,rid,p['node'],q['node'],d) or widen(rows,i,lambda a,b:ride_hits(A,rid,a,b,d))
                # 양 끝 연장 역이 둘 다 계통의 같은 끝으로 이어지면 이 계통의 승차가 아니다 (田端貨物線의 上中里·駒込). 앱도 경로 없음으로 막는다
                ext=set([])
                if not h and not ({p['node'],q['node']}<=ext and A.expand_any(rid,p['node'],q['node'],appsim.normalize_date(d)).get('reason')=='same-node'):bad[rid]+=1
                hits|=h
    print(f'[도달성] 계통 {len(A.routes)}, 펼치기 {calls}회, {time.time()-t:.0f}초, 탈 수 있는 (노선, edge) {len(hits)}')
    if bad:print('  이웃 역인데 경로가 안 나오는 계통',len(bad),bad.most_common(8));FAIL['이웃 역 경로 없음']+=len(bad)
    report={}
    for c in ('on','off'):
        got={A.unit_of(l,e,c) for l,e in hits}
        nodes=[(k,u) for (k,cc),u in A.units.items() if cc==c]
        for cls in ('normal','outside','extra'):
            all_=[(k,u) for k,u in nodes if u['class']==cls]
            miss=[(k,u) for k,u in all_ if k not in got]
            print(f'  승계 {c} {cls}: 단위 {len(all_)}, 못 채움 {len(miss)}, {sum(u["km"] for _,u in miss):.1f}km')
            for k,u in miss[:30]:
                ed=A.edges[u['edge_id']];ls=sorted({a['line_id'] for a in A._attrs[u['edge_id']]})
                print('    ',k,u['km'],u['valid_from'],u['valid_to'],A.name(ed['from_node'],None,None),'~',A.name(ed['to_node'],None,None),[A.line_name(l) for l in ls][:3])
            report[c,cls]=miss
            if cls=='normal' and miss:FAIL[f'승계 {c} 못 채우는 분모 단위']+=len(miss)
        ks={k for k,_ in nodes}
        out=[l_e for l_e in hits if A.unit_of(*l_e,c) not in ks]
        print(f'  승계 {c}: 분모 밖으로 떨어지는 크레딧 {len(out)}',out[:4])
        if out:FAIL[f'승계 {c} 분모 밖 크레딧']+=len(out)
    return hits,report

def member(A,rid,e,d):
    """그날 이 계통의 노선이 이 구간을 확실히 가졌는가. 이관 뒤의 구간과 불확실한 날짜는 뺀다"""
    return any(r['valid_from_hi']<=d and (r['valid_to_lo'] or MAXD)>d for r in A.attrs_of(e,A.routes[rid]['line_id']) if r['valid_from_hi'])

def on_date(A):
    """그날 영업한 구간은 그날 날짜로 기록할 수 있어야 한다. 도달성은 어느 날이든 채워지면 통과라 이것을 못 본다"""
    want=collections.defaultdict(set);got=set();calls=0;t=time.time()
    # 화물선(extra)은 정기 여객이 없어 그날 날짜로 넣을 대상이 아니다 (高島線. 분모에도 들지 않는다).
    # 여객 영업 이력이 없는 화물선(hidden)은 아예 기록할 수 없다 (9회차 F)
    extra={l for l,c in A.db.execute('select id,rule_class from line') if c in ('extra','hidden')}
    for rid in A.routes:
        line=A.routes[rid]['line_id'];ext=set([])
        if line in extra:continue
        for d in dates_of(A,rid)+[FLOOR]:
            for _,e,_,_ in A.route_edges(rid):
                if A.edge_usable(rid,e,d)[0]=='ok' and member(A,rid,e,d):want[line,e].add(d)
            rows=picks(A,rid,d)
            for i,(p,q) in enumerate(zip(rows,rows[1:])):
                if p['node']==q['node']:continue
                calls+=1
                if {p['node'],q['node']}&ext:                # 끝 역 연장은 그 역의 계통으로 leg를 나눈다
                    x=A.expand_any(rid,p['node'],q['node'],appsim.normalize_date(d))
                    if x['status']=='ok':got|={(l,e,d) for l,e in A.ride_of(x,d)['edges']}
                    continue
                def hits(a,b):
                    out=set()
                    for w in (None,'seq_up','seq_down'):
                        x=A.expand(rid,a,b,d,direction=w)
                        if x['status']=='ok':out|={(l,e,d) for l,e in A.ride_of(x,d)['edges']}
                    return out
                got|=hits(p['node'],q['node']) or widen(rows,i,hits)
            if A.routes[rid]['closed'] and rows:
                x=A.expand(rid,rows[0]['node'],rows[0]['node'],d,direction='seq_up')
                if x['status']=='ok':got|={(l,e,d) for l,e in A.ride_of(x,d)['edges']}
    gaps={k:sorted(d for d in ds if (*k,d) not in got) for k,ds in want.items()}
    gaps={k:v for k,v in gaps.items() if v}
    for (l,e),ds in list(gaps.items()):                  # 다른 계통의 연장이나 운행 계통으로 넣을 수 있으면 된다
        ed=A.edges[e];ends={ed['from_node'],ed['to_node']}
        for d in list(ds):
            for rid in A.routes:
                if not ends&(set([])|{s['node_id'] for s in A._stops[rid]}):continue
                rows=picks(A,rid,d);ok=False
                for p,q in zip(rows,rows[1:]):
                    if p['node']==q['node']:continue
                    x=A.expand_any(rid,p['node'],q['node'],appsim.normalize_date(d))
                    if x['status']=='ok' and (l,e) in A.ride_of(x,d)['edges']:ok=True;break
                if ok:ds.remove(d);break
            else:
                for sid, in A.db.execute('select id from service'):
                    hops,bad=A.service_chain(sid,d)
                    if not bad and any(h[2]==e for h in hops):ds.remove(d);break
        if not ds:del gaps[l,e]
    # 사유를 적은 예외 (data/overrides/invariant_exceptions.json, 사용자 결정)
    EXC=json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','data','overrides','invariant_exceptions.json'),encoding='utf-8'))['on_date']
    for x in EXC:
        if x.get('provisional'):print('  임시 예외',x['line'],x['a'],x['b'],x['from'],x['to'])
        for (l,e),ds in list(gaps.items()):
            ed=A.edges[e]
            if l==x['line'] and {ed['from_node'],ed['to_node']}=={x['a'],x['b']}:
                ds=[d for d in ds if not x['from']<=d<=x['to']]
                if ds:gaps[l,e]=ds
                else:del gaps[l,e]
    print(f'[날짜별 도달성] 펼치기 {calls}회, {time.time()-t:.0f}초, 그날 날짜로 못 넣는 (노선, edge) {len(gaps)}, {sum(A.km[e] for _,e in gaps):.1f}km')
    if gaps:FAIL['그날 날짜로 못 넣는 구간']+=len(gaps)
    return gaps

def sums(A):
    d=A.db
    a={(r[0],r[1]):r[2] for r in d.execute("select carryover,class,round(sum(km),1) from denominator_unit group by 1,2")}
    print('[합계] 단위 합',a)
    print('  denominator 역대',[tuple(x) for x in d.execute("select carryover,round(km,1),unit_count from denominator where basis='alltime' and scope in ('all','total','전체')").fetchall()[:4]])
    bad=d.execute("""select e.edge_id,e.km,round(sum(p.km),1) from edge_km e left join edge_pref p on p.edge_id=e.edge_id
      group by 1 having sum(p.km) is null or abs(sum(p.km)-e.km)>0.11""").fetchall()
    print('  edge_pref 합이 km와 다른 구간',len(bad),bad[:5])
    if bad:FAIL['edge_pref 합 불일치']+=len(bad)
    fut=d.execute("select count(*),round(sum(km),1) from denominator_unit where carryover='on' and valid_from>?",(A.today,)).fetchone()
    print('  아직 개업 안 한 분모 단위',tuple(fut))

def phantoms(A):
    """한 계통에서 기간이 겹치고 1.5 km 안에 선 두 정차 노드가 이름(지금·옛 이름)을 함께 가지면 같은 역이 두 번 들어간 것이다.
    南海本線 住吉公園(住吉大社의 옛 이름이 따로 정차역이 됨) 같은 꼴을 막는다 (가짜 역 전수 검증 2026-11-09). 역 이전 쌍(node_move)은 뺀다"""
    import math,re,unicodedata
    def norm(t):return re.sub(r'（[^）]*）$','',unicodedata.normalize('NFKC',t or '')).replace('ヶ','ケ')
    def lo(v,end=False):
        if v in (None,'ongoing'):return '9999' if end else '0000'
        return v.strip('[')[:10].replace('XX','01')
    raw=collections.defaultdict(list)
    # 노선별 이름(그 노선에서만 쓰는 표기, 越美南線 시절 母野의 木尾)은 그 노선 계통에서만 본다
    for n,t,f,u,l in A.db.execute("select entity_id,text,valid_from,valid_to,line_id from nm.name where entity_type='node' and lang='ja'"):raw[n].append((norm(t),f,u,l))
    # 노드 → [(이름, 시작, 끝)]. 이름 기간까지 겹쳐야 같은 역이다 (千林의 옛 이름 森小路와 지금 森小路는 시기가 다름).
    # 기간 없는 지금 이름은 그 노드의 기간 있는 다른 이름이 쓰이던 때를 뺀 나머지에만 쓴다 (竹鼻: 1929~1951은 栄町)
    texts=collections.defaultdict(list)
    for n,rows in raw.items():
        dated=sorted((lo(f),lo(u,True)) for t,f,u,l in rows if (f or u) and not l)
        for t,f,u,l in rows:
            if f or u or l:texts[n].append((t,lo(f),lo(u,True),l));continue
            at='0000'
            for f2,u2 in dated:
                if f2>at:texts[n].append((t,at,f2,None))
                at=max(at,u2)
            if at<'9999':texts[n].append((t,at,'9999',None))
    pos={n:(la,lo) for n,la,lo in A.db.execute("select node_id,lat,lon from node_position where lat is not null")}
    moved={frozenset(x) for x in A.db.execute("select old_node,new_node from node_move")}
    gaps=collections.defaultdict(list)
    for r_,n_,g0,g1 in A.db.execute("select route_id,node_id,gap_from,gap_to from route_stop_gap"):gaps[(r_,n_)].append((lo(g0),lo(g1,True)))
    bad=[]
    for rid,st in A._stops.items():
        S=[x for x in st if x['is_stop']];ln=A.routes[rid]['line_id']
        for i,a in enumerate(S):
            for b in S[i+1:]:
                if a['node_id']==b['node_id'] or frozenset((a['node_id'],b['node_id'])) in moved:continue
                if a['node_id'] not in pos or b['node_id'] not in pos:continue
                (y1,x1),(y2,x2)=pos[a['node_id']],pos[b['node_id']]
                if math.hypot((y1-y2)*111.2,(x1-x2)*111.2*math.cos(math.radians(y1)))>1.5:continue
                if not(lo(a['valid_from'])<lo(b['valid_to'],True) and lo(b['valid_from'])<lo(a['valid_to'],True)):continue
                f0=max(lo(a['valid_from']),lo(b['valid_from']));u0=min(lo(a['valid_to'],True),lo(b['valid_to'],True))
                # 정차 기간 사이 서지 않던 때(route_stop_gap)는 겹침이 아니다 (滋賀里 1945~1955 坂本方 400m 이설 동안 옛 자리 정차 없음)
                same=sorted({t for t,f,u,l in texts[a['node_id']] for t2,f2,u2,l2 in texts[b['node_id']]
                             if t==t2 and l in (None,ln) and l2 in (None,ln) and max(f0,f,f2)<min(u0,u,u2)
                             and not any(g0<=max(f0,f,f2) and min(u0,u,u2)<=g1 for g0,g1 in gaps.get((rid,a['node_id']),[])+gaps.get((rid,b['node_id']),[]))})
                if same:bad.append((rid,a['node_id'],b['node_id'],same[:2]))
    print('[가짜 역] 한 계통의 같은 이름 겹친 정차 쌍',len(bad),bad[:6])
    if bad:FAIL['가짜 역(같은 역 두 노드)']+=len(bad)

def km_collapse(A):
    """추정 km 역이 이웃 역의 km를 그대로 받으면 0 km 칸이 되고, 좌표 보간도 이웃 좌표를 복사한다 (추정 km 조사 2026-11-09: 若宮·浅間線 등 17역).
    0.05 km 미만 칸과, 같은 계통에서 이웃한 정차역 둘이 같은 km에 서는 일이 없어야 한다. 같은 역 묶음(옛 자리·나눈 노드)은 뺀다"""
    # 나뉜 역(station_split)의 같은 km 점 칸은 0 km가 맞다 (나뉘기 전 그 노선의 한 역 자리, 11회차 S1)
    _ss=A.db.execute("select 1 from sqlite_master where type='table' and name='station_split'").fetchone()
    zero=A.db.execute("select k.edge_id,e.from_node,e.to_node from edge_km k join edge e on e.id=k.edge_id where k.km<0.05"+(" and k.edge_id not in (select edge_id from station_split where edge_id is not null)" if _ss else "")).fetchall()
    grp={n:g for n,g in A.db.execute("select id,group_id from node")}
    moved={frozenset(x) for x in A.db.execute("select old_node,new_node from node_move")}|({frozenset(x) for x in A.db.execute("select node_a,node_b from station_split")} if _ss else set())
    same=[]
    for rid,st in A._stops.items():
        S=[x for x in st if x['is_stop'] and x['km_cum'] is not None]
        for a,b in zip(S,S[1:]):
            if abs(a['km_cum']-b['km_cum'])>=0.05 or grp.get(a['node_id'])==grp.get(b['node_id']) or frozenset((a['node_id'],b['node_id'])) in moved:continue
            if not(a.get('km_estimated') or b.get('km_estimated')):continue
            same.append((rid,a['node_id'],b['node_id'],a['km_cum']))
    print('[추정 km] 0.05 km 미만 칸',len(zero),[tuple(z) for z in zero[:4]],'/ 이웃과 같은 km의 추정 역',len(same),same[:4])
    if zero:FAIL['0 km 칸']+=len(zero)
    if same:FAIL['이웃과 같은 추정 km']+=len(same)

def cuts(A,n=6000):
    """기록에서 구간을 잘라 조각을 다시 펼치면 원래 edge가 그대로 나와야 한다"""
    r=random.Random(11);routes=[x for x in A.routes if len(A._stops[x])>=4]
    ok=fail=skip=0;why=collections.Counter();ex={}
    for _ in range(n):
        rid=r.choice(routes);ds=dates_of(A,rid)
        d=r.choice(ds) if ds and r.random()<.7 else None
        rows=[x for x in picks(A,rid,d) if not 0]
        if len(rows)<4:skip+=1;continue
        idx=sorted(r.sample(range(len(rows)),2))
        direction=r.choice(['seq_up','seq_down']) if A.routes[rid]['closed'] else None
        a,b=rows[idx[0]]['node'],rows[idx[1]]['node']
        if r.random()<.5 and not A.routes[rid]['closed']:a,b=b,a
        res=A.record(rid,a,b,d,direction=direction)
        if res['status']!='ok' or not res.get('nodes'):skip+=1;continue
        nodes,edges=res['nodes'],res['edges']
        vis={x['node_id'] for x in A._stops[rid] if x['is_stop']}     # 노선 상세의 표시 역. 그날 고를 수 없는 역도 끊을 수 있다
        cand=[i for i,x in enumerate(nodes) if x in vis]
        if len(cand)<2:skip+=1;continue
        i,j=sorted(r.sample(cand,2))
        pieces=[(nodes[:i+1],edges[:i]),(nodes[j:],edges[j:])]
        # 조각은 원래 기록이 저장한 날짜로 다시 펼친다. 날짜 모름으로 내려 저장한 기록(그날 없던 역)의 조각을 원래 날짜로 펼치면
        # 옛 선로(alt old)가 있는 계통에서 그날 경로(옛 선로)로 가 원래 edge(그 역이 있던 시절 경로)와 달라진다 (中央本線 田立 옛 선로)
        dd=res.get('saved_date') if res.get('demoted') else d
        for pn,pe in pieces:
            if len(pn)<2:continue
            x=A.record(rid,pn[0],pn[-1],dd,direction=direction)
            # 날짜 없는 조각이 이설로 두 경로로 갈리면 다시 펼쳐 맞출 수 없다(앱은 조각 edge를 그대로 저장한다)
            if dd is None and x['status']=='needs_input' and x.get('reason') in ('ambiguous-path','relocated-parallel'):skip+=1;continue
            # 조각 끝이 그 방향 열차가 서지 않는 역이면 다시 펼칠 수 없다(앱은 조각 edge를 그대로 저장한다, DESIGN §8 한 방향 정차)
            if x['status']=='invalid' and x.get('reason')=='stop-direction':skip+=1;continue
            if x['status']=='ok' and sorted(x['edges'])==sorted(pe) and (not res.get('saved_date') or x.get('saved_date')==res['saved_date']):ok+=1
            else:
                fail+=1;key=(x['status'],x.get('reason'),bool(A.routes[rid]['closed']))   # 날짜가 있던 기록의 조각이 날짜를 잃으면 불일치
                why[key]+=1;ex.setdefault(key,(rid,d,pn[0],pn[-1],len(pe),len(x.get('edges') or [])))
    print(f'[구간 끄기] 조각 다시 펼치기 일치 {ok}, 불일치 {fail}, 건너뜀 {skip}')
    if fail:FAIL['구간 끄기 조각 불일치']+=fail
    for k,v in why.most_common(8):print('  ',k,v,ex[k])

if __name__=='__main__':
    A=App()
    sums(A)
    phantoms(A)
    km_collapse(A)
    cuts(A)
    if '--no-reach' not in sys.argv:
        reach(A)
        for (l,e),ds in sorted(on_date(A).items()):
            ed=A.edges[e];print('  ',A.line_name(l),e,A.name(ed['from_node'],None,None),'~',A.name(ed['to_node'],None,None),A.km[e],ds[0],ds[-1])
    if FAIL:raise SystemExit(f'불변식 위반: {dict(FAIL)}')
    print('불변식 통과')
