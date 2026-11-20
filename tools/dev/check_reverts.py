"""최근 커밋의 변경이 지금 작업 트리에서 되돌려졌는지 본다.

갈래 결과를 합칠 때 옛 기준의 파일을 통째로 덮어쓰면 그 사이 커밋의 변경이 소리 없이 사라진다
(11회차 S1·S2 합치기 3f42667이 49ee1f3의 compile.py·stop_dates.json을 되돌려 陸羽西線 운휴가 「폐역」이 됨, 2026-11-17).
커밋마다 그 커밋의 패치가 지금 트리에 다시 들어가면(git apply --check 통과) 그 변경이 빠진 것이다.
생성물(data/source, *.g.dart)과 누적 기록(회귀 사례표·결정 기록)은 같은 줄이 다시 들어갈 수 있어 보지 않는다.

python3 -I tools/dev/check_reverts.py [커밋 수, 기본 15]   # 합친 뒤, 커밋 전에 돌린다. 되돌려진 것이 있으면 종료 코드 1
"""
import subprocess
import sys

SKIP = ('data/source/', 'build/')
SKIP_END = ('.g.dart', 'cases.json', 'decisions.md')


def run(*args, data=None):
    return subprocess.run(list(args), input=data, capture_output=True)


def main():
    count = int(sys.argv[1]) if len(sys.argv) > 1 else 15
    commits = run('git', 'log', f'-{count}', '--format=%h', '--no-merges').stdout.decode().split()
    # 나중 커밋이 일부러 되돌린 변경(앞 커밋의 기능을 뒤에서 없앤 것)은 결함이 아니다. 그 커밋 뒤의 커밋들이 같은 파일을 바꿨으면 알리기만 한다
    bad = []
    for at, commit in enumerate(commits):
        files = run('git', 'show', '--name-only', '--format=', commit).stdout.decode().split()
        for path in files:
            if path.startswith(SKIP) or path.endswith(SKIP_END):
                continue
            patch = run('git', 'show', commit, '--', path).stdout
            if not patch or run('git', 'apply', '--check', '-', data=patch).returncode != 0:
                continue
            # 덧붙이기만 한 덩어리는 앞뒤 줄이 같으면(새 함수 끝 「return out; }」이 앞 함수 끝과 같음) 한 번 더 들어갈 자리가 생긴다.
            # 거꾸로도 들어가면 그 변경이 지금 트리에 있는 것이라 되돌림이 아니다 (f4ed85e pack_reader 오탐, 2026-11-18)
            if run('git', 'apply', '--check', '-R', '-', data=patch).returncode == 0:
                continue
            later = [c for c in commits[:at] if path in run('git', 'show', '--name-only', '--format=', c).stdout.decode().split()]
            bad.append((commit, path, later))
    for commit, path, later in bad:
        note = f' (뒤 커밋 {", ".join(later)}도 이 파일을 바꿈: 의도한 되돌림인지 확인)' if later else ''
        print(f'되돌려짐 {commit} {path}{note}')
    print(f'최근 {len(commits)}개 커밋 대조: 되돌려진 파일 {len(bad)}')
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
