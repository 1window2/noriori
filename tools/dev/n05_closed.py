# -*- coding: utf-8 -*-
# 선 없는 폐선 구간의 후보 경로를 国土数値情報 鉄道時系列(N05)과 대조해 data/overrides/closed_geometry.json을 만든다
# N05는 非商用이고 복제물 재배포가 안 된다. 대조에만 쓰고 좌표는 어디에도 옮기지 않는다. 경로는 N02나 OSM의 것이다
# 손으로 정한 항목(by가 n05가 아님)은 덮어쓰지 않는다. src가 null이면 그 구간은 받아들이지 않는다
# 실행: python3 -I tools/dev/n05_closed.py  (data/imports/n05/N05-24_GML.zip, build/master.sqlite 필요)
import sys,os,json,math,zipfile,collections,re,sqlite3
ROOT=os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TOOLS=os.path.join(ROOT,'tools');sys.path.insert(0,TOOLS)
src=open(os.path.join(TOOLS,'gen_geometry.py'),encoding='utf-8').read()
G={'__file__':os.path.join(TOOLS,'gen_geometry.py'),'__name__':'n05_closed'}
exec(src[:src.index("rows={};meta={};st=collections.Counter()")],G)
seglen=G['seglen']
IN=.1;SHARE=.9;MAXD=.15     # 경로 점의 90% 이상이 N05 선형 100m 안, 가장 먼 점도 150m 안
def core(s):
    s=re.sub(r'[（(].*?[)）]','',s or '').replace('溪','渓').replace('萠','萌')
    for x in ('本線','電気鉄道','鉄道線','鉄道','電鉄','線','支線'):s=s.replace(x,'')
    return s
z=zipfile.ZipFile(os.path.join(ROOT,'data','imports','n05','N05-24_GML.zip'))
P=[]
for f in json.loads(z.read('UTF-8/N05-24_RailroadSection2.geojson'))['features']:
    p=f['properties'];g=f['geometry']
    try:ye=int(p.get('N05_005e'))
    except (TypeError,ValueError):ye=0
    for l in (g['coordinates'] if g['type']=='MultiLineString' else [g['coordinates']]):
        P.append((core(p.get('N05_002','')),ye,[tuple(c[:2]) for c in l]))
GC=50;GRID=collections.defaultdict(set)
for i,(_,_,l) in enumerate(P):
    for u,v in zip(l,l[1:]):
        for a in range(int(min(u[0],v[0])*GC),int(max(u[0],v[0])*GC)+1):
            for b in range(int(min(u[1],v[1])*GC),int(max(u[1],v[1])*GC)+1):GRID[(a,b)].add(i)
def dseg(x,a,b):
    cs=math.cos(math.radians(x[1]))
    ax,ay=(a[0]-x[0])*cs,a[1]-x[1];bx,by=(b[0]-x[0])*cs,b[1]-x[1]
    ex,ey=bx-ax,by-ay;t=max(0,min(1,-(ax*ex+ay*ey)/((ex*ex+ey*ey) or 1e-18)))
    return 111.0*math.hypot(ax+t*ex,ay+t*ey)
def near(x,names,yr):
    """N05에서 이름이 같은 노선의, 폐지 무렵까지 있던 조각까지의 거리. 사업자가 바뀐 현행 노선의 옛 기록을 피하려고 이름으로 거른다"""
    best=9
    for i in GRID.get((int(x[0]*GC),int(x[1]*GC)),()):
        n_,ye,l=P[i]
        if ye<yr-3 or not any(a and n_ and (a in n_ or n_ in a) for a in names):continue
        for a,b in zip(l,l[1:]):best=min(best,dseg(x,a,b))
    return best
def samples(p,step=.05):
    o=[p[0]];acc=0
    for a,b in zip(p,p[1:]):
        acc+=seglen(a,b)
        if acc>=step:o.append(b);acc=0
    return o+[p[-1]]
db=sqlite3.connect(os.path.join(ROOT,'build','master.sqlite'))
hid={(a,b) for a,b in db.execute("select from_node,to_node from closed_section where map_visible=0")}
OUT=os.path.join(ROOT,'data','overrides','closed_geometry.json')
old=json.load(open(OUT,encoding='utf-8'))
new={k:v for k,v in old.items() if v.get('by')!='n05'}
st=collections.Counter()
for e in G['edges']:
    # 선 없는 구간과, 앞서 이 도구로 받아들여 지금은 선이 있는 구간을 다시 본다
    key=f"{e['seed_line']}|{e['a']}|{e['b']}"
    if key in new:continue      # 손으로 정한 항목 (by가 n05가 아님)
    if e['id'] in G['CUR'] or ((e['a'],e['b']) not in hid and (e['b'],e['a']) not in hid and old.get(key,{}).get('by')!='n05'):continue
    A,B=G['lonlat'](e['a']),G['lonlat'](e['b'])
    if not A or not B:st['nopos']+=1;continue
    k=G['km'].get(e['id']) or 0;lt=G['LT'](e['id']);yr=G['CLOSEY'].get(e['id'],0)
    names={core(G['lines'][x]['name_ja']) for x in lt}
    best=None
    for s_ in G['order'](True,yr):
        c=G['pick'](s_,lt,A,B,k,True,1.2,1.2)
        # 끝이 역에서 300m 넘게 떨어지면 역 점이 선 끝에서 멀어진다
        if not c or c['lvl']>=2 or c['far']>.3:continue
        ds=[near(x,names,yr) for x in samples(c['path'])]
        share=sum(1 for x in ds if x<=IN)/len(ds)
        if share>=SHARE and max(ds)<=MAXD and (best is None or c['lvl']<best[0]['lvl']):best=(c,share,max(ds))
    if not best:st['none']+=1;continue
    c,share,mx=best
    new[key]=dict(src=c['src'],by='n05',why=f"N05 대조: 경로 점의 {share:.0%}가 100m 안, 가장 먼 점 {mx*1000:.0f}m. 길이 {c['L']:.2f}km, 영업km {k}")
    st['ok']+=1
json.dump(dict(sorted(new.items())),open(OUT,'w',encoding='utf-8'),ensure_ascii=False,indent=0)
open(OUT,'a',encoding='utf-8').write('\n')
print(dict(st),len(new))
