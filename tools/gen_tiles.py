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
for e,f,t in m.execute("select edge_id,min(valid_from),max(valid_to) from edge_life group by 1"):life[e]=(f,t)
hub={r[0] for r in m.execute('select node_id from hub_member')}
def year(v):return int(v[:4].replace('X','0')) if v and v!='ongoing' else None
# 역 이름: 기간 없는 기본 이름. 표시 이름 규칙은 앱의 NameLookup과 같다
label=collections.defaultdict(dict)
for e,l,x in nm.execute("select entity_id,lang,text from name where entity_type='node' and line_id is null and valid_from is null and (valid_to is null or valid_to='ongoing')"):label[e].setdefault(l,x)
# 역의 기간: 정차 행 전체의 처음과 끝
span={}
for nd,f,t in m.execute("select node_id,min(valid_from),max(case when valid_to='ongoing' or valid_to is null then '9999' else valid_to end) from route_stop where is_stop=1 group by 1"):span[nd]=(f,t)
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
    edges=[(n,e) for n in nodes if n in pos for e in at[n] if e in geo or e in osm]
    cur=[x for x in edges if life.get(x[1],(None,None))[1]=='ongoing']
    per={}
    for n,e in cur or edges:
        hit=nearest(*pos[n],(geo.get(e) or osm[e])['coords'])+(e in osm,)
        for l in lines_of[e]:
            if l not in per or hit<per[l]:per[l]=hit
    near=[p for p in per.values() if p[0]<=SNAP_KM]
    if not near:return lat,lon,False
    here=(0,lat,lon)
    d,y,x,on_osm=min(near,key=lambda p:(round(sum(apart(p,q) for q in near),3),apart(p,here)))
    snap_moved.append(apart((0,y,x),here));return round(y,6),round(x,6),on_osm
def feature(eid,num,g):
    vf,vt=life.get(eid,(None,None))
    p=dict(n=num,closed=int(vt!='ongoing'))
    if year(vf) is not None:p['fy']=year(vf)
    p['ty']=year(vt) if year(vt) is not None else 9999
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
    groups=collections.defaultdict(list)
    for nid,grp in m.execute('select id,group_id from node_public'):groups[grp].append(nid)
    for grp,members in groups.items():
        members=[x for x in sorted(members,key=lambda x:(x not in hub,noderank.get(x,len(oprank)),x)) if x in pos]
        if not members:continue
        top=members[0]
        lat,lon,on_osm=on_line(members,*pos[top])
        ends=[span[x][1] for x in members if x in span]
        shut=int(bool(ends) and max(ends)!='9999')
        h=int(any(x in hub for x in members))
        p=dict(g=gn.get(grp,0),hub=h,closed=shut,node=top)
        if ends:p['ty']=9999 if max(ends)=='9999' else year(max(ends))
        starts=[year(span[x][0]) for x in members if x in span and span[x][0]]
        if starts:p['fy']=min(starts)
        for l in ('ja','ko','en'):
            if l in label[top]:p[l]=label[top][l]
        point=json.dumps(dict(type='Feature',tippecanoe=dict(layer='station',minzoom=8 if h else 10),properties=p,geometry=dict(type='Point',coordinates=[lon,lat])),ensure_ascii=False)+'\n'
        (osm_points.append(point) if on_osm else f.write(point))
    # 위치 미확인 표식. 기준 역과 방향은 빌드가 정한다 (ARCHITECTURE §2.6)
    for mid,node,bearing in m.execute('select id,anchor_node,bearing from map_marker'):
        if node not in pos:continue
        lat,lon,on_osm=on_line([node],*pos[node])
        point=json.dumps(dict(type='Feature',tippecanoe=dict(layer='marker',minzoom=8),properties=dict(m=mid,bearing=bearing,closed=1),geometry=dict(type='Point',coordinates=[lon,lat])),ensure_ascii=False)+'\n'
        (osm_points.append(point) if on_osm else f.write(point))
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
for t in ('edge_shape','junction','denominator'):db.execute('drop table '+t)
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
