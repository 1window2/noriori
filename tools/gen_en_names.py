# -*- coding: utf-8 -*-
# 노선·사업자·계통·운전 계통의 영어 이름을 만든다 (DESIGN §9.1).
# 순서는 공식 표기(data/overrides/en_fix.json), Wikidata 영어 라벨, 히라가나 읽기의 헵번식(장음 기호 없이)이다.
# 일반명사만 남는 노선 이름에는 회사 약칭을 붙인다 (en_fix.json의 operator_short).
#   python3 -I tools/gen_en_names.py [--dry]
# 라벨은 data/overrides/wikidata_labels.json이다. {kind: {일본어 이름: [[항목, 영어, 형식], ...]}}, CC0.
# 라벨을 새로 받는 일은 수집 단계에서 따로 한다. 이 도구는 네트워크를 쓰지 않는다.
import json,os,re,sqlite3,sys,unicodedata
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0,os.path.join(ROOT,'tools'))
from en_rules import hepburn,load_fix

# 운전 계통은 표가 짧아 손으로 적는다
SERVICES={
    's_yamanote_loop':'Yamanote Line (Loop)','s_chuo_rapid':'Chuo Line (Rapid)','s_chuo_sobu_local':'Chuo-Sobu Line (Local)',
    's_keihin_tohoku':'Keihin-Tohoku Line','s_saikyo':'Saikyo Line','s_yokosuka':'Yokosuka Line',
    's_joban_rapid':'Joban Line (Rapid)','s_ueno_tokyo':'Ueno-Tokyo Line','s_shonan_shinjuku_ty':'Shonan-Shinjuku Line (Tokaido)',
    's_shonan_shinjuku_ys':'Shonan-Shinjuku Line (Yokosuka)','s_jr_kyoto':'JR Kyoto Line','s_jr_kobe':'JR Kobe Line',
    's_biwako':'Biwako Line','s_osaka_loop':'Osaka Loop Line','s_yamagata_shinkansen':'Yamagata Shinkansen',
    's_akita_shinkansen':'Akita Shinkansen','s_meijo_loop':'Meijo Line (Loop)',
}
# Wikidata에서 찾지 못한 사업자
OPERATORS={
    'JR東日本':'JR East','JR東海':'JR Central','JR西日本':'JR West','JR北海道':'JR Hokkaido','JR九州':'JR Kyushu','JR四国':'JR Shikoku',
    'JR貨物':'JR Freight','上田電鉄':'Ueda Electric Railway','万葉線':'Manyosen','小湊鉄道':'Kominato Railway',
    '京都丹後鉄道（WILLER TRAINS）':'Kyoto Tango Railway (Willer Trains)','京福電気鉄道':'Keifuku Electric Railroad',
    '別府鉄道':'Befu Railway','大夕張鉄道':'Oyubari Railway','同和鉱業':'Dowa Mining','頸城鉄道':'Kubiki Railway',
    '野上電気鉄道':'Nogami Electric Railway','北丹鉄道':'Hokutan Railway','備南電気鉄道':'Binan Electric Railway',
    '南部縦貫鉄道':'Nambu Jukan Railway',
}
# 노선 읽기 앞에 붙는 회사 약칭. 일본어 이름에는 없고 읽기에만 있어 뗀다
PREFIXES={'さんりくてつどう':'三陸鉄道','さんようでんてつ':'山陽電鉄','とうきょうめとろ':'東京メトロ','とえいとでん':'都営','とえい':'都営','にしてつ':'西鉄',
          'けいせい':'京成','めいてつ':'名鉄','きんてつ':'近鉄','せいぶ':'西武','けいおう':'京王','かんでん':'関電','とうぶ':'東武','おだきゅう':'小田急',
          'けいきゅう':'京急','とうきゅう':'東急','はんきゅう':'阪急','はんしん':'阪神','なんかい':'南海','けいはん':'京阪','そうてつ':'相鉄',
          'しんてつ':'神鉄','りゅうてつ':'流鉄','いせ':'伊勢','みずま':'水間'}
GENERIC=re.compile('^(でんきてつどう|ちほうてつどう|てつどう|でんてつ|でんきこうつう|でんこうつう|こうつう|でんき|しでん|しえいちかてつ|しちかてつ)')
# 읽기가 없는 노선. 노면전차 계통과 연락선이 대부분이다
READINGS={
    'つくばエクスプレス線':'Tsukuba Express Line','ディズニーリゾートライン':'Disney Resort Line','ポートアイランド線':'Port Island Line',
    '六甲ケーブル線':'Rokko Cable Line','摩耶ケーブル線':'Maya Cable Line','妙見の森ケーブル':'Myokennomori Cable','ケーブルカー':'Cable Car',
    '鋼索線':'Cable Line','鉄道線':'Railway Line','本線':'Main Line','1号線':'Line 1','2号線':'Line 2','3号線':'Line 3','4号線':'Line 4',
    '金沢シーサイド線':'Kanazawa Seaside Line','東京臨海新交通臨海線':'Yurikamome Line','無軌条電車':'Trolleybus','成田空港線':'Narita Airport Line',
    '幹線':'Trunk Line','丸ノ内線方南町支線':'Marunouchi Line Honancho Branch','夕張線登川支線':'Yubari Line Noborikawa Branch',
    '名城線・名港線':'Meijo-Meiko Line','1条線・山鼻線・山鼻西線・都心線':'Sapporo Streetcar','天神大牟田線':'Tenjin-Omuta Line',
    '国際文化公園都市線':'Kokusai Bunka Koen Toshi Line','西九州線':'Nishi-Kyushu Line','秋田内陸線':'Akita Nairiku Line',
    '西神延伸線':'Seishin Extension Line','広島短距離交通瀬野線':'Seno Line','上野懸垂線':'Ueno Suspended Line',
    '鞍馬山鋼索鉄道線':'Kuramayama Cable Line','東山本線':'Higashiyama Main Line','南越線':'Nan-Etsu Line','荒川線':'Arakawa Line',
    '上滝線':'Kamidaki Line','立山線':'Tateyama Line','八日市線':'Yokaichi Line','多賀線':'Taga Line','上高地線':'Kamikochi Line',
    '湊線':'Minato Line','阿佐東線':'Asato Line','山代線':'Yamashiro Line','田園都市線':'Den-en-toshi Line',
    'モンキーパークモノレール線':'Monkey Park Monorail','秩父鉄道連絡線':'Chichibu Railway Connecting Line','北しなの線':'Kita-Shinano Line',
    '半蔵門線直通':'Hanzomon Line Through Service','松田連絡線':'Matsuda Connecting Line','鵜沼連絡線':'Unuma Connecting Line',
    '新ノ口連絡線':'Ninokuchi Connecting Line','宝来・谷地頭線':'Horai-Yachigashira Line','大森線':'Omori Line',
    '湯の川線':'Yunokawa Line','水前寺線':'Suizenji Line','健軍線':'Kengun Line','上熊本線':'Kami-Kumamoto Line',
    '田崎線':'Tasaki Line','第一期線':'First Phase Line','第二期線':'Second Phase Line','谷山線':'Taniyama Line',
    '唐湊線':'Toso Line','軌道線本線':'Tramway Main Line','軌道線支線':'Tramway Branch Line','軌道線安野屋線':'Tramway Yasunoya Line',
    '軌道線呉羽線':'Tramway Kureha Line','軌道線富山都心線':'Tramway Toyama City Center Line',
    '軌道線富山駅南北接続線':'Tramway Toyama Station North-South Link','江波線':'Eba Line','横川線':'Yokogawa Line',
    '皆実線':'Minami Line','白島線':'Hakushima Line','循環線':'Loop Line','宮島線':'Miyajima Line','城北線':'Johoku Line',
    '城南線':'Jonan Line','本町線':'Honmachi Line','大手町線':'Otemachi Line','花園線':'Hanazono Line','赤迫支線':'Akasako Branch Line',
    '桜町支線':'Sakuramachi Branch Line','大浦支線':'Oura Branch Line','蛍茶屋支線':'Hotarujaya Branch Line',
}
# 일반명사뿐인 이름. 회사 약칭(en_fix.json의 operator_short)을 붙인다
GENERIC_NAMES=('Main Line','Airport Line','Line 1','Line 2')
LINE_ENDS=(('新幹線','しんかんせん','Shinkansen'),('本線','ほんせん','Main Line'),('支線','しせん','Branch Line'),
           ('モノレール線','ものれーるせん','Monorail'),('モノレール','ものれーる','Monorail'),('鋼索線','こうさくせん','Cable Line'),
           ('線','せん','Line'))
WORDS=(('電気鉄道','でんきてつどう','Electric Railway'),('高速鉄道','こうそくてつどう','Rapid Railway'),('鉄道','てつどう','Railway'),
       ('電鉄','でんてつ','Electric Railway'),('軌道','きどう','Tramway'),('急行','きゅうこう','Kyuko'),('空港','くうこう','Airport'),
       ('連絡','れんらく','Connecting'),('短絡','たんらく','Connecting'))
LATIN={'A':'えー','B':'びー','C':'しー','D':'でぃー','E':'いー','F':'えふ','G':'じー','H':'えいち','I':'あい','J':'じぇい','K':'けい',
       'L':'える','M':'えむ','N':'えぬ','O':'おー','P':'ぴー','Q':'きゅー','R':'あーる','S':'えす','T':'てぃー','U':'ゆー','V':'ぶい',
       'W':'だぶりゅー','X':'えっくす','Y':'わい','Z':'ぜっと'}

def plain(text):
    """장음 기호를 뺀다 (DESIGN §9.1)"""
    return ''.join(c for c in unicodedata.normalize('NFD',text) if not unicodedata.combining(c))

def titled(kana,ja=None):
    text=hepburn(kana,ja)
    return text[:1].upper()+text[1:]

def split_words(ja,kana):
    """이름 안의 낱말을 번역하고 나머지는 읽기대로 적는다"""
    parts=[];ja_left=ja;kana_left=kana
    latin=re.match(r'[A-Za-z]+',ja_left)
    if latin:
        word=latin.group(0);read=''.join(LATIN.get(c.upper(),'') for c in word)
        parts.append(word)
        ja_left=ja_left[len(word):]
        if kana_left.startswith(read):kana_left=kana_left[len(read):]
    for token,reading,english in WORDS:
        if token in ja_left and reading in kana_left:
            head,tail=kana_left.split(reading,1)
            ja_head,ja_tail=ja_left.split(token,1)
            if head:parts.append(titled(head,ja))
            parts.append(english)
            ja_left,kana_left=ja_tail,tail
            break
    if kana_left:parts.append(titled(kana_left,ja))
    return ' '.join(p for p in parts if p)

def line_name(ja,kana):
    if ja in READINGS:return READINGS[ja]
    if not kana:return None
    for tail_ja,tail_kana,tail_en in LINE_ENDS:
        # 田原本線처럼 글자는 맞아도 읽기가 다르면 그 끝이 아니다
        if ja.endswith(tail_ja) and (tail_kana in kana or tail_ja=='線'):
            root=ja[:-len(tail_ja)]
            read=re.sub(tail_kana+'$','',kana)
            head=split_words(root,read)
            return f'{head} {tail_en}'.strip()
    return split_words(ja,kana)

def pick(rows,kinds):
    """형식이 맞는 라벨 하나. 영어가 갈리면 쓰지 않는다"""
    good=[r for r in rows if r[2] not in kinds['bad']]
    texts={plain(r[1]) for r in good}
    return texts.pop() if len(texts)==1 else None

def own_reading(ja,kana,operator_en,shared):
    """노선 읽기 앞의 회사 이름을 뗀다. 일본어 이름에는 없는 글자다"""
    if not kana:return kana
    # 뗀 뒤의 읽기는 일본어 이름 글자 수보다 짧을 수 없다. 짧으면 이름까지 지운 것이다 (伊勢線, 岳南鉄道線)
    fits=lambda tail:len(tail)>=len(ja)
    if shared and len(kana)>len(shared):
        tail=kana[len(shared):]
        if GENERIC.search(shared[-4:]) or GENERIC.match(tail) or shared.endswith(('てつどう','でんてつ','こうつう','めとろ','でんき','しでん')):
            left=GENERIC.sub('',tail) or tail
            if fits(left):return left
    for prefix,kanji in PREFIXES.items():
        tail=GENERIC.sub('',kana[len(prefix):])
        # 일본어 이름에 회사 글자가 있으면 이름의 일부다. 西武園線처럼 읽기에 한 번 더 있으면 앞의 것은 회사다
        if kana.startswith(prefix) and fits(tail) and (not ja.startswith(kanji) or tail.startswith(prefix)):return tail
    word=plain(operator_en or '').split(' ')[0].lower().replace("'",'')
    for at in range(2,len(kana)):
        if hepburn(kana[:at]).replace("'",'').lower()==word:
            tail=GENERIC.sub('',kana[at:])
            if tail!=kana[at:] and tail and fits(tail):return tail
    return kana

def common_prefix(items):
    items=list(items)
    if len(items)<2:return ''
    return os.path.commonprefix(items)

def clean(text):
    text=plain(text).replace('‐','-').replace('–','-').replace('’',"'")
    # Wikidata 라벨의 소문자 line (Sangi line, Osaki branch line)
    text=re.sub(r'\bbranch line$','Branch Line',text)
    text=re.sub(r'\bline$','Line',text)
    return re.sub(r'\s+',' ',text).strip()

def check(rows):
    """다시 생기면 안 되는 꼴을 막는다 (i18n-review-en §8)"""
    bad=[r['text'] for r in rows if r['entity_type'] in('line','operator','service') and (
        re.search(r' (line|branch line)\b',r['text']) or r['text'] in GENERIC_NAMES or r['text'] in('Line','Railway Line','Cable Line','Cable Car','Connecting Line','Trolleybus')
        or not r['text'].strip() or not r['text'].replace('·','').isascii())]
    # 역 이름은 names.yaml에 있다. 읽기대로 옮긴 외래어와 붙은 ekimae가 돌아오지 않게 한다
    bad+=[r['text'] for r in rows if re.search('keburu|monoreru|taminaru|kosakusen|[a-z]ekimae',r['text'],re.I)]
    if bad:sys.exit('영어 이름 규칙 위반: '+', '.join(bad))

def main():
    labels=json.load(open(os.path.join(ROOT,'data','overrides','wikidata_labels.json'),encoding='utf-8'))
    fix=load_fix()
    dry='--dry' in sys.argv
    src=os.path.join(ROOT,'data','source','names','names.yaml')
    names=[json.loads(l[2:]) for l in open(src,encoding='utf-8') if l.startswith('- {')]
    ja={};kana={}
    for x in names:
        if x['lang']=='ja' and not x.get('line'):
            ja.setdefault((x['entity_type'],x['id']),x['text'])
            if x.get('kana'):kana.setdefault((x['entity_type'],x['id']),x['kana'])
    en_node={x['id']:x['text'] for x in names if x['entity_type']=='node' and x['lang']=='en'}
    count={}
    for (kind,_),text in ja.items():count[(kind,text)]=count.get((kind,text),0)+1
    bad={'bad':{'Q4167410','Q13406463','Q5','Q55488','Q953806'}}
    rows=[];stats={}
    def add(kind,id_,text,source):
        rows.append({'entity_type':kind,'id':id_,'lang':'en','text':text,'source':source})
        stats[(kind,source)]=stats.get((kind,source),0)+1
    missing=[]
    master=sqlite3.connect('file:'+os.path.join(ROOT,'build','master.sqlite')+'?mode=ro',uri=True)
    owner=dict(master.execute('select line_id,operator_id from edge_attr'))
    operator_en={}
    for (kind,id_),text in sorted(ja.items()):
        if kind=='operator':
            operator_en[id_]=fix['operator'].get(id_,{}).get('en') or OPERATORS.get(text) or pick(labels.get(kind,{}).get(text,[]),bad)
    groups={}
    for (kind,id_) in ja:
        if kind=='line' and (kind,id_) in kana and id_ in owner:groups.setdefault(owner[id_],[]).append(kana[(kind,id_)])
    for (kind,id_),text in sorted(ja.items()):
        if kind not in('line','operator'):continue
        if id_ in fix[kind]:add(kind,id_,fix[kind][id_]['en'],'hand');continue
        got=None
        # 이름이 겹치는 노선은 라벨이 어느 쪽인지 모른다
        if count[(kind,text)]==1:got=pick(labels.get(kind,{}).get(text,[]),bad)
        if got:add(kind,id_,clean(got),'wikidata');continue
        if kind=='line':
            company=owner.get(id_)
            read=own_reading(text,kana.get((kind,id_)),operator_en.get(company),common_prefix(groups.get(company,[])))
            made=line_name(text,read)
            # 일반명사만 남으면 어느 노선인지 모른다 (Keisei Main Line, Keikyu Airport Line)
            if made in GENERIC_NAMES:made=f"{fix['operator_short'][company]['en']} {made}"
        else:made=OPERATORS.get(text)
        if made:add(kind,id_,clean(made),'rule')
        else:missing.append((kind,id_,text))
    for id_,text in SERVICES.items():add('service',id_,text,'hand')
    routes={x['id'] for x in names if x['entity_type']=='route'}
    for route,a,b in master.execute('select id,from_node,to_node from route'):
        if route in routes and a in en_node and b in en_node:add('route',route,f'{en_node[a]}~{en_node[b]}','rule')
    check(rows+[x for x in names if x['entity_type']=='node' and x['lang']=='en'])
    print(sorted(stats.items()))
    print('못 만든 것',len(missing),missing[:40])
    if dry:return rows
    path=os.path.join(ROOT,'data','source','names','en.yaml')
    with open(path,'w',encoding='utf-8') as f:
        f.write('# 영어 이름\n')
        for r in rows:f.write('- '+json.dumps(r,ensure_ascii=False)+'\n')
    return rows

if __name__=='__main__':main()
