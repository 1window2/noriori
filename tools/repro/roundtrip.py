# 저장 결과를 ride_leg 원본(route, from, to, direction)으로 낮춘 뒤 원본만으로 다시 펼친다.
# 재해석은 이 경로만 탄다. 같은 구간이 안 나오면 다음 앱 갱신에서 기록의 뜻이 바뀐다.
import sys,collections,random,time
sys.path.insert(0,sys.argv[1])
import appsim, invariants
from appsim import App,FLOOR,MAXD,normalize_date
A=App();d=A.db
def lower(res,fallback_route):
    """expand 결과 → 원본 legs. 경로를 따라 route가 바뀌는 곳에서 나눈다"""
    nodes=res['nodes'];edges=res['edges']
    owner={}
    for k,es in res['legs'].items():
        r=k if k in A.routes else fallback_route
        for e in es:owner[e]=r
    legs=[];i=0
    while i<len(edges):
        j=i
        while j+1<len(edges) and owner[edges[j+1]]==owner[edges[i]]:j+=1
        legs.append(dict(route=owner[edges[i]],a=nodes[i],b=nodes[j+1],edges=edges[i:j+1]))
        i=j+1
    return legs
def reexpand(leg,date,direction=None):
    r=A.record(leg['route'],leg['a'],leg['b'],date,direction=direction)
    return r
stat=collections.Counter();ex=collections.defaultdict(list)
R=random.Random(7)
t=time.time()
for rid in A.routes:
    ds=invariants.dates_of(A,rid)
    sample=[None]+R.sample(ds,min(4,len(ds)))
    for dd in sample:
        rows=A.picker(rid,dd);rows=[x for x in rows if x['selectable']]
        if len(rows)<2:continue
        pairs=list(zip(rows,rows[1:]))
        for _ in range(6):
            p,q=R.sample(rows,2);pairs.append((p,q))
        for p,q in pairs:
            a,b=p['node'],q['node']
            if a==b:continue
            ext=set(A.routes[rid]['extend_to'])
            if {a,b}&ext:
                res=A.expand_any(rid,a,b,normalize_date(dd));kind='ext'
                saved=normalize_date(dd)
            else:
                res=A.record(rid,a,b,dd);kind='plain';saved=res.get('saved_date')
            if res['status']!='ok' or not res.get('nodes'):
                stat[kind,'저장안됨',res['status']]+=1;continue
            direction=res.get('direction') if A.routes[rid]['closed'] else None
            legs=lower(res,rid)
            got=[];bad=None
            for lg in legs:
                x=reexpand(lg,saved,direction)
                if x['status'] not in('ok',):bad=(x['status'],x.get('reason'));break
                if x.get('demoted'):bad=('demoted',None);break
                got+=x['edges']
            if bad:
                stat[kind,'실패',bad]+=1;ex[kind,bad].append((rid,dd,a,b,len(legs)));continue
            if sorted(got)!=sorted(res['edges']):
                stat[kind,'구간다름']+=1;ex[kind,'diff'].append((rid,dd,a,b,len(legs),res['km'],round(sum(A.km[e] for e in got),1)))
            else:stat[kind,'같음']+=1
print(f'{time.time()-t:.0f}s')
for k,v in sorted(stat.items(),key=str):print(k,v)
for k,v in ex.items():print(k,len(v),v[:5])
# 운전 계통
st=collections.Counter();ex2=[]
for sid,closed in d.execute('select id,closed from service').fetchall():
    for dd in (None,'1990-06-01','2010-06-01','2026-06-01'):
        hops,gaps=A.service_chain(sid,dd)
        if gaps:st['gap']+=1;continue
        ns=[h[1] for h in hops]+[hops[-1][3]]
        for _ in range(30):
            a,b=R.sample(ns,2)
            x=A.expand_service(sid,a,b,dd)
            if x['status']!='ok':continue
            # legs는 route별 edge 묶음
            nodes=x['nodes'];i=0;got=[];fail=None
            order=[]
            for r,es in x['legs'].items():order.append((r,es))
            for r,es in order:
                na,nb=nodes[i],nodes[i+len(es)];i+=len(es)
                y=A.record(r,na,nb,dd)
                if y['status']!='ok':fail=(y['status'],y.get('reason'),r,na,nb);break
                got+=y['edges']
            if fail:st['실패',fail[0],fail[1]]+=1;ex2.append((sid,dd,fail));continue
            st['같음' if sorted(got)==sorted(x['edges']) else '구간다름']+=1
print(st);print(ex2[:6])
