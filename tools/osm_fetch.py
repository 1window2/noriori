# -*- coding: utf-8 -*-
# Overpass API에서 일본 철도 선로를 영역별로 받는다. 받은 값은 신뢰하지 않는 데이터다. python3 -I로 돌린다
# all.sh와 따로, 원천을 새로 받을 때만 실행한다: python3 -I tools/osm_fetch.py [폴더 이름]
# 공개 서비스라 한 번에 하나씩, 간격을 두고 부른다. 실패하면 간격을 늘리고, 그래도 안 되면 영역을 넷으로 나눈다
import sys,os,json,gzip,time,math,subprocess,tempfile
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from lib import *
URL='https://overpass-api.de/api/interpreter'
UA='noriori-data'
GAP=8                # 호출 사이 최소 간격(초)
RETRY=7
QUERY='''[out:json][timeout:170][bbox:{s},{w},{n},{e}];
(
 way["railway"~"^(rail|subway|light_rail|tram|narrow_gauge|monorail|funicular)$"]["service"!="yard"];
 way["railway"~"^(abandoned|razed|disused|dismantled|preserved)$"];
 way["abandoned:railway"];
 way["razed:railway"];
 way["disused:railway"];
);
out tags geom;
'''
name=sys.argv[1] if len(sys.argv)>1 else 'overpass-'+AS_OF
OUT=os.path.join(IMP,'osm',name)
os.makedirs(OUT,exist_ok=True)
IDX=os.path.join(OUT,'index.json')
index=json.load(open(IDX,encoding='utf-8')) if os.path.exists(IDX) else dict(url=URL,user_agent=UA,query=QUERY,calls=0,failed=0,tiles={})
# 격자: 역 좌표가 있는 칸과 구간이 지나는 칸. 바다만 있는 칸은 부르지 않는다
pos={p['node']:(p['lat'],p['lon']) for p in load('positions') if p.get('lat') is not None}
cells=set()
for la,lo in pos.values():cells.add((math.floor(la),math.floor(lo)))
for e in load('edges'):
    a,b=pos.get(e['a']),pos.get(e['b'])
    if not a or not b:continue
    n=max(2,int(max(abs(a[0]-b[0]),abs(a[1]-b[1]))/.1)+1)
    for i in range(n+1):
        f=i/n;cells.add((math.floor(a[0]+(b[0]-a[0])*f),math.floor(a[1]+(b[1]-a[1])*f)))
print('칸',len(cells),flush=True)
last=[0.0]
class Http(Exception):
    def __init__(self,code):self.code=code;super().__init__(code)
# macOS 기본 python3의 LibreSSL로는 이 서버와 TLS가 맺어지지 않아 curl로 부른다. 인증서 검증은 끄지 않는다
def call(q):
    wait=GAP-(time.time()-last[0])
    if wait>0:time.sleep(wait)
    last[0]=time.time();index['calls']+=1
    with tempfile.TemporaryDirectory() as td:
        qf=os.path.join(td,'q');bf=os.path.join(td,'b')
        open(qf,'w',encoding='utf-8').write(q)
        r=subprocess.run(['curl','-sS','--compressed','-m','200','-A',UA,'-o',bf,'-w','%{http_code}','--data-urlencode','data@'+qf,URL],capture_output=True,text=True)
        if r.returncode!=0:raise OSError(r.stderr.strip()[:200])
        c=int(r.stdout.strip() or 0)
        if c!=200:raise Http(c)
        return open(bf,'rb').read()
def save():
    t=IDX+'.tmp';json.dump(index,open(t,'w',encoding='utf-8'),ensure_ascii=False,indent=0);os.replace(t,IDX)
def fetch(s,w,n,e,depth=0):
    key=f'{s:g}_{w:g}_{n:g}_{e:g}'
    if key in index['tiles']:return
    a,b_=(s+n)/2,(w+e)/2
    parts=((s,w,a,b_),(s,b_,a,e),(a,w,n,b_),(a,b_,n,e))
    # 앞선 실행에서 이미 나눈 칸은 이어서 받는다
    if any(f'{p[0]:g}_{p[1]:g}_{p[2]:g}_{p[3]:g}' in index['tiles'] for p in parts):
        for p in parts:fetch(*p,depth+1)
        index['tiles'][key]=dict(split=True);save();return
    q=QUERY.format(s=s,w=w,n=n,e=e)
    gap=30
    for k in range(RETRY):
        try:
            b=call(q);d=json.loads(b.decode('utf-8'))
            rem=d.get('remark') or ''
            if rem and depth<3 and ('timed out' in rem or 'memory' in rem or 'error' in rem):raise TimeoutError(rem[:120])
            if rem:raise ValueError(rem[:120])
            f=os.path.join(OUT,key+'.json.gz')
            # 내용이 같으면 파일도 같게 시각을 넣지 않는다
            with open(f+'.tmp','wb') as raw:
                with gzip.GzipFile(filename='',fileobj=raw,mode='wb',mtime=0) as z:z.write(b)
            os.replace(f+'.tmp',f)
            index['tiles'][key]=dict(bbox=[s,w,n,e],ways=len(d.get('elements',[])),bytes=len(b),base=(d.get('osm3s') or {}).get('timestamp_osm_base'))
            save();print(key,len(d.get('elements',[])),len(b),'calls',index['calls'],flush=True)
            return
        except TimeoutError as x:
            print(key,'시간 초과, 영역을 나눕니다',x,flush=True);break
        except (Http,OSError,ValueError) as x:
            c=getattr(x,'code',None)
            index['failed']+=1;save()
            # 502는 대개 서버가 바빠서 난다. 큰 응답이 끊기는 504이거나 다섯 번째까지 안 되면 영역을 나눈다
            if depth<3 and (c==504 or k>=4):print(key,c or x,'영역을 나눕니다',flush=True);time.sleep(gap);break
            print(key,'실패',c or x,'대기',gap,flush=True)
            time.sleep(gap);gap=min(gap*2,900)
    else:
        print(key,'포기',flush=True);index.setdefault('gave_up',[]).append(key);save();return
    if depth>=3:
        print(key,'더 나눌 수 없음',flush=True);index.setdefault('gave_up',[]).append(key);save();return
    for p in parts:fetch(*p,depth+1)
    index['tiles'][key]=dict(split=True);save()
for la,lo in sorted(cells):fetch(la,lo,la+1,lo+1)
save()
print('끝 호출',index['calls'],'실패',index['failed'],'포기',index.get('gave_up'),flush=True)
