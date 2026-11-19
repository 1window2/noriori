# -*- coding: utf-8 -*-
# 완성된 DB를 원자료와 전수 대조한다. 파이프라인의 판정 코드는 쓰지 않는다(노선도 HTML 해석 tools/wparse.py와 data/source 읽기만 빌린다). 결과: build/audit_ext.json
import sqlite3,json,os,re,math,collections,csv,zipfile,unicodedata
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
B=os.path.join(ROOT,'build')
m=sqlite3.connect(os.path.join(B,'master.sqlite'));n=sqlite3.connect(os.path.join(B,'names.sqlite'))
# 사유를 달고 뺀 열람 전용 ID(archive_lines.json drop·drop_stop·exclude)의 일본어 이름. 컴파일이 그 고아 이름을 DB에 싣지 않게 된 뒤에도
# 감사는 그 행을 「판정된 것」으로 본다(이미 기록 노선·화물역·같은 역·수록 밖). 원천 이름(data/source/names/archive.yaml)에서 읽는다 (12회차 M R6 2026-11-19)
_AF0=json.load(open(os.path.join(ROOT,'data','overrides','archive_lines.json'),encoding='utf-8'))
_DROPPED_IDS=set(_AF0.get('drop',{}))|set(_AF0.get('drop_stop',{}))|set(_AF0.get('exclude',{}))
_DROPPED_JA={}
for _l in open(os.path.join(ROOT,'data','source','names','archive.yaml'),encoding='utf-8'):
    if _l.startswith('- {') and '"lang": "ja"' in _l:
        _x=json.loads(_l[2:])
        if (_x.get('entity_id') or _x.get('id')) in _DROPPED_IDS:_DROPPED_JA.setdefault(_x.get('entity_id') or _x.get('id'),[]).append(_x['text'])
def dropped_ja(ids=None):
    return [t for i,ts in _DROPPED_JA.items() if ids is None or i in ids for t in ts]
m.row_factory=sqlite3.Row
R=collections.OrderedDict()
# 단계: report(원자료와의 차이 보고, 실패하지 않음)·err(결함, NORIORI_AUDIT_STRICT=1이면 실패)·warn(사람이 볼 후보). ids는 행에 나온 ID 전부(회귀 대조용)
IDK=re.compile(r'^(?:n|r|l|e|a|o|hub)_[0-9a-z_]+$')
def _ids(x,o):
    if isinstance(x,str):
        if IDK.match(x):o.add(x)
    elif isinstance(x,dict):
        for y in x.values():_ids(y,o)
    elif isinstance(x,(tuple,list,set,frozenset)):
        for y in x:_ids(y,o)
def put(k,rows,lim=40,lvl='report',**kw):
    rows=list(rows);ids=set()
    for r in rows:_ids(r,ids)
    R[k]=dict(n=len(rows),lvl=lvl,sample=rows[:lim],ids=sorted(ids),**kw)
def nz(s):
    s=unicodedata.normalize('NFKC',s or '')
    s=re.sub(r'[〈<(（].*?[〉>)）]','',s).replace('【旧】','').strip('*[] ')
    for a,b in (('ヶ','ケ'),('ヵ','ケ'),('﨑','崎'),('髙','高'),('渕','淵'),('澤','沢'),('濱','浜'),('瀧','滝'),('條','条'),('龍','竜'),('國','国'),('會','会'),('櫻','桜'),('廣','広'),('德','徳'),('諌','諫'),('槇','槙'),('祗','祇'),('塚','塚'),('之','ノ'),('の','ノ'),('嶋','島')):s=s.replace(a,b)
    if len(s)>1 and s.endswith('駅'):s=s[:-1]
    # 送り仮名 「通り」와 「通」은 같은 이름이다 (江ノ電 海岸通り·海岸通, 2026-11-14)
    s=s.replace('通り','通')
    return s.replace(' ','')
ja=collections.defaultdict(list);alias=collections.defaultdict(list)
for t,i,x in n.execute("select entity_type,entity_id,text from name where lang='ja' and valid_to is null"):ja[t,i].append(x)
for i,x in n.execute("select entity_id,text from alias where entity_type='node' and kind<>'old_title'"):alias[i].append(x)
def names(i):return {nz(x) for x in ja['node',i]+alias[i]}
def nn(i):return ja['node',i][0] if ja['node',i] else i
def ln(i):return ja['line',i][0] if ja['line',i] else i
routes={r['id']:dict(r) for r in m.execute('select * from route')}
stops=collections.defaultdict(list)
# 여객 영업 이력이 없는 화물선(rule_class hidden) 계통은 원자료(노리츠부시·N05·위키 여객 역) 대조에서 뺀다. DB에만 두는 화물 지선이다 (9회차 F)
_HIDL={r_[0] for r_ in m.execute("select id from line where rule_class='hidden'")}
for r in m.execute('select * from route_stop where is_extension=0 order by route_id,seq'):
    if routes[r['route_id']]['line_id'] in _HIDL:continue
    stops[r['route_id']].append(dict(r))
line_routes=collections.defaultdict(list)
for k,r in routes.items():line_routes[r['line_id']].append(k)
kms=dict(m.execute('select edge_id,km from edge_km').fetchall())
# ---- 1. 노리츠부시 현행 표: 역 순서와 km를 그대로 다시 찾는다
NB=json.load(open(os.path.join(ROOT,'data/imports/noritsubushi/lines.json'),encoding='utf-8'))
pair_db=collections.defaultdict(list)
for k,s in stops.items():
    for a,b in zip(s,s[1:]):
        for x in names(a['node_id']):
            for y in names(b['node_id']):
                pair_db[x,y].append(round(b['km_cum']-a['km_cum'],1));pair_db[y,x].append(round(b['km_cum']-a['km_cum'],1))
seq_miss=[];km_miss=[];tot=0;ok=0
nm_all=collections.Counter()
for x in NB:
    if x['g'] not in('jr','pr','jrx','prx','tm'):continue
    st=[(l,float(k)) for l,k in x['s']]
    # 숨은 노드, 옛 표기를 그대로 두고 이웃끼리 본다
    clean=[(nz(re.sub(r'^\(臨\)','',l.strip('*').strip('[]'))),k) for l,k in st]
    for (a,ka),(b,kb) in zip(clean,clean[1:]):
        tot+=1
        d=round(abs(kb-ka),1)
        v=pair_db.get((a,b))
        if v is None:seq_miss.append((x['t'][:24],a,b,d))
        elif not any(abs(z-d)<=.11 for z in v):km_miss.append((x['t'][:24],a,b,d,sorted(set(v))[:3]))
        else:ok+=1
put('노리츠부시 이웃 쌍이 DB에 없음',seq_miss,60,tot=tot,ok=ok)
put('노리츠부시 이웃 km 다름',km_miss,60)
# ---- 2. station_database 현행 노선: 역 수와 집합
SD=list(csv.DictReader(open(os.path.join(ROOT,'data/imports/stationdb/station.csv'),encoding='utf-8')))
LN=list(csv.DictReader(open(os.path.join(ROOT,'data/imports/stationdb/line.csv'),encoding='utf-8')))
RG=list(csv.DictReader(open(os.path.join(ROOT,'data/imports/stationdb/register.csv'),encoding='utf-8')))
sdc={s['code']:s for s in SD}
cur_names=set()
for k,s in stops.items():
    for x in s:
        if x['valid_to']=='ongoing' and x['is_stop']:cur_names|=names(x['node_id'])
all_names=set()
for k,s in stops.items():
    for x in s:all_names|=names(x['node_id'])
arch={nz(t) for t, in n.execute("select text from name where entity_type='archive' and lang='ja'")}|{nz(t) for t in dropped_ja()}
miss=[];closed_but_cur=[];cur_but_closed=[]
sdopen=collections.defaultdict(list)
for s in SD:
    nm=nz(s['name'])
    if s['closed']=='0':
        sdopen[nm].append(s)
        if nm not in cur_names:
            (cur_but_closed if nm in all_names else miss).append((nm,s['prefecture'],s['open_date'],s['closed_date'],s['original_name']))
put('SD 현행 역이 DB에 없음',miss,80)
put('SD 현행 역이 DB에서 폐역',cur_but_closed,80)
put('DB 현행 역이 SD에 없음(현행)',sorted(x for x in cur_names if x not in sdopen),80)
# 노선 단위: SD 현행 노선의 역 순서가 DB의 어떤 계통과 맞는가
rg=collections.defaultdict(list)
for r in RG:rg[r['line_code']].append((int(r['index']),r['station_code']))
bad=[];chk=0
for l in LN:
    if l['closed']!='0':continue
    ss=[nz(sdc[c]['name']) for _,c in sorted(rg[l['code']]) if c in sdc and sdc[c]['closed']=='0']
    for a,b in zip(ss,ss[1:]):
        chk+=1
        if (a,b) not in pair_db:
            # 폐역이 끼어 있을 수 있으므로 같은 계통 안 순서로 다시 본다
            okk=False
            for k,s in stops.items():
                idx=[i for i,x in enumerate(s) if a in names(x['node_id'])]
                if not idx:continue
                jdx=[i for i,x in enumerate(s) if b in names(x['node_id'])]
                if jdx and min(abs(i-j) for i in idx for j in jdx)<=6:okk=True;break
            if not okk:bad.append((l['name'],a,b))
put('SD 현행 이웃 역이 DB 계통에서 이웃 아님',bad,60,chk=chk)
# ---- 3. N02 2024 역 점과 위치 대조
zz=zipfile.ZipFile(os.path.join(ROOT,'data/imports/n02/N02-24_GML.zip'))
f=[x for x in zz.namelist() if x.endswith('Station.geojson') and 'UTF-8' in x]
pts=collections.defaultdict(list)
if f:
    d=json.loads(zz.read(f[0]).decode('utf-8'))
    for ft in d['features']:
        p=ft['properties'];g=ft['geometry']['coordinates']
        c=g[len(g)//2] if isinstance(g[0],list) else g
        pts[nz(p.get('N02_005',''))].append((c[1],c[0],p.get('N02_003',''),p.get('N02_004','')))
def hav(a,b):
    p1,l1,p2,l2=map(math.radians,(a[0],a[1],b[0],b[1]));h=math.sin((p2-p1)/2)**2+math.cos(p1)*math.cos(p2)*math.sin((l2-l1)/2)**2
    return 6371*2*math.asin(math.sqrt(h))
far=[];ok=0;none=0
for r in m.execute("select p.node_id,p.lat,p.lon,p.quality,p.source from node_position p where p.lat is not null and p.node_id in (select node_id from route_stop where is_stop=1 and valid_to='ongoing')"):
    nmz=names(r['node_id']);c=[]
    for x in nmz:c+=pts.get(x,[])
    if not c:none+=1;continue
    d=min(hav((r['lat'],r['lon']),q) for q in c)
    if d>.35:far.append((round(d,2),nn(r['node_id']),r['node_id'],r['quality'],r['source'],r['lat'],r['lon']))
    else:ok+=1
far.sort(reverse=True,key=lambda x:x[0])
put('현행 역 좌표가 N02와 350m 넘게 다름',far,80,ok=ok,none=none)
# ---- 4. 역 날짜: 역 문서와 최종값
W=json.load(open(os.path.join(ROOT,'data/imports/wiki/station.json'),encoding='utf-8'))
print(json.dumps({k:v['n'] for k,v in R.items()},ensure_ascii=False))
json.dump(R,open(os.path.join(B,'audit_ext.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=0)
# ---- 5. 노리츠부시 현행 표와 오늘자 계통을 통째로 비교한다
# 표마다 이름이 가장 많이 겹치는 계통을 고르고, 정차역 순서·집합·km를 본다
SEQ=[];PHANTOM=[];MISSK=[];NOROUTE=[];EXACT=0;CLOSEDFLAG=[]
byname=collections.defaultdict(set)
for k,s in stops.items():
    for x in s:
        for y in names(x['node_id']):byname[y].add(k)
used=collections.Counter()
for x in NB:
    if x['g'] not in('jr','pr','jrx','prx'):continue
    tb=[]
    for l,k in x['s']:
        cl=l.startswith('*') or l.endswith('*') or '【旧】' in l
        hid=l.startswith('[') and l.endswith(']') or '〈貨〉' in l or l.endswith('(信)') or '信号' in l or '分岐' in l or '接続点' in l
        tb.append((nz(re.sub(r'^\(臨\)','',l.strip('*').strip('[]'))),float(k),cl,hid))
    if len(tb)<2:continue
    nowt=[t for t in tb if not t[2] and not t[3]]
    c=collections.Counter()
    for t in tb:
        for r in byname.get(t[0],()):c[r]+=1
    if not c:NOROUTE.append(x['t'][:30]);continue
    # 같은 노선 계통 전체가 표 하나를 나눠 가질 수 있으므로 상위 후보 중 km까지 맞는 것을 고른다
    best=None
    for r,_ in c.most_common(6):
        now=[y for y in stops[r] if y['is_stop'] and y['valid_to']=='ongoing']
        mt=0
        for t in nowt:
            if any(t[0] in names(y['node_id']) for y in now):mt+=1
        sc=mt-abs(len(now)-len(nowt))*.5
        if best is None or sc>best[0]:best=(sc,r,now)
    sc,r,now=best
    used[r]+=1
    a=[t[0] for t in nowt]
    b=[nz(nn(y['node_id'])) if nz(nn(y['node_id'])) in a else min(names(y['node_id'])&set(a) or {nz(nn(y['node_id']))}) for y in now]
    if a==b or a==b[::-1]:EXACT+=1
    else:
        sa,sb=set(a),set(b)
        SEQ.append((x['t'][:34],r,'표만',sorted(sa-sb)[:6],'DB만',sorted(sb-sa)[:6],'순서' if sa==sb else ''))
    # km: 이름이 같은 역끼리 표의 간격과 DB 간격
    pa={t[0]:t[1] for t in nowt}
    pb={}
    for y,nmz in zip(now,b):pb[nmz]=y['km_cum']
    com=[t for t in a if t in pb]
    for p,q in zip(com,com[1:]):
        d1=round(abs(pa[q]-pa[p]),1);d2=round(abs(pb[q]-pb[p]),1)
        if abs(d1-d2)>.11:MISSK.append((x['t'][:30],p,q,d1,d2))
R['현행 표와 계통 정확 일치']=dict(n=0,sample=[EXACT])
put('현행 표와 계통 불일치',SEQ,120)
put('현행 표 km 불일치',MISSK,60)
put('현행 표에 맞는 계통 없음',NOROUTE)
print({k:R[k]['n'] for k in ('현행 표와 계통 불일치','현행 표 km 불일치','현행 표에 맞는 계통 없음')},EXACT)
json.dump(R,open(os.path.join(B,'audit_ext.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=0)
# ---- 6. 오늘자 이웃 역 쌍을 양쪽에서 모아 집합으로 비교한다. 표 경계와 계통 경계에 영향받지 않는다
NP=collections.defaultdict(set)
for x in NB:
    if x['g'] not in('jr','pr','jrx','prx'):continue
    tb=[]
    for l,k in x['s']:
        cl=l.startswith('*') or l.endswith('*') or '【旧】' in l
        hid=l.startswith('[') and l.endswith(']') or '〈貨〉' in l or l.endswith('(信)') or '信号' in l or '分岐' in l or '接続点' in l
        if not cl and not hid:tb.append((nz(re.sub(r'^\(臨\)','',l)),float(k)))
    for (a,p),(b,q) in zip(tb,tb[1:]):
        NP[frozenset((a,b))].add(round(abs(q-p),1))
DP=collections.defaultdict(list)
for k,s in stops.items():
    now=[y for y in s if y['is_stop'] and y['valid_to']=='ongoing']
    for p,q in zip(now,now[1:]):
        DP[k].append((p,q))
only_db=[];only_nb=dict(NP);ok=0
for k,v in DP.items():
    for p,q in v:
        d=round(abs(q['km_cum']-p['km_cum']),1);hit=None
        for a in names(p['node_id']):
            for b in names(q['node_id']):
                f=frozenset((a,b))
                if f in NP and any(abs(z-d)<=.11 for z in NP[f]):hit=f
        if hit is None:only_db.append((k,nn(p['node_id']),nn(q['node_id']),d))
        else:ok+=1;only_nb.pop(hit,None)
put('오늘 이웃 쌍, DB에만',only_db,120,ok=ok,nb=len(NP))
put('오늘 이웃 쌍, 표에만',[(sorted(k),sorted(v)) for k,v in only_nb.items()],120)
print({k:R[k]['n'] for k in ('오늘 이웃 쌍, DB에만','오늘 이웃 쌍, 표에만')},ok)
json.dump(R,open(os.path.join(B,'audit_ext.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=0)
# ---- 7. 모든 표(폐선 표 포함)의 이웃 쌍을 계통 위 누적 km로 대조한다. 끼워 넣은 옛 역은 건너뛴다
where=collections.defaultdict(list)
for k,s in stops.items():
    for i,x in enumerate(s):
        for y in names(x['node_id']):where[y].append((k,i,x['km_cum']))
fail=[];fail2=[];good=0
for x in NB:
    tb=[(nz(re.sub(r'^\(臨\)','',l.strip('*').strip('[]')).replace('〈貨〉','')),float(k)) for l,k in x['s']]
    for (a,p),(b,q) in zip(tb,tb[1:]):
        d=round(abs(q-p),1);found=None
        ra={k:(i,c) for k,i,c in where.get(a,[])}
        for k,i,c in where.get(b,[]):
            if k in ra:
                dd=round(abs(ra[k][1]-c),1)
                if found is None or abs(dd-d)<abs(found[0]-d):found=(dd,k)
        if found is None:fail.append((x['g'],x['t'][:26],a,b,d))
        elif abs(found[0]-d)>.11:fail2.append((x['g'],x['t'][:26],a,b,d,found[0],found[1]))
        else:good+=1
put('표 이웃 쌍이 같은 계통에 없음',fail,150,good=good)
put('표 이웃 간격이 계통 누적 km와 다름',fail2,150)
# 같은 이름이 같은 계통에 둘
dup=[]
for k,s in stops.items():
    c=collections.defaultdict(list)
    for x in s:
        c[nz(nn(x['node_id']))].append(x)
    for nm_,v in c.items():
        if len(v)>1 and len({y['node_id'] for y in v})>1:dup.append((k,nm_,[(y['seq'],y['km_cum'],y['valid_from'],y['valid_to']) for y in v]))
put('같은 계통에 같은 이름의 다른 노드',dup,60)
print({k:R[k]['n'] for k in ('표 이웃 쌍이 같은 계통에 없음','표 이웃 간격이 계통 누적 km와 다름','같은 계통에 같은 이름의 다른 노드')},good)
json.dump(R,open(os.path.join(B,'audit_ext.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=0)
# ---- 8. 표의 구간별 개업일·폐지일과 DB의 구간 날짜
E_=collections.defaultdict(list)
for r in m.execute('select x.route_id,x.seq,x.edge_id,e.from_node,e.to_node from route_edge x join edge e on e.id=x.edge_id order by 1,2'):E_[r['route_id']].append(dict(r))
LIFE=collections.defaultdict(list)
for r in m.execute('select * from edge_life'):LIFE[r['edge_id']].append(dict(r))
AT=collections.defaultdict(list)
for r in m.execute('select * from edge_attr'):AT[r['edge_id']].append(dict(r))
def norm_d(s):
    s=unicodedata.normalize('NFKC',s or '').strip()
    return s[:10] if re.match(r'\d{4}-\d\d-\d\d',s) else None
op_bad=[];cl_bad=[];nf=[];okc=0
for x in NB:
    for t in x.get('h',[]):
        if not t or len(t)<2:continue
        h=''.join(t[0]);kind='open' if '開業日' in h else ('close' if '廃止日' in h else None)
        if not kind:continue
        for row in t[1:]:
            if len(row)<3 or '～' not in row[0]:continue
            a,b=[nz(q) for q in row[0].split('～')[:2]];d=norm_d(row[2])
            if not d or d[5:7]=='00' or d[8:]=='00':continue
            ra={k:i for k,i,c in where.get(a,[])}
            cand=[(k,ra[k],i) for k,i,c in where.get(b,[]) if k in ra]
            if not cand:nf.append((x['t'][:24],row[0],d));continue
            res=[]
            for k,i,j in cand:
                i,j=min(i,j),max(i,j)
                seg=[e['edge_id'] for e in E_[k]][i:j]
                if kind=='open':res.append({min((z['valid_from'] or '9') for z in AT[e]) for e in seg})
                else:res.append({max((z['valid_to'] or '') for z in LIFE[e]) for e in seg}|{max((z['legal_abolition'] or z['valid_to'] or '') for z in LIFE[e]) for e in seg})
            hit=any(d in s for s in res)
            if hit:okc+=1
            else:(op_bad if kind=='open' else cl_bad).append((x['t'][:24],row[0],d,sorted(res[0])[:4]))
put('표 개업일이 구간 날짜에 없음',op_bad,80,ok=okc)
put('표 폐지일이 구간 날짜에 없음',cl_bad,80)
put('표 구간을 계통에서 못 찾음',nf,40)
print({k:R[k]['n'] for k in ('표 개업일이 구간 날짜에 없음','표 폐지일이 구간 날짜에 없음','표 구간을 계통에서 못 찾음')},okc)
json.dump(R,open(os.path.join(B,'audit_ext.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=0)
# ---- 9. 위키 캐시·N05와 원인별 대조 (2회차 종합 K01·K11·K12·K18·K23·K25·K26·K28·K29·K36, 묶음 B5)
# data/imports의 로컬 캐시만 읽는다(외부 요청 없음). 위키 노선도 행은 HTML 표 해석기(tools/wparse.py)로 읽는다. 판정 규칙은 여기서 따로 둔다
import gzip,hashlib,datetime,sys
sys.path.insert(0,os.path.join(ROOT,'tools'))
import wparse as wp
from lib import load,lohi,AS_OF
ON='ongoing';BASE='1950-01-01'
def ivl(f,t):
    try:a=lohi(f) if f else ('0000-01-01','0000-01-01');b=lohi(t) if t else ('9999-12-31','9999-12-31')
    except ValueError:return None
    return (a[0],a[1],b[0],b[1])
ALLJA=collections.defaultdict(list)   # 노드의 모든 일본어 이름 행(옛·노선 전용 포함)
for i,x,li,vf,vt in n.execute("select entity_id,text,line_id,valid_from,valid_to from name where entity_type='node' and lang='ja'"):ALLJA[i].append((x,li,vf,vt))
OLDT=collections.defaultdict(set)
for i,x in n.execute("select entity_id,text from alias where entity_type='node' and kind='old_title'"):OLDT[i].add(nz(x))
_AN={}
def anames(i):
    if i not in _AN:_AN[i]={nz(x) for x,*_ in ALLJA[i]}|{nz(x) for x in alias[i]}|OLDT[i]
    return _AN[i]
rnodes=collections.defaultdict(set)
for r in m.execute('select route_id,node_id from route_stop'):rnodes[routes[r[0]]['line_id']].add(r[1])
GRP=dict(m.execute('select id,group_id from node').fetchall())
def G_(x):return GRP.get(x) or x
TLG=set()
for at,a,b in m.execute('select at_node,line_a,line_b from track_link'):TLG|={(G_(at),a,b),(G_(at),b,a)}
for a,b,x in m.execute('select line_id,other_line_id,node_id from junction'):TLG|={(G_(x),a,b),(G_(x),b,a)}
LTY={i:('shinkansen' if rc=='shinkansen' else {'rail':'heavy','subway':'heavy','trolley':'tram'}.get(t,t)) for i,t,rc in m.execute('select id,type,rule_class from line')}
def sysx(l):return LTY.get(l)
SPN=collections.defaultdict(list)
for r_,x,f_,t_ in m.execute('select route_id,node_id,valid_from,valid_to from route_stop_period'):SPN[x].append(ivl(f_,t_))
pos={r['node_id']:(r['lat'],r['lon']) for r in m.execute('select node_id,lat,lon from node_position where lat is not null')}
# 위키 문서: 노선 → 캐시 문서. 캐시 파일 이름은 문서 제목의 md5 앞 14자리
WD=os.path.join(ROOT,'data','imports','wiki')
def doc(t):
    f=os.path.join(WD,hashlib.md5(t.encode()).hexdigest()[:14]+'.json.gz')
    return json.load(gzip.open(f,'rt',encoding='utf-8')) if os.path.exists(f) else None
SRC={x['id']:x for x in load('lines')}
LDOC={}
for l in line_routes:
    s_=SRC.get(l,{});cands=[]
    if s_.get('sd'):cands.append(re.sub(r'^JR','',re.sub(r'[（(].*?[)）]','',s_['sd']).strip()))
    cands+=[s_.get('name_ja')]+ja['line',l]
    for t in cands:
        if t and (d_:=doc(t)) and d_.get('html'):LDOC[l]=d_;break
_rows={}
def rows_of(l):
    d_=LDOC.get(l)
    if not d_:return []
    if d_['title'] not in _rows:
        rr,_=wp.extract(None,8,wp.parse_text(d_['html']))
        _rows[d_['title']]=[r for r in rr if isinstance(r,dict) and 'h' not in r]
    return _rows[d_['title']]
STN=re.compile(r'([^\s／：・（()）]+?)(?:臨時乗降場|仮乗降場|仮停車場|仮停留場|臨時駅|駅|停留場|停留所|電停|信号場|乗降場)')
def row_node(l,r,nm2n):
    for tok in STN.finditer(r['t']):
        x=nz(tok.group(1))
        if x in nm2n:return nm2n[x]
    x=nz(re.split(r'[\s(（]',r['t'].strip())[0]) if r['t'].strip() else ''
    return nm2n.get(x)
def nmap(l):
    # 같은 이름 노드가 둘 이상이면 ID 순서로 첫 노드 (실행마다 같은 결과)
    o={}
    for x in sorted(rnodes[l]):
        for y in anames(x):o.setdefault(y,x)
    return o
KMN=re.compile(r'\d+\.\d+')
TMP=re.compile(r'(?:（臨）|\(臨\))\s*([^\s（(駅]+)駅|([^\s／：・（()）]+?)(?:仮乗降場|仮停車場|仮停留場|臨時乗降場|臨時駅)')
rs_by=collections.defaultdict(dict)
for k,s in stops.items():
    for y in s:rs_by[routes[k]['line_id']].setdefault(y['node_id'],[]).append((k,y))
markn={r[0] for r in n.execute('select node_id from stop_mark')}
# 계통 한정 표식(尼崎港線 尼崎, stop_mark_route)도 그 역의 임시역 표식이다 (2026-11-14)
if n.execute("select 1 from sqlite_master where name='stop_mark_route'").fetchone():markn|={r[0] for r in n.execute('select node_id from stop_mark_route')}
arch_l=collections.defaultdict(set)
for i,l in m.execute('select id,line_id from archive_stop'):
    for x, in n.execute("select text from name where entity_type='archive' and entity_id=? and lang='ja'",(i,)):arch_l[l].add(nz(x))
NB_I=collections.defaultdict(set)
for x in NB:
    tb=[(nz(re.sub(r'^\(臨\)','',l_.strip('*').strip('[]')).replace('〈貨〉','')),float(k_)) for l_,k_ in x['s']]
    for (a,p),(b,q) in zip(tb,tb[1:]):NB_I[frozenset((a,b))].add(round(abs(q-p),1))
KMFIX={z for x in json.load(open(os.path.join(ROOT,'data','overrides','km_fix.json'),encoding='utf-8')) for z in (x.get('a'),x.get('b'))}
abz=[];kmest=[];kmdiff=[];miss=[];kari=[];mvd=[];kmest_tram=[]
# 노선별로 각 역 묶음에 닿는 칸 (자기 갈림 판정)
OWN_E=collections.defaultdict(set)
TLL=collections.defaultdict(set)
for g_,a_,b_ in TLG:TLL[g_,a_].add(b_)
for e_,a_,b_,l_ in m.execute('select e.id,e.from_node,e.to_node,a.line_id from edge e join edge_attr a on a.edge_id=e.id'):
    OWN_E[l_,G_(a_)].add(e_);OWN_E[l_,G_(b_)].add(e_)
KARI_N={x_['node'] for x_ in json.load(open(os.path.join(ROOT,'data','overrides','stop_status.json'),encoding='utf-8')) if x_.get('kind')=='kari'}
MOVED={frozenset(r) for r in m.execute('select old_node,new_node from node_move')}
NOSTN=re.compile(r'専用|貨物|（社）|\(社\)|工場|車両|基地|信号|操車|車庫|機関区|運転所|検車|電留線|留置|発電|鉱|炭|森林|索道|ロープウェイ')
LBYT=collections.defaultdict(set)
for l,d_ in LDOC.items():LBYT[d_['title']].add(l)
# ---- 위키 年表 문장과 DB 대조 공통 (8회차 W1b)
def wclean(t):
    """위키 글 한 줄에서 각주·틀·링크 꾸밈을 걷어 낸 글"""
    t=re.sub(r'<ref[^>]*/>','',t);t=re.sub(r'<ref[^>]*>.*?</ref>','',t);t=re.sub(r'<ref[^>]*>.*$','',t)
    for _ in range(4):t=re.sub(r'\{\{[^{}]*\}\}','',t)
    t=re.sub(r'\[\[(?:[^|\]]*\|)?([^\]]*)\]\]',r'\1',t);t=re.sub(r"'''?|<[^>]+>",'',t)
    return t.replace('&nbsp;',' ').replace('　',' ')
HSEC=re.compile(r'歴史|沿革|年表|変遷|概要')
YD=re.compile(r'^\s*(\d{4})年(?:度)?(?:\s*[（(][^）)]*[）)])?\s*(?:(\d{1,2})月(?:\s*(\d{1,2})日)?)?')
MD=re.compile(r'^\s*(?:[（(][^）)]*[）)])?\s*(\d{1,2})月(?:\s*(\d{1,2})日)?')
def hist_items(wt,sec=HSEC):
    """歴史·沿革·年表 절의 글머리 줄 → [(EDTF 날짜 또는 None, 글, 깊이)]. 날짜 없는 아래 줄은 윗줄 날짜를, 월일만 있는 줄은 윗줄 해를 이어 쓴다.
    「以前·まで·頃·までに」가 붙은 날짜는 해만 남긴다"""
    out=[];hs=[];dst={}
    for raw in (wt or '').split('\n'):
        mh=re.match(r'^(=+)\s*(.*?)\s*=+\s*$',raw)
        if mh:
            lv=len(mh.group(1));hs=[h for h in hs if h[0]<lv]+[(lv,mh.group(2))];dst={};continue
        if sec is not None and not any(sec.search(h) for _,h in hs):continue
        mb=re.match(r'^([*#]+)\s*(.*)$',raw)
        if not mb:continue
        dep=len(mb.group(1));t=wclean(mb.group(2)).strip()
        par=dst.get(dep-1)
        my=YD.match(t);mm=None if my else MD.match(t)
        if my:
            y,mo,d=my.groups();d_=f'{y}-{int(mo):02d}-{int(d):02d}' if d else (f'{y}-{int(mo):02d}-XX' if mo else f'{y}-XX-XX')
            q_=re.sub(r'^[\s：:\-–]*(?:[（(][^）)]*[）)])?[\s：:\-–]*','',t[my.end():my.end()+16])
            if re.match(r'(?:以前|まで|頃まで|この年までに|までに)',q_):d_=f'[..{y}-XX-XX]'
            elif re.match(r'(?:以降|この年以降)',q_):d_=f'[{y}-XX-XX..]'
            elif re.match(r'(?:頃|ごろ)',q_):d_=f'{y}-XX-XX'
            t=t[my.end():]
        elif mm and par:
            py=re.search(r'\d{4}',par).group(0);mo,d=mm.groups();d_=f'{py}-{int(mo):02d}-{int(d):02d}' if d else f'{py}-{int(mo):02d}-XX'
            t=t[mm.end():]
        elif re.match(r'\s*[（(]?(?:月日不詳|日付不詳|日不詳)',t) and par:d_=re.search(r'\d{4}',par).group(0)+'-XX-XX'
        else:
            d_=par if dep>1 else None
            # 아래 줄 첫머리 「この年以降」「この年までに」는 윗줄 해를 범위로 바꾼다
            if d_ and (q_:=re.match(r'^\s*(?:この年|同年)(以降|までに|以前)',t)):
                y_=re.search(r'\d{4}',d_).group(0);d_=f'[{y_}-XX-XX..]' if q_.group(1)=='以降' else f'[..{y_}-XX-XX]'
        dst[dep]=d_
        for k in [k for k in dst if k>dep]:dst.pop(k)
        out.append((d_,re.sub(r'^\s*[-－–―:：、]\s*','',t).strip(),dep))
    return out
_HI={}
def hist_of(title):
    if title not in _HI:
        d_=doc(title);_HI[title]=hist_items(d_.get('wikitext') or '') if d_ else []
    return _HI[title]
def dlo(d):
    try:return lohi(d)
    except Exception:return (None,None)
TNM=r'[^\s、。，,・･「」『』（）()：:→＝=　]'
STN2=re.compile(r'('+TNM+r'{1,20}?)(?:臨時乗降場|仮乗降場|仮停車場|仮停留場|臨時駅|駅|停留場|停留所|電停|乗降場)')
def sect_cut(s):
    """「A駅 - B駅間」 구간 표현과 괄호 안(現在の…)을 지운 글 (역 하나에 대한 사건만 남김)"""
    s=re.sub(r'[（(][^（）()]*[）)]','',s)
    return re.sub(TNM+r'+?(?:駅|停留場|停留所|電停)?\s*[-－–―〜~～]\s*(?:'+TNM+r'+?(?:駅|停留場|停留所|電停)?\s*[-－–―〜~～]\s*)*'+TNM+r'+?(?:駅|停留場|停留所|電停)?間',' 〓 ',s)
def stn_names(s):
    """글 조각의 역 이름들: 「A駅、B駅」「A・B・Cの各停留場」「A、Bの両駅」"""
    o=[]
    for m_ in re.finditer(r'((?:'+TNM+r'{1,15}[・、])+'+TNM+r'{1,15})の(?:各|両|3|三|4|四|5|五)?(?:駅|停留場|停留所|電停)',s):o+=re.split(r'[・、]',m_.group(1))
    o+=[m_.group(1) for m_ in STN2.finditer(s)]
    return [re.sub(r'^(?:旧|新設の|休止中の|休止していた|現在の|臨時)','',x) for x in o if x]
TNODES={}
def title_nodes(title):
    """그 문서를 쓰는 노선들의 노드 이름 → 노드 (옛 이름 포함)"""
    if title not in TNODES:
        o={}
        for l in sorted(LBYT.get(title,())):
            for y,x in nmap(l).items():o.setdefault(y,x)
        TNODES[title]=o
    return TNODES[title]
def tlines(title):return sorted(LBYT.get(title,()))
RSP=collections.defaultdict(list)   # (노선, 노드) → 정차 기간 [(lo_from,hi_from,lo_to,hi_to,route)]
for r_,x,f_,t_ in m.execute('select route_id,node_id,valid_from,valid_to from route_stop_period'):
    v=ivl(f_,t_)
    if v:RSP[routes[r_]['line_id'],x].append(v+(r_,))
GAPS=collections.defaultdict(list)
for r_,x,f_,t_ in m.execute('select route_id,node_id,gap_from,gap_to from route_stop_gap'):
    v=ivl(f_,t_)
    if v:GAPS[routes[r_]['line_id'],x].append(v+(r_,))
def per_of(title,x):
    return [p for l in tlines(title) for p in RSP.get((l,x),[])]
def gap_of(title,x):
    return [p for l in tlines(title) for p in GAPS.get((l,x),[])]
def dmatch(d,lo,hi):
    """위키 날짜 d(EDTF)가 DB 날짜 범위 [lo,hi]와 맞물리는가 (해·달만 적힌 위키 날짜는 겹치면 맞음)"""
    a,b=dlo(d)
    return a is not None and lo is not None and a<=hi and lo<=b
for l in sorted(LDOC):
    R_=rows_of(l)
    if not R_:continue
    nm2n=nmap(l);hit=[]
    for r in R_:
        x=row_node(l,r,nm2n);icons=[z for c in r['c'] for z in c]
        if x:hit.append((r,x))
        # 선로 접속 아이콘(ABZ·CONT) 행이 가리키는 다른 노선과 선로 연결 판정이 없음
        if x and any(re.search(r'ABZ|CONT',z) for z in icons):
            Ms_=[M for t in r.get('l',[]) for M in sorted(LBYT.get(t,())) if M!=l and rnodes[M] and sysx(M)==sysx(l) and {G_(y) for y in rnodes[M]}&{G_(x)}]
            # 행의 노선 칸에는 환승 노선도 함께 적힌다. 그중 하나라도 선로 연결이 있으면 아이콘은 그 연결이다(京葉線 西船橋: 武蔵野線과 연결, 東西線은 환승, 6회차 2026-11-14)
            # 아이콘 하나는 연결 하나다. 노선도 노선이 그 역(묶음)에서 이미 다른 노선과 선로 연결이 있거나(京葉線 西船橋: 武蔵野線, 東西線·東葉은 환승) 자신이 셋 이상의 칸으로 갈라지면 아이콘은 그것이다 (6회차 2026-11-14)
            if Ms_ and (len(OWN_E.get((l,G_(x)),()))>=3 or TLL.get((G_(x),l))):Ms_=[]
            if not any((G_(x),l,M) in TLG for M in Ms_):
                for M in Ms_:abz.append((ln(l),ln(M),nn(x),x))
        # 이름에 仮·臨이 붙은 역인데 임시역 표식이 없음
        if x and x not in markn and any(nz(a or b) in anames(x) for a,b in TMP.findall(r['t'])) and not (re.findall(r'\d{4}',r['t']) and max(int(y) for y in re.findall(r'\d{4}',r['t']))<1950):kari.append((ln(l),nn(x),x,r['t'][:30]))
    # km: 위키 행 km이 있는 역이 DB에서 추정 km / 위키 이웃 간격과 DB 간격
    seen=[]
    for r,x in hit:
        ks=KMN.findall(r['k'] or '')
        if not ks:continue
        kw=float(ks[-1])
        for rid,y in rs_by[l].get(x,[]):
            # 노면전차 정류장은 어느 一覧·要覧에도 정류장별 営業キロ가 없어 위키 km뿐이면 결함이 아니다(warn). 局設定 仮乗降場은 공식 営業キロ가 없다 (3회차 근거 조사 2026-11-13)
            if y['km_estimated'] and y['is_stop'] and x not in KARI_N:(kmest_tram if LTY.get(l)=='tram' else kmest).append((rid,nn(x),x))
        seen.append((x,kw))
    main=[k for k in line_routes[l] if routes[k]['role']=='main']
    if main:
        s=[y for y in stops[main[0]] if y['is_stop'] and y['valid_to']==ON];at={y['node_id']:y['km_cum'] for y in s};idx={y['node_id']:i for i,y in enumerate(s)}
        sv=[(x,k) for x,k in seen if x in at]
        for (a,ka),(b,kb) in zip(sv,sv[1:]):
            if abs(idx[a]-idx[b])!=1 or a in KMFIX or b in KMFIX:continue
            dw=round(abs(kb-ka),1);dd=round(abs(at[b]-at[a]),1)
            if abs(dw-dd)<=.15 or abs(dw-dd)>=2:continue   # 2km 넘는 차이는 다른 기점 km 열·지선 표를 이어 읽은 것
            nbv={v for p in anames(a) for q in anames(b) for v in NB_I.get(frozenset((p,q)),())}
            if any(abs(v-dd)<=.05 for v in nbv):continue   # 노리츠부시와 같으면 노리츠부시 유지 (U17)
            kmdiff.append((ln(l),nn(a),nn(b),dw,dd,sorted(nbv)[:2]))
    # 같은 역이 「(1)·(2)·旧」 표시로 km를 달리해 두 번 나오는데 이전 쌍이 없음
    by=collections.defaultdict(list)
    for r in R_:
        t=r['t'].strip();mk=re.match(r'^([^\s／：・（(]+?)(?:駅|停留場)?\s*[（(](?:\d|I{1,3}|IV|旧|初代|[0-9一二三]代目?)[)）]',t) or re.match(r'^(?:旧)([^\s／：・（(]+?)(?:駅|停留場)',t)
        ks=KMN.findall(r['k'] or '')
        if mk and ks:by[nz(mk.group(1))].append((float(ks[-1]),t[:30]))
        elif ks:
            mm=STN.match(t)
            if mm:by[nz(mm.group(1))].append((float(ks[-1]),t[:30]))
    for nmz,v in by.items():
        if len(v)<2 or not any(re.search(r'[（(](?:\d|I{1,3}|IV|旧|初代|[0-9一二三]代目?)[)）]|^旧',t) for _,t in v):continue
        # 옮긴 해 = 표시 붙은 행 가운데 가장 먼저 끝난 행의 끝 해 (1950년 뒤만)
        ye_=[int(y) for _,t in v for y in re.findall(r'[-–−]\s*(\d{4})',t)]
        if max(k for k,_ in v)-min(k for k,_ in v)<.1 or not ye_ or min(ye_)<1950 or re.search('信号',''.join(t for _,t in v)):continue
        xs=[x for x in rnodes[l] if nmz in anames(x)]
        if not xs:continue
        # 「旧○○駅」이 따로 있는 다른 역(石北本線 旧白滝 1947–2016)이면 이전 쌍이 아니다 (3회차 근거 조사 2026-11-13)
        if any(t.startswith('旧') for _,t in v) and nz('旧'+nmz) in {nz(x_) for v_ in ALLJA.values() for x_,*_ in v_}:continue
        if not any(frozenset((a,b)) in MOVED for a in xs for b in xs if a!=b):mvd.append((ln(l),nmz,[t for _,t in v][:3],xs[:3]))
put('K01 위키 노선도 선로 접속(ABZ·CONT) 행인데 그 노선과 선로 연결 없음',sorted(set(abz)),40,lvl='warn')
put('K23 위키 노선도에 km가 있는 역이 DB에서 추정 km',sorted(set(kmest)),40,lvl='err')
put('K23 노면전차 정류장 km가 위키 노선도에만 있음(공식 정류장별 km 없음)',sorted(set(kmest_tram)),40,lvl='warn')
put('K36 위키 노선도 이웃 간격과 DB 간격이 0.15km 넘게 다름(노리츠부시와 같은 것은 뺌)',kmdiff,40,lvl='warn')
# K28 다시: 앞 km 칸(「-0.1 東田町駅」)·電停·「1930-1944休、69廃」(두 자리 폐지 해)·(I)(II) 표시 행도 읽고, 행 첫 역 이름이 노드 이름이 아니면 다른 토막(「左：美濃市駅」·「美濃町駅前」의 「美濃町」)으로 노드가 잡혀도 없는 역으로 본다 (chubu_2-23 ④)
RW28=re.compile(r'^([^\s／：・（(]+?)(?:臨時乗降場|仮乗降場|仮停車場|仮停留場|臨時駅|駅|停留場|停留所|電停|停車場|乗降場)(?=[\s(（\-–−~～\d]|$)(?:\s*[（(][^）)]*[)）])?\s*(.*)$')
def close_year(rest):
    """노선도 행 꼬리(「-1960」「1932?-1958」「1930-1944休、69廃」)에서 폐지 해. 없으면 None"""
    rest=rest[:24]
    if not re.match(r'^\s*(?:\d{4}\s*[?？]?\s*)?[-–−~～]?\s*\d{4}',rest):return None
    m2=re.search(r'(\d{4})年?\s*休[^0-9]{0,3}(\d{2})\s*廃',rest)
    if m2:return int(m2.group(1)[:2]+m2.group(2)) if int(m2.group(2))>=int(m2.group(1)[2:]) else int(str(int(m2.group(1)[:2])+1)+m2.group(2))
    m2=re.search(r'(\d{4})\s*年?廃',rest) or re.match(r'^\s*(?:\d{4}\s*[?？]?\s*)?[-–−~～]\s*(\d{4})',rest)
    return int(m2.group(1)) if m2 else None
def row_head(t):
    """노선도 행 글 앞의 km 칸·번호(「[1] 」「HN51」)·들여쓰기 별표·「＝」를 뗀다"""
    return re.sub(r'^(?:[-–−]?\s*\(?\d+\.\d+\)?\*?\s*|[-–−]\s+|[＝=]|\[\d+\]\s*|\*+\s*|[A-Z]{1,3}\d{1,3}(?=[^\x00-\x7f]))+','',t.strip())
miss2=[]
for l in sorted(LDOC):
    R_=rows_of(l)
    if not R_:continue
    nm2n=nmap(l);tn=title_nodes(LDOC[l]['title']);al=set().union(*[arch_l[q] for q in tlines(LDOC[l]['title'])])
    for r in R_:
        icons=[z for c in r['c'] for z in c]
        t0=row_head(r['t'])
        m_=RW28.match(t0)
        if not m_ or NOSTN.search(r['t']):continue
        cy=close_year(m_.group(2))
        if not cy or cy<1950:continue
        if not any(re.match(r'^(ex|e[A-Z]|x[A-Z]|uex|ke)',z) and re.search('BHF|HST',z) for z in icons):continue
        nmz=nz(m_.group(1))
        if nmz in nm2n or nmz in tn or nmz in arch_l[l] or nmz in al or nmz in arch_l[None]:continue
        x=row_node(l,r,nm2n)
        if x and nmz in anames(x):continue
        miss2.append((ln(l),m_.group(1),cy,r['t'][:30]))
miss=miss2
put('K28 위키 노선도 폐역(1950년 뒤 폐지)이 DB·열람 전용에 없음',miss,40,lvl='warn')
put('K26 위키 노선도 仮·臨 역에 임시역 표식 없음',sorted(set(kari)),40,lvl='err')
put('K25 위키 노선도 이전 역(km 다른 두 행)에 이전 쌍 없음',mvd,40,lvl='err')
# ---- 위키 年表 改称 줄 (역 문서 연혁·노선 문서 年表): 1950년 뒤 「X駅をY駅に改称」의 옛 이름 X가 그 노드 이름에 있는가
W=json.load(open(os.path.join(WD,'station.json'),encoding='utf-8'))
DT=re.compile(r'(\d{4})年(?:\s*[（(][^）)]*[）)])?\s*(?:(\d{1,2})月(?:\s*(\d{1,2})日)?)?')
PAIR=re.compile(r'([^\s、。「」『』（）()・：:→]{1,20}?)(?:駅|停留場|停留所|電停)?(?:を|から|→)[「『]?([^\s、。「」『』（）()・：:→]{1,20}?)(?:駅|停留場|停留所|電停)[」』]?(?:に|へ|と)?')
def wdate(m_):
    y,mo,d=m_.groups()
    return f'{y}-{int(mo):02d}-{int(d):02d}' if d else (f'{y}-{int(mo):02d}-XX' if mo else f'{y}-XX-XX')
NAMEN=collections.defaultdict(set)
for i,v in ALLJA.items():
    for x,*_ in v:NAMEN[nz(x)].add(i)
# 이유절·종류 바뀜 구절(対して…から, 貨物·信号所·仮称·臨時→常置)은 이름이 아니다 (2회차 audit 근거 조사 2026-11-13)
JUNK=re.compile(r'駅名|名称|停留場名|社名|会社|鉄道|線|として|同時|併せ|伴い|より|のみ|扱|年|月|日|の$|に$|う$|対して|から|貨物|信号|仮称|臨時|常置|との|ため|受け')
def renames(lines_):
    """연표 줄에서 (날짜, 옛 이름, 새 이름). 날짜가 없는 줄은 앞 줄의 해를 이어 쓴다"""
    out=[];last=None
    for t in lines_:
        t=re.sub(r'\[\[(?:[^|\]]*\|)?([^\]]*)\]\]',r'\1',t);t=re.sub(r"'''?|<[^>]+>|\{\{[^}]*\}\}",'',t)
        m_=DT.search(t[:40])
        if m_:last=wdate(m_)
        # 「1961年以前」처럼 위 끝만 적힌 줄은 개칭 날짜를 모른다(尻池線 菅原通5丁目: N05 1950년 기록에 없음, 2026-11-14)
        if m_ and re.match(r'\s*(?:[（(][^）)]*[）)])?\s*(?:以前|まで|頃まで)',t[m_.end():m_.end()+12]):last=None;continue
        if not last or last[:4]<'1950' or not re.search('改称|改名',t):continue
        for p in PAIR.finditer(t):
            a,b=p.group(1),p.group(2)
            # 「X駅からY駅まで」는 구간이지 개칭이 아니다 (知立 1959 「重原駅から知立駅までの新線開業」, 2026-11-14)
            if t[p.end():p.end()+2]=='まで' or t[p.end(2):p.end(2)+4].lstrip('駅停留場所').startswith('まで'):continue
            a=re.sub(r'^.*(?:駅が|駅は|駅も|、)','',a)
            # 조사로 시작하거나(が当) 조사·지시어가 섞인 6자 넘는 구절(駅周辺の地区名·用地取得の手間·隣駅の上久里)은 이름이 아니다 (3회차 근거 조사 2026-11-13)
            frag_=lambda z:bool(re.match(r'^[のがでをにはもとへや]',z) or re.search(r'この|ほか|こと|ような|など',z) or (len(z)>=6 and re.search(r'[のがでをにはも](?=.)',z) and re.search(r'[ぁ-ん]{1}',z)))
            if a and b and nz(a)!=nz(b) and 2<=len(a)<=14 and not JUNK.search(a) and not JUNK.search(b) and not frag_(a) and not frag_(b):out.append((last,a,b))
    return out
miss_old=[];bad_date=[]
def judge(d,a,b,cands,src):
    if not cands:return
    # 역 문서 연혁에 다른 역(이웃 역·같은 도시 역)의 개칭이 섞여 있으면(宇治駅 문서의 八幡市→石清水八幡宮) 그 문서 역의 개칭이 아니다
    if not any(nz(x)==nz(b) for i in cands for x,*_ in ALLJA[i]):return
    hit=[(i,x,vt) for i in cands for x,li,vf,vt in ALLJA[i] if nz(x)==nz(a)]
    # 2 km 안의 다른 노드가 그 옛 이름을 기간 있는 행으로 가지면 이웃 역(이전 전 자리·나눈 노드)의 개칭이다 (3회차 근거 조사 2026-11-13)
    def _near_(i):
        p=pos.get(i)
        return [j for j in NAMEN.get(nz(a),()) if j not in cands and p and pos.get(j) and math.hypot((pos[j][0]-p[0])*111,(pos[j][1]-p[1])*91)<2 and any(nz(x)==nz(a) and vt for x,li,vf,vt in ALLJA[j])]
    if not hit and any(_near_(i) for i in cands):return
    if not hit and not any(nz(a) in {nz(z) for z in alias[i]} for i in cands):miss_old.append((src,d,a,b,tuple(sorted(cands)[:2])))
    elif hit and 'X' not in d and not any(vt==d for i,x,vt in hit) and all((vt or '').startswith('[') or 'X' in (vt or '') for i,x,vt in hit):bad_date.append((src,d,a,b,tuple(vt for _,_,vt in hit[:2])))
for t,e in W.items():
    h=e.get('hist') or []
    if not h:continue
    cur=nz(re.sub(r'\s*[（(].*$','',e.get('title') or t))
    # 같은 이름 역이 여럿이면 그중 하나라도 옛 이름을 가지면 통과로 본다
    for d,a,b in renames(h):judge(d,a,b,set(NAMEN.get(cur,())),t)
for l,d_ in LDOC.items():
    wt=d_.get('wikitext') or ''
    seg=re.split(r'\n==+\s*(?:歴史|沿革|年表)\s*==+\n',wt)
    if len(seg)<2:continue
    body=re.split(r'\n==[^=]',seg[1])[0]
    nm2n=nmap(l)
    for d,a,b in renames(body.split('\n')):
        x=nm2n.get(nz(b))
        # 옛 이름이 같은 노선의 다른 노드에 이름 행으로 있으면(이전·나눈 노드) 그 노드가 옛 이름을 가진 것이다
        if x and nz(a) not in nm2n:judge(d,a,b,{x},d_['title'])
# K11 옛 이름 끝 날짜: 노선 문서 年表의 월일만 적힌 아래 줄(「** 3月14日」)·「それぞれ」 나열·「XをYとして営業再開」·역 문서 「駅名をY駅に改称」(옛 이름 생략)까지 읽는다 (kanto_2-018·chubu_1-021)
PN=TNM+r'{1,14}?'
PAIR3=re.compile(r'('+PN+r')(?:駅|停留場|停留所|電停)(?:が|は|を)(?:\d{4}年[^。、]{0,20}?に)?[「『]?('+PN+r')(?:駅|停留場|停留所|電停)[」』]?(?=、|に|へ|と)')
def pairs_in(t):
    """개칭 글의 (옛 이름, 새 이름, 위치): 「AをBに」「AがBに」「AはYYYY年…にBに」, 나열(「AがB、CがDに改称」)"""
    o=[]
    for P_ in (PAIR,PAIR3):
        for p in P_.finditer(t):
            a,b=p.group(1),p.group(2)
            if t[p.end():p.end()+2]=='まで' or t[p.end(2):p.end(2)+4].lstrip('駅停留場所').startswith('まで'):continue
            a=re.sub(r'^.*(?:駅が|駅は|駅も|、)','',a)
            if a and b and nz(a)!=nz(b) and not JUNK.search(a) and not JUNK.search(b):o.append((a,b,p.start()))
    return o
def renames2(items,own=False):
    """年表 줄 → (정확한 날짜, 옛 이름 또는 None, 새 이름). own=True(역 문서)이면 옛 이름 없는 「駅名をY駅に改称」도 낸다"""
    out=[]
    for d,t,_ in items:
        if not d or 'X' in d or d<'1950':continue
        if re.search('改称|改名',t):
            out+=[(d,a,b) for a,b,_ in pairs_in(t)]
            for p in re.finditer(r'((?:'+PN+r'(?:駅|停留場)?、)+'+PN+r')(?:駅|停留場)?をそれぞれ((?:'+PN+r'(?:駅|停留場)?、)+'+PN+r')(?:駅|停留場)?に',t):
                A=[re.sub(r'(?:駅|停留場)$','',z) for z in p.group(1).split('、')];B=[re.sub(r'(?:駅|停留場)$','',z) for z in p.group(2).split('、')]
                if len(A)==len(B):out+=[(d,a,b) for a,b in zip(A,B) if nz(a)!=nz(b)]
            if own:
                p=re.match(r'^\s*(?:駅名を|駅名が)?[「『]?('+PN+r')(?:駅|停留場)[」』]?に(?:改称|改名)',t)
                if p:out.append((d,None,p.group(1)))
        for p in re.finditer(r'('+PN+r')(?:駅|停留場)を('+PN+r')(?:駅|停留場)として(?:営業)?(?:再開|開業|復活)',t):
            if nz(p.group(1))!=nz(p.group(2)):out.append((d,p.group(1),p.group(2)))
    return out
def _isrange(v):return bool(v) and (v.startswith('[') or 'X' in v)
def judge2(d,a,b,x,src):
    rows_=[(t_,vf,vt) for t_,li,vf,vt in ALLJA[x]]
    if not any(nz(t_)==nz(b) for t_,_,_ in rows_):return
    if a is None:
        hit=[(t_,vt) for t_,vf,vt in rows_ if _isrange(vt) and dmatch(d,*dlo(vt))]
    else:hit=[(t_,vt) for t_,vf,vt in rows_ if nz(t_)==nz(a)]
    if hit and not any(vt==d for _,vt in hit) and all(_isrange(vt) for _,vt in hit):bad_date.append((src,d,a or hit[0][0],b,tuple(vt for _,vt in hit[:2]),x))
for t,e in W.items():
    h=e.get('hist') or []
    if not h:continue
    cur=nz(re.sub(r'\s*[（(].*$','',e.get('title') or t))
    cands=set(NAMEN.get(cur,()))
    if len(cands)!=1:continue
    x=next(iter(cands))
    for d,a,b in renames2(hist_items('\n'.join('* '+z for z in h),sec=None),own=True):
        if nz(b)==cur:judge2(d,a,b,x,t)
for title in sorted(LBYT):
    tn=title_nodes(title)
    for d,a,b in renames2(hist_of(title)):
        x=tn.get(nz(b))
        if x and (a is None or tn.get(nz(a)) in (None,x)):judge2(d,a,b,x,title)
# 노선에 이어지지 않은 문서·본문 산문(「砧駅は1961年2月1日に砧本村駅に改称」)도 읽는다: 두 이름을 모두 가진 노드가 하나일 때만
FD=re.compile(r'(\d{4})年(?:\s*[（(][^）)]*[）)])?\s*(\d{1,2})月\s*(\d{1,2})日')
for f_ in sorted(os.listdir(WD)):
    if not f_.endswith('.json.gz'):continue
    d_=json.load(gzip.open(os.path.join(WD,f_),'rt',encoding='utf-8'));wt=d_.get('wikitext') or ''
    if '改称' not in wt:continue
    for ln_ in wt.split('\n'):
        if '改称' not in ln_ or not FD.search(ln_):continue
        for s_ in wclean(ln_).split('。'):
            if '改称' not in s_:continue
            ds=[(q.start(),f'{q.group(1)}-{int(q.group(2)):02d}-{int(q.group(3)):02d}') for q in FD.finditer(s_)]
            if not ds:continue
            for a,b,k0 in pairs_in(s_):
                d=([d for k,d in ds if k<k0] or [ds[0][1]])[-1]
                if d<'1950':continue
                xs=NAMEN.get(nz(a),set())&NAMEN.get(nz(b),set())
                if len(xs)==1:judge2(d,a,b,next(iter(xs)),d_.get('title'))
_bd={}
for r_ in sorted(set(bad_date)):_bd.setdefault((r_[5] if len(r_)>5 else r_[0],nz(r_[2]),r_[1]),r_)
bad_date=list(_bd.values())
# K40 같은 노드·같은 노선 한정·같은 글자 이름 행이 이어 붙음(앞 행 끝 = 뒤 행 시작): 한 행이어야 할 것이 둘로 갈림 (chubu_1-021 ②)
k40=[]
_nr=collections.defaultdict(list)
for i,x,li,vf,vt in n.execute("select entity_id,text,line_id,valid_from,valid_to from name where entity_type='node' and lang='ja'"):_nr[i,li,nz(x)].append((vf,vt,x))
for (i,li,t_),v in _nr.items():
    for p in v:
        for q in v:
            if p is not q and p[1] and p[1]==q[0]:k40.append((i,li,p[2],q[2],p[0],p[1],q[1]))
put('K11 위키 年表 개칭의 옛 이름이 노드 이름에 없음',sorted(set(miss_old)),60,lvl='err')
put('K11 옛 이름 끝 날짜가 해 범위인데 위키 年表에 정확한 날이 있음',sorted(set(bad_date)),60,lvl='warn')
put('K40 같은 노드·같은 노선 한정·같은 글자 이름 행이 이어 붙음(앞 행 끝 = 뒤 행 시작)',k40,40,lvl='warn')
# 역 문서 연혁의 「信号場に変更」 뒤에도 정차 / 신호장 노드인데 역 문서에 역 개업이 있음
sig=[];sig2=[]
NK=dict(m.execute('select id,kind from node').fetchall())
for t,e in W.items():
    cur=nz(re.sub(r'\s*[（(].*$','',e.get('title') or t));cands=NAMEN.get(cur,set())
    if len(cands)!=1:continue
    x=next(iter(cands))
    for l_ in e.get('hist') or []:
        m_=DT.match(l_)
        if not m_:continue
        d=lohi(wdate(m_))[1]
        if re.search(r'信号場に(?:変更|格下げ|降格)|信号場化',l_) and not re.search(r'隣駅|の信号場化',l_) and d>=BASE and not re.search(r'再び|駅に(?:昇格|変更)|旅客営業を再開',' '.join(e.get('hist') or [])):
            if any(p and p[0]<=d<p[3] and p[3]>datetime.date.fromisoformat(d).replace(year=int(d[:4])+1).isoformat() for p in SPN.get(x,[])):sig.append((t,wdate(m_),x))
        if NK.get(x)=='signal' and re.search(r'駅(?:として)?開業',l_):sig2.append((t,wdate(m_),x))
put('K18 역 문서 「信号場に変更」 뒤에도 정차 기간이 이어짐',sorted(set(sig)),40,lvl='err')
put('K18 신호장 노드인데 역 문서 연혁에 역 개업이 있음',sorted(set(sig2)),40,lvl='warn')
# ---- N05 역 기록 (1950~): 역 ID별 이름·첫 해·사업자
ZN=zipfile.ZipFile(os.path.join(ROOT,'data','imports','n05','N05-24_GML.zip'))
NS=collections.defaultdict(list)
for f in json.loads(ZN.read('UTF-8/N05-24_Station2.geojson'))['features']:
    p=f['properties'];g=f['geometry'];c=g['coordinates']
    c=c[len(c)//2] if g['type']=='LineString' else (c if g['type']=='Point' else c[0][len(c[0])//2])
    NS[p['N05_006']].append(dict(name=p['N05_011'],yb=int(p['N05_005b']),ye=int(p['N05_005e']),op=p['N05_003'],line=p['N05_002'],pt=(c[1],c[0]),y4=int(p['N05_004']) if (p.get('N05_004') or '').isdigit() else None))
NGRID=collections.defaultdict(list)
for i,p in pos.items():NGRID[int(p[0]*50),int(p[1]*50)].append(i)
JRW=re.compile(r'旅客鉄道|国有鉄道|国鉄')
# 옛 회사 이름 → 지금 회사 이름 (hand_tables OPAL, 사명 변경)
OPAL={unicodedata.normalize('NFKC',a):b for a,b in json.load(open(os.path.join(ROOT,'data','overrides','hand_tables.json'),encoding='utf-8'))['tables']['OPAL']['값'].items()}
def opn(s):
    s=unicodedata.normalize('NFKC',s or '');s=OPAL.get(s,s)
    return 'JR' if JRW.search(s) else re.sub(r'株式会社|\(株\)|（株）','',unicodedata.normalize('NFKC',s)).strip()
NOPS=collections.defaultdict(set)
for x,o in m.execute('select e.from_node,a.operator_id from edge e join edge_attr a on a.edge_id=e.id union select e.to_node,a.operator_id from edge e join edge_attr a on a.edge_id=e.id'):NOPS[x].add(o)
OPN=collections.defaultdict(set)
for i,t in n.execute("select entity_id,text from name where entity_type='operator' and lang='ja'"):OPN[i].add(opn(t))
OPC=dict(m.execute('select id,category from operator').fetchall())
def dbops(i):
    """노드 사업자 이름(정규화). 국철·JR은 'JR'"""
    d={'JR'} if any(OPC.get(o)=='jr' or o=='o_japanese_national_railways' for o in NOPS.get(i,())) else set()
    for o in NOPS.get(i,()):d|=OPN.get(o,{o})
    return d
def opok(o,dbo):return any(o==d or (len(o)>=2 and len(d)>=2 and (o in d or d in o or o[:2]==d[:2])) for d in dbo)
def node_for(sid):
    """N05 역 ID → 노드: 그 ID의 어느 이름과 같은 이름(옛 이름·별칭 포함)을 가진 1.5km 안 노드.
    같은 이름 후보가 여럿이면 N05 사업자와 노드 사업자가 맞는 노드가 먼저다(金山 지하철 ID가 JR 노드로, 天空橋 京急 ID가 모노레일 노드로 가던 것, 6회차 2026-11-14)"""
    v=NS[sid];nms={nz(x['name']) for x in v};pt=v[-1]['pt'];o=[];ops={opn(x['op']) for x in v}
    for da in(-1,0,1):
        for db in(-1,0,1):
            for i in NGRID.get((int(pt[0]*50)+da,int(pt[1]*50)+db),()):
                if anames(i)&nms and hav(pos[i],pt)<1.5:o.append((0 if any(opok(q,dbops(i)) for q in ops) else 1,hav(pos[i],pt),i))
    return min(o)[2] if o else None
N2N={sid:node_for(sid) for sid in NS}
# stop_dates.json 키는 「계통|노드」다. 노드 ID로 비교해야 손 근거가 있는 역이 빠진다 (6회차 2026-11-14)
HANDST={k.split('|')[-1] for k in json.load(open(os.path.join(ROOT,'data','overrides','stop_dates.json'),encoding='utf-8')) if not k.startswith('_')}
early=[];nomatch=[];nmiss=[];opbad=[]
NLN=collections.defaultdict(set)
for k,s_ in stops.items():
    for y in s_:NLN[y['node_id']].add(routes[k]['line_id'])
archn={nz(x) for x, in n.execute("select text from name where entity_type='archive' and lang='ja'")}|{nz(x) for x in dropped_ja()}
for sid,v in NS.items():
    x=N2N[sid];yb=min(r['yb'] for r in v);ye=max(r['ye'] for r in v)
    if x is None:
        pt=v[-1]['pt']
        near=[i for da in(-1,0,1) for db in(-1,0,1) for i in NGRID.get((int(pt[0]*50)+da,int(pt[1]*50)+db),()) if hav(pos[i],pt)<.3]
        if ye>=1950 and not near and not {nz(r['name']) for r in v}&archn:nomatch.append((sid,v[-1]['name'],v[-1]['line'],yb,ye))
        continue
    # N05 역 ID는 노선마다 따로다. 그 노드의 어느 계통 정차 시작도 N05 첫 해보다 2년 넘게 이를 때만 본다
    if yb>=1951 and x not in HANDST and len(NLN[x])==1:
        f0=max((p[0] for p in SPN.get(x,[]) if p),default=None)
        if f0 and f0<f'{yb-2}-01-01':early.append((sid,v[-1]['name'],x,yb,f0))
    for r in v:
        if r['ye']>=1950 and nz(r['name']) not in anames(x):nmiss.append((sid,r['name'],r['yb'],r['ye'],x,nn(x)))
put('K18 정차 시작이 N05 첫 해보다 2년 넘게 이름(한 노선 역, 손 근거 없음)',early,40,lvl='warn')
# N05_004(역 개업 해)가 1950년 뒤인데 그 노드 어느 계통의 정차 시작 해와도 1년 넘게 다름
op4=[]
for sid,v in NS.items():
    x=N2N[sid]
    if x is None or x in HANDST:continue
    y4=[r['y4'] for r in v if r['y4']]
    if not y4 or min(y4)<1950:continue
    st=[int(p[0][:4]) for p in SPN.get(x,[]) if p and p[0]>'0000-01-01']
    if st and all(abs(y-min(y4))>1 for y in st):op4.append((sid,v[-1]['name'],x,min(y4),sorted(set(st))[:3]))
put('K18 정차 시작 해가 N05 역 개업 해(1950년 뒤)와 1년 넘게 다름',op4,40,lvl='warn')
# 같은 N05 역 ID의 자리가 1950년 뒤 기록 사이에 150m 넘게 옮겨졌는데 그 노드에 이전 쌍이 없음 (선로 위 km가 바뀐 이전 후보)
mv=[]
MVN={x for r_ in MOVED for x in r_}
for sid,v in NS.items():
    x=N2N[sid]
    if x is None or x in MVN:continue
    w=sorted(v,key=lambda r:r['yb'])
    for p_,q_ in zip(w,w[1:]):
        if q_['yb']>=1951 and hav(p_['pt'],q_['pt'])>.15:
            # 옮기기 전·뒤 기록 점 150m 안에 그 기록 이름을 가진 노드가 서로 다르면 이전이 이미 노드 둘로 있다(近鉄四日市: 諏訪·近畿日本四日市, 千曳: 西千曳·千曳, 6회차 2026-11-14)
            def _at(r):
                return {i for da in(-1,0,1) for db in(-1,0,1) for i in NGRID.get((int(r['pt'][0]*50)+da,int(r['pt'][1]*50)+db),()) if nz(r['name']) in anames(i) and hav(pos[i],r['pt'])<.15}
            A_,B_=_at(p_),_at(q_)
            if A_ and B_ and A_!=B_ and not (A_&B_):break
            mv.append((sid,q_['name'],x,q_['yb'],round(hav(p_['pt'],q_['pt'])*1000)));break
put('K25 N05 같은 역 ID의 자리가 옮겨졌는데 이전 쌍 없음',mv,40,lvl='warn')
put('K28 N05 역 기록(1950년 뒤)에 대응하는 노드·열람 전용 없음',nomatch,60,lvl='warn')
put('K11 N05 같은 역 ID의 1950년 뒤 이름이 노드 이름에 없음',nmiss,60,lvl='warn')
RN05=json.load(open(os.path.join(ROOT,'data','overrides','renames_n05.json'),encoding='utf-8'))
for i,v in RN05.items():
    dbo=dbops(i)
    for r_ in v:
        sid=r_[3] if len(r_)>3 else None
        recs=[z for z in NS.get(sid,[]) if nz(z['name'])==nz(r_[0])]
        for z in recs:
            o=opn(z['op'])
            if dbo and not opok(o,dbo):opbad.append((i,r_[0],z['op'],tuple(sorted(dbo)[:3])))
put('K12 N05 유래 옛 이름의 N05 사업자가 노드 사업자와 다름',sorted(set(opbad)),40,lvl='err')
# 도도부현: station_database의 도도부현 코드(현행·폐역)와 노드 도도부현 (해협 건너 빌려 쓰기 K29)
NPREF=dict(m.execute('select id,pref from node').fetchall())
pb=[]
for s in SD:
    nmz=nz(s['name']);la,lo_=float(s['lat'] or 0),float(s['lng'] or 0)
    if not s.get('prefecture') or not la:continue
    for i in NAMEN.get(nmz,()):
        if i in pos and hav(pos[i],(la,lo_))<.3 and NPREF.get(i) and int(NPREF[i])!=int(s['prefecture']):pb.append((i,nn(i),NPREF[i],s['prefecture']))
put('K29 노드 도도부현이 station_database와 다름',sorted(set(pb)),40,lvl='err')
# ==== 3회차 전수 점검 연결 검사 (W1a, 판 2026-11-15.1) ====
# K69 노면전차 운행 계통표(data/overrides/tram_systems.json, 위키 東京都電車 運転系統表 등)에서 계통이 노선 경계를 넘는 곳에 선로 연결이 없음 (3회차 kanto_1-007)
_TSP=os.path.join(ROOT,'data','overrides','tram_systems.json')
_TS=json.load(open(_TSP,encoding='utf-8'))['rows'] if os.path.exists(_TSP) else []
put('K69 노면전차 운행 계통이 노선 경계를 넘는 곳에 선로 연결 없음',sorted({(x['system'],nn(x['at']),x['at'],ln(x['x']),ln(x['y'])) for x in _TS if (G_(x['at']),x['x'],x['y']) not in TLG}),40,lvl='err')
# K68 이어짐 방향을 선형으로: 이 계통이 끝 역으로 들어오는 칸의 선형 시작 방향과 상대 계통 다음 역 쪽 칸의 시작 방향이 이루는 각(곧게 이어지면 180°)
# ① 상대가 그 역을 지나는데 되돌아가는 쪽(각이 기준각 미만)을 고르고 곧게 이어지는 반대쪽(기준각 이상)은 두지 않음 → 오류(川西能勢口·伊勢若松·都城 같은 방향 오독)
# ② 스위치백형 이어짐(두 노선이 같은 쪽으로 나가 역에서 방향을 바꿈)은 사용자 결정(2026-11-12)으로 이어짐이 맞다 → 확인 목록 (3회차 kinki_3-007)
_GEO={}
for _f in ('n02.yaml','n02_legacy.yaml','n05.yaml'):
    _p=os.path.join(ROOT,'data','source','geometry',_f)
    if os.path.exists(_p):
        for _l in open(_p,encoding='utf-8'):
            if _l.startswith('- '):_g=json.loads(_l[2:]);_GEO[_g['edge']]=_g['coords']
_EN={r[0]:(r[1],r[2]) for r in m.execute('select id,from_node,to_node from edge')}
_REDGE=collections.defaultdict(set)
for r_,e_ in m.execute('select route_id,edge_id from route_edge'):_REDGE[r_].add(e_)
def _gdir(e,x):
    """칸 e를 노드 x에서 나갈 때 시작 방향(300 m, 짧으면 칸의 45%). 선형이 없으면 이웃 노드 좌표"""
    a,b=_EN[e];y=b if a==x else a;cs=_GEO.get(e)
    if cs and len(cs)>=2 and x in pos:
        px=pos[x];rev=(cs[-1][0]-px[1])**2+(cs[-1][1]-px[0])**2<(cs[0][0]-px[1])**2+(cs[0][1]-px[0])**2
        c=cs[::-1] if rev else cs;cl=math.cos(math.radians(c[0][1]))
        mv=lambda p,q:((q[1]-p[1])*111320,(q[0]-p[0])*111320*cl)
        tot=sum(math.hypot(*mv(p,q)) for p,q in zip(c,c[1:]));lim=min(300,.45*tot);acc=0;tg=c[-1]
        for p,q in zip(c,c[1:]):
            l_=math.hypot(*mv(p,q))
            if l_>0 and acc+l_>=lim:f_=(lim-acc)/l_;tg=(p[0]+(q[0]-p[0])*f_,p[1]+(q[1]-p[1])*f_);break
            acc+=l_
        v=mv(c[0],tg)
    elif x in pos and y in pos:v=((pos[y][0]-pos[x][0]),(pos[y][1]-pos[x][1])*math.cos(math.radians(pos[x][0])))
    else:return None
    l_=math.hypot(*v);return (v[0]/l_,v[1]/l_) if l_ else None
def _ang(u,v):
    if not u or not v:return None
    return math.degrees(math.acos(max(-1,min(1,u[0]*v[0]+u[1]*v[1]))))
_THX=json.load(open(os.path.join(ROOT,'data','overrides','hand_tables.json'),encoding='utf-8'))['tables']['THROUGH']['값']
_EXPL={(x['a'],x['b']) for x in _THX if x.get('a_toward') or x.get('b_side')}|{(x['b'],x['a']) for x in _THX if x.get('b_toward') or x.get('a_side')}
_EXPL|={(x['x'],x['y']) for x in _TS if x.get('y_toward')}|{(x['y'],x['x']) for x in _TS if x.get('x_toward')}
_SEQN={(r_['route_id'],r_['seq']):r_['node_id'] for r_ in m.execute('select route_id,seq,node_id from route_stop')}
_ELIFE=collections.defaultdict(list)
for r_ in m.execute("select edge_id,valid_from,valid_to from edge_life where status='open'"):_ELIFE[r_[0]].append(ivl(r_[1],r_[2]))
_EMEM=collections.defaultdict(list)
for r_ in m.execute('select edge_id,line_id,valid_from,valid_to from edge_attr'):_EMEM[r_[0],r_[1]].append(ivl(r_[2],r_[3]))
def _eopen(e,line,d):
    """그날 칸 e가 노선 line 소속으로 영업 중인가"""
    return any(p and p[0]<=d<p[3] for p in _ELIFE.get(e,[])) and any(p and p[0]<=d<p[3] for p in _EMEM.get((e,line),[]))
_RSFB=set()
if os.path.exists(os.path.join(B,'report.json')):
    _RSFB={tuple(x[:3]) for x in json.load(open(os.path.join(B,'report.json'),encoding='utf-8')).get('warnings',{}).get('rside_fallback',[])}
rows1=[];rows2=[]
for k in m.execute("select route_id,seq,other_line_id,other_node,next_stop_node,valid_from,valid_to,other_route_id from route_link where kind='continue'"):
    rid,seq,ol,on_,nx_,vf,vt,orr=k;x=_SEQN.get((rid,seq))
    _p=ivl(vf,vt)
    if not _p:continue
    # 그 이음의 대표 날(끝나지 않았으면 기준일, 끝났으면 끝 전날)에 열린 칸으로만 본다
    d_=AS_OF if vt=='ongoing' else (_p[2] or AS_OF)
    if vt!='ongoing':
        try:d_=(datetime.date.fromisoformat(d_)-datetime.timedelta(days=1)).isoformat()
        except ValueError:pass
    if not x or not nx_ or rid not in routes:continue
    A=routes[rid]['line_id'];m_=on_ or x
    own=[e for e in _REDGE[rid] if x in _EN.get(e,())]
    if len(own)!=1:continue
    vo=_gdir(own[0],x)
    for q in ([orr] if orr else line_routes.get(ol,[])):
        L=[s_['node_id'] for s_ in stops[q]]
        if m_ not in L or nx_ not in L:continue
        i,j=L.index(m_),L.index(nx_);st_=1 if j>i else -1
        ed=[e for e in _REDGE[q] if m_ in _EN.get(e,()) and _eopen(e,ol,d_)]
        def side_e(step):
            for kk in (range(i+1,len(L)) if step>0 else range(i-1,-1,-1)):
                f_=[e for e in ed if L[kk] in _EN[e]]
                if f_:return f_[0]
            return None
        en,ea=side_e(st_),side_e(-st_)
        if not en:continue
        a1=_ang(vo,_gdir(en,m_));a2=_ang(vo,_gdir(ea,m_)) if ea else None
        th=30 if LTY.get(A)==LTY.get(ol)=='tram' else 75
        if a1 is None:break
        # 곧은 반대쪽이 그날 궤간이 맞지 않아 생성기가 되돌아가는 쪽으로 이은 곳(大曲 田沢湖線·新庄 陸羽西線 → 奥羽本線, 秋田·山形新幹線 방향 전환)은 판정된 것이다 (9회차 L)
        if (rid,x,ol) in _RSFB:continue
        if a1<th and a2 is not None and a2>=th and (A,ol) not in _EXPL:rows1.append((rid,nn(x),ln(ol),nn(nx_),round(a1),round(a2),vf,vt))
        elif a1<th and a2 is None:rows2.append((rid,nn(x),ln(ol),nn(nx_),round(a1),vf,vt))
        break
# 확인 목록: 곧게 나가는 방면이 그날 다른 계통(옛 경로 계통 등)에만 있는 곳(内房線 蘇我 1958 전), 화물선 계통의 하루 임시 여객 행이 남는다. 생성기는 같은 계통 안에서는 곧은 쪽을 고른다
put('K68 이어짐이 되돌아가는 방면을 고름(곧게 이어지는 반대쪽이 있음, 선형 각, 확인 목록)',rows1,40,lvl='warn')
put('K68 스위치백형 끝-끝 이어짐(선형 각이 기준 미만, 사용자 결정 2026-11-12로 이어짐, 확인 목록)',rows2,60,lvl='warn')
# 노선에 이어지지 않은 위키 문서(下津井電鉄線·磐梯急行電鉄 등): 문서에 나온 역 이름이 그 노선 역의 60% 이상(3역 이상)이면 그 노선 문서로 본다
LNM=collections.defaultdict(set)
for l,xs in rnodes.items():
    for x in xs:
        if any(p_ for p_ in RSP.get((l,x),())):LNM[l]|={nz(nn(x))}
TOKL=collections.defaultdict(set)
for l,v in LNM.items():
    for y in v:TOKL[y].add(l)
ALLDOC={}
for f_ in sorted(os.listdir(WD)):
    if not f_.endswith('.json.gz'):continue
    d_=json.load(gzip.open(os.path.join(WD,f_),'rt',encoding='utf-8'))
    t_=d_.get('title')
    if not t_ or t_ in LBYT:continue
    wt=d_.get('wikitext') or ''
    tok={nz(z) for z in STN2.findall(wclean(wt))}|{nz(z) for z in re.findall(r'\[\[([^\]|#]+?)(?:駅|停留場)(?:\s*\([^)]*\))?(?:\|[^\]]*)?\]\]',wt)}
    c=collections.Counter(l for y in tok for l in TOKL.get(y,()))
    ls=[l for l,k in c.items() if k>=3 and k>=.6*len(LNM[l])]
    if ls:
        ALLDOC[t_]=wt
        for l in ls:LBYT[t_].add(l)
for t_,wt in ALLDOC.items():_HI[t_]=hist_items(wt)
# ---- 年表 역 사건: 「역 목록 + (が|を)? + 동사」. 구간(A駅 - B駅間)·괄호(現在の…)·（貨）역은 지운다
EVV=r'(?:営業)?(?:再開業?|復活)|新設|開業|開設|設置|廃止|休止|営業停止|営業休止|移転|移設'
EVN=r'(?!\d|発|周年|に伴|の|予定|計画|準備|工事|記念|に向け|を前|日|式|当日|時|後|前|まで|以前|以降|に際|に合わせ|に先立|を機|を控え|が決定|を決定|を申請|が認可|を認可|が許可|を発表|が発表|され?ず|しない|できず)'
SFX=r'(?:臨時乗降場|仮乗降場|仮停車場|仮停留場|臨時駅|駅|停留場|停留所|電停|乗降場)'
TOK=r'(?:駅前|[^\s、。，,・･「」『』（）()：:→＝=　駅停])'
EV1=re.compile(r'((?:'+TOK+r'{1,15}?'+SFX+r'(?:[、・]|および|及び|と|並びに))*'+TOK+r'{1,15}?'+SFX+r')(?:が|を|は|も)?\s*('+EVV+')'+EVN)
EV2=re.compile(r'((?:'+TOK+r'{1,15}[・、])+'+TOK+r'{1,15})の(?:各|両)?(?:駅|停留場|停留所|電停)(?:が|を|は|も)?\s*('+EVV+')'+EVN)
def resolve(tok,tn):
    """글 토막이 노드 이름이면 (이름, 노드). 앞에 조사로 끝나는 말이 붙었으면(「同年中に児島」「を統合し大泉」) 떼어 본다. 접두만 다른 이름(東浅川→浅川)은 떼지 않는다"""
    tok=re.sub(r'^(?:および|及び|並びに|また|さらに|同時に|うち|新設の|休止中の|現在の)','',tok)
    x=tn.get(nz(tok))
    if x:return tok,x
    for i in range(1,len(tok)-1):
        if tok[i-1] in 'にがをはでへともしての、' and (x:=tn.get(nz(tok[i:]))):return tok[i:],x
    return None
PROMO=re.compile(r'(?:信号場|信号所|仮停車場|仮乗降場|臨時乗降場|臨時駅|（臨）|\(臨\)).{0,12}(?:を|が)(?:正式な)?(?:駅|常設駅)(?:に|と)|駅に(?:昇格|格上げ|改める|改め)|常設駅|正式な駅|(?:を|が)駅に変更')
SELF=re.compile(r'^\s*(?:当駅|本駅|駅)?(?:が|を|は)?\s*(?:旅客駅として|駅として)?('+EVV+')'+EVN)
def stn_events(items,tn,self_x=None,self_nm=None):
    out=[]
    for d,t,_ in items:
        if not d:continue
        t=re.sub(r'[（(]貨[）)]\s*'+TOK+r'+?駅','',t)
        for s in t.split('。'):
            if re.search(r'休止中|休止して|休止され|貨物駅|貨物取扱|貨物営業|旅客営業を?廃止|荷物|案|計画|予定|構想|検討|要望|周年',s):continue
            promo=bool(PROMO.search(s))
            s2=sect_cut(s)
            got=[]
            for m2 in EV2.finditer(s2):
                for z in re.split(r'[・、]',m2.group(1)):got.append((z,'',m2.group(2)))
            for m2 in EV1.finditer(s2):
                for z in re.split(r'[、・]|および|及び|と|並びに',m2.group(1)):
                    q=re.match(r'^(.+?)('+SFX+r')$',z)
                    if q:got.append((q.group(1),q.group(2),m2.group(2)))
            if self_x and (q:=SELF.match(s2)):got.append((self_nm,'駅',q.group(1)))
            seen=set()
            for z,sfx,v in got:
                if re.search(r'貨物|信号|操車|分岐|臨時$|仮$',z):continue
                rr=resolve(z,tn)
                if not rr or (rr[1],v) in seen:continue
                # 같은 문장에 같은 이름이 둘이면(「旧X停留場を廃止し、Y停留場をX停留場に改称」) 어느 노드인지 모른다
                if '改称' in s and s.count(rr[0])>1:continue
                # 「X駅（2代目）」처럼 대수 표시가 붙은 이름은 같은 이름 다른 역일 수 있다
                if re.search(re.escape(rr[0])+SFX+r'?\s*[（(](?:初代|[0-9０-９一二三]代目?)',s):continue
                seen.add((rr[1],v))
                out.append((d,rr[0],rr[1],sfx,'昇格' if promo and re.match('新設|開業|開設|設置',v) else v,s.strip()[:60]))
    return out
DAY=datetime.timedelta(days=1)
def dnear(d,lo,hi,tol=1):
    """위키 날짜 d가 DB 날짜 [lo,hi]와 tol일 안에서 맞물리는가. 「…年までに」(아래 끝 없음)는 그 해까지 6년 안"""
    a,b=dlo(d)
    if a is None or lo is None or lo.startswith('0000') or hi.startswith('9999'):return False
    if a.startswith('0000'):a=f'{int(b[:4])-6}-01-01'
    if b.startswith('9999'):b=f'{int(a[:4])+6}-12-31'
    try:lo_=(datetime.date.fromisoformat(lo)-tol*DAY).isoformat();hi_=(datetime.date.fromisoformat(hi)+tol*DAY).isoformat()
    except ValueError:lo_,hi_=lo,hi
    return a<=hi_ and lo_<=b
def dyear(d):
    return int(re.search(r'\d{4}',d).group(0))
SMK=collections.defaultdict(list)
for x,l,k,f_,t_ in n.execute('select node_id,line_id,kind,valid_from,valid_to from stop_mark'):SMK[x].append((k,f_,t_))
if n.execute("select 1 from sqlite_master where name='stop_mark_route'").fetchone():
    for x,l,k,f_,t_ in n.execute('select node_id,line_id,kind,valid_from,valid_to from stop_mark_route'):SMK[x].append((k,f_,t_))
NPER=collections.defaultdict(list);NGAP=collections.defaultdict(list)
for (l_,y),v_ in RSP.items():NPER[y]+=v_
for (l_,y),v_ in GAPS.items():NGAP[y]+=v_
PREFN='北海道 青森県 岩手県 宮城県 秋田県 山形県 福島県 茨城県 栃木県 群馬県 埼玉県 千葉県 東京都 神奈川県 新潟県 富山県 石川県 福井県 山梨県 長野県 岐阜県 静岡県 愛知県 三重県 滋賀県 京都府 大阪府 兵庫県 奈良県 和歌山県 鳥取県 島根県 岡山県 広島県 山口県 徳島県 香川県 愛媛県 高知県 福岡県 佐賀県 長崎県 熊本県 大分県 宮崎県 鹿児島県 沖縄県'.split()
def wdoc_ok(e,x):
    """역 문서가 그 노드의 역인가: 주소에 노드 도도부현이 있고 사업자가 맞음(같은 이름 다른 지방·외지 역 문서를 거름)"""
    bl=e.get('blocks') or []
    if not bl:return False
    pf=NPREF.get(x);pn=PREFN[int(pf)-1] if pf and str(pf).isdigit() and 1<=int(pf)<=47 else None
    if not pn or not any(pn in (b.get('addr') or '') or pn[:-1] in (b.get('addr') or '')[:4] for b in bl):return False
    ops={opn(re.sub(r'[（(].*?[）)]','',b.get('ops') or '')) for b in bl if b.get('ops')}
    return not ops or not dbops(x) or any(opok(o,dbops(x)) for o in ops)
DOCS=[]   # (출처, 年表 줄, 이름→노드, 역 문서이면 그 노드)
for title in sorted(LBYT):DOCS.append((title,_HI[title] if title in _HI else hist_of(title),title_nodes(title),None))
for t,e in W.items():
    h=e.get('hist') or []
    if not h:continue
    cur=nz(re.sub(r'\s*[（(].*$','',e.get('title') or t));cands=NAMEN.get(cur,set())
    if len(cands)!=1:continue
    x=next(iter(cands))
    if not wdoc_ok(e,x):continue
    DOCS.append((t,hist_items('\n'.join('* '+z for z in h),sec=None),{y:x for y in anames(x)},(x,cur)))
EVS=[]   # (출처, 날짜, 이름, 노드, 접미, 동사, 글, 기간 목록, 공백 목록). 기간은 그 노드의 모든 계통(사업자 바뀜 승계 노선 포함)
for src,it,tn,sx in DOCS:
    for d,nm,x,sfx,v,s in stn_events(it,tn,*(sx or (None,None))):
        # 역 문서의 폐지 줄은 같은 자리 다른 시설(「X駅前停留場廃止」·町営軌道 停留所)일 때가 많아 쓰지 않는다
        if sx and v=='廃止':continue
        EVS.append((src,d,nm,x,sfx,v,s,NPER[x],NGAP[x]))
# 年表 역 사건 날짜와 정차 기간: 開業·新設 ↔ 정차 시작(chubu_3-06), 廃止 ↔ 정차 끝, 再開·営業再開·復活 ↔ 정차 시작·공백 끝(chugoku_shikoku_1-015 (1)·kinki_1-12)
KARI_SFX=re.compile('仮|臨時')
k43o=[];k43c=[];k45=[];k50a=[]
for src,d,nm,x,sfx,v,s,P,G in EVS:
    if not P or not d or dyear(d)<1950:continue
    starts=[(p[0],p[1]) for p in P]+[(g[2],g[3]) for g in G]
    ends=[(p[2],p[3]) for p in P]+[(g[0],g[1]) for g in G]
    if KARI_SFX.search(sfx) and re.match('新設|開業|開設|設置',v):
        # 年表 仮停車場·仮乗降場 新設 날짜가 정차 시작보다 이름 (kyushu_1-012 (1))
        if not any(dnear(d,a,b) for a,b in starts) and min(a for a,b in starts)>dlo(d)[1]:k50a.append((src,d,nm+sfx,x,sorted({p[0] for p in P})[:3]))
        continue
    if v=='昇格':continue
    if re.match('新設|開業|開設|設置',v):
        if not any(dnear(d,a,b) for a,b in starts):k43o.append((src,d,nm,v,x,sorted({p[0] for p in P})[:3],s))
    elif v=='廃止':
        # DB가 위키 폐지일 뒤에도 정차를 이어 갈 때만 (폐지 전 휴지·마지막 운행 소급 종료는 DB가 더 이르다)
        if KARI_SFX.search(sfx) and not SMK.get(x):continue
        if not any(dnear(d,a,b) for a,b in ends) and any(p[0]<dlo(d)[0] and p[3]>dlo(d)[1] for p in P):k43c.append((src,d,nm,v,x,sorted({p[2] for p in P})[:3],s))
    elif re.search('再開|復活',v):
        if not any(dnear(d,a,b) for a,b in starts):k45.append((src,d,nm,v,x,sorted({p[0] for p in P})[:3],s))
# 年表 「仮停車場·仮乗降場·臨時駅·信号場を駅に改める/昇格/変更」: 그 전부터 정차했으면 그날 끝나는 임시역 표식이 있어야 한다 (kyushu_1-012 (2))
PRM=re.compile(r'(?:[（(](?:臨|仮)[）)])?('+TOK+r'{1,15}?)(仮停車場|仮乗降場|臨時乗降場|臨時駅|信号場|信号所|駅)(?:[（(][^）)]*[）)])?(?:が|を|は)(?:正式な|常設の?)?(?:駅|常設駅)(?:に|と)(?:改める|改め|昇格|格上げ|変更|し|なる|なり)')
k50b=[]
for src,it,tn,sx in DOCS:
    for d,t,_ in it:
        if not d or dyear(d)<1950:continue
        for q in PRM.finditer(t):
            if q.group(2)=='駅' and not re.search(r'[（(](?:臨|仮)[）)]$',t[:q.start(1)]):continue
            rr=resolve(q.group(1),tn)
            if not rr:continue
            x=rr[1];P=(per_of(src,x) if not sx else None) or NPER[x]
            if not P or not any(p[0]<dlo(d)[0] for p in P):continue
            mk=[z for z in SMK.get(x,()) if z[0] in('kari','rinji')]
            if not any(dnear(d,*dlo(z[2])) for z in mk if z[2]):k50b.append((src,d,rr[0]+q.group(2),x,sorted({p[0] for p in P})[:2],tuple(sorted(mk))[:2]))
def _dd(rows):
    o={}
    for r_ in rows:o.setdefault((next(z for z in r_ if isinstance(z,str) and z.startswith('n_')),r_[1]),r_)
    return list(o.values())

# 年表 「X駅での旅客扱いはなし」「当駅は通過扱い」「全列車が通過」인 날에 정차 기간이 걸침 (kanto_2-020)
NOPAX=re.compile(r'(?:('+TOK+r'{1,15}?)'+SFX+r'|当駅|本駅)(?:で|での|では|には|は|を)?(?:の)?(?:旅客(?:の)?(?:取り?)?扱い(?:は)?(?:なし|無し|を?行わ|しない|はない)|(?:全列車が?|全ての列車が?)?通過扱い|全列車が?通過|全ての列車が?通過)')
k49=[]
for src,it,tn,sx in DOCS:
    for d,t,_ in it:
        if not d:continue
        for q in NOPAX.finditer(t):
            if q.group(1):rr=resolve(q.group(1),tn)
            elif sx:rr=(sx[1],sx[0])
            else:continue
            if not rr:continue
            x=rr[1];P=(per_of(src,x) if not sx else None) or NPER[x];a,b=dlo(d)
            # 「通過扱い」는 일부 열차·임시 운전 이야기일 때가 많다: 그런 글은 뺀다
            if '通過' in q.group(0) and re.search(r'一部|特急|快速|急行|ダイヤ|臨時|一時|期間|工事|運転を実施|改正|列車において|のみ',t):continue
            if a and any(p[0]<=b and p[3]>a for p in P):k49.append((src,d,rr[0],x,sorted({(p[0],p[2]) for p in P if p[0]<=b and p[3]>a})[:2],t[max(0,q.start()-20):q.end()][:50]))
k49=_dd(k49)
# 年表 「移転」과 「km短縮·km延長·m移転」이 한 줄인 역에 이전 쌍(node_move)이 없음 (chugoku_shikoku_2-025)
KMV=re.compile(r'(?:\d+(?:\.\d+)?\s*(?:km|ｋｍ|キロ(?:メートル)?)\s*(?:短縮|延長|延伸))|(?:\d+(?:\.\d+)?\s*(?:m|ｍ|メートル|km|キロ)[^。]{0,12}?(?:移転|移設))|営業キロ[^。]{0,20}変更')
k48=[]
for src,d,nm,x,sfx,v,s,P,G in EVS:
    if v not in('移転','移設') or not d or dyear(d)<1950 or x in MVN:continue
    if not KMV.search(s):continue
    k48.append((src,d,nm,x,s[:50]))
# 같은 줄 다음 문장(「同年中に児島駅移転、0.2km短縮」은 한 문장이지만 「…移転。営業キロを…に変更」은 둘)도 본다
for src,it,tn,sx in DOCS:
    for d,t,_ in it:
        if not d or dyear(d)<1950 or not KMV.search(t) or not re.search('移転|移設',t):continue
        for d2,nm,x,sfx,v,s in stn_events([(d,t,1)],tn,*(sx or (None,None))):
            if v in('移転','移設') and x not in MVN:k48.append((src,d,nm,x,t[:50]))
k48=_dd(k48)
# 年表 「A駅 - B駅間で運転を再開」: 그 구간 칸이 DB에서는 그날 뒤에도 운휴(suspended)로 남음 (tohoku_1-030 (3))
SUSP=collections.defaultdict(list)
for e_,f_,t_ in m.execute("select edge_id,valid_from,valid_to from edge_life where status='suspended'"):
    v=ivl(f_,t_)
    if v:SUSP[e_].append(v)
RSEC=re.compile(r'('+TOK+r'{1,15}?)(?:駅|停留場)?\s*[-－–―〜~～]\s*('+TOK+r'{1,15}?)(?:駅|停留場)?間(?:で|の|が|を)?(?:は)?(?:列車の)?(?:運転|運行|営業|折り返し運転)(?:を|が)?(?:再開|復旧)')
def sec_edges(title,a,b):
    """문서 노선 계통에서 두 역 사이 칸들 (계통마다 따로, 가장 짧은 것)"""
    best=None
    for l in tlines(title):
        for k in line_routes[l]:
            s_=stops[k];ia=[i for i,y in enumerate(s_) if a in anames(y['node_id'])];ib=[i for i,y in enumerate(s_) if b in anames(y['node_id'])]
            for i in ia:
                for j in ib:
                    if i==j:continue
                    seg=[e['edge_id'] for e in E_[k]][min(i,j):max(i,j)]
                    if seg and (best is None or len(seg)<len(best)):best=seg
    return best or []
k52=[]
for src,it,tn,sx in DOCS:
    if sx:continue
    for d,t,_ in it:
        if not d or 'X' in d or dyear(d)<1950:continue
        for q in RSEC.finditer(t):
            a,b=nz(q.group(1)),nz(q.group(2))
            seg=sec_edges(src,a,b)
            if not seg:continue
            # DB가 그날 뒤에도 운휴로 두는 칸 (운휴 시작이 재개일보다 이르고 끝이 재개일 다음 날보다 늦음)
            late=[e for e in seg if any(p[0]<d and p[3]>(datetime.date.fromisoformat(d)+DAY).isoformat() for p in SUSP.get(e,()))]
            if late:k52.append((src,d,q.group(1),q.group(2),tuple(tlines(src)[:2]),tuple(late[:3]),tuple(sorted({p[2] for e in late for p in SUSP[e]})[:2])))
# 年表 「A駅 - B駅間を(が)C에 譲渡·移管」: 그 구간 칸의 edge_attr에 그날 바뀌는 경계가 없음 (chubu_3-08)
RTR=re.compile(r'('+TOK+r'{1,15}?)(?:駅|停留場)?\s*[-－–―〜~～]\s*(?:'+TOK+r'{1,15}?(?:駅|停留場)?\s*[-－–―〜~～]\s*)?('+TOK+r'{1,15}?)(?:駅|停留場)?間?(?:の(?:鉄道|軌道)?(?:事業)?)?(?:が|を|は)[^。]{0,40}?(?:譲渡|移管|譲受|継承|承継)')
ATB=collections.defaultdict(set)
for e_,f_,t_ in m.execute('select edge_id,valid_from,valid_to from edge_attr union all select edge_id,valid_from,valid_to from edge_life'):
    for z in (f_,t_):
        if z and z!=ON:ATB[e_].add(z)
k44=[]
for src,it,tn,sx in DOCS:
    if sx:continue
    for d,t,_ in it:
        # 국철·JR 안 관리 이관(鉄道管理局·支社·指令), 시설만 넘기는 鉄道・運輸機構·公団 譲渡는 사업자 바뀜이 아니다
        if not d or dyear(d)<1950 or re.search(r'予定|計画|申請|許可|認可|免許|鉄道管理局|支社|指令|本部|管理所|地域本社|鉄道部|CTC|運行管理|運輸機構|鉄道建設|公団|専用線',t):continue
        t=re.sub(r'[（(][^（）()]*[）)]','',t)
        for q in RTR.finditer(t):
            a,b=nz(q.group(1)),nz(q.group(2))
            seg=sec_edges(src,a,b)
            if not seg:continue
            if not any(dnear(d,*dlo(z)) for e in seg for z in ATB.get(e,()) if dlo(z)[0]):k44.append((src,d,q.group(1),q.group(2),tuple(tlines(src)[:2]),tuple(seg[:2]),t[max(0,q.end()-30):q.end()+10]))
# 年表 社名変更: 회사 이름이 노선 이름에 들어 있는 노선(磐梯急行電鉄線·福島臨海鉄道本線)인데 그날 line_period 이름 행 경계가 없음 (tohoku_1-031 (6)·tohoku_1-014)
CO=[re.compile(r'([^\s、。「」『』（）()：:]{2,20}?)(?:に|へ)(?:再度)?(?:社名|名称|商号)(?:を)?(?:変更|改称|改め)'),re.compile(r'(?:社名|商号|名称)(?:を|が)([^\s、。「」『』（）()：:]{2,20}?)(?:に|へ)(?:変更|改称|改め)'),re.compile(r'([^\s、。「」『』（）()：:駅]{2,20}?(?:鉄道|電鉄|軌道|交通|鉄道部|電気鉄道|電軌|鉱業))(?:株式会社)?(?:に|へ)(?:改称|商号変更|社名変更)')]
LPN=collections.defaultdict(list)
for l_,nm_,f_,t_ in m.execute("select line_id,name_ja,valid_from,valid_to from line_period where kind='name'"):LPN[l_].append((nm_,f_,t_))
def costem(c):return re.sub(r'株式会社|（株）|\(株\)','',unicodedata.normalize('NFKC',c)).strip()
k53=[]
for src,it,tn,sx in DOCS:
    if sx:continue
    ev=[]
    for d,t,_ in it:
        # 다른 회사(버스 회사 등)가 주어인 글(「宮城中央バスが…社名が宮城交通に変更」)은 노선 회사의 개칭이 아니다
        if not d or re.match(r'^[^、。]{1,15}バス(?:が|は)',t):continue
        for P_ in CO:
            for q in P_.finditer(t):
                c=costem(re.sub(r'^.*(?:(?<=[一-龥ァ-ヶー）)])(?:を|が|は|に)|して|し、|から|中に|により|に伴い、?|ため、?|、)','',q.group(1)))
                if len(c)>=2 and not re.search(r'駅|停留場|線$',c):ev.append((d,c))
    if not ev:continue
    chain={c for _,c in ev}
    for l in tlines(src):
        lend=max((z for z, in m.execute('select a.valid_to from edge_attr a where a.line_id=?',(l,)) if z),default=ON)
        lbeg=min((z for z, in m.execute('select a.valid_from from edge_attr a where a.line_id=?',(l,)) if z),default='0000-01-01')
        lnames=set(ja['line',l])|{z[0] for z in LPN[l] if z[0]}
        if not any(c in x_ for c in chain for x_ in lnames):continue
        for d,c in ev:
            if dyear(d)<1950 or (lend!=ON and dlo(d)[0]>=lohi(lend)[1]) or dlo(d)[1]<lohi(lbeg)[0]:continue
            if not any(dnear(d,*dlo(z)) for _,f_,t_ in LPN[l] for z in (f_,t_) if z and z!=ON and dlo(z)[0]):k53.append((src,d,c,l,ln(l)))
k53=sorted({(r_[1],r_[3]):r_ for r_ in k53}.values())

# 노선 문서 廃駅 절·노선도 행의 1949년까지 폐역(휴지 포함)이 열람 전용·노드 이름 어디에도 없음 (chubu_1-022 ①)
k41=[]
for title in sorted({LDOC[l]['title'] for l in LDOC}):
    tn=title_nodes(title);al=set().union(*[arch_l[q] for q in tlines(title)])|arch_l[None]
    def _have(nmz):
        nmz=re.sub(r'(?:仮|臨時)$','',nmz)
        return nmz in tn or nmz in al or nmz in archn or re.search(r'方面|以下|の$',nmz)
    wt=LDOC[next(iter(tlines(title)))]['wikitext'] if tlines(title) and LDOC.get(next(iter(tlines(title)))) else (doc(title) or {}).get('wikitext') or ''
    seen_=set()
    for it_d,t,_ in hist_items(wt,sec=re.compile(r'廃(?:駅|止駅|停留場|止停留場)')):
        mm=re.match(r'^\s*(?:[（(]臨[）)])?('+TOK+r'{1,15}?)'+SFX+r'(?:[（(][^）)]*[）)])?\s*(?:[（(][A-Z]{0,3}\d+[）)])?\s*[:：]?(.*)$',t)
        if not mm or re.search(r'貨|信号',t[:mm.end(1)+6]) :continue
        ys=[int(y) for y,v_ in re.findall(r'(\d{4})年[^、。]{0,12}?(休止|廃止|営業停止)',mm.group(2))]
        if not ys or min(ys)>1949:continue
        nmz=nz(mm.group(1))
        if nmz in seen_ or _have(nmz):continue
        seen_.add(nmz);k41.append((title,mm.group(1),min(ys),'廃駅',tlines(title)[:2]))
    for l in tlines(title):
        for r in rows_of(l):
            icons=[z for c in r['c'] for z in c]
            t0=row_head(r['t'])
            m_=RW28.match(t0)
            if not m_ or NOSTN.search(r['t']):continue
            cy=close_year(m_.group(2))
            if not cy or cy>1949:continue
            if not any(re.match(r'^(ex|e[A-Z]|x[A-Z]|uex|ke)',z) and re.search('BHF|HST',z) for z in icons):continue
            nmz=nz(m_.group(1))
            if nmz in seen_ or _have(nmz):continue
            seen_.add(nmz);k41.append((title,m_.group(1),cy,'노선도',[l]))
# 노선도에 같은 역 이름이 표시 없이 다른 km(0.1 넘게)로 두 번, 한쪽에 1950년 뒤 끝 해가 있는데 이전 쌍 없음 (chubu_1-022 ②, K25 넓힘)
k25w=[]
for title in sorted({LDOC[l]['title'] for l in LDOC}):
    by=collections.defaultdict(list)
    for r in rows_of(next(iter(tlines(title)))) if tlines(title) else []:
        t0=row_head(r['t'])
        m_=RW28.match(t0);ks=KMN.findall(r['k'] or '')
        if not m_ or not ks or re.search(r'[（(](?:\d|I{1,3}|IV|旧|初代|[0-9一二三]代目?)[)）]',r['t']) or NOSTN.search(r['t']):continue
        by[nz(m_.group(1))].append((float(ks[-1]),close_year(m_.group(2)),r['t'][:30]))
    tn=title_nodes(title)
    for nmz,v in by.items():
        if len(v)<2 or max(k for k,_,_ in v)-min(k for k,_,_ in v)<.1 or not any(c and c>=1950 for _,c,_ in v):continue
        # 끝 해 없는 행이 하나뿐(현행 자리)이고 끝 해 있는 행이 옛 자리여야 이전이다
        if sum(1 for _,c,_ in v if not c)>1:continue
        xs=sorted({x for l in tlines(title) for x in rnodes[l] if nmz in anames(x)})
        if not xs or any(frozenset((a,b)) in MOVED for a in xs for b in xs if a!=b):continue
        k25w.append((title,nmz,[t for _,_,t in v][:3],xs[:3]))
# 年表 「下り…新線経由、上り…旧線経由」: 한 방향만 다른 선로를 쓴 기간인데 그 노선에 한 방향 칸(edge_one_way)이 없음 (chubu_1-022 ③)
OWX=re.compile(r'(上り|下り)[^。]{0,40}?(?:新線|旧線|[^。、]{1,12}経由)[^。]{0,8}?、?\s*(上り|下り)[^。]{0,40}?(?:新線|旧線|経由)')
OWR=collections.defaultdict(list)
for r_,f_,t_ in m.execute('select route_id,valid_from,valid_to from edge_one_way'):
    v=ivl(f_,t_)
    if v:OWR[routes[r_]['line_id']].append(v)
k42=[]
for src,it,tn,sx in DOCS:
    if sx:continue
    for d,t,_ in it:
        if not d or dyear(d)<1950:continue
        for s in t.split('。'):
            q=OWX.search(s)
            if not q or q.group(1)==q.group(2):continue
            a,b=dlo(d)
            if not any(p[0]<=b and p[3]>a for l in tlines(src) for p in OWR.get(l,())):k42.append((src,d,tlines(src)[:3],s[:60]))
# N05 첫 해(1950 바닥 제외)가 그 노드 정차 시작 해보다 이르고 같은 이름·60m 안: 정차 시작이 늦게 잡힘 (kyushu_1-012 (3))
k50c=[]
for sid,v in NS.items():
    x=N2N[sid]
    if x is None or not NPER.get(x):continue
    f0=min(p[0] for p in NPER[x])
    if f0.startswith('0000'):continue
    for r in sorted(v,key=lambda r:r['yb']):
        if 1950<r['yb']<int(f0[:4]) and nz(r['name']) in anames(x) and hav(pos[x],r['pt'])<.06 and (not dbops(x) or opok(opn(r['op']),dbops(x))):
            k50c.append((sid,r['name'],r['yb'],x,f0));break
# 같은 사업자 안 km 출처 섞임: 사업자 공식 키로를 km_fix로 쓴 노선이 있는 사업자의 다른 노선에서 위키 노선도 간격과 DB(=노리츠부시) 간격이 다름 (chugoku_shikoku_1-015 (3))
LOPS=collections.defaultdict(set)
for l_,o_ in m.execute('select distinct line_id,operator_id from edge_attr'):LOPS[l_].add(o_)
KFL=set()
for x_ in json.load(open(os.path.join(ROOT,'data','overrides','km_fix.json'),encoding='utf-8')):
    KFL|=NLN.get(x_.get('a'),set())&NLN.get(x_.get('b'),set())
KFO={o for l in KFL for o in LOPS[l] if OPC.get(o)!='jr' and o!='o_japanese_national_railways'}
k47=[]
for l in sorted(LDOC):
    if l in KFL or not (LOPS[l]&KFO):continue
    seen=[]
    nm2n=nmap(l)
    for r in rows_of(l):
        x=row_node(l,r,nm2n);ks=KMN.findall(r['k'] or '')
        if x and ks:seen.append((x,float(ks[-1])))
    main=[k for k in line_routes[l] if routes[k]['role']=='main']
    if not main:continue
    s=[y for y in stops[main[0]] if y['is_stop'] and y['valid_to']==ON];at={y['node_id']:y['km_cum'] for y in s};idx={y['node_id']:i for i,y in enumerate(s)}
    sv=[(x,k) for x,k in seen if x in at]
    for (a,ka),(b,kb) in zip(sv,sv[1:]):
        if abs(idx[a]-idx[b])!=1:continue
        dw=round(abs(kb-ka),1);dd=round(abs(at[b]-at[a]),1)
        if abs(dw-dd)<.1 or abs(dw-dd)>=2:continue
        nbv={v for p in anames(a) for q in anames(b) for v in NB_I.get(frozenset((p,q)),())}
        if any(abs(v-dd)<=.05 for v in nbv):k47.append((ln(l),nn(a),nn(b),dw,dd,a,b,sorted(LOPS[l]&KFO)[:1]))

put('K25 위키 노선도에 같은 역 이름이 표시 없이 다른 km로 두 번(1950년 뒤 끝 해)인데 이전 쌍 없음',k25w,40,lvl='warn')
put('K41 위키 노선 문서 廃駅 절·노선도의 1949년까지 폐역(휴지 포함)이 열람 전용·노드 이름에 없음',k41,60,lvl='warn')
put('K42 위키 年表 「下り…新線経由、上り…旧線経由」인데 그 노선에 한 방향 칸(edge_one_way) 없음',k42,40,lvl='warn')
put('K43 위키 年表 역 開業·新設(1950년 뒤) 날짜가 그 노드 정차 시작·공백 끝에 없음',_dd(k43o),60,lvl='warn')
put('K43 위키 年表 역 廃止(1950년 뒤) 날짜 뒤에도 정차가 이어짐',_dd(k43c),40,lvl='warn')
put('K44 위키 年表 구간 譲渡·移管(1950년 뒤) 날짜에 그 구간 칸 사업자·수명 경계가 없음',sorted({r_[:6]:r_ for r_ in k44}.values()),40,lvl='warn')
put('K45 위키 年表 역 再開·営業再開·復活(1950년 뒤) 날짜가 정차 시작·공백 끝에 없음',_dd(k45),60,lvl='warn')
put('K46 km_fix(사업자 공식 키로) 노선이 있는 사업자의 다른 노선에서 위키 노선도 간격과 DB(=노리츠부시) 간격이 다름',k47,40,lvl='warn')
put('K47 위키 年表 「移転」과 「km短縮·延長·m移転」이 한 줄인 역에 이전 쌍(node_move) 없음',k48,40,lvl='warn')
put('K48 위키 年表 「旅客扱いなし」·「通過扱い」인 날에 그 역 정차 기간이 걸침',k49,40,lvl='warn')
put('K49 위키 年表 仮停車場·仮乗降場 新設(1950년 뒤) 날짜가 정차 시작보다 이름',_dd(k50a),40,lvl='warn')
put('K49 위키 年表 仮·臨·信号場를 駅に改める·昇格한 날(1950년 뒤)에 끝나는 임시역 표식이 없음(그 전부터 정차)',_dd(k50b),40,lvl='warn')
put('K49 N05 첫 해(1950 바닥 제외)가 정차 시작 해보다 이르고 같은 이름·같은 사업자·60m 안',k50c,40,lvl='warn')
put('K50 위키 年表 「…間で運転を再開」 날 뒤에도 그 구간 칸이 운휴(suspended)로 남음',sorted(set(k52)),40,lvl='warn')
put('K51 위키 年表 社名変更(1950년 뒤)인데 회사 이름이 든 노선의 line_period 이름 행 경계가 없음',k53,60,lvl='warn')
# ---- 9회차 M: 빠진 역·구간 전수 대조 (K100–K102). K28 두 목록과 위키 노선도의 연도 없는 폐역 행을 수록 규칙·판정표로 걸러 남는 것만 낸다
# 판정표는 data/overrides/missing_reviewed.json(사람이 근거를 보고 정한 것: 정상 사유·화물·근거 부족). 규칙(DESIGN §4.1·§4.4)은 여기서 둔다
MR=json.load(open(os.path.join(ROOT,'data','overrides','missing_reviewed.json'),encoding='utf-8'))
# 수록 안 함 규칙: 홋카이도 簡易軌道(町営·村営軌道)는 철도사업법·궤도법 근거가 없다 (DESIGN §4.1), 무궤조전차(트롤리버스)는 궤도가 없다 (DESIGN §4.4)
M_KANI=re.compile(r'簡易軌道|町営軌道|村営軌道')
M_TROL=re.compile(r'トロリーバス|無軌条')
# 이름이 여객역이 아닌 꼴: 보선 요원 乗降場(線路班)·신호소·화물 취급소
M_NOPAX=re.compile(r'線路班|信号所|信号場|荷扱所')
def m_nz2(s):
    """N05·노선도 이름과 노드 이름의 표기 차이를 더 넓게 맞춘다: 乗降場 꼬리, 糖/糠·趾/址·鉤/鈎, 町目/丁目, の(ノ) 빠짐"""
    s=nz(s);s=re.sub(r'(?:臨時乗降場|仮乗降場|乗降場)$','',s)
    for a,b in (('糖','糠'),('趾','址'),('鉤','鈎'),('町目','丁目')):s=s.replace(a,b)
    return s.replace('ノ','')
M_N2={}
for i_ in pos:
    for x_ in anames(i_):M_N2.setdefault(m_nz2(x_),set()).add(i_)
def m_samename(names_,pt,km=3.0):
    """같은 이름(넓은 표기 맞춤, 「…前」 붙음 포함) 노드가 km 안에 있으면 그 노드"""
    ks={m_nz2(x) for x in names_};ks|={k+'前' for k in ks}|{k[:-1] for k in ks if k.endswith('前')}
    for k in ks:
        for i_ in M_N2.get(k,()):
            if hav(pos[i_],pt)<km:return i_
    return None
# 열람 전용 노선이 덮는 N05 역: 열람 전용 노선 이름 핵심(끝 「線」 뗌)이 N05 사업자+노선 이름에 들고, 다는 역(at)이 있으면 40km 안, 없으면 핵심이 세 글자 넘거나 판정표에 노선 짝이 있을 때
M_ARL=[]
for i_,at_ in m.execute('select id,at_node from archive_line'):
    for x_, in n.execute("select text from name where entity_type='archive' and entity_id=? and lang='ja'",(i_,)):
        c_=re.sub(r'線$','',nz(x_))
        if len(c_)>=2:M_ARL.append((i_,c_,pos.get(at_) if at_ else None))
def m_archline(v):
    s_={nz(r['op'])+nz(r['line']) for r in v};pt=v[-1]['pt']
    for i_,c_,ap in M_ARL:
        if not any(c_ in t for t in s_):continue
        if ap is not None:
            if hav(ap,pt)<40:return i_
        elif len(c_)>=3:return i_
    for r in v:
        if MR['archive_line_map'].get(r['op']+'|'+r['line']) in {a for a,_,_ in M_ARL}:return MR['archive_line_map'][r['op']+'|'+r['line']]
    return None
def m_rule(sid,v):
    """N05 역 ID의 규칙 판정. (갈래, 사유) 또는 None"""
    pt=v[-1]['pt']
    if any(M_KANI.search(r['op']+r['line']) for r in v) and pt[0]>41.3:return ('수록 밖','홋카이도 簡易軌道(DESIGN §4.1)')
    if any(M_TROL.search(r['line']) or (r['op']=='東京都' and re.match(r'^\d+系統$',r['line'])) for r in v):return ('수록 밖','무궤조전차(DESIGN §4.4)')
    for r in v:
        t_=MR['trolleybus'].get(r['op']+'|'+r['line'])
        if t_ and r['yb']>=t_['from']:return ('수록 밖','무궤조전차(DESIGN §4.4): '+t_['why'][:40])
    if all(M_NOPAX.search(r['name']) for r in v):return ('정상','여객역 아님(線路班·信号所·荷扱所)')
    a_=m_archline(v)
    if a_:return ('열람 전용','열람 전용 노선 '+a_)
    x_=m_samename({r['name'] for r in v},pt)
    if x_:return ('정상','같은 이름 노드 '+x_+' (N05 점이 1.5km 넘게 어긋남·표기 차이)')
    for r in v:
        t_=MR['n05_line'].get(r['op']+'|'+r['line'])
        if t_ and r['yb']>=t_.get('from',0):return (t_['verdict'],t_['why'][:60])
    t_=MR['n05'].get(sid)
    if t_:return (t_['verdict'],t_['why'][:60])
    return None
k100=[];k100w=[];k100c=collections.Counter();k100a=[]
for sid,nm_,l_,yb,ye in nomatch:
    j=m_rule(sid,NS[sid])
    if j is None:k100.append((sid,nm_,l_,yb,ye));continue
    k100c[j[0]]+=1;k100a.append((sid,nm_,l_,yb,ye)+tuple(j))
    if j[0]=='근거 부족':k100w.append((sid,nm_,l_,yb,ye,j[1]))
put('K100 N05 역 기록(1950년 뒤)이 노드·열람 전용·수록 규칙·판정표 어디에도 없음',k100,60,lvl='err')
put('K100 N05 역 기록(1950년 뒤) 판정 근거 부족(남은 것, 판정표)',k100w,60,lvl='warn')
put('K100 N05 역 기록(1950년 뒤) 판정 갈래별 건수',sorted(k100c.items()),20)
put('K100 N05 역 기록(1950년 뒤) 판정 전체(참고)',k100a,20)
# K101: 위키 노선도의 1950년 뒤 폐역 행(K28) — 같은 이름 노드·열람 전용 역이 그 노선 노드 15km 안에 있으면(노선도에 그려진 이웃 노선 역) 있는 것으로 본다
def m_near_line(l,ids,km=15.0):
    pts_=[pos[x] for x in rnodes[l] if x in pos]
    for i_ in ids:
        ps_=[pos[i_]] if i_ in pos else []
        if not ps_:
            # 열람 전용 역은 자리가 앞뒤 역 사이라 앞·뒤 역 점을 모두 본다. 앞 역 하나만 보면 뒤 역이 그 노선 위인 행(播但線 豆腐町 ← 姫路)을 놓쳤다 (12회차 M)
            r_=m.execute('select after_id,before_id from archive_stop where id=?',(i_,)).fetchone()
            ps_=[pos[y] for y in (r_ or ()) if y in pos]
        if any(hav(p_,q)<km for p_ in ps_ for q in pts_):return i_
    return None
M_GN=collections.defaultdict(set)
for i_,x_ in n.execute("select entity_id,text from name where lang='ja' and entity_type in ('node','archive')"):M_GN[m_nz2(x_)].add(i_)
for i_ in pos:
    for x_ in anames(i_):M_GN[m_nz2(x_)].add(i_)
k101=[];k101w=[];k101c=collections.Counter();k102=[];k102n=[];k101n=[]
K102Q=[];K102H=[]
# 앞 회차에 열람 전용 역에서 사유를 달고 뺀 행(archive_lines.json drop_stop: 화물역·전용선·같은 역)의 이름은 판정된 것으로 본다
M_DROPN=set()
for x_ in dropped_ja(set(_AF0.get('drop_stop',{}))):M_DROPN.add(m_nz2(x_))
M_NS2=collections.defaultdict(set)
for s_,v_ in NS.items():
    for rr in v_:
        if rr['ye']>=1950:M_NS2[m_nz2(rr['name'])].add(s_)
for l in sorted(LDOC):
    R_=rows_of(l)
    if not R_:continue
    nm2n=nmap(l);tn=title_nodes(LDOC[l]['title']);al=set().union(*[arch_l[q] for q in tlines(LDOC[l]['title'])])
    for r in R_:
        icons=[z for c in r['c'] for z in c]
        t0=row_head(r['t']);m_=RW28.match(t0)
        if not m_ or NOSTN.search(r['t']):continue
        if not any(re.match(r'^(ex|e[A-Z]|x[A-Z]|uex|ke)',z) and re.search('BHF|HST',z) for z in icons):continue
        cy=close_year(m_.group(2))
        # 노선도 행 이름 앞의 표지(#·+·*: 옛 선·별 기점 거리 표시)는 역 이름이 아니다. 떼지 않으면 들어간 역(実盛谷·泉福寺)과 이름이 맞지 않았다 (12회차 M)
        _rn=re.sub(r'^[#+*]+','',m_.group(1));nmz=nz(_rn)
        if nmz in nm2n or nmz in tn or nmz in arch_l[l] or nmz in al or nmz in arch_l[None]:continue
        x=row_node(l,r,nm2n)
        if x and nmz in anames(x):continue
        key=l+'|'+m_.group(1);t_=MR['wiki'].get(key)
        hit=m_near_line(l,M_GN.get(m_nz2(_rn),())) or ('drop_stop' if m_nz2(_rn) in M_DROPN else None)
        if cy and cy>=1950:
            if t_:
                k101c[t_['verdict']]+=1
                if t_['verdict']=='근거 부족':k101w.append((ln(l),m_.group(1),cy,r['t'][:30],t_['why'][:60]))
                continue
            if hit:
                k101c['앞 회차 열람 전용 뺌 사유' if hit=='drop_stop' else '같은 이름 이웃 노선 역']+=1;k101n.append((ln(l),m_.group(1),cy,hit));continue
            k101.append((l,ln(l),m_.group(1),cy,r['t'][:30]))
        elif not cy:
            # 연도 없는 행은 같은 이름 역이 그 노선 바로 곁(1.5km 안)일 때만 같은 역으로 본다. 15km로 보면 이름만 같은 다른 역이 섞였다
            # (西鉄枝光線 競馬場前 ← 6.4km 밖 北九州モノレール 競馬場前, 長野電鉄河東線 井上 ← 14km 밖 다른 井上. 12회차 M 2026-11-18)
            # 후보 전체에서 1.5km 안을 찾는다. 15km 안 첫 후보 하나만 다시 재면 집합 순서에 따라 결과가 바뀌었다(天神橋·豆腐町이 실행마다 오감)
            if hit and hit!='drop_stop':hit=m_near_line(l,M_GN.get(m_nz2(_rn),()),km=1.5)
            # K102: 연도 없는 폐역 행인데 그 노선 15km 안 N05 기록(1950년 뒤, 규칙·판정표로 걸러지지 않은 것)이 같은 이름
            if hit or t_:
                # 추가 대기(근거는 있으나 손 행을 아직 못 넣음)도 근거 부족과 같이 경고로 남긴다 (12회차 M)
                if t_ and t_['verdict'] in ('근거 부족','추가 대기'):k101w.append((ln(l),m_.group(1),None,r['t'][:30],(t_['verdict']+': '+t_['why'])[:60]))
                # 같은 이름 이웃 역으로만 넘긴 행(판정표 없음)도 대기열로 남긴다. 이름만 같은 다른 역(市役所前 같은 흔한 이름)이 섞일 수 있다
                if hit and not t_:K102H.append(dict(line=l,line_ja=ln(l),name=m_.group(1),row=r['t'],doc=LDOC[l]['title'],hit=hit))
                continue
            pts_=[pos[q] for q in rnodes[l] if q in pos]
            ev=[s_ for s_ in sorted(M_NS2.get(m_nz2(m_.group(1)),())) if any(hav(NS[s_][-1]['pt'],q)<15 for q in pts_)]
            ev=[s_ for s_ in ev if not m_rule(s_,NS[s_]) or m_rule(s_,NS[s_])[0]=='근거 부족']
            if ev:k102.append((l,ln(l),m_.group(1),r['t'][:30],ev[:3]))
            else:k102n.append((ln(l),m_.group(1),r['t'][:30]));K102Q.append(dict(line=l,line_ja=ln(l),name=m_.group(1),row=r['t'],doc=LDOC[l]['title'],nodes=[x for x in rnodes[l]][:0]))
put('K101 위키 노선도 폐역(1950년 뒤 폐지)이 DB·열람 전용·이웃 노선 역·판정표 어디에도 없음',k101,40,lvl='err')
put('K101 위키 노선도 폐역 판정 근거 부족(남은 것, 판정표)',k101w,60,lvl='warn')
put('K101 위키 노선도 폐역 판정 갈래별 건수',sorted(k101c.items()),20)
put('K101 위키 노선도 폐역을 같은 이름 이웃 노선 역·앞 회차 판정으로 본 행(참고, 이름만 같은 다른 역이 섞일 수 있어 판정표로 뒤집음)',k101n,60)
put('K102 위키 노선도 연도 없는 폐역 행인데 N05에 1950년 뒤 같은 이름 기록(그 노선 15km 안)이 있고 DB·열람 전용·판정표에 없음',k102,40,lvl='err')
# 참고 목록이던 것을 오류로 올린다. 판정 없이 보고서에만 쌓인 행에서 빠진 폐역 85곳(志度線 出晴·東田町 등)과 西鉄 甘木線 渕ノ上 등이 나왔다.
# 행마다 판정표(missing_reviewed.json wiki: 정상·근거 부족)나 DB 행(archive_fix _noyear로 날짜를 준 열람 전용 역)이 있어야 한다 (12회차 M 2026-11-18)
put('K102 위키 노선도 연도 없는 폐역 행이 DB·열람 전용·판정표 어디에도 없음(N05·DB 근거 없음)',k102n,40,lvl='err')
# 조사 대기열: 판정표(missing_reviewed wiki)에도 DB에도 없는 연도 없는 폐역 행 전부 (12회차 2026-11-18)
json.dump(K102Q,open(os.path.join(B,'k102_queue.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=0)
json.dump(K102H,open(os.path.join(B,'k102_hit_queue.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=0)
put('K102 위키 노선도 연도 없는 폐역 행을 같은 이름 이웃 역으로만 넘긴 것(판정표 없음, 참고)',[(x['line_ja'],x['name'],x['hit']) for x in K102H],40)
# ---- K103 노선째 빠진 것: 위키 「日本の廃止鉄道路線一覧」의 항목이 DB 노선·열람 전용 노선·계통 이름이나 판정표(missing_reviewed lines)에 없음 (12회차 M 2026-11-18)
# N05는 1950년 뒤 폐선의 닫힌 목록이 아니었다(北陸鉄道金沢市内線이 N05에도 DB에도 없음, 名鉄安城支線은 西尾線 묶음으로 넘어감). 노선 단위로 독립 목록과 대조한다.
# 수록 밖 유형(DESIGN §4.1: 馬車鉄道·人車軌道·森林鉄道·専用線·貨物線·簡易軌道·無軌条電車 등)은 규칙으로 거른다. 판정이 다 붙기 전이라 지금은 경고다
import glob as _glob
_al=sorted(_glob.glob(os.path.join(ROOT,'data','imports','wiki_lists','abolished_lines_*.wikitext')))
K103Q=[];K103W=[];k103c=collections.Counter()
if _al:
    _t=open(_al[-1],encoding='utf-8').read()
    _OUT=re.compile(r'馬車|人車|森林鉄道|専用鉄道|専用線|専用軌道|簡易軌道|殖民軌道|無軌条|トロリーバス|貨物線|貨物専用|軍用線|工事軌道|砂利|会場内')
    _nm=set(x for x, in n.execute("select text from name where lang='ja' and entity_type in ('line','archive','route')"))|set(dropped_ja(set(_AF0.get('drop',{}))|set(_AF0.get('exclude',{}))))
    def _keys(s_):
        s_=re.sub(r'\s*[（(].*?[)）]','',s_).strip();o={s_}
        for a_ in list(o):o|={re.sub(r'線$','',a_),a_+'線',re.sub(r'(鉄道|電鉄|軌道|電気軌道|電気鉄道)$','',a_)}
        return {k for k in o if k}
    _idx=set()
    for x_ in _nm:_idx|=_keys(x_)
    _pref=None
    for _ln in _t.splitlines():
        _m=re.match(r'^=+ *([^=]+?) *=+',_ln)
        if _m:_pref=_m.group(1);continue
        if not _ln.startswith('*') or _pref in (None,'関連項目'):continue
        _links=re.findall(r'\[\[([^\]|#]+)(?:[|#][^\]]*)?\]\]',_ln)
        if not _links:continue
        _ti=_links[0]
        if _keys(_ti)&_idx:k103c['DB에 있음']+=1;continue
        if _OUT.search(_ln):k103c['수록 밖 유형']+=1;continue
        _j=MR.get('lines',{}).get(_ti)
        if _j:
            k103c[_j['verdict']]+=1
            if _j['verdict']!='정상':K103W.append((_pref,_ti,_j['verdict']))
            continue
        K103Q.append(dict(pref=_pref,title=_ti,line=_ln.strip()))
    json.dump(K103Q,open(os.path.join(B,'k103_queue.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=0)
# 판정이 다 붙어(12회차 M, 갈래 셋) 판정 없는 항목은 오류다. 근거 부족·추가 대기는 재조사 대상이라 경고로 남긴다
put('K103 위키 폐선 목록 항목이 DB·열람 전용·판정표에 없음(노선째 빠졌을 수 있음)',[(x['pref'],x['title'],x['line'][:60]) for x in K103Q],60,lvl='err')
put('K103 위키 폐선 목록 판정이 근거 부족·추가 대기(재조사 중)',K103W,60,lvl='warn')
put('K103 위키 폐선 목록 판정 갈래별 건수',sorted(k103c.items()),20)
# ---- K104 열람 전용 역의 이름 열쇠 읽기가 다른 곳 같은 이름 역의 읽기 (13회차 2026-11-19 사용자 지적: 「한자가 같다고 같은 읽기를 붙이지 말 것」) ----
# 읽기가 행 자신의 근거(archive_fix _add·이름@노선·이름 행)나 그 역 위키 문서가 아니라 이름만 맞춘 열쇠(손 읽기 표 node:이름·station_database)에서 왔는데,
# 같은 이름의 노드가 그 역 노선에 서지 않고 앞뒤 역에서 5 km 밖에만 있으면 그 노드 읽기를 빌려 온 것일 수 있다. 생성기(gen_extra)가 막으므로 0이어야 한다
_aks=os.path.join(ROOT,'data','candidates','archive_kana_src.json')
K104=[]
if os.path.exists(_aks):
    _AKS=json.load(open(_aks,encoding='utf-8'))
    _pos={r[0]:(r[1],r[2]) for r in m.execute('select node_id,lat,lon from node_position') if r[1] is not None}
    _rl={r[0]:r[1] for r in m.execute('select id,line_id from route')}
    _nl=collections.defaultdict(set)
    for r in m.execute('select route_id,node_id from route_stop'):_nl[r[1]].add(_rl.get(r[0]))
    _nn=collections.defaultdict(set)
    for r in n.execute("select entity_id,text from name where entity_type='node' and lang='ja'"):_nn[r[1]].add(r[0])
    def _d104(p,q):return math.hypot((p[0]-q[0])*111.2,(p[1]-q[1])*111.2*math.cos(math.radians(p[0])))
    for r in m.execute('select id,line_id,after_id,before_id from archive_stop'):
        src=_AKS.get(r[0])
        # 위키 문서 읽기는 생성기가 문서 역 정보칸의 사업자·노선이 맞을 때도 받으므로(그 역 자신의 문서) 여기서 보지 않는다
        if src not in ('hand','est','sd'):continue
        t=n.execute("select text,kana from name where entity_type='archive' and lang='ja' and entity_id=?",(r[0],)).fetchone()
        if not t or not t[1]:continue
        ends=[_pos[x] for x in (r[2],r[3]) if x in _pos]
        others=[x for x in _nn.get(t[0],()) if x not in (r[2],r[3])]
        same=[x for x in others if r[1] in _nl[x] or (x in _pos and ends and min(_d104(_pos[x],e) for e in ends)<5)]
        if others and not same:K104.append((r[0],t[0],t[1],src,sorted(others)[:3]))
put('K104 열람 전용 역 읽기가 이름 열쇠로 다른 곳 같은 이름 역에서 옴',K104,60,lvl='err')
# ---- K105 노드 읽기가 손 읽기 표·추정 표의 이름 열쇠(node:이름)에서 왔는데 같은 이름 노드가 5 km 밖에 있음 (13회차 2026-11-19) ----
# 이름 하나에 읽기 하나인 표는 같은 이름 역을 가르지 못한다. 생성기(gen_source namekey_ok)가 막으므로 0이어야 한다. 그 역 읽기는 「노드 ID|이름」 열쇠로 넣는다
_kh=json.load(open(os.path.join(ROOT,'data','overrides','kana.json'),encoding='utf-8'))
_ke0=os.path.join(ROOT,'data','overrides','kana_est.json');_ke=json.load(open(_ke0,encoding='utf-8')) if os.path.exists(_ke0) else {}
_pos5={r[0]:(r[1],r[2]) for r in m.execute('select node_id,lat,lon from node_position') if r[1] is not None}
_cur=collections.defaultdict(list)
for r in n.execute("select entity_id,text,kana,reading_source from name where entity_type='node' and lang='ja' and valid_from is null and valid_to is null"):_cur[r[1]].append(r)
def _d105(p,q):return math.hypot((p[0]-q[0])*111.2,(p[1]-q[1])*111.2*math.cos(math.radians(p[0])))
K105=[]
for t,rs in _cur.items():
    if len(rs)<2:continue
    for r in rs:
        if r[3]!='auto:name_key' or not r[2]:continue
        k='node:'+t
        if _kh.get(k)!=r[2] and _ke.get(k)!=r[2]:continue
        far=[o[0] for o in rs if o[0]!=r[0] and not (o[0] in _pos5 and r[0] in _pos5 and _d105(_pos5[o[0]],_pos5[r[0]])<5)]
        # 1 km 안 같은 이름 역이 자기 근거로 같은 읽기면 같은 곳 이름이라 생성기가 받는다 (gen_source namekey_ok)
        own=[o for o in rs if o[0]!=r[0] and o[3]!='auto:name_key' and o[2]==r[2] and o[0] in _pos5 and r[0] in _pos5 and _d105(_pos5[o[0]],_pos5[r[0]])<1]
        if far and not own:K105.append((r[0],t,r[2],sorted(far)[:3]))
put('K105 노드 읽기가 이름 열쇠 손 표로 다른 곳 같은 이름 역과 공유',K105,60,lvl='err')
# ---- K106 지금 운영 중인 역(여는 계통에 오늘도 정차)에 읽기가 없음 (13회차 2026-11-19 사용자 지시: 「모든 현재 운영 중인 역은 읽기가 있어야 한다」) ----
K106=[]
for r in m.execute("select distinct s.node_id from route_stop s join route r on r.id=s.route_id where s.is_stop=1 and s.valid_to='ongoing' and (r.closed is null or r.closed=0)"):
    t=n.execute("select text,kana from name where entity_type='node' and lang='ja' and entity_id=? and valid_from is null and valid_to is null",(r[0],)).fetchone()
    if not t or not t[1]:K106.append((r[0],t[0] if t else None))
put('K106 지금 운영 중인 역에 읽기 없음',K106,60,lvl='err')
# ---- K142 근거 표 없는 여객 직통 후보 (10회차 D1, 전수 점검 4회차 일반화 요청) ----
# 같은 역 묶음(group)의 두 노선이 그 역에서 환승으로만 이어진 쌍(노드가 같든 다르든)마다, 두 노선 위키 문서 본문에서 상대 노선 이름 앞뒤 80자 안에
# 「直通|乗り入れ|乗入|併結」이 있으면 여객 직통 후보다. 근거 표 직통(THROUGH)이나 직통 판정 표(THROUGH_REVIEWED: 화물·선로만·근거 부족 판정)에 있는 쌍은 뺀다
_HT2=json.load(open(os.path.join(ROOT,'data','overrides','hand_tables.json'),encoding='utf-8'))['tables']
_REV=_HT2.get('THROUGH_REVIEWED',{}).get('값',[])
_DONE={frozenset((x['a'],x['b'])) for x in _HT2['THROUGH']['값']}|{frozenset((x['a'],x['b'])) for x in _REV}
_LT={i:t for i,t in m.execute('select id,type from line')}
_LC={i:c for i,c in m.execute('select id,rule_class from line')}
_RL={i:l for i,l in m.execute('select id,line_id from route')}
_GR={i:g for i,g in m.execute('select id,group_id from node')}
_GN=collections.defaultdict(list)
for i_,g_ in _GR.items():_GN[g_].append(i_)
_LN=collections.defaultdict(set)
for i,x in n.execute("select entity_id,text from name where entity_type='line' and lang='ja'"):
    _LN[i].add(x)
    m_=re.match(r'^.*?(?:鉄道|電鉄|電気鉄道|急行|交通|軌道|メトロ|地下鉄|高速|事業|電車|鐵道|鐵道|臨海|開発|製錬|鉱業)(.{2,}線)$',x)
    if m_ and m_.group(1) not in ('本線','支線','新線','連絡線'):_LN[i].add(m_.group(1))
_KW=re.compile('直通|乗り入れ|乗入|併結')
_TXT={}
def _ltext(l):
    if l not in _TXT:
        d_=LDOC.get(l);_TXT[l]=wclean((d_ or {}).get('wikitext') or '') if d_ else ''
    return _TXT[l]
def _near(txt,nms,sts):
    # 상대 노선 이름 앞뒤 80자 안에 직통 낱말이 있고, 그 앞뒤 200자 안에 그 역 이름(같은 역 묶음 노드 이름)도 나올 때
    for nm_ in nms:
        for q in re.finditer(re.escape(nm_),txt):
            w_=txt[max(0,q.start()-80):q.end()+80]
            if not _KW.search(w_):continue
            w2=txt[max(0,q.start()-200):q.end()+200]
            if any(st_ and st_ in w2 for st_ in sts):return w_.replace('\n',' ')
    return None
_lnk=collections.defaultdict(set);_tr=collections.defaultdict(set)
for r_,sq_,ol_,kd_,nd_ in m.execute('select l.route_id,l.seq,l.other_line_id,l.kind,s.node_id from route_link l join route_stop s on s.route_id=l.route_id and s.seq=l.seq'):
    a_=_RL[r_];g_=_GR.get(nd_)
    if kd_ in ('continue','branch'):_lnk[frozenset((a_,ol_)),g_].add(1)
    else:_tr[frozenset((a_,ol_)),g_].add(nd_)
k142=[];_seen=set()
for (pr_,g_),nds_ in sorted(_tr.items(),key=lambda kv:(sorted(kv[0][0]),str(kv[0][1]))):
    if len(pr_)!=2 or (pr_,g_) in _lnk or pr_ in _DONE:continue
    a_,b_=sorted(pr_)
    if {_LT.get(a_),_LT.get(b_)}-{'rail','subway','tram'}:continue
    # 신칸센↔재래선은 환승(§8.1), 지하철끼리는 직통 노선 쌍이 아니라 다른 노선 이름이 문장에 함께 나온 것뿐이라 뺀다
    if 'shinkansen' in (_LC.get(a_),_LC.get(b_)) or _LT.get(a_)==_LT.get(b_)=='subway':continue
    if pr_ in _seen:continue
    sts_={re.sub(r'(駅|停留場|電停)$','',x_) for d_ in nds_ for x_ in ja['node',d_]}|{re.sub(r'(駅|停留場|電停)$','',x_) for d_ in _GN[g_] for x_ in ja['node',d_]} if g_ else set()
    sts_={x_ for x_ in sts_ if len(x_)>=2}
    w_=_near(_ltext(a_),_LN[b_],sts_) or _near(_ltext(b_),_LN[a_],sts_)
    if w_:_seen.add(pr_);k142.append((a_,b_,nn(sorted(nds_)[0]),w_[:200]))
# 판정 표에서 근거 부족(c)·근거 하나(c1)로 남긴 쌍은 문장 탐지와 관계없이 후보로 남긴다
k142+=[(x['a'],x['b'],nn(x['at'][0]),'판정 표 '+x['verdict']+': '+x['why'][:150]) for x in _REV if x['verdict'] in ('c','c1')]
put('K142 근거 표 없는 여객 직통 후보 남음(같은 역 묶음 환승 쌍 중 위키 본문에 상대 노선과 直通·乗り入れ·併結이 함께 나옴)',k142,400,lvl='warn')
# ---- 10회차 G1 (K178·K179): 위키 직통 문장 후보·같은 노드 연결 행 없음·지금 계통 누적 km
# K178 다른 노드(같은 역 묶음·환승 쌍) 환승뿐인 두 노선의 위키 노선 문서 한 문장에 상대 노선 이름과 「直通|乗り入れ|乗入」이 함께 나옴 → THROUGH 근거 후보 (4회차 kanto_1-016·kanto_2-015·kyushu_2-008 등 13건 제안).
# 근거 표(THROUGH)·연결 없음 판정(JUNCTION_NOT)에 이미 있는 쌍, 화물만(貨車·貨物 직통), 부정 문구(断られ·実現しなかった·計画·構想·予定)는 뺀다. 확인 목록이고 사람이 THROUGH 또는 「직통 없음」으로 닫는다
_HT178=json.load(open(os.path.join(ROOT,'data','overrides','hand_tables.json'),encoding='utf-8'))['tables']
_TH178={frozenset((x['a'],x['b'])) for x in _HT178.get('THROUGH',{}).get('값',[])}
_JN178={frozenset((x.get('a') or x.get('line'),x.get('b') or x.get('other'))) for x in _HT178.get('JUNCTION_NOT',{}).get('값',[]) if isinstance(x,dict)}
_OPS178=[x for x, in n.execute("select distinct text from name where entity_type='operator' and lang='ja'") if x and len(x)>=2]
def _lnames178(l):
    out=set()
    for x in ja['line',l]:
        x=re.sub(r'[（(].*?[)）]','',x).strip();out.add(x)
        for o_ in _OPS178:
            if x.startswith(o_) and len(x)-len(o_)>=3:out.add(x[len(o_):])
    return {x for x in out if len(x)>=3 and x not in ('本線','支線','新線','連絡線')}
def _plain178(wt):
    wt=re.sub(r'<ref[^>]*/>|<ref[^>]*>.*?</ref>','',wt,flags=re.S)
    wt=re.sub(r'\{\{[^{}]*\}\}','',wt);wt=re.sub(r'\[\[(?:[^|\]]*\|)?([^\]]*)\]\]',r'\1',wt);wt=re.sub(r"'{2,}",'',wt)
    return wt
_SENT178={}
def _sents178(l):
    if l not in _SENT178:
        d_=LDOC.get(l);_SENT178[l]=[s_ for s_ in re.split(r'[。\n]',_plain178(d_.get('wikitext') or '')) if s_.strip()] if d_ else []
    return _SENT178[l]
_K178P=re.compile(r'直通|乗り入れ|乗入');_K178N=re.compile(r'断られ|実現しなかった|実現せず|計画|構想|予定|検討')
_pairs178=collections.defaultdict(set)
_trk178={(G_(x),a,b) for x,a,b in [(r_[0],r_[1],r_[2]) for r_ in m.execute("select s.node_id,r.line_id,l.other_line_id from route_link l join route_stop s on s.route_id=l.route_id and s.seq=l.seq join route r on r.id=l.route_id where l.kind in ('continue','branch')")]}
for rid_,x_,ol_,on_ in m.execute("select l.route_id,s.node_id,l.other_line_id,l.other_node from route_link l join route_stop s on s.route_id=l.route_id and s.seq=l.seq where l.kind='transfer'"):
    la_=routes[rid_]['line_id']
    if not ol_ or la_==ol_ or (G_(x_),la_,ol_) in _trk178:continue
    _pairs178[frozenset((la_,ol_))].add(nn(x_))
rows=[]
for f_,ats_ in sorted(_pairs178.items(),key=lambda kv:sorted(kv[0])):
    if f_ in _TH178 or f_ in _JN178 or len(f_)!=2:continue
    a_,b_=sorted(f_)
    for x_,y_ in ((a_,b_),(b_,a_)):
        nm_=_lnames178(y_)
        # 문장에 갈아타는 역 이름도 있어야 한다(노선 이름만 스친 문장을 줄임)
        st_={re.sub(r'（旧）$','',t_) for t_ in ats_}
        hit=[s_.strip()[:90] for s_ in _sents178(x_) if _K178P.search(s_) and any(t_ in s_ for t_ in nm_) and any(t_ in s_ for t_ in st_) and not _K178N.search(s_) and not (re.search(r'貨車|貨物',s_) and not re.search(r'旅客|列車|電車|気動車|特急|急行|快速',s_))]
        if hit:rows.append((ln(x_),ln(y_),sorted(ats_)[:2],(LDOC.get(x_) or {}).get('title'),hit[0]));break
put('K178 다른 노드 환승뿐인 두 노선의 위키 문서에 상대 노선과 직통·乗り入れ 문장(THROUGH 근거 후보)',rows,80,lvl='warn')
# K178 같은 노드·같은 사업자·같은 궤간 두 노선이 기간 내내 환승뿐이고 선로 연결 근거(junction·track_link)가 하나도 없음 (4회차 kinki_2-012 西宮北口). 위키 노선도 BS에 ABZ·연결선이 있는지 볼 확인 목록
_LTYPE178=dict(m.execute('select id,type from line').fetchall())
_LG178=collections.defaultdict(set)
for l_,g_ in m.execute('select line_id,gauge from line_gauge where gauge is not null'):_LG178[l_].add(g_)
_LOP178=collections.defaultdict(set)
for l_,o_ in m.execute('select line_id,operator_id from edge_attr'):_LOP178[l_].add(o_)
rows=[]
for rid_,x_,ol_,on_ in m.execute("select distinct l.route_id,s.node_id,l.other_line_id,l.other_node from route_link l join route_stop s on s.route_id=l.route_id and s.seq=l.seq where l.kind='transfer' and (l.other_node is null or l.other_node=s.node_id)"):
    la_=routes[rid_]['line_id']
    if not ol_ or la_>=ol_ or (G_(x_),la_,ol_) in TLG or (G_(x_),la_,ol_) in _trk178:continue
    if not (_LOP178[la_]&_LOP178[ol_]) or not (_LG178[la_]&_LG178[ol_]) or LTY.get(la_)!=LTY.get(ol_):continue
    # 지하철끼리는 층이 달라 만나는 역이 많다(선로 연결 없음이 보통). 지상 철도·노면전차만 본다
    if _LTYPE178.get(la_)=='subway' or _LTYPE178.get(ol_)=='subway':continue
    rows.append((ln(la_),ln(ol_),nn(x_),x_))
put('K178 같은 노드·같은 사업자·같은 궤간 두 노선이 환승뿐이고 선로 연결 근거가 없음(확인 목록)',sorted(set(rows)),60,lvl='warn')
# K179 지금 영업 계통의 역별 누적 km(첫 맞는 역 기준)가 노리츠부시 역 km와 0.1 km 넘게 다름 (4회차 chubu_1-012 遠州 e_010518). km_fix로 근거를 채택한 칸 뒤는 그 역을 새 기준으로 잰다
_KF179={frozenset((x['a'],x['b'])) for x in json.load(open(os.path.join(ROOT,'data','overrides','km_fix.json'),encoding='utf-8')) if isinstance(x,dict) and x.get('a') and x.get('b')}
_cur179={}
_kfr179={r_ for r_,v_ in stops.items() if any(frozenset((a['node_id'],b['node_id'])) in _KF179 for a,b in zip(v_,v_[1:]))}
for rid_,v_ in stops.items():
    # 고리 계통(시작·끝 역이 같음)과 km_fix로 근거를 채택한 칸이 있는 계통은 뺀다(노리츠부시 표 자체가 틀린 곳이 km_fix다)
    if routes[rid_].get('closed') or rid_ in _kfr179:continue
    cs_=[z_ for z_ in v_ if z_['is_stop'] and z_['valid_to']=='ongoing' and z_['km_cum'] is not None]
    if len(cs_)>=2:_cur179[rid_]=cs_
_byname179=collections.defaultdict(set)
for rid_,cs_ in _cur179.items():
    for z_ in cs_:
        for nm_ in names(z_['node_id']):_byname179[nm_].add(rid_)
rows=[]
for x in NB:
    if x['g'] not in('jr','pr','tm'):continue
    st=[(nz(re.sub(r'^\(臨\)','',l.strip('*').strip('[]'))),float(k)) for l,k in x['s']]
    cnt_=collections.Counter(r_ for nm_,_ in st for r_ in _byname179.get(nm_,()))
    if not cnt_:continue
    rid_,c_=cnt_.most_common(1)[0]
    if c_<max(3,len(st)//2):continue
    pos_={}
    for z_ in _cur179[rid_]:
        for nm_ in names(z_['node_id']):pos_.setdefault(nm_,z_)
    # 반올림(0.1 단위 칸 km 합)으로 한 역만 ±0.1 흔들리는 것은 빼고, 0.15 넘게 다르거나 0.1 차가 다음 맞는 역까지 같은 쪽으로 이어질 때만 낸다(遠州 八幡 뒤 모든 역 0.1 작음)
    base=None;pend=None
    for nm_,k_ in st:
        z_=pos_.get(nm_)
        if not z_:continue
        if base is None:base=(z_['km_cum'],k_);continue
        d_=round((z_['km_cum']-base[0])-(k_-base[1]),2)
        if abs(d_)>=0.15 or (pend and abs(d_)>=0.1-1e-9 and (d_>0)==(pend[-1]>0)):
            rows.append((x['t'][:24],rid_,(pend or (nm_,))[0],nm_,round(z_['km_cum']-base[0],1),round(k_-base[1],1),d_));base=(z_['km_cum'],k_);pend=None
        elif abs(d_)>=0.1-1e-9:pend=(nm_,d_)
        else:pend=None
put('K179 지금 영업 계통 역별 누적 km가 노리츠부시 역 km와 0.1 km 넘게 다름(km_fix 채택 칸 뒤는 다시 잼, 확인 목록)',rows,200,lvl='warn')
# ---- 11회차 S1b (K194b·K194d·K194g): 위키 「分離」「直通 中止」 문장·근거 글 인용 연도·노면전차 系統
# K194b 같은 노드 이어짐·분기인 두 노선의 위키 노선 문서 한 문장에 그 역 이름·상대 노선 이름과 「分離」「(直通)運転を中止·廃止」「乗り入れを中止·廃止」이 함께 나옴
# (4회차 chubu_2-010 (c): 穴水 1988–1991 のと鉄道 분리). 그 문장의 해 뒤에도 같은 노드 이어짐이면 직통이 끝난 뒤 환승이어야 하는지 볼 확인 목록
# 「〇〇線として分離」(노선 이름 나눔)은 운행 분리가 아니라 뺀다. 역·운행 계통·직통의 분리·중지만 본다
_K194BP=re.compile(r'(?:駅|ホーム|運転系統|系統|運行|運転|列車|直通運転)(?:を|が|は|も)?(?:完全に)?分離|分離(?:して|され)(?:独立|別駅)|(?:直通|乗り入れ|乗入れ|運転)(?:運転)?を(?:中止|廃止|取りやめ|休止)|直通(?:運転)?(?:が|は)?(?:廃止|中止)')
rows=[]
_seen194b=set()
for r_ in m.execute("select l.route_id,s.node_id,l.other_line_id,l.valid_from,l.valid_to from route_link l join route_stop s on s.route_id=l.route_id and s.seq=l.seq where l.kind in ('continue','branch') and (l.other_node is null or l.other_node=s.node_id)"):
    rid_,x_,ol_,vf_,vt_=r_[0],r_[1],r_[2],r_[3],r_[4]
    la_=routes[rid_]['line_id']
    if not ol_ or la_==ol_ or (la_,ol_,x_) in _seen194b:continue
    _seen194b.add((la_,ol_,x_));_seen194b.add((ol_,la_,x_))
    st_={re.sub(r'（旧）$','',t_) for t_ in ja['node',x_]}
    for a_,b_ in ((la_,ol_),(ol_,la_)):
        nm_=_lnames178(b_)
        hit=[s_.strip()[:100] for s_ in _sents178(a_) if _K194BP.search(s_) and any(t_ in s_ for t_ in st_) and any(t_ in s_ for t_ in nm_)]
        if hit:rows.append((ln(la_),ln(ol_),nn(x_),x_,vf_,vt_,(LDOC.get(a_) or {}).get('title'),hit[0]));break
put('K194b 같은 노드 이어짐인 두 노선의 위키 문서에 그 역·상대 노선과 「分離」「直通 中止·廃止」 문장(확인 목록)',rows,60,lvl='warn')
# K194d 근거 표 직통(THROUGH)의 근거 글이 인용한 해와, 인용한 원문(「…」)이 있는 위키 年表 단락 머리의 해가 다름 (4회차 tohoku_1-011 (2): 保原 1963↔1934).
# 근거 글의 「해(-달-날) 「인용」」 꼴만 본다. 인용은 두 노선 위키 노선 문서와 src에 제목이 있는 문서에서 찾고, 그 앞 가장 가까운 年表 줄 머리(* 1963年 …)의 해와 견준다
import urllib.parse
_HT194=json.load(open(os.path.join(ROOT,'data','overrides','hand_tables.json'),encoding='utf-8'))['tables']
_Q194=re.compile(r'(?<![\d.])(18\d\d|19\d\d|20[0-2]\d)(?:-\d\d(?:-\d\d)?)?\)?\s*「([^」]{6,})」')
_HEAD194=re.compile(r'^\s*[*;:#=]*\s*(?:\'\'\')?\[*(\d{4})年')
rows=[]
for x_ in _HT194.get('THROUGH',{}).get('값',[]):
    why_=x_.get('why') or ''
    docs_=[]
    for l_ in (x_.get('a'),x_.get('b')):
        d_=LDOC.get(l_)
        if d_ and d_.get('wikitext'):docs_.append((d_['title'],d_['wikitext']))
    for t_ in re.findall(r'title=([^&\s;]+)',x_.get('src') or ''):
        t_=urllib.parse.unquote(t_);d_=doc(t_)
        if d_ and d_.get('wikitext'):docs_.append((t_,d_['wikitext']))
    for y_,q_ in _Q194.findall(why_):
        frag=max((f_.strip() for f_ in re.split(r'…|\.\.\.|⋯',q_)),key=len)
        if len(frag)<6:continue
        for t_,wt_ in docs_:
            lines_=_plain178(wt_).split('\n')
            at=next((i_ for i_,l2 in enumerate(lines_) if frag in l2),None)
            if at is None:continue
            head=None
            for l2 in reversed(lines_[:at+1]):
                mh=_HEAD194.match(l2)
                if mh:head=mh.group(1);break
            if head and head!=y_:rows.append((ln(x_.get('a')),ln(x_.get('b')),y_,head,t_,frag[:40]))
            break
put('K194d 근거 표 직통의 근거 글 인용 연도가 위키 年表 단락 머리 해와 다름(확인 목록)',sorted(set(rows)),40,lvl='warn')
# K194g 노면전차 사업자·노선 위키 문서의 系統 줄이 서로 만나는 두 노선(같은 역 묶음·환승 쌍)을 함께 지나는데, 두 노선 사이 선로 연결(이어짐·분기)도
# 운행 계통표 행(tram_systems.json)도 없음 (4회차 chugoku_shikoku_2-011: 伊予鉄 6号線 本町線↔城南線 다른 노드 계통). 系統 줄의 역 이름으로 노선을 가린다. 확인 목록
_TS194=json.load(open(os.path.join(ROOT,'data','overrides','tram_systems.json'),encoding='utf-8')).get('rows',[])
_TSP194={frozenset((x_['x'],x_['y'])) for x_ in _TS194}
_TRK194=set()
for la_,ol_ in m.execute("select r.line_id,l.other_line_id from route_link l join route r on r.id=l.route_id where l.kind in ('continue','branch')"):
    if ol_:_TRK194.add(frozenset((la_,ol_)))
_OPL194=collections.defaultdict(set)
for l_,o_ in m.execute('select distinct line_id,operator_id from edge_attr'):
    if LTY.get(l_)=='tram':_OPL194[o_].add(l_)
_LST194=collections.defaultdict(set)
for rid_,v_ in stops.items():
    l_=routes[rid_]['line_id']
    if LTY.get(l_)!='tram':continue
    for y in v_:
        if y['is_stop']:_LST194[l_].add(y['node_id'])
_HP194=collections.defaultdict(set)
for a_,b_ in m.execute('select node_a,node_b from hub_pair'):_HP194[a_].add(b_);_HP194[b_].add(a_)
def _meet194(a_,b_):
    ga={G_(x) for x in _LST194[a_]};gb={G_(x) for x in _LST194[b_]}
    return bool(ga&gb) or any(y in _LST194[b_] for x in _LST194[a_] for y in _HP194.get(x,()))
rows=[]
for o_,ls_ in _OPL194.items():
    if len(ls_)<2:continue
    by_nm=collections.defaultdict(set)
    for l_ in ls_:
        for x in _LST194[l_]:
            for t_ in ja['node',x]:
                if len(t_)>=2:by_nm[t_].add(l_)
    texts=[]
    for t_ in ja['operator',o_]:
        d_=doc(t_)
        if d_ and d_.get('wikitext'):texts.append((t_,d_['wikitext']))
    for l_ in ls_:
        d_=LDOC.get(l_)
        if d_ and d_.get('wikitext'):texts.append((d_['title'],d_['wikitext']))
    for t_,wt_ in texts:
        for l2 in _plain178(wt_).split('\n'):
            if not re.search(r'\d+\s*(?:系統|号線)',l2):continue
            own=collections.defaultdict(int)
            for nm_,lls in by_nm.items():
                if len(lls)==1 and nm_ in l2:own[next(iter(lls))]+=1
            got=sorted(own)
            for i_,a_ in enumerate(got):
                for b_ in got[i_+1:]:
                    f_=frozenset((a_,b_))
                    if f_ in _TRK194 or f_ in _TSP194 or not _meet194(a_,b_):continue
                    rows.append((ln(a_),ln(b_),t_,l2.strip()[:90]))
put('K194g 노면전차 系統 줄이 만나는 두 노선을 함께 지나는데 선로 연결·운행 계통표 행이 없음(확인 목록)',sorted({r_[:2]+r_[2:3]:r_ for r_ in rows}.values()),60,lvl='warn')
# ==== 11회차 S3 스위치백 직통 표식 (판 2026-11-16.4) ====
# 끝 역 이어짐의 선형 각(K68과 같은 잼: 이 계통이 끝 역으로 들어오는 칸과 상대 계통 다음 역 쪽 칸의 시작 방향, 곧게 이어지면 180°)
# K196 스위치백 표식(route_link_reverse)이 걸린 선 이어짐인데 선형 각이 기준 미만(되돌아감)이 아님. 옛 역 자리 배선을 노드가 담지 못한 곳(塩尻 1982 전)이 남는다(확인 목록)
# K197 선형 각이 기준 미만(되돌아가는 끝 역 이어짐)인데 근거 표(THROUGH)에 그 쌍의 스위치백 판정(reverse 칸)이 없음(확인 목록). 선로만 이어진 스위치백형 이어짐이 대부분이다
_RVC=bool(m.execute("select 1 from sqlite_master where type='table' and name='route_link_reverse'").fetchone())
_RVS=collections.defaultdict(list)
if _RVC:
    for r_ in m.execute('select route_id,seq,other_line_id,next_stop_node,valid_from,valid_to from route_link_reverse'):_RVS[tuple(r_[:4])].append(ivl(r_[4],r_[5]))
def _rv196(rid,seq,ol,nx_,vf,vt):
    p_=ivl(vf,vt)
    return any(q_ and p_ and q_[0]<p_[3] and p_[0]<q_[3] for q_ in _RVS.get((rid,seq,ol,nx_),()))
_RVJ={(x['a'],x['b'],x['at'][0]) for x in _THX if 'reverse' in x}|{(x['b'],x['a'],x['at'][1]) for x in _THX if 'reverse' in x}
def _ang196(rid,seq,ol,on_,nx_,vf,vt,orr):
    x=_SEQN.get((rid,seq));_p=ivl(vf,vt)
    if not _p or not x or not nx_ or rid not in routes:return None,None
    d_=AS_OF if vt=='ongoing' else (_p[2] or AS_OF)
    if vt!='ongoing':
        try:d_=(datetime.date.fromisoformat(d_)-datetime.timedelta(days=1)).isoformat()
        except ValueError:pass
    A=routes[rid]['line_id'];m_=on_ or x
    own=[e for e in _REDGE[rid] if x in _EN.get(e,())]
    if len(own)!=1:return None,None
    vo=_gdir(own[0],x)
    for q in ([orr] if orr else line_routes.get(ol,[])):
        L=[s_['node_id'] for s_ in stops[q]]
        if m_ not in L or nx_ not in L:continue
        i,j=L.index(m_),L.index(nx_);st_=1 if j>i else -1
        ed=[e for e in _REDGE[q] if m_ in _EN.get(e,()) and _eopen(e,ol,d_)]
        en=None
        for kk in (range(i+1,len(L)) if st_>0 else range(i-1,-1,-1)):
            f_=[e for e in ed if L[kk] in _EN[e]]
            if f_:en=f_[0];break
        if not en:continue
        return _ang(vo,_gdir(en,m_)),(30 if LTY.get(A)==LTY.get(ol)=='tram' else 75)
    return None,None
rows196=[];rows197={}
if _RVC:
    for k in m.execute("select route_id,seq,other_line_id,other_node,next_stop_node,valid_from,valid_to,other_route_id from route_link where kind='continue'"):
        rid,seq,ol,on_,nx_,vf,vt,orr=k;rv=1 if _rv196(rid,seq,ol,nx_,vf,vt) else 0
        a1,th=_ang196(rid,seq,ol,on_,nx_,vf,vt,orr)
        x=_SEQN.get((rid,seq))
        if rv==1 and (a1 is None or a1>=th):rows196.append((rid,nn(x),ln(ol),nn(nx_) if nx_ else None,None if a1 is None else round(a1),vf,vt))
        elif rv!=1 and a1 is not None and a1<th and (routes[rid]['line_id'],ol,x) not in _RVJ:rows197.setdefault((rid,x,ol),(rid,nn(x),ln(ol),nn(nx_),round(a1),vf,vt))
put('K196 스위치백 표식(route_link_reverse) 끝 역 이어짐의 선형 각이 되돌아가는 각이 아님(옛 역 배선, 확인 목록)',rows196,40,lvl='warn')
put('K197 되돌아가는 끝 역 이어짐(선형 각 기준 미만)인데 근거 표에 스위치백 직통 판정(THROUGH reverse 칸)이 없음(확인 목록)',sorted(rows197.values()),80,lvl='warn')
for v in R.values():v.setdefault('lvl','report')
json.dump(R,open(os.path.join(B,'audit_ext.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=0)
print({k:v['n'] for k,v in R.items() if v['lvl'] in('err','warn')})
err={k:v['n'] for k,v in R.items() if v['n'] and v['lvl']=='err'};warn={k:v['n'] for k,v in R.items() if v['n'] and v['lvl']=='warn'}
STRICT=os.environ.get('NORIORI_AUDIT_STRICT')=='1'
print(f"audit_ext 오류 {len(err)}항목 {sum(err.values())}건, 경고 {len(warn)}항목 {sum(warn.values())}건 ({'엄격' if STRICT else '보고만'}, 원자료 차이 보고 항목은 세지 않음)")
if STRICT and err:sys.exit(1)
