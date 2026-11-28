# -*- coding: utf-8 -*-
# 현행 구간의 선형과 역 위치를 재고, 기준을 넘는 항목이 있으면 exit 1로 실패한다
# 예외는 data/overrides/geometry_exceptions.json에 사유와 함께 적은 것만 허용한다. 쓰이지 않는 예외도 실패다
# build/master.sqlite와 data/source만 읽으므로 data/imports가 없는 체크아웃에서도 돈다
import sys,os,json,math,sqlite3,collections
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from lib import *
GAP_LINE=.02   # 같은 노선의 이웃 끝 간격 (km)
GAP_ANY=.3     # 다른 노선까지 포함한 이웃 끝 간격 (km)
END=.3         # 끝점과 역의 거리 (km)
PLAT=.8        # 끝을 그 노선의 N02 승강장에 맞춘 구간은 공유 노드 좌표와 이만큼 떨어질 수 있다 (km)
TRACK=.3       # 역과 자기 구간 선로의 거리 (km)
SPIKE=.05      # 되돌아가는 꺾임으로 볼 다리 길이 (km)
m=sqlite3.connect(os.path.join(BUILD,'master.sqlite'))
cur={r[0] for r in m.execute("select distinct edge_id from edge_attr where valid_to='ongoing'")}
# 나뉜 역(station_split)의 같은 km 점 칸은 컴파일이 두 노드 좌표 직선으로 만드는 0 km 칸이라 원본(data/source)에 없다 (11회차 S1)
if m.execute("select 1 from sqlite_master where type='table' and name='station_split'").fetchone():
    cur-={r[0] for r in m.execute("select edge_id from station_split where edge_id is not null")}
edges={e['id']:e for e in load('edges')}
# 컴파일이 칸에 분기점을 끼워 나눈 칸(edge_insert, 5번 결정 2026-11-20)은 원본에 없다. 나누기 전 원본 칸이 원본 선형으로 검사된다
cur&=set(edges)
km={k['edge']:k['km'] for k in load('km')}
geo={g['edge']:g for g in load('geometry')}
pos={p['node']:(p['lon'],p['lat']) for p in load('positions') if p.get('lat') is not None}
ln={l['id']:l['name_ja'] for l in load('lines')}
ja={}
for x in load('names'):
    if x['entity_type']=='node' and x['lang']=='ja' and x['id'] not in ja and not x.get('line') and not x.get('valid_to'):ja[x['id']]=x['text']
stop={r[0] for r in m.execute("select distinct node_id from route_stop where is_stop=1 and valid_to='ongoing'")}
def d(a,b):
    p=math.radians((a[1]+b[1])/2)
    return math.hypot((a[1]-b[1])*111.0,(a[0]-b[0])*111.0*math.cos(p))
def L(c):return sum(d(a,b) for a,b in zip(c,c[1:]))
def dseg(p,a,b):
    cs=math.cos(math.radians(p[1]))
    ax,ay=(a[0]-p[0])*cs,a[1]-p[1];bx,by=(b[0]-p[0])*cs,b[1]-p[1]
    ex,ey=bx-ax,by-ay;t=max(0,min(1,-(ax*ex+ay*ey)/((ex*ex+ey*ey) or 1e-18)))
    return 111.0*math.hypot(ax+t*ex,ay+t*ey)
def dline(p,c):return min(dseg(p,a,b) for a,b in zip(c,c[1:]))
def name(e):
    x=edges[e];return f"{ln[x['seed_line']]} {ja.get(x['a'],x['a'])}~{ja.get(x['b'],x['b'])}"
F=collections.defaultdict(list)    # 검사 이름 → (대상, 설명)
adj=collections.defaultdict(list)
LEN={};RAT=[]
for e in sorted(cur):
    x=edges[e];k=km.get(e) or 0
    for n in (x['a'],x['b']):
        adj[n].append(e)
        if n not in pos:F['nopos'].append((n,f"{ja.get(n,n)} 좌표 없음"))
    g=geo.get(e)
    if not g:F['none'].append((e,f"{name(e)} {k}km 선형 없음"));continue
    c=g['coords'];l=L(c)
    if '新幹線' in ln[x['seed_line']]:
        A,B=pos.get(x['a']),pos.get(x['b'])
        if A and B and l>1.4*d(A,B)+1:F['ratio'].append((e,f"{name(e)} 신칸센 직선 {d(A,B):.2f} 길이 {l:.2f}"))
    else:
        LEN[e]=l
        if k and not(.8*k-.2<=l<=1.2*k+.2):RAT.append((e,f"{name(e)} 영업 {k} 길이 {l:.2f} {g['source']}"))
    pl=g.get('plat','')
    for n,p,t in ((x['a'],c[0],'a'),(x['b'],c[-1],'b')):
        if n in pos and d(pos[n],p)>(PLAT if t in pl else END):F['end'].append((e,f"{name(e)} {ja.get(n,n)} 끝점 {d(pos[n],p):.2f}km"))
    for a,b,q in zip(c,c[1:],c[2:]):
        u=(a[0]-b[0],a[1]-b[1]);v=(q[0]-b[0],q[1]-b[1])
        cs=math.cos(math.radians(b[1]))
        if d(a,b)>SPIKE and d(b,q)>SPIKE:
            dot=u[0]*v[0]*cs*cs+u[1]*v[1];nn=math.hypot(u[0]*cs,u[1])*math.hypot(v[0]*cs,v[1])
            if nn and dot/nn>.5:F['spike'].append((e,f"{name(e)} 되돌아감 ({b[1]:.5f},{b[0]:.5f}) {g['source']}"))
# 신호장·분기점·화물역은 승객이 타고 내리는 역이 아니다. 그 km는 장내 중심 같은 명목값이고, 그 노드에서 나눈 구간에는
# 이웃 역 쪽 km 어긋남(名古屋 이전 뒤에도 그대로 둔 km 등)이 한쪽에 몰린다. 그런 노드에서 같은 노선의 두 구간만 만나면
# 둘을 이은 영업km 합과 선형 길이 합으로 다시 재고, 이어서도 벗어날 때만 실패로 둔다
NK={n_['id']:n_.get('kind') for n_ in load('nodes')}
UF={}
def root(e):
    while UF.get(e,e)!=e:e=UF[e]
    return e
for n_,es_ in adj.items():
    if NK.get(n_) not in ('signal','junction','freight'):continue
    bl=collections.defaultdict(list)
    for e_ in es_:bl[edges[e_]['seed_line']].append(e_)
    for v_ in bl.values():
        if len(v_)==2 and all(x in LEN for x in v_):UF[root(v_[0])]=root(v_[1])
GRP=collections.defaultdict(list)
for e_ in LEN:GRP[root(e_)].append(e_)
for e_,s_ in RAT:
    g_=GRP[root(e_)]
    if len(g_)>1:
        K_=sum(km.get(x) or 0 for x in g_);L_=sum(LEN[x] for x in g_)
        if .8*K_-.2<=L_<=1.2*K_+.2:F['ratio_joined'].append((e_,s_));continue
    F['ratio'].append((e_,s_))
def endof(e,n):
    c=geo[e]['coords'];return c[0] if edges[e]['a']==n else c[-1]
def isplat(e,n):return ('a' if edges[e]['a']==n else 'b') in geo[e].get('plat','')
for n in sorted(adj):
    es=[e for e in adj[n] if e in geo]
    for i,e1 in enumerate(es):
        for e2 in es[i+1:]:
            if edges[e1]['a']==edges[e1]['b'] or edges[e2]['a']==edges[e2]['b']:continue
            g_=d(endof(e1,n),endof(e2,n))
            same=edges[e1]['seed_line']==edges[e2]['seed_line']
            bp=isplat(e1,n) and isplat(e2,n)
            if (same and g_>GAP_LINE) or g_>(PLAT if bp else GAP_ANY):F['gap'].append((n,f"{ja.get(n,n)} {name(e1)} / {name(e2)} 간격 {g_:.3f}km"))
    if n in pos and es and (n in stop or len(es)>=1):
        t=min(dline(pos[n],geo[e]['coords']) for e in es)
        if t>(PLAT if any(isplat(e,n) for e in es) else TRACK):F['track'].append((n,f"{ja.get(n,n)} 자기 선로까지 {t:.2f}km"))
# OSM 선형은 ODbL이라 master.sqlite에 들어가면 안 된다 (설계 §2.11)
leak=[g['edge'] for g in geo.values() if g['source']=='osm' and m.execute('select 1 from edge_shape where edge_id=?',(g['edge'],)).fetchone()]
F['license']=[(e,f'{name(e)} OSM 선형이 edge_shape에 있음') for e in leak]
F['license']+=[(r[0],'좌표 출처가 OSM') for r in m.execute("select node_id from node_position where source like '%osm%'")]
# 예외
exc=json.load(open(os.path.join(ROOT,'data','overrides','geometry_exceptions.json'),encoding='utf-8'))
# 구간 예외의 키는 노선|앞 노드|뒤 노드다. edge 번호는 노선이 늘면 밀린다
EKEY={f"{e['seed_line']}|{e['a']}|{e['b']}":e['id'] for e in load('edges')}
for x in exc:
    if x.get('edge_key'):
        if x['edge_key'] not in EKEY:raise SystemExit(f"geometry_exceptions.json의 구간이 없습니다: {x['edge_key']}")
        x['edge']=EKEY[x['edge_key']]
used=set();allow=collections.defaultdict(set)
# 폐선 구간이 다른 선로로 돌아간 고리(영업km와 두 역 직선을 모두 크게 넘음). 생성기는 이런 선을 두 역 점 직선으로 바꾸므로 남으면 보정 행이 고리다 (6회차 2026-11-28)
for e in sorted(edges):
    if e in cur or e not in geo:continue
    k=km.get(e);A,B=pos.get(edges[e]['a']),pos.get(edges[e]['b'])
    if not k or not A or not B:continue
    l=L(geo[e]['coords']);D=d(A,B)
    if l>1.4*D+.15 and l>1.2*k+.2:F['detour'].append((e,f"{name(e)} 폐선 영업 {k} 직선 {D:.2f} 길이 {l:.2f} {geo[e]['source']}"))
bad=[]
for i,x in enumerate(exc):
    if not str(x.get('reason','')).strip() or not x.get('checks') or not (x.get('edge') or x.get('node')):bad.append(f'예외 {i}: 사유, 검사, 대상 중 빠진 것이 있음')
    for c in x.get('checks',[]):allow[(x.get('edge') or x.get('node'),c)].add(i)
fails=[]
tot=collections.Counter()
for c in ('license','nopos','none','ratio','end','gap','track','spike','detour'):
    seen=set()
    for t,s in F[c]:
        tot[c]+=1
        if (t,c) in allow:used|=allow[(t,c)];continue
        fails.append((c,t,s))
for i,x in enumerate(exc):
    if i not in used:bad.append(f"쓰이지 않는 예외: {x.get('edge') or x.get('node')} {x.get('checks')}")
# 폐선은 재기만 한다
closed=[e for e in edges if e not in cur]
ck=sum(km.get(e) or 0 for e in closed)
gk=sum(km.get(e) or 0 for e in closed if e in geo)
src=collections.Counter(g['source'] for g in geo.values())
rep=dict(current=len(cur),found=dict(tot),ratio_joined=[list(x) for x in F['ratio_joined']],failed=len(fails),exceptions=len(exc),closed=dict(edges=len(closed),km=round(ck,1),with_geometry=sum(1 for e in closed if e in geo),km_with_geometry=round(gk,1)),source=dict(src),fails=[list(x) for x in fails])
json.dump(rep,open(os.path.join(BUILD,'check_geometry.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=0)
print('선형 검사',{k:v for k,v in rep.items() if k!='fails'})
for c,t,s in fails[:int(sys.argv[1]) if len(sys.argv)>1 else 40]:print(' ',c,t,s)
for s in bad:print(' ',s)
if fails or bad:
    print(f'실패 {len(fails)}건, 예외 문제 {len(bad)}건');sys.exit(1)
print('통과')
