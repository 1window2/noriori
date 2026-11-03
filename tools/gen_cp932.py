# -*- coding: utf-8 -*-
# CP932 2바이트 표를 Dart로 만든다. 파이썬 코덱이 기준이고 Dart에는 이 범위를 다 읽는 패키지가 없다
# charset 2.0.1은 9,604자 중 2,642자를 못 읽었다 (﨑, 髙 같은 역명 글자 포함, 2026-11-02 측정)
import os
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT=os.path.join(ROOT,'packages/noriori_core/lib/src/importing/cp932_table.dart')
LEADS=list(range(0x81,0xA0))+list(range(0xE0,0xFD))
TRAILS=list(range(0x40,0x7F))+list(range(0x80,0xFD))
def cell(hi,lo):
    try:
        c=bytes([hi,lo]).decode('cp932')
    except UnicodeDecodeError:
        return '�'
    if 0xE000<=ord(c)<=0xF8FF:return '�'   # 사용자 정의 영역은 글자가 정해져 있지 않다
    return c
lines=[''.join(cell(h,l) for l in TRAILS) for h in LEADS]
assert all(len(x)==len(TRAILS) for x in lines)
assert not any(x in ''.join(lines) for x in "'\\$")
with open(OUT,'w',encoding='utf-8') as f:
    f.write('// tools/gen_cp932.py가 만든 파일이다. 손으로 고치지 않는다.\n\n')
    f.write('/// 앞 바이트 하나마다 뒤 바이트 %d칸. 없는 칸은 U+FFFD다.\n'%len(TRAILS))
    f.write('const cp932Table =\n')
    for i,x in enumerate(lines):
        f.write("    '%s'%s\n"%(x,';' if i==len(lines)-1 else ''))
print(len(lines),len(TRAILS),sum(c!='�' for x in lines for c in x))
