# -*- coding: utf-8 -*-
# 읽기가 없는 역·노선·회사의 읽기를 일본어 위키백과 첫 문장에서 가져온다. 20건씩 묶어 저속 조회
import sys,re,json,time,os,urllib.parse,urllib.request,urllib.error
IN,OUT=sys.argv[1:3]
UA={'User-Agent':'noriori-data/0.1 (personal open-source rail record app; low rate)'}
API='https://ja.wikipedia.org/w/api.php?format=json&formatversion=2&action=query&prop=extracts&exintro=1&explaintext=1&redirects=1&exlimit=20&titles='
done=json.load(open(OUT,encoding='utf-8')) if os.path.exists(OUT) else {}
want=json.load(open(IN,encoding='utf-8'))   # [[키, 제목 후보...],...]
RX=re.compile(r'[（(]\s*([ぁ-んゔー・\s]{2,40}?)\s*[、,，）)]')
def get(u):
    for a in range(6):
        try:return json.load(urllib.request.urlopen(urllib.request.Request(u,headers=UA),timeout=60))
        except urllib.error.HTTPError as e:
            if e.code in(429,503):time.sleep(int(e.headers.get('Retry-After') or 30)+5)
            else:return None
        except Exception:time.sleep(8)
titles={}
for w in want:
    if w[0] in done:continue
    for t in w[1:]:titles.setdefault(t,w[0])
L=list(titles)
for i in range(0,len(L),20):
    b=L[i:i+20]
    d=get(API+urllib.parse.quote('|'.join(b)))
    if not d:continue
    q=d['query'];nm={}
    for x in q.get('normalized',[]):nm[x['to']]=x['from']
    rd={}
    for x in q.get('redirects',[]):rd[x['to']]=x['from']
    for p in q['pages']:
        t=p.get('title','');s=p.get('extract') or ''
        if not s:continue
        o=rd.get(t,t);o=nm.get(o,o)
        k=titles.get(o)
        if k is None or k in done:continue
        m=RX.search(s[:200])
        if m and t.split('駅')[0][:1] in s[:60]:
            done[k]=dict(kana=m.group(1).replace(' ','').replace('・',''),title=t)
    json.dump(done,open(OUT,'w',encoding='utf-8'),ensure_ascii=False,indent=0)
    time.sleep(1.5)
print('kana',len(done))
