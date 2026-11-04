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
    n=n.replace('ヶ','ケ').replace('ヵ','ケ').replace('ｹ','ケ').replace('之','ノ').replace('﨑','崎').replace('髙','高').replace('塚','塚').replace('槇','槙').replace('渕','淵').replace('澤','沢').replace('濱','浜').replace('瀧','滝').replace('條','条').replace('龍','竜').replace('驛','駅').replace('國','国').replace('會','会').replace('櫻','桜').replace('廣','広').replace('德','徳').replace('諌','諫')
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
DIM=[31,29,31,30,31,30,31,31,30,31,30,31]
def lohi(e):
    """EDTF를 (가장 이른 날, 가장 늦은 날)로. None은 (None,None), ongoing은 ('9999-12-31',)*2"""
    if e is None:return (None,None)
    if e=='ongoing':return ('9999-12-31','9999-12-31')
    y,m,d=e.split('-')
    if 'X' in y:
        a=y.replace('X','0');b=y.replace('X','9');return (f'{a}-01-01',f'{b}-12-31')
    if m=='XX':return (f'{y}-01-01',f'{y}-12-31')
    if d=='XX':return (f'{y}-{m}-01',f'{y}-{m}-{DIM[int(m)-1]:02d}')
    return (e,e)

def dump(path,items,head=None):
    """YAML의 부분집합으로 쓴다: 항목마다 JSON 흐름 표기 한 줄"""
    p=os.path.join(SRC,path);os.makedirs(os.path.dirname(p),exist_ok=True)
    with open(p,'w',encoding='utf-8') as o:
        if head:o.write('# '+head+'\n')
        for x in items:o.write('- '+json.dumps(x,ensure_ascii=False,separators=(', ',': '))+'\n')
def load(mod):
    """모듈 폴더의 모든 .yaml을 항목 목록으로 읽는다"""
    r=[];d=os.path.join(SRC,mod)
    if not os.path.isdir(d):return r
    for f in sorted(os.listdir(d)):
        if not f.endswith('.yaml'):continue
        for l in open(os.path.join(d,f),encoding='utf-8'):
            if l.startswith('- '):r.append(json.loads(l[2:]))
    return r
def load_geo():
    """master.sqlite, rail.pmtiles에 넣는 선형. OSM 선형은 ODbL이라 빠진다 (설계 §2.11)"""
    return [g for g in load('geometry') if g.get('source')!='osm']
def stable(*a):
    return hashlib.md5('|'.join(map(str,a)).encode()).hexdigest()[:8]
