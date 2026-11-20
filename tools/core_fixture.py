# -*- coding: utf-8 -*-
# Dart core가 파이썬 기준과 같은지 보는 대조표를 만든다. packages/noriori_store/test/core_parity_test.dart가 읽는다
#   python3 -I tools/core_fixture.py [건수]
import json,os,random,sys
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
import appsim
N=int(sys.argv[1]) if len(sys.argv)>1 else 6000
A=appsim.App()
R=random.Random(20261102)
# 여객 영업 이력이 없는 화물선(rule_class hidden)은 앱 판에 없다. 대조표에서도 뺀다 (9회차 F)
_hid={l for (l,) in A.db.execute("select id from line where rule_class='hidden'")}
rids=sorted(r for r in A.routes if A.routes[r]['line_id'] not in _hid)
def rec(rid,a,b,date):
    d=appsim.normalize_date(date)
    r=A.expand_any(rid,a,b,d)
    demoted=date is not None and d is None
    if r['status']=='invalid' and d is not None and r.get('reason') in('no-path-on-date','not-closed-on-date'):
        r=A.expand_any(rid,a,b,None);demoted=True
    return r,demoted
# 거리는 구간마다 그 노선의 km다. 3섹 전환 전 노선은 국철 시대 km (DESIGN §2.9 E, 앱 RouteResolver와 같음)
ERA_M={(x['line_id'],x['edge_id']):x['m'] for x in A.db.execute('SELECT line_id,edge_id,m FROM edge_km_era')}
def meters(r,rid):
    legs=r.get('legs') or {A.routes[rid]['line_id']:r.get('edges',[])}
    return sum(ERA_M[(l,e)]/1000 if (l,e) in ERA_M else A.km[e] for l,es in legs.items() for e in es)
DATES=[None,'1969-01-01','1970-XX-XX','1975-06-XX','1985-03-14','198X-XX-XX','1987-04-01','1990-07-01','2000-XX-XX','2005-10-01','2010-06-15','2015-03-14','2015-03-XX','2020-XX-XX','2026-11-01']
out=[]
for i in range(N):
    rid=R.choice(rids)
    st=[s for s in A._picks[rid] if s['is_stop'] or 0]
    if len(st)<2:continue
    a,b=R.sample(st,2)
    date=R.choice(DATES)
    r,dem=rec(rid,a['node_id'],b['node_id'],date)
    row=dict(route=rid,a=a['node_id'],b=b['node_id'],date=date,status=r['status'],edges=r.get('edges',[]),m=None if r.get('km') is None else meters(r,rid),demoted=dem,reason=r.get('reason'))
    row['m']=None if row['m'] is None else round(row['m']*1000)
    if r.get('nodes'):row['nodes']=r['nodes']
    if r.get('direction'):row['direction']=r['direction']
    if r.get('line_km'):row['lines']=sorted(r['line_km'])
    out.append(row)
# 선택기
pick=[]
for i in range(300):
    rid=R.choice(rids);date=R.choice(DATES)
    rows=A.picker_lineage(rid,date)
    pick.append(dict(route=rid,date=date,rows=[[x['seq'],x['node'],x['state'],bool(x['selectable']),x.get('saved_as')] for x in rows]))
# 완주율: 무작위 기록 묶음
rides=[]
# 닫힌 계통은 기록에 방향이 저장되고 재해석은 방향을 묻는다. 대조표에는 방향이 없으므로 뺀다 (ARCHITECTURE §7.2)
loops={r[0] for r in A.db.execute('select id from route where closed=1')}
for row in R.sample([x for x in out if x['status']=='ok' and x['edges'] and x['route'] not in loops],400):
    rr,_=rec(row['route'],row['a'],row['b'],row['date'])
    x=A.ride_of(rr,None if row['demoted'] else appsim.normalize_date(row['date']))
    # 연장 역으로 나뉘면 펼친 결과의 끝이 고른 역과 다르다. 앱은 고른 두 역을 그대로 끝으로 본다
    x['ends']=(row['route'],row['a'],row['b'])
    x['created']='2026-11-01'
    rides.append(dict(route=row['route'],a=row['a'],b=row['b'],date=row['date'],hi=A.effective_hi(x),x=x))
pys=[{k:v for k,v in x.items() if k!='x'} for x in rides]
scores=[]
for n in (40,400):
    use=[x['x'] for x in rides[:n]]
    for b in ('current','alltime','1975','1987','2000','2020'):
        for c in ('on','off'):
            r=A.completion(use,b,c)
            scores.append(dict(n=n,basis=b,carryover=c,num_units=r['num_units'],den_units=r['den_units'],den=r['den_km'],num=r['num_km']))
json.dump(dict(expand=out,picker=pick,rides=pys,scores=scores,today=appsim.TODAY),open(os.path.join(appsim.SCRATCH,'build','core_fixture.json'),'w',encoding='utf-8'),ensure_ascii=False)
import collections
print(len(out),collections.Counter(x['status'] for x in out),len(pick),len(scores))
