# -*- coding: utf-8 -*-
# 환승역의 노선별 승강장 위치 (DESIGN §7.5). 国土数値情報 鉄道時系列(N05) 2024판의 노선·사업자·기간별 역 점에서 고른다.
# 대상: 환승 묶음(hub)과 같은 역 묶음(station_group)에 노드가 둘 이상인 역의 정차 노드. 폐선 노드도 넣는다.
# 고르는 법: 같은 이름(옛 이름 포함)의 N05 점 가운데 DB 좌표 2km 안, 노선 이름이 맞는 것. 기간이 정차 기간과 많이 겹치는 것, 그다음 DB 좌표에 가까운 것.
# 결과: data/overrides/platforms/n05.yaml (compile이 platform 표로)
#   python3 -I tools/dev/platforms.py [--write]
import sys,os,json,math,zipfile,sqlite3,collections,re
ROOT=os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','..')
Z=os.path.join(ROOT,'data','imports','n05','N05-24_GML.zip')
OUT=os.path.join(ROOT,'data','overrides','platforms','n05.yaml')
db=sqlite3.connect(os.path.join(ROOT,'build','master.sqlite'))
db.execute(f"ATTACH '{os.path.join(ROOT,'build','names.sqlite')}' AS nm")
def km(p,q):return math.hypot((p[0]-q[0])*math.cos(math.radians((p[1]+q[1])/2))*111.32,(p[1]-q[1])*110.57)
KAN=dict(zip('0123456789','〇一二三四五六七八九'))
def norm(s):
    s=re.sub(r'【旧】|（.*?）|\(.*?\)','',s or '').replace('ヶ','ケ').replace('ヵ','カ').replace('竈','竃').strip()
    return s
VAR=str.maketrans({'鐵':'鉄','礦':'炭','砿':'炭','萠':'萌','ヶ':'ケ','國':'国','驛':'駅'})
# N05와 DB가 다르게 부르는 같은 노선
LALIAS={'常磐新線':'つくばエクスプレス','有楽町線':'副都心線','智頭線':'智頭急行'}
# N05가 번호만 쓰는 시영 지하철 (大阪市, 横浜市): 「1号線」 → 노선 이름
NUMBERED={('大阪市','1'):'御堂筋',('大阪市','2'):'谷町',('大阪市','3'):'四つ橋',('大阪市','4'):'中央',('大阪市','5'):'千日前',('大阪市','6'):'堺筋',('大阪市','7'):'長堀鶴見緑地',('大阪市','8'):'今里筋',('横浜市','1'):'ブルーライン',('横浜市','3'):'ブルーライン',('横浜市','4'):'グリーンライン'}
def line_core(s,op=None):
    m_=re.match(r'^(\d+)号線(.*)$',s or '')
    if m_ and not m_.group(2).strip() and op and (op,m_.group(1)) in NUMBERED:return NUMBERED[(op,m_.group(1))]
    return _line_core(s)
def _line_core(s):
    """노선 이름 대조용: 「10号線新宿線」→「新宿」, 「中央本線」→「中央」, 「江若鉄道線」→「江若鉄道」, 괄호 지움"""
    s=re.sub(r'（.*?）|\(.*?\)','',s or '').split(' ')[0]
    s=re.sub(r'^\d+号線','',s).replace('本線','線').translate(VAR).strip()
    s=LALIAS.get(s,s)
    return re.sub(r'線$','',s)
def op_core(s):
    s=re.sub(r'（.*?）|\(.*?\)','',s or '').translate(VAR)
    return re.sub(r'^(株式会社|一般社団法人)|株式会社$','',s).strip()
def yr(v,d):
    try:return int(str(v)[:4].replace('X','0'))
    except (TypeError,ValueError):return d
# N05 역 점
pts=collections.defaultdict(list)
for f in json.loads(zipfile.ZipFile(Z).read('UTF-8/N05-24_Station2.geojson').decode('utf-8'))['features']:
    p=f['properties'];yb=yr(p.get('N05_005b'),1950);ye=yr(p.get('N05_005e'),9999)
    if yb==999:yb=1950
    if ye==999:ye=9999   # 끝 해 모름
    pts[norm(p.get('N05_011'))].append((line_core(p.get('N05_002'),re.sub(r'（.*?）','',p.get('N05_003') or '')),p.get('N05_002') or '',p.get('N05_003') or '',yb,ye,tuple(f['geometry']['coordinates'])))
# 대상 노드: hub와 2노드 이상 group
members=collections.defaultdict(set)
for h,n in db.execute("SELECT hub_id,node_id FROM hub_member"):members['hub:'+h].add(n)
grp=collections.defaultdict(set)
for n,g in db.execute("SELECT id,group_id FROM node WHERE group_id IS NOT NULL"):grp[g].add(n)
for g,v in grp.items():
    if len(v)>1:members['group:'+g]|=v
for k in list(members):
    if k.startswith('hub:'):
        for n in list(members[k]):
            g=db.execute("SELECT group_id FROM node WHERE id=?",(n,)).fetchone()
            if g and g[0]:members[k]|=grp[g[0]]
stops=collections.defaultdict(list)
for n,l,f,t in db.execute("SELECT s.node_id,r.line_id,s.valid_from,s.valid_to FROM route_stop s JOIN route r ON r.id=s.route_id WHERE s.is_stop=1"):
    stops[n].append((l,yr(f,1950),9999 if t=='ongoing' else yr(t,9999)))
pos={n:(lo,la) for n,la,lo in db.execute("SELECT node_id,lat,lon FROM node_position WHERE lat IS NOT NULL")}
def names_of(t,i):return [x for (x,) in db.execute("SELECT DISTINCT text FROM nm.name WHERE entity_type=? AND entity_id=? AND lang='ja'",(t,i))]
targets=sorted({n for v in members.values() for n in v if n in stops})
SRCQ={n:s_ for n,s_ in db.execute("SELECT node_id,source FROM node_position")}
_mem=collections.defaultdict(set)
for v in members.values():
    for m in v:_mem[m]|=v
def grp_of(n):return _mem[n]
out={};rep=collections.Counter();miss=[]
for n in targets:
    here=pos.get(n)
    lines={l for l,_,_ in stops[n]}
    lnames={line_core(y) for l in lines for x in names_of('line',l) for y in x.split('・')}-{''}
    ops={op_core(x) for (o,) in db.execute("SELECT DISTINCT a.operator_id FROM edge_attr a JOIN edge e ON e.id=a.edge_id WHERE (e.from_node=? OR e.to_node=?)",(n,n)) for x in names_of('operator',o)}
    y0=max(1950,min(f for _,f,_ in stops[n]));y1=max(t for _,_,t in stops[n])
    sp={norm(x) for x in names_of('node',n)}
    sp|={''.join(KAN.get(ch,ch) for ch in x) for x in sp}
    cand=[c for s in sp for c in pts.get(s,())]
    if here:cand=[c for c in cand if km(c[5],here)<2.0]
    def lmatch(c):
        a=c[0]
        if not a:return False   # 「本線」처럼 노선 이름이 비면 사업자로 고른다
        if any(a==b for b in lnames):return True
        # 이름 끝 맞춤(「空港線」⊂「羽田空港線」)은 사업자도 맞을 때만 (東京モノレール이 京急 점에 붙던 것)
        return any(len(b)>=2 and (a.endswith(b) or b.endswith(a)) for b in lnames) and any(o and (o in op_core(c[2]) or op_core(c[2]) in o) for o in ops)
    good=[c for c in cand if lmatch(c)]
    # 노선 이름이 안 맞으면 사업자로: 그 사업자의 점이 한 노선뿐일 때만
    if not good:
        byop=[c for c in cand if any(o and (o in op_core(c[2]) or op_core(c[2]) in o) for o in ops)]
        if len({c[0] for c in byop})==1:good=byop
    if not good and here and sum(1 for m in grp_of(n) if pos.get(m)==here)==1:
        # N05에 없으면 DB 좌표가 그 묶음에서 혼자일 때만 그대로 쓴다 (복사된 좌표는 승강장 위치가 아님)
        out[n]=dict(node=n,lat=here[1],lon=here[0],source='db',db_source=SRCQ.get(n),how='db');rep['DB 좌표']+=1;continue
    if not good:
        rep['노선 이름 안 맞음' if cand else 'N05 점 없음']+=1;miss.append((n,sorted(sp)[:1],sorted(lnames),[c[1] for c in cand][:4]));continue
    def opm(c):return any(o and (o in op_core(c[2]) or op_core(c[2]) in o) for o in ops)
    # 사업자가 맞는 후보를 먼저. 사업자 이름이 달라도(旧国鉄, 改称) 300m 안이면 받는다 (阪急 嵐山 ≠ 京福 嵐山本線)
    if any(opm(c) for c in good):good=[c for c in good if opm(c)]
    elif here:good=[c for c in good if km(c[5],here)<0.3]
    if not good:rep['사업자 안 맞음']+=1;miss.append((n,sorted(sp)[:1],'operator'));continue
    def score(c):
        ov=min(c[4],y1)-max(c[3],y0)
        return (-ov,km(c[5],here) if here else 0)
    best=min(good,key=score)
    if min(best[4],y1)-max(best[3],y0)<0:rep['기간 안 겹침']+=1;miss.append((n,sorted(sp)[:1],'period',best[3],best[4]));continue
    out[n]=dict(node=n,lat=round(best[5][1],6),lon=round(best[5][0],6),source='n05',n05_line=best[1],n05_operator=best[2],years=[best[3],best[4]])
    rep['찾음']+=1
    # 한 노드가 같은 회사의 여러 노선을 맡으면(JR 東京 등) 노선마다 승강장 자리를 따로 찾는다. 떨어진 노선은 따로 그린다 (§7.5)
    if len(lines)>1:
        per={}
        for l in sorted(lines):
            ln={line_core(y) for x in names_of('line',l) for y in x.split('・')}-{''}
            ly0=max(1950,min(f for l2,f,_ in stops[n] if l2==l));ly1=max(t for l2,_,t in stops[n] if l2==l)
            gl=[c for c in good if c[0] and any(c[0]==b_ or (len(b_)>=2 and (c[0].endswith(b_) or b_.endswith(c[0]))) for b_ in ln)]
            gl=[c for c in gl if min(c[4],ly1)-max(c[3],ly0)>=0]
            if gl:
                bl=min(gl,key=lambda c:(-(min(c[4],ly1)-max(c[3],ly0)),km(c[5],here) if here else 0))
                per[l]=[round(bl[5][1],6),round(bl[5][0],6),bl[1]]
        if len({(v[0],v[1]) for v in per.values()})>1:out[n]['lines']=per;rep['노선별로 나뉜 노드']+=1
print('대상 노드',len(targets),dict(rep))
for m in miss[:25]:print('못 찾음',m)
if '--write' in sys.argv:
    os.makedirs(os.path.dirname(OUT),exist_ok=True)
    with open(OUT,'w',encoding='utf-8') as o:
        o.write('# 환승역의 노선별 승강장 위치 (DESIGN §7.5). 国土数値情報 鉄道時系列(N05) 2024판의 노선·사업자·기간별 역 점. 非商用 조건. tools/dev/platforms.py가 씀\n')
        for n in sorted(out):o.write('- '+json.dumps(out[n],ensure_ascii=False)+'\n')
    print('썼음',OUT,len(out))
