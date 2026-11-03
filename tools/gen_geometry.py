# -*- coding: utf-8 -*-
# 선로 원천에서 edge별 선형을 찾는다. N02 최신판부터 옛 판 순서로, 없으면 OSM에서 찾는다
# OSM 유래 선형은 geometry/osm.yaml에만 쓴다. ODbL이라 master.sqlite, rail.pmtiles와 섞지 않는다
# 역 좌표가 보간값인 노드는 선로 위 km 비율 지점으로 옮긴다. OSM 경로로는 옮기지 않는다
import sys,os,re,json,struct,zipfile,io,math,heapq,collections,gzip,sqlite3
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from lib import *
Z=os.path.join(IMP,'n02')
OPN={'o_japanese_national_railways':['旅客鉄道'],'o_jr_hokkaido':['北海道旅客鉄道'],'o_jr_east':['東日本旅客鉄道'],'o_jr_central':['東海旅客鉄道'],'o_jr_west':['西日本旅客鉄道'],'o_jr_shikoku':['四国旅客鉄道'],'o_jr_kyushu':['九州旅客鉄道']}

def read_shp(z,shp,dbf,enc):
    b=z.read(shp);d=z.read(dbf)
    nrec=struct.unpack('<I',d[4:8])[0];hl,rl=struct.unpack('<HH',d[8:12])
    fields=[];p=32
    while d[p]!=0x0d:
        nm=d[p:p+11].split(b'\0')[0].decode('ascii');ln=d[p+16];fields.append((nm,ln));p+=32
    recs=[]
    for i in range(nrec):
        o=hl+i*rl+1;r={}
        for nm,ln in fields:
            r[nm]=d[o:o+ln].decode(enc,'ignore').strip();o+=ln
        recs.append(r)
    out=[];p=100;i=0
    while p<len(b):
        num,ln=struct.unpack('>II',b[p:p+8]);p+=8
        c=b[p:p+ln*2];p+=ln*2
        st=struct.unpack('<i',c[:4])[0]
        if st==3:
            np_,nq=struct.unpack('<ii',c[36:44])
            parts=list(struct.unpack('<%di'%np_,c[44:44+4*np_]))+[nq]
            q=44+4*np_
            pts=struct.unpack('<%dd'%(2*nq),c[q:q+16*nq])
            for a,e in zip(parts,parts[1:]):
                out.append((recs[i],[(pts[2*k],pts[2*k+1]) for k in range(a,e)]))
        i+=1
    return out
def load_year(y):
    f=os.path.join(Z,f'N02-{y}_GML.zip');zz=zipfile.ZipFile(f)
    names=zz.namelist()
    gj=[n for n in names if n.endswith('RailroadSection.geojson') and 'UTF-8' in n]
    out=[]
    if gj:
        d=json.loads(zz.read(gj[0]).decode('utf-8'))
        for ft in d['features']:
            p=ft['properties'];g=ft['geometry']
            ls=g['coordinates'] if g['type']=='MultiLineString' else [g['coordinates']]
            for l in ls:out.append((p.get('N02_003',''),p.get('N02_004',''),[tuple(c[:2]) for c in l]))
        return out
    shp=[n for n in names if n.endswith('RailroadSection.shp') and '_v1.0' in n] or [n for n in names if n.endswith('RailroadSection.shp')]
    shp=shp[0];dbf=shp[:-3]+'dbf'
    for r,l in read_shp(zz,shp,dbf,'cp932'):
        out.append((r.get('N02_003',''),r.get('N02_004',''),l))
    return out
def load_stations(y):
    """판별 역 점. 승강장 선분의 가운데를 노선별로 돌려준다"""
    f=os.path.join(Z,f'N02-{y}_GML.zip');zz=zipfile.ZipFile(f)
    names=zz.namelist();out=collections.defaultdict(list)
    gj=[n for n in names if n.endswith('Station.geojson') and 'UTF-8' in n]
    if gj:
        for ft in json.loads(zz.read(gj[0]).decode('utf-8'))['features']:
            p=ft['properties'];g=ft['geometry']
            c=g['coordinates'] if g['type']=='LineString' else [g['coordinates']]
            out[znorm(p.get('N02_005',''))].append((p.get('N02_003',''),p.get('N02_004',''),[tuple(x[:2]) for x in c]))
        return out
    shp=[n for n in names if n.endswith('Station.shp') and '_v1.0' in n] or [n for n in names if n.endswith('Station.shp')]
    shp=shp[0]
    for r,l in read_shp(zz,shp,shp[:-3]+'dbf','cp932'):
        out[znorm(r.get('N02_005',''))].append((r.get('N02_003',''),r.get('N02_004',''),l))
    return out
LICENSE='''# 선형의 이용 조건

이 폴더의 선형은 원 자료의 조건을 따르고 다시 허락하지 않습니다. 파일마다 조건이 달라 나눴습니다.

| 파일 | 원 자료 | 조건 |
|---|---|---|
| `n02.yaml` | 国土数値情報 鉄道データ (N02) 2020·2024판 | CC BY 4.0 |
| `n02_legacy.yaml` | 国土数値情報 鉄道データ (N02) 2005·2008·2015판 | 国土数値情報 이용 조건 (商用可). CC BY 4.0 아님 |
| `osm.yaml` | OpenStreetMap | Open Database License (ODbL) 1.0 |

N02 표시: 「国土数値情報（鉄道データ）」（国土交通省）を加工して作成。このデータは国土交通省が作成したものではありません。

## OpenStreetMap

`osm.yaml`과 여기서 만든 `rail-osm.pmtiles`는 © OpenStreetMap contributors 자료에서 뽑은 데이터베이스이고 Open Database License 1.0으로 제공합니다. 조문은 <https://opendatacommons.org/licenses/odbl/1-0/>, 안내는 <https://www.openstreetmap.org/copyright>에 있습니다.

- 지도나 앱에 쓸 때는 `© OpenStreetMap contributors`를 표시합니다.
- 이 데이터베이스를 고쳐 공개하면 고친 내용도 ODbL로 공개합니다.
- `osm.yaml`의 선형은 `master.sqlite`, `names.sqlite`, `rail.pmtiles`에 넣지 않습니다. 역의 원래 좌표에도 쓰지 않습니다. 이 선에 맞춘 역 점은 `rail-osm.pmtiles`에만 있습니다 (설계 §2.11).

받은 원본은 `data/imports/osm/`에 있고 공개하지 않습니다. 판과 받은 날은 `data/sources.lock`에 있습니다.
'''
YEARS=['24','20','15','08','05']
ED={'24':2024,'20':2020,'15':2015,'08':2008,'05':2005}
LEGACY=('N02-05','N02-08','N02-15')
DATA={};STN={}
for y in YEARS:
    DATA[y]=load_year(y);STN[y]=load_stations(y)
    print(y,len(DATA[y]),len(STN[y]),flush=True)
# OSM: data/imports/osm/의 가장 새 폴더. 받은 값은 신뢰하지 않으므로 좌표와 이름, 종류만 쓴다
ACTIVE={'rail','subway','light_rail','tram','narrow_gauge','monorail','funicular'}
def load_osm():
    base=os.path.join(IMP,'osm')
    if not os.path.isdir(base):return None
    fd=sorted(x for x in os.listdir(base) if os.path.isdir(os.path.join(base,x)))
    if not fd:return None
    out={};d=os.path.join(base,fd[-1])
    for f in sorted(os.listdir(d)):
        if not f.endswith('.json.gz'):continue
        for w in json.loads(gzip.open(os.path.join(d,f),'rb').read().decode('utf-8')).get('elements',[]):
            if w.get('type')!='way' or not isinstance(w.get('id'),int) or w['id'] in out:continue
            t=w.get('tags') or {};g=w.get('geometry') or []
            try:c=[(round(float(p['lon']),6),round(float(p['lat']),6)) for p in g]
            except (TypeError,KeyError,ValueError):continue
            if len(c)<2:continue
            r=str(t.get('railway',''))
            if r in ACTIVE and t.get('service')!='yard':kind='a'
            elif r in ('abandoned','razed','disused','dismantled','preserved') or 'abandoned:railway' in t or 'razed:railway' in t or 'disused:railway' in t:kind='o'
            else:continue
            nm=' '.join(str(t.get(k,'')) for k in ('name','name:ja','official_name','old_name','abandoned:name','razed:name','disused:name'))[:120]
            out[w['id']]=(nm,kind,c)
    return [out[k] for k in sorted(out)]
OSM=load_osm()
SRCS=list(YEARS)
if OSM is not None:
    DATA['osm']=OSM;SRCS.append('osm');print('osm',len(OSM),flush=True)
lines={l['id']:l for l in load('lines')}
ops={o['id']:o for o in load('operators')}
edges=load('edges')
ids={e['id']:e for e in edges}
pos={p['node']:p for p in load('positions')}
km={k['edge']:k['km'] for k in load('km')}
# 현행 여부와 폐지 연도는 앞서 돈 compile의 결과로 본다
_db=sqlite3.connect(os.path.join(BUILD,'master.sqlite'))
CUR={r[0] for r in _db.execute("select distinct edge_id from edge_attr where valid_to='ongoing'")}
CLOSEY={}
for e_,v_ in _db.execute("select edge_id,max(valid_to) from edge_life group by 1"):
    if v_ and v_!='ongoing' and v_[:4].isdigit():CLOSEY[e_]=int(v_[:4])
STOPS={r[0] for r in _db.execute("select distinct node_id from route_stop where is_stop=1 and valid_to='ongoing'")}
LOPS=collections.defaultdict(set)
ELINE=collections.defaultdict(set)
for e_,l_,o_ in _db.execute("select distinct edge_id,line_id,operator_id from edge_attr"):
    ELINE[e_].add(l_)
    if o_ in ops:LOPS[l_].add(ops[o_]['name_ja'])
_db.close()
MOVED=json.load(open(os.path.join(ROOT,'data','overrides','moved.json'),encoding='utf-8'))
def seglen(a,b):
    p=math.radians((a[1]+b[1])/2)
    return math.hypot((a[1]-b[1])*111.0,(a[0]-b[0])*111.0*math.cos(p))
def pathlen(c):return sum(seglen(a,b) for a,b in zip(c,c[1:]))
Q=lambda c:(round(c[0],5),round(c[1],5))
# 노선과 조각의 관계: 0 자기 노선, 1 같은 회사나 이름만 같음, 2 다른 노선, 3 쓰지 않을 종류, 4 끊긴 끝을 이은 곳
WN=(1.0,1.25,2.0,4.0,4.0)
WS=(1.0,3.0,5.0,8.0,8.0)     # 신칸센은 병행 재래선으로 새지 않게 더 강하게 막는다
WE=3.0                       # 역에서 선로까지의 거리 가중치
def key_names(l):
    n=l['name_ja'];o={znorm(n)}
    s=l.get('sd')
    if s:
        s2=re.sub(r'[（(].*?[)）]','',s);s2=re.sub(r'^JR','',s2);o.add(znorm(s2))
    return o|{k.replace('本線','線') for k in o}|{k.replace('線','本線') for k in o if not k.endswith('本線')}
def n02_names(nm):
    o={znorm(nm)}
    # 지하철은 N02에서 '1号線(御堂筋線)', '5号線東西線' 꼴이다
    m_=re.search(r'[（(](.+?)[)）]',nm) or re.match(r'^\d+号線(.+)$',nm)
    if m_:o.add(znorm(m_.group(1)))
    return o
# N02의 사업자 이름 중 옛 이름인 것
OPAL={'東京急行電鉄':'東急電鉄','箱根登山鉄道':'小田急箱根','松本電気鉄道':'アルピコ交通','大阪高速鉄道':'大阪モノレール','総武流山電鉄':'流鉄','富士急行':'富士山麓電気鉄道','上田交通':'上田電鉄','一畑電気鉄道':'一畑電車','土佐電氣鐵道':'とさでん交通','岳南鉄道':'岳南電車','小湊鐵道':'小湊鉄道','大阪府都市開発':'南海電気鉄道','泉北高速鉄道':'南海電気鉄道','横浜新都市交通':'横浜シーサイドライン','アイジーアールいわて銀河鉄道':'IGRいわて銀河鉄道','WILLER\u3000TRAINS':'京都丹後鉄道（WILLER TRAINS）'}
def same_op(l,co):
    co=OPAL.get(co,co);cs=LOPS.get(l['id'],())
    if '旅客鉄道' in co:return l.get('family')=='jr' or any(c.startswith('JR') or c=='日本国有鉄道' for c in cs)
    return any(co in c or c in co or co[:4]==c[:4] for c in cs)
CC={}
# 한 구간을 여러 노선이 쓰기도 한다. 3섹 전환 구간은 seed_line이 옛 JR 노선이라 지금 노선까지 함께 본다
NC={}
def names_of(t):
    if t not in NC:NC[t]=set().union(*[key_names(lines[x]) for x in t])
    return NC[t]
def op_ok(t,co):return any(same_op(lines[x],co) for x in t)
def piece_class(t,closed,src,i):
    nm,co,_=DATA[src][i]
    k=(t,closed,src=='osm',nm,co)
    r=CC.get(k)
    if r is None:
        ks=names_of(t)
        if src=='osm':
            own=any(x and len(x)>=3 and x in nm for x in ks)
            if closed:r=(0 if own else 1) if co=='o' else 2
            else:r=(0 if own else 1) if co=='a' else 3
        else:
            nn=n02_names(nm);name=bool(nn&ks);op=op_ok(t,co)
            r=0 if name and op else (1 if op or (name and len(next(iter(nn)))>=4) else 2)
        CC[k]=r
    return r
GRID={}
GC=50                        # 칸 크기 0.02도
for s_ in SRCS:
    G=collections.defaultdict(list)
    for i,(nm,co,l) in enumerate(DATA[s_]):
        seen=set()
        for u,v in zip(l,l[1:]):
            for a in range(int(min(u[0],v[0])*GC),int(max(u[0],v[0])*GC)+1):
                for b in range(int(min(u[1],v[1])*GC),int(max(u[1],v[1])*GC)+1):seen.add((a,b))
        for c in seen:G[c].append(i)
    GRID[s_]=G
def local(src,lid,closed,x0,y0,x1,y1):
    ids_=set()
    G=GRID[src]
    for a in range(int(x0*GC),int(x1*GC)+1):
        for b in range(int(y0*GC),int(y1*GC)+1):ids_.update(G.get((a,b),()))
    g=collections.defaultdict(list)
    for i in sorted(ids_):
        l=DATA[src][i][2];c=piece_class(lid,closed,src,i)
        # 나선 선로는 한 조각이 자기 자신과 같은 꼭짓점에서 교차한다. 그 점을 합치면 루프를 건너뛰므로 둘로 둔다
        seen=set();K=[]
        for j,x in enumerate(l):
            q=Q(x)
            K.append((round(q[0]+.00001,5),q[1]) if q in seen and 0<j<len(l)-1 else q);seen.add(q)
        for (u,v),U,V in zip(zip(l,l[1:]),K,K[1:]):
            if (u[0]<x0 and v[0]<x0) or (u[0]>x1 and v[0]>x1) or (u[1]<y0 and v[1]<y0) or (u[1]>y1 and v[1]>y1):continue
            if U==V:continue
            w=seglen(U,V);g[U].append((V,w,c));g[V].append((U,w,c))
    return g
def attach(g,pt,r):
    """pt에서 r km 안의 선로마다 가장 가까운 점을 찾아 그래프에 넣는다. {점:거리}"""
    cs=math.cos(math.radians(pt[1]));dy=r/111.0;dx=dy/cs
    out={};add=[]
    for u,nb in g.items():
        for v,w,c in nb:
            if u>v or min(u[0],v[0])>pt[0]+dx or max(u[0],v[0])<pt[0]-dx or min(u[1],v[1])>pt[1]+dy or max(u[1],v[1])<pt[1]-dy:continue
            ax,ay=(u[0]-pt[0])*cs,u[1]-pt[1];bx,by=(v[0]-pt[0])*cs,v[1]-pt[1]
            ex,ey=bx-ax,by-ay;t=-(ax*ex+ay*ey)/((ex*ex+ey*ey) or 1e-18)
            if 0<t<1:
                q=Q((u[0]+(v[0]-u[0])*t,u[1]+(v[1]-u[1])*t));d=seglen(q,pt)
                if d<r:add.append((q,u,v,c));out[q]=d
    for u,nb in g.items():
        if abs(u[0]-pt[0])>dx or abs(u[1]-pt[1])>dy:continue
        ax,ay=(pt[0]-u[0])*cs,pt[1]-u[1]
        if all((v[0]-u[0])*cs*ax+(v[1]-u[1])*ay<=0 for v,w,c in nb):
            d=seglen(u,pt)
            if d<r:out[u]=d
    for q,u,v,c in add:
        if q==u or q==v:continue
        a,b=seglen(q,u),seglen(q,v)
        g[q].append((u,a,c));g[q].append((v,b,c));g[u].append((q,a,c));g[v].append((q,b,c))
    return out
def stitch(g,rl,rt):
    """끊긴 끝을 앞쪽의 가까운 선로와 잇는다. N02 조각은 역 부근에서 끊겨 있기도 하고 회사가 다르면 이어져 있지 않다"""
    cell=collections.defaultdict(list);S=200
    for v in g:cell[(int(v[0]*S),int(v[1]*S))].append(v)
    R=max(1,int(max(rl,rt)/.45)+1);add=[]
    for u,nb in g.items():
        nn={x[0] for x in nb}
        if len(nn)!=1:continue
        p=next(iter(nn));fx,fy=u[0]-p[0],u[1]-p[1]
        cs=math.cos(math.radians(u[1]));c=[]
        for a in range(int(u[0]*S)-R,int(u[0]*S)+R+1):
            for b in range(int(u[1]*S)-R,int(u[1]*S)+R+1):
                for v in cell.get((a,b),()):
                    if v==u or v in nn:continue
                    d=seglen(u,v)
                    if d>rl:continue
                    if d>rt and len({x[0] for x in g[v]})!=1:continue
                    dot=(v[0]-u[0])*fx*cs*cs+(v[1]-u[1])*fy
                    if d>1e-4 and dot<0:continue    # 뒤로는 잇지 않는다
                    n_=math.hypot(fx*cs,fy)*math.hypot((v[0]-u[0])*cs,v[1]-u[1])
                    c.append((d,v,dot/n_ if n_ else 1))
        # 가까운 점과, 곧장 앞에 있는 점. 끊긴 선로는 대개 곧게 이어진다
        c.sort()
        for d,v,_ in c[:3]+[x for x in c[3:] if x[2]>.9][:2]:add.append((u,v,d))
    for u,v,d in add:g[u].append((v,d,4));g[v].append((u,d,4))
def dijkstra(g,S,T,W,avoid=None):
    pq=[(WE*d,v) for v,d in S.items()];heapq.heapify(pq)
    dist={v:c for c,v in pq};prev={};best=None;bc=1e18
    while pq:
        c,v=heapq.heappop(pq)
        if c>=bc:break
        if c>dist.get(v,1e18):continue
        if v in T:
            tc=c+WE*T[v]
            if tc<bc:bc=tc;best=v
        for m,w,k in g.get(v,()):
            nc=c+w*W[k]
            if avoid and (v,m) in avoid:nc+=w*6
            if nc<dist.get(m,1e18):dist[m]=nc;prev[m]=(v,k);heapq.heappush(pq,(nc,m))
    if best is None:return None
    p=[best];cls=collections.Counter();v=best
    while v in prev:
        u,k=prev[v];cls[k]+=seglen(u,v);p.append(u);v=u
    return p[::-1],cls
def despike(p):
    """되돌아가는 꺾임을 지운다. N02에서는 복선의 두 선로가 조각 끝 한 점에서만 이어져 있어 그 점까지 갔다가 돌아오는 경로가 나온다"""
    i=1
    while i<len(p)-1:
        a,b,c=p[i-1],p[i],p[i+1];cs=math.cos(math.radians(b[1]))
        ux,uy=(a[0]-b[0])*cs,a[1]-b[1];vx,vy=(c[0]-b[0])*cs,c[1]-b[1]
        nn=math.hypot(ux,uy)*math.hypot(vx,vy)
        if nn==0 or (ux*vx+uy*vy)/nn<.5:i+=1;continue
        # 양쪽 다리를 거슬러 가며 가장 가까운 두 점을 찾아 잇는다
        best=None;la=0.0
        for x in range(i-1,-1,-1):
            la+=seglen(p[x],p[x+1])
            if la>.5:break
            lb=0.0
            for y in range(i+1,len(p)):
                lb+=seglen(p[y-1],p[y])
                if lb>.5:break
                d=seglen(p[x],p[y])
                if best is None or d<best[0]:best=(d,x,y)
        if best and best[0]<.1:
            p=p[:best[1]+1]+p[best[2]:];i=max(1,best[1])
        else:i+=1
    return p
def fit(L,k,level):
    if level==0:return max(.8*k-.2,.4*k)<=L<=1.2*k+.2
    return max(.7*k-.3,.4*k)<=L<=1.35*k+.3
def is_shin(t):return any('新幹線' in lines[x]['name_ja'] for x in t)
def search(src,lid,A,B,k,closed,ra,rb,mode,avoid=None,pairs=False):
    """A에서 B까지 경로. mode 0은 있는 대로, 1은 끊긴 끝을 잇는다. pairs면 시작점과 끝점의 쌍마다 찾아 길이가 맞는 쪽을 고른다"""
    crow=seglen(A,B);m=max(1.5,k*.3,crow*.3)/111.0
    x0,x1=sorted((A[0],B[0]));y0,y1=sorted((A[1],B[1]));mx=m/math.cos(math.radians(y0))
    g=local(src,lid,closed,x0-mx,y0-m,x1+mx,y1+m)
    if not g:return None
    S=attach(g,A,ra);T=attach(g,B,rb)
    if not S or not T:return None
    if mode:stitch(g,1.5 if src=='osm' and closed else .6,.5 if src=='osm' else .3)
    W=WS if is_shin(lid) else WN
    def make(r_):
        if not r_:return None
        p,cls=r_;p=despike(p);L=pathlen(p)
        if L<=0:return None
        return dict(src=src,path=p,L=L,own=cls[0]/L,near=(cls[0]+cls[1])/L,bad=(cls[2]+cls[3])/L,gap=cls[4],far=max(seglen(p[0],A),seglen(p[-1],B)))
    if not pairs:return make(dijkstra(g,S,T,W,avoid))
    best=None
    # 역에서 먼 점은 빼고 본다. 역을 지나쳐 길이만 맞추는 경로가 나오면 안 된다
    near=lambda D:[x for x in sorted(D.items(),key=lambda x:x[1]) if x[1]<=max(.15,min(D.values())+.05)][:5]
    for s_,ds in near(S):
        for t_,dt in near(T):
            c=make(dijkstra(g,{s_:ds},{t_:dt},W))
            if c and (best is None or abs(c['L']-k)<abs(best['L']-k)):best=c
    return best
def order(closed,y):
    """찾을 원천 순서. 폐선은 폐지 직전 판부터 본다"""
    if not closed:return SRCS
    a=[s for s in YEARS if ED[s]<=(y or 9999)+1]
    b=[s for s in reversed(YEARS) if s not in a]
    # N02에 없는 2004년 이전 폐선은 같은 이름의 새 선로에 잘못 붙지 않게 N02를 보지 않는다
    if y and y<2004:a,b=[],[]
    return a+b+(['osm'] if OSM is not None else [])
def accept(c,closed,src,lid):
    if c['gap']>max(.8,.35*c['L']):return False
    if is_shin(lid) and c['own']<.5:return False
    if closed:
        if src=='osm':return c['near']>=.5
        return c['own']>=.6
    if src=='osm':return c['bad']<=.3
    return True
def pick(src,lid,A,B,k,closed,ra,rb):
    """한 원천에서 가장 맞는 경로. lvl 0 엄격히 맞음, 1 느슨히 맞음, 2 안 맞음"""
    shin=is_shin(lid);crow=seglen(A,B);best=None
    def lvl(c):
        # 현행 구간의 끝이 역에서 먼 경로는 길이가 맞아도 다른 선로에 붙은 것이다
        if not closed and c['far']>.3:return 2
        if shin:return 0 if c['L']<=1.4*crow+1.0 else 2
        return 0 if fit(c['L'],k,0) else (1 if fit(c['L'],k,1) else 2)
    for mode in (0,1):
        c=search(src,lid,A,B,k,closed,ra,rb,mode)
        if not c:continue
        # 짧은 길이 먼저 잡혀 길이가 안 맞으면 그 길을 피해 한 번 더 찾는다 (복복선, 루프)
        if not shin and lvl(c) and c['L']<k:
            av={(a,b) for a,b in zip(c['path'],c['path'][1:])}|{(b,a) for a,b in zip(c['path'],c['path'][1:])}
            c2=search(src,lid,A,B,k,closed,ra,rb,mode,av)
            if c2 and abs(c2['L']-k)<abs(c['L']-k):c=c2
        c['lvl']=lvl(c)
        if best is None or (c['lvl'],abs(c['L']-k))<(best['lvl'],abs(best['L']-k)):best=c
        if best['lvl']==0:break
    # 시작점이 나선 선로의 다른 바퀴에 잡히면 루프를 건너뛴다. 쌍마다 찾아 본다
    if best and best['lvl'] and not shin:
        c=search(src,lid,A,B,k,closed,ra,rb,0,None,True)
        if c:
            c['lvl']=lvl(c)
            if (c['lvl'],abs(c['L']-k))<(best['lvl'],abs(best['L']-k)):best=c
    return best
def inside(p,q,tol):
    """p의 점들이 모두 q 가까이에 있는가. 100m마다 본다"""
    pts=[];acc=0.0
    for a,b in zip(p,p[1:]):
        acc+=seglen(a,b)
        if acc>=.1:pts.append(b);acc=0.0
    # 끝은 원천마다 잡는 자리가 달라 빼고 본다
    pts=pts[2:-2] if len(pts)>6 else (pts[1:-1] if len(pts)>2 else [p[len(p)//2]])
    cs=math.cos(math.radians(p[0][1]));lim=tol/111.0
    def ds(x,a,b):
        ax,ay=(a[0]-x[0])*cs,a[1]-x[1];bx,by=(b[0]-x[0])*cs,b[1]-x[1]
        ex,ey=bx-ax,by-ay;t=max(0,min(1,-(ax*ex+ay*ey)/((ex*ex+ey*ey) or 1e-18)))
        return math.hypot(ax+t*ex,ay+t*ey)
    return all(any(ds(x,a,b)<lim for a,b in zip(q,q[1:])) for x in pts)
def close(p,q,tol=.15):
    """두 경로가 같은 선로 띠인가. 끝점이 가깝고 서로의 안에 들어가야 한다. 복복선은 원천마다 다른 줄을 잡아 100m 넘게 벌어지기도 한다"""
    return seglen(p[0],q[0])<.35 and seglen(p[-1],q[-1])<.35 and inside(p,q,tol) and inside(q,p,tol)
def best_path(lid,na,nb,A,B,k,closed,y,r):
    """맞는 경로를 찾는다. 없으면 (None, 가장 가까운 후보)"""
    k=k or seglen(A,B)*1.15
    cs=[]
    for src in order(closed,y):
        A2=stop_on(na,lid,src,A);B2=stop_on(nb,lid,src,B)
        # 승강장 가운데는 그 판의 선로 위에 있다. 반경을 좁혀 말발굽 선로의 다른 쪽에 붙지 않게 한다
        c=pick(src,lid,A2 or A,B2 or B,k,closed,.08 if A2 else r,.08 if B2 else r)
        # 상하선이 떨어진 역은 승강장 표가 다른 쪽 선로에 있기도 하다. 잇지 않고 가는 길이 있으면 그쪽을 쓴다
        if (A2 or B2) and (not c or c['lvl'] or c['gap']>0):
            c3=pick(src,lid,A2 or A,B2 or B,k,closed,.35 if A2 else r,.35 if B2 else r)
            if c3 and (not c or (c3['lvl'],c3['gap']>0)<(c['lvl'],c['gap']>0)):c=c3
        if c:c['plat']=('a' if A2 else '')+('b' if B2 else '')
        # 승강장이 다른 선로에 있으면 (상하선이 떨어진 역) 노드 좌표로 다시 찾는다
        if (A2 or B2) and (not c or c['lvl']==2):
            c2=pick(src,lid,A,B,k,closed,r,r)
            if c2 and (not c or c2['lvl']<c['lvl']):c=c2;c['plat']=''
        if not c:continue
        c['ok']=accept(c,closed,src,lid)
        if c['ok'] and c['lvl']==0 and src!='osm' and c['own']>=.5:
            # 이름이 안 맞아 미뤄 둔 새 판 경로가 같은 선로면 새 판을 쓴다 (3섹 전환 구간, 연락선)
            for x in cs:
                if x['ok'] and x['lvl']==0 and close(x['path'],c['path']):
                    x['ver']=True;return x,None
            return c,None
        if c['ok'] and c['lvl']==0 and src=='osm':
            # OSM과 같은 선로인 N02 경로가 있으면 길이가 영업km와 달라도 N02를 쓴다. 틀린 것은 경로가 아니라 km다
            for x in cs:
                if x['ok'] and close(x['path'],c['path']):
                    x['ver']=True;return x,None
            return c,None
        cs.append(c)
    good=[c for c in cs if c['ok'] and c['lvl']<2]
    if good:
        # 순서: 맞는 N02, 이름이 맞는 느슨한 N02, 느슨한 OSM, 나머지
        good.sort(key=lambda c:(c['lvl'],0 if c['src']!='osm' and c['own']>=.5 else (1 if c['src']=='osm' else 2)))
        if good[0]['src']=='osm':
            for x in cs:
                if x['src']!='osm' and x['ok'] and close(x['path'],good[0]['path']):
                    x['ver']=True;return x,None
        return good[0],None
    if not cs:return None,None
    own=[c for c in cs if c['src']!='osm' and c['ok'] and c['own']>=.5]
    last=own[0] if own else min(cs,key=lambda c:abs(c['L']-k))
    # 어느 원천으로도 길이가 안 맞으면 km가 틀린 구간이다. N02와 OSM이 같은 선로면 N02를 남긴다
    if last['src']=='osm':
        for x in cs:
            if x['src']!='osm' and x['ok'] and close(x['path'],last['path']):return None,x
    return None,last
def simplify(c,eps=.00004):
    if len(c)<3:return c
    a,b=c[0],c[-1];mx=-1;mi=0
    dx,dy=b[0]-a[0],b[1]-a[1];L=math.hypot(dx,dy) or 1e-12
    for i in range(1,len(c)-1):
        p=c[i];d=abs((p[0]-a[0])*dy-(p[1]-a[1])*dx)/L
        if d>mx:mx=d;mi=i
    if mx<eps:return [a,b]
    return simplify(c[:mi+1],eps)[:-1]+simplify(c[mi:],eps)
def tag(src):return 'osm' if src=='osm' else 'N02-'+src
def row(eid,c,p):
    r=dict(edge=eid,source=tag(c['src']),coords=[list(x) for x in simplify(p)])
    if c['gap']>0:r['match']='stitched'
    elif c['own']<.5:r['match']='near'
    return r
def plat_of(c,flip,first,last):
    """이 조각의 끝 중 N02 승강장에 맞춘 쪽. 공유 노드의 좌표와 떨어져 있어도 틀린 끝이 아니다"""
    o=''
    if first and 'a' in c['plat']:o+='b' if flip else 'a'
    if last and 'b' in c['plat']:o+='a' if flip else 'b'
    return ''.join(sorted(o))
def lonlat(n):
    p=pos.get(n)
    return (p['lon'],p['lat']) if p and p.get('lat') is not None else None
LABEL=collections.defaultdict(set)
for x in load('names'):
    if x['entity_type']=='node' and x['lang']=='ja':LABEL[x['id']].add(znorm(x['text']))
for x in load('aliases'):
    if x.get('entity_type')=='node' and x.get('lang')=='ja':LABEL[x['id']].add(znorm(x['text']))
def mid(c):return c[len(c)//2] if len(c)%2 else tuple((a+b)/2 for a,b in zip(c[len(c)//2-1],c[len(c)//2]))
PU={}
# 좌표를 믿을 수 없는 노드: 보간값, 없음, 역 이전으로 옛 노드와 새 노드의 좌표가 같은 경우
WEAK={n for n,p in pos.items() if p.get('lat') is None or p.get('source')=='interpolated'}
# 지금 서지 않는 옛 역은 원천 좌표가 같은 이름의 다른 역을 가리키기도 한다. 선로 위 km 지점과 300m 넘게 다르면 옮긴다
_cn=set()
for e_ in edges:
    if e_['id'] in CUR:_cn|={e_['a'],e_['b']}
SOFT={n for n in _cn if n not in STOPS and n not in WEAK and pos[n].get('source')!='hand'}
# 역 이전: 원천 좌표는 새 역 하나뿐이다. 옛 역은 이전 전 판의 승강장을 쓰고, 그런 판이 없으면 km로 자른다
for mv in MOVED:
    a,b=lonlat(mv['old']),lonlat(mv['new'])
    if not a or not b or seglen(a,b)>=.01:continue
    ls=[lines[x] for e_ in edges if mv['old'] in (e_['a'],e_['b']) for x in ELINE.get(e_['id'],set())|{e_['seed_line']}]
    got=None
    for y in YEARS:
        if ED[y]>=int(mv['date'][:4]):continue
        for t in sorted(LABEL[mv['old']]):
            for nm,co,c in STN[y].get(t,()):
                if any(n02_names(nm)&key_names(l) for l in ls) and seglen(mid(c),b)>.1:got=got or mid(c)
    if got:pos[mv['old']].update(lon=round(got[0],6),lat=round(got[1],6),source='n02',quality='precise');PU[mv['old']]=(got[0],got[1],'moved')
    else:WEAK.add(mv['old'])
byline=collections.defaultdict(lambda:collections.defaultdict(list))
for e in edges:
    if e.get('alt')=='old':continue
    byline[e['seed_line']][e['a']].append(e);byline[e['seed_line']][e['b']].append(e)
def other(e,n):return e['b'] if e['a']==n else e['a']
def stop_on(n,lid,src,pt):
    """그 노선의 승강장 가운데. 한 노드를 여러 노선이 쓰면 좌표가 하나뿐이라 노선마다 다른 자리를 찾는다"""
    if src=='osm' or n not in LABEL or not pt or NK.get(n)!='station':return None
    ks=names_of(lid);jr=all(lines[x].get('family')=='jr' for x in lid);best=None
    for t in LABEL[n]:
        for nm,co,c in STN[src].get(t,()):
            if not op_ok(lid,co):continue
            own=bool(n02_names(nm)&ks)
            # 이름이 다른 노선은 사철만 받는다. JR은 한 역에 노선이 많아 다른 노선의 승강장을 잡기 쉽다
            if not own and jr:continue
            q=mid(c);d=seglen(q,pt)
            if d<.7 and (best is None or (not own,d)<best[:2]):best=(not own,d,q)
    return best[2] if best else None
NK={n['id']:n.get('kind') for n in load('nodes')}
def LT(eid):return tuple(sorted(ELINE.get(eid,set())|{ids[eid]['seed_line']}))
rows={};meta={};st=collections.Counter()
# 1. 믿을 수 없는 노드가 낀 구간은 양쪽의 믿을 수 있는 노드 사이를 한 번에 찾아 km 비율로 자른다
done_chain=set();CHAINFAIL=[]
for lid in sorted(byline):
    adj=byline[lid]
    for n in sorted(adj):
        if (n not in WEAK and n not in SOFT) or len(adj[n])!=2 or n in done_chain:continue
        seq=[n];es=[]
        for side in (0,1):
            e=adj[n][side];cur=n;walk=[];wn=[]
            while True:
                walk.append(e);cur=other(e,cur);wn.append(cur)
                if (cur not in WEAK and cur not in SOFT) or len(adj[cur])!=2:break
                nx=[x for x in adj[cur] if x['id']!=e['id']]
                if not nx:break
                e=nx[0]
                if len(walk)>40:break
            if side==0:es=walk[::-1];seq=wn[::-1]+[n]
            else:es=es+walk;seq=seq+wn
        done_chain|=set(seq)
        if any(x in WEAK or x in SOFT for x in (seq[0],seq[-1])) or len(set(seq))!=len(seq):st['chain_open']+=1;continue
        A,B=lonlat(seq[0]),lonlat(seq[-1])
        if not A or not B:continue
        ks=[km.get(x['id']) or 0 for x in es];K=sum(ks)
        if K<=0:continue
        closed=all(x['id'] not in CUR for x in es)
        y=max((CLOSEY.get(x['id'],0) for x in es),default=None)
        c,_l=best_path(tuple(sorted(set().union(*[set(LT(x['id'])) for x in es]))),seq[0],seq[-1],A,B,K,closed,y,.6)
        if not c:st['chain_fail']+=1;CHAINFAIL.append([lines[lid]['name_ja'],seq,K,_l and round(_l['L'],2)]);continue
        # OSM 경로로는 좌표를 옮기지 못한다. 좌표가 있는 노드는 구간별로 그 좌표를 쓴다
        sure=c['src']!='osm' and (c['own']>=.5 or c.get('ver'))
        if not sure and all(lonlat(x) and x not in WEAK for x in seq[1:-1]):st['chain_skip']+=1;continue
        p=c['path'];L=c['L'];cum=[0.0]
        for a,b in zip(p,p[1:]):cum.append(cum[-1]+seglen(a,b))
        i=0;acc=0.0;pieces=[];pts=[];cur=[p[0]]
        for ki in ks[:-1]:
            acc+=ki/K*L
            while i+1<len(p) and cum[i+1]<acc:
                i+=1;cur.append(p[i])
            f=(acc-cum[i])/((cum[i+1]-cum[i]) or 1e-9) if i+1<len(p) else 0
            q=Q((p[i][0]+(p[min(i+1,len(p)-1)][0]-p[i][0])*f,p[i][1]+(p[min(i+1,len(p)-1)][1]-p[i][1])*f))
            cur.append(q);pieces.append(cur);pts.append(q);cur=[q]
        cur+=p[i+1:];pieces.append(cur)
        for j,(x,pc) in enumerate(zip(es,pieces)):
            a_,b_=seq[j],seq[j+1]
            fl=x['a']!=a_
            rows[x['id']]=row(x['id'],c,pc[::-1] if fl else pc)
            pl=plat_of(c,fl,j==0,j==len(es)-1)
            if pl:rows[x['id']]['plat']=pl
            meta[x['id']]=dict(L=pathlen(pc),own=round(c['own'],2),gap=round(c['gap'],2),src=c['src'],chain=len(es))
        # OSM 경로나 다른 노선 이름의 N02 경로에서 얻은 점은 그 구간 끝점으로만 쓴다. master.sqlite로 가는 좌표에는 믿을 수 있는 N02 값만 넣는다
        for nd,q in zip(seq[1:-1],pts):
            o=lonlat(nd)
            if nd in WEAK or (o and seglen(o,q)>.3):
                pos[nd]=dict(pos[nd],_on=(q[0],q[1]))
                if sure:
                    PU[nd]=(q[0],q[1],c['src']);pos[nd].update(lon=round(q[0],6),lat=round(q[1],6),source='n02',quality='approx')
        st['chain']+=1;st['chain_edges']+=len(es)
def where(n):
    a=pos.get(n) or {}
    return a.get('_on') or lonlat(n)
# 2. 나머지 구간
for e in edges:
    if e['id'] in rows:continue
    A,B=where(e['a']),where(e['b'])
    if not A or not B:st['nopos']+=1;continue
    k=km.get(e['id']) or 0
    closed=e['id'] not in CUR
    # 좌표가 어림값이면 선로에서 멀리 떨어져 있을 수 있다
    r=1.2 if closed or (pos[e['a']].get('quality')!='precise' or pos[e['b']].get('quality')!='precise') else .6
    c,last=best_path(LT(e['id']),e['a'],e['b'],A,B,k,closed,CLOSEY.get(e['id']),r)
    if c:
        rows[e['id']]=row(e['id'],c,c['path']);st[tag(c['src'])]+=1
        if c['plat']:rows[e['id']]['plat']=c['plat']
        meta[e['id']]=dict(L=c['L'],own=round(c['own'],2),gap=round(c['gap'],2),src=c['src'],lvl=c['lvl'])
    elif last and not closed:
        rows[e['id']]=row(e['id'],last,last['path']);st['fallback']+=1
        if last['plat']:rows[e['id']]['plat']=last['plat']
        meta[e['id']]=dict(L=last['L'],own=round(last['own'],2),gap=round(last['gap'],2),src=last['src'],fallback=1)
    else:st['miss_closed' if closed else 'miss']+=1
# 3. 같은 노선의 이웃 구간 끝을 맞춘다. 끊겨 보이는 곳은 대개 끝점이 어긋난 곳이다
def famil(r):return 'osm' if r['source']=='osm' else 'n02'
def end_of(eid,n):return -1 if ids[eid]['b']==n else 0
def join(L_,n):
    """한 노드에서 만나는 같은 노선의 구간 끝을 한 점으로 모은다"""
    P=[rows[e]['coords'][end_of(e,n)] for e in L_]
    far=max(seglen(p,q) for p in P for q in P)
    if far<1e-5:return
    if far>.6:st['join_far']+=1;return
    fam={famil(rows[e]) for e in L_}
    if len(fam)==1:m=[round(sum(p[0] for p in P)/len(P),5),round(sum(p[1] for p in P)/len(P),5)]
    else:
        # N02와 OSM 좌표를 서로 옮기지 않는다. 둘 다 역 좌표로 잇는다
        m=where(n)
        if not m:return
        m=[round(m[0],5),round(m[1],5)]
    for e,p in zip(L_,P):
        r=rows[e];x=end_of(e,n)
        if seglen(p,m)<1e-5:continue
        if far<.03 and len(fam)==1 and len(r['coords'])>2:r['coords'][x]=m
        elif x==0:r['coords'].insert(0,m)
        else:r['coords'].append(m)
    st['joined']+=1
for lid in sorted(byline):
    adj=byline[lid]
    for n in sorted(adj):
        L_=[e['id'] for e in adj[n] if e['id'] in rows]
        if len(L_)>1:join(L_,n)
# 끝이 역에서 멀면 역까지 잇는다. 현행 구간은 조금 더 멀어도 잇는다. 끊겨 보이는 것보다 낫다
for eid in sorted(rows):
    r=rows[eid];e=ids[eid];c=r['coords'];lim=1.2 if eid in CUR else .8
    A,B=where(e['a']),where(e['b']);pl=r.get('plat','')
    if A and 'a' not in pl and .3<seglen(c[0],A)<=lim:c.insert(0,[round(A[0],5),round(A[1],5)]);st['tostation']+=1
    if B and 'b' not in pl and .3<seglen(c[-1],B)<=lim:c.append([round(B[0],5),round(B[1],5)]);st['tostation']+=1
# 자동 탐색이 다른 선로를 고른 구간. OSM 선로를 손으로 따라간 값이다
for eid,fx in json.load(open(os.path.join(ROOT,'data','overrides','osm_manual.json'),encoding='utf-8')).items():
    rows[eid]=dict(edge=eid,source='osm',coords=fx['coords'])
os.makedirs(os.path.join(SRC,'geometry'),exist_ok=True)
out=[rows[k] for k in sorted(rows)]
# 2019년 이전 판은 CC BY 4.0이 아니라 "商用可" 조건이라 다시 허락할 수 없다. 파일을 나눠 조건을 구분한다
dump('geometry/n02.yaml',[x for x in out if x['source'] not in LEGACY and x['source']!='osm'],'N02 선로에서 뽑은 edge별 선형. 2020·2024판 (CC BY 4.0)')
dump('geometry/n02_legacy.yaml',[x for x in out if x['source'] in LEGACY],'N02 선로에서 뽑은 edge별 선형. 2005·2008·2015판 (商用可 조건, CC BY 4.0 아님)')
dump('geometry/osm.yaml',[x for x in out if x['source']=='osm'],'OpenStreetMap 선로에서 뽑은 edge별 선형. ODbL 1.0. master.sqlite, rail.pmtiles에 넣지 않는다')
# 보간 좌표를 선로 위로 옮긴 값. 나머지 좌표는 그대로 둔다
if PU:
    for p in pos.values():
        p.pop('_on',None)
    dump('positions/positions.yaml',list(pos.values()),'노드 좌표')
# gen_source가 data/source를 지우고 다시 만들므로 여기서 쓴다
with open(os.path.join(SRC,'geometry','LICENSE.md'),'w',encoding='utf-8') as o:o.write(LICENSE)
os.makedirs(CAND,exist_ok=True)
json.dump(dict(stats=st,positions=PU,meta=meta,chain_fail=CHAINFAIL),open(os.path.join(CAND,'geometry_report.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=0,sort_keys=True)
print(dict(st),len(rows),len(edges))
