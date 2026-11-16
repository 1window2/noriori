# -*- coding: utf-8 -*-
# 노선·사업자·계통·운행 계통의 영어 이름을 만든다 (DESIGN §9.1).
# 순서는 공식 표기(data/overrides/en_fix.json), Wikidata 영어 라벨, 히라가나 읽기의 헵번식(장음 기호 없이)이다.
# 일반명사만 남는 노선 이름에는 회사 약칭을 붙인다 (en_fix.json의 operator_short).
#   python3 -I tools/gen_en_names.py [--dry]
# 라벨은 data/overrides/wikidata_labels.json이다. {kind: {일본어 이름: [[항목, 영어, 형식], ...]}}, CC0.
# 라벨을 새로 받는 일은 수집 단계에서 따로 한다. 이 도구는 네트워크를 쓰지 않는다.
import glob,json,os,re,sqlite3,sys,unicodedata
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0,os.path.join(ROOT,'tools'))
from en_rules import hepburn,load_fix,fix_station
from lib import HT,source_on,_rows,ROOT as _ROOT

# 운행 계통은 표가 짧아 손으로 적는다. 운행 계통 정의(services.json)에 en이 있으면 그것을 쓴다
# 정의에서 빠진 옛 운행 계통 ID(湘南新宿ライン _ty·_ys 등)의 이름은 만들지 않는다
_sv=json.load(open(os.path.join(ROOT,'data','overrides','services.json'),encoding='utf-8'))
SERVICES={k:v for k,v in HT['SERVICES'].items() if k in {s['id'] for s in _sv}}
for _s in _sv:
    # 범위의 en dash는 계통 이름처럼 ~로 쓴다 (Nara Line (Kyoto~Nara)). 영어 이름은 ASCII만이다
    if _s.get('en'):SERVICES[_s['id']]=_s['en'].replace('–','~').replace('—','~')
# Wikidata에서 찾지 못한 사업자
OPERATORS=HT['OPERATORS']
# 노선 읽기 앞에 붙는 회사 약칭. 일본어 이름에는 없고 읽기에만 있어 뗀다
PREFIXES={'さんりくてつどう':'三陸鉄道','さんようでんてつ':'山陽電鉄','とうきょうめとろ':'東京メトロ','とえいとでん':'都営','とえい':'都営','にしてつ':'西鉄',
          'けいせい':'京成','めいてつ':'名鉄','きんてつ':'近鉄','せいぶ':'西武','けいおう':'京王','かんでん':'関電','とうぶ':'東武','おだきゅう':'小田急',
          'けいきゅう':'京急','とうきゅう':'東急','はんきゅう':'阪急','はんしん':'阪神','なんかい':'南海','けいはん':'京阪','そうてつ':'相鉄',
          'しんてつ':'神鉄','りゅうてつ':'流鉄','いせ':'伊勢','みずま':'水間'}
GENERIC=re.compile('^(でんきてつどう|ちほうてつどう|てつどう|でんてつ|でんきこうつう|でんこうつう|こうつう|でんき|しでん|しえいちかてつ|しちかてつ)')
# 읽기가 없는 노선. 노면전차 계통과 연락선이 대부분이다
READINGS=HT['READINGS']
# 일반명사뿐인 이름. 회사 약칭(en_fix.json의 operator_short)을 붙인다
GENERIC_NAMES=('Main Line','Airport Line','Line 1','Line 2','Connecting Line')
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
    # 출처 스위치에서 Wikidata를 끄면 라벨을 쓰지 않는다 (data/sources.json)
    on=source_on('wikidata')
    labels=json.load(open(os.path.join(ROOT,'data','overrides','wikidata_labels.json'),encoding='utf-8')) if on else {}
    fix=load_fix()
    dry='--dry' in sys.argv
    src=os.path.join(ROOT,'data','source','names','names.yaml')
    names=[json.loads(l[2:]) for l in open(src,encoding='utf-8') if l.startswith('- {')]
    ja={};kana={}
    for x in names:
        if x['lang']=='ja' and not x.get('line'):
            ja.setdefault((x['entity_type'],x['id']),x['text'])
            if x.get('kana'):kana.setdefault((x['entity_type'],x['id']),x['kana'])
    # 지금 이름만 쓴다. 기간 있는 옛 이름 행이 덮으면 계통 이름이 옛 역명이 된다 (Shin-Aomori~Oshimaono)
    en_node={x['id']:x['text'] for x in names if x['entity_type']=='node' and x['lang']=='en' and not x.get('line') and not x.get('valid_from') and not x.get('valid_to')}
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
            parts=text.split(' ',1);reads=(kana.get((kind,id_)) or '').split(' ',1)
            if len(parts)==2 and len(reads)==2 and parts[1].endswith('支線') and reads[1].endswith('しせん'):
                # 본선 이름 뒤에 갈래를 적은 지선 (別大線 別府駅前支線 → Betsudai Line Beppu-Ekimae Branch)
                base=parts[1][:-2];base_read=reads[1][:-3]
                made=f"{line_name(parts[0],reads[0])} {fix_station(base,base_read,'',set()) or titled(base_read,base)} Branch"
            elif len(parts)==2 and len(reads)==2 and (re.search('[–~]',parts[1]) or parts[1].endswith('旧線')):
                # 본선 이름 뒤에 구간이나 옛 선로를 적은 계통 (循環線 花京院–仙台駅前 → Junkan Line (Kakyoin~Sendai-Ekimae), 清水市内線 西久保–袖師 旧線)
                tail_ja=parts[1];tail_rd=reads[1];old=''
                if tail_ja.endswith('旧線'):
                    tail_ja=tail_ja[:-2].strip();tail_rd=re.sub(r'\s*きゅうせん$','',tail_rd).strip();old=' Old Route'
                st=[x for x in re.split(r'[–~]',tail_ja) if x];rs=tail_rd.split(' ') if tail_rd else []
                seg=''
                if st and len(st)==len(rs):seg=' ('+'~'.join(fix_station(a,b,'',set()) or titled(b,a) for a,b in zip(st,rs))+')'
                made=f"{line_name(parts[0],reads[0])}{seg}{old}" if (seg or not st) else None
            else:made=line_name(text,read)
            # 일반명사만 남으면 어느 노선인지 모른다 (Keisei Main Line, Keikyu Airport Line)
            # 짧은 이름이 없는 회사(옛 폐선의 회사)는 정식 영어 이름을 붙인다 (Hokuriku Railroad Connecting Line)
            if made in GENERIC_NAMES:made=f"{(fix['operator_short'].get(company) or {}).get('en') or operator_en.get(company) or ''} {made}".strip()
        else:made=OPERATORS.get(text)
        if made:add(kind,id_,clean(made),'rule')
        else:missing.append((kind,id_,text))
    for id_,text in SERVICES.items():add('service',id_,text,'hand')
    routes={x['id'] for x in names if x['entity_type']=='route'}
    # 끝 역 너머 역 이전 옛 자리는 계통 이름에 쓰지 않는다. 지금 끝 역이다 (gen_source와 같음)
    site={x['id']:x['new_node'] for f_ in glob.glob(os.path.join(ROOT,'data','overrides','wiki_insert_moves*.json')) for x in json.load(open(f_,encoding='utf-8')) if x.get('old') and x.get('terminal') and not x.get('hold')}
    # 컴파일이 만든 계통(지선 승격·숨은 끝 계통)은 생성기 이름 행이 없다. 같은 규칙으로 일본어·한국어·영어를 모두 단다 (2회차 종합 K14)
    base_={(x['id'],x['lang']):x['text'] for x in names if x['entity_type']=='node' and not x.get('line') and not x.get('valid_from') and not x.get('valid_to')}
    route_ja={x['id']:x['text'] for x in names if x['entity_type']=='route' and x['lang']=='ja'}
    # 컴파일 단계 보정(source_patch)으로 더한 계통(日光鋼索線 등 새 노선)도 이름을 단다. 생성 중 컴파일에는 그 계통과 끝 역이 없어 보정 행의 이름으로 찾는다 (2회차 종합 K14)
    _sp=lambda m:[x for x in _rows(os.path.join(_ROOT,'data','overrides','source_patch',m)) if x.get('patch')=='add']
    for x in _sp('names'):
        if x['entity_type']=='node' and not x.get('line') and not x.get('valid_from') and not x.get('valid_to'):
            base_.setdefault((x['id'],x['lang']),x['text'])
            if x['lang']=='en':en_node.setdefault(x['id'],x['text'])
    _have={r for r, in master.execute('select id from route')}
    _pr=[(x['id'],x['from'],x['to']) for x in _sp('routes') if x['id'] not in _have]
    # 보정 행이 이미 이름을 단 계통·언어는 두지 않는다(같은 키가 둘이면 컴파일이 멈춘다)
    _pn={(x['id'],x['lang']) for x in _sp('names') if x['entity_type']=='route'}
    routes|={i for i,lg in _pn if lg=='ja'}
    for route,a,b in list(master.execute('select id,from_node,to_node from route'))+_pr:
        a,b=site.get(a,a),site.get(b,b)
        if route not in routes:
            for lang_,sep_ in (('ja','～'),('ko','~')):
                if (a,lang_) in base_ and (b,lang_) in base_:
                    rows.append({'entity_type':'route','id':route,'lang':lang_,'text':f'{base_[(a,lang_)]}{sep_}{base_[(b,lang_)]}','source':'rule'})
                    stats[('route_'+lang_,'rule')]=stats.get(('route_'+lang_,'rule'),0)+1
        if a in en_node and b in en_node and (route,'en') not in _pn:
            # 일본어 계통 이름에 （旧）가 없으면 영어에도 (old)를 붙이지 않는다 (gen_source가 같은 계통 같은 이름 （旧）를 계통 이름에서 뗌)
            ea,eb=en_node[a],en_node[b]
            if '（旧）' not in route_ja.get(route,'（旧）'):ea,eb=(re.sub(r' \(old\)$','',x) for x in (ea,eb))
            add('route',route,f'{ea}~{eb}','rule')
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
