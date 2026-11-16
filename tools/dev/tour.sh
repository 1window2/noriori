#!/usr/bin/env bash
# 에뮬레이터·시뮬레이터에서 integration_test/tour_test.dart를 돌리며 화면을 찍는다.
# 쓰는 법: tools/dev/tour.sh <flutter 기기 ID> <ios|android> <저장 폴더> [flutter test에 넘길 인자, 예: --dart-define=TOUR_LINES=l_mine_line]
# 다른 순회 시험은 TOUR_TEST=integration_test/one_way_test.dart 처럼 고른다 (한 방향 운행·정차 화면)
# 시험이 `TOUR_SHOT:<이름>`을 찍으면 simctl·adb로 갈무리해 <저장 폴더>/<이름>.png로 둔다 (지도는 네이티브 화면이라 앱 안 갈무리에 안 잡힌다)
set -euo pipefail
device=$1 platform=$2 out=$3
shift 3
mkdir -p "$out"
cd "$(dirname "$0")/../../apps/noriori"
flutter test "${TOUR_TEST:-integration_test/tour_test.dart}" -d "$device" "$@" 2>&1 | while IFS= read -r line; do
  case "$line" in
    *TOUR_SHOT:*)
      name=${line##*TOUR_SHOT:}
      name=${name//[^A-Za-z0-9_]/_}
      if [ "$platform" = ios ]; then
        xcrun simctl io "$device" screenshot --type=png "$out/$name.png" >/dev/null 2>&1 || true
      else
        adb -s "$device" exec-out screencap -p > "$out/$name.png" 2>/dev/null || true
      fi
      echo "찍음 $name"
      ;;
    *"All tests passed"*|*"Some tests failed"*|*EXCEPTION*|*Error*) echo "$line" ;;
  esac
done
