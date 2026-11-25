# -*- coding: utf-8 -*-
# 일본어 위키백과 노선도에서 분기(junction), 이어짐, 열람 전용 역(archive) 후보를 뽑아 data/source에 넣는다
import sys,os,re,json,gzip,hashlib,collections,math,heapq
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from lib import *
import wparse as w
import conn
os.environ['NW_OFF']='1'
from decimal import Decimal,ROUND_HALF_UP
def dround(x,n=1):
    """km 반올림은 사사오입이다. float round()는 15.85를 15.8로 내린다(이진 표현·은행가 반올림). 6자리에서 float 잡음을 먼저 지운다"""
    return None if x is None else float(Decimal(repr(round(x,6))).quantize(Decimal(1).scaleb(-n),rounding=ROUND_HALF_UP))

lines={l['id']:l for l in load('lines')}
routes=load('routes')
def _src_patch(mod,rows):
    """컴파일 단계 보정 행(data/overrides/source_patch)의 계통·칸을 얹는다. 생성 도중에는 load가 얹지 않지만(lib._patch) 연결 행은
    컴파일이 보정을 얹은 계통 끝을 기준으로 맞아야 한다(京津線 계통 시작 京津三条, 安城支線 등). 새 ID 모드에서는 ID가 달라 얹지 않는다"""
    if os.environ.get('NORIORI_NEW_IDS'):return rows
    by={x['id']:i for i,x in enumerate(rows)}
    for x in sorted((x for x in [json.loads(l[2:]) for d_ in [os.path.join(ROOT,'data','overrides','source_patch',mod)] if os.path.isdir(d_) for f_ in sorted(os.listdir(d_)) if f_.endswith('.yaml') for l in open(os.path.join(d_,f_),encoding='utf-8') if l.startswith('- ')]),key=lambda x:x['id']):
        x=dict(x);op=x.pop('patch');x.pop('why',None)
        if op=='replace' and x['id'] in by:rows[by[x['id']]]=x
        elif op=='add' and x['id'] not in by:by[x['id']]=len(rows);rows.append(x)
    return rows
lines={l['id']:l for l in _src_patch('lines',list(lines.values()))}
routes=[r for r in _src_patch('routes',routes) if r['line'] in lines]
nodes={n['id']:n for n in _src_patch('nodes',load('nodes'))}
names=load('names')
# 노드의 대표 이름은 지금 이름(노선·기간 한정 아닌 행)이다. 이름 표의 첫 행을 쓰면 행 순서(직전 빌드 결과)에 따라 옛 이름이 대표가 되어
# 같은 이름 두 노드(京津線 浜大津·びわ湖浜大津) 맞춤이 빌드마다 뒤집혔다 (5회차 2026-11-23)
ja={};JA_ALL=collections.defaultdict(set);JA_LINE=collections.defaultdict(set)
for x in names:
    if x['entity_type']!='node' or x['lang']!='ja':continue
    JA_ALL[x['id']].add(x['text'])
    if x.get('line'):JA_LINE[(x['id'],x['line'])].add(x['text'])
    if not x.get('line') and not x.get('valid_from') and not x.get('valid_to'):ja.setdefault(x['id'],x['text'])
for x in names:
    if x['entity_type']=='node' and x['lang']=='ja' and x['id'] not in ja:ja[x['id']]=x['text']
# 노선마다 그 노선 계통이 서는 노드(노선도 역 이름 맞춤에서 먼저 고른다)
LSTOP=collections.defaultdict(set)
_rl_={r['id']:r['line'] for r in routes}
for x_ in load('stops'):
    if x_.get('route') in _rl_:LSTOP[_rl_[x_['route']]].add(x_['node'])
line_ja={i:l['name_ja'] for i,l in lines.items()}
# 노선별 정차역 순서
edges=[e for e in _src_patch('edges',load('edges')) if e.get('seed_line') in lines]
r_by_line=collections.defaultdict(list)
for r in routes:r_by_line[r['line']].append(r)
adj=collections.defaultdict(set)
# 노선 그래프(노드 → 이웃). 이관으로 넘겨받은 구간은 넘겨준 노선의 길을 따라 칸째로 붙인다
ladj=collections.defaultdict(lambda:collections.defaultdict(set))
for e in edges:
    adj[e['seed_line']].add(e['a']);adj[e['seed_line']].add(e['b'])
    ladj[e['seed_line']][e['a']].add(e['b']);ladj[e['seed_line']][e['b']].add(e['a'])
def lpath(l,a,b,via=()):
    """노선 l 그래프에서 a→(via)→b 최단 경로 노드 목록. 없으면 None"""
    out=[a]
    for s,t in zip([a]+list(via),list(via)+[b]):
        if s==t:continue
        prev={s:None};q=collections.deque([s])
        while q and t not in prev:
            u=q.popleft()
            for v in sorted(ladj[l].get(u,())):
                if v not in prev:prev[v]=u;q.append(v)
        if t not in prev:return None
        p=[];u=t
        while u!=s:p.append(u);u=prev[u]
        out+=p[::-1]
    return out
ev=load('events')
# 이관 사슬(넘겨준 노선 → 넘겨받은 노선, 날짜, 구간 노드). 연결 행을 옛 노선에도 기간만큼 복제할 때 쓴다 (2회차 종합 K01)
chain=[];CHE=collections.defaultdict(set)
for e in sorted(ev,key=lambda e:e.get('date') or ''):
    if e['type']=='transfer' and e.get('to') and e.get('from') and e['to']['line']!=e['from']['line']:
        for sp in e['edges']:
            m=re.match(r'^(n_[^.@]+)\.\.(n_[^.@]+)',sp)
            if m:
                fl,tl=e['from']['line'],e['to']['line']
                p=lpath(fl,m.group(1),m.group(2)) or [m.group(1),m.group(2)]
                adj[tl]|=set(p)
                for u,v in zip(p,p[1:]):ladj[tl][u].add(v);ladj[tl][v].add(u)
                chain.append((fl,tl,e.get('date'),set(p)));CHE[(fl,tl)]|={frozenset(x) for x in zip(p,p[1:])}
# 계통 경로(노드 순서)와 경로 위 영업km. 열람 전용 역을 계통 축에 놓고, 지나가는 노선의 위·아래 쪽과 지선 계통 끝이 같은 노선 다른 계통 위인지 볼 때 쓴다
rpath={r['id']:lpath(r['line'],r['from'],r['to'],[v for v in r.get('via') or () if isinstance(v,str)]) for r in routes}
_ekm={};_eid={e['id']:e for e in edges}
for k_ in load('km'):
    e_=_eid.get(k_['edge'])
    if e_ and isinstance(k_.get('km'),(int,float)):_ekm.setdefault(frozenset((e_['a'],e_['b'])),k_['km'])
_rkm={};_rid={r['id']:r for r in routes}
_epair=collections.defaultdict(list)
for e in edges:_epair[frozenset((e['a'],e['b']))].append(e)
def rkm(rid):
    """계통의 노드별 누적 영업km. 컴파일의 계통 km 축과 같게 잰다(compile.py route_rank): 본선 계통은 그 노선의 지금 칸(옛 선로 alt old 빼고,
    다른 계통 전용 칸 빼고)으로 km 최단 거리, 옛 선로 역은 그 뒤에 옛 칸으로. 지선·옛 경로 계통은 그 계통 칸만. 경로를 칸 수로 고르면
    짧은 옛 선로로 돌아 km 축이 어긋난다(飯田線 大嵐 옛 선로로 4.0 km 작음, 2회차 종합 K24). 계통 경로가 없으면 None"""
    if rid not in _rkm:
        r=_rid.get(rid);o=None
        if r and rpath.get(rid):
            hand=r.get('role')=='branch' or r.get('owned')
            # 노선 그래프(ladj: 이관으로 넘겨받은 구간 포함, あいの風とやま鉄道線의 옛 北陸本線 칸)의 칸. 같은 두 역을 그 노선 자기 칸이 이으면 그것만
            ok_=lambda e:e.get('route_only')==rid or (not hand and not e.get('route_only')) or e['id'] in (r.get('also') or ())
            S=[]
            for u,vs in ladj[r['line']].items():
                for v in vs:
                    if u<v:
                        es_=[e for e in _epair.get(frozenset((u,v)),()) if ok_(e)]
                        S+=[e for e in es_ if e.get('seed_line')==r['line']] or es_
            g=collections.defaultdict(list)
            for e in S:g[e['a']].append(e);g[e['b']].append(e)
            o={r['from']:0.0}
            def relax(alts,fixed):
                pq=[(v,k) for k,v in o.items()];heapq.heapify(pq)
                while pq:
                    d,n=heapq.heappop(pq)
                    if d>o.get(n,1e12):continue
                    for e in g[n]:
                        if not hand and (e.get('alt')=='old')!=alts:continue
                        k_=_ekm.get(frozenset((e['a'],e['b'])))
                        if k_ is None:continue
                        m=e['b'] if e['a']==n else e['a'];nd=d+k_
                        if nd<o.get(m,1e12) and m not in fixed:o[m]=nd;heapq.heappush(pq,(nd,m))
            relax(False,set());relax(True,set(o))
            # 칸 km를 몰라 닿지 못한 노드는 값이 없다. 쓰는 쪽이 앞뒤 역 둘 다 값이 있을 때만 환산한다
        _rkm[rid]=o
    return _rkm[rid]
st_line=collections.defaultdict(set)
for l,S in adj.items():
    for n in sorted(S):st_line[n].add(l)
# compile이 끝 노드를 역 노드로 합치는 곳(edge_insert merge, 5번 결정): 합쳐질 노드에 닿는 노선은 합친 역 노드에 닿는다
_MERGED_INTO={}
for r_ in json.load(open(os.path.join(ROOT,'data','overrides','edge_insert.json'),encoding='utf-8'))['rows']:
    if r_.get('merge'):_MERGED_INTO.setdefault(r_['into'],set()).add(r_['merge'])
def _meets(l,x):
    """노선 l이 노드 x에 닿는가. 이관으로 칸 없이 계통만 받은 노선(弘南鉄道黒石線)은 계통 경로로 본다"""
    return any(l in st_line.get(y,()) or any(y in (r['from'],r['to']) or y in (rpath.get(r['id']) or ()) for r in r_by_line[l]) for y in {x}|_MERGED_INTO.get(x,set()))
# 위키 문서 색인
idx={}
d=os.path.join(IMP,'wiki')
for f in os.listdir(d):
    if f.endswith('.json.gz'):idx[f[:14]]=f
def doc_of(t):
    k=hashlib.md5(t.encode()).hexdigest()[:14]
    f=idx.get(k)
    if not f:return None
    return json.load(gzip.open(os.path.join(d,f),'rt',encoding='utf-8'))
pos_={p['node']:p for p in load('positions') if p.get('lat') is not None}
name_nodes=collections.defaultdict(list)
for x in names:
    if x['entity_type']=='node' and x['lang']=='ja':name_nodes[znorm(x['text'])].append(x['id'])
_MVP={frozenset((mv['old'],mv['new'])) for mv in json.load(open(os.path.join(ROOT,'data','overrides','moved.json'),encoding='utf-8'))}
def near_ok(a,b):
    import math
    p,q=pos_.get(a),pos_.get(b)
    if not p or not q:return False
    return math.hypot((p['lat']-q['lat'])*111,(p['lon']-q['lon'])*91)<.9
pairs=set()
# 노선 이름 → ID (이름이 같은 사철 노선은 같은 역을 지나는지로 가린다)
by_ja=collections.defaultdict(list)
for i,n in line_ja.items():
    by_ja[znorm(n)].append(i)
    s=lines[i].get('sd')
    if s:
        c=znorm(conn.clean(s))
        if c!=znorm(n):by_ja[c].append(i)
names_sorted=sorted(by_ja,key=len,reverse=True)
def lines_in(text):
    t=znorm(text);o=[];used=[]
    for n in names_sorted:
        if len(n)<2 or not n.endswith(('線','本線','ライン')) and len(n)<3:continue
        p=t.find(n)
        while p>=0:
            if not any(a<=p<b for a,b in used):
                used.append((p,p+len(n)));o.append(n);break
            p=t.find(n,p+1)
    return o
# ---- 노선도에 폐지 해가 없는 폐역 행의 날짜를 같은 문서의 역 일람 표·年表·廃駅 목록에서 읽는다 (2026-11-17)
_NYD=r'(\d{4})年(?:\s*[（(][^）)]{0,8}[）)])?\s*(?:(\d{1,2})月)?\s*(?:(\d{1,2})日)?'
_NYSUF=r'(?:駅|停留場|停留所|停車場|乗降場|仮乗降場|仮停車場|仮停留場|仮駅|臨時乗降場|臨時停留場|臨時停車場|臨時駅)'
def _nyclean(s):
    s=re.sub(r'<!--.*?-->','',s,flags=re.S)
    s=re.sub(r'<ref[^>]*/>|<ref[^>]*>.*?</ref>','',s,flags=re.S)
    s=re.sub(r'\{\{(?:R|Sfn|sfn|efn|Refnest|refnest|NDLDC)\|[^{}]*\}\}','',s)
    s=re.sub(r'\[\[(?:[^|\]]*\|)?([^\]]*)\]\]',r'\1',s)
    s=re.sub(r"'''?|\{\{right\}\}|&nbsp;",'',s)
    s=re.sub(r'style="[^"]*"\s*\|?|rowspan="\d+"\s*\|?|colspan="\d+"\s*\|?','',s)
    # 「休止（廃止日不明）」의 廃止는 폐지일이 아니다
    s=re.sub(r'[（(]?廃止日不明[)）]?|廃止時期不明|廃止年不明','',s)
    return s
def _nyday(y,mo,d,edge):
    """해·달·날 → EDTF. edge 'lo'·'hi'는 「以前」「以降」의 열린 끝"""
    if not y:return None
    v=y+'-'+(f'{int(mo):02d}' if mo else 'XX')+'-'+(f'{int(d):02d}' if d else 'XX')
    return v
def _nyspan(head,y,mo,d):
    """年表 머리말의 「以前」「以降」「頃」「-」을 범위로"""
    v=_nyday(y,mo,d,None)
    if re.search(r'以前|まで',head):return f'[..{y}-12-31]'
    if re.search(r'以降',head):return f'[{y}-01-01..]'
    m=re.search(r'(\d{4})年\s*[-–~～]\s*(\d{4})年頃',head)
    if m:return f'[{m.group(1)}-01-01..{m.group(2)}-12-31]'
    return v
def noyear_dates(wt,name):
    """같은 문서에서 그 역의 개업·폐지(휴지)를 읽는다. 결과 dict(src, opened, closed, kind 'close'|'susp', legal, skip 이유, text)"""
    nm=re.escape(name)
    # ① 역 일람 표: 이름 칸이 그 역인 행(노선도 BS 틀 덩어리는 뺀다)
    for ch in re.split(r'\n\|-',wt):
        if '{{BS' in ch:continue
        c=_nyclean(ch.split('\n|}')[0]);cells=[x.strip().rstrip('*').strip() for x in re.split(r'\n[|!]|\|\||!!',c)]
        if not any(re.sub(r'\s*[（(].*$','',x) in (name,name+'駅',name+'停留場') for x in cells):continue
        t=' / '.join(x for x in cells if x)
        r=dict(src='table',text=t[:200])
        if re.search(r'未成|未開業|未開通|計画|予定|構想',t):return dict(r,skip='plan')
        if re.search(r'貨物|（貨）|\(貨\)|信号',t):return dict(r,skip='freight')
        cl=[m for m in re.finditer(_NYD+r'[^0-9/、。]{0,12}?(廃止|廃駅)',t)];su=[m for m in re.finditer(_NYD+r'[^0-9/、。]{0,12}?休止',t)]
        op=re.search(_NYD+r'[^0-9/、。]{0,6}?(開設|開業|設置|新設)',t)
        if re.search(r'移転|改称|統合',t) and not cl:return dict(r,skip='moved')
        o=_nyday(*op.groups()[:3],None) if op else None
        if su and (not cl or cl[0].start()>su[-1].start()):
            return dict(r,kind='susp',opened=o,closed=_nyday(*su[-1].groups()[:3],None),legal=_nyday(*cl[-1].groups()[:3],None) if cl else None)
        if cl:return dict(r,kind='close',opened=o,closed=_nyday(*cl[-1].groups()[:3],None),legal=None)
        # 표 행은 있으나 날짜가 없다 → 年表로 넘어간다
        break
    # ② 年表·廃駅 목록의 글머리 행
    yr=None;mo_=None;found=[];heads_={};head_in=''
    for ln in wt.split('\n'):
        if not ln.startswith('*'):continue
        c=_nyclean(ln)
        m=re.match(r'^\*\s*'+_NYD,c)
        if m and not c.startswith('**'):yr=m.group(1);heads_={1:m.group(0)[1:].strip()}
        # 廃駅 목록 「* 山道駅：1904年7月18日廃止」「* 長尾西駅：公文明駅 - 長尾駅間、1915年廃止」
        m=re.match(r'^\*+\s*(?:（貨）|\(貨\))?'+nm+_NYSUF+r'(?:（[^）]*）)?\s*[：:（(\-–—]',c)
        if m:
            if re.match(r'^\*+\s*(?:（貨）|\(貨\))',c) or re.search(r'貨物|信号',c):found.append(dict(src='list',text=c[:200],skip='freight'));continue
            cl=list(re.finditer(_NYD+r'[^0-9、。]{0,6}?(廃止|廃駅)',c));su=list(re.finditer(_NYD+r'[^0-9、。]{0,6}?休止',c))
            op=re.search(_NYD+r'[^0-9、。]{0,6}?(開設|開業|設置|新設)',c)
            o=_nyday(*op.groups()[:3],None) if op else None
            if su:found.append(dict(src='list',text=c[:200],kind='susp',opened=o,closed=_nyday(*su[0].groups()[:3],None),legal=_nyday(*cl[-1].groups()[:3],None) if cl else None))
            elif cl:found.append(dict(src='list',text=c[:200],kind='close',opened=o,closed=_nyday(*cl[-1].groups()[:3],None),legal=None))
            continue
        # 年表 행: 날짜 머리말 + 「A駅・B駅が廃止」. 머리말 뒤 쌍점이 없는 행(「** 6月1日 並木橋駅、新太田町駅休止」)은 날짜까지를 머리말로 본다
        hm=re.match(r'^(\*+)\s*([^：:]{0,40}?)[：:]',c) or re.match(r'^(\*+)\s*((?:\d{4}年(?:\s*[（(][^）)]{0,8}[）)])?\s*)?\d{1,2}月(?:\d{1,2}日)?)\s',c) or re.match(r'^(\*+)\s*(\d{4}年(?:\s*[（(][^）)]{0,8}[）)])?\s*(?:[-–~～]\s*\d{4}年)?\s*(?:以前|以降|頃))\s',c)
        # 날짜 머리말이 없는 더 깊은 글머리(「*** 武蔵小杉停留場・…が廃止」)는 바로 위 얕은 글머리의 날짜를 잇는다
        lv_=len(c)-len(c.lstrip('*'))
        if hm and (re.search(_NYD,hm.group(2)) or re.search(r'\d{1,2}月',hm.group(2)) or '同年' in hm.group(2)):heads_[lv_]=hm.group(2);[heads_.pop(k_) for k_ in [k_ for k_ in heads_ if k_>lv_]]
        elif lv_>1 and any(k_<lv_ for k_ in heads_):
            hm=re.match(r'^(\*+)()\s*',c);head_in=heads_[max(k_ for k_ in heads_ if k_<lv_)]
        if not hm:continue
        head=hm.group(2) or head_in
        dm=re.search(_NYD,head);dd=re.search(r'(\d{1,2})月(?:(\d{1,2})日)?',head)
        if dm:y,mo,d=dm.groups()
        elif dd and yr:y,mo,d=yr,dd.group(1),dd.group(2)
        elif re.search(r'同年',head) and yr:y,mo,d=yr,None,None
        else:continue
        body=c[hm.end():]
        for sen in re.split(r'。',body):
            # 「A駅・B駅が廃止」「A駅とB駅を統合し」「鏡田・池内・片山の各季節停留場を廃止」「【駅廃止】元油津、妻手橋、…」
            p=re.search(r'(?:^|[、・ 　の）])((?:[^。：、・ 　]{1,14}?'+_NYSUF+r'(?:（[^）]*）)?[・、と])*)'+nm+_NYSUF+r'(?:（[^）]*）)?((?:[・、と][^。：、・ 　]{1,14}?'+_NYSUF+r'(?:（[^）]*）)?)*)(?:の両駅|の各駅|各駅)?(?:を|が|も|は)?(?:前日限りで|同時に)?(廃止|休止|廃駅|統合)(?!後)',sen)
            if not p:p=re.search(r'(?:^|[、 　の）])((?:[^。：、・ 　]{1,10}・)*)'+nm+r'((?:・[^。：、・ 　]{1,10})*)の(?:各|両)(?:季節|臨時)?'+_NYSUF+r'(?:を|が|も)?(廃止|休止)',sen)
            if not p:
                q=re.search(r'【駅廃止】([^【]*)',sen)
                if q and re.search(r'(?:^|[、\s])'+nm+r'(?:'+_NYSUF+r')?(?:[、\s]|$)',q.group(1)):p=re.match(r'()()(廃止)','廃止')
            if not p:continue
            # 화물: 그 역 이름 앞의 （貨） 표지, 또는 (【駅廃止】 목록이 아닌) 문장의 貨物·信号
            if re.search(r'(?:（貨）|\(貨\))'+nm,sen) or ('【駅廃止】' not in sen and re.search(r'貨物|信号',sen)):found.append(dict(src='chron',text=sen[:200],skip='freight'));continue
            v=_nyspan(head,y,mo,d)
            found.append(dict(src='chron',text=(head+'：'+sen)[:200],kind='susp' if p.group(3)=='休止' else 'close',opened=None,closed=v,legal=None))
        # 그 역의 재개 서술(「X駅が営業再開」「X駅を再開」)
        if re.search(nm+_NYSUF+r'(?:（[^）]*）)?(?:が|を|も|は)?(?:営業|運転|旅客営業)?(?:再開|復活)',c):found.append(dict(src='chron',text=c[:200],skip='reopen'))
    if not found:return None
    if any(f.get('skip')=='reopen' for f in found):return dict(next(f for f in found if f.get('skip')=='reopen'))
    if any(f.get('skip') for f in found):return dict(next(f for f in found if f.get('skip')))
    # 휴지 뒤 폐지: 휴지 시작이 끝, 나중 폐지일은 법적 폐지
    su=[f for f in found if f['kind']=='susp'];cl=[f for f in found if f['kind']=='close']
    # 문서 안의 폐지(휴지) 해가 서로 다르면(戎 1901·1907) 판정하지 않는다
    ys={str(f['closed']).strip('[.')[:4] for f in (su or cl)}
    if len(ys)>1:return dict(found[0],skip='conflict',text=' // '.join(f['text'][:80] for f in found))
    if su:
        f=dict(su[0])
        if cl and not f.get('legal'):f['legal']=cl[-1]['closed'] if not str(cl[-1]['closed']).startswith('[') else None
        return f
    return dict(cl[0])
NYH=json.load(open(os.path.join(ROOT,'data','overrides','archive_fix.json'),encoding='utf-8')).get('_noyear',{});NYH_USED=set()
junc=[];arch=[];stat=collections.Counter();seen=set();ARCH_OUT=[];KARI=[];NOYEAR=[]
# 노선별 노선도 행 위치: 지금 역 행(노드)과 역 꼴 행(이름). gen_extra가 같은 자리 열람 전용 역의 순서(wiki_row)를 정할 때 쓴다(손 행 _add 포함)
WROWS={}
years={};kmcheck=[];unmatched=[];archnames=[];ins=[];kmrows={}
STICON=re.compile(r'(BHF|HST|BST)')
NOT=re.compile(r'専用|貨物|（社）|\(社\)|工場|車両|基地|信号|操車|車庫|機関区|運転所|検車|電留線|留置|発電|鉱|炭|森林|軌道|索道|ロープウェイ')
ST=re.compile(r'^([^\s／：・（(]+?)(?:臨時乗降場|仮乗降場|仮停車場|仮停留場|臨時駅|駅|停留場|停車場|乗降場)(?:\s*[（(].*?[)）])?(?:\s+(\d{4})?\s*[-–−~～]\s*(\d{4})?)?')
# 꼬리(駅·停留場)가 없거나 「電停」인 노선도 역 행(名古屋市電 「南大津町電停 -1918」, 꼬리 없는 「南大津町 -1918」)을 받는 보조 규칙.
# ST가 받는 행은 ST 그대로라 기존 열람 전용 이름·ID는 바뀌지 않는다. 역 아이콘·NOT 거르기는 똑같이 거친다. 폐역 행 뽑기에만 쓰고,
# 노선도의 지금 역 자리 맞추기(posd·wiki_row)는 ST 그대로다(꼬리 없는 「浜大津」가 지금 역 자리로 잡혀 기존 열람 전용 앞 노드가 바뀌었다) (5회차 2026-11-23)
ST2=re.compile(r'^([^\s／：・（(]+?)(?:電停留場|電停)?(?=\s|$|[（(])(?:\s*[（(].*?[)）])?(?:\s+(\d{4})?\s*[-–−~～]\s*(\d{4})?)?')
def stmatch(t):return ST.match(t) or ST2.match(t)
CLOSEDICON=re.compile(r'^(ex|x|e[A-Z]|ke|u?ex)')
cache={};TXT={}
for lid_,l in lines.items():
    t=conn.clean(l['sd']) if l.get('sd') else l['name_ja']
    rec=doc_of(t) or doc_of(l['name_ja'])
    if not rec or not rec.get('html'):stat['no_doc']+=1;continue
    TXT[lid_]=(rec['revid'],re.sub(r'<[^>]+>','',rec['html']))
    if rec['title'] in cache:rows=cache[rec['title']]
    else:
        root=w.parse_text(rec['html'])
        rows,_=w.extract(None,8,root)
        cache[rec['title']]=rows
    flat=[]
    for r in rows:
        if isinstance(r,(list,tuple)) and len(r)==2 and isinstance(r[1],list):flat+=[x for x in r[1] if 'h' not in x]
        elif isinstance(r,dict) and 'h' not in r:flat.append(r)
    if not flat:stat['no_rows']+=1;continue
    stat['docs']+=1
    # 정차역 위치
    S=sorted(adj[lid_])
    # 노선도 역 이름 → 노드. 이 노선이 서는 노드를 먼저(지금 이름과 그 노선 한정 이름), 다른 노드(지나가는 노드)는 그 이름이 비었을 때만
    nm2n={}
    for n in S:
        if n in LSTOP[lid_]:
            for t_ in sorted(({ja.get(n)}|JA_LINE[(n,lid_)])-{None}):nm2n.setdefault(znorm(t_),n)
    for n in S:
        if n in ja:nm2n.setdefault(znorm(ja[n]),n)
    pos=[]
    for i,r in enumerate(flat):
        hit=None
        for tok in re.findall(r'[^\s／：・]+駅|[^\s／：・]+(?:信号場|信号所)',r['t']):
            x=znorm(re.sub(r'\(.*$','',tok))
            if x in nm2n:hit=nm2n[x];break
        if hit:pos.append((i,hit))
    if len(pos)<2:stat['few_pos']+=1;continue
    # 역 행의 연도·km, 없는 옛 역
    prevn=None;mainr=r_by_line[lid_][0]['id'] if r_by_line[lid_] else None
    posd=dict(pos);km_diff=[]
    # 위키 진행 방향이 본선 계통과 반대인가 (아래 분기 방향에도 쓴다)
    _mr=r_by_line[lid_][0] if r_by_line[lid_] else None
    _fa=[i for i,n in pos if _mr and n==_mr['from']];_fb=[i for i,n in pos if _mr and n==_mr['to']]
    flip_=bool(_fa and _fb and _fa[0]>_fb[-1])
    # 노선도 맨 끝(맨 앞) 너머에 그려진 역 묶음이 이 노선의 연장이 아니라 중간 역에서 갈라진 지선일 수 있다(日ノ丸自動車法勝寺電鉄線: 阿賀 「←母里支線」,
    # 母里支線 역 原·猪小路·与一谷·不動尊·母里가 法勝寺 뒤 다른 열에 그려짐, 2026-11-20 사용자 지적). 분기 아이콘(ABZ) 행의 표기 「…支線」「…線」 앞말이
    # 너머 묶음의 역 이름과 같으면 그 묶음 전체를 그 분기 행 바로 위 역(branch_at)에서 갈라지는 지선의 역(branch)으로 표시한다. 옮기는 것은 gen_extra다
    _ends=(min(posd),max(posd)) if posd else (None,None)
    _stn=lambda q:(lambda m:znorm(re.sub(r'(仮|臨時)$','',m.group(1))) if m else None)(ST.match(flat[q]['t'].strip())) if any(STICON.search(x) for c in flat[q]['c'] for x in c) else None
    _blk={side:{_stn(q) for q in qs}-{None} for side,qs in (('a',range(_ends[1]+1,len(flat))),('b',range(0,_ends[0]))) if _ends[0] is not None}
    _br={}
    for q in range(len(flat)):
        if q in posd or not any('ABZ' in x for c in flat[q]['c'] for x in c):continue
        lab_=re.sub(r'\s*-?\s*\d{4}.*$','',re.sub(r'[←→↑↓]','',flat[q]['t'])).strip()
        root_=znorm(re.sub(r'(支線|線)$','',lab_)) if re.search(r'線$',lab_) else ''
        at_=next((posd[z] for z in range(q,-1,-1) if z in posd),None)
        for side,ns in _blk.items():
            if root_ and root_ in ns and at_:_br[side]=(at_,root_)
    _wr=WROWS[lid_]=dict(n=[[i,n] for i,n in pos],s=[])
    for i,r in enumerate(flat):
        m_=ST.match(r['t'].strip())
        if m_ and i not in posd and any(STICON.search(x) for c in r['c'] for x in c):_wr['s'].append([i,znorm(re.sub(r'(仮|臨時)$','',m_.group(1)))])
    for i,r in enumerate(flat):
        icons=[x for c in r['c'] for x in c]
        m=ST.match(r['t'].strip())
        # 보조 규칙(꼬리 없음·電停)은 노드가 없는 옛 정류장만 받는다. 이미 노드 이름인 행(京津線 浜大津)은 지금 역이라 열람 전용 후보로 뽑지 않는다
        if not m:
            t_=r['t'].strip()
            # 「鉄軌分界点（福井市駅） -1933」처럼 머리 토막이 분계·분기 지점이고 괄호 안이 역이면 괄호 안 이름이 역이다. 「…点」 머리 토막은 역 이름이 아니다
            pm_=re.match(r'^[^\s（(]+?点\s*[（(]([^）)]+?)(?:駅|停留場|電停)[)）](.*)$',t_)
            if pm_:t_=pm_.group(1)+'駅'+pm_.group(2)
            m=ST.match(t_) or ST2.match(t_)
            if m and (re.search(r'点$',m.group(1)) or znorm(re.sub(r'(仮|臨時)$','',m.group(1))) in name_nodes):m=None
        if i in posd:
            n=posd[i]
            # 이름이 다른 역으로의 환승: 같은 행(또는 바로 옆 HUB 행)에 적힌 다른 역
            rs=[r]+[flat[q] for q in (i-1,i+1) if 0<=q<len(flat) and not flat[q]['k'] and any('HUB' in x for c in flat[q]['c'] for x in c)]
            for rr in rs:
                for tok in re.findall(r'[^\s／：・（(]+駅',rr['t'])+rr.get('l',[]):
                    o2=znorm(re.sub(r'\s*[(（].*$','',tok))
                    if o2==znorm(ja.get(n,'')) or len(o2)<2:continue
                    for x in name_nodes.get(o2,[]):
                        if x!=n and near_ok(n,x):pairs.add(tuple(sorted((n,x))))
            ym=re.search(r'(\d{4})\s*[-–−~～]\s*(\d{4})?',r['t'])
            if ym:years[lid_+'|'+n]=[ym.group(1),ym.group(2)]
            # 仮乗降場·臨時駅 표지는 stop_status 후보로 보고서에 남긴다(그 기간 표식은 stop_status.json이 붙인다, 2회차 종합 K26)
            mk=re.search(r'(仮乗降場|仮停車場|仮停留場|臨時乗降場|臨時駅|仮駅)',r['t'])
            if mk:KARI.append(dict(line=lid_,node=n,kind='rinji' if '臨時' in mk.group(1) else 'kari',text=r['t'][:60],years=[ym.group(1),ym.group(2)] if ym else None,source=f"wikipedia:{rec['revid']}"))
            prevn=n;continue
        if not m or not any(STICON.search(x) for x in icons) or NOT.search(r['t']):continue
        # 「酒津仮」「大黒沢臨時」처럼 仮乗降場·臨時乗降場 표지가 이름 끝에 남은 것은 뗀다. 그 기간 표시는 stop_status.json이 붙인다
        nm=znorm(re.sub(r'(仮|臨時)$','',m.group(1)))
        if nm in nm2n:
            mk=re.search(r'(仮乗降場|仮停車場|仮停留場|臨時乗降場|臨時駅)',m.group(0)) or re.search(r'(仮|臨時)$',m.group(1))
            if mk:KARI.append(dict(line=lid_,node=nm2n[nm],kind='rinji' if '臨時' in mk.group(1) else 'kari',text=r['t'][:60],years=[m.group(2),m.group(3)] if m.group(2) or m.group(3) else None,source=f"wikipedia:{rec['revid']}"))
            continue
        y0,y1=m.group(2),m.group(3)
        closedicon=any(re.match(r'^(ue|ex|e[A-Z]|x[A-Z]|uex)',x) for x in icons if STICON.search(x))
        if not(closedicon or y1):continue
        # 폐역 아이콘인데 노선도에 폐지 해가 없는 행(志度線 出晴·志度西口·東田町·白羽)은 같은 문서의 역 일람 표·年表·廃駅 목록에서
        # 그 역의 폐지(휴지) 날짜를 읽는다(noyear_dates). 읽은 날짜가 기준일 전이면 열람 전용 역으로 만들고, 휴지 뒤 폐지는 휴지 시작이 끝·뒤 폐지일은
        # 법적 폐지다(DESIGN 휴지·폐지 결과 기준). 未成·화물·이전·재개·날짜 엇갈림·열린 범위·기준일 뒤 폐지는 만들지 않고
        # 이유와 함께 보고서(wiki_archive_kari.json noyear)에 남긴다. 같은 이름 노드와 자리가 겹치는 행은 gen_extra 자리·기간 판정(_known)이 뺀다. 기준일 뒤 폐지(post1950)는 기록 가능해야 하는데 빠진 역 후보다 (2026-11-17 사용자 지적)
        NYD=None
        if not y1:
            nm_=re.sub(r'(仮|臨時)$','',m.group(1))
            NYD=noyear_dates(rec.get('wikitext') or '',nm_)
            # 규칙이 못 읽거나(날짜 없음·엇갈림·열린 범위) 잘못 읽는 행은 사람이 근거를 확인한 손 표(archive_fix.json "_noyear", 키 「이름@노선」)를 쓴다.
            # drop은 만들지 않을 행(옛 경로라 자리를 못 정함 등), name은 노선도 표기 오기(南武是正→南武是政)를 고친 이름이다
            h_=NYH.get(f'{nm_}@{lid_}')
            if h_:
                NYD=dict(src='hand',skip='hand_drop',text=h_['why']) if h_.get('drop') else dict(src='hand',kind='close',opened=h_.get('opened'),closed=h_['closed'],legal=h_.get('legal_abolition'),text=h_['why'],name=h_.get('name'))
                NYH_USED.add(f'{nm_}@{lid_}')
            why_=None
            if NYD is None:why_='no_date'
            elif NYD.get('skip'):why_=NYD['skip']
            else:
                c_=str(NYD['closed'])
                hi_=c_[c_.index('..')+2:-1] if c_.startswith('[') else c_
                if not hi_:why_='open_range'
                elif hi_[:4]>='1950':why_='post1950'
            if why_:
                NOYEAR.append(dict(line=lid_,line_ja=l['name_ja'],name=nm_,open=y0,km=r['k'] or None,prev=ja.get(prevn),icons=icons,revid=rec['revid'],why=why_,found=NYD))
                continue
            y1=(str(NYD['closed']).strip('[.')[:4])
            if NYD.get('name'):nm_=NYD['name']
            if not y0 and NYD.get('opened'):y0=NYD['opened'][:4]
        kw=float(r['k']) if re.match(r'^[\d.]+$',r['k'] or '') else None
        pk=None;nk=None;pn=None;nn=None
        for q in range(i-1,-1,-1):
            if q in posd and re.match(r'^[\d.]+$',flat[q]['k'] or ''):pk=float(flat[q]['k']);pn=posd[q];break
        for q in range(i+1,len(flat)):
            if q in posd and re.match(r'^[\d.]+$',flat[q]['k'] or ''):nk=float(flat[q]['k']);nn=posd[q];break
        # 1970년 이후 폐지는 노드로 끼워 넣는다. 1950~1969년은 노선도에 다른 노선의 역·화물역·휴지 뒤 폐지역이 섞여(121 중 46만 맞음,
        # docs/research/insert-check-2026-11-06.md) 확인한 역만 data/overrides/wiki_insert.json에 손으로 넣는다
        if int(y1)>=1970:
            if kw is not None and pn and nn:
                ins.append(dict(family=l.get('family'),line=l['name_ja'],name=re.sub(r'(仮|臨時)$','',m.group(1)),close=y1,open=y0,km=kw,prev=ja.get(pn),prev_km=pk,next=ja.get(nn),next_km=nk))
            else:unmatched.append((l['name_ja'],m.group(1),y0,y1,r['k']))
            continue
        # 열람 전용 역 (2회차 종합 K24). 앞뒤 역이 둘 다 있고 이 노선 한 계통 위에 있으면 앞뒤를 계통 순서로 놓고 km를 앞뒤 역의 계통 km 사이로
        # 환산한다. 행은 빼지 않는다(열람 전용 ID는 이름 읽기로 정해져 한 행이 빠지면 같은 이름 다른 행 ID가 바뀐다). 화물 아이콘·다른 계통 사이·
        # 같은 역 사이·위키 km 범위 밖은 km를 비우고 보고서(wiki_archive_kari.json)에 남겨 removed·archive_fix로 판정한다
        nm0=(NYD.get('name') if NYD else None) or re.sub(r'(仮|臨時)$','',m.group(1))
        def _out(why):ARCH_OUT.append((l['name_ja'],nm0,ja.get(prevn),ja.get(nxt),why))
        nxt=next((posd[q] for q in sorted(posd) if q>i),None)
        if not any(re.search(r'BHF|HST',x) for x in icons) or re.search(r'[（(]貨[)）]',r['t']):_out('화물 아이콘')
        pq=next((q for q in range(i-1,-1,-1) if q in posd),None);nq=next((q for q in range(i+1,len(flat)) if q in posd),None)
        ak=lambda q:float(flat[q]['k']) if q is not None and re.match(r'^[\d.]+$',flat[q]['k'] or '') else None
        RS_=sorted(r_by_line[lid_],key=lambda q:q.get('role')!='main')
        rid_=next((q['id'] for q in RS_ if prevn and nxt and prevn!=nxt and rpath.get(q['id']) and prevn in rpath[q['id']] and nxt in rpath[q['id']]),None)
        # 바로 앞뒤 역 행이 한 계통에 없으면(노선도 앞 줄이 갈라진 지선 끝 長門本山인 小野田線 松原) 앞뒤를 같은 계통 경로 위의 가장 가까운 역 행으로 고른다.
        # 갈래 사이에 그려진 다른 계통 역은 건너뛴다. 위키 km가 고른 두 역 사이에 있어야 하는 검사는 그대로라 지선 쪽 역이 본선에 붙지 않는다
        cand_=[(rid_,pq,nq)] if rid_ else []
        if not rid_ and prevn and nxt:
            for q in RS_:
                P0_=set(rpath.get(q['id']) or ())
                a_=next((x for x in range(i-1,-1,-1) if x in posd and posd[x] in P0_),None);b_=next((x for x in range(i+1,len(flat)) if x in posd and posd[x] in P0_),None)
                if a_ is not None and b_ is not None and posd[a_]!=posd[b_]:cand_=[(q['id'],a_,b_,'skip')];break
        km_=None;pick_=None
        for c_ in cand_:
            pv_,nv_=posd[c_[1]],posd[c_[2]];skip_=len(c_)>3
            P_=rpath[c_[0]];K_=rkm(c_[0]);ka,kb=ak(c_[1]),ak(c_[2]);k0_=None
            if kw is not None and ka is not None and kb is not None and ka!=kb:
                if not min(ka,kb)<=kw<=max(ka,kb):
                    if not skip_:_out(f'km {kw} 범위 밖')
                elif K_ and pv_ in K_ and nv_ in K_:k0_=dround(K_[pv_]+(kw-ka)/(kb-ka)*(K_[nv_]-K_[pv_]))
            elif kw is not None and K_ and pv_ in K_ and nv_ in K_ and (ka is None)!=(kb is None):
                # 앞뒤 한쪽 역 행에 위키 km가 없으면(小野田線 雀田) 아는 쪽 역에서 위키 km와 계통 km가 같은 축(0.5 km 안)이고
                # 위키 km가 앞뒤 역 계통 km 사이일 때만 위키 km를 그대로 쓴다 (노선도 맨 끝 너머 역과 같은 규칙)
                kk_,nn_=(kb,nv_) if ka is None else (ka,pv_)
                if abs(K_[nn_]-kk_)<.5 and min(K_[pv_],K_[nv_])<kw<max(K_[pv_],K_[nv_]):k0_=dround(kw)
            # 건너뛰어 고른 앞뒤는 위키 km로 자리가 맞을 때만 쓴다. 아니면 아래 「한 계통에 없음」으로 남긴다
            if skip_ and k0_ is None:continue
            pick_=(c_[0],)+((pv_,nv_) if P_.index(pv_)<P_.index(nv_) else (nv_,pv_));km_=k0_
        if pick_:rid_,aft,bef=pick_
        elif prevn and nxt:
            _out('앞뒤 역이 한 계통에 없음' if prevn!=nxt else '앞뒤가 같은 역');rid_,aft,bef=mainr,prevn,nxt
        else:
            # 노선도 맨 앞·맨 뒤 역 너머: 한쪽 역만 안다. 위키 진행 방향이 계통과 반대면 앞뒤를 바꾸고, km는 그 역의 위키 km와 계통 km가 같은 축일 때만 쓴다
            nb_=prevn or nxt
            rid_=next((q['id'] for q in RS_ if nb_ and nb_ in (rpath.get(q['id']) or ())),mainr)
            aft,bef=(nxt,prevn) if flip_ else (prevn,nxt)
            K_=rkm(rid_) if rid_ else None;ka=ak(pq if prevn else nq)
            km_=dround(kw) if kw is not None and K_ and ka is not None and not flip_ and abs(K_.get(nb_,-99)-ka)<.5 else None
            # 끝 역 너머인데 위키 km가 그 역의 안쪽이면(五日市線 옛 立川–拝島 구간의 역이 拝島 0 km에서 거꾸로 센 km) 같은 축이 아니다
            if km_ is not None and nb_ in (K_ or {}) and ((aft is None and km_>K_[nb_]) or (bef is None and km_<K_[nb_])):km_=None
            if not nb_:_out('앞뒤 역 없음')
        # 노선도 표기를 고친 이름(손 표 name)도 그 행 이름이다
        if [i,znorm(nm0)] not in _wr['s']:_wr['s'].append([i,znorm(nm0)])
        a_=dict(kind='stop',id='a_'+stable(lid_,m.group(1)),line=lid_,route=rid_,after=aft,before=bef,name=nm0,opened=(y0+'-XX-XX') if y0 else None,closed=(y1+'-XX-XX') if y1 else None,km=km_,source=f"wikipedia:{rec['revid']}")
        if not pick_ and not (prevn and nxt) and _br.get('a' if prevn and not nxt else 'b'):a_.update(branch=_br['a' if prevn and not nxt else 'b'][1],branch_at=_br['a' if prevn and not nxt else 'b'][0],brow=i)
        if NYD:
            a_.update(opened=NYD.get('opened') or a_['opened'],closed=NYD['closed'],_ny=True)
            if NYD.get('legal'):a_['legal_abolition']=NYD['legal']
        arch.append(a_)
        stat['archive_stop']+=1
    kmrows[lid_]=[(n,float(flat[i]['k'])) for i,n in pos if re.match(r'^[\d.]+$',flat[i]['k'] or '')]
    # 위키 진행 방향과 계통 순서 비교
    main=r_by_line[lid_][0] if r_by_line[lid_] else None
    flip=False
    if main:
        a=[i for i,n in pos if n==main['from']];b=[i for i,n in pos if n==main['to']]
        if a and b and a[0]>b[-1]:flip=True
    for i,r in enumerate(flat):
        sd=conn.junc_side(r)
        cont=any('CONT' in x for c in r['c'] for x in c)
        if not sd and not cont:continue
        tx=conn.rowtext(r)
        cand=lines_in(tx)
        if not cand:stat['row_no_line']+=1;continue
        # 가장 가까운 역부터 공유 노드를 찾는다
        order=sorted(pos,key=lambda p:abs(p[0]-i))[:8]
        for nm in cand:
            for oid in by_ja[nm]:
                if oid==lid_:continue
                found=None
                for ri,n in order:
                    if oid in st_line.get(n,()):found=n;break
                if not found:continue
                k=(lid_,oid,found)
                if k in seen:continue
                seen.add(k)
                j=dict(line=lid_,other=oid,at=found,source=f"wikipedia:{rec['revid']}",verified=False,valid=[None,'ongoing'])
                if sd:
                    if flip:sd2={'u':'d','d':'u'}[sd]
                    else:sd2=sd
                    j['side']={'u':'up','d':'down'}[sd2]
                if cont and not sd:j['continue']=True
                junc.append(j);stat['junction']+=1
                break
# ---- 선로 연결(이어짐·분기) 행 (DESIGN §2.9, 2회차 종합 K01·K02·K04)
# 위 노선도 행에 더해 ① 끝 역에서 만나는 노선 쌍 ② 근거 표(THROUGH) ③ 이관 전후 노선 ④ 같은 노선 지선 계통의 양 끝을 후보로 만들고,
# 손 판정 표(hand_tables NOCONT·JUNCTION_NOT)와 궤간·선로 방식 표(data/overrides/line_gauge.json → 노선 행 gauge)로 거른다
ops_={o['id']:o for o in load('operators')}
def op_short(l):
    o=ops_.get('o_'+l['family'][1:],{}) if l.get('family')!='jr' else {}
    return re.sub('(電気鉄道|鉄道|鐵道|電鉄|交通局|交通|高速電気軌道)$','',o.get('name_ja','')) or None
def mentions(a,b):
    """a 문서의 '직통' 곁에 b 이름이 있으면 판을 돌려준다. 문서가 없으면 None"""
    if a not in TXT:return None
    v=[lines[b]['name_ja']] if lines[b]['name_ja'] not in('本線','鉄道線','鋼索線') else ([op_short(lines[b])] if len(op_short(lines[b]) or '')>=3 else [])
    T=TXT[a][1]
    for m in re.finditer('直通',T):
        w_=T[max(0,m.start()-30):m.end()+30]
        # 「直通」이 든 문장만 본다. 부정·과거·대체 문장(「直通運転はない」「休止された」「分断された…に代わり」)은 직통 근거가 아니다 (직통·환승 전수 점검 R1, 2026-11-09)
        s0=max(T.rfind('。',0,m.start()),T.rfind('\n',0,m.start()))+1
        s1=min(x for x in (T.find('。',m.end()),T.find('\n',m.end()),len(T)) if x>=0)
        sent=T[s0:s1]
        if NOTTHROUGH.search(sent):continue
        if any(x and x in w_ and x in sent for x in v):return TXT[a][0]
    return False
NOTTHROUGH=re.compile('はない|ではない|ていない|行わない|行われない|できない|休止|廃止|終了|取りやめ|取り止め|中止|打ち切|代わり|分断|不可|できず|行わ(れ)?ず')
ends=collections.defaultdict(set)
for r in routes:
    if not r.get('old'):ends[r['line']]|={r['from'],r['to']}
# ── 궤간·선로 방식. 노선 행 gauge = [{from_node, to_node, gauge, system, valid_from, valid_to}]. 구간이 비면 노선 전체.
# 쇠바퀴 철도(일반 철도·지하철·노면전차)는 서로 들어갈 수 있고(U06), AGT·모노레일·리니어·강삭 등은 같은 방식끼리만 이어진다
STEEL={'rail','subway','tram'}
def sys0(l):
    t=lines[l].get('type');return 'rail' if t=='subway' else t
_gs={}
def gsegs(l):
    """노선 l의 궤간 행 [(구간 칸 집합|None=노선 전체, 시작, 끝, 궤간, 방식)]"""
    if l not in _gs:
        o=[]
        for g in lines[l].get('gauge') or []:
            es=None
            if g.get('from_node') and g.get('to_node'):
                p=lpath(l,g['from_node'],g['to_node']) or []
                es={frozenset(x) for x in zip(p,p[1:])}
            o.append((es,g.get('valid_from') or '0000','9999' if g.get('valid_to') in (None,'ongoing') else g['valid_to'],g.get('gauge'),g.get('system') or sys0(l)))
        _gs[l]=o
    return _gs[l]
def _touch(es,x,nbs):return es is None or any(frozenset((x,n)) in es for n in nbs)
def gat(l,x,nbs,lo,hi):
    """[lo,hi)에 노선 l이 x에서 이웃 nbs 쪽 칸으로 가진 (궤간, 방식) 집합. 이 칸을 덮는 행이 하나도 없는 노선은 노선 종류로 본다.
    덮는 행은 있는데 그 기간을 덮는 행이 없으면 빈 집합(改軌 공사 휴지 등 선로가 없는 기간)"""
    rows=[r_ for r_ in gsegs(l) if _touch(r_[0],x,nbs)]
    if not rows:return {(None,sys0(l))}
    return {(g,s) for es,f,t,g,s in rows if f<=lo and hi<=t}
def gok(p,q):
    (ga,sa),(gb,sb)=p,q
    if sa!=sb and not(sa in STEEL and sb in STEEL):return False
    return ga is None or gb is None or ga==gb
def compat(A,x,nA,B,y,nB):
    """A(x에서 이웃 nA 쪽)와 B(y에서 이웃 nB 쪽) 선로가 이어질 수 있는 기간 [(시작, 끝)]. '0000'·'9999'는 열린 끝"""
    bp={'0000','9999'}
    for l in (A,B):
        for es,f,t,g,s in gsegs(l):bp|={f,t}
    bp=sorted(bp);out=[]
    for lo,hi in zip(bp,bp[1:]):
        if any(gok(p,q) for p in gat(A,x,nA,lo,hi) for q in gat(B,y,nB,lo,hi)):
            if out and out[-1][1]==lo:out[-1]=(out[-1][0],hi)
            else:out.append((lo,hi))
    return out
def clipv(v,per):
    """연결 기간 v=[시작|None, 끝|'ongoing']를 기간 목록 per로 자른다"""
    f0=v[0] or '0000';t0='9999' if v[1] in (None,'ongoing') else v[1];o=[]
    for f,t in per:
        a_=max(f0,f);b_=min(t0,t)
        if a_<b_:o.append([None if a_=='0000' else a_,'ongoing' if b_=='9999' else b_])
    return o
# ── 방향
def vec2(a,b):
    p,q=pos_.get(a),pos_.get(b)
    if not p or not q:return None
    c_=math.cos(math.radians(p['lat']));v=((q['lon']-p['lon'])*c_,q['lat']-p['lat'])
    return v if v!=(0,0) else None
def cosang(u,v):return (u[0]*v[0]+u[1]*v[1])/(math.hypot(*u)*math.hypot(*v))
def turn(a,x,b,y=None):
    """끝 역에서 두 노선의 이웃 역이 이루는 가장 큰 각. 곧게 이어지면 180°, 되돌아가야 하면 0°에 가깝다. 좌표가 없으면 None"""
    y=y or x;best=None
    for p in ladj[a].get(x,()):
        for q in ladj[b].get(y,()):
            u,w=vec2(x,p),vec2(x,q)
            if not u or not w or p==q:continue
            ang=math.degrees(math.acos(max(-1,min(1,cosang(u,w)))))
            best=ang if best is None else max(best,ang)
    return best
def thru(B,x):
    """B가 x를 지나는 계통의 (앞 역, 뒤 역). 본선 계통 먼저. 없으면 None"""
    for r in sorted(r_by_line[B],key=lambda r:r.get('role')!='main'):
        p=rpath.get(r['id'])
        if p and x in p[1:-1]:i=p.index(x);return p[i-1],p[i+1]
    return None
def side_of(B,x,nA):
    """B가 x를 지날 때 이웃 nA 쪽 선로가 갈라지는 방향. B 계통의 앞 역(up)·뒤 역(down) 중 더 같은 쪽 (위키 ABZg+·ABZg와 같은 뜻)"""
    ud=thru(B,x)
    if not ud:return None
    for a in sorted(nA):
        va,vu,vd=vec2(x,a),vec2(x,ud[0]),vec2(x,ud[1])
        if va and vu and vd:return 'up' if cosang(va,vu)>cosang(va,vd) else 'down'
    return None
# 이 각보다 작으면 그 역에서 되돌아가는 것이라 직통으로 보지 않는다 (직통·환승 전수 점검 R2, 2026-11-09). 스위치백 직통은 THROUGH 표로 넣는다
SHARP=75
def sharp(a,b):
    """노면전차끼리는 길모퉁이에서 직각으로 꺾여 이어지므로 되돌아가는 각(30° 미만)만 뺀다"""
    return 30 if lines[a].get('type')==lines[b].get('type')=='tram' else SHARP
# ── 손 판정 표. NOCONT: 같은 역에서 만나도 선로가 이어지지 않는 노선 ID 쌍(근거 없는 자동 후보와 노선도 이어짐 행을 지움).
# JUNCTION_NOT: {line, other|other_route, at, why[, from, to]} 그 역의 그 쌍은 (그 기간에) 선로 연결 없음. 노선도·자동 행을 지운다.
# 둘 다 한 번도 쓰이지 않은 행이 있으면 멈춘다(이름·ID 오타로 조용히 무시되는 일을 막음, 2회차 종합 K02)
NOCONT={frozenset(x[:2]):x for x in HT['NOCONT']}
for k_ in NOCONT:
    if any(l_ not in lines for l_ in k_):raise SystemExit(f'NOCONT 노선 ID가 없습니다: {sorted(k_)}')
NC_USED=set()
def nocont(a,b):
    k_=frozenset((a,b))
    if k_ in NOCONT:NC_USED.add(k_);return True
    return False
JNOT=HT.get('JUNCTION_NOT',[]);JN_USED=set()
for x_ in JNOT:
    if x_['line'] not in lines or (x_.get('other') and x_['other'] not in lines) or x_['at'] not in nodes or not x_.get('why'):raise SystemExit(f'JUNCTION_NOT 행이 틀렸습니다: {x_}')
_RLINE={r['id']:r['line'] for r in routes}
def jnot_per(j):
    """j에 걸리는 JUNCTION_NOT 행들의 '연결 없음' 기간. 쌍의 양쪽 화면 행에 함께 건다"""
    out=[]
    for i_,x_ in enumerate(JNOT):
        # 계통 한정 행(route)은 compile이 그 계통의 연결에만 건다
        if x_['at']!=j['at'] or x_.get('route'):continue
        # 계통 한정 상대(other_route) 행은 그 계통을 가리키는 행과, 계통을 정하지 않은 노선 단위 행(양쪽 화면)에 건다.
        # 노선 단위 행은 compile이 상대 노선의 계통으로 풀어 본선 계통에 붙인다(赤羽線 赤羽·川越線 大宮 → 東北本線 본선, 5회차 2026-11-25).
        # 다른 계통으로 가는 근거 직통은 THROUGH(b_route) 행이 따로 넣는다. 같은 노선 계통끼리 행(東北本線 赤羽)은 늘 계통을 가리키므로 해당 없음
        if x_.get('other_route'):hit=(j['line']==x_['line'] and j.get('other_route')==x_['other_route']) or (not j.get('other_route') and x_['line']!=_RLINE.get(x_['other_route']) and {j['line'],j['other']}=={x_['line'],_RLINE.get(x_['other_route'])})
        else:hit={j['line'],j['other']}=={x_['line'],x_['other']}
        if hit:JN_USED.add(i_);out.append((x_.get('from') or '0000','9999' if x_.get('to') in (None,'ongoing') else x_['to']))
    return out
def minus(v,nots):
    """기간 v에서 '없음' 기간들을 뺀 토막들"""
    per=[('0000','9999')]
    for f,t in nots:
        per=[q for a_,b_ in per for q in ((a_,min(b_,f)),(max(a_,t),b_)) if q[0]<q[1]]
    return clipv(v,per)
# 노선도 행(이어짐·분기)도 NOCONT 쌍이면 지운다
junc=[j for j in junc if not nocont(j['line'],j['other'])]
done_={(j['line'],j['other'],j['at']) for j in junc}
def addj(a,b,x,cont,src,side=None,valid=None,rr=None,verified=False):
    if (a,b,x) in done_ and not rr:return
    done_.add((a,b,x))
    j=dict(line=a,other=b,at=x,source=src,verified=verified,valid=valid or [None,'ongoing'])
    if rr:j['other_route']=rr
    if side:j['side']=side
    if cont:j['continue']=True
    junc.append(j);stat['derived_'+('cont' if cont else 'branch')]+=1
# 국철·JR 묶음: JR 노선과 이관 사슬로 이어진 노선(3セク 등). 같은 역에서 한쪽이 끝나면 선로가 이어진 것으로 본다(예외는 NOCONT·JUNCTION_NOT)
# 노면전차로 바뀐 옛 JR 노선(富山港線)은 넣지 않는다. 이관 앞뒤 노선끼리(같은 선로의 다른 시기)는 서로 연결 후보가 아니다
JRC={l for l in lines if lines[l].get('family')=='jr' and lines[l].get('type')=='rail'}
_ch=True
while _ch:
    _ch=False
    for fl,tl,_,_ in chain:
        if (fl in JRC)!=(tl in JRC) and lines[fl].get('type')==lines[tl].get('type')=='rail':JRC|={fl,tl};_ch=True
CHP={frozenset((fl,tl)) for fl,tl,_,_ in chain}
def same_track(a,b,x):
    """a·b가 이관 앞뒤 노선이고 x에서 두 노선의 칸이 모두 넘겨진 구간이면 같은 선로의 다른 시기다(明知線 국철→明知鉄道).
    한쪽이라도 x 너머에 제 칸이 있으면(北陸本線 敦賀, 阿佐東線 海部) 함께 영업한 기간의 연결 후보다"""
    for fl,tl in ((a,b),(b,a)):
        if (fl,tl) in CHE and all(frozenset((x,n)) in CHE[(fl,tl)] for l_ in (fl,tl) for n in ladj[l_].get(x,())):return True
    return False
def auto_ok(a,b):
    """근거 문서 없이 선로 연결 후보로 보는 쌍: 국철·JR 묶음끼리, 같은 사업자의 같은 종류 노선(노면전차끼리, 철도·지하철끼리)이 한 노드를 함께 쓸 때.
    같은 사업자 역에서 한 노선이 끝나면 선로가 이어진 것이 보통이고, 따로 끝나는 승강장(渋谷 東横線·田園都市線 등)은 NOCONT로 판정한다
    (DESIGN §2.9, 사용자 판단 U02: 정기 직통이 없어도 선로가 이어졌으면 분기)"""
    if a in JRC and b in JRC:return True
    if lines[a].get('family')!=lines[b].get('family') or lines[a].get('family')=='jr':return False
    ta,tb=sys0(a),sys0(b)
    return ta==tb and ta in ('tram','rail') and lines[a].get('rule_class')==lines[b].get('rule_class')
for a in sorted(ends):
    for x in sorted(ends[a]):
        for b in sorted(st_line.get(x,())):
            if b==a or a not in st_line.get(x,()) or same_track(a,b,x):continue
            if (lines[a].get('rule_class')=='shinkansen')!=(lines[b].get('rule_class')=='shinkansen'):continue
            bend=x in ends[b]
            if (a,b,x) in done_ and (b,a,x) in done_:continue
            rv=None;auto=auto_ok(a,b)
            # 사철은 한쪽만 끝나면 같은 사업자끼리만 후보다. 후보 쌍은 손 판정(NOCONT)을 먼저 본다
            if not auto and not bend and lines[a].get('family')!=lines[b].get('family'):continue
            if nocont(a,b):continue
            if not auto:
                # 사철은 노선 문서가 직통을 적어야 한다 (渋谷의 東横線·田園都市線은 안 이어진다)
                rv=mentions(a,b) or mentions(b,a)
                if not rv:continue
            t_=turn(a,x,b)
            if t_ is not None and t_<sharp(a,b):stat['sharp_cont']+=1;continue
            src=f'wikipedia:{rv}' if rv else 'derived'
            if bend:addj(a,b,x,True,src);addj(b,a,x,True,src)
            else:
                # 한쪽만 끝남: 끝나는 쪽은 이어짐, 지나가는 쪽은 그 방향으로 분기 (DESIGN §2.9)
                addj(a,b,x,True,src);addj(b,a,x,False,src,side=side_of(b,x,ladj[a].get(x,())))
        # 노드가 나뉜 같은 역(이름이 같고 0.9 km 안). 자동 후보 쌍(국철·JR 묶음, 같은 사업자 노면전차: 長崎 住吉)은 같은 노드처럼 보고,
        # 사업자가 다른 사철은 양쪽 다 끝나고 양쪽 문서가 서로를 직통으로 적어야 한다 (東横線·みなとみらい線)
        for y in name_nodes.get(znorm(ja.get(x,'')),[]):
            # 역 이전 쌍(moved.json)의 옛 자리와 새 자리는 다른 시기의 같은 역이라 한 노드를 나눈 것이 아니다 (京成千葉（旧）과 千原線의 千葉中央)
            if y==x or not near_ok(x,y) or frozenset((x,y)) in _MVP:continue
            for b in sorted(st_line.get(y,())):
                if b==a or b in st_line.get(x,()) or same_track(a,b,x) or (a,b,x) in done_:continue
                if (lines[a].get('rule_class')=='shinkansen')!=(lines[b].get('rule_class')=='shinkansen'):continue
                bend=y in ends[b]
                if auto_ok(a,b):
                    if nocont(a,b):continue
                    t_=turn(a,x,b,y)
                    if t_ is not None and t_<sharp(a,b):stat['sharp_cont']+=1;continue
                    if bend:addj(a,b,x,True,'derived');addj(b,a,y,True,'derived')
                    else:addj(a,b,x,True,'derived');addj(b,a,y,False,'derived',side=side_of(b,y,ladj[a].get(x,())))
                    continue
                if lines[b].get('family')==lines[a].get('family') or not bend:continue
                if nocont(a,b):continue
                p_,q_=mentions(a,b),mentions(b,a)
                if (p_ and q_) or (p_ and q_ is None) or (q_ and p_ is None):
                    addj(a,b,x,True,f'wikipedia:{p_ or q_}');addj(b,a,y,True,f'wikipedia:{p_ or q_}')
print('이어짐',sum(1 for j in junc if j.get('continue')))
# 신칸센과 재래선은 환승으로 그린다 (§8.1)
junc=[j for j in junc if (lines[j['line']].get('rule_class')=='shinkansen')==(lines[j['other']].get('rule_class')=='shinkansen') or j.get('continue')]
# 근거로 확인한 직통 (hand_tables THROUGH). 한쪽만 끝나고 상대는 지나가는 직통(中目黒·中野), 기간 한정 직통, 스위치백 직통, 노면전차↔철도 직통도 여기서 넣는다.
# 행: {a, b, at: [a 쪽 노드, b 쪽 노드], from, to, src, why[, a_route, b_route, a_side, b_side]}. *_route는 그 쪽 계통(지선), *_side는 그 쪽이
# 지나가는 역일 때의 분기 방향. 판정 표·궤간 거르기 뒤에 더하므로 이 표가 이긴다 (직통·환승 전수 점검 R4–R6, 2026-11-09)
TH=[];TH_SKIP=[]
# 컴파일이 나누는 노드(node_split.json: 지하철역·노면 정류장)의 새 ID로 적은 행은 나누기 전 원 노드로 읽는다. 컴파일이 옮길 노선 쪽 기록을 새 노드로 다시 옮긴다
# (최종 DB의 n_monzen_nakacho_toden처럼 손 표 작성자가 보는 ID를 그대로 쓸 수 있게, 5회차 옛 평면 교차 2차 2026-11-25)
_SPLIT_NEW={x_['new_id']:(x_['node'],set(x_['move_lines'])) for x_ in json.load(open(os.path.join(ROOT,'data','overrides','node_split.json'),encoding='utf-8'))}
for x_ in HT.get('THROUGH',[]):
    for p_,q_,n_,rr_,sd_ in ((x_['a'],x_['b'],x_['at'][0],x_.get('b_route'),x_.get('a_side')),(x_['b'],x_['a'],x_['at'][1],x_.get('a_route'),x_.get('b_side'))):
        if n_ not in nodes and n_ in _SPLIT_NEW:
            if p_ not in _SPLIT_NEW[n_][1]:raise SystemExit(f'THROUGH 행이 나뉜 노드의 옮길 노선이 아닌 노선에 걸렸습니다: {p_} {n_}')
            n_=_SPLIT_NEW[n_][0]
        if p_ not in lines or q_ not in lines or n_ not in nodes:raise SystemExit(f'THROUGH 행의 노선·노드가 없습니다: {p_} {q_} {n_}')
        # 노선이 그 노드를 지나지 않는 행(노선 구성이 바뀐 곳)은 넣지 않고 보고서에 남긴다
        if not _meets(p_,n_):TH_SKIP.append((p_,q_,n_));stat['through_skip']+=1;continue
        j=dict(line=p_,other=q_,at=n_,source=x_.get('src') or 'hand',verified=True,valid=[x_.get('from'),x_.get('to') or 'ongoing'],continue_=True)
        if rr_:j['other_route']=rr_
        if sd_:j['side']=sd_
        # 여객 직통 기간만 적은 행(passenger_only): 선로 연결은 기간 밖에도 자동 판정대로 남는다(11회차 S3)
        if x_.get('passenger_only'):j['_po']=True
        TH.append(j)
        stat['through']+=1
# ── 이관 사슬: 노선 ID가 바뀌어도 선로는 그대로다. 앞 노선(국철 能登線)·뒤 노선(のと鉄道能登線)에 같은 연결을 이관 날짜로 나눠 둔다
def _cp(j,line,other,v):
    # 철도가 노면전차로 바뀐 이관(富山港線)은 선로가 새로 깔린 것이라 복제하지 않는다. 판정 표 쌍도 복제하지 않는다
    if sys0(line)!=sys0(j['line']) or sys0(other)!=sys0(j['other']) or frozenset((line,other)) in NOCONT:return
    if line==other or same_track(line,other,j['at']) or (line,other,j['at']) in done_ or v[0] and v[1] not in (None,'ongoing') and v[0]>=v[1]:return
    done_.add((line,other,j['at']))
    k=dict(j,line=line,other=other,source='derived',verified=False,valid=v);k.pop('continue_',None)
    if j.get('verified'):k['continue']=True
    if k.get('side') and line!=j['line']:
        k['side']=side_of(line,k['at'],ladj[other].get(k['at'],()))
        if not k['side']:k.pop('side')
    junc.append(k);stat['chain_copy']+=1
for j in list(junc)+TH:
    v=j.get('valid') or [None,'ongoing']
    for fl,tl,d,ns in chain:
        if j['at'] not in ns or not d:continue
        if j['line']==tl and fl in st_line.get(j['at'],()):_cp(j,fl,j['other'],[None if not v[0] or v[0]>=d else v[0],d])
        if j['other']==tl and fl in st_line.get(j['at'],()) and not j.get('other_route'):_cp(j,j['line'],fl,[None if not v[0] or v[0]>=d else v[0],d])
        if j['line']==fl and tl in st_line.get(j['at'],()):_cp(j,tl,j['other'],[max(v[0] or d,d),v[1]])
        if j['other']==fl and tl in st_line.get(j['at'],()) and not j.get('other_route'):_cp(j,j['line'],tl,[max(v[0] or d,d),v[1]])
# ── 판정 표와 궤간으로 거르기(근거 THROUGH는 빼고). 기간이 갈리면 행을 나눈다
GCUT=[];out=[]
for j in junc:
    v=j.get('valid') or [None,'ongoing']
    nots=jnot_per(j)
    vs=minus(v,nots) if nots else [v]
    if nots and not vs:stat['junction_not']+=1;continue
    x=j['at'];A,B=j['line'],j['other']
    # 근거 표 밖의 행에서 철도↔노면전차는 같은 사업자일 때만 잇는다(富山 南北接続線–あいの風 같은 노선도 오판을 막음. 근거 직통은 THROUGH, U06)
    if {sys0(A),sys0(B)}=={'rail','tram'} and lines[A].get('family')!=lines[B].get('family'):GCUT.append((A,B,x,j.get('other_route'),v,[]));stat['cross_type']+=1;continue
    nA=ladj[A].get(x,set());nB=ladj[B].get(x,set())
    if j.get('other_route'):
        p=rpath.get(j['other_route']) or []
        nB={p[i+1] for i in range(len(p)-1) if p[i]==x}|{p[i-1] for i in range(1,len(p)) if p[i]==x}
        if A==B:nA=nA-nB
    per=compat(A,x,nA,B,x,nB)
    ws=[w_ for v_ in vs for w_ in clipv(v_,per)]
    if ws!=vs:GCUT.append((A,B,x,j.get('other_route'),v,ws))
    for w_ in ws:out.append(dict(j,valid=w_))
junc=out
# 근거 직통 행이 이긴다: 같은 (노선, 상대, 역) 자동 행을 지우고 넣는다
# 다만 여객 직통 기간만 적은 행(passenger_only)은 선로 연결 판정을 지우지 않는다. 같은 (노선, 상대, 역, 상대 계통)의 자동 행은 그 기간 밖 토막으로 남는다
# (長尾線 瓦町→琴平線: 선로 1951~, 高松築港 여객 직통 1994-06-26~. 宇都宮 日光線: 선로는 곧은 방면, 上野 직통은 折り返し 방면. 11회차 S3)
def _rlo(x):return None if x is None else (x[1:x.index('..')] if str(x).startswith('[') and not str(x).startswith('[..') else ('0000' if str(x).startswith('[..') else x))
def _rhi(x):return 'ongoing' if x in (None,'ongoing') else ((x[x.index('..')+2:-1] or 'ongoing') if str(x).startswith('[') else x)
_thk={(j['line'],j['other'],j['at']) for j in TH if not j.get('_po')}
_thp=collections.defaultdict(list)
for j in TH:
    if j.pop('_po',None):_thp[(j['line'],j['other'],j['at'],j.get('other_route'))].append((_rlo(j['valid'][0]) or '0000','9999' if _rhi(j['valid'][1])=='ongoing' else _rhi(j['valid'][1])))
_out=[]
for j in junc:
    if (j['line'],j['other'],j['at']) in _thk:continue
    k_=(j['line'],j['other'],j['at'],j.get('other_route'))
    if k_ in _thp:
        # 근거 행에 방향 칸이 없으면 선로 연결 행의 방향을 그대로 쓴다(같은 이음이 기간마다 방향만 달라 갈라지지 않게, 伊勢中川·塩尻)
        for t_ in TH:
            if (t_['line'],t_['other'],t_['at'],t_.get('other_route'))==k_ and not t_.get('side') and j.get('side'):t_['side']=j['side']
        # 자른 토막은 자르기 전 기간(track_valid)을 함께 적는다. compile이 끝 역 시기(era)를 그것으로 본다
        for v_ in minus(j.get('valid') or [None,'ongoing'],_thp[k_]):_out.append(dict(j,valid=v_,track_valid=j.get('valid') or [None,'ongoing']));stat['through_po_keep']+=1
        # 근거 행은 선로 연결 행 자리에 둔다(같은 역 이어짐 줄 차례가 근거 행 없던 때와 같게, 長尾線 瓦町)
        for t_ in TH:
            if (t_['line'],t_['other'],t_['at'],t_.get('other_route'))==k_ and not any(t_ is z_ for z_ in _out):_out.append(t_)
        continue
    _out.append(j)
junc=_out+[t_ for t_ in TH if not any(t_ is z_ for z_ in _out)]
for j in junc:
    if j.pop('continue_',None):j['continue']=True
# ── 같은 노선의 지선·옛 경로 계통은 양 끝에서 그 노드를 지나는 같은 노선 다른 계통으로 가리킨다(같은 궤간일 때만, ガーラ湯沢)
ledges_at=collections.defaultdict(list)
for e in edges:ledges_at[(e['seed_line'],e['a'])].append(e);ledges_at[(e['seed_line'],e['b'])].append(e)
rid_line={q['id']:q['line'] for q in routes}
for r in routes:
    if r.get('role')!='branch':continue
    p=rpath.get(r['id'])
    for x,nx_ in ((r['from'],p[1] if p and len(p)>1 else None),(r['to'],p[-2] if p and len(p)>1 else None)):
        others=[q for q in r_by_line[r['line']] if q['id']!=r['id'] and x in (rpath.get(q['id']) or ())]
        # 계통마다 한 줄로 고른 최단 경로(rpath)만 보면, 옛 선형과 새 선형이 함께 있는 노선에서 그 역을 지나지 않는 쪽 길이 골라져 분기가 빠진다
        # (東北本線 松島 ← 松島–高城町, 西鉄 循環線 祇園町·柳橋 ← 옛 경로, ポートライナー 市民広場 ← 空港線). 이 계통 전용이 아닌 그 노선 칸이 그 역에 닿으면 지나가는 길이 있다
        shared_=[(e['b'] if e['a']==x else e['a']) for e in ledges_at.get((r['line'],x),()) if e.get('route_only')!=r['id'] and (not e.get('route_only') or e['route_only'] in rid_line and rid_line[e['route_only']]==r['line'])]
        if not others and not shared_ and p:continue
        if p and nx_:
            nO={n for q in others for P in [rpath[q['id']]] for i,n in enumerate(P) if (i>0 and P[i-1]==x) or (i+1<len(P) and P[i+1]==x)}|set(shared_)
            per=compat(r['line'],x,nO,r['line'],x,{nx_})
            if not per:GCUT.append((r['line'],r['line'],x,r['id'],[None,'ongoing'],[]));stat['branch_gauge']+=1;continue
            vs=clipv([None,'ongoing'],per)
        else:vs=[[None,'ongoing']]
        sd=side_of(r['line'],x,{nx_}) if nx_ else None
        for v in vs:junc.append(dict(line=r['line'],other=r['line'],other_route=r['id'],at=x,source='derived',verified=False,valid=v,**({'side':sd} if sd else {})))
# ── 끝이 아닌 역의 이어짐은 분기로 바꾼다(綾瀬 常磐線·越後湯沢 上越新幹線, 2회차 종합 K01 kanto_1-033). 상대가 그 역에서 끝나면 그쪽으로 갈라지는 방향을,
# 둘 다 지나가면 근거 행의 *_side를 쓴다. 끝난 기간 한정 직통(金沢·八戸)은 그때 끝 역이었으므로 그대로 둔다(compile era_end)
# 옛 선형 계통(route old, 2번안 2026-11-23)의 끝은 옛 선로가 본선과 만나는 곳이지 노선 끝이 아니다 (京津線 옛 御陵 계통 끝 御陵: 東西線 이어짐 상대 계통을 가져감)
def _ends_at(B,y):return [q for q in r_by_line[B] if y in (q['from'],q['to']) and not q.get('old')]
out=[]
for j in junc:
    A,B,x=j['line'],j['other'],j['at'];v=j.get('valid') or [None,'ongoing']
    if not j.get('continue') or x in ends[A] or v[1] not in (None,'ongoing'):out.append(j);continue
    ys=[x]+[y for y in name_nodes.get(znorm(ja.get(x,'')),[]) if y!=x and near_ok(x,y)]
    y=next((y for y in ys if B in st_line.get(y,()) and _ends_at(B,y)),None)
    if j.get('side'):
        j=dict(j);j.pop('continue');out.append(j);stat['cont_to_branch']+=1;continue
    if y:
        k=dict(j);k.pop('continue')
        # 옛 선형 계통은 본 계통과 함께 이 노선의 한 줄이라 상대 계통을 고르는 후보에서 뺀다 (身延線 富士: 옛 富士–入山瀬 계통 1969 전)
        rs=[q for q in r_by_line[B] if not q.get('old') and y in (rpath.get(q['id']) or (q['from'],q['to']))]
        re_=_ends_at(B,y)
        if not k.get('other_route') and len(rs)>1 and len(re_)==1:k['other_route']=re_[0]['id']
        nb=set(ladj[B].get(y,()))
        if k.get('other_route'):
            P=rpath.get(k['other_route']) or []
            nb={P[1]} if P and P[0]==y and len(P)>1 else {P[-2]} if P and P[-1]==y and len(P)>1 else nb
        sd=side_of(A,x,nb)
        if sd:k['side']=sd
        out.append(k);stat['cont_to_branch']+=1;continue
    if j.get('verified'):out.append(j);stat['through_both_pass']+=1;continue
    stat['cont_dropped']+=1
junc=out
# 후보 행이 없어 걸리지 않았어도 두 노선이 실제로 만나는 판정 행은 쓰인 것이다(근거 문서 없는 다른 사업자 쌍의 「선로 연결 없음」, 川部 弘南鉄道黒石線).
# 멈추는 것은 이름·ID가 틀려 만나는 곳이 없는 행뿐이다
NC_USED|={k_ for k_ in NOCONT if set.intersection(*[set(ladj[l_]) for l_ in k_])}
# 계통 한정 상대 행은 실제로 걸린 것만 쓰인 것으로 센다(걸리지 않으면 아무 일도 하지 않으므로 멈춘다). 계통 한정 행(route)은 compile이 따로 센다
JN_USED|={i_ for i_,x_ in enumerate(JNOT) if _meets(x_['line'],x_['at']) and (x_.get('route') or (not x_.get('other_route') and _meets(x_['other'],x_['at'])))}
unused=[sorted(k_) for k_ in NOCONT if k_ not in NC_USED]+[JNOT[i_] for i_ in range(len(JNOT)) if i_ not in JN_USED]
if unused:raise SystemExit(f'쓰이지 않은 NOCONT·JUNCTION_NOT 행: {unused}')
os.makedirs(CAND,exist_ok=True)
if TH_SKIP:print('THROUGH 행 중 노선이 그 노드를 지나지 않아 뺀 것',TH_SKIP)
json.dump(dict(gauge_cut=GCUT,through_skip=TH_SKIP,derived=[(j['line'],j['other'],j['at'],j.get('side'),bool(j.get('continue'))) for j in junc if j['source']=='derived']),open(os.path.join(CAND,'junction_report.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=0)
dump('junctions/wikipedia.yaml',junc,'위키 노선도에서 뽑은 분기. verified는 사람이 확인했다는 뜻')
if set(NYH)-NYH_USED:raise SystemExit(f'archive_fix.json _noyear 행에 맞는 노선도 행이 없습니다: {sorted(set(NYH)-NYH_USED)}')
_a={}
for a in arch:_a.setdefault(a['id'],a)
# 날짜를 문서 본문에서 읽은 행(_ny)은 같은 노선·같은 이름의 노선도 해 행이 있으면 그 행에 맡긴다
_reg={(a['line'],a['name']) for a in _a.values() if not a.get('_ny')}
arch=[a for a in _a.values() if not (a.get('_ny') and (a['line'],a['name']) in _reg)]
for a in arch:a.pop('_ny',None)
for _f in ('archive.yaml',):
    _p=os.path.join(SRC,'archive',_f)
    if os.path.exists(_p):os.remove(_p)
dump('archive/wikipedia.yaml',arch,'위키 노선도에서 뽑은 열람 전용 역')
os.makedirs(CAND,exist_ok=True)
json.dump(years,open(os.path.join(CAND,'wiki_years.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=0)
# 노선도에 같이 적힌 쌍도 역 문서로 거른다. 문서가 없는 역끼리만 그대로 둔다
_h=os.path.join(SRC,'hubs','hub_evidence.json')
if os.path.exists(_h):
    H_=json.load(open(_h,encoding='utf-8'));ev_={tuple(x) for x in H_['evid']};doc_=set(H_['doc']);adj_={tuple(x) for x in H_['adj']}
    pairs={p for p in pairs if p not in adj_ and (p in ev_ or not(p[0] in doc_ or p[1] in doc_))}
# 환승 묶음 ID는 묶인 역 중 JR 역의 이름, 없으면 첫 역의 이름. 겹치면 다른 역의 이름을 붙인다 (DESIGN §2.10)
JRN={x for e in edges if lines.get(e['seed_line'],{}).get('family')=='jr' for x in (e['a'],e['b'])}
_t=os.path.join(SRC,'hubs','hubs.yaml')
_hs=[json.loads(l[2:]) for l in open(_t,encoding='utf-8') if l.startswith('- ')] if os.path.exists(_t) else []
HTAKEN={h['id'] for h in _hs}
HMEM=[set(h['nodes']) for h in _hs]
hw=[]
for a,b in sorted(pairs):
    # 역 자료 근접으로 이미 묶인 쌍은 같은 구성원의 묶음을 또 만들지 않는다 (감사 A2-12: 108쌍이 둘씩)
    if any({a,b}<=m for m in HMEM):continue
    first,second=(b,a) if b in JRN and a not in JRN else (a,b)
    hid='hub_'+first[2:]
    if hid in HTAKEN:hid=hid+'_'+second[2:]
    if hid in HTAKEN:raise SystemExit(f'환승 묶음 ID가 겹칩니다: {hid}')
    HTAKEN.add(hid);hw.append(dict(id=hid,nodes=[a,b],source=['wikipedia'],verified=False))
dump('hubs/wikipedia.yaml',hw,'위키 노선도의 다른 이름 환승')
print('환승 쌍',len(pairs))
json.dump(kmrows,open(os.path.join(CAND,'wiki_km.json'),'w',encoding='utf-8'),ensure_ascii=False)
json.dump(unmatched,open(os.path.join(CAND,'wiki_unmatched.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=0)
# 계통 자리를 못 정해 뺀 열람 전용 역(앞뒤 역이 한 계통 위에 없음·km 범위 밖)과 仮乗降場·臨時駅 표지 후보. 사람이 archive_fix·stop_status로 옮긴다
json.dump(WROWS,open(os.path.join(CAND,'wiki_rows.json'),'w',encoding='utf-8'),ensure_ascii=False)
json.dump(dict(archive_out=ARCH_OUT,kari=KARI,noyear=NOYEAR),open(os.path.join(CAND,'wiki_archive_kari.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=0)
# 끼울 역 후보는 보고서다. 매번 새로 쓰고, 사람이 확인한 것만 data/overrides/wiki_insert*.json으로 옮긴다 (가짜 역 전수 검증 2026-11-09)
_p=os.path.join(CAND,'wiki_insert.json')
json.dump(ins,open(_p,'w',encoding='utf-8'),ensure_ascii=False,indent=0)
print('끼워 넣을 역',len(ins))
print(dict(stat))
