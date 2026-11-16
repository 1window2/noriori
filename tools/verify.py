# -*- coding: utf-8 -*-
# 완성된 DB를 독립 자료와 대조한다. 결과는 build/verify.json
import sys,os,json,csv,sqlite3,collections,re,glob
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from lib import *
m=sqlite3.connect(os.path.join(BUILD,'master.sqlite'));n=sqlite3.connect(os.path.join(BUILD,'names.sqlite'))
R={}
ja=collections.defaultdict(list)
for i,t in n.execute("select entity_id,text from name where entity_type='node' and lang='ja'"):ja[i].append(t)
ko={i:t for i,t in n.execute("select entity_id,text from name where entity_type='node' and lang='ko'")}
# 1. 현행 역 이름 대조. 원천 스냅샷이 없는 체크아웃에서는 건너뛴다
DB=os.path.join(IMP,'stationdb','station.csv')
if os.path.exists(DB):
    SD=list(csv.DictReader(open(DB,encoding='utf-8')))
    cur=set()
    for nid,in m.execute("select distinct node_id from route_stop where is_stop=1 and valid_to='ongoing'"):
        for t in ja[nid]:cur.add(znorm(t))
    sdcur={znorm(s['name']) for s in SD if s['closed']=='0'}
    sdcl={znorm(s['name']) for s in SD if s['closed']=='1'}
    R['현행 역 이름']=dict(db=len(cur),sd=len(sdcur),both=len(cur&sdcur),db_only=sorted(cur-sdcur)[:60],sd_only=sorted(sdcur-cur)[:60],sd_only_n=len(sdcur-cur),db_only_n=len(cur-sdcur))
    allnm=set()
    for v in ja.values():
        for t in v:allnm.add(znorm(t))
    R['옛 역 이름']=dict(sd_closed=len(sdcl),in_db=len(sdcl&allnm),missing_sample=sorted(sdcl-allnm)[:60],missing=len(sdcl-allnm))
else:print('data/imports가 없어 station_database 이름 대조를 건너뜁니다')
# 2. 날짜
early=m.execute("select count(*) from edge_life where valid_to_lo<'1950-01-01' and valid_to<>'ongoing'").fetchone()[0]   # 기준일 (DESIGN §4.6)
R['기준일 이전 폐지 edge']=early
R['날짜 없는 개업 edge']=m.execute("select count(*) from edge_attr where valid_from is null").fetchone()[0]
R['날짜 없는 폐역']=m.execute("select count(*) from route_stop where is_stop=1 and valid_to is null").fetchone()[0]
R['폐역']=m.execute("select count(*) from route_stop where is_stop=1 and valid_to<>'ongoing'").fetchone()[0]
# 3. 공개 노드에 숨은 종류가 없는지
R['공개 노드 중 비여객']=m.execute("select count(*) from node_public where kind<>'station'").fetchone()[0]
# 4. 거리
R['연도별 분모']={a:b for a,b in m.execute("select basis,km from denominator where scope='all' and carryover='on' and basis in('current','alltime','1950','1960','1970','1980','1987','2000','2010','2020')")}
R['승계 끔 역대']=m.execute("select km from denominator where scope='all' and carryover='off' and basis='alltime'").fetchone()[0]
# 5. 이관
R['이관 묶음']=m.execute("select count(distinct lineage_id) from edge_attr").fetchone()[0]
# 6. 위치
R['위치']={a:b for a,b in m.execute("select quality,count(*) from node_position group by 1")}
R['선형 있는 edge']=m.execute("select geometry_quality,geometry_source,count(*) from edge group by 1,2").fetchall()
R['표시']={a:b for a,b in m.execute("select kind,count(*) from route_link group by 1")}
R['등급']={a:b for a,b in m.execute("select grade,count(*) from coverage group by 1")}
R['이름 출처']={a:b for a,b in n.execute("select source,count(*) from name where entity_type='node' and lang='ko' group by 1")}
R['노선 이름 출처']={a:b for a,b in n.execute("select source,count(*) from name where entity_type='line' and lang='ko' group by 1")}
# 7. 위키 노선도 km와 비교 (같은 노선, 역 간격 기준)
_w=os.path.join(CAND,'wiki_km.json')
if os.path.exists(_w):
    W=json.load(open(_w,encoding='utf-8'))
    stops=collections.defaultdict(dict)
    for r,nd,k in m.execute("select s.route_id,s.node_id,s.km_cum from route_stop s where s.is_extension=0"):stops[r][nd]=k
    rts=collections.defaultdict(list)
    for i,l in m.execute('select id,line_id from route'):rts[l].append(i)
    bad=[];ok=tot=0
    lname={i:t for i,t in n.execute("select entity_id,text from name where entity_type='line' and lang='ja'")}
    for l,rows in W.items():
        for a,b in zip(rows,rows[1:]):
            dw=abs(b[1]-a[1])
            for r in rts[l]:
                if a[0] in stops[r] and b[0] in stops[r]:
                    dn=abs(stops[r][b[0]]-stops[r][a[0]]);tot+=1
                    if abs(dw-dn)<=.25:ok+=1
                    else:bad.append((round(abs(dw-dn),1),lname.get(l),(ja.get(a[0]) or [a[0]])[0],(ja.get(b[0]) or [b[0]])[0],dn,round(dw,1)))
                    break
    bad.sort(reverse=True)
    R['위키 km 대조']=dict(pairs=tot,ok=ok,rate=round(ok/max(tot,1),4),worst=bad[:30])
    json.dump(bad,open(os.path.join(CAND,'km_diff.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=0)
else:print('data/candidates가 없어 위키 km 대조를 건너뜁니다')
# ID에는 영어 이름만 쓴다. 원천 사이트의 번호나 해시가 나오면 실패다 (ARCHITECTURE §4.2)
_bad=[i for t in ('node','line','route','operator','hub','archive_stop','archive_line','service') for i, in m.execute(f'select id from {t}') if re.search(r'_\d{3,}(_|$)|_[0-9a-f]{7,8}$|_x[0-9a-f]{8}|^[nlr]_n\d+',i)]
if _bad:raise SystemExit(f'ID에 번호가 있습니다: {_bad[:10]}')
# 꺼진 출처의 값이 남지 않았는지 (data/sources.json, DESIGN §2.10). data/source의 모든 출처 태그를 +로 나눠 본다
# 위치의 n02는 2024판과 2008판(node_fix)이 섞여 판을 가를 수 없어 보지 않는다. 읽는 쪽(n02_stations, gen_source)이 스위치를 본다
TAG={'N02-24':'n02_2024','N02-20':'n02_2020','N02-15':'n02_2015','N02-08':'n02_2008','N02-05':'n02_2005','N05-24':'n05'}
_tags=collections.Counter()
for f in glob.glob(os.path.join(SRC,'**','*.*'),recursive=True):
    for t in re.findall(r'"source": *"([^"]*)"',open(f,encoding='utf-8').read()):_tags[t]+=1
_leak=collections.Counter()
for t,c in _tags.items():
    for part in {re.sub(r':.*$','',x) for x in t.split('+')}:
        k=TAG.get(part,part)
        if k in SOURCES and not SOURCES[k]['on']:_leak[k]+=c
for k in ('namuwiki','wikidata'):
    if not SOURCES[k]['on']:_leak[k]+=n.execute("select count(*) from name where source like ?",(f'%{k}%',)).fetchone()[0]
_leak={k:_leak.get(k,0) for k,v in SOURCES.items() if not v['on']}
R['꺼진 출처']=_leak
if any(_leak.values()):raise SystemExit(f'꺼진 출처의 값이 남았습니다: {_leak}')
json.dump(R,open(os.path.join(BUILD,'verify.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=1)
for k,v in R.items():print(k,str(v)[:420])
