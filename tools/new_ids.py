# -*- coding: utf-8 -*-
# 새로 들어온 항목의 공개 ID를 영어 이름으로 매겨 data/imports/id_map.json에 더한다 (ARCHITECTURE §4.2)
# 순서: NORIORI_NEW_IDS=1 bash tools/all.sh (내부 키를 그대로 냄) -> python3 -I tools/new_ids.py -> bash tools/all.sh
# 규칙: 접두사 뒤에 영어 이름. 겹치면 회사 약칭, 그다음 노선 이름을 붙인다. 그래도 겹치면 멈추고 손으로 정한다. 숫자·해시·_b 꼬리는 쓰지 않는다
import sys,os,re,json,collections,unicodedata
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from lib import *
P=os.path.join(IMP,'id_map.json')
M=json.load(open(P,encoding='utf-8'))
NEW=json.load(open(os.path.join(CAND,'new_ids.json'),encoding='utf-8'))
if not NEW:print('새 ID 없음');sys.exit(0)
def slug(s):
    s=unicodedata.normalize('NFKD',s or '').encode('ascii','ignore').decode().lower().replace("'",'').replace('&',' and ')
    return re.sub(r'[^a-z0-9]+','_',s).strip('_')
EN={};JA={}
for r in load('names'):
    if r.get('line_id') or r.get('valid_from'):continue
    if r['lang']=='en':EN.setdefault((r['entity_type'],r['id']),r['text'])
    if r['lang']=='ja':JA.setdefault((r['entity_type'],r['id']),r['text'])
def short(s):
    for _ in range(2):s=re.sub(r'_(company|corporation|electric_railway|electric_railroad|railway|railroad|electric_tramway|tramway|kotsu|transportation|bus|smelting_and_refining|kaihatsu|denki_tetsudo)$','',s)
    return s
taken=set(M['ids'].values())
lines={l['id']:l for l in load('lines')}
ops={o['id']:o for o in load('operators')}
routes={r['id']:r for r in load('routes')}
# 노드가 지나는 노선
nl=collections.defaultdict(set)
for e in load('edges'):nl[e['a']].add(e['seed_line']);nl[e['b']].add(e['seed_line'])
out={};bad=[]
def put(k,cands):
    for c in cands:
        if c and c not in taken:taken.add(c);out[k]=c;return
    bad.append((k,cands))
def fam_op(f):
    return out.get('o_'+f[1:]) or M['ids'].get('o_'+f[1:]) if f and f!='jr' else None
def tail(i):return (out.get(i) or i or '')[2:]
# 사업자 -> 노선 -> 역 -> 계통 순서. 뒤의 것이 앞의 이름을 쓴다
for k in sorted(x for x in NEW if x.startswith('o_')):
    put(k,['o_'+slug(EN.get(('operator',k)))])
fam={}
for k,v in out.items():
    if re.fullmatch(r'o_9[0-9a-f]{6}',k):fam['p'+k[2:]]='p'+v[2:]
for k in sorted(x for x in NEW if x.startswith('l_')):
    t=slug(EN.get(('line',k)));o=fam_op((lines.get(k) or {}).get('family'))
    put(k,['l_'+t,'l_'+t+'_'+short(o[2:]) if o else None])
for k in sorted(x for x in NEW if x.startswith('n_')):
    t=slug(EN.get(('node',k)))
    l0=sorted(nl.get(k) or [None])[0]
    o=fam_op((lines.get(l0) or {}).get('family'))
    lt=re.sub(r'_line$','',tail(l0)) if l0 else ''
    put(k,['n_'+t,'n_'+t+'_'+short(o[2:]) if o else None,'n_'+t+'_'+lt if lt else None,'n_'+t+'_'+short(o[2:])+'_'+lt if o and lt else None])
for k in sorted(x for x in NEW if x.startswith('r_')):
    r=routes.get(k) or {}
    lt=tail(r.get('line'))
    put(k,['r_'+lt if r.get('role')=='main' else 'r_'+lt+'_'+tail(r.get('from'))+'_'+tail(r.get('to'))])
left=[k for k in NEW if k not in out]
if bad or left:
    for k,c in bad[:40]:print('겹침',k,c)
    raise SystemExit(f'공개 ID를 정하지 못한 항목 {len(bad)}개 (남은 {len(left)}개). 이름 규칙에 맞게 손으로 정하세요')
v=list(out.values())
assert not [x for x in v if re.search(r'_9[0-9a-f]{6}|_\d{5}',x)],[x for x in v if re.search(r'_9[0-9a-f]{6}|_\d{5}',x)][:5]
M['ids'].update(out);M['family'].update(fam)
json.dump(M,open(P,'w',encoding='utf-8'),ensure_ascii=False,indent=0,sort_keys=True)
print('새 ID',len(out),collections.Counter(x.split('_')[0] for x in out.values()),'예',v[:8])
