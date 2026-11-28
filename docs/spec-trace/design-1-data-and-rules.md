# noriori DESIGN.md 명세 감사 A: 1행 ~ §7 직전

- 대상: `docs/DESIGN.md` 머리말, §0~§6, v0.42의 §6.1. §7 이후는 범위 밖입니다.
- 판정 시각: 2026-11-05 작업본 (HEAD ada124d, DESIGN v0.51, ARCHITECTURE v0.13). 표는 2026-11-02 21시 코드로 만들었고, 2026-11-05에 `미구현`·`부분`·`미연결` 행을 지금 코드에서 다시 읽어 판정했습니다. `구현됨` 행은 요구가 바뀐 것만 다시 봤습니다. 명세 행 번호와 근거 행 번호는 `tools/dev/trace_refresh.py`로 옮긴 뒤 다시 판정한 행과 어긋난 행을 손으로 맞췄습니다. 뒤에 기호가 없는 근거 번호 중 손으로 보지 않은 것은 옮김 계산입니다..
- 판정 값: 구현됨 / 부분 / 미구현 / 미연결 (코드나 저장소는 있으나 화면에서 부르지 않음) / 문서 오류 / 대상 아님.
- `뼈대라서 나중에`는 사유로 쓰지 않았습니다. P1은 v1.0 범위(L1084, L1782)로 판정했고, P2·서버·배포 단계만 대상 아님입니다.
- 팩 수치는 `build/master.sqlite`, `build/names.sqlite`를 읽기 전용으로 조회했습니다. 이 감사는 앱을 실행하지 않았고 테스트도 돌리지 않았습니다. 화면 항목의 `구현됨`은 코드를 읽어 내린 판정이고, 추적표 규칙 5의 목업 대조는 하지 않았습니다.

## 집계

| 판정 | 항목 수 |
|---|---|
| 구현됨 | 519 |
| 구현됨(이름 다름) | 1 |
| 부분 | 48 |
| 미구현 | 41 |
| 미연결 | 0 |
| 문서 오류 | 28 |
| 문서 누락 | 0 |
| 대상 아님 | 43 |
| **합계** | **680** |

## 근거 약어

| 약어 | 경로 |
|---|---|
| `A/` | `apps/noriori/lib/` |
| `C/` | `packages/noriori_core/lib/src/` |
| `S/` | `packages/noriori_store/lib/src/` |
| `T/` | `tools/` |
| `RS` | `A/features/record/ui/record_session_screen.dart` |
| `SL` | `A/features/record/ui/session_lines.dart` |
| `SB` | `A/features/record/ui/session_save_bar.dart` |
| `RC` | `A/features/record/controller/record_session_controller.dart` |
| `BS` | `A/features/record/ui/browse_screens.dart` |
| `MH` | `A/features/map/ui/map_home_screen.dart` |
| `MS` | `A/features/map/map_style.dart` |
| `ST` | `A/features/stats/ui/stats_screen.dart` |
| `RR` | `C/network/route_resolver.dart` |
| `RI` | `C/network/ride_interpreter.dart` |
| `CP` | `T/compile.py` |
| `WF` | `.github/workflows/data.yml`, `.github/workflows/flutter.yml` |
| `LD` | `A/features/record/ui/line_detail_screen.dart` |
| `LC` | `A/features/record/controller/line_detail_controller.dart` |
| `DG` | `C/network/line_diagram.dart` |
| `CUT` | `C/network/ride_cut.dart` |
| `SS` | `A/features/record/ui/service_session_screen.dart` |
| `SC` | `A/features/record/controller/service_session_controller.dart` |
| `SP` | `C/network/service_splitter.dart` |
| `MP` | `A/features/record/ui/map_sheets.dart` |
| `DEL` | `A/features/data/ui/deleted_screen.dart` |
| `CE` | `C/importing/csv_export.dart` |
| `pack` | 빌드된 팩의 실측값 |

## 항목표

### 머리말 (L1~26)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 1 | L23 | 글꼴 Pretendard | 구현됨 | apps/noriori/pubspec.yaml 글꼴 3종, A/main.dart `registerFontLicense` |
| 2 | L23 | 설정에 오픈소스 라이선스 | 구현됨 | A/features/settings/ui/settings_screen.dart `showLicensePage` |
| 3 | L23 | 역 선택기 머리글이 노선을 맡은 회사를 모두 표시 | 구현됨 | RC:354 `operatorName`, C/network/network.dart:202 `operatorsOn` |
| 4 | L26 | 쓰기 DB 하나 + 교체형 데이터 팩 | 구현됨 | S/startup/cold_start.dart:94, C/pack/pack_choice.dart:18 |

### §0 원칙 (L30~42)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 5 | L34 | 코드·데이터·파이프라인 공개 | 구현됨 | LICENSE·NOTICE·data/LICENSE·data/NOTICE.md 있음. 공개 저장소 `1window2/noriori` (2026-11-26, DESIGN §17 GitHub). 2026-11-27 재판정 |
| 6 | L34 | 광고·결제 없음 | 구현됨 | apps/noriori/pubspec.yaml 광고·결제 의존성 없음 |
| 7 | L35 | 서버 없이 모든 기능이 기기 안에서 동작 | 구현됨 | 지도 배경과 글자까지 앱에 내장. 온라인 배경을 끊은 빌드로 확인 |
| 8 | L35 | 언제든 서버를 붙일 수 있는 구조 | 구현됨 | S/db/tables.dart:5 `updated_at·deleted_at·device_id`, S/records/record_store.dart:23 단일 쓰기 지점 |
| 9 | L36 | 사실은 모듈별 파일에 한 번만 | 구현됨 | data/source/<모듈>/*.yaml |
| 10 | L36 | 노선 변화는 이벤트로 남김 | 문서 오류 | redesign 4.1 `안 쓰는 이벤트 규범: 문서를 실제 방식으로 고침`. data/source/events 실측 7종뿐 (rename·move·km_change·relocate·set_class 0건). DESIGN §2.2 미갱신 (M12) |
| 11 | L38 | 기록과 지도 분리 | 구현됨 | S/db/tables.dart:50 ride_leg는 노드·계통만 저장, 선형은 rail.pmtiles |
| 12 | L39 | 기록은 역 목록·순서·km가 확정된 것만 | 구현됨 | pack: coverage 766노선 전부 기록 가능 이상 |
| 13 | L39 | 표시는 순서가 명확한 것까지 | 구현됨 | pack: archive_stop 439, archive_line 140. SL:664 `_ArchiveTile` |
| 14 | L39 | 지도는 정밀 위치까지 확인된 것만 | 대상 아님 | redesign 4.1 `역 위치 규칙`: 폐역은 approx도 점 유지. DESIGN §4.7은 미갱신 (모순 M4) |
| 15 | L40 | 웹뷰 금지, 로컬 사전 계산 값 사용 | 구현됨 | webview 의존성 없음. C/score/scorer.dart 판정, pack denominator_unit |
| 16 | L41 | ko/en 동시 지원 | 구현됨 | ko, en, ja. 설정 슬라이드 바, 그 자리 전환 (`languageProvider`). 에뮬레이터에서 확인 |
| 17 | L41 | 일본어 지원 | 구현됨 | 결정됨: 일본어 동시 출시. `ja.i18n.json`, 이름 순서 `japaneseFirst` |
| 18 | L42 | Android 우선, iOS 같은 코드로 병행 | 구현됨 | apps/noriori/android, apps/noriori/ios |

### §0 배포 전략 (L45~51)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 19 | L47 | Android 배포 경로 (Releases → F-Droid → Play) | 대상 아님 | L1796 Phase 4 |
| 20 | L48 | iOS 서명 안 된 IPA 사이드로드 | 대상 아님 | L1796 Phase 4 |
| 21 | L49 | TestFlight | 대상 아님 | L49 "유료 Apple 계정 생기면 추가" |
| 22 | L51 | 화면 표기 소문자 noriori | 구현됨 | A/i18n/ko.i18n.json app.name |

### §1 채택안 (L67)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 23 | L67 | 논리 DB가 기록 기준, 지도 선형은 독립 층, ID로만 참조 | 구현됨 | S/db/tables.dart:50, T/gen_tiles.py |

### §1.1 노리츠부시 구조의 반영 (L72~85)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 24 | L72 | 노선 아래 계통 모듈 | 구현됨 | pack: route 823, 2개 이상 계통을 가진 노선 42개 |
| 25 | L73 | km 축은 계통별 | 구현됨 | pack: route_stop.km_cum, CP:284 |
| 26 | L74 | 날짜 미상·부분 날짜 허용 | 구현됨 | `parseDateInput`이 연대를 받음 |
| 27 | L75 | 폐역은 회색·선택 불가 + `~연도`, 탑승일 기준 판단 | 구현됨 | SL:151 `_note`, SL:180 tier3, C/network/selector.dart:84 |
| 28 | L76 | 운전 계통 검색과 노선별 구간 표시 | 구현됨 | A/features/record/controller/line_search_controller.dart:36-39,51-57, 입력 SS:15-157, 분해 SP:59-96,186-196 |
| 29 | L77 | JR 한 구간 한 노선, 사철 사업자별 집계 | 구현됨 | pack: 代々木–新宿 山手線만, 京成·北総 별도 노선 |
| 30 | L78 | 개업 이력은 open 이벤트 | 구현됨 | data/source/events open 2,631건 |
| 31 | L80 | 기본 승계 + 옵션 | 구현됨 | `carryoverProvider`, 설정 스위치 |
| 32 | L81 | 폐지 단계별로 구분해 표시 | 구현됨 | C/network/display_rules.dart `SectionLine`, SL:682 `~연도 폐지` |
| 33 | L82 | BRT 전환은 폐선 취급 | 구현됨 | pack: 日田彦山線·気仙沼線 close_reason=brt |
| 34 | L83 | 사업자 분류 채택 | 구현됨 | pack: operator.category 8종 |
| 35 | L85 | 기준일 지도(타임 슬라이더) 발상 반영 | 구현됨 | 지도 `연도` 칩, `yearFilter` |
| 36 | L85 | 네이티브 벡터 지도 즉시 반영 | 구현됨 | MH:186 `_repaint`, MS `riddenFilter` |

### §1.2 DB 구조 비교의 noriori 열 (L90~105)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 37 | L90 | (노선, 역, 날짜) → 구간으로 펼침 | 구현됨 | RR:113 `record` |
| 38 | L91 | 진행률 기준 영업km | 구현됨 | C/score/scorer.dart:100 `computeScore` |
| 39 | L92 | 구간·역을 그 자리에서 전환 | 구현됨 | LD:78-86,228 구간 전환, LD:88-113 역 방문 전환, CUT:45-119 |
| 40 | L92 | 일괄 삭제 | 구현됨 | 여정 전체 삭제 A/features/record/controller/trip_controller.dart:72, A/features/record/ui/trip_screens.dart:136,185. 되돌리기 있음 |
| 41 | L93 | 역 신설이 기록에 영향 없음 | 구현됨 | S/db/tables.dart:50 기록은 노드 기준 |
| 42 | L94 | 영업km 개정이 기록에 영향 없음 | 구현됨 | S/db/tables.dart:50 기록은 노드 기준 |
| 43 | L95 | 기본 승계, 끌 수 있음 | 구현됨 | `carryoverProvider`, 설정 스위치 |
| 44 | L96 | 모든 구간·역에 기간 + 3가지 완주율 | 구현됨 | ST:24 `_Kind`, C/score/scorer.dart:62 |
| 45 | L97 | 1950-01-01 이후 국철·JR + 검증된 사철 | 구현됨 | pack 2026-11-04.1: 법적 폐지 기준일 전 0건. N05와 교차 검증한 옛 폐선 74노선(T/gen_n05.py). 옛 노면전차망은 명세가 미룬 다음 단계 |
| 46 | L98 | 한 노선 안에서 폐지 단계별 표시 | 구현됨 | SL:683, C/network/display_rules.dart `SectionLine` |
| 47 | L99 | 계통 + 집계 멤버십 + 운전 계통 | 구현됨 | 계통·멤버십 기존, 운전 계통 입력 SS:15-157, SP:59-96 |
| 48 | L100 | 일·월·연도·연대·모름 + 범위 계산 | 구현됨 | 연대 입력 `198X` |
| 49 | L101 | 선형 오류가 기록에 번지지 않음 | 구현됨 | 기록은 선형을 읽지 않음 C/network/route_resolver.dart |
| 50 | L102 | 공개 파일 + PR + 자동 검증 | 부분 | PR마다 `CI`가 `Data`를 돌림 .github/workflows/ci.yml:48-63. T/all.sh:26-39가 컴파일 오류(CP:849)·verify·check_geometry·check_ids·appsim·invariants에서 멈춤. 저장소가 private(L1816)이라 공개 파일과 PR 기여는 공개 뒤 |
| 51 | L103 | 역 방문 단독 기록 | 구현됨 | C/records/record.dart:342 `Visit`, 입력 MP:29-41,70-75와 LD:88-113, 목록 MP:131-165 |
| 52 | L104 | 운전 계통 입력 | 구현됨 | 한 줄 노선도에 줄기·범위 칠하기·역 상태·그날 없는 구간 흐림 A/features/record/ui/service_session_screen.dart:125-130,157-172. 판 선택은 결정으로 빠짐 |
| 53 | L105 | 입력 화면 분기선 표시 | 구현됨 | SL:501 `_BranchTile`, A/features/record/ui/session_painters.dart `BranchPainter`, 설정 켜고 끔 |

### §1.4 노리츠부시 추가 확인의 반영 (L136~141)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 54 | L136 | 기록의 구간도 수정 가능 | 구현됨 | 구간 전환 LD:78-86, 잘라 내기 CUT:45-119. 날짜·메모는 A/features/record/ui/record_edit_screen.dart:82-123 |
| 55 | L137 | 미승 구간 목록 화면 (P1) | 구현됨 | `RemainingScreen` |
| 56 | L138 | 별선·단락선 extra | 구현됨 | pack: extra 노선 25개 |
| 57 | L139 | 열차명 검색 | 대상 아님 | L139 "(P2)", L1084 "P2 이후" |
| 58 | L140 | 운전 계통 + 폐선 한 번에 입력 | 구현됨 | L140 원문이 `탑승일 기준으로 자연히 가능`. 역 선택기가 그날 상태로 현행·폐지 구간을 한 노선에서 고름 C/network/selector.dart:93-138, RR:100-122. 별도 운전 계통 항목은 없음 |
| 59 | L141 | 도도부현별 노선 찾기 (P1) | 미구현 | A/features/record에 도도부현 경로 없음 |

### §1.5 테츠로그에서 가져올 것 (L146~163)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 60 | L147 | 가로 스트립을 노선 상세 상단에 | 구현됨 | LD:298-304 |
| 61 | L148 | 저장 전 미리보기: 구간 수 + km + 노선별 분해 | 구현됨 | `RecordSessionState.split`, 저장 바 |
| 62 | L149 | 출발역 뒤 도착역 목록의 거리 힌트 `+3 stops` | 구현됨 | SL:251-258, RC:183-189 |
| 63 | L150 | 세로 노선도 위 역 검색 | 구현됨 | RS:67~73 |
| 64 | L151 | 노선 카드: 상태색 띠, km·%, 역 수 보조 | 문서 오류 | DESIGN §8.0 위치 띠가 §1.5 색 띠·역 수 보조를 대체 A/features/record/ui/line_tile.dart:90 |
| 65 | L152 | 노선 상세 맨 위 큰 % | 구현됨 | LD:278-290 |
| 66 | L153 | 회사 → 노선 2단 탐색 | 구현됨 | A/app/router.dart `_browse`, BS:194 |
| 67 | L153 | 즐겨찾기 고정 | 미구현 | 코드·저장 없음 |
| 68 | L154 | 3단 표기, 원어 병기 옵션 | 대상 아님 | redesign 4.1 `원어 병기`: 선택기 항상, 로마자 3단 뺌. 지도 옵션 몫은 D2:97 |
| 69 | L155 | 지도 상단 검색창 + % 캡슐 + 필터 칩 | 구현됨 | MH:159~177, MH `_SearchBar` |
| 70 | L156 | 노선 단독 지도 | 구현됨 | 노선 상세 지도 버튼, `soloLineProvider` |
| 71 | L157 | 우측 버튼: 현재 위치 | 대상 아님 | 2026-11-03 결정: 뺌 |
| 72 | L157 | 우측 버튼: 근처 역 | 대상 아님 | 2026-11-03 결정: 뺌 |
| 73 | L157 | 우측 버튼: 지도 종류 | 대상 아님 | redesign 4.4 #1 지도 버튼과 근처 역 뺌 |
| 74 | L157 | 우측 버튼: 표시 설정 | 대상 아님 | redesign 4.4 #1 지도 버튼과 근처 역 뺌 |
| 75 | L158 | 축하 카드: 도장 + 마스코트 + 공유 | 구현됨 | `showCompleteCard`. 마스코트는 v1.0 뒤 |
| 76 | L159 | 빈 화면 안내 | 구현됨 | A/features/record/ui/record_list_screen.dart:38, ST:175 |
| 77 | L160 | 차량 도감 | 대상 아님 | L160 "(P2)" |
| 78 | L161 | 첫 기록 안내 카드 | 구현됨 | A/features/record/ui/continue_sheet.dart:88 |
| 79 | L162 | 역 기록 시트 (메모, 사진 3장, 탄 차량, P1) | 대상 아님 | 2026-11-03 결정: 사진 뺌 |
| 80 | L163 | 곁들임 정보 | 대상 아님 | L163 "(P2)" |

### §1.5 따라 하지 않을 것 (L168~172)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 81 | L168 | 닫기 없는 축하 시트를 쓰지 않음 | 구현됨 | 축하 시트 자체가 없음. 승차권은 5초 뒤 사라짐 A/features/record/ui/ride_ticket.dart:29 |
| 82 | L169 | 저장 직후 평점 요청 안 함 | 구현됨 | 평점 요청 코드 없음 |
| 83 | L170 | 역 단위 저장 안 함 | 구현됨 | S/db/tables.dart:50 구간 단위 |
| 84 | L170 | 일괄 삭제 없음을 따라 하지 않음 | 구현됨 | 여러 개 선택 삭제 A/features/record/ui/record_list_screen.dart:40-46,67-87. 남은 여정 전체는 L1090 행 |
| 85 | L171 | 지선을 한 줄로 합치지 않음 | 구현됨 | RS:104 계통 칩으로 분리 |
| 86 | L172 | 역 수 기준 진행률·선형 km 안 씀 | 구현됨 | C/score/scorer.dart:100 영업km 기준 |

### §2.1 모듈 구성 (L181~214)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 87 | L181 | nodes | 구현됨 | data/source/nodes |
| 88 | L182 | groups | 구현됨 | data/source/groups |
| 89 | L183 | redirects | 미구현 | data/source/redirects 없음 (L183 "아직 없음. 시드 동결 뒤 필요"). pack id_redirect 0행. T/check_ids.py:59-65는 은퇴 목록의 redirect 순환과 대상만 봄 |
| 90 | L184 | operators | 구현됨 | data/source/operators |
| 91 | L185 | lines | 구현됨 | data/source/lines |
| 92 | L186 | routes | 구현됨 | data/source/routes |
| 93 | L187 | services | 구현됨 | data/source/services (17) |
| 94 | L188 | edges (seed_line, route_only) | 구현됨 | data/source/edges |
| 95 | L189 | events | 구현됨 | data/source/events |
| 96 | L190 | hubs | 구현됨 | data/source/hubs |
| 97 | L191 | junctions | 구현됨 | data/source/junctions |
| 98 | L192 | lineage | 문서 오류 | 사슬은 transfer에서 컴파일, 고정 ID는 선택(§2.9). 사슬 ID는 기록에 저장 안 함(§2.10) |
| 99 | L193 | archive | 구현됨 | data/source/archive |
| 100 | L211 | km | 구현됨 | data/source/km |
| 101 | L212 | positions | 구현됨 | data/source/positions |
| 102 | L213 | geometry | 구현됨 | data/source/geometry |
| 103 | L214 | names | 구현됨 | data/source/names |
| 104 | L199 | staging | 미구현 | data/source/staging 없음 |
| 105 | L200 | checks (intentional_gap 등) | 미구현 | data/source/checks 없음 |

### §2.1 변경 번짐 표 (L208~221)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 106 | L208 | 뼈대 추가·분할은 §2.10 도구로 | 미구현 | 도구 없음 (L721~724) |
| 107 | L209 | routes → route_edge·route_stop·route_link | 구현됨 | CP:208~284, CP:452~525 |
| 108 | L210 | events → edge_attr·route_*·denominator | 구현됨 | CP:132~199, CP:322~359 |
| 109 | L211 | km → denominator·closed_section | 구현됨 | CP:322~359, CP:629~634 |
| 110 | L212 | 환승 후보 거리 300m | 문서 오류 | L792은 350m, 구현도 350m CP:456 `hav_km(a,b)<.35` |
| 111 | L213 | geometry → 품질·출처·커버리지·도도부현 경계 km | 구현됨 | 품질·출처·커버리지 CP:596-604,656. 경계 km는 선형을 data/base/pref.geojson 경계로 잘라 나눔 CP:737-780 (커밋 81dcc93) |
| 112 | L214 | 파이프라인의 조인 키로 이름을 쓰지 않음 | 부분 | 이름 키가 남음: CP:451-456 HUBNOT·HUBX(일본어 이름 쌍), T/gen_wiki.py:202-224 NOCONT(노선 일본어 이름 쌍), T/gen_source.py:102,172 RENAME. 표는 data/overrides/hand_tables.json으로 옮겼으나 키는 여전히 이름 |
| 113 | L215 | hubs·junctions → route_link | 구현됨 | CP:452~525 |
| 114 | L216 | lineage → 이름 병기 | 구현됨 | pack lineage_id, C/network/display_rules.dart `_chained`, SL:549 |
| 115 | L217 | archive는 표시만, 기록·통계·지도 무영향 | 구현됨 | S/pack/pack_reader.dart:209 표시용만 읽음. network_reader는 안 읽음 |
| 116 | L219 | 선로·정차·귀속·이름의 시간은 events/에만 | 문서 오류 | 이름 기간은 names, 역 기간은 overrides가 실제 구조 (§2.12 사람이 고친 값). §2.1 문구 낡음 (M12) |
| 117 | L220 | 변경 유형별 도구와 체크리스트 | 미구현 | T/에 해당 도구 없음 |
| 118 | L221 | 선형이 없어도 기록·통계 계산 | 구현됨 | 기록 가능 173노선, 계산은 km만 사용 |

### §2.2 이벤트 종류 (L224~236)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 119 | L224 | edge는 역대 모든 노드로 가장 잘게 나눔 | 구현됨 | data/source/events open_stop 3,269건, 역 변화가 edge 수를 안 바꿈 |
| 120 | L228 | open: operator·line 필수, 멤버십 생성 | 구현됨 | CP:134~148 |
| 121 | L228 | open의 class 선택 필드 | 구현됨 | CP:147, 사용 73건 |
| 122 | L228 | close: line 필수, last_service·legal_abolition 별도 | 구현됨 | CP:149~154, CP:131 |
| 123 | L229 | suspend / resume | 구현됨 | CP:182~189, 64·36건 |
| 124 | L230 | open_stop / close_stop | 구현됨 | CP:194, 3,269·184건 |
| 125 | L231 | transfer from+to | 구현됨 | CP:155~174, 307건 |
| 126 | L231 | transfer `to`만 (사업자 추가) | 문서 오류 | redesign 4.1 `안 쓰는 이벤트 규범: 문서를 실제 방식으로 고침`. data/source/events 실측 7종뿐 (rename·move·km_change·relocate·set_class 0건). DESIGN §2.2 미갱신 (M12) |
| 127 | L231 | transfer `from`만 (사업자 철수) | 문서 오류 | redesign 4.1 `안 쓰는 이벤트 규범: 문서를 실제 방식으로 고침`. data/source/events 실측 7종뿐 (rename·move·km_change·relocate·set_class 0건). DESIGN §2.2 미갱신 (M12) |
| 128 | L232 | relocate | 문서 오류 | redesign 4.1 `안 쓰는 이벤트 규범: 문서를 실제 방식으로 고침`. data/source/events 실측 7종뿐 (rename·move·km_change·relocate·set_class 0건). DESIGN §2.2 미갱신 (M12) |
| 129 | L233 | rename 이벤트 | 문서 오류 | redesign 4.1 `안 쓰는 이벤트 규범: 문서를 실제 방식으로 고침`. data/source/events 실측 7종뿐 (rename·move·km_change·relocate·set_class 0건). DESIGN §2.2 미갱신 (M12) |
| 130 | L234 | move 이벤트 (좌표에 날짜) | 문서 오류 | redesign 4.1 `안 쓰는 이벤트 규범: 문서를 실제 방식으로 고침`. data/source/events 실측 7종뿐 (rename·move·km_change·relocate·set_class 0건). DESIGN §2.2 미갱신 (M12) |
| 131 | L235 | km_change 이벤트 | 문서 오류 | redesign 4.1 `안 쓰는 이벤트 규범: 문서를 실제 방식으로 고침`. data/source/events 실측 7종뿐 (rename·move·km_change·relocate·set_class 0건). DESIGN §2.2 미갱신 (M12) |
| 132 | L236 | set_class | 구현됨 | CP:190. 데이터 0건 (class는 open의 73건으로 들어감) |
| 133 | L238 | seed_line 불변 | 구현됨 | CP:77, data/source/edges |
| 134 | L242 | a..b: open은 seed_line | 구현됨 | CP:135 |
| 135 | L243 | a..b: close·set_class는 전날 멤버십 | 구현됨 | CP:150, CP:191 |
| 136 | L244 | a..b: transfer는 from.line 멤버십 | 구현됨 | CP:157~158 |
| 137 | L245 | a..b: to만이면 within | 구현됨 | CP:157 |
| 138 | L247 | 같은 날 이벤트는 모두 전날 기준 | 부분 | CP:60 날짜와 종류 순으로 정렬한 뒤 차례로 그때의 active를 봄. 전날 상태를 고정하지 않음 |

### §2.2 규범 규칙 (L252~264)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 139 | L252 | 기간은 [from,to), valid_to는 마지막 운행 다음 날, JST | 구현됨 | pack: 札沼線 valid_to 2020-04-18. C/date/date_rules.dart:39 |
| 140 | L253 | 마지막 운행일과 법적 폐지일 분리 | 구현됨 | pack: 札沼線 last_service 04-17, legal 05-07 |
| 141 | L254 | BRT는 운행 첫날 close | 구현됨 | pack: 気仙沼線 2012-08-20, 日田彦山線 2023-08-28 |
| 142 | L255 | 정기 여객 없는 구간 close | 구현됨 | pack: 海峡線 no_regular_service 2016-03-26 |
| 143 | L256 | 재해 불통은 폐지 신고까지 suspend | 구현됨 | pack: 岩泉線 suspended 2010-08-01~2014-04-01, last_service 2010-07-31 |
| 144 | L257 | 이설은 relocate (吾妻, 常磐, 仙石, 菊池, 石巻) | 문서 오류 | 菊池線 연장은 §17 `근사 처리 3건`으로 정리됨. §2.2 예시 낡음 |
| 145 | L258 | 역 위치 이동: km 같으면 move, 다르면 노드 둘 + moved | 문서 오류 | redesign 4.1 `안 쓰는 이벤트 규범: 문서를 실제 방식으로 고침`. data/source/events 실측 7종뿐 (rename·move·km_change·relocate·set_class 0건). DESIGN §2.2 미갱신 (M12) |
| 146 | L260 | 사업자만 바뀜은 같은 line에 transfer | 부분 | 국철→JR 구현. 사철 합병 미표현: 松戸線은 처음부터 o_keisei_electric_railway 한 사업자 |
| 147 | L261 | 노선이 바뀌면 새 line + transfer | 부분 | 3섹 전환 구현. 리아스선 통합은 40100 단일 노선으로 미표현 |
| 148 | L262 | 이름만 바뀌면 rename | 문서 오류 | redesign 4.1 `안 쓰는 이벤트 규범: 문서를 실제 방식으로 고침`. data/source/events 실측 7종뿐 (rename·move·km_change·relocate·set_class 0건). DESIGN §2.2 미갱신 (M12) |
| 149 | L263 | 운휴를 거친 이관 (도야마항선) | 구현됨 | pack: 2006-03-01~04-29 suspended 후 open, lineage 유지 |
| 150 | L264 | 역↔신호장: close_stop, node.kind는 최근 종류 | 문서 오류 | node.kind는 화면에 안 나옴. 공개는 node_public 기준이라 楓·東追分 동작 동일 |

### §2.3 예시 (L267~291)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 151 | L267 | 삿쇼선 두 번의 폐지, 로이즈타운 정차 | 구현됨 | pack: 1972-06-19, 2020-05-07, n_royce_town 2022-03-12 |
| 152 | L280 | 신에츠 → 시나노철도 1997-10-01 | 구현됨 | pack: lineage lg336 유지, carryover 새 값 |
| 153 | L283 | 나리타 스카이 같은 선로에 사업자 추가 | 문서 오류 | 동시 멤버십 0개 pack 실측. ARCH §7.2 `DESIGN §2.7·§14 문구 정리`가 남은 일 (M13) |
| 154 | L288 | 아가츠마선 이설 2014-10-01 | 구현됨 | pack: 옛 edge relocated, 새 edge 이어짐 |

### §2.4 신호장·화물역 (L296~303)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 155 | L296 | 신호장·분기점·화물역은 내부 전용 | 구현됨 | pack: 숨은 노드 18 (signal 4, junction 11, freight 3) |
| 156 | L298 | 빌드 시 숨은 노드 이름 제거, 색인 제외 | 구현됨 | CP:674, CP:698. pack 숨은 노드 이름 0행 |
| 157 | L299 | 앱은 node_public만 사용 | 부분 | 망과 역 수는 node_public S/pack/network_reader.dart:45, S/pack/pack_reader.dart:54. 원본 node를 읽는 곳 둘: S/pack/pack_reader.dart:125 export_name(L303의 예외), :212 묶음의 도도부현. CI 검사는 #160 |
| 158 | L299 | 역이었던 신호장은 폐역으로만 표시 | 구현됨 | pack: 楓 2004-03-13, 東追分 2016-03-26 정차 종료 |
| 159 | L300 | 정차는 (계통, 노드) 단위 | 구현됨 | pack: 船町·下地는 r_iida_line만 |
| 160 | L301 | UI가 원본 node를 읽으면 CI 실패 | 미구현 | T/check_boundaries.py:23-47은 의존 방향만 봄. node 규칙 없음 |
| 161 | L302 | 노선도·선택기·지도·통계에 안 나옴 | 구현됨 | C/network/selector.dart:110, T/gen_tiles.py `node_public` |
| 162 | L303 | 호환판 CSV 경계에 export_name 사용 | 구현됨 | S/pack/pack_reader.dart:120-125가 export_name을 일본어 이름 표에 넣음, 숨은 노드 18행은 ja 이름이 없어 이 값이 쓰임 (names 조회), C/importing/csv_export.dart:117 |

### §2.5 사업자 분류 (L306~307)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 163 | L306 | operator.category 8종 유지 | 구현됨 | pack operator |
| 164 | L307 | 지도는 분류와 무관하게 같은 색 | 구현됨 | MS 층 색은 토큰뿐 |
| 165 | L307 | 통계: 전체·사업자별·노선별·도도부현별 | 구현됨 | ST:221~224 |

### §2.6 빌드와 검증 (L311~336)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 166 | L311 | events + 뼈대 → master.sqlite | 구현됨 | CP |
| 167 | L312 | km → 거리 테이블 | 구현됨 | CP:603 |
| 168 | L313 | positions/geometry → rail.pmtiles | 구현됨 | T/gen_tiles.py |
| 169 | L315 | names → names.sqlite (공개 노드만) | 구현됨 | CP:672~705 |
| 170 | L317 | CI 검사는 네트워크 없이 | 구현됨 | T/all.sh 생성·컴파일·검증에 네트워크 없음 |
| 171 | L317 | 결과는 coverage.json과 빌드 리포트 | 문서 오류 | 결과물은 build/report.json. coverage는 master 표. §2.6 파일 이름 낡음 |
| 172 | L317 | 문서 수치는 리포트에서 | 구현됨 | T/status.py → docs/db-status.md |
| 173 | L326 | 위상 검사 + intentional_gap | 부분 | T/audit_db.py:243 날짜별 조각 수 계산뿐이고 all.sh·CI 밖 (ARCHITECTURE §4.4 보고용). intentional_gap 예외 파일 없음 (data/source/checks 없음, L200) |
| 174 | L327 | 날짜 정합성, 범위는 양 끝 검사 | 부분 | T/audit_db.py:48, all.sh·CI 밖. 범위 양 끝 시점 검사 없음 |
| 175 | L328 | 수록 등급 조건 못 채우면 실패, 현행 노선은 등급을 내리지 않고 실패 | 부분 | CP:796-800 등급 계산뿐, 실패 없음 |
| 176 | L329 | 귀속 검사 | 구현됨 | CP:548 edge_no_attr, CP:554 overlap_attr가 오류. CP:849가 오류가 있으면 멈추고 T/all.sh:26이 CI에서 돎 (.github/workflows/data.yml:34). 지금 오류 0건 |
| 177 | L330 | 계통 끝 노드 검사 | 부분 | CP:542 extend_to 대상이 공개 노드인지는 오류로 멈춤(CP:849). 끝 노드가 정차역이 아닐 때 extend_to·service를 요구하는 검사는 T/audit_db.py:173뿐, CI 밖 |
| 178 | L331 | 거리: 사업자 합계를 공표 값과 대조 | 부분 | JR 도카이 1,970.8 일치 (docs/db-status.md). 사업자 합계 자동 대조 없음. 노선 km 차이는 경고만 CP:234 |
| 179 | L332 | 교차 검증: 역 목록·순서·km·폐지일을 모든 출처끼리 대조, 현행 노선 불일치는 CI 실패 | 부분 | 위키 km 대조 T/verify.py:46-67과 station_database 이름 대조는 결과만 남기고 멈추지 않음. 원천 대조 T/audit_ext.py:29는 로컬 전용. N05 폐선은 손 대조 표 data/overrides/n05_fix.json |
| 180 | L333 | 이름 검사 | 부분 | 역·노선 한글 없음과 한글 속 일본어 글자 CP:562-568이 오류로 멈춤(CP:849). 사업자 한글·source 검사, 나무위키 제목 공유 검사는 없음 (T/audit_db.py:312는 CI 밖) |
| 181 | L334 | ID: 영어 이름 규칙, ids.lock 대조, 재사용·삭제·지문·순환 실패 | 부분 | 이름 규칙 T/verify.py:69-71(멈춤). 잠금 검사 T/check_ids.py:50-70이 T/all.sh:36에서 돎. data/ids.lock이 아직 없어(시드 동결 때 만듦, L334) 지금은 비교 대상이 없음 |
| 182 | L335 | 라이선스: 출처별 파일에 다른 출처가 섞이면 실패, 값마다 출처 태그 | 부분 | OSM 값이 master에 섞이면 실패 T/check_geometry.py:76-78, 꺼진 출처 값이 남으면 실패 T/verify.py:72-87. 출처별 geometry 파일의 혼입과 출처 태그 누락은 검사하지 않음 |
| 183 | L336 | 회귀: 옛 판 고정 기록 재해석 비교 | 미구현 | tools/repro/는 빈 폴더. 판 사이 재해석 비교 도구 없음 (ARCHITECTURE §4.4 "미완") |

### §2.7 세 개념과 계통 파일 (L343~366)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 184 | L343 | 노선이 통계·완주 단위 | 구현됨 | C/score/scorer.dart:140 |
| 185 | L344 | 계통은 고유 km 축 | 구현됨 | pack route_stop |
| 186 | L345 | edge는 노선당 1개, 공동 구간은 멤버십 여럿 | 문서 오류 | 동시 멤버십 0개 pack 실측. ARCH §7.2 `DESIGN §2.7·§14 문구 정리`가 남은 일 (M13) |
| 187 | L344 | 千歳線 본선·공항지선 | 구현됨 | pack: r_chitose_line, r_chitose_line_minami_chitose_new_chitose_airport |
| 188 | L344 | 函館本線 본선·砂原支線 | 구현됨 | pack: r_hakodate_main_line, r_hakodate_main_line_onuma_mori |
| 189 | L362 | 東海道 美濃赤坂 계통 자기 edge | 구현됨 | pack: r_tokaido_main_line_ogaki_mino_akasaka, 5.0km |
| 190 | L357 | 犬山線 기점 숨은 노드 + extend_to | 구현됨 | pack: n_biwajima_junction, extend_to n_higashi_biwajima |
| 191 | L361 | 각 시점의 노선 부분 그래프로 경로, route_edge에 기간 | 대상 아님 | DESIGN §14.1 `v1에서 뺀 것` route_edge 기간 |
| 192 | L362 | 공식 km가 따로 있는 계통은 route_only | 구현됨 | pack: route_only edge 333개 |
| 193 | L362 | 본선 기록은 route_only 계통을 채우지 않음 | 구현됨 | pack: 별도 edge |
| 194 | L363 | 노선 집계가 계통으로 겹침·빠짐 없이 나뉘는지 CI | 부분 | T/audit_db.py:173, all.sh·CI 밖 |
| 195 | L364 | 계통 파일은 기점·종점만, 폐지는 빌드가 처리 | 구현됨 | data/source/routes, CP:208~223 |
| 196 | L365 | extend_to 선택기 표시, km 미표시, 저장 시 계통 분할 | 구현됨 | pack is_extension 24행, RR:124 `expandAny`, RR:475 |
| 197 | L366 | closed 계통, 같은 역 두 번 | 구현됨 | pack: closed 5, 都庁前 seq 0·28 |
| 198 | L366 | closed 계통은 via 필수 | 부분 | pack: closed 계통 5개(r_oedo_line 등) 전부 via_nodes `[]` |
| 199 | L366 | 순환 입력 | 구현됨 | RC:579 `asksLap`, RC:582 `pickLap`, SL:82~105, SB:180~189 |
| 200 | L366 | 시대에 따라 닫히는 계통 closed_from | 문서 오류 | closed_from 사례 0행. 시대 차이는 service 기간으로 처리(s_meijo_loop 2004~). 지금 쓸 데이터 없음 |

### §2.7 지선 유형별 처리 (L371~375)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 201 | L371 | 역에서 갈라지는 지선 | 구현됨 | pack: 南千歳가 두 계통에 나타남 |
| 202 | L372 | 역이 아닌 분기점은 숨은 노드 + extend_to | 구현됨 | pack: junction 11, extend_to 17계통 |
| 203 | L373 | 병행 경로는 계통 ID를 저장 | 구현됨 | S/db/tables.dart:57, RC:617 |
| 204 | L374 | 중간 폐지 노선은 계통 하나, 폐지 구간 3단계 | 구현됨 | pack r_nemuro_main_line 하나, SL:180 tier3, SL:20 `tail` |
| 205 | L375 | 겹치는 구간은 그 노선 계통에 안 넣음 | 구현됨 | pack: 代々木–新宿 e_000654는 山手線만 |

### §2.7 중복 구간 (L379~400)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 206 | L379 | 기록은 (기록한 노선, edge)에만 붙음 | 구현됨 | C/network/network.dart:266 `unitOf` |
| 207 | L383 | 지도는 물리 edge 기준으로 파랑 | 문서 오류 | 동시 멤버십 0개 pack 실측. ARCH §7.2 `DESIGN §2.7·§14 문구 정리`가 남은 일 (M13) |
| 208 | L384 | 통계는 기록한 노선에만 크레딧 | 구현됨 | RI:65 |
| 209 | L387 | JR은 한 구간 한 노선 | 구현됨 | pack: 東京–神田 東北本線, 代々木–新宿 山手線 |
| 210 | L388 | JR 예외 4곳은 두 노선 집계 | 구현됨 | pack: 4곳 모두 양쪽 분모. 별도 edge로 표현 |
| 211 | L389 | 사철 공동 구간은 사업자별 집계 | 구현됨 | pack: 京成 成田空港線·北総線 각각, 사업자별 노선 |
| 212 | L390 | 같은 사업자 중복은 공식 소속 노선 하나 | 구현됨 | pack: 梅田–十三은 宝塚本線, 京都本線 기점 十三 |
| 213 | L390 | `梅田→淡路` 입력을 운전 계통으로 | 미구현 | 운전 계통 입력은 됨 SS:15-157. `梅田→淡路`에 맞는 service가 없음 (master.service 17행) |
| 214 | L395 | 中央線 쾌속 東京→新宿 분해 크레딧 | 구현됨 | s_chuo_rapid SP:59-96, 요약 SP:186-196, 저장 뒤 legs로 크레딧 RI:62-80. 시험 apps/noriori/test/line_detail_test.dart:305 |
| 215 | L396 | 山手線 代々木→新宿 크레딧 | 구현됨 | pack e_000654, 분모 l_yamanote_line |
| 216 | L397 | 中央本線 金山→名古屋는 中央本線만 | 구현됨 | pack: e_000890은 中央本線 |
| 217 | L398 | 京成 스카이라이너는 京成만 | 구현됨 | pack: 별도 edge·노선 |
| 218 | L400 | 입력 화면에 분해 결과 표시 | 구현됨 | SS:130-140 운전 계통 입력 화면 하단 요약. 일반 역 선택기는 L148 행 |

### §2.7 운전 계통 (L403~420)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 219 | L403 | 통칭으로 입력하고 저장 시 공식 노선으로 쪼갬 | 구현됨 | SP:59-96, SC:208-224 |
| 220 | L407 | service closed 필드 | 구현됨 | pack service.closed (3개 1) |
| 221 | L408 | parts는 공식 계통 구간의 이음 | 구현됨 | pack service_part: s_chuo_rapid 4구간 |
| 222 | L413 | stops 필드 | 대상 아님 | DESIGN §14.1 `v1에서 뺀 것` service_stop. 생략이면 모든 정차역 (§2.7) |
| 223 | L415 | 운전 계통은 통계 단위 아님 | 구현됨 | ride_edge가 service를 안 봄 |
| 224 | L415 | 시대별 날짜 판 | 대상 아님 | redesign 4.1 `옛 판·노면전차 계통: v1.0 뒤` |
| 225 | L415 | 날짜 모름이고 판이 여럿이면 고르게 함 | 대상 아님 | redesign 4.1 `옛 판·노면전차 계통: v1.0 뒤` |
| 226 | L416 | parts는 노선이 아니라 계통을 가리킴 | 구현됨 | pack service_part.route_id |
| 227 | L417 | 쇼난신주쿠는 service 2개 | 구현됨 | pack: s_shonan_shinjuku_ty·ys |
| 228 | L418 | 야마노테 일주는 closed service | 구현됨 | pack: s_yamanote_loop |
| 229 | L419 | 검색에서 공식 노선과 운전 계통을 함께 표시 | 구현됨 | 색인 34행 CP:698, A/features/record/controller/line_search_controller.dart:36-39,51-57, A/features/record/ui/line_search_screen.dart:20-26,55 |
| 230 | L419 | 기록에 service_id를 남겨 "○○로 탑승" 표시 | 구현됨 | `viaService`, `record_queries.dart` 목록 |
| 231 | L420 | 노선 계통에는 집계 edge만 | 구현됨 | pack: 中央本線 3계통 |

### §2.7 화면 (L423~425)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 232 | L423 | 노선 상세: 계통별 세로 노선도, 연결 표시 | 구현됨 | A/app/router.dart:46-49, LD:217-242 계통별 세로 노선도, 계통 칩 LD:309-319, 연결 단추 LD:431-437, DG:89-200 |
| 233 | L424 | 선택기 계통 칩, 하나면 칩 없음 | 구현됨 | RS:104 |
| 234 | L425 | 통계: 노선 합산 + 노선 상세의 계통별 진행률 | 구현됨 | 노선 합산 ST:231-237, 계통별 LD:320 |

### §2.8 A·B (L431~444)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 235 | L431 | events는 현실 변화만 | 구현됨 | data/source/events (rename·정정 사건 없음) |
| 236 | L432 | ID를 합치거나 없앨 때 redirects | 미구현 | L183와 같음 (#89) |
| 237 | L437 | node가 기록의 출발·도착 | 구현됨 | S/db/tables.dart:58~59 |
| 238 | L438 | group: 방문 역 수, 지도 역 점, 역 방문 기록 | 구현됨 | 지도 점 T/gen_tiles.py:36-45, 방문 역 수 ST:127-128, C/network/station_state.dart:25-41, 방문은 묶음으로 판정 LD:91-96 |
| 239 | L439 | hub는 기록 화면 환승 표시 | 구현됨 | CP:458, SL:251 |
| 240 | L441 | hub가 group을 대체하지 않음 | 구현됨 | pack: 姫路 g_himeji, 山陽姫路 g_sanyo_himeji, 같은 hub_himeji |
| 241 | L442 | 공동 사용역은 노드 하나에 노선별 이름 | 구현됨 | pack name.line_id 218행, S/pack/pack_reader.dart:95 |
| 242 | L443 | 사업자가 다르면 별도 node + 같은 group + hub | 구현됨 | pack: n_fukui·n_fukui_echizen, hub_fukui |
| 243 | L444 | 방문 화면에서 group 안 node 지정 | 부분 | 노선 상세는 그 노선의 node로 남김 LD:106-111, 지도 시트는 타일의 대표 node MP:35-40. 묶음 안에서 고르는 화면은 없음 |

### §2.8 C (L447~457)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 244 | L447 | km는 구간별 값 하나, 바뀌면 km_change, 누적은 빌드 | 문서 오류 | 해당 사례 0건 (km_change, 등급 섞인 단위, 같은 edge 재개). 규칙은 있으나 팩에 대상 없음 |
| 245 | L448 | 자료의 누적 km를 구간 길이로 저장 | 구현됨 | T/gen_source.py |
| 246 | L449 | 경계 노드(사업자·노선·폐지 구간 경계) km 필수 CI | 구현됨 | 모든 edge에 km가 있어야 함 CP:51 edge_no_km, 오류면 멈춤 CP:849, CI에서 돎. 도도부현 경계는 노드가 아니라 edge_pref (#290) |
| 247 | L453 | 현행 분모 km는 지금 | 구현됨 | edge_km |
| 248 | L454 | 역대 분모 km는 종료 직전 | 구현됨 | edge_km (단일 값) |
| 249 | L455 | 특정 연도 km는 그해 마지막 영업일 | 대상 아님 | DESIGN §14.1 `v1에서 뺀 것` edge_km 기간. km_change 0건 |
| 250 | L456 | 탑승 거리 km는 탑승일 | 대상 아님 | DESIGN §14.1 `v1에서 뺀 것` edge_km 기간. km_change 0건 |
| 251 | L457 | 입력 화면 km는 고른 탑승일 | 대상 아님 | DESIGN §14.1 `v1에서 뺀 것` edge_km 기간. km_change 0건 |

### §2.8 D (L460~464)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 252 | L460 | 펼침은 탑승일의 선로망 | 구현됨 | RR:219~233 `edgeUsable(… day)` |
| 253 | L461 | route_id 항상 저장 | 구현됨 | RC:617 |
| 254 | L462 | 날짜 몰라 경로가 둘이면 저장 시 물음, 날짜로 저장 | 구현됨 | SB:81, RC:669 asOf |
| 255 | L462 | 답 형식 옛 선로 / 새 선로 / 모름 | 구현됨 | `relocationLabel`이 옛 선로/새 선로, 모름은 구간마다 |
| 256 | L463 | 모름이면 resolve_unknown, partial, 공통 구간만 크레딧 | 구현됨 | RR:241~255, RC 저장 |
| 257 | L464 | 펼친 결과는 캐시, 데이터 바뀌면 재계산 | 구현됨 | S/records/cache_rebuild.dart |

### §2.8 E (L467~482)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 258 | L467 | transfer는 선로를 닫지 않음, lineage 유지·비어 있지 않음 | 구현됨 | CP:155~174, audit lineage 비어 있음 0건 |
| 259 | L468 | 승계 켬: (lineage, edge), 지금 노선 이름으로 표시 | 구현됨 | 승계 끔 켜기, 유효 날짜 양쪽 교집합, 변경 내역 트랜잭션·날짜·빌드, 판 번호 수 비교, 역대 표 지금 노선 이름 (공개 전 검토) |
| 260 | L469 | 승계 끔: (carryover_group, edge) | 구현됨 | 설정 스위치 A/features/settings/ui/settings_screen.dart:97-101, carryoverProvider A/app/session_providers.dart:233, 모든 집계가 이 값을 씀. 팩 분모 off 33,161.8km를 시나리오로 확인. 단 AR:L245의 켜기 결함 있음 |
| 261 | L470 | 두 방식 분모 미리 계산, 설정 즉시 반영 | 구현됨 | 설정 스위치 A/features/settings/ui/settings_screen.dart:97-101, carryoverProvider A/app/session_providers.dart:233, 모든 집계가 이 값을 씀. 팩 분모 off 33,161.8km를 시나리오로 확인. 단 AR:L245의 켜기 결함 있음 |
| 262 | L471 | 멤버십 여럿이면 기록한 노선 lineage만 | 구현됨 | C/network/network.dart:190 |
| 263 | L475 | open: 새 사슬, 새 값 | 구현됨 | CP:117~120 |
| 264 | L476 | 국철·JR → 타사: lineage 유지, carryover 새 값 | 구현됨 | CP:168 |
| 265 | L477 | 그 밖 이관: 둘 다 유지 | 구현됨 | CP:168 |
| 266 | L478 | to만: 새 사슬, 새 값 | 구현됨 | CP:170~171 |
| 267 | L479 | from만: 그 행 종료 | 구현됨 | CP:161~164 |
| 268 | L480 | open + continues | 구현됨 | CP:137~146. 데이터 0건 |
| 269 | L482 | o_japanese_national_railways 분류는 jr | 구현됨 | pack operator |

### §2.8 F·G·H (L485~493)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 270 | L485 | 같은 노선 안 계통을 넘어 경로 자동 탐색 (지선 역 → 본선 역) | 구현됨 | C/network/route_resolver.dart:515 across, A/features/record/controller/record_session_controller.dart:411,665-666. 新千歳空港→白石 2구간 40.8km 실행 확인 |
| 271 | L486 | 숨은 노드 경계 자동 분할, 화면 분해 표시 | 구현됨 | `RecordSessionState.split`, 저장 바 |
| 272 | L489 | 순환 계통 방향 저장, 한 바퀴 leg | 구현됨 | RC:622, RR:273 |
| 273 | L489 | 두 바퀴 이상은 leg를 바퀴 수만큼 | 구현됨 | 고리에도 횟수와 두 방향 |
| 274 | L492 | 운전 계통 기록은 저장 시 분해 | 구현됨 | SP:59-96이 공식 구간 legs로 나눔, SC:208-224, `service_id`는 표시용 SP:170 |
| 275 | L493 | 탑승일에 맞는 운전 계통 판 선택 | 구현됨 | `usable`, `openOn`을 화면이 씀 (service_session_controller) |

### §2.8 I (L496~502)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 276 | L496 | 기록은 ride + legs 묶음 | 구현됨 | S/records/record_store.dart `_writeRide` |
| 277 | L497 | 삭제·되살리기도 updated_at | 구현됨 | S/records/record_store.dart:23, C/records/change.dart |
| 278 | L498 | 구간 끄기는 기록을 고침 | 구현됨 | CUT:45-119, LC:71-114 |
| 279 | L499 | 데이터 변경 시 변경 내역 표시 | 구현됨 | `CacheRebuild`가 변경 내역을 남기고 앱을 열 때 보여 줌 |
| 280 | L500 | 없는 ID는 unknown_ref, 갱신 안내 | 부분 | 상태값 RR:137. 갱신 안내 없음, 목록 배지 `확인 필요`뿐 |
| 281 | L501 | CSV 행은 UUIDv5 고정 ID | 구현됨 | S/records/content_id.dart, C/importing/csv_import.dart:233 |
| 282 | L502 | 같은 (날짜, 경로, 시각) 중복 후보 표시 | 미구현 | L1632 "아직 없는 것: 중복 후보 표시" |

### §2.8 J (L505~514)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 283 | L505 | 연도 분모: 그해 하루라도 영업, 불통 포함 | 구현됨 | C/score/scorer.dart:62 |
| 284 | L505 | 이설 해에 분모가 커지는 이유를 화면에 설명 | 미구현 | A/features/stats에 없음 |
| 285 | L506 | 연도 분자: 유효 범위 끝이 Y년 말 이전 | 구현됨 | C/score/scorer.dart:93 |
| 286 | L507 | 유효 날짜 범위 계산, 날짜 없으면 등록일 상한 | 구현됨 | 승계 끔 켜기, 유효 날짜 양쪽 교집합, 변경 내역 트랜잭션·날짜·빌드, 판 번호 수 비교, 역대 표 지금 노선 이름 (공개 전 검토) |
| 287 | L512 | 교집합이 비면 날짜 모름, 입력값 보존 | 구현됨 | 승계 끔 켜기, 유효 날짜 양쪽 교집합, 변경 내역 트랜잭션·날짜·빌드, 판 번호 수 비교, 역대 표 지금 노선 이름 (공개 전 검토) |
| 288 | L513 | 저장·날짜 수정 때 line·route를 멤버십에 맞춤 | 구현됨 | 저장 RR:454 `_align`, 날짜 수정 A/features/record/ui/record_edit_screen.dart:103-116도 같은 해석 RI:43 |
| 289 | L514 | 현행 분모는 실행 시 오늘로 선택, 100% 안 넘음 | 구현됨 | C/score/scorer.dart:62, A/app/session_providers.dart `todayProvider` |

### §2.8 K·L (L517~522)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 290 | L517 | 도도부현 경계는 노드 없이 edge_pref에 도도부현별 km (v0.48) | 구현됨 | CP:737-780 edge_pref. 경계 구간 249개, 경계 노드 0 |
| 291 | L518 | 경계 km를 선형으로 구해 값으로 저장 | 구현됨 | CP:737-780: N02·N05 선형을 도도부현 경계로 잘라 길이 비율로 나눔. 249구간 중 226구간이 선형 (커밋 81dcc93) |
| 292 | L518 | 선형으로 못 구한 구간은 반씩 나누고 approx 표시 | 부분 | 반씩 나눔과 approx 열 있음 (23구간, pack approx 46행) CP:777-778. 앱이 approx를 읽지 않아 표시 없음 S/pack/network_reader.dart:48 |
| 293 | L521 | 전체 지도는 어느 노선으로든 탔으면 파랑 | 구현됨 | MH:27, S/records/record_queries.dart `watchRiddenEdges` |
| 294 | L522 | 미승 구간만 보기: (노선, 구간) 크레딧 기준. v0.41에서 `승차만` 보기로 바뀜 | 구현됨 | DESIGN v0.41 L526 `승차만` 보기가 이 기능을 대체. MH:141-146,161-167. 탄 선과 지나간 역만 남김 |
| 295 | L522 | 노선 단독 보기: 크레딧 기준 | 구현됨 | `soloLine`의 크레딧 기준 |

### §2.8 M (L526~529)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 296 | L526 | 승하차역 = alighted 끝 + 여기서 갈아탐 | 구현됨 | 계산 RI:85-88, 입력 A/features/record/ui/record_edit_screen.dart:181-210 |
| 297 | L527 | 손 입력 끝은 참, CSV는 거짓, 나중에 일괄로 참 | 부분 | 기본값 C/records/record.dart:110, CSV C/importing/csv_import.dart:313. 기록마다 고치기 A/features/record/ui/record_edit_screen.dart:169-180. 일괄 변경 없음 (L1632) |
| 298 | L528 | 통과 판정은 지난 경로, 경로 밖 갈아탄 역 무시 | 구현됨 | RI:73~85 |
| 299 | L529 | 방문 역 수 = 역 방문 ∪ 승하차역 | 구현됨 | ST:127-128,178-182, C/network/station_state.dart:25-41. 숫자 카드 `지나간 역`은 별도 지표 (§8.0) |

### §2.8 N (L534~542)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 300 | L534 | resolve_status ok | 구현됨 | C/records/derived.dart:6 |
| 301 | L535 | partial | 구현됨 | C/records/derived.dart, 목록 배지 record_list_screen.dart:76 |
| 302 | L536 | needs_input: 사용자 답이 필요 | 구현됨 | `record_edit_screen.dart` `_questions`가 방향·이설·모름을 구간마다 받음 |
| 303 | L537 | unknown_ref | 구현됨 | RR:137, RR:175 |
| 304 | L538 | invalid | 구현됨 | RR:183, RR:197 |
| 305 | L539 | error, 다른 기록 계산은 계속 | 구현됨 | C/records/derived.dart `interpretRideIsolated` |
| 306 | L541 | ok·partial 아닌 기록은 완주 제외, 원본 유지 | 구현됨 | RI:74 edge 없음 |
| 307 | L541 | `확인 필요 n건 · m km` 표시, partial 나머지 포함 | 구현됨 | `reviewProvider`, 통계 완주율 아래 한 줄 |
| 308 | L542 | 가져온 행 원문을 import_raw에 보존 | 구현됨 | C/importing/csv_import.dart:316 |

### §2.8 O (L547~557)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 309 | L547 | normal | 구현됨 | pack edge_attr |
| 310 | L548 | outside | 구현됨 | pack 343행 |
| 311 | L549 | extra | 구현됨 | pack 43행 |
| 312 | L551 | 분자 = 분모 ∩ 탄 단위, 분모 밖 km 미표시 | 구현됨 | C/score/scorer.dart:100, C/score/ride_preview.dart:48 |
| 313 | L552 | 등급은 기간별 행, rule_class 기본값, outside는 빌드 계산 | 구현됨 | CP:119, T/gen_source.py:928 |
| 314 | L553 | 한 단위에 등급이 섞이면 기준별로 다르게 | 문서 오류 | 해당 사례 0건 (km_change, 등급 섞인 단위, 같은 edge 재개). 규칙은 있으나 팩에 대상 없음 |
| 315 | L554 | 전 구간 분모 밖 노선은 전체 통계 제외 | 구현됨 | C/score/scorer.dart:62 |
| 316 | L554 | 그 노선의 상세 화면은 노선 자체 km로 진행률 | 구현됨 | LD:278-292 분모 밖이면 selfScore, DG:185-199. 역 선택기 머리글 km 0.0과 `이미 탄 구간입니다` 오표시는 남음 RS:104-105, SB:153 |
| 317 | L555 | extra는 승차 km·승차율 제외 | 구현됨 | C/score/scorer.dart:63 |
| 318 | L555 | extra도 누적 탑승 거리에 포함 | 구현됨 | `watchTotalKm10` |
| 319 | L557 | 사철 목록 완성 시 normal로 옮기고 안내 | 대상 아님 | L557 "목록이 완성되면", L977 |

### §2.9 환승·분기·승계 (L589~647)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 320 | L590 | hub 파일 구조 | 구현됨 | data/source/hubs (799) |
| 321 | L596 | junction 파일 구조, side, source | 구현됨 | data/source/junctions (1,234) |
| 322 | L609 | 끝에서 이어지는 continue | 구현됨 | pack: 東横線 → 副都心線 is_continue=1 |
| 323 | L617 | (역, 상대 계통) 한 쌍에 표시 하나, 지선은 other_route | 구현됨 | CP:462~510 |
| 324 | L621 | 1순위: 끝에서 이어짐 | 구현됨 | C/network/display_rules.dart `EndLine`, SL:585 |
| 325 | L622 | 2순위: 분기, side 없으면 아래 | 구현됨 | C/network/display_rules.dart `ups·downs`, SL:479 |
| 326 | L623 | 3순위: 환승 캡슐 | 구현됨 | A/features/record/ui/session_painters.dart `StopPainter`, SL:182 |
| 327 | L625 | 양 끝이 닿는 노선은 역마다 따로 | 구현됨 | CP:452~510 |
| 328 | L626 | side의 뜻 | 구현됨 | pack: side up 178, down 215 |
| 329 | L628 | 위아래는 계통 순서, 위키 방향 반대면 뒤집음 | 구현됨 | T/gen_wiki.py:154~181 |
| 330 | L629 | transfers/*.yaml 안 씀 | 구현됨 | data/source에 없음 |
| 331 | L630 | 사실만 기록, source에 revid | 구현됨 | pack junction.source `wikipedia:<revid>` |
| 332 | L631 | hub·junction이 비어도 기록·통계 동작 | 구현됨 | 기록·통계는 route_link를 안 읽음 |
| 333 | L633 | 승계 사슬은 transfer에서 컴파일 | 구현됨 | CP:155~174 |
| 334 | L633 | 폐선 뒤 재개는 open + continues | 구현됨 | CP:137. 데이터 0건 |
| 335 | L638 | 이관: 현행, 지금 이름 + 옛 이름 병기 | 구현됨 | C/network/display_rules.dart `_chained`, SL:549~556 |
| 336 | L639 | 개칭: 현행, 이름 병기 | 부분 | 노선 개칭 데이터 0행 (pack line 기간 이름 0). L233 |
| 337 | L640 | 통합: 새 line + transfer | 부분 | 리아스선 통합 미표현 (L261) |
| 338 | L641 | 부활: 중단 기간 기록 불가, `~폐지`·`재개~` 병기 | 문서 오류 | 해당 사례 0건 (km_change, 등급 섞인 단위, 같은 edge 재개). 규칙은 있으나 팩에 대상 없음 |
| 339 | L642 | 일부만 이관: 구간별 transfer | 구현됨 | pack: 신에츠 구간별 |
| 340 | L643 | 이관 후 폐지 `1989~2006` 폐선색 | 구현됨 | `_tail` `span`, 폐선색 |
| 341 | L644 | 사업자 철수 `1968~2010` | 구현됨 | `_tail` `span` |
| 342 | L645 | 완전 폐지: 옛 이름만 | 구현됨 | pack, SL:38 |
| 343 | L647 | 원자료 closed 값 안 쓰고 상태로 계산 | 구현됨 | CP:132~199 |

### §2.10 원본 소유권 (L654~662)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 344 | L654 | imports: 스냅샷과 sources.lock | 구현됨 | data/imports/osm/overpass-2026-11-02, data/sources.lock:136 이하에 등록 |
| 345 | L656 | candidates는 기계가 덮어씀 | 구현됨 | data/candidates |
| 346 | L658 | data/source는 시드 동결 뒤 사람 소유, 기계는 diff 제안만 | 부분 | 동결 전이라 T/all.sh:8-22가 data/source를 다시 씀 (L658이 동결 전 재생성을 허용). 동결과 diff 제안 도구는 아직 |
| 347 | L660 | 시드는 한 번, 이후 변경 감지만 | 부분 | 위와 같음 |
| 348 | L661 | 손 보정은 data/source의 파일에 | 문서 오류 | L783는 data/overrides, L791·L793는 스크립트 안 표. 서로 모순 |
| 349 | L662 | 빌드 고정, 의존성 잠금 | 구현됨 | data/sources.lock, WF tippecanoe 2.79.0 |

### §2.10 뼈대 데이터의 역할 (L677~683)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 350 | L678 | station_database는 시드 | 구현됨 | T/gen_source.py |
| 351 | L679 | 위키 노선도 | 구현됨 | T/gen_wiki.py |
| 352 | L680 | N02는 선형과 역 묶음 | 구현됨 | T/gen_geometry.py, T/n02_stations.py |
| 353 | L683 | 사업자 공지로 3월 개정 감지 | 미구현 | 수집·감지 도구 없음 |
| 354 | L677 | 노리츠부시는 대조 기준 | 구현됨 | T/audit_ext.py:29 |

### §2.10 ID (L685~705)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 355 | L685 | ID는 불투명, 외부 키는 별도 열 | 부분 | 앱은 파싱 안 함. CP:656,735가 edge ID 숫자를 정수 키로 읽음 (edge는 내부 ID라 번호 허용, L691). 외부 키 열 없음 data/source/nodes |
| 356 | L695 | 노드 ID 형식 | 구현됨 | pack n_hakodate, n_fukui_echizen |
| 357 | L696 | 역 묶음·환승 묶음 형식 | 구현됨 | pack g_himeji, hub_himeji |
| 358 | L697 | 사업자·노선 형식 | 구현됨 | pack |
| 359 | L698 | 계통·운전 계통 형식 | 구현됨 | pack |
| 360 | L700 | edge 형식 | 구현됨 | pack e_000123 |
| 361 | L699 | 승계 사슬 `lg_`, 열람 전용 `a_` | 문서 오류 | lg336 형식. 승계 사슬 ID는 기록에 저장 안 함(§2.10), 영향 없음 |
| 362 | L705 | ID 재사용 금지, 추가 전용 ids.lock | 부분 | 재사용·삭제 검사 T/check_ids.py:53-54, 추가 전용 쓰기 `--add` :41-44. data/ids.lock 파일은 아직 없음 (시드 동결 때 만듦) |

### §2.10 redirect 규칙 (L710~716)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 363 | L710 | 1:1 정정 | 미구현 | pack id_redirect 0행, Dart에 redirect 읽기 없음. T/check_ids.py:64-65가 은퇴 ID가 생기면 앱 읽기가 없다고 멈춤 |
| 364 | L711 | 1:N 분리, 못 풀면 needs_input | 미구현 | 위와 같음 |
| 365 | L712 | 묘비 항목, 기록은 invalid | 미구현 | 위와 같음 |
| 366 | L713 | 비공개가 된 역을 가리키는 기록의 표시 이름 유지 | 구현됨 | S/db/tables.dart:63~65, S/pack/pack_reader.dart:111 |
| 367 | L714 | 여러 판 건너뛴 갱신은 사슬 압축 | 미구현 | 위와 같음 |
| 368 | L716 | redirect는 읽을 때만 적용 | 미구현 | 위와 같음 |

### §2.10 변경 유형별 도구 (L721~724)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 369 | L721 | new-station | 미구현 | T/에 없음 |
| 370 | L722 | split-edge | 미구현 | T/에 없음 |
| 371 | L723 | transfer-section | 미구현 | T/에 없음 |
| 372 | L724 | diff-sources | 미구현 | T/에 없음 |

### §2.11 배포 파일 (L729~762)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 373 | L729 | master.sqlite | 구현됨 | build/manifest.json |
| 374 | L730 | names.sqlite, 파일 안에 출처별 고지 | 문서 오류 | 고지는 data/NOTICE.md와 설정 출처 화면 A/features/settings/ui/data_sources_screen.dart. 행별 source 있음 |
| 375 | L732 | rail.pmtiles: 선형, 역 점, 작은 기본 배경 | 구현됨(이름 다름) | 작은 배경은 base.pmtiles로 분리 T/gen_tiles.py 기본 배경 절, DESIGN §2.11 base.pmtiles |
| 376 | L733 | rail-osm.pmtiles | 구현됨 | `rail-osm.pmtiles` 앱 자산, `start_gate.dart` |
| 377 | L735 | manifest.json + .sig (판, 스키마, 최소 앱 버전, 해시) | 부분 | 판·스키마·해시 있음. 최소 앱 버전과 .sig 없음 |
| 378 | L762 | OSM 선형 유무를 앱이 파일을 읽어 판단 | 구현됨 | `pack_folder.dart` |
| 379 | L762 | OSM 값을 master·rail과 섞지 않음 | 구현됨 | OSM 값이 아직 없어 위반 없음 |
| 380 | L762 | verified는 사람이 확인했다는 뜻만 | 구현됨 | pack: hub·junction verified 0 |

### §2.12 구축된 파이프라인 (L769~796)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 381 | L769 | 항목마다 JSON 한 줄 YAML | 구현됨 | data/source/nodes/jr.yaml |
| 382 | L771 | 시드 | 구현됨 | T/gen_source.py |
| 383 | L772 | 위키 | 구현됨 | T/gen_wiki.py |
| 384 | L774 | 옛 폐선, 사철 2000년 전 outside | 구현됨 | T/gen_old.py, T/gen_source.py:928 |
| 385 | L775 | 선형 N02 5개 판 | 구현됨 | T/gen_geometry.py |
| 386 | L776 | 컴파일 | 구현됨 | CP |
| 387 | L777 | 타일과 manifest | 구현됨 | T/gen_tiles.py |
| 388 | L778 | 대조 | 구현됨 | T/verify.py |
| 389 | L779 | 현황 문서 생성 | 구현됨 | T/status.py |
| 390 | L780 | 역 문서 | 구현됨 | T/wiki_station.py |
| 391 | L781 | 역명 이력 | 구현됨 | T/gen_renames.py |
| 392 | L782 | 재검토 | 구현됨 | T/audit_db.py, T/audit_ext.py |
| 393 | L783 | 사람이 고친 값 | 구현됨 | data/overrides |
| 394 | L785 | 노드는 사업자별, JR 계열 한 묶음 | 구현됨 | pack n_nagoya가 신칸센·재래선 공용 |
| 395 | L786 | 옛 역은 위키에 km·연도 있으면 노드 | 구현됨 | data/overrides/wiki_insert.json |
| 396 | L787 | 공식 부품은 계통 하나, 끊긴 부품은 이어서 한 계통 | 구현됨 | pack r_nemuro_main_line |
| 397 | L788 | 위키만으로 기록 가능 노선을 만들지 않음 | 구현됨 | T/gen_old.py:123 |
| 398 | L789 | 옛 폐선 구간 이력은 old_history.json | 구현됨 | data/overrides/old_history.json |
| 399 | L790 | 역 날짜는 역 문서 우선 | 구현됨 | T/wiki_station.py |
| 400 | L791 | 3섹 이관 역 이름 대응표 | 구현됨 | T/gen_source.py:99 |
| 401 | L792 | 환승 묶음 350m, 문서 근거 | 구현됨 | CP:446~448 |
| 402 | L793 | 끝에서 이어짐 판정과 NOCONT | 구현됨 | T/gen_wiki.py:202 |
| 403 | L794 | 현행 역 좌표 N02 대조 | 구현됨 | T/n02_stations.py |
| 404 | L795 | 대표 이름은 가장 늦은 시기 | 구현됨 | T/gen_source.py |
| 405 | L796 | 노선 이름 짝짓기, lines_ko·lines_kana | 구현됨 | data/overrides/lines_ko.json |

### §3.1 완주율 3기준 (L803~807)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 406 | L803 | 현행 | 구현됨 | C/score/scorer.dart:62, ST:87 |
| 407 | L804 | 역대 | 구현됨 | C/score/scorer.dart:62, ST:88 |
| 408 | L805 | 특정 연도 Y | 구현됨 | C/score/scorer.dart:62,93, ST:28 |
| 409 | L807 | 단위는 승계 설정에 따름, 분자는 분모 안에서 | 구현됨 | pack denominator_unit on·off, C/score/scorer.dart:100 |

### §3.2 변화 유형별 처리 (L812~821)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 410 | L812 | 사업자 전환: 기본 승계, 끄기 설정 | 구현됨 | `carryoverProvider`, 설정 스위치 |
| 411 | L813 | 이설: 옛 선로는 폐선 기록, 새 선로는 다시 타야 함 | 구현됨 | pack 별도 edge, C/score/scorer.dart |
| 412 | L814 | 부분 폐선: 폐지 구간은 역대에만 | 구현됨 | C/score/scorer.dart:62 |
| 413 | L815 | 중간 폐선: 노선 하나, intentional_gap | 부분 | 노선·진행률 하나 구현. intentional_gap 없음 (data/source/checks 없음) |
| 414 | L816 | 연장 개업으로 완주 풀림 → 노선 변경 소식 | 구현됨 | `lineReopened` |
| 415 | L817 | 지난 역 신설은 open_stop | 구현됨 | data/source/events |
| 416 | L817 | 앞으로의 역은 new-station 도구 | 미구현 | 도구 없음 |
| 417 | L818 | 폐역은 그 역을 지나는 기록에 영향 없음 | 구현됨 | close_stop은 edge를 안 건드림 CP:194 |
| 418 | L819 | 폐선 후 재개업 | 구현됨 | CP:132 `life_open`. 사례 0건 |
| 419 | L820 | 재해 불통: 현행 분모 포함, 탑승 불가 | 구현됨 | pack 불통 edge 103개, SL:115 운휴 |
| 420 | L820 | 재해 불통 구간의 역 방문 가능 | 구현됨 | 방문은 구간 영업 상태를 보지 않음 MP:29-41, LD:88-113 |
| 421 | L821 | BRT는 폐선과 같이 처리 | 구현됨 | L254 |

### §3.3 노선 상세 화면 (L825~829)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 422 | L825 | 노선 상세: 노선 이름과 현행·역대 km·% 두 줄 | 구현됨 | LD:293-297,329-370. 줄을 탭하면 역 선택기는 그대로 BS:240 |
| 423 | L829 | 배지는 `현행 완주`만, 한 번 얻으면 새 역·연장으로 100%가 아니어도 유지, 탄 기록을 모두 지우면 사라짐 (v0.51, 사용자 결정 2026-11-05) | 구현됨 | C/score/collection.dart `heldBadges`, A/app/session_providers.dart `heldBadgesProvider`(설정 `badges.earned`), LD `_ScoreRow`는 현행 줄에만 배지. 시험 rules_test 「배지」 |
| 424 | L829 | 완주 상태가 바뀌면 노선 변경 소식 알림 | 구현됨 | `lineReopened` |

### §4.1 수록 정책 (L836~858)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 425 | L836 | 현행 전부 + 1950-01-01 이후 폐지 | 구현됨 | pack 2026-11-04.1: 노선 836, 법적 폐지 기준일 전 0건. N05 노선 묶음 판정은 data/candidates/n05_report.json |
| 426 | L840 | 지도 표시 등급 | 구현됨 | pack coverage 593 |
| 427 | L841 | 기록 가능 등급 | 구현됨 | pack coverage 173 |
| 428 | L842 | 열람 전용 등급: 노선 화면에 표시 | 구현됨 | pack archive, SL:633 |
| 429 | L843 | 보류 등급은 staging에만 | 부분 | staging 폴더 없음 (L199) |
| 430 | L846 | 기준일 이전 폐지는 탑승 불가 | 구현됨 | archive가 route_edge 밖 |
| 431 | L847 | 날짜는 조건 아님, 연도만 표시 | 구현됨 | pack archive_stop opened NULL 410, SL:647 |
| 432 | L848 | 선형 추가만으로 승격 | 구현됨 | CP:593 GEO, CP:664 |
| 433 | L849 | 신호장 완전성은 조건 아님 | 구현됨 | CP:660~665 |
| 434 | L854 | JR 수록, 계절 운행 포함 | 구현됨 | pack: ガーラ湯沢 r_joetsu_line_echigo_yuzawa_gala_yuzawa |
| 435 | L855 | 사철 수록, 제3종 제외 | 구현됨 | pack operator·line |
| 436 | L856 | 폐선 이름은 탑승일 기준, km는 폐지 직전 | 구현됨 | S/pack/pack_reader.dart:95, edge_km |
| 437 | L857 | 별선·단락선 extra, 梅田貨物線 별선 | 구현됨 | pack: l_umeda_freight_line extra |
| 438 | L858 | 연락선·BRT·삭도 등 미수록 | 구현됨 | pack 해당 이름 0 |

### §4.2 1970년대 미확인 노선 표 (L868~896)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 439 | L868 | 山形交通尾花沢線 기록 가능 후보 | 구현됨 | §4.2는 조건부 후보. 역 목록·km 미확정이면 열람 전용이 규칙대로 (§4.1, §4.5). pack names.name entity_type=archive 확인. 湯野浜線은 line |
| 440 | L869 | 茨城交通茨城線 | 구현됨 | pack 기록 가능, outside |
| 441 | L870 | 北陸鉄道 山中線·山代線 | 구현됨 | pack 기록 가능, outside |
| 442 | L871 | 横荘線 | 구현됨 | pack 기록 가능, outside |
| 443 | L872 | 金石線 | 구현됨 | pack 기록 가능, outside |
| 444 | L873 | 世知原線·臼ノ浦線 | 구현됨 | pack 기록 가능, normal |
| 445 | L874 | 鍛冶屋原線 | 구현됨 | pack 기록 가능 |
| 446 | L875 | 細島線 | 구현됨 | pack 기록 가능 |
| 447 | L876 | 上田交通真田傍陽線 | 구현됨 | §4.2는 조건부 후보. 역 목록·km 미확정이면 열람 전용이 규칙대로 (§4.1, §4.5). pack names.name entity_type=archive 확인. 湯野浜線은 line |
| 448 | L877 | 三国線·篠山線 | 구현됨 | pack 기록 가능 |
| 449 | L878 | 川俣線 | 구현됨 | pack 기록 가능 |
| 450 | L879 | 美唄鉄道 | 구현됨 | §4.2는 조건부 후보. 역 목록·km 미확정이면 열람 전용이 규칙대로 (§4.1, §4.5). pack names.name entity_type=archive 확인. 湯野浜線은 line |
| 451 | L880 | 北陸鉄道能登線 | 구현됨 | pack 기록 가능, outside |
| 452 | L881 | 加越鉄道 | 구현됨 | §4.2는 조건부 후보. 역 목록·km 미확정이면 열람 전용이 규칙대로 (§4.1, §4.5). pack names.name entity_type=archive 확인. 湯野浜線은 line |
| 453 | L882 | 松尾鉱業鉄道 | 구현됨 | §4.2는 조건부 후보. 역 목록·km 미확정이면 열람 전용이 규칙대로 (§4.1, §4.5). pack names.name entity_type=archive 확인. 湯野浜線은 line |
| 454 | L883 | 上武鉄道 | 구현됨 | §4.2는 조건부 후보. 역 목록·km 미확정이면 열람 전용이 규칙대로 (§4.1, §4.5). pack names.name entity_type=archive 확인. 湯野浜線은 line |
| 455 | L884 | 西鉄福岡市内線 수록 제외 | 구현됨 | pack 없음 |
| 456 | L885 | 名鉄拳母線 | 구현됨 | §4.2는 조건부 후보. 역 목록·km 미확정이면 열람 전용이 규칙대로 (§4.1, §4.5). pack names.name entity_type=archive 확인. 湯野浜線은 line |
| 457 | L886 | 雄勝線 | 구현됨 | pack 기록 가능 |
| 458 | L887 | 福井鉄道鯖浦線 | 구현됨 | §4.2는 조건부 후보. 역 목록·km 미확정이면 열람 전용이 규칙대로 (§4.1, §4.5). pack names.name entity_type=archive 확인. 湯野浜線은 line |
| 459 | L888 | 北丹鉄道 | 구현됨 | pack 지도 표시, outside |
| 460 | L889 | 東濃鉄道駄知線 | 구현됨 | pack 기록 가능 |
| 461 | L890 | 山形交通 三山線·高畠線 | 구현됨 | pack 기록 가능 |
| 462 | L891 | 富山地鉄笹津線 · 庄内交通湯野浜線 | 구현됨 | §4.2는 조건부 후보. 역 목록·km 미확정이면 열람 전용이 규칙대로 (§4.1, §4.5). pack names.name entity_type=archive 확인. 湯野浜線은 line |
| 463 | L892 | 越後交通栃尾線 | 구현됨 | pack 기록 가능 |
| 464 | L893 | 大分交通耶馬渓線 | 구현됨 | pack 기록 가능 |
| 465 | L894 | 北恵那鉄道 | 구현됨 | §4.2는 조건부 후보. 역 목록·km 미확정이면 열람 전용이 규칙대로 (§4.1, §4.5). pack names.name entity_type=archive 확인. 湯野浜線은 line |
| 466 | L895 | 東濃鉄道笠原線 | 구현됨 | pack 기록 가능 |
| 467 | L896 | 姫路市営モノレール | 구현됨 | §4.2는 조건부 후보. 역 목록·km 미확정이면 열람 전용이 규칙대로 (§4.1, §4.5). pack names.name entity_type=archive 확인. 湯野浜線은 line |
| 468 | L861 | 폐선 목록은 위키 일람과 개별 문서로 만듦 | 구현됨 | T/gen_old.py:167, data/imports/old_titles.json. 판정 결과는 기록 가능 또는 archive |

### §4.4 노면전차망 (L920)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 469 | L920 | 옛 노면전차망 미수록 | 구현됨 | pack: 京都·名古屋·横浜·大阪市電 0 |
| 470 | L920 | 현행 노면전차와 최근 부분 폐지는 일반 규칙 | 구현됨 | pack: tram 53노선 |

### §4.5 열람 전용 (L932~965)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 471 | L932 | 표시는 데이터 상태, 기록 허용은 기준일로 판정 | 구현됨 | T/gen_old.py:123 |
| 472 | L932 | archive 파일 구조, 왓카나이잔교 | 구현됨 | pack: 稚内桟橋 a_4d17d97f, r_soya_main_line, n_wakkanai 다음 |
| 473 | L942 | 이름은 names/, 한글 검사, after·before | 구현됨 | pack name archive ko 579, archive_stop.after_id·before_id |
| 474 | L954 | 폐역·폐선과 같은 3단계 흐림 | 구현됨 | SL:633~680 |
| 475 | L954 | 메인 설정 체크박스 (기본 켬) | 구현됨 | A/features/settings/ui/settings_screen.dart:30~48 |
| 476 | L954 | 기록 화면 맨 위 체크박스 | 구현됨 | RS:194 `_DisplayBar` |
| 477 | L955 | 연도만, 모르면 `~?`, km도 `?` | 구현됨 | S/pack/pack_reader.dart:209, SL:647, SL:667 |
| 478 | L956 | 출발·도착 불가, 탭하면 폐지 연도와 안내 | 구현됨 | SL:652 |
| 479 | L957 | 끝 역 너머 줄기를 가늘고 흐리게 | 구현됨 | SL:20 `tail`, SL:59 |
| 480 | L958 | 완주율·거리 제외 | 구현됨 | network_reader가 archive를 안 읽음 |
| 481 | L959 | 지도에 그리지 않음 | 구현됨 | T/gen_tiles.py archive 미사용 |
| 482 | L960 | 역 방문 기록 불가 | 구현됨 | archive ID는 node가 아님 |
| 483 | L961 | 승격 규칙 | 구현됨 | T/gen_old.py:123 |
| 484 | L962 | 옛 노면전차망·전용선·미개업선 제외 | 구현됨 | pack archive 이름 검사 |
| 485 | L964 | 파일을 지워도 기록·통계 동일 | 구현됨 | edges·km·events 무참조 |
| 486 | L965 | km 모르는 역은 선로망에 넣지 않음 | 구현됨 | archive_stop km NULL 115행 |

### §4.6 탑승 기록 허용 범위 (L970~1014)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 487 | L970 | 기준일 전 날짜는 계산된 날짜만 날짜 모름, 입력값은 date_input에 남음 (v0.48에서 문서를 고침) | 구현됨 | C/date/date_rules.dart:14, RI 해석이 date_input을 그대로 둠 |
| 488 | L974 | 현행 노선 허용·포함 | 구현됨 | pack |
| 489 | L975 | 국철·JR 폐선 1950-01-01 이후 허용·포함 | 구현됨 | pack 幸袋線 normal |
| 490 | L979 | 사철 폐선 2000년 이후 허용·포함 | 구현됨 | pack normal 34노선 |
| 491 | L977 | 처음부터 사철이던 1950-01-01~1999 폐선: 노선별 검증 후 허용, 분모 포함 (v0.50) | 구현됨 | 판 2026-11-04.2에서 normal로 옮김. pack edge_attr normal 19,912·extra 43, outside 0 |
| 492 | L981 | 기준일 이전 폐지 표시만 | 구현됨 | pack archive |
| 493 | L1005 | 국철 이관 뒤 폐지 구간은 분모 | 구현됨 | CP:169 이관 때 등급 승계. pack: 黒石線 국철 단위 normal. 이관 뒤 사철 시기 행이 없는 노선도 있음 |
| 494 | L1006 | 국철·JR은 139개 + 추가분과 대조 | 구현됨 | T/audit_ext.py |
| 495 | L1007 | 根北線 수록 | 구현됨 | pack 1970-12-01 |
| 496 | L1008 | 手宮線: 법적 폐지일로 범위, 선택기는 마지막 운행일 | 구현됨 | pack valid_to 1962-05-15, legal 1985-11-05 |
| 497 | L1009 | 범위 폐지일 하한 판정 | 구현됨 | pack 범위 폐지일 edge 0건 |
| 498 | L1010 | 특정 연도는 1970년부터 | 구현됨 | ST:40 |
| 499 | L1011 | 기준일 전 날짜는 날짜 모름, 설명 문구 없음 | 구현됨 | C/date/date_rules.dart:14, RR:112 |
| 500 | L1011 | 입력칸이 바로 `날짜 모름`으로 바뀜 | 구현됨 | RS:99-101 칩이 바로 `날짜 모름`. 운전 계통 화면 칩은 입력값 그대로 SS:74 |
| 501 | L1011 | 연대는 1970년대부터 고름 | 구현됨 | 연대 입력 `198X`, `1980s`, `1980년대`, `1980年代` |
| 502 | L1012 | 탈 수 없는 날짜는 경고 팝업, 저장하지 않음 (v0.48) | 구현됨 | C/network/ride_interpreter.dart:118 `unridable`, A/features/record/ui/session_date.dart:137 `showUnridable` |
| 503 | L1013 | CSV 해당 행도 같음, 원문 보존 | 구현됨 | RI:46~52, C/importing/csv_import.dart:316 |
| 504 | L1014 | 사철 행: 검증되면 outside, 아니면 unknown_ref | 구현됨 | C/importing/csv_import.dart:14, RR:137 |

### §4.7 지도 위치 상태 (L1020~1025)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 505 | L1020 | 역 quality와 checked | 구현됨 | pack precise 9,467, approx 1,530, none 26 |
| 506 | L1021 | edge.geometry_quality | 구현됨 | pack precise 10,099, none 1,084 |
| 507 | L1022 | route.map_coverage | 구현됨 | pack full 641, partial 80, none 102 |
| 508 | L1025 | approx 좌표는 지도에 점을 찍지 않음 | 대상 아님 | redesign 4.1 `역 위치 규칙`: 폐역은 approx도 점 유지. DESIGN §4.7은 미갱신 (모순 M4) |

### §5.1 구간 탑승 (L1032)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 509 | L1032 | 노선 + 출발역 + 도착역 + 날짜 | 구현됨 | RC:578~637 |
| 510 | L1032 | 시간 입력 | 구현됨 | A/features/record/ui/record_edit_screen.dart:44,164. 입력은 저장 뒤 기록 수정 화면 |
| 511 | L1032 | 열차명 입력 | 구현됨 | A/features/record/ui/record_edit_screen.dart:45,165. 입력은 저장 뒤 기록 수정 화면 |
| 512 | L1032 | 편성 입력 | 구현됨 | A/features/record/ui/record_edit_screen.dart:46,166. 입력은 저장 뒤 기록 수정 화면 |
| 513 | L1032 | 메모 입력 | 구현됨 | A/features/record/ui/record_edit_screen.dart:47,167. 입력은 저장 뒤 기록 수정 화면 |
| 514 | L1032 | 날짜 미상 허용 | 구현됨 | A/features/record/ui/session_date.dart `DateAnswer(null)` |

### §5.2 역 방문 (L1035~1039)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 515 | L1035 | 역만 방문한 경우 기록 | 구현됨 | MP:29-41,70-75, LD:88-113, A/features/record/controller/record_list_controller.dart:64-87 |
| 516 | L1036 | 기록 탭에 구간 탑승 / 역 방문 두 목록 | 구현됨 | A/features/record/ui/record_home_screen.dart:46-61 셋째 탭 `역 방문`, MP:131-165 |
| 517 | L1037 | 완주율·거리 무영향, 지도 점은 칠해짐 | 구현됨 | 방문은 ride_edge에 안 들어가 점수 무영향 S/records/record_store.dart:161-165, 지도 MS:245-281, A/app/session_providers.dart:179-188 |
| 518 | L1038 | 폐역 방문 가능 | 구현됨 | 폐역 점 시트 MH:98, 노선 상세 점 LD:238. 막는 코드 없음 |
| 519 | L1038 | 열람 전용 역은 방문 불가 | 구현됨 | L960 |
| 520 | L1039 | 방문 역 수 (현행 / 폐역) | 구현됨 | 합계와 폐역 수 |
| 521 | L1039 | 도도부현별 방문 역 수 | 구현됨 | 도도부현별 방문 역 수 A/features/stats/ui/visits_screen.dart:40, A/features/stats/controller/visits_controller.dart, C/score/collection.dart:139, 라우트 A/app/router.dart:83 |

### §5.3 지도 위 점의 상태 (L1044~1048)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 522 | L1044 | 미방문: 회색 테두리, 가운데 흰색 | 구현됨 | MS:189~208 |
| 523 | L1045 | 통과: 파란 테두리, 뚫린 원 | 구현됨 | MS:254-290 stationPassedLayer, 필터 MH:150-152 |
| 524 | L1046 | 발로 밟음: 파란색 꽉 찬 원 | 구현됨 | MS:254-290 stationSteppedLayer, 필터 MH:150-152 |
| 525 | L1048 | 폐역은 빨강 | 구현됨 | MS:274-287 `closed`면 폐선·탑승 색 |
| 526 | L1048 | 방문만 있으면 점만 칠함 | 구현됨 | 방문은 stepped에만 들고 선은 riddenEdges A/app/session_providers.dart:159-161,179-188 |

### §5.4 불확실한 날짜 (L1051~1078)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 527 | L1051 | 마스터와 기록이 같은 날짜 형식 | 구현됨 | C/date/date_span.dart |
| 528 | L1051 | 화면은 계산된 날짜를 입력 형식 그대로 | 구현됨 | C/date/date_rules.dart:84, A/features/record/ui/record_list_screen.dart:92 |
| 529 | L1051 | 날짜 모름이 된 기록은 `날짜 모름` | 구현됨 | S/records/record_queries.dart `shownDate` |
| 530 | L1051 | 입력값을 수정 화면에서 봄 | 구현됨 | A/features/record/ui/record_edit_screen.dart:43,163 date_input을 그대로 보임 |
| 531 | L1055 | 일까지 | 구현됨 | C/date/date_span.dart |
| 532 | L1056 | 월까지 | 구현됨 | C/date/date_span.dart |
| 533 | L1057 | 연도까지 | 구현됨 | C/date/date_span.dart |
| 534 | L1058 | 연대까지 (저장·표기) | 구현됨 | C/date/date_span.dart, C/date/date_rules.dart:55. 사용자 입력은 L1011 |
| 535 | L1059 | 모름은 NULL, 화면 `~?` | 구현됨 | C/date/date_rules.dart:55 |
| 536 | L1060 | 끝나지 않음 ongoing | 구현됨 | C/date/date_span.dart `maxDate` |
| 537 | L1062 | NULL과 ongoing을 섞지 않음 | 구현됨 | pack valid_to, CP:578 |
| 538 | L1063 | 마스터 날짜는 화면에 연도만 | 구현됨 | C/date/date_rules.dart:55 |
| 539 | L1064 | 빌드 시 (lo, hi)로 변환, ongoing은 최댓값 | 구현됨 | CP:578, T/lib.py:77 |
| 540 | L1069 | 역 선택: 범위가 겹치면 선택 가능 | 구현됨 | C/date/date_rules.dart `stateOn`, C/network/selector.dart |
| 541 | L1070 | 애매하면 선택되고 날짜 칩 `?` + 저장 시 안내 | 구현됨 | 칩 뒤 `?` (`record_session_screen.dart`) |
| 542 | L1071 | 특정 연도: 확실히 영업한 단위만 분모에, 애매한 단위는 분모·분자에서 빼고 따로 셈 | 구현됨 | C/score/scorer.dart:62-71 `unitCounts`(BasisYear는 `_mayRunIn`과 `_surelyRanIn`), :75 `unitUndecided`, :112·126 `Score.undecidedUnits`. 기간 하한·상한은 S/pack/network_reader.dart:150-151,182-183 `fromHi`·`toLo`. 빌드 분모 T/lib.py:90 `year_status`, CP:332-334, 시뮬 T/appsim.py:99 `year_certain`(K-null). 시험 packages/noriori_core/test/rules_test.dart:75. 화면 표시는 #678 |
| 543 | L1071 | 폐지 연도만 알면 폐지 해에 영업한 것으로 침 | 구현됨 | C/score/scorer.dart:82 `_surelyRanIn`(폐지 하한이 그해 1월 1일 이후면 확실), T/lib.py:90 `year_status` |
| 544 | L1072 | 현행·역대는 날짜 불확실성과 무관 | 구현됨 | C/score/scorer.dart:62 |
| 545 | L1073 | 미상·부분 기록은 유효 범위로 연도 판정 | 구현됨 | RI:111 |
| 546 | L1074 | 수록 범위 판정 | 구현됨 | T/gen_old.py:123 |
| 547 | L1076 | CI 위상은 범위 양 끝에서 검사 | 미구현 | #173와 같음 |
| 548 | L1078 | 개업 `1987~`, 폐지 `~1987` | 구현됨 | A/i18n/ko.i18n.json state.since·until |

### §6 기능 명세: 기록 (L1088~1094)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 549 | L1088 | 구간 탑승 | 구현됨 | RC:578 |
| 550 | L1088 | 경로 자동 전개 | 구현됨 | `route_resolver.dart` `record`, `across` |
| 551 | L1088 | 환승역 노선 선택 | 구현됨 | 사용자 결정: 분기 이동은 한 기록으로 묶지 않음. 다구간은 재설계안 4.2 |
| 552 | L1088 | 날짜 미상 허용 | 구현됨 | L1032 |
| 553 | L1089 | 시점 인식 역 선택기 | 구현됨 | C/network/selector.dart, RC:357 |
| 554 | L1089 | 분기선 표시 | 구현됨 | SL:479 |
| 555 | L1090 | 그 자리에서 전환 | 구현됨 | LD:78-113 |
| 556 | L1090 | 범위 지정 | 구현됨 | LD:122-156,194-203 |
| 557 | L1090 | 되돌리기 | 구현됨 | 표 2의 L1090와 같음 (undo_snack.dart) |
| 558 | L1090 | 일괄 삭제 | 구현됨 | 여정 전체 삭제 포함 |
| 559 | L1091 | 역 방문 기록 | 구현됨 | 도도부현별 방문 역 수 A/features/stats/ui/visits_screen.dart:40, A/features/stats/controller/visits_controller.dart, C/score/collection.dart:139, 라우트 A/app/router.dart:83 |
| 560 | L1092 | 운전 계통 입력 | 구현됨 | 표 2의 L1092과 같음 |
| 561 | L1092 | 순환 입력 | 구현됨 | 표 2의 L1092과 같음 |
| 562 | L1093 | 열람 전용 역·노선 표시 | 구현됨 | SL:633, SL:515 archive |
| 563 | L1094 | 여정 묶음 | 구현됨 | `TripCommands`, `TripDetailScreen` |
| 564 | L1094 | 다구간 경로 탐색 | 구현됨 | `findJourney`, `JourneyScreen`. 시각표 없는 기록 입력 보조 |
| 565 | L1094 | 사진 | 대상 아님 | 2026-11-03 결정: 뺌 |
| 566 | L1094 | 메모 | 구현됨 | A/features/record/ui/record_edit_screen.dart:47,167 |
| 567 | L1094 | GPS 근처 역 | 대상 아님 | 2026-11-03 결정: 뺌. 위치는 `가까운 곳`에만 씀 |

### §6 기능 명세: 지도 (L1096~1098)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 568 | L1096 | 현행·폐선·탑승 상태 | 구현됨 | MS 층 구성, MH:27 |
| 569 | L1096 | 역 원 | 구현됨 | 3상태 MS:206-281, MH:150-152. 폐역·폐선을 꺼도 칠해진 폐역 점은 남음 (필터에 closed 조건 없음 MH:151-152) |
| 570 | L1096 | 도도부현 경계 | 구현됨 | `base.pmtiles`의 `border` 층 |
| 571 | L1096 | 위치 미확인 구간 표식 | 구현됨 | `master.map_marker` 115행, 표식 층, `MarkerSheet` |
| 572 | L1097 | 미승 구간만 보기. v0.41에서 `승차만` 보기로 바뀜 | 구현됨 | L522과 같음. `승차만` 보기로 대체 |
| 573 | L1097 | 노선 단독 보기 | 구현됨 | 표 2의 L1097과 같음 |
| 574 | L1097 | 노선 탭 → 정보 시트 | 구현됨 | MH:84-122, A/app/router.dart:75-96, MP:83-128 |
| 575 | L1098 | 타임 슬라이더 | 구현됨 | 지도 `연도` 칩 |
| 576 | L1098 | 도도부현 히트맵 | 구현됨 | 지도 층 A/features/map/map_style.dart:41,60,371, 칠하기 A/features/map/ui/map_home_screen.dart:222, 칩 :443-448 |

### §6 기능 명세: 통계 (L1099~1100)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 577 | L1099 | 완주율 현행·역대 | 구현됨 | ST |
| 578 | L1099 | 승차 거리 | 구현됨 | 탄 영업km와 누적 탑승 거리 |
| 579 | L1099 | 전체 | 구현됨 | ST:124 |
| 580 | L1099 | 사업자별 | 구현됨 | ST:223 |
| 581 | L1099 | 노선별 | 구현됨 | ST:224 |
| 582 | L1099 | 도도부현별 | 구현됨 | ST:221 |
| 583 | L1100 | 특정 연도 완주율 | 부분 | 연도 고르기 ST:29-51(1950부터, `floorYear` :42), 판정 불가 단위를 분모에서 빼고 `판정 불가 n구간` ST:197-202. 화면은 목업 대조 전 (규칙 5) |
| 584 | L1100 | 승계 끔 모드 | 구현됨 | 설정 스위치 A/features/settings/ui/settings_screen.dart:97-101, carryoverProvider A/app/session_providers.dart:233, 모든 집계가 이 값을 씀. 팩 분모 off 33,161.8km를 시나리오로 확인. 단 AR:L245의 켜기 결함 있음 |
| 585 | L1100 | 연도별 그래프 | 구현됨 | `YearsScreen`, 자체 위젯 |
| 586 | L1100 | 활동 캘린더 | 구현됨 | A/features/stats/ui/activity_screen.dart:13, 라우트 A/app/router.dart:82 |
| 587 | L1100 | 폐선 컬렉션 | 구현됨 | 폐선 컬렉션과 폐지 늦은 순 C/score/activity.dart:113 이하, A/features/stats/ui/collection_screen.dart:95,126 |
| 588 | L1100 | 방문 역 통계 | 구현됨 | 도도부현별 방문 역 수 A/features/stats/ui/visits_screen.dart:40, A/features/stats/controller/visits_controller.dart, C/score/collection.dart:139, 라우트 A/app/router.dart:83 |

### §6 기능 명세: 수집·데이터·서버 (L1101~1104)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 589 | L1101 | 현행 완주 배지 (역대 완주 배지는 없앰, 2026-11-05) | 구현됨 | `CollectionScreen`의 `held` |
| 590 | L1101 | 축하 카드 | 구현됨 | `showCompleteCard` |
| 591 | L1101 | 공유 카드 | 구현됨 | 축하 카드를 이미지로 공유 |
| 592 | L1101 | 위젯 | 대상 아님 | L1101 "P1~P2", L1794 Phase 3 목록에 위젯 없음 |
| 593 | L1102 | JSON 백업 | 구현됨 | C/backup/backup_codec.dart, S/backup/auto_backup.dart |
| 594 | L1102 | 자동 백업 파일 | 구현됨 | A/app/start_gate.dart `_paused`, S/backup/auto_backup.dart:53 |
| 595 | L1102 | CSV 내보내기 | 구현됨 | A/features/data/ui/data_settings_screen.dart:24-38,75-84, A/features/data/controller/export_controller.dart:25-38, CE:127-275 |
| 596 | L1102 | 앱 업데이트로 데이터 갱신 | 구현됨 | C/pack/pack_choice.dart:18, S/records/cache_rebuild.dart |
| 597 | L1103 | 노리츠부시 CSV 가져오기 | 부분 | 일반판·코멘트판 구현. 수동 선택, 중복 후보, 일괄 승하차 없음 (L1632) |
| 598 | L1103 | 앱 안에서 데이터 내려받기 | 미구현 | http 코드 없음 |
| 599 | L1103 | 노선 변경 소식 | 구현됨 | `NewsGate`, `networkNews` |
| 600 | L1104 | 기기 간 동기화 | 대상 아님 | L1104 "P2", L1797 이후 |
| 601 | L1104 | 순위표 | 대상 아님 | L1104 "P2", L1797 이후 |

### §6.1 첫 기능 목록에서 되살린 항목 (v0.42)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 602 | v0.42 L1112 | 같은 구간 반복 탑승 횟수 (P1) | 미구현 | 구간별 횟수 계산 없음. S/records/record_queries.dart:114-117은 DISTINCT만 |
| 603 | v0.42 L1112 | 반복 탑승 횟수 통계 (P1) | 미구현 | ST에 없음 |
| 604 | v0.42 L1113 | GPS 주행 로그 자동 기록. 백그라운드, 옵트인, 위치는 기기 밖으로 나가지 않음 (P2) | 대상 아님 | L1141 P2 |
| 605 | v0.42 L1114 | 즐겨찾기 고정 (P1) | 미구현 | 코드·저장 없음 (L153 행) |
| 606 | v0.42 L1114 | 열차명 검색 (P1) | 대상 아님 | redesign 4.1 `수송밀도·열차명 검색: P2 (출처 없음)`. DESIGN §6.1은 미갱신 |
| 607 | v0.42 L1114 | 도도부현별 입력 (P1) | 미구현 | A/features/record에 도도부현 경로 없음 (L141 행) |
| 608 | v0.42 L1114 | 기록 목록 정렬 (P1) | 미구현 | S/records/record_queries.dart:93 고정 순서 |
| 609 | v0.42 L1114 | 기록 목록 필터 (P1) | 미구현 | A/features/record/ui/record_list_screen.dart에 필터 없음 |
| 610 | v0.42 L1115 | 역 방문의 메모·사진·차량 (P2) | 대상 아님 | L1143 P2. 지금은 방문 토글뿐 MP:70-75 |
| 611 | v0.42 L1115 | 차량 도감 (P2) | 대상 아님 | L1143 P2 |
| 612 | v0.42 L1116 | 지도 필터: 사업자 (P1) | 미구현 | 칩은 승차만·폐선·역 이름뿐 MH:238-257. 타일에 사업자 속성 없음 T/gen_tiles.py:22-27 |
| 613 | v0.42 L1116 | 지도 필터: 노선 종류 (P1) | 미구현 | 위와 같음 |
| 614 | v0.42 L1116 | 지도 필터: 지역 (P1) | 미구현 | 위와 같음 |
| 615 | v0.42 L1117 | 기록 재생 애니메이션 (P2) | 대상 아님 | L1145 P2 |
| 616 | v0.42 L1118 | 지도 우측 버튼 묶음 (P1) | 대상 아님 | redesign 4.4 #1 지도 버튼과 근처 역 뺌 |
| 617 | v0.42 L1118 | 지도 종류 전환 (P1) | 대상 아님 | redesign 4.4 #1 지도 버튼과 근처 역 뺌 |
| 618 | v0.42 L1119 | 미승 구간 추천: 현재 위치나 고른 지역 근처의 안 탄 구간 (P1) | 구현됨 | `가까운 곳`, 반경 50km |
| 619 | v0.42 L1119 | 미승 구간 목록 (P1) | 구현됨 | `RemainingScreen` |
| 620 | v0.42 L1120 | 개인 기록: 하루 최장 거리 (P1) | 미구현 | ST에 없음 |
| 621 | v0.42 L1120 | 개인 기록: 최다 탑승 노선 (P1) | 미구현 | ST에 없음 |
| 622 | v0.42 L1120 | 개인 기록: 첫 탑승일 (P1) | 미구현 | ST에 없음 |
| 623 | v0.42 L1120 | 개인 기록: 최근 완주 노선 (P1) | 미구현 | ST에 없음 |
| 624 | v0.42 L1121 | 수송밀도 구간별 진행률 (P1) | 대상 아님 | redesign 4.1 `수송밀도·열차명 검색: P2 (출처 없음)`. DESIGN §6.1은 미갱신 |
| 625 | v0.42 L1121 | 분모 밖 노선 자체 진행률 (P1) | 구현됨 | LD:278-292, DG:185-199 |
| 626 | v0.42 L1122 | 업적 배지와 마일스톤 (P1) | 구현됨 | `CollectionScreen`, 역 수 기준 100~3,000 |
| 627 | v0.42 L1122 | 역 스탬프북 (P1) | 미구현 | 코드 없음 |
| 628 | v0.42 L1122 | 폐선 컬렉션 정렬 (P1) | 구현됨 | 폐선 컬렉션과 폐지 늦은 순 C/score/activity.dart:113 이하, A/features/stats/ui/collection_screen.dart:95,126 |
| 629 | v0.42 L1123 | 월간·연간 결산 카드 (P2) | 대상 아님 | L1152 P2 |
| 630 | v0.42 L1123 | 経県値식 단일 점수 `철도 경험치` (P2) | 대상 아님 | L1152 P2 |
| 631 | v0.42 L1124 | 마스코트 (P2) | 대상 아님 | L1153 P2 |
| 632 | v0.42 L1124 | 곁들임 정보 (P2) | 대상 아님 | L1153 P2 |
| 633 | v0.42 L1124 | 공유 카드의 다크 지도 기본값 후보 (P2) | 대상 아님 | L1153 P2 |
| 634 | v0.42 L1125 | 鉄ログ 백업 가져오기 (P2) | 대상 아님 | L1154 P2 |
| 635 | v0.42 L1125 | 데이터 오류 제보 (P2) | 대상 아님 | L1154 P2 |

### v0.48~v0.51에서 새로 넣은 항목 (2026-11-05)

DESIGN 머리말 5~14행의 v0.48~v0.51 변경과 그 본문에서 생긴 요구입니다. 화면 항목은 코드가 있어도 목업 대조 전이라 `부분`입니다 (규칙 5).

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 636 | L34 | 원천 스냅샷(data/imports, id_map.json)은 재배포하지 않음 (v0.48) | 구현됨 | .gitignore:2 data/imports/, :5 data/candidates/. 이 체크아웃에도 없음 |
| 637 | L34 | 선형은 원 자료 조건을 파일별로 따름 (N05는 비상업) | 구현됨 | data/source/geometry/LICENSE.md와 n02.yaml·n02_legacy.yaml·n05.yaml·osm.yaml |
| 638 | L37 | 출처는 하나씩 뺄 수 있게: 출처 목록 한 곳에서 끄고 다시 빌드 (v0.48) | 구현됨 | data/sources.json(12출처, 필수 3). T/lib.py:14 필수 출처를 끄면 멈춤, T/verify.py:72-87 꺼진 출처 값이 남으면 실패 |
| 639 | L39 | 지도는 선형이 있는 구간을 모두 그리고, 없을 때만 위치 미확인 표식 | 구현됨 | 표식은 map_visible=0인 폐지 구간에만 CP:735 (판 2026-11-05.7 pack 11구간, map_marker 15행) |
| 640 | L48 | iOS는 AltStore·SideStore 공식 소스로 새 판을 업데이트로 받음 (v0.50) | 부분 | .github/workflows/release.yml:102-109, T/altstore_source.py, distribution/altstore/meta.json. 저장소가 private이라 소스 주소를 아직 읽을 수 없음 (L48 "소스는 저장소가 공개여야 읽힘"). 태그 실행 기록 없음 |
| 641 | L196 | geometry 모듈은 출처별 파일 n02·n02_legacy·n05·osm + LICENSE.md | 구현됨 | data/source/geometry/ |
| 642 | L198 | aliases 모듈 (검색 별칭) | 구현됨 | data/source/aliases/. names alias old_title 412, noritsubushi 1,205, moved 12 |
| 643 | L202 | 시드 동결 전 사람이 고친 값은 data/overrides, 동결 때 data/source로 흡수 | 부분 | data/overrides/ 35개 파일. 흡수는 시드 동결 때 (미실행, ARCHITECTURE §4.2) |
| 644 | L213 | edge.geometry_source 열 | 구현됨 | CP:656. pack n02 10,066, n05 2,351, osm 1,189, 없음 122 |
| 645 | L258 | 역 위치 이동은 선로 위 km 기준. km가 바뀌면 옛·새 노드 + moved.json, 같은 역 묶음 (v0.48) | 구현됨 | data/overrides/moved.json, master.node_move 26행 CP:802 |
| 646 | L259 | 이름이 같은 옛 노드는 `(구)`·`（旧）`·`(old)`를 붙여 폐역처럼, 원래 이름은 별칭 (v0.49) | 구현됨 | T/gen_source.py:1337-1352 OLDMARK, names alias kind=moved 12행 |
| 647 | L321 | CI는 imports 없이 data/source를 컴파일하고 원천 없이 되는 검사를 돌림 | 구현됨 | T/all.sh:7-25 imports가 없으면 생성 단계를 건너뜀, .github/workflows/data.yml:34 |
| 648 | L322 | 로컬 판 릴리스: 원천부터 재생성, 원천 대조와 회귀·appsim·invariants·판 번호 검사 | 부분 | appsim·invariants는 T/all.sh:38-39, 판 번호는 T/sync_pack.sh의 check_edition. 회귀(#183)는 없음 |
| 649 | L334 | 공개·기록 ID는 영어 이름 규칙, 번호·해시가 있으면 실패 | 구현됨 | T/verify.py:69-71. pack 공개 ID 30,604개에 `_b` 꼬리 0, `_old` 20 |
| 650 | L509 | CSV 가져오기는 탈 수 없는 날짜·기준일 이전 행을 날짜 모름으로 넣고 `날짜 모름으로 넣은 행 n건`만 보임 (v0.48) | 부분 | 규칙 C/importing/csv_import.dart:178 `undated`, 건수 A/features/data/controller/import_controller.dart:171. 결과 문구 A/features/data/ui/import_screen.dart:219는 목업 대조 전 (규칙 5) |
| 651 | L548 | `outside`는 새로 들어오는 폐선만, 대조가 끝나면 normal. 판 2026-11-04.2부터 0행 (v0.50) | 구현됨 | pack edge_attr denominator_class normal 19,912, extra 43, outside 0 |
| 652 | L555 | `outside`는 누적 탑승 거리에도 넣지 않음, `extra`는 넣음 | 부분 | 누적 거리는 ride_cache km10 합이라 분모 밖 전부를 넣음 S/records/record_queries.dart:298-302. `outside`를 빼는 코드 없음. 지금 판은 outside 0행이라 차이가 없음 |
| 653 | L556 | `outside`·`extra` 구간도 노선이 있으면 기록 탭 목록에 나오고 기록 가능, 완주율 통계에서만 뺌 | 구현됨 | C/score/browse_tree.dart `_outsideOwners`·`BrowseLine.outside`: 분모 밖 구간만 있는 노선 25개(東海道貨物線, 藤城線 등)도 목록에, 회사 합계·「거의 완주」에서는 뺌. 시험 real_pack_rules_test |
| 654 | L557 | N05 대조가 끝나 한 번에 normal로 옮김, 이번 편입은 변경 내역으로 안내하지 않음 | 구현됨 | 판 2026-11-04.2 (data/overrides/as_of.json 이후 판). outside 0 |
| 655 | L564 | 분기·환승의 기준은 선로 연결 (junction·continue는 분기, 같은 node·group·hub는 환승) (v0.48) | 구현됨 | CP:451-518 route_link: junction 행은 branch·continue, 가까운 노드·group·hub는 transfer |
| 656 | L577 | X자 교차: 두 노선이 모두 지나고 연결선도 있으면 환승 ①과 분기를 함께 표시 | 구현됨 | `tools/compile.py`의 `crossing`: 분기(`branch`)이고 상대 노선도 그 역을 지나면 환승 행도 만듦. 판 2026-11-05.3에 26곳(追分, 拝島, 吉田, 香椎, 春日部, 所沢 등). 표시는 core `DisplayRules.transfers`와 분기 줄이 따로 그림 |
| 657 | L580 | 환승 번호는 종류에 고정, 없는 번호는 건너뜀 (v0.48) | 구현됨 | C/network/display_rules.dart:298-309 (enum 순서가 번호, 종류가 하나면 번호 없음) |
| 658 | L627 | 분기 방향 손 보정은 junction_side.json에 사유 필수 | 부분 | CP:35-40이 읽음. 사유(`why`)가 없는 행을 막는 검사는 없음 |
| 659 | L672 | 출처를 끄면 빠진 값은 다음 출처로 채우거나 등급을 내림, 현행 노선은 CI 실패 | 부분 | 선형은 다음 출처로 채움 (T/gen_geometry.py 순서). 현행 노선을 내리지 않고 실패시키는 검사는 없음 (#175) |
| 660 | L689 | 회사·노선 이름으로도 구별되지 않으면 `_old`, 그다음 지역 이름. 환승 묶음은 JR 역 이름. 내부 ID만 번호 | 구현됨 | pack `_old` 20, `o_keifuku_electric_railroad_fukui`, 해시 hub 0 (T/verify.py:69-71이 막음) |
| 661 | L739 | 선형 출처: N02 최신판부터 옛 판 → OSM → N05, geometry_quality는 선 유무, map_coverage·map_visible도 선 유무 | 구현됨 | T/gen_geometry.py, CP:596-604,656. pack coverage 지도 표시 959·기록 가능 74 |
| 662 | L760 | 폐지 구간 선형 수량 | 구현됨 | DESIGN 본문을 판 2026-11-05.7 실측으로 고침: 폐지 구간 3,999개 중 3,988개에 선형, 11개가 표식(15곳) |
| 663 | L774 | 옛 폐선 N05: gen_n05.py + 손 대조 표 n05_fix.json, 이설 전 옛 선로는 `○○旧線` 지선 계통 (v0.51) | 구현됨 | T/gen_n05.py, data/overrides/n05_fix.json 432항목 (line 185, join 53, skip 66 등) |
| 664 | L858 | 수록 안 함에 簡易軌道(町営·村営軌道) (v0.49) | 구현됨 | T/gen_n05.py:293-295 |
| 665 | L920 | 옛 노면전차망도 v1.0에: 못 만들면 열람 전용, 확정되면 기록 가능, 위치까지면 지도 표시 (v0.51) | 구현됨 | 판 2026-11-05.1: N05 노면전차 묶음 131개에서 공식 노선 138개 (data/overrides/n05_fix.json). 1950 전 휴지 5개는 열람 전용. 선형 없는 구간은 표식 (pack map_marker) |
| 666 | L928 | 정류장별 営業キロ가 없으면 노선 길이를 N05 선 위 거리로 나눔, 출처 `N05 겹침 추정` | 구현됨 | T/gen_n05.py:529-557 `estimate_km` |
| 667 | L929 | 무궤조전차(트롤리버스)는 넣지 않음, 立山·関電 터널 트롤리버스만 남김 (v0.51) | 구현됨 | T/gen_extra.py:45-46 TRACKLESS, T/gen_source.py:527. pack line.type trolley 2 |
| 668 | L962 | 옛 노면전차망을 "다음 단계"로 적은 곳 (L962, L1795, L1838, L1881) | 구현됨 | 2026-11-27에 DESIGN §4.2 표, §16 완료 기준, ARCHITECTURE §4.3·§8의 남은 「다음 단계」를 v1.0 수록(판 2026-11-05.1)으로 고침 |
| 669 | L946 | 일부 역의 営業キロ만 모르는 노선도 기록 가능, 노선 km와 분모는 아는 역 사이로 (v0.51) | 구현됨 | route_stop.km_estimated 698행 (CP:606-608, T/gen_source.py:1380-1381), 분모는 edge_km |
| 670 | L947 | `? km`: 노선 상세의 역 km 자리 | 부분 | A/features/record/ui/line_detail_screen.dart:472. 화면은 목업 대조 전 (규칙 5) |
| 671 | L947 | `? km`: 역 선택기의 역 km 자리 | 부분 | SL:194. 화면은 목업 대조 전 (규칙 5) |
| 672 | L947 | `? km`: 기록 목록 RideTile의 승차 km | 부분 | A/features/record/ui/ride_tile.dart:35 (C/network/network.dart:156-160 `kmEstimatedOn`·`kmEstimatedBetween`). 화면은 목업 대조 전 (규칙 5) |
| 673 | L947 | `? km`: 지도 표식 시트, 활동 캘린더, 폐선 컬렉션, 여러 노선 기록의 구간 km | 부분 | A/features/record/ui/map_sheets.dart:132, A/features/stats/ui/activity_screen.dart:95, A/features/stats/ui/collection_screen.dart:169, A/features/record/ui/journey_screen.dart:130 (커밋 28cd52d). 화면은 목업 대조 전 (규칙 5) |
| 674 | L947 | `? km`: 저장 바의 승차 km | 부분 | SB:126, RC:125 `kmEstimated`. 화면은 목업 대조 전 (규칙 5) |
| 675 | L947 | `? km`: 승차권의 승차 km | 부분 | A/features/record/ui/ride_ticket.dart:154. 화면은 목업 대조 전 (규칙 5) |
| 676 | L948 | 좌표가 있으면 앞뒤 km를 아는 역 사이를 선 위 비율로 나눠 안쪽 계산에만 씀 | 구현됨 | T/gen_n05.py:543-550 |
| 677 | L949 | 좌표도 없으면 그 역에서 탄 기록은 다음 km를 아는 역부터 셈 (B→C 0km) | 구현됨 | T/gen_n05.py:551-556 (다음 km를 아는 역 자리에 둠) |
| 678 | L1071 | `판정 불가 n구간`을 통계 화면에 따로 표시 | 부분 | ST:197-202 `t.undecided`, 문구 A/i18n/ko.i18n.json:126. 화면은 목업 대조 전 (규칙 5) |
| 679 | L10 | 날짜별 도달성 검사에 사유를 적은 예외 표 (v0.51) | 구현됨 | data/overrides/invariant_exceptions.json (행마다 why), T/invariants.py:137-138 |
| 680 | L1095 | 사진, GPS 근처 역 버튼은 v1.0에서 뺌 (P2) | 대상 아님 | L1095 |

## 요구가 아니어서 항목에서 뺀 행

문서를 처음부터 다시 훑어 대조했습니다. 아래는 요구가 아니라 사실 기록이나 근거라서 항목으로 세지 않았습니다.

| 행 | 내용 |
|---|---|
| L1~18, L24~25 | 제목과 변경 이력 |
| L57~65 | 두 서비스의 방식 비교. noriori 열이 없는 사실 표 |
| L79, L84 | 노리츠부시 사실. 반영 열은 §4.3, §10 참조뿐이고 §10은 범위 밖 |
| L107~112 | 불리한 점과 추정이라는 단서 |
| L115~131 | 테츠로그 직접 테스트 결과 (사실 기록) |
| L861~863 일부 | 2026-10-30 조사 수치. 목록 작성 요구만 L861로 셈 |
| L898 | 집계의 한계 메모 |
| L900~909 | 노리츠부시 수록 범위 측정과 대조 |
| L912~918 | 다른 서비스의 노면전차 수록 조사 |
| L966~967 | 자료량 측정과 목업 메모 |
| L986~992 | 기준일을 고른 이유 |
| L994~1003 | 측정 근거 |
| L1015 | 다른 서비스 조사 |
| 표 머리글과 구역 제목 | L32, L45, L70, L88, L118, L134, L144~145, L165~166 등 |
