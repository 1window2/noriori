# -*- coding: utf-8 -*-
# data/imports의 스냅샷 판을 data/sources.lock에 적는다: 경로, 크기, sha256, 받은 날, 원천 URL, 도구 버전
# 받은 날은 파일 mtime이다. 체크아웃이나 복사로 mtime이 바뀌어도 sha256이 같으면 처음 적은 날을 유지한다
import sys,os,json,gzip,hashlib,datetime,platform,subprocess,urllib.parse
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from lib import *
OUT=os.path.join(ROOT,'data','sources.lock')
WIKI='https://ja.wikipedia.org/w/api.php'
SD='https://github.com/Seo-4d696b75/station_database'
NAMU='https://huggingface.co/datasets/heegyu/namuwiki'
# 스냅샷이 아니라 도구가 만든 파일. 받은 날이 없다
MADE={'n02_stations.json':'tools/n02_stations.py','old_lines.json':'tools/gen_old.py'}
FIXED={'noritsubushi/lines.json':'https://www.noritsubushi.org/','wikidata/stations.json':'https://query.wikidata.org/sparql',
       'wiki_kana.json':WIKI,'wiki_station.json':WIKI,'wiki_titles.txt':WIKI,'wiki_titles2.txt':WIKI,'wiki_titles3.txt':WIKI,'old_titles.json':WIKI,
       'names_ko.json':NAMU,'names_lines.json':NAMU}
def url_of(rel):
    if rel in FIXED:return FIXED[rel]
    if rel.startswith('stationdb/'):return SD
    if rel.startswith('osm/'):return 'https://overpass-api.de/api/interpreter'
    if rel.startswith('n02/'):
        y=os.path.basename(rel).split('_')[0]
        return f'https://nlftp.mlit.go.jp/ksj/gml/data/N02/{y}/{os.path.basename(rel)}'
    if rel.startswith('wiki/'):
        r=json.load(gzip.open(os.path.join(IMP,rel),'rt',encoding='utf-8'))
        if r.get('title') and r.get('revid'):return f"https://ja.wikipedia.org/w/index.php?title={urllib.parse.quote(r['title'])}&oldid={r['revid']}"
        return WIKI
    return None
def sha(p):
    h=hashlib.sha256()
    with open(p,'rb') as f:
        for b in iter(lambda:f.read(1<<20),b''):h.update(b)
    return h.hexdigest()
def tippecanoe():
    try:
        r=subprocess.run(['tippecanoe','--version'],capture_output=True,text=True)
        return (r.stderr or r.stdout).strip().split()[-1]
    except OSError:return None
old={}
if os.path.exists(OUT):old={x['path']:x for x in json.load(open(OUT,encoding='utf-8'))['files']}
files=[]
for d,dn,fn in sorted(os.walk(IMP)):
    dn.sort()
    for f in sorted(fn):
        if f.startswith('.'):continue
        p=os.path.join(d,f);rel=os.path.relpath(p,IMP).replace(os.sep,'/');path='data/imports/'+rel
        x=dict(path=path,size=os.path.getsize(p),sha256=sha(p))
        if rel in MADE:x['made_by']=MADE[rel]
        else:
            o=old.get(path)
            x['received']=o['received'] if o and o['sha256']==x['sha256'] else datetime.date.fromtimestamp(os.path.getmtime(p)).isoformat()
            x['url']=url_of(rel)
        files.append(x)
# 항목마다 한 줄이라 판이 바뀌면 diff가 파일 단위로 보인다
head=dict(as_of=AS_OF,tools=dict(python=platform.python_version(),tippecanoe=tippecanoe()))
with open(OUT,'w',encoding='utf-8') as o:
    o.write(json.dumps(head,ensure_ascii=False)[:-1]+', "files": [\n')
    o.write(',\n'.join(json.dumps(x,ensure_ascii=False) for x in files))
    o.write('\n]}\n')
print('sources.lock',len(files))
