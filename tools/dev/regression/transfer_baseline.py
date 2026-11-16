# -*- coding: utf-8 -*-
# 환승 키 기준판 (10회차 G1 chubu_3-018·kinki_1-11). 판 사이에 사유 없이 사라진 환승 키(계통|역|상대 노선)·환승 쌍(노드|노드)을 audit_db K172가 경고로 낸다.
# 쓰는 법: python3 -I tools/dev/regression/transfer_baseline.py write <기준판 master.sqlite> <판 이름>
#   기준판의 환승 키와 환승 쌍을 transfer_baseline.json에 쓴다. 이미 적은 「사유」는 그대로 둔다(새 기준판에 없는 키의 사유는 지운다)
# 일부러 뺀 키는 「사유」에 키 → 까닭(결정 기록의 판·갈래)을 적는다
import sys,os,json,sqlite3
HERE=os.path.dirname(os.path.abspath(__file__));P=os.path.join(HERE,'transfer_baseline.json')
if len(sys.argv)<4 or sys.argv[1]!='write':sys.exit('쓰는 법: transfer_baseline.py write <master.sqlite> <판>')
m=sqlite3.connect(sys.argv[2])
tr=sorted({f'{a}|{b}|{c}' for a,b,c in m.execute("select l.route_id,s.node_id,l.other_line_id from route_link l join route_stop s on s.route_id=l.route_id and s.seq=l.seq where l.kind='transfer'")})
hp=sorted({'|'.join(sorted(r)) for r in m.execute('select node_a,node_b from hub_pair')})
old=json.load(open(P,encoding='utf-8')) if os.path.exists(P) else {}
keep=set(tr)|set(hp)
why={k:v for k,v in (old.get('사유') or {}).items() if k in keep}
json.dump({'설명':'판 사이에 사라진 환승 키·환승 쌍 감시(audit_db K172). 사유가 없는 사라짐은 경고','판':sys.argv[3],'사유':why,'transfer':tr,'hub_pair':hp},open(P,'w',encoding='utf-8'),ensure_ascii=False,indent=0)
print('환승 키',len(tr),'환승 쌍',len(hp),'사유',len(why))
