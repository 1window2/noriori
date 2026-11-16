# -*- coding: utf-8 -*-
# 공개 ID 잠금 (ARCHITECTURE §4.2). 사용자 기록이 저장하는 ID가 판 사이에 사라지거나 다른 실체로 옮겨 가지 않게 한다
#   python3 -I tools/check_ids.py            검사. 컴파일한 build/master.sqlite를 data/ids.lock과 비교한다
#   python3 -I tools/check_ids.py --add      새 ID를 목록 끝에 더한다. 있던 항목은 바꾸지 않는다
#   python3 -I tools/check_ids.py --accept <ID>...   사람이 확인한 이름·위치 변경을 지문에 반영한다
# 은퇴는 목록의 retired에 손으로 적는다: {"id": 옛 ID, "to": [새 ID] 또는 [], "edition": 판, "why": 이유}
# 검사: 삭제 금지(은퇴 목록에 없는데 사라짐), 재사용 금지(은퇴한 ID가 다시 나옴), 지문(노드 1km 넘는 이동, 이름이 완전히 바뀜), redirect 순환
import sys,os,json,sqlite3,math,difflib
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from lib import *
LOCK=os.path.join(ROOT,'data','ids.lock')
m=sqlite3.connect(os.path.join(BUILD,'master.sqlite'));n=sqlite3.connect(os.path.join(BUILD,'names.sqlite'))
ja={}
# 지금 이름: 노선별·기간 한정이 아닌 행
for t,i,x in n.execute("select entity_type,entity_id,text from name where lang='ja' and line_id is null and valid_from is null and valid_to is null"):ja.setdefault((t,i),x)
pos={i:(a,b) for i,a,b in m.execute('select node_id,lat,lon from node_position')}
# 사용자 기록에 저장되는 ID만 잠근다. 역 묶음, 환승 묶음, edge 같은 내부 ID는 넣지 않는다
now={}
for i, in m.execute('select id from node_public'):now[i]=dict(kind='node',ja=ja.get(('node',i)),lat=pos.get(i,(None,))[0],lon=pos.get(i,(None,None))[1])
for i, in m.execute('select id from line'):now[i]=dict(kind='line',ja=ja.get(('line',i)))
for i,l in m.execute('select id,line_id from route'):now[i]=dict(kind='route',line=l)
for i, in m.execute('select id from service'):now[i]=dict(kind='service',ja=ja.get(('service',i)))
for i, in m.execute('select id from operator'):now[i]=dict(kind='operator',ja=ja.get(('operator',i)))
for t in ('archive_stop','archive_line'):
    for i, in m.execute(f'select id from {t}'):now[i]=dict(kind=t)
def km(a,b):
    if None in (a.get('lat'),b.get('lat')):return 0
    q=math.radians((a['lat']+b['lat'])/2);return math.hypot((a['lat']-b['lat'])*111.2,(a['lon']-b['lon'])*111.2*math.cos(q))
def renamed(a,b):
    """이름이 완전히 바뀜. 표기 정리(괄호, 駅)는 바뀐 것으로 보지 않는다"""
    x,y=znorm(a.get('ja') or ''),znorm(b.get('ja') or '')
    return bool(x and y) and x!=y and difflib.SequenceMatcher(None,x,y).ratio()<.5
def write(lock):
    # 항목마다 한 줄이라 diff가 ID 단위로 보인다
    with open(LOCK,'w',encoding='utf-8') as f:
        f.write('{"설명": "공개 ID 잠금 목록 (ARCHITECTURE §4.2). 추가 전용. 은퇴는 retired에 적고 redirect(to)를 둔다. tools/check_ids.py가 검사한다",\n"ids": {\n')
        f.write(',\n'.join(json.dumps(k,ensure_ascii=False)+': '+json.dumps(v,ensure_ascii=False,sort_keys=True) for k,v in lock['ids'].items()))
        f.write('\n},\n"retired": [\n'+',\n'.join(json.dumps(r,ensure_ascii=False,sort_keys=True) for r in lock['retired'])+'\n]}\n')
lock=json.load(open(LOCK,encoding='utf-8')) if os.path.exists(LOCK) else dict(ids={},retired=[])
retired={r['id']:r for r in lock['retired']}
if '--add' in sys.argv:
    new=[i for i in sorted(now) if i not in lock['ids'] and i not in retired]
    for i in new:lock['ids'][i]=now[i]
    write(lock);print('ID 잠금에 더함',len(new),'전체',len(lock['ids']));sys.exit(0)
if '--accept' in sys.argv:
    for i in sys.argv[sys.argv.index('--accept')+1:]:
        if i not in lock['ids'] or i not in now:raise SystemExit(f'{i}: 잠금 목록과 지금 판 양쪽에 있어야 합니다')
        lock['ids'][i]=now[i]
    write(lock);print('지문 갱신');sys.exit(0)
bad={}
def put(k,v):
    if v:bad[k]=v
put('사라진 ID (은퇴 목록에 없음)',sorted(i for i in lock['ids'] if i not in now and i not in retired)[:30])
put('은퇴한 ID가 다시 나옴',sorted(i for i in retired if i in now)[:30])
put('종류가 바뀐 ID',sorted(i for i,v in lock['ids'].items() if i in now and now[i]['kind']!=v['kind'])[:30])
put('1km 넘게 옮겨진 노드',sorted((i,round(km(v,now[i]),2)) for i,v in lock['ids'].items() if i in now and v['kind']=='node' and km(v,now[i])>1)[:30])
put('이름이 완전히 바뀐 ID',sorted((i,v.get('ja'),now[i].get('ja')) for i,v in lock['ids'].items() if i in now and renamed(v,now[i]))[:30])
put('다른 노선으로 옮겨진 계통',sorted((i,v['line'],now[i]['line']) for i,v in lock['ids'].items() if i in now and v['kind']=='route' and v['line']!=now[i]['line'])[:30])
def chain(i,seen=()):
    if i in seen:return True
    return any(chain(t,seen+(i,)) for t in retired.get(i,{}).get('to',[]))
put('redirect 순환',sorted(i for i in retired if chain(i)))
put('redirect가 없는 ID를 가리킴',sorted(i for i,r in retired.items() for t in r.get('to',[]) if t not in now and t not in retired))
# 앱은 아직 id_redirect를 읽지 않는다. 처음으로 ID를 은퇴시키는 판에는 앱의 읽기를 함께 내야 한다 (DESIGN §2.10)
put('은퇴 ID가 있는데 앱이 id_redirect를 읽지 않음',sorted(retired) if retired and not os.path.exists(os.path.join(ROOT,'packages','noriori_store','lib','src','pack','id_redirect.dart')) else [])
new=sorted(i for i in now if i not in lock['ids'] and i not in retired)
if lock['ids']:put('잠금 목록에 없는 새 ID (확인 뒤 --add)',new[:30])
if bad:
    for k,v in bad.items():print(k,v)
    raise SystemExit('ID 잠금 검사 실패')
print('ID 잠금',len(lock['ids']),'은퇴',len(retired),'새 ID',len(new))
