# -*- coding: utf-8 -*-
# AltStore·SideStore 소스(altstore.json)를 GitHub Releases에서 만든다. 릴리스 워크플로가 새 판을 올릴 때마다 다시 만든다
# 소스 주소는 https://github.com/<저장소>/releases/latest/download/altstore.json 하나로 고정이다. 앱이 이 주소를 새로 읽어 업데이트를 알린다
#   gh api repos/<저장소>/releases --paginate --slurp > releases.json
#   python3 -I tools/altstore_source.py releases.json altstore.json
#   python3 -I tools/altstore_source.py --check-build <빌드> <태그> releases.json   (태그 전 검사: 빌드 번호가 앞선 IPA보다 커야 함)
# 버전마다 IPA 파일 이름은 noriori-<버전>-b<빌드>.ipa 다. 초안과 사전 릴리스는 넣지 않는다
import sys,os,json,re
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
META=json.load(open(os.path.join(ROOT,'distribution','altstore','meta.json'),encoding='utf-8'))
IPA=re.compile(r'^noriori-(\d+\.\d+\.\d+)-b(\d+)\.ipa$')
def versions(releases):
    o=[]
    for r in releases:
        if r.get('draft') or r.get('prerelease'):continue
        for a in r.get('assets',[]):
            m=IPA.match(a['name'])
            if not m:continue
            o.append(dict(version=m.group(1),buildVersion=m.group(2),date=r['published_at'],
                          localizedDescription=(r.get('body') or '').strip() or f"noriori {m.group(1)}",
                          downloadURL=a['browser_download_url'],size=a['size'],minOSVersion=META['app']['minOSVersion']))
    # 최신이 앞이다
    return sorted(o,key=lambda v:(tuple(int(x) for x in v['version'].split('.')),int(v['buildVersion'])),reverse=True)
def source(releases):
    app={k:v for k,v in META['app'].items() if k!='minOSVersion'}
    app['versions']=versions(releases)
    if not app['versions']:raise SystemExit('IPA가 붙은 릴리스가 없습니다')
    return dict({k:v for k,v in META.items() if k!='app'},apps=[app],news=[])
def load(path):
    rel=json.load(open(path,encoding='utf-8'))
    # --slurp는 쪽마다 배열 하나를 담은 배열을 준다
    return [r for page in rel for r in page] if rel and isinstance(rel[0],list) else rel
if __name__=='__main__':
    if sys.argv[1]=='--check-build':
        build,tag=int(sys.argv[2]),sys.argv[3]
        prev=[int(v['buildVersion']) for v in versions([r for r in load(sys.argv[4]) if r.get('tag_name')!=tag])]
        if prev and build<=max(prev):raise SystemExit(f'빌드 번호 {build}가 앞선 IPA의 {max(prev)}보다 크지 않습니다')
        print('빌드 번호',build,'앞선 최대',max(prev) if prev else None);sys.exit(0)
    out=source(load(sys.argv[1]))
    json.dump(out,open(sys.argv[2],'w',encoding='utf-8'),ensure_ascii=False,indent=1)
    print('AltStore 소스',[v['version'] for v in out['apps'][0]['versions']])
