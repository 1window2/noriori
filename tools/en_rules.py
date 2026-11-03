# -*- coding: utf-8 -*-
# 영어 이름의 공용 규칙 (DESIGN §9.1). gen_source.py(역)와 gen_en_names.py(노선·사업자)가 함께 쓴다.
# 사람이 정한 값은 data/overrides/en_fix.json이다. 규칙으로 안 되는 이름만 넣고 항목마다 이유를 적는다.
import json,os,re,unicodedata
from lib import ROMA,ROOT,kata2hira,romaji

def load_fix():
    return json.load(open(os.path.join(ROOT,'data','overrides','en_fix.json'),encoding='utf-8'))

# 훈독 낱말의 첫 글자. 長音처럼 보여도 앞 글자와 다른 낱말이라 줄이면 안 된다 (丸ノ内, 松浦, 箕面)
WORD_START={'内':'うち','浦':'うら','牛':'うし','魚':'うお','海':'うみ','尾':'お','箕面':'お'}
# 宇는 う 한 글자라 앞이 う 줄이면 구별되지 않는다 (陸中宇部, 由宇)
AFTER_O='おこそとのほもよろごぞどぼぽょ'
# 한 낱말로 읽는 말. 앞 표의 한자가 있어도 장음이다
ONE_WORD=('青海','神海','河内')

def mark_words(kana,ja):
    """일본어 이름을 보고 읽기에 낱말 경계 |를 넣는다"""
    if not ja or any(w in ja for w in ONE_WORD):return kana
    if '宇' in ja:kana=re.sub(f'(?<=[{AFTER_O}])う(?=[じつわみべ])','|う',kana)
    for kanji,read in WORD_START.items():
        if kanji not in ja:continue
        after=ja[ja.index(kanji)+len(kanji):]
        def cut(m):
            # 한자 뒤의 글자 수와 읽기 뒤의 글자 수가 맞아야 그 한자의 읽기다 (雄鎮内의 ゆうちんない는 아니다)
            tail=len(m.string)-m.end()
            return '|'+read if (tail>=len(after) if after else tail==0) else read
        kana=re.sub(f'(?<=[{AFTER_O}うくすつぬふむゆるぐずづぶぷゅ])'+read,cut,kana)
    return kana

def contract(kana,ja=None):
    """장음을 줄인다. 낱말 경계는 넘지 않는다"""
    k=mark_words(kata2hira(unicodedata.normalize('NFKC',kana)),ja)
    k=re.sub('([おこそとのほもよろごぞどぼぽょ])[うお]',r'\1',k)
    return re.sub('([うくすつぬふむゆるぐずづぶぷゅ])う',r'\1',k).replace('|','')

def hepburn(kana,ja=None):
    k=contract(kana,ja)
    o=[];i=0;sok=False
    while i<len(k):
        c=k[i]
        if c=='っ':sok=True;i+=1;continue
        if c=='ー':i+=1;continue
        pair=k[i:i+2]
        if pair in ROMA:r=ROMA[pair];i+=2
        elif c in ROMA:r=ROMA[c];i+=1
        else:i+=1;continue
        if sok and r:r=('t' if r.startswith('ch') else r[0])+r;sok=False
        # ん 뒤의 모음은 끊어 읽는다
        if o and o[-1]=='n' and r[0] in 'aiueoy':r="'"+r
        # ん은 b, p, m 앞에서 m이다
        if o and o[-1]=='n' and r[0] in 'bpm':o[-1]='m'
        o.append(r)
    return ''.join(o)

def station_reading(kana,ja=None):
    """역 이름의 규칙 표기. 낱말 하나로 붙여 쓴다"""
    return romaji(contract(kana,ja)).title()

# 가타카나 외래어. 읽기대로 옮기면 Keburu, Monoreru가 된다. 긴 낱말이 먼저다
KATAKANA={
    'オークスカナルパークホテル':'Oaks Canal Park Hotel','デンテツターミナルビル':'Dentetsu Terminal Building',
    'イングリッシュガーデン':'English Garden','グリーンスタジアム':'Green Stadium','クルーズターミナル':'Cruise Terminal',
    'スタジアムシティサウス':'Stadium City South','スタジアムシティノース':'Stadium City North','メディカルセンター':'Medical Center',
    'グランドプラザ':'Grand Plaza','ロープウェイ':'Ropeway','パークタウン':'Park Town','ターミナル':'Terminal','モノレール':'Monorail',
    'キャンパス':'Campus','ハイランド':'Highland','クロスベイ':'Cross Bay','センター':'Center','ケーブル':'Cable','トンネル':'Tunnel',
    'インテック':'Intec','アパート':'Apartment','アリーナ':'Arena','ドーム':'Dome',
    'モール':'Mall','アート':'Art','アスモ':'Asmo','エスタ':'Esta','ビル':'Building','ダム':'Dam','ベル':'Bell',
}
KATA_WORDS=sorted(KATAKANA,key=len,reverse=True)
# 외래어 뒤에 붙는 말
TAILS=(('入口','いりぐち','-iriguchi'),('前','まえ','-mae'),('下','した','-shita'),('口','ぐち','-guchi'),('通り','どおり','-dori'),('通','どおり','-dori'))
# 앞이 이 글자로 시작하는 역은 하이픈으로 뗀다 (Higashi-Ogu). 두 글자 지명의 일부는 뺀다 (新潟, 東京, 西宮, 北上, 南部)
PREFIX=(('東','ひがし','Higashi'),('西','にし','Nishi'),('南','みなみ','Minami'),('北','きた','Kita'),('新','しん','Shin'))

def plainkana(kana):
    return re.sub(r'[（(].*?[)）]','',kata2hira(unicodedata.normalize('NFKC',kana or ''))).replace(' ','')

def plainja(ja):
    return re.sub(r'[（(].*?[)）]','',unicodedata.normalize('NFKC',ja or '')).strip()

def place(ja,kana,known):
    """지명 부분의 영어. 같은 한자·같은 읽기의 역이 있으면 그 이름을 쓴다"""
    if not ja:return ''
    if (ja,kana) in known:return known[(ja,kana)]
    for mark,read,en in PREFIX:
        rest=ja[len(mark):];tail=kana[len(read):]
        if ja.startswith(mark) and kana.startswith(read) and len(rest)>=2 and rest[0] not in 'ヶケノの':
            return f"{en}-{known.get((rest,tail)) or station_reading(tail,rest)}"
    return station_reading(kana,ja)

NUM={'一':1,'二':2,'三':3,'四':4,'五':5,'六':6,'七':7,'八':8,'九':9}
def number(text):
    if text.isdigit():return int(text)
    if '十' in text:
        a,b=text.split('十');return (NUM.get(a,1))*10+NUM.get(b,0)
    return NUM[text]

CHOME=re.compile(r'^(.*?)(\d+|[一二三四五六七八九十]+)丁目$')
CHOME_READ=re.compile('(?:(?:に|さん)?じゅう)?(?:いっ|に|さん|よん|ご|ろく|なな|はっ|きゅう|じっ|じゅっ)?ちょうめ$')
EKIMAE=re.compile(r'^(JR)?(.*?)駅前(大通|通)?$')
TERMINAL=re.compile(r'^(.*)空港第(\d)(?:・第(\d))?ターミナル$')

def chome(ja,kana,known):
    m=CHOME.match(ja)
    return m and f"{place(m.group(1),CHOME_READ.sub('',kana),known)} {number(m.group(2))}-chome"

def ekimae(ja,kana,known):
    m=EKIMAE.match(ja)
    if not m:return None
    jr,base,tail=m.groups()
    read=re.sub('(じぇいあーる)|(えきまえ(おお)?(どおり)?$)','',kana)
    head=place(base,read,known)
    name=f"{head}-Ekimae" if head else 'Ekimae'
    if jr:name='JR '+name
    return name+{'大通':'-Odori','通':'-dori',None:''}[tail]

def terminal(ja,kana,known):
    m=TERMINAL.match(ja)
    if not m:return None
    head=place(m.group(1),kana[:kana.index('くうこう')],known)
    return f"{head} Airport Terminal {m.group(2)}"+(f"·{m.group(3)}" if m.group(3) else '')

def katakana(ja,kana,known,text):
    """외래어를 영어로 바꾸고 앞뒤는 읽기대로 적는다. 라벨이 이미 영어로 적었으면 건드리지 않는다"""
    word=next((w for w in KATA_WORDS if w in ja),None)
    if not word:return None
    read=kata2hira(word)
    if read not in kana:return None
    if re.sub('[^a-z]','',hepburn(read)) not in re.sub('[^a-z]','',text.lower()):return None
    left_ja,right_ja=ja.split(word,1);left,right=kana.split(read,1)
    head=place(left_ja,left,known)
    name=f'{head} {KATAKANA[word]}'.strip()
    if right_ja:
        tail=next((en for t,r,en in TAILS if right_ja==t and right==r),None)
        if tail:name+=tail
        elif right_ja.endswith('前') and right.endswith('まえ'):name+=f" {place(right_ja[:-1],right[:-2],known)}-mae"
        else:name+=' '+place(right_ja,right,known)
    return name

def fix_station(ja,kana,text,known,keep=()):
    """역 영어 이름 규칙. ekimae, chome, 공항 터미널, 외래어 순서다. 해당 없으면 None"""
    ja=plainja(ja);kana=plainkana(kana)
    if not kana:return None
    if chome(ja,kana,known) and text in keep:return None
    return chome(ja,kana,known) or ekimae(ja,kana,known) or terminal(ja,kana,known) or katakana(ja,kana,known,text)

def fix_nodes(names):
    """gen_source.py가 일본어와 읽기를 확정한 뒤 부른다. en 행의 글자만 바꾼다 (행 순서는 그대로)"""
    fix=load_fix();nodefix=fix['node'];keep=set(fix['chome_official'])
    ja={};kana={}
    for x in names:
        if x['entity_type']!='node' or x['lang']!='ja' or x.get('line') or x.get('valid_to'):continue
        if x['id'] not in ja:ja[x['id']]=x['text'];kana[x['id']]=plainkana(x.get('kana'))
    rows=[x for x in names if x['entity_type']=='node' and x['lang']=='en']
    # 규칙 이름은 확정된 읽기로 다시 만든다. node_fix.json이 읽기를 고치기 전에 만든 값이 남아 있다
    for x in rows:
        if x['source']=='rule' and kana.get(x['id']):x['text']=station_reading(kana[x['id']],plainja(ja[x['id']]))
    # 다른 역 이름의 바탕. 어절이 나뉜 표기만 믿는다
    known={}
    for x in rows:
        if x['source']!='rule' and x['id'] not in nodefix and ('-' in x['text'] or ' ' in x['text'] or len(x['text'])<13):
            known.setdefault((plainja(ja[x['id']]),kana[x['id']]),x['text'])
    known.update({tuple(k.split('|')):v['en'] for k,v in fix['base'].items()})
    for x in rows:
        i=x['id']
        if i in nodefix:x['text']=nodefix[i]['en'];x['source']='hand';continue
        if x['source']=='hand' or i not in ja:continue
        made=fix_station(ja[i],kana[i],x['text'],known,keep)
        if made:x['text']=made;x['source']='rule'
