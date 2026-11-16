# -*- coding: utf-8 -*-
# 손 대조 표(data/overrides/n05_fix.json, 위키 원문을 revid와 함께 옮긴 값)와 빌드 DB를 무작위 표본으로 대조한다
# 역 순서, 역 사이 km, 구간 폐지일을 본다. 쓰는 법: python3 -I tools/dev/n05_sample.py [표본 수] [씨앗]
import sys,os,json,random,sqlite3,re
ROOT=os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','..')
N=int(sys.argv[1]) if len(sys.argv)>1 else 30
SEED=int(sys.argv[2]) if len(sys.argv)>2 else 20261105
fix=json.load(open(os.path.join(ROOT,'data','overrides','n05_fix.json'),encoding='utf-8'))['lines']
db=sqlite3.connect(os.path.join(ROOT,'build','master.sqlite'))
db.execute(f"ATTACH '{os.path.join(ROOT,'build','names.sqlite')}' AS nm")
def jname(n):
    r=db.execute("SELECT text FROM nm.name WHERE entity_type='node' AND entity_id=? AND lang='ja' AND line_id IS NULL AND valid_from IS NULL AND valid_to IS NULL",(n,)).fetchone()
    return r[0] if r else None
def norm(s):return re.sub(r'[\s　]','',s.replace('【旧】','').replace('ヶ','ケ').replace('ヵ','カ'))
cands=[(k,v) for k,v in fix.items() if isinstance(v,dict) and v.get('kind','line')=='line' and v.get('verdict')=='ok' and v.get('stations') and not isinstance(v['stations'][0][0],list)]
random.Random(SEED).shuffle(cands)
by={}
for rid,seq,node,km,st in db.execute("SELECT route_id,seq,node_id,km_cum,is_stop FROM route_stop WHERE is_extension=0"):
    by.setdefault(rid,[]).append((seq,node,km,st))
out=[];checked=0
for k,v in cands:
    if checked>=N:break
    names=[norm(a) for a,_ in v['stations']]
    # 노선 찾기: 그 이름들이 가장 많이 든 계통
    score=[]
    want=set(names)
    for rid,L in by.items():
        got=[norm(jname(n) or '') for _,n,_,_ in L]
        hit=len(want&set(got))
        if hit>=max(2,len(want)*0.6):score.append((hit,-abs(len(got)-len(want)),rid))
    if not score:
        out.append(dict(line=k,result='노선 못 찾음'));checked+=1;continue
    rid=max(score)[2]
    L=sorted(by[rid])
    seqnames=[norm(jname(n) or '') for _,n,_,_ in L]
    kmof={norm(jname(n) or ''):km for _,n,km,_ in L}
    # 순서: 손 대조 표의 역이 DB 계통에서 같은 순서인가 (방향은 둘 다 허용)
    pos=[seqnames.index(x) for x in names if x in seqnames]
    order_ok=pos==sorted(pos) or pos==sorted(pos,reverse=True)
    missing=[x for x in names if x not in seqnames]
    # km: 손 대조 표 첫 역 기준 차이와 DB 누계 차이
    base=[(norm(a),b) for a,b in v['stations'] if isinstance(b,(int,float))]
    kmbad=[]
    if base and base[0][0] in kmof and kmof[base[0][0]] is not None:
        k0=kmof[base[0][0]];w0=base[0][1]
        for a,b in base[1:]:
            if a in kmof and kmof[a] is not None and abs(abs(kmof[a]-k0)-(b-w0))>0.15:kmbad.append((a,b-w0,round(abs(kmof[a]-k0),1)))
    # 폐지일: 손 대조 표의 close 날짜가 그 계통 edge의 폐지일 집합에 있는가
    closes={c[2] for c in v.get('close',[])}
    dbc={r[0] for r in db.execute("SELECT DISTINCT l.valid_to FROM route_edge re JOIN edge_life l ON l.edge_id=re.edge_id WHERE re.route_id=?",(rid,))}
    close_miss=sorted(c for c in closes if c not in dbc)
    out.append(dict(line=k,route=rid,stations=len(names),order_ok=order_ok,missing=missing,km_diff=kmbad,close_missing=close_miss,revid=v.get('revid')))
    checked+=1
ok=sum(1 for r in out if r.get('order_ok') and not r.get('missing') and not r.get('km_diff') and not r.get('close_missing'))
for r in out:print(json.dumps(r,ensure_ascii=False))
print(f'표본 {len(out)}, 모두 맞음 {ok}')
