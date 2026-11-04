# -*- coding: utf-8 -*-
# 노리츠부시에 없는 옛 폐선(주로 사철 1969-12-08 이후)을 station_database·위키 노선도로 만든다
# 결과: data/imports/stationdb/old_lines.json (노리츠부시 표와 같은 모양에 값별 출처 src를 더함), data/candidates/old_report.json
import sys,os,re,json,csv,gzip,hashlib,collections
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from lib import *
import wparse as w
os.environ['NW_OFF']='1'
import conn
# station_database로 자동으로 만드는 범위. 1950~1969 폐선은 N05와 교차 검증하는 tools/gen_n05.py로만 넣는다 (DESIGN §2.12, §4.6)
CUT='1969-12-08'
DB=os.path.join(IMP,'stationdb')
SD={s['code']:s for s in csv.DictReader(open(DB+'/station.csv',encoding='utf-8'))}
SL=list(csv.DictReader(open(DB+'/line.csv',encoding='utf-8')))
REG=collections.defaultdict(list)
for r in csv.DictReader(open(DB+'/register.csv',encoding='utf-8')):REG[r['line_code']].append(r)
N=json.load(open(os.path.join(IMP,'noritsubushi','lines.json'),encoding='utf-8'))
Nnames=collections.Counter()
Nline=set()
for r in N:
    m=re.match(r'^(.+?)(?: \(.+?\))? \S.*? ～ ',r['t']) or re.search(r'【(?:.* )?(.+?)(?: \(.+?\))?】',r['t'])
    if m:Nline.add(znorm(m.group(1)));Nline.add(znorm((r.get('cn') or '')+m.group(1)))
for r in N:
    for s,_ in r['s']:Nnames[znorm(s.strip('*[]'))]+=1
d=os.path.join(IMP,'wiki')
def doc(t):
    f=os.path.join(d,hashlib.md5(t.encode()).hexdigest()[:14]+'.json.gz')
    if not os.path.exists(f):return None
    return json.load(gzip.open(f,'rt',encoding='utf-8'))
ST=re.compile(r'([^\s／：・（(]+?)(?:駅|停留場|停車場|仮乗降場|乗降場)')
ICON=re.compile(r'(BHF|HST|BST)')
def rows_of(rec):
    if not rec or not rec.get('html'):return []
    rows,_=w.extract(None,8,w.parse_text(rec['html']))
    fl=[]
    for r in rows:
        if isinstance(r,(list,tuple)) and len(r)==2 and isinstance(r[1],list):fl+=[x for x in r[1] if 'h' not in x]
        elif isinstance(r,dict) and 'h' not in r:fl.append(r)
    o=[]
    for r in fl:
        ic=[x for c in r['c'] for x in c]
        m=ST.search(r['t'])
        if m and any(ICON.search(x) for x in ic):
            k=r['k'] if re.match(r'^[\d.]+$',r['k'] or '') else None
            o.append((m.group(1),float(k) if k else None))
    return o
def table_km(rec):
    """駅一覧 표에서 역 이름과 누계 km를 읽는다"""
    if not rec or not rec.get('html'):return []
    root=w.parse_text(rec['html']);best=[]
    for t in w.walk(root):
        if t.t!='table' or 'wikitable' not in (t.a.get('class') or ''):continue
        rows=[q for q in w.walk(t) if q.t=='tr']
        if len(rows)<3:continue
        head=[re.sub(r'\s+','',w.text(c)) for c in rows[0].c if isinstance(c,w.N) and c.t in('th','td')]
        ni=next((i for i,h in enumerate(head) if '駅名' in h or h=='駅'),None)
        ki=next((i for i,h in enumerate(head) if '累計' in h or '営業キロ' in h or 'キロ程' in h or '起点' in h),None)
        ki2=[i for i,h in enumerate(head) if '累計' in h]
        if ni is None or ki is None:continue
        if ki2:ki=ki2[0]
        between='駅間' in head[ki] and not ki2
        o=[]
        for r in rows[1:]:
            c=[x for x in r.c if isinstance(x,w.N) and x.t in('th','td')]
            if len(c)<=max(ni,ki):continue
            nm=re.sub(r'\s+','',w.text(c[ni]));km=re.sub(r'[^\d.]','',w.text(c[ki]))
            nm=re.sub(r'(駅|停留場)$','',re.sub(r'[（(].*$','',nm))
            if nm and re.match(r'^\d+(\.\d+)?$',km):o.append((nm,float(km)))
        if between and o:
            run=0.0;c2=[]
            for a,b in o:
                run=round(run+b,1);c2.append((a,run))
            o=c2
        if len(o)>len(best):best=o
    return best
def info(rec):
    t=rec.get('wikitext') or ''
    g={}
    for k,rx in (('op',r'\|\s*(?:運営者|所有者|事業者)\s*=\s*(.+)'),('open',r'\|\s*開業\s*=\s*(.+)'),('close',r'\|\s*廃止\s*=\s*(.+)')):
        m=re.search(rx,t)
        if m:g[k]=re.sub(r'\[\[(?:[^\]|]*\|)?([^\]]*)\]\]',r'\1',m.group(1)).strip()
    return g
def jd(s):
    m=re.search(r'(\d{4})年(?:(\d{1,2})月(?:(\d{1,2})日)?)?',s or '')
    if not m:
        m2=re.search(r'\{\{\s*(?:start date|Start date)[^|]*\|\s*(\d{4})\|(\d+)\|(\d+)',s or '')
        return f'{int(m2.group(1)):04d}-{int(m2.group(2)):02d}-{int(m2.group(3)):02d}' if m2 else None
    y,mo,da=m.groups()
    if not mo:return f'{y}-XX-XX'
    if not da:return f'{y}-{int(mo):02d}-XX'
    return f'{y}-{int(mo):02d}-{int(da):02d}'
def src_of(rec,i,co,stop):
    """값별 출처. km는 위키 문서 판, 노선 이름과 폐지일은 station_database, 개업일은 위키 인포박스다"""
    rv=(rec or {}).get('revid')
    return dict(km=f'wikipedia:{rv}' if rv else 'wikipedia',stop=stop,line='station_database',open='wikipedia',close='station_database',op='wikipedia' if co in (i.get('op') or '') else 'station_database')
TRAMRX=re.compile(r'市電|市内線|路面|軌道線|電気軌道|電車線|トロリー|都電|馬車|人車')
out=[];rep=collections.Counter();arch=[]
# 표본 대조로 확인한 폐지일. 인포박스 날짜는 다른 사건일 때가 있어 2006년 이후 값은 버린다
ARCH_CLOSE=HT['ARCH_CLOSE']
known={}
for r in N:
    if r.get('cn') and r['g'] in('pr','tm') and str(r['c'])!='9':known[r['cn']]=str(r['c'])
ALIAS=HT['ALIAS']
def owner(t,op):
    for a,b in ALIAS.items():
        if t.startswith(a) and b in known:return b,known[b],t[len(a):]
    best=None
    for k in known:
        if t.startswith(k) and (not best or len(k)>len(best)):best=k
    if best and len(t)>len(best):return best,known[best],t[len(best):]
    for k in known:
        if op and op==k:return k,known[k],t
    m=re.match(r'^(.+?(?:電気鉄道|鉄道|電鉄|交通))(.+線)$',t)
    if m:
        co=m.group(1);return co,known.get(co) or '9'+hashlib.md5(co.encode()).hexdigest()[:6],m.group(2)
    if t=='横荘線' or t.startswith('雄勝線'):co='羽後交通'
    else:co=re.sub(r'[（(→].*$','',op or '').strip() or re.sub(r'線$','',t)
    return co,'9'+hashlib.md5(co.encode()).hexdigest()[:6],t
titles=[]
for l in SL:
    if l['closed']!='1':continue
    cd=l['closed_date']
    if cd=='NULL' or cd<CUT:continue
    t=re.sub(r'^JR','',re.sub(r'[（(].*?[)）]','',l['name']).strip())
    st=[SD[r['station_code']] for r in sorted(REG[l['code']],key=lambda r:int(r['index'])) if r['station_code'] in SD]
    names=[znorm(s['name']) for s in st]
    cov=sum(1 for n in names if n in Nnames)/max(len(names),1)
    if cov>=.6:rep['covered_by_n']+=1;continue
    if TRAMRX.search(l['name']) and cd<'2000-01-01':rep['tram']+=1;continue
    if znorm(t) in Nline:rep['in_n_line']+=1;continue
    rec=doc(t)
    if rec and rec.get('title') and znorm(rec['title'])!=znorm(t) and not znorm(t) in znorm(rec['title']):rec=None;rep['redirect']+=1
    rows=rows_of(rec)
    km={znorm(a):b for a,b in rows if b is not None}
    for a,b in table_km(rec):km.setdefault(znorm(a),b)
    seq=[];miss=0
    for s in st:
        k=km.get(znorm(s['name']))
        if k is None:miss+=1
        seq.append([s['name'],k])
    if len(seq)<2:rep['too_short']+=1;continue
    if miss==0 and all(a[1]!=b[1] for a,b in zip(seq,seq[1:])):
        base=seq[0][1]
        s2=[[n,round(abs(k-base),1)] for n,k in seq]
        if all(a[1]<b[1] for a,b in zip(s2,s2[1:])):
            i=info(rec or {})
            co,c,t=owner(t,i.get('op',''))
            oh=[['区間','営業km','開業日'],[f"{seq[0][0]}～{seq[-1][0]}",str(s2[-1][1]),jd(i.get('open')) or '']]
            ch=[['区間','営業km','廃止日'],[f"{seq[0][0]}～{seq[-1][0]}",str(s2[-1][1]),cd]]
            sr=src_of(rec,i,co,'station_database')
            if l['company_code']=='0':out.append(dict(g='tm',c='9',cn='旧国鉄・JR各社',id='old'+l['code'],t=f'乗車区間の選択【{t}】',h=[oh,ch],s=s2,sd=l['name'],revid=(rec or {}).get('revid'),src=sr))
            else:out.append(dict(g='old',c=c,cn=co,id='old'+l['code'],t=f'乗車区間の選択【{t}】',h=[oh,ch],s=s2,sd=l['name'],revid=(rec or {}).get('revid'),src=sr))
            rep['recordable']+=1;continue
    # 역 자료와 이름이 다르면 위키의 역 목록을 그대로 쓴다
    wr=[(a,b) for a,b in rows if b is not None]
    if len(wr)<len(seq)-1 or not all(x[1]<y[1] for x,y in zip(wr,wr[1:])):wr=table_km(rec)
    if len(wr)>=max(2,len(seq)-2) and all(x[1]<y[1] for x,y in zip(wr,wr[1:])):
        i=info(rec or {});co,c,t2=owner(t,i.get('op',''))
        base=wr[0][1];s2=[[a,round(b-base,1)] for a,b in wr]
        oh=[['区間','営業km','開業日'],[f"{wr[0][0]}～{wr[-1][0]}",str(s2[-1][1]),jd(i.get('open')) or '']]
        ch=[['区間','営業km','廃止日'],[f"{wr[0][0]}～{wr[-1][0]}",str(s2[-1][1]),cd]]
        g_,c_,cn_=('tm','9','旧国鉄・JR各社') if l['company_code']=='0' else ('old',c,co)
        out.append(dict(g=g_,c=c_,cn=cn_,id='old'+l['code'],t=f'乗車区間の選択【{t2}】',h=[oh,ch],s=s2,sd=l['name'],revid=(rec or {}).get('revid'),src=src_of(rec,i,co,'wikipedia')))
        rep['recordable_wiki']+=1;continue
    arch.append(dict(name=t,closed=cd,stations=[x[0] for x in seq],km_missing=miss,revid=(rec or {}).get('revid')))
    rep['archive_line']+=1
# 폐선 일람에서 온 문서
olds=json.load(open(os.path.join(IMP,'wiki','old_titles.json'),encoding='utf-8'))
seen=set(x['t'] for x in out)|{a['name'] for a in arch}
for t in olds:
    rec=doc(t)
    if not rec or not rec.get('html') or t in seen:rep['old_no_doc']+=1;continue
    i=info(rec)
    if rec.get('title') and znorm(rec['title'])!=znorm(t) and not znorm(t) in znorm(rec['title']):rep['redirect']+=1;continue
    cd=jd(i.get('close'))
    if cd and cd[:4]>='2006':cd=None
    cd=ARCH_CLOSE.get(t,cd)
    tt=rec.get('title') or t
    if TRAMRX.search(tt):rep['old_tram']+=1;continue
    rows=[(a,b) for a,b in rows_of(rec) if b is not None] or table_km(rec)
    if rows and sum(1 for a,b in rows if znorm(a) in Nnames)/len(rows)>=.6:rep['old_in_n']+=1;continue
    if False:
        base=rows[0][1];s2=[[a,round(abs(b-base),1)] for a,b in rows]
        if all(x[1]<y[1] for x,y in zip(s2,s2[1:])) and not any(x[0] in Nnames and False for x in s2):
            co,c,t2=owner(t,i.get('op',''))
            oh=[['区間','営業km','開業日'],[f"{rows[0][0]}～{rows[-1][0]}",str(s2[-1][1]),jd(i.get('open')) or '']]
            ch=[['区間','営業km','廃止日'],[f"{rows[0][0]}～{rows[-1][0]}",str(s2[-1][1]),cd]]
            out.append(dict(g='old',c=c,cn=co,id='oldw'+hashlib.md5(t.encode()).hexdigest()[:8],t=f'乗車区間の選択【{t2}】',h=[oh,ch],s=s2,sd=None,revid=rec.get('revid')))
            rep['old_recordable']+=1;continue
    arch.append(dict(name=t,closed=cd,stations=[a for a,b in rows_of(rec)],km_missing=0,revid=rec.get('revid')))
    rep['old_archive']+=1
# 손으로 확인한 노선과 부분 폐지
HAND=json.load(open(os.path.join(ROOT,'data','overrides','old_hand.json'),encoding='utf-8'))
for h in HAND:
    a,b=h['s'][0],h['s'][-1];km=str(b[1])
    out.append(dict(g=h['g'],c=h['c'],cn=h['cn'],id='oldh'+hashlib.md5(h['name'].encode()).hexdigest()[:8],t=f"乗車区間の選択【{h['name']}】",h=[[['区間','営業km','開業日'],[f'{a[0]}～{b[0]}',km,h.get('open','')]],[['区間','営業km','廃止日'],[f'{a[0]}～{b[0]}',km,h['close']]]],s=h['s'],sd=None,revid=None,src=dict.fromkeys(('km','stop','line','open','close','op'),'wikipedia')))
hn={h['cn'][:2]+h['name'] for h in HAND}
arch=[a for a in arch if not any(k in a['name'] for k in('京福電鉄永平寺線','京福電気鉄道永平寺線','名鉄田神線'))]
# 구간별 이력. 기준일 전에 폐지된 구간은 뺀다
HIST=json.load(open(os.path.join(ROOT,'data','overrides','old_history.json'),encoding='utf-8'))
rep2=collections.Counter()
for o in out:
    t=o['t'][o['t'].index('【')+1:].rstrip('】')
    H=HIST.get(t)
    if not H or (H.get('cn') and H['cn'][:2]!=o['cn'][:2] and o['g']!='tm'):continue
    if not H.get('close'):continue
    s0=[list(x) for x in o['s']]
    for a_,k_ in H.get('add_stops') or []:
        if a_ not in [x[0] for x in s0]:s0.append([a_,k_])
    s0.sort(key=lambda x:x[1])
    idx={x[0]:i for i,x in enumerate(s0)}
    rows=[r for r in H['close'] if r[0] in idx and r[1] in idx]
    if len(rows)!=len(H['close']):rep2['close_name_miss']+=1;print('이름 불일치',t,[r[:2] for r in H['close'] if r[0] not in idx or r[1] not in idx])
    if not rows:continue
    keep=[False]*(len(s0)-1)
    close=[None]*(len(s0)-1);legal=[None]*(len(s0)-1)
    for r in rows:
        i,j=sorted((idx[r[0]],idx[r[1]]))
        for k in range(i,j):
            close[k]=r[2];legal[k]=r[3] if len(r)>3 else None
    # 법적 폐지가 기준일 뒤면 수록 범위 안이다
    live=[k for k in range(len(s0)-1) if close[k] is None or (legal[k] or close[k])>=CUT]
    if not live:rep2['all_before']+=1;o['drop']=True;continue
    a0,b0=live[0],live[-1]+1
    if a0>0 or b0<len(s0)-1:rep2['trimmed']+=1
    base=s0[a0][1]
    o['s']=[[x[0],round(x[1]-base,1)] for x in s0[a0:b0+1]]
    # 개업 경계로만 쓴 역은 폐지 전에 사라졌으므로 역 목록에 남기지 않는다
    bound={x for r in rows for x in r[:2]}
    extra={a_ for a_,k_ in H.get('add_stops') or [] if a_ not in bound}
    o['s']=[x for x in o['s'] if x[0] not in extra]
    new=[['区間','営業km','廃止日']];lg=[]
    k=a0
    while k<b0:
        e=k
        while e+1<b0 and close[e+1]==close[k] and legal[e+1]==legal[k]:e+=1
        if close[k]:
            new.append([f'{s0[k][0]}～{s0[e+1][0]}',str(round(s0[e+1][1]-s0[k][1],1)),close[k]])
            if legal[k]:lg.append([s0[k][0],s0[e+1][0],legal[k]])
        k=e+1
    o['h'][1]=new;o['src']['close']='wikipedia'   # 구간 이력은 위키 문서에서 사람이 옮겼다
    if lg:o['legal']=lg
    op=[r for r in H.get('open') or [] if r[0] in idx and r[1] in idx]
    if op:
        names={x[0] for x in o['s']}
        def snap(x):
            return x if x in names else next((y[0] for y in s0[idx[x]+1:] if y[0] in names),x)
        op=[[snap(r[0]),snap(r[1]),r[2]] for r in op]
        o['h'][0]=[['区間','営業km','開業日']]+[[f'{r[0]}～{r[1]}',str(round(abs(s0[idx[r[1]]][1]-s0[idx[r[0]]][1]),1)),r[2]] for r in op if r[0]!=r[1] and r[0] in names and r[1] in names]
    nm2={x[0] for x in o['s']}
    sv=[r for r in H.get('service_end') or [] if r[0] in nm2 and r[1] in nm2]
    if sv:o['svc']=sv
out=[o for o in out if not o.get('drop')]
print('구간 이력',dict(rep2))
json.dump(out,open(os.path.join(IMP,'stationdb','old_lines.json'),'w',encoding='utf-8'),ensure_ascii=False)
os.makedirs(CAND,exist_ok=True)
json.dump(dict(stat=rep,archive=arch),open(os.path.join(CAND,'old_report.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=0)
print(dict(rep),[x['t'][8:] for x in out][:20],[a['name'] for a in arch][:20])
