"""두 빌드(직전 판과 새 판)의 결과물을 전수 대조한다. 커밋 전에 「의도한 변화만」 남았는지 본다.

새 데이터·규칙 때문에 기존에 맞던 결과가 소리 없이 바뀌면 안 된다(사용자, 2026-11-18). 그래서 빌드마다 이 도구로
ID·기간·이름·열람 전용 역 자리, 그리고 (있으면) 화면 글(audit_render_test 출력)을 직전 판과 견준다.
바뀐 것은 모두 이번 변경의 의도로 설명돼야 한다.

python3 -I tools/dev/build_diff.py <옛 build> <새 build> [<옛 화면 폴더> <새 화면 폴더>] [--show N]
"""
import os
import re
import sqlite3
import sys


def rows(build, db, sql):
    c = sqlite3.connect(os.path.join(build, db + '.sqlite'))
    try:
        return set(c.execute(sql).fetchall())
    finally:
        c.close()


TABLES = [
    ('노드', 'master', 'select id from node'),
    ('공개 노드', 'master', 'select id from node_public'),
    ('노선', 'master', 'select id from line'),
    ('계통', 'master', 'select id from route'),
    ('칸', 'master', 'select id from edge'),
    ('칸 수명', 'master', 'select edge_id, valid_from, valid_to from edge_life'),
    ('정차 기간', 'master', 'select route_id, node_id, valid_from, valid_to from route_stop_period'),
    ('계통 연결', 'master', 'select route_id, seq, kind, other_line_id, valid_from, valid_to from route_link'),
    ('열람 전용 역', 'master', 'select id, route_id, archive_line_id, after_id, before_id, seq, opened, closed from archive_stop'),
    ('열람 전용 노선', 'master', 'select id, at_node, closed from archive_line'),
    ('임시 운행 토막', 'master', 'select route_id, valid_from, valid_to from route_temp_window'),
    ('이름', 'names', 'select entity_type, entity_id, lang, text, kana, line_id, valid_from, valid_to from name'),
]


def sections(path):
    out, cur = {}, None
    for line in open(path, encoding='utf-8'):
        m = re.match(r'## 날짜 (\S+)', line)
        if m:
            cur = m.group(1)
            out[cur] = []
        elif cur:
            out[cur].append(line.rstrip('\n'))
    return out


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    show = int(sys.argv[sys.argv.index('--show') + 1]) if '--show' in sys.argv else 8
    if '--show' in sys.argv:
        args.remove(str(show))
    old, new = args[0], args[1]
    total = 0
    for label, db, sql in TABLES:
        try:
            a, b = rows(old, db, sql), rows(new, db, sql)
        except sqlite3.OperationalError as e:
            print(f'{label}: 건너뜀 ({e})')
            continue
        gone, added = sorted(a - b, key=str), sorted(b - a, key=str)
        total += len(gone) + len(added)
        print(f'{label}: 옛 {len(a)} 새 {len(b)} / 빠짐 {len(gone)} 더함 {len(added)}')
        for x in gone[:show]:
            print('   - ', x)
        for x in added[:show]:
            print('   + ', x)
    if len(args) >= 4:
        ro, rn = args[2], args[3]
        changed = {}
        for f in sorted(os.listdir(ro)):
            p = os.path.join(rn, f)
            if not os.path.exists(p):
                changed.setdefault('(파일 없음)', []).append(f)
                continue
            so, sn = sections(os.path.join(ro, f)), sections(p)
            for k in so:
                if so[k] != sn.get(k):
                    changed.setdefault(k, []).append(f)
        for k, v in sorted(changed.items()):
            total += len(v)
            print(f'화면 {k}: 바뀐 계통 {len(v)}', v[:show])
    print(f'합계 변화 {total}')


if __name__ == '__main__':
    main()
