# DB 2차 감사 (4) 이름·ID·좌표·선형 (2026-11-06, 판 2026-11-06.3)

대상은 스냅샷 `snap-2026-11-06.3/master.sqlite`, `names.sqlite`(판 2026-11-06.3)만입니다. `build/`는 읽지 않았습니다. 원천은 커밋 `340460f`(판 2026-11-06.3)의 `data/source/*`(작업 트리에서 다시 생성 중이라 `git show HEAD:`로 꺼내 읽음), `data/overrides/*`, `data/imports/stationdb/station.csv`, 위키 캐시, `data/base/pref.geojson`을 읽기만 했습니다. 저장소에서 쓴 파일은 이 문서와 `db-audit2-names-2026-11-06.json` 둘뿐입니다.

검사 스크립트는 세션 임시 폴더(`…/연구 원자료/a4/*.py`)에 있고, 다시 돌릴 수 있게 핵심 조건을 부록 A에 SQL·파이썬으로 옮겼습니다. 모두 `python3 -I`, 읽기 전용 URI(`mode=ro`)로 열었습니다. 규칙 표기(ko·en)를 다시 만들어 비교할 때만 저장소의 `tools/ko.py`, `tools/en_rules.py`를 import했습니다(`NW_OFF=1`, 나무위키 표 끔).

`[알려짐]`은 1차 감사(`db-audit-2026-11-06.md`)나 그 0절 반영 기록에 이미 있는 항목입니다.

## 1. 요약

| # | 내용 | 수 | 등급 | 새 항목인가 |
|---|---|---:|---|---|
| A2-01 | 伊香保線 商工会議所前과 前橋線 商工会議所前(다른 정류장)이 노드 하나 `n_shokokaigishomae_ikaho`. DBA-017이 좌표를 前橋 쪽으로 옮겨 伊香保線 0.2km 구간이 직선 13.6·13.9km, 선형 2 edge 사라짐 | 1 노드, 2 edge | 오류 | 새 항목 (DBA-017의 부작용) |
| A2-02 | 일본어 표시 이름에 station_database 동명 구분 괄호 (`広瀬(石川)`, `松森(名古屋鉄道)`) | 43 + 노선별 1 | 오류 | 새 항목 |
| A2-03 | 노리츠부시 주석이 든 일본어 이름 (`とうきょうスカイツリー／押上`, `恋路(臨)`, `会津高原(旧会津滝ノ原)`, `大和八木／八木西口` 등) | 기본 1 + 노선별 8 | 오류 | 새 항목 |
| A2-04 | 옛 이름의 한국어 읽기를 먼 곳의 같은 한자 역에서 가져옴, 또는 지금 이름을 그대로 씀 (高山→타카야마, 岩内→이와나이, 小山→오야마, 長野原→나가노하라쿠사츠구치, 所沢御幸町→신토코로자와) | 5 (+의심 2) | 오류 | 새 항목 |
| A2-05 | 本町二丁目 2역의 kana가 `ほんまちさんちょうめ`, ko가 `혼마치산초메`(3초메) | 2 | 오류 | 새 항목 (n_honmachi_2_chome ID 문제는 [알려짐]) |
| A2-06 | 부역명 처리가 언어마다 다름. en이 읽기를 통째로 이어 붙임 (`Hasumachibabakinenkoemmae`), kana에 공백 | en 3, kana 1 (+불일치 11) | 오류 | 새 항목 |
| A2-07 | 甲浦 옛·새 노드: 옛 노드에 （旧）·(구)·(old) 표시 없음. ko·en이 두 노드 똑같음 | 1쌍 | 오류 | 새 항목 |
| A2-08 | 노선 읽기가 틀림 (中川短絡線 `いせなかがわ`, 西九州線 `まつうらてつどう`, 山代線 `…やましろえん`, 内子線 `よさん・うちこせん`, 軌道線 `きどうほう` 등) | 9 | 오류 | 새 항목 |
| A2-09 | 노선 한국어 이름이 깨짐: N05 복합 이름 13개가 `센`+구간으로 붙음 (`니시테츠 준칸센하카타칫코마에치도리바시`), `테츠도선`(淡路交通線), `호쿠리츠 철도`(오타), `이즈하코네 철도 궤도 호` 등 | 18 | 오류 | 새 항목 |
| A2-10 | 노선 영어 이름에 `線`이 `sen`으로 남거나 틀린 읽기에서 나옴 (`Yamaguchisen'otogi Line`, `Tramway Ho Line` 등) | 4 | 오류 | 새 항목 |
| A2-11 | 계통 이름이 끝 역 이름보다 낡음 (ko 11: `오야마코사쿠센~아후리진자`, `미야와키~츠쿠바산코사쿠테츠도센` 등, ja·en 2) | ko 11, ja 2, en 1 | 오류 | 새 항목 |
| A2-12 | 같은 구성원의 환승 묶음이 두 번 (station_database 근접 + 위키) | 108쌍 (216 hub) | 오류 | 새 항목 |
| A2-13 | `ん` 뒤 모음에서 `n'`이 빠진 규칙 영어 이름 (`Shinobihiro`, `Kanommachi`) | 50 | 오류 | 새 항목 |
| A2-14 | 東山・おかでんチャギントンミュージアム駅의 ko가 옛 이름 `히가시야마·오카덴뮤지엄역` | 1 | 오류 | 새 항목 |
| A2-15 | 循環 → `준칸`처럼 일반 한자어를 음차한 노선 ko (§9.3은 한국 한자음) | 6 | 오류 | 새 항목 |
| A2-16 | `Matsueingurisshugademmae` (松江イングリッシュガーデン前) | 1 | 오류 | 새 항목 |
| S2-01 | 옛 이름(기간 있음) ja 397행 중 ko 116, en 0, kana 0. 노선별 이름 ja 115 중 en 0 | — | 의심 | 새 항목 |
| S2-02 | 노선 kana 앞에 회사 읽기 (`網干線` `さんようでんてつあぼしせん`) | 262 / 997 | 의심 | 새 항목 |
| S2-03 | 회사 이름뿐인 노선 kana에 `せん` 없음 (`愛知環状鉄道線` `あいちかんじょうてつどう`) | 약 45 | 의심 | 새 항목 |
| S2-04 | 노선별 이름에서 드러난 역 합침: 橿原線 八木西口가 노드 없이 大和八木에, 尼崎港線 尼崎(임시승강장)이 JR 尼崎 노드에 | 2 | 의심 | 새 항목 |
| S2-05 | 사철 노선인데 ko에 사업자 짧은 이름이 없음 (`호조선` = 北条鉄道 北条線, 国鉄 北条線과 같은 표기) | 34 (rule) | 의심 | 새 항목 |
| S2-06 | 사업자 짧은 이름 `센다이시 지하철`·`나고야 시영 지하철`이 노면전차 노선에 붙음 | 2 사업자 | 의심 | 새 항목 |
| S2-07 | 영어 `-mae` 표기 다섯 가지, 접두 `Higashi-` 하이픈이 규칙 출처 안에서도 갈림 | 686 / 238 | 의심 | 새 항목 |
| S2-08 | 일반명사 노선 영어 이름 `Loop Line` 3개에 회사 약칭 없음 (§9.1) | 3 | 의심 | 새 항목 |
| S2-09 | 읽기가 다른 같은 한자 역이 나무위키 제목을 나눔: 穴太 あのう/あのお `아노`, 大和田 おおわだ/おわだ `오와다` | 2 (+近江今津 [알려짐]) | 의심 | 2건 새 항목 |
| S2-10 | 환승 묶음 ID가 JR 역 이름 규칙(§2.10)과 다름 (`hub_keikyu_tsurumi`에 JR `n_tsurumi`) | 125 | 의심 | 새 항목 |
| S2-11 | 米島口: 伏木線(1948~1971) 노드가 같은 회사 같은 정류장인데 따로, 좌표 none, 이름에 2010년대 부역명 | 1 | 의심 | 새 항목 |
| S2-12 | 이웃 역 직선거리가 km보다 큼 (현행 SD 좌표끼리 7: 肥薩線 大隅横川–植村 2.0km/2.7km, 武豊線 半田–東成岩 1.7/2.3 등) | 45쌍 | 의심 | 일부 [알려짐] |
| S2-13 | 이름표에만 있고 master에 없는 열람 전용 ID (archive_lines.json drop/exclude 44개, 蒲蒲線 포함) | 44 ID, 88행 | 의심 | 새 항목 |
| S2-14 | 노선·ID 모양: `l_seihosensabaeechizenhirai`, `l_yamaguchisenotogi_line`, `l_blue_line_line_1` | 5 | 의심 | 새 항목 |
| S2-15 | 20m 안의 다른 group 노드 (丹後山田=与謝野, 西長田=西長田ゆりの里, 東古市=永平寺口 0m 등) | 12쌍 + 동일 좌표 3 | 의심 | 일부 [알려짐] |
| S2-16 | `n_takahata_yamagata_kotsu` 좌표가 N05인데 `precise` | 1 | 의심 | 새 항목 |
| I2-01 | 동일 좌표 다른 group 14묶음 (S6 18 → 14) | 14 | 정보 | [알려짐] |
| I2-02 | 선형 끝 ↔ 역 300m 초과 42 (현행 26은 한 노드의 떨어진 승강장) | 42 | 정보 | [알려짐] 43→42 |
| I2-03 | 선형 없는 edge 13 (11 + A2-01로 생긴 2), 점 하나뿐인 선형 9 (모두 0km edge) | 13 / 9 | 정보 | [알려짐] + 2 |
| I2-04 | kana의 `・` 30자, 공백 23자 (ja에 있는 글자를 그대로 옮김) | 44행 | 정보 | 새 항목 |
| I2-05 | 사업자·계통 kana 없음, `reading_source`·`source_title` 0행, `checked`는 ko만 | — | 정보 | 새 항목 |
| I2-06 | 별칭 완전 중복 55 (계통 노리츠부시 53, 옛 이름 2) | 55 | 정보 | 새 항목 |
| I2-07 | `n05_fill.yaml` 111개 중 55개가 다른 선형 파일에도 있음(그중 n02 3·osm 9는 쓰이지 않음). `e_090001`은 n05 태그지만 `n05.yaml`이 아니라 `source_patch`에서 옴 | 55 / 1 | 정보 | 새 항목 |
| I2-08 | 계통 이름 ko·en 없음 16, 열람 전용 en 없음 498, 노선 kana 없음 36, `n_honmachi_2_chome` 이름 三丁目, Honmachi 15 | — | 정보 | [알려짐] |

오류 16종, 의심 16종, 정보 8종입니다. 고칠 값과 근거는 `db-audit2-names-2026-11-06.json`(40건)에 있습니다.

## 2. 규칙 추적표

"위반 0"인 규칙도 확인 방법을 남겼습니다. SQL은 `names.sqlite`를 `nm`으로 ATTACH한 `master.sqlite`에 돌린 조건입니다. 기본 이름은 `line_id`·`valid_from`·`valid_to`가 모두 NULL인 행입니다.

### 2.1 이름 존재·중복 (§2.6 이름, §14.2)

| 규칙 | 확인 방법 | 위반 | 예 |
|---|---|---:|---|
| 공개 노드(13,571)·노선(1,033)·사업자(282)·운전 계통(17)에 ja·ko·en 기본 이름 | `node_public`/`line`/`operator`/`service` × 언어, 기본 이름 행 없음 | 0 | |
| 계통(1,133)에 ja·ko·en | 같은 방법 | ko 16, en 16 | 연락선·화물선 16계통 [알려짐 I1] |
| 열람 전용(498)에 ja·ko | 같은 방법 | 0 (en 498 없음 [알려짐 I2]) | |
| 공개 역·노선의 기본 ja에 kana | `kana` NULL/'' | 역 0, 노선 36 [알려짐 I3], 열람 전용 5 | 西鉄北九州線 등 열람 전용 노선 5 |
| 사업자·계통 kana | 같은 방법 | 282 / 1,133 없음 | 명세가 요구하지 않음 (I2-05) |
| 실체·언어당 기본 이름 하나 | 기본 행 `count>1` | 0 | |
| (실체, 언어, 노선, 기간) 키 중복 | `group by` 6열 | 0 | |
| 이름이 가리키는 실체가 있음 | 이름의 id가 해당 표·공개 뷰에 없음 | 88행 (열람 전용 44 ID) | `a_kamakama_line` 蒲蒲線 (S2-13) |
| 노선별 이름의 `line_id`가 실제 노선 | `line`에 없음 | 0 | |
| 노선별 이름은 그 노선 정차역에만 | 그 노선 계통에서 is_stop=1인 적 없음 | 0 | |
| 노선별 이름은 ja·ko 짝 | ja에만 있음 | 1 | n_nishi_5_chome 鉄北線 `西5丁目` ko 없음 |
| 노선별 이름 en | en 행 수 | 0 / 115 | S2-01 |

### 2.2 옛 이름 (§9.2 기간, §2.2 rename, §14.2 조회 순서)

| 규칙 | 확인 방법 | 위반 | 예 |
|---|---|---:|---|
| EDTF 형식 | `^\d{4}(-(\d\d|XX)){0,2}$` 밖 | 0 | |
| 시작 < 끝 | 하한·상한 비교 | 0 | |
| 끝 없음(현재까지 옛 이름) 금지 | `valid_to` NULL | 0 | 시작 NULL 18행은 "개업부터" 뜻으로 허용 |
| 같은 실체·언어·노선의 옛 이름 기간 겹침 | 정렬 후 앞 끝 > 뒤 시작 | 0 | 빈 틈 1 (n_kitsunegasaki 1944~1968, 기본 이름 시기로 정상) |
| 옛 이름 기간이 그 역의 정차 기간 밖 | 정차 `min(lo)`·`max(hi)`와 비교 | 0 | |
| 폐역의 옛 이름이 폐지일까지 가서 기본 이름이 한 번도 안 쓰임 | 옛 이름 끝 ≥ 정차 끝 | 0 | |
| 미래 날짜 | `valid_to` > as_of | 0 | |
| ja 옛 이름마다 ko | (실체, 노선, 기간) 짝 | ja 397 중 ko 116 | S2-01 |
| ko 옛 이름이 ja 옛 이름의 읽기 | ko 옛 이름 = 기본 ko인데 ja가 다름 / 같은 이름 SD 역이 5km 안에 없고 읽기가 지금 읽기와 어긋남 | 2 + 3 (+의심 2) | A2-04 |
| ko 옛 이름에 ja 짝 | 역방향 | 0 | |
| 옛 이름 별칭(`old_title`) | 옛 이름 397 ↔ 별칭 410 | 0 누락 | 별칭 쪽 13은 노선 2·중복 2 등 |

### 2.3 읽기 kana (§14.2, §9.1)

| 규칙 | 확인 방법 | 위반 | 예 |
|---|---|---:|---|
| 히라가나·`ー`만 | `^[ぁ-ゖー]+$` 밖 | 44행 | 모두 `・`(30자)·공백(23자). 가타카나·한자·괄호 0 (E15 [알려짐] 고쳐짐) |
| 작은 글자로 시작, `ーー`·`っっ` | 정규식 | 0 | |
| 가나만 있는 ja는 kana = 히라가나 변환 | `kata2hira(ja) != kana` | 3 | `ディズニーリゾートライン` `…らいんせん`, `ケーブルカー` `たかおけーぶるかー`·`みたけ…` |
| 丁目 숫자 = kana 숫자 = en 숫자 = ID 숫자 | 네 값 추출 비교 | 3 | 本町二丁目 2역 kana `ほんまちさんちょうめ` (A2-05), n_honmachi_2_chome [알려짐] |
| 노선 kana = 노선 이름 읽기 (회사 이름 없음) | 회사 읽기(`PREFIXES`, 鉄道·電鉄·地下鉄·交通·市電 읽기)가 있는데 ja에 그 글자 없음 | 262 | S2-02 |
| 노선 kana가 ja와 맞음 | `線`으로 끝나는데 kana가 `せん`으로 안 끝남 등 손 확인 | 9 오류 + 약 45 | A2-08, S2-03 |
| 부역명 괄호의 kana 처리 | 괄호가 있는 공식 이름 11개 | 5는 넣고 6은 뺌 | A2-06 |

### 2.4 영어 (§9.1)

| 규칙 | 확인 방법 | 위반 | 예 |
|---|---|---:|---|
| ASCII | 비ASCII | 6 | `·` [알려짐] |
| 앞뒤·연속 공백 | | 0 | E14 고쳐짐 |
| `'` 뒤 대문자 (`.title()` 부작용) | `'[A-Z]` | 0 | |
| 소문자로 시작 | | 0 | |
| `ん`+b·p·m → m (rule 역) | kana에 `ん[ばびぶべぼぱ…まみむめも]`, en에 `n[bpm]` | 15 | Honmachi 丁目 [알려짐, 의도] |
| 같은 규칙, 위키데이터 라벨 | | 164 n / 117 m | 출처 순위상 허용. 앱 안 표기는 갈림 (정보) |
| `ん`+모음·y → `n'` (rule 역) | kana `ん[あいうえおやゆよ]`, en에 `'` 없음 | 50 | A2-13 |
| 훈령식 (si, ti, tu, hu, zi) | 정규식 (rule 역) | 0 | 걸린 2건은 `chu`의 오탐 |
| 丁目 `N-chome` | 형식 | rule 0 (269 + 지명 없는 1~6-chome 5) | `四条廿丁目` `Yojonijutchome` (廿 미처리, 정보) |
| `-mae` 표기 하나 | 끝 형식 분류 | 5가지 | S2-07 |
| 접두 `Higashi-` 등 하이픈 | 東·西·南·北·新 + 2자 이상 | rule 안에서 하이픈 32 / 붙임 206 / 띄움 13 | S2-07 |
| 외래어는 영어로 | rule 역 중 가타카나 3자 이상 31 | 1 오류 + 의심 4 | A2-16, `Puru Center-mae`·`Reja Center-mae`·`Gurandomae` |
| 노선 `線`→Line | 이름 중간 `線`이 `sen`으로 | 4 | A2-10 |
| 일반명사만 남은 노선 이름에 회사 약칭 | 같은 en을 쓰는 노선 47묶음 중 일반명사 | 1묶음 3 | `Loop Line` (S2-08) |
| 노선별·옛 이름 en | | 0행 있음 | S2-01 |

### 2.5 한국어 (§9.2, §9.3, §2.6)

| 규칙 | 확인 방법 | 위반 | 예 |
|---|---|---:|---|
| ko에 가나·한자 | 정규식 | 0 | |
| 앞뒤·연속 공백, 자모 낱자 | | 0 / 0 | |
| 라틴 문자 | 29 | 0 | 모두 JR·YRP·J빌리지·IGR 등 공식 표기 |
| 이상한 문장부호 | `[^가-힣A-Za-z0-9 ·\-~().'&]` | 1 | `메이지진구마에〈하라주쿠〉` (나무위키 제목, 정상) |
| 지역 구분 괄호를 뗌 | `(…)` (구 제외) | 0 | `니시테츠후쿠오카(텐진)`은 역명의 일부 |
| 규칙 ko = 규칙(kana) | `tools/ko.py station(kana, ja)`(나무위키 끔)로 다시 만듦 | rule 7, estimated 0, rule+wikidata 0 | 7개 모두 부역명 괄호 처리 차이 (A2-06) |
| hand ko | 같은 비교 15 차이 | 1 | A2-14 (나머지 14는 공항·외래어 손 표기로 정상) |
| 읽기가 다른 같은 한자 역의 나무위키 제목 공유 금지 | 같은 ja, 다른 kana, 같은 ko, 하나 이상 namuwiki | 3 | 近江今津 [알려짐], 穴太, 大和田 (S2-09) |
| 다른 한자·다른 읽기가 한 제목 | 같은 방법, ja 다름 | 60 | 장음 탈락으로 같아지는 정상 표기 (아소, 오노 등). 위반 아님 |
| 노선 ko: 나무위키 없으면 사업자 짧은 이름 + 노선 (§9.3) | 국철·JR 밖 사업자인데 ko에 사업자 짧은 이름 없음 | 44 (rule 34, hand 9, namuwiki 1) | S2-05 |
| 노선 ko 일반 한자어는 한국 한자음 | `준칸`·`칸조`·`린코`·`혼센`·`시센`·`렌라쿠` | 6 | A2-15 |
| N05 복합 노선 이름(공백·`–` 포함 13) | 눈으로 | 13 | A2-09 |

### 2.6 별칭·검색 색인 (§10.2, ARCHITECTURE §4.3)

| 규칙 | 확인 방법 | 위반 | 예 |
|---|---|---:|---|
| 별칭 대상 실재·공개 | 공개 뷰·표에 없음 | 0 | |
| 완전 중복 | 5열 같음 | 55 | I2-06 |
| 기본 이름과 같은 별칭 | | 1 | n_higashi_karatsu_old `東唐津（旧）` (노리츠부시 CSV 이름, 의도) |
| 괄호·`駅`·공백 든 별칭 | 정규식 | 160 | 모두 `noritsubushi` CSV 대응 이름 (`三井芦別駅`, `函館本線 (砂原回り)`). 가져오기용이라 의도 |
| 검색 색인이 공개 노드·노선·운전 계통을 모두 담음 | 실체별 색인 행 | 0 누락 | 59,134행 |
| 색인 행이 없는 실체를 가리킴 / 중복 | | 0 / 0 | |
| 이름·kana가 색인에 있음 | `fold(text)` 대조 | 0 | (`ヶ→け` 접기 차이만) |

### 2.7 계통 이름 (§9.1 계통, gen_source 계통 이름)

| 규칙 | 확인 방법 | 위반 | 예 |
|---|---|---:|---|
| ja = 끝 역 ja `～` | `route.from_node`·`to_node`의 기본 이름(없으면 노선별 이름) | 20 | 숨은 끝 16 [알려짐 I1], （旧） 표시 차이 2, 낡음 2 (A2-11) |
| ko = 끝 역 ko `~` | 같은 방법 | 13 | （旧） 2, 낡음 11 (A2-11) |
| en = 끝 역 en `~` | 같은 방법 | 1 | r_johoku_line_iyotetsu |
| 같은 노선 안에서 계통 이름 중복 | | 0 | (노선이 다르면 같은 이름 28쌍, 정상) |

### 2.8 ID (§2.10, ARCHITECTURE §4.2)

| 규칙 | 확인 방법 | 위반 | 예 |
|---|---|---:|---|
| 접두사와 형식 | `^(n|l|r|s|o|g|hub|a)_[a-z0-9]+(_[a-z0-9]+)*$` | 0 | 노드 13,590, group 12,902, hub 1,100 등 |
| 표 안·표 사이 중복 | | 0 / 0 | |
| `_` 끝, `__` | | 0 | E12 고쳐짐 |
| 해시 모양(영숫자 섞인 6자 이상)·4자리 이상 숫자 | | 0 / 0 | |
| `_b` 같은 글자 꼬리 | `_[b-z]$` | 0 | |
| 숫자 꼬리는 이름의 숫자 | `_\d+$` 21개 | 0 | terminal_1, line_1 등 |
| ID와 이름이 맞음 | ID 줄기가 en 또는 kana 헵번식으로 시작 (n/m 차이 무시) | 노드 3, 노선 1, 사업자 1 | n_honmachi_2_chome [알려짐], n_matsue_english_garden_mae (en 쪽 결함 A2-16), n_shinden_kagoshima_city (en 쪽 A2-06), `l_seihosensabaeechizenhirai` (S2-14), o_mt_rokko… (공식 영문, 정상) |
| edge `e_` + 6자리 | | 0 | |
| `id_redirect` 일관성 | 행 수 | 0행 | 시드 동결 전이라 검사 대상 없음 (정보) |
| group ID 줄기 = 구성원 노드 줄기 | | 0 | |
| 숨은 노드만 든 group | | 19 | 신호장·분기점 group (공개 안 됨, 정상) |
| hub ID가 구성원 이름에서 | | 0 | |
| hub ID는 JR 역 이름 우선 | JR 노드 하나만 든 hub의 ID가 그 노드 줄기가 아님 | 125 | S2-10 |
| 같은 구성원 hub 중복 | 구성원 집합 같음 | 108쌍 | A2-12 |

### 2.9 좌표 (§4.7, §2.11, §14.1)

| 규칙 | 확인 방법 | 위반 | 예 |
|---|---|---:|---|
| 노드마다 `node_position` 한 행 (종류별) | station 13,571 / signal 4 / junction 12 / freight 3 | 0 누락, 중복 0, 고아 0 | |
| quality 값 | precise/approx/none 밖 | 0 | precise 9,584, approx 4,005, none 1 (DESIGN §4.7의 3,987은 낡은 수) |
| none이면 좌표 NULL·checked 있음 | | 0 | n_yonejimaguchi_fushiki (S2-11) |
| OSM 값 없음 (§2.11) | source=osm | 0 | |
| 현행 정차역은 precise | ongoing 정차역 중 approx | 1 | hand 1 (정밀 손 좌표) |
| precise는 선로와 맞는 정밀 좌표 | precise인데 출처가 SD·N02 밖 | 3 | n05 1 (S2-16), wikidata 1, wikipedia 1 |
| 일본 범위 | 위도 24~45.6, 경도 122.9~146 | 0 | |
| 도도부현 = 좌표 (§14.1 node.pref) | `pref.geojson` 점 포함, 적힌 현 경계까지 거리 | 9 (모두 1km 안, 경계 역) | DBA-010 반영 뒤 1km 넘는 것 0. 어느 현에도 안 드는 점 45는 모두 해안 1km 안 |
| `pref` 형식 | 1~47 정수 문자열 | 0 | |
| 다른 group 공개 역의 같은 좌표 | 소수 6자리 반올림 같음 | 14묶음 30노드 | I2-01 [알려짐] |
| 다른 group, 20m 안 | | 12쌍 | S2-15 |
| 이웃 역 직선거리 ≤ km×1.15+0.3 | 계통 순번 이웃, 같은 쌍 한 번 | 45쌍 | A2-01 2쌍, S2-12 |
| 이웃 역 직선거리 ≥ km×0.25 (km>3) | | 1 | 木次線 出雲坂根–三井野原 6.4km/1.28 (스위치백·루프, 정상) |

### 2.10 도도부현 km (§2.8 K)

| 규칙 | 확인 방법 | 위반 |
|---|---|---:|
| edge마다 `edge_pref` | 없는 edge | 0 |
| 없는 edge를 가리킴 / 같은 현 두 행 | | 0 / 0 |
| 현별 km 합 = edge km (±0.05) | | 0 |
| km NULL·음수, 여러 현인데 0km 조각 | | 0 / 0 |
| 한 현뿐인데 양 끝 현과 다름 | | 0 |
| 양 끝 현이 모두 들어 있음 | | 0 |
| 양 끝 현이 다른데 한 행 | | 0 |

### 2.11 선형 (§2.11, §4.7)

| 규칙 | 확인 방법 | 위반 | 예 |
|---|---|---:|---|
| `edge_shape` 해독 (Google encoded polyline, 정밀도 5) | 독립 해독기 | 0 오류 / 12,515 | |
| 점 2개 이상, 일본 안 | | 0 / 0 | |
| 모든 점이 한 점(길이 0) | | 9 | 모두 km 0 edge (I2-03) |
| 이웃 꼭짓점 5km 넘게 떨어짐 | | 49 | 신칸센·北越急行 등 터널 직선 구간 (정상) |
| quality ↔ source ↔ shape | `precise`면 출처 있음·n02/n05/hand는 shape 있음·osm은 shape 없음 / `none`이면 출처·shape 없음 | 0 | |
| OSM 선형이 master에 없음 (ODbL 분리) | osm edge의 `edge_shape` | 0 / 1,202 | |
| shape = 출처 파일 좌표 | n02(9,789)·n02_legacy(277)·n05(2,345)·n05_fill(56)과 점 단위 비교 | 6 차이 | 모두 `source_patch/geometry/n05_refit.yaml` 보정 (정상) |
| 출처 태그가 파일에 있음 (§2.10 끄기) | master `geometry_source` 파일에 그 edge 없음 | 1 | e_090001 n05 (source_patch, I2-07) |
| 한 edge가 두 출처 파일 | | 55 | I2-07 |
| `hand` 출처 | 필드 정의 밖 값 | 1 | e_090002 [알려짐] |
| 선형 없음 | `none` | 13 | I2-03 |
| 방향 (첫 점이 from 쪽) | 뒤집으면 양 끝이 300m 안으로 들어오는 것 | 0 | |
| 끝점 ↔ 노드 300m | 양 끝 중 먼 쪽 | 42 | I2-02 [알려짐] |
| 길이/km 0.67~1.5, 차이 1km 초과 | | 9 | 新岩国–徳山(신칸센 정의), 押上–曳舟 1.22/2.4, 東青山–榊原温泉口 2.57/3.9, 陸前高田–脇ノ沢 4.89/2.9, N05 노면전차 5 |
| 라이선스 표기 | `LICENSE.md`·파일 머리말 | 0 | N02(CC BY)·legacy(商用可)·N05(非商用)·OSM(ODbL) 각각 적힘. master에는 n02/n02_legacy 구분 열이 없음(§2.11 정의대로, 정보) |

## 3. 오류 상세

### A2-01. 商工会議所前 두 정류장이 노드 하나
`n_shokokaigishomae_ikaho`가 두 계통에 정차역으로 있습니다.

| 계통 | 순번 | 앞 역 | 뒤 역 | km |
|---|---|---|---|---|
| r_ikaho_line (東武 伊香保線, 渋川) | 3 | 渋川四ツ角 0.9 | 河原町 1.3 | 1.1 |
| r_maebashi_line (東武 前橋線, 前橋) | 1 | 前橋駅前 0.0 | 曲輪町 1.1 | 0.4 |

DBA-017에서 `node_fix.json`에 前橋 쪽 좌표(36.386615, 139.071083, 메모 「前橋線 商工会議所前」)를 넣자 伊香保線 쪽이 끊겼습니다. 渋川四ツ角–商工会議所前 0.2km가 직선 13.58km, 商工会議所前–河原町 0.2km가 13.91km이고, 이 두 edge(e_012381·e_012382)는 선형 길이 조건에 걸려 선형이 없어졌습니다(선형 없음 11 → 13). 이름은 같아도 渋川商工会議所와 前橋商工会議所 앞의 다른 정류장입니다. ID 꼬리 `_ikaho`도 伊香保線 쪽을 가리킵니다.

고칠 곳: `tools/gen_n05.py`의 노드 재사용(같은 이름 + 거리 5km 조건, DBA-015와 같은 곳)이 15km 떨어진 두 정류장을 합쳤습니다. 前橋線 정류장에 새 노드(`n_shokokaigishomae_maebashi`)를 주고 `node_fix.json`의 좌표를 그 노드로 옮기며, 伊香保線 노드는 渋川四ツ角·河原町 사이 보간 좌표로 되돌립니다. 그 뒤 e_012381·382의 N05 선형이 다시 붙는지 봅니다.

### A2-02. station_database의 동명 구분 괄호가 일본어 표시 이름에 남음
`source=station_database`인 기본 ja 43개와 노선별 1개가 station.csv의 `name` 열(구분 괄호 포함)을 썼습니다. 같은 행의 `original_name`은 괄호가 없습니다(`9943703,21082,広瀬(石川),広瀬,…`). ko·en에는 괄호가 없어 언어마다 표시가 다릅니다.

예: n_hirose_hokuriku `広瀬(石川)`, n_matsumori_meitetsu `松森(名古屋鉄道)`, n_kitago_fukui_nan_etsu `北府(南越線)`, n_saiwaicho `幸町(北海道)`, n_keirinjo_mae `競輪場前(岐阜)`, n_akechi_meitetsu 八百津線 `明智(名古屋鉄道)`. 전체 목록은 JSON A2-02.

고칠 곳: `tools/gen_source.py`에서 station_database 이름을 쓸 때 `original_name`을 씁니다. 계통 이름(`片上(岡山)～柵原`, `芦別～玉川(北海道)`, `競輪場前(岐阜)～田神`)도 같이 바뀝니다.

### A2-03. 노리츠부시 주석이 든 일본어 이름
| 노드 | 범위 | 이름 | 문제 |
|---|---|---|---|
| n_tokyo_skytree | 기본 | `とうきょうスカイツリー／押上` | 공식 역명은 とうきょうスカイツリー (押上는 부역명). kana는 `とうきょうすかいつりー`라 ja와도 다름 |
| n_koiji | 能登線 | `恋路(臨)` | 임시승강장 주석 |
| n_aizukogen_ozeguchi_aizu | 国鉄 会津線 | `会津高原(旧会津滝ノ原)` | 국철 시기 이름은 会津滝ノ原 |
| n_amagasaki | 福知山線 | `尼崎（臨時乗降場）` | 주석 (S2-04도 볼 것) |
| n_yamato_yagi | 橿原線 | `大和八木／八木西口` | 두 역 이름을 한 이름에 (S2-04) |
| n_nishihamanomachi | 蛍茶屋支線 | `西浜町／浜町アーケード` | 두 이름 병기 |
| n_awa_kainan | 阿佐東線 | `阿波海南（モードインターチェンジ）` | DMV 주석 |
| n_osaka | 梅田貨物線 | `大阪（うめきた）` | 주석 |
| n_kannoura_asa_seaside_asato(_old) | 기본 | `甲浦（モードインターチェンジ）`, `甲浦(鉄道駅)` | 주석. 옛 노드는 A2-07 |
| n_unsenji, n_onbara_rakutenchi | 기본 | `雲泉寺(ラクテンチ下)`, `乙原(ラクテンチ上)` | 주석 (의심, 공식 표기 확인 필요) |

고칠 곳: 노선별 이름은 `gen_source.py`가 노리츠부시 표 이름을 그대로 넣습니다. `data/overrides/node_fix.json`(이름) 또는 노리츠부시 이름 정규화(`／`·`(臨)`·`(旧…)` 제거, 별칭으로만 보관)로 고칩니다. 원래 문자열은 CSV 가져오기 별칭(`noritsubushi`)으로 남깁니다.

### A2-04. 옛 이름의 한국어 읽기
`tools/gen_source.py` 1309~1311행은 옛 이름의 읽기를 `KANA['node:'+old]` 또는 **이름이 같은 station_database 역 아무거나**(`byname[znorm(old)]`)에서 가져옵니다. 같은 한자의 다른 역 읽기가 들어갑니다(§9.2 "같은 한자의 다른 역일 수 있습니다").

| 노드 | 옛 이름 (기간) | 지금 이름·읽기 | ko | 가져온 읽기 (그 역과의 거리) | 맞는 읽기 |
|---|---|---|---|---|---|
| n_osumi_koyama | 高山 (1920~1935) | 大隅高山 おおすみこうやま | 타카야마 | たかやま (岐阜 高山, 790km) | こうやま → 코야마 |
| n_kagaiwauchi | 岩内 (1925~1946) | 加賀岩内 かがいわうち | 이와나이 | いわない (北海道 岩内, 801km) | いわうち → 이와우치 |
| n_musashi_koyama | 小山 (1923~1924) | 武蔵小山 むさしこやま | 오야마 | おやま (栃木 小山, 78km) | こやま → 코야마 |
| n_naganohara_kusatsuguchi | 長野原 (~1991) | 長野原草津口 | 나가노하라쿠사츠구치 | 지금 이름 그대로 | 나가노하라 (같은 역의 노선별 ko가 이미 `나가노하라`) |
| n_shin_tokorozawa | 所沢御幸町 (1940~1959) | 新所沢 | 신토코로자와 | 지금 이름 그대로 | 토코로자와미유키초 |
| n_owari_asahi (의심) | 新居 (1905~1922) | 尾張旭 | 니이 | にい (伊賀 新居, 97km) | あらい로 알려짐, 원문 확인 필요 |
| n_enshu_kobayashi (의심) | 新原 (1909~1923) | 遠州小林 | 신바루 | しんばる (福岡 新原, 684km) | 원문 확인 필요 |

ko 옛 이름 116개 중 같은 이름 SD 역이 5km 안에 있는 것 24, SD에 없는 것 44, 먼 역뿐인 것 48입니다. 먼 역 48개 중 위 3개는 옛 이름이 지금 이름의 일부인데 가져온 읽기가 지금 읽기에 없어서 확실히 틀립니다. 나머지 45는 흔한 읽기라 맞을 가능성이 높지만 근거는 같은 결함입니다.

고칠 곳: `gen_source.py`에서 (1) 옛 이름이 지금 이름의 일부이면 지금 kana에서 해당 부분을 잘라 쓰고, (2) SD 역은 그 노드에서 가까운 것(예: 5km)만 쓰고, (3) 어느 것도 없으면 ko 옛 이름을 만들지 않거나 `estimated`로 적습니다. 위 5개는 `data/overrides/old_names_fix.json`이나 `kana.json`에 손으로 넣을 수 있습니다.

### A2-05. 本町二丁目의 읽기
| 노드 | ja | kana | ko | en |
|---|---|---|---|---|
| n_honmachi_2_chome_osaka_municipal_transportation_bureau (大阪市電 靭本町線) | 本町二丁目 | ほんまちさんちょうめ | 혼마치산초메 | Honmachi 2-chome |
| n_honmachi_2_chome_takasaki_line_tobu (東武 高崎線 궤도) | 本町二丁目 | ほんまちさんちょうめ | 혼마치산초메 | Honmachi 2-chome |

같은 계통의 이웃이 本町三丁目(seq 4·6)이라, 같은 이름 사전에서 三丁目 읽기를 잘못 짝지은 것으로 보입니다(출처 `wikipedia+n05`). en은 ja 숫자로 만들어 맞습니다. 고칠 곳: `data/overrides/kana.json`에 두 노드의 `ほんまちにちょうめ`. ko는 다시 생성하면 `혼마치니초메`. [알려짐]인 n_honmachi_2_chome(이름 三丁目)과 같은 노선의 일이라 함께 보면 됩니다.

### A2-06. 부역명 괄호
공식 이름에 부역명 괄호가 있는 역 11개의 언어별 처리입니다.

| 노드 | ja | kana | ko | en |
|---|---|---|---|---|
| n_hasumachi | 蓮町（馬場記念公園前） | はすまちばばきねんこうえんまえ | 하스마치 | **Hasumachibabakinenkoemmae** |
| n_hatsukaichishiyakushomae | 廿日市市役所前(平良) | はつかいちしやくしょまえへら | 하츠카이치시야쿠쇼마에 | **Hatsukaichishiyakushomaehera** |
| n_shinden_kagoshima_city | 神田（交通局前） | しんでんこうつうきょくまえ | 신덴 | **Shindenkotsukyokumae** |
| n_nishitetsu_fukuoka | 西鉄福岡（天神） | にしてつふくおかてんじん | 니시테츠후쿠오카(텐진) | Nishitetsu Fukuoka |
| n_toyota_mobility_toyama_g_square_gofuku_mae | …五福前（五福末広町） | `とよたもびりてぃとやま じーすくえあ…` (공백) | …고후쿠마에 | …Gofuku-mae |
| n_nakamachi, n_ryukokutoyamakokomae, n_awajima, n_yonejimaguchi(×2) | 괄호 있음/붙임 | 부역명 뺌 | 뺌 | 뺌 |

en 3개는 읽기를 통째로 헵번식으로 이어 붙여 부역명이 지명에 섞였습니다. kana는 5개가 부역명을 넣고 6개는 뺐습니다. ko는 `니시테츠후쿠오카(텐진)`만 괄호를 두고 나머지는 뺐습니다. 고칠 곳: `gen_source.py`(kana·en)와 `tools/en_rules.py`의 `plainkana`를 거친 값을 en에 쓰고, kana에서 부역명 읽기를 뺄지 넣을지 하나로 정합니다. 공백은 지웁니다.

### A2-07. 甲浦 옛·새 노드의 표시
`node_move`: n_kannoura_asa_seaside_asato_old → n_kannoura_asa_seaside_asato (2021-12-25, DMV 전환). §2.2 "옛 노드와 새 노드의 이름이 같으면 … `(구)`, `（旧）`, `(old)`". 지금은 ja `甲浦(鉄道駅)` / `甲浦（モードインターチェンジ）`, ko 둘 다 `칸노우라`, en 둘 다 `Kannoura`라 한국어·영어 화면에서 구별이 안 됩니다. 별칭 `moved`도 없습니다. node_move 46쌍 중 이름이 같은데 표시가 없는 것은 이 1쌍입니다(나머지 14쌍은 새 이름이 달라 표시 대상 아님). 고칠 곳: `moved.json` 처리(gen_source의 옛 노드 표시)가 노리츠부시 이름의 괄호 주석 때문에 "같은 이름"으로 못 본 것으로 보입니다. 주석을 뗀 이름으로 비교합니다.

### A2-08. 노선 읽기가 틀림
| 노선 | ja | kana | 맞는 읽기 |
|---|---|---|---|
| l_nakagawa_connecting_line | 中川短絡線 | いせなかがわ | なかがわたんらくせん |
| l_nishi_kyushu_line | 西九州線 | まつうらてつどう | にしきゅうしゅうせん |
| l_yamashiro_line | 山代線 | ほくりくてつどうやましろえん | やましろせん (`えん` 오타) |
| l_uchiko_line | 内子線 | よさん・うちこせん | うちこせん |
| l_kamidaki_line | 上滝線 | とやまちてつふじこし・かみだきせん | かみだきせん |
| l_tramway_ho_line | 軌道線 | きどうほう | きどうせん |
| l_disney_resort_line | ディズニーリゾートライン | でぃずにーりぞーとらいんせん | …らいん |
| l_tokyo_monorail_haneda_airport_line | 東京モノレール羽田空港線 | とうきょうものれーる | …はねだくうこうせん |
| l_sapporo_streetcar | 1条線・山鼻線・山鼻西線・都心線 | さっぽろしでん | 이름과 읽기가 다른 단위 |

노리츠부시 읽기를 그대로 옮겨서 생긴 일입니다. 검색 색인에 이 kana가 들어가 `まつうら`로 西九州線이 나오고, 위 읽기에서 만든 ko·en도 틀립니다(A2-09·A2-10). 고칠 곳: `data/overrides/lines_kana.json`.

### A2-09. 노선 한국어 이름이 깨짐
N05 복합 이름 13개는 `tools/ko.py line()`이 공백·`–`을 무시해 `선`을 `센`으로 음차하고 구간을 붙였습니다.

| 노선 | ja | ko |
|---|---|---|
| l_loop_line_hakatachikkomae_chidoribashi | 循環線 博多築港前–千鳥橋 | 니시테츠 준칸센하카타칫코마에치도리바시 |
| l_betsudai_line_beppu_ekimae_branch | 別大線 別府駅前支線 | 베츠다이센벳푸에키마에 지선 |
| l_ishiki_line_shinshoin_ishiki_old_route | 伊敷線 新照院–伊敷 旧線 | 가고시마시 교통국 이시키센신쇼인이시키큐선 |
| l_yamaguchisenotogi_line | 山口線 おとぎ線 | 세이부 야마구치센오토기선 |
| (나머지 9개) | 岐阜市内線 忠節支線, 循環線 花京院–仙台駅前, 循環線 旧線, 帯広部線 帯広大通支線, 押切線 柳橋–志摩町, 真田傍陽線 傍陽支線, 鯖浦線 鯖江–越前平井, 清水市内線 西久保–袖師 旧線, 東郊線 高辻–滝子 | 같은 꼴 |

그 밖에:
- l_awaji_kotsu_line 淡路交通線 → `테츠도선` (지명이 빠짐)
- l_katayamazu_line 片山津線 → `호쿠리츠 철도 카타야마즈선` (`호쿠리쿠` 오타)
- l_tramway_ho_line 軌道線 → `이즈하코네 철도 궤도 호` (A2-08 읽기에서)
- l_uchiko_line 内子線 → `요산선·우치코선`, l_kamidaki_line 上滝線 → `도야마 지방철도 후지코시·카미다키선` (A2-08)

고칠 곳: `tools/ko.py line()`이 공백 단위로 나눠 `線`·`支線`·`旧線`과 `A–B` 구간을 따로 옮기게 합니다. 결과는 영어처럼 `순환선 (하카타칫코마에~치도리바시)` 꼴이 맞습니다. 낱개는 `data/overrides/lines_ko.json`.

### A2-10. 노선 영어 이름
`Yamaguchisen'otogi Line`(山口線 おとぎ線), `Yagumahigashisentozai Connecting Line`(八熊東線東西連絡線), `Tsukijisen Branch Line`(築地線支線), `Tramway Ho Line`(軌道線, A2-08 읽기). §9.1 "`線` → `Line`". 고칠 곳: `tools/gen_en_names.py line_name()`이 이름 중간의 `線`(공백·`線`+다른 낱말)을 나누지 않습니다. N05 복합 이름은 이미 `Loop Line (A~B) Old Route`처럼 잘 나온 것이 있어 같은 처리를 넓히면 됩니다.

### A2-11. 계통 이름이 낡음
`gen_source.py`가 계통 이름을 `names_ko.json` 손 보정과 `source_patch` 적용 전에 만들어, 뒤에 바뀐 역 이름이 계통 이름에 반영되지 않았습니다.

| 계통 | 언어 | 계통 이름 | 지금 끝 역 이름 |
|---|---|---|---|
| r_oyama_cable_line | ko | 오야마코사쿠센~아후리진자 | 오야마케이블 |
| r_mount_tsukuba_cable_car | ko | 미야와키~츠쿠바산코사쿠테츠도센 | 츠쿠바산초 |
| r_jukkokutoge_cable_car | ko | 줏코쿠코사쿠센~짓코쿠토게산초 | 줏코쿠토게산로쿠~줏코쿠토게산초 |
| r_ueno_zoo_monorail_line | ko | …~우에노켄스이센 | 우에노도부츠엔니시엔 |
| r_hiroden_main_line, …_hiroshima_matobacho | ko | 히로시마~… | 히로시마역 |
| r_hanazono_line | ja·ko | 松山市駅前～南堀端 / 마츠야마시~ | 松山市駅 / 마츠야마시역 |
| r_seikan_tunnel_tappi_shako_line | ko | 세이칸톤네루키넨칸~ | 세이칸터널키넨칸 |
| r_yunomae_line_kumagawa | ko | 히토요시~유노마에 | 히토요시온센 (ja 계통 이름은 人吉温泉～湯前) |
| r_higashiyama_main_line | ko | …~히가시야마오카덴차긴톤뮤지아무역 | (A2-14) |
| r_johoku_line_iyotetsu | ja·ko·en | 古町～平和通一丁目 | 끝 노드는 source_patch로 바꾼 上一万（旧） |

ko 계통 이름 넷에는 역 이름 대신 노선 읽기(`코사쿠센`, `켄스이센`)가 들어 있습니다. 고칠 곳: 계통 이름을 `tools/compile.py`에서 최종 노드 이름으로 만들거나, `gen_source.py`에서 손 보정 뒤로 옮깁니다.

### A2-12. 같은 환승 묶음이 두 번
hub 1,100개 중 108쌍(216개)이 구성원 집합이 똑같습니다. 한쪽은 `["station_database","proximity_300m"]`, 다른 쪽은 `["wikipedia"]`입니다. 예: `hub_mita`·`hub_tamachi` (n_mita, n_tamachi), `hub_harajuku`·`hub_harajuku_meiji_jingumae`, `hub_shin_sapporo`·`hub_shin_sapporo_shin_sapporo_sapporo_city`. 그래서 노드 384개가 hub 둘 이상에 속합니다. 고칠 곳: `tools/gen_wiki.py`(위키 hub)가 같은 구성원의 기존 hub를 찾으면 새 hub를 만들지 않고 `source`에 `wikipedia`를 더합니다. 환승 표시가 hub 단위라면 같은 환승이 두 번 나옵니다(위상 감사와 겹치는 항목).

### A2-13. `ん` 뒤 모음
§9.1 "`ん`은 … 모음 앞에서 `n'`". `source=rule` 역 이름 중 kana에 `ん`+모음·や행이 있는 50개에 `'`가 없습니다. `tools/en_rules.py station_reading()`이 `hepburn()`이 아니라 `romaji()`를 쓰기 때문입니다(노선은 `hepburn()`이라 `Kurihara Den'en`, `Sun'en Line`). 예: n_shinobihiro `Shinobihiro`(しんおびひろ, Shin'obihiro), n_kanonmachi `Kanommachi`(かんおんまち, Kan'ommachi), n_shinyashiki `Shinyashiki`, n_gozenyama `Gozenyama`, n_anyoji `Anyoji`. 고칠 곳: `en_rules.station_reading`에서 `ん` 뒤 모음에 `'`를 넣고 `.title()` 대신 첫 글자만 대문자로 합니다(`'` 뒤 대문자 방지).

### A2-14. 東山・おかでんチャギントンミュージアム駅의 한국어
ja `東山・おかでんチャギントンミュージアム駅`, en `Higashiyama-Okaden Chuggington Museum`인데 ko(hand)는 개칭 전 `히가시야마·오카덴뮤지엄역`입니다. 고칠 곳: `data/overrides/names_ko.json` → `히가시야마·오카덴차깅턴뮤지엄역`(나무위키 제목 확인).

### A2-15. 일반 한자어 음차
§9.3 "일반 한자어 → 한국 한자음 (環状 환상)". `循環線`을 rule로 옮긴 6개가 `준칸선`입니다(`니시테츠 준칸선`, `센다이시 지하철 준칸선` 등). 같은 이름의 広電 노선은 hand로 `히로시마 전철 순환선`입니다. 고칠 곳: `tools/ko.py`의 SINO 표에 `循環 じゅんかん 순환`.

### A2-16. 松江イングリッシュガーデン前
en `Matsueingurisshugademmae`. `en_rules.KATAKANA`에 `イングリッシュガーデン`이 있는데도 외래어 변환을 거치지 않은 읽기 표기가 나왔습니다(`katakana()`의 라벨 대조 조건에서 빠진 것으로 보임). ID는 `n_matsue_english_garden_mae`라 이름과 어긋납니다. 고칠 곳: `en_fix.json`에 `Matsue English Garden-mae`.

## 4. 의심 상세

| # | 내용 | 측정 | 끝내는 방법 |
|---|---|---|---|
| S2-01 | 옛 이름 ja 397 중 ko 116, en 0, kana 0. 노선별 이름 ja 115 중 en 0, kana 0. 한국어·영어 화면에서 옛 기록은 지금 이름으로 나옴(稲田多摩川 → 노보리토). kana가 없어 옛 이름 읽기로 검색 안 됨 | names.sqlite | 옛 이름 ko·en·kana를 만들지(규칙), 지금 이름으로 두는 것이 의도인지 결정. 만든다면 A2-04를 먼저 고침 |
| S2-02 | 노선 kana 262개가 회사 읽기로 시작 (`八王子線` `よっかいちあすなろうてつどうはちおうじせん`, `東豊線` `さっぽろしえいちかてつ…`) | 997 중 | §14.2 kana를 "이름의 읽기"로 보면 `gen_en_names.own_reading()`이 뗀 값을 kana로 저장. 회사 이름 검색은 사업자로 |
| S2-03 | 회사 이름 노선 약 45개 kana에 `せん` 없음 (`有田鉄道線` `ありだてつどう`, `つくばエクスプレス線` `つくばえくすぷれす`) | | S2-02와 같이 |
| S2-04 | 노선별 이름이 드러낸 합친 역: 橿原線 `大和八木／八木西口` — 八木西口역 노드가 없음(橿原線 계통 seq 13이 大和八木). 尼崎港線 `尼崎（臨時乗降場）` — n_amagasaki(JR 尼崎)에 합쳐졌고 尼崎–金楽寺 km 0.5에 직선 0.94km | 2 | 近鉄이 八木西口를 営業キロ상 大和八木와 같은 역으로 다루는 것을 노리츠부시가 따른 것. 역 방문 기록 단위로 노드를 둘지 결정. 尼崎港線 尼崎는 원문으로 위치 확인 |
| S2-05 | 사철 노선 ko에 사업자 이름 없음 44 (rule 34). `호조선`·`카미오카선`·`미키선`·`타카치호선`은 국철 노선과 3섹 노선이 같은 ko. 같은 꼴의 会津線은 hand로 `아이즈 철도 아이즈선` | | §9.3 규칙대로 `tools/ko.py`·`lines_ko.json`에서 사업자 짧은 이름을 붙임 |
| S2-06 | `o_sendai_city_transportation_bureau` ko `센다이시 지하철`, 名古屋市交通局 `나고야 시영 지하철`이 市電 노선(循環線, 押切線, 東郊線 등)에 붙음 | 2 사업자 | `operators_ko.json`의 짧은 이름을 `센다이시 교통국` 꼴로 |
| S2-07 | 前 686개 en 끝: `mae` 붙임 535, `-mae` 124, `-Mae` 17, `GAKKO-MAE` 1, ` Mae` 1. 접두 東·西·南·北·新: rule 하이픈 32 / 붙임 206 / 띄움 13, wikidata 하이픈 787 / 붙임 137 / 띄움 26 | | 하나로 정할지 결정. 정하면 `en_rules`·`en_fix.json`. `GAKKO-MAE`(n_gakko_mae_kujukuri)는 위키데이터 라벨 대문자라 바로 고칠 대상 |
| S2-08 | `Loop Line` 3노선 (広電, 西鉄, 仙台市電) | | `en_fix.json operator_short` |
| S2-09 | 穴太 n_anoh あのう / n_anoo あのお 둘 다 namuwiki `아노`, 大和田 n_owada_oigawa おわだ / 나머지 おおわだ 모두 `오와다` | 2 | 규칙 결과와 글자가 같아 표시는 그대로. 한쪽 `source`를 `rule`로 (§9.2 CI 검사 대상) |
| S2-10 | JR 노드 하나가 든 hub 125개의 ID가 JR 이름이 아님 (`hub_keikyu_tsurumi`, `hub_mizonokuchi`, `hub_kitashichijodori`에 n_sapporo) | 125 | 시드 동결 전에 `gen_wiki.py`·hub 생성기의 이름 규칙 적용. A2-12 중복 정리와 같이 |
| S2-11 | n_yonejimaguchi_fushiki: 伏木線(加越能鉄道, 1948~1971) 米島口. 같은 회사 n_yonejimaguchi(万葉線)와 같은 정류장으로 보이는데 다른 group, 좌표 `none`. 이름은 두 노드 모두 `米島口アルビス米島店前`(근년 부역명) | 1 | 같은 정류장이면 한 노드(§2.8 B). 아니면 이름을 `米島口`로, 좌표는 万葉線 米島口 근처 |
| S2-12 | 이웃 역 직선 > km×1.15+0.3: 45쌍. N05 좌표 17, 폐역 SD 10, 현행 SD 7, 추정 km 6, 이설 옛·새 3, 보간·손 2 | 표 c3 | 현행 7 중 肥薩線 大隅横川–植村(2.0km / 2.7km), 武豊線 半田–東成岩(1.7 / 2.3)은 좌표 또는 km 하나가 틀림. 외부 대조 감사(5)에서 1차 자료 확인. なんば·車道·松島–高城町은 설계 |
| S2-13 | 열람 전용 노선 44개가 `archive_lines.json`의 drop(35)·exclude(9)로 master에서 빠졌는데 이름 88행이 names.sqlite에 남음. 蒲蒲線(계획선), 鉄道連隊演習線 포함 | 44 | `compile.py`가 names에도 같은 필터를 적용 |
| S2-14 | `l_seihosensabaeechizenhirai`(鯖浦線 鯖江–越前平井), `l_yamaguchisenotogi_line`, `l_yagumahigashisentozai_connecting_line`, `l_tsukijisen_branch_line`은 `線`을 `sen`으로 이어 붙인 ID. `l_blue_line_line_1`·`_3`은 `line_line` | 5 | 시드 동결 전 `new_ids.py`로 다시 매김(공개 전이라 redirect 불필요) |
| S2-15 | 20m 안의 다른 group: 丹後山田(加悦鉄道)=与謝野 6m, 西長田=西長田ゆりの里 4m, 芦原=あわら湯のまち 14m, 古川=よしかわ 15m, 亀川=亀川駅前 7m 등 12쌍. 같은 좌표: 東古市=永平寺口(SD 0m, 같은 역의 옛 이름), 南方=南方(宮崎) | 12 + 2 | 같은 역이면 같은 group (§2.8 B). 위상 감사(3)와 겹침 |
| S2-16 | n_takahata_yamagata_kotsu 좌표 출처 N05인데 `precise` (§4.7 precise는 선로와 맞는 정밀 좌표, N05는 수백 m 오차) | 1 | `approx`로 |
| — | 押上–曳舟 e_010020 km 2.4, 선형 1.22km. 東青山–榊原温泉口 3.9/2.57 (新線 터널 선형에 옛 km), 陸前高田–脇ノ沢 2.9/4.89 | 3 | 외부 대조 감사(5) |

## 5. 정보

| # | 내용 |
|---|---|
| I2-01 | 같은 좌표 다른 group 14묶음 30노드 (n05·보간 11) [알려짐 S6, 18→14] |
| I2-02 | 선형 끝 ↔ 역 300m 초과 42 (현행 26은 なんば·東京·浅草 등 한 노드의 떨어진 승강장, 폐역 16) [알려짐] |
| I2-03 | 선형 없는 edge 13 = 1차 감사 11 + e_012381·e_012382(A2-01). 점 하나 선형 9개는 km 0 edge (`e_011443` 弁天前–亀陽泉前 등) [알려짐 0km 12] |
| I2-04 | kana의 `・`(万座・鹿沢口 등 30자)와 공백(N05 노선 이름 등 23자). ja에 있는 구분자라 검색 접기(`fold`)가 지움 |
| I2-05 | 사업자 282·계통 1,133에 kana 없음. `reading_source`·`source_title`은 49,902행 모두 NULL(§9.2는 일본어 위키백과 읽기 확인을 `reading_source`에 적는다고 함). `checked`는 ko 행에만 |
| I2-06 | 별칭 완전 중복 55 (`r_tokaido_main_line` `東海道本線` 등 계통 노리츠부시 53, 関急蟹江·関急八田 옛 이름 2) |
| I2-07 | `data/overrides/geometry/n05_fill.yaml` 111개 중 n05 43, n02 3, osm 9가 다른 파일에도 있음. n02·osm 12개는 master가 쓰지 않는 줄. e_090001(長尾線 옛 경로)은 `source_patch/geometry/nagao_old.yaml`에서 와 `n05.yaml`을 끌 때 함께 빠지는지 확인 필요 |
| I2-08 | [알려짐]: 계통 ko·en 없음 16, 열람 전용 en 없음 498, 노선 kana 없음 36, n_honmachi_2_chome의 이름 本町三丁目(ID 2丁目), `Honmachi` 15(의도), en의 `·` 6, e_090002 `hand` |
| — | DESIGN §4.7의 approx 3,987은 지금 4,005, §2.11의 선형 없음 11은 지금 13 |
| — | `四条廿丁目` en `Yojonijutchome` (en_rules `CHOME`가 `廿`을 모름) |

## 6. 고칠 곳 요약 (생성기별)

| 파일 | 항목 |
|---|---|
| `tools/gen_n05.py` (노드 재사용) | A2-01 |
| `tools/gen_source.py` | A2-02 (`original_name`), A2-03 (노리츠부시 주석 정규화), A2-04 (옛 이름 읽기), A2-06 (부역명), A2-07 (옛 노드 같은 이름 판정), A2-11 (계통 이름 시점) |
| `tools/en_rules.py` / `tools/gen_en_names.py` | A2-10, A2-13, A2-16, S2-07, S2-08 |
| `tools/ko.py` | A2-09, A2-15, S2-05 |
| `tools/gen_wiki.py` | A2-12, S2-10 |
| `tools/compile.py` | A2-11 (계통 이름을 최종 이름으로), S2-13 (열람 전용 이름 필터) |
| `data/overrides/kana.json`, `lines_kana.json` | A2-05, A2-08, S2-02·03 |
| `data/overrides/names_ko.json`, `lines_ko.json`, `operators_ko.json` | A2-14, A2-09 낱개, S2-06 |
| `data/overrides/node_fix.json` | A2-01 좌표 이동, A2-03 이름, S2-16 |
| `data/overrides/old_names_fix.json` | A2-04 낱개 |
| `data/overrides/en_fix.json` | A2-16, `GAKKO-MAE` |

## 7. 확인하지 못한 것

| 항목 | 까닭 |
|---|---|
| 新居(尾張旭)·新原(遠州小林) 옛 읽기 | 위키 캐시에 역 문서가 없음 (캐시 1,576문서는 대부분 노선 문서) |
| 나무위키 제목이 지금도 그 제목인지 | 덤프 2021-03-01판만 저장소에 있음. 네트워크를 쓰지 않음 |
| 위키데이터 라벨 en의 철자 | 출처 순위상 그대로 둠. 표기 갈림만 S2-07로 셈 |
| 노선 kana 262의 정확한 수 | 회사 읽기 목록(`PREFIXES`·`GENERIC`) 기준이라 목록 밖 회사 이름은 빠질 수 있음. 표본 12개는 모두 맞음 |
| 현행 역 좌표 ↔ N02 승강장 | `data/imports/n02/stations_2024.json`이 감사 중 다시 생성됨(22:47). 1차 감사의 대조(300m 초과 0)를 다시 재지 않음 |

## 부록 A. 검사 조건

```sql
-- 기본 이름 없음 (node 예). lang을 바꿔 ja·ko·en
select id from node_public n where not exists (select 1 from nm.name a where a.entity_type='node' and a.entity_id=n.id
  and a.lang='ko' and a.line_id is null and a.valid_from is null and a.valid_to is null);
-- 기본 이름 중복
select entity_type,entity_id,lang,count(*) from nm.name where line_id is null and valid_from is null and valid_to is null
  group by 1,2,3 having count(*)>1;
-- 이름이 가리키는 열람 전용이 없음 (S2-13)
select distinct entity_id from nm.name where entity_type='archive'
  and entity_id not in (select id from archive_stop union select id from archive_line);
-- ko 옛 이름 = 기본 ko인데 ja는 다름 (A2-04)
select a.entity_id,a.text,b.text from nm.name a join nm.name b on b.entity_id=a.entity_id and b.lang='ko'
  and b.valid_from is a.valid_from and b.valid_to is a.valid_to
 where a.lang='ja' and (a.valid_from is not null or a.valid_to is not null)
   and b.text=(select text from nm.name d where d.entity_id=a.entity_id and d.lang='ko' and d.line_id is null and d.valid_from is null)
   and a.text<>(select text from nm.name d where d.entity_id=a.entity_id and d.lang='ja' and d.line_id is null and d.valid_from is null);
-- 같은 구성원 hub (A2-12)
select m, group_concat(hub_id) from (select hub_id, group_concat(node_id) m from (select * from hub_member order by node_id) group by hub_id)
  group by m having count(*)>1;
-- edge_pref 합 (위반 0)
select e.edge_id,k.km,sum(e.km) from edge_pref e join edge_km k using(edge_id) group by e.edge_id having abs(sum(e.km)-k.km)>0.051;
-- 선형 출처 일관성 (위반 0)
select geometry_quality,geometry_source,(id in (select edge_id from edge_shape)),count(*) from edge group by 1,2,3;
```

```python
# 이웃 역 직선거리 vs km (A2-01, S2-12). P: node_position, 계통별 seq 이웃
if hav(*P[a], *P[b]) > abs(km_b-km_a)*1.15 + 0.3: flag
# 옛 이름 읽기 출처 (A2-04): station.csv에서 같은 name의 행 중 노드 좌표 5km 안이 없고,
# 옛 이름이 지금 이름의 일부인데 그 SD 읽기가 지금 kana에 없으면 오류
# 규칙 ko 재현: os.environ['NW_OFF']='1'; import ko; ko.station(kana, ja) != ko_text
# 폴리라인: Google encoded polyline 정밀도 5를 독립 구현으로 해독, 점 길이 합 vs edge_km
# 도도부현: pref.geojson MultiPolygon 광선 교차 + 적힌 현 경계까지 최소 거리
```
