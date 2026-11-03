# 문서의 저장 규칙을 실제 데이터 위에서 흉내 낸 작은 저장소. 판(App)을 바꿔 끼워 재해석을 비교한다.
import copy,uuid
class Store:
    def __init__(s):s.rows={};s.t=1000
    def tick(s):s.t+=1;return s.t
    def add(s,route,a,b,date=None,direction=None,as_of=None,unknown=False,alighted=(True,True),rid=None):
        rid=rid or f'R{len(s.rows)+1}'
        s.rows[rid]=dict(id=rid,date_input=date,created_at=s.tick(),updated_at=s.t,deleted_at=None,alighted=list(alighted),
             legs=[dict(route=route,a=a,b=b,direction=direction,as_of=as_of,unknown=unknown)],note='')
        return rid
def resolve(A,r):
    """원본만으로 펼친다. 재해석과 저장이 같은 함수"""
    edges=[];nodes=[];status='ok';date=r['date_input'];km=0
    for l in r['legs']:
        x=A.record(l['route'],l['a'],l['b'],r['date_input'],l['direction'],l['as_of'],l['unknown'])
        if x['status'] not in('ok','partial'):return dict(status=x['status'],reason=x.get('reason'),edges=[],km=0,date=None,nodes=[])
        if x['status']=='partial':status='partial'
        if x.get('demoted'):date=None
        line=A.ride_of(x,x.get('saved_date'))['edges']
        edges+=line;nodes+=x.get('nodes',[]);km+=x['km']
    return dict(status=status,edges=edges,km=round(km,1),date=date,nodes=nodes)
def cut(A,st,rid,x,y):
    """§3.4 cutSection. 단일 leg 기록용. x,y는 경로 위의 노드"""
    r=st.rows[rid];res=resolve(A,r);n=res['nodes'];i,j=sorted((n.index(x),n.index(y)))
    leg=r['legs'][0];now=st.tick()
    parts=[]
    if i>0:parts.append((n[0],n[i],(r['alighted'][0],False)))
    if j<len(n)-1:parts.append((n[j],n[-1],(False,r['alighted'][1])))
    before=copy.deepcopy(r)
    def mk(a,b,al,new_id=None,deleted=False):
        q=copy.deepcopy(r);q['legs']=[dict(leg,a=a,b=b)];q['alighted']=list(al);q['updated_at']=now
        if new_id:q['id']=new_id
        if deleted:q['deleted_at']=now
        st.rows[q['id']]=q
    if parts:
        mk(*parts[0])
        if len(parts)>1:mk(*parts[1],new_id=rid+'-rear')
    else:r['deleted_at']=now;r['updated_at']=now
    mk(n[i],n[j],(False,False),new_id=rid+'-cut',deleted=True)
    return before
def merge(st,file):
    """§3.7 복원"""
    ch=[]
    for k,row in file.items():
        if k not in st.rows or row['updated_at']>st.rows[k]['updated_at']:
            st.rows[k]=copy.deepcopy(row);ch.append(k)
    return ch
def totals(A,st,carry='on'):
    km=0;units={};by={}
    for k,r in st.rows.items():
        if r['deleted_at']:continue
        x=resolve(A,r);by[k]=(x['status'],x['km'],x['date'])
        if x['status'] in('ok','partial'):
            km+=x['km']
            for l,e in x['edges']:
                u=A.unit_of(l,e,carry)
                if u:units[u]=A.km[e]
    return round(km,1),round(sum(units.values()),1),len(units),by
