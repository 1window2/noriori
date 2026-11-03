# -*- coding: utf-8 -*-
import sys,sqlite3,collections
sys.path.insert(0,'tools')
from lib import *
got={g['edge'] for g in load('geometry')}
db=sqlite3.connect('build/master.sqlite')
A=collections.defaultdict(lambda:[0,0,0.0,0.0])
for e,km,cur in db.execute("select e.id,k.km,exists(select 1 from edge_attr a where a.edge_id=e.id and a.valid_to='ongoing') from edge e join edge_km k on k.edge_id=e.id"):
    c='current' if cur else 'closed'
    A[c][0]+=1;A[c][2]+=km
    if e in got:A[c][1]+=1;A[c][3]+=km
for k,v in A.items():print(k,v[0],v[1],round(v[1]/v[0],3),'km',round(v[2]),round(v[3]),round(v[3]/max(v[2],1),3))
