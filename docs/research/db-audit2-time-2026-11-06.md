# DB 2차 감사 (1) 시간 축 (2026-11-06, 판 2026-11-06.3)

대상은 스냅숏 `snap-2026-11-06.3/master.sqlite`(md5 8486c607…)와 `names.sqlite`뿐입니다. `build/`는 읽지 않았습니다. 원본은 `data/source/events/*.yaml`, 보정은 `data/overrides/*`의 **커밋된 판(HEAD)**을 봤습니다. 작업 트리의 `edge_dates.json`·`stop_dates.json` 변경(ニューシャトル 内宿 1990-08-02)은 스냅숏 뒤의 일이라 대상에서 뺐습니다.

사건이 결과에 어떻게 남았는지 보려고, HEAD의 `data/`와 `tools/`를 임시 폴더에 풀어 `compile.py`에 기록 두 줄(구간 풀이 결과, 효과 없는 휴지·재개)만 더해 다시 컴파일했습니다. 그 결과의 `edge_life`·`edge_attr`·`route_stop`·`route_link`·`edge`가 스냅숏과 행 단위로 같아서(차이 0행), 그 기록을 이 스냅숏의 사건 기록으로 썼습니다. 저장소에서 고친 파일은 이 문서와 `db-audit2-time-2026-11-06.json` 둘뿐입니다.

`[알려짐]`은 앞선 감사(`db-audit-2026-11-06.md`)에 있던 항목입니다. 이번 판의 상태만 다시 쟀습니다.

## 1. 요약

| # | 내용 | 수 | 등급 | 새 항목인가 |
|---|---|---:|---|---|
| T2-01 | 日田彦山線 石田–東小倉(1956-11-19 폐지)의 `legal_abolition`이 2027-03-31. 노선 이름으로 거는 `LEGAL` 표가 같은 노선의 다른 폐지에도 붙음 | edge 2, closed_section 2 | 오류 | 새 항목 |
| T2-02 | 동일본 대지진 휴지 시작일이 갈림: 73 edge는 2011-03-11, 気仙沼線·大船渡線 28 edge는 2011-03-12(마지막 운행 03-11). 2011-03-11 오전 탑승이 "탈 수 없는 날짜"가 됨. 이설로 끝난 옛 선로 8 edge는 `last_service`도 없음 | 73 edge | 오류 | 새 항목 |
| T2-03 | `route_link` 기간이 끝(또는 시작)을 모르는 정차(NULL)를 무한으로 봄. 한쪽 계통이 없어진 지 15~19년 뒤에 시작하는 환승 2쌍(4행), 계통 개업 22년 전에 시작하는 환승 1행 | NULL 끝 11행, 존재 밖 5행 | 오류 | 새 항목 |
| T2-04 | 같은 노선·같은 역인데 계통마다 정차 시작이 다름. 옛 경로 계통에는 `open_stop`이 없어 선로 개업일을 씀. 白新線 大形 1956-04-15(옛 경로 계통) / 1957-02-11(본선 계통) | 11쌍 (1950 이후에 걸친 것 2) | 오류 | 새 항목 |
| T2-05 | 정차 시작이 그 계통 인접 선로보다 이름. 원인은 컴파일 순서: `edge_dates.json`을 `route_stop`을 만든 **뒤에** 적용함. `route_link`도 옛 날짜를 이어받음 (城南線 上一万 지선 연결 2행 1927~) | 10 (1950 이후 영향 4) | 의심 | [알려짐] S8 14→10, 원인은 새 항목 |
| T2-06 | 室蘭本線 陣屋町–元輪西(e_000241, 3.0km)이 1970-08-01~1978-10-03에 정차역이 元輪西 하나뿐인데 영업·분모(normal)에 있음 | 1 edge | 의심 | 새 항목 |
| T2-07 | 大阪環状線 今宮–新今宮(e_003000, 1.2km)이 1961-04-25~1964-03-22에 정차역 없는 끝으로 매달림 (新今宮 개업 1964-03-22, 新今宮–天王寺는 関西本線만) | 1 edge | 의심 | 새 항목 |
| T2-08 | 옛 선로를 새 선로로 바꾼 날 닫힌 옛 선로 61 edge(26 계통)의 `close_reason`이 `abolished`. 같은 종류인 吾妻線 등 11 edge만 `relocated`이고 `edge_link`도 그 11개뿐 | 61 edge | 의심 (결정 필요) | 새 항목 |
| T2-09 | 日田彦山線 添田–夜明 BRT 구간 `legal_abolition` 2027-03-31이 as_of(2026-11-02) 뒤. 근거 확인 필요 | 9 edge | 의심 | 새 항목 |
| T2-10 | `edge_life`의 `*_lo`가 EDTF 원문 범위와 다름 (범위 날짜 재개 1953-XX-XX 등의 하한을 앞 휴지 시작으로 올림). `compile.py` `_life_rows`의 의도된 동작이지만 명세(§5.4, §14)에 없고 `edge_attr`·`route_stop`에는 없음 | 112칸 (45 edge) | 정보 | 새 항목 |
| T2-11 | `junction`의 기간이 전부 NULL~ongoing. 한쪽 노선이 끝났는데 ongoing인 행 505 | 1,349 / 505 | 정보 | 새 항목 |
| T2-12 | 같은 `open_stop` 사건이 두 줄 (常磐線 駒ケ嶺, 石巻線 浦宿) | 2 | 정보 | 새 항목 |
| T2-13 | 정차 기간 NULL (정차 사건 날짜 NULL 45줄에서 옴) | 37 | 의심 | [알려짐] S11 38→37 |
| T2-14 | 국철→JR 이관(1987-04-01)이 edge 생애 밖 (edge_dates로 앞 기간을 지운 새 선로 8 edge). 결과에 영향 없음 | 8 | 정보 | 새 항목 |
| T2-15 | 池北線 岡女堂 통과 행이 길이 0 기간 (DBA-023 고침이 남긴 모양) | 1 | 정보 | [알려짐] E17 고침의 남은 것 |
| T2-16 | 지금 휴지 중인 edge 103 (11묶음) 목록. 외부 대조용 | 103 | 정보 | 새 항목 |
| T2-17 | 大崎支線(extra) 1980-10-01~1986-04-02에 정차역이 大崎 하나 | 1 edge | 정보 | 새 항목 |

오류 4종, 의심 6종(알려짐 2 포함), 정보 7종입니다. 나머지 규칙 60여 개는 위반 0입니다(2장).

**깨끗한 것**: `edge_life` 겹침·빈틈·역전·같은 상태 쪼개짐·사유 누락 0, attr 합집합 = life 합집합(경계 원문까지) 0 차이, 사건 효과 검증(사건마다 푼 edge에 같은 날짜의 결과 행이 있는가) 6종 모두 0, 효과 없는 휴지·재개 0, 짝 없는 재개 0, 정차 사건을 버린 곳 0, `last_service`·`legal_abolition`·`valid_to` 순서 위반 0, 1872 이전 날짜 0, 노선 구간 끝을 넘는 정차 0, `route_parallel` 기간 0, names 기간 역전·겹침 0.

## 2. 규칙 추적표

"SQL"은 스냅숏에 그대로 돌린 조건, "스크립트"는 저장소 밖 임시 폴더의 `python3 -I` 스크립트(파이프라인 코드를 재사용하지 않은 독립 구현, EDTF 파서 포함)입니다. 핵심 질의는 부록 A에 있습니다.

### 2.1 날짜 형식과 lo/hi (§5.4, §14)

| 규칙 | 확인 방법 | 위반 | 예 |
|---|---|---:|---|
| 원문이 EDTF(일·월·연·연대) 또는 `ongoing`·NULL이고 달력에 있는 날 | 정규식 + `datetime.date` (edge_life, edge_attr, route_stop, route_link, junction, service, archive, node_move, closed_section, last_service, legal_abolition) | 0 | |
| `valid_from`에 `ongoing` 없음 | SQL 5표 | 0 | |
| `edge_attr`·`route_stop` lo/hi = 원문 범위 | 독립 파서와 비교 | 0 / 0 | |
| `edge_life` lo/hi = 원문 범위 | 같음 | **112칸** | e_011661 `1953-XX-XX` lo 1953-06-26 (원문 범위 1953-01-01). T2-10 |
| 평년 `YYYY-02-XX`의 상한 | `lib.DIM[1]=29` 고정. DB에서 결과가 달라지는 칸 | 0 | 해당 날짜 없음 |
| (정보) 정밀도 분포 | 집계 | — | edge_life 시작: 일 14,521·월 23·연 94·연대 1. route_stop 시작 NULL 11, 끝 NULL 27 |

### 2.2 edge_life (§2.2, §2.8 E, §3.2)

| 규칙 | 확인 방법 | 위반 | 예 |
|---|---|---:|---|
| status ∈ {open, suspended} | SQL | 0 | |
| close_reason ∈ {NULL, abolished, brt, relocated, no_regular_service} | SQL | 0 | |
| 기간 역전 / 길이 0 / 범위 끝이 겹침 / NULL | SQL | 0 / 0 / 0 / 0 | |
| 같은 edge 행끼리 겹치지 않음 | 시작 순 정렬(DB lo) 뒤 앞 끝 > 뒤 시작 | 0 | |
| 빈틈(폐지 뒤 재개) 앞 행에 사유 있음 | 앞 끝 ≠ 뒤 시작이면 close_reason NOT NULL | 0 | 빈틈 자체가 0 (재개는 모두 휴지로 적음) |
| 맞닿은 행(상태만 바뀜)에 사유 없음 | 앞 끝 = 뒤 시작인데 사유 있음 | 0 | |
| 같은 상태가 맞닿아 쪼개지지 않음 | 맞닿고 상태 같음 | 0 | |
| ongoing은 마지막 행 / 끝난 마지막 행에 사유 | 정렬 뒤 비교 | 0 / 0 | |
| 첫 행이 suspended 아님 | SQL | 0 | |
| ongoing 행·상태 전환 행에 last_service·legal_abolition 없음 | SQL | 0 / 0 | |
| last_service < valid_to | `last_service_hi ≥ valid_to_lo` | 0 | |
| open 행의 valid_to = last_service 다음 날 (§2.2 `[from,to)`) | 일 정밀도 행에서 비교 | 0 | 札沼線 2020-04-17 → 2020-04-18 등 |
| 휴지 행이면 last_service < 휴지 시작 | SQL | 0 | |
| legal_abolition ≥ last_service / ≥ valid_to (brt 제외) | 범위 비교 | 0 / 0 | |
| 폐지 행의 legal_abolition NULL은 no_regular_service만 | SQL | 0 | 海峡線 5 |
| 휴지 중 폐지(재해 불통)에 last_service | status=suspended, 사유 있음, last_service NULL | **8** | 常磐線 駒ケ嶺–浜吉田 옛 선로 e_001362~365 등 (T2-02) |
| 법적 폐지일이 그 구간 것 | legal_abolition − valid_to가 수십 년이고 last_service 없음 | **2** | e_004957·958 1956-11-19 / 2027-03-31 (T2-01) |
| (정보) legal_abolition ≠ valid_to | SQL | 244 | 札沼線, 手宮線, 宇品線 등 49묶음. T2-01 말고는 last_service+1 = valid_to이거나 원문에 운행 끝 날짜가 없는 경우 |
| (정보) 지금 휴지 중 | status=suspended, ongoing | 103 | T2-16 |
| 같은 재해의 휴지 시작 규약 | 2011-03-11/12 시작 행 집계 | **73** | T2-02 |

### 2.3 edge_attr와 edge_life (§2.2 이관, §2.8 E)

| 규칙 | 확인 방법 | 위반 | 예 |
|---|---|---:|---|
| attr 기간 역전 / 길이 0 / NULL | SQL | 0 / 0 / 0 | |
| 같은 (edge, line) 기간 겹침 | 정렬 비교 | 0 | |
| edge마다 attr 합집합 = life 합집합 (원문 경계까지) | DB lo로 정렬·병합 뒤 비교 | 0 | 원문 EDTF로만 정렬하면 山鹿温泉鉄道 등 40 edge가 다르게 보임 (T2-10의 뒷면) |
| attr 행 경계가 life 경계이거나 이관 경계 | 원문 비교 | 0 | |
| life ongoing ⇔ ongoing attr 있음 | SQL | 0 | |
| (정보) 같은 lineage가 빈틈을 두고 이어짐 | 정렬 비교 | 0 | |

### 2.4 route_stop (§2.2 정차, §2.8 J, §4.6, ARCHITECTURE §3.5)

| 규칙 | 확인 방법 | 위반 | 예 |
|---|---|---:|---|
| 기간 역전 | SQL | 0 | DBA-023 반영 |
| 정차 행 길이 0 / 범위 끝 겹침 | SQL | 0 / 0 | |
| (정보) 통과 행 길이 0 | SQL | 1 | r_chihoku_line 岡女堂 1989-06-04 (T2-15) |
| 정차 행 기간 NULL | SQL | **37** | 東旭川線 六丁目 1930-12-26~NULL, 久保山線 6역 NULL~1969-10-01 (T2-13 [알려짐]) |
| 같은 계통·노드 정차 행이 기간 겹쳐 둘 | 쌍 비교 | 5 | 모두 순환 계통의 시작=끝 (大江戸線 都庁前 등). 위반 아님 |
| 정차 시작이 계통 노선의 인접 edge보다 이름 | 인접 attr 합집합 첫 시작 lo > 정차 시작 hi | **10** | 室蘭本線 岩見沢 1892 / 1994 (T2-05 [알려짐]) |
| 정차 끝이 인접 edge 끝보다 늦음 | 비교 | 0 | |
| 정차 기간 안에 인접 멤버십 빈틈 | 합집합 빈틈 | 0 | |
| 정차역인데 인접 멤버십 0 | SQL | 0 | |
| 정차 기간 내내 인접 edge가 휴지뿐 | open 합집합과 겹침 없음 | 0 | |
| 그날 확실한 정차역에 그날 인접 선로가 없음 (1950~as_of, 경계일마다) | 스크립트 | 3 | 直江津 1950-01-28, 岩見沢 1953-12-20, 鹿越 1954-07-01 (T2-05와 같은 것) |
| 그날 열린 선로 덩어리에 정차역 2개 이상 | 스크립트 (숨은 끝 계통 제외) | 3 | 陣屋町–元輪西 1970~1978 (T2-06), 大崎支線 1980~1986 (T2-17), 옛 경로 계통 2(본선 계통이 같은 edge를 가짐, 위반 아님) |
| 그날 열린 edge 양쪽에 정차역 (매달린 edge 없음) | 스크립트 | 16 | 大阪環状線 e_003000 (T2-07). 나머지는 옛 경로·본선 분리로 같은 노선 다른 계통이 맡는 곳(白新線, 信越本線, 菊池線, 長尾線)과 京成本線 京成成田–駒井野(東成田線의 숨은 끝으로 탐) |
| (정보) 계통 끝(차수 1) 역 노드가 그날 정차역 | 스크립트 | 178 | 거의 모두 1950 전 임시 종점(函館本線 1902 등). 1950 뒤는 大阪環状線 新今宮 1961, 大崎支線 西大井 1980 둘 |
| 같은 노선·노드의 다른 계통 정차 시작이 맞음 | 스크립트 (b 계통에 그날 인접 선로가 있었는데 a 계통만 정차) | **11** | 大形 1956-04-15 / 1957-02-11 (T2-04) |
| node_move: 옛 노드는 이전일까지, 새 노드는 이전일부터 | 스크립트 | 0 | |
| open_stop 날짜 = 정차 시작 | 원문 비교, 원인 분류 | 19행 | 모두 `stop_dates.json`(14)·`moved.json`(5) 보정 |
| close_stop 날짜 = 정차 끝 | 같음 | 22행 | 모두 `stop_dates.json`(12)·`moved.json`(10) 보정 |

### 2.5 route_link · junction · route_parallel (§2.9, §8.1)

| 규칙 | 확인 방법 | 위반 | 예 |
|---|---|---:|---|
| route_link 기간 역전·길이 0 | SQL | 0 | |
| (정보) route_link 기간 NULL | SQL | 11 | 모두 끝 NULL, transfer (T2-03) |
| route_link가 자기 계통 존재와 겹침 | 계통 attr 합집합과 겹침 | **2** | 水浜線 本社前 → 大洗鹿島線 1985-03-14~NULL (水浜線은 1966-06-01 끝) |
| route_link가 상대 계통 존재와 겹침 | 같음 | **2** | 大洗鹿島線 → 水浜線, 神戸市営 山手線 → 湊川線 1983-06-17~NULL (湊川線 1968-04-21 끝) |
| route_link(역)가 그 순번 정차 기간과 겹침 | 비교 | 0 | |
| route_link가 자기 계통 존재 범위를 넘지 않음 | 처음·끝 비교 | **3** | 城南線 上一万 지선 continue 2행 1927-04-03~ (계통 1969-12-01~), 花園橋線 → 本牧線 1905-07-24~ (계통 1927-03-30~) |
| route_link 중복 (같은 키·겹친 기간) | SQL | 0 | |
| junction 기간 역전 | SQL | 0 | |
| (정보) junction valid_from NULL | SQL | 1,349 | 전부 (T2-11) |
| junction이 양쪽 노선 존재와 겹침 | 비교 | 0 | 기간이 무한이라 늘 겹침 |
| junction이 ongoing인데 한쪽 노선 끝남 | 비교 | 505 | T2-11 |
| route_parallel 기간이 양쪽 계통 존재 범위 안 | 비교 | 0 | 20행 |
| service 기간이 구성 계통 범위 안 | 비교 | 0 | |

### 2.6 사건 원본 (§2.2, data/source/events, events_fix)

원본 사건 8,171줄(jr 4,309, private 3,862)과 events_fix 추가 16줄(케이블카 휴지·재개 8쌍). 종류: open_stop 3,474, open 3,335, close 593, transfer 313, close_stop 292, suspend 106(+8), resume 58(+8). relocate·rename·km_change·set_class·move는 0줄입니다.

| 규칙 | 확인 방법 | 위반 | 예 |
|---|---|---:|---|
| 같은 사건 두 줄 | 출처 뺀 모든 필드 비교 | **2** | open_stop r_joban_line 駒ケ嶺 1952-07-10 (jr.yaml 1055·1061), r_ishinomaki_line 浦宿 1956-02-12 (1253·1258) (T2-12) |
| 같은 대상·종류가 날짜만 다름 | 키 비교 | 20 | 모두 국철→JR 뒤 JR→3섹 이관 둘. 위반 아님 |
| 날짜 형식 | 정규식 | 0 | |
| 날짜 NULL | SQL | 45 | 모두 정차 사건 (close_stop 다수). T2-13 |
| 참조 ID가 DB에 있음 | 집합 비교 | 0 | |
| as_of 뒤 날짜 | lo > 2026-11-02 | 2 | 모두 日田彦山線 legal_abolition 2027-03-31 (T2-01, T2-09) |
| 1872-06-12 전 날짜 | SQL | 0 | |
| 정차 사건을 컴파일이 버림 (계통·노드 없음) | 키 비교 | 0 | |
| 같은 (계통, 노드)에 open_stop·close_stop 여러 개 | 집계 | 2 | 위의 중복 2건뿐. 정차 휴지·재개가 한 기간으로 합쳐진 곳 0 |
| open_stop이 close_stop보다 늦음 | 비교 | 0 | |
| 구간 범위가 edge 0개로 풀림 | 컴파일 기록 | 0 | |
| 효과 없는 휴지 / 재개 | 컴파일 NOOP 기록 | 0 / 0 | |
| 사건 효과가 결과에 남음 (open·close·transfer from/to·suspend·resume) | 사건마다 푼 edge에서 같은 날짜 행 확인 (edge_dates 구간 제외) | 0 × 6 | |
| 이관 날짜가 edge_life 안 | 비교 | 8 | T2-14 |
| 짝 없는 재개 / 폐지 뒤 휴지 | edge별 시간순 상태 | 0 / 0 | |
| 같은 날 같은 edge·노선의 open과 close | 묶음 | 0 | |
| (정보) 같은 날 휴지·재개와 이관 | 묶음 | 30 | 富山港線 2006-03-01 휴지+이관, リアス線 2019-03-23 이관+재개. 정렬 순위(이관 2 < 휴지·재개 4)로 의도대로 풀림 |
| 범위 날짜 사건의 순서가 불분명 | 같은 edge의 범위 겹침 | 3 | 山鹿温泉鉄道 1953·1957, 新潟交通 1964 재개 `YYYY-XX-XX`. `key()`가 재개를 상한으로 정렬하고 `_life_rows`가 lo를 올려 순서를 지킴 (T2-10) |
| events_fix 쓰이지 않는 행 | 컴파일 오류 | 0 | |

### 2.7 날짜 상식

| 규칙 | 확인 방법 | 위반 | 예 |
|---|---|---:|---|
| 1872-06-12 전 날짜 (edge_life, edge_attr, route_stop, 사건) | SQL | 0 | |
| as_of 뒤 날짜 (모든 표) | lo > as_of | 11 | 日田彦山線 legal_abolition 11 edge |
| (정보) archive 폐지 1950 이후 | SQL | 114 | [알려짐] S1(103)·archive_line 11 |
| names 기간 역전·길이 0·겹침 | 스크립트 | 0 / 0 / 0 | |
| closed_section last_service < abolished | SQL | 0 | |
| denominator_unit date_lo/hi = 원문 범위 | SQL | 0 | |
| `edge_link` 옛 끝 = 새 시작 | SQL | 0 | 11행 |

## 3. 오류 상세

### T2-01. 日田彦山線 1956 폐지 구간의 법적 폐지일이 2027-03-31

- 증거: `edge_life` e_004957(石田–妙見), e_004958(妙見–東小倉) `valid_to=1956-11-19`, `legal_abolition=2027-03-31`, `last_service` NULL. `closed_section`의 같은 두 구간 `abolished=2027-03-31`. 원본 `events/jr.yaml:3459` `{"date": "1956-11-19", "type": "close", "line": "l_hitahikosan_line", "edges": ["n_ishida..n_higashi_kokura"], "legal_abolition": "2027-03-31"}`.
- 원인: `tools/gen_source.py` 1008행 `if part.name in LEGAL and fam=='jr':ev['legal_abolition']=LEGAL[part.name]`이 노선 이름만 보고 그 노선의 모든 폐지 사건에 같은 날짜를 붙입니다. `hand_tables.json` `LEGAL`의 `日田彦山線: 2027-03-31`은 BRT 구간(添田–夜明) 값입니다. 宇品線은 두 폐지(1966, 1972) 모두 1986-10-01이 맞는 값이라 겉으로는 드러나지 않습니다.
- 영향: 화면의 폐지 연도(`closed_section.abolished`)가 1956 구간에서 2027로 나옵니다. 수록 범위 판정(§4.6)은 둘 다 1950 뒤라 결과가 같습니다.
- 고침: `gen_source.py`에서 `LEGAL`을 (노선, 구간 첫 역)으로 거는 `BRTDAY`처럼 구간 키로 바꾸거나, 폐지일이 표의 값보다 이른 구간에만 걸고 그 밖에는 `d`를 씁니다. 1956 구간의 법적 폐지일은 출처로 다시 확인합니다(원본 대조는 감사 5 범위).

### T2-02. 2011-03-11 휴지 시작일이 규약과 다름 (73 edge)

- 증거: `status=suspended`이고 시작이 2011-03-11인 행 73(常磐線 24, 仙石線 11, 石巻線 6, 山田線 15, リアス線 17. 이 가운데 이설로 끝난 옛 선로 8), 2011-03-12인 행 28(気仙沼線 17·大船渡線 11, `last_service=2011-03-11`). 앞쪽은 `data/overrides/suspended.json`의 `2011-03-11`에서, 뒤쪽은 `hand_tables.json`의 마지막 운행일 `2011-03-11`(+1일)에서 옵니다.
- 규칙: §2.2 기간은 `[from, to)`이고 끝은 "더는 탈 수 없게 된 첫날"입니다. `suspended.json`도 米坂線 메모에 "온종일 운휴한 첫날을 씀"이라고 적고 있습니다. 2011-03-11은 지진(14:46) 전까지 열차가 다녔으므로 첫 운휴일은 03-12입니다.
- 영향: 그날 오전 常磐線·仙石線·石巻線·山田線·三陸鉄道를 탄 기록은 저장할 때 "탈 수 없는 날짜"로 막히고(§2.8 J), CSV로 들어오면 날짜 모름이 됩니다. 같은 재해인데 気仙沼線은 되고 常磐線은 안 됩니다.
- 함께: 이설로 끝난 옛 선로 8 edge(常磐線 駒ケ嶺–浜吉田 4, 仙石線 陸前大塚–陸前小野 3, 石巻線 浦宿–女川 1)는 휴지 중 폐지인데 `last_service`가 NULL입니다(§2.2 "재해로 불통인 채 끝난 구간… `last_service`는 실제 마지막 운행일").
- 고침: `data/overrides/suspended.json`의 동일본 대지진 행 전부(`北リアス線`·`南リアス線` 중복 행 포함)를 `2011-03-12`로. `gen_source.py`가 `@old` 옛 선로의 relocate 폐지에도 휴지 시작 전날을 `last_service`로 넣게 합니다. 고친 뒤 `edge_life` 휴지 시작 2011-03-11 행 0을 db_regression에 넣습니다.

### T2-03. route_link가 모르는 날짜(NULL)를 무한으로 봄

- 증거: `route_link` 11행이 `valid_to` NULL입니다(모두 transfer). 그중
  - `r_suihin_line` seq 13 ↔ `l_oarai_kashima_line` 1985-03-14~NULL, 반대쪽 `r_oarai_kashima_line` seq 0 ↔ `r_suihin_line` 같은 기간. 茨城交通 水浜線 attr의 끝은 1966-06-01입니다.
  - `r_minatogawa_line` seq 1 ↔ `l_yamate_line` 1983-06-17~NULL과 그 반대. 湊川線 끝은 1968-04-21입니다.
  - `r_hanazonobashi_line` seq 2 → `l_hommoku_line` 1905-07-24~1970-07-01. 이 계통의 attr은 1927-03-30부터입니다.
- 원인: `compile.py` `period()`가 정차의 `valid_to` NULL을 `9999-12-30`으로, `valid_from` NULL을 `0000`으로 봅니다. 정차 끝 자르기(D4)도 `valid_to in (None,'ongoing')`을 건너뜁니다. 本社前·湊川公園·花園橋線 정류장들은 정차 기간이 NULL입니다(T2-13).
- 영향: 그날 계통이 없으므로 화면에 나올 일은 없지만 행 값이 틀립니다. 앱이 `route_link` 기간만으로 판정하는 곳(ARCHITECTURE §3.5 "분기 기간")에서 1985년 날짜로 水浜線 환승을 묻으면 참이 나옵니다.
- 고침: `compile.py` `period()`에서 NULL 끝을 그 계통의 인접 attr 범위(시작은 최소, 끝은 최대)로 묶고, 묶은 뒤 겹침이 없으면 행을 만들지 않습니다. 정차 원문의 NULL은 그대로 둡니다(§5.4 모름).

### T2-04. 같은 역의 계통별 정차 시작이 다름

- 증거: 같은 노선·같은 노드가 두 계통에서 정차하고, 늦게 시작하는 쪽 계통에도 그 날짜에 인접 선로가 있었던 쌍이 11입니다.
  - 白新線 大形: `r_hakushin_line_higashi_niigata_nuttari`(沼垂 경유 옛 경로) 1956-04-15, `r_hakushin_line` 1957-02-11(`jr.yaml:1648` open_stop, wikipedia). 1956-04-15~1957-02-10에 옛 경로 계통으로 大形 승하차가 저장됩니다.
  - 北陸本線 浦本: 옛 경로 계통 1912-12-16, 본선 계통 1950-01-28(open_stop). 1950-01-01~01-27이 걸립니다.
  - 나머지 9쌍(根室本線 東鹿越 1901/1941, 中央本線 田立 1909/1948, 東北本線 品井沼 1890/1932·利府 1890/1894, 北陸本線 有間川 1911/1947, 可部線 安芸長束, 鹿児島本線 枝光 2, 足尾線 沢入)은 늦은 쪽 시작이 1950 전이라 기록 범위 밖입니다.
- 원인: open_stop·close_stop은 `route` 하나에 걸리고, 사건이 없는 계통은 `compile.py`가 인접 attr 최소 시작을 씁니다. 옛 경로 계통은 `gen_source.py`가 선로만 만들고 정차 사건을 복사하지 않습니다.
- 고침: `compile.py` 정차 계산에서 같은 노선의 다른 계통에 그 노드의 open_stop/close_stop이 있으면, 자기 사건이 없는 계통도 그 날짜를 쓰게 합니다(계통 선로 범위로 자르는 지금 규칙은 그대로). 또는 `gen_source.py`가 옛 경로 계통에도 정차 사건을 냅니다.

## 4. 의심 상세

### T2-05. [알려짐 S8] 정차 시작이 인접 선로보다 이름 (10), 원인은 컴파일 순서

- 10행: 室蘭本線 岩見沢(1892 / 인접 1994-11-01), 根室本線 鹿越(1901 / 1966-09-29), 中央本線 南木曽(1909-07-15 / 09-01), 北陸本線 直江津(1911 / 1969-10-01), 伯備線 美袋, 土讃線 大杉, 会津線 湯野上温泉, 西鉄 栄町(`stop_dates` 1938-10-01 / 1939-07-01), 長尾線 瓦町(1927 / 1945-07-30), 伊予鉄 城南線 지선 上一万(1927-04-03 / 1969-12-01).
- 10행 중 8행(栄町·瓦町 말고 전부)은 인접 edge에 `edge_dates.json` 값이 있습니다. `compile.py`는 290행대에서 `route_stop`을 만들고 355행대에서 `edge_dates`로 앞 기간을 지우므로, 정차와 그 정차로 만든 `route_link`가 지운 기간을 이어받습니다. 城南線 지선의 continue 2행(1927-04-03~)이 그 예입니다.
- 1950 뒤에 걸리는 것은 岩見沢(본선 계통 1950~1994), 鹿越(1950~1966), 直江津(1950~1969), 上一万 지선(1950~1969)입니다. 앞의 셋은 같은 노선의 옛 경로 계통이 그 기간을 맡아 노선 안 경로 탐색으로는 이어집니다. 본선 계통 화면에서는 고를 수 있는데 갈 선로가 없습니다.
- 고침: `compile.py`에서 `edge_dates` 블록을 정차 계산 앞으로 옮기거나, 적용 뒤 정차 시작을 인접 attr 최소 시작으로 한 번 더 자릅니다(끝 자르기 D4와 대칭). 栄町·瓦町은 `stop_dates`/선로 날짜 중 어느 쪽이 맞는지 출처를 확인합니다.

### T2-06. 室蘭本線 陣屋町–元輪西 (1970~1978)

- `r_muroran_main_line_kogane_moto_wanishi`의 e_000241(陣屋町–元輪西 3.0km)은 1925-08-20~1978-10-03 영업, `denominator_unit` normal입니다. 陣屋町 정차는 1970-08-01에 끝나고 이 edge는 다른 계통에 없습니다. 1970-08-01~1978-10-02에는 이 edge를 지나는 탑승을 만들 수 없는데 1971~1977년 분모에 3.0km가 들어갑니다.
- 고침: 陣屋町 여객 취급 끝과 이 구간 여객 영업 끝 중 어느 쪽이 틀렸는지 출처로 확인해 `stop_dates.json` 또는 사건(`gen_n05.py`/`n05_fix.json`)을 고칩니다. 같은 모양을 잡는 검사(그날 열린 edge 양쪽에 정차역)를 db_regression에 넣습니다.

### T2-07. 大阪環状線 今宮–新今宮 (1961~1964)

- e_003000(今宮–新今宮 1.2km)이 1961-04-25부터 大阪環状線입니다. 新今宮 정차는 1964-03-22부터이고 新今宮–天王寺(e_002841)는 関西本線만 가집니다. 1961~1964에 이 edge는 정차역 없는 끝이라 환상선으로는 탈 수 없고, 연도 분모에는 들어갑니다.
- 고침: 1961~1964 환상선 열차가 今宮 너머 天王寺까지 関西本線 선로로 다녔다면 e_002841·e_003000을 어떻게 집계할지 정하고, 아니면 e_003000의 환상선 시작을 1964-03-22로(`edge_dates.json`) 둡니다.

### T2-08. 옛 선로 폐지 사유 (61 edge)

- 같은 노선의 새 선로가 같은 날 시작하는(`edge_dates.json`) 옛 경로 계통 26개, 61 edge의 사유가 `abolished`입니다(中央本線 南木曽–田立 1973, 信越本線 横川–軽井沢 1963, 室蘭本線 志文–岩見沢 1994, 白新線 沼垂 경유 1958 등). 吾妻線·常磐線·仙石線·石巻線 등 `@old` 11 edge만 `relocated`이고 `edge_link`도 그 11개뿐입니다.
- §2.2는 역 이전을 수반하는 선로 교체를 `relocate`로 적게 합니다. 지금은 같은 일이 두 값으로 나뉘어, 사유로 이설을 거르는 화면·검사가 61 edge를 폐선으로 셉니다.
- 결정 필요: 옛 경로 계통의 폐지를 `relocated`로 바꿀지, 역 이전이 없는 곳은 `abolished`로 둘지. 바꾸면 `gen_source.py`(또는 `compile.py`가 edge_dates와 같은 날 닫히는 옛 경로 edge에 사유를 붙임)에서 하고 `edge_link`도 채웁니다(위상은 감사 3과 맞춤).

### T2-09. 日田彦山線 BRT 구간 법적 폐지일이 as_of 뒤

- 添田–夜明 9 edge `legal_abolition=2027-03-31`, `valid_to=2023-08-28`(BRT 첫날), `last_service=2017-07-05`. 판의 as_of(2026-11-02)보다 뒤의 날짜는 이 값뿐입니다. 근거(`hand_tables.json` `LEGAL`)에 출처가 적혀 있지 않습니다. 감사 5의 원본 대조 대상으로 넘깁니다.

### T2-13. [알려짐 S11] 정차 기간 NULL (37)

- 시작 NULL 11(久保山線 6, 花園橋線 5), 끝 NULL 26(東旭川線 5, 川尻線 3, `r_shinai_line` 4, 広瀬線 3, 東川線 2, 呉 `r_kogai_line` 2, 水浜線 1, 湊川線 1 등), 통과 행 1(高島貨物). 원천은 날짜 없는 정차 사건 45줄입니다(`stop_dates`·`moved`가 19줄을 메움). T2-03의 원인이기도 합니다.

## 5. 정보

- **T2-10** `_life_rows`가 범위 경계(`1953-XX-XX` 등)의 하한을 앞 행 시작으로 올립니다(45 edge, 112칸: 山鹿温泉鉄道 1953·1957 재개, 新潟交通 1964 재개 등). 순서를 지키려는 의도이고 결과는 맞지만, 명세는 lo/hi를 원문 범위로 정의합니다. DESIGN §14에 "edge_life의 lo는 앞 행 시작보다 이르지 않게 올린다"를 적거나, 원본을 앞 휴지 다음 날 이후로 좁힌 EDTF로 둘 것을 제안합니다.
- **T2-11** `junction` 1,349행은 `valid`가 없어 전부 NULL~ongoing입니다(§2.9 예시는 `valid: [1894-XX-XX, ongoing]`). 배포 팩에서 빠지고 `route_link`가 정차 기간으로 기간을 만들므로 앱에는 영향이 없습니다. 쓰지 않을 값이면 §14에서 열을 "비어 있음"으로 적거나, `gen_wiki.py`가 두 노선 멤버십의 겹침으로 채웁니다.
- **T2-12** 중복 open_stop 2줄. 컴파일은 첫 줄만 써서 결과는 같습니다. 역 이전 구간(`@old`/`@new`)을 잇는 곳에서 두 번 냅니다. `gen_source.py` 사건 출력 전에 중복을 지웁니다.
- **T2-14** 1987-04-01 이관이 edge_life 밖인 8 edge(e_000231 志文–岩見沢, e_000277, e_001017, e_003601, e_004133·134, e_004401·402)는 `edge_dates`가 국철 기간을 지운 새 선로입니다. JR 행의 시작이 edge_dates 값으로 바뀌어 결과는 맞습니다.
- **T2-15** 池北線 岡女堂 통과 행 `valid_from=valid_to=1989-06-04`. DBA-023 고침이 시작을 끝에 맞춘 결과입니다. 통과 행이라 판정에 쓰이지 않습니다.
- **T2-16** 지금 휴지 중: 肥薩線 八代–吉松(2020-07-04~, 18), 津軽線 蟹田–三厩(2022-08-04~, 7), 米坂線(2022-08-04~, 14), 大井川鐵道(2022-09-24~, 8), 美祢線(2023-06-30~, 11), 陸羽東線(2024-07-26~, 12), いすみ鉄道(2024-10-05~, 13), 北上線(2026-08-02~, 7), 小湊鐵道(2026-09-20·21~, 10), 久留里線(2026-09-21~, 3). 津軽線의 폐지 예정(`suspended.json` 메모 2027-04-01)은 사건에 없습니다(예정 사건을 넣을지는 §2.8 J 결정).
- **T2-17** 大崎支線(extra) 1980-10-01~1986-04-02는 정차역이 大崎 하나라 기록할 수 없습니다. 분모 밖이라 통계 영향은 없습니다.
- 사건 정렬: `compile.py` `key()`는 범위 날짜를 하한으로, 재개만 상한으로 정렬합니다. 범위 날짜 휴지(`1944-XX-XX` 케이블카 등)는 같은 해 다른 사건보다 앞에 옵니다. 지금 데이터에서 순서가 불분명한 쌍은 위의 3쌍(재개)뿐입니다.
- as_of(2026-11-02)와 판 날짜(11-06) 사이의 사건은 없습니다.

## 6. 고칠 곳 모음

| 항목 | 파일·생성기 | 할 일 |
|---|---|---|
| T2-01 | `tools/gen_source.py` 1008행, `data/overrides/hand_tables.json` `LEGAL` | 구간 키로 걸기. 1956 구간 법적 폐지일 확인 |
| T2-02 | `data/overrides/suspended.json`, `tools/gen_source.py` relocate 폐지 | 2011-03-12로. 옛 선로 `last_service` 2011-03-11 |
| T2-03 | `tools/compile.py` `period()` | NULL을 계통 attr 범위로 묶고, 겹침 없으면 행 안 만듦 |
| T2-04 | `tools/compile.py` 정차 계산 (또는 `gen_source.py`) | 같은 노선 다른 계통의 정차 사건을 함께 씀 |
| T2-05 | `tools/compile.py` `edge_dates` 블록 위치 | 정차 계산 앞으로, 또는 시작 자르기 추가 |
| T2-06 | `stop_dates.json` 또는 N05 사건 | 출처 확인 뒤 한쪽 고침 |
| T2-07 | `edge_dates.json` 또는 사건 | 1961~1964 환상선 집계 결정 |
| T2-08 | `gen_source.py`/`compile.py` | 결정 뒤 사유·`edge_link` |
| 검사 | `tools/db_regression.py` | 2011-03-11 휴지 시작 0, route_link 기간 ⊆ 양쪽 계통 존재, 그날 열린 edge 양쪽 정차역, 같은 노선 계통 간 정차 시작 일치, legal_abolition − valid_to > 20년이면서 last_service 없음 0 |

## 부록 A. 핵심 질의

스냅숏 경로를 `$S`로 둡니다. 스크립트는 감사 중 임시 폴더에 두었고(`checks.py`, `events.py`, `ride.py`, `xroute.py`, `avl.py`, `misc.py`), 아래는 그중 SQL로 바로 되는 것입니다.

```sql
-- T2-01 법적 폐지일이 그 구간 것이 아님
select edge_id,valid_to,legal_abolition,last_service from edge_life
 where last_service is null and legal_abolition is not null
   and julianday(legal_abolition)-julianday(valid_to_hi) > 365*20 and edge_id not in ('e_005881');  -- 手宮線은 출처 있음
-- T2-02 휴지 시작 규약
select valid_from,count(*) from edge_life where status='suspended' and valid_from in ('2011-03-11','2011-03-12') group by 1;
select edge_id from edge_life where status='suspended' and close_reason is not null and last_service is null;
-- T2-03 route_link NULL 끝, 계통 존재 밖
select route_id,seq,other_line_id,kind,valid_from,valid_to from route_link where valid_from is null or valid_to is null;
-- edge_life 겹침·빈틈 (0이어야 함)
select a.edge_id from edge_life a join edge_life b on a.edge_id=b.edge_id and a.rowid<b.rowid
 where a.valid_from_lo < b.valid_to_hi and b.valid_from_lo < a.valid_to_hi
   and not (a.valid_to=b.valid_from or b.valid_to=a.valid_from);
-- open 행 valid_to = last_service + 1일
select edge_id,last_service,valid_to from edge_life where status='open' and last_service glob '????-??-??'
 and valid_to glob '????-??-??' and date(last_service,'+1 day')!=valid_to;
-- 정차 시작이 인접 선로보다 이름 (T2-05)
select s.route_id,s.node_id,s.valid_from,min(a.valid_from_lo) from route_stop s join route r on r.id=s.route_id
 join route_edge re on re.route_id=s.route_id join edge e on e.id=re.edge_id and s.node_id in (e.from_node,e.to_node)
 join edge_attr a on a.edge_id=e.id and a.line_id=r.line_id
 where s.is_stop=1 and s.is_extension=0 and s.valid_from is not null
 group by s.rowid having s.valid_from_hi < min(a.valid_from_lo);
```
