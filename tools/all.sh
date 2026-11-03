#!/bin/bash
# 전체 데이터 재생성: 시드 → data/source → 위키 → 컴파일 → 선형 → 컴파일 → 검증
# 네트워크를 쓰지 않는다. 원천을 새로 받는 일은 data/README.md의 수집 도구로 따로 한다
# data/imports가 없는 깨끗한 체크아웃에서는 생성을 건너뛰고 저장소의 data/source를 컴파일하고 검증한다
set -eo pipefail
cd "$(dirname "$0")/.."
if [ -f data/imports/noritsubushi/lines.json ]; then
  python3 -I tools/n02_stations.py
  python3 -I tools/gen_renames.py
  python3 -I tools/gen_old.py | cut -c1-200
  python3 -I tools/gen_source.py all | tail -2 | cut -c1-240
  python3 -I tools/gen_wiki.py | tail -2 | cut -c1-240
  python3 -I tools/gen_source.py all | tail -2 | cut -c1-240
  python3 -I tools/gen_wiki.py | tail -1 | cut -c1-240
  python3 -I tools/gen_extra.py | cut -c1-300
  python3 -I tools/lock_sources.py
  # 선형은 구간의 현행 여부와 폐지 연도가 필요해 한 번 컴파일한 뒤에 찾는다
  python3 -I tools/compile.py >/dev/null
  # gen_source가 data/source를 비우므로 영어 이름은 여기서 다시 만든다
  python3 -I tools/gen_en_names.py | tail -1 | cut -c1-200
  python3 -I tools/gen_geometry.py | tail -1 | cut -c1-400
else
  echo 'data/imports가 없어 생성 단계를 건너뜁니다. data/source를 컴파일하고 검증만 합니다'
fi
python3 -I tools/compile.py | tail -1 | cut -c1-420
if command -v tippecanoe >/dev/null; then
  python3 -I tools/gen_glyphs.py | tail -1
  python3 -I tools/gen_tiles.py | tail -1
else
  echo 'tippecanoe가 없어 rail.pmtiles와 manifest.json을 만들지 않습니다'
fi
python3 -I tools/verify.py | cut -c1-200
python3 -I tools/check_geometry.py
# 판이 바뀌면 Dart 시험의 기준값도 바뀐다
python3 -I tools/core_fixture.py | tail -1 | cut -c1-120
