#!/bin/bash
# build/의 데이터 팩을 앱 자산으로 복사한다
set -eo pipefail
cd "$(dirname "$0")/.."
mkdir -p apps/noriori/assets/pack
# 앱은 같은 판이면 새 팩을 쓰지 않는다. 내용이 다른데 판이 같으면 조용히 옛 값이 남는다
python3 -I tools/check_edition.py
# 매니페스트 서명은 복사하기 전에 확인한다. 확인이 실패해 멈추면 앱 자산에 새 매니페스트와 옛 DB가 섞여 남는다 (tools/sign_manifest.py)
if [ -f build/manifest.json.sig ]; then python3 -I tools/sign_manifest.py verify build || exit 1; fi
# 옛 판의 글리프가 남으면 매니페스트에 없는 파일이 앱에 들어간다
rm -f apps/noriori/assets/pack/glyph-*.pbf
cp build/manifest.json build/names.sqlite build/rail.pmtiles apps/noriori/assets/pack/
# 매니페스트 서명: 위에서 확인한 것만 넣는다. 옛 서명이 남으면 앱이 판을 거부한다
rm -f apps/noriori/assets/pack/manifest.json.sig
if [ -f build/manifest.json.sig ]; then cp build/manifest.json.sig apps/noriori/assets/pack/; fi
# 앱이 읽지 않는 표를 뺀 판이다
cp build/pack-master.sqlite apps/noriori/assets/pack/master.sqlite
# 기본 배경과 역 이름 글리프. 지도가 인터넷 없이 그려지는 데 필요하다
cp build/base.pmtiles build/glyph-*.pbf apps/noriori/assets/pack/
# OSM 선로는 선택 파일이다
if [ -f build/rail-osm.pmtiles ]; then cp build/rail-osm.pmtiles apps/noriori/assets/pack/; fi
ls -la apps/noriori/assets/pack | awk 'NR>3{print $5,$9}'
