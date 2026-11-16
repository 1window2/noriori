# DB 2차 감사 ③ 위상 (2026-11-06, 판 2026-11-06.3)

대상은 감사용 사본 `연구 원자료/snap-2026-11-06.3/master.sqlite`·`names.sqlite`(판 2026-11-06.3)뿐입니다. `build/`는 읽지 않았습니다. 저장소는 읽기만 했고 고친 파일은 이 문서와 `db-audit2-topology-2026-11-06.json` 둘입니다. 검사는 표본이 아니라 해당 표 전수이고, 스크립트는 저장소 밖 임시 폴더에서 `python3 -I`로 돌렸습니다(핵심 부분은 부록 A).

맡은 범위는 위상입니다: 노드·역 묶음(group)·환승 묶음(hub), 역 이전 짝(`node_move`), edge·계통(`route_edge`·`route_stop`), `route_link`·`junction`·`route_parallel`, 열람 전용(`archive_stop`·`archive_line`)의 자리. 시간·승계·이름·좌표·원자료 대조는 다른 감사가 맡아, 위상 판정에 걸리는 곳만 적고 넘겼습니다.

`[알려짐]`은 db-audit-2026-11-06(0절의 남은 항목 DBA-013·DBA-015 포함)과 그 문서가 [알려짐]으로 둔 항목입니다.

## 1. 요약

| ID | 내용 | 수 | 등급 |
|---|---|---:|---|
| TOP-01 | `route_link`가 상대 노선마다 후보 하나만 골라, 같은 노선의 다른 계통·다른 노드가 맡던 기간의 환승·분기 행이 없음 | (계통, 역, 상대 노선) 60 | 오류 |
| TOP-02 | `route_link`의 종류(continue/branch)와 흐름(through/up/down)을 오늘 상태로 정해 전 기간에 씀 | 85행 (continue 25, through 30, up·down 30) | 오류 |
| TOP-03 | junction이 이관 뒤 노선 ID에만 붙어, 이관 전(또는 같은 역의 JR 쪽) 노선쌍의 분기·끝 이어짐이 환승으로만 나옴 | 9역 18행 | 오류 |
| TOP-04 | 같은 노선 지선·옛 경로 계통의 한쪽 끝에서 부모 계통 쪽 분기 행이 없음 | 45끝 (부모 쪽 행이 하나도 없는 계통 10) | 오류 |
| TOP-05 | 広電 循環線(2026 분리)을 1912·1944부터 둠. 本線 稲荷町–的場町, 皆実線 的場町–比治山下 귀속이 틀리고 本線 계통이 2025년 전 끊김 | 3 edge | 오류 |
| TOP-06 | 공식 노선의 토막·옛 경로를 따로 노선(line)으로 둠 | 8노선 | 오류 (DBA-013 원인 포함) |
| TOP-07 | 선로 위 km가 바뀐 역 이전인데 `moved.json` 짝이 없음 (桑原, 伊敷, 玉里道, 崎守町) | 4 (+의심 1) | 오류 |
| TOP-08 | `moved.json` 쌍의 옛 정차 끝이 연도만(`XX`)이라 이전일 뒤까지 걸침 | 8쌍 | 오류 |
| TOP-09 | 옛 선로 계통이 본선 edge를 그대로 써 본선과 같은 기간에 겹침 (北陸本線 倶利伽羅–石動 1909–2015, 白新線 沼垂–新崎 1958 뒤) | 2계통 2 edge | 오류 |
| TOP-10 | 같은 역인데 group·hub가 없어 환승 행이 0 (中津, 糠ノ目=高畠, 丹後山田=与謝野) — 손 표 SAME_STATION이 좌표 없는 노드에서 조용히 무시됨 | 3역 | 오류 |
| TOP-11 | 100m 안의 환승역인데 hub가 없어 환승 행 0 (前橋 両毛線–東武前橋線, 津軽二股–津軽今別 1988–2016) | 2 | 오류 |
| TOP-12 | 같은 group인데 hub가 아니면 `route_link`가 없음. §2.9 표시 결정표 3순위(같은 group → 환승)와 어긋남 | 86 (60 group) | 의심 (결정 필요) |
| TOP-13 | 노면전차 정류장을 지하철역 노드에 합침: 浅草(都電 千住線), 板橋本町(都電 志村線) | 2 | 의심 (S5·DBA-015 유형의 새 예) |
| TOP-14 | 국철 시대 같은 역이 노드·group 둘: 鷹ノ巣/鷹巣(阿仁合線), 人吉/人吉温泉(湯前線) | 2 | 의심 |
| TOP-15 | 津軽今別(海峡線)과 奥津軽いまべつ(北海道新幹線)이 같은 시설·같은 회사인데 노드·group 둘, 짝 없음 | 1 | 의심 |
| TOP-16 | `archive_stop.km`이 그 계통 `km_cum` 축과 다름 (앞뒤 역 km 사이가 아님) | 27 | 오류 |
| TOP-17 | `archive_stop.after_id` NULL 22 (§14는 필수), 앞뒤 역 사이에 그때 있던 공개 정차역이 낌 4 | 26 | 의심 |
| TOP-18 | 新潟 옛 경로 계통의 亀田 정차가 `ongoing`이라 1958 뒤에도 다음 역 없는 분기 행 | 1 | 의심 |
| TOP-19 | `parallel_runs.json` 판정 행의 기간이 데이터와 다름 3, 병주로 판정했지만 숨은 노드 경계라 그려지지 않는 칸 6 | 9 | 정보 |
| TOP-20 | junction 중 두 노선이 그 역에 함께 있던 날이 없는 행 168, 노드가 상대 노선 노드가 아닌 행 64 | 232 | 정보 |
| TOP-21 | 위상 판정을 흔드는 좌표: 新垂井(垂井에서 73m, n02 approx), 塩竈(本塩釜에서 31m, n05) | 2 | 정보 (④에 넘김) |
| TOP-22 | 열람 전용 노선 `at` 역이 그 노선 영업 때 정차역이 아님 2, 열람 역 `after`가 그때 계통에 없음 65 | 67 | 정보 |
| TOP-23 | 甲浦 옛 노드 이름이 「甲浦(鉄道駅)」이라 （旧） 표시 규칙 밖 | 1 | 정보 (④에 넘김) |
| TOP-24 | 숨은 노드 `export_name` 괄호 표기가 갈림 (19개 중 9개 괄호 없음) | 9 | 정보 |

오류 12종, 의심 6종, 정보 6종입니다. 가장 큰 것은 `route_link` 생성(TOP-01~04)입니다. 행 자체의 참조·값·중복은 모두 0인데, **기간을 나누지 않고 한 후보·오늘 상태로 전 기간을 덮는 생성 방식** 때문에 날짜를 고른 역 선택기(§8.1 탑승일 연동)에서 환승·분기가 빠지거나 다른 종류로 나옵니다.

## 2. 규칙 추적표

"SQL"은 사본에 그대로 돌린 조건, "스크립트"는 부록 A의 적재부 위 파이썬입니다. 기간은 `*_lo`/`*_hi`(EDTF 하한·상한)로 [from, to) 겹침을 봅니다. 위반 0도 방법을 남겼습니다.

### 2.1 노드 (§2.4, §2.8 B, §14)

| 규칙 | 확인 방법 | 위반 | 예·판정 |
|---|---|---:|---|
| §14 `node.kind` 값 | kind ∉ {station, signal, junction, freight} | 0 | station 13,571 · junction 12 · signal 4 · freight 3 |
| §14 group 필수 | group NULL / station_group에 없음 / 구성원 없는 group / `station_group.n` 중복 | 0/0/0/0 | |
| 고아 노드 | edge 없는 노드 / route_stop에 없는 노드 / 모든 edge가 어느 계통에도 없음 | 0/0/0 | |
| §2.4 숨은 노드 | kind≠station인데 정차행 / station인데 정차행 없음 / 숨은 노드에 이름 | 0/0/0 | 숨은 노드 19개 목록을 역사로 검토, 여객 취급 흔적 0 (嘉穂·上沼垂·田端·新小岩·三岐朝明 신호장, 吹田·東高島·高島 화물, 분기점 11) |
| §2.4 `export_name` 표기 | 숨은 노드 export_name이 `[…]` | 9 | TOP-24 |
| §2.8 B 같은 사업자의 같은 역은 한 node | 공개 노드 쌍: 300m 안, 같은 사업자 계열(국철·JR 6사는 하나, `category='jr'`)이 **같은 기간에** 두 노드를 다른 계통의 정차역으로 씀, 같은 이름(옛·노선별 이름 포함), `node_move` 아님 | 10 | 博多築港前·千鳥橋·新川 [알려짐 DBA-013], 住吉 [알려짐], 内子·神戸(足尾) [알려짐 S9], 鷹ノ巣·人吉 (TOP-14), 上一万(旧)·松山市/松山市駅 (n05_fix 근거로 다른 정류장, 정상) |
| 같음, 이름이 다른 쌍 | 위 조건에서 이름 조건 대신 100m 안 | 15 | 전차 정류장↔역(南富山駅前, 東武駅前 등), 津軽二股↔津軽今別(TOP-11), 新垂井↔垂井(좌표, TOP-21) |
| §2.8 B 다른 역을 한 node로 합치지 않음 | 한 노드에 모인 **다른 노선** edge 선형 끝(edge_shape 복호화, 그 노드 쪽 끝) 사이 최대 거리 > 300m | 다른 사업자 0 / 같은 사업자 12 | 瑞江 1.74km [알려짐 DBA-015], 大曽根·名古屋城·車道 [알려짐 S5], **浅草 0.35km·板橋本町 0.30km (TOP-13)**, 東京(京葉線)·池袋·本町·武蔵小杉·なんば·新下関은 한 역의 떨어진 승강장(설계) |
| §2.8 B group = 같은 역 | group 안 두 노드 최대 거리 > 0.5km | 58 | 이전 짝 17, [알려짐 S9] 東青山 2.77·松島 2.37·田立·五十崎·西青山·八幡·土佐穴内, 나머지는 같은 이름 다른 사업자 0.5~1.0km(芦屋 0.74, 塚口 0.86 등) |
| group 이름 | 같은 group 두 노드의 ja 이름(옛·노선별 포함)에 공통이 없음 | 18 | ケ/ヶ 표기 6, 옛 이름(原町田/町田, 金山/金山橋, 平田橋/上小田井), 駅前 정류장(高岡駅前, 福井駅前). 정보 |
| group 빠짐 | 같은 이름(옛 이름 포함)·300m 안·다른 group | 15 | **丹後山田=与謝野 6m·中津 7m (TOP-10)**, 桑原 (TOP-07), 鷹ノ巣·人吉 (TOP-14), 片町 [알려짐], 神戸 [알려짐 S9]; 金町·小郡·業平橋·梅田·琴平·幕張·松山市는 다른 역 |
| 같은 이름 1km 안 다른 group (현재 이름만) | | 4 | 神戸·中津·片町·寺泊. 셋은 한쪽 좌표가 n05·wikidata — 그룹 규칙이 좌표 없는 노드를 못 묶은 흔적 (TOP-10) |
| §2.8 B 다른 사업자면 같은 group + hub | 같은 group 두 공개 노드가 같은 hub에 없음 | 43쌍 (같은 때 정차 34) | 琴似, 芦屋, 塚口, 浅草(TX) 등 → TOP-12 |
| §2.9 hub 무결성 | hub_member의 hub 없음 / 빈 hub / 구성원 1개 / 노드 없음 / 비공개 노드 / 중복 행 | 0 | |
| hub 중첩 | 두 hub 이상에 속한 노드 | 384 | 쌍 단위 hub(사슬). 설계, 정보 |
| hub 빠짐 | 공개 노드 둘이 100m 안·같은 때 정차·다른 계통·같은 group도 hub도 아님(hub_not 제외) | 8 | 中津·糠ノ目(TOP-10), 前橋·津軽二股(TOP-11), 神戸 [S9], 本塩釜·新垂井(좌표), 豊平 |

### 2.2 역 이전 (`moved.json` / `node_move`, §2.2, ARCHITECTURE §3.5)

| 규칙 | 확인 방법 | 위반 | 예·판정 |
|---|---|---:|---|
| node_move = moved.json | 행 수 | 0 | 46 = 46 |
| 짝 하나 | 같은 옛·새 노드 두 번 / 사슬(옛 = 다른 쌍의 새) | 0 | |
| 같은 group | 옛·새 group 다름 | 0 | |
| 이전일에서 가름 | 옛 정차 끝 하한 > 이전일 / 새 정차 시작 상한 < 이전일 | 0 / 0 | |
| 같음 (불확실 날짜) | 옛 정차 끝이 `YYYY-XX-XX`라 상한이 이전일 뒤 | 8 | TOP-08 |
| 옛 노드는 옛 계통에만 | 새 노드와 공유하지 않는 옛 노드 계통에 이전일 뒤 정차 | 1 | `r_shinetsu_main_line_echigo_ishiyama_niigata_shinetsu_main`의 亀田 ongoing (TOP-18) |
| 같은 선로 위 이동은 두 노드가 같은 edge 위 | 같은 계통 공유 쌍의 옛 노드 edge가 이전 뒤에도 영업 | 22 | 설계대로(가장 잘게 나눈 edge, 정차로 가름). 위반 아님 |
| （旧） 표시·`moved` 별칭 | 이름 같은 쌍의 옛 이름에 （旧） / 별칭 | 1 / 0 | 甲浦 「甲浦(鉄道駅)」 (TOP-23) |
| 옛 좌표 | 옛·새 좌표 거리 < 10m | 16 | [알려짐] (db-audit 2.3 "옛 좌표를 찾음", DBA-014로 넣은 11쌍 모두 0m 그대로) |
| 이전인데 짝 없음 ① | 같은 이름·같은(이관 사슬 포함) 노선·5km 안·옛 정차 끝 뒤 400일 안에 새 정차 시작 | 2 | **桑原→芦ノ牧温泉南 1980-12-01 (TOP-07)**, 大泉東·長宮→大泉 2004(통합, 정보) |
| 이전인데 짝 없음 ② (이름이 바뀐 이전) | 옛 노드의 모든 정차가 같은 날 끝나고 300m 안 같은 사업자 새 노드가 그날 시작 | 13 | **伊敷→玉江小学校前, 玉里道→護国神社前 1952-08-10, 崎守町→崎守 1968-09-19 (TOP-07, n05_fix 메모가 근거)**, 西鉄栄町→新栄町 1970-04-28 (의심), 津軽今別 (TOP-15); 나머지 7은 통합·다른 정류장 |

### 2.3 edge·계통 (§2.2, §2.7, §14)

| 규칙 | 확인 방법 | 위반 | 예·판정 |
|---|---|---:|---|
| edge 참조 | 양 끝 노드·seed_line·route_only 실재, `n` = 번호 | 0 | |
| 자기 고리 | from = to | 0 | |
| §2.8 C km | km NULL / 음수 / edge_km 없음 / 0km | 0/0/0/12 | 0km 12 모두 km 추정 역 [알려짐] |
| §2.2 병렬 edge는 relocate만 | 같은 두 노드·같은 노선·기간 겹침 | 2 | 福知山線 尼崎–塚口, 鹿児島本線 戸畑–枝光 [알려짐] (route_only 지선) |
| edge 소속 | route_edge에 없는 edge / edge_attr 없는 edge / (노선, edge) 집계인데 그 노선 계통에 없음 | 0/0/0 | |
| 계통에 남의 edge | 계통 edge가 그 노선 집계에 한 번도 없음 / route_only edge가 다른 계통에 | 0/0 | |
| route_edge 형식 | seq 0..n-1 연속, 계통 안 중복, 없는 계통, edge 없는 계통 | 0 | |
| §2.7 한 줄로 이어짐 | 이웃 순번 edge가 노드 공유 안 함 / 계통 edge가 두 덩어리 이상 / from·to·via가 edge에 없음 | 4/0/0 | 吾妻·常磐·仙石·新潟 옛 경로 [알려짐] (이설 계통) |
| route_stop ↔ route_edge | 정차행 노드가 계통 edge에 없음 / edge 노드가 route_stop에 없음 / 이웃 순번 노드를 잇는 edge 없음 | 0/0/4 | 常磐線 新地·坂元·山下 옛·새 교차 배열 (ARCHITECTURE §3.5 설계) |
| km_cum | NULL·감소(순환 제외) / 첫 역 ≠ 0 / 이웃 정차 km 차 ≠ 잇는 edge km(±0.11) | 0/0/5 | 차 5는 吾妻·石巻·仙石 이설 계통(표시용 km, 정보) |
| `is_extension` | extend_to와 일치, km NULL | 0 | |
| §2.7 순환 | closed=1인데 반복 노드 없음 / 열린 계통에 반복 노드 | 0/0 | 순환 5 |
| role | role 값, 노선마다 main 1, route.line 실재, 열린 계통 첫·끝 = from·to | 0 | main 1,033 = 노선 1,033 |
| §2.7 끊긴 곳 (날짜별) | 계통의 어느 날, 양쪽 노드는 그 노선 영업 중인데 사이 edge만 다른 노선 소속 | 0 | 영업 없는 사이 edge 20은 모두 이설 병렬 짝 |
| §2.7 노선 = 공식 명칭 | 노선 영업 edge가 어느 날 두 덩어리이고 그 사이를 같은 사업자 다른 노선 edge가 이음 | 3 | 中央本線/山手線 代々木–新宿(설계), **広電 本線/循環線 (TOP-05)**, **仙台 循環線/循環線 花京院–仙台駅前 (TOP-06)** |
| 같음 (토막 노선) | 노선 이름이 「X線 A–B」「旧線」이고 같은 사업자 X線이 따로 있음 | 8 | TOP-06 |
| §2.7 겹침 없이 (날짜별) | 같은 노선 두 계통이 같은 edge를, 양 끝 정차행 기간 ∩ 집계 기간이 겹치게 덮음 | 7 | **北陸本線 倶利伽羅–石動, 白新線 大形–新崎 (TOP-09)**; 白新線 나머지 2·信越 2·長尾線 1은 한쪽이 통과행이라 고를 수 없음(정상). [알려짐]은 "route_edge에 기간이 없어 invariants.py가 봄"이었으나 정차 기간으로는 겹침 |
| §2.2 relocate 연결 | edge_link kind·참조·successor NULL / relocated인데 edge_link 없음 / 짝 양 끝(옛 노드는 새 노드로) 불일치 | 0/0/0 | relocated 11 |
| 운전 계통 | service_part의 계통·역 실재, 부품이 이어짐 | 0 | |
| 파생 표 참조 | closed_section·map_marker 노드·노선·edge(n), closed_section 중복, coverage | 0 | |

### 2.4 `route_link`·`junction` (§2.9, §8.1, ARCHITECTURE §3.5 "분기 기간")

| 규칙 | 확인 방법 | 위반 | 예·판정 |
|---|---|---:|---|
| 참조 | (route, seq)가 공개 정차행(연장 아님) / other_line·other_route·other_node·next·terminal 실재 / other_route ∈ other_line / 자기 자신 | 0 | 7,373행 |
| other_route 빈 행 | | 1,626 | continue 1,236·branch 390: 다른 노선 junction 행(설계) |
| 값 | kind / side(transfer에 side 없음) / flow는 transfer만, transfer는 flow 필수 / flow_source가 up·down↔coord, through↔route / at_edge는 branch만 / other_node가 자기 노드 | 0 | |
| 기간 | NULL·역전 / 자기 정차 기간 밖 / 상대 계통 그 역 정차 기간 밖 | 0/0/0 | |
| 중복 | 완전 중복 / 같은 (계통, 역, 상대)에 transfer와 continue가 같은 때 / 같은 kind·next가 기간 겹침 | 0/0/0 | |
| next_stop | 상대 계통에서 그 역(other_node 또는 같은 group·hub 노드) 바로 옆 정차역(오늘·기간 겹침·전체 중 하나)이 아님 (through 제외) | 1 | 亀田 → 新潟 옛 경로, next NULL (TOP-18) |
| terminal | 그 방향 끝 정차역이 아님 | 0 | |
| next 없음 (through 제외) | next NULL | 26 | 화물선·연락선·東成田線 등 정차역 없는 상대. 정보 |
| at_edge | seq가 위쪽 정차역이고 상대 계통 끝이 그 다음 칸의 숨은 노드 | 0 | 6행 |
| **§2.9 표시 결정표 3 (빠짐)** | 정차행 s마다 같은 node·같은 group·같은 hub 노드에 다른 노선 정차가 겹치는 기간을, 그 노선으로 가는 route_link 기간 합집합이 덮는지 (경계 1일 차 무시) | 같은 node 10 · 같은 group 110 · hub(350m 등 linked) 28 · hub(먼 쌍) 217 · hub_not 2 | 같은 node·linked hub의 일부 기간 빠짐 60 → **TOP-01**; 같은 group 행 없음 86 → **TOP-12**; 먼 hub 쌍·hub_not은 `linked()`가 일부러 뺌(설계) |
| 대칭 | R→L 행이 있는데 L 계통에서 R 노선으로 돌아오는 행이 같은 때 없음 | 20 | TOP-01과 같은 원인(芸備線 広島 ↔ 広電 등) |
| **끝 이어짐은 그날의 끝 역** | continue 행 기간에 자기 계통 위·아래 모두 정차역이 있던 때가 있음 | 25 | **TOP-02** (富良野, 鵡川, 盛岡, 敦賀, 姫路 …) |
| **흐름은 그날 상태** | flow=through인데 그 기간 내내 상대가 한쪽에만 정차역 / flow=up·down·unknown인데 그 기간에 상대가 지나가던 때가 있음 | 30 / 30 | **TOP-02** (八戸 青い森 2002–2010, 金沢 新幹線 2015–2024, 横浜 東横線 1928–2004 …) |
| §2.9 같은 노선 지선 | 지선 계통 끝이 같은 노선 다른 계통 정차역과 같은 때 닿는데 부모 쪽에서 그 지선을 가리키는 행 없음 | 45 | **TOP-04** |
| 지선 끝이 부모에 닿음 | 지선 계통 양 끝이 같은 노선 다른 계통에 닿지 않음 | 4 | 中央本線 神田–代々木(설계), **広電 広島駅–的場町 (TOP-05)**, 立山黒部貫光 鋼索線 두 케이블(정보), 秩父 연락선(숨은 노드, 설계) |
| junction 참조·값 | line·other·other_route·node·edge 실재, side·is_continue 값, 기간 역전, node·edge 둘 다 없음 | 0 | 1,349행, 모두 node |
| junction 노드 | node가 line 계통에 없음 / other_line 계통에 없음 | 0 / 64 | 다른 사업자 별도 노드. `near`로 처리되어 행은 생김 (TOP-20) |
| junction 기간 | 두 노선이 그 노드에 함께 정차한 날 없음 | 168 | 이관 전후 노선쌍 (TOP-20). 그중 같은 사슬 노선쌍이 그 역에 공존하는데 분기·이어짐 행이 없음 → **TOP-03** |
| junction 효과 | 공존하는데 branch/continue 행을 하나도 못 만든 행 | 39 | 같은 노선 지선 파생 행 15(잘못된 끝, TOP-04), 지하철 渡り線 continue 24(상대도 지나가 환승으로 둠, 설계) |

### 2.5 병주 (`route_parallel`, §8.1, `parallel_runs.json`)

| 규칙 | 확인 방법 | 위반 | 예·판정 |
|---|---|---:|---|
| 후보 칸마다 판정 | 같은 두 노드를 다른 노선이 기간 겹치게 잇는 노드쌍 vs 판정 행 (양방향) | 0 | 후보 24(영업 중 20) = 판정 24 (병주 16: shared 5·adjacent 11, 아님 8) |
| 판정 칸은 이웃 | 판정 두 노드가 양쪽 노선 계통에서 이웃 순번 | 0 | |
| 판정 기간 | 판정 행 `period` = 후보 겹침 기간 | 3 | TOP-19 (compile은 이 열을 쓰지 않음) |
| route_parallel 행 | 참조, from<to, 양 끝 정차행, stop_seqs가 범위 안·상대도 서는 역, 모든 칸이 병주 판정, 상대 계통에 양 끝, in/out next가 상대 계통 이웃, terminal이 상대 끝, 대칭 행 | 0 | 20행 |
| 판정 칸이 그려짐 | 병주 판정 칸이 route_parallel 토막에 들어감 | 6 | 上沼垂(신호장) 경계 2칸, 嘉穂신호장–下山田 1칸 × 양 노선. 정차역 사이 칸이 숨은 노드에서 갈라져 §8.1 "칸 안에서 갈라지면 병주 아님"에 해당 (TOP-19) |

### 2.6 열람 전용 (§4.5, §14)

| 규칙 | 확인 방법 | 위반 | 예·판정 |
|---|---|---:|---|
| archive_stop 참조 | line·route 실재, route ∈ line, after가 계통 위 또는 열람 역, before가 계통 위 | 0 | (지난 감사 a_matsumotodoori 고쳐짐) |
| §14 after 필수 | after_id NULL | 22 | TOP-17 |
| 자리 | after–before 사이에 열람 역 기간에 함께 있던 공개 정차역 | 4 | TOP-17 |
| km | 열람 역 km가 after·before의 km_cum 사이가 아님 | 27 | TOP-16 |
| 날짜 | opened > closed | 0 | |
| 중복 | 같은 노선·같은 이름 둘 / 이름이 같은 노선 공개 정차역과 같고 기간 겹침 | 0/0 | |
| 앞 역 기간 | 열람 역 기간에 after 역이 그 계통에 없음 | 65 | 순서 표시용 자리라 정보 (TOP-22) |
| archive_line | line·at 실재, at 공개, at이 line 위 / at NULL | 0 / 34 | at NULL 34 [알려짐 I5], line_id는 73행 모두 NULL(열람 노선은 line 밖) |
| archive_line 기간 | 그 노선 영업 때 at 역이 정차역 아님 | 2 | TOP-22 |

### 2.7 확인하지 못한 것

| 항목 | 까닭 |
|---|---|
| junction 선로 연결의 원문 대조(TOP-03 각 역) | 위키 캐시의 노선도 행을 다시 읽어야 함. 篠ノ井·八代·直江津·盛岡는 직통 운행이 있어 확실, 나머지는 역마다 확인 필요 |
| 같은 group인데 hub가 아닌 86 (TOP-12)이 환승이어야 하는지 | 명세 결정 사항 |
| 숨은 노드 19의 여객 취급 원문 | 이름과 연혁만 봄(①·⑤ 영역) |
| 좌표 정확도 | ④ 영역. 위상에 걸린 곳만 TOP-21 |

## 3. 오류 상세

### TOP-01. `route_link`가 상대 노선마다 후보 하나만 고름

`tools/compile.py`의 환승 생성은 상대 **노선**별로 후보를 모아 `pick()`으로 하나만 고르고(`for ol,cand in sorted(by.items()): o,m=pick(cand,s)`), 분기·이어짐도 junction마다 하나만 고릅니다. 상대 노선의 다른 계통(옛 경로·지선)이나 다른 노드(옛 정류장)가 맡던 기간은 행이 없습니다. §2.9는 "(역, 상대 계통) 한 쌍의 표시"이고, ARCHITECTURE §3.5는 분기 기간을 `route_link` 기간으로 판정하므로 그 날짜에는 아무것도 그려지지 않습니다.

| 계통·역 | 상대 | 상대가 있던 기간 | 행이 덮는 기간 |
|---|---|---|---|
| 芸備線 広島 | 広電 本線(옛 広島駅 정류장 1912–2025, `r_hiroden_main_line_hiroshima_matobacho`) | 1926-01-21~2025-08-03 | 2025-08-03~ (새 広島駅 정류장만) |
| 唐津線 山本 | 筑肥線 虹ノ松原–山本(1929–1983) | 1929-06-20~1983-03-22 | 1935-03-01~ (山本–伊万里 계통만) |
| 小浜線 敦賀 | 北陸本線 敦賀–今庄 杉津 옛 경로 | 1917-12-15~1962-06-10 | 1957-10-01~ |
| 山陽本線 横川 | 可部線 横川–安芸長束 옛 경로 | 1928-11-09~1962-10-01 | 없음 (다른 계통 행만) |
| 琴平線·志度線 瓦町(河原町) | 長尾線 河原町–林道 옛 경로 | 1927-04-22~1951-12-26 | 없음 |
| 土讃線 土佐大津 | 後免線(領石通·一条橋) | 1925-12-05~ | 1985-09-10~ |

같은 node 10, linked hub 26, 같은 group 24 — (계통, 역, 상대 노선) 60, 역 59. 반대쪽 화면도 같은 원인으로 비대칭 20행.

**고침**: `tools/compile.py` route_link 부분. 후보를 상대 **계통**별로 묶고, 한 계통 안에서도 기간이 겹치지 않는 후보(옛·새 노드)는 각각 행을 만듭니다. `pick()`은 같은 기간에 겹치는 후보 사이에서만 씁니다.

### TOP-02. 종류·흐름을 오늘 상태로 전 기간에 씀

`isend=not(mp[0] and mn[0])`과 `flow_of()`·`neighbors(...,cur)`가 `is_cur`(오늘 영업 여부)로 이웃을 찾고, 그 결과를 겹침 기간 전체(`period(s,o)`)에 붙입니다. 역의 끝·통과 상태가 바뀐 날에서 행을 나누지 않습니다.

| 종류 | 수 | 예 |
|---|---:|---|
| continue인데 그 기간 일부는 끝 역이 아님 | 25 | 根室本線 富良野→富良野線 1900–ongoing (富良野–新得은 2024까지 영업), 日高本線 鵡川→富内線 1943–1986 (日高本線은 2021까지 鵡川을 지남), 東北本線 盛岡→山田線 1923–, 北陸本線 敦賀→小浜線 1957–, 播但線 姫路→山陽本線 1894–(姫路–飾磨港 1986까지), 石川線 鶴来→能美線 1932–1980, 竹鼻線 江吉良→羽島線 1982– |
| flow=through인데 상대가 그 기간 내내 그 역에서 끝남 | 30 | 東北本線 八戸→青い森鉄道 2002–2010, 北陸新幹線 金沢↔北陸本線·IR 2015–2024, 北陸本線 福井→福武線 1933–2016, 万葉線 高岡 1948–2014 |
| flow=up·down인데 상대가 그 기간 일부는 지나감 | 30 | 東海道本線·根岸線·京急·相鉄 横浜→東横線 1928– (東横線 横浜–桜木町 2004까지), 北陸本線 直江津→信越本線 1911–2015 |

**고침**: `tools/compile.py`. 링크 기간을 자기·상대 계통의 정차 시작·끝과 인접 edge 집계 경계에서 쪼개고, 쪼갠 기간마다 `isend`·flow·next·terminal을 그날 기준으로 다시 구합니다.

### TOP-03. junction 노선 ID가 이관 뒤 노선에만 붙음

위키 노선도의 분기 행을 노선 이름으로 이을 때(`tools/gen_wiki.py`, `for oid in by_ja[nm]: … junc.append(j); break`) 지금 그 자리를 맡은 3섹 노선 하나만 고릅니다. 같은 역에 남은 JR 노선이나 이관 전 국철 노선 쌍에는 junction이 없어 환승으로만 나옵니다(그 행의 kind가 transfer).

| 역 | 빠진 쌍 (기간) | 있는 junction |
|---|---|---|
| 篠ノ井 | 篠ノ井線 ↔ 信越本線 (1900–) | 篠ノ井線 ↔ しなの鉄道線 |
| 盛岡 | 田沢湖線 ↔ 東北本線 (1921–) | 田沢湖線 ↔ IGR |
| 八代 | 肥薩線 ↔ 鹿児島本線 (1908–) | 肥薩線 ↔ 肥薩おれんじ |
| 直江津 | 北陸本線 ↔ 信越本線 (1911–2015), 日本海ひすいライン ↔ 信越本線 (2015–) | ひすい ↔ 妙高はねうま |
| 穴水 | 七尾線 ↔ 能登線 (국철 1959–1988) | のと 七尾線 ↔ のと 能登線 |
| 金田 | 平成筑豊 伊田線 → 糸田線 (1989–) | 国鉄 伊田線 → 平成筑豊 糸田線 |
| 北見 | 石北本線 → 池北線 (1912–1989) | 石北本線 → ふるさと銀河線 |
| 角館 | 田沢湖線 → 角館線 (1970–1986) | 田沢湖線 → 秋田内陸線 |
| 有田 | 佐世保線 → 松浦線 (1898–1988) | 佐世保線 → 松浦鉄道 西九州線 |
| 宮津·今泉 | KTR 宮津線 → 宮福線 (1990–), フラワー長井線 → 米坂線 (1988–) | 国鉄 宮津線·長井線 쪽 |

(富山 南北接続線 ↔ あいの風 1건은 궤간이 달라 선로 연결이 없을 것으로 보여 뺐습니다.) 18행.

**고침**: `tools/gen_wiki.py` junction 생성에서, 고른 상대 노선과 같은 lineage(이관 전후)이거나 같은 역에 함께 서는 같은 이름 계열 노선도 그 역에서 공존하면 행을 만듭니다. 손으로 넣을 곳이 필요하면 `data/overrides/`에 junction 추가 표(사유 필수, `junction_side.json` 형식)를 둡니다.

### TOP-04. 같은 노선 지선의 다른 끝에 부모 쪽 행이 없음

`tools/gen_wiki.py` 끝의 "같은 노선의 지선은 분기역에서 계통으로 가리킨다"가 `at=r['from']`만 만듭니다. 지선·옛 경로가 부모에 다시 닿는 끝(森, 北広島, 錦糸町, 赤羽, 大宮, 浦上 …)의 부모 화면에는 분기 행이 없습니다(지선 화면 쪽 continue는 있음). from이 부모 계통에 없는 지선 10개(千歳線 苗穂–北広島, 総武本線 御茶ノ水–錦糸町, 身延線 富士–入山瀬, 予讃線 新谷–伊予大洲, 可部線 横川–安芸長束, 足尾線 神土–沢入, 小泉線 太田–東小泉, 長尾線 河原町–林道, 城南線 平和通一丁目–上一万, 白新線 沼垂–新崎)는 부모 쪽 행이 하나도 없습니다. 45끝.

**고침**: 같은 생성부에서 부모(같은 노선 다른 계통)의 정차역에 닿는 끝마다 행을 만듭니다.

### TOP-05. 広電 循環線의 시작일

`data/source/events/private.yaml` 1562·1563행(출처 noritsubushi)이 `l_loop_line`(循環線)을 稲荷町–的場町 1912-11-23, 的場町–比治山下 1944-12-27 개업으로 둡니다. 위키 広島電鉄循環線(revid 110778621) 「旧本線の一部（稲荷町 - 的場町間）と旧皆実線（的場町 - 比治山下間）の区間を分離・統合して2026年に開業」, 「2025年（令和7年）8月3日：…本線の的場町 - 稲荷町間、皆実線の的場町 - 比治山下間が休止」, 「2026年（令和8年）3月28日：…循環線として独立」. 広島電鉄本線(110701122)도 같은 날짜를 적습니다.

결과: 2025년 전 本線은 広島駅–的場町(옛 경로 계통)과 稲荷町–西広島로 끊기고, 皆実線은 的場町에 닿지 않으며, 1912–2025 本線 탑승 기록이 稲荷町–的場町 0.2km를 循環線에 줍니다. 2025-08-03~2026-03-28 휴지도 없습니다(①에 넘김).

**고침**: `data/overrides/events_fix.json`: e_009620(稲荷町–的場町)은 `l_hiroden_main_line` 1912-11-23 개업, e_009621·e_009622(的場町–段原一丁目–比治山下)은 `l_minami_line` 1944-12-27 개업, 2025-08-03 휴지, 2026-03-28 `l_loop_line`으로 `transfer` + 재개.

### TOP-06. 공식 노선의 토막을 따로 노선으로 둠

§2.7은 노선을 공식 명칭(통계·완주 단위)으로, 시대별 경로는 계통으로 둡니다. 아래 8개는 같은 사업자 같은 이름 노선의 토막이 별도 `line`입니다. 완주율이 둘로 나뉘고, 별도 노선이라 노드도 따로 만들어져 같은 역이 두 노드가 됩니다(DBA-013의 博多築港前·千鳥橋가 이 경우).

| 토막 노선 | 부모 | 근거·영향 |
|---|---|---|
| 循環線 博多築港前–千鳥橋 (西鉄) | 循環線 `l_loop_line_nishitetsu` | 공유 노드 0, 같은 이름 노드 2쌍 [알려짐 DBA-013] |
| 循環線 旧線 (西鉄) | 같음 | |
| 循環線 花京院–仙台駅前 (仙台市) | 循環線 `l_loop_line_sendai_city` | n05_fix 「환상선을 한 줄로 쓸 수 없어 나눔」. §2.7은 `closed: true`로 둠 |
| 押切線 柳橋–志摩町, 東郊線 高辻–滝子 (名古屋市) | 押切線, 東郊線 | 押切線 토막은 부모와 공유 노드 0 |
| 鯖浦線 鯖江–越前平井 (福井鉄道) | 鯖浦線 | |
| 清水市内線 西久保–袖師 旧線, 伊敷線 新照院–伊敷 旧線 | 清水市内線, 伊敷線 | 옛 경로. 伊敷線 旧線은 끝 伊敷가 부모에 닿지 않음 (TOP-07) |

**고침**: `data/overrides/n05_fix.json` 해당 8항목의 `db_line_id`를 부모 노선으로 바꾸어 `tools/gen_n05.py`가 부모 노선의 계통(role branch, 순환은 closed)으로 만들게 합니다. 공식 단위가 정말 따로인 것(원문으로 확인)은 남깁니다.

### TOP-07. 역 이전 짝 누락

| 옛 노드 | 새 노드 | 이전일 | 근거 |
|---|---|---|---|
| n_kuwabara 桑原 (会津線 옛 선로) | n_ashinomaki_onsen_minami (국철 시절 이름 桑原, 1987 芦ノ牧温泉南) | 1980-12-01 | 166m, 다른 group → 방문 역 둘, （旧） 없음 |
| n_ishiki 伊敷 (伊敷線 旧線) | n_tamaeshogakkomae 玉江小学校前 | 1952-08-10 | n05_fix 伊敷線 메모 「玉江小学校前=1952 새 선의 伊敷(1962-04-01 개칭)」 |
| n_tamazatomichi 玉里道 | n_gokokujinjamae 護国神社前 | 1952-08-10 | 같은 메모 「護国神社前=옛 玉里道(1953-02-20 개칭)」 |
| n_sakimoricho 崎守町 (室蘭本線 黄金–本輪西 옛 선로) | n_sakimori 崎守 | 1968-09-19 | n05_fix 室蘭本線 메모 「崎守町仮乗降場…을 옮겨 崎守로 개칭」 |
| (의심) n_nishitetsusakaemachi 西鉄栄町 | n_shin_sakaemachi 新栄町 | 1970-04-28 | 天神大牟田線 73.9→73.7km, 205m, 같은 계통 |

伊敷·玉里道는 옛·새 좌표가 0m(좌표 복사)이고, 새 노드에 옛 이름(伊敷 1952–1962, 玉里道 1952–1953)도 없습니다(④에 넘김).

**고침**: `data/overrides/moved.json`에 4쌍(확인 뒤 西鉄栄町) 추가. 옛 이름은 `old_names_fix.json`.

### TOP-08. 이전일 뒤까지 걸치는 옛 정차

`compile.py`의 moved 처리는 옛 정차 끝의 **하한**이 이전일보다 늦을 때만 자릅니다(`(lohi(s['valid_to'])[0] or '9999')>d`). 끝이 연도만 아는 값이면 상한이 이전일 뒤로 남습니다. 金山橋→金山 1989-07-09(옛 끝 1989-XX-XX), 平田橋→上小田井 1991-10-27, 境川→岐南 1980-09-20, 大篠津→米子空港 2008-06-15, 大長→北勢中央公園口 1997-04-01, 大井田→大安 1986-03-25, 東風連→名寄高校 2022-03-12, 原町田→町田 1980-04-01. 이전일이 정확하므로 옛 노드는 그날 끝나야 하고, 지금은 범위 날짜 기록이 옛·새 노드 모두에서 탈 수 있게 됩니다.

**고침**: 같은 줄을 상한(`[1]`) 기준으로 바꿉니다.

### TOP-09. 옛 선로 계통이 본선 edge를 같이 씀

- `r_hokuriku_main_line_kurikara_isurugi`(倶利伽羅～石動): edge는 본선과 같은 e_003094 하나(`also`), 정차 1909-06-15~2015-03-14. n05_fix 「日本国有鉄道 北陸本線 倶利伽羅–石動 旧線」은 1955-12-05 폐지(新倶利伽羅トンネル 경유로 교체, km 6.9→6.8)인데, `tools/gen_source.py` `build_chain`이 같은 노드쌍을 `shared`로 보고 본선 edge를 재사용해 폐지가 사라졌습니다. 106년 동안 같은 구간을 두 계통으로 고를 수 있습니다.
- `r_hakushin_line_higashi_niigata_nuttari`(沼垂～新崎): 沼垂 종착 시절(1956–1958) 계통인데 大形·新崎 정차가 ongoing이라 1957 뒤 大形–新崎(e_002170)을 본선과 함께 고를 수 있습니다(e_002168·2169도 `also`로 같이 씀). 大形의 continue 행(TOP-02 표에도 걸림)도 여기서 나옵니다.

**고침**: `gen_source.py` `build_chain`에서 join 옛 선로가 본선과 같은 노드쌍이면 재사용하지 말고 `alt='old'` 병렬 edge + `relocate`로 만듭니다(倶利伽羅). 白新線은 `stop_dates.json`으로 沼垂–新崎 계통의 大形·新崎 정차를 1958-04-29에 자르거나 계통을 沼垂–上沼垂로 줄입니다.

### TOP-10. 같은 역인데 group·hub 없음 (손 표가 무시됨)

`hand_tables.json` SAME_STATION에 「糠ノ目=高畠」「中津=中津」이 있는데 DB는 다른 group(g_nukanome / g_takahata, g_nakatsu / g_nakatsu_oita_transportation)이고 hub도 없어 환승 행이 0입니다. `gen_source.py` 묶음 규칙이 `dist(a['pt'],b['pt'])`를 쓰는데 좌표가 나중에(n05·wikidata) 붙는 노드는 `pt`가 없어 `dist`가 1e9를 돌려 조용히 빠집니다. 丹後山田(加悦鉄道, n05 좌표)=与謝野(옛 丹後山田, 6m)도 같은 모양으로 group이 다릅니다(hub는 있음). 결과: 방문 역 수가 둘로 세지고(group), 中津·糠ノ目는 1913–1975·1922–1974 기간 환승이 화면에 없습니다.

**고침**: `tools/gen_source.py` 그룹 단계에서 좌표가 없으면 최종 좌표(`data/source/positions`)로 다시 재거나, SAME_STATION 항목은 거리 없이 묶고 적용 못 한 항목은 실패로 냅니다. hub 초안도 같이.

### TOP-11. hub 빠짐

前橋(両毛線 n_maebashi)–前橋駅前(東武 前橋線 n_maebashi_ekimae) 71m, 津軽二股(津軽線)–津軽今別(海峡線, 1988–2016) 86m. 둘 다 group·hub가 없어 그 기간 환승 행이 0입니다(津軽二股는 2016 뒤 奥津軽いまべつ와의 hub만 있음).

**고침**: `data/source/hubs/hubs.yaml` 생성(gen_wiki.py hub 초안)에 두 쌍을 넣고, 이름이 다른 쌍은 `data/overrides/hub_pairs.json`에.

### TOP-16. 열람 역 km 축

27행의 km가 앞뒤 공개 역 `km_cum` 사이가 아닙니다. 대부분 옛 km 축(기점 이동, 반대 방향)입니다. 筑前庄 1.6km가 西新 8.9–姪浜 11.7 사이, 京急 浜川 3.1이 鮫洲 3.9–立会川 4.7 사이, 西鉄 甘木線 7역이 반대 방향 km, 三河線 北寺津 47.2가 寺津 7.9 옆. 노선 화면에 km를 그대로 그리면 순서와 숫자가 어긋납니다.

**고침**: `tools/gen_wiki.py` 열람 역 생성에서 앞뒤 공개 역의 위키 km와 DB `km_cum`의 차로 옮겨 적고, 옮길 수 없으면 km를 비웁니다(§4.5 `? km`).

## 4. 의심 상세

| ID | 내용 | 끝내는 방법 |
|---|---|---|
| TOP-12 | 같은 group 다른 hub 노드 86쌍(60 group)에 환승 행 없음. §2.9 표 3순위는 "같은 node, 같은 group 또는 같은 hub → 환승 캡슐"인데 compile은 hub 구성원만 후보로 봄(`near`). 예 早稲田(都電–東西線 0.71km), 芦屋(JR–阪神 0.74km), 浅草(都営·東武·メトロ–TX 0.57km) | 명세를 "hub(또는 같은 node)"로 좁히거나, compile `near`에 같은 group을 넣음 |
| TOP-13 | 浅草(n_asakusa_toei: 都営浅草線 1960– + 都電 千住線 1908–1971), 板橋本町(n_itabashi_honcho: 三田線 1968– + 都電 志村線 1944–1966) — 다른 노선 선형 끝이 0.35·0.30km | 정류장 자리를 원문으로 확인해 노드 분리 (S5·DBA-015와 함께) |
| TOP-14 | 鷹ノ巣(奥羽本線)와 阿仁合線 鷹ノ巣(1934–1986, 지금 秋田内陸 鷹巣) 92m, 人吉(肥薩線)와 湯前線 人吉(1924–1989, 지금 人吉温泉) 111m — 국철 시절 한 역인데 노드·group 둘 | 국철 시절 같은 역이면 같은 group (노드는 사업자가 바뀌어 둘이어도 됨) |
| TOP-15 | 津軽今別(海峡線 1988–2016)과 奥津軽いまべつ(北海道新幹線 2016–)는 같은 선로(삼선궤) 위 같은 역 시설·JR北海道, 2016-03-26에 바뀜. 노드·group 둘 | 같은 group(또는 moved) |
| TOP-17 | after NULL 22: 富内線 4역(沼ノ端–豊城 옛 구간인데 鵡川 앞에 km 4.8~19.7로 놓임), 京王 停車場前, 天理線 2, 湯の山線·内部線 4 등. 자리 4: 東日野(西日野 twin [S9]), 藤島神社前, 北山口, 東山東 | 富内線은 옛 구간 계통이나 열람 노선으로, 나머지는 `before`만이면 계통 앞이라는 표시를 명세에 적기 |
| TOP-18 | 新潟 옛 경로 계통(亀田–沼垂–新潟(旧))의 亀田 정차가 ongoing → 信越本線 亀田의 분기 행 1897–ongoing, 1958 뒤 next 없음 | 계통 끝 정차를 다른 정차가 모두 끝난 날에 자름 (compile) |
| — | 西鉄栄町→新栄町 이전 짝 (TOP-07) | 위키 新栄町駅 연혁 확인 |

## 5. 정보

- TOP-19: `parallel_runs.json` 白新線/信越 上沼垂–新潟, 関西/環状 今宮–新今宮, 鹿児島/日豊 小倉–西小倉의 `period` 끝이 1987-04-01이지만 겹침은 지금까지. compile은 attr로 기간을 다시 재므로 결과 영향 없음. 병주 true 판정 3칸(上沼垂 2, 嘉穂신호장 1)은 정차역 사이 칸이 숨은 노드에서 갈라져 그려지지 않음 → 판정을 false(칸 안 갈라짐)로 바꾸거나 메모.
- TOP-20: 두 노선이 공존한 날이 없는 junction 168행(국철↔3섹 경계의 continue 등)은 아무 행도 만들지 않음. 정리 대상.
- TOP-21: 新垂井(n02 approx)이 垂井 73m, 塩竈(塩釜線, n05)이 本塩釜 31m — 실제로는 떨어진 역. hub·group 판정을 흔듦.
- TOP-22: 西鉄 北方線 `at`=川原口(1985 개업 모노레일역, 北方線은 1980 폐지), 西遠鉄道 `at`=宮口(1940 개업, 西遠은 1937 폐지).
- TOP-24: 숨은 노드 `export_name`이 `[上沼垂]`처럼 괄호인 것 10, `嘉穂`·`東高島`·`田端信号場`처럼 괄호 없는 것 9.
- 立山黒部貫光 `l_tateyama_cable_car`는 떨어진 두 케이블(黒部湖–黒部平 main, 立山–美女平 branch)을 한 노선으로 둠. 鉄道要覧 「鋼索線」 단위로 보이나 확인 필요.

## 6. [알려짐] 재측정

| 항목 | 지난 값 | 이번 |
|---|---|---|
| DBA-013 博多築港前·千鳥橋·豊橋 新川 | 노드 둘 | 그대로. 博多築港前·千鳥橋는 TOP-06(토막 노선)이 원인 |
| DBA-015 瑞江 | 1.46km | 선형 끝 사이 1.74km, 그대로 |
| 住吉(長崎) 노드 둘 | 17m | 그대로 |
| S5 名古屋城·大曽根·車道·京都駅前 | | 그대로 (+浅草·板橋本町 TOP-13) |
| S9 같은 노선 같은 이름 동시 정차 | 19행 | 内子·神戸·西日野·大洗·稲永町·東青山 등 그대로 |
| S10 hub 지름 | 8 | group 지름 > 0.5km 58로 다시 잼 |
| 병렬 edge 2, 이설 계통 이웃 edge 4, 0km 12, side 빔 18, archive_line at NULL 34 | | 그대로 |
| 中津·片町 다른 group | 의심 | 中津는 원인(TOP-10)을 찾아 오류로 |
| §2.7 같은 노선 두 계통 같은 edge 8 | invariants 통과로 봄 | 정차 기간으로 재면 北陸 倶利伽羅–石動·白新線은 실제 겹침 (TOP-09) |
| node_move 옛·새 좌표 같음 | 4 | 16 (DBA-014 11쌍 포함) |

## 부록 A. 검사 코드 (핵심)

사본 경로 `S`만 바꾸면 그대로 돌아갑니다. `python3 -I a.py`.

```python
import sqlite3,json,collections,itertools,math
S='…/snap-2026-11-06.3'
db=sqlite3.connect(f'file:{S}/master.sqlite?mode=ro',uri=True);D=collections.defaultdict
DIM=[31,29,31,30,31,30,31,31,30,31,30,31]
def lohi(e):
    if not e:return (None,None)
    if e=='ongoing':return ('9999-12-31',)*2
    y,m,d=e.split('-')
    if m=='XX':return (f'{y}-01-01',f'{y}-12-31')
    if d=='XX':return (f'{y}-{m}-01',f'{y}-{m}-{DIM[int(m)-1]:02d}')
    return (e,e)
ov=lambda a0,a1,b0,b1:a0<b1 and b0<a1
R=lambda q:db.execute(q).fetchall()
nodes={r[0]:dict(kind=r[1],g=r[2]) for r in R('select id,kind,group_id from node')}
routes={r[0]:dict(line=r[1],role=r[2]) for r in R('select id,line_id,role from route')}
rs=D(list)
for r in R('select route_id,seq,node_id,is_stop,is_extension,valid_from_lo,valid_to_hi,valid_to from route_stop order by 1,2'):
    rs[r[0]].append(dict(r=r[0],seq=r[1],n=r[2],stop=r[3],ext=r[4],lo=r[5] or '0000',hi=r[6] or '9999',vt=r[7]))
S_={(s['r'],s['seq']):s for v in rs.values() for s in v}
nstops=D(list)
for v in rs.values():
    for s in v:
        if s['stop'] and not s['ext']:nstops[s['n']].append(s)
links=[dict(zip('r seq ol orr kind side at on nxt term flow fs vf vt'.split(),x)) for x in R('select * from route_link')]
for l in links:l['lo']=lohi(l['vf'])[0] or '0000';l['hi']=lohi(l['vt'])[1] or '9999'
hubs=D(set);hub_of=D(set)
for h,n in R('select hub_id,node_id from hub_member'):hubs[h].add(n);hub_of[n].add(h)
groups=D(set)
for n,v in nodes.items():groups[v['g']].add(n)
LK=D(list)
for l in links:LK[(l['r'],l['seq'],l['ol'])].append((l['lo'],l['hi']))
def gaps(iv,a,b):
    out=[];cur=a
    for x,y in sorted(iv):
        if y<=cur:continue
        if x>cur:out.append((cur,min(x,b)))
        cur=max(cur,y)
    return out+([(cur,b)] if cur<b else [])

# TOP-01/TOP-12: 같은 node·group·hub 상대 정차 기간을 route_link가 덮는가
miss=[]
for v in rs.values():
    for s in v:
        if not s['stop'] or s['ext']:continue
        near={s['n']}|groups[nodes[s['n']]['g']]|set().union(*[hubs[h] for h in hub_of[s['n']]] or [set()])
        for m in near:
            for o in nstops[m]:
                L=routes[o['r']]['line']
                if L==routes[s['r']]['line']:continue
                a,b=max(s['lo'],o['lo']),min(s['hi'],o['hi'])
                if a<b and gaps(LK.get((s['r'],s['seq'],L),[]),a,b):miss.append((s['r'],s['seq'],s['n'],L,o['r'],m,a,b))
print('TOP-01/12 후보',len(miss))   # 관계(같은 node/group/linked hub/먼 hub)로 나눠 셈

# TOP-02: continue 행인데 그 기간에 양쪽에 정차역이 있던 때가 있음
def side(r,seq,step,lo,hi):
    L=[x for x in rs[r] if not x['ext']];i=next(k for k,x in enumerate(L) if x['seq']==seq);k=i+step
    while 0<=k<len(L):
        if L[k]['stop'] and ov(L[k]['lo'],L[k]['hi'],lo,hi):return True
        k+=step
    return False
print('TOP-02 continue',sum(1 for l in links if l['kind']=='continue' and side(l['r'],l['seq'],-1,l['lo'],l['hi']) and side(l['r'],l['seq'],1,l['lo'],l['hi'])))

# TOP-04: 지선 끝이 같은 노선 다른 계통에 닿는데 부모 쪽 행이 없음
n4=0
for r,Rr in routes.items():
    if Rr['role']!='branch':continue
    L=[x for x in rs[r] if not x['ext']]
    for e in (L[0],L[-1]):
        for o in nstops[e['n']]:
            if o['r']!=r and routes[o['r']]['line']==Rr['line'] and ov(o['lo'],o['hi'],e['lo'],e['hi']):
                if not any(l['r']==o['r'] and l['seq']==o['seq'] and l['orr']==r for l in links):n4+=1
print('TOP-04',n4)

# TOP-08: moved 옛 정차 끝 상한이 이전일 뒤
print('TOP-08',[(o,d) for o,n,d in R('select * from node_move') for s in nstops[o] if s['hi']>d])

# TOP-09: 같은 노선 두 계통이 같은 edge를 같은 때 (양 끝 정차행 ∩ 집계)
att=D(list)
for e,l,lo,hi in R('select edge_id,line_id,valid_from_lo,valid_to_hi from edge_attr'):att[e].append((l,lo,hi))
E={r[0]:(r[1],r[2]) for r in R('select id,from_node,to_node from edge')}
use=D(list)
for r,x in R('select route_id,edge_id from route_edge'):
    sp={s['n']:s for s in rs[r] if s['stop'] and not s['ext']};a,b=E[x]
    if a in sp and b in sp:
        lo,hi=max(sp[a]['lo'],sp[b]['lo']),min(sp[a]['hi'],sp[b]['hi'])
        if any(l==routes[r]['line'] and ov(lo,hi,p,q) for l,p,q in att[x]):use[(routes[r]['line'],x)].append((r,lo,hi))
print('TOP-09',[(k,v) for k,v in use.items() if len(v)>1 and any(ov(p[1],p[2],q[1],q[2]) for p,q in itertools.combinations(v,2))])
```

나머지 검사(노드 공동 사용, 선형 끝 거리, 이전 짝 찾기, junction 사슬, 병주, 열람 자리)는 2절 "확인 방법"의 조건을 같은 적재부 위에 그대로 옮긴 것입니다. 선형 끝은 `edge_shape.polyline`(소수 5자리 encoded polyline, 위도 먼저)을 복호화해 edge 양 끝 노드 좌표와 가까운 방향으로 끝을 고릅니다.
