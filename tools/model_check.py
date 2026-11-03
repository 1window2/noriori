# -*- coding: utf-8 -*-
# ARCHITECTURE §3의 로컬 규칙을 작은 모델로 시험한다. 앱 코드가 아니라 규칙 자체의 검증이다
# 규칙마다 스위치가 있고 --mutate는 하나씩 꺼서 시험이 실패하는지 확인한다. 안 실패하면 시험이 약한 것이다
# 모델에는 시간과 파일 크기가 없다. 실제 SQLite 동작은 store 시험에서 본다
import random,sys,copy

RULES={
 'atomic_save':'원본과 캐시를 한 트랜잭션에',
 'drop_deleted':'삭제한 기록의 캐시 제거',
 'row_isolate':'계산 못 하는 기록은 그 기록만 error',
 'rebuild_key':'캐시 키가 다르면 전체 재해석',
 'rebuild_atomic':'재해석은 한 트랜잭션',
 'pick_highest':'지원하는 팩 중 가장 높은 판',
 'pick_schema':'지원 안 하는 스키마의 팩은 고르지 않음',
 'check_header':'깨진 팩은 버리고 다시 고름',
 'verify_rename':'내려받은 팩은 해시 확인 뒤 이름 변경',
 'clean_tmp':'시작 때 임시 파일 삭제',
 'clean_packs':'쓰지 않는 팩 삭제',
 'merge_restore':'복원은 병합',
 'bump_delete':'삭제도 수정 시각을 올림',
 'migrate_keep':'마이그레이션이 실패하면 파일을 그대로 둠',
 'hold_quarantine':'격리 파일이 있으면 빈 DB로 넘어가지 않음',
 'backup_verify':'새 백업을 다시 읽어 확인한 뒤 회전',
 'rotate_noop':'옛 백업은 병합해도 바뀌는 게 없을 때만 지움',
 'rotate_readable':'읽지 못한 백업은 지우지 않음',
 'stamp_mono':'updated_at은 그 행에서 앞으로만 감',
 'undo_apply':'되돌리기도 새 변경으로 적용',
}
class Flags:
    def __init__(s,off=None):
        for k in RULES:setattr(s,k,k!=off)
F=Flags()

class Crash(Exception):pass
def drive(gen,chance):
    """gen의 yield마다 커밋 하나. chance()가 참이면 그 뒤에서 프로세스가 죽는다"""
    for _ in gen:
        if chance():raise Crash

class Disk:
    """강제 종료 뒤에도 남는 것"""
    def __init__(s):
        s.rows={};s.cache={};s.key=None              # user.sqlite. 행은 (값, updated_at, 삭제 여부, 실제 입력 순서)
        s.packs={};s.tmp=set()                       # datasets/. 팩은 dict(schema, whole, good)
        s.uver=1;s.corrupt=False;s.aside=None;s.folder=True  # user_version, 손상 여부, 격리 파일, 백업 위치
class World:
    def __init__(s):
        s.d=Disk();s.rules=1;s.schema=1;s.asset=1;s.pack=None;s.intent={};s.vers={};s.ed=1
        s.uver=1;s.migbad=False;s.locked=False       # 앱의 user_version, 이 릴리스의 마이그레이션이 실패하는가, 복원 전용 화면
        s.ext=[];s.backed={}                         # 앱을 지워도 남는 백업 폴더, 어떤 온전한 파일에 들어간 적 있는 값
        s.claim={};s.clock=0;s.seq=0;s.gen=0;s.last=None;s.snaps=[]  # 마지막 백업이 약속한 내용, 기기 시계, 실제 입력 순서, 새 ID 세대, 되돌릴 변경, 수동 백업
    def snap(s):
        d=s.d;return copy.deepcopy(dict(rows=d.rows,cache=d.cache,key=d.key,uver=d.uver))
    def expect(s,k,row):
        """있어야 할 원본을 규칙과 따로 계산한다. 기준은 시계가 아니라 사용자가 실제로 쓴 순서다"""
        if k not in s.vers or row[3]>s.vers[k]:s.intent[k]=row[0],row[2];s.vers[k]=row[3]

class BadRow(Exception):pass
def truth(row,pack,rules):
    return ('실패' if row[0]=='깨짐' else row[0],pack,rules)
def calc(row,pack,rules):
    if row[0]=='깨짐' and not F.row_isolate:raise BadRow
    return truth(row,pack,rules)

def apply(w,k,val,deleted=False):
    """RecordStore.apply: 원본과 그 기록의 캐시를 함께 쓴다"""
    d=w.d;w.clock+=1;w.seq+=1
    at=max(w.clock,d.rows[k][1]+1) if F.stamp_mono and k in d.rows else w.clock
    if deleted and not F.bump_delete:at=d.rows[k][1]
    row=(val,at,deleted,w.seq);w.expect(k,row);w.last=(k,d.rows.get(k))
    try:c=None if deleted else calc(row,w.pack,w.rules)
    except BadRow:return                                 # 트랜잭션 전체가 실패
    d.rows[k]=row
    if not F.atomic_save:yield
    if not deleted:d.cache[k]=c
    elif F.drop_deleted:d.cache.pop(k,None)
    yield
def undo(w):
    """5초 안의 되돌리기. 원래 행을 그대로 쓰면 그 사이 나간 백업이 복원 때 이긴다"""
    k,b=w.last;d=w.d
    if F.undo_apply:yield from apply(w,k,b[0],b[2])
    else:
        w.seq+=1;row=b[:3]+(w.seq,);w.expect(k,row);d.rows[k]=row
        if row[2]:d.cache.pop(k,None)
        else:d.cache[k]=calc(row,w.pack,w.rules)
        yield
    w.last=None
def rebuild(w,pack):
    d=w.d;new={}
    if not F.rebuild_atomic:d.key=(pack,w.rules);d.cache=new;yield
    for k,r in d.rows.items():
        if r[2]:continue
        try:new[k]=calc(r,pack,w.rules)
        except BadRow:return
        if not F.rebuild_atomic:yield
    d.cache=new;d.key=(pack,w.rules)
    yield
def pick(w):
    """저장된 상태값이 없다. 폴더와 앱 자산만 보고 고른다"""
    d=w.d;c=[w.asset]+[e for e,p in d.packs.items() if p['schema']==w.schema or not F.pick_schema]
    return max(c) if F.pick_highest else w.asset
def aside(d):
    d.aside=copy.deepcopy(d.rows);d.rows={};d.cache={};d.key=None
def start(w):
    d=w.d;w.pack=None;w.locked=False
    if d.corrupt:aside(d);d.corrupt=False;d.uver=w.uver;yield
    if d.aside is not None and F.hold_quarantine:w.locked=True;return
    if d.uver<w.uver:
        if w.migbad:
            if not F.migrate_keep:aside(d);d.uver=w.uver;yield
            w.locked=True;return
        d.uver=w.uver;d.cache={};d.key=None;yield        # 마이그레이션은 한 트랜잭션
    if F.clean_tmp:d.tmp.clear();yield
    while True:
        e=pick(w)
        if e==w.asset and e not in d.packs:
            d.tmp.add(e);yield
            d.tmp.discard(e);d.packs[e]=dict(schema=w.schema,whole=True,good=True);yield
        if F.check_header and not d.packs[e]['whole']:del d.packs[e];yield;continue
        break
    if F.rebuild_key and d.key!=(e,w.rules):yield from rebuild(w,e)
    w.pack=e
    yield                                                # 화면
    if F.clean_packs:
        for x in list(d.packs):
            if x!=e:del d.packs[x]
        yield
def download(w,e,good=True):
    """폴더에 넣는 것까지만 한다. 적용은 다음 시작"""
    d=w.d;d.tmp.add(e);yield
    if F.verify_rename and not good:d.tmp.discard(e);return
    d.tmp.discard(e);d.packs[e]=dict(schema=w.schema,whole=True,good=good);yield
def download_cut(w,e):
    """이름 변경 뒤에 파일이 깎인 경우. 크기 검사가 잡아야 한다"""
    w.d.packs[e]=dict(schema=w.schema,whole=False,good=False);yield

def merge_noop(w,f):
    d=w.d
    return all(k in d.rows and d.rows[k][1]>=r[1] for k,r in f['rows'].items())
def autobackup(w,good=True):
    """쓰고, 다시 읽어 확인하고, 병합해도 바뀌는 게 없는 옛 파일만 지운다"""
    d=w.d
    if not d.folder:return
    f=dict(rows=copy.deepcopy(d.rows),whole=good,avail=True);w.ext.append(f);yield
    if not good and F.backup_verify:w.ext.remove(f);yield;return
    w.claim={k:r[1] for k,r in d.rows.items()}           # 설정 화면의 마지막 백업 시각이 약속하는 내용
    if good:
        for k,r in d.rows.items():w.backed[k]=max(w.backed.get(k,0),r[1])
    ok=lambda x:x['whole'] and x['avail']                # 앱이 아는 것은 지금 읽혔는지뿐이다
    while sum(map(ok,w.ext))>3:
        old=w.ext[:-1]
        c=[x for x in old if ok(x) and merge_noop(w,x) or not ok(x) and not F.rotate_readable] if F.rotate_noop else old
        if not c:break
        w.ext.remove(c[0]);yield
def reinstall(w):
    """앱 폴더가 통째로 사라지고 백업 폴더만 남는다. 같은 폴더를 골랐지만 복원은 아직 안 했다"""
    w.d=Disk();w.d.uver=w.uver;w.intent={};w.vers={};w.gen+=1;w.last=None

def stale(w,k):
    """§3.7의 예외: 로컬 행이 파일보다 옛것이고 고칠 시각도 그 사본보다 작으면 병합에서 진다. 규칙 밖으로 둔다"""
    d=w.d;at=max(w.clock+1,d.rows[k][1]+1 if k in d.rows else 0)
    return any(k in f['rows'] and f['rows'][k][1]>=at for f in w.ext+w.snaps)
def boot(w,chance=lambda:False):
    n=0
    while True:
        try:drive(start(w),chance if n<6 else (lambda:False));break
        except Crash:n+=1
    assert w.d.aside is None or w.locked,'격리 파일을 잊음'
def best(w):
    """있어야 할 팩을 규칙과 따로 계산한다"""
    return max([w.asset]+[e for e,x in w.d.packs.items() if x['schema']==w.schema and x['whole']])
def check(w,want):
    d=w.d;p=w.pack
    assert p is not None,'시작이 끝나지 않음'
    assert p==want,'가장 높은 팩을 고르지 않음'
    assert p in d.packs,'고른 팩 없음'
    assert d.packs[p]['schema']==w.schema,'지원 안 하는 스키마'
    assert d.packs[p]['whole'] and d.packs[p]['good'],'깨진 팩'
    assert d.key==(p,w.rules),'캐시 키'
    assert d.cache=={k:truth(r,p,w.rules) for k,r in d.rows.items() if not r[2]},'캐시가 원본과 다름'
    assert {k:(r[0],r[2]) for k,r in d.rows.items()}==w.intent,'기록 유실'
    for k,v in w.backed.items():
        got=[d.rows[k][1]] if k in d.rows else []
        got+=[f['rows'][k][1] for f in w.ext if f['whole'] and k in f['rows']]
        assert max(got,default=0)>=v,'백업의 기록 유실'
    for k,v in w.claim.items():
        assert any(f['whole'] and k in f['rows'] and f['rows'][k][1]>=v for f in w.ext),'마지막 백업 시각이 거짓'
    assert not d.tmp,'묵은 임시 파일'
    assert set(d.packs)=={p},'묵은 팩'

def script(w):
    """저장, 내려받기, 깨진 값, 삭제, 앱 내 재시작, 다시 저장"""
    yield from apply(w,'a',1)
    yield from apply(w,'b',1)
    yield from autobackup(w)
    w.ed+=1;yield from download(w,w.ed)
    yield from apply(w,'c','깨짐')
    yield from apply(w,'b',1,deleted=True)
    yield from start(w)
    yield from apply(w,'a',2)
    for _ in range(3):yield from autobackup(w)
def exhaustive():
    """모든 커밋 뒤에서 죽고, 그 뒤 시작의 모든 커밋 뒤에서 또 죽는다"""
    n=0
    w=World();boot(w);total=sum(1 for _ in script(w))
    for i in range(total+1):
        for j in range(10):
            w=World();boot(w);c=[0];e=[0]
            def ci():c[0]+=1;return c[0]==i+1
            def cj():e[0]+=1;return e[0]==j+1
            try:drive(script(w),ci)
            except Crash:pass
            try:drive(start(w),cj)
            except Crash:pass
            want=best(w);boot(w);check(w,want);n+=1
    return n

def run(seed):
    r=random.Random(seed);w=World();snaps=w.snaps=[w.snap()]
    chance=lambda:r.random()<.07
    boot(w,chance)
    def do(gen):
        try:drive(gen,chance)
        except Crash:boot(w,chance)
    for _ in range(40):
        o=r.random();k=r.choice('abcdef')+str(w.gen);d=w.d
        if w.locked:                                     # 복원 전용 화면
            if d.aside is not None:d.aside=None          # 사용자가 격리 파일을 내보내고 닫음
            else:w.migbad=False                          # 고침 릴리스
            boot(w,chance);continue
        if stale(w,k):continue
        if r.random()<.22:
            p=r.random()
            if p<.42:do(autobackup(w,good=r.random()<.7))
            elif p<.52:reinstall(w);boot(w,chance)
            elif p<.6:w.uver+=1;w.migbad=r.random()<.5;boot(w,chance)
            elif p<.68:d.corrupt=True;w.intent={};w.vers={};w.gen+=1;w.last=None;boot(w,chance)
            elif p<.78:                                  # 시계가 되돌아가거나 앞서 감
                w.clock=max(0,w.clock+r.choice((-40,-8,30)))
            elif p<.9:
                if w.last and w.last[1] and not stale(w,w.last[0]):do(undo(w))
            elif w.ext:                                  # 구름 자리표시자나 더 새로운 스키마처럼 지금은 읽지 못하는 파일
                f=r.choice(w.ext);f['avail']=not f['avail']
            continue
        if o<.32:do(apply(w,k,r.randrange(1000)))
        elif o<.38:do(apply(w,k,'깨짐'))
        elif o<.46 and k in d.rows:do(apply(w,k,d.rows[k][0],deleted=True))
        elif o<.54:snaps.append(w.snap())
        elif o<.62:
            w.ed+=1;do(download(w,w.ed,good=r.random()<.8))
        elif o<.66:
            w.ed+=1;do(download_cut(w,w.ed))
        elif o<.74:boot(w,chance)
        elif o<.80:                                      # JSON 복원
            src=r.choice(snaps)['rows']
            good=[f for f in w.ext if f['whole'] and f['avail']]
            if good and r.random()<.5:src=r.choice(good)['rows']
            def job():
                if F.merge_restore:
                    for x,row in src.items():
                        w.expect(x,row)
                        if x not in d.rows or row[1]>d.rows[x][1]:
                            d.rows[x]=row
                            if row[2]:d.cache.pop(x,None)
                            else:d.cache[x]=calc(row,w.pack,w.rules)
                else:
                    for x,row in src.items():w.expect(x,row)
                    d.rows=copy.deepcopy(src);d.cache={x:calc(v,w.pack,w.rules) for x,v in d.rows.items() if not v[2]}
                yield
            try:do(job())
            except BadRow:return True
        elif o<.86:                                      # OS 복원: user.sqlite만 옛 시점으로, 팩 폴더는 없음
            s=r.choice(snaps);d.rows=copy.deepcopy(s['rows']);d.cache=copy.deepcopy(s['cache']);d.key=s['key'];d.uver=s['uver']
            d.packs={};d.tmp=set()
            w.intent={x:(v[0],v[2]) for x,v in d.rows.items()};w.vers={x:v[3] for x,v in d.rows.items()};w.last=None
            boot(w,chance)
        elif o<.93:w.rules+=1;boot(w,chance)             # 규칙이 바뀐 앱 갱신
        else:                                            # 스키마가 바뀐 앱 갱신. 새 자산 팩 포함
            if r.random()<.5:                            # 앱이 빌드된 뒤 옛 스키마 팩을 먼저 내려받은 경우
                w.ed+=2;d.packs[w.ed]=dict(schema=w.schema,whole=True,good=True);w.asset=w.ed-1
            else:w.ed+=1;w.asset=w.ed
            w.schema+=1;boot(w,chance)
    w.migbad=False;boot(w)
    if w.locked:w.d.aside=None;boot(w)
    want=best(w);boot(w);check(w,want)
    return True

def suite(n):
    for s in range(n):run(s)
    return exhaustive()

if __name__=='__main__':
    if '--mutate' in sys.argv:
        suite(1500);lost=[]
        for k,text in RULES.items():
            F=Flags(k)
            try:suite(1500);lost.append(k);print('  못 잡음',k,text)
            except AssertionError as e:print('  잡음',k,'→',str(e)[:40])
        F=Flags();print('규칙',len(RULES),'못 잡음',len(lost));sys.exit(1 if lost else 0)
    n=int(sys.argv[1]) if len(sys.argv)>1 else 40000
    c=suite(n);print('로컬 임의 시나리오',n,'통과, 강제 종료 2회 조합',c,'통과')
