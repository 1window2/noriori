# -*- coding: utf-8 -*-
# 일본어 위키백과 노선도에서 분기(junction), 이어짐, 열람 전용 역(archive) 후보를 뽑아 data/source에 넣는다
import sys,os,re,json,gzip,hashlib,collections
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from lib import *
import wparse as w
import conn
os.environ['NW_OFF']='1'

lines={l['id']:l for l in load('lines')}
routes=load('routes')
nodes={n['id']:n for n in load('nodes')}
names=load('names')
ja={};
for x in names:
    if x['entity_type']=='node' and x['lang']=='ja' and x['id'] not in ja:ja[x['id']]=x['text']
line_ja={i:l['name_ja'] for i,l in lines.items()}
# 노선별 정차역 순서
edges=load('edges')
r_by_line=collections.defaultdict(list)
for r in routes:r_by_line[r['line']].append(r)
adj=collections.defaultdict(set)
for e in edges:
    adj[e['seed_line']].add(e['a']);adj[e['seed_line']].add(e['b'])
ev=load('events')
for e in ev:
    if e['type']=='transfer' and e.get('to') and e.get('from') and e['to']['line']!=e['from']['line']:
        for sp in e['edges']:
            m=re.match(r'^(n_[^.@]+)\.\.(n_[^.@]+)',sp)
            if m:
                adj[e['to']['line']].add(m.group(1));adj[e['to']['line']].add(m.group(2))
st_line=collections.defaultdict(set)
for l,S in adj.items():
    for n in sorted(S):st_line[n].add(l)
# 위키 문서 색인
idx={}
d=os.path.join(IMP,'wiki')
for f in os.listdir(d):
    if f.endswith('.json.gz'):idx[f[:14]]=f
def doc_of(t):
    k=hashlib.md5(t.encode()).hexdigest()[:14]
    f=idx.get(k)
    if not f:return None
    return json.load(gzip.open(os.path.join(d,f),'rt',encoding='utf-8'))
pos_={p['node']:p for p in load('positions') if p.get('lat') is not None}
name_nodes=collections.defaultdict(list)
for x in names:
    if x['entity_type']=='node' and x['lang']=='ja':name_nodes[znorm(x['text'])].append(x['id'])
def near_ok(a,b):
    import math
    p,q=pos_.get(a),pos_.get(b)
    if not p or not q:return False
    return math.hypot((p['lat']-q['lat'])*111,(p['lon']-q['lon'])*91)<.9
pairs=set()
# 노선 이름 → ID (이름이 같은 사철 노선은 같은 역을 지나는지로 가린다)
by_ja=collections.defaultdict(list)
for i,n in line_ja.items():
    by_ja[znorm(n)].append(i)
    s=lines[i].get('sd')
    if s:
        c=znorm(conn.clean(s))
        if c!=znorm(n):by_ja[c].append(i)
names_sorted=sorted(by_ja,key=len,reverse=True)
def lines_in(text):
    t=znorm(text);o=[];used=[]
    for n in names_sorted:
        if len(n)<2 or not n.endswith(('線','本線','ライン')) and len(n)<3:continue
        p=t.find(n)
        while p>=0:
            if not any(a<=p<b for a,b in used):
                used.append((p,p+len(n)));o.append(n);break
            p=t.find(n,p+1)
    return o
junc=[];arch=[];stat=collections.Counter();seen=set()
years={};kmcheck=[];unmatched=[];archnames=[];ins=[];kmrows={}
STICON=re.compile(r'(BHF|HST|BST)')
NOT=re.compile(r'専用|貨物|（社）|\(社\)|工場|車両|基地|信号|操車|車庫|機関区|運転所|検車|電留線|留置|発電|鉱|炭|森林|軌道|索道|ロープウェイ')
ST=re.compile(r'^([^\s／：・（(]+?)(?:駅|停留場|停車場|仮乗降場|乗降場)(?:\s*[（(].*?[)）])?(?:\s+(\d{4})?\s*[-–−~～]\s*(\d{4})?)?')
CLOSEDICON=re.compile(r'^(ex|x|e[A-Z]|ke|u?ex)')
cache={};TXT={}
for lid_,l in lines.items():
    t=conn.clean(l['sd']) if l.get('sd') else l['name_ja']
    rec=doc_of(t) or doc_of(l['name_ja'])
    if not rec or not rec.get('html'):stat['no_doc']+=1;continue
    TXT[lid_]=(rec['revid'],re.sub(r'<[^>]+>','',rec['html']))
    if rec['title'] in cache:rows=cache[rec['title']]
    else:
        root=w.parse_text(rec['html'])
        rows,_=w.extract(None,8,root)
        cache[rec['title']]=rows
    flat=[]
    for r in rows:
        if isinstance(r,(list,tuple)) and len(r)==2 and isinstance(r[1],list):flat+=[x for x in r[1] if 'h' not in x]
        elif isinstance(r,dict) and 'h' not in r:flat.append(r)
    if not flat:stat['no_rows']+=1;continue
    stat['docs']+=1
    # 정차역 위치
    S=sorted(adj[lid_])
    nm2n={}
    for n in S:
        nd=nodes.get(n)
        if n in ja:nm2n[znorm(ja[n])]=n
    pos=[]
    for i,r in enumerate(flat):
        hit=None
        for tok in re.findall(r'[^\s／：・]+駅|[^\s／：・]+(?:信号場|信号所)',r['t']):
            x=znorm(re.sub(r'\(.*$','',tok))
            if x in nm2n:hit=nm2n[x];break
        if hit:pos.append((i,hit))
    if len(pos)<2:stat['few_pos']+=1;continue
    # 역 행의 연도·km, 없는 옛 역
    prevn=None;mainr=r_by_line[lid_][0]['id'] if r_by_line[lid_] else None
    posd=dict(pos);km_diff=[]
    for i,r in enumerate(flat):
        icons=[x for c in r['c'] for x in c]
        m=ST.match(r['t'].strip())
        if i in posd:
            n=posd[i]
            # 이름이 다른 역으로의 환승: 같은 행(또는 바로 옆 HUB 행)에 적힌 다른 역
            rs=[r]+[flat[q] for q in (i-1,i+1) if 0<=q<len(flat) and not flat[q]['k'] and any('HUB' in x for c in flat[q]['c'] for x in c)]
            for rr in rs:
                for tok in re.findall(r'[^\s／：・（(]+駅',rr['t'])+rr.get('l',[]):
                    o2=znorm(re.sub(r'\s*[(（].*$','',tok))
                    if o2==znorm(ja.get(n,'')) or len(o2)<2:continue
                    for x in name_nodes.get(o2,[]):
                        if x!=n and near_ok(n,x):pairs.add(tuple(sorted((n,x))))
            ym=re.search(r'(\d{4})\s*[-–−~～]\s*(\d{4})?',r['t'])
            if ym:years[lid_+'|'+n]=[ym.group(1),ym.group(2)]
            prevn=n;continue
        if not m or not any(STICON.search(x) for x in icons) or NOT.search(r['t']):continue
        nm=znorm(m.group(1))
        if nm in nm2n:continue
        y0,y1=m.group(2),m.group(3)
        closedicon=any(re.match(r'^(ue|ex|e[A-Z]|x[A-Z]|uex)',x) for x in icons if STICON.search(x))
        if not(closedicon or y1):continue
        if not y1:continue
        kw=float(r['k']) if re.match(r'^[\d.]+$',r['k'] or '') else None
        pk=None;nk=None;pn=None;nn=None
        for q in range(i-1,-1,-1):
            if q in posd and re.match(r'^[\d.]+$',flat[q]['k'] or ''):pk=float(flat[q]['k']);pn=posd[q];break
        for q in range(i+1,len(flat)):
            if q in posd and re.match(r'^[\d.]+$',flat[q]['k'] or ''):nk=float(flat[q]['k']);nn=posd[q];break
        if int(y1)>=1970:
            if kw is not None and pn and nn:
                ins.append(dict(family=l.get('family'),line=l['name_ja'],name=m.group(1),close=y1,open=y0,km=kw,prev=ja.get(pn),prev_km=pk,next=ja.get(nn),next_km=nk))
            else:unmatched.append((l['name_ja'],m.group(1),y0,y1,r['k']))
            continue
        nxt=next((posd[q] for q in sorted(posd) if q>i),None)
        arch.append(dict(kind='stop',id='a_'+stable(lid_,m.group(1)),line=lid_,route=mainr,after=prevn,before=nxt,name=m.group(1),opened=(y0+'-XX-XX') if y0 else None,closed=(y1+'-XX-XX') if y1 else None,km=float(r['k']) if re.match(r'^[\d.]+$',r['k'] or '') else None,source=f"wikipedia:{rec['revid']}"))
        stat['archive_stop']+=1
    kmrows[lid_]=[(n,float(flat[i]['k'])) for i,n in pos if re.match(r'^[\d.]+$',flat[i]['k'] or '')]
    # 위키 진행 방향과 계통 순서 비교
    main=r_by_line[lid_][0] if r_by_line[lid_] else None
    flip=False
    if main:
        a=[i for i,n in pos if n==main['from']];b=[i for i,n in pos if n==main['to']]
        if a and b and a[0]>b[-1]:flip=True
    for i,r in enumerate(flat):
        sd=conn.junc_side(r)
        cont=any('CONT' in x for c in r['c'] for x in c)
        if not sd and not cont:continue
        tx=conn.rowtext(r)
        cand=lines_in(tx)
        if not cand:stat['row_no_line']+=1;continue
        # 가장 가까운 역부터 공유 노드를 찾는다
        order=sorted(pos,key=lambda p:abs(p[0]-i))[:8]
        for nm in cand:
            for oid in by_ja[nm]:
                if oid==lid_:continue
                found=None
                for ri,n in order:
                    if oid in st_line.get(n,()):found=n;break
                if not found:continue
                k=(lid_,oid,found)
                if k in seen:continue
                seen.add(k)
                j=dict(line=lid_,other=oid,at=found,source=f"wikipedia:{rec['revid']}",verified=False,valid=[None,'ongoing'])
                if sd:
                    if flip:sd2={'u':'d','d':'u'}[sd]
                    else:sd2=sd
                    j['side']={'u':'up','d':'down'}[sd2]
                if cont and not sd:j['continue']=True
                junc.append(j);stat['junction']+=1
                break
# 사업자가 달라 노드가 나뉜 직통: 양쪽 다 그 역에서 끝나고 노선 문서가 직통을 적은 경우 (東横線·みなとみらい線 등)
ops_={o['id']:o for o in load('operators')}
def op_short(l):
    o=ops_.get('o_'+l['family'][1:],{}) if l.get('family')!='jr' else {}
    return re.sub('(電気鉄道|鉄道|鐵道|電鉄|交通局|交通|高速電気軌道)$','',o.get('name_ja','')) or None
def mentions(a,b):
    """a 문서의 '직통' 곁에 b 이름이 있으면 판을 돌려준다. 문서가 없으면 None"""
    if a not in TXT:return None
    v=[lines[b]['name_ja']] if lines[b]['name_ja'] not in('本線','鉄道線','鋼索線') else ([op_short(lines[b])] if len(op_short(lines[b]) or '')>=3 else [])
    T=TXT[a][1]
    for m in re.finditer('直通',T):
        w_=T[max(0,m.start()-30):m.end()+30]
        if any(x and x in w_ for x in v):return TXT[a][0]
    return False
ends=collections.defaultdict(set)
for r in routes:ends[r['line']]|={r['from'],r['to']}
done_=set()
NOCONT={frozenset(x) for x in HT['NOCONT']}
def add_cont(a,x,b,y,rv):
    done_.update({(a,b,x),(b,a,y)})
    for p_,q_,n_ in ((a,b,x),(b,a,y)):
        junc.append(dict(line=p_,other=q_,at=n_,source=f'wikipedia:{rv}' if rv else 'derived',verified=False,valid=[None,'ongoing']));junc[-1]['continue']=True
for a,E_ in sorted(ends.items()):
    for x in sorted(E_):
        for b in sorted(st_line.get(x,())):
            # 같은 역에서 양쪽 다 끝남. JR과 노면전차는 선로가 이어지고, 사철은 문서로 확인한다 (渋谷의 東横線·田園都市線은 안 이어진다)
            if b==a or x not in ends[b] or (a,b,x) in done_ or lines[b].get('type')!=lines[a].get('type') or (lines[a].get('rule_class')=='shinkansen')!=(lines[b].get('rule_class')=='shinkansen'):continue
            if lines[a].get('family')=='jr' or lines[a].get('type')=='tram':add_cont(a,x,b,x,None)
            else:
                if frozenset((lines[a]['name_ja'],lines[b]['name_ja'])) in NOCONT:continue
                rv=mentions(a,b) or mentions(b,a)
                if rv:add_cont(a,x,b,x,rv)
        # 사업자가 달라 노드가 나뉜 직통. 양쪽 문서가 서로를 직통으로 적어야 한다 (東横線·みなとみらい線)
        for y in name_nodes.get(znorm(ja.get(x,'')),[]):
            if y==x or not near_ok(x,y):continue
            for b in sorted(st_line.get(y,())):
                if b==a or lines[b].get('family')==lines[a].get('family') or y not in ends[b] or lines[b].get('type')!=lines[a].get('type') or (a,b,x) in done_:continue
                p_,q_=mentions(a,b),mentions(b,a)
                if (p_ and q_) or (p_ and q_ is None) or (q_ and p_ is None):add_cont(a,x,b,y,p_ or q_)
junc=[j for j in junc if not(j.get('continue') and frozenset((lines[j['line']]['name_ja'],lines[j['other']]['name_ja'])) in NOCONT)]
print('이어짐',len(done_)//2)
# 신칸센과 재래선은 환승으로 그린다 (§8.1)
junc=[j for j in junc if (lines[j['line']].get('rule_class')=='shinkansen')==(lines[j['other']].get('rule_class')=='shinkansen') or j.get('continue')]
# 같은 노선의 지선은 분기역에서 계통으로 가리킨다
for r in routes:
    if r.get('role')=='branch' and any(r['from']==x['from'] or r['from'] in adj[r['line']] for x in r_by_line[r['line']]):
        junc.append(dict(line=r['line'],other=r['line'],other_route=r['id'],at=r['from'],source='derived',verified=False,valid=[None,'ongoing']))
dump('junctions/wikipedia.yaml',junc,'위키 노선도에서 뽑은 분기. verified는 사람이 확인했다는 뜻')
_a={}
for a in arch:_a.setdefault(a['id'],a)
arch=list(_a.values())
for _f in ('archive.yaml',):
    _p=os.path.join(SRC,'archive',_f)
    if os.path.exists(_p):os.remove(_p)
dump('archive/wikipedia.yaml',arch,'위키 노선도에서 뽑은 열람 전용 역')
os.makedirs(CAND,exist_ok=True)
json.dump(years,open(os.path.join(CAND,'wiki_years.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=0)
# 노선도에 같이 적힌 쌍도 역 문서로 거른다. 문서가 없는 역끼리만 그대로 둔다
_h=os.path.join(SRC,'hubs','hub_evidence.json')
if os.path.exists(_h):
    H_=json.load(open(_h,encoding='utf-8'));ev_={tuple(x) for x in H_['evid']};doc_=set(H_['doc']);adj_={tuple(x) for x in H_['adj']}
    pairs={p for p in pairs if p not in adj_ and (p in ev_ or not(p[0] in doc_ or p[1] in doc_))}
# 환승 묶음 ID는 묶인 역 중 JR 역의 이름, 없으면 첫 역의 이름. 겹치면 다른 역의 이름을 붙인다 (DESIGN §2.10)
JRN={x for e in edges if lines.get(e['seed_line'],{}).get('family')=='jr' for x in (e['a'],e['b'])}
_t=os.path.join(SRC,'hubs','hubs.yaml')
HTAKEN={json.loads(l[2:])['id'] for l in open(_t,encoding='utf-8') if l.startswith('- ')} if os.path.exists(_t) else set()
hw=[]
for a,b in sorted(pairs):
    first,second=(b,a) if b in JRN and a not in JRN else (a,b)
    hid='hub_'+first[2:]
    if hid in HTAKEN:hid=hid+'_'+second[2:]
    if hid in HTAKEN:raise SystemExit(f'환승 묶음 ID가 겹칩니다: {hid}')
    HTAKEN.add(hid);hw.append(dict(id=hid,nodes=[a,b],source=['wikipedia'],verified=False))
dump('hubs/wikipedia.yaml',hw,'위키 노선도의 다른 이름 환승')
print('환승 쌍',len(pairs))
json.dump(kmrows,open(os.path.join(CAND,'wiki_km.json'),'w',encoding='utf-8'),ensure_ascii=False)
json.dump(unmatched,open(os.path.join(CAND,'wiki_unmatched.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=0)
_p=os.path.join(CAND,'wiki_insert.json')
_old=json.load(open(_p,encoding='utf-8')) if os.path.exists(_p) else []
_k={(x.get('family'),x['line'],x['name']):x for x in _old}
for x in ins:_k[(x.get('family'),x['line'],x['name'])]=x
ins=list(_k.values())
json.dump(ins,open(_p,'w',encoding='utf-8'),ensure_ascii=False,indent=0)
print('끼워 넣을 역',len(ins))
print(dict(stat))
