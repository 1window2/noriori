# -*- coding: utf-8 -*-
# 영어 이름의 공용 규칙 (DESIGN §9.1). gen_source.py(역)와 gen_en_names.py(노선·사업자)가 함께 쓴다.
# 사람이 정한 값은 data/overrides/en_fix.json이다. 규칙으로 안 되는 이름만 넣고 항목마다 이유를 적는다.
import json,os,re,unicodedata
from lib import ROMA,ROOT,kata2hira,romaji

def load_fix():
    return json.load(open(os.path.join(ROOT,'data','overrides','en_fix.json'),encoding='utf-8'))

def load_official():
    """현행 역 공식 영어 이름 {노드: {en, source, type}} (data/overrides/en_official.json, 5회차)"""
    p_=os.path.join(ROOT,'data','overrides','en_official.json')
    if not os.path.exists(p_):return {}
    rows=json.load(open(p_,encoding='utf-8'))['rows']
    return {k:dict(v,en=norm_official(v['en'])) for k,v in rows.items()}

def load_jawiki():
    """공식이 없는 역의 일본어 위키백과 정보칸 로마자 {노드: {en, title, revid}} (data/overrides/en_jawiki.json, 5회차 2026-11-25)"""
    p_=os.path.join(ROOT,'data','overrides','en_jawiki.json')
    if not os.path.exists(p_):return {}
    return {k:dict(v,en=norm_official(v['en'])) for k,v in json.load(open(p_,encoding='utf-8'))['rows'].items()}

def norm_official(s):
    """공식 자료에서 옮긴 글자 흔적을 고친다: 전각 글자, 굽은 따옴표(ROYCE’), 가운뎃점(Ōmori・Kinjōgakuin-mae),
    낱말 가운데 대문자 장음 기호(KyŪkan). 장음 기호 자체는 공식대로 둔다"""
    s=''.join(unicodedata.normalize('NFKC',c) if c not in '・' and unicodedata.east_asian_width(c)=='F' else c for c in s)
    s=s.replace('’',"'").replace('‘',"'").replace('・','-').replace('·','-')
    return re.sub('(?<=[a-zāīūēō])[ĀĪŪĒŌ]',lambda m:m.group(0).lower(),s)

# 훈독 낱말의 첫 글자. 長音처럼 보여도 앞 글자와 다른 낱말이라 줄이면 안 된다 (丸ノ内, 松浦, 箕面)
BOTH_READ=('箕面',)
WORD_START={'内':'うち','浦':'うら','裏':'うら','牛':'うし','魚':'うお','海':'うみ','兎':'うさぎ','畝':'うね','上':'うえ','尾':'お','箕面':'お'}
# 宇는 う 한 글자라 앞이 う 줄이면 구별되지 않는다 (陸中宇部, 由宇)
AFTER_O='おこそとのほもよろごぞどぼぽょ'
# 한 낱말로 읽는 말. 앞 표의 한자가 있어도 장음이다
# 熟字訓·옛 국명(한자를 하나씩 읽지 않는 말). 공식 표기도 한 낱말의 장음으로 줄인다 (5회차 장음 점검 2026-11-25: 近江 Ōmi, 下総 Shimōsa, 伯耆 Hōki, 国府 Kō, 洞爺 Tōya)
ONE_WORD=('青海','神海','河内','青梅','真岡','近江','下総','伯耆','国府','府中','洞爺')

def mark_words(kana,ja):
    """일본어 이름을 보고 읽기에 낱말 경계 |를 넣는다"""
    if not ja or any(w in ja for w in ONE_WORD):return kana
    # う 줄 뒤도 같다 (近鉄宇治山田 きんてつうじやまだ → Kintetsuujiyamada)
    if '宇' in ja:kana=re.sub(f'(?<=[{AFTER_O}うくすつぬふむゆるぐずづぶぷゅ])う(?=[じつわみべ])','|う',kana)
    for kanji,read in WORD_START.items():
        if kanji not in ja:continue
        before=ja.index(kanji);after=ja[before+len(kanji):]
        def cut(m):
            # 한자 뒤의 글자 수와 읽기 뒤의 글자 수가 맞아야 그 한자의 읽기다 (雄鎮内의 ゆうちんない는 아니다)
            # 앞도 같다. 한자 앞 글자마다 읽기가 한 글자 이상이다 (上越 じょうえつ의 うえ는 上이 아니다)
            tail=len(m.string)-m.end()
            return '|'+read if (tail>=len(after) if after else tail==0) and (len(kanji)>1 or (before and m.start()>=before)) else read
        kana=re.sub(f'(?<=[{AFTER_O}うくすつぬふむゆるぐずづぶぷゅ])'+read,cut,kana)
    return kana

def contract(kana,ja=None):
    """장음을 줄인다. 같은 한자 읽기 안에서만 줄이고 한자 경계는 넘지 않는다(豊|岡 Toyooka, 田|の|浦 Tanoura, 奥|羽 Ou).
    한자별 읽기 표로 나눌 수 있으면 en_segment.contract, 못 나누면(숫자가 든 이름 등) 아래 옛 규칙. 熟字訓(ONE_WORD)은 한 낱말이라 옛 규칙 (5회차 장음 점검 2026-11-25)"""
    h=kata2hira(unicodedata.normalize('NFKC',kana))
    # 같은 한자 자리 안이어도 두 음절을 모두 읽는 熟字訓(箕面 みの|お, Minoo)은 위 WORD_START 손 규칙으로 읽는다
    if ja and not any(w in ja for w in ONE_WORD+BOTH_READ):
        import en_segment
        r=en_segment.contract(h,plainja(ja))
        if r is not None:return r
    k=mark_words(h,ja)
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
    """역 이름의 규칙 표기. 낱말 하나로 붙여 쓴다. 옛 국명 접두(陸前高田)는 하이픈으로 뗀다(Rikuzen-Takata, 2회차 종합 K17)"""
    from ko import province
    pv=province(ja or '',kana or '')
    if pv:return pv[2]+'-'+station_reading(pv[4],pv[3])
    # ん은 b, p, m 앞에서 m, 모음 앞에서 n'이다 (§9.1, 감사 A2-13). 첫 글자만 대문자라 n' 뒤는 소문자다
    h=hepburn(kana,ja)
    return h[:1].upper()+h[1:]

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
# 二十·三十丁目은 「にじっ·にじゅっ·さんじゅっ」이다. 십의 자리(に·さん) 뒤 じっ·じゅっ을 받지 않아 西二十丁目이 Nishini 20-chome였다 (5회차 2026-11-24)
CHOME_READ=re.compile('(?:(?:に|さん)?(?:じっ|じゅっ)|(?:(?:に|さん)?じゅう)?(?:いっ|に|さん|よん|ご|ろく|なな|はっ|きゅう)?)ちょうめ$')
EKIMAE=re.compile(r'^(JR)?(.*?)駅前(大通|通)?$')
TERMINAL=re.compile(r'^(.*)空港第(\d)(?:・第(\d))?ターミナル$')

def chome(ja,kana,known):
    m=CHOME.match(ja)
    # 지명 없이 丁目만인 정류장은 앞에 띄어 쓰지 않는다 (旭川電気軌道 一丁目)
    return m and f"{place(m.group(1),CHOME_READ.sub('',kana),known)} {number(m.group(2))}-chome".lstrip()

def ekimae(ja,kana,known):
    m=EKIMAE.match(ja)
    if not m:return None
    jr,base,tail=m.groups()
    read=re.sub('(じぇいあーる)|(えきまえ(おお)?(どおり)?$)','',kana)
    head=place(base,read,known)
    # 駅前는 공식이 없으면 「-ekimae」 소문자다(-mae와 같은 꼴, 사용자 결정 2026-11-24). 공식 영어 이름은 en_official.json이 앞선다
    name=f"{head}-ekimae" if head else 'Ekimae'
    if jr:name='JR '+name
    return name+{'大通':'-Odori','通':'-dori',None:''}[tail]

EKIGUCHI=re.compile(r'^(.+?)駅(東|西|南|北|中央|前|新)?口$')
def ekiguchi(ja,kana,known):
    """駅〇口 정류장(秋葉原駅東口 → Akihabara-eki-higashiguchi). 공식 근거가 없어 「〇口」는 한 낱말로 붙인다 (5회차 규칙 설계, 공식 이름 다수 꼴)"""
    m=EKIGUCHI.match(ja)
    if not m or 'えき' not in kana:return None
    i=kana.rfind('えき');base,rest=kana[:i],kana[i+2:]
    if not base or not rest:return None
    return f"{place(m.group(1),base,known)}-eki-{hepburn(rest)}"

# 前 앞의 시설 낱말은 하이픈 소문자로 나눈다(Akado-shogakko-mae). 공식 이름 다수 꼴 (5회차 규칙 설계 2026-11-24)
INST=sorted((('病院','びょういん','byoin'),('市役所','しやくしょ','shiyakusho'),('区役所','くやくしょ','kuyakusho'),('役所','やくしょ','yakusho'),
             ('小学校','しょうがっこう','shogakko'),('中学校','ちゅうがっこう','chugakko'),('学校','がっこう','gakko'),('高校','こうこう','koko'),
             ('大学','だいがく','daigaku'),('車庫','しゃこ','shako'),('交差点','こうさてん','kosaten'),('神社','じんじゃ','jinja'),('郵便局','ゆうびんきょく','yubinkyoku')),
            key=lambda t:len(t[0]),reverse=True)
def mae(ja,kana,known):
    """〇〇前 정류장 → 「〇〇-mae」(앞에 하이픈이 있어도 붙인다, 공식 이름 16/28). 駅前는 ekimae가 먼저 다룬다"""
    if len(ja)<2 or not ja.endswith('前') or not kana.endswith('まえ') or ja.endswith('駅前'):return None
    bj,bk=ja[:-1],kana[:-2]
    # 이름 전체가 시설 낱말이면 나누지 않는다(市役所前 → Shiyakusho-mae, 大学前 → Daigaku-mae)
    if any(bj==wj and bk==wk for wj,wk,_ in INST):return f"{place(bj,bk,known)}-mae"
    for wj,wk,we in INST:
        if bj.endswith(wj) and bk.endswith(wk) and len(bj)>len(wj):
            return f"{place(bj[:-len(wj)],bk[:-len(wk)],known)}-{we}-mae"
    return f"{place(bj,bk,known)}-mae"

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
    return chome(ja,kana,known) or ekimae(ja,kana,known) or ekiguchi(ja,kana,known) or terminal(ja,kana,known) or katakana(ja,kana,known,text) or mae(ja,kana,known) or eki(ja,kana,known)

def eki(ja,kana,known):
    """이름이 「駅」으로 끝나는 정류장(広島駅, 須磨駅)은 -eki를 붙여 같은 이름 철도역과 가른다 (2회차 종합 K17)"""
    if len(ja)>1 and ja.endswith('駅') and kana.endswith('えき') and len(kana)>2:
        return f"{place(ja[:-1],kana[:-2],known)}-eki"
    return None

# 번역형 낱말과 그 외래어 가나. 가나가 일본어 이름에 있으면(フラワーパーク) 번역이 아니다
TRANSLATED_WORDS={'Park':'パーク','Garden':'ガーデン','Gardens':'ガーデン','Botanical':None,'Zoo':'ズー','Zoological':None,'Museum':'ミュージアム',
 'Hospital':'ホスピタル','University':'ユニバーシティ','Univ':None,'Medical':'メディカル','Municipal':None,'City':'シティ','Hall':'ホール',
 'Port':'ポート','Temple':None,'Shrine':None,'Castle':'キャッスル','Station':'ステーション','Sta':None,'Entrance':None,'Office':'オフィス',
 'Prefectural':None,'Police':None,'Elementary':None,'Depot':None,'Cathedral':None,'International':'インターナショナル','Art':'アート'}
def is_translated(text,ja):
    # 공항(空港 → Airport, 中部国際空港 → Central Japan International Airport)은 공항 규칙의 꼴이다
    if '空港' in ja:return False
    for w in re.findall(r"[A-Za-z]+",text):
        if w in TRANSLATED_WORDS and not (TRANSLATED_WORDS[w] and TRANSLATED_WORDS[w] in ja):return True
    return False

# 공식 번역형(市役所 City Hall, 運動公園前 Sports Park)은 다른 역 이름의 낱말 바탕이 아니다. 영어 시설 낱말이 있어도 일본어 이름에 가타카나가 있으면
# 외래어를 그대로 옮긴 것(国際センター Kokusai Center, スポーツセンター → Sports Center)이라 바탕으로 둔다 (5회차 2026-11-25)
_FAC_WORDS=re.compile(r'\b(Hall|Park|University|Hospital|Station|Center|Museum|Shrine|Temple|Airport|School|Office|Garden|Gardens|Port|Terminal|Bridge|Depot|Yard|Cathedral|Castle|Farm|Ground)\b')
def _translated_base(text,ja):
    if ja and is_translated(text,ja):return True
    return bool(_FAC_WORDS.search(text)) and not re.search('[ァ-ヶー]',ja or '')

def fix_nodes(names):
    """gen_source.py가 일본어와 읽기를 확정한 뒤 부른다. en 행의 글자만 바꾼다 (행 순서는 그대로)"""
    fix=load_fix();nodefix=fix['node'];keep=set(fix['chome_official'])
    ja={};kana={}
    for x in names:
        if x['entity_type']!='node' or x['lang']!='ja' or x.get('line') or x.get('valid_to'):continue
        if x['id'] not in ja:ja[x['id']]=x['text'];kana[x['id']]=plainkana(x.get('kana'))
    # 기간 있는 옛 이름 행은 그 시절 읽기로 이미 만들었다. 지금 이름 읽기로 덮지 않는다 (재평가 ST4-12)
    # 노선 전용 행(line)은 그 노선 표기의 읽기로 이미 만들었다. 지금 이름 읽기로 덮지 않는다
    rows=[x for x in names if x['entity_type']=='node' and x['lang']=='en' and not x.get('valid_from') and not x.get('valid_to') and not x.get('line')]
    # 규칙 이름은 확정된 읽기로 다시 만든다. node_fix.json이 읽기를 고치기 전에 만든 값이 남아 있다
    for x in rows:
        if x['source']=='rule' and kana.get(x['id']):x['text']=station_reading(kana[x['id']],plainja(ja[x['id']]))
    # 현행 역의 공식 영어 이름(회사 자료·역명판 사진)이 가장 앞선다. 다른 역 이름의 낱말 경계 바탕(known)으로도 쓴다 (사용자 결정 2026-11-24)
    official=load_official()
    # 열쇠는 노드(지금 이름) 또는 「노드|일본어 이름」(그 이름일 때만: 폐역의 마지막 이름·기간 있는 옛 이름, 옛 공식 역 일람 로마자 5회차 r3)
    def _named(tab,i,j):
        for k_ in (i+'|'+(j or ''),i+'|'+plainja(j or '')):
            if k_ in tab:return tab[k_]
        return None
    for x in rows:
        v_=official.get(x['id']) or _named(official,x['id'],ja.get(x['id']))
        if v_:x['text']=v_['en'];x['source']='official'
    # 공식을 못 찾은 역은 일본어 위키백과 역 문서 정보칸 로마자가 다음이다(위키 가운데 일본어 위키 최우선, 사용자 결정 2026-11-25). Wikidata 라벨·규칙보다 앞선다.
    # 출처 표시는 wikipedia이고, 아래 규칙 손질(fix_station·번역형 바꾸기)을 거치지 않는다
    jawiki=load_jawiki()
    for x in rows:
        v_=jawiki.get(x['id']) or _named(jawiki,x['id'],ja.get(x['id']))
        if x['source']!='official' and v_:x['text']=v_['en'];x['source']='wikipedia';x['_jawiki']=True
    # 번역형(植物園→Botanical Garden, 松山市→Matsuyama City, 八木山動物公園→Yagiyama Zoological Park)은 공식이 아닌 라벨에서도 쓰지 않는다.
    # 로마자 꼴(읽기 규칙)로 바꾸고 번역형은 검색 별칭으로 돌려준다. 공항(Airport)은 공항 터미널 규칙(terminal)이 정한 꼴이라 그대로다 (사용자 결정 2026-11-24 영어 이름 원칙 3, 일반화 2026-11-25)
    translated=[]
    def untranslate(x,known=None):
        i=x['id']
        if x['source']=='official' or x.get('_jawiki') or i not in ja or not kana.get(i) or not is_translated(x['text'],ja[i]):return
        translated.append((i,x['text']));x['text']=station_reading(kana[i],plainja(ja[i]));x['source']='rule'
        # 외래어·-mae 규칙을 읽기 꼴에 다시 씌운다(東京国際クルーズターミナル → …Cruise Terminal). 첫 차례는 아래 고리가 씌운다
        if known is not None:
            made=fix_station(ja[i],kana[i],x['text'],known,keep)
            if made:x['text']=made
    for x in rows:untranslate(x)
    # 다른 역 이름의 바탕. 어절이 나뉜 표기만 믿는다
    known={}
    for x in rows:
        # 공식 번역형(市役所 City Hall, 사용자 결정 2026-11-25)은 그 역만의 이름이라 다른 역 이름의 낱말 바탕으로 쓰지 않는다(市役所前 → City Hall-mae가 됨)
        if x['source']!='rule' and x['id'] not in nodefix and ('-' in x['text'] or ' ' in x['text'] or len(x['text'])<13) and not _translated_base(x['text'],ja.get(x['id'],'')):
            known.setdefault((plainja(ja[x['id']]),kana[x['id']]),x['text'])
    known.update({tuple(k.split('|')):v['en'] for k,v in fix['base'].items()})
    for x in rows:
        i=x['id']
        if x['source']=='official' or x.get('_jawiki'):continue
        if i in nodefix:x['text']=nodefix[i]['en'];x['source']='hand';continue
        if x['source']=='hand' or i not in ja:continue
        made=fix_station(ja[i],kana[i],x['text'],known,keep)
        if made:x['text']=made;x['source']='rule'
    for x in rows:untranslate(x,known)
    # 기간 있는 옛 이름의 규칙 영어도 같은 규칙(駅前 -ekimae, 丁目 -chome 등)을 그 시절 이름·읽기로 적용한다
    old_ja={(x['id'],x.get('valid_to')):(x['text'],plainkana(x.get('kana'))) for x in names if x['entity_type']=='node' and x['lang']=='ja' and not x.get('line') and x.get('valid_to')}
    for x in names:
        if x['entity_type']!='node' or x['lang']!='en' or x.get('line') or not x.get('valid_to'):continue
        j_,k_=old_ja.get((x['id'],x['valid_to']),(None,None))
        # 옛 이름의 공식(옛 역 일람)·일본어 위키 로마자는 「노드|그 이름」 열쇠로 규칙보다 앞선다
        v_=_named(official,x['id'],j_) if j_ else None
        if v_:x['text']=v_['en'];x['source']='official';continue
        v_=_named(jawiki,x['id'],j_) if j_ else None
        if v_ and x.get('source')!='official':x['text']=v_['en'];x['source']='wikipedia';continue
        if x.get('source')!='rule':continue
        if j_ and k_:
            made=fix_station(j_,k_,x['text'],known,keep)
            if made:x['text']=made
    for x in rows:x.pop('_jawiki',None)
    return translated
