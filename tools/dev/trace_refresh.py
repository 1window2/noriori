# -*- coding: utf-8 -*-
# 명세 추적표 세 개의 줄 번호를 지금 작업본에 맞춘다. 판정, 요구, 행 수는 건드리지 않는다
# 번호는 e5bde94 판 추적표에서 읽는다. 그 뒤 손으로 고친 행은 지금 표의 글을 쓰고, 기준 판에 있던 자리의 번호만 다시 계산한다
#   기준 판에 없던 번호(뒤에 새로 쓴 근거)는 그대로 둔다. 기준 판에 있던 자리의 번호를 손으로 고치면 다음 실행이 덮어쓴다
# 명세 줄(L…, A:…, dbs:…, R:…, SN:…): 표를 만든 때의 명세 판(DESIGN v0.40 등)이 git에 없다
#   그래서 행의 요구 글과 지금 명세의 줄을 글자와 글자쌍으로 맞춘다. 오프셋 비터비로 고르고 ±12줄 안에서 더 맞는 줄로 옮긴다
# 코드 줄: e5bde94 판 파일과 지금 파일을 difflib로 잇는다. 뒤에 기호(`foo`)가 있으면 지금 파일에서 가장 가까운 그 기호 줄로
#   표를 만든 때의 코드도 git에 없어서, 기호가 없는 번호는 e5bde94 때 맞았던 만큼만 맞는다
# 몇 번을 돌려도 같은 결과가 나온다. 명세나 코드가 바뀌면 다시 돌린다
# 실행: python3 -I tools/dev/trace_refresh.py [-n]   (-n은 쓰지 않고 보고만)
import os,re,sys,math,subprocess,difflib,collections
ROOT=os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BASE='e5bde94'
TD='docs/spec-trace/'
TABLES=['design-1-data-and-rules.md','design-2-screens-and-release.md','architecture.md']
DOCS={'D':'docs/DESIGN.md','A':'docs/ARCHITECTURE.md','dbs':'docs/db-status.md','R':'data/README.md','SN':'docs/server-notes.md'}
SERDOC={'D0.40':'D','D0.42':'D','A':'A','A11':'A','dbs':'dbs','R':'R','SN':'SN'}   # 계열 → 명세. 계열은 표를 만든 때의 판
SPEC_ALL={'docs/DESIGN.md':'D0.40','DESIGN':'D0.40','docs/ARCHITECTURE.md':'A','docs/db-status.md':'dbs','data/README.md':'R','data/README':'R','docs/server-notes.md':'SN'}
SPEC_ARCH={'A':'A','dbs':'dbs','R':'R','SN':'SN','server-notes':'SN'}
PREFIX={'A/':'apps/noriori/lib/','C/':'packages/noriori_core/lib/src/','S/':'packages/noriori_store/lib/src/','T/':'tools/',
        'app/':'apps/noriori/lib/','core/':'packages/noriori_core/lib/src/','store/':'packages/noriori_store/lib/src/'}
LAM=0.8;MU=0.01;WIN=12;ALPHA=0.04;MARGIN=0.15;KEYB=0.4

def git(*a):
    r=subprocess.run(['git',*a],cwd=ROOT,capture_output=True,text=True)
    return r.stdout if r.returncode==0 else None
def cur(p):
    try:return open(os.path.join(ROOT,p),encoding='utf-8').read()
    except (OSError,UnicodeDecodeError):return None
_bc={}
def base(p):
    if p not in _bc:_bc[p]=git('show',f'{BASE}:{p}')
    return _bc[p]

# 줄 번호 토큰. 범위는 a-b, a~b. 목록은 a,b 또는 ", a-b"
NUM=r'\d+(?:[-~]\d+)?'
NUMS=rf'{NUM}(?:,(?=\d){NUM}|, \d+[-~]\d+(?=[ ,.|)]|$))*'
TOK=re.compile(rf'(?<![A-Za-z0-9_])(?:(v0\.42) )?L({NUM})(?!\d)'
               rf'|(?<![A-Za-z0-9_./`-])(`?)([A-Za-z_.][\w./-]*)\3:({NUMS})(?!\d)'
               rf'|(?<=[ (]):({NUMS})(?!\d)'
               rf'|(?<![A-Za-z0-9_./-])([\w.-]+/[\w./-]+\.\w+|[\w-]+\.(?:dart|py|sh|yml|yaml|swift|kt|json))(?![\w/:-])')
SYM=re.compile(r' ?`([^`]+)`| ([A-Za-z_][A-Za-z0-9_]*)\b')
ELEM=re.compile(r'\d+')

files=set((git('ls-files') or '').split('\n'))|set((git('ls-files','-o','--exclude-standard') or '').split('\n'))
files={f for f in files if f and not f.startswith(('build/','data/'))}
BYNAME=collections.defaultdict(list)
for f in files:BYNAME[os.path.basename(f)].append(f)

def abbrs(text):
    a={};on=False
    for l in text.split('\n'):
        if l.startswith('## '):on='약어' in l
        m=on and re.match(r'\| `([^`]+)` \| `([^`]+)` \|$',l)
        if m:a[m.group(1)]=m.group(2)
    return a

def resolve(name,ab,prevdir):
    name=name.strip('`')
    while name in ab:name=ab[name]
    for k,v in PREFIX.items():
        if name.startswith(k):name=v+name[len(k):];break
    if '/' in name and (name in files or cur(name) is not None or base(name) is not None):return name
    if '/' not in name and name in files:return name   # 맨 이름이 저장소 뿌리에 있으면 그것
    c=BYNAME.get(os.path.basename(name),[])
    c=[x for x in c if x.endswith(name)]
    if len(c)>1 and prevdir:c=[x for x in c if os.path.dirname(x)==prevdir] or c
    return c[0] if len(c)==1 else None

def tokens(line,ab,arch,sec):
    # (시작, 끝, 대상, 번호 문자열, 기호, 단단한 기호인가). 대상은 ('spec',계열) 또는 ('code',경로) 또는 ('bad',이름)
    out=[];prev=None
    for m in TOK.finditer(line):
        if m.group(2):
            tgt=('spec','D0.42' if m.group(1) else 'D0.40');s,e=m.span(2)
        elif m.group(5):
            name=m.group(4);s,e=m.span(5)
            sp=SPEC_ALL.get(name) or (arch and SPEC_ARCH.get(name))
            if sp:tgt=('spec',sp+('11' if sp=='A' and sec else ''))
            else:
                p=resolve(name,ab,prev[1].rsplit('/',1)[0] if prev and prev[0]=='code' else None)
                if p:tgt=('code',p)
                elif '/' in name or '.' in name or name in ab:tgt=('bad',name)
                else:continue
        elif m.group(6):
            if not prev:continue
            tgt=prev;s,e=m.span(6)
        else:
            p=resolve(m.group(7),ab,prev[1].rsplit('/',1)[0] if prev and prev[0]=='code' else None)
            if p:prev=('code',p)
            continue
        sym=SYM.match(line,e)
        out.append((s,e,tgt,line[s:e],sym and (sym.group(1) or sym.group(2)),bool(sym and sym.group(1))))
        prev=tgt
    return out

def mask(line,ab,arch,sec):
    t=tokens(line,ab,arch,sec);o=[];i=0
    for s,e,*_ in t:o.append(line[i:s]+'#');i=e
    return ''.join(o)+line[i:]

# 요구 글이 명세 줄에 얼마나 들어 있는지. 글자와 글자쌍, 명세 안에서 드문 것일수록 무겁게 센다
def bg(s):
    s=re.sub(r'[\W_]+','',s.lower())
    return set(s)|{s[i:i+2] for i in range(len(s)-1)}
def fit(anchors,doc):
    D=[bg(x) for x in doc];n=len(D);Ls=sorted(anchors)
    if not Ls:return {},{},{}
    df=collections.Counter(g for d in D for g in d)
    w=lambda g:math.log((n+1)/(df.get(g,0)+1))+0.1
    R={L:[(r,sum(map(w,r))) for r in map(bg,anchors[L]) if r] for L in Ls}
    # 표 줄의 첫 칸이 요구 글에 그대로 들어 있으면 더하고, 표 머리 줄이면 뺀다
    norm=lambda x:re.sub(r'\([^)]*\)|[\s`*]+','',x).lower()
    hdr=[l.startswith('|') and i+1<n and doc[i+1].startswith('|-') for i,l in enumerate(doc)]
    key=[norm(l.split('|')[1]) if l.startswith('|') and not l.startswith('|-') and not hdr[i] else '' for i,l in enumerate(doc)]
    Q={L:[(norm(t),re.sub(r'[`*]','',t).lower()) for t in anchors[L]] for L in Ls}
    def has(k,q):   # 로마자 칸은 단어 경계로, 그 밖은 띄어쓰기를 무시하고 찾는다
        return re.search(rf'(?<![a-z0-9_]){re.escape(k)}(?![a-z0-9_])',q[1]) if k.isascii() else k in q[0]
    def S(L,N):
        if not 1<=N<=n or not R[L]:return 0.0
        d=D[N-1];k=key[N-1]
        b=KEYB if k and not k.isdigit() and any(has(k,q) for q in Q[L]) else -KEYB if hdr[N-1] else 0
        return b+sum(sum(w(g) for g in r&d)/t for r,t in R[L])/len(R[L])
    offs=list(range(-100,max(0,n-Ls[-1])+150));K=len(offs)
    v=None;bps=[]
    for L in Ls:
        e=[S(L,L+o) for o in offs]
        if v is None:v=e;bps.append(None);continue
        # 오프셋을 바꾸면 LAM + MU*|차이|. 양방향 거리 변환으로 K에 비례하게 구한다
        f=[x-LAM for x in v];fb=list(range(K))
        for k in range(1,K):
            if f[k-1]-MU>f[k]:f[k]=f[k-1]-MU;fb[k]=fb[k-1]
        for k in range(K-2,-1,-1):
            if f[k+1]-MU>f[k]:f[k]=f[k+1]-MU;fb[k]=fb[k+1]
        bp=[k if v[k]>=f[k] else fb[k] for k in range(K)]
        v=[max(v[k],f[k])+e[k] for k in range(K)];bps.append(bp)
    k=max(range(len(v)),key=v.__getitem__);ks=[0]*len(Ls)
    for i in range(len(Ls)-1,-1,-1):
        ks[i]=k
        if bps[i]:k=bps[i][k]
    got={};score={};dp={}
    for L,k in zip(Ls,ks):
        # 비터비 줄에서 WIN 줄 안에 거리당 ALPHA를 빼고도 MARGIN 넘게 맞는 줄이 있으면 옮긴다
        N=L+offs[k]
        d=max(sorted(range(-WIN,WIN+1),key=abs),key=lambda d:S(L,N+d)-ALPHA*abs(d))
        best=N+d if S(L,N+d)-ALPHA*abs(d)>S(L,N)+MARGIN else N
        dp[L]=N
        got[L]=best;score[L]=S(L,best)
    return got,score,dp

def specmap(got,dp,n):
    # 기준점이면 고른 줄, 아니면 가장 가까운 기준점의 비터비 오프셋. 첫 기준점 앞은 1행에서 0으로 줄여 간다
    # 범위 a~b는 그 안 기준점들이 지금 놓인 줄까지 덮는다
    Ls=sorted(got)
    def f(L):
        if L in got:return got[L]
        if not Ls:return L
        a=min(Ls,key=lambda x:(abs(x-L),x));o=dp[a]-a
        if L<Ls[0]:o=round(o*(L-1)/max(1,Ls[0]-1))
        return max(1,min(n,L+o))
    def r(a,b):
        ins=[got[x] for x in Ls if a<=x<=b]
        return min([f(a)]+ins),max([f(b),f(a)]+ins)
    return f,r

def linemap(old,new):
    sm=difflib.SequenceMatcher(None,old,new,autojunk=False);m={}
    for tag,i1,i2,j1,j2 in sm.get_opcodes():
        for i in range(i1,i2):
            m[i+1]=j1+(i-i1)+1 if tag=='equal' else j1+min(i-i1,max(j2-j1-1,0))+1 if tag=='replace' else j1+1
    return lambda x:m.get(x,x+len(new)-len(old) if x>len(old) else x)

_cm={}
def codemap(p):
    if p not in _cm:
        o,c=base(p),cur(p)
        _cm[p]=None if c is None else (c.split('\n'),linemap(o.split('\n'),c.split('\n')) if o is not None else None)
    return _cm[p]

def symline(lines,sym,near):
    for c in [sym]+sorted(re.findall(r'[A-Za-z_][A-Za-z0-9_]{2,}',sym),key=len,reverse=True):
        pat=re.compile(re.escape(c) if not re.fullmatch(r'\w+',c) else rf'(?<![A-Za-z0-9_]){re.escape(c)}(?![A-Za-z0-9_])')
        hits=[i+1 for i,l in enumerate(lines) if pat.search(l)]
        if hits:return min(hits,key=lambda h:(abs(h-near),h))
    return None

def main(dry):
    T={}
    for t in TABLES:
        b,c=base(TD+t),cur(TD+t)
        T[t]=(b.split('\n'),c.split('\n'),abbrs(c),t=='architecture.md')
    def sections(lines):
        s=False;o=[]
        for l in lines:
            if l.startswith('#'):s='v0.11에서 새로' in l
            o.append(s)
        return o
    # 지금 표의 줄마다 기준 판의 짝 줄을 찾는다. 번호를 가린 글이 같으면 짝, 손으로 고친 줄은 같은 자리끼리 짝
    # 짝 줄에서 (대상, 몇 번째) 자리가 같은 번호를 기준 번호로 쓴다. 기준 판에 없던 번호는 그대로 둔다
    L2={}
    for t,(B,C,ab,arch) in T.items():
        sb,sc=sections(B),sections(C)
        mb=[mask(l,ab,arch,x) for l,x in zip(B,sb)];mc=[mask(l,ab,arch,x) for l,x in zip(C,sc)]
        pair={}
        for tag,i1,i2,j1,j2 in difflib.SequenceMatcher(None,mb,mc,autojunk=False).get_opcodes():
            if tag in('equal','replace'):
                for k in range(min(i2-i1,j2-j1)):pair[j1+k]=i1+k
        rows=[]
        for j,l in enumerate(C):
            bslot={};cnt=collections.Counter()
            if j in pair:
                for x in tokens(B[pair[j]],ab,arch,sb[pair[j]]):cnt[x[2]]+=1;bslot[(x[2],cnt[x[2]])]=x[3]
            cnt=collections.Counter();tk=[]
            for x in tokens(l,ab,arch,sc[j]):cnt[x[2]]+=1;tk.append(x+(bslot.get((x[2],cnt[x[2]])),))
            rows.append(tk)
        L2[t]=rows
    # 명세 기준점: 판정 칸이 있는 표의 행 칸 번호(기준 판)와 그 행의 요구 글(지금 표). 요구가 아닌 줄의 표는 뺀다
    anchors=collections.defaultdict(lambda:collections.defaultdict(list))
    for t,(B,C,ab,arch) in T.items():
        for l,tk in zip(C,L2[t]):
            cells=l.split('|')
            if len(cells)<6 or not l.startswith('| '):continue
            i=2 if cells[1].strip().isdigit() else 1
            lo=len('|'.join(cells[:i]))+1;hi=lo+len(cells[i])
            for s,e,tgt,txt,sym,hard,src in tk:
                if tgt[0]=='spec' and src and lo<=s<e<=hi:anchors[tgt[1]][int(ELEM.match(src).group())].append(cells[i+1].replace('`',''))
    SM={};low=[]
    for ser in SERDOC:
        doc=cur(DOCS[SERDOC[ser]]).split('\n')
        got,score,dp=fit(anchors.get(ser,{}),doc);SM[ser]=specmap(got,dp,len(doc))
        low+=[(ser,L,got[L],round(score[L],2)) for L in sorted(got) if score[L]<0.3]
    rep=collections.defaultdict(list);changed=collections.Counter();total=collections.Counter()
    def remap(txt,tgt,sym,hard):
        # 번호 문자열 하나를 새 번호 문자열로. 바꿀 수 없으면 None과 사유
        if tgt[0]=='bad':return None,'경로를 못 찾음'
        if tgt[0]=='spec':
            f,rg=SM[tgt[1]];out=[]
            for m in re.finditer(r'(\d+)(?:([-~])(\d+))?|[^\d]+',txt):
                if not m.group(1):out.append(m.group())
                elif m.group(3):a,b=rg(int(m.group(1)),int(m.group(3)));out.append(f'{a}{m.group(2)}{b}')
                else:out.append(str(f(int(m.group(1)))))
            return ''.join(out),None
        cm=codemap(tgt[1])
        if cm is None:return None,'파일 없음'
        lines,lm=cm;single=re.fullmatch(NUM,txt)
        if sym and single:
            a0=int(re.match(r'\d+',txt).group());near=lm(a0) if lm else a0
            h=symline(lines,sym,near)
            if h is None and hard:return None,f'기호 `{sym}` 없음'
            if h is not None:
                m=re.fullmatch(r'(\d+)(?:([-~])(\d+))?',txt);r=str(h)
                if m.group(3):r+=m.group(2)+str(h+max(0,(lm(int(m.group(3))) if lm else int(m.group(3)))-near))
                return r,None
        if lm is None:return None,'기준 판에 없는 파일'
        return re.sub(r'\d+',lambda m:str(lm(int(m.group()))),txt),None
    for t,(B,C,ab,arch) in T.items():
        out=[]
        for j,l in enumerate(C):
            o=[];i=0
            for s,e,tgt,txt,sym,hard,src in L2[t][j]:
                o.append(l[i:s]);i=e;total[t]+=1
                if src is None:o.append(txt);continue
                new,why=remap(src,tgt,sym,hard)
                if new is None:
                    new=txt;rep[t].append((j+1,tgt[1],txt,why))
                if new!=txt:changed[t]+=1
                o.append(new)
            o.append(l[i:]);out.append(''.join(o))
        if not dry and out!=C:open(os.path.join(ROOT,TD+t),'w',encoding='utf-8').write('\n'.join(out))
    for t in TABLES:
        print(f'{t}: 번호 {total[t]}개 중 {changed[t]}개 바꿈, 못 바꾼 것 {len(rep[t])}개')
        for j,p,txt,why in rep[t]:print(f'  {t}:{j}  {p}:{txt}  {why}')
    print(f'요구 글과 덜 맞는 명세 기준점 {len(low)}개 (포함률 0.3 미만)')
    for x in low:print('  ',*x)
if __name__=='__main__':main('-n' in sys.argv)
