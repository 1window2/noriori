# -*- coding: utf-8 -*-
# 시드 자료(노리츠부시 표, station_database, Wikidata, 이름 표)를 data/source 모듈로 만든다
# 사람이 고친 값은 data/overrides/*.json에 두고 여기서 덮어쓴다
import sys,os,re,json,csv,collections,math,shutil,unicodedata,datetime,glob
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from lib import *
from decimal import Decimal as _Dec,ROUND_HALF_UP as _HUP
def dround(x,n=1):
    """km 반올림은 사사오입이다. float round()는 15.85를 15.8로 내린다(이진 표현·은행가 반올림). 6자리에서 float 잡음을 먼저 지운다"""
    return None if x is None else float(_Dec(repr(round(x,6))).quantize(_Dec(1).scaleb(-n),rounding=_HUP))
import ko
import conn
import en_rules

ONLY=set(sys.argv[1].split(',')) if len(sys.argv)>1 and sys.argv[1]!='all' else None   # 예: jr1 (JR 홋카이도만)
DB=os.path.join(IMP,'stationdb')
N=hidden_insert(official(json.load(open(os.path.join(IMP,'noritsubushi','lines.json'),encoding='utf-8'))))
N+=json.load(open(os.path.join(IMP,'stationdb','old_lines.json'),encoding='utf-8'))
# N05와 교차 검증한 옛 폐선 (tools/gen_n05.py). N05를 끄면 빈 목록이다
N5=json.load(open(os.path.join(IMP,'n05','lines.json'),encoding='utf-8')) if source_on('n05') else []
N+=N5
def n5name(t):
    """N05 행의 노선 이름. 이음 행은 이어 붙인 기존 표의 제목(괄호 없는 노리츠부시 꼴)을 쓴다"""
    m=re.search(r'【(?:.* )?(.+?)】',t)
    return m.group(1) if m else t.split(' ')[0]
N5NAMES={n5name(x['t']) for x in N5}
# N05 노선 읽기(위키 문서 첫 줄)는 다른 읽기가 없을 때만. 같은 이름의 기존 노선 읽기를 바꾸면 그 노선의 ID가 바뀐다
N5KANA={(x.get('cn') or '')+'|'+n5name(x['t']):x['line_kana'] for x in N5 if x.get('line_kana')}

JRCO={1:'o_jr_hokkaido',2:'o_jr_east',3:'o_jr_central',4:'o_jr_west',5:'o_jr_shikoku',6:'o_jr_kyushu'}
JRJA={'o_japanese_national_railways':'日本国有鉄道','o_jr_hokkaido':'JR北海道','o_jr_east':'JR東日本','o_jr_central':'JR東海','o_jr_west':'JR西日本','o_jr_shikoku':'JR四国','o_jr_kyushu':'JR九州'}
JRKO={'o_japanese_national_railways':'국철','o_jr_hokkaido':'JR 홋카이도','o_jr_east':'JR 동일본','o_jr_central':'JR 도카이','o_jr_west':'JR 서일본','o_jr_shikoku':'JR 시코쿠','o_jr_kyushu':'JR 큐슈'}
BRT={tuple(x) for x in HT['BRT']}
LEGAL=HT['LEGAL']

# ---- 원천 읽기
KANA={}
# 이름 열쇠 읽기의 출처: ('wiki', 문서 제목) · ('hand',) · ('est',) · ('n05', {사업자}). 위키 문서·N05 다른 노선 표의 읽기는 그 이름의 특정 역 읽기라
# 같은 이름의 다른 역에 빌려 주면 안 된다 (3회차 kyushu_1-005 唐浜, 9회차 N)
KSRC={}
for a,b in json.load(open(os.path.join(IMP,'wiki','kana.json'),encoding='utf-8')).items():
    nm=a.split(':',1)[1];t=b['title']
    if znorm(nm)[:2] not in znorm(t):continue
    KANA[a]=re.sub(r'(えき|ていりゅうじょう|ていりゅうしょ|でんてい)$','',b['kana']);KSRC[a]=('wiki',t)
_k=os.path.join(ROOT,'data','overrides','kana.json')
if os.path.exists(_k):
    _kh=json.load(open(_k,encoding='utf-8'));KANA.update(_kh);KSRC.update({a:('hand',) for a in _kh})
NAMEKO=json.load(open(os.path.join(ROOT,'data','overrides','names_ko.json'),encoding='utf-8'))
_e=os.path.join(ROOT,'data','overrides','kana_est.json')
if os.path.exists(_e):
    _ke=json.load(open(_e,encoding='utf-8'));KANA.update(_ke);KSRC.update({a:('est',) for a in _ke})
# N05 노선 표의 역 읽기는 그 노선 열쇠로 둔다. 이름 열쇠는 같은 글자에 읽기가 하나뿐일 때만 (平野町 ひらのまち·ひらのちょう, 2회차 종합 K13)
N5ST={(x.get('cn') or '')+'|'+n5name(x['t']):x.get('kana',{}) for x in N5}
_n5r=collections.defaultdict(set)
for x in N5:
    for a,k in x.get('kana',{}).items():_n5r[a].add(kata2hira(k))
KANA_AMBIG={a for a,v in _n5r.items() if len(v)>1}
# 공개 ID의 내부 키는 예전 읽기 순서로 만든다. 읽기를 고쳐도 ID가 바뀌면 안 된다 (ID 개명은 W3에서 리다이렉트와 함께)
KANA_ID=dict(KANA)
for x in N5:
    for a,k in x.get('kana',{}).items():KANA_ID.setdefault('node:'+a,k)
# 이름 열쇠 표는 그 노선 원문(N5ST_LK)이 없는 노드에만 쓴다. N05 노선 역은 위의 노선 열쇠가 먼저다
for x in N5:
    for a,k in x.get('kana',{}).items():
        if 'node:'+a not in KANA:KANA['node:'+a]=k;KSRC['node:'+a]=('n05',set())
        if KSRC.get('node:'+a,('',))[0]=='n05' and kata2hira(KANA['node:'+a])==kata2hira(k):KSRC['node:'+a][1].add(x.get('cn') or '')
_g=os.path.join(ROOT,'data','overrides','kana_est_report.json')
GUESS=set(json.load(open(_g,encoding='utf-8')).get('guess',[])) if os.path.exists(_g) else set()
OPKO=json.load(open(os.path.join(ROOT,'data','overrides','operators_ko.json'),encoding='utf-8')) if os.path.exists(os.path.join(ROOT,'data','overrides','operators_ko.json')) else {}
SD=list(csv.DictReader(open(DB+'/station.csv',encoding='utf-8')))
SL=list(csv.DictReader(open(DB+'/line.csv',encoding='utf-8')))
REG=list(csv.DictReader(open(DB+'/register.csv',encoding='utf-8')))
sl={l['code']:l for l in SL}
st_lines=collections.defaultdict(set)
for r in REG:st_lines[r['station_code']].add(r['line_code'])
byname=collections.defaultdict(list)
for s in SD:
    s['lat_']=float(s['lat']);s['lng_']=float(s['lng'])
    s['base']=[znorm(conn.clean(sl[c]['name'])) for c in st_lines[s['code']]]
    s['comp']={sl[c]['company_code'] for c in st_lines[s['code']]}
    for nm in {znorm(s['name']),znorm(s['original_name'])}:byname[nm].append(s)
def dist(a,b):
    if not a or not b:return 1e9
    p=math.radians((a[0]+b[0])/2)
    return math.hypot((a[0]-b[0])*111.0,(a[1]-b[1])*111.0*math.cos(p))
WD=collections.defaultdict(list)
wdraw=json.load(open(os.path.join(IMP,'wikidata','stations.json'),encoding='utf-8'))['results']['bindings'] if source_on('wikidata') else []
_w={}
for r in wdraw:
    q=r['s']['value'].rsplit('/',1)[1];x=_w.setdefault(q,{'q':q,'lines':set()})
    for k in('ja','ko','en','kana','open','close','dis','inc'):
        if k in r:x.setdefault(k,r[k]['value'])
    if 'coord' in r and 'pt' not in x:
        m=re.match(r'Point\(([-\d.]+) ([-\d.]+)\)',r['coord']['value'])
        if m:x['pt']=(float(m.group(2)),float(m.group(1)))
    if 'lineLabel' in r:x['lines'].add(r['lineLabel']['value'])
for x in _w.values():
    x['opens']=set()
for r in wdraw:
    if 'open' in r:_w[r['s']['value'].rsplit('/',1)[1]]['opens'].add(r['open']['value'])
for x in _w.values():
    if x['opens']:x['open']=min(x['opens'])
    if 'ja' in x:
        WD[znorm(re.sub(r'\s*[（(].*?[)）]\s*','',x['ja']))].append(x)
def wdday(v):
    if not v or not re.match(r'^\d{4}-\d\d-\d\d',v):return None
    d=v[:10]
    if d.endswith('-01-01'):return d[:4]+'-XX-XX'
    return d

SIGNALISH=re.compile(r'(信号場|分岐点|信号所|貨物ターミナル|貨物駅|操車場|接続点)$')
def prx_op(p):
    return PUB.get(PRX[p.name],PRX[p.name]) if p.name in PRX else 'o_tokyu_railways'
_ids=json.load(open(os.path.join(ROOT,'data','imports','id_map.json'),encoding='utf-8'))
PUB=_ids['ids']
# 동결 전 공개 ID 개명(data/overrides/id_rename.json rename 행, 2회차 결정 U12). id_map은 공개하지 않는 원천 표라 고치지 않고 여기서 바꾼다
for _r in json.load(open(os.path.join(ROOT,'data','overrides','id_rename.json'),encoding='utf-8'))['rows']:
    # key: 구조를 바꿔 새로 생긴 내부 키(노선을 합친 계통 등)에 옛 공개 ID를 그대로 준다. 기록에 저장된 계통 ID가 살아 있게
    if _r['kind']=='key':
        for k_ in [k_ for k_,v_ in PUB.items() if v_==_r['new']]:del PUB[k_]
        PUB[_r['key']]=_r['new'];continue
    # 열람 전용 역(a_) 개명은 생성기 gen_extra가 읽기로 ID를 다시 매기고 컴파일이 id_redirect만 낸다 (9회차 N)
    if _r['kind']!='rename' or _r['old'].startswith('a_'):continue
    _ks=[k_ for k_,v_ in PUB.items() if v_==_r['old']]
    if len(_ks)!=1 or _r['new'] in PUB.values():raise SystemExit(f"id_rename.json 행을 쓸 수 없습니다: {_r['old']} → {_r['new']}")
    PUB[_ks[0]]=_r['new']
OLD={v:k for k,v in PUB.items()};FAM=_ids['family'];FAM_OLD={v:k for k,v in FAM.items()}
PRXN=HT['PRXN']
PRX={}
LINEKANA=json.load(open(os.path.join(ROOT,'data','overrides','lines_kana.json'),encoding='utf-8'))
# ---- 부품 파싱
_co={}
for x in N:
    if x.get('cn') and x['g']=='pr':_co[x['cn']]=str(x['c'])
for a,b in PRXN.items():PRX[a]='o_'+_co[b]
RENAME=HT['RENAME']
# station_database 역에 붙이지 않는 역. 같은 이름의 다른 자리 (東唐津: 1983년, 楓: 1981년, 常磐線 新地·坂元·山下: 2016년 이전 전의 옛 역)
NOSD={tuple(x) for x in HT['NOSD']}
# 원천 좌표가 같은 이름의 다른 지방 역을 가리키는 노드. 묶음 판정 전에 고친다 (좌표, 출처, 도도부현)
POSFIX={k:(v['lat'],v['lon'],v['src'],v['pref']) for k,v in HT['POSFIX'].items()}
LINEOPEN=HT['LINEOPEN']
BYLINEKO=HT['BYLINEKO']
SUSPENDED=json.load(open(os.path.join(ROOT,'data','overrides','suspended.json'),encoding='utf-8'))
JAFIX=HT['JAFIX']
N02AL=HT['N02AL']
STOPCLOSE=HT['STOPCLOSE']
FORCE_PAIR={tuple(x) for x in HT['FORCE_PAIR']}
BRTDAY={tuple(x[:-1]):x[-1] for x in HT['BRTDAY']}
LAST=HT['LAST']
# 재해로 끊긴 채 끝난 구간: 노선 -> [(역, 역, 실제 마지막 운행일)]
SVC={k:[tuple(x) for x in v] for k,v in HT['SVC'].items()}
OPENFIX={k:[tuple(x) for x in v] for k,v in HT['OPENFIX'].items()}
# 노리츠부시 표에 현재 회사만 있는 노선의 앞선 사업자: 노선 -> (앞선 회사, 바뀐 날)
OPHIST={k:tuple(v) for k,v in HT['OPHIST'].items()}
OPHIST_KO=HT['OPHIST_KO']
OPHIST_ID=HT['OPHIST_ID']
REASON=HT['REASON']
class P:pass
parts=[]
RX=re.compile(r'^(.+?)(?: \((.+?)\))? (\S.*?) ～ (\S.*?) 営業km: ([\d.]+)$')
for x in N:
    m=RX.match(x['t'])
    p=P();p.id=x['id'];p.g=x['g'];p.c=str(x['c']);p.cn=x.get('cn') or ''
    p.x_svc=x.get('svc') or [];p.x_legal=x.get('legal') or []
    p.n05pt=x.get('n05pt') or {};p.arch=x.get('arch') or [];p.jr=bool(x.get('jr'))
    # N05 행의 휴지·재개 (gen_n05의 손 대조 표). suspended.json과 같은 모양 [a, b, 시작일, 메모, 재개일]
    p.x_susp=x.get('susp') or []
    p.n05alt=False
    # 손 대조의 이음 행 (gen_n05 join). 지선 계통이 본선 선로를 같이 쓰는 칸은 사건을 내지 않는다
    p.n05join=bool(x.get('join'))
    p.n05shared=bool(x.get('shared'))
    # 부모 노선에 합친 손 대조 토막·지선·옛 선로 항목(gen_n05 subsec). 따로 노선이던 때처럼 본선의 이설 창·옛 선로(alt)로 보지 않는다
    p.n05subsec=bool(x.get('subsec'))
    # 여객 영업 km가 따로 없는 화물·연결선을 모선의 지선 계통으로 둘 때, 그 계통의 칸은 분모 밖이다 (official_lines.json route_extra, 사용자 결정 2026-11-09)
    p.route_extra=bool(x.get('route_extra'))
    # 여객 영업 이력이 없는 화물선. DB에만 두고 목록·검색·분모에서 뺀다 (official_lines.json no_passenger, 사용자 결정 2026-11-09)
    p.no_passenger=bool(x.get('no_passenger'))
    # 값의 출처. 노리츠부시 표가 기본이고 옛 폐선 표(gen_old)는 부품마다 적혀 있다
    p.s={k:(x.get('src') or {}).get(k,'noritsubushi') for k in ('km','stop','line','open','close','op')};p.hand_open=set()
    if m:p.name,p.paren,p.frm,p.to,km=m.groups();p.km=float(km)
    else:
        m2=re.search(r'【(.+?)(?: \((.+?)\))?】',x['t'])
        p.name,p.paren=m2.groups();p.frm=x['s'][0][0];p.to=x['s'][-1][0];p.km=float(x['s'][-1][1])
    if p.g=='prx':p.name=p.name.split()[-1]
    elif p.cn and p.name.startswith(p.cn+' '):p.name=p.name[len(p.cn)+1:]
    m3=re.search(r'(\d{4}-\d\d-\d\d)\s*まで|～(\d{4}-\d\d-\d\d)',p.paren or '')
    p.until=(m3.group(1) or m3.group(2)) if m3 else None
    p.open=[];p.close=[]
    for t in x.get('h',[]):
        if not t:continue
        h=''.join(t[0])
        if '開業日' in h:p.open=[r for r in t[1:] if len(r)>=3]
        elif '廃止日' in h:p.close=[r for r in t[1:] if len(r)>=3]
    p.st=[]
    for lab,k in x['s']:
        o=P();o.label=lab;o.km=float(k);o.n05=p.n05pt.get(lab)
        # N05 역 기간으로 정한 가운데 역의 폐지·개업 해 (gen_n05)
        o.n05close=(x.get('sclose') or {}).get(lab.strip('*'));o.n05open=(x.get('sopen') or {}).get(lab.strip('*'));o.n05src=x.get('sdate_src','n05')
        # 営業キロ를 몰라 N05 선 위 위치로 km를 추정한 역 (DESIGN §4.5 `? km`)
        o.km_est=lab.strip('*') in set(x.get('km_est') or [])
        o.closed=lab.startswith('*') or lab.endswith('*')
        o.hidden=lab.startswith('[') and lab.endswith(']')
        o.old='【旧】' in lab
        if o.old:o.closed=True
        o.name=re.sub(r'^\(臨\)','',lab.strip('*').strip('[]').strip()).replace('【旧】','')
        o.kind=None
        if o.name.startswith('〈貨〉'):o.kind='freight'
        if o.name.endswith('(信)'):o.kind='signal'
        o.name=re.sub(r'^〈貨〉|\((信|仮)\)$','',o.name)
        o.alt=(re.search(r'（旧(.*?)）',o.name) or [None,None])[1]
        o.name=re.sub(r'（旧.*?）','',o.name);o.nm=znorm(o.name)
        o.mnm=RENAME.get(o.nm,o.nm) if x['g'] in('tm','old') else o.nm
        if x['g'] in('jrx','prx') and re.search('（.*(方|通過|八木西口).*）',lab):o.nm=o.name;o.mnm=o.name;o.hidden=True
        p.st.append(o)
    p.family='jr' if p.g in('jr','jrx') or (p.g=='tm' and p.c=='9') or p.jr else ('p'+PRX[p.name][2:] if p.g=='prx' else 'p'+p.c)
    if p.g=='prx':p.c=PRX[p.name][2:]
    p.extra=p.g=='ex'
    parts.append(p)
# 위키 노선도에만 있는 옛 역(1950년 이후 폐지)을 km 위치에 끼워 넣는다. km를 모르면 앞뒤 역 가운데에 두고 추정 km다
# 사람이 확인한 끼우기만 쓴다(wiki_insert*.json, 담당별 파일 포함). 후보 파일(data/candidates/wiki_insert.json)은 보고서일 뿐이다.
# 검토 안 된 후보를 그대로 끼웠더니 노선도 옆 칸(노면전차·화물선·다른 사철)의 역이 그 노선 역이 됐다 (가짜 역 전수 검증 2026-11-09: 南海本線 住吉公園 등 9건)
INS=[x for f_ in sorted(glob.glob(os.path.join(ROOT,'data','overrides','wiki_insert*.json'))) for x in json.load(open(f_,encoding='utf-8'))]
OLDNAMES0=json.load(open(os.path.join(ROOT,'data','overrides','old_names.json'),encoding='utf-8'))
NFIX0=json.load(open(os.path.join(ROOT,'data','overrides','node_fix.json'),encoding='utf-8'))
OLDKANA0={k:v['kana'] for k,v in json.load(open(os.path.join(ROOT,'data','overrides','old_names_kana.json'),encoding='utf-8')).items() if v.get('kana')}
by_pl=collections.defaultdict(list)
for x in INS:
    x['family']=FAM_OLD.get(x.get('family'),x.get('family'))
    by_pl[(x.get('family'),x['line'])].append(x)
placed=0;placed_old=0;old_skip=[]
def old_site(p,x):
    """역 이전의 옛 자리(wiki_insert_moves.json, old: true)를 【旧】 역처럼 따로 노드로 둔다 (재설계 결정 7).
    끝 역 너머(terminal)면 끝에 붙이고 옛–새 칸을 edge_close에 닫는다. 끝 역 앞 옛 자리는 edge_open에 옛–새 칸이 열린다.
    relabel은 옛 부품의 같은 이름 역을 옛 노드로 돌린다. 공개 ID는 행의 id 그대로다"""
    nm=znorm(x['name'])
    # 한 부품에 같은 이름 옛 자리가 여럿일 수 있다(夕張支線 夕張 18.2·16.9 → 지금 16.1). 표기는 구간 행이 역을 찾는 열쇠라 겹치지 않게
    # 두 번째부터 【旧2】·【旧3】으로 둔다(노리츠부시 표기 별칭·내보내기 이름은 【旧】로 되돌린다)
    labs_={q.label.strip('*[]') for q in p.st}
    lab_=x['name']+'【旧】';i_=2
    while lab_ in labs_:lab_=f"{x['name']}【旧{i_}】";i_+=1
    def mk(k,est):
        o=P();o.label=lab_;o.km=k;o.closed=True;o.hidden=False;o.old=True;o.kind=None;o.alt=None
        o.name=x['name'];o.nm=nm;o.mnm=nm;o.wclose=x['close'];o.wopen=x.get('open');o.km_est=est;o.force_id=x['id'];o.n05=None;o.move_of=x['new_node']
        return o
    if any(o.old and o.nm==nm and (x.get('km') is None or abs(o.km-x['km'])<.15) for o in p.st):old_skip.append((x,'이미 【旧】 역 있음'));return 0
    if x.get('mode')=='relabel':
        c=[o for o in p.st if o.nm==nm and abs(o.km-x['km'])<.15]
        if not c:old_skip.append((x,'relabel 대상 없음'));return 0
        o=c[0];o.old=True;o.closed=True;o.wclose=x['close'];o.force_id=x['id'];o.move_of=x['new_node']
        # 표기도 옛 자리로 둔다. 기점 너머 옛 자리 행과 사슬이 이어지면 구간 행(貝塚【旧】～貝塚)이 이 표기로 옛 자리를 찾는다
        o.label=('*' if o.label.startswith('*') else '')+x['name']+'【旧】'
        return 1
    est=bool(x.get('km_est'))
    # 끝 역 너머 행은 그 끝 역(prev·next)으로 끝나는 부품에만 붙인다. 같은 이름 노선의 다른 부품(室蘭本線 長万部–岩見沢)에 붙이지 않는다
    if x.get('terminal')=='end' and p.st[-1].nm!=znorm(x['prev'] or ''):old_skip.append((x,'끝 역이 다른 부품'));return 0
    if x.get('terminal')=='start' and p.st[0].nm!=znorm(x['next'] or ''):old_skip.append((x,'첫 역이 다른 부품'));return 0
    if x.get('terminal')=='end':
        # km 원문이 없으면 끝 역 너머 0.1 km에 두고 추정 km다
        end=p.st[-1];d_=(x['km']-x['prev_km']) if x['km'] is not None and x.get('prev_km') is not None else None
        o=mk(dround(end.km+d_) if d_ else dround(end.km+.1),est or not d_);p.st.append(o)
        sec=f"{end.label.strip('*[]')}～{o.label}"
    elif x.get('terminal')=='start':
        end=p.st[0];d_=(x['next_km']-x['km']) if x['km'] is not None and x.get('next_km') is not None else None
        o=mk(dround(end.km-d_) if d_ else dround(end.km-.1),est or not d_);p.st.insert(0,o)
        sec=f"{o.label}～{end.label.strip('*[]')}"
    else:
        a=next((o for o in p.st if o.nm==znorm(x['prev'] or '')),None)
        b=next((o for o in p.st if o.nm==znorm(x['next'] or '') and not o.old),None)
        if not a or not b:old_skip.append((x,'앞뒤 역 없음'));return 0
        ia,ib=p.st.index(a),p.st.index(b);lo,hi=sorted((ia,ib))
        k=x['km']
        # 행의 km는 노선 기점 누적이라 부품의 km 기준과 다를 수 있다(関西本線 加美 165.7). 앞 역과의 차이로 옮긴다
        if k is not None and x.get('prev_km') is not None:k=dround(a.km+(x['km']-x['prev_km'])*(1 if b.km>=a.km else -1))
        if k is None or not min(a.km,b.km)<k<max(a.km,b.km):k=dround((a.km+b.km)/2);est=True   # km 원문이 없거나 범위 밖이면 앞뒤 역 가운데, 추정 km
        if any(abs(q.km-k)<.05 for q in p.st[lo:hi+1]):old_skip.append((x,'같은 km 역 있음'));return 0
        o=mk(k,est);pos=hi
        for j in range(lo+1,hi):
            if (p.st[j].km-k)*(1 if a.km<b.km else -1)>0:pos=j;break
        p.st.insert(pos,o)
        # 이전일에 열리는 칸은 옛 자리와 새 역 사이다. 새 역이 뒤(next)면 옛–새(多摩湖), 앞(prev)이면 새–옛(기점 쪽으로 옮긴 京阪 天満橋·市電川崎, 6회차 2026-11-14)
        if x.get('edge_open'):
            sec_=f"{a.label.strip('*[]')}～{o.label}" if znorm(x['prev'] or '')==nm and znorm(x['next'] or '')!=nm else f"{o.label}～{b.label.strip('*[]')}"
            p.open=list(p.open)+[[sec_,'0',x['edge_open']]];p.hand_open.add(x['edge_open'])
        return 1
    # 끝 역 너머 칸: 옛 자리가 열린 날 열리고 이전일에 닫힌다
    # 옛 자리가 역이 되기 전부터 선로가 있었으면(貝塚: 1924 선로, 1950 西鉄多々良 역) 행의 edge_open이 옛–새 칸이 열린 날이다
    eo_=x.get('edge_open') or x.get('open')
    p.open=list(p.open)+[[sec,'0',eo_]];p.hand_open.add(eo_)
    if x.get('edge_close'):p.close=list(p.close)+[[sec,'0',x['edge_close']]]
    return 1
for p in parts:
    for x in (by_pl.get((p.family,p.name),[])+(by_pl.get((p.family,p.name+' '+p.paren),[]) if getattr(p,'n05subsec',False) and p.paren else [])):
        # 같은 이름 부품이 여럿이면(東北本線) 앞뒤 역이 있는 부품 하나에만 넣는다
        if x.get('hold'):continue   # 넣기 전에 판정이 더 필요한 행(사유는 행에)
        if x.get('old'):
            # hold: 넣기 전에 판정이 더 필요한 행(사유는 행에)
            if not x.get('hold') and not x.get('_done') and old_site(p,x):x['_done']=True;placed_old+=1
            continue
        nm=znorm(x['name'])
        if any(o.nm==nm for o in p.st):continue
        # 앞뒤 역은 지금 역으로 찾는다. 같은 이름 옛 자리(鎌倉【旧】)를 잡으면 끝 너머에 끼워진다
        a=next((o for o in p.st if o.nm==znorm(x['prev'] or '') and not o.old),None)
        b=next((o for o in p.st if o.nm==znorm(x['next'] or '') and not o.old),None)
        if not a or not b or (x['km'] is not None and x['next_km']==x['prev_km']):continue
        ia,ib=p.st.index(a),p.st.index(b)
        if abs(ia-ib)<1:continue
        # km_est: km를 원문이 아니라 위치(N05 역 점의 선상 투영 등)로 정한 행
        nokm=x['km'] is None or x['prev_km'] is None or x['next_km'] is None
        est=nokm or bool(x.get('km_est'))
        f=.5 if nokm else (x['km']-x['prev_km'])/(x['next_km']-x['prev_km'])
        if not 0<f<1:continue
        k=dround(a.km+(b.km-a.km)*f)
        lo,hi=sorted((ia,ib))
        cl_=bool(x.get('close'))   # 폐지일이 없으면 지금 영업하는 역(지금 臨時駅 田井ノ浜 등)
        o=P();o.label=('*' if cl_ else '')+x['name'];o.km=k;o.closed=cl_;o.hidden=False;o.old=False;o.kind=None;o.alt=None;o.name=x['name'];o.nm=nm;o.mnm=nm;o.wclose=x['close'];o.wopen=x.get('open');o.km_est=est
        pos=hi
        for j in range(lo+1,hi):
            if (p.st[j].km-k)*(1 if a.km<b.km else -1)>0:pos=j;break
        if any(abs(q.km-k)<.05 for q in p.st[lo:hi+1]):continue
        # 읽기 근거가 없는 역은 행에 임시 공개 ID를 둔다. 화면 이름은 일본어 표기 그대로다 (명세 결정 6)
        if x.get('id'):o.force_id=x['id']
        o.skip_nb=bool(x.get('skip_neighbor_check'))
        p.st.insert(pos,o);placed+=1
_miss={id(x):(x,why) for x,why in old_skip if not x.get('_done') and not x.get('hold')}
print('옛 역 삽입',placed,'옛 자리',placed_old,'못 넣음',len(_miss))
for x,why in _miss.values():print('  옛 자리 못 넣음',x['line'],x['name'],why)
def want(p):
    if ONLY is None:return True
    if p.g=='jr':return f'jr{p.c}' in ONLY or 'jr' in ONLY
    if p.g=='tm' and p.c=='9':return 'jr' in ONLY or 'tm' in ONLY
    return p.family in ONLY
JR_ONLY=ONLY is not None and any(o.startswith('jr') and o!='jr' for o in ONLY)
if JR_ONLY:
    # 슬라이스: 그 회사 역을 지나는 폐선만 함께 넣는다
    nm={s.nm for p in parts if want(p) for s in p.st}
    for p in parts:
        if p.g=='tm' and p.c=='9':p.keep=len({s.nm for s in p.st}&nm)>=2
    parts=[p for p in parts if want(p) and getattr(p,'keep',True)]
elif ONLY is not None:
    parts=[p for p in parts if want(p)]

for p in parts:
    p.svc=[[f'{a}～{b}','0',d] for a,b,d in SVC.get(p.name,[])]+[[f'{a}～{b}','0',d] for a,b,d in getattr(p,'x_svc',[])]
    p.legal=[[f'{a}～{b}','0',d] for a,b,d in getattr(p,'x_legal',[])]
    for a,b,d in OPENFIX.get(p.name,[]):p.open=list(p.open)+[[f'{a}～{b}','0',d]];p.hand_open.add(d)
    # 神戸高速線은 1968-04-07부터 여객 영업. 1988-04-01은 각 사의 제2종 면허 시작일이다
    if '神戸高速線' in p.name:p.open=[[r[0],r[1],'1968-04-07' if str(r[2]).startswith('1988-04-01') else r[2]] for r in p.open];p.hand_open.add('1968-04-07')
# ---- 역 대조
def match(o,p,prev):
    c=byname.get(o.mnm,[])
    if not c:return None
    base=znorm(p.name)
    best=None;bs=-1e9
    for s in c:
        sc=0
        if any(base==b or base in b or b in base for b in s['base']):sc+=4
        if p.family=='jr' and (s['comp']&{'1','2','3','4','5','6'}):sc+=2
        if p.family!='jr' and not (s['comp']&{'1','2','3','4','5','6'}):sc+=1
        pt=(s['lat_'],s['lng_'])
        d=dist(prev,pt) if prev else 0
        if prev:
            if d<12:sc+=3
            elif d<40:sc+=1
            elif d>120:sc-=4
        sc-=min(d,200)/200
        if s['closed']=='1' and not o.closed and p.g!='tm':sc-=1
        if sc>bs:bs=sc;best=s
    return best
for p in sorted(parts,key=lambda p:(p.g!='jr',p.id)):
    prev=None
    for o in p.st:
        o.sd=match(o,p,prev)
        if o.sd:prev=(o.sd['lat_'],o.sd['lng_'])
    # 앞쪽 끝 역이 틀렸을 때를 대비해 역방향으로 한 번 더 본다
    nxt=None
    for o in reversed(p.st):
        if o.sd is None or not nxt or dist((o.sd['lat_'],o.sd['lng_']),nxt)>40:
            s=match(o,p,nxt)
            if s:o.sd=s
        if o.sd:nxt=(o.sd['lat_'],o.sd['lng_'])

# 앞뒤 역과 거리가 영업km로 설명되지 않으면 다시 고른다
def pt_of(o):return (o.sd['lat_'],o.sd['lng_']) if o.sd else None
fixed=0
for p in parts:
    for _ in range(2):
        for i,o in enumerate(p.st):
            if not o.sd:continue
            nb=[]
            # 행에 「이웃 대조에서 건너뜀」을 단 끼운 역(栄町口)은 그 너머 역을 본다. 끼우기 전과 같은 이웃이라 옆 역의 대조가 바뀌지 않는다
            for d_ in (-1,1):
                j=i+d_
                while 0<=j<len(p.st) and getattr(p.st[j],'skip_nb',False):j+=d_
                if 0<=j<len(p.st) and p.st[j].sd:nb.append((pt_of(p.st[j]),abs(p.st[j].km-o.km)))
            if not nb:continue
            if all(dist(pt_of(o),q)>k*1.5+5 for q,k in nb):
                c=sorted(byname.get(o.nm,[]),key=lambda s:min(dist((s['lat_'],s['lng_']),q) for q,k in nb))
                best=c[0] if c and min(dist((c[0]['lat_'],c[0]['lng_']),q)-k*1.5-5 for q,k in nb)<=0 else None
                o.sd=best;fixed+=1
print('좌표 재대조',fixed)

# 노드 묶기(union-find)
par={}
def find(x):
    par.setdefault(x,x)
    while par[x]!=x:
        par[x]=par[par[x]];x=par[x]
    return x
def union(a,b):
    a,b=find(a),find(b)
    if a!=b:par[max(a,b)]=min(a,b)
# N05 노선이 같은 회사의 기존 노선에 이어지면 이음 역은 그 노선의 역과 같은 역이다
# 같은 회사에 같은 이름 역이 여럿이면(国鉄 神戸·横川) N05 역 점이나 이웃 역에 가까운 쪽이다
FAMSD=collections.defaultdict(list)
for p in parts:
    if p.n05pt:continue
    for o in p.st:
        if o.sd and all(q['id']!=o.sd['id'] for q in FAMSD[(p.family,o.nm)]):FAMSD[(p.family,o.nm)].append(o.sd)
for p in parts:
    if p.n05pt:
        for i,o in enumerate(p.st):
            cs=FAMSD.get((p.family,o.nm)) or []
            if not cs:continue
            sp=lambda q:(q['lat_'],q['lng_'])
            ref=o.n05
            if not ref:
                # 이음 역은 N05 점이 없을 수 있다. 가장 가까운 순번의 이웃 역 점으로 본다
                nb=sorted(((abs(j-i),x) for j,x in enumerate(p.st) if j!=i and (getattr(x,'n05',None) or x.sd)),key=lambda t:t[0])
                ref=next(((x.n05 or sp(x.sd)) for _,x in nb),None)
            if ref is None:q=cs[0] if len(cs)==1 else None
            else:
                q=min(cs,key=lambda q:dist(ref,sp(q)))
                lim=5 if o.n05 else abs(p.st[min(len(p.st)-1,i+1)].km-p.st[max(0,i-1)].km)*1.5+10
                if dist(ref,sp(q))>lim:q=None
            if q:o.sd=q;o.n05=None
XPT={}
for p in parts:
    for o in p.st:
        if (p.cn,o.nm) in NOSD or (p.id,o.nm) in NOSD:o.sd=None
        # N05 노선의 역은 N05 역 점에서 1.5km 넘게 떨어진 station_database 역에 붙이지 않는다. 이름만 같은 다른 역이다
        if getattr(o,'n05',None) and o.sd and dist(o.n05,(o.sd['lat_'],o.sd['lng_']))>1.5:o.sd=None
        o.key=('o'+p.family+':'+o.nm) if o.old else (('s'+o.sd['id']+':'+p.family) if o.sd else ('x'+p.family+':'+o.mnm))
        # 역 자료가 없는 N05 역은 같은 회사·같은 이름이라도 N05 역 점이 1.5km 넘게 떨어지면 다른 역이다 (東武 伊香保線과 前橋線의 商工会議所前, 감사 A2-01)
        if o.key[0]=='x' and getattr(o,'n05',None):
            seen_=XPT.setdefault(o.key,[])
            near_=next((k_ for k_,pt_ in seen_ if dist(pt_,o.n05)<=1.5),None)
            if near_ is None:
                near_=o.key if not seen_ else o.key+'@'+str(len(seen_))
                seen_.append((near_,o.n05))
            o.key=near_
        prevsame=[q for q in p.st[:p.st.index(o)] if getattr(q,'key',None)==o.key]
        if prevsame and (prevsame[-1].label!=o.label or p.st[p.st.index(o)-1] is prevsame[-1]):
            o.key=o.key+'#'+str(len(prevsame))
        find(o.key)
# 두 표에 다른 이름으로 나오는 같은 역 (hand_tables SAME_NODE. 島原外港=島原港). 노선 이름을 |로 이으면 여러 노선의 같은 역이다 (三国線 金津=北陸本線 芦原温泉)
for nm_,a_,b_,_ in HT['SAME_NODE']:
    ks=[o.key for p in parts if p.name in nm_.split('|') for o in p.st if o.nm in(znorm(a_),znorm(b_)) and not o.hidden]
    for k_ in ks[1:]:union(ks[0],k_)
# 사업자별로 나뉜 공용 선로(hand_tables SHARED_TRACK, 2회차 결정 U03): 두 노선이 함께 쓰는 구간의 역은 한 노드, 칸은 물리 칸 하나(+노선·사업자마다 멤버십 행)다
# (都営三田線·東京メトロ南北線 目黒–白金高輪, JR·のと鉄道 七尾–和倉温泉, JR 伯備線·井原鉄道 総社–清音, JR·南海 りんくうタウン–関西空港) (3회차 kanto_2-007, 8회차 W1b)
for nm_,sts_,_ in HT.get('SHARED_TRACK',[]):
    for st_ in sts_:
        ks=[o.key for p in parts if p.name in nm_.split('|') for o in p.st if o.nm==znorm(st_) and not o.hidden]
        for k_ in ks[1:]:union(ks[0],k_)

# ---- 노선
BASE=collections.OrderedDict()
for p in parts:
    p.lk=(p.family,p.name)
    BASE.setdefault(p.lk,[]).append(p)
def sectionish(p):
    return p.paren is None or re.search(r'[-～~]',p.paren) is not None
# ---- 승계(국철·JR 폐선 → 타사 현행 노선)
HAND_NO_TRANSFER=set()   # (폐선 부품 id, 현행 부품 id) 오판 제외
trans=[]
cur_pr=[p for p in parts if p.g=='pr' or (p.g=='tm' and p.c!='9')]
# 손 표 FORCE_PAIR의 앞 노선이 N05·폐선 표의 옛 노선 부품(g old)이면 그 짝만 승계로 본다. 사업자별로 나뉜 공용 선로(2회차 종합 U03)를
# 물리 칸 하나로: 앞 노선이 닫힌 날 그 구간이 뒤 노선으로 이관되고(같은 lineage), 같은 이름 역은 한 노드다 (西鉄 北九州線 黒崎駅前–熊西 → 筑豊電気鉄道 2000-11-26)
FORCE_OLD={a_ for a_,b_ in FORCE_PAIR}
for p in parts:
    old_=p.g=='old' and p.name in FORCE_OLD
    if not(p.g=='tm' and p.c=='9') and not old_:continue
    # 역 이전 옛 자리(o.old)는 지금 역과 이름이 같아 승계 짝짓기에 두 번 들어가면 공유 역 순서·짝이 흐트러진다(信越本線 春日山（旧）, 7회차 2026-11-14)
    names=[o.mnm for o in p.st if not getattr(o,'old',False)]
    S=set(names)
    for q in cur_pr:
        if (p.id,q.id) in HAND_NO_TRANSFER:continue
        # 옛 노선 부품은 손 표 짝만(이름 겹침 규칙으로 다른 노선을 잡지 않게)
        if old_ and (p.name,q.name) not in FORCE_PAIR:continue
        T={o.mnm for o in q.st}
        sh=[n for n in names if n in T]
        if (len(sh)>=3 and (len(sh)/len(S)>=.5 or len(sh)>=4)) or (len(sh)>=2 and (p.name,q.name) in FORCE_PAIR):
            idx={o.mnm:i for i,o in enumerate(q.st)}
            ix=[idx[n] for n in sh]
            mono=all(a<b for a,b in zip(ix,ix[1:])) or all(a>b for a,b in zip(ix,ix[1:]))
            if mono:trans.append((p,q,sh))
print('승계 후보',len(trans))
shared_keys=collections.defaultdict(set)   # q.id -> 공유 구간 노드 쌍
def ghost(o,km):
    c=P();c.__dict__.update(o.__dict__);c.km=dround(km);c.ghost=True;c.closed=False;return c
SUCC=set()
for p,q,sh in trans:
    pm={o.mnm:o for o in p.st if not getattr(o,'old',False)};qm={o.mnm:o for o in q.st if not getattr(o,'old',False)}
    # 공유 역의 km 간격이 어긋나면 이름만 같은 다른 역이다
    kept=[sh[0]]
    for x in sh[1:]:
        a=kept[-1]
        if abs(abs(pm[x].km-pm[a].km)-abs(qm[x].km-qm[a].km))<=.7:kept.append(x)
    sh[:]=kept
    if len(sh)<2:continue
    SUCC.add(q.id)
    for n in sh:union(pm[n].key,qm[n].key)
    fw=q.st.index(qm[sh[0]])<q.st.index(qm[sh[-1]])
    newp=[];newq=[]
    i0=p.st.index(pm[sh[0]]);i1=p.st.index(pm[sh[-1]])
    head=p.st[:i0];tail=p.st[i1+1:]
    M=[(pm[sh[0]],qm[sh[0]])]
    for A,B in zip(sh,sh[1:]):
        pa,pb=pm[A],pm[B];qa,qb=qm[A],qm[B]
        pin=p.st[p.st.index(pa)+1:p.st.index(pb)]
        ia,ib=q.st.index(qa),q.st.index(qb)
        qin=q.st[ia+1:ib] if fw else q.st[ib+1:ia][::-1]
        pg=abs(pb.km-pa.km) or 1;qg=abs(qb.km-qa.km) or 1
        L=[(abs(o.km-pa.km)/pg,0,o) for o in pin]+[(abs(o.km-qa.km)/qg,1,o) for o in qin]
        L.sort(key=lambda x:(x[0],x[1]))
        i=0
        while i<len(L):
            f,w,o=L[i]
            nxt=L[i+1] if i+1<len(L) else None
            if nxt and nxt[1]!=w and abs(nxt[0]-f)*qg<=.3:
                x,y=(o,nxt[2]) if w==0 else (nxt[2],o)
                union(x.key,y.key);M.append((x,y));i+=2;continue
            if w==0:M.append((o,ghost(o,qa.km+(qb.km-qa.km)*f)))
            else:M.append((ghost(o,pa.km+(pb.km-pa.km)*f),o))
            i+=1
        M.append((pb,qb))
    p.st=head+[a for a,b in M]+tail
    qs=[b for a,b in M]
    j0=min(q.st.index(qm[sh[0]]),q.st.index(qm[sh[-1]]));j1=max(q.st.index(qm[sh[0]]),q.st.index(qm[sh[-1]]))
    q.st=q.st[:j0]+(qs if fw else qs[::-1])+q.st[j1+1:]
    p.trans=getattr(p,'trans',[])+[(q,[(a.key) for a,b in M])]

# ---- 계통 사슬
def rev(st):
    tot=st[-1].km;o=[]
    for s in reversed(st):
        c=P();c.__dict__.update(s.__dict__);c.km=dround(tot-s.km);o.append(c)
    return o
def rev_chain(seq):
    """계통 사슬을 뒤집는다. km는 새 기점에서 다시 누적한다. 부품(표) 경계의 이음 역은 앞 부품 것이고 뒤 부품 첫 역이 이음 역 km를 prevkm으로 가진다(edge_km·spans 규칙).
    뒤집으면 앞뒤가 바뀌므로 이음 역을 새 앞 부품으로 옮기고 새 뒤 부품 첫 역에 prevkm을 준다"""
    d=[]
    for i in range(len(seq)-1):
        (a_,pa),(b_,pb)=seq[i],seq[i+1]
        d.append(dround(abs(b_.km-a_.km)) if pa is pb else dround(abs(b_.km-getattr(b_,'prevkm',b_.km))))
    r=seq[::-1];tags=[p_ for _,p_ in r]
    for j in range(1,len(r)):
        if r[j][1] is not r[j-1][1] and (j+1>=len(r) or r[j+1][1] is r[j][1]):tags[j]=tags[j-1]
    o=[];cum=0.0
    for j,(s_,p_) in enumerate(r):
        c=P();c.__dict__.update(s_.__dict__)
        if hasattr(c,'prevkm'):del c.prevkm
        if j>0:
            cum=dround(cum+d[len(seq)-1-j])
            if tags[j] is not tags[j-1]:c.prevkm=o[-1][0].km
        c.km=cum;o.append((c,tags[j]))
    return o
# 공식 기점 표 (hand_tables LINE_AXIS): (회사, 노선) -> 기점 역 이름
LINE_AXIS={(a_,b_):c_ for a_,b_,c_,_ in HT.get('LINE_AXIS',[])}
line_rel=[]
for lk,ps in BASE.items():
    mains=[];branches=[]
    for p in ps:
        (mains if sectionish(p) else branches).append(p)
    chains=[]
    for p in sorted(mains,key=lambda p:(p.g=='tm',-p.km)):
        c=P();c.parts=[p];c.seq=[(s,p) for s in p.st];c.alts=[];chains.append(c)
    changed=True
    while changed:
        changed=False
        for a in chains:
            for b in chains:
                if a is b:continue
                af,al=find(a.seq[0][0].key),find(a.seq[-1][0].key)
                bf,bl=find(b.seq[0][0].key),find(b.seq[-1][0].key)
                ka={find(s.key) for s,_ in a.seq};kb={find(s.key) for s,_ in b.seq}
                if len(ka&kb)>1:continue
                if al==bf and bl!=af:
                    b.seq[1][0].prevkm=b.seq[0][0].km
                    a.seq=a.seq+b.seq[1:];a.parts+=b.parts;chains.remove(b);changed=True;break
                if bl==af and al!=bf:
                    a.seq[1][0].prevkm=a.seq[0][0].km
                    a.seq=b.seq+a.seq[1:];a.parts=b.parts+a.parts;chains.remove(b);changed=True;break
                if al==bl and af!=bf and b.parts[0].g=='tm':
                    rs=rev([s for s,_ in b.seq]);rp=[q for _,q in reversed(b.seq)]
                    rs[1].prevkm=rs[0].km
                    a.seq=a.seq+list(zip(rs,rp))[1:];a.parts+=b.parts;chains.remove(b);changed=True;break
            if changed:break
    def host_of(c,cands,strict):
        """옛 선로 부품 c를 옛 선로(alt old)로 실을 지금 사슬. 두 끝이 그 사슬의 역이어야 한다.
        끝 하나가 역 이전 옛 자리(move_of)면 같은 이름의 새 자리 역이 그 사슬에 있으면 된다 (女川: 浦宿–女川(旧) 막다른 옛 선로).
        strict면 사이 역이 그 사슬과 겹치지 않아야 한다 (지선 표의 옛 경로)"""
        f_,l_=c.seq[0][0],c.seq[-1][0]
        inner={find(s.key) for s,_ in c.seq[1:-1]}
        for d in cands:
            if d is c or d.parts[0].g=='tm':continue
            ks={find(s.key) for s,_ in d.seq};nms={s.nm for s,_ in d.seq if not s.old}
            on=lambda s:find(s.key) in ks or (getattr(s,'move_of',None) is not None and s.nm in nms)
            if not (on(f_) and on(l_)) or (find(f_.key) not in ks and find(l_.key) not in ks):continue
            if strict and inner&ks:continue
            # 역 이전 옛 자리(【旧】 또는 같은 이름 역이 지금 사슬에 있는 역)를 지나는 옛 선형만 싣는다. 옛 자리가 없는 옛 선형(北陸本線 敦賀–今庄 杉津 경유)은
            # 실으면 날짜 모름·운휴로 내린 기록이 옛·새 두 경로로 갈려(appsim E5) 따로 계통으로 둔다
            if strict and not any(s.old or getattr(s,'move_of',None) or s.nm in nms for s,_ in c.seq[1:-1]):continue
            return d
        return None
    keep=[]
    for c in chains:
        if c.parts[0].g=='tm' and len(chains)>1:
            host=host_of(c,chains,False)
            if host:
                host.alts.append(c);continue
        keep.append(c)
    chains=keep
    for c in chains:c.role='main'
    def oldroute(p):
        """지금 노선의 옛 선형 부품(N05·폐선 표의 旧線). 전 구간이 닫혔고 본선 선로를 같이 쓰지 않는다"""
        if p.g not in('old','tm') or p.n05shared or p.extra or getattr(p,'n05subsec',False):return False
        if any(o.hidden for o in p.st):return False
        try:ckm=sum(float(r[1]) for r in p.close)
        except (TypeError,ValueError):return False
        return ckm>=p.km-.05
    for p in branches:
        c=P();c.parts=[p];c.seq=[(s,p) for s in p.st];c.alts=[]
        # 옛 선형(田立·東青山·土佐穴内 옛 선로)은 따로 계통이 아니라 지금 계통의 옛 선로다 (常磐線 新地·坂元·山下 모델).
        # 그 시절 날짜에 지금 계통 하나로 옛 자리 역까지 기록하고, 새 자리 역 정차는 compile의 역 이전 자르기가 이전일부터로 둔다
        host=host_of(c,chains,True) if oldroute(p) and chains else None
        if host:host.alts.append(c);continue
        c.role='branch';chains.append(c)
    # 공식 기점이 정해진 노선(hand_tables LINE_AXIS)은 km 축을 기점에서 한 줄로 둔다. 표가 끝 구간을 따로 적어 기점이 다른 계통이 둘 이상 생긴 곳
    # (頸城鉄道 百間町 기점 두 토막 → 新黒井 0.0 한 줄, 名鉄 三河線 西中金–猿投–碧南–吉良吉田, 羽後交通 横荘線 横手 기점)을 기점 쪽부터 잇는다 (3회차 chubu_2-12·chubu_2-13·tohoku_2-014, 8회차 W1b)
    _ax=LINE_AXIS.get((ps[0].cn,lk[1]))
    if _ax:
        _o=znorm(_ax)
        head=next((c for c in chains if _o in (c.seq[0][0].nm,c.seq[-1][0].nm)),None)
        if head is None:raise SystemExit(f'LINE_AXIS {ps[0].cn} {lk[1]}: 기점 {_ax}가 끝인 계통이 없음')
        if head.seq[0][0].nm!=_o:head.seq=rev_chain(head.seq);head.parts=head.parts[::-1]
        grown=True
        while grown:
            grown=False
            for b in chains:
                if b is head:continue
                hl=find(head.seq[-1][0].key);ks={find(s_.key) for s_,_ in head.seq}
                kb={find(s_.key) for s_,_ in b.seq}
                if len(ks&kb)!=1:continue
                if find(b.seq[-1][0].key)==hl:b.seq=rev_chain(b.seq);b.parts=b.parts[::-1]
                if find(b.seq[0][0].key)!=hl:continue
                b.seq[1][0].prevkm=b.seq[0][0].km
                head.seq=head.seq+b.seq[1:];head.parts+=b.parts;chains.remove(b);grown=True;break
        chains.remove(head);chains.insert(0,head)
    for c in chains[1:]:c.role='branch'
    if chains:chains[0].role='main'
    line_rel.append((lk,ps,chains))

# ---- ID
# 원천 표의 번호는 안에서만 쓰고 밖으로는 영어 이름 ID로 낸다 (ARCHITECTURE §4.2). 표는 공개하지 않는 data/imports/id_map.json이다
NEW_IDS=os.environ.get('NORIORI_NEW_IDS')=='1';NEWK=set()
used=set()
def uid(base):
    b=base;i=2
    while b in used:b=f'{base}_{i}';i+=1
    used.add(b)
    # 표에 없는 새 항목이 옛 형식으로 나가거나 기존 공개 ID와 겹치지 않게 여기서 멈춘다.
    # 새 노선을 넣을 때는 NORIORI_NEW_IDS=1로 한 번 돌려 내부 키를 그대로 내고, tools/new_ids.py가 영어 이름 ID를 표에 더한다
    if b not in PUB:
        if NEW_IDS:NEWK.add(b);return b
        raise SystemExit(f'data/imports/id_map.json에 없는 ID입니다: {b}. 새 항목이면 NORIORI_NEW_IDS=1로 돌리고 tools/new_ids.py를 실행하세요')
    return PUB[b]
def oid(c):
    i=f'o_{c}'
    if i not in PUB and c not in('','x'):
        if NEW_IDS:NEWK.add(i);return i
        raise SystemExit(f'data/imports/id_map.json에 없는 사업자 ID입니다: {i}')
    return PUB.get(i,i)
ops={};OPSRC={}
# N05로 들어온 사업자는 회사 코드가 없어 분류를 손으로 둔다 (감사 SUC-006). 공영은 public, 모노레일만 운영한 곳은 monorail
N05CAT={'大阪市交通局':'public','秋田市交通局':'public','呉市交通局':'public','川崎市交通局':'public','姫路市':'monorail','名古屋市交通局協力会':'monorail'}
def category(c):
    c=str(c)
    if c.startswith('10'):return 'major_private'
    if c.startswith('20'):return 'semi_major_private'
    if c.startswith('30'):return 'public'
    if c.startswith('4'):return 'general_private'
    if c.startswith('50'):return 'monorail'
    if c.startswith('51'):return 'agt'
    if c.startswith('52'):return 'cable'
    return 'general_private'
for k,v in JRJA.items():ops[k]=dict(id=k,name_ja=v,category='jr',short_ko=JRKO[k])
for p in parts:
    if p.family!='jr' and oid(p.c) not in ops and p.c!='x':
        ops[oid(p.c)]=dict(id=oid(p.c),name_ja=p.cn,category=N05CAT.get(p.cn) or category(p.c));OPSRC[oid(p.c)]=p.s['op']
PREF_JR={1:1,2:2,3:2,4:2,5:2,6:2,7:2,8:2,9:2,10:2,11:2,12:2,13:2,14:2,15:2,16:4,17:4,18:4,19:2,20:2,21:3,22:3,23:3,24:3,25:4,26:4,27:4,28:4,29:4,30:4,31:4,32:4,33:4,34:4,35:4,36:5,37:5,38:5,39:5,40:6,41:6,42:6,43:6,44:6,45:6,46:6,47:6}
def jr_of(p):
    if p.g=='jr':return JRCO[int(p.c)]
    if p.g=='jrx':return JRCO[jrx_co(p)]
    c=collections.Counter()
    for o in p.st:
        if o.sd:
            for x in o.sd['comp']:
                if x in('1','2','3','4','5','6'):c[int(x)]+=1
            if not o.sd['comp']&{'1','2','3','4','5','6'} and o.sd['prefecture'].isdigit():
                c[PREF_JR.get(int(o.sd['prefecture']),2)]+=.5
    return JRCO[c.most_common(1)[0][0]] if c else 'o_jr_east'
def jrx_co(p):
    c=collections.Counter()
    for o in p.st:
        if o.sd:
            for x in o.sd['comp']:
                if x in('1','2','3','4','5','6'):c[int(x)]+=1
    return c.most_common(1)[0][0] if c else 2
kana_line={}
for l in SL:
    if l['name_kana'] not in('','NULL'):
        kana_line.setdefault(znorm(conn.clean(l['name'])),l['name_kana'])
linesout={};lid={};hub_line={};LSRC={}
TRAMCO=set(HT['TRAMCO'])
TRAMLN={tuple(x) for x in HT['TRAMLN']}
TRAMCO_CLOSED=set(HT['TRAMCO_CLOSED'])
SUBWAYCO=set(HT['SUBWAYCO'])
LINETYPE={(a,b):c for a,b,c in HT['LINETYPE']}
def line_type(fam,name):
    c=fam[1:] if fam!='jr' else ''
    cn=ops.get(oid(c),{}).get('name_ja','')
    if cn in TRAMCO or (cn,name) in TRAMLN:return 'tram'
    if '鋼索' in name or 'ケーブル' in name:return 'cable'
    if c.startswith('50'):return 'monorail'
    if c.startswith('51'):return 'agt'
    if '軌道' in name:return 'tram'
    if '比叡山' in cn or '竜飛' in name:return 'cable'
    if '無軌条' in name:return 'trolley'
    if '懸垂' in name:return 'monorail'
    return 'rail'
# 원자료 노선과 짝짓기: 역이 가장 많이 겹치는 줄
sd_line_st=collections.defaultdict(set)
scode={s['code']:s for s in SD}
for r in REG:
    s=scode.get(r['station_code'])
    if s:sd_line_st[r['line_code']].add(znorm(s['name']))
def sd_line_for(ps):
    S=set(o.nm for p in ps for o in p.st if not getattr(o,'ghost',False))
    best=None;bs=0
    for code,T in sd_line_st.items():
        sh=len(S&T)
        if not sh:continue
        l=sl[code]
        # 역 하나만 겹치는 다른 노선(妙見の森ケーブル 黒川–小田急多摩線 黒川, 中山線 中山–グリーンライン)은 같은 이름 역이 우연히 겹친 것이다.
        # 두 역 넘게 겹치거나 노선 이름이 맞을 때만 짝이다 (3회차 hokkaido_1-012·kinki_2-015, 8회차 W1b)
        # 두 역 사이 연결선(連絡線: 鵜沼·新ノ口·松田)은 모선과 역 하나만 겹치는 게 본디 꼴이라 그대로 둔다
        if sh<2 and znorm(ps[0].name) not in znorm(l['name']) and '連絡線' not in ps[0].name:continue
        sc=sh/max(len(S),1)+.2*(znorm(ps[0].name) in znorm(l['name']))+.1*(sh/len(T))
        if sc>bs:bs=sc;best=l
    return best if bs>=.5 else None
for lk,ps,ch in line_rel:
    fam,name=lk
    s=sd_line_for(ps)
    sdn_=conn.clean(s['name']) if s else ''
    same_=bool(s) and (znorm(name) in znorm(sdn_) or znorm(sdn_) in znorm(name)) and name not in('本線','幹線','鋼索線')
    k=LINEKANA.get(ps[0].cn+'|'+name if fam!='jr' else '|'+name) or KANA.get('line:'+name) or kana_line.get(znorm(name)) or (s['name_kana'] if same_ and s['name_kana'] not in('','NULL') else None) or N5KANA.get(ps[0].cn+'|'+name)
    base='l_'+(romaji(re.sub(r'^じぇいあーる','',k)) if k else 'n'+ps[0].id)
    if fam!='jr':base+='_'+fam[1:]
    i=uid(base);lid[lk]=i
    # 노선 전체가 화물·연결선 표일 때만 노선이 분모 밖이다. 모선 아래 지선 계통으로 둔 표(route_extra)는 그 계통만 분모 밖이다
    rc='shinkansen' if '新幹線' in name else ('hidden' if all(getattr(q,'no_passenger',False) for q in ps) else 'extra' if all(q.g in('jrx','prx') for q in ps) else 'normal')
    linesout[i]=dict(id=i,name_ja=name,type=line_type(fam,name),rule_class=rc,kana=k,sd=s['name'] if s else None,family=fam)
    if not any(q.g in('jr','pr') for q in ps):linesout[i]['closed']=True
    # 지하철과 市電을 함께 둔 공영 사업자의 폐지 노선은 市電이다 (hand_tables TRAMCO_CLOSED). 손 표 LINETYPE이 먼저, 지하철 사업자의 나머지 철도 노선은 subway
    cn_=ops.get(oid(fam[1:]),{}).get('name_ja') if fam!='jr' else None
    if (cn_,name) in LINETYPE:linesout[i]['type']=LINETYPE[(cn_,name)]
    elif linesout[i].get('closed') and linesout[i]['type']=='rail' and cn_ in TRAMCO_CLOSED:linesout[i]['type']='tram'
    elif linesout[i]['type']=='rail' and cn_ in SUBWAYCO:linesout[i]['type']='subway'
    LSRC[i]='noritsubushi' if any(q.s['line']=='noritsubushi' for q in ps) else ps[0].s['line']

# ---- 노드
# 부품(노선)별 역 읽기: N05 노선 표의 그 노선 kana
N5ST_LK={}
for p in parts:
    v_=N5ST.get((p.cn or '')+'|'+p.name)
    if v_:
        for o in p.st:
            if v_.get(o.name):N5ST_LK[(p.lk,o.name)]=kata2hira(v_[o.name])
nodes={};n_of={}
clusters=collections.defaultdict(list)
for p in parts:
    for o in p.st:
        if not getattr(o,'ghost',False):clusters[find(o.key)].append((o,p))
for k,L in clusters.items():
    L=sorted(L,key=lambda x:x[1].g=='tm')
    os_=[o for o,_ in L]
    sd=next((o.sd for o in os_ if o.sd),None)
    o0=os_[0]
    # 표시 이름은 가장 늦은 시기의 표에서 고른다. 옛 이름은 노선별 이름으로 남는다 (§9.2)
    def part_end(p_):
        return '9999' if p_.g!='tm' else max([str(r[2]) for r in p_.close if len(r)>2] or ['0'])
    o_name=max(L,key=lambda x:part_end(x[1]))[0]
    # 이름의 출처. 위키에서 끼워 넣은 역은 위키, 같은 이름이 노리츠부시 표에도 있으면 표다
    stop_src=lambda o,q:'wikipedia' if hasattr(o,'wclose') else q.s['stop']
    name_src=min((stop_src(o,q) for o,q in L if o.name==o_name.name),key=lambda x:(x!='noritsubushi',x))
    # 공개 ID 내부 키의 읽기: 예전 순서 그대로 (station_database → Wikidata 이름 → 이름 열쇠 표)
    kana_id=(sd or {}).get('name_kana')
    if kana_id in(None,'','NULL'):
        kana_id=next((x.get('kana') for x in WD.get(o0.nm,[]) if x.get('kana')),None)
        if kana_id:kana_id=re.sub(r'(えき|エキ|かりじょうこうじょう|しんごうじょう|ていりゅうじょう|じょうこうじょう)$','',kata2hira(kana_id).replace(' ',''))
    if kana_id in(None,'','NULL'):kana_id=KANA_ID.get('node:'+o0.name) or KANA_ID.get('node:'+o0.nm)
    # 표시 읽기 (2회차 종합 K13): 그 역 자료(station_database) → 그 노선 원문(N05 노선 표의 그 노선 kana) → 5km 안 같은 이름 Wikidata → 이름 열쇠 표(읽기가 하나뿐일 때만).
    # 먼 곳의 같은 글자 역 읽기(今福 いまぶく·いまふく, 平野町 ひらのちょう·ひらのまち)가 섞이면 안 된다
    _wdu=False
    # 읽기 출처(names.reading_source, auto:경로). 어느 경로로 고른 읽기인지 남겨 같은 이름 역에서 빌린 읽기를 감사가 따로 볼 수 있게 한다 (12회차 M 2026-11-19 사용자 지적)
    kana=(sd or {}).get('name_kana');_ksrc='auto:station_db' if kana not in(None,'','NULL') else None
    if kana in(None,'','NULL'):
        kana=next((N5ST_LK[(q.lk,o.name)] for o,q in L if (q.lk,o.name) in N5ST_LK and o.name==o_name.name),None)
        if kana:_ksrc='auto:n05_line'
    if kana in(None,'','NULL'):
        _p0=(sd['lat_'],sd['lng_']) if sd else next((tuple(o.n05) for o in os_ if getattr(o,'n05',None)),None)
        # 같은 이름 Wikidata 항목: 이 역 점 5km 안 항목이 있으면 그 읽기를 쓴다. 없으면, 좌표가 있어 다른 곳(5km 밖)으로 드러난 항목은 이 역이 아니라 버리고,
        # 남은 항목(이 단계에 점이 없는 노드·좌표 없는 항목이라 확인할 수 없는 것)의 읽기가 하나로 같을 때만 쓴다.
        # 예전에는 5km 밖 항목까지 읽기가 하나뿐이면 써서 115곳이 수백 km 밖 같은 글자 역의 읽기를 빌렸다(西鉄 甘木線 高島 たかしま, 別大 浜町 797km 등,
        # 2026-11-18 사용자 지적 「같은 이름 역의 읽기를 빌리지 않는다」). 버린 읽기는 다음 근거(손 조사 표·이름 열쇠 가드)로 넘긴다
        _wk=[x for x in WD.get(o0.nm,[]) if x.get('kana') and _p0 and x.get('pt') and dist(_p0,x['pt'])<5]
        if not _wk:
            _wk=[x for x in WD.get(o0.nm,[]) if x.get('kana') and not (_p0 and x.get('pt'))]
            if len({re.sub(r'(えき|エキ)$','',kata2hira(x['kana']).replace(' ','')) for x in _wk})>1:_wk=[]
        kana=_wk[0]['kana'] if _wk else None
        _wdu=bool(kana) and not (_p0 and all(x.get('pt') for x in _wk) and all(dist(_p0,x['pt'])<5 for x in _wk))
        if kana:_ksrc='auto:wikidata_unverified' if _wdu else 'auto:wikidata_5km'
        if kana:kana=re.sub(r'(えき|エキ|かりじょうこうじょう|しんごうじょう|ていりゅうじょう|じょうこうじょう)$','',kata2hira(kana).replace(' ',''))
    _nk=None
    if kana in(None,'','NULL'):
        kana=KANA.get('node:'+o0.name) or KANA.get('node:'+o0.nm)
        if kana:_nk='node:'+o0.name if KANA.get('node:'+o0.name) else 'node:'+o0.nm;_ksrc='auto:name_key'
    # 역 이전 옛 자리는 새 역의 옛 이름 읽기(old_names_kana.json 「새 역|옛 이름」)를 쓴다 (陸前古川, 湊町)
    _fid=next((o.force_id for o in os_ if getattr(o,'force_id',None)),None)
    _row=next((x for x in INS if x.get('id')==_fid and x.get('new_node')),None) if _fid else None
    if _row:
        if kana in(None,'','NULL'):
            kana=OLDKANA0.get(_row['new_node']+'|'+o0.name)
            if kana:_ksrc='auto:old_site_id_key'
        if kana_id in(None,'','NULL'):kana_id=OLDKANA0.get(_row['new_node']+'|'+o0.name)
    # 이름이 「駅」으로 끝나면 읽기도 えき로 끝난다(須磨駅 すまえき, 保土ヶ谷駅 ほどがやえき, 2회차 종합 K17). 한국어는 「역」, 영어는 -eki가 된다
    if kana not in(None,'','NULL') and o_name.name.endswith('駅') and not kata2hira(kana).endswith('えき'):kana=kata2hira(kana)+'えき'
    r=romaji(kana_id) if kana_id else ''
    # 역 이전 옛 자리는 수집 행이 정한 공개 ID를 그대로 쓴다. 다른 노드의 _2 꼬리를 밀지 않게 uid를 거치지 않는다
    forced=next((o.force_id for o in os_ if getattr(o,'force_id',None)),None)
    if forced:
        if forced in nodes or forced in used:raise SystemExit(f'옛 자리 ID가 겹칩니다: {forced}')
        i=forced;used.add(i)
    else:i=uid('n_'+(r or 'x'+stable(k))+('' if L[0][1].family=='jr' else '_'+L[0][1].family[1:]))
    hid=all(o.hidden for o in os_)
    kind='station'
    if hid or SIGNALISH.search(o0.name) or o0.kind:kind=o0.kind or ('signal' if '信号' in o0.name else ('freight' if '貨物' in o0.name else 'junction'))
    pt=(sd['lat_'],sd['lng_']) if sd else None
    # station_database에 없는 N05 노선의 역은 N05 역 점 (DESIGN §2.11 출처 모듈화. N05를 끄면 쓰지 않는다)
    n5pt=next((tuple(o.n05) for o in os_ if getattr(o,'n05',None)),None) if source_on('n05') else None
    nodes[i]=dict(id=i,cns=sorted({p_.cn for _,p_ in L}),kind=kind,group=None,pref=(sd or {}).get('prefecture'),name=o_name.name,nm=o_name.nm,kana=re.sub(r'〈.*?〉','',kana) if kana and kana!='NULL' else None,pt=pt,sd_only=bool(sd and len(byname.get(znorm(sd['name']),[]))==1 and len(st_lines[sd['code']])==1),sdname=(sd or {}).get('name'),sd=(sd or {}).get('id'),closed_sd=(sd or {}).get('closed'),sd_open=edtf((sd or {}).get('open_date')),sd_close=edtf((sd or {}).get('closed_date')),family=L[0][1].family,labels=sorted({o.name for o in os_}),by_line=sorted({(o.name,q.lk) for o,q in L if o.name!=o_name.name}),name_src=name_src,by_src={(o.name,q.lk):stop_src(o,q) for o,q in L})
    if _nk and nodes[i]['kana']:nodes[i]['_namekey']=_nk
    if _wdu and nodes[i]['kana'] and not _nk:nodes[i]['_wdu']=o0.nm
    if nodes[i]['kana']:nodes[i]['_ksrc']=_ksrc
    # 「노드 ID|이름」 열쇠 읽기(old_names_kana.json)는 그 역 하나를 가리키는 손 조사 근거라 지금 이름에도 가장 먼저 쓴다. 이름 열쇠 표(kana.json)는
    # 같은 이름 역을 가르지 못해 다른 역(山陽本線 열람 전용 遊園地前)에 번진다 (西武山口線 遊園地前, 2026-11-18)
    _ik=OLDKANA0.get(i+'|'+o_name.name)
    if _ik:nodes[i]['kana']=_ik;nodes[i].pop('_namekey',None);nodes[i].pop('_wdu',None);nodes[i]['_ksrc']='auto:id_key'
    if not pt and n5pt:nodes[i].update(pt=n5pt,pt_src='n05',closed_sd='1')
    if kind!='station':nodes[i]['export_name']=('['+o0.name+']') if o0.hidden else o0.name
    n_of[k]=i
def nid(o):return n_of[find(o.key)]
def wd_for(n):
    best=None;bd=1e9
    for x in WD.get(n['nm'],[]):
        d=dist(n['pt'],x.get('pt')) if n['pt'] and x.get('pt') else 50
        if d<bd:bd=d;best=x
    return best if bd<8 and n['pt'] else None
for n in nodes.values():
    n['wd']=wd_for(n)

# 손 보정 좌표도 그 근거 출처를 끄면 쓰지 않는다
POSSRC={'wikidata':'wikidata','wikipedia':'wikipedia','n05':'n05','n02':'n02_2008'}
def pos_ok(src):return source_on(POSSRC[src]) if src in POSSRC else True
for k_,(la_,lo_,src_,pf_) in POSFIX.items():
    if k_ in nodes and pos_ok(src_):
        nodes[k_]['pt']=(la_,lo_)
        if src_!='hand':nodes[k_]['pt_src']=src_
        if pf_:nodes[k_]['pref']=pf_;nodes[k_]['pref_src']='hand'
# 현행 역은 같은 이름·같은 사업자의 N02 2024 역 점과 맞춘다. 이름이 같은 다른 지방 역에 잘못 붙은 좌표를 고친다
N02ST=json.load(open(os.path.join(IMP,'n02','stations_2024.json'),encoding='utf-8'))
cur_nodes=set()
for p in parts:
    for o in p.st:
        if not o.closed and not getattr(o,'ghost',False) and p.g!='tm':cur_nodes.add(nid(o))
def plat_dist(p,x):
    """역 좌표와 N02 승강장 선분의 거리. 긴 역은 가운데 점과 재면 크게 나온다"""
    c=x[4] if len(x)>4 else [[x[1],x[0]]]
    if len(c)==1:return dist(p,(c[0][1],c[0][0]))
    cs=math.cos(math.radians(p[0]));o=[]
    for a,b in zip(c,c[1:]):
        ax,ay=(a[0]-p[1])*cs,a[1]-p[0];bx,by=(b[0]-p[1])*cs,b[1]-p[0]
        ex,ey=bx-ax,by-ay;t=max(0,min(1,-(ax*ex+ay*ey)/((ex*ex+ey*ey) or 1e-18)))
        o.append(111.0*math.hypot(ax+t*ex,ay+t*ey))
    return min(o)
def n02_same(x,n):
    if n.get('family')=='jr' and '旅客鉄道' in x[2]:return True
    return any(x[2] in c or c in x[2] or x[2][:4]==c[:4] for c in n['cns'] if c)
n02_fix=[]
for k_ in cur_nodes:
    n=nodes[k_]
    c=[x for t in sorted({n['nm'],*n['labels']}) for x in N02ST.get(N02AL.get(znorm(t),znorm(t)),[]) if n02_same(x,n)]
    if not c:continue
    best=min(c,key=lambda x:dist(n['pt'],x)) if n['pt'] else c[0]
    d=dist(n['pt'],best) if n['pt'] else None
    if d is None or d>.6 or n.get('closed_sd')!='0':
        if d is None or d>.6:n02_fix.append((n['nm'],n['id'],None if d is None else dround(d)))
        if d is None or d>20:n['pref']=None
        n['pt']=(best[0],best[1]);n['closed_sd']='0';n['pt_src']='n02'
print('N02 좌표 교정',len(n02_fix),n02_fix[:40])
# 이어진 구간 어디에서도 거리가 맞지 않는 좌표는 버린다
for p in parts:
    for i,o in enumerate(p.st):
        if getattr(o,'ghost',False):continue
        nd=nodes[nid(o)]
        if not nd['pt']:continue
        ck=[]
        for j in (i-1,i+1):
            if 0<=j<len(p.st) and nodes[nid(p.st[j])]['pt']:
                ck.append(dist(nd['pt'],nodes[nid(p.st[j])]['pt'])>abs(p.st[j].km-o.km)*1.5+5)
        if ck and all(ck):nd['pt']=None;nd['closed_sd']='1'
# 좌표가 없는 노드는 같은 부품의 앞뒤 역에서 km 비율로 근사한다
for p in parts:
    for i,o in enumerate(p.st):
        if getattr(o,'ghost',False):continue
        nd=nodes[nid(o)]
        if nd['pt']:continue
        a=next((x for x in reversed(p.st[:i]) if nodes[nid(x)]['pt']),None)
        b=next((x for x in p.st[i+1:] if nodes[nid(x)]['pt']),None)
        if a and b and b.km!=a.km:
            pa,pb=nodes[nid(a)]['pt'],nodes[nid(b)]['pt'];f=(o.km-a.km)/(b.km-a.km)
            nd['pt']=(round(pa[0]+(pb[0]-pa[0])*f,6),round(pa[1]+(pb[1]-pa[1])*f,6));nd['pt_src']='interpolated';nd['closed_sd']='1'
# 도도부현이 비면 가장 가까운 역에서, 좌표도 없으면 같은 부품의 이웃 역에서 채운다. 이웃도 없는 독립 노선은 표로
for k_,v_ in {'n_daikanbo':'16','n_murodo':'16','n_raiden':'16','n_kurobe_dam':'16','n_ogizawa':'20','n_ueno_zoo_east_garden':'13','n_ueno_zoo_west_garden':'13','n_seibu_chichibu_through':'11','n_seibu_chichibu_ohanabatake_side':'11','n_ise_nakagawa_uehommachi_side':'24','n_ise_nakagawa_nagoya_side':'24'}.items():
    if k_ in nodes:nodes[k_]['pref']=v_;nodes[k_]['pref_src']='hand'
# 도도부현의 출처: station_database 주소(sd)와 손 값(hand)은 믿고, 그 밖은 빌린 값(borrow)이라 마지막에 좌표 폴리곤이 정한다.
# 가장 가까운 노드에서 빌리면 해협 건너 다른 현 역을 집는다(長関線 4역이 門司 쪽 福岡, 2회차 종합 K29). 같은 부품의 이웃 역에서만 빌린다
for n in nodes.values():
    if n.get('pref') and not n.get('pref_src'):n['pref_src']='sd' if n.get('sd') else 'hand'
for p in parts:
    for i,o in enumerate(p.st):
        nd=nodes[nid(o)]
        if nd.get('pref'):continue
        for j in sorted(range(len(p.st)),key=lambda j:abs(j-i)):
            x=nodes[nid(p.st[j])].get('pref') if nodes[nid(p.st[j])].get('pref_src')!='borrow' else None
            if x:nd['pref']=x;nd['pref_src']='borrow';break
# 부품에 믿을 현이 하나도 없는 독립 노선은 빌린 이웃 값, 그것도 없으면 가장 가까운 노드에서. 좌표가 폴리곤 안이면 마지막에 폴리곤이 정한다
for p in parts:
    for i,o in enumerate(p.st):
        nd=nodes[nid(o)]
        if nd.get('pref'):continue
        x=next((nodes[nid(p.st[j])].get('pref') for j in sorted(range(len(p.st)),key=lambda j:abs(j-i)) if nodes[nid(p.st[j])].get('pref')),None)
        if x:nd['pref']=x;nd['pref_src']='borrow'
for n in nodes.values():
    if n['pt'] and not n.get('pref'):
        v=[(dist(n['pt'],m_['pt']),m_['pref']) for m_ in nodes.values() if m_['pt'] and m_.get('pref') and abs(m_['pt'][0]-n['pt'][0])<.5]
        if v:n['pref']=min(v,key=lambda x:x[0])[1];n['pref_src']='borrow'
# ---- edge와 계통
edges={};km={};eseq=[0]
built={}       # 공유 구간 노드 쌍 -> edge
shared=set()
for p,q,sh in trans:
    ks=[nid(o) for o in p.st]
    tk=set(find(k) for _,keys in p.trans for k in keys)
    for a,b in zip(p.st,p.st[1:]):
        if find(a.key) in tk and find(b.key) in tk:shared.add(tuple(sorted((nid(a),nid(b)))))
# 손 대조 이음 행은 승계에서 빠지므로, 본선 선로를 같이 쓴다고 적은 행(branch)의 겹치는 칸을 여기서 공유 구간으로 둔다 (新潟 옛 선로).
# 두 역 사이를 다른 선로로 잇던 옛 선로(志文–岩見沢)는 같은 역 쌍이어도 따로 둔다
_pairs=collections.defaultdict(set)
for p in parts:
    for a,b in zip(p.st,p.st[1:]):_pairs[(p.family,p.name,tuple(sorted((nid(a),nid(b)))))].add(p.id)
# 이 칸은 같은 노선(가족·이름) 안에서만 같이 쓴다. 승계로 다른 노선과 같이 쓰는 칸(shared_trans)과 달리, 같은 두 역을 다른 노선이 잇는 칸(京成成田–駒井野의 東成田線)은 그 노선의 칸을 따로 둔다
shared_trans=set(shared);shared_n05=set()
for p in parts:
    if not p.n05shared:continue
    for a,b in zip(p.st,p.st[1:]):
        k=tuple(sorted((nid(a),nid(b))))
        if len(_pairs[(p.family,p.name,k)])>1:shared.add(k);shared_n05.add(k)
shared_n05-=shared_trans
# 공용 선로 구간의 칸은 노선이 달라도 같이 쓴다 (SHARED_TRACK). 뒤에 만드는 노선의 개업 사건은 칸 ID로 적는다(spec)
SHARED_TRACK_K=set()
for nm_,sts_,_ in HT.get('SHARED_TRACK',[]):
    S_={znorm(x) for x in sts_}
    for p in parts:
        if p.name not in nm_.split('|'):continue
        for a,b in zip(p.st,p.st[1:]):
            if a.nm in S_ and b.nm in S_ and not a.hidden and not b.hidden:
                k_=tuple(sorted((nid(a),nid(b))));shared.add(k_);SHARED_TRACK_K.add(k_)
# 승계로 같이 쓰는 칸은 앞 노선의 칸이다(사건 범위가 앞 노선 seed로 풀린다). 국철 폐선은 앞에 만들어져 늘 그렇지만,
# 앞 노선이 N05 옛 부품이면 뒤 노선(노리츠부시 현행)이 먼저 만든다 (FORCE_PAIR 北九州線→筑豊電気鉄道)
SH_SEED={}
for p,q,sh in trans:
    tk_=set(find(k) for _,keys in getattr(p,'trans',[]) for k in keys)
    for a,b in zip(p.st,p.st[1:]):
        if find(a.key) in tk_ and find(b.key) in tk_:SH_SEED.setdefault(tuple(sorted((nid(a),nid(b)))),lid[p.lk])
SH_KMSUCC=set()   # 뒤 노선(승계 받은 현행 노선)이 km를 적은 공유 칸. 칸 km는 지금 営業キロ라 뒤 노선 값이 앞 노선 값을 이긴다
def new_edge(a,b,line,route=None,alt=None):
    eseq[0]+=1
    i=f'e_{eseq[0]:06d}'
    e=dict(id=i,a=a,b=b,seed_line=line)
    if route:e['route_only']=route
    if alt:e['alt']=alt
    edges[i]=e;return i
def edge_km(seq,i):
    (s,pa),(t,pb)=seq[i],seq[i+1]
    if pa is pb:return dround(abs(t.km-s.km))
    return dround(abs(t.km-getattr(t,'prevkm',t.km)))
routesout=[];NROUTE={};kmsrc={}
def km_src(seq,i):
    """edge km의 출처. 위키에서 끼워 넣은 역은 표의 km를 위키 km 비율로 나눈 값이다"""
    (s,_),(t,q)=seq[i],seq[i+1]
    return 'noritsubushi+wikipedia' if q.s['km']=='noritsubushi' and (hasattr(s,'wclose') or hasattr(t,'wclose')) else q.s['km']
def build_chain(c,l,alt=None,host=None):
    seq=c.seq
    c.lid=l
    if host is None:
        rid=uid('r_'+OLD.get(l,l)[2:]+('' if c.role=='main' else '_'+(re.sub(r'\W+','',romaji(c.parts[0].paren or '')) or c.parts[0].id)))
        c.rid=rid
    else:
        rid=host.rid;c.rid=rid
    ns=[nid(s) for s,_ in seq]
    owned=(getattr(c,'role','alt')=='branch') or len(set(ns))<len(ns)
    c.ns=ns;c.eids=[];also=[]
    for i in range(len(seq)-1):
        a,b=ns[i],ns[i+1]
        k=tuple(sorted((a,b)))
        if alt is None and k in shared:
            bk=(k,l) if k in shared_n05 else k
            e=built.get(bk)
            # 손 대조 이음 행(지선 계통)이 다른 계통의 선로를 같이 쓰는 칸. 그 칸의 사건은 선로를 처음 만든 계통이 낸다
            if e is not None and getattr(c.parts[0],'n05join',False):c.reused=getattr(c,'reused',set())|{i}
            succ_=any(q.id in SUCC for q in c.parts)
            if e is None:
                e=new_edge(a,b,SH_SEED.get(k,l));built[bk]=e;km[e]=edge_km(seq,i);kmsrc[e]=km_src(seq,i)
                if succ_ and k in SH_SEED:SH_KMSUCC.add(e)
            elif e in SH_KMSUCC and not succ_:pass
            else:
                km[e]=edge_km(seq,i) or km[e]
                if edge_km(seq,i):kmsrc[e]=km_src(seq,i)
                if succ_ and k in SH_SEED:SH_KMSUCC.add(e)
            also.append(e)
        else:
            e=new_edge(a,b,l,rid if (owned or alt) else None,alt);km[e]=edge_km(seq,i);kmsrc[e]=km_src(seq,i)
        c.eids.append(e)
    if host is None:
        r=dict(id=rid,line=l,role=c.role)
        r['from']=ns[0];r['to']=ns[-1]
        if owned:r['owned']=True
        if owned and also:r['also']=also
        if any(getattr(q,'route_extra',False) for q in c.parts):r['extra']=True
        if len(set(ns))<len(ns):r['closed']=True;r['seq']=ns
        hid=sorted({nid(s) for s,_ in seq if s.hidden or getattr(s,'ghost',False)})
        if hid:r['hidden_stops']=hid
        NROUTE[rid]=dict(parts=[q.id for q in c.parts],km=dround(sum(q.km for q in c.parts)))
        routesout.append(r);c.r=r
    else:
        hid=sorted({nid(s) for s,_ in seq if s.hidden or getattr(s,'ghost',False)})
        if hid:host.r.setdefault('hidden_stops',[]).extend(hid)
for lk,ps,ch in sorted(line_rel,key=lambda x:x[0][0]!='jr'):
    l=lid[lk]
    for c in ch:build_chain(c,l)
    for c in ch:
        for a in c.alts:build_chain(a,l,alt='old',host=c)

WS=json.load(open(os.path.join(IMP,'wiki','station.json'),encoding='utf-8'))
COSHORT=HT['COSHORT']
ws_stat=collections.Counter()
PREF='北海道 青森県 岩手県 宮城県 秋田県 山形県 福島県 茨城県 栃木県 群馬県 埼玉県 千葉県 東京都 神奈川県 新潟県 富山県 石川県 福井県 山梨県 長野県 岐阜県 静岡県 愛知県 三重県 滋賀県 京都府 大阪府 兵庫県 奈良県 和歌山県 鳥取県 島根県 岡山県 広島県 山口県 徳島県 香川県 愛媛県 高知県 福岡県 佐賀県 長崎県 熊本県 大分県 宮崎県 鹿児島県 沖縄県'.split()
ws_miss=[]
ws_cache={}
def freight_block(b):
    """화물 전용 인포박스. 여객 역의 날짜로 쓰면 현행 역이 폐역이 된다 (女川, 宮古, 敦賀)"""
    o=b.get('ops') or ''
    if re.search('貨物(?:支線|線)|臨港線',b.get('lines') or ''):return True
    return '貨物' in o and not re.sub(r'\{\{[^|}]*\||\}\}|\||日本貨物鉄道|JR貨物|日本国有鉄道|国鉄|[（）()→\s・]','',o)
def ws_for(nd,q):
    """역 문서에서 이 사업자·노선의 블록을 찾아 가장 이른 개업일과 가장 늦은 폐지일을 준다"""
    k=(nd['id'],q.cn,q.name)
    if k in ws_cache:return ws_cache[k]
    n0=nd['name'];t0=n0 if n0.endswith('駅') else n0+'駅'
    pages=[t0,n0+'停留場'];
    for t in list(pages):
        pages+=(WS.get(t) or {}).get('alt') or []
    cand=[]
    seen=set()
    for t in pages:
        e=WS.get(t)
        if not e or e.get('missing') or t in seen or not t.startswith(n0):continue
        seen.add(t)
        a0=next((b.get('addr') for b in e.get('blocks',[]) if b.get('addr')),None)
        for b in e.get('blocks',[]):
            if freight_block(b):continue
            if b.get('open') or b.get('close'):cand.append(dict(b,addr=b.get('addr') or a0,page=t))
    jr=q.family=='jr' or q.g in('jr','jrx')
    cns=[x for x in nd.get('cns',[]) if x and x!='旧国鉄・JR各社']
    def opm(b):
        s=b.get('ops') or ''
        if jr and re.search('旅客鉄道|国有鉄道|JR|鉄道省',s):return True
        return any(x in s or COSHORT.get(x,'\0') in s or x[:3] in s for x in cns)
    pref=nd.get('pref')
    pn=PREF[int(pref)-1] if pref and str(pref).isdigit() and 0<int(pref)<=47 else None
    ln=q.name
    ops_=[b for b in cand if opm(b)]
    hit=[b for b in ops_ if ln in (b.get('lines') or '') or ln[:-1] in (b.get('lines') or '')]
    if not hit and pn:hit=[b for b in ops_ if pn in (b.get('addr') or '') or pn in b['page']]
    if not hit and len({b['page'] for b in ops_})==1 and (pn or not jr):
        # 문서가 하나이고 다른 도도부현이 적혀 있지 않으면 받는다
        hit=[b for b in ops_ if not any(x!=pn and x in (b.get('addr') or '') for x in PREF)]
    r={}
    if hit:
        ws_stat['hit']+=1
        # 폐지일은 그 노선의 블록에서만 쓴다. 같은 역의 다른 노선 폐지일이 넘어오면 현행 구간의 역이 사라진다 (佐々, 川内, 青森)
        lk_=re.sub(r'(本線|線)$','',ln)
        strict=[b for b in hit if not b.get('lines') or len(lk_)<2 or lk_ in b['lines']]
        o=[x for b in hit for x in b.get('open',[])]
        c_=[x for b in strict for x in b.get('close',[])]
        o=[x for x in o if 'X' not in x] or o
        c_=[x for x in c_ if 'X' not in x] or c_
        if o:r['open']=min(o,key=lambda x:lohi(x)[0] or '9')
        if c_:r['close']=max(c_,key=lambda x:lohi(x)[0] or '0')
    else:
        ws_stat['miss' if cand else 'nodoc']+=1
        if cand:ws_miss.append((q.cn,q.name,n0,[(b.get('ops') or '')[:18] for b in cand][:3],[(b.get('lines') or '')[:18] for b in cand][:2]))
    ws_cache[k]=r
    return r
def wd_line(nd,lname):
    """같은 노선을 지나는 Wikidata 항목만 쓴다"""
    k=znorm(lname);best={}
    for x in WD.get(nd['nm'],[]):
        if nd['pt'] and x.get('pt') and dist(nd['pt'],x['pt'])>3:continue
        if any(k in znorm(l) or znorm(l) in k for l in x['lines']):
            if not best or (x.get('open') or '9')<(best.get('open') or '9'):best=x
    return best
# ---- 사건
WY={}
_f=os.path.join(CAND,'wiki_years.json')
if os.path.exists(_f):
    for k,v in json.load(open(_f,encoding='utf-8')).items():
        if v[1]:WY[k]=v[1]+'-XX-XX'
events=collections.defaultdict(list)
JR_DAY='1987-04-01'
# SAME_NODE로 합친 역은 계통에 한 이름만 남는다. 다른 표의 구간 행이 다른 이름(島原外港)을 써도 찾게 한다
SAME_ALIAS={}
for _nm,_a,_b,_ in HT['SAME_NODE']:
    SAME_ALIAS[znorm(_a)]=znorm(_b);SAME_ALIAS[znorm(_b)]=znorm(_a)
def idx_in(c,pos,name):
    nm=znorm(name)
    # 표기가 그대로 같은 역이 먼저다. 한 부품에 옛 역(土佐穴内【旧】)과 지금 역(土佐穴内)이 함께 있다
    for i in pos:
        if c.seq[i][0].label.strip('*[]')==name.strip('*[]'):return i
    for n_ in (nm,SAME_ALIAS.get(nm)):
        if n_ is None:continue
        for i in pos:
            if c.seq[i][0].nm==n_ or znorm(c.seq[i][0].label.strip('*[]'))==n_:return i
    return None
def spans(c,part,rows):
    """표의 구간 행을 계통 edge 범위로 바꾼다. 이름을 못 찾으면 km 누적으로 찾는다"""
    out=[]
    pos=[i for i,(s,q) in enumerate(c.seq) if q is part]
    if not pos:return out
    base=getattr(c.seq[pos[0]][0],'prevkm',None)
    if pos[0]>0 and base is not None:pos=[pos[0]-1]+pos
    if base is None:base=c.seq[pos[0]][0].km
    run=0.0
    for r in rows:
        sec,k,d=r[0],r[1],r[2]
        kmv=float(k) if re.match(r'^[\d.]+$',k or '') else 0.0
        m=re.split(r'[～~]',sec)
        a=b=None
        if len(m)==2:
            a=idx_in(c,pos,m[0].strip('[]* '));b=idx_in(c,pos,m[1].strip('[]* '))
        if a is None or b is None:
            def near(x):
                best=min(pos,key=lambda i:abs(abs(c.seq[i][0].km-base)-x))
                return best if abs(abs(c.seq[best][0].km-base)-x)<=.25 else None
            if a is None:a=near(run)
            if b is None:b=near(run+kmv)
        run+=kmv
        # 환상선 부품은 끝 역이 처음과 끝 두 자리다. 한쪽 끝만 그 역인 행(サッカー場前～遊園地)은 행 km에 맞는 자리를 고른다 (よみうりランドモノレール 2026-11-11)
        if a is not None and b is not None and len(m)==2 and kmv>0 and len(pos)>2:
            rn_=c.seq[pos[0]][0].label.strip('*[]')
            if rn_==c.seq[pos[-1]][0].label.strip('*[]') and (m[0].strip('[]* ')==rn_)!=(m[1].strip('[]* ')==rn_):
                ca_=[pos[0],pos[-1]] if m[0].strip('[]* ')==rn_ else [a];cb_=[pos[0],pos[-1]] if m[1].strip('[]* ')==rn_ else [b]
                a,b=min(((x_,y_) for x_ in ca_ for y_ in cb_ if x_!=y_),key=lambda t_:abs(abs(c.seq[t_[1]][0].km-c.seq[t_[0]][0].km)-kmv))
        # 환상선 행(中央口～中央口)은 같은 역 둘이라 한 점으로 잡힌다. 부품이 그 역에서 시작해 그 역에서 끝나면 계통 전체로 본다
        if a==b and a is not None and len(m)==2 and m[0].strip('[]* ')==m[1].strip('[]* ') and len(pos)>1 and c.seq[pos[0]][0].label.strip('*[]')==c.seq[pos[-1]][0].label.strip('*[]')==m[0].strip('[]* '):a,b=pos[0],pos[-1]
        if a==b and a is not None:continue
        if a is None or b is None:
            unresolved.append((part.id,part.name,sec));continue
        out.append((min(a,b),max(a,b),edtf(d)))
    return out
unresolved=[]
def spec(c,i,j,alt=None):
    """edge 범위 i..j(양 끝 포함)를 a..b 표기로. 같은 노드가 두 번 나오는 계통은 edge를 직접 적는다"""
    if len(set(c.ns))<len(c.ns):return ','.join(c.eids[i:j+1])
    # 다른 노선이 만든 공용 선로 칸(SHARED_TRACK)이 끼면 이 노선 seed로 경로를 못 찾으니 칸을 직접 적는다
    if alt is None and any(tuple(sorted((c.ns[q],c.ns[q+1]))) in SHARED_TRACK_K and edges[c.eids[q]].get('seed_line')!=getattr(c,'lid',None) for q in range(i,j+1)):return ','.join(c.eids[i:j+1])
    a,b=c.ns[i],c.ns[j+1]
    return a+'..'+b+('@old' if alt else '')
def before(d,day):
    lo=lohi(d)[0]
    return lo is None or lo<day
def run_src(v,i,j):
    """edge 범위의 출처. 한 사건이 두 출처에 걸치면 함께 적는다"""
    return '+'.join(sorted({x for x in v[i:j+1] if x})) or None
EV=[];reloc_stat=[]
def reloc_windows(c0,ch):
    """이설 창: 옛 선형 사슬(c0의 옛 선로 alt, 또는 같은 노선의 옛 선형 지선 계통)이 날짜 D에 다 닫히고 두 끝이 c0의 역이면 (i,j,D,옛 선로 개업,옛 선로 칸).
    끝 역이 다른 노드여도 같은 이름이거나 300 m 안이면 그 역으로 본다(足尾線 神土: 옛 선로 계통이 따로 만든 神土 노드에서 시작)"""
    out=[]
    # 옛 선형 지선 계통: 옛 선형 부품(oldroute)이거나, N05 손 대조로 본선에 이어 붙인 옛 선로(n05join, 전 구간 폐지)
    def _old(q):
        if oldroute(q):return True
        try:return bool(getattr(q,'n05join',False)) and q.g=='old' and sum(float(r[1]) for r in q.close)>=q.km-.05
        except (TypeError,ValueError):return False
    olds=list(c0.alts)+[c for c in ch if c is not c0 and getattr(c,'role','')=='branch' and all(_old(q) for q in c.parts)]
    for a in olds:
        cl=[edtf(r[2]) for q in a.parts for r in q.close if len(r)>2 and edtf(r[2])]
        op=[edtf(r[2]) for q in a.parts for r in q.open if len(r)>2 and edtf(r[2])]
        if not cl or not op:continue
        D=max(cl,key=lambda d:lohi(d)[1]);O=min(op,key=lambda d:lohi(d)[0])
        def at(s_):
            k_=nid(s_)
            if k_ in c0.ns:return c0.ns.index(k_)
            pt_=nodes[k_]['pt']
            for i_,(t_,_) in enumerate(c0.seq):
                if getattr(t_,'ghost',False) or t_.old:continue
                m_=nodes[nid(t_)]
                if t_.nm==s_.nm or s_.nm in {znorm(x) for x in m_['labels']} or (pt_ and m_['pt'] and dist(pt_,m_['pt'])<.3):return i_
            return None
        i_,j_=at(a.seq[0][0]),at(a.seq[-1][0])
        if i_ is None or j_ is None or i_==j_:continue
        if i_>j_:i_,j_=j_,i_
        out.append((i_,j_,D,O,{tuple(sorted((nid(x),nid(y)))) for (x,_),(y,_) in zip(a.seq,a.seq[1:])}))
    return out
for lk,ps,ch in line_rel:
    l=lid[lk]
    for c0 in ch:
        for c,alt in [(c0,None)]+[(x,'old') for x in c0.alts]:
            n=len(c.eids)
            opened=[None]*n;closed=[None]*n;reason=[None]*n;xfer=[None]*n;pop=[None]*n
            opened_s=[None]*n;closed_s=[None]*n;lost_s=[None]*n
            fam=c.parts[0].family
            for part in c.parts:
                co=jr_of(part) if fam=='jr' or part.g=='jrx' else (oid(part.c) if part.c!='x' else prx_op(part))
                pos=[i for i,(s,q) in enumerate(c.seq) if q is part]
                for i in pos:
                    if i>0:pop[i-1]=co
                if pos and pos[0]==0 and False:pass
                for a,b,d in spans(c,part,part.open):
                    for i in range(a,b):opened[i]=d;opened_s[i]='hand' if d in part.hand_open else part.s['open']
                for a,b,d in spans(c,part,part.close):
                    for i in range(a,b):
                        closed[i]=d;closed_s[i]=part.s['close']
                        # 화물선을 모선의 지선 계통으로 둔 표(route_extra, 여객 이력 있는 화물·연결선)의 끝은 여객 운행이 끝난 것이다. 선로는 화물로 남으니 폐지가 아니라 정기 운행 없음 (新金線·北方貨物線·馬橋支線·北小金支線, 3회차 kanto_3-21)
                        reason[i]='relocated' if alt else ('brt' if (part.name,c.seq[a][0].name) in BRT else REASON.get(part.name,'no_regular_service' if getattr(part,'route_extra',False) else 'abolished'))
            # 표의 구간 행이 순환·숨은 노드 때문에 안 풀린 곳
            for part in c.parts:
                po_=[i for i,(s_,q_) in enumerate(c.seq) if q_ is part and i<n]
                for i in po_:
                    if opened[i] is None and len(part.open)==1:opened[i]=edtf(part.open[0][2]);opened_s[i]='hand' if opened[i] in part.hand_open else part.s['open']
                    if opened[i] is None and part.name in LINEOPEN:opened[i]=LINEOPEN[part.name];opened_s[i]='hand'
            # 이설 새 선로는 옛 선로가 닫힌 날 열린다 (2회차 종합 K19: 足尾線 草木ダム, 東北本線 野内–青森).
            # 표는 새 선로 칸에도 그 구간의 첫 개업일을 적어 옛·새 선로가 함께 영업한 것처럼 된다. 옛 선로와 같이 쓰지 않는 칸만, 손 개업일은 그대로.
            # 옛 선로가 본선보다 늦게 생긴 일시 우회(近鉄丹波橋 1945~1967)는 이설이 아니라 건드리지 않는다
            if alt is None:
                for wi,wj,D,O,ap in reloc_windows(c0,ch):
                    for i in range(wi,min(wj,n)):
                        if tuple(sorted((c.ns[i],c.ns[i+1]))) in ap or opened_s[i]=='hand' or not opened[i]:continue
                        if lohi(O)[0]<=lohi(opened[i])[0] and lohi(opened[i])[1]<lohi(D)[0]:
                            opened[i]=D;opened_s[i]='rule';reloc_stat.append((l,c.ns[i],c.ns[i+1],D))
            lost=[None]*n;legal=[None]*n
            for part in c.parts:
                for a,b,d in spans(c,part,part.svc):
                    for i in range(a,b):lost[i]=d;lost_s[i]='hand' if part.name in SVC else part.s['close']
                for a,b,d in spans(c,part,part.legal):
                    for i in range(a,b):legal[i]=d
            # 승계
            tr={}
            for part in c.parts:
                for q,keys in getattr(part,'trans',[]):
                    ks={find(k) for k in keys}
                    for i in range(n):
                        (s,_),(t,_)=c.seq[i],c.seq[i+1]
                        if find(s.key) in ks and find(t.key) in ks:xfer[i]=q
            r=c.r if alt is None else c0.r
            rid=c.rid
            owned=bool(r.get('owned')) or bool(alt)
            # 공용 선로 칸(SHARED_TRACK)은 승계 노선이라도 앞 노선에서 넘겨받는 칸이 아니라 함께 여는 칸이다(のと鉄道 七尾–和倉温泉)
            shared_i=[tuple(sorted((c.ns[i],c.ns[i+1]))) in shared and tuple(sorted((c.ns[i],c.ns[i+1]))) not in SHARED_TRACK_K and alt is None for i in range(n)]
            issucc=any(q.id in SUCC for q in c.parts)
            def emit_runs(pred,fn):
                i=0
                while i<n:
                    if not pred(i):i+=1;continue
                    j=i;v=fn(i)
                    while j+1<n and pred(j+1) and fn(j+1)==v:j+=1
                    yield i,j,v
                    i=j+1
            # 개업
            # 등급의 기준은 법적 폐지일. 노리츠부시 표의 폐지일이 여객 영업 끝인 국철 노선은 LEGAL 표에 법적 폐지일이 있다
            # LEGAL은 그 노선의 마지막 폐지 구간 것이다. 먼저 폐지된 다른 구간(日田彦山線 石田–東小倉 1956)에 붙이지 않는다 (감사 T2-01)
            lastc_=max([x for x in closed if x and 'X' not in x] or ['0'])
            # LEGAL 값이 [폐지일, 법적 폐지일]이면 그 폐지일의 구간에만 붙인다 (日田彦山線 石田–東小倉 지선은 1956년에 따로 닫힘, S5 조사)
            def legal_of(name,cl):
                v=LEGAL.get(name)
                if isinstance(v,list):return v[1] if cl==v[0] else None
                return v
            lg_=[legal[i] or (legal_of(c.seq[i+1][1].name,closed[i]) if fam=='jr' and closed[i]==lastc_ else None) or closed[i] or '9999' for i in range(n)]
            reused_=getattr(c,'reused',set())
            for i,j,v in emit_runs(lambda i:not(issucc and shared_i[i]) and i not in reused_,lambda i:(opened[i],pop[i],lg_[i]<'2000',lg_[i]<'1969-12-08')):
                d,co,_o,_j=v
                if fam=='jr' and before(d,JR_DAY):co='o_japanese_national_railways'
                ev=dict(date=d,type='open',operator=co,line=l,edges=spec(c,i,j,alt).split(','))
                # 새로 들어오던 폐선(1950~1969 국철, 처음부터 사철이던 1950~1999)은 N05 대조가 끝나 판 2026-11-04.2부터 분모 안이다 (DESIGN §2.8 O, §4.6).
                # 다음에 새 범위를 넣을 때는 대조가 끝날 때까지 여기서 그 범위를 outside로 둔다
                if owned:ev['route']=rid
                ev['source']=run_src(opened_s,i,j) or c.seq[i+1][1].s['open']
                EV.append((fam,ev))
            # 국철 → JR
            if fam=='jr':
                def alive(i):
                    return i not in reused_ and before(opened[i],JR_DAY) and (closed[i] is None or not before(closed[i],JR_DAY))
                for i,j,co in emit_runs(alive,lambda i:pop[i]):
                    ev=dict(date=JR_DAY,type='transfer',edges=spec(c,i,j,alt).split(','),**{'from':dict(operator='o_japanese_national_railways',line=l),'to':dict(operator=co,line=l)})
                    if owned:ev['route']=rid
                    ev['source']='rule'
                    EV.append((fam,ev))
            # 폐지와 이관
            for i,j,v in emit_runs(lambda i:(closed[i] is not None or xfer[i] is not None) and i not in reused_,lambda i:(closed[i],xfer[i].id if xfer[i] else None,reason[i],lost[i],legal[i])):
                d,qid,why,ls,lg=v
                part=c.seq[i][1]
                if qid:
                    q=xfer[i]
                    dd=d
                    if dd is None:
                        for x in q.open:dd=dd or edtf(x[2])
                    co=pop[i]
                    if before(dd,JR_DAY):co='o_japanese_national_railways'
                    ev=dict(date=dd,type='transfer',edges=spec(c,i,j).split(','),source=run_src(closed_s,i,j) or q.s['open'],**{'from':dict(operator=co,line=l),'to':dict(operator=oid(q.c),line=lid[q.lk])})
                    oh=OPHIST.get(q.name)
                    if oh:
                        ev['to']['operator']=OPHIST_ID[oh[0]]
                        EV.append((fam,dict(date=oh[1],type='transfer',edges=spec(c,i,j).split(','),source='hand',**{'from':dict(operator=OPHIST_ID[oh[0]],line=lid[q.lk]),'to':dict(operator=oid(q.c),line=lid[q.lk])})))
                    qo=sorted(edtf(x[2]) for x in q.open if edtf(x[2]) and 'X' not in edtf(x[2]))
                    gap=[x for x in qo if dd and 'X' not in dd and x>dd]
                    if gap and gap[0][:4]==dd[:4]:
                        EV.append((fam,ev))
                        EV.append((fam,dict(date=dd,type='suspend',line=lid[q.lk],edges=spec(c,i,j).split(','),source=ev['source'])))
                        ev=dict(date=gap[0],type='resume',line=lid[q.lk],edges=spec(c,i,j).split(','),source=q.s['open'])
                else:
                    ev=dict(date=d,type='close',line=l,edges=spec(c,i,j,alt).split(','),reason=why,source=run_src(closed_s,i,j))
                    bd=BRTDAY.get((part.name,c.seq[i][0].name))
                    if bd:ev['legal_abolition']=d;ev['date']=bd;ev['source']='hand'
                    if part.name in LAST and (d or '')>=LAST[part.name]:
                        ev['last_service']=LAST[part.name];ev['legal_abolition']=d
                        import datetime as _dt
                        ev['valid_to']=(_dt.date.fromisoformat(LAST[part.name])+_dt.timedelta(days=1)).isoformat()
                    # 폐지일보다 늦은 운행 중단은 같은 노선 이름의 다른 구간 것이다 (根室本線 2016 불통이 1966 옛 선로에 붙던 것, DB 감사 DBA-003)
                    if ls and not (d and ls[:10]>d[:10]):
                        import datetime as _dt
                        ev['last_service']=ls
                        if 'X' not in ls and ls<(ev['date'] or '9'):
                            EV.append((fam,dict(date=(_dt.date.fromisoformat(ls)+_dt.timedelta(days=1)).isoformat(),type='suspend',line=l,edges=spec(c,i,j,alt).split(','),source=run_src(lost_s,i,j),**({'route':rid} if owned else {}))))
                    if lg:
                        ev['legal_abolition']=lg
                        # 범위 날짜(士別軌道 [1955-04-01..1956-03-31])는 하루 앞을 셀 수 없어 마지막 운행일을 두지 않는다
                        if lg!=d and d and 'X' not in d and not d.startswith('[') and not ev.get('last_service'):
                            import datetime as _dt
                            ev['last_service']=(_dt.date.fromisoformat(d)-_dt.timedelta(days=1)).isoformat()
                    if part.name in LEGAL and fam=='jr' and d==lastc_ and legal_of(part.name,d):ev['legal_abolition']=legal_of(part.name,d)
                if owned:ev['route']=rid
                EV.append((fam,ev))
            # 지금 불통인 구간. 폐지 신고 전까지 현행으로 둔다 (§3.2)
            for part in c.parts:
                nms_={t_ for s_ in part.st for t_ in (s_.name,s_.nm,znorm(s_.name))}
                for x in (SUSPENDED.get(part.name+'@old',[]) if alt else SUSPENDED.get(part.name,[])+SUSPENDED.get(f'{part.name}|{part.cn}',[])+part.x_susp):
                    if not(({x[0],znorm(x[0])}&nms_) and ({x[1],znorm(x[1])}&nms_)):continue
                    for a,b,d in spans(c,part,[[f'{x[0]}～{x[1]}','0',x[2]]]):
                        o_={'route':rid} if owned else {}
                        EV.append((fam,dict(date=d,type='suspend',line=l,edges=spec(c,a,b-1,alt).split(','),source='hand',**o_)))
                        if len(x)>4 and x[4]:EV.append((fam,dict(date=x[4],type='resume',line=x[5] if len(x)>5 else l,edges=spec(c,a,b-1,alt).split(','),source='hand',**o_)))
            # 정차 사건
            for i,(s,q) in enumerate(c.seq):
                if getattr(s,'ghost',False) or s.hidden:continue
                nd=nodes[nid(s)]
                wd=wd_line(nd,q.name)
                ws=ws_for(nd,q)
                if s.closed:
                    # 손 대조 표(gen_n05)의 역 폐지일은 사람이 위키 원문에서 옮긴 값이라 역 자료보다 앞선다
                    hand_=getattr(s,'n05src',None)=='wikipedia'
                    d,d_src=next(((a_,b_) for a_,b_ in ((STOPCLOSE.get(s.nm),'hand'),(hand_ and s.n05close,'wikipedia'),(ws.get('close'),'wikipedia'),(nd['sd_close'],'station_database'),(wdday(wd.get('close')),'wikidata'),(wdday(wd.get('dis')),'wikidata'),(getattr(s,'n05close',None),'n05'),(getattr(s,'wclose',None) and (str(s.wclose)+'-XX-XX' if len(str(s.wclose))==4 else str(s.wclose)),'wikipedia'),(WY.get(l+'|'+nd['id']),'wikipedia')) if a_),(None,q.s['close']))
                    EV.append((fam,dict(date=d,type='close_stop',route=rid,node=nd['id'],source=d_src)))
                op=ws.get('open') or (nd['sd_open'] if nd['sd_only'] else None)
                op_src='wikipedia' if ws.get('open') else 'station_database'
                if not op:op=None if ws else wdday(wd.get('open'));op_src='wikidata'
                # 위키 노선도에서 끼워 넣은 옛 역은 그 표의 개업 연도를 쓴다. 없으면 노선 개통일이 되어 臨時駅이 수십 년 앞서 열린다 (フイハップ浜)
                if not op and getattr(s,'wopen',None):op,op_src=(str(s.wopen)+'-XX-XX' if len(str(s.wopen))==4 else str(s.wopen)),'wikipedia'
                if getattr(s,'n05open',None) and (not op or getattr(s,'n05src',None)=='wikipedia'):op,op_src=s.n05open,s.n05src
                # N05 손 대조 행은 늦게 생긴 역을 stop_open에 적는다. 같은 이름의 다른 역(노면전차 栄町과 지하철 栄)의 문서 개업일은 쓰지 않는다
                elif q.n05pt:op=None
                adj_o=[opened[k] for k in (i-1,i) if 0<=k<n and opened[k]]
                if s.closed and op and d and (lohi(d)[0] or '9')<=(lohi(op)[0] or '0'):op=None
                ends=[closed[k] for k in (i-1,i) if 0<=k<n and closed[k]]
                if op and ends and (lohi(op)[0] or '')>=(max(lohi(x)[0] or '' for x in ends)):op=None
                # 역 문서와 노선 문서의 표기 차이(하루 등)는 역 폐지로 치지 않는다
                # 마지막 날(6/30)과 폐지일(7/1)처럼 달이 바뀌는 하루 차이도 같다
                end_=min(lohi(x)[0] or '9' for x in ends) if ends else '9'
                oneday=bool(re.match(r'^\d{4}-\d\d-\d\d$',ws.get('close') or '')) and bool(re.match(r'^\d{4}-\d\d-\d\d$',end_)) and (datetime.date.fromisoformat(end_)-datetime.date.fromisoformat(ws['close'])).days==1
                if not s.closed and ws.get('close') and ends and (lohi(ws['close'])[1] or '9')<end_ and ws['close'][:7]!=end_[:7] and not oneday:
                    EV.append((fam,dict(date=ws['close'],type='close_stop',route=rid,node=nd['id'],source='wikipedia')))
                if op and adj_o and (lohi(op)[0] or '')>((min if ws.get('open') else max)(lohi(x)[0] for x in adj_o)):
                    EV.append((fam,dict(date=op,type='open_stop',route=rid,node=nd['id'],source=op_src)))
print('역 문서',dict(ws_stat))
os.makedirs(CAND,exist_ok=True)
json.dump(ws_miss,open(os.path.join(CAND,'ws_miss.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=0)
print('구간 행 미해결',len(unresolved),unresolved[:12])
print('이설 새 선로 개업일을 옛 선로 폐지일로',len(reloc_stat),sorted({(a,d) for a,_,_,d in reloc_stat})[:40])

# ---- 부품별 이력의 '기간 한정 별선'
for lk,ps,ch in line_rel:
    l=lid[lk]
    for c in ch:
        for part in c.parts:
            if part.until:
                import datetime
                d=(datetime.date.fromisoformat(part.until)+datetime.timedelta(days=1)).isoformat()
                ev=dict(date=d,type='close',line=l,route=c.rid,edges=spec(c,0,len(c.eids)-1).split(','),reason='no_regular_service',source=part.s['close'])
                EV.append((part.family,ev))

# ---- 그룹·환승 묶음
gpar={}
def gf(x):
    gpar.setdefault(x,x)
    while gpar[x]!=x:
        gpar[x]=gpar[gpar[x]];x=gpar[x]
    return x
bynm=collections.defaultdict(list)
for n in nodes.values():bynm[n['nm']].append(n)
for L in bynm.values():
    for i,a in enumerate(L):
        for b in L[i+1:]:
            if dist(a['pt'],b['pt'])<1.0:gpar[gf(b['id'])]=gf(a['id'])
# 이름이 바뀌었거나 표기가 달라 위 규칙으로 묶이지 않는 같은 역 (손 표). 좌표는 선형 전이라 넉넉히 2km
for a_,b_,_ in HT['SAME_STATION']:
    for a in bynm.get(znorm(a_),()):
        for b in bynm.get(znorm(b_),()):
            # 손 표라 좌표가 아직 없는 노드(wikidata 좌표 전)도 같은 도도부현이면 묶는다. 좌표가 둘 다 있으면 2km 안만 (감사 TOP-10: 中津, 糠ノ目=高畠)
            near_=dist(a['pt'],b['pt'])<2.0 if a['pt'] and b['pt'] else (a.get('pref') is not None and a.get('pref')==b.get('pref'))
            if a is not b and near_:gpar[gf(b['id'])]=gf(a['id'])
gm=collections.defaultdict(list)
for n in nodes.values():
    gm[gf(n['id'])].append(n)
gids={}
for k,L in gm.items():
    g='g_'+L[0]['id'][2:];gids[k]=g
    for n in L:n['group']=g
# 300m 격자로 환승 후보
grid=collections.defaultdict(list)
for n in nodes.values():
    if n['pt']:grid[(int(n['pt'][0]*100),int(n['pt'][1]*100))].append(n)
hp={}
def hf(x):
    hp.setdefault(x,x)
    while hp[x]!=x:
        hp[x]=hp[hp[x]];x=hp[x]
    return x
# 같은 이름은 350m 안에서만, 이름이 다른 역은 역 문서의 乗換·接続路線 칸에 적힌 것만 묶는다. 같은 노선의 이웃 역은 묶지 않는다
def xn(t):
    t=unicodedata.normalize('NFKC',t or '')
    for a_,b_ in (('ヶ','ケ'),('ヵ','ケ'),('之','ノ'),('﨑','崎'),('髙','高'),('澤','沢'),('濱','浜')):t=t.replace(a_,b_)
    return t
node_lines=collections.defaultdict(set);adjpair=set()
for p in parts:
    prev=None
    for o in p.st:
        if getattr(o,'ghost',False) or o.hidden:continue
        k_=nid(o);node_lines[k_].add(p.name)
        if prev and prev!=k_:adjpair.add(frozenset((prev,k_)))
        prev=k_
def xf_text(n):
    n0=n['name'];out=[];hit=False
    pages=[n0 if n0.endswith('駅') else n0+'駅',n0+'停留場']
    for t in list(pages):pages+=(WS.get(t) or {}).get('alt') or []
    for t in pages:
        e=WS.get(t)
        if e and not e.get('missing') and t.startswith(n0):
            hit=True;out+=[b.get('xf','') for b in e.get('blocks',[])]
    return xn(' '.join(out)) if hit else None
TX={k_:xf_text(n) for k_,n in nodes.items() if n['kind']=='station'}
def named(y,T):
    for nm in {xn(y['name']),xn(y['nm']),*[xn(x) for x in y['labels']]}:
        nm=re.sub(r'[（(].*$','',nm)
        if nm and ((len(nm)>=3 and nm in T) or any(nm+x in T for x in('駅','停留場','電停'))):return True
    return False
def line_or_op(y,T):
    return any(l and l in T for l in node_lines[y['id']]) or any(c and (c in T or c[:3] in T or COSHORT.get(c,'\0') in T) for c in y['cns'])
evid=set()
for (a,b),L in grid.items():
    near=[]
    for i in(-1,0,1):
        for j in(-1,0,1):near+=grid.get((a+i,b+j),[])
    for x in L:
        T=TX.get(x['id'])
        if not T:continue
        c=collections.defaultdict(list)
        for y in near:
            if y['id']!=x['id'] and y['kind']=='station' and xn(y['nm'])!=xn(x['nm']) and dist(x['pt'],y['pt'])<.8 and named(y,T):c[xn(y['nm'])].append(y)
        for v in c.values():
            for y in ([y for y in v if line_or_op(y,T)] or v):evid.add(frozenset((x['id'],y['id'])))
# 역 문서 乗換 칸만으로 찾은 쌍. compile의 hub_pair 규칙은 근접 쌍이 아니라 이것을 문서 근거로 친다
xf=set(evid)
# 문서 칸만으로는 모자란다 (乗換 값이 있는 블록 501개). 공통 노선이 없고 아주 가까우면 연락역으로 친다
HUBX=json.load(open(os.path.join(ROOT,'data','overrides','hub_pairs.json'),encoding='utf-8'))
HUBX={frozenset(xn(t) for t in p_) for p_ in HUBX}
for (a,b),L in grid.items():
    near=[]
    for i in(-1,0,1):
        for j in(-1,0,1):near+=grid.get((a+i,b+j),[])
    for x in L:
        for y in near:
            if x['id']<y['id'] and x['kind']==y['kind']=='station' and frozenset((x['id'],y['id'])) not in adjpair and not node_lines[x['id']]&node_lines[y['id']]:
                d_=dist(x['pt'],y['pt'])
                if d_<(.25 if x['family']!=y['family'] else .1) or (d_<.45 and any(frozenset((p_,q_)) in HUBX for p_ in {xn(x['nm']),xn(x['name'])} for q_ in {xn(y['nm']),xn(y['name'])})):
                    if xn(x['nm'])!=xn(y['nm']) or d_>=.35:evid.add(frozenset((x['id'],y['id'])))
for L in gm.values():
    for i,x in enumerate(L):
        for y in L[i+1:]:
            if x['pt'] and y['pt'] and dist(x['pt'],y['pt'])<.35:hp[hf(y['id'])]=hf(x['id'])
for (a,b),L in grid.items():
    near=[]
    for i in(-1,0,1):
        for j in(-1,0,1):near+=grid.get((a+i,b+j),[])
    for x in L:
        for y in near:
            if x['id']<y['id'] and x['family']!=y['family'] and dist(x['pt'],y['pt'])<.3:
                f=frozenset((x['id'],y['id']))
                if f in adjpair:continue
                if xn(x['nm'])==xn(y['nm']) or f in evid or (TX.get(x['id']) is None and TX.get(y['id']) is None and dist(x['pt'],y['pt'])<.15):hp[hf(y['id'])]=hf(x['id'])
# X駅前·X駅 정류장은 철도역 X와 묶는다. 철도역 문서의 乗換 칸이 비어 있는 곳이 많다
for (a,b),L in grid.items():
    near=[]
    for i in(-1,0,1):
        for j in(-1,0,1):near+=grid.get((a+i,b+j),[])
    for x in L:
        for y in near:
            if y['id']!=x['id'] and y['kind']==x['kind']=='station' and frozenset((x['id'],y['id'])) not in adjpair and dist(x['pt'],y['pt'])<.45:
                if re.sub(r'[（(].*$','',xn(y['name'])) in (xn(x['nm'])+'駅前',xn(x['nm'])+'駅') or xn(y['nm'])==xn(x['nm'])+'駅前':hp[hf(y['id'])]=hf(x['id'])
# 문서 근거로 잇되 묶음 지름이 1.1km를 넘으면 잇지 않는다 (肥後橋~北新地~梅田처럼 사슬이 길어지는 것을 막는다)
mem=collections.defaultdict(list)
for k_,n in nodes.items():
    if n['kind']=='station':mem[hf(k_)].append(k_)
for f in sorted(evid,key=sorted):
    if f in adjpair:continue
    a_,b_=sorted(f);ra,rb=hf(a_),hf(b_)
    if ra==rb:continue
    pts_=[nodes[k_]['pt'] for k_ in mem[ra]+mem[rb] if nodes[k_]['pt']]
    if any(dist(p_,q_)>1.1 for p_ in pts_ for q_ in pts_):continue
    hp[rb]=ra;mem[ra]+=mem.pop(rb)
HUBEV=dict(evid=sorted(sorted(f) for f in evid),xf=sorted(sorted(f) for f in xf),doc=sorted(k_ for k_,v_ in TX.items() if v_ is not None),adj=sorted(sorted(f) for f in adjpair))
hm=collections.defaultdict(list)
for n in nodes.values():
    if n['kind']=='station':hm[hf(n['id'])].append(n['id'])
hubs=[dict(id='hub_'+sorted(v)[0][2:],nodes=sorted(v),source=['station_database','proximity_300m'],verified=False) for v in hm.values() if len(v)>1]

# 이름 열쇠 읽기(위키 「X駅」 문서·N05 다른 노선 표)는 그 이름의 어느 한 역 읽기다. 그 역이 이 노드인지 가린다 (3회차 kyushu_1-005, 9회차 N):
#  ① 문서 역 정보칸·N05 표의 사업자가 이 노드 사업자(노리츠부시 회사)와 맞으면 이 역의 읽기다
#  ② 같은 이름 노드가 모두 5 km 안(같은 곳의 같은 역·정류장)이면 그 이름의 역은 이곳이다
#  ③ 같은 이름 다른 노드가 있으면 5 km 안 같은 이름 역이 자기 근거(역 자료·그 노선 N05·위키데이터)로 같은 읽기일 때만 쓴다(노선 전용 이름 읽기의 5 km 규칙과 같음)
#  그 밖은 다른 역의 읽기를 빌려 온 것이라 비운다. 손 조사 표(kana.json·kana_est.json)는 이름마다 근거를 따로 적은 것이라 그대로 둔다
def _opc(t):return re.sub(r'株式会社|[（(].*?[)）]|\s','',unicodedata.normalize('NFKC',t or ''))
def _opm(ops,cns):
    a_=[_opc(y) for o in ops for y in re.split(r'<br\s*/?>|、|・',o) if len(_opc(y))>=2];b_=[_opc(c) for c in cns if len(_opc(c))>=2]
    return any(x==y or x in y or y in x for x in a_ for y in b_)
_NMALL=collections.defaultdict(list)
for n in nodes.values():
    if n['kind']=='station':_NMALL[n['nm']].append(n)
def _far_same(nm_,pt_,id_):
    """5 km 밖(또는 자리를 모르는) 같은 이름 다른 노드가 있는가"""
    return any(m['id']!=id_ and not (m['pt'] and pt_ and dist(m['pt'],pt_)<5) for m in _NMALL.get(nm_,[]))
_NMOWN=collections.defaultdict(list)
for n in nodes.values():
    if n['kind']=='station' and n['kana'] and not n.get('_namekey'):_NMOWN[n['nm']].append(n)
def _wcore(t):return znorm(re.sub(r'(駅|停留場|停留所|電停|仮乗降場|乗降場|信号場)$','',re.sub(r'\s*[（(].*?[)）]\s*$','',t or '')))
def namekey_ok(k_,nm_,cns_,pt_,kana_,id_=None):
    s_=KSRC.get(k_)
    if not s_:return True
    # 손 읽기 표·추정 표(kana.json·kana_est.json)의 「node:이름」도 이름 하나에 읽기 하나다. 같은 이름 다른 노드가 5 km 밖(자리 모름 포함)에 있으면
    # 어느 역 읽기인지 가를 수 없어 쓰지 않는다. 그 역 하나를 가리키는 읽기는 「노드 ID|이름」 열쇠(old_names_kana.json)로 넣는다
    # (呉服町 ごふくちょう·ごふくまち, 清水町, 大和町처럼 町 읽기가 역마다 다름. 13회차 2026-11-19 사용자 지적)
    # 다만 1 km 안 같은 이름 역(같은 교차점의 다른 회사 역)이 그 역 자신의 근거(역 자료·ID 지정 읽기 등)로 같은 읽기면 같은 곳 이름이라 쓴다 (大阪市電 片町 ← 片町線·京阪 片町)
    if s_[0] in ('hand','est'):return not _far_same(nm_,pt_,id_) or any(m['id']!=id_ and m['pt'] and pt_ and dist(m['pt'],pt_)<1 and kata2hira(m['kana']).replace(' ','')==kata2hira(kana_).replace(' ','') for m in _NMOWN.get(nm_,[]))
    # 문서 제목이 그 이름이 아니면(넘겨주기로 지금 역 문서: 真脇 → 縄文真脇駅 じょうもんまわき, 加茂野口 → 加茂野駅) 다른 이름의 읽기다
    if s_[0]=='wiki' and _wcore(s_[1])!=znorm(k_.split(':',1)[1]):return False
    ops_=[b.get('ops','') for b in (WS.get(s_[1]) or {}).get('blocks',[])] if s_[0]=='wiki' else sorted(s_[1])
    if _opm(ops_,cns_):return True
    if not _far_same(nm_,pt_,id_):NK_ONLY.append((id_,nm_,kana_,s_[0]));return True
    return any(m['pt'] and pt_ and dist(m['pt'],pt_)<5 and kata2hira(m['kana']).replace(' ','')==kata2hira(kana_).replace(' ','') for m in _NMOWN.get(nm_,[]))
# 확인 없이 받은 Wikidata 읽기(이 단계에 점이 없는 노드·좌표 없는 항목)는 좌표가 정해진 뒤 다시 본다. 좌표 보정 파일(data/overrides/positions)까지 반영한
# 이 역 점에서 같은 이름 항목이 모두 5 km 밖이면 다른 곳의 역 읽기를 빌린 것이라 비운다 (손으로 넣은 西鉄 甘木線 高島, 2026-11-18)
from lib import _FILL as _FILL0,_rows as _rows0
_k0,_t0,_s0=_FILL0['positions']
_POS0={x[_k0]:(x['lat'],x['lon']) for x in _rows0(os.path.join(ROOT,'data','overrides','positions')) if source_on(_s0.get(x.get(_t0),x.get(_t0))) and x.get('lat') is not None}
WDU_DROP=[]
for n in nodes.values():
    if not n.get('_wdu'):continue
    p_=_POS0.get(n['id']) or n['pt']
    near_=[x for x in WD.get(n['_wdu'],[]) if x.get('kana') and x.get('pt')]
    if p_ and near_ and not any(dist(p_,x['pt'])<5 for x in near_):WDU_DROP.append((n['id'],n['name'],n['kana']));n['kana']=None
    # 좌표 없는 Wikidata 항목의 읽기는 어느 역 것인지 모른다. 같은 이름 다른 노드가 5 km 밖에 있으면 그 역 항목일 수 있어 쓰지 않는다 (13회차 2026-11-19)
    elif _far_same(n['nm'],p_,n['id']):WDU_DROP.append((n['id'],n['name'],n['kana']));n['kana']=None
print('확인 없이 받은 Wikidata 읽기 좌표로 다시 봐 뺌',len(WDU_DROP),sorted(WDU_DROP)[:40])
NK_ONLY=[]
NAMEKEY_DROP=[]
for n in nodes.values():
    if n.get('_namekey') and not namekey_ok(n['_namekey'],n['nm'],n['cns'],n['pt'],n['kana'],n['id']):
        NAMEKEY_DROP.append((n['id'],n['name'],n['kana'],KSRC[n['_namekey']][0]));n['kana']=None
print('이름 열쇠 읽기 뺌(다른 역 읽기)',len(NAMEKEY_DROP),sorted(NAMEKEY_DROP)[:60])
print('이름 열쇠 읽기 규칙②(같은 이름 노드 하나)로만 씀',len(NK_ONLY),sorted(NK_ONLY,key=str)[:200])
# 읽기가 비었거나 위에서 뺀 역은 그 역 자신의 위키 문서(「X駅 (県)」처럼 구별 꼬리가 붙은 제목 포함)에서 찾는다.
# 문서 제목(넘겨주기면 넘어간 문서 제목)의 이름이 이 노드 이름과 같고, 역 정보칸의 사업자가 이 노드 사업자와 맞는 문서의 읽기만 쓴다.
# 맞는 문서가 여럿인데 읽기가 갈리면 쓰지 않는다 (市役所前 長野電鉄 しやくしょまえ, 柳橋 黒部峡谷鉄道, 13회차 2026-11-19)
_WSN=collections.defaultdict(list)
for t_,d_ in WS.items():
    m_=re.match(r'^(.+?)(駅|停留場|停留所|電停)(\s*[（(].*[)）])?$',t_)
    if m_ and d_.get('blocks'):_WSN[znorm(m_.group(1))].append(d_)
WIKI_OP_FILL=[]
for n in nodes.values():
    if n['kana'] or n['kind']!='station':continue
    # 이름이 가나만으로 된 역(あびこ)은 이름이 곧 읽기다
    if re.fullmatch(r'[ぁ-ゖァ-ヺー]+',n['name'] or ''):
        n['kana']=kata2hira(n['name']);n['_ksrc']='auto:name_is_kana';n.pop('_namekey',None);WIKI_OP_FILL.append((n['id'],n['name'],n['kana']));continue
    ks_=set()
    for d_ in _WSN.get(n['nm'],[]):
        if _wcore(d_.get('title'))!=n['nm']:continue
        for b_ in d_['blocks']:
            if b_.get('kana') and _opm([b_.get('ops','')],n['cns']):ks_.add(re.sub(r'(えき|ていりゅうじょう|ていりゅうしょ|でんてい)$','',kata2hira(b_['kana']).replace(' ','')))
    if len(ks_)==1:
        n['kana']=ks_.pop();n['_ksrc']='auto:wiki_station_op';n.pop('_namekey',None);WIKI_OP_FILL.append((n['id'],n['name'],n['kana']))
print('그 역 위키 문서(사업자 일치)로 채운 읽기',len(WIKI_OP_FILL),sorted(WIKI_OP_FILL)[:80])

# ---- 이름
names=[];pend=[]
TODAY=AS_OF
def add(et,i,lang,text,**k):
    x=dict(entity_type=et,id=i,lang=lang,text=text);x.update({a:b for a,b in k.items() if b is not None});names.append(x)
for n in nodes.values():
    add('node',n['id'],'ja',JAFIX.get(n['id'],n['name']),kana=n['kana'],source='hand' if n['id'] in JAFIX else n['name_src'],
        reading_source=n.get('_ksrc') if n['kana'] else None)
    w=n['wd'] or {}
    if n['kind']!='station':continue
    t=None;src=None
    kana=n['kana']
    if kana:
        hk=kata2hira(kana)
        v=ko.NW.get((n.get('sdname') or '')+'|'+hk) or ko.NW.get(re.sub(r'[（(].*?[)）]','',n['name']).strip()+'|'+hk) or ko.NW.get(n['nm']+'|'+hk)
        if v:t,src=v[0],v[1]
        else:t=ko.station(hk,n['name']);src='estimated' if 'node:'+n['name'] in GUESS else 'rule'
        if n['name'].endswith('駅') and t.endswith('에키'):t=t[:-2]+'역'
    elif w.get('ko'):
        t=re.sub(r'\s*\(.*?\)\s*','',w['ko']);t=t[:-1] if t.endswith('역') else t;src='wikidata'
    t=NAMEKO.get(n['id']) or (NAMEKO.get(n['name'],t) if t else NAMEKO.get(n['name']))
    if t:add('node',n['id'],'ko',t,source=src,checked=TODAY)
    else:pend.append(('node',n['id'],n['name']))
    e=w.get('en')
    if e:
        e=re.sub(r'\s*\(.*?\)\s*','',e).replace('\u2010','-');e=re.sub(r'(?<=[a-z])Station$','',e);e=re.sub(r'\s+(train\s+)?(station|stop|tram stop|staton)$','',e,flags=re.I)
        if e.lower() in('station','stop') or len(e.split())>3:e=None
        # 「前」 역인데 라벨에 mae가 없고 시설 낱말(Shrine·Hospital·Office·University·Park·Ground)이 있으면 역이 아닌 시설 항목의 라벨이다
        # (櫛田神社前=Kushida Shrine, 県庁前=Prefectural Office, 市立病院前=Naha City Hospital). 규칙 로마자로 둔다 (3회차 kyushu_2-10·kyushu_2-11, 8회차 W1b)
        elif n['name'].endswith('前') and 'mae' not in e.lower() and re.search(r'\b(Shrine|Temple|Hospital|Office|University|Park|Ground|Zoo|Hall|School|Castle)\b',e):e=None
    # 라벨을 버렸으면 규칙 값이다. 출처를 wikidata로 적으면 역 이름 규칙이 라벨로 믿는다
    e_src='wikidata' if e else 'rule'
    if not e:e=en_rules.station_reading(kana,n['name']) if kana else None
    if e:add('node',n['id'],'en',''.join(c for c in unicodedata.normalize('NFD',e) if c!='\u0304'),source=e_src)
    for lab,lk_ in n.get('by_line',[]):
        # 노선 전용 이름의 읽기 (2회차 종합 K13·K14): 그 노선 원문(N05 노선 표) → 같은 노드의 같은 글자 읽기 → 가까운(5km) 같은 이름 역 → 그 이름 역 문서.
        # 이름 열쇠 읽기 표(KANA 「node:이름」)는 같은 글자에 읽기가 하나뿐일 때만 쓴다
        # 사람이 확인한 그 노드 옛 이름 읽기(old_names_kana·old_names)가 가장 먼저다
        # 표의 주석(「会津高原(旧会津滝ノ原)」)은 뒤에서 떼므로 읽기를 찾을 때도 뗀 이름으로 본다
        labk=re.sub(r'[（(](?:旧[^)）]*|臨時乗降場)[)）]$','',lab).strip() or lab
        kk=OLDKANA0.get(n['id']+'|'+labk) or (OLDNAMES0.get(n['id']+'|'+labk) or {}).get('kana')
        if not kk:kk=N5ST_LK.get((lk_,lab)) or N5ST_LK.get((lk_,labk))
        # 같은 노드의 같은 글자: 손 보정 읽기(node_fix)가 먼저, 노드 읽기는 그 읽기를 준 station_database 이름이 같은 글자일 때만 (丹後山田 노드에 与謝野 읽기)
        if not kk and znorm(lab)==znorm(n['name']):
            kk=NFIX0.get(n['id'],{}).get('kana') or (n['kana'] if n['kana'] and (not n.get('sdname') or znorm(n['sdname'])==znorm(lab)) else None)
        if not kk:
            # 옛 이름(original_name)으로 걸린 행은 지금 이름의 읽기라 쓰지 않는다 (舟子 → 大川ダム公園 おおかわだむこうえん)
            sdk=[s['name_kana'] for s in byname.get(znorm(labk),[]) if s['name_kana'] not in('','NULL') and znorm(s['name'])==znorm(labk) and n['pt'] and dist(n['pt'],(s['lat_'],s['lng_']))<5]
            kk=kata2hira(sdk[0]) if sdk else None
        # 역 문서 읽기는 그 이름이 제목인 문서만 (넘겨주기로 지금 역 문서가 오면 지금 이름 읽기다: 金津駅 → 芦原温泉駅)
        if not kk and (WS.get(labk+'駅') or {}).get('title')==labk+'駅':
            kk=next((b.get('kana') for b in (WS.get(labk+'駅') or {}).get('blocks',[]) if b.get('kana')),None)
            kk=re.sub(r'[（(].*$','',kk).strip() if kk else None
        if not kk and labk not in KANA_AMBIG:
            kk=KANA.get('node:'+labk)
            if kk and not namekey_ok('node:'+labk,znorm(labk),n['cns'],n['pt'],kk,n['id']):kk=None
        # 「바탕 이름+仮乗降場」 꼴 노선 표기는 바탕 이름 읽기(그 노드의 손 옛 이름 읽기·같은 글자 노드 읽기) + 꼬리 고정 읽기다. 두 쪽 모두 근거 있는 합성 (R 갈래 지적, 9회차 N)
        if not kk:
            _mt=re.search(r'(臨時乗降場|仮乗降場|乗降場|仮停車場)$',labk)
            if _mt and len(labk)>len(_mt.group(1)):
                _bs=labk[:-len(_mt.group(1))]
                _bk=OLDKANA0.get(n['id']+'|'+_bs) or (NFIX0.get(n['id'],{}).get('kana') or n['kana'] if znorm(_bs)==znorm(n['name']) else None)
                if _bk:kk=kata2hira(_bk).replace(' ','')+{'臨時乗降場':'りんじじょうこうじょう','仮乗降場':'かりじょうこうじょう','乗降場':'じょうこうじょう','仮停車場':'かりていしゃじょう'}[_mt.group(1)]
        if kk:kk=kata2hira(kk).replace(' ','')
        if kk and lab.endswith('駅') and not kk.endswith('えき'):kk+='えき'
        add('node',n['id'],'ja',lab,source=n['by_src'][(lab,lk_)],line=lid[lk_],kana=kk,_lab=lab)
        if lab in BYLINEKO:add('node',n['id'],'ko',BYLINEKO[lab],source='hand',line=lid[lk_],checked=TODAY,_lab=lab)
        elif kk:
            hk=kata2hira(kk);v=ko.NW.get(lab+'|'+hk)
            t_=v[0] if v else ko.station(hk,lab)
            if lab.endswith('駅') and t_.endswith('에키'):t_=t_[:-2]+'역'
            add('node',n['id'],'ko',t_,source=v[1] if v else 'rule',line=lid[lk_],checked=TODAY,_lab=lab)
        if kk:
            # 역 이름 영어 규칙(駅前 -Ekimae, 丁目 -chome, 외래어)을 노선 전용 이름에도 쓴다
            e_=en_rules.station_reading(kk,lab);e_=en_rules.fix_station(lab,kk,e_,{}) or e_
            add('node',n['id'],'en',''.join(c for c in unicodedata.normalize('NFD',e_) if c!='\u0304'),source='rule',line=lid[lk_],_lab=lab)
NLN=json.load(open(os.path.join(IMP,'namuwiki','names_lines.json'),encoding='utf-8')) if source_on('namuwiki') else {}
LINEKO={tuple(k.split('|')):v for k,v in json.load(open(os.path.join(ROOT,'data','overrides','lines_ko.json'),encoding='utf-8')).items()}
opko={k:v['short_ko'] for k,v in ops.items() if v.get('short_ko')}
for i,l in linesout.items():
    if l.get('kana'):l['kana']=re.sub('^じぇ[いえ]あーる','',l['kana'])
    add('line',i,'ja',l['name_ja'],kana=l.get('kana'),source=LSRC[i])
    t=None;src=None
    sdn=conn.clean(l['sd']) if l.get('sd') else None
    cn=ops.get(oid(l['family'][1:]),{}) if l['family']!='jr' else {}
    cko=OPKO.get(cn.get('name_ja',''),'')
    # 공영 노면전차는 사업자 이름(〇〇시 지하철) 대신 「〇〇 시영 전차」를 머리로 쓴다 (hand_tables TRAMKO)
    tko=HT['TRAMKO'].get(cn.get('name_ja')) if l['type']=='tram' else None
    if tko:cko=tko
    # 노면전차 노선 이름 앞의 사업자 약칭(京都市電·大阪市電)은 머리(tko)가 대신하므로 읽기 규칙에 넣지 않는다 (2회차 종합 K16: 교토시덴카라스마선)
    nm_,kn_=l['name_ja'],l.get('kana')
    if tko:
        for pj_,pk_ in (('京都市電','きょうとしでん'),('大阪市電','おおさかしでん'),('札幌市電','さっぽろしでん'),('函館市電','はこだてしでん'),('名古屋市電','なごやしでん'),('神戸市電','こうべしでん'),('横浜市電','よこはましでん'),('仙台市電','せんだいしでん')):
            if nm_.startswith(pj_) and len(nm_)>len(pj_):
                nm_=nm_[len(pj_):]
                if kn_ and kn_.startswith(pk_):kn_=kn_[len(pk_):]
    # 공영 지하철도 사업자 이름(〇〇시 교통국) 대신 지하철 브랜드를 머리로 쓴다 (hand_tables SUBWAYKO)
    if l['type']=='subway' and cn.get('name_ja') in HT['SUBWAYKO']:cko=HT['SUBWAYKO'][cn['name_ja']]
    same=bool(sdn) and znorm(l['name_ja'])!='' and (znorm(l['name_ja']) in znorm(sdn) or znorm(sdn) in znorm(l['name_ja'])) and l['rule_class']!='extra' and l['name_ja'] not in('本線','鋼索線','幹線')
    lk_=(cn.get('name_ja',''),l['name_ja'])
    if lk_ in LINEKO:t,src=LINEKO[lk_],'hand'
    elif same and sdn in NLN:t,src=NLN[sdn]
    elif same and sdn in conn.LABEL:t,src=conn.LABEL[sdn],'hand'
    elif l['name_ja'] in NLN and l['family']=='jr':t,src=NLN[l['name_ja']]
    elif l['name_ja']=='鋼索線':t,src=(cko+' 강삭선').strip(),'rule'
    elif l['name_ja']=='本線':t,src=(cko+' 본선').strip(),'rule'
    elif kn_ and same:t=ko.line(kn_,nm_);src='rule'
    elif KANA.get('line:'+l['name_ja']):
        t=ko.line(KANA['line:'+l['name_ja']],l['name_ja']);t=(cko+' '+t).strip() if cko and not t.startswith(cko) else t;src='rule'
    elif kn_ and l['name_ja'] in N5NAMES:
        # N05 노선은 읽기를 노선 읽기 표(lines_kana.json)나 위키 문서 첫 줄에서 받는다
        t=ko.line(kn_,nm_);t=(cko+' '+t).strip() if cko and not t.startswith(cko) else t;src='rule'
    # 나무위키·손 표에서 온 이름도 같은 머리로 맞춘다 (구마모토시 전차 간선 → 구마모토 시영 전차 간선, 삿포로 시전 → 삿포로 시영 전차)
    if tko and l['name_ja'].endswith('市電'):t,src=tko,'rule'
    elif t and tko:t=(tko+' '+re.sub(r'^(?:\S+시 ?(?:전차|교통국|지하철)|\S+ ?시전|\S+ 시영 (?:지하철|전차)|도에이|도덴)\s*','',t)).strip()
    if t:add('line',i,'ko',t,source=src,checked=TODAY)
    else:pend.append(('line',i,l['name_ja']))
for a,b in OPHIST_ID.items():
    ops[b]=dict(id=b,name_ja=a,category='general_private',short_ko=OPHIST_KO[a])
for i,o in ops.items():
    add('operator',i,'ja',o['name_ja'],source=OPSRC.get(i,'hand'))
    k=o.get('short_ko') or OPKO.get(o['name_ja'])
    kk=KANA.get('op:'+o['name_ja'])
    if not k and kk:
        m=re.match(r'^(.*?)(でんきてつどう|てつどう|でんてつ|こうつう|でんしゃ|きどう)?$',kk)
        tail={'でんきてつどう':' 전기철도','てつどう':' 철도','でんてつ':' 전철','こうつう':' 교통','でんしゃ':' 전차','きどう':' 궤도'}.get(m.group(2),'')
        k=ko.station(m.group(1),re.sub(r'(電気鉄道|鉄道|鐵道|電鉄|交通|電車|軌道)$','',o['name_ja']))+tail
    if k:add('operator',i,'ko',k,source='hand')
    else:pend.append(('operator',i,o['name_ja']))
# 역명 변경 이력. 옛 이름은 기간이 있는 행과 검색 별칭으로 둔다
_r=os.path.join(CAND,'renames.json')
RN=json.load(open(_r,encoding='utf-8')) if os.path.exists(_r) else {}
RNH=json.load(open(os.path.join(ROOT,'data','overrides','renames_hand.json'),encoding='utf-8'))
# N05 연도 기록의 개칭 (tools/n05_history.py, 재설계 2단계). 위키 개칭이 없는 것만 쓰고 날짜는 연도 범위
_rn5=os.path.join(ROOT,'data','overrides','renames_n05.json')
RN05={k:[r[:3] for r in v] for k,v in json.load(open(_rn5,encoding='utf-8')).items()} if os.path.exists(_rn5) else {}
OLDFIX=json.load(open(os.path.join(ROOT,'data','overrides','old_names_fix.json'),encoding='utf-8'))
OLDNAMES=json.load(open(os.path.join(ROOT,'data','overrides','old_names.json'),encoding='utf-8'))
# 일본어 위키에 적힌 옛 역 이름의 읽기 (tools/old_name_kana.py). 한국어·영어 옛 이름을 이 읽기로 만든다
_ok=os.path.join(ROOT,'data','overrides','old_names_kana.json')
OLDKANA={k:v['kana'] for k,v in json.load(open(_ok,encoding='utf-8')).items() if v.get('kana')} if os.path.exists(_ok) else {}
old_alias=[]
def doc_about(n,t):
    """제목이 같은 이름이고 그 역의 노선이 적힌 문서만 그 역의 문서로 본다. 동명 역 문서의 연혁이 섞이면 안 된다"""
    e=WS.get(t)
    if not e or e.get('missing'):return False
    b0=xn(re.sub(r'\s*[（(].*$','',t));b1=xn(n['name'])
    if b0 not in (b1,b1+'駅',b1+'停留場'):return False
    ls=[re.sub('(本線|線)$','',l) for l in node_lines[n['id']]]
    return any(l and len(l)>=2 and l in (b.get('lines') or '') for b in e.get('blocks',[]) for l in ls)
# 노선 문서 年表의 개칭 쌍 (tools/gen_renames.py, 2회차 종합 K11). 캐시 파일 이름은 문서 제목의 md5 앞 14자리
import hashlib
_rl=os.path.join(CAND,'renames_lines.json')
RNL=json.load(open(_rl,encoding='utf-8')) if os.path.exists(_rl) else {}
def _stem(t):return hashlib.md5(t.encode()).hexdigest()[:14]
LDOC_RN={}
for i,l in linesout.items():
    co_=ops.get(oid(l['family'][1:]),{}).get('name_ja','') if l['family']!='jr' else ''
    for t in [re.sub(r'^JR','',re.sub(r'[（(].*?[)）]','',l['sd']).strip()) if l.get('sd') else None,l['name_ja'],COSHORT.get(co_,'')+l['name_ja'] if co_ else None,co_+l['name_ja'] if co_ else None]:
        if t and _stem(t) in RNL:LDOC_RN[i]=RNL[_stem(t)]['rows'];break
node_lids=collections.defaultdict(set)
for lk,ps,ch in line_rel:
    for c0 in ch:
        for c in [c0]+list(c0.alts):
            for s_,_ in c.seq:
                if not getattr(s_,'ghost',False):node_lids[nid(s_)].add(lid[lk])
def _lo(d):return lohi(d)[0] if d else None
def _prec(d):
    """날짜의 정밀도: 하루 0, 달 1, 해·범위 2, 없음 3"""
    if not d:return 3
    if d.startswith('['):return 2
    return 0 if 'X' not in d else (1 if not d.endswith('XX-XX') else 2)
def _near(a,b):
    """두 개칭 날짜가 같은 개칭으로 볼 만큼 가까운가 (N05 연 범위는 앞뒤 한 해 여유)"""
    if not a or not b:return False
    la,ha=lohi(a);lb,hb=lohi(b)
    return la[:4]<=str(int(hb[:4])+1) and lb[:4]<=str(int(ha[:4])+1)
def rn_chain(cur,ev):
    """노선 문서 개칭 쌍에서 지금 이름부터 거슬러 이어지는 것만 고른다 (gen_renames.chain과 같은 규칙)"""
    opn=[(znorm(cur),'9999')];rows=[]
    for d,a,b in sorted(ev,key=lambda x:x[0].replace('X','0'),reverse=True):
        k=next((i for i,(nm,end) in enumerate(opn) if nm==znorm(b) and d.replace('X','0')<end),None)
        if k is None:continue
        opn.pop(k);rows.append([a,None,d]);opn.append((znorm(a),d.replace('X','0')))
    rows.sort(key=lambda r:r[2].replace('X','0'))
    for i in range(1,len(rows)):rows[i][1]=rows[i-1][2]
    return rows
SRC_RANK={'hand':0,'wiki':1,'n05':2};HAND_ROWS=set()
# 모든 노선에서 폐역인 노드의 마지막 정차 폐지일. 그 뒤 날짜의 위키·N05 개칭은 같은 이름을 이어받은 다른 역 것이다 (2회차 종합 K12)
_allc=collections.defaultdict(lambda:True)
for p in parts:
    for o in p.st:
        if not getattr(o,'ghost',False):_allc[nid(o)]&=bool(o.closed)
_ncl={}
for fa_,e_ in EV:
    if e_.get('type')=='close_stop' and e_.get('date') and _allc[e_['node']]:_ncl[e_['node']]=max(_ncl.get(e_['node'],'0'),lohi(e_['date'])[1])
# 노선이 통째로 닫혀 역 표지(*)가 없는 역(南越線 福武口, 名古屋市電 名古屋城)도 폐역이다: 그 역이 서는 모든 부품이 닫혔으면(또는 역이 먼저 닫혔으면) 가장 늦은 부품 폐지일
_pcl=collections.defaultdict(list);_popen=set()
for lk,ps,ch in line_rel:
    for q in ps:
        try:
            qe=max((lohi(edtf(r[2]))[1] for r in q.close if len(r)>2 and edtf(r[2])),default=None) if sum(float(r[1]) for r in q.close)>=q.km-.05 else None
        except (TypeError,ValueError):qe=None
        for o in q.st:
            if getattr(o,'ghost',False) or o.closed:continue
            if qe:_pcl[nid(o)].append(qe)
            else:_popen.add(nid(o))
for x_,v_ in _pcl.items():
    if x_ not in _popen:_ncl[x_]=max([_ncl.get(x_,'0')]+v_)
# 노드가 처음 선 날(정차 개업 사건). 해 범위로 끝나는 옛 이름은 그 뒤에 끝났다 (아래, 2회차 종합 K12)
_nopen={}
for fa_,e_ in EV:
    if e_.get('type')=='open_stop' and e_.get('date'):
        try:_nopen[e_['node']]=min(_nopen.get(e_['node'],'9999'),lohi(e_['date'])[0])
        except (TypeError,ValueError):pass
# 정차 개업 사건이 없는 노드는 station_database 개업일
for x_,n_ in nodes.items():
    if x_ not in _nopen and n_.get('sd_open') and not n_['sd_open'].startswith('XXXX'):
        try:_nopen[x_]=lohi(n_['sd_open'])[0]
        except (TypeError,ValueError):pass
# 仮乗降場·臨時駅 표식이 끝난 날(역 승격일). 같은 때 끝나는 N05 옛 이름의 연 범위를 이 날로 맞춘다
_SSE=collections.defaultdict(list)
for st_ in json.load(open(os.path.join(ROOT,'data','overrides','stop_status.json'),encoding='utf-8')):
    if st_.get('to') and re.match(r'^\d{4}-\d\d-\d\d$',st_['to']):_SSE[st_['node']].append(st_['to'])
# 컴파일이 사건 보정(events_fix.json)의 이관으로 만드는 노선(弘南 黒石線)도 노선 칸에 쓸 수 있다
EF_LINES=set(re.findall(r'"line": "(l_[a-z0-9_]+)"',open(os.path.join(ROOT,'data','overrides','events_fix.json'),encoding='utf-8').read()))
rn_stat=collections.Counter()
def _par(t):
    """이름의 괄호 부기 글자(（旧）는 뺌)"""
    return ''.join(x for x in re.findall(r'[（(]([^）)]*)[）)]',unicodedata.normalize('NFKC',t or '')) if not x.startswith('旧'))
for n in nodes.values():
    if n['kind']!='station':continue
    n0=n['name'];pages=[n0 if n0.endswith('駅') else n0+'駅',n0+'停留場']
    for t in list(pages):pages+=(WS.get(t) or {}).get('alt') or []
    # 지금 이름은 손으로 고친 표기(JAFIX)다. 원래 이름(寺泊新道)이 옛 이름이면 기간 행으로 남는다
    seen_=set();base=znorm(JAFIX.get(n['id'],n0));bpar=_par(JAFIX.get(n['id'],n0))
    # 후보: 역 문서 연혁(wiki), 그 역이 서는 노선 문서 年表(wiki), 손 개칭(hand), N05 연 범위(n05)
    cand=[('wiki',r) for t in pages if doc_about(n,t) for r in RN.get((WS[t] or {}).get('title') or t,[])]
    lev=[tuple(x) for l_ in sorted(node_lids[n['id']]) for x in LDOC_RN.get(l_,[])]
    if lev:cand+=[('wiki',r) for r in rn_chain(JAFIX.get(n['id'],n0),lev)]
    cand+=[('hand',r) for r in RNH.get(n['id'],[])]+[('n05',r) for r in RN05.get(n['id'],[])]
    rows=[];undated=[]
    for t,row_ in cand:
        # 손 개칭의 4번째 원소는 노선이다. 공용 노드의 한 노선에서만 쓴 기간 이름(西銀座·信濃橋)은 그 노선 행으로만 둔다 (2회차 종합 U14)
        old,f,to=row_[:3];rl_=row_[3] if len(row_)>3 else None
        if rl_ and rl_ not in linesout and rl_ not in EF_LINES:
            if ONLY is None:raise SystemExit(f"renames_hand.json 행의 노선이 없습니다: {n['id']} {rl_}")
            continue
        # 옛 이름을 못 읽은 위키 개칭은 날짜만 쓴다 (N05 연 범위 행의 끝을 정확한 날로)
        if not to:continue
        if old is None:undated.append(to);continue
        old=re.sub(r'^駅[がをはも]','',old)
        k_=n['id']+'|'+old if n['id']+'|'+old in OLDFIX else old       # 옛 이름 404행을 사람이 읽고 고친 값
        if k_ in OLDFIX:
            v_=OLDFIX[k_]
            if v_ is None:continue
            old,f,to=[v_,f,to] if isinstance(v_,str) else v_
            # 사람이 이름·기간을 다 적은 보정 행은 손 개칭과 같이 다룬다 (합칠 때 우선, 1950년 전 행도 이름 행으로)
            if not isinstance(v_,str):t='hand'
        # 같은 글자인데 읽기만 다른 옛 이름(苅田 かりた→かんだ, 2회차 종합 U13)은 읽기가 적혀 있을 때만 남긴다
        sk_=OLDNAMES.get(n['id']+'|'+old,{}).get('kana') or OLDKANA.get(n['id']+'|'+old)
        # 괄호 부기만 다른 이름(西鉄福岡 → 西鉄福岡（天神） 2001, 神田 → 神田（交通局前）)은 다른 이름이다. 대조 정규화(znorm)는 괄호를 떼므로 괄호 글자를 따로 본다
        # 사람이 적은 손 개칭은 글자꼴만 다른 공식 표기 변경(伊太祁曽 → 伊太祈曽 2006)이라 지금 표기와 글자가 다르면 남긴다
        if t=='hand' and old!=(NFIX0.get(n['id'],{}).get('ja') or JAFIX.get(n['id'],n0)) and znorm(old)==base:pass
        elif znorm(old)==base and _par(old)==bpar and not (sk_ and n.get('kana') and kata2hira(sk_)!=kata2hira(n['kana'])):continue
        if (n0,old) in {('ケーブル山上','中間'),('トロッコ嵯峨','嵯峨')}:continue
        if t!='hand' and n['id'] in _ncl and lohi(to)[0]>_ncl[n['id']]:rn_stat['after_close']+=1;continue
        rows.append(dict(old=old,f=f,to=to,line=rl_,src=t))
    # 손 개칭이 노선을 적은 옛 이름(공용 노드의 한 노선에서만 쓴 기간 이름)은 같은 옛 이름·같은 끝 날짜의 노선 없는 위키·N05 행도 그 노선 행이다.
    # 그래야 아래에서 손 행과 하나로 합쳐져 다른 노선 화면에 번지지 않는다 (千鳥橋 新博多·西鉄博多는 1954-03-05 전 宮地岳線 역 이름, 7회차 2026-11-14)
    _hl={(znorm(r['old']),r['to']):r['line'] for r in rows if r['src']=='hand' and r['line']}
    for r in rows:
        if r['src']=='hand' or r['line']:continue
        l_=_hl.get((znorm(r['old']),r['to'])) or next((v_ for (o_,t_),v_ in _hl.items() if o_==znorm(r['old']) and _near(t_,r['to'])),None)
        if l_:r['line']=l_
    # 같은 옛 이름의 같은 개칭은 하나로: 정밀한 날짜가 먼저(위키 정확일 > 손 범위 > N05 연 범위), 같은 정밀도면 손 > 위키 > N05.
    # N05 개칭은 위키·손에 같은 옛 이름이 있으면 쓰지 않는다
    named_={(znorm(r['old']),r['line']) for r in rows if r['src']!='n05'}
    rows=[r for r in rows if r['src']!='n05' or (znorm(r['old']),r['line']) not in named_]
    rows.sort(key=lambda r:(_prec(r['to']),SRC_RANK[r['src']]))
    keep=[]
    for r in rows:
        twin=next((k for k in keep if znorm(k['old'])==znorm(r['old']) and k['line']==r['line'] and (k['to']==r['to'] or _near(k['to'],r['to']))),None)
        if twin is None:keep.append(r);continue
        if not twin['f'] or _prec(r['f'])<_prec(twin['f']) and twin['src']!='hand':twin['f']=r['f']
        rn_stat['merged']+=1
    # N05 연 범위 끝을 같은 때의 위키 개칭 날짜로 (옛 이름을 못 읽은 위키 행), 仮乗降場·臨時駅이 역이 된 날로
    for d_ in undated+_SSE.get(n['id'],[]):
        hit=[k for k in keep if not k['line'] and _prec(k['to'])>_prec(d_) and lohi(k['to'])[0]<=lohi(d_)[0]<=lohi(k['to'])[1]]
        if len(hit)==1:hit[0]['to']=d_;rn_stat['exact_from_undated']+=1
    # 끝이 해 범위인 옛 이름은 그 노드가 처음 선 뒤에 끝났다. 범위의 앞이 첫 정차 날 이전이면 그 다음 날로 당긴다(千国崎 [1961..1962], 정차 1961-12-23~).
    # 범위가 비면 그 노드가 서기 전에 끝난 이름이라 버린다 (2회차 종합 K12: 옛 이름 기간이 어떤 정차 기간과도 안 겹침)
    f0_=_nopen.get(n['id'])
    if f0_ and f0_>'0000-01-01':
        d1_=(datetime.date.fromisoformat(f0_)+datetime.timedelta(days=1)).isoformat()
        for k in keep:
            if k['to'].startswith('[') and lohi(k['to'])[0]<=f0_:
                k['to']=f"[{d1_}..{lohi(k['to'])[1]}]" if d1_<=lohi(k['to'])[1] else None
                rn_stat['range_after_open']+=1
        keep=[k for k in keep if k['to']]
    # 같은 노드·같은 노선 칸의 옛 이름 기간이 겹치지 않게: 끝 날짜 순으로 앞 이름의 끝을 다음 이름의 시작으로 잇는다. 길이가 0이 되면 버린다
    out_=[]
    # 1950년 전에 끝난 위키 옛 이름은 검색 별칭만 되므로(아래) 기간 잇기에서 뺀다
    out_=[k for k in keep if k['src']=='wiki' and lohi(k['to'])[1]<'1950-01-01']
    keep=[k for k in keep if k not in out_]
    for ln_ in {k['line'] for k in keep}:
        g_=sorted([k for k in keep if k['line']==ln_],key=lambda k:(lohi(k['to'])[0],lohi(k['to'])[1]))
        prev=None
        for k in g_:
            # 첫 옛 이름이 1950년 전에 시작하면 처음부터의 이름으로 본다. 그 앞에 지금 이름이 끼면 같은 이름의 다른 역과 겹친다 (三次: 備後十日市 1933~)
            if prev is None and k['f'] and k['src']!='hand' and lohi(k['f'])[1]<'1950-01-01':k['f']=None
            if prev is not None and (not k['f'] or lohi(k['f'])[0]<lohi(prev['to'])[0]):k['f']=prev['to']
            if k['f'] and (k['f']==k['to'] or lohi(k['f'])[0]>lohi(k['to'])[1]):rn_stat['empty']+=1;continue
            out_.append(k);prev=k
    for k in sorted(out_,key=lambda k:(k['line'] or '',lohi(k['to'])[0])):
            old,f,to,rl_,t=k['old'],k['f'],k['to'],k['line'],k['src']
            if (old,to,rl_) in seen_:continue
            seen_.add((old,to,rl_));rn_stat[t]+=1
            if t=='hand':HAND_ROWS.add((n['id'],f,to))
            # 1950년 전에 끝난 위키 옛 이름은 기록 화면에 안 나오므로 검색 별칭으로만 둔다 (n05_history의 pre1950과 같은 규칙).
            # 열람 전용 역과는 이름이 아니라 자리·기간으로 맞춘다 (gen_extra _known)
            if t=='wiki' and lohi(to)[1]<'1950-01-01':
                old_alias.append(dict(entity_type='node',id=n['id'],lang='ja',text=old,kind='old_title'));rn_stat['pre1950_alias']+=1;continue
            # 사람이 확인한 옛 이름의 읽기·한국어·영어 (data/overrides/old_names.json, 재평가 ST4-12). 한국어·영어 화면도 그 시절 이름을 보인다
            on_=OLDNAMES.get(n['id']+'|'+old)
            ok_=OLDKANA.get(n['id']+'|'+old)
            add('node',n['id'],'ja',old,source='n05' if t=='n05' else 'wikipedia',line=rl_,valid_from=f,valid_to=to,kana=on_['kana'] if on_ else ok_)
            old_alias.append(dict(entity_type='node',id=n['id'],lang='ja',text=old,kind='old_title'))
            if on_:
                add('node',n['id'],'ko',on_['ko'],source='hand',line=rl_,valid_from=f,valid_to=to,checked=TODAY)
                add('node',n['id'],'en',on_['en'],source='hand',line=rl_,valid_from=f,valid_to=to)
                continue
            # 옛 이름의 읽기는 그 역 가까이(5km)의 같은 이름 역에서만 가져온다. 먼 동명 역(高山→たかやま)은 다른 역이다 (감사 A2-04).
            # kana 표는 옛 이름에서 지금 역 문서로 넘어간 읽기를 주므로 쓰지 않는다 (上原→うえはら, 재평가 ST4-12)
            # 괄호 부기가 다른 이름(西鉄福岡과 西鉄福岡（天神）)의 읽기는 다른 이름의 읽기다
            sdk=[s['name_kana'] for s in byname.get(znorm(old),[]) if s['name_kana'] not in('','NULL') and znorm(s['name'])==znorm(old) and _par(s['name'])==_par(old) and n['pt'] and dist(n['pt'],(s['lat_'],s['lng_']))<5]
            # 가타카나가 없는 이름에 장음 부호가 든 읽기는 부역명까지 읽은 다른 표기다 (成田空港 → なりたくうこうなりただいいちたーみなる)
            if not re.search('[ァ-ヺー]',old):sdk=[k for k in sdk if 'ー' not in k]
            # 위키에 적힌 그 역의 옛 이름 읽기가 가까운 같은 이름 역의 읽기보다 먼저다
            kk=ok_ or (kata2hira(sdk[0]) if sdk else None)
            if kk:
                add('node',n['id'],'ko',ko.station(kk,old),source='rule',line=rl_,valid_from=f,valid_to=to,checked=TODAY)
                # 역 이름 영어 규칙(駅前 -Ekimae, 외래어)을 옛 이름에도 (博多駅前 Hakata-Ekimae). 일본어 행에 읽기가 없으면 en_rules.fix_nodes가 못 고친다
                e_=en_rules.station_reading(kk,old);e_=en_rules.fix_station(old,kk,e_,{}) or e_
                add('node',n['id'],'en',e_,source='rule',line=rl_,valid_from=f,valid_to=to)
print('옛 이름 행',dict(rn_stat),'노선 문서 年表',len(LDOC_RN))
# 노선 전용 이름(노리츠부시 표의 그 노선 표기)이 그 노드의 이름 이력(지금 이름이나 기간 있는 옛 이름)에 같은 글자로 있으면 겹친 행이라 지운다 (2회차 종합 K14).
# 노선 고유 행은 기본 행보다 앞서서(DESIGN §14.2) 기간 없이 남기면 그 노선 화면에서 노드의 다른 옛 이름을 가린다(宮津線 丹後山田가 野田川을, 八百津線 明智가 伏見口를).
# 옛 이름 기간을 옮겨 붙여도 기본 행과 같은 이름이다. 노선 행에만 있던 읽기·한국어·영어는 같은 글자 기본 행으로 옮긴다.
# 같은 글자인데 읽기가 다르면(같은 글자 다른 읽기, U13) 노선 행을 남기고 같은 글자 옛 이름이 있으면 그 기간을 받는다.
# 이력에 없는 글자(다른 사업자가 쓴 이름)는 기간 없이 둔다(그 노선 영업 기간 내내 그 이름).
# 같은 글자 옛 이름 기간이 그 노선 영업 기간 전체를 덮으면(長野原線 1945~1971, 長野原 이름 ~1991) 날짜를 모르는 화면에서도 그 노선에는 그 이름이 보여야 해서 기간 없이 남긴다 (appsim M4)
_lend={};_lbeg={}
for lk,ps,ch in line_rel:
    try:
        _lbeg[lid[lk]]=min((lohi(edtf(r[2]))[0] for q in ps for r in q.open if len(r)>2 and edtf(r[2])),default=None)
        if all(sum(float(r[1]) for r in q.close)>=q.km-.05 for q in ps):
            _lend[lid[lk]]=max((lohi(edtf(r[2]))[1] for q in ps for r in q.close if len(r)>2 and edtf(r[2])),default=None)
    except (TypeError,ValueError):pass
def _covers(g,l):
    return bool(g.get('valid_to') and _lend.get(l) and _lend[l]<=lohi(g['valid_to'])[0] and (not g.get('valid_from') or (_lbeg.get(l) and lohi(g['valid_from'])[1]<=_lbeg[l])))
_gen=collections.defaultdict(list)
for x in names:
    if x['entity_type']=='node' and not x.get('line') and x.get('_lab') is None:_gen[(x['id'],x['lang'])].append(x)
def _kn(k):return kata2hira(k).replace(' ','') if k else None
# 같은 글자인지는 표기 그대로 본다. 표의 주석(반각 괄호 동명 구분 「明智(岐阜)」, 「会津高原(旧会津滝ノ原)」)만 떼고, 전각 부역명(蓮町（馬場記念公園前）)과
# 이체자만 다른 노선 표기(留萠·小淵)는 그 노선 시절의 공식 표기라 다른 글자로 본다
def _nt(t):
    t=re.sub(r'\([^()（）]*\)$','',t or '');t=re.sub(r'[（(](?:旧[^)）]*|臨時乗降場|臨|仮)[)）]','',t)
    return re.sub(r'\s+','',unicodedata.normalize('NFKC',t))
_red=set();_bl=collections.Counter()
for x in names:
    if x.get('_lab') is None or x['lang']!='ja' or x.get('valid_from') or x.get('valid_to'):continue
    hit=[g for g in _gen[(x['id'],'ja')] if _nt(g['text'])==_nt(x['_lab'])]
    if not hit:continue
    if x.get('kana') and any(g.get('kana') and _kn(g['kana'])!=_kn(x['kana']) for g in hit):
        pv_=next((g for g in hit if g.get('valid_to')),None)
        if pv_:x.update({k:v for k,v in (('valid_from',pv_.get('valid_from')),('valid_to',pv_['valid_to'])) if v});x['_period']=True;_bl['dated']+=1
        continue
    if any(_covers(g,x['line']) for g in hit):_bl['covering_kept']+=1;continue
    _red.add((x['id'],x['line'],x['_lab']))
    for g in hit:
        if not g.get('kana') and x.get('kana'):
            g['kana']=x['kana'];_bl['kana_moved']+=1
            if x.get('reading_source'):g['reading_source']=x['reading_source']
_per={(y['id'],y.get('line'),y['_lab']):y for y in names if y.get('_period')}
for x in names:
    k_=(x['id'],x.get('line'),x.get('_lab'))
    if x.get('_lab') is None or x['lang']=='ja':continue
    if k_ not in _red:
        # 기간을 받은 일본어 행과 같은 기간을 한국어·영어 행에도
        j_=_per.get(k_)
        if j_:x.update({k:j_[k] for k in ('valid_from','valid_to') if j_.get(k)})
        continue
    for g in [g for g in _gen[(x['id'],'ja')] if _nt(g['text'])==_nt(x['_lab'])]:
        if not any(h.get('valid_from')==g.get('valid_from') and h.get('valid_to')==g.get('valid_to') for h in _gen[(x['id'],x['lang'])]):
            add('node',x['id'],x['lang'],x['text'],source=x.get('source'),valid_from=g.get('valid_from'),valid_to=g.get('valid_to'),checked=x.get('checked'));_bl[x['lang']+'_moved']+=1
            _gen[(x['id'],x['lang'])].append(names[-1])
_bl['dropped']=sum(1 for x in names if x.get('_lab') is not None and x['lang']=='ja' and (x['id'],x.get('line'),x['_lab']) in _red)
names[:]=[x for x in names if not (x.get('_lab') is not None and (x['id'],x.get('line'),x['_lab']) in _red)]
for x in names:x.pop('_lab',None);x.pop('_period',None)
print('노선 전용 이름 정리(겹친 행 지움·읽기 옮김)',dict(_bl))
# 역 이전의 옛 자리(moved.json old)는 옮기기 전의 같은 역이다. 위키 역 문서·N05는 지금 역을 기준으로 적어 이전일 전의 옛 이름이 새 자리 노드에 붙는다.
# 이전일 전에 끝난 옛 이름은 옛 자리 노드로 옮기고, 이전일에 걸친 이름은 이전일에서 가른다(같은 글자 이름이 이미 옛 자리에 있으면 그대로)
# (2회차 종합 K11: 近鉄八尾（旧）의 大軌八尾·関急八尾, 川原湯温泉（旧）의 川原湯, 貝塚（旧）의 西鉄多々良, 竹田（旧）의 奈良電竹田)
_mvs=collections.Counter();_byn=collections.defaultdict(list)
for x in names:
    if x['entity_type']=='node' and not x.get('line') and x.get('valid_to'):_byn[x['id']].append(x)
_MV=json.load(open(os.path.join(ROOT,'data','overrides','moved.json'),encoding='utf-8'))
# 옛 자리 여럿을 한 역으로 합친 이전(京浜逗子·逗子海岸 → 新逗子)은 옛 이름이 어느 자리 것인지 몰라 옮기지 않는다
_nold=collections.Counter(mv['new'] for mv in _MV)
for mv in _MV:
    o_,w_=mv['old'],mv['new']
    if o_ not in nodes or w_ not in nodes or _nold[w_]>1:continue
    D_=lohi(mv['date'])[0]
    have_={(znorm(y['text']),y['lang']) for y in _byn[o_]}
    for x in list(_byn[w_]):
        if (znorm(x['text']),x['lang']) in have_:continue
        lt_,ht_=lohi(x['valid_to']);fl_=lohi(x['valid_from'])[0] if x.get('valid_from') else '0000-01-01'
        if ht_<=D_:x['id']=o_;_byn[o_].append(x);_mvs['moved']+=1
        elif fl_<D_<lt_:
            y_=dict(x,id=o_,valid_to=mv['date']);names.append(y_);_byn[o_].append(y_);x['valid_from']=mv['date'];_mvs['split']+=1
print('이전 옛 자리로 옮긴 옛 이름',dict(_mvs))
# 한 계통에서 두 노드가 같은 때 같은 이름이면 그중 하나는 다른 역 이름이 붙은 것이다 (2회차 종합 K12: 新島々의 「島々」, 竹鼻線 栄町, 札幌 交通局前).
# 지금 이름은 버리지 않고, 옛 이름은 손 > 위키 > N05 순으로 남긴다. 같은 출처면 늦게 시작한 쪽을 버린다. 이전 쌍(moved)은 （旧）로 이름이 갈려 해당 없다
_SR={'hand':0,'wikipedia':1,'n05':2}
_iv=collections.defaultdict(list)
for x in names:
    if x['entity_type']!='node' or x['lang']!='ja' or x.get('line'):continue
    if x.get('valid_to'):_iv[x['id']].append((znorm(x['text']),lohi(x['valid_from'])[0] if x.get('valid_from') else '0000-01-01',lohi(x['valid_to'])[0],x))
for i_,v_ in list(_iv.items()):
    cur_=[x for x in names if x['entity_type']=='node' and x['id']==i_ and x['lang']=='ja' and not x.get('line') and not x.get('valid_to')]
    st_=max((t for _,_,t,_ in v_),default='0000-01-01')
    for x in cur_:v_.append((znorm(x['text']),st_,'9999-12-31',None))
# 옛 이름이 없는 노드의 지금 이름은 그 역 개업(station_database)부터다 (御嵩口의 옛 「御嵩」 ~1952와 새 御嵩 1952~는 겹치지 않음)
for x in names:
    if x['entity_type']=='node' and x['lang']=='ja' and not x.get('line') and not x.get('valid_to') and x['id'] not in _iv:
        so_=(nodes.get(x['id']) or {}).get('sd_open')
        _iv[x['id']].append((znorm(x['text']),(lohi(so_)[0] if so_ and not so_.startswith('XXXX') else None) or '0000-01-01','9999-12-31',None))
_rn2=collections.defaultdict(set)
for lk,ps,ch in line_rel:
    for c0 in ch:
        for c in [c0]+list(c0.alts):
            for x_ in getattr(c,'ns',[]):_rn2[c.rid].add(x_)
_drop=set();_conf_wiki=set()
for r_,ns_ in _rn2.items():
    ns_=sorted(ns_)
    for ia,a_ in enumerate(ns_):
        for b_ in ns_[ia+1:]:
            for ta,fa,ua,xa in _iv.get(a_,()):
                for tb,fb,ub,xb in _iv.get(b_,()):
                    if ta!=tb or not(fa<ub and fb<ua) or (xa is None and xb is None):continue
                    if xa is None:loser=xb
                    elif xb is None:loser=xa
                    else:
                        ka=(_SR.get(xa.get('source'),1),fa);kb=(_SR.get(xb.get('source'),1),fb)
                        loser=xa if ka>kb else xb
                    # 버리는 것은 N05 대응 옛 이름만이다(이름+거리 대응의 오류, K12). 위키·손 행끼리 겹치면 목록으로 남긴다
                    if loser.get('source')!='n05' or (loser['id'],loser.get('valid_from'),loser['valid_to']) in HAND_ROWS:
                        if loser.get('source')!='n05':_conf_wiki.add((r_,loser['id'],loser['text'],loser['valid_to']))
                        continue
                    _drop.add((loser['id'],loser.get('valid_from'),loser['valid_to']))
names[:]=[x for x in names if not (x['entity_type']=='node' and not x.get('line') and (x['id'],x.get('valid_from'),x.get('valid_to')) in _drop)]
print('같은 계통 다른 노드와 겹친 옛 이름 버림(N05)',len(_drop),sorted(_drop,key=str)[:40])
print('같은 계통 다른 노드와 겹친 위키 옛 이름(확인 목록)',len(_conf_wiki),sorted(_conf_wiki,key=str)[:40])
aliases=[dict(entity_type='node',id=k_,lang='ja',text=nodes[k_]['name'],kind='noritsubushi') for k_ in JAFIX]
aliases+=old_alias
for i_,v_ in {'l_rias_line':['北リアス線','南リアス線']}.items():
    for t_ in v_:aliases.append(dict(entity_type='line',id=i_,lang='ja',text=t_,kind='old_title'))
# 감사에서 고친 값 (data/overrides/node_fix.json, line_fix.json)
NFIX=json.load(open(os.path.join(ROOT,'data','overrides','node_fix.json'),encoding='utf-8'))
LFIX=json.load(open(os.path.join(ROOT,'data','overrides','line_fix.json'),encoding='utf-8'))
for x in names:
    if x.get('line') or x.get('valid_to'):continue
    f=NFIX.get(x['id']) if x['entity_type']=='node' else None
    if f:
        if x['lang']=='ja':
            if f.get('kana'):x['kana']=f['kana'];x['reading_source']='hand:node_fix'
            if f.get('ja'):
                aliases.append(dict(entity_type='node',id=x['id'],lang='ja',text=x['text'],kind='noritsubushi'));x['text']=f['ja'];x['source']='hand'
        elif f.get(x['lang']):x['text']=f[x['lang']];x['source']='hand'
    if x['entity_type'] in('line','operator') and x['lang']=='ko' and x['id'] in LFIX:x['text']=LFIX[x['id']];x['source']='hand'
# node_fix의 "kana": null은 틀린 읽기를 지우라는 뜻이다(다른 이름의 읽기를 가져온 것, 맞는 읽기 근거는 없음).
# 그 읽기로 만든 한국어·영어 기본 행도 지워 compile이 일본어 표기 그대로(ja_as_is)로 채운다 (명세 결정 6)
_nokana={i for i,f in NFIX.items() if 'kana' in f and f['kana'] is None}
for x in names:
    if x['entity_type']=='node' and x['id'] in _nokana and x['lang']=='ja' and not x.get('line') and not x.get('valid_to'):x.pop('kana',None)
names[:]=[x for x in names if not (x['entity_type']=='node' and x['id'] in _nokana and x['lang'] in ('ko','en') and not x.get('line') and not x.get('valid_from') and not x.get('valid_to'))]
# 안내용 副駅名称(〈 〉, 東京メトロ 明治神宮前〈原宿〉·二重橋前〈丸の内〉, 東武 獨協大学前〈草加松原〉)은 정식 역명이 아니다. 역 이름은 정식 역명(노리츠부시 표기)이고
# 〈 〉 꼴은 검색 별칭으로 둔다. 노리츠부시 표에 있는 전각 괄호 부기(蓮町（馬場記念公園前）·西鉄福岡（天神）)는 정식 표기라 그대로다 (3회차 kanto_1-015, 9회차 N)
_SUBN=re.compile(r'〈[^〉]*〉')
for x in names:
    if x['entity_type']=='node' and _SUBN.search(x['text'] or ''):
        if x['lang']=='ja':aliases.append(dict(entity_type='node',id=x['id'],lang='ja',text=x['text'],kind='alias'))
        x['text']=_SUBN.sub('',x['text']).strip()
# node_fix의 aliases는 검색 별칭이다: 공식 이름과 다른 통칭(虹の駅), 같은 営業キロ의 다른 역명(八木西口) (2회차 종합 U07·U19)
for i,f in NFIX.items():
    for a_ in f.get('aliases') or []:
        if i in nodes:aliases.append(dict(entity_type='node',id=i,lang='ja',text=a_,kind='alias'))
# 나무위키·위키데이터에 짝이 없는 역(狩留賀浜 옛 仮乗降場)은 node_fix의 한국어·영어 이름을 새로 단다
_has={(x['id'],x['lang']) for x in names if x['entity_type']=='node' and not x.get('line') and not x.get('valid_to')}
for i,f in NFIX.items():
    for lg in ('ko','en'):
        if f.get(lg) and (i,'ja') in _has and (i,lg) not in _has:names.append(dict(entity_type='node',id=i,lang=lg,text=f[lg],source='hand'))
# station_database 이름의 동명 구분 괄호(広瀬(石川), 松森(名古屋鉄道))는 표시 이름이 아니다. original_name처럼 뗀다 (감사 A2-02)
for x in names:
    if x['entity_type']=='node' and x['lang']=='ja' and x.get('source')=='station_database' and re.search(r'\([^()（）]+\)$',x['text']):
        x['text']=re.sub(r'\([^()（）]+\)$','',x['text'])
# 노리츠부시 라벨의 주석(「／押上」 다른 이름, (臨), (旧会津滝ノ原), （臨時乗降場）, （うめきた）)은 표시 이름이 아니다 (감사 A2-03).
# 원문은 noritsubushi 별칭으로 남아 가져오기와 찾기는 그대로다
NS_NOTE=re.compile(r'／.*$|\((?:臨|仮)\)$|^\((?:臨|仮)\)|[（(](?:旧[^)）]*|臨時乗降場|うめきた|モードインターチェンジ|鉄道駅)[)）]$')
for x in names:
    if x['entity_type']=='node' and x['lang']=='ja' and x.get('source')=='noritsubushi' and NS_NOTE.search(x['text']):
        t_=NS_NOTE.sub('',x['text']).strip()
        if t_:
            aliases.append(dict(entity_type='node',id=x['id'],lang='ja',text=x['text'],kind='noritsubushi'));x['text']=t_
# 읽기에 붙은 괄호 주석(애칭, 부역명)은 뗀다. 이름 자체에 괄호가 있으면 괄호 안 읽기는 남기고 괄호 글자만 뗀다 (DB 감사 DBA-021)
for x in names:
    k_=x.get('kana')
    if not k_ or not re.search('[（(]',k_):continue
    # 부역명(蓮町（馬場記念公園前）)의 읽기도 뗀다. 읽기는 본 이름 것만 두어 영어·한국어 이름이 부역명을 이어 붙이지 않는다 (감사 A2-06)
    x['kana']=re.sub(r'[（(].*?[)）]','',k_).replace(' ','')
# 일본어 지금 이름에 읽기가 있는데(node_fix 등으로 나중에 확정) 한국어·영어 기본 행이 없으면 그 읽기로 규칙 행을 단다.
# 노드를 만들 때(위) 읽기가 없어 빠졌던 것이다. 없으면 compile이 일본어 표기 그대로(ja_as_is)로 채워 읽기가 있는데도 영어가 「JR松山駅前」이 된다
# (9회차 이름 열쇠 읽기 빌림 금지 뒤 15노드 퇴행: JR松山駅前·松山市駅·船小屋 등, 10회차 G1 chugoku_shikoku_2-005). 영어 공식 표기(en_fix)는 바로 아래 fix_nodes가 얹는다
_hasb={(x['id'],x['lang']) for x in names if x['entity_type']=='node' and not x.get('line') and not x.get('valid_from') and not x.get('valid_to')}
_kfill=collections.Counter()
for x in list(names):
    if x['entity_type']!='node' or x['lang']!='ja' or x.get('line') or x.get('valid_from') or x.get('valid_to') or not x.get('kana'):continue
    if x['id'] in _nokana:continue
    hk_=kata2hira(x['kana'])
    if (x['id'],'en') not in _hasb:
        e_=en_rules.station_reading(hk_,x['text']);e_=en_rules.fix_station(x['text'],hk_,e_,{}) or e_
        names.append(dict(entity_type='node',id=x['id'],lang='en',text=''.join(c for c in unicodedata.normalize('NFD',e_) if c!='\u0304'),source='rule'));_hasb.add((x['id'],'en'));_kfill['en']+=1
    if (x['id'],'ko') not in _hasb:
        t_=ko.station(hk_,x['text'])
        if x['text'].endswith('駅') and t_.endswith('에키'):t_=t_[:-2]+'역'
        names.append(dict(entity_type='node',id=x['id'],lang='ko',text=t_,source='rule',checked=TODAY));_hasb.add((x['id'],'ko'));_kfill['ko']+=1
print('읽기 있는 지금 이름의 빠진 한국어·영어 규칙 행',dict(_kfill))
# 영어 이름은 일본어와 읽기가 확정된 뒤에 고친다 (DESIGN §9.1, data/overrides/en_fix.json)
en_rules.fix_nodes(names)
# 역 이전의 옛 역 (DESIGN §2.2 옛 역의 표시). 새 역과 이름이 같으면 이름 뒤에 표시를 붙이고, 원래 이름과 노리츠부시 표기는 별칭으로 남긴다
OLDMARK={'ja':'（旧）','ko':'(구)','en':' (old)'}
# 노드·언어별 지금 이름. 기간 있는 행은 이 글자와 같을 때만 （旧）를 단다(옛 자리로 옮겨 온 다른 이름의 옛 이름 행은 그대로)
_bt={(x['id'],x['lang']):x['text'] for x in names if x['entity_type']=='node' and not x.get('line') and not x.get('valid_from') and not x.get('valid_to')}
NSLABEL={}
for p in parts:
    for o in p.st:
        if '旧' in o.label and not getattr(o,'ghost',False):NSLABEL.setdefault(nid(o),re.sub(r'【旧\d+】','【旧】',o.label.strip('*').strip('[]').strip()))
JA_={x['id']:x['text'] for x in names if x['entity_type']=='node' and x['lang']=='ja' and not x.get('line') and not x.get('valid_to')}
for mv in json.load(open(os.path.join(ROOT,'data','overrides','moved.json'),encoding='utf-8')):
    o_,n_=mv['old'],mv['new']
    if o_ not in nodes or JA_.get(o_)!=JA_.get(n_):continue
    for x in names:
        if x['entity_type']=='node' and x['id']==o_ and x['lang'] in OLDMARK and not x.get('line') and not (x.get('valid_to') and _bt.get((o_,x['lang']))!=x['text']):
            if x['lang']=='ja':aliases.append(dict(entity_type='node',id=o_,lang='ja',text=x['text'],kind='moved'))
            x['text']=x['text']+OLDMARK[x['lang']]
    lab=NSLABEL.get(o_)
    if lab:aliases.append(dict(entity_type='node',id=o_,lang='ja',text=lab,kind='noritsubushi'))
    nodes[o_]['export_name']=lab or JA_[o_]+'（旧）'
# 이전 쌍이 아니어도 한 계통에 지금 이름이 같은 역 둘이면 먼저 끝난 쪽에 （旧）를 단다 (2회차 종합 K25: 長岡線 옛 寺泊과 寺泊新道였던 寺泊).
# 끝은 그 계통의 정차 폐지(close_stop) 날이다. 둘 다 끝나지 않았거나 같은 날 끝나면 가르지 않는다
JA_={x['id']:x['text'] for x in names if x['entity_type']=='node' and x['lang']=='ja' and not x.get('line') and not x.get('valid_to')}
_cs={}
for fa_,e_ in EV:
    if e_.get('type')=='close_stop' and e_.get('date'):_cs[(e_['route'],e_['node'])]=min(_cs.get((e_['route'],e_['node']),'9'),lohi(e_['date'])[1])
_rn=collections.defaultdict(set)
for lk,ps,ch in line_rel:
    for c0 in ch:
        for c in [c0]+list(c0.alts):
            for x_ in getattr(c,'ns',[]):
                if nodes.get(x_,{}).get('kind')=='station':_rn[c.rid].add(x_)
_oldm=set()
for r_,ns_ in _rn.items():
    by_=collections.defaultdict(list)
    for x_ in ns_:
        if x_ in JA_ and not JA_[x_].endswith('（旧）'):by_[JA_[x_]].append(x_)
    for t_,v_ in by_.items():
        if len(v_)!=2:continue
        a_,b_=sorted(v_,key=lambda x_:_cs.get((r_,x_),'9999-99-99'))
        if _cs.get((r_,a_),'9')<_cs.get((r_,b_),'9999-99-99'):_oldm.add(a_)
# 계통이 달라도 같은 노선에 지금 이름이 같은 역 둘이면 먼저 끝난 쪽이 옛 역이다(東北本線 山線의 옛 松島와 海線의 松島, 3회차 tohoku_2-013, 9회차 N).
# 노선에서 끝난 날은 그 노선 모든 계통의 정차 폐지 가운데 늦은 날이다(한 계통이라도 아직 서면 끝나지 않음)
_lnn=collections.defaultdict(lambda:collections.defaultdict(list))
for lk,ps,ch in line_rel:
    for c0 in ch:
        for c in [c0]+list(c0.alts):
            for x_ in getattr(c,'ns',[]):
                if nodes.get(x_,{}).get('kind')=='station':_lnn[lk][x_].append(_cs.get((c.rid,x_),'9999-99-99'))
_oldl=[]
for lk,d_ in _lnn.items():
    by_=collections.defaultdict(list)
    for x_,cs_ in d_.items():
        if x_ in JA_ and not JA_[x_].endswith('（旧）') and x_ not in _oldm:by_[JA_[x_]].append((max(cs_),x_))
    for t_,v_ in by_.items():
        if len(v_)!=2:continue
        (ca_,a_),(cb_,b_)=sorted(v_)
        if ca_<cb_:_oldm.add(a_);_oldl.append((lk,t_,a_))
print('같은 노선 같은 이름 （旧）',len(_oldl),_oldl[:20])
# 이름 규칙 보고(확인 목록): 다른 역 읽기라 뺀 이름 열쇠 읽기, 같은 노선 같은 이름으로 단 （旧） (9회차 N)
json.dump(dict(namekey_drop=sorted(NAMEKEY_DROP),old_mark_same_line=sorted(_oldl)),open(os.path.join(CAND,'name_rules.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=0)
for o_ in sorted(_oldm):
    for x in names:
        if x['entity_type']=='node' and x['id']==o_ and x['lang'] in OLDMARK and not x.get('line') and not x['text'].endswith(OLDMARK[x['lang']]) and not (x.get('valid_to') and _bt.get((o_,x['lang']))!=x['text']):
            if x['lang']=='ja':aliases.append(dict(entity_type='node',id=o_,lang='ja',text=x['text'],kind='moved'))
            x['text']=x['text']+OLDMARK[x['lang']]
    nodes[o_]['export_name']=NSLABEL.get(o_) or JA_[o_]+'（旧）'
print('같은 계통 같은 이름 （旧）',len(_oldm),sorted(_oldm)[:30])
# 계통 이름은 역 이름 보정(node_fix, names_ko, 주석 떼기)이 끝난 뒤 양 끝 역의 이름으로 만든다 (감사 A2-11)
_ko={x['id']:x['text'] for x in names if x['entity_type']=='node' and x['lang']=='ko' and not x.get('line') and not x.get('valid_to')}
# 같은 계통 같은 이름으로 （旧）를 단 끝 역은 계통 이름에 표시 없이 쓴다 (大阪駅前～恵美須町)
for o_ in _oldm:
    if o_ in _ko and _ko[o_].endswith(OLDMARK['ko']):_ko[o_]=_ko[o_][:-len(OLDMARK['ko'])]
_ja={x['id']:x['text'] for x in names if x['entity_type']=='node' and x['lang']=='ja' and not x.get('line') and not x.get('valid_to')}
for o_ in _oldm:
    if o_ in _ja and _ja[o_].endswith(OLDMARK['ja']):_ja[o_]=_ja[o_][:-len(OLDMARK['ja'])]
# 끝 역 너머에 붙인 역 이전 옛 자리(wiki_insert_moves)는 계통 이름에 쓰지 않는다. 지금 끝 역 이름이다 (新豊橋～三河田原)
_site={x['id']:x['new_node'] for x in INS if x.get('old') and x.get('_done') and x.get('terminal')}
for r in routesout:
    f_,t_=_site.get(r['from'],r['from']),_site.get(r['to'],r['to'])
    if f_ in _ja and t_ in _ja:
        names.append(dict(entity_type='route',id=r['id'],lang='ja',text=f"{_ja[f_]}～{_ja[t_]}",source='rule'))
        if f_ in _ko and t_ in _ko:names.append(dict(entity_type='route',id=r['id'],lang='ko',text=f"{_ko[f_]}~{_ko[t_]}",source='rule'))
# 노선 전체의 옛 이름(line_history kind=name, 구간 노드 없음)은 날짜별 노선 이름이다 (재설계 결정 3). 한국어·영어는 읽기 규칙으로, 읽기가 없으면 일본어 표기 그대로.
# 읽기 규칙(ko)이 data/imports를 쓰므로 컴파일이 아니라 여기서 만든다
_lcur={x['id']:x['text'] for x in names if x['entity_type']=='line' and x['lang']=='ja' and not x.get('valid_from') and not x.get('valid_to') and not x.get('line')}
# 지금 표시 이름은 컴파일이 lines_ja.json으로 바꾼다. 그 이름과 같은 행도 날짜별 이름이 아니다
_LJ=json.load(open(os.path.join(ROOT,'data','overrides','lines_ja.json'),encoding='utf-8'))
for x in json.load(open(os.path.join(ROOT,'data','overrides','line_history.json'),encoding='utf-8')):
    # 지금 이름과 같은 행(사업자 기간만 적은 札幌市電)은 날짜별 이름이 아니다. 읽기가 없는 행도 버리지 않고 한국어·영어를 일본어 표기 그대로(ja_as_is) 둔다 (2회차 종합 K15).
    # 행에 ko·en이 적혀 있으면 그 값이다(사업자 접두가 붙은 옛 이름은 읽기 규칙이 한 낱말로 붙여 쓴다)
    if x['kind']!='name' or x.get('from_node') or x.get('to_node') or x['name_ja'] in (_lcur.get(x['line']),_LJ.get(x['line'])):continue
    if x['line'] not in linesout:
        if ONLY is None:raise SystemExit(f"line_history.json 행의 노선이 없습니다: {x['line']}")
        continue
    k_=x.get('kana')
    ko_=x.get('ko') or (ko.line(k_,x['name_ja']) if k_ else x['name_ja'])
    en_=x.get('en') or ((en_rules.hepburn(k_[:-2]).title()+' Line' if k_.endswith('せん') else en_rules.hepburn(k_).title()) if k_ else x['name_ja'])
    for lang_,text_ in (('ja',x['name_ja']),('ko',ko_),('en',en_)):
        add('line',x['line'],lang_,text_,kana=k_ if lang_=='ja' else None,source='line_history' if k_ or lang_=='ja' or x.get(lang_) else 'ja_as_is',valid_from=x['valid_from'],valid_to=x['valid_to'])
for lk,ps,ch in line_rel:
    for c in ch:
        for q in c.parts:
            aliases.append(dict(entity_type='route',id=c.rid,lang='ja',text=q.name+(f' ({q.paren})' if q.paren else ''),kind='noritsubushi',span=[q.frm,q.to]))
        for a in c.alts:
            for q in a.parts:
                aliases.append(dict(entity_type='route',id=c.rid,lang='ja',text=q.name+(f' ({q.paren})' if q.paren else ''),kind='noritsubushi',span=[q.frm,q.to]))
# 이름 출처는 값을 정한 근거다. 나무위키 제목이 있으면 규칙 결과와 같아도 namuwiki다 (DESIGN §9.2)
print('나무위키 태그',sum(1 for x in names if x['lang']=='ko' and x.get('source')=='namuwiki'))
# 노선(또는 구간)의 궤간·선로 방식 기간 (data/overrides/line_gauge.json, 2회차 종합 W0). 노선 행의 gauge로 넘기고 컴파일이 line_gauge 표로 낸다.
# 노선이 없는 행은 이름 키가 어긋난 것이라 멈춘다
for g_ in json.load(open(os.path.join(ROOT,'data','overrides','line_gauge.json'),encoding='utf-8'))['rows']:
    if g_['line'] not in linesout:
        if ONLY is None:raise SystemExit(f"line_gauge.json 행의 노선이 없습니다: {g_['line']}")
        continue
    linesout[g_['line']].setdefault('gauge',[]).append({k:v for k,v in dict(from_node=g_.get('from_node'),to_node=g_.get('to_node'),gauge=g_.get('gauge'),system=g_['system'],valid_from=g_.get('valid_from'),valid_to=g_.get('valid_to') or 'ongoing',source='; '.join(g_.get('evidence') or [])).items() if v is not None})
# ---- 쓰기
if os.path.isdir(SRC):shutil.rmtree(SRC)
fam=lambda x:'jr' if x=='jr' else 'private'
dump('operators/operators.yaml',[{k:v for k,v in o.items()} for o in ops.values()],'사업자')
for f in('jr','private'):
    dump(f'lines/{f}.yaml',[{k:FAM.get(v,v) if k=='family' else v for k,v in l.items() if v is not None} for l in linesout.values() if fam(l['family'])==f],'노선')
    dump(f'nodes/{f}.yaml',[{k:v for k,v in n.items() if k in('id','kind','group','pref','export_name') and v is not None} for n in nodes.values() if fam(n['family'])==f],'노드')
    ls={i for i,l in linesout.items() if fam(l['family'])==f}
    dump(f'routes/{f}.yaml',[r for r in routesout if r['line'] in ls],'계통')
    dump(f'edges/{f}.yaml',[e for e in edges.values() if e['seed_line'] in ls],'edge')
    # 표가 틀린 구간. 위키백과와 실제 선로가 일치할 때만 고치고 인접 구간의 합은 유지한다
    # 역이 끼어 쪼개진 구간의 행은 맞을 edge가 없다. 조용히 지나가면 틀린 표 값이 돌아오므로 멈춘다
    for fx in json.load(open(os.path.join(ROOT,'data','overrides','km_fix.json'),encoding='utf-8')):
        hit=[e for e in edges.values() if {e['a'],e['b']}=={fx['a'],fx['b']}]
        if not hit and ONLY is None:raise SystemExit(f"km_fix.json 행에 맞는 edge가 없습니다: {fx['a']}–{fx['b']}")
        for e in hit:km[e['id']]=fx['km'];kmsrc[e['id']]='wikipedia'
    dump(f'km/{f}.yaml',[dict(edge=e['id'],km=km[e['id']],source=kmsrc[e['id']]) for e in edges.values() if e['seed_line'] in ls],'edge별 영업km')
    dump(f'events/{f}.yaml',[e for fa,e in EV if fam(fa)==f],'사건')
dump('groups/groups.yaml',[dict(id=g) for g in sorted(set(gids.values()))],'같은 역 묶음')
# km를 추정한 정차역. 화면은 `? km`로 보이고 계산에만 쓴다 (DESIGN §4.5)
est_=sorted({(c.rid,nid(s_)) for _,_,ch in line_rel for c0 in ch for c in [c0]+list(c0.alts) for s_,_ in c.seq if getattr(s_,'km_est',False)})
dump('stops/estimated.yaml',[dict(route=r_,node=n_) for r_,n_ in est_],'km를 N05 선 위 위치로 추정한 정차역')
dump('hubs/hubs.yaml',hubs,'환승 묶음 초안')
json.dump(HUBEV,open(os.path.join(SRC,'hubs','hub_evidence.json'),'w',encoding='utf-8'),ensure_ascii=False)
# 좌표 교정. 묶음과 환승 판정이 끝난 뒤에 한다. 거리로 판정하는 값이 교정 때문에 흔들리면 안 된다
# 자기 사업자의 N02 승강장 선분에서 300m 넘게 떨어진 현행 역은 승강장 가운데로, node_fix.json에 좌표가 있는 노드는 그 값으로
n02_late=[]
for k_ in sorted(cur_nodes):
    n=nodes[k_]
    c=[x for t in sorted({n['nm'],*n['labels']}) for x in N02ST.get(N02AL.get(znorm(t),znorm(t)),[]) if n02_same(x,n)]
    if not c or not n['pt']:continue
    best=min(c,key=lambda x:plat_dist(n['pt'],x));d=plat_dist(n['pt'],best)
    if d>.301 and d<2:
        n02_late.append((n['nm'],k_,round(d,3)));n['pt']=(best[0],best[1]);n['closed_sd']='0';n['pt_src']='n02'
print('N02 승강장 교정',n02_late)
# 보간 좌표는 Wikidata에 그 역의 좌표가 있으면 그 값을 쓴다 (CC0). 신호장과 화물역은 원천 표에 없어 보간값으로 남아 있다
wd_pts=0
for n in nodes.values():
    if n['pt'] and n.get('pt_src')!='interpolated':continue
    c=[x['pt'] for t in (n['nm'],n['nm']+'信号場',n['nm']+'信号所') for x in WD.get(znorm(t),[]) if x.get('pt')]
    c=[x for x in c if n['pt'] and dist(n['pt'],x)<6]
    if c:n['pt']=min(c,key=lambda x:dist(n['pt'],x));n['pt_src']='wikidata';wd_pts+=1
print('Wikidata 좌표',wd_pts)
for k_,v_ in NFIX.items():
    if k_ in nodes and 'lat' in v_ and pos_ok(v_.get('pos_src')):nodes[k_].update(pt=(v_['lat'],v_['lon']),pt_src=v_.get('pos_src','hand'),closed_sd='1')
# 도도부현은 마지막 좌표로 다시 본다. 이름으로 짝지은 station_database 행이 다른 현의 같은 이름 역이면 현이 틀린다 (伊香保線이 熊本, DB 감사 DBA-010).
# 경계 역(山崎, 高の原)은 줄인 경계선의 오차 안이라 그대로 두고, 적힌 현에서 1km 넘게 떨어진 것만 좌표가 든 현으로 바꾼다
PREFPOLY={}
for f_ in json.load(open(os.path.join(ROOT,'data','base','pref.geojson'),encoding='utf-8'))['features']:
    g_=f_['geometry']
    PREFPOLY[str(f_['properties']['pref'])]=[(((min(x for r in q for x,_ in r),min(y for r in q for _,y in r),max(x for r in q for x,_ in r),max(y for r in q for _,y in r))),q) for q in (g_['coordinates'] if g_['type']=='MultiPolygon' else [g_['coordinates']])]
def in_pref(pt,pf):
    x,y=pt;hit=False
    for (x0,y0,x1,y1),q in PREFPOLY.get(pf,()):
        if not(x0<=x<=x1 and y0<=y<=y1):continue
        for ring in q:
            inr=False
            for (ax,ay),(bx,by) in zip(ring,ring[1:]+ring[:1]):
                if (ay>y)!=(by>y) and x<(bx-ax)*(y-ay)/(by-ay)+ax:inr=not inr
            if inr:hit=not hit
    return hit
def pref_gap(pt,pf):
    x,y=pt;kx=math.cos(math.radians(y))*111.32;ky=110.57;best=1e9
    for _,q in PREFPOLY.get(pf,()):
        for ring in q:
            for (ax,ay),(bx,by) in zip(ring,ring[1:]+ring[:1]):
                if abs(ay-y)>.05 and abs(by-y)>.05 and (ay-y)*(by-y)>0:continue
                dx,dy=(bx-ax)*kx,(by-ay)*ky;L=dx*dx+dy*dy
                t_=0 if L==0 else max(0,min(1,((x-ax)*kx*dx+(y-ay)*ky*dy)/L))
                best=min(best,math.hypot((x-ax)*kx-t_*dx,(y-ay)*ky-t_*dy))
    return best
pref_fix=[]
# 좌표 보정 파일(data/overrides/positions)이 컴파일 때 덮어쓰는 노드는 그 좌표로 본다 (前橋線 前橋駅前은 여기서 熊本 역 좌표였음)
from lib import _FILL,_rows
_k,_t,_s=_FILL['positions']
POSOV={x[_k]:(x['lat'],x['lon']) for x in _rows(os.path.join(ROOT,'data','overrides','positions')) if source_on(_s.get(x.get(_t),x.get(_t))) and x.get('lat') is not None}
for n in nodes.values():
    p_=POSOV.get(n['id']) or n['pt']
    if not p_:continue
    pt=(p_[1],p_[0]);pf=n.get('pref')
    if pf and in_pref(pt,str(pf)):continue
    w=next((k for k in PREFPOLY if in_pref(pt,k)),None)
    # 빌린 도도부현은 좌표가 든 폴리곤이 허용 오차 없이 이긴다(両備金光). station_database 주소의 현은 줄인 경계선 오차(1km) 안이면 그대로 둔다(山崎, 高の原)
    if w and w!=str(pf) and (not pf or n.get('pref_src')=='borrow' or pref_gap(pt,str(pf))>1.0):pref_fix.append((n['id'],pf,w));n['pref']=w
print('좌표로 고친 도도부현',len(pref_fix),pref_fix)
for f in('jr','private'):
    dump(f'nodes/{f}.yaml',[{k:v for k,v in n.items() if k in('id','kind','group','pref','export_name') and v is not None} for n in nodes.values() if fam(n['family'])==f],'노드')
dump('positions/positions.yaml',[dict(node=n['id'],lat=n['pt'][0] if n['pt'] else None,lon=n['pt'][1] if n['pt'] else None,quality=('precise' if n.get('closed_sd')=='0' else 'approx') if n['pt'] else 'none',checked=TODAY,source=n.get('pt_src','station_database') if n['pt'] else None) for n in nodes.values()],'노드 좌표')
dump('names/names.yaml',names,'이름')
dump('aliases/aliases.yaml',aliases,'별칭')
# 운행 계통
SV=json.load(open(os.path.join(ROOT,'data','overrides','services.json'),encoding='utf-8'))
# 노선 이름 → 계통 ID. 같은 이름의 다른 계통(本線, 福知山線 등)은 parts의 4번째 원소(계통 ID)로 가린다
ali={}
for a in aliases:
    if a['entity_type']=='route':ali.setdefault(a['text'],a['id'])
for a in aliases:ali.setdefault(a['text'],a['id'])
def sv_editions(sv):
    """판 목록. 옛 꼴(parts·valid)은 정차역 없는(모든 역) 판 하나다 (운행 계통 형식 v2)"""
    if 'editions' in sv:return sv['editions']
    v_=sv.get('valid') or [None,'ongoing']
    return [{'from':v_[0],'to':v_[1],'parts':sv['parts']}]
# 역 이름은 여기서 풀지 않는다. 같은 경로에 같은 이름이 둘(옛 이름·옛 자리)일 때 판 기간의 정차·이름으로 가려야 해서
# 기간이 다 갖춰진 컴파일(tools/compile.py)이 노드로 바꾼다. 여기서는 노선 이름만 계통 ID로 바꾼다
svc=[];bad=[]
for sv in SV:
    eds=[]
    for ed in sv_editions(sv):
        sparts=[]
        for pt_ in ed['parts']:
            lname,a,b=pt_[:3]
            rid=pt_[3] if len(pt_)>3 and pt_[3] else ali.get(lname)
            if not rid:bad.append((sv['id'],ed.get('from'),lname));continue
            sparts.append({'route':rid,'a':a,'b':b})
        x_=dict(valid=[ed.get('from'),ed.get('to') or 'ongoing'],parts=sparts)
        if ed.get('stops') is not None:x_['stops_ja']=list(ed['stops'])
        eds.append(x_)
    eds.sort(key=lambda e:lohi(e['valid'][0])[0] or '')
    x=dict(id=sv['id'],editions=eds)
    if sv.get('closed'):x['closed']=True
    svc.append(x)
    names.append(dict(entity_type='service',id=sv['id'],lang='ja',text=sv['ja'],source='hand'))
    names.append(dict(entity_type='service',id=sv['id'],lang='ko',text=sv['ko'],source='hand'))
    # 옛 안내 이름(長野行新幹線)은 기간 붙은 이름이라 검색에 걸리고 화면 이름은 지금 이름 그대로다
    for h_ in sv.get('name_history') or []:
        if h_.get('ja') and h_['ja']!=sv['ja']:
            names.append(dict(entity_type='service',id=sv['id'],lang='ja',text=h_['ja'],source='hand',valid_from=h_.get('from'),valid_to=h_.get('to')))
dump('services/services.yaml',svc,'운행 계통')
dump('names/names.yaml',names,'이름')
print('운행 계통',len(svc),'판',sum(len(x['editions']) for x in svc),'문제',bad)
# 노선을 못 찾은 운행 계통은 틀린 구간을 보이거나 저장하게 되므로 멈춘다
if bad:raise SystemExit(f'운행 계통 정의 오류(노선 이름): {bad}')
os.makedirs(CAND,exist_ok=True)
# N05에는 있지만 위키 목록에 km가 없는 역은 열람 전용 역으로 (tools/gen_n05.py, DESIGN §4.1). gen_extra가 이름을 붙여 넣는다
n05arch=[]
for lk,ps,chs in line_rel:
    for c in chs:
        for p in c.parts:
            for nm_,a_,b_ in getattr(p,'arch',[]):
                oa=next((o for o in p.st if o.label==a_),None);ob=next((o for o in p.st if o.label==b_),None)
                if oa and ob:n05arch.append(dict(kind='stop',id='a_'+stable(lid[lk],nm_),line=lid[lk],route=c.rid,after=nid(oa),before=nid(ob),name=nm_,opened=None,closed=max([d for _,_,d in p.x_legal] or [None]),km=None,source='n05'))
json.dump(n05arch,open(os.path.join(CAND,'n05_arch.json'),'w',encoding='utf-8'),ensure_ascii=False)
json.dump(sorted(NEWK),open(os.path.join(CAND,'new_ids.json'),'w',encoding='utf-8'),ensure_ascii=False)
json.dump(dict(pending=pend,unresolved=unresolved,transfers=[(p.name,p.frm,p.to,q.cn,q.name,len(sh)) for p,q,sh in trans]),open(os.path.join(CAND,'gen_report.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=0)
tot=collections.Counter()
for p in parts:
    if p.g in('jr','pr'):tot[jr_of(p) if p.family=='jr' else oid(p.c)]+=p.km
json.dump({k:dround(v) for k,v in tot.items()},open(os.path.join(CAND,'n_totals.json'),'w',encoding='utf-8'),ensure_ascii=False)
json.dump(NROUTE,open(os.path.join(CAND,'n_routes.json'),'w',encoding='utf-8'),ensure_ascii=False)   # 로컬 QA 전용. 사이트 내부 ID라 공개 데이터에 넣지 않는다
print('nodes',len(nodes),'edges',len(edges),'routes',len(routesout),'events',len(EV),'hubs',len(hubs),'pending',len(pend))
