# noriori

일본 철도 탑승 기록 앱입니다. 탄 구간을 기록하면 지도에 칠하고, 노선과 회사별 완승률을 보여 줍니다.

- 완전 오픈소스, 무료입니다. 광고와 계정이 없습니다.
- 기록은 기기에만 저장됩니다. 사용자가 고른 폴더로 자동 백업합니다.
- 노리츠부시에서 내려받은 CSV를 가져올 수 있습니다.
- Android 먼저, iOS는 사이드로드로 배포합니다.

아직 공개 배포 전입니다.

## 구조

| 경로 | 내용 |
|---|---|
| `apps/noriori` | Flutter 앱 |
| `packages/noriori_core` | 규칙과 타입. 의존성이 없는 순수 Dart |
| `packages/noriori_store` | SQLite 저장소, 백업, 데이터 팩 |
| `tools/` | 데이터 파이프라인과 검증 도구 |
| `data/` | 데이터 원본. 구축 절차는 [data/README.md](data/README.md) |
| `docs/` | [제품 설계](docs/DESIGN.md), [구조 설계](docs/ARCHITECTURE.md) |

의존 방향은 `apps → store → core`입니다. `tools/check_boundaries.py`가 검사합니다.

## 개발

Flutter stable이 필요합니다.

```bash
bash tools/all.sh
bash tools/sync_pack.sh
cd apps/noriori
flutter test
flutter run
```

릴리스 빌드에는 서명 키가 필요합니다. `apps/noriori/android/key.properties.example`을 보세요.

## 라이선스

코드는 [Apache License 2.0](LICENSE), 데이터는 [CC BY-SA 4.0](data/LICENSE)입니다. 선형은 원 자료의 조건을 따릅니다. 자세한 내용은 [NOTICE](NOTICE)와 [data/NOTICE.md](data/NOTICE.md)에 있습니다.
