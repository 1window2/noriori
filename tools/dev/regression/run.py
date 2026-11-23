# -*- coding: utf-8 -*-
# 회귀 대조: 전수 대조 1·2회차 지적 사례표(cases.json)를 빌드 결과와 맞춰 아직 남은 사례를 센다 (2회차 종합 K34)
# 쓰는 법: python3 -I tools/dev/regression/run.py [build 폴더]. 검사 사례는 build/audit.json·audit_ext.json을 읽으므로 감사 도구 뒤에 돌린다
# 결과: build/regression.json. 마지막 줄이 합계다. NORIORI_AUDIT_STRICT=1이면 남은 사례가 하나라도 있을 때 실패한다
import sys,os,json,sqlite3,collections,math
HERE=os.path.dirname(os.path.abspath(__file__));ROOT=os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
sys.path.insert(0,os.path.join(ROOT,'tools'))
from lib import lohi
B=sys.argv[1] if len(sys.argv)>1 else os.path.join(ROOT,'build')
C=json.load(open(os.path.join(HERE,'cases.json'),encoding='utf-8'))['cases']
m=sqlite3.connect(os.path.join(B,'master.sqlite'));n=sqlite3.connect(os.path.join(B,'names.sqlite'))
NM=collections.defaultdict(list)
for t,i,lg,x,k,li,vf,vt in n.execute('select entity_type,entity_id,lang,text,kana,line_id,valid_from,valid_to from name'):NM[t,i].append((lg,x,k,li,vf,vt))
def base(t,i,lg):return next((r for r in NM[t,i] if r[0]==lg and not r[3] and not r[4] and not r[5]),None)
NODES={r[0] for r in m.execute('select id from node')}
GRP=dict(m.execute('select id,group_id from node').fetchall())
SPR=collections.defaultdict(list)
for rt,x,f_,t_ in m.execute('select route_id,node_id,valid_from,valid_to from route_stop_period'):SPR[x].append((rt,f_,t_))
MOVE=[tuple(r) for r in m.execute('select old_node,new_node,moved_on from node_move')]
MARK=collections.defaultdict(list)
for x,l,k,f_,t_ in n.execute('select node_id,line_id,kind,valid_from,valid_to from stop_mark'):MARK[x].append((k,f_,t_))
# 계통 한정 표식(stop_mark_route)도 같은 표식이다 (尼崎港線 尼崎, 2026-11-14)
if n.execute("select 1 from sqlite_master where name='stop_mark_route'").fetchone():
    for x,k,f_,t_ in n.execute('select node_id,kind,valid_from,valid_to from stop_mark_route'):MARK[x].append((k,f_,t_))
HP={frozenset((a,b)) for a,b in m.execute('select node_a,node_b from hub_pair')}
ARCH=collections.defaultdict(list)
for i,rt,a,b,km in m.execute('select id,route_id,after_id,before_id,km from archive_stop'):
    for r in NM['archive',i]:
        if r[0]=='ja':ARCH[r[1]].append((rt,a,b,km))
EK=collections.defaultdict(list)
for a,b,km in m.execute('select e.from_node,e.to_node,k.km from edge e join edge_km k on k.edge_id=e.id'):EK[frozenset((a,b))].append(km)
LP={(l,x,f_) for l,x,f_ in m.execute("select line_id,name_ja,valid_from from line_period where kind='name'")}
POS={r[0]:(r[1],r[2]) for r in m.execute('select node_id,lat,lon from node_position where lat is not null')}
# 8회차 W1b 새 판정: 계통 위 역 km(stopkm), 계통의 노선(routeline), 그날 칸의 사업자(edgeop)
SKM=collections.defaultdict(list)
for rt,x,km in m.execute('select route_id,node_id,km_cum from route_stop'):SKM[rt,x].append(km)
RLINE=dict(m.execute('select id,line_id from route').fetchall())
EOP=collections.defaultdict(list)
for a,b,l,o,f_,t_ in m.execute('select e.from_node,e.to_node,ea.line_id,ea.operator_id,ea.valid_from_lo,ea.valid_to_hi from edge e join edge_attr ea on ea.edge_id=e.id'):EOP[frozenset((a,b)),l].append((o,f_ or '0000',t_ or '9999'))
CH={};CHK=set()
for fn in('audit.json','audit_ext.json'):
    p=os.path.join(B,fn)
    if os.path.exists(p):
        for k,v in json.load(open(p,encoding='utf-8')).items():CH[k]=set(v.get('ids',[])) if v.get('n') else set();CHK.add(k)
TL={frozenset((a,b,x)) for x,a,b in m.execute("select at_node,line_a,line_b from track_link where kind in ('continue','branch')")}
# 계통 이음 행 (3회차 W1a: link 종류). (계통, 역 노드) → 행들
LNK=collections.defaultdict(list)
for r_ in m.execute('select l.route_id,s.node_id,l.other_line_id,l.other_route_id,l.kind,l.side,l.next_stop_node,l.terminal_node,l.valid_from,l.valid_to,l.other_node from route_link l join route_stop s on s.route_id=l.route_id and s.seq=l.seq'):LNK[r_[0],r_[1]].append(r_[2:])
# 계통 끝 너머 역: 확장 행 장치를 걷어내고(5번 결정 2026-11-19) 그 계통 끝에서 그 역으로 가는 끝 이어짐(continue, 다음 역·끝 역)으로 바뀌었다.
# (계통, 그 역) → 이어짐 기간들. extstop은 사례 기간과 겹치는 이어짐이 있는가, extend는 그런 이어짐이 하나라도 있는가
# (5번 결정 재구성 2026-11-20) 끝 이어짐은 끝 노드에서 상대 계통으로 이어지고, 그 계통에서 끝 노드(또는 상대 노드)부터 끝 역까지 사이의 역들에 닿는다.
# 옛 확장 행의 역(Y)은 그 사이에 있으면 닿는 것이다. 상대 계통을 적지 않은 이어짐은 그 노선 계통 가운데 두 노드를 함께 둔 계통으로 본다
RROWS=collections.defaultdict(list)
for r_,n_ in m.execute('select route_id,node_id from route_stop order by route_id,seq'):RROWS[r_].append(n_)
RLN={r_:l_ for r_,l_ in m.execute('select id,line_id from route')}
RFT={r_:(a_,b_) for r_,a_,b_ in m.execute('select id,from_node,to_node from route')}
_RBYL=collections.defaultdict(list)
for r_,l_ in RLN.items():_RBYL[l_].append(r_)
_SEQ2={(r_,q_):n_ for r_,q_,n_ in m.execute('select route_id,seq,node_id from route_stop')}
def _ovl(a,b):
    """두 기간(시작, 끝)이 겹치는가 (EDTF 범위는 넓게)"""
    def l_(v):return '0000' if v in (None,'ongoing') else (lohi(v)[0] or '0000')
    def h_(v):return '9999' if v in (None,'ongoing') else (lohi(v)[1] or '9999')
    return l_(a[0])<h_(b[1]) and l_(b[0])<h_(a[1])
XST=collections.defaultdict(list)
for rt_,sq_,ol_,orr_,nx_,te_,on_,f_,t_ in m.execute("select route_id,seq,other_line_id,other_route_id,next_stop_node,terminal_node,other_node,valid_from,valid_to from route_link where kind='continue'"):
    at_=on_ or _SEQ2.get((rt_,sq_))
    hit_={x_ for x_ in (nx_,te_) if x_}
    for q_ in ([orr_] if orr_ else _RBYL.get(ol_,[])):
        R_=RROWS.get(q_,[])
        a0_=on_ if on_ in R_ else next((x_ for x_ in R_ if x_==at_),None)
        if a0_ is None:
            a0_=next((x_ for x_ in R_ if x_ in RROWS.get(rt_,[])),None)
        if a0_ in R_ and te_ in R_:
            # 그 사이에서 그 이어짐 기간에 그 계통이 서던 역만(서지 않던 역까지 닿는다고 세지 않는다)
            i_,j_=R_.index(a0_),R_.index(te_)
            hit_|={x_ for x_ in R_[min(i_,j_):max(i_,j_)+1] if any(rr_==q_ and _ovl((ff_,tt_),(f_,t_)) for rr_,ff_,tt_ in SPR.get(x_,[]))}
    for n_ in hit_:XST[rt_,n_].append((f_,t_))
EXT=collections.defaultdict(set)
for (rt_,n_) in XST:EXT[rt_].add(n_)
XNEXT=collections.defaultdict(set)
for rt_,nx_ in m.execute("select route_id,next_stop_node from route_link where kind='continue'"):XNEXT[rt_].add(nx_)
# 정차 공백(route_stop_gap). 끝 없는 공백은 gap_to='ongoing'(재개 미정 정차 운휴, 11회차 시뮬레이터 시험: 합치기에서 되돌려진 것을 잡는다)
SGAP=collections.defaultdict(list)
for r_ in m.execute('select route_id,node_id,gap_from,gap_to from route_stop_gap'):SGAP[r_[0],r_[1]].append((r_[2],r_[3]))
SDIR=collections.defaultdict(list)
for r_ in m.execute('select route_id,node_id,direction,label,use,valid_from,valid_to from stop_direction'):SDIR[r_[0],r_[1]].append(r_[2:])
def _on(v,day):
    """날 day가 기간 v=(시작, 끝) 안에 확실히 드는가"""
    f_,t_=v;lo_=lohi(f_)[1] if f_ else '0000';hi_='9999' if t_ in (None,'ongoing') else lohi(t_)[0]
    return (lo_ or '0000')<=day<(hi_ or '9999')
# 기대값의 자리표시(「(岸ノ里 개업일)」·「(끝)」처럼 사례표를 만들 때 값을 못 정한 쪽)는 판정하지 않는 쪽으로 읽는다
def val(v):return None if isinstance(v,str) and v.startswith('(') and v.endswith(')') else v
def _alt_nodes(c):
    """사례 노드에 연결이 없을 때 볼 그 계통의 끝 노드 행: 상대 노선(계통) 계통의 끝 노드이거나 이 계통의 끝 노드인 행"""
    qs_=[c['other_route']] if c.get('other_route') else _RBYL.get(c.get('other_line'),[])
    ends_={x_ for q_ in qs_ for x_ in RFT.get(q_,())}|set(RFT.get(c['route'],()))
    return [x_ for x_ in RROWS.get(c['route'],[]) if x_ in ends_ and x_!=c['node']]
def _link_case(c):
    def _match(rs,loose):
        out=[]
        for r_ in rs:
            if c.get('other_line') and r_[0]!=c['other_line']:continue
            if c.get('other_route') and r_[1]!=c['other_route']:continue
            if c.get('link_kind') and r_[2]!=c['link_kind']:continue
            if c.get('day') and not _on((r_[6],r_[7]),c['day']):continue
            if c.get('term') and r_[5]!=c['term']:continue
            if c.get('side') and r_[3]!=c['side']:continue
            if c.get('other_node') and r_[8]!=c['other_node']:continue
            nx_=c.get('next')
            if nx_ and r_[4]!=nx_:
                # 번역: 옛 확장 위치(사례 노드)가 새 다음 역이거나, 상대 계통의 끝 노드(서지 않는 끝 노드)가 다음 역이면 같은 방면이다
                if not loose:continue
                q_=r_[1] or next((q for q in _RBYL.get(r_[0],[]) if r_[4] in RROWS.get(q,[])),None)
                if not(r_[4]==c['node'] or (q_ and r_[4] in RFT.get(q_,()) and nx_ not in RROWS.get(q_,[]))):continue
            out.append(r_)
        return out
    hit=_match(LNK[c['route'],c['node']],False)
    if not hit and not c.get('absent'):
        hit=_match(LNK[c['route'],c['node']],True) or [r_ for x_ in _alt_nodes(c) for r_ in _match(LNK[c['route'],x_],True)]
    return not hit if c.get('absent') else bool(hit)
def de(a,x):
    """날짜 a가 기대값 x에 맞는가. x가 자리표시·없음이면 맞음. x가 해·달 정밀도(1994-XX-XX)나 범위([1957..1958])면 a가 그 안에 들면 맞음
    (DB가 더 정확한 날을 가진 경우: 名古屋球場正門前 rinji 1987-07-01~1994-10-08)"""
    x=val(x)
    if x is None or a==x:return True
    if not isinstance(a,str) or not isinstance(x,str) or not ('X' in x or x.startswith('[')):return False
    try:la,ha=lohi(a);lx,hx=lohi(x)
    except ValueError:return False
    return bool(la and lx) and lx<=la and ha<=hx
# 경고(warn) 단계 검사 가운데 사용자 결정이 허용한 꼴. 사례가 이 검사에만 걸려 있으면 규칙상 정상이다
RULE_OK={'K02 근거 없는 이어짐(source=derived continue)':'U02 선로가 이어졌으면 정기 직통이 없어도 분기·끝 이어짐으로 그린다(DESIGN §2.9 문자대로). '
         '근거 칸 없는 이어짐(derived) 경고는 확인 목록이라 결함이 아니다'}
def judge(c):
    """True=고쳐짐, False=남음, None=판정할 자료 없음, 문자열=규칙상 정상 사유"""
    k=c['kind']
    if k=='name':
        # 폐역 뒤에도 마지막 이름 규칙(2026-11-21): 기대한 끝이 그 역의 마지막 정차 끝이면, 끝이 비어 폐역 뒤로 이어지는 같은 이름 행도 같은 사례다
        last_=[r[2] for r in SPR[c['node']] if r[2]!='ongoing']
        closed_=bool(last_) and not any(r[2]=='ongoing' for r in SPR[c['node']]) and bool(c.get('valid_to')) and any(de(t_,c['valid_to']) for t_ in last_)
        return any(r[0]=='ja' and r[1]==c['text'] and (de(r[5],c.get('valid_to')) or (closed_ and r[5] in (None,'ongoing'))) and de(r[4],c.get('valid_from')) and (not c.get('line') or r[3]==c['line']) for r in NM['node',c['node']])
    if k=='kana':return any(r[0]=='ja' and r[1]==c['text'] and r[2]==c['kana'] for r in NM['node',c['node']])
    if k=='nodename':
        b=base('node',c['node'],'ja' if c['lang']=='kana' else c['lang'])
        return bool(b) and (b[2] if c['lang']=='kana' else b[1])==c['text']
    # 옛 확장 행(그 계통 행에 없는 역)의 정차 기대값은 끝 이어짐으로 그 역에 닿는가로 본다(5번 결정 재구성)
    if k=='stop' and c.get('route') and c['node'] not in RROWS.get(c['route'],()):
        return bool(XST.get((c['route'],c['node'])))
    if k=='stop':
        v=[r for r in SPR[c['node']] if not c.get('route') or r[0]==c['route']]
        # 정차 기간이 둘 이상인 기대값(periods: [[시작, 끝], ...])은 기간마다 같은 정차 토막(route_stop_period)이 있어야 한다. 끝 null은 지금도 선다
        if c.get('periods'):
            return bool(v) and all(any(de(r[1],a) and (r[2]=='ongoing' if b is None else de(r[2],b)) for r in v) for a,b in c['periods'])
        return bool(v) and any(de(r[1],c.get('valid_from')) for r in v) and any(de(r[2],c.get('valid_to')) for r in v)
    if k=='moved':return any(w==c['new'] and de(d,c['date']) and (not c.get('old') or o==c['old']) for o,w,d in MOVE)
    if k=='mark':return any(kd==c['mark'] and de(f_,c.get('valid_from')) and de(t_,c.get('valid_to')) for kd,f_,t_ in MARK[c['node']])
    # 거짓 연결 지적: 그 역에서 두 노선 사이 분기·끝 이어짐(track_link)이 없어야 한다 (pairs: [[노선, 상대 노선], ...])
    if k=='nolink':return not any(frozenset((a,b,c['node'])) in TL for a,b in c['pairs'])
    # 계통 이음 행: {route, node, other_line|other_route, link_kind?, day?, next?, term?, side?, absent?}. day가 있으면 그날 유효한 행만 본다.
    # absent면 조건에 맞는 행이 없어야 고쳐짐이다 (3회차 W1a)
    if k=='link':
        return _link_case(c)
    if k=='link_raw':
        rs=[r_ for r_ in LNK[c['route'],c['node']] if (not c.get('other_line') or r_[0]==c['other_line']) and (not c.get('other_route') or r_[1]==c['other_route'])
            and (not c.get('link_kind') or r_[2]==c['link_kind']) and (not c.get('day') or _on((r_[6],r_[7]),c['day']))]
        hit=[r_ for r_ in rs if (not c.get('next') or r_[4]==c['next']) and (not c.get('term') or r_[5]==c['term']) and (not c.get('side') or r_[3]==c['side']) and (not c.get('other_node') or r_[8]==c['other_node'])]
        return not hit if c.get('absent') else bool(hit)
    # 선로 연결 있음(nolink의 반대): pairs의 모든 쌍이 그 역에서 분기·끝 이어짐(track_link)
    # 계통 끝 확장 행의 정차 기간 (3회차 kyushu_1-013)
    if k=='extstop':
        lo_=lohi(c.get('valid_from'))[0] or '0000';hi_=(lohi(c['valid_to'])[1] if c.get('valid_to') else None) or '9999'
        return any((lohi(f_)[0] or '0000')<hi_ and lo_<(('9999' if t_ in (None,'ongoing') else lohi(t_)[1]) or '9999') for f_,t_ in XST[c['route'],c['node']])
    if k=='track':return all(frozenset((a,b,c['node'])) in TL for a,b in c['pairs'])
    # 계통 끝 확장 역: absent면 extend_to에 없어야 한다
    # 옛 확장 목록은 「끝 너머 바로 다음 역」이었다. 새 모델에서 「없어야 함」은 끝 이어짐의 다음 역이 그 역이 아님, 「있어야 함」은 끝 이어짐으로 그 역에 닿음이다(5번 결정 재구성)
    if k=='extend':return (c['node'] not in XNEXT.get(c['route'],set())) if c.get('absent') else (c['node'] in EXT.get(c['route'],set()))
    if k=='hub':return frozenset((c['a'],c['b'])) in HP
    if k=='nohub':return frozenset((c['a'],c['b'])) not in HP
    if k=='nogroup':return not(GRP.get(c['a']) and GRP.get(c['a'])==GRP.get(c['b']))
    # 12회차(2026-11-18): archname 열람 전용 행(역·노선)의 그 언어 이름 {aid, lang, text}, closeby 그 계통 정차 기간의 폐지 늦은 끝이 그날 이전 {route, node, by}
    if k=='archname':return any(r[0]==c['lang'] and r[1]==c['text'] for r in NM['archive',c['aid']])
    if k=='closeby':return bool(SPR[c['node']]) and all(t_!='ongoing' and (lohi(t_)[1] or '9999')<=c['by'] for rt,f_,t_ in SPR[c['node']] if rt==c['route'])
    if k=='archive':
        return any(rt==c['route'] and (not c.get('after') or a==c['after']) and (not c.get('before') or b==c['before']) and (c.get('km') is None or (km is not None and abs(km-c['km'])<.05)) for rt,a,b,km in ARCH[c['name']])
    if k=='edgekm':return any(abs(x-c['km'])<.05 for x in EK[frozenset((c['a'],c['b']))])
    if k=='linename':
        b=base('line',c['line'],c['lang']);return bool(b) and b[1]==c['text']
    if k=='lineperiod':return (c['line'],c['name'],c['valid_from']) in LP
    if k=='pos':
        p=POS.get(c['node']);return bool(p) and math.hypot((p[0]-c['lat'])*111,(p[1]-c['lon'])*91)<.03
    if k=='absent':return c['node'] not in NODES
    # 계통 위 역의 누적 km (공식 기점 한 줄 축: 三河線·頸城鉄道·横荘線, 시대 km: 大畑線)
    if k=='stopkm':return any(x is not None and abs(x-c['km'])<.05 for x in SKM[c['route'],c['node']])
    # 계통이 그 노선에 속함 (노선 합침: 循環線 토막·旧線, 新金線 → 総武本線)
    if k=='routeline':return RLINE.get(c['route'])==c['line']
    # 그날(date) 그 칸(a–b, 노선 line)의 사업자
    if k=='edgeop':return any(o==c['operator'] and f_<=c['date']<t_ for o,f_,t_ in EOP[frozenset((c['a'],c['b'])),c['line']])
    if k=='check':
        if not all(h in CHK for h in c['checks']):return None
        hit=[h for h in c['checks'] if set(c['ids'])&CH[h]]
        if hit and all(h in RULE_OK for h in hit):return RULE_OK[hit[0]]+(f" ({c['basis']})" if c.get('basis') else '')
        return not hit
    # 9회차 L 새 판정. nostop: 그날(day) 그 계통(route)에서 그 역(node)이 서지 않음(정차 토막 route_stop_period가 그날을 덮지 않음, 경계 통과 역 北鹿島 1978–1983)
    if k=='nostop':return not any(_on((f_,t_),c['day']) for rt,f_,t_ in SPR[c['node']] if rt==c['route'])
    # stopdir: 한 방향 정차(stop_direction) 행. {route, node, direction?(seq_up|seq_down), label?, use?, day?} (8회차 W3 요청)
    if k=='stopdir':
        return any((not c.get('direction') or d_==c['direction']) and (not c.get('label') or lb_==c['label']) and (not c.get('use') or (u_ or '')==c['use']) and (not c.get('day') or _on((f_,t_),c['day']))
                   for d_,lb_,u_,f_,t_ in SDIR[c['route'],c['node']])
    # 9회차 S 새 판정. 칸은 노드 쌍(a, b)으로 찾는다(edge 번호는 빌드마다 바뀐다)
    # 칸 수명: {a, b, valid_from?, valid_to?, close_reason?, legal?, status?} 조건에 맞는 edge_life 행이 있는가 (八栗·阪和貨物線·西大寺)
    if k=='edgelife':
        return any((c.get('valid_from') is None or de(f_,c['valid_from'])) and (c.get('valid_to') is None or de(t_,c['valid_to'])) and (not c.get('close_reason') or r_==c['close_reason'])
                   and (c.get('legal') is None or de(lg_,c['legal'])) and (not c.get('status') or st_==c['status']) for f_,t_,st_,lg_,r_ in ELIFE[frozenset((c['a'],c['b']))])
    # 노선 시대 km: {a, b, line, km} 그 칸의 그 노선 시대 km(edge_km_era). km이 null이면 시대 km 행이 없어야 한다 (西出水·弘南·大畑)
    if k=='erakm':
        v=EERA[frozenset((c['a'],c['b'])),c['line']]
        return (not v) if c.get('km') is None else any(abs(x-c['km'])<.05 for x in v)
    # 칸 개업일: {a, b, date} 그 칸의 첫 영업 행 시작
    if k=='edge_open':
        v=sorted(ELIFE[frozenset((c['a'],c['b']))],key=lambda r_:lohi(r_[0])[0] or '0000')
        return bool(v) and de(v[0][0],c['date'])
    # 계통 첫 역: {route, node} 확장 행을 뺀 순번 0 정차 노드
    if k=='stopgap':return any(de(f_,c['gap_from']) and (t_==c.get('gap_to','ongoing') or de(t_,c.get('gap_to'))) for f_,t_ in SGAP[c['route'],c['node']])
    if k=='route_first':return RFIRST.get(c['route'])==c['node']
    # 열람 전용 중복 없음: {route?, name?} 같은 계통·같은 이름·같은 km 열람 전용 역이 둘 이상이면 남음
    if k=='archive_unique':
        cnt_=collections.Counter((rt,nm_,km) for nm_,v in ARCH.items() for rt,a,b,km in v if (not c.get('route') or rt==c['route']) and (not c.get('name') or nm_==c['name']))
        return all(x<2 for x in cnt_.values())
    # 같은 노선 기간 km: {a, b, line, km, until} 그 칸에 그 날까지의 기간 km 행(edge_km_period, source km_era_period)
    if k=='kmperiod':return any(abs(x-c['km'])<.05 and de(u_,c['until']) for x,u_ in EKP[frozenset((c['a'],c['b'])),c['line']])
    # 9회차 N 새 판정: 읽기 없음(nokana: 그 노드의 일본어 이름 행 가운데 text가 맞는 행(없으면 지금 이름)에 읽기가 없음, 唐浜),
    # 노선 한정 이름(lname: 기간 없는 노선 한정 일본어 이름이 text. absent면 그 노선 한정 행이 하나도 없어야 함)
    if k=='nokana':
        v=[r for r in NM['node',c['node']] if r[0]=='ja' and (r[1]==c['text'] if c.get('text') else (not r[3] and not r[4] and not r[5]))]
        return bool(v) and all(not r[2] for r in v)
    if k=='lname':
        v=[r for r in NM['node',c['node']] if r[0]=='ja' and r[3]==c['line']]
        if c.get('absent'):return not v
        return any(r[1]==c['text'] and not r[4] and not r[5] for r in v)
    # 9회차 M: 열람 전용 노선(archive_line)이 이름·다는 역(at)으로 있는가 (archline)
    if k=='archline':return any(r[0]=='ja' and r[1]==c['name'] for i_,at_ in m.execute('select id,at_node from archive_line') if not c.get('at') or at_==c['at'] for r in NM['archive',i_])
    # 9회차 F: 여객 이력이 없는 화물 구간(숨은 노선). {line, a?, b?, km?, freight?}: 노선이 rule_class hidden이고 그 칸들에 분모 단위가 없으며,
    # a–b 칸이 그 노선에 속하고(km가 있으면 그 값), freight 노드는 kind freight이고 공개 노드가 아니다
    if k=='hidden':
        rc=m.execute('select rule_class from line where id=?',(c['line'],)).fetchone()
        if not rc or rc[0]!='hidden':return False
        es={r_[0] for r_ in m.execute('select distinct edge_id from edge_attr where line_id=?',(c['line'],))}
        if not es or m.execute(f"select 1 from denominator_unit where edge_id in ({','.join('?'*len(es))}) limit 1",tuple(es)).fetchone():return False
        if c.get('a'):
            hit=[e_ for e_,a_,b_ in m.execute('select id,from_node,to_node from edge where id in (%s)'%','.join('?'*len(es)),tuple(es)) if {a_,b_}=={c['a'],c['b']}]
            if not hit or (c.get('km') is not None and not any(abs(x-c['km'])<.05 for x in EK[frozenset((c['a'],c['b']))])):return False
        if c.get('freight'):
            kd=m.execute('select kind from node where id=?',(c['freight'],)).fetchone()
            if not kd or kd[0]!='freight' or m.execute('select 1 from node_public where id=?',(c['freight'],)).fetchone():return False
        return True
    # 화면 전수 검사(tools/dev/screen_check.py, 9회차 X): {checks: [S.. 제목], ids}. 렌더 JSON을 읽은 결과가 이 판(master.sqlite)보다 새로울 때만 판정한다.
    # 렌더는 빌드에 들지 않아 결과가 없거나 옛 판의 것이면 판정 자료 없음이다
    if k=='screen':
        p_=os.path.join(B,'screen_check.json')
        if not os.path.exists(p_) or os.path.getmtime(p_)<os.path.getmtime(os.path.join(B,'master.sqlite')):return None
        S_=json.load(open(p_,encoding='utf-8'))
        hit=[h for h in c['checks'] if set(c['ids'])&set(S_.get(h,{}).get('ids',[]))]
        return not hit
    # 열람 전용 역 읽기(10회차 D3): 그 계통(·열람 전용 ID aid)의 열람 전용 역 일본어 행이 그 이름·읽기인가
    if k=='archkana':
        q_='select id from archive_stop where route_id=?'+(' and id=?' if c.get('aid') else '')
        return any(r[0]=='ja' and r[1]==c['name'] and r[2]==c['kana'] for (i_,) in m.execute(q_,(c['route'],)+((c['aid'],) if c.get('aid') else ())) for r in NM['archive',i_])
    # 10회차 G2 새 판정. linkstart: 계통 이음 행의 시작 {route, node, other_line, link_kind?, valid_from} (시작이 범위면 그 범위와 같아야 함, 宮福線 福知山),
    # noarchive: 그 계통(route)에 그 이름(name)의 열람 전용 역이 없음(다른 노선 정류장이 번진 중복, 北九州線 折尾 뒤), pref: 노드의 도도부현 {node, pref}
    if k=='linkstart':
        return any(r_[2]==c.get('link_kind',r_[2]) and r_[0]==c['other_line'] and r_[6]==c['valid_from'] for r_ in LNK[c['route'],c['node']])
    if k=='noarchive':return not any(rt==c['route'] for rt,a,b,km in ARCH[c['name']])
    if k=='pref':return str((m.execute('select pref from node where id=?',(c['node'],)).fetchone() or [None])[0])==str(c['pref'])
    # 11회차 S3 새 판정. linkrow: 그 계통 그 역에 상대 노선(other_line)·계통(other_route?)·종류(link_kind?)의 이음 행이 기간 그대로(valid_from, valid_to) 하나 있음.
    # 근거 표 행이 선로 연결 행을 자르거나 다른 계통이 끝 역 판정을 바꿔 시작·끝이 옮겨진 것을 잡는다(王寺 和歌山線 1972-03-15, 伊勢中川 1959-11-19~)
    if k=='linkrow':
        if not any((not c.get('other_line') or r_[0]==c['other_line']) and (not c.get('other_route') or r_[1]==c['other_route']) and (not c.get('link_kind') or r_[2]==c['link_kind'])
                   and r_[6]==c['valid_from'] and r_[7]==c['valid_to'] for r_ in LNK[c['route'],c['node']]):
            # 옛 확장 노드의 연결은 상대 노선 계통의 끝 노드 행으로 옮겨 갔다(5번 결정 재구성)
            # 다음 역이 바뀌는 날 나뉜 행(같은 상대·종류)은 이어 붙여 기간을 견준다 (白新線 大形 1957·東新潟 1958 개업)
            for x_ in _alt_nodes(c):
                iv_=sorted((r_[6],r_[7]) for r_ in LNK[c['route'],x_] if (not c.get('other_line') or r_[0]==c['other_line']) and (not c.get('other_route') or r_[1]==c['other_route']) and (not c.get('link_kind') or r_[2]==c['link_kind']))
                mg_=[]
                for a_,b_ in iv_:
                    if mg_ and mg_[-1][1]==a_:mg_[-1]=(mg_[-1][0],b_)
                    else:mg_.append((a_,b_))
                if (c['valid_from'],c['valid_to']) in mg_:return True
            return False
        return any((not c.get('other_line') or r_[0]==c['other_line']) and (not c.get('other_route') or r_[1]==c['other_route']) and (not c.get('link_kind') or r_[2]==c['link_kind'])
                   and r_[6]==c['valid_from'] and r_[7]==c['valid_to'] for r_ in LNK[c['route'],c['node']])
    # 11회차 S3 새 판정. reverse: 그날(day) 그 계통 그 역의 끝 역 이어짐(continue, 상대 노선 other_line, 다음 역 next?)에 스위치백 표식 기간(route_link_reverse)이 걸림(reverse true) 또는 이어짐은 있고 표식이 없음(false)
    if k=='reverse':
        if not m.execute("select 1 from sqlite_master where type='table' and name='route_link_reverse'").fetchone():return None
        rs=[r_ for r_ in m.execute("select l.seq,l.next_stop_node,l.valid_from,l.valid_to from route_link l join route_stop s on s.route_id=l.route_id and s.seq=l.seq where l.route_id=? and s.node_id=? and l.other_line_id=? and l.kind='continue'",(c['route'],c['node'],c['other_line']))
            if _on((r_[2],r_[3]),c['day']) and (not c.get('next') or r_[1]==c['next'])]
        hit=[r_ for r_ in rs if any(_on((f_,t_),c['day']) for f_,t_ in m.execute('select valid_from,valid_to from route_link_reverse where route_id=? and seq=? and other_line_id=? and next_stop_node is ?',(c['route'],r_[0],c['other_line'],r_[1])))]
        return bool(hit) if c['reverse'] else bool(rs) and not hit
    # 11회차 F1 새 판정. parstart: 그 계통의 상대 노선(other_line) 병주 토막 가운데 가장 이른 시작이 valid_from (날짜 모름 화면의 병주 시작,
    # 1950 전에 끝나 뺀 앞 토막의 시작을 첫 토막이 이어받음. 阪神なんば線 大物 1928, 日豊本線 小倉 1902)
    if k=='parstart':
        v_=[f_ for (f_,) in m.execute('select valid_from_lo from route_parallel where route_id=? and other_line_id=?',(c['route'],c['other_line']))]
        return bool(v_) and min(f_ or '0000' for f_ in v_)==(c['valid_from'] or '0000')
    # archorder: 그 계통(route)의 열람 전용 역을 앱처럼 계통 순번(seq) 순으로 읽었을 때 이름(names)이 그 차례로 나온다 (같은 자리 순서, 2026-11-17 志度線 瓦町 앞)
    if k=='archorder':
        got=[r[1] for (i_,) in m.execute('select id from archive_stop where route_id=? order by seq is null,seq,rowid',(c['route'],)) for r in NM['archive',i_] if r[0]=='ja' and not r[3] and not r[4] and not r[5] and r[1] in c['names']]
        return got==c['names']
    return None
ELIFE=collections.defaultdict(list)
for a,b,f_,t_,st_,lg_,r_ in m.execute('select e.from_node,e.to_node,l.valid_from,l.valid_to,l.status,l.legal_abolition,l.close_reason from edge e join edge_life l on l.edge_id=e.id'):ELIFE[frozenset((a,b))].append((f_,t_,st_,lg_,r_))
EERA=collections.defaultdict(list)
for a,b,l,km in m.execute('select e.from_node,e.to_node,k.line_id,k.km from edge e join edge_km_era k on k.edge_id=e.id'):EERA[frozenset((a,b)),l].append(km)
EKP=collections.defaultdict(list)
for a,b,l,mm,u_ in m.execute("select e.from_node,e.to_node,p.line_id,p.m,p.valid_to from edge e join edge_km_period p on p.edge_id=e.id where p.source='km_era_period'"):EKP[frozenset((a,b)),l].append((mm/1000,u_))
RFIRST={rt:x for rt,x in m.execute('select route_id,node_id from route_stop where seq=0')}
res=[];cnt=collections.Counter();by=collections.defaultdict(collections.Counter)
for c in C:
    j=None if c.get('normal') else judge(c)
    st='normal' if c.get('normal') or isinstance(j,str) else {True:'fixed',False:'open',None:'skip'}[j]
    cnt[c['round'],st]+=1;by[c.get('cause') or c.get('cat') or '-'][st]+=1
    res.append(dict(c,state=st,**({'normal':j} if isinstance(j,str) else {})))
json.dump(dict(count={f'{a}회차 {b}':v for (a,b),v in sorted(cnt.items())},by_cause={k:dict(v) for k,v in sorted(by.items())},
               open=[r for r in res if r['state']=='open'],normal=[r for r in res if r['state']=='normal']),open(os.path.join(B,'regression.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=0)
for k,v in sorted(by.items()):
    if v['open']:print(k,dict(v))
op=sum(v for (a,b),v in cnt.items() if b=='open')
STRICT=os.environ.get('NORIORI_AUDIT_STRICT')=='1'
print(f"회귀 대조 {len(C)}사례: 남음 {op} (1회차 {cnt[1,'open']}·2회차 {cnt[2,'open']}), 고쳐짐 {sum(v for (a,b),v in cnt.items() if b=='fixed')}, 판정 자료 없음 {sum(v for (a,b),v in cnt.items() if b=='skip')}, 규칙상 정상 {sum(v for (a,b),v in cnt.items() if b=='normal')} ({'엄격' if STRICT else '보고만'})")
if STRICT and op:sys.exit(1)
