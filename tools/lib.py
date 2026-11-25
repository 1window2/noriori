# -*- coding: utf-8 -*-
# noriori 데이터 파이프라인 공용 함수
import json,os,re,unicodedata,hashlib
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC=os.path.join(ROOT,'data','source')
IMP=os.path.join(ROOT,'data','imports')
CAND=os.path.join(ROOT,'data','candidates')
BUILD=os.path.join(ROOT,'build')
# 이 판의 기준일. 실행한 날에 따라 값이 달라지지 않게 입력으로 둔다. 새 판을 낼 때 손으로 올린다
AS_OF=json.load(open(os.path.join(ROOT,'data','overrides','as_of.json'),encoding='utf-8'))['as_of']
# 출처 스위치 (data/sources.json). 뼈대 출처를 끄면 멈춘다
SOURCES=json.load(open(os.path.join(ROOT,'data','sources.json'),encoding='utf-8'))['sources']
for _k,_v in SOURCES.items():
    if _v.get('required') and not _v['on']:raise SystemExit(f'뼈대 출처 {_k}는 끌 수 없습니다. 대체 출처를 마련한 뒤 data/sources.json에서 required를 고치세요')
def source_on(k):return SOURCES[k]['on']
# 손으로 적은 보정 표. 표마다 설명과 값이 있다
HT={k:v['값'] for k,v in json.load(open(os.path.join(ROOT,'data','overrides','hand_tables.json'),encoding='utf-8'))['tables'].items()}
# 판 번호. 앱은 같은 판이면 받아 둔 팩을 그대로 쓰므로, 값이 바뀌면 반드시 올린다
EDITION=json.load(open(os.path.join(ROOT,'data','overrides','as_of.json'),encoding='utf-8'))['edition']

def znorm(n):
    """이름 대조용 정규화. 역·노선 이름의 표기 차이만 지운다"""
    n=unicodedata.normalize('NFKC',n or '').strip()
    n=re.sub(r'[（(]旧.*?[)）]','',n)
    n=re.sub(r'[〈<(（].*?[〉>)）]','',n)
    n=n.split('/')[0].split('／')[0]
    n=n.replace('ヶ','ケ').replace('ヵ','ケ').replace('ｹ','ケ').replace('之','ノ').replace('﨑','崎').replace('髙','高').replace('塚','塚').replace('槇','槙').replace('渕','淵').replace('澤','沢').replace('濱','浜').replace('瀧','滝').replace('條','条').replace('龍','竜').replace('驛','駅').replace('國','国').replace('會','会').replace('櫻','桜').replace('廣','広').replace('德','徳').replace('諌','諫').replace('萠','萌')
    n=n.replace('【旧】','')
    n=re.sub(r'([一二三四五六七八九])丁目',lambda m:str('一二三四五六七八九'.index(m.group(1))+1)+'丁目',n)
    n=re.sub(r'\s+','',n)
    if len(n)>1 and n.endswith('駅'):n=n[:-1]
    return n

ROMA={}
def _r():
    t='''あa いi うu えe おo かka きki くku けke こko さsa しshi すsu せse そso たta ちchi つtsu てte とto なna にni ぬnu ねne のno はha ひhi ふfu へhe ほho まma みmi むmu めme もmo やya ゆyu よyo らra りri るru れre ろro わwa をo んn がga ぎgi ぐgu げge ごgo ざza じji ずzu ぜze ぞzo だda ぢji づzu でde どdo ばba びbi ぶbu べbe ぼbo ぱpa ぴpi ぷpu ぺpe ぽpo ぁa ぃi ぅu ぇe ぉo ゃya ゅyu ょyo ゎwa'''
    for x in t.split():ROMA[x[0]]=x[1:]
    for a,b in (('きゃ','kya'),('きゅ','kyu'),('きょ','kyo'),('しゃ','sha'),('しゅ','shu'),('しょ','sho'),('ちゃ','cha'),('ちゅ','chu'),('ちょ','cho'),('にゃ','nya'),('にゅ','nyu'),('にょ','nyo'),('ひゃ','hya'),('ひゅ','hyu'),('ひょ','hyo'),('みゃ','mya'),('みゅ','myu'),('みょ','myo'),('りゃ','rya'),('りゅ','ryu'),('りょ','ryo'),('ぎゃ','gya'),('ぎゅ','gyu'),('ぎょ','gyo'),('じゃ','ja'),('じゅ','ju'),('じょ','jo'),('ぢゃ','ja'),('ぢゅ','ju'),('ぢょ','jo'),('びゃ','bya'),('びゅ','byu'),('びょ','byo'),('ぴゃ','pya'),('ぴゅ','pyu'),('ぴょ','pyo'),('ふぁ','fa'),('ふぃ','fi'),('ふぇ','fe'),('ふぉ','fo'),('てぃ','ti'),('でぃ','di'),('うぃ','wi'),('うぇ','we'),('うぉ','wo'),('しぇ','she'),('じぇ','je'),('ちぇ','che')):ROMA[a]=b
_r()
def kata2hira(k):
    return ''.join(chr(ord(c)-0x60) if 'ァ'<=c<='ヶ' else c for c in k)
def romaji(k):
    k=kata2hira(unicodedata.normalize('NFKC',k or ''))
    k=re.sub(r'[（(].*?[)）]','',k)
    o=[];i=0;sok=False
    while i<len(k):
        c=k[i]
        if c=='っ':sok=True;i+=1;continue
        if c=='ー':i+=1;continue
        s=k[i:i+2]
        if s in ROMA:r=ROMA[s];i+=2
        elif c in ROMA:r=ROMA[c];i+=1
        else:
            i+=1
            if c.isascii() and c.isalnum():r=c.lower()
            else:continue
        if sok and r:r=('t' if r.startswith('ch') else r[0])+r;sok=False
        o.append(r)
    return ''.join(o)

def edtf(d):
    """노리츠부시·위키 날짜 표기를 EDTF로. 모르면 None"""
    if not d:return None
    d=unicodedata.normalize('NFKC',str(d)).strip()
    if d in('','NULL','null','0000-00-00','?'):return None
    if re.match(r'^\d{4}-(\d\d|XX)-(\d\d|XX)$',d) and 'X' in d:return d
    # 손 대조 표의 범위 날짜(士別軌道 여객 끝 1955年度 [1955-04-01..1956-03-31])는 그대로 둔다
    if re.match(r'^\[\d{4}-\d\d-\d\d\.\.\d{4}-\d\d-\d\d\]$',d):return d
    m=re.match(r'^(\d{4})-(\d{2})-(\d{2})',d)
    if m:
        y,mo,da=m.groups()
        if mo=='00':return f'{y}-XX-XX'
        if da=='00':return f'{y}-{mo}-XX'
        return f'{y}-{mo}-{da}'
    m=re.match(r'^(\d{4})-(\d{2})$',d)
    if m:return f'{m.group(1)}-{m.group(2)}-XX'
    m=re.match(r'^(\d{4})$',d)
    if m:return f'{d}-XX-XX'
    return None
def _dim(y,m):
    """그달의 날 수. 평년 2월은 28일"""
    if m==2:return 29 if (y%4==0 and (y%100!=0 or y%400==0)) else 28
    return [31,28,31,30,31,30,31,31,30,31,30,31][m-1]
_RANGE=re.compile(r'^\[(.*)\.\.(.*)\]$')
def lohi(e):
    """EDTF를 (가장 이른 날, 가장 늦은 날)로. None은 (None,None), ongoing은 ('9999-12-31',)*2.
    하루·달·해·10년·100년(1955-04-01, 1955-04-XX, 1955-XX-XX, 195X-XX-XX, 19XX-XX-XX)과
    그 사이 어느 날인지 모르는 범위 [A..B]·[..B]·[A..]를 받는다 (EDTF 「하나의 값」 표기)"""
    if e is None:return (None,None)
    if e=='ongoing':return ('9999-12-31','9999-12-31')
    m=_RANGE.match(e)
    if m:
        a,b=m.groups()
        lo=lohi(a)[0] if a else '0000-01-01'
        hi=lohi(b)[1] if b else '9999-12-31'
        if lo>hi:raise ValueError(f'날짜 범위가 거꾸로: {e}')
        return (lo,hi)
    # 원 자료의 해 모름(XXXX)은 생성기가 받아 쓰도록 「아무 때나」로 읽는다. 출력 DB에는 남지 않는다 (compile check_dates)
    if e.startswith('XXXX'):return ('0000-01-01','9999-12-31')
    if not re.match(r'^(\d{4}|\d{3}X|\d{2}XX)-(\d\d|XX)-(\d\d|XX)$',e):raise ValueError(f'EDTF 해석 불가: {e}')
    y,m,d=e.split('-')
    if 'X' in y:
        if m!='XX' or d!='XX':raise ValueError(f'EDTF 해석 불가: {e}')
        a=y.replace('X','0');b=y.replace('X','9');return (f'{a}-01-01',f'{b}-12-31')
    if m=='XX':
        if d!='XX':raise ValueError(f'EDTF 해석 불가: {e}')
        return (f'{y}-01-01',f'{y}-12-31')
    if not 1<=int(m)<=12:raise ValueError(f'달이 아님: {e}')
    if d=='XX':return (f'{y}-{m}-01',f'{y}-{m}-{_dim(int(y),int(m)):02d}')
    if not 1<=int(d)<=_dim(int(y),int(m)):raise ValueError(f'날이 아님: {e}')
    return (e,e)

def year_status(valid_from,valid_to,y):
    """Y년 분모 판정 (DESIGN §5.4). 'yes' 확실히 영업, 'unknown' 판정 불가, None 영업 안 함.
    애매한 단위는 분모·분자 모두에서 빼고 판정 불가로 센다. 폐지 연도만 아는 구간은 그해에 영업한 것으로 친다"""
    f_lo,f_hi=lohi(valid_from);t_lo,t_hi=lohi(valid_to)
    a,b=f'{y}-01-01',f'{y+1}-01-01'
    if not((f_lo or '0000-01-01')<b and (t_hi or '9999-12-31')>a):return None
    if f_hi is not None and f_hi<b and t_lo is not None and t_hi>a and t_lo>=a:return 'yes'
    return 'unknown'

def dump(path,items,head=None):
    """YAML의 부분집합으로 쓴다: 항목마다 JSON 흐름 표기 한 줄"""
    p=os.path.join(SRC,path);os.makedirs(os.path.dirname(p),exist_ok=True)
    with open(p,'w',encoding='utf-8') as o:
        if head:o.write('# '+head+'\n')
        for x in items:o.write('- '+json.dumps(x,ensure_ascii=False,separators=(', ',': '))+'\n')
def _rows(d):
    r=[]
    if not os.path.isdir(d):return r
    for f in sorted(os.listdir(d)):
        if not f.endswith('.yaml'):continue
        for l in open(os.path.join(d,f),encoding='utf-8'):
            if l.startswith('- '):r.append(json.loads(l[2:]))
    return r
# 생성(gen_*)이 놓친 값을 원천에서 다시 찾아 둔 보정. data/source는 재생성 때 비워지므로 overrides에 둔다.
# 선형은 원본에 없는 edge만 채우고, 좌표는 그 노드의 원본 값을 바꾼다. 출처를 끄면 빠진다 (DESIGN §2.10)
_FILL={'geometry':('edge','source',{'N05-24':'n05'}),'positions':('node','source',{'n05':'n05'})}
# 원본과 같은 형식의 보정 행 (data/overrides/source_patch/<모듈>.yaml). 생성기를 돌릴 수 없을 때 생성기가 만들었어야 할 행을 넣는다.
# 행마다 "patch": "add"(그 키가 원본에 없어야 함), "replace"(있어야 함) 또는 "drop"(있어야 함, 그 행을 뺀다). 어긋나면 멈춘다: 재생성으로 원본에 생긴 행은 지우라는 뜻이다.
# 이름은 한 개체·언어에 노선별·기간별 행이 여럿이라 노선·기간까지 키로 본다(그래야 노선 전용 이름 행 하나만 더하거나 뺄 수 있다). drop은 생성기 표가 잘못 낸 행(노리츠부시 표 오기)을 뺄 때만 쓴다
_PATCH_KEY={'operators':'id','groups':'id','edges':'id','nodes':'id','routes':'id','lines':'id','km':'edge','positions':'node','geometry':'edge','events':None,'names':('entity_type','id','lang','line','valid_from','valid_to'),'aliases':('entity_type','id','lang','text','kind'),'stops':None}
def _patch(mod,r):
    rows=_rows(os.path.join(ROOT,'data','overrides','source_patch',mod))
    # 보정 행은 다 만든 원본에 얹는 컴파일 단계용이다. 생성 도중(NORIORI_GEN, tools/all.sh)에는 영어 이름처럼 아직 없는 원본이 있고,
    # 새 ID 모드(NORIORI_NEW_IDS=1)의 원본은 내부 키라 공개 ID로 쓴 행이 맞지 않는다. 둘 다 마지막 컴파일에서 합친다
    if not rows or os.environ.get('NORIORI_NEW_IDS') or os.environ.get('NORIORI_GEN'):return r
    key=_PATCH_KEY[mod];k=(lambda x:tuple(x.get(f) for f in key)) if isinstance(key,tuple) else (lambda x:x[key])
    have={k(x):i for i,x in enumerate(r)} if key else {}
    added={};drop=set()
    for x in rows:
        x=dict(x);op=x.pop('patch');x.pop('why',None)
        if op=='add':
            if key and k(x) in have:raise SystemExit(f'source_patch/{mod}: {k(x)}가 원본에 이미 있습니다. 보정 행을 지우세요')
            # 다른 보정 파일이 같은 번호로 이미 더했으면 멈춘다(秋田 분기점 칸이 田端 칸 e_097201과 겹쳐 조용히 덮였음, 5회차 2026-11-26).
            # 같은 키에 기간 행이 여럿인 이름·별칭 표는 키가 겹쳐도 정상이다
            if key and isinstance(key,str) and k(x) in added:raise SystemExit(f'source_patch/{mod}: {k(x)}를 두 보정 행이 더합니다. 번호를 바꾸세요')
            r.append(x)
            # 앞 파일이 더한 행을 뒤 파일이 replace로 고칠 수 있게 따로 적어 둔다 (옛 선로 칸의 km를 근거 조사로 고침).
            # 더하기 겹침 검사는 원본만 본다. 이름처럼 같은 키에 기간 행이 여럿인 표가 있다
            if key:added[k(x)]=len(r)-1
        elif op=='replace':
            if not key or (k(x) not in have and k(x) not in added):raise SystemExit(f'source_patch/{mod}: {k(x) if key else x}가 원본에 없습니다')
            r[have[k(x)] if k(x) in have else added[k(x)]]=x
        elif op=='drop':
            if not key or k(x) not in have:raise SystemExit(f'source_patch/{mod}: 뺄 {k(x) if key else x}가 원본에 없습니다')
            drop.add(have[k(x)])
        else:raise SystemExit(f'source_patch/{mod}: patch는 add·replace·drop')
    return [x for i,x in enumerate(r) if i not in drop] if drop else r
def load(mod):
    """모듈 폴더의 모든 .yaml을 항목 목록으로 읽는다. 선형·좌표는 overrides의 보정을 더한다"""
    r=_patch(mod,_rows(os.path.join(SRC,mod))) if mod in _PATCH_KEY else _rows(os.path.join(SRC,mod))
    if mod in _FILL:
        key,tag,src=_FILL[mod]
        fill=[x for x in _rows(os.path.join(ROOT,'data','overrides',mod)) if source_on(src.get(x.get(tag),x.get(tag)))]
        if mod=='geometry':
            have={x[key] for x in r}
            r+=[x for x in fill if x[key] not in have]
        else:
            by={x[key]:x for x in fill}
            r=[by.pop(x[key],x) for x in r]+list(by.values())
    return r
def load_geo():
    """master.sqlite, rail.pmtiles에 넣는 선형. OSM 선형은 ODbL이라 빠진다 (설계 §2.11)"""
    return [g for g in load('geometry') if g.get('source')!='osm']
def stable(*a):
    return hashlib.md5('|'.join(map(str,a)).encode()).hexdigest()[:8]

def official(rows):
    """노리츠부시 표를 공식 노선 구성으로 바꾼다 (data/overrides/official_lines.json, 사용자 결정 2026-11-09).
    노리츠부시가 『鉄道要覧』과 다르게 나눈 노선(副都心線 和光市–小竹向原 등)을 법적 소속대로 다시 쓴다. 쓰이지 않는 행은 멈춘다"""
    OF=json.load(open(os.path.join(ROOT,'data','overrides','official_lines.json'),encoding='utf-8'))['rows']
    by={r['id']:i for i,r in enumerate(rows)}
    drop=set()
    for x in OF:
        if x['op']=='add':
            if x['set']['id'] in by:raise SystemExit(f"official_lines: {x['set']['id']}가 이미 있습니다")
            rows.append(dict(x['set']));continue
        if x['id'] not in by:raise SystemExit(f"official_lines: 노리츠부시 표에 {x['id']}가 없습니다")
        if x['op']=='replace':rows[by[x['id']]]=dict(rows[by[x['id']]],**x['set'])
        elif x['op']=='drop':drop.add(x['id'])
        else:raise SystemExit(f"official_lines: op는 replace·drop·add")
    return [r for r in rows if r['id'] not in drop]
def hidden_insert(rows):
    """노리츠부시 표에 정차하지 않는 분기점을 km 자리에 숨은 역([이름])으로 넣는다 (hand_tables HIDDEN_INSERT)"""
    for t,name,k,_ in HT['HIDDEN_INSERT']:
        for r in rows:
            if not r['t'].startswith(t) or any(s[0].strip('[]')==name for s in r['s']):continue
            i=next((i for i,s in enumerate(r['s']) if float(s[1])>k),len(r['s']))
            r['s'].insert(i,['['+name+']',str(k) if isinstance(r['s'][0][1],str) else k])
    return rows
