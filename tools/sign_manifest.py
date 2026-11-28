# -*- coding: utf-8 -*-
# 데이터 팩 매니페스트(manifest.json)에 ed25519 서명을 붙이고 확인한다 (DESIGN §2.11, ARCHITECTURE §4.5).
# 개인 키는 저장소와 CI에 두지 않는다. 판을 내는 사람이 오프라인 보관 장소의 키로 서명한다.
# 공개 키는 data/keys/manifest-ed25519-*.pub.pem 이고 앱에도 같은 값이 들어 있다(packages/noriori_store/lib/src/pack/pack_signature.dart).
#   python3 -I tools/sign_manifest.py sign <개인 키.pem> [폴더]   폴더(기본 build)의 manifest.json에 서명해 manifest.json.sig를 쓴다
#   python3 -I tools/sign_manifest.py verify [폴더]               manifest.json.sig가 공개 키 가운데 하나로 맞는지 본다. 서명이 없으면 알리고 0으로 끝난다
#   python3 -I tools/sign_manifest.py keys                         저장소 공개 키의 원시 32바이트(base64)를 찍는다(앱 상수와 대조용)
# 서명 파일은 서명 64바이트를 base64로 쓴 한 줄이다. 서명 대상은 manifest.json 파일의 바이트 그대로다
import sys,os,glob,base64,subprocess,tempfile
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEYS=sorted(glob.glob(os.path.join(ROOT,'data','keys','manifest-ed25519-*.pub.pem')))
def openssl(*a,inp=None):
    r=subprocess.run(['openssl',*a],input=inp,capture_output=True)
    return r.returncode,r.stdout,r.stderr
def raw_pub(pem):
    """공개 키 PEM의 원시 32바이트. DER SubjectPublicKeyInfo의 마지막 32바이트다"""
    c,out,err=openssl('pkey','-pubin','-in',pem,'-outform','DER')
    if c or len(out)<32:raise SystemExit(f'공개 키를 읽지 못했습니다: {pem} {err.decode()[:200]}')
    return out[-32:]
def verify_with(pem,data,sig):
    with tempfile.TemporaryDirectory() as d:
        dp=os.path.join(d,'m');sp=os.path.join(d,'s')
        open(dp,'wb').write(data);open(sp,'wb').write(sig)
        c,_,_=openssl('pkeyutl','-verify','-pubin','-inkey',pem,'-rawin','-in',dp,'-sigfile',sp)
    return c==0
def verify(folder):
    man=os.path.join(folder,'manifest.json');sigp=man+'.sig'
    if not os.path.exists(sigp):print('서명 없음',sigp);return 0
    if not KEYS:raise SystemExit('저장소에 공개 키가 없습니다(data/keys)')
    data=open(man,'rb').read()
    try:sig=base64.b64decode(open(sigp,encoding='ascii').read().strip(),validate=True)
    except Exception:raise SystemExit(f'서명 파일 꼴이 틀렸습니다: {sigp}')
    if len(sig)!=64:raise SystemExit(f'서명 길이가 64바이트가 아닙니다: {sigp}')
    ok=[os.path.basename(k) for k in KEYS if verify_with(k,data,sig)]
    if not ok:raise SystemExit(f'서명이 맞지 않습니다(매니페스트가 바뀌었거나 다른 키): {sigp}')
    print('서명 맞음',ok[0]);return 0
def sign(key,folder):
    man=os.path.join(folder,'manifest.json')
    if not os.path.exists(man):raise SystemExit(f'매니페스트가 없습니다: {man}')
    c,out,err=openssl('pkeyutl','-sign','-inkey',key,'-rawin','-in',man)
    if c or len(out)!=64:raise SystemExit(f'서명하지 못했습니다: {err.decode()[:200]}')
    open(man+'.sig','w',encoding='ascii').write(base64.b64encode(out).decode()+'\n')
    # 저장소 공개 키 가운데 하나로 맞아야 한다. 다른 키로 서명한 파일을 내보내지 않는다
    try:verify(folder)
    except SystemExit:os.remove(man+'.sig');raise SystemExit('이 키의 공개 키가 data/keys에 없습니다. 서명을 지웠습니다')
    return 0
if __name__=='__main__':
    a=sys.argv[1:]
    if a[:1]==['sign'] and len(a)>=2:sys.exit(sign(a[1],a[2] if len(a)>2 else os.path.join(ROOT,'build')))
    if a[:1]==['verify']:sys.exit(verify(a[1] if len(a)>1 else os.path.join(ROOT,'build')))
    if a[:1]==['keys']:
        for k in KEYS:print(os.path.basename(k),base64.b64encode(raw_pub(k)).decode())
        sys.exit(0)
    print(__doc__ or open(__file__,encoding='utf-8').read().split('\nimport')[0]);sys.exit(2)
