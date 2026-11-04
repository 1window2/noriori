# -*- coding: utf-8 -*-
# 역 문서의 {{駅情報}}에서 사업자별 개업일·폐지일·읽기를 모은다. 결과: data/imports/wiki/station.json
# 전문을 읽어 인포박스 블록과 연혁 줄을 남긴다. 각주 틀은 지운다
import sys,os,re,json,time,urllib.parse,urllib.request,urllib.error
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from lib import *
UA={'User-Agent':'noriori-data/0.1 (personal open-source rail record app; low rate)'}
API='https://ja.wikipedia.org/w/api.php'
OUT=os.path.join(IMP,'wiki','station.json')
# 다시 받을 때는 파일을 지우고 돌린다
D=json.load(open(OUT,encoding='utf-8')) if os.path.exists(OUT) else {}
def save():json.dump(D,open(OUT,'w',encoding='utf-8'),ensure_ascii=False,indent=0)
def get(q):
    u=API+'?'+urllib.parse.urlencode(q)
    for a in range(7):
        try:return json.load(urllib.request.urlopen(urllib.request.Request(u,headers=UA),timeout=120))
        except urllib.error.HTTPError as e:
            if e.code in(429,503):time.sleep(int(e.headers.get('Retry-After') or 30)+5)
            else:print('http',e.code);return None
        except Exception as e:
            print('err',str(e)[:80]);time.sleep(10)
def blocks(t):
    """{{駅情報 ...}} 블록을 괄호 짝으로 잘라낸다"""
    o=[]
    for m in re.finditer(r'\{\{\s*駅情報',t):
        i=m.start();d=0;j=i
        while j<len(t)-1:
            if t[j:j+2]=='{{':d+=1;j+=2;continue
            if t[j:j+2]=='}}':
                d-=1;j+=2
                if d==0:break
                continue
            j+=1
        o.append(t[i:j])
    return o
def strip_tmpl(s):
    """각주 틀은 안쪽 날짜가 인포박스 값으로 읽히므로 괄호 짝까지 지운다"""
    for m in list(re.finditer(r'\{\{\s*(?:Refnest|refnest|Efn|efn|Efn2|efn2|注釈|R|Sfn|sfn|Refn|refn|要出典|要出典範囲|Cite[^|}]*)\b',s))[::-1]:
        i=m.start();d=0;j=i
        while j<len(s)-1:
            if s[j:j+2]=='{{':d+=1;j+=2;continue
            if s[j:j+2]=='}}':
                d-=1;j+=2
                if d==0:break
                continue
            j+=1
        s=s[:i]+s[j:]
    return s
def clean(s):
    s=re.sub(r'<ref[^>]*?/>','',s);s=re.sub(r'<ref.*?</ref>','',s,flags=re.S);s=re.sub(r'<!--.*?-->','',s,flags=re.S)
    s=strip_tmpl(s)
    s=re.sub(r'\[\[(?:[^\]|]*\|)?([^\]]*)\]\]',r'\1',s)
    return s
def dates(s):
    s=clean(s)
    # 여객과 화물·신호장 날짜가 나란히 적혀 있으면 여객 쪽만 쓴다
    seg=[x for x in re.split(r'<br\s*/?>|\n',s) if re.search(r'\d{4}年',x)]
    keep=[x for x in seg if not re.search('貨物|信号場|信号所',x) or '旅客' in x]
    if keep and len(keep)<len(seg):s='\n'.join(keep)
    o=[]
    for m in re.finditer(r'\{\{\s*(?:start date(?: and age)?|Start date(?: and age)?|開業年月日)\s*\|\s*(\d{4})\s*\|\s*(\d+)\s*\|\s*(\d+)',s):o.append('%04d-%02d-%02d'%tuple(int(x) for x in m.groups()))
    s=re.sub(r'[（(][^）)]{0,20}[）)]','',s)
    for m in re.finditer(r'(\d{4})年\s*(?:(\d{1,2})月\s*(?:(\d{1,2})日)?)?',s):
        y,mo,da=m.groups()
        o.append(f'{y}-{int(mo):02d}-{int(da):02d}' if da else (f'{y}-{int(mo):02d}-XX' if mo else f'{y}-XX-XX'))
    return o
FIELD=re.compile(r'\n\s*\|\s*([^=|\n]+?)\s*=(.*?)(?=\n\s*\|\s*[^=|\n]+?\s*=|\Z)',re.S)
def parse(b):
    f={m.group(1).strip():m.group(2) for m in FIELD.finditer(b)}
    r={}
    for k,a in (('ops','所属事業者'),('lines','所属路線'),('addr','所在地')):
        if f.get(a):r[k]=clean(f[a]).strip()[:300]
    if f.get('よみがな'):r['kana']=clean(f['よみがな']).strip()[:60]
    if dates(f.get('開業年月日','')):r['open']=dates(f['開業年月日'])
    if dates(f.get('廃止年月日','')):r['close']=dates(f['廃止年月日'])
    xf=' '.join(re.sub(r'\s+',' ',clean(f[a])) for a in('乗換','接続路線') if f.get(a))
    if xf.strip():r['xf']=xf.strip()[:400]
    return r
HK=re.compile('改称|改名|駅名|移転|信号場|信号所|旅客|貨物|廃止|開業|昇格|休止|再開|統合|乗降場')
def hist(c):
    """연혁 절의 날짜 줄 중 역의 변화를 적은 것만 남긴다"""
    o=[]
    for l in c.split('\n'):
        if l[:1]!='*' or not re.search(r'\d{4}年',l):continue
        t=re.sub(r"'''?",'',clean(l)).strip('* ')
        if HK.search(t):o.append(t[:140])
    return o[:40]
def fetch(titles,full=True):
    """titles를 40개씩 전문으로 읽어 D[요청 제목]에 넣는다"""
    titles=[t for t in titles if t not in D]
    for i in range(0,len(titles),40):
        b=titles[i:i+40]
        q=dict(action='query',prop='revisions',rvprop='content',rvslots='main',titles='|'.join(b),redirects=1,format='json',formatversion=2)
        cont={}
        while True:
            d=get({**q,**cont})
            if not d:break
            qq=d.get('query',{})
            nm={x['to']:x['from'] for x in qq.get('normalized',[])}
            rd={x['to']:x['from'] for x in qq.get('redirects',[])}
            for p in qq.get('pages',[]):
                t=p.get('title','');o=rd.get(t,t);o=nm.get(o,o)
                if p.get('missing'):D[o]=dict(missing=True);continue
                revs=p.get('revisions')
                if not revs:continue
                c=revs[0].get('slots',{}).get('main',{}).get('content','') or ''
                bl=[parse(x) for x in blocks(c)]
                e=dict(title=t,blocks=bl,full=True,hist=hist(c))
                e['aimai']=bool(re.search(r'\{\{\s*(?:aimai|Aimai|曖昧さ回避|駅名の曖昧さ回避|地名の曖昧さ回避)',c))
                alt=set(re.findall(r'[^\[\]|{}\n=]{1,20}(?:駅|停留場)\s*[（(][^\[\]|{}\n）)]{1,20}[）)]',c if len(c)<30000 else c[:3000]))
                e['alt']=sorted(a.replace('（',' (').replace('）',')').strip() for a in alt)[:30]
                D[o]=e
            cont=d.get('continue') or {}
            if not cont or 'rvcontinue' not in cont:break
            time.sleep(1.2)
        save();time.sleep(1.5)
        if i%2000==0:print(i,len(titles),flush=True)
names=load('names')
nm=set()
for x in names:
    if x['entity_type']=='node' and x['lang']=='ja':nm.add(x['text'])
nm={re.sub(r'[（(].*?[)）]','',x).strip() for x in nm}
T=sorted({(x if x.endswith('駅') else x+'駅') for x in nm})
print('제목',len(T),flush=True)
fetch(T)
# 동음이의 제목과 머리 주석의 다른 역
A=set()
for t in T:
    e=D.get(t) or {}
    A|=set(e.get('alt') or [])
A={a for a in A if a not in D and '駅' in a or '停留場' in a}
print('다른 문서',len(A),flush=True)
fetch(sorted(A))
# 노면전차 정류장
S=sorted({x+'停留場' for x in nm if (D.get(x+'駅') or {}).get('missing')})
print('정류장',len(S),flush=True)
fetch(S)
print('끝',len(D),flush=True)
