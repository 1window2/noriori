#!/bin/bash
# 공개 릴리스의 데이터 팩 매니페스트에 서명한다 (ARCHITECTURE §4.4 판 릴리스 절차, §4.5).
# 태그를 올려 Release 워크플로가 IPA·팩·매니페스트를 빌드 증명과 함께 올린 뒤, 그 태그를 체크아웃하고 tools/all.sh를 돌린 이 기기에서 쓴다.
# 개인 키 경로는 환경 변수로 받는다: NORIORI_MANIFEST_KEY(1번 키), 없으면 NORIORI_MANIFEST_KEY_2(2번 키). 키 파일은 저장소·CI에 두지 않는다
#   bash tools/release_pack.sh <태그> [--upload] [--into-app]   (옵션은 tools/release_sign.py)
set -eo pipefail
cd "$(dirname "$0")/.."
key=${NORIORI_MANIFEST_KEY:-}
if [ -z "$key" ] || [ ! -f "$key" ]; then key=${NORIORI_MANIFEST_KEY_2:-}; fi
if [ -z "$key" ] || [ ! -f "$key" ]; then echo "서명 키가 없습니다: NORIORI_MANIFEST_KEY(또는 _2)에 개인 키 경로를 주세요"; exit 1; fi
[ -n "${1:-}" ] || { echo "태그를 주세요: bash tools/release_pack.sh v1.2.3"; exit 2; }
tag=$1; shift
python3 -I tools/release_sign.py "$tag" "$key" "$@"
