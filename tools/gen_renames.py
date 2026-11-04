# -*- coding: utf-8 -*-
# 역 문서 연혁에서 역명 변경을 뽑는다. 결과: data/candidates/renames.json {문서 제목:[[옛 이름,시작,끝],...]}
# 마지막 이름이 문서 제목과 맞을 때만 받는다. 시작을 모르면 None
import sys,os,re,json,unicodedata
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from lib import *
W=json.load(open(os.path.join(IMP,'wiki','station.json'),encoding='utf-8'))
D=r'(\d{4})年(?:（[^）]*）)?(?:(\d{1,2})月(?:(\d{1,2})日)?)?'
N=r'([^\s、。：:「」『』（）()・,，]{1,24}?)(?:駅|停留場|電停|停留所)'
R1=re.compile(N+r'(?:から|より)[「『]?'+N+r'[」』]?に(?:駅名を)?(?:改称|改名|変更)')
R2=re.compile(r'(?:駅名を|名称を|、|：|-|同時に|に伴い|により)?[「『]?'+N+r'[」』]?に(?:駅名)?(?:改称|改名)')
R0=re.compile(N+r'(?:として|が)(?:開業|開設|設置|新設)')
def fix(x):
    return re.sub(r'^.*(?:駅が|駅を|駅は|駅も)','',x)
BAD={'貨物','一般','旅客','同','当','信号場','現在','現','本','この'}
def ok(x):
    """역 이름처럼 생긴 것만 받는다. 빠지면 현재 이름이 보일 뿐이지만 틀린 이름은 그대로 화면에 나온다"""
    if not x or x in BAD or not 2<=len(x)<=14 or x[0] in 'のがにはをとでもへや':return False
    return not re.search(r'[、。{}|=:<>]|として|伴い|開業|同時に|間に|線の|により|ため|まで|および|及び|を|後に|あたる|現在',x)
def lo(x):return x.replace('X','0') if x else ''
def edate(m):
    y,mo,da=m.groups()
    return f'{y}-{int(mo):02d}-{int(da):02d}' if da else (f'{y}-{int(mo):02d}-XX' if mo else f'{y}-XX-XX')
out={};skip=0
for t,e in W.items():
    if not e.get('hist'):continue
    cur=znorm(re.sub(r'\s*[（(].*$','',e.get('title') or t))
    ev=[];first=None
    for l in e['hist']:
        l=re.sub(r'\{\{読み仮名\|([^|}]*)\|[^}]*\}\}',r'\1',l)
        d=re.match(r'^'+D,l)
        if not d:continue
        date=edate(d);rest=l[d.end():]
        if first is None:
            m=R0.search(rest)
            if m:
                f_=m.group(1)
                f_=re.split('である|当初の',f_)[-1]
                if re.search('鉄道|電鉄|電気|軌道|索道|延伸|開通|により|市営|会社|支社',f_):f_=re.split('の|により|に',f_)[-1]
                if f_:first=(f_,date)
        if '会社' in rest[:30] or '社名' in rest[:30] or '仮' in rest[:6] or '決定' in rest:continue
        m=R1.search(rest)
        if m:ev.append((date,fix(m.group(1)),fix(m.group(2))));continue
        m=R2.search(rest)
        if m:ev.append((date,None,fix(m.group(1))))
    if not ev:continue
    ev.sort(key=lambda x:x[0].replace('X','9'))
    if znorm(ev[-1][2])!=cur:skip+=1;continue
    rows=[];prev=first[0] if first else None;start=first[1] if first else None
    for date,old,new in ev:
        o=old or prev
        if ok(o) and ok(new) and znorm(o)!=znorm(new) and (not start or lo(start)<=lo(date)):rows.append([o,start,date])
        prev=new;start=date
    if rows:out[e.get('title') or t]=rows
os.makedirs(CAND,exist_ok=True)
json.dump(out,open(os.path.join(CAND,'renames.json'),'w',encoding='utf-8'),ensure_ascii=False,indent=0)
print('역명 변경 문서',len(out),'행',sum(len(v) for v in out.values()),'제목 불일치로 뺌',skip)
