# -*- coding: utf-8 -*-
# 열람 전용 항목에 옛 폐선을 더하고 이름을 붙인다. 한글 이름을 못 만든 항목은 빼고 기록한다
import sys,os,re,json,csv,collections
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from lib import *
import ko,conn,unicodedata
from gen_en_names import line_name
KANA={}
for a,b in json.load(open(os.path.join(IMP,'wiki','kana.json'),encoding='utf-8')).items():
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
NLN=json.load(open(os.path.join(IMP,'namuwiki','names_lines.json'),encoding='utf-8')) if source_on('namuwiki') else {}
_g=os.path.join(ROOT,'data','overrides','kana_est_report.json')
GUESS=set(json.load(open(_g,encoding='utf-8')).get('guess',[])) if os.path.exists(_g) else set()
arch=load('archive')
# N05 노선의 km 없는 역 (gen_source가 만든 후보)
_n=os.path.join(CAND,'n05_arch.json')
if os.path.exists(_n):arch+=json.load(open(_n,encoding='utf-8'))
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
# N05와 대조하지 못한 옛 폐선 중 위키 역 목록으로 순서를 아는 것 (tools/gen_n05.py). 읽기가 없으면 ID를 못 만들어 넣지 않는다
_r=os.path.join(CAND,'n05_report.json')
for a in (json.load(open(_r,encoding='utf-8')).get('report',[]) if os.path.exists(_r) else []):
    n=a.get('name')
    if a['result']!='archive' or not n or znorm(n) in lineja or not (KANA.get('line:'+n) or sdk.get('L'+znorm(n))):continue
    nk=re.sub(r'線$','',znorm(n))
    if any(nk==k or nk.startswith(k) or k.startswith(nk) for k in seenk):continue
    seenk.add(nk)
    at=next((nn[znorm(s)][0] for s in a.get('order') or [] if len(set(nn.get(znorm(s),[])))==1),None)
    i='a_'+stable('line',n)
    if i in seen:continue
    seen.add(i)
    arch.append(dict(kind='line',id=i,name=n,at=at,closed=f"{a['closed_year']}-XX-XX",source=f"wikipedia:{a.get('revid')}" if a.get('revid') else 'n05'))
out=[];rows=[];drop=[];KA={}
TODAY=AS_OF
for a in arch:
    n=a.get('name')
    t=None;kana=None;src='rule'
    fix=FIX.get(n,{}) if a['kind']=='stop' else {}
    if a['kind']=='stop':
        kana=fix.get('kana') or KANA.get('node:'+n) or sdk.get(znorm(n))
        if kana:
            hk=kata2hira(kana);v=ko.NW.get(n+'|'+hk);t=v[0] if v else ko.station(hk,n)
            if v and v[1]=='namuwiki':src='namuwiki'   # 나무위키 제목이 있으면 규칙과 같아도 출처는 나무위키 (DESIGN §9.2)
    else:
        # 위키 노선도의 이름과 나무위키 표의 이름이 다른 노선
        nk=HT['WIKI_TITLE'].get(n,n)
        if nk in NLN:
            t=NLN[nk][0]
            if NLN[nk][1]=='namuwiki':src='namuwiki'
        elif n in conn.LABEL:t=conn.LABEL[n]
        else:
            kana=KANA.get('line:'+n) or KANA.get('node:'+n) or sdk.get('L'+znorm(n))
            if kana:t=ko.line(kata2hira(kana),n)
    t=HT['ARCH_KO'].get(n,t)
    if not t:drop.append(n);continue
    b={k:v for k,v in a.items() if k!='name'}
    out.append(b)
    if fix.get('ko'):t=fix['ko'];src='hand'
    KA[a['id']]=kana or (KANA.get('line:'+n) or KANA.get('node:'+n) or sdk.get('L'+znorm(n)) if a['kind']=='line' else None)
    rows.append(dict(entity_type='archive',id=a['id'],lang='ja',text=n,kana=kana,source='wikipedia'))
    rows.append(dict(entity_type='archive',id=a['id'],lang='ko',text=t,source='estimated' if ('node:'+n in GUESS or 'line:'+n in GUESS) else src,checked=TODAY))
# 열람 전용 ID는 영어 이름이다 (DESIGN §2.10). 읽기를 로마자로 옮기고, 겹치면 노선 이름, 그래도 겹치면 앞 역 이름을 붙인다
def slug(i):return re.sub(r'_line$','',re.sub(r'^[a-z]+_','',i or ''))
JA={r['id']:r['text'] for r in rows if r['lang']=='ja'}
NEW={};taken=set();nokana=[]
for b in sorted(out,key=lambda b:(b['kind'],b.get('line') or '',b.get('after') or '',JA.get(b['id']) or '')):
    k=KA.get(b['id'])
    if not k:nokana.append(JA.get(b['id']));continue
    # 역은 노드처럼 읽기의 로마자, 노선은 노선 ID처럼 영어 이름 (gen_en_names의 규칙)
    base='a_'+(re.sub(r'[^a-z]+','_',unicodedata.normalize('NFKD',line_name(JA.get(b['id']),kata2hira(k))).encode('ascii','ignore').decode().lower()).strip('_') if b['kind']=='line' else romaji(k));c=base
    for h in (slug(b.get('line')),slug(b.get('after') or b.get('at'))):
        if c not in taken:break
        if h:c=c+'_'+h
    if c in taken:raise SystemExit(f'열람 전용 ID가 겹칩니다: {c} ({JA.get(b["id"])})')
    taken.add(c);NEW[b['id']]=c
if nokana:raise SystemExit(f'읽기가 없어 열람 전용 ID를 만들 수 없습니다 ({len(nokana)}): {nokana}. data/overrides/kana_est.json에 읽기를 넣으세요')
for b in out:
    for k in ('after','before'):
        if b.get(k) in NEW:b[k]=NEW[b[k]]
    b['id']=NEW[b['id']]
for r in rows:r['id']=NEW[r['id']]
for f in os.listdir(os.path.join(SRC,'archive')):os.remove(os.path.join(SRC,'archive',f))
dump('archive/archive.yaml',out,'열람 전용 역·노선')
dump('names/archive.yaml',rows,'열람 전용 이름')
os.makedirs(CAND,exist_ok=True)
json.dump(drop,open(os.path.join(CAND,'archive_noname.json'),'w',encoding='utf-8'),ensure_ascii=False)
print('열람 전용',len(out),'이름 없어 뺌',len(drop),drop[:30])
