# -*- coding: utf-8 -*-
# 내용이 바뀌었는데 판 번호가 그대로면 멈춘다. 앱은 같은 판이면 받아 둔 팩을 쓴다
import json,os,sys
old='apps/noriori/assets/pack/manifest.json'
if os.path.exists(old):
    a=json.load(open(old,encoding='utf-8'));b=json.load(open('build/manifest.json',encoding='utf-8'))
    if a['edition']==b['edition'] and a['files']!=b['files']:
        sys.exit('내용이 바뀌었는데 판이 그대로입니다. data/overrides/as_of.json의 edition을 올리세요')
