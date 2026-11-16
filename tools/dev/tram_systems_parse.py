# 위키 東京都電車 運転系統表에서 계통이 노선 경계를 넘는 곳(A -（X線）- B -（Y線）- C)을 뽑아 노드·노선 ID로 바꾼다.
# 결과(표준 출력 JSON)를 사람이 확인해 data/overrides/tram_systems.json에 둔다 (3회차 kanto_1-007, 판 2026-11-15.1)
import gzip,json,hashlib,os,re,sqlite3,collections,unicodedata,sys
ROOT=os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','..')
D=os.path.join(ROOT,'data','imports','wiki')
r=json.load(gzip.open(os.path.join(D,hashlib.md5('東京都電車'.encode()).hexdigest()[:14]+'.json.gz'),'rt',encoding='utf-8'))
t=r['wikitext'];i=t.find('=== 系統 ===');j=t.find('== 廃線跡 ==');sec=t[i:j]
B=os.path.join(ROOT,'build')
m=sqlite3.connect(B+'/master.sqlite');nm=sqlite3.connect(B+'/names.sqlite')
op='o_tokyo_metropolitan_bureau_of_transportation'
TL=[x[0] for x in m.execute("select distinct line_id from edge_attr where operator_id=?",(op,))]
LN={}
for l in TL:
    for (tx,) in nm.execute("select text from name where entity_type='line' and lang='ja' and entity_id=?",(l,)):
        LN[re.sub('^都電','',tx)]=l
LN.update({'虎の門線':LN.get('虎ノ門線'),'州崎線':LN.get('洲崎線'),'市谷線':LN.get('市ヶ谷線'),'勝鬨橋':LN.get('勝鬨橋線'),'厩橋':LN.get('厩橋線'),'三河島線':'l_arakawa_line','荒川線':'l_arakawa_line','滝野川線':'l_arakawa_line','早稲田線':'l_arakawa_line'})
# node names on tram lines
nodes_of=collections.defaultdict(set)
for l in TL:
    for (n,) in m.execute("select distinct s.node_id from route_stop s join route r on r.id=s.route_id where r.line_id=?",(l,)):nodes_of[l].add(n)
def nz(s):
    s=unicodedata.normalize('NFKC',s);return s.replace('ノ','の').replace('ヶ','が').replace('ケ','が').replace('駅前','').replace('駅','')
NAMES=collections.defaultdict(set)
for (i_,tx) in nm.execute("select entity_id,text from name where entity_type='node' and lang='ja'"):NAMES[i_].add(nz(re.sub('[（(].*','',tx)))
def find(name,lines):
    c=[n for n in set.intersection(*[nodes_of[l] for l in lines]) if nz(name) in NAMES[n]] if lines else []
    return c
rows=[];bad=[]
for blk in re.finditer(r'!\s*(?:rowspan="\d+"\|\s*)?([^\n|]*?系統[^\n]*)\n((?:\|[^\n]*\n|\|-\n)*)',sec):
    sysname=re.sub(r'<.*?>','',blk.group(1)).strip()
    for line in blk.group(2).split('\n'):
        for chain in re.split(r'<br\s*/?>',line):
            chain=re.sub(r'\[\[[^|\]]*\|([^\]]*)\]\]',r'\1',chain);chain=re.sub(r'[\[\]]','',chain)
            parts=[p.strip() for p in re.split(r'\s-\s',chain.lstrip('| ').strip())]
            if len(parts)<5:continue
            # alternate station, （line）, station...
            seq=[]
            for p in parts:
                mm=re.match(r'^（(.+?)）$',p)
                seq.append(('L',mm.group(1)) if mm else ('S',re.sub(r'（.*|\(.*|に経路変更.*|。.*','',p).strip()))
            for k in range(1,len(seq)-2):
                if seq[k][0]=='L' and seq[k+1][0]=='S' and seq[k+2][0]=='L':
                    X,Bn,Y=seq[k][1],seq[k+1][1],seq[k+2][1]
                    A=seq[k-1][1] if seq[k-1][0]=='S' else None
                    C=seq[k+3][1] if k+3<len(seq) and seq[k+3][0]=='S' else None
                    x,y=LN.get(X),LN.get(Y)
                    if not x or not y:bad.append(('line?',sysname,X,Y));continue
                    if x==y:continue
                    at=find(Bn,[x,y])
                    if len(at)!=1:bad.append(('node?',sysname,Bn,X,Y,at));continue
                    ax=find(A,[x]) if A else [];cy=find(C,[y]) if C else []
                    rows.append(dict(system=sysname,at=at[0],at_name=Bn,x=x,y=y,x_toward=ax[0] if len(ax)==1 else None,y_toward=cy[0] if len(cy)==1 else None,x_toward_name=A,y_toward_name=C))
print(len(rows),'못 맞춘 경계',len(bad),file=sys.stderr)
for b in bad:print(b,file=sys.stderr)
json.dump(dict(rows=rows),sys.stdout,ensure_ascii=False,indent=0)
