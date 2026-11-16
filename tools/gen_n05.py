# -*- coding: utf-8 -*-
# 国土数値情報 鉄道時系列(N05)의 폐지 노선을 노리츠부시 표, 위키백과, station_database와 교차 검증해 기록 가능 노선으로 만든다 (DESIGN §2.10, §2.12, §16)
# N05가 1950년 이후 여객 철도의 닫힌 목록이다. 같은 선로를 잇는 기록을 노선 묶음으로 만들고 묶음마다 판정한다
#   in_db: 노리츠부시 표나 옛 폐선 표에 이미 있음 / ok: 기록 가능으로 넣음 / archive: 열람 전용 / out: 수록 대상 아님 (§4.1) / tram: 옛 노면전차망 (다음 단계) / current: 현행 노선의 일부
# 역 목록·순서는 위키 노선도·역 일람과 N05 역이 맞아야 하고, 영업km는 위키 값을 N05 역 사이 직선거리로 검사한다
# 구간의 폐지·개업 해는 N05 역의 기간으로 정하고, 위키 연혁 줄에서 그 해·그 구간의 날짜를 찾는다. 없으면 해만 쓴다
# 결과: data/imports/n05/lines.json (노리츠부시 표 모양, gen_source가 읽음), data/candidates/n05_report.json
import sys,os,re,json,gzip,hashlib,collections,math,zipfile
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from lib import *
from decimal import Decimal as _Dec,ROUND_HALF_UP as _HUP
def dround(x,n=1):
    """km 반올림은 사사오입이다. float round()는 15.85를 15.8로 내린다(이진 표현·은행가 반올림). 6자리에서 float 잡음을 먼저 지운다"""
    return None if x is None else float(_Dec(repr(round(x,6))).quantize(_Dec(1).scaleb(-n),rounding=_HUP))
import wparse as w
CUT='1950-01-01'
WIKI=os.path.join(IMP,'wiki')
OUT=os.path.join(IMP,'n05','lines.json')
REP=os.path.join(CAND,'n05_report.json')
# 노선마다 위키 원문을 사람이 읽고 만든 정답 표. 있으면 자동 대조 결과 대신 쓴다 (역, km, 구간별 개업·폐지·휴지, 역 기간)
FIXF=os.path.join(ROOT,'data','overrides','n05_fix.json')
def seglen(a,b):
    q=math.radians((a[1]+b[1])/2);return math.hypot((a[1]-b[1])*111,(a[0]-b[0])*111*math.cos(q))
def yr(v):
    try:return int(v)
    except (TypeError,ValueError):return None
def sn(s):
    """역 이름 대조용. 괄호, 駅·停留場, 표의 표시 기호, 가나 표기 차이를 지운다"""
    s=re.sub(r'[（(].*?[)）]','',(s or '').strip().strip('*[]').replace('【旧】',''))
    s=re.sub(r'(駅|停留場|停留所|停車場|仮乗降場|乗降場|信号場)$','',s.strip())
    s=znorm(s.replace('ヶ','ケ').replace('ヵ','カ').replace('之','ノ').replace('の','ノ')).translate(VARIANT)
    # 위키는 「相生町4丁目」, N05는 「相生町四丁目」처럼 숫자를 다르게 쓴다
    return re.sub(r'\d+',lambda m:kanji_num(int(m.group())),s)
def kanji_num(n):
    d='〇一二三四五六七八九'
    if n<10:return d[n]
    if n<100:return ('' if n//10==1 else d[n//10])+'十'+(d[n%10] if n%10 else '')
    return ''.join(d[int(c)] for c in str(n))
# 위키와 N05가 서로 다르게 쓰는 이체자 (藪波/薮波, 白旗城趾前/白旗城址前, 田峯/田峰, 舘合/館合)
VARIANT=str.maketrans({'薮':'藪','址':'趾','峰':'峯','館':'舘','嶋':'島','嶌':'島','邊':'辺','邉':'辺','冨':'富','曾':'曽'})

# ---- N05 노선 묶음. 같은 선로를 잇는 기록(사업자 교체, 개칭)을 하나로 본다
ALLST=collections.defaultdict(list)   # 모든 N05 역. 이름 → 역들
def groups():
    z=zipfile.ZipFile(os.path.join(IMP,'n05','N05-24_GML.zip'))
    R=[]
    for f in json.loads(z.read('UTF-8/N05-24_RailroadSection2.geojson'))['features']:
        p=f['properties'];g=f['geometry']
        for l in (g['coordinates'] if g['type']=='MultiLineString' else [g['coordinates']]):
            R.append(dict(line=p['N05_002'],op=p['N05_003'],kind=p['N05_001'],yb=yr(p['N05_005b']),ye=yr(p['N05_005e']),coords=[tuple(c[:2]) for c in l]))
    GC=200;IDX=collections.defaultdict(list)
    def dseg(x,a,b):
        cs=math.cos(math.radians(x[1]))
        ax,ay=(a[0]-x[0])*cs,a[1]-x[1];bx,by=(b[0]-x[0])*cs,b[1]-x[1]
        ex,ey=bx-ax,by-ay;t=max(0,min(1,-(ax*ex+ay*ey)/((ex*ex+ey*ey) or 1e-18)))
        return 111*math.hypot(ax+t*ex,ay+t*ey)
    for i,r in enumerate(R):
        for u,v in zip(r['coords'],r['coords'][1:]):IDX[(int(u[0]*GC),int(u[1]*GC))].append((u,v,i))
    def near(x):
        o=set()
        for a in (-1,0,1):
            for b in (-1,0,1):
                for u,v,i in IDX.get((int(x[0]*GC)+a,int(x[1]*GC)+b),()):
                    if dseg(x,u,v)<.05:o.add(i)
        return o
    def samples(c,step=.2):
        o=[c[0]];acc=0
        for a,b in zip(c,c[1:]):
            acc+=seglen(a,b)
            if acc>=step:o.append(b);acc=0
        return o+[c[-1]]
    par=list(range(len(R)))
    def find(i):
        while par[i]!=i:par[i]=par[par[i]];i=par[i]
        return i
    SAMP=[samples(r['coords']) for r in R]
    # 기록의 선로 점 절반 이상이 다른 기록과 50m 안이면 같은 노선
    for i in range(len(R)):
        cnt=collections.Counter(j for x in SAMP[i] for j in near(x) if j!=i)
        for j,c in cnt.items():
            if c>=.5*len(SAMP[i]) or c>=.5*len(SAMP[j]):par[find(i)]=find(j)
    G=collections.defaultdict(list)
    for i in range(len(R)):G[find(i)].append(i)
    ST=collections.defaultdict(list)
    for f in json.loads(z.read('UTF-8/N05-24_Station2.geojson'))['features']:
        p=f['properties'];g=f['geometry'];c=g['coordinates']
        c=c[len(c)//2] if g['type']=='LineString' else (c if g['type']=='Point' else c[0][len(c[0])//2])
        ST[(p['N05_002'],p['N05_003'])].append(dict(name=p['N05_011'],yb=yr(p['N05_005b']),ye=yr(p['N05_005e']),pt=(round(c[0],6),round(c[1],6))))
    for v in ST.values():
        for s_ in v:ALLST[sn(s_['name'])].append(s_)
    CITY=re.compile(r'(市|都|市交通局|市電気局)$')
    TRAMNAME=re.compile(r'市内線|軌道線|国道線|市電|電気軌道|路面|併用軌道|築港線|循環線')
    out=[]
    for ix in G.values():
        recs=[R[i] for i in ix]
        ends=[r['ye'] for r in recs if r['ye'] and r['ye']<9999]
        if not ends or max(ends)+1<1950:continue
        alive=any(r['ye'] and r['ye']>=9999 for r in recs)
        names=sorted({(r['line'],r['op']) for r in recs})
        st={}
        for n in names:
            for s in ST.get(n,()):
                k=(s['name'],round(s['pt'][0],3),round(s['pt'][1],3))
                # N05는 사업자가 바뀌면 기록을 새로 시작한다. 역의 시작 해는 같은 역의 가장 이른 기록
                yb=min([x for x in (s['yb'],(st.get(k) or {}).get('yb')) if x] or [None])
                if k not in st or (s['ye'] or 0)>(st[k]['ye'] or 0):st[k]=dict(s,line=n[0],op=n[1])
                st[k]['yb']=yb
        kinds=sorted({r['kind'] for r in recs})
        tram=('3' in kinds and any(CITY.search(r['op']) for r in recs)) or any(TRAMNAME.search(r['line']) for r in recs)
        out.append(dict(names=[list(n) for n in names],closed_year=max(ends)+1,cls='current' if alive else ('tram' if tram else 'line'),stations=sorted(st.values(),key=lambda s:(s['ye'] or 0,s['name'])),pts=[p for i in ix for p in SAMP[i]]))
    out.sort(key=lambda x:(x['cls'],x['closed_year'],x['names']))
    return out

# ---- 위키 문서
def doc(t):
    f=os.path.join(WIKI,hashlib.md5(t.encode()).hexdigest()[:14]+'.json.gz')
    if not os.path.exists(f):return None
    r=json.load(gzip.open(f,'rt',encoding='utf-8'))
    return r if r.get('html') else None
ST_RX=re.compile(r'([^\s／：・（(#*]+?)(?:駅|停留場|停車場|仮乗降場|乗降場)')
ICON=re.compile(r'(BHF|HST|BST)')
def diagram(rec):
    """노선도 틀의 역과 km"""
    rows,_=w.extract(None,8,w.parse_text(rec['html']))
    fl=[]
    for r in rows:
        if isinstance(r,(list,tuple)) and len(r)==2 and isinstance(r[1],list):fl+=[x for x in r[1] if 'h' not in x]
        elif isinstance(r,dict) and 'h' not in r:fl.append(r)
    o=[]
    for r in fl:
        ic=[x for c in r['c'] for x in c]
        m=ST_RX.search(r['t'])
        if m and any(ICON.search(x) for x in ic):
            k=r['k'] if re.match(r'^[\d.]+$',r['k'] or '') else None
            o.append((m.group(1),float(k) if k else None,None))
    return o
def table(rec):
    """역 일람 표의 역 이름, 누계 km, 읽기"""
    root=w.parse_text(rec['html']);best=[]
    for t in w.walk(root):
        if t.t!='table' or 'wikitable' not in (t.a.get('class') or ''):continue
        rows=[q for q in w.walk(t) if q.t=='tr']
        if len(rows)<3:continue
        head=[re.sub(r'\s+','',w.text(c)) for c in rows[0].c if isinstance(c,w.N) and c.t in('th','td')]
        ni=next((i for i,h in enumerate(head) if '駅名' in h or h in('駅','停留場名','停留場')),None)
        ki=next((i for i,h in enumerate(head) if '累計' in h or '営業キロ' in h or 'キロ程' in h or '起点' in h),None)
        yi=next((i for i,h in enumerate(head) if h in('読み','よみ','駅名読み','読み方') or 'よみ' in h),None)
        ki2=[i for i,h in enumerate(head) if '累計' in h]
        if ni is None or ki is None:continue
        if ki2:ki=ki2[0]
        between='駅間' in head[ki] and not ki2
        o=[]
        for r in rows[1:]:
            c=[x for x in r.c if isinstance(x,w.N) and x.t in('th','td')]
            if len(c)<=max(ni,ki):continue
            nm=re.sub(r'\s+','',w.text(c[ni]));km=re.sub(r'[^\d.]','',w.text(c[ki]))
            # 읽기: 읽기 칸, 또는 역 이름 칸 안의 「黒部（くろべ）」
            kana=None
            if yi is not None and yi<len(c):kana=re.sub(r'[^ぁ-ゖー]','',w.text(c[yi])) or None
            m=re.search(r'[（(]([ぁ-ゖー・]+)[)）]',nm)
            if not kana and m:kana=m.group(1).replace('・','')
            nm=re.sub(r'(駅|停留場|停留所)$','',re.sub(r'[（(].*$','',nm))
            if nm and re.match(r'^\d+(\.\d+)?$',km):o.append((nm,float(km),kana))
            elif nm and not o and not km:o.append((nm,None,kana))   # 역 사이 거리 표의 첫 역
        if between and o:
            run=0.0;c2=[]
            for a,b,k in o:
                run=dround(run+(b or 0));c2.append((a,run,k))
            o=c2
        if len(o)>len(best):best=o
    return best
def prose(rec):
    """駅一覧 절의 줄글 목록 「早来駅 (0.0km) - 中土場駅 (2.3km) - …」. km가 없으면 순서만 있다"""
    t=rec.get('wikitext') or ''
    m=re.search(r'==+\s*(?:駅一覧|駅・停留場一覧|停留場一覧)\s*==+\n(.*?)(?=\n==)',t,re.S)
    if not m:return []
    best=[]
    for line in m.group(1).split('\n'):
        line=re.sub(r'<ref[^>]*/>|<ref.*?</ref>','',line)
        line=re.sub(r'\[\[(?:[^\]|]*\|)?([^\]]*)\]\]',r'\1',line).strip('*: ')
        parts=re.split(r'\s+[-－–―]\s+',line)
        if len(parts)<2:continue
        o=[]
        for p in parts:
            k=re.search(r'[（(]\s*([\d.]+)\s*(?:km|ｋｍ|キロ)?\s*[)）]',p)
            nm=re.sub(r'[（(].*$','',p).strip()
            nm=re.sub(r'(駅|停留場|停留所|停車場)$','',nm)
            if not nm or len(nm)>12:o=[];break
            o.append((nm,float(k.group(1)) if k else None,None))
        if len(o)>len(best):best=o
    return best
def runs(rows):
    """노선도는 지선과 다른 구간이 이어 붙어 km가 다시 시작한다. km가 한 방향으로 이어지는 토막으로 나눈다"""
    seen={sn(r[0]) for r in rows if r[1] is not None}
    rows=[r for r in rows if r[1] is not None or sn(r[0]) not in seen]
    o=[];cur=[]
    for r in rows:
        k=[q[1] for q in cur if q[1] is not None]
        if r[1] is not None and len(k)>=2 and (k[-1]-k[-2])*(r[1]-k[-1])<=0:o.append(cur);cur=[]
        elif r[1] is not None and k and r[1]==k[-1]:o.append(cur);cur=[]
        cur.append(r)
    o.append(cur)
    return [c for c in o if len(c)>=2]
def variants(rec):
    """위키 문서에서 뽑은 역 목록 후보들"""
    d=diagram(rec);t=table(rec);p=prose(rec)
    o=[('diagram',d)]+[('diagram',c) for c in runs(d)]
    o+=[('table',t)]
    # 역 일람의 km 칸이 역 사이 거리일 때 (머리 칸이 두 줄이라 「駅間」을 못 읽음)
    if t and any(b[1] is not None and a[1] is not None and b[1]<a[1] for a,b in zip(t,t[1:])):
        run=0.0;c=[]
        for a,k,kn in t:
            run=dround(run+(k or 0));c.append((a,run,kn))
        o.append(('table',c))
    o+=[('prose',p)]
    # 같은 이름이 잇달아 나오면(신호소와 역, 옛 위치) 하나로, 떨어져 나오면 거기서 나눈다 (지선)
    o2=[]
    for k,rows in o:
        r2=[]
        for r in rows:
            if r2 and sn(r2[-1][0])==sn(r[0]):
                if r2[-1][1] is None:r2[-1]=r
                continue
            r2.append(r)
        cur=[]
        for r in r2:
            if any(sn(q[0])==sn(r[0]) for q in cur):o2.append((k,cur));cur=[]
            cur.append(r)
        o2.append((k,cur))
    o=o+[x for x in o2 if len(x[1])>=2]
    # 역 이름 끝의 각주 기호와 駅·停留所 표기를 지운다. 노리츠부시 표에서 *는 폐역 표시라 남기면 안 된다
    def nm(a):
        a=re.sub(r'^[*#†※]+|[*#†※]+$','',a.strip())
        return re.sub(r'(駅|停留場|停留所|停車場)$','',a) or a
    return [(k,[(nm(a),km,kn) for a,km,kn in rows]) for k,rows in o]
def lead_kana(rec,name):
    """문서 첫 줄의 읽기: '''名前'''（なまえ）. 굵은 이름이 이 노선 이름일 때만 (넘겨주기로 다른 노선 문서일 수 있다)"""
    m=re.search(r"'''([^']+)'''\s*[（(]\s*([ぁ-ゖー・ 　]+)",rec.get('wikitext') or '')
    if not m or sn(m.group(1))!=sn(name):return None
    return re.sub(r'[・ 　]','',m.group(2))
def jd(s):
    """위키 날짜. 날까지 있어야 날짜로 본다"""
    s=re.sub(r'\[\[|\]\]','',s or '')
    m=re.search(r'(\d{4})年(?:（[^）]*）)?\s*(\d{1,2})月\s*(\d{1,2})日',s)
    if m:return f'{int(m.group(1)):04d}-{int(m.group(2)):02d}-{int(m.group(3)):02d}'
    return None
def history(rec):
    """연혁 줄: (날짜, 종류 open/close, 구간 끝 역 이름 집합 또는 None=전선). 「** 9月7日」처럼 해가 윗줄에 있는 줄도 읽는다"""
    o=[];year=None
    for line in (rec.get('wikitext') or '').split('\n'):
        if not line.startswith('*'):continue
        x=re.sub(r'<ref[^>]*/>|<ref.*?</ref>|\{\{.*?\}\}|<!--.*?-->','',line)
        x=re.sub(r'\[\[(?:[^\]|]*\|)?([^\]]*)\]\]',r'\1',x)
        m=re.match(r'^\*\s*(\d{4})年',x)
        if m:year=m.group(1)
        elif not line.startswith('**'):year=None
        d=jd(x)
        if not d and year and line.startswith('**'):
            m=re.match(r'^\*+\s*(\d{1,2})月\s*(\d{1,2})日',x)
            if m:d=f'{year}-{int(m.group(1)):02d}-{int(m.group(2)):02d}'
        if not d:continue
        if re.search(r'申請|許可|認可|特許|免許|届|貨物|休止|計画|決定|議決|着工|起工|乗り?入れ|変電所|設定|列車',x):continue
        if re.search(r'(間|全線|線|鉄道|全区間|事業)(の|を|が)?(旅客)?(営業|運輸営業|鉄道)?(を)?(正式)?廃止',x) or re.search(r'日\s*[：:]?\s*(旅客営業を)?廃止',x):kind='close'
        elif re.search(r'(間|全線|線|鉄道)(が|を)?(開業|開通|延伸|延長)',x):kind='open'
        else:continue
        m=None
        for m_ in re.finditer(r'([^\s、。：:（()）\-－–]+?)(?:駅|停留場)?\s*[-－–〜～]\s*([^\s、。（(]+?)(?:駅|停留場)?間',x):
            if not re.search(r'\d|年|月',m_.group(1)+m_.group(2)):m=m_;break
        o.append((d,kind,{sn(m.group(1)),sn(m.group(2))} if m and '全線' not in x else None))
    return o
def clean(s):return re.sub(r'(株式会社|（.*?）|\(.*?\))','',s or '').strip()
OPSHORT={'名古屋鉄道':'名鉄','西日本鉄道':'西鉄','南海電気鉄道':'南海','東京急行電鉄':'東急','近畿日本鉄道':'近鉄','京阪電気鉄道':'京阪','阪神電気鉄道':'阪神','阪急電鉄':'阪急','京福電気鉄道':'京福'}
def titles(x):
    """위키 문서 이름 후보. 노선 이름, 회사+노선, 회사 약칭+노선, 회사 문서"""
    o=[]
    for line,op in x['names']:
        op=clean(op);line=clean(line)
        if line in(op,'本線','鉄道線') or line.startswith(op):o.append(op if line in('本線','鉄道線') or line==op else line)
        else:o+=[op+line,line,OPSHORT.get(op,op)+line]
        o+=[line+'線' if not line.endswith('線') else line,op+'線',op+'鉄道線',op]
    return list(dict.fromkeys(o))
# ---- 이미 있는 노선: 노리츠부시 표와 옛 폐선 표의 역 위치
N=hidden_insert(official(json.load(open(os.path.join(IMP,'noritsubushi','lines.json'),encoding='utf-8'))))
N+=json.load(open(os.path.join(IMP,'stationdb','old_lines.json'),encoding='utf-8'))
POS=collections.defaultdict(list)
for r in N:
    for lab,k in r['s']:POS[sn(lab)].append((r['id'],float(k),r['t']))
def covered(a,ka,b,kb):
    """두 역이 같은 표에 있고 그 표의 km 간격이 위키 간격과 맞으면 이미 있는 구간"""
    d=abs(kb-ka)
    for ra,xa,t in POS.get(sn(a),()):
        for rb,xb,_ in POS.get(sn(b),()):
            if ra==rb and abs(abs(xb-xa)-d)<=.3*d+.5:return t
    return None
OUTSCOPE=HT['N05_OUT']
def scope(x):
    """수록 대상 밖 (DESIGN §4.1). 簡易軌道는 철도사업법·궤도법 근거가 없다"""
    for line,op in x['names']:
        if '簡易軌道' in op or re.search(r'[町村]営軌道$',line+op) or re.search(r'[町村]営軌道',op):return '簡易軌道 (철도사업법·궤도법 근거 없음)'
        for k,v in OUTSCOPE.items():
            if k in(line,op,op+line):return v
    return None

def judge(x,used=()):
    """한 묶음의 판정. (결과 dict, 이유). used는 앞서 다른 노선으로 넣은 가운데 역"""
    n5=[s for s in x['stations'] if id(s) not in used]
    names5=collections.defaultdict(list)
    for s in n5:names5[sn(s['name'])].append(s)
    best=None
    for t in titles(x):
        rec=doc(t)
        if not rec:continue
        for kind,rows in variants(rec):
            if len(rows)<2:continue
            hit=sum(1 for r in rows if sn(r[0]) in names5)
            nk=sum(1 for r in rows if r[1] is not None)
            score=(hit/len(rows)>=.7 and nk>=2 and len({sn(r[0]) for r in rows})==len(rows),hit,hit/len(rows),nk)
            if best is None or score>best[0]:best=(score,t,rec,kind,rows)
    if not best:return None,'위키 문서 없음 또는 역 목록 없음'
    (_,hit,share,_),t,rec,kind,rows=best
    order=[r[0] for r in rows]
    if share<.7:return dict(title=t,revid=rec.get('revid'),order=order),f'위키 역 목록과 N05 역이 {share:.0%}만 맞음 ({t})'
    if len({sn(r[0]) for r in rows})!=len(rows):return dict(title=t,revid=rec.get('revid'),order=order),f'역 이름 중복 ({t}, 지선 포함 표)'
    # km가 없는 역은 확인할 수 없어 뺀다
    if sum(1 for r in rows if r[1] is not None)<2:return dict(title=t,revid=rec.get('revid'),order=order),f'위키에 영업km 없음 ({t})'
    nokm=[r[0] for r in rows if r[1] is None];rows=[r for r in rows if r[1] is not None]
    if len(nokm)>max(1,.25*(len(rows)+len(nokm))):return dict(title=t,revid=rec.get('revid'),order=order),f'위키 노선도에 km가 빠진 역이 {len(nokm)}개 ({t})'
    # 끝 역이 다른 회사 노선의 N05 역이면 그 역에서 갈라지는 노선이다 (有田鉄道 藤並, 出石鉄道 江原). N05 선로가 그 역에 닿고 km가 맞을 때만 잇는다
    ext=[]
    for end,nb in ((0,1),(-1,-2)):
        if len(rows)<2:break
        r,q=rows[end],rows[nb]
        if sn(r[0]) in names5 or sn(q[0]) not in names5:continue
        dk=abs(r[1]-q[1])
        for c in ALLST.get(sn(r[0]),()):
            if (c['ye'] or 9999)<1950 or min(seglen(c['pt'],p) for p in x['pts'])>.3:continue
            if any(seglen(c['pt'],s['pt'])<=dk*1.1+.4 and dk<=seglen(c['pt'],s['pt'])*3+1.5 for s in names5[sn(q[0])]):
                names5[sn(r[0])].append(c);ext.append(r[0]);break
    # N05에 없는 끝 역은 1950년 전에 없어진 구간이다. 가운데의 N05에 없는 역은 확인되지 않아 뺀다
    while rows and sn(rows[0][0]) not in names5:rows=rows[1:]
    while rows and sn(rows[-1][0]) not in names5:rows=rows[:-1]
    drop=nokm+[r[0] for r in rows if sn(r[0]) not in names5]
    rows=[r for r in rows if sn(r[0]) in names5]
    if len(rows)<2:return dict(title=t,revid=rec.get('revid'),order=order),f'N05와 맞는 역이 둘 미만 ({t})'
    km=[r[1] for r in rows]
    if not all(a<b for a,b in zip(km,km[1:])):
        if all(a>b for a,b in zip(km,km[1:])):rows=[(a,km[0]-k,c) for a,k,c in rows]
        else:return dict(title=t,revid=rec.get('revid'),order=order),f'km가 단조롭지 않음 ({t})'
    base=rows[0][1];rows=[(a,dround(k-base),c) for a,k,c in rows]
    # 역마다 N05 점 하나. 같은 이름이 여럿이면 앞 역에서 가까운 것
    pick=[];prev=None
    for a,k,c in rows:
        cs=names5[sn(a)]
        s=min(cs,key=lambda s:seglen(prev['pt'],s['pt']) if prev else -(s['ye'] or 0));pick.append(s);prev=s
    # km 검사: 역 사이 직선거리는 영업km보다 길 수 없고, 영업km가 직선거리의 3배를 넘으면 위치나 km가 틀렸다
    bad=0
    for (a,ka,_),(b,kb,_),sa,sb in zip(rows,rows[1:],pick,pick[1:]):
        d=seglen(sa['pt'],sb['pt']);dk=kb-ka
        if d>dk*1.1+.4 or dk>d*3+1.5:bad+=1
    pairs=len(rows)-1
    if bad>max(1,.15*pairs):return dict(title=t,revid=rec.get('revid'),order=order),f'km와 N05 역 위치가 {bad}/{pairs}쌍 어긋남 ({t})'
    # 역 목록 검사: 두 역 사이에 같은 시기의 N05 역이 있는데 위키 목록에 없으면 그 역은 km를 몰라 열람 전용으로 둔다 (§4.1)
    got={sn(a) for a,_,_ in rows}|{sn(a) for a in drop};miss=[]
    for (a,_,_),(b,_,_),sa,sb in zip(rows,rows[1:],pick,pick[1:]):
        d=seglen(sa['pt'],sb['pt']);y0=min(sa['ye'] or 0,sb['ye'] or 0)
        for q in x['stations']:
            if sn(q['name']) in got or re.search(r'(荷扱所|信号所|信号場|貨物)$',q['name']) or (q['ye'] or 0)<y0-1 or (q['yb'] or 0)>y0:continue
            if seglen(q['pt'],sa['pt'])+seglen(q['pt'],sb['pt'])<=d*1.1+.2:miss.append((q['name'],a,b));got.add(sn(q['name']))
    if len(miss)>max(1,.25*len(rows)):return dict(title=t,revid=rec.get('revid'),order=order),f'위키 목록에 없는 N05 역이 {len(miss)}개 ({t})'
    return dict(title=t,revid=rec.get('revid'),rec=rec,kind=kind,rows=rows,pick=pick,drop=drop,miss=miss,km_bad=bad,share=round(share,2),ext=ext),'ok'

def sections(rows,pick,hist,key,body=''):
    """구간별 해와 날짜. key가 'ye'면 폐지, 'yb'면 개업. N05 역 기간으로 해를 정하고 위키 연혁에서 같은 해·같은 구간의 날짜를 찾는다"""
    n=len(rows)
    y=[s[key] for s in pick]
    if key=='ye':
        # 가운데 역만 먼저 없어졌으면 노선은 이어졌다. 그 역의 해는 이웃 역의 해로 본다
        e=list(y)
        for i in range(1,n-1):
            if (y[i] or 0)<min(y[i-1] or 0,y[i+1] or 0):e[i]=min(y[i-1],y[i+1])
        Y=[min(e[i],e[i+1])+1 for i in range(n-1)]
    else:
        e=list(y)
        for i in range(1,n-1):
            if (y[i] or 0)>max(y[i-1] or 0,y[i+1] or 0):e[i]=max(y[i-1],y[i+1])
        Y=[max(e[i] or 1950,e[i+1] or 1950,1950) for i in range(n-1)]
    out=[];i=0
    kind='close' if key=='ye' else 'open'
    H=[h for h in hist if h[1]==kind]
    while i<n-1:
        j=i
        while j+1<n-1 and Y[j+1]==Y[i]:j+=1
        a,b=rows[i][0],rows[j+1][0];yy=Y[i]
        ends={sn(a),sn(b)}
        last=(kind=='close' and yy==max(Y)) or (kind=='open' and yy==min(Y))
        d=None;src='n05'
        for dy in (0,-1,1):
            c=[h[0] for h in H if int(h[0][:4])==yy+dy and (h[2]==ends or (h[2] is None and last))]
            if c:d=min(c) if kind=='open' else max(c);src='wikipedia+n05';break
        if not d and kind=='close' and last:
            # 인포박스의 폐지일
            m=re.search(r'\|\s*廃止\s*=\s*(.+)',body)
            x=jd(m.group(1)) if m else None
            if x and abs(int(x[:4])-yy)<=1:d=x;src='wikipedia+n05'
        if not d and kind=='close' and last:
            # 연혁 줄에 없으면 본문의 「全線…廃止」 문장. N05의 해 ±1에 날짜가 하나뿐일 때만 쓴다 (다른 사건의 날짜를 피한다)
            c=set()
            for t in re.split(r'[。\n]',re.sub(r'<ref.*?</ref>|<ref[^>]*/>|\[\[(?:[^\]|]*\|)?([^\]]*)\]\]',lambda m:m.group(1) or '',body)):
                if '廃止' in t and re.search(r'全線|廃線|鉄道線|全区間',t) and not re.search(r'申請|許可|認可|貨物|休止|計画|バス',t):
                    for m in re.finditer(r'(\d{4})年(?:（[^）]*）)?\s*(\d{1,2})月\s*(\d{1,2})日',t):
                        if abs(int(m.group(1))-yy)<=1:c.add(f'{int(m.group(1)):04d}-{int(m.group(2)):02d}-{int(m.group(3)):02d}')
            if len(c)==1:d=c.pop();src='wikipedia+n05'
        out.append((i,j+1,d or f'{yy}-XX-XX',src))
        i=j+1
    return out

def jy(s):
    """위키 날짜. 달이나 해까지만 있어도 쓴다"""
    s=re.sub(r'\[\[|\]\]','',s or '')
    m=re.search(r'(\d{4})年(?:（[^）]*）)?(?:\s*(\d{1,2})月)?',s)
    if not m:return None
    return f'{m.group(1)}-{int(m.group(2)):02d}-XX' if m.group(2) else f'{m.group(1)}-XX-XX'
def infobox_open(rec):
    """노선 인포박스의 개업일"""
    m=re.search(r'\|\s*開業\s*=\s*(.+)',rec.get('wikitext') or '')
    if not m:return None
    t=re.search(r'\{\{\s*[Ss]tart date\s*\|\s*(\d{4})\s*\|\s*(\d{1,2})\s*\|\s*(\d{1,2})',m.group(1))
    if t:return f'{int(t.group(1)):04d}-{int(t.group(2)):02d}-{int(t.group(3)):02d}'
    return jd(m.group(1)) or jy(m.group(1))
def first_open(rec,names):
    """연혁의 가장 이른 개업 줄. 이 노선의 역 이름이나 「全線」이 있는 줄만. 날까지 없으면 달이나 해"""
    o=[]
    for line in (rec.get('wikitext') or '').split('\n'):
        if line.startswith('*') and re.search(r'開業|開通',line) and not re.search(r'申請|許可|認可|特許|免許|計画|(駅|停留場)(を)?(開業|開設)',line):
            x=re.sub(r'\[\[(?:[^\]|]*\|)?([^\]]*)\]\]',r'\1',line)
            if '全線' not in x and names!=[''] and not any(n and n in x for n in names):continue
            d=jd(x) or jy(x)
            if d:o.append(d)
    return min(o) if o else None
def naming(pick):
    """노선 이름과 사업자. N05의 폐지 직전 기록을 쓴다. 회사 이름 같은 노선은 「○○鉄道線」"""
    op=clean(pick[-1]['op']);line=clean(pick[-1]['line'])
    jr=op=='日本国有鉄道' or '旧国鉄' in op
    if jr:return re.sub(r'^.*本線','',line) or line,'日本国有鉄道',True
    if line in('本線','鉄道線',op):return (op if op.endswith('線') else op+'線'),op,False
    if re.search(r'(鉄道|電鉄|軌道|交通|鉱業|鉱山|汽船)$',line):return line+'線',op,False
    if line.startswith(op):line=line[len(op):] or line
    if line in('本線','線','鉄道線'):line=op+'線'
    return line,op,False
def tags(xs):
    """출처 태그 합치기. 이미 합친 태그(wikipedia+n05)도 나눠 한 번씩만 쓴다"""
    return '+'.join(sorted({t for x in xs if x for t in x.split('+')}))
def make(x,j,CO,seen):
    """판정을 통과한 역 목록으로 노리츠부시 표 모양의 행을 만든다. (보고, 행)"""
    r0=dict(title=j['title'],revid=j['revid'])
    rows,pick=j['rows'],j['pick']
    cov=[covered(a,ka,b,kb) for (a,ka,_),(b,kb,_) in zip(rows,rows[1:])]
    if all(cov):return dict(r0,result='in_db',why=f'이미 있음: {cov[0]}'),None
    # 앞뒤로 이미 있는 구간은 떼어 낸다. 가운데가 겹치면 손으로 나눠야 한다
    a_,b_=0,len(cov)
    while a_<b_ and cov[a_]:a_+=1
    while b_>a_ and cov[b_-1]:b_-=1
    if any(cov[a_:b_]):return dict(r0,result='archive',why=f'가운데 구간이 이미 있는 노선과 겹침: {[c for c in cov if c][0]}',order=[r[0] for r in rows]),None
    trimmed=bool(a_ or b_<len(cov))
    rows=rows[a_:b_+1];pick=pick[a_:b_+1]
    # 이미 있는 노선에 이어지는 구간은 그 표의 방향을 따른다. 끝 역에서 이어져야 한 계통이 된다
    if trimmed:
        jn=rows[0][0] if a_ else rows[-1][0]
        r_=next(r for r in N if r['t']==(cov[a_-1] if a_ else cov[b_]))
        ns_=[sn(q) for q,_ in r_['s']]
        if (ns_[0]==sn(jn))==(sn(rows[0][0])==sn(jn)):
            tot=rows[-1][1];rows=[(q,dround(tot-k),c) for q,k,c in reversed(rows)];pick=pick[::-1]
    hist=history(j['rec'])
    close=sections(rows,pick,hist,'ye',j['rec'].get('wikitext') or '')
    if all(d<CUT for _,_,d,_ in close):return dict(r0,result='archive',why='모든 구간이 기준일 전에 폐지',order=[r[0] for r in rows]),None
    # 기준일 전에 폐지된 앞뒤 구간은 뺀다
    while close and close[0][2]<CUT:k=close[0][1];rows=rows[k:];pick=pick[k:];close=[(a-k,b-k,d,s) for a,b,d,s in close[1:]]
    while close and close[-1][2]<CUT:k=close[-1][0];rows=rows[:k+1];pick=pick[:k+1];close=close[:-1]
    if any(d<CUT for _,_,d,_ in close):return dict(r0,result='archive',why='가운데 구간이 기준일 전에 폐지',order=[r[0] for r in rows]),None
    base=rows[0][1];rows=[(a,dround(k-base),c) for a,k,c in rows]
    # N05의 첫 해 1950은 '1950년 이전부터'다. 그 구간의 개업일은 위키 연혁이나 인포박스의 가장 이른 개업일
    first=sorted([d for d in [infobox_open(j['rec']),first_open(j['rec'],[a for a,_,_ in rows])] if d])
    # 역 이름이 없는 연혁 줄밖에 없으면 그 문서의 가장 이른 개업 줄 (노선 문서이므로 그 노선의 개업이다)
    if not first:first=sorted([h[0] for h in hist if h[1]=='open'] or [d for d in [first_open(j['rec'],[''])] if d])
    # 개업일은 N05에 처음 나온 해보다 늦을 수 없다 (1950년부터 있던 노선은 1951년까지)
    y0=max(min([q['yb'] for q in pick if q['yb']] or [1950]),1950)
    first=[d for d in first if int(d[:4])<=y0+1]
    # N05의 시작 해는 역 이름이 바뀌어도 새로 시작해 개업으로 보지 않는다. 위키 연혁에 같은 해·같은 구간의 개업이 있을 때만 쓴다
    opn=[]
    for a,b,d,s in sections(rows,pick,hist,'yb'):
        if s=='n05':opn.append((a,b,first[0],'wikipedia') if first else (a,b,None,None))
        else:opn.append((a,b,d,s))
    # 가운데 역이 이웃 역보다 먼저 N05에서 사라졌거나 늦게 나타났으면 그 해를 역 기간으로 쓴다. 해는 N05가 마지막으로 그 역을 그린 해의 다음 해
    # N05는 사업자·위치가 바뀌면 같은 역을 기록 여럿으로 나눈다. 같은 이름의 1km 안 기록을 합쳐 본다
    def span(i):
        q=[c for c in x['stations']+[pick[i]] if sn(c['name'])==sn(pick[i]['name']) and seglen(c['pt'],pick[i]['pt'])<1]
        return min(c['yb'] or 1950 for c in q),max(c['ye'] or 9999 for c in q)
    sp=[span(i) for i in range(len(rows))]
    sclose={};sopen={}
    for i in range(1,len(rows)-1):
        (yb,ye),(pb,pe),(nb_,ne)=sp[i],sp[i-1],sp[i+1]
        if ye<min(pe,ne) and ye<9999:sclose[rows[i][0]]=f'{ye+1}-XX-XX'
        if yb>max(pb,nb_,1950):sopen[rows[i][0]]=f'{yb}-XX-XX'
    lname,op,jr=naming(pick)
    if (op,lname) in seen:return dict(r0,result='in_db',why=f'같은 노선의 다른 N05 묶음: {op} {lname}'),None
    seen.add((op,lname))
    c='9' if jr else CO.get(HT['OPAL'].get(op,op)) or CO.get(op) or '9'+hashlib.md5(op.encode()).hexdigest()[:6]
    t=f'乗車区間の選択【{lname}】' if jr or lname.startswith(op) else f'乗車区間の選択【{op} {lname}】'
    sec=lambda a,b,d:[f'{rows[a][0]}～{rows[b][0]}',str(dround(rows[b][1]-rows[a][1])),d]
    h=[[['区間','営業km','開業日']]+[sec(a,b,d) for a,b,d,_ in opn if d],[['区間','営業km','廃止日']]+[sec(a,b,d) for a,b,d,_ in close]]
    rv=j['revid']
    row=dict(g='old',c=c,cn=op,id='n05'+hashlib.md5((op+lname).encode()).hexdigest()[:6],t=t,h=[x_ for x_ in h if len(x_)>1],
             s=[[('*' if a in sclose else '')+a,k] for a,k,_ in rows],revid=rv,jr=jr,sclose=sclose,sopen=sopen,
             src=dict(km=f'wikipedia:{rv}',stop='wikipedia+n05',line='n05',open=tags(s for *_,s in opn) or None,close=tags(s for *_,s in close),op='n05'),
             legal=[[rows[a][0],rows[b][0],d] for a,b,d,_ in close],
             n05pt={('*' if a in sclose else '')+a:[s_['pt'][1],s_['pt'][0]] for (a,_,_),s_ in zip(rows,pick)},
             kana={a:k for a,_,k in rows if k},arch=[m for m in j['miss'] if m[1] in {r_[0] for r_ in rows} and m[2] in {r_[0] for r_ in rows}],line_kana=lead_kana(j['rec'],lname) or ((lead_kana(j['rec'],lname[:-1]) or '')+'せん' if lname.endswith('線') and lead_kana(j['rec'],lname[:-1]) else None))
    return dict(r0,result='ok',why='ok',line=f'{op} {lname}',kind=j['kind'],stations=len(rows),extended=j['ext'],stop_close=sclose,stop_open=sopen,dropped=j['drop'],missing=[m[0] for m in j['miss']],km_bad=j['km_bad'],
                close=[d for *_,d,_ in close],close_src=row['src']['close'],open=[d for *_,d,_ in opn],trimmed=trimmed),row

def kana_of(f,o,names):
    """역 읽기: 손 대조 표, 자동 대조 행, 위키 역 목록 표 순서"""
    k={}
    rec=doc(f['title']) if f.get('title') else None
    if rec:
        for _,rows in variants(rec):
            for a,_,kn in rows:
                if kn:k.setdefault(sn(a),kn)
    # names는 집합이라 순서가 실행마다 다르다. 출력 파일이 늘 같도록 정렬한다
    out={a:k[sn(a)] for a in sorted(names) if sn(a) in k}
    out.update({a:v for a,v in (o.get('kana') or {}).items() if a in names})
    out.update({a:v for a,v in (f.get('kana') or {}).items() if a in names})
    return dict(sorted(out.items()))
def estimate_km(f,x):
    """営業キロ를 모르는 역(XX)의 km를 N05 선로 위 위치로 나눠 추정한다 (DESIGN §4.5 `? km`).
    앞뒤 km를 아는 역 사이 거리를 N05 선 위 거리 비율로 나눈다. N05 역 점이 없으면 그대로 둔다. 추정한 역은 f['km_est']에 더한다"""
    import n05_overlay as ov
    num=lambda k:isinstance(k,(int,float)) or bool(re.match(r'^[\d.]+$',str(k)))
    st=[list(s_) for s_ in f['stations']]
    if isinstance(st[0][0],list) or all(num(k) for _,k in st) or x is None:return st
    est=set(f.get('km_est') or [])
    # 위키 표기와 N05 점 이름이 다른 역 (n05_stop: 위키 이름 -> N05 이름)
    al=f.get('n05_stop') or {};sk=lambda a:sn(al.get(a,a))
    segs=[];pts={}
    for line,op in {tuple(n) for n in x['names']}:
        sg,sp=ov.load(line,op);segs+=sg
        for nm,pt in sp.items():pts.setdefault(sn(nm),pt)
    for i,(a,k) in enumerate(st if segs else []):
        if num(k) or sk(a) not in pts:continue
        lo=next((j for j in range(i-1,-1,-1) if num(st[j][1])),None);hi=next((j for j in range(i+1,len(st)) if num(st[j][1])),None)
        if lo is None or hi is None or sk(st[lo][0]) not in pts or sk(st[hi][0]) not in pts:continue
        d1=ov.along(segs,pts[sk(st[lo][0])],pts[sk(a)])[0];d2=ov.along(segs,pts[sk(a)],pts[sk(st[hi][0])])[0]
        if not d1 or not d2:continue
        k0,k1=float(st[lo][1]),float(st[hi][1])
        st[i][1]=dround(k0+(k1-k0)*d1/(d1+d2));est.add(a)
    # 좌표도 없으면 앞뒤 km를 아는 역 사이를 모르는 역 수로 고르게 나눈다. 이웃 역 km를 그대로 받으면 0 km 칸이 되고 좌표 보간도
    # 이웃 좌표를 복사한다 (추정 km 조사 2026-11-09: 若宮·浅間線 등 17역). 0.1 km로 가를 수 없을 만큼 좁거나 끝 역이면 이웃 자리에 둔다
    for i,(a,k) in enumerate(st):
        if num(k) or a.startswith('['):continue
        hi=next((j for j in range(i+1,len(st)) if num(st[j][1])),None);lo=next((j for j in range(i-1,-1,-1) if num(st[j][1])),None)
        if hi is None and lo is None:continue
        if hi is not None and lo is not None:
            run=[j for j in range(lo+1,hi) if not st[j][0].startswith('[')];k0,k1=float(st[lo][1]),float(st[hi][1])
            v=dround(k0+(k1-k0)*(run.index(i)+1)/(len(run)+1))
            if k0<v<k1:st[i][1]=v;est.add(a);continue
        st[i][1]=float(st[hi if hi is not None else lo][1]);est.add(a)
    f['km_est']=sorted(est)
    return st
_FIXK=None
def _parent_key(key):
    """손 대조 표에서 이 항목을 「부모 항목 + 공백 + 부제」로 품는 가장 긴 다른 항목(넣는 항목만). 없으면 None"""
    global _FIXK
    if _FIXK is None:
        _F=json.load(open(FIXF,encoding='utf-8'))['lines'] if os.path.exists(FIXF) else {}
        _FIXK={k for k,v in _F.items() if v.get('verdict','skip' if v.get('kind')=='skip' else 'ok')=='ok' and not v.get('join_at')}
    ps=[k for k in _FIXK if key.startswith(k+' ') and k!=key]
    return max(ps,key=len) if ps else None
def fixrow(key,f,x,old,CO):
    """손 대조 표 한 항목으로 노리츠부시 표 모양의 행을 만든다. km를 모르는 역은 estimate_km이 추정한다"""
    op,lname=key.split(' ',1)
    num=lambda k:isinstance(k,(int,float)) or bool(re.match(r'^[\d.]+$',str(k)))
    st=estimate_km(f,x)
    al=f.get('n05_stop') or {};sk=lambda a:sn(al.get(a,a))
    known=[(a,float(k)) for a,k in st if num(k)]
    if len(known)<2:raise SystemExit(f'n05_fix {key}: km를 아는 역이 둘 미만')
    base=known[0][1];kmof={a:dround(k-base) for a,k in known}
    order=[a for a,_ in st]
    def snap(a):
        """km를 모르는 구간 끝은 앞쪽의 km를 아는 역으로 붙인다"""
        if a in kmof:return a
        if a not in order:raise SystemExit(f'n05_fix {key}: 구간 끝 {a}가 stations에 없음')
        i=order.index(a)
        return next((b for b in reversed(order[:i]) if b in kmof),None) or next(b for b in order[i:] if b in kmof)
    arch=[]
    for i,(a,k) in enumerate(st):
        if num(k):continue
        lo=next((b for b in reversed(order[:i]) if b in kmof),None);hi=next((b for b in order[i+1:] if b in kmof),None)
        if lo and hi:arch.append([a,lo,hi])
        else:print('n05_fix 끝 역의 km를 몰라 뺌',key,a)
    # 역 점: N05 묶음의 같은 이름 역, 없으면 다른 노선의 N05 역 중 앞 역에서 가까운 것
    # N05 묶음이 없는 구간(N05가 그리지 않은 국철 여객 지선, 小野田線 西沖山–助田–居能)은 역 점 없이 둔다. 선형 없이 표식만 그린다 (DESIGN §7.3)
    xst=(x or {}).get('stations') or []
    pt={};prev=None
    for a,_ in known:
        cs=[q for q in xst if sn(q['name'])==sk(a)] or [q for q in ALLST.get(sk(a),()) if prev is None or seglen(q['pt'],prev)<30]
        if cs:
            q=min(cs,key=lambda q:seglen(prev,q['pt']) if prev else 0);pt[a]=q['pt'];prev=q['pt']
    # 폐지일을 모르는 폐역은 N05가 마지막으로 그린 해의 다음 해
    def n05end(a):
        # N05는 모르는 끝 해를 999로 적는다. 묶음에 없으면(노선 이름이 N05와 다른 손 대조 노선) 같은 이름의 N05 역 중 이 노선 역 점 가까이(3km) 있는 것
        qs=[q for q in xst if sn(q['name'])==sk(a)]
        if not qs:
            near=[pt[b] for b in pt]
            qs=[q for q in ALLST.get(sk(a),()) if any(seglen(q['pt'],p_)<3 for p_ in near)]
        ye=max([q['ye'] for q in qs if q['ye'] and 1800<q['ye']<9999] or [0])
        if not ye:
            # N05가 그 역을 그렸지만 끝 해를 모르면(999) 그린 첫 해 뒤 어느 날, 노선이 닫히기 전에 없어졌다 (2회차 종합 K18: 阪神北大阪線 上浦江, 西鉄 天籟寺·西門通).
            # 하한을 개업일로 두면 1950년 탑승이 「모름」이 된다. 시작 해 999는 「1949년 이전」이라 기준일(1950)로 본다
            yb=[max(1950,q['yb'] if q['yb'] and 1800<q['yb']<9999 else 1950) for q in qs if q['ye']==999]
            if yb:
                try:hi=max(lohi(c[0])[1] for x_,y_,*c in f['close'] if c and c[0])
                except ValueError:hi=None
                if not hi or hi>=f'{max(yb)}-01-01':return f"[{max(yb)}-01-01..{hi or ''}]"
            print('n05_fix 폐지일을 모르는 역이 N05에도 없음',key,a);return None
        return f'{ye+1}-XX-XX'
    shut={a:(d if d and not d.startswith('XXXX') else n05end(a)) for a,d in (f.get('stop_close') or {}).items()}
    # 옮겨 간 역의 옛 자리(【旧】)는 그 역을 지나는 구간이 닫힐 때 함께 없어진다
    for a,_ in st:
        if '【旧】' in a and not shut.get(a):
            i=order.index(a)
            ds=[c[0] for x_,y_,*c in f['close'] if x_ in order and y_ in order and min(order.index(x_),order.index(y_))<=i<=max(order.index(x_),order.index(y_))]
            # 닿는 구간이 모두 닫혀야 역도 없어진다
            if ds:shut[a]=max(ds)
    lab=lambda a:('*' if a in shut else '')+a
    def sec(a,b,d):
        a,b=snap(a),snap(b)
        return [f'{a}～{b}',str(dround(abs(kmof[b]-kmof[a]))),d]
    rv=f.get('revid')
    o=old or {}
    jr=o.get('jr',op=='日本国有鉄道')
    # 같은 노선의 한 토막·지선·옛 선로 항목(「仙台市交通局 循環線 花京院–仙台駅前」, 「上田交通 真田傍陽線 傍陽支線」)은 부모 항목(「仙台市交通局 循環線」)과 같은 노선이다.
    # 제목을 「부모 노선 (부제)」 꼴로 내서 생성기가 같은 노선의 다른 계통으로 싣게 한다. 노선 수·완주 단위가 둘로 갈리지 않게 (DESIGN §2.7, 3회차 전수 점검 K30·kyushu_1-008·tohoku_1-005·tohoku_1-006·kyushu_1-009, 8회차 W1b)
    pk_=_parent_key(key)
    tl_=lname if pk_ is None else pk_.split(' ',1)[1]+' ('+key[len(pk_)+1:]+')'
    t=o.get('t') or (f'乗車区間の選択【{tl_}】' if jr or tl_.startswith(op) else f'乗車区間の選択【{op} {tl_}】')
    row=dict(g='old',c=o.get('c') or ('9' if jr else CO.get(HT['OPAL'].get(op,op)) or CO.get(op) or '9'+hashlib.md5(op.encode()).hexdigest()[:6]),cn=o.get('cn',op),
             id=o.get('id') or 'n05'+hashlib.md5((op+lname).encode()).hexdigest()[:6],t=t,
             h=[x_ for x_ in ([['区間','営業km','開業日']]+[sec(a,b,d) for a,b,d in f['open']],[['区間','営業km','廃止日']]+[sec(a,b,c[0]) for a,b,*c in f['close']]) if len(x_)>1],
             s=[[lab(a),kmof[a]] for a,_ in known],revid=rv,jr=jr,subsec=pk_ is not None and not o.get('t'),
             src=dict(km=f'wikipedia:{rv}',stop='wikipedia+n05',line='n05',open='wikipedia',close='wikipedia',op='n05'),
             legal=[[snap(a),snap(b),(c[1] if len(c)>1 and c[1] else c[0])] for a,b,*c in f['close']],
             svc=[[snap(a),snap(b),d] for a,b,d in f.get('service_end') or []],
             susp=[[snap(a),snap(b),d0,'wikipedia',d1] for a,b,d0,d1 in f.get('suspend') or []],
             sclose={a:d for a,d in shut.items() if a in kmof},sopen={a:d for a,d in (f.get('stop_open') or {}).items() if a in kmof},sdate_src='wikipedia',
             n05pt={lab(a):[pt[a][1],pt[a][0]] for a,_ in known if a in pt},
             km_est=[a for a in f.get('km_est') or [] if a in kmof],
             kana=kana_of(f,o,set(kmof)|{a for a,_,_ in arch}),arch=arch,line_kana=f.get('line_kana') or o.get('line_kana') or (lead_kana(doc(f['title']) or {},lname) if f.get('title') else None))
    return row
def group_of(G,f):
    """손 대조 항목의 N05 묶음. 이름 목록이 같은 묶음, 없으면 [노선, 사업자]가 하나라도 겹치는 묶음"""
    want=[list(n) for n in f.get('n05_names') or []]
    if not want:return None
    return next((x for x in G if x['names']==want),None) or next((x for x in G if any(n in x['names'] for n in want)),None)
def apply_fix(G,GROUP,out,rep,CO):
    """손 대조 표를 자동 대조 결과 위에 얹는다. 표에 없는 노선은 자동 결과를 그대로 둔다"""
    if not os.path.exists(FIXF):return out,rep
    FIX=json.load(open(FIXF,encoding='utf-8'))['lines']
    # 2차 대조의 kind: line·join은 넣는 항목, skip은 넣지 않는 항목(판정 근거로만 남김)
    for f in FIX.values():f.setdefault('verdict','skip' if f.get('kind')=='skip' else 'ok')
    byrow={id(row):k for k,(x,row) in GROUP.items()}
    keep=[]
    for row in out:
        k=byrow.get(id(row))
        f=FIX.get(k)
        if f is None:keep.append(row);continue
        if f['verdict']=='ok':keep.append(fixrow(k,f,GROUP[k][0],row,CO))
    # 이음(join) 항목은 뒤에 본다. host 표가 이 표의 다른 손 대조 노선(N05로만 들어온 노선)일 수 있다. 나온 행 순서는 표 순서 그대로 둔다(edge 번호)
    res_=collections.defaultdict(list);head_=list(keep)
    for k,f in sorted(FIX.items(),key=lambda kv:bool(kv[1].get('join_at'))):
        if k in GROUP or f['verdict']!='ok':continue
        keep=res_[k]
        if f.get('join_at'):
            # 이미 있는 노선의 빠진 구간이나 옛 선로. 그 노선의 표와 같은 회사·노선 이름으로 행을 만들어 이음 역에서 한 계통으로 잇는다
            # join_at은 이음 역 이름들이다. 옛 선로는 양 끝이 이음 역이다
            joins=set(f['join_at'] if isinstance(f['join_at'],list) else [f['join_at']])
            segs=f['stations'] if isinstance(f['stations'][0][0],list) else [f['stations']]
            x=group_of(G,f)
            for i,st_ in enumerate(segs):
                names_={a for a,_ in st_};jn=names_&joins
                jn_={a.strip('[]') for a in jn}
                if not jn:raise SystemExit(f'n05_fix {k}: 토막 {i}에 이음 역이 없음')
                # 이음 역이 모두 있는 기존 표. 노선 이름이 맞는 표, 없으면 같은 회사의 표 (국철 노선은 뒤에 3섹·JR로 넘어가 회사 이름이 다르다)
                line_=k.split(' ')[1]
                # 다른 노선과 만나는 끝(三河線 吉良吉田는 西尾線 역)도 있어, 이음 역 하나라도 있는 표를 본다
                # 기존 표는 노리츠부시·old_lines 표, 거기 없으면 이 대조가 만든 N05 표(柳生橋支線·美濃町線처럼 N05로만 들어온 노선)다
                n05rows_=[r_ for r_ in head_+[q_ for v_ in res_.values() for q_ in v_] if not r_.get('join')]
                host=None
                for pool_ in (N,n05rows_):
                    cands=sorted((r_ for r_ in pool_ if jn_&{q_.strip('*[]') for q_,_ in r_['s']}),key=lambda r_:-len(jn_&{q_.strip('*[]') for q_,_ in r_['s']}))
                    host=next((r_ for r_ in cands if line_ in r_['t']),None) or next((r_ for r_ in cands if r_.get('cn')==k.split(' ',1)[0]),None)
                    if host:break
                # 이음 역이 옛 이름으로만 적힌 표(国鉄 会津線의 上三寄·湯野上)는 이름으로 못 찾는다. host에 그 표 제목을 적는다 (DB 감사 DBA-004)
                if f.get('host'):
                    host=next((r_ for r_ in N+n05rows_ if r_['t'].startswith(f['host'])),None)
                    if host is None:raise SystemExit(f'n05_fix {k}: host 표 {f["host"]}가 없음')
                if host is None:raise SystemExit(f'n05_fix {k}: 이음 역 {sorted(jn)}가 있는 기존 표가 없음')
                part=dict(f,stations=st_,open=[o_ for o_ in f['open'] if {o_[0],o_[1]}<=names_],close=[c_ for c_ in f['close'] if {c_[0],c_[1]}<=names_],
                          service_end=[c_ for c_ in f.get('service_end') or [] if {c_[0],c_[1]}<=names_],suspend=[c_ for c_ in f.get('suspend') or [] if {c_[0],c_[1]}<=names_])
                row=fixrow(k,part,x,dict(c=host['c'],cn=host.get('cn'),jr=bool(host.get('jr')) or host['g'] in('jr','jrx') or str(host['c'])=='9',t=host['t'],id='n05'+hashlib.md5(f'{k}|{i}'.encode()).hexdigest()[:6]),CO)
                # 이음 역은 기존 표의 역과 같은 방법으로 역 자료에 붙도록 N05 점을 주지 않는다
                for j_ in jn:row['n05pt'].pop(j_,None)
                row['join']=True
                # branch: 이음 역 사이를 본선 선로와 같이 쓰는 옛 경로(新潟, 長尾線). 이 칸은 본선 edge를 쓴다
                if f.get('branch'):row['shared']=True
                # 양 끝이 이음 역인 옛 선로는 같은 노선의 지선 계통으로 둔다 (東海道本線 (美濃赤坂線)처럼 제목에 괄호 부제).
                # 본선 계통의 대체 경로로 붙이면 정차 순서와 km 누계가 본선 기준과 섞인다
                if len(jn)>=2 or f.get('branch'):
                    m_=re.search(r'【(?:.* )?(.+?)(?: \((.+?)\))?】',host['t'])
                    base_=m_.group(1) if m_ else re.match(r'^(.+?)(?: \(.+?\))? \S',host['t']).group(1)
                    a_,b_=st_[0][0],st_[-1][0]
                    tag_='旧線' if '이설' in (f.get('note') or '') else ''
                    row['t']=f"{base_} ({a_}・{b_}{tag_}) {a_} ～ {b_} 営業km: {row['s'][-1][1]}"
                keep.append(row)
            continue
        # 자동 대조가 놓친 노선. 손 대조 표의 N05 묶음 이름으로 역 점을 찾는다. 지선은 본선의 묶음, 없으면 노선 이름이 든 묶음
        op_,ln_=k.split(' ',1)
        x=group_of(G,f) or next((GROUP[p_][0] for p_ in GROUP if k.startswith(p_+' ')),None) or next((x for x in G if any(ln_==l or ln_.endswith(l) for l,_ in x['names']) and any(op_ in o for _,o in x['names'])),None)
        if x is None:raise SystemExit(f'n05_fix {k}: N05 묶음 {f.get("n05_names")}가 없음')
        keep.append(fixrow(k,f,x,None,CO))
    keep=head_+[r_ for k in FIX for r_ in res_.get(k,[])]
    def arch(k,f):
        """열람 전용으로 내린 노선. gen_extra가 이름과 역 순서로 열람 전용 노선을 만든다"""
        st=f.get('stations') or []
        return dict(result='archive',why=f['why'],hand=True,name=k.split(' ',1)[1],revid=f.get('revid'),
                    order=[a for a,_ in st] if st and not isinstance(st[0][0],list) else None)
    for r in rep:
        f=FIX.get(r.get('line'))
        if f:r.update(dict(result='ok',why='손 대조 (n05_fix)',hand=True) if f['verdict']=='ok' else arch(r['line'],f))
    have={r.get('line') for r in rep}
    for k,f in FIX.items():
        if k in have or f['verdict'] not in ('ok','archive'):continue
        x=group_of(G,f)
        base=dict(names=f.get('n05_names'),line=k,closed_year=x['closed_year'] if x else None)
        rep.append(dict(base,result='ok',why='손 대조로 찾음 (n05_fix)',hand=True) if f['verdict']=='ok' else dict(base,**arch(k,f)))
    # 선형 찾기(gen_geometry)는 노선 이름으로 N05 선을 고른다. 이름이 N05와 다른 노선을 위해 묶음의 N05 노선 이름을 별칭으로 남긴다
    alias=collections.defaultdict(set)
    for k,f in FIX.items():
        if f['verdict']!='ok':continue
        x=GROUP.get(k,(None,))[0] or group_of(G,f) or next((GROUP[p_][0] for p_ in GROUP if k.startswith(p_+' ')),None)
        if x:alias[k.split(' ',1)[1]]|={l for l,_ in x['names']}
    json.dump({k:sorted(v) for k,v in sorted(alias.items())},open(os.path.join(CAND,'n05_alias.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=0)
    return keep,rep

if __name__=='__main__':
    os.makedirs(os.path.dirname(OUT),exist_ok=True);os.makedirs(CAND,exist_ok=True)
    if not source_on('n05'):
        json.dump([],open(OUT,'w',encoding='utf-8'));json.dump(dict(off=True,report=[]),open(REP,'w',encoding='utf-8'))
        print('N05가 꺼져 있습니다');sys.exit(0)
    G=groups()
    CO={r.get('cn'):str(r['c']) for r in N if r.get('cn') and r['g'] in('pr','old')}
    rep=[];out=[];seen=set();GROUP={}
    for x in G:
        r0=dict(names=x['names'],closed_year=x['closed_year'],n05_stations=len(x['stations']))
        if x['cls']!='line':rep.append(dict(r0,result=x['cls'],why={'tram':'옛 노면전차망 (다음 단계, §4.4)','current':'현행 노선의 일부'}[x['cls']]));continue
        sc=scope(x)
        if sc:rep.append(dict(r0,result='out',why=sc));continue
        # 노리츠부시 표나 옛 폐선 표 하나에 N05 역 이름의 60% 이상(셋 이상)이 있으면 이미 있는 노선이다
        S={sn(s_['name']) for s_ in x['stations']}
        # 동점이면 먼저 센 표가 이긴다. 집합 순서가 해시에 따라 바뀌지 않게 정렬해서 센다
        hit=collections.Counter(rid for n_ in sorted(S) for rid in sorted({p_[2] for p_ in POS.get(n_,())}))
        if hit and S:
            t_,c_=hit.most_common(1)[0]
            if c_>=3 and c_>=.6*len(S):rep.append(dict(r0,result='in_db',why=f'이미 있음: {t_}'));continue
        # 한 묶음에 노선이 여럿일 수 있다 (회사 노선망). 넣은 노선의 가운데 역을 빼고 다시 판정한다
        used=set();res=[]
        for _ in range(8):
            j,why=judge(x,used)
            if why!='ok':
                if not res or len([s_ for s_ in x['stations'] if id(s_) not in used])>=3:
                    # 순서를 아는 것(위키 역 목록이 있음)은 열람 전용, 순서도 모르는 것은 보류 (§4.1)
                    nm_=naming([dict(op=x['names'][-1][1],line=x['names'][-1][0])])
                    res.append(dict(result='archive' if j and j.get('order') else 'hold',why=why,name=nm_[0] if nm_[2] else (nm_[0] if nm_[0].startswith(nm_[1]) else nm_[1]+nm_[0]),**({k:j[k] for k in ('title','revid','order')} if j else {})))
                break
            r,row=make(x,j,CO,seen)
            if r['why'].startswith('같은 노선의 다른'):break
            res.append(r)
            if row:out.append(row);GROUP[r['line']]=(x,row)
            # 끝 역은 다른 노선과 만나는 역일 수 있어 남긴다
            used|={id(q) for q in j['pick'][1:-1]}|{id(q) for q in x['stations'] if sn(q['name']) in {sn(a) for a,_,_ in j['rows'][1:-1]}}
            if len([s_ for s_ in x['stations'] if id(s_) not in used])<3:break
        for r in res:rep.append(dict(r0,**r))
        # 판정되지 않고 남은 N05 역
        left=sorted({q['name'] for q in x['stations'] if id(q) not in used} - {a for r in res for a in (r.get('order') or [])})
        if res and res[0]['result']!='archive' and len(left)>=3:rep[-1]['left']=left
    out,rep=apply_fix(G,GROUP,out,rep,CO)
    json.dump(out,open(OUT,'w',encoding='utf-8'),ensure_ascii=False)
    json.dump(dict(report=rep),open(REP,'w',encoding='utf-8'),ensure_ascii=False,indent=0)
    c=collections.Counter(r['result'] for r in rep)
    why=collections.Counter(re.sub(r'\s*\(.*$|:.*$','',r['why'])[:24] for r in rep if r['result'] in('archive','hold'))
    print('N05 판정',dict(c),'행',len(out),'열람 전용 이유',why.most_common(10))
