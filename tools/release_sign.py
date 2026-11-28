# -*- coding: utf-8 -*-
# 공개 릴리스의 데이터 팩 매니페스트에 서명한다 (ARCHITECTURE §4.4 판 릴리스 절차, §4.5).
# 팩과 매니페스트는 Release 워크플로가 만들어 빌드 증명(attestation)과 함께 릴리스에 올린다. 개인 키는 CI에 두지 않으므로 서명만 여기서 붙인다.
# 서명하기 전에 셋을 확인하고 하나라도 어긋나면 서명하지 않는다:
#   1. 릴리스의 팩 묶음과 매니페스트가 이 저장소 Release 워크플로가 만든 것이다(gh attestation verify).
#   2. 팩 파일마다 해시·크기가 매니페스트와 같다.
#   3. 같은 커밋으로 이 기기에서 만든 build/의 DB(pack-master.sqlite, names.sqlite)와 표마다 행 내용이 같다.
#      CI와 이 기기의 팩은 SQLite·타일 바이트가 달라 파일 해시로는 비교할 수 없고, 내용은 같다(2026-11-28 확인).
#   python3 -I tools/release_sign.py <태그> <개인 키.pem> [--upload] [--into-app]
#     --upload    서명 파일을 그 릴리스에 올린다(공개 게시)
#     --into-app  릴리스 팩과 서명을 앱 자산에 넣는다(이 기기에서 정식 APK를 만들 때 모든 배포물이 같은 팩을 쓰게)
import sys,os,json,glob,hashlib,shutil,sqlite3,subprocess,zipfile
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
import sign_manifest
def run(*a,**k):
    r=subprocess.run(a,capture_output=True,text=True,**k)
    if r.returncode:raise SystemExit(f'실패: {" ".join(a)}\n{(r.stderr or r.stdout)[-600:]}')
    return r.stdout
# 빌드 증명은 이 저장소의 Release 워크플로가 그 태그로 GitHub 호스트 러너에서 만든 것만 받는다. 저장소는 로컬 origin이 아니라 상수다(포크를 가리켜도 속지 않게)
REPO='1window2/noriori'
WORKFLOW=f'{REPO}/.github/workflows/release.yml'
def repo():return REPO
def sha(p):
    h=hashlib.sha256()
    with open(p,'rb') as f:
        for b in iter(lambda:f.read(1<<20),b''):h.update(b)
    return h.hexdigest()
def tables(db):
    c=sqlite3.connect(f'file:{db}?mode=ro',uri=True);out={}
    # FTS5 숨은 표(*_data·*_idx·*_docsize·*_config)는 SQLite 판과 병합 시점에 따라 바이트가 달라 내용 비교에서 뺀다. 검색 내용은 *_content가 담는다
    for (t,) in c.execute("select name from sqlite_master where type='table' and name not like 'sqlite_%' order by name"):
        if t.endswith(('_data','_idx','_docsize','_config')) and c.execute("select 1 from sqlite_master where type='table' and name=? and lower(sql) like '%virtual table%fts5%'",(t.rsplit('_',1)[0],)).fetchone():continue
        cols=[r[1] for r in c.execute(f'pragma table_info("{t}")')]
        h=hashlib.sha256();n=0
        for row in c.execute(f'select * from "{t}" order by '+','.join(f'"{x}"' for x in cols)):h.update(repr(row).encode());n+=1
        out[t]=(n,h.hexdigest())
    return out
def main(a):
    if len(a)<2:raise SystemExit(open(__file__,encoding='utf-8').read().split('\nimport')[0])
    tag,key=a[0],a[1];upload='--upload' in a;into='--into-app' in a
    if not os.path.isfile(key):raise SystemExit('개인 키 파일이 없습니다(NORIORI_MANIFEST_KEY 경로를 확인하세요)')
    # 3번 대조의 기준: build/가 그 태그 커밋에서 만든 판이어야 한다
    head=run('git','-C',ROOT,'rev-parse','HEAD').strip();tc=run('git','-C',ROOT,'rev-parse',tag+'^{commit}').strip()
    if head!=tc:raise SystemExit(f'지금 체크아웃({head[:8]})이 태그 {tag}({tc[:8]})가 아닙니다. 태그를 체크아웃하고 tools/all.sh를 돌린 뒤 하세요')
    if run('git','-C',ROOT,'status','--porcelain','--','data','tools','packages','apps/noriori/lib').strip():raise SystemExit('작업 트리에 커밋하지 않은 변경이 있습니다')
    d=os.path.join(ROOT,'build','release',tag);shutil.rmtree(d,ignore_errors=True);os.makedirs(d)
    run('gh','release','download',tag,'-R',repo(),'-p','manifest.json','-p','noriori-pack-*.zip','-D',d)
    zips=glob.glob(os.path.join(d,'noriori-pack-*.zip'))
    if len(zips)!=1:raise SystemExit(f'릴리스 {tag}에 팩 묶음이 하나가 아닙니다: {zips}')
    man=os.path.join(d,'manifest.json')
    # 1. 빌드 증명
    # 태그 이름(ref)뿐 아니라 그 태그 커밋에서 만든 것인지도 본다(태그를 옮긴 뒤 다시 서명하는 경우, 6회차 리뷰)
    for f in (zips[0],man):run('gh','attestation','verify',f,'-R',repo(),'--signer-workflow',WORKFLOW,'--source-ref',f'refs/tags/{tag}','--source-digest',tc,'--deny-self-hosted-runners')
    # 2. 파일 해시
    pk=os.path.join(d,'pack');zipfile.ZipFile(zips[0]).extractall(pk)
    if open(os.path.join(pk,'manifest.json'),'rb').read()!=open(man,'rb').read():raise SystemExit('묶음 안 매니페스트가 따로 올린 매니페스트와 다릅니다')
    m=json.load(open(man,encoding='utf-8'))
    for name,v in m['files'].items():
        p=os.path.join(pk,name)
        if not os.path.exists(p) or os.path.getsize(p)!=v['size'] or sha(p)!=v['sha256']:raise SystemExit(f'팩 파일이 매니페스트와 다릅니다: {name}')
    # 3. 같은 커밋 로컬 빌드와 DB 내용
    local=json.load(open(os.path.join(ROOT,'build','manifest.json'),encoding='utf-8'))
    if local['edition']!=m['edition']:raise SystemExit(f'판이 다릅니다: 로컬 {local["edition"]} / 릴리스 {m["edition"]}')
    for ours,theirs in (('pack-master.sqlite','master.sqlite'),('names.sqlite','names.sqlite')):
        A,B=tables(os.path.join(ROOT,'build',ours)),tables(os.path.join(pk,theirs))
        bad=[t for t in sorted(set(A)|set(B)) if A.get(t)!=B.get(t)]
        if bad:raise SystemExit(f'{theirs} 내용이 로컬 빌드와 다른 표: {bad[:10]}')
    # 서명하고 저장소 공개 키로 확인한다
    sign_manifest.sign(key,d)
    print(f'서명함: {man}.sig (판 {m["edition"]}, 빌드 증명·해시·DB 내용 확인)')
    if into:
        dst=os.path.join(ROOT,'apps','noriori','assets','pack');os.makedirs(dst,exist_ok=True)
        for f in glob.glob(os.path.join(dst,'*')):
            if os.path.isfile(f):os.remove(f)
        # 매니페스트가 적은 파일(해시 확인함)과 매니페스트만 넣는다
        for f in list(m['files'])+['manifest.json']:
            if f!=os.path.basename(f) or f.startswith('.'):raise SystemExit(f'매니페스트 파일 이름이 이상합니다: {f}')
            shutil.copy(os.path.join(pk,f),os.path.join(dst,f))
        shutil.copy(man+'.sig',dst);sign_manifest.verify(dst);print('앱 자산에 릴리스 팩과 서명을 넣음')
    if upload:
        run('gh','release','upload',tag,man+'.sig','-R',repo(),'--clobber');print(f'릴리스 {tag}에 manifest.json.sig를 올림')
    return 0
if __name__=='__main__':sys.exit(main(sys.argv[1:]))
