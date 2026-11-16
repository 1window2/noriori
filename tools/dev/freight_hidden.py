# -*- coding: utf-8 -*-
"""여객 영업 이력이 없는 화물 전용 구간 표(data/overrides/freight_hidden.json)를 컴파일 단계 보정 행
(data/overrides/source_patch/<모듈>/zz_f9_freight.yaml)으로 펼친다 (화물 규칙 1, 사용자 결정 2026-11-09, DESIGN §1.4 별선·단락선·§2.4).

- 모선마다 숨은 노선 하나(rule_class hidden, 「모선 이름（貨物）」, ID 「모선 ID_freight」)를 두고 화물 지선마다 계통 하나를 둔다.
  숨은 노선은 분모 단위가 없어 목록·검색·요약에 나오지 않고 기록할 수 없다 (compile unit_rows, 검색 색인 sadd).
- 새 화물역은 kind freight 노드(이름은 ja만, 정차한 적이 없어 앱용 이름이 지워진다).
- edge 번호는 표에 고정해 둔다(생성 edge가 아니라 다시 매겨지지 않는다).
- 표의 행은 근거(sources·why)를 반드시 가진다. why에 다른 edge ID를 쓰지 않는다.
돌리기: python3 -I tools/dev/freight_hidden.py  (표를 고친 뒤 한 번. 결과 yaml을 함께 커밋한다)
"""
import json,os,sys,re,sqlite3
ROOT=os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
T=json.load(open(os.path.join(ROOT,'data','overrides','freight_hidden.json'),encoding='utf-8'))
SP=os.path.join(ROOT,'data','overrides','source_patch')
F='zz_f9_freight.yaml'  # 끝에 읽혀 기존 보정 행의 묶음 번호(station_group n)를 밀지 않는다
H='# 생성물: tools/dev/freight_hidden.py가 data/overrides/freight_hidden.json에서 만든다. 손으로 고치지 않는다\n'
out={m:[] for m in ('lines','routes','groups','nodes','names','positions','edges','km','events')}
seen_line={};nodes_new=set();eids=set()
def W(r,extra=''):
    return f"[F9 화물 {r['name']}] "+r['why']+(' / '+extra if extra else '')
for r in T['rows']:
    if not r.get('sources') or not r.get('why'):raise SystemExit(f"{r.get('route')}: sources·why가 없습니다")
    if re.search(r'e_\d{6}',r['why']):raise SystemExit(f"{r['route']}: why에 edge ID를 쓰지 않습니다")
    L=r['line']
    if L not in seen_line:
        seen_line[L]=r
        out['lines'].append(dict(id=L,name_ja=r['line_name'],type='rail',rule_class='hidden',family=r['family'],closed=True,
            gauge=[dict(gauge=r.get('gauge',1067),system='rail',source=r.get('gauge_src','모선과 같은 궤간'))],
            why=f"숨은 노선(여객 영업 이력이 없는 화물 지선 묶음, 모선 {r['parent']}). 화물 규칙 1(사용자 결정 2026-11-09)"))
        out['names'].append(dict(entity_type='line',id=L,lang='ja',text=r['line_name'],source='rule',why='숨은 노선 이름은 모선 이름+（貨物）. 앱에 나오지 않음'))
    path=r['path'];P=[p[0] for p in path]
    # 숨은 노선의 첫 계통은 본선, 나머지는 지선 계통(owned, 칸은 route_only로 그 계통 전용)이다
    main_=not any(x['line']==L for x in out['routes'])
    out['routes'].append(dict(id=r['route'],line=L,role='main' if main_ else 'branch',**({} if main_ else {'owned':True}),**{'from':P[0],'to':P[-1]},why=W(r)))
    for p in path:
        if len(p)>2 and p[2]:
            n=p[0];a=p[2]
            if n in nodes_new:continue
            nodes_new.add(n);g='g_'+n[2:]
            out['groups'].append(dict(id=g,why=W(r,f"{a['name']}: 화물역(숨은 노드)")))
            out['nodes'].append(dict(id=n,kind=a.get('kind','freight'),group=g,pref=str(a['pref']),export_name=a['name'],why=W(r,f"{a['name']}: 화물역(숨은 노드)")))
            out['names'].append(dict(entity_type='node',id=n,lang='ja',text=a['name'],source=a.get('name_src','wikipedia'),why=W(r,f"{a['name']}: 화물역 이름(정차한 적이 없어 앱에는 나오지 않음)")))
            if a.get('pos'):
                la,lo,src=a['pos']
                out['positions'].append(dict(node=n,lat=la,lon=lo,quality='approx',checked='2026-11-16',source=src,why=W(r,a.get('pos_why',''))))
    E=r['edges']
    if len(E)!=len(path)-1:raise SystemExit(f"{r['route']}: edge 수가 칸 수와 다릅니다")
    for i,e in enumerate(E):
        if e in eids:raise SystemExit(f'edge 번호 겹침 {e}')
        eids.add(e)
        a,b=path[i][0],path[i+1][0];k=round(path[i+1][1]-path[i][1],1)
        out['edges'].append(dict(id=e,a=a,b=b,seed_line=L,route_only=r['route'],why=W(r)))
        out['km'].append(dict(edge=e,km=k,source=r.get('km_src','wikipedia'),why=W(r)))
    # 사건: 칸마다 개업·폐지(칸별 날짜가 있으면 그것), 사업자 바뀜
    segs=r.get('seg_dates') or [[r['open'],r['close']]]*len(E)
    ops=r.get('operators') or [[None,'o_japanese_national_railways']]
    groups={}
    for e,(o,c) in zip(E,segs):groups.setdefault((o,c),[]).append(e)
    for (o,c),es in groups.items():
        op0=[x for x in ops if x[0] is None or x[0]<=o][-1][1]
        out['events'].append(dict(date=o,type='open',operator=op0,line=L,edges=es,route=r['route'],source=r.get('date_src','wikipedia'),why=W(r,'개업')))
        prev=op0
        for d,op in ops:
            if d is None or d<=o or (c and d>=c):continue
            out['events'].append(dict(date=d,type='transfer',edges=es,route=r['route'],source=r.get('date_src','wikipedia'),**{'from':dict(operator=prev,line=L),'to':dict(operator=op,line=L)},why=W(r,'사업자 바뀜')));prev=op
        if c:
            out['events'].append(dict(date=c,type='close',line=L,edges=es,route=r['route'],reason='abolished',legal_abolition=c,source=r.get('date_src','wikipedia'),why=W(r,'폐지')))
for m,rows in out.items():
    os.makedirs(os.path.join(SP,m),exist_ok=True)
    with open(os.path.join(SP,m,F),'w',encoding='utf-8') as f:
        f.write(H)
        for x in rows:f.write('- '+json.dumps(dict(patch='add',**x),ensure_ascii=False)+'\n')
print('freight_hidden',{m:len(v) for m,v in out.items()})
