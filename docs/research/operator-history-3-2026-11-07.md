사업자 이력 보정 3차 (재평가 2026-11-07 operators OP4-*, lines LN-N02)

결과: rows.json 423행, 사례 39개 (OP4-001~037 중 요청 범위 + OP4-042 + LN-N02)
- events_fix.json: 새 행 238 (match/set 155, transfer add 83) + 기존 행 고침 10 (京福, action=replace_existing, match_why로 찾음)
- source_patch/operators/private_operator_history.yaml: 새 사업자 43
- source_patch/names/private_operator_history.yaml: add 129 (43×ja/ko/en) + replace 2 (神戸六甲鉄道 en, 小田原市内線 ko)
- en_fix.json: 1 (operator.o_mt_rokko_cable_car_and_tourism_company en)
- confidence high 326, medium 97 (주로 ko/en 이름과 아래 결정 항목)

검증 (샌드박스 = 작업 시점 저장소 작업 트리 복사, HEAD cdd0a6d + 커밋 안 된 변경 22파일. repo_state.txt):
- NORIORI_GEN= python3 -I tools/compile.py 오류 0 (match 모두 1건 적중, transfer_no_from·range_unresolved 0)
- verify.py 통과, invariants.py 통과, appsim PASS 112 NOTE 9
- 요청 노선 밖 edge_attr 변화 0. 노선별 사업자 기간이 사슬과 어긋나는 행 1개(아래 9)
- 범위는 edge ID 없이 n_a..n_b. 志摩線 白木–五知 옛 선로는 "n_shiraki..n_gochi" + route r_shima_line_shiraki_gochi (owned 계통이라 그 한 칸만 풀림)
- 범위는 edge_dates.json을 뺀 사건 시점 멤버십으로 계산함 (edge_dates가 시작일을 당긴 칸을 빼려고)

사용자 결정이 필요한 것
1. 같은 이름의 1대·2대 법인을 한 ID로 둠: 富士山麓電気鉄道(1926~1960 / 2022~, o_fujikyu_railway), 東京モノレール(1964~1967 / 1981~, o_tokyo_monorail). 따로 둘지.
2. 黒部峡谷 1953~1971 関西電力: 기존 o_kansai_electric_power_company(category cable, 관전 트롤리버스용) 재사용. 같은 회사 ID 둘을 피하려고. 분류 cable이 그대로라 별도 ID로 할지.
3. 京福 OP4-042: o_keifuku_electric_railroad를 남기고 福井 노선 사건 15곳을 옮김. o_keifuku_electric_railroad_fukui는 쓰이지 않게 되지만 원본 operators·names에 남아 이름 중복(ja/ko/en)은 그대로. 완전히 없애려면 생성기(gen_source oid / id_map)에서 福井 회사 코드를 같은 ID로 보내야 함 (check_ids 은퇴 처리 필요할 수 있음). 대안은 두 ID 유지 + 표시 이름 구별.
4. ドリーム交通 OP4-036: 새 ID o_dream_kotsu로 운행 기간 전체. o_dream_kaihatsu는 미사용으로 남음 (OP4-048과 같이 정리). 노선 ko 「드림 개발 드림랜드선」은 손대지 않음.
5. 筑豊 黒崎駅前–熊西 OP4-010: 1914~2000-11-26을 西日本鉄道로, 노선 ID는 l_chikuho_electric_railroad 그대로 (北九州線이 DB에 없음). 北九州線을 넣을 때 노선 이관으로 바꿔야 함. 그때까지 보류할지.
6. 휴지 중 회사 변경: 八栗(1944~1964), 妙見の森ケーブル(1944~1960)은 휴지 기간도 재개 회사(八栗ケーブル, 能勢電気軌道)로 둠.
7. 분류: 神戸電気鉄道는 후계와 같은 general_private (재평가는 준대형 근거 언급). ドリーム交通은 기존 o_dream_kaihatsu와 같은 general_private. 공사 3곳(神戸市都市整備公社 등)은 케이블만 운영해 cable.
8. 이름: 富士急行 ko 「후지 급행」(규칙; 「후지큐」로 할지), 東京急行電鉄 en 「Tokyu Corporation」(원문 미확인), 東京臨海新交通·横浜新都市交通·大阪高速鉄道 en 원문 미확인, 神戸六甲鉄道 en 「Kobe Rokko Railway」 공식 미확인 (옛 값 Mt. Rokko Cable Car & Tourism Company는 새 六甲山観光 ID로 옮김).

알려 둘 것
9. 豊橋 東田本線 e_009176(駅前–駅前大通): edge_dates.json이 시작을 1950-08-26으로 당겨 1950~1954에 豊橋鉄道로 보임. 사건 시점엔 1998 개업이라 transfer로 못 고침.
10. 東京モノレール 2대 이관일은 위키 최신판(111669937)의 1981-05-01 사업 양도. 재평가 근거의 05-28이 아님.
11. 손대지 않음: こどもの国線 면허(OP4-038), 北総 公団 구간 면허, 頸城(OP4-039), 분류 OP4-040·041, 이름 OP4-043~047, 小田原市内線 type(LN-T01), 폐선 노선 ko 이름에 박힌 지금 회사 이름.
12. 저장소 작업 트리가 작업 중에 바뀌고 있었음. 적용 전 events_fix.json의 京福 기존 행 why가 그대로인지 확인 (replace_existing은 why로 찾음).

파일: rows.json, summary.txt, spec.json(사례별 사슬), scripts/(gen.py·assemble.py·apply.py·validate.py), sb/(샌드박스), new_master.sqlite·new_names.sqlite(적용 뒤 빌드)
