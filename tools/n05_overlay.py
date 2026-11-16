# -*- coding: utf-8 -*-
# N05 선로 위 두 점 사이 거리 (DESIGN §2.12 「N05 겹침 추정」). 営業キロ가 없는 역의 km와 좌표를 거꾸로 계산할 때 쓴다
#   python3 -I tools/n05_overlay.py <N05 노선> <N05 사업자> <역 A> <역 B> [<해>]
#   역은 N05 역 이름 또는 "위도,경도". 해를 주면 그해 기록만 쓴다
# N05 선을 이어 그래프로 만들고 두 점을 가장 가까운 선 위 점에 붙여 최단 경로 길이를 잰다. 결과는 km(소수 1자리)와 붙인 거리
import sys,os,json,math,zipfile,heapq,collections
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from lib import IMP
def km(a,b):
    q=math.radians((a[1]+b[1])/2);return math.hypot((a[1]-b[1])*111.2,(a[0]-b[0])*111.2*math.cos(q))
def load(line,op,year=None):
    z=zipfile.ZipFile(os.path.join(IMP,'n05','N05-24_GML.zip'))
    segs=[];st={}
    for f in json.loads(z.read('UTF-8/N05-24_RailroadSection2.geojson'))['features']:
        p=f['properties']
        if p['N05_002']!=line or p['N05_003']!=op:continue
        if year and not(int(p['N05_005b'] or 0)<=year<=int(p['N05_005e'] or 9999)):continue
        g=f['geometry']
        for l in (g['coordinates'] if g['type']=='MultiLineString' else [g['coordinates']]):segs.append([tuple(round(x,6) for x in c[:2]) for c in l])
    for f in json.loads(z.read('UTF-8/N05-24_Station2.geojson'))['features']:
        p=f['properties']
        if p['N05_002']==line and p['N05_003']==op:
            c=f['geometry']['coordinates'];t=f['geometry']['type']
            st[p['N05_011']]=tuple(c[len(c)//2][:2]) if t=='LineString' else (tuple(c[:2]) if t=='Point' else tuple(c[0][0][:2]))
    return segs,st
def along(segs,a,b):
    """a, b를 선 위 가장 가까운 꼭짓점에 붙이고 최단 경로 길이"""
    G=collections.defaultdict(list)
    # 끝점이 50m 안이면 이어 본다 (기록이 나뉜 곳)
    pts=[p for s in segs for p in s]
    for s in segs:
        for u,v in zip(s,s[1:]):d=km(u,v);G[u].append((v,d));G[v].append((u,d))
    ends=[s[0] for s in segs]+[s[-1] for s in segs]
    for i,u in enumerate(ends):
        for v in ends[i+1:]:
            if u!=v and km(u,v)<.05:G[u].append((v,km(u,v)));G[v].append((u,km(u,v)))
    sa=min(pts,key=lambda p:km(p,a));sb=min(pts,key=lambda p:km(p,b))
    D={sa:0};h=[(0,sa)]
    while h:
        d,u=heapq.heappop(h)
        if u==sb:return round(d,1),round(km(sa,a),3),round(km(sb,b),3)
        if d>D.get(u,1e9):continue
        for v,w in G[u]:
            if d+w<D.get(v,1e9):D[v]=d+w;heapq.heappush(h,(d+w,v))
    return None,round(km(sa,a),3),round(km(sb,b),3)
if __name__=='__main__':
    line,op,A,B=sys.argv[1:5];year=int(sys.argv[5]) if len(sys.argv)>5 else None
    segs,st=load(line,op,year)
    if not segs:raise SystemExit('N05에 그 노선·사업자의 선이 없음')
    def pt(x):
        if ',' in x:la,lo=map(float,x.split(','));return (lo,la)
        if x not in st:raise SystemExit(f'N05 역 {x} 없음. 있는 역: {sorted(st)}')
        return st[x]
    d,ea,eb=along(segs,pt(A),pt(B))
    print(json.dumps(dict(km=d,snap_a_km=ea,snap_b_km=eb,a=pt(A),b=pt(B)),ensure_ascii=False))
