# -*- coding: utf-8 -*-
# 지도 역 이름에 쓰는 글자만 추려 글리프를 앱에 넣는다. 인터넷이 없어도 이름이 보여야 한다.
# 지도 엔진은 범위 파일 하나가 없으면 그 타일의 이름을 통째로 그리지 않으므로, 쓰는 범위는 전부 만든다.
# 원본은 OpenFreeMap의 Noto Sans Regular다 (SIL OFL 1.1). 받은 파일은 data/imports/glyphs에 남긴다
import sys,os,sqlite3,urllib.request
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from lib import *
CACHE=os.path.join(ROOT,'data','imports','glyphs')
OUT=os.path.join(ROOT,'data','base','glyphs')
# 깨끗한 체크아웃에는 원본이 없다. 저장소의 글리프를 그대로 쓰고 네트워크를 쓰지 않는다
if not os.path.isdir(CACHE):
    print('글리프 원본이 없어 data/base/glyphs를 그대로 씁니다');sys.exit()
URL='https://tiles.openfreemap.org/fonts/Noto%20Sans%20Regular/{}.pbf'
UA={'User-Agent':'noriori-data'}
nm=sqlite3.connect(os.path.join(BUILD,'names.sqlite'))
chars=set()
for lang in ('ja','ko','en'):
    for (x,) in nm.execute("select text from name where entity_type='node' and lang=? and line_id is null",(lang,)):chars.update(map(ord,x))
chars.add(ord(' '))
# 빌드는 네트워크를 쓰지 않는다. 새 글자 범위가 생기면 --fetch로 받아 data/imports/glyphs에 둔다
FETCH='--fetch' in sys.argv
def fetch(name):
    p=os.path.join(CACHE,name+'.pbf')
    if not os.path.exists(p):
        if not FETCH:raise SystemExit(f'글리프 {name}.pbf가 없습니다. python3 -I tools/gen_glyphs.py --fetch로 받으세요')
        req=urllib.request.Request(URL.format(name),headers=UA)
        with urllib.request.urlopen(req,timeout=30) as r:raw=r.read()
        with open(p,'wb') as f:f.write(raw)
    return open(p,'rb').read()
def varint(b,i):
    v=s=0
    while True:
        c=b[i];i+=1;v|=(c&127)<<s;s+=7
        if c<128:return v,i
def put(v):
    o=bytearray()
    while True:
        c=v&127;v>>=7
        if v:o.append(c|128)
        else:o.append(c);return bytes(o)
def fields(b):
    i=0
    while i<len(b):
        tag,i=varint(b,i);n,w=tag>>3,tag&7
        if w==0:
            v,i=varint(b,i);yield n,w,v,None
        elif w==2:
            l,i=varint(b,i);yield n,w,None,b[i:i+l];i+=l
        else:raise ValueError('pbf')
def lenfield(n,data):return put(n<<3|2)+put(len(data))+data
def subset(raw,want):
    out=b'';kept=set()
    for n,w,_,stack in fields(raw):
        if n!=1 or w!=2:continue
        body=b''
        for m,mw,v,d in fields(stack):
            if m==3:
                gid=next(x for k,_,x,_ in fields(d) if k==1)
                if gid in want:body+=lenfield(3,d);kept.add(gid)
            elif mw==2:body+=lenfield(m,d)
        out+=lenfield(1,body)
    return out,kept
ranges={}
for c in chars:ranges.setdefault(c//256,set()).add(c)
total=0;missing=set();made={}
for r,want in sorted(ranges.items()):
    name=f'{r*256}-{r*256+255}'
    data,kept=subset(fetch(name),want)
    missing|=want-kept
    made[f'glyph-{name}.pbf']=data
    total+=len(data)
# 다 받은 뒤에만 지운다. 도중에 실패하면 저장소의 글리프가 남는다
os.makedirs(OUT,exist_ok=True)
for f in os.listdir(OUT):os.remove(os.path.join(OUT,f))
for name,data in made.items():
    with open(os.path.join(OUT,name),'wb') as f:f.write(data)
print('글리프',len(chars),'자',len(ranges),'범위',total,'바이트 없는 글자',len(missing),''.join(map(chr,sorted(missing)))[:60])
