# -*- coding: utf-8 -*-
# 시드 자료(노리츠부시 표, station_database, Wikidata, 이름 표)를 data/source 모듈로 만든다
# 사람이 고친 값은 data/overrides/*.json에 두고 여기서 덮어쓴다
import sys,os,re,json,csv,collections,math,shutil,gzip,unicodedata
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from lib import *
import ko
import conn
import en_rules

ONLY=set(sys.argv[1].split(',')) if len(sys.argv)>1 and sys.argv[1]!='all' else None   # 예: jr1 (JR 홋카이도만)
DB=os.path.join(IMP,'stationdb')
N=json.load(open(os.path.join(IMP,'noritsubushi','lines.json'),encoding='utf-8'))
if os.path.exists(os.path.join(IMP,'stationdb','old_lines.json')):N+=json.load(open(os.path.join(IMP,'stationdb','old_lines.json'),encoding='utf-8'))
# N05와 교차 검증한 옛 폐선 (tools/gen_n05.py). N05를 끄면 빈 목록이다
N5=json.load(open(os.path.join(IMP,'n05','lines.json'),encoding='utf-8')) if os.path.exists(os.path.join(IMP,'n05','lines.json')) and source_on('n05') else []
N+=N5
N5NAMES={re.search(r'【(?:.* )?(.+?)】',x['t']).group(1) for x in N5}
# N05 노선 읽기(위키 문서 첫 줄)는 다른 읽기가 없을 때만. 같은 이름의 기존 노선 읽기를 바꾸면 그 노선의 ID가 바뀐다
N5KANA={x['cn']+'|'+re.search(r'【(?:.* )?(.+?)】',x['t']).group(1):x['line_kana'] for x in N5 if x.get('line_kana')}

JRCO={1:'o_jr_hokkaido',2:'o_jr_east',3:'o_jr_central',4:'o_jr_west',5:'o_jr_shikoku',6:'o_jr_kyushu'}
JRJA={'o_japanese_national_railways':'日本国有鉄道','o_jr_hokkaido':'JR北海道','o_jr_east':'JR東日本','o_jr_central':'JR東海','o_jr_west':'JR西日本','o_jr_shikoku':'JR四国','o_jr_kyushu':'JR九州'}
JRKO={'o_japanese_national_railways':'국철','o_jr_hokkaido':'JR 홋카이도','o_jr_east':'JR 동일본','o_jr_central':'JR 도카이','o_jr_west':'JR 서일본','o_jr_shikoku':'JR 시코쿠','o_jr_kyushu':'JR 큐슈'}
BRT={tuple(x) for x in HT['BRT']}
LEGAL=HT['LEGAL']

# ---- 원천 읽기
KANA={}
_k=os.path.join(IMP,'wiki','kana.json')
if os.path.exists(_k):
    for a,b in json.load(open(_k,encoding='utf-8')).items():
        nm=a.split(':',1)[1];t=b['title']
        if znorm(nm)[:2] not in znorm(t):continue
        KANA[a]=re.sub(r'(えき|ていりゅうじょう|ていりゅうしょ|でんてい)$','',b['kana'])
_k=os.path.join(ROOT,'data','overrides','kana.json')
if os.path.exists(_k):KANA.update(json.load(open(_k,encoding='utf-8')))
NAMEKO=json.load(open(os.path.join(ROOT,'data','overrides','names_ko.json'),encoding='utf-8'))
_e=os.path.join(ROOT,'data','overrides','kana_est.json')
if os.path.exists(_e):KANA.update(json.load(open(_e,encoding='utf-8')))
for x in N5:
    for a,k in x.get('kana',{}).items():KANA.setdefault('node:'+a,k)
_g=os.path.join(ROOT,'data','overrides','kana_est_report.json')
GUESS=set(json.load(open(_g,encoding='utf-8')).get('guess',[])) if os.path.exists(_g) else set()
OPKO=json.load(open(os.path.join(ROOT,'data','overrides','operators_ko.json'),encoding='utf-8')) if os.path.exists(os.path.join(ROOT,'data','overrides','operators_ko.json')) else {}
SD=list(csv.DictReader(open(DB+'/station.csv',encoding='utf-8')))
SL=list(csv.DictReader(open(DB+'/line.csv',encoding='utf-8')))
REG=list(csv.DictReader(open(DB+'/register.csv',encoding='utf-8')))
sl={l['code']:l for l in SL}
st_lines=collections.defaultdict(set)
for r in REG:st_lines[r['station_code']].add(r['line_code'])
byname=collections.defaultdict(list)
for s in SD:
    s['lat_']=float(s['lat']);s['lng_']=float(s['lng'])
    s['base']=[znorm(conn.clean(sl[c]['name'])) for c in st_lines[s['code']]]
    s['comp']={sl[c]['company_code'] for c in st_lines[s['code']]}
    for nm in {znorm(s['name']),znorm(s['original_name'])}:byname[nm].append(s)
def dist(a,b):
    if not a or not b:return 1e9
    p=math.radians((a[0]+b[0])/2)
    return math.hypot((a[0]-b[0])*111.0,(a[1]-b[1])*111.0*math.cos(p))
WD=collections.defaultdict(list)
wdraw=json.load(open(os.path.join(IMP,'wikidata','stations.json'),encoding='utf-8'))['results']['bindings'] if source_on('wikidata') else []
_w={}
for r in wdraw:
    q=r['s']['value'].rsplit('/',1)[1];x=_w.setdefault(q,{'q':q,'lines':set()})
    for k in('ja','ko','en','kana','open','close','dis','inc'):
        if k in r:x.setdefault(k,r[k]['value'])
    if 'coord' in r and 'pt' not in x:
        m=re.match(r'Point\(([-\d.]+) ([-\d.]+)\)',r['coord']['value'])
        if m:x['pt']=(float(m.group(2)),float(m.group(1)))
    if 'lineLabel' in r:x['lines'].add(r['lineLabel']['value'])
for x in _w.values():
    x['opens']=set()
for r in wdraw:
    if 'open' in r:_w[r['s']['value'].rsplit('/',1)[1]]['opens'].add(r['open']['value'])
for x in _w.values():
    if x['opens']:x['open']=min(x['opens'])
    if 'ja' in x:
        WD[znorm(re.sub(r'\s*[（(].*?[)）]\s*','',x['ja']))].append(x)
def wdday(v):
    if not v or not re.match(r'^\d{4}-\d\d-\d\d',v):return None
    d=v[:10]
    if d.endswith('-01-01'):return d[:4]+'-XX-XX'
    return d

SIGNALISH=re.compile(r'(信号場|分岐点|信号所|貨物ターミナル|貨物駅|操車場|接続点)$')
def prx_op(p):
    return PUB.get(PRX[p.name],PRX[p.name]) if p.name in PRX else 'o_tokyu_railways'
_ids=json.load(open(os.path.join(ROOT,'data','imports','id_map.json'),encoding='utf-8'))
PUB=_ids['ids'];OLD={v:k for k,v in PUB.items()};FAM=_ids['family'];FAM_OLD={v:k for k,v in FAM.items()}
PRXN=HT['PRXN']
PRX={}
LINEKANA=json.load(open(os.path.join(ROOT,'data','overrides','lines_kana.json'),encoding='utf-8'))
# ---- 부품 파싱
_co={}
for x in N:
    if x.get('cn') and x['g']=='pr':_co[x['cn']]=str(x['c'])
for a,b in PRXN.items():PRX[a]='o_'+_co[b]
RENAME=HT['RENAME']
# station_database 역에 붙이지 않는 역. 같은 이름의 다른 자리 (東唐津: 1983년, 楓: 1981년, 常磐線 新地·坂元·山下: 2016년 이전 전의 옛 역)
NOSD={tuple(x) for x in HT['NOSD']}
# 원천 좌표가 같은 이름의 다른 지방 역을 가리키는 노드. 묶음 판정 전에 고친다 (좌표, 출처, 도도부현)
POSFIX={k:(v['lat'],v['lon'],v['src'],v['pref']) for k,v in HT['POSFIX'].items()}
LINEOPEN=HT['LINEOPEN']
BYLINEKO=HT['BYLINEKO']
SUSPENDED=json.load(open(os.path.join(ROOT,'data','overrides','suspended.json'),encoding='utf-8'))
JAFIX=HT['JAFIX']
N02AL=HT['N02AL']
STOPCLOSE=HT['STOPCLOSE']
FORCE_PAIR={tuple(x) for x in HT['FORCE_PAIR']}
BRTDAY={tuple(x[:-1]):x[-1] for x in HT['BRTDAY']}
LAST=HT['LAST']
# 재해로 끊긴 채 끝난 구간: 노선 -> [(역, 역, 실제 마지막 운행일)]
SVC={k:[tuple(x) for x in v] for k,v in HT['SVC'].items()}
OPENFIX={k:[tuple(x) for x in v] for k,v in HT['OPENFIX'].items()}
# 노리츠부시 표에 현재 회사만 있는 노선의 앞선 사업자: 노선 -> (앞선 회사, 바뀐 날)
OPHIST={k:tuple(v) for k,v in HT['OPHIST'].items()}
OPHIST_KO=HT['OPHIST_KO']
OPHIST_ID=HT['OPHIST_ID']
REASON=HT['REASON']
class P:pass
parts=[]
RX=re.compile(r'^(.+?)(?: \((.+?)\))? (\S.*?) ～ (\S.*?) 営業km: ([\d.]+)$')
for x in N:
    m=RX.match(x['t'])
    p=P();p.id=x['id'];p.g=x['g'];p.c=str(x['c']);p.cn=x.get('cn') or ''
    p.x_svc=x.get('svc') or [];p.x_legal=x.get('legal') or []
    p.n05pt=x.get('n05pt') or {};p.arch=x.get('arch') or [];p.jr=bool(x.get('jr'))
    # 값의 출처. 노리츠부시 표가 기본이고 옛 폐선 표(gen_old)는 부품마다 적혀 있다
    p.s={k:(x.get('src') or {}).get(k,'noritsubushi') for k in ('km','stop','line','open','close','op')};p.hand_open=set()
    if m:p.name,p.paren,p.frm,p.to,km=m.groups();p.km=float(km)
    else:
        m2=re.search(r'【(.+?)(?: \((.+?)\))?】',x['t'])
        p.name,p.paren=m2.groups();p.frm=x['s'][0][0];p.to=x['s'][-1][0];p.km=float(x['s'][-1][1])
    if p.g=='prx':p.name=p.name.split()[-1]
    elif p.cn and p.name.startswith(p.cn+' '):p.name=p.name[len(p.cn)+1:]
    m3=re.search(r'(\d{4}-\d\d-\d\d)\s*まで|～(\d{4}-\d\d-\d\d)',p.paren or '')
    p.until=(m3.group(1) or m3.group(2)) if m3 else None
    p.open=[];p.close=[]
    for t in x.get('h',[]):
        if not t:continue
        h=''.join(t[0])
        if '開業日' in h:p.open=[r for r in t[1:] if len(r)>=3]
        elif '廃止日' in h:p.close=[r for r in t[1:] if len(r)>=3]
    p.st=[]
    for lab,k in x['s']:
        o=P();o.label=lab;o.km=float(k);o.n05=p.n05pt.get(lab)
        o.closed=lab.startswith('*') or lab.endswith('*')
        o.hidden=lab.startswith('[') and lab.endswith(']')
        o.old='【旧】' in lab
        if o.old:o.closed=True
        o.name=re.sub(r'^\(臨\)','',lab.strip('*').strip('[]').strip()).replace('【旧】','')
        o.kind=None
        if o.name.startswith('〈貨〉'):o.kind='freight'
        if o.name.endswith('(信)'):o.kind='signal'
        o.name=re.sub(r'^〈貨〉|\((信|仮)\)$','',o.name)
        o.alt=(re.search(r'（旧(.*?)）',o.name) or [None,None])[1]
        o.name=re.sub(r'（旧.*?）','',o.name);o.nm=znorm(o.name)
        o.mnm=RENAME.get(o.nm,o.nm) if x['g'] in('tm','old') else o.nm
        if x['g'] in('jrx','prx') and re.search('（.*(方|通過|八木西口).*）',lab):o.nm=o.name;o.mnm=o.name;o.hidden=True
        p.st.append(o)
    p.family='jr' if p.g in('jr','jrx') or (p.g=='tm' and p.c=='9') or p.jr else ('p'+PRX[p.name][2:] if p.g=='prx' else 'p'+p.c)
    if p.g=='prx':p.c=PRX[p.name][2:]
    p.extra=p.g=='ex'
    parts.append(p)
# 위키 노선도에만 있는 옛 역(1970년 이후 폐지)을 km 위치에 끼워 넣는다
# 끼워 넣은 뒤에는 같은 후보가 다시 나오지 않으므로 지금까지의 목록을 입력으로 둔다. 후보 폴더 없이 처음부터 돌려도 같은 역이 들어간다
INS=json.load(open(os.path.join(ROOT,'data','overrides','wiki_insert.json'),encoding='utf-8'))
_f=os.path.join(CAND,'wiki_insert.json')
if os.path.exists(_f):
    _i={(x.get('family'),x['line'],x['name']) for x in INS}
    INS+=[x for x in json.load(open(_f,encoding='utf-8')) if (x.get('family'),x['line'],x['name']) not in _i]
by_pl=collections.defaultdict(list)
for x in INS:
    x['family']=FAM_OLD.get(x.get('family'),x.get('family'))
    by_pl[(x.get('family'),x['line'])].append(x)
placed=0
for p in parts:
    for x in by_pl.get((p.family,p.name),[]):
        nm=znorm(x['name'])
        if any(o.nm==nm for o in p.st):continue
        a=next((o for o in p.st if o.nm==znorm(x['prev'] or '')),None)
        b=next((o for o in p.st if o.nm==znorm(x['next'] or '')),None)
        if not a or not b or x['next_km']==x['prev_km']:continue
        ia,ib=p.st.index(a),p.st.index(b)
        if abs(ia-ib)<1:continue
        f=(x['km']-x['prev_km'])/(x['next_km']-x['prev_km'])
        if not 0<f<1:continue
        k=round(a.km+(b.km-a.km)*f,1)
        lo,hi=sorted((ia,ib))
        o=P();o.label='*'+x['name'];o.km=k;o.closed=True;o.hidden=False;o.old=False;o.kind=None;o.alt=None;o.name=x['name'];o.nm=nm;o.mnm=nm;o.wclose=x['close'];o.wopen=x.get('open')
        pos=hi
        for j in range(lo+1,hi):
            if (p.st[j].km-k)*(1 if a.km<b.km else -1)>0:pos=j;break
        if any(abs(q.km-k)<.05 for q in p.st[lo:hi+1]):continue
        p.st.insert(pos,o);placed+=1
print('옛 역 삽입',placed)
def want(p):
    if ONLY is None:return True
    if p.g=='jr':return f'jr{p.c}' in ONLY or 'jr' in ONLY
    if p.g=='tm' and p.c=='9':return 'jr' in ONLY or 'tm' in ONLY
    return p.family in ONLY
JR_ONLY=ONLY is not None and any(o.startswith('jr') and o!='jr' for o in ONLY)
if JR_ONLY:
    # 슬라이스: 그 회사 역을 지나는 폐선만 함께 넣는다
    nm={s.nm for p in parts if want(p) for s in p.st}
    for p in parts:
        if p.g=='tm' and p.c=='9':p.keep=len({s.nm for s in p.st}&nm)>=2
    parts=[p for p in parts if want(p) and getattr(p,'keep',True)]
elif ONLY is not None:
    parts=[p for p in parts if want(p)]

for p in parts:
    p.svc=[[f'{a}～{b}','0',d] for a,b,d in SVC.get(p.name,[])]+[[f'{a}～{b}','0',d] for a,b,d in getattr(p,'x_svc',[])]
    p.legal=[[f'{a}～{b}','0',d] for a,b,d in getattr(p,'x_legal',[])]
    for a,b,d in OPENFIX.get(p.name,[]):p.open=list(p.open)+[[f'{a}～{b}','0',d]];p.hand_open.add(d)
    # 神戸高速線은 1968-04-07부터 여객 영업. 1988-04-01은 각 사의 제2종 면허 시작일이다
    if '神戸高速線' in p.name:p.open=[[r[0],r[1],'1968-04-07' if str(r[2]).startswith('1988-04-01') else r[2]] for r in p.open];p.hand_open.add('1968-04-07')
# ---- 역 대조
def match(o,p,prev):
    c=byname.get(o.mnm,[])
    if not c:return None
    base=znorm(p.name)
    best=None;bs=-1e9
    for s in c:
        sc=0
        if any(base==b or base in b or b in base for b in s['base']):sc+=4
        if p.family=='jr' and (s['comp']&{'1','2','3','4','5','6'}):sc+=2
        if p.family!='jr' and not (s['comp']&{'1','2','3','4','5','6'}):sc+=1
        pt=(s['lat_'],s['lng_'])
        d=dist(prev,pt) if prev else 0
        if prev:
            if d<12:sc+=3
            elif d<40:sc+=1
            elif d>120:sc-=4
        sc-=min(d,200)/200
        if s['closed']=='1' and not o.closed and p.g!='tm':sc-=1
        if sc>bs:bs=sc;best=s
    return best
for p in sorted(parts,key=lambda p:(p.g!='jr',p.id)):
    prev=None
    for o in p.st:
        o.sd=match(o,p,prev)
        if o.sd:prev=(o.sd['lat_'],o.sd['lng_'])
    # 앞쪽 끝 역이 틀렸을 때를 대비해 역방향으로 한 번 더 본다
    nxt=None
    for o in reversed(p.st):
        if o.sd is None or not nxt or dist((o.sd['lat_'],o.sd['lng_']),nxt)>40:
            s=match(o,p,nxt)
            if s:o.sd=s
        if o.sd:nxt=(o.sd['lat_'],o.sd['lng_'])

# 앞뒤 역과 거리가 영업km로 설명되지 않으면 다시 고른다
def pt_of(o):return (o.sd['lat_'],o.sd['lng_']) if o.sd else None
fixed=0
for p in parts:
    for _ in range(2):
        for i,o in enumerate(p.st):
            if not o.sd:continue
            nb=[]
            for j in (i-1,i+1):
                if 0<=j<len(p.st) and p.st[j].sd:nb.append((pt_of(p.st[j]),abs(p.st[j].km-o.km)))
            if not nb:continue
            if all(dist(pt_of(o),q)>k*1.5+5 for q,k in nb):
                c=sorted(byname.get(o.nm,[]),key=lambda s:min(dist((s['lat_'],s['lng_']),q) for q,k in nb))
                best=c[0] if c and min(dist((c[0]['lat_'],c[0]['lng_']),q)-k*1.5-5 for q,k in nb)<=0 else None
                o.sd=best;fixed+=1
print('좌표 재대조',fixed)

# 노드 묶기(union-find)
par={}
def find(x):
    par.setdefault(x,x)
    while par[x]!=x:
        par[x]=par[par[x]];x=par[x]
    return x
def union(a,b):
    a,b=find(a),find(b)
    if a!=b:par[max(a,b)]=min(a,b)
# N05 노선이 같은 회사의 기존 노선에 이어지면 이음 역은 그 노선의 역과 같은 역이다
FAMSD={(p.family,o.nm):o.sd for p in parts if not p.n05pt for o in p.st if o.sd}
for p in parts:
    if p.n05pt:
        for o in p.st:
            q=FAMSD.get((p.family,o.nm))
            if q and (not o.n05 or dist(o.n05,(q['lat_'],q['lng_']))<5):o.sd=q;o.n05=None
for p in parts:
    for o in p.st:
        if (p.cn,o.nm) in NOSD or (p.id,o.nm) in NOSD:o.sd=None
        # N05 노선의 역은 N05 역 점에서 1.5km 넘게 떨어진 station_database 역에 붙이지 않는다. 이름만 같은 다른 역이다
        if getattr(o,'n05',None) and o.sd and dist(o.n05,(o.sd['lat_'],o.sd['lng_']))>1.5:o.sd=None
        o.key=('o'+p.family+':'+o.nm) if o.old else (('s'+o.sd['id']+':'+p.family) if o.sd else ('x'+p.family+':'+o.mnm))
        prevsame=[q for q in p.st[:p.st.index(o)] if getattr(q,'key',None)==o.key]
        if prevsame and (prevsame[-1].label!=o.label or p.st[p.st.index(o)-1] is prevsame[-1]):
            o.key=o.key+'#'+str(len(prevsame))
        find(o.key)

# ---- 노선
BASE=collections.OrderedDict()
for p in parts:
    p.lk=(p.family,p.name)
    BASE.setdefault(p.lk,[]).append(p)
def sectionish(p):
    return p.paren is None or re.search(r'[-～~]',p.paren) is not None
# ---- 승계(국철·JR 폐선 → 타사 현행 노선)
HAND_NO_TRANSFER=set()   # (폐선 부품 id, 현행 부품 id) 오판 제외
trans=[]
cur_pr=[p for p in parts if p.g=='pr' or (p.g=='tm' and p.c!='9')]
for p in parts:
    if not(p.g=='tm' and p.c=='9'):continue
    names=[o.mnm for o in p.st]
    S=set(names)
    for q in cur_pr:
        if (p.id,q.id) in HAND_NO_TRANSFER:continue
        T={o.mnm for o in q.st}
        sh=[n for n in names if n in T]
        if (len(sh)>=3 and (len(sh)/len(S)>=.5 or len(sh)>=4)) or (len(sh)>=2 and (p.name,q.name) in FORCE_PAIR):
            idx={o.mnm:i for i,o in enumerate(q.st)}
            ix=[idx[n] for n in sh]
            mono=all(a<b for a,b in zip(ix,ix[1:])) or all(a>b for a,b in zip(ix,ix[1:]))
            if mono:trans.append((p,q,sh))
print('승계 후보',len(trans))
shared_keys=collections.defaultdict(set)   # q.id -> 공유 구간 노드 쌍
def ghost(o,km):
    c=P();c.__dict__.update(o.__dict__);c.km=round(km,1);c.ghost=True;c.closed=False;return c
SUCC=set()
for p,q,sh in trans:
    pm={o.mnm:o for o in p.st};qm={o.mnm:o for o in q.st}
    # 공유 역의 km 간격이 어긋나면 이름만 같은 다른 역이다
    kept=[sh[0]]
    for x in sh[1:]:
        a=kept[-1]
        if abs(abs(pm[x].km-pm[a].km)-abs(qm[x].km-qm[a].km))<=.7:kept.append(x)
    sh[:]=kept
    if len(sh)<2:continue
    SUCC.add(q.id)
    for n in sh:union(pm[n].key,qm[n].key)
    fw=q.st.index(qm[sh[0]])<q.st.index(qm[sh[-1]])
    newp=[];newq=[]
    i0=p.st.index(pm[sh[0]]);i1=p.st.index(pm[sh[-1]])
    head=p.st[:i0];tail=p.st[i1+1:]
    M=[(pm[sh[0]],qm[sh[0]])]
    for A,B in zip(sh,sh[1:]):
        pa,pb=pm[A],pm[B];qa,qb=qm[A],qm[B]
        pin=p.st[p.st.index(pa)+1:p.st.index(pb)]
        ia,ib=q.st.index(qa),q.st.index(qb)
        qin=q.st[ia+1:ib] if fw else q.st[ib+1:ia][::-1]
        pg=abs(pb.km-pa.km) or 1;qg=abs(qb.km-qa.km) or 1
        L=[(abs(o.km-pa.km)/pg,0,o) for o in pin]+[(abs(o.km-qa.km)/qg,1,o) for o in qin]
        L.sort(key=lambda x:(x[0],x[1]))
        i=0
        while i<len(L):
            f,w,o=L[i]
            nxt=L[i+1] if i+1<len(L) else None
            if nxt and nxt[1]!=w and abs(nxt[0]-f)*qg<=.3:
                x,y=(o,nxt[2]) if w==0 else (nxt[2],o)
                union(x.key,y.key);M.append((x,y));i+=2;continue
            if w==0:M.append((o,ghost(o,qa.km+(qb.km-qa.km)*f)))
            else:M.append((ghost(o,pa.km+(pb.km-pa.km)*f),o))
            i+=1
        M.append((pb,qb))
    p.st=head+[a for a,b in M]+tail
    qs=[b for a,b in M]
    j0=min(q.st.index(qm[sh[0]]),q.st.index(qm[sh[-1]]));j1=max(q.st.index(qm[sh[0]]),q.st.index(qm[sh[-1]]))
    q.st=q.st[:j0]+(qs if fw else qs[::-1])+q.st[j1+1:]
    p.trans=getattr(p,'trans',[])+[(q,[(a.key) for a,b in M])]

# ---- 계통 사슬
def rev(st):
    tot=st[-1].km;o=[]
    for s in reversed(st):
        c=P();c.__dict__.update(s.__dict__);c.km=round(tot-s.km,1);o.append(c)
    return o
line_rel=[]
for lk,ps in BASE.items():
    mains=[];branches=[]
    for p in ps:
        (mains if sectionish(p) else branches).append(p)
    chains=[]
    for p in sorted(mains,key=lambda p:(p.g=='tm',-p.km)):
        c=P();c.parts=[p];c.seq=[(s,p) for s in p.st];c.alts=[];chains.append(c)
    changed=True
    while changed:
        changed=False
        for a in chains:
            for b in chains:
                if a is b:continue
                af,al=find(a.seq[0][0].key),find(a.seq[-1][0].key)
                bf,bl=find(b.seq[0][0].key),find(b.seq[-1][0].key)
                ka={find(s.key) for s,_ in a.seq};kb={find(s.key) for s,_ in b.seq}
                if len(ka&kb)>1:continue
                if al==bf and bl!=af:
                    b.seq[1][0].prevkm=b.seq[0][0].km
                    a.seq=a.seq+b.seq[1:];a.parts+=b.parts;chains.remove(b);changed=True;break
                if bl==af and al!=bf:
                    a.seq[1][0].prevkm=a.seq[0][0].km
                    a.seq=b.seq+a.seq[1:];a.parts=b.parts+a.parts;chains.remove(b);changed=True;break
                if al==bl and af!=bf and b.parts[0].g=='tm':
                    rs=rev([s for s,_ in b.seq]);rp=[q for _,q in reversed(b.seq)]
                    rs[1].prevkm=rs[0].km
                    a.seq=a.seq+list(zip(rs,rp))[1:];a.parts+=b.parts;chains.remove(b);changed=True;break
            if changed:break
    keep=[]
    for c in chains:
        if c.parts[0].g=='tm' and len(chains)>1:
            f,l=find(c.seq[0][0].key),find(c.seq[-1][0].key)
            host=None
            for d in chains:
                if d is c or d.parts[0].g=='tm':continue
                ks=[find(s.key) for s,_ in d.seq]
                if f in ks and l in ks:host=d;break
            if host:
                host.alts.append(c);continue
        keep.append(c)
    chains=keep
    for c in chains:c.role='main'
    for p in branches:
        c=P();c.parts=[p];c.seq=[(s,p) for s in p.st];c.role='branch';c.alts=[];chains.append(c)
    for c in chains[1:]:c.role='branch'
    if chains:chains[0].role='main'
    line_rel.append((lk,ps,chains))

# ---- ID
# 원천 표의 번호는 안에서만 쓰고 밖으로는 영어 이름 ID로 낸다 (ARCHITECTURE §4.2). 표는 공개하지 않는 data/imports/id_map.json이다
NEW_IDS=os.environ.get('NORIORI_NEW_IDS')=='1';NEWK=set()
used=set()
def uid(base):
    b=base;i=2
    while b in used:b=f'{base}_{i}';i+=1
    used.add(b)
    # 표에 없는 새 항목이 옛 형식으로 나가거나 기존 공개 ID와 겹치지 않게 여기서 멈춘다.
    # 새 노선을 넣을 때는 NORIORI_NEW_IDS=1로 한 번 돌려 내부 키를 그대로 내고, tools/new_ids.py가 영어 이름 ID를 표에 더한다
    if b not in PUB:
        if NEW_IDS:NEWK.add(b);return b
        raise SystemExit(f'data/imports/id_map.json에 없는 ID입니다: {b}. 새 항목이면 NORIORI_NEW_IDS=1로 돌리고 tools/new_ids.py를 실행하세요')
    return PUB[b]
def oid(c):
    i=f'o_{c}'
    if i not in PUB and c not in('','x'):
        if NEW_IDS:NEWK.add(i);return i
        raise SystemExit(f'data/imports/id_map.json에 없는 사업자 ID입니다: {i}')
    return PUB.get(i,i)
ops={};OPSRC={}
def category(c):
    c=str(c)
    if c.startswith('10'):return 'major_private'
    if c.startswith('20'):return 'semi_major_private'
    if c.startswith('30'):return 'public'
    if c.startswith('4'):return 'general_private'
    if c.startswith('50'):return 'monorail'
    if c.startswith('51'):return 'agt'
    if c.startswith('52'):return 'cable'
    return 'general_private'
for k,v in JRJA.items():ops[k]=dict(id=k,name_ja=v,category='jr',short_ko=JRKO[k])
for p in parts:
    if p.family!='jr' and oid(p.c) not in ops and p.c!='x':
        ops[oid(p.c)]=dict(id=oid(p.c),name_ja=p.cn,category=category(p.c));OPSRC[oid(p.c)]=p.s['op']
PREF_JR={1:1,2:2,3:2,4:2,5:2,6:2,7:2,8:2,9:2,10:2,11:2,12:2,13:2,14:2,15:2,16:4,17:4,18:4,19:2,20:2,21:3,22:3,23:3,24:3,25:4,26:4,27:4,28:4,29:4,30:4,31:4,32:4,33:4,34:4,35:4,36:5,37:5,38:5,39:5,40:6,41:6,42:6,43:6,44:6,45:6,46:6,47:6}
def jr_of(p):
    if p.g=='jr':return JRCO[int(p.c)]
    if p.g=='jrx':return JRCO[jrx_co(p)]
    c=collections.Counter()
    for o in p.st:
        if o.sd:
            for x in o.sd['comp']:
                if x in('1','2','3','4','5','6'):c[int(x)]+=1
            if not o.sd['comp']&{'1','2','3','4','5','6'} and o.sd['prefecture'].isdigit():
                c[PREF_JR.get(int(o.sd['prefecture']),2)]+=.5
    return JRCO[c.most_common(1)[0][0]] if c else 'o_jr_east'
def jrx_co(p):
    c=collections.Counter()
    for o in p.st:
        if o.sd:
            for x in o.sd['comp']:
                if x in('1','2','3','4','5','6'):c[int(x)]+=1
    return c.most_common(1)[0][0] if c else 2
kana_line={}
for l in SL:
    if l['name_kana'] not in('','NULL'):
        kana_line.setdefault(znorm(conn.clean(l['name'])),l['name_kana'])
linesout={};lid={};hub_line={};LSRC={}
TRAMCO=set(HT['TRAMCO'])
TRAMLN={tuple(x) for x in HT['TRAMLN']}
def line_type(fam,name):
    c=fam[1:] if fam!='jr' else ''
    cn=ops.get(oid(c),{}).get('name_ja','')
    if cn in TRAMCO or (cn,name) in TRAMLN:return 'tram'
    if '鋼索' in name or 'ケーブル' in name:return 'cable'
    if c.startswith('50'):return 'monorail'
    if c.startswith('51'):return 'agt'
    if '軌道' in name:return 'tram'
    if '比叡山' in cn or '竜飛' in name:return 'cable'
    if '無軌条' in name:return 'trolley'
    if '懸垂' in name:return 'monorail'
    return 'rail'
# 원자료 노선과 짝짓기: 역이 가장 많이 겹치는 줄
sd_line_st=collections.defaultdict(set)
scode={s['code']:s for s in SD}
for r in REG:
    s=scode.get(r['station_code'])
    if s:sd_line_st[r['line_code']].add(znorm(s['name']))
def sd_line_for(ps):
    S=set(o.nm for p in ps for o in p.st if not getattr(o,'ghost',False))
    best=None;bs=0
    for code,T in sd_line_st.items():
        sh=len(S&T)
        if not sh:continue
        l=sl[code]
        sc=sh/max(len(S),1)+.2*(znorm(ps[0].name) in znorm(l['name']))+.1*(sh/len(T))
        if sc>bs:bs=sc;best=l
    return best if bs>=.5 else None
for lk,ps,ch in line_rel:
    fam,name=lk
    s=sd_line_for(ps)
    sdn_=conn.clean(s['name']) if s else ''
    same_=bool(s) and (znorm(name) in znorm(sdn_) or znorm(sdn_) in znorm(name)) and name not in('本線','幹線','鋼索線')
    k=LINEKANA.get(ps[0].cn+'|'+name if fam!='jr' else '|'+name) or KANA.get('line:'+name) or kana_line.get(znorm(name)) or (s['name_kana'] if same_ and s['name_kana'] not in('','NULL') else None) or N5KANA.get(ps[0].cn+'|'+name)
    base='l_'+(romaji(re.sub(r'^じぇいあーる','',k)) if k else 'n'+ps[0].id)
    if fam!='jr':base+='_'+fam[1:]
    i=uid(base);lid[lk]=i
    rc='shinkansen' if '新幹線' in name else ('extra' if ps[0].g in('jrx','prx') else 'normal')
    linesout[i]=dict(id=i,name_ja=name,type=line_type(fam,name),rule_class=rc,kana=k,sd=s['name'] if s else None,family=fam)
    if not any(q.g in('jr','pr') for q in ps):linesout[i]['closed']=True
    LSRC[i]='noritsubushi' if any(q.s['line']=='noritsubushi' for q in ps) else ps[0].s['line']

# ---- 노드
nodes={};n_of={}
clusters=collections.defaultdict(list)
for p in parts:
    for o in p.st:
        if not getattr(o,'ghost',False):clusters[find(o.key)].append((o,p))
for k,L in clusters.items():
    L=sorted(L,key=lambda x:x[1].g=='tm')
    os_=[o for o,_ in L]
    sd=next((o.sd for o in os_ if o.sd),None)
    o0=os_[0]
    # 표시 이름은 가장 늦은 시기의 표에서 고른다. 옛 이름은 노선별 이름으로 남는다 (§9.2)
    def part_end(p_):
        return '9999' if p_.g!='tm' else max([str(r[2]) for r in p_.close if len(r)>2] or ['0'])
    o_name=max(L,key=lambda x:part_end(x[1]))[0]
    # 이름의 출처. 위키에서 끼워 넣은 역은 위키, 같은 이름이 노리츠부시 표에도 있으면 표다
    stop_src=lambda o,q:'wikipedia' if hasattr(o,'wclose') else q.s['stop']
    name_src=min((stop_src(o,q) for o,q in L if o.name==o_name.name),key=lambda x:(x!='noritsubushi',x))
    kana=(sd or {}).get('name_kana')
    if kana in(None,'','NULL'):
        kana=next((x.get('kana') for x in WD.get(o0.nm,[]) if x.get('kana')),None)
        if kana:kana=re.sub(r'(えき|エキ|かりじょうこうじょう|しんごうじょう|ていりゅうじょう|じょうこうじょう)$','',kata2hira(kana).replace(' ',''))
    if kana in(None,'','NULL'):kana=KANA.get('node:'+o0.name) or KANA.get('node:'+o0.nm)
    r=romaji(kana) if kana else ''
    i=uid('n_'+(r or 'x'+stable(k))+('' if L[0][1].family=='jr' else '_'+L[0][1].family[1:]))
    hid=all(o.hidden for o in os_)
    kind='station'
    if hid or SIGNALISH.search(o0.name) or o0.kind:kind=o0.kind or ('signal' if '信号' in o0.name else ('freight' if '貨物' in o0.name else 'junction'))
    pt=(sd['lat_'],sd['lng_']) if sd else None
    # station_database에 없는 N05 노선의 역은 N05 역 점 (DESIGN §2.11 출처 모듈화. N05를 끄면 쓰지 않는다)
    n5pt=next((tuple(o.n05) for o in os_ if getattr(o,'n05',None)),None) if source_on('n05') else None
    nodes[i]=dict(id=i,cns=sorted({p_.cn for _,p_ in L}),kind=kind,group=None,pref=(sd or {}).get('prefecture'),name=o_name.name,nm=o_name.nm,kana=re.sub(r'〈.*?〉','',kana) if kana and kana!='NULL' else None,pt=pt,sd_only=bool(sd and len(byname.get(znorm(sd['name']),[]))==1 and len(st_lines[sd['code']])==1),sdname=(sd or {}).get('name'),sd=(sd or {}).get('id'),closed_sd=(sd or {}).get('closed'),sd_open=edtf((sd or {}).get('open_date')),sd_close=edtf((sd or {}).get('closed_date')),family=L[0][1].family,labels=sorted({o.name for o in os_}),by_line=sorted({(o.name,q.lk) for o,q in L if o.name!=o_name.name}),name_src=name_src,by_src={(o.name,q.lk):stop_src(o,q) for o,q in L})
    if not pt and n5pt:nodes[i].update(pt=n5pt,pt_src='n05',closed_sd='1')
    if kind!='station':nodes[i]['export_name']=('['+o0.name+']') if o0.hidden else o0.name
    n_of[k]=i
def nid(o):return n_of[find(o.key)]
def wd_for(n):
    best=None;bd=1e9
    for x in WD.get(n['nm'],[]):
        d=dist(n['pt'],x.get('pt')) if n['pt'] and x.get('pt') else 50
        if d<bd:bd=d;best=x
    return best if bd<8 and n['pt'] else None
for n in nodes.values():
    n['wd']=wd_for(n)

# 손 보정 좌표도 그 근거 출처를 끄면 쓰지 않는다
POSSRC={'wikidata':'wikidata','wikipedia':'wikipedia','n05':'n05','n02':'n02_2008'}
def pos_ok(src):return source_on(POSSRC[src]) if src in POSSRC else True
for k_,(la_,lo_,src_,pf_) in POSFIX.items():
    if k_ in nodes and pos_ok(src_):
        nodes[k_]['pt']=(la_,lo_)
        if src_!='hand':nodes[k_]['pt_src']=src_
        if pf_:nodes[k_]['pref']=pf_
# 현행 역은 같은 이름·같은 사업자의 N02 2024 역 점과 맞춘다. 이름이 같은 다른 지방 역에 잘못 붙은 좌표를 고친다
N02ST=json.load(open(os.path.join(IMP,'n02','stations_2024.json'),encoding='utf-8'))
cur_nodes=set()
for p in parts:
    for o in p.st:
        if not o.closed and not getattr(o,'ghost',False) and p.g!='tm':cur_nodes.add(nid(o))
def plat_dist(p,x):
    """역 좌표와 N02 승강장 선분의 거리. 긴 역은 가운데 점과 재면 크게 나온다"""
    c=x[4] if len(x)>4 else [[x[1],x[0]]]
    if len(c)==1:return dist(p,(c[0][1],c[0][0]))
    cs=math.cos(math.radians(p[0]));o=[]
    for a,b in zip(c,c[1:]):
        ax,ay=(a[0]-p[1])*cs,a[1]-p[0];bx,by=(b[0]-p[1])*cs,b[1]-p[0]
        ex,ey=bx-ax,by-ay;t=max(0,min(1,-(ax*ex+ay*ey)/((ex*ex+ey*ey) or 1e-18)))
        o.append(111.0*math.hypot(ax+t*ex,ay+t*ey))
    return min(o)
def n02_same(x,n):
    if n.get('family')=='jr' and '旅客鉄道' in x[2]:return True
    return any(x[2] in c or c in x[2] or x[2][:4]==c[:4] for c in n['cns'] if c)
n02_fix=[]
for k_ in cur_nodes:
    n=nodes[k_]
    c=[x for t in sorted({n['nm'],*n['labels']}) for x in N02ST.get(N02AL.get(znorm(t),znorm(t)),[]) if n02_same(x,n)]
    if not c:continue
    best=min(c,key=lambda x:dist(n['pt'],x)) if n['pt'] else c[0]
    d=dist(n['pt'],best) if n['pt'] else None
    if d is None or d>.6 or n.get('closed_sd')!='0':
        if d is None or d>.6:n02_fix.append((n['nm'],n['id'],None if d is None else round(d,1)))
        if d is None or d>20:n['pref']=None
        n['pt']=(best[0],best[1]);n['closed_sd']='0';n['pt_src']='n02'
print('N02 좌표 교정',len(n02_fix),n02_fix[:40])
# 이어진 구간 어디에서도 거리가 맞지 않는 좌표는 버린다
for p in parts:
    for i,o in enumerate(p.st):
        if getattr(o,'ghost',False):continue
        nd=nodes[nid(o)]
        if not nd['pt']:continue
        ck=[]
        for j in (i-1,i+1):
            if 0<=j<len(p.st) and nodes[nid(p.st[j])]['pt']:
                ck.append(dist(nd['pt'],nodes[nid(p.st[j])]['pt'])>abs(p.st[j].km-o.km)*1.5+5)
        if ck and all(ck):nd['pt']=None;nd['closed_sd']='1'
# 좌표가 없는 노드는 같은 부품의 앞뒤 역에서 km 비율로 근사한다
for p in parts:
    for i,o in enumerate(p.st):
        if getattr(o,'ghost',False):continue
        nd=nodes[nid(o)]
        if nd['pt']:continue
        a=next((x for x in reversed(p.st[:i]) if nodes[nid(x)]['pt']),None)
        b=next((x for x in p.st[i+1:] if nodes[nid(x)]['pt']),None)
        if a and b and b.km!=a.km:
            pa,pb=nodes[nid(a)]['pt'],nodes[nid(b)]['pt'];f=(o.km-a.km)/(b.km-a.km)
            nd['pt']=(round(pa[0]+(pb[0]-pa[0])*f,6),round(pa[1]+(pb[1]-pa[1])*f,6));nd['pt_src']='interpolated';nd['closed_sd']='1'
# 도도부현이 비면 가장 가까운 역에서, 좌표도 없으면 같은 부품의 이웃 역에서 채운다. 이웃도 없는 독립 노선은 표로
for k_,v_ in {'n_daikanbo':'16','n_murodo':'16','n_raiden':'16','n_kurobe_dam':'16','n_ogizawa':'20','n_ueno_zoo_east_garden':'13','n_ueno_zoo_west_garden':'13','n_seibu_chichibu_through':'11','n_seibu_chichibu_ohanabatake_side':'11','n_ise_nakagawa_uehommachi_side':'24','n_ise_nakagawa_nagoya_side':'24'}.items():
    if k_ in nodes:nodes[k_]['pref']=v_
for n in nodes.values():
    if n['pt'] and not n.get('pref'):
        v=[(dist(n['pt'],m_['pt']),m_['pref']) for m_ in nodes.values() if m_['pt'] and m_.get('pref') and abs(m_['pt'][0]-n['pt'][0])<.5]
        if v:n['pref']=min(v,key=lambda x:x[0])[1]
for p in parts:
    for i,o in enumerate(p.st):
        nd=nodes[nid(o)]
        if nd.get('pref'):continue
        for j in sorted(range(len(p.st)),key=lambda j:abs(j-i)):
            x=nodes[nid(p.st[j])].get('pref')
            if x:nd['pref']=x;break
# ---- edge와 계통
edges={};km={};eseq=[0]
built={}       # 공유 구간 노드 쌍 -> edge
shared=set()
for p,q,sh in trans:
    ks=[nid(o) for o in p.st]
    tk=set(find(k) for _,keys in p.trans for k in keys)
    for a,b in zip(p.st,p.st[1:]):
        if find(a.key) in tk and find(b.key) in tk:shared.add(tuple(sorted((nid(a),nid(b)))))
def new_edge(a,b,line,route=None,alt=None):
    eseq[0]+=1
    i=f'e_{eseq[0]:06d}'
    e=dict(id=i,a=a,b=b,seed_line=line)
    if route:e['route_only']=route
    if alt:e['alt']=alt
    edges[i]=e;return i
def edge_km(seq,i):
    (s,pa),(t,pb)=seq[i],seq[i+1]
    if pa is pb:return round(abs(t.km-s.km),1)
    return round(abs(t.km-getattr(t,'prevkm',t.km)),1)
routesout=[];NROUTE={};kmsrc={}
def km_src(seq,i):
    """edge km의 출처. 위키에서 끼워 넣은 역은 표의 km를 위키 km 비율로 나눈 값이다"""
    (s,_),(t,q)=seq[i],seq[i+1]
    return 'noritsubushi+wikipedia' if q.s['km']=='noritsubushi' and (hasattr(s,'wclose') or hasattr(t,'wclose')) else q.s['km']
def build_chain(c,l,alt=None,host=None):
    seq=c.seq
    if host is None:
        rid=uid('r_'+OLD.get(l,l)[2:]+('' if c.role=='main' else '_'+(re.sub(r'\W+','',romaji(c.parts[0].paren or '')) or c.parts[0].id)))
        c.rid=rid
    else:
        rid=host.rid;c.rid=rid
    ns=[nid(s) for s,_ in seq]
    owned=(getattr(c,'role','alt')=='branch') or len(set(ns))<len(ns)
    c.ns=ns;c.eids=[];also=[]
    for i in range(len(seq)-1):
        a,b=ns[i],ns[i+1]
        k=tuple(sorted((a,b)))
        if alt is None and k in shared:
            e=built.get(k)
            if e is None:
                e=new_edge(a,b,l);built[k]=e;km[e]=edge_km(seq,i);kmsrc[e]=km_src(seq,i)
            else:
                km[e]=edge_km(seq,i) or km[e]
                if edge_km(seq,i):kmsrc[e]=km_src(seq,i)
            also.append(e)
        else:
            e=new_edge(a,b,l,rid if (owned or alt) else None,alt);km[e]=edge_km(seq,i);kmsrc[e]=km_src(seq,i)
        c.eids.append(e)
    if host is None:
        r=dict(id=rid,line=l,role=c.role)
        r['from']=ns[0];r['to']=ns[-1]
        if owned:r['owned']=True
        if owned and also:r['also']=also
        if len(set(ns))<len(ns):r['closed']=True;r['seq']=ns
        hid=sorted({nid(s) for s,_ in seq if s.hidden or getattr(s,'ghost',False)})
        if hid:r['hidden_stops']=hid
        NROUTE[rid]=dict(parts=[q.id for q in c.parts],km=round(sum(q.km for q in c.parts),1))
        routesout.append(r);c.r=r
    else:
        hid=sorted({nid(s) for s,_ in seq if s.hidden or getattr(s,'ghost',False)})
        if hid:host.r.setdefault('hidden_stops',[]).extend(hid)
for lk,ps,ch in sorted(line_rel,key=lambda x:x[0][0]!='jr'):
    l=lid[lk]
    for c in ch:build_chain(c,l)
    for c in ch:
        for a in c.alts:build_chain(a,l,alt='old',host=c)

WS=json.load(open(os.path.join(IMP,'wiki','station.json'),encoding='utf-8')) if os.path.exists(os.path.join(IMP,'wiki','station.json')) else {}
COSHORT=HT['COSHORT']
ws_stat=collections.Counter()
PREF='北海道 青森県 岩手県 宮城県 秋田県 山形県 福島県 茨城県 栃木県 群馬県 埼玉県 千葉県 東京都 神奈川県 新潟県 富山県 石川県 福井県 山梨県 長野県 岐阜県 静岡県 愛知県 三重県 滋賀県 京都府 大阪府 兵庫県 奈良県 和歌山県 鳥取県 島根県 岡山県 広島県 山口県 徳島県 香川県 愛媛県 高知県 福岡県 佐賀県 長崎県 熊本県 大分県 宮崎県 鹿児島県 沖縄県'.split()
ws_miss=[]
ws_cache={}
def freight_block(b):
    """화물 전용 인포박스. 여객 역의 날짜로 쓰면 현행 역이 폐역이 된다 (女川, 宮古, 敦賀)"""
    o=b.get('ops') or ''
    if re.search('貨物(?:支線|線)|臨港線',b.get('lines') or ''):return True
    return '貨物' in o and not re.sub(r'\{\{[^|}]*\||\}\}|\||日本貨物鉄道|JR貨物|日本国有鉄道|国鉄|[（）()→\s・]','',o)
def ws_for(nd,q):
    """역 문서에서 이 사업자·노선의 블록을 찾아 가장 이른 개업일과 가장 늦은 폐지일을 준다"""
    k=(nd['id'],q.cn,q.name)
    if k in ws_cache:return ws_cache[k]
    n0=nd['name'];t0=n0 if n0.endswith('駅') else n0+'駅'
    pages=[t0,n0+'停留場'];
    for t in list(pages):
        pages+=(WS.get(t) or {}).get('alt') or []
    cand=[]
    seen=set()
    for t in pages:
        e=WS.get(t)
        if not e or e.get('missing') or t in seen or not t.startswith(n0):continue
        seen.add(t)
        a0=next((b.get('addr') for b in e.get('blocks',[]) if b.get('addr')),None)
        for b in e.get('blocks',[]):
            if freight_block(b):continue
            if b.get('open') or b.get('close'):cand.append(dict(b,addr=b.get('addr') or a0,page=t))
    jr=q.family=='jr' or q.g in('jr','jrx')
    cns=[x for x in nd.get('cns',[]) if x and x!='旧国鉄・JR各社']
    def opm(b):
        s=b.get('ops') or ''
        if jr and re.search('旅客鉄道|国有鉄道|JR|鉄道省',s):return True
        return any(x in s or COSHORT.get(x,'\0') in s or x[:3] in s for x in cns)
    pref=nd.get('pref')
    pn=PREF[int(pref)-1] if pref and str(pref).isdigit() and 0<int(pref)<=47 else None
    ln=q.name
    ops_=[b for b in cand if opm(b)]
    hit=[b for b in ops_ if ln in (b.get('lines') or '') or ln[:-1] in (b.get('lines') or '')]
    if not hit and pn:hit=[b for b in ops_ if pn in (b.get('addr') or '') or pn in b['page']]
    if not hit and len({b['page'] for b in ops_})==1 and (pn or not jr):
        # 문서가 하나이고 다른 도도부현이 적혀 있지 않으면 받는다
        hit=[b for b in ops_ if not any(x!=pn and x in (b.get('addr') or '') for x in PREF)]
    r={}
    if hit:
        ws_stat['hit']+=1
        # 폐지일은 그 노선의 블록에서만 쓴다. 같은 역의 다른 노선 폐지일이 넘어오면 현행 구간의 역이 사라진다 (佐々, 川内, 青森)
        lk_=re.sub(r'(本線|線)$','',ln)
        strict=[b for b in hit if not b.get('lines') or len(lk_)<2 or lk_ in b['lines']]
        o=[x for b in hit for x in b.get('open',[])]
        c_=[x for b in strict for x in b.get('close',[])]
        o=[x for x in o if 'X' not in x] or o
        c_=[x for x in c_ if 'X' not in x] or c_
        if o:r['open']=min(o,key=lambda x:lohi(x)[0] or '9')
        if c_:r['close']=max(c_,key=lambda x:lohi(x)[0] or '0')
    else:
        ws_stat['miss' if cand else 'nodoc']+=1
        if cand:ws_miss.append((q.cn,q.name,n0,[(b.get('ops') or '')[:18] for b in cand][:3],[(b.get('lines') or '')[:18] for b in cand][:2]))
    ws_cache[k]=r
    return r
def wd_line(nd,lname):
    """같은 노선을 지나는 Wikidata 항목만 쓴다"""
    k=znorm(lname);best={}
    for x in WD.get(nd['nm'],[]):
        if nd['pt'] and x.get('pt') and dist(nd['pt'],x['pt'])>3:continue
        if any(k in znorm(l) or znorm(l) in k for l in x['lines']):
            if not best or (x.get('open') or '9')<(best.get('open') or '9'):best=x
    return best
# ---- 사건
WY={}
_f=os.path.join(CAND,'wiki_years.json')
if os.path.exists(_f):
    for k,v in json.load(open(_f,encoding='utf-8')).items():
        if v[1]:WY[k]=v[1]+'-XX-XX'
events=collections.defaultdict(list)
JR_DAY='1987-04-01'
def idx_in(c,pos,name):
    nm=znorm(name)
    for i in pos:
        if c.seq[i][0].nm==nm or znorm(c.seq[i][0].label.strip('*[]'))==nm:return i
    return None
def spans(c,part,rows):
    """표의 구간 행을 계통 edge 범위로 바꾼다. 이름을 못 찾으면 km 누적으로 찾는다"""
    out=[]
    pos=[i for i,(s,q) in enumerate(c.seq) if q is part]
    if not pos:return out
    base=getattr(c.seq[pos[0]][0],'prevkm',None)
    if pos[0]>0 and base is not None:pos=[pos[0]-1]+pos
    if base is None:base=c.seq[pos[0]][0].km
    run=0.0
    for r in rows:
        sec,k,d=r[0],r[1],r[2]
        kmv=float(k) if re.match(r'^[\d.]+$',k or '') else 0.0
        m=re.split(r'[～~]',sec)
        a=b=None
        if len(m)==2:
            a=idx_in(c,pos,m[0].strip('[]* '));b=idx_in(c,pos,m[1].strip('[]* '))
        if a is None or b is None:
            def near(x):
                best=min(pos,key=lambda i:abs(abs(c.seq[i][0].km-base)-x))
                return best if abs(abs(c.seq[best][0].km-base)-x)<=.25 else None
            if a is None:a=near(run)
            if b is None:b=near(run+kmv)
        run+=kmv
        if a==b and a is not None:continue
        if a is None or b is None:
            unresolved.append((part.id,part.name,sec));continue
        out.append((min(a,b),max(a,b),edtf(d)))
    return out
unresolved=[]
def spec(c,i,j,alt=None):
    """edge 범위 i..j(양 끝 포함)를 a..b 표기로. 같은 노드가 두 번 나오는 계통은 edge를 직접 적는다"""
    if len(set(c.ns))<len(c.ns):return ','.join(c.eids[i:j+1])
    a,b=c.ns[i],c.ns[j+1]
    return a+'..'+b+('@old' if alt else '')
def before(d,day):
    lo=lohi(d)[0]
    return lo is None or lo<day
def run_src(v,i,j):
    """edge 범위의 출처. 한 사건이 두 출처에 걸치면 함께 적는다"""
    return '+'.join(sorted({x for x in v[i:j+1] if x})) or None
EV=[]
for lk,ps,ch in line_rel:
    l=lid[lk]
    for c0 in ch:
        for c,alt in [(c0,None)]+[(x,'old') for x in c0.alts]:
            n=len(c.eids)
            opened=[None]*n;closed=[None]*n;reason=[None]*n;xfer=[None]*n;pop=[None]*n
            opened_s=[None]*n;closed_s=[None]*n;lost_s=[None]*n
            fam=c.parts[0].family
            for part in c.parts:
                co=jr_of(part) if fam=='jr' or part.g=='jrx' else (oid(part.c) if part.c!='x' else prx_op(part))
                pos=[i for i,(s,q) in enumerate(c.seq) if q is part]
                for i in pos:
                    if i>0:pop[i-1]=co
                if pos and pos[0]==0 and False:pass
                for a,b,d in spans(c,part,part.open):
                    for i in range(a,b):opened[i]=d;opened_s[i]='hand' if d in part.hand_open else part.s['open']
                for a,b,d in spans(c,part,part.close):
                    for i in range(a,b):
                        closed[i]=d;closed_s[i]=part.s['close']
                        reason[i]='relocated' if alt else ('brt' if (part.name,c.seq[a][0].name) in BRT else REASON.get(part.name,'abolished'))
            # 표의 구간 행이 순환·숨은 노드 때문에 안 풀린 곳
            for part in c.parts:
                po_=[i for i,(s_,q_) in enumerate(c.seq) if q_ is part and i<n]
                for i in po_:
                    if opened[i] is None and len(part.open)==1:opened[i]=edtf(part.open[0][2]);opened_s[i]='hand' if opened[i] in part.hand_open else part.s['open']
                    if opened[i] is None and part.name in LINEOPEN:opened[i]=LINEOPEN[part.name];opened_s[i]='hand'
            lost=[None]*n;legal=[None]*n
            for part in c.parts:
                for a,b,d in spans(c,part,part.svc):
                    for i in range(a,b):lost[i]=d;lost_s[i]='hand' if part.name in SVC else part.s['close']
                for a,b,d in spans(c,part,part.legal):
                    for i in range(a,b):legal[i]=d
            # 승계
            tr={}
            for part in c.parts:
                for q,keys in getattr(part,'trans',[]):
                    ks={find(k) for k in keys}
                    for i in range(n):
                        (s,_),(t,_)=c.seq[i],c.seq[i+1]
                        if find(s.key) in ks and find(t.key) in ks:xfer[i]=q
            r=c.r if alt is None else c0.r
            rid=c.rid
            owned=bool(r.get('owned')) or bool(alt)
            shared_i=[tuple(sorted((c.ns[i],c.ns[i+1]))) in shared and alt is None for i in range(n)]
            issucc=any(q.id in SUCC for q in c.parts)
            def emit_runs(pred,fn):
                i=0
                while i<n:
                    if not pred(i):i+=1;continue
                    j=i;v=fn(i)
                    while j+1<n and pred(j+1) and fn(j+1)==v:j+=1
                    yield i,j,v
                    i=j+1
            # 개업
            # 등급의 기준은 법적 폐지일. 노리츠부시 표의 폐지일이 여객 영업 끝인 국철 노선은 LEGAL 표에 법적 폐지일이 있다
            lg_=[legal[i] or (LEGAL.get(c.seq[i+1][1].name) if fam=='jr' else None) or closed[i] or '9999' for i in range(n)]
            for i,j,v in emit_runs(lambda i:not(issucc and shared_i[i]),lambda i:(opened[i],pop[i],lg_[i]<'2000',lg_[i]<'1969-12-08')):
                d,co,_o,_j=v
                if fam=='jr' and before(d,JR_DAY):co='o_japanese_national_railways'
                ev=dict(date=d,type='open',operator=co,line=l,edges=spec(c,i,j,alt).split(','))
                # 새로 들어오는 폐선은 N05와 목록 대조가 끝날 때까지 분모 밖 (DESIGN §2.8 O, §4.6): 처음부터 사철이던 2000년 전 폐지, 1969-12-08 전 국철 폐지
                if fam!='jr' and lg_[i]<'2000':ev['class']='outside'
                if fam=='jr' and lg_[i]<'1969-12-08':ev['class']='outside'
                if owned:ev['route']=rid
                ev['source']=run_src(opened_s,i,j) or c.seq[i+1][1].s['open']
                EV.append((fam,ev))
            # 국철 → JR
            if fam=='jr':
                def alive(i):
                    return before(opened[i],JR_DAY) and (closed[i] is None or not before(closed[i],JR_DAY))
                for i,j,co in emit_runs(alive,lambda i:pop[i]):
                    ev=dict(date=JR_DAY,type='transfer',edges=spec(c,i,j,alt).split(','),**{'from':dict(operator='o_japanese_national_railways',line=l),'to':dict(operator=co,line=l)})
                    if owned:ev['route']=rid
                    ev['source']='rule'
                    EV.append((fam,ev))
            # 폐지와 이관
            for i,j,v in emit_runs(lambda i:closed[i] is not None or xfer[i] is not None,lambda i:(closed[i],xfer[i].id if xfer[i] else None,reason[i],lost[i],legal[i])):
                d,qid,why,ls,lg=v
                part=c.seq[i][1]
                if qid:
                    q=xfer[i]
                    dd=d
                    if dd is None:
                        for x in q.open:dd=dd or edtf(x[2])
                    co=pop[i]
                    if before(dd,JR_DAY):co='o_japanese_national_railways'
                    ev=dict(date=dd,type='transfer',edges=spec(c,i,j).split(','),source=run_src(closed_s,i,j) or q.s['open'],**{'from':dict(operator=co,line=l),'to':dict(operator=oid(q.c),line=lid[q.lk])})
                    oh=OPHIST.get(q.name)
                    if oh:
                        ev['to']['operator']=OPHIST_ID[oh[0]]
                        EV.append((fam,dict(date=oh[1],type='transfer',edges=spec(c,i,j).split(','),source='hand',**{'from':dict(operator=OPHIST_ID[oh[0]],line=lid[q.lk]),'to':dict(operator=oid(q.c),line=lid[q.lk])})))
                    qo=sorted(edtf(x[2]) for x in q.open if edtf(x[2]) and 'X' not in edtf(x[2]))
                    gap=[x for x in qo if dd and 'X' not in dd and x>dd]
                    if gap and gap[0][:4]==dd[:4]:
                        EV.append((fam,ev))
                        EV.append((fam,dict(date=dd,type='suspend',line=lid[q.lk],edges=spec(c,i,j).split(','),source=ev['source'])))
                        ev=dict(date=gap[0],type='resume',line=lid[q.lk],edges=spec(c,i,j).split(','),source=q.s['open'])
                else:
                    ev=dict(date=d,type='close',line=l,edges=spec(c,i,j,alt).split(','),reason=why,source=run_src(closed_s,i,j))
                    bd=BRTDAY.get((part.name,c.seq[i][0].name))
                    if bd:ev['legal_abolition']=d;ev['date']=bd;ev['source']='hand'
                    if part.name in LAST and (d or '')>=LAST[part.name]:
                        ev['last_service']=LAST[part.name];ev['legal_abolition']=d
                        import datetime as _dt
                        ev['valid_to']=(_dt.date.fromisoformat(LAST[part.name])+_dt.timedelta(days=1)).isoformat()
                    if ls:
                        import datetime as _dt
                        ev['last_service']=ls
                        if 'X' not in ls and ls<(ev['date'] or '9'):
                            EV.append((fam,dict(date=(_dt.date.fromisoformat(ls)+_dt.timedelta(days=1)).isoformat(),type='suspend',line=l,edges=spec(c,i,j,alt).split(','),source=run_src(lost_s,i,j))))
                    if lg:
                        ev['legal_abolition']=lg
                        if lg!=d and d and 'X' not in d and not ev.get('last_service'):
                            import datetime as _dt
                            ev['last_service']=(_dt.date.fromisoformat(d)-_dt.timedelta(days=1)).isoformat()
                    if part.name in LEGAL and fam=='jr':ev['legal_abolition']=LEGAL[part.name]
                if owned:ev['route']=rid
                EV.append((fam,ev))
            # 지금 불통인 구간. 폐지 신고 전까지 현행으로 둔다 (§3.2)
            for part in c.parts:
                nms_={t_ for s_ in part.st for t_ in (s_.name,s_.nm,znorm(s_.name))}
                for x in (SUSPENDED.get(part.name+'@old',[]) if alt else SUSPENDED.get(part.name,[])+SUSPENDED.get(f'{part.name}|{part.cn}',[])):
                    if not(({x[0],znorm(x[0])}&nms_) and ({x[1],znorm(x[1])}&nms_)):continue
                    for a,b,d in spans(c,part,[[f'{x[0]}～{x[1]}','0',x[2]]]):
                        o_={'route':rid} if owned else {}
                        EV.append((fam,dict(date=d,type='suspend',line=l,edges=spec(c,a,b-1,alt).split(','),source='hand',**o_)))
                        if len(x)>4 and x[4]:EV.append((fam,dict(date=x[4],type='resume',line=x[5] if len(x)>5 else l,edges=spec(c,a,b-1,alt).split(','),source='hand',**o_)))
            # 정차 사건
            for i,(s,q) in enumerate(c.seq):
                if getattr(s,'ghost',False) or s.hidden:continue
                nd=nodes[nid(s)]
                wd=wd_line(nd,q.name)
                ws=ws_for(nd,q)
                if s.closed:
                    d,d_src=next(((a_,b_) for a_,b_ in ((STOPCLOSE.get(s.nm),'hand'),(ws.get('close'),'wikipedia'),(nd['sd_close'],'station_database'),(wdday(wd.get('close')),'wikidata'),(wdday(wd.get('dis')),'wikidata'),(getattr(s,'wclose',None) and s.wclose+'-XX-XX','wikipedia'),(WY.get(l+'|'+nd['id']),'wikipedia')) if a_),(None,q.s['close']))
                    EV.append((fam,dict(date=d,type='close_stop',route=rid,node=nd['id'],source=d_src)))
                op=ws.get('open') or (nd['sd_open'] if nd['sd_only'] else None)
                op_src='wikipedia' if ws.get('open') else 'station_database'
                if not op:op=None if ws else wdday(wd.get('open'));op_src='wikidata'
                adj_o=[opened[k] for k in (i-1,i) if 0<=k<n and opened[k]]
                if s.closed and op and d and (lohi(d)[0] or '9')<=(lohi(op)[0] or '0'):op=None
                ends=[closed[k] for k in (i-1,i) if 0<=k<n and closed[k]]
                if op and ends and (lohi(op)[0] or '')>=(max(lohi(x)[0] or '' for x in ends)):op=None
                # 역 문서와 노선 문서의 표기 차이(하루 등)는 역 폐지로 치지 않는다
                if not s.closed and ws.get('close') and ends and (lohi(ws['close'])[1] or '9')<(min(lohi(x)[0] or '9' for x in ends)) and ws['close'][:7]!=min(lohi(x)[0] or '9' for x in ends)[:7]:
                    EV.append((fam,dict(date=ws['close'],type='close_stop',route=rid,node=nd['id'],source='wikipedia')))
                if op and adj_o and (lohi(op)[0] or '')>((min if ws.get('open') else max)(lohi(x)[0] for x in adj_o)):
                    EV.append((fam,dict(date=op,type='open_stop',route=rid,node=nd['id'],source=op_src)))
print('역 문서',dict(ws_stat))
os.makedirs(CAND,exist_ok=True)
json.dump(ws_miss,open(os.path.join(CAND,'ws_miss.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=0)
print('구간 행 미해결',len(unresolved),unresolved[:12])

# ---- 부품별 이력의 '기간 한정 별선'
for lk,ps,ch in line_rel:
    l=lid[lk]
    for c in ch:
        for part in c.parts:
            if part.until:
                import datetime
                d=(datetime.date.fromisoformat(part.until)+datetime.timedelta(days=1)).isoformat()
                ev=dict(date=d,type='close',line=l,route=c.rid,edges=spec(c,0,len(c.eids)-1).split(','),reason='no_regular_service',source=part.s['close'])
                EV.append((part.family,ev))

# ---- 그룹·환승 묶음
gpar={}
def gf(x):
    gpar.setdefault(x,x)
    while gpar[x]!=x:
        gpar[x]=gpar[gpar[x]];x=gpar[x]
    return x
bynm=collections.defaultdict(list)
for n in nodes.values():bynm[n['nm']].append(n)
for L in bynm.values():
    for i,a in enumerate(L):
        for b in L[i+1:]:
            if dist(a['pt'],b['pt'])<1.0:gpar[gf(b['id'])]=gf(a['id'])
gm=collections.defaultdict(list)
for n in nodes.values():
    gm[gf(n['id'])].append(n)
gids={}
for k,L in gm.items():
    g='g_'+L[0]['id'][2:];gids[k]=g
    for n in L:n['group']=g
# 300m 격자로 환승 후보
grid=collections.defaultdict(list)
for n in nodes.values():
    if n['pt']:grid[(int(n['pt'][0]*100),int(n['pt'][1]*100))].append(n)
hp={}
def hf(x):
    hp.setdefault(x,x)
    while hp[x]!=x:
        hp[x]=hp[hp[x]];x=hp[x]
    return x
# 같은 이름은 350m 안에서만, 이름이 다른 역은 역 문서의 乗換·接続路線 칸에 적힌 것만 묶는다. 같은 노선의 이웃 역은 묶지 않는다
def xn(t):
    t=unicodedata.normalize('NFKC',t or '')
    for a_,b_ in (('ヶ','ケ'),('ヵ','ケ'),('之','ノ'),('﨑','崎'),('髙','高'),('澤','沢'),('濱','浜')):t=t.replace(a_,b_)
    return t
node_lines=collections.defaultdict(set);adjpair=set()
for p in parts:
    prev=None
    for o in p.st:
        if getattr(o,'ghost',False) or o.hidden:continue
        k_=nid(o);node_lines[k_].add(p.name)
        if prev and prev!=k_:adjpair.add(frozenset((prev,k_)))
        prev=k_
def xf_text(n):
    n0=n['name'];out=[];hit=False
    pages=[n0 if n0.endswith('駅') else n0+'駅',n0+'停留場']
    for t in list(pages):pages+=(WS.get(t) or {}).get('alt') or []
    for t in pages:
        e=WS.get(t)
        if e and not e.get('missing') and t.startswith(n0):
            hit=True;out+=[b.get('xf','') for b in e.get('blocks',[])]
    return xn(' '.join(out)) if hit else None
TX={k_:xf_text(n) for k_,n in nodes.items() if n['kind']=='station'}
def named(y,T):
    for nm in {xn(y['name']),xn(y['nm']),*[xn(x) for x in y['labels']]}:
        nm=re.sub(r'[（(].*$','',nm)
        if nm and ((len(nm)>=3 and nm in T) or any(nm+x in T for x in('駅','停留場','電停'))):return True
    return False
def line_or_op(y,T):
    return any(l and l in T for l in node_lines[y['id']]) or any(c and (c in T or c[:3] in T or COSHORT.get(c,'\0') in T) for c in y['cns'])
evid=set()
for (a,b),L in grid.items():
    near=[]
    for i in(-1,0,1):
        for j in(-1,0,1):near+=grid.get((a+i,b+j),[])
    for x in L:
        T=TX.get(x['id'])
        if not T:continue
        c=collections.defaultdict(list)
        for y in near:
            if y['id']!=x['id'] and y['kind']=='station' and xn(y['nm'])!=xn(x['nm']) and dist(x['pt'],y['pt'])<.8 and named(y,T):c[xn(y['nm'])].append(y)
        for v in c.values():
            for y in ([y for y in v if line_or_op(y,T)] or v):evid.add(frozenset((x['id'],y['id'])))
# 문서 칸만으로는 모자란다 (乗換 값이 있는 블록 501개). 공통 노선이 없고 아주 가까우면 연락역으로 친다
HUBX=json.load(open(os.path.join(ROOT,'data','overrides','hub_pairs.json'),encoding='utf-8'))
HUBX={frozenset(xn(t) for t in p_) for p_ in HUBX}
for (a,b),L in grid.items():
    near=[]
    for i in(-1,0,1):
        for j in(-1,0,1):near+=grid.get((a+i,b+j),[])
    for x in L:
        for y in near:
            if x['id']<y['id'] and x['kind']==y['kind']=='station' and frozenset((x['id'],y['id'])) not in adjpair and not node_lines[x['id']]&node_lines[y['id']]:
                d_=dist(x['pt'],y['pt'])
                if d_<(.25 if x['family']!=y['family'] else .1) or (d_<.45 and any(frozenset((p_,q_)) in HUBX for p_ in {xn(x['nm']),xn(x['name'])} for q_ in {xn(y['nm']),xn(y['name'])})):
                    if xn(x['nm'])!=xn(y['nm']) or d_>=.35:evid.add(frozenset((x['id'],y['id'])))
for L in gm.values():
    for i,x in enumerate(L):
        for y in L[i+1:]:
            if x['pt'] and y['pt'] and dist(x['pt'],y['pt'])<.35:hp[hf(y['id'])]=hf(x['id'])
for (a,b),L in grid.items():
    near=[]
    for i in(-1,0,1):
        for j in(-1,0,1):near+=grid.get((a+i,b+j),[])
    for x in L:
        for y in near:
            if x['id']<y['id'] and x['family']!=y['family'] and dist(x['pt'],y['pt'])<.3:
                f=frozenset((x['id'],y['id']))
                if f in adjpair:continue
                if xn(x['nm'])==xn(y['nm']) or f in evid or (TX.get(x['id']) is None and TX.get(y['id']) is None and dist(x['pt'],y['pt'])<.15):hp[hf(y['id'])]=hf(x['id'])
# X駅前·X駅 정류장은 철도역 X와 묶는다. 철도역 문서의 乗換 칸이 비어 있는 곳이 많다
for (a,b),L in grid.items():
    near=[]
    for i in(-1,0,1):
        for j in(-1,0,1):near+=grid.get((a+i,b+j),[])
    for x in L:
        for y in near:
            if y['id']!=x['id'] and y['kind']==x['kind']=='station' and frozenset((x['id'],y['id'])) not in adjpair and dist(x['pt'],y['pt'])<.45:
                if re.sub(r'[（(].*$','',xn(y['name'])) in (xn(x['nm'])+'駅前',xn(x['nm'])+'駅') or xn(y['nm'])==xn(x['nm'])+'駅前':hp[hf(y['id'])]=hf(x['id'])
# 문서 근거로 잇되 묶음 지름이 1.1km를 넘으면 잇지 않는다 (肥後橋~北新地~梅田처럼 사슬이 길어지는 것을 막는다)
mem=collections.defaultdict(list)
for k_,n in nodes.items():
    if n['kind']=='station':mem[hf(k_)].append(k_)
for f in sorted(evid,key=sorted):
    if f in adjpair:continue
    a_,b_=sorted(f);ra,rb=hf(a_),hf(b_)
    if ra==rb:continue
    pts_=[nodes[k_]['pt'] for k_ in mem[ra]+mem[rb] if nodes[k_]['pt']]
    if any(dist(p_,q_)>1.1 for p_ in pts_ for q_ in pts_):continue
    hp[rb]=ra;mem[ra]+=mem.pop(rb)
HUBEV=dict(evid=sorted(sorted(f) for f in evid),doc=sorted(k_ for k_,v_ in TX.items() if v_ is not None),adj=sorted(sorted(f) for f in adjpair))
hm=collections.defaultdict(list)
for n in nodes.values():
    if n['kind']=='station':hm[hf(n['id'])].append(n['id'])
hubs=[dict(id='hub_'+sorted(v)[0][2:],nodes=sorted(v),source=['station_database','proximity_300m'],verified=False) for v in hm.values() if len(v)>1]

# ---- 이름
names=[];pend=[]
TODAY=AS_OF
def add(et,i,lang,text,**k):
    x=dict(entity_type=et,id=i,lang=lang,text=text);x.update({a:b for a,b in k.items() if b is not None});names.append(x)
for n in nodes.values():
    add('node',n['id'],'ja',JAFIX.get(n['id'],n['name']),kana=n['kana'],source='hand' if n['id'] in JAFIX else n['name_src'])
    w=n['wd'] or {}
    if n['kind']!='station':continue
    t=None;src=None
    kana=n['kana']
    if kana:
        hk=kata2hira(kana)
        v=ko.NW.get((n.get('sdname') or '')+'|'+hk) or ko.NW.get(re.sub(r'[（(].*?[)）]','',n['name']).strip()+'|'+hk) or ko.NW.get(n['nm']+'|'+hk)
        if v:t,src=v[0],v[1]
        else:t=ko.station(hk,n['name']);src='estimated' if 'node:'+n['name'] in GUESS else 'rule'
        if n['name'].endswith('駅') and t.endswith('에키'):t=t[:-2]+'역'
    elif w.get('ko'):
        t=re.sub(r'\s*\(.*?\)\s*','',w['ko']);t=t[:-1] if t.endswith('역') else t;src='wikidata'
    t=NAMEKO.get(n['id']) or (NAMEKO.get(n['name'],t) if t else NAMEKO.get(n['name']))
    if t:add('node',n['id'],'ko',t,source=src,checked=TODAY)
    else:pend.append(('node',n['id'],n['name']))
    e=w.get('en')
    if e:
        e=re.sub(r'\s*\(.*?\)\s*','',e).replace('\u2010','-');e=re.sub(r'(?<=[a-z])Station$','',e);e=re.sub(r'\s+(train\s+)?(station|stop|tram stop|staton)$','',e,flags=re.I)
        if e.lower() in('station','stop') or len(e.split())>3:e=None
    # 라벨을 버렸으면 규칙 값이다. 출처를 wikidata로 적으면 역 이름 규칙이 라벨로 믿는다
    e_src='wikidata' if e else 'rule'
    if not e:e=en_rules.station_reading(kana,n['name']) if kana else None
    if e:add('node',n['id'],'en',''.join(c for c in unicodedata.normalize('NFD',e) if c!='\u0304'),source=e_src)
    for lab,lk_ in n.get('by_line',[]):
        add('node',n['id'],'ja',lab,source=n['by_src'][(lab,lk_)],line=lid[lk_])
        kk=KANA.get('node:'+lab)
        if not kk:
            sdk=[s['name_kana'] for s in byname.get(znorm(lab),[]) if s['name_kana'] not in('','NULL')]
            kk=kata2hira(sdk[0]) if sdk else None
        if not kk:
            kk=next((b.get('kana') for b in (WS.get(lab+'駅') or {}).get('blocks',[]) if b.get('kana')),None)
            kk=re.sub(r'[（(].*$','',kk).strip() if kk else None
        if lab in BYLINEKO:add('node',n['id'],'ko',BYLINEKO[lab],source='hand',line=lid[lk_],checked=TODAY)
        elif kk:
            hk=kata2hira(kk);v=ko.NW.get(lab+'|'+hk)
            add('node',n['id'],'ko',v[0] if v else ko.station(hk,lab),source=v[1] if v else 'rule',line=lid[lk_],checked=TODAY)
NLN=json.load(open(os.path.join(IMP,'namuwiki','names_lines.json'),encoding='utf-8'))
LINEKO={tuple(k.split('|')):v for k,v in json.load(open(os.path.join(ROOT,'data','overrides','lines_ko.json'),encoding='utf-8')).items()}
opko={k:v['short_ko'] for k,v in ops.items() if v.get('short_ko')}
for i,l in linesout.items():
    if l.get('kana'):l['kana']=re.sub('^じぇ[いえ]あーる','',l['kana'])
    add('line',i,'ja',l['name_ja'],kana=l.get('kana'),source=LSRC[i])
    t=None;src=None
    sdn=conn.clean(l['sd']) if l.get('sd') else None
    cn=ops.get(oid(l['family'][1:]),{}) if l['family']!='jr' else {}
    cko=OPKO.get(cn.get('name_ja',''),'')
    same=bool(sdn) and znorm(l['name_ja'])!='' and (znorm(l['name_ja']) in znorm(sdn) or znorm(sdn) in znorm(l['name_ja'])) and l['rule_class']!='extra' and l['name_ja'] not in('本線','鋼索線','幹線')
    lk_=(cn.get('name_ja',''),l['name_ja'])
    if lk_ in LINEKO:t,src=LINEKO[lk_],'hand'
    elif same and sdn in NLN:t,src=NLN[sdn]
    elif same and sdn in conn.LABEL:t,src=conn.LABEL[sdn],'hand'
    elif l['name_ja'] in NLN and l['family']=='jr':t,src=NLN[l['name_ja']]
    elif l['name_ja']=='鋼索線':t,src=(cko+' 강삭선').strip(),'rule'
    elif l['name_ja']=='本線':t,src=(cko+' 본선').strip(),'rule'
    elif l.get('kana') and same:t=ko.line(l['kana'],l['name_ja']);src='rule'
    elif KANA.get('line:'+l['name_ja']):
        t=ko.line(KANA['line:'+l['name_ja']],l['name_ja']);t=(cko+' '+t).strip() if cko and not t.startswith(cko) else t;src='rule'
    elif l.get('kana') and l['name_ja'] in N5NAMES:
        # N05 노선은 읽기를 노선 읽기 표(lines_kana.json)나 위키 문서 첫 줄에서 받는다
        t=ko.line(l['kana'],l['name_ja']);t=(cko+' '+t).strip() if cko and not t.startswith(cko) else t;src='rule'
    if t:add('line',i,'ko',t,source=src,checked=TODAY)
    else:pend.append(('line',i,l['name_ja']))
for a,b in OPHIST_ID.items():
    ops[b]=dict(id=b,name_ja=a,category='general_private',short_ko=OPHIST_KO[a])
for i,o in ops.items():
    add('operator',i,'ja',o['name_ja'],source=OPSRC.get(i,'hand'))
    k=o.get('short_ko') or OPKO.get(o['name_ja'])
    kk=KANA.get('op:'+o['name_ja'])
    if not k and kk:
        m=re.match(r'^(.*?)(でんきてつどう|てつどう|でんてつ|こうつう|でんしゃ|きどう)?$',kk)
        tail={'でんきてつどう':' 전기철도','てつどう':' 철도','でんてつ':' 전철','こうつう':' 교통','でんしゃ':' 전차','きどう':' 궤도'}.get(m.group(2),'')
        k=ko.station(m.group(1),re.sub(r'(電気鉄道|鉄道|鐵道|電鉄|交通|電車|軌道)$','',o['name_ja']))+tail
    if k:add('operator',i,'ko',k,source='hand')
    else:pend.append(('operator',i,o['name_ja']))
# 역명 변경 이력. 옛 이름은 기간이 있는 행과 검색 별칭으로 둔다
_r=os.path.join(CAND,'renames.json')
RN=json.load(open(_r,encoding='utf-8')) if os.path.exists(_r) else {}
RNH=json.load(open(os.path.join(ROOT,'data','overrides','renames_hand.json'),encoding='utf-8'))
OLDFIX=json.load(open(os.path.join(ROOT,'data','overrides','old_names_fix.json'),encoding='utf-8'))
old_alias=[]
def doc_about(n,t):
    """제목이 같은 이름이고 그 역의 노선이 적힌 문서만 그 역의 문서로 본다. 동명 역 문서의 연혁이 섞이면 안 된다"""
    e=WS.get(t)
    if not e or e.get('missing'):return False
    b0=xn(re.sub(r'\s*[（(].*$','',t));b1=xn(n['name'])
    if b0 not in (b1,b1+'駅',b1+'停留場'):return False
    ls=[re.sub('(本線|線)$','',l) for l in node_lines[n['id']]]
    return any(l and len(l)>=2 and l in (b.get('lines') or '') for b in e.get('blocks',[]) for l in ls)
for n in nodes.values():
    if n['kind']!='station':continue
    n0=n['name'];pages=[n0 if n0.endswith('駅') else n0+'駅',n0+'停留場']
    for t in list(pages):pages+=(WS.get(t) or {}).get('alt') or []
    seen_=set();base=znorm(n0)
    pages=[(t,RN.get((WS[t] or {}).get('title') or t,[])) for t in pages if doc_about(n,t)]+[(None,RNH.get(n['id'],[]))]
    for t,rows_ in pages:
        for old,f,to in rows_:
            old=re.sub(r'^駅[がをはも]','',old)
            k_=n['id']+'|'+old if n['id']+'|'+old in OLDFIX else old       # 옛 이름 404행을 사람이 읽고 고친 값
            if k_ in OLDFIX:
                v_=OLDFIX[k_]
                if v_ is None:continue
                old,f,to=[v_,f,to] if isinstance(v_,str) else v_
            if znorm(old)==base or (old,to) in seen_ or (n0,old) in {('ケーブル山上','中間'),('トロッコ嵯峨','嵯峨')}:continue
            seen_.add((old,to))
            add('node',n['id'],'ja',old,source='wikipedia',valid_from=f,valid_to=to)
            old_alias.append(dict(entity_type='node',id=n['id'],lang='ja',text=old,kind='old_title'))
            sdk=[s['name_kana'] for s in byname.get(znorm(old),[]) if s['name_kana'] not in('','NULL')]
            kk=KANA.get('node:'+old) or (kata2hira(sdk[0]) if sdk else None)
            if kk:add('node',n['id'],'ko',ko.station(kata2hira(kk),old),source='rule',valid_from=f,valid_to=to,checked=TODAY)
aliases=[dict(entity_type='node',id=k_,lang='ja',text=nodes[k_]['name'],kind='noritsubushi') for k_ in JAFIX]
aliases+=old_alias
_ko={x['id']:x['text'] for x in names if x['entity_type']=='node' and x['lang']=='ko' and not x.get('line') and not x.get('valid_to')}
_ja={x['id']:x['text'] for x in names if x['entity_type']=='node' and x['lang']=='ja' and not x.get('line') and not x.get('valid_to')}
for r in routesout:
    if r['from'] in _ja and r['to'] in _ja:
        names.append(dict(entity_type='route',id=r['id'],lang='ja',text=f"{_ja[r['from']]}～{_ja[r['to']]}",source='rule'))
        if r['from'] in _ko and r['to'] in _ko:names.append(dict(entity_type='route',id=r['id'],lang='ko',text=f"{_ko[r['from']]}~{_ko[r['to']]}",source='rule'))
for i_,v_ in {'l_rias_line':['北リアス線','南リアス線']}.items():
    for t_ in v_:aliases.append(dict(entity_type='line',id=i_,lang='ja',text=t_,kind='old_title'))
# 감사에서 고친 값 (data/overrides/node_fix.json, line_fix.json)
NFIX=json.load(open(os.path.join(ROOT,'data','overrides','node_fix.json'),encoding='utf-8'))
LFIX=json.load(open(os.path.join(ROOT,'data','overrides','line_fix.json'),encoding='utf-8'))
for x in names:
    if x.get('line') or x.get('valid_to'):continue
    f=NFIX.get(x['id']) if x['entity_type']=='node' else None
    if f:
        if x['lang']=='ja':
            if f.get('kana'):x['kana']=f['kana']
            if f.get('ja'):
                aliases.append(dict(entity_type='node',id=x['id'],lang='ja',text=x['text'],kind='noritsubushi'));x['text']=f['ja'];x['source']='hand'
        elif f.get(x['lang']):x['text']=f[x['lang']];x['source']='hand'
    if x['entity_type'] in('line','operator') and x['lang']=='ko' and x['id'] in LFIX:x['text']=LFIX[x['id']];x['source']='hand'
# 영어 이름은 일본어와 읽기가 확정된 뒤에 고친다 (DESIGN §9.1, data/overrides/en_fix.json)
en_rules.fix_nodes(names)
# 역 이전의 옛 역 (DESIGN §2.2 옛 역의 표시). 새 역과 이름이 같으면 이름 뒤에 표시를 붙이고, 원래 이름과 노리츠부시 표기는 별칭으로 남긴다
OLDMARK={'ja':'（旧）','ko':'(구)','en':' (old)'}
NSLABEL={}
for p in parts:
    for o in p.st:
        if '旧' in o.label and not getattr(o,'ghost',False):NSLABEL.setdefault(nid(o),o.label.strip('*').strip('[]').strip())
JA_={x['id']:x['text'] for x in names if x['entity_type']=='node' and x['lang']=='ja' and not x.get('line') and not x.get('valid_to')}
for mv in json.load(open(os.path.join(ROOT,'data','overrides','moved.json'),encoding='utf-8')):
    o_,n_=mv['old'],mv['new']
    if o_ not in nodes or JA_.get(o_)!=JA_.get(n_):continue
    for x in names:
        if x['entity_type']=='node' and x['id']==o_ and x['lang'] in OLDMARK and not x.get('line'):
            if x['lang']=='ja':aliases.append(dict(entity_type='node',id=o_,lang='ja',text=x['text'],kind='moved'))
            x['text']=x['text']+OLDMARK[x['lang']]
    lab=NSLABEL.get(o_)
    if lab:aliases.append(dict(entity_type='node',id=o_,lang='ja',text=lab,kind='noritsubushi'))
    nodes[o_]['export_name']=lab or JA_[o_]+'（旧）'
for lk,ps,ch in line_rel:
    for c in ch:
        for q in c.parts:
            aliases.append(dict(entity_type='route',id=c.rid,lang='ja',text=q.name+(f' ({q.paren})' if q.paren else ''),kind='noritsubushi',span=[q.frm,q.to]))
        for a in c.alts:
            for q in a.parts:
                aliases.append(dict(entity_type='route',id=c.rid,lang='ja',text=q.name+(f' ({q.paren})' if q.paren else ''),kind='noritsubushi',span=[q.frm,q.to]))
# 이름 출처는 값을 정한 근거다. 나무위키 제목이 있으면 규칙 결과와 같아도 namuwiki다 (DESIGN §9.2)
print('나무위키 태그',sum(1 for x in names if x['lang']=='ko' and x.get('source')=='namuwiki'))
# ---- 쓰기
if os.path.isdir(SRC):shutil.rmtree(SRC)
fam=lambda x:'jr' if x=='jr' else 'private'
dump('operators/operators.yaml',[{k:v for k,v in o.items()} for o in ops.values()],'사업자')
for f in('jr','private'):
    dump(f'lines/{f}.yaml',[{k:FAM.get(v,v) if k=='family' else v for k,v in l.items() if v is not None} for l in linesout.values() if fam(l['family'])==f],'노선')
    dump(f'nodes/{f}.yaml',[{k:v for k,v in n.items() if k in('id','kind','group','pref','export_name') and v is not None} for n in nodes.values() if fam(n['family'])==f],'노드')
    ls={i for i,l in linesout.items() if fam(l['family'])==f}
    dump(f'routes/{f}.yaml',[r for r in routesout if r['line'] in ls],'계통')
    dump(f'edges/{f}.yaml',[e for e in edges.values() if e['seed_line'] in ls],'edge')
    # 표가 틀린 구간. 위키백과와 실제 선로가 일치할 때만 고치고 인접 구간의 합은 유지한다
    for fx in json.load(open(os.path.join(ROOT,'data','overrides','km_fix.json'),encoding='utf-8')):
        hit=[e for e in edges.values() if {e['a'],e['b']}=={fx['a'],fx['b']}]
        for e in hit:km[e['id']]=fx['km'];kmsrc[e['id']]='wikipedia'
    dump(f'km/{f}.yaml',[dict(edge=e['id'],km=km[e['id']],source=kmsrc[e['id']]) for e in edges.values() if e['seed_line'] in ls],'edge별 영업km')
    dump(f'events/{f}.yaml',[e for fa,e in EV if fam(fa)==f],'사건')
dump('groups/groups.yaml',[dict(id=g) for g in sorted(set(gids.values()))],'같은 역 묶음')
dump('hubs/hubs.yaml',hubs,'환승 묶음 초안')
json.dump(HUBEV,open(os.path.join(SRC,'hubs','hub_evidence.json'),'w',encoding='utf-8'),ensure_ascii=False)
# 좌표 교정. 묶음과 환승 판정이 끝난 뒤에 한다. 거리로 판정하는 값이 교정 때문에 흔들리면 안 된다
# 자기 사업자의 N02 승강장 선분에서 300m 넘게 떨어진 현행 역은 승강장 가운데로, node_fix.json에 좌표가 있는 노드는 그 값으로
n02_late=[]
for k_ in sorted(cur_nodes):
    n=nodes[k_]
    c=[x for t in sorted({n['nm'],*n['labels']}) for x in N02ST.get(N02AL.get(znorm(t),znorm(t)),[]) if n02_same(x,n)]
    if not c or not n['pt']:continue
    best=min(c,key=lambda x:plat_dist(n['pt'],x));d=plat_dist(n['pt'],best)
    if d>.301 and d<2:
        n02_late.append((n['nm'],k_,round(d,3)));n['pt']=(best[0],best[1]);n['closed_sd']='0';n['pt_src']='n02'
print('N02 승강장 교정',n02_late)
# 보간 좌표는 Wikidata에 그 역의 좌표가 있으면 그 값을 쓴다 (CC0). 신호장과 화물역은 원천 표에 없어 보간값으로 남아 있다
wd_pts=0
for n in nodes.values():
    if n['pt'] and n.get('pt_src')!='interpolated':continue
    c=[x['pt'] for t in (n['nm'],n['nm']+'信号場',n['nm']+'信号所') for x in WD.get(znorm(t),[]) if x.get('pt')]
    c=[x for x in c if n['pt'] and dist(n['pt'],x)<6]
    if c:n['pt']=min(c,key=lambda x:dist(n['pt'],x));n['pt_src']='wikidata';wd_pts+=1
print('Wikidata 좌표',wd_pts)
for k_,v_ in NFIX.items():
    if k_ in nodes and 'lat' in v_ and pos_ok(v_.get('pos_src')):nodes[k_].update(pt=(v_['lat'],v_['lon']),pt_src=v_.get('pos_src','hand'),closed_sd='1')
dump('positions/positions.yaml',[dict(node=n['id'],lat=n['pt'][0] if n['pt'] else None,lon=n['pt'][1] if n['pt'] else None,quality=('precise' if n.get('closed_sd')=='0' else 'approx') if n['pt'] else 'none',checked=TODAY,source=n.get('pt_src','station_database') if n['pt'] else None) for n in nodes.values()],'노드 좌표')
dump('names/names.yaml',names,'이름')
dump('aliases/aliases.yaml',aliases,'별칭')
# 운전 계통
SV=json.load(open(os.path.join(ROOT,'data','overrides','services.json'),encoding='utf-8'))
ali={}
for a in aliases:ali.setdefault(a['text'],a['id'])
r_by={r['id']:r for r in routesout}
n_by_name=collections.defaultdict(list)
for n in nodes.values():
    for lb in n['labels']:n_by_name[znorm(lb)].append(n['id'])
rstops=collections.defaultdict(set)
for lk,ps,ch in line_rel:
    for c in ch:
        rstops[c.rid]|=set(c.ns)
svc=[];bad=[]
for sv in SV:
    sparts=[]
    for lname,a,b in sv['parts']:
        rid=ali.get(lname)
        if not rid:bad.append((sv['id'],lname));continue
        fa=[x for x in n_by_name[znorm(a)] if x in rstops[rid]];fb=[x for x in n_by_name[znorm(b)] if x in rstops[rid]]
        if not fa or not fb:bad.append((sv['id'],lname,a,b));continue
        sparts.append({'route':rid,'from':fa[0],'to':fb[0]})
    x=dict(id=sv['id'],parts=sparts)
    if sv.get('closed'):x['closed']=True
    if sv.get('valid'):x['valid']=sv['valid']
    svc.append(x)
    names.append(dict(entity_type='service',id=sv['id'],lang='ja',text=sv['ja'],source='hand'))
    names.append(dict(entity_type='service',id=sv['id'],lang='ko',text=sv['ko'],source='hand'))
dump('services/services.yaml',svc,'운전 계통')
dump('names/names.yaml',names,'이름')
print('운전 계통',len(svc),'문제',bad)
os.makedirs(CAND,exist_ok=True)
# N05에는 있지만 위키 목록에 km가 없는 역은 열람 전용 역으로 (tools/gen_n05.py, DESIGN §4.1). gen_extra가 이름을 붙여 넣는다
n05arch=[]
for lk,ps,chs in line_rel:
    for c in chs:
        for p in c.parts:
            for nm_,a_,b_ in getattr(p,'arch',[]):
                oa=next((o for o in p.st if o.label==a_),None);ob=next((o for o in p.st if o.label==b_),None)
                if oa and ob:n05arch.append(dict(kind='stop',id='a_'+stable(lid[lk],nm_),line=lid[lk],route=c.rid,after=nid(oa),before=nid(ob),name=nm_,opened=None,closed=max([d for _,_,d in p.x_legal] or [None]),km=None,source='n05'))
json.dump(n05arch,open(os.path.join(CAND,'n05_arch.json'),'w',encoding='utf-8'),ensure_ascii=False)
json.dump(sorted(NEWK),open(os.path.join(CAND,'new_ids.json'),'w',encoding='utf-8'),ensure_ascii=False)
json.dump(dict(pending=pend,unresolved=unresolved,transfers=[(p.name,p.frm,p.to,q.cn,q.name,len(sh)) for p,q,sh in trans]),open(os.path.join(CAND,'gen_report.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=0)
tot=collections.Counter()
for p in parts:
    if p.g in('jr','pr'):tot[jr_of(p) if p.family=='jr' else oid(p.c)]+=p.km
json.dump({k:round(v,1) for k,v in tot.items()},open(os.path.join(CAND,'n_totals.json'),'w',encoding='utf-8'),ensure_ascii=False)
json.dump(NROUTE,open(os.path.join(CAND,'n_routes.json'),'w',encoding='utf-8'),ensure_ascii=False)   # 로컬 QA 전용. 사이트 내부 ID라 공개 데이터에 넣지 않는다
print('nodes',len(nodes),'edges',len(edges),'routes',len(routesout),'events',len(EV),'hubs',len(hubs),'pending',len(pend))
