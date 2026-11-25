# 남은 일

남은 일의 목록은 이 파일 하나에서 찾아 들어갑니다. 결정과 완료 기준은 [DESIGN §17](DESIGN.md#17-결정-기록과-todo), 회차별 남은 일은 아래 연구 문서에 있습니다. 2026-11-07까지 이 파일에 있던 목록은 `docs/research/recount-2026-11-11.md`의 실측으로 대체되었고 git 기록에 남아 있습니다.

## 데이터

- **5회차 남은 일**: [audit5-backlog-2026-11-23.md](research/audit5-backlog-2026-11-23.md)의 「열림」 항목과 진행 기록의 「남은 일」.
- **사용자 판단 대기**: [audit5-decisions-2026-11-24.md](research/audit5-decisions-2026-11-24.md)(옛 평면 교차 나머지 등), [audit5-n-m-undecided-2026-11-25.md](research/audit5-n-m-undecided-2026-11-25.md)(공식 근거 없이 정한 ん+b·p·m 표기).
- **근거 부족으로 넘긴 항목**: [round5-carryover.md](research/evidence-2026-11/round5-carryover.md), `data/overrides/missing_reviewed.json`의 「근거 부족」. 공개 자료로 풀지 못한 사실은 README의 Help wanted에 모읍니다.
- **생성기 정리**: 재생성으로 원본에 생긴 보정 행(`data/overrides/source_patch`, `events_fix.json`)을 지웁니다. 보정 행의 `why`가 「재생성으로 원본에 생기면 지움」이라고 적은 행이 대상입니다. 열람 전용 노선 가운데 붙을 역(`at_node`)이 없는 줄은 `tools/dev/db_regression.py`가 정보로 셉니다.
- **동결**: audit·회귀 대조 0건 뒤 DB 전수 점검이 두 번 연속 이상 0건이면 DB·ID를 잠급니다 (DESIGN §17). 실기기 시험은 그 뒤입니다.

## 앱

- Android 에뮬레이터 smoke 시험(`apps/noriori/integration_test/app_smoke_test.dart`), 실기기 성능 실측(DESIGN §12).
- 환승역 지도: 실기기에서 줌·크기 확인 (DESIGN §7.5, §17).

## 공개할 때

- 공개는 5회차 뒤, 출처·인용 정리와 규칙 전수 점검(중복·충돌·모순)을 마친 뒤입니다.
- iOS CI는 저장소를 공개하면 PR에서도 돕니다. README 배지가 가리키는 워크플로를 확인합니다.
