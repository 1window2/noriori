# -*- coding: utf-8 -*-
# 서버 단계의 동기화 규칙 모델. v1.0에는 쓰이지 않는다 (docs/server-notes.md)
# 규칙마다 스위치가 있고 --mutate는 하나씩 꺼서 시험이 실패하는지 확인한다
import random,sys

RULES_B={
 'recv_clock':'받은 HLC로 시계 전진',
 'persist_hlc':'마지막 HLC를 저장',
 'pushed_sent':'응답 때 보낸 HLC만 기록',
 'hlc_compare':'서버는 높은 HLC만 유지',
 'undo_check':'되돌리기는 HLC가 같을 때만',
 'delete_slot':'삭제는 내용과 다른 슬롯',
 'import_min':'가져온 행의 첫 HLC는 최솟값',
 'import_dev':'최솟값 HLC에도 device_id 포함',
 'new_device':'OS 복원 뒤 새 device_id',
 'epoch_reset':'server_epoch가 바뀌면 전송 상태와 커서 초기화',
}
class Flags:
    def __init__(s,off=None):
        for k in RULES_B:setattr(s,k,k!=off)
F=Flags()

# ── 동기화 ───────────────────────────────────────────────
class Server:
    def __init__(s,epoch=0,seen=None):
        s.epoch=epoch;s.seq=0;s.slots={};s.seen=seen if seen is not None else {}
    def push(s,k,h,v):
        s.seen.setdefault(k,{})[h]=v                              # 시험용 기록. 서버의 일이 아니다
        if not F.hlc_compare or k not in s.slots or h>s.slots[k][1]:
            s.seq+=1;s.slots[k]=(s.seq,h,v)
    def pull(s,since):
        return [(k,x[1],x[2]) for k,x in s.slots.items() if x[0]>since]
class Dev:
    def __init__(s,name,pt):
        s.id=name;s.pt=pt;s.last=(0,0,'');s.slots={};s.pushed={};s.cursor=0;s.epoch=0;s.undo=[];s.n=0
    def tick(s):
        p=max(s.pt,s.last[0]);c=s.last[1]+1 if p==s.last[0] else 0
        s.last=(p,c,s.id);return s.last
    def write(s,k,v,bad):
        seen=s.slots[k][0] if k in s.slots else None
        h=s.tick();s.slots[k]=(h,v)
        if seen is not None and not h>seen:bad.append(('앞선 값보다 낮은 HLC',k))
        return h
    def dirty(s):return [k for k,(h,v) in s.slots.items() if s.pushed.get(k)!=h]
    def batch(s):return [(k,)+s.slots[k] for k in s.dirty()]
    def info(s,S):
        if s.epoch!=S.epoch:
            if F.epoch_reset:s.pushed.clear();s.cursor=0
            s.epoch=S.epoch
    def ack(s,batch):
        for k,h,v in batch:s.pushed[k]=h if F.pushed_sent else s.slots[k][0]
    def pull(s,S):
        rows=S.pull(s.cursor)
        for k,h,v in rows:
            if F.recv_clock:s.last=max(s.last,(h[0],h[1],s.id))
            if k not in s.slots or h>s.slots[k][0]:s.slots[k]=(h,v)
            if s.slots[k][0]==h:s.pushed[k]=h
        s.cursor=S.seq
    def sync(s,S):
        s.info(S);b=s.batch()
        for k,h,v in b:S.push(k,h,v)
        s.ack(b);s.pull(S)
    def imp(s,k,v):
        if k in s.slots:return
        h=(0,0,s.id if F.import_dev else '') if F.import_min else s.tick()
        s.slots[k]=(h,v)
    def delete(s,x,val,bad):
        if F.delete_slot:return s.write((x,'delete'),val,bad)
        return s.write((x,'content'),'삭제' if val else '복원',bad)
    def restart(s,r):
        s.undo=[];s.pt=max(0,s.pt-r.randint(0,6))
        if not F.persist_hlc:s.last=(0,0,'')
    def undo_last(s,bad):
        k,h,old=s.undo.pop()
        if s.slots[k][0]==h or not F.undo_check:s.write(k,old,bad)
    def keep(s):return (dict(s.slots),dict(s.pushed),s.cursor,s.last,s.pt)
    def restore(s,x):
        s.slots=dict(x[0]);s.pushed=dict(x[1]);s.cursor=x[2];s.last=x[3];s.pt=x[4];s.undo=[]
        if F.new_device:s.n+=1;s.id=f'{s.id[0]}{s.n}';s.last=(s.last[0],s.last[1],s.id)
def ride_view(d,x):
    c=d.slots.get((x,'content'));e=d.slots.get((x,'delete'))
    return (c and c[1],bool(e and e[1]))
def settle(D,S):
    for _ in range(3):
        for d in D:d.sync(S)
def final_check(D,S,bad):
    A,B=D
    assert not bad,bad[:2]
    assert A.slots==B.slots,'두 기기가 다름'
    assert not A.dirty() and not B.dirty(),'보낼 것이 남음'
    assert {k:x[1:] for k,x in S.slots.items()}=={k:v for k,v in A.slots.items()},'서버가 다름'
    for k,seen in S.seen.items():
        m=max(seen);assert A.slots[k]==(m,seen[m]),'가장 높은 HLC가 지지 않음'

def run_b(seed):
    r=random.Random(seed);mode=r.choice(['plain','plain','wipe','restore'])
    S=Server();A,B=Dev('A',10),Dev('B',13);D=[A,B];bad=[];fly=[];snap={}
    rides=['r1','r2'];excl=['x1','x2','x3']
    for x in rides:A.write((x,'content'),'v0',bad)
    for _ in range(60):
        d=r.choice(D);o=r.random();x=r.choice(rides);e=r.choice(excl);d.pt+=r.randint(0,2)
        if o<.18:
            k=(x,'content');h=d.write(k,f'{d.id}{d.pt}',bad);d.undo.append((k,h,'v0'))
        elif o<.26:d.delete(x,r.random()<.7,bad)
        elif o<.38:
            k=('excl',e);h=d.write(k,r.random()<.7,bad);d.undo.append((k,h,False))
        elif o<.46 and d.undo:d.undo_last(bad)
        elif o<.60:d.info(S);fly.append((d,d.batch()))
        elif o<.72 and fly:
            dv,b=fly.pop(r.randrange(len(fly)))
            for k,h,v in b:S.push(k,h,v)
            if r.random()<.75:dv.ack(b)                           # 응답 유실
        elif o<.84:
            d.info(S)
            if r.random()<.8:d.pull(S)
        elif o<.90:d.imp(('imp',r.randrange(2),'content'),d.id)
        elif o<.94:
            d.restart(r);fly=[f for f in fly if f[0] is not d]
        elif o<.97 and mode=='wipe':
            S=Server(S.epoch+1,S.seen);fly=[]
        elif o<.985 and mode=='restore' and d.id[0]=='B':
            if 'B' in snap:
                d.restore(snap['B']);fly=[f for f in fly if f[0] is not d]
        elif mode=='restore' and d.id[0]=='B':
            settle(D,S);snap['B']=d.keep()
    for dv,b in fly:
        for k,h,v in b:S.push(k,h,v)
    settle(D,S);final_check(D,S,bad)

def scripted_b():
    bad=[]
    # 지운 쪽과 더 늦게 고친 쪽: 삭제가 살고, 복원하면 고친 내용이 나온다
    S=Server();A,B=Dev('A',10),Dev('B',20);D=[A,B]
    A.write(('r','content'),'v0',bad);settle(D,S)
    A.delete('r',True,bad);B.write(('r','content'),'고침',bad);settle(D,S)
    assert ride_view(A,'r')==('고침',True),'삭제가 편집에 밀림'
    # 끄기 → 되돌리기 → 다시 끄기, 다른 기기의 더 늦은 끄기
    S=Server();A,B=Dev('A',10),Dev('B',20);D=[A,B];k=('excl','x')
    A.write(k,True,bad);A.write(k,False,bad);A.write(k,True,bad);settle(D,S)
    assert A.slots[k][1] is True,'다시 꺼지지 않음'
    A.write(k,False,bad);B.write(k,True,bad);settle(D,S)
    assert A.slots[k][1] is True,'늦은 끄기가 사라짐'
    # 가져온 뒤 고친 값은 다른 기기의 늦은 가져오기에 지지 않는다
    S=Server();A,B=Dev('A',10),Dev('B',50);D=[A,B];k=('imp',0,'content')
    A.imp(k,'원문');A.write(k,'고침',bad);B.imp(k,'원문');settle(D,S)
    assert A.slots[k][1]=='고침','가져오기가 수정을 덮음'
    # 서버를 잃어도 기기의 사본으로 복구된다
    S=Server();A,B=Dev('A',10),Dev('B',20);D=[A,B]
    A.write(('r','content'),'v0',bad);settle(D,S)
    S=Server(S.epoch+1);settle(D,S)
    assert ('r','content') in S.slots,'서버가 비었는데 다시 올리지 않음'
    # 내가 고친 뒤 다른 기기가 더 고쳤으면 내 되돌리기가 그 값을 덮지 않는다
    S=Server();A,B=Dev('A',10),Dev('B',20);D=[A,B];k=('r','content')
    A.write(k,'v0',bad);settle(D,S)
    A.undo.append((k,A.write(k,'내 값',bad),'v0'));settle(D,S)
    B.write(k,'남의 값',bad);settle(D,S)
    A.undo_last(bad);settle(D,S)
    assert A.slots[k][1]=='남의 값','되돌리기가 남의 수정을 덮음'
    # OS 복원 뒤 같은 시각에 다른 값을 써도 HLC가 겹치지 않는다
    S=Server();A,B=Dev('A',10),Dev('B',20);D=[A,B];k=('r','content')
    x=B.keep();B.write(k,'잃은 쪽',bad);settle(D,S)
    B.restore(x);B.write(k,'새 값',bad);settle(D,S)
    assert A.slots==B.slots,'같은 HLC에 다른 값'
    assert not bad,bad[:2]

def suite(n):
    for s in range(n):run_b(s)
    scripted_b()

if __name__=='__main__':
    if '--mutate' in sys.argv:
        suite(1500);lost=[]
        for k,text in RULES_B.items():
            F=Flags(k)
            try:suite(1500);lost.append(k);print('  못 잡음',k,text)
            except AssertionError as e:print('  잡음',k,'→',str(e)[:40])
        F=Flags();print('규칙',len(RULES_B),'못 잡음',len(lost));sys.exit(1 if lost else 0)
    n=int(sys.argv[1]) if len(sys.argv)>1 else 40000
    suite(n);print('동기화 임의 시나리오',n,'통과, 고정 시나리오 통과')
