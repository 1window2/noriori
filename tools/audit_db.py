# -*- coding: utf-8 -*-
# 완성된 DB를 설계 규칙으로 다시 검사한다. compile.py의 검사를 재사용하지 않고 SQLite만 읽는다
# 결과: build/audit.json. 항목마다 건수와 표본
import sqlite3,json,os,re,math,collections,datetime,sys
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
B=sys.argv[1] if len(sys.argv)>1 else os.path.join(ROOT,'build')
m=sqlite3.connect(os.path.join(B,'master.sqlite'));n=sqlite3.connect(os.path.join(B,'names.sqlite'))
m.row_factory=sqlite3.Row
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from lib import AS_OF,lohi,znorm as znorm_
TODAY=AS_OF;BASE='1950-01-01';ON='ongoing'
R=collections.OrderedDict()
# 항목 단계: err(결함. NORIORI_AUDIT_STRICT=1이면 하나라도 있을 때 실패)·warn(사람이 볼 후보)·info(정보, 건수 0)
# ids는 행에 나온 ID 전부다. 회귀 대조(tools/dev/regression)가 지적 대상이 아직 걸리는지 이것으로 본다
IDK=re.compile(r'^(?:n|r|l|e|a|o|hub)_[0-9a-z_]+$')
def _ids(x,o):
    if isinstance(x,str):
        if IDK.match(x):o.add(x)
    elif isinstance(x,dict):
        for y in x.values():_ids(y,o)
    elif isinstance(x,(tuple,list,set,frozenset,sqlite3.Row)):
        for y in x:_ids(y,o)
def put(k,rows,lim=12,lvl='err'):
    rows=list(rows);ids=set()
    for r in rows:_ids(r,ids)
    R[k]=dict(n=len(rows),lvl=lvl,sample=[(tuple(r) if isinstance(r,(sqlite3.Row,tuple,list)) else r) for r in rows[:lim]],ids=sorted(ids))
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
              ('select line_id from archive_stop','line','arch.line'),('select line_id from archive_line','line','archl.line'),('select route_id from service_part','route','svc.route'),('select node_id from service_stop','node','svc.stop'),
              ('select edge_id from denominator_unit','edge','unit.edge'),('select edge_id from edge_pref','edge','pref.edge'),('select edge_id from edge_link','edge','elink')]:ref(q,t,k)
put('edge에 life 없음',[r[0] for r in m.execute('select id from edge where id not in (select edge_id from edge_life)')])
put('edge에 km 없음',[r[0] for r in m.execute('select id from edge where id not in (select edge_id from edge_km)')])
put('edge에 attr 없음',[r[0] for r in m.execute('select id from edge where id not in (select edge_id from edge_attr)')])
put('edge가 어떤 계통에도 없음',[r[0] for r in m.execute('select id from edge where id not in (select edge_id from route_edge)')])
# 표시용 버스 노선(type bus, data/overrides/bus_through.json)은 edge·계통 없이 끝 이어짐으로만 보인다 (DESIGN '버스 구간 직통')
BUSL={r[0] for r in m.execute("select id from line where type='bus'")}
put('노선에 attr 없음',[ln(r[0]) for r in m.execute('select id from line where id not in (select line_id from edge_attr)') if r[0] not in BUSL])
put('표시용 버스 노선에 edge·계통이 있음',[ln(l) for l in BUSL if m.execute('select 1 from edge_attr where line_id=? union select 1 from route where line_id=?',(l,l)).fetchone()])
# 나뉜 역(station_split)의 같은 km 점 칸은 0 km다 (11회차 S1)
_SS0={r[0] for r in m.execute('select edge_id from station_split where edge_id is not null')} if m.execute("select 1 from sqlite_master where type='table' and name='station_split'").fetchone() else set()
put('km 0 이하',[(r[0],r[1]) for r in m.execute('select edge_id,km from edge_km where km is null or km<0 or (km=0 and edge_id not in (%s))'%','.join("'"+x+"'" for x in _SS0 or ['-']))])
put('edge당 km 여러 값',[r[0] for r in m.execute('select edge_id from edge_km group by 1 having count(*)>1')])
# ---- 날짜 형식과 순서
bad=[]
for t,cols in (('edge_life',('valid_from','valid_to')),('edge_attr',('valid_from','valid_to')),('route_stop',('valid_from','valid_to'))):
    for r in m.execute(f'select * from {t}'+(' where is_stop=1' if t=='route_stop' else '')):
        r=dict(r)
        for c in cols:
            v=r[c]
            if v is None or v==ON:continue
            # EDTF 하루·달·해·연대와 「하나의 값」 범위 [A..B]·[..B]·[A..] (DESIGN §5.4, lib.lohi). 원문과 lo/hi 열이 맞아야 한다
            try:lo_,hi_=lohi(v)
            except ValueError:bad.append((t,c,v));continue
            if v.startswith('XXXX') or v=='[..]':bad.append((t,c,v));continue
            if (r[c+'_lo'],r[c+'_hi'])!=(lo_,hi_):bad.append((t,c+' lo/hi',v,r[c+'_lo'],r[c+'_hi']))
        if r['valid_from_lo'] and r['valid_from_hi'] and r['valid_from_lo']>r['valid_from_hi']:bad.append((t,'from범위',r['valid_from']))
        if r['valid_to_lo'] and r['valid_to_hi'] and r['valid_to_lo']>r['valid_to_hi']:bad.append((t,'to범위',r['valid_to']))
        # 범위가 겹치면 순서가 가능하다. 시작의 가장 이른 날이 끝의 가장 늦은 날 이상일 때만 확실히 비거나 거꾸로다 (길이 0 행 포함)
        if r['valid_from_lo'] and r['valid_to_hi'] and r['valid_from_lo']>=r['valid_to_hi']:bad.append((t,'from>=to',r['valid_from'],r['valid_to'],r.get('edge_id') or (r.get('route_id'),r.get('node_id'))))
put('날짜 형식·순서',bad)
fut=[]
# 역 정차 기간도 본다. 폐지 범위의 끝이 열려 있으면(「[1950-01-02..]」) 오늘 화면에 「영업 중일 수도」로 그려진다.
# 지금 역 목록(N02)에 없으면 그 판의 날짜로 끝을 막는다 (西鉄 甘木線 鏡 등 6역, 사용자 지적 2026-11-18)
for t in('edge_life','edge_attr','route_stop'):
    for r in m.execute(f"select * from {t} where (valid_from_lo>'{TODAY}' or (valid_to<>'ongoing' and valid_to_hi>'{TODAY}'))"+(' and is_stop=1' if t=='route_stop' else '')):fut.append((t,dict(r).get('edge_id') or (dict(r).get('route_id'),dict(r).get('node_id')),r['valid_from'],r['valid_to']))
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
            # 앞 행 끝과 뒤 행 시작이 같은 원문(1952-06-XX)이면 같은 날 바뀐 것이다. 범위가 겹쳐 보여도 이어진 행
            if p['valid_to']==q['valid_from']:continue
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
# 운행을 다시 시작하지 않고 끝난 휴지(DESIGN §2.2, 결정 122): 운휴 뒤 재개 없이 닫힌 칸은 운휴 시작으로 소급해 닫혀야 하고(마지막 행이 suspended인 채 닫히면 안 됨),
# 법적 폐지일이 닫힌 날보다 늦으면 사유가 no_regular_service(이설·BRT는 그대로)다
# 다만 운휴 중 이설해 계승한 칸(폐지 사유 relocated이고 칸 끝 노드의 이전처 새 역이 닫힌 날 열림, 常磐線 駒ヶ嶺–浜吉田 2011→2016)은 운휴로 남는 것이 규칙이다
# (설계 audit5-relocation-successor-design.md, 사용자 결정 2026-11-24). compile의 _reloc_successor와 같은 조건이다
_MVD=collections.defaultdict(set)
for mv_ in json.load(open(os.path.join(ROOT,'data','overrides','moved.json'),encoding='utf-8')):_MVD[mv_['old']].add(mv_['date'])
def _reloc_ok(e,L):
    if L['close_reason']!='relocated':return False
    fr_,to_=m.execute('select from_node,to_node from edge where id=?',(e,)).fetchone()
    return any((L['valid_to'] or '')[:10] in _MVD.get(n_,()) for n_ in (fr_,to_))
put('운휴 뒤 재개 없이 닫힘(운휴 시작으로 소급 안 됨)',[(e,ln(attr[e][0]['line_id']) if attr.get(e) else '',v[-1]['valid_from'],v[-1]['valid_to']) for e,v in LR.items() if v[-1]['status']=='suspended' and v[-1]['valid_to']!=ON and not _reloc_ok(e,v[-1])],30)
put('법적 폐지가 닫힌 날보다 늦은데 사유 abolished',[(e,ln(attr[e][0]['line_id']) if attr.get(e) else '',L['valid_to'],L['legal_abolition']) for e,L in life.items() if L['close_reason']=='abolished' and L['legal_abolition'] and L['valid_to']!=ON and (lohi(L['legal_abolition'])[0] or '')>(lohi(L['valid_to'])[1] or '9999')],30)
put('폐지 사유 없는 폐지 edge',[e for e,L in life.items() if L['valid_to']!=ON and not L['close_reason']])
put('현행 edge에 폐지 사유',[e for e,L in life.items() if L['valid_to']==ON and L['close_reason']])
put('현행인데 suspended 아닌 status 이상',[e for e,L in life.items() if L['status'] not in('open','suspended')])
rows=[]
for e,v in LR.items():
    for p,q in zip(v,v[1:]):
        # 폐지(사유 있는 닫힘) 뒤 다시 연 칸은 그 사이가 비어 있는 것이 맞다(鹿島臨港線 1983 여객 폐지 → 2005 하루 臨時, 사용자 결정 2026-11-13)
        if p['valid_to']!=q['valid_from'] and not p.get('close_reason'):rows.append((e,p['valid_to'],q['valid_from']))
put('edge_life 행 불연속',rows)
# 지금 운휴 중인 노선은 검토용 목록이다 (suspended.json·official_lines susp에서 옴). 건수가 동결 조건(감사 0건)을 막지 않게 정보로만 둔다.
# 노선 이름은 지금 소속 행에서 읽는다 (첫 행은 옛 노선일 수 있다: 木原線 → いすみ線)
R['현행 운휴 정보']=dict(n=0,sample=sorted({(ln(a['line_id']),LR[e][-1]['valid_from']) for e,L in life.items() if L['valid_to']==ON and L['status']=='suspended' for a in attr[e] if a['valid_to']==ON}))
# ---- 분모 재계산
op_cat=dict(m.execute('select id,category from operator').fetchall())
km=dict(m.execute('select edge_id,km from edge_km').fetchall())
# 승계 끔의 국철·JR 단위는 3섹 전환 때 다시 정한 그 시대 km를 쓴다 (compile.py ERA, data/overrides/km_era.json).
# 그 값은 denominator_unit에만 있으므로 거기서 읽고, 시대 km가 국철·JR만의 승계 끔 단위에만 있는지 따로 본다
unitkm={(r['carryover'],r['unit_key']):r['km'] for r in m.execute('select carryover,unit_key,km from denominator_unit')}
def calc(key,today=None):
    u={}
    for e,rows in attr.items():
        for a in rows:
            if a['denominator_class']!='normal':continue
            if today:
                if not(a['valid_to_hi'] >today): continue
                if (a['valid_from_hi'] or '')>today:continue
            k=km[e]
            if key=='carryover_group':k=unitkm.get(('off',f"{a[key]}:{e}"),k)
            u[(a[key],e)]=k
    return round(sum(u.values()),1),len(u)
D={(r['basis'],r['carryover']):(r['km'],r['unit_count']) for r in m.execute("select * from denominator where scope='all'")}
got=dict(current=calc('lineage_id',TODAY),on=calc('lineage_id'),off=calc('carryover_group'))
rows=[]
# 9회차 S: 단위 km = 그 단위 마지막 행(끝이 가장 늦은 행) 노선의 시대 km, 없으면 칸 km(compile 단위 규칙). 승계 끔 국철·JR 단위만이 아니라
# 한 승계 단위 안에서 사업자 시기별로 km가 다른 칸(弘南 黒石線)도 같은 규칙이다. 검사 제목은 회귀 호환을 위해 그대로 두고 뜻을 넓힌다(시대 km가 마지막 행 규칙 밖에 있음)
_ERAK={(l,e):k for e,l,k in m.execute('select edge_id,line_id,km from edge_km_era')}
for (c,uk),v in unitkm.items():
    g,e=uk.rsplit(':',1)
    if e not in km:continue
    ats=[a for a in attr.get(e,[]) if a['carryover_group' if c=='off' else 'lineage_id']==g]
    if not ats:continue
    lr=max(ats,key=lambda a:(a['valid_to_hi'] or '9999-12-31',a['valid_from_lo'] or ''))
    want=_ERAK.get((lr['line_id'],e),km[e])
    if abs(v-want)>.0006:rows.append((c,uk,v,want))
put('시대 km가 국철·JR 승계 끔 단위 밖에 있음',rows)
R['분모 재계산']=dict(n=int(abs(got['current'][0]-D['current','on'][0])>.05)+int(abs(got['on'][0]-D['alltime','on'][0])>.05)+int(abs(got['off'][0]-D['alltime','off'][0])>.05),sample=[got,{str(k):v for k,v in D.items() if k[0] in('current','alltime')}])
# 현행 분모와 같은 물리 구간 km (공동 사용 구간이 두 번 세이는지 본다)
phys={}
for e,rows in attr.items():
    if any(a['valid_to_hi']>TODAY and a['denominator_class']=='normal' for a in rows):phys[e]=km[e]
R['현행 분모 정보']=dict(n=0,sample=[dict(units=got['current'][1],physical_edges=len(phys),physical_km=round(sum(phys.values()),1))])
# ---- 분모 등급 규칙 (§2.8 O, §4.6, §1.4 별선·단락선, 사용자 결정 2026-11-04·2026-11-09)
# outside는 판 2026-11-04.2에 모두 normal로 옮겨 0이어야 한다. 1999년 전 사철 폐선도 normal이다 (§4.6 표).
# 분모 밖은 extra(별선·단락선: 노선 rule_class extra이거나 모선의 extra 지선 계통 전용 칸)와 hidden(여객 이력 없는 화물선, 분모 단위 없음)뿐이다
line_rc=dict(m.execute('select id,rule_class from line').fetchall())
main_edges=collections.defaultdict(set)
for l,e in m.execute("select r.line_id,re.edge_id from route r join route_edge re on re.route_id=r.id where r.role='main'"):main_edges[l].add(e)
unit_cls=collections.defaultdict(set)
for c,uk,cl in m.execute('select carryover,unit_key,class from denominator_unit'):unit_cls[(c,uk)].add(cl)
# 사용자 판단 U18: 계통 끝 역이 km를 모르는 仮乗降場·臨時駅이고 그 노선 선로의 막다른 끝이면 그 끝 칸은 extra다 (小松島線 小松島港, compile 같은 규칙)
_mk_nodes={r_[0] for r_ in n.execute('select node_id from stop_mark')}
_line_e=collections.defaultdict(set)
for e,v in attr.items():
    for a in v:_line_e[a['line_id']].add(e)
_einc0=collections.defaultdict(set)
for e,a_,b_ in m.execute('select id,from_node,to_node from edge'):_einc0[a_].add(e);_einc0[b_].add(e)
U18E=set()
for rid_,L_ in m.execute('select id,line_id from route').fetchall():
    ss_=m.execute('select node_id,is_stop,km_estimated from route_stop where route_id=? order by seq',(rid_,)).fetchall()
    if not ss_:continue
    re_={r_[0] for r_ in m.execute('select edge_id from route_edge where route_id=?',(rid_,))}
    for x_,st_,est_ in (ss_[0],ss_[-1]):
        if st_ and est_ and x_ in _mk_nodes and len(_einc0[x_]&_line_e[L_])==1:U18E|={(L_,e) for e in _einc0[x_]&re_}
rows=[]
for e,v in attr.items():
    for a in v:
        cl=a['denominator_class'];rc=line_rc.get(a['line_id'])
        # 기록 기준일(1950-01-01) 전에 끝난 영업 행은 기록할 수 없어 분모 밖 extra다(날짜 모름 기록 크레딧이 떨어질 단위는 둠) (DESIGN §4.6 「기준일 이전 폐지」, compile K35)
        pre_=(a['valid_to_hi'] or '9999')<=BASE
        if cl not in('normal','extra','hidden'):rows.append(('알 수 없는 등급' if cl!='outside' else 'outside 남음',ln(a['line_id']),e,cl))
        elif rc=='shinkansen' and cl!='normal' and not (pre_ and cl=='extra'):rows.append(('신칸센인데 분모 밖',ln(a['line_id']),e,cl))
        elif rc in('extra','hidden') and cl!=rc and not (pre_ and cl=='extra' and rc!='hidden'):rows.append((f'노선 {rc}인데 칸 {cl}',ln(a['line_id']),e))
        # 정식 여객 영업이 끝난(닫힌) 뒤의 임시 운행은 분모 밖이다(鹿島臨港線 2005-10-16 하루, 사용자 결정 2026-11-13: 정식 영업 기간만 분모 안)
        elif rc not in('extra','hidden') and cl=='extra' and e in main_edges[a['line_id']] and (a['line_id'],e) not in U18E and not pre_ and not any(b['denominator_class']=='normal' and b['valid_to'] and b['valid_to']<=a['valid_from'] for b in v):rows.append(('normal 노선 본선 칸이 extra',ln(a['line_id']),e))
        elif rc not in('extra','hidden') and cl=='hidden':rows.append(('normal 노선 칸이 hidden',ln(a['line_id']),e))
# 분모 단위의 등급은 그 단위 멤버십 중 normal이 하나라도 있으면 normal (compile.py unit_rows). hidden은 단위가 없어야 한다
for c,key in(('on','lineage_id'),('off','carryover_group')):
    g=collections.defaultdict(list)
    for e,v in attr.items():
        for a in v:g[(c,f"{a[key]}:{e}")].append(a['denominator_class'])
    for k,cls in g.items():
        want='normal' if 'normal' in cls else cls[0]
        got=unit_cls.get(k)
        if want=='hidden':
            if got:rows.append(('hidden인데 분모 단위 있음',k))
        elif got!={want}:rows.append(('분모 단위 등급 불일치',k,want,sorted(got or [])))
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
        # 폐선 뒤 재개(open+continues, DESIGN §2.8 E 표 마지막 줄): 앞 행 끝에 칸이 사유 있게 닫혔다가 뒷 행 시작에 다시 열렸으면 그 사이가 비는 것이 맞다
        # (函館市電 湯の川線 湯の川温泉–湯の川 1945 폐지·1959 재개업, 八栗ケーブル 1944 소급 폐지·1964 재개업, 9회차 S)
        if p['lineage_id']==q['lineage_id'] and p['valid_to']!=q['valid_from'] and life[e]['status']!='suspended' and not any(r_['valid_to']==p['valid_to'] and r_['close_reason'] for r_ in LR[e]) :rows.append((ln(p['line_id']),ln(q['line_id']),p['valid_to'],q['valid_from']))
c=collections.Counter(rows);put('이관 경계 날짜 불연속',[(*k,v) for k,v in c.most_common()],20)
# ---- 계통
E={r['id']:(r['from_node'],r['to_node']) for r in m.execute('select id,from_node,to_node from edge')}
rstop=collections.defaultdict(list)
for r in m.execute('select * from route_stop order by route_id,seq'):rstop[r['route_id']].append(dict(r))
redge=collections.defaultdict(list)
for r in m.execute('select route_id,seq,edge_id from route_edge order by route_id,seq'):redge[r[0]].append(r[2])
routes={r['id']:dict(r) for r in m.execute('select * from route')}
# 옛 선형 계통(원본 계통 행 old, 2번안 2026-11-23). DB 계통 표에는 칸이 없어 원본(보정 포함)에서 읽는다
from lib import load as _load_src
_OLD_R={r_['id'] for r_ in _load_src('routes') if r_.get('old')}
# 여객 영업 이력이 없는 화물선(rule_class hidden)은 DB에만 두어 정차·끝 확장·이름이 없다. 공개 계통 검사에서 뺀다 (9회차 F, 그 대신 K110이 새는 길을 본다)
HIDL={r_[0] for r_ in m.execute("select id from line where rule_class='hidden'")}
par=[];disc=[];kmbad=[];mono=[];seqgap=[];stopno=[];endbad=[];closedbad=[];dup=[]
# route_edge는 순서 있는 길이 아니라 edge 묶음이다(seq는 route_stop.seq와 맞지 않을 수 있음, tools/appsim.py route_edges).
# 옛 선로 고리(이설, 常磐線 모델)와 막다른 옛 선로(女川(旧)·白山(旧)) 때문에 전체로는 길이 아닐 수 있다.
# 규칙: (1) 묶음이 연결되어 있고 그 노드가 정차 목록(연장 행 제외)과 같다 (2) 어느 날이든 그 계통 노선 소속으로 살아 있는 edge는
# 갈래·고리가 없는 길이다 (3) 전체가 한 줄 길인 계통은 이웃 역 사이 edge의 km로 누적 km를 맞춘다
AT=collections.defaultdict(list)
for e,v in attr.items():
    for a in v:AT[a['line_id'],e].append(a)
# 노선 시대 km(국철 계통의 3섹 전환 전 km, compile K22)와 옛 선로 칸(이설로 닫힌 칸·끝난 옛 경로 계통 전용 칸)
ERA0={(l,e):k for e,l,k in m.execute('select edge_id,line_id,km from edge_km_era')}
_RO0=dict(m.execute('select id,route_only from edge').fetchall())
OLDE={e for e,x in life.items() if x['close_reason']=='relocated' or (_RO0.get(e) and x['valid_to']!='ongoing')}
for rid,ed in redge.items():
    s=rstop[rid]
    if not s:disc.append((rid,'역 없음'));continue
    if [x['seq'] for x in s]!=list(range(len(s))):seqgap.append(rid)
    r=routes[rid];l=r['line_id']
    g=collections.defaultdict(set);nodes=set()
    for e in ed:a,b=E[e];g[a].add(b);g[b].add(a);nodes|={a,b}
    ids=[x['node_id'] for x in s]
    if nodes!=set(ids):disc.append((rid,'정차 목록과 edge 노드가 다름',[nn(x) for x in nodes^set(ids)][:4]));continue
    seen={ids[0]};st=[ids[0]]
    while st:
        x=st.pop()
        for y in g[x]-seen:seen.add(y);st.append(y)
    if seen!=nodes:disc.append((rid,'edge 묶음이 끊김',[nn(x) for x in nodes-seen][:4]));continue
    if not r['closed']:
        days=sorted({a['valid_from_lo'] or '0000' for e in ed for a in AT[l,e]})
        for d in days:
            live=[e for e in ed if any((a['valid_from_lo'] or '0000')<=d<(a['valid_to_hi'] or '9999') for a in AT[l,e])]
            deg=collections.Counter();p={}
            def f(x):
                p.setdefault(x,x)
                while p[x]!=x:p[x]=p[p[x]];x=p[x]
                return x
            cyc=False
            for e in live:
                a,b=E[e];deg[a]+=1;deg[b]+=1
                if f(a)==f(b):cyc=True
                p[f(a)]=f(b)
            br=[k for k,c in deg.items() if c>2]
            if br or cyc:par.append((rid,d,'고리' if cyc else '갈래',[nn(x) for x in br][:3]));break
    simple=len(ed)==len(nodes)-1 and all(len(g[x])<=2 for x in nodes)
    if simple:
        ek={}
        for e in ed:ek[frozenset(E[e])]=e
        cum=0
        for i in range(len(s)-1):
            x,y=s[i]['node_id'],s[i+1]['node_id']
            e=ek.get(frozenset((x,y)))
            if e is None:disc.append((rid,i,nn(x),nn(y),'이웃 역 사이 edge 없음'));break
            cum=round(cum+ERA0.get((l,e),km[e]),1)
            if abs(s[i+1]['km_cum']-s[0]['km_cum']-cum)>.11:kmbad.append((rid,nn(y),s[i+1]['km_cum'],cum));break
    # 옛 선로 역의 km는 실제 옛 営業キロ이고 순서는 seq로만 지킨다(compile K21). 옛 선로 역과 지금 선로 역이 번갈아 서는 곳은 km가 줄 수 있다
    oldst={x for x in ids if all(e in OLDE for e in ed if x in E[e])}
    for p_,q_ in zip(s,s[1:]):
        if q_['km_cum']<p_['km_cum'] and not {p_['node_id'],q_['node_id']}&oldst:mono.append((rid,nn(q_['node_id'])))
    if r['closed']:
        if s[0]['node_id']!=s[-1]['node_id']:closedbad.append(rid)
    else:
        if len(set(ids))!=len(ids):dup.append((rid,[nn(k) for k,c in collections.Counter(ids).items() if c>1][:4]))
put('이설 병렬 edge 계통',par);put('계통 경로 끊김',disc);put('누적 km 불일치',kmbad);put('km 감소',mono);put('seq 빈틈',seqgap);put('계통 양 끝 불일치',endbad);put('올가미·순환에 반복 역 없음',[r for r in closedbad if len({x['node_id'] for x in rstop[r]})==len(rstop[r])]);put('비순환에 같은 역 반복',dup)
put('main 없는 노선',[ln(r[0]) for r in m.execute("select id from line where id not in (select line_id from route where role='main')") if r[0] not in BUSL])
put('계통 없는 노선',[ln(r[0]) for r in m.execute("select id from line where id not in (select line_id from route)") if r[0] not in BUSL])
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
        # 기록 하한(1950) 전에 끝난 소속은 계통에 둘 필요가 없다 (徳島線 阿波池田–三縄 1931–1935)
        if a['valid_to']!=ON and a['valid_to_hi'] and a['valid_to_hi']<=BASE:continue
        if e not in in_r[a['line_id']]:rows.append((ln(a['line_id']),e,nn(E[e][0]),nn(E[e][1])))
put('노선 멤버십 edge가 계통에 없음',rows)
# ---- 공식 노선 구성 표의 폐지·휴지가 빌드에 실렸는가 (official_lines.json h의 廃止日 표, susp)
# 입력 표와 출력 수명을 노선(계통) 단위로 맞춘다. 환상선 구간(中央口～中央口)의 폐지가 빠져 万国博モノレール이 영업 중으로 남던 것(2026-11-11 고침)의 재발 방지
import unicodedata
def _nz(s):
    s=unicodedata.normalize('NFKC',str(s or ''))
    return re.sub(r'〈.*?〉|\(臨\)|【旧】|^\*|[\[\]]','',s).replace('ヶ','ケ').replace('ヵ','カ').strip()
def _nz2(s):return re.sub(r'[（(].*?[)）]','',_nz(s)).strip()
rows=[]
OFP=os.path.join(ROOT,'data','overrides','official_lines.json');NBP=os.path.join(ROOT,'data','imports','noritsubushi','lines.json')
if os.path.exists(OFP):
    NB={x['id']:x for x in json.load(open(NBP,encoding='utf-8'))} if os.path.exists(NBP) else {}
    RXT=re.compile(r'^(.+?)(?: \((.+?)\))? (\S.*?) ～ (\S.*?) 営業km: ([\d.]+)$')
    nname=collections.defaultdict(set)
    for (t_,i_),v_ in ja.items():
        if t_=='node':nname[i_]|={_nz(x) for x in v_}|{_nz2(x) for x in v_}
    for i_,x_ in m.execute('select id,export_name from node where export_name is not null'):nname[i_]|={_nz(x_),_nz2(x_)}
    rname=collections.defaultdict(list);rname_b=collections.defaultdict(list)
    def _nzb(x):
        m_=re.match(r'^(?:分岐点|接続点|交点)[（(](.+?)[)）]$',x.strip())
        return _nz2(m_.group(1)) if m_ else _nz2(x)
    for (t_,i_),v_ in ja.items():
        if t_=='route':
            for x_ in v_:
                a_,_,b_=x_.partition('～');rname[_nz(a_),_nz(b_)].append(i_);rname_b[_nzb(a_),_nzb(b_)].append(i_)
    eroutes=collections.defaultdict(set)
    for rid,ed in redge.items():
        for e in ed:eroutes[e].add(rid)
    for x in json.load(open(OFP,encoding='utf-8'))['rows']:
        if x['op']=='drop':continue
        s_=dict(NB.get(x.get('id'),{}),**x['set'])
        closes=[r_ for t_ in s_.get('h') or [] if t_ and '廃止日' in ''.join(t_[0]) for r_ in t_[1:] if len(r_)>=3]
        susp=s_.get('susp') or []
        if not closes and not susp:continue
        key=x.get('id') or s_.get('id')
        mt=RXT.match(s_.get('t') or '')
        if mt:name,paren,frm,to=mt.group(1),mt.group(2),mt.group(3),mt.group(4)
        else:
            # 역 목록(s)은 노리츠부시 표(data/imports)에서 온다. 깨끗한 체크아웃에는 없다
            if not s_.get('s'):continue
            m2=re.search(r'【(.+?)(?: \((.+?)\))?】',s_.get('t') or '')
            name,paren=m2.groups() if m2 else (None,None);frm,to=s_['s'][0][0],s_['s'][-1][0]
        if name and s_.get('cn') and name.startswith(s_['cn']+' '):name=name[len(s_['cn'])+1:]
        cand=rname.get((_nz(frm),_nz(to)),[])
        # 공식 표가 역 안 위치로 적은 끝(大和八木（上本町方）)은 끝 노드 이름 규칙(分岐点（大和八木）·역 이름)과 다르다: 괄호 뺀 역 이름으로 맞춘다
        if not cand:cand=rname_b.get((_nzb(frm),_nzb(to)),[])
        if len(cand)>1:
            cand=[c for c in cand if any(_nz(name) in _nz(y) or (paren and _nz(paren) in _nz(y)) for y in ja.get(('line',routes[c]['line_id']),[]))] or cand
        if len(cand)!=1:rows.append(('계통 못 찾음',key,f'{frm}～{to}',cand));continue
        rid=cand[0];L=routes[rid]['line_id'];es=redge[rid]
        adj=collections.defaultdict(list)
        for e in es:
            a_,b_=E[e];adj[a_].append((b_,e));adj[b_].append((a_,e))
        # 표의 구간 끝이 계통 밖(합류점에서 끝낸 옛 경로 계통의 확장 역, compile 합류점 규칙)이면 그 노선의 칸으로 잇는다
        adjL=collections.defaultdict(list,{k:list(v) for k,v in adj.items()})
        for e in {e for e,v in attr.items() for a_ in v if a_['line_id']==L}-set(es):
            a_,b_=E[e];adjL[a_].append((b_,e));adjL[b_].append((a_,e))
        def seg(a,b,adj=adj,again=True):
            """표의 구간 「A～B」를 그 계통의 edge로. A와 B가 같으면 순환 계통 전체"""
            A=[k for k in adj if _nz(a) in nname[k]] or [k for k in adj if _nz2(a) in nname[k]]
            Bn=[k for k in adj if _nz(b) in nname[k]] or [k for k in adj if _nz2(b) in nname[k]]
            if not A or not Bn:return seg(a,b,adjL,False) if again else None
            if _nz(a)==_nz(b) and routes[rid]['closed']:return list(es)
            best=None
            for a_ in A:
                prev={a_:None};q=[a_]
                while q:
                    u=q.pop(0)
                    for v_,e in adj[u]:
                        if v_ not in prev:prev[v_]=(u,e);q.append(v_)
                for b_ in Bn:
                    if b_==a_ or b_ not in prev:continue
                    p_=[];u=b_
                    while prev[u]:p_.append(prev[u][1]);u=prev[u][0]
                    if best is None or len(p_)<len(best):best=p_
            return best
        for a_b,_,d in closes:
            a,_,b=a_b.partition('～');d=str(d);sg=seg(a,b)
            if not sg:rows.append(('폐지 구간 못 찾음',key,rid,a_b));continue
            bad=[]
            for e in sg:
                # 다른 계통도 지나는 칸은 그 계통이 수명을 정한다 (京成 東成田 옛 경로의 京成成田–駒井野 공유 칸)
                if eroutes[e]-{rid}:continue
                lf=LR[e][-1];at=[y['valid_to'] for y in attr[e] if y['line_id']==L]
                if d not in {lf['valid_to'],lf['legal_abolition']}|set(at):bad.append((e,lf['valid_to'],lf['legal_abolition'],at))
            if bad:rows.append(('폐지일 미반영',key,rid,a_b,d,f'{len(bad)}/{len(sg)}',bad[:3]))
        for z in susp:
            a,b,d0=z[0],z[1],str(z[2]);d1=z[4] if len(z)>4 else None;sg=seg(a,b)
            # 30일 안에 재개한 운휴는 넣지 않는 것이 규칙이다 (DESIGN §17 「운휴 수록 기준」, compile 짧은 운휴 지움)
            if d1 and real(d0) and real(str(d1)) and (datetime.date.fromisoformat(str(d1))-datetime.date.fromisoformat(d0)).days<30:continue
            if not sg:rows.append(('휴지 구간 못 찾음',key,rid,a,b));continue
            bad=[]
            for e in sg:
                sr=[(i_,y) for i_,y in enumerate(LR[e]) if y['status']=='suspended' and y['valid_from']==d0]
                # 재개 없이 끝난 휴지는 휴지 시작으로 소급해 닫힌다(DESIGN §2.2, 결정 122). 그날 닫힌 영업 행이면 휴지가 반영된 것이다
                if not sr and not d1 and LR[e][-1]['valid_to']==d0 and LR[e][-1]['close_reason'] in ('no_regular_service','brt','relocated'):continue
                if not sr:bad.append((e,'휴지 행 없음'));continue
                i_,y=sr[0]
                if d1 and y['valid_to']!=d1:bad.append((e,'재개일 다름',y['valid_to']))
                if not d1 and i_!=len(LR[e])-1:bad.append((e,'재개 없는데 뒤 행',LR[e][i_+1]['valid_from'],LR[e][i_+1]['status']))
            if bad:rows.append(('휴지 미반영',key,rid,a,b,d0,d1,f'{len(bad)}/{len(sg)}',bad[:3]))
put('공식 노선표 폐지·휴지 미반영',rows)
# ---- 정차 기간과 선로 기간
rows=[];rows2=[]
for rid,s in rstop.items():
    # 인접 선로는 그 계통 edge 가운데 이 역에 닿는 것이다. route_edge 순번은 옛 선로·병렬 edge가 끼면 역 순번과 어긋난다 (이설 병렬 edge 계통)
    inc=collections.defaultdict(set)
    for e in redge[rid]:
        for k in E[e]:inc[k].add(e)
    for i,x in enumerate(s):
        if not x['is_stop']:continue
        adj=inc.get(x['node_id'])
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
    if not s or r['closed'] or r['line_id'] in HIDL:continue
    for x in(s[0],s[-1]):
        # 기록 하한(1950) 전에 끝난 행은 화면에 고를 일이 없다 (徳島線 三縄 1931–1935)
        if x['valid_to']!=ON and x['valid_to_hi'] and x['valid_to_hi']<=BASE:continue
        if not x['is_stop'] and not x['is_end_point']:rows.append((rid,nn(x['node_id'])))
put('계통 끝이 숨은 노드인데 끝 노드 행 아님',rows)
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
allp=collections.defaultdict(dict)
for e,v in attr.items():
    for a in v:allp[a['line_id']][e]=1
def comps(es):
    p={}
    def f(x):
        p.setdefault(x,x)
        while p[x]!=x:p[x]=p[p[x]];x=p[x]
        return x
    for e in es:p[f(E[e][0])]=f(E[e][1])
    return f,p
# 공식 노선 구성이 처음부터 두 조각인 노선 (data/overrides/invariant_exceptions.json split_today, 사유 필수)
try:SPLIT_OK={x['line']:x['why'] for x in json.load(open(os.path.join(ROOT,'data','overrides','invariant_exceptions.json'),encoding='utf-8')).get('split_today',[])}
except Exception:SPLIT_OK={}
rows=[]
for l,v in frag.items():
    if v.get(TODAY,1)<=1 or l in SPLIT_OK:continue
    f,_=comps(list(allp[l]))
    live=[e for e in allp[l] if any((a['valid_from_hi'] or '0000')<=TODAY<a['valid_to_hi'] for a in attr[e] if a['line_id']==l)]
    if len({f(E[e][0]) for e in live})>1:rows.append((ln(l),v,'한 번도 이어진 적 없는 조각'))
put('오늘 영업 구간이 끊긴 노선',rows,40)
# ---- 공개 노드와 이름
pub={r[0] for r in m.execute('select id from node_public')}
nm=collections.defaultdict(dict)
for t,i,l,x,k,src,li,vf,vt in n.execute('select entity_type,entity_id,lang,text,kana,source,line_id,valid_from,valid_to from name'):nm[t,i].setdefault(l,[]).append((x,k,src,li,vf,vt))
def base(t,i,l):
    """지금 이름 행: 노선별·기간 한정이 아닌 행 (없으면 None). 첫 행은 노선별 이름일 수 있다(富山駅)"""
    return next((r for r in nm[t,i].get(l,[]) if not r[3] and not r[4] and not r[5]),None)
put('공개 노드 ko 없음',[i for i in pub if 'ko' not in nm['node',i]])
put('공개 노드 ja 없음',[i for i in pub if 'ja' not in nm['node',i]])
put('공개 노드 en 없음',[i for i in pub if 'en' not in nm['node',i]])
# 승하차 불가 끝 노드(분기점·신호장, 정차 없는 계통 끝)는 노선 일람에 보여 이름이 있다 (5번 결정 junction-nodes-rule, 2026-11-19)
ENDN={r[0] for r in m.execute('select distinct node_id from route_stop where is_end_point=1')}
# 승객 미취급 정식 역(route_stop_select style staff, 근거 표 node_identity staff_only)도 노선 일람에 보여 이름이 있다 (2026-11-24)
STAFFN={r[0] for r in m.execute("select distinct node_id from route_stop_select where style like 'staff%'")} if m.execute("select 1 from sqlite_master where name='route_stop_select'").fetchone() else set()
put('비공개 노드 이름 노출',[i for t,i in nm if t=='node' and i not in pub and i not in ENDN and i not in STAFFN])
put('kind가 station 아닌 공개 노드',[r[0] for r in m.execute("select id from node_public where kind<>'station'")])
# 읽기 근거가 끝내 없어 한국어·영어에 일본어 표기를 그대로 보이는 이름(ja_as_is, redesign §4 결정 6)과
# 읽기를 모르는 옛 이름의 병기 「지금 이름 (당시 옛 표기)」(DESIGN §9 표, 2026-11-08)는 설계대로다. 병기 앞부분만 본다
THEN={'ko':re.compile(r'^(.*) \(당시 (.+)\)$'),'en':re.compile(r'^(.*) \(then (.+)\)$')}
def shown(l,x,s):
    """검사할 글자. ja_as_is는 None(검사 밖), 옛 표기 병기는 앞부분"""
    if s=='ja_as_is':return None
    g=THEN[l].match(x) if s=='rule' and l in THEN else None
    return g.group(1) if g else x
HK=re.compile(r'[぀-ヿ㐀-鿿]')
# 읽기 근거가 없는 분기점 이름은 고유한 부분만 한자 그대로 두고 종류만 옮긴다(宮古 분기점·宮古 Jct., 사용자 결정 2026-11-19). 끝 노드의 사람이 정한 이름(hand)의 한자 토막과
# 그 이름으로 만든 계통 이름의 같은 토막은 예외다
KJOK={t_ for i in ENDN for l in ('ko','en') for x,k,s,*_ in nm['node',i].get(l,[]) if s=='hand' for t_ in re.findall('[㐀-鿿]+',x)}
def _kj_ok(x):return not re.search('[぀-ヿ]',x) and set(re.findall('[㐀-鿿]+',x))<=KJOK
put('한글 이름에 일본어',[(t,i,x) for (t,i),v in nm.items() for x,k,s,*_ in v.get('ko',[]) if shown('ko',x,s) is not None and HK.search(shown('ko',x,s)) and not _kj_ok(shown('ko',x,s))])
HANGUL=re.compile(r'[가-힣]')
put('한글 이름에 한글 없음',[(t,i,x) for (t,i),v in nm.items() for x,k,s,*_ in v.get('ko',[]) if shown('ko',x,s) is not None and not HANGUL.search(shown('ko',x,s)) and not re.search(r'[A-Z]',x)])
asis=sorted({i for (t,i),v in nm.items() if t=='node' and any(r[2]=='ja_as_is' for r in v.get('ko',[]))})
R['정보: 읽기 근거 없어 일본어 표기 그대로(ja_as_is)']=dict(n=0,sample=[(i,nn(i)) for i in asis])
# 옛 이름 행에 읽기가 있는데 한국어·영어가 병기로 남음 (읽기를 찾으면 그 읽기로 만든 이름이 대신해야 한다)
rows=[]
for (t,i),v in nm.items():
    if t!='node':continue
    for x,k,s,li,vf,vt in v.get('ja',[]):
        if not k or li or not vt:continue
        for l in ('ko','en'):
            if any(r[5]==vt and not r[3] and r[2]=='rule' and THEN[l].match(r[0]) for r in v.get(l,[])):rows.append((i,x,k,l))
put('옛 이름에 읽기가 있는데 병기로 남음',rows)
# 읽기가 있는 이름 행은 같은 (노선, 기간)의 한국어·영어가 있어야 하고, 일본어 표기 그대로(ja_as_is)나 한자·가나가 남으면 안 된다.
# 읽기를 알면서 외국어를 못 단 것은 생성 단계의 빠짐이다 (열람 전용 역 영어 595·노선 영어 138, 2026-11-18 사용자 지적). 영어 이름은 컴파일 뒤에 들어오므로 여기서 본다
_rw=[]
for (t,i),v in nm.items():
    if t=='node' and i not in pub:continue
    for x,k,s_,li,vf,vt in v.get('ja',[]):
        if not k:continue
        for l in ('ko','en'):
            y=[r for r in v.get(l,[]) if (r[3],r[4],r[5])==(li,vf,vt)]
            if not y or any(r[2]=='ja_as_is' or (shown(l,r[0],r[2]) is not None and HK.search(shown(l,r[0],r[2]))) for r in y):_rw.append((t,i,l,x,li,vf,vt))
put('읽기 있는데 한국어·영어 없음',_rw)
# 읽기 없는 이름 행도 같은 (노선, 기간)의 한국어·영어 행이 있어야 한다(일본어 표기 그대로 ja_as_is 또는 옛 이름 병기). 없으면 화면이 다른 기간 이름을 보이거나 비게 된다 (5회차 2026-11-24)
_nk=[]
for (t,i),v in nm.items():
    if t not in ('node','archive') or (t=='node' and i not in pub):continue
    for x,k,s_,li,vf,vt in v.get('ja',[]):
        if k:continue
        for l in ('ko','en'):
            if not any((r[3],r[4],r[5])==(li,vf,vt) for r in v.get(l,[])):_nk.append((t,i,l,x,li,vf,vt))
put('읽기 없는 이름에 한국어·영어 행 없음',_nk)
# archive_fix의 읽기 열쇠(이름 또는 이름@노선)는 DB의 그 이름 열람 전용 역에 실제로 붙어야 한다. 컴파일이 노드에서 만든 열람 전용 역(1950 전 정차가 끝난 노드)은
# 이 열쇠를 보지 않아 읽기가 조용히 버려진다(志摩町·西裏·東野田町九丁目, 5회차 2026-11-24). 그런 역의 읽기는 노드(node_fix·old_names_kana)에 둔다
_AF=json.load(open(os.path.join(ROOT,'data','overrides','archive_fix.json'),encoding='utf-8'));_akana=collections.defaultdict(set)
_aline={r_[0]:r_[1] for r_ in m.execute('select id,coalesce(line_id,archive_line_id) from archive_stop')}
_aname=collections.defaultdict(set)
for (t,i),v in nm.items():
    if t!='archive':continue
    for x,k,*_r in v.get('ja',[]):
        _aname[x].add((t,i))
        if k:_akana[x].add((k,_aline.get(i)))
rows=[]
for k_,v_ in _AF.items():
    if k_.startswith('_') or not isinstance(v_,dict) or not v_.get('kana'):continue
    nm_,_,ln_=k_.partition('@')
    same_=list(_aname.get(nm_,()))
    if not same_:continue
    # 그 이름 열람 전용 역이 하나면 노선이 바뀌었어도(이관 뒤 北陸本線→あいの風) 그 역이다
    if not any(kk==v_['kana'] and (not ln_ or ll==ln_ or len(same_)==1) for kk,ll in _akana.get(nm_,())):rows.append((k_,v_['kana'],sorted(_akana.get(nm_,()))[:3]))
put('archive_fix 읽기 열쇠가 DB 열람 전용 역에 반영되지 않음',rows,30)
# 승객 미취급 정식 역(route_stop_select style staff)은 근거 표 node_identity staff_only에 적은 노드에만 생겨야 하고, 화물역(노드 종류 freight)에는 절대 생기면 안 된다.
# staff 행은 정차·끝·공개 노드가 아니어도 노선 일람에 보이므로, 잘못 번지면 화물역이 일람에 쏟아진다 (사용자 지시 2026-11-24)
_STAFF={r_['node'] for r_ in json.load(open(os.path.join(ROOT,'data','overrides','node_identity.json'),encoding='utf-8'))['rows'] if r_.get('kind')=='staff_only'}
_nkind={r_[0]:r_[1] for r_ in m.execute('select id,kind from node')}
rows=[]
if m.execute("select 1 from sqlite_master where name='route_stop_select'").fetchone():
    for r_,n_,st_ in m.execute("select route_id,node_id,style from route_stop_select where style like 'staff%'"):
        if n_ not in _STAFF:rows.append((r_,n_,st_,'근거 표에 없는 노드'))
        if _nkind.get(n_)=='freight':rows.append((r_,n_,st_,'화물역'))
put('승객 미취급 역(staff) 표시가 근거 표 밖 노드나 화물역에 생김',rows,20)
put('kana가 히라가나 아님',[(i,x,k) for (t,i),v in nm.items() if t=='node' for x,k,*_ in v.get('ja',[]) if k and not re.fullmatch(r'[ぁ-ゟー・ 　0-9A-Za-zァ-ヶ（）()]+',k)])
# 현대 가나 표기가 아님 (ぎをん, をごとおんせん). 원문 옛 표기를 그대로 옮긴 것이다
put('kana에 옛 가나(を·ゐ·ゑ)',[(t,i,x,k) for (t,i),v in nm.items() for x,k,*_ in v.get('ja',[]) if k and re.search('[をゐゑ]',k)])
put('공개 노드 kana 없음',[(i,base('node',i,'ja')[0]) for i in pub if base('node',i,'ja') and not base('node',i,'ja')[1] and i not in asis])
# 공식 영어 이름의 장음 기호(Shijō-Ōmiya)는 공식대로 둔다 (사용자 결정 2026-11-24). 그 밖의 비ASCII만 잡는다
_MACRON=str.maketrans('','','āīūēōĀĪŪĒŌ')
put('en에 비ASCII',[(i,x) for (t,i),v in nm.items() for x,k,s,*_ in v.get('en',[]) if shown('en',x,s) is not None and not shown('en',x,s).replace('·','').translate(_MACRON).isascii() and not _kj_ok(shown('en',x,s))])
# 계통 이름도 화면에 나온다(PackReader.nameBook). 없으면 한국어·영어 화면에 일본어 계통 이름이 나온다 (끝 역이 신호장·분기점인 계통)
put('계통 ko·en 이름 없음',[(i,l,J('route',i)) for (t,i),v in nm.items() if t=='route' for l in ('ko','en') if l not in v])
put('en 빈 값',[(i,x) for (t,i),v in nm.items() for x,k,s,*_ in v.get('en',[]) if not x.strip()])
pos={r['node_id']:(r['lat'],r['lon'],r['quality']) for r in m.execute('select * from node_position') if r['lat'] is not None}
def hav(a,b):
    p1,l1,p2,l2=map(math.radians,(a[0],a[1],b[0],b[1]));h=math.sin((p2-p1)/2)**2+math.cos(p1)*math.cos(p2)*math.sin((l2-l1)/2)**2
    return 6371*2*math.asin(math.sqrt(h))
# 같은 한자 다른 읽기: 같은 표기의 다른 지명은 흔하다(桂川 かつらがわ·けいせん, 山崎 やまさき·やまざき). 그래서 같은 노드 안이거나
# 8km 안의 노드끼리만 본다. 가까워도 실제로 읽기가 다른 역(西院 阪急 さいいん·京福 さい, 木幡 JR こはた·京阪 こわた)은 뺀다
# 三河豊田: 名鉄 挙母線 1937–1959(みかわとよだ, 1942 鉄道省 運賃算出表 높음)과 愛知環状鉄道 1976~(みかわとよた)은 시기가 겹치지 않는 다른 역 (5회차 2026-11-24)
NEAR_OK={'西院','木幡','三河豊田'}
kk=collections.defaultdict(lambda:collections.defaultdict(set))
# 같은 노드에서 같은 글자의 읽기가 기간을 달리해 바뀐 것(苅田 かりた ~1959 → かんだ, 공식 읽기 변경)은 충돌이 아니다.
# 그 노드에서 그 글자의 행이 모두 기간이 겹치지 않으면(기간 없는 지금 행 하나 + 끝난 옛 행들) 한 노드 안 충돌로 세지 않는다 (2026-11-13)
def _ivl_(r_):return ((r_[4] or '0000')[:10].strip('['),(r_[5] or '9999')[:10].strip('['))
for (t,i),v in nm.items():
    if t=='node':
        rs_=[r_ for r_ in v.get('ja',[]) if r_[1] and not r_[3]]
        for x in {r_[0] for r_ in rs_}:
            same_=[r_ for r_ in rs_ if r_[0]==x]
            ks_={r_[1] for r_ in same_}
            if len(ks_)>1:
                # 기간 없는 지금 행은 끝난 옛 행들 뒤에 온다
                end_=max((_ivl_(r_)[1] for r_ in same_ if r_[5]),default='0000')
                iv_=sorted((end_,'9999') if not r_[4] and not r_[5] else _ivl_(r_) for r_ in same_)
                if all(p_[1]<=q_[0] for p_,q_ in zip(iv_,iv_[1:])):kk[x][sorted(ks_)[0]].add(i);continue
            for k in ks_:kk[x][k].add(i)
rows=[]
for x,by in kk.items():
    if len(by)<2 or x in NEAR_OK:continue
    ks=sorted(by);hit=None
    for a_ in range(len(ks)):
        for b_ in range(a_):
            for p in by[ks[a_]]:
                for q in by[ks[b_]]:
                    if p==q:hit=(x,ks[b_],ks[a_],p,q,0.0)
                    elif p in pos and q in pos and hav(pos[p],pos[q])<8:hit=hit or (x,ks[b_],ks[a_],p,q,round(hav(pos[p],pos[q]),1))
    if hit:rows.append(hit)
put('같은 한자 다른 읽기',rows,30)
R['정보: 같은 한자 다른 읽기(먼 노드 포함)']=dict(n=0,sample=[sum(len(v)>1 for v in kk.values())])
# 같은 표기·같은 읽기인데 한글이 다름. 나무위키 표는 표기|읽기 키라 같은 값을 주므로, 다르면 손 보정이나 규칙이 갈라진 것이다
# 표기가 다르면(神谷町 카미야쵸·紙屋町 카미야초, 新飯田 니다) 나무위키 표제어나 新 규칙이라 보지 않는다
ko2=collections.defaultdict(lambda:collections.defaultdict(set))
for (t,i),v in nm.items():
    if t!='node':continue
    j,kr=base('node',i,'ja'),base('node',i,'ko')
    if j and kr and j[1] and kr[2]!='ja_as_is':ko2[j[0],j[1]][kr[0]].add(i)
put('같은 읽기 다른 한글',[(a,b,{x:sorted(y) for x,y in v.items()}) for (a,b),v in ko2.items() if len(v)>1],30)
# 역 이전 옛 자리(（旧）)와 새 자리는 같은 역이라 읽기가 같아야 한다 (西鉄福岡（天神）（旧） ふくおか)
rows=[]
for o,w in m.execute('select old_node,new_node from node_move'):
    a,b=base('node',o,'ja'),base('node',w,'ja')
    if a and b and a[1] and b[1] and a[0].replace('（旧）','')==b[0] and a[1]!=b[1]:rows.append((o,a[0],a[1],w,b[1]))
put('옛 자리와 새 자리 읽기가 다름',rows)
# 다른(더 긴) 이름의 읽기를 그대로 가져옴: 넘겨주기 문서·이웃 역의 읽기가 들어온 것이다
# (雲雀丘 ひばりがおかはなやしき, 大分駅前 おおいた, 西公園 おおまちにしこうえん, 옛 이름 立花 いよたちばな).
# 한 글자 차이는 읽기가 없는 글자라 뺀다 (和泉中央·泉中央 いずみちゅうおう, 渡·渡り わたり)
# 〈〉 부역명(明治神宮前〈原宿〉)도 괄호처럼 뗀다. 부역명은 읽기에 없다
def _nz(t):return re.sub(r'（[^）]*）|\([^)]*\)|〈[^〉]*〉|(駅|停留場|仮乗降場|臨時乗降場|乗降場|信号場|信号所)$','',t)
def _longer(a,b):
    a,b=_nz(a),_nz(b)
    return len(b)-len(a)>=2 and a in b
kb=collections.defaultdict(set)
for (t,i),v in nm.items():
    if t!='node' or i not in pub:continue
    j=base('node',i,'ja')
    if j and j[1]:kb[j[1]].add((j[0],i))
rows=[]
for k,v in kb.items():
    for a,i in v:
        for b,w in v:
            if _longer(a,b):rows.append((i,a,k,w,b))
for (t,i),v in nm.items():
    if t!='node' or i not in pub:continue
    j=base('node',i,'ja')
    if not j or not j[1]:continue
    for x,k,s,li,vf,vt in v.get('ja',[]):
        if vt and k==j[1] and (_longer(x,j[0]) or _longer(j[0],x)):rows.append((i,x,k,i,j[0]))
put('다른 이름의 읽기를 가져옴',rows,30)
# 읽기에 들어가면 안 되는 것 (이름 감사의 재발 방지)
NUMK={'一':'いっ|いち','二':'に','三':'さん','四':'よん|し','五':'ご','六':'ろく|ろっ','七':'なな|しち','八':'はっ|はち','九':'きゅう|く','十':'じっ|じゅっ|じゅう'}
rows=[]
for (t,i),v in nm.items():
    if t!='node' or i not in pub:continue
    for x,k,*_ in v.get('ja',[])[:1]:
        if not k:continue
        if re.search('(こうさくせん|てつどうせん|けんすいせん)$',k) and not x.endswith('線'):rows.append((i,x,k))
        if re.search('しんごうじょう|じょうこうじょう',k) and not re.search('信号|乗降',x):rows.append((i,x,k))
        if x.endswith('駅前') and not k.endswith('えきまえ'):rows.append((i,x,k))
        # 丁目 앞 숫자와 읽기의 숫자가 맞아야 한다 (本町二丁目 ほんまちさんちょうめ)
        g=re.search('([一二三四五六七八九十])丁目$',x)
        if g and not re.search(f"(?:{NUMK[g.group(1)]})ちょうめ$",k):rows.append((i,x,k))
put('읽기가 이름과 맞지 않음',rows,30)
sk=collections.defaultdict(set);sks=collections.defaultdict(set)
for (t,i),v in nm.items():
    if t=='node' and i in pub and 'ja' in v and 'ko' in v and v['ja'][0][1]:
        sk[v['ja'][0][0],v['ko'][0][0]].add(v['ja'][0][1]);sks[v['ja'][0][0],v['ko'][0][0]].add(v['ko'][0][2])
# 한글이 모두 나무위키 표제어면 나무위키가 맑은소리·흐린소리를 가르지 않은 것이라 뺀다 (二軒茶屋 にけんちゃや·にけんぢゃや 니켄차야)
put('같은 이름·같은 한글인데 읽기가 다름',[(a,b,sorted(c)) for (a,b),c in sk.items() if len({re.sub('[うお]','',x) for x in c})>1 and sks[a,b]!={'namuwiki'}],30)
# 그룹: 같은 그룹 안 노드의 이름과 거리
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
    if len(v)<2:rows.append((k,'한 명'))
# 사업자 공식 안내가 있는 간접환승은 거리와 상관없이 환승이다(사용자 결정 2026-11-16, 京阪 七条–JR 京都 1015 m). 손 표(hub_join) why에 「노드 확인」을 적은 쌍은 뺀다(K205와 같은 표시)
_HJOK658={frozenset((x_['node'],x_['with'])) for x_ in json.load(open(os.path.join(ROOT,'data','overrides','hub_join.json'),encoding='utf-8')) if '노드 확인' in x_.get('why','')}
for k,a,b,f_,t_ in m.execute('select hub_id,node_a,node_b,valid_from,valid_to from hub_pair'):
    if a in pos and b in pos and hav(pos[a],pos[b])>1.0 and frozenset((a,b)) not in _HJOK658:rows.append((k,[nn(a),nn(b),f_,t_,pos[a][2],pos[b][2]],round(hav(pos[a],pos[b]),2)))
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
# 선로가 실제로 크게 돌아가는 곳. 営業キロ가 원자료와 맞고 선형이 이유일 때만 적는다
LONG_OK={('r_kisuki_line','n_izumo_sakane','n_miinohara'),   # 木次線 三段スイッチバック. 노리츠부시 63.3→69.7 (6.4km), 직선 1.3km
         ('r_kisuki_line','n_miinohara','n_izumo_sakane')}
rows=[]
for rid,s in rstop.items():
    for p,q in zip(s,s[1:]):
        a,b=pos.get(p['node_id']),pos.get(q['node_id'])
        if not a or not b or a[2]!='precise' or b[2]!='precise':continue
        d=hav(a,b);k=q['km_cum']-p['km_cum']
        if k>d*2.2+3 and (rid,p['node_id'],q['node_id']) not in LONG_OK:rows.append((round(k-d,1),rid,nn(p['node_id']),nn(q['node_id']),round(k,1),round(d,1)))
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
    if r['other_line_id'] not in cur and not (r['other_line_id'] in BUSL and r['kind']=='continue'):rows.append((r['route_id'],r['seq'],r['kind'],ln(r['other_line_id'])))
put('현행 link가 폐선 노선을 가리킴',rows,20)
stop_cur={(r[0],r[1]) for r in m.execute("select route_id,node_id from route_stop where valid_to='ongoing' and is_stop=1")}
# 오늘 서는 역은 정차 기간(route_stop_period)으로 본다. 끝 노드 행을 계통 끝 칸 영업 기간으로 늘린 동안은 정차가 아니다(5번 결정, 三岐朝明 신호장)
node_cur={r[0] for r in m.execute("select node_id from route_stop_period where valid_to='ongoing'")}
# 오늘 계통 끝 노드(정차가 없어도 승하차 불가 끝 노드로 고름)
END_CUR={r['node_id'] for r in m.execute("select s.node_id from route_stop s join route r on r.id=s.route_id where s.valid_to='ongoing' and s.node_id in (r.from_node,r.to_node)")}
if m.execute("select 1 from sqlite_master where type='table' and name='route_stop_select'").fetchone():
    # 끝은 날마다 정한다(계통 정의의 시작·끝 노드가 아니어도 됨): 지금 서지 않고 고를 수 있는 행
    END_CUR|={r['node_id'] for r in m.execute("select s.node_id from route_stop_select s where s.valid_to='ongoing' and s.style not in ('none','moved')")}
rows=[]
for r in m.execute("select route_id,seq,next_stop_node,terminal_node from route_link where valid_to='ongoing'"):
    for x in (r['next_stop_node'],r['terminal_node']):
        # 정차역이 없는 연락선의 다음·끝 역은 끝 노드다(中川短絡線 宮古分岐 → 黒田分岐)
        if x and x not in node_cur and x not in ENDN and x not in END_CUR:rows.append((r['route_id'],r['seq'],nn(x)))
put('현행 link가 폐역을 가리킴',rows,20)
# 숨은 노드가 link 대상으로 나가는가
rows=[]
for r in m.execute('select route_id,seq,kind,other_node,next_stop_node,terminal_node from route_link'):
    for x in (r['other_node'],r['next_stop_node'],r['terminal_node']):
        if x and x not in pub and x not in ENDN:rows.append((r['route_id'],r['seq'],r['kind'],x))
put('link가 비공개 노드를 가리킴',rows)
# 계통별 표시 역 없음
# 고를 수 있는 줄: 정차역과 승하차 불가 끝 노드(자기 역이 없는 연락선은 양 끝 노드만으로 기록한다)
ext_n=collections.Counter(r[0] for r in m.execute('select route_id from route_stop where is_end_point=1 and is_stop=0'))
put('정차역이 2개 미만인 계통',[(r,[nn(x['node_id']) for x in s]) for r,s in rstop.items() if sum(x['is_stop'] for x in s)+ext_n[r]<2 and routes[r]['line_id'] not in HIDL])
# ---- 수록 범위
# リフトカー는 地方鉄道法 鋼索(新宮観光リフトカー, 위키 ケーブルカー 廃止 목록)라 リフト(索道)에서 뺀다
bad=re.compile(r'BRT|ロープウェ|リフト(?!カー)|連絡船|索道|スロープカー|ゴンドラ|フェリー')
put('수록하지 않는 종류 이름',[(i,v[0]) for (t,i),v in ja.items() if t=='line' and bad.search(v[0])])
# 노선별 사업자 현재/과거
rows=[]
for r in m.execute("select l.id,l.type from line l"):
    pass
# 열람 전용의 날짜 범위: 기록 가능과 겹침
rows=[(r['id'],r['opened'],r['closed']) for r in m.execute("select * from archive_stop") if r['closed'] and real(r['closed']) and r['closed']>=BASE and False]
# ==== 2회차 전수 대조의 원인별 검사 (docs/redesign.md 뒤 2회차 종합, 원인 K01~K37, 묶음 B5) ====
# 항목 이름 앞 K번호가 원인 번호다. 단계 err는 고쳐야 할 결함(엄격 모드에서 빌드 실패), warn은 사람이 볼 후보 목록이다.
# 규칙상 정상인 것은 세지 않는다: 신칸센과 재래선이 만나는 곳은 환승(DESIGN §2.9·§8.1), §17 결정(명목상 여객 취급·행사날 임시역·계절 운휴),
# 노리츠부시와 위키 km 0.1 차이는 노리츠부시 유지(U17, audit_ext 쪽)
def ivl(f,t):
    """EDTF 기간 (시작 가장 이른 날, 시작 가장 늦은 날, 끝 가장 이른 날, 끝 가장 늦은 날). 빈 쪽은 열린 끝. 읽을 수 없으면 None"""
    try:
        a=lohi(f) if f else ('0000-01-01','0000-01-01');b=lohi(t) if t else ('9999-12-31','9999-12-31')
    except ValueError:return None
    return (a[0],a[1],b[0],b[1])
def may(p,q):return bool(p and q) and p[0]<q[3] and q[0]<p[3]
def must(p,q):return bool(p and q) and p[1]<q[2] and q[1]<p[2]
def G_(x):return GRP.get(x) or x
GRP=dict(m.execute('select id,group_id from node').fetchall())
NPREF=dict(m.execute('select id,pref from node').fetchall())
NKIND=dict(m.execute('select id,kind from node').fetchall())
LT=dict(m.execute('select id,type from line').fetchall())
def sysc(l):
    """선로 방식 묶음. 궤간 표(data/overrides/line_gauge.json)가 생기기 전까지는 노선 종류로 가른다"""
    if line_rc.get(l)=='shinkansen':return 'shinkansen'
    t=LT.get(l);return {'rail':'heavy','subway':'heavy','trolley':'tram'}.get(t,t)
GPATH=os.path.join(ROOT,'data','overrides','line_gauge.json')
GAUGE=collections.defaultdict(list)
if os.path.exists(GPATH):
    for x in json.load(open(GPATH,encoding='utf-8')).get('rows',[]):GAUGE[x['line']].append((ivl(x.get('valid_from'),x.get('valid_to')),x.get('gauge'),x.get('system')))
GCLS={'rail':'rail','subway':'rail','tram':'rail','third_rail':'third_rail','agt':'agt','monorail':'monorail','maglev':'maglev','linear':'linear','cable':'cable','rubber_guided':'rubber_guided','guideway_bus':'guideway_bus','trolley':'trolley','bus':'bus'}
def gfit(a,b):
    """두 (방식, 궤간) 집합이 이어질 수 있는가. 궤간 모름(None)은 같은 방식이면 맞는 것으로 본다 (compile._fits와 같음)"""
    return any(x[0]==y[0] and (x[1] is None or y[1] is None or x[1]==y[1]) for x in a for y in b)
def gauge_on(l,lo,hi,x=None):
    """기간 [lo,hi)에 그 노선이 노드 x에서 가진 궤간 집합 (표가 없으면 빈 집합). 구간 행(from_node–to_node)은 그 구간 경로가 x를 지날 때만 센다
    (上越線 高崎는 ガーラ湯沢 지선 1435 mm 행을 보지 않는다). x가 없으면 노선 전체를 본다"""
    if not hasattr(gauge_on,'rows'):
        gauge_on.rows=collections.defaultdict(list);gauge_on.adj={};gauge_on.seg={}
        if os.path.exists(GPATH):
            for r_ in json.load(open(GPATH,encoding='utf-8')).get('rows',[]):gauge_on.rows[r_['line']].append(r_)
    def seg(r_):
        """구간 행의 경로 노드 (노선 칸 그래프 최단 경로). 구간이 없으면 None=노선 전체"""
        if not(r_.get('from_node') and r_.get('to_node')):return None
        k_=(r_['line'],r_['from_node'],r_['to_node'])
        if k_ not in gauge_on.seg:
            if r_['line'] not in gauge_on.adj:
                g_=collections.defaultdict(set)
                for e_,v_ in attr.items():
                    if any(a_['line_id']==r_['line'] for a_ in v_) and e_ in E:a_,b_=E[e_];g_[a_].add(b_);g_[b_].add(a_)
                gauge_on.adj[r_['line']]=g_
            g_=gauge_on.adj[r_['line']];prev={r_['from_node']:None};q_=collections.deque([r_['from_node']])
            while q_ and r_['to_node'] not in prev:
                u_=q_.popleft()
                for v_ in sorted(g_.get(u_,())):
                    if v_ not in prev:prev[v_]=u_;q_.append(v_)
            p_=set()
            if r_['to_node'] in prev:
                u_=r_['to_node']
                while u_ is not None:p_.add(u_);u_=prev[u_]
            gauge_on.seg[k_]=p_
        return gauge_on.seg[k_]
    # (방식 묶음, 궤간). 第三軌条와 架空은 다른 묶음이다(compile._SYSCLS와 같음). 그 역에 걸리는 구간 행이 노선 전체 행보다 앞선다
    segs=set();whole=set()
    for r_ in gauge_on.rows.get(l,[]):
        p=ivl(r_.get('valid_from'),r_.get('valid_to'))
        if not p or not(p[0]<hi and lo<p[3]):continue
        s_=seg(r_) if x is not None else None
        k_=(GCLS.get(r_.get('system'),r_.get('system')),r_.get('gauge'))
        if s_ is None:whole.add(k_)
        # 노드 쪼개기로 노선마다 나뉜 같은 역(西鉄 千鳥橋 시전 쪽·貝塚線 쪽)은 같은 묶음이면 구간 위로 본다 (compile._on_seg의 SPLIT_OF와 같은 뜻)
        elif x in s_ or (GRP.get(x) and GRP.get(x) in {GRP.get(n_) for n_ in s_}):segs.add(k_)
    return segs or whole
EINC=collections.defaultdict(set)
for e,(a,b) in E.items():EINC[a].add(e);EINC[b].add(e)
NOP=collections.defaultdict(set)
for x,es in EINC.items():
    for e in es:NOP[x]|={a['operator_id'] for a in attr.get(e,[])}
SP=collections.defaultdict(list);SPR=collections.defaultdict(list)
for r in m.execute('select route_id,node_id,valid_from,valid_to from route_stop_period'):
    p=ivl(r[2],r[3]);SP[r[1]].append((r[0],p));SPR[r[0],r[1]].append(p)
allstop=collections.defaultdict(list)
for r in m.execute('select * from route_stop order by route_id,seq'):allstop[r['route_id']].append(dict(r))
SEQN={(rid,x['seq']):x['node_id'] for rid,v in allstop.items() for x in v}
LROUTES=collections.defaultdict(list)
for rid,r in routes.items():LROUTES[r['line_id']].append(rid)
RNODES={rid:{x['node_id'] for x in v} for rid,v in allstop.items()}
NLINES=collections.defaultdict(set)
for rid,v in rstop.items():
    for x in v:
        if x['is_stop']:NLINES[x['node_id']].add(routes[rid]['line_id'])
def bj(i):
    b=base('node',i,'ja');return b[0] if b else J('node',i)
def strip_old(s):return re.sub(r'[（(]旧[)）]','',s or '').strip()
LINKS=[dict(r) for r in m.execute('select * from route_link')]
for k in LINKS:k['node']=SEQN.get((k['route_id'],k['seq']))
JN=[dict(r) for r in m.execute('select * from junction')]
TLG=set()
for at,a,b in m.execute('select at_node,line_a,line_b from track_link'):TLG|={(G_(at),a,b),(G_(at),b,a)}
for j in JN:TLG|={(G_(j['node_id']),j['line_id'],j['other_line_id']),(G_(j['node_id']),j['other_line_id'],j['line_id'])}
HT=json.load(open(os.path.join(ROOT,'data','overrides','hand_tables.json'),encoding='utf-8'))['tables']
LBYJA=collections.defaultdict(set)
for (t_,i_),v_ in ja.items():
    if t_=='line':
        for x in v_:LBYJA[unicodedata.normalize('NFKC',x)].add(i_)
# 판정 표의 노선 열쇠는 노선 ID다(2회차 B1). 예전 행처럼 일본어 이름이면 이름으로 찾는다
LINE_IDS={i_ for (t_,i_) in ja if t_=='line'}
def lines_of(k):return {k} if k in LINE_IDS else LBYJA.get(unicodedata.normalize('NFKC',k),set())
NOCONT=set()
for a_,b_ in HT.get('NOCONT',{}).get('값',[]):
    for p_ in lines_of(a_):
        for q_ in lines_of(b_):NOCONT|={(p_,q_),(q_,p_)}
# 「선로 연결 없음」 판정 표(B1에서 생김: JUNCTION_NOT {line, other|other_route, at, why}). 있으면 판정으로 센다
JNOT=set()
for x in HT.get('JUNCTION_NOT',{}).get('값',[]):
    if x.get('line') and x.get('other'):JNOT|={(G_(x.get('at')),x['line'],x['other']),(G_(x.get('at')),x['other'],x['line'])}
def judged(x,a,b):return (G_(x),a,b) in TLG or (a,b) in NOCONT or (G_(x),a,b) in JNOT or (None,a,b) in JNOT
OVR=lambda f:json.load(open(os.path.join(ROOT,'data','overrides',f),encoding='utf-8'))
HUBNOT={frozenset((x['node'],x['with'])) for x in OVR('hub_not.json')}
MOVED={frozenset((a,b)) for a,b,_ in m.execute('select * from node_move')}
MVOLD={a:b for a,b,_ in m.execute('select * from node_move')}
HP=collections.defaultdict(list)
for h_,a,b,f_,t_,o_,bs in m.execute('select * from hub_pair'):HP[frozenset((a,b))].append((h_,f_,t_,bs))
# ---- 선로 연결 (K01~K05, K09, K10)
# 계통의 끝은 계통 정의의 양 끝(from·to)과 정차 목록의 처음·끝이다(끝 너머에 옛 자리 역이 붙은 越後線 新潟)
ends=collections.defaultdict(set)
for rid,s in rstop.items():
    if s:ends[routes[rid]['line_id']]|={s[0]['node_id'],s[-1]['node_id'],routes[rid]['from_node'],routes[rid]['to_node']}
LATTR=collections.defaultdict(list)
for e,v in attr.items():
    for a in v:LATTR[a['line_id']].append((e,a['valid_from_lo'] or '0000',a['valid_to_hi'] or '9999'))
def end_on(l,x,d):
    """그날(d) 노선 l의 칸이 x에 하나 이하로 닿으면 그날 x는 l의 끝이다 (DESIGN §8.1 「시기별 끝 역」, compile era_end)"""
    return sum(1 for e,f_,t_ in LATTR[l] if x in E.get(e,()) and f_<=d<t_)<=1
put('K01 continue junction이 계통 끝 역 아님',[(j['line_id'],j['other_line_id'],j['node_id'],(j['source'] or '')[:24]) for j in JN if j['is_continue'] and j['node_id'] not in ends[j['line_id']] and not end_on(j['line_id'],j['node_id'],lohi(j['valid_from'])[1] if j['valid_from'] else '0000')],30)
NBR_K01=collections.defaultdict(lambda:collections.defaultdict(set))
for rid_,v_ in rstop.items():
    for p_,q_ in zip(v_,v_[1:]):
        NBR_K01[routes[rid_]['line_id']][p_['node_id']].add(q_['node_id']);NBR_K01[routes[rid_]['line_id']][q_['node_id']].add(p_['node_id'])
LK=set()
for k in LINKS:
    if k['kind'] in('continue','branch') and k['node'] and k['route_id'] in routes:LK.add((routes[k['route_id']]['line_id'],G_(k['node']),k['other_line_id']))
rows=[]
# 상대 노선이 그 노드가 아니라 같은 묶음의 다른 노드에만 서서 근거 표(THROUGH) 없이 환승으로 둔 근거 행은 판정된 것이다 (다른 노드 이어짐은 여객 직통 근거가 있을 때만, 9회차 L)
_JON=set()
if os.path.exists(os.path.join(B,'report.json')):
    _JON={tuple(x) for x in json.load(open(os.path.join(B,'report.json'),encoding='utf-8')).get('warnings',{}).get('junction_other_node_transfer',[])}
for j in JN:
    if j['source']=='derived' or (j['valid_to'] not in(None,ON) and j['valid_to']<BASE):continue
    if (j['line_id'],j['other_line_id'],j['node_id']) in _JON:continue
    a,b,x=j['line_id'],j['other_line_id'],G_(j['node_id'])
    # 숨은 분기점·신호장(승객 역 아님)의 근거는 그 노드를 지나는 두 노선 계통의 이웃 행에서 나온 연결로도 된다
    # (漆生線은 嘉穂信号場에서 上山田線과 만나 下山田까지 나란히 가고 연결은 下山田 정차역에 있다)
    xs_={x}|({G_(y) for l_ in (a,b) for y in NBR_K01[l_].get(j['node_id'],())} if j['node_id'] not in pub else set())
    if not any((a,y,b) in LK or (b,y,a) in LK for y in xs_):rows.append((a,b,j['node_id'],j['valid_from'],j['valid_to'],(j['source'] or '')[:40]))
put('K01 근거 junction이 route_link 분기·이어짐으로 안 나옴',rows,30)
# 한 노선이 끝나는 노드를 같은 방식의 다른 노선이 지나가거나 거기서 끝나는데 선로 연결 판정(junction·track_link·NOCONT·JUNCTION_NOT)이 없음
RSIV={}
for rid,v in rstop.items():
    for x in v:RSIV[rid,x['node_id']]=(x['valid_from_lo'] or '0000',x['valid_from_hi'] or '0000',x['valid_to_lo'] or '9999',x['valid_to_hi'] or '9999')
NROUTES=collections.defaultdict(set)
ISSTOP={(rid,x['node_id']) for rid,v in rstop.items() for x in v if x['is_stop']}
for rid,v in rstop.items():
    for x in v:NROUTES[x['node_id']].add(rid)
# 규칙으로 판정된 쌍은 판정이 있는 것으로 센다: 그날 궤간이 다름(DESIGN §2.9 궤간·선로 방식), 끝 역에서 두 노선의 이웃 역이 이루는 각이 75°(노면전차끼리 30°)
# 보다 작아 되돌아가야 함(직통·환승 전수 점검 R2, gen_wiki SHARP)
def r_nb(rid,x):
    """계통 rid에서 x와 칸으로 이웃한 노드들"""
    return {b if a==x else a for e in REDGE_L.get(rid,()) for a,b in [E[e]] if x in (a,b) and a!=b}
REDGE_L={rid:list(v) for rid,v in redge.items()}
def vang(x,p,q):
    if x not in pos or p not in pos or q not in pos:return None
    k=math.cos(math.radians(pos[x][0]))
    u=((pos[p][1]-pos[x][1])*k,pos[p][0]-pos[x][0]);w=((pos[q][1]-pos[x][1])*k,pos[q][0]-pos[x][0])
    l_=math.hypot(*u)*math.hypot(*w)
    return math.degrees(math.acos(max(-1,min(1,(u[0]*w[0]+u[1]*w[1])/l_)))) if l_ else None
def rule_judged(x,A,ra,B,rb):
    lo_=max(RSIV[ra,x][0],RSIV[rb,x][0]);hi_=min(RSIV[ra,x][3],RSIV[rb,x][3])
    ga_,gb_=(gauge_on(A,lo_,hi_,x),gauge_on(B,lo_,hi_,x)) if GAUGE else (set(),set())
    if ga_ and gb_ and not gfit(ga_,gb_):return True
    # 같은 이웃 노드로 들어오면(같은 칸으로 함께 끝남, 高松（旧）) 각은 0°다
    angs=[0 if p_==q_ else vang(x,p_,q_) for p_ in r_nb(ra,x) for q_ in r_nb(rb,x)];angs=[a_ for a_ in angs if a_ is not None]
    return bool(angs) and max(angs)<(30 if LT.get(A)==LT.get(B)=='tram' else 75)
# 나뉜 역(station_split)의 같은 km 점 칸으로만 그 노드에 닿는 노선은 그 노드에서 새 선로를 만난 것이 아니다(같은 역의 다른 승강장). 선로 연결 판정은 각자 제 노드에서 본다 (11회차 S1)
_SPL01=set()
if m.execute("select 1 from sqlite_master where type='table' and name='station_split'").fetchone():
    for a_,l_ in m.execute('select s.node_a,e.seed_line from station_split s join edge e on e.id=s.edge_id'):_SPL01.add((a_,l_))
rows=set()
for rid,s in rstop.items():
    if not s or routes[rid]['closed']:continue
    A=routes[rid]['line_id']
    for x in {s[0]['node_id'],s[-1]['node_id']}:
        for q in NROUTES[x]:
            Lb=routes[q]['line_id']
            if (x,A) in _SPL01 or (x,Lb) in _SPL01:continue
            # 두 노선이 함께 서는 역에서만 본다 (화물선이 지나기만 하는 秋田港는 화면에 연결이 없다)
            if Lb==A or sysc(A)!=sysc(Lb) or sysc(A)=='tram' or (rid,x) not in ISSTOP or (q,x) not in ISSTOP or not may(RSIV[rid,x],RSIV[q,x]):continue
            if not judged(x,A,Lb) and not rule_judged(x,A,rid,Lb,q):rows.add((ln(A),ln(Lb),nn(x),x))
put('K01 끝 역에서 같은 방식 노선과 만나는데 선로 연결 판정 없음(노면전차 밖)',sorted(rows),40)
# 같은 사업자 노면전차 노선 둘이 한 노드에서 만나는데 선로 연결이 하나도 없음 (사업자 안 노면 망)
TRAM={l for l,t in LT.items() if t in('tram','trolley')}
LOP=collections.defaultdict(set)
for e,v in attr.items():
    for a in v:LOP[a['line_id']].add(a['operator_id'])
rows=set()
for x,rs in NROUTES.items():
    ls=sorted({routes[q]['line_id'] for q in rs}&TRAM)
    for i_ in range(len(ls)):
        for k_ in range(i_):
            a,b=ls[i_],ls[k_]
            # 두 노선이 그 노드에 함께 선 날이 있어야 본다(노면전차 밖 검사와 같은 조건). 富山 西町 都心線–支線·東部線, 広島 的場町 循環선 쌍은 함께 영업한 날이 없다 (6회차 2026-11-14)
            if not any((q1,x) in ISSTOP and (q2,x) in ISSTOP and may(RSIV[q1,x],RSIV[q2,x]) for q1 in rs if routes[q1]['line_id']==a for q2 in rs if routes[q2]['line_id']==b):continue
            if LOP[a]&LOP[b] and not judged(x,a,b):rows.add((ln(a),ln(b),nn(x),x))
put('K01 같은 사업자 노면전차 노선이 만나는 노드에 선로 연결 없음',sorted(rows),40,lvl='warn')
jop=collections.Counter()
for j in JN:
    for o in LOP[j['line_id']]:jop[o]+=1
R['K01 정보: 선로 연결(junction) 0행인 노면전차 사업자']=dict(n=0,lvl='info',sample=sorted({o for l in TRAM for o in LOP[l] if not jop[o]}))
# 같은 노선 지선 계통의 양 끝이 다른 계통과 만나면 그 자리에 계통 사이 연결 행이 있어야 한다
RL=set()
for k in LINKS:
    if k['kind'] in('continue','branch') and k['node']:RL|={(k['route_id'],k['node'],k['other_route_id']),(k['other_route_id'],k['node'],k['route_id'])}
# 끝이 숨은 노드면 그 자리 연결은 at_edge 분기·확장 행이 맡는다. 다른 계통은 그 역에 함께 선 기간이 있고 이 계통이 들어온 칸을 함께 쓰지 않을 때만 본다
# (같은 칸으로 들어오는 두 계통은 이어지는 것이 아니다, compile own_pairs)
# 규칙으로 판정된 같은 노선 계통 쌍: 그날 궤간이 다름·선형이 같은 쪽으로 나란히 나감(compile build/report.json warnings cont_gauge·cont_sharp)·계통 한정 「연결 없음」 판정(JUNCTION_NOT route)
_RW=json.load(open(os.path.join(B,'report.json'),encoding='utf-8')).get('warnings',{}) if os.path.exists(os.path.join(B,'report.json')) else {}
SLJ={(w[0],w[1],w[2]) for k_ in ('cont_gauge','cont_sharp') for w in _RW.get(k_,[]) if isinstance(w,list) and len(w)>2}
SLJ|={(x_['route'],x_['at'],x_['other_route']) for x_ in HT.get('JUNCTION_NOT',{}).get('값',[]) if x_.get('route') and x_.get('other_route')}
rows=[]
for rid,r in routes.items():
    s=rstop[rid]
    if r['role']!='branch' or r['closed'] or not s:continue
    for y in {s[0]['node_id']:s[0],s[-1]['node_id']:s[-1]}.values():
        x=y['node_id']
        if not y['is_stop']:continue
        own_=EINC[x]&set(REDGE_L.get(rid,()))
        oth=[q for q in LROUTES[r['line_id']] if q!=rid and x in RNODES.get(q,()) and (q,x) in ISSTOP and may(RSIV[rid,x],RSIV[q,x]) and not own_&set(REDGE_L.get(q,())) and (rid,x,q) not in SLJ and (q,x,rid) not in SLJ]
        if oth and not any((q,x,rid) in RL or (rid,x,q) in RL for q in oth):rows.append((rid,nn(x),oth[:3]))
put('K01 지선 계통 끝에 부모 계통 연결 행 없음',rows,30)
# 이관 사슬: 앞 노선과 뒤 노선이 같은 노드에서 같은 상대와 맺은 연결 종류가 다름
TLK=collections.defaultdict(set)
for at,a,b,kd,f_,t_ in m.execute('select at_node,line_a,line_b,kind,valid_from,valid_to from track_link'):TLK[G_(at),a,b].add((kd,f_,t_));TLK[G_(at),b,a].add((kd,f_,t_))
chain=set()
for e,v in attr.items():
    v=sorted(v,key=lambda x:x['valid_from_lo'] or '')
    for p,q in zip(v,v[1:]):
        if p['lineage_id']==q['lineage_id'] and p['line_id']!=q['line_id']:chain.add((p['line_id'],q['line_id'],q['valid_from_lo'] or ''))
rows=set()
for a,b,d in chain:
    for x in {G_(n_) for q in LROUTES[a] for n_ in RNODES.get(q,())}&{G_(n_) for q in LROUTES[b] for n_ in RNODES.get(q,())}:
        for (g_,l1,c),kk in list(TLK.items()):
            if g_!=x or l1!=a or c==b:continue
            ka={k_ for k_,f_,t_ in kk if t_==ON or (lohi(t_)[1] if t_ else '9999')>=d}
            kb={k_ for k_,f_,t_ in TLK.get((x,b,c),())}
            if ka and ka!=kb:rows.add((ln(a),ln(b),d,x,ln(c),tuple(sorted(ka)),tuple(sorted(kb))))
put('K01 이관 앞뒤 노선의 같은 노드 연결 종류가 다름',sorted(rows),30,lvl='warn')
rows=[]
for j in JN:
    a,b=j['line_id'],j['other_line_id']
    if j['source']!='derived':continue
    if sysc(a)!=sysc(b):rows.append(('방식',ln(a),ln(b),j['node_id'],sysc(a),sysc(b)))
    else:
        p=ivl(j['valid_from'],j['valid_to'])
        ga_,gb_=(gauge_on(a,p[0],p[3],j['node_id']),gauge_on(b,p[0],p[3],j['node_id'])) if p and GAUGE else (set(),set())
        if ga_ and gb_ and not gfit(ga_,gb_):rows.append(('궤간',ln(a),ln(b),j['node_id'],sorted(ga_,key=str),sorted(gb_,key=str)))
put('K02 근거 없는 분기·이어짐의 두 노선 궤간·방식이 다름',rows,30)
rows=[]
for a_,b_ in HT.get('NOCONT',{}).get('값',[]):
    A_,B_=lines_of(a_),lines_of(b_)
    if not A_ or not B_:rows.append(('이름 없음',a_,b_,'' if A_ else a_,'' if B_ else b_));continue
    ga={G_(n_) for l in A_ for q in LROUTES[l] for n_ in RNODES.get(q,())};gb={G_(n_) for l in B_ for q in LROUTES[l] for n_ in RNODES.get(q,())}
    if not ga&gb:rows.append(('만나는 곳 없음',a_,b_))
put('K02 NOCONT 행이 쓰이지 않음(노선 없음·만나는 곳 없음)',rows,30)
put('K02 근거 없는 이어짐(source=derived continue)',[(ln(j['line_id']),ln(j['other_line_id']),j['node_id']) for j in JN if j['source']=='derived' and j['is_continue']],20,lvl='warn')
# 끝난 연결: 다음 역·끝 역이 link 기간에 그 계통에서 정차하는가 (그날 선로로 계산, K03)
def stops_of(rid,line,x):
    if rid:return SPR.get((rid,x),[])
    return [p for q in LROUTES.get(line,[]) for p in SPR.get((q,x),[])]
# 계통 끝 노드 행은 정차가 없어도 그 행 기간 내내 고를 수 있다(5번 결정: 승하차 불가 끝 노드). 연결의 다음·끝 역이 될 수 있다
# 고를 수 있는 기간 = 행 기간(정차) ∪ 끝 노드로 고를 수 있는 서지 않는 기간(route_stop_select, 숨김(none)은 뺀다). 정차로 보는 검사는 SPR만 읽는다
SELIV=collections.defaultdict(list)
if m.execute("select 1 from sqlite_master where type='table' and name='route_stop_select'").fetchone():
    # 고를 수 있는 기간만(「_view」는 보이기만 함)
    for r_ in m.execute("select route_id,node_id,valid_from,valid_to from route_stop_select where style not in ('none','moved') and style not like '%\\_view' escape '\\'"):SELIV[r_[0],r_[1]].append(ivl(r_[2],r_[3]))
ENDIV=collections.defaultdict(list)
for rid_,v_ in allstop.items():
    for z_ in v_:
        if rid_ in routes and z_['node_id'] in (routes[rid_]['from_node'],routes[rid_]['to_node']):ENDIV[rid_,z_['node_id']].append(ivl(z_['valid_from'],z_['valid_to']))
for (rid_,x_),v_ in SELIV.items():
    if rid_ in routes:ENDIV[rid_,x_]+=v_
ENDNODES={v for r_ in routes.values() for v in (r_['from_node'],r_['to_node'])}
ROWIV=collections.defaultdict(list)
for rid_,v_ in allstop.items():
    for z_ in v_:ROWIV[rid_,z_['node_id']].append(ivl(z_['valid_from'],z_['valid_to']))
for k_,v_ in SELIV.items():ROWIV[k_]+=v_
def ends_of(rid,line,x):
    if rid and ENDIV.get((rid,x)):return ENDIV[rid,x]
    return [p for q in LROUTES.get(line,[]) for p in ENDIV.get((q,x),[])]
rows=[];rows2=[]
for k in LINKS:
    p=ivl(k['valid_from'],k['valid_to'])
    if not p or (p[3]<=BASE):continue
    for c in('next_stop_node','terminal_node'):
        x=k[c]
        if not x:continue
        # 끝 역은 같은 노선의 다른 계통(옛 경로·갈래)을 지나 줄기 끝까지 간다(3회차 W1a). 그 계통에 없으면 노선 전체에서 본다
        sp=stops_of(k['other_route_id'],k['other_line_id'],x)
        if k['other_route_id'] and not any(may(p,q) for q in sp):sp=stops_of(None,k['other_line_id'],x)
        ep=ends_of(k['other_route_id'],k['other_line_id'],x)
        if not sp and not ep:continue
        if not any(may(p,q) for q in sp) and not any(may(p,q) for q in ep):rows.append((k['route_id'],k['seq'],k['kind'],c[:4],nn(x),k['valid_from'],k['valid_to']))
        elif not sp:continue
        elif c=='terminal_node' and max(q[3] for q in sp)<p[2] and not(ep and max(q[3] for q in ep)>=p[2]):rows2.append((k['route_id'],k['seq'],k['kind'],nn(x),max(q[3] for q in sp),k['valid_to']))
put('K03 link 다음·끝 역이 link 기간에 정차하지 않음',rows,30)
put('K03 link 기간 안에 끝 역이 폐역이 됨(행 나눔 없음)',rows2,30,lvl='warn')
REDGE={rid:set(v) for rid,v in redge.items()}
EINC_N0={r_[0]:(r_[1],r_[2]) for r_ in m.execute('select id,from_node,to_node from edge')}
rows=[];rows2=[]
for k in LINKS:
    if k['kind']!='continue' or not k['node'] or k['route_id'] not in routes:continue
    rid=k['route_id'];s=rstop[rid];x=k['node']
    # 다음 역이 이 계통에서 끝 역 바로 옆 정차역(들어온 쪽)이고 그 이음 기간에 거기 서면 되돌아가는 방면이다(2회차 종합 K03 「직전 역(들어온 쪽)」).
    # 확장 행·이음 전에 끝난 옛 정차(徳島線 佃→阿波池田 1950~)와 순환을 닫는 방면(大阪環状線 新今宮→天王寺)은 아니다
    y_=k['next_stop_node'];st_=[z for z in s if z['is_stop']]
    adj_={st_[1]['node_id'] if st_ and st_[0]['node_id']==x and len(st_)>1 else None,st_[-2]['node_id'] if st_ and st_[-1]['node_id']==x and len(st_)>1 else None}-{None}
    # 같은 노선 옛 선형 계통과의 이음(따로 계통, 2번안 2026-11-23)은 앱이 한 줄로 이어 그린다(§8.3). 다음 역 계산이 옛 선형을 함께 걸어 자기 계통 역이 나온다
    if routes.get(k['other_route_id'] or '',{}).get('line_id')==routes[rid]['line_id'] and (rid in _OLD_R or k['other_route_id'] in _OLD_R):continue
    if s and x in(s[0]['node_id'],s[-1]['node_id']) and not routes[rid]['closed'] and y_ in adj_ and any(may(ivl(k['valid_from'],k['valid_to']),q) for q in SPR.get((rid,y_),[])):rows.append((rid,nn(x),ln(k['other_line_id']),nn(y_)))
    q=k['other_route_id']
    # 함께 쓰는 칸이 있어도 다음 정차역이 자기 계통 밖이면 겹친 쪽이 아니라 공유 칸 너머로 이어진다(옛 경로 계통이 본선 마지막 칸을 함께 쓰고 그 끝에서 본선으로, 遠州 八幡·外房 蘇我, 2026-11-14)
    # 칸은 그 이음 기간에 양 끝 행이 다 살아 있을 때만 이 계통 칸이다(그날 없던 끝 역 대신 붙인 앞 역 칸은 그 기간에만, 키쿠치선 구선 쿠로이시 1995 전)
    pk_=ivl(k['valid_from'],k['valid_to'])
    def _alive_e(e_,rid_=rid,x_=x,pk_=pk_):
        a_,b_=EINC_N0.get(e_,(None,None));n2_=b_ if a_==x_ else a_
        return any(z['node_id']==n2_ and may(pk_,ivl(z['valid_from'],z['valid_to'])) for z in rstop[rid_])
    sh_={e_ for e_ in EINC[x]&REDGE.get(q,set())&REDGE.get(rid,set()) if _alive_e(e_)} if q else set()
    if q and q!=rid and routes.get(q,{}).get('line_id')==routes[rid]['line_id'] and sh_ and (not k['next_stop_node'] or k['next_stop_node'] in {z['node_id'] for z in s}):rows2.append((rid,q,nn(x),x))
put('K03 끝 역 continue의 다음 역이 자기 계통 안쪽 역',rows,30)
put('K03 같은 노선 계통 사이 continue가 칸을 공유(겹친 방향으로 이어짐)',sorted(set(rows2)),30)
# 옛 경로 계통이 합류점 너머까지 이어짐: 끝난 칸이 있는 지선 계통에서, 닿는 칸이 모두 같은 노선 다른 계통과 함께 쓰는 현행 칸인 역이
# 이 계통에서는 폐역으로 끝남 (長尾線 옛 경로의 木太東口·林道). 옛 칸에 닿는 합류점 역은 빼고 본다
ROUTES_OF_E=collections.defaultdict(set)
EINC_N={r_[0]:(r_[1],r_[2]) for r_ in m.execute('select id,from_node,to_node from edge')}
for rid,ed in redge.items():
    for e in ed:ROUTES_OF_E[e].add(rid)
rows=[]
for rid,ed in redge.items():
    r=routes[rid];L=r['line_id']
    if r['role']=='main' or all(life[e]['valid_to']==ON for e in ed):continue
    for y in rstop[rid]:
        x=y['node_id'];inc=EINC[x]&REDGE[rid]
        if not y['is_stop'] or y['valid_to']==ON or x not in node_cur or not inc:continue
        if all(life[e]['valid_to']==ON and any(routes[q]['line_id']==L for q in ROUTES_OF_E[e]-{rid}) for e in inc):
            # 합류점(옛 칸과 함께 쓰는 칸이 만나는 노드)이 이 계통 영업 동안 정차역이 아니었던 때가 있으면, 갈아탈 수 있는 다음 공통 정차역까지 함께 쓴 칸으로 가야 한다
            # (遠州鉄道 옛 新浜松 계통: 遠州病院은 1958-06-01부터 역, 그 전엔 八幡까지. 2026-11-13)
            own_=[e for e in REDGE[rid] if not any(routes[q]['line_id']==L for q in ROUTES_OF_E[e]-{rid})]
            jn_={n_ for e in own_ for n_ in EINC_N.get(e,())}&{n_ for e in REDGE[rid]-set(own_) for n_ in EINC_N.get(e,())}
            # 합류점 행이 이 계통에서 서지 않는 행(그날 없던 역 자리, 大浦支線 옛 경로 메디컬센터 1961 전)이어도 같다
            if any(z['node_id'] in jn_ and (not z['is_stop'] or (z['valid_from'] or '0000')>(routes[rid].get('opened') or y.get('valid_from') or '0000')) for z in rstop[rid]):continue
            rows.append((rid,nn(x),x,y['valid_to']))
put('K03 옛 경로 계통이 합류점 너머 현행 역까지 이어짐',rows,30)
if GAUGE:
    rows=[]
    for j in JN:
        p=ivl(j['valid_from'],j['valid_to'])
        if not p:continue
        ga,gb=gauge_on(j['line_id'],p[0],p[3],j['node_id']),gauge_on(j['other_line_id'],p[0],p[3],j['node_id'])
        if ga and gb and not gfit(ga,gb) and not(j['source'] or '').startswith('http'):rows.append((ln(j['line_id']),ln(j['other_line_id']),j['node_id'],sorted(ga,key=str),sorted(gb,key=str),j['valid_from'],j['valid_to']))
    put('K04 연결 기간에 두 노선 궤간이 다름(改軌·분단)',rows,30)
else:R['K04 정보: 궤간 표 없음(data/overrides/line_gauge.json이 생기면 改軌 검사를 켬)']=dict(n=0,lvl='info',sample=[])
rows=[]
for k in LINKS:
    if k['kind']=='branch' and not k['next_stop_node']:rows.append((k['route_id'],k['seq'],ln(k['other_line_id']),k['valid_from'],k['valid_to']))
    if k['kind']=='continue' and k['node'] and k['next_stop_node']==k['node']:rows.append((k['route_id'],k['seq'],'다음 역=자기 노드',nn(k['node'])))
put('K10 분기의 다음 역 없음·이어짐의 다음 역이 자기 노드',rows,30)
# 현행 계통에서 함께 정차한 이웃 두 역 사이를 그 계통 칸(숨은 노드만 지남)으로 갈 수 없음: 줄기에 끼어든 옛 역
rows=[]
for rid,ed in redge.items():
    r=routes[rid];s=[x for x in rstop[rid] if x['is_stop']]
    if r['closed'] or len(s)<2:continue
    hid={x['node_id'] for x in rstop[rid] if not x['is_stop']}
    g=collections.defaultdict(set)
    for e in ed:a,b=E[e];g[a].add(b);g[b].add(a)
    for p,q in zip(s,s[1:]):
        if not may(RSIV[rid,p['node_id']],RSIV[rid,q['node_id']]):continue
        seen={p['node_id']};st=[p['node_id']];hit=False
        while st and not hit:
            u=st.pop()
            for v in g[u]:
                if v==q['node_id']:hit=True;break
                if v in hid and v not in seen:seen.add(v);st.append(v)
        if not hit:rows.append((rid,nn(p['node_id']),nn(q['node_id'])));break
put('K10 현행 계통 이웃 정차역 사이가 계통 칸으로 이어지지 않음',rows,30)
# ---- 병주 (K09): 같은 group 노드 쌍을 다른 노선이 같은 기간에 잇는 칸
PR=OVR('parallel_runs.json')['rows']
PRK=set()
for x in PR:
    ls=frozenset(x['lines']);ns=x['nodes']
    if len(ns)>=2:PRK.add((ls,frozenset((G_(ns[0]),G_(ns[-1])))))
byg=collections.defaultdict(list)
for e,(a,b) in E.items():
    if a==b:continue
    for l in {x['line_id'] for x in attr.get(e,[])}:byg[frozenset((G_(a),G_(b)))].append((e,l))
def aiv(e,l):
    v=[x for x in attr[e] if x['line_id']==l];return (min(x['valid_from_lo'] or '0000' for x in v),'',' ',max(x['valid_to_hi'] or '9999' for x in v))
cand=[];rows=[]
for k,v in byg.items():
    if len(k)<2:continue
    for i_ in range(len(v)):
        for j_ in range(i_):
            (e1,l1),(e2,l2)=v[i_],v[j_]
            if l1==l2 or not may(aiv(e1,l1),aiv(e2,l2)):continue
            cand.append((e1,e2,l1,l2))
            if (frozenset((l1,l2)),k) not in PRK:rows.append((ln(l1),ln(l2),e1,e2,nn(E[e1][0]),nn(E[e1][1])))
# 같은 역 쌍만으로는 병주가 아니다(지하철·지상 별선). 이중 집계 위험은 아래 선형 겹침 검사가 잡는다
put('K09 같은 역 쌍을 잇는 다른 노선 칸에 병주 판정 없음',rows,30,lvl='warn')
def dec(s):
    """구글 polyline(1e-5)을 (위도, 경도) 목록으로"""
    out=[];i=0;la=lo_=0
    while i<len(s):
        for c in (0,1):
            sh=r_=0
            while True:
                b=ord(s[i])-63;i+=1;r_|=(b&0x1f)<<sh;sh+=5
                if b<0x20:break
            d=~(r_>>1) if r_&1 else r_>>1
            if c==0:la+=d
            else:lo_+=d
        out.append((la/1e5,lo_/1e5))
    return out
SHP=dict(m.execute('select edge_id,polyline from edge_shape').fetchall())
_DC={}
def DEC(e):
    if e not in _DC:_DC[e]=dec(SHP[e])
    return _DC[e]
def segd(p,a,b):
    """점 p와 선분 ab의 거리(km, 평면 근사)"""
    kx=111.32*math.cos(math.radians(p[0]));ax,ay=(a[1]-p[1])*kx,(a[0]-p[0])*110.57;bx,by=(b[1]-p[1])*kx,(b[0]-p[0])*110.57
    dx,dy=bx-ax,by-ay;L2=dx*dx+dy*dy
    t=0 if L2==0 else max(0,min(1,-(ax*dx+ay*dy)/L2))
    return math.hypot(ax+t*dx,ay+t*dy)
def pdist(p,pl):return min((segd(p,a,b) for a,b in zip(pl,pl[1:])),default=hav(p,pl[0]) if pl else 9e9)
rows=[]
for e1,e2,l1,l2 in cand:
    if e1==e2 or e1 not in SHP or e2 not in SHP or (frozenset((l1,l2)),frozenset((G_(E[e1][0]),G_(E[e1][1])))) in PRK:continue
    a_,b_=DEC(e1),DEC(e2)
    if len(a_)<2 or len(b_)<2:continue
    if len(a_)>len(b_):a_,b_=b_,a_
    near=sum(pdist(p,b_)<.01 for p in a_)
    if near>=.9*len(a_):rows.append((ln(l1),ln(l2),e1,e2,nn(E[e1][0]),nn(E[e1][1])))
put('K09 판정 없는 같은 역 쌍 두 칸의 선형이 90% 넘게 겹침(10m 안, 이중 집계)',rows,30)
# ---- 환승 (K06·K07·K08)
GR=collections.defaultdict(list)
for i,gid in GRP.items():
    if i in pub and gid:GR[gid].append(i)
def nsp(x):return [p for _,p in SP.get(x,[])]
def cowork(a,b):return any(may(p,q) for p in nsp(a) for q in nsp(b))
rows=[]
for gid,v in GR.items():
    for i_ in range(len(v)):
        for j_ in range(i_):
            a,b=v[i_],v[j_];f=frozenset((a,b))
            # 같은 노선을 함께 가지면 환승이 아니다(compile hub_rule ②). 정밀 좌표로 400 m 넘는 다른 사업자 쌍은 K07(다른 근거 필요)이 본다
            if NLINES[a]&NLINES[b] or f in HP or f in HUBNOT or f in MOVED or not cowork(a,b):continue
            if a in pos and b in pos and pos[a][2]==pos[b][2]=='precise' and hav(pos[a],pos[b])>.4 and not NOP[a]&NOP[b]:continue
            # 다른 이전 쌍의 옛 자리 둘(사업자 다름)은 지금 역 묶음을 함께 쓸 뿐 같은 역이었다는 근거가 아니다 (compile hub_rule 옛 자리 규칙: 京急 (初代)羽田空港–모노레일 옛 羽田)
            if a in MVOLD and b in MVOLD and MVOLD[a]!=MVOLD[b] and not NOP[a]&NOP[b]:continue
            rows.append((gid,nn(a),a,nn(b),b))
put('K06 같은 group 두 노드가 함께 영업하는데 환승 쌍 없음',rows,30)
rows=[]
# 두 역이 함께 선 날이 없으면 환승 쌍이 될 수 없다(compile hub_rule ①, 같은 역 묶음만 합치는 행: 奥津軽いまべつ). 손 쌍 표는 노드 ID 쌍이다(2회차 B3)
for x in OVR('hub_join.json'):
    if frozenset((x['node'],x['with'])) not in HP and cowork(x['node'],x['with']) and not NLINES[x['node']]&NLINES[x['with']]:rows.append(('hub_join',x['node'],x['with']))
NBYJA=collections.defaultdict(set)
for (t_,i_),v_ in nm.items():
    if t_=='node':
        for r_ in v_.get('ja',[]):NBYJA[znorm_(r_[0])].add(i_)
for a_,b_ in OVR('hub_pairs.json'):
    A_,B_=({a_},{b_}) if a_.startswith('n_') and b_.startswith('n_') else (NBYJA.get(znorm_(a_),set()),NBYJA.get(znorm_(b_),set()))
    if not any(cowork(p,q) for p in A_ for q in B_):continue
    if not any(frozenset((p,q)) in HP for p in A_ for q in B_):rows.append(('hub_pairs',a_,b_))
put('K06 hub_join·hub_pairs 행이 환승 쌍이 안 됨',rows,30)
HM=collections.defaultdict(set)
for h_,x in m.execute('select hub_id,node_id from hub_member'):HM[h_].add(x)
put('K06 hub 이름의 노드가 그 hub에 없음',[(h_,'n_'+h_[4:]) for h_ in HM if ('n_'+h_[4:]) in GRP and ('n_'+h_[4:]) not in HM[h_]],30)
# 공간 격자 (약 1km 칸)
GRID=collections.defaultdict(list)
for i in pub:
    if i in pos:GRID[int(pos[i][0]*100),int(pos[i][1]*100)].append(i)
def near_nodes(i,r_km):
    if i not in pos:return []
    a,b=int(pos[i][0]*100),int(pos[i][1]*100);o=[]
    for da in(-1,0,1):
        for db in(-1,0,1):
            for j in GRID.get((a+da,b+db),()):
                if j!=i and hav(pos[i],pos[j])<=r_km:o.append(j)
    return o
rows=[];rows2=[]
EKIMAE=re.compile(r'^(.{2,}?)(?:駅前|電車前|駅|前)$')
for i in pub:
    mt=EKIMAE.match(bj(i))
    near=near_nodes(i,.5)
    if mt:
        for j in near:
            if strip_old(bj(j)) in(mt.group(1),mt.group(1)+'駅') and NLINES[i]!=NLINES[j] and frozenset((i,j)) not in HP and frozenset((i,j)) not in HUBNOT and cowork(i,j):rows.append((nn(i),i,nn(j),j,round(hav(pos[i],pos[j])*1000)))
    for j in near:
        if j<i and hav(pos[i],pos[j])<=.2 and NLINES[i]!=NLINES[j] and not NLINES[i]&NLINES[j] and frozenset((i,j)) not in HP and frozenset((i,j)) not in HUBNOT and frozenset((i,j)) not in MOVED and cowork(i,j):rows2.append((nn(i),i,nn(j),j,round(hav(pos[i],pos[j])*1000)))
put('K06 「X駅前」 정류장이 500m 안 X역과 환승 쌍 없음',rows,30,lvl='warn')
put('K06 200m 안 다른 노선 역이 함께 영업하는데 환승 쌍 없음',sorted(rows2,key=lambda x:x[4]),40,lvl='warn')
rows=[]
for gid,v in GR.items():
    p=[x for x in v if x in pos and pos[x][2]=='precise']
    for i_ in range(len(p)):
        for j_ in range(i_):
            a,b=p[i_],p[j_];d=hav(pos[a],pos[b])
            if frozenset((a,b)) in MOVED:continue
            if d>1 or (d>.4 and not NOP[a]&NOP[b] and strip_old(bj(a))==strip_old(bj(b))):rows.append((gid,nn(a),a,nn(b),b,round(d*1000)))
put('K07 group 안 먼 쌍(1km 초과, 또는 400m 초과·다른 사업자·이름만 같음)',sorted(set(rows),key=lambda x:-x[5]),30)
rows=[]
for f,v in HP.items():
    a,b=sorted(f)
    if any('"doc"' in (x[3] or '') for x in v) and a in pos and b in pos and hav(pos[a],pos[b])>.5:rows.append((v[0][0],nn(a),nn(b),round(hav(pos[a],pos[b])*1000)))
put('K07 역 문서 근거 환승 쌍이 500m 넘음(U01 확인 목록)',sorted(rows,key=lambda x:-x[3]),30,lvl='warn')
rows=[];rows2=[]
for i in pub:
    for j in near_nodes(i,.1):
        if j>=i or bj(i)!=bj(j) or not NOP[i]&NOP[j] or not cowork(i,j) or frozenset((i,j)) in HUBNOT:continue
        (rows2 if GRP.get(i)==GRP.get(j) else rows).append((nn(i),i,j,round(hav(pos[i],pos[j])*1000),sorted(NOP[i]&NOP[j])[:2]))
put('K08 같은 사업자·같은 이름·100m 안 노드 둘이 다른 group',rows,30)
put('K08 같은 사업자·같은 이름·100m 안 노드 둘(같은 group, 합칠 후보 U04)',rows2,30,lvl='warn')
# ---- 이름 (K11~K17)
NROWS=collections.defaultdict(list)
for t,i,l,x,k,src,li,vf,vt in n.execute('select entity_type,entity_id,lang,text,kana,source,line_id,valid_from,valid_to from name'):NROWS[t,i,l].append((x,k,src,li,vf,vt))
rows=set()
for (t,i,l),v in NROWS.items():
    if t!='node' or l!='ja':continue
    b=base('node',i,'ja')
    for x,k,src,li,vf,vt in v:
        if vt and not li and b and src in('n05','wikipedia+n05') and x==b[0]:rows.add((i,x,vf,vt,src))
RN05=OVR('renames_n05.json')
for i,v in RN05.items():
    b=base('node',i,'ja')
    for r_ in v:
        if b and r_[0]==b[0]:rows.add((i,r_[0],r_[1],r_[2],'renames_n05.json'))
put('K11 N05 옛 이름이 그 노드 지금 이름과 같음(뒤집힘)',sorted(rows),30)
rows=[];wide=[]
for (t,i,l),v in NROWS.items():
    if l!='ja':continue
    by=collections.defaultdict(list)
    for x,k,src,li,vf,vt in v:
        if vf or vt:by[li].append((x,vf,vt,ivl(vf,vt)))
    for li,w in by.items():
        for x,vf,vt,p in w:
            if p is None:rows.append((t,i,li,x,vf,vt,'날짜 해석 불가'));continue
            if (vf and vf==vt) or p[0]>=p[3]:rows.append((t,i,li,x,vf,vt,'길이 0·거꾸로'))
            if vt and vt.startswith('[') and p[3]>p[2] and (datetime.date.fromisoformat(p[3])-datetime.date.fromisoformat(p[2])).days>731:wide.append((t,i,x,vf,vt))
        w=sorted([z for z in w if z[3]],key=lambda z:z[3][0])
        for a_,b_ in zip(w,w[1:]):
            if a_[2]!=b_[1] and must(a_[3],b_[3]):rows.append((t,i,li,a_[0],a_[1],a_[2],b_[0],b_[1],b_[2],'겹침'))
put('K11 같은 대상·노선 이름 행 기간이 겹침·길이 0·거꾸로',rows,30)
put('K11 옛 이름 끝 날짜 범위가 2년 넘음',wide,30,lvl='warn')
def names_at(x,L):
    """그 노선 화면에서 노드 x의 일본어 이름과 기간: 노선 전용 행이 있으면 그것, 없으면 노선 무관 행. 기간 없는 행은 날짜 있는 행 뒤 기간"""
    v=NROWS.get(('node',x,'ja'),[])
    w=[r_ for r_ in v if r_[3]==L] or [r_ for r_ in v if not r_[3]]
    dated=[(r_[0],ivl(r_[4],r_[5])) for r_ in w if r_[4] or r_[5]]
    top=max((p[3] for _,p in dated if p),default='0000-01-01')
    return dated+[(r_[0],(top,top,'9999-12-31','9999-12-31')) for r_ in w if not r_[4] and not r_[5]]
rows=[];rows2=[]
for rid,s in rstop.items():
    L=routes[rid]['line_id'];g=collections.defaultdict(list);gb=collections.defaultdict(set)
    for y in s:
        if not y['is_stop']:continue
        x=y['node_id'];gb[bj(x)].add(x)
        for t_,p in names_at(x,L):
            for q in SPR.get((rid,x),[]):
                if p and may(p,q):g[t_].append((x,(max(p[0],q[0]),'',' ',min(p[3],q[3]))))
    for t_,v in g.items():
        hit=[(a[0],b[0]) for i_,a in enumerate(v) for b in v[:i_] if a[0]!=b[0] and may(a[1],b[1])]
        if hit:rows.append((rid,t_,nn(hit[0][0]),nn(hit[0][1])))
    for t_,xs in gb.items():
        # 「（旧）」끼리는 같은 이름이어도 된다: 폐역 해가 함께 보여 어느 것인지 안다 (사용자 결정 2026-11-21, 桜島（旧）)
        if len(xs)>1 and not t_.endswith('（旧）'):rows2.append((rid,t_,sorted(xs)[:3]))
put('K11 같은 계통에서 같은 날 표시 이름이 같은 역 둘',rows,30)
put('K25 같은 계통에 지금 이름이 같은 노드 둘(（旧） 없음)',rows2,30)
_END_SP=collections.defaultdict(list)
for rid_,v_ in rstop.items():
    for z_ in v_:
        if z_['node_id'] in (routes[rid_]['from_node'],routes[rid_]['to_node']):_END_SP[z_['node_id']].append(((z_['valid_from_lo'] or '0000'),'',('9999' if z_['valid_to']==ON else (z_['valid_to_hi'] or '9999')),''))
# 서지 않고 고를 수 있는 기간(route_stop_select: 끝 노드·격하된 신호장)도 그 이름이 보이는 기간이다
if m.execute("select 1 from sqlite_master where name='route_stop_select'").fetchone():
    for r_ in m.execute("select node_id,valid_from_lo,valid_to,valid_to_hi from route_stop_select where style not in ('none','moved')"):
        _END_SP[r_[0]].append(((r_[1] or '0000'),'',('9999' if r_[2] in (ON,'ongoing') else (r_[3] or '9999')),''))
rows=[];rows2=[]
for (t,i,l),v in NROWS.items():
    if t!='node' or l!='ja' or i not in pub:continue
    sp=nsp(i)
    if not sp:continue
    for x,k,src,li,vf,vt in v:
        if not vt or li:continue
        p=ivl(vf,vt)
        if not p or p[3]<BASE:continue
        # 계통 끝으로 지나가던 기간(승하차 불가 끝 노드, 5번 결정)도 그 이름이 보이는 기간이다
        if not any(p[2]>q[0] and q[2]>p[0] for q in sp+_END_SP.get(i,[])):rows.append((i,x,vf,vt,src))
    last=max([q[3] for q in sp]+[q[2] for q in _END_SP.get(i,[])])
    if last<'9999':
        for x,k,src,li,vf,vt in v:
            p=ivl(vf,vt)
            if vt and not li and p and p[2]>last:rows2.append((i,bj(i),x,vt,last))
put('K12 옛 이름 기간이 그 노드 어떤 정차 기간과도 안 겹침',rows,30)
put('K12 폐역 노드의 지금 이름이 폐역 뒤 개칭에서 옴',rows2,30)
rows=[]
for (t,i,l),v in NROWS.items():
    if l!='ko':continue
    for x,k,src,li,vf,vt in v:
        if '〈' in x:
            jr=[r_[0] for r_ in NROWS.get((t,i,'ja'),[]) if r_[3]==li and r_[4]==vf and r_[5]==vt]
            if jr and not any('〈' in y for y in jr):rows.append((t,i,x,jr[0]))
put('K13 ko에 〈〉 부제가 있는데 ja에 없음',rows,30)
KSFX=re.compile(r'(仮乗降場|臨時乗降場|仮停車場|臨時駅|乗降場|駅)$')
def tnorm(s):return KSFX.sub('',znorm_(strip_old(s)))
rows=[];rows2=[]
for (t,i,l),v in NROWS.items():
    if t!='node' or l!='ja':continue
    byt=collections.defaultdict(set);byk=collections.defaultdict(set)
    for x,k,src,li,vf,vt in v:
        if k and src!='ja_as_is':byt[x].add(k);byk[k].add(tnorm(x))
    for x,ks in byt.items():
        if len({re.sub('[うおー]','',z) for z in ks})>1:rows.append((i,x,sorted(ks)))
    for k,ts in byk.items():
        if len(ts)>1:rows2.append((i,k,sorted(ts)))
    b=base('node',i,'ja')
    if b and b[1] and i in pub:
        for j in near_nodes(i,.5):
            c=base('node',j,'ja')
            if c and c[1]==b[1] and tnorm(c[0])!=tnorm(b[0]) and j>i:rows2.append((i,j,b[1],b[0],c[0]))
put('K13 같은 노드 같은 글자 이름 행의 읽기가 다름',rows,30,lvl='warn')
put('K13 다른 글자 이름과 읽기가 같음(같은 노드·500m 안)',rows2,30,lvl='warn')
rows=[];rows2=[];rows3=[];rows4=[];rows5=[]
curL={a['line_id'] for v in attr.values() for a in v if a['valid_to']==ON}
for (t,i,l),v in NROWS.items():
    if t!='node' or l!='ja':continue
    olds={x for x,k,src,li,vf,vt in v if vt and not li}
    b=base('node',i,'ja')
    for x,k,src,li,vf,vt in v:
        if not li:continue
        if i in pub and not k and src!='ja_as_is':rows.append((i,li,x,'kana'))
        if i in pub and not any(r_[3]==li for r_ in NROWS.get((t,i,'en'),[])):rows.append((i,li,x,'en'))
        if vf or vt:continue
        # 그 노드에서 그 노선이 선 기간. 노선 전용 이름이 기간 없이 남는 규칙(gen_source K14)을 같은 기준으로 읽는다
        sp_=[p for q_,p in SP.get(i,[]) if p and routes.get(q_,{}).get('line_id')==li]
        # 같은 글자 옛 이름의 기간이 그 노선 정차 기간 전체를 덮으면 날짜 모르는 화면용으로 기간 없이 두는 것이 규칙이다
        # (長野原線 1945~1971의 長野原, 이름 ~1991, appsim M4). 덮지 않을 때만 겹친 행이다
        def _cov(z):
            p=ivl(z[4],z[5])
            return bool(p and sp_) and max(q[3] for q in sp_)<=p[2] and (not z[4] or p[1]<=min(q[0] for q in sp_))
        # 끝난 노선의 마지막 날 이름(compile 규칙, 9회차 N 설계 판단): 같은 글자 옛 이름 기간이 그 노선 정차 끝을 덮으면 날짜 모르는 화면용 이름이다.
        # 그 노선 영업 중의 다른 옛 이름은 노선 한정 기간 행이 덮는지 아래 「가림」 검사가 본다
        def _cov_end(z):
            p=ivl(z[4],z[5])
            return bool(p and sp_) and max(q[2] for q in sp_)<=p[2] and p[0]<max(q[2] for q in sp_)
        if x in olds and not any(_cov(z) or _cov_end(z) for z in v if z[0]==x and z[5] and not z[3]):rows2.append((i,li,x))
        if li in curL and b and x!=b[0] and i in pub:rows3.append((i,ln(li),x,b[0]))
        if sp_:
            f0=min(q[0] for q in sp_)
            # 가리는 것은 그 노선이 서던 동안의 다른 옛 이름뿐이다. 노선이 끝난 뒤에 쓰인 이름(宮津線 丹後山田 시절 뒤의 野田川)은 가리지 않는다
            # 같은 글자·같은 기간의 노선 한정 기간 행이 있으면(노선 고유 + 날짜가 가장 앞섬, §14.2) 그 옛 이름은 가려지지 않는다 (9회차 N)
            _lper={(z,vf_,vt_) for z,k_,s_,li_,vf_,vt_ in v if li_==li and (vf_ or vt_)}
            late=[(z,vt_) for z,k_,s_,li_,vf_,vt_ in v if not li_ and vt_ and ivl(vf_,vt_) and any(may(ivl(vf_,vt_),q) for q in sp_) and ivl(vf_,vt_)[2]>f0 and z!=x and (z,vf_,vt_) not in _lper]
            if late:rows4.append((i,ln(li),x,f0,late[:2]))
put('K14 노선 전용 이름 행에 kana·en 없음',rows,30)
put('K14 기간 없는 노선 전용 이름이 그 노드 옛 이름과 같음',rows2,30)
put('K14 오늘 영업 노선의 기간 없는 노선 전용 이름이 지금 이름과 다름',rows3,30,lvl='warn')
put('K14 기간 없는 노선 전용 이름이 그 노선 영업 중의 옛 이름을 가림',rows4,30)
named={i for (t,i,l) in NROWS if t=='route'}
put('K14 이름 행이 하나도 없는 계통',[r for r in routes if r not in named and routes[r]['line_id'] not in HIDL],30)
LH=OVR('line_history.json')
LPN={(r_[0],r_[1],r_[2]) for r_ in m.execute("select line_id,name_ja,valid_from from line_period where kind='name'")}
put('K15 line_history 이름 행이 노선 기간 이름으로 안 쓰임',[(x['line'],x['name_ja'],x['valid_from']) for x in LH if x.get('kind')=='name' and (x['line'],x['name_ja'],x['valid_from']) not in LPN],30)
LATT=collections.defaultdict(list)
for v in attr.values():
    for a in v:LATT[a['line_id']].append(a)
OPJA={i:re.sub(r'^(株式会社)|(株式会社)$','',v[0]) for (t,i),v in ja.items() if t=='operator'}
lpn={r_[0] for r_ in LPN}
rows=[]
for l,ops in LOP.items():
    if len(ops)<2 or l in lpn:continue
    top=max(a['valid_to_hi'] or '' for a in LATT[l]);last={a['operator_id'] for a in LATT[l] if (a['valid_to_hi'] or '')==top}
    for o in ops-last:
        w=OPJA.get(o,'')
        if len(w)>=3 and w in ln(l):rows.append((ln(l),w,sorted(last)[:2]))
put('K15 사업자가 바뀐 노선 이름에 옛 사업자 이름이 남고 기간 이름 없음',rows,30,lvl='warn')
rows=[]
for lg in('ko','en'):
    c=collections.defaultdict(set)
    for (t,i),v in nm.items():
        if t=='line':
            b=base('line',i,lg)
            if b:c[b[0]].add(i)
    rows+=[(lg,x,sorted(v)) for x,v in c.items() if len(v)>1]
put('K16 서로 다른 노선의 ko·en 이름이 같음',rows,30)
rows=[]
OPL=collections.defaultdict(set)
for l,ops in LOP.items():
    if LT.get(l) in('tram','trolley','subway'):
        for o in ops:OPL[o,LT[l]].add(l)
for o,ls in OPL.items():
    if len(ls)<3:continue
    for lg in('ja','en'):
        nms=[base('line',l,lg)[0] for l in ls if base('line',l,lg)]
        pre=set()
        for i_ in range(len(nms)):
            for j_ in range(i_):
                p=os.path.commonprefix([nms[i_],nms[j_]])
                if len(p)>=(2 if lg=='ja' else 6):pre.add(p)
        if pre:
            # 가장 많은 노선이 함께 쓰는 머리(같으면 긴 것)
            p=max(pre,key=lambda z:(sum(x.startswith(z) for x in nms),len(z),z));w=[x for x in nms if x.startswith(p)]
            if 2<=len(w)<len(nms):rows.append((o,lg,p,len(w),len(nms),sorted(set(nms)-set(w))[:3]))
put('K16 같은 사업자 노선 이름의 머리 꼴이 섞임',rows,30,lvl='warn')
put('K17 이름 끝이 「駅」인데 읽기 끝이 えき 아님',sorted({(i,x,k) for (t,i,l),v in NROWS.items() if t=='node' and l=='ja' for x,k,*_ in v if x.endswith('駅') and k and not k.endswith('えき')}),30)
# ---- 정차·km·역 (K18~K29)
rows=[]
for tb,q in(('route_stop_period','select route_id,node_id,valid_from,valid_to from route_stop_period'),('stop_mark','select node_id,line_id,valid_from,valid_to from nm.stop_mark'),
           ('route_link','select route_id,seq,valid_from,valid_to from route_link'),('junction','select line_id,node_id,valid_from,valid_to from junction'),
           ('hub_pair','select node_a,node_b,valid_from,valid_to from hub_pair'),('track_link','select at_node,line_a,valid_from,valid_to from track_link'),
           ('line_period','select line_id,kind,valid_from,valid_to from line_period')):
    if tb=='stop_mark':q=q.replace('nm.','')
    for a,b,f_,t_ in (n if tb=='stop_mark' else m).execute(q):
        p=ivl(f_,t_)
        if p is None:rows.append((tb,a,b,f_,t_,'해석 불가'))
        elif (f_ and f_==t_) or (f_ and t_ and p[0]>=p[3]):rows.append((tb,a,b,f_,t_))
put('K18 기간 시작≥끝(정차 기간·표식·연결·환승·노선 기간)',rows,30)
# 이설: 옛 선로 칸(끝난 옛 경로 계통 전용 칸 route_only, 또는 relocated로 닫힌 칸) 묶음의 양 끝을 같은 노선 다른 칸으로 잇는 새 경로가
# 옛 선로가 닫히기 전에 이미 열려 있음 (옛·새 선로 이중 영업, 足尾 草木ダム·東北本線 野内–青森). 끝 노드는 같은 group이면 같은 자리로 본다
RO=dict(m.execute('select id,route_only from edge').fetchall())
def _ivand(p,q):
    """두 기간 목록의 교집합 [(시작, 끝)]"""
    return sorted((max(a,c),min(b,d)) for a,b in p for c,d in q if max(a,c)<min(b,d))
def ivx_all(es,L):
    """칸 묶음이 모두 노선 L로(그 칸에 L 행이 없으면 아무 노선으로) 운휴 없이 영업한 기간. 날짜는 확실한 쪽(시작의 늦은 끝, 끝의 이른 끝)"""
    out=[('0000-01-01','9999-12-31')]
    for e in es:
        at_=AT.get((L,e)) or attr.get(e,[])
        p=[(a['valid_from_hi'] or a['valid_from_lo'] or '0000-01-01',a['valid_to_lo'] or '9999-12-31') for a in at_]
        q=[(r['valid_from_hi'] or r['valid_from_lo'] or '0000-01-01',r['valid_to_lo'] or '9999-12-31') for r in LR.get(e,[]) if r['status']=='open']
        out=_ivand(out,_ivand(p,q))
    # 맞닿은 기간은 잇는다(사업자·소속 행이 바뀐 날은 영업이 이어짐)
    m_=[]
    for a,b in out:
        if m_ and a<=m_[-1][1]:m_[-1]=(m_[-1][0],max(m_[-1][1],b))
        else:m_.append((a,b))
    return m_
def ivx(old,new):
    """옛 선로 기간과 새 길 기간의 겹침. 새 길이 옛 선로보다 먼저 열려 있던 겹침은 뺀다: 옛 선로가 아니라 나중에 생긴 다른 길이다
    (北方貨物線 2025-07-05 하루 여객 운행 때 이미 영업 중이던 東海道本線). 같은 날 열린 겹침(새 선로가 원래 개업일부터 열림)은 남는다"""
    return sorted((max(a,c),min(b,d)) for a,b in old for c,d in new if max(a,c)<min(b,d) and c>=a)
# 병용·과도기 근거 (compile 보고서 relocation_overlap: 옛 선로를 닫는 사건의 overlap 칸)
OVL=collections.defaultdict(list)
_rp=os.path.join(B,'report.json')
for o_ in (json.load(open(_rp,encoding='utf-8')).get('relocation_overlap',[]) if os.path.exists(_rp) else []):
    OVL[o_['edge']].append(dict(o_,from_lo=lohi(o_['from'])[0],close_hi=lohi(o_['close'])[1] if o_['close']!=ON else '9999-12-31'))
rows=[]
EKM=dict(m.execute('select edge_id,km from edge_km').fetchall())
for L,rs in LROUTES.items():
    led={e for q in rs for e in redge.get(q,[])}
    old={e for e in led if (RO.get(e) and life[e]['valid_to']!=ON) or life[e]['close_reason']=='relocated'}
    if not old:continue
    new_=led-old
    ng=collections.defaultdict(set)
    for e in sorted(new_):a_,b_=E[e];ng[a_].add((b_,e));ng[b_].add((a_,e))
    gnode={}
    for x in sorted(ng):gnode.setdefault(G_(x),x)
    og=collections.defaultdict(set)
    for e in old:a_,b_=E[e];og[a_].add(e);og[b_].add(e)
    seen=set()
    for e0 in sorted(old):
        if e0 in seen:continue
        comp={e0};st=[e0]
        while st:
            e=st.pop()
            for x in E[e]:
                if x in ng or G_(x) in gnode:continue
                for f_ in og[x]-comp:comp.add(f_);st.append(f_)
        seen|=comp
        ends_=sorted({x if x in ng else gnode[G_(x)] for e in comp for x in E[e] if x in ng or G_(x) in gnode})
        if len(ends_)<2:continue
        X,Y=ends_[0],ends_[-1]
        prev={X:None};q_=[X]
        while q_:
            u=q_.pop(0)
            for v,e in sorted(ng[u]):
                if v not in prev:prev[v]=(u,e);q_.append(v)
        if Y not in prev:continue
        path=[];u=Y
        while prev[u]:path.append(prev[u][1]);u=prev[u][0]
        # 두 선로가 그 노선으로 함께 영업한 날: 칸마다 그 노선 소속(edge_attr)이고 운휴가 아닌(edge_life open) 기간의 교집합.
        # 새 길이 다른 노선 소속이던 때(越後線 白山–関屋 새 선로는 1951-06-25~12-15 信越本線)나 운휴 중이던 때(梅田貨物線)는 함께 영업이 아니다
        # 순환선을 닫는 짧은 토막·지선(仙台市電 循環線 花京院–仙台駅前 0.6 km)은 옛 선로가 아니다: 다른 길이 그 토막보다 세 배 넘게 길면 이설로 보지 않는다
        if sum(EKM.get(e,0) for e in path)>3*max(sum(EKM.get(e,0) for e in comp),.05):continue
        ov=ivx(ivx_all(comp,L),ivx_all(path,L))
        # 근거 칸(옛 선로를 닫는 사건의 overlap, compile 보고서 relocation_overlap)이 덮는 병용·과도기는 허용한다
        ov=[(a_,b_) for a_,b_ in ov if not any(o_['from_lo']<=a_ and b_<=o_['close_hi'] for e in comp for o_ in OVL.get(e,()))]
        if ov:rows.append((ln(L),nn(X),nn(Y),'함께 영업',ov[0][0],ov[0][1],sorted(comp)[0],path[0]))
put('K19 옛 선로와 새 선로가 같은 날 함께 영업(이설 이중 영업)',rows,30)
def ALLN(x):return {strip_old(r_[0]) for r_ in NROWS.get(('node',x,'ja'),[])}
rows=[]
for rid,s in rstop.items():
    if not s:continue
    L=routes[rid]['line_id']
    for x in {s[0]['node_id'],s[-1]['node_id']}:
        if x not in pos:continue
        for q in LROUTES[L]:
            if q==rid:continue
            for y in RNODES.get(q,()):
                if y!=x and y in pos and ALLN(x)&ALLN(y) and hav(pos[x],pos[y])<.2 and frozenset((x,y)) not in MOVED:rows.append((rid,q,nn(x),x,y,round(hav(pos[x],pos[y])*1000)))
put('K19 같은 노선 다른 계통에 같은 이름·200m 안 노드 둘(이전 쌍 없음)',sorted(set(rows)),30)
rows=[]
for rid,s in rstop.items():
    r=routes[rid]
    # 지선·옛 경로 계통(branch)의 km는 그 계통 안의 위치라 공식 기점과 관계없다 (compile K20 원점 규칙과 같은 기준)
    if r['closed'] or r['role']!='main' or not s or not any(life[e]['valid_to']==ON for e in redge[rid]):continue
    cur_=[y for y in s if y['is_stop'] and y['valid_to']==ON and y['node_id'] in pub]
    if not cur_:continue
    o=min(s,key=lambda y:y['km_cum'] if y['km_cum'] is not None else 9e9)
    # 원점 노드의 이 계통 칸이 아직 영업 중이면(한때 역이던 신호장 三岐朝明 1950–1989, 지금 三岐線·近鉄連絡線의 기점) compile도 원점을 옮기지 않는다 (7회차 2026-11-14)
    if any(life[e]['valid_to']==ON for e in redge[rid] if o['node_id'] in E[e]):continue
    if o['km_cum']==0 and o['node_id'] not in node_cur and NKIND.get(o['node_id'])=='station' and min(y['km_cum'] for y in cur_)>.05:rows.append((rid,nn(o['node_id']),o['valid_to'],nn(cur_[0]['node_id']),min(y['km_cum'] for y in cur_)))
put('K20 현행 계통 km 원점이 폐역',rows,30)
# 칸 하나로 이어진 같은 계통 두 역의 km 차 = 그 칸 km (갈래·고리 계통의 옛 선로 역 포함, K21)
ERA=collections.defaultdict(set)
for e,l,k in m.execute('select edge_id,line_id,km from edge_km_era'):ERA[e].add(k)
for e,mm in m.execute('select edge_id,m from edge_km_period'):ERA[e].add(round(mm/1000,1))
rows=[]
for rid,ed in redge.items():
    s=rstop[rid];c=collections.Counter(y['node_id'] for y in s);at={y['node_id']:y for y in s}
    for e in ed:
        a,b=E[e]
        if c[a]!=1 or c[b]!=1 or a==b:continue
        p,q=at[a],at[b]
        if p['km_cum'] is None or q['km_cum'] is None or p['km_estimated'] or q['km_estimated']:continue
        # 옛 선로가 지금 선로에 다시 붙는 칸(옛 선로 끝 → 합류 역)은 두 km의 기준이 달라(옛 km는 갈라지는 역에서 잰다) 칸 km와 맞지 않는 것이 규칙이다 (compile K21)
        if e in OLDE:
            po_=all(x in OLDE for x in EINC[a]&set(ed));qo_=all(x in OLDE for x in EINC[b]&set(ed))
            if po_!=qo_ and (q['km_cum']>p['km_cum'])==po_:continue
            # 막다른 옛 선 끝의 옛 역(스위치백 北宇智（旧） 31.6)이 합류 역(北宇智 31.5)보다 km가 크면 열차는 옛 역에서 되돌아 나와 합류 역을 지난다.
            # 계통 km는 노드마다 하나라 그 칸 km(되돌아 나오는 0.3)와 두 km 차(0.1)는 맞지 않는 것이 규칙이다 (7회차 2026-11-14)
            if po_!=qo_ and (p['km_cum']>q['km_cum'])==po_:continue
        d=round(abs(q['km_cum']-p['km_cum']),1)
        if all(abs(d-k)>.1 for k in {km[e]}|ERA[e]):rows.append((rid,nn(a),nn(b),d,km[e]))
put('K21 칸으로 이어진 두 역 km 차가 칸 km와 다름',rows,30)
# 지금 영업 중인 臨時 정류장(stop_status kind rinji, 끝 없음)은 사업자·위키 어디에도 km 원문이 없는 일이 있다(岡電 (臨)京橋, 10회차 G2).
# 근거 하나로 확정하지 않고(근거 등급 규칙) 추정값을 둔 채 확인 목록(warn)으로 남긴다. 그 밖의 정차역은 그대로 오류
_RJON={(x_.get('route'),x_['node']) for x_ in OVR('stop_status.json') if x_.get('kind')=='rinji' and not x_.get('to')}
_k23=[(rid,y['node_id']) for rid,s in rstop.items() for y in s if y['is_stop'] and y['valid_to']==ON and y['km_estimated']]
put('K23 오늘 영업 중인 정차역 km가 추정값',[(r_,nn(x_)) for r_,x_ in _k23 if (r_,x_) not in _RJON and (None,x_) not in _RJON],30)
put('K23 오늘 영업 중인 臨時 정류장 km가 추정값(공개 km 원문 없음, 확인 목록)',[(r_,nn(x_)) for r_,x_ in _k23 if (r_,x_) in _RJON or (None,x_) in _RJON],30,lvl='warn')
MARKN=collections.defaultdict(list)
for x,l,kd,f_,t_ in n.execute('select node_id,line_id,kind,valid_from,valid_to from stop_mark'):MARKN[x].append((l,kd,ivl(f_,t_),f_,t_))
rows=[]
for rid,s in rstop.items():
    tm=[y for y in s if y['is_stop'] and y['node_id'] in MARKN and y['node_id'] in pos]
    for i_ in range(len(tm)):
        for j_ in range(i_):
            a,b=tm[i_]['node_id'],tm[j_]['node_id']
            if a!=b and hav(pos[a],pos[b])<.5 and any(may(p,q) for p in SPR.get((rid,a),[]) for q in SPR.get((rid,b),[])):rows.append((rid,nn(a),nn(b),round(hav(pos[a],pos[b])*1000)))
put('K21 같은 계통 500m 안 임시역 둘이 같은 날 함께 정차',rows,30)
rows=[]
for rid,s in rstop.items():
    if not s:continue
    for y in (s[0],s[-1]):
        if y['km_estimated'] and any(a['denominator_class']=='normal' for e in EINC[y['node_id']]&REDGE[rid] for a in attr[e]):rows.append((rid,nn(y['node_id']),y['km_cum']))
# 추정 km는 안쪽 계산(완주율·분모 단위)에 쓰는 것이 규칙이다(DESIGN §4.5 「km를 모르는 역」). 근거 km가 있는데 추정으로 남은 것은 audit_ext가 잡는다
put('K23 계통 끝 역 km가 추정값인데 그 칸이 분모 normal',rows,30,lvl='info')
# ---- 열람 전용 역 (K24)
AS=[dict(r) for r in m.execute('select * from archive_stop')]
KM={(rid,y['node_id']):y['km_cum'] for rid,s in rstop.items() for y in s}
rows=[];rows2=[]
for a in AS:
    if a['after_id'] and a['after_id']==a['before_id']:rows.append((a['id'],a['route_id'],nn(a['after_id'])))
    if a['km'] is None or not a['route_id']:continue
    lo_=KM.get((a['route_id'],a['after_id'])) if a['after_id'] else None
    hi_=KM.get((a['route_id'],a['before_id'])) if a['before_id'] else None
    if lo_ is not None and hi_ is not None and lo_>hi_+.05:rows2.append((a['id'],'순서 거꾸로',lo_,a['km'],hi_));continue
    if (lo_ is not None and a['km']<lo_-.05) or (hi_ is not None and a['km']>hi_+.05):rows2.append((a['id'],a['route_id'],lo_,a['km'],hi_))
put('K24 열람 전용 역 after=before',rows,30)
put('K24 열람 전용 역 km가 앞뒤 역 km 범위 밖·순서 거꾸로',rows2,40)
AN={i:v[0] for (t,i),v in ja.items() if t=='archive'}
c=collections.defaultdict(set)
for a in AS:
    if a['km'] is not None:c[AN.get(a['id']),round(a['km'],1)].add((a['line_id'],a['route_id'],a['id']))
# 기준일 전 정차를 열람 전용으로 바꾼 행(source rule:pre1950_stop)은 노선마다 그 노선 계통의 정차였던 같은 노드(두 노선의 공동 끝 船津橋)라 이름 복사 중복이 아니다 (9회차 S)
_ASRC={a['id']:a['source'] for a in AS}
put('K24 같은 이름·km 열람 전용 역이 두 노선에',[(k[0],k[1],sorted(v)) for k,v in c.items() if len({z[0] for z in v})>1 and not all(_ASRC.get(z[2])=='rule:pre1950_stop' for z in v)],30)
# after·before 사이에 그 열람 전용 역이 있던 시기에 선(어느 계통이든) 다른 정차역이 있음: km로 보면 그 역들 사이 자리
rows=[]
for a in AS:
    if a['km'] is None or not a['route_id'] or not a['after_id'] or not a['before_id']:continue
    lo_,hi_=KM.get((a['route_id'],a['after_id'])),KM.get((a['route_id'],a['before_id']))
    if lo_ is None or hi_ is None:continue
    lo_,hi_=min(lo_,hi_),max(lo_,hi_);p=ivl(a['opened'],a['closed'])
    # 앞뒤 역의 이전 쌍 다른 쪽(江戸橋（旧）의 지금 江戸橋, 옛 浜大津의 びわ湖浜大津)은 같은 역의 다른 시기라 사이에 선 역이 아니다
    mid=[y for y in rstop[a['route_id']] if y['is_stop'] and y['km_cum'] is not None and lo_+.05<y['km_cum']<hi_-.05 and any(may(p,q) for q in nsp(y['node_id']))
         and frozenset((y['node_id'],a['after_id'])) not in MOVED and frozenset((y['node_id'],a['before_id'])) not in MOVED]
    if mid:rows.append((a['id'],a['route_id'],nn(a['after_id']),nn(a['before_id']),a['km'],len(mid),nn(mid[0]['node_id'])))
put('K24 열람 전용 역 after·before가 이웃 역이 아님(그 시기 사이에 선 역이 있음)',rows,30)
# 열람 전용의 모르는 날짜는 null이 규칙이다(DESIGN §4.5 「모르는 날짜와 km는 null, 화면에 ~?」). 채울 거리로만 센다
put('K24 열람 전용 노선 폐지일 없음',[(r[0],AN.get(r[0])) for r in m.execute('select id from archive_line where closed is null')],30,lvl='warn')
put('K24 열람 전용 역 이름이 화물·신호장',[(a['id'],AN.get(a['id'])) for a in AS if re.search(r'貨物|信号|操車|分岐|専用',AN.get(a['id']) or '')],30,lvl='warn')
# ---- 이전 (K25)
rows=[];rows2=[]
_REAL={(x['old'],x['new']) for x in json.load(open(os.path.join(ROOT,'data','overrides','moved.json'),encoding='utf-8')) if x.get('realigned') or x.get('km_official')}
# 이전과 같은 날 이름도 바뀐 쌍(moved.json renamed: 粟ヶ崎遊園前→内灘 등)은 「새 노드에 이전 뒤 옛 이름 없음」 확인 목록에서 뺀다 (6회차 2026-11-14)
_RENAMED={(x['old'],x['new']) for x in json.load(open(os.path.join(ROOT,'data','overrides','moved.json'),encoding='utf-8')) if x.get('renamed')}
for o,w,d in m.execute('select * from node_move'):
    # 이전 뒤 경로 변경으로 km 축이 바뀐 쌍(moved.json realigned, 八幡 1999)은 3배 규칙에서 뺀다 (3회차 근거 조사 2026-11-13)
    # 공식 営業キロ 차가 실제 이동 거리보다 큰 쌍(moved.json km_official: km 근거와 옛 자리 판독 좌표가 둘 다 있는 것, 今津 1993)도 뺀다 (6회차 2026-11-14)
    if (o,w) in _REAL:continue
    if o in pos and w in pos:
        dd=hav(pos[o],pos[w])
        for rid in sorted(NROUTES[o]&NROUTES[w]):
            ka,kb=KM.get((rid,o)),KM.get((rid,w))
            if ka is None or kb is None:continue
            kd=abs(ka-kb)
            # 옛 노드 좌표가 새 노드 복사본이면(高松（旧）) 어긋남의 크기와 상관없이 결함이다
            if dd<.01 and kd>=.1:rows.append((nn(o),o,w,rid,round(dd,2),round(kd,1),'좌표 복사'));break
            # 선로를 바꾸며 옮긴 이전(옛 노드에만 닿는 칸이 이전 무렵 끝남: 日羽·佐久間·東名)은 営業キロ를 그대로 둔 付替라 km 차가 작아도 정상이다 (2회차 audit 근거 조사 2026-11-13)
            realign=any(e not in EINC[w] and life.get(e) and life[e]['valid_to']!=ON and life[e]['valid_to'][:4]<=d[:4] for e in EINC[o])
            if abs(dd-kd)>.2:(rows if max(dd,kd)>3*max(min(dd,kd),.05) and not realign else rows2).append((nn(o),o,w,rid,round(dd,2),round(kd,1)))
            break
    on,wn=strip_old(bj(o)),bj(w)
    if on!=wn and (o,w) not in _RENAMED and not any(r_[0]==on and r_[5] and ivl(r_[4],r_[5]) and ivl(r_[4],r_[5])[3]>d for r_ in NROWS.get(('node',w,'ja'),[])):rows2.append((nn(o),o,w,'새 노드에 이전 뒤 옛 이름 없음',on,wn,d))
put('K25 이전 쌍의 좌표 거리와 km 차가 3배 넘게 어긋남',rows,30)
put('K25 이전 쌍 확인 목록(좌표 거리·km 차 0.2km 넘게 다름, 새 노드 옛 이름 없음)',rows2,30,lvl='warn')
# ---- 임시역 표식 (K26)
rows=[];rows2=[]
for x,v in MARKN.items():
    for l,kd,p,f_,t_ in v:
        sp=[q for rid,q in SP.get(x,[]) if routes.get(rid,{}).get('line_id')==l and q]
        if not sp:rows.append((x,ln(l),kd,'그 노선 정차 없음'));continue
        if p and ((f_ and p[1]<min(q[0] for q in sp)) or (t_ and p[2]>max(q[3] for q in sp))):rows.append((x,ln(l),kd,f_,t_,min(q[0] for q in sp),max(q[3] for q in sp)))
    byl=collections.defaultdict(list)
    for l,kd,p,f_,t_ in v:
        if p:byl[l].append(p+(kd,))
    for l,ps in byl.items():
        if sum(1 for z in v if z[0]==l and z[1]=='rinji')>=3:continue
        ps.sort()
        for a,b in zip(ps,ps[1:]):
            # 종류가 바뀐 표식 사이(仮乗降場 → 역 승격 → 臨時駅, 只見線 柿ノ木 1987~2013)는 정식 역이던 기간이다. 仮乗降場은 역으로 오른 날부터
            # 표시가 없다(DESIGN §9.1.2). 같은 종류 표식이 끊긴 것만 빠진 기간으로 본다
            if a[4]!=b[4]:continue
            if a[3]<b[0]:
                if any(q and q[0]<=a[3] and q[3]>=b[0] for rid,q in SP.get(x,[]) if routes.get(rid,{}).get('line_id')==l):rows2.append((x,ln(l),a[3],b[0]))
put('K26 임시역 표식 기간이 그 노선 정차 기간 밖',rows,30)
put('K26 임시역 표식이 끊겼는데 정차는 이어짐',rows2,30)
# ---- 도도부현 (K29): 같은 계통에서 같은 도도부현 사이에 낀 10km 안 다른 도도부현 역 묶음
rows=[]
for rid,s in rstop.items():
    v=[y for y in s if y['node_id'] in NPREF]
    i_=0
    while i_<len(v):
        j_=i_
        while j_+1<len(v) and NPREF[v[j_+1]['node_id']]==NPREF[v[i_]['node_id']]:j_+=1
        if i_>0 and j_+1<len(v) and NPREF[v[i_-1]['node_id']]==NPREF[v[j_+1]['node_id']]!=NPREF[v[i_]['node_id']] and (v[j_+1]['km_cum'] or 0)-(v[i_-1]['km_cum'] or 0)<10:
            rows.append((rid,[nn(y['node_id']) for y in v[i_:j_+1]][:4],NPREF[v[i_]['node_id']],NPREF[v[i_-1]['node_id']]))
        i_=j_+1
put('K29 이웃 역과 다른 도도부현으로 낀 역(확인 목록, 町田처럼 실제로 낀 곳 있음)',rows,30,lvl='warn')
rows=[]
for e,p_,k_ in m.execute('select edge_id,pref,km from edge_pref'):
    if e in E and p_ not in {NPREF.get(E[e][0]),NPREF.get(E[e][1])} and k_>=1:rows.append((e,p_,NPREF.get(E[e][0]),NPREF.get(E[e][1]),k_))
put('K29 edge 도도부현이 양 끝 노드 도도부현 밖(1km 이상)',rows,30,lvl='warn')
# ---- 운휴·분모
rows=[]
for rid,ed in redge.items():
    s=rstop[rid];g=collections.Counter()
    for e in ed:a,b=E[e];g[a]+=1;g[b]+=1
    if len(ed)!=len(g)-1 or any(c>2 for c in g.values()):continue
    for e1,e2 in zip(ed,ed[1:]):
        if not set(E[e1])&set(E[e2]):rows.append((rid,e1,e2));break
put('K35 한 줄 계통의 route_edge 순번이 경로 순서와 다름',rows,30,lvl='warn')
put('K35 1950 전에 끝난 분모 normal 칸',sorted({(e,ln(a['line_id']),a['valid_to']) for e,v in attr.items() for a in v if a['denominator_class']=='normal' and (a['valid_to_hi'] or '9999')<=BASE}),30)
# 운휴 수록 기준(DESIGN §17)은 30일 안에 재개한 운휴를 넣지 않는 것이다. 재개 없이 폐지·이관으로 끝난 운휴는 영업의 끝이라 길이를 보지 않는다
# 짧아도 남길 운휴(suspend 사건의 short_ok, compile과 같은 규칙: 津島口仮乗降場 앞뒤처럼 닿을 정차가 없는 날)는 뺀다
_SHOK={(x_['add']['line'],x_['add']['date']) for x_ in json.load(open(os.path.join(ROOT,'data','overrides','events_fix.json'),encoding='utf-8')) if isinstance(x_.get('add'),dict) and x_['add'].get('short_ok')}
rows=[]
for e,v in LR.items():
    for x,y in zip(v,v[1:]):
        if any((a_['line_id'],x['valid_from']) in _SHOK for a_ in attr.get(e,[])):continue
        if x['status']=='suspended' and y['status']=='open' and y['valid_from']==x['valid_to'] and real(x['valid_from']) and real(x['valid_to']) and (datetime.date.fromisoformat(x['valid_to'])-datetime.date.fromisoformat(x['valid_from'])).days<30:rows.append((e,ln(attr[e][0]['line_id']) if attr.get(e) else '',x['valid_from'],x['valid_to']))
put('K35 운휴 기간 30일 미만',rows,30)
rows=[]
# 끝 정차가 끝난 뒤에도 그 끝에서 이어지는 끝 이어짐(continue)이 있으면 승하차 불가 끝 노드로 지나가는 것이 맞다(옛 확장 행 자리, 5번 결정 2026-11-19)
_CONT35=collections.defaultdict(list)
for r_,q_,f_,t_ in m.execute("select l.route_id,l.seq,l.valid_from,l.valid_to from route_link l where l.kind='continue'"):_CONT35[(r_,q_)].append((lohi(f_)[0] or '0000',(lohi(t_)[1] if t_ not in (None,'ongoing') else None) or '9999'))
for rid,s in rstop.items():
    if routes[rid]['closed'] or not s:continue
    for y in (s[0],s[-1]):
        x=y['node_id'];sp=SPR.get((rid,x),[])
        if not y['is_stop'] or not sp:continue
        last=max(q[3] for q in sp)
        if last>='9999':continue
        for e in EINC[x]&REDGE[rid]:
            if any((a['valid_from_lo'] or '0000')<=last<(a['valid_to_hi'] or '9999') for a in AT[routes[rid]['line_id'],e]) and any((z['valid_from_lo'] or '0000')<=last<(z['valid_to_hi'] or '9999') and z['status']=='open' for z in LR[e]) and not any(f_<=last<t_ for f_,t_ in _CONT35.get((rid,y['seq']),())):
                # 같은 노선의 다른 계통이 그 칸을 그때도 쓰면 칸이 열려 있는 것이 맞다(옛 경로 계통이 함께 쓰던 본선 칸, 2026-11-13)
                if any(routes[q]['line_id']==routes[rid]['line_id'] and not routes[q]['closed'] for q in ROUTES_OF_E.get(e,set())-{rid}):continue
                rows.append((rid,nn(x),last,e));break
put('K35 계통 끝 정차역이 사라진 뒤에도 끝 칸이 영업 중',rows,30)
# ---- 위치 (K37)
PLAT={r[0]:(r[1],r[2]) for r in m.execute('select node_id,lat,lon from platform')}
# 노선별 승강장 좌표(station_platform)가 있으면 그 노선 계통은 그 점으로 잰다 (東京 京葉線 승강장 등)
PLAT_LINE={(r[0],r[1]):(r[2],r[3]) for r in m.execute('select node_id,line_id,lat,lon from station_platform where lat is not null')}
rows=[]
for rid,s in rstop.items():
    for y in s:
        x=y['node_id']
        if not y['is_stop'] or x not in pos or pos[x][2]!='precise':continue
        pl=[DEC(e) for e in EINC[x]&REDGE[rid] if e in SHP]
        if not pl:continue
        p=PLAT_LINE.get((x,routes[rid]['line_id'])) or PLAT.get(x) or pos[x][:2]
        d=min(pdist(p,q) for q in pl if len(q)>1) if any(len(q)>1 for q in pl) else 0
        if d>.15:rows.append((round(d*1000),rid,nn(x),x))
put('K37 역 점이 그 계통 선형에서 150m 넘게 떨어짐',sorted(set(rows),reverse=True),30)
# 근거로 확정한 역 km(km_confirmed)와 계통 누계 km가 다르면 구간 길이 보정이 빠진 것이다. km_confirmed는 추정 표시만 떼므로 값은 source_patch/km로 맞춰야 한다 (河和線 四海波 24.1/23.7, 7회차 2026-11-14)
_KMC_=[x for x in json.load(open(os.path.join(ROOT,'data','overrides','km_confirmed.json'),encoding='utf-8'))]
rows=[]
for x in _KMC_:
    ks=[r[0] for r in m.execute('select km_cum from route_stop where route_id=? and node_id=?',(x['route'],x['node'])) if r[0] is not None]
    if ks and all(abs(k-x['km'])>.051 for k in ks):rows.append((x['route'],nn(x['node']),x['km'],ks[:2]))
put('K23 확정 km(km_confirmed)와 계통 km가 다름',rows,30)
put('K37 오늘 영업 중인 역 위치가 대략값',sorted({(x,nn(x)) for x in node_cur if x in pos and pos[x][2]!='precise'}),30)
# ==== 3회차 전수 점검 연결 검사 (W1a, 판 2026-11-15.1) ====
# 계통 이음(route_link)이 양쪽 계통의 실제 영업·궤간·선로 구조와 맞는가. compile의 연결 생성과 따로 DB만 읽어 다시 본다
_DAY1=datetime.timedelta(days=1)
def _d(s):
    try:return datetime.date.fromisoformat(s)
    except Exception:return None
def _ivs_union(iv):
    out=[]
    for a,b in sorted(iv):
        if a>=b:continue
        if out and a<=out[-1][1]:out[-1]=(out[-1][0],max(out[-1][1],b))
        else:out.append((a,b))
    return out
def _ivs_minus(A,B):
    """A 기간들에서 B(합집합)를 뺀 토막들"""
    out=[]
    for a,b in A:
        cur=a
        for c,d in B:
            if d<=cur or c>=b:continue
            if c>cur:out.append((cur,c))
            cur=max(cur,d)
        if cur<b:out.append((cur,b))
    return out
def _open_iv(e,line=None):
    """칸 e가 영업(open)한 기간들(가능한 쪽: 시작 lo, 끝 hi). line이면 그 노선 소속 기간과 겹친 것만"""
    iv=[((r['valid_from_lo'] or '0000-01-01'),(r['valid_to_hi'] or '9999-12-31') if r['valid_to']!=ON else '9999-12-31') for r in LR.get(e,[]) if r['status']=='open']
    if line:
        mem=_ivs_union([((a['valid_from_lo'] or '0000-01-01'),(a['valid_to_hi'] or '9999-12-31') if a['valid_to']!=ON else '9999-12-31') for a in attr.get(e,[]) if a['line_id']==line])
        iv=[(max(a,c),min(b,d)) for a,b in iv for c,d in mem if max(a,c)<min(b,d)]
    return _ivs_union(iv)
def _sure(p):
    """정차·연결 기간의 확실한 부분 [시작 hi, 끝 lo)"""
    return (p[1] or '0000-01-01',p[2] or '9999-12-31') if p else None
RPAIR={rid:{frozenset(E[e]):e for e in v if e in E} for rid,v in redge.items()}
def _route_open_at(rid,x):
    """계통 rid의 칸 가운데 x에 닿는 칸들이 영업한 기간(합집합). 칸 영업 기록이 없으면 None"""
    # 같은 두 노드 사이에 시기가 다른 칸이 여럿일 수 있다(松戸線 前原–新津田沼（旧） 1947–1953·1961–1968). RPAIR는 쌍마다 칸 하나라 계통 칸 전부를 본다
    es=[e for e in redge.get(rid,()) if e in E and x in E[e]]
    if not es or not all(LR.get(e) for e in es):return None
    return _ivs_union([iv for e in es for iv in _open_iv(e,routes[rid]['line_id'])])
# K54 닿을 수 없는 정차: 정차 기간 토막(1950 뒤 확실한 부분) 내내 그 역에 닿는 그 계통 칸이 하나도 영업하지 않음 (3회차 chugoku_shikoku_2-023, 三江線 野井).
# 노선 휴지 동안 휴지 구간 역은 정차로 둔다(DB 관례: 휴지는 칸 상태). 그래서 휴지와 겹친 일부 날이 아니라 토막 전체가 닿을 수 없는 정차만 결함이다
rows=[]
for rid,s in rstop.items():
    for y in s:
        if not y['is_stop']:continue
        x=y['node_id'];op=_route_open_at(rid,x)
        if op is None:continue
        for p in SPR.get((rid,x),[]):
            a,b=_sure(p)
            a=max(a,BASE);b=min(b,TODAY)
            if a>=b:continue
            un=_ivs_minus([(a,b)],op)
            if un==[(a,b)]:rows.append((rid,nn(x),x,a,b))
put('K54 닿을 수 없는 정차(정차 토막 내내 그 역에 닿는 계통 칸이 모두 휴지·폐지)',sorted(set(rows)),40)
# K55 근거 표 없이 다른 노드로 잇는 이어짐·분기 (3회차 chugoku_shikoku_2-024 立久恵線 出雲市)
_TH=HT.get('THROUGH',{}).get('값',[])
THP={(x['a'],x['b']) for x in _TH}|{(x['b'],x['a']) for x in _TH}
TSROWS=json.load(open(os.path.join(ROOT,'data','overrides','tram_systems.json'),encoding='utf-8'))['rows'] if os.path.exists(os.path.join(ROOT,'data','overrides','tram_systems.json')) else []
TSP={(x['x'],x['y']) for x in TSROWS}|{(x['y'],x['x']) for x in TSROWS}
rows=[]
for k in LINKS:
    if k['kind'] not in('continue','branch') or not k['other_node'] or k['route_id'] not in routes:continue
    a=routes[k['route_id']]['line_id']
    if G_(k['other_node'])!=G_(k['node']) and (a,k['other_line_id']) not in THP and (a,k['other_line_id']) not in TSP:rows.append((k['route_id'],nn(k['node']),ln(k['other_line_id']),nn(k['other_node']),k['valid_from'],k['valid_to']))
put('K55 근거 표 없이 다른 노드로 잇는 이어짐·분기',rows,30)
# K56 연결 기간이 양쪽 계통의 그 역 영업 기간 밖 (3회차 kanto_2-019: 정차 공백·휴지 동안 남은 환승·이어짐)
def _node_live(line,nodes_):
    """노선 line이 nodes_ 가운데 어느 역에서든 정차하고 그 역에 닿는 칸이 영업한 기간(합집합)"""
    iv=[]
    for q in LROUTES.get(line,[]):
        for x in nodes_:
            sp=SPR.get((q,x))
            # 승하차 불가 끝 노드 행은 정차가 없어도 그 칸이 영업한 때 고를 수 있다(5번 결정): 그 행 기간을 정차 기간 자리에 쓴다
            if not sp and (q,x) in _EP_ROW:sp=_EP_ROW[(q,x)]
            # 계통 끝 노드 행은 정차가 아닌 동안(늘린 끝 행의 route_stop_gap)에도 고를 수 있다. 그 노드를 지나는 다른 계통의 행도 같다(5번 결정: 지나가는 계통 화면에도 보임)
            if x in ENDNODES and ROWIV.get((q,x)):sp=(sp or [])+ROWIV[q,x]
            # 끝은 날마다 정한다: 어느 행이든 서지 않고 고를 수 있는 기간(route_stop_select)에는 고를 수 있다 (土讃線 1950–1962 끝 佃 ↔ 徳島線 佃)
            if SELIV.get((q,x)):sp=(sp or [])+SELIV[q,x]
            if not sp:continue
            op=_route_open_at(q,x)
            st=_ivs_union([((p[0] or '0000-01-01'),(p[3] or '9999-12-31')) for p in sp if p])
            iv+=st if op is None else [(max(a,c),min(b,d)) for a,b in st for c,d in op if max(a,c)<min(b,d)]
    return _ivs_union(iv)
_EP_ROW={}
for rid_,v_ in rstop.items():
    for z_ in v_:
        if z_['is_end_point'] and not z_['is_stop']:_EP_ROW.setdefault((rid_,z_['node_id']),[]).append(ivl(z_['valid_from'],z_['valid_to']))
GMEM=collections.defaultdict(set)
for x_,g_ in GRP.items():GMEM[g_ or x_].add(x_)
_nlc={}
rows=[]
for k in LINKS:
    if k['at_edge'] or k['route_id'] not in routes or not k['node'] or not LROUTES.get(k['other_line_id']):continue
    p=_sure(ivl(k['valid_from'],k['valid_to']))
    if not p:continue
    a,b=max(p[0],BASE),min(p[1],TODAY)
    if a>=b:continue
    own=_node_live(routes[k['route_id']]['line_id'],[k['node']])
    on_=k['other_node'] or k['node'];kk=(k['other_line_id'],G_(on_))
    if kk not in _nlc:_nlc[kk]=_node_live(k['other_line_id'],sorted(GMEM[G_(on_)]|{on_}))
    un=[(c,d) for c,d in _ivs_minus([(a,b)],[(max(x[0],y[0]),min(x[1],y[1])) for x in own for y in _nlc[kk] if max(x[0],y[0])<min(x[1],y[1])]) if _d(c) and _d(d) and (_d(d)-_d(c)).days>=2]
    if un:rows.append((k['route_id'],nn(k['node']),k['kind'],ln(k['other_line_id']),k['valid_from'],k['valid_to'],un[0]))
put('K56 연결 기간이 양쪽 계통의 그 역 영업 기간(정차·칸 영업) 밖',rows,30)
def _rep(k):
    p=ivl(k['valid_from'],k['valid_to'])
    if not p:return None
    if k['valid_to']==ON:return max(TODAY,p[1] or '0000')
    d=_d(p[2]);return (d-_DAY1).isoformat() if d else None
# K57 이어짐의 다음 역이 상대 계통에서 접속 노드 바로 옆 정차역이 아님(한 칸 건너뜀, 3회차 kanto_2-021 京王 新宿)
rows=[]
for k in LINKS:
    if k['kind']!='continue' or not k['next_stop_node'] or not k['node']:continue
    d_=_rep(k)
    if not d_ or d_<BASE:continue
    m_=k['other_node'] or k['node'];ok=False;seen_route=False
    for q in LROUTES.get(k['other_line_id'],[]):
        L_=[z for z in allstop.get(q,[]) if not 0]
        idx=[i for i,z in enumerate(L_) if G_(z['node_id'])==G_(m_)]
        if not idx:continue
        seen_route=True
        # 상대 계통이 숨은 노드와 확장 행뿐인 연결선이면 다음 역은 그날 서는 확장 역이다(compile과 같은 뜻, 西武秩父 連絡線 → 影森, 9회차 L)
        # 그 방향에 그날 서는 역이 없으면 다음 역은 그 계통 끝 노드다(서지 않는 끝 노드, 정차역 없는 연락선. compile walk와 같은 뜻, 5번 결정)
        if k['next_stop_node'] in (routes[q]['from_node'],routes[q]['to_node']) and any(may((d_,d_,d_,d_),pp) for pp in ROWIV.get((q,k['next_stop_node']),[])):ok=True
        # 그날 확실히 선 역만(끝이 범위인 역은 범위 첫날까지): compile의 다음 역과 같은 뜻 (9회차 L, 東部線 東堤町 [1950..1984] 폐지)
        # 같은 노선 옛 선형 계통(따로 계통, 2번안 2026-11-23)의 칸·역도 함께 따라간다. compile walk가 끊긴 본 계통에서 옛 선형으로 건너간다 (花輪線 好摩 → 東北本線 옛 滝沢)
        ON_=set();NB_=collections.defaultdict(set)
        for q2 in [q]+[x for x in LROUTES.get(k['other_line_id'],[]) if x!=q and x in _OLD_R]:
            ON_|={z['node_id'] for z in allstop.get(q2,[]) if z['is_stop'] and any(pp and pp[0]<=d_<(pp[2] or '9999') for pp in SPR.get((q2,z['node_id']),[]))}
            for f_ in RPAIR.get(q2,{}):
                a_,b_=tuple(f_) if len(f_)==2 else (None,None)
                if a_:NB_[a_].add(b_);NB_[b_].add(a_)
        for i in idx:
            # 계통 칸을 따라 그날 서는 첫 역까지 (목록 순서가 아니라 칸으로: 옛 경로·이전 자리가 km 순으로 끼어 있음)
            for y0 in NB_[L_[i]['node_id']]:
                # 서지 않는 노드에서 갈래가 여럿이면(옛 경로·새 경로 칸이 함께 든 계통, 東北本線 渋民–滝沢·滝沢（旧）) 갈래마다 따라가 그날 서는 첫 역을 모은다 (9회차 L)
                st_=[(L_[i]['node_id'],y0)];seen_={L_[i]['node_id']}
                while st_:
                    prev,cur=st_.pop()
                    if cur in ON_:
                        if cur==k['next_stop_node']:ok=True
                        continue
                    if cur in seen_ or len(seen_)>60:continue
                    seen_.add(cur);st_.extend((cur,w) for w in NB_[cur] if w!=prev)
    if seen_route and not ok:rows.append((k['route_id'],nn(k['node']),ln(k['other_line_id']),nn(m_),nn(k['next_stop_node']),k['valid_from'],k['valid_to']))
# 확인 목록: compile은 연결 기간 토막의 대표 날(시작 쪽) 선로로, 이 검사는 끝 전날로 본다. 기간 안에 역이 생기거나 없어지면 갈린다. 京王 新宿 같은 노드 건너뜀은 회귀 사례(kanto_2-008)로 본다
put('K57 이어짐 다음 역이 상대 계통 접속 노드의 바로 옆 정차역이 아님(확인 목록)',rows,30,lvl='warn')
# K58 이어짐·분기의 두 선로가 그 방면 칸에서 궤간·방식이 다름(칸 단위, 3회차 tohoku_2-005 大曲·新庄·越後湯沢)
rows=[]
if GAUGE:
    for k in LINKS:
        if k['kind'] not in('continue','branch') or not k['next_stop_node'] or not k['node'] or k['route_id'] not in routes:continue
        p=_sure(ivl(k['valid_from'],k['valid_to']))
        if not p or p[0]>=p[1]:continue
        lo_,hi_=max(p[0],BASE),p[1]
        if lo_>=hi_:continue
        A=routes[k['route_id']]['line_id'];x=k['node']
        # 같은 노선 계통끼리의 이음(본 계통 ↔ 옛 선형 계통)은 앱이 한 줄로 이어 그린다(§8.3). 궤간 행이 본선 계통 순서로만 적혀 옛 선형 칸은 노선 전체 행으로 읽힌다
        if k['other_line_id']==A:continue
        nb=[(b_ if a_==x else a_) for f,e in RPAIR.get(k['route_id'],{}).items() if x in f for a_,b_ in [E[e]]]
        ga=set().union(*[gauge_on(A,lo_,hi_,y) for y in nb]) if nb else gauge_on(A,lo_,hi_,x)
        gb=gauge_on(k['other_line_id'],lo_,hi_,k['next_stop_node'])
        if ga and gb and not gfit(ga,gb):rows.append((k['route_id'],nn(x),k['kind'],ln(k['other_line_id']),nn(k['next_stop_node']),k['valid_from'],k['valid_to'],sorted(ga,key=str),sorted(gb,key=str)))
put('K58 이어짐·분기 방면 칸의 두 노선 궤간·방식이 다름',rows,30)
# K61 끝 역이 노선 줄기 끝이 아님: 그날 상대 노선 칸이 끝 역에서 둘 넘게 영업 중(옛 경로·갈래 계통에서 잘림, 3회차 hokkaido_1-015 (1))
_LEDGES=collections.defaultdict(list)
for e,v in attr.items():
    for a_ in v:
        if e in E:_LEDGES[a_['line_id']].append((e,(a_['valid_from_lo'] or '0000-01-01'),(a_['valid_to_hi'] or '9999-12-31') if a_['valid_to']!=ON else '9999-12-31'))
_LSTOP=collections.defaultdict(list)
for (q_,x_),v_ in SPR.items():
    if q_ in routes:_LSTOP[routes[q_]['line_id'],x_]+=v_
def _leads_to_stop(ln_,t,y,d):
    """노선 ln_의 그날 영업 칸을 따라 t에서 y 쪽으로 가면 그날 그 노선이 서는 역에 닿는가"""
    seen={t};st=[y]
    while st:
        x=st.pop()
        if x in seen:continue
        seen.add(x)
        if any(p and p[0]<=d<(p[3] or '9999') for p in _LSTOP.get((ln_,x),[])):return True
        if len(seen)>80:return True
        for e,f_,u_ in _LEDGES[ln_]:
            if x in E[e] and f_<=d<u_:st.append(E[e][0] if E[e][1]==x else E[e][1])
    return False
rows=[]
for k in LINKS:
    t=k['terminal_node']
    if not t or k['kind'] not in('continue','branch','transfer'):continue
    d=_rep(k)
    if not d or d<BASE:continue
    es={e for e,f_,u_ in _LEDGES[k['other_line_id']] if t in E[e] and f_<=d<u_ and any((r['valid_from_lo'] or '0000')<=d<((r['valid_to_hi'] or '9999') if r['valid_to']!=ON else '9999') and r['status']=='open' for r in LR.get(e,[]))}
    nbs={(E[e][0] if E[e][1]==t else E[e][1]) for e in es}
    # 그 방면으로 그날 서는 역이 하나라도 있는 이웃만 센다. 너머가 서지 않는 노드(끝 노드: 駒井野信号場·長岡分岐点)에서 끝나면 끝 역은 줄기 끝이다(5번 결정)
    if len(nbs)>=2:nbs={y for y in nbs if _leads_to_stop(k['other_line_id'],t,y,d)}
    if len(nbs)>=2:rows.append((k['route_id'],nn(k['node']),k['kind'],ln(k['other_line_id']),nn(t),d,sorted(nn(z) for z in nbs)[:3]))
put('K61 연결 끝 역에서 그날 상대 노선이 더 이어짐(끝 역이 줄기 끝이 아님)',rows,30,lvl='warn')
# K62 시작이 범위인 연결 행의 범위 상한이 끝보다 늦음 (3회차 tohoku_1-019 石巻)
# 시작·끝이 둘 다 범위이고 끝 범위가 시작 범위보다 뒤로 밀린 창(그해 운행은 근거로 확인, 날짜만 모름: 秋田内陸 2000 봄)은 compile이 있었다고 받은 행이라 뺀다 (5회차 2026-11-25)
def _k62_window(k):
    f_,t_=str(k['valid_from']),str(k['valid_to'])
    if not (f_.startswith('[') and t_.startswith('[')):return False
    a_,b_=lohi(f_),lohi(t_)
    return bool(a_[0] and b_[0] and a_[1] and b_[1]) and a_[0]<b_[0] and a_[1]<b_[1]
rows=[(k['route_id'],nn(k['node']),k['kind'],ln(k['other_line_id']),k['valid_from'],k['valid_to']) for k in LINKS for p in [ivl(k['valid_from'],k['valid_to'])] if p and k['valid_to']!=ON and (p[1] or '')>(p[2] or '9999') and not str(k['valid_from']).startswith('[..') and not _k62_window(k)]
put('K62 연결 시작 범위의 상한이 끝보다 늦음',rows,30)
# K63 계통 연속성: 이웃 두 정차역이 함께 서는 날에 그 사이 계통 칸이 영업하지 않음(병주 칸도 없음, 3회차 kinki_2-019 西野田線)
rows=[]
for rid,s in rstop.items():
    st=[y for y in s if y['is_stop']]
    for e in redge.get(rid,[]):
        if e not in E:continue
        u,v=E[e]
        if not SPR.get((rid,u)) or not SPR.get((rid,v)):continue
        both=_ivs_union([(max(_sure(p)[0],_sure(q)[0]),min(_sure(p)[1],_sure(q)[1])) for p in SPR[(rid,u)] for q in SPR[(rid,v)]])
        both=[(max(a,BASE),min(b,TODAY)) for a,b in both if max(a,BASE)<min(b,TODAY)]
        if not both:continue
        par_=[e2 for e2 in EINC[u]&EINC[v]]
        op=_ivs_union([iv for e2 in par_ for iv in _open_iv(e2)]) if all(LR.get(e2) for e2 in par_) else None
        if op is None:continue
        un=[(c,d) for c,d in _ivs_minus(both,op) if _d(c) and _d(d) and (_d(d)-_d(c)).days>=2]
        if un:rows.append((rid,nn(u),nn(v),e,un[0]))
put('K63 이웃 두 정차역이 함께 서는 날에 그 사이 칸이 영업하지 않음(병주 칸 없음, 확인 목록)',rows,30,lvl='warn')
# K65 같은 노선 다른 계통으로의 분기인데 그 계통의 그날 남은 칸이 모두 이 계통 칸 (3회차 kanto_3-22 (1) 外房線 蘇我)
rows=[]
for k in LINKS:
    q=k['other_route_id']
    if k['kind']!='branch' or not q or q not in routes or k['route_id'] not in routes or routes[q]['line_id']!=routes[k['route_id']]['line_id']:continue
    d=_rep(k)
    if not d:continue
    L=routes[q]['line_id']
    rem={e for e in redge.get(q,[]) if any(f_<=d<u_ for e2,f_,u_ in _LEDGES[L] if e2==e) and any((r['valid_from_lo'] or '0000')<=d<((r['valid_to_hi'] or '9999') if r['valid_to']!=ON else '9999') and r['status']=='open' for r in LR.get(e,[]))}
    if rem and rem<=set(redge.get(k['route_id'],[])):rows.append((k['route_id'],nn(k['node']),q,k['valid_from'],k['valid_to']))
put('K65 같은 노선 계통으로의 분기인데 그 계통의 남은 칸이 모두 이 계통 칸',rows,30)
# K66 1950-01-01 전에 끝난 연결 행 (3회차 hokkaido_1-015 (3))
put('K66 1950-01-01 전에 끝난 연결 행',[(k['route_id'],nn(k['node']),k['kind'],ln(k['other_line_id']),k['valid_to']) for k in LINKS for p in [ivl(k['valid_from'],k['valid_to'])] if p and k['valid_to']!=ON and (p[3] or '9999')<=BASE],30)
# K53 사람이 적은 분기 방향(junction_side)이 선형 시작 방향과 반대 (compile build/report.json warnings side_geo_hand, 3회차 junction_side 전수)
_REP=json.load(open(os.path.join(B,'report.json'),encoding='utf-8')).get('warnings',{}) if os.path.exists(os.path.join(B,'report.json')) else {}
_JS={(x['line'],x['other'],x['at']) for x in json.load(open(os.path.join(ROOT,'data','overrides','junction_side.json'),encoding='utf-8'))}
put('K53 손 분기 방향(junction_side)이 선형 시작 방향과 반대',[tuple(x) for x in _REP.get('side_geo_hand',[]) if tuple(x[:3]) in _JS],30)
put('K53 근거 표 THROUGH 방향(*_side)이 선형과 다름(스위치백 직통 확인 목록)',[tuple(x) for x in _REP.get('side_geo_hand',[]) if tuple(x[:3]) not in _JS],30,lvl='warn')
# K67 근거 표 직통이 상대 노선의 중간 역에서 이어지는데 방면(*_toward·*_side) 칸이 없음 (3회차 kinki_2-020 川西能勢口)
_K67AMB={(x[0],x[1],x[2]) for x in _REP.get('through_dir_geo_ambiguous',[])}
rows=[]
for x in _TH:
    for a,b,nb_,tw,sd,na_ in ((x['a'],x['b'],x['at'][1],x.get('a_toward'),x.get('b_side'),x['at'][0]),(x['b'],x['a'],x['at'][0],x.get('b_toward'),x.get('a_side'),x['at'][1])):
        if tw or sd:continue
        # 선형으로 방면이 갈리는 곳(한 방면만 곧음·되돌아가는 쪽과 궤간 다른 쪽은 규칙으로 뺌)은 방면 칸이 없어도 된다. 생성기가 선형으로 못 정한 곳
        # (두 방면이 모두 곧거나 모두 되돌아감, 두 노선이 모두 지나가는 X자 교차: compile report through_dir_geo_ambiguous)만 센다 (9회차 L)
        if (a,b,na_) not in _K67AMB:continue
        if any(nb_ not in (rstop[q][0]['node_id'],rstop[q][-1]['node_id']) and nb_ in {z['node_id'] for z in rstop[q]} for q in LROUTES.get(b,[]) if rstop.get(q)):rows.append((ln(a),ln(b),nn(nb_),x.get('from'),x.get('to')))
put('K67 근거 표 직통이 상대 노선 중간 역에서 이어지는데 방면 칸 없음(선형으로 고름, 확인 목록)',rows,40,lvl='warn')
# K64 순환 운전 계통의 양 끝 이어짐 대칭: 한 끝 이어짐의 상대 노선이 그 끝 역에서 다른 노선으로 이어지고 그 노선이 이 계통의 다른 끝에 서면, 다른 끝에도 그 노선으로의 이어짐이 있어야 함 (3회차 kanto_3-02 山手線 品川)
TLX=collections.defaultdict(set)
for at,a,b,kd,f_,t_ in m.execute('select at_node,line_a,line_b,kind,valid_from,valid_to from track_link'):TLX[G_(at),a].add(b);TLX[G_(at),b].add(a)
rows=[]
for rid,s in rstop.items():
    st=[y for y in s if y['is_stop']]
    if len(st)<2 or routes[rid]['closed']:continue
    A=routes[rid]['line_id'];ends_={st[0]['node_id'],st[-1]['node_id']}
    lk=[k for k in LINKS if k['route_id']==rid and k['kind']=='continue' and k['node'] in ends_ and k['valid_to']==ON]
    for k in lk:
        other_end=(ends_-{k['node']}) or None
        if not other_end or not k['terminal_node']:continue
        e2=next(iter(other_end))
        for Y in TLX.get((G_(k['terminal_node']),k['other_line_id']),()):
            if Y==A or not any(G_(z['node_id'])==G_(e2) and z['is_stop'] for q in LROUTES.get(Y,[]) for z in rstop.get(q,[])):continue
            if not any(k2['route_id']==rid and k2['node']==e2 and k2['other_line_id']==Y and k2['kind'] in('continue','branch') for k2 in LINKS):rows.append((rid,nn(k['node']),ln(k['other_line_id']),nn(k['terminal_node']),ln(Y),nn(e2)))
put('K64 순환 계통 한 끝 이어짐과 짝인 다른 끝 이어짐이 없음(확인 목록)',sorted(set(rows)),30,lvl='warn')
# ---- 8회차 W1b 검사 (3회차 전수 점검 monitor_gap). 같은 역 묶음·이름·노선 구성·결정 반영
# K38 같은 역 묶음(group): 같은 계통에서 같은 날 둘 다 서는 두 노드, 환승 아님 표 쌍, 이전 쌍 옛 자리 둘이 함께 영업, 묶음 안에서 함께 영업·이전·인계로 안 이어지는 노드 (kyushu_2-05·tohoku_1-030(1)·kanto_3-03·kyushu_1-016)
_GN=collections.defaultdict(list)
for i_,g_ in GRP.items():
    if g_:_GN[g_].append(i_)
_MV2=collections.defaultdict(set)
for a_,b_ in MOVED:_MV2[a_].add(b_);_MV2[b_].add(a_)
rows=[];rows2=[];rows3=[];rows4=[]
def _nd(e,s):
    try:return abs((datetime.date.fromisoformat(s[:10])-datetime.date.fromisoformat(e[:10])).days)<=1
    except ValueError:return False
for g_,ns_ in _GN.items():
    if len(ns_)<2:continue
    ns_=sorted(ns_)
    for i_,a in enumerate(ns_):
        for b in ns_[i_+1:]:
            f_=frozenset((a,b))
            if f_ in HUBNOT:rows2.append((g_,nn(a),a,nn(b),b))
            if f_ in MOVED:continue
            if any(r1==r2 and must(p,q) for r1,p in SP.get(a,[]) for r2,q in SP.get(b,[])):rows.append((g_,nn(a),a,nn(b),b))
            if a in MVOLD and b in MVOLD and MVOLD[a]!=MVOLD[b] and any(must(p,q) for _,p in SP.get(a,[]) for _,q in SP.get(b,[])):rows3.append((g_,nn(a),a,nn(b),b))
    live=[x for x in ns_ if SP.get(x)]
    par={x:x for x in live}
    def fd(x):
        while par[x]!=x:par[x]=par[par[x]];x=par[x]
        return x
    for i_,a in enumerate(live):
        for b in live[i_+1:]:
            if b in _MV2[a] or any(may(p,q) or _nd(p[3],q[0]) or _nd(q[3],p[0]) for _,p in SP[a] for _,q in SP[b]):par[fd(a)]=fd(b)
    if len({fd(x) for x in live})>1:rows4.append((g_,[(x,nn(x)) for x in live]))
put('K38 같은 group 두 노드가 같은 계통에서 같은 날 함께 정차(다른 역)',rows,30)
put('K38 환승 아님(hub_not) 쌍이 같은 group',rows2,30)
put('K38 다른 이전 쌍의 옛 자리 둘이 함께 영업했는데 같은 group',rows3,30)
put('K38 group 안에 함께 영업·이전·인계로 이어지지 않는 노드(함께 영업한 적 없는 후계 역)',rows4,30)
# K39 이름 글자: 위키 목록 기호·위키 문법이 섞인 이름 (chubu_1-020). 정해진 표식((旧)·(old)·(臨)·（仮） 등 괄호)만 허용
_SYM=re.compile(r'[*＊※:：\[\]{}|=<>]')
rows=[]
for t_,i_,l_,x_ in n.execute("select entity_type,entity_id,lang,text from name union all select entity_type,entity_id,lang,text from name_route"):
    if x_ and _SYM.search(x_):rows.append((t_,i_,l_,x_))
for t_,i_,x_ in n.execute("select entity_type,entity_id,text from alias"):
    if x_ and re.search(r'^[*＊※]|[{}|=<>\[\]]',x_):rows.append((t_,i_,'alias',x_))
put('K39 이름에 위키 목록 기호·문법 글자가 섞임',rows,30)
# K40 옛 이름 기간 행의 글자·읽기가 지금 이름과 같음(이름이 바뀐 것이 아님, kyushu_1-010). 같은 글자 다른 읽기(苅田, U13)는 정상
rows=[]
for (t_,i_,l_),v in NROWS.items():
    if l_!='ja' or t_ not in ('node','line'):continue
    b=base(t_,i_,'ja')
    if not b:continue
    for x,k,src,li,vf,vt in v:
        if (vf or vt) and not li and x==b[0] and (not k or not b[1] or k==b[1]):rows.append((t_,i_,x,vf,vt))
put('K40 옛 이름 기간 행이 지금 이름과 같음(글자·읽기 같음)',rows,30)
# K41 「前」 역의 영어 이름이 시설 항목 라벨(위키데이터): mae 없음 + 시설 낱말 (kyushu_2-11)
rows=[]
for (t_,i_),v in nm.items():
    if t_!='node':continue
    j=base('node',i_,'ja');e=base('node',i_,'en')
    if j and e and j[0].endswith('前') and 'mae' not in e[0].lower() and e[2]=='wikidata':rows.append((i_,j[0],e[0]))
put('K41 「前」 역인데 영어 이름에 mae가 없는 위키데이터 라벨(시설 항목 의심)',rows,30,lvl='warn')
rows=[(i_,j[0],e[0]) for i_,j,e in [(i_,base('node',i_,'ja'),base('node',i_,'en')) for (t_,i_) in nm if t_=='node'] if j and e and e[2]=='wikidata' and j[0].endswith('前') and 'mae' not in e[0].lower() and re.search(r'\b(Shrine|Temple|Hospital|Office|University|Park|Ground|Zoo|Hall|School|Castle)\b',e[0])]
put('K41 「前」 역 영어 이름이 시설 라벨(시설 낱말, mae 없음)',rows,30)
# K42 노선 sd(station_database 노선 이름)가 노선 이름·역과 맞지 않음: sd 노선과 겹치는 역이 하나 이하 (hokkaido_1-012·kinki_2-015)
rows=[]
try:
    import glob as _gl
    _SDL={}
    for f_ in _gl.glob(os.path.join(ROOT,'data','source','lines','*.yaml')):
        for l_ in open(f_,encoding='utf-8'):
            l_=l_.strip()
            if l_.startswith('- {'):
                d_=json.loads(l_[2:]);_SDL[d_['id']]=d_.get('sd')
    _sdst=collections.defaultdict(set)
    _sdp=os.path.join(ROOT,'data','imports','stationdb')
    if os.path.isdir(_sdp):
        import csv as _csv
        for f_ in _gl.glob(os.path.join(_sdp,'*.json')):
            pass
    for l_,sd_ in _SDL.items():
        if not sd_:continue
        jn=(base('line',l_,'ja') or ('',))[0]
        core=re.sub(r'(線|本線|支線)$','',re.sub(r'^.*?(電鉄|鉄道|市電|都電|交通|軌道)','',jn))
        if core and core not in sd_ and not set(core)&set(sd_):rows.append((l_,jn,sd_))
except Exception as ex_:rows.append(('error',str(ex_)))
put('K42 노선 sd가 노선 이름과 한 글자도 안 겹침(다른 노선 이름 의심)',rows,40,lvl='warn')
# K43 열람 전용 역 중복: 같은 계통·같은 이름·같은 km (chubu_3-02, chubu_2-23 ⑤)
_AN={i_:x_ for i_,x_ in n.execute("select entity_id,text from name where entity_type='archive' and lang='ja' and line_id is null and valid_from is null and valid_to is null")}
_c=collections.defaultdict(list)
for i_,rt_,km_ in m.execute('select id,route_id,km from archive_stop'):_c[(rt_,_AN.get(i_),km_)].append(i_)
put('K43 열람 전용 역 중복(같은 계통·이름·km)',[(k[0],k[1],k[2],v) for k,v in _c.items() if len(v)>1 and k[1]],30)
# K44 정차·칸 시작 하한이 0000(「[..날짜]」)인데 1950 뒤에 끝남 (kanto_2-023)
rows=[]
for r_ in m.execute("select route_id,node_id,valid_from,valid_from_lo,valid_to,valid_to_lo from route_stop_period"):
    if (r_[3] or '').startswith('0000') and r_[2] and r_[2].startswith('[..') and (r_[5] or '9999')>BASE:rows.append(('stop',r_[0],nn(r_[1]),r_[1],r_[2],r_[4]))
for r_ in m.execute("select edge_id,line_id,valid_from,valid_from_lo,valid_to,valid_to_lo from edge_attr"):
    if (r_[3] or '').startswith('0000') and r_[2] and r_[2].startswith('[..') and (r_[5] or '9999')>BASE:rows.append(('attr',r_[0],r_[1],r_[2],r_[4]))
put('K44 시작 하한이 열린 범위([..날짜])인데 1950 뒤까지 영업',rows,30,lvl='warn')
# K45 이전 쌍인데 좌표 거리·km 차 모두 0.1 km 이하(같은 자리, 쌍을 만들지 않는 규칙: tohoku_1-016·tohoku_1-031(5))
rows=[]
_KMN=collections.defaultdict(list)
for rid_,v_ in allstop.items():
    for x_ in v_:
        if x_['km_cum'] is not None:_KMN[x_['node_id']].append((rid_,x_['km_cum']))
# 9회차 S: 공식 営業キロ가 바뀐 이전(moved.json km_change 근거)은 옛 자리 노드가 옛 km를 나타내므로 같은 자리여도 쌍을 둔다(설계 판단). 근거 없는 쌍만 남긴다
_MKC={(x_['old'],x_['new']) for x_ in OVR('moved.json') if x_.get('km_change')}
for a_,b_,d_ in m.execute('select old_node,new_node,moved_on from node_move'):
    if a_ in pos and b_ in pos and (a_,b_) not in _MKC:
        dd=hav(pos[a_],pos[b_])
        kd=[abs(p_-q_) for r1,p_ in _KMN[a_] for r2,q_ in _KMN[b_] if r1==r2]
        if dd<=.1 and kd and min(kd)<=.1:rows.append((nn(a_),a_,b_,round(dd*1000),round(min(kd),2),d_))
put('K45 이전 쌍인데 좌표 거리·km 차 모두 0.1km 이하(같은 자리)',rows,30,lvl='warn')
# K46 route_link 시작 범위 상한이 끝보다 늦음 (tohoku_1-031(4))
rows=[]
try:
    for r_ in m.execute('select route_id,seq,kind,other_line_id,valid_from_hi,valid_to_lo,valid_to from route_link'):
        if r_[4] and r_[5] and r_[6] not in (None,'ongoing') and r_[4]>r_[5]:rows.append(tuple(r_))
except sqlite3.OperationalError:pass
put('K46 연결 행 시작 범위 상한이 끝보다 늦음',rows,30)
# K47 km_era_hand의 모든 손 구간이 시대 km(edge_km_era)로 쓰였는가 (tohoku_2-002)
rows=[]
_EKE={(r_[0],r_[1]) for r_ in m.execute('select edge_id,line_id from edge_km_era')}
_EL=collections.defaultdict(set)
for e_,l_ in _EKE:_EL[e_].add(l_)
for x_ in OVR('km_era_hand.json'):
    es_=[r_[0] for r_ in m.execute("select re.edge_id from route_edge re join edge e on e.id=re.edge_id where re.route_id=? and (e.from_node in (?,?) or e.to_node in (?,?))",(x_['route'],x_['a'],x_['b'],x_['a'],x_['b']))]
    if not any(x_['line'] in _EL[e_] for e_ in es_):rows.append((x_['line'],x_['a'],x_['b'],x_['km']))
put('K47 km_era_hand 손 구간이 시대 km(edge_km_era)에 없음',rows,30)
# K48 임시역(臨時駅) 정차가 1년 넘게 연속인데 임시역 표식 기간이 그 정차를 다 덮음(영업 시즌 확인 필요, tohoku_1-003·tohoku_1-030(2))
rows=[]
_RJ=collections.defaultdict(list)
for x_,l_,k_,f_,t_ in n.execute("select node_id,line_id,kind,valid_from,valid_to from stop_mark where kind='rinji'"):_RJ[x_].append((f_,t_))
_GP=collections.defaultdict(list)
for r_ in m.execute('select route_id,node_id,gap_from,gap_to from route_stop_gap'):_GP[r_[1]].append(r_)
for x_,v_ in _RJ.items():
    for f_,t_ in v_:
        p_=ivl(f_,t_)
        if not p_:continue
        try:span=(datetime.date.fromisoformat(min(p_[3],TODAY)[:10])-datetime.date.fromisoformat(p_[1][:10])).days
        except ValueError:continue
        # 1950-01-01 전에 끝난 표식은 기록 범위 밖이라 확인할 것이 없다(弁天島 1907~1916, 北鎌倉 1927~1930). 계절 臨時駅의 영업 철은 날짜로 다루지 않는다
        # (DESIGN §9.4 臨時駅 「영업한 해 전체가 기록 가능」): 남는 행은 해마다 영업했는지(영업하지 않은 해가 있는지)의 확인 목록이다 (9회차 N)
        if p_[3]<=BASE:continue
        if span>366 and not _GP.get(x_):rows.append((nn(x_),x_,f_,t_))
put('K48 臨時駅 표식이 1년 넘게 이어지고 정차 공백 없음(영업 시즌 확인 목록)',rows,40,lvl='warn')
# K49 같은 노선 이웃 칸이 같은 날 사업자가 다름(이관 범위가 뒤에 닫힌 끝 칸을 빠뜨린 꼴, kinki_1-15·kinki_1-19)
rows=[]
_LE=collections.defaultdict(list)
for e_,v_ in attr.items():
    for a_ in v_:_LE[a_['line_id']].append((e_,a_))
_EN={r_[0]:(r_[1],r_[2]) for r_ in m.execute('select id,from_node,to_node from edge')}
for l_,v_ in _LE.items():
    if len({a_['operator_id'] for _,a_ in v_})<2:continue
    byn=collections.defaultdict(list)
    for e_,a_ in v_:
        for x_ in _EN.get(e_,()):byn[x_].append(a_)
    for x_,as_ in byn.items():
        for i_,a1 in enumerate(as_):
            for a2 in as_[i_+1:]:
                if a1['edge_id']!=a2['edge_id'] and a1['operator_id']!=a2['operator_id'] and must(ivl(a1['valid_from'],a1['valid_to']),ivl(a2['valid_from'],a2['valid_to'])):
                    rows.append((ln(l_),l_,nn(x_),a1['operator_id'],a2['operator_id']));break
put('K49 같은 노선 이웃 칸이 같은 날 사업자가 다름',sorted(set(rows)),30,lvl='warn')
# K50 사업자가 바뀐 노선(1950 뒤)에 시대 이름 행이 없고 지금 이름에 사업자 머리가 있음(결정 U10·U11 반영 확인, kanto_2-016·kanto_2-022②·kinki_1-18)
rows=[]
_LPL={r_[0] for r_ in m.execute("select line_id from line_period where kind='name'")}
_HTP={r_[0]:r_[1] for r_ in OVR('hand_tables.json')['tables']['LINE_PREFIX']['값']}
for l_,ops_ in LOP.items():
    if len(ops_)<2 or l_ in _LPL or l_ in HIDL:continue
    js=sorted({a_['operator_id'] for e_,a_ in _LE[l_] if (a_['valid_to_hi'] or '9999')>BASE})
    if len(js)<2:continue
    jn=(base('line',l_,'ja') or ('',))[0]
    cur=max(_LE[l_],key=lambda z:z[1]['valid_to_hi'] or '9999')[1]['operator_id']
    if cur in ('o_japanese_national_railways',) or cur.startswith('o_jr_'):continue
    # 모든 사업자가 같은 상표 머리(hand_tables LINE_PREFIX: 京阪神急行電鉄·阪急電鉄 → 阪急, 東京急行電鉄·東急電鉄 → 東急)면 시대 이름이 지금 이름과 같아 규칙상 정상이다 (9회차 N)
    if len({_HTP.get(o_) for o_ in js})==1 and _HTP.get(js[0]):continue
    rows.append((ln(l_),l_,js))
put('K50 1950 뒤 사업자가 바뀐 노선인데 시대 이름 행 없음(같은 이름이면 정상, 확인 목록)',rows,40,lvl='warn')
# K51 공용 선로 결정(U03) 반영 확인: 병주(route_parallel)로 묶인 두 계통이 같은 역 묶음 쌍을 서로 다른 칸으로 잇는 곳(사업자별로 나뉜 공용 선로가 두 벌, kanto_2-007·kanto_2-022①)
rows=[]
_RE=collections.defaultdict(dict)
for rid_,eid_,a_,b_ in m.execute('select re.route_id,re.edge_id,e.from_node,e.to_node from route_edge re join edge e on e.id=re.edge_id'):_RE[rid_][frozenset((G_(a_),G_(b_)))]=eid_
try:
    for r_ in m.execute('select route_id,other_route_id,from_seq,to_seq from route_parallel'):
        if not r_[1]:continue
        ns_=[SEQN.get((r_[0],q_)) for q_ in range(r_[2],r_[3]+1)]
        for x_,y_ in zip(ns_,ns_[1:]):
            k_=frozenset((G_(x_),G_(y_)))
            e1,e2=_RE[r_[0]].get(k_),_RE[r_[1]].get(k_)
            if e1 and e2 and e1!=e2:rows.append((r_[0],r_[1],nn(x_),nn(y_),e1,e2))
except sqlite3.OperationalError:pass
put('K51 사업자별로 나뉜 공용 선로가 다른 칸 두 벌(U03 대상, 병주로 남은 곳 확인 목록)',sorted(set(rows)),40,lvl='warn')
# K52 노선 이름 속 역 이름의 읽기가 그 역 노드 읽기와 다름 (chubu_3-13: 鯖浦線 越前平井 えちぜんへいい)
rows=[]
_LK={i_:(x_,k_) for i_,x_,k_ in n.execute("select entity_id,text,kana from name where entity_type in ('line','route') and lang='ja' and kana is not null and line_id is null and valid_from is null and valid_to is null")}
_NK=collections.defaultdict(set)
for i_,x_,k_ in n.execute("select entity_id,text,kana from name where entity_type='node' and lang='ja' and kana is not null"):_NK[x_].add(k_)
for i_,(x_,k_) in _LK.items():
    for nmx,ks in _NK.items():
        if len(nmx)>=3 and nmx in x_ and len(ks)==1:
            kk=next(iter(ks))
            # 노선 이름 읽기 안에 그 역 이름 글자가 있는 자리의 읽기가 역 읽기와 맞는지: 역 읽기가 노선 읽기에 없고, 같은 글자 다른 읽기 후보가 있으면
            if kk not in k_.replace(' ','').replace('～','') and nmx+'駅' not in x_:rows.append((i_,x_,k_,nmx,kk))
put('K52 노선·계통 이름 속 역 이름 읽기가 그 역 읽기와 다름(확인 목록)',rows[:400],40,lvl='warn')
# K08 확장: 같은 사업자·같은 옛 이름(기간 이름 포함)·100 m 안 두 노드가 다른 group (지금 이름이 달라 K08을 빠져나간 西長田–西長田ゆりの里, chubu_2-23③)
_ALLJA=collections.defaultdict(set)
for (t_,i_,l_),v_ in NROWS.items():
    if t_=='node' and l_=='ja':
        for r_ in v_:_ALLJA[i_].add(strip_old(r_[0]))
rows=[]
for i in pub:
    for j in near_nodes(i,.1):
        if j>=i or GRP.get(i)==GRP.get(j) or not NOP[i]&NOP[j] or frozenset((i,j)) in HUBNOT or not cowork(i,j):continue
        if _ALLJA[i]&_ALLJA[j] and bj(i)!=bj(j):rows.append((nn(i),i,nn(j),j,sorted(_ALLJA[i]&_ALLJA[j])[:2]))
put('K08 같은 사업자·같은 옛 이름·100m 안 노드 둘이 다른 group(지금 이름은 다름)',rows,30,lvl='warn')
# ==== 9회차 L (연결·계통 생성기, K70–K79) ====
# K70 근거 표 직통(THROUGH)의 at 노드가 그 기간 그 노선 계통의 정차역이 아님(鳥羽 志摩線 1929–1970은 n_toba_kintetsu_old, 9회차 L-9).
# 기간은 범위 날짜를 lo/hi로 겹침 판정한다(住吉 [1913..1985]·石巻 [1990..2016] 같은 범위 시작)
# 노드 나누기(node_split.json move_lines)로 그 노선 정차가 새 노드로 옮겨 간 곳은 새 노드로 본다(後免町 安芸線 → n_gomenmachi_aki_line. compile도 같은 대응으로 잇는다)
_NSPL={(l_,x_['node']):x_['new_id'] for x_ in json.load(open(os.path.join(ROOT,'data','overrides','node_split.json'),encoding='utf-8')) if isinstance(x_,dict) and x_.get('new_id') for l_ in x_.get('move_lines',[])}
rows=[]
for x in _TH:
    p_=ivl(x.get('from'),x.get('to') if x.get('to') not in (None,'ongoing') else None)
    for ln_,nd_,rr_ in ((x['a'],x['at'][0],x.get('a_route')),(x['b'],x['at'][1],x.get('b_route'))):
        nd_=_NSPL.get((ln_,nd_),nd_)
        qs_=[rr_] if rr_ else LROUTES.get(ln_,[])
        # 계통 끝 노드 행은 정차가 없어도 그 행 기간 내내 고를 수 있는 끝이라 직통의 끝이 될 수 있다(연락선 끝 御花畑·大和八木, 5번 결정)
        if not any(may(p_,pp) for q in qs_ for pp in SPR.get((q,nd_),[])+ENDIV.get((q,nd_),[])):rows.append((ln(ln_),nd_,nn(nd_),x.get('from'),x.get('to')))
put('K70 근거 표 직통(THROUGH)의 at 노드가 그 기간 그 노선 계통의 정차역이 아님',rows,30)
# K71 다른 노드끼리 잇는 근거 표 직통(THROUGH)의 근거가 여객 직통이 아님: 근거 글(why)에 여객 직통·운행 서술이 없음(노선도의 선로 접속뿐이거나 화물만 직통).
# 다른 노드끼리의 이어짐은 여객 직통 근거가 있을 때만이고, 화물만 직통했거나 선로 접속만 있으면 환승이다(사용자 확인 2026-11-16, 鳥羽·美唄). 같은 노드의 선로 갈라짐은 U02 그대로 (9회차 L-9)
_PSG=re.compile(r'直通|乗り入れ|乗入|列車|運転|運行|旅客|特急|急行|快速|相互|직통|여객|\(R[1-6][ ,)]')
rows=[]
for x in _TH:
    a_,b_=_NSPL.get((x['a'],x['at'][0]),x['at'][0]),_NSPL.get((x['b'],x['at'][1]),x['at'][1])
    if a_==b_:continue
    if not _PSG.search(x.get('why') or ''):rows.append((ln(x['a']),ln(x['b']),nn(a_),nn(b_),x.get('from'),x.get('to')))
put('K71 다른 노드끼리 잇는 근거 표 직통(THROUGH)의 근거에 여객 직통 서술이 없음(선로 접속·화물만이면 환승)',rows,30)
# ---- 연결·환승·승계 화면 이상 전수 탐지 (9회차 X, K120–K129). 계기: 参宮線·近鉄志摩線 鳥羽(화물 직통을 여객 이어짐으로, 양쪽 비대칭).
# 화면 단위 검사(같은 역 줄에 같은 상대가 두 번, 이관 앞 노선 사슬)는 렌더 JSON을 읽는 tools/dev/screen_check.py가 본다. 여기는 원 DB 행만 본다
_XS=collections.defaultdict(list)   # (노선, 노드) -> 정차·확장 행의 가능한 기간
for rid_,v_ in allstop.items():
    for z_ in v_:
        # 승하차 불가 끝 노드 행도 다음·끝 역이 될 수 있다(정차역이 없는 연락선의 반대쪽 끝, 5번 결정)
        if z_['is_stop'] or z_['is_end_point']:
            _XS[routes[rid_]['line_id'],z_['node_id']].append(((z_['valid_from_lo'] or '0000-01-01'),'9999-12-31' if z_['valid_to']==ON else (z_['valid_to_hi'] or '9999-12-31')))
# 서지 않고 고를 수 있는 기간(route_stop_select)의 노드도 다음·끝 역이 될 수 있다
if m.execute("select 1 from sqlite_master where name='route_stop_select'").fetchone():
    for r_ in m.execute("select route_id,node_id,valid_from_lo,valid_to,valid_to_hi from route_stop_select where style not in ('none','moved')"):
        if r_[0] in routes:_XS[routes[r_[0]]['line_id'],r_[1]].append(((r_[2] or '0000-01-01'),'9999-12-31' if r_[3] in (ON,'ongoing') else (r_[4] or '9999-12-31')))
def _xs_on(line,x,p):return any(a<p[3] and p[0]<b for a,b in _XS.get((line,x),[]))
_XGM=collections.defaultdict(set)
for x_,g_ in GRP.items():_XGM[g_ or x_].add(x_)
_XTR=('continue','branch')
_XLK=[k for k in LINKS if k['route_id'] in routes and k['node'] and ivl(k['valid_from'],k['valid_to'])]
for k in _XLK:k['_p']=ivl(k['valid_from'],k['valid_to']);k['_line']=routes[k['route_id']]['line_id']
def _xsure(p):return (max(p[1],BASE),min(p[2],TODAY))
def _xdays(a,b):
    d1,d2=_d(a),_d(b)
    return (d2-d1).days if d1 and d2 else 9999
# K120 다음 역·끝 역이 그 기간 상대 노선의 정차(확장 행 포함)가 아님 (X 갈래 (h)). 그날 상대 계통에 없는 역으로 방면을 적으면 화면 글이 틀린다
rows=[]
for k in _XLK:
    for f_ in ('next_stop_node','terminal_node'):
        if k[f_] and not _xs_on(k['other_line_id'],k[f_],k['_p']):rows.append((k['route_id'],nn(k['node']),k['kind'],ln(k['other_line_id']),f_,nn(k[f_]),k[f_],k['valid_from'],k['valid_to']))
put('K120 연결의 다음 역·끝 역이 그 기간 상대 노선 정차역이 아님',rows,30)
# K121 같은 역 줄에서 같은 상대 노선이 선로 연결(이어짐·분기)과 환승으로 같은 때 함께 있음. 둘 다 지나가는 X자 교차(환승 through + 분기·이어짐, 이 계통도 그 역을 지남)는 DESIGN §2.9 예외라 뺀다
_XEND={}
for rid_,v_ in allstop.items():
    q_=[z_['seq'] for z_ in v_ if z_['is_stop'] or 0]
    _XEND[rid_]={min(q_),max(q_)} if q_ else set()
_XROW=collections.defaultdict(list)
for k in _XLK:_XROW[k['route_id'],k['seq'],k['other_line_id']].append(k)
rows=[]
for (rid_,sq_,ol_),ks_ in _XROW.items():
    for t_ in [k for k in ks_ if k['kind']=='transfer']:
        # 숨은 분기점의 at_edge 분기는 이 역과 다음 역 사이에 그린다(역 줄의 선로 연결이 아니다, 9회차 L: 布引線 三宮阪神前)
        for c_ in [k for k in ks_ if k['kind'] in _XTR and not k['at_edge']]:
            a,b=_xsure(t_['_p']);c,d=_xsure(c_['_p'])
            if not(a<d and c<b) or _xdays(max(a,c),min(b,d))<2:continue
            # 시기별 끝 역 직통(continue 한 행)도 이 계통이 그 역을 지나가게 된 뒤는 같은 X자 교차다(萩山 拝島線→多摩湖線 1962~, 11회차 F1)
            if t_['flow']=='through' and c_['kind'] in _XTR and sq_ not in _XEND[rid_]:continue
            rows.append((rid_,nn(c_['node']),ln(ol_),c_['kind'],c_['valid_from'],c_['valid_to'],'transfer',t_['flow'],t_['valid_from'],t_['valid_to']))
put('K121 같은 역 줄에 같은 상대 노선의 선로 연결과 환승이 같은 때 함께(X자 교차 아님, 확인 목록)',rows,30)
# K122 비대칭: 이쪽은 그 역에서 상대 노선으로 이어짐·분기인데 상대 노선 쪽은 같은 때 이 노선을 환승으로만 봄 (鳥羽 参宮線→志摩線 1929–1969).
# 상대 쪽 행은 같은 group 노드(이쪽 노드 또는 상대 노드)에서 찾는다. 2일 미만 어긋남은 날짜 경계로 본다
_XIX=collections.defaultdict(list)
for k in _XLK:_XIX[k['_line'],k['other_line_id']].append(k)
rows=[];rows2=[]
for k in _XLK:
    if k['kind'] not in _XTR or k['at_edge'] or k['_line']==k['other_line_id']:continue
    s_=_xsure(k['_p'])
    if s_[0]>=s_[1]:continue
    a_=k['node'];o_=k['other_node'] or a_
    back=[b for b in _XIX.get((k['other_line_id'],k['_line']),[]) if G_(b['node']) in (G_(o_),G_(a_)) or G_(b['other_node'] or b['node'])==G_(a_)]
    tr=_ivs_union([(b['_p'][0],b['_p'][3]) for b in back if b['kind'] in _XTR])
    tf=_ivs_union([(b['_p'][0],b['_p'][3]) for b in back if b['kind']=='transfer'])
    bad=[(c,d) for c,d in _ivs_minus([s_],tr) if any(c<y and x<d for x,y in tf) and _xdays(c,d)>=2]
    if bad:rows.append((k['route_id'],nn(a_),k['kind'],ln(k['other_line_id']),k['valid_from'],k['valid_to'],'상대 쪽 환승만',bad[0]))
    # K123 한쪽에만 연결: 상대 노선 쪽에 이 노선으로의 연결이 같은 때 하나도 없음 (표시용 버스 노선은 계통이 없어 뺀다)
    miss=[(c,d) for c,d in _ivs_minus([s_],_ivs_union(tr+tf)) if _xdays(c,d)>=2]
    if miss and k['other_line_id'] not in BUSL and LROUTES.get(k['other_line_id']):rows2.append((k['route_id'],nn(a_),k['kind'],ln(k['other_line_id']),k['valid_from'],k['valid_to'],miss[0]))
for k in _XLK:
    if k['kind']!='transfer' or k['at_edge'] or k['_line']==k['other_line_id'] or k['other_line_id'] in BUSL or not LROUTES.get(k['other_line_id']):continue
    s_=_xsure(k['_p'])
    if s_[0]>=s_[1]:continue
    a_=k['node'];o_=k['other_node'] or a_
    back=[b for b in _XIX.get((k['other_line_id'],k['_line']),[]) if G_(b['node']) in (G_(o_),G_(a_)) or G_(b['other_node'] or b['node'])==G_(a_)]
    miss=[(c,d) for c,d in _ivs_minus([s_],_ivs_union([(b['_p'][0],b['_p'][3]) for b in back])) if _xdays(c,d)>=2]
    if miss:rows2.append((k['route_id'],nn(a_),k['kind'],ln(k['other_line_id']),k['valid_from'],k['valid_to'],miss[0]))
put('K122 연결 비대칭: 이쪽은 이어짐·분기인데 상대 노선 쪽은 같은 때 환승만(확인 목록)',rows,30)
put('K123 한쪽에만 있는 연결: 상대 노선 쪽에 같은 때 이 노선으로의 연결이 없음(확인 목록)',rows2,30,lvl='warn')
# K124 다른 노드끼리 이어짐·분기인데 other_node를 비우고 근거 표(THROUGH·노면전차 계통표)도 없음. 상대는 그때 이 노드가 아니라 같은 group의 다른 노드에 섬.
# 다른 노드끼리의 이어짐은 여객 직통 근거가 있을 때만 인정한다(사용자 확인 2026-11-16 鳥羽, 화물만 직통이면 환승). K55는 other_node가 있는 행만 본다
rows=[]
for k in _XLK:
    if k['kind'] not in _XTR or k['other_node'] or k['at_edge']:continue
    ol_=k['other_line_id'];x_=k['node']
    if _xs_on(ol_,x_,k['_p']):continue
    mates=sorted(y_ for y_ in _XGM[G_(x_)] if y_!=x_ and _xs_on(ol_,y_,k['_p']))
    if not mates or (k['_line'],ol_) in THP or (k['_line'],ol_) in TSP:continue
    rows.append((k['route_id'],nn(x_),k['kind'],ln(ol_),nn(mates[0]),mates[0],k['valid_from'],k['valid_to']))
put('K124 다른 노드끼리 이어짐·분기인데 근거 표 없음(other_node 비움, 여객 직통 근거 확인 목록)',rows,40)
# K121·K122·K124·K125는 9회차 L 생성기 고침(연결 근거 대칭·다른 노드 이어짐 여객 근거·궤간 방면 대체 등)으로 0이 되어 오류(err)로 올림. 제목은 회귀 사례가 쓰므로 그대로 둠
# K125 같은 역 줄·같은 상대 노선의 분기 방향(side)이 기간마다 다르고 한쪽은 비어 있음(비면 아래로 그려 위·아래 두 줄이 됨). 선로가 바뀐 근거가 없으면 같은 방향이어야 한다
rows=[]
for (rid_,sq_,ol_),ks_ in _XROW.items():
    bs=[k for k in ks_ if k['kind']=='branch']
    sides={k['side'] or '' for k in bs}
    if len(sides)>1 and '' in sides:rows.append((rid_,nn(bs[0]['node']),ln(ol_),sorted((k['side'] or '-',k['valid_from'],k['valid_to']) for k in bs)))
put('K125 같은 역·같은 상대 노선 분기 방향이 기간마다 다르고 한쪽은 빔(확인 목록)',rows,30)
# ---- 9회차 N 갈래(이름 생성기) 검사 K90~K93
# K90 노선 한정 이름의 노선에 그 노드 정차가 없음 (3회차 chubu_3-17: インテック本社前의 JR 富山港線 「富山口」). compile이 빼므로 0이어야 한다
rows=[]
_NLS={(x_,l_) for x_,l_ in m.execute('select distinct rs.node_id,r.line_id from route_stop rs join route r on r.id=rs.route_id where rs.is_stop=1')}
for t_,i_,l_,x_,li_ in n.execute("select entity_type,entity_id,lang,text,line_id from name where entity_type='node' and line_id is not null and lang='ja'"):
    if (i_,li_) not in _NLS:rows.append((i_,li_,x_))
put('K90 노선 한정 이름의 노선에 그 노드 정차가 없음',sorted(set(rows)),30)
# K91 끝난 노선의 날짜 모름 화면 이름이 그 역 마지막 정차 날 이름과 다름 (3회차 chubu_1-018·chubu_2-20·tohoku_1-018: 한 계통 안에 노선 한정 옛 이름과 지금 이름이 섞임).
# 날짜 모름 화면은 기간 없는 노선 한정 이름 > 지금 이름(§14.2). 마지막 정차 날은 노선 끝·그 역 정차 끝 가운데 이른 날의 전날
rows=[]
_LEND={}
for l_,vs_ in m.execute("select line_id,group_concat(valid_to,'|') from edge_attr group by line_id"):
    vs_=vs_.split('|')
    if all(v_ not in (None,'','ongoing') for v_ in vs_):_LEND[l_]=max(lohi(v_)[0] or '0000' for v_ in vs_)
_LSP={}
for rid_,x_,f_,t_ in m.execute('select route_id,node_id,valid_from,valid_to from route_stop where is_stop=1'):
    l_=routes[rid_]['line_id']
    if l_ not in _LEND or t_ in (None,'ongoing'):continue
    e_=lohi(t_)[0] or '9999';_LSP[(x_,l_)]=max(_LSP.get((x_,l_),'0000'),e_)
for (x_,l_),e_ in sorted(_LSP.items()):
    if x_ not in pub:continue
    d_=min(e_,_LEND[l_])
    try:day=(datetime.date.fromisoformat(d_)-datetime.timedelta(days=1)).isoformat()
    except ValueError:continue
    v_=NROWS.get(('node',x_,'ja'),[])
    # 기간 없는 노선 한정 이름이 있으면 그 노선 표기(노리츠부시 표·마지막 날 이름 규칙)라 따로 보지 않는다
    if any(z[3]==l_ and not z[4] and not z[5] for z in v_):continue
    shown=(base('node',x_,'ja') or ('',))[0]
    last=[z[0] for z in v_ if not z[3] and z[5] and ivl(z[4],z[5]) and (ivl(z[4],z[5])[1]<=day<ivl(z[4],z[5])[2])]
    want=last[0] if len(last)==1 else (base('node',x_,'ja') or ('',))[0]
    # 마지막 날 이름이 같은 노선 계통의 다른 공개 노드의 지금 이름과 같으면 지금 이름으로 둔다(같은 이름 두 줄 금지, compile 마지막 날 이름 규칙의 예외, 11회차 S1 chubu_1-007)
    if strip_old(shown)!=strip_old(want) and any(y_ in pub and y_!=x_ and (base('node',y_,'ja') or ('',))[0]==want for r_ in LROUTES.get(l_,()) for y_ in RNODES.get(r_,())):continue
    if len(last)<=1 and strip_old(shown)!=strip_old(want):rows.append((ln(l_),l_,x_,shown,want,day))
put('K91 끝난 노선의 날짜 모름 화면 이름이 그 역 마지막 정차 날 이름과 다름',rows,30)
# K92 역 이름에 안내용 副駅名称(〈 〉)이 들어감 (3회차 kanto_1-015: 明治神宮前〈原宿〉). 정식 역명만 이름이고 〈 〉 꼴은 검색 별칭이다
rows=[(i_,l_,x_) for t_,i_,l_,x_ in n.execute("select entity_type,entity_id,lang,text from name where entity_type='node'") if re.search('[〈〉]',x_ or '')]
put('K92 역 이름에 안내용 副駅名称(〈〉)',rows,30)
_MVPAIR={tuple(sorted((x['old'],x['new']))) for x in json.load(open(os.path.join(ROOT,'data','overrides','moved.json'),encoding='utf-8'))}
# K93 같은 노선의 다른 계통에 지금 이름이 같은 역 둘((旧) 없음, 3회차 tohoku_2-013: 東北本線 山線 옛 松島–海線 松島). 같은 계통은 K25
rows=[]
for l_,rids_ in LROUTES.items():
    gb=collections.defaultdict(set)
    for rid_ in rids_:
        for y in rstop.get(rid_,[]):
            # 노선 한정 이름(기간 없음)이 있으면 그 이름으로 본다(5회차 京王線 新宿·新線新宿)
            if y['is_stop']:gb[next((z[0] for z in NROWS.get(('node',y['node_id'],'ja'),[]) if z[3]==l_ and not z[4] and not z[5]),None) or bj(y['node_id'])].add(y['node_id'])
    for t_,xs in gb.items():
        # 역 이전(moved.json) 옛·새 노드 쌍은 옛 역에 이전 안내가 붙어 구별된다(会津線 舟子 1980 大川ダム 선로 바꿈)
        if len(xs)==2 and tuple(sorted(xs)) in _MVPAIR:continue
        if len(xs)>1 and t_ and not any(len(xs)>1 and set(xs)<=RNODES.get(r_,set()) for r_ in rids_):rows.append((ln(l_),t_,sorted(xs)[:3]))
put('K93 같은 노선 다른 계통에 지금 이름이 같은 노드 둘(（旧） 없음)',rows,30)
# K110 여객 영업 이력이 없는 화물선(rule_class hidden)은 DB에만 둔다(사용자 결정 2026-11-09). 앱에 드러나는 길이 없어야 한다 (9회차 F):
# 정차·분모 단위·계통 이음·위치 미확인 표식이 없고, 칸 등급이 모두 hidden이며, 그 칸을 다른 노선이 같이 쓰지 않는다(앱 판에서 칸째 빼기 때문)
_hl=tuple(sorted(r_[0] for r_ in m.execute("select id from line where rule_class='hidden'")))
rows=[]
if _hl:
    q_=','.join('?'*len(_hl))
    rows+=[('정차 있음',)+tuple(r_) for r_ in m.execute(f"select s.route_id,s.node_id from route_stop s join route r on r.id=s.route_id where r.line_id in ({q_}) and s.is_stop=1",_hl)]
    rows+=[('분모 단위 있음',r_[0]) for r_ in m.execute(f"select distinct u.edge_id from denominator_unit u where u.edge_id in (select edge_id from edge_attr where line_id in ({q_}))",_hl)]
    rows+=[('계통 이음 있음',)+tuple(r_) for r_ in m.execute(f"select l.route_id,l.other_line_id from route_link l join route r on r.id=l.route_id where r.line_id in ({q_}) or l.other_line_id in ({q_})",_hl+_hl)]
    rows+=[('위치 미확인 표식 있음',)+tuple(r_) for r_ in m.execute(f"select id,line_id from map_marker where line_id in ({q_})",_hl)]
    rows+=[('칸 등급이 hidden 아님',)+tuple(r_) for r_ in m.execute(f"select edge_id,line_id,denominator_class from edge_attr where line_id in ({q_}) and denominator_class<>'hidden'",_hl)]
    rows+=[('다른 노선과 같이 쓰는 칸',)+tuple(r_) for r_ in m.execute(f"select a.edge_id,b.line_id from edge_attr a join edge_attr b on a.edge_id=b.edge_id where a.line_id in ({q_}) and b.line_id not in ({q_})",_hl+_hl)]
put('K110 숨은 화물선이 앱에 드러남(정차·분모 단위·이음·표식·공용 칸)',sorted(set(rows)),20)
# ---- 결과. 건수가 있는 항목만 찍고 마지막 줄에 단계별 합계를 낸다 (tools/all.sh가 그 줄만 보인다)
for v in R.values():v.setdefault('lvl','info')
print(json.dumps({k:[v['n'],v['lvl']] for k,v in R.items() if v['n']},ensure_ascii=False,indent=0))
# ---- 9회차 S (K80–K89): 열람 전용·이전 쌍·redirect
# K80 기록 기준일 전에 여객 영업이 끝난 정차가 공개 정차(is_stop)로 남음 (DESIGN §4.5·§4.6, compile 열람 전용 규칙, 3회차 chubu_3-16)
_NK80=dict(m.execute('select id,kind from node').fetchall())
rows=[tuple(r_) for r_ in m.execute("select route_id,node_id,valid_to from route_stop where is_stop=1 and valid_to!='ongoing' and valid_to_hi<='1950-01-01'") if _NK80.get(r_[1])=='station']
put('K80 기준일 전에 끝난 정차가 공개 정차로 남음(열람 전용이어야 함)',rows,30)
# K81 같은 계통·같은 이름·같은 km 열람 전용 역이 둘 (8회차 W1b 합침 규칙의 사후 검사)
_AN={i:x for i,x in n.execute("select entity_id,text from name where entity_type='archive' and lang='ja' and line_id is null and valid_from is null and valid_to is null")}
_c81=collections.Counter((rt,_AN.get(i),km) for i,rt,km in m.execute('select id,route_id,km from archive_stop where route_id is not null and km is not null'))
put('K81 같은 계통 열람 전용 역 중복(같은 이름·같은 km)',[k for k,v in _c81.items() if v>1 and k[1]],30)
# K82 열람 전용 역의 앞뒤(after·before)가 공개 노드도 열람 전용 ID도 아님(앱이 자리를 못 잡음)
_PUB82={r_[0] for r_ in m.execute('select id from node_public')};_AID={r_[0] for r_ in m.execute('select id from archive_stop')}
rows=[(i,k_,x) for i,a_,b_ in m.execute('select id,after_id,before_id from archive_stop') for k_,x in (('after',a_),('before',b_)) if x and x not in _PUB82 and x not in _AID]
put('K82 열람 전용 역 앞뒤가 공개 노드·열람 전용 ID가 아님',rows,30,lvl='warn')
# K83 id_redirect 새 ID가 이 판에 없음
_ALLID={r_[0] for t_ in ('node','line','route','archive_stop') for r_ in m.execute(f'select id from {t_}')}
rows=[(t_,o_,x) for t_,o_,v_ in m.execute('select entity_type,old_id,new_ids from id_redirect') for x in json.loads(v_ or '[]') if x not in _ALLID]
put('K83 id_redirect 새 ID가 이 판에 없음',rows,30)
# K84 공식 km 바뀜 근거(moved km_change)가 있는 이전 쌍인데 두 노드의 같은 계통 km 차가 없음
rows=[]
for x_ in OVR('moved.json'):
    if not x_.get('km_change'):continue
    kd_=[abs(p_-q_) for r1,p_ in _KMN[x_['old']] for r2,q_ in _KMN[x_['new']] if r1==r2]
    # 옛 자리가 옛 선형 계통(따로 계통, 2번안 2026-11-23)에 있으면 두 계통이 함께 가진 역에서 잰 거리로 비교한다 (菊池線 再春 옛 자리: 熊本高専前에서 0.4/0.3)
    if not kd_:
        _kr=collections.defaultdict(dict)
        for r_,v_ in allstop.items():
            for y_ in v_:
                if y_['km_cum'] is not None:_kr[r_][y_['node_id']]=y_['km_cum']
        for r1,p_ in _KMN[x_['old']]:
            for r2,q_ in _KMN[x_['new']]:
                com=[n_ for n_ in _kr[r1] if n_ in _kr[r2] and n_ not in (x_['old'],x_['new'])]
                if com:
                    c_=min(com,key=lambda n_:abs(_kr[r1][n_]-p_))
                    kd_.append(abs(abs(p_-_kr[r1][c_])-abs(q_-_kr[r2][c_])))
    if not kd_ or max(kd_)<.05:rows.append((x_['old'],x_['new'],kd_[:3]))
put('K84 km 바뀜 근거가 있는 이전 쌍인데 두 노드 km 차 없음',rows,30)
# ---- 직통 근거 기간 (10회차 D1, K140–K149) ----
# K140 다른 노드끼리 잇는 근거 표 직통(THROUGH)이 시작·끝 모두 비어 두 노선이 함께 선 전 기간을 직통으로 둠. 여객 직통은 기간 근거가 있을 때만이라
# 사람이 볼 확인 목록이다(연결선처럼 노선 자체가 직통 기간뿐인 곳은 정상)
rows=[(J('line',x['a']),J('line',x['b']),J('node',x['at'][0]),J('node',x['at'][1])) for x in _TH
      if _NSPL.get((x['a'],x['at'][0]),x['at'][0])!=_NSPL.get((x['b'],x['at'][1]),x['at'][1]) and not x.get('from') and not x.get('to')]
put('K140 다른 노드끼리 잇는 근거 표 직통(THROUGH)의 시작·끝이 모두 비어 함께 선 전 기간을 직통으로 둠(여객 직통 기간 확인 목록)',rows,40,lvl='warn')
# K141 근거 표 직통(THROUGH)의 기간을 읽을 수 없거나 시작(가장 이른 날)이 끝(가장 늦은 날)보다 늦음
rows=[]
for x in _TH:
    p_=ivl(x.get('from'),x.get('to') if x.get('to') not in (None,'ongoing') else None)
    if p_ is None or p_[0]>=p_[3]:rows.append((J('line',x['a']),J('line',x['b']),x['at'][0],x.get('from'),x.get('to')))
put('K141 근거 표 직통(THROUGH)의 기간을 읽을 수 없거나 시작이 끝보다 늦음',rows,30)
# ---- 10회차 G1 (K170–K177): 전수 점검 4회차 감시 공백
# K170 읽기가 있는 지금 이름인데 한국어·영어가 일본어 표기 그대로(ja_as_is), 또는 영어 공식 표기(en_fix)가 DB에 안 들어감 (4회차 chugoku_shikoku_2-005·2-009: 9회차 뒤 15노드 퇴행이 오류 0으로 통과)
_k170b={}
for t_,i_,lg_,x_,k_,s_,li_,vf_,vt_ in n.execute("select entity_type,entity_id,lang,text,kana,source,line_id,valid_from,valid_to from name where entity_type='node'"):
    if li_ or vf_ or vt_:continue
    _k170b[(i_,lg_)]=(x_,k_,s_)
rows=[]
for (i_,lg_),(x_,k_,s_) in _k170b.items():
    if lg_!='ja' or not k_:continue
    for l2_ in ('ko','en'):
        v_=_k170b.get((i_,l2_))
        if v_ and v_[2]=='ja_as_is':rows.append((i_,x_,k_,l2_,v_[0]))
_enfx=OVR('en_fix.json').get('node',{})
for i_,f_ in _enfx.items():
    v_=_k170b.get((i_,'en'))
    if v_ and f_.get('en') and v_[0]!=f_['en'] and (not f_.get('ja') or (_k170b.get((i_,'ja')) or ('',))[0]==f_['ja']):rows.append((i_,'en_fix',f_['en'],v_[0],v_[2]))
put('K170 읽기가 있는데 한국어·영어가 일본어 표기 그대로(ja_as_is), 또는 영어 공식 표기(en_fix)가 안 들어감',rows,30)
# K171 병주 토막(route_parallel)의 다음 역·끝 역이 그 토막 기간에 상대 노선에 서지 않음, 또는 1950 전에 끝난 병주 토막 (4회차 chugoku_shikoku_1-012·1-013 井原線 酒津, chubu_2-009 輪島, kinki_3-007·3-008 西野田線 1932)
_k171s=collections.defaultdict(list)
for rid_,v_ in allstop.items():
    for z_ in v_:
        if z_['is_stop'] or 0:_k171s[(routes[rid_]['line_id'],z_['node_id'])].append(ivl(z_['valid_from'],z_['valid_to']))
rows=[]
for r_ in m.execute('select * from route_parallel'):
    r_=dict(r_);lo_=max(r_['valid_from_lo'] or '0000-01-01',BASE);hi_=min(r_['valid_to_hi'] or '9999-12-31',TODAY)
    if (r_['valid_to_hi'] or '9999-12-31')<=BASE:rows.append((r_['route_id'],ln(r_['other_line_id']),'1950 전에 끝남',r_['valid_from_lo'],r_['valid_to_hi']));continue
    if lo_>=hi_:continue
    for k_ in ('in_next_stop','in_terminal','out_next_stop','out_terminal'):
        x_=r_[k_]
        if not x_:continue
        if not any(p_ and p_[0]<hi_ and lo_<p_[3] for p_ in _k171s.get((r_['other_line_id'],x_),[])):rows.append((r_['route_id'],ln(r_['other_line_id']),k_,x_,nn(x_),lo_,hi_))
put('K171 병주 토막의 다음 역·끝 역이 그 기간 상대 노선에 서지 않음(또는 1950 전에 끝난 병주 토막)',rows,30)
# K172 기준판에서 사유 없이 사라진 환승 키(계통, 역, 상대 노선)·환승 쌍 (4회차 chubu_3-018·kinki_1-11: 9회차에 名古屋駅前↔名鉄·播但線 亀山↔山陽 亀山 등이 결정 기록 밖에서 빠짐).
# 기준판 키와 사라져도 되는 사유는 tools/dev/regression/transfer_baseline.json에 둔다. 판을 올릴 때 사유를 채우고 기준판을 새로 쓴다(--write는 tools/dev/regression/transfer_baseline.py)
_tbp=os.path.join(ROOT,'tools','dev','regression','transfer_baseline.json')
rows=[]
if os.path.exists(_tbp):
    _tb=json.load(open(_tbp,encoding='utf-8'));_why=_tb.get('사유',{})
    _now={f'{r_[0]}|{r_[1]}|{r_[2]}' for r_ in m.execute("select l.route_id,s.node_id,l.other_line_id from route_link l join route_stop s on s.route_id=l.route_id and s.seq=l.seq")}
    _hpn={'|'.join(sorted(r_)) for r_ in m.execute('select node_a,node_b from hub_pair')}
    _rt=set(routes);_nd=set(GRP)
    for k_ in _tb.get('transfer',[]):
        r1,x1,l1=k_.split('|')
        if k_ not in _now and k_ not in _why and r1 in _rt and x1 in _nd:rows.append(('환승 키',r1,nn(x1),ln(l1)))
    for k_ in _tb.get('hub_pair',[]):
        a1,b1=k_.split('|')
        if k_ not in _hpn and k_ not in _why and a1 in _nd and b1 in _nd:rows.append(('환승 쌍',nn(a1),nn(b1),a1,b1))
put('K172 기준판에서 사유 없이 사라진 환승 키·환승 쌍(transfer_baseline.json)',rows,40,lvl='warn')
# K173 계통 끝 확장 행의 기간이 그 계통 자기 행 기간 밖 (4회차 kanto_1-009 西白井·kanto_2-011 京成成田 등 12행: 끝난 계통 화면에 확장 역만 「영업 중」)
rows=[]
for rid_,v_ in allstop.items():
    own_=[ivl(z_['valid_from'],z_['valid_to']) for z_ in v_ if not 0]
    own_=[p_ for p_ in own_ if p_]
    if not own_:continue
    lo_=min(p_[0] for p_ in own_);hi_=max(p_[3] for p_ in own_)
    for z_ in v_:
        if not 0:continue
        p_=ivl(z_['valid_from'],z_['valid_to'])
        if p_ and (p_[3]>hi_ or p_[0]<lo_):rows.append((rid_,z_['node_id'],nn(z_['node_id']),z_['valid_from'],z_['valid_to'],lo_,hi_))
put('K173 확장 행 기간이 그 계통 자기 행 기간 밖',rows,30)
# K174 분기 짝 행의 사분면이 서로 어긋남 (4회차 kanto_1-007 所沢·kanto_1-011 赤羽橋·芝園橋, kanto_1-017). DESIGN §2.9 side = 이 노선에서 그쪽으로 달리는 열차가 곧장 들어가는 쪽.
# A 계통에서 side 쪽으로 달려 B의 다음 역 쪽으로 들어가면, B 계통에서는 그 다음 역 쪽에서 오는 방향(다음 역이 위면 down)이 곧장 들어가는 쪽이고 B의 다음 역은 A에서 side 반대쪽 이웃이다
def _k174pos(rid,x,y):
    sq_={}
    for z_ in allstop.get(rid,[]):
        if z_['is_stop'] or 0:sq_.setdefault(G_(z_['node_id']),z_['seq'])
    a_,b_=sq_.get(G_(x)),sq_.get(G_(y))
    if a_ is None or b_ is None or a_==b_:return None
    return 'up' if b_<a_ else 'down'
_k174=collections.defaultdict(list)
for k in LINKS:
    if k['kind']!='branch' or not k.get('node') or not k['next_stop_node'] or k['at_edge'] or k['route_id'] not in routes:continue
    _k174[(G_(k['node']),routes[k['route_id']]['line_id'],k['other_line_id'])].append(k)
rows=[]
for (g_,la_,lb_),ks_ in _k174.items():
    # 같은 노선 다른 계통끼리(갈래 계통)는 짝이 아니라 본다
    if la_==lb_:continue
    for ka_ in ks_:
        pa_=ivl(ka_['valid_from'],ka_['valid_to'])
        for kb_ in _k174.get((g_,lb_,la_),[]):
            pb_=ivl(kb_['valid_from'],kb_['valid_to'])
            if not (pa_ and pb_ and must(pa_,pb_)):continue
            # 둘 다 서로를 다음 역으로 가리키는 짝(같은 운행)만 본다: A의 다음 역이 B 계통에, B의 다음 역이 A 계통에 있어야 한다
            pos_na=_k174pos(kb_['route_id'],kb_['node'],ka_['next_stop_node']);pos_nb=_k174pos(ka_['route_id'],ka_['node'],kb_['next_stop_node'])
            if not pos_na or not pos_nb:continue
            sa_=ka_['side'] or 'down';sb_=kb_['side'] or 'down'
            want_sb='down' if pos_na=='up' else 'up';want_nb='down' if sa_=='up' else 'up'
            if sb_!=want_sb or pos_nb!=want_nb:rows.append((ka_['route_id'],nn(ka_['node']),ln(lb_),sa_,nn(ka_['next_stop_node']),kb_['route_id'],sb_,nn(kb_['next_stop_node']),max(pa_[0],pb_[0])))
put('K174 분기 짝 행의 사분면이 서로 어긋남(A의 곧장 들어가는 쪽·B의 다음 역과 B의 곧장 들어가는 쪽·A의 다음 역)',sorted(set(rows)),40,lvl='warn')
# K175 다른 노드끼리 잇는 근거 표 직통(THROUGH)의 기간·근거 글 확인 목록 (4회차 chubu_1-011 高蔵寺 「(R4, 중간)」뿐, kanto_2-016·kanto_3-008 筑波線 土浦·岩瀬 전 기간, tohoku_1-011·tohoku_2-005 福島 阿武隈急行 「かつて…廃止」)
# (가) 근거 글에 여객 서술 없이 조사 꼬리표(R1–R6)뿐 (나) 기간이 비었는데(전 기간) 근거 글에 해가 있음 (다) 끝이 비었는데(지금까지) 근거 글에 끝난 직통 서술(かつて·廃止·取り止め·終了·まで)
_k175p=re.compile(r'直通|乗り入れ|乗入|列車|運転|運行|旅客|特急|急行|快速|相互|직통|여객')
rows=[]
for x in _TH:
    a_,b_=_NSPL.get((x['a'],x['at'][0]),x['at'][0]),_NSPL.get((x['b'],x['at'][1]),x['at'][1])
    if a_==b_:continue
    w_=x.get('why') or ''
    if not _k175p.search(w_):rows.append(('조사 꼬리표뿐',ln(x['a']),ln(x['b']),nn(a_),x.get('from'),x.get('to'),w_[:60]))
    if not x.get('from') and not x.get('to') and re.search(r'(18|19|20)\d\d',w_):rows.append(('전 기간인데 근거 글에 해',ln(x['a']),ln(x['b']),nn(a_),w_[:80]))
    if not x.get('to') and re.search(r'かつて|廃止|取り止め|取りやめ|終了|운행 끝|폐지',w_):rows.append(('지금까지인데 끝난 직통 서술',ln(x['a']),ln(x['b']),nn(a_),x.get('from'),w_[:80]))
put('K175 다른 노드 THROUGH 기간·근거 글 확인 목록(꼬리표뿐·전 기간인데 해·지금까지인데 끝난 서술)',rows,60,lvl='warn')
# K176 열람 전용 역 자리 확인 목록 (4회차 kyushu_1-010): (가) 같은 이름·같은 근거의 열람 전용 역이 두 노선 이상 (나) 계통 끝 너머에 붙음(앞 역이 끝 정차·뒤 역 없음, 또는 뒤 역이 첫 정차·앞 역 없음)
# (다) 앞 역–뒤 역 사이에 이 계통 정차가 셋 넘게 낌
_k176src=collections.defaultdict(set)
_AN176={i:x for i,x in n.execute("select entity_id,text from name where entity_type='archive' and lang='ja' and line_id is null and valid_from is null and valid_to is null")}
_acols={r_[1] for r_ in m.execute('pragma table_info(archive_stop)')}
for r_ in m.execute('select * from archive_stop'):
    r_=dict(r_);_k176src[(_AN176.get(r_['id']),r_.get('source') if 'source' in _acols else None)].add(r_['line_id'])
rows=[('여러 노선',k_[0],sorted(ln(l_) for l_ in v_)) for k_,v_ in _k176src.items() if k_[0] and len(v_)>1]
for i_,rt_,a_,b_ in m.execute('select id,route_id,after_id,before_id from archive_stop where route_id is not null'):
    st_=[z_['node_id'] for z_ in allstop.get(rt_,[]) if z_['is_stop'] and not 0]
    if not st_:continue
    if a_ and not b_ and a_==st_[-1]:rows.append(('끝 너머',rt_,_AN176.get(i_),nn(a_)))
    if b_ and not a_ and b_==st_[0]:rows.append(('첫 역 앞',rt_,_AN176.get(i_),nn(b_)))
    if a_ in st_ and b_ in st_ and abs(st_.index(b_)-st_.index(a_))>4:rows.append(('사이 정차 셋 넘음',rt_,_AN176.get(i_),nn(a_),nn(b_)))
put('K176 열람 전용 역 자리 확인 목록(여러 노선·끝 너머·첫 역 앞·사이 정차 셋 넘음)',rows,60,lvl='warn')
# K177 선로 연결 근거(junction)의 시작이 범위인데 그 연결의 계통 이음 시작이 범위 첫날로 확정됨 (4회차 kinki_2-013·kinki_2-006). 시작 범위면 이음 시작도 범위이거나 범위 끝 뒤여야 한다
rows=[]
for j_ in JN:
    f_=j_['valid_from']
    # 생성기가 칸 기간에서 끌어낸 행(derived)은 근거가 아니다. 근거 행(위키·손 표)만 본다
    if not f_ or not f_.startswith('[') or f_.startswith('[..') or (j_['source'] or '')=='derived':continue
    lo_,hi_=lohi(f_)
    if lo_==hi_:continue
    for k in LINKS:
        if k['kind'] not in ('branch','continue') or k['other_line_id']!=j_['other_line_id'] or k['route_id'] not in routes or routes[k['route_id']]['line_id']!=j_['line_id'] or not k.get('node') or G_(k['node'])!=G_(j_['node_id']):continue
        if k['valid_from']==lo_:rows.append((k['route_id'],nn(k['node']),ln(j_['other_line_id']),f_,k['valid_from']))
put('K177 선로 연결 근거 시작이 범위인데 계통 이음 시작이 범위 첫날로 확정',rows,30)
# K190·K191 나뉜 역 (사용자 결정 2026-11-16, 11회차 S1). 한 역이 나중에 둘로 나뉘면 나뉘기 전 기간은 한 노드다(data/overrides/split_period.json)
_SP190=json.load(open(os.path.join(ROOT,'data','overrides','split_period.json'),encoding='utf-8'))
def _lo190(v):return '0000-00-00' if not v else (lohi(v)[0] or '0000-00-00')
def _hi190(v):return '9999-12-31' if v in (None,'ongoing') else (lohi(v)[1] or '9999-12-31')
_pos190={}
for r_ in m.execute('select node_id,lat,lon from node_position'):_pos190.setdefault(r_[0],(r_[1],r_[2]))
def _d190(a,b):
    if a not in _pos190 or b not in _pos190 or None in _pos190[a]+_pos190[b]:return 9e9
    return math.hypot((_pos190[a][0]-_pos190[b][0])*111000,(_pos190[a][1]-_pos190[b][1])*91000)
_grp190=dict(m.execute('select id,group_id from node'))
_lp190=collections.defaultdict(list)
for l_,o_,f_,t_ in m.execute('select line_id,operator_id,valid_from,valid_to from line_period where operator_id is not null'):_lp190[l_].append((o_,f_,t_))
_nl190=collections.defaultdict(list)
# 함께 선 기간은 정차 기간(route_stop_period)이다. 계통 끝 노드로 늘린 행 기간(서지 않는 끝 노드)은 정차가 아니다(5번 결정)
for l_,nd_,f_,t_ in m.execute('select r.line_id,s.node_id,s.valid_from,s.valid_to from route_stop_period s join route r on r.id=s.route_id'):_nl190[nd_].append((l_,f_,t_))
def _ops190(nd_,day):
    s_=set()
    for l_,f_,t_ in _nl190[nd_]:
        if not _lo190(f_)<=day<_hi190(t_):continue
        h_=[o_ for o_,a_,b_ in _lp190[l_] if _lo190(a_)<=day<_hi190(b_)]
        s_|=set(h_) if h_ else {'?'+l_}
    return s_
_done190={frozenset((x_['a'],x_['b'])) for x_ in _SP190}
_ja190=collections.defaultdict(list)
for i_,t_,vf_,vt_ in n.execute("select entity_id,text,valid_from,valid_to from name where entity_type='node' and lang='ja'"):_ja190[t_].append((i_,vf_,vt_))
rows=[]
for t_,L_ in _ja190.items():
    for i_,vf_,vt_ in L_:
        if vt_ in (None,'ongoing'):continue
        for j_,vf2_,vt2_ in L_:
            if j_==i_ or _grp190.get(j_)==_grp190.get(i_) or frozenset((i_,j_)) in _done190:continue
            if not (_lo190(vf_)<_hi190(vt2_) and _lo190(vf2_)<_hi190(vt_)):continue
            if _d190(i_,j_)>=300:continue
            day_=(datetime.date.fromisoformat(_hi190(vt_))-datetime.timedelta(days=1)).isoformat()
            if _ops190(i_,day_)&_ops190(j_,day_):rows.append((t_,i_,j_,vt_,round(_d190(i_,j_))))
_k190={}
for r_ in rows:_k190.setdefault((r_[0],)+tuple(sorted(r_[1:3])),r_)
rows=sorted(_k190.values())
put('K190 같은 사업자·같은 이름·300 m 안 다른 노드가 이름이 같던 기간에 함께 섬(한 역이 나뉜 꼴 후보, split_period 확인 목록)',rows,40,lvl='warn')
# K191 나뉜 역 행대로 DB가 됐는가: 그 기간 b가 서지 않고, a가 b의 노선에 서며, a–b 환승 쌍·환승 이음이 그 기간에 없다
_gap191=collections.defaultdict(list)
for r_,q_,nd_,a_,b_ in m.execute('select route_id,seq,node_id,gap_from,gap_to from route_stop_gap'):_gap191[(r_,q_)].append((a_,b_))
rows=[]
for x_ in _SP190:
    if x_.get('normal'):continue
    a_,b_,f_,t_=x_['a'],x_['b'],x_.get('from'),x_['to'];flo_,tlo_=_lo190(f_),_lo190(t_)
    lines_b=set()
    for r_,q_,ln_,vf_,vt_ in m.execute('select s.route_id,s.seq,r.line_id,s.valid_from,s.valid_to from route_stop s join route r on r.id=s.route_id where s.node_id=? and s.is_stop=1',(b_,)):
        lo_,hi_=max(_lo190(vf_),flo_),min(_hi190(vt_),tlo_)
        if lo_>=hi_:continue
        if any(_lo190(g0_)<=lo_ and ('9999-12-31' if g1_ in (None,'ongoing') else _lo190(g1_))>=hi_ for g0_,g1_ in _gap191[(r_,q_)]):continue
        rows.append(('그 기간 b 정차',r_,b_,lo_,hi_))
    for ln_,vf_,vt_ in _nl190[b_]:lines_b.add(ln_)
    for ln_ in sorted(lines_b):
        st_=[(vf_,vt_) for l2_,vf_,vt_ in _nl190[a_] if l2_==ln_ and _lo190(vf_)<tlo_ and flo_<_hi190(vt_)]
        bs_=[(vf_,vt_) for l2_,vf_,vt_ in _nl190[b_] if l2_==ln_]
        # b가 그 노선에서 그 기간과 겹치게 서던 적이 있으면 a가 그 노선에 서야 한다(b가 나뉜 뒤에만 그 노선에 섰으면 뺀다)
        if not st_ and any(_lo190(vf_)<tlo_ for vf_,vt_ in bs_):rows.append(('그 기간 a가 b의 노선에 안 섬',ln_,a_,b_))
    for hf_,ht_ in m.execute('select valid_from,valid_to from hub_pair where (node_a=? and node_b=?) or (node_a=? and node_b=?)',(a_,b_,b_,a_)):
        if _lo190(hf_)<tlo_ and flo_<_hi190(ht_):rows.append(('그 기간 a–b 환승 쌍',a_,b_,hf_,ht_))
    for r_,q_,on_,vf_,vt_ in m.execute("select l.route_id,l.seq,l.other_node,l.valid_from,l.valid_to from route_link l where l.kind='transfer' and l.other_node in (?,?)",(a_,b_)):
        nd_=m.execute('select node_id from route_stop where route_id=? and seq=?',(r_,q_)).fetchone()
        if nd_ and {nd_[0],on_}=={a_,b_} and _lo190(vf_)<tlo_ and flo_<_hi190(vt_):rows.append(('그 기간 a–b 환승 이음',r_,nd_[0],on_,vf_,vt_))
put('K191 나뉜 역(split_period) 기간에 b 정차·a–b 환승 쌍·환승 이음이 남거나 a가 b의 노선에 서지 않음',rows,30)
# ---- 11회차 S1b (K192–K194): 임시역 표식 꼬리·한 화면 같은 이름·마지막 날 이름 근거·현 경계·계통 단위 대칭
# K192 임시역 표식 행 이름(stop_status name) 꼬리와 표식 종류가 확실히 어긋남: 仮乗降場인데 臨(rinji), 臨時駅인데 仮(kari).
# 仮停車場·臨時乗降場·乗降場·仮駅은 앞 회차들이 근거마다 仮·臨을 정했으므로(白兎·清水寺·安芸浜崎 仮, 酒津 臨) 종류는 보지 않는다(11회차 S1 설계 판단).
# 생성 이름이 꼬리를 따르지 않음(安芸浜崎仮停車場이 「安芸浜崎仮乗降場」으로 찍힘, 4회차 chugoku_shikoku_1-008·009)도 함께 본다
_SS192=OVR('stop_status.json')
_TL192=re.compile(r'(.+?)(仮乗降場|臨時乗降場|乗降場|仮停車場|仮駅|臨時駅)')
rows=[];rows2=[]
for x_ in _SS192:
    m_=_TL192.fullmatch(x_.get('name') or '')
    t_=m_.group(2) if m_ else None
    if (t_=='臨時駅' and x_['kind']=='kari') or (t_=='仮乗降場' and x_['kind']=='rinji'):rows.append((x_['node'],x_['kind'],x_.get('name'),x_.get('from'),x_.get('to')))
    if t_ not in ('仮停車場','臨時乗降場','乗降場','仮駅'):continue
    p_=ivl(x_.get('from'),x_.get('to'))
    for x,k,src,li,vf,vt in NROWS.get(('node',x_['node'],'ja'),[]):
        if not li or not (vf or vt) or src not in ('rule','ja_as_is'):continue
        q_=ivl(vf,vt)
        if not (p_ and q_ and q_[1]>=p_[0] and q_[2]<=p_[3]):continue
        if (x or '').endswith('仮乗降場') or (k and k.endswith('かりじょうこうじょう') and t_!='仮乗降場'):rows2.append((x_['node'],ln(li),x,k,x_.get('name'),vf,vt))
put('K192 임시역 표식 행 이름 꼬리와 표식 종류가 어긋남(仮乗降場인데 臨, 臨時駅인데 仮)',rows,30)
put('K192 임시역 표식 기간 이름이 표식 행 이름 꼬리(仮停車場·臨時乗降場·乗降場·仮駅)를 따르지 않음',rows2,30)
# K193 한 계통 날짜 모름 화면에 같은 이름 두 노드(4회차 chubu_1-007: 越美南線 JR 木尾(지금 母野)의 마지막 날 이름과 이관 뒤 새 역 木尾).
# 날짜 모름 화면 이름은 기간 없는 노선 한정 이름 > 지금 이름이다. 서는 역과, 이 노선은 서지 않지만 공개 노드인 숨은 노드(이관 뒤 새 역)를 함께 본다. K93은 다른 계통끼리다
rows=[]
for rid_,v_ in allstop.items():
    l_=routes[rid_]['line_id']
    if l_ in HIDL:continue
    gb=collections.defaultdict(set)
    for y in v_:
        if 0:continue
        if not (y['is_stop'] or y['node_id'] in pub):continue
        x_=y['node_id']
        t_=next((z[0] for z in NROWS.get(('node',x_,'ja'),[]) if z[3]==l_ and not z[4] and not z[5]),None) or bj(x_)
        gb[t_].add(x_)
    for t_,xs in gb.items():
        if len(xs)>1 and t_ and not t_.endswith('（旧）'):rows.append((ln(l_),rid_,t_,sorted(xs)[:3]))
put('K193 한 계통 날짜 모름 화면에 같은 이름 노드 둘(서는 역·이관 뒤 새 역)',rows,30)
# K194a 끝난 노선 마지막 날 이름(노선 한정, 기간 없음)의 근거가 시작 없는 N05 개칭 행(4회차 chubu_2-010 (a): のと穴水). N05 연도 개칭 행은 시작 없이 들어가
# 같은 노드의 다른 사업자 노선·끝난 노선 이름까지 덮을 수 있다. 그 이름을 그 노선 마지막 날에 실제로 썼는지 볼 확인 목록
rows=[]
for (t,i,l),v in NROWS.items():
    if t!='node' or l!='ja':continue
    for x,k,src,li,vf,vt in v:
        if not li or vf or vt or src not in ('rule:line_last_name','ja_as_is'):continue
        if any(z[0]==x and z[2]=='n05' and not z[4] and z[5] and not z[3] for z in v):rows.append((i,ln(li),x,src))
put('K194a 끝난 노선 마지막 날 이름의 근거가 시작 없는 N05 개칭 행(그 노선에서 쓴 이름인지 확인 목록)',sorted(set(rows)),40,lvl='warn')
# K194c 마지막 날 이름이 정차 끝 범위의 앞(lo)으로 골라졌는데 그 범위 안에서 이름이 바뀐 행이 있음(4회차 kanto_3-008 (3): 玉川遊園).
# 끝이 범위면 마지막 날을 하루로 정할 수 없다. 범위 안 개칭은 범위 앞 이름과 뒤 이름 가운데 어느 쪽이 마지막 이름인지 모른다
rows=[]
_SEND194=collections.defaultdict(list)
for rid_,v_ in rstop.items():
    for y in v_:
        if y['is_stop'] and y['valid_to'] not in (None,ON):_SEND194[(y['node_id'],routes[rid_]['line_id'])].append(y['valid_to'])
for (t,i,l),v in NROWS.items():
    if t!='node' or l!='ja':continue
    for x,k,src,li,vf,vt in v:
        if not li or vf or vt or src not in ('rule:line_last_name','ja_as_is'):continue
        ends=_SEND194.get((i,li))
        if not ends:continue
        e_=max(ends,key=lambda z:(lohi(z)[1] or ''))
        try:a_,b_=lohi(e_)
        except ValueError:continue
        if a_==b_:continue
        ch=[(z[0],z[4],z[5]) for z in v if not z[3] and (z[4] or z[5]) and any(d_ and a_<(lohi(d_)[0] or '')<=b_ for d_ in (z[4],z[5]))]
        if ch:rows.append((i,ln(li),x,e_,ch[:2]))
put('K194c 끝난 노선 마지막 날 이름을 정차 끝 범위 앞으로 골랐는데 범위 안에 개칭이 있음(확인 목록)',rows,40,lvl='warn')
# K194h 폐역 뒤로 끝 없이 늘인 기간 이름(시작 있음·끝 없음)인데 마지막 정차 끝이 범위다. 이름 끝이 그 범위 끝보다 이르면 늘이면 안 된다
# (4회차 kanto_3-006 재발: 身延山別院前·柵町가 정차 끝 범위 앞날과 비교해 늘어남). 남는 행은 이름이 범위 끝까지 이어졌다는 근거가 있어야 한다
rows=[]
_SALL=collections.defaultdict(list)
for rid_,v_ in rstop.items():
    for y in v_:
        if y['is_stop']:_SALL[y['node_id']].append(y['valid_to'])
for (t,i,l),v in NROWS.items():
    if t!='node' or l!='ja':continue
    ends=_SALL.get(i)
    if not ends or any(z in (None,ON) for z in ends):continue
    e_=max(ends,key=lambda z:(lohi(z)[1] or ''))
    try:a_,b_=lohi(e_)
    except ValueError:continue
    if a_==b_:continue
    for x,k,src,li,vf,vt in v:
        if vf and not vt:rows.append((i,x,vf,e_))
put('K194h 폐역 뒤로 끝 없이 늘인 기간 이름인데 마지막 정차 끝이 범위(확인 목록)',rows,40,lvl='warn')
# K194e 노드의 도도부현(node.pref)과 좌표가 든 현이 다름(4회차 tohoku_1-011 (4): 吉岡海底). 경계는 compile과 같은 data/base/pref.geojson(N03을 줄인 것)이라
# 경계 가까운 역은 줄인 선 때문에 틀리게 나올 수 있다. 바다 위(어느 현에도 안 듦)는 보지 않는다. 확인 목록
_PF194={}
for f_ in json.load(open(os.path.join(ROOT,'data','base','pref.geojson'),encoding='utf-8'))['features']:
    g_=f_['geometry'];ps_=[]
    for poly in (g_['coordinates'] if g_['type']=='MultiPolygon' else [g_['coordinates']]):
        xs=[q[0] for r in poly for q in r];ys=[q[1] for r in poly for q in r]
        ps_.append(((min(xs),min(ys),max(xs),max(ys)),poly))
    _PF194[str(f_['properties']['pref'])]=ps_
def _in194(x,y,pref):
    hit=False
    for (x0,y0,x1,y1),poly in _PF194.get(pref,()):
        if not(x0<=x<=x1 and y0<=y<=y1):continue
        for ring in poly:
            inr=False
            for (ax,ay),(bx,by) in zip(ring,ring[1:]+ring[:1]):
                if (ay>y)!=(by>y) and x<(bx-ax)*(y-ay)/(by-ay)+ax:inr=not inr
            if inr:hit=not hit
    return hit
rows=[]
for x_,pf_ in m.execute('select id,pref from node'):
    if x_ not in pub or x_ not in pos or not pf_:continue
    la_,lo_,_=pos[x_];pf_=str(int(pf_)) if str(pf_).isdigit() else str(pf_)
    if _in194(lo_,la_,pf_):continue
    got=[p_ for p_ in _PF194 if p_!=pf_ and _in194(lo_,la_,p_)]
    if got:rows.append((x_,nn(x_),pf_,got[0],la_,lo_))
put('K194e 노드 도도부현과 좌표가 든 현이 다름(줄인 경계 기준 확인 목록)',rows,40,lvl='warn')
# K194f 계통 단위 연결 비대칭(4회차 kanto_2-016 ①: 大宮 川越線). A 계통 a1이 역 x에서 B 계통 b1로 이어짐·분기인데, b1은 같은 역에서 A로 잇는 선로 연결이
# 있으면서 그 상대 계통이 a1이 아님(같은 때). 노선 쌍 단위인 K122·K123이 못 보는 꼴. 확인 목록
rows=[]
_TL194=collections.defaultdict(list)
for k in LINKS:
    if k['kind'] in ('continue','branch') and k.get('node'):_TL194[(k['route_id'],k['node'])].append(k)
for (rid_,x_),ks in _TL194.items():
    la_=routes[rid_]['line_id']
    for k in ks:
        b1=k.get('other_route_id')
        if not b1 or b1 not in routes:continue
        p_=ivl(k['valid_from'],k['valid_to'])
        back=[z for z in _TL194.get((b1,k.get('other_node') or x_),[])+_TL194.get((b1,x_),[]) if z['other_line_id']==la_ and must(p_,ivl(z['valid_from'],z['valid_to']))]
        back=[z for z in back if z.get('other_route_id')]
        if back and not any(z.get('other_route_id')==rid_ for z in back):rows.append((ln(la_),rid_,nn(x_),b1,sorted({z.get('other_route_id') or '' for z in back})))
put('K194f 계통 단위 연결 비대칭: 상대 계통은 같은 역에서 이 노선의 다른 계통으로 이음(확인 목록)',sorted(set(map(lambda r:(r[0],r[1],r[2],r[3],tuple(r[4])),rows))),40,lvl='warn')
# K195 통과 경계(stop_dates 값 "pass": 법정 끝·경계인데 그 계통 여객 열차가 서지 않음, 梅田貨物線 福島)는 그 계통에서 정차가 아니고,
# 계통 끝 쪽이면 승하차 불가 끝 노드 행이어야 그 칸을 탈 수 있다 (4회차 kinki_1-07, 11회차 S2, 5번 결정 2026-11-19)
rows=[]
for k_,v_ in json.load(open(os.path.join(ROOT,'data','overrides','stop_dates.json'),encoding='utf-8')).items():
    if k_.startswith('_') or v_!='pass' or '|' not in k_:continue
    rt_,nd_=k_.split('|')
    L_=sorted(allstop.get(rt_,[]),key=lambda z_:z_['seq'])
    own_=L_
    hit_=[z_ for z_ in own_ if z_['node_id']==nd_]
    if not hit_:rows.append((rt_,nd_,'계통에 없음'));continue
    if any(z_['is_stop'] for z_ in hit_):rows.append((rt_,nd_,'정차로 남음'));continue
    i_=own_.index(hit_[0])
    if i_ in (0,len(own_)-1) and not hit_[0]['is_end_point']:rows.append((rt_,nd_,'계통 끝인데 끝 노드 행 아님'))
put('K195 통과 경계(stop_dates pass)가 정차로 남거나 계통 끝인데 끝 노드 행 아님',rows,20)
# ==== 11회차 S3 스위치백 직통 표식 (판 2026-11-16.4) ====
# K198 스위치백 표식 기간(route_link_reverse)에 맞는 끝 역 이어짐(같은 계통·역 순번·상대 노선·다음 역의 continue 행, 기간이 겹침)이 없음. 앱은 끝 이어짐 줄에만 표식을 그린다
_RVC198=bool(m.execute("select 1 from sqlite_master where type='table' and name='route_link_reverse'").fetchone())
rows=[]
if _RVC198:
    _cl198=collections.defaultdict(list)
    for r_ in m.execute("select route_id,seq,other_line_id,next_stop_node,valid_from,valid_to from route_link where kind='continue'"):_cl198[tuple(r_[:4])].append((r_[4],r_[5]))
    for r_ in m.execute('select route_id,seq,other_line_id,next_stop_node,valid_from,valid_to from route_link_reverse'):
        a_,b_=lohi(r_[4]) if r_[4] else ('0000-01-01',)*2,lohi(r_[5]) if r_[5] not in (None,'ongoing') else ('9999-12-31',)*2
        if not any((lohi(f_)[0] if f_ else '0000-01-01')<b_[1] and a_[0]<(lohi(t_)[1] if t_ not in (None,'ongoing') else '9999-12-31') for f_,t_ in _cl198.get(tuple(r_[:4]),())):rows.append(tuple(r_))
put('K198 스위치백 표식 기간(route_link_reverse)에 맞는 끝 역 이어짐(continue) 행이 없음',rows,20)
# K199 근거 표 THROUGH의 reverse·passenger_only 칸 값이 틀림(reverse는 true·"a"·"b"·false(곧게 이어짐, 자동 표식 막음, 5회차), passenger_only는 true), 또는 reverse 행의 표식 기간이 하나도 없음
rows=[]
_RVROWS=[x_ for x_ in _TH if 'reverse' in x_ or 'passenger_only' in x_]
for x_ in _RVROWS:
    if 'reverse' in x_ and x_['reverse'] not in (True,False,'a','b'):rows.append((x_['a'],x_['b'],x_['at'][0],'reverse 값',str(x_['reverse'])))
    if 'passenger_only' in x_ and x_['passenger_only'] is not True:rows.append((x_['a'],x_['b'],x_['at'][0],'passenger_only 값',str(x_['passenger_only'])))
if _RVC198:
    _rvl=collections.defaultdict(list)
    for r_,ol_ in m.execute("select route_id,other_line_id from route_link_reverse"):_rvl[(routes.get(r_,{}).get('line_id'),ol_)].append(r_)
    for x_ in _RVROWS:
        if x_.get('reverse') in (True,'a','b'):
            sides_=[(x_['a'],x_['b'])] if x_['reverse']=='a' else [(x_['b'],x_['a'])] if x_['reverse']=='b' else [(x_['a'],x_['b']),(x_['b'],x_['a'])]
            if not any(_rvl.get(k_) for k_ in sides_):rows.append((x_['a'],x_['b'],x_['at'][0],'표식 기간 없음',str(x_.get('from'))))
put('K199 근거 표 THROUGH의 reverse·passenger_only 칸 값이 틀리거나 reverse 행의 표식 행이 없음',rows,20)
# ==== 11회차 T1 간접환승 거리 (사용자 결정 2026-11-16) ====
# K205 채택 환승 쌍의 두 역 정밀 좌표 거리가 500 m를 넘는데 손 표(hub_join) why에 「확인」 표시가 없음. 거리는 빼는 기준이 아니라
# 역 노드를 잘못 맞춘 것 아닌가 의심하는 징표다(玉川 문서의 「野田駅（JR大阪環状線）」을 阪神 野田에 맞춘 꼴). 확인을 마친 쌍은 why에 「노드 확인」을 적는다
_HJW205=collections.defaultdict(str)
for x_ in OVR('hub_join.json'):_HJW205[frozenset((x_['node'],x_['with']))]+=x_.get('why','')
rows=[]
for a_,b_,bs_ in sorted({tuple(r_) for r_ in m.execute('select node_a,node_b,basis from hub_pair')}):
    p_,q_=pos.get(a_),pos.get(b_)
    if not p_ or not q_ or p_[2]!='precise' or q_[2]!='precise':continue
    d_=6371000*math.hypot(math.radians(q_[0]-p_[0]),math.radians(q_[1]-p_[1])*math.cos(math.radians(p_[0])))
    if d_>500 and '확인' not in _HJW205.get(frozenset((a_,b_)),''):rows.append((a_,nn(a_),b_,nn(b_),round(d_),json.loads(bs_)[0] if bs_ else ''))
put('K205 채택 환승 쌍 두 역 정밀 거리 500 m 초과인데 손 표 why에 「확인」 없음(노드 맞춤 확인 목록)',sorted(set(rows),key=lambda r:-r[4]),40,lvl='warn')
# ==== 같은 자리 열람 전용 역 순서 (2026-11-17 志度線 瓦町 앞) ====
# K206 계통 위 열람 전용 역(route_id 있음)의 계통 순번(seq, DESIGN §4.5)이 비었거나 한 계통 안에서 겹침. 앱은 같은 자리 역을 이 순서로 놓는다
_A206=[dict(r_) for r_ in m.execute('select id,line_id,route_id,after_id,before_id,km,seq from archive_stop where route_id is not null')]
_AN206={i:x for i,x in n.execute("select entity_id,text from name where entity_type='archive' and lang='ja' and line_id is null and valid_from is null and valid_to is null")}
rows=[('순번 없음',a_['route_id'],a_['id'],_AN206.get(a_['id'])) for a_ in _A206 if a_['seq'] is None]
for (rt_,sq_),c_ in collections.Counter((a_['route_id'],a_['seq']) for a_ in _A206 if a_['seq'] is not None).items():
    if c_>1:rows.append(('순번 겹침',rt_,sq_,c_))
put('K206 계통 위 열람 전용 역 순번(seq) 없음·한 계통 안 겹침',rows,20)
# K206 같은 자리(같은 계통·같은 앞 역·같은 뒤 역)에 열람 전용 역이 둘 넘는데 순번 순서가 km 순(둘 다 km 있을 때)이나 위키 노선도 행 순서와 어긋남.
# 노선도 행은 gen_wiki 보고서(data/candidates/wiki_rows.json, 로컬 생성물)에서 이름이 같은 역 꼴 행을 찾고 앞(뒤) 역 행 쪽으로 방향을 맞춘다. 보고서가 없으면 km만 본다.
# km가 1순위라 km와 노선도가 다르면 노선도 어긋남으로 남는다(사람이 볼 후보)
_WP206=os.path.join(ROOT,'data','candidates','wiki_rows.json')
_WR206=json.load(open(_WP206,encoding='utf-8')) if os.path.exists(_WP206) else {}
def _wrow206(a_):
    W_=_WR206.get(a_['line_id'])
    if not W_:return None
    nm_=znorm_(_AN206.get(a_['id']) or '');rs_=[i for i,x in W_['s'] if x==nm_]
    if not rs_:return None
    nr_=collections.defaultdict(list)
    for i,x in W_['n']:nr_[x].append(i)
    for k_,sg_ in (('after_id',1),('before_id',-1)):
        if a_[k_] not in nr_:continue
        i_,j_=min(((i,j) for i in rs_ for j in nr_[a_[k_]]),key=lambda p:abs(p[0]-p[1]))
        return (a_['line_id'],i_ if (i_-j_)*sg_>0 else -i_)
    return None
_G206=collections.defaultdict(list)
for a_ in _A206:_G206[(a_['route_id'],a_['after_id'],a_['before_id'])].append(a_)
rows=[]
for k_,L_ in sorted(_G206.items(),key=lambda x:tuple(y or '' for y in x[0])):
    if len(L_)<2:continue
    L_.sort(key=lambda a_:(a_['seq'] is None,a_['seq'] or 0))
    nm_=[_AN206.get(a_['id']) for a_ in L_]
    K_=[a_['km'] for a_ in L_ if a_['km'] is not None]
    if K_!=sorted(K_):rows.append(('km 순과 어긋남',k_[0],k_[1],k_[2],nm_,[a_['km'] for a_ in L_]))
    W_=[(w_,_AN206.get(a_['id'])) for a_ in L_ for w_ in [_wrow206(a_)] if w_]
    for ln_ in {w_[0] for w_,_ in W_}:
        V_=[(w_[1],x_) for w_,x_ in W_ if w_[0]==ln_]
        if [x_ for _,x_ in V_]!=[x_ for _,x_ in sorted(V_)]:rows.append(('노선도 순과 어긋남',k_[0],k_[1],k_[2],nm_,[x_ for _,x_ in sorted(V_)]))
put('K206 같은 자리 열람 전용 역 순번 순서가 km 순·위키 노선도 행 순서와 어긋남(확인 목록)',rows,40,lvl='warn')
json.dump(R,open(os.path.join(B,'audit.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=0,default=str)
err={k:v['n'] for k,v in R.items() if v['n'] and v['lvl']=='err'};warn={k:v['n'] for k,v in R.items() if v['n'] and v['lvl']=='warn'}
STRICT=os.environ.get('NORIORI_AUDIT_STRICT')=='1'
print(f"audit_db 오류 {len(err)}항목 {sum(err.values())}건, 경고 {len(warn)}항목 {sum(warn.values())}건 ({'엄격' if STRICT else '보고만'})")
if STRICT and err:sys.exit(1)
