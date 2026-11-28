# 남은 일

남은 일의 목록은 이 파일 하나에서 찾아 들어갑니다. 결정과 완료 기준은 [DESIGN §17](DESIGN.md#17-결정-기록과-todo), 회차별 남은 일은 아래 연구 문서에 있습니다. 2026-11-07까지 이 파일에 있던 목록은 `docs/research/recount-2026-11-11.md`의 실측으로 대체되었고 git 기록에 남아 있습니다.

## 데이터

- **7회차(확인 회차)로 넘긴 것**: [audit6-wrapup-2026-11-28.md](research/audit6-wrapup-2026-11-28.md) 3절. 6회차까지 미룬 것을 한꺼번에 다뤘고, 7회차는 이상이 없는지 확인하는 회차다(사용자 2026-11-28).
- **이전 회차 기록**: [audit5-backlog-2026-11-23.md](research/audit5-backlog-2026-11-23.md), [audit5-decisions-2026-11-24.md](research/audit5-decisions-2026-11-24.md), [audit5-n-m-undecided-2026-11-25.md](research/audit5-n-m-undecided-2026-11-25.md). 6회차가 다시 본 항목은 6회차 마무리 문서가 앞선다.
- **근거 부족**: 공개 자료로 풀지 못한 사실은 README의 Help wanted에 모은다. 신청이 필요한 자료도 거기에 둔다.
- **생성기 정리**: 재생성으로 원본에 생긴 보정 행(`data/overrides/source_patch`, `events_fix.json`)을 지운다. 보정 행의 `why`가 「재생성으로 원본에 생기면 지움」이라고 적은 행이 대상이다(6회차: 원본과 출처까지 같아진 km 한 행을 지움, 위키 판 번호를 가진 행은 출처를 위해 남김).
- **동결**: audit·회귀 대조 0건 뒤 DB 전수 점검이 두 번 연속 이상 0건이면 DB·ID를 잠근다 (DESIGN §17). 실기기 시험은 그 뒤다.

## 앱

- Android 에뮬레이터 smoke 시험(`apps/noriori/integration_test/app_smoke_test.dart`), 실기기 성능 실측(DESIGN §12).
- 환승역 지도: 실기기에서 줌·크기 확인 (DESIGN §7.5, §17).

## 공개 판

- 저장소는 공개다(2026-11-26). 모든 커밋이 CI를 돈다.
- 공개 판(태그)을 낼 때 데이터 팩 매니페스트 서명은 `tools/release_pack.sh <태그> --upload`(ARCHITECTURE §4.4·§4.5).
