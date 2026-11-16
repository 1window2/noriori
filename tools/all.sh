#!/bin/bash
# 전체 데이터 재생성: 시드 → data/source → 위키 → 컴파일 → 선형 → 컴파일 → 검증 → ID 잠금 → 앱 시뮬·불변식 → 감사·회귀 대조
# 네트워크를 쓰지 않는다. 원천을 새로 받는 일은 data/README.md의 수집 도구로 따로 한다
# data/imports가 없는 깨끗한 체크아웃에서는 생성을 건너뛰고 저장소의 data/source를 컴파일하고 검증한다
set -eo pipefail
cd "$(dirname "$0")/.."
if [ -f data/imports/noritsubushi/lines.json ]; then
  # 생성 도중에는 컴파일 단계 보정 행(data/overrides/source_patch)을 얹지 않는다 (tools/lib.py _patch)
  export NORIORI_GEN=1
  python3 -I tools/n02_stations.py
  python3 -I tools/gen_renames.py
  python3 -I tools/gen_old.py | cut -c1-200
  python3 -I tools/gen_n05.py | cut -c1-300
  python3 -I tools/gen_source.py all | tail -2 | cut -c1-240
  python3 -I tools/gen_wiki.py | tail -2 | cut -c1-240
  python3 -I tools/gen_source.py all | tail -2 | cut -c1-240
  python3 -I tools/gen_wiki.py | tail -1 | cut -c1-240
  python3 -I tools/gen_extra.py | cut -c1-300
  # 오버라이드가 번호로 가리키는 edge를 새 번호로 옮긴다. 새 ID 모드에서는 노드 ID가 내부 키라 건너뛴다
  if [ -z "$NORIORI_NEW_IDS" ]; then python3 -I tools/remap_edges.py; fi
  python3 -I tools/lock_sources.py
  # 선형은 구간의 현행 여부와 폐지 연도가 필요해 한 번 컴파일한 뒤에 찾는다
  python3 -I tools/compile.py >/dev/null
  # gen_source가 data/source를 비우므로 영어 이름은 여기서 다시 만든다
  python3 -I tools/gen_en_names.py | tail -1 | cut -c1-200
  python3 -I tools/gen_geometry.py | tail -1 | cut -c1-400
  unset NORIORI_GEN
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
# 공개 ID가 사라지거나 다른 실체로 옮겨 가지 않았는지 (ARCHITECTURE §4.2)
python3 -I tools/check_ids.py
# 앱 시뮬 시나리오와 불변식. 위반이 하나라도 있으면 멈춘다 (ARCHITECTURE §0.1, §4.4)
python3 -I tools/appsim.py | tail -1 | cut -c1-200
python3 -I tools/invariants.py | tail -2 | cut -c1-300
# 판이 바뀌면 Dart 시험의 기준값도 바뀐다
python3 -I tools/core_fixture.py | tail -1 | cut -c1-120
# 재설계 전 판(.9)과 비교해 사유 없이 빠진 역·노선·계통·사업자·이름이 없는가 (docs/redesign.md). 기준 파일은 로컬에만 있다
if [ -f data/imports/baseline_v9.json ]; then python3 -I tools/dev/entity_diff.py compare data/imports/baseline_v9.json build/master.sqlite build/names.sqlite | tail -1; fi
# 설계 규칙 감사와 전수 대조 지적 회귀 대조 (2회차 종합 B5·K34). 지금은 단계별 건수만 보이고 멈추지 않는다.
# NORIORI_AUDIT_STRICT=1이면 audit_db·audit_ext의 오류(err) 항목이나 회귀 대조의 남은 사례가 하나라도 있을 때 멈춘다.
# 기본을 빌드 실패로 바꿀 때는 아래 기본값 0을 1로 바꾼다
export NORIORI_AUDIT_STRICT=${NORIORI_AUDIT_STRICT:-0}
python3 -I tools/audit_db.py | tail -1
# 원자료 대조는 data/imports의 로컬 캐시(위키·N05·노리츠부시·station_database)가 있을 때만 한다
if [ -f data/imports/wiki/station.json ]; then python3 -I tools/audit_ext.py | tail -1; fi
python3 -I tools/dev/regression/run.py | tail -1
