# -*- coding: utf-8 -*-
# 배경 지도에서 일본의 실효 지배 밖인 섬을 뺀다 (사용자 결정 2026-11-07).
# N03 행정구역은 일본 측 행정구역이라 러시아가 관할하는 北方領土(国後·択捉·色丹·歯舞群島)와 竹島(독도)를 땅으로 넣는다.
# 철도 데이터에는 이 지역의 역·선로가 없다. 배경의 땅·경계·도도부현 면만 고친다.
#   python3 -I tools/base_exclude.py           data/base의 land·border·pref.geojson에서 뺀다 (gen_base.sh 뒤)
#   python3 -I tools/base_exclude.py --check   남은 조각이 있으면 멈춘다 (gen_tiles)
import json,os,sys
ROOT=os.path.join(os.path.dirname(os.path.abspath(__file__)),'..')
BASE=os.path.join(ROOT,'data','base')
FILES=('land.geojson','border.geojson','pref.geojson')

# 조각의 경계 상자(서·남·동·북)가 이 안에 들면 뺀다.
# 根室 해협 건너편: 野付·知床 쪽 일본 관할 섬은 북위 43.6도 아래이거나 동경 145.35도 서쪽이다.
# 珸瑶瑁 수도 건너편(歯舞群島): 納沙布岬(145.817E) 동쪽. 根室 반도 남쪽의 ユルリ島·モユルリ島는 북위 43.3도 아래다
AREAS=[
    ('北方領土 国後·択捉·色丹', 145.35, 43.6, 149.5, 46.0),
    ('北方領土 歯舞群島', 145.83, 43.35, 146.5, 43.7),
    ('竹島', 131.8, 37.2, 131.95, 37.3),
]

def _bbox(coords):
    xs=[];ys=[]
    def walk(c):
        if isinstance(c[0],(int,float)):xs.append(c[0]);ys.append(c[1])
        else:
            for x in c:walk(x)
    walk(coords)
    return min(xs),min(ys),max(xs),max(ys)

def area_of(coords):
    x0,y0,x1,y1=_bbox(coords)
    for name,a,b,c,d in AREAS:
        if x0>=a and y0>=b and x1<=c and y1<=d:return name
    return None

def clean(geo):
    """뺀 조각 수를 돌려준다. 다각형은 조각(외곽 링 단위), 선은 선 단위로 본다"""
    out=[];gone=0
    for ft in geo['features']:
        g=ft['geometry']
        if g is None:out.append(ft);continue
        t=g['type']
        if t in('Polygon','LineString'):
            if area_of(g['coordinates']):gone+=1;continue
            out.append(ft);continue
        if t in('MultiPolygon','MultiLineString'):
            keep=[p for p in g['coordinates'] if not area_of(p)]
            gone+=len(g['coordinates'])-len(keep)
            if not keep:continue
            g['coordinates']=keep
            if len(keep)==1:g['type']=t[5:];g['coordinates']=keep[0]
        out.append(ft)
    geo['features']=out
    return gone

def left(path):
    geo=json.load(open(path,encoding='utf-8'))
    n=0
    for ft in geo['features']:
        g=ft['geometry']
        if not g:continue
        parts=g['coordinates'] if g['type'].startswith('Multi') else [g['coordinates']]
        n+=sum(1 for p in parts if area_of(p))
    return n

if __name__=='__main__':
    if '--check' in sys.argv:
        bad={f:left(os.path.join(BASE,f)) for f in FILES}
        if any(bad.values()):raise SystemExit(f'배경 지도에 뺄 섬이 남았습니다 {bad}. python3 -I tools/base_exclude.py를 돌리세요')
        print('배경 제외 영역 비어 있음');sys.exit(0)
    for f in FILES:
        p=os.path.join(BASE,f);geo=json.load(open(p,encoding='utf-8'))
        n=clean(geo)
        # mapshaper처럼 한 줄에 한 feature로 쓴다
        if n:open(p,'w',encoding='utf-8').write('{"type":"FeatureCollection", "features": [\n'+',\n'.join(json.dumps(ft,ensure_ascii=False,separators=(',',':')) for ft in geo['features'])+']}\n')
        print(f,'뺀 조각',n)
