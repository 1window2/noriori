#!/bin/bash
# N03 행정구역에서 앱에 넣는 기본 배경을 만든다. 원본이 새 판일 때만 돌린다.
# 쓰는 법: gen_base.sh <N03 prefecture.geojson> <mapshaper-xl 경로> [간격 m]
# 결과 data/base/land.geojson, border.geojson, pref.geojson은 그대로 두고 gen_tiles가 타일로 묶는다
set -eo pipefail
cd "$(dirname "$0")/.."
src=$1
ms=$2
interval=${3:-30}
"$ms" 8gb "$src" -dissolve N03_001 -simplify "interval=$interval" keep-shapes -clean \
  -o data/base/.prefs.topo.json format=topojson
"$ms" 8gb data/base/.prefs.topo.json -dissolve \
  -o data/base/land.geojson format=geojson geojson-type=FeatureCollection precision=0.00001
"$ms" 8gb data/base/.prefs.topo.json -innerlines \
  -o data/base/border.geojson format=geojson geojson-type=FeatureCollection precision=0.00001
rm data/base/.prefs.topo.json
# 히트맵용 면. 멀리서만 보이므로 훨씬 거칠게 줄인다
"$ms" 8gb "$src" -dissolve N03_001 copy-fields=N03_007 -simplify interval=500 keep-shapes -clean \
  -each 'pref=parseInt(N03_007.slice(0,2),10);delete N03_001;delete N03_007' \
  -o data/base/pref.geojson format=geojson geojson-type=FeatureCollection precision=0.0001
