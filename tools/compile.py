# -*- coding: utf-8 -*-
# data/source를 컴파일해 build/master.sqlite, build/names.sqlite, build/report.json을 만든다
import sys,os,json,sqlite3,collections,heapq,re,math
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from lib import *

TODAY=AS_OF
ERR=collections.defaultdict(list)
WARN=collections.defaultdict(list)
def err(k,v):ERR[k].append(v)
from decimal import Decimal,ROUND_HALF_UP
def dround(x,n=1):
    """km 반올림은 사사오입이다. float round()는 15.85를 15.8로 내린다(이진 표현·은행가 반올림). 6자리에서 float 잡음을 먼저 지운다"""
    return None if x is None else float(Decimal(repr(round(x,6))).quantize(Decimal(1).scaleb(-n),rounding=ROUND_HALF_UP))

ops={o['id']:o for o in load('operators')}
lines={l['id']:l for l in load('lines')}
routes={r['id']:r for r in load('routes')}
nodes={n['id']:n for n in load('nodes')}
groups=load('groups')
edges={e['id']:e for e in load('edges')}
kms={k['edge']:k['km'] for k in load('km')}
events=load('events')
# 생성기가 빠뜨린 사건을 재생성 전까지 컴파일에서 고친다. 원본(data/source)은 생성 결과라 손대지 않는다.
# 재생성으로 원본이 맞아지면 이 행은 쓰이지 않게 되고, 쓰이지 않는 행은 오류다 (data/README.md)
def _fix_lines(x):
    v=x.get('add') or x.get('set') or {}
    return {v.get('line'),(v.get('from') or {}).get('line'),(v.get('to') or {}).get('line')}-{None}
def _fix_ops(x):
    v=x.get('add') or x.get('set') or {}
    return {v.get('operator'),(v.get('from') or {}).get('operator'),(v.get('to') or {}).get('operator')}-{None}
_nopatch=bool(os.environ.get('NORIORI_GEN') or os.environ.get('NORIORI_NEW_IDS'))
_EF=json.load(open(os.path.join(ROOT,'data','overrides','events_fix.json'),encoding='utf-8'))
# source_patch로 더한 노선·사업자를 가리키는 행은 보정을 얹지 않는 생성 중 컴파일에서 건너뛴다.
# 이관은 사슬이라 한 행만 빠지면 다음 행의 출발 사업자가 없다. 그런 노선의 행은 모두 건너뛴다 (北勢線 三重交通→三重電鉄→近鉄→三岐)
def _ef_lines(x):return _fix_lines(x)|{(x.get('match') or {}).get('line')}-{None}
_skipl={l_ for x in _EF if _fix_lines(x)-set(lines) or _fix_ops(x)-set(ops) for l_ in _ef_lines(x)} if _nopatch else set()
for _x in _EF:
    if _nopatch and (_fix_lines(_x)-set(lines) or _fix_ops(_x)-set(ops) or _ef_lines(_x)&_skipl):continue
    if 'add' in _x:
        _ev=_x['add']
        if any(all(e.get(k)==v for k,v in _ev.items() if k!='source') for e in events):err('events_fix_unused',_x['why'])
        else:events.append(dict(_ev))
    else:
        _hit=[e for e in events if all(e.get(k)==v for k,v in _x['match'].items())]
        if len(_hit)!=1:err('events_fix_unused' if not _hit else 'events_fix_ambiguous',_x['why'])
        else:
            # 노선 소속만 바꾸는 보정(徳島線 佃–阿波池田 1914 개통을 徳島本線으로)은 범위를 원래 노선의 선로(seed)로 찾는다. 선로 위치는 그대로다
            if 'line' in _x['set'] and _x['set']['line']!=_hit[0].get('line') and '_scope_line' not in _hit[0]:_hit[0]['_scope_line']=_hit[0].get('line')
            _hit[0].update(_x['set'])
positions=load('positions')
hubs=load('hubs')
# 이름만 같은 다른 역(根室 국철–根室拓殖)이나 옛 위치는 환승 묶음에서 뗀다 (data/overrides/hub_split.json).
# 생성기는 이름과 초기 좌표로 묶어서, 확인한 쌍만 사람이 떼어 낸다. 묶음에 역이 더 있으면 좌표가 가까운 쪽으로 나눈다
# (野田: JR 野田·玉川 / 阪神 野田·野田阪神·海老江). 옛 위치(moved.json 짝)는 같은 역이라 같은 역 묶음은 그대로 둔다 ("group": false)
_pos={p_['node']:(p_['lat'],p_['lon']) for p_ in positions}
def _d2(x,y):
    if x not in _pos or y not in _pos:return 9e9
    (a1,o1),(a2,o2)=_pos[x],_pos[y];return (a1-a2)**2+((o1-o2)*math.cos(math.radians(a1)))**2
_hid={h['id'] for h in hubs}
for _x in json.load(open(os.path.join(ROOT,'data','overrides','hub_split.json'),encoding='utf-8')):
    _n,_f=_x['node'],_x['from']
    if _n not in nodes or _f not in nodes:err('hub_split_unknown',_x);continue
    _h=[h for h in hubs if _n in h['nodes'] and _f in h['nodes']]
    _g=_x.get('group',True) and nodes[_n].get('group')==nodes[_f].get('group')
    if not _h and not _g:err('hub_split_unused',_x);continue
    for h in _h:
        side=[m for m in h['nodes'] if m!=_f and (m==_n or (m!=_f and _d2(m,_n)<_d2(m,_f)))]
        # 남는 쪽 노드와 같은 group(같은 역)인 노드는 좌표가 가까워도 데려가지 않는다 (新杉田: 杉田(市電)을 떼면서 シーサイドライン 新杉田까지 떨어졌음, 2회차 종합 K06)
        _rg={nodes[m].get('group') for m in h['nodes'] if m not in side}-{None}
        side=[m for m in side if m==_n or nodes[m].get('group') not in _rg]
        h['nodes']=[m for m in h['nodes'] if m not in side]
        if len(side)>1:
            i_='hub_'+sorted(side)[0][2:]
            while i_ in _hid:i_+='_2'
            _hid.add(i_);hubs.append(dict(h,id=i_,nodes=sorted(side)))
    if _g:
        _go=nodes[_n]['group'];_gn='g_'+_n[2:]
        if _gn==_go:
            # 묶음 이름이 떼어 낼 노드에서 왔으면(社尺別) 남는 쪽에 새 이름을 준다. 그대로 두면 아무것도 갈라지지 않는다
            _gn='g_'+_f[2:]
            if any(m.get('group')==_gn for m in nodes.values()):err('hub_split_group_taken',_x);continue
            for m in nodes.values():
                if m.get('group')==_go and m is not nodes[_n]:m['group']=_gn
        else:nodes[_n]['group']=_gn
        if not any(g['id']==_gn for g in groups):groups.append(dict(id=_gn))
hubs=[h for h in hubs if len(h['nodes'])>1]
# 생성기가 놓친 같은 역·연락역을 묶는다 (data/overrides/hub_join.json). group이 참이면 같은 역 묶음까지 (같은 사업자의 같은 역)
# 역 쪼개기(node_split)로 뒤에 생기는 노드는 여기서 묶지 않는다. 그 쌍은 뒤의 환승 쌍 규칙이 원 노드 묶음 후보와 손 표 근거로 다시 본다
_SPLITNEW={x_['new_id'] for x_ in json.load(open(os.path.join(ROOT,'data','overrides','node_split.json'),encoding='utf-8'))}
for _x in json.load(open(os.path.join(ROOT,'data','overrides','hub_join.json'),encoding='utf-8')):
    _n,_w=_x['node'],_x['with']
    if (_n in _SPLITNEW or _w in _SPLITNEW) and not _x.get('group'):continue
    if _n not in nodes or _w not in nodes:
        # source_patch로 더한 역(京津三条)은 보정을 얹지 않는 생성 중 컴파일에는 없다
        if not _nopatch:err('hub_join_unknown',_x)
        continue
    _hn=next((h for h in hubs if _n in h['nodes']),None);_hw=next((h for h in hubs if _w in h['nodes']),None)
    if _hn is not None and _hn is _hw:
        # 생성기 hub에 이미 함께 있어도 손 표는 뒤의 hub_pair 규칙에서 환승 근거(hand)로 쓰인다. group을 합치라는 행만 이미 같으면 쓰이지 않은 것이다
        if not _x.get('group'):continue
        if nodes[_n].get('group')==nodes[_w].get('group'):err('hub_join_unused',_x);continue
    elif _hn and _hw:_hw['nodes']=sorted(set(_hw['nodes'])|set(_hn['nodes']));hubs.remove(_hn)
    elif _hw:_hw['nodes']=sorted(set(_hw['nodes'])|{_n})
    elif _hn:_hn['nodes']=sorted(set(_hn['nodes'])|{_w})
    else:
        i_='hub_'+sorted((_n,_w))[0][2:]
        while i_ in _hid:i_+='_2'
        _hid.add(i_);hubs.append(dict(id=i_,nodes=sorted((_n,_w)),source=['hand'],verified=True))
    if _x.get('group'):nodes[_n]['group']=nodes[_w]['group']
junctions=load('junctions')
# 위키 노선도에서 방향을 잘못 읽은 분기를 사람이 확인해 고친다. 같은 역에 폐지된 옛 선로가 함께 그려진 곳에서 생긴다
# 선로가 이어지지 않는다는 근거 행(hand_tables JUNCTION_NOT, 기간 없는 행)이 있는 (역, 노선 쌍)은 방향 손 행이 연결을 새로 만들지 않는다.
# 방향 손 행은 연결이 있을 때의 그림 방향만 고친다 (勝田線·香椎線 宇美: 따로 떨어진 두 역 시설, 4회차 kyushu_1-004, 11회차 S2)
_JNOT0={(x_['line'],x_['other'],x_.get('at')) for x_ in json.load(open(os.path.join(ROOT,'data','overrides','hand_tables.json'),encoding='utf-8'))['tables']['JUNCTION_NOT']['값'] if x_.get('line') and x_.get('other') and not x_.get('route') and not x_.get('from') and not x_.get('to')}
for _x in json.load(open(os.path.join(ROOT,'data','overrides','junction_side.json'),encoding='utf-8')):
    if any(k_ in _JNOT0 for k_ in ((_x['line'],_x['other'],_x['at']),(_x['other'],_x['line'],_x['at']),(_x['line'],_x['other'],None),(_x['other'],_x['line'],None))):
        WARN['junction_side_not'].append((_x['line'],_x['other'],_x['at']));continue
    _hit=[j for j in junctions if (j['line'],j['other'],j.get('at'))==(_x['line'],_x['other'],_x['at'])]
    # 위키에 분기 기록이 없는 연결은 사람이 확인한 값으로 만든다
    if not _hit:
        _hit=[dict(line=_x['line'],other=_x['other'],at=_x['at'],source='hand',verified=True,valid=[None,'ongoing'])]
        junctions.append(_hit[0])
    for j in _hit:
        j['side']=_x['side'];j['_hand_side']=True
        # 방면 역(선택): toward는 상대 노선에서 곧장 가는 쪽 역, own_toward는 이 노선에서 그 열차가 오는 쪽 역. 역 둘레 선형이 실제 배선과 다를 때 쓴다 (西武 所沢, 10회차 G1 kanto_1-007)
        if _x.get('toward'):j.setdefault('_toward',set()).update(_x['toward'])
        if _x.get('own_toward'):j.setdefault('_own_toward',set()).update(_x['own_toward'])
services=load('services')
# 운행 계통은 판(editions)마다 기간·경로·정차역을 둔다. 판 없는 옛 꼴(parts·valid)은 정차역 없는(모든 역) 판 하나로 읽는다
for _s in services:
    if 'editions' not in _s:_s['editions']=[dict(valid=_s.pop('valid',None) or [None,'ongoing'],parts=_s.pop('parts',[]))]
# 노드를 나눌 때 옮긴 부분과 옮기지 않은 부분에 함께 걸려 둘 다 남긴 정차역. 경로에 없는 쪽은 조용히 뺀다
_svc_split_extra=set()
def _rows_plat():
    from lib import _rows
    return _rows(os.path.join(ROOT,'data','overrides','platforms'))
archive=load('archive')
# 열람 전용 노선 보정: 이미 기록 노선이 있는 중복을 빼고 틀린 폐지일을 고친다. 쓰이지 않는 행은 오류
_af=json.load(open(os.path.join(ROOT,'data','overrides','archive_lines.json'),encoding='utf-8'))
_al={a['id']:a for a in archive if a.get('kind')=='line'}
for _k,_l in _af['drop'].items():
    # source_patch로 더한 기록 노선(東武日光鋼索鉄道線 등)은 보정을 얹지 않는 생성 중 컴파일에 없다
    if _l not in lines and _nopatch:continue
    if _k not in _al or _l not in lines:err('archive_lines_unused',_k)
# 값: {date, legal_abolition?, suspended?}. 휴지 뒤 폐지는 아래 「휴지로 끝난 열람 전용」 규칙이 closed를 휴지 시작으로, 법적 폐지일을 따로 둔다 (결정 128)
def _arch_set(a_,v_):
    a_['closed']=v_['date']
    for k_ in ('legal_abolition','suspended'):
        if v_.get(k_):a_[k_]=v_[k_]
for _k,_v in _af['closed'].items():
    if _k not in _al or (_al[_k].get('closed')==_v['date'] and not _v.get('legal_abolition') and not _v.get('suspended')):err('archive_lines_unused',_k)
    else:_arch_set(_al[_k],_v)
for _k in _af.get('exclude',{}):
    if _k not in _al:err('archive_lines_unused',_k)
# 열람 전용 노선이 붙는 노드. null은 접속 역 없음 (line_at)
for _k,_v in _af.get('line_at',{}).items():
    if _v['node'] is not None and _v['node'] not in nodes:
        if not _nopatch:err('archive_lines_unknown',_k)
        continue
    if _k not in _al or _al[_k].get('at')==_v['node']:err('archive_lines_unused',_k)
    else:_al[_k]['at']=_v['node']
# 열람 전용 역: 이름으로 다른 노선에 복사된 중복을 빼고(drop_stop), 휴지 해가 들어간 폐지일을 고친다(stop_closed)
_as={a['id']:a for a in archive if a.get('kind')=='stop'}
for _k in _af.get('drop_stop',{}):
    if _k not in _as:err('archive_lines_unused',_k)
for _k,_v in _af.get('stop_closed',{}).items():
    if _k not in _as or (_as[_k].get('closed')==_v['date'] and not _v.get('legal_abolition') and not _v.get('suspended')) or _k in _af.get('drop_stop',{}):err('archive_lines_unused',_k)
    else:_arch_set(_as[_k],_v)
# 원천에 개업일이 빈 열람 전용 역의 개업일(stop_opened. 鬼怒大瀞 1930-07-06)
for _k,_v in _af.get('stop_opened',{}).items():
    if _k not in _as or _as[_k].get('opened')==_v['date'] or _k in _af.get('drop_stop',{}):err('archive_lines_unused',_k)
    else:_as[_k]['opened']=_v['date']
# 원천에 개업일이 빈 열람 전용 노선의 개업일(line_opened. 蹴上線 1895-04-01·南海 大浜支線 1912-04-01, 12회차 M R6)
for _k,_v in _af.get('line_opened',{}).items():
    if _k not in _al or _al[_k].get('opened')==_v['date']:err('archive_lines_unused',_k)
    else:_al[_k]['opened']=_v['date']
archive=[a for a in archive if not(a.get('kind')=='line' and (a['id'] in _af['drop'] or a['id'] in _af.get('exclude',{})))
    and not(a.get('kind')=='stop' and a['id'] in _af.get('drop_stop',{}))]
# 휴지로 끝난 열람 전용 역·노선 (DESIGN §2.2 「운행을 다시 시작하지 않고 끝난 휴지」, 사용자 결정 128). 휴지 기록(suspended: 휴지 시작)이 있으면
# closed는 휴지 시작(마지막 운행 다음 날)이고 원래 폐지일은 법적 폐지일(legal_abolition)로 따로 둔다. 법적 폐지일만 따로 준 행은 closed 그대로
for a_ in archive:
    sp_=a_.pop('suspended',None)
    if not sp_:continue
    if a_.get('closed') and not a_.get('legal_abolition') and a_['closed']!=sp_:a_['legal_abolition']=a_['closed']
    a_['closed']=sp_
LINES_JA=json.load(open(os.path.join(ROOT,'data','overrides','lines_ja.json'),encoding='utf-8'))
LINES_EN=json.load(open(os.path.join(ROOT,'data','overrides','lines_en.json'),encoding='utf-8'))
names=load('names')
aliases=load('aliases')
# 일본어 표시 이름은 일본어 위키 문서 제목을 따른다 (広島電鉄本線, 都電荒川線, 札幌市電苗穂線. 사용자 결정 2026-11-07).
# 공식 노선명은 official 별칭으로 남겨 찾기·가져오기·내보내기가 쓴다 (data/overrides/lines_ja.json, docs/research/ja-display-2026-11-07.md)
for _x in names:
    if _x['entity_type']=='line' and _x['lang']=='ja' and not _x.get('line') and not _x.get('valid_to') and _x['id'] in LINES_JA:
        aliases.append(dict(entity_type='line',id=_x['id'],lang='ja',text=_x['text'],kind='official'));_x['text']=LINES_JA[_x['id']]
if not _nopatch:
    for _k in set(LINES_JA)-{x['id'] for x in names if x['entity_type']=='line'}:err('lines_ja_unknown',_k)
# 영어 표시 이름은 공식 영문 사명 + 노선 (Sanyo Electric Railway Aboshi Line, Tokyo Metro Tozai Line). JR과 공식 영문에 회사가 없는 노선은 그대로
# (사용자 결정 2026-11-07, data/overrides/lines_en.json, docs/research/reaudit-2026-11-07.md D09·D10)
for _x in names:
    if _x['entity_type']=='line' and _x['lang']=='en' and not _x.get('line') and not _x.get('valid_to') and _x['id'] in LINES_EN:
        aliases.append(dict(entity_type='line',id=_x['id'],lang='en',text=_x['text'],kind='official'));_x['text']=LINES_EN[_x['id']]
if not _nopatch:
    for _k in set(LINES_EN)-{x['id'] for x in names if x['entity_type']=='line' and x['lang']=='en'}:err('lines_en_unknown',_k)
# 같은 사업자(가족)·같은 종류(노면전차·지하철 등) 노선의 이름 머리를 하나로 맞춘다(2회차 결정 U08). 손 표(lines_ja·lines_en)가 「머리 + 생성 이름」 꼴로 바꾼 노선들의
# 공통 머리(名古屋市電·横浜市電·都電·仙台市電·熊本市電·山陽電気軌道·阪神·東急·西鉄)를, 손 표가 없어 머리 없이 남은 같은 가족·종류 노선(笹島線·赤羽線·北仙台線·戸畑線)에도 붙인다.
# 한국어는 생성기가 이미 사업자 머리를 붙인다 (3회차 chubu_3-19·kanto_1-016·tohoku_1-015·kyushu_2-14, 8회차 W1b)
def _unify_prefix(lang_,table_):
    raw_={x['id']:x['text'] for x in aliases if x['entity_type']=='line' and x['lang']==lang_ and x.get('kind')=='official'}
    cur_={x['id']:x for x in names if x['entity_type']=='line' and x['lang']==lang_ and not x.get('line') and not x.get('valid_from') and not x.get('valid_to')}
    grp_=collections.defaultdict(list)
    for l_,v_ in lines.items():grp_[(v_.get('family'),v_.get('type'))].append(l_)
    added=[]
    for (f_,t_),ls_ in sorted(grp_.items(),key=str):
        if t_ not in ('tram','trolley','subway','monorail','agt') or len(ls_)<2:continue
        ps_=[table_[l_][:-len(raw_[l_])] for l_ in ls_ if l_ in table_ and l_ in raw_ and table_[l_].endswith(raw_[l_]) and len(table_[l_])>len(raw_[l_])]
        if not ps_:
            # 손 표가 없는 가족·종류(福島交通 保原線·掛田線·梁川線·飯坂東線): 한국어 이름이 모두 사업자 머리로 시작하면 일본어·영어도 사업자 이름 머리
            op_='o_'+(f_ or '')[1:]
            oj_=next((x['text'] for x in names if x['entity_type']=='operator' and x['id']==op_ and x['lang']==lang_ and not x.get('valid_from')),None)
            ok_=next((x['text'] for x in names if x['entity_type']=='operator' and x['id']==op_ and x['lang']=='ko' and not x.get('valid_from')),None)
            kos_=[next((x['text'] for x in names if x['entity_type']=='line' and x['id']==l_ and x['lang']=='ko' and not x.get('line') and not x.get('valid_from') and not x.get('valid_to')),'') for l_ in ls_]
            if not oj_ or not ok_ or not all(k_.startswith(ok_+' ') for k_ in kos_):continue
            ps_=[re.sub(r'^株式会社|株式会社$','',oj_)+('' if lang_=='ja' else ' ')]
        p_=os.path.commonprefix(ps_)
        if lang_=='en':p_=p_[:p_.rfind(' ')+1] if ' ' in p_ else ''
        if len(p_)<2:continue
        for l_ in ls_:
            x=cur_.get(l_)
            if not x or l_ in table_ or x['text'].startswith(p_.strip()):continue
            if any(y['text']==p_+x['text'] for k2,y in cur_.items() if k2!=l_):continue
            # 영어는 일본어에도 사업자 머리가 있는 노선만 (세 언어 같은 꼴, tohoku_1-031(7))
            if lang_=='en' and l_ not in LINES_JA and not any(a_['entity_type']=='line' and a_['id']==l_ and a_['lang']=='ja' and a_.get('kind')=='official' for a_ in aliases):continue
            aliases.append(dict(entity_type='line',id=l_,lang=lang_,text=x['text'],kind='official'));x['text']=p_+x['text'];added.append((l_,x['text']))
            if lang_=='ja' and x.get('kana') and p_ in PREFIX_KANA:x['kana']=PREFIX_KANA[p_]+x['kana']
    return added
PREFIX_KANA=dict(HT.get('PREFIX_KANA',[]))
_UP={lg:_unify_prefix(lg,tb) for lg,tb in (('ja',LINES_JA),('en',LINES_EN))}
WARN['line_prefix_unified']=[(k,)+tuple(x) for k,v in _UP.items() for x in v]
print('사업자 머리를 맞춘 노선 이름',{k:len(v) for k,v in _UP.items()})
# 노리츠부시 표의 계통 km. 사이트 내부 값이라 공개 데이터에 없고 로컬 후보 폴더에 있을 때만 대조한다
_n=os.path.join(CAND,'n_routes.json')
NROUTE=json.load(open(_n,encoding='utf-8')) if os.path.exists(_n) else {}
for e in edges.values():
    if e['a'] not in nodes or e['b'] not in nodes:err('edge_node',e['id'])
    if e['id'] not in kms:err('edge_no_km',e['id'])
# 칸 사이에 끼우는 노드·합치는 노드 (data/overrides/edge_insert.json, 5번 결정 junction-nodes-rule 2026-11-20).
# insert: 본선 칸(edge) 위의 분기점을 그 칸에 끼운다. 칸을 a–node, node–b 둘로 나누고 노선(seed_line)·전용 계통(route_only)은 그대로,
# km는 선형 위 투영 비율로 나눈다(공식 km가 아니므로 km 추정 표시). 사건(개업·폐지)은 역 사이 경로로 걸리므로 나눈 칸에도 그대로 걸린다.
# merge: 연락선 끝이 역 승강장에서 끝나면(西武 連絡線 御花畑, 近鉄 八木連絡線 八木西口=大和八木) 끝 노드를 그 역 노드로 합친다
EDGE_INSERT=json.load(open(os.path.join(ROOT,'data','overrides','edge_insert.json'),encoding='utf-8'))['rows']
_EI_GEO={};EI_EST=set();_MERGE_PT=[]
_geo0={g_['edge']:g_ for g_ in load_geo()}
def _proj_frac(coords,pt):
    """선형 위에서 점에 가장 가까운 자리까지의 길이 비율과 그 자리(좌표 목록을 둘로 나눔)"""
    seg=[];tot=0.0
    for (x1,y1),(x2,y2) in zip(coords,coords[1:]):
        L=math.hypot((x2-x1)*91000,(y2-y1)*111000);seg.append(L);tot+=L
    best=(1e18,0.0,0,(coords[0][0],coords[0][1]))
    acc=0.0
    for i,((x1,y1),(x2,y2)) in enumerate(zip(coords,coords[1:])):
        dx,dy=(x2-x1)*91000,(y2-y1)*111000;L2=dx*dx+dy*dy
        t=0.0 if L2==0 else max(0.0,min(1.0,((pt[0]-x1)*91000*dx+(pt[1]-y1)*111000*dy)/L2))
        px,py=x1+(x2-x1)*t,y1+(y2-y1)*t
        d=math.hypot((pt[0]-px)*91000,(pt[1]-py)*111000)
        if d<best[0]:best=(d,(acc+seg[i]*t)/tot if tot else 0.0,i,(px,py))
        acc+=seg[i]
    return best
for x_ in EDGE_INSERT:
    if x_.get('merge'):
        o_,n_=x_['merge'],x_['into']
        if (o_ not in nodes or n_ not in nodes) and _nopatch:continue
        if o_ not in nodes or n_ not in nodes or not x_.get('why'):err('edge_insert_bad',x_);continue
        for e in edges.values():
            for k_ in ('a','b'):
                if e[k_]==o_:e[k_]=n_;_MERGE_PT.append((e['id'],k_,n_))
        _ends_=set()
        # 합친 노드가 그 계통에서 승객이 서지 않던 노드(분기점·신호장)였으면 합친 뒤에도 그 계통은 그 역에서 서지 않는다(정차는 그 역 노선의 것):
        # 西武秩父鉄道連絡線 끝 御花畑, 近鉄八木連絡線 끝 大和八木(八木西口 승강장). 합치기가 정차 여부를 바꾸면 환승 쌍(西武秩父–御花畑) 등 정차로 읽는 계산이 달라진다
        _ostop_=nodes[o_].get('kind') not in ('signal','junction','pref_boundary','freight')
        for r_ in routes.values():
            if o_ in (r_['from'],r_['to']):
                _ends_.add(r_['id'])
                if not _ostop_:r_.setdefault('nostop',{})[n_]=True
            r_['from']=n_ if r_['from']==o_ else r_['from'];r_['to']=n_ if r_['to']==o_ else r_['to']
        # 그 노드를 끝으로 삼던 계통 이름(「A～B」)의 그 끝 이름도 합친 역 이름으로 바꾼다
        _nm_=lambda i_:{y['lang']:y['text'] for y in names if y['entity_type']=='node' and y['id']==i_ and not y.get('line') and not y.get('valid_from') and not y.get('valid_to')}
        _on_,_nn_=_nm_(o_),_nm_(n_)
        for y in names:
            if y['entity_type']=='route' and y['id'] in _ends_ and y['lang'] in _on_ and y['lang'] in _nn_:y['text']=y['text'].replace(_on_[y['lang']],_nn_[y['lang']])
        del nodes[o_]
        # 사건의 구간 표기(「a..b」)·정차 노드도 합친 노드로 옮긴다
        for ev_ in events:
            if ev_.get('edges'):ev_['edges']=['..'.join(n_ if z_==o_ else z_ for z_ in sp_.split('..')) for sp_ in ev_['edges']]
            if ev_.get('node')==o_:ev_['node']=n_
        names[:]=[y for y in names if not (y['entity_type']=='node' and y['id']==o_)]
        positions[:]=[y for y in positions if y['node']!=o_]
        continue
    n_,eid_=x_['node'],x_['edge']
    if (n_ not in nodes or eid_ not in edges) and _nopatch:continue
    if n_ not in nodes or eid_ not in edges or not x_.get('why'):err('edge_insert_bad',x_);continue
    e_=edges[eid_];g_=_geo0.get(eid_);p_=next((p for p in positions if p['node']==n_ and p.get('lat') is not None),None)
    # 생성 중 첫 컴파일(NORIORI_GEN)에는 선형이 아직 없다. 마지막 컴파일에서 끼운다
    if (not g_ or not p_) and _nopatch:continue
    if not g_ or not p_:err('edge_insert_no_geo',x_);continue
    d_,fr_,i_,(px_,py_)=_proj_frac(g_['coords'],(p_['lon'],p_['lat']))
    if d_>60:err('edge_insert_far',(n_,eid_,round(d_)))
    k_=kms[eid_];ka_=dround(k_*fr_)
    new_='e_0966%02d'%(len(_EI_GEO)//2+1)
    if new_ in edges:err('edge_insert_taken',new_);continue
    edges[new_]=dict(e_,id=new_,a=n_,b=e_['b']);e_['b']=n_
    kms[eid_]=ka_;kms[new_]=dround(k_-ka_)
    c_=g_['coords'];_EI_GEO[eid_]=dict(g_,coords=c_[:i_+1]+[[px_,py_]]);_EI_GEO[new_]=dict(g_,edge=new_,coords=[[px_,py_]]+c_[i_+1:])
    EI_EST.add(n_)
print('칸에 끼운 노드',len(_EI_GEO)//2,'합친 노드',sum(1 for x_ in EDGE_INSERT if x_.get('merge')))
# 합친 노드로 끝이 옮겨 간 칸은 선형 끝을 그 역 점까지 잇는다(西武 連絡線 끝 → 御花畑 역 점)
_pos_mg={p_['node']:(p_['lon'],p_['lat']) for p_ in positions if p_.get('lat') is not None}
for e_,k_,n_ in _MERGE_PT:
    g_=_EI_GEO.get(e_) or _geo0.get(e_)
    if not g_ or n_ not in _pos_mg:continue
    pt_=list(_pos_mg[n_]);c_=g_['coords']
    _EI_GEO[e_]=dict(g_,coords=([pt_]+c_) if k_=='a' else (c_+[pt_]))
_load_geo_ei=load_geo
def load_geo():
    return [_EI_GEO.get(x['edge'],x) for x in _load_geo_ei()]+[v for k,v in _EI_GEO.items() if k not in _geo0]
# 나뉜 역 (data/overrides/split_period.json, 사용자 결정 2026-11-16, 11회차 S1): 한 역이 나중에 둘로 나뉘면 나뉘기 전 기간은 한 노드다.
# 행 {a: 그 기간의 역(같이 쓰던 노드), b: 나뉜 뒤의 역, from: 한 역이 된 날(없으면 처음부터), to: 나뉜 날}. [from, to) 동안 b에 서던 계통은 a에 선다.
# b가 서는 노선의 선로(seed) 그래프에 a가 없으면 a를 그 노선 선로에 넣는다: b가 끝이면 a–b 칸을 끝에 붙이고(계통 끝을 a로),
# b가 중간이면 a 쪽 이웃 칸의 b 끝을 a로 바꾸고 a–b 칸을 넣는다. 넣는 a–b 칸은 같은 km 점(0 km)이다: 나뉘기 전 그 노선의 공식 km는
# 하나의 역 자리였고 두 승강장 사이 거리는 営業キロ에 없다. 칸 기간·소속은 사건 처리 뒤 이웃 칸의 행을 [from, to)로 잘라 옮긴다.
# 정차는 아래(역 이전 다음)에서 b의 [from, to)를 a로 옮긴다. a가 이미 그 노선 선로에 있으면(丹波橋 옛 경로 계통) 칸은 넣지 않고 정차만 옮긴다
_SPLITP=json.load(open(os.path.join(ROOT,'data','overrides','split_period.json'),encoding='utf-8'))
SPLITP_EDGE={}   # 넣은 a–b 칸 -> (행 번호, 이웃 칸)
SPLITP_ROUTE={}  # 계통 끝을 a로 바꾼 계통 -> 행 번호
_SPLITP_GEO=[]
_pos0={p_['node']:p_ for p_ in positions}
def _d_sp(x_,y_):
    p_,q_=_pos0.get(x_),_pos0.get(y_)
    if not p_ or not q_ or p_.get('lat') is None or q_.get('lat') is None:return 1e9
    return math.hypot((p_['lat']-q_['lat'])*111000,(p_['lon']-q_['lon'])*91000)
_spn=0
for i_,x_ in enumerate(_SPLITP):
    a_,b_=x_['a'],x_['b']
    # 같은 꼴 후보(감사 K190)를 보고 한 역이 나뉜 것이 아니라고 판정한 쌍(normal: 사유)은 감사 목록에서만 뺀다
    if x_.get('normal'):continue
    # 보정 행(source_patch)으로 더한 노드(京津三条)는 보정을 얹지 않는 생성 중 컴파일에 없다
    if (a_ not in nodes or b_ not in nodes) and _nopatch:continue
    if a_ not in nodes or b_ not in nodes or not x_.get('to') or not x_.get('why'):err('split_period_bad',(a_,b_));continue
    sl_={e['seed_line'] for e in edges.values() if b_ in (e['a'],e['b']) and e.get('seed_line') and not e.get('alt') and not e.get('route_only')}
    for l_ in sorted(sl_):
        se_=[e for e in edges.values() if e.get('seed_line')==l_ and not e.get('alt')]
        if any(a_ in (e['a'],e['b']) for e in se_):continue
        nb_=[e for e in se_ if b_ in (e['a'],e['b']) and not e.get('route_only')]
        if not nb_:continue
        _spn+=1;eid_='e_0963%02d'%_spn
        if eid_ in edges:err('split_period_edge_taken',eid_);continue
        if len(nb_)==1:
            src_=nb_[0]
            for r_ in routes.values():
                if r_['line']==l_ and b_ in (r_['from'],r_['to']):
                    r_['from']=a_ if r_['from']==b_ else r_['from'];r_['to']=a_ if r_['to']==b_ else r_['to'];SPLITP_ROUTE[r_['id']]=i_
        else:
            # a 쪽 이웃: 그 칸의 먼 끝이 b보다 a에 가까운 칸
            _far_=lambda e:e['b'] if e['a']==b_ else e['a']
            src_=min(nb_,key=lambda e:_d_sp(_far_(e),a_)-_d_sp(_far_(e),b_))
            for k_ in ('a','b'):
                if src_[k_]==b_:src_[k_]=a_
        edges[eid_]=dict(id=eid_,a=a_,b=b_,seed_line=l_);kms[eid_]=0.0
        SPLITP_EDGE[eid_]=(i_,src_['id'],len(nb_)>1)
        if a_ in _pos0 and b_ in _pos0:_SPLITP_GEO.append(dict(edge=eid_,source='split_period',coords=[[_pos0[a_]['lon'],_pos0[a_]['lat']],[_pos0[b_]['lon'],_pos0[b_]['lat']]]))
print('나뉜 역 기간 칸',len(SPLITP_EDGE),sorted((k_,)+v_[1:] for k_,v_ in SPLITP_EDGE.items()))
# 넣은 칸의 선형은 두 노드 좌표를 잇는 직선이다(같은 km 점, 생성 선형이 있으면 그것)
_load_geo0=load_geo
def load_geo():
    g_=_load_geo0();have_={x['edge'] for x in g_}
    return g_+[x for x in _SPLITP_GEO if x['edge'] not in have_]

adj=collections.defaultdict(list)
for e in edges.values():
    adj[e['a']].append(e);adj[e['b']].append(e)
def other(e,n):return e['b'] if e['a']==n else e['a']

def key(ev):
    lo,hi=lohi(ev.get('date'))
    # 날짜가 불확실한 재개(1953-XX-XX)는 그 범위의 끝으로 정렬한다. 하한으로 두면 같은 해의 휴지보다 먼저 와서 휴지가 폐지까지 이어진다
    if ev['type']=='resume' and lo!=hi:lo=hi
    return (lo or '0000-00-00',{'open':0,'relocate':1,'transfer':2,'close':3}.get(ev['type'],4))
events.sort(key=key)
NOOP=collections.defaultdict(list)  # 효과 없는 휴지·재개 (DB 감사 D1)

attr=[]     # 집계 멤버십
active=collections.defaultdict(list)  # edge -> 살아 있는 attr
life=[]     # edge_life
live={}     # edge -> 현재 life row
stopev=collections.defaultdict(list)  # (route,node) -> 사건
kmch=collections.defaultdict(list)
carryseq=[0];lineseq=[0];hidseq=[0,0]
def newc():
    carryseq[0]+=1;return f'c{carryseq[0]}'
def newl():
    lineseq[0]+=1;return f'lg{lineseq[0]}'
JR={o for o,v in ops.items() if v.get('category')=='jr'}

def scope_edges(line,route=None,mode='seed',alt=None):
    S=[]
    owned=bool(route and routes.get(route,{}).get('owned'))
    also=set(routes.get(route,{}).get('also',[])) if route else set()
    for e in edges.values():
        if alt!=e.get('alt'):continue
        ro=e.get('route_only')
        if route:
            if ro!=route and not (ro is None and (not owned or e['id'] in also)):continue
        elif ro:continue
        if mode=='seed':
            if e.get('seed_line')==line:S.append(e)
        else:
            if any(a['line']==line for a in []) or any(a['line_id']==line for a in active[e['id']]):S.append(e)
    return S

def path(a,b,S):
    if a==b:return []
    g=collections.defaultdict(list)
    for e in S:g[e['a']].append(e);g[e['b']].append(e)
    pq=[(0,a)];best={a:0};prev={}
    while pq:
        d,n=heapq.heappop(pq)
        if n==b:break
        if d>best.get(n,1e12):continue
        for e in g[n]:
            m=other(e,n);nd=d+kms.get(e['id'],0)+1e-4
            if nd<best.get(m,1e12):best[m]=nd;prev[m]=(n,e);heapq.heappush(pq,(nd,m))
    if b not in prev:return None
    o=[];n=b
    while n!=a:
        p,e=prev[n];o.append(e['id']);n=p
    return o[::-1]

_cache={}
def resolve(ev,specs,line,mode):
    out=[]
    for sp in specs:
        if sp in edges:out.append(sp);continue
        m=re.match(r'^(n_[^.@]+)\.\.(n_[^.@]+)(?:@(\w+))?$',sp)
        if not m:err('bad_range',sp);continue
        a,b,alt=m.groups()
        sl_=ev.get('_scope_line') or line if mode=='seed' else line
        k=(sl_,ev.get('route'),mode,alt)
        S=scope_edges(sl_,ev.get('route'),mode,alt) if mode=='member' else _cache.setdefault(k,scope_edges(sl_,ev.get('route'),mode,alt))
        p=path(a,b,S)
        if p is None and not ev.get('route'):
            # 지선 계통 전용 선로(route_only)는 계통을 적지 않으면 빠진다. 그 노선 모든 계통의 선로를 합쳐 찾는다
            # (鶴見線 大川支線, 菊池線 옛 선로처럼 두 계통에 걸친 구간). 그날 노선에 속한 선로만 들어 있어 그날의 경로가 나온다
            U={e['id']:e for r_,v_ in routes.items() if v_['line']==line for e in scope_edges(line,r_,mode,alt)}
            p=path(a,b,list(U.values()))
        if p is None:
            err('range_unresolved',{'ev':ev.get('type'),'date':ev.get('date'),'spec':sp,'line':line});continue
        out+=p
    return out

def start(eid,line,op,date,lineage=None,carry=None,cls=None):
    l=lines[line]
    # 분모 밖 계통(화물·연결선을 모선의 지선으로 둔 것)의 전용 칸은 노선이 normal이어도 분모 밖이다
    ro=(edges.get(eid) or {}).get('route_only')
    if not cls and ro and (routes.get(ro) or {}).get('extra'):cls='extra'
    cls=cls or {'extra':'extra','hidden':'hidden'}.get(l.get('rule_class'),'normal')
    # 숨은 화물선(hidden)은 분모 단위가 없다. 계보·이관 묶음 번호를 따로 매겨 다른 칸의 번호(분모 단위 열쇠)가 밀리지 않게 한다 (9회차 F)
    if cls=='hidden':
        if not lineage:hidseq[0]+=1;lineage=f'lh{hidseq[0]}'
        if not carry:hidseq[1]+=1;carry=f'ch{hidseq[1]}'
    a=dict(edge_id=eid,line_id=line,operator_id=op,lineage_id=lineage or newl(),carryover_group=carry or newc(),denominator_class=cls,valid_from=date,valid_to='ongoing')
    attr.append(a);active[eid].append(a);return a
def stop(a,date):
    a['valid_to']=date
    if a in active[a['edge_id']]:active[a['edge_id']].remove(a)
def life_open(eid,date):
    if eid in live:return
    r=dict(edge_id=eid,valid_from=date,valid_to='ongoing',status='open',last_service=None,legal_abolition=None,close_reason=None)
    life.append(r);live[eid]=r
def life_close(eid,date,ev):
    r=live.pop(eid,None)
    if r:
        r['valid_to']=date;r['last_service']=ev.get('last_service');r['legal_abolition']=ev.get('legal_abolition') or (None if ev.get('reason')=='no_regular_service' else ev.get('date'));r['close_reason']=ev.get('reason','abolished')
        # 옛 선로를 닫는 사건에 새 선로와 함께 쓴 기간의 근거(overlap)가 있으면 남긴다: 병용(近鉄 丹波橋 1967~1968 두 경로 併用)·과도기(이설 전환 며칠).
        # {from: 새 선로 영업 시작, kind: 병용|과도기|방향별, why, evidence}. 방향별은 새 선로가 열린 뒤 한 방향만 옛 선로에 남은 기간(豊橋 東田本線 神明–市役所前 1950-07-15~1951-10-30 上り만).
        # 이설 이중 영업 검사(audit_db K19)가 이 기간을 허용한다 (2회차 종합 K19)
        if ev.get('overlap'):
            ov_=ev['overlap']
            if not isinstance(ov_,dict) or not ov_.get('from') or not ov_.get('why') or ov_.get('kind') not in ('병용','과도기','방향별'):err('overlap_bad',(eid,ov_))
            else:r['overlap']=ov_
for ev in events:
    t=ev['type'];d=ev.get('date')
    if t=='open':
        es=resolve(ev,ev['edges'],ev['line'],'seed')
        prev=None
        if ev.get('continues'):
            prev=ev['continues']
        for x in es:
            lin=None;car=None
            # 같은 노선이 닫혔던 칸을 다시 열면(같은 노선의 부활: 鹿島臨港線 1983 여객 폐지 → 2005 하루 臨時) continues를 적지 않아도 같은 계보다(DESIGN §2.8 E 「같은 노선의 부활은 값을 유지」).
            # 계보가 둘로 갈리면 역대 분모에 같은 칸이 두 번 들어간다 (9회차 S)
            if not prev and not active[x] and any(a['edge_id']==x and a['line_id']==ev['line'] for a in attr):prev_=ev['line']
            else:prev_=prev
            if prev_:
                old=[a for a in attr if a['edge_id']==x and a['line_id']==prev_]
                if old:
                    lin=old[-1]['lineage_id']
                    po=ops.get(old[-1]['operator_id'],{}).get('category');no=ops.get(ev['operator'],{}).get('category')
                    car=None if (po=='jr' and no!='jr') else old[-1]['carryover_group']
            start(x,ev['line'],ev['operator'],d,lin,car,ev.get('class'))
            life_open(x,d)
    elif t=='close':
        es=resolve(ev,ev['edges'],ev['line'],'member')
        vt=ev.get('valid_to') or d
        for x in es:
            for a in [a for a in active[x] if a['line_id']==ev['line']]:stop(a,vt)
            if not active[x]:life_close(x,vt,ev)
    elif t=='transfer':
        fr=ev.get('from');to=ev.get('to')
        line=(fr or {}).get('line') or ev.get('within')
        es=resolve(ev,ev['edges'],line,'member')
        for x in es:
            old=None
            if fr:
                for a in [a for a in active[x] if a['line_id']==fr['line'] and a['operator_id']==fr['operator']]:
                    old=a;stop(a,d)
                if not old:err('transfer_no_from',{'edge':x,'from':fr,'date':d})
            if to:
                if old:
                    po=ops[old['operator_id']].get('category');no=ops[to['operator']].get('category')
                    car=newc() if (po=='jr' and no!='jr') else old['carryover_group']
                    start(x,to['line'],to['operator'],d,old['lineage_id'],car,old['denominator_class'])
                else:
                    start(x,to['line'],to['operator'],d,None,None,ev.get('class'))
                life_open(x,d)
            elif not active[x]:
                life_close(x,d,ev)
    elif t=='relocate':
        for x in resolve(ev,ev['close'],ev['line'],'member'):
            for a in [a for a in active[x] if a['line_id']==ev['line']]:stop(a,d)
            if not active[x]:
                life_close(x,d,dict(ev,reason='relocated'))
        for x in resolve(ev,ev['open'],ev['line'],'seed'):
            start(x,ev['line'],ev['operator'],d);life_open(x,d)
    elif t=='suspend':
        for x in resolve(ev,ev['edges'],ev['line'],'member'):
            r=live.get(x)
            # 공용 선로 칸(SHARED_TRACK)은 노선마다 같은 날 운휴 사건을 낸다. 같은 날 이미 운휴로 바뀐 칸은 같은 사건이다
            if r and r['status']=='suspended' and r['valid_from']==d:continue
            if r and r['status']=='suspended':NOOP['suspend'].append((x,d))
            # 연 날 바로 운휴면(梅田貨物線 吹田貨物ターミナル–新大阪: 여객 영업 없음) 길이 0 행을 남기지 않고 그 행을 운휴로 바꾼다
            if r and r['valid_from']==d:r['status']='suspended';r['_short_ok']=ev.get('short_ok');continue
            if r:r['valid_to']=d;live[x]=dict(r,valid_from=d,valid_to='ongoing',status='suspended',_short_ok=ev.get('short_ok'));life.append(live[x])
    elif t=='planned_close':
        # 확정된 미래 폐지일 (사용자 결정 2026-11-07). 오늘 상태는 그대로 두고 지금 수명 행에 법적 폐지 예정일만 적는다
        if d<=AS_OF:err('planned_close_past',ev)
        for x in resolve(ev,ev['edges'],ev['line'],'member'):
            r=live.get(x)
            if r:r['legal_abolition']=d
            else:err('planned_close_not_live',(x,d))
    elif t=='resume':
        for x in resolve(ev,ev['edges'],ev['line'],'member'):
            r=live.get(x)
            if r and r['status']=='open' and r['valid_from']==d:continue
            if r and r['status']!='suspended':NOOP['resume'].append((x,d))
            if r and r['valid_from']==d:r['status']='open';continue
            if r:r['valid_to']=d;live[x]=dict(r,valid_from=d,valid_to='ongoing',status='open');life.append(live[x])
    elif t=='set_class':
        for x in resolve(ev,ev['edges'],ev['line'],'member'):
            for a in [a for a in active[x] if a['line_id']==ev['line']]:
                stop(a,d);start(x,a['line_id'],a['operator_id'],d,a['lineage_id'],a['carryover_group'],ev['class'])
    elif t in('open_stop','close_stop'):
        stopev[(ev['route'],ev['node'])].append(ev)
    elif t=='km_change':
        for x in ev['edges']:kmch[x].append(ev)
    elif t=='rename':pass
    else:err('unknown_event',t)
# 같은 노선 안에서 사업자만 바뀌는 이관(사명 변경·합병: 京阪神急行電鉄→阪急電鉄 1973, 三重交通→三重電気鉄道→近鉄)은 그날 그 노선을 옛 사업자로 영업하던 칸 전부에 미친다.
# 표의 구간 범위가 뒤에 닫힌 끝 칸(今津–今津（旧）, 西桑名（旧）–西桑名)을 빠뜨려 옛 사업자로 남은 행을 그날에서 갈라 새 사업자로 잇는다.
# 그날 그 노선의 옛 사업자 이관이 모두 한 사업자로 갈 때만 (국철→JR 여러 회사처럼 갈래가 나뉘면 손대지 않음) (3회차 kinki_1-15·kinki_1-19, 8회차 W1b)
_XT=collections.defaultdict(set)
for ev in events:
    if ev['type']=='transfer' and ev.get('from') and ev.get('to') and ev['from'].get('line')==ev['to'].get('line') and ev['from'].get('operator')!=ev['to'].get('operator'):
        _XT[(ev['from']['line'],ev['date'],ev['from']['operator'])].add(ev['to']['operator'])
_xtn=[]
for (l_,d_,fo_),tos_ in sorted(_XT.items()):
    if len(tos_)!=1 or not re.fullmatch(r'\d{4}-\d\d-\d\d',d_ or ''):continue
    to_=next(iter(tos_))
    for a in [a for a in attr if a['line_id']==l_ and a['operator_id']==fo_]:
        lo_=lohi(a['valid_from'])[1] or '0000';hi_=(lohi(a['valid_to'])[0] or '9999-12-31') if a['valid_to'] not in (None,'ongoing') else '9999-12-31'
        if lo_<d_<hi_:
            po=ops.get(fo_,{}).get('category');no=ops.get(to_,{}).get('category')
            b=dict(a,operator_id=to_,valid_from=d_,carryover_group=newc() if (po=='jr' and no!='jr') else a['carryover_group'])
            a['valid_to']=d_;attr.append(b);_xtn.append((l_,a['edge_id'],d_,fo_,to_))
WARN['transfer_whole_line']=_xtn
print('같은 노선 사업자 바뀜을 빠진 칸에도 적용',len(_xtn))
# 운휴 수록 기준 (DESIGN §17 「운휴 수록 기준」, 2회차 종합 K35): 30일 넘게 온종일 닫힌 운휴만 넣는다. 30일이 안 돼 재개한 운휴는
# 앞뒤 영업 행과 합쳐 없애고 build/report.json warnings short_suspension_dropped에 남긴다. 재개 없이 폐지·이관으로 끝난 운휴는 영업의 끝이라 그대로 둔다.
# 짧아도 남길 운휴(규칙 밖 사실)는 suspend 사건에 short_ok(사유)를 적는다
import datetime as _dt0
def _days(f,t):
    try:return (_dt0.date.fromisoformat(t)-_dt0.date.fromisoformat(f)).days
    except (TypeError,ValueError):return None
_lby=collections.defaultdict(list)
for r_ in life:_lby[r_['edge_id']].append(r_)
_drop=set()
for e_,v_ in _lby.items():
    i_=0
    while i_<len(v_)-1:
        r_,n_=v_[i_],v_[i_+1]
        d_=_days(r_['valid_from'],r_['valid_to']) if r_['status']=='suspended' and n_['status']=='open' and n_['valid_from']==r_['valid_to'] else None
        if d_ is None or d_>=30 or r_.get('_short_ok'):i_+=1;continue
        p_=v_[i_-1] if i_>0 and v_[i_-1]['status']=='open' and v_[i_-1]['valid_to']==r_['valid_from'] else None
        keep_=p_ or r_
        WARN['short_suspension_dropped'].append((e_,r_['valid_from'],r_['valid_to'],d_))
        keep_.update(status='open',valid_to=n_['valid_to'],last_service=n_['last_service'],legal_abolition=n_['legal_abolition'],close_reason=n_['close_reason'])
        gone_=[n_]+([r_] if p_ else [])
        _drop|={id(x_) for x_ in gone_}
        for x_ in gone_:v_.remove(x_)
        if any(live.get(e_) is x_ for x_ in gone_):live[e_]=keep_
        i_=max(i_-1,0)
life=[r_ for r_ in life if id(r_) not in _drop]
for r_ in life:r_.pop('_short_ok',None)
print('30일 안에 재개해 지운 운휴',len(WARN['short_suspension_dropped']),sorted({(x[1],x[2]) for x in WARN['short_suspension_dropped']}))
# 운행을 다시 시작하지 않고 끝난 휴지 (DESIGN §2.2, 사용자 결정 122, 2026-11-12). 운휴(suspended) 뒤 재개 없이 닫힌 칸은 마지막 운행 다음 날(운휴 시작)로
# 소급해 닫는다: 영업 행 끝 = 운휴 시작, last_service = 그 전날(이미 있으면 둠), legal_abolition = 원래 닫힌 날(이미 있으면 둠).
# 폐지 사유 abolished는 no_regular_service로 바꾸고 brt·relocated는 그대로 둔다. 그 기간의 노선 소속 행(edge_attr)도 운휴 시작에서 끝낸다.
# 법적 폐지일이 닫힌 날보다 늦은 abolished도 no_regular_service다(생성기·n05_fix·old_history의 close 행 휴지 시작·법적 폐지 값이 이 길로 온다)
_lby=collections.defaultdict(list)
for r_ in life:_lby[r_['edge_id']].append(r_)
_attr_by=collections.defaultdict(list)
for a_ in attr:_attr_by[a_['edge_id']].append(a_)
_s2c=[];_drop=set();_adrop=set()
for e_,v_ in _lby.items():
  # 행은 사건 순서(시간 순)로 붙어 있다. 날짜를 모르는 재개 행(山鹿温泉鉄道 1953)이 있어 날짜로 다시 정렬하지 않는다.
  # 마지막 행만이 아니라 중간의 「운휴 → 닫힘」 행도 같은 규칙이다: 폐지 뒤 같은 칸이 다시 열린 꼴(八栗ケーブル: 1944 휴지 → 1960 폐지 → 1964 재개업)은
  # 닫힌 운휴 행 뒤에 새 영업 행이 있다. 그 운휴 기간 안의 소속 행만 당기고, 다시 연 뒤의 행은 그대로 둔다 (9회차 S)
  for zi_ in range(len(v_)):
    z_=v_[zi_]
    # 지금 운휴 중인데 폐지일이 정해진 칸(planned_close: 津軽線 蟹田–三厩 2022-08-04 운휴, 2027-04-01 폐지)도 공식 폐지일이 정해졌으므로 같은 규칙이다
    planned_=zi_==len(v_)-1 and z_['status']=='suspended' and z_['valid_to'] in (None,'ongoing') and z_.get('legal_abolition')
    if not planned_ and (z_['status']!='suspended' or z_['valid_to'] in (None,'ongoing') or not z_.get('close_reason')):continue
    s_,c_=z_['valid_from'],(z_['legal_abolition'] if planned_ else z_['valid_to'])
    # 앞에 영업 행이 있어야 한다. 연 날 바로 운휴였던 칸(여객 영업 없음)은 당길 곳이 없어 그대로 둔다
    p_=v_[zi_-1] if zi_>0 and v_[zi_-1]['status']=='open' and v_[zi_-1]['valid_to']==s_ else None
    if not p_ or s_ is None:continue
    if planned_:z_['close_reason']='abolished'
    # 운휴 중에 시작한 소속 행(운휴 중 이관)만 있으면 운휴 시작 앞의 소속이 없으므로 당기지 않는다. 운휴가 닫힌 뒤(다시 연 뒤)에 시작한 행은 이 운휴와 무관하다
    hi_=(lohi(z_['valid_to'])[0] or '9999') if not planned_ else '9999'
    mine_=[a_ for a_ in _attr_by[e_] if (lohi(a_['valid_from'])[0] or '0000')<hi_]
    in_=[a_ for a_ in mine_ if (lohi(a_['valid_from'])[0] or '0000')<(lohi(s_)[0] or '9999')]
    if not in_:continue
    ls_=z_.get('last_service') or p_.get('last_service')
    if not ls_ and re.fullmatch(r'\d{4}-\d\d-\d\d',s_):ls_=(_dt0.date.fromisoformat(s_)-_dt0.timedelta(days=1)).isoformat()
    p_.update(valid_to=s_,last_service=ls_,legal_abolition=z_.get('legal_abolition') or c_,close_reason='no_regular_service' if z_['close_reason']=='abolished' else z_['close_reason'])
    _drop.add(id(z_));_s2c.append((e_,s_,c_))
    in_ids_={id(a_) for a_ in in_}
    for a_ in mine_:
        if id(a_) not in in_ids_:_adrop.add(id(a_))
        elif a_['valid_to'] in (None,'ongoing') or (lohi(a_['valid_to'])[1] or '9999')>(lohi(s_)[0] or '0000'):a_['valid_to']=s_
attr[:]=[a_ for a_ in attr if id(a_) not in _adrop]
for e_ in active:active[e_]=[a_ for a_ in active[e_] if id(a_) not in _adrop]
life=[r_ for r_ in life if id(r_) not in _drop]
for r_ in life:
    if r_.get('close_reason')=='abolished' and r_.get('legal_abolition') and r_['valid_to'] not in (None,'ongoing') and (lohi(r_['legal_abolition'])[0] or '')>(lohi(r_['valid_to'])[1] or '9999'):r_['close_reason']='no_regular_service'
print('재개 없이 닫힌 운휴를 운휴 시작으로 당김',len(_s2c),_s2c[:8])

def _edge(v,i):
    """범위 안에 넣을 날짜 원문. 이미 범위면 그 하한(i=0)이나 상한(i=1) 날"""
    return lohi(v)[i] if v and v.startswith('[') else (v or '')
def _open_unknown(r):
    """개업일을 모르는 선로는 「폐지 전에는 있었다」로 둔다 (날짜 원칙). 영업 중이면 판 기준일 전"""
    if r['valid_from'] is None:r['valid_from']=f"[..{AS_OF if r['valid_to'] in (None,'ongoing') else _edge(r['valid_to'],1)}]"
# 분모·계통·표가 모두 같은 값을 보도록 사건 처리 직후에 채운다
for r_ in life+attr:_open_unknown(r_)
# 나뉜 역 기간 칸(위 split_period)의 기간·소속: 이웃 칸의 그 노선 행을 [from, to)로 잘라 옮긴다. 사건 범위(n_x..n_y)가 이 칸을 지나는지와 상관없이 같다
def _sp_lo(v):return '0000-00-00' if not v else (lohi(v)[0] or '0000-00-00')
def _sp_hi(v):return '9999-12-31' if v in (None,'ongoing') else (lohi(v)[1] or '9999-12-31')
def _sp_clip(rows_,f_,t_):
    out_=[]
    for r_ in rows_:
        if _sp_lo(r_['valid_from'])>=_sp_lo(t_) or (f_ and _sp_hi(r_['valid_to'])<=_sp_lo(f_)):continue
        r_=dict(r_)
        if f_ and _sp_lo(r_['valid_from'])<_sp_lo(f_):r_['valid_from']=f_
        if _sp_hi(r_['valid_to'])>_sp_lo(t_):r_['valid_to']=t_;r_['_split_cut']=1
        out_.append(r_)
    return out_
# 중간 역에 넣은 칸은 노선이 계속 지나가는 선로라 이웃 칸 행을 자르지 않고 그대로 옮긴다(a는 그 기간에만 선다)
for eid_,(i_,src_,mid_) in SPLITP_EDGE.items():
    x_=_SPLITP[i_];l_=edges[eid_]['seed_line'];f_,t_=(None,'9999-12-31') if mid_ else (x_.get('from'),x_['to'])
    attr[:]=[a for a in attr if a['edge_id']!=eid_];life[:]=[r_ for r_ in life if r_['edge_id']!=eid_]
    for a in _sp_clip([a for a in attr if a['edge_id']==src_ and a['line_id']==l_],f_,t_):
        a.pop('_split_cut',None);a['edge_id']=eid_;attr.append(a)
    for r_ in _sp_clip([r_ for r_ in life if r_['edge_id']==src_],f_,t_):
        # 나뉜 날에 끝나는 칸은 폐지가 아니라 역이 둘로 나뉜 것이다
        if r_.pop('_split_cut',None):r_.update(last_service=None,legal_abolition=None,close_reason='relocated')
        r_['edge_id']=eid_;life.append(r_)
    if not any(a['edge_id']==eid_ for a in attr) and not _nopatch:err('split_period_no_attr',(eid_,src_))

# 계통의 edge 묶음과 순서
own=collections.defaultdict(list)
for e in edges.values():
    if e.get('route_only'):own[e['route_only']].append(e)
line_e=collections.defaultdict(set)
for a in attr:line_e[a['line_id']].add(a['edge_id'])
route_edges={};route_rank={};ALT_SCALED={};ROUTE_KM=collections.defaultdict(dict)
def _alt_scale(rid,dist,fixed,S,kmr):
    """두 지금 역 X·Y 사이를 잇는 옛 선로(alt old) 사슬의 역은 X·Y 사이 순서(정렬 값)를 옛 선로 길이 비율로 둔다.
    옛 선로가 지금 선로보다 길거나 짧으면(北陸本線 敦賀–今庄 옛 선로) 옛 km 그대로는 Y 너머로 밀려 순서가 뒤집힌다.
    길이가 같으면(常磐線 新地·坂元·山下) 값이 그대로다. 막다른 옛 선로(女川(旧)·白山(旧))는 그대로 둔다.
    비율 값은 순서에만 쓰고, 화면 km는 실제 옛 営業キロ(갈라지는 역 km + 옛 edge 누적)다 (ROUTE_KM, 2회차 종합 K21)"""
    ga=collections.defaultdict(list)
    for e in S:
        if e.get('alt')=='old':ga[e['a']].append(e);ga[e['b']].append(e)
    rest=[n for n in dist if n not in fixed];seen=set()
    for n0 in rest:
        if n0 in seen:continue
        comp={n0};st=[n0];att=set()
        while st:
            x=st.pop()
            for e in ga[x]:
                y=other(e,x)
                if y in fixed:att.add(y)
                elif y in dist and y not in comp:comp.add(y);st.append(y)
        seen|=comp
        if len(att)!=2:continue
        X,Y=sorted(att,key=lambda v:dist[v])
        # X에서 Y까지 comp만 지나는 한 줄 사슬
        path=[X];prev=None;cur=X;acc={};run=0.0;ok=True
        while cur!=Y:
            nx=[e for e in ga[cur] if other(e,cur)!=prev and (other(e,cur) in comp or (other(e,cur)==Y and cur!=X))]
            if len(nx)!=1:ok=False;break
            e=nx[0];prev,cur=cur,other(e,cur);run+=kmr(e)
            if cur!=Y:acc[cur]=run
        if not ok or set(acc)!=comp or run<=0:continue
        span=dist[Y]-dist[X]
        if abs(run-span)<=.05:continue
        for n,a_ in acc.items():ROUTE_KM[rid][n]=round(dist[X]+a_,3);dist[n]=round(dist[X]+a_/run*span,3)
        ALT_SCALED[(rid,X,Y)]=(round(run,1),round(span,1),len(acc))
for r in routes.values():
    tagged=own.get(r['id'],[])
    if r.get('role')=='branch' or r.get('owned'):
        S=list(tagged)+[edges[x] for x in r.get('also',[])]
    else:
        U=[edges[x] for x in sorted(line_e[r['line']]) if not edges[x].get('route_only') or edges[x]['route_only']==r['id']]
        U=[e for e in U if e.get('alt')!='old']
        pts=[r['from']]+r.get('via',[])+[r['to']]
        p=[]
        for i in range(len(pts)-1):
            q=path(pts[i],pts[i+1],U)
            if q is None:
                err('route_no_path',{'route':r['id'],'from':pts[i],'to':pts[i+1]});q=[]
            p+=q
        S=[edges[x] for x in p]+[e for e in tagged if e['id'] not in p]
    route_edges[r['id']]=S
    tot=sum(kms.get(e['id'],0) for e in S if e.get('alt')!='old')
    nk=NROUTE.get(r['id'],{}).get('km')
    if nk and abs(tot-nk)>.15 and not r.get('also'):WARN['route_km'].append({'route':r['id'],'calc':round(tot,1),'n':nk})
# 3섹 전환 때 営業キロ를 다시 정한 구간의 국철·JR 시대 km (data/overrides/km_era.json, tools/dev/km_era.py).
# 정차역 둘 사이 값을 그 사이 edge에 지금 km 비율로 나눈다. 그 노선(국철·JR)의 멤버십과 그 노선 계통의 누계 km에 쓴다
ERA={}
# 손으로 확인한 구간(km_era_hand.json)은 생성 표(km_era.json)를 다시 만들지 않아도 늘 얹는다. 손 행이 생성 표에 빠져 下北交通 大畑線 시대 km가 안 쓰이던 꼴 (3회차 tohoku_2-001·tohoku_2-002, 8회차 W1b)
_KE=json.load(open(os.path.join(ROOT,'data','overrides','km_era.json'),encoding='utf-8'))
_KEK={(x['line'],x['route'],x['a'],x['b']) for x in _KE}
_KE+=[x for x in json.load(open(os.path.join(ROOT,'data','overrides','km_era_hand.json'),encoding='utf-8')) if (x['line'],x['route'],x['a'],x['b']) not in _KEK]
for x_ in _KE:
    g_=collections.defaultdict(list)
    for e_ in route_edges.get(x_['route'],[]):g_[e_['a']].append(e_);g_[e_['b']].append(e_)
    prev={x_['a']:None};q_=[x_['a']]
    while q_ and x_['b'] not in prev:
        n_=q_.pop(0)
        for e_ in g_[n_]:
            m_=other(e_,n_)
            if m_ not in prev:prev[m_]=(n_,e_);q_.append(m_)
    # 보정 행(source_patch)이 만드는 계통(下北交通 大畑線)은 보정을 얹지 않는 생성 중 컴파일에 없다
    if x_['route'] not in routes:
        if not _nopatch:err('km_era_path',x_)
        continue
    # 생성 중 컴파일(보정 없음)에서는 보정 행(source_patch)이 만드는 칸·km가 없어 길이 끊기거나 지금 km가 다를 수 있다(弘南 黒石線 渡り線). 보정을 얹는 컴파일만 오류로 본다 (9회차 S)
    if x_['b'] not in prev:
        if not _nopatch:err('km_era_path',x_)
        continue
    path=[];n_=x_['b']
    while prev[n_]:n_,e_=prev[n_];path.append(e_)
    now=sum(kms.get(e_['id'],0) for e_ in path)
    if not path or abs(now-x_['km_now'])>.15:
        if not _nopatch:err('km_era_now',dict(x_,calc=round(now,2)))
        continue
    for e_ in path:ERA[(x_['line'],e_['id'])]=kms.get(e_['id'],0)*x_['km']/now
# 같은 노선 안에서 날짜로 바뀐 営業キロ(기간 km, data/overrides/km_era_period.json, 9회차 S·W3 요청 5): 사업자·노선은 그대로인데 역 이전·선로 付け替え로
# 공식 km가 바뀐 칸(妙見線 平野–一の鳥居 1973, 南海 難波–今宮戎 1980, 広電 広島港 2003·海岸通 2002). 행: {line, route, a, b, km(바뀌기 전), km_now, until(바뀐 날), why}.
# 정차역 둘 사이 값을 그 사이 칸에 지금 km 비율로 나눠 edge_km_period에 그 날까지의 행으로 둔다. 단위 km·계통 km는 지금(마지막) 값 그대로다(DESIGN §2.8 C).
# 탑승일 km(탑승 거리)는 앱이 edge_km_period를 읽을 때 쓴다
KMPER=collections.defaultdict(list)
_kpp=os.path.join(ROOT,'data','overrides','km_era_period.json')
for x_ in (json.load(open(_kpp,encoding='utf-8')) if os.path.exists(_kpp) else []):
    if x_['route'] not in routes:
        if not _nopatch:err('km_period_path',x_)
        continue
    g_=collections.defaultdict(list)
    for e_ in route_edges.get(x_['route'],[]):g_[e_['a']].append(e_);g_[e_['b']].append(e_)
    prev={x_['a']:None};q_=[x_['a']]
    while q_ and x_['b'] not in prev:
        n_=q_.pop(0)
        for e_ in g_[n_]:
            m_=other(e_,n_)
            if m_ not in prev:prev[m_]=(n_,e_);q_.append(m_)
    if x_['b'] not in prev:
        if not _nopatch:err('km_period_path',x_)
        continue
    path=[];n_=x_['b']
    while prev[n_]:n_,e_=prev[n_];path.append(e_)
    now=sum(kms.get(e_['id'],0) for e_ in path)
    if not path or abs(now-x_['km_now'])>.05:
        if not _nopatch:err('km_period_now',dict(x_,calc=round(now,2)))
        continue
    for e_ in path:KMPER[e_['id']].append((x_['line'],x_.get('from'),x_['until'],kms.get(e_['id'],0)*x_['km']/now))
def route_km_of(line):
    """그 노선 계통의 칸 km. 노선 시대 km(ERA)가 있으면 그 값이다 (닫힌 국철 계통 丸森線·中村線, 2회차 종합 K22)"""
    return lambda e:ERA.get((line,e['id']),kms.get(e['id'],0))
for r in routes.values():
    S=route_edges[r['id']];kmr=route_km_of(r['line'])
    g=collections.defaultdict(list)
    for e in S:g[e['a']].append(e);g[e['b']].append(e)
    hand=bool(r.get('role')=='branch' or r.get('owned')) and any(e.get('alt')=='old' for e in S)
    def relax(dist,alts):
        pq=[(v,k) for k,v in dist.items()];heapq.heapify(pq)
        while pq:
            d,n=heapq.heappop(pq)
            if d>dist.get(n,1e12):continue
            for e in g[n]:
                # edge를 손으로 고른 계통(지선·옛 경로)은 옛 선로도 같은 단계에서 잇는다. 옛 선로 너머의 본선 칸까지 순서가 이어진다
                if not hand and (e.get('alt')=='old')!=alts:continue
                m=other(e,n);nd=d+kmr(e)
                if nd<dist.get(m,1e12) and not (alts and m in fixed):dist[m]=nd;heapq.heappush(pq,(nd,m))
    dist={r['from']:0.0};fixed=set()
    relax(dist,False)
    fixed=set(dist)
    relax(dist,True)
    if not hand:_alt_scale(r['id'],dist,fixed,S,kmr)
    route_rank[r['id']]=dist
    if S and len(dist)<len(g):err('route_disconnected',{'route':r['id'],'nodes':len(g),'reach':len(dist)})

print('옛 선로 비율 배치',len(ALT_SCALED),sorted(ALT_SCALED.items())[:40])
def fin(x):return x if x not in (None,) else None
def _stop_bounds(fromv,tov,vals):
    """날짜 없는 개업·폐지 사건으로 정차 시작·끝을 모르면 NULL 대신 근거 범위로 둔다 (날짜 원칙).
    끝은 시작 이후, 그 역에 닿는 선로가 끝나기 전(선로가 영업 중이면 판 기준일 전)이다. 시작은 그 선로가 생긴 뒤, 끝 전이다"""
    if tov is None:
        hi_=max(((lohi(a['valid_to'])[1] or '9999-12-31'),a['valid_to']) for a in vals)[1] if vals else None
        tov=f"[{_edge(fromv,0)}..{AS_OF if hi_ in (None,'ongoing') else _edge(hi_,1)}]"
    if fromv is None:
        lo_=min(((lohi(a['valid_from'])[0] or '0000-01-01'),a['valid_from']) for a in vals)[1] if vals else None
        fromv=f"[{_edge(lo_,0)}..{AS_OF if tov=='ongoing' else _edge(tov,1)}]"
    return fromv,tov
_MOVED_NEW={mv['old']:mv['new'] for mv in json.load(open(os.path.join(ROOT,'data','overrides','moved.json'),encoding='utf-8'))}
stops=[]
for r in routes.values():
    dist=route_rank[r['id']]
    # 순서는 정렬 값(dist)으로, km는 옛 선로 역이면 실제 옛 営業キロ로 (K21)
    rk_=ROUTE_KM.get(r['id'],{})
    order=[(n,rk_.get(n,km)) for n,km in sorted(dist.items(),key=lambda x:(round(x[1],3)))]
    if r.get('closed') and r.get('seq'):
        ek={};kmr=route_km_of(r['line'])
        for e in route_edges[r['id']]:ek.setdefault(tuple(sorted((e['a'],e['b']))),[]).append(e)
        order=[];run=0.0
        for i,n in enumerate(r['seq']):
            if i:
                L=ek.get(tuple(sorted((r['seq'][i-1],n))),[])
                if L:run+=kmr(L[0])
            order.append((n,run))
    # km는 지금 끝 역 기준이다. 기점 너머 옛 자리(高松（旧）·新豊橋（旧）)는 음수 km이고 지금 기점이 0이다 (사용자 결정 2026-11-08)
    lead=0
    while lead<len(order) and order[lead][0] in _MOVED_NEW:lead+=1
    if 0<lead<len(order) and order[lead][0] in {_MOVED_NEW[n] for n,_ in order[:lead]}:
        base=order[lead][1];order=[(n,km-base) for n,km in order]
    elist=route_edges[r['id']]
    attrs=collections.defaultdict(list)
    for a in attr:
        if a['line_id']==r['line']:attrs[a['edge_id']].append(a)
    for seq,(n,km) in enumerate(order):
        nd=nodes.get(n)
        if not nd:continue
        evs=stopev.get((r['id'],n),[])
        fromv=None;tov='ongoing'
        for e in adj[n]:
            for a in attrs.get(e['id'],[]):
                pass
        ope=[e for e in evs if e['type']=='open_stop'];cle=[e for e in evs if e['type']=='close_stop']
        vals=[a for e in adj[n] if e in elist for a in attrs.get(e['id'],[])]
        if ope:fromv=ope[0].get('date')
        elif vals:
            los=[(lohi(a['valid_from'])[0] or '0000',a['valid_from']) for a in vals];fromv=min(los)[1]
        if cle:tov=cle[-1].get('date')
        elif vals:
            his=[(lohi(a['valid_to'])[1] or '9999-12-30',a['valid_to']) for a in vals];tov=max(his)[1]
        stop_flag=0 if (nd['kind'] in('signal','junction','pref_boundary','freight') or r.get('nostop',{}).get(n)) else 1
        if n in set(r.get('hidden_stops',[])):stop_flag=0
        if cle and vals and tov is not None:
            mx=max(((lohi(a['valid_to'])[1] or '9999-12-30'),a['valid_to']) for a in vals)
            if (lohi(tov)[1] or '')>mx[0]:tov=mx[1]
        fromv,tov=_stop_bounds(fromv,tov,vals)
        stops.append(dict(route_id=r['id'],seq=seq,node_id=n,km_cum=dround(km),is_stop=stop_flag,is_extension=0,valid_from=fromv,valid_to=tov))


# 문서에서 옮긴 역 기간. 역 문서 연결이 안 되는 곳
# 값은 [시작, 끝] 하나이거나, 정차 기간이 둘 이상인 역(印場 1905~1944·1995~)은 [[시작, 끝], [시작, 끝], ...]이다.
# 정차 행은 처음 시작부터 마지막 끝까지 하나로 두고, 기간 사이 서지 않은 때를 route_stop_gap에 적는다
stop_gaps=[]
for k_,v_ in json.load(open(os.path.join(ROOT,'data','overrides','stop_dates.json'),encoding='utf-8')).items():
    # 「_근거」처럼 _로 시작하는 키는 행 근거를 모은 옆 사전이다 (출처 보존, renames_hand.json과 같은 형식)
    if k_.startswith('_'):continue
    rid_,nd_=k_.split('|') if '|' in k_ else (None,k_)
    # 값 "pass": 그 계통 여객 열차가 서지 않고 지나기만 하는 노드(법정 끝·경계인데 그 계통 승강장이 없음). 정차가 아니지만 행 기간은 그대로 두어
    # 계통 끝(승하차 불가 끝 노드)으로 남고, 너머는 끝 이어짐으로 고른다. 기간을 지운 정차([X, X])로 두면 그 앞 정차역이 계통 끝이 되어
    # 선로가 없는 끝 이어짐이 생긴다 (梅田貨物線 福島: 위키 梅田貨物線 rev111568936 「福島駅・野田駅には梅田貨物線のホーム自体が設置されていない」, 4회차 kinki_1-07, 11회차 S2)
    if v_=='pass':
        hit_=0
        for s in stops:
            if s['node_id']==nd_ and (not rid_ or s['route_id']==rid_) and not s.get('is_extension'):s['is_stop']=0;hit_+=1;WARN['stop_pass'].append((s['route_id'],nd_,s['valid_from'],s['valid_to']))
        if not hit_ and not _nopatch:err('stop_dates_unknown',k_)
        continue
    ps_=v_ if v_ and isinstance(v_[0],list) else [v_]
    for a_,b_ in zip(ps_,ps_[1:]):
        if not a_[1] or not b_[0] or (lohi(a_[1])[1] or '')>=(lohi(b_[0])[0] or ''):err('stop_dates_periods',{k_:v_})
    hit_=0
    for s in stops:
        if s['node_id']==nd_ and (not rid_ or s['route_id']==rid_):
            hit_+=1
            if ps_[0][0]:s['valid_from']=ps_[0][0]
            if ps_[-1][1]:s['valid_to']=ps_[-1][1]
            if s['valid_to'] and (lohi(s['valid_from'])[0] or '0000')>=(lohi(s['valid_to'])[1] or '9999-12-31'):s['is_stop']=0
            # 정차 기간을 손으로 준 역은 그 기간에 선다. 통과 역으로 표시된 역(塔のへつり, 芦峅寺)도 켠다. 신호장·분기점은 그대로
            elif (nodes.get(nd_) or {}).get('kind')=='station':s['is_stop']=1
            for a_,b_ in zip(ps_,ps_[1:]):stop_gaps.append((s,a_[1],b_[0]))
    if len(ps_)>1 and not hit_ and not _nopatch:err('stop_dates_unknown',k_)
# 해마다 며칠만 여는 임시역(臨時駅): 임시역 표식(stop_status rinji·kari) 기간이 여러 토막이면 토막 사이는 서지 않는 때다. 정차 행 하나를 표식 사이 공백(route_stop_gap)으로 가른다.
# 표식이 하나뿐이거나 표식 뒤에 정식 역이 된 경우(표식 밖도 서는 때)는 그대로 둔다 (一ノ堰六地蔵尊 2009~2013 해마다 8/23~8/24, 3회차 tohoku_1-002·tohoku_1-030(2), 8회차 W1b)
_TMK=collections.defaultdict(list)
for x_ in (json.load(open(os.path.join(ROOT,'data','overrides','stop_status.json'),encoding='utf-8')) if os.path.exists(os.path.join(ROOT,'data','overrides','stop_status.json')) else []):
    # 臨時駅 표식끼리만 본다. 仮乗降場 뒤 정식 역이 되었다가 다시 臨時駅이 된 역(柿ノ木·原生花園)의 사이는 서던 때다
    if x_.get('kind')=='rinji' and x_.get('from') and x_.get('to'):_TMK[(x_['node'],x_.get('route'))].append((x_['from'],x_['to']))
_season=0
for (nd_,ro_),ps_ in _TMK.items():
    ps_=sorted(ps_,key=lambda p_:lohi(p_[0])[0] or '')
    holes=[(a_[1],b_[0]) for a_,b_ in zip(ps_,ps_[1:]) if (lohi(a_[1])[1] or '9999')<(lohi(b_[0])[0] or '0000')]
    if not holes:continue
    for s in stops:
        if s['node_id']!=nd_ or (ro_ and s['route_id']!=ro_) or not s['is_stop'] or s.get('is_extension'):continue
        for a_,b_ in holes:
            if (lohi(s['valid_from'])[1] or '0000')<=(lohi(a_)[0] or '') and (s['valid_to'] in (None,'ongoing') or (lohi(b_)[1] or '')<=(lohi(s['valid_to'])[0] or '9999')):
                if not any(g_[0] is s and g_[1]==a_ and g_[2]==b_ for g_ in stop_gaps):stop_gaps.append((s,a_,b_));_season+=1
print('임시역 표식 사이 정차 공백',_season)
# 역 이전: km가 달라 노드는 둘이지만 같은 역이다. 정차 기간을 이전일에서 가르고 묶음을 합친다
_MVPAIRS=[]
for mv in json.load(open(os.path.join(ROOT,'data','overrides','moved.json'),encoding='utf-8')):
    old,new,d=mv['old'],mv['new'],mv['date']
    # 보정 행(source_patch)이 만드는 옛 노드는 보정을 얹지 않는 생성 중 컴파일에 없다
    if old not in nodes or new not in nodes:continue
    # 이전일은 범위로 적을 수 있다([1970-XX-XX..1972-XX-XX]). 비교는 이른 끝으로 하고 잘라 둘 때는 원문을 쓴다
    dl=lohi(d)[0] or d
    # 옛 노드의 정차는 이 이전 기록이 가리키는 노선(행의 lines, 없으면 새 노드에 서는 노선)에서만 자른다.
    # 옛 자리에 남아 이름·회사만 바뀌어 계속 쓰는 노선(千曳 → 南部縦貫 西千曳)은 그대로다
    fam_=lambda rid:(lines.get((routes.get(rid) or {}).get('line')) or {}).get('family')
    line_=lambda rid:(routes.get(rid) or {}).get('line')
    new_fams={fam_(s['route_id']) for s in stops if s['node_id']==new}
    new_lines=set(mv.get('lines') or [])|({line_(s['route_id']) for s in stops if s['node_id']==new and not s.get('is_extension')} if not mv.get('lines') else set())
    # 기간을 이전일 쪽으로 넓히지는 않는다. 새 노드에 이전 뒤에 생긴 노선(新潟 1958 이전, 上越新幹線 1982)이 있다
    for s in stops:
        if s['node_id']==old:
            by_fam=not new_fams or fam_(s['route_id']) in new_fams
            by_line=not new_lines or line_(s['route_id']) in new_lines
            if by_fam!=by_line and s['is_stop'] and (s['valid_to'] in (None,'ongoing') or (lohi(s['valid_to'])[1] or '9999')>dl):
                WARN['moved_cut_rule_diff'].append(dict(old=old,new=new,date=d,route=s['route_id'],family_rule=by_fam,line_rule=by_line))
            if not by_line:continue
            if (lohi(s['valid_from'])[0] or '0000')>=dl:s['is_stop']=0
            # 끝을 연도만 알면(1989-XX-XX) 그 상한이 이전일 뒤로 넘지 않게 자른다 (감사 TOP-08)
            elif s['valid_to'] in (None,'ongoing') or (lohi(s['valid_to'])[1] or '9999')>dl:s['valid_to']=d
        elif s['node_id']==new:
            # 손으로 여러 기간을 준 정차는 그대로 둔다 (高松: 1959 옛 자리로 나갔다가 2001 처음 자리로 돌아옴)
            if any(g_[0] is s for g_ in stop_gaps):continue
            # 옛 노드가 서지 않는 계통(새 노드에서 만나는 다른 노선·옛 경로, 志布志線·大隅線의 志布志)은 자르지 않는다
            _rs=[x for x in stops if x['route_id']==s['route_id'] and not x.get('is_extension')]
            if not any(x['node_id']==old and x['is_stop'] for x in _rs):continue
            # 옛 경로 계통(branch)의 끝이 새 노드면 그 끝은 옛 선로가 본선과 만나는 곳이라 자르지 않는다
            if routes[s['route_id']].get('role')=='branch' and new in (routes[s['route_id']]['from'],routes[s['route_id']]['to']):continue
            if (lohi(s['valid_to'])[1] or '9999-12-31')<=dl:s['is_stop']=0
            elif (lohi(s['valid_from'])[1] or '0000')<dl:s['valid_from']=d
    _MVPAIRS.append((old,new))
# 나뉜 역(split_period)의 정차: [from, to) 동안 b에 서던 계통 정차를 a로 옮긴다.
# 계통에 a가 넣은 칸으로 들어왔으면 a 정차 = b 정차와 그 기간의 겹침. a가 원래 그 계통에 있거나(知立連絡線) 같은 노선 다른 계통(丹波橋 옛 경로)에 서면 b만 자른다.
# b는 그 기간을 빼고 선다(앞·뒤면 시작·끝을 옮기고, 가운데면 서지 않은 때). b의 날짜 있는 이름 가운데 그 기간 안에 든 것(그때는 a의 이름)은 뺀다
_SPLITP_N=collections.Counter();_SPLITP_ROWS=[]
_spe_route=collections.defaultdict(set)
for r_id_,el_ in route_edges.items():
    for e in el_:
        if e['id'] in SPLITP_EDGE:_spe_route[r_id_].add(e['id'])
def _sp_gap(s_,f_,t_):
    gs_=[(g_[1],g_[2]) for g_ in stop_gaps if g_[0] is s_]+[(f_,t_)]
    gs_.sort(key=lambda g_:_sp_lo(g_[0]))
    m_=[]
    for g_ in gs_:
        if m_ and _sp_lo(g_[0])<=_sp_lo(m_[-1][1]):
            if _sp_lo(g_[1])>_sp_lo(m_[-1][1]):m_[-1]=(m_[-1][0],g_[1])
        else:m_.append(g_)
    stop_gaps[:]=[g_ for g_ in stop_gaps if g_[0] is not s_]+[(s_,a_,b_) for a_,b_ in m_]
for i_,x_ in enumerate(_SPLITP):
    a_,b_=x_['a'],x_['b']
    if x_.get('normal') or a_ not in nodes or b_ not in nodes:continue
    f_,t_=x_.get('from'),x_['to'];flo_=_sp_lo(f_);tlo_=_sp_lo(t_)
    hit_=0
    for s in [s for s in stops if s['node_id']==b_ and s['is_stop'] and not s.get('is_extension')]:
        slo_,shi_=_sp_lo(s['valid_from']),_sp_hi(s['valid_to'])
        if not (slo_<tlo_ and flo_<shi_):continue
        hit_+=1
        rs_=[y for y in stops if y['route_id']==s['route_id'] and not y.get('is_extension')]
        as_=next((y for y in rs_ if y['node_id']==a_),None)
        if as_ is not None and any(a_ in (edges[e_]['a'],edges[e_]['b']) for e_ in _spe_route.get(s['route_id'],())):
            as_['is_stop']=1;as_['valid_from']=s['valid_from'] if slo_>=flo_ else f_;as_['valid_to']=s['valid_to'] if shi_<=tlo_ else t_
            _SPLITP_N['a_stop']+=1;mode_='넣은 칸'
        elif as_ is not None:mode_='계통에 있음';_SPLITP_N['a_in_route']+=1
        else:
            ln_=routes[s['route_id']]['line']
            if not any(y['node_id']==a_ and y['is_stop'] and routes[y['route_id']]['line']==ln_ and _sp_lo(y['valid_from'])<tlo_ and max(flo_,slo_)<_sp_hi(y['valid_to']) for y in stops):
                # 옛 경로 계통(source_patch)은 생성 중 컴파일에 없다
                if not _nopatch:err('split_period_no_a',(s['route_id'],a_,b_))
                continue
            mode_='다른 계통';_SPLITP_N['a_other_route']+=1
        if slo_>=flo_ and shi_<=tlo_:s['is_stop']=0
        elif slo_>=flo_:s['valid_from']=t_
        elif shi_<=tlo_:s['valid_to']=f_
        else:_sp_gap(s,f_,t_)
        _SPLITP_ROWS.append((s['route_id'],a_,b_,f_,t_,mode_))
    if not hit_ and not _nopatch:err('split_period_unused',(a_,b_))
print('나뉜 역 기간 정차',len(_SPLITP_ROWS),dict(_SPLITP_N),_SPLITP_ROWS)
# 옛 자리 노드만 새 자리(지금 역)의 묶음으로 옮긴다. 묶음을 통째로 합치면 옛 자리가 이름으로 함께 묶여 있던 다른 역
# (京成千葉（旧）–지금 京成千葉)까지 지금 역(千葉中央)과 같은 역이 되고, 지금 역 묶음 ID도 옛 자리 것으로 바뀐다 (B6a 넘김).
# 이전이 이어지면(옛 자리 → 중간 자리 → 지금 자리) 마지막 자리의 묶음이다
_mvto=dict(_MVPAIRS)
# 옮기기 전 묶음. 옛 자리끼리(다른 이전 쌍의 옛 자리)는 지금 역 묶음을 함께 써도 같은 역이었다는 근거가 아니다 (hub_rule)
_GRP_PRE={k_:v_.get('group') for k_,v_ in nodes.items()}
for old,new in _MVPAIRS:
    seen_={old};x_=new
    while x_ in _mvto and _mvto[x_] not in seen_:seen_.add(x_);x_=_mvto[x_]
    nodes[old]['group']=nodes[x_]['group']
# 보정(stop_dates, moved)을 적용한 뒤에도 정차 끝은 그 계통 노선이 인접 구간을 가진 마지막 날을 넘지 않는다 (DB 감사 D4: 이관·폐선 뒤 옛 계통에 남던 정차)
_ra=collections.defaultdict(list)
for a_ in attr:_ra[(a_['line_id'],a_['edge_id'])].append(a_)
_clip=0
for s in stops:
    if s.get('is_extension') or not s['is_stop'] or s['valid_to'] in (None,'ongoing'):continue
    r_=routes[s['route_id']]
    vals=[a_ for e in route_edges[s['route_id']] if s['node_id'] in (e['a'],e['b']) for a_ in _ra[(r_['line'],e['id'])]]
    if not vals:continue
    mx=max(vals,key=lambda a_:lohi(a_['valid_to'])[1] or '9999-12-31')['valid_to']
    if mx!='ongoing' and (lohi(s['valid_to'])[0] or '')>(lohi(mx)[1] or '9999'):s['valid_to']=mx;_clip+=1
print('노선 구간 끝으로 자른 정차',_clip)
# 계통이 끝난 뒤에 생긴 역(池北線 岡女堂 1995, 계통은 1989까지)은 그 계통에서 지나가기만 하고 기간이 없다. 시작을 끝에 맞춰 기간이 거꾸로 되지 않게 한다 (DB 감사 DBA-023)
for s in stops:
    if s['valid_to'] not in (None,'ongoing') and (lohi(s['valid_from'])[0] or '0000')>(lohi(s['valid_to'])[1] or '9999-12-31'):
        s['is_stop']=0;s['valid_from']=s['valid_to']
# 구간 시작일. 여객 영업이 늦게 시작했거나 끝 역과 함께 열린 구간
for k_,v_ in json.load(open(os.path.join(ROOT,'data','overrides','edge_dates.json'),encoding='utf-8')).items():
    x_=set(k_.split('|'))
    es=[e for e in edges.values() if {e['a'],e['b']}==x_]
    # 옛 선로(지선 계통·alt)가 같은 두 역을 바로 이으면 본선 쪽이다
    if len(es)>1:es=[e for e in es if not e.get('alt') and not e.get('route_only')]
    # 사이에 역이 새로 끼어들었으면(옛 자리 細倉, 新地中華街–メディカルセンター의 새 정류장) 두 역 사이 세 칸까지의 길에 같은 날을 준다
    if not es:
        a0,b0=k_.split('|');_adj=collections.defaultdict(list)
        for e in edges.values():_adj[e['a']].append(e);_adj[e['b']].append(e)
        q_=[(a0,[])];seen_={a0}
        while q_ and not es:
            n0,path=q_.pop(0)
            if len(path)>=3:continue
            for e in _adj[n0]:
                m_=e['b'] if e['a']==n0 else e['a']
                if m_==b0:es=path+[e];break
                if m_ not in seen_:seen_.add(m_);q_.append((m_,path+[e]))
        if es:WARN['edge_dates_path'].append((k_,len(es)))
    # 두 노선이 같은 두 역을 따로 이으면(新潟–上沼垂의 信越·白新) 구간 시작일은 둘 다에 적용한다
    if not es:err('edge_dates_no_edge',k_);continue
    for e_ in es:
        for rows_ in (attr,life):
            # 시작일보다 먼저 끝난 기간(이설 전 국철 시절 등)은 없앤다. 남은 첫 기간이 시작일에서 시작한다
            mine=sorted((r for r in rows_ if r['edge_id']==e_['id']),key=lambda r:lohi(r['valid_from'])[0] or '')
            gone=[r for r in mine if r['valid_to']!='ongoing' and (lohi(r['valid_to'])[1] or '9')<=(lohi(v_)[0] or '0') and r is not mine[-1]]
            for r in gone:rows_.remove(r)
            if not [r for r in mine if r not in gone]:print('EDGEDATES_EMPTY',k_,e_['id'],'attr' if rows_ is attr else 'life');continue
            first=[r for r in mine if r not in gone][0]
            first['valid_from']=v_
# 구간 시작일을 고친 뒤에도 정차 시작은 그 계통 노선이 그 역에 닿는 가장 이른 날보다 앞서지 않는다 (감사 T2-05: 室蘭本線 岩見沢 1892, 城南線 上一万)
_ra2=collections.defaultdict(list)
for a_ in attr:_ra2[(a_['line_id'],a_['edge_id'])].append(a_)
_clip2=0
for s in stops:
    if s.get('is_extension') or not s['is_stop'] or s['valid_from'] is None:continue
    r_=routes[s['route_id']]
    vals=[a_ for e in route_edges[s['route_id']] if s['node_id'] in (e['a'],e['b']) for a_ in _ra2[(r_['line'],e['id'])]]
    if not vals:continue
    mn=min(vals,key=lambda a_:lohi(a_['valid_from'])[0] or '0000')['valid_from']
    if mn and (lohi(s['valid_from'])[1] or '9999')<(lohi(mn)[0] or '0000'):s['valid_from']=mn;_clip2+=1
print('노선 구간 시작으로 자른 정차',_clip2)
def _p_lo(v):return '0000-00-00' if v is None else (lohi(v)[0] or '0000-00-00')
def _p_hi(v):return '9999-12-31' if v in (None,'ongoing') else (lohi(v)[1] or '9999-12-31')
# 손으로 준 정차 기간이 여럿인 역(stop_dates)은 계통 기간으로 자른 뒤 기간마다 다시 본다. 계통이 끝난 뒤에 시작하는 기간
# (塔のへつり 1988 재개업, 국철 会津線 계통은 1987 끝)은 버리고 정차 끝을 남은 마지막 기간 끝으로 둔다. 시작≥끝인 기간 행을 남기지 않는다 (2회차 종합 K18)
_gap_of=collections.defaultdict(list)
for g_ in stop_gaps:_gap_of[id(g_[0])].append(g_)
_cut_pieces=0;_new_gaps=[]
for s in stops:
    gs_=_gap_of.get(id(s))
    if not gs_:continue
    gs_=sorted(gs_,key=lambda g_:_p_lo(g_[1]))
    cuts_=[s['valid_from']]+[x for g_ in gs_ for x in (g_[1],g_[2])]+[s['valid_to']]
    ps_=[]
    for f_,u_ in zip(cuts_[::2],cuts_[1::2]):
        # 계통 기간 [정차 시작, 정차 끝]으로 자른다. 늦은 시작, 이른 끝
        if _p_lo(f_)<_p_lo(s['valid_from']):f_=s['valid_from']
        if _p_lo(u_)>_p_lo(s['valid_to']) and s['valid_to'] not in (None,'ongoing'):u_=s['valid_to']
        if u_ not in (None,'ongoing') and _p_lo(f_)>=_p_hi(u_):_cut_pieces+=1;continue
        ps_.append((f_,u_))
    if not ps_:s['is_stop']=0;continue
    s['valid_from'],s['valid_to']=ps_[0][0],ps_[-1][1]
    for (a_,b_),(c_,d_) in zip(ps_,ps_[1:]):_new_gaps.append((s,b_,c_))
stop_gaps=[g_ for g_ in stop_gaps if id(g_[0]) not in _gap_of]+_new_gaps
print('계통 기간 밖이라 버린 정차 기간',_cut_pieces)
# 운휴로 시작한 계통(富山港線: 2006-03-01 이관, 2006-04-29 富山ライトレール 개업)은 재개일부터 선다 (온종일 운휴 기간은 영업이 아니다, DESIGN §17).
# 정차 시작 날 그 역에 닿는 그 계통 칸이 모두 운휴 중이면 정차 시작부터 가장 이른 재개일까지를 서지 않은 때(route_stop_gap)로 둔다.
# 정차 행 시작은 이관일 그대로라 앞 노선 화면이 그날 이어받은 노선을 찾는다(이관 띠·이관 뒤 역). 정차 기간(route_stop_period)은 재개일부터다
_life_by=collections.defaultdict(list)
for r_ in life:_life_by[r_['edge_id']].append(r_)
_resume=[]
for s in stops:
    if s.get('is_extension') or not s['is_stop'] or s['valid_from'] is None:continue
    d0_=lohi(s['valid_from'])[1] or '0000'
    es_=[e for e in route_edges[s['route_id']] if s['node_id'] in (e['a'],e['b'])]
    if not es_:continue
    nxt_=[]
    for e in es_:
        rs_=sorted(_life_by[e['id']],key=lambda r_:lohi(r_['valid_from'])[0] or '0000')
        cur_=next((r_ for r_ in rs_ if (lohi(r_['valid_from'])[0] or '0000')<=d0_<_p_hi(r_['valid_to'])),None)
        if not cur_ or cur_['status']!='suspended':nxt_=None;break
        rr_=next((r_ for r_ in rs_ if r_['status']=='open' and r_['valid_from']==cur_['valid_to']),None)
        if rr_:nxt_.append(rr_['valid_from'])
    if not nxt_:continue
    v_=min(nxt_,key=lambda x:lohi(x)[0] or '0000')
    if s['valid_to'] not in (None,'ongoing') and (lohi(v_)[0] or '0000')>=_p_hi(s['valid_to']):continue
    _resume.append((s['route_id'],s['node_id'],s['valid_from'],v_));stop_gaps.append((s,s['valid_from'],v_))
print('운휴 중 시작한 정차의 재개일까지 서지 않은 때',len(_resume),_resume[:10])
# 시작≥끝이라 서는 날이 없는 정차(길이 0, 細倉 1990-06-16~1990-06-16)는 지나가기만 한다
_zero=0
for s in stops:
    if s['is_stop'] and s['valid_to'] not in (None,'ongoing') and _p_lo(s['valid_from'])>=_p_hi(s['valid_to']):s['is_stop']=0;_zero+=1
print('서는 날이 없는 정차',_zero)
# 옛 경로·지선 계통은 같은 노선 다른 계통과 만나는 역(합류점)에서 끝난다 (2회차 종합 K03: 瀬戸線 堀川 계통이 尾張瀬戸까지, 長尾線 옛 경로가 林道까지 이어짐).
# 끝 쪽 칸을 같은 노선의 다른 계통(부모)도 지나면 그 칸을 떼어 내고, 합류점이 이 계통에서 서는 역일 때만 거기서 끝낸다. 떼어 낸 역의 정차 기간을 부모가
# 덮지 않으면 부모 정차에 합친다(사이는 서지 않은 때, 瀬戸線 印場 1905~1944는 堀川 계통 행에만 있었음). 부모에 그 역 행이 없거나 합류점이 숨은 분기점·신호장,
# 그때 없던 역이면 그대로 둔다(떼어 낸 칸을 그날 날짜로 넣을 수 없게 되므로. 확장 행 자료가 있어야 한다). 합류점에서 부모 계통 쪽 분기 행은 연결 표에 더한다
_TRIM=[];_trim_j=[]
_sb=collections.defaultdict(dict)
for s in stops:_sb[s['route_id']][s['node_id']]=s
_ppos0={p_['node']:p_ for p_ in positions if p_.get('lat') is not None}
def _absorb(q,s):
    """떼어 낼 정차 s의 기간을 부모 계통 q의 같은 역 정차에 합친다. 부모에 그 역 행이 없으면 False"""
    o=_sb[q].get(s['node_id'])
    if not o:return False
    if not s['is_stop'] or (o['is_stop'] and _p_lo(o['valid_from'])<=_p_lo(s['valid_from']) and _p_hi(o['valid_to'])>=_p_hi(s['valid_to'])):return True
    if not o['is_stop']:o.update(is_stop=1,valid_from=s['valid_from'],valid_to=s['valid_to']);return True
    if _p_hi(s['valid_to'])<=_p_lo(o['valid_from']):stop_gaps.append((o,s['valid_to'],o['valid_from']));o['valid_from']=s['valid_from']
    elif _p_hi(o['valid_to'])<=_p_lo(s['valid_from']):stop_gaps.append((o,o['valid_to'],s['valid_from']));o['valid_to']=s['valid_to']
    else:
        if _p_lo(s['valid_from'])<_p_lo(o['valid_from']):o['valid_from']=s['valid_from']
        if _p_hi(s['valid_to'])>_p_hi(o['valid_to']):o['valid_to']=s['valid_to']
    return True
for rid,r in routes.items():
    if r.get('role')!='branch' or r.get('closed'):continue
    es=list(route_edges[rid]);oth={q:{e['id'] for e in route_edges[q]} for q,x in routes.items() if q!=rid and x['line']==r['line']}
    if not oth:continue
    g=collections.defaultdict(list)
    for e in es:g[e['a']].append(e);g[e['b']].append(e)
    for x in [n for n,v in g.items() if len(v)==1]:
        cut=[];cur=x;qs=None
        while len(g[cur])==1:
            e=g[cur][0];q_=[q for q,v in oth.items() if e['id'] in v and (cur not in _sb[rid] or not _sb[rid][cur]['is_stop'] or cur in _sb[q])]
            nq_=[q for q in (q_ if qs is None else qs) if q in q_]
            if not nq_:break
            qs=nq_
            cut.append(e);y=other(e,cur)
            for k_ in (e['a'],e['b']):g[k_].remove(e)
            cur=y
            if len(g[cur])!=1:break
        if not cut:continue
        m_=_sb[rid].get(cur)
        sp_=[y for y in _sb[rid].values() if y['is_stop']]
        q0_=sorted(qs,key=lambda q:(routes[q].get('role')!='main',q))[0] if qs else None
        p0_=_sb[q0_].get(cur) if q0_ else None
        # 합류점이 이 계통에서만 서지 않게 둔 역이고 부모 계통이 이 계통의 기간 내내 거기 서면(広電 天満町 옛 경로의 観音町) 거기서 서는 끝 역으로 삼는다
        if m_ and not m_['is_stop'] and nodes[cur]['kind']=='station' and p0_ and p0_['is_stop'] and sp_:
            f0_=min((y['valid_from'] for y in sp_),key=_p_lo);u0_=max((y['valid_to'] for y in sp_),key=_p_hi)
            # 부모가 그 사이 서지 않은 때(route_stop_gap, 観音町 1942~1964)가 있으면 덮지 않는다
            gap_=any(g_[0] is p0_ and _p_lo(g_[1])<_p_hi(u0_) and _p_lo(f0_)<_p_hi(g_[2]) for g_ in stop_gaps)
            if not gap_ and _p_lo(p0_['valid_from'])<=_p_lo(f0_) and _p_hi(p0_['valid_to'])>=_p_hi(u0_):m_=dict(m_,is_stop=1,valid_from=f0_,valid_to=u0_,_merge=True)
        gone={n_ for e in cut for n_ in (e['a'],e['b'])}-{cur}
        # 떼어 낸 역과 이 계통 쪽 역 사이를 오가던 기간에는 합류점이 이 계통과 부모 계통 양쪽에서 서야 한다(갈아 넣어 같은 날 기록할 수 있게).
        # 遠州 옛 新浜松 계통은 1958년 전에 遠州病院이 없어 八幡까지 이어진 채로 둔다
        def _cov_(o_,f_,u_):
            return bool(o_) and o_['is_stop'] and _p_lo(o_['valid_from'])<=_p_lo(f_) and _p_hi(o_['valid_to'])>=_p_hi(u_) and not any(g_[0] is o_ and _p_lo(g_[1])<_p_hi(u_) and _p_lo(f_)<_p_hi(g_[2]) for g_ in stop_gaps)
        ok_=bool(m_) and m_['is_stop']
        for y_ in gone:
            ys_=_sb[rid].get(y_)
            if not ok_ or not ys_ or not ys_['is_stop']:continue
            for z_ in sp_:
                if z_['node_id'] in gone or z_['node_id']==cur:continue
                f_=max(ys_['valid_from'],z_['valid_from'],key=_p_lo);u_=min(ys_['valid_to'],z_['valid_to'],key=_p_hi)
                if _p_lo(f_)<_p_hi(u_) and not(_cov_(m_,f_,u_) and _cov_(p0_,f_,u_)):ok_=False;break
        if not ok_ or not g[cur] or len(cut)>=len(es) or not all(y_ not in _sb[rid] or not _sb[rid][y_]['is_stop'] or y_ in _sb[q0_] for y_ in gone):
            for e in cut:g[e['a']].append(e);g[e['b']].append(e)
            continue
        if m_.pop('_merge',None):_sb[rid][cur].update(m_)
        for y_ in gone:
            if y_ in _sb[rid]:_absorb(q0_,_sb[rid][y_])
        _TRIM.append((rid,x,cur,len(cut)))
        route_edges[rid]=[e for e in route_edges[rid] if e not in cut]
        stops=[s for s in stops if not(s['route_id']==rid and s['node_id'] in gone)]
        for k_ in ('from','to'):
            if r[k_]==x:r[k_]=cur
        # 합류점에서 부모 계통 화면의 분기: 이 계통이 나가는 쪽이 부모 계통의 앞 역 쪽이면 up
        b_=other(g[cur][0],cur);sd_=None
        for q in qs:
            rk_=route_rank[q];ord_=sorted((n_ for n_ in rk_ if _sb[q].get(n_,{}).get('is_stop')),key=lambda n_:rk_[n_])
            if cur not in ord_:continue
            i_=ord_.index(cur);pv_=ord_[i_-1] if i_ else None;nx_=ord_[i_+1] if i_+1<len(ord_) else None
            def _v(a_,c_):
                p_,q_=_ppos0.get(a_),_ppos0.get(c_)
                return ((q_['lon']-p_['lon'])*math.cos(math.radians(p_['lat'])),q_['lat']-p_['lat']) if p_ and q_ and c_ else None
            vb_,vp_,vn_=_v(cur,b_),_v(cur,pv_),_v(cur,nx_)
            if vb_ and vp_ and vn_:
                cs_=lambda u,w:(u[0]*w[0]+u[1]*w[1])/((math.hypot(*u)*math.hypot(*w)) or 1)
                sd_='up' if cs_(vb_,vp_)>cs_(vb_,vn_) else 'down'
            break
        _trim_j.append(dict(line=r['line'],other=r['line'],other_route=rid,at=cur,source='derived',verified=False,valid=[None,'ongoing'],**({'side':sd_} if sd_ else {})))
# 순번을 다시 매기고, 시작 쪽을 떼어 냈으면 km를 새 시작에서 잰다
for rid in {t_[0] for t_ in _TRIM}:
    L_=sorted((s for s in stops if s['route_id']==rid and not s.get('is_extension')),key=lambda s:s['seq'])
    b0_=L_[0]['km_cum'] if L_ and L_[0]['km_cum'] else 0
    for i_,s in enumerate(L_):s['seq']=i_;s['km_cum']=dround(s['km_cum']-b0_) if s['km_cum'] is not None else None
_gid={id(s) for s in stops};stop_gaps=[g_ for g_ in stop_gaps if id(g_[0]) in _gid]
junctions+=_trim_j
print('합류점에서 끝낸 옛 경로·지선 계통',_TRIM)
# ── 그날 아직 없던 역이 계통 끝이고 그 자리가 같은 노선 선로가 그냥 이어지는 점이면 그날의 기점·종점은 바로 앞 역이다 (사용자 결정 2026-11-21) ──
# 옛 경로·지선 계통을 나중에 생긴 역에서 나눈 경우(키쿠치선 구선은 1995 개업 덴파코센마에에서 나눔)에 그 역이 생기기 전에는 그 자리에 역도 신호장·분기점도 없다.
# 그날 그 점에 닿는 선로가 두 갈래뿐이고 둘 다 계통 노선이면, 그 노선 다른 계통에서 그 점 바로 옆의 역(계통에 없는 역, 쿠로이시)을 그 기간의 기점(종점)으로 붙인다.
# 붙인 행은 그 기간에만 있고(뒤로는 숨김, route_stop_select none) 그 기간 그 칸은 이 계통의 칸이다. 세 갈래 이상(실제 분기점, 신이마미야 1961–1964)이나 다른 노선끼리 만나는 점은 그대로 분기점이다
_LEAD_EIV={}
_LEAD_TAKE={}
def _lead_lo(v):return lohi(v)[0] or '0000-00-00'
_fst0={}
for s_ in stops:
    if s_['is_stop'] and not s_.get('is_extension'):
        k_=_lead_lo(s_['valid_from'])
        if s_['node_id'] not in _fst0 or k_<_lead_lo(_fst0[s_['node_id']]):_fst0[s_['node_id']]=s_['valid_from']
_IDN0=collections.defaultdict(list)
_idp0=os.path.join(ROOT,'data','overrides','node_identity.json')
if os.path.exists(_idp0):
    for r_ in json.load(open(_idp0,encoding='utf-8'))['rows']:
        if r_['kind']!='none':_IDN0[r_['node']].append((lohi(r_.get('from'))[0] or '0000',lohi(r_.get('to'))[0] or '9999') if r_.get('to') else (lohi(r_.get('from'))[0] or '0000','9999'))
_sigw0=re.compile(r'(信号場|信号所|分岐点)')
for x_ in names:
    if x_['entity_type']=='node' and x_['lang']=='ja' and not x_.get('line') and (x_.get('valid_from') or x_.get('valid_to')) and _sigw0.search(x_['text']):
        _IDN0[x_['id']].append((lohi(x_.get('valid_from'))[0] or '0000',lohi(x_.get('valid_to'))[0] or '9999'))
def _open0(x_,d_):
    """그날 노드 x_에 닿는 노선 소속 칸 (칸, 노선)"""
    return [(a_['edge_id'],a_['line_id']) for a_ in _attr_at.get(x_,()) if (lohi(a_['valid_from'])[0] or '0000')<=d_<((lohi(a_['valid_to'])[0] or '9999') if a_['valid_to'] not in (None,'ongoing') else '9999')]
_attr_at=collections.defaultdict(list)
for a_ in attr:
    e_=edges.get(a_['edge_id'])
    if e_ and e_['a']!=e_['b']:_attr_at[e_['a']].append(a_);_attr_at[e_['b']].append(a_)
_byr0=collections.defaultdict(list)
for s_ in stops:
    if not s_.get('is_extension'):_byr0[s_['route_id']].append(s_)
for L_ in _byr0.values():L_.sort(key=lambda y:y['seq'])
_lead_n=0
for rid_,r_ in sorted(routes.items()):
    L_=_byr0.get(rid_)
    if not L_ or len(L_)<2 or lines.get(r_['line'],{}).get('rule_class')=='hidden':continue
    for side_ in ('start','end'):
        X_=(L_[0] if side_=='start' else L_[-1])
        x_=X_['node_id']
        if x_ not in (r_['from'],r_['to']) or nodes.get(x_,{}).get('kind')!='station' or x_ not in _fst0:continue
        f0_=min((_lead_lo(y['valid_from']) for y in L_))
        fs_=_lead_lo(_fst0[x_])
        d_=max(f0_,'1950-01-01')
        if d_>=fs_:continue
        if any(a_<fs_ and d_<b_ for a_,b_ in _IDN0.get(x_,())):continue
        op_=_open0(x_,d_)
        if len({e for e,_ in op_})!=2 or any(l_!=r_['line'] for _,l_ in op_):continue
        mine_={y['node_id'] for y in L_}
        best_=None
        for rid2_,L2_ in sorted(_byr0.items()):
            if rid2_==rid_ or routes[rid2_]['line']!=r_['line']:continue
            for i_,y2_ in enumerate(L2_):
                if y2_['node_id']!=x_:continue
                for j_ in (i_-1,i_+1):
                    if not 0<=j_<len(L2_):continue
                    yy_=L2_[j_]
                    if yy_['node_id'] in mine_:continue
                    ee_=[e for e in route_edges.get(rid2_,()) if {e['a'],e['b']}=={x_,yy_['node_id']} and e['id'] in {k for k,_ in op_}]
                    if not ee_ or _lead_lo(yy_['valid_from'])>=fs_ or (yy_['valid_to'] not in (None,'ongoing') and _lead_lo(yy_['valid_to'])<=d_):continue
                    best_=best_ or (yy_,ee_[0])
        if not best_:continue
        yy_,e_=best_
        k_=kms.get(e_['id'])
        km_=None if X_['km_cum'] is None or k_ is None else dround(X_['km_cum']-k_ if side_=='start' else X_['km_cum']+k_)
        vf_=yy_['valid_from'] if _lead_lo(yy_['valid_from'])>f0_ else min((y['valid_from'] for y in L_),key=_lead_lo)
        row_=dict(route_id=rid_,seq=0,node_id=yy_['node_id'],km_cum=km_,is_stop=yy_['is_stop'],is_extension=0,valid_from=vf_,valid_to=_fst0[x_],lead_until=_fst0[x_])
        if side_=='start':
            for y in L_:y['seq']+=1
            row_['seq']=0;L_.insert(0,row_)
        else:
            row_['seq']=L_[-1]['seq']+1;L_.append(row_)
        stops.append(row_)
        route_edges[rid_]=list(route_edges.get(rid_,()))+[e_]
        _LEAD_EIV[(rid_,e_['id'])]=(vf_,_fst0[x_])
        # 그 기간 그 칸은 이 계통 몫이다. 칸을 빌려 준 같은 노선 계통에서는 그 기간 빼서 그쪽 끝도 앞 역이 되게 한다(키쿠치선 본선 1995 전 끝 쿠로이시)
        for rid3_ in [q_ for q_ in _byr0 if q_!=rid_ and routes[q_]['line']==r_['line'] and any(e3['id']==e_['id'] for e3 in route_edges.get(q_,()))]:
            _LEAD_TAKE[(rid3_,e_['id'])]=(vf_,_fst0[x_])
        _lead_n+=1;WARN['lead_rows'].append((rid_,side_,x_,yy_['node_id'],vf_,_fst0[x_]))
print('그날 없던 끝 역 대신 앞 역을 기점으로',_lead_n,WARN['lead_rows'][:10])
# 오늘 영업하는 계통의 km 원점은 공식 기점(오늘 서는 첫 공개 정차역)이다. 기점 쪽 구간이 폐지돼 원점이 폐역이면(石川線 白菊町, 京津線 京津三条,
# 播但線 飾磨港) 첫 현행 정차역을 0.0으로 옮기고 폐지 구간은 음수 km로 둔다 (2회차 종합 K20). 원점이 숨은 분기점·신호장이거나 그 역의 선로가 아직 살아 있으면 그대로다
_ROUTE_ORIGIN=[]
_SPAB={(x_['a'],x_['b']) for x_ in _SPLITP if not x_.get('normal')}
_bys=collections.defaultdict(list)
for s in stops:
    if not s.get('is_extension'):_bys[s['route_id']].append(s)
for L_ in _bys.values():L_.sort(key=lambda s:s['seq'])
# 원점 역이 「이 노선」의 현행 정차역이면 그대로 둔다. 다른 노선이 지금 서는 역이라도 이 노선이 그 역을 더 쓰지 않으면 원점을 옮긴다(徳島線 三縄·阿波池田 → 佃 0.0)
_curnode={(routes[s['route_id']]['line'],s['node_id']) for s in stops if s['is_stop'] and s['valid_to']=='ongoing' and not s.get('is_extension')}
for rid_,L_ in _bys.items():
    r_=routes[rid_]
    # 지선·옛 경로 계통(branch)의 km는 그 계통 안의 위치라 공식 기점과 관계없다
    if r_.get('closed') or r_.get('role')!='main':continue
    h_=L_[0]
    # 나뉜 역(split_period)으로 계통 머리에 붙인 a(같은 km 점 칸, 京津線 三条 1949–1987)는 그 기간 b(京津三条)의 자리다. 기점 판정은 b로 한다.
    # a가 지금 다른 노선 정차역이어도 나뉜 역 규칙이 km 원점을 옮기지 않는다 (11회차 F1: 京津線 御陵 3.7 → 0.0)
    while len(L_)>L_.index(h_)+1 and (h_['node_id'],L_[L_.index(h_)+1]['node_id']) in _SPAB and L_[L_.index(h_)+1]['km_cum']==h_['km_cum']:h_=L_[L_.index(h_)+1]
    # 머리 행이 서지 않는 행이어도(넘겨준 옛 구간의 끝, 徳島線 三縄) 역이면 같다. 숨은 분기점·신호장은 그대로다
    if h_['valid_to'] in (None,'ongoing') or nodes[h_['node_id']]['kind']!='station' or (r_['line'],h_['node_id']) in _curnode:continue
    c_=next((s for s in L_ if s['is_stop'] and s['valid_to']=='ongoing'),None)
    if not c_ or c_['km_cum'] is None or c_['km_cum']<=.05:continue
    if any(a_['valid_to']=='ongoing' for e in route_edges[rid_] if h_['node_id'] in (e['a'],e['b']) for a_ in _ra[(r_['line'],e['id'])]):continue
    base_=c_['km_cum']
    for s in L_:s['km_cum']=dround(s['km_cum']-base_)
    _ROUTE_ORIGIN.append((rid_,h_['node_id'],c_['node_id'],base_))
print('현행 기점으로 옮긴 km 원점',len(_ROUTE_ORIGIN),_ROUTE_ORIGIN[:20])
# 한 노드에 겹쳐 있던 다른 시설(노면 정류장–철도역 등)을 노선별로 나눈다 (data/overrides/node_split.json, 재설계 통합 int_identity).
# 정차·선로·분기 기록을 원 노드로 다 만든 뒤 move_lines 노선 쪽만 새 노드로 바꾼다. 좌표가 없으면 원 노드 좌표,
# 이름이 원 노드와 같으면 원 노드의 한국어·영어 이름을 함께 쓰고, 다르면 일본어만 둔다(아래 ja_as_is가 채운다).
# 역 문서 乗換 근거(hub_evidence)는 원 노드 ID에 붙은 것이라 새 노드에 물려주지 않는다
SPLIT={}      # (노선, 원 노드) -> 새 노드
SPLIT_OF={}   # 새 노드 -> 원 노드
_eln=collections.defaultdict(set)
for a_ in attr:_eln[a_['edge_id']].add(a_['line_id'])
_nm_of=collections.defaultdict(list)
for x_ in names:
    if x_['entity_type']=='node':_nm_of[x_['id']].append(x_)
_pos_of={p_['node']:p_ for p_ in positions}
_NFIX=json.load(open(os.path.join(ROOT,'data','overrides','node_fix.json'),encoding='utf-8'))
_OLDFIX=json.load(open(os.path.join(ROOT,'data','overrides','old_names_fix.json'),encoding='utf-8'))
_RNH=json.load(open(os.path.join(ROOT,'data','overrides','renames_hand.json'),encoding='utf-8'))
_rn5_=os.path.join(ROOT,'data','overrides','renames_n05.json')
_RN05=json.load(open(_rn5_,encoding='utf-8')) if os.path.exists(_rn5_) else {}
for x_ in json.load(open(os.path.join(ROOT,'data','overrides','node_split.json'),encoding='utf-8')):
    n_,new_=x_['node'],x_['new_id'];mv_=set(x_['move_lines'])
    if n_ not in nodes or mv_-set(lines):
        if not _nopatch:err('node_split_unknown',n_)
        continue
    if new_ in nodes:err('node_split_taken',new_);continue
    hit_=[s for s in stops if s['node_id']==n_ and routes[s['route_id']]['line'] in mv_]
    if not hit_:err('node_split_unused',n_);continue
    for l_ in mv_:SPLIT[(l_,n_)]=new_
    SPLIT_OF[new_]=n_
    nd_=dict(nodes[n_],id=new_,pref=x_['pref'])
    # 같은 group으로 두지 않는 쌍(함께 영업한 적 없는 다른 시스템)은 새 group
    if x_['new_group']!=nodes[n_].get('group'):
        if any(m.get('group')==x_['new_group'] for m in nodes.values()):err('node_split_group_taken',x_['new_group'])
        nd_['group']=x_['new_group']
        if not any(g['id']==x_['new_group'] for g in groups):groups.append(dict(id=x_['new_group']))
    nodes[new_]=nd_
    for s in hit_:s['node_id']=new_
    # 선로 끝: 그 edge에 멤버십이 있는 노선(없으면 seed_line)이 모두 옮길 노선일 때만 바꾼다. 두 쪽이 함께 쓰는 edge는 원 노드에 두고 알린다
    for e in list(adj[n_]):
        ls_=_eln[e['id']] or {e.get('seed_line')}-{None}
        if not ls_&mv_:continue
        if ls_-mv_:WARN['node_split_edge_shared'].append((n_,e['id'],sorted(ls_-mv_)));continue
        for k_ in ('a','b'):
            if e[k_]==n_:e[k_]=new_
        adj[n_].remove(e);adj[new_].append(e)
    pp_=x_.get('position');p0_=_pos_of.get(n_)
    # 새 노드 ID로 이미 좌표 행(손 보정 위치의 precise 승강장 점 등)이 있으면 그것을 쓴다. 나눔 행의 대략 좌표를 한 번 더 넣지 않는다 (熊野前·富山駅 K37)
    if any(q_['node']==new_ for q_ in positions):pass
    elif pp_ and source_on(pp_.get('source','n05')):positions.append(dict(node=new_,lat=pp_['lat'],lon=pp_['lon'],quality='approx',checked=(p0_ or {}).get('checked'),source=pp_.get('source')))
    elif p0_:positions.append(dict(p0_,node=new_,quality='approx' if p0_.get('lat') is not None else p0_.get('quality')))   # 원 노드 좌표를 빌린 것이라 approx
    same_=next((y['text'] for y in _nm_of[n_] if y['lang']=='ja' and not y.get('line') and not y.get('valid_from') and not y.get('valid_to')),None)==x_['name_ja']
    # 새 노드(옮길 노선 쪽 시설)가 선 기간. 원 노드의 옛 이름은 이 기간 안에서 끝난 것만 새 노드의 옛 이름이다.
    # 새 시설이 닫힌 뒤까지 이어진 이름(都電 日本橋가 1972 끝난 뒤 1989까지 지하철 쪽 江戸橋, 名古屋城 정류장 1971 뒤 市役所 ~2023)은 원 시설의 이력이다
    nlo_=min((_p_lo(h_['valid_from']) for h_ in hit_),default='0000-00-00');nhi_=max((_p_hi(h_['valid_to']) for h_ in hit_),default='9999-12-31')
    def _mine(y):
        a_=_p_lo(y.get('valid_from'));b_=_p_hi(y.get('valid_to')) if y.get('valid_to') else '9999-12-31'
        return a_<nhi_ and b_>nlo_ and (not y.get('valid_to') or (lohi(y['valid_to'])[0] or '9999')<=nhi_)
    for y in list(_nm_of[n_]):
        # 노선별 이름(그 노선에서만 쓰는 표기)은 그 노선 쪽 노드로 옮긴다
        if y.get('line') in mv_:y['id']=new_
        elif y.get('line'):continue
        elif (y.get('valid_from') or y.get('valid_to')) and _mine(y):names.append(dict(y,id=new_))
        elif same_ and not y.get('valid_from') and not y.get('valid_to'):names.append(dict(y,id=new_))
    if not same_:
        names.append(dict(entity_type='node',id=new_,lang='ja',text=x_['name_ja'],source='node_split',**({'kana':x_['kana']} if x_.get('kana') else {})))
        # 읽기가 있으면 한국어·영어도 행에 둔다. 없으면 아래 ja_as_is가 일본어 표기를 쓴다
        for lg_ in ('ko','en'):
            if x_.get(lg_):names.append(dict(entity_type='node',id=new_,lang=lg_,text=x_[lg_],source='node_split'))
    # 감사에서 고친 이름(node_fix.json)은 생성기(gen_source)가 이름에 얹는데, 나눈 노드는 여기서 생겨 그 단계를 못 거친다. 같은 규칙으로 얹는다
    # (伊予鉄 大手町線 大手町駅前: 원 노드 이름 大手町을 물려받은 뒤 node_fix의 ja로)
    f_=_NFIX.get(new_);chg_=False
    if f_:
        # 검색 별칭(공식 이름과 다른 통칭·옛 표기, 2회차 종합 U07·U19)도 생성기 단계를 못 거친 나눈 노드에 얹는다 (港区役所前·長町北町·四番町八丁目)
        for a_ in f_.get('aliases') or []:aliases.append(dict(entity_type='node',id=new_,lang='ja',text=a_,kind='alias'))
        for y in names:
            if y['entity_type']!='node' or y['id']!=new_ or y.get('line') or y.get('valid_from') or y.get('valid_to'):continue
            if y['lang']=='ja':
                if 'kana' in f_:y['kana']=f_['kana']
                if f_.get('ja') and f_['ja']!=y['text']:
                    aliases.append(dict(entity_type='node',id=new_,lang='ja',text=y['text'],kind='noritsubushi'));y['text']=f_['ja'];y['source']='hand';chg_=True
                    # 물려받은 읽기는 원 노드 이름의 읽기다. 새 표기의 읽기를 함께 주지 않았으면 비운다
                    if 'kana' not in f_:y.pop('kana',None)
            elif f_.get(y['lang']):y['text']=f_[y['lang']];y['source']='hand'
        _hv={y['lang'] for y in names if y['entity_type']=='node' and y['id']==new_ and not y.get('line') and not y.get('valid_from') and not y.get('valid_to')}
        for lg_ in ('ko','en'):
            if f_.get(lg_) and 'ja' in _hv and lg_ not in _hv:names.append(dict(entity_type='node',id=new_,lang=lg_,text=f_[lg_],source='hand'))
        # 일본어만 고쳤으면 원 노드에서 물려받은 한국어·영어(大手町의 오테마치)는 다른 이름의 것이라 지우고 일본어 표기 그대로(ja_as_is)로 둔다
        # 읽기를 지운 행(kana null, 다른 역 읽기를 빌려 온 것)도 그 읽기로 만든 한국어·영어를 지운다 (생성기 node_fix 규칙과 같음, 9회차 N)
        if (chg_ and not f_.get('kana')) or ('kana' in f_ and f_['kana'] is None):
            names[:]=[y for y in names if not (y['entity_type']=='node' and y['id']==new_ and y['lang'] in ('ko','en') and y.get('source')!='hand' and not y.get('line') and not y.get('valid_from') and not y.get('valid_to'))]
    # 사람이 고친 옛 이름(old_names_fix.json의 「새 노드|옛 이름」 행)도 생성기가 못 거친 나눈 노드에 같은 뜻으로 얹는다.
    # null이면 그 옛 이름 행(같은 기간의 한국어·영어 포함)을 빼고, [이름, 시작, 끝]이면 그 행을 그 값으로 두거나 없으면 더한다 (大手町駅前의 옛 이름 江戸町駅前)
    for k_,v_ in _OLDFIX.items():
        nd_,_,t_=k_.partition('|')
        if nd_!=new_ or not t_:continue
        hit2_=[y for y in names if y['entity_type']=='node' and y['id']==new_ and y['lang']=='ja' and not y.get('line') and y.get('valid_to') and y['text']==t_]
        per_={(y.get('valid_from'),y.get('valid_to')) for y in hit2_}
        names[:]=[y for y in names if not (y['entity_type']=='node' and y['id']==new_ and not y.get('line') and (y.get('valid_from'),y.get('valid_to')) in per_ and (y['lang']!='ja' or y['text']==t_))]
        if isinstance(v_,list) and v_[2]:names.append(dict(entity_type='node',id=new_,lang='ja',text=v_[0],source='hand',valid_from=v_[1],valid_to=v_[2]))
    # 손 개칭(renames_hand)·N05 연도 개칭(renames_n05)도 새 노드 ID 행은 생성기가 못 본다(都電 麻布十番의 옛 이름 一ノ橋, 月島의 月島通八丁目). 같은 글자 행이 없을 때 더한다.
    # 손 개칭의 4번째 원소는 그 노선에서만 쓴 이름이다(N05 행의 4번째 원소는 N05 역 ID라 노선이 아니다)
    _have=collections.defaultdict(list)
    for y in names:
        if y['entity_type']=='node' and y['id']==new_ and y['lang']=='ja':_have[y['text']].append(y)
    for src_,rows_ in (('hand',_RNH.get(new_) or []),('n05',_RN05.get(new_) or [])):
        for r_ in (rows_ if isinstance(rows_,list) else []):
            if not isinstance(r_,list):continue
            old_,f_,to_=r_[:3];ln_=(r_[3] if len(r_)>3 and src_=='hand' else None)
            if not old_ or not to_ or (ln_ and ln_ not in lines):continue
            if any(y.get('line')==ln_ and (src_=='n05' or y.get('valid_to')==to_) for y in _have.get(old_,[])):continue
            if old_ in _have:
                # 같은 글자 옛 이름이 다른 기간으로 있으면 손 값이 이긴다(N05 연 범위는 덮지 않음)
                if src_=='n05':continue
                names[:]=[y for y in names if not (y['entity_type']=='node' and y['id']==new_ and y['lang']=='ja' and y['text']==old_ and y.get('line')==ln_ and y.get('valid_to'))]
            y_=dict(entity_type='node',id=new_,lang='ja',text=old_,source='hand' if src_=='hand' else 'n05',valid_from=f_,valid_to=to_,**({'line':ln_} if ln_ else {}))
            names.append(y_);_have[old_]=[y for y in _have.get(old_,[]) if y.get('line')!=ln_ or not y.get('valid_to') or src_=='n05']+[y_]
    for j in junctions:
        if j.get('at')==n_ and j['line'] in mv_:j['at']=new_
    for r in routes.values():
        if r['line'] in mv_:
            r['from']=new_ if r['from']==n_ else r['from'];r['to']=new_ if r['to']==n_ else r['to']
            if r.get('via'):r['via']=[new_ if v==n_ else v for v in r['via']]
    for s_ in services:
        for ei_,ed_ in enumerate(s_['editions']):
            mvd_=[p_ for p_ in ed_['parts'] if routes.get(p_.get('route'),{}).get('line') in mv_]
            for p_ in mvd_:
                for k_ in ('from','to'):
                    if p_.get(k_)==n_:p_[k_]=new_
            # 정차역은 옮긴 노선의 부분에서는 새 노드다. 옮기지 않은 부분도 있으면 둘 다 두고 경로에 없는 쪽을 나중에 뺀다
            if mvd_ and n_ in (ed_.get('stops') or []):
                keep_=len(mvd_)<len(ed_['parts'])
                ed_['stops']=[y_ for x_ in ed_['stops'] for y_ in ((x_,new_) if x_==n_ and keep_ else (new_,) if x_==n_ else (x_,))]
                if keep_:_svc_split_extra.update({(s_['id'],ei_,n_),(s_['id'],ei_,new_)})
    for a_ in archive:
        if a_.get('kind')=='stop' and a_.get('line') in mv_:
            for k_ in ('after','before'):
                if a_.get(k_)==n_:a_[k_]=new_
print('나눈 노드',len(SPLIT_OF))
# 손 개칭의 노선 전용 행(4번째 원소) 가운데 노선이 컴파일 단계에서 생기는 것(사건 보정 이관으로 만드는 弘南 黒石線)은 생성기가 못 넣는다. 같은 글자·같은 노선 행이 없으면 여기서 더한다 (2회차 회귀 tohoku_1-015, 2026-11-13)
_late=0
_LATE_KANA={k:v['kana'] for k,v in json.load(open(os.path.join(ROOT,'data','overrides','old_names_kana.json'),encoding='utf-8')).items() if v.get('kana')}
for nd_,rows_ in _RNH.items():
    if nd_.startswith('_') or nd_ not in nodes or not isinstance(rows_,list):continue
    for r_ in rows_:
        if not isinstance(r_,list) or not r_[0] or not r_[2]:continue
        ln_=r_[3] if len(r_)>3 else None
        if ln_ and ln_ not in lines:continue
        # 생성 단계 ID와 공개 ID가 다른 노드(새 ID로 잠근 京津 東山三条)의 손 개칭도 생성기가 못 본다. 같은 글자 행이 하나도 없고 지금 이름과도 다를 때만 더한다
        if any(y['entity_type']=='node' and y['id']==nd_ and y['lang']=='ja' and y['text']==r_[0] and (y.get('line')==ln_ or not ln_) for y in names):continue
        if not ln_ and any(y['entity_type']=='node' and y['id']==nd_ and y['lang']=='ja' and y['text']==r_[0] for y in names):continue
        _lk={'line':ln_} if ln_ else {}
        # 읽기는 사람이 확인한 옛 이름 읽기(old_names_kana)에서만 가져온다. 있으면 한국어·영어도 생성기와 같은 규칙으로 만든다 (K14, 2026-11-14)
        _kk=_LATE_KANA.get(nd_+'|'+r_[0])
        names.append(dict(entity_type='node',id=nd_,lang='ja',text=r_[0],source='hand',valid_from=r_[1],valid_to=r_[2],**({'kana':_kk} if _kk else {}),**_lk));_late+=1
        if _kk:
            # 나무위키 표(data/imports)는 깨끗한 체크아웃에 없다. 빌드마다 같은 이름이 나오게 규칙 표기만 쓴다(아래 계통 이름 채우기와 같음)
            os.environ['NW_OFF']='1'
            import ko as _ko1,en_rules as _en1
            names.append(dict(entity_type='node',id=nd_,lang='ko',text=_ko1.station(_kk,r_[0]),source='rule',valid_from=r_[1],valid_to=r_[2],checked=TODAY,**_lk))
            _e1=_en1.station_reading(_kk,r_[0]);_e1=_en1.fix_station(r_[0],_kk,_e1,{}) or _e1
            names.append(dict(entity_type='node',id=nd_,lang='en',text=_e1,source='rule',valid_from=r_[1],valid_to=r_[2],**_lk))
print('생성기가 못 본 손 개칭 행',_late)
# 사람이 확인한 옛 이름 읽기(old_names_kana 「노드|옛 이름」)는 출처와 상관없이 그 노드의 같은 글자 기간 행에 붙는다. 생성기(gen_source)는 자기가 낸 행에만 붙여서,
# 보정 행(source_patch)이 더한 노드의 N05 옛 이름(浜松 旭町, 遠州鉄道 옛 新浜松)과 노드 나누기·손 개칭으로 컴파일에서 생긴 행은 읽기가 비었다(10회차 D3 보고, 11회차 S1).
# 읽기를 붙이면 한국어·영어도 생성기와 같은 규칙으로 만든다. 같은 기간의 한국어·영어 행이 이미 있으면 그대로 둔다(아래 「(당시 …)」 병기는 행이 없을 때만 생긴다)
_okfill=[]
_kokey={(y['id'],y['lang'],y.get('line'),y.get('valid_from'),y.get('valid_to')) for y in names if y['entity_type']=='node' and y['lang'] in ('ko','en')}
for y in list(names):
    if y['entity_type']!='node' or y['lang']!='ja' or y.get('kana') or not (y.get('valid_from') or y.get('valid_to') not in (None,'ongoing')):continue
    _kk=_LATE_KANA.get(y['id']+'|'+y['text'])
    if not _kk:continue
    y['kana']=_kk;_okfill.append((y['id'],y['text']))
    os.environ['NW_OFF']='1'
    import ko as _ko1,en_rules as _en1
    _lk={'line':y['line']} if y.get('line') else {}
    if (y['id'],'ko',y.get('line'),y.get('valid_from'),y.get('valid_to')) not in _kokey:
        names.append(dict(entity_type='node',id=y['id'],lang='ko',text=_ko1.station(_kk,y['text']),source='rule',valid_from=y.get('valid_from'),valid_to=y.get('valid_to'),checked=TODAY,**_lk))
    if (y['id'],'en',y.get('line'),y.get('valid_from'),y.get('valid_to')) not in _kokey:
        _e1=_en1.station_reading(_kk,y['text']);_e1=_en1.fix_station(y['text'],_kk,_e1,{}) or _e1
        names.append(dict(entity_type='node',id=y['id'],lang='en',text=_e1,source='rule',valid_from=y.get('valid_from'),valid_to=y.get('valid_to'),**_lk))
print('옛 이름 읽기 표를 늦게 붙인 기간 행',len(_okfill),_okfill[:10])
# 날짜 없는 폐역 표시(노리츠부시 *)가 만든 정차 끝 범위([정차 시작..선 끝]) 가운데, 계통 칸이 모두 같은 날 닫히고 그 계통의 모든 정차 끝이 같은 꼴로 범위인 선
# (박람회·유원지 선: 横浜博 3선·よみうりランド·ヨカトピア, 역 둘뿐인 鋼索·리프트)은 역마다 따로 닫힌 근거가 없고 선과 함께 끝났다. 정차 끝을 선 끝(그 값이 범위면 그 범위)으로 둔다.
# 여러 역 가운데 한 역만 범위인 노선(玉川遊園)은 노선보다 먼저 닫혔을 수 있어 두지 않는다 (W3 요청 3, 9회차 S)
# 나뉜 역(split_period): b의 날짜 있는 이름 가운데 합친 기간 안에 든 것(그때는 a의 이름)을 뺀다. 손 개칭(위)까지 얹은 뒤에 본다
_spnd=0
for x_ in _SPLITP:
    if x_.get('normal'):continue
    flo_,tlo_=_sp_lo(x_.get('from')),_sp_lo(x_['to'])
    for y in list(names):
        if y['entity_type']!='node' or y['id']!=x_['b'] or not (y.get('valid_from') or y.get('valid_to') not in (None,'ongoing')):continue
        fh_=(lohi(y['valid_from'])[1] or '0000') if y.get('valid_from') else '0000-00-00'
        tl_=(lohi(y['valid_to'])[0] or '9999') if y.get('valid_to') not in (None,'ongoing') else '9999-12-31'
        if fh_>=flo_ and tl_<=tlo_:names.remove(y);_spnd+=1
print('나뉜 역 기간 안의 b 이름 행 뺌',_spnd)
_LINEEND=[]
_lend_by=collections.defaultdict(list)
for r_ in life:_lend_by[r_['edge_id']].append(r_)
for rid_ in sorted({s['route_id'] for s in stops}):
    es_=route_edges.get(rid_) or []
    if not es_:continue
    ends_={max((r_['valid_to'] for r_ in _lend_by[e['id']]),key=lambda v:lohi(v)[1] or '9999') if _lend_by[e['id']] else None for e in es_}
    if len(ends_)!=1:continue
    end_=next(iter(ends_))
    if end_ in (None,'ongoing'):continue
    ss_=[s for s in stops if s['route_id']==rid_ and s['is_stop'] and not s.get('is_extension')]
    if not ss_ or not all(s['valid_to'] and s['valid_to'].startswith('[') and lohi(s['valid_to'])[1]==lohi(end_)[1] and lohi(s['valid_to'])[0]==lohi(s['valid_from'] or '')[0] for s in ss_):continue
    for s in ss_:
        if s['valid_to']!=end_:_LINEEND.append((rid_,s['node_id'],s['valid_to'],end_));s['valid_to']=end_
WARN['stop_end_line_end']=_LINEEND
print('범위 정차 끝을 선 끝으로',len(_LINEEND),_LINEEND[:6])
# 기록 기준일(1950-01-01) 전에 여객 영업이 끝난 정차는 기록 대상이 아니라 열람 전용이다 (DESIGN §4.5·§4.6, 3회차 chubu_3-16·kyushu_2-09, 9회차 S).
# 그 계통의 정차 행(정차 끝이 확실히 1950-01-01 이전, 서지 않은 때로 나뉜 토막도 모두 그 전)은 지나가기만 하는 행(is_stop 0)으로 두고(노드는 선로를 가르는 데 필요해 남김)
# 같은 자리에 열람 전용 역(archive stop)을 만든다: ID a_+노드 ID 꼬리, 앞뒤는 그 계통의 가장 가까운 공개 정차역, km는 계통 km, 이름은 노드의 지금 이름(일본어·읽기·한국어·영어).
# 계통 끝 정차가 이렇게 바뀌고 그 끝 칸의 영업이 모두 기준일 전에 끝났으면(西鉄 大牟田市内線 旭町–栄町駅前 1949 휴지·1954 폐지) 그 칸은 계통에서 떼고
# 판에서 뺀다(어느 계통에도 없고 기준일 뒤 영업이 없는 칸). 같은 노드가 다른 계통에서 1950 뒤에도 서면 노드는 공개로 남고, 어디서도 서지 않으면 공개 노드에서 빠져 id_redirect가 열람 전용 ID로 잇는다
_PRE50=[];_PRE50_RED=[];_PRE50_TRIM=[]
_bys50=collections.defaultdict(list)
for s in stops:
    if not s.get('is_extension'):_bys50[s['route_id']].append(s)
_arch_ids={a['id'] for a in archive}
_nm50=collections.defaultdict(list)
for x in names:
    if x['entity_type']=='node' and not x.get('line') and not x.get('valid_from') and not x.get('valid_to'):_nm50[x['id']].append(x)
for rid_,L_ in sorted(_bys50.items()):
    L_.sort(key=lambda s:s['seq'])
    for i_,s in enumerate(L_):
        if not s['is_stop'] or s['valid_to'] in (None,'ongoing') or (lohi(s['valid_to'])[1] or '9999')>'1950-01-01':continue
        if nodes[s['node_id']]['kind']!='station':continue
        pv_=next((y['node_id'] for y in reversed(L_[:i_]) if y['is_stop'] and (y['valid_to'] in (None,'ongoing') or (lohi(y['valid_to'])[1] or '9999')>'1950-01-01')),None)
        nx_=next((y['node_id'] for y in L_[i_+1:] if y['is_stop'] and (y['valid_to'] in (None,'ongoing') or (lohi(y['valid_to'])[1] or '9999')>'1950-01-01')),None)
        aid_='a_'+s['node_id'][2:]
        if aid_ in _arch_ids:aid_=aid_+'_'+rid_[2:]
        _arch_ids.add(aid_)
        archive.append(dict(kind='stop',id=aid_,line=routes[rid_]['line'],route=rid_,after=pv_,before=nx_,opened=s['valid_from'],closed=s['valid_to'],km=s['km_cum'],source='rule:pre1950_stop',_node=s['node_id']))
        for x in _nm50[s['node_id']]:
            if x['lang'] in ('ja','ko','en'):names.append(dict({k:v for k,v in x.items() if k in ('lang','text','kana','source','checked')},entity_type='archive',id=aid_))
        s['is_stop']=0;_PRE50.append((rid_,s['node_id'],aid_,s['valid_to']))
    # 계통 끝 칸 떼기: 끝 정차가 열람 전용이 되었고 그 끝 칸의 영업 행이 모두 기준일 전에 끝났으면
    for end_ in (0,-1):
        L2_=[y for y in L_ if y in stops]
        if len(L2_)<3:break
        h_=L2_[end_]
        if h_['is_stop']:continue
        es_=[e for e in route_edges[rid_] if h_['node_id'] in (e['a'],e['b'])]
        if len(es_)!=1:continue
        e_=es_[0];ra_=[a for a in attr if a['edge_id']==e_['id']]
        if not ra_ or any(a['valid_to'] in (None,'ongoing') or (lohi(a['valid_to'])[1] or '9999')>'1950-01-01' for a in ra_):continue
        if any(e_ in route_edges[q_] for q_ in route_edges if q_!=rid_):continue
        route_edges[rid_]=[e for e in route_edges[rid_] if e is not e_]
        # 칸 자체를 판에서 뺀다: 기준일 뒤 여객 영업이 없고 어느 계통에도 없는 칸은 기록·분모·지도 어디에도 쓰이지 않는다(열람 전용 역이 그 자리를 보인다)
        _drop50={id(a) for a in ra_}
        attr[:]=[a for a in attr if id(a) not in _drop50]
        life[:]=[r9 for r9 in life if r9['edge_id']!=e_['id']]
        edges.pop(e_['id'],None);kms.pop(e_['id'],None)
        nn_=other(e_,h_['node_id'])
        stops=[y for y in stops if y is not h_]
        r_=routes[rid_]
        for k_ in ('from','to'):
            if r_[k_]==h_['node_id']:r_[k_]=nn_
        _PRE50_TRIM.append((rid_,h_['node_id'],e_['id']))
        L_=[y for y in L_ if y is not h_]
    if any(t_[0]==rid_ for t_ in _PRE50_TRIM):
        L3_=sorted((y for y in stops if y['route_id']==rid_ and not y.get('is_extension')),key=lambda y:y['seq'])
        b0_=L3_[0]['km_cum'] if L3_ and L3_[0]['km_cum'] else 0
        for j_,y in enumerate(L3_):y['seq']=j_;y['km_cum']=dround(y['km_cum']-b0_) if y['km_cum'] is not None else None
        for a in archive:
            if a.get('route')==rid_ and a.get('source')=='rule:pre1950_stop' and a.get('km') is not None:a['km']=dround(a['km']-b0_)
_gid={id(s) for s in stops};stop_gaps=[g_ for g_ in stop_gaps if id(g_[0]) in _gid]
_still50={s['node_id'] for s in stops if s['is_stop']}
# 다른 열람 전용 역의 앞뒤가 이번에 열람 전용이 된 노드면(그 계통에서) 그 열람 전용 ID로 잇는다(DESIGN §4.5 after는 열람 전용 ID도 된다)
_a50={(r_,n_):a_ for r_,n_,a_,_ in _PRE50}
for a in archive:
    if a.get('kind')!='stop' or a.get('source')=='rule:pre1950_stop':continue
    for k_ in ('after','before'):
        if (a.get('route'),a.get(k_)) in _a50:a[k_]=_a50[(a['route'],a[k_])]
_PRE50_RED=sorted({(n_,a_) for _,n_,a_,_ in _PRE50 if n_ not in _still50})
WARN['pre1950_stop_archived']=_PRE50
print('기준일 전에 끝난 정차를 열람 전용으로',len(_PRE50),'공개 노드에서 빠짐',len(_PRE50_RED),'계통 끝 칸 뗌',_PRE50_TRIM)
# 끝 역이 km를 모르는 仮乗降場·臨時駅이면(小松島港: 小松島駅 구내, 공식 営業キロ는 中田–小松島 1.9 km) 그 끝 칸은 분모 밖이다.
# DESIGN §4.5 「끝 역이면 이웃 역 자리」의 뜻(분모 불변)과 불변식(0.05 km 미만 칸 0개)을 함께 지킨다 (2회차 종합 U18)
_EST0={(x['route'],SPLIT.get((routes.get(x['route'],{}).get('line'),x['node']),x['node'])) for x in load('stops')}
_ssp0=os.path.join(ROOT,'data','overrides','stop_status.json')
_TEMPN={x['node'] for x in (json.load(open(_ssp0,encoding='utf-8')) if os.path.exists(_ssp0) else [])}
_endx=[]
for rid_,L_ in _bys.items():
    if not L_:continue
    for h_ in (L_[0],L_[-1]):
        if not h_['is_stop'] or (rid_,h_['node_id']) not in _EST0 or h_['node_id'] not in _TEMPN:continue
        l_=routes[rid_]['line']
        # 그 노선 선로의 막다른 끝일 때만 (옛 경로 계통의 끝이 본선 역인 경우는 아니다)
        if sum(1 for e in adj[h_['node_id']] if e['id'] in line_e[l_])!=1:continue
        for e in route_edges[rid_]:
            if h_['node_id'] not in (e['a'],e['b']):continue
            for a_ in attr:
                if a_['edge_id']==e['id'] and a_['line_id']==l_ and a_['denominator_class']=='normal':a_['denominator_class']='extra';_endx.append((rid_,e['id']))
print('km 모르는 仮·臨 끝 역 칸을 분모 밖으로',_endx)
# 기록 기준일(1950-01-01) 전에 끝난 여객 영업 행은 기록할 수 없어 분모 밖이다(DESIGN §4.6 「기준일 이전 폐지」: 불가·제외).
# 날짜 모름 기록은 그 칸에도 크레딧을 주므로(불변식 2: 크레딧은 분모 단위 안) 단위가 없는 hidden이 아니라 extra로 둔다 (大阪市電 西野田線 1932 비영업선화, 2회차 종합 K35)
_pre1950=[]
for a_ in attr:
    if a_['denominator_class']=='normal' and a_['valid_to'] not in (None,'ongoing') and (lohi(a_['valid_to'])[1] or '9999')<='1950-01-01':
        a_['denominator_class']='extra';_pre1950.append((a_['edge_id'],a_['line_id'],a_['valid_to']))
print('기준일 전에 끝난 영업 행을 분모 밖으로',len(_pre1950),_pre1950[:10])
# 분모
def overlap_year(a,y):
    # 그해에 확실히 영업한 행만. 날짜가 애매하면 판정 불가로 빠진다 (DESIGN §5.4)
    return year_status(a['valid_from'],a['valid_to'],y)=='yes'
def active_on(a,day):
    lo=lohi(a['valid_from'])[0] or '0000-00-00';hi=lohi(a['valid_to'])[0] or '9999-12-31'
    return lo<=day<hi
units=collections.defaultdict(list)
for a in attr:
    units[('on',a['lineage_id'],a['edge_id'])].append(a)
    units[('off',a['carryover_group'],a['edge_id'])].append(a)
unit_rows=[]
for (c,k,x),rows in units.items():
    cls='normal' if any(a['denominator_class']=='normal' for a in rows) else rows[0]['denominator_class']
    # 여객 영업 이력이 없는 화물선(hidden)은 DB에만 둔다. 분모 단위가 없어 목록·요약에 나오지 않는다 (사용자 결정 2026-11-09)
    if cls=='hidden':continue
    vf=min((lohi(a['valid_from'])[0] or '0000-00-00',a['valid_from'] or '') for a in rows)[1] or None
    vt=max((lohi(a['valid_to'])[1] or '9999-12-30',a['valid_to'] or '') for a in rows)[1] or None
    # 단위 km는 그 단위의 마지막 행(끝이 가장 늦은 행) 노선 시대의 km다(DESIGN §2.8 C 「역대 분모: 영업 중이면 지금, 끝난 단위는 종료 직전」).
    # 승계 끔의 국철·JR 단위는 그 시대 km(ERA), 국철→사철·사철 사이 이관이 한 단위에 섞이면 마지막 사업자 시기의 km다. 노선 시대 km가 없으면 칸 km(마지막 값)다.
    # 예전 규칙(끔 단위의 모든 행이 시대 km일 때만)은 한 승계 단위 안에서 사업자 시기별로 km가 다른 칸(弘南 黒石線 川部–前田屋敷)을 나타내지 못했다 (3회차 tohoku_1-001, 9회차 S)
    lr_=max(rows,key=lambda a:(lohi(a['valid_to'])[1] or '9999-12-31',lohi(a['valid_from'])[0] or ''))
    unit_rows.append(dict(unit_key=f'{k}:{x}',carryover=c,edge_id=x,km=ERA.get((lr_['line_id'],x),kms.get(x,0)),cls=cls,valid_from=vf,valid_to=vt))
cur=collections.Counter();curop=collections.Counter();curline=collections.Counter();alltime=collections.Counter()
for a in attr:
    if a['denominator_class']=='normal' and active_on(a,TODAY):
        k=kms.get(a['edge_id'],0)
        curop[a['operator_id']]+=k;curline[a['line_id']]+=k
for u in unit_rows:
    if u['cls']=='normal':alltime[u['carryover']]+=u['km']
cuniq={}
for a in attr:
    if a['denominator_class']=='normal' and active_on(a,TODAY):cuniq[(a['lineage_id'],a['edge_id'])]=kms.get(a['edge_id'],0)
denom=[dict(scope='all',basis='current',carryover='on',km=round(sum(cuniq.values()),1),unit_count=len(cuniq)),
       dict(scope='all',basis='alltime',carryover='on',km=round(alltime['on'],1),unit_count=sum(1 for u in unit_rows if u['carryover']=='on' and u['cls']=='normal')),
       dict(scope='all',basis='alltime',carryover='off',km=round(alltime['off'],1),unit_count=sum(1 for u in unit_rows if u['carryover']=='off' and u['cls']=='normal'))]
for y in range(1950,int(TODAY[:4])+1):   # 기준일의 해부터 (§4.6)
    s={}
    for a in attr:
        if a['denominator_class']=='normal' and overlap_year(a,y):s[(a['lineage_id'],a['edge_id'])]=kms.get(a['edge_id'],0)
    denom.append(dict(scope='all',basis=str(y),carryover='on',km=round(sum(s.values()),1),unit_count=len(s)))
for o,k in curop.items():denom.append(dict(scope=o,basis='current',carryover='on',km=round(k,1),unit_count=None))
for l,k in curline.items():denom.append(dict(scope=l,basis='current',carryover='on',km=round(k,1),unit_count=None))

# 같은 역 묶음(group) = 같은 역 (DESIGN §2.8 B, S2 판정). 생성기·이전 쌍·이름이 묶었어도 아래 쌍은 서로 다른 역이라 묶음을 가른다 (3회차 전수 점검 kanto_3-03·kanto_3-04·kyushu_2-04·kyushu_1-016·tohoku_1-008, 8회차 W1b):
#  ① 같은 계통에서 같은 날 둘 다 정차(京浜逗子–逗子海岸, 北馬場–南馬場, 初代 桜町–小川町→桜町). 두 옛 역이 한 새 역으로 합쳐진 이전 쌍이 옛 두 역을 잇던 꼴
#  ② 서로 다른 이전 쌍의 옛 자리 둘이 같은 날 함께 영업했는데 이전 전 묶음이 달랐음(모노레일 羽田（旧）–京急 羽田空港（旧）)
#  ③ 환승 아님 표(hub_not)의 쌍(秋田市電 土崎–JR 土崎, 大阪市電 今里–近鉄 今里)
#  ④ 묶음 안에서 함께 영업·이전·하루 안 인계로 이어지지 않는 노드(熊本電鉄 広町·京町口 ~1953 → 市電 1954~, 15개월 공백·사업자 다름)
# 가를 때는 남길 쪽을 정하고 나머지를 새 묶음(g_+노드)으로 뗀다. 남는 쪽: 묶음 이름의 노드 > 새 자리와 가까운 옛 자리 > 먼저 연 역
def _grp_split():
    _sp=collections.defaultdict(list)
    for s_ in stops:
        if s_['is_stop'] and not s_.get('is_extension'):_sp[s_['node_id']].append((s_['route_id'],lohi(s_['valid_from'])[1] or '0000',lohi(s_['valid_to'])[0] or '9999-12-31',lohi(s_['valid_from'])[0] or '0000',lohi(s_['valid_to'])[1] or '9999-12-31'))
    def must(p,q):return p[1]<q[2] and q[1]<p[2]
    def may(p,q):return p[3]<q[4] and q[3]<p[4]
    def first(x):return min((p[3] for p in _sp[x]),default='9999')
    _mvp={frozenset(p_) for p_ in _MVPAIRS}
    def dkm(a,b):return math.sqrt(_d2(a,b))*111.2 if a in _pos and b in _pos else 9e9
    _hn={k_ for k_ in HUBNOT_ID}
    byg=collections.defaultdict(list)
    for k_,v_ in nodes.items():
        if v_.get('group'):byg[v_['group']].append(k_)
    out=[]
    for g_,ns_ in sorted(byg.items()):
        if len(ns_)<2:continue
        cut=set()
        def pick(a,b,why):
            # 남길 쪽
            if 'g_'+a[2:]==g_:keep,drop=a,b
            elif 'g_'+b[2:]==g_:keep,drop=b,a
            elif a in _mvto and b in _mvto:keep,drop=(a,b) if dkm(a,_mvto[a])<=dkm(b,_mvto[b]) else (b,a)
            elif a in _mvto and b not in _mvto:keep,drop=b,a
            elif b in _mvto and a not in _mvto:keep,drop=a,b
            else:keep,drop=(a,b) if (first(a),a)<=(first(b),b) else (b,a)
            if keep in cut:keep,drop=drop,keep
            if drop not in cut:cut.add(drop);out.append((g_,keep,drop,why))
        for i_,a in enumerate(sorted(ns_)):
            for b in sorted(ns_)[i_+1:]:
                f_=frozenset((a,b))
                if f_ in _mvp:continue
                if any(p[0]==q[0] and must(p,q) for p in _sp[a] for q in _sp[b]):pick(a,b,'same_route');continue
                if a in _mvto and b in _mvto and _mvto[a]!=_mvto[b] and _GRP_PRE.get(a)!=_GRP_PRE.get(b) and any(must(p,q) for p in _sp[a] for q in _sp[b]):pick(a,b,'move_olds');continue
                if f_ in _hn:pick(a,b,'hub_not')
        # ④ 이어짐 그래프의 덩어리
        live=[x for x in ns_ if _sp[x] and x not in cut]
        par={x:x for x in live}
        def fd(x):
            while par[x]!=x:par[x]=par[par[x]];x=par[x]
            return x
        def near_day(e,s):
            try:return abs((_dt0.date.fromisoformat(s[:10])-_dt0.date.fromisoformat(e[:10])).days)<=1
            except ValueError:return False
        for i_,a in enumerate(live):
            for b in live[i_+1:]:
                if frozenset((a,b)) in _mvp or any(may(p,q) or near_day(p[4],q[3]) or near_day(q[4],p[3]) for p in _sp[a] for q in _sp[b]):par[fd(a)]=fd(b)
        cs_=collections.defaultdict(list)
        for x in live:cs_[fd(x)].append(x)
        if len(cs_)>1:
            main=min(cs_.values(),key=lambda c:(not any('g_'+x[2:]==g_ for x in c),min(first(x) for x in c)))
            for c in cs_.values():
                if c is main:continue
                for x in c:
                    if x not in cut:cut.add(x);out.append((g_,main[0],x,'no_cowork'))
        # 뗀 노드와 이전 쌍으로 이어진 노드(뗀 노드의 옛 자리)는 함께 간다
        for x in sorted(cut):
            ng='g_'+x[2:]
            while any(v_.get('group')==ng for v_ in nodes.values()) and ng!=nodes[x].get('group'):ng+='_2'
            if ng==g_:ng=g_+'_2'
            mates=[y for y in ns_ if y not in cut and frozenset((x,y)) in _mvp and _mvto.get(y)==x]
            for y in [x]+mates:nodes[y]['group']=ng
            if not any(gg['id']==ng for gg in groups):groups.append(dict(id=ng))
    return out
HUBNOT_ID={frozenset((x_['node'],x_['with'])) for x_ in json.load(open(os.path.join(ROOT,'data','overrides','hub_not.json'),encoding='utf-8')) if isinstance(x_,dict)}
GROUP_SPLIT=_grp_split()
for x_ in GROUP_SPLIT:WARN['group_split_rule'].append(x_)
print('같은 역 묶음 규칙으로 가른 노드',len(GROUP_SPLIT))
# 여객 영업 이력이 없는 화물선(rule_class hidden)의 계통에는 정차가 없다. 기점 역이 다른 노선의 정차역이거나 손 정차 기간(stop_dates 노드 행)이 있어도
# 이 계통에서는 서지 않아 환승·이음·공개 노드가 생기지 않는다 (9회차 F, 사용자 결정 2026-11-09)
_HID_R={r_ for r_,v_ in routes.items() if lines.get(v_['line'],{}).get('rule_class')=='hidden'}
for s in stops:
    if s['route_id'] in _HID_R:s['is_stop']=0
# route_link: 표시 결정표 (§2.9)
ppos={p['node']:p for p in positions if p.get('lat') is not None}
node_stops=collections.defaultdict(list)
by_route=collections.defaultdict(list)
for s in stops:
    by_route[s['route_id']].append(s)
    if s['is_stop']:node_stops[s['node_id']].append(s)
for v in by_route.values():v.sort(key=lambda s:s['seq'])
# 환승 쌍 (재설계 통합 int_identity 규칙, redesign §2 결정 6). 후보는 환승 묶음 안의 쌍과 나눈 노드–원 노드 묶음의 쌍이다.
# ① 두 역이 함께 선 기간이 있고 ② 같은 노선(이웃 역 포함)을 함께 갖지 않고 ③ hub_not 행이 아니며 ④ 근거가 하나 있을 때만 환승이다.
# 근거: 같은 group, 손 표(hub_join·hub_pairs·위키 노선도 wikipedia.yaml), 같은 이름 500 m 안(회사 접두·駅前 꼬리를 뗀 이름 포함),
# X駅前·X駅–X 500 m 안, 역 문서 乗換 칸, 150 m 안. 300 m 근접만으로는 근거가 아니다 (spec H1).
# hub는 채택 쌍의 연결 성분으로 다시 만들고 쌍이 없는 노드는 hub에서 뺀다
import unicodedata
_HUBEV=json.load(open(os.path.join(SRC,'hubs','hub_evidence.json'),encoding='utf-8'))
JA={x['id']:x['text'] for x in names if x['entity_type']=='node' and x['lang']=='ja' and not x.get('valid_to') and not x.get('valid_from') and not x.get('line')}
# 손 환승 쌍 (data/overrides/hub_pairs.json). 노드 ID 쌍이고 늘 후보다. 옛 형식(일본어 이름 쌍)도 읽는다. 채택 쌍이 안 되는 행은 오류 (2회차 종합 K06)
_HPX=json.load(open(os.path.join(ROOT,'data','overrides','hub_pairs.json'),encoding='utf-8'))
HUBX_ID={};HUBX={}
for i_,p_ in enumerate(_HPX):
    if all(isinstance(x_,str) and x_.startswith('n_') for x_ in p_):
        if not all(x_ in nodes for x_ in p_):
            if not _nopatch:err('hub_pairs_unknown',p_)
            continue
        HUBX_ID[frozenset(p_)]=i_
    else:HUBX[frozenset(p_)]=i_
HJ={frozenset((x['node'],x['with'])) for x in json.load(open(os.path.join(ROOT,'data','overrides','hub_join.json'),encoding='utf-8'))}
# hub_not: 노드 ID 행 {node, with, why}. 옛 형식(이름 쌍)도 읽는다. 쓰이지 않는 행은 오류
_HN=json.load(open(os.path.join(ROOT,'data','overrides','hub_not.json'),encoding='utf-8'))
HUBNOT={};HUBNOT_NM={}
for i_,x_ in enumerate(_HN):
    if isinstance(x_,dict):
        if x_['node'] not in nodes or x_['with'] not in nodes:
            if not _nopatch:err('hub_not_unknown',x_)
            continue
        HUBNOT[frozenset((x_['node'],x_['with']))]=i_
    else:HUBNOT_NM[frozenset(x_)]=i_
_hn_used=set()
def hub_not(a,b):
    i_=HUBNOT.get(frozenset((a,b)),HUBNOT_NM.get(frozenset((JA.get(a),JA.get(b)))))
    if i_ is None:return False
    _hn_used.add(i_);return True
# 같은 역 묶음 규칙(③ 환승 아님 표)으로 가른 쌍은 그 행이 쓰인 것이다
for _g,_a,_b,_w in GROUP_SPLIT:
    if _w=='hub_not':hub_not(_a,_b)
# 역 문서 乗換 칸 근거. 생성기가 문서 근거 쌍을 xf로 따로 적으면 그것을 쓴다. 지금 evid에는 「공통 노선 없이 아주 가까운」 근접 쌍이 섞여 있어,
# xf가 없으면 두 역 다 문서가 없는 evid 쌍(근접으로만 들어간 것)을 뺀다. 문서가 있는 역의 근접 쌍(150~250 m)은 남는 근사다
_EVID={frozenset(p_) for p_ in _HUBEV['evid']}
_DOCN=set(_HUBEV.get('doc',[]))
_DOC={frozenset(p_) for p_ in _HUBEV['xf']} if 'xf' in _HUBEV else {f_ for f_ in _EVID if f_&_DOCN}
def _xn(t):
    t=unicodedata.normalize('NFKC',t or '')
    for a_,b_ in (('ヶ','ケ'),('ヵ','ケ'),('之','ノ'),('﨑','崎'),('髙','高'),('澤','沢'),('濱','浜')):t=t.replace(a_,b_)
    return re.sub(r'[（(].*$','',t)
# 「電鉄」은 같은 이름 국철 역과 구별하려고 붙인 머리다(山陽 電鉄亀山–播但線 亀山, 위키 山陽電気鉄道本線 rev111474989 1991 개칭 주 「『電鉄』を外したのは…それらの駅と区別する必要がなくなった」). 다른 회사 머리처럼 떼고 같은 이름을 본다.
# 거리(500 m)·함께 선 기간·hub_not 조건은 그대로다(電鉄飾磨–飾磨 920 m, 電鉄高砂–高砂 hub_not) (4회차 kinki_1-05, 11회차 S2)
_CO=re.compile(r'^(JR|京成|京王|小田急|近鉄|名鉄|西武|東武|京急|地下鉄|市電|電鉄)')
# 정류장 이름 꼬리: X駅前·X前·X駅東口, 회사 이름이 붙은 X阪神電車前·X阪急前 (野田阪神電車前–野田, 2회차 종합 K06)
_COT=re.compile(r'(阪神|阪急|京阪|南海|近鉄|国鉄|省線|市電|電鉄)?(電車前|駅前|前|駅東口)$')
def _core(t):return _COT.sub('',_CO.sub('',_xn(t)))
def _far(a,b):
    """두 노드가 정밀 좌표로 400 m 넘게 떨어졌는가"""
    return all((ppos.get(x_) or {}).get('quality')=='precise' for x_ in (a,b)) and _dm(a,b)>400
def _dm(a,b):
    p,q=ppos.get(a),ppos.get(b)
    if not p or not q:return 9e9
    return 6371000*math.hypot(math.radians(q['lat']-p['lat']),math.radians(q['lon']-p['lon'])*math.cos(math.radians(p['lat'])))
_nl=collections.defaultdict(set);_adjp=set();_sspan=collections.defaultdict(list)
for rid_,L_ in by_route.items():
    prev_=None
    for s_ in L_:
        if not s_['is_stop']:continue
        _nl[s_['node_id']].add(routes[rid_]['line'])
        _sspan[s_['node_id']].append(s_)
        if prev_ and prev_!=s_['node_id']:_adjp.add(frozenset((prev_,s_['node_id'])))
        prev_=s_['node_id']
_lops=collections.defaultdict(set)
for a_ in attr:_lops[a_['line_id']].add(a_['operator_id'])
def _ops_of(n):
    """그 역에 서는 노선들의 사업자(모든 시기)"""
    return {o_ for l_ in _nl[n] for o_ in _lops[l_]}
def _together(a,b):
    """두 역이 함께 선 기간 (늦은 시작, 이른 끝). 없으면 None"""
    if not _sspan[a] or not _sspan[b]:return None
    fa=min((s_['valid_from'] for s_ in _sspan[a]),key=lambda v:lohi(v)[0]);ua=max((s_['valid_to'] for s_ in _sspan[a]),key=lambda v:lohi(v)[1])
    fb=min((s_['valid_from'] for s_ in _sspan[b]),key=lambda v:lohi(v)[0]);ub=max((s_['valid_to'] for s_ in _sspan[b]),key=lambda v:lohi(v)[1])
    f_=max((fa,fb),key=lambda v:lohi(v)[0]);u_=min((ua,ub),key=lambda v:lohi(v)[1])
    return (f_,u_) if lohi(f_)[0]<lohi(u_)[1] else None
# 역 이전 쌍(moved.json). 같은 역의 옛 자리와 새 자리라 같은 노선을 함께 갖고 이웃 정차이기도 하다.
# 다른 노선이 그 시절 다른 쪽 노드에 섰으면(志布志 日南線 옛 자리–志布志線, 江戸橋 名古屋線 옛 자리–伊勢線, 浜大津 石坂線 옛 자리–京津線) 환승이다
MOVEDPAIR={frozenset((mv['old'],mv['new'])) for mv in json.load(open(os.path.join(ROOT,'data','overrides','moved.json'),encoding='utf-8')) if mv['old'] in nodes and mv['new'] in nodes}
MOVEPART=collections.defaultdict(set)
for f_ in MOVEDPAIR:
    a_,b_=sorted(f_);MOVEPART[a_].add(b_);MOVEPART[b_].add(a_)
def _ov2(x,y):
    lo_=max(lohi(x['valid_from'])[0] or '0000',lohi(y['valid_from'])[0] or '0000')
    hi_=min('9999-12-31' if x['valid_to'] in (None,'ongoing') else (lohi(x['valid_to'])[1] or '9999-12-31'),'9999-12-31' if y['valid_to'] in (None,'ongoing') else (lohi(y['valid_to'])[1] or '9999-12-31'))
    return lo_<hi_
# 노드의 일본어 이름 이력(노선 한정이 아닌 기간 행). 기간 밖은 지금 이름이다
_NHIST=collections.defaultdict(list)
for x in names:
    if x['entity_type']=='node' and x['lang']=='ja' and not x.get('line') and x.get('valid_to') not in (None,'ongoing'):
        _NHIST[x['id']].append(((lohi(x.get('valid_from'))[0] or '0000-01-01') if x.get('valid_from') else '0000-01-01',lohi(x['valid_to'])[0] or '9999-12-31',x['text']))
def _name_on(n,day):
    for lo_,hi_,t_ in _NHIST.get(n,()):
        if lo_<=day<hi_:return t_
    return JA.get(n) or ''
def _names_together(a,b,tg):
    """두 역이 함께 선 기간 tg=(시작, 끝)의 날마다 (a 이름, b 이름). 이름이 바뀌는 날마다 한 쌍"""
    lo_=lohi(tg[0])[0] or '0000-01-01';hi_='9999-12-31' if tg[1] in (None,'ongoing') else (lohi(tg[1])[1] or '9999-12-31')
    ds_={lo_}|{d_ for n_ in (a,b) for p_,q_,_ in _NHIST.get(n_,()) for d_ in (p_,q_) if lo_<d_<hi_}
    return sorted({(_name_on(a,d_),_name_on(b,d_)) for d_ in ds_})
# 나뉜 역 쌍(split_period): 나뉘기 전은 한 역이라 환승이 아니고, 나뉜 뒤(또는 합치기 전) 두 역이 함께 선 기간만 환승이다.
# 같은 노선이 두 노드를 다 지나도(넣은 같은 km 점 칸) 다른 기간의 두 역이라 이웃·같은 노선 규칙으로 버리지 않는다. 기간은 서지 않은 때를 뺀 토막으로 잰다
SPLITPAIR={frozenset((x_['a'],x_['b'])):x_ for x_ in _SPLITP if not x_.get('normal')}
def _sp_segs(x):
    out_=[]
    for s_ in stops:
        if s_['node_id']!=x or not s_['is_stop'] or s_.get('is_extension'):continue
        segs_=[(_sp_lo(s_['valid_from']),_sp_hi(s_['valid_to']))]
        for g_ in stop_gaps:
            if g_[0] is not s_:continue
            g0_,g1_=_sp_lo(g_[1]),('9999-12-31' if g_[2] in (None,'ongoing') else _sp_lo(g_[2]))
            segs_=[y_ for a_,b_ in segs_ for y_ in ((a_,min(b_,g0_)),(max(a_,g1_),b_)) if y_[0]<y_[1]]
        out_+=segs_
    # 여러 계통 토막을 합친다(그 역이 선 때)
    out_.sort();m_=[]
    for a_,b_ in out_:
        if m_ and a_<=m_[-1][1]:m_[-1]=(m_[-1][0],max(m_[-1][1],b_))
        else:m_.append((a_,b_))
    return m_
def _sp_together(a,b):
    """나뉜 역 쌍이 함께 선 마지막 토막 (시작, 끝). 그 노드의 정차 원문 날짜를 돌려준다"""
    best_=None
    for a0_,a1_ in _sp_segs(a):
        for b0_,b1_ in _sp_segs(b):
            lo_,hi_=max(a0_,b0_),min(a1_,b1_)
            if lo_<hi_ and (not best_ or lo_>best_[0]):best_=(lo_,hi_)
    if not best_:return None
    return (best_[0],'ongoing' if best_[1]=='9999-12-31' else best_[1])
def hub_rule(a,b,src):
    """채택 근거. 환승이 아니면 None"""
    f_=frozenset((a,b))
    if f_ in SPLITPAIR:return None if hub_not(a,b) or not _sp_together(a,b) else 'split'
    if f_ in MOVEDPAIR:
        # 그 시절 두 노드에 서로 다른 노선이 함께 섰을 때만
        if hub_not(a,b) or not _together(a,b) or not any(_ov2(x,y) for x in _sspan[a] for y in _sspan[b] if routes[x['route_id']]['line']!=routes[y['route_id']]['line']):return None
        return 'moved'
    if not _together(a,b) or f_ in _adjp or _nl[a]&_nl[b] or hub_not(a,b):return None
    d_=_dm(a,b)
    # 같은 group은 같은 역이다. 다만 400 m 넘게 떨어진 다른 사업자 노드는 이름만 같은 다른 역일 수 있어(都電 両国–JR 両国 537 m) 다른 근거를 본다 (K07).
    # 거리는 두 좌표가 모두 정밀할 때만 근거다. 대략 좌표(노면전차 정류장의 N05 근사)의 거리로는 같은 역 묶음을 깨지 않는다 (2회차 종합 K06: 赤羽·大曽根·丹波橋)
    # 두 역이 다 다른 이전 쌍의 옛 자리이고 사업자가 다르면(京急 (初代)羽田空港–모노레일 옛 羽田, 둘 다 지금 天空橋 묶음) 옮기기 전 묶음이 같을 때만 같은 역이다
    _og=a in _mvto and b in _mvto and not _ops_of(a)&_ops_of(b) and _GRP_PRE.get(a)!=_GRP_PRE.get(b)
    if nodes[a].get('group')==nodes[b].get('group') and not _og and (not _far(a,b) or _ops_of(a)&_ops_of(b)):return 'same_group'
    if f_ in HJ or f_ in HUBX_ID or 'hand' in src or 'wikipedia' in src or frozenset((JA.get(a),JA.get(b))) in HUBX:return 'hand'
    # 이름 근거는 두 역이 함께 선 날의 그날 이름으로 본다. 지금 이름만 보면 山陽 電鉄高砂(~1991)가 국철 高砂(~1984)와 「高砂」로 묶인다 (8회차 W3 요청 2, 9회차 N)
    tg_=_together(a,b)
    if d_<=500 and tg_:
        # 「ノ」만 다른 표기(西ノ宮–西宮駅前, JR 西宮은 2007년까지 西ノ宮)는 같은 이름이다
        def _no(t_):return t_.replace('ノ','').replace('の','')
        for ja_,jb_ in _names_together(a,b,tg_):
            if _xn(ja_)==_xn(jb_) or _core(ja_)==_core(jb_) or _no(_core(ja_))==_no(_core(jb_)):return 'same_name'
        for ja_,jb_ in _names_together(a,b,tg_):
            if any(_no(_xn(q_)) in (_no(_xn(p_))+'駅前',_no(_xn(p_))+'駅') for p_,q_ in ((ja_,jb_),(jb_,ja_))):return 'ekimae'
    # 역 문서 乗換 칸 근거는 500 m 안만 (사용자 판단 U01: 本川越–川越 773 m·阪急嵐山–嵐電嵯峨 680 m는 뗌. 그보다 먼 공식 환승은 손 표로)
    if f_ in _DOC and d_<=500:return 'doc'
    if d_<=150:return 'near_150'
    return None
_cand={}
for h in hubs:
    ms_=sorted(m for m in h['nodes'] if m in nodes)
    for i_,a_ in enumerate(ms_):
        for b_ in ms_[i_+1:]:_cand.setdefault(frozenset((a_,b_)),set()).update(h.get('source') or [])
for new_,n_ in SPLIT_OF.items():
    for m in {n_}|{m for h in hubs if n_ in h['nodes'] for m in h['nodes']}:
        if m!=new_ and m in nodes:_cand.setdefault(frozenset((new_,m)),set()).update(s_ for h in hubs if n_ in h['nodes'] for s_ in h.get('source') or [])
for f_ in MOVEDPAIR:_cand.setdefault(f_,set()).add('moved')
# 손 표(hub_join·hub_pairs) 쌍은 묶음 밖이어도 늘 후보다 (쪼갠 노드의 간접환승 등)
for f_ in list(HJ)+list(HUBX_ID):
    if all(x_ in nodes for x_ in f_):_cand.setdefault(f_,set()).add('hand')
# 같은 group의 모든 쌍과 500 m 안 정차역 쌍도 후보다. 묶음(hubs.yaml)에 빠진 노드(馬喰横山·天空橋–モノレール羽田)도 근거가 있으면 환승이 된다 (K06)
_byg=collections.defaultdict(list)
for n_,x_ in nodes.items():
    if x_.get('group') and _sspan.get(n_):_byg[x_['group']].append(n_)
for v_ in _byg.values():
    v_=sorted(v_)
    for i_,a_ in enumerate(v_):
        for b_ in v_[i_+1:]:_cand.setdefault(frozenset((a_,b_)),set())
_grid=collections.defaultdict(list)
for n_ in _sspan:
    p_=ppos.get(n_)
    if p_:_grid[(int(p_['lat']/.005),int(p_['lon']/.006))].append(n_)
for (gy_,gx_),v_ in _grid.items():
    for a_ in v_:
        for dy_ in (-1,0,1):
            for dx_ in (-1,0,1):
                for b_ in _grid.get((gy_+dy_,gx_+dx_),()):
                    if a_<b_ and _dm(a_,b_)<=500:_cand.setdefault(frozenset((a_,b_)),set())
HUBPAIR={}
for f_,src_ in sorted(_cand.items(),key=lambda kv:sorted(kv[0])):
    a_,b_=sorted(f_);why_=hub_rule(a_,b_,src_)
    if why_:HUBPAIR[f_]=(why_,src_)
# 역앞 정류장은 그 역 묶음 전체와 환승이다. 정류장 A가 그날 이름으로 X 역과 이름 근거(역앞·같은 이름) 쌍이고, X가 B와 센 근거(같은 group·150 m·문서·손 표·같은 이름) 쌍이면,
# A–B도 500 m 안·함께 선 기간이면 환승이다. 그날 이름 판정(9회차 N) 뒤 名古屋駅前 ↔ 新名古屋(名鉄)처럼 역앞 이름이 상대 사철 역의 옛 이름과 안 맞아 빠진 쌍을 되살린다
# (名古屋駅前·岐阜駅前·川崎駅前·東神奈川駅前·市電川崎 등, 10회차 G1 chubu_3-011). A의 그날 이름이 X와 이름 근거가 없는 역(電鉄高砂–高砂)은 되살리지 않는다
_viaek=[]
_hpn=collections.defaultdict(list)
for f_,(w_,_) in HUBPAIR.items():
    a_,b_=sorted(f_);_hpn[a_].append((b_,w_));_hpn[b_].append((a_,w_))
for a_ in list(_hpn):
    for x_,w1_ in list(_hpn[a_]):
        if w1_ not in ('ekimae','same_name'):continue
        for b_,w2_ in list(_hpn[x_]):
            f2_=frozenset((a_,b_))
            if b_==a_ or w2_ not in ('same_group','near_150','doc','hand','same_name') or f2_ in HUBPAIR:continue
            if f2_ in _adjp or _nl[a_]&_nl[b_] or hub_not(a_,b_) or not _together(a_,b_) or _dm(a_,b_)>500:continue
            # 지금 이름으로는 같은 역(역앞·같은 이름)인 쌍만 되살린다. 새 쌍을 만들지 않는다(그날 이름 판정 전 기준판에 있던 쌍)
            ja0_,jb0_=_xn(JA.get(a_) or ''),_xn(JA.get(b_) or '')
            if not (_core(ja0_)==_core(jb0_) or any(q_ in (p_+'駅前',p_+'駅') for p_,q_ in ((ja0_,jb0_),(jb0_,ja0_)))):continue
            HUBPAIR[f2_]=('ekimae',_cand.get(f2_,set()));_viaek.append(tuple(sorted(f2_)))
print('역앞 정류장의 역 묶음 환승',len(_viaek),sorted(_viaek)[:30])
for f_,i_ in HUBX_ID.items():
    if f_ not in HUBPAIR:err('hub_pairs_unused',sorted(f_))
for f_,i_ in HUBX.items():
    if not any(frozenset((JA.get(x_),JA.get(y_)))==f_ for x_,y_ in (sorted(k_) for k_ in HUBPAIR)):err('hub_pairs_unused',sorted(f_))
# 같은 group 쌍도 hub_not이면 환승으로 잇지 않는다 (linked). 쓰였는지 보려고 group 쌍도 한 번 본다
for f_ in list(HUBNOT):
    a_,b_=sorted(f_)
    if nodes[a_].get('group')==nodes[b_].get('group'):hub_not(a_,b_)
for i_,x_ in enumerate(_HN):
    if i_ not in _hn_used and (not isinstance(x_,dict) or frozenset((x_['node'],x_['with'])) in HUBNOT):err('hub_not_unused',x_)
# hub = 채택 쌍의 연결 성분. ID는 겹치는 옛 hub ID를 되도록 그대로 쓴다
_par={}
def _hf(x):
    while _par.setdefault(x,x)!=x:_par[x]=_par[_par[x]];x=_par[x]
    return x
for f_ in HUBPAIR:
    a_,b_=sorted(f_);_par[_hf(a_)]=_hf(b_)
_comp=collections.defaultdict(list)
for x_ in list(_par):_comp[_hf(x_)].append(x_)
_old=sorted(hubs,key=lambda h:h['id']);_new=[];_taken=set()
for ms_ in sorted((sorted(v) for v in _comp.values()),key=lambda v:v[0]):
    S_=set(ms_);ov_=[h for h in _old if S_&set(h['nodes'])]
    pick_=max((h for h in ov_ if h['id'] not in _taken),key=lambda h:(len(S_&set(h['nodes'])),-len(set(h['nodes'])-S_)),default=None)
    i_=pick_['id'] if pick_ else 'hub_'+ms_[0][2:]
    # 옛 hub ID의 이름 노드가 이 hub에서 빠졌으면(hub_chuohanamaki에 中央花巻 없음) 지금 멤버로 새로 짓는다. hub ID는 잠금 대상이 아니다
    if pick_ and ('n_'+i_[4:]) in nodes and ('n_'+i_[4:]) not in S_ and ('hub_'+ms_[0][2:]) not in _taken:i_='hub_'+ms_[0][2:]
    while i_ in _taken:i_+='_2'
    _taken.add(i_)
    _new.append(dict(id=i_,nodes=ms_,source=sorted({s_ for h in ov_ for s_ in h.get('source') or []}),verified=any(h.get('verified') for h in ov_)))
print('환승 쌍 후보',len(_cand),'채택',len(HUBPAIR),dict(collections.Counter(v[0] for v in HUBPAIR.values())),'hub',len(hubs),'->',len(_new))
hubs=_new
hubmem=collections.defaultdict(set)
for h in hubs:
    for n in h['nodes']:hubmem[n].add(h['id'])
hubn={h['id']:h['nodes'] for h in hubs}
# (노드 나누기·합치기를 마친 뒤에 붙인다: 나눈 노드(都電 赤羽橋 등)를 가리키는 행이 있다)
# 노면전차 운행 계통표(data/overrides/tram_systems.json, 3회차 kanto_1-007·tohoku_1-007): 계통이 노선 경계를 넘는 곳은 선로가 이어져 있다.
# 그 쌍의 연결 행을 손 확인 행으로 두고(없으면 만든다), 계통이 향하는 역(*_toward)을 방면으로 적는다. 쓰이지 않는 행(노선·노드 없음)은 오류
for _x in json.load(open(os.path.join(ROOT,'data','overrides','tram_systems.json'),encoding='utf-8'))['rows']:
    if _x['at'] not in nodes or _x['x'] not in lines or _x['y'] not in lines:
        # 보정 행(source_patch)으로 더한 노드·노선은 생성 중 컴파일에 없다
        if not _nopatch:err('tram_systems_unknown',(_x['at'],_x['x'],_x['y']))
        continue
    for _a,_b,_tw,_ow in ((_x['x'],_x['y'],_x.get('y_toward'),_x.get('x_toward')),(_x['y'],_x['x'],_x.get('x_toward'),_x.get('y_toward'))):
        _hit=[j for j in junctions if (j['line'],j['other'],j.get('at'))==(_a,_b,_x['at'])]
        if not _hit:
            _hit=[dict(line=_a,other=_b,at=_x['at'],source=_x['src'],verified=True,valid=[None,'ongoing'],**{'continue':True})]
            junctions.append(_hit[0])
        for j in _hit:
            j['verified']=True;j['_ts']=True
            if _tw:j.setdefault('_toward',set()).add(_tw)
            # 이 노선 쪽 방면 역: 계통이 이 노선의 그 역 쪽에서 와서 상대 노선으로 곧장 들어간다. 분기 방향(side)은 그 역이 위쪽이면 down (10회차 G1 kanto_1-011 赤羽橋·芝園橋)
            if _ow:j.setdefault('_own_toward',set()).add(_ow)
# 근거 표 THROUGH의 상대 쪽 노드(at[1])와 방면(a_toward·b_toward: 그 쪽 열차가 상대 노선에서 향하는 역). 상대 노드가 다르면 그 노드에서만 잇는다(京王 新宿–都営 新宿(新線新宿))
# 여객 직통 기간만 적은 행(passenger_only)·스위치백 직통 행(reverse)은 그 기간의 근거 행에만 방면을 건다. 기간 밖 같은 쌍의 자동 행(선로 연결)은 선형 방면 그대로다.
# reverse 행이면 그 기간 끝 역 이어짐이 진행 방향을 바꿔 상대 노선으로 들어가는 것이라 표식(route_link.reverse)을 건다 (11회차 S3)
for _x in json.load(open(os.path.join(ROOT,'data','overrides','hand_tables.json'),encoding='utf-8'))['tables']['THROUGH']['값']:
    _po=bool(_x.get('passenger_only'));_pv=[_x.get('from'),_x.get('to') or 'ongoing'];_rv=_x.get('reverse')
    for _a,_b,_n,_m,_tw,_sd in ((_x['a'],_x['b'],_x['at'][0],_x['at'][1],_x.get('a_toward'),'a'),(_x['b'],_x['a'],_x['at'][1],_x['at'][0],_x.get('b_toward'),'b')):
        for j in junctions:
            if (j['line'],j['other'],j.get('at'))!=(_a,_b,_n):continue
            _own=bool(j.get('verified')) and list(j.get('valid') or [None,'ongoing'])==_pv
            if _po and not _own:continue
            # reverse: true면 두 쪽, "a"·"b"면 그 쪽 노선 끝 역 이어짐만(塩尻: 篠ノ井線→中央西線만, 中央東線→篠ノ井線은 곧게 이어짐)
            if _own and (_rv is True or _rv==_sd):j['_reverse']=True
            if _m!=_n:j['_other_at']=_m
            for t_ in ([_tw] if isinstance(_tw,str) else (_tw or [])):j.setdefault('_toward',set()).add(t_)
# 선로 연결 판정은 (역, 노선 쌍)마다 하나다: 근거 행이 한쪽(A→B)에만 있으면 상대 쪽(B→A) 행을 같은 기간으로 만든다. 상대 노선이 그 노드에 설 때만이다(다른 노드는 THROUGH가 양쪽을 다 갖는다).
# 방향은 생성기가 선형으로 정한다 (拝島·春日部·市ケ谷·鴫野 X자 교차 분기를 한쪽만 그리던 것, 9회차 L / X K122)
_JNP=[x_ for x_ in json.load(open(os.path.join(ROOT,'data','overrides','hand_tables.json'),encoding='utf-8'))['tables']['JUNCTION_NOT']['값'] if not x_.get('route') and x_.get('line') and x_.get('other')]
def _jnot_pair(a,b,at):return any({x_['line'],x_['other']}=={a,b} and x_.get('at') in (None,at) for x_ in _JNP)
_jkey={(j['line'],j['other'],j.get('at')) for j in junctions}
_lstop=collections.defaultdict(set)
for s_ in stops:
    if s_['is_stop']:_lstop[routes[s_['route_id']]['line']].add(s_['node_id'])
_jm=[]
for j in junctions:
    a_=j.get('at')
    if not a_ or j['line']==j['other'] or (j['other'],j['line'],a_) in _jkey or a_ not in _lstop.get(j['other'],()) or a_ not in _lstop.get(j['line'],()):continue
    if j.get('other_route') or _jnot_pair(j['other'],j['line'],a_):continue
    # 방향 칸은 두지 않고(이쪽 노선에서의 side와 뜻이 다르다) 선형으로 가장 곧은 방면을 고르게 한다(_geo)
    k_=dict(line=j['other'],other=j['line'],at=a_,source='mirror',verified=bool(j.get('verified')),valid=j.get('valid') or [None,'ongoing'],_geo=True)
    _jm.append(k_);_jkey.add((k_['line'],k_['other'],a_))
junctions+=_jm
print('선로 연결 근거 행 대칭으로 더함',len(_jm))
jx=collections.defaultdict(list)
for j in junctions:
    if j.get('at'):jx[(j['line'],j['at'])].append(j)
def vec(a,b):
    p,q=ppos.get(a),ppos.get(b)
    if not p or not q:return None
    return (q['lat']-p['lat'],(q['lon']-p['lon'])*math.cos(math.radians(p['lat'])))
def is_cur(s):return s['valid_to']=='ongoing'
# 그날 선로: 노선별 (칸 양 끝, 시작, 끝). 끝난 연결의 다음 역·끝 역은 그날 열린 칸과 그날 서는 역으로 찾는다 (2회차 종합 K03)
_lspan=collections.defaultdict(list)
for a_ in attr:_lspan[a_['line_id']].append((frozenset((edges[a_['edge_id']]['a'],edges[a_['edge_id']]['b'])),lohi(a_['valid_from'])[0] or '0000',(lohi(a_['valid_to'])[0] or '9999-12-31') if a_['valid_to'] not in (None,'ongoing') else '9999-12-31'))
_opc={}
def open_on(line,day):
    k_=(line,day)
    if k_ not in _opc:_opc[k_]={p for p,f,u in _lspan[line] if f<=day<u}
    return _opc[k_]
# 정차 기간 사이 서지 않은 때(route_stop_gap, 高松 1959~2001 옛 자리로 나간 동안)에는 서지 않는다 (2회차 종합 K03)
_GAPS=collections.defaultdict(list)
for s_,a_,b_ in stop_gaps:_GAPS[id(s_)].append(((lohi(a_)[0] or '0000') if a_ else '0000',(lohi(b_)[0] or '9999-12-31') if b_ else '9999-12-31'))
def on_day(s,day):
    return (lohi(s['valid_from'])[0] or '0000')<=day<((lohi(s['valid_to'])[0] or '9999-12-31') if s['valid_to'] not in (None,'ongoing') else '9999-12-31') and not any(f_<=day<u_ for f_,u_ in _GAPS.get(id(s),()))
_END=collections.defaultdict(list)
def walk(rid,seq,step,cur,day=None,ext=False):
    """seq에서 한 방향으로 다음 정차역과 끝 역을 찾는다. cur이면 오늘, day면 그날 영업 구간 안에서만 본다. 둘 다 없으면 모든 시기.
    ext면 그 방향에 정차역이 없을 때 계통 끝 노드를 다음 역·끝 역으로 돌려준다"""
    L=by_route[rid];i=next((k for k,x in enumerate(L) if x['seq']==seq),None)
    if i is None:return None,None
    if day is None and cur:day=TODAY
    op=open_on(routes[rid]['line'],day) if day else None;nxt=last=None;k=i+step;at=L[i]['node_id'];off=True
    while 0<=k<len(L):
        if day:
            # 그날 영업하지 않는 옛 경로·옛 자리 역(藤曲·仙人峠)이 km 순으로 사이에 끼어 있으면 건너뛰고, 마지막으로 지난 역과 이어지는지 본다
            if frozenset((L[k]['node_id'],at)) not in op:
                if not on_day(L[k],day):k+=step;continue
                off=False;break
            at=L[k]['node_id']
        if L[k]['is_stop'] and (not day or on_day(L[k],day)):
            if not nxt:nxt=L[k]['node_id']
            last=L[k]['node_id']
        k+=step
    # 그 방향에 정차역이 없고 계통 끝까지 그날 선로가 이어지면 다음 역·끝 역은 계통 끝 노드다(정차역이 없는 연락선, 서지 않는 끝 노드. 5번 결정)
    if ext and off and not nxt:
        # 그 방향에서 그날 끝인 가장 가까운 행
        e_=None
        for y_,inw_,iv_ in _END.get(rid,()):
            if inw_!=-step or (y_['seq']-L[i]['seq'])*step<=0:continue
            if day and not any(_lo(a_)<=day<_lo(b_,True) for a_,b_ in iv_):continue
            if e_ is None or abs(y_['seq']-L[i]['seq'])<abs(e_['seq']-L[i]['seq']):e_=y_
        if e_ is not None and (not day or _sel_on(e_,day)):nxt=last=e_['node_id']
    return nxt,last
def _sel_on(s,day):
    """행 s를 그날 고를 수 있는가: 그날 서거나, 끝 노드로 고를 수 있는 기간(sel_iv)이다"""
    if on_day(s,day):return True
    return any((lohi(a_)[0] or '0000')<=day<((lohi(b_)[0] or '9999-12-31') if b_ not in (None,'ongoing') else '9999-12-31') for a_,b_ in s.get('sel_iv',()))
def neighbors(rid,seq,cur=False,day=None,ext=False):
    return walk(rid,seq,-1,cur,day,ext),walk(rid,seq,1,cur,day,ext)
def first_hop(rid,seq,step,day):
    """seq에서 그 방향으로 그날 선로로 처음 닿는 노드 (정차역이 아니어도)"""
    L=by_route[rid];i=next((k for k,x in enumerate(L) if x['seq']==seq),None)
    if i is None:return None
    op=open_on(routes[rid]['line'],day);at=L[i]['node_id'];k=i+step
    while 0<=k<len(L):
        if frozenset((L[k]['node_id'],at)) in op:return L[k]['node_id']
        if on_day(L[k],day):return None
        k+=step
    return None
import datetime as _dtm
def _rep_day(pd):
    """연결 기간을 대표하는 날. 끝나지 않았으면 기준일, 끝났으면 끝 전날(시작보다 앞서지 않게)"""
    if pd[1] in (None,'ongoing'):return max(TODAY,lohi(pd[0])[1] or '0000') if pd[0] else TODAY
    e_=lohi(pd[1])[0] or '9999-12-31'
    try:d_=(_dtm.date.fromisoformat(e_)-_dtm.timedelta(days=1)).isoformat()
    except ValueError:d_=e_
    return max(d_,lohi(pd[0])[0] or '0000') if pd[0] else d_
FLOOR='1950-01-01'
def _change_days(rid,pd):
    """기간 pd 안에서 그 계통의 정차역·선로가 바뀌는 날들(시작 포함, 정렬)"""
    lo_=lohi(pd[0])[0] or '0000';hi_=(lohi(pd[1])[0] or '9999-12-31') if pd[1] not in (None,'ongoing') else '9999-12-31'
    ds={lo_}
    for x in by_route[rid]:
        for v in (x['valid_from'],x['valid_to']):
            if v not in (None,'ongoing'):
                d_=lohi(v)[0]
                if d_ and lo_<d_<hi_ and d_>FLOOR:ds.add(d_)
        # 정차 공백(route_stop_gap)의 시작·끝도 다음 역이 바뀌는 날이다 (名鉄常滑線 新日鉄前 1944–1964 공백: 河和線 太田川 이어짐 다음 역, 9회차 L K57)
        for g_ in _GAPS.get(id(x),()):
            for d_ in g_:
                if d_ and lo_<d_<hi_ and d_>FLOOR:ds.add(d_)
    for p,f,u in _lspan[routes[rid]['line']]:
        for d_ in (f,u):
            if lo_<d_<hi_ and d_>FLOOR:ds.add(d_)
    return sorted(ds)
def split_by_day(rid,pd,fn):
    """pd를 그 계통의 바뀌는 날로 나눠 토막마다 fn(그 토막 대표 날)을 부르고, 결과가 같은 이웃 토막은 합친다. [(토막, 결과)]"""
    ds=_change_days(rid,pd);out=[]
    for i,d in enumerate(ds):
        f_=pd[0] if i==0 else d;u_=pd[1] if i==len(ds)-1 else ds[i+1]
        if i==len(ds)-1:rd=_rep_day((f_,u_))
        elif i==0:
            # 시작을 범위로만 알면 그 상한 날(그날은 확실히 기간 안이다)
            # 기록 기준일(1950-01-01) 전의 변화는 나누지 않고 기준일의 선로로 본다
            rd=max(lohi(pd[0])[1] or d if pd[0] else d,FLOOR)
            if rd>=ds[1]:rd=d
        else:rd=d
        v=fn(rd)
        if out and out[-1][1]==v:out[-1]=((out[-1][0][0],u_),v)
        else:out.append(((f_,u_),v))
    return out
def era_end(rid,seq,valid):
    """기간 한정 직통의 시작 날에 이 역이 그 계통의 끝이었으면 끊긴 쪽('up'·'down'), 아니면 None.
    이관·연장으로 끝 역이 시기마다 다르면 지금은 지나가는 역도 그때는 끝이다 (金沢 2015–2024, 八戸 2002–2010)"""
    t=_lo(valid[0]);L=by_route[rid];i=next((k for k,x in enumerate(L) if x['seq']==seq),None)
    if i is None or t=='0000':return None
    ln=routes[rid]['line'];n=L[i]['node_id']
    def cut(step):
        # 그 방향으로 이 노드에서 나가는 계통 구간이 그날 이 노선 것이었는지 본다. 사이에 낀 폐역·옛 자리·나중 역은 상관없다.
        # 노선이 끊겨 먼 곳에 살아 있는 역이 있어도 끝이다 (八戸 2002: 盛岡 남쪽)
        # 그 방향 이웃이 여럿이면(옛 선로와 새 선로, 関屋 1951: 白山(旧)·白山) 하나라도 그날 이 노선 칸이면 지나간다
        ks=[L[k]['node_id'] for k in (range(i-1,-1,-1) if step<0 else range(i+1,len(L)))]
        es=[e for e in route_edges[rid] if n in (e['a'],e['b']) and other(e,n) in ks]
        return not any(_lo(a_['valid_from'])<=t<_lo(a_['valid_to'],True) for e in es for a_ in _ra[(ln,e['id'])])
    gone=[step for step in (-1,1) if cut(step)]
    if len(gone)==1:return 'up' if gone[0]<0 else 'down'
    # 그날 두 방면 모두 이 노선 칸이 있었으면 지나가는 역이었다(오늘은 끝이어도, 新開地 1968–1998 阪急神戸高速線)
    return 'through' if not gone else None
def _bounded(s):
    """정차 기간. 모르는 시작·끝(NULL)은 그 계통 노선이 그 역에 닿는 구간의 기간으로 묶는다 (감사 T2-03: 끝 NULL을 무한으로 봐 계통이 끝난 뒤의 환승이 생겼음)"""
    f,t=s['valid_from'],s['valid_to']
    if f is not None and t is not None:return f,t
    r_=routes[s['route_id']]
    vals=[a_ for e in route_edges[s['route_id']] if s['node_id'] in (e['a'],e['b']) for a_ in _ra[(r_['line'],e['id'])]]
    if not vals:return f,t
    if f is None:f=min(vals,key=lambda a_:lohi(a_['valid_from'])[0] or '0000')['valid_from']
    if t is None:t=max(vals,key=lambda a_:lohi(a_['valid_to'])[1] or '9999-12-31')['valid_to']
    return f,t
def period(s,o):
    """두 정차 기간의 겹침. 겹치지 않으면 None"""
    (sf,st),(of,ot)=_bounded(s),_bounded(o)
    f=max((sf,of),key=lambda x:lohi(x)[0] or '0000')
    t=min((st,ot),key=lambda x:(lohi(x)[1] or '9999-12-31') if x else '9999-12-30')
    if (lohi(f)[1] or '0000')>=((lohi(t)[0] or '9999-12-31') if t else '9999-12-30'):return None
    return f,t
def flow_of(s,o,day=None):
    """환승 흐름. 상대 노선이 그날 그 역을 지나가면 ①, 끝나면 들어오는 쪽이 내 위쪽인지 아래쪽인지 (2회차 종합 K05).
    상대는 계통 하나가 아니라 같은 노선의 그날 모든 계통으로 본다(姪浜: 筑肥線이 계통만 나뉘고 이어짐)"""
    cur=is_cur(o)
    pr,nx=neighbors(o['route_id'],o['seq'],cur,day)
    if pr[0] and nx[0]:return 'through','route',None,None
    ol_=routes[o['route_id']]['line'];dirs={}
    for o2 in node_stops.get(o['node_id'],()):
        if routes[o2['route_id']]['line']!=ol_ or o2 is o or (day and not on_day(o2,day)) or (not day and not period(o,o2)):continue
        for x in neighbors(o2['route_id'],o2['seq'],is_cur(o2),day):
            if x[0]:dirs.setdefault(x[0],x)
    for x in (pr,nx):
        if x[0]:dirs.setdefault(x[0],x)
    if len(dirs)>=2:
        # 두 방면 다음 역이 서로 반대쪽이면 지나감이다
        ks=list(dirs);vs=[vec(o['node_id'],k_) for k_ in ks]
        if any(vs[i] and vs[j] and vs[i][0]*vs[j][0]+vs[i][1]*vs[j][1]<0 for i in range(len(vs)) for j in range(i+1,len(vs))):return 'through','route',None,None
    other=pr if pr[0] else nx
    # 계통 안에 다음 역이 없는 끝(숨은 끝 너머 확장 행만 있는 옛 경로 계통, 長尾線 瓦町)은 확장 역을 다음 역으로 본다
    if not other[0]:
        pr2,nx2=neighbors(o['route_id'],o['seq'],cur,day,ext=True)
        other=pr2 if pr2[0] else nx2
    if not other[0]:return 'unknown',None,None,None
    v=vec(s['node_id'],other[0])
    mp,mn=neighbors(s['route_id'],s['seq'],is_cur(s),day)
    # 지금 끝 역이라도 화면에는 그 너머 옛·이관 구간 역이 이어 나온다(B안). 비는 쪽은 모든 시기의 이웃으로 채워 방향을 잰다 (디자인 감사 T02, 敦賀 北陸新幹線)
    if not(mp[0] and mn[0]):
        ap,an=neighbors(s['route_id'],s['seq'],False)
        mp=mp if mp[0] else ap;mn=mn if mn[0] else an
    best=None
    if v:
        du=dd=None
        if mp[0]:
            w=vec(s['node_id'],mp[0])
            if w:du=v[0]*w[0]+v[1]*w[1]
        if mn[0]:
            w=vec(s['node_id'],mn[0])
            if w:dd=v[0]*w[0]+v[1]*w[1]
        # 한쪽 이웃만 있으면(계통 맨 끝 역) 그 이웃과 같은 쪽인지 반대쪽인지로 정한다. 없는 쪽을 늘 진 것으로 두면 맨 위 끝에서 늘 ③이 된다
        if du is not None and dd is not None:best='up' if du>dd else 'down'
        elif du is not None:best='up' if du>0 else 'down'
        elif dd is not None:best='down' if dd>0 else 'up'
    return best or 'unknown','coord' if best else None,other[0],other[1]
def hav_km(a,b):
    p,q=ppos.get(a),ppos.get(b)
    if not p or not q:return 9.0
    return math.hypot((p['lat']-q['lat'])*111,(p['lon']-q['lon'])*111*math.cos(math.radians(p['lat'])))
def _lo(x,end=False):
    if x in (None,'ongoing'):return '9999-12-31' if end else '0000'
    return lohi(x)[0] or ('9999-12-31' if end else '0000')
# 선로가 이어질 수 있는가 (2회차 종합 U06·K01·K04). 철도·지하철·노면전차는 같은 바퀴·레일 방식이라 궤간이 같으면 들어간다(宮島線↔本線, 京津線↔東西線).
# AGT·모노레일·리니어·강삭·가이드웨이 버스·무궤조 전차는 같은 방식끼리만이다. 궤간·방식은 그날 그 역에 걸리는 line_gauge 행(노선 행의 gauge)이 먼저이고,
# 행이 없으면 노선 종류에서 방식만 읽는다(궤간 모름은 막지 않음). 單線並列·三線軌条처럼 행이 둘이면 하나라도 맞으면 된다
# 第三軌条는 架空 집전 노선과 직통할 수 없어 다른 묶음이다(丸ノ内線↔有楽町線, 名城線↔上飯田線, 千日前線↔今里筋線). 磁気浮上(リニモ·HSST)은 鉄輪式リニア와 다르다
_SYSCLS={'rail':'rail','subway':'rail','tram':'rail','third_rail':'third_rail','agt':'agt','monorail':'monorail','maglev':'maglev','linear':'linear','cable':'cable','rubber_guided':'rubber_guided','guideway_bus':'guideway_bus','trolley':'trolley','bus':'bus'}
_seg_cache={}
def _on_seg(line,f,t,n):
    """노드 n이 그 노선의 f–t 구간 위(끝 포함)에 있는가. 그 노선 계통 순서로 본다"""
    n=SPLIT_OF.get(n,n);k=(line,f,t,n)
    if k not in _seg_cache:
        hit=False
        for rid_,d_ in route_rank.items():
            if routes[rid_]['line']!=line or f not in d_ or t not in d_ or n not in d_:continue
            lo_,hi_=sorted((d_[f],d_[t]))
            if lo_-1e-6<=d_[n]<=hi_+1e-6:hit=True;break
        _seg_cache[k]=hit or n in (f,t)
    return _seg_cache[k]
def _gstate(line,n,day):
    """그날 그 역에서 노선의 (방식 묶음, 궤간) 집합. 궤간 모름은 None"""
    seg=set();whole=set()
    for g in lines[line].get('gauge') or []:
        if not(_lo(g.get('valid_from'))<=day<_lo(g.get('valid_to'),True)):continue
        if g.get('from_node') and g.get('to_node'):
            if not _on_seg(line,g['from_node'],g['to_node'],n):continue
            seg.add((_SYSCLS.get(g['system'],g['system']),g.get('gauge')))
        else:whole.add((_SYSCLS.get(g['system'],g['system']),g.get('gauge')))
    # 그 역에 걸리는 구간 행이 있으면 노선 전체(그 밖 구간) 행보다 앞선다 (近鉄名古屋線 江戸橋–中川 1938~1959 1067)
    return seg or whole or {(_SYSCLS.get(lines[line].get('type'),lines[line].get('type')),None)}
def _fits(a,b):
    return any(x[0]==y[0] and (x[1] is None or y[1] is None or x[1]==y[1]) for x in a for y in b)
def _gstate_e(line,a,b,day):
    """그날 노선 line의 칸 a–b의 (방식 묶음, 궤간) 집합. 두 끝이 다 든 구간 행이 먼저다(越後湯沢: 越後湯沢–ガーラ湯沢 1435, 高崎–宮内 1067)"""
    seg=set();whole=set()
    for g in lines[line].get('gauge') or []:
        if not(_lo(g.get('valid_from'))<=day<_lo(g.get('valid_to'),True)):continue
        if g.get('from_node') and g.get('to_node'):
            if _on_seg(line,g['from_node'],g['to_node'],a) and _on_seg(line,g['from_node'],g['to_node'],b):seg.add((_SYSCLS.get(g['system'],g['system']),g.get('gauge')))
        else:whole.add((_SYSCLS.get(g['system'],g['system']),g.get('gauge')))
    # 칸 두 끝이 다 든 구간 행이 없으면(옛 경로 칸: 名古屋線 諏訪 1938–1956) 그 역에 걸린 행으로 본다
    return seg or whole or _gstate(line,a,day)
def _gstate_n(line,n,ys,day):
    """그날 노선 line이 n에서 이웃 ys 쪽 칸들로 가진 (방식, 궤간) 집합. 이웃이 없으면 역 단위"""
    ys=[y for y in (ys or ()) if y]
    if not ys:return _gstate(line,n,day)
    return set().union(*[_gstate_e(line,n,y,day) for y in ys])
def _gfit(l1,n,ys1,l2,m,ys2,day):
    """그날 l1(n에서 ys1 쪽)과 l2(m에서 ys2 쪽) 선로의 궤간·방식이 맞는가 (3회차 W1a: 칸 단위. 大曲·新庄·越後湯沢)"""
    return _fits(_gstate_n(l1,n,ys1,day),_gstate_n(l2,m,ys2,day))
def _gsplit(l1,l2,pd):
    """기간 pd를 두 노선 궤간 행의 시작·끝 날로 나눈 토막들"""
    ds=sorted({_lo(v) for l_ in (l1,l2) for g in lines[l_].get('gauge') or [] for v in (g.get('valid_from'),g.get('valid_to')) if v not in (None,'ongoing') and _lo(pd[0])<_lo(v)<_lo(pd[1],True)})
    out=[];cur=pd[0]
    for d in ds:out.append((cur,d));cur=d
    out.append((cur,pd[1]))
    return out
def track_ok(l1,l2,n,pd,ys1=None,m=None,ys2=None):
    """기간 pd 가운데 두 노선 선로가 그 역에서 이어질 수 있는 토막들. 이웃(ys1·ys2)을 주면 그 칸의 궤간으로 본다"""
    ds={_lo(pd[0])}
    for l_ in (l1,l2):
        for g in lines[l_].get('gauge') or []:
            for v in (g.get('valid_from'),g.get('valid_to')):
                if v not in (None,'ongoing') and _lo(pd[0])<_lo(v)<_lo(pd[1],True):ds.add(_lo(v))
    ds=sorted(ds);out=[]
    for i,d in enumerate(ds):
        f_=pd[0] if i==0 else d;u_=pd[1] if i==len(ds)-1 else ds[i+1]
        if not _gfit(l1,n,ys1,l2,m or n,ys2,d):continue
        if out and out[-1][1]==f_:out[-1]=(out[-1][0],u_)
        else:out.append((f_,u_))
    return out
def _clip(pd,j):
    """근거 표 junction에 적힌 기간으로 자른다. 적힌 기간이 없으면 그대로"""
    v_=j.get('valid') or [None,'ongoing']
    if v_[0] is None and v_[1] in (None,'ongoing'):return pd
    # 이른 날이 같으면 범위 쪽을 고른다. 근거 표 시작이 범위([1988-07-16..1996-03-16])인데 정차 시작(1988-07-16)과 이른 날이 같다고
    # 확정 날로 바뀌면 근거가 없는 날을 확정으로 적는다 (宮福線 福知山, 10회차 G1 kinki_2-013 감사 K177). 끝도 같다(늦은 날이 같으면 범위)
    def _hi_(x):return '9999-12-31' if x in (None,'ongoing') else (lohi(x)[1] or '9999-12-31')
    f_=max((pd[0],v_[0]),key=lambda x:(_lo(x),_hi_(x)));u_=min((pd[1],v_[1]),key=lambda x:(_lo(x,True),_lo(x)))
    return (f_,u_) if _lo(f_)<_lo(u_,True) else None
def cover(cand,s,per_route=False):
    """후보마다 이 역과 겹치는 기간을 고르는 순서대로 채운다. 앞 후보가 덮은 기간은 빼고 남은 토막만 둔다.
    상대 노선을 한 후보로만 고르면 다른 계통·옛 노드가 맡던 기간의 연결이 빠진다 (감사 TOP-01)"""
    out=[];done=[]
    for c in sorted(cand,key=lambda c:pick_key(c,s)):
        pd0_=period(s,c[0])
        if not pd0_:continue
        # 앞 후보와 그 역에서 칸을 함께 쓰지 않는 다른 계통(다른 방면의 갈래)은 그 기간을 빼지 않고 따로 잇는다
        # (唐津線 山本: 筑肥線 伊万里 방면과 虹ノ松原 방면, 西武新宿線 東村山: 西武園線 두 계통, 3회차 kyushu_1-007·kanto_3-10)
        es_={f_ for f_ in _RPE.get(c[0]['route_id'],{}) if c[1] in f_} if per_route else set()
        # 후보가 서지 않던 때(정차 공백)는 덮지 않고 다음 후보에 남긴다(高松 予讃線 1959–2001 공백 동안은 高松（旧）: 琴平線 高松築港 쪽 환승이 빠져 비대칭이던 것, 9회차 L / X K123)
        pcs_=[pd0_]
        for g0,h0 in _GAPS.get(id(c[0]),()):
            g_=None if g0=='0000' else g0;h_=None if h0=='9999-12-31' else h0;nx_=[]
            for f_,u_ in pcs_:
                if (h_ is not None and h_<=_lo(f_)) or (g_ is not None and g_>=_lo(u_,True)):nx_.append((f_,u_));continue
                if g_ is not None and _lo(f_)<g_:nx_.append((f_,g_))
                if h_ is not None and h_<_lo(u_,True):nx_.append((h_,u_))
            pcs_=nx_
        for pd in pcs_:
            f,t=pd;cur=f
            for g,h in sorted([d_ for d_,e_ in done if not es_ or not e_ or e_&es_],key=lambda x:_lo(x[0])):
                if _lo(h,True)<=_lo(cur):continue
                if _lo(g)>=_lo(t,True):break
                if _lo(g)>_lo(cur):out.append((c[0],c[1],(cur,g)))
                if h in (None,'ongoing'):cur=None;break
                if _lo(h,True)>_lo(cur):cur=h
            if cur is not None and _lo(cur)<_lo(t,True):out.append((c[0],c[1],(cur,t)))
            done.append((pd,es_))
    return out
_BRANK={'same_group':1,'moved':2,'doc':2,'same_name':2,'ekimae':2,'near_150':2,'hand':3}
def _brank(n,m):
    if m==n:return 0
    w_=HUBPAIR.get(frozenset((n,m)))
    if w_:return _BRANK.get(w_[0],3)
    return 1 if nodes[n].get('group') and nodes[n].get('group')==nodes[m].get('group') else 4
def pick_key(c,s):
    n=s['node_id'];o,m=c
    pr,nx=neighbors(o['route_id'],o['seq'],is_cur(o))
    # 묶음 안 다른 노드끼리는 상대가 지나가는 노드를 먼저 고른다 (東西線 仙台: 仙石線은 あおば通에서 끝나지만 仙台를 지나감, 2회차 종합 K05)
    # 묶음 안 다른 노드끼리는 환승 근거가 센 쪽(같은 노드 > 같은 group > 문서·같은 이름·역앞·150 m > 손 표 간접 환승)을 먼저, 그다음 상대가 지나가는 노드, 가까운 노드 순
    # (阪神 野田: 千日前線은 野田阪神(문서·같은 건물)이고 玉川(손 표 537 m)가 아니다, 3회차 kinki_2-012)
    return (is_cur(o)!=is_cur(s),m!=n,_brank(n,m),m!=n and not(pr[0] and nx[0]),round(hav_km(n,m),3),not(pr[0] and nx[0]),o['route_id'],o['seq'])
def pick(cand,s):
    """같은 노선의 후보 정차 행 중 표시할 하나. 오늘 상태가 같은 것, 가까운 것, 지나가는 것 순"""
    n=s['node_id']
    def key(c):
        o,m=c
        pr,nx=neighbors(o['route_id'],o['seq'],is_cur(o))
        return (is_cur(o)!=is_cur(s),m!=n,round(hav_km(n,m),3),not(pr[0] and nx[0]),o['route_id'],o['seq'])
    return min(cand,key=key)
# 상대 노선의 끝 역이면 그쪽 화면에서는 이어짐이다. 위키에 한쪽만 그려져 있어도 양쪽을 만든다
for j in list(junctions):
    if j.get('at') and j['other']!=j['line'] and not any(x['other']==j['line'] for x in jx.get((j['other'],j['at']),[])):
        jx[(j['other'],j['at'])].append(dict(line=j['other'],other=j['line'],at=j['at'],implied=True))
# ── 선형 방향 (3회차 전수 점검 W1a, 판 2026-11-15.1). 갈래·이어짐의 방향은 이웃 역 좌표의 각도가 아니라 그 역에서 나가는 칸 선형(geometry)의
# 시작 방향(역에서 300 m, 짧은 칸은 칸 길이의 45%까지)으로 잰다. 이웃 역이 멀거나 노선이 역을 나가 크게 굽으면 좌표 각도가 반대로 나온다
# (日生線 山下, 鈴鹿線 伊勢若松, 鳴門線 池谷, 吉都線 都城, 和歌山線 王寺, 信楽線 貴生川). 배포 선형(OSM 뺌)이 없는 칸은 이웃 노드 좌표로 잰다
HTAB={k_:v_.get('값',v_) for k_,v_ in json.load(open(os.path.join(ROOT,'data','overrides','hand_tables.json'),encoding='utf-8'))['tables'].items()}
# 근거 표 THROUGH가 방향(*_side)을 적은 행
_THSIDE={(x_['a'],x_['b'],x_['at'][0]) for x_ in HTAB.get('THROUGH',[]) if x_.get('a_side')}|{(x_['b'],x_['a'],x_['at'][1]) for x_ in HTAB.get('THROUGH',[]) if x_.get('b_side')}
_GEOC={g['edge']:g['coords'] for g in load_geo()}
_EPAIR=collections.defaultdict(list)
for _eid,_e in edges.items():_EPAIR[frozenset((_e['a'],_e['b']))].append(_eid)
_ELINES=collections.defaultdict(set)
for _a in attr:_ELINES[_a['edge_id']].add(_a['line_id'])
GEO_D=300.0
_gdc={}
def _unit(v):
    if not v:return None
    l_=math.hypot(*v)
    return (v[0]/l_,v[1]/l_) if l_ else None
def gde(eid,x):
    """칸 eid를 노드 x에서 나갈 때의 시작 방향(북, 동 단위 벡터)"""
    k_=(eid,x)
    if k_ in _gdc:return _gdc[k_]
    cs=_GEOC.get(eid);e_=edges[eid];v_=None
    if cs and len(cs)>=2:
        px=ppos.get(x)
        if px:rev=(cs[-1][0]-px['lon'])**2+(cs[-1][1]-px['lat'])**2<(cs[0][0]-px['lon'])**2+(cs[0][1]-px['lat'])**2
        else:rev=e_['a']!=x
        c_=cs[::-1] if rev else cs
        cl=math.cos(math.radians(c_[0][1]))
        def _mv(p,q):return ((q[1]-p[1])*111320.0,(q[0]-p[0])*111320.0*cl)
        tot=sum(math.hypot(*_mv(p,q)) for p,q in zip(c_,c_[1:]))
        lim=min(GEO_D,0.45*tot);acc=0.0;tg=c_[-1]
        for p,q in zip(c_,c_[1:]):
            l_=math.hypot(*_mv(p,q))
            if l_>0 and acc+l_>=lim:
                f_=(lim-acc)/l_;tg=(p[0]+(q[0]-p[0])*f_,p[1]+(q[1]-p[1])*f_);break
            acc+=l_
        v_=_unit(_mv(c_[0],tg))
    if v_ is None:
        w_=vec(x,other(e_,x));v_=_unit(w_)
    _gdc[k_]=v_
    return v_
def gd(x,y,line=None):
    """x에서 이웃 y로 나가는 칸의 시작 방향. 노선이 주어지면 그 노선 칸을 먼저 본다"""
    es_=_EPAIR.get(frozenset((x,y)),[])
    if line:es_=sorted(es_,key=lambda e_:line not in _ELINES[e_])
    return gde(es_[0],x) if es_ else _unit(vec(x,y))
def ucos(u,v):return u[0]*v[0]+u[1]*v[1] if u and v else None
def tdeg(u,v):
    """두 방향 사이 각(도). 제 계통 안쪽 방향과 상대 방향 사이 각이면 180°가 곧게 이어짐, 0°가 되돌아감"""
    c_=ucos(u,v)
    return None if c_ is None else math.degrees(math.acos(max(-1.0,min(1.0,c_))))
_RPE={rid_:{frozenset((e_['a'],e_['b'])):e_['id'] for e_ in es_} for rid_,es_ in route_edges.items()}
_SIDX={}
for _rid,_L in by_route.items():
    for _k,_x in enumerate(_L):_SIDX[(_rid,_x['seq'])]=_k
def hop(rid,seq,step,day=None):
    """계통 rid의 seq 역에서 step 방향으로 계통 칸으로 처음 닿는 (노드, 칸). day면 그날 그 노선 칸이 열린 것 먼저"""
    L=by_route[rid];i=_SIDX.get((rid,seq))
    if i is None:return None,None
    at=L[i]['node_id'];P=_RPE.get(rid,{});op=open_on(routes[rid]['line'],day) if day else None
    k=i+step
    while 0<=k<len(L):
        f_=frozenset((at,L[k]['node_id']))
        if f_ in P and (op is None or f_ in op):return L[k]['node_id'],P[f_]
        k+=step
    return hop(rid,seq,step,None) if day else (None,None)
def rdir(rid,seq,step,day=None):
    """계통 rid의 seq 역에서 step 방향으로 나가는 칸의 시작 방향"""
    y_,eid_=hop(rid,seq,step,day)
    if not y_:return None
    return gde(eid_,by_route[rid][_SIDX[(rid,seq)]]['node_id'])
_RBL=collections.defaultdict(list)
for _rid in routes:_RBL[routes[_rid]['line']].append(_rid)
def _thru_e(B,x):
    """노선 B가 x를 지나는 계통의 (계통, 위쪽 칸, 아래쪽 칸). 본선 계통 먼저. 없으면 None"""
    for rid_ in sorted(_RBL.get(B,()),key=lambda r_:(routes[r_].get('role')!='main',r_)):
        for x_ in by_route.get(rid_,()):
            if x_['node_id']!=x or x_.get('is_extension'):continue
            u_,d_=hop(rid_,x_['seq'],-1),hop(rid_,x_['seq'],1)
            if u_[0] and d_[0]:return rid_,u_[1],d_[1]
    return None
def side_geo(B,x,A,arid=None):
    """노선 B가 x를 지날 때 노선 A(계통 arid)의 선로가 갈라지는 방향. A의 칸이 시작하는 방향이 B의 위쪽(up)·아래쪽(down) 칸 중 어느 쪽과 나란한가.
    A가 x를 지나거나(X자) 칸을 B와 함께 쓰거나 두 방향의 차이가 작으면(직각 교차) None"""
    t_=_thru_e(B,x)
    if not t_:return None
    rid_,eu,ed=t_
    if arid:es_={e_ for f_,e_ in _RPE.get(arid,{}).items() if x in f_}-{eu,ed}
    else:es_={e_['id'] for e_ in adj[x] if A in _ELINES[e_['id']] and B not in _ELINES[e_['id']]}
    if len(es_)!=1:return None
    va=gde(next(iter(es_)),x);cu,cd=ucos(va,gde(eu,x)),ucos(va,gde(ed,x))
    if cu is None or cd is None or abs(cu-cd)<0.5:return None
    return 'up' if cu>cd else 'down'
# 위키 노선도·좌표로 정한 분기 방향을 선형으로 고친다. 사람이 확인한 행(junction_side.json, 근거 표 THROUGH의 *_side)은 고치지 않고
# 선형과 다르면 경고로 남겨 감사(K53)가 본다. 반대 화면 행(implied)에도 방향을 채운다
for _j in list(junctions)+[x_ for v_ in list(jx.values()) for x_ in v_ if x_.get('implied')]:
    if not _j.get('at') or _j['line'] not in lines or _j['other'] not in lines:continue
    _sg=side_geo(_j['line'],_j['at'],_j['other'],_j.get('other_route'))
    if not _sg or _j.get('side')==_sg:continue
    if _j.get('_hand_side') or (_j['line'],_j['other'],_j['at']) in _THSIDE:
        WARN['side_geo_hand'].append((_j['line'],_j['other'],_j['at'],_j.get('side'),_sg));continue
    if _j.get('side'):WARN['side_geo_fix'].append((_j['line'],_j['other'],_j['at'],_j.get('side'),_sg))
    _j['side']=_sg
print('선형으로 고친 분기 방향',len(WARN['side_geo_fix']),'손 행과 선형이 다름',len(WARN['side_geo_hand']))
def _tw_pick(o,pr,nx,j):
    """방면 역(j['_toward'])이 상대 계통에서 이 역의 위쪽이면 pr, 아래쪽이면 nx. 상대 계통에 없는 역은 그 노선 다른 계통 순서로도 찾지 않는다"""
    L_=by_route[o['route_id']];i_=_SIDX[(o['route_id'],o['seq'])];out=[]
    for t_ in sorted(j['_toward']):
        k_=next((k for k,x in enumerate(L_) if x['node_id']==t_),None)
        if k_ is None or k_==i_:WARN['toward_miss'].append((o['route_id'],t_));continue
        x_=pr if k_<i_ else nx
        if x_[0] and x_ not in out:out.append(x_)
    return out
def _inside(rid,seq,mp,day):
    """끝 역에서 이 계통이 들어오는 쪽(-1 위쪽·1 아래쪽). 바로 옆 정차역이 아니라 그날 계통 칸으로 본다: 옆 노드가 숨은 노드(신호장·분기점)이고 그 너머가 확장 행뿐이면
    정차역 이웃이 없어도 칸은 그쪽에 있다 (田端信号場–上中里 東北貨物線·田端信号場–三河島 田端貨物線·吹田貨物ターミナル–尼崎 北方貨物線, 9회차 L K68)"""
    u_,d_=hop(rid,seq,-1,day)[0],hop(rid,seq,1,day)[0]
    if u_ and not d_:return -1
    if d_ and not u_:return 1
    return -1 if mp[0] else 1
def _alt_cont(s,r,mp,oid,m,o,pd,ys_own,xs,own_fn,rr,group_near):
    """방면별 계통 후보: 끝 역 이어짐이 상대 계통 o에서 되돌아가는 방면(선형 각이 기준 미만)만 고를 수 있을 때, 그날 같은 노드에 선 상대 노선의 다른 계통에서
    곧게 나가는 방면(기준 이상, 가장 곧은 것)이 있으면 그 계통의 다음 역·끝 역으로 이음 행을 내고 True. 없으면 아무것도 하지 않고 False
    (内房線 蘇我 1958 전: 外房線 본선 계통은 蘇我에서 誉田 쪽뿐, 千葉 쪽 곧은 방면은 옛 경로 계통 蘇我–本千葉(旧)–千葉(旧), 3회차 W1a 확인 목록 → 9회차 L K68)"""
    rd_=_rep_day(pd);w_=rdir(r['id'],s['seq'],_inside(r['id'],s['seq'],mp,rd_),rd_)
    if w_ is None:return False
    th_=sharp_c(r['line'],oid)
    if xs is not None:
        a0_=tdeg(w_,rdir(o['route_id'],o['seq'],xs,rd_))
        if a0_ is None or a0_>=th_:return False
    best=None
    for o2 in node_stops.get(m,()):
        if routes[o2['route_id']]['line']!=oid or o2['route_id']==o['route_id'] or o2.get('is_extension') or not on_day(o2,rd_):continue
        if rr and o2['route_id']!=rr:continue
        for st2 in (-1,1):
            h2_=hop(o2['route_id'],o2['seq'],st2,rd_)[0]
            if not h2_ or frozenset((m,h2_)) not in open_on(oid,rd_):continue
            a_=tdeg(w_,rdir(o2['route_id'],o2['seq'],st2,rd_))
            if a_ is None or a_<th_:continue
            if not _gfit(r['line'],s['node_id'],ys_own,oid,m,{h2_},rd_):continue
            x_=walk(o2['route_id'],o2['seq'],st2,False,rd_)
            if not x_[0] or own_fn(x_[0],pd):continue
            if best is None or a_>best[0]:best=(a_,o2,st2)
    if not best:return False
    _,o2,st2=best;n0_=len(links)
    for pd2,(nxt2,term2) in split_by_day(o2['route_id'],pd,lambda d,o2=o2,st2=st2:walk(o2['route_id'],o2['seq'],st2,False,d)):
        if nxt2:add_link(s,oid,rr,'continue',None,group_near(m),nxt2,term2,None,None,pd2,o2)
    if len(links)>n0_:WARN['cont_alt_route'].append((r['id'],s['node_id'],oid,o['route_id'],o2['route_id'],pd));return True
    return False
def sharp_c(a,b):
    """이어짐으로 보는 가장 작은 선형 각. 노면전차끼리는 길모퉁이에서 직각으로 꺾여 이어지므로 되돌아가는 각(30° 미만)만 뺀다 (gen_wiki SHARP와 같은 값)"""
    return 30 if lines[a].get('type')==lines[b].get('type')=='tram' else 75
# JUNCTION_NOT의 계통 한정 행(route): 그 계통에서만 그 노선(other)·계통(other_route)과 선로가 이어지지 않는다(尾久 경유 계통 赤羽→埼京線). 노선 단위 행은 gen_wiki가 건다
_JNR=[x_ for x_ in HTAB.get('JUNCTION_NOT',[]) if x_.get('route')]
_JNR_USED=set()
def _jnot_route(rid,n,oid,orr):
    for i_,x_ in enumerate(_JNR):
        if x_['route']==rid and x_['at']==n and ((x_.get('other_route') and x_['other_route']==orr) or (not x_.get('other_route') and x_.get('other')==oid)):
            _JNR_USED.add(i_);return True
    return False
# 노선별 칸(edge ID)의 소속 기간. 같은 두 역 사이를 다른 선로로 잇는 옛 선형·새 선형은 다른 칸이다
_lspanE=collections.defaultdict(lambda:collections.defaultdict(list))
for a_ in attr:_lspanE[a_['line_id']][a_['edge_id']].append((lohi(a_['valid_from'])[0] or '0000',(lohi(a_['valid_to'])[0] or '9999-12-31') if a_['valid_to'] not in (None,'ongoing') else '9999-12-31'))
def _all_own(orid,own_ids,day,own_pairs=frozenset()):
    """상대 계통의 그날 열린 칸이 모두 이 계통 칸인가. 칸은 선로(edge ID)로 본다.
    두 역 쌍으로 보면 같은 두 역 사이의 옛 선형과 새 선형이 한 칸으로 겹쳐, 옛 경로 계통이 본선으로 돌아오는 분기가 사라졌다
    (信越本線 軽井沢 ← 横川–軽井沢 옛 선로, 篠ノ井線 西条·明科, 鹿児島本線 戸畑, 和歌山線 田井ノ瀬. 사용자 지적 2026-11-19)"""
    # 여객 이력 계통(extra)은 같은 두 역 사이의 별선이어도 같은 노선 다른 계통과 잇지 않는다(和歌山線 短絡線 1962–1972, 정한 규칙 4회차 kinki_3-004). 그래서 역 쌍으로 본다
    if routes[orid].get('extra'):
        op_=open_on(routes[orid]['line'],day)
        remp_={f_ for f_ in _RPE.get(orid,{}) if f_ in op_}
        return bool(remp_) and remp_<=own_pairs
    sp_=_lspanE[routes[orid]['line']]
    rem_={e_['id'] for e_ in route_edges[orid] if any(f_<=day<u_ for f_,u_ in sp_.get(e_['id'],()))}
    return bool(rem_) and rem_<=own_ids
# 묶음은 사슬로 이어지므로 같은 묶음이라고 다 환승이 아니다 (日本橋~三越前~新日本橋).
# 환승은 같은 노드·같은 group·채택한 환승 쌍(위 HUBPAIR)만이다 (spec route_link transfer 근원)
def linked(a,b):
    if a==b:return True
    if hub_not(a,b):return False
    if frozenset((a,b)) in HUBPAIR:return True
    # 같은 group이어도 400 m 넘게 떨어진 다른 사업자 노드는 채택 쌍일 때만 (K07)
    return nodes[a].get('group')==nodes[b].get('group') and (not _far(a,b) or bool(_ops_of(a)&_ops_of(b)))
# ── 계통 끝 노드 행 (5번 결정 2026-11-19, 입력 단계 재구성 2026-11-20) ──
# 계통 끝 너머 다른 노선의 역을 이 계통 역처럼 붙이던 확장 행(extend.json)은 더 만들지 않는다. 대신 연결 행을 만들기 전에 행 기간을 정한다.
# ① 계통 끝 노드 행은 그 끝에 닿는 계통 칸이 그 노선으로 영업한 기간(계통 자기 행 기간 안) 내내 있다. 끝 역이 나중에 생겼거나(熊本高専前 1995,
#    三岐朝明 1950) 먼저 정차를 그친(東野田町九丁目 1944, 三岐朝明 신호장 1989) 동안도 승하차 불가 끝 노드(가운데 회색, 고를 수 있음)로 보인다.
# ② 끝 노드는 그 노드를 지나가는 다른 계통 화면에도 보인다. 그 계통 행도 끝 노드가 끝인 기간 가운데 그 계통 칸이 닿는 동안으로 늘린다(徳島線 끝 佃 → 土讃線 佃 행).
# 행 기간(valid_from·valid_to)과 서지 않은 때는 그대로 두고, 고를 수 있는 기간(sel_from·sel_to)만 따로 적는다. 그래서 행 기간을 쓰는 다른 계산
# (다음 역·끝 역, 옛 경로 건너뛰기, 환승, 환승 쌍, 임시역 표식)은 바뀌지 않는다. 고를 수 있는 기간은 끝 노드 찾기(walk)·선로 연결 기간(_alive)·끝 이어짐과
# 내보내는 route_stop(행 기간을 늘리고 늘린 동안 정차 행이면 route_stop_gap)에서만 쓴다
_EXTROWS=[]
def _iv_sub(ivs,cut):
    """기간 목록에서 [cut) 를 뺀다 (EDTF 하한 기준)"""
    out=[]
    for f_,t_ in ivs:
        a_,b_=_lo(f_),_lo(t_,True);c0,c1=_lo(cut[0]),_lo(cut[1],True)
        if c1<=a_ or c0>=b_:out.append((f_,t_));continue
        if c0>a_:out.append((f_,cut[0]))
        if c1<b_:out.append((cut[1],t_))
    return out
_ra2=collections.defaultdict(list)
for a_ in attr:_ra2[(a_['line_id'],a_['edge_id'])].append(a_)
def _ivu(iv):
    """기간들의 합집합(시작 순)"""
    out=[]
    for f_,t_ in sorted(iv,key=lambda x:_lo(x[0])):
        if out and _lo(f_)<=_lo(out[-1][1],True):
            if _lo(t_,True)>_lo(out[-1][1],True):out[-1]=(out[-1][0],t_)
        else:out.append((f_,t_))
    return out
def _ivx(A,B):
    """두 기간 목록의 교집합. 같은 날이면 앞 목록(A)의 값을 쓴다"""
    out=[]
    for f1,t1 in A:
        for f2,t2 in B:
            f_=f2 if _lo(f2)>_lo(f1) else f1
            t_=t2 if _lo(t2,True)<_lo(t1,True) else t1
            if _lo(f_)<_lo(t_,True):out.append((f_,t_))
    return out
def _minus(A,B):
    for c_ in B:A=_iv_sub(A,c_)
    return A
def _selivs(s_):
    """행을 고를 수 있는 기간들: 행 기간과 끝 노드로 고를 수 있는 기간(sel_iv). 사이의 빈 날은 넣지 않는다 (검토 L1)"""
    return _ivu([(s_['valid_from'],s_['valid_to'] or 'ongoing')]+[x_ for x_ in s_.get('sel_iv',()) if _lo(x_[0])<_lo(x_[1],True)])
def _hull(s_):
    iv_=_selivs(s_)
    return (min((x[0] for x in iv_),key=lambda v:_lo(v)),max((x[1] for x in iv_),key=lambda v:_lo(v,True)))
def _ecover(s_,iv_):
    """행 s_를 iv_(기간 목록) 동안 고를 수 있게 한다(sel_iv). 늘린 동안 정차가 아니면 고를 수 있는 서지 않은 때다.
    행 기간은 바꾸지 않으므로 범위로만 아는 날(「[..1972-11-12]」)도 그대로 넣는다(都電 吾妻橋線 끝 吾妻橋一丁目 1960–1972)"""
    add_=[(f0_,t0_) for f0_,t0_ in iv_ if f0_ and t0_ and _lo(f0_)<_lo(t0_,True)]
    if not add_:return 0
    s_.setdefault('sel_iv',[]).extend(add_)
    return 1
def _lead_clip(rid_,eid_,iv_):
    """앞 역을 붙인 칸은 그 기간에만 이 계통 칸이고, 그 칸을 빌려 준 계통에서는 그 기간 칸이 아니다"""
    p_=_LEAD_EIV.get((rid_,eid_))
    if p_:iv_=_ivx(iv_,[p_])
    q_=_LEAD_TAKE.get((rid_,eid_))
    if q_:iv_=_minus(list(iv_),[q_])
    return iv_
def _edge_iv(rid_,n_):
    """계통 rid_의 칸 가운데 노드 n_에 닿는 칸들이 그 계통 노선 소속이던 기간들"""
    ln_=routes[rid_]['line']
    return [x_ for e in route_edges.get(rid_,()) if n_ in (e['a'],e['b']) and e['a']!=e['b'] for x_ in _lead_clip(rid_,e['id'],[(a_['valid_from'],a_['valid_to']) for a_ in _ra2[(ln_,e['id'])]])]
def _clip_iv(iv_,f0,t0):
    iv_=[(f_ if _lo(f_)>=_lo(f0) else f0,t_ if _lo(t_,True)<=_lo(t0,True) else t0) for f_,t_ in iv_]
    return [(f_,t_) for f_,t_ in iv_ if _lo(f_)<_lo(t_,True)]
_rspan={}
for rid_,L_ in by_route.items():
    if L_:_rspan[rid_]=(min((y['valid_from'] for y in L_),key=lambda v:_lo(v)),max((y['valid_to'] for y in L_),key=lambda v:_lo(v,True)))
# 계통의 끝은 날마다 정한다 (검토 M3, 2026-11-21): 그날 한쪽 칸은 계통 노선 소속인데 반대쪽 칸은 아닌(또는 칸이 없는) 행이 그날의 끝이다.
# 가장 바깥 행은 그 한 경우다. 앞쪽 구간이 폐지·이관되면(徳島線 佃 1962~, 播但線 飾磨港 폐지 뒤 姫路) 안쪽 행이 끝이 되고,
# 계통 가운데가 남의 노선 소속이면(土讃線 佃–阿波池田 1914–1962는 徳島線) 그 양쪽(佃·阿波池田)이 자기 선로의 끝이다.
# 계통 정의의 시작·끝 노드(from/to)는 가장 넓은 범위일 뿐이다. _END[계통] = [(행, 안쪽 방향, 끝인 기간들)].
# 끝 노드 행 덮개·끝 이어짐·다음 역 찾기·끝 노드 표시가 모두 이것만 읽는다
_END=collections.defaultdict(list)
def _own_iv(rid_,e_):
    return _lead_clip(rid_,e_['id'],[(a_['valid_from'],a_['valid_to'] or 'ongoing') for a_ in _ra2[(routes[rid_]['line'],e_['id'])]])
for rid_,L_ in by_route.items():
    if rid_ in _HID_R or len(L_)<2:continue
    if routes[rid_].get('closed'):
        # 닫힌 계통(순환)은 행 순서로 양쪽을 나눌 수 없어 가장 바깥 행만 본다
        T_=[_ivu(_clip_iv(_edge_iv(rid_,y_['node_id']),*_rspan[rid_])) for y_ in L_]
        for inw_,ord_ in ((1,range(len(L_))),(-1,range(len(L_)-1,-1,-1))):
            acc_=[]
            for i_ in ord_:
                if not T_[i_]:continue
                e_=[x for x in _minus(list(T_[i_]),acc_) if _lo(x[0])<_lo(x[1],True) and _lo(x[1],True)>FLOOR]
                if e_:_END[rid_].append((L_[i_],inw_,e_))
                acc_=_ivu(acc_+T_[i_])
        continue
    sq_={}
    for y_ in L_:sq_.setdefault(y_['node_id'],y_['seq'])
    ga_=collections.defaultdict(list)
    for e in route_edges.get(rid_,()):
        if e['a']!=e['b']:ga_[e['a']].append(e);ga_[e['b']].append(e)
    def _side(y_,e0_):
        """행 y_에서 칸 e0_ 쪽으로 가면 만나는 첫 행의 순번 (행 없는 노드는 한 갈래로만 지나간다)"""
        at_,e_=y_['node_id'],e0_
        for _ in range(60):
            nx_=other(e_,at_)
            if nx_ in sq_ and nx_!=y_['node_id']:return sq_[nx_]
            c_=[x for x in ga_[nx_] if x is not e_]
            if len(c_)!=1:return None
            at_,e_=nx_,c_[0]
        return None
    for y_ in L_:
        lo_,up_=[],[]
        for e in ga_.get(y_['node_id'],()):
            k_=_side(y_,e)
            if k_ is None:continue
            (lo_ if k_<y_['seq'] else up_).extend(_own_iv(rid_,e))
        lo_=_ivu(_clip_iv(lo_,*_rspan[rid_]));up_=_ivu(_clip_iv(up_,*_rspan[rid_]))
        for inw_,a_,b_ in ((1,up_,lo_),(-1,lo_,up_)):
            # 기록 하한(1950) 전에만 끝이던 기간은 끝으로 보지 않는다 (연결과 같은 하한)
            e_=[x for x in _minus(list(a_),b_) if _lo(x[0])<_lo(x[1],True) and _lo(x[1],True)>FLOOR]
            if e_:_END[rid_].append((y_,inw_,e_))
_ENDROW={id(y_) for E_ in _END.values() for y_,_,_ in E_}
def _oend(rid2_,o_,day_=None):
    """행 o_가 그날(날짜가 없으면 어느 날이든) 계통 rid2_의 끝(날마다 정한 끝)이면 안쪽 방향(1·-1), 아니면 0. 행 위치(첫·마지막 행)로 보지 않는다"""
    for y_,inw_,iv_ in _END.get(rid2_,()):
        if y_ is o_ and (day_ is None or any(_lo(a_)<=day_<_lo(b_,True) for a_,b_ in iv_)):return inw_
    return 0
def _cut_end(rid2_,o_,base_):
    """기간들을 행 o_가 끝인 기간의 경계에서 나눈다(나눈 토막마다 끝인지가 하나다)"""
    bs_=sorted({v_ for y_,_,iv_ in _END.get(rid2_,()) if y_ is o_ for a_,b_ in iv_ for v_ in (_lo(a_),_lo(b_,True))})
    out_=[]
    for f_,t_ in base_:
        cur_=f_
        for b_ in bs_:
            if _lo(cur_)<b_<_lo(t_,True):out_.append((cur_,b_));cur_=b_
        out_.append((cur_,t_))
    return out_
_ENDIV=collections.defaultdict(list)
for E_ in _END.values():
    for y_,_,iv_ in E_:_ENDIV[id(y_)]+=iv_
_ecov=_pcov=0
for rid_,E_ in _END.items():
    for y_,inw_,iv_ in E_:_ecov+=_ecover(y_,iv_)
# 끝 노드는 그 노드를 지나는 다른 계통 화면에도 보인다. 단 두 계통이 그 자리에서 선로로 이어질 때만이다 (검토 H2: 品川 山手線 끝 ≠ 新幹線 品川).
# 이어짐 근거: 같은 노선, 또는 그 노드가 어느 계통에서도 승객이 서지 않는 노드(분기점·신호장), 또는 두 노선 사이 연결 근거 행(jx). 끝 이어짐과 같은 근거다
_pub_e={s_['node_id'] for s_ in stops if s_['is_stop']}
_EXJ=json.load(open(os.path.join(ROOT,'data','overrides','extend.json'),encoding='utf-8'))
_EXL=collections.defaultdict(set)   # 손 방면 자료: 계통 → 끝에서 이어지는 노선(방면 첫 역에 서는 노선)
_ysl=collections.defaultdict(set)
for s_ in stops:
    if s_['is_stop']:_ysl[s_['node_id']].add(routes[s_['route_id']]['line'])
for r_,v_ in _EXJ.items():
    if r_ not in routes:continue
    for g_ in (v_ if isinstance(v_,list) else [v_]):
        for sd_ in ('start','end'):
            for y_ in g_.get(sd_) or ():_EXL[r_]|=_ysl.get(SPLIT.get((routes[r_]['line'],y_),y_),set())
def _conn_ev(r1,r2,X):
    A_,B_=routes[r1]['line'],routes[r2]['line']
    if A_==B_:return True
    if _jnot_route(r1,X,B_,r2) or _jnot_route(r2,X,A_,r1):return False
    if X not in _pub_e or B_ in _EXL.get(r1,()):return True
    return any(j_['other']==B_ for j_ in jx.get((A_,X),())) or any(j_['other']==A_ for j_ in jx.get((B_,X),()))
_endt=collections.defaultdict(list)
for rid_,E_ in _END.items():
    for y_,inw_,iv_ in E_:_endt[y_['node_id']].append((rid_,iv_))
for rid_,L_ in by_route.items():
    if rid_ in _HID_R:continue
    for s_ in L_:
        iv_=[]
        for rid2_,iv2_ in _endt.get(s_['node_id'],()):
            if rid2_==rid_ or not _conn_ev(rid2_,rid_,s_['node_id']):continue
            iv_+=[x for g_,h_ in iv2_ for x in _clip_iv(_edge_iv(rid_,s_['node_id']),g_,h_)]
        iv_=[x for f0,t0 in [_rspan[rid_]] for x in _clip_iv(iv_,f0,t0)]
        # 이어진 다른 계통이 여기서 끝나는 날은 이 행 자리에도 실제 갈림 지점이 있다(숨기지 않는다, 新今宮 1961–1964 環状線 끝)
        if iv_:_pcov+=_ecover(s_,iv_);_ENDIV[id(s_)]+=iv_
print('끝 노드 행을 끝 칸 영업 기간으로',_ecov,'끝 노드를 지나는 다른 계통 행',_pcov)
def _ext_segs(o,sg_):
    """(확장 행이 없어진 뒤) 정차역 이웃이 없는 토막의 다음 역은 walk가 계통 끝 노드로 돌려준다"""
    return [sg_]
def _rev_ang(l_,r,s,mp):
    """끝 역 이어짐 l_의 선형 각: 이 계통이 끝 역으로 들어오는 칸과 상대 계통 다음 역 쪽 칸의 시작 방향 사이(곧게 이어지면 180°, 되돌아가면 0°) (11회차 S3)"""
    o_rid,o_seq=l_['_o'];rd_=_rep_day((l_['valid_from'],l_['valid_to']))
    L_=by_route[o_rid];i_=_SIDX.get((o_rid,o_seq))
    k_=next((k for k,x in enumerate(L_) if x['node_id']==l_['next_stop_node']),None)
    if i_ is None or k_ is None or k_==i_:return None
    w_=rdir(r['id'],s['seq'],_inside(r['id'],s['seq'],mp,rd_),rd_)
    return tdeg(w_,rdir(o_rid,o_seq,-1 if k_<i_ else 1,rd_))
links=[]
def add_link(s,oid,rr,kind,side,other,nxt,term,fl,src,pd,o=None):
    # 다음 역·끝 역이 이 역 자신(같은 역 묶음)뿐인 분기·이어짐은 갈 구간이 없다 (大江線→東臨港線 港東通 1944~1951 「다음=끝=港東通」)
    if kind in ('branch','continue') and nxt and nxt==term and (nxt==s['node_id'] or ((nodes.get(nxt) or {}).get('group') or nxt)==((nodes.get(s['node_id']) or {}).get('group') or s['node_id'])):
        WARN['link_no_segment'].append((s['route_id'],s['seq'],oid,nxt));return
    links.append(dict(route_id=s['route_id'],seq=s['seq'],other_line_id=oid,other_route_id=rr,kind=kind,side=side,at_edge=0,other_node=other,next_stop_node=nxt,terminal_node=term,flow=fl,flow_source=src,valid_from=pd[0],valid_to=pd[1],_o=(o['route_id'],o['seq']) if o else None,_s=s))
for s in stops:
    if not s['is_stop']:continue
    r=routes[s['route_id']];n=s['node_id'];seen=set();cur=is_cur(s)
    # 두 노선이 모두 이 역을 지나고 연결선도 있으면 환승 ①과 분기를 함께 둔다 (DESIGN §2.9 X자 교차)
    crossing=set()
    mp,mn=neighbors(r['id'],s['seq'],cur)
    isend=not(mp[0] and mn[0])
    near={n}
    for h in sorted(hubmem.get(n,())):near|={m for m in hubn[h] if linked(n,m)}
    # 역 이전 쌍의 다른 쪽 노드. 같은 노선은 아래에서 빠지고, 기간이 겹치는 다른 노선만 환승이 된다
    near|=MOVEPART.get(n,set())
    near=sorted(near,key=lambda x:(x!=n,x))
    def group_near(m):return m if m!=n and nodes[m].get('group')!=nodes[n].get('group') else None
    J=list(jx.get((r['line'],n),[]))
    # 상대 노선 → 선로로 이은 기간들. 그 노선과의 환승은 이 기간을 뺀 토막만이다 (中目黒 東横線: 2013-03-16 뒤 환승, 福島 奥羽本線 1991 改軌 뒤 환승)
    linked_pd=collections.defaultdict(list)
    # 그 기간을 선로로 이은 상대 계통·종류 (같은 노선 다른 계통으로의 분기가 지나가는 계통과의 환승을 끊지 않게, 越後湯沢 9회차 L)
    linked_rt=collections.defaultdict(list)
    own_pairs={frozenset((e['a'],e['b'])) for e in route_edges[r['id']]}
    own_ids={e['id'] for e in route_edges[r['id']]}
    # 제 계통 칸은 그날 이 노선 소속인 칸만이다. 다른 노선으로 넘어간 칸(和倉温泉–田鶴浜 1991 のと鉄道, 宮古–磯鶏 2019 リアス線)은 되돌아가는 방면이 아니다 (9회차 L, X K122)
    def _ownp(f_,day,own_pairs=own_pairs,ln_=r['line']):return f_ in own_pairs and f_ in open_on(ln_,day)
    ys_own={other(e,n) for e in route_edges[r['id']] if n in (e['a'],e['b'])}
    # 끝 역 이어짐의 다음 역이 그날 이 계통에서 바로 옆 정차역(들어온 쪽)이면 제 계통으로 되돌아가는 방면이라 이어짐이 아니다 (2회차 종합 K03).
    # 그날 서지 않는 옛 정차(徳島線 佃→阿波池田 1950~)와 순환을 닫는 방면(大阪環状線 新今宮→関西本線 天王寺)은 이어짐이다
    def _own(x_,pd_):
        if r.get('closed') or not x_:return False
        a_,b_=neighbors(r['id'],s['seq'],False,_rep_day(pd_))
        return x_ in (a_[0],b_[0])
    # 끝 역인지는 기간마다 다르다(北陸本線 敦賀: 2024-03-16부터 끝, 阿佐東線 海部: 2021-12-25 전까지 끝). 정차 기간을 끝·지나감이 바뀌는 날로 나눠
    # 토막마다 이어짐·분기를 판정한다. 환승 토막(linked_pd)은 모든 토막을 모은 뒤 아래에서 한 번에 낸다 (링크 조사 R5 2026-11-12)
    # 끝은 그날 그 방향으로 이 계통에 서는 역이 하나도 없을 때다. 옛 경로 계통으로 바로 옆 정차가 비는 날(室蘭本線 豊浦)은 끝이 아니다
    def _term_on(d,s=s,r=r):
        L_=by_route[r['id']]
        return not(any(x['is_stop'] and x['seq']<s['seq'] and on_day(x,d) for x in L_) and any(x['is_stop'] and x['seq']>s['seq'] and on_day(x,d) for x in L_))
    isend0=isend
    pieces_=[((s['valid_from'],s['valid_to']),(mp,mn),isend)]
    sp_=split_by_day(r['id'],(s['valid_from'],s['valid_to']),_term_on)
    if len(sp_)>1:pieces_=[(pd_,neighbors(r['id'],s['seq'],False,_rep_day(pd_)),t_) for pd_,t_ in sp_]
    s_all=s
    for pd_s,(mp,mn),isend_p in pieces_:
      s=s_all if len(pieces_)==1 else dict(s_all,valid_from=pd_s[0],valid_to=pd_s[1])
      for j in J:
          oid=j['other'];rr=j.get('other_route')
          # 같은 노선 다른 계통(옛 경로)으로의 이음은 구조 판정 그대로다 (遠州鉄道 八幡: 옛 경로와 칸을 함께 씀)
          isend=isend0 if oid==r['line'] else isend_p
          if rr==r['id'] or (oid==r['line'] and not rr):continue
          near_j=[j['_other_at']] if j.get('_other_at') else near
          cand=[(o,m) for m in near_j for o in node_stops.get(m,()) if routes[o['route_id']]['line']==oid and o['route_id']!=r['id'] and (not rr or o['route_id']==rr)]
          # 지정 노드에 그 기간 정차가 없으면(이전한 역의 옛 자리, 鳥羽 1929–1970 志摩線은 鳥羽（旧）) 묶음 안 노드로 찾는다
          if j.get('_other_at') and not [c for c in cand if period(s,c[0]) and _clip(period(s,c[0]),j)]:
              cand=[(o,m) for m in near for o in node_stops.get(m,()) if routes[o['route_id']]['line']==oid and o['route_id']!=r['id'] and (not rr or o['route_id']==rr)]
          cand=[c for c in cand if period(s,c[0])]
          # 근거 표(THROUGH·손 확인) 없이 묶음의 다른 노드(다른 역)로 선로를 잇지 않는다. 같은 사업자 이웃 역이라고 선로가 이어진 것은 아니다
          # (立久恵線 出雲市–一畑 電鉄出雲市, 3회차 chugoku_shikoku_2-017). 그 쌍은 아래에서 환승이 된다
          # 같은 group(같은 역 묶음)의 다른 노드(사업자마다 나뉜 노드)도 다른 노드다. 다른 노드끼리의 이어짐은 여객 직통 근거(THROUGH·노면전차 계통표)가 있을 때만이고,
          # 화물만 직통했거나 노선도의 선로 접속만 있으면 환승이다(사용자 확인 2026-11-16 鳥羽·美唄, 9회차 L / X K124)
          if not j.get('verified'):
              c0_=cand;cand=[c for c in cand if c[1]==n]
              # 다른 노드에만 상대 정차가 있어 환승으로 둔 근거 행(감사 K01이 판정된 것으로 센다)
              if c0_ and not cand:WARN['junction_other_node_transfer'].append((r['line'],oid,n))
          # 그 계통에만 「연결 없음」을 건 판정 행(JUNCTION_NOT route)
          if _jnot_route(r['id'],n,oid,rr):continue
          if not cand:continue
          # 두 노선이 같은 칸으로 같은 끝 역에 따로 들어오면 이어짐이 아니라 그 역의 환승이다 (高松（旧）: 予讃線·高徳線 각자 승강장)
          if isend:
              def _same_end(c,own=mp[0] or mn[0]):
                  p_,n_=neighbors(c[0]['route_id'],c[0]['seq'],is_cur(c[0]))
                  return not(p_[0] and n_[0]) and (p_[0] or n_[0])==own
              # 묶음의 다른 노드(이전한 새 자리)에 선 상대 정차는 보지 않는다. 같은 노드에서 함께 끝나면 환승이다
              _here=[c for c in cand if c[1]==n]
              if _here and all(_same_end(c) for c in _here):j['_same_end']=True;continue
          # 기간 한정 직통이 그 기간에 이 계통의 끝 역에서 이어지면, 지금은 지나가는 역이어도 이어짐이다 (京津線 御陵 1997: 京津三条 쪽이 같은 날 폐지).
          # 화면에서 그 역이 마지막 줄이면 끝 이어짐, 뒤에 폐지·이관 구간이 보이면 그쪽으로 갈라지는 분기로 그린다 (사용자 결정 2026-11-09)
          era=None
          # 근거 표 여객 직통 기간(passenger_only)으로 자른 선로 연결 토막은 자르기 전 기간(track_valid)으로 끝 역 시기를 본다 (塩尻 中央本線→篠ノ井線, 11회차 S3)
          jv_=j.get('track_valid') or j.get('valid')
          if j.get('continue') and not j.get('implied') and jv_:era=era_end(r['id'],s['seq'],jv_)
          # 끝난 기간 한정 행은 그 기간의 선로로 끝 역인지 본다. 오늘 끝 역이어도 그때 지나가는 역이었으면 분기다 (2회차 종합 K01)
          thru_then=era=='through' and isend and (jv_ or [None,'ongoing'])[1] not in (None,'ongoing')
          if isend or era=='through':era=None
          if (isend and not thru_then) or era:kind='continue'
          elif j.get('implied'):
              o_,_m=pick(cand,s);pr_,nx_=neighbors(o_['route_id'],o_['seq'],is_cur(o_))
              if pr_[0] and nx_[0]:continue                # 상대도 지나가는 역이면 환승으로 둔다
              kind='branch'
          # 끝 역이 아닌 역의 이어짐(continue) 행은 그 역에서 갈라지는 분기다 (綾瀬 常磐線→千代田線, 越後湯沢 上越新幹線→ガーラ湯沢, 2회차 종합 K01)
          else:kind='branch'
          n0_=len(links);j.setdefault('_tried',set()).add(kind)
          seen.add(oid)
          if rr:seen.add(rr)
          # 반대 화면 행의 방향(side): 상대 노선에서 위로 달리는 열차가 곧장 이 노선으로 들어오면, 이 노선에서 들어가는 열차는 상대 노선을 아래로 간다 (夜明)
          rside=next((x.get('side') for x in jx.get((oid,n),[]) if x['other']==r['line'] and x.get('side') and not x.get('implied')),None) if oid!=r['line'] else None
          for o,m,pd0 in cover(cand,s,per_route=(kind=='branch')):
              # 근거 표에 기간이 적힌 직통(THROUGH)은 그 기간만 잇는다
              pd0=_clip(pd0,j)
              if not pd0:continue
              # 궤간·방식이 그날 다르면 선로가 이어지지 않는다 (AGT·모노레일·리니어·강삭, 改軌. U06·K04)
              ys_o={other(e,m) for e in route_edges[o['route_id']] if m in (e['a'],e['b'])}
              # 칸별 궤간이 바뀌는 날(新庄 1999 奥羽本線 新庄–舟形 1435)에서도 나눠 방면마다 그날 궤간으로 본다
              for pd1 in [q_ for p_ in track_ok(r['line'],oid,n,pd0,ys_own,m,ys_o) for q_ in _gsplit(r['line'],oid,p_)]:
                  # 다음 역·끝 역은 그날 선로로 찾고, 기간 안에서 바뀌면 행을 나눈다 (K03)
                  # 시기별 끝 역의 직통(era)은 그 역이 끝이던 첫날부터 한 행이다. 나누면 뒤 토막은 그 역이 끝이 아닌 날에 시작한다 (盛岡 1997, 中洲川端 1982)
                  segs_=[(pd1,neighbors(o['route_id'],o['seq'],False,_rep_day(pd1)))] if era else split_by_day(o['route_id'],pd1,lambda d,o=o:neighbors(o['route_id'],o['seq'],False,d))
                  # 정차역 이웃도, 대표 날의 확장 역도 없어 버려질 토막은 상대 계통 확장 행 기간으로 잘라 그 토막만 확장 역을 다음 역으로 본다.
                  # 이미 이어지는 토막은 건드리지 않는다 (1986 秋田港線: 秋田港이 서지 않고 秋田博前까지 확장된 38일, 11회차 S3)
                  segs_=[q_ for sg_ in segs_ for q_ in _ext_segs(o,sg_)]
                  for pd,(pr,nx) in segs_:
                      # 상대 계통이 숨은 노드와 확장 행뿐인 연결선이면(西武秩父 連絡線·北初富 1期·瓦町 長尾線 옛 경로 1945–1951) 확장 역을 다음 역으로 본다 (9회차 L, X K122)
                      if not(pr[0] or nx[0]):pr,nx=neighbors(o['route_id'],o['seq'],False,_rep_day(pd),ext=True)
                      if not(pr[0] or nx[0]):continue
                      thru=bool(pr[0] and nx[0])
                      if kind=='branch' and thru:crossing.add(oid)
                      else:linked_pd[oid].append(pd);linked_rt[oid].append((pd,o['route_id'],kind))
                      if thru:
                          if kind=='continue':
                              # 상대가 지나가는 역에서 끝나는 직통은 들어온 방향에서 곧게 이어지는 한쪽만이다 (中目黒의 日比谷線→東横線 横浜 방면, 점검 권장 4)
                              # 이 계통이 들어온 칸으로 되돌아가는 방면(尼崎港線 尼崎→塚口)과 제 계통 안의 역으로 가는 방면은 이어짐이 아니다
                              def _back(x_):return _ownp(frozenset((m,first_hop(o['route_id'],o['seq'],-1 if x_ is pr else 1,_rep_day(pd)))),_rep_day(pd)) or _own(x_[0],pd)
                              # 방향은 선형 시작 방향으로 잰다(川西能勢口 妙見線→宝塚本線 梅田 방면). 그날 궤간이 맞지 않는 방면(大曲 奥羽本線 横手 쪽)은 뺀다
                              rd_=_rep_day(pd);own_st=(-1 if era=='down' else 1) if era else _inside(r['id'],s['seq'],mp,rd_);w_=rdir(r['id'],s['seq'],own_st,rd_)
                              def _gok(x_):
                                  h_=hop(o['route_id'],o['seq'],-1 if x_ is pr else 1,rd_)[0]
                                  return not h_ or _gfit(r['line'],n,ys_own,oid,m,{h_},rd_)
                              def _vd(x_):return rdir(o['route_id'],o['seq'],-1 if x_ is pr else 1,rd_)
                              if j.get('_toward'):
                                  # 운행 계통표·근거 표가 적은 방면(그 역 쪽)만 (都電·仙台市電 계통, 川西能勢口 日生エクスプレス 梅田 방면)
                                  xs_=_tw_pick(o,pr,nx,j)
                              elif rside:
                                  xs_=[nx if rside=='up' else pr]
                                  # 반대 화면 행의 방향이 선형과 어긋나 되돌아가는 쪽을 가리키면(손 행 오독) 곧게 나가는 쪽을 쓰고 경고로 남긴다
                                  alt_=pr if xs_[0] is nx else nx
                                  a1_,a2_=tdeg(w_,_vd(xs_[0])),tdeg(w_,_vd(alt_))
                                  # 두 각이 기준각 둘레에서 비슷하면(瓦町 長尾線 옛 경로 1945–1951: 75°·85°, 직각에 가까운 T자) 선형으로 손 행을 뒤집지 않는다. 30° 넘게 갈릴 때만 (9회차 L K68)
                                  if not j.get('verified') and a1_ is not None and a2_ is not None and a1_<sharp_c(r['line'],oid)<=a2_ and a2_-a1_>=30 and alt_[0] and not _back(alt_):
                                      WARN['rside_geo_conflict'].append((r['id'],n,oid,rside,round(a1_),round(a2_)));xs_=[alt_]
                                  # 손 행 방향 쪽이 그날 궤간이 맞지 않거나 되돌아가는 쪽이면 다른 쪽으로 잇는다(大曲 田沢湖線 1997~·新庄 陸羽西線 1999~: 奥羽本線 남쪽은 표준궤, 북쪽 1067·1435 그대로) (9회차 L, X K122)
                                  elif (_back(xs_[0]) or not _gok(xs_[0])) and alt_[0] and not _back(alt_) and _gok(alt_):
                                      WARN['rside_fallback'].append((r['id'],n,oid,rside,pd));xs_=[alt_]
                                  elif not j.get('verified') and a1_ is not None and a2_ is not None and a1_<sharp_c(r['line'],oid)<=a2_:WARN['rside_geo_close'].append((r['id'],n,oid,rside,round(a1_),round(a2_)))
                              else:
                                  ok_=[x_ for x_ in (pr,nx) if not _back(x_) and _gok(x_)]
                                  dp_,dn_=ucos(_vd(pr),w_),ucos(_vd(nx),w_)
                                  # 근거 표 직통인데 선형으로 방면이 갈리지 않음(두 방면이 모두 곧거나 모두 되돌아감): 방면 칸(a_toward·b_toward)이 있어야 한다 (감사 K67)
                                  if j.get('verified') and not j.get('_ts') and len(ok_)==2:
                                      ap_,an_=tdeg(w_,_vd(pr)),tdeg(w_,_vd(nx));th_=sharp_c(r['line'],oid)
                                      if ap_ is None or an_ is None or (ap_>=th_)==(an_>=th_):WARN['through_dir_geo_ambiguous'].append((r['line'],oid,n,m,pd[0],pd[1],None if ap_ is None else round(ap_),None if an_ is None else round(an_)))
                                  xs_=ok_ if len(ok_)<2 else [pr if dp_<dn_ else nx] if dp_ is not None and dn_ is not None else [pr,nx]
                              n1_=len(links)
                              # 고른 방면이 모두 되돌아가는 각이고 곧게 나가는 방면이 그날 상대 노선의 다른 계통에 있으면 그쪽으로 잇는다 (방면별 계통 후보)
                              if not j.get('_toward') and not rside and not era and xs_ and all(_back(x_) or not _gok(x_) or (lambda a_:a_ is not None and a_<sharp_c(r['line'],oid))(tdeg(w_,_vd(x_))) for x_ in xs_) \
                                 and _alt_cont(s,r,mp,oid,m,o,pd,ys_own,None,_own,rr,group_near):continue
                              for x_ in xs_:
                                  if _back(x_) or not _gok(x_):continue
                                  add_link(s,oid,rr,kind,era,group_near(m),x_[0],x_[1],None,None,pd,o)
                              # 이을 방면이 없으면 그 기간은 환승이다
                              if len(links)==n1_:linked_pd[oid].remove(pd)
                              continue
                          sd_=j.get('side')
                          if j.get('_toward'):
                              # 방면마다 방향: 그 방면 칸이 이 계통 아래쪽 칸과 나란하면 위쪽에서 오는 열차가 곧장 들어감(down) (淡路 X자 교차 두 연결선)
                              rd_=_rep_day(pd);vu_,vd_=rdir(r['id'],s['seq'],-1,rd_),rdir(r['id'],s['seq'],1,rd_)
                              # 이 노선 쪽 방면 역이 있으면 방향은 계통 순서로 정한다(그 역이 위쪽이면 그쪽에서 내려와 곧장 들어가므로 down). 선형보다 앞선다
                              own_sd_=None
                              if j.get('_own_toward'):
                                  L0_=by_route[r['id']];i0_=_SIDX.get((r['id'],s['seq']))
                                  ks_=[k for k,x in enumerate(L0_) if x['node_id'] in j['_own_toward']]
                                  if i0_ is not None and ks_ and all(k!=i0_ for k in ks_):
                                      ups_={k<i0_ for k in ks_}
                                      if len(ups_)==1:own_sd_='down' if ups_.pop() else 'up'
                                      else:WARN['own_toward_both'].append((r['id'],n,oid))
                                  else:WARN['toward_miss'].append((r['id'],sorted(j['_own_toward'])))
                              for x_ in _tw_pick(o,pr,nx,j):
                                  va_=rdir(o['route_id'],o['seq'],-1 if x_ is pr else 1,rd_);cu_,cd_=ucos(va_,vu_),ucos(va_,vd_)
                                  sdx_=own_sd_ or (('up' if cu_>cd_ else 'down') if cu_ is not None and cd_ is not None and abs(cu_-cd_)>=.5 else sd_)
                                  add_link(s,oid,rr,kind,sdx_,group_near(m),x_[0],x_[1],None,None,pd,o)
                              continue
                          if not sd_ and (j.get('continue') or j.get('_geo')):
                              # 방향을 적지 않은 이어짐 행(綾瀬 常磐線→千代田線)은 이 노선 한쪽에서 들어와 상대 노선으로 가장 곧게 나가는 방면이다.
                              # 아래쪽(mn)에서 와서 위로 달리는 열차가 곧장 들어가면 up이다
                              rd_=_rep_day(pd)
                              def _cos(xs,os_):
                                  c_=ucos(rdir(o['route_id'],o['seq'],xs,rd_),rdir(r['id'],s['seq'],os_,rd_))
                                  return -c_ if c_ is not None else None
                              sc_=[(c_,x_,sd2) for x_,xs in ((pr,-1),(nx,1)) if x_[0] for own_,os_,sd2 in ((mn,1,'up'),(mp,-1,'down')) if own_[0] for c_ in [_cos(xs,os_)] if c_ is not None]
                              if sc_:
                                  _,(nxt,term),sd_=max(sc_,key=lambda z:z[0])
                                  # 두 노선이 모두 지나가는 X자 교차의 근거 표 직통은 네 방면 가운데 어느 것인지 선형으로 정할 수 없다(名鉄 知立 三河線→名古屋本線 名古屋 방면): 방면 칸이 있어야 한다 (감사 K67)
                                  if j.get('verified') and not j.get('_ts') and kind=='branch':WARN['through_dir_geo_ambiguous'].append((r['line'],oid,n,m,pd[0],pd[1],'X',None))
                                  add_link(s,oid,rr,kind,sd_,group_near(m),nxt,term,None,None,pd,o);continue
                          rd_=_rep_day(pd);w=rdir(r['id'],s['seq'],-1 if sd_=='up' else 1,rd_)
                          def dot(xs):
                              c_=ucos(rdir(o['route_id'],o['seq'],xs,rd_),w)
                              return c_ if c_ is not None else 0
                          nxt,term=(pr if dot(-1)>dot(1) else nx)
                          # 근거 표 직통의 분기 방면을 방향 칸 없이 선형으로 골랐는데 두 방면이 거의 같은 각이면 방면 칸이 있어야 한다 (감사 K67)
                          # 두 노선이 모두 지나가는 X자 교차의 직통은 네 방면 가운데 어느 것인지 선형으로 정할 수 없다(名鉄 知立 三河線→名古屋本線 名古屋 방면)
                          if j.get('verified') and not j.get('_ts') and not sd_:WARN['through_dir_geo_ambiguous'].append((r['line'],oid,n,m,pd[0],pd[1],round(dot(-1),2),round(dot(1),2)))
                      else:
                          nxt,term=pr if pr[0] else nx
                          if kind=='continue' and _own(nxt,pd):linked_pd[oid].remove(pd);continue
                          if kind=='continue':
                              # 그날 궤간이 맞지 않으면 잇지 않는다(新庄 陸羽西線→奥羽本線 1999~)
                              rd_=_rep_day(pd);xs=-1 if pr[0] else 1
                              h_=hop(o['route_id'],o['seq'],xs,rd_)[0]
                              if h_ and not _gfit(r['line'],n,ys_own,oid,m,{h_},rd_):WARN['cont_gauge'].append((r['id'],n,oid,h_,pd));j['_sharp']=True;linked_pd[oid].remove(pd);continue
                              # 스위치백형(역에서 방향만 바뀜)도 선로가 그 역에서 이어지면 끝에서 이어짐이다(사용자 결정 2026-11-12). 되돌아가는 각은 감사 확인 목록(K68)이 본다
                              # 다만 곧게 나가는 방면이 그날 상대 노선의 다른 계통(옛 경로 계통)에 있으면 그쪽으로 잇는다 (방면별 계통 후보)
                              if not j.get('_toward') and _alt_cont(s,r,mp,oid,m,o,pd,ys_own,xs,_own,rr,group_near):continue
                      # 상대 계통의 그날 남은 칸이 모두 이 계통 칸이면 갈라지는 선로가 없다(外房線 蘇我: 1963 千葉(旧) 폐지 뒤 옛 경로 계통은 蘇我–本千葉만 남음)
                      if kind=='branch' and oid==r['line'] and _all_own(o['route_id'],own_ids,_rep_day(pd),own_pairs):
                          WARN['branch_all_own'].append((r['id'],n,o['route_id'],pd))
                          if pd in linked_pd[oid]:linked_pd[oid].remove(pd)
                          continue
                      # 이 노선 쪽 방면 역(운행 계통표 x_toward·y_toward, junction_side own_toward)이 있으면 지나가는 이 노선의 분기 방향은 계통 순서로 정한다.
                      # 그 역이 위쪽이면 그쪽에서 내려와 곧장 들어가므로 down. 방면 역이 두 쪽에 다 있으면(와이: 三宅坂 9·10系統, 古川橋 4·5·7系統) 쪽마다 한 행이다.
                      # 선형 방향(side_geo)보다 앞선다(丸ノ内一丁目 28系統 永代橋 쪽 → up) (4회차 kanto_1-010·kanto_1-012, 11회차 S2)
                      if kind=='branch' and j.get('_own_toward'):
                          L0_=by_route[r['id']];i0_=_SIDX.get((r['id'],s['seq']))
                          ks_=[k for k,x in enumerate(L0_) if x['node_id'] in j['_own_toward'] and not x.get('is_extension')]
                          sds_=sorted({'down' if k<i0_ else 'up' for k in ks_ if k!=i0_}) if i0_ is not None else []
                          if sds_:
                              for sdo_ in sds_:
                                  add_link(s,oid,rr,kind,sdo_,group_near(m),nxt,term,None,None,pd,o)
                                  if sdo_!=j.get('side'):WARN['branch_side_own_toward'].append((r['id'],n,oid,j.get('side'),sdo_,pd[0]))
                              continue
                      add_link(s,oid,rr,kind,j.get('side') or era,group_near(m),nxt,term,None,None,pd,o)
          # 이 행으로 낸 계통 이음의 종류 (연결 표를 판정대로 낼 때 쓴다)
          if len(links)>n0_:j.setdefault('_kinds',set()).add(kind)
          # 스위치백 직통(근거 표 reverse 행): 끝 역 이어짐 가운데 이 계통 마지막 칸과 상대 방면 칸이 되돌아가는 각(기준각 미만)인 방면에 표식을 건다.
          # 그 행의 이어짐이 하나도 날카롭지 않으면(옛 역 자리 배선을 노드가 담지 못함) 아래에서 모두 켜고 경고로 남긴다 (11회차 S3)
          if j.get('_reverse'):
              for l_ in links[n0_:]:
                  if l_['kind']!='continue' or not l_.get('_o'):continue
                  l_['_rj']=(id(j),r['id']);a_=_rev_ang(l_,r,s,mp)
                  if a_ is not None and a_<sharp_c(r['line'],oid):l_['reverse']=1
      # 지선 끝에서 같은 노선의 다른 계통으로 이어진다. 그날 열린 방면만이고(옛 경로가 대체한 새 선로 쪽은 그때 없음), 이 계통이 들어온 칸을 함께 쓰는 방면(瀬戸線 두 계통, 西武園線)은 뺀다 (K03)
      if isend0:
          for o in node_stops.get(n,()):
              if routes[o['route_id']]['line']==r['line'] and o['route_id']!=r['id'] and o['route_id'] not in seen:
                  pd0=period(s,o)
                  if not pd0:continue
                  seen.add(o['route_id'])
                  for pd,(pr,nx) in split_by_day(o['route_id'],pd0,lambda d,o=o:neighbors(o['route_id'],o['seq'],False,d)):
                      rd_=_rep_day(pd)
                      if _jnot_route(r['id'],n,r['line'],o['route_id']):continue
                      ys_o={other(e,n) for e in route_edges[o['route_id']] if n in (e['a'],e['b'])}
                      xs_=[x for x in ([pr,nx] if pr[0] and nx[0] else [pr if pr[0] else nx]) if x[0]
                           and not(_ownp(frozenset((n,first_hop(o['route_id'],o['seq'],-1 if x is pr else 1,rd_))),rd_) or _own(x[0],pd))]
                      # 궤간이 다른 갈래(上越線 越後湯沢: ガーラ湯沢 1435 계통과 본선 1067)는 잇지 않는다
                      _g=[x for x in xs_ if _gfit(r['line'],n,ys_own,r['line'],n,{hop(o['route_id'],o['seq'],-1 if x is pr else 1,rd_)[0]}-{None} or ys_o,rd_)]
                      if len(_g)<len(xs_):WARN['cont_gauge'].append((r['id'],n,o['route_id'],None,pd))
                      w0_=rdir(r['id'],s['seq'],_inside(r['id'],s['seq'],mp,rd_),rd_)
                      # 같은 쪽으로 나란히 나가는 계통(駒込 山手貨물線→山手線 田端, 西武園線 두 계통)은 이어짐이 아니다
                      xs_=[]
                      for x in _g:
                          a_=tdeg(w0_,rdir(o['route_id'],o['seq'],-1 if x is pr else 1,rd_))
                          if a_ is not None and a_<sharp_c(r['line'],r['line']):WARN['cont_sharp'].append((r['id'],n,o['route_id'],x[0],round(a_)));continue
                          xs_.append(x)
                      # 상대 계통이 이 역을 지나가면 들어온 방향에서 가장 곧게 나가는 한쪽만 잇는다. 되돌아가는 쪽(鶴見·大垣·赤羽·日暮里 갈래)은 다른 노선 이음처럼 뺀다 (스위치백 조사 R6-E 2026-11-12)
                      if len(xs_)==2:
                          d0_,d1_=ucos(rdir(o['route_id'],o['seq'],-1,rd_),w0_),ucos(rdir(o['route_id'],o['seq'],1,rd_),w0_)
                          if d0_ is not None and d1_ is not None:xs_=[xs_[0] if d0_<d1_ else xs_[1]]
                      for x in xs_:
                          add_link(s,r['line'],o['route_id'],'continue',None,None,x[0],x[1],None,None,pd,o)
    s=s_all
    by={}
    for m in near:
        for o in node_stops.get(m,()):
            ol=routes[o['route_id']]['line']
            if ol==r['line'] or not period(s,o):continue
            by.setdefault(ol,[]).append((o,m))
    for ol,cand in sorted(by.items()):
        for o,m,pd in cover(cand,s):
            # 선로로 이은 기간을 뺀 앞뒤 토막만 환승이다
            pieces=[pd]
            for g_,h_ in sorted(linked_pd.get(ol,()),key=lambda x:_lo(x[0])):
                # X자 교차의 일반화: 이 계통이 지나가는 역에서 상대 노선의 다른 계통(지선)으로만 분기하고, 환승 후보 계통은 그날 이 역을 지나가면
                # 그 계통과의 환승은 남긴다 (越後湯沢: 上越新幹線 → ガーラ湯沢 갈래 분기 1990~, 上越線 본선 환승 그대로, 3회차 kanto_1-010)
                rts_={(rt_,k_) for p_,rt_,k_ in linked_rt.get(ol,()) if p_==(g_,h_)}
                if rts_ and all(k_=='branch' and rt_!=o['route_id'] for rt_,k_ in rts_):
                    rd_=_rep_day((max((g_,pd[0]),key=lambda x:_lo(x)),min((h_,pd[1]),key=lambda x:_lo(x,True))))
                    a_,b_=neighbors(r['id'],s['seq'],False,rd_);c_,d_=neighbors(o['route_id'],o['seq'],False,rd_)
                    if a_[0] and b_[0] and c_[0] and d_[0]:WARN['transfer_kept_crossing_branch'].append((r['id'],n,o['route_id'],g_,h_));continue
                # 끝 이어짐(continue) 행도 이 계통과 환승 후보 계통이 그날 모두 이 역을 지나가면 X자 교차다(분기 행의 crossing과 같은 규칙).
                # 시기별 끝 역 직통은 그 역이 끝이던 첫날부터 한 행이라(萩山 拝島線→多摩湖線 1958~, 拝島線은 1962 小川 연장 뒤 지나감) 지나가게 된 날부터는 환승을 남긴다.
                # 상대 화면(多摩湖線 → 拝島線 분기 + 1962~ 환승)과 대칭 (11회차 F1)
                cut_=[(g_,h_)]
                if rts_ and all(k_=='continue' for rt_,k_ in rts_):
                    def _both(d,o=o):
                        a_,b_=neighbors(r['id'],s['seq'],False,d);c_,d2_=neighbors(o['route_id'],o['seq'],False,d)
                        return bool(a_[0] and b_[0] and c_[0] and d2_[0])
                    # 이 계통이 바뀌는 날로 먼저 나누고(대표 날마다 다른 값이라 합치지 않음), 토막마다 후보 계통이 바뀌는 날로 다시 나눠 둘 다 지나가는 날을 뺀다
                    cut_=[q2_ for q1_,_d in split_by_day(r['id'],(g_,h_),lambda d:d) for q2_,v_ in split_by_day(o['route_id'],q1_,_both) if not v_]
                    _cm=[]
                    for q_ in cut_:
                        if _cm and _cm[-1][1]==q_[0]:_cm[-1]=(_cm[-1][0],q_[1])
                        else:_cm.append(q_)
                    cut_=_cm
                    if cut_!=[(g_,h_)]:WARN['transfer_kept_crossing_continue'].append((r['id'],n,o['route_id'],g_,h_,cut_))
                for g2_,h2_ in cut_:
                    nxt_=[]
                    for f_,u_ in pieces:
                        if _lo(h2_,True)<=_lo(f_) or _lo(g2_)>=_lo(u_,True):nxt_.append((f_,u_));continue
                        if _lo(f_)<_lo(g2_):nxt_.append((f_,g2_))
                        if h2_ not in (None,'ongoing') and _lo(h2_)<_lo(u_,True):nxt_.append((h2_,u_))
                    pieces=nxt_
            for pc_ in pieces:
                if _lo(pc_[0])<_lo(pc_[1],True):
                    # 환승도 분기·이어짐처럼 상대 계통의 그날 정차로 나눠 그날의 다음 역·끝 역을 둔다 (3회차 hokkaido_1-006)
                    for pc2_,(fl,src,nxt,term) in split_by_day(o['route_id'],pc_,lambda d,o=o:flow_of(s,o,d)):
                        add_link(s,ol,o['route_id'],'transfer',None,group_near(m),nxt,term,fl,src,pc2_,o)

# ── 연결 행 다듬기 (3회차 전수 점검 W1a, 판 2026-11-15.1)
# ① 연결 기간은 양쪽 계통이 그 역에서 실제로 영업한 날만이다: 정차 기간에서 정차 공백을 빼고, 그 역에 닿는 계통 칸이 모두 휴지인 날도 뺀다
#   (魚沼線 来迎寺 1944–1954 전선 휴지, 京王 北野 御陵線 1945–1967 휴지, 鹿島臨港線 여객 없던 기간). 그 역에 닿는 칸의 영업 기록이 없으면 자르지 않는다
_LOPEN=collections.defaultdict(list)
for _r in life:
    if _r['status']=='open':_LOPEN[_r['edge_id']].append((_r['valid_from'],_r['valid_to']))
def _ivu(iv):
    """기간들의 합집합(시작 순)"""
    out=[]
    for f_,t_ in sorted(iv,key=lambda x:_lo(x[0])):
        if out and _lo(f_)<=_lo(out[-1][1],True):
            if _lo(t_,True)>_lo(out[-1][1],True):out[-1]=(out[-1][0],t_)
        else:out.append((f_,t_))
    return out
def _ivx(A,B):
    """두 기간 목록의 교집합. 같은 날이면 앞 목록(A)의 값을 쓴다"""
    out=[]
    for f1,t1 in A:
        for f2,t2 in B:
            f_=f2 if _lo(f2)>_lo(f1) else f1
            t_=t2 if _lo(t2,True)<_lo(t1,True) else t1
            if _lo(f_)<_lo(t_,True):out.append((f_,t_))
    return out
_alc={}
def _alive(rid,seq,sel=False):
    """행이 그 노드에서 영업한 기간. sel이면(분기·이어짐) 고를 수 있는 서지 않은 때(끝 노드)도 넣는다"""
    k_=(rid,seq,sel)
    if k_ in _alc:return _alc[k_]
    k0_=(rid,seq)
    s_=by_route[rid][_SIDX[k0_]];n_=s_['node_id']
    base=[(s_['valid_from'],s_['valid_to'])]
    for g_,h_ in sorted(_GAPS.get(id(s_),())):
        nb=[]
        for f_,t_ in base:
            if _lo(t_,True)<=g_ or _lo(f_)>=h_:nb.append((f_,t_));continue
            if _lo(f_)<g_:nb.append((f_,g_))
            if h_<_lo(t_,True):nb.append((h_,t_))
        base=nb
    # 분기·이어짐은 끝 노드로 늘린 기간(행 기간 앞·뒤)에도 산다
    if sel and s_.get('sel_iv'):base=_ivu(base+[x_ for x_ in s_['sel_iv'] if _lo(x_[0])<_lo(x_[1],True)])
    es_=[e_ for f_,e_ in _RPE.get(rid,{}).items() if n_ in f_]
    # 칸 영업 기간은 그 계통 노선 소속 기간과 겹친 것만 센다(이관된 칸은 남의 노선 영업: 山田線 宮古–磯鶏는 2019부터 リアス線)
    ln_=routes[rid]['line']
    def _mem(e_):return _ivu([(a_['valid_from'],a_['valid_to']) for a_ in _ra[(ln_,e_)]])
    if es_ and all(_LOPEN.get(e_) for e_ in es_):base=_ivx(base,_ivu([iv for e_ in es_ for iv in (_ivx(_LOPEN[e_],_mem(e_)) if any(_ra[(ln_,x_)] for x_ in es_) else _LOPEN[e_])]))
    _alc[k_]=base
    return base
_nl0=len(links);_cut=0;_out=[]
for l_ in links:
    if not l_.get('_o'):_out.append(l_);continue
    sel_=l_['kind'] in ('branch','continue')
    A_=_ivx([(l_['valid_from'],l_['valid_to'])],_alive(l_['route_id'],l_['seq'],sel_))
    A_=_ivx(A_,_alive(*l_['_o'],sel_))
    if A_!=[(l_['valid_from'],l_['valid_to'])]:_cut+=1
    for f_,t_ in A_:_out.append(dict(l_,valid_from=f_,valid_to=t_))
links=_out
# ── 끝 이어짐 (5번 결정 2026-11-19, 입력 단계 재구성 2026-11-20) ──
# 계통 A의 끝 행 h(노드 X)와, X(또는 근거 행이 적은 상대 노드)에 행이 있는 다른 노선 계통 B의 행 o를 잇는다.
# 두 행이 함께 서는 날은 위 생성기가 이미 이었으므로, 둘 가운데 하나라도 서지 않는 날(숨은 분기점·신호장, 끝 역이 정차 전·뒤, 지나가는 계통이 서지 않는 노드)만 여기서 잇는다.
# 선로 연결은 X가 어느 계통에서도 승객이 서지 않는 노드(분기점·신호장)면 그 자리에서 갈라진 것이고, 아니면 연결 근거 행(jx)이 있어야 한다.
# A→B 이어짐: B가 그 노드에서 끝나면 안쪽, 지나가면 근거 행 방면(_toward) 또는 A가 들어온 방향에서 곧게 나가는 쪽(기준각 이상, 가장 곧은 것).
# B→A: B가 지나가면 분기, 끝나면 이어짐. 다음 역·끝 역은 A 끝에서 안쪽으로 처음·마지막 정차역(정차역이 없으면 반대쪽 끝 노드).
# 기간은 두 행이 고를 수 있고 그 노드에 닿는 두 계통 칸이 영업한 날(_alive, 서지 않는 끝 행 기간 포함)이고 기록 하한(1950) 뒤만이다
def group_near_e(a,b):return b if b!=a and nodes[b].get('group')!=nodes[a].get('group') else None
_rows_at=collections.defaultdict(list)
for rid_,L_ in by_route.items():
    for y_ in L_:_rows_at[y_['node_id']].append(y_)
_pub_e={s_['node_id'] for s_ in stops if s_['is_stop']}
_gp_e=collections.defaultdict(list)
for g_ in stop_gaps:_gp_e[id(g_[0])].append((g_[1],g_[2]))
def _stop_iv(y):
    """행 y가 서는 기간들(서지 않은 때를 뺀 토막). 정차 행이 아니면 없음"""
    if not y['is_stop']:return []
    iv=[(y['valid_from'],y['valid_to'] or 'ongoing')]
    for c_ in _gp_e.get(id(y),()):iv=_iv_sub(iv,c_)
    return iv
def _minus(A,B):
    for c_ in B:A=_iv_sub(A,c_)
    return A
_xt=0
_grpm=collections.defaultdict(set)
for x_,v_ in nodes.items():
    if v_.get('group'):_grpm[v_['group']].add(x_)
_nat={(y_['route_id'],y_['seq']):y_['node_id'] for y_ in stops}
# 끝 이어짐 방면 자료(extend.json): 계통 끝에서 이어지는 노선과 방면을 그 방면 첫 역(Y)으로 손으로 정한 자료(山手貨物線 끝 田端信号場 → 上中里 쪽·三河島 쪽).
# 확장 행으로 쓰지 않고 끝 이어짐의 입력으로 쓴다. 손으로 정한 방면이라 아래 일반 규칙(기하로 고른 방면)보다 먼저 낸다. Y에 서는 노선(같은 노선 다른 계통 포함)의 계통 가운데 끝 노드 X(없으면 같은 묶음 다른 노드)를 지나는 계통 Q로,
# X에서 Y 쪽(Q에 Y가 있으면 그 순서, 없으면 좌표상 Y 쪽)으로 잇는다. 기간은 두 행을 고를 수 있고 두 칸이 영업하며 Y가 서는 날, 이미 그 노선으로 이은 날은 뺀다
_EXT=json.load(open(os.path.join(ROOT,'data','overrides','extend.json'),encoding='utf-8'))
_ystop=collections.defaultdict(list)
for s_ in stops:
    if s_['is_stop']:_ystop[s_['node_id']].append(s_)
def _vec(a,b):
    p,q=ppos.get(a),ppos.get(b)
    return ((q['lat']-p['lat']),(q['lon']-p['lon'])*math.cos(math.radians(p['lat']))) if p and q else None
_xt3=0;_xmiss=[]
for rid,v in sorted(_EXT.items()):
    if rid not in routes or rid in _HID_R:continue
    L=by_route[rid];A_=routes[rid]['line']
    for g_ in (v if isinstance(v,list) else [v]):
        for h,inw,eiv_ in _END.get(rid,()):
            side_='start' if inw==1 else 'end'
            if not g_.get(side_):continue
            X=h['node_id'];gm_={X}|set(_grpm.get(nodes[X].get('group')) or ())
            for Y in g_[side_]:
                Y=SPLIT.get((A_,Y),Y)
                ly_={routes[y_['route_id']]['line'] for y_ in _ystop.get(Y,())}
                cand=[]
                for q in sorted({r_ for l_ in ly_ for r_ in _RBL.get(l_,())}):
                    if q==rid or q in _HID_R:continue
                    for o in by_route.get(q,()):
                        if o['node_id'] in gm_:cand.append((Y not in {y_['node_id'] for y_ in by_route[q]},o['node_id']!=X,q,o))
                if not cand:_xmiss.append((rid,X,Y));continue
                # 후보 계통을 차례로 본다: Y가 그 계통에 있음 → 같은 노드 → 같은 노선 → 이름. 앞 후보가 맡은 날은 빼고 남는 날을 다음 후보가 맡는다
                # (京成 東成田 계통 1978–1991: 京成成田을 지나는 계통은 京成本線·東成田線인데 東成田線은 1991~)
                cand.sort(key=lambda c:(c[0],c[1],routes[c[2]]['line']!=A_,c[2]))
                _done_y=[]
                for _,_,rid2,o in cand:
                  m=o['node_id']  ;B_=routes[rid2]['line'];L2=by_route[rid2];oend=_oend(rid2,o)
                  ys_=[(y_['valid_from'],y_['valid_to'] or 'ongoing') for y_ in _ystop.get(Y,()) if routes[y_['route_id']]['line']==B_] or [(y_['valid_from'],y_['valid_to'] or 'ongoing') for y_ in _ystop.get(Y,())]
                  base=_ivx(_ivx(_selivs(h),_selivs(o)),eiv_)
                  base=_ivx(_ivx(base,_alive(rid,h['seq'],True)),_alive(rid2,o['seq'],True))
                  if g_.get('from') or g_.get('to'):base=_ivx(base,[(g_.get('from'),g_.get('to') or 'ongoing')])
                  base=[x_ for x_ in _ivx(base,_ivu(ys_)) if not(x_[1] not in (None,'ongoing') and (lohi(x_[1])[1] or '9999')<=FLOOR)]
                  base=_minus(base,_done_y)
                  if not base:WARN['ext_hint_trace'].append((rid,X,Y,rid2,'기간 없음'));continue
                  Q_=[y_['node_id'] for y_ in L2];io_=L2.index(o)
                  if Y in Q_:st2_=1 if Q_.index(Y)>io_ else -1
                  else:
                      vy_=_vec(m,Y);sc_=[]
                      for st_ in (-1,1):
                          k_=io_+st_
                          if 0<=k_<len(L2) and vy_:
                              vv_=_vec(m,L2[k_]['node_id'])
                              if vv_:sc_.append((vv_[0]*vy_[0]+vv_[1]*vy_[1],st_))
                      st2_=max(sc_)[1] if sc_ and max(sc_)[0]>0 else None
                  if st2_ is None or (oend and st2_!=oend):WARN['ext_hint_trace'].append((rid,X,Y,rid2,'방면 없음'));continue
                  # 생성기가 이 끝 행에서 그 노선으로 낸 날(환승 포함)은 생성기 판정을 따른다. 방면 자료끼리는 같은 방면으로 이미 낸 날만 뺀다(같은 노선 양쪽 방면: 保原線 長岡分岐点 → 聖光学院前 쪽·長岡田町 쪽)
                  def _side(l_):
                      nx_=l_.get('next_stop_node')
                      return (1 if Q_.index(nx_)>io_ else -1) if nx_ in Q_ and Q_.index(nx_)!=io_ else None
                  have=[(l_['valid_from'],l_['valid_to']) for l_ in links if l_['route_id']==rid and l_['seq']==h['seq'] and l_['other_line_id']==B_ and (l_.get('flow_source')!='end_through' or (l_.get('other_route_id')==rid2 and _side(l_)==st2_))]
                  base=_minus(base,have)
                  if not base:WARN['ext_hint_trace'].append((rid,X,Y,rid2,'이미 이어짐'));continue
                  n1_=len(links);_done_y+=base;WARN['ext_hint_made'].append((rid,X,Y,rid2,base[:3]))
                  for pd0 in base:
                      for pd,(nx2,la2) in split_by_day(rid2,pd0,lambda d,st2_=st2_,o=o,rid2=rid2:walk(rid2,o['seq'],st2_,False,d,True)):
                          if not nx2 or (pd[1] not in (None,'ongoing') and (lohi(pd[1])[1] or '9999')<=FLOOR):continue
                          n0_=len(links);add_link(h,B_,rid2,'continue',None,m if m!=X else None,nx2,la2,None,'end_through',pd,o);_xt3+=len(links)-n0_
                      have2=[(l_['valid_from'],l_['valid_to']) for l_ in links if l_['route_id']==rid2 and l_['seq']==o['seq'] and l_['other_line_id']==A_ and l_.get('other_route_id') in (None,rid)]
                      for pd1 in _minus([pd0],have2):
                          for pd,(nx,la) in split_by_day(rid,pd1,lambda d,h=h,rid=rid,inw=inw:walk(rid,h['seq'],inw,False,d,True)):
                              if not nx or (pd[1] not in (None,'ongoing') and (lohi(pd[1])[1] or '9999')<=FLOOR):continue
                              n0_=len(links);add_link(o,A_,rid,'continue' if _oend(rid2,o,_rep_day(pd)) else 'branch',None,X if m!=X else None,nx,la,None,'end_through',pd,h);_xt3+=len(links)-n0_
                  if len(links)==n1_:WARN['ext_hint_trace'].append((rid,X,Y,rid2,'다음 역 없음',st2_,base[:2]))
WARN['ext_hint_unused'].extend(_xmiss)
for rid,L in sorted(by_route.items()):
    if rid in _HID_R or len(L)<2:continue
    A_=routes[rid]['line']
    for h,inw,eiv_ in _END.get(rid,()):
        X=h['node_id']
        hidden=X not in _pub_e
        js_=jx.get((A_,X),[])
        # 상대 노드: 같은 노드, 근거 표가 적은 다른 노드(여객 직통 근거가 있는 행만, 생성기와 같은 규칙)
        for m in [X]+sorted({j_['_other_at'] for j_ in js_ if j_.get('_other_at') and j_.get('verified') and j_['_other_at']!=X}):
            for o in _rows_at.get(m,()):
                rid2=o['route_id']
                if rid2==rid or rid2 in _HID_R:continue
                # 같은 노선의 두 계통이 같은 날 같은 자리에서 둘 다 끝나면 한 노선이 나뉜 것이라 서로 잇는다(키쿠치선 본선·구선 1995 전 쿠로이시).
                # 같은 노선 다른 계통과의 이음은 그 밖에는 생성기가 정한다
                same_=routes[rid2]['line']==A_
                # 여객 이력 계통(extra)은 같은 노선 다른 계통과 잇지 않는다(和歌山線 短絡線 1962–1972, 정한 규칙 4회차 kinki_3-004)
                if same_ and (m!=X or not _oend(rid2,o) or routes[rid].get('extra') or routes[rid2].get('extra')):continue
                B_=routes[rid2]['line']
                jj_=[j_ for j_ in js_ if j_['other']==B_ and (m==X or j_.get('_other_at')==m)] if not same_ else []
                jr_=[j_ for j_ in jx.get((B_,m),[]) if j_['other']==A_] if not same_ else []
                if not(hidden and m==X) and not jj_ and not jr_ and not same_:continue
                if _jnot_route(rid,X,B_,rid2) or _jnot_route(rid2,m,A_,rid):continue
                base=_ivx(_ivx(_selivs(h),_selivs(o)),eiv_)
                # 두 행이 함께 서는 날은 생성기가 이었으므로 뺀다. 같은 노선 계통끼리는 생성기가 한쪽만 잇기도 해서 빼지 않고 아래에서 없는 쪽만 낸다
                if not same_:base=_minus(base,_ivx(_stop_iv(h),_stop_iv(o)))
                base=_ivx(_ivx(base,_alive(rid,h['seq'],True)),_alive(rid2,o['seq'],True))
                base=[(f_,t_) for f_,t_ in base if _lo(f_)<_lo(t_,True) and not(t_ not in (None,'ongoing') and (lohi(t_)[1] or '9999')<=FLOOR)]
                if not base:continue
                L2=by_route[rid2];oend=_oend(rid2,o);base=_cut_end(rid2,o,base)
                if same_:base=[pd_ for pd_ in base if _oend(rid2,o,_rep_day(pd_))]
                if not base:continue
                # A→B
                # 생성기가 이 쌍을 어느 쪽에서든 이미 판정한 날(환승 포함: 같은 묶음 옆 노드로 낸 환승 江戸橋 옛 자리, 番町線 上之町 환승)은 생성기 판정을 따른다
                gx_={X,m}|set(_grpm.get(nodes[X].get('group')) or ())
                # 상대 쪽 판정은 이 끝 노드(같은 묶음)에 닿고 이 계통(또는 계통을 적지 않은)으로 가는 연결만 센다. 그 노선의 다른 계통·다른 노드로 가는 연결(秩父本線 御花畑 → 연락선 西武秩父 쪽 갈래)은 이 쌍의 판정이 아니다
                have=[(l_['valid_from'],l_['valid_to']) for l_ in links if (l_['route_id']==rid and l_['seq']==h['seq'] and l_['other_line_id']==B_ and (not same_ or l_.get('other_route_id')==rid2)) or (l_['route_id']==rid2 and l_['other_line_id']==A_ and _nat.get((rid2,l_['seq'])) in gx_ and l_.get('other_route_id') in ((rid,) if same_ else (None,rid)) and (l_.get('other_node') or X) in gx_)]
                # 같은 노선: 한쪽 이음만 있으면 없는 쪽만 낸다(아래 A→B·B→A가 저마다 이미 있는 날을 뺀다)
                ab_=_minus(list(base),[(l_['valid_from'],l_['valid_to']) for l_ in links if l_['route_id']==rid and l_['seq']==h['seq'] and l_.get('other_route_id')==rid2]) if same_ else None
                ba_=_minus(list(base),[(l_['valid_from'],l_['valid_to']) for l_ in links if l_['route_id']==rid2 and l_['seq']==o['seq'] and l_.get('other_route_id')==rid]) if same_ else None
                base=_minus(base,have) if not same_ else base
                for pd0 in (ab_ if same_ else base):
                    rd_=_rep_day(pd0);oe_=_oend(rid2,o,rd_)
                    if oe_:sts_=[oe_]
                    else:
                        jt_=next((j_ for j_ in jj_ if j_.get('_toward')),None)
                        if jt_:
                            pr_,nx_=neighbors(rid2,o['seq'],False,rd_,True)
                            sts_=[-1 if x_ is pr_ else 1 for x_ in _tw_pick(o,pr_,nx_,jt_)]
                        else:
                            w_=rdir(rid,h['seq'],inw,rd_)
                            sc_=[(tdeg(w_,rdir(rid2,o['seq'],st2_,rd_)),st2_) for st2_ in (-1,1)]
                            sc_=[(a_,st2_) for a_,st2_ in sc_ if a_ is not None and a_>=sharp_c(A_,B_)]
                            sts_=[max(sc_)[1]] if sc_ else []
                    for st2_ in sts_:
                        for pd,(nx2,la2) in split_by_day(rid2,pd0,lambda d,st2_=st2_,o=o,rid2=rid2:walk(rid2,o['seq'],st2_,False,d,True)):
                            if not nx2 or (pd[1] not in (None,'ongoing') and (lohi(pd[1])[1] or '9999')<=FLOOR):continue
                            n0_=len(links);add_link(h,B_,rid2,'continue',None,group_near_e(X,m),nx2,la2,None,'end_through',pd,o);_xt+=len(links)-n0_
                # B→A
                # B→A: 위에서 정한 날(생성기가 판정하지 않은 날)만. 그 사이 위 A→B로 낸 행은 같은 쌍의 짝이라 빼지 않는다
                for pd0 in (ba_ if same_ else base):
                    for pd,(nx,la) in split_by_day(rid,pd0,lambda d,h=h,rid=rid,inw=inw:walk(rid,h['seq'],inw,False,d,True)):
                        if not nx or (pd[1] not in (None,'ongoing') and (lohi(pd[1])[1] or '9999')<=FLOOR):continue
                        n0_=len(links);add_link(o,A_,rid,'continue' if _oend(rid2,o,_rep_day(pd)) else 'branch',None,group_near_e(m,X),nx,la,None,'end_through',pd,h);_xt+=len(links)-n0_
# 끝 노드 한 구간 너머의 여객 직통 근거: 계통 끝 노드 X를 지나는 다른 노선 계통에서 X 바로 옆 노드 m에, 이 노선(A)과 다른 노선(C)의 직통 근거 행(검증된 행)이 있으면
# 그 직통은 그 한 구간을 지나 m에서 C로 이어진 것이다(都電 30系統 向島線–本所吾妻橋–吾妻橋線: 吾妻橋線 끝은 吾妻橋一丁目, 本所吾妻橋까지는 業平線 선로).
# A 끝 행에서 C로(상대 노드 m), C의 m 행에서 A로(상대 노드 X) 잇는다. 방면은 근거 행(_toward)을 따른다. 그 한 구간의 노선(B) 자체로의 이어짐은 위에서 X에서 낸다
_xt2=0
for rid,L in sorted(by_route.items()):
    if rid in _HID_R or len(L)<2:continue
    A_=routes[rid]['line'];own_n={y_['node_id'] for r_ in _RBL.get(A_,()) for y_ in by_route.get(r_,())}
    for h,inw,eiv_ in _END.get(rid,()):
        X=h['node_id']
        nbr_={}
        for p_ in _rows_at.get(X,()):
            if routes[p_['route_id']]['line']==A_ or p_['route_id'] in _HID_R:continue
            P_=by_route[p_['route_id']];i_=P_.index(p_)
            for k_ in (i_-1,i_+1):
                if 0<=k_<len(P_) and P_[k_]['node_id'] not in own_n:nbr_.setdefault(P_[k_]['node_id'],set()).add(routes[p_['route_id']]['line'])
        for m,bl_ in sorted(nbr_.items()):
            for j in [j_ for j_ in jx.get((A_,m),[]) if j_.get('verified') and j_['other'] not in bl_ and j_['other']!=A_]:
                C_=j['other']
                for o in _rows_at.get(m,()):
                    rid2=o['route_id']
                    if routes[rid2]['line']!=C_ or rid2 in _HID_R or (j.get('other_route') and rid2!=j['other_route']):continue
                    # 끝 노드가 그 계통에서 서는 날은 그 계통 열차가 역에서 끝나는 것이라 너머 직통을 내지 않는다(확장 행이 메우던 것은 서지 않는 끝 노드 기간뿐)
                    base=_minus(_ivx(_ivx(_selivs(h),_selivs(o)),eiv_),_stop_iv(h))
                    base=_ivx(_ivx(base,_alive(rid,h['seq'],True)),_alive(rid2,o['seq'],True))
                    base=[q_ for b_ in base for q_ in [_clip(b_,j)] if q_]
                    if not base:continue
                    L2=by_route[rid2];oend=_oend(rid2,o);base=_cut_end(rid2,o,base)
                    have=[(l_['valid_from'],l_['valid_to']) for l_ in links if l_['route_id']==rid and l_['seq']==h['seq'] and l_['other_line_id']==C_]
                    for pd0 in _minus(base,have):
                        rd_=_rep_day(pd0);oe_=_oend(rid2,o,rd_)
                        if oe_:sts_=[oe_]
                        elif j.get('_toward'):
                            pr_,nx_=neighbors(rid2,o['seq'],False,rd_,True)
                            sts_=[-1 if x_ is pr_ else 1 for x_ in _tw_pick(o,pr_,nx_,j)]
                        else:sts_=[]
                        for st2_ in sts_:
                            for pd,(nx2,la2) in split_by_day(rid2,pd0,lambda d,st2_=st2_,o=o,rid2=rid2:walk(rid2,o['seq'],st2_,False,d,True)):
                                if not nx2 or (pd[1] not in (None,'ongoing') and (lohi(pd[1])[1] or '9999')<=FLOOR):continue
                                n0_=len(links);add_link(h,C_,rid2,'continue',None,m,nx2,la2,None,'end_through',pd,o);_xt2+=len(links)-n0_
                    have=[(l_['valid_from'],l_['valid_to']) for l_ in links if l_['route_id']==rid2 and l_['seq']==o['seq'] and l_['other_line_id']==A_]
                    for pd0 in _minus(base,have):
                        for pd,(nx,la) in split_by_day(rid,pd0,lambda d,h=h,rid=rid,inw=inw:walk(rid,h['seq'],inw,False,d,True)):
                            if not nx or (pd[1] not in (None,'ongoing') and (lohi(pd[1])[1] or '9999')<=FLOOR):continue
                            n0_=len(links);add_link(o,A_,rid,'continue' if _oend(rid2,o,_rep_day(pd)) else 'branch',None,X,nx,la,None,'end_through',pd,h);_xt2+=len(links)-n0_
print('끝 이어짐 방면 자료',_xt3,'못 씀',len(_xmiss),'일반 규칙',_xt,'한 구간 너머 직통 근거',_xt2)
# 끝 이어짐이 대신한 옛 연결: 계통 P의 끝 노드·분기점 행에서 상대 계통 Q로 끝 이어짐(또는 반대쪽 갈림)이 있으면, P의 다른 행에서 같은 Q로 내던
# 갈림·이어짐(생성기가 상대 노드로 낸 연결)은 그 날들에서 뺀다. 같은 갈래가 두 번 그려지지 않게 (秩父本線 御花畑 → 연락선 갈래 계통: 分岐点（御花畑）에서 갈라짐)
_etq=collections.defaultdict(list)
for l_ in links:
    if l_.get('flow_source')=='end_through' and l_.get('other_route_id'):_etq[(l_['route_id'],l_['other_route_id'])].append((l_['seq'],l_['valid_from'],l_['valid_to']))
_rown={r_:{y_['node_id'] for y_ in L_} for r_,L_ in by_route.items()}
def _q_of(l_):
    if l_.get('other_route_id'):return l_['other_route_id']
    c_=[q_ for q_ in _RBL.get(l_['other_line_id'],()) if (l_.get('next_stop_node') in _rown.get(q_,()) or l_.get('other_node') in _rown.get(q_,()))]
    return c_[0] if len(c_)==1 else None
_out=[];_sup=0
for l_ in links:
    if l_.get('flow_source')=='end_through' or l_['kind'] not in ('branch','continue'):_out.append(l_);continue
    q_=_q_of(l_)
    # 그 행 노드에서 두 계통이 실제로 만나면(大阪環状線·関西本線 天王寺와 新今宮) 따로 있는 연결이라 두고, 상대 계통이 그 노드에 없을 때만 뺀다
    if not q_ or _nat.get((l_['route_id'],l_['seq'])) in _rown.get(q_,()):_out.append(l_);continue
    cov_=[(f_,t_) for sq_,f_,t_ in _etq.get((l_['route_id'],q_),()) if sq_!=l_['seq']]
    if not cov_:_out.append(l_);continue
    rest_=_minus([(l_['valid_from'],l_['valid_to'])],cov_)
    if rest_!=[(l_['valid_from'],l_['valid_to'])]:_sup+=1;WARN['link_superseded_by_end_through'].append((l_['route_id'],l_['seq'],q_,l_['valid_from'],l_['valid_to']))
    for f_,t_ in rest_:_out.append(dict(l_,valid_from=f_,valid_to=t_))
links=_out
print('끝 이어짐이 대신한 옛 연결',_sup)
# ② 1950-01-01 전에 끝난 연결 행은 기록할 날이 없다 (3회차 hokkaido_1-015)
_pre=[l_ for l_ in links if l_['valid_to'] not in (None,'ongoing') and (lohi(l_['valid_to'])[1] or '9999')<=FLOOR]
links=[l_ for l_ in links if not(l_['valid_to'] not in (None,'ongoing') and (lohi(l_['valid_to'])[1] or '9999')<=FLOOR)]
print('연결 행 영업 기간 맞춤',_cut,'1950 전에 끝나 뺀 행',len(_pre),'행 수',_nl0,'->',len(links))
# ②' 시작을 범위로만 아는 연결 행이 그 범위 안에서 끝나면 있었다고 말할 수 없다(石巻 仙石線–石巻線 연결선 개통 [1990-07-21..2016-08-06], 3회차 tohoku_1-019). 같은 기간 환승 행은 그대로 둔다
# 근거 행의 시작이 범위이면 연결 행 시작이 정차 기간으로 잘려 날짜가 되었어도 같다(石巻 石巻線→仙石線 2000–2011: 仙石線 쪽만 빠져 비대칭이던 것, 9회차 L / X K122)
_JVR={}
for j_ in junctions:
    v_=(j_.get('valid') or [None])[0]
    if j_.get('at') and isinstance(v_,str) and v_.startswith('[') and not v_.startswith('[..'):_JVR[(j_['line'],j_['other'],j_['at'])]=v_
def _vstart(l_):
    if str(l_['valid_from']).startswith('[') and not str(l_['valid_from']).startswith('[..'):return l_['valid_from']
    return _JVR.get((routes[l_['route_id']]['line'],l_['other_line_id'],(l_.get('_s') or {}).get('node_id')))
_unc=[l_ for l_ in links if l_['kind'] in ('branch','continue') and _vstart(l_) and l_['valid_to'] not in (None,'ongoing') and (lohi(l_['valid_to'])[0] or '9999')<=(lohi(_vstart(l_))[1] or '0000')]
links=[l_ for l_ in links if not any(l_ is u_ for u_ in _unc)]
WARN['link_uncertain_start'].extend((l_['route_id'],l_['seq'],l_['other_line_id'],l_['valid_from'],l_['valid_to']) for l_ in _unc)
# 근거 행 시작이 범위인데 연결 행 시작이 정차·영업으로 잘려 그 범위 안의 날짜가 되었으면, 그 날부터 범위 상한 사이 어느 날 시작했다고만 말할 수 있다.
# 양쪽 계통의 잘린 날이 달라도(石巻 仙石線 2015-03-21·石巻線 2015-05-30) 확실한 시작은 범위 상한으로 같다 (9회차 L / X K122·S01)
for l_ in links:
    if l_['kind'] not in ('branch','continue'):continue
    v_=_vstart(l_);f_=l_['valid_from']
    if not v_ or v_==f_ or not isinstance(f_,str) or f_.startswith('['):continue
    lo_,hi_=lohi(v_)
    # 잘린 날이 범위 하한과 같아도(宮福線 福知山 1988-07-16 = 개업일 = 근거 범위 앞) 그 날 시작했다고 말할 수 없다. 하한 포함 (10회차 G2, audit4 kinki_2-006)
    if lo_ and hi_ and lo_<=f_<hi_:l_['valid_from']=f'[{f_}..{hi_}]';WARN['link_range_start'].append((l_['route_id'],l_['seq'],l_['other_line_id'],l_['valid_from']))
print('시작 범위 안에서 끝나 뺀 연결 행',len(_unc))
# ③ 끝 역은 노선 줄기 끝이다: 상대 계통의 그날 끝(또는 끊긴 곳)에서 같은 노선의 다른 계통(옛 경로·갈래 계통)이 곧게 이어지면 그 계통을 따라 끝까지 간다
#   (根室本線 野花南–島ノ下·落合–新得 옛 경로, 室蘭本線, 函館本線 納内–伊納, 東北本線 野内(旧)·品井沼, 石勝線 1981 전 夕張 갈래, 3회차 hokkaido_1-002~005·tohoku_1-020)
_npl=collections.defaultdict(set)
for _r,_es in route_edges.items():
    if not routes[_r].get('extra'):_npl[routes[_r]['line']]|={frozenset((e_['a'],e_['b'])) for e_ in _es}
_DUPX={_r for _r,_es in route_edges.items() if routes[_r].get('extra') and _es and all(frozenset((e_['a'],e_['b'])) in _npl[routes[_r]['line']] for e_ in _es)}
print('같은 두 역 사이 칸이 따로 있는 여객 이력 계통',sorted(_DUPX))
def _trunk(q,t,prev,day,seen,depth=0):
    """계통 q 위 끝 t(앞 노드 prev에서 들어옴)에서 같은 노선 다른 계통으로 곧게 이어 간 마지막 정차역. 이어지는 계통이 없으면 None"""
    if depth>8:return None
    ln_=routes[q]['line'];op_=open_on(ln_,day);v0=gd(t,prev,ln_) if prev else None
    for q2 in sorted(_RBL.get(ln_,())):
        # 같은 계통으로 다시 돌아가도 된다(본선→옛 경로→본선). 같은 (계통, 역)으로 두 번 들어가지 않는다
        if (q2,t) in seen or q2==q:continue
        # 같은 두 역 사이에 같은 노선 다른 계통 칸이 따로 있는 여객 이력 계통(extra, 和歌山線 短絡線 1962–1972)은 줄기가 아니다 (11회차 S3)
        if q2 in _DUPX:continue
        for x_ in by_route.get(q2,()):
            if x_['node_id']!=t or x_.get('is_extension'):continue
            for st_ in (-1,1):
                h_,eid_=hop(q2,x_['seq'],st_,day)
                if not h_ or h_==prev or frozenset((t,h_)) not in op_:continue
                a_=tdeg(v0,gde(eid_,t))
                if a_ is not None and a_<75:continue
                nx_,last_=walk(q2,x_['seq'],st_,False,day)
                if not last_ or last_==t:continue
                li_=next((k for k,y in enumerate(by_route[q2]) if y['node_id']==last_ and y['is_stop'] and on_day(y,day)),None)
                if li_ is None:return last_
                p2_=hop(q2,by_route[q2][li_]['seq'],-st_,day)[0]
                return _trunk(q2,last_,p2_,day,seen|{(q2,t)},depth+1) or last_
    return None
def _split_days(ds,pd,fn):
    out=[]
    for i,d in enumerate(ds):
        f_=pd[0] if i==0 else d;u_=pd[1] if i==len(ds)-1 else ds[i+1]
        if i==len(ds)-1:rd=_rep_day((f_,u_))
        elif i==0:
            rd=max(lohi(pd[0])[1] or d if pd[0] else d,FLOOR)
            if rd>=ds[1]:rd=d
        else:rd=d
        v=fn(rd)
        if out and out[-1][1]==v:out[-1]=((out[-1][0][0],u_),v)
        else:out.append(((f_,u_),v))
    return out
_ntr=0;_out=[]
for l_ in links:
    q_=(l_.get('_o') or (None,))[0];t_=l_.get('terminal_node')
    if not q_ or not t_:_out.append(l_);continue
    oi_=_SIDX[l_['_o']];L_=by_route[q_]
    ti_=[k for k,y in enumerate(L_) if y['node_id']==t_]
    if not ti_ or ti_[0]==oi_:_out.append(l_);continue
    st_=1 if ti_[0]>oi_ else -1;tseq_=L_[ti_[0]]['seq']
    # 끝 역은 그 방향 그날의 계통 끝이다. 마지막 정차역 너머에 승하차 불가 끝 행이 있으면 계통은 거기까지 간다(梅田貨物線: 新大阪 › 福島, 사용자 지적 2026-11-21)
    ends_=[(y,iv) for y,inw,iv in _END.get(q_,()) if inw==-st_ and (y['seq']-tseq_)*st_>0]
    # 화물 지선 위 여객 이력 계통 가운데 다른 회사·다른 계통 열차가 그 계통 끝에서 멈춘 것(계통 행 stops_at_end: 江若 乗入 膳所–浜大津, 和歌山線 短絡線)은
    # 줄기 끝으로 늘이지 않는다 (11회차 메인). extra 계통 전부가 아니다: 品鶴線·武蔵野線·藤城線·押上 伊勢崎線처럼 열차가 그대로 지나가는 extra 계통은 줄기를 따라간다 (11회차 F1)
    trunk_=not routes[q_].get('stops_at_end') and len(_RBL.get(routes[q_]['line'],()))>=2
    if not trunk_ and not ends_:_out.append(l_);continue
    pd_=(l_['valid_from'],l_['valid_to'])
    p0_,p1_=_lo(pd_[0]),_lo(pd_[1],True)
    # 기록 하한(1950) 전 경계로는 나누지 않는다
    ds_={p0_}|{v_ for _,iv in ends_ for a_,b_ in iv for v_ in (_lo(a_),_lo(b_,True)) if p0_<v_<p1_ and v_>FLOOR}
    if trunk_:
        for q2 in _RBL[routes[q_]['line']]:ds_|=set(_change_days(q2,pd_))
    def _fn(d,q_=q_,t_=t_,tseq_=tseq_,st_=st_,ends_=ends_,trunk_=trunk_):
        t0_,s0_=t_,tseq_
        c_=[y for y,iv in ends_ if any(_lo(a_)<=d<_lo(b_,True) for a_,b_ in iv)]
        if c_:
            y_=min(c_,key=lambda y:abs(y['seq']-tseq_));t0_,s0_=y_['node_id'],y_['seq']
        if not trunk_:return t0_
        return _trunk(q_,t0_,hop(q_,s0_,-st_,d)[0],d,set()) or t0_
    sp_=_split_days(sorted(ds_),pd_,_fn)
    if len(sp_)==1 and sp_[0][1]==t_:_out.append(l_);continue
    for (f_,u_),tt_ in sp_:
        if tt_!=t_:_ntr+=1
        _out.append(dict(l_,valid_from=f_,valid_to=u_,terminal_node=tt_))
links=_out
print('끝 역을 노선 줄기 끝으로 이은 연결 행',_ntr)
# ④ 한 계통에서 같은 상대(노선·노드)로의 환승이 여러 역에 붙으면, 근거가 더 센 역(같은 노드 > 같은 group > 문서·같은 이름·역앞·150 m > 손 표 간접 환승)이
#   상대에 100 m 넘게 더 가까울 때 약한 역의 환승을 그 역이 잇는 날만큼 뺀다. 근거가 같은 등급이면 둘 다 남긴다(多摩モノレール 立川北·立川南 → JR 立川,
#   東京モノレール 羽田空港 第1·第2 → 京急, 사업자 안내가 두 역 모두에 적음). 손 환승 쌍(hub_pairs.json)으로 명시한 환승은 남긴다
#   (千日前線 玉川: 阪神本線·北大阪線·国道線 野田 환승은 바로 옆 野田阪神에 있고 玉川은 JR 野田만, 사업자 안내, 9회차 L-8)
def _ltgt(l_):return l_.get('other_node') or l_['_s']['node_id']
_lgrp=collections.defaultdict(list)
for l_ in links:
    if l_.get('_s') is None or l_.get('at_edge'):continue
    _lgrp[(l_['route_id'],l_['other_line_id'],_ltgt(l_))].append(l_)
def _lkey(l_):
    n_=l_['_s']['node_id'];t_=_ltgt(l_)
    return (_brank(n_,t_),round(hav_km(n_,t_),3))
_ndup=0;_ndrop=0;_out=[]
for l_ in links:
    if l_['kind']!='transfer' or l_.get('_s') is None or l_.get('at_edge'):_out.append(l_);continue
    n_=l_['_s']['node_id'];t_=_ltgt(l_);k_=_lkey(l_)
    if frozenset((n_,t_)) in HUBX_ID:_out.append(l_);continue
    bt_=[u_ for u_ in _lgrp[(l_['route_id'],l_['other_line_id'],t_)] if u_['_s']['node_id']!=n_ and _lkey(u_)[0]<k_[0] and _lkey(u_)[1]+.1<k_[1]]
    pcs_=[(l_['valid_from'],l_['valid_to'])]
    for u_ in bt_:
        g_,h_=u_['valid_from'],u_['valid_to'];nxt_=[]
        for f_,w_ in pcs_:
            if _lo(h_,True)<=_lo(f_) or _lo(g_)>=_lo(w_,True):nxt_.append((f_,w_));continue
            if _lo(f_)<_lo(g_):nxt_.append((f_,g_))
            if h_ not in (None,'ongoing') and _lo(h_)<_lo(w_,True):nxt_.append((h_,w_))
        pcs_=nxt_
    if pcs_==[(l_['valid_from'],l_['valid_to'])]:_out.append(l_);continue
    _ndup+=1
    if not pcs_:_ndrop+=1;WARN['transfer_dup_target'].append((l_['route_id'],n_,l_['other_line_id'],t_,l_['valid_from'],l_['valid_to']))
    for f_,w_ in pcs_:
        if _lo(f_)<_lo(w_,True):_out.append(dict(l_,valid_from=f_,valid_to=w_))
links=_out
print('같은 상대 환승이 여러 역에 붙어 약한 역에서 뺀 행',_ndup,'(통째로 뺌',_ndrop,')')
for i_,x_ in enumerate(_JNR):
    # 보정 행(source_patch)으로 더한 계통(和歌山線 短絡線)을 가리키는 행은 생성 중 컴파일에서 쓰이지 않는다 (11회차 S3)
    if i_ not in _JNR_USED and not(_nopatch and (x_['route'] not in routes or (x_.get('other_route') and x_['other_route'] not in routes))):err('junction_not_route_unused',x_)
# 숨은 노드에서 갈라지는 노선은 부모 계통의 위쪽 역에 at_edge 행으로 둔다.
# 정류장이 없어진 뒤의 분기점도 숨은 노드다: 부모 계통의 그 역과 갈래 계통의 끝 역이 둘 다 서지 않는 기간에는 at_edge 행을 둔다
# (都電 業平線 吾妻橋一丁目 1960 폐지 뒤에도 吾妻橋線은 1972-11-12까지 그 분기점에서 갈라짐, 3회차 kanto_1-003, 9회차 L)
def _ivs_minus_l(A,B):
    """기간 목록 A에서 B의 기간들을 뺀 토막"""
    out=list(A)
    for g_,h_ in B:
        nx_=[]
        for f_,u_ in out:
            if _lo(h_,True)<=_lo(f_) or _lo(g_)>=_lo(u_,True):nx_.append((f_,u_));continue
            if _lo(f_)<_lo(g_):nx_.append((f_,g_))
            if h_ not in (None,'ongoing') and _lo(h_)<_lo(u_,True):nx_.append((h_,u_))
        out=nx_
    return [x for x in out if _lo(x[0])<_lo(x[1],True)]
def _hid_iv(y):
    """정차 행 y가 서지 않는 기간들(정차 기간 앞·뒤와 정차 공백). 정차 행이 아니면 내내"""
    if not y['is_stop']:return [(None,'ongoing')]
    out=[]
    if y['valid_from'] and _lo(y['valid_from'])>'0000':out.append((None,y['valid_from']))
    if y['valid_to'] not in (None,'ongoing'):out.append((y['valid_to'],'ongoing'))
    for g_,h_ in _GAPS.get(id(y),()):out.append((g_ if g_!='0000' else None,h_ if h_!='9999-12-31' else 'ongoing'))
    return out
_nae=0
for rid,L in by_route.items():
    for i,x in enumerate(L):
        if i==0 or i==len(L)-1:continue
        hx0_=_hid_iv(x)
        if not hx0_:continue
        for rid2,L2 in by_route.items():
            if rid2==rid or routes[rid2]['line']==routes[rid]['line']:continue
            for e_,f_ in ((L2[0],1),(L2[-1],-1)):
                if e_['node_id']!=x['node_id']:continue
                if x['is_stop'] or e_['is_stop']:
                    # 정차 행이던 분기점: 두 행이 함께 서지 않는 기간에만 (1950 뒤)
                    hiv_=[iv for iv in _ivx(hx0_,_hid_iv(e_)) if _lo(iv[1],True)>FLOOR]
                    if not hiv_:continue
                    for hf_,ht_ in hiv_:
                        def _act(y,hf_=hf_,ht_=ht_):return y['is_stop'] and _lo(y['valid_from'])<_lo(ht_,True) and _lo(hf_)<_lo(y['valid_to'],True) and y is not x and y is not e_
                        up=next((y for y in reversed(L[:i]) if _act(y)),None);dn=next((y for y in L[i+1:] if _act(y)),None)
                        v=[y for y in (L2 if f_==1 else L2[::-1]) if _act(y)]
                        if not up or not dn or not v:continue
                        pd0_=period(up,v[0])
                        if not pd0_:continue
                        # 그 기간에 분기점에서 두 계통 칸이 실제로 영업했어야 한다(새 역 자리의 선로가 생기기 전·옛 역 자리 선로가 없어진 뒤는 분기가 없다)
                        hx_=x['node_id']
                        def _eiv(rr_,hx_=hx_):
                            ln_=routes[rr_]['line']
                            return _ivu([iv for e in route_edges[rr_] if hx_ in (e['a'],e['b']) for iv in _ivx(_LOPEN.get(e['id'],[]),_ivu([(a_['valid_from'],a_['valid_to']) for a_ in _ra[(ln_,e['id'])]]))])
                        ea_=_eiv(rid);eb_=_eiv(rid2)
                        if not ea_ or not eb_:continue
                        for pd_ in _ivx(_ivx(_ivx([pd0_],[(hf_,ht_)]),ea_),eb_):
                            hx_=x['node_id'];ya_={other(e,hx_) for e in route_edges[rid] if hx_ in (e['a'],e['b'])};yb_={other(e,hx_) for e in route_edges[rid2] if hx_ in (e['a'],e['b'])}
                            # 부모 계통이 위·아래 정차역에서 이미 그 노선으로 잇는 날은 빼고 둔다(天王寺 関西本線→大阪環状線 1961–1964: 天王寺 분기가 이미 있음)
                            # 분기점 행에서 이미 잇는 날(끝 이어짐: 지나가는 계통 행에 끝 노드가 보이는 기간)도 뺀다
                            _have=[(l_['valid_from'],l_['valid_to']) for l_ in links if l_['route_id']==rid and l_['seq'] in (up['seq'],dn['seq'],x['seq']) and l_['other_line_id']==routes[rid2]['line'] and l_['kind'] in ('branch','continue')]
                            for pd in [q_ for p_ in track_ok(routes[rid]['line'],routes[rid2]['line'],hx_,pd_,ya_,hx_,yb_) for q_ in _ivs_minus_l([p_],_have)]:
                                if pd[1] not in (None,'ongoing') and (lohi(pd[1])[1] or '9999')<=FLOOR:continue
                                _nae+=1;WARN['at_edge_closed_junction'].append((rid,x['node_id'],rid2,pd[0],pd[1]))
                                links.append(dict(route_id=rid,seq=up['seq'],other_line_id=routes[rid2]['line'],other_route_id=rid2,kind='branch',side=None,at_edge=1,other_node=None,next_stop_node=v[0]['node_id'],terminal_node=v[-1]['node_id'],flow=None,flow_source=None,valid_from=pd[0],valid_to=pd[1]))
                    continue
                up=next((y for y in reversed(L[:i]) if y['is_stop']),None);dn=next((y for y in L[i+1:] if y['is_stop']),None)
                if not up or not dn:continue
                v=[y for y in (L2 if f_==1 else L2[::-1]) if y['is_stop']]
                if not v:continue
                pd=period(up,v[0])
                if not pd:continue
                # 숨은 분기점에서도 그날 두 선로의 궤간·방식이 맞아야 잇는다(近鉄名古屋線 諏訪 1067 ↔ 湯の山線 762, 3회차 W1a K58)
                hx_=x['node_id'];ya_={other(e,hx_) for e in route_edges[rid] if hx_ in (e['a'],e['b'])};yb_={other(e,hx_) for e in route_edges[rid2] if hx_ in (e['a'],e['b'])}
                _have2=[(l_['valid_from'],l_['valid_to']) for l_ in links if l_['route_id']==rid and l_['seq'] in (up['seq'],dn['seq'],x['seq']) and l_['other_line_id']==routes[rid2]['line'] and l_['kind'] in ('branch','continue')]
                for pd in [q_ for p_ in track_ok(routes[rid]['line'],routes[rid2]['line'],hx_,pd,ya_,hx_,yb_) for q_ in _ivs_minus_l([p_],_have2)]:
                    if pd[1] not in (None,'ongoing') and (lohi(pd[1])[1] or '9999')<=FLOOR:continue
                    links.append(dict(route_id=rid,seq=up['seq'],other_line_id=routes[rid2]['line'],other_route_id=rid2,kind='branch',side=None,at_edge=1,other_node=None,next_stop_node=v[0]['node_id'],terminal_node=v[-1]['node_id'],flow=None,flow_source=None,valid_from=pd[0],valid_to=pd[1]))
print('정류장이 없어진 분기점의 at_edge 분기',_nae)

# 검사
for x,e in edges.items():
    if not any(a['edge_id']==x for a in attr):err('edge_no_attr',x)
sim=collections.defaultdict(list)
for a in attr:sim[(a['line_id'],a['edge_id'])].append(a)
for k,v in sim.items():
    v=sorted(v,key=lambda a:lohi(a['valid_from'])[0] or '0000')
    for p,q in zip(v,v[1:]):
        if (lohi(p['valid_to'])[0] or '9999')>(lohi(q['valid_from'])[0] or '0000'):err('overlap_attr',k)
for n in nodes:
    if not adj[n]:err('node_unused',n)
pub=set()
for s in stops:
    if s['is_stop']:pub.add(s['node_id'])
sname={x['id'] for x in names if x['entity_type']=='node' and x['lang']=='ko' and not x.get('line')}
# 읽기 근거가 끝내 없는 역은 뒤에서 일본어 표기를 그대로 한국어·영어로 쓴다 (사용자 결정 2026-11-08, redesign §4-6). 일본어 이름도 없을 때만 오류다
jname={x['id'] for x in names if x['entity_type']=='node' and x['lang']=='ja' and not x.get('line') and not x.get('valid_from') and not x.get('valid_to')}
for n in pub:
    if n not in sname and n not in jname:err('node_no_ko',n)
lname={x['id'] for x in names if x['entity_type']=='line' and x['lang']=='ko'}
# 노선도 읽기 근거가 없으면 일본어 표기를 그대로 한국어·영어로 쓴다 (redesign §4-6, 琴参 琴平線 등)
for l in lines:
    if l in lname:continue
    ja_=next((x for x in names if x['entity_type']=='line' and x['id']==l and x['lang']=='ja' and not x.get('valid_from') and not x.get('valid_to')),None)
    if not ja_:err('line_no_ko',l);continue
    have_en=any(x['entity_type']=='line' and x['id']==l and x['lang']=='en' for x in names)
    for lang_ in ('ko',)+(() if have_en else ('en',)):names.append(dict(entity_type='line',id=l,lang=lang_,text=ja_['text'],source='ja_as_is'))
kana=re.compile('[぀-ヿ一-鿿]')
# 읽기 근거가 없는 분기점 이름은 고유한 부분만 한자 그대로 두고 종류만 옮긴다(宮古 분기점, 사용자 결정 2026-11-19). 사람이 정한 노드 한국어 이름(hand)의
# 한자 토막과, 그 이름으로 만든 계통 이름의 같은 토막은 예외다
_KANJI_OK={t_ for x in names if x['entity_type']=='node' and x['lang']=='ko' and x.get('source')=='hand' for t_ in re.findall('[一-鿿]+',x['text'])}
for x in names:
    # 일본어 표기 그대로(ja_as_is)는 읽기 근거가 없는 마지막 수단이라 예외다 (명세 결정 6)
    if x['lang']=='ko' and x.get('source')!='ja_as_is' and kana.search(x['text']) and not (not re.search('[぀-ヿ]',x['text']) and set(re.findall('[一-鿿]+',x['text']))<=_KANJI_OK):err('ko_has_japanese',x['text'])

# 쓰기
os.makedirs(BUILD,exist_ok=True)
# 노드가 정차역이 되기 전에 끝난 옛 이름은 동명 역 문서에서 온 것이다. 화면에 나올 날도 없다
first_stop={}
for s in stops:
    if s['is_stop']:
        lo=lohi(s['valid_from'])[0] or '0000-00-00'
        first_stop[s['node_id']]=min(first_stop.get(s['node_id'],lo),lo)
# 계통 끝 노드는 정차역이 되기 전에도 승하차 불가 끝 노드로 보이므로 그때 이름이 필요하다 (北鹿島 ~1994 → 鹿島サッカースタジアム, 佃信号場 1929–1950, 5번 결정)
# 다만 그 옛 이름 기간에 계통 끝으로 지나가던 때(그 계통 끝 행이 있던 때)가 있어야 한다. 아니면 동명 역 문서에서 온 이름이다(多摩湖 「狭山公園前」)
_endfrom={}
for s in stops:
    r_=routes.get(s['route_id'])
    if r_ and id(s) in _ENDROW:
        # 끝 노드로 고를 수 있는 기간의 시작(정차 전 늘린 기간 포함)
        lo=lohi(_hull(s)[0])[0] or '0000-00-00'
        _endfrom[s['node_id']]=min(_endfrom.get(s['node_id'],lo),lo)
names=[x for x in names if not(x['entity_type']=='node' and x.get('valid_to') and x['id'] in first_stop and (lohi(x['valid_to'])[1] or '9999')<=first_stop[x['id']] and not (x['id'] in _endfrom and _endfrom[x['id']]<(lohi(x['valid_to'])[0] or '0000')))]
mp=os.path.join(BUILD,'master.sqlite');np_=os.path.join(BUILD,'names.sqlite')
for p in (mp,np_):
    if os.path.exists(p):os.remove(p)
db=sqlite3.connect(mp)
# 날짜 원칙 (docs/redesign.md §2.1): 있었던 기간을 뜻하는 칸은 NULL이 아니고, 모르면 근거 범위 [A..B]로 쓴다.
# NULL이 뜻을 갖는 칸(마지막 운행일·법적 폐지일 없음, 날짜 없는 기본 이름, 열람 전용 개업일, 운행 계통 시작)은 검사에서 뺀다
_DATECOL=re.compile(r'^(valid_from|valid_to|last_service|legal_abolition|gap_from|gap_to|abolished|opened|closed_from)$')
_DATE_REQ={('route_stop','valid_from'),('route_stop','valid_to'),('edge_life','valid_from'),('edge_life','valid_to'),('edge_attr','valid_from'),('edge_attr','valid_to'),
    ('route_link','valid_from'),('route_link','valid_to'),('route_link_carryover','valid_from'),('route_link_carryover','valid_to'),('route_stop_carryover','valid_from'),('route_stop_carryover','valid_to'),
    ('junction','valid_from'),('junction','valid_to'),('bus_section','valid_from'),('bus_section','valid_to'),('route_stop_gap','gap_from'),('route_stop_gap','gap_to'),
    ('denominator_unit','valid_from'),('denominator_unit','valid_to'),('closed_section','abolished'),('map_marker','abolished'),('service','valid_to'),('service_edition','valid_to'),('stop_mark','valid_from'),('stop_mark','valid_to')}
def check_dates(name,cols,rows):
    names_=[c.split()[0] for c in cols]
    for i_,c_ in enumerate(names_):
        # route.closed는 참·거짓 칸이다. 열람 전용 표의 closed만 날짜 칸으로 본다
        if not (_DATECOL.match(c_) or (c_=='closed' and name.startswith('archive_'))):continue
        lo_i=names_.index(c_+'_lo') if c_+'_lo' in names_ else None
        hi_i=names_.index(c_+'_hi') if c_+'_hi' in names_ else None
        for r_ in rows:
            v_=r_[i_]
            if v_ is None:
                if (name,c_) in _DATE_REQ:err('date_null',(name,c_,r_[:3]))
                continue
            if str(v_).startswith('XXXX') or v_=='[..]':err('date_bad',(name,c_,v_,'해 모름은 근거 범위로 쓴다'));continue
            try:lo_,hi_=lohi(v_)
            except ValueError as e_:err('date_bad',(name,c_,v_,str(e_)));continue
            if lo_i is not None and r_[lo_i]!=lo_:err('date_lohi',(name,c_,v_,r_[lo_i],lo_,r_[:2]))
            if hi_i is not None and r_[hi_i]!=hi_:err('date_lohi',(name,c_,v_,r_[hi_i],hi_,r_[:2]))
def t(name,cols,rows):
    rows=list(rows)
    check_dates(name,cols,rows)
    db.execute(f'create table {name} ({",".join(cols)})')
    db.executemany(f'insert into {name} values ({",".join("?"*len(cols))})',rows)
def per(name,e):
    return (e,)+lohi(e)
t('operator',['id primary key','category'],[(o['id'],o.get('category')) for o in ops.values()])
t('line',['id primary key','type','rule_class'],[(l['id'],l.get('type'),l.get('rule_class')) for l in lines.values()])
# 숨은 화물선에만 닿는 노드의 묶음은 번호를 맨 뒤에 둔다. 묶음 번호(n)는 앱이 정수 열쇠로 쓰므로 화물역을 더해도 다른 묶음 번호가 밀리지 않게 한다 (9회차 F)
_ecls=collections.defaultdict(set)
for a_ in attr:_ecls[a_['edge_id']].add(a_['denominator_class'])
_hidg={n_.get('group') for k_,n_ in nodes.items() if adj.get(k_) and all(_ecls.get(e_['id'])=={'hidden'} for e_ in adj[k_])}
_hidg-={n_.get('group') for k_,n_ in nodes.items() if not (adj.get(k_) and all(_ecls.get(e_['id'])=={'hidden'} for e_ in adj[k_]))}
_gl=[x for x in groups if x['id'] in {n['group'] for n in nodes.values() if n.get('group')}]
t('station_group',['id primary key','n'],[(g['id'],i+1) for i,g in enumerate([x for x in _gl if x['id'] not in _hidg]+[x for x in _gl if x['id'] in _hidg])])
t('node',['id primary key','kind','group_id','pref','export_name'],[(n['id'],n['kind'],n.get('group'),n.get('pref'),n.get('export_name')) for n in nodes.values()])
t('hub',['id primary key','source','verified'],[(h['id'],json.dumps(h.get('source'),ensure_ascii=False),int(bool(h.get('verified')))) for h in hubs])
t('hub_member',['hub_id','node_id'],[(h['id'],n) for h in hubs for n in h['nodes']])
_ATTR_OF=collections.defaultdict(list)
for a in attr:_ATTR_OF[a['edge_id']].append(a)
def _jvalid(j):
    """분기·이어짐 기간. 적힌 값이 없으면 두 노선이 그 역에 함께 있던 기간(늦은 시작 ~ 이른 끝)이다 (날짜 원칙)"""
    f_,u_=(j.get('valid') or [None,'ongoing'])[:2]
    if f_ is not None:return f_,u_
    ab_=collections.defaultdict(list)
    for e in adj.get(j.get('at'),[]):
        for a in _ATTR_OF[e['id']]:
            if a['line_id'] in (j['line'],j['other']):ab_[a['line_id']].append(a)
    if len(ab_)<2:return (f"[..{AS_OF if u_ in (None,'ongoing') else _edge(u_,1)}]",u_)
    lo_=lambda a:lohi(a['valid_from'])[0] or '0000-01-01'
    st_=max((lo_(min(v,key=lo_)),min(v,key=lo_)['valid_from']) for v in ab_.values())[1]
    return (st_ if st_ is not None else f"[..{AS_OF if u_ in (None,'ongoing') else _edge(u_,1)}]"),u_
# 연결 표(junction)는 계통 이음(route_link)을 만든 판정대로 낸다 (2회차 종합 K01).
# ① 끝 역이 아닌 역에서 분기로만 쓴 이어짐 행은 분기 행이다(DESIGN §2.9 표시 결정표, 綾瀬·中目黒). 시기별 끝 역(era)으로 쓴 행은 이어짐 그대로다
# ② 두 노선이 그 역(같은 묶음)에 함께 선 날이 행 기간 안에 하루도 없으면(이관 앞뒤의 다른 시기 노선, 이름이 같은 다른 노선) 낼 연결이 없어 뺀다
# ③ 두 노선이 같은 칸으로 같은 끝 역에 들어와 환승으로 그린 행(高松（旧）)은 선로 연결이 아니라 뺀다. 뺀 행은 build/report.json warnings에 남긴다
def _jrows():
    out=[]
    for j in junctions:
        # 숨은 분기점·신호장의 행은 계통 이음 없이도 선로 연결 사실이라 그대로 둔다
        if j.get('at') and not j.get('_kinds') and nodes.get(j['at'],{}).get('kind')=='station':
            if j.get('_same_end'):WARN['junction_same_end'].append((j['line'],j['other'],j['at']));continue
            f_,u_=_jvalid(j)
            gs_={j['at']}|{m for m,x in nodes.items() if nodes[j['at']].get('group') and x.get('group')==nodes[j['at']].get('group')}
            A_=[s for m in gs_ for s in node_stops.get(m,()) if routes[s['route_id']]['line']==j['line']]
            B_=[s for m in gs_ for s in node_stops.get(m,()) if routes[s['route_id']]['line']==j['other'] and (not j.get('other_route') or s['route_id']==j['other_route'])]
            if not any(pd and _lo(pd[0])<_lo(u_,True) and _lo(f_)<_lo(pd[1],True) for a in A_ for b in B_ if a is not b for pd in [period(a,b)]):
                WARN['junction_never_together'].append((j['line'],j['other'],j.get('other_route'),j['at']));continue
        # 그날 궤간이 맞지 않아 계통 이음을 하나도 내지 않은 행(3회차 W1a: 大曲 田沢湖線 1997~)은 선로 연결로 내지 않는다
        if j.get('_sharp') and not j.get('_kinds'):WARN['junction_sharp'].append((j['line'],j['other'],j.get('at')));continue
        cont=bool(j.get('continue')) and ('continue' in (j.get('_kinds') or j.get('_tried') or {'continue'}))
        v_=_jvalid(j)
        # 두 노선이 함께 있던 날이 없는 행(八木 연락선 1967-12-20 바뀜: 앞 노선 끝날이 뒤 노선 시작날)은 낼 기간이 없다 (K18)
        if v_[1] not in (None,'ongoing') and not str(v_[0]).startswith('[') and _lo(v_[0])>=_lo(v_[1],True):WARN['junction_empty'].append((j['line'],j['other'],j.get('at'),v_));continue
        # 선로 연결은 그날 두 노선 궤간·방식이 맞는 토막만이다(西鉄 千鳥橋 循環線↔貝塚線: 1954-03-05 貝塚線 1067 改軌 뒤로는 없음). 계통 이음과 같은 track_ok
        ps_=track_ok(j['line'],j['other'],j['at'],v_) if j.get('at') and j['line'] in lines and j['other'] in lines else [v_]
        if not ps_:WARN['junction_gauge'].append((j['line'],j['other'],j.get('at'),v_));continue
        for p_ in ps_:
            out.append((j['line'],j['other'],j.get('other_route'),j.get('at'),j.get('edge'),j.get('side'),int(cont))+tuple(p_)+(j.get('source'),int(bool(j.get('verified')))))
    print('연결 표에서 뺀 행(같은 칸 끝, 함께 서지 않음)',len(WARN['junction_same_end']),len(WARN['junction_never_together']))
    return out
t('junction',['line_id','other_line_id','other_route_id','node_id','edge_id','side','is_continue','valid_from','valid_to','source','verified'],_jrows())
t('node_position',['node_id','lat','lon','quality','checked','source'],[(p['node'],p.get('lat'),p.get('lon'),p.get('quality'),p.get('checked'),p.get('source')) for p in positions])
# 환승역의 노선별 승강장과 통합 노드 (DESIGN §7.5). 시각 표시일 뿐 기록·km·분모와 무관하다
PLAT={x['node']:x for x in _rows_plat() if x['node'] in nodes and (x.get('source')!='n05' or source_on('n05'))}
# 노선별 승강장 자리가 없는 공용 노드(한 노드를 여러 노선이 씀)는 지나가는 노선마다 역 점을 그 노선 선형 위 가장 가까운 점으로 옮긴 자리를 승강장으로 둔다.
# 그 노선이 이 역에서 끝나면(이 노드에 닿는 지금 칸이 하나) 역 점 자리다. 종점에서 갈라지는 선형 끝을 다른 승강장으로 잘못 보지 않게 한다.
# 옮긴 자리가 역 점에서 30m 넘게 떨어진 노선이 있을 때만 만든다. 그 밖(같은 회사 50m 안, 다른 회사 승강장 공유)은 아래 배치 규칙이 한 승강장으로 묶는다.
# 木古内처럼 新幹線 선로가 역 점에서 떨어져 그려져 역 표시 없이 지나가 보이던 것 (13회차 2026-11-19 사용자 지적). 시각 표시일 뿐 기록·km와 무관하다
def _auto_plat():
    geo_={g['edge']:g['coords'] for g in load_geo()}
    pos_={p_['node']:(p_['lat'],p_['lon']) for p_ in positions if p_.get('lat') is not None}
    cur_=collections.defaultdict(set)
    for a_ in attr:
        if a_.get('valid_to')=='ongoing':cur_[a_['edge_id']].add(a_['line_id'])
    nl_=collections.defaultdict(set)
    for s_ in stops:
        if s_['is_stop'] and s_['valid_to']=='ongoing':nl_[s_['node_id']].add(routes[s_['route_id']]['line'])
    out_={}
    for n_,ls_ in sorted(nl_.items()):
        if len(ls_)<2 or n_ in PLAT or n_ not in pos_ or n_ not in nodes:continue
        o_=pos_[n_];cx_=math.cos(math.radians(o_[0]))
        def xy_(lon_,lat_):return ((lon_-o_[1])*111.32*cx_,(lat_-o_[0])*110.57)
        per_={}
        # 노선 순서를 정해 두어야 빌드마다 행 순서가 같다(집합 순서는 실행마다 다름, 13회차 깨끗한 CI 대조)
        for l_ in sorted(ls_):
            es_=[e_['id'] for e_ in adj[n_] if l_ in cur_[e_['id']] and e_['id'] in geo_]
            if len(es_)<2:continue
            best_=None
            for e_ in es_:
                pts_=[xy_(*c_) for c_ in geo_[e_]]
                for i_ in range(len(pts_)-1):
                    (ax_,ay_),(bx_,by_)=pts_[i_],pts_[i_+1];dx_,dy_=bx_-ax_,by_-ay_;L_=dx_*dx_+dy_*dy_
                    t_=0 if L_==0 else max(0,min(1,(-ax_*dx_-ay_*dy_)/L_));qx_,qy_=ax_+t_*dx_,ay_+t_*dy_
                    d_=math.hypot(qx_,qy_)
                    if best_ is None or d_<best_[0]:best_=(d_,qx_,qy_)
            per_[l_]=best_
        far_={l_:v_ for l_,v_ in per_.items() if v_ and v_[0]>0.03}
        if not far_:continue
        out_[n_]=dict(node=n_,lat=o_[0],lon=o_[1],source='auto_line_projection',lines={l_:(round(o_[0]+v_[2]/110.57,6),round(o_[1]+v_[1]/(111.32*cx_),6)) for l_,v_ in far_.items()})
    return out_
AUTO_PLAT=_auto_plat()
PLAT.update(AUTO_PLAT)
print('노선별 승강장 자동(공용 노드, 선형 투영)',len(AUTO_PLAT),sorted(AUTO_PLAT)[:80])
t('platform',['node_id primary key','lat','lon','source'],[(n,x['lat'],x['lon'],x.get('source')) for n,x in sorted(PLAT.items())])
def _layout():
    # 역 단위: hub와 같은 역 묶음을 이은 연결 성분
    par={}
    def f(x):
        while par.setdefault(x,x)!=x:par[x]=par[par[x]];x=par[x]
        return x
    def u(a_,b_):par[f(a_)]=f(b_)
    for h in hubs:
        ms=[m for m in h.get('nodes',[]) if m in nodes]
        for m in ms[1:]:u(ms[0],m)
    byg=collections.defaultdict(list)
    for n_ in nodes.values():
        if n_.get('group'):byg[n_['group']].append(n_['id'])
    for v in byg.values():
        for m in v[1:]:u(v[0],m)
    # 같은 역 이름끼리만 한 역이다. 이름이 다른 역(東京–大手町 같은 간접 환승)은 따로 그린다 (§7.5)
    jan={}
    for x in names:
        if x['entity_type']=='node' and x['lang']=='ja' and not x.get('line') and not x.get('valid_from') and x['id'] not in jan:jan[x['id']]=x['text']
    def base(n_):return re.sub(r'（.*?）|\(.*?\)|駅$','',jan.get(n_,n_)).strip()
    # 배치 단위: (노드, 노선). 노선별 자리가 없으면 노드 자리를 그 노드의 나머지 노선이 함께 쓴다
    nlines=collections.defaultdict(set)
    for s_ in stops:
        if s_['is_stop']:nlines[s_['node_id']].add(routes[s_['route_id']]['line'])
    U={}
    for n_,x in PLAT.items():
        per=x.get('lines') or {}
        rest=sorted(nlines[n_]-set(per))
        for l_,v in per.items():U[(n_,l_)]=(v[0],v[1])
        if rest or not per:U[(n_,None)]=(x['lat'],x['lon'])
    comp=collections.defaultdict(list)
    for u_ in U:comp[(f(u_[0]),base(u_[0]))].append(u_)
    opof={}
    for a_ in attr:
        for n_ in (edges[a_['edge_id']]['a'],edges[a_['edge_id']]['b']):
            if n_ in PLAT:
                k=(lohi(a_['valid_to'])[1] or '9999')
                for key in ((n_,None),(n_,a_['line_id'])):
                    if k>=opof.get(key,('',None))[0]:opof[key]=(k,a_['operator_id'])
    nroutes=collections.Counter(s_['node_id'] for s_ in stops if s_['is_stop'])
    ncur=collections.Counter(s_['node_id'] for s_ in stops if s_['is_stop'] and s_['valid_to']=='ongoing')
    SPAN={}
    for s_ in stops:
        if not s_['is_stop']:continue
        lo_=lohi(s_['valid_from'])[0] or '0000';hi_=lohi(s_['valid_to'])[1] or '9999'
        o_=SPAN.get(s_['node_id']);SPAN[s_['node_id']]=(min(lo_,o_[0]),max(hi_,o_[1])) if o_ else (lo_,hi_)
    _sh=json.load(open(os.path.join(ROOT,'data','overrides','platforms','shared.json'),encoding='utf-8'))
    SHARED=set(_sh['stations'])
    # 역 안에서 그 두 회사끼리만 승강장을 함께 쓰는 곳 (福島: 阿武隈急行·福島交通, JR은 따로)
    SHARED_PAIRS={(x['station'],frozenset(x['operators'])) for x in _sh.get('pairs',[])}
    def dkm(p,q):return math.hypot((p[1]-q[1])*math.cos(math.radians(p[0]))*111.32,(p[0]-q[0])*110.57)
    hubs_out=[];plat_out=[]
    for root,ms in comp.items():
        # 승객이 서는 행이 없는 노드(끝 너머 옛 소속 구간의 서지 않는 노드 등)는 승강장 묶기에 넣지 않는다
        ms=[m for m in ms if m[0] in SPAN]
        if len(ms)<2:continue
        P={m:U[m] for m in ms}
        # 승강장 노드 묶기: 같은 회사 50m 안, 다른 회사는 승강장을 함께 쓸 때(15m 안)만
        cp={m:m for m in ms}
        def cf(x):
            while cp[x]!=x:x=cp[x]
            return x
        for i_,a_ in enumerate(ms):
            for b_ in ms[i_+1:]:
                d=dkm(P[a_],P[b_]);same=opof.get(a_,(0,1))[1]==opof.get(b_,(0,2))[1]
                # 같은 회사는 50m 안이면 하나. 다른 회사는 승강장을 함께 쓰는 역(shared.json)에서 N05 점이 같을 때만 (N05는 이웃한 별개 승강장에도 같은 점을 줌)
                pair=frozenset((opof.get(a_,(0,None))[1],opof.get(b_,(0,None))[1]))
                if (same and d<=0.05) or (not same and d<=0.001 and (root[1] in SHARED or (root[1],pair) in SHARED_PAIRS)):cp[cf(a_)]=cf(b_)
        cl=collections.defaultdict(list)
        for m in ms:cl[cf(m)].append(m)
        # 같은 시기에 함께 있지 않은 승강장(이설 전후의 옛·새 노드)은 환승역이 아니다
        sp={k:(min(SPAN[m[0]][0] for m in v),max(SPAN[m[0]][1] for m in v)) for k,v in cl.items()}
        keep={k for k in cl if any(j!=k and sp[k][0]<sp[j][1] and sp[j][0]<sp[k][1] for j in cl)}
        cl={k:v for k,v in cl.items() if k in keep}
        if len(cl)<2:continue
        cen={k:(sum(P[m][0] for m in v)/len(v),sum(P[m][1] for m in v)/len(v)) for k,v in cl.items()}
        g=(sum(c[0] for c in cen.values())/len(cen),sum(c[1] for c in cen.values())/len(cen))
        near=min(dkm(g,c) for c in cen.values())
        # 무게중심이 모든 승강장에서 250m 넘게 떨어지면 대표 역(노선·계통이 가장 많은 승강장)을 통합 노드로
        kind='centroid'
        if near>0.25:
            # 대표 역: 지금 영업하는 승강장, 그다음 지금 정차하는 계통 수, 전체 계통 수, 짧은 노드 이름(본역)
            rep_=max(cl,key=lambda k:(any(SPAN[m[0]][1]>='9999' for m in cl[k]),sum(ncur[m[0]] for m in cl[k]),sum(nroutes[m[0]] for m in cl[k]),-min(len(m[0]) for m in cl[k])));g=cen[rep_];kind='representative'
        hid='sh_'+min(m[0] for m in ms)
        hubs_out.append((hid,round(g[0],6),round(g[1],6),kind,len(cl)))
        for k,v in cl.items():
            cid='c_'+k[0]+('|'+k[1] if k[1] else '')
            for m in v:plat_out.append((hid,cid,m[0],m[1],round(cen[k][0],6),round(cen[k][1],6)))
    return hubs_out,plat_out
_ho,_po=_layout()
t('station_hub',['id primary key','lat','lon','kind','clusters'],_ho)
t('station_platform',['hub_id','cluster_id','node_id','line_id','lat','lon'],_po)
print('환승역 배치',len(_ho),'승강장 묶음',len({(h,c) for h,c,_,_,_,_ in _po}),'대표 역을 쓴 곳',sum(1 for x in _ho if x[3]=='representative'))
def coverage_of(rid):
    S=route_edges.get(rid,[])
    if not S:return 'none'
    h=sum(1 for e in S if e['id'] in DRAWN)
    return 'full' if h==len(S) else ('none' if h==0 else 'partial')
# 선 유무와 노선 등급은 출처와 무관하게 본다 (DESIGN §2.11). 배포하는 선형 모양(edge_shape)만 OSM을 뺀다
GEO_ALL={g['edge']:g for g in _SPLITP_GEO+load('geometry')}
DRAWN=set(GEO_ALL)
# 임시 운행만 있는 계통(정식 여객 영업 없이 단체·임시 열차만 다님, 新金線·田端貨物線 등)의 운행 토막.
# 계통 사건(open·resume ~ suspend·close)으로 여객 토막을 만들고, 토막이 하나 이상이며 모두 7일 이하면 임시 운행만 있는 계통이다.
# 정기 운행 기간이 있던 계통(高島線 1920–1960, 北小金支線 2003–2014)은 긴 토막이 있어 들지 않는다. 끝이 열린 토막(영업 중)도 들지 않는다.
# 앱은 탭 「임시」 표시·운행일 칩·운행 없는 날의 흐린 그림에 쓴다 (사용자 결정 2026-11-19). valid_to는 다음 날(끝 제외)
def _temp_windows():
    import datetime as _dt
    by_=collections.defaultdict(list)
    for ev_ in events:
        if ev_.get('route') and ev_['type'] in ('open','close','suspend','resume'):by_[ev_['route']].append((ev_['date'],ev_['type']))
    out_=[]
    for r_,evs_ in by_.items():
        if r_ not in routes or not all(re.fullmatch(r'\d{4}-\d\d-\d\d',d_) for d_,_ in evs_):continue
        win_,cur_=[],None
        for d_,k_ in sorted(evs_,key=lambda x:(x[0],x[1] in ('suspend','close'))):
            if k_ in ('open','resume'):cur_=cur_ or d_
            elif cur_:win_.append((cur_,d_));cur_=None
        if cur_ or not win_:continue
        if all((_dt.date.fromisoformat(b_)-_dt.date.fromisoformat(a_)).days<=7 for a_,b_ in win_):
            out_+=[(r_,a_,b_) for a_,b_ in win_]
    return out_
_TEMPW=_temp_windows()
print('임시 운행만 계통',sorted({r_ for r_,_,_ in _TEMPW}),'토막',len(_TEMPW))
t('route_temp_window',['route_id','valid_from','valid_to'],sorted(_TEMPW))
t('route',['id primary key','line_id','role','from_node','to_node','via_nodes','closed','closed_from','map_coverage'],[(r['id'],r['line'],r.get('role'),r['from'],r['to'],json.dumps(r.get('via',[])),int(bool(r.get('closed'))),r.get('closed_from'),coverage_of(r['id'])) for r in routes.values()])
t('route_edge',['route_id','seq','edge_id'],[(rid,i,e['id']) for rid,S in route_edges.items() for i,e in enumerate(S)])
# km를 N05 선 위 위치로 추정한 정차역 (DESIGN §4.5 `? km`). 화면은 km 대신 `?`
EST={(x['route'],SPLIT.get((routes.get(x['route'],{}).get('line'),x['node']),x['node'])) for x in load('stops')}
# 칸에 끼운 분기점(edge_insert)의 km는 선형 투영 비율이라 추정이다
EST|={(s_['route_id'],s_['node_id']) for s_ in stops if s_['node_id'] in EI_EST}
# 근거 조사로 km를 확정한 역은 추정 표시를 뗀다. 그 km에 맞춘 구간 길이는 source_patch/km/research_r5.yaml (tools/dev/apply_km_research.py)
_KMC=os.path.join(ROOT,'data','overrides','km_confirmed.json')
if os.path.exists(_KMC):EST-={(x['route'],x['node']) for x in json.load(open(_KMC,encoding='utf-8'))}
# 승하차 불가 끝 노드 (junction-nodes-rule, 5번 결정 2026-11-19): 승객 정차가 있는 계통의 양 끝인데 어느 계통에서도 승객이 서지 않는 노드(분기점·신호장·정류장이 없어진 경계점).
# 계통 끝인데 그 계통에서는 서지 않는 역(西武 連絡線 끝 御花畑)도 그 계통 일람의 끝 노드다.
# 노선 일람에 가운데가 회색인 노드로 보이고 고를 수 있다(km 계산). 그 노드를 지나는 다른 계통 일람에도 보인다(연락선을 따로 기록하려면 양쪽 노선에서 골라야 한다). 지도에는 그리지 않는다
# 여객 계통 = 화물 전용(숨은) 노선이 아닌 계통. 자기 역이 없는 연락선(中川短絡線·西武 連絡線)도 여객 계통이다
_stopped_routes={r_ for r_ in routes if r_ not in _HID_R}
# 끝 노드: 어느 계통이든 그날의 끝이 된 적 있는 노드(_END) 가운데 승객 역이 아닌 것. 계통 정의의 시작·끝 노드도 넣는다
ENDPT=({n for r in routes.values() if r['id'] in _stopped_routes for n in (r['from'],r['to'])}|{y_['node_id'] for r_,E_ in _END.items() if r_ in _stopped_routes for y_,_,_ in E_})-pub
# 끝 노드 이름은 세 언어 모두 있어야 한다. 고유한 부분은 한자 그대로, 종류(分岐点·信号場 등)만 각 언어로 옮긴다 (사용자 결정 2026-11-19)
_endnm={(x['id'],x['lang']) for x in names if x['entity_type']=='node' and not x.get('line') and not x.get('valid_from') and not x.get('valid_to')}
for n in sorted(ENDPT):
    for lg_ in ('ja','ko','en'):
        if (n,lg_) not in _endnm:err('endpoint_no_name',(n,lg_))
t('route_stop',['route_id','seq','node_id','km_cum','is_stop','is_end_point','valid_from','valid_from_lo','valid_from_hi','valid_to','valid_to_lo','valid_to_hi','km_estimated'],[(s['route_id'],s['seq'],s['node_id'],s['km_cum'],s['is_stop'],1 if s['node_id'] in ENDPT or (not s['is_stop'] and id(s) in _ENDROW and s['route_id'] in _stopped_routes) else 0)+per(0,s['valid_from'])+per(0,s['valid_to'])+(1 if (s['route_id'],s['node_id']) in EST else 0,) for s in stops])
# ── 고를 수 있는 서지 않는 기간과 그날 노드의 정체 (5번 결정 재구성 2026-11-21) ──
# route_stop의 기간은 행 기간(정차)이다. 끝 노드로 고를 수 있는데 정차가 아닌 기간은 이 표에 따로 내고, 그 기간 노드의 정체(style)를 함께 적는다.
# 정차·환승·연도 표시는 route_stop·route_stop_period만 읽고, 고를 수 있는지·노드 모양만 이 표를 읽는다 (뜻을 섞지 않는다).
# style: signal·junction = 가운데가 회색인 노드(신호장·분기점만, 사용자 결정) / nostop = 역은 있으나 이 계통이 그날 서지 않음
# (보통 역 모양에 「승하차 불가」, 결정 A 추천안) / none = 그날 아무것도 없던 경계점(계통을 나중 갈림으로 나눈 자리: 숨김, 결정 B 추천안)
# 정체는 이 차례로 정한다: ① 근거 표(data/overrides/node_identity.json) ② 그날 이름이 신호장·신호소·분기점 ③ 노드 종류가 신호장·분기점
# ④ 그날 어느 계통이든 서는 역 ⑤ 화물역 ⑥ 승객 역이었던 노드: 첫 정차 전 none, 마지막 정차 뒤 junction(남은 선로 지점), 정차 사이 nostop
_gp3=collections.defaultdict(list)
for g_ in stop_gaps:_gp3[id(g_[0])].append((g_[1],g_[2]))
def _stop_pieces3(s_):
    if not s_['is_stop']:return []
    iv=[(s_['valid_from'],s_['valid_to'] or 'ongoing')]
    for c_ in _gp3.get(id(s_),()):iv=_iv_sub(iv,c_)
    return [(f_,t_) for f_,t_ in iv if _lo(f_)<_lo(t_,True)]
_NSTOP=collections.defaultdict(list)
for s_ in stops:
    for f_,t_ in _stop_pieces3(s_):_NSTOP[s_['node_id']].append((_lo(f_),_lo(t_,True)))
_NFIRST={x_:min(a_ for a_,_ in v_) for x_,v_ in _NSTOP.items()}
_NLAST={x_:max(b_ for _,b_ in v_) for x_,v_ in _NSTOP.items()}
_SIGW=re.compile(r'(信号場|信号所|分岐点)')
# 그날 이름이 신호장·신호소·분기점이면 신호장이다. 그날 이름은 기간 이름, 그날 기간 이름이 없으면 기본 이름이다 (정체는 그날 이름을 따른다)
_SIGN=collections.defaultdict(list)
_DNM=collections.defaultdict(list)
for x_ in names:
    if x_['entity_type']=='node' and x_['lang']=='ja' and not x_.get('line'):
        if x_.get('valid_from') or x_.get('valid_to'):_DNM[x_['id']].append((_lo(x_.get('valid_from')),_lo(x_.get('valid_to'),True),bool(_SIGW.search(x_['text']))))
        elif _SIGW.search(x_['text']):_DNM[x_['id']].append(('0000','9999-12-31',None))
for x_,v_ in _DNM.items():
    dated_=[(a_,b_) for a_,b_,w_ in v_ if w_ is not None]
    for a_,b_,w_ in v_:
        if w_:_SIGN[x_].append((a_,b_))
        elif w_ is None:
            # 기본 이름: 기간 이름이 덮지 않는 날만
            iv_=[(a_,b_)]
            for c_,d_ in dated_:
                iv_=[p_ for f_,t_ in iv_ for p_ in ((f_,min(t_,c_)),(max(f_,d_),t_)) if p_[0]<p_[1]]
            _SIGN[x_]+=iv_
_IDP=os.path.join(ROOT,'data','overrides','node_identity.json')
_IDENT=collections.defaultdict(list)
if os.path.exists(_IDP):
    for r_ in json.load(open(_IDP,encoding='utf-8'))['rows']:
        if r_['node'] in nodes:_IDENT[r_['node']].append((_lo(r_.get('from')),_lo(r_.get('to'),True),{'signal':'signal','junction':'junction','station_no_passenger':'nostop','none':'none'}[r_['kind']]))
def _style(x_,d_):
    for a_,b_,k_ in _IDENT.get(x_,()):
        if a_<=d_<b_:return k_
    if any(a_<=d_<b_ for a_,b_ in _SIGN.get(x_,())):return 'signal'
    k_=(nodes.get(x_) or {}).get('kind')
    if k_ in ('signal','junction','pref_boundary'):return 'junction'
    if any(a_<=d_<b_ for a_,b_ in _NSTOP.get(x_,())):return 'nostop'
    if k_=='freight':return 'nostop'
    # 승객 역이었던 노드: 첫 정차 전과 마지막 정차 뒤에는 그 자리에 아무것도 없다(none). 정차 사이(운휴·임시 폐지)는 역이 있다(nostop).
    # 그날 이 계통이나 이어진 계통의 끝인 행은 아래에서 분기점 모양으로 남는다. 승계 표시용 자리 행(肥薩おれんじ鉄道의 唐浜 1951–1955)에
    # 「지금도 있음」 기간이 붙던 것을 막는다 (조사 2026-11-21)
    if x_ not in _NFIRST:return 'none'
    if d_<_NFIRST[x_] or d_>=_NLAST[x_]:return 'none'
    return 'nostop'
def _cuts(x_):
    c_={a_ for a_,_,_ in _IDENT.get(x_,())}|{b_ for _,b_,_ in _IDENT.get(x_,())}
    c_|={a_ for a_,_ in _SIGN.get(x_,())}|{b_ for _,b_ in _SIGN.get(x_,())}
    c_|={a_ for a_,_ in _NSTOP.get(x_,())}|{b_ for _,b_ in _NSTOP.get(x_,())}
    return sorted(v_ for v_ in c_ if v_ and v_ not in ('0000','9999-12-31'))
_SELROWS=[]
for s_ in stops:
    iv_=list(s_.get('sel_iv') or [])
    # 서지 않는 행(분기점·신호장·서지 않는 끝 역)은 행 기간 내내 고를 수 있는 서지 않는 기간이다
    if not s_['is_stop']:iv_.append((s_['valid_from'],s_['valid_to'] or 'ongoing'))
    # 그날 없던 끝 역 대신 붙인 앞 역 행은 그 기간 뒤로 이 계통에 없다(숨김)
    if s_.get('lead_until'):_SELROWS.append((s_,[s_['lead_until'],'ongoing','none']))
    # 역 행의 정차 기간 밖이라도 그 노드가 그날 신호장(근거 표·그날 이름)이고 이 계통 칸이 이 노드에 닿아 있으면 신호장 노드로 고를 수 있다.
    # 역이 신호장으로 격하된 뒤(三岐朝明 1989~, 上越 1983~)와 신호장이 역으로 승격되기 전(逢隈 1960–1988). 신호장이 폐지되면(이름·근거 표 끝) 거기서 끝난다
    if s_['is_stop'] and s_['route_id'] in _rspan:
        for f0_,t0_ in _clip_iv(_edge_iv(s_['route_id'],s_['node_id']),*_rspan[s_['route_id']]):
            for a_,b_ in _minus([(f0_,t0_)],[(s_['valid_from'],s_['valid_to'] or 'ongoing')]):
                pts_=[a_]+[c_ for c_ in _cuts(s_['node_id']) if _lo(a_)<c_<_lo(b_,True)]+[b_]
                iv_+=[(x_,y_) for x_,y_ in zip(pts_,pts_[1:]) if _lo(x_)<_lo(y_,True) and _style(s_['node_id'],_lo(x_))=='signal']
    if not iv_:continue
    iv_=_ivu([(f_,t_ or 'ongoing') for f_,t_ in iv_ if _lo(f_)<_lo(t_,True)])
    for c_ in _stop_pieces3(s_):iv_=_iv_sub(iv_,c_)
    cuts_=sorted(set(_cuts(s_['node_id']))|{v_ for e0_,e1_ in _ENDIV.get(id(s_),()) for v_ in (_lo(e0_),_lo(e1_,True)) if v_ not in ('0000','9999-12-31')})
    for f_,t_ in iv_:
        pts_=[f_]+[c_ for c_ in cuts_ if _lo(f_)<c_<_lo(t_,True)]+[t_]
        prev_=None
        for a_,b_ in zip(pts_,pts_[1:]):
            st_=_style(s_['node_id'],_lo(a_))
            in_end_=any(_lo(e0_)<=_lo(a_)<_lo(e1_,True) for e0_,e1_ in _ENDIV.get(id(s_),()))
            # 그날 이 계통이나 이어진 다른 계통의 끝인 행은 숨기지 않는다. 숨기면 그 끝까지를 기록할 수 없고(三岐線 富田西口–三岐朝明 1950) 갈림 연결이 숨은 행에 달린다(新今宮 1961–1964). 그 자리는 계통이 갈리는 지점이라 분기점 모양이다
            if st_=='none' and in_end_:st_='junction'
            # 그날 이 계통이나 이어진 다른 계통의 끝이 아니면 보이기만 하고 고를 수 없다(_view). 그 자리에서 갈라지거나 이어지는 노선이 없으면 거기서 기록을 끊을 까닭이 없다
            # (하코다테 본선 니야마 신호장 2026~, 사용자 결정 2026-11-21). 끝인 날만 승하차 불가 끝 노드로 고를 수 있다
            if st_!='none' and not in_end_:st_+='_view'
            if prev_ and prev_[2]==st_:prev_[1]=b_;continue
            prev_=[a_,b_,st_];_SELROWS.append((s_,prev_))
# 역을 옮긴 옛 자리·새 자리(data/overrides/moved.json): 날짜를 고른 화면에서는 그날의 자리만 보인다(moved, 앱이 날짜 모름에서는 무시한다).
# 옛 자리는 옮긴 뒤 숨기고, 새 자리는 옮기기 전에 숨긴다. 옛 자리가 어느 계통의 끝이었거나 분기·이어짐이 달렸던 자리(기점 등 특수한 역할,
# 苗穂 옛 역사)면 옮긴 뒤에도 폐역처럼 보인다 (사용자 결정 2026-11-21)
_MV=json.load(open(os.path.join(ROOT,'data','overrides','moved.json'),encoding='utf-8'))
_role_n={y_['node_id'] for E_ in _END.values() for y_,_,_ in E_}|{_nat.get((l_['route_id'],l_['seq'])) for l_ in links if l_['kind'] in ('branch','continue')}
_mvn=0
for mv_ in _MV:
    d_=mv_.get('date')
    if not d_:continue
    for s_ in stops:
        if s_['node_id']==mv_['old'] and mv_['old'] not in _role_n and s_['valid_to'] not in (None,'ongoing') and _lo(s_['valid_to'],True)<='9999':
            _SELROWS.append((s_,[s_['valid_to'],'ongoing','moved']));_mvn+=1
        elif s_['node_id']==mv_['new'] and s_['valid_from'] and _rspan.get(s_['route_id']) and _lo(_rspan[s_['route_id']][0])<_lo(s_['valid_from']):
            _SELROWS.append((s_,[_rspan[s_['route_id']][0],s_['valid_from'],'moved']));_mvn+=1
print('옮긴 역 자리 날짜별 숨김',_mvn)
t('route_stop_select',['route_id','seq','node_id','valid_from','valid_from_lo','valid_from_hi','valid_to','valid_to_lo','valid_to_hi','style'],
  [(s_['route_id'],s_['seq'],s_['node_id'])+per(0,v_[0])+per(0,v_[1] if v_[1]!='9999-12-31' else 'ongoing')+(v_[2],) for s_,v_ in _SELROWS])
print('고를 수 있는 서지 않는 기간',len(_SELROWS),collections.Counter(v_[2] for _,v_ in _SELROWS))
# 빈 분기 방향은 역 좌표로 채운다. 앞 역에서 곧장 가는 쪽이 분기 쪽이다 (설계 §8.1)
# 값이 있는 296행에 대보면 각도 차 0.6rad 이상에서 95% 맞는다. 그보다 애매하면 비워 둔다
def bearing(a,c):return math.atan2((c[1]-a[1])*math.cos(math.radians(a[0])),c[0]-a[0])
def turn(x,y):
    d=abs(x-y)%(2*math.pi);return min(d,2*math.pi-d)
by_route=collections.defaultdict(list)
for x in sorted(stops,key=lambda x:x['seq']):by_route[x['route_id']].append(x)
def where_node(n):
    p=ppos.get(n)
    return (p['lat'],p['lon']) if p else None
def side_of(k):
    # 상대 계통 정차가 있으면 선형 시작 방향으로 잰다 (3회차 W1a)
    if k.get('_o') and k.get('next_stop_node'):
        rd_=_rep_day((k['valid_from'],k['valid_to']));o_=k['_o'];L2=by_route[o_[0]];i2=_SIDX[o_]
        ix_=[j for j,x in enumerate(L2) if x['node_id']==k['next_stop_node']]
        if ix_ and ix_[0]!=i2:
            va=rdir(o_[0],o_[1],1 if ix_[0]>i2 else -1,rd_);cu,cd=ucos(va,rdir(k['route_id'],k['seq'],-1,rd_)),ucos(va,rdir(k['route_id'],k['seq'],1,rd_))
            if cu is not None and cd is not None and abs(cu-cd)>=0.5:return 'up' if cu>cd else 'down'
    L=by_route[k['route_id']]
    at=[i for i,x in enumerate(L) if x['seq']==k['seq']]
    if not at or at[0]==0 or at[0]==len(L)-1:return None
    i=at[0];A,S,B=(where_node(L[j]['node_id']) for j in (i-1,i,i+1));C=where_node(k.get('next_stop_node'))
    if not (A and S and B and C):return None
    go=bearing(S,C);up=turn(bearing(A,S),go);dn=turn(bearing(B,S),go)
    return None if abs(up-dn)<.6 else ('down' if up<dn else 'up')
filled=0
for k in links:
    if k['kind']=='branch' and not k.get('side') and not k.get('at_edge'):
        k['side']=side_of(k);filled+=bool(k['side'])
for _k,_v in NOOP.items():
    for _x in _v:err(_k+'_noop',_x)
print('분기 방향 채움',filled)
# 스위치백 직통 행의 이어짐이 하나도 날카롭지 않으면(塩尻 1982 전 옛 역 배선) 그 행의 이어짐을 모두 표식으로 둔다. 감사 K196이 확인 목록으로 본다 (11회차 S3)
_rjg=collections.defaultdict(list)
for k in links:
    if k.get('_rj'):_rjg[k['_rj']].append(k)
for _v in _rjg.values():
    if not any(k.get('reverse') for k in _v):
        for k in _v:k['reverse']=1
        WARN['reverse_not_sharp'].append((_v[0]['route_id'],_v[0]['seq'],_v[0]['other_line_id']))
# 표식은 계통 이음 행에 두지 않고 따로 낸다(route_link_reverse). 이음 행은 표식 없는 판과 같게 합쳐진다 (11회차 S3)
LREV=[]
for k in links:
    if k.pop('reverse',None):LREV.append(dict(route_id=k['route_id'],seq=k['seq'],other_line_id=k['other_line_id'],next_stop_node=k['next_stop_node'],valid_from=k['valid_from'],valid_to=k['valid_to']))
for k in links:k.pop('_o',None);k.pop('_s',None);k.pop('_rj',None)
# 방향을 아는 행이 있으면 같은 곳으로 가는 방향 없는 행은 뺀다. 앱은 방향이 없으면 아래쪽에 그려서
# 위키에 분기로, 끝 역 규칙으로 이어짐으로 두 번 들어온 노선이 양쪽에 나온다 (南千歳의 石勝線)
# 기간이 겹칠 때만이다. 기간마다 끝 역 판정이 달라 앞 기간은 분기(방향 있음), 뒤 기간은 끝 이어짐(방향 없음)인 곳(北陸本線 敦賀→小浜線 2024-03-16~)은 둘 다 남긴다
_sided=collections.defaultdict(list)
for l in links:
    if l['side']:_sided[(l['route_id'],l['seq'],l['other_line_id'],l['other_route_id'],l['next_stop_node'])].append((l['valid_from'],l['valid_to']))
def _ovl(a,b):return _lo(a[0])<_lo(b[1],True) and _lo(b[0])<_lo(a[1],True)
_before=len(links)
links=[l for l in links if l['side'] or not any(_ovl((l['valid_from'],l['valid_to']),p_) for p_ in _sided.get((l['route_id'],l['seq'],l['other_line_id'],l['other_route_id'],l['next_stop_node']),()))]
print('방향 없는 중복 환승 행 뺌',_before-len(links))
# 그날 선로로 나눈 행 가운데 기간만 이어지고 내용이 같은 행은 하나로 합친다 (K03)
_mk=lambda l:tuple((k,l[k]) for k in sorted(l) if k not in ('valid_from','valid_to'))
# 좌표로 정한 환승 흐름(①②③)은 같은 역에서 같은 다음 역으로 들어오는 상대면 기간마다 뒤집히지 않는다. 이 계통의 이웃 역이 바뀌는 날
# 내적 부호가 넘어가 같은 방면이 시기마다 위·아래로 갈리면 화면이 한 노선을 두 흐름 묶음에 나눠 옛 토막의 「끝남」을 보인다
# (養老線 大垣 → 樽見線 東大垣: 1956–1960 up, 1960~ down. 10회차 G1 chubu_3-012). 가장 늦게 끝나는 행의 흐름으로 맞춘다
_fk=collections.defaultdict(list)
for l in links:
    if l['kind']=='transfer' and l.get('flow_source')=='coord' and l.get('next_stop_node') and l.get('flow') in ('up','down'):_fk[(l['route_id'],l['seq'],l['next_stop_node'])].append(l)
_flowfix=0
for v in _fk.values():
    if len({l['flow'] for l in v})<2:continue
    ref_=max(v,key=lambda l:_lo(l['valid_to'],True))['flow']
    for l in v:
        if l['flow']!=ref_:l['flow']=ref_;_flowfix+=1
print('같은 다음 역 환승 흐름 맞춤',_flowfix)
# 같은 역·같은 상대 노선 분기의 방향(side)이 어떤 기간에만 비어 있으면 다른 기간의 방향으로 채운다. 운행 계통표 방면(own_toward)이 계통이 있던 기간에만
# 방향을 정해(都電 室町三丁目·万世橋 1969–1971), 빈 쪽이 아래로 그려져 위·아래 두 줄이 되던 것 (감사 K125, 10회차 G1)
_sk=collections.defaultdict(list)
for l in links:
    if l['kind']=='branch':_sk[(l['route_id'],l['seq'],l['other_line_id'])].append(l)
_sidefill=0
for v in _sk.values():
    ss_={l['side'] for l in v if l.get('side')}
    if len(ss_)!=1:continue
    sd0_=next(iter(ss_))
    for l in v:
        if not l.get('side'):l['side']=sd0_;_sidefill+=1
print('같은 상대 분기의 빈 방향 채움',_sidefill)
_byk=collections.defaultdict(list)
for l in links:_byk[_mk(l)].append(l)
_merged=0
for v in _byk.values():
    if len(v)<2:continue
    v.sort(key=lambda l:_lo(l['valid_from']))
    for a_,b_ in zip(v,v[1:]):
        if a_.get('_gone'):continue
        if a_['valid_to']==b_['valid_from']:b_['valid_from']=a_['valid_from'];a_['_gone']=True;_merged+=1
links=[l for l in links if not l.pop('_gone',False)]
print('이어진 같은 연결 행 합침',_merged)
# 위키와 끝 역 규칙에서 똑같은 행이 두 번 나오면 하나만 둔다
# 연결 행의 시작이 범위인데 행이 그 범위 안에서 끝나면(정차 변화로 나뉜 토막) 범위 상한을 행 끝으로 자른다. 끝이 범위 하한보다 이르면 행을 뺀다
# (10회차 D1: 직통 끝을 범위로 둔 근거 행 뒤의 환승 토막, 大館 小坂線↔花岡線. 감사 K62)
_rclip=0;_rdrop=0;_k2=[]
for l in links:
    f_,t_=str(l.get('valid_from') or ''),l.get('valid_to')
    m_=re.match(r'^\[(\d{4}-\d\d-\d\d)\.\.(\d{4}-\d\d-\d\d)\]$',f_)
    if m_ and t_ not in (None,'ongoing') and re.match(r'^\d{4}-\d\d-\d\d$',str(t_)) and m_.group(2)>t_:
        if m_.group(1)>=t_:_rdrop+=1;continue
        l=dict(l,valid_from=f'[{m_.group(1)}..{t_}]');_rclip+=1
    _k2.append(l)
links=_k2
print('연결 시작 범위 상한을 행 끝으로 자름',_rclip,'뺌',_rdrop)
_seen=set();_dup=0;_kept=[]
for l in links:
    k=tuple(sorted((x,str(y)) for x,y in l.items()))
    if k in _seen:_dup+=1;continue
    _seen.add(k);_kept.append(l)
links=_kept
print('같은 환승 행 합침',_dup)
# 상대 계통이 비어 있는 분기·이어짐은 다음 역(없으면 상대 노드)이 있는 상대 노선 계통이 하나뿐이면 그 계통을 적는다.
# 비어 있으면 앱이 상대 노선 본선 계통을 열어 다른 계통으로 넘어갔다 (肥薩おれんじ鉄道 川内 → 鹿児島本線 隈之城, 검토 M4 2026-11-21)
_rn_=collections.defaultdict(set)
for rid_,L_ in by_route.items():
    for y_ in L_:_rn_[rid_].add(y_['node_id'])
_orf=0
for l_ in links:
    if l_.get('other_route_id') or l_['kind'] not in ('branch','continue') or l_['other_line_id'] not in lines:continue
    t_=l_.get('next_stop_node') or l_.get('other_node')
    if not t_:continue
    c_=[r_ for r_ in _RBL.get(l_['other_line_id'],()) if r_ not in _HID_R and t_ in _rn_[r_]]
    if len(c_)==1:l_['other_route_id']=c_[0];_orf+=1
print('상대 계통 채움',_orf)
# 기록하지 않는 버스 구간을 직통처럼 늘 보이는 끝 이어짐으로 둔다 (data/overrides/bus_through.json). 계통이 없는 표시용 노선이라 앱은 넘어가지 않는다
BUS=json.load(open(os.path.join(ROOT,'data','overrides','bus_through.json'),encoding='utf-8'))
for b_ in BUS:
    st_=[s for s in stops if s['route_id']==b_['route'] and s['node_id']==b_['node']]
    if len(st_)!=1 or b_['line'] in lines:err('bus_through_bad',b_['line']);continue
    links.append(dict(route_id=b_['route'],seq=st_[0]['seq'],other_line_id=b_['line'],other_route_id=None,kind='continue',side=None,at_edge=0,other_node=None,next_stop_node=None,terminal_node=None,flow='through',flow_source='hand',valid_from=b_['valid_from'],valid_to='ongoing'))
t('route_link',['route_id','seq','other_line_id','other_route_id','kind','side','at_edge','other_node','next_stop_node','terminal_node','flow','flow_source','valid_from','valid_to'],[(l['route_id'],l['seq'],l['other_line_id'],l['other_route_id'],l['kind'],l['side'],l['at_edge'],l['other_node'],l['next_stop_node'],l['terminal_node'],l['flow'],l['flow_source'],l['valid_from'],l['valid_to']) for l in links])
# 끝 역 스위치백 직통 표식 기간 (근거 표 THROUGH reverse 행, DESIGN §14). 같은 이음의 이어진 기간은 하나로 합친다 (11회차 S3)
_lrk=collections.defaultdict(list)
for x_ in LREV:_lrk[(x_['route_id'],x_['seq'],x_['other_line_id'],x_['next_stop_node'])].append(x_)
_lrv=[]
for k_,v_ in sorted(_lrk.items(),key=lambda z:str(z[0])):
    v_.sort(key=lambda x:_lo(x['valid_from']))
    for x_ in v_:
        if _lrv and _lrv[-1][:4]==k_ and _lrv[-1][5]==x_['valid_from']:_lrv[-1]=_lrv[-1][:5]+(x_['valid_to'],)
        elif not(_lrv and _lrv[-1][:4]==k_ and _lrv[-1][4]==x_['valid_from'] and _lrv[-1][5]==x_['valid_to']):_lrv.append(k_+(x_['valid_from'],x_['valid_to']))
t('route_link_reverse',['route_id','seq','other_line_id','next_stop_node','valid_from','valid_to'],_lrv)
# 병주 (DESIGN §8.1). 같은 두 역을 서로 다른 노선이 같은 기간에 함께 잇는 칸은 모두 판정 표(parallel_runs.json)에 있어야 한다.
# 판정 단위는 정차역 사이 한 칸이다. 그 칸의 선로 조각이 모두 같은 상대와 병주일 때만 병주이고, 이어진 칸을 한 구간으로 묶는다
PR=json.load(open(os.path.join(ROOT,'data','overrides','parallel_runs.json'),encoding='utf-8'))['rows']
# 판정 행의 nodes는 한 칸 [A, B]이거나 칸 여럿 [[A, B], [B, C]]이다
def _pr_pairs(r):return [frozenset(r['nodes'])] if isinstance(r['nodes'][0],str) else [frozenset(x) for x in r['nodes']]
def _grp(n):return (nodes.get(n) or {}).get('group') or n
JUDGED={(frozenset(r['lines']),k_) for r in PR for k_ in _pr_pairs(r)}
JUDGED_G={(frozenset(r['lines']),frozenset(_grp(x) for x in k_)) for r in PR for k_ in _pr_pairs(r)}
_span=collections.defaultdict(list)
for a in attr:
    e=edges[a['edge_id']];_span[frozenset((e['a'],e['b']))].append((a['line_id'],lohi(a['valid_from'])[0] or '',lohi(a['valid_to'])[1] or '9999'))
# 함께 잇는 기간은 집계 행 전체에서 잰다 (국철→JR처럼 행이 나뉘어도 한 기간)
_both=collections.defaultdict(list)
for k_,v in _span.items():
    for i,x in enumerate(v):
        for y in v[i+1:]:
            if x[0]!=y[0] and x[1]<y[2] and y[1]<x[2]:
                if (frozenset((x[0],y[0])),k_) not in JUDGED:err('parallel_unjudged',(x[0],y[0],sorted(k_)))
                _both[(frozenset((x[0],y[0])),k_)].append((max(x[1],y[1]),min(x[2],y[2])))
# 사업자별로 노드·칸이 나뉜 공용 선로(のと鉄道 七尾–和倉温泉, 井原線 総社–清音, 関空連絡橋)는 같은 역 묶음(group) 쌍을 잇는 칸끼리 병주 후보다 (2회차 종합 K09).
# 판정이 없는 후보는 알린다(판정 표를 채우는 동안 빌드를 멈추지 않는다)
_gs=collections.defaultdict(list)
for k_,v in _span.items():
    gk_=frozenset(_grp(x) for x in k_)
    if len(gk_)==2:
        for x in v:_gs[gk_].append(x+(k_,))
_gboth=collections.defaultdict(list)
for gk_,v in _gs.items():
    for i,x in enumerate(v):
        for y in v[i+1:]:
            if x[0]!=y[0] and x[3]!=y[3] and x[1]<y[2] and y[1]<x[2]:
                L_=frozenset((x[0],y[0]))
                _gboth[(L_,gk_)].append((max(x[1],y[1]),min(x[2],y[2]),x[0],x[3],y[0],y[3]))
                if (L_,gk_) not in JUDGED_G and (L_,x[3]) not in JUDGED and (L_,y[3]) not in JUDGED:WARN['parallel_group_unjudged'].append((x[0],sorted(x[3]),y[0],sorted(y[3])))
PAR=collections.defaultdict(dict)
for r in PR:
    if not r['parallel']:continue
    a_,b_=r['lines']
    for k_ in _pr_pairs(r):
        w=_both.get((frozenset((a_,b_)),k_))
        if w:
            per_=(min(x[0] for x in w),max(x[1] for x in w))
            PAR[(a_,k_)][b_]=per_;PAR[(b_,k_)][a_]=per_
            continue
        wg=_gboth.get((frozenset((a_,b_)),frozenset(_grp(x) for x in k_)))
        if not wg:err('parallel_unused',(a_,b_,sorted(k_)));continue
        per_=(min(x[0] for x in wg),max(x[1] for x in wg))
        for _,_,l1,k1,l2,k2 in wg:PAR[(l1,k1)][l2]=per_;PAR[(l2,k2)][l1]=per_
_rs=collections.defaultdict(dict)
for s in stops:
    q=_rs[s['route_id']].setdefault(s['seq'],[s['node_id'],0])
    q[1]|=s['is_stop']
STOPSEQ={rid:[(seq,v[0]) for seq,v in sorted(d.items()) if v[1]] for rid,d in _rs.items()}
par_rows=[];_par1950=[];_par1950c=[]
for rid,d in _rs.items():
    line_=routes[rid]['line'];seq=sorted(d);node=[d[x][0] for x in seq]
    st=[i for i,x in enumerate(seq) if d[x][1]]
    runs=[]
    for i,j in zip(st,st[1:]):
        sub=[PAR.get((line_,frozenset((node[x],node[x+1]))),{}) for x in range(i,j)]
        for p in (set.intersection(*[set(s_) for s_ in sub]) if sub else ()):
            lo=max(s_[p][0] for s_ in sub);hi=min(s_[p][1] for s_ in sub)
            last=next((u for u in runs if u['p']==p and u['b']==i),None)
            if last:last.update(b=j,lo=max(last['lo'],lo),hi=min(last['hi'],hi))
            else:runs.append(dict(p=p,a=i,b=j,lo=lo,hi=hi))
    for u in runs:
        na,nb=node[u['a']],node[u['b']]
        # 상대 노선에서 두 끝 역을 정차역으로 지나는 계통. 바깥으로 이웃한 정차역과 그 방향 끝 역이 들고 나는 줄이 된다
        # 사업자별로 노드가 나뉜 공용 선로는 상대 계통에서 같은 역 묶음(group)의 노드로 찾는다 (K09)
        cand=[r_ for r_,s_ in STOPSEQ.items() if routes[r_]['line']==u['p'] and ({na,nb}<={n_ for _,n_ in s_} or {_grp(na),_grp(nb)}<={_grp(n_) for _,n_ in s_})]
        cand.sort(key=lambda r_:(routes[r_].get('role')!='main',not {na,nb}<={n_ for _,n_ in STOPSEQ[r_]},r_))
        prow=cand[0] if cand else None
        ps=[n_ for _,n_ in STOPSEQ.get(prow,[])]
        if prow and not {na,nb}<=set(ps):
            na=next(n_ for n_ in ps if _grp(n_)==_grp(na));nb=next(n_ for n_ in ps if _grp(n_)==_grp(nb))
        loop=bool(prow) and bool(routes[prow].get('closed'))
        if loop and ps and ps[0]==ps[-1]:ps=ps[:-1]
        # 다음 역·끝 역은 그 기간 상대 계통에 서는 역으로 고른다. 상대 계통 정차가 바뀌는 날마다 토막을 나눈다
        # (井原線 清音 → 伯備線 다음 酒津(1962 폐지) → 倉敷, のと鉄道七尾線 끝 輪島(2001 폐지) → 穴水. 10회차 G1 chubu_2-009·chugoku_shikoku_1-012)
        def _seg(ps_):
            ia,ib=(ps_.index(na),ps_.index(nb)) if prow else (None,None)
            # 순환 계통은 끝을 지나 반대쪽으로 이어지고, 방면 끝 역은 없다
            dd=(1 if (ib-ia)%len(ps_)==1 else -1) if loop else (1 if prow and ib>ia else -1)
            def nb_(at,step):
                k2=at+step
                if loop:return (ps_[k2%len(ps_)],None)
                return (ps_[k2],ps_[-1] if step>0 else ps_[0]) if prow and 0<=k2<len(ps_) else (None,None)
            return (nb_(ia,-dd) if prow else (None,None)),(nb_(ib,dd) if prow else (None,None))
        lo_u=u['lo'] or '0000-01-01';hi_u=u['hi'] or '9999-12-31'
        pr_=[x for x in stops if x['route_id']==prow and x['is_stop']] if prow else []
        def _on_(x,d_):return (lohi(x['valid_from'])[0] or '0000')<=d_<('9999' if x['valid_to'] in (None,'ongoing') else (lohi(x['valid_to'])[0] or '9999'))
        cut_=sorted({d_ for x in pr_ for d_ in ((lohi(x['valid_from'])[0] if x['valid_from'] else None),(None if x['valid_to'] in (None,'ongoing') else lohi(x['valid_to'])[0])) if d_ and lo_u<d_<hi_u})
        segs_=[]
        for d0_,d1_ in zip([lo_u]+cut_,cut_+[hi_u]):
            on_={x['node_id'] for x in pr_ if _on_(x,d0_)}|{na,nb}
            ps_d=[n_ for n_ in ps if n_ in on_] if prow else ps
            v_=_seg(ps_d)
            if segs_ and segs_[-1][2]==v_:segs_[-1][1]=d1_
            else:segs_.append([d0_,d1_,v_])
        pstop={_grp(n_) for n_ in ps}
        # 뺀 1950 전 토막에 끊김 없이 이어진 첫 토막은 그 병주가 시작한 날부터다. 날짜 모름 화면이 이 시작을 적는다
        # (阪神なんば線 大物 → 阪神本線 1928~, 1936 梅田 지하화로 나뉜 앞 토막을 빼면 「1936~」이 병주 시작처럼 읽혔다. 11회차 F1)
        _c0=None
        for d0_,d1_,(inn,out) in segs_:
            # 1950 전에 끝난 병주 토막은 기록 범위 밖이라 두지 않는다(1950 전에 끝난 연결 행과 같다. 西野田線 1918–1932, 10회차 G1 kinki_3-007)
            if d1_<'1950-01-01':
                _par1950.append((rid,u['p'],d0_,d1_))
                if _c0 is None:_c0=d0_
                continue
            if _c0 is not None:_par1950c.append((rid,u['p'],_c0,d0_));d0_=_c0;_c0=None
            par_rows.append((rid,u['p'],prow,seq[u['a']],seq[u['b']],json.dumps([seq[x] for x in st if u['a']<=x<=u['b'] and _grp(node[x]) in pstop]),inn[0],inn[1],out[0],out[1],d0_ if d0_!='0000-01-01' else None,d1_ if d1_<'9999' else None))
# 행 순서를 고정한다. 상대 노선을 모은 집합의 순서가 빌드마다 달라 같은 칸 병주 줄의 바깥·안쪽 자리가 바뀌었다(京成本線 成田 成田線·成田空港線, 2026-11-17)
# 같은 칸이면 먼저 시작한 병주가 앞(안쪽)이다
par_rows.sort(key=lambda r_:(r_[0],r_[3],r_[4],r_[10] or '',r_[1],r_[11] or ''))
t('route_parallel',['route_id','other_line_id','other_route_id','from_seq','to_seq','stop_seqs','in_next_stop','in_terminal','out_next_stop','out_terminal','valid_from_lo','valid_to_hi'],par_rows)
print('병주 구간',len(par_rows),'1950 전에 끝나 뺀 토막',len(_par1950),'뺀 토막의 시작을 이어받은 첫 토막',len(_par1950c))
succ={frozenset((e['a'],e['b'])):e['id'] for e in edges.values() if e.get('alt')!='old'}
# 이설로 옮긴 역은 옛 노드와 새 노드가 따로다 (moved.json). 옛 선로의 끝을 새 노드로 바꿔 짝을 찾는다
NEWOF={mv['old']:mv['new'] for mv in json.load(open(os.path.join(ROOT,'data','overrides','moved.json'),encoding='utf-8'))}
_el=[]
_noold=[e for e in edges.values() if e.get('alt')!='old']
_g=collections.defaultdict(list)
for e in _noold:_g[e['a']].append(e);_g[e['b']].append(e)
def _sp(x,y,line):
    """같은 seed_line의 지금 칸으로 x→y 최단 길 (edge 목록, x 쪽부터)"""
    pq=[(0.0,x)];dist={x:0.0};prev={}
    while pq:
        d_,n_=heapq.heappop(pq)
        if n_==y:break
        if d_>dist[n_]:continue
        for e in _g[n_]:
            if e.get('seed_line')!=line:continue
            m_=other(e,n_);nd=d_+kms.get(e['id'],0)
            if nd<dist.get(m_,1e12):dist[m_]=nd;prev[m_]=(n_,e);heapq.heappush(pq,(nd,m_))
    if y not in prev:return None
    out=[];n_=y
    while n_!=x:n_,e=prev[n_];out.append(e)
    return out[::-1]
_olds=[e for e in edges.values() if e.get('alt')=='old']
_oadj=collections.defaultdict(list)
for e in _olds:_oadj[e['a']].append(e);_oadj[e['b']].append(e)
_on=lambda n,l:any(c.get('seed_line')==l for c in _g.get(n,()))   # 그 노선(seed_line)의 지금 선로에 닿는 노드
for e in _olds:
    s_=succ.get(frozenset((NEWOF.get(e['a'],e['a']),NEWOF.get(e['b'],e['b']))))
    if s_:_el.append((e['id'],s_,'relocate'));continue
    # 1:1 짝이 없으면(옛 경로가 다른 역을 지남) 옛 칸 사슬을 지금 선로에 닿는 두 끝(옮긴 역은 새 노드)까지 늘이고, 그 두 끝을 잇는 지금 길에서 km 위치가 같은 칸을 짝으로 둔다.
    # 막다른 옛 칸(仙人峠·立山仮)은 갈라진 역에서 그 계통의 다음 역 쪽 지금 칸이 짝이다
    chain=[e];ends=[]
    for k_ in ('a','b'):
        n_=e[k_];prev_e=e;side=[]
        while not _on(NEWOF.get(n_,n_),e['seed_line']):
            nx=[x for x in _oadj[n_] if x is not prev_e and x.get('route_only')==e.get('route_only')]
            if len(nx)!=1:break
            prev_e=nx[0];side.append(prev_e);n_=other(prev_e,n_)
        ends.append(NEWOF.get(n_,n_));chain=(side[::-1]+chain) if k_=='a' else (chain+side)
    X,Y=ends
    path=_sp(X,Y,e['seed_line']) if _on(X,e['seed_line']) and _on(Y,e['seed_line']) else None
    if path:
        tot_o=sum(kms.get(c['id'],0) for c in chain);tot_p=sum(kms.get(c['id'],0) for c in path)
        pos=0.0
        for c in chain:
            if c is e:break
            pos+=kms.get(c['id'],0)
        mid=(pos+kms.get(e['id'],0)/2)/(tot_o or 1)*tot_p;acc=0.0;pick=path[-1]
        for c in path:
            acc+=kms.get(c['id'],0)
            if acc>=mid:pick=c;break
        _el.append((e['id'],pick['id'],'reroute'));continue
    # 막다른 칸: 지금 선로에 닿은 끝에서 계통 순서상 다음 지금 칸
    at=X if _on(X,e['seed_line']) else Y
    rid_=e.get('route_only');rk=route_rank.get(rid_,{})
    nx=[c for c in _g[at] if c.get('seed_line')==e['seed_line'] and rk.get(other(c,at),-1)>rk.get(at,0)]
    _el.append((e['id'],nx[0]['id'] if nx else None,'reroute' if nx else 'relocate'))
t('edge_link',['edge_id','successor_edge_id','kind'],_el)
def geo_source(eid):
    g=GEO_ALL.get(eid)
    if not g:return None
    s=g.get('source') or ''
    # 나뉜 역 같은 km 점 칸(split_period)은 두 노드 좌표를 잇는 규칙 직선이다
    return 'osm' if s=='osm' else 'hand' if s=='hand' else 'rule' if s=='split_period' else ('n05' if s.startswith('N05') else 'n02')
t('edge',['id primary key','n','from_node','to_node','seed_line','route_only','geometry_quality','geometry_source'],[(e['id'],int(e['id'][2:]),e['a'],e['b'],e.get('seed_line'),e.get('route_only'),'precise' if e['id'] in GEO_ALL else 'none',geo_source(e['id'])) for e in edges.values()])
def _life_rows():
    # 기간 경계가 불확실한 날(1953-XX-XX)이면 그 하한을 앞 기간의 시작보다 이르게 두지 않는다. 휴지 1953-06-26 뒤의 재개는 1953-06-26 이후다.
    # 좁힌 경계는 원문도 범위로 다시 써서 원문과 하한·상한이 늘 맞게 한다
    by=collections.defaultdict(list)
    for r in life:
        by[r['edge_id']].append([r['edge_id']]+list(per(0,r['valid_from']))+list(per(0,r['valid_to']))+[r['status'],r['last_service'],r['legal_abolition'],r['close_reason']])
    def narrow(x,i,lo):
        x[i+1]=lo;x[i]=lo if lo==x[i+2] else f'[{lo}..{x[i+2]}]'
    out=[]
    for v in by.values():
        # 사건을 적용한 순서가 시간 순서다 (하한으로 정렬하면 불확실한 경계가 앞뒤를 바꾼다). 이어짐은 좁히기 전 원문으로 본다
        orig=[(x[1],x[4]) for x in v]
        for x in v:
            if x[2] and x[5] and x[5]<x[2]:narrow(x,4,x[2])
        for (a_,b_),(oa,ob) in zip(zip(v,v[1:]),zip(orig,orig[1:])):
            if oa[1]==ob[0] and b_[2] and a_[2] and b_[2]<a_[2]:
                lo_=a_[2];narrow(b_,1,lo_);narrow(a_,4,lo_)
        out+=[tuple(x) for x in v]
    return out
t('edge_life',['edge_id','valid_from','valid_from_lo','valid_from_hi','valid_to','valid_to_lo','valid_to_hi','status','last_service','legal_abolition','close_reason'],_life_rows())
t('edge_km',['edge_id','km','m'],[(k,v,round(v*1000)) for k,v in kms.items()])
t('edge_km_era',['edge_id','line_id','km','m'],[(e_,l_,round(v,3),round(v*1000)) for (l_,e_),v in sorted(ERA.items())])
t('edge_attr',['edge_id','line_id','operator_id','lineage_id','carryover_group','denominator_class','valid_from','valid_from_lo','valid_from_hi','valid_to','valid_to_lo','valid_to_hi'],[(a['edge_id'],a['line_id'],a['operator_id'],a['lineage_id'],a['carryover_group'],a['denominator_class'])+per(0,a['valid_from'])+per(0,a['valid_to']) for a in attr])
# 승계 켬일 때만 보이는 국철 시대 폐역과 구선로 (DESIGN §2.9 E, 사용자 결정 2026-11-06).
# 국철·JR에서 다른 사업자로 넘어간 구간의 뒤 계통에, 이관 전에 끝난 앞 계통의 같은 노선 구선로 분기와 정차를 옮겨 둔다. 고를 수 있는지는 날짜가 정한다
_jr={o for (o,) in db.execute("select id from operator") if o=='o_japanese_national_railways' or o.startswith('o_jr')}
_rl=dict(db.execute("select id,line_id from route"))
_re=collections.defaultdict(set)
for _r,_e in db.execute("select route_id,edge_id from route_edge"):_re[_e].add(_r)
_ea=collections.defaultdict(list)
for _x in db.execute("select edge_id,line_id,operator_id,lineage_id,valid_from_lo,valid_to_lo from edge_attr"):_ea[_x[0]].append(_x)
_pairs={}
for _e,_xs in _ea.items():
    for _x in _xs:
        if _x[2] in _jr:continue
        for _y in _xs:
            if _y[2] not in _jr or _y[3]!=_x[3] or (_y[5] or '')>(_x[4] or ''):continue
            for _r2 in _re[_e]:
                if _rl[_r2]!=_x[1]:continue
                for _r1 in _re[_e]:
                    if _rl[_r1]==_y[1]:_pairs[(_r2,_r1)]=min(_pairs.get((_r2,_r1),'9999'),_x[4] or '9999')
_rs=collections.defaultdict(dict)
for _r,_s,_n,_st,_f,_t in db.execute("select route_id,seq,node_id,is_stop,valid_from,valid_to from route_stop"):_rs[_r][_n]=(_s,_st,_f,_t)
# 계통의 마지막 정차일. 이관일 전에 끝난 계통만 구선로다 (지금도 다니는 JR 계통은 옮기지 않는다)
_rend=collections.defaultdict(str)
for _r,_t in db.execute("select route_id,max(coalesce(valid_to_hi,'9999-12-31')) from route_stop group by 1"):_rend[_r]=_t
_cl=[];_cs=[]
for (_r2,_r1),_day in sorted(_pairs.items()):
    _seq1={v[0]:n for n,v in _rs[_r1].items()}
    for _n,(_s1,_st1,_f1,_t1) in _rs[_r1].items():
        if _st1 and _t1 not in (None,'ongoing') and (lohi(_t1)[1] or '')<=_day and _n in _rs[_r2] and not _rs[_r2][_n][1]:_cs.append((_r2,_rs[_r2][_n][0],_n,_f1,_t1))
    # 같은 노선의 구선로 계통만 옮긴다. 본선끼리의 이음은 3섹 계통에 이미 있다
    for _l in [l for l in links if l['route_id']==_r1 and l['kind'] in ('branch','continue') and l['other_line_id']==_rl[_r1] and l['other_route_id'] and routes[l['other_route_id']].get('role')!='main' and _rend[l['other_route_id']]<=_day]:
        _n=_seq1.get(_l['seq'])
        if not _n or _n not in _rs[_r2] or _l['valid_to'] in (None,'ongoing') or (lohi(_l['valid_to'])[1] or '')>_day:continue
        _cl.append((_r2,_rs[_r2][_n][0],_l['other_line_id'],_l['other_route_id'],_l['kind'],_l['side'],_l['at_edge'],_l['other_node'],_l['next_stop_node'],_l['terminal_node'],_l['flow'],_l['flow_source'],_l['valid_from'],_l['valid_to']))
t('bus_section',['line_id','pattern','seq','stop_ja','valid_from','valid_to'],[(b_['line'],p_['name'],i_,n_,p_.get('since'),p_.get('until') or 'ongoing') for b_ in BUS for p_ in b_['patterns'] for i_,n_ in enumerate(p_['stops'])])
db.executemany('insert into line values (?,?,?)',[(b_['line'],'bus',None) for b_ in BUS])
t('route_link_carryover',['route_id','seq','other_line_id','other_route_id','kind','side','at_edge','other_node','next_stop_node','terminal_node','flow','flow_source','valid_from','valid_to'],_cl)
# 재개·폐지가 정해지지 않은 역 정차 운휴(陸羽西線 羽前前波·高屋: 2022-05-14 운휴, 2026-01-16 노선 재개 뒤 全列車通過). 노선 운휴와 같게 「운휴」다.
# 정차 행은 끝 없이 두고 끝 없는 공백(gap_to ongoing)을 단다. 앞뒤 칸이 운행 중인지는 칸 수명이 따로 안다. 폐지가 확정되면 결정 119대로
# stop_dates로 마지막 정차 다음 날에 끝낸다 (사용자 결정 2026-11-16, data/overrides/stop_suspended.json)
_SSP=os.path.join(ROOT,'data','overrides','stop_suspended.json');_nss=0
for x_ in (json.load(open(_SSP,encoding='utf-8')) if os.path.exists(_SSP) else []):
    hit_=[s for s in stops if s['route_id']==x_['route'] and s['node_id']==x_['node'] and s['is_stop'] and s.get('valid_to') in (None,'ongoing')]
    if not hit_:err('stop_suspended',x_);continue
    for s in hit_:stop_gaps.append((s,x_['from'],'ongoing'));_nss+=1
print('재개 미정 역 정차 운휴',_nss)
# 정차 기간 사이 서지 않은 때 (stop_dates의 여러 기간). gap_from은 앞 기간의 끝(그날부터 서지 않음), gap_to는 다음 기간의 시작
t('route_stop_gap',['route_id','seq','node_id','gap_from','gap_from_lo','gap_from_hi','gap_to','gap_to_lo','gap_to_hi'],[(s['route_id'],s['seq'],s['node_id'])+per(0,a_)+per(0,b_) for s,a_,b_ in stop_gaps if s['is_stop']])
t('route_stop_carryover',['route_id','seq','node_id','valid_from','valid_from_lo','valid_from_hi','valid_to','valid_to_lo','valid_to_hi'],[(r_,q_,n_)+per(0,f_)+per(0,t_) for r_,q_,n_,f_,t_ in _cs])
print('승계 켬 국철 시대 구선로',len(_cl),'폐역',len(_cs))
# 한 방향 운행 칸과 한 방향 정차 (DESIGN §8 한 방향 운행·한 방향 정차, 사용자 결정 2026-11-12)
# one_way.json의 path는 운행 순서의 역이다. 이웃한 두 역 사이의 그 계통 칸(숨은 노드를 거쳐도)을 모두 그 방향으로만 지나게 한다
def _route_between(rid,a,b):
    g_=collections.defaultdict(list)
    for e in route_edges.get(rid,[]):g_[e['a']].append((e['b'],e));g_[e['b']].append((e['a'],e))
    stops_={x['node_id'] for x in by_route.get(rid,[]) if x['is_stop']}-{a,b}
    prev={a:None};q=collections.deque([a])
    while q:
        n_=q.popleft()
        if n_==b:break
        for m_,e in g_[n_]:
            if m_ in prev or (m_ in stops_):continue
            prev[m_]=(n_,e);q.append(m_)
    if b not in prev:return None
    out=[];n_=b
    while prev[n_]:
        f_,e=prev[n_];out.append((f_,n_,e['id']));n_=f_
    return out[::-1]
_ow=[]
for o_ in json.load(open(os.path.join(ROOT,'data','overrides','one_way.json'),encoding='utf-8')):
    if o_['route'] not in route_edges:err('one_way_route',{'route':o_['route']});continue
    for a_,b_ in zip(o_['path'],o_['path'][1:]):
        hops_=_route_between(o_['route'],a_,b_)
        if not hops_:err('one_way_edge',{'route':o_['route'],'from':a_,'to':b_});continue
        for f_,t_,e_ in hops_:_ow.append((o_['route'],e_,f_,t_)+per(0,o_['from'])+per(0,o_.get('to') or 'ongoing'))
t('edge_one_way',['route_id','edge_id','from_node','to_node','valid_from','valid_from_lo','valid_from_hi','valid_to','valid_to_lo','valid_to_hi'],_ow)
_sd=[]
for s_ in json.load(open(os.path.join(ROOT,'data','overrides','stop_direction.json'),encoding='utf-8')):
    if not any(x['node_id']==s_['node'] and x['is_stop'] for x in by_route.get(s_['route'],[])):err('stop_direction_stop',{'route':s_['route'],'node':s_['node']});continue
    if s_['direction'] not in ('seq_up','seq_down'):err('stop_direction_dir',{'route':s_['route'],'node':s_['node']});continue
    if s_.get('use') not in (None,'alight','board'):err('stop_direction_use',{'route':s_['route'],'node':s_['node']});continue
    _sd.append((s_['route'],s_['node'],s_['direction'],s_.get('label'),s_.get('use'))+per(0,s_['from'])+per(0,s_.get('to') or 'ongoing'))
t('stop_direction',['route_id','node_id','direction','label','use','valid_from','valid_from_lo','valid_from_hi','valid_to','valid_to_lo','valid_to_hi'],_sd)
print('한 방향 칸',len(_ow),'한 방향 정차',len(_sd))
def arch_route(a):
    """이웃 역이 있는 계통에 건다"""
    for x in (a.get('after'),a.get('before')):
        if x and any(s['node_id']==x for s in by_route.get(a.get('route'),[])):return a.get('route')
    # 이웃 역 둘을 다 가진 계통이 먼저다. 한쪽 역만 가진 지선(伊勢崎線 押上–曳舟의 曳舟)에 걸면 앞 역이 그 계통에 없다
    want={a.get('after'),a.get('before')}-{None}
    cand=[rid for rid,L in by_route.items() if routes[rid]['line']==a.get('line') and want&{s['node_id'] for s in L}]
    if cand:return max(cand,key=lambda rid:(len(want&{s['node_id'] for s in by_route[rid]}),routes[rid].get('role')=='main'))
    return a.get('route')
# 운행 계통의 판. 원본은 역을 일본어 이름으로 적는다(tools/gen_source.py). 여기서 그 판 경로의 노드로 바꾼다.
# 같은 경로에 같은 이름이 둘이면(옛 이름·옛 자리: 紀勢本線 和歌山, 関西本線 湊町, 予讃線 高松（旧）) 판 기간 [from, to)에
# 그 계통에 서고 그 이름이던 노드를 고른다. 그래도 하나로 못 가리거나 못 찾으면 오류다 (사용자 결정 2026-11-08)
_sv_name=collections.defaultdict(list);_sv_last=collections.defaultdict(list)
for x in names:
    if x['entity_type']=='node' and x['lang']=='ja' and x.get('valid_to') and x['valid_to']!='ongoing':_sv_last[(x['id'],x.get('line'))].append(x['valid_to'])
for x in names:
    if x['entity_type']=='node' and x['lang']=='ja':
        vf_=x.get('valid_from')
        # 날짜 없는 지금 이름은 옛 이름이 끝난 날부터다 (東和歌山 → 和歌山)
        if vf_ is None and not x.get('valid_to'):
            prev_=_sv_last.get((x['id'],x.get('line'))) or (_sv_last.get((x['id'],None)) if x.get('line') else None)
            if prev_:vf_=max(prev_,key=lambda v:lohi(v)[1])
        _sv_name[x['text']].append((x['id'],vf_,x.get('valid_to'),x.get('line'),False))
# 별칭(옛 표제 등)으로도 찾지만 기간은 모르는 것으로 본다
for x in aliases:
    if x['entity_type']=='node':_sv_name[x['text']].append((x['id'],None,None,None,True))
def _sv_over(f_,t_,lo_,hi_,strict):
    """기간 [f_, t_)가 판 [lo_, hi_)와 겹치는가. strict면 범위 날짜를 좁게 본다"""
    a_=lohi(f_)[1 if strict else 0] or '0000-01-01';b_=lohi(t_)[0 if strict else 1] or '9999-12-31'
    return a_<hi_ and b_>lo_
def _sv_named_on(r,day):
    """이름 행 r이 그날의 이름인가"""
    return (lohi(r[1])[1] or '0000-01-01')<=day<(lohi(r[2])[0] or '9999-12-31')
def _sv_pick(sid,ed_,kind,name,cands,lo_,hi_):
    """이름 name인 후보 (노드, 역 행, 노선) 중 판 기간에 그 이름으로 그 계통에 선 노드. 점수가 가장 높은 후보들을 돌려준다"""
    rows=_sv_name.get(name,[])
    def score(c):
        n_,rs_,line=c
        nm=[r for r in rows if r[0]==n_ and not r[4] and (r[3] is None or r[3]==line)]
        return (any(_sv_over(r[1],r[2],lo_,hi_,True) for r in nm),any(_sv_over(x['valid_from'],x['valid_to'],lo_,hi_,True) for x in rs_),
                any(_sv_over(r[1],r[2],lo_,hi_,False) for r in nm),any(_sv_over(x['valid_from'],x['valid_to'],lo_,hi_,False) for x in rs_))
    # 판 기간 전체가 넓어(시작 모름 등) 둘 다 그 이름이던 때가 있으면 판 마지막 날(지금 판이면 기준일)의 이름으로 가린다
    import datetime as _dt
    end_=TODAY if hi_>=TODAY else (_dt.date.fromisoformat(hi_)-_dt.timedelta(days=1)).isoformat()
    def score(c,_base=score):
        n_,_,line=c
        return _base(c)+(any(_sv_named_on(r,end_) for r in rows if r[0]==n_ and not r[4] and (r[3] is None or r[3]==line)),)
    have={r[0] for r in rows}
    cs=[c for c in cands if c[0] in have]
    if not cs:
        err('service_name_missing',(sid,ed_.get('valid'),kind,name));return []
    top=max(score(c) for c in cs)
    return [c for c in cs if score(c)==top]
def _sv_rows(rid):
    """계통의 역 행을 노드별로 묶어 순번 순서로. 기간이 다른 같은 노드는 한 후보다"""
    out={}
    for x in by_route.get(rid,[]):
        if x.get('is_extension'):continue
        out.setdefault(x['node_id'],[x['seq'],[]])[1].append(x)
    return sorted(((n_,v[1],v[0]) for n_,v in out.items()),key=lambda z:z[2])
def _sv_grp(n_):
    """같은 역 묶음(group)의 노드는 한 역이다. 부분이 그 안의 다른 노드로 넘어가도 이어지고, 같은 이름 노드가 그 안에 여럿이어도 앞의 것을 쓴다 (長崎 住吉: 赤迫支線 끝과 本線 시작)"""
    return nodes[n_].get('group') or n_ if n_ in nodes else n_
def _sv_resolve(s_,ei_,ed_):
    """이름으로 적힌 판을 노드로 바꾼다. 경로(부분별 역 순서)도 돌려준다"""
    lo_,hi_=lohi(ed_['valid'][0])[0] or '0000-01-01',lohi(ed_['valid'][1] or 'ongoing')[1]
    parts_=[];path=[]
    for p_ in ed_['parts']:
        rid=p_.get('route')
        if rid not in routes:err('service_route_missing',(s_['id'],ed_['valid'],rid));continue
        line=routes[rid]['line'];R=_sv_rows(rid)
        if 'a' in p_:
            ends=[]
            for k_ in ('a','b'):
                got=_sv_pick(s_['id'],ed_,'parts',p_[k_],[(n_,rs_,line) for n_,rs_,_ in R],lo_,hi_)
                if len({_sv_grp(g[0]) for g in got})>1:err('service_name_ambiguous',(s_['id'],ed_['valid'],'parts',p_[k_],sorted({g[0] for g in got})))
                ends.append(got[0][0] if got else None)
            if None in ends:continue
            q_={'route':rid,'from':ends[0],'to':ends[1]}
        else:q_=dict(p_)
        parts_.append(q_)
        seqs={n_:sq_ for n_,_,sq_ in R}
        if routes[rid].get('closed') or q_['from'] not in seqs or q_['to'] not in seqs:seg=[(n_,rs_) for n_,rs_,_ in R]
        else:
            i_,j_=seqs[q_['from']],seqs[q_['to']]
            seg=[(n_,rs_) for n_,rs_,sq_ in R if min(i_,j_)<=sq_<=max(i_,j_)]
            if i_>j_:seg=seg[::-1]
        path+=[(n_,rs_,line) for n_,rs_ in seg]
    stops_=ed_.get('stops')
    if ed_.get('stops_ja') is not None:
        stops_=[];cur=0
        names_=ed_['stops_ja']
        for k_,nm_ in enumerate(names_):
            got=_sv_pick(s_['id'],ed_,'stops',nm_,path,lo_,hi_)
            best={g[0] for g in got}
            if not best:continue
            # 경로 순서로 앞 정차역 뒤에서 찾는다. 다음 정차역 이름이 나오기 전에 서로 다른 노드가 둘 이상이면 못 가린 것이다
            nxt={r[0] for r in _sv_name.get(names_[k_+1],[])} if k_+1<len(names_) else set()
            end=next((i_ for i_ in range(cur,len(path)) if path[i_][0] in nxt and path[i_][0] not in best),len(path))
            win=[i_ for i_ in range(cur,end) if path[i_][0] in best]
            if len({_sv_grp(path[i_][0]) for i_ in win})>1:err('service_name_ambiguous',(s_['id'],ed_['valid'],'stops',nm_,sorted({path[i_][0] for i_ in win})))
            at=win[0] if win else next((i_ for i_ in range(cur,len(path)) if path[i_][0] in best),None)
            if at is None:at=next((i_ for i_ in range(len(path)) if path[i_][0] in best),None)
            if at is None:continue
            stops_.append(path[at][0]);cur=at+1
    return parts_,{n_ for n_,_,_ in path},stops_
_sv_ed=[];_sv_part=[];_sv_stop=[]
for s_ in services:
    for e0_,e1_ in zip(s_['editions'],s_['editions'][1:]):
        if (lohi(e1_['valid'][0])[0] or '')<(lohi(e0_['valid'][1] or 'ongoing')[0] or ''):err('service_edition_overlap',(s_['id'],e0_['valid'],e1_['valid']))
    for ei_,ed_ in enumerate(s_['editions']):
        f_,to_=ed_.get('valid') or [None,'ongoing']
        ed_['valid']=[f_,to_ or 'ongoing']
        _sv_ed.append((s_['id'],ei_)+per(0,f_)+per(0,to_ or 'ongoing')+(int(ed_.get('stops') is None and ed_.get('stops_ja') is None),))
        parts_,on_,stops_=_sv_resolve(s_,ei_,ed_)
        for i_,p_ in enumerate(parts_):_sv_part.append((s_['id'],ei_,i_,p_.get('route'),p_.get('from'),p_.get('to')))
        # 부분이 이어지지 않으면 한 줄로 그릴 수 없다
        for p0_,p1_ in zip(parts_,parts_[1:]):
            if _sv_grp(p0_['to'])!=_sv_grp(p1_['from']):err('service_part_gap',(s_['id'],ed_['valid'],p0_['route'],p0_['to'],p1_['route'],p1_['from']))
        q_=0
        for n_ in stops_ or []:
            if n_ not in on_:
                if (s_['id'],ei_,n_) not in _svc_split_extra:err('service_stop_off_path',(s_['id'],f_,n_))
                continue
            _sv_stop.append((s_['id'],ei_,q_,n_));q_+=1
# service의 기간은 첫 판의 시작부터 마지막 판의 끝까지다. 판별 기간은 service_edition에 있다
t('service',['id primary key','closed','valid_from','valid_to'],[(s['id'],int(bool(s.get('closed'))),(s['editions'][0].get('valid') or [None])[0] if s['editions'] else None,((s['editions'][-1].get('valid') or [None,None])[1] or 'ongoing') if s['editions'] else 'ongoing') for s in services])
# all_stops=1이면 정차역을 적지 않은 판이라 경로의 모든 역에 선다
t('service_edition',['service_id','edition','valid_from','valid_from_lo','valid_from_hi','valid_to','valid_to_lo','valid_to_hi','all_stops'],_sv_ed)
t('service_part',['service_id','edition','seq','route_id','from_node','to_node'],_sv_part)
t('service_stop',['service_id','edition','seq','node_id'],_sv_stop)
# legal_abolition: 휴지로 끝난 열람 전용의 법적 폐지일(closed는 휴지 시작, 결정 128). 앱은 아직 읽지 않는다
# archive_line_id·seq: 열람 전용 노선(기록 노선이 없는 옛 노선)에 단 역. 계통이 없어 route_id는 비고, 그 열람 전용 노선의 역 순서(seq)와
# 앞뒤 역(after·before: 노드나 같은 노선의 다른 열람 전용 역)을 둔다 (宮の陣–日吉町, 결정 133). 앱은 아직 읽지 않는다
# 열람 전용 역은 그 역이 닫힌 날 그 자리를 맡던 노선(시대 노선)의 계통에 단다 (3회차 chubu_1-016, 9회차 S). 국철·JR 시대에 닫힌 역이 이관 뒤 노선
# (ハピラインふくい線 越前下関 1938–1940 → 北陸本線)에만 붙어 있으면, 앞뒤 역에 닿는 그 계통 칸의 그날 소속 노선을 보고 그 노선에서 앞뒤 역을 함께 가진 계통으로 옮긴다.
# km는 옮긴 계통의 축으로 바꾼다(앞 역 km 차를 그대로 더함). 닫힌 날을 모르거나 그날 소속이 같은 노선이면 그대로 둔다
_ERA_ARCH=[]
_skm=collections.defaultdict(dict)
for s in stops:
    if s['km_cum'] is not None and not s.get('is_extension'):_skm[s['route_id']].setdefault(s['node_id'],s['km_cum'])
for a in archive:
    if a.get('kind')!='stop' or a.get('archive_line') or not a.get('route') or a['route'] not in routes:continue
    d_=lohi(a.get('closed') or '')[0] if a.get('closed') else None
    if not d_:continue
    # 닫히기 전날 그 자리
    nb_=[x for x in (a.get('after'),a.get('before')) if x and x in nodes]
    if not nb_:continue
    es_=[e for e in route_edges.get(a['route'],[]) if e['a'] in nb_ or e['b'] in nb_]
    ls_={b['line_id'] for e in es_ for b in _ATTR_OF.get(e['id'],[]) if (lohi(b['valid_from'])[0] or '0000')<d_<=(lohi(b['valid_to'])[1] if b['valid_to'] not in (None,'ongoing') else '9999-12-31')}
    if not ls_ or a['line'] in ls_ or len(ls_)!=1:continue
    l2_=next(iter(ls_))
    cand_=[q for q,r_ in routes.items() if r_['line']==l2_ and all(x in _skm[q] for x in nb_)]
    if not cand_:continue
    q_=max(cand_,key=lambda q:routes[q].get('role')=='main')
    km2_=a.get('km')
    if km2_ is not None:
        R0_,Q0_=_skm[a['route']],_skm[q_]
        ref_=next((x for x in nb_ if x in R0_ and x in Q0_),None)
        if ref_ is None:km2_=None
        else:
            # 두 계통의 km 방향(앞뒤 역이 둘 다 있으면 그 차의 부호로 맞춘다)
            sg_=1
            if len(nb_)==2 and all(x in R0_ and x in Q0_ for x in nb_):
                dr_=R0_[nb_[1]]-R0_[nb_[0]];dq_=Q0_[nb_[1]]-Q0_[nb_[0]]
                sg_=1 if dr_*dq_>=0 else -1
            km2_=dround(Q0_[ref_]+(km2_-R0_[ref_])*sg_)
    _ERA_ARCH.append((a['id'],a['route'],q_,a.get('km'),km2_))
    a.update(line=l2_,route=q_,km=km2_)
WARN['archive_era_route']=_ERA_ARCH
print('열람 전용 역을 시대 노선 계통으로',len(_ERA_ARCH),_ERA_ARCH[:8])
_archl={a['id'] for a in archive if a.get('kind')=='line'}
for a in archive:
    if a.get('kind')=='stop' and a.get('archive_line') and a['archive_line'] not in _archl:err('archive_stop_line_unknown',(a['id'],a['archive_line']))
# 같은 계통·같은 이름·같은 km의 열람 전용 역은 한 역이다(N05·위키 두 원천이 같은 역을 따로 낸 꼴: 竹鼻線 東須賀·門間, 各務原線 安良田). 먼저 나온 행을 남기고 나머지는 빼며 옛 ID는 id_redirect로 잇는다 (3회차 chubu_3-02·chubu_2-23⑤, 8회차 W1b)
_anm={x['id']:x['text'] for x in names if x['entity_type']=='archive' and x['lang']=='ja' and not x.get('line') and not x.get('valid_from') and not x.get('valid_to')}
_akeep={};_adrop={}
for a in archive:
    if a.get('kind')!='stop' or a.get('archive_line'):continue
    k_=(arch_route(a),_anm.get(a['id']),a.get('km'))
    if not k_[0] or not k_[1] or k_[2] is None:continue
    if k_ in _akeep:
        b_=_akeep[k_];_adrop[a['id']]=b_['id']
        for f_ in ('opened','closed','legal_abolition','source'):
            if not b_.get(f_) and a.get(f_):b_[f_]=a[f_]
    else:_akeep[k_]=a
archive=[a for a in archive if a['id'] not in _adrop]
names=[x for x in names if not (x['entity_type']=='archive' and x['id'] in _adrop)]
ARCH_REDIRECT=sorted(_adrop.items())
WARN['archive_stop_dup']=ARCH_REDIRECT
print('같은 열람 전용 역 합침',len(ARCH_REDIRECT))
# archive_stop.seq는 두 뜻이다. 둘은 route_id가 있는지로 갈려 섞이지 않는다 (DESIGN §4.5 표).
#  ① 열람 전용 노선의 역(archive_line_id 있음, route_id 없음): 그 열람 전용 노선 안의 역 순서. 손 표(archive_fix seq) 값 그대로다.
#  ② 계통 위 열람 전용 역(route_id 있음): 그 계통 진행 방향의 순번(1부터, 계통마다 따로). 앱은 같은 자리(두 정차 사이·첫 역 앞·끝 역 뒤)의 역을 이 순서로 놓는다.
#     자리는 앞 역(after)의 계통 순번 뒤, 앞 역이 계통에 없으면 뒤 역(before) 앞, 앞뒤가 다른 열람 전용 역이면 그 역 자리, 둘 다 없으면 km로 찾는다(앱 _place와 같다).
#     같은 자리 안에서는 1순위 둘 다 km가 있으면 km, 2순위 같은 노선 노선도의 행 순서(gen_extra wiki_row, 앞 역 쪽이 작다), 앞뒤가 서로를 가리키면 그 순서, 그 밖은 지금 행 순서(안정)다
#     (2026-11-17 志度線 瓦町 앞 公園前·中野町·藤塚·東田町이 위키 행·손 행 따로 쌓여 노선도와 다른 순서로 보이던 것)
def _aseq_cmp(x,y):
    if x.get('before')==y['id'] or y.get('after')==x['id']:return -1
    if y.get('before')==x['id'] or x.get('after')==y['id']:return 1
    if x.get('km') is not None and y.get('km') is not None and x['km']!=y['km']:return -1 if x['km']<y['km'] else 1
    wx,wy=x.get('wiki_row'),y.get('wiki_row')
    if wx and wy and wx[0]==wy[0] and wx[1]!=wy[1]:return -1 if wx[1]<wy[1] else 1
    return 0
_abyr=collections.defaultdict(list)
for a in archive:
    if a.get('kind')=='stop' and not a.get('archive_line') and arch_route(a):_abyr[arch_route(a)].append(a)
_ASEQ_CONFLICT=[]
for rid_,L_ in _abyr.items():
    R_=[x for x in by_route.get(rid_,[]) if not x.get('is_extension')]
    _last={x['node_id']:i for i,x in enumerate(R_)};_first={}
    for i,x in enumerate(R_):_first.setdefault(x['node_id'],i)
    _byid={a['id']:a for a in L_};_slot={}
    def _sl(a,depth=0):
        if a['id'] in _slot:return _slot[a['id']]
        v=None
        if a.get('after') in _last:v=2*_last[a['after']]+1
        elif a.get('before') in _first:v=2*_first[a['before']]-1
        elif depth<20 and (a.get('after') in _byid or a.get('before') in _byid):v=_sl(_byid.get(a.get('after')) or _byid[a['before']],depth+1)
        elif a.get('km') is not None:
            j_=max((i for i,x in enumerate(R_) if x['km_cum'] is not None and x['km_cum']<=a['km']),default=None)
            v=2*j_+1 if j_ is not None else -1
        _slot[a['id']]=v if v is not None else 2*len(R_)+1
        return _slot[a['id']]
    G_=collections.defaultdict(list)
    for a in L_:G_[_sl(a)].append(a)
    n_=0
    for k_ in sorted(G_):
        o_=[]
        for a in G_[k_]:
            # 뒤에 와야 할 첫 역 앞에 끼운다. 순서를 정할 단서가 없는 역끼리는 지금 순서를 지킨다
            j_=next((j for j,b in enumerate(o_) if _aseq_cmp(a,b)<0),len(o_))
            if any(_aseq_cmp(a,b)>0 for b in o_[j_:]):_ASEQ_CONFLICT.append((rid_,a['id']))
            o_.insert(j_,a)
        for a in o_:n_+=1;a['seq']=n_
WARN['archive_seq_conflict']=_ASEQ_CONFLICT
print('계통 위 열람 전용 역 순번',sum(len(v) for v in _abyr.values()),'순서 단서 엇갈림',len(_ASEQ_CONFLICT),_ASEQ_CONFLICT[:6])
t('archive_stop',['id primary key','line_id','route_id','after_id','before_id','opened','closed','km','source','legal_abolition','archive_line_id','seq'],[(a['id'],a.get('line'),None if a.get('archive_line') else arch_route(a),a.get('after'),a.get('before'),a.get('opened'),a.get('closed'),a.get('km'),a.get('source'),a.get('legal_abolition'),a.get('archive_line'),a.get('seq')) for a in archive if a.get('kind')=='stop'])
# 동결 전 공개 ID 개명·합친 노드의 옛 ID (data/overrides/id_rename.json, 2회차 결정 U12). 새 ID가 이 판에 없거나 옛 ID가 아직 있으면 행이 틀린 것이다
_IDR=[]
for _r in json.load(open(os.path.join(ROOT,'data','overrides','id_rename.json'),encoding='utf-8'))['rows']:
    if _r['kind']=='key':continue
    _et={'n':'node','l':'line','r':'route','a':'archive_stop'}[_r['old'][0]];_tb={'node':nodes,'line':lines,'route':routes,'archive_stop':{a['id'] for a in archive if a.get('kind')=='stop'}}[_et]
    if _r['new'] not in _tb or _r['old'] in _tb:
        if not _nopatch:err('id_rename_bad',_r)
        continue
    _IDR.append((_et,_r['old'],None,json.dumps([_r['new']]),AS_OF))
_IDR+=[('archive_stop',o_,None,json.dumps([n_]),AS_OF) for o_,n_ in ARCH_REDIRECT]
# 기준일 전 정차만 있던 노드 → 그 자리 열람 전용 역 (9회차 S). 같은 노드가 여러 계통의 열람 전용이 되면 모두 잇는다
_r50=collections.defaultdict(list)
for n_,a_ in _PRE50_RED:_r50[n_].append(_adrop.get(a_,a_))
_IDR+=[('node',n_,None,json.dumps(v_),AS_OF) for n_,v_ in sorted(_r50.items())]
t('id_redirect',['entity_type','old_id','context_line','new_ids','dataset_version'],_IDR)
t('archive_line',['id primary key','line_id','at_node','opened','closed','source','legal_abolition'],[(a['id'],a.get('line'),a.get('at'),a.get('opened'),a.get('closed'),a.get('source'),a.get('legal_abolition')) for a in archive if a.get('kind')=='line'])
t('denominator',['scope','basis','carryover','km','unit_count'],[(d['scope'],d['basis'],d['carryover'],d['km'],d['unit_count']) for d in denom])
t('denominator_unit',['n','unit_key','carryover','edge_id','km','m','class','valid_from','valid_to','date_lo','date_hi','certainty'],[(i+1,u['unit_key'],u['carryover'],u['edge_id'],u['km'],round(u['km']*1000),u['cls'],u['valid_from'],u['valid_to'],lohi(u['valid_from'])[0],lohi(u['valid_to'])[1],'unknown' if not u['valid_from'] or not u['valid_to'] else 'certain') for i,u in enumerate(unit_rows)])
# 파생: 폐지 구간, 도도부현별 km, 수록 등급
closed_rows=[]
closed_life=collections.defaultdict(list)
for r in life:
    if r['close_reason']:closed_life[r['edge_id']].append(r)
last={}
for a in attr:
    k=(a['lineage_id'],a['edge_id'])
    if k not in last or (lohi(a['valid_to'])[1] or '')>(lohi(last[k]['valid_to'])[1] or ''):last[k]=a
for a in last.values():
    if a['valid_to']!='ongoing':
        e=edges[a['edge_id']];lf=closed_life.get(e['id'],[])
        ab=(lf[-1]['legal_abolition'] if lf else None) or a['valid_to'];ls=lf[-1]['last_service'] if lf else None
        closed_rows.append((a['line_id'],e['a'],e['b'],kms.get(e['id'],0),ab,ls,int(e['id'] in DRAWN)))
t('closed_section',['line_id','from_node','to_node','km','abolished','last_service','map_visible'],closed_rows)
# 위치 미확인 표식 (DESIGN §7.3). 모르는 곳에 선을 긋지 않고, 마지막 확인 역에서 그쪽 방향만 알린다
def _bearing(a,b):
    la,lo=math.radians(a[0]),math.radians(a[1]);lb,lp=math.radians(b[0]),math.radians(b[1])
    y=math.sin(lp-lo)*math.cos(lb);x=math.cos(la)*math.sin(lb)-math.sin(la)*math.cos(lb)*math.cos(lp-lo)
    return round(math.degrees(math.atan2(y,x))%360,1)
_at={p['node']:(p['lat'],p['lon']) for p in positions if p.get('lat') is not None and p.get('quality')!='none'}
_runs=collections.defaultdict(list)
for a in last.values():
    if a['valid_to']=='ongoing':continue
    # 숨은 화물선은 지도 표식(위치 미확인)을 내지 않는다. 앱 어디에도 보이지 않는다 (9회차 F)
    if a.get('denominator_class')=='hidden':continue
    e=edges[a['edge_id']]
    if e['id'] in DRAWN:continue
    _runs[a['line_id']].append(e)
_touch=collections.defaultdict(list)
for g in GEO_ALL.values():
    e=edges.get(g['edge'])
    if not e or not g.get('coords'):continue
    c=g['coords']
    # 선로의 마지막 진행 방향. 좌표는 [경도, 위도]다
    _touch[e['a']].append(((c[min(3,len(c)-1)][1],c[min(3,len(c)-1)][0]),(c[0][1],c[0][0])))
    _touch[e['b']].append(((c[max(-4,-len(c))][1],c[max(-4,-len(c))][0]),(c[-1][1],c[-1][0])))
marker_rows=[]
closed_lines=set()
for line,items in sorted(_runs.items()):
    # 이어진 구간끼리 묶는다
    left=list(items)
    while left:
        run=[left.pop()];nodes_in={run[0]['a'],run[0]['b']}
        grown=True
        while grown:
            grown=False
            for e in list(left):
                if e['a'] in nodes_in or e['b'] in nodes_in:
                    run.append(e);left.remove(e);nodes_in|={e['a'],e['b']};grown=True
        anchors=sorted(n for n in nodes_in if n in _touch and n in _at)
        ends=[r for r in closed_rows if r[0]==line and any(r[1]==e['a'] and r[2]==e['b'] for e in run)]
        for n in anchors:
            first=[e for e in run if n in (e['a'],e['b'])][0]
            other=first['b'] if first['a']==n else first['a']
            if other in _at:bearing=_bearing(_at[n],_at[other])
            else:
                back,tip=_touch[n][0]
                bearing=_bearing(back,tip)
            # 반대쪽 확인 역이 있으면 그 역이고, 없으면 구간의 끝 역이다
            degree=collections.Counter(x for e in run for x in (e['a'],e['b']))
            far=max(nodes_in-{n},key=lambda x:(x in anchors,degree[x]==1,x))
            km=dround(sum(kms.get(e['id'],0) for e in run))
            ab=max((r[4] or '' for r in ends),default='') or None
            marker_rows.append((len(marker_rows)+1,n,bearing,line,far,km,ab,json.dumps(sorted(int(e['id'][2:]) for e in run))))
t('map_marker',['id integer primary key','anchor_node','bearing','line_id','to_node','km','abolished','edges'],marker_rows)
# 도도부현 경계를 넘는 구간은 선형을 경계(N03을 줄인 data/base/pref.geojson)로 잘라 km를 나눈다 (DESIGN §2.8 K).
# 선형이 없거나 한쪽 현에만 떨어지면 양 끝 역의 현에 반씩 두고 approx로 둔다. OSM 선형은 master에 넣지 않으므로 쓰지 않는다
_PREF={}
for _f in json.load(open(os.path.join(ROOT,'data','base','pref.geojson'),encoding='utf-8'))['features']:
    _polys=[];_g=_f['geometry']
    for _poly in (_g['coordinates'] if _g['type']=='MultiPolygon' else [_g['coordinates']]):
        _xs=[x for r in _poly for x,_ in r];_ys=[y for r in _poly for _,y in r]
        _polys.append(((min(_xs),min(_ys),max(_xs),max(_ys)),_poly))
    _PREF[str(_f['properties']['pref'])]=_polys
def _inside(pt,pref):
    x,y=pt;hit=False
    for (x0,y0,x1,y1),poly in _PREF.get(pref,()):
        if not(x0<=x<=x1 and y0<=y<=y1):continue
        for ring in poly:
            inr=False
            for (ax,ay),(bx,by) in zip(ring,ring[1:]+ring[:1]):
                if (ay>y)!=(by>y) and x<(bx-ax)*(y-ay)/(by-ay)+ax:inr=not inr
            if inr:hit=not hit
    return hit
def _split(coords,a,b):
    """선형 위 길이를 현 a·b로 나눈 비율. 어느 쪽에도 안 드는 점(바다·호수)은 앞 점의 현을 따른다"""
    la=lb=0.0;last=None
    for (x0,y0),(x1,y1) in zip(coords,coords[1:]):
        d=math.hypot((x1-x0)*math.cos(math.radians((y0+y1)/2))*111.32,(y1-y0)*110.57)
        n=max(1,int(d/0.05))
        for i in range(n):
            t_=(i+0.5)/n;pt=(x0+(x1-x0)*t_,y0+(y1-y0)*t_)
            w=a if _inside(pt,a) else b if _inside(pt,b) else last
            if w==a:la+=d/n
            elif w==b:lb+=d/n
            last=w or last
    return la,lb
_geo={g['edge']:g['coords'] for g in load_geo()}
pr=[];pref_split=collections.Counter()
for e in edges.values():
    a,b=nodes[e['a']].get('pref'),nodes[e['b']].get('pref');k=kms.get(e['id'],0)
    if a and b and a!=b:
        la,lb=_split(_geo[e['id']],a,b) if e['id'] in _geo else (0,0)
        if la>0 and lb>0:
            ka=round(k*la/(la+lb),2);pr+=[(e['id'],a,ka,0),(e['id'],b,round(k-ka,2),0)];pref_split['선형']+=1
        else:
            pr+=[(e['id'],a,round(k/2,2),1),(e['id'],b,round(k-round(k/2,2),2),1)];pref_split['반씩']+=1
    elif a or b:pr.append((e['id'],a or b,k,0))
t('edge_pref',['edge_id','pref','km','approx'],pr)
# 지도의 탑승 오버레이용 선형. encoded polyline, 소수 5자리
def _enc(v):
    v=~(v<<1) if v<0 else v<<1
    o=[]
    while v>=0x20:
        o.append(chr((0x20|(v&0x1f))+63));v>>=5
    o.append(chr(v+63));return ''.join(o)
def polyline(c):
    a0=b0=0;o=[]
    for lon,lat in c:
        a,b=round(lat*1e5),round(lon*1e5);o.append(_enc(a-a0)+_enc(b-b0));a0,b0=a,b
    return ''.join(o)
t('edge_shape',['edge_id primary key','polyline'],[(g['edge'],polyline(g['coords'])) for g in load_geo()])
cov=[]
for l in lines:
    rs=[r for r in routes.values() if r['line']==l]
    cc=[coverage_of(r['id']) for r in rs]
    grade='지도 표시' if cc and all(x=='full' for x in cc) else '기록 가능'
    cov.append((l,grade,json.dumps(cc)))
t('coverage',['line_id','grade','routes'],cov)
# 역 이전: 선로 위 km가 바뀐 역의 옛·새 노드 (DESIGN §2.2, §14.1)
t('node_move',['old_node','new_node','moved_on'],[(mv['old'],mv['new'],mv['date']) for mv in json.load(open(os.path.join(ROOT,'data','overrides','moved.json'),encoding='utf-8'))])
# 나뉜 역(split_period.json): 나뉘기 전 [valid_from, valid_to) 동안 node_b의 정차는 node_a다. edge_id는 그 노선 선로에 넣은 같은 km 점(0 km) 칸.
# 감사·불변식이 이 칸의 0 km를 허용하고, 앱 재해석이 그 기간 node_b로 저장된 기록을 node_a로 읽을 때 쓴다 (11회차 S1)
_ssr=[]
for i_,x_ in enumerate(_SPLITP):
    if x_.get('normal') or x_['a'] not in nodes or x_['b'] not in nodes:continue
    es_=[k_ for k_,v_ in SPLITP_EDGE.items() if v_[0]==i_] or [None]
    for e_ in es_:_ssr.append((x_['a'],x_['b'],x_.get('from'),x_['to'],e_,x_.get('src')))
t('station_split',['node_a','node_b','valid_from','valid_to','edge_id','source'],_ssr)
# ---- 재설계 1단계 표 (docs/redesign.md §2.1) ----
# 지금 값에서 옮겨 온 첫 판이고 근거는 다음 단계(N05 후보, 선로 연결, 정차 기간)에서 바꾼다. 앱은 아직 읽지 않는다
t('pack_meta',['key primary key','value'],[('edition',EDITION),('as_of',AS_OF),('floor_date','1950-01-01')])
def _span(rows,f='valid_from',u='valid_to'):
    """행들의 가장 이른 시작 원문과 가장 늦은 끝 원문"""
    a_=min(rows,key=lambda r:lohi(r[f])[0]);b_=max(rows,key=lambda r:lohi(r[u])[1])
    return a_[f],b_[u]
_life_of=collections.defaultdict(list)
for r in life:_life_of[r['edge_id']].append(r)
# 구간 km: 노선 칸이 비면 그 구간의 기본 km, 노선이 있으면 그 노선 시대의 km (3섹 전환 전 국철 km 등)
_kmp=[]
for e_,rs_ in sorted(_life_of.items()):
    if e_ not in kms:continue
    f_,u_=_span(rs_)
    # 기간 km가 있으면 지금 km 행은 마지막 바뀐 날부터다 (9회차 S)
    if KMPER.get(e_):
        for l_,pf_,pu_,v_ in sorted(KMPER[e_],key=lambda z:z[2]):_kmp.append((e_,l_)+per(0,pf_ or f_)[:2]+(pu_,lohi(pu_)[1],round(v_*1000),'km_era_period'))
        f_=max(z[2] for z in KMPER[e_])
    _kmp.append((e_,None)+per(0,f_)[:2]+(u_,lohi(u_)[1],round(kms[e_]*1000),'edge_km'))
for (l_,e_),v_ in sorted(ERA.items()):
    rs_=[a for a in _ATTR_OF[e_] if a['line_id']==l_] or _life_of[e_]
    f_,u_=_span(rs_);_kmp.append((e_,l_)+per(0,f_)[:2]+(u_,lohi(u_)[1],round(v_*1000),'km_era'))
t('edge_km_period',['edge_id','line_id','valid_from','valid_from_lo','valid_to','valid_to_hi','m','source'],_kmp)
# 정차 기간: 정차 행의 기간에서 서지 않던 기간(route_stop_gap)을 뺀 토막들
_gaps_of=collections.defaultdict(list)
for s_,a_,b_ in stop_gaps:_gaps_of[(s_['route_id'],s_['seq'])].append((a_,b_))
_rsp=[]
for s_ in stops:
    if not s_['is_stop']:continue
    cuts=[s_['valid_from']]+[x for g in sorted(_gaps_of[(s_['route_id'],s_['seq'])],key=lambda g:lohi(g[0])[0]) for x in g]+[s_['valid_to']]
    for f_,u_ in zip(cuts[::2],cuts[1::2]):
        # 시작≥끝인 토막은 서는 날이 없다 (K18). 정차 시작에서 바로 서지 않은 때(운휴로 시작)가 이어지면 앞 토막은 길이 0이라 조용히 뺀다
        if f_==u_==s_['valid_from']:continue
        # 끝 없는 공백(재개 미정 정차 운휴, stop_suspended) 뒤 토막은 서는 날이 없다
        if f_=='ongoing':continue
        if u_ not in (None,'ongoing') and _p_lo(f_)>=_p_hi(u_):WARN['route_stop_period_empty'].append((s_['route_id'],s_['node_id'],f_,u_));continue
        _rsp.append((s_['route_id'],s_['seq'],s_['node_id'],'stop')+per(0,f_)+per(0,u_))
t('route_stop_period',['route_id','seq','node_id','kind','valid_from','valid_from_lo','valid_from_hi','valid_to','valid_to_lo','valid_to_hi'],_rsp)
# 환승 쌍: 위 규칙으로 채택한 쌍(HUBPAIR)과 두 역이 함께 서던 기간. 채택 쌍은 함께 선 기간이 있으므로 overlap=1.
# basis는 채택 근거(same_group, hand, same_name, ekimae, doc, near_150) 뒤에 원 묶음 출처
_hof={m:h['id'] for h in hubs for m in h['nodes']}
_hp=[]
for f_,(why_,src_) in sorted(HUBPAIR.items(),key=lambda kv:sorted(kv[0])):
    a_,b_=sorted(f_);f2_,u2_=_sp_together(a_,b_) if f_ in SPLITPAIR else _together(a_,b_)
    _hp.append((_hof[a_],a_,b_,f2_,u2_,1,json.dumps([why_]+sorted(src_),ensure_ascii=False)))
t('hub_pair',['hub_id','node_a','node_b','valid_from','valid_to','overlap','basis'],_hp)
# 물리 선로 연결: 계통 이음(route_link)의 분기·이어짐 행을 역·노선 쌍으로 모은다. 4단계에서 선형 끝점·운행 계통 근거로 바꾼다
_node_at={(s_['route_id'],s_['seq']):s_['node_id'] for s_ in stops}
_tl={}
for l_ in links:
    if l_['kind'] not in ('continue','branch'):continue
    k_=(_node_at.get((l_['route_id'],l_['seq'])),routes[l_['route_id']]['line'],l_['other_line_id'],l_['kind'])
    if None in k_:continue
    # 같은 역·노선 쌍은 가장 이른 시작과 가장 늦은 끝으로 합친다
    f_,u_,src_=_tl.get(k_,(l_['valid_from'],l_['valid_to'],l_.get('flow_source')))
    if lohi(l_['valid_from'])[0]<lohi(f_)[0]:f_=l_['valid_from']
    if lohi(l_['valid_to'])[1]>lohi(u_)[1]:u_=l_['valid_to']
    _tl[k_]=(f_,u_,src_)
# 노면전차 운행 계통표가 경계로 적은 곳은 계통 이음 행을 달 정차가 없어도(계통 끝이 확장 행인 吾妻橋線 本所吾妻橋) 물리 선로 연결이다 (3회차 kanto_1-007·kanto_1-003)
_tlk={(a_,b_,c_) for (a_,b_,c_,d_) in _tl}|{(a_,c_,b_) for (a_,b_,c_,d_) in _tl}
for j in junctions:
    if not j.get('_ts') or (j['at'],j['line'],j['other']) in _tlk:continue
    f_,u_=_jvalid(j);_tl[(j['at'],j['line'],j['other'],'branch')]=(f_,u_,'tram_systems');_tlk|={(j['at'],j['line'],j['other']),(j['at'],j['other'],j['line'])}
    WARN['track_link_tram_systems'].append((j['at'],j['line'],j['other']))
_tlr=[(a_,b_,c_,d_,f_,u_,src_) for (a_,b_,c_,d_),(f_,u_,src_) in sorted(_tl.items())]
t('track_link',['at_node','line_a','line_b','kind','valid_from','valid_to','source'],_tlr)
# 노선 이름·소속 이력 (data/overrides/line_history.json, 재설계 결정 3·4). 노선 단위는 지금 노선 그대로이고 구간의 그 시절 이름·소속·사업자를 기간 행으로 둔다.
# kind=name: 그 구간(노드가 없으면 노선 전체)의 그때 이름. kind=member: 그때 다른 노선(member_line, why의 「소속: l_…」)에 속함
LH=json.load(open(os.path.join(ROOT,'data','overrides','line_history.json'),encoding='utf-8'))
_lp=[]
for x in LH:
    if x['line'] not in lines:err('line_history_line',x['line']);continue
    for k_ in ('from_node','to_node'):
        if x.get(k_) and x[k_] not in nodes:err('line_history_node',(x['line'],x[k_]))
    # 그 시절 사업자가 DB에 없을 수 있다(東京急行電鉄 옛 이름 등). 원문 ID를 그대로 두고 경고만 한다
    if x.get('operator') and x['operator'] not in ops:WARN['line_history_operator'].append((x['line'],x['operator']))
    m_=re.match(r'소속: (l_[a-z0-9_]+)',x.get('why') or '')
    _lp.append((x['line'],x.get('from_node'),x.get('to_node'),x['kind'],x['name_ja'],x.get('kana'),x.get('operator'),m_.group(1) if m_ else None,x['valid_from'],x['valid_to'],'; '.join(x.get('evidence') or [])))
# 사업자·사명이 바뀐 노선의 시대 이름 행을 규칙으로 만든다 (2회차 결정 U10·U11·재설계 결정 3, 3회차 전수 점검 kanto_2-016·kinki_1-18·tohoku_1-014, 8회차 W1b).
# 노선 전체가 한 사업자인 기간(edge_attr)을 잇고, 지금 이름의 사업자 머리(hand_tables LINE_PREFIX의 상표 머리, 없으면 사업자 이름)를 그 시대 사업자 머리로 바꾼다.
# 국철·JR은 머리가 없다(越美南線). 바꾼 이름이 지금 이름과 같으면(阪急 상표: 京阪神急行電鉄→阪急電鉄) 행을 만들지 않는다. 손 이력 행(line_history)이 있는 기간도 만들지 않는다.
# 한국어·영어도 같은 방식(사업자 한국어·영어 머리)으로 바꾸고, 셋 중 하나라도 지금 이름에서 머리를 못 찾으면 만들지 않고 보고에 남긴다
def _era_names():
    LP_=HT.get('LINE_PREFIX',[])
    PFX={o_:(a_,b_,c_) for o_,a_,b_,c_,_ in LP_}
    JRX={'o_japanese_national_railways'}|{o_ for o_,v_ in ops.items() if v_.get('category')=='jr'}
    nm_=collections.defaultdict(dict)
    for x in names:
        if x['entity_type'] in ('operator','line') and not x.get('line') and not x.get('valid_from') and not x.get('valid_to'):nm_[(x['entity_type'],x['id'])].setdefault(x['lang'],x['text'])
    def pfx(o_,lg):
        if o_ in JRX:return ['']
        if o_ in PFX:
            v_=PFX[o_][('ja','ko','en').index(lg)]
            return [v_+(' ' if lg!='ja' and v_ else '')]
        t_=nm_[('operator',o_)].get(lg)
        if not t_:return []
        t_=re.sub(r'^株式会社|株式会社$','',t_) if lg=='ja' else t_
        return [t_] if lg=='ja' else [t_+' ',t_]
    hand=collections.defaultdict(list)
    for x in names:
        if x['entity_type']=='line' and not x.get('line') and (x.get('valid_from') or x.get('valid_to')) and x['lang']=='ja':hand[x['id']].append((lohi(x.get('valid_from'))[0] or '0000',lohi(x.get('valid_to'))[1] if x.get('valid_to') not in (None,'ongoing') else '9999-12-31'))
    for x in LH:
        if x.get('kind')=='name' and not x.get('from_node'):hand[x['line']].append((lohi(x.get('valid_from'))[0] or '0000',lohi(x.get('valid_to'))[1] if x.get('valid_to') not in (None,'ongoing') else '9999-12-31'))
    byl=collections.defaultdict(list)
    for a_ in attr:byl[a_['line_id']].append(a_)
    out=[];skip=[]
    for l_,rows_ in sorted(byl.items()):
        if len({a_['operator_id'] for a_ in rows_})<2:continue
        cuts=sorted({lohi(a_['valid_from'])[0] or '0000' for a_ in rows_}|{(lohi(a_['valid_to'])[0] if a_['valid_to'] not in (None,'ongoing') else '9999-12-31') for a_ in rows_})
        seg=[]
        for p_,q_ in zip(cuts,cuts[1:]):
            on_={a_['operator_id'] for a_ in rows_ if (lohi(a_['valid_from'])[0] or '0000')<=p_ and q_<=((lohi(a_['valid_to'])[0]) if a_['valid_to'] not in (None,'ongoing') else '9999-12-31')}
            if not on_:continue
            if len(on_)>1:seg=None;break
            o_=next(iter(on_))
            if seg and seg[-1][0]==o_ and seg[-1][2]==p_:seg[-1][2]=q_
            else:seg.append([o_,p_,q_])
        if not seg or len(seg)<2:
            if seg is None:skip.append((l_,'사업자가 함께 있는 기간'))
            continue
        cur=seg[-1][0];base={}
        for lg in ('ja','ko','en'):
            t_=nm_[('line',l_)].get(lg)
            if t_ is None:break
            b_=next((t_[len(p_):] for p_ in pfx(cur,lg) if t_.startswith(p_)),None)
            if b_ is None or not b_.strip(' '):break
            base[lg]=b_
        if len(base)<3:skip.append((l_,'지금 이름에서 사업자 머리를 못 찾음'));continue
        for o_,p_,q_ in seg[:-1]:
            if q_<=BASE_DAY:continue
            if any(a_<q_ and p_<b_ for a_,b_ in hand[l_]):continue
            row={}
            for lg in ('ja','ko','en'):
                ps_=pfx(o_,lg)
                if not ps_:break
                row[lg]=(ps_[0]+base[lg]).strip()
            if len(row)<3:skip.append((l_,o_,'사업자 이름 없음'));continue
            if row['ja']==nm_[('line',l_)]['ja']:continue
            out.append((l_,o_,p_,q_,row))
    return out,skip
BASE_DAY='1950-01-01'
_ERA,_ERA_SKIP=_era_names()
for l_,o_,p_,q_,row in _ERA:
    vf_=None if p_=='0000' else p_;vt_=None if q_=='9999-12-31' else q_
    for lg,t_ in row.items():names.append(dict(entity_type='line',id=l_,lang=lg,text=t_,kana=None,source='rule:operator_era',valid_from=vf_,valid_to=vt_))
    _lp.append((l_,None,None,'name',row['ja'],None,o_,None,vf_,vt_,'rule:operator_era (edge_attr 사업자 기간)'))
WARN['operator_era_skipped']=_ERA_SKIP
print('사업자 시대 노선 이름',len(_ERA),'못 만듦',len(_ERA_SKIP))
t('line_period',['line_id','from_node','to_node','kind','name_ja','kana','operator_id','member_line_id','valid_from','valid_to','source'],_lp)
# 노선(또는 구간)의 궤간·선로 방식 기간 (data/overrides/line_gauge.json을 gen_source가 노선 행의 gauge로 넘김, 2회차 종합 W0·K02·K04).
# 노드가 없으면 노선 전체다. 單線並列·三線軌条는 같은 구간에 행이 둘이다. 연결 판정에는 아직 쓰지 않는다
_GSYS={'rail','tram','third_rail','agt','monorail','linear','maglev','cable','rubber_guided','guideway_bus','trolley','bus'}
_lg=[]
for l in lines.values():
    for g in l.get('gauge') or []:
        if g.get('system') not in _GSYS or not (g.get('gauge') is None or isinstance(g['gauge'],int)):err('line_gauge_bad',(l['id'],g));continue
        if any(g.get(k_) and g[k_] not in nodes for k_ in ('from_node','to_node')):err('line_gauge_node',(l['id'],g.get('from_node'),g.get('to_node')));continue
        _lg.append((l['id'],g.get('from_node'),g.get('to_node'),g.get('gauge'),g['system'],g.get('valid_from'),g.get('valid_to') or 'ongoing',g.get('source')))
t('line_gauge',['line_id','from_node','to_node','gauge','system','valid_from','valid_to','source'],_lg)
db.execute('create view node_public as select * from node where id in (select node_id from route_stop where is_stop=1)')
for ix in ('route_stop(route_id,seq)','route_stop(node_id)','edge_attr(edge_id)','edge_attr(line_id)','route_link(route_id,seq)','route_edge(route_id)','route(line_id)','denominator_unit(carryover,unit_key)','edge_life(edge_id)','route_link(other_line_id)','edge_pref(edge_id)','edge_km(edge_id)','route_edge(edge_id)','node(group_id)','edge(n)','denominator_unit(n)'):
    nm='ix_'+re.sub(r'\W+','_',ix);db.execute(f'create index {nm} on {ix}')
db.commit();db.close()
# 仮乗降場·臨時駅이던 기간의 이름 (사용자 결정 2026-11-06, data/overrides/stop_status.json).
# 그 노선, 그 기간에만 쓰는 이름 행이다. 기간 안에 이름이 바뀌었으면 바뀐 날마다 나눠 그때 이름에 표시를 붙인다
MARK={'kari':{'ja':'{}仮乗降場','ko':'{} 가승강장','en':'{} (temp.)'},'rinji':{'ja':'(臨){}','ko':'(임){}','en':'{} (seasonal)'}}
# 표식 이름의 읽기는 바탕 이름 읽기에 꼬리 읽기를 붙인다(越路仮乗降場 こしじかりじょうこうじょう). 臨時駅의 「(臨)」은 표기 머리라 읽지 않는다.
# 바탕 이름 읽기가 없으면 표식 이름도 일본어 표기 그대로(ja_as_is)다 (명세 결정 6, 2회차 종합 K14)
MARK_KANA={'kari':'かりじょうこうじょう','rinji':''}
# 표식 이름 꼬리(stop_status name)의 읽기. 고정 읽기다
_MARK_FULL_KANA={'仮乗降場':'かりじょうこうじょう','臨時乗降場':'りんじじょうこうじょう','乗降場':'じょうこうじょう','仮停車場':'かりていしゃじょう','仮駅':'かりえき','臨時駅':'りんじえき'}
# 표식 행 이름(stop_status name)의 꼬리가 그때의 정식 표기다. 일본어 표기와 읽기는 꼬리를 따른다(恋路仮停車場 → 恋路臨時乗降場 → (臨)恋路, 安芸浜崎仮停車場).
# 꼬리가 없거나(〇〇駅) 臨時駅이면 표식 종류의 기본 표기(〇〇仮乗降場·(臨)〇〇)다. 한국어·영어는 출처 표기가 꼬리마다 따로 없어 표식 종류의 표기(가승강장·(임), temp.·seasonal) 그대로다
# (4회차 chugoku_shikoku_1-008·009, 11회차 S1)
_MARK_TAILS=('仮乗降場','臨時乗降場','乗降場','仮停車場','仮駅')
def _mark_tail(name_):
    m_=re.fullmatch(r'(.+?)(仮乗降場|臨時乗降場|乗降場|仮停車場|仮駅|臨時駅)',name_ or '')
    return m_.group(2) if m_ and m_.group(2) in _MARK_TAILS else None
_mark_tail_used=collections.Counter()
_ssp=os.path.join(ROOT,'data','overrides','stop_status.json')
def _pick_name(rows,line,day):
    best=None;rank=9
    for x in rows:
        dated=bool(x.get('valid_from')) or (x.get('valid_to') not in (None,'ongoing'))
        if x.get('line') and x['line']!=line:continue
        if dated:
            f=lohi(x.get('valid_from'))[0] if x.get('valid_from') else None
            u=lohi(x['valid_to'])[1] if x.get('valid_to') not in (None,'ongoing') else None
            if f and day<f:continue
            if u and day>=u:continue
        lv=(0 if dated else 1) if x.get('line') else (2 if dated else 3)
        if lv<rank:best=x;rank=lv
    return best
_marked=[];_stop_mark=[];_own_marks=[]
# 계통 한정 표식(stop_status의 route). 같은 노선의 다른 계통이 같은 노드에 서면(福知山線 본선과 尼崎港線의 尼崎) 노선 한정 행으로는 본선에도 붙는다.
# 그런 행은 노선 한정 표(name·stop_mark)에 넣지 않고 계통 한정 표(name_route·stop_mark_route)에 따로 낸다. 앱이 그 표를 읽기 전에는 화면에 나오지 않는다
_route_marked=[];_route_stop_mark=[]
_stop_lines=collections.defaultdict(list)
# 역·노선별 정차 기간의 처음 시작 원문과 마지막 끝 원문. 표식 기간은 이 안으로 자른다 (仮乗降場·臨時駅은 서는 동안만이다, 2회차 종합 K26)
_stop_span={}
for s in stops:
    if s['is_stop']:
        l_=routes[s['route_id']]['line']
        _stop_lines[s['node_id']].append((l_,lohi(s.get('valid_from'))[0] or '0000',(lohi(s.get('valid_to'))[1] if s.get('valid_to') not in (None,'ongoing') else None) or '9999'))
        _stop_lines[(s['node_id'],s['route_id'])].append((l_,lohi(s.get('valid_from'))[0] or '0000',(lohi(s.get('valid_to'))[1] if s.get('valid_to') not in (None,'ongoing') else None) or '9999'))
        for k_ in ((s['node_id'],l_),(s['node_id'],s['route_id'])):
            a_,b_=_stop_span.get(k_,(s.get('valid_from'),s.get('valid_to') or 'ongoing'))
            if (lohi(s.get('valid_from'))[0] or '0000')<(lohi(a_)[0] or '0000'):a_=s.get('valid_from')
            if _p_hi(s.get('valid_to') or 'ongoing')>_p_hi(b_):b_=s.get('valid_to') or 'ongoing'
            _stop_span[k_]=(a_,b_)
for st_ in (json.load(open(_ssp,encoding='utf-8')) if os.path.exists(_ssp) else []):
    nd_,kd_,f_,u_=st_['node'],st_['kind'],st_['from'],st_.get('to')
    # 시작을 모르는 표식은 「끝 전에는 그랬다」로 둔다 (날짜 원칙)
    if f_ and f_.startswith('XXXX'):f_=f"[..{AS_OF if u_ in (None,'ongoing') else _edge(u_,1)}]"
    # source_patch로 더한 역(井川線 大加島)은 보정을 얹지 않는 생성 중 컴파일에는 없다
    if nd_ not in nodes and _nopatch:continue
    if nd_ not in nodes or kd_ not in MARK:err('stop_status_unknown',st_);continue
    # 끝 해를 모르면 끝 없는 기간이 되어 오늘 화면에도 仮·臨이 붙는다 (재평가 ST4-01). 날짜를 넣어야 한다
    if u_ and u_[:4]=='XXXX':err('stop_status_unknown_to',st_);continue
    # line이 있으면 그 노선에서만 仮·臨이었다 (尼崎港線의 尼崎, 2회차 종합 U20). 없으면 그 기간에 서는 모든 노선이다
    ol_=st_.get('line')
    if ol_ and ol_ not in lines:
        if _nopatch:continue
        err('stop_status_line',st_);continue
    # route가 있으면 그 계통에서만 仮·臨이었다(尼崎港線 尼崎: 본역과 다른 神崎乗降場→尼崎乗降場→尼崎臨時乗降場). 노선은 그 계통의 노선이다
    ro_=st_.get('route')
    if ro_:
        if ro_ not in routes:
            if _nopatch:continue
            err('stop_status_route',st_);continue
        if ol_ and ol_!=routes[ro_]['line']:err('stop_status_route',st_);continue
        ol_=routes[ro_]['line']
    sk_=(nd_,ro_) if ro_ else nd_
    out_names_,out_marks_=(_route_marked,_route_stop_mark) if ro_ else (_marked,_stop_mark)
    mine=[x for x in names if x['entity_type']=='node' and x['id']==nd_]
    _m=re.fullmatch(r'(.+?)(仮乗降場|臨時乗降場|乗降場|仮停車場|仮駅|臨時駅)',st_.get('name') or '')
    own_=_m.group(1) if _m and not any(znorm(_m.group(1))==znorm(re.sub(r'(仮乗降場|臨時乗降場|乗降場|仮停車場|仮駅|臨時駅|駅)$','',x['text'])) for x in mine if x['lang']=='ja') else None
    if own_:_own_marks.append((nd_,st_['name']))
    lo0_=lohi(f_)[0] or '0000-01-01';hi0_=lohi(u_)[1] if u_ not in (None,'ongoing') else '9999-12-31'
    # 그 역에 서는 노선마다 둔다. 노선별 이름이 기간 이름보다 앞서므로 노선 없는 행으로는 덮이지 않는다
    # 그 기간에 이 역에 서는 노선에만 단다 (재평가 ST4-25)
    for ln_ in sorted({l for l,a,b in _stop_lines[sk_] if a<hi0_ and lo0_<b and (not ol_ or l==ol_)}):
        # 표식 기간은 그 노선(계통 한정이면 그 계통) 정차 기간 안으로 자른다. 정차 시작 전·끝 뒤의 표식은 서지 않는 때라 뜻이 없다 (2회차 종합 K26)
        sf_,su_=_stop_span[(nd_,ro_ or ln_)];f2_,u2_=f_,u_
        if f2_ is None or (lohi(f2_)[0] or '0000')<(lohi(sf_)[0] or '0000'):f2_=sf_ if sf_ else f2_
        if _p_hi(u2_ or 'ongoing')>_p_hi(su_):u2_=su_
        lo_=lohi(f2_)[0] or '0000-01-01';hi_=lohi(u2_)[1] if u2_ not in (None,'ongoing') else '9999-12-31'
        cuts=sorted({lo_,hi_}|{d for x in mine for d in ((lohi(x['valid_from'])[0] if x.get('valid_from') else None),(lohi(x['valid_to'])[1] if x.get('valid_to') not in (None,'ongoing') else None)) if d and lo_<d<hi_})
        out_marks_.append((nd_,ln_,kd_,f2_,None if u2_ in (None,'ongoing') else u2_)+((ro_,) if ro_ else ()))
        for a_,b_ in zip(cuts,cuts[1:]):
            # 일본어 이름 행을 먼저 고르고 한국어·영어는 같은 이름 행(같은 노선·기간)에서 가져온다. 언어마다 따로 고르면
            # 옛 이름 기간에 한국어·영어만 지금 이름이 된다(舟子仮乗降場 → Okawa-Dam-Koen (temp.)). 그 행이 없으면 일본어 표기 그대로 (2회차 종합 K26)
            ja_=_pick_name([x for x in mine if x['lang']=='ja'],ln_,a_)
            if not ja_:continue
            # 표식 행의 이름(stop_status name)이 그 노드 이름 이력에 없는 그때의 乗降場 이름이면(小野田港北口乗降場, 노드 지금 이름 南小野田) 그 이름이 먼저다.
            # 일본어는 적힌 이름 그대로, 한국어·영어는 바탕 이름에 표식을 붙이고 읽기가 없어 일본어 표기 그대로(ja_as_is)
            if own_:
                # 읽기는 사람이 확인한 옛 이름 읽기(old_names_kana)의 표식 이름 전체 또는 바탕 이름에서만 가져온다. 바탕 읽기 + 표식 읽기(かりじょうこうじょう)는
                # 두 쪽 모두 근거가 있는 합성이다(R 갈래 지적: 小野田港北口乗降場, 9회차 N). 없으면 일본어 표기 그대로
                _ok_=_LATE_KANA.get(nd_+'|'+st_['name']);_ob_=_LATE_KANA.get(nd_+'|'+own_)
                _ok_=_ok_ or ((_ob_+_MARK_FULL_KANA.get(st_['name'][len(own_):],'')) if _ob_ and st_['name'][len(own_):] in _MARK_FULL_KANA else None)
                for lang_,fmt_ in MARK[kd_].items():
                    if _ok_ and _ob_ and lang_!='ja':
                        os.environ['NW_OFF']='1'
                        import ko as _ko2,en_rules as _en2
                        t_=fmt_.format(_ko2.station(_ob_,own_) if lang_=='ko' else (_en2.fix_station(own_,_ob_,_en2.station_reading(_ob_,own_),{}) or _en2.station_reading(_ob_,own_)))
                        out_names_.append(dict(entity_type='node',id=nd_,lang=lang_,text=t_,kana=None,source='rule',line=ln_,valid_from=a_,valid_to=None if b_=='9999-12-31' else b_,**({'route':ro_} if ro_ else {})))
                        continue
                    out_names_.append(dict(entity_type='node',id=nd_,lang=lang_,text=st_['name'] if lang_=='ja' else fmt_.format(own_),kana=_ok_ if lang_=='ja' else None,source=('rule' if _ok_ and lang_=='ja' else 'ja_as_is'),line=ln_,valid_from=a_,valid_to=None if b_=='9999-12-31' else b_,**({'route':ro_} if ro_ else {})))
                continue
            key_=(ja_.get('line'),ja_.get('valid_from'),ja_.get('valid_to'))
            tail_=_mark_tail(st_.get('name'))
            if tail_:_mark_tail_used[tail_]+=1
            for lang_,fmt_ in MARK[kd_].items():
                if lang_=='ja' and tail_:fmt_='{}'+tail_
                if lang_=='ja':base_=ja_
                else:base_=next((x for x in mine if x['lang']==lang_ and (x.get('line'),x.get('valid_from'),x.get('valid_to'))==key_),None) or (None if (ja_.get('line') or ja_.get('valid_from') or ja_.get('valid_to') not in (None,'ongoing')) else _pick_name([x for x in mine if x['lang']==lang_],ln_,a_)) or dict(text=ja_['text'],source='ja_as_is')
                if lang_=='ja':
                    # 고른 이름 행에 읽기가 없으면 같은 노드 같은 글자 행의 읽기(같은 역 같은 이름)를 쓴다. 바탕 읽기 + 표식 읽기 합성 (R 갈래 지적: 舟子仮乗降場, 9회차 N)
                    _bk_=ja_.get('kana') or next((x.get('kana') for x in mine if x['lang']=='ja' and x['text']==ja_['text'] and x.get('kana')),None)
                    kana_=_bk_+(_MARK_FULL_KANA[tail_] if tail_ else MARK_KANA[kd_]) if _bk_ else None
                    src_='rule' if kana_ else 'ja_as_is'
                else:
                    kana_=None;src_='ja_as_is' if base_.get('source')=='ja_as_is' else 'rule'
                    # 같은 글자 행의 읽기로 일본어 읽기가 생겼으면 한국어·영어도 그 읽기로 규칙 표기한다
                    if src_=='ja_as_is' and _bk_:
                        os.environ['NW_OFF']='1'
                        import ko as _ko2,en_rules as _en2
                        _bt_=ja_['text']
                        base_=dict(text=_ko2.station(_bk_,_bt_) if lang_=='ko' else (_en2.fix_station(_bt_,_bk_,_en2.station_reading(_bk_,_bt_),{}) or _en2.station_reading(_bk_,_bt_)));src_='rule'
                out_names_.append(dict(entity_type='node',id=nd_,lang=lang_,text=fmt_.format(base_['text']),kana=kana_,source=src_,line=ln_,valid_from=a_,valid_to=None if b_=='9999-12-31' else b_,**({'route':ro_} if ro_ else {})))
names+=_marked
for b_ in BUS:
    for lang_,text_ in b_['names'].items():names.append(dict(entity_type='line',id=b_['line'],lang=lang_,text=text_,source='hand'))
print('仮乗降場·臨時駅 기간 이름',len(_marked),'계통 한정',len(_route_marked),'표식 행 이름이 먼저',_own_marks,'꼬리 표기',dict(_mark_tail_used))
# 읽기를 모르는 옛 역 이름은 한국어·영어 화면에 지금 이름과 옛 표기를 함께 보인다: 「카미키타초 (당시 沼崎)」, 「Kamikitacho (then 沼崎)」
# 추정 읽기는 쓰지 않는다 (사용자 결정 19). 읽기를 찾아 한국어·영어 옛 이름이 생기면 그 행이 대신한다 (사용자 결정 2026-11-08)
_base={(x['id'],x['lang']):x['text'] for x in names if x['entity_type']=='node' and not x.get('line') and not x.get('valid_from') and not x.get('valid_to')}
_dated={(x['id'],x['lang'],x.get('valid_to')) for x in names if x['entity_type']=='node' and not x.get('line') and x.get('valid_to')}
_then=[]
for x in names:
    if x['entity_type']!='node' or x['lang']!='ja' or x.get('line') or not x.get('valid_to') or x['valid_to']=='ongoing':continue
    for lang_,fmt_ in (('ko','{} (당시 {})'),('en','{} (then {})')):
        if (x['id'],lang_,x['valid_to']) in _dated or (x['id'],lang_) not in _base:continue
        # 옛 자리 표식 「（旧）」는 일본어라 병기에서 뗀다 (「(당시 鬼怒川温泉)」)
        _then.append(dict(entity_type='node',id=x['id'],lang=lang_,text=fmt_.format(_base[(x['id'],lang_)],x['text'].replace('（旧）','')),source='rule',valid_from=x.get('valid_from'),valid_to=x['valid_to']))
names+=_then
print('옛 표기 병기',len(_then))
# 노선 전체의 옛 이름(line_history kind=name)은 생성기(gen_source)가 data/source 이름에 넣는다
# 일본 사이트를 끝까지 뒤져도 읽기가 없는 역은 한국어·영어 화면에도 일본어 표기를 그대로 보인다 (사용자 결정 2026-11-08, redesign §4-6).
# 마지막 수단이라 출처를 ja_as_is로 남겨 읽기를 찾으면 바로 갈아 끼운다
_asis=[]
for x in names:
    if x['entity_type']!='node' or x['lang']!='ja' or x.get('line') or x.get('valid_from') or x.get('valid_to'):continue
    for lang_ in ('ko','en'):
        if (x['id'],lang_) not in _base:
            _asis.append(dict(entity_type='node',id=x['id'],lang=lang_,text=x['text'],source='ja_as_is'));_base[(x['id'],lang_)]=x['text']
names+=_asis
print('읽기 없어 일본어 표기',len(_asis))
# 노드 분리(node_split)로 끝 역이 컴파일에서 생긴 계통은 영어 이름 생성기(gen_en_names)가 못 본다. 끝 역의 지금 영어 이름으로 채운다.
# 한국어도 같다: 계통 이름은 gen_source가 만드는데, 그 뒤 단계(source_patch·node_fix)에서 한국어가 생긴 끝 역(近鉄 諏訪)은 빠진다.
# 읽기가 없어 일본어 표기 그대로(ja_as_is)인 끝 역(신호장·분기점·연결선 끝)은 쓰지 않는다. 섞인 이름(三岐朝明信号所~Nishi-Fujiwara)이 된다
_rfill=collections.Counter()
for lang_ in ('ko','en'):
    _rl={x['id'] for x in names if x['entity_type']=='route' and x['lang']==lang_}
    _nl={x['id']:x['text'] for x in names if x['entity_type']=='node' and x['lang']==lang_ and x.get('source')!='ja_as_is' and not x.get('line') and not x.get('valid_from') and not x.get('valid_to')}
    for r_ in routes.values():
        if r_['id'] in _rl or not any(x['entity_type']=='route' and x['id']==r_['id'] for x in names):continue
        a_,b_=_nl.get(r_.get('from')),_nl.get(r_.get('to'))
        if a_ and b_:names.append(dict(entity_type='route',id=r_['id'],lang=lang_,text=f'{a_}~{b_}',source='rule'));_rfill[lang_]+=1
# 그래도 이름이 없는 계통은 끝 역이 숨은 노드(신호소·분기점·연결선 갈래)다. 계통 읽기(kana_fix.json)로 양쪽을 규칙 표기한다.
# 같은 표기·같은 읽기의 공개 역 이름(나무위키·위키데이터)이 있으면 그 이름을 쓰고, 신호소·분기점 꼬리와 （○○方）·（通過） 주석은 번역한다
# 나무위키 표(data/imports)는 깨끗한 체크아웃에 없다. 빌드마다 같은 이름이 나오게 규칙 표기만 쓴다
os.environ['NW_OFF']='1'
import ko as _ko,en_rules as _en
_kf0=json.load(open(os.path.join(ROOT,'data','overrides','kana_fix.json'),encoding='utf-8'))
_jk={}
for x in names:
    if x['entity_type']=='node' and x['lang']=='ja' and x.get('kana') and not x.get('line') and not x.get('valid_from') and not x.get('valid_to'):_jk.setdefault((x['text'],x['kana']),x['id'])
_bn={(x['id'],x['lang']):x['text'] for x in names if x['entity_type']=='node' and x['lang'] in ('ko','en') and x.get('source')!='ja_as_is' and not x.get('line') and not x.get('valid_from') and not x.get('valid_to')}
_TAIL={'信号所':('しんごうじょ',' 신호소',' Signal'),'信号場':('しんごうじょう',' 신호장',' Signal'),'分岐点':('ぶんきてん',' 분기점',' Junction'),'接続点':('せつぞくてん',' 접속점',' Junction')}
def _side(lang_,j,k):
    m_=re.fullmatch(r'(.+?)（(.+)）',j);mk=re.fullmatch(r'(.+?)（(.+)）',k)
    if m_ and mk:
        b=_side(lang_,m_.group(1),mk.group(1));a,ak=m_.group(2),mk.group(2)
        if b is None:return None
        if a=='通過':return b+(' (통과)' if lang_=='ko' else ' (through)')
        if a.endswith('方') and ak.endswith('がた'):
            p=_side(lang_,a[:-1],ak[:-2]);return None if p is None else b+(f' ({p} 방면)' if lang_=='ko' else f' ({p} side)')
        p=_side(lang_,a,ak);return None if p is None else b+f' ({p})'
    if re.search('[（）()]',j+k):return None
    i_=_jk.get((j,k))
    if i_ and (i_,lang_) in _bn:return _bn[(i_,lang_)]
    for t_,(tk,tko,ten) in _TAIL.items():
        if j.endswith(t_) and k.endswith(tk) and len(j)>len(t_):
            b=_side(lang_,j[:-len(t_)],k[:-len(tk)]);return None if b is None else b+(tko if lang_=='ko' else ten)
    return _ko.station(k,j) if lang_=='ko' else _en.station_reading(k,j)
for lang_ in ('ko','en'):
    _rl={x['id'] for x in names if x['entity_type']=='route' and x['lang']==lang_}
    for x in [x for x in names if x['entity_type']=='route' and x['lang']=='ja' and not x.get('valid_from') and not x.get('valid_to')]:
        f_=_kf0.get('route:'+x['id'])
        if x['id'] in _rl or not f_ or f_['text']!=x['text'] or x['text'].count('～')!=1 or f_['kana'].count('～')!=1:continue
        s_=[_side(lang_,j,k) for j,k in zip(x['text'].split('～'),f_['kana'].split('～'))]
        if None in s_:continue
        names.append(dict(entity_type='route',id=x['id'],lang=lang_,text='~'.join(s_),source='rule'));_rl.add(x['id']);_rfill[lang_+'_kana']+=1
# 마지막 수단: 끝 역이 읽기가 없어 일본어 표기 그대로(ja_as_is)인 계통(旅館 鋼索 浦島～乙姫, 境線 米子～船着場)은 끝 역의 화면 이름 그대로 잇고 출처를 ja_as_is로 남긴다
for lang_ in ('ko','en'):
    _rl={x['id'] for x in names if x['entity_type']=='route' and x['lang']==lang_}
    _al={x['id']:x['text'] for x in names if x['entity_type']=='node' and x['lang']==lang_ and not x.get('line') and not x.get('valid_from') and not x.get('valid_to')}
    _as1={x['id'] for x in names if x['entity_type']=='node' and x['lang']==lang_ and x.get('source')=='ja_as_is' and not x.get('line') and not x.get('valid_from') and not x.get('valid_to')}
    for r_ in routes.values():
        if r_['id'] in _rl or not any(x['entity_type']=='route' and x['id']==r_['id'] for x in names):continue
        a_,b_=_al.get(r_.get('from')),_al.get(r_.get('to'))
        if a_ and b_ and (r_.get('from') in _as1 or r_.get('to') in _as1):
            names.append(dict(entity_type='route',id=r_['id'],lang=lang_,text=f'{a_}~{b_}',source='ja_as_is'));_rfill[lang_+'_asis']+=1
print('계통 한국어·영어 이름 채움',dict(_rfill))
# 노선 한정 이름은 그 노선에 서는 노드에만 뜻이 있다. 그 노선 어느 계통에도 서지 않는 노드에 붙은 노선 한정 이름(노리츠부시 표 대응이 다른 역을 묶어 생긴
# インテック本社前의 JR 富山港線 「富山口」)은 쓰이지 않고 검색에서 엉뚱한 역을 찾게 하므로 뺀다 (3회차 chubu_3-17, 감사 K90, 9회차 N)
_LSTOP={(s_['node_id'],routes[s_['route_id']]['line']) for s_ in stops if s_['is_stop'] and s_['route_id'] in routes}
_LUN=sorted({(x['id'],x['line'],x['text']) for x in names if x['entity_type']=='node' and x.get('line') and x['lang']=='ja' and (x['id'],x['line']) not in _LSTOP})
names=[x for x in names if not (x['entity_type']=='node' and x.get('line') and (x['id'],x['line']) not in _LSTOP)]
print('노선에 서지 않는 노드의 노선 한정 이름 뺌',len(_LUN),_LUN[:20])
# 끝난 노선(폐지·이관으로 노선 영업이 모두 끝남)의 역 이름은 그 노선의 마지막 날 이름이다 (DESIGN §8 입력 화면 「날짜 모름이면 지금 또는 종료 직전」, §14.2 조회 순서).
# 날짜 모름·오늘 화면은 기간 없는 노선 한정 이름 > 지금 이름 순이라, 한 계통 안에 노선 한정 옛 이름과 지금 이름이 섞이지 않게
# 그 역의 마지막 정차 날(노선 끝·정차 끝 가운데 이른 날의 전날)에 쓰던 옛 이름이 지금 이름과 다르면 기간 없는 노선 한정 이름으로 둔다(越美南線 美濃立花·美濃関, 神岡線 神岡口, 能登線 真脇, 会津線 会津高原).
# 노선 한정 이름은 기본 기간 이름보다 앞서므로(§14.2) 그대로 두면 그 노선 영업 중의 다른 옛 이름(美濃立花 전의 板取口)을 가린다. 그래서 그 노선 정차 기간에 걸친
# 다른 기간 이름은 같은 기간의 노선 한정 기간 행으로 함께 둔다(노선 고유 + 날짜가 가장 앞섬). 기간 이름이 없는 틈은 지금 이름이 그때 이름이라 그 틈도 노선 한정 기간 행으로 둔다.
# 한국어·영어는 그 기간의 기본 행(나무위키·규칙, 읽기가 없으면 「(당시 …)」 병기) 그대로 옮긴다. 읽기가 없는 옛 이름은 일본어 행을 일본어 표기 그대로(ja_as_is)로 둔다
# (3회차 chubu_1-018·chubu_2-20·tohoku_1-018, 9회차 N 설계 판단: 감사 K14는 노선 한정 기간 행으로 덮인 옛 이름을 가림으로 보지 않는다)
def _p_rng(x):
    return (lohi(x.get('valid_from'))[0] or '0000-01-01') if x.get('valid_from') else '0000-01-01',(lohi(x['valid_to'])[0] or '9999-12-31') if x.get('valid_to') not in (None,'ongoing') else '9999-12-31'
def _last_line_names():
    _lend=collections.defaultdict(list)
    for a_ in attr:_lend[a_['line_id']].append(a_['valid_to'])
    ended={l_:max(lohi(v_)[0] or '0000' for v_ in vs) for l_,vs in _lend.items() if all(v_ not in (None,'ongoing') for v_ in vs)}
    span={}
    for s_ in stops:
        if not s_['is_stop'] or s_.get('is_extension') or s_['route_id'] not in routes:continue
        l_=routes[s_['route_id']]['line']
        if l_ not in ended:continue
        f_=lohi(s_['valid_from'])[0] or '0000-01-01' if s_.get('valid_from') else '0000-01-01'
        t_=(lohi(s_['valid_to'])[0] or '9999-12-31') if s_['valid_to'] not in (None,'ongoing') else '9999-12-31'
        k_=(s_['node_id'],l_);o_=span.get(k_)
        span[k_]=(min(o_[0],f_),max(o_[1],t_)) if o_ else (f_,t_)
    have=set();cur={};per=collections.defaultdict(list)
    for x in names:
        if x['entity_type']!='node':continue
        if x.get('line'):
            if not x.get('valid_from') and not x.get('valid_to'):have.add((x['id'],x['line']))
            continue
        if not x.get('valid_from') and not x.get('valid_to'):cur.setdefault((x['id'],x['lang']),x)
        elif x.get('valid_to'):per[x['id']].append(x)
    out=[];miss=[];cp=0
    # 그 노선 계통 위에 있는 공개 노드(서는 역과 이관 뒤 새 역처럼 이 노선은 서지 않고 이어받은 노선만 서는 숨은 노드). 날짜 모름 화면에 함께 나온다
    _pub=set();_on=collections.defaultdict(set)
    for s_ in stops:
        if s_['is_stop']:_pub.add(s_['node_id'])
        if s_['route_id'] in routes and not s_.get('is_extension'):_on[routes[s_['route_id']]['line']].add(s_['node_id'])
    for (n_,l_),(f0,t0) in sorted(span.items()):
        if (n_,l_) in have or (n_,'ja') not in cur:continue
        end_=min(ended[l_],t0)
        if not re.fullmatch(r'\d{4}-\d\d-\d\d',end_):continue
        day=(_dt0.date.fromisoformat(end_)-_dt0.timedelta(days=1)).isoformat()
        pj=[x for x in per[n_] if x['lang']=='ja']
        hit=[x for x in pj if _p_rng(x)[0]<=day<_p_rng(x)[1]]
        if len(hit)!=1 or hit[0]['text']==cur[(n_,'ja')]['text']:continue
        h=hit[0];hk_=(h.get('valid_from'),h.get('valid_to'))
        # 마지막 날 이름이 같은 노선 계통의 다른 공개 노드의 지금 이름과 같으면(越美南線: JR 木尾 = 지금 母野, 이관 뒤 새 역 木尾) 날짜 모름 화면에 같은 이름 두 줄이 된다.
        # 같은 이름 두 노드는 기록 저장 노드를 이름으로 가를 수 없으므로 이 노드는 지금 이름으로 둔다. 날짜가 있으면 기간 이름(木尾 1956–1986)이 그대로 나온다 (4회차 chubu_1-007, 11회차 S1)
        col_=sorted(m_ for m_ in _on[l_] if m_!=n_ and m_ in _pub and (cur.get((m_,'ja')) or {}).get('text')==h['text'])
        if col_:_LLN_COL.append((l_,n_,h['text'],col_[0]));continue
        rows=[]
        for lg in ('ja','ko','en'):
            y=h if lg=='ja' else next((x for x in per[n_] if x['lang']==lg and (x.get('valid_from'),x.get('valid_to'))==hk_),None)
            if not y:break
            # 읽기 없는 옛 이름의 한국어·영어 병기 「지금 이름 (당시 옛 표기)」는 병기 규칙 행(출처 rule) 그대로 옮긴다
            _then_=lg!='ja' and re.search(r' \((당시|then) .+\)$',y['text'] or '')
            rows.append(dict(entity_type='node',id=n_,lang=lg,text=y['text'],kana=y.get('kana') if lg=='ja' else None,source=(y.get('source') if _then_ else 'rule:line_last_name' if lg!='ja' or y.get('kana') else 'ja_as_is'),line=l_))
        if len(rows)<3:miss.append((l_,n_,h['text']));continue
        out+=rows
        # 그 노선 정차 기간에 걸친 다른 기간 이름은 노선 한정 기간 행으로
        cov=[]
        for x in per[n_]:
            a_,b_=_p_rng(x)
            if x['lang']=='ja':cov.append((a_,b_))
            if (x.get('valid_from'),x.get('valid_to'))==hk_ or not (a_<end_ and f0<b_):continue
            out.append(dict(x,line=l_,source=(x.get('source') if x['lang']!='ja' or x.get('kana') else 'ja_as_is')));cp+=1
        # 기간 이름이 덮지 않는 틈은 지금 이름의 때다
        cov=sorted(cov);gaps=[];c_=f0
        for a_,b_ in cov:
            if a_>c_ and c_<end_:gaps.append((c_,min(a_,end_)))
            c_=max(c_,b_)
        if c_<end_:gaps.append((c_,end_))
        for a_,b_ in gaps:
            if a_<='0000-01-01' and b_<=f0:continue
            for lg in ('ja','ko','en'):
                y=cur.get((n_,lg))
                if not y:continue
                out.append(dict(entity_type='node',id=n_,lang=lg,text=y['text'],kana=y.get('kana') if lg=='ja' else None,source=(y.get('source') if lg!='ja' or y.get('kana') else 'ja_as_is'),line=l_,valid_from=None if a_<='0000-01-01' else a_,valid_to=b_));cp+=1
    return out,miss,cp
LLN_ON=True
_LLN_COL=[]
_LLN,_LLN_MISS,_LLN_CP=_last_line_names() if LLN_ON else ([],[],0)
names.extend(_LLN)
# 끝난 노선 계통의 이름(양 끝 역 이름)도 그 노선 마지막 날 이름으로 다시 잇는다 (丸岡線 本丸岡～西長田, 지금 이름 西長田ゆりの里가 아님)
# 읽기 없는 옛 이름의 병기(「(당시 …)」)는 계통 이름에 쓰지 않고 지금 이름으로 잇는다
_lln={(x['id'],x['line'],x['lang']):x['text'] for x in names if x['entity_type']=='node' and x.get('line') and not x.get('valid_from') and not x.get('valid_to') and not re.search(r' \((당시|then) .+\)$',x['text'] or '')}
_llk={(x['id'],x['line']):x.get('kana') for x in names if x['entity_type']=='node' and x.get('line') and x['lang']=='ja' and not x.get('valid_from') and not x.get('valid_to')}
_cur_n={(x['id'],x['lang']):x['text'] for x in names if x['entity_type']=='node' and not x.get('line') and not x.get('valid_from') and not x.get('valid_to')}
_cur_k={x['id']:x.get('kana') for x in names if x['entity_type']=='node' and x['lang']=='ja' and not x.get('line') and not x.get('valid_from') and not x.get('valid_to')}
_rn=0;_RRN=set()
for x in (names if LLN_ON else []):
    if x['entity_type']!='route' or x.get('valid_from') or x.get('valid_to') or x['id'] not in routes:continue
    r_=routes[x['id']];l_=r_['line'];sep='～' if x['lang']=='ja' else '~'
    a_,b_=r_.get('from'),r_.get('to')
    if (a_,l_,x['lang']) not in _lln and (b_,l_,x['lang']) not in _lln:continue
    ca,cb=_cur_n.get((a_,x['lang'])),_cur_n.get((b_,x['lang']))
    if not ca or not cb or x['text']!=f'{ca}{sep}{cb}':continue
    x['text']=f"{_lln.get((a_,l_,x['lang']),ca)}{sep}{_lln.get((b_,l_,x['lang']),cb)}";_rn+=1;_RRN.add(x['id'])
    if x['lang']=='ja':
        ka=_llk.get((a_,l_)) if (a_,l_,'ja') in _lln else _cur_k.get(a_);kb=_llk.get((b_,l_)) if (b_,l_,'ja') in _lln else _cur_k.get(b_)
        x['kana']=f'{ka}～{kb}' if ka and kb else None
print('끝난 노선 계통 이름을 마지막 날 이름으로',_rn)
# 노선·회사·계통의 읽기 (data/overrides/kana_fix.json, 위키 첫 문장의 읽기). 표시 이름이 바뀌면 읽기도 다시 봐야 하므로 멈춘다
_kf=json.load(open(os.path.join(ROOT,'data','overrides','kana_fix.json'),encoding='utf-8'))
_kh=set()
for x in names:
    k_=x['entity_type']+':'+x['id']
    if x['lang']!='ja' or k_ not in _kf:continue
    # 끝난 노선 계통 이름을 마지막 날 이름으로 다시 이은 것은 그 옛 이름들의 읽기로 이미 읽기를 정했다
    if x['entity_type']=='route' and x['id'] in _RRN:_kh.add(k_);continue
    if _kf[k_]['text']==x['text']:x['kana']=_kf[k_]['kana'];_kh.add(k_);continue
    # 사업자 머리를 붙인 노선 이름(위 머리 맞춤)은 읽기 앞에도 머리 읽기(hand_tables PREFIX_KANA)를 붙인다
    _p=x['text'][:-len(_kf[k_]['text'])] if x['entity_type']=='line' and x['text'].endswith(_kf[k_]['text']) else None
    if _p and _p in PREFIX_KANA:x['kana']=PREFIX_KANA[_p]+_kf[k_]['kana'];_kh.add(k_)
for k_ in sorted(set(_kf)-_kh):
    if not _nopatch:err('kana_fix_unused',(k_,_kf[k_]['text']))
db=sqlite3.connect(np_)
WARN['line_last_name_no_kana']=_LLN_MISS
WARN['line_last_name_collide']=_LLN_COL
print('끝난 노선 마지막 날 이름이 같은 계통 다른 역 지금 이름과 같아 지금 이름으로 둠',len(_LLN_COL),_LLN_COL[:10])
print('끝난 노선의 마지막 날 이름(노선 전용)',sum(1 for x in _LLN if x['lang']=='ja' and not x.get('valid_from') and not x.get('valid_to')),'노선 한정 기간 행',_LLN_CP,'못 만듦',len(_LLN_MISS))
WARN['line_unused_name']=_LUN
# 옛 이름 기간 행의 글자가 지금 이름과 같고 읽기도 같으면(읽기가 없으면 같은 것으로 봄) 그 기간은 이름이 바뀐 것이 아니다. 기간 행과 그 기간의 한국어·영어 병기 행을 만들지 않는다.
# 같은 글자에 읽기만 바뀐 역(苅田 かりた→かんだ, 2회차 결정 U13)은 남는다 (3회차 kyushu_1-010, 8회차 W1b)
_cur_ja={}
for x in names:
    if x['lang']=='ja' and not x.get('line') and not x.get('valid_from') and not x.get('valid_to'):_cur_ja.setdefault((x['entity_type'],x['id']),x)
_same_per=set();_kmove=[]
for x in names:
    if x['lang']!='ja' or x.get('line') or not (x.get('valid_from') or x.get('valid_to')):continue
    c_=_cur_ja.get((x['entity_type'],x['id']))
    if c_ and c_['text']==x['text'] and (not x.get('kana') or not c_.get('kana') or x['kana']==c_['kana']):
        _same_per.add((x['entity_type'],x['id'],x.get('valid_from'),x.get('valid_to')))
        # 빼는 기간 행에만 읽기가 있으면 같은 글자 지금 이름의 읽기다(같은 노드의 자기 이름). 지금 이름에 옮기고, 읽기가 없어 일본어 표기 그대로(ja_as_is)이던
        # 한국어·영어도 그 기간 행의 것으로 바꾼다 (京阪 別所 옛 자리: 1940–1967 「別所 べっしょ」 행을 빼며 지금 이름 別所가 읽기 없이 남던 것, 10회차 G1 kinki_1-08)
        if x.get('kana') and not c_.get('kana'):c_['kana']=x['kana'];_kmove.append((x['entity_type'],x['id'],x.get('valid_from'),x.get('valid_to')))
_kmv_set=set(_kmove);_kmv_alt={}
for x in names:
    if x['lang'] in ('ko','en') and not x.get('line') and (x['entity_type'],x['id'],x.get('valid_from'),x.get('valid_to')) in _kmv_set:_kmv_alt[(x['entity_type'],x['id'],x['lang'])]=x
for x in names:
    if x['lang'] in ('ko','en') and not x.get('line') and not x.get('valid_from') and not x.get('valid_to') and x.get('source')=='ja_as_is':
        y_=_kmv_alt.get((x['entity_type'],x['id'],x['lang']))
        if y_:x['text']=y_['text'];x['source']=y_.get('source') or 'rule'
print('뺀 같은 이름 기간 행의 읽기를 지금 이름으로',len(_kmove),_kmove[:10])
_n0=len(names)
names=[x for x in names if x.get('line') or (x['entity_type'],x['id'],x.get('valid_from'),x.get('valid_to')) not in _same_per]
print('지금 이름과 같은 옛 이름 기간 행 뺌',len(_same_per),'행',_n0-len(names))
REPORT_SAME_PER=sorted(_same_per,key=str)
db.execute('create table name (entity_type,entity_id,lang,text,kana,source,reading_source,source_title,checked,line_id,valid_from,valid_to)')
check_dates('name',['entity_type','entity_id','lang','text','kana','source','reading_source','source_title','checked','line_id','valid_from','valid_to'],[(x['entity_type'],x['id'],x['lang'],x['text'],x.get('kana'),x.get('source'),x.get('reading_source'),x.get('source_title'),x.get('checked'),x.get('line'),x.get('valid_from'),x.get('valid_to')) for x in names])
# 열람 전용 이름은 남은 열람 전용 행(drop·drop_stop·exclude로 뺀 것 제외)의 것만 싣는다. 뺀 ID의 이름만 남은 고아 109건(a_yomiurirando_monorail 등, 12회차 M R6)
_arch_ids={a_['id'] for a_ in archive}
db.executemany('insert into name values (?,?,?,?,?,?,?,?,?,?,?,?)',[(x['entity_type'],x['id'],x['lang'],x['text'],x.get('kana'),x.get('source'),x.get('reading_source'),x.get('source_title'),x.get('checked'),x.get('line'),x.get('valid_from'),x.get('valid_to')) for x in names if (x['entity_type']!='node' or x['id'] in pub or x['id'] in ENDPT) and (x['entity_type']!='archive' or x['id'] in _arch_ids)])
# 역·노선별 仮乗降場·臨時駅 기간. 날짜 모름 화면의 표식에 쓴다 (사용자 결정 2026-11-07). valid_to NULL이면 지금도 仮·臨
db.execute('create table stop_mark (node_id,line_id,kind,valid_from,valid_to)')
# 끝 없는 표식은 지금도 仮·臨이라는 뜻이다 (날짜 원칙: ongoing)
_stop_mark=sorted({(a,b,c,d,e or 'ongoing') for a,b,c,d,e in _stop_mark})
check_dates('stop_mark',['node_id','line_id','kind','valid_from','valid_to'],_stop_mark)
db.executemany('insert into stop_mark values (?,?,?,?,?)',_stop_mark)
# 계통 한정 표식과 그 이름 (stop_status의 route). 노선 한정 표와 같은 꼴에 route_id만 더한다. 앱은 계통 화면에서 이 표를 노선 한정 행보다 먼저 본다
db.execute('create table stop_mark_route (node_id,line_id,route_id,kind,valid_from,valid_to)')
_route_stop_mark=sorted({(a,b,r,c,d,e or 'ongoing') for a,b,c,d,e,r in _route_stop_mark})
check_dates('stop_mark_route',['node_id','line_id','route_id','kind','valid_from','valid_to'],_route_stop_mark)
db.executemany('insert into stop_mark_route values (?,?,?,?,?,?)',_route_stop_mark)
db.execute('create table name_route (entity_type,entity_id,lang,text,kana,source,line_id,route_id,valid_from,valid_to)')
_nr=[(x['entity_type'],x['id'],x['lang'],x['text'],x.get('kana'),x.get('source'),x.get('line'),x['route'],x.get('valid_from'),x.get('valid_to')) for x in _route_marked if x['id'] in pub]
check_dates('name_route',['entity_type','entity_id','lang','text','kana','source','line_id','route_id','valid_from','valid_to'],_nr)
db.executemany('insert into name_route values (?,?,?,?,?,?,?,?,?,?)',_nr)
db.execute('create table alias (entity_type,entity_id,lang,text,kind)')
# 노리츠부시 대응표(data/overrides/noritsubushi_map.json). 공식 노선 구성과 다르게 나뉜 노리츠부시 노선명을 계통·운행 계통 별칭으로 둔다 (DESIGN §10.2)
_nm=json.load(open(os.path.join(ROOT,'data','overrides','noritsubushi_map.json'),encoding='utf-8'))['rows']
_svid={s_['id'] for s_ in services}
for text_,v_ in _nm.items():
    if v_.get('service'):
        if v_['service'] not in _svid:err('noritsubushi_map_target',(text_,v_['service']));continue
        aliases.append(dict(entity_type='service',id=v_['service'],lang='ja',text=text_,kind='noritsubushi'))
    elif v_.get('route'):
        if v_['route'] not in routes:err('noritsubushi_map_target',(text_,v_['route']));continue
        aliases.append(dict(entity_type='route',id=v_['route'],lang='ja',text=text_,kind='noritsubushi'))
    else:err('noritsubushi_map_target',(text_,None))
db.executemany('insert into alias values (?,?,?,?,?)',[(x['entity_type'],x['id'],x.get('lang'),x['text'],x.get('kind')) for x in aliases])
# 검색 색인: 한 글자 토큰. trigram은 두 글자 역명을 못 찾는다. 앱의 searchQuery와 같은 정규화를 쓴다
KOFOLD={ord('쵸'):ord('초'),ord('죠'):ord('조'),ord('쥬'):ord('주'),ord('츄'):ord('추'),ord('챠'):ord('차'),ord('쟈'):ord('자')}
def fold(t):
    out=[]
    for c in t.lower():
        o=ord(c)
        if o<0x20 or o==0x7F:continue  # 앱 foldSearchText와 같게 제어 문자는 뺀다
        if 0x30A1<=o<=0x30F6:o-=0x60
        if o==0x3095:o=0x304B    # ゕ → か
        elif o==0x3096:o=0x3051  # ゖ → け
        o=KOFOLD.get(o,o)        # 쵸→초, 죠→조, 쥬→주, 츄→추, 챠→차, 쟈→자 (앱 foldSearchText와 같음)
        c=chr(o)
        if c.isspace() or c in '・·':continue
        out.append(c)
    return ' '.join(out)
db.execute("create virtual table search using fts5(text,entity_type unindexed,entity_id unindexed,tokenize=\"unicode61 remove_diacritics 0\")")
seen=set()
rows=[]
_hidden_lines={i for i,l in lines.items() if l.get('rule_class')=='hidden'}
def sadd(kind,eid,text):
    if not text or (kind=='line' and eid in _hidden_lines) or (kind=='route' and (routes.get(eid) or {}).get('line') in _hidden_lines):return
    f=fold(text)
    if f and (kind,eid,f) not in seen:
        seen.add((kind,eid,f));rows.append((f,kind,eid))
_busl={b_['line'] for b_ in BUS}
for x in names:
    # 버스 구간 표시용 노선은 찾기에 넣지 않는다. 고를 계통이 없다
    if x['entity_type']=='line' and x['id'] in _busl:continue
    if x['entity_type'] in('node','line','service') and not(x['entity_type']=='node' and x['id'] not in pub):
        sadd(x['entity_type'],x['id'],x['text']);sadd(x['entity_type'],x['id'],x.get('kana'))
    # 열람 전용 역·노선도 이름으로 찾는다. 고를 수는 없고 그 노선 화면의 자리로 간다 (사용자 결정 2026-11-08)
    elif x['entity_type']=='archive':
        sadd('archive',x['id'],x['text']);sadd('archive',x['id'],x.get('kana'))
for x in aliases:
    if x['entity_type'] in('node','line','service') and not(x['entity_type']=='node' and x['id'] not in pub):sadd(x['entity_type'],x['id'],x['text'])
# 운행 계통 별칭 (data/overrides/service_aliases.json). 공식 노선 하나 전체의 애칭은 그 노선으로, 운행 계통의 애칭은 그 계통으로 찾는다.
# 대상은 노선 ja 이름이나 ID다. 못 찾거나 여럿이면 오류다
_sa=os.path.join(ROOT,'data','overrides','service_aliases.json')
if os.path.exists(_sa):
    _lja=collections.defaultdict(set);_lja_now=collections.defaultdict(set)
    for x in names:
        if x['entity_type']=='line' and x['lang']=='ja':
            _lja[x['text']].add(x['id'])
            if not x.get('valid_to') or x.get('valid_to')=='ongoing':_lja_now[x['text']].add(x['id'])
    _sja={x['text']:x['id'] for x in names if x['entity_type']=='service' and x['lang']=='ja'}
    _sid={s['id'] for s in services}
    for text_,v_ in json.load(open(_sa,encoding='utf-8')).items():
        # 가리키는 키는 service, route(그 계통의 노선으로 감), line_id, line(이름이나 ID) 순으로 본다
        if v_.get('service'):
            kind_='service';c_={v_['service']} if v_['service'] in _sid else ({_sja[v_['service']]} if v_['service'] in _sja else set())
        elif v_.get('route'):
            kind_='line';c_={routes[v_['route']]['line']} if v_['route'] in routes else set()
        elif v_.get('line_id'):
            kind_='line';c_={v_['line_id']} if v_['line_id'] in lines else set()
        else:
            kind_='line';c_={v_.get('line')} if v_.get('line') in lines else (_lja_now.get(v_.get('line')) or _lja.get(v_.get('line'),set()))
        if len(c_)!=1:err('service_alias_target',(text_,v_.get('service') or v_.get('route') or v_.get('line_id') or v_.get('line'),sorted(c_)));continue
        for t_ in (text_,v_.get('kana'),v_.get('ko'),v_.get('en')):sadd(kind_,next(iter(c_)),t_)
# 버스 구간의 통칭(ゆとりーとライン)으로 찾으면 그 버스가 이어지는 기록 노선이 나온다
for b_ in BUS:
    for t_ in b_.get('search',[]):sadd('line',routes[b_['route']]['line'],t_)
db.executemany('insert into search values (?,?,?)',rows)
db.execute("insert into search(search) values('optimize')")
db.execute('create index ix_name_entity on name(entity_type,entity_id)')
db.commit();db.close()

rep=dict(today=TODAY,operators=len(ops),lines=len(lines),routes=len(routes),nodes=len(nodes),public_nodes=len(pub),edges=len(edges),events=len(events),attr=len(attr),route_stop=len(stops),route_link=len(links),hubs=len(hubs),junctions=len(junctions),archive=len(archive),
 denominators={f"{d['basis']}:{d['carryover']}":d['km'] for d in denom if d['scope']=='all' and d['basis'] in('current','alltime')},
 relocation_overlap=[dict(edge=r_['edge_id'],close=r_['valid_to'],**r_['overlap']) for r_ in life if r_.get('overlap')],
 pref_split=dict(pref_split),operator_km={k:round(v,1) for k,v in curop.items()},errors={k:len(v) for k,v in ERR.items()},error_samples={k:v[:12] for k,v in ERR.items()},warnings={k:v[:40] for k,v in WARN.items()})
json.dump(rep,open(os.path.join(BUILD,'report.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=1)
print({k:v for k,v in rep.items() if k not in('error_samples','operator_km')})
# 검사 오류는 실패다 (DESIGN §2.6). 보고서를 쓴 뒤 멈춘다
# 생성 중 컴파일(보정 행을 얹지 않음, 새 ID 모드는 노드가 내부 키)에서는 보정 행과 번호로 가리키는 사건 행이 맞지 않는다.
# 이 종류는 마지막 컴파일에서 검사하므로 여기서는 알리기만 한다
if _nopatch:
    for k_ in ('transfer_no_from','route_no_path','edge_no_attr','parallel_unjudged','range_unresolved','service_stop_off_path','service_name_missing','service_name_ambiguous','service_route_missing','service_part_gap','hub_pairs_unused'):
        if k_ in ERR:print('생성 중 컴파일: 마지막 컴파일에서 검사',k_,len(ERR.pop(k_)))
if ERR:
    # 어느 행인지 바로 보이게 종류마다 앞의 몇 개를 적는다
    for k,v in ERR.items():print('오류',k,json.dumps(v[:int(os.environ.get('NORIORI_ERRN','5'))],ensure_ascii=False,default=str)[:int(os.environ.get('NORIORI_ERRW','600'))],file=sys.stderr)
    raise SystemExit(f'컴파일 검사 오류: {dict((k,len(v)) for k,v in ERR.items())}')
