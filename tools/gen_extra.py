# -*- coding: utf-8 -*-
# 열람 전용 항목에 옛 폐선을 더하고 이름을 붙인다. 한글 이름을 못 만든 항목은 빼고 기록한다
import sys,os,re,json,csv,collections,math
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from lib import *
import ko,conn,unicodedata,en_rules
from gen_en_names import line_name
KANA={}
# 이름 열쇠 읽기의 출처 (gen_source KSRC와 같은 뜻): ('wiki', 문서 제목)·('hand',)·('est',)
KSRC={}
for a,b in json.load(open(os.path.join(IMP,'wiki','kana.json'),encoding='utf-8')).items():
    nm=a.split(':',1)[1];t=b['title']
    if znorm(nm)[:2] not in znorm(t):continue
    KANA[a]=re.sub(r'(えき|ていりゅうじょう|ていりゅうしょ|でんてい)$','',b['kana']);KSRC[a]=('wiki',t)
_kh=json.load(open(os.path.join(ROOT,'data','overrides','kana.json'),encoding='utf-8'));KANA.update(_kh);KSRC.update({a:('hand',) for a in _kh})
_e=os.path.join(ROOT,'data','overrides','kana_est.json')
if os.path.exists(_e):
    _ke=json.load(open(_e,encoding='utf-8'));KANA.update(_ke);KSRC.update({a:('est',) for a in _ke})
sdk={}
for s in csv.DictReader(open(os.path.join(IMP,'stationdb','station.csv'),encoding='utf-8')):
    if s['name_kana'] not in('','NULL'):sdk.setdefault(znorm(s['name']),s['name_kana'])
for s in csv.DictReader(open(os.path.join(IMP,'stationdb','line.csv'),encoding='utf-8')):
    if s['name_kana'] not in('','NULL'):sdk.setdefault('L'+znorm(conn.clean(s['name'])),s['name_kana'])
NLN=json.load(open(os.path.join(IMP,'namuwiki','names_lines.json'),encoding='utf-8')) if source_on('namuwiki') else {}
_g=os.path.join(ROOT,'data','overrides','kana_est_report.json')
GUESS=set(json.load(open(_g,encoding='utf-8')).get('guess',[])) if os.path.exists(_g) else set()
arch=load('archive')
# 열람 전용 역의 이름 열쇠 읽기(위키 「X駅」 문서·station_database 이름 맞춤)도 그 이름의 어느 한 역 읽기다. 노드 규칙(gen_source namekey_ok)과 같이
# ① 문서 역 정보칸의 사업자·노선이 그 열람 전용 역의 노선 사업자·노선 이름과 맞거나 ② 같은 이름의 노드·다른 열람 전용 역이 없거나
# ③ 같은 이름 노드가 그 노선에 서거나 앞뒤 역에서 5 km 안(같은 곳의 옛 자리·옛 정류장)일 때만 쓴다.
# 손 조사 표(kana.json·kana_est.json)와 행의 읽기(archive_fix kana·_add kana)는 그대로다. 손 행(_add)의 kana null도 같은 규칙이다 (9회차 N)
WS=json.load(open(os.path.join(IMP,'wiki','station.json'),encoding='utf-8'))
_OPJ={o['id']:o.get('name_ja') or '' for o in load('operators')}
_LOP=collections.defaultdict(set)
for e in load('events'):
    if e.get('line') and e.get('operator'):_LOP[e['line']].add(_OPJ.get(e['operator'],''))
_LNJ={l['id']:l.get('name_ja') or '' for l in load('lines')}
_NAMEN=collections.defaultdict(set)
for x in load('names'):
    if x.get('entity_type')=='node' and x.get('lang')=='ja' and not x.get('line') and not x.get('valid_from') and not x.get('valid_to'):_NAMEN[znorm(x['text'])].add(x['id'])
_NODEJA={k:len(v) for k,v in _NAMEN.items()}
_POS={p['node']:(p['lat'],p['lon']) for p in load('positions') if p.get('lat') is not None}
_RL={r['id']:r.get('line') for r in load('routes')}
_NLINE=collections.defaultdict(set)
for x in load('stops'):_NLINE[x['node']].add(_RL.get(x['route']))
def _km(p,q):return math.hypot((p[0]-q[0])*111.2,(p[1]-q[1])*111.2*math.cos(math.radians(p[0])))
def _same_place_nm(a,nm):
    """같은 이름 노드가 그 열람 전용 역의 노선에 서거나 앞뒤 역에서 5 km 안이면 같은 곳의 같은 이름(옛 자리·옛 정류장)이다"""
    nb_=[_POS[x] for x in (a.get('after'),a.get('before')) if x in _POS]
    return any(a.get('line') in _NLINE[m] or (m in _POS and any(_km(_POS[m],q)<5 for q in nb_)) for m in _NAMEN.get(nm,()))
def _opc(t):return re.sub(r'株式会社|[（(].*?[)）]|\{\{.*?\}\}|\[\[|\]\]|\s','',unicodedata.normalize('NFKC',t or ''))
def _pm(xs,ys):
    a_=[_opc(y) for o in xs for y in re.split(r'<br\s*/?>|、|・|■|●',o or '') if len(_opc(y))>=2];b_=[_opc(c) for c in ys if len(_opc(c))>=2]
    return any(x==y or x in y or y in x for x in a_ for y in b_)
NAMEKEY_DROP_A=[]
# N05 노선의 km 없는 역 (gen_source가 만든 후보)
_n=os.path.join(CAND,'n05_arch.json')
if os.path.exists(_n):arch+=json.load(open(_n,encoding='utf-8'))
# 위키 문서 순서와 현역 역 읽기로는 틀리는 열람 전용 역을 사람이 고친 값
FIX=json.load(open(os.path.join(ROOT,'data','overrides','archive_fix.json'),encoding='utf-8'))
# 자리 키는 이름으로 찾고, 같은 이름이 여러 노선에 있을 수 있는 행은 "이름@위키 노선"(고치기 전 line) 키로 그 행만 고친다.
# @ 키는 이름 키 뒤에 얹는다. 맞는 행이 없는 @ 키는 쓰이지 않는 보정이라 멈춘다
# 개업·폐지일(opened·closed)과 휴지로 끝난 역의 휴지 시작·법적 폐지일(suspended·legal_abolition, 결정 128)도 사람이 고친 값이다
# archive_line·seq: 기록 노선이 없는 옛 노선(열람 전용 노선)의 역으로 옮길 때 그 노선 ID와 노선 방향 순서 (母里線 与一谷·不動尊, 11회차 S2)
_PK=('line','route','after','before','km','opened','closed','suspended','legal_abolition','archive_line','seq');_used=set()
# 손 값의 달·해 정밀도(1883-10)는 EDTF 「하나의 값」 꼴(1883-10-XX)로 맞춘다. 범위 [A..B]는 그대로
_DK=('opened','closed','suspended','legal_abolition')
def _fixv(k,v):return (edtf(v) or v) if k in _DK and isinstance(v,str) and not v.startswith('[') else v
for a in arch:
    if a.get('kind')!='stop':continue
    k2=f"{a.get('name')}@{a.get('line')}"
    a.update({k:_fixv(k,v) for k,v in FIX.get(a.get('name'),{}).items() if k in _PK})
    if k2 in FIX:a.update({k:_fixv(k,v) for k,v in FIX[k2].items() if k in _PK});_used.add(k2);a['_fk2']=k2
_un=sorted(k for k in FIX if '@' in k and k not in _used)
if _un:raise SystemExit(f'archive_fix.json의 이름@노선 행에 맞는 열람 전용 역이 없습니다 ({len(_un)}): {_un}')
names=load('names')
# 이름 글자 → 그 이름을 가진(지금 이름·기간 있는 옛 이름) 노드와 그 이름 행
nn=collections.defaultdict(list);nrow=collections.defaultdict(list)
for x in names:
    if x['entity_type']=='node' and x['lang']=='ja' and not x.get('line'):nn[znorm(x['text'])].append(x['id']);nrow[znorm(x['text'])].append(x)
# 노드의 자리와 기간: 좌표, 서는 노선, 처음 정차한 날. 열람 전용 역·노선을 이미 있는 역과 이름 글자가 아니라 자리·기간으로 맞춘다 (2회차 종합 K24)
POS={p['node']:(p['lat'],p['lon']) for p in load('positions') if p.get('lat') is not None}
RLINE={r['id']:r['line'] for r in load('routes')}
NLINE=collections.defaultdict(set);NOPEN={}
for e in load('edges'):
    for x in (e['a'],e['b']):NLINE[x].add(e.get('seed_line'))
for ev in load('events'):
    if ev.get('node') and ev.get('route') in RLINE:NLINE[ev['node']].add(RLINE[ev['route']])
    if ev.get('type')=='open_stop' and ev.get('node') and ev.get('date'):
        try:d_=lohi(ev['date'])[0]
        except (TypeError,ValueError):continue
        NOPEN[ev['node']]=min(NOPEN.get(ev['node'],'9999'),d_)
def _km(a,b):
    la1,lo1,la2,lo2=map(math.radians,(*a,*b))
    return 6371*2*math.asin(math.sqrt(math.sin((la2-la1)/2)**2+math.cos(la1)*math.cos(la2)*math.sin((lo2-lo1)/2)**2))
def _span(f,t):
    """EDTF 기간의 가장 이른 시작과 가장 늦은 끝. 모르는 쪽은 열린 끝"""
    try:return (lohi(f)[0] if f else '0000-01-01',lohi(t)[1] if t and t!='ongoing' else '9999-12-31')
    except (TypeError,ValueError):return ('0000-01-01','9999-12-31')
rep=json.load(open(os.path.join(CAND,'old_report.json'),encoding='utf-8'))
lineja=set()
for x in names:
    if x['entity_type']=='line' and x['lang']=='ja':lineja.add(znorm(x['text']))
for l in load('lines'):
    if l.get('sd'):lineja.add(znorm(conn.clean(l['sd'])))
# 같은 역이 이미 노드로 들어 있으면 뺀다. 같은 역인지는 이름 글자가 아니라 자리·기간으로 본다 (docs/redesign.md 재설계 R7, 2회차 종합 K24):
#  그 이름(지금 이름·기간 있는 옛 이름)을 가진 노드가 그 열람 전용 역의 앞뒤 역이 아니고, 그 노선에 서거나 앞뒤 역에서 1km 안이며,
#  그 이름을 쓴 기간(지금 이름은 그 노드가 처음 선 날부터)이 열람 전용 역이 있던 기간과 겹칠 때.
# 이름만 이어받은 옆 시설(霞ヶ浦의 옛 이름 羽津와 1943년까지의 羽津, 天理市, 富洲原, 橿原神宮)은 앞뒤 역이라 남는다
def _same_place(a,x):
    if x in (a.get('after'),a.get('before')):return False
    if a.get('line') and a['line'] in NLINE[x]:return True
    ends=[POS[y] for y in (a.get('after'),a.get('before')) if y in POS]
    return bool(ends) and x in POS and min(_km(POS[x],q) for q in ends)<=1.0
def _known(a):
    lo_,hi_=_span(a.get('opened'),a.get('closed'))
    for r in nrow.get(znorm(a.get('name') or ''),[]):
        f_,t_=_span(r.get('valid_from') or (None if r.get('valid_to') else NOPEN.get(r['id'])),r.get('valid_to'))
        if f_<hi_ and lo_<t_ and _same_place(a,r['id']):return True
    return False
# 이름 없는 역 행은 쓸 수 없다
arch=[a for a in arch if not (a.get('kind')=='stop' and (not a.get('name') or _known(a)))]
# 예전 규칙(이름 글자만)이 지우던 역은 ID를 정할 때 뒤에 둔다. 먼저 있던 열람 전용 역의 공개 ID가 새로 남은 같은 읽기 역으로 옮겨 가지 않게 한다
_oldn={znorm(x['text']) for x in names if x['entity_type']=='node' and x['lang']=='ja' and x.get('source')!='n05'}
for a in arch:
    if a.get('kind')=='stop' and znorm(a.get('name') or '') in _oldn:a['_late']=True
# 사람이 확인한 열람 전용 역 행 (archive_fix.json "_add"). 이름만 같은 다른 역 노드(駅前·沖·東伏見) 때문에 지워지던 역을 되살린 행이라,
# 자리·기간 판정(_known)으로 위키 노선도 행이 남으면 그 행에 사람이 적은 자리·km·읽기를 얹는다. 없으면 새 행이다.
# 읽기는 행의 kana, ID는 다른 행과 같은 규칙(읽기 로마자, 겹치면 노선)이다.
# kind line 행은 다른 노선 문서 노선도에 잘못 붙은 옛 지선·옛 구간 역 대신 그 갈림 역(at)에 다는 열람 전용 노선이다 (法隆寺線, 富内線 沼ノ端–豊城)
for x in FIX.get('_add',[]):
    v_={k:v for k,v in x.items() if k not in('why','kana')}
    hit=[a for a in arch if a.get('kind')=='stop' and x.get('kind','stop')=='stop' and a.get('name')==x['name'] and a.get('line')==x.get('line')]
    # 이름 키 보정(휴지 시작·법적 폐지·그 시기 앞뒤 역)은 _add 행보다 나중에 확인한 값이라 _add 값 위에 다시 얹는다.
    # 앞에서 얹은 값을 _add가 옛 값으로 덮어 伝馬町·星川·四十九 등의 휴지·앞뒤 역이 빠지던 것 (6회차 근거 조사 2026-11-14)
    def _again(a):a.update({k:_fixv(k,v) for k,v in FIX.get(a.get('name'),{}).items() if k in _PK})
    if hit:
        for a in hit:a.update({k:v for k,v in v_.items() if k!='id'},add_kana=x['kana']);a.pop('_late',None);_again(a)
        continue
    arch.append(dict(v_,add_kana=x['kana']));_again(arch[-1])
# 같은 노선도(같은 문서)의 같은 이름 역이 여러 노선에 붙었을 때, 앞뒤 역이 다 있는 행이 있으면 한쪽 역만 있고 km도 없는 행은 옆 노선 끝으로 번진 것이라 뺀다
# (飯田線 노선도의 옛 역이 小坂井支線 끝 小坂井 뒤에, 竹鼻線 노선도의 역이 大須 끝에 한 번 더 붙음, 2회차 종합 K24)
_full=collections.defaultdict(bool)
for a in arch:
    if a.get('kind')=='stop' and a.get('after') and a.get('before'):_full[(a.get('name'),a.get('source'))]=True
_spill=[a for a in arch if a.get('kind')=='stop' and _full[(a.get('name'),a.get('source'))] and not (a.get('after') and a.get('before')) and a.get('km') is None]
# 뺀 행도 ID를 정할 때는 남겨 둔다. 겹치는 읽기의 다른 행 ID(竹鼻線 東須賀 a_higashisuka_takehana)가 바뀌지 않게
for a in _spill:a['_spill']=True
print('옆 노선으로 번진 열람 전용 역 뺌',len(_spill))
# 열람 전용 노선을 다는 역(at): 역 목록 이름 가운데 노드 하나로만 맞는 것. 맞는 역이 둘 이상이면 다른 맞는 역이 30km 안에 있는 첫 역이다.
# 이름만 같은 먼 역(光明電気鉄道 平松 → 山陽 網干線 平松)이 붙지 않게 한다. 서로 모인 역이 없으면 자리로 가를 수 없어 첫 역이다
def _at(stations,closed):
    cand=[]
    for s in stations:
        xs=set(nn.get(znorm(s),[]))
        if len(xs)==1 and next(iter(xs)) not in cand:cand.append(next(iter(xs)))
    if len(cand)<2:return cand[0] if cand else None
    return next((x for x in cand if x in POS and any(y!=x and y in POS and _km(POS[x],POS[y])<=30 for y in cand)),cand[0])
seen={a['id'] for a in arch}
seenk=set()
# 무궤조전차(트롤리버스)는 궤도가 없어 넣지 않는다. 노리츠부시에 있는 立山·関電 터널 트롤리버스만 기록 노선으로 남는다 (DESIGN §4.4, 사용자 결정 2026-11-04)
TRACKLESS=re.compile(r'無軌道|無軌条|トロリー')
for a in rep['archive']:
    if TRACKLESS.search(a['name']):continue
    if not re.search(r'(線|鉄道|鐵道|電鉄|電車|ケーブル|登山)$',a['name']) or a['name'] in('不要不急線','特定地方交通線'):continue
    if znorm(a['name']) in lineja:continue
    nk=znorm(a['name']).replace('電気鉄道','電鉄').replace('精練','製錬')
    nk=re.sub(r'線$','',nk)
    if any(nk==k or nk.startswith(k) or k.startswith(nk) for k in seenk):continue
    seenk.add(nk)
    at=_at(a.get('stations') or [],a.get('closed'))
    i='a_'+stable('line',a['name'])
    if i in seen:continue
    seen.add(i)
    arch.append(dict(kind='line',id=i,name=a['name'],at=at,closed=a.get('closed'),source=f"wikipedia:{a.get('revid')}"))
# N05와 대조하지 못한 옛 폐선 중 위키 역 목록으로 순서를 아는 것 (tools/gen_n05.py). 읽기가 없으면 ID를 못 만들어 넣지 않는다
_r=os.path.join(CAND,'n05_report.json');nokana_arch=[]
_FIX=json.load(open(os.path.join(ROOT,'data','overrides','n05_fix.json'),encoding='utf-8'))['lines']
_OKN05={tuple(x) for f in _FIX.values() if f.get('verdict','skip' if f.get('kind')=='skip' else 'ok')=='ok' for x in f.get('n05_names') or []}
for a in (json.load(open(_r,encoding='utf-8')).get('report',[]) if os.path.exists(_r) else []):
    n=a.get('name')
    if TRACKLESS.search(n or '') or any(TRACKLESS.search(' '.join(x)) for x in a.get('names') or []):continue
    if a['result']!='archive' or not n:continue
    # 손 대조 표(n05_fix)가 열람 전용으로 정한 노선은 이름이 다른 회사 노선과 같아도(琴電 市内線) 넣는다. 읽기가 없으면 멈춘다
    hand=bool(a.get('hand'))
    if not (KANA.get('line:'+n) or sdk.get('L'+znorm(n))):
        if hand:nokana_arch.append(a.get('line') or n)
        continue
    # 손 대조 열람 전용도 같은 N05 선로를 기록 노선이 이미 가졌으면(琴平急行電鉄線) 넣지 않는다
    if hand and {tuple(x) for x in (_FIX.get(a.get('line')) or {}).get('n05_names') or []}&_OKN05:continue
    if not hand and znorm(n) in lineja:continue
    nk=re.sub(r'線$','',znorm(n))
    if any(nk==k or nk.startswith(k) or k.startswith(nk) for k in seenk):continue
    seenk.add(nk)
    at=_at(a.get('order') or [],f"{a['closed_year']}-XX-XX" if a.get('closed_year') else None)
    i='a_'+stable('line',n)
    if i in seen and hand:i='a_'+stable('line',a.get('line') or n)
    if i in seen:continue
    seen.add(i)
    arch.append(dict(kind='line',id=i,name=n,at=at,closed=f"{a['closed_year']}-XX-XX",source=f"wikipedia:{a.get('revid')}" if a.get('revid') else 'n05'))
# 노선도 끝 너머에 그려진 지선 역(gen_wiki branch: 분기 행 「←母里支線」의 앞말과 이름이 맞는 묶음)은 그 지선의 열람 전용 노선 역으로 옮긴다.
# 노선 이름이 「앞말+線」「앞말+支線」인 열람 전용 노선이 하나뿐이고, 손 값(archive_fix)으로 자리를 잡지 않아 아직 끝 역 너머(앞뒤 한쪽 없음)인 역만 옮긴다.
# 순서(seq)는 노선도 행 순서, 앞 역은 분기 행 바로 위 역이다. 맞는 노선이 없으면 그대로 두고 알린다 (日ノ丸自動車法勝寺電鉄線 母里支線, 2026-11-20 사용자 지적)
_BRL=collections.defaultdict(set)
for a in arch:
    if a.get('kind')=='line':
        for sfx in ('支線','線'):
            if znorm(a.get('name') or '').endswith(sfx):_BRL[znorm(a['name'])[:-len(sfx)]].add(a['id'])
_bro=collections.defaultdict(list);BRANCH_KEEP=[]
for a in arch:
    if a.get('kind')=='stop' and a.get('branch') and not (a.get('after') and a.get('before')) and not a.get('archive_line'):_bro[(a.get('line'),a['branch'],a['branch_at'])].append(a)
for (ln_,root_,at_),xs in _bro.items():
    ids_=sorted(_BRL.get(root_,()))
    if len(ids_)!=1:BRANCH_KEEP+=[(ln_,root_,x.get('name')) for x in xs];continue
    for k_,x in enumerate(sorted(xs,key=lambda x:x['brow']),1):x.update(archive_line=ids_[0],line=None,route=None,after=at_,before=None,km=None,seq=k_)
for a in arch:
    for k_ in ('branch','branch_at','brow'):a.pop(k_,None)
if BRANCH_KEEP:print('노선도 지선 역인데 맞는 열람 전용 노선이 없어 그대로 둔 행',len(BRANCH_KEEP),BRANCH_KEEP[:12])
if nokana_arch:raise SystemExit(f'읽기가 없어 열람 전용 노선을 만들 수 없습니다 ({len(nokana_arch)}): {nokana_arch}. data/overrides/kana.json에 line: 읽기를 넣으세요')
_ARCHN=collections.Counter(znorm(a.get('name') or '') for a in arch if a.get('kind')=='stop')
_ARCHBY=collections.defaultdict(list)
for a in arch:
    if a.get('kind')=='stop':_ARCHBY[znorm(a.get('name') or '')].append(a)
def _arch_far(a,nm):
    """같은 이름의 다른 열람 전용 역이 다른 곳(앞뒤 역끼리 5 km 넘게 떨어짐, 자리 모름 포함)에 있으면 참. 같은 역이 두 노선 노선도에 함께 실린 것(宮地嶽)은 같은 곳이다"""
    pa=[_POS[y] for y in (a.get('after'),a.get('before')) if y in _POS]
    for b in _ARCHBY.get(nm,()):
        if b is a:continue
        pb=[_POS[y] for y in (b.get('after'),b.get('before')) if y in _POS]
        if not pa or not pb or min(_km(p,q) for p in pa for q in pb)>=5:return True
    return False
# 같은 이름 열람 전용 역이 놓인 노선들. 한 노선뿐이면(같은 역의 중복 행) 이름 키 보정 읽기는 그 역 것이다
_ARCHL=collections.defaultdict(set)
for a in arch:
    if a.get('kind')=='stop':_ARCHL[znorm(a.get('name') or '')].add(a.get('line') or a.get('archive_line'))
_ANJ={a['id']:a.get('name') or '' for a in arch if a.get('kind')=='line'}
out=[];rows=[];drop=[];KA={};LATE=set();SPILL=set()
# 열람 전용 역 읽기의 출처: row(_add 행)·fix(archive_fix 이름·이름@노선 행)·wiki·hand·est·sd(이름 열쇠). 감사 K104가 이름 열쇠 읽기를 다시 본다
AKSRC={}
TODAY=AS_OF
for a in arch:
    n=a.get('name')
    t=None;kana=None;src='rule'
    fix=FIX.get(n,{}) if a['kind']=='stop' else {}
    # 보정 행의 읽기·한국어는 그 역 것이다. 이름 키 행은 같은 이름 열람 전용 역이 한 노선에만 있거나 행의 노선이 그 역 노선일 때만 얹고,
    # 「이름@노선」 행이면 그 행 것을 쓴다. 같은 이름 다른 열람 전용 역에 읽기를 빌려 주지 않는다 (R 갈래 지적, 9회차 N)
    if a['kind']=='stop':
        if fix and len(_ARCHL[znorm(n)])>1 and not (fix.get('line') and fix.get('line')==a.get('line')):fix={k:v for k,v in fix.items() if k not in ('kana','ko')}
        if a.get('_fk2'):fix=dict(fix,**{k:v for k,v in FIX[a['_fk2']].items() if k in ('kana','ko')})
    if a['kind']=='stop':
        kana=a.get('add_kana') or fix.get('kana')
        if kana:AKSRC[a['id']]='row' if a.get('add_kana') else 'fix'
        if not kana:
            k_=KANA.get('node:'+n);s_=KSRC.get('node:'+n) if k_ else None
            if not k_ and sdk.get(znorm(n)):k_=sdk[znorm(n)];s_=('sd',)
            # 문서 제목이 그 이름이 아니면(넘겨주기로 지금 역 문서) 다른 이름의 읽기다
            if k_ and s_[0]=='wiki' and znorm(re.sub(r'(駅|停留場|停留所|電停|仮乗降場|乗降場|信号場)$','',re.sub(r'\s*[（(].*?[)）]\s*$','',s_[1])))!=znorm(n):
                NAMEKEY_DROP_A.append((a['id'],n,k_,'wiki_other_title'));k_=None
            if k_ and s_[0] not in ('hand','est'):
                bl_=(WS.get(s_[1]) or {}).get('blocks',[]) if s_[0]=='wiki' else []
                ln_=a.get('line');mine_=_LOP.get(ln_,set())|({_LNJ.get(ln_,'')} if ln_ else set())|({_ANJ.get(a.get('archive_line'),'')} if a.get('archive_line') else set())
                ok_=_pm([b.get('ops','') for b in bl_]+[b.get('lines','') for b in bl_],mine_) if bl_ else False
                if not ok_ and ((not _NODEJA.get(znorm(n)) and not _arch_far(a,znorm(n))) or _same_place_nm(a,znorm(n))):ok_=True
                if not ok_:NAMEKEY_DROP_A.append((a['id'],n,k_,s_[0]));k_=None
            # 손 읽기 표(kana.json·kana_est.json)의 「node:이름」 열쇠도 이름 하나에 읽기 하나라, 같은 이름의 다른 곳 노드가 있으면 그 노드 읽기일 수 있다.
            # 같은 이름 노드·다른 열람 전용 역이 없거나 같은 곳(그 노선에 서거나 앞뒤 역 5 km 안)일 때만 쓴다
            # (志度線 東照宮前에 仙石線 東照宮前 n_toshogumae의 추정 읽기가 붙던 것, 13회차 2026-11-19. 같은 이름 함수가 아래에서 다시 정의되어
            #  위 ③ 같은 곳 판정이 늘 거짓이던 것도 _same_place_nm으로 고침)
            elif k_ and not ((not _NODEJA.get(znorm(n)) and not _arch_far(a,znorm(n))) or _same_place_nm(a,znorm(n))):
                NAMEKEY_DROP_A.append((a['id'],n,k_,s_[0]+'_other_place'));k_=None
            kana=k_
            if kana:AKSRC[a['id']]=s_[0]
        if kana:
            hk=kata2hira(kana);v=ko.NW.get(n+'|'+hk);t=v[0] if v else ko.station(hk,n)
            if v and v[1]=='namuwiki':src='namuwiki'   # 나무위키 제목이 있으면 규칙과 같아도 출처는 나무위키 (DESIGN §9.2)
    else:
        # 위키 노선도의 이름과 나무위키 표의 이름이 다른 노선
        nk=HT['WIKI_TITLE'].get(n,n)
        if nk in NLN:
            t=NLN[nk][0]
            if NLN[nk][1]=='namuwiki':src='namuwiki'
        elif n in conn.LABEL:t=conn.LABEL[n]
        else:
            # _add로 더한 노선은 행의 읽기를 먼저 쓴다
            kana=a.get('add_kana') or KANA.get('line:'+n) or KANA.get('node:'+n) or sdk.get('L'+znorm(n))
            if kana:t=ko.line(kata2hira(kana),n)
    t=HT['ARCH_KO'].get(n,t)
    # 사람이 넣은 행(archive_fix _add)인데 읽기 근거가 없으면 이름은 일본어 표기 그대로(ja_as_is)다. 읽기를 추정하지 않는다 (결정 132, 명세 결정 6).
    # 위키 노선도에서만 나온 읽기 없는 행은 사람이 확인하지 않아 그대로 뺀다
    # 읽기 근거가 없는 역도 빼지 않는다. 이름은 일본어 표기 그대로(ja_as_is), ID는 자리 ID(a_<노선>_<앞 역>_<뒤 역>, DESIGN §2.10)다
    # (사용자 결정 2026-11-16: 읽기가 없으면 한자 그대로 보이고, 읽기 근거 수집이 먼저다. 읽기가 없다고 옛 역을 DB에서 빼지 않는다. 예전 결정 132의 「위키 노선도에서만 온 읽기 없는 행은 뺀다」를 바꿈)
    if not t and a['kind']=='stop' and n:
        t=n;src='ja_as_is';a['_noread']=True
    # 앞뒤 역이 같으면(노선도 고리·옛 자리를 앞뒤로 읽은 것) 자리는 그 역 옆까지만 안다. 뒤 역을 비운다(감사 K24 after=before).
    # 읽기가 있는 행도 같다(5회차: 京急大師線 港町（旧）에 읽기가 붙자 이 규칙을 빠져나감)
    if a['kind']=='stop' and a.get('after') and a.get('after')==a.get('before'):a['before']=None
    if not t:drop.append(n);continue
    b={k:v for k,v in a.items() if k not in('name','add_kana','_fk2')}
    if b.pop('_late',None):LATE.add(b['id'])
    if b.pop('_spill',None):SPILL.add(b['id'])
    out.append(b)
    if fix.get('ko'):t=fix['ko'];src='hand'
    KA[a['id']]=kana or (a.get('add_kana') or KANA.get('line:'+n) or KANA.get('node:'+n) or sdk.get('L'+znorm(n)) if a['kind']=='line' else None)
    rows.append(dict(entity_type='archive',id=a['id'],lang='ja',text=n,kana=kana,source='wikipedia'))
    rows.append(dict(entity_type='archive',id=a['id'],lang='ko',text=t,source='ja_as_is' if a.get('_noread') else ('estimated' if ('node:'+n in GUESS or 'line:'+n in GUESS) else src),checked=TODAY))
    # 읽기 없는 행은 추정 읽기 목록(GUESS)에 이름이 있어도 한국어가 일본어 표기 그대로다(이름 열쇠 추정 읽기를 다른 곳 역 것이라 뺀 행, 13회차)
    if a.get('_noread'):rows.append(dict(entity_type='archive',id=a['id'],lang='en',text=n,source='ja_as_is'))
    # 읽기가 있는 열람 전용 역은 노드와 같은 규칙(en_rules.station_reading, 장음 기호 없는 헵번)으로 영어 이름을 단다. 없으면 앱이 일본어 표기로 보여
    # 영어 화면에서 열람 전용 역 대부분이 한자로 나왔다(839 중 영어 241, 그중 215는 일본어 그대로. 2026-11-18 사용자 지적)
    elif a['kind']=='stop' and kana:
        hk_=kata2hira(kana);e_=en_rules.station_reading(hk_,n);e_=en_rules.fix_station(n,hk_,e_,{}) or e_
        rows.append(dict(entity_type='archive',id=a['id'],lang='en',text=''.join(c for c in unicodedata.normalize('NFD',e_) if c!='\u0304'),source='estimated' if ('node:'+n in GUESS) else 'rule'))
    # 열람 전용 노선도 읽기가 있으면 노선 영어 이름 규칙(gen_en_names.line_name)으로 단다. 노선 138개가 한국어만 있고 영어가 없었다 (2026-11-18 사용자 지적)
    elif a['kind']=='line' and KA.get(a['id']):
        e_=line_name(n,kata2hira(KA[a['id']]),en=True)
        if e_:rows.append(dict(entity_type='archive',id=a['id'],lang='en',text=''.join(c for c in unicodedata.normalize('NFD',e_) if c!='\u0304'),source='estimated' if ('line:'+n in GUESS) else 'rule'))
# 열람 전용 ID는 영어 이름이다 (DESIGN §2.10). 읽기를 로마자로 옮기고, 겹치면 노선 이름, 그래도 겹치면 앞 역 이름을 붙인다
def slug(i):return re.sub(r'_line$','',re.sub(r'^[a-z]+_','',i or ''))
JA={r['id']:r['text'] for r in rows if r['lang']=='ja'}
NEW={};taken=set();nokana=[]
# 은퇴한 공개 ID(id_rename.json의 옛 ID: 개명·합침으로 redirect가 걸린 ID)는 다시 쓰지 않는다. 읽기 없는 역의 자리 ID나 겹침 접미사가
# 옛 ID로 돌아가면(志度線 東田町이 中野町의 옛 자리 ID a_shido_kawaramachi_takamatsu_kotohira를 가져감) redirect가 다른 역을 가리킨다 (2026-11-17)
taken|={r_['old'] for r_ in json.load(open(os.path.join(ROOT,'data','overrides','id_rename.json'),encoding='utf-8'))['rows'] if r_.get('old')}
# 읽기 근거가 없는 열람 전용 역(사람이 넣은 행)의 ID는 읽기 대신 자리로 정한다: a_<노선>_<앞 역>_<뒤 역> (앞뒤 역은 노드·열람 전용 ID에서 접두사를 뗀 영어 이름).
# 같은 두 역 사이에 그런 역이 여럿이면 노선 방향 순서대로 second·third…를 붙인다(숫자·해시는 쓰지 않는다, DESIGN §2.10). 열람 전용 노선의 역은 그 열람 전용 노선 ID가 노선 자리다
_ORD=['','second','third','fourth','fifth','sixth','seventh','eighth','ninth','tenth']
def _noread_id(b):
    ln_=slug(NEW.get(b.get('archive_line'),b.get('archive_line')) if b.get('archive_line') else b.get('line'))
    parts=[x for x in (ln_,slug(NEW.get(b.get('after'),b.get('after'))),slug(NEW.get(b.get('before'),b.get('before')))) if x]
    base='a_'+'_'.join(parts)
    for w in _ORD:
        c=base+('_'+w if w else '')
        if c not in taken:return c
    raise SystemExit(f'읽기 없는 열람 전용 역 ID를 정할 수 없습니다: {base}')
# 역은 노드처럼 읽기의 로마자, 노선은 노선 ID처럼 영어 이름 (gen_en_names의 규칙)
def _rbase(b,k):return 'a_'+(re.sub(r'[^a-z]+','_',unicodedata.normalize('NFKD',line_name(JA.get(b['id']),kata2hira(k))).encode('ascii','ignore').decode().lower()).strip('_') if b['kind']=='line' else romaji(k))
# 이미 낸 읽기 기반 ID는 지킨다. 같은 읽기의 역이 새로 읽기를 얻으면 노선 이름 순서로 밑자리를 빼앗았다
# (五日市線 武蔵上ノ原이 읽기를 얻자 青梅線 a_musashiuenohara가 a_musashiuenohara_ome로 밀림, 2026-11-18). 직전 커밋의 archive.yaml에서
# (종류, 노선, 일본어 이름)이 같고 지금 읽기의 밑자리로 시작하는 ID면 그 행에 먼저 준다. 깨끗한 체크아웃(생성 단계 없음)에는 영향이 없다
def _prev_ids():
    import subprocess
    def show(path):
        r_=subprocess.run(['git','-C',ROOT,'show','HEAD:data/source/'+path],capture_output=True)
        return r_.stdout.decode('utf-8') if r_.returncode==0 else ''
    ja_={};out_={}
    for ln_ in show('names/archive.yaml').splitlines():
        if ln_.startswith('- {') and '"lang": "ja"' in ln_:
            x_=json.loads(ln_[2:]);ja_[x_.get('entity_id') or x_.get('id')]=x_['text']
    for ln_ in show('archive/archive.yaml').splitlines():
        if ln_.startswith('- {'):
            x_=json.loads(ln_[2:]);key_=(x_['kind'],x_.get('archive_line') or x_.get('line'),ja_.get(x_['id']))
            out_.setdefault(key_,[]).append(x_['id'])
    return out_
PREV=_prev_ids()
for b in out:
    k=KA.get(b['id'])
    pids=PREV.get((b['kind'],b.get('archive_line') or b.get('line'),JA.get(b['id'])),())
    if k:
        base=_rbase(b,k)
        for pid in pids:
            if (pid==base or pid.startswith(base+'_')) and pid not in taken:taken.add(pid);NEW[b['id']]=pid;break
        # 읽기를 새로 얻은 역(직전엔 자리 ID)도 직전 ID를 지킨다. 손 표(archive_lines 등)가 그 ID를 열쇠로 쓰고, 읽기가 생겼다고 공개 ID가 바뀌면 안 된다 (13회차 2026-11-19)
        if b['id'] not in NEW:
            for pid in pids:
                if pid not in taken:taken.add(pid);NEW[b['id']]=pid;break
    elif b.get('_noread'):
        # 읽기 없는 역의 자리 ID(a_<노선>_<앞 역>_<뒤 역>_second…)도 지킨다. 같은 자리에 새 역이 들어오면 서수가 밀려 蛍川의 ID를
        # 다른 역이 받았다(西鉄 甘木線 宮の陣 앞, 12회차 M 2026-11-18 build_diff). 같은 (종류, 노선, 이름)의 직전 ID를 먼저 준다
        for pid in pids:
            if pid not in taken:taken.add(pid);NEW[b['id']]=pid;break
for b in sorted(out,key=lambda b:(b['id'] in LATE,b['kind'],b.get('line') or '',b.get('after') or '',b.get('seq') or 0,JA.get(b['id']) or '')):
    if b['id'] in NEW:continue
    k=KA.get(b['id'])
    if not k and b.get('_noread'):
        c=_noread_id(b);taken.add(c);NEW[b['id']]=c;continue
    if not k:nokana.append(JA.get(b['id']));continue
    base=_rbase(b,k);c=base
    # 열람 전용 노선의 역은 노선 칸이 비어 있어 그 열람 전용 노선 ID로 꼬리를 단다(大口線 天神前 ← 다른 天神前과 겹침, 12회차 M)
    for h in (slug(b.get('line') or b.get('archive_line')),slug(b.get('after') or b.get('at'))):
        if c not in taken:break
        if h:c=c+'_'+h
    if c in taken:raise SystemExit(f'열람 전용 ID가 겹칩니다: {c} ({JA.get(b["id"])})')
    taken.add(c);NEW[b['id']]=c
if nokana:raise SystemExit(f'읽기가 없어 열람 전용 ID를 만들 수 없습니다 ({len(nokana)}): {nokana}. data/overrides/kana_est.json에 읽기를 넣으세요')
# 같은 자리 열람 전용 역의 순서 단서 wiki_row = [노선, 부호 붙은 노선도 행 번호]. 그 노선 노선도(gen_wiki 보고서 wiki_rows.json)에서 같은 이름 역 꼴 행을 찾고
# (같은 이름이 여럿이면 앞뒤 역 행에 가장 가까운 것), 앞 역 행에서 뒤 역 행 쪽으로 갈 때 번호가 커지면 +, 작아지면 −를 붙인다. 그래서 값이 작을수록 앞 역(after) 쪽이다.
# 위키 행에서 나온 역과 손 행(_add·_noyear)이 같은 규칙을 탄다. 앞뒤 역이 노선도에 없거나 이름 행이 없으면 비운다. compile이 이것으로 계통 위 열람 전용 역 seq를 정한다 (2026-11-17 志度線 瓦町 앞)
_wp=os.path.join(CAND,'wiki_rows.json');WROWS=json.load(open(_wp,encoding='utf-8')) if os.path.exists(_wp) else {}
def _wiki_row(b):
    W=WROWS.get(b.get('line'))
    if not W or b.get('archive_line'):return None
    nm=znorm(JA.get(b['id']) or '');rows_=[i for i,x in W['s'] if x==nm]
    if not rows_:return None
    nr=collections.defaultdict(list)
    for i,x in W['n']:nr[x].append(i)
    for k_,sg in (('after',1),('before',-1)):
        if b.get(k_) not in nr:continue
        i_,j_=min(((i,j) for i in rows_ for j in nr[b[k_]]),key=lambda p:abs(p[0]-p[1]))
        return [b['line'],i_ if (i_-j_)*sg>0 else -i_]
    return None
for b in out:
    if b['kind']=='stop' and (w_:=_wiki_row(b)):b['wiki_row']=w_
out=[b for b in out if b['id'] not in SPILL];rows=[r for r in rows if r['id'] not in SPILL]
for b in out:
    for k in ('after','before','archive_line'):
        if b.get(k) in NEW:b[k]=NEW[b[k]]
    b.pop('_noread',None)
    b['id']=NEW[b['id']]
for r in rows:r['id']=NEW[r['id']]
for f in os.listdir(os.path.join(SRC,'archive')):os.remove(os.path.join(SRC,'archive',f))
dump('archive/archive.yaml',out,'열람 전용 역·노선')
dump('names/archive.yaml',rows,'열람 전용 이름')
os.makedirs(CAND,exist_ok=True)
json.dump(drop,open(os.path.join(CAND,'archive_noname.json'),'w',encoding='utf-8'),ensure_ascii=False)
print('열람 전용',len(out),'이름 없어 뺌',len(drop),drop[:30])
print('열람 전용 이름 열쇠 읽기 뺌(다른 역 읽기)',len(NAMEKEY_DROP_A))
json.dump(sorted(NAMEKEY_DROP_A),open(os.path.join(CAND,'archive_namekey_drop.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=0)
json.dump(AKSRC,open(os.path.join(CAND,'archive_kana_src.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=0,sort_keys=True)
