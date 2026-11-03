# -*- coding: utf-8 -*-
# 로컬 QA: 현행 N02 선형을 OSM 경로와 겹쳐 본다. 결과는 공개 데이터에 넣지 않는다 (설계 §2.11)
#   python3 -I tools/dev/geo_qa.py [허용 km]
# 다른 노선 선로를 탔거나 평행선으로 돌아간 구간을 찾는다. 결과: data/candidates/geo_qa.json
import sys,os,json,math,collections
T=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0,T)
src=open(os.path.join(T,'gen_geometry.py'),encoding='utf-8').read()
exec(compile(src.split("# 1. 믿을 수 없는 노드가 낀 구간은")[0],'gen_geometry','exec'))
tol=float(sys.argv[1]) if len(sys.argv)>1 else .1
ja={}
for x in load('names'):
    if x['entity_type']=='node' and x['lang']=='ja' and x['id'] not in ja and not x.get('line') and not x.get('valid_to'):ja[x['id']]=x['text']
geo={g['edge']:g for g in load('geometry') if g['source']!='osm'}
def overlap(p,q):
    """p의 100m 표본 중 q에서 tol 안에 있는 비율"""
    pts=[];acc=0.0
    for a,b in zip(p,p[1:]):
        L=seglen(a,b);acc+=L
        n=int(L/.1)
        for i in range(1,n+1):pts.append((a[0]+(b[0]-a[0])*i/(n+1),a[1]+(b[1]-a[1])*i/(n+1)))
        pts.append(tuple(b))
    cs=math.cos(math.radians(p[0][1]));lim=tol/111.0;h=0
    for x in pts:
        for a,b in zip(q,q[1:]):
            ax,ay=(a[0]-x[0])*cs,a[1]-x[1];bx,by=(b[0]-x[0])*cs,b[1]-x[1]
            ex,ey=bx-ax,by-ay;t=max(0,min(1,-(ax*ex+ay*ey)/((ex*ex+ey*ey) or 1e-18)))
            if math.hypot(ax+t*ex,ay+t*ey)<lim:h+=1;break
    return h/len(pts)
out=[];no=0
for e in edges:
    if e['id'] not in CUR or e['id'] not in geo:continue
    A,B=lonlat(e['a']),lonlat(e['b'])
    if not A or not B:continue
    c=[tuple(x) for x in geo[e['id']]['coords']];k=km.get(e['id']) or 0
    if '新幹線' in lines[e['seed_line']]['name_ja']:continue
    o=pick('osm',LT(e['id']),c[0],c[-1],k or pathlen(c),False,.3,.3)
    if not o:no+=1;continue
    f=overlap(c,o['path'])
    if f<.8:out.append(dict(edge=e['id'],line=lines[e['seed_line']]['name_ja'],a=ja.get(e['a']),b=ja.get(e['b']),km=k,n02=round(pathlen(c),2),osm=round(o['L'],2),overlap=round(f,2),src=geo[e['id']]['source']))
out.sort(key=lambda x:x['overlap'])
json.dump(out,open(os.path.join(CAND,'geo_qa.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=0)
print('OSM 경로 없음',no,'겹침 낮음',len(out))
for x in out[:int(sys.argv[2]) if len(sys.argv)>2 else 60]:print(x)
