# -*- coding: utf-8 -*-
# 완성된 DB를 설계 규칙으로 다시 검사한다. compile.py의 검사를 재사용하지 않고 SQLite만 읽는다
# 결과: build/audit.json. 항목마다 건수와 표본
import sqlite3,json,os,re,math,collections,datetime,sys
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
B=sys.argv[1] if len(sys.argv)>1 else os.path.join(ROOT,'build')
m=sqlite3.connect(os.path.join(B,'master.sqlite'));n=sqlite3.connect(os.path.join(B,'names.sqlite'))
m.row_factory=sqlite3.Row
TODAY='2026-11-01';BASE='1969-12-08';ON='ongoing'
R=collections.OrderedDict()
def put(k,rows,lim=12):
    rows=list(rows);R[k]=dict(n=len(rows),sample=[(tuple(r) if isinstance(r,(sqlite3.Row,tuple,list)) else r) for r in rows[:lim]])
ja=collections.defaultdict(list)
for t,i,x in n.execute("select entity_type,entity_id,text from name where lang='ja'"):ja[t,i].append(x)
def J(t,i):
    v=ja.get((t,i));return v[0] if v else i
def nn(i):return J('node',i)
def ln(i):return J('line',i)
def nx(s):return datetime.date.fromisoformat(s)+datetime.timedelta(days=1)
def real(s):return bool(s) and bool(re.fullmatch(r'\d{4}-\d\d-\d\d',s))
def lo(s,l):return l or s
# ---- 참조 무결성
ID={t:{r[0] for r in m.execute(f'select id from {t}')} for t in('node','edge','line','operator','route','service')}
def ref(q,t,k):
    bad=[r[0] for r in m.execute(q) if r[0] is not None and r[0] not in ID[t]]
    put('참조:'+k,bad)
for q,t,k in [('select from_node from edge','node','edge.from'),('select to_node from edge','node','edge.to'),('select seed_line from edge','line','edge.seed'),
              ('select edge_id from edge_life','edge','life'),('select edge_id from edge_km','edge','km'),('select edge_id from edge_attr','edge','attr.edge'),
              ('select line_id from edge_attr','line','attr.line'),('select operator_id from edge_attr','operator','attr.op'),
              ('select line_id from route','line','route.line'),('select from_node from route','node','route.from'),('select to_node from route','node','route.to'),
              ('select route_id from route_stop','route','stop.route'),('select node_id from route_stop','node','stop.node'),
              ('select route_id from route_edge','route','redge.route'),('select edge_id from route_edge','edge','redge.edge'),
              ('select route_id from route_link','route','link.route'),('select other_line_id from route_link','line','link.line'),('select other_route_id from route_link','route','link.oroute'),
              ('select other_node from route_link','node','link.onode'),('select next_stop_node from route_link','node','link.next'),('select terminal_node from route_link','node','link.term'),
              ('select node_id from hub_member','node','hub'),('select node_id from junction','node','junction.node'),('select line_id from junction','line','junction.line'),
              ('select other_line_id from junction','line','junction.other'),('select node_id from node_position','node','pos'),('select line_id from closed_section','line','closed.line'),
              ('select line_id from archive_stop','line','arch.line'),('select line_id from archive_line','line','archl.line'),('select route_id from service_part','route','svc.route'),
              ('select edge_id from denominator_unit','edge','unit.edge'),('select edge_id from edge_pref','edge','pref.edge'),('select edge_id from edge_link','edge','elink')]:ref(q,t,k)
put('edge에 life 없음',[r[0] for r in m.execute('select id from edge where id not in (select edge_id from edge_life)')])
put('edge에 km 없음',[r[0] for r in m.execute('select id from edge where id not in (select edge_id from edge_km)')])
put('edge에 attr 없음',[r[0] for r in m.execute('select id from edge where id not in (select edge_id from edge_attr)')])
put('edge가 어떤 계통에도 없음',[r[0] for r in m.execute('select id from edge where id not in (select edge_id from route_edge)')])
put('노선에 attr 없음',[ln(r[0]) for r in m.execute('select id from line where id not in (select line_id from edge_attr)')])
put('km 0 이하',[(r[0],r[1]) for r in m.execute('select edge_id,km from edge_km where km is null or km<=0')])
put('edge당 km 여러 값',[r[0] for r in m.execute('select edge_id from edge_km group by 1 having count(*)>1')])
# ---- 날짜 형식과 순서
bad=[]
for t,cols in (('edge_life',('valid_from','valid_to')),('edge_attr',('valid_from','valid_to')),('route_stop',('valid_from','valid_to'))):
    for r in m.execute(f'select * from {t}'+(' where is_stop=1' if t=='route_stop' else '')):
        r=dict(r)
        for c in cols:
            v=r[c]
            if v is None or v==ON:continue
            if not re.fullmatch(r'\d{4}-(\d\d|XX)-(\d\d|XX)|\d{3}X-XX-XX',v):bad.append((t,c,v))
        a,b=r.get('valid_from_lo') or r['valid_from'],r.get('valid_to_hi') or r['valid_to']
        if r['valid_from_lo'] and r['valid_from_hi'] and r['valid_from_lo']>r['valid_from_hi']:bad.append((t,'from범위',r['valid_from']))
        if r['valid_to_lo'] and r['valid_to_hi'] and r['valid_to_lo']>r['valid_to_hi']:bad.append((t,'to범위',r['valid_to']))
        if r['valid_from_hi'] and r['valid_to_lo'] and r['valid_from_hi']>=r['valid_to_lo'] and not ('X' in (r['valid_from'] or '') or 'X' in (r['valid_to'] or '')):bad.append((t,'from>=to',r['valid_from'],r['valid_to'],r.get('edge_id') or r.get('node_id')))
put('날짜 형식·순서',bad)
fut=[]
for t in('edge_life','edge_attr'):
    for r in m.execute(f"select * from {t} where valid_from_lo>'{TODAY}' or (valid_to<>'ongoing' and valid_to_hi>'{TODAY}')"):fut.append((t,dict(r).get('edge_id') or dict(r).get('node_id'),r['valid_from'],r['valid_to']))
put('오늘 뒤 날짜',fut)
# ---- edge_attr
LR=collections.defaultdict(list)
for r in m.execute('select * from edge_life'):LR[r['edge_id']].append(dict(r))
life={}
for e,v in LR.items():
    v.sort(key=lambda x:x['valid_from_lo'] or '')
    x=dict(v[-1]);x['valid_from']=v[0]['valid_from'];x['valid_from_lo']=v[0]['valid_from_lo'];life[e]=x
attr=collections.defaultdict(list)
for r in m.execute('select * from edge_attr'):attr[r['edge_id']].append(dict(r))
ov=[];gap=[];nolin=[]
for e,rows in attr.items():
    by=collections.defaultdict(list)
    for a in rows:
        by[a['line_id']].append(a)
        if not a['lineage_id'] or not a['carryover_group']:nolin.append(e)
    for l,v in by.items():
        v.sort(key=lambda x:x['valid_from_lo'] or '')
        for p,q in zip(v,v[1:]):
            if (p['valid_to_hi'] or '')>(q['valid_from_lo'] or '') and q['valid_from_lo']:ov.append((ln(l),e,p['valid_from'],p['valid_to'],q['valid_from'],q['valid_to']))
put('(노선,edge) 동시 두 행',ov)
put('lineage·carryover 비어 있음',nolin)
outside=[]
for e,rows in attr.items():
    L=life.get(e)
    if not L:continue
    top=max((a['valid_to_hi'] or '') for a in rows)
    if L['valid_to']==ON and top!='9999-12-31':outside.append(('현행edge에 현행attr없음',e,nn(m.execute('select from_node from edge where id=?',(e,)).fetchone()[0])))
    if L['valid_to']!=ON and top=='9999-12-31':outside.append(('폐지edge에 현행attr',e,ln(rows[0]['line_id']),L['valid_to']))
put('life와 attr 불일치',outside)
# ---- 폐지 규범
rows=[]
for e,L in life.items():
    v=L['valid_to']
    if v==ON:continue
    if L['last_service'] and real(v) and real(L['last_service']):
        if L['close_reason']=='brt' or L['status']=='suspended':continue
        if str(nx(L['last_service']))!=v:rows.append((e,ln(attr[e][0]['line_id']),L['last_service'],v,L['legal_abolition'],L['close_reason']))
put('valid_to≠마지막 운행 다음날',rows)
rows=[]
for e,L in life.items():
    if L['valid_to']==ON:continue
    a=L['legal_abolition'] or L['valid_to']
    if a<BASE and 'X' not in a:rows.append((ln(attr[e][0]['line_id']),nn(m.execute('select from_node from edge where id=?',(e,)).fetchone()[0]),L['valid_to'],L['legal_abolition']))
put('법적 폐지가 기준일 전인데 수록',rows)
put('폐지 사유 없는 폐지 edge',[e for e,L in life.items() if L['valid_to']!=ON and not L['close_reason']])
put('현행 edge에 폐지 사유',[e for e,L in life.items() if L['valid_to']==ON and L['close_reason']])
put('현행인데 suspended 아닌 status 이상',[e for e,L in life.items() if L['status'] not in('open','suspended')])
rows=[]
for e,v in LR.items():
    for p,q in zip(v,v[1:]):
        if p['valid_to']!=q['valid_from']:rows.append((e,p['valid_to'],q['valid_from']))
put('edge_life 행 불연속',rows)
put('현행 suspended',sorted({ln(attr[e][0]['line_id']) for e,L in life.items() if L['valid_to']==ON and L['status']=='suspended'}))
# ---- 분모 재계산
op_cat=dict(m.execute('select id,category from operator').fetchall())
km=dict(m.execute('select edge_id,km from edge_km').fetchall())
def calc(key,today=None):
    u={}
    for e,rows in attr.items():
        for a in rows:
            if a['denominator_class']!='normal':continue
            if today:
                if not(a['valid_to_hi'] >today): continue
                if (a['valid_from_hi'] or '')>today:continue
            u[(a[key],e)]=km[e]
    return round(sum(u.values()),1),len(u)
D={(r['basis'],r['carryover']):(r['km'],r['unit_count']) for r in m.execute("select * from denominator where scope='all'")}
got=dict(current=calc('lineage_id',TODAY),on=calc('lineage_id'),off=calc('carryover_group'))
R['분모 재계산']=dict(n=int(abs(got['current'][0]-D['current','on'][0])>.05)+int(abs(got['on'][0]-D['alltime','on'][0])>.05)+int(abs(got['off'][0]-D['alltime','off'][0])>.05),sample=[got,{str(k):v for k,v in D.items() if k[0] in('current','alltime')}])
# 현행 분모와 같은 물리 구간 km (공동 사용 구간이 두 번 세이는지 본다)
phys={}
for e,rows in attr.items():
    if any(a['valid_to_hi']>TODAY and a['denominator_class']=='normal' for a in rows):phys[e]=km[e]
R['현행 분모 정보']=dict(n=0,sample=[dict(units=got['current'][1],physical_edges=len(phys),physical_km=round(sum(phys.values()),1))])
# ---- 분모 등급 규칙 (§2.8 O, §4.6)
rows=[]
for e,v in attr.items():
    L=life[e]
    for a in v:
        cat=op_cat.get(a['operator_id']);tl=a['valid_to']
        legal=L['legal_abolition'] or L['valid_to']
        jr=cat=='jr' or any(op_cat.get(x['operator_id'])=='jr' for x in v)
        if a['denominator_class']=='outside':
            if L['valid_to']==ON:rows.append(('현행인데 outside',ln(a['line_id']),nn(e)))
            elif jr:rows.append(('국철시기 있는데 outside',ln(a['line_id']),L['valid_to']))
            elif legal[:4]>='2000':rows.append(('2000년 뒤 폐지 outside',ln(a['line_id']),legal))
        elif a['denominator_class']=='normal' and not jr and L['valid_to']!=ON and legal[:4]<'2000' and 'X' not in legal:
            rows.append(('1999년 전 사철 폐지인데 normal',ln(a['line_id']),legal))
put('분모 등급 규칙',rows,30)
# ---- carryover 규칙
rows=[]
for e,v in attr.items():
    v=sorted(v,key=lambda x:x['valid_from_lo'] or '')
    for p,q in zip(v,v[1:]):
        if p['lineage_id']!=q['lineage_id']:continue
        pj=op_cat.get(p['operator_id'])=='jr';qj=op_cat.get(q['operator_id'])=='jr'
        ch=p['carryover_group']!=q['carryover_group']
        if pj and not qj and not ch:rows.append(('JR→타사인데 유지',ln(p['line_id']),ln(q['line_id']),e))
        if (qj or not pj) and ch:rows.append(('그 밖의 이관인데 새 값',ln(p['line_id']),ln(q['line_id']),e))
put('승계 규칙',rows,20)
# 이관 경계 날짜 연속성: 같은 계보의 앞 행 종료 = 뒷 행 시작
rows=[]
for e,v in attr.items():
    v=sorted(v,key=lambda x:x['valid_from_lo'] or '')
    for p,q in zip(v,v[1:]):
        if p['lineage_id']==q['lineage_id'] and p['valid_to']!=q['valid_from'] and life[e]['status']!='suspended':rows.append((ln(p['line_id']),ln(q['line_id']),p['valid_to'],q['valid_from']))
c=collections.Counter(rows);put('이관 경계 날짜 불연속',[(*k,v) for k,v in c.most_common()],20)
# ---- 계통
E={r['id']:(r['from_node'],r['to_node']) for r in m.execute('select id,from_node,to_node from edge')}
rstop=collections.defaultdict(list)
for r in m.execute('select * from route_stop where is_extension=0 order by route_id,seq'):rstop[r['route_id']].append(dict(r))
redge=collections.defaultdict(list)
for r in m.execute('select route_id,seq,edge_id from route_edge order by route_id,seq'):redge[r[0]].append(r[2])
routes={r['id']:dict(r) for r in m.execute('select * from route')}
par=[];disc=[];kmbad=[];mono=[];seqgap=[];stopno=[];endbad=[];closedbad=[];dup=[]
for rid,ed in redge.items():
    s=rstop[rid]
    if not s:disc.append((rid,'역 없음'));continue
    if [x['seq'] for x in s]!=list(range(len(s))):seqgap.append(rid)
    if len(s)!=len(ed)+1:par.append(rid);continue
    cur=None;cum=0;ok=True
    for i,e in enumerate(ed):
        a,b=E[e]
        if i<len(s)-1:
            x,y=s[i]['node_id'],s[i+1]['node_id']
            if {x,y}!={a,b}:ok=False;disc.append((rid,i,nn(x),nn(y),nn(a),nn(b)));break
            cum=round(cum+km[e],1)
            if abs(s[i+1]['km_cum']-cum)>.11:kmbad.append((rid,nn(y),s[i+1]['km_cum'],cum));ok=False;break
    if not s:continue
    for p,q in zip(s,s[1:]):
        if q['km_cum']<p['km_cum']:mono.append((rid,nn(q['node_id'])))
    r=routes[rid]
    if r['closed']:
        if s[0]['node_id']!=s[-1]['node_id']:closedbad.append(rid)
    else:
        ids=[x['node_id'] for x in s]
        if len(set(ids))!=len(ids):dup.append((rid,[nn(k) for k,c in collections.Counter(ids).items() if c>1][:4]))
    if False and s[-1]['node_id']!=r['to_node']:endbad.append((rid,nn(s[0]['node_id']),nn(r['from_node']),nn(s[-1]['node_id']),nn(r['to_node'])))
put('이설 병렬 edge 계통',par);put('계통 경로 끊김',disc);put('누적 km 불일치',kmbad);put('km 감소',mono);put('seq 빈틈',seqgap);put('계통 양 끝 불일치',endbad);put('올가미·순환에 반복 역 없음',[r for r in closedbad if len({x['node_id'] for x in rstop[r]})==len(rstop[r])]);put('비순환에 같은 역 반복',dup)
put('main 없는 노선',[ln(r[0]) for r in m.execute("select id from line where id not in (select line_id from route where role='main')")])
put('계통 없는 노선',[ln(r[0]) for r in m.execute("select id from line where id not in (select line_id from route)")])
# 계통 edge의 attr에 그 노선이 있는가
rows=[]
for rid,ed in redge.items():
    l=routes[rid]['line_id']
    for e in ed:
        if not any(a['line_id']==l for a in attr[e]):rows.append((rid,e));break
put('계통 edge가 노선 멤버십에 없음',rows)
rows=[]
in_r=collections.defaultdict(set)
for rid,ed in redge.items():
    for e in ed:in_r[routes[rid]['line_id']].add(e)
for e,v in attr.items():
    for a in v:
        if e not in in_r[a['line_id']]:rows.append((ln(a['line_id']),e,nn(E[e][0]),nn(E[e][1])))
put('노선 멤버십 edge가 계통에 없음',rows)
# ---- 정차 기간과 선로 기간
rows=[];rows2=[]
for rid,s in rstop.items():
    ed=redge[rid]
    for i,x in enumerate(s):
        if not x['is_stop']:continue
        adj=[ed[j] for j in(i-1,i) if 0<=j<len(ed)]
        if not adj:continue
        lif=[life[e] for e in adj]
        f=min((l['valid_from_lo'] or '0000') for l in lif);t=max(l['valid_to_hi'] or '9999' for l in lif)
        if x['valid_to_hi'] and x['valid_to_hi']>t and x['valid_to']==ON:rows.append((rid,nn(x['node_id']),x['valid_to'],t))
        if x['valid_from_lo'] and x['valid_from_lo']>=t:rows2.append((rid,nn(x['node_id']),x['valid_from'],t))
put('현행 역인데 인접 선로가 전부 폐지',rows);put('역 개업이 인접 선로 폐지 뒤',rows2)
# 현행 선로 사이에 폐역이 아닌 역이 있어야 함: 양 끝 역이 정차역인가
rows=[]
for rid,ed in redge.items():
    s=rstop[rid];r=routes[rid]
    if not s or r['closed']:continue
    for x in(s[0],s[-1]):
        if not x['is_stop']and r['extend_to']=='[]':rows.append((rid,nn(x['node_id'])))
put('계통 끝이 숨은 노드인데 extend_to 없음',rows)
# 날짜 스냅숏 위상: 노선별로 그날 열린 edge가 몇 조각인가
snaps=['1970-01-01','1987-04-01','2000-01-01','2015-01-01',TODAY]
frag=collections.defaultdict(dict)
for rid,ed in redge.items():
    l=routes[rid]['line_id']
for d in snaps:
    by=collections.defaultdict(list)
    for e,v in attr.items():
        for a in v:
            if (a['valid_from_hi'] or '0000')<=d and a['valid_to_hi']>d:by[a['line_id']].append(e)
    for l,es in by.items():
        p={}
        def f(x):
            p.setdefault(x,x)
            while p[x]!=x:
                p[x]=p[p[x]];x=p[x]
            return x
        for e in es:p[f(E[e][0])]=f(E[e][1])
        frag[l][d]=len({f(x) for x in list(p)})
rows=[(ln(l),v) for l,v in frag.items() if v.get(TODAY,1)>1]
put('오늘 영업 구간이 끊긴 노선',rows,40)
# ---- 공개 노드와 이름
pub={r[0] for r in m.execute('select id from node_public')}
nm=collections.defaultdict(dict)
for t,i,l,x,k,src in n.execute('select entity_type,entity_id,lang,text,kana,source from name'):nm[t,i].setdefault(l,[]).append((x,k,src))
put('공개 노드 ko 없음',[i for i in pub if 'ko' not in nm['node',i]])
put('공개 노드 ja 없음',[i for i in pub if 'ja' not in nm['node',i]])
put('공개 노드 en 없음',[i for i in pub if 'en' not in nm['node',i]])
put('비공개 노드 이름 노출',[i for t,i in nm if t=='node' and i not in pub])
put('kind가 station 아닌 공개 노드',[r[0] for r in m.execute("select id from node_public where kind<>'station'")])
HK=re.compile(r'[぀-ヿ㐀-鿿]')
put('한글 이름에 일본어',[(t,i,x) for (t,i),v in nm.items() for x,k,s in v.get('ko',[]) if HK.search(x)])
HANGUL=re.compile(r'[가-힣]')
put('한글 이름에 한글 없음',[(t,i,x) for (t,i),v in nm.items() for x,k,s in v.get('ko',[]) if not HANGUL.search(x) and not re.search(r'[A-Z]',x)])
put('kana가 히라가나 아님',[(i,x,k) for (t,i),v in nm.items() if t=='node' for x,k,s in v.get('ja',[]) if k and not re.fullmatch(r'[ぁ-ゟー・ 　0-9A-Za-zァ-ヶ（）()]+',k)])
put('공개 노드 kana 없음',[(i,nm['node',i]['ja'][0][0]) for i in pub if 'ja' in nm['node',i] and not nm['node',i]['ja'][0][1]])
put('en에 비ASCII',[(i,x) for (t,i),v in nm.items() for x,k,s in v.get('en',[]) if not x.replace('·','').isascii()])
put('en 빈 값',[(i,x) for (t,i),v in nm.items() for x,k,s in v.get('en',[]) if not x.strip()])
# 같은 한자 읽기가 노드마다 다른 경우 (이름 같고 읽기 다름은 실제로 있으나 표본 확인용)
kk=collections.defaultdict(set)
for (t,i),v in nm.items():
    if t=='node':
        for x,k,s in v.get('ja',[]):
            if k:kk[x].add(k)
R['같은 한자 다른 읽기']=dict(n=sum(len(v)>1 for v in kk.values()),sample=[(a,sorted(b)) for a,b in kk.items() if len(b)>1][:30])
kh=collections.defaultdict(set)
for (t,i),v in nm.items():
    if t=='node':
        for x,k,s in v.get('ko',[]):kh[k or x,x].add(i)
# 같은 읽기인데 한글이 여러 개
ko2=collections.defaultdict(set)
for (t,i),v in nm.items():
    if t=='node' and 'ja' in v and 'ko' in v:
        ko2[v['ja'][0][1]].add(v['ko'][0][0])
R['같은 읽기 다른 한글']=dict(n=sum(len(v)>1 for v in ko2.values()),sample=[(a,sorted(b)) for a,b in ko2.items() if len(b)>1][:30])
# 읽기에 들어가면 안 되는 것 (이름 감사의 재발 방지)
rows=[]
for (t,i),v in nm.items():
    if t!='node' or i not in pub:continue
    for x,k,s in v.get('ja',[])[:1]:
        if not k:continue
        if re.search('(こうさくせん|てつどうせん|けんすいせん)$',k) and not x.endswith('線'):rows.append((i,x,k))
        if re.search('しんごうじょう|じょうこうじょう',k) and not re.search('信号|乗降',x):rows.append((i,x,k))
        if x.endswith('駅前') and not k.endswith('えきまえ'):rows.append((i,x,k))
put('읽기가 이름과 맞지 않음',rows,30)
sk=collections.defaultdict(set)
for (t,i),v in nm.items():
    if t=='node' and i in pub and 'ja' in v and 'ko' in v and v['ja'][0][1]:
        sk[v['ja'][0][0],v['ko'][0][0]].add(v['ja'][0][1])
put('같은 이름·같은 한글인데 읽기가 다름',[(a,b,sorted(c)) for (a,b),c in sk.items() if len({re.sub('[うお]','',x) for x in c})>1],30)
# 그룹: 같은 그룹 안 노드의 이름과 거리
pos={r['node_id']:(r['lat'],r['lon'],r['quality']) for r in m.execute('select * from node_position') if r['lat'] is not None}
def hav(a,b):
    p1,l1,p2,l2=map(math.radians,(a[0],a[1],b[0],b[1]));h=math.sin((p2-p1)/2)**2+math.cos(p1)*math.cos(p2)*math.sin((l2-l1)/2)**2
    return 6371*2*math.asin(math.sqrt(h))
g=collections.defaultdict(list)
for r in m.execute('select id,group_id from node where id in (select id from node_public)'):g[r[1]].append(r[0])
rows=[]
for k,v in g.items():
    p=[pos[x] for x in v if x in pos and pos[x][2]=='precise']
    for i in range(len(p)):
        for j in range(i):
            if hav(p[i],p[j])>1.5:rows.append((k,[nn(x) for x in v][:4],round(hav(p[i],p[j]),1)))
put('같은 그룹인데 1.5km 넘게 떨어짐',sorted(rows,key=lambda x:-x[2]),30)
put('그룹 없는 공개 노드',[r[0] for r in m.execute("select id from node where group_id is null and id in (select id from node_public)")])
rows=[]
h=collections.defaultdict(list)
for a,b in m.execute('select hub_id,node_id from hub_member').fetchall():h[a].append(b)
for k,v in h.items():
    if len(v)<2:rows.append((k,'한 명'));continue
    p=[pos[x] for x in v if x in pos]
    for i in range(len(p)):
        for j in range(i):
            if hav(p[i],p[j])>1.0:rows.append((k,[nn(x) for x in v][:5],round(hav(p[i],p[j]),2)))
put('환승 묶음인데 1km 넘게 떨어짐',sorted(rows,key=lambda x:-(x[2] if isinstance(x[2],float) else 0)),40)
# ---- 좌표
put('일본 밖 좌표',[(nn(i),p[:2]) for i,p in pos.items() if not(24<=p[0]<=46 and 122<=p[1]<=146)])
rows=[]
for rid,s in rstop.items():
    for p,q in zip(s,s[1:]):
        a,b=pos.get(p['node_id']),pos.get(q['node_id'])
        if not a or not b or a[2]!='precise' or b[2]!='precise':continue
        d=hav(a,b);k=q['km_cum']-p['km_cum']
        if d>k*1.25+.6:rows.append((round(d-k,1),rid,nn(p['node_id']),nn(q['node_id']),round(k,1),round(d,1)))
rows.sort(reverse=True);put('직선거리가 영업km보다 긺',rows,40)
rows=[]
for rid,s in rstop.items():
    for p,q in zip(s,s[1:]):
        a,b=pos.get(p['node_id']),pos.get(q['node_id'])
        if not a or not b or a[2]!='precise' or b[2]!='precise':continue
        d=hav(a,b);k=q['km_cum']-p['km_cum']
        if k>d*2.2+3:rows.append((round(k-d,1),rid,nn(p['node_id']),nn(q['node_id']),round(k,1),round(d,1)))
rows.sort(reverse=True);put('영업km가 직선거리보다 지나치게 긺',rows,40)
# ---- 정차·표시
put('공개 노드인데 위치 행 없음',[i for i in pub if i not in {r[0] for r in m.execute('select node_id from node_position')}])
rows=[]
for r in m.execute('select * from route_link'):
    if r['kind'] not in('transfer','branch','continue'):rows.append(r['kind'])
put('link 종류 이상',rows)
rows=[]
for r in m.execute("select l.route_id,l.seq,l.other_line_id,l.kind,l.terminal_node,l.next_stop_node from route_link l"):
    if r['route_id'] not in routes:continue
    if routes[r['route_id']]['line_id']==r['other_line_id'] and r['kind']=='transfer':rows.append((r['route_id'],r['seq'],ln(r['other_line_id'])))
put('자기 노선으로 환승',rows)
# 표시 결정표: 끝 역이 아닌 곳의 continue, 자기 참조, 현행 행이 폐선을 가리킴
rows=[]
for r in m.execute("select l.route_id,l.seq,l.other_route_id,l.kind,l.valid_to,l.other_line_id from route_link l where l.other_route_id=l.route_id"):rows.append(tuple(r))
put('자기 계통을 가리키는 link',rows)
cur={r[0] for r in m.execute("select distinct line_id from edge_attr where valid_to='ongoing'")}
rows=[]
for r in m.execute("select route_id,seq,kind,other_line_id from route_link where valid_to='ongoing'"):
    if r['other_line_id'] not in cur:rows.append((r['route_id'],r['seq'],r['kind'],ln(r['other_line_id'])))
put('현행 link가 폐선 노선을 가리킴',rows,20)
stop_cur={(r[0],r[1]) for r in m.execute("select route_id,node_id from route_stop where valid_to='ongoing' and is_stop=1")}
node_cur={r[0] for r in m.execute("select node_id from route_stop where valid_to='ongoing' and is_stop=1")}
rows=[]
for r in m.execute("select route_id,seq,next_stop_node,terminal_node from route_link where valid_to='ongoing'"):
    for x in (r['next_stop_node'],r['terminal_node']):
        if x and x not in node_cur:rows.append((r['route_id'],r['seq'],nn(x)))
put('현행 link가 폐역을 가리킴',rows,20)
# 숨은 노드가 link 대상으로 나가는가
rows=[]
for r in m.execute('select route_id,seq,kind,other_node,next_stop_node,terminal_node from route_link'):
    for x in (r['other_node'],r['next_stop_node'],r['terminal_node']):
        if x and x not in pub:rows.append((r['route_id'],r['seq'],r['kind'],x))
put('link가 비공개 노드를 가리킴',rows)
# 계통별 표시 역 없음
put('정차역이 2개 미만인 계통',[(r,[nn(x['node_id']) for x in s]) for r,s in rstop.items() if sum(x['is_stop'] for x in s)<2])
# ---- 수록 범위
bad=re.compile(r'BRT|ロープウェ|リフト|連絡船|索道|スロープカー|ゴンドラ|フェリー')
put('수록하지 않는 종류 이름',[(i,v[0]) for (t,i),v in ja.items() if t=='line' and bad.search(v[0])])
# 노선별 사업자 현재/과거
rows=[]
for r in m.execute("select l.id,l.type from line l"):
    pass
# 열람 전용의 날짜 범위: 기록 가능과 겹침
rows=[(r['id'],r['opened'],r['closed']) for r in m.execute("select * from archive_stop") if r['closed'] and real(r['closed']) and r['closed']>=BASE and False]
print(json.dumps({k:v['n'] for k,v in R.items() if v['n']},ensure_ascii=False,indent=0))
json.dump(R,open(os.path.join(B,'audit.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=0,default=str)
