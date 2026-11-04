# -*- coding: utf-8 -*-
# N02 2024판 역 점을 이름별로 뽑는다. 결과: data/imports/n02/stations_2024.json
import sys,os,json,zipfile,collections
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from lib import *
if not source_on('n02_2024'):
    json.dump({},open(os.path.join(IMP,'n02','stations_2024.json'),'w',encoding='utf-8'));print('N02 2024판이 꺼져 있습니다');sys.exit(0)
zz=zipfile.ZipFile(os.path.join(IMP,'n02','N02-24_GML.zip'))
f=[x for x in zz.namelist() if x.endswith('Station.geojson') and 'UTF-8' in x][0]
P=collections.defaultdict(list)
for ft in json.loads(zz.read(f).decode('utf-8'))['features']:
    p=ft['properties'];g=ft['geometry']
    pl=g['coordinates'] if g['type']=='LineString' else [g['coordinates']]
    c=pl[len(pl)//2]
    # 끝의 선분은 역의 승강장이다. 긴 역은 가운데 점만으로 거리를 재면 크게 나온다
    x=[round(c[1],6),round(c[0],6),p['N02_004'],p['N02_003'],[[round(a,6),round(b,6)] for a,b in (q[:2] for q in pl)]]
    if x not in P[znorm(p['N02_005'])]:P[znorm(p['N02_005'])].append(x)
json.dump(P,open(os.path.join(IMP,'n02','stations_2024.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=0)
print('N02 역',len(P))
