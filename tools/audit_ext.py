# -*- coding: utf-8 -*-
# 완성된 DB를 원자료와 전수 대조한다. 파이프라인 코드를 재사용하지 않는다. 결과: build/audit_ext.json
import sqlite3,json,os,re,math,collections,csv,zipfile,unicodedata,sys
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
B=os.path.join(ROOT,'build')
m=sqlite3.connect(os.path.join(B,'master.sqlite'));n=sqlite3.connect(os.path.join(B,'names.sqlite'))
m.row_factory=sqlite3.Row
R=collections.OrderedDict()
def put(k,rows,lim=40,**kw):
    rows=list(rows);R[k]=dict(n=len(rows),sample=rows[:lim],**kw)
def nz(s):
    s=unicodedata.normalize('NFKC',s or '')
    s=re.sub(r'[〈<(（].*?[〉>)）]','',s).replace('【旧】','').strip('*[] ')
    for a,b in (('ヶ','ケ'),('ヵ','ケ'),('﨑','崎'),('髙','高'),('渕','淵'),('澤','沢'),('濱','浜'),('瀧','滝'),('條','条'),('龍','竜'),('國','国'),('會','会'),('櫻','桜'),('廣','広'),('德','徳'),('諌','諫'),('槇','槙'),('祗','祇'),('塚','塚'),('之','ノ')):s=s.replace(a,b)
    if len(s)>1 and s.endswith('駅'):s=s[:-1]
    return s.replace(' ','')
ja=collections.defaultdict(list);alias=collections.defaultdict(list)
for t,i,x in n.execute("select entity_type,entity_id,text from name where lang='ja' and valid_to is null"):ja[t,i].append(x)
for i,x in n.execute("select entity_id,text from alias where entity_type='node' and kind<>'old_title'"):alias[i].append(x)
def names(i):return {nz(x) for x in ja['node',i]+alias[i]}
def nn(i):return ja['node',i][0] if ja['node',i] else i
def ln(i):return ja['line',i][0] if ja['line',i] else i
routes={r['id']:dict(r) for r in m.execute('select * from route')}
stops=collections.defaultdict(list)
for r in m.execute('select * from route_stop where is_extension=0 order by route_id,seq'):stops[r['route_id']].append(dict(r))
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
arch={nz(t) for t, in n.execute("select text from name where entity_type='archive' and lang='ja'")}
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
W=json.load(open(os.path.join(ROOT,'data/imports/wiki_station.json'),encoding='utf-8'))
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
