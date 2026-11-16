# -*- coding: utf-8 -*-
# 선형과 역 점을 rail.pmtiles로, OSM 선형과 그 선에 맞춘 역 점을 rail-osm.pmtiles로 묶고 manifest.json을 만든다. tippecanoe 필요
import sys,os,json,sqlite3,hashlib,subprocess,collections,math,shutil
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from lib import *
m=sqlite3.connect(os.path.join(BUILD,'master.sqlite'))
nm=sqlite3.connect(os.path.join(BUILD,'names.sqlite'))
geo={x['edge']:x for x in load_geo()}
osm={x['edge']:x for x in load('geometry') if x.get('source')=='osm'}
life={}
# 원문이 범위일 수 있어 하한·상한 칸으로 비교한다. 끝이 열려 있으면 ongoing
for e,f,t in m.execute("select edge_id,min(valid_from_lo),max(case when valid_to='ongoing' then '9999-12-31' else valid_to_hi end) from edge_life group by 1"):life[e]=(f,'ongoing' if t=='9999-12-31' else t)
hub={r[0] for r in m.execute('select node_id from hub_member')}
def year(v,i=0):
    """날짜 원문의 해. 범위·불확실한 날은 가장 이른 해(i=0)나 가장 늦은 해(i=1)"""
    if not v or v in ('ongoing','9999'):return None
    return int((lohi(v)[i] if len(v)!=4 else v)[:4])
# 역 이름: 기간 없는 기본 이름. 표시 이름 규칙은 앱의 NameLookup과 같다
label=collections.defaultdict(dict)
for e,l,x in nm.execute("select entity_id,lang,text from name where entity_type='node' and line_id is null and valid_from is null and (valid_to is null or valid_to='ongoing')"):label[e].setdefault(l,x)
# 역의 기간: 정차 행 전체의 처음과 끝
span={}
# 원문이 범위([A..B])일 수 있어 비교는 하한·상한 칸으로 한다
for nd,f,t in m.execute("select node_id,min(valid_from_lo),max(case when valid_to='ongoing' then '9999' else valid_to_hi end) from route_stop where is_stop=1 group by 1"):span[nd]=(f,t)
pos={r[0]:r[1:] for r in m.execute('select node_id,lat,lon from node_position where lat is not null')}
gn=dict(m.execute('select id,n from station_group'))
# 역 점은 선 위에 그린다. 역 좌표와 선로는 다른 자료라 그대로 두면 점이 선에서 떨어지고 끝 역은 선 끝과 어긋난다.
# 그리는 위치만 옮기고 node_position은 그대로 둔다. 선의 출처와 상관없이 규칙은 하나이고, OSM 선에 맞춘 점만 OSM 파일로 간다
at=collections.defaultdict(set)
ends={}
for e,a,b in m.execute('select id,from_node,to_node from edge'):at[a].add(e);at[b].add(e);ends[e]=(a,b)
lines_of=collections.defaultdict(set)
for l,e in m.execute('select distinct line_id,edge_id from edge_attr'):lines_of[e].add(l)
SNAP_KM=1.0
snap_moved=[]
# 지도 렌더링 전수 점검 (build/map_audit.json). 선 위에 서지 못한 점과 크게 옮긴 점을 남긴다
AUDIT={'station_off_line':[],'station_moved_far':[],'platform_off_line':[],'platform_moved':[],'hub_far':[]}
def nearest(lat,lon,coords):
    kx=math.cos(math.radians(lat))*111.32;ky=110.57;best=None
    for p,q in zip(coords,coords[1:]):
        ax,ay=(p[0]-lon)*kx,(p[1]-lat)*ky;dx,dy=(q[0]-p[0])*kx,(q[1]-p[1])*ky
        l=dx*dx+dy*dy;t=0 if l==0 else max(0,min(1,-(ax*dx+ay*dy)/l))
        x,y=ax+t*dx,ay+t*dy;d=math.hypot(x,y)
        if best is None or d<best[0]:best=(d,lat+y/ky,lon+x/kx)
    return best
def apart(p,q):return math.hypot((p[2]-q[2])*math.cos(math.radians(p[1]))*111.32,(p[1]-q[1])*110.57)
def on_line(nodes,lat,lon):
    """역 하나의 선 위 위치. 환승역은 노선마다 역 좌표를 그 노선 위로 옮긴 뒤 가운데 있는 점을 고른다.
    평균을 내면 선 사이 빈 곳에 떠 보이고, 가까운 선 하나를 고르면 큰 역에서 한쪽으로 쏠린다"""
    # 옮긴 역(野内와 野内（旧）)처럼 한 묶음에 지금 역과 옛 역이 함께 있으면 지금 역 자리에 그린다. 옛 역 선이 지금 선과 겹치면 옛 자리로 튄다
    now=[n for n in nodes if span.get(n,(None,''))[1]=='9999']
    if now:nodes=now;lat,lon=pos[nodes[0]] if nodes[0] in pos else (lat,lon)
    edges=[(n,e) for n in nodes if n in pos for e in at[n] if e in geo or e in osm]
    cur=[x for x in edges if life.get(x[1],(None,None))[1]=='ongoing']
    per={}
    for n,e in cur or edges:
        hit=nearest(*pos[n],(geo.get(e) or osm[e])['coords'])+(e in osm,)
        # 같은 노선에 묶음의 여러 노드가 있으면(土居下와 土居下（仮）) 대표 노드의 자리를 쓴다
        for l in lines_of[e]:
            if l not in per or (n==nodes[0])>(per[l][4]==nodes[0]) or ((n==nodes[0])==(per[l][4]==nodes[0]) and hit<per[l][:4]):per[l]=hit+(n,)
    near=[p for p in per.values() if p[0]<=SNAP_KM]
    if not near:
        AUDIT['station_off_line'].append(dict(nodes=sorted(nodes),nearest_km=round(min((p[0] for p in per.values()),default=-1),3)))
        return lat,lon,False
    here=(0,lat,lon)
    d,y,x,on_osm,_=min(near,key=lambda p:(round(sum(apart(p,q) for q in near),3),apart(p,here)))
    mv=apart((0,y,x),here);snap_moved.append(mv)
    if mv>0.3:AUDIT['station_moved_far'].append(dict(nodes=sorted(nodes),moved_km=round(mv,3)))
    return round(y,6),round(x,6),on_osm
def feature(eid,num,g):
    vf,vt=life.get(eid,(None,None))
    p=dict(n=num,closed=int(vt!='ongoing'))
    if year(vf) is not None:p['fy']=year(vf)
    p['ty']=year(vt,1) if year(vt,1) is not None else 9999
    return json.dumps(dict(type='Feature',tippecanoe=dict(layer='edge'),properties=p,geometry=dict(type='LineString',coordinates=g['coords'])),ensure_ascii=False)+'\n'
gj=os.path.join(BUILD,'rail.geojsonl')
n=0
osm_points=[]
with open(gj,'w',encoding='utf-8') as f:
    for eid,num in m.execute('select id,n from edge'):
        g=geo.get(eid)
        if not g:continue
        f.write(feature(eid,num,g));n+=1
    # 지도 점은 역 묶음 단위다 (ARCHITECTURE §2.6). 묶음의 대표는 환승역을 먼저, 그다음 사업자 표의 순서다.
    # ID는 영어 이름이라 그 순서로 고르면 회사 이름의 알파벳 순이 된다
    oprank={o:i for i,(o,) in enumerate(m.execute('select id from operator order by rowid'))}
    noderank={}
    for e,o in m.execute('select distinct edge_id,operator_id from edge_attr'):
        for nd in ends[e]:noderank[nd]=min(noderank.get(nd,len(oprank)),oprank[o])
    IN_SH={nd for (nd,) in m.execute('select node_id from station_platform')}
    GPT={}   # 역 묶음마다 지도에 그린 역 점 (간접환승 선의 끝)
    groups=collections.defaultdict(list)
    for nid,grp in m.execute('select id,group_id from node_public'):groups[grp].append(nid)
    for grp,members in groups.items():
        members=[x for x in sorted(members,key=lambda x:(x not in hub,span.get(x,(None,''))[1]!='9999',noderank.get(x,len(oprank)),x)) if x in pos]
        if not members:continue
        top=members[0]
        lat,lon,on_osm=on_line(members,*pos[top])
        ends=[span[x][1] for x in members if x in span]
        shut=int(bool(ends) and max(ends)!='9999')
        h=int(any(x in hub for x in members))
        p=dict(g=gn.get(grp,0),hub=h,closed=shut,node=top)
        if any(x in IN_SH for x in members):p['sh']=1   # 환승역 배치가 대신 그린다 (§7.5)
        if ends:p['ty']=9999 if max(ends)=='9999' else year(max(ends),1)
        starts=[year(span[x][0]) for x in members if x in span and span[x][0]]
        if starts:p['fy']=min(starts)
        for l in ('ja','ko','en'):
            if l in label[top]:p[l]=label[top][l]
        GPT[grp]=(lat,lon)
        point=json.dumps(dict(type='Feature',tippecanoe=dict(layer='station',minzoom=8 if h else 10),properties=p,geometry=dict(type='Point',coordinates=[lon,lat])),ensure_ascii=False)+'\n'
        (osm_points.append(point) if on_osm else f.write(point))
    # 위치 미확인 표식. 기준 역과 방향은 빌드가 정한다 (ARCHITECTURE §2.6)
    for mid,node,bearing in m.execute('select id,anchor_node,bearing from map_marker'):
        if node not in pos:continue
        lat,lon,on_osm=on_line([node],*pos[node])
        point=json.dumps(dict(type='Feature',tippecanoe=dict(layer='marker',minzoom=8),properties=dict(m=mid,bearing=bearing,closed=1),geometry=dict(type='Point',coordinates=[lon,lat])),ensure_ascii=False)+'\n'
        (osm_points.append(point) if on_osm else f.write(point))
    # 환승역의 통합 노드·승강장 노드·연결선 (DESIGN §7.5). 연결선은 시각 표시일 뿐이다
    SH={h:(la,lo,k) for h,la,lo,k,_ in m.execute('select id,lat,lon,kind,clusters from station_hub')}
    NG={nd:g_ for nd,g_ in m.execute('select id,group_id from node')}
    shut_of={}
    # 연도 슬라이더용 해(fy·ty): 그 점·선을 이루는 노드가 서던 기간의 처음과 끝. 역 점·선로와 같은 칸이다
    def node_years(nds):
        sp=[span[x] for x in nds if x in span]
        p_={}
        if sp:
            fs=[year(a) for a,_ in sp if a]
            if fs:p_['fy']=min(fs)
            p_['ty']=9999 if any(b=='9999' for _,b in sp) else max(year(b,1) for _,b in sp)
        return p_
    # 승강장 자리(N05 역 점 등)는 지도에 그리는 그 노선의 선과 어긋날 수 있다 (上野 東北線). 그 노선 선 위 가장 가까운 자리로 옮긴다
    def on_own_line(nd,ln,la,lo):
        es=[e for e in at[nd] if (e in geo or e in osm) and (ln is None or ln in lines_of[e])]
        es=[e for e in es if life.get(e,(None,None))[1]=='ongoing'] or es
        best=None
        for e in es:
            hit=nearest(la,lo,(geo.get(e) or osm[e])['coords'])
            if best is None or hit<best:best=hit
        if best and best[0]<=0.4:
            if best[0]>0.03:AUDIT['platform_moved'].append(dict(node=nd,line=ln,moved_km=round(best[0],3)))
            return round(best[1],6),round(best[2],6)
        AUDIT['platform_off_line'].append(dict(node=nd,line=ln,nearest_km=round(best[0],3) if best else None))
        return la,lo
    pts=collections.defaultdict(list)
    for h,c,nd,ln,la,lo in m.execute('select hub_id,cluster_id,node_id,line_id,lat,lon from station_platform'):
        e_=span.get(nd,(None,None))[1] if nd in span else None
        shut_of.setdefault((h,c),[la,lo,[],[],[]]);shut_of[(h,c)][2].append(nd);shut_of[(h,c)][3].append(e_)
        if ln:shut_of[(h,c)][4].append(ln)
        pts[(h,c)].append(on_own_line(nd,ln,la,lo))
    # 묶음 점은 옮긴 점 가운데 다른 점과 가장 가까운 점이다. 평균은 선 사이 빈 곳에 뜬다
    for k_,ps in pts.items():
        la,lo=min(ps,key=lambda p:sum(apart((0,*p),(0,*q)) for q in ps))
        shut_of[k_][0],shut_of[k_][1]=la,lo
    # 묶음 중심은 옮긴 승강장 점의 가운데 (station_hub kind=centroid)
    for h in list(SH):
        cs=[(v[0],v[1]) for (hh,_),v in shut_of.items() if hh==h]
        if SH[h][2]=='centroid' and cs:SH[h]=(sum(p[0] for p in cs)/len(cs),sum(p[1] for p in cs)/len(cs),SH[h][2])
    for (h,c),(la,lo,nds,ends_,lns) in shut_of.items():
        closed=int(all(x and x!='9999' for x in ends_))
        # nodes: 이 승강장을 쓰는 노드, lines: 노선별로 나뉜 경우 그 노선 (비면 그 노드의 모든 노선)
        gs=sorted({gn.get(NG.get(x),0) for x in nds}-{0})
        f.write(json.dumps(dict(type='Feature',tippecanoe=dict(layer='platform',minzoom=13),properties=dict(sh=h,c=c,g=gs[0] if gs else 0,nodes=','.join(sorted(set(nds))),lines=','.join(sorted(set(lns))),closed=closed,**node_years(nds)),geometry=dict(type='Point',coordinates=[lo,la])),ensure_ascii=False)+'\n')
        # 탄 표시용: 노드마다 그 승강장 자리에 점 하나 (앱이 노드 id로 고른다)
        for x,e_ in zip(nds,ends_):
            f.write(json.dumps(dict(type='Feature',tippecanoe=dict(layer='platformmark',minzoom=13),properties=dict(node=x,closed=int(bool(e_ and e_!='9999'))),geometry=dict(type='Point',coordinates=[lo,la])),ensure_ascii=False)+'\n')
        hla,hlo,_=SH[h]
        if abs(hla-la)+abs(hlo-lo)>1e-6:
            f.write(json.dumps(dict(type='Feature',tippecanoe=dict(layer='spoke',minzoom=13),properties=dict(sh=h,closed=closed,**node_years(nds)),geometry=dict(type='LineString',coordinates=[[hlo,hla],[lo,la]])),ensure_ascii=False)+'\n')
    hub_closed=collections.defaultdict(list)
    for (h,c),v in shut_of.items():hub_closed[h]+=v[3]
    rep_node={}
    for h,c,nd in m.execute('select hub_id,cluster_id,node_id from station_platform'):rep_node.setdefault(h,nd)
    for h,(la,lo,k) in SH.items():
        top=rep_node[h];p=dict(sh=h,node=top,nodes=','.join(sorted({x for (hh,cc),v in shut_of.items() if hh==h for x in v[2]})),closed=int(all(x and x!='9999' for x in hub_closed[h])),kind=k)
        p.update(node_years(p['nodes'].split(',')))
        for l in ('ja','ko','en'):
            if l in label.get(top,{}):p[l]=label[top][l]
        f.write(json.dumps(dict(type='Feature',tippecanoe=dict(layer='hubnode',minzoom=8),properties=p,geometry=dict(type='Point',coordinates=[lo,la])),ensure_ascii=False)+'\n')
        for x in sorted(set(p['nodes'].split(','))):
            e_=span.get(x,(None,None))[1] if x in span else None
            f.write(json.dumps(dict(type='Feature',tippecanoe=dict(layer='hubmark',minzoom=8),properties=dict(node=x,closed=int(bool(e_ and e_!='9999'))),geometry=dict(type='Point',coordinates=[lo,la])),ensure_ascii=False)+'\n')
    # 간접환승(徒歩連絡): 채택된 환승 쌍 가운데 지도에서 서로 다른 역 점으로 그려지는 쌍은 대표 점끼리 잇는다 (DESIGN §7.5, 사용자 결정 2026-11-08 주황 점선).
    # 쌍마다 손으로 고르지 않고 이 규칙 하나로 모든 쌍에 적용한다. 함께 서던 기간이 모두 끝났으면 closed
    # 끝점은 그 역의 대표 점이다: 환승역 배치(station_hub)에 든 노드는 그 묶음 중심, 아니면 그 역 묶음의 역 점 (DESIGN §7.5 「대표 노드, 없으면 그 역 노드」).
    # 양쪽이 같은 점이면(같은 환승역 배치·같은 역 묶음) 잇지 않는다 (11회차 메인: 환승역 배치끼리만 잇던 것을 바로잡음)
    hub_at={nd:h for h,nd in m.execute('select hub_id,node_id from station_platform')}
    grp_of=dict(m.execute('select id,group_id from node_public'))
    def _wpt(nd):
        if nd in hub_at and hub_at[nd] in SH:return ('sh',hub_at[nd]),(SH[hub_at[nd]][0],SH[hub_at[nd]][1])
        g_=grp_of.get(nd)
        if g_ in GPT:return ('g',g_),GPT[g_]
        return None,None
    # walk_y: 그 두 점 사이 환승 쌍들이 함께 서던 기간의 시작 해·끝 해 목록 (연도 슬라이더)
    walks={};wpt={};walk_y={}
    for a_,b_,f_,u_ in m.execute('select node_a,node_b,valid_from,valid_to from hub_pair'):
        ka,pa=_wpt(a_);kb,pb=_wpt(b_)
        if not ka or not kb or ka==kb:continue
        k_=tuple(sorted((ka,kb)));walks[k_]=walks.get(k_,True) and bool(u_ and u_!='ongoing');wpt[ka]=pa;wpt[kb]=pb
        fs_,ts_=walk_y.setdefault(k_,([],[]));fs_.append(year(f_));ts_.append(year(u_,1) or 9999)
    for (ka,kb),shut in sorted(walks.items()):
        (la1,lo1),(la2,lo2)=wpt[ka],wpt[kb]
        f.write(json.dumps(dict(type='Feature',tippecanoe=dict(layer='walk',minzoom=11),properties=dict(a=ka[1],b=kb[1],closed=int(shut),**({'fy':min(walk_y[(ka,kb)][0])} if all(walk_y[(ka,kb)][0]) else {}),ty=max(walk_y[(ka,kb)][1])),geometry=dict(type='LineString',coordinates=[[lo1,la1],[lo2,la2]])),ensure_ascii=False)+'\n')
    print('간접환승 선',len(walks),'끝난 것',sum(walks.values()))
print('환승역 통합 노드',len(SH),'승강장 노드',len(shut_of))
# 묶음 중심이 그 역 선에서 멀면 연결선만 허공에 뜬다 (참고)
for h,(la,lo,k) in SH.items():
    nds={x for (hh,_),v in shut_of.items() if hh==h for x in v[2]}
    ds=[nearest(la,lo,(geo.get(e) or osm[e])['coords'])[0] for x in nds for e in at[x] if e in geo or e in osm]
    if ds and min(ds)>0.15:AUDIT['hub_far'].append(dict(hub=h,nearest_km=round(min(ds),3)))
json.dump(AUDIT,open(os.path.join(BUILD,'map_audit.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=1)
print('지도 점검',{k:len(v) for k,v in AUDIT.items()})
print('역 점 옮김',len(snap_moved),'최대 %.0fm'%(max(snap_moved)*1000),'OSM 선 위',len(osm_points))
out=os.path.join(BUILD,'rail.pmtiles')
if os.path.exists(out):os.remove(out)
# 메타데이터에 경로가 남지 않게 build/ 안에서 상대 경로로 부른다
subprocess.run(['tippecanoe','-q','-o','rail.pmtiles','-Z3','-z14','--no-feature-limit','--no-tile-size-limit','-r1','-n','noriori rail','-A','「国土数値情報（鉄道データ）」（国土交通省）を加工して作成','rail.geojsonl'],check=True,cwd=BUILD,env=dict(os.environ,TIPPECANOE_MAX_THREADS='1'))
os.remove(gj)
# OSM 선형과 그 선에 맞춘 점은 ODbL이라 다른 파일과 섞지 않는다 (설계 §2.11). 레이어와 속성은 rail.pmtiles와 같다
oj=os.path.join(BUILD,'rail-osm.geojsonl');oo=os.path.join(BUILD,'rail-osm.pmtiles');no=0
if os.path.exists(oo):os.remove(oo)
if osm:
    with open(oj,'w',encoding='utf-8') as f:
        for eid,num in m.execute('select id,n from edge'):
            g=osm.get(eid)
            if g:f.write(feature(eid,num,g));no+=1
        f.writelines(osm_points)
    subprocess.run(['tippecanoe','-q','-o','rail-osm.pmtiles','-Z3','-z14','--no-feature-limit','--no-tile-size-limit','-r1','-n','noriori rail osm','-A','© OpenStreetMap contributors','rail-osm.geojsonl'],check=True,cwd=BUILD,env=dict(os.environ,TIPPECANOE_MAX_THREADS='1'))
    os.remove(oj)
# 기본 배경은 앱에 넣는다. 인터넷이 없어도 일본 윤곽과 도도부현 경계가 보인다 (설계 §13). 원본은 tools/gen_base.sh
BASE=os.path.join(ROOT,'data','base')
bb=os.path.join(BUILD,'base.pmtiles')
if os.path.exists(bb):os.remove(bb)
# 北方領土·竹島가 배경에 다시 들어오면 멈춘다 (tools/base_exclude.py)
subprocess.run([sys.executable,'-I',os.path.join(os.path.dirname(os.path.abspath(__file__)),'base_exclude.py'),'--check'],check=True)
for x in ('land.geojson','border.geojson','pref.geojson'):shutil.copy(os.path.join(BASE,x),os.path.join(BUILD,x))
subprocess.run(['tippecanoe','-q','-o','base.pmtiles','-Z3','-z10','--no-feature-limit','--no-tile-size-limit','--no-tiny-polygon-reduction','-n','noriori base','-A','「国土数値情報（行政区域データ）」（国土交通省）を加工','-L','land:land.geojson','-L','border:border.geojson','-L','pref:pref.geojson'],cwd=BUILD,check=True,env=dict(os.environ,TIPPECANOE_MAX_THREADS='1'))
for x in ('land.geojson','border.geojson','pref.geojson'):os.remove(os.path.join(BUILD,x))
for x in os.listdir(BUILD):
    if x.startswith('glyph-') and x.endswith('.pbf'):os.remove(os.path.join(BUILD,x))
# 역 이름에 쓰는 글자의 글리프를 앱에 넣는다. 지도 엔진이 한글도 글리프 파일로 그린다 (tools/gen_glyphs.py)
GLYPHS=sorted(os.listdir(os.path.join(BASE,'glyphs')))
for x in GLYPHS:shutil.copy(os.path.join(BASE,'glyphs',x),os.path.join(BUILD,x))
# 앱이 읽지 않는 표는 판에서 뺀다. 도구와 시험은 build/master.sqlite를 그대로 본다 (설계 §14.1)
PACK=os.path.join(BUILD,'pack-master.sqlite')
if os.path.exists(PACK):os.remove(PACK)
tmp=PACK+'.tmp';shutil.copy(os.path.join(BUILD,'master.sqlite'),tmp)
db=sqlite3.connect(tmp)
# 재설계 1단계 표는 앱이 읽기 시작할 때 판에 넣는다 (docs/redesign.md)
for t in ('edge_shape','junction','denominator','pack_meta','edge_km_period','route_stop_period','hub_pair','track_link','line_gauge'):db.execute('drop table '+t)
# 여객 영업 이력이 없는 화물선(rule_class hidden)은 DB에만 둔다(사용자 결정 2026-11-09). 앱 판에서는 그 노선·계통·칸·전용 노드를 뺀다.
# 분모 단위·정차·이음이 없어도 칸 수명(edge_life)이 남으면 변경 소식·위치 미확인 표식에 나오기 때문이다 (9회차 F)
_tabs={r_[0] for r_ in db.execute("select name from sqlite_master where type='table'")}
_cols=lambda t_:{c_[1] for c_ in db.execute(f'pragma table_info({t_})')}
HL=[r_[0] for r_ in db.execute("select id from line where rule_class='hidden'")]
if HL:
    db.execute('create temp table _hl(id primary key)');db.executemany('insert into _hl values (?)',[(x,) for x in HL])
    db.execute('create temp table _hr as select id from route where line_id in (select id from _hl)')
    db.execute('create temp table _he as select id from edge where id in (select edge_id from edge_attr where line_id in (select id from _hl)) and id not in (select edge_id from edge_attr where line_id not in (select id from _hl))')
    db.execute('create temp table _hn as select id from node where id in (select from_node from edge where id in (select id from _he) union select to_node from edge where id in (select id from _he)) '
               'and id not in (select from_node from edge where id not in (select id from _he) union select to_node from edge where id not in (select id from _he)) '
               'and id not in (select node_id from route_stop where route_id not in (select id from _hr))')
    for t_ in sorted(_tabs):
        c_=_cols(t_)
        for col_,tmp_ in (('line_id','_hl'),('route_id','_hr'),('edge_id','_he'),('node_id','_hn'),('anchor_node','_hn')):
            if col_ in c_:db.execute(f'delete from {t_} where {col_} in (select id from {tmp_})')
        if t_ in ('line','route','edge','node'):db.execute(f"delete from {t_} where id in (select id from {dict(line='_hl',route='_hr',edge='_he',node='_hn')[t_]})")
    db.execute('delete from station_group where id not in (select group_id from node where group_id is not null)')
db.commit();db.execute('vacuum into ?',(PACK,));db.close();os.remove(tmp)
def sha(p):
    h=hashlib.sha256()
    with open(p,'rb') as f:
        for b in iter(lambda:f.read(1<<20),b''):h.update(b)
    return h.hexdigest()
files={x:dict(sha256=sha(os.path.join(BUILD,x)),size=os.path.getsize(os.path.join(BUILD,x))) for x in ('names.sqlite','rail.pmtiles','rail-osm.pmtiles','base.pmtiles',*GLYPHS) if os.path.exists(os.path.join(BUILD,x))}
files['master.sqlite']=dict(sha256=sha(PACK),size=os.path.getsize(PACK))
man=dict(edition=EDITION,schema_version=2,files=files)
json.dump(man,open(os.path.join(BUILD,'manifest.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=1)
print('tiles',n,os.path.getsize(out),'osm',no,os.path.getsize(oo) if no else 0)
