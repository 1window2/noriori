# -*- coding: utf-8 -*-
# 사용: python3 -I tools/n05_reloc_cand.py list | <번호>   (프로젝트 루트에서)
# 후보: N05에서 1950년 이후 폐지된 선로 가운데 DB 선형에서 1km 넘게 이어서 떨어진 토막
import sys,json,math,sqlite3,zipfile,collections
C=json.load(open('data/candidates/reloc_cand.json',encoding='utf-8'))
def km(a,b):
    q=math.radians((a[1]+b[1])/2);return math.hypot((a[1]-b[1])*111.2,(a[0]-b[0])*111.2*math.cos(q))
if sys.argv[1]=='list':
    for i,r in enumerate(C):print(i,r['closed_after'],r['op'],r['line'],r['km'],'km',r['stations'][:6])
    sys.exit()
r=C[int(sys.argv[1])];print(json.dumps(r,ensure_ascii=False))
m=sqlite3.connect('build/master.sqlite');n=sqlite3.connect('build/names.sqlite')
ja={i:t for i,t in n.execute("select entity_id,text from name where lang='ja' and line_id is null and valid_from is null")}
pos=[(i,a,b) for i,a,b in m.execute('select node_id,lon,lat from node_position where lon is not null')]
rl=collections.defaultdict(set)
for nd,l in m.execute('select distinct s.node_id,r.line_id from route_stop s join route r on r.id=s.route_id'):rl[nd].add(l)
for tag,pt in (('시작',r['start']),('끝',r['end'])):
    near=sorted((km(pt,(a,b)),i) for i,a,b in pos if abs(a-pt[0])<.03 and abs(b-pt[1])<.03)[:6]
    print(tag,pt,[(ja.get(i,i),round(d,2),sorted(ja.get(l,l) for l in rl[i])[:3]) for d,i in near])
z=zipfile.ZipFile('data/imports/n05/N05-24_GML.zip')
print('N05 역 (이름, 처음 해, 마지막 해, 경도·위도)')
for f in json.loads(z.read('UTF-8/N05-24_Station2.geojson'))['features']:
    p=f['properties']
    if p['N05_002']==r['line'] and p['N05_003']==r['op']:
        c=f['geometry']['coordinates'];g=f['geometry']['type']
        c=c[len(c)//2] if g=='LineString' else (c if g=='Point' else c[0][len(c[0])//2])
        if min(km(c,r['start']),km(c,r['end']))<r['km']+2 or p['N05_011'] in r['stations']:print('  ',p['N05_011'],p['N05_005b'],p['N05_005e'],[round(c[0],5),round(c[1],5)])
