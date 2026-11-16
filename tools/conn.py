# -*- coding: utf-8 -*-
# 위키 노선도 행과 역 자료를 대조해 환승·분기·방향·승계를 만든다
import re,os,json
import ko
from lib import HT,source_on
OPS=[('仙台市営地下鉄','せんだいしえいちかてつ','센다이시 지하철'),('札幌市営地下鉄','さっぽろしえいちかてつ','삿포로시 지하철'),('福岡市地下鉄','ふくおかしちかてつ','후쿠오카시 지하철'),('名古屋市営地下鉄','なごやしえいちかてつ','나고야 시영 지하철'),('神戸市営地下鉄','こうべしえいちかてつ','고베 시영 지하철'),('京都市営地下鉄','きょうとしえいちかてつ','교토 시영 지하철'),('横浜市営地下鉄','よこはましえいちかてつ','요코하마 시영 지하철'),
('埼玉新都市交通','さいたましんとしこうつう','사이타마 신도시 교통'),('神戸高速','こうべこうそく','고베 고속'),('姫路市営','ひめじしえい','히메지 시영'),('東京メトロ','とうきょうめとろ','도쿄메트로'),('都営','とえい','도에이'),('東急','とうきゅう','도큐'),('京急','けいきゅう','케이큐'),('京成','けいせい','케이세이'),('京王','けいおう','케이오'),('小田急','おだきゅう','오다큐'),('東武','とうぶ','도부'),('西武','せいぶ','세이부'),('相鉄','そうてつ','소테츠'),('名鉄','めいてつ','메이테츠'),('近鉄','きんてつ','킨테츠'),('阪急','はんきゅう','한큐'),('阪神','はんしん','한신'),('南海','なんかい','난카이'),('京阪','けいはん','케이한'),('山陽電鉄','さんようでんてつ','산요 전기철도'),('神戸電鉄','こうべでんてつ','고베 전철'),('神鉄','しんてつ','고베 전철'),('OsakaMetro','おおさかめとろ','오사카메트로'),('西鉄','にしてつ','니시테츠'),
('富山地鉄','とやまちてつ','도야마 지방철도'),('京福電鉄','けいふくでんてつ','케이후쿠 전기철도'),('叡山電鉄','えいざんでんてつ','에이잔 전기철도'),('阪堺電軌','はんかいでんき','한카이 전기궤도'),('岡山電軌','おかやまでんき','오카야마 전기궤도'),('琴電','ことでん','코토덴'),('福島交通','ふくしまこうつう','후쿠시마 교통'),('東海交通事業','とうかいこうつうじぎょう','도카이 교통사업'),('アルピコ交通','あるぴここうつう','알피코 교통'),('とさでん交通','とさでんこうつう','토사덴 교통'),('一畑電車','いちばたでんしゃ','이치바타 전차'),('流鉄','りゅうてつ','류테츠'),('平成筑豊鉄道','へいせいちくほうてつどう','헤이세이 치쿠호 철도'),('土佐くろしお鉄道','とさくろしおてつどう','토사쿠로시오 철도'),('阿佐海岸鉄道','あさかいがんてつどう','아사카이간 철도'),('京都丹後鉄道','きょうとたんごてつどう','교토 탄고 철도'),('北近畿タンゴ鉄道','きたきんきたんごてつどう','키타킨키 탄고 철도'),('北越急行','ほくえつきゅうこう','호쿠에츠 급행'),('ひたちなか海浜鉄道','ひたちなかかいひんてつどう','히타치나카 해빈철도'),('鹿島臨海鉄道','かしまりんかいてつどう','카시마 임해철도'),('神戸新交通','こうべしんこうつう','고베 신교통'),('大阪モノレール','おおさかものれーる','오사카 모노레일'),('千葉都市モノレール','ちばとしものれーる','치바 도시 모노레일'),('四日市あすなろう鉄道','よっかいちあすなろうてつどう','욧카이치 아스나로 철도'),('山形鉄道','やまがたてつどう','야마가타 철도'),('能勢電鉄','のせでんてつ','노세 전철'),('熊本電鉄','くまもとでんてつ','구마모토 전기철도'),('上田丸子電鉄','うえだまるこでんてつ','우에다마루코 전철')]
TRAM=re.compile(r'^(旧?広電|長崎電軌|熊本市電|鹿児島市電|伊予鉄道|函館市電).*系統')
NM=(('山陽電気鉄道','山陽電鉄'),('阪神電気鉄道','阪神'),('阪急電鉄','阪急'),('東京地下鉄','東京メトロ'),('Osaka Metro','OsakaMetro'),('大阪市高速電気軌道','OsakaMetro'),('横浜高速鉄道',''),('JR東海：',''),('JR西日本：',''),('JR東日本：',''),('JR貨物：',''),('：',''),(' ',''),('　',''),('ケ','ヶ'))
JRLINE=re.compile(r'^JR')
def clean(n):
    n=re.sub(r'[（(].*?[)）]','',n).strip()
    return JRLINE.sub('',n)
def norm(t):
    for a,b in NM:t=t.replace(a,b)
    return t
# 원자료가 회사 이름만 적은 현행 노선. 위키 문서 제목을 근거로 공식 노선명을 붙인다
LABEL=HT['CONN_LABEL']
LNW={}
_f=os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','data','imports','namuwiki','names_lines.json')
if not os.environ.get('NW_OFF') and source_on('namuwiki'):LNW=json.load(open(_f,encoding='utf-8'))
def line_ko(l):
    n=clean(l['name']);k=l['name_kana']
    if n in LABEL:return LABEL[n]
    if n in LNW:return LNW[n][0]
    if k in('','NULL'):return n
    k=re.sub(r'[（(].*?[)）]','',k)
    for jp,kn,kr in OPS:
        if n.startswith(jp) and k.startswith(kn):
            return kr+' '+ko.line(k[len(kn):],n[len(jp):])
    if l['name'].startswith('JR東西線'):return 'JR '+ko.line(k[len('じぇいあーる'):] if k.startswith('じぇいあーる') else k,n)
    for a,b in (('てつどう',' 철도'),('でんてつ',' 전철'),('きゅうこう',' 급행'),('こうつう',' 교통'),('きどう',' 궤도')):
        if k.endswith(a):return ko.station(k[:-len(a)],n[:-2])+b
    m=re.match(r'(.+?)(てつどう|でんてつ)(.+)$',k)
    if m:
        c=re.search(r'鉄道|電鉄|鐵道',n)
        return ko.station(m.group(1),n[:c.start()] if c else n)+(' 철도 ' if m.group(2)=='てつどう' else ' 전철 ')+ko.line(m.group(3),n[c.end():] if c else n)
    return ko.line(k,n)
HIDE=re.compile('京浜東北|湘南新宿|上野東京|埼京|JR神戸線|JR京都線|琵琶湖線|さくら夙川|成田エクスプレス|中央線\\(快速\\)|総武線\\(快速\\)|ケーブル|ロープウェイ|リフト')
# 본선 칸의 수직 분기 그림만 본다. '+x'는 없어진 옛 가지다
JUNC=re.compile(r'^[a-z]*ABZg(\+?)[lr]')
DROP=re.compile('専用|貨物|車両|機関区|運転区|客車区|工場|電車区|車庫|検車|支所|留置|信号場|操車場|基地|港線$')
def rowtext(r):
    return norm(r['t']+' '+' '.join(r.get('l',[])))
def junc_side(r):
    ms=[JUNC.search(re.sub(r'\+x[lrf]+','',i)) for c in r['c'] for i in c]
    ms=[m for m in ms if m]
    if not ms:return None
    return 'u' if any(m.group(1) for m in ms) else 'd'
def core(l):
    n=norm(clean(l['name']))
    for jp,_,_ in OPS:
        if n.startswith(jp):return n,n[len(jp):]
    return n,n
def match(l,txt):
    a,b=core(l)
    if a in txt:return True
    return len(b)>=3 and b in txt

SUCC_OUT={'宮崎交通','三国線','京王御陵線','江若鉄道','北丹鉄道','土佐電気鉄道','西鉄北方線','旧広電５系統(比治山線)'}
def succession(L,St,by,base):
    # 폐선으로 적힌 노선 중 같은 역들을 다른 노선이 이어 달리면 승계로 본다
    names=lambda c:[base(St[x]['name']) for _,x in by[c] if x in St]
    cur={c:set(names(c)) for c,l in L.items() if l['closed']=='0'}
    out={}
    for c,l in L.items():
        if l['closed']!='1' or l['name'] in SUCC_OUT:continue
        n=names(c)
        if len(n)<2:continue
        best=max(((sum(1 for x in n if x in s),d) for d,s in cur.items() if d!=c),default=None)
        if best and (best[0]/len(n)>=.75 or (best[0]/len(n)>=.5 and best[0]>=8)):out[c]=best[1]
    return out
