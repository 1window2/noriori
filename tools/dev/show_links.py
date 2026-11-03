# -*- coding: utf-8 -*-
# 역의 환승·분기 행을 사람이 읽기 좋게 보여 준다. 사용법: python3 -I tools/dev/show_links.py 大宮 宇治山田
import sqlite3,sys,os
ROOT=os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
m=sqlite3.connect(os.path.join(ROOT,'build','master.sqlite'));n=sqlite3.connect(os.path.join(ROOT,'build','names.sqlite'))
ja={}
for i,t in n.execute("select entity_id,text from name where entity_type='node' and lang='ja'"):ja.setdefault(i,t)
ln=dict(n.execute("select entity_id,text from name where entity_type='line' and lang='ja'").fetchall())
for q in sys.argv[1:]:
    for i, in n.execute("select distinct entity_id from name where entity_type='node' and lang='ja' and text=?",(q,)):
        for r,seq,vt,line in m.execute("select s.route_id,s.seq,s.valid_to,r.line_id from route_stop s join route r on r.id=s.route_id where s.node_id=? and s.is_stop=1",(i,)):
            print(q,i,'[',ln.get(line),vt,']')
            for k,ol,oroute,side,on,nx,te,fl,vf,vt2 in m.execute("select kind,other_line_id,other_route_id,side,other_node,next_stop_node,terminal_node,flow,valid_from,valid_to from route_link where route_id=? and seq=? order by kind",(r,seq)):
                print('    ',k,ln.get(ol),'route' if ol==line else '',side or '',('('+ja.get(on,on)+')') if on else '',ja.get(nx,nx),'›',ja.get(te,te),fl or '',vf,vt2)
