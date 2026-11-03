# -*- coding: utf-8 -*-
# data/source를 컴파일해 build/master.sqlite, build/names.sqlite, build/report.json을 만든다
import sys,os,json,sqlite3,collections,heapq,re,math
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from lib import *

TODAY=AS_OF
ERR=collections.defaultdict(list)
WARN=collections.defaultdict(list)
def err(k,v):ERR[k].append(v)

ops={o['id']:o for o in load('operators')}
lines={l['id']:l for l in load('lines')}
routes={r['id']:r for r in load('routes')}
nodes={n['id']:n for n in load('nodes')}
groups=load('groups')
edges={e['id']:e for e in load('edges')}
kms={k['edge']:k['km'] for k in load('km')}
events=load('events')
positions=load('positions')
hubs=load('hubs')
junctions=load('junctions')
# 위키 노선도에서 방향을 잘못 읽은 분기를 사람이 확인해 고친다. 같은 역에 폐지된 옛 선로가 함께 그려진 곳에서 생긴다
for _x in json.load(open(os.path.join(ROOT,'data','overrides','junction_side.json'),encoding='utf-8')):
    _hit=[j for j in junctions if (j['line'],j['other'],j.get('at'))==(_x['line'],_x['other'],_x['at'])]
    # 위키에 분기 기록이 없는 연결은 사람이 확인한 값으로 만든다
    if not _hit:
        _hit=[dict(line=_x['line'],other=_x['other'],at=_x['at'],source='hand',verified=True,valid=[None,'ongoing'])]
        junctions.append(_hit[0])
    for j in _hit:j['side']=_x['side']
services=load('services')
archive=load('archive')
names=load('names')
aliases=load('aliases')
# 노리츠부시 표의 계통 km. 사이트 내부 값이라 공개 데이터에 없고 로컬 후보 폴더에 있을 때만 대조한다
_n=os.path.join(CAND,'n_routes.json')
NROUTE=json.load(open(_n,encoding='utf-8')) if os.path.exists(_n) else {}
for e in edges.values():
    if e['a'] not in nodes or e['b'] not in nodes:err('edge_node',e['id'])
    if e['id'] not in kms:err('edge_no_km',e['id'])

adj=collections.defaultdict(list)
for e in edges.values():
    adj[e['a']].append(e);adj[e['b']].append(e)
def other(e,n):return e['b'] if e['a']==n else e['a']

def key(ev):
    lo,_=lohi(ev.get('date'));return (lo or '0000-00-00',{'open':0,'relocate':1,'transfer':2,'close':3}.get(ev['type'],4))
events.sort(key=key)

attr=[]     # 집계 멤버십
active=collections.defaultdict(list)  # edge -> 살아 있는 attr
life=[]     # edge_life
live={}     # edge -> 현재 life row
stopev=collections.defaultdict(list)  # (route,node) -> 사건
kmch=collections.defaultdict(list)
carryseq=[0];lineseq=[0]
def newc():
    carryseq[0]+=1;return f'c{carryseq[0]}'
def newl():
    lineseq[0]+=1;return f'lg{lineseq[0]}'
JR={o for o,v in ops.items() if v.get('category')=='jr'}

def scope_edges(line,route=None,mode='seed',alt=None):
    S=[]
    owned=bool(route and routes.get(route,{}).get('owned'))
    also=set(routes.get(route,{}).get('also',[])) if route else set()
    for e in edges.values():
        if alt!=e.get('alt'):continue
        ro=e.get('route_only')
        if route:
            if ro!=route and not (ro is None and (not owned or e['id'] in also)):continue
        elif ro:continue
        if mode=='seed':
            if e.get('seed_line')==line:S.append(e)
        else:
            if any(a['line']==line for a in []) or any(a['line_id']==line for a in active[e['id']]):S.append(e)
    return S

def path(a,b,S):
    if a==b:return []
    g=collections.defaultdict(list)
    for e in S:g[e['a']].append(e);g[e['b']].append(e)
    pq=[(0,a)];best={a:0};prev={}
    while pq:
        d,n=heapq.heappop(pq)
        if n==b:break
        if d>best.get(n,1e12):continue
        for e in g[n]:
            m=other(e,n);nd=d+kms.get(e['id'],0)+1e-4
            if nd<best.get(m,1e12):best[m]=nd;prev[m]=(n,e);heapq.heappush(pq,(nd,m))
    if b not in prev:return None
    o=[];n=b
    while n!=a:
        p,e=prev[n];o.append(e['id']);n=p
    return o[::-1]

_cache={}
def resolve(ev,specs,line,mode):
    out=[]
    for sp in specs:
        if sp in edges:out.append(sp);continue
        m=re.match(r'^(n_[^.@]+)\.\.(n_[^.@]+)(?:@(\w+))?$',sp)
        if not m:err('bad_range',sp);continue
        a,b,alt=m.groups()
        k=(line,ev.get('route'),mode,alt)
        S=scope_edges(line,ev.get('route'),mode,alt) if mode=='member' else _cache.setdefault(k,scope_edges(line,ev.get('route'),mode,alt))
        p=path(a,b,S)
        if p is None:
            err('range_unresolved',{'ev':ev.get('type'),'date':ev.get('date'),'spec':sp,'line':line});continue
        out+=p
    return out

def start(eid,line,op,date,lineage=None,carry=None,cls=None):
    l=lines[line]
    a=dict(edge_id=eid,line_id=line,operator_id=op,lineage_id=lineage or newl(),carryover_group=carry or newc(),denominator_class=cls or {'extra':'extra'}.get(l.get('rule_class'),'normal'),valid_from=date,valid_to='ongoing')
    attr.append(a);active[eid].append(a);return a
def stop(a,date):
    a['valid_to']=date
    if a in active[a['edge_id']]:active[a['edge_id']].remove(a)
def life_open(eid,date):
    if eid in live:return
    r=dict(edge_id=eid,valid_from=date,valid_to='ongoing',status='open',last_service=None,legal_abolition=None,close_reason=None)
    life.append(r);live[eid]=r
def life_close(eid,date,ev):
    r=live.pop(eid,None)
    if r:
        r['valid_to']=date;r['last_service']=ev.get('last_service');r['legal_abolition']=ev.get('legal_abolition') or (None if ev.get('reason')=='no_regular_service' else ev.get('date'));r['close_reason']=ev.get('reason','abolished')
for ev in events:
    t=ev['type'];d=ev.get('date')
    if t=='open':
        es=resolve(ev,ev['edges'],ev['line'],'seed')
        prev=None
        if ev.get('continues'):
            prev=ev['continues']
        for x in es:
            lin=None;car=None
            if prev:
                old=[a for a in attr if a['edge_id']==x and a['line_id']==prev]
                if old:
                    lin=old[-1]['lineage_id']
                    po=ops.get(old[-1]['operator_id'],{}).get('category');no=ops.get(ev['operator'],{}).get('category')
                    car=None if (po=='jr' and no!='jr') else old[-1]['carryover_group']
            start(x,ev['line'],ev['operator'],d,lin,car,ev.get('class'))
            life_open(x,d)
    elif t=='close':
        es=resolve(ev,ev['edges'],ev['line'],'member')
        vt=ev.get('valid_to') or d
        for x in es:
            for a in [a for a in active[x] if a['line_id']==ev['line']]:stop(a,vt)
            if not active[x]:life_close(x,vt,ev)
    elif t=='transfer':
        fr=ev.get('from');to=ev.get('to')
        line=(fr or {}).get('line') or ev.get('within')
        es=resolve(ev,ev['edges'],line,'member')
        for x in es:
            old=None
            if fr:
                for a in [a for a in active[x] if a['line_id']==fr['line'] and a['operator_id']==fr['operator']]:
                    old=a;stop(a,d)
                if not old:err('transfer_no_from',{'edge':x,'from':fr,'date':d})
            if to:
                if old:
                    po=ops[old['operator_id']].get('category');no=ops[to['operator']].get('category')
                    car=newc() if (po=='jr' and no!='jr') else old['carryover_group']
                    start(x,to['line'],to['operator'],d,old['lineage_id'],car,old['denominator_class'])
                else:
                    start(x,to['line'],to['operator'],d,None,None,ev.get('class'))
                life_open(x,d)
            elif not active[x]:
                life_close(x,d,ev)
    elif t=='relocate':
        for x in resolve(ev,ev['close'],ev['line'],'member'):
            for a in [a for a in active[x] if a['line_id']==ev['line']]:stop(a,d)
            if not active[x]:
                life_close(x,d,dict(ev,reason='relocated'))
        for x in resolve(ev,ev['open'],ev['line'],'seed'):
            start(x,ev['line'],ev['operator'],d);life_open(x,d)
    elif t=='suspend':
        for x in resolve(ev,ev['edges'],ev['line'],'member'):
            r=live.get(x)
            if r:r['valid_to']=d;live[x]=dict(r,valid_from=d,valid_to='ongoing',status='suspended');life.append(live[x])
    elif t=='resume':
        for x in resolve(ev,ev['edges'],ev['line'],'member'):
            r=live.get(x)
            if r:r['valid_to']=d;live[x]=dict(r,valid_from=d,valid_to='ongoing',status='open');life.append(live[x])
    elif t=='set_class':
        for x in resolve(ev,ev['edges'],ev['line'],'member'):
            for a in [a for a in active[x] if a['line_id']==ev['line']]:
                stop(a,d);start(x,a['line_id'],a['operator_id'],d,a['lineage_id'],a['carryover_group'],ev['class'])
    elif t in('open_stop','close_stop'):
        stopev[(ev['route'],ev['node'])].append(ev)
    elif t=='km_change':
        for x in ev['edges']:kmch[x].append(ev)
    elif t=='rename':pass
    else:err('unknown_event',t)

# 계통의 edge 묶음과 순서
own=collections.defaultdict(list)
for e in edges.values():
    if e.get('route_only'):own[e['route_only']].append(e)
line_e=collections.defaultdict(set)
for a in attr:line_e[a['line_id']].add(a['edge_id'])
route_edges={};route_rank={}
for r in routes.values():
    tagged=own.get(r['id'],[])
    if r.get('role')=='branch' or r.get('owned'):
        S=list(tagged)+[edges[x] for x in r.get('also',[])]
    else:
        U=[edges[x] for x in sorted(line_e[r['line']]) if not edges[x].get('route_only') or edges[x]['route_only']==r['id']]
        U=[e for e in U if e.get('alt')!='old']
        pts=[r['from']]+r.get('via',[])+[r['to']]
        p=[]
        for i in range(len(pts)-1):
            q=path(pts[i],pts[i+1],U)
            if q is None:
                err('route_no_path',{'route':r['id'],'from':pts[i],'to':pts[i+1]});q=[]
            p+=q
        S=[edges[x] for x in p]+[e for e in tagged if e['id'] not in p]
    route_edges[r['id']]=S
    tot=sum(kms.get(e['id'],0) for e in S if e.get('alt')!='old')
    nk=NROUTE.get(r['id'],{}).get('km')
    if nk and abs(tot-nk)>.15 and not r.get('also'):WARN['route_km'].append({'route':r['id'],'calc':round(tot,1),'n':nk})
    g=collections.defaultdict(list)
    for e in S:g[e['a']].append(e);g[e['b']].append(e)
    def relax(dist,alts):
        pq=[(v,k) for k,v in dist.items()];heapq.heapify(pq)
        while pq:
            d,n=heapq.heappop(pq)
            if d>dist.get(n,1e12):continue
            for e in g[n]:
                if (e.get('alt')=='old')!=alts:continue
                m=other(e,n);nd=d+kms.get(e['id'],0)
                if nd<dist.get(m,1e12) and not (alts and m in fixed):dist[m]=nd;heapq.heappush(pq,(nd,m))
    dist={r['from']:0.0};fixed=set()
    relax(dist,False)
    fixed=set(dist)
    relax(dist,True)
    route_rank[r['id']]=dist
    if S and len(dist)<len(g):err('route_disconnected',{'route':r['id'],'nodes':len(g),'reach':len(dist)})

def fin(x):return x if x not in (None,) else None
stops=[]
for r in routes.values():
    dist=route_rank[r['id']]
    order=sorted(dist.items(),key=lambda x:(round(x[1],3)))
    if r.get('closed') and r.get('seq'):
        ek={}
        for e in route_edges[r['id']]:ek.setdefault(tuple(sorted((e['a'],e['b']))),[]).append(e)
        order=[];run=0.0
        for i,n in enumerate(r['seq']):
            if i:
                L=ek.get(tuple(sorted((r['seq'][i-1],n))),[])
                if L:run+=kms.get(L[0]['id'],0)
            order.append((n,run))
    elist=route_edges[r['id']]
    attrs=collections.defaultdict(list)
    for a in attr:
        if a['line_id']==r['line']:attrs[a['edge_id']].append(a)
    for seq,(n,km) in enumerate(order):
        nd=nodes.get(n)
        if not nd:continue
        evs=stopev.get((r['id'],n),[])
        fromv=None;tov='ongoing'
        for e in adj[n]:
            for a in attrs.get(e['id'],[]):
                pass
        ope=[e for e in evs if e['type']=='open_stop'];cle=[e for e in evs if e['type']=='close_stop']
        vals=[a for e in adj[n] if e in elist for a in attrs.get(e['id'],[])]
        if ope:fromv=ope[0].get('date')
        elif vals:
            los=[(lohi(a['valid_from'])[0] or '0000',a['valid_from']) for a in vals];fromv=min(los)[1]
        if cle:tov=cle[-1].get('date')
        elif vals:
            his=[(lohi(a['valid_to'])[1] or '9999-12-30',a['valid_to']) for a in vals];tov=max(his)[1]
        stop_flag=0 if (nd['kind'] in('signal','junction','pref_boundary','freight') or r.get('nostop',{}).get(n)) else 1
        if n in set(r.get('hidden_stops',[])):stop_flag=0
        if cle and vals:
            mx=max(((lohi(a['valid_to'])[1] or '9999-12-30'),a['valid_to']) for a in vals)
            if (lohi(tov)[1] or '')>mx[0]:tov=mx[1]
        stops.append(dict(route_id=r['id'],seq=seq,node_id=n,km_cum=round(km,1),is_stop=stop_flag,is_extension=0,valid_from=fromv,valid_to=tov))

# 문서에서 옮긴 역 기간. 역 문서 연결이 안 되는 곳
for k_,v_ in json.load(open(os.path.join(ROOT,'data','overrides','stop_dates.json'),encoding='utf-8')).items():
    rid_,nd_=k_.split('|') if '|' in k_ else (None,k_)
    for s in stops:
        if s['node_id']==nd_ and (not rid_ or s['route_id']==rid_):
            if v_[0]:s['valid_from']=v_[0]
            if v_[1]:s['valid_to']=v_[1]
            if s['valid_to'] and (lohi(s['valid_from'])[0] or '0000')>=(lohi(s['valid_to'])[1] or '9999-12-31'):s['is_stop']=0
# 역 이전: km가 달라 노드는 둘이지만 같은 역이다. 정차 기간을 이전일에서 가르고 묶음을 합친다
for mv in json.load(open(os.path.join(ROOT,'data','overrides','moved.json'),encoding='utf-8')):
    old,new,d=mv['old'],mv['new'],mv['date']
    for s in stops:
        if s['node_id']==old:
            if (lohi(s['valid_from'])[0] or '0000')>=d:s['is_stop']=0
            else:s['valid_to']=d
        elif s['node_id']==new:
            if (lohi(s['valid_to'])[1] or '9999-12-31')<=d:s['is_stop']=0
            else:s['valid_from']=d
    g_old,g_new=nodes[old]['group'],nodes[new]['group']
    for n_ in nodes.values():                            # 새 노드의 묶음에 있던 다른 노드도 함께 옮긴다
        if n_.get('group')==g_new:n_['group']=g_old
# 구간 시작일. 여객 영업이 늦게 시작했거나 끝 역과 함께 열린 구간
for k_,v_ in json.load(open(os.path.join(ROOT,'data','overrides','edge_dates.json'),encoding='utf-8')).items():
    x_=set(k_.split('|'))
    es=[e for e in edges.values() if {e['a'],e['b']}==x_]
    assert len(es)==1,k_
    for rows_ in (attr,life):
        first=min((r for r in rows_ if r['edge_id']==es[0]['id']),key=lambda r:lohi(r['valid_from'])[0] or '')
        first['valid_from']=v_
# 분모
def overlap_year(a,y):
    lo=lohi(a['valid_from'])[0] or '0000-00-00';hi=lohi(a['valid_to'])[1] or '9999-12-30'
    return lo<=f'{y}-12-31' and hi>f'{y}-01-01'
def active_on(a,day):
    lo=lohi(a['valid_from'])[0] or '0000-00-00';hi=lohi(a['valid_to'])[0] or '9999-12-31'
    return lo<=day<hi
units=collections.defaultdict(list)
for a in attr:
    units[('on',a['lineage_id'],a['edge_id'])].append(a)
    units[('off',a['carryover_group'],a['edge_id'])].append(a)
unit_rows=[]
for (c,k,x),rows in units.items():
    cls='normal' if any(a['denominator_class']=='normal' for a in rows) else rows[0]['denominator_class']
    vf=min((lohi(a['valid_from'])[0] or '0000-00-00',a['valid_from'] or '') for a in rows)[1] or None
    vt=max((lohi(a['valid_to'])[1] or '9999-12-30',a['valid_to'] or '') for a in rows)[1] or None
    unit_rows.append(dict(unit_key=f'{k}:{x}',carryover=c,edge_id=x,km=kms.get(x,0),cls=cls,valid_from=vf,valid_to=vt))
cur=collections.Counter();curop=collections.Counter();curline=collections.Counter();alltime=collections.Counter()
for a in attr:
    if a['denominator_class']=='normal' and active_on(a,TODAY):
        k=kms.get(a['edge_id'],0)
        curop[a['operator_id']]+=k;curline[a['line_id']]+=k
for u in unit_rows:
    if u['cls']=='normal':alltime[u['carryover']]+=u['km']
cuniq={}
for a in attr:
    if a['denominator_class']=='normal' and active_on(a,TODAY):cuniq[(a['lineage_id'],a['edge_id'])]=kms.get(a['edge_id'],0)
denom=[dict(scope='all',basis='current',carryover='on',km=round(sum(cuniq.values()),1),unit_count=len(cuniq)),
       dict(scope='all',basis='alltime',carryover='on',km=round(alltime['on'],1),unit_count=sum(1 for u in unit_rows if u['carryover']=='on' and u['cls']=='normal')),
       dict(scope='all',basis='alltime',carryover='off',km=round(alltime['off'],1),unit_count=sum(1 for u in unit_rows if u['carryover']=='off' and u['cls']=='normal'))]
for y in range(1970,int(TODAY[:4])+1):
    s={}
    for a in attr:
        if a['denominator_class']=='normal' and overlap_year(a,y):s[(a['lineage_id'],a['edge_id'])]=kms.get(a['edge_id'],0)
    denom.append(dict(scope='all',basis=str(y),carryover='on',km=round(sum(s.values()),1),unit_count=len(s)))
for o,k in curop.items():denom.append(dict(scope=o,basis='current',carryover='on',km=round(k,1),unit_count=None))
for l,k in curline.items():denom.append(dict(scope=l,basis='current',carryover='on',km=round(k,1),unit_count=None))

# route_link: 표시 결정표 (§2.9)
import math
ppos={p['node']:p for p in positions if p.get('lat') is not None}
node_stops=collections.defaultdict(list)
by_route=collections.defaultdict(list)
for s in stops:
    by_route[s['route_id']].append(s)
    if s['is_stop']:node_stops[s['node_id']].append(s)
for v in by_route.values():v.sort(key=lambda s:s['seq'])
hubmem=collections.defaultdict(set)
for h in hubs:
    for n in h['nodes']:hubmem[n].add(h['id'])
hubn={h['id']:h['nodes'] for h in hubs}
jx=collections.defaultdict(list)
for j in junctions:
    if j.get('at'):jx[(j['line'],j['at'])].append(j)
def vec(a,b):
    p,q=ppos.get(a),ppos.get(b)
    if not p or not q:return None
    return (q['lat']-p['lat'],(q['lon']-p['lon'])*math.cos(math.radians(p['lat'])))
openpair=collections.defaultdict(set)
for a_ in attr:
    if a_['valid_to']=='ongoing':openpair[a_['line_id']].add(frozenset((edges[a_['edge_id']]['a'],edges[a_['edge_id']]['b'])))
def is_cur(s):return s['valid_to']=='ongoing'
def walk(rid,seq,step,cur):
    """seq에서 한 방향으로 다음 정차역과 끝 역을 찾는다. cur이면 오늘 영업 구간 안에서만 본다"""
    L=by_route[rid];i=next((k for k,x in enumerate(L) if x['seq']==seq),None)
    if i is None:return None,None
    op=openpair[routes[rid]['line']];nxt=last=None;k=i+step
    while 0<=k<len(L):
        if cur and frozenset((L[k]['node_id'],L[k-step]['node_id'])) not in op:break
        if L[k]['is_stop'] and (not cur or is_cur(L[k])):
            if not nxt:nxt=L[k]['node_id']
            last=L[k]['node_id']
        k+=step
    return nxt,last
def neighbors(rid,seq,cur=False):
    return walk(rid,seq,-1,cur),walk(rid,seq,1,cur)
def period(s,o):
    """두 정차 기간의 겹침. 겹치지 않으면 None"""
    f=max((s['valid_from'],o['valid_from']),key=lambda x:lohi(x)[0] or '0000')
    t=min((s['valid_to'],o['valid_to']),key=lambda x:(lohi(x)[1] or '9999-12-31') if x else '9999-12-30')
    if (lohi(f)[1] or '0000')>=((lohi(t)[0] or '9999-12-31') if t else '9999-12-30'):return None
    return f,t
def flow_of(s,o):
    cur=is_cur(o)
    pr,nx=neighbors(o['route_id'],o['seq'],cur)
    if pr[0] and nx[0]:return 'through','route',None,None
    other=pr if pr[0] else nx
    if not other[0]:return 'unknown',None,None,None
    v=vec(s['node_id'],other[0])
    mp,mn=neighbors(s['route_id'],s['seq'],is_cur(s))
    best=None
    if v:
        du=dd=None
        if mp[0]:
            w=vec(s['node_id'],mp[0])
            if w:du=v[0]*w[0]+v[1]*w[1]
        if mn[0]:
            w=vec(s['node_id'],mn[0])
            if w:dd=v[0]*w[0]+v[1]*w[1]
        if du is not None or dd is not None:
            best='up' if (dd is None or (du is not None and du>dd)) else 'down'
    return best or 'unknown','coord' if best else None,other[0],other[1]
def hav_km(a,b):
    p,q=ppos.get(a),ppos.get(b)
    if not p or not q:return 9.0
    return math.hypot((p['lat']-q['lat'])*111,(p['lon']-q['lon'])*111*math.cos(math.radians(p['lat'])))
def pick(cand,s):
    """같은 노선의 후보 정차 행 중 표시할 하나. 오늘 상태가 같은 것, 가까운 것, 지나가는 것 순"""
    n=s['node_id']
    def key(c):
        o,m=c
        pr,nx=neighbors(o['route_id'],o['seq'],is_cur(o))
        return (is_cur(o)!=is_cur(s),m!=n,round(hav_km(n,m),3),not(pr[0] and nx[0]),o['route_id'],o['seq'])
    return min(cand,key=key)
# 상대 노선의 끝 역이면 그쪽 화면에서는 이어짐이다. 위키에 한쪽만 그려져 있어도 양쪽을 만든다
for j in list(junctions):
    if j.get('at') and j['other']!=j['line'] and not any(x['other']==j['line'] for x in jx.get((j['other'],j['at']),[])):
        jx[(j['other'],j['at'])].append(dict(line=j['other'],other=j['line'],at=j['at'],implied=True))
# 묶음은 사슬로 이어지므로 같은 묶음이라고 다 환승이 아니다 (日本橋~三越前~新日本橋). 문서 근거가 있거나 가까운 쌍만 환승이다
EVID={frozenset(p_) for p_ in json.load(open(os.path.join(SRC,'hubs','hub_evidence.json'),encoding='utf-8'))['evid']}
HUBX={frozenset(p_) for p_ in json.load(open(os.path.join(ROOT,'data','overrides','hub_pairs.json'),encoding='utf-8'))}
JA={x['id']:x['text'] for x in names if x['entity_type']=='node' and x['lang']=='ja' and not x.get('valid_to') and not x.get('line')}
HUBNOT={frozenset(p_) for p_ in json.load(open(os.path.join(ROOT,'data','overrides','hub_not.json'),encoding='utf-8'))}
def linked(a,b):
    if frozenset((JA.get(a),JA.get(b))) in HUBNOT:return False
    return a==b or nodes[a].get('group')==nodes[b].get('group') or frozenset((a,b)) in EVID or hav_km(a,b)<.35 or frozenset((JA.get(a),JA.get(b))) in HUBX
links=[]
def add_link(s,oid,rr,kind,side,other,nxt,term,fl,src,pd):
    links.append(dict(route_id=s['route_id'],seq=s['seq'],other_line_id=oid,other_route_id=rr,kind=kind,side=side,at_edge=0,other_node=other,next_stop_node=nxt,terminal_node=term,flow=fl,flow_source=src,valid_from=pd[0],valid_to=pd[1]))
for s in stops:
    if not s['is_stop']:continue
    r=routes[s['route_id']];n=s['node_id'];seen=set();cur=is_cur(s)
    mp,mn=neighbors(r['id'],s['seq'],cur)
    isend=not(mp[0] and mn[0])
    near={n}
    for h in sorted(hubmem.get(n,())):near|={m for m in hubn[h] if linked(n,m)}
    near=sorted(near,key=lambda x:(x!=n,x))
    def group_near(m):return m if m!=n and nodes[m].get('group')!=nodes[n].get('group') else None
    J=list(jx.get((r['line'],n),[]))
    for j in J:
        oid=j['other'];rr=j.get('other_route')
        if rr==r['id'] or (oid==r['line'] and not rr):continue
        cand=[(o,m) for m in near for o in node_stops.get(m,()) if routes[o['route_id']]['line']==oid and o['route_id']!=r['id'] and (not rr or o['route_id']==rr)]
        cand=[c for c in cand if period(s,c[0])]
        if not cand:continue
        if isend:kind='continue'
        elif j.get('implied') or (j.get('continue') and not j.get('side')):
            o_,_m=pick(cand,s);pr_,nx_=neighbors(o_['route_id'],o_['seq'],is_cur(o_))
            if pr_[0] and nx_[0]:continue                # 상대도 지나가는 역이면 환승으로 둔다
            kind='branch'
        else:kind='branch'
        o,m=pick(cand,s);pd=period(s,o);oc=is_cur(o)
        pr,nx=neighbors(o['route_id'],o['seq'],oc)
        seen.add(oid)
        if pr[0] and nx[0]:
            if kind=='continue':
                add_link(s,oid,rr,kind,None,group_near(m),pr[0],pr[1],None,None,pd)
                add_link(s,oid,rr,kind,None,group_near(m),nx[0],nx[1],None,None,pd)
                continue
            own=mp if j.get('side')=='up' else mn
            w=vec(n,own[0]) if own[0] else None
            def dot(q):
                v=vec(m,q)
                return v[0]*w[0]+v[1]*w[1] if v and w else 0
            nxt,term=(pr if dot(pr[0])>dot(nx[0]) else nx)
        else:
            nxt,term=pr if pr[0] else nx
        add_link(s,oid,rr,kind,j.get('side'),group_near(m),nxt,term,None,None,pd)
    # 지선 끝에서 같은 노선의 다른 계통으로 이어진다
    if isend:
        for o in node_stops.get(n,()):
            if routes[o['route_id']]['line']==r['line'] and o['route_id']!=r['id'] and o['route_id'] not in seen:
                pd=period(s,o)
                if not pd:continue
                pr,nx=neighbors(o['route_id'],o['seq'],is_cur(o))
                seen.add(o['route_id'])
                for x in ([pr,nx] if pr[0] and nx[0] else [pr if pr[0] else nx]):
                    if x[0]:add_link(s,r['line'],o['route_id'],'continue',None,None,x[0],x[1],None,None,pd)
    by={}
    for m in near:
        for o in node_stops.get(m,()):
            ol=routes[o['route_id']]['line']
            if ol==r['line'] or ol in seen or not period(s,o):continue
            by.setdefault(ol,[]).append((o,m))
    for ol,cand in sorted(by.items()):
        o,m=pick(cand,s)
        fl,src,nxt,term=flow_of(s,o)
        add_link(s,ol,o['route_id'],'transfer',None,group_near(m),nxt,term,fl,src,period(s,o))

# 숨은 노드에서 갈라지는 노선은 부모 계통의 위쪽 역에 at_edge 행으로 둔다
for rid,L in by_route.items():
    for i,x in enumerate(L):
        if x['is_stop'] or i==0 or i==len(L)-1:continue
        up=next((y for y in reversed(L[:i]) if y['is_stop']),None);dn=next((y for y in L[i+1:] if y['is_stop']),None)
        if not up or not dn:continue
        for rid2,L2 in by_route.items():
            if rid2==rid or routes[rid2]['line']==routes[rid]['line']:continue
            for e_,f_ in ((L2[0],1),(L2[-1],-1)):
                if e_['node_id']!=x['node_id'] or e_['is_stop']:continue
                v=[y for y in (L2 if f_==1 else L2[::-1]) if y['is_stop']]
                if not v:continue
                pd=period(up,v[0])
                if pd:links.append(dict(route_id=rid,seq=up['seq'],other_line_id=routes[rid2]['line'],other_route_id=rid2,kind='branch',side=None,at_edge=1,other_node=None,next_stop_node=v[0]['node_id'],terminal_node=v[-1]['node_id'],flow=None,flow_source=None,valid_from=pd[0],valid_to=pd[1]))
# 끝이 숨은 노드인 계통: 그 너머의 역을 선택기에 함께 보인다 (§2.7 extend_to). km는 표시하지 않는다
EXT=json.load(open(os.path.join(ROOT,'data','overrides','extend.json'),encoding='utf-8'))
pub0={s['node_id'] for s in stops if s['is_stop']}
for rid,v in EXT.items():
    L=by_route[rid];r=routes[rid];r['extend_to']=v.get('start',[])+v.get('end',[])
    for side,tg in (('start',v.get('start',[])),('end',v.get('end',[]))):
        h=L[0] if side=='start' else L[-1]
        for k,n in enumerate(tg):
            if n not in pub0:err('extend_to',(rid,n));continue
            seq=-1-k if side=='start' else L[-1]['seq']+1+k
            stops.append(dict(route_id=rid,seq=seq,node_id=n,km_cum=None,is_stop=1,is_extension=1,valid_from=v.get('from') or h['valid_from'],valid_to=h['valid_to']))

# 검사
for x,e in edges.items():
    if not any(a['edge_id']==x for a in attr):err('edge_no_attr',x)
sim=collections.defaultdict(list)
for a in attr:sim[(a['line_id'],a['edge_id'])].append(a)
for k,v in sim.items():
    v=sorted(v,key=lambda a:lohi(a['valid_from'])[0] or '0000')
    for p,q in zip(v,v[1:]):
        if (lohi(p['valid_to'])[0] or '9999')>(lohi(q['valid_from'])[0] or '0000'):err('overlap_attr',k)
for n in nodes:
    if not adj[n]:err('node_unused',n)
pub=set()
for s in stops:
    if s['is_stop']:pub.add(s['node_id'])
sname={x['id'] for x in names if x['entity_type']=='node' and x['lang']=='ko' and not x.get('line')}
for n in pub:
    if n not in sname:err('node_no_ko',n)
lname={x['id'] for x in names if x['entity_type']=='line' and x['lang']=='ko'}
for l in lines:
    if l not in lname:err('line_no_ko',l)
kana=re.compile('[぀-ヿ一-鿿]')
for x in names:
    if x['lang']=='ko' and kana.search(x['text']):err('ko_has_japanese',x['text'])

# 쓰기
os.makedirs(BUILD,exist_ok=True)
# 노드가 정차역이 되기 전에 끝난 옛 이름은 동명 역 문서에서 온 것이다. 화면에 나올 날도 없다
first_stop={}
for s in stops:
    if s['is_stop']:
        lo=lohi(s['valid_from'])[0] or '0000-00-00'
        first_stop[s['node_id']]=min(first_stop.get(s['node_id'],lo),lo)
names=[x for x in names if not(x['entity_type']=='node' and x.get('valid_to') and x['id'] in first_stop and (lohi(x['valid_to'])[1] or '9999')<=first_stop[x['id']])]
mp=os.path.join(BUILD,'master.sqlite');np_=os.path.join(BUILD,'names.sqlite')
for p in (mp,np_):
    if os.path.exists(p):os.remove(p)
db=sqlite3.connect(mp)
def t(name,cols,rows):
    db.execute(f'create table {name} ({",".join(cols)})')
    db.executemany(f'insert into {name} values ({",".join("?"*len(cols))})',rows)
def per(name,e):
    return (e,)+lohi(e)
t('operator',['id primary key','category'],[(o['id'],o.get('category')) for o in ops.values()])
t('line',['id primary key','type','rule_class'],[(l['id'],l.get('type'),l.get('rule_class')) for l in lines.values()])
t('station_group',['id primary key','n'],[(g['id'],i+1) for i,g in enumerate(x for x in groups if x['id'] in {n['group'] for n in nodes.values() if n.get('group')})])
t('node',['id primary key','kind','group_id','pref','export_name'],[(n['id'],n['kind'],n.get('group'),n.get('pref'),n.get('export_name')) for n in nodes.values()])
t('hub',['id primary key','source','verified'],[(h['id'],json.dumps(h.get('source'),ensure_ascii=False),int(bool(h.get('verified')))) for h in hubs])
t('hub_member',['hub_id','node_id'],[(h['id'],n) for h in hubs for n in h['nodes']])
t('junction',['line_id','other_line_id','other_route_id','node_id','edge_id','side','is_continue','valid_from','valid_to','source','verified'],[(j['line'],j['other'],j.get('other_route'),j.get('at'),j.get('edge'),j.get('side'),int(bool(j.get('continue'))),j.get('valid',[None,'ongoing'])[0],j.get('valid',[None,'ongoing'])[1],j.get('source'),int(bool(j.get('verified')))) for j in junctions])
t('node_position',['node_id','lat','lon','quality','checked','source'],[(p['node'],p.get('lat'),p.get('lon'),p.get('quality'),p.get('checked'),p.get('source')) for p in positions])
def coverage_of(rid):
    S=route_edges.get(rid,[])
    if not S:return 'none'
    h=sum(1 for e in S if e['id'] in GEO)
    return 'full' if h==len(S) else ('none' if h==0 else 'partial')
GEO={g['edge'] for g in load_geo()}
GEO_ALL={g['edge']:g for g in load('geometry')} # OSM 선형까지. 지도에 선이 있는가를 본다
DRAWN=set(GEO_ALL)
t('route',['id primary key','line_id','role','from_node','to_node','via_nodes','closed','closed_from','extend_to','map_coverage'],[(r['id'],r['line'],r.get('role'),r['from'],r['to'],json.dumps(r.get('via',[])),int(bool(r.get('closed'))),r.get('closed_from'),json.dumps(r.get('extend_to',[])),coverage_of(r['id'])) for r in routes.values()])
t('route_edge',['route_id','seq','edge_id'],[(rid,i,e['id']) for rid,S in route_edges.items() for i,e in enumerate(S)])
t('route_stop',['route_id','seq','node_id','km_cum','is_stop','is_extension','valid_from','valid_from_lo','valid_from_hi','valid_to','valid_to_lo','valid_to_hi'],[(s['route_id'],s['seq'],s['node_id'],s['km_cum'],s['is_stop'],s['is_extension'])+per(0,s['valid_from'])+per(0,s['valid_to']) for s in stops])
# 빈 분기 방향은 역 좌표로 채운다. 앞 역에서 곧장 가는 쪽이 분기 쪽이다 (설계 §8.1)
# 값이 있는 296행에 대보면 각도 차 0.6rad 이상에서 95% 맞는다. 그보다 애매하면 비워 둔다
def bearing(a,c):return math.atan2((c[1]-a[1])*math.cos(math.radians(a[0])),c[0]-a[0])
def turn(x,y):
    d=abs(x-y)%(2*math.pi);return min(d,2*math.pi-d)
by_route=collections.defaultdict(list)
for x in sorted(stops,key=lambda x:x['seq']):by_route[x['route_id']].append(x)
def where_node(n):
    p=ppos.get(n)
    return (p['lat'],p['lon']) if p else None
def side_of(k):
    L=by_route[k['route_id']]
    at=[i for i,x in enumerate(L) if x['seq']==k['seq']]
    if not at or at[0]==0 or at[0]==len(L)-1:return None
    i=at[0];A,S,B=(where_node(L[j]['node_id']) for j in (i-1,i,i+1));C=where_node(k.get('next_stop_node'))
    if not (A and S and B and C):return None
    go=bearing(S,C);up=turn(bearing(A,S),go);dn=turn(bearing(B,S),go)
    return None if abs(up-dn)<.6 else ('down' if up<dn else 'up')
filled=0
for k in links:
    if k['kind']=='branch' and not k.get('side') and not k.get('at_edge'):
        k['side']=side_of(k);filled+=bool(k['side'])
print('분기 방향 채움',filled)
# 방향을 아는 행이 있으면 같은 곳으로 가는 방향 없는 행은 뺀다. 앱은 방향이 없으면 아래쪽에 그려서
# 위키에 분기로, 끝 역 규칙으로 이어짐으로 두 번 들어온 노선이 양쪽에 나온다 (南千歳의 石勝線)
_sided={(l['route_id'],l['seq'],l['other_line_id'],l['other_route_id'],l['next_stop_node']) for l in links if l['side']}
_before=len(links)
links=[l for l in links if l['side'] or (l['route_id'],l['seq'],l['other_line_id'],l['other_route_id'],l['next_stop_node']) not in _sided]
print('방향 없는 중복 환승 행 뺌',_before-len(links))
# 위키와 끝 역 규칙에서 똑같은 행이 두 번 나오면 하나만 둔다
_seen=set();_dup=0;_kept=[]
for l in links:
    k=tuple(sorted((x,str(y)) for x,y in l.items()))
    if k in _seen:_dup+=1;continue
    _seen.add(k);_kept.append(l)
links=_kept
print('같은 환승 행 합침',_dup)
t('route_link',['route_id','seq','other_line_id','other_route_id','kind','side','at_edge','other_node','next_stop_node','terminal_node','flow','flow_source','valid_from','valid_to'],[(l['route_id'],l['seq'],l['other_line_id'],l['other_route_id'],l['kind'],l['side'],l['at_edge'],l['other_node'],l['next_stop_node'],l['terminal_node'],l['flow'],l['flow_source'],l['valid_from'],l['valid_to']) for l in links])
succ={frozenset((e['a'],e['b'])):e['id'] for e in edges.values() if e.get('alt')!='old'}
t('edge_link',['edge_id','successor_edge_id','kind'],[(e['id'],succ.get(frozenset((e['a'],e['b']))),'relocate') for e in edges.values() if e.get('alt')=='old'])
geo={g['edge'] for g in load_geo()}
t('edge',['id primary key','n','from_node','to_node','seed_line','route_only','geometry_quality'],[(e['id'],int(e['id'][2:]),e['a'],e['b'],e.get('seed_line'),e.get('route_only'),'precise' if e['id'] in geo else 'none') for e in edges.values()])
t('edge_life',['edge_id','valid_from','valid_from_lo','valid_from_hi','valid_to','valid_to_lo','valid_to_hi','status','last_service','legal_abolition','close_reason'],[(r['edge_id'],)+per(0,r['valid_from'])+per(0,r['valid_to'])+(r['status'],r['last_service'],r['legal_abolition'],r['close_reason']) for r in life])
t('edge_km',['edge_id','km','m'],[(k,v,round(v*1000)) for k,v in kms.items()])
t('edge_attr',['edge_id','line_id','operator_id','lineage_id','carryover_group','denominator_class','valid_from','valid_from_lo','valid_from_hi','valid_to','valid_to_lo','valid_to_hi'],[(a['edge_id'],a['line_id'],a['operator_id'],a['lineage_id'],a['carryover_group'],a['denominator_class'])+per(0,a['valid_from'])+per(0,a['valid_to']) for a in attr])
def arch_route(a):
    """이웃 역이 있는 계통에 건다"""
    for x in (a.get('after'),a.get('before')):
        if x and any(s['node_id']==x for s in by_route.get(a.get('route'),[])):return a.get('route')
    for rid,L in by_route.items():
        if routes[rid]['line']==a.get('line') and any(s['node_id'] in (a.get('after'),a.get('before')) for s in L):return rid
    return a.get('route')
t('service',['id primary key','closed','valid_from','valid_to'],[(s['id'],int(bool(s.get('closed'))),(s.get('valid') or [None,'ongoing'])[0],(s.get('valid') or [None,'ongoing'])[1]) for s in services])
t('service_part',['service_id','seq','route_id','from_node','to_node'],[(s['id'],i,p.get('route'),p.get('from'),p.get('to')) for s in services for i,p in enumerate(s.get('parts',[]))])
t('archive_stop',['id primary key','line_id','route_id','after_id','before_id','opened','closed','km','source'],[(a['id'],a.get('line'),arch_route(a),a.get('after'),a.get('before'),a.get('opened'),a.get('closed'),a.get('km'),a.get('source')) for a in archive if a.get('kind')=='stop'])
t('archive_line',['id primary key','line_id','at_node','opened','closed','source'],[(a['id'],a.get('line'),a.get('at'),a.get('opened'),a.get('closed'),a.get('source')) for a in archive if a.get('kind')=='line'])
t('denominator',['scope','basis','carryover','km','unit_count'],[(d['scope'],d['basis'],d['carryover'],d['km'],d['unit_count']) for d in denom])
t('denominator_unit',['n','unit_key','carryover','edge_id','km','m','class','valid_from','valid_to','date_lo','date_hi','certainty'],[(i+1,u['unit_key'],u['carryover'],u['edge_id'],u['km'],round(u['km']*1000),u['cls'],u['valid_from'],u['valid_to'],lohi(u['valid_from'])[0],lohi(u['valid_to'])[1],'unknown' if not u['valid_from'] or not u['valid_to'] else 'certain') for i,u in enumerate(unit_rows)])
# 파생: 폐지 구간, 도도부현별 km, 수록 등급
closed_rows=[]
closed_life=collections.defaultdict(list)
for r in life:
    if r['close_reason']:closed_life[r['edge_id']].append(r)
last={}
for a in attr:
    k=(a['lineage_id'],a['edge_id'])
    if k not in last or (lohi(a['valid_to'])[1] or '')>(lohi(last[k]['valid_to'])[1] or ''):last[k]=a
for a in last.values():
    if a['valid_to']!='ongoing':
        e=edges[a['edge_id']];lf=closed_life.get(e['id'],[])
        ab=(lf[-1]['legal_abolition'] if lf else None) or a['valid_to'];ls=lf[-1]['last_service'] if lf else None
        closed_rows.append((a['line_id'],e['a'],e['b'],kms.get(e['id'],0),ab,ls,int(e['id'] in DRAWN)))
t('closed_section',['line_id','from_node','to_node','km','abolished','last_service','map_visible'],closed_rows)
# 위치 미확인 표식 (DESIGN §7.3). 모르는 곳에 선을 긋지 않고, 마지막 확인 역에서 그쪽 방향만 알린다
def _bearing(a,b):
    la,lo=math.radians(a[0]),math.radians(a[1]);lb,lp=math.radians(b[0]),math.radians(b[1])
    y=math.sin(lp-lo)*math.cos(lb);x=math.cos(la)*math.sin(lb)-math.sin(la)*math.cos(lb)*math.cos(lp-lo)
    return round(math.degrees(math.atan2(y,x))%360,1)
_at={p['node']:(p['lat'],p['lon']) for p in positions if p.get('lat') is not None and p.get('quality')!='none'}
_runs=collections.defaultdict(list)
for a in last.values():
    if a['valid_to']=='ongoing':continue
    e=edges[a['edge_id']]
    if e['id'] in DRAWN:continue
    _runs[a['line_id']].append(e)
_touch=collections.defaultdict(list)
for g in GEO_ALL.values():
    e=edges.get(g['edge'])
    if not e or not g.get('coords'):continue
    c=g['coords']
    # 선로의 마지막 진행 방향. 좌표는 [경도, 위도]다
    _touch[e['a']].append(((c[min(3,len(c)-1)][1],c[min(3,len(c)-1)][0]),(c[0][1],c[0][0])))
    _touch[e['b']].append(((c[max(-4,-len(c))][1],c[max(-4,-len(c))][0]),(c[-1][1],c[-1][0])))
marker_rows=[]
closed_lines=set()
for line,items in sorted(_runs.items()):
    # 이어진 구간끼리 묶는다
    left=list(items)
    while left:
        run=[left.pop()];nodes_in={run[0]['a'],run[0]['b']}
        grown=True
        while grown:
            grown=False
            for e in list(left):
                if e['a'] in nodes_in or e['b'] in nodes_in:
                    run.append(e);left.remove(e);nodes_in|={e['a'],e['b']};grown=True
        anchors=sorted(n for n in nodes_in if n in _touch and n in _at)
        ends=[r for r in closed_rows if r[0]==line and any(r[1]==e['a'] and r[2]==e['b'] for e in run)]
        for n in anchors:
            first=[e for e in run if n in (e['a'],e['b'])][0]
            other=first['b'] if first['a']==n else first['a']
            if other in _at:bearing=_bearing(_at[n],_at[other])
            else:
                back,tip=_touch[n][0]
                bearing=_bearing(back,tip)
            # 반대쪽 확인 역이 있으면 그 역이고, 없으면 구간의 끝 역이다
            degree=collections.Counter(x for e in run for x in (e['a'],e['b']))
            far=max(nodes_in-{n},key=lambda x:(x in anchors,degree[x]==1,x))
            km=round(sum(kms.get(e['id'],0) for e in run),1)
            ab=max((r[4] or '' for r in ends),default='') or None
            marker_rows.append((len(marker_rows)+1,n,bearing,line,far,km,ab,json.dumps(sorted(int(e['id'][2:]) for e in run))))
t('map_marker',['id integer primary key','anchor_node','bearing','line_id','to_node','km','abolished','edges'],marker_rows)
pr=[]
for e in edges.values():
    a,b=nodes[e['a']].get('pref'),nodes[e['b']].get('pref');k=kms.get(e['id'],0)
    if a and b and a!=b:pr+= [(e['id'],a,round(k/2,2),1),(e['id'],b,round(k/2,2),1)]
    elif a or b:pr.append((e['id'],a or b,k,0))
t('edge_pref',['edge_id','pref','km','approx'],pr)
# 지도의 탑승 오버레이용 선형. encoded polyline, 소수 5자리
def _enc(v):
    v=~(v<<1) if v<0 else v<<1
    o=[]
    while v>=0x20:
        o.append(chr((0x20|(v&0x1f))+63));v>>=5
    o.append(chr(v+63));return ''.join(o)
def polyline(c):
    a0=b0=0;o=[]
    for lon,lat in c:
        a,b=round(lat*1e5),round(lon*1e5);o.append(_enc(a-a0)+_enc(b-b0));a0,b0=a,b
    return ''.join(o)
t('edge_shape',['edge_id primary key','polyline'],[(g['edge'],polyline(g['coords'])) for g in load_geo()])
cov=[]
for l in lines:
    rs=[r for r in routes.values() if r['line']==l]
    cc=[coverage_of(r['id']) for r in rs]
    grade='지도 표시' if cc and all(x=='full' for x in cc) else '기록 가능'
    cov.append((l,grade,json.dumps(cc)))
t('coverage',['line_id','grade','routes'],cov)
t('id_redirect',['entity_type','old_id','context_line','new_ids','dataset_version'],[])
db.execute('create view node_public as select * from node where id in (select node_id from route_stop where is_stop=1)')
for ix in ('route_stop(route_id,seq)','route_stop(node_id)','edge_attr(edge_id)','edge_attr(line_id)','route_link(route_id,seq)','route_edge(route_id)','route(line_id)','denominator_unit(carryover,unit_key)','edge_life(edge_id)','route_link(other_line_id)','edge_pref(edge_id)','edge_km(edge_id)','route_edge(edge_id)','node(group_id)','edge(n)','denominator_unit(n)'):
    nm='ix_'+re.sub(r'\W+','_',ix);db.execute(f'create index {nm} on {ix}')
db.commit();db.close()
db=sqlite3.connect(np_)
db.execute('create table name (entity_type,entity_id,lang,text,kana,source,reading_source,source_title,checked,line_id,valid_from,valid_to)')
db.executemany('insert into name values (?,?,?,?,?,?,?,?,?,?,?,?)',[(x['entity_type'],x['id'],x['lang'],x['text'],x.get('kana'),x.get('source'),x.get('reading_source'),x.get('source_title'),x.get('checked'),x.get('line'),x.get('valid_from'),x.get('valid_to')) for x in names if x['entity_type']!='node' or x['id'] in pub])
db.execute('create table alias (entity_type,entity_id,lang,text,kind)')
db.executemany('insert into alias values (?,?,?,?,?)',[(x['entity_type'],x['id'],x.get('lang'),x['text'],x.get('kind')) for x in aliases])
# 검색 색인: 한 글자 토큰. trigram은 두 글자 역명을 못 찾는다. 앱의 searchQuery와 같은 정규화를 쓴다
def fold(t):
    out=[]
    for c in t.lower():
        o=ord(c)
        if 0x30A1<=o<=0x30F6:o-=0x60
        if o==0x3095:o=0x304B    # ゕ → か
        elif o==0x3096:o=0x3051  # ゖ → け
        c=chr(o)
        if c.isspace() or c in '・·':continue
        out.append(c)
    return ' '.join(out)
db.execute("create virtual table search using fts5(text,entity_type unindexed,entity_id unindexed,tokenize=\"unicode61 remove_diacritics 0\")")
seen=set()
rows=[]
def sadd(kind,eid,text):
    if not text:return
    f=fold(text)
    if f and (kind,eid,f) not in seen:
        seen.add((kind,eid,f));rows.append((f,kind,eid))
for x in names:
    if x['entity_type'] in('node','line','service') and not(x['entity_type']=='node' and x['id'] not in pub):
        sadd(x['entity_type'],x['id'],x['text']);sadd(x['entity_type'],x['id'],x.get('kana'))
for x in aliases:
    if x['entity_type'] in('node','line','service') and not(x['entity_type']=='node' and x['id'] not in pub):sadd(x['entity_type'],x['id'],x['text'])
db.executemany('insert into search values (?,?,?)',rows)
db.execute("insert into search(search) values('optimize')")
db.execute('create index ix_name_entity on name(entity_type,entity_id)')
db.commit();db.close()

rep=dict(today=TODAY,operators=len(ops),lines=len(lines),routes=len(routes),nodes=len(nodes),public_nodes=len(pub),edges=len(edges),events=len(events),attr=len(attr),route_stop=len(stops),route_link=len(links),hubs=len(hubs),junctions=len(junctions),archive=len(archive),
 denominators={f"{d['basis']}:{d['carryover']}":d['km'] for d in denom if d['scope']=='all' and d['basis'] in('current','alltime')},
 operator_km={k:round(v,1) for k,v in curop.items()},errors={k:len(v) for k,v in ERR.items()},error_samples={k:v[:12] for k,v in ERR.items()},warnings={k:v[:40] for k,v in WARN.items()})
json.dump(rep,open(os.path.join(BUILD,'report.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=1)
print({k:v for k,v in rep.items() if k not in('error_samples','operator_km')})
