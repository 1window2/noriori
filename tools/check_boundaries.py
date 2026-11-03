# -*- coding: utf-8 -*-
# 의존 방향을 검사한다 (ARCHITECTURE §1, §2.2). 어기면 CI가 실패한다
#   apps → store → core. core는 순수 Dart, store는 Flutter를 모른다
#   기능끼리 직접 import하지 않고, 화면은 저장소를 모른다
import os,re,sys
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMP=re.compile(r"""^\s*(?:import|export)\s+['"]([^'"]+)['"]""",re.M)
# 조건부 import의 뒤쪽 대상까지 본다
COND=re.compile(r"""\bif\s*\([^)]*\)\s*['"]([^'"]+)['"]""")
PURE={'dart:core','dart:convert','dart:collection','dart:math','dart:typed_data'}
def dart_files(*parts):
    base=os.path.join(ROOT,*parts)
    for d,_,fs in os.walk(base):
        for f in fs:
            if f.endswith('.dart') and not f.endswith('.g.dart'):yield os.path.join(d,f)
def imports(path):
    text=open(path,encoding='utf-8').read()
    return IMP.findall(text)+COND.findall(text)
def resolved(path,target):
    return '' if ':' in target else os.path.normpath(os.path.join(os.path.dirname(path),target))
bad=[]
def fail(path,target,why):bad.append(f'{os.path.relpath(path,ROOT)}: {target} ({why})')
for f in dart_files('packages','noriori_core','lib'):
    for t in imports(f):
        if t.startswith('dart:') and t not in PURE:fail(f,t,'core는 I/O가 없다')
        if t.startswith('package:'):fail(f,t,'core는 의존이 없다')
        if resolved(f,t) and not resolved(f,t).startswith(os.path.join(ROOT,'packages','noriori_core')):fail(f,t,'core 밖을 보지 않는다')
for f in dart_files('packages','noriori_store','lib'):
    for t in imports(f):
        if t.startswith('package:flutter') or t.startswith('package:noriori/'):fail(f,t,'store는 앱을 모른다')
        if resolved(f,t).startswith(os.path.join(ROOT,'apps')):fail(f,t,'store는 앱을 모른다')
FEATURES=os.path.join(ROOT,'apps','noriori','lib','features')
for f in dart_files('apps','noriori','lib','features'):
    rel=os.path.relpath(f,FEATURES).split(os.sep);own=rel[0];layer=rel[1]
    for t in imports(f):
        full=resolved(f,t)
        if full.startswith(FEATURES+os.sep) and os.path.relpath(full,FEATURES).split(os.sep)[0]!=own:
            fail(f,t,'기능끼리 직접 import하지 않는다')
        if t.startswith('package:noriori/features/') and t.split('/')[2]!=own:fail(f,t,'기능끼리 직접 import하지 않는다')
        # 기능 바로 아래 파일은 화면과 같이 본다. controller와 플랫폼 어댑터만 저장소를 안다
        if layer not in ('controller','platform') and re.match(r'package:(noriori_store|drift|sqlite3)',t):fail(f,t,'화면은 저장소를 모른다')
        if layer not in ('controller','platform') and full.startswith(os.path.join(ROOT,'packages','noriori_store')):fail(f,t,'화면은 저장소를 모른다')
# 공용 위젯은 기능과 저장소를 모른다
for f in dart_files('apps','noriori','lib','app','widgets'):
    for t in imports(f):
        if t.startswith('package:noriori/features/') or resolved(f,t).startswith(FEATURES+os.sep):fail(f,t,'공용 위젯은 기능을 모른다')
        if re.match(r'package:(noriori_store|drift|sqlite3)',t):fail(f,t,'공용 위젯은 저장소를 모른다')
for b in bad:print(b)
print('경계 위반',len(bad))
sys.exit(1 if bad else 0)
