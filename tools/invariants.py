# -*- coding: utf-8 -*-
# ARCHITECTURE §0.1의 불변식을 실제 데이터로 전수 확인한다. 앱 시뮬(appsim.py) 위에서 돈다
# 1. 도달성: 역 선택기로 입력할 수 있는 기록만으로 모든 분모 단위를 채울 수 있는가 (전 구간을 타면 100%)
# 2. 포함: 기록이 주는 크레딧은 분모 안에 있는가 (분자는 분모의 부분집합)
# 3. 합계: denominator, edge_pref가 단위 합과 맞는가
# 4. 구간 끄기: 조각을 다시 펼치면 원래 구간이 그대로 나오는가
import collections,datetime,os,random,sys,time
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
import appsim
from appsim import App,edtf_range,FLOOR,MAXD

_d={}
def dates_of(A,rid):
    """그 계통의 상태가 바뀌는 날짜들. 바뀌는 날과 그 전날을 대표로 쓴다"""
    if rid in _d:return _d[rid]
    out=set()
    def add(x):
        if not x or x>=MAXD:return
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
    if {a,b}&set(A.routes[rid]['extend_to']):           # 끝 역 연장은 그 역의 계통으로 leg를 나눈다
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

def reach(A):
    hits=set();calls=0;bad=collections.Counter();t=time.time()
    for rid in A.routes:
        for d in [None]+dates_of(A,rid):
            rows=picks(A,rid,d)
            for p,q in zip(rows,rows[1:]):
                calls+=1
                if p['node']==q['node']:continue
                h=ride_hits(A,rid,p['node'],q['node'],d)
                if not h:bad[rid]+=1
                hits|=h
    print(f'[도달성] 계통 {len(A.routes)}, 펼치기 {calls}회, {time.time()-t:.0f}초, 탈 수 있는 (노선, edge) {len(hits)}')
    if bad:print('  이웃 역인데 경로가 안 나오는 계통',len(bad),bad.most_common(8))
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
        ks={k for k,_ in nodes}
        out=[l_e for l_e in hits if A.unit_of(*l_e,c) not in ks]
        print(f'  승계 {c}: 분모 밖으로 떨어지는 크레딧 {len(out)}',out[:4])
    return hits,report

def member(A,rid,e,d):
    """그날 이 계통의 노선이 이 구간을 확실히 가졌는가. 이관 뒤의 구간과 불확실한 날짜는 뺀다"""
    return any(r['valid_from_hi']<=d and (r['valid_to_lo'] or MAXD)>d for r in A.attrs_of(e,A.routes[rid]['line_id']) if r['valid_from_hi'])

def on_date(A):
    """그날 영업한 구간은 그날 날짜로 기록할 수 있어야 한다. 도달성은 어느 날이든 채워지면 통과라 이것을 못 본다"""
    want=collections.defaultdict(set);got=set();calls=0;t=time.time()
    for rid in A.routes:
        line=A.routes[rid]['line_id'];ext=set(A.routes[rid]['extend_to'])
        for d in dates_of(A,rid)+[FLOOR]:
            for _,e,_,_ in A.route_edges(rid):
                if A.edge_usable(rid,e,d)[0]=='ok' and member(A,rid,e,d):want[line,e].add(d)
            rows=picks(A,rid,d)
            for p,q in zip(rows,rows[1:]):
                if p['node']==q['node']:continue
                calls+=1
                if {p['node'],q['node']}&ext:                # 끝 역 연장은 그 역의 계통으로 leg를 나눈다
                    x=A.expand_any(rid,p['node'],q['node'],appsim.normalize_date(d))
                    if x['status']=='ok':got|={(l,e,d) for l,e in A.ride_of(x,d)['edges']}
                    continue
                for w in (None,'seq_up','seq_down'):
                    x=A.expand(rid,p['node'],q['node'],d,direction=w)
                    if x['status']=='ok':got|={(l,e,d) for l,e in A.ride_of(x,d)['edges']}
            if A.routes[rid]['closed'] and rows:
                x=A.expand(rid,rows[0]['node'],rows[0]['node'],d,direction='seq_up')
                if x['status']=='ok':got|={(l,e,d) for l,e in A.ride_of(x,d)['edges']}
    gaps={k:sorted(d for d in ds if (*k,d) not in got) for k,ds in want.items()}
    gaps={k:v for k,v in gaps.items() if v}
    for (l,e),ds in list(gaps.items()):                  # 다른 계통의 연장이나 운전 계통으로 넣을 수 있으면 된다
        ed=A.edges[e];ends={ed['from_node'],ed['to_node']}
        for d in list(ds):
            for rid in A.routes:
                if not ends&(set(A.routes[rid]['extend_to'])|{s['node_id'] for s in A._stops[rid]}):continue
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
    print(f'[날짜별 도달성] 펼치기 {calls}회, {time.time()-t:.0f}초, 그날 날짜로 못 넣는 (노선, edge) {len(gaps)}, {sum(A.km[e] for _,e in gaps):.1f}km')
    return gaps

def sums(A):
    d=A.db
    a={(r[0],r[1]):r[2] for r in d.execute("select carryover,class,round(sum(km),1) from denominator_unit group by 1,2")}
    print('[합계] 단위 합',a)
    print('  denominator 역대',[tuple(x) for x in d.execute("select carryover,round(km,1),unit_count from denominator where basis='alltime' and scope in ('all','total','전체')").fetchall()[:4]])
    bad=d.execute("""select e.edge_id,e.km,round(sum(p.km),1) from edge_km e left join edge_pref p on p.edge_id=e.edge_id
      group by 1 having sum(p.km) is null or abs(sum(p.km)-e.km)>0.11""").fetchall()
    print('  edge_pref 합이 km와 다른 구간',len(bad),bad[:5])
    fut=d.execute("select count(*),round(sum(km),1) from denominator_unit where carryover='on' and valid_from>?",(A.today,)).fetchone()
    print('  아직 개업 안 한 분모 단위',tuple(fut))

def cuts(A,n=6000):
    """기록에서 구간을 잘라 조각을 다시 펼치면 원래 edge가 그대로 나와야 한다"""
    r=random.Random(11);routes=[x for x in A.routes if len(A._stops[x])>=4]
    ok=fail=skip=0;why=collections.Counter();ex={}
    for _ in range(n):
        rid=r.choice(routes);ds=dates_of(A,rid)
        d=r.choice(ds) if ds and r.random()<.7 else None
        rows=[x for x in picks(A,rid,d) if not x['is_extension']]
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
        for pn,pe in pieces:
            if len(pn)<2:continue
            if pn[0]==pn[-1]:
                x=A.record(rid,pn[0],pn[-1],d,direction=direction)
            else:x=A.record(rid,pn[0],pn[-1],d,direction=direction)
            if x['status']=='ok' and sorted(x['edges'])==sorted(pe) and (not res.get('saved_date') or x.get('saved_date')==res['saved_date']):ok+=1
            else:
                fail+=1;key=(x['status'],x.get('reason'),bool(A.routes[rid]['closed']))   # 날짜가 있던 기록의 조각이 날짜를 잃으면 불일치
                why[key]+=1;ex.setdefault(key,(rid,d,pn[0],pn[-1],len(pe),len(x.get('edges') or [])))
    print(f'[구간 끄기] 조각 다시 펼치기 일치 {ok}, 불일치 {fail}, 건너뜀 {skip}')
    for k,v in why.most_common(8):print('  ',k,v,ex[k])

if __name__=='__main__':
    A=App()
    sums(A)
    cuts(A)
    if '--no-reach' not in sys.argv:
        reach(A)
        for (l,e),ds in sorted(on_date(A).items()):
            ed=A.edges[e];print('  ',A.line_name(l),e,A.name(ed['from_node'],None,None),'~',A.name(ed['to_node'],None,None),A.km[e],ds[0],ds[-1])
