# -*- coding: utf-8 -*-
# N05 손 대조의 근거 보기 (data/overrides/n05_fix.json의 evidence·note). data/imports가 있는 체크아웃에서만 돈다
# 사용: python3 -I tools/n05_evidence.py list | ok <번호|노선이름 일부> | hold|tram|in_db|archive|out [번호] | wiki <제목> (절 전체) | find <글자> (위키 캐시 제목 찾기)
# 프로젝트 루트에서 돌린다
import sys,os,json,re,glob,gzip
sys.path.insert(0,'tools')
import gen_n05 as g
REP=json.load(open('data/candidates/n05_report.json'))['report']
ROWS={x['t']:x for x in json.load(open('data/imports/n05/lines.json'))}
OK=[r for r in REP if r['result']=='ok'];HOLD=[r for r in REP if r['result']=='hold']
def section(t,names):
    o=[];on=False
    for line in t.split('\n'):
        m=re.match(r'^(=+)\s*(.*?)\s*=+\s*$',line)
        if m:on=any(n in m.group(2) for n in names)
        if on:o.append(line)
    return '\n'.join(o)
def clean(t):
    t=re.sub(r'<ref[^>]*/>|<ref.*?</ref>','',t,flags=re.S);t=re.sub(r'<!--.*?-->','',t,flags=re.S)
    return re.sub(r'\[\[(?:[^\]|]*\|)?([^\]]*)\]\]',r'\1',t)
def wiki(title,full=False):
    rec=g.doc(title)
    if not rec:print('  (위키 캐시에 없음)',title);return
    t=clean(rec.get('wikitext') or '')
    print(f'=== 위키 {title} revid={rec.get("revid")}')
    m=re.search(r'\{\{(?:鉄道路線ウィキ|Infobox 鉄道路線|Infobox 鉄道路線|鉄道路線)[^\n]*\n(.*?)\n\}\}',t,re.S)
    ib=re.findall(r'^\|\s*(開業|廃止|休止|路線距離|営業キロ|駅数|起点|終点|運営者|所有者)\s*=\s*(.*)$',t,re.M)
    print('  인포박스',ib)
    for k,rows in g.variants(rec)[:6]:
        if len(rows)>=2:print('  역 목록 후보',k,rows)
    for nm in (['歴史','沿革','年表'],['駅一覧','停留場一覧','駅・停留場一覧']):
        sx=section(t,nm)
        print(f'  --- {nm[0]} 절 ---');print(sx[:9000] if not full else sx)
def ok(r):
    t='乗車区間の選択【'+r['line'].split(' ',1)[1]+'】' if False else None
    row=next((x for x in ROWS.values() if r['line'].split(' ',1)[-1] in x['t'] and (x['cn']==r['line'].split(' ')[0] or x['jr'])),None)
    print('### 노선',r['line']);print('보고',json.dumps({k:v for k,v in r.items() if k not in('names',)},ensure_ascii=False))
    if row:print('지금 행',json.dumps({k:row[k] for k in ('t','cn','s','h','legal','sclose','sopen') if k in row},ensure_ascii=False))
    x=next((x for x in GR if x['names']==r['names']),None)
    if x:
        print('N05 묶음 역 (이름, 처음 해, 마지막 해, 경도·위도, N05 노선, 사업자)')
        for s in x['stations']:print('   ',s['name'],s['yb'],s['ye'],s['pt'],s.get('line'),s.get('op'))
    wiki(r['title'])
GR=g.groups()
cmd=sys.argv[1]
if cmd=='list':
    for i,r in enumerate(OK):print('ok',i,r['line'],r['title'])
    for i,r in enumerate(HOLD):print('hold',i,r['names'],r.get('name'))
elif cmd=='ok':
    a=sys.argv[2];rs=[OK[int(a)]] if a.isdigit() else [r for r in OK if a in r['line']]
    for r in rs:ok(r)
elif cmd in('hold','tram','in_db','archive','out'):
    L=[r for r in REP if r['result']==cmd]
    if len(sys.argv)<3:
        for i,r in enumerate(L):print(cmd,i,r['names'],r['closed_year'],r.get('why','')[:80])
        sys.exit()
    r=L[int(sys.argv[2])];print(json.dumps(r,ensure_ascii=False))
    x=next((x for x in GR if x['names']==r['names']),None)
    for s in x['stations']:print('   ',s['name'],s['yb'],s['ye'],s['pt'],s.get('line'),s.get('op'))
    print('찾아 본 제목',g.titles(x))
elif cmd=='wiki':wiki(sys.argv[2],full=True)
elif cmd=='find':
    # 위키 캐시에서 제목·이름에 글자가 든 문서
    q=sys.argv[2]
    for f in glob.glob(os.path.join(g.WIKI,'*.json.gz')):
        try:rec=json.load(gzip.open(f,'rt',encoding='utf-8'))
        except Exception:continue
        nm=(rec.get('title') or '')+' | '+(rec.get('name') or '')
        if q in nm and rec.get('html'):print(nm,rec.get('revid'))
