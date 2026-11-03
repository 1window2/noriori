# -*- coding: utf-8 -*-
# 인접 역의 좌표 거리와 영업km를 비교해 이름이 같은 다른 역으로 잘못 연결된 곳을 찾는다
import sys,os,math,collections,json
sys.path.insert(0,'tools')
from lib import *
pos={p['node']:p for p in load('positions')}
km={k['edge']:k['km'] for k in load('km')}
ja={}
for x in load('names'):
    if x['entity_type']=='node' and x['lang']=='ja' and x['id'] not in ja:ja[x['id']]=x['text']
ln={l['id']:l['name_ja'] for l in load('lines')}
def d(a,b):
    p=math.radians((a['lat']+b['lat'])/2)
    return math.hypot((a['lat']-b['lat'])*111.0,(a['lon']-b['lon'])*111.0*math.cos(p))
bad=[];nopos=0
for e in load('edges'):
    a,b=pos.get(e['a']),pos.get(e['b'])
    if not a or not b or a.get('lat') is None or b.get('lat') is None:nopos+=1;continue
    k=km.get(e['id'],0);g=d(a,b)
    if g>k*1.3+2.0:bad.append((round(g-k,1),ln.get(e['seed_line']),ja.get(e['a']),ja.get(e['b']),k,round(g,1),e['a'],e['b']))
bad.sort(reverse=True)
print('edges no position',nopos,'suspect',len(bad))
for x in bad[:int(sys.argv[1]) if len(sys.argv)>1 else 40]:print(x[:6])
os.makedirs('data/candidates',exist_ok=True)
json.dump(bad,open('data/candidates/geo_suspect.json','w',encoding='utf-8'),ensure_ascii=False,indent=0)
nn=collections.Counter()
for n,p in pos.items():
    if p.get('lat') is None:nn['none']+=1
    else:nn[p.get('quality')]+=1
print(nn)
