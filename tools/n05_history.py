# -*- coding: utf-8 -*-
# 재설계 2단계 (docs/redesign.md §2.2-2): N05 연도별 역·구간 기록에서 1950년 이후 구조 후보를 만든다.
#   역 대응: N05 역 ID(N05_006) → DB 노드 (이름·옛 이름 + 1 km 안, 여럿이면 노선 이름)
#   개칭: 같은 역 ID의 이름이 바뀌었는데 DB에 그 옛 이름 행이 없다
#   이전: 같은 역 ID의 점이 150 m 넘게 옮겼는데 DB에 옛 자리 노드(node_move)가 없다
#   옛 구간: N05 구간 선이 그 기간에 영업하던 DB 선로 선형에서 300 m 넘게 떨어진 토막이 1 km 넘는다
# 결과: data/candidates/n05_history.json (후보와 셈), --write면 data/overrides/renames_n05.json (그대로 넣을 개칭). 빌드 결과(build/*.sqlite)를 읽는다
import sys,os,json,zipfile,sqlite3,collections,math,re,unicodedata
sys.path.insert(0,os.path.dirname(__file__))
from lib import *
Z=zipfile.ZipFile(os.path.join(ROOT,'data','imports','n05','N05-24_GML.zip'))
N05_YEAR=2024
def feats(name):return json.loads(Z.read(f'UTF-8/{name}.geojson'))['features']
def yr(v,end=False):
    """N05 해. 9999는 지금까지. 시작 해의 999는 「1949년 이전이라 해를 모름」(N05 메타데이터)이라 1949로 읽는다.
    끝 해의 999는 메타데이터에 정의가 없고 실제로는 「끝 해를 모름」이다(시작 1951·끝 999 같은 행이 391개) → None"""
    if v in (None,'9999'):return 9999
    if v=='999':return None if end else 1949
    y=int(v);return y if y>=1872 else None
_KD=str.maketrans('0123456789','〇一二三四五六七八九')
def norm(s):
    """같은 이름으로 볼 표기 차이를 없앤다: 전각·반각, ヶ/ケ, の/ノ/之, 숫자 표기(7丁目·七丁目), 뒤의 駅·停留場"""
    s=unicodedata.normalize('NFKC',s or '').replace('ヶ','ケ').replace('ヵ','カ').replace(' ','').replace('・','')
    s=s.replace('ノ','の').replace('之','の').translate(_KD)
    return re.sub(r'(駅|停留場|停留所|電停)$','',s)
def lname(s):return re.sub(r'(本線|線)$','',norm(s))
def km(a,b):
    return math.hypot((a[0]-b[0])*math.cos(math.radians((a[1]+b[1])/2)),a[1]-b[1])*111.2
def mid(g):
    c=g['coordinates']
    if g['type']=='Point':return tuple(c[:2])
    if g['type']=='LineString':return tuple(c[len(c)//2][:2])
    return tuple(c[0][len(c[0])//2][:2])

M=sqlite3.connect('file:'+os.path.join(BUILD,'master.sqlite')+'?mode=ro',uri=True)
N=sqlite3.connect('file:'+os.path.join(BUILD,'names.sqlite')+'?mode=ro',uri=True)
pos={n:(lon,lat) for n,lat,lon in M.execute('select node_id,lat,lon from node_position where lat is not null')}
pub={n for (n,) in M.execute('select id from node_public')}
names=collections.defaultdict(list)   # node → [(text, line, from, to)]
by_name=collections.defaultdict(set)
for e,t,l,f,u,src in N.execute("select entity_id,text,line_id,valid_from,valid_to,source from name where entity_type='node' and lang='ja'"):
    # N05 개칭으로 들어온 이름은 대응·「이미 있음」 판정에 쓰지 않는다. 다시 돌려도 후보가 같아야 한다
    if src=='n05':continue
    names[e].append((t,l,f,u))
    by_name[norm(re.sub(r'（[^）]*）$','',t))].add(e)
line_ja={e:t for e,t in N.execute("select entity_id,text from name where entity_type='line' and lang='ja' and valid_from is null and line_id is null")}
node_lines=collections.defaultdict(set)
for n,l in M.execute('select distinct rs.node_id,r.line_id from route_stop rs join route r on r.id=rs.route_id where rs.is_stop=1'):node_lines[n].add(l)
moved_old={o for (o,) in M.execute('select old_node from node_move')}|{n for (n,) in M.execute('select new_node from node_move')}

# ---- N05 역 기록을 역 ID로 모은다 ----
ST=collections.defaultdict(list)
for f in feats('N05-24_Station2'):
    p=f['properties']
    yb,ye=yr(p['N05_005b']),yr(p['N05_005e'],end=True)
    if yb is None:continue
    # 끝 해를 모르면 적어도 시작 해에는 있었다. 끝이 열린 것으로 보지 않는다
    # 해 999는 실제로는 「그 해 모름」이다: 새 이름(永石通 999–1971)이 옛 이름(秋葉通 1950–999)보다 앞에 정렬되면 개칭이 뒤집힌다 (2회차 종합 K11).
    # 순서는 대표 해(시작을 모르면 끝 해, 끝을 모르면 시작 해)로 정한다
    sk=p['N05_005b']!='999'
    # 시작도 끝도 모르고 지금까지 이어진 이름(江波 999–9999)은 지금 이름이라 맨 뒤다
    rep=yb if sk else (ye if ye not in (None,9999) else 9998)
    ST[p['N05_006']].append(dict(name=p['N05_011'],line=p['N05_002'],op=p['N05_003'],yb=yb,ye=ye if ye is not None else yb,end_unknown=ye is None,start_known=sk,rep=rep,pt=mid(f['geometry'])))
for v in ST.values():v.sort(key=lambda r:(r['rep'],r['ye']))

def match(recs):
    """역 ID → DB 노드. 기록의 이름 가운데 하나를 가진 노드 중 1 km 안의 것, 여럿이면 노선 이름이 맞는 것, 그래도 여럿이면 가까운 것"""
    want={norm(r['name']) for r in recs};lines={lname(r['line']) for r in recs}
    last=recs[-1]['pt']
    cand=[(min(km(pos[n],r['pt']) for r in recs),n) for w in want for n in by_name.get(w,()) if n in pos and n in pub]
    cand=sorted({c for c in cand if c[0]<=1.0})
    if not cand:return None,'none'
    fit=[c for c in cand if any(lname(line_ja.get(l,''))==x or x in lname(line_ja.get(l,'')) for l in node_lines[c[1]] for x in lines)]
    pick=(fit or cand)
    q='line' if fit else 'name'
    if len(pick)>1 and pick[1][0]-pick[0][0]<0.05:q+='_close'
    return pick[0][1],q

MATCH={};stat=collections.Counter()
for sid,recs in ST.items():
    n,q=match(recs);MATCH[sid]=(n,q);stat['match_'+q.split('_')[0]]+=1
    if q.endswith('_close'):stat['match_ambiguous']+=1
# 한 역 ID를 멀리 떨어진 다른 노선 역이 같이 쓰는 일이 있다 (EB03_14424003: 多摩川線 多磨墓地前과 山口線 上堰堤·山口, 14 km).
# 대응한 노드에서 3 km 넘게 떨어진 기록은 그 역이 아니라 개칭·이전 판정에서 뺀다
FAR=3.0
for sid,recs in ST.items():
    n,_=MATCH[sid]
    if not n or n not in pos:continue
    keep=[r for r in recs if km(r['pt'],pos[n])<=FAR]
    if len(keep)<len(recs):stat['far_records']+=len(recs)-len(keep);ST[sid]=keep

# ---- 개칭 ----
renames=[]
for sid,recs in ST.items():
    n,q=MATCH[sid]
    seq=[]
    for r in recs:
        if not seq or norm(seq[-1]['name'])!=norm(r['name']):seq.append(dict(name=r['name'],yb=r['yb'] if r['start_known'] else (r['rep'] if r['rep']!=9998 else r['yb']),ye=r['ye'],op=r['op'],line=r['line']))
        else:seq[-1]['ye']=max(seq[-1]['ye'],r['ye'])
    if len(seq)<2:continue
    stat['rename_n05']+=1
    if not n:stat['rename_unmatched']+=1;continue
    have={norm(re.sub(r'（[^）]*）$','',t)):(f,u) for t,l,f,u in names[n]}
    cur_=norm(re.sub(r'（[^）]*）$','',next((t for t,l,f,u in names[n] if not l and not f and not u),'')))
    for a,b in zip(seq,seq[1:]):
        k=norm(a['name'])
        # 옛 이름이 지금 이름과 같은 것(二子玉川→二子玉川園→二子玉川, のと穴水→穴水)은 그 시절 이름이 지금 이름이라 행이 필요 없다
        if k==cur_:stat['rename_same_as_current']+=1;continue
        dated=k in have and (have[k][0] or have[k][1])
        if dated:stat['rename_have']+=1;continue
        # 바뀐 때는 옛 이름의 마지막 해와 새 이름의 첫 해 사이다. 새 이름의 시작 해를 모르면 대표 해(끝 해)까지로 본다
        # 9999(지금까지)는 자료 해(2024)로 읽는다
        lo_,hi_=min(a['ye'],N05_YEAR),min(b['yb'],N05_YEAR)
        if lo_>hi_:lo_,hi_=hi_,lo_
        renames.append(dict(n05=sid,node=n,match=q,old=a['name'],new=b['name'],old_years=[a['yb'],a['ye']],old_op=a['op'],old_line=a['line'],
            changed=f"[{lo_}-XX-XX..{hi_}-XX-XX]" if lo_!=hi_ else f"{lo_}-XX-XX",
            db='undated_alias' if k in have else 'missing'))
_seen=set();renames=[x for x in renames if (x['node'],norm(x['old']))not in _seen and not _seen.add((x['node'],norm(x['old'])))]
stat['rename_candidates']=len(renames)

# ---- 이전 ----
moves=[]
for sid,recs in ST.items():
    n,q=MATCH[sid]
    pts=[(r['yb'],r['ye'],r['pt']) for r in recs]
    far=[(a,b) for a in pts for b in pts if a[0]<b[0] and km(a[2],b[2])>0.15]
    if not far:continue
    stat['move_n05']+=1
    if not n:stat['move_unmatched']+=1;continue
    if n in moved_old:stat['move_have']+=1;continue
    a,b=max(far,key=lambda x:km(x[0][2],x[1][2]))
    moves.append(dict(n05=sid,node=n,match=q,name=recs[-1]['name'],dist_m=round(km(a[2],b[2])*1000),
        old_pt=a[2],old_years=[a[0],a[1]],new_pt=b[2],new_years=[b[0],b[1]],moved=f"[{a[1]}-XX-XX..{b[0]}-XX-XX]"))
stat['move_candidates']=len(moves)

# ---- 옛 구간: 그 기간에 영업하던 DB 선로 선형으로 덮이지 않는 N05 토막 ----
life=collections.defaultdict(list)
for e,f,u in M.execute("select edge_id,valid_from_lo,case when valid_to='ongoing' then '9999-12-31' else valid_to_hi end from edge_life"):life[e].append((int(f[:4]),int(u[:4])))
G=0.005;grid=collections.defaultdict(list)
for g in load('geometry'):
    c=g['coords'];e=g['edge']
    for a,b in zip(c,c[1:]):
        for x in range(int(min(a[0],b[0])/G)-1,int(max(a[0],b[0])/G)+2):
            for y in range(int(min(a[1],b[1])/G)-1,int(max(a[1],b[1])/G)+2):grid[(x,y)].append((a,b,e))
def seg_km(p,a,b):
    cx=math.cos(math.radians(p[1]))
    ax,ay,bx,by,px,py=a[0]*cx,a[1],b[0]*cx,b[1],p[0]*cx,p[1]
    dx,dy=bx-ax,by-ay;L=dx*dx+dy*dy
    t=0 if L==0 else max(0,min(1,((px-ax)*dx+(py-ay)*dy)/L))
    return math.hypot(px-ax-t*dx,py-ay-t*dy)*111.2
def covered(p,y0,y1):
    for a,b,e in grid.get((int(p[0]/G),int(p[1]/G)),()):
        if any(f<=y1 and u>=y0 for f,u in life.get(e,())) and seg_km(p,a,b)<=0.3:return True
    return False
def samples(c,step=0.2):
    out=[]
    for a,b in zip(c,c[1:]):
        d=km(a,b);k=max(1,int(d/step))
        out+=[(a[0]+(b[0]-a[0])*i/k,a[1]+(b[1]-a[1])*i/k) for i in range(k)]
    return out+[tuple(c[-1][:2])]
# N05 (노선, 사업자) → DB 노선: 그 노선 역들이 이어진 DB 노드가 서는 노선. 없으면 우리 범위 밖 노선(簡易軌道 등)
n05_dbl=collections.defaultdict(collections.Counter)
for sid,recs in ST.items():
    n,q=MATCH[sid]
    if not n:continue
    for r in recs:
        for l in node_lines[n]:n05_dbl[(r['line'],r['op'])][l]+=1
gaps=[]
for f in feats('N05-24_RailroadSection2'):
    p=f['properties'];yb_,ye_=yr(p['N05_005b']),yr(p['N05_005e'],end=True)
    if yb_ is None:continue
    if ye_ is None:ye_=yb_
    if ye_<1950:continue
    y0,y1=max(1950,yb_),ye_
    g=f['geometry'];lines_=[g['coordinates']] if g['type']=='LineString' else g['coordinates']
    for c in lines_:
        pts=samples(c);run=[]
        for q_ in pts+[None]:
            if q_ is not None and not covered(q_,y0,min(y1,2026)):run.append(q_);continue
            if len(run)>1:
                L=sum(km(a,b) for a,b in zip(run,run[1:]))
                if L>=1.0:
                    # 끝 역만 JR 역과 같이 쓰는 簡易軌道 등이 JR 노선으로 잡히지 않게, 노선 이름이 맞는 DB 노선만 친다
                    ln_=lname(p['N05_002'])
                    dbl=[l for l,_ in n05_dbl.get((p['N05_002'],p['N05_003']),collections.Counter()).most_common() if ln_ and (ln_==lname(line_ja.get(l,'')) or ln_ in lname(line_ja.get(l,'')))][:3]
                    gaps.append(dict(n05=p['N05_006'],line=p['N05_002'],op=p['N05_003'],db_lines=dbl,scope='in' if dbl else 'out',years=[y0,y1],km=round(L,2),start=[round(v,5) for v in run[0]],end=[round(v,5) for v in run[-1]]))
            run=[]
for sc in ('in','out'):
    g_=[x for x in gaps if x['scope']==sc];stat[f'old_section_{sc}']=len(g_);stat[f'old_section_{sc}_km']=round(sum(x['km'] for x in g_),1)
# ---- 역 단위: N05에서 그해 그 노선에 있던 역이 DB의 그 노선 정차 기간에 없다 ----
stop_years=collections.defaultdict(list)
for n,l,f,u in M.execute("select rs.node_id,r.line_id,rs.valid_from_lo,case when rs.valid_to='ongoing' then '9999-12-31' else rs.valid_to_hi end from route_stop rs join route r on r.id=rs.route_id where rs.is_stop=1"):
    stop_years[(n,l)].append((int(f[:4]),int(u[:4])))
missing_stops=[];missing_nodes=[]
for sid,recs in ST.items():
    n,q=MATCH[sid]
    for r in recs:
        y0,y1=max(1950,r['yb']),min(r['ye'],2026)
        if y1<y0:continue
        ln_=lname(r['line'])
        dbl=[l for l in n05_dbl.get((r['line'],r['op']),{}) if ln_ and (ln_==lname(line_ja.get(l,'')) or ln_ in lname(line_ja.get(l,'')))]
        if not dbl:continue
        if not n:
            missing_nodes.append(dict(n05=sid,name=r['name'],line=r['line'],op=r['op'],db_lines=dbl[:2],years=[y0,y1],pt=[round(v,5) for v in r['pt']]));continue
        # 그 노선(이름이 맞는 DB 노선 가운데 하나)에서 그 기간의 어느 해에라도 서던 기록이 있으면 된다
        if any(f<=y1 and u>=y0 for l in dbl for f,u in stop_years.get((n,l),())):continue
        missing_stops.append(dict(n05=sid,node=n,name=r['name'],line=r['line'],db_lines=dbl[:2],years=[y0,y1],db=sorted({(l,f,u) for l in dbl for f,u in stop_years.get((n,l),())})[:3]))
stat['missing_stop_candidates']=len(missing_stops);stat['missing_node_candidates']=len(missing_nodes)

# ---- 분류: 그대로 넣을 몫(auto)과 사람·자료 확인 몫(check), 범위 밖(out) ----
NONPAX=re.compile(r'荷扱所|信号場|信号所|操車場|貨物|分岐点|検車|車庫$|機関区')
# 노드의 사업자 이름 (그 노드에 닿는 edge의 모든 시기 사업자). N05 사업자와 맞춰 다른 사업자 역 이름이 붙는 것을 막는다 (2회차 종합 K12)
opja=collections.defaultdict(set)
for e,t in N.execute("select entity_id,text from name where entity_type='operator' and lang='ja'"):opja[e].add(t)
node_ops=collections.defaultdict(set)
for a_,b_,o_ in M.execute('select e.from_node,e.to_node,a.operator_id from edge e join edge_attr a on a.edge_id=e.id'):
    for x_ in (a_,b_):node_ops[x_]|=opja.get(o_,set())|{o_}
# 사업자 이름의 구자체(N05 「土佐電氣鐵道」)는 신자체로 맞춘다. 「土佐電気鉄道」와 못 맞춰 土佐電 개칭 21행이 check로 빠졌다 (8회차 W3 요청 1, 9회차 N)
_KYU=str.maketrans({'氣':'気','鐵':'鉄','國':'国','驛':'駅','會':'会','營':'営','縣':'県','廣':'広','澤':'沢','濱':'浜','邊':'辺','臺':'台','舊':'旧','參':'参','總':'総',
    '豐':'豊','與':'与','寶':'宝','黑':'黒','德':'徳','增':'増','發':'発','惠':'恵','榮':'栄','齋':'斎','藝':'芸','龜':'亀','圓':'円','關':'関','鑛':'鉱','礦':'鉱',
    '輕':'軽','傳':'伝','歸':'帰','實':'実','壽':'寿','櫻':'桜','萬':'万','灣':'湾','乘':'乗','轉':'転','當':'当','產':'産','產':'産','專':'専','體':'体','屬':'属','樂':'楽','聯':'連','區':'区','藏':'蔵','觀':'観','巖':'巌','嶋':'島','嶌':'島'})
def opn(s):return re.sub(r'（[^）]*）|\([^)]*\)|株式会社|交通局|交通部|電気局','',unicodedata.normalize('NFKC',s or '').translate(_KYU))
def op_ok(n,op):
    have=node_ops.get(n)
    if not have:return True
    o=opn(op)
    if not o:return True
    if re.search('旅客鉄道|国有鉄道',op) and any(x.startswith('o_jr_') or x=='o_japanese_national_railways' for x in have):return True
    return any(len(opn(h))>=2 and (opn(h) in o or o in opn(h)) for h in have if not h.startswith('o_'))
node_stop=collections.defaultdict(list)
for (n_,l_),v_ in stop_years.items():node_stop[n_]+=v_
# 사람이 보고 넣지 않기로 한 N05 개칭(노드, 옛 이름) → 사유 (8회차 W3 土佐電 대조, 9회차 N에서 도구로 옮김)
N05_REJECT={('n_harimayabashi','播磨屋橋'):'N05 1950–2013 표기 공백(같은 역 이름의 한자 표기일 뿐 개칭 날짜 근거 없음)',
    ('n_kenchomae_tosaden_kotsu','本町上一丁'):'N05 표기 잘림(本町上一丁目)',('n_nakanohashidori','本町下一丁'):'N05 표기 잘림(本町下一丁目)'}
def cls_rename(x):
    if (x['node'],x['old']) in N05_REJECT:return 'check',N05_REJECT[(x['node'],x['old'])]
    if x['old_years'][1]<1950:return 'pre1950','옛 이름이 1950년 전에 끝남: 기록 화면에는 안 나오고 검색 별칭만'
    if x['match']!='line':return 'check','대응이 이름뿐이거나 애매함'
    # 옛 이름 기간에 그 노드가 어느 노선에서도 서지 않았으면 N05가 같은 역 ID로 묶은 다른 역이다 (花園·公文明·南小野田)
    y0,y1=max(1950,x['old_years'][0]),x['old_years'][1]
    if not any(f<=y1 and u>=y0 for f,u in node_stop.get(x['node'],())):return 'check','옛 이름 기간이 노드 정차 기간과 안 겹침'
    if not op_ok(x['node'],x['old_op']):return 'check','옛 이름의 N05 사업자가 노드 사업자와 다름(다른 사업자 이름은 노선 지정 행으로만)'
    # 옛 이름이 같은 노선 가까운 다른 역의 이름이면 이름이 역을 옮겨 간 것(志摩磯部)일 수 있다
    if any(o!=x['node'] and o in pos and km(pos[o],pos[x['node']])<3 for o in by_name.get(norm(x['old']),())):return 'check','옛 이름이 가까운 다른 역 이름'
    return 'auto','N05 같은 역 ID의 이름 변화'
for x in renames:x['class'],x['why']=cls_rename(x)
for x in moves:
    x['class'],x['why']=('check','2 km 넘게 옮김') if x['dist_m']>2000 else ('check' if x['match']!='line' else 'step3','km 변화 확인 뒤 3단계(노드 둘이면 옛 자리 노드, km가 같으면 노드 하나)')
for x in missing_stops:
    other=[(l,f,u) for (n_,l),v in stop_years.items() if n_==x['node'] for f,u in v if f<=x['years'][1] and u>=x['years'][0]]
    x['class'],x['why']=('line_history','그 기간 다른 DB 노선에 정차함: 노선 이름·소속 이력(결정 3·4)') if other else ('stop_missing','그 기간 어느 노선에도 정차 기록 없음')
for x in missing_nodes:
    x['class'],x['why']=('out','여객역 아님') if NONPAX.search(x['name']) else ('node_missing','DB에 없는 역 (km·근거 확인 뒤 추가)')
for k_,v_ in (('rename',renames),('move',moves),('missing_stop',missing_stops),('missing_node',missing_nodes)):
    for c_,n_ in collections.Counter(x['class'] for x in v_).items():stat[f'{k_}:{c_}']=n_
out=dict(stat=dict(stat),renames=renames,moves=moves,old_sections=sorted(gaps,key=lambda x:-x['km']),missing_stops=missing_stops,missing_nodes=missing_nodes,
    unmatched=[dict(n05=s,names=sorted({r['name'] for r in v}),line=v[-1]['line'],op=v[-1]['op'],years=[v[0]['yb'],v[-1]['ye']]) for s,v in ST.items() if not MATCH[s][0]])
# 그대로 넣을 개칭은 생성기가 읽는 보정 파일로 둔다 (gen_source가 위키 개칭 다음 출처로 씀). 앞 이름 기간의 끝을 시작으로 잇는다
acc=collections.defaultdict(list)
# N05 원자료의 옛 이름 오기. 鉄道省『鉄道停車場一覧』(1937년판, NDL 1207554)과 역 문서 원문으로 고친다 (옛 이름 읽기 4차 조사 2026-11-09)
N05_TYPO={'防中':'坊中','小間木':'古間木','志差':'志佐','武洲大沢':'武州大沢'}
for x in renames:
    if x['class']=='auto':acc[x['node']].append([N05_TYPO.get(x['old'],x['old']),x['old_years'],x['changed'],x['n05']])
rn05={}
for n,rows in sorted(acc.items()):
    rows.sort(key=lambda r:lohi(r[2])[0]);out_=[];prev=None
    for old,yrs,changed,sid in rows:
        out_.append([old,prev,changed,sid]);prev=changed
    rn05[n]=out_
if '--write' in sys.argv:json.dump(rn05,open(os.path.join(ROOT,'data','overrides','renames_n05.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=0)
stat['renames_n05_nodes']=len(rn05)
os.makedirs(os.path.join(ROOT,'data','candidates'),exist_ok=True)
json.dump(out,open(os.path.join(ROOT,'data','candidates','n05_history.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=1)
print(dict(stat))
