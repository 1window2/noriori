# -*- coding: utf-8 -*-
# 날짜별 옛 역 이름의 읽기를 일본어 위키백과에서 모은다 (재설계 2단계 빈틈: 읽기가 없으면 한국어·영어 화면에 지금 이름이 나온다).
# 1) 그 역 자신의 문서(data/imports/wiki/station.json 연혁)에서 「옛이름駅（よみえき）」
# 2) 없으면 전문 검색으로 「옛이름駅」이 나오는 문서를 받아 같은 꼴을 찾는다. 문서마다 읽기가 다르면 넣지 않는다
# 읽기 추정은 하지 않는다 (사용자 결정 19: 일본 사이트 표기). 결과: data/overrides/old_names_kana.json {"node|옛이름": {kana, source}}
#   python3 -I tools/old_name_kana.py            로컬 자료만
#   python3 -I tools/old_name_kana.py --fetch    위키 조회까지 (3초 간격, 이어서 받기 가능)
import sys,os,re,json,time,sqlite3,urllib.parse,urllib.request,urllib.error
sys.path.insert(0,os.path.dirname(__file__))
from lib import ROOT,BUILD
OUT=os.path.join(ROOT,'data','overrides','old_names_kana.json')
CACHE=os.path.join(ROOT,'data','candidates','old_name_kana_cache.json')   # 조회 기록(로컬). data/imports는 출처 잠금 대상이라 두지 않는다
UA={'User-Agent':'noriori-data/0.1 (low rate)'}
API='https://ja.wikipedia.org/w/api.php?format=json&formatversion=2&'
done=json.load(open(OUT,encoding='utf-8')) if os.path.exists(OUT) else {}
cache=json.load(open(CACHE,encoding='utf-8')) if os.path.exists(CACHE) else {}
st=json.load(open(os.path.join(ROOT,'data','imports','wiki','station.json'),encoding='utf-8'))
nm=sqlite3.connect('file:'+os.path.join(BUILD,'names.sqlite')+'?mode=ro',uri=True)
cur={e:t for e,t in nm.execute("select entity_id,text from name where entity_type='node' and lang='ja' and line_id is null and valid_from is null and valid_to is null")}
want=nm.execute("select distinct entity_id,text from name where entity_type='node' and lang='ja' and valid_to is not null and kana is null").fetchall()
SUF='(?:駅|停留場|停留所|電停)'
def pat(o):
    # 앞은 이름 경계여야 한다 (上相ノ内의 「相ノ内」, 崇城大学前의 「大学前」을 잡지 않게)
    # 굵은 글씨 표시(\'\'\'万世橋駅\'\'\'（まんせいばしえき、…）)와, 한자로 시작하는 이름 앞의 조사·접속 끝(「…に伴い舌辛駅（したからえき）」)도 이름 경계다 (R 갈래 지적, 9회차 N)
    hb=r'|伴い|により|および|や|と|で|に|へ|も' if o and re.match(r'[一-鿿々]',o) else ''
    return re.compile(r"(?:^|[\s|\[・、。「『（(：:=!']|は|を|が|の|として|から"+hb+r")"+re.escape(o)+SUF+r"(?:''')?\]?\]?(?:''')?\s*[（(]\s*([ぁ-んゔー・]{2,30}?)\s*(?:えき|ていりゅうじょう|ていりゅうしょ|でんてい)?\s*[）)、,]",re.M)
def own(e,o):
    b=re.sub(r'（.*?）$','',cur.get(e,''))
    for t in (b+'駅',b+'停留場',b+'停留所',b+'電停'):
        a=st.get(t)
        if not a:continue
        m=pat(o).search(' '.join((a.get('hist') or [])+(a.get('alt') or [])))
        if m:return m.group(1),f'wikipedia:{t}'
    return None,None
def get(u):
    for i in range(6):
        try:
            time.sleep(3)
            return json.load(urllib.request.urlopen(urllib.request.Request(u,headers=UA),timeout=60))
        except (urllib.error.URLError,TimeoutError) as e:
            time.sleep(10*(i+1))
    return None
def search(o):
    k='s:'+o
    if k not in cache:
        r=get(API+'action=query&list=search&srlimit=8&srwhat=text&srsearch='+urllib.parse.quote(f'"{o}駅"'))
        cache[k]=[x['title'] for x in ((r or {}).get('query') or {}).get('search',[])]
    return cache[k]
def texts(titles):
    need=[t for t in titles if 'p:'+t not in cache]
    for i in range(0,len(need),20):
        r=get(API+'action=query&prop=revisions&rvprop=content|ids&rvslots=main&titles='+urllib.parse.quote('|'.join(need[i:i+20])))
        for p in ((r or {}).get('query') or {}).get('pages',[]):
            rv=(p.get('revisions') or [{}])[0]
            cache['p:'+p['title']]=[rv.get('revid'),((rv.get('slots') or {}).get('main') or {}).get('content') or '']
    return [(t,)+tuple(cache.get('p:'+t,[None,''])) for t in titles]
fetch='--fetch' in sys.argv;n=0
for e,t in want:
    o=re.sub(SUF+'$','',t);k=f'{e}|{t}'
    if k in done:continue
    kana,src=own(e,o)
    if not kana and fetch:
        got={}
        for title,rev,txt in texts(search(o)):
            m=pat(o).search(txt)
            if m:got.setdefault(m.group(1),[]).append(f'wikipedia:{title}:{rev}')
        if len(got)==1:kana,src=next(iter(got)),';'.join(next(iter(got.values()))[:3])
        elif len(got)>1:done[k]=dict(kana=None,ambiguous=sorted(got));n+=1
        else:done[k]=dict(kana=None);n+=1
        if n%20==0:
            json.dump(cache,open(CACHE,'w',encoding='utf-8'),ensure_ascii=False)
            json.dump(dict(sorted(done.items())),open(OUT,'w',encoding='utf-8'),ensure_ascii=False,indent=0)
    if kana:done[k]=dict(kana=kana,source=src);n+=1
json.dump(cache,open(CACHE,'w',encoding='utf-8'),ensure_ascii=False)
json.dump(dict(sorted(done.items())),open(OUT,'w',encoding='utf-8'),ensure_ascii=False,indent=0)
ok=sum(1 for v in done.values() if v.get('kana'))
print('읽기 찾음',ok,'못 찾음',sum(1 for v in done.values() if not v.get('kana') and not v.get('ambiguous')),'문서마다 다름',sum(1 for v in done.values() if v.get('ambiguous')),'대상',len(want))
