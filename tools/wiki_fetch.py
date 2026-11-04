# -*- coding: utf-8 -*-
# 일본어 위키백과 노선 문서를 revid와 함께 저속으로 받아 둔다. 이미 받은 문서는 건너뛴다
import csv,sys,re,json,os,time,gzip,hashlib,urllib.parse,urllib.request,urllib.error
TITLES,OUT=sys.argv[1:3]
UA={'User-Agent':'noriori-data/0.1 (personal open-source rail record app; low rate)'}
API='https://ja.wikipedia.org/w/api.php?format=json&formatversion=2&'
def get(u,t=90):
    for a in range(6):
        try:return json.load(urllib.request.urlopen(urllib.request.Request(u,headers=UA),timeout=t))
        except urllib.error.HTTPError as e:
            if e.code in(429,503,504):time.sleep(int(e.headers.get('Retry-After') or 30)+5)
            else:return None
        except Exception:time.sleep(8)
    return None
def resolve(t):
    d=get(API+'action=query&redirects=1&titles='+urllib.parse.quote(t))
    # 오류 응답에는 query가 없다. 못 찾은 것으로 본다
    if d and 'query' in d and not d['query']['pages'][0].get('missing'):return d['query']['pages'][0]['title']
    d=get(API+'action=query&list=search&srlimit=5&srnamespace=0&srsearch='+urllib.parse.quote(t+' 鉄道 路線'))
    if not d or 'query' not in d:return None
    core=re.sub(r'(線|本線|鉄道)$','',t)
    for h in d['query']['search']:
        if core[-4:] in h['title']:return h['title']
    return None
names=[l.strip() for l in open(TITLES,encoding='utf-8') if l.strip()]
n=0
for t in names:
    f=os.path.join(OUT,hashlib.md5(t.encode()).hexdigest()[:14]+'.json.gz')
    if os.path.exists(f):continue
    rec={'name':t,'title':None,'revid':None,'html':None,'wikitext':None,'fetched':time.strftime('%Y-%m-%d')}
    r=resolve(t);time.sleep(1.2)
    if r:
        rec['title']=r
        d=get(API+'action=parse&redirects=1&prop=text|revid|wikitext&page='+urllib.parse.quote(r))
        if d and 'parse' in d:
            p=d['parse'];rec['revid']=p.get('revid');rec['title']=p.get('title',r);rec['html']=p.get('text');rec['wikitext']=p.get('wikitext')
    with gzip.open(f,'wt',encoding='utf-8') as o:json.dump(rec,o,ensure_ascii=False)
    n+=1
    if n%25==0:print(n,t,flush=True)
    time.sleep(1.6)
print('done',n,flush=True)
