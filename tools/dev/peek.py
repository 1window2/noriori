# -*- coding: utf-8 -*-
# 계통 하나를 사람이 읽는 형태로 보여 준다: python3 tools/dev/peek.py 노선일본어이름 [개수]
import sqlite3,sys,json
m=sqlite3.connect('build/master.sqlite');n=sqlite3.connect('build/names.sqlite')
nm=sys.argv[1];lim=int(sys.argv[2]) if len(sys.argv)>2 else 14
ko={};ja={}
for t,i,l,x in n.execute("select entity_type,entity_id,lang,text from name where source is not 'x' and (lang='ko' or lang='ja')"):
    if l=='ko':ko[(t,i)]=x
    else:ja.setdefault((t,i),x)
for (i,) in n.execute("select distinct entity_id from name where entity_type='line' and lang='ja' and text=?",(nm,)):
    print('LINE',i,ko.get(('line',i)))
    for r,fr,to,role in m.execute('select id,from_node,to_node,role from route where line_id=?',(i,)):
        rows=m.execute('select seq,node_id,km_cum,is_stop,valid_from,valid_to from route_stop where route_id=? order by seq',(r,)).fetchall()
        print(' ROUTE',r,role,len(rows),'stops')
        sel=rows if len(rows)<=lim else rows[:lim//2]+rows[-lim//2:]
        for s,nd,k,st,vf,vt in sel:
            print('   ',s,ja.get(('node',nd)),ko.get(('node',nd)),k,'stop' if st else 'pass',vf,vt)
    ops=m.execute('select operator_id,count(*),min(valid_from),max(valid_to) from edge_attr where line_id=? group by operator_id',(i,)).fetchall()
    print(' OPS',ops)
