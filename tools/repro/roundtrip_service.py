import sys,collections,random
sys.path.insert(0,sys.argv[1])
import appsim
from appsim import App
A=App();d=A.db;R=random.Random(7)
st=collections.Counter();ex2=[]
for sid,closed in d.execute('select id,closed from service').fetchall():
    for dd in (None,'1990-06-01','2010-06-01','2026-06-01'):
        hops,gaps=A.service_chain(sid,dd)
        if gaps:st['gap',sid,dd]+=1;continue
        ns=[h[1] for h in hops]+[hops[-1][3]]
        for _ in range(60):
            a,b=R.sample(ns,2)
            for direction in (('seq_up','seq_down') if closed else ('seq_up',)):
                x=A.expand_service(sid,a,b,dd,direction=direction)
                if x['status']!='ok':continue
                owner={}
                for r,es in x['legs'].items():
                    for e in es:owner[e]=r
                nodes=x['nodes'];edges=x['edges'];i=0;got=[];fail=None
                while i<len(edges):
                    j=i
                    while j+1<len(edges) and owner[edges[j+1]]==owner[edges[i]]:j+=1
                    y=A.record(owner[edges[i]],nodes[i],nodes[j+1],dd)
                    if y['status']!='ok':fail=(y['status'],y.get('reason'),owner[edges[i]],nodes[i],nodes[j+1]);break
                    got+=y['edges'];i=j+1
                if fail:st['실패',fail[0],fail[1]]+=1;ex2.append((sid,dd,fail));continue
                st['같음' if sorted(got)==sorted(edges) else '구간다름']+=1
print(st);print(ex2[:6])
