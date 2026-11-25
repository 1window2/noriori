"""data/overrides/kanji_readings.json을 다시 만든다: 역 이름(노드·열람 전용)의 일본어·읽기 쌍에서 배운 한자별 읽기 표.
tools/en_segment.py가 장음처럼 보이는 낱말 경계를 찾을 때 쓴다.
usage: python3 -I tools/dev/kanji_readings.py [build/names.sqlite]

배우는 법: 한 글자 이름의 읽기를 씨앗으로 두고, 모든 이름을 가장 그럴듯하게 나눠 한자별 읽기를 세는 일을 네 번 되풀이한다.
safe는 장음과 헷갈릴 수 없는 자리(이름 첫머리, 앞 글자가 お단·う단이 아닌 자리)에서 본 횟수다."""
import collections,json,os,sqlite3,sys,unicodedata,re
ROOT=os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0,os.path.join(ROOT,'tools'))
import en_segment as S

def plain(s):return re.sub(r'[（(].*?[)）]','',unicodedata.normalize('NFKC',s or '')).strip().replace(' ','')
db=sys.argv[1] if len(sys.argv)>1 else os.path.join(ROOT,'build','names.sqlite')
n=sqlite3.connect(db)
pairs=sorted({(plain(t),S._hira(plain(k))) for t,k in n.execute("select text,kana from name where lang='ja' and entity_type in ('node','archive') and kana is not null and kana!=''") if plain(t) and plain(k)})
def seed():
    c=collections.defaultdict(collections.Counter)
    for j,k in pairs:
        u=S.units(j)
        if len(u)==1 and u[0][0]=='K':c[u[0][1]][k]+=5
    return c
def safe_of(cnt,tot,sf):
    out=collections.defaultdict(collections.Counter)
    for j,k in pairs:
        s=S.seg(j,k,cnt,tot,sf)
        if not s:continue
        acc=''
        for c,r in s:
            if S.iskanji(c) and (not acc or acc[-1] not in S.AMB):out[c][r]+=1
            acc+=r
    return out
cnt=seed();sf=None
for it in range(4):
    tot={c:sum(v.values()) for c,v in cnt.items()}
    if it>=2:sf=safe_of(cnt,tot,sf)
    new=seed();ok=0
    for j,k in pairs:
        s=S.seg(j,k,cnt,tot,sf)
        if not s:continue
        ok+=1
        for c,r in s:
            if S.iskanji(c) and c!='々':new[c][r]+=1
    cnt=new
tot={c:sum(v.values()) for c,v in cnt.items()}
safe=safe_of(cnt,tot,sf)
out={'설명':'역 이름 일본어·읽기 쌍에서 배운 한자별 읽기 횟수(count)와 장음과 헷갈릴 수 없는 자리에서 본 횟수(safe). tools/en_segment.py가 장음처럼 보이는 낱말 경계(下|落合, 豊|岡)를 찾을 때 쓴다. 손으로 고치지 않고 tools/dev/kanji_readings.py로 다시 만든다 (5회차 장음 점검 2026-11-25)',
     'pairs':len(pairs),'aligned':ok,
     'count':{c:dict(sorted(v.items())) for c,v in sorted(cnt.items())},
     'safe':{c:dict(sorted(v.items())) for c,v in sorted(safe.items())}}
p=os.path.join(ROOT,'data','overrides','kanji_readings.json')
with open(p,'w',encoding='utf-8') as f:json.dump(out,f,ensure_ascii=False,indent=0,sort_keys=False)
print('pairs',len(pairs),'aligned',ok,'kanji',len(cnt),'->',p)
