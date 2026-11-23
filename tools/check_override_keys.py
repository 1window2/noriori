# -*- coding: utf-8 -*-
# 보정 파일(data/overrides/*.json)에 같은 열쇠가 두 번 있으면 멈춘다. JSON은 뒤의 값만 읽어 앞의 보정(위치·날짜·읽기)이 소리 없이 사라진다
# (5회차 2026-11-24: archive_fix 「片野本町@l_kitagata_line」 위치 행이 같은 열쇠의 읽기 행에 덮여 회귀 5건)
import json,os,sys,collections,glob
ROOT=os.path.join(os.path.dirname(os.path.abspath(__file__)),'..')
bad=[]
for f in sorted(glob.glob(os.path.join(ROOT,'data','overrides','**','*.json'),recursive=True)):
    def hook(p,f=f):
        d=[k for k,v in collections.Counter(k for k,_ in p).items() if v>1]
        if d:bad.append((os.path.relpath(f,ROOT),d[:5]))
        return dict(p)
    json.load(open(f,encoding='utf-8'),object_pairs_hook=hook)
if bad:sys.exit(f'보정 파일에 같은 열쇠가 두 번 있습니다: {bad}')
print('보정 파일 열쇠 겹침 0')
