# -*- coding: utf-8 -*-
# 선형이 없는 폐지 edge를 国土数値情報 鉄道時系列(N05) 2024판 선로로 채운다 (DESIGN §2.11 순서 3, §7)
# gen_geometry.py가 이름·끝점 기준을 못 넘겨 놓친 구간을 같은 원본에서 다시 찾는다.
# 같은 노선 이름(또는 손 대조 표의 N05 이름)의 선로 조각을 이어 그래프로 만들고, 두 역에 가장 가까운 점 사이의 최단 경로를 쓴다.
# 경로 길이가 営業キロ와 크게 어긋나면 받지 않는다. 결과는 data/overrides/geometry/n05_fill.yaml (lib.load가 원본에 없는 edge만 채움)
#   python3 -I tools/dev/n05_fill.py [--write]
import sys,os,json,math,heapq,zipfile,sqlite3,collections,re
ROOT=os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','..')
Z=os.path.join(ROOT,'data','imports','n05','N05-24_GML.zip')
OUT=os.path.join(ROOT,'data','overrides','geometry','n05_fill.yaml')
db=sqlite3.connect(os.path.join(ROOT,'build','master.sqlite'))
db.execute(f"ATTACH '{os.path.join(ROOT,'build','names.sqlite')}' AS nm")

def km(p,q):
    return math.hypot((p[0]-q[0])*math.cos(math.radians((p[1]+q[1])/2))*111.32,(p[1]-q[1])*110.57)
def core(s):
    s=re.sub(r'[（(].*?[)）]','',s or '');s=re.sub(r'\s.*$','',s)
    return s.replace('ヶ','ケ').replace('本線','線')
def name(n,t='node'):
    r=db.execute("SELECT text FROM nm.name WHERE entity_type=? AND entity_id=? AND lang='ja' AND line_id IS NULL AND valid_from IS NULL AND valid_to IS NULL",(t,n)).fetchone()
    return r[0] if r else n

# N05 선로. (노선 이름, 사업자, 시작 해, 끝 해, 좌표)
feat=[]
for f in json.loads(zipfile.ZipFile(Z).read('UTF-8/N05-24_RailroadSection2.geojson').decode('utf-8'))['features']:
    p=f['properties']
    try:yb=int(p.get('N05_005b') or 0);ye=int(p.get('N05_005e') or 9999)
    except ValueError:continue
    feat.append((p.get('N05_002') or '',p.get('N05_003') or '',yb,ye,[tuple(c) for c in f['geometry']['coordinates']]))
BOX={id(f):(min(c[0] for c in f[4]),max(c[0] for c in f[4]),min(c[1] for c in f[4]),max(c[1] for c in f[4])) for f in feat}

# N05 역 점. 같은 역도 시기마다 점이 따로다 (이전한 역은 옛 자리와 새 자리)
stas=collections.defaultdict(list)
for f in json.loads(zipfile.ZipFile(Z).read('UTF-8/N05-24_Station2.geojson').decode('utf-8'))['features']:
    p=f['properties']
    try:yb=int(p.get('N05_005b') or 0);ye=int(p.get('N05_005e') or 9999)
    except ValueError:continue
    if yb==999:yb=1950
    stas[(p.get('N05_011') or '').replace('ヶ','ケ')].append((core(p.get('N05_002') or ''),yb,ye,tuple(f['geometry']['coordinates'])))
KAN=dict(zip('0123456789','〇一二三四五六七八九'))
def spellings(node):
    """노드의 모든 일본어 이름(옛 이름 포함)과 숫자 표기 둘"""
    out=set()
    for (t,) in db.execute("SELECT DISTINCT text FROM nm.name WHERE entity_type='node' AND entity_id=? AND lang='ja'",(node,)):
        t=re.sub(r'【旧】|\(.*?\)|（.*?）','',t).replace('ヶ','ケ')
        out|={t,''.join(KAN.get(ch,ch) for ch in t),re.sub('[〇一二三四五六七八九]',lambda m:str('〇一二三四五六七八九'.index(m.group())),t)}
    # N05의 다른 자체: 竃(竈), 廿(二十). 足尾線 神戸는 1989 개칭 전 이름이 神土(N05 표기)
    out|={x.replace('竈','竃') for x in out}|{x.replace('二十','廿') for x in out}
    if name(node)=='神戸' and node in {n for (n,) in db.execute("SELECT DISTINCT node_id FROM route_stop rs JOIN route r ON r.id=rs.route_id WHERE r.line_id='l_watarase_keikoku_line' OR r.line_id='l_ashio_line'")}:out.add('神土')
    return out
def station_point(node,names,y0,y1,near):
    """그 노선(이름)의 그 시기 N05 역 점. 겹치는 해가 긴 것, 그다음 DB 좌표에 가까운 것"""
    cands=[c for sp in spellings(node) for c in stas.get(sp,()) if c[0] in names or c[0].replace('線','') in {x.replace('線','') for x in names}]
    best=None
    for ln,yb,ye,pt in cands:
        ov=min(ye,y1)-max(yb,y0)
        if ov<0:continue
        key=(-ov,km(pt,near) if near else 0)
        if best is None or key<best[0]:best=(key,pt)
    return best[1] if best else None

# 손 대조 표가 적은 N05 노선 이름 (DB 노선 → N05 이름)
fix=json.load(open(os.path.join(ROOT,'data','overrides','n05_fix.json'),encoding='utf-8'))['lines']
alias=collections.defaultdict(set)
for k,v in fix.items():
    if not isinstance(v,dict):continue
    keys={v.get('db_line_id')} if v.get('db_line_id') else set()
    line_part=k.split(' ',1)[1] if ' ' in k else k
    for n5,_ in v.get('n05_names') or []:
        alias[core(line_part.split(' ')[0])].add(core(n5))
        for x in keys:alias[x].add(core(n5))

class _Adj(collections.defaultdict):pass
def graph(fs):
    """조각을 이은 그래프. 끝점이 30m 안이면 잇는다"""
    adj=_Adj(list);pts=[];segs=[]
    for _,_,_,_,c in fs:
        for p,q in zip(c,c[1:]):
            d=km(p,q);adj[p].append((q,d));adj[q].append((p,d));segs.append((p,q))
        pts+=[c[0],c[-1]]
    grid=collections.defaultdict(list)
    for p in set(pts):grid[(round(p[0],3),round(p[1],3))].append(p)
    for p in set(pts):
        gx,gy=round(p[0],3),round(p[1],3)
        for dx in (-0.001,0,0.001):
            for dy in (-0.001,0,0.001):
                for q in grid.get((round(gx+dx,3),round(gy+dy,3)),()):
                    if q!=p and km(p,q)<0.03:adj[p].append((q,km(p,q)))
    adj.segs=segs
    return adj
def snap(adj,pt):
    """역을 가장 가까운 선분 위로 투영해 그 점을 그래프에 넣는다. N05 꼭짓점은 듬성해서 꼭짓점에 붙이면 구간이 사라진다"""
    best=None
    cx=math.cos(math.radians(pt[1]))
    for p,q in adj.segs:
        vx,vy=(q[0]-p[0])*cx,q[1]-p[1];wx,wy=(pt[0]-p[0])*cx,pt[1]-p[1]
        L=vx*vx+vy*vy;t=0 if L==0 else max(0,min(1,(vx*wx+vy*wy)/L))
        s=(p[0]+(q[0]-p[0])*t,p[1]+(q[1]-p[1])*t);d=km(s,pt)
        if best is None or d<best[0]:best=(d,s,p,q)
    if best is None:return None,9e9,None
    d,s,p,q=best
    if s not in adj:
        adj[s]=[(p,km(s,p)),(q,km(s,q))];adj[p].append((s,km(s,p)));adj[q].append((s,km(s,q)))
    return s,d,frozenset((p,q))
def nearest(adj,pt):return snap(adj,pt)
def path(adj,a,b):
    dist={a:0};prev={};h=[(0,a)]
    while h:
        d,v=heapq.heappop(h)
        if v==b:break
        if d>dist.get(v,9e9):continue
        for w,x in adj[v]:
            if d+x<dist.get(w,9e9):dist[w]=d+x;prev[w]=v;heapq.heappush(h,(d+x,w))
    if b not in dist:return None,None
    out=[b]
    while out[-1]!=a:out.append(prev[out[-1]])
    return out[::-1],dist[b]

sys.path.insert(0,os.path.join(ROOT,'tools'))
import lib as _lib
rows=[];report=collections.Counter();miss=[];fixpos={}
# 좌표가 겹치는 노드 (옛 역이 새 역 좌표를 그대로 가진 경우)
# 좌표 판정은 원본 좌표로 한다. 빌드 좌표는 이 도구의 보정을 이미 담고 있을 수 있다
SRC_POS={x['node']:x for x in _lib._rows(os.path.join(_lib.SRC,'positions'))}
# 사람이 원문으로 확인한 옛 역 좌표(이 도구가 쓰지 않는 보정 파일)는 N05 역 점보다 먼저 쓴다
CHECKED={x['node']:(x['lon'],x['lat']) for x in _lib._rows(os.path.join(ROOT,'data','overrides','positions')) if x.get('why')}
dup=collections.Counter((x['lon'],x['lat']) for x in SRC_POS.values() if x.get('lon') is not None)
current={n for (n,) in db.execute("SELECT DISTINCT node_id FROM route_stop WHERE is_stop=1 AND valid_to='ongoing'")}
# 대상은 원본(data/source/geometry)에 선형이 없는 edge다. 빌드는 이 도구의 결과를 이미 담고 있을 수 있다
SRC_GEO={g['edge'] for g in _lib._rows(os.path.join(_lib.SRC,'geometry'))+_lib._rows(os.path.join(ROOT,'data','overrides','source_patch','geometry'))}
q="""SELECT e.id,e.from_node,e.to_node,k.km FROM edge e JOIN edge_km k ON k.edge_id=e.id ORDER BY e.id"""
# 사람이 좌표를 고친 역에 닿는 원본 선형은 끝이 옛 좌표에 남아 선이 끊긴다. 끝이 80m 넘게 떨어지면 다시 찾는다 (source_patch로 바꿈)
_G={g['edge']:g['coords'] for g in _lib._rows(os.path.join(_lib.SRC,'geometry')) if g.get('source')!='osm'}
REFIT=set()
for e_,a_,b_ in db.execute("SELECT id,from_node,to_node FROM edge"):
    if e_ in _G and (a_ in CHECKED or b_ in CHECKED):
        c_=_G[e_]
        if any(n_ in CHECKED and min(km(c_[0],CHECKED[n_]),km(c_[-1],CHECKED[n_]))>0.08 for n_ in (a_,b_)):REFIT.add(e_)
for eid,a,b,ekm in [x for x in db.execute(q).fetchall() if x[0] not in SRC_GEO or x[0] in REFIT]:
    attrs=db.execute("SELECT line_id,valid_from_lo,valid_to_hi FROM edge_attr WHERE edge_id=?",(eid,)).fetchall()
    pa=(SRC_POS[a].get('lon'),SRC_POS[a].get('lat'),SRC_POS[a].get('quality')) if a in SRC_POS else None
    pb=(SRC_POS[b].get('lon'),SRC_POS[b].get('lat'),SRC_POS[b].get('quality')) if b in SRC_POS else None
    lines={l for l,_,_ in attrs}
    names=set()
    for l in lines:
        n=name(l,'line');names|={core(n),core(n).replace('線','')+'線'}|alias.get(l,set())|alias.get(core(n),set())
    y0=max(1950,min(int((f or '1950')[:4]) for _,f,_ in attrs));y1=max(int((t or '9999')[:4]) for _,_,t in attrs)
    dbA=(pa[0],pa[1]) if pa and pa[0] is not None else None
    dbB=(pb[0],pb[1]) if pb and pb[0] is not None else None
    # 끝 역은 그 시기의 N05 역 점에 붙인다. 없으면 DB 좌표
    sA=CHECKED.get(a) or station_point(a,names,y0,y1,dbA);sB=CHECKED.get(b) or station_point(b,names,y0,y1,dbB)
    if name(a)==name(b):
        # 이전한 역의 옛·새 노드. 정차가 먼저 끝나는 노드가 먼저 끝나는 N05 점이다
        nm_=re.sub(r'【旧】|\(.*?\)|（.*?）','',name(a)).replace('ヶ','ケ')
        pts=sorted({(ye,yb,pt) for ln,yb,ye,pt in stas.get(nm_,()) if (ln in names or ln.replace('線','') in {x.replace('線','') for x in names}) and ye>=y0},key=lambda t:(t[0],t[1]))
        pts=[t for i,t in enumerate(pts) if not any(km(t[2],u[2])<0.02 for u in pts[:i])]
        if len(pts)>=2:
            end=lambda n_:max(((r or '9999') for (r,) in db.execute("SELECT valid_to FROM route_stop WHERE node_id=? AND is_stop=1",(n_,))),default='9999')
            old_,new_=(a,b) if end(a)<=end(b) else (b,a)
            got={old_:pts[0][2],new_:pts[-1][2]}
            sA,sB=got[a],got[b]
    A=sA or dbA;B=sB or dbB
    if A is None or B is None:
        report['miss']+=1;miss.append((eid,name(a),name(b),ekm,'좌표 없음'));continue
    for n_,db_pt,n5 in ((a,dbA,sA),(b,dbB,sB)):
        # DB 좌표가 없거나 다른 노드와 똑같으면(옛 역이 새 역 좌표를 복사) N05 역 점으로 보정한다
        # 지금 정차하는 역은 손대지 않는다. 같은 역 묶음의 노드는 좌표가 같은 것이 정상이다
        if n5 and n_ not in current and n_ not in CHECKED and (db_pt is None or dup.get(db_pt,0)>1) and (db_pt is None or km(db_pt,n5)>0.05):fixpos[n_]=n5
    lim=0.8 if (pa and 'approx' in (pa[2],pb[2] if pb else None)) else 0.5
    def try_with(fs,tag):
        if not fs:return None
        adj=graph(fs)
        va,da,ga=nearest(adj,A);vb,db_,gb=nearest(adj,B)
        if da>lim or db_>lim:return ('far',da,db_)
        if va==vb:return ('same',da,db_)
        # 두 역이 같은 선분에 투영될 때만 그 사이가 곧 경로다. 다른 선분이면 선로를 따라간다
        if ga==gb:adj[va].append((vb,km(va,vb)));adj[vb].append((va,km(va,vb)))
        p,L=path(adj,va,vb)
        if p is None:return ('gap',da,db_)
        # 선로를 따라간 길이라 営業キロ와 가까워야 한다. 많이 길면 돌아간 길, 많이 짧으면 역 점이 틀린 것이다
        ok=(ekm==0 and L<0.4) or (ekm>0 and (0.7<=L/ekm<=1.4 or abs(L-ekm)<0.4))
        # 같은 이름 선로이고 두 역이 선 위에 바로 붙으면(150m 안) 역 점의 오차로 보고 조금 넓게 받는다. 선로 자체는 N05의 것이다
        loose=not ok and tag=='name' and max(da,db_)<=0.15 and ekm>0 and 0.5<=L/ekm<=1.6
        if not ok and not loose:return ('ratio',round(L,2),ekm)
        if loose:tag='name_loose'
        return dict(edge=eid,source='N05-24',coords=[[round(x,5),round(y,5)] for x,y in p],n05=sorted({f[0] for f in fs})[:4],
                    L=round(L,2),km=ekm,snap=[round(da,2),round(db_,2)],how=tag)
    # 긴 선(한 노선 전체가 한 조각)도 있어 점을 건너뛰지 않는다. 경계 상자로 먼저 거른다
    box=(min(A[0],B[0])-0.04,max(A[0],B[0])+0.04,min(A[1],B[1])-0.03,max(A[1],B[1])+0.03)
    def close(c):return box[0]<=c[0]<=box[1] and box[2]<=c[1]<=box[3] and min(km(c,A),km(c,B))<3
    near=[f for f in feat if f[2]<=y1 and f[3]>=y0 and BOX[id(f)][0]<=box[1] and BOX[id(f)][1]>=box[0] and BOX[id(f)][2]<=box[3] and BOX[id(f)][3]>=box[2] and any(close(c) for c in f[4])]
    named=[f for f in near if core(f[0]) in names or core(f[0]).replace('線','') in {x.replace('線','') for x in names}]
    # 폐지된 edge는 폐지 전에 끝난 선로를 먼저 쓴다. 같은 이름의 새 선로가 섞이면 돌아가는 경로가 나온다 (大阪線 青山 옛 선)
    old_only=[f for f in named if f[3]<y1] if y1<9999 else []
    r=try_with(old_only,'name') if old_only else None
    if not isinstance(r,dict):r=try_with(named,'name')
    # 이름이 다른 선로로는 채우지 않는다. 표본에서 노면전차·지하철 선로에 붙는 오답이 나왔다 (八幡, 勝鬨橋)
    if isinstance(r,dict):
        rows.append(r);report[r['how']]+=1
    else:
        report['miss']+=1;miss.append((eid,name(a),name(b),ekm,sorted(name(l,'line') for l in lines),r))
# 0km 추정 구간: 양옆 구간에 선형이 있으면 그 맞닿는 끝끼리 잇는다. 같은 N05 선 위라 새 위치를 지어내지 않는다
have={g['edge']:g['coords'] for g in _lib._rows(os.path.join(_lib.SRC,'geometry')) if g.get('source')!='osm'}
have.update({r['edge']:r['coords'] for r in rows})
ends=collections.defaultdict(list)
for e_,a_,b_ in db.execute("SELECT id,from_node,to_node FROM edge"):
    if e_ in have:ends[a_].append((e_,a_,b_));ends[b_].append((e_,a_,b_))
def end_at(node,other):
    """node에서 끝나는 이웃 선형의 그 끝 좌표. other 쪽 구간은 빼고 본다"""
    pts=[]
    for e_,a_,b_ in ends.get(node,()):
        c=have[e_];nb=b_ if a_==node else a_
        if nb==other:continue
        # 노드 쪽 끝: a_가 노드면 처음 점이라고 가정하지 않고, 이웃 노드에서 먼 쪽 끝을 고른다
        pts.append(c[0] if a_==node else c[-1])
    return pts[0] if pts else None
still=[]
for m in miss:
    eid=m[0];ekm=m[3]
    if ekm!=0:still.append(m);continue
    a_,b_=db.execute("SELECT from_node,to_node FROM edge WHERE id=?",(eid,)).fetchone()
    pa_,pb_=end_at(a_,b_),end_at(b_,a_)
    if pa_ and pb_ and km(pa_,pb_)<0.5:
        rows.append(dict(edge=eid,source='N05-24',coords=[list(pa_),list(pb_)],n05=[],L=round(km(pa_,pb_),2),km=0,snap=[0,0],how='zero'));report['zero']+=1;report['miss']-=1
    else:still.append(m)
miss=still
print(dict(report))
for m in miss:print('못 찾음',m)
if '--write' in sys.argv:
    os.makedirs(os.path.dirname(OUT),exist_ok=True)
    with open(OUT,'w',encoding='utf-8') as o:
        o.write('# 国土数値情報 鉄道時系列(N05) 2024판에서 tools/dev/n05_fill.py가 다시 찾은 폐선 구간 선형. 非商用 조건, CC BY 4.0 아님 (data/source/geometry/LICENSE.md의 n05.yaml과 같은 조건)\n')
        for r in rows:
            if r['edge'] not in REFIT:o.write('- '+json.dumps({k:r[k] for k in ('edge','source','coords','n05','how','L','km','snap')},ensure_ascii=False)+'\n')
    print('썼음',OUT,len([r for r in rows if r['edge'] not in REFIT]))
    RF=os.path.join(ROOT,'data','overrides','source_patch','geometry','n05_refit.yaml')
    with open(RF,'w',encoding='utf-8') as o:
        o.write('# 사람이 좌표를 고친 옛 역(data/overrides/positions/research_29.yaml)에 닿는 원본 선형을 N05로 다시 맞춘 것. tools/dev/n05_fill.py가 씀\n')
        for r in rows:
            if r['edge'] in REFIT:o.write('- '+json.dumps(dict(patch='replace',edge=r['edge'],source='N05-24',coords=r['coords']),ensure_ascii=False)+'\n')
    print('썼음',RF,len([r for r in rows if r['edge'] in REFIT]),'다시 맞출 대상',sorted(REFIT))
    POS=os.path.join(ROOT,'data','overrides','positions','n05_fill.yaml')
    os.makedirs(os.path.dirname(POS),exist_ok=True)
    with open(POS,'w',encoding='utf-8') as o:
        o.write('# 좌표가 없거나 다른 노드 좌표를 그대로 가진 옛 역을 国土数値情報 鉄道時系列(N05) 2024판의 그 시기 역 점으로 (tools/dev/n05_fill.py). 非商用 조건\n')
        for n_,pt in sorted(fixpos.items()):o.write('- '+json.dumps(dict(node=n_,lat=round(pt[1],6),lon=round(pt[0],6),quality='approx',source='n05',checked='2026-11-05'),ensure_ascii=False)+'\n')
    print('썼음',POS,len(fixpos))
