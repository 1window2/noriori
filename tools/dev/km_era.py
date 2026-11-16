# -*- coding: utf-8 -*-
# 국철·JR 시대 営業キロ가 3섹 전환 때 다시 정해진 구간의 옛 km (DESIGN §2.9 E, 사용자 결정 2026-11-06).
# 입력: docs/research/km-jnr-3sec-2026-11-06.json(노리츠부시 국철 표와 DB의 역별 차, 원인 조사)과 build/master.sqlite.
# 원인이 remeasure(역·선로 그대로 km만 바뀜)인 역만 쓴다. 이설·이전(realign, move)은 노드와 선로를 나눠 고친다.
# 결과: data/overrides/km_era.json. 정차역 두 곳 사이 국철 시대 km이고, 컴파일이 사이 edge에 지금 km 비율로 나눈다
#   python3 -I tools/dev/km_era.py [--write]
import json,os,re,sys,sqlite3,collections,unicodedata
ROOT=os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','..')
R=json.load(open(os.path.join(ROOT,'docs','research','km-jnr-3sec-2026-11-06.json'),encoding='utf-8'))
db=sqlite3.connect(os.path.join(ROOT,'build','master.sqlite'))
line_of=dict(db.execute('select id,line_id from route'))
by=collections.defaultdict(list)
for x in R:by[(x['table_title'],x['route_id'])].append(x)
nm=sqlite3.connect(os.path.join(ROOT,'build','names.sqlite'))
def norm(t):return re.sub(r'[（(].*?[)）]','',unicodedata.normalize('NFKC',t)).replace('ヶ','ケ').strip()
NAMES=collections.defaultdict(set)
for i,t in list(nm.execute("select entity_id,text from name where entity_type='node' and lang='ja'"))+list(nm.execute("select entity_id,text from alias where entity_type='node'")):NAMES[i].add(norm(t))
ONE={'牟岐線 阿波海南 ～ 海部 営業km: 1.5':1}   # 阿波海南 77.8 → 海部 79.2, 표와 같은 방향
out=[];bad=[]
for (title,rid),xs in sorted(by.items()):
    stops=[dict(seq=s,node=n,km=k) for s,n,k in db.execute('select seq,node_id,km_cum from route_stop where route_id=? and is_stop=1 and is_extension=0 order by seq',(rid,))]
    pos={s['node']:s for s in stops}
    xs=[x for x in xs if x['node_id'] in pos]
    if not xs:bad.append((title,rid,'역 없음'));continue
    # 표 방향: DB km와 노리츠부시 km가 같은 쪽으로 늘면 +1
    sg=None
    if len(xs)>=2:
        a,b=xs[0],xs[-1]
        sg=1 if (b['km_db']-a['km_db'])*(pos[b['node_id']]['km']-pos[a['node_id']]['km'])>=0 else -1
    else:
        # 역 하나만 다른 표는 표 첫 역이 0이라 DB km와 바로 비교하지 못한다. 손으로 본 방향을 쓴다
        x=xs[0];sg=1 if abs(x['km_db']-pos[x['node_id']]['km'])<.05 else ONE.get(title)
    if sg is None:bad.append((title,rid,'방향 모름'));continue
    d={x['node_id']:x['km_db']-x['km_noritsubushi'] for x in xs if x['cause']=='remeasure'}
    skip={x['node_id'] for x in xs if x['cause']!='remeasure'}
    # 그 표의 구간은 제목의 양 끝 역 사이다 (「信越本線 横川 ～ 篠ノ井 営業km」). 끝 역은 이름이나 별칭으로 찾는다
    m=re.match(r'^\S+ (.+?) ～ (.+?) 営業km',title)
    ends=[[i for i,s_ in enumerate(stops) if norm(e) in NAMES.get(s_['node'],set())] for e in (m.groups() if m else ())]
    if len(ends)!=2 or not all(ends):bad.append((title,rid,'끝 역 없음'));continue
    i0,i1=sorted((ends[0][0],ends[1][-1]))
    for u,v in zip(stops[i0:i1],stops[i0+1:i1+1]):
        if u['node'] in skip or v['node'] in skip:continue
        seg=round(v['km']-u['km'],1)
        era=round(abs(sg*seg-(d.get(v['node'],0)-d.get(u['node'],0))),1)
        if abs(era-abs(seg))>=.05:out.append(dict(line=line_of[rid],route=rid,a=u['node'],b=v['node'],km=era,km_now=abs(seg),table=title))
# 노리츠부시 국철 표와 대조 표에 없는 구간을 구선로 보정에서 손으로 확인한 것 (docs/research/realign-patches-2026-11-06.md)
HAND=json.load(open(os.path.join(ROOT,'data','overrides','km_era_hand.json'),encoding='utf-8')) if os.path.exists(os.path.join(ROOT,'data','overrides','km_era_hand.json')) else []
out+=[x for x in HAND if x not in out]
print('구간',len(out),'노선',len({x['line'] for x in out}),'못 쓴 표',bad)
if '--write' in sys.argv:
    json.dump(out,open(os.path.join(ROOT,'data','overrides','km_era.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=0)
    open(os.path.join(ROOT,'data','overrides','km_era.json'),'a',encoding='utf-8').write('\n')
