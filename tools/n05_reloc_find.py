# -*- coding: utf-8 -*-
# 사용: python3 -I tools/n05_reloc_find.py data/candidates/reloc_cand.json. data/imports가 있는 체크아웃에서만 돈다
# N05에서 1950년 이후 폐지된 선로 중 DB 선형과 떨어진 부분 (옛 선로, 이설 전 경로, 빠진 구간 후보)
import sys,json,zipfile,math,collections,sqlite3,re
sys.path.insert(0,'tools')
from lib import IMP,BUILD
import os
def dec(s):
    i=0;lat=lon=0;o=[]
    while i<len(s):
        for k in (0,1):
            sh=r=0
            while True:
                b=ord(s[i])-63;i+=1;r|=(b&31)<<sh;sh+=5
                if b<32:break
            d=~(r>>1) if r&1 else r>>1
            if k==0:lat+=d
            else:lon+=d
        o.append((lon/1e5,lat/1e5))
    return o
def km(a,b):
    q=math.radians((a[1]+b[1])/2);return math.hypot((a[1]-b[1])*111.2,(a[0]-b[0])*111.2*math.cos(q))
m=sqlite3.connect(os.path.join(BUILD,'master.sqlite'))
GC=500;G=collections.defaultdict(list)
import glob
def shapes():
    for f in glob.glob(os.path.join(ROOTS,'data','source','geometry','*.yaml')):
        for l in open(f,encoding='utf-8'):
            if l.startswith('- {'):
                x=json.loads(l[2:]);yield x.get('coords') or []
ROOTS=os.path.dirname(BUILD)
for pts in shapes():
    pts=[tuple(c[:2]) for c in pts]
    for a,b in zip(pts,pts[1:]):
        n=max(1,int(km(a,b)/.1))
        for t in range(n+1):
            x=(a[0]+(b[0]-a[0])*t/n,a[1]+(b[1]-a[1])*t/n);G[(int(x[0]*GC),int(x[1]*GC))].append(x)
def near(x,r=.2):
    gx,gy=int(x[0]*GC),int(x[1]*GC)
    for i in (-1,0,1):
        for j in (-1,0,1):
            for y in G.get((gx+i,gy+j),()):
                if km(x,y)<r:return True
    return False
z=zipfile.ZipFile(os.path.join(IMP,'n05','N05-24_GML.zip'))
CITY=re.compile(r'(市|都|市交通局|市電気局)$');TRAM=re.compile(r'市内線|軌道線|国道線|市電|電気軌道|路面|併用軌道|築港線|循環線|系統|トロリー')
ST=collections.defaultdict(list)
for f in json.loads(z.read('UTF-8/N05-24_Station2.geojson'))['features']:
    p=f['properties'];c=f['geometry']['coordinates'];g=f['geometry']['type']
    c=c[len(c)//2] if g=='LineString' else (c if g=='Point' else c[0][len(c[0])//2])
    ST[(p['N05_002'],p['N05_003'])].append((p['N05_011'],p['N05_005b'],p['N05_005e'],tuple(c[:2])))
out=[]
for f in json.loads(z.read('UTF-8/N05-24_RailroadSection2.geojson'))['features']:
    p=f['properties'];g=f['geometry']
    try:ye=int(p['N05_005e'])
    except (TypeError,ValueError):continue
    if not 1949<=ye<9999:continue
    if p['N05_001']=='3' and CITY.search(p['N05_003']) or TRAM.search(p['N05_002']):continue
    for l in (g['coordinates'] if g['type']=='MultiLineString' else [g['coordinates']]):
        l=[tuple(c[:2]) for c in l];L=sum(km(a,b) for a,b in zip(l,l[1:]))
        if L<.3:continue
        # 기록 안에서 DB 선형과 이어서 떨어진 토막. 국철 본선은 시기별 한 기록이라 옛 선로가 그 안에 있다
        flag=[not near(x) for x in l];runs=[];cur=[]
        for x,fl in zip(l,flag):
            if fl:cur.append(x)
            elif cur:runs.append(cur);cur=[]
        if cur:runs.append(cur)
        for r in runs:
            R=sum(km(a,b) for a,b in zip(r,r[1:]))
            if R<1.0:continue
            sts=sorted({s[0] for s in ST[(p['N05_002'],p['N05_003'])] if any(km(s[3],x)<.3 for x in r)})
            out.append(dict(line=p['N05_002'],op=p['N05_003'],kind=p['N05_001'],yb=p['N05_005b'],ye=ye,km=round(R,1),far=1.0,stations=sts,a=r[0],b=r[-1]))
# 같은 옛 선로가 여러 시기 기록에 되풀이된다. 노선·사업자와 끝점 위치(1km)로 합치고 가장 늦은 해를 남긴다
res=[]
for o in sorted(out,key=lambda o:(o['op'],o['line'],-o['ye'])):
    hit=next((r for r in res if r['line']==o['line'] and r['op']==o['op'] and min(km(r['start'],o['a'])+km(r['end'],o['b']),km(r['start'],o['b'])+km(r['end'],o['a']))<2),None)
    if hit:hit['seen'].append(o['ye']);continue
    res.append(dict(line=o['line'],op=o['op'],closed_after=o['ye'],km=o['km'],stations=o['stations'],start=o['a'],end=o['b'],seen=[o['ye']]))
res.sort(key=lambda r:(r['closed_after'],r['op'],r['line']))
json.dump(res,open(sys.argv[1],'w',encoding='utf-8'),ensure_ascii=False,indent=0)
print(len(res),'후보',round(sum(r['km'] for r in res),1),'km')
for r in res[:400]:print(r['closed_after'],r['op'],r['line'],r['km'],'km',r['stations'][:8])
