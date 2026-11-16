# -*- coding: utf-8 -*-
# 전수 대조 1·2회차 지적을 기계로 판정할 수 있는 사례표(cases.json)로 바꾼다 (2회차 종합 K34)
# 쓰는 법: python3 -I tools/dev/regression/make_cases.py 1회차_findings.json 2회차_findings.json 2회차_synthesis.json [build 폴더]
# 지적 파일은 저장소 밖 작업 폴더에 있다. 사례는 두 가지다
#   값 사례: 2회차 종합의 보정 값(data_fixes)이 DB에 실렸는가 (이름 행·정차 기간·이전 쌍·환승 쌍·임시역 표식·열람 전용 역·km·노선 이름)
#   검사 사례: 지적 대상(노드·계통·edge)을 그 원인의 기계 검사(build/audit.json·audit_ext.json)가 지금 잡는가. 고치면 빠져야 한다
# 보정 값이 확인 필요(confirm)이거나 자리표시(「(앞 역)」 같은)인 것, 사건·생성 규칙을 고쳐야 하는 것은 넣지 않는다
import sys,os,json,re,collections
HERE=os.path.dirname(os.path.abspath(__file__));ROOT=os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
R1,R2,SY=sys.argv[1:4];B=sys.argv[4] if len(sys.argv)>4 else os.path.join(ROOT,'build')
f1=json.load(open(R1,encoding='utf-8'));f2=json.load(open(R2,encoding='utf-8'));sy=json.load(open(SY,encoding='utf-8'))
ID=re.compile(r'^(?:n|r|l|e|a|o|hub)_[0-9a-z_]+$')
def real(x):return isinstance(x,str) and bool(ID.match(x))
cause=dict(sy['finding_index'])
# 규칙상 정상(종합 §1.1)과 U17 「노리츠부시 유지」로 닫히는 조건부 정상: 대조하지 않고 사유만 남긴다
normal={x['id']:x['why'] for x in sy['rule_normal']}
for i in ('kanto_2-058','kanto_2-059','kanto_2-060','kinki_1-027','kinki_1-034','kinki_1-035','kinki_3-002','kinki_3-028','hokkaido_1-013'):
    normal.setdefault(i,'U17 노리츠부시와 위키 km 0.1 차이는 노리츠부시 유지(§2.7, 사업자 공표가 반박할 때만 바꿈)')
cases=[]
def add(fid,rnd,kind,**kw):
    c=dict(id=fid,round=rnd,cause=cause.get(fid),kind=kind,**kw)
    if rnd==2 and fid in normal:c['normal']=normal[fid]
    cases.append(c)
# ---- 값 사례 (2회차 보정 값)
for f,rows in sy['data_fixes_by_file'].items():
    base=f.split('/')[-1]
    for x in rows:
        if x['op']=='confirm':continue
        fid=x['finding'];v=x['value']
        try:
            if base=='renames_hand.json':
                for nd,ls in v.items():
                    for r_ in ls:
                        if real(nd) and r_[0]:add(fid,2,'name',node=nd,text=r_[0],valid_to=r_[2],line=r_[3] if len(r_)>3 else None)
            elif base in('old_names_fix.json',):
                for k,r_ in v.items():
                    nd=k.split('|')[0]
                    if real(nd) and isinstance(r_,list):add(fid,2,'name',node=nd,text=r_[0],valid_from=r_[1],valid_to=r_[2])
            elif base in('old_names_kana.json','old_names.json'):
                for k,r_ in v.items():
                    nd,_,t=k.partition('|')
                    if real(nd) and t and r_.get('kana'):add(fid,2,'kana',node=nd,text=t,kana=r_['kana'])
            elif base=='stop_dates.json':
                for k,r_ in v.items():
                    a,_,b=k.partition('|');rt,nd=(a,b) if b else (None,a)
                    if not (real(nd) and (rt is None or real(rt)) and r_ and (r_[0] or r_[1])):continue
                    # 정차 기간이 둘 이상이면 값이 [[시작, 끝], ...]이다. 시작·끝 목록으로 읽으면 판정할 수 없다
                    if isinstance(r_[0],list):add(fid,2,'stop',route=rt,node=nd,periods=r_)
                    else:add(fid,2,'stop',route=rt,node=nd,valid_from=r_[0],valid_to=r_[1])
            elif base=='moved.json':
                for r_ in v:
                    if real(r_.get('new')) and r_.get('date'):add(fid,2,'moved',new=r_['new'],old=r_['old'] if real(r_.get('old')) else None,date=r_['date'])
            elif base=='stop_status.json' and x['op']=='add':
                for r_ in v:
                    if real(r_.get('node')):add(fid,2,'mark',node=r_['node'],mark=r_.get('kind'),valid_from=r_.get('from'),valid_to=r_.get('to'))
            elif base=='hub_join.json':
                for r_ in (v if isinstance(v,list) else [v]):
                    if real(r_.get('node')) and real(r_.get('with')):add(fid,2,'hub',a=r_['node'],b=r_['with'])
            elif base=='hub_not.json':
                for r_ in (v if isinstance(v,list) else [v]):
                    if real(r_.get('node')) and real(r_.get('with')):add(fid,2,'nohub',a=r_['node'],b=r_['with'])
            elif base=='hub_split.json':
                for r_ in (v if isinstance(v,list) else [v]):
                    if real(r_.get('node')) and real(r_.get('from')):add(fid,2,'nogroup',a=r_['node'],b=r_['from'])
            elif base=='archive_fix.json' and x['op']=='set':
                for nm_,r_ in v.items():
                    if isinstance(r_,dict) and real(r_.get('route')):add(fid,2,'archive',name=nm_,route=r_['route'],after=r_.get('after') if real(r_.get('after')) else None,before=r_.get('before') if real(r_.get('before')) else None,km=r_.get('km') if isinstance(r_.get('km'),(int,float)) else None)
            elif base=='km_fix.json':
                for r_ in v:
                    if real(r_.get('a')) and real(r_.get('b')) and isinstance(r_.get('km'),(int,float)):add(fid,2,'edgekm',a=r_['a'],b=r_['b'],km=r_['km'])
            elif base in('node_fix.json','names_ko.json'):
                for nd,r_ in v.items():
                    if not real(nd):continue
                    if isinstance(r_,str):r_={'ko':r_}
                    for lg in('ja','ko','en'):
                        if isinstance(r_.get(lg),str):add(fid,2,'nodename',node=nd,lang=lg,text=r_[lg])
                    if isinstance(r_.get('kana'),str):add(fid,2,'nodename',node=nd,lang='kana',text=r_['kana'])
            elif base in('lines_en.json','lines_ko.json','lines_ja.json'):
                for l,t in v.items():
                    if real(l):add(fid,2,'linename',line=l,lang=base[6:8],text=t)
            elif base=='line_history.json':
                for r_ in (v if isinstance(v,list) else [v]):
                    if real(r_.get('line')) and r_.get('kind')=='name':add(fid,2,'lineperiod',line=r_['line'],name=r_['name_ja'],valid_from=r_['valid_from'])
            elif base=='positions' and x['op']=='add':
                for r_ in (v if isinstance(v,list) else [v]):
                    if real(r_.get('node')) and isinstance(r_.get('lat'),(int,float)) and isinstance(r_.get('lon'),(int,float)):add(fid,2,'pos',node=r_['node'],lat=r_['lat'],lon=r_['lon'])
            elif base=='removed.json':
                for nd in v:
                    if real(nd):add(fid,2,'absent',node=nd)
        except (AttributeError,TypeError,KeyError,IndexError):pass
# ---- 검사 사례: 지적 대상을 그 원인의 검사가 지금 잡는가
CAT={'branch':'K01 K02 K03 K05 K10','through':'K01 K02 K03 K04 K05','false_transfer':'K02 K06 K07','missing_transfer':'K06 K08','transfer':'K06 K07 K08',
     'parallel':'K09','station_name':'K11 K12 K13 K14 K15 K16 K17 K25','kana':'K13 K17','ko_en':'K13 K14 K16 K17','type_format':'K16 K17',
     'date':'K18 K19 K26 K35','temp_stop':'K18 K21 K26','status':'K18 K26 K35','km':'K20 K21 K22 K23 K36','moved_station':'K19 K25',
     'missing_station':'K24 K27 K28','extra_station':'K10 K24','station_list':'K10 K24 K27 K28','position':'K29 K37','duplicate':'K08 K11 K25','cross_table':'K24 K29'}
CH={}
for fn in('audit.json','audit_ext.json'):
    p=os.path.join(B,fn)
    if os.path.exists(p):
        for k,v in json.load(open(p,encoding='utf-8')).items():
            if v.get('lvl') in('err','warn') and v.get('n'):CH[k]=set(v.get('ids',[]))
for rnd,fs in((1,f1),(2,f2)):
    for x in fs:
        ks=[cause[x['id']]] if rnd==2 and x['id'] in cause else CAT.get(x['category'],'').split()
        ent=next((x[k] for k in('node','route','edge') if real(x.get(k))),None)
        if not ent or not ks:continue
        hit=sorted(k for k,v in CH.items() if k[:3] in ks and ent in v)
        if hit:
            c=dict(id=x['id'],round=rnd,cause=cause.get(x['id']) if rnd==2 else None,cat=x['category'],kind='check',ids=[ent],checks=hit)
            # 지적 id는 회차마다 따로 매긴다(1회차 kanto_2-006과 2회차 kanto_2-006은 다른 지적). 규칙상 정상 판정은 2회차 것이다
            if rnd==2 and x['id'] in normal:c['normal']=normal[x['id']]
            cases.append(c)
out=dict(설명='전수 대조 1·2회차 지적의 회귀 대조표 (2회차 종합 K34). tools/dev/regression/run.py가 빌드 뒤 대조해 아직 남은 사례를 센다. '
         'kind: name·kana·nodename(이름 행), stop(정차 기간, 기간이 둘 이상이면 periods), moved(이전 쌍), mark(임시역 표식), hub·nohub·nogroup(환승 쌍·group), archive(열람 전용 역), edgekm(칸 km), '
         'linename·lineperiod(노선 이름), pos(좌표), absent(지운 노드), check(그 원인 검사가 대상을 더는 잡지 않음), nolink(그 역에서 두 노선 쌍 분기·끝 이어짐 없음, 손으로 바꾼 거짓 연결 지적). '
         '「(…)」로 적힌 기대값은 자리표시라 그쪽은 판정하지 않는다. normal이 있는 사례는 규칙상 정상이라 세지 않는다. '
         '의도적으로 고치지 않는 사례는 normal에 사유를 적는다. check 사례가 사용자 결정이 허용한 경고 검사(run.py RULE_OK)에만 걸리면 규칙상 정상이고 basis에 원문 대조 근거를 적는다',
         만든_방법='tools/dev/regression/make_cases.py (지적 파일과 그때 빌드의 audit.json·audit_ext.json으로 만든다)',
         cases=cases)
json.dump(out,open(os.path.join(HERE,'cases.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=0)
c=collections.Counter((x['round'],x['kind']) for x in cases)
print('사례',len(cases),dict(sorted(c.items())))
