# -*- coding: utf-8 -*-
# 컴파일된 DB가 명세의 불변식을 지키는지 SQL로 다시 잰다 (HANDOFF §7). 결과는 숫자로만 낸다
# 쓰는 법: python3 -I tools/dev/db_regression.py [build 폴더]. 실패 항목이 있으면 0이 아닌 값으로 끝난다
import sys,os,json,re,sqlite3,collections
B=sys.argv[1] if len(sys.argv)>1 else os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','..','build')
db=sqlite3.connect(os.path.join(B,'master.sqlite'))
db.execute(f"ATTACH '{os.path.join(B,'names.sqlite')}' AS nm")
rep=json.load(open(os.path.join(B,'report.json'),encoding='utf-8'))
TODAY=rep['today']
R=[]
def q(s,*a):return db.execute(s,a).fetchall()
def one(s,*a):return db.execute(s,a).fetchone()[0]
def add(k,what,got,ok,note=''):R.append(dict(k=k,what=what,got=got,ok=bool(ok),note=note))
EDTF=re.compile(r'^(\d{4}-\d\d-\d\d|\d{4}-\d\d-XX|\d{4}-XX-XX|\d{3}X-XX-XX|ongoing)$')

# 1. 분모 합 = km 합
for b,c in (('alltime','on'),('alltime','off'),('current','on')):
    t=q("SELECT km,unit_count FROM denominator WHERE scope='all' AND basis=? AND carryover=?",b,c)[0]
    if b=='alltime':
        s=q("SELECT round(sum(km),1),count(*) FROM denominator_unit WHERE class='normal' AND carryover=?",c)[0]
    else:
        s=q("SELECT round(sum(km),1),count(*) FROM denominator_unit WHERE class='normal' AND carryover=? AND (date_lo IS NULL OR date_lo<=?) AND ?<coalesce(date_hi,'9999-12-31')",c,TODAY,TODAY)[0]
    add(f'D-{b}-{c}',f'{b}/{c} 분모 표 = 단위 합',f'표 {t[0]}km {t[1]} / 단위 {s[0]}km {s[1]}',abs(t[0]-s[0])<0.05 and t[1]==s[1])
km_edge=one("SELECT round(sum(k.km),1) FROM edge_km k")
km_unit=one("SELECT round(sum(km),1) FROM (SELECT DISTINCT edge_id,km FROM denominator_unit WHERE carryover='on')")
add('D-edges','모든 edge km = 단위가 덮는 edge km',f'{km_edge} / {km_unit}',km_edge==km_unit)
bad=one("SELECT count(*) FROM edge_km WHERE km IS NULL OR km<0 OR m IS NULL OR m<>round(km*1000)")
add('D-km','edge_km이 있고 m이 km×1000',bad,bad==0)
# 0km 구간은 営業キロ도 좌표도 모르는 역을 다음 km를 아는 역 자리에 둔 것뿐이어야 한다 (§4.5, gen_n05 estimate_km)
zero=q("SELECT k.edge_id FROM edge_km k JOIN edge e ON e.id=k.edge_id WHERE k.km=0 AND NOT EXISTS (SELECT 1 FROM route_stop s WHERE s.node_id IN (e.from_node,e.to_node) AND s.km_estimated=1)")
add('D-zero','0km 구간은 km 추정 역에 닿음',f'0km {one("SELECT count(*) FROM edge_km WHERE km=0")}, 추정 역 아님 {len(zero)}',not zero)
pref=one("SELECT count(*) FROM (SELECT p.edge_id FROM edge_pref p JOIN edge_km k USING(edge_id) GROUP BY p.edge_id HAVING abs(sum(p.km)-max(k.km))>0.05)")
add('D-pref','도도부현별 km 합 = edge km',pref,pref==0)
apx=q("SELECT count(DISTINCT edge_id) FROM edge_pref WHERE approx=1")[0][0]
add('D-pref-approx','경계 구간 중 선형이 없어 반씩 나눈 근사 (§2.8 K)',apx,True,'정보')

# 2. 이름
for et,tbl in (('node','node_public'),('line','line'),('operator','operator')):
    for lang in ('ja','ko','en'):
        miss=one(f"SELECT count(*) FROM {tbl} t WHERE NOT EXISTS (SELECT 1 FROM nm.name n WHERE n.entity_type=? AND n.entity_id=t.id AND n.lang=? AND n.line_id IS NULL AND coalesce(n.text,'')<>'')",et,lang)
        add(f'N-{et}-{lang}',f'공개 {et}의 기본 {lang} 이름',f'빠짐 {miss}',miss==0)
miss=one("SELECT count(*) FROM route r WHERE NOT EXISTS (SELECT 1 FROM nm.name n WHERE n.entity_type='route' AND n.entity_id=r.id AND n.lang='ko')")
add('N-route-ko','계통의 한국어 이름',f'빠짐 {miss} (계통 칩은 본선이면 `본선`)',True,'정보')
src=dict(q("SELECT coalesce(source,'NULL'),count(*) FROM nm.name WHERE lang='ko' GROUP BY 1"))
add('N-src','한국어 이름 출처 태그',src,'NULL' not in src)
jp=one("SELECT count(*) FROM nm.name WHERE lang='ko' AND entity_type IN ('node','line','operator') AND text GLOB '*[ぁ-ゖァ-ヺ一-龯]*'")
add('N-kana-in-ko','한국어 이름에 일본어 글자',jp,jp==0)
nokana=q("SELECT entity_id FROM nm.name WHERE entity_type='node' AND lang='ja' AND line_id IS NULL AND valid_from IS NULL AND valid_to IS NULL AND coalesce(kana,'')='' AND entity_id IN (SELECT id FROM node_public)")
add('N-kana','공개 역의 기본 이름에 읽기(가나)',f'빠짐 {len(nokana)} {[x[0] for x in nokana[:6]]}',not nokana)
sh=q("SELECT text,count(DISTINCT kana) FROM nm.name WHERE lang='ko' AND entity_type='node' AND source='namuwiki' AND line_id IS NULL GROUP BY text HAVING count(DISTINCT kana)>1")
add('N-share','읽기가 다른 역이 한 나무위키 제목을 나눠 씀',len(sh),True,'정보. 같은 제목의 다른 지방 역이 있으면 정상일 수 있음')

# 3. 선형
cur=q("SELECT DISTINCT a.edge_id FROM edge_attr a JOIN edge e ON e.id=a.edge_id WHERE e.geometry_quality<>'precise' AND (a.valid_from_lo IS NULL OR a.valid_from_lo<=?) AND ?<a.valid_to_hi",TODAY,TODAY)
add('G-current','현행 edge에 선형',f'없음 {len(cur)}',not cur)
cs=q("SELECT map_visible,count(*),round(sum(km),1) FROM closed_section GROUP BY 1")
mk=one("SELECT count(*) FROM map_marker")
inv=one("SELECT count(*) FROM closed_section WHERE map_visible=0")
add('G-closed','폐지 구간 선형 (map_visible) / 위치 미확인 표식',f'{cs} / 표식 {mk}',True,'정보. 선형이 없는 폐지 구간은 표식으로 (§7.3)')
nsrc=one("SELECT count(*) FROM edge WHERE (geometry_quality='precise')<>(geometry_source IS NOT NULL)")
add('G-src','geometry_quality와 geometry_source가 맞음',nsrc,nsrc==0)

# 4. 날짜 형식
bad=[]
for t,cols in (('edge_life',('valid_from','valid_to','last_service','legal_abolition')),('edge_attr',('valid_from','valid_to')),('route_stop',('valid_from','valid_to')),('archive_stop',('opened','closed')),('archive_line',('opened','closed'))):
    for c in cols:
        for (v,) in q(f"SELECT DISTINCT {c} FROM {t} WHERE {c} IS NOT NULL"):
            if not EDTF.match(v):bad.append((t,c,v))
add('T-edtf','모든 날짜가 EDTF (§5.4)',f'어긋남 {len(bad)} {bad[:5]}',not bad)
nul=q("SELECT a.edge_id,a.line_id FROM edge_attr a WHERE a.valid_from IS NULL")
add('T-open-null','개업일 NULL 집계 행 (연도 분모에서 판정 불가)',f'{len(nul)} {sorted({l for _,l in nul})}',True,'정보')
neg=one("SELECT count(*) FROM edge_attr WHERE valid_from_lo IS NOT NULL AND valid_to_lo IS NOT NULL AND valid_from_lo>valid_to_hi")
add('T-order','기간의 시작이 끝보다 늦지 않음 (edge_attr)',neg,neg==0)
neg=one("SELECT count(*) FROM route_stop WHERE is_stop=1 AND valid_from_lo IS NOT NULL AND valid_to_lo IS NOT NULL AND valid_from_lo>=valid_to_hi")
add('T-order-stop','정차 기간의 시작이 끝보다 늦지 않음',neg,neg==0)

# 5. 기간 겹침
ov=0
rows=collections.defaultdict(list)
for e,l,f,t in q("SELECT edge_id,line_id,valid_from_lo,valid_to_lo FROM edge_attr"):rows[(e,l)].append((f or '0000',t or '9999'))
for v in rows.values():
    v.sort()
    for a,b in zip(v,v[1:]):
        if a[1]>b[0]:ov+=1
add('T-overlap-attr','(노선, edge) 집계 행 기간 겹침',ov,ov==0)
ov=0
rows=collections.defaultdict(list)
for e,f,t in q("SELECT edge_id,valid_from_lo,valid_to_lo FROM edge_life"):rows[e].append((f or '0000',t or '9999'))
for v in rows.values():
    v.sort()
    for a,b in zip(v,v[1:]):
        if a[1]>b[0]:ov+=1
add('T-overlap-life','edge_life 기간 겹침',ov,ov==0)

# 6. 승계 단위
n=one("SELECT count(*) FROM edge_attr WHERE lineage_id IS NULL OR lineage_id='' OR carryover_group IS NULL OR carryover_group=''")
add('U-lineage','lineage_id·carryover_group이 채워짐',n,n==0)
n=one("SELECT count(*) FROM edge_attr a WHERE NOT EXISTS (SELECT 1 FROM denominator_unit u WHERE u.edge_id=a.edge_id AND u.unit_key=a.lineage_id||':'||a.edge_id AND u.carryover='on')")
add('U-unit','모든 집계 행에 승계 켬 단위',n,n==0)
# 7. 등급
cls=dict(q("SELECT denominator_class,count(*) FROM edge_attr GROUP BY 1"))
add('C-outside','outside 행 0 (§2.8 O)',cls,cls.get('outside',0)==0)
noattr=one("SELECT count(*) FROM edge e WHERE NOT EXISTS (SELECT 1 FROM edge_attr a WHERE a.edge_id=e.id)")
add('C-edge-attr','모든 edge에 집계 행',noattr,noattr==0)

# 8. 노면전차·무궤조
ty=dict(q("SELECT type,count(*) FROM line GROUP BY 1"))
tro=sorted({t for (t,) in q("SELECT n.text FROM line l JOIN edge_attr a ON a.line_id=l.id JOIN nm.name n ON n.entity_type='operator' AND n.entity_id=a.operator_id AND n.lang='ja' AND n.line_id IS NULL WHERE l.type='trolley'")})
add('L-trolley','무궤조전차는 立山·関電 터널 둘뿐 (§4.4)',f'노선 {ty.get("trolley",0)}, 사업자 {tro}',ty.get('trolley',0)==2 and tro==['立山黒部貫光','関西電力'])
sys_=[t for (t,) in q("SELECT n.text FROM line l JOIN nm.name n ON n.entity_type='line' AND n.entity_id=l.id AND n.lang='ja' AND n.line_id IS NULL WHERE l.type='tram' AND n.text GLOB '*系統*'")]
add('L-tram','노면전차 노선이 공식 궤도선 단위 (계통 이름 아님)',f'노면전차 {ty.get("tram",0)}, 계통 이름 {sys_}',not sys_)
add('L-types','노선 종류',ty,True,'정보')

# 9. 계통과 역
r1=q("SELECT l.id FROM line l WHERE NOT EXISTS (SELECT 1 FROM route r WHERE r.line_id=l.id)")
add('R-line','모든 노선에 계통',len(r1),not r1)
r2=q("SELECT route_id FROM route_stop GROUP BY route_id HAVING count(*)<2")
add('R-stops','모든 계통에 역 둘 이상',len(r2),not r2)
mono=0
prev={}
for r,s,k in q("SELECT route_id,seq,km_cum FROM route_stop WHERE km_cum IS NOT NULL ORDER BY route_id,seq"):
    if r in prev and k+1e-9<prev[r]:mono+=1
    prev[r]=k
add('R-km','계통 누계 km가 순번대로 줄지 않음',mono,mono==0)
hid=one("SELECT count(*) FROM route_stop s WHERE s.is_stop=1 AND s.node_id NOT IN (SELECT id FROM node_public)")
add('R-public','정차역이 모두 공개 노드',hid,hid==0)
est=one("SELECT count(*) FROM route_stop WHERE km_estimated=1")
estn=one("SELECT count(DISTINCT route_id) FROM route_stop WHERE km_estimated=1")
add('R-est','km 추정 역 (? km, §4.5)',f'{est}행, 계통 {estn}',True,'정보')
nopos=one("SELECT count(*) FROM node_public p WHERE NOT EXISTS (SELECT 1 FROM node_position x WHERE x.node_id=p.id AND x.lat IS NOT NULL)")
qual=dict(q("SELECT quality,count(*) FROM node_position WHERE node_id IN (SELECT id FROM node_public) GROUP BY 1"))
add('P-pos','공개 역 좌표',f'좌표 없음 {nopos}, 품질 {qual}',True,'정보')
cov=dict(q("SELECT grade,count(*) FROM coverage GROUP BY 1"))
add('V-grade','노선 수록 등급 (§4.1)',cov,True,'정보')
arc=(one("SELECT count(*) FROM archive_line"),one("SELECT count(*) FROM archive_stop"))
add('V-archive','열람 전용 노선·역',arc,True,'정보')
xf=one("SELECT count(*) FROM route_link WHERE kind='transfer'")
add('K-links','표시 링크',dict(q("SELECT kind,count(*) FROM route_link GROUP BY 1")),True,'정보')

# 8. 누락·중복·잘못된 값 (2026-11-06)
def ov(a0,a1,b0,b1):
    """기간 겹침. 끝은 첫 무효일"""
    return (a0 or '0000')<(b1 or '9999-12-31') and (b0 or '0000')<(a1 or '9999-12-31')
loops={r for r, in q("SELECT id FROM route WHERE closed=1")}
by=collections.defaultdict(list)
for r,s,n,f,t in q("SELECT route_id,seq,node_id,valid_from_lo,valid_to_hi FROM route_stop WHERE is_stop=1"):by[(r,n)].append((s,f,t))
dup=[(r,n) for (r,n),v in by.items() if len(v)>1 and any(ov(a[1],a[2],b[1],b[2]) for i,a in enumerate(v) for b in v[i+1:]) and not (r in loops and len(v)==2)]
add('X-dup-stop','한 계통에 같은 역이 같은 기간 두 번 정차 (닫힌 계통의 처음·끝 제외)',f'{len(dup)} {dup[:5]}',not dup)
ja={i:t for i,t in q("SELECT entity_id,text FROM nm.name WHERE entity_type='node' AND lang='ja' AND line_id IS NULL AND valid_from IS NULL")}
pos={i:(a,b) for i,a,b in q("SELECT node_id,lat,lon FROM node_position WHERE lat IS NOT NULL")}
ln=collections.defaultdict(list)
for l,n,f,t in q("SELECT r.line_id,s.node_id,s.valid_from_lo,s.valid_to_hi FROM route_stop s JOIN route r ON r.id=s.route_id WHERE s.is_stop=1"):ln[(l,ja.get(n))].append((n,f,t))
moved={(m['old'],m['new']) for m in json.load(open(os.path.join(os.path.dirname(B),'data','overrides','moved.json'),encoding='utf-8'))} if os.path.exists(os.path.join(os.path.dirname(B),'data','overrides','moved.json')) else set()
twin=sorted({(l,nm_,a[0],b[0]) for (l,nm_),v in ln.items() if nm_ for i,a in enumerate(v) for b in v[i+1:] if a[0]!=b[0] and ov(a[1],a[2],b[1],b[2]) and (a[0],b[0]) not in moved and (b[0],a[0]) not in moved})
add('X-twin-node','같은 노선에서 같은 이름의 다른 노드가 같은 기간 정차 (moved.json 밖)',f'{len(twin)} {twin[:6]}',True,'정보. 옛 역·새 역이면 moved.json, 같은 역이면 합침')
ed={i:(a,b) for i,a,b in q("SELECT id,from_node,to_node FROM edge")}
pe=collections.defaultdict(list)
for e,l,f,t in q("SELECT edge_id,line_id,valid_from_lo,valid_to_hi FROM edge_attr"):pe[(l,frozenset(ed[e]))].append((e,f,t))
dupe=sorted({(l,a[0],b[0]) for (l,k),v in pe.items() for i,a in enumerate(v) for b in v[i+1:] if a[0]!=b[0] and ov(a[1],a[2],b[1],b[2])})
add('X-dup-edge','같은 노선의 같은 두 역 사이 edge가 같은 기간 둘 (옛·새 선로 병행 포함)',f'{len(dupe)} {dupe[:6]}',True,'정보. 이설 전후가 겹치면 기간 오류')
life=collections.defaultdict(list)
for e,f,t,st in q("SELECT edge_id,valid_from_lo,valid_to_lo,status FROM edge_life ORDER BY edge_id,valid_from_lo"):life[e].append((f,t,st))
same=[e for e,v in life.items() if any(a[2]==b[2] and a[1]==b[0] for a,b in zip(v,v[1:]))]
add('X-life-run','edge_life에서 상태가 같은 기간이 이어져 나뉨',f'{len(same)} {same[:6]}',not same)
gap=[e for e,v in life.items() if any((a[1] or '')<(b[0] or '') for a,b in zip(v,v[1:]) if a[1] and a[1]!='ongoing')]
add('X-life-gap','edge_life 기간 사이 빈틈',f'{len(gap)} {gap[:6]}',True,'정보. 개업 전·폐지 후가 아닌 빈틈은 원인 확인')
nd=one("SELECT count(*) FROM (SELECT entity_type,entity_id,lang FROM nm.name WHERE line_id IS NULL AND valid_from IS NULL AND valid_to IS NULL GROUP BY 1,2,3 HAVING count(*)>1)")
add('X-name-dup','같은 실체·언어에 기본 이름이 둘 이상',nd,nd==0)
orph=one("SELECT count(*) FROM node n WHERE NOT EXISTS (SELECT 1 FROM route_stop s WHERE s.node_id=n.id) AND NOT EXISTS (SELECT 1 FROM edge e WHERE e.from_node=n.id OR e.to_node=n.id)")
add('X-orphan-node','어느 계통·edge에도 없는 노드',orph,orph==0)
noat=one("SELECT count(*) FROM archive_line WHERE at_node IS NULL")
add('X-archive-at','열람 전용 노선 중 붙을 역(at_node)이 없는 줄',noat,True,'정보. 어느 화면에도 안 붙음 (docs/TODO.md)')
bad_as=one("SELECT count(*) FROM archive_stop a WHERE (a.after_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM route_stop s WHERE s.route_id=a.route_id AND s.node_id=a.after_id)) OR (a.before_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM route_stop s WHERE s.route_id=a.route_id AND s.node_id=a.before_id))")
add('X-archive-stop','열람 전용 역의 앞뒤 역이 그 계통에 없음',bad_as,bad_as==0)
farkm=[(e,round(k,1)) for e,k in q("SELECT edge_id,km FROM edge_km WHERE km>60 OR km<0")]
add('X-km-range','edge km가 0 미만이거나 60 넘음',f'{len(farkm)} {farkm[:6]}',True,'정보. 긴 칸은 원문 확인')

fails=[r for r in R if not r['ok']]
for r in R:
    print(('통과 ' if r['ok'] else '실패 ')+r['k'].ljust(16),r['what'],'|',r['got'],('· '+r['note']) if r['note'] else '')
print(f'항목 {len(R)}, 실패 {len(fails)}')
json.dump(R,open(os.path.join(B,'db_regression.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=1,default=str)
sys.exit(1 if fails else 0)
