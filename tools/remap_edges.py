# -*- coding: utf-8 -*-
# 오버라이드가 번호로 가리키는 edge를 생성 뒤의 새 번호로 옮긴다 (ARCHITECTURE §3.5 edge 번호).
# e_ 번호는 생성 순서라 앞쪽 노선의 edge 수가 바뀌면 뒤가 밀린다. 그대로 두면 km·선형 보정이 다른 edge에 붙는다.
# data/overrides/edge_keys.json에 번호마다 「노선|앞 노드|뒤 노드」를 적어 두고, 새 data/source/edges에서 같은 키의 번호로 바꾼다.
# 키가 사라진 edge(역이 끼어 쪼개짐, 노드가 바뀜)는 멈추고 알린다. 사람이 그 보정을 새 edge에 맞춰 고친다.
#   python3 -I tools/remap_edges.py            생성 뒤 옮김 (all.sh)
#   python3 -I tools/remap_edges.py --init     지금 build/master.sqlite로 키 표를 만듦
#   python3 -I tools/remap_edges.py --add      보정이 새로 가리키는 번호의 키만 지금 data/source/edges로 더함 (생성 전에)
import collections,json,os,re,sys,glob,sqlite3
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from lib import ROOT,load
OV=os.path.join(ROOT,'data','overrides')
KEYS=os.path.join(OV,'edge_keys.json')
PAT=re.compile(r'e_\d{6}')
def files():
    out=[]
    for f in sorted(glob.glob(os.path.join(OV,'**','*'),recursive=True)):
        if f==KEYS or not f.endswith(('.json','.yaml')):continue
        if PAT.search(open(f,encoding='utf-8').read()):out.append(f)
    return out
def ids_in(fs):return sorted({e for f in fs for e in PAT.findall(open(f,encoding='utf-8').read())})
# 보정이 새로 만드는 edge(source_patch의 add 행)는 생성 결과에 없다. 번호를 옮기지 않는다
def patch_added():
    out=set()
    for f in glob.glob(os.path.join(OV,'source_patch','edges','*.yaml')):
        for line in open(f,encoding='utf-8'):
            if line.startswith('- '):
                x=json.loads(line[2:])
                if x.get('patch')=='add':out.add(x['id'])
    return out
fs=files();added=patch_added()
if '--init' in sys.argv:
    db=sqlite3.connect(os.path.join(ROOT,'build','master.sqlite'))
    ed={i:(l,a,b) for i,a,b,l in db.execute('select id,from_node,to_node,seed_line from edge')}
    keys={e:'|'.join(ed[e]) for e in ids_in(fs) if e in ed and e not in added}
    json.dump(keys,open(KEYS,'w',encoding='utf-8'),ensure_ascii=False,indent=0,sort_keys=True);open(KEYS,'a').write('\n')
    print('edge 키',len(keys));sys.exit(0)
keys=json.load(open(KEYS,encoding='utf-8'))
if '--add' in sys.argv:
    E={e['id']:e for e in load('edges')}
    n_=collections.Counter(frozenset((e['seed_line'],e['a'],e['b'])) for e in E.values())
    miss=[e for e in ids_in(fs) if e not in keys and e not in added]
    for e in miss:
        x=E[e];k='|'.join((x['seed_line'],x['a'],x['b']))
        # 같은 두 역의 칸이 여럿이면 옛 선로·계통 전용 표시로 가른다 (아래 new 키와 같은 꼴)
        if x.get('route_only'):k+='|route='+x['route_only']
        elif x.get('alt'):k+='|alt='+x['alt']
        elif n_[frozenset((x['seed_line'],x['a'],x['b']))]>1:k+='|alt=none'
        keys[e]=k
    json.dump(keys,open(KEYS,'w',encoding='utf-8'),ensure_ascii=False,indent=0,sort_keys=True);open(KEYS,'a').write('\n')
    print('더한 edge 키',len(miss));sys.exit(0)
# 어느 보정도 가리키지 않는 번호의 키는 버린다
used_=set(ids_in(fs))
keys={e:k for e,k in keys.items() if e in used_}
new={};nb={}
for e in load('edges'):
    # 옛 선로 칸(alt)은 같은 두 역의 지금 칸과 키가 같다. 「|alt=old」를 붙인 키로 가른다
    tail='|alt='+e['alt'] if e.get('alt') else ''
    # 한 계통만 쓰는 칸(route_only)도 같은 두 역의 지금 칸과 키가 같다. 「|route=계통」을 붙인 키로 가른다 (志摩線 白木–五知 옛 계통)
    own='|route='+e['route_only'] if e.get('route_only') else ''
    for x,y in ((e['a'],e['b']),(e['b'],e['a'])):
        new.setdefault('|'.join((e['seed_line'],x,y)),[]).append(e['id'])
        new.setdefault('|'.join((e['seed_line'],x,y))+(tail or '|alt=none'),[]).append(e['id'])
        if own:new.setdefault('|'.join((e['seed_line'],x,y))+own,[]).append(e['id'])
        nb.setdefault((e['seed_line'],x),[]).append((y,e['id']))
M={};lost=[];split={}
for e,k in keys.items():
    c=new.get(k,[])
    if len(c)==1:M[e]=c[0];continue
    # 사이에 역(옛 자리 등)이 하나 끼어 칸이 둘로 쪼개졌으면 목록 안에서 두 번호로 바꾼다
    l_,a_,b_=k.split('|')[:3]
    two=[(e1,e2) for m_,e1 in nb.get((l_,a_),[]) for n_,e2 in nb.get((l_,m_),[]) if n_==b_]
    if not c and len(two)==1:split[e]=two[0];continue
    lost.append((e,k,c))
unknown=[e for e in ids_in(fs) if e not in keys and e not in added]
if lost or unknown:
    for x in lost:print('키가 없거나 여럿인 edge',x)
    for e in unknown:print('키 표에 없는 edge',e)
    raise SystemExit('edge 번호를 옮기지 못했습니다. 그 보정을 새 edge에 맞춰 고치고 edge_keys.json을 고치세요')
moved=0
for f in fs:
    t=open(f,encoding='utf-8').read()
    for e,(e1,e2) in split.items():
        if e not in t:continue
        # 목록 안에서만 둘로 바꾼다. 다른 자리(km·선형 값의 키 등)면 사람이 고친다
        for m in re.finditer('"%s"'%e,t):
            if t[:m.start()].rstrip()[-1:] not in '[,' or t[m.end():].lstrip()[:1] not in ',]':raise SystemExit(f'쪼개진 edge {e}가 목록 밖에 있습니다: {f}')
        t=t.replace('"%s"'%e,'"%s", "%s"'%(e1,e2))
    u=PAT.sub(lambda m:M.get(m.group(0),m.group(0)),t)
    if u!=t:open(f,'w',encoding='utf-8').write(u);moved+=1
# 쪼개져 둘이 된 칸은 새 두 칸의 키를 적는다
out_={M[e]:k for e,k in keys.items() if e in M}
cur_={e['id']:'|'.join((e['seed_line'],e['a'],e['b'])) for e in load('edges')}
for e1,e2 in split.values():out_[e1]=cur_[e1];out_[e2]=cur_[e2]
json.dump(out_,open(KEYS,'w',encoding='utf-8'),ensure_ascii=False,indent=0,sort_keys=True);open(KEYS,'a').write('\n')
print('edge 번호 옮김',sum(1 for e in M if M[e]!=e),'파일',moved)
