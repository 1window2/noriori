# -*- coding: utf-8 -*-
# 이름이 비어 있는 역·노선·회사와 열람 전용 역의 읽기를 모은다
import json,re,sys
sys.path.insert(0,'tools')
from lib import *
g=json.load(open('data/candidates/gen_report.json',encoding='utf-8'))
W=[]
for et,i,n in g['pending']:
    if et=='node':
        b=re.sub(r'[（(].*?[)）]','',n).strip();W.append(['node:'+n,b+'駅',b+'停留場',b+'電停',b+'停留所'])
    elif et=='line':W.append(['line:'+n,n])
    else:W.append(['op:'+n,n])
for a in load('archive'):
    n=a.get('name')
    if not n:continue
    if a.get('kind')=='stop':W.append(['node:'+n,n+'駅',n+'停留場'])
    else:W.append(['line:'+n,n])
seen=set();U=[]
for w in W:
    if w[0] not in seen:seen.add(w[0]);U.append(w)
json.dump(U,open('data/candidates/kana_want.json','w',encoding='utf-8'),ensure_ascii=False)
print(len(U))
