"""역 이름 읽기를 한자 단위로 나눠, 장음처럼 보이지만 낱말 경계인 자리(下|落合 しも|おちあい, 豊|岡 とよ|おか)를 찾는다.

한자별 읽기 표는 data/overrides/kanji_readings.json이다. 역 이름의 일본어·읽기 쌍에서 배운 표이고 tools/dev/kanji_readings.py로 다시 만든다.
빌드마다 새로 배우지 않는 것은 같은 입력이면 결과가 바이트까지 같아야 하기 때문이다.

경계로 보는 조건(모두 맞아야 한다, 5회차 장음 점검 2026-11-25):
- 뒤 단위의 읽기가 お·う로 시작하고, 앞 읽기의 끝 글자가 장음을 만들 수 있는 글자(お단·う단)다
- 뒤 읽기가 그 한자의 자주 나오는 읽기이고(3번 이상, 그 한자 읽기의 20% 이상), 장음과 헷갈릴 수 없는 자리(이름 첫머리이거나 앞 글자가 お단·う단이 아닌 자리)에서도 두 번 이상 나온 읽기다. 小路 こうじ의 路=うじ처럼 장음 자리에서만 나오는 읽기는 나눔이 서로를 굳힌 것이라 믿지 않는다
- 앞 단위가 한자면 그 읽기도 자주 나오는 읽기다(青梅 おうめ의 青=お는 아니다)
- 뒤 읽기가 う 한 글자가 아니다(由宇 ゆう: う 하나는 장음 표시와 구별되지 않는다)
- 작은 ゃゅょ 뒤 う 앞에서는 나누지 않는다(きょう·ちゅう는 음독 한 덩어리)
- 숫자·로마자가 든 이름은 나누지 않는다(정렬할 수 없다)
"""
import json,math,os,re,unicodedata

ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_T=None
AMB='おこそとのほもよろごぞどぼぽょうくすつぬふむゆるぐずづぶぷゅ'
KANA_EQ={'ヶ':('か','が','け'),'ケ':('か','が','け'),'ノ':('の',),'の':('の',),'ッ':('つ','っ'),'ツ':('つ',)}
_NOSTART='ゃゅょぁぃぅぇぉっんー'

def _hira(s):
    return ''.join(chr(ord(c)-0x60) if 'ァ'<=c<='ヶ' else c for c in unicodedata.normalize('NFKC',s))

def table():
    global _T
    if _T is None:
        p=os.path.join(ROOT,'data','overrides','kanji_readings.json')
        d=json.load(open(p,encoding='utf-8')) if os.path.exists(p) else {'count':{},'safe':{}}
        _T=(d['count'],d['safe'],{c:sum(v.values()) for c,v in d['count'].items()})
    return _T

def iskanji(c):return '一'<=c<='鿿' or c in '々〆'

def units(j):
    """일본어 이름을 단위로 나눈다: 한자 하나, ヶ·ノ 같은 한 글자, 가나 덩어리 하나. 【西】·〔臨〕 같은 주석 괄호는 읽기에 없어 뗀다"""
    j=re.sub(r'[【〔［\[].*?[】〕］\]]','',j)
    out=[];i=0
    while i<len(j):
        c=j[i]
        if iskanji(c):out.append(('K',c));i+=1
        elif c in KANA_EQ:out.append(('E',c));i+=1
        else:
            m=re.match(r'[ぁ-ゖァ-ヺー]+',j[i:])
            if m:out.append(('H',_hira(m.group(0))));i+=len(m.group(0))
            else:out.append(('X',c));i+=1
    return out

def logp(cnt,tot,c,r,prev=None):
    if c=='々' and prev is not None:
        # 앞 한자 읽기를 되풀이한다(연탁 허용)
        return 0.0 if r==prev or (len(r)==len(prev) and r[1:]==prev[1:]) else -12.0
    v=cnt.get(c,{}).get(r,0)
    if v:return math.log(v/(tot.get(c,0)+2))
    return -6.0-1.5*abs(len(r)-1.6)

# 손 목록의 훈독(en_rules.WORD_START: 浦 うら, 内 うち, 兎 うさぎ …)은 장음 자리에서도 확인된 읽기로 본다
KNOWN_START={'浦':'うら','裏':'うら','内':'うち','牛':'うし','魚':'うお','海':'うみ','兎':'うさぎ','畝':'うね','上':'うえ','尾':'お'}
def _known(safe,c,r):
    """장음과 헷갈릴 수 없는 자리에서 두 번 이상 본 읽기이거나 손 목록의 훈독. safe가 아직 없으면(학습 첫 단계) 손 목록만"""
    return KNOWN_START.get(c)==r or (safe is not None and safe.get(c,{}).get(r,0)>=2)
def _attested(safe,c,r):
    return safe is None or safe.get(c,{}).get(r,0)>=2 or KNOWN_START.get(c)==r

def seg(j,k,cnt=None,tot=None,safe=None):
    """(한자·가나 단위, 그 읽기) 목록. 맞출 수 없으면 None.
    safe를 주면, 앞 읽기 끝이 장음을 만들 수 있는 글자인데 お·う로 시작하는 읽기가 장음과 헷갈릴 수 없는 자리에서 확인된 적 없으면 크게 깎는다.
    한 한자의 음독 장음을 두 한자로 잘못 나누지 않게 한다(王子 おう|じ, 小路 こう|じ, 国府 こう)"""
    if cnt is None:cnt,safe,tot=table()
    u=units(j);N=len(k)
    best={(0,0):(0.0,[])}
    for i,(t,c) in enumerate(u):
        nb={}
        for (_,p),(s,path) in sorted(best.items()):
            if t=='H':
                if not k.startswith(c,p):continue
                cands=[c]
            elif t=='E':cands=[x for x in KANA_EQ[c] if k.startswith(x,p)]
            elif t=='X':
                if c.isdigit() or unicodedata.category(c)[0] in 'LN':continue
                cands=['']
            else:cands=[k[p:p+L] for L in range(1,5) if p+L<=N and k[p] not in _NOSTART]
            # 한자와 한자 사이에 표기 없이 읽기에만 끼는 の·が(田浦 た|の|うら, 道上 みち|の|うえ, 妹尾 せ|の|お)는 따로 한 단위로 읽는다
            starts=[(p,s,path)]
            if t=='K' and i and u[i-1][0]=='K':
                for h in ('の','が'):
                    if k.startswith(h,p):starts.append((p+1,s-2.0,path+[('',h)]))
            for p0,s0,path0 in starts:
              cc=cands if p0==p else [k[p0:p0+L] for L in range(1,5) if p0+L<=N and k[p0] not in _NOSTART]
              for r in cc:
                prev=path0[-1][1].lstrip('\0') if path0 else None
                # 숨은 の·が 뒤 읽기는 두 글자 이상의 확인된 읽기여야 한다(稲生 いのう를 稲|の|生(う)로 읽지 않게)
                if p0!=p and not ((len(r)>=2 and _known(safe,c,r)) or KNOWN_START.get(c)==r):continue
                # 음독 장음(きょう·ちゅう)은 한 덩어리다. 작은 ゃゅょ 뒤 う 앞에서는 나누지 않는다. 확인된 훈독(裏 うら: 事務所|裏)은 예외
                if t=='K' and prev and prev[-1] in 'ゃゅょ' and r[:1]=='う' and not _known(safe,c,r):continue
                sc=s0+(logp(cnt,tot,c,r,prev) if t=='K' else 0.0)
                pen=t=='K' and prev and prev[-1] in AMB and r[:1] in 'おう' and not _attested(safe,c,r)
                if pen:sc-=14.0
                key=(i+1,p0+len(r))
                # 깎인 단위는 읽기 앞에 표시(\0)를 붙여 둔다. 가장 나은 나눔에 그것이 남으면 믿을 수 없는 나눔이다
                if key not in nb or nb[key][0]<sc:nb[key]=(sc,path0+[(c,('\0' if pen else '')+r)])
        best=nb
    e=best.get((len(u),N))
    if not e:return None
    # 한자 수에 비해 읽기가 모자란 熟字訓(小志生木 こじゅうき)은 깎인 단위가 남는다. 한자마다 읽기를 줄 수 없으니 나누지 않는다
    if any(r.startswith('\0') for _,r in e[1]):return None
    return e[1]

LONG1=re.compile('([おこそとのほもよろごぞどぼぽょ])[うお]');LONG2=re.compile('([うくすつぬふむゆるぐずづぶぷゅ])う')
def _within(r):return LONG2.sub(r'\1',LONG1.sub(r'\1',r))

def contract(kana,ja):
    """같은 한자 읽기 안에서만 장음을 줄인다(東 とう→to, 大 おお→o). 한자 경계를 넘는 모음은 줄이지 않는다(豊|岡 toyooka, 下|落合).
    가나 덩어리(ぶどう·ゆうえんち)는 한 낱말이라 그 안에서 줄인다. 숨은 の·が는 경계다.
    정렬 보정: 앞 단위 끝이 장음을 만들 수 있는 글자이고 뒤 한자 읽기가 お·う로 시작하는데, 그 읽기가 장음과 헷갈릴 수 없는 자리에서
    두 번 이상 본 읽기가 아니면(小路 こ|うじ의 路=うじ, 由宇의 宇=う 한 글자) 잘못 나눈 것이라 앞 단위에 붙인다.
    맞출 수 없으면(숫자·로마자가 든 이름) None"""
    cnt,safe,tot=table()
    if not ja or not kana:return None
    sg=seg(ja,kana,cnt,tot,safe)
    if not sg:return None
    # 生를 う·お 한 글자로 읽는 이름(葛生 くずう, 室生 むろう, 栄生 さこう, 穴生 あのお)은 ふ→う 옛 음운 변화로 앞 음절과 이어진 장음이다
    m=[]
    for c,r in sg:
        if m and m[-1][0] and iskanji(m[-1][0][-1]) and c=='生' and r in ('う','お'):m[-1]=(m[-1][0]+c,m[-1][1]+r);continue
        m.append((c,r))
    return ''.join(_within(r) if c else r for c,r in m)
