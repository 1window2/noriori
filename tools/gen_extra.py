# -*- coding: utf-8 -*-
# 열람 전용 항목에 옛 폐선을 더하고 이름을 붙인다. 한글 이름을 못 만든 항목은 빼고 기록한다
import sys,os,re,json,csv,collections
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from lib import *
import ko,conn
KANA={}
for a,b in json.load(open(os.path.join(IMP,'wiki_kana.json'),encoding='utf-8')).items():
    nm=a.split(':',1)[1];t=b['title']
    if znorm(nm)[:2] not in znorm(t):continue
    KANA[a]=re.sub(r'(えき|ていりゅうじょう|ていりゅうしょ|でんてい)$','',b['kana'])
KANA.update(json.load(open(os.path.join(ROOT,'data','overrides','kana.json'),encoding='utf-8')))
_e=os.path.join(ROOT,'data','overrides','kana_est.json')
if os.path.exists(_e):KANA.update(json.load(open(_e,encoding='utf-8')))
sdk={}
for s in csv.DictReader(open(os.path.join(IMP,'stationdb','station.csv'),encoding='utf-8')):
    if s['name_kana'] not in('','NULL'):sdk.setdefault(znorm(s['name']),s['name_kana'])
for s in csv.DictReader(open(os.path.join(IMP,'stationdb','line.csv'),encoding='utf-8')):
    if s['name_kana'] not in('','NULL'):sdk.setdefault('L'+znorm(conn.clean(s['name'])),s['name_kana'])
NLN=json.load(open(os.path.join(IMP,'names_lines.json'),encoding='utf-8'))
_g=os.path.join(ROOT,'data','overrides','kana_est_report.json')
GUESS=set(json.load(open(_g,encoding='utf-8')).get('guess',[])) if os.path.exists(_g) else set()
arch=load('archive')
# 위키 문서 순서와 현역 역 읽기로는 틀리는 열람 전용 역을 사람이 고친 값
FIX=json.load(open(os.path.join(ROOT,'data','overrides','archive_fix.json'),encoding='utf-8'))
for a in arch:
    if a.get('kind')=='stop':a.update({k:v for k,v in FIX.get(a.get('name'),{}).items() if k in('line','route','after','before','km')})
names=load('names')
nn=collections.defaultdict(list)
for x in names:
    if x['entity_type']=='node' and x['lang']=='ja':nn[znorm(x['text'])].append(x['id'])
rep=json.load(open(os.path.join(CAND,'old_report.json'),encoding='utf-8'))
lineja=set()
for x in names:
    if x['entity_type']=='line' and x['lang']=='ja':lineja.add(znorm(x['text']))
for l in load('lines'):
    if l.get('sd'):lineja.add(znorm(conn.clean(l['sd'])))
arch=[a for a in arch if not (a.get('kind')=='stop' and nn.get(znorm(a.get('name') or '')))]
seen={a['id'] for a in arch}
seenk=set()
for a in rep['archive']:
    if not re.search(r'(線|鉄道|鐵道|電鉄|電車|ケーブル|登山)$',a['name']) or a['name'] in('不要不急線','特定地方交通線'):continue
    if znorm(a['name']) in lineja:continue
    nk=znorm(a['name']).replace('電気鉄道','電鉄').replace('精練','製錬')
    nk=re.sub(r'線$','',nk)
    if any(nk==k or nk.startswith(k) or k.startswith(nk) for k in seenk):continue
    seenk.add(nk)
    at=None
    for s in a.get('stations') or []:
        if len(set(nn.get(znorm(s),[])))==1:at=nn[znorm(s)][0];break
    i='a_'+stable('line',a['name'])
    if i in seen:continue
    seen.add(i)
    arch.append(dict(kind='line',id=i,name=a['name'],at=at,closed=a.get('closed'),source=f"wikipedia:{a.get('revid')}"))
out=[];rows=[];drop=[]
TODAY=AS_OF
for a in arch:
    n=a.get('name')
    t=None;kana=None;src='rule'
    fix=FIX.get(n,{}) if a['kind']=='stop' else {}
    if a['kind']=='stop':
        kana=fix.get('kana') or KANA.get('node:'+n) or sdk.get(znorm(n))
        if kana:
            hk=kata2hira(kana);v=ko.NW.get(n+'|'+hk);t=v[0] if v else ko.station(hk,n)
            if v and v[1]=='namuwiki' and ko.rule_only(ko.station,hk,n)!=t:src='namuwiki'   # 표의 값이 규칙과 다르면 표가 출처다
    else:
        # 위키 노선도의 이름과 나무위키 표의 이름이 다른 노선
        nk={'姫路市交通局モノレール線':'姫路市営モノレール'}.get(n,n)
        if nk in NLN:
            t=NLN[nk][0];kk=KANA.get('line:'+n) or KANA.get('node:'+n) or sdk.get('L'+znorm(n))
            if NLN[nk][1]=='namuwiki' and (nk!=n or not(kk and ko.rule_only(ko.line,kata2hira(kk),n)==t)):src='namuwiki'
        elif n in conn.LABEL:t=conn.LABEL[n]
        else:
            kana=KANA.get('line:'+n) or KANA.get('node:'+n) or sdk.get('L'+znorm(n))
            if kana:t=ko.line(kata2hira(kana),n)
    t={'西鉄戸畑線':'니시테츠 토바타선','西鉄北方線':'니시테츠 키타카타선','岡山臨港鉄道':'오카야마 임항철도'}.get(n,t)
    if not t:drop.append(n);continue
    b={k:v for k,v in a.items() if k!='name'}
    out.append(b)
    if fix.get('ko'):t=fix['ko'];src='hand'
    rows.append(dict(entity_type='archive',id=a['id'],lang='ja',text=n,kana=kana,source='wikipedia'))
    rows.append(dict(entity_type='archive',id=a['id'],lang='ko',text=t,source='estimated' if ('node:'+n in GUESS or 'line:'+n in GUESS) else src,checked=TODAY))
for f in os.listdir(os.path.join(SRC,'archive')):os.remove(os.path.join(SRC,'archive',f))
dump('archive/archive.yaml',out,'열람 전용 역·노선')
dump('names/archive.yaml',rows,'열람 전용 이름')
os.makedirs(CAND,exist_ok=True)
json.dump(drop,open(os.path.join(CAND,'archive_noname.json'),'w',encoding='utf-8'),ensure_ascii=False)
print('열람 전용',len(out),'이름 없어 뺌',len(drop),drop[:30])
