# 재현 도구

독립 재검토(2026-11-02)에서 쓴 스크립트입니다. 판 사이 재해석 시험(ARCHITECTURE §7)의 시작점입니다.

지금 판에서는 참고용입니다. `mkpacks.py`는 표 열을 이름으로 복사해 지금 스키마에서도 돌지만, `r6_packs.py`·`roundtrip.py`는 그때의 계통 길이·역 번호를 그대로 써서 일부 단계가 멈추거나 실패로 셉니다. 빌드의 관문은 `tools/appsim.py`와 Dart 시험(core·store·app)입니다. 프로젝트를 쓰지 않고 지정한 임시 폴더에만 만듭니다.

- `mkpacks.py`: `build/master.sqlite`를 복사해 변조 판을 만듭니다.
- `r6_packs.py`: 합성 기록을 원본 형태로 저장하고 옛 판과 변조 판에서 펼쳐 비교합니다.
- `roundtrip.py`, `roundtrip_service.py`: 저장 → 원본 → 재펼침 왕복을 확인합니다.
- `store_sim.py`: 위 도구가 쓰는 저장 시뮬입니다.
