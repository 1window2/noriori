# 재현 도구

독립 재검토에서 쓴 스크립트입니다. 판 사이 재해석 시험(ARCHITECTURE §7)의 시작점입니다. 프로젝트를 쓰지 않고 지정한 임시 폴더에만 만듭니다.

- `mkpacks.py`: `build/master.sqlite`를 복사해 변조 판을 만듭니다.
- `r6_packs.py`: 합성 기록을 원본 형태로 저장하고 옛 판과 변조 판에서 펼쳐 비교합니다.
- `roundtrip.py`, `roundtrip_service.py`: 저장 → 원본 → 재펼침 왕복을 확인합니다.
- `store_sim.py`: 위 도구가 쓰는 저장 시뮬입니다.
