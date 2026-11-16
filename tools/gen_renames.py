# -*- coding: utf-8 -*-
# 위키 연혁에서 역명 변경을 뽑는다 (2회차 종합 K11).
#   역 문서 연혁(station.json hist) → data/candidates/renames.json {문서 제목:[[옛 이름,시작,끝],...]}
#     지금 이름(문서 제목)에서 거슬러 올라가며 이어지는 개칭만 받는다. 옛 이름을 문장에서 못 읽은 개칭은 [None,시작,끝]으로 남겨
#     생성기(gen_source)가 N05 연 범위 행의 끝 날짜를 정확한 날로 바꾸는 데 쓴다
#   노선 문서 年表(캐시 문서 wikitext의 歴史·沿革·年表 절) → data/candidates/renames_lines.json {캐시 파일 이름:{title, rows:[[날짜,옛 이름,새 이름],...]}}
#     노선 문서에는 어느 역 이야기인지 제목이 없어 「X駅をY駅に改称」처럼 옛·새 이름이 다 적힌 문장만 받는다. 노드 대응은 gen_source가 그 노선 역으로 한다
import sys,os,re,json,gzip,glob,collections
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from lib import *
W=json.load(open(os.path.join(IMP,'wiki','station.json'),encoding='utf-8'))
D=r'(\d{4})年(?:\s*[（(][^）)]*[）)])?\s*(?:(\d{1,2})月(?:\s*(\d{1,2})日)?)?'
# 仮乗降場·臨時駅의 「仮」「臨時」는 이름이 아니라 표식이다(旭野仮乗降場 → 旭野). 이름에 남기면 표식을 다시 붙여 「旭野仮仮乗降場」이 된다 (2회차 종합 K14·K26)
SUF=r'(?:仮乗降場|臨時乗降場|仮停車場|臨時停車場|臨時駅|仮駅|駅|停留場|電停|停留所|乗降場)'
# 가운뎃점은 이름 안에서만 받는다(愛・地球博記念公園, 逗子・葉山). 이름 첫 글자로는 받지 않아 「A・B駅間」의 나열을 이름으로 읽지 않는다
NM=r'([^\s、。：:「」『』（）()・,，→][^\s、。：:「」『』（）(),，→]{0,23}?)'
N=NM+SUF
# 옛·새 이름이 다 적힌 개칭: 「X駅をY駅に改称」「X駅がY駅と改称」「X駅からY駅へ改称」「X駅をY駅に、Z駅をW駅に改称」
# 여러 쌍을 늘어놓은 「AをB、CをDにそれぞれ改称」의 앞 쌍은 「、」로 끝난다 (石北本線 1934 上相ノ内→相ノ内, 1997 相ノ内→相内)
PAIR=re.compile(N+r'[」』]?(?:を|が|は|から|より)[「『]?'+N+r'[」』]?(に|と|へ|、)')
# 「変更」은 「駅名を変更」「名称変更」일 때만 개칭이다. 「起点は千曳駅から野辺地駅へ変更」은 개칭이 아니다
AFTER=re.compile(r'^(?:(?:駅名|名称)(?:を)?(?:改称|改名|変更)|改称|改名)')
# 새 이름만 적힌 개칭: 「Y駅に改称」 (옛 이름은 앞 줄의 이름)
R2=re.compile(r'(?:駅名を|名称を|、|：|-|同時に|に伴い|により)?[「『]?'+N+r'[」』]?(?:に|と|へ)(?:駅名)?(?:改称|改名)')
R0=re.compile(N+r'(?:として|が)(?:同時に|駅)?(?:開業|開設|設置|新設)')
# 「(別線の)Y駅が開業。X駅も同名に改称」: 새 이름은 그 줄의 다른 역 이름이다 (表参道)
SAME=re.compile(N+r'(?:も|を)同名に(?:改称|改名)')
# 노선·사업자 이름이 바뀐 줄 (역 이름 개칭이 아니다). 옛·새 역 이름이 다 적힌 문장은 이 줄에서도 받는다
NOTSTA=re.compile(r'路線名|線路名|線名|所属|社名|会社名|事業者名|会社が|鉄道が|電鉄が')
def fix(x):
    """이름 앞에 붙은 문장 조각을 뗀다: 「X駅を」「〇〇鉄道の」「移転し」「西横黒線」 등"""
    x=re.sub(r'^.*(?:駅が|駅を|駅は|駅も|駅名を|名称を|に伴い|にともない|により|に際して|際し|ため|として|に合わせて|に合わせ|にあわせて|にあわせ|同日に|については|、|：)','',x)
    x=re.sub(r'^.*(?:鉄道|電鉄|電車|電軌|軌道|貨物|地下鉄|国鉄|JR|線|社|駅|場|起点|終着|代目|付近)(?:の|が|たる|に|も|は)','',x)
    x=re.sub(r'^.*(?:移転し(?:て)?|分離して|され|このほか|その後|のうえ|の上)','',x)
    x=re.sub(r'^.*本線','',x)
    if not x.startswith('鉄道博物館'):x=re.sub(r'^[^\s]*?(?:線|鉄道)(?=[^\s]{2,}$)','',x)
    x=re.sub(r'^(?:これまでの|従来の|それまでの|当時の|同時に|鉄道省|国有鉄道|国鉄|省線|再び|この時|従来地は)','',x)
    # 가운뎃점 앞이 역·사업자 말이면 나열이다(「終着駅・中徳富」「旧・比治山」): 가운뎃점 뒤만 이름이다
    x=re.sub(r'^(?:.*駅|旧|現)・','',x).lstrip('・')
    # 「旧X駅をY駅に改称」의 「旧」는 「예전의」라는 뜻이다 (広島電鉄江波線 1954 旧江波口 → 江波口)
    return re.sub(r'^旧(?=[^\s]{2,}$)','',x)
BAD={'貨物','一般','旅客','同','当','信号場','現在','現','本','この','両','各','新','旧','同名','隣','隣の'}
def ok(x):
    """역 이름처럼 생긴 것만 받는다. 빠지면 현재 이름이 보일 뿐이지만 틀린 이름은 그대로 화면에 나온다"""
    # 가운뎃점으로 이은 이름(ルイス・C.ティファニー庭園美術館前)은 조금 더 길 수 있다
    if not x or x in BAD or not 2<=len(x)<=(20 if '・' in x else 14) or x[0] in 'のがにはをとでもへや・' or x[-1] in 'のがはをに・':return False
    # 긴 문장 조각(「夏の海水浴シーズンに新須磨」「燕市の良寛史料館が経つ位置に」)은 이름이 아니다
    if len(x)>=8 and re.search(r'[にがで](?=..)',x):return False
    return not re.search(r'[、。{}|=:：<>\[\]*＊※]|として|伴い|開業|同時に|間に|線の|により|ため|まで|および|及び|を|後に|あたる|現在|それぞれ|ともに|支線|改称|途中|接続|連絡$|^その|^この|^同社|\d+[年月日]',x)
def lo(x):return x.replace('X','0') if x else ''
def edate(y,mo,da):
    return f'{y}-{int(mo):02d}-{int(da):02d}' if da else (f'{y}-{int(mo):02d}-XX' if mo else f'{y}-XX-XX')
def clean(l):
    """위키 문법과 읽기 괄호를 떼고 문장만 남긴다. 「X駅（えっくすえき）に改称」의 읽기 괄호는 이름 사이에 끼어 대조를 깬다"""
    # 위키 목록 머리 기호(「*** 加茂野口駅を…」의 ***)는 이름이 아니다 (3회차 chubu_1-001, 8회차 W1b)
    l=re.sub(r'^\s*[*#:;]+\s*','',l)
    l=re.sub(r'\{\{読み仮名\|([^|}]*)\|[^}]*\}\}',r'\1',l)
    l=re.sub(r'\[\[(?:[^|\]]*\|)?([^\]]*)\]\]',r'\1',l);l=re.sub(r"'''?|<ref[^>]*/>|<ref[^>]*>.*?</ref>|<[^>]+>",'',l)
    l=re.sub(r'\{\{[^{}]*\}\}','',l)
    l=re.sub(r'[（(][ぁ-ゖー・\s]+[）)]','',l)
    # 다른 역 이야기를 적은 괄호(「（同時に現在の竹鼻駅は栄町駅に改称）」)는 이 역의 개칭이 아니다
    l=re.sub(r'[（(][^）)]*(?:同時に|現在の|現・|なお|それまでの|この時)[^）)]*[）)]','',l)
    l=re.sub(r'[（(](?:初代|[0-9０-９一二三四五六七八九]+代目?|現・[^）)]*|現在の[^）)]*)[）)]','',l)
    return l
def pairs(rest):
    """한 줄의 (옛 이름, 새 이름) 쌍. 쌍 뒤에 「改称」이 바로 오거나, 「、」로 이어져 그 줄 뒤에 「改称」이 있어야 한다"""
    out=[]
    for m in PAIR.finditer(rest):
        tail=rest[m.end():]
        if m.group(3)=='、':
            if re.search('改称|改名',tail):a,b=fix(m.group(1)),fix(m.group(2))
            else:continue
            if b==m.group(2) and ok(a) and ok(b) and znorm(a)!=znorm(b):out.append((a,b))
            continue
        if AFTER.match(tail) or (re.match(r'^[、，]',tail) and re.search('改称|改名',tail)) or (re.match(r'^(?:それぞれ|同時に)',tail) and re.search('改称|改名',tail)):
            a,b=fix(m.group(1)),fix(m.group(2))
            # 새 이름 쪽에 문장 조각이 붙어 있으면(「島々駅からのターミナル機能移設に伴い新島々駅に」) 쌍이 아니다
            if b!=m.group(2):continue
            if ok(a) and ok(b) and znorm(a)!=znorm(b):out.append((a,b))
    return out
def chain(cur,ev):
    """지금 이름에서 거슬러 올라가며 이어지는 개칭만 고른다. ev=[(날짜, 옛 이름|None, 새 이름)] 날짜순.
    각 이름 기간은 바로 앞 개칭 하나만 받는다. 같은 날 「A→B, B→C」에서 C의 앞은 B뿐이다 (吉原→本吉原, 鈴川→吉原)"""
    opn=[(znorm(cur),'9999')];rows=[]
    for d,a,b in reversed(ev):
        k=next((i for i,(nm,end) in enumerate(opn) if nm==znorm(b) and lo(d)<lo(end)),None)
        if k is None:continue
        opn.pop(k)
        rows.append([a,None,d])
        if a:opn.append((znorm(a),d))
    rows.sort(key=lambda r:lo(r[2]))
    for i in range(1,len(rows)):rows[i][1]=rows[i-1][2]
    return rows
out={};skip=0;stat=collections.Counter()
for t,e in W.items():
    if not e.get('hist'):continue
    cur=znorm(re.sub(r'\s*[（(].*$','',e.get('title') or t))
    ev=[];first=None;prev=None;nth=0
    for l in e['hist']:
        l=clean(l)
        d=re.match(r'^'+D,l)
        if not d:continue
        date=edate(*d.groups());rest=l[d.end():];nth+=1
        # 개업 이름은 이 역 이야기인 줄에서만 읽는다. 뒤 줄이 「A - B駅間のXが」처럼 사이 시설의 개업을 말하면 이웃 역 개업이다 (東岩瀬駅 1939 「当駅 - 高等学校前駅間の西ノ宮信号場が日満工場前駅として開業」)
        if first is None and (nth==1 or not re.search(r'間の[^、。]*?が',rest)):
            m=R0.search(rest)
            if m:
                f_=m.group(1)
                f_=re.split('である|当初の',f_)[-1]
                if re.search('鉄道|電鉄|電気|軌道|索道|延伸|開通|により|市営|会社|支社',f_):f_=re.split('の|により|に',f_)[-1]
                f_=fix(f_)
                if ok(f_):first=(f_,date);prev=prev or f_
        # 「仮称」 같은 줄은 버리되 「X仮停車場と改称」「X仮乗降場に改称」은 이름 줄이다
        if not re.search('改称|改名',rest) or re.search('^.{0,5}仮(?!停車場|乗降場|駅)',rest) or '決定' in rest:continue
        pp=pairs(rest)
        n0_=len(ev)
        for a,b in pp:ev.append((date,a,b))
        if pp:stat['pair']+=1
        m=SAME.search(rest)
        if m:
            o_=[x.group(1) for x in re.finditer(N,rest[:m.start()]) if ok(fix(x.group(1)))]
            if o_ and ok(fix(m.group(1))):ev.append((date,fix(m.group(1)),fix(o_[-1])));stat['same_name']+=1
            continue
        if NOTSTA.search(rest) and not pp:stat['not_station']+=1;continue
        # 한 줄에 다른 역의 「X駅をY駅と改称」과 이 역의 「Z駅に改称」이 함께 있다 (千葉中央: 国鉄千葉駅前駅を京成千葉駅と改称するのに伴い、千葉中央駅に改称)
        # 다른 역 쌍의 옛 이름은 막지 않는다: 이름을 맞바꾼 줄(相内駅 「相ノ内駅に改称。同時に相ノ内駅が東相ノ内駅に改称」)에서 이 역의 새 이름이 그 옛 이름이다
        got={znorm(b) for _,b in pp}
        for m in R2.finditer(rest):
            b=fix(m.group(1))
            if ok(b) and znorm(b) not in got:ev.append((date,None,b));got.add(znorm(b));stat['new_only']+=1
        # 이 역의 새 이름이 같은 줄 쌍의 옛 이름이면 그 쌍은 이름을 내준 다른 역 이야기다(塩町 「（初代）塩町駅は神杉駅に改称」, 加茂野 「従来の加茂野駅は富加駅へ改称」).
        # 그 쌍의 새 이름을 이 역의 다음 옛 이름으로 잇지 않는다
        own_={znorm(b) for _,a,b in ev[n0_:] if a is None}
        ev[n0_:]=[(d,a,b,'other') if a is not None and znorm(a) in own_ else (d,a,b) for d,a,b in ev[n0_:]]
    if not ev:continue
    ev.sort(key=lambda x:lo(x[0]))
    # 옛 이름이 없는 개칭은 앞 개칭의 새 이름(처음이면 개업 이름)이 옛 이름이다
    full=[];p_=first[0] if first else None
    for d,a,b,*oth in ev:
        if oth:continue
        # 같은 개칭이 두 번 적힌 문서(사업자별 절이 둘인 역)는 한 번만. 옛 이름이 새 이름과 같은 줄은 버린다
        if ((a or p_) is None or znorm(a or p_)!=znorm(b)) and (d,a or p_,b) not in full:full.append((d,a or p_,b))
        p_=b
    rows=chain(cur,full)
    if not rows:skip+=1;continue
    # 처음 이름의 시작은 개업일이다
    if first and rows[0][0] and znorm(rows[0][0])==znorm(first[0]) and lo(first[1])<=lo(rows[0][2]):rows[0][1]=first[1]
    rows=[r for r in rows if (r[0] is None or (ok(r[0]) and znorm(r[0])!=cur)) and r[1]!=r[2]]
    if rows:out[e.get('title') or t]=rows
os.makedirs(CAND,exist_ok=True)
json.dump(out,open(os.path.join(CAND,'renames.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=0)
# ---- 노선 문서 年表
LD=re.compile(r'^[*#:\s]*'+D)
MD=re.compile(r'^[*#:\s]*(\d{1,2})月(?:\s*(\d{1,2})日)?')
lines_out={}
for f in sorted(glob.glob(os.path.join(IMP,'wiki','*.json.gz'))):
    try:d_=json.load(gzip.open(f,'rt',encoding='utf-8'))
    except (OSError,ValueError):continue
    wt=d_.get('wikitext') or ''
    # 歴史·沿革·年表 절마다 (같은 깊이 이상의 다음 절에서 끝낸다). 年表가 歴史 아래 하위 절이거나 따로 있는 문서가 다 있다
    body=''
    for h in re.finditer(r'\n(==+)\s*(?:歴史|沿革|年表|概要と歴史|路線の歴史)\s*\1\s*\n',wt):
        body+='\n'+re.split(r'\n={2,%d}[^=]'%len(h.group(1)),'\n'+wt[h.end():])[0]
    if not body:continue
    rows=[];year=None;last=None
    for l in body.split('\n'):
        l=clean(l)
        m=LD.match(l)
        if m:
            year=m.group(1);last=edate(*m.groups());rest=l[m.end():]
        else:
            m=MD.match(l)
            if m and year:last=edate(year,m.group(1),m.group(2));rest=l[m.end():]
            else:rest=l
        if not last or not re.search('改称|改名',rest):continue
        for a,b in pairs(rest):
            if [last,a,b] not in rows:rows.append([last,a,b])
    if rows:lines_out[os.path.basename(f)[:14]]=dict(title=d_.get('title'),rows=rows)
json.dump(lines_out,open(os.path.join(CAND,'renames_lines.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=0)
print('역명 변경 문서',len(out),'행',sum(len(v) for v in out.values()),'이어지지 않아 뺌',skip,'노선 문서',len(lines_out),'쌍',sum(len(v['rows']) for v in lines_out.values()),dict(stat))
