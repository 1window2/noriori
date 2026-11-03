# noriori

[![CI](https://github.com/1window2/noriori/actions/workflows/lint-test.yml/badge.svg)](https://github.com/1window2/noriori/actions/workflows/lint-test.yml)

일본 철도를 어디까지 탔는지 기록하는 앱입니다. 탄 구간을 고르면 지도에 칠하고, 노선·회사·도도부현별 완주율을 보여 줍니다.

- 일본 전 노선과 폐선을 담았습니다. 지도와 노선도는 인터넷 없이도 보입니다.
- 기록은 기기에만 저장되고, 고른 폴더로 자동 백업합니다. 계정과 광고가 없습니다.
- 노리츠부시에서 내려받은 CSV를 가져오고 같은 형식으로 내보낼 수 있습니다.
- 한국어, 영어, 일본어를 지원합니다. Android 먼저, iOS는 사이드로드로 배포합니다.

아직 공개 배포 전입니다.

## 개발

Flutter stable과 tippecanoe가 필요합니다.

```bash
bash tools/all.sh       # 데이터 팩 만들기
bash tools/sync_pack.sh # 앱에 넣기
cd apps/noriori && flutter run
```

구조는 `apps/noriori`(앱), `packages/noriori_core`(규칙), `packages/noriori_store`(저장소), `tools/`(데이터 파이프라인), `data/`(원본)입니다. 설계는 [docs/DESIGN.md](docs/DESIGN.md)와 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)에 있습니다.

## 라이선스

코드는 [Apache License 2.0](LICENSE), 데이터는 [CC BY-SA 4.0](data/LICENSE)입니다. 선형은 원 자료의 조건을 따릅니다. 자세한 내용은 [NOTICE](NOTICE)와 [data/NOTICE.md](data/NOTICE.md)에 있습니다.
