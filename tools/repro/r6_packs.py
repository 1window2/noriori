# 재현 6: 판 교체. 합성 기록을 원본 형태로 저장하고 옛 판과 변조 판에서 각각 펼쳐 비교한다.
import sys,copy,sqlite3,shutil,os,collections
sys.path.insert(0,sys.argv[1]);sys.path.insert(0,sys.argv[2]);P=sys.argv[3]
from appsim import App
from store_sim import *
A=App()
def pack(n):return App(master=os.path.join(P,n+'.sqlite'))
name=lambda n:A.name(n,None,None)
def show(tag,B,st,old=A):
    for k,r in st.rows.items():
        if r['deleted_at']:continue
        x=resolve(old,r);y=resolve(B,r)
        same=sorted(e for _,e in x['edges'])==sorted(e for _,e in y['edges'])
        print(f'  {tag} {k}: 옛 {x["status"]} {x["km"]}km 날짜 {x["date"]} → 새 {y["status"]} {y.get("reason") or ""} {y["km"]}km 날짜 {y["date"]} 구간같음={same}')
print('=== 1. 새 역 (split-edge) + 조각. 끼운 곳은 끈 구간 안')
B=pack('split');R='r_sassho_line';n=[s['node_id'] for s in A._stops[R]]
st=Store();r=st.add(R,n[0],n[12],'2024-06-01');cut(A,st,r,n[4],n[6])
print('  옛 판',totals(A,st)[:3],'새 판',totals(B,st)[:3])
s2=Store();r=s2.add(R,n[0],n[12],None);cut(A,s2,r,n[2],n[3])          # 날짜 모름, 끈 구간은 새 역 밖
print('  날짜 모름, 앞쪽을 끔: 옛',totals(A,s2)[:3],'새',totals(B,s2)[:3])
d=s2.rows[r+'-cut'];print('  삭제 조각 원본',d['legs'][0]['a'],d['legs'][0]['b'],'새 판에서 되살리면',resolve(B,d)['status'],resolve(B,d)['km'])
print('=== 2. 이설일 하루 정정: 날짜 모름 + 사용자가 "새 선로"로 답한 기록')
B=pack('relocate');R='r_agatsuma_line';st_=A._stops[R];a,b=st_[0]['node_id'],st_[-1]['node_id']
opts=A.relocation_options(R,a,b);print('  선택지',opts)
st=Store();r=st.add(R,a,b,None,as_of=opts[-1]['as_of']);show('새 선로 답',B,st)
print('  새 선로 답이 가리키는 날의 상태: 옛 판',A.life_on('e_001464',opts[-1]['as_of'])[0],A.life_on('e_001471',opts[-1]['as_of'])[0],'/ 새 판',B.life_on('e_001464',opts[-1]['as_of'])[0],B.life_on('e_001471',opts[-1]['as_of'])[0])
mid='2020-06-01'
st=Store();r=st.add(R,a,b,None,as_of=mid);show('가운데 날로 저장한 같은 답',B,st)
print('=== 3. 닫힌 계통 역 순서 반전: direction 저장 기록')
B=pack('reverse');
for R,i,j in (('r_sapporo_streetcar',3,12),('r_port_island_line',4,7),('r_oedo_line',5,20)):
    n=[s['node_id'] for s in A._stops[R]];a,b=n[i],n[j]
    for w in ('seq_up','seq_down'):
        x=A.expand(R,a,b,None,direction=w)
        st=Store();st.add(R,a,b,None,direction=w);show(A.line_name(A.routes[R]['line_id'])+' '+w,B,st)
print('=== 4-a. 폐지일이 늦춰짐: 날짜를 잃었던 기록이 되살아나는가 (2015-01-08 → 2019-04-01)')
B=pack('closure');R='r_hidaka_main_line';n=[s['node_id'] for s in A._stops[R]]
st=Store();st.add(R,n[0],n[-1],'2017-08-01');show('2017 기록',B,st)
print('=== 4-b. 폐지일 뒤 날짜를 가진 기록은 옛 판으로 돌아가도 원본이 유지되는가')
st=Store();st.add(R,n[0],n[-1],'2017-08-01');print('  원본 date_input',st.rows['R1']['date_input'])
print('=== 5. 역이 묘비가 됨: 기록과 조각')
B=pack('tomb');R='r_sassho_line';n=[s['node_id'] for s in A._stops[R]]
st=Store();r=st.add(R,n[0],n[12],'2024-06-01');cut(A,st,r,n[3],n[5])     # 조각 끝이 사라질 역(seq 5)
r2=st.add(R,n[0],n[12],'2024-06-01')                                      # 잘리지 않은 기록
print('  조각 끝',name(n[5]));show('묘비',B,st)
print('=== 6. 이관: 같은 사슬, 새 노선. 이관 뒤 날짜 기록')
B=pack('transfer');R='r_sassho_line';n=[s['node_id'] for s in A._stops[R]]
st=Store();r=st.add(R,n[0],n[12],'2026-10-20');k=st.add(R,n[0],n[12],None);j=st.add(R,n[0],n[12],'2026-09-01')
cut(A,st,r,n[4],n[6])
for c in('on','off'):print(' ',c,'옛',totals(A,st,c)[:3],'새',totals(B,st,c)[:3])
print('  노선별:',{i:sorted({l for l,_ in resolve(B,q)['edges']}) for i,q in st.rows.items() if not q['deleted_at']})
print('  분모 안 크레딧 확인(off):',len(totals(B,st,'off')[3]))
