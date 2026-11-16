# 현행·폐지·전환·열람 전용 분리 감사 (읽기 전용)

- 대상: `build/master.sqlite`, `build/names.sqlite`. 감사 도중 빌드가 다시 돌아서(04:49~04:51) **04:51 빌드의 사본**(`(임시 폴더)/snap/`)으로 쟀습니다. 이 빌드는 커밋 435388a에 **커밋되지 않은 작업 트리 변경**(tools/compile.py, tools/lib.py, data/overrides/source_patch/, invariant_exceptions.json)을 더한 결과입니다. 그래서 closed_section이 문서의 3,997이 아니라 3,998이고 edge_link는 11행입니다(source_patch의 e_090001 瓦町~花園).
- 판의 오늘: 2026-11-02 (report.json). `build/audit.json`은 01:36 것이라 지금 빌드보다 오래됐습니다.
- 스크립트: `(임시 폴더)/c1.py`~`c8*.py` (python3 -I, 단일 프로세스, 각 1초 안쪽)
- 기존 검사와 겹치는 것(db_regression 47항목, audit_db, appsim sweep)은 다시 세지 않았습니다. 아래는 그 검사들이 보지 않는 빈틈입니다.

## 요약

| # | 판정 | 항목 | 건수 |
|---|---|---|---|
| D1 | **실제 결함** | 날짜가 불확실한 `resume`가 같은 해의 `suspend`보다 먼저 정렬돼 운휴가 폐지까지 이어짐 | 2개 노선, edge 41개 |
| D2 | **실제 결함** | 이설 뒤 새 노선 edge가 원래 개업일부터 있음(옛 노선 지선 계통과 같은 기간에 공존) | 4~6곳 |
| D3 | **실제 결함** | 이설된 역이 옛 노드와 새 노드로 같은 기간에 함께 정차역으로 나옴(moved.json에 없음, （旧） 표시 없음) | 같은 노선 같은 이름 중복 28쌍(노드 약 21개) / 인접 선로보다 먼저 시작하는 정차 16행 |
| D4 | **실제 결함** | override 뒤에 정차 기간이 노선 멤버십 끝에서 잘리지 않음(이관·폐선 뒤에도 옛 계통에 정차역이 남음) | 4행 |
| D5 | **실제 결함** | archive_line에 at_node가 없어 어느 화면에도 붙지 않음. 그중 수록 대상이 아닌 종류가 섞여 있음 | 41/82 |
| D6 | **실제 결함** | archive_stop의 before_id가 그 계통에 없는 노드 | 1 |
| D7 | 개선 권장 | 날짜가 null인 `close_stop`/`open`에서 route_stop 기간이 NULL이 되어 위·아래 한계가 없음 | 37행 |
| D8 | 확인 필요 | 정차역이 인접 edge보다 먼저 시작함(edge 개업일이 틀렸을 수 있음) | 1 (西鉄栄町) |
| OK | 의도·정상 | 상태·기간 정합, 이관 단위, closed_section, map_marker, 열람 전용 누출 | 아래 표 |

---

## 실제 결함

### D1. 불확실한 날짜의 `resume`가 `suspend`보다 먼저 적용됨 — 41 edge
`tools/compile.py`의 `key()`는 이벤트를 날짜 하한(`lohi(date)[0]`)으로 정렬합니다. 그래서 `1953-XX-XX` resume(하한 1953-01-01)이 `1953-06-26` suspend보다 먼저 처리됩니다. 그때는 이미 영업 중이라 resume는 open 행을 둘로 쪼개기만 하고, 뒤이은 suspend는 폐지일까지 풀리지 않습니다. 검출 방법: edge_life에서 **상태가 같은 행이 연달아 나오는** 경우(정상이면 open↔suspended가 번갈아 나옴).

| 노선 | edge | DB 상태 | 원본 이벤트 (data/source/events/private.yaml) |
|---|---|---|---|
| 山鹿温泉鉄道線 `l_yamaga_onsen_railway_line` | 18 (e_011661 植木~植木町 등) | 1953-06-26~1957-07-26 **suspended**, 1957-07-26~1965-02-04 suspended. `last_service` 1957-07-25가 운휴 기간 안에 있어 모순 | L2735 suspend 1953-06-26, L2736 resume **1953-XX-XX**, L2737 suspend 1957-07-26, L2738 resume **1957-XX-XX** |
| 電車線(新潟交通) `l_densha_line_niigata` | 23 (e_012306 등, 東関屋~燕) | **1964-06-16~1999-04-05 내내 suspended** (35년 동안 탑승 기록 불가) | L3080 suspend 1964-06-16, L3081 resume **1964-XX-XX** (白山前~東関屋의 resume 1965-01-XX은 정상 적용) |

- 영향: 그 기간의 기록이 "탈 수 없는 날짜"로 막힙니다(§2.8 J, §3.2 재해 불통).
- 고치는 법:
  1. 데이터: `data/overrides/events_fix.json`에 `match`/`set`으로 resume 날짜를 suspend 뒤로 정렬되는 값으로 바꿉니다(예: 월을 아는 값 `1964-XX-XX`→`1964-12-XX` 수준. 실제 재개일은 원문에서 확인해야 함).
  2. 생성 단계: `key()`에서 `resume`(그리고 `close`)는 같은 edge의 직전 `suspend`보다 앞서지 않게 하고, **효과 없는 resume/suspend는 `err('resume_noop')`**로 처리합니다.
  3. 회귀 검사: db_regression에 "edge_life 연속 행의 status가 같음 = 0"을 추가합니다. 지금 `T-overlap-life`는 `valid_to_lo`만 비교해서 이 경우를 놓칩니다.

### D2. 이설 뒤 새 선로 edge가 원래 개업일부터 있음 — 옛 선로와 공존
"○○旧線" 지선 계통 방식(옛 선로 = `owned` branch, 새 선로 = 본선 edge)에서는 새 선로 edge의 시작일을 `data/overrides/edge_dates.json`으로 이설일에 맞춥니다(志文~岩見沢, 明科~西条, 佐久間, 能生 등 77행은 이미 들어 있음). 다음 곳은 그 행이 없습니다. 그래서 이설 전 기간에 **같은 노선의 옛·새 선로가 함께 영업 중**으로 나옵니다. 결과로 특정 연도 분모가 이중으로 잡히고(§3.1, §2.8 J), 새 선로를 개통 전 날짜로 기록할 수 있게 됩니다.

| 노선 | 새 선로 edge (attr 시작) | 옛 선로 계통 (끝) | 제안 edge_dates.json 행 |
|---|---|---|---|
| 志摩線 | e_007773 白木~五知 3.1km (1929-07-23) | r_shima_line_shiraki_gochi e_007782 3.4km (1993-09-11) | `"n_shiraki\|n_gochi": "1993-09-11"` |
| 大阪線 | e_007540 伊賀上津~西青山, e_007541 西青山~東青山 (1930-12-20) | r_osaka_line_nishi_aoyama_higashi_aoyama 8.6km (1975-11-23) | 해당 edge들 `"…": "1975-11-23"` |
| 中央本線 | e_000888 南木曽~田立, e_000889 田立~坂下 (1909-07-15) | r_chuo_main_line_nagiso_tadachi 6.3km (1973-05-25) | `"1973-05-25"` |
| 伯備線 | e_003515 豪渓~日羽, e_003516 日羽~美袋 (1925-05-17) | r_hakubi_line_gokei_minagi 7.4km (1970-09-07) | `"1970-09-07"` |
| 鹿児島本線 (확인 필요) | e_004400 戸畑~枝光 2.8km (1902-12-27) | r_kagoshima_main_line_tobata_edamitsu e_004518 2.8km (1966-10-01) | 이설이면 `"1966-10-01"`. km가 같아 km_change였을 수도 있음 |
| 内子線 (확인 필요) | e_004220 内子~五十崎 (1920-05-01) | r_uchiko_line_kitayama_uchiko_uchiko_uchiko 5.6km (1986-03-03) | 1986년 신선과의 관계를 확인해야 함 |

- 같은 노선·같은 두 노드의 병렬 edge 가운데 정상인 것: 福知山線 尼崎~塚口(e_003041, 尼崎港線 `route_only`, 1893~1981)은 §2.7의 "자기 영업km를 가진 계통"에 해당합니다.
- 생성 단계 검사 제안: "같은 노선의 owned 지선이 끝나는 날 본선 쪽에서 같은 노드 쌍(또는 같은 구간)이 시작하지 않으면 경고".

### D3. 이설된 역이 같은 기간에 두 노드로 공개됨 (moved.json 누락)
§2.2 "역 위치 이동" 규칙: 선로 위 km가 바뀌면 옛 노드와 새 노드를 두고, `moved.json`으로 이전일에서 기간을 가르고, 옛 노드에 （旧）를 붙입니다. 아래 역들은 moved.json에 없습니다. 그래서 새 노드의 본선 정차가 **원래 개업일부터** 시작하고, 옛 노드(`*_iida`, `*_hokuriku_main` 등)도 같은 기간에 정차역입니다. 측정 결과는 같은 노선·같은 이름·다른 노드이면서 기간이 겹치는 정차가 28쌍(노드 약 21개)이고, 인접 계통 edge보다 정차가 먼저 시작하는 경우가 16행입니다. 이 16행에서는 본선 선택기에 옛 기간 동안 **선로 없는 역**이 나옵니다(appsim S9가 지선에서 고를 수 있으면 통과시킴).

| 노선 | 새 노드 (본선 정차 시작) | 옛 노드 (지선, 끝) | 본선 인접 edge 시작 |
|---|---|---|---|
| 飯田線 | n_sakuma 佐久間 (1936-11-10) | n_sakuma_iida (1955-11-11) | 1955-11-11 |
| 北陸本線 | n_no 能生, n_tsutsuishi 筒石, n_nadachi 名立 (1911~1912) | n_no_hokuriku_main 등 (1969-09-29) | 1969-09-29 |
| 北上線 | n_waka_sennin 和賀仙人 (1921-11-18) | n_waka_sennin_kitakami (1962-12-01) | 1962-12-01 |
| 士幌線 | n_nukabira 糠平 (1937-09-26) | n_nukabira_shihoro (1955-08-01) | 1955-08-01 |
| 身延線 | n_tatebori 竪堀 (1926-03-08) | n_tatebori_minobu (1969-09-28) | 1969-09-28 |
| 根室本線 | n_shikagoe 鹿越 (1901-09-03) | n_shikagoekarijokojo (1966-09-29) | 1966-09-29 |
| 大阪線 | n_nishi_aoyama 西青山, n_higashi_aoyama 東青山 | *_osaka (1975-11-23) | (D2와 같은 원인) |
| 中央本線 | n_tadachi 田立 | n_tadachi_chuo_main (1973-05-25) | (D2) |
| 伯備線 | n_hiwa 日羽 | n_hiwa_hakubi (1970-09-07) | (D2) |
| 八王子線(近鉄) | n_nishihino 西日野 | n_nishihino_hachioji (1976-04-01), 0m, 같은 계통 | — |
| 大師線(京急) | n_kojimashinden 小島新田 | n_kojimashinden_daishi (1964-03-25), 같은 계통 | — |
| 그 밖 | 土讃線 土佐穴内, 内子線 内子·五十崎, 鹿児島本線 八幡, 水浜線 大洗, 築地線 稲永町 | | |

- 대부분은 같은 group입니다(방문 역 수는 맞음). 깨지는 것은 선택기 표시, 이름 （旧） 표시, 기록 재해석 순서(node_move)입니다.
- 고치는 법: `data/overrides/moved.json`에 `{old, new, date}`를 추가합니다(예: `n_sakuma_iida → n_sakuma, 1955-11-11`). compile.py의 moved 루프가 기간을 가르고 group도 합칩니다. km가 같은 단순 이동이면 대신 `stop_dates.json`에 `"r_iida_line|n_sakuma": ["1955-11-11", null]`를 넣습니다.
- 확인 필요: 足尾線 神戸(n_godo_watarase_keikoku ↔ n_godo_ashio, 5m, **다른 group**, 1912~1973 겹침. 직전 커밋의 "神戸=神土"와 관련), 長岡線 寺泊(n_teradomari_shindo ↔ n_teradomari_nagaoka, 32m, 다른 group).

### D4. override 뒤에 정차 기간이 노선 멤버십 끝으로 잘리지 않음 — 4행
compile.py는 `close_stop`이 있을 때만 정차 끝을 인접 attr 끝으로 자릅니다. 뒤에 적용되는 `moved.json`·`stop_dates.json`은 자르지 않습니다.

| 계통 | 역 | 정차 끝 | 계통 노선 멤버십 끝 | 원인 |
|---|---|---|---|---|
| r_tohoku_main_line (JR) | 野内（旧） n_nonai_aoimori_aoimori_railway_old | 2011-03-12 | 2010-12-04 (青い森鉄道 이관) | moved.json 날짜 |
| r_tohoku_main_line_nonai_…_old_aomori | 野内（旧） | 2011-03-12 | 1968-07-21 | moved.json |
| r_yubari_line_noborikawa_branch | 楓（旧） n_kaede_old | 1981-10-01 | 1981-07-01 | moved.json |
| r_yunomae_line (国鉄) | 川村 n_kawamura_kumagawa | 2026-09-20 | 1989-10-01 (くま川鉄道 이관) | 확인 필요 (원본 이벤트에 2026-09-20 없음. source_patch/stops일 수 있음) |

- 이관 뒤 옛 사업자 계통에 정차역이 남는 오염입니다. appsim S8이 "이관 옛 계통의 정차역"을 보지만 이 행들은 통과합니다.
- 고치는 법(생성 단계): 모든 override를 적용한 뒤 `valid_to = min(valid_to, 그 계통 노선의 인접 attr 끝)`으로 다시 자릅니다.

### D5. archive_line 41/82행에 at_node가 없음 (대부분 closed도 NULL)
§4.5: line 항목의 `at`은 그 노선이 갈라지던 역이고, 노선 화면에 붙여 보입니다. `at=null`이면 어느 노선 화면에도 나오지 않는 죽은 행입니다. 그중 §4.1·§4.5의 **수록 제외 종류**가 들어 있습니다.

| 분류 | 예 (id, 이름) | 판정 |
|---|---|---|
| 화물·임항선 (전용선·화물선 제외) | a_akitarinkai_railway_line 秋田臨海鉄道線, a_fukushimarinkai_railway_onahamafuto_main_line 福島臨海鉄道小名浜埠頭本線, a_kushirokaihatsufutonishiko_line / …futo_line 釧路開発埠頭, a_mizushimarinkai_railway_nishifuto_line 水島臨海鉄道西埠頭線 | 빼야 함 |
| 미개업선 | a_kamakama_line 蒲蒲線 | 빼야 함 |
| 군용·특수 | a_railway_rentaienshu_line 鉄道連隊演習線 | 빼야 함(확인 필요) |
| 궤도 아닌 것 추정 | a_nisengonen…aichikyuhaku_line 愛・地球博線 (IMTS) | 확인 필요 |
| 1950년 뒤 폐지인데 기록 노선이 없음 | a_tokyutamagawa_line 東急玉川線 (1969 폐지, 砧線만 l_kinuta_line로 있음) | **기록 가능으로 올릴 대상** (§4.6) |
| 그 밖 | 北見鉄道, 洞爺湖電気鉄道, 京成白鬚線, 名鉄勝川線·清洲線, 北恵那鉄道大井線 등 | at·closed를 채우거나 staging으로 |

- 고치는 법: `data/overrides/archive_lines.json`의 `drop`은 "같은 기록 노선이 있을 때"만 쓰는 키(값 = 그 노선)입니다. 제외용 `exclude: {id: 사유}` 키를 새로 두거나 생성기 `tools/gen_extra.py`에서 거릅니다. at이 없는 행은 컴파일 경고로 올립니다.
- 별도: at·closed가 있는 1950년 뒤 폐지 archive_line 11개(西鉄北九州線 2000, 戸畑線·枝光線 1985, 北方線 1980, 井笠鉄道 神辺·矢掛線 1967, 三重交通神都線 1961, 荒尾市営 1964, 赤城登山 1968, 向ヶ丘遊園モノレール 2001, 大浜線 1980)는 §4.6 "기준일 이후지만 교차 검증 불가 → 열람 전용"으로 허용됩니다. 다만 승격 후보로 목록에 둘 만합니다.

### D6. archive_stop 참조 1건
- `a_matsumotodoori` 松本通 (l_fukubu_line, r_fukubu_line, after n_fukui_fukui, before **n_tawaramachi_fukui 田原町**, km 20.4): before_id가 r_fukubu_line의 route_stop에 없습니다. 고치는 법: `data/overrides/archive_fix.json`의 "松本通" 항목에서 route를 田原町이 있는 계통으로 바꾸거나 before를 null로 둡니다.

---

## 개선 권장 · 확인 필요

### D7. route_stop 기간 NULL 37행 (valid_to NULL 26, valid_from NULL 11)
원인은 `"date": null`인 close_stop/open 이벤트입니다(원본에 42줄). 예: 別大線 白木海水浴場, 東旭川線 南中通 등 5역, 久保山線 6역, 花園橋線 5역(open null). NULL은 "모름"이라 의도된 값이지만(§4.5, §5.4), 앱의 `state_on`은 `t_hi=None`이면 끝이 없는 것으로 봅니다. 노선 폐지 뒤에도 "maybe"가 됩니다. 제안: valid_to는 NULL로 두고 `valid_to_hi`만 인접 attr 끝으로 채웁니다(`valid_from_lo`도 같은 방식).

### D8. 西鉄栄町
- r_tenjin_omuta_line n_nishitetsusakaemachi는 정차 1938-10-01부터이고, 인접 edge(新栄町~西鉄栄町, 西鉄栄町~大牟田)는 1939-07-01부터입니다. edge 개업일이 넓게 풀렸을 수 있습니다(1938년 栄町 종착). 원문을 확인해야 합니다.

### JR 중복 집계 4곳 밖의 병렬 (확인 필요)
- 白新線 e_002167 ↔ 信越本線 e_002300 新潟~(上沼垂 신호장) 1.9km, 둘 다 normal·현행. §2.7 규칙 2의 예외 4곳에 들어 있지 않습니다. 영업km상 양쪽 다 있는지 확인이 필요합니다.
- 漆生線 e_005807 ↔ 上山田線 e_005812 (?~下山田) 1966~1986 겹침.

---

## 의도·정상 (측정값)

| 검사 | 결과 | 근거 |
|---|---|---|
| edge_life ongoing인데 hi≠9999 / 폐지인데 hi=9999 / 오늘 뒤 폐지 | 0 / 0 / 0 | |
| edge_attr 기간이 edge_life 합집합 밖 | 0 | |
| edge_life 기간 중 어느 attr도 없는 날 | 0 | |
| life와 attr의 ongoing 불일치 | 0 | |
| attr 노선이 그 edge를 담은 계통을 갖지 않음 / 계통 노선이 attr 없음 | 0 / 0 | |
| 현행 노선 600 / 폐지 노선 433. 폐지 노선 계통의 ongoing 정차역 | 0 | |
| 현행 정차역인데 인접 선로가 모두 끝남 | 0 | |
| suspended 상태로 폐지된 life 행 (close_reason 있음) | 295 | §2.2 "재해로 불통인 채 끝난 구간" 의도 |
| 오늘 운휴 edge | 103 (383.0km, 10개 노선: 肥薩線·美祢線·米坂線·津軽線·陸羽東線·久留里線·北上線·大井川本線·いすみ線·小湊鉄道線) | §3.2 현행 분모 포함 의도 |
| 같은 두 노드의 병렬 edge, 다른 노선·같은 기간 | 24 | 梅田貨物線(extra), JR 예외 3곳(今宮~新今宮, 小倉~西小倉, 鴫野~放出), 東京メトロ·阪急·阪神·大阪メトロ·札幌·横浜의 별도 선로, 伊勢線 南四日市~河原田(1973~87) — §2.7 |
| alt=old 이설 쌍과 edge_link | 11행. 모두 옛 끝 = 새 시작, close_reason relocated | §2.2 relocate |
| 현행 normal edge 중 단위가 둘 이상 (승계 켬) | 0 (공동 영업은 노선별 별도 edge) | §2.7 규칙 3 |
| 같은 edge의 연속 행에서 lineage가 끊김 (승계 켬 역대 분모 이중 집계) | 0 | §2.8 E |
| carryover_group 규칙 (JR→타사만 새 값) 위반 | 0 | §2.8 E |
| denominator_unit ↔ attr (기간, 등급, km) 불일치 | 0 | |
| closed_section ↔ 폐지 edge | 3,998 = 3,998, 6,965.2km = 6,965.2km. 중복·누락·필드 불일치(km, abolished, last_service, 마지막 소속 노선, map_visible) 0 | §2.11 |
| map_marker가 map_visible=1이거나 폐지 아닌 edge에 있음 / 선형 없는 폐지 edge에 표식 없음 | 0 / 0 | §7.3 |
| 열람 전용 ID(a_*)가 route_stop·edge·node·denominator_unit·hub_member·route_link에 있음 | 0 | §4.5 "통계에 영향 없음" |
| archive_stop 이름 = 같은 노선 route_stop 이름 | 0 | |
| archive_line 이름 ≈ 기록 노선 (정규화) | 2 — 篠山鉄道≠国鉄篠山線, 芦屋鉄道≠国鉄芦屋線. 다른 노선이라 오탐 | |
| archive_stop 1950년 뒤 폐지 | 103 (km 있음 77) | §4.6 "교차 검증 불가 → 열람 전용" 허용. 승격 후보 |
| archive_stop의 앞뒤 노드가 archive 개업 전에 폐지됨 | 0 | |
| 같은 ja 이름·같은 사업자의 노선이 기간 겹침 | 0 | |
| 공개 노드의 날짜 없는 기본 ja/ko 이름 없음 / 같은 언어 기본 이름 둘 | 0 / 0 | |
| 공개 노드 kana 없음 | 3 (陣屋町, ユネスコ村, 下之郷) | audit_db에 이미 있음 |

## 기존 검사에 더할 만한 것
1. edge_life 연속 행의 status가 같음 = 0 (D1)
2. 정차 기간 ⊂ 인접 계통 edge의 (life ∩ 그 노선 attr) 합집합. extension과 NULL은 따로 보고 (D2·D3·D4)
3. 같은 노선·같은 이름·다른 노드의 정차가 겹치면 moved.json에 있어야 함 (D3)
4. archive_line.at_node NOT NULL. 화물·미개업 키워드 금지 (D5)
5. archive_stop의 after·before가 그 route의 route_stop 또는 a_* (D6)
