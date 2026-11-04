# noriori DESIGN.md 명세 감사 A: 1행 ~ §7 직전

- 대상: `docs/DESIGN.md` 머리말, §0~§6, v0.42의 §6.1. §7 이후는 범위 밖입니다.
- 판정 시각: 2026-11-02 21시 작업본. 표는 19:36 코드로 만들었고, 그 뒤 `미구현`·`부분`·`미연결` 행을 코드에서 다시 읽어 판정했습니다. `구현됨` 행은 다시 보지 않았습니다. 행 열과 근거 행 번호는 2026-11-04 작업본(DESIGN v0.49)에 맞췄습니다 (`tools/dev/trace_refresh.py`). 뒤에 기호가 없는 근거 번호는 옮김 계산이라 다음 재판정 때 다시 읽습니다.
- 판정 값: 구현됨 / 부분 / 미구현 / 미연결 (코드나 저장소는 있으나 화면에서 부르지 않음) / 문서 오류 / 대상 아님.
- `뼈대라서 나중에`는 사유로 쓰지 않았습니다. P1은 v1.0 범위(L1059, L1757)로 판정했고, P2·서버·배포 단계만 대상 아님입니다.
- 팩 수치는 `build/master.sqlite`, `build/names.sqlite`를 읽기 전용으로 조회했습니다. 이 감사는 앱을 실행하지 않았고 테스트도 돌리지 않았습니다. 화면 항목의 `구현됨`은 코드를 읽어 내린 판정이고, 추적표 규칙 5의 목업 대조는 하지 않았습니다.

## 집계

| 판정 | 항목 수 |
|---|---|
| 구현됨 | 486 |
| 부분 | 35 |
| 미구현 | 44 |
| 미연결 | 0 |
| 문서 오류 | 27 |
| 대상 아님 | 42 |
| **합계** | **635** |

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

### 머리말 (L1~18)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 1 | L15 | 글꼴 Pretendard | 구현됨 | apps/noriori/pubspec.yaml 글꼴 3종, A/main.dart `registerFontLicense` |
| 2 | L15 | 설정에 오픈소스 라이선스 | 구현됨 | A/features/settings/ui/settings_screen.dart `showLicensePage` |
| 3 | L15 | 역 선택기 머리글이 노선을 맡은 회사를 모두 표시 | 구현됨 | RC:362 `operatorName`, C/network/network.dart:190 `operatorsOn` |
| 4 | L18 | 쓰기 DB 하나 + 교체형 데이터 팩 | 구현됨 | S/startup/cold_start.dart:95, C/pack/pack_choice.dart:18 |

### §0 원칙 (L22~34)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 5 | L26 | 코드·데이터·파이프라인 공개 | 부분 | LICENSE·NOTICE·data/LICENSE 있음. 아직 git 저장소 아님. 노리츠부시 유래 데이터는 공개 저장소에 넣기로 정함 (DESIGN §17 목록·km). 공개는 아직 |
| 6 | L26 | 광고·결제 없음 | 구현됨 | apps/noriori/pubspec.yaml 광고·결제 의존성 없음 |
| 7 | L27 | 서버 없이 모든 기능이 기기 안에서 동작 | 구현됨 | 지도 배경과 글자까지 앱에 내장. 온라인 배경을 끊은 빌드로 확인 |
| 8 | L27 | 언제든 서버를 붙일 수 있는 구조 | 구현됨 | S/db/tables.dart:5 `updated_at·deleted_at·device_id`, S/records/record_store.dart:23 단일 쓰기 지점 |
| 9 | L28 | 사실은 모듈별 파일에 한 번만 | 구현됨 | data/source/<모듈>/*.yaml |
| 10 | L28 | 노선 변화는 이벤트로 남김 | 문서 오류 | redesign 4.1 `안 쓰는 이벤트 규범: 문서를 실제 방식으로 고침`. data/source/events 실측 7종뿐 (rename·move·km_change·relocate·set_class 0건). DESIGN §2.2 미갱신 (M12) |
| 11 | L30 | 기록과 지도 분리 | 구현됨 | S/db/tables.dart:50 ride_leg는 노드·계통만 저장, 선형은 rail.pmtiles |
| 12 | L31 | 기록은 역 목록·순서·km가 확정된 것만 | 구현됨 | pack: coverage 766노선 전부 기록 가능 이상 |
| 13 | L31 | 표시는 순서가 명확한 것까지 | 구현됨 | pack: archive_stop 439, archive_line 140. SL:663 `_ArchiveTile` |
| 14 | L31 | 지도는 정밀 위치까지 확인된 것만 | 대상 아님 | redesign 4.1 `역 위치 규칙`: 폐역은 approx도 점 유지. DESIGN §4.7은 미갱신 (모순 M4) |
| 15 | L32 | 웹뷰 금지, 로컬 사전 계산 값 사용 | 구현됨 | webview 의존성 없음. C/score/scorer.dart 판정, pack denominator_unit |
| 16 | L33 | ko/en 동시 지원 | 구현됨 | ko, en, ja. 설정 슬라이드 바, 그 자리 전환 (`languageProvider`). 에뮬레이터에서 확인 |
| 17 | L33 | 일본어 지원 | 구현됨 | 결정됨: 일본어 동시 출시. `ja.i18n.json`, 이름 순서 `japaneseFirst` |
| 18 | L34 | Android 우선, iOS 같은 코드로 병행 | 구현됨 | apps/noriori/android, apps/noriori/ios |

### §0 배포 전략 (L37~43)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 19 | L39 | Android 배포 경로 (Releases → F-Droid → Play) | 대상 아님 | L1771 Phase 4 |
| 20 | L40 | iOS 서명 안 된 IPA 사이드로드 | 대상 아님 | L1771 Phase 4 |
| 21 | L41 | TestFlight | 대상 아님 | L41 "유료 Apple 계정 생기면 추가" |
| 22 | L43 | 화면 표기 소문자 noriori | 구현됨 | A/i18n/ko.i18n.json app.name |

### §1 채택안 (L59)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 23 | L59 | 논리 DB가 기록 기준, 지도 선형은 독립 층, ID로만 참조 | 구현됨 | S/db/tables.dart:50, T/gen_tiles.py |

### §1.1 노리츠부시 구조의 반영 (L64~77)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 24 | L64 | 노선 아래 계통 모듈 | 구현됨 | pack: route 823, 2개 이상 계통을 가진 노선 42개 |
| 25 | L65 | km 축은 계통별 | 구현됨 | pack: route_stop.km_cum, CP:273 |
| 26 | L66 | 날짜 미상·부분 날짜 허용 | 구현됨 | `parseDateInput`이 연대를 받음 |
| 27 | L67 | 폐역은 회색·선택 불가 + `~연도`, 탑승일 기준 판단 | 구현됨 | SL:151 `_note`, SL:180 tier3, C/network/selector.dart:80 |
| 28 | L68 | 운전 계통 검색과 노선별 구간 표시 | 구현됨 | A/features/record/controller/line_search_controller.dart:36-39,51-57, 입력 SS:15-157, 분해 SP:59-96,186-196 |
| 29 | L69 | JR 한 구간 한 노선, 사철 사업자별 집계 | 구현됨 | pack: 代々木–新宿 山手線만, 京成·北総 별도 노선 |
| 30 | L70 | 개업 이력은 open 이벤트 | 구현됨 | data/source/events open 2,631건 |
| 31 | L72 | 기본 승계 + 옵션 | 구현됨 | `carryoverProvider`, 설정 스위치 |
| 32 | L73 | 폐지 단계별로 구분해 표시 | 구현됨 | C/network/display_rules.dart `SectionLine`, SL:682 `~연도 폐지` |
| 33 | L74 | BRT 전환은 폐선 취급 | 구현됨 | pack: 日田彦山線·気仙沼線 close_reason=brt |
| 34 | L75 | 사업자 분류 채택 | 구현됨 | pack: operator.category 8종 |
| 35 | L77 | 기준일 지도(타임 슬라이더) 발상 반영 | 구현됨 | 지도 `연도` 칩, `yearFilter` |
| 36 | L77 | 네이티브 벡터 지도 즉시 반영 | 구현됨 | MH:186 `_repaint`, MS `riddenFilter` |

### §1.2 DB 구조 비교의 noriori 열 (L82~97)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 37 | L82 | (노선, 역, 날짜) → 구간으로 펼침 | 구현됨 | RR:113 `record` |
| 38 | L83 | 진행률 기준 영업km | 구현됨 | C/score/scorer.dart:78 `computeScore` |
| 39 | L84 | 구간·역을 그 자리에서 전환 | 구현됨 | LD:78-86,228 구간 전환, LD:88-113 역 방문 전환, CUT:45-119 |
| 40 | L84 | 일괄 삭제 | 구현됨 | 여정 전체 삭제 A/features/record/controller/trip_controller.dart:72, A/features/record/ui/trip_screens.dart:136,185. 되돌리기 있음 |
| 41 | L85 | 역 신설이 기록에 영향 없음 | 구현됨 | S/db/tables.dart:50 기록은 노드 기준 |
| 42 | L86 | 영업km 개정이 기록에 영향 없음 | 구현됨 | S/db/tables.dart:50 기록은 노드 기준 |
| 43 | L87 | 기본 승계, 끌 수 있음 | 구현됨 | `carryoverProvider`, 설정 스위치 |
| 44 | L88 | 모든 구간·역에 기간 + 3가지 완주율 | 구현됨 | ST:24 `_Kind`, C/score/scorer.dart:57 |
| 45 | L89 | 1950-01-01 이후 국철·JR + 검증된 사철 | 구현됨 | pack 2026-11-04.1: 법적 폐지 기준일 전 0건. N05와 교차 검증한 옛 폐선 74노선(T/gen_n05.py). 옛 노면전차망은 명세가 미룬 다음 단계 |
| 46 | L90 | 한 노선 안에서 폐지 단계별 표시 | 구현됨 | SL:682, C/network/display_rules.dart `SectionLine` |
| 47 | L91 | 계통 + 집계 멤버십 + 운전 계통 | 구현됨 | 계통·멤버십 기존, 운전 계통 입력 SS:15-157, SP:59-96 |
| 48 | L92 | 일·월·연도·연대·모름 + 범위 계산 | 구현됨 | 연대 입력 `198X` |
| 49 | L93 | 선형 오류가 기록에 번지지 않음 | 구현됨 | 기록은 선형을 읽지 않음 C/network/route_resolver.dart |
| 50 | L94 | 공개 파일 + PR + 자동 검증 | 부분 | 공개 전. 검증 스크립트는 있으나 CI 실패로 이어지는 것은 경계 검사뿐 (L311~328) |
| 51 | L95 | 역 방문 단독 기록 | 구현됨 | C/records/record.dart:342 `Visit`, 입력 MP:29-41,70-75와 LD:88-113, 목록 MP:131-165 |
| 52 | L96 | 운전 계통 입력 | 구현됨 | 한 줄 노선도에 줄기·범위 칠하기·역 상태·그날 없는 구간 흐림 A/features/record/ui/service_session_screen.dart:125-130,157-172. 판 선택은 결정으로 빠짐 |
| 53 | L97 | 입력 화면 분기선 표시 | 구현됨 | SL:500 `_BranchTile`, A/features/record/ui/session_painters.dart `BranchPainter`, 설정 켜고 끔 |

### §1.4 노리츠부시 추가 확인의 반영 (L128~133)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 54 | L128 | 기록의 구간도 수정 가능 | 구현됨 | 구간 전환 LD:78-86, 잘라 내기 CUT:45-119. 날짜·메모는 A/features/record/ui/record_edit_screen.dart:82-123 |
| 55 | L129 | 미승 구간 목록 화면 (P1) | 구현됨 | `RemainingScreen` |
| 56 | L130 | 별선·단락선 extra | 구현됨 | pack: extra 노선 25개 |
| 57 | L131 | 열차명 검색 | 대상 아님 | L131 "(P2)", L1059 "P2 이후" |
| 58 | L132 | 운전 계통 + 폐선 한 번에 입력 | 구현됨 | L132 원문이 `탑승일 기준으로 자연히 가능`. 역 선택기가 그날 상태로 현행·폐지 구간을 한 노선에서 고름 C/network/selector.dart:89-133, RR:100-122. 별도 운전 계통 항목은 없음 |
| 59 | L133 | 도도부현별 노선 찾기 (P1) | 미구현 | A/features/record에 도도부현 경로 없음 |

### §1.5 테츠로그에서 가져올 것 (L138~155)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 60 | L139 | 가로 스트립을 노선 상세 상단에 | 구현됨 | LD:298-304 |
| 61 | L140 | 저장 전 미리보기: 구간 수 + km + 노선별 분해 | 구현됨 | `RecordSessionState.split`, 저장 바 |
| 62 | L141 | 출발역 뒤 도착역 목록의 거리 힌트 `+3 stops` | 구현됨 | SL:250-257, RC:195-201 |
| 63 | L142 | 세로 노선도 위 역 검색 | 구현됨 | RS:67~73 |
| 64 | L143 | 노선 카드: 상태색 띠, km·%, 역 수 보조 | 문서 오류 | DESIGN §8.0 위치 띠가 §1.5 색 띠·역 수 보조를 대체 A/features/record/ui/line_tile.dart:90 |
| 65 | L144 | 노선 상세 맨 위 큰 % | 구현됨 | LD:278-290 |
| 66 | L145 | 회사 → 노선 2단 탐색 | 구현됨 | A/app/router.dart `_browse`, BS:194 |
| 67 | L145 | 즐겨찾기 고정 | 미구현 | 코드·저장 없음 |
| 68 | L146 | 3단 표기, 원어 병기 옵션 | 대상 아님 | redesign 4.1 `원어 병기`: 선택기 항상, 로마자 3단 뺌. 지도 옵션 몫은 D2:97 |
| 69 | L147 | 지도 상단 검색창 + % 캡슐 + 필터 칩 | 구현됨 | MH:159~177, MH `_SearchBar` |
| 70 | L148 | 노선 단독 지도 | 구현됨 | 노선 상세 지도 버튼, `soloLineProvider` |
| 71 | L149 | 우측 버튼: 현재 위치 | 대상 아님 | 2026-11-03 결정: 뺌 |
| 72 | L149 | 우측 버튼: 근처 역 | 대상 아님 | 2026-11-03 결정: 뺌 |
| 73 | L149 | 우측 버튼: 지도 종류 | 대상 아님 | redesign 4.4 #1 지도 버튼과 근처 역 뺌 |
| 74 | L149 | 우측 버튼: 표시 설정 | 대상 아님 | redesign 4.4 #1 지도 버튼과 근처 역 뺌 |
| 75 | L150 | 축하 카드: 도장 + 마스코트 + 공유 | 구현됨 | `showCompleteCard`. 마스코트는 v1.0 뒤 |
| 76 | L151 | 빈 화면 안내 | 구현됨 | A/features/record/ui/record_list_screen.dart:38, ST:175 |
| 77 | L152 | 차량 도감 | 대상 아님 | L152 "(P2)" |
| 78 | L153 | 첫 기록 안내 카드 | 구현됨 | A/features/record/ui/continue_sheet.dart:88 |
| 79 | L154 | 역 기록 시트 (메모, 사진 3장, 탄 차량, P1) | 대상 아님 | 2026-11-03 결정: 사진 뺌 |
| 80 | L155 | 곁들임 정보 | 대상 아님 | L155 "(P2)" |

### §1.5 따라 하지 않을 것 (L160~164)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 81 | L160 | 닫기 없는 축하 시트를 쓰지 않음 | 구현됨 | 축하 시트 자체가 없음. 승차권은 5초 뒤 사라짐 A/features/record/ui/ride_ticket.dart:29 |
| 82 | L161 | 저장 직후 평점 요청 안 함 | 구현됨 | 평점 요청 코드 없음 |
| 83 | L162 | 역 단위 저장 안 함 | 구현됨 | S/db/tables.dart:50 구간 단위 |
| 84 | L162 | 일괄 삭제 없음을 따라 하지 않음 | 구현됨 | 여러 개 선택 삭제 A/features/record/ui/record_list_screen.dart:40-46,67-87. 남은 여정 전체는 L1065 행 |
| 85 | L163 | 지선을 한 줄로 합치지 않음 | 구현됨 | RS:104 계통 칩으로 분리 |
| 86 | L164 | 역 수 기준 진행률·선형 km 안 씀 | 구현됨 | C/score/scorer.dart:78 영업km 기준 |

### §2.1 모듈 구성 (L173~206)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 87 | L173 | nodes | 구현됨 | data/source/nodes |
| 88 | L174 | groups | 구현됨 | data/source/groups |
| 89 | L175 | redirects | 미구현 | data/source/redirects 없음. pack id_redirect 0행 |
| 90 | L176 | operators | 구현됨 | data/source/operators |
| 91 | L177 | lines | 구현됨 | data/source/lines |
| 92 | L178 | routes | 구현됨 | data/source/routes |
| 93 | L179 | services | 구현됨 | data/source/services (17) |
| 94 | L180 | edges (seed_line, route_only) | 구현됨 | data/source/edges |
| 95 | L181 | events | 구현됨 | data/source/events |
| 96 | L182 | hubs | 구현됨 | data/source/hubs |
| 97 | L183 | junctions | 구현됨 | data/source/junctions |
| 98 | L184 | lineage | 문서 오류 | 사슬은 transfer에서 컴파일, 고정 ID는 선택(§2.9). 사슬 ID는 기록에 저장 안 함(§2.10) |
| 99 | L185 | archive | 구현됨 | data/source/archive |
| 100 | L203 | km | 구현됨 | data/source/km |
| 101 | L204 | positions | 구현됨 | data/source/positions |
| 102 | L205 | geometry | 구현됨 | data/source/geometry |
| 103 | L206 | names | 구현됨 | data/source/names |
| 104 | L191 | staging | 미구현 | data/source/staging 없음 |
| 105 | L192 | checks (intentional_gap 등) | 미구현 | data/source/checks 없음 |

### §2.1 변경 번짐 표 (L200~213)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 106 | L200 | 뼈대 추가·분할은 §2.10 도구로 | 미구현 | 도구 없음 (L713~716) |
| 107 | L201 | routes → route_edge·route_stop·route_link | 구현됨 | CP:197~273, CP:433~506 |
| 108 | L202 | events → edge_attr·route_*·denominator | 구현됨 | CP:121~188, CP:311~340 |
| 109 | L203 | km → denominator·closed_section | 구현됨 | CP:311~340, CP:608~613 |
| 110 | L204 | 환승 후보 거리 300m | 문서 오류 | L784은 350m, 구현도 350m CP:437 `hav_km(a,b)<.35` |
| 111 | L205 | geometry → 품질·커버리지·도도부현 경계 km | 부분 | 품질·커버리지 있음 CP:582, CP:569. 경계 km는 선형에서 구하지 않음 CP:614~619 |
| 112 | L206 | 파이프라인의 조인 키로 이름을 쓰지 않음 | 부분 | 이름 키 사용: CP:434~438 HUBNOT·HUBX, T/gen_wiki.py:202 NOCONT, T/gen_source.py:100 RENAME |
| 113 | L207 | hubs·junctions → route_link | 구현됨 | CP:433~506 |
| 114 | L208 | lineage → 이름 병기 | 구현됨 | pack lineage_id, C/network/display_rules.dart `_chained`, SL:548 |
| 115 | L209 | archive는 표시만, 기록·통계·지도 무영향 | 구현됨 | S/pack/pack_reader.dart:209 표시용만 읽음. network_reader는 안 읽음 |
| 116 | L211 | 선로·정차·귀속·이름의 시간은 events/에만 | 문서 오류 | 이름 기간은 names, 역 기간은 overrides가 실제 구조 (§2.12 사람이 고친 값). §2.1 문구 낡음 (M12) |
| 117 | L212 | 변경 유형별 도구와 체크리스트 | 미구현 | T/에 해당 도구 없음 |
| 118 | L213 | 선형이 없어도 기록·통계 계산 | 구현됨 | 기록 가능 173노선, 계산은 km만 사용 |

### §2.2 이벤트 종류 (L216~228)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 119 | L216 | edge는 역대 모든 노드로 가장 잘게 나눔 | 구현됨 | data/source/events open_stop 3,269건, 역 변화가 edge 수를 안 바꿈 |
| 120 | L220 | open: operator·line 필수, 멤버십 생성 | 구현됨 | CP:123~137 |
| 121 | L220 | open의 class 선택 필드 | 구현됨 | CP:136, 사용 73건 |
| 122 | L220 | close: line 필수, last_service·legal_abolition 별도 | 구현됨 | CP:138~143, CP:120 |
| 123 | L221 | suspend / resume | 구현됨 | CP:171~178, 64·36건 |
| 124 | L222 | open_stop / close_stop | 구현됨 | CP:183, 3,269·184건 |
| 125 | L223 | transfer from+to | 구현됨 | CP:144~163, 307건 |
| 126 | L223 | transfer `to`만 (사업자 추가) | 문서 오류 | redesign 4.1 `안 쓰는 이벤트 규범: 문서를 실제 방식으로 고침`. data/source/events 실측 7종뿐 (rename·move·km_change·relocate·set_class 0건). DESIGN §2.2 미갱신 (M12) |
| 127 | L223 | transfer `from`만 (사업자 철수) | 문서 오류 | redesign 4.1 `안 쓰는 이벤트 규범: 문서를 실제 방식으로 고침`. data/source/events 실측 7종뿐 (rename·move·km_change·relocate·set_class 0건). DESIGN §2.2 미갱신 (M12) |
| 128 | L224 | relocate | 문서 오류 | redesign 4.1 `안 쓰는 이벤트 규범: 문서를 실제 방식으로 고침`. data/source/events 실측 7종뿐 (rename·move·km_change·relocate·set_class 0건). DESIGN §2.2 미갱신 (M12) |
| 129 | L225 | rename 이벤트 | 문서 오류 | redesign 4.1 `안 쓰는 이벤트 규범: 문서를 실제 방식으로 고침`. data/source/events 실측 7종뿐 (rename·move·km_change·relocate·set_class 0건). DESIGN §2.2 미갱신 (M12) |
| 130 | L226 | move 이벤트 (좌표에 날짜) | 문서 오류 | redesign 4.1 `안 쓰는 이벤트 규범: 문서를 실제 방식으로 고침`. data/source/events 실측 7종뿐 (rename·move·km_change·relocate·set_class 0건). DESIGN §2.2 미갱신 (M12) |
| 131 | L227 | km_change 이벤트 | 문서 오류 | redesign 4.1 `안 쓰는 이벤트 규범: 문서를 실제 방식으로 고침`. data/source/events 실측 7종뿐 (rename·move·km_change·relocate·set_class 0건). DESIGN §2.2 미갱신 (M12) |
| 132 | L228 | set_class | 구현됨 | CP:179. 데이터 0건 (class는 open의 73건으로 들어감) |
| 133 | L230 | seed_line 불변 | 구현됨 | CP:66, data/source/edges |
| 134 | L234 | a..b: open은 seed_line | 구현됨 | CP:124 |
| 135 | L235 | a..b: close·set_class는 전날 멤버십 | 구현됨 | CP:139, CP:180 |
| 136 | L236 | a..b: transfer는 from.line 멤버십 | 구현됨 | CP:146~147 |
| 137 | L237 | a..b: to만이면 within | 구현됨 | CP:146 |
| 138 | L239 | 같은 날 이벤트는 모두 전날 기준 | 부분 | CP:40 정렬 뒤 순서대로 현재 active를 봄. 전날 상태를 고정하지 않음 |

### §2.2 규범 규칙 (L244~256)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 139 | L244 | 기간은 [from,to), valid_to는 마지막 운행 다음 날, JST | 구현됨 | pack: 札沼線 valid_to 2020-04-18. C/date/date_rules.dart:39 |
| 140 | L245 | 마지막 운행일과 법적 폐지일 분리 | 구현됨 | pack: 札沼線 last_service 04-17, legal 05-07 |
| 141 | L246 | BRT는 운행 첫날 close | 구현됨 | pack: 気仙沼線 2012-08-20, 日田彦山線 2023-08-28 |
| 142 | L247 | 정기 여객 없는 구간 close | 구현됨 | pack: 海峡線 no_regular_service 2016-03-26 |
| 143 | L248 | 재해 불통은 폐지 신고까지 suspend | 구현됨 | pack: 岩泉線 suspended 2010-08-01~2014-04-01, last_service 2010-07-31 |
| 144 | L249 | 이설은 relocate (吾妻, 常磐, 仙石, 菊池, 石巻) | 문서 오류 | 菊池線 연장은 §17 `근사 처리 3건`으로 정리됨. §2.2 예시 낡음 |
| 145 | L250 | 역 위치 이동: km 같으면 move, 다르면 노드 둘 + moved | 문서 오류 | redesign 4.1 `안 쓰는 이벤트 규범: 문서를 실제 방식으로 고침`. data/source/events 실측 7종뿐 (rename·move·km_change·relocate·set_class 0건). DESIGN §2.2 미갱신 (M12) |
| 146 | L252 | 사업자만 바뀜은 같은 line에 transfer | 부분 | 국철→JR 구현. 사철 합병 미표현: 松戸線은 처음부터 o_keisei_electric_railway 한 사업자 |
| 147 | L253 | 노선이 바뀌면 새 line + transfer | 부분 | 3섹 전환 구현. 리아스선 통합은 40100 단일 노선으로 미표현 |
| 148 | L254 | 이름만 바뀌면 rename | 문서 오류 | redesign 4.1 `안 쓰는 이벤트 규범: 문서를 실제 방식으로 고침`. data/source/events 실측 7종뿐 (rename·move·km_change·relocate·set_class 0건). DESIGN §2.2 미갱신 (M12) |
| 149 | L255 | 운휴를 거친 이관 (도야마항선) | 구현됨 | pack: 2006-03-01~04-29 suspended 후 open, lineage 유지 |
| 150 | L256 | 역↔신호장: close_stop, node.kind는 최근 종류 | 문서 오류 | node.kind는 화면에 안 나옴. 공개는 node_public 기준이라 楓·東追分 동작 동일 |

### §2.3 예시 (L259~283)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 151 | L259 | 삿쇼선 두 번의 폐지, 로이즈타운 정차 | 구현됨 | pack: 1972-06-19, 2020-05-07, n_royce_town 2022-03-12 |
| 152 | L272 | 신에츠 → 시나노철도 1997-10-01 | 구현됨 | pack: lineage lg336 유지, carryover 새 값 |
| 153 | L275 | 나리타 스카이 같은 선로에 사업자 추가 | 문서 오류 | 동시 멤버십 0개 pack 실측. ARCH §7.2 `DESIGN §2.7·§14 문구 정리`가 남은 일 (M13) |
| 154 | L280 | 아가츠마선 이설 2014-10-01 | 구현됨 | pack: 옛 edge relocated, 새 edge 이어짐 |

### §2.4 신호장·화물역 (L288~295)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 155 | L288 | 신호장·분기점·화물역은 내부 전용 | 구현됨 | pack: 숨은 노드 18 (signal 4, junction 11, freight 3) |
| 156 | L290 | 빌드 시 숨은 노드 이름 제거, 색인 제외 | 구현됨 | CP:653, CP:677. pack 숨은 노드 이름 0행 |
| 157 | L291 | 앱은 node_public만 사용 | 부분 | T/compile.py에 sys.exit 없음, ERR는 report.json에만. data.yml은 check_boundaries, all.sh, core_fixture, sync_pack. audit_db·invariants·appsim·model_check 미실행. T/check_boundaries.py에 node 규칙 없음 |
| 158 | L291 | 역이었던 신호장은 폐역으로만 표시 | 구현됨 | pack: 楓 2004-03-13, 東追分 2016-03-26 정차 종료 |
| 159 | L292 | 정차는 (계통, 노드) 단위 | 구현됨 | pack: 船町·下地는 r_iida_line만 |
| 160 | L293 | UI가 원본 node를 읽으면 CI 실패 | 미구현 | T/check_boundaries.py에 없음 |
| 161 | L294 | 노선도·선택기·지도·통계에 안 나옴 | 구현됨 | C/network/selector.dart:106, T/gen_tiles.py `node_public` |
| 162 | L295 | 호환판 CSV 경계에 export_name 사용 | 구현됨 | S/pack/pack_reader.dart:120-125가 export_name을 일본어 이름 표에 넣음, 숨은 노드 18행은 ja 이름이 없어 이 값이 쓰임 (names 조회), C/importing/csv_export.dart:117 |

### §2.5 사업자 분류 (L298~299)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 163 | L298 | operator.category 8종 유지 | 구현됨 | pack operator |
| 164 | L299 | 지도는 분류와 무관하게 같은 색 | 구현됨 | MS 층 색은 토큰뿐 |
| 165 | L299 | 통계: 전체·사업자별·노선별·도도부현별 | 구현됨 | ST:215~218 |

### §2.6 빌드와 검증 (L303~328)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 166 | L303 | events + 뼈대 → master.sqlite | 구현됨 | CP |
| 167 | L304 | km → 거리 테이블 | 구현됨 | CP:584 |
| 168 | L305 | positions/geometry → rail.pmtiles | 구현됨 | T/gen_tiles.py |
| 169 | L307 | names → names.sqlite (공개 노드만) | 구현됨 | CP:651~684 |
| 170 | L309 | CI 검사는 네트워크 없이 | 구현됨 | T/all.sh 생성·컴파일·검증에 네트워크 없음 |
| 171 | L309 | 결과는 coverage.json과 빌드 리포트 | 문서 오류 | 결과물은 build/report.json. coverage는 master 표. §2.6 파일 이름 낡음 |
| 172 | L309 | 문서 수치는 리포트에서 | 구현됨 | T/status.py → docs/db-status.md |
| 173 | L318 | 위상 검사 + intentional_gap | 부분 | T/audit_db.py:241 조각 수 계산뿐, CI 밖. 예외 파일 없음 |
| 174 | L319 | 날짜 정합성, 범위는 양 끝 검사 | 부분 | T/audit_db.py:46, CI 밖. 양 끝 검사 없음 |
| 175 | L320 | 수록 등급 조건 못 채우면 실패 | 부분 | CP:639 등급 계산뿐, 실패 없음 |
| 176 | L321 | 귀속 검사 | 부분 | CP:520~527 ERR에 넣지만 CP:686~690 종료 코드 없음. WF도 report.errors를 안 봄. 지금 오류는 0건 |
| 177 | L322 | 계통 끝 노드 검사 | 부분 | T/audit_db.py:171, CI 밖 |
| 178 | L323 | 거리: 사업자 합계를 공표 값과 대조 | 부분 | JR 도카이 1,970.8 일치. 자동 대조 없음, route_km 경고 10건 CP:215 |
| 179 | L324 | 역 순서 출처끼리 대조 | 부분 | T/audit_ext.py:29, CI 밖 |
| 180 | L325 | 이름 검사 | 부분 | 역·노선 한글과 일본어 글자 금지 CP:533~541. 사업자·source 검사 없음, 실패로 안 이어짐 |
| 181 | L326 | ID: ids.lock 대조 | 미구현 | ids.lock 파일 없음 |
| 182 | L327 | 라이선스: 파일별 허용 출처 검사 | 미구현 | T/에 없음 |
| 183 | L328 | 회귀: 옛 판 고정 기록 재해석 비교 | 미구현 | T/에 없음 |

### §2.7 세 개념과 계통 파일 (L335~358)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 184 | L335 | 노선이 통계·완주 단위 | 구현됨 | C/score/scorer.dart:115 |
| 185 | L336 | 계통은 고유 km 축 | 구현됨 | pack route_stop |
| 186 | L337 | edge는 노선당 1개, 공동 구간은 멤버십 여럿 | 문서 오류 | 동시 멤버십 0개 pack 실측. ARCH §7.2 `DESIGN §2.7·§14 문구 정리`가 남은 일 (M13) |
| 187 | L336 | 千歳線 본선·공항지선 | 구현됨 | pack: r_chitose_line, r_chitose_line_minami_chitose_new_chitose_airport |
| 188 | L336 | 函館本線 본선·砂原支線 | 구현됨 | pack: r_hakodate_main_line, r_hakodate_main_line_onuma_mori |
| 189 | L354 | 東海道 美濃赤坂 계통 자기 edge | 구현됨 | pack: r_tokaido_main_line_ogaki_mino_akasaka, 5.0km |
| 190 | L349 | 犬山線 기점 숨은 노드 + extend_to | 구현됨 | pack: n_biwajima_junction, extend_to n_higashi_biwajima |
| 191 | L353 | 각 시점의 노선 부분 그래프로 경로, route_edge에 기간 | 대상 아님 | DESIGN §14.1 `v1에서 뺀 것` route_edge 기간 |
| 192 | L354 | 공식 km가 따로 있는 계통은 route_only | 구현됨 | pack: route_only edge 333개 |
| 193 | L354 | 본선 기록은 route_only 계통을 채우지 않음 | 구현됨 | pack: 별도 edge |
| 194 | L355 | 노선 집계가 계통으로 겹침·빠짐 없이 나뉘는지 CI | 부분 | T/audit_db.py:171, CI 밖 |
| 195 | L356 | 계통 파일은 기점·종점만, 폐지는 빌드가 처리 | 구현됨 | data/source/routes, CP:197~212 |
| 196 | L357 | extend_to 선택기 표시, km 미표시, 저장 시 계통 분할 | 구현됨 | pack is_extension 24행, RR:124 `expandAny`, RR:470 |
| 197 | L358 | closed 계통, 같은 역 두 번 | 구현됨 | pack: closed 5, 都庁前 seq 0·28 |
| 198 | L358 | closed 계통은 via 필수 | 부분 | pack: 5개 전부 via_nodes `[]` |
| 199 | L358 | 순환 입력 | 구현됨 | RC:587 `asksLap`, RC:590 `pickLap`, SL:82~105, SB:180~189 |
| 200 | L358 | 시대에 따라 닫히는 계통 closed_from | 문서 오류 | closed_from 사례 0행. 시대 차이는 service 기간으로 처리(s_meijo_loop 2004~). 지금 쓸 데이터 없음 |

### §2.7 지선 유형별 처리 (L363~367)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 201 | L363 | 역에서 갈라지는 지선 | 구현됨 | pack: 南千歳가 두 계통에 나타남 |
| 202 | L364 | 역이 아닌 분기점은 숨은 노드 + extend_to | 구현됨 | pack: junction 11, extend_to 17계통 |
| 203 | L365 | 병행 경로는 계통 ID를 저장 | 구현됨 | S/db/tables.dart:57, RC:623 |
| 204 | L366 | 중간 폐지 노선은 계통 하나, 폐지 구간 3단계 | 구현됨 | pack r_nemuro_main_line 하나, SL:180 tier3, SL:20 `tail` |
| 205 | L367 | 겹치는 구간은 그 노선 계통에 안 넣음 | 구현됨 | pack: 代々木–新宿 e_000654는 山手線만 |

### §2.7 중복 구간 (L371~392)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 206 | L371 | 기록은 (기록한 노선, edge)에만 붙음 | 구현됨 | C/network/network.dart:254 `unitOf` |
| 207 | L375 | 지도는 물리 edge 기준으로 파랑 | 문서 오류 | 동시 멤버십 0개 pack 실측. ARCH §7.2 `DESIGN §2.7·§14 문구 정리`가 남은 일 (M13) |
| 208 | L376 | 통계는 기록한 노선에만 크레딧 | 구현됨 | RI:65 |
| 209 | L379 | JR은 한 구간 한 노선 | 구현됨 | pack: 東京–神田 東北本線, 代々木–新宿 山手線 |
| 210 | L380 | JR 예외 4곳은 두 노선 집계 | 구현됨 | pack: 4곳 모두 양쪽 분모. 별도 edge로 표현 |
| 211 | L381 | 사철 공동 구간은 사업자별 집계 | 구현됨 | pack: 京成 成田空港線·北総線 각각, 사업자별 노선 |
| 212 | L382 | 같은 사업자 중복은 공식 소속 노선 하나 | 구현됨 | pack: 梅田–十三은 宝塚本線, 京都本線 기점 十三 |
| 213 | L382 | `梅田→淡路` 입력을 운전 계통으로 | 미구현 | 운전 계통 입력은 됨 SS:15-157. `梅田→淡路`에 맞는 service가 없음 (master.service 17행) |
| 214 | L387 | 中央線 쾌속 東京→新宿 분해 크레딧 | 구현됨 | s_chuo_rapid SP:59-96, 요약 SP:186-196, 저장 뒤 legs로 크레딧 RI:62-80. 시험 apps/noriori/test/line_detail_test.dart:304 |
| 215 | L388 | 山手線 代々木→新宿 크레딧 | 구현됨 | pack e_000654, 분모 l_yamanote_line |
| 216 | L389 | 中央本線 金山→名古屋는 中央本線만 | 구현됨 | pack: e_000890은 中央本線 |
| 217 | L390 | 京成 스카이라이너는 京成만 | 구현됨 | pack: 별도 edge·노선 |
| 218 | L392 | 입력 화면에 분해 결과 표시 | 구현됨 | SS:130-140 운전 계통 입력 화면 하단 요약. 일반 역 선택기는 L140 행 |

### §2.7 운전 계통 (L395~412)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 219 | L395 | 통칭으로 입력하고 저장 시 공식 노선으로 쪼갬 | 구현됨 | SP:59-96, SC:208-224 |
| 220 | L399 | service closed 필드 | 구현됨 | pack service.closed (3개 1) |
| 221 | L400 | parts는 공식 계통 구간의 이음 | 구현됨 | pack service_part: s_chuo_rapid 4구간 |
| 222 | L405 | stops 필드 | 대상 아님 | DESIGN §14.1 `v1에서 뺀 것` service_stop. 생략이면 모든 정차역 (§2.7) |
| 223 | L407 | 운전 계통은 통계 단위 아님 | 구현됨 | ride_edge가 service를 안 봄 |
| 224 | L407 | 시대별 날짜 판 | 대상 아님 | redesign 4.1 `옛 판·노면전차 계통: v1.0 뒤` |
| 225 | L407 | 날짜 모름이고 판이 여럿이면 고르게 함 | 대상 아님 | redesign 4.1 `옛 판·노면전차 계통: v1.0 뒤` |
| 226 | L408 | parts는 노선이 아니라 계통을 가리킴 | 구현됨 | pack service_part.route_id |
| 227 | L409 | 쇼난신주쿠는 service 2개 | 구현됨 | pack: s_shonan_shinjuku_ty·ys |
| 228 | L410 | 야마노테 일주는 closed service | 구현됨 | pack: s_yamanote_loop |
| 229 | L411 | 검색에서 공식 노선과 운전 계통을 함께 표시 | 구현됨 | 색인 34행 CP:677, A/features/record/controller/line_search_controller.dart:36-39,51-57, A/features/record/ui/line_search_screen.dart:20-26,55 |
| 230 | L411 | 기록에 service_id를 남겨 "○○로 탑승" 표시 | 구현됨 | `viaService`, `record_queries.dart` 목록 |
| 231 | L412 | 노선 계통에는 집계 edge만 | 구현됨 | pack: 中央本線 3계통 |

### §2.7 화면 (L415~417)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 232 | L415 | 노선 상세: 계통별 세로 노선도, 연결 표시 | 구현됨 | A/app/router.dart:46-49, LD:217-242 계통별 세로 노선도, 계통 칩 LD:309-319, 연결 단추 LD:431-437, DG:85-195 |
| 233 | L416 | 선택기 계통 칩, 하나면 칩 없음 | 구현됨 | RS:104 |
| 234 | L417 | 통계: 노선 합산 + 노선 상세의 계통별 진행률 | 구현됨 | 노선 합산 ST:225-231, 계통별 LD:320 |

### §2.8 A·B (L423~436)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 235 | L423 | events는 현실 변화만 | 구현됨 | data/source/events (rename·정정 사건 없음) |
| 236 | L424 | ID를 합치거나 없앨 때 redirects | 미구현 | L175와 같음 |
| 237 | L429 | node가 기록의 출발·도착 | 구현됨 | S/db/tables.dart:58~59 |
| 238 | L430 | group: 방문 역 수, 지도 역 점, 역 방문 기록 | 구현됨 | 지도 점 T/gen_tiles.py:36-45, 방문 역 수 ST:127-128, C/network/station_state.dart:25-41, 방문은 묶음으로 판정 LD:91-96 |
| 239 | L431 | hub는 기록 화면 환승 표시 | 구현됨 | CP:439, SL:250 |
| 240 | L433 | hub가 group을 대체하지 않음 | 구현됨 | pack: 姫路 g_himeji, 山陽姫路 g_sanyo_himeji, 같은 hub_himeji |
| 241 | L434 | 공동 사용역은 노드 하나에 노선별 이름 | 구현됨 | pack name.line_id 218행, S/pack/pack_reader.dart:95 |
| 242 | L435 | 사업자가 다르면 별도 node + 같은 group + hub | 구현됨 | pack: n_fukui·n_fukui_echizen, hub_fukui |
| 243 | L436 | 방문 화면에서 group 안 node 지정 | 부분 | 노선 상세는 그 노선의 node로 남김 LD:106-111, 지도 시트는 타일의 대표 node MP:35-40. 묶음 안에서 고르는 화면은 없음 |

### §2.8 C (L439~449)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 244 | L439 | km는 구간별 값 하나, 바뀌면 km_change, 누적은 빌드 | 문서 오류 | 해당 사례 0건 (km_change, 등급 섞인 단위, 같은 edge 재개). 규칙은 있으나 팩에 대상 없음 |
| 245 | L440 | 자료의 누적 km를 구간 길이로 저장 | 구현됨 | T/gen_source.py |
| 246 | L441 | 경계 노드 km 필수 CI | 부분 | CP:10 ERR 기록, 종료 코드 없음 |
| 247 | L445 | 현행 분모 km는 지금 | 구현됨 | edge_km |
| 248 | L446 | 역대 분모 km는 종료 직전 | 구현됨 | edge_km (단일 값) |
| 249 | L447 | 특정 연도 km는 그해 마지막 영업일 | 대상 아님 | DESIGN §14.1 `v1에서 뺀 것` edge_km 기간. km_change 0건 |
| 250 | L448 | 탑승 거리 km는 탑승일 | 대상 아님 | DESIGN §14.1 `v1에서 뺀 것` edge_km 기간. km_change 0건 |
| 251 | L449 | 입력 화면 km는 고른 탑승일 | 대상 아님 | DESIGN §14.1 `v1에서 뺀 것` edge_km 기간. km_change 0건 |

### §2.8 D (L452~456)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 252 | L452 | 펼침은 탑승일의 선로망 | 구현됨 | RR:216~230 `edgeUsable(… day)` |
| 253 | L453 | route_id 항상 저장 | 구현됨 | RC:623 |
| 254 | L454 | 날짜 몰라 경로가 둘이면 저장 시 물음, 날짜로 저장 | 구현됨 | SB:81, RC:674 asOf |
| 255 | L454 | 답 형식 옛 선로 / 새 선로 / 모름 | 구현됨 | `relocationLabel`이 옛 선로/새 선로, 모름은 구간마다 |
| 256 | L455 | 모름이면 resolve_unknown, partial, 공통 구간만 크레딧 | 구현됨 | RR:236~250, RC 저장 |
| 257 | L456 | 펼친 결과는 캐시, 데이터 바뀌면 재계산 | 구현됨 | S/records/cache_rebuild.dart |

### §2.8 E (L459~474)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 258 | L459 | transfer는 선로를 닫지 않음, lineage 유지·비어 있지 않음 | 구현됨 | CP:144~163, audit lineage 비어 있음 0건 |
| 259 | L460 | 승계 켬: (lineage, edge), 지금 노선 이름으로 표시 | 구현됨 | 승계 끔 켜기, 유효 날짜 양쪽 교집합, 변경 내역 트랜잭션·날짜·빌드, 판 번호 수 비교, 역대 표 지금 노선 이름 (공개 전 검토) |
| 260 | L461 | 승계 끔: (carryover_group, edge) | 구현됨 | 설정 스위치 A/features/settings/ui/settings_screen.dart:97-101, carryoverProvider A/app/session_providers.dart:233, 모든 집계가 이 값을 씀. 팩 분모 off 33,161.8km를 시나리오로 확인. 단 AR:L237의 켜기 결함 있음 |
| 261 | L462 | 두 방식 분모 미리 계산, 설정 즉시 반영 | 구현됨 | 설정 스위치 A/features/settings/ui/settings_screen.dart:97-101, carryoverProvider A/app/session_providers.dart:233, 모든 집계가 이 값을 씀. 팩 분모 off 33,161.8km를 시나리오로 확인. 단 AR:L237의 켜기 결함 있음 |
| 262 | L463 | 멤버십 여럿이면 기록한 노선 lineage만 | 구현됨 | C/network/network.dart:178 |
| 263 | L467 | open: 새 사슬, 새 값 | 구현됨 | CP:106~109 |
| 264 | L468 | 국철·JR → 타사: lineage 유지, carryover 새 값 | 구현됨 | CP:157 |
| 265 | L469 | 그 밖 이관: 둘 다 유지 | 구현됨 | CP:157 |
| 266 | L470 | to만: 새 사슬, 새 값 | 구현됨 | CP:159~160 |
| 267 | L471 | from만: 그 행 종료 | 구현됨 | CP:150~153 |
| 268 | L472 | open + continues | 구현됨 | CP:126~135. 데이터 0건 |
| 269 | L474 | o_japanese_national_railways 분류는 jr | 구현됨 | pack operator |

### §2.8 F·G·H (L477~485)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 270 | L477 | 같은 노선 안 계통을 넘어 경로 자동 탐색 (지선 역 → 본선 역) | 구현됨 | C/network/route_resolver.dart:510 across, A/features/record/controller/record_session_controller.dart:419,670-671. 新千歳空港→白石 2구간 40.8km 실행 확인 |
| 271 | L478 | 숨은 노드 경계 자동 분할, 화면 분해 표시 | 구현됨 | `RecordSessionState.split`, 저장 바 |
| 272 | L481 | 순환 계통 방향 저장, 한 바퀴 leg | 구현됨 | RC:628, RR:268 |
| 273 | L481 | 두 바퀴 이상은 leg를 바퀴 수만큼 | 구현됨 | 고리에도 횟수와 두 방향 |
| 274 | L484 | 운전 계통 기록은 저장 시 분해 | 구현됨 | SP:59-96이 공식 구간 legs로 나눔, SC:208-224, `service_id`는 표시용 SP:170 |
| 275 | L485 | 탑승일에 맞는 운전 계통 판 선택 | 구현됨 | `usable`, `openOn`을 화면이 씀 (service_session_controller) |

### §2.8 I (L488~494)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 276 | L488 | 기록은 ride + legs 묶음 | 구현됨 | S/records/record_store.dart `_writeRide` |
| 277 | L489 | 삭제·되살리기도 updated_at | 구현됨 | S/records/record_store.dart:23, C/records/change.dart |
| 278 | L490 | 구간 끄기는 기록을 고침 | 구현됨 | CUT:45-119, LC:71-114 |
| 279 | L491 | 데이터 변경 시 변경 내역 표시 | 구현됨 | `CacheRebuild`가 변경 내역을 남기고 앱을 열 때 보여 줌 |
| 280 | L492 | 없는 ID는 unknown_ref, 갱신 안내 | 부분 | 상태값 RR:137. 갱신 안내 없음, 목록 배지 `확인 필요`뿐 |
| 281 | L493 | CSV 행은 UUIDv5 고정 ID | 구현됨 | S/records/content_id.dart, C/importing/csv_import.dart:233 |
| 282 | L494 | 같은 (날짜, 경로, 시각) 중복 후보 표시 | 미구현 | L1607 "아직 없는 것: 중복 후보 표시" |

### §2.8 J (L497~506)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 283 | L497 | 연도 분모: 그해 하루라도 영업, 불통 포함 | 구현됨 | C/score/scorer.dart:57 |
| 284 | L497 | 이설 해에 분모가 커지는 이유를 화면에 설명 | 미구현 | A/features/stats에 없음 |
| 285 | L498 | 연도 분자: 유효 범위 끝이 Y년 말 이전 | 구현됨 | C/score/scorer.dart:71 |
| 286 | L499 | 유효 날짜 범위 계산, 날짜 없으면 등록일 상한 | 구현됨 | 승계 끔 켜기, 유효 날짜 양쪽 교집합, 변경 내역 트랜잭션·날짜·빌드, 판 번호 수 비교, 역대 표 지금 노선 이름 (공개 전 검토) |
| 287 | L504 | 교집합이 비면 날짜 모름, 입력값 보존 | 구현됨 | 승계 끔 켜기, 유효 날짜 양쪽 교집합, 변경 내역 트랜잭션·날짜·빌드, 판 번호 수 비교, 역대 표 지금 노선 이름 (공개 전 검토) |
| 288 | L505 | 저장·날짜 수정 때 line·route를 멤버십에 맞춤 | 구현됨 | 저장 RR:449 `_align`, 날짜 수정 A/features/record/ui/record_edit_screen.dart:103-116도 같은 해석 RI:43 |
| 289 | L506 | 현행 분모는 실행 시 오늘로 선택, 100% 안 넘음 | 구현됨 | C/score/scorer.dart:57, A/app/session_providers.dart `todayProvider` |

### §2.8 K·L (L509~514)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 290 | L509 | 도도부현 경계 pref_boundary 노드 + km | 부분 | pack pref_boundary 0개. 경계 edge는 반씩 CP:617 |
| 291 | L510 | 경계 km를 선형으로 구해 값으로 저장 | 미구현 | CP:614~619 선형을 쓰지 않음 |
| 292 | L510 | 선형 없는 노선은 반씩 + "근사" 표시 | 부분 | 반씩 있음(238 edge). approx를 Dart가 읽지 않아 표시 없음 S/pack/network_reader.dart:48 |
| 293 | L513 | 전체 지도는 어느 노선으로든 탔으면 파랑 | 구현됨 | MH:27, S/records/record_queries.dart `watchRiddenEdges` |
| 294 | L514 | 미승 구간만 보기: (노선, 구간) 크레딧 기준. v0.41에서 `승차만` 보기로 바뀜 | 구현됨 | DESIGN v0.41 L518 `승차만` 보기가 이 기능을 대체. MH:141-146,161-167. 탄 선과 지나간 역만 남김 |
| 295 | L514 | 노선 단독 보기: 크레딧 기준 | 구현됨 | `soloLine`의 크레딧 기준 |

### §2.8 M (L518~521)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 296 | L518 | 승하차역 = alighted 끝 + 여기서 갈아탐 | 구현됨 | 계산 RI:85-88, 입력 A/features/record/ui/record_edit_screen.dart:181-201 |
| 297 | L519 | 손 입력 끝은 참, CSV는 거짓, 나중에 일괄로 참 | 부분 | 기본값 C/records/record.dart:110, CSV C/importing/csv_import.dart:313. 기록마다 고치기 A/features/record/ui/record_edit_screen.dart:169-180. 일괄 변경 없음 (L1607) |
| 298 | L520 | 통과 판정은 지난 경로, 경로 밖 갈아탄 역 무시 | 구현됨 | RI:73~85 |
| 299 | L521 | 방문 역 수 = 역 방문 ∪ 승하차역 | 구현됨 | ST:127-128,178-182, C/network/station_state.dart:25-41. 숫자 카드 `지나간 역`은 별도 지표 (§8.0) |

### §2.8 N (L526~534)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 300 | L526 | resolve_status ok | 구현됨 | C/records/derived.dart:6 |
| 301 | L527 | partial | 구현됨 | C/records/derived.dart, 목록 배지 record_list_screen.dart:76 |
| 302 | L528 | needs_input: 사용자 답이 필요 | 구현됨 | `record_edit_screen.dart` `_questions`가 방향·이설·모름을 구간마다 받음 |
| 303 | L529 | unknown_ref | 구현됨 | RR:137, RR:175 |
| 304 | L530 | invalid | 구현됨 | RR:183, RR:197 |
| 305 | L531 | error, 다른 기록 계산은 계속 | 구현됨 | C/records/derived.dart `interpretRideIsolated` |
| 306 | L533 | ok·partial 아닌 기록은 완주 제외, 원본 유지 | 구현됨 | RI:74 edge 없음 |
| 307 | L533 | `확인 필요 n건 · m km` 표시, partial 나머지 포함 | 구현됨 | `reviewProvider`, 통계 완주율 아래 한 줄 |
| 308 | L534 | 가져온 행 원문을 import_raw에 보존 | 구현됨 | C/importing/csv_import.dart:316 |

### §2.8 O (L539~549)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 309 | L539 | normal | 구현됨 | pack edge_attr |
| 310 | L540 | outside | 구현됨 | pack 343행 |
| 311 | L541 | extra | 구현됨 | pack 43행 |
| 312 | L543 | 분자 = 분모 ∩ 탄 단위, 분모 밖 km 미표시 | 구현됨 | C/score/scorer.dart:78, C/score/ride_preview.dart:48 |
| 313 | L544 | 등급은 기간별 행, rule_class 기본값, outside는 빌드 계산 | 구현됨 | CP:108, T/gen_source.py:874 |
| 314 | L545 | 한 단위에 등급이 섞이면 기준별로 다르게 | 문서 오류 | 해당 사례 0건 (km_change, 등급 섞인 단위, 같은 edge 재개). 규칙은 있으나 팩에 대상 없음 |
| 315 | L546 | 전 구간 분모 밖 노선은 전체 통계 제외 | 구현됨 | C/score/scorer.dart:57 |
| 316 | L546 | 그 노선의 상세 화면은 노선 자체 km로 진행률 | 구현됨 | LD:278-292 분모 밖이면 selfScore, DG:180-194. 역 선택기 머리글 km 0.0과 `이미 탄 구간입니다` 오표시는 남음 RS:104-105, SB:153 |
| 317 | L547 | extra는 승차 km·승차율 제외 | 구현됨 | C/score/scorer.dart:58 |
| 318 | L547 | extra도 누적 탑승 거리에 포함 | 구현됨 | `watchTotalKm10` |
| 319 | L549 | 사철 목록 완성 시 normal로 옮기고 안내 | 대상 아님 | L549 "목록이 완성되면", L952 |

### §2.9 환승·분기·승계 (L581~639)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 320 | L582 | hub 파일 구조 | 구현됨 | data/source/hubs (799) |
| 321 | L588 | junction 파일 구조, side, source | 구현됨 | data/source/junctions (1,234) |
| 322 | L601 | 끝에서 이어지는 continue | 구현됨 | pack: 東横線 → 副都心線 is_continue=1 |
| 323 | L609 | (역, 상대 계통) 한 쌍에 표시 하나, 지선은 other_route | 구현됨 | CP:443~491 |
| 324 | L613 | 1순위: 끝에서 이어짐 | 구현됨 | C/network/display_rules.dart `EndLine`, SL:584 |
| 325 | L614 | 2순위: 분기, side 없으면 아래 | 구현됨 | C/network/display_rules.dart `ups·downs`, SL:478 |
| 326 | L615 | 3순위: 환승 캡슐 | 구현됨 | A/features/record/ui/session_painters.dart `StopPainter`, SL:182 |
| 327 | L617 | 양 끝이 닿는 노선은 역마다 따로 | 구현됨 | CP:433~491 |
| 328 | L618 | side의 뜻 | 구현됨 | pack: side up 178, down 215 |
| 329 | L620 | 위아래는 계통 순서, 위키 방향 반대면 뒤집음 | 구현됨 | T/gen_wiki.py:154~181 |
| 330 | L621 | transfers/*.yaml 안 씀 | 구현됨 | data/source에 없음 |
| 331 | L622 | 사실만 기록, source에 revid | 구현됨 | pack junction.source `wikipedia:<revid>` |
| 332 | L623 | hub·junction이 비어도 기록·통계 동작 | 구현됨 | 기록·통계는 route_link를 안 읽음 |
| 333 | L625 | 승계 사슬은 transfer에서 컴파일 | 구현됨 | CP:144~163 |
| 334 | L625 | 폐선 뒤 재개는 open + continues | 구현됨 | CP:126. 데이터 0건 |
| 335 | L630 | 이관: 현행, 지금 이름 + 옛 이름 병기 | 구현됨 | C/network/display_rules.dart `_chained`, SL:548~555 |
| 336 | L631 | 개칭: 현행, 이름 병기 | 부분 | 노선 개칭 데이터 0행 (pack line 기간 이름 0). L225 |
| 337 | L632 | 통합: 새 line + transfer | 부분 | 리아스선 통합 미표현 (L253) |
| 338 | L633 | 부활: 중단 기간 기록 불가, `~폐지`·`재개~` 병기 | 문서 오류 | 해당 사례 0건 (km_change, 등급 섞인 단위, 같은 edge 재개). 규칙은 있으나 팩에 대상 없음 |
| 339 | L634 | 일부만 이관: 구간별 transfer | 구현됨 | pack: 신에츠 구간별 |
| 340 | L635 | 이관 후 폐지 `1989~2006` 폐선색 | 구현됨 | `_tail` `span`, 폐선색 |
| 341 | L636 | 사업자 철수 `1968~2010` | 구현됨 | `_tail` `span` |
| 342 | L637 | 완전 폐지: 옛 이름만 | 구현됨 | pack, SL:38 |
| 343 | L639 | 원자료 closed 값 안 쓰고 상태로 계산 | 구현됨 | CP:121~188 |

### §2.10 원본 소유권 (L646~654)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 344 | L646 | imports: 스냅샷과 sources.lock | 구현됨 | data/imports/osm/overpass-2026-11-02, data/sources.lock:137 이하에 등록 |
| 345 | L648 | candidates는 기계가 덮어씀 | 구현됨 | data/candidates |
| 346 | L650 | data/source는 사람 소유, 기계는 diff 제안만 | 부분 | T/all.sh:7~18이 data/source를 다시 씀 (시드 동결 전) |
| 347 | L652 | 시드는 한 번, 이후 변경 감지만 | 부분 | 위와 같음 |
| 348 | L653 | 손 보정은 data/source의 파일에 | 문서 오류 | L775는 data/overrides, L783·L785는 스크립트 안 표. 서로 모순 |
| 349 | L654 | 빌드 고정, 의존성 잠금 | 구현됨 | data/sources.lock, WF tippecanoe 2.79.0 |

### §2.10 뼈대 데이터의 역할 (L669~675)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 350 | L670 | station_database는 시드 | 구현됨 | T/gen_source.py |
| 351 | L671 | 위키 노선도 | 구현됨 | T/gen_wiki.py |
| 352 | L672 | N02는 선형과 역 묶음 | 구현됨 | T/gen_geometry.py, T/n02_stations.py |
| 353 | L675 | 사업자 공지로 3월 개정 감지 | 미구현 | 수집·감지 도구 없음 |
| 354 | L669 | 노리츠부시는 대조 기준 | 구현됨 | T/audit_ext.py:29 |

### §2.10 ID (L677~697)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 355 | L677 | ID는 불투명, 외부 키는 별도 열 | 부분 | 앱은 파싱 안 함. CP:510 e_ 숫자 파싱. 외부 키 열 없음 data/source/nodes |
| 356 | L687 | 노드 ID 형식 | 구현됨 | pack n_hakodate, n_fukui_echizen |
| 357 | L688 | 역 묶음·환승 묶음 형식 | 구현됨 | pack g_himeji, hub_himeji |
| 358 | L689 | 사업자·노선 형식 | 구현됨 | pack |
| 359 | L690 | 계통·운전 계통 형식 | 구현됨 | pack |
| 360 | L692 | edge 형식 | 구현됨 | pack e_000123 |
| 361 | L691 | 승계 사슬 `lg_`, 열람 전용 `a_` | 문서 오류 | lg336 형식. 승계 사슬 ID는 기록에 저장 안 함(§2.10), 영향 없음 |
| 362 | L697 | ID 재사용 금지, 추가 전용 ids.lock | 미구현 | 파일 없음 |

### §2.10 redirect 규칙 (L702~708)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 363 | L702 | 1:1 정정 | 미구현 | pack id_redirect 0행, Dart에 redirect 없음 |
| 364 | L703 | 1:N 분리, 못 풀면 needs_input | 미구현 | 위와 같음 |
| 365 | L704 | 묘비 항목, 기록은 invalid | 미구현 | 위와 같음 |
| 366 | L705 | 비공개가 된 역을 가리키는 기록의 표시 이름 유지 | 구현됨 | S/db/tables.dart:63~65, S/pack/pack_reader.dart:111 |
| 367 | L706 | 여러 판 건너뛴 갱신은 사슬 압축 | 미구현 | 위와 같음 |
| 368 | L708 | redirect는 읽을 때만 적용 | 미구현 | 위와 같음 |

### §2.10 변경 유형별 도구 (L713~716)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 369 | L713 | new-station | 미구현 | T/에 없음 |
| 370 | L714 | split-edge | 미구현 | T/에 없음 |
| 371 | L715 | transfer-section | 미구현 | T/에 없음 |
| 372 | L716 | diff-sources | 미구현 | T/에 없음 |

### §2.11 배포 파일 (L721~754)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 373 | L721 | master.sqlite | 구현됨 | build/manifest.json |
| 374 | L722 | names.sqlite, 파일 안에 출처별 고지 | 문서 오류 | 고지는 data/NOTICE.md와 설정 출처 화면 A/features/settings/ui/data_sources_screen.dart. 행별 source 있음 |
| 375 | L724 | rail.pmtiles: 선형, 역 점, 작은 기본 배경 | 구현됨(이름 다름) | 작은 배경은 base.pmtiles로 분리 T/gen_tiles.py 기본 배경 절, DESIGN §2.11 base.pmtiles |
| 376 | L725 | rail-osm.pmtiles | 구현됨 | `rail-osm.pmtiles` 앱 자산, `start_gate.dart` |
| 377 | L727 | manifest.json + .sig (판, 스키마, 최소 앱 버전, 해시) | 부분 | 판·스키마·해시 있음. 최소 앱 버전과 .sig 없음 |
| 378 | L754 | OSM 선형 유무를 앱이 파일을 읽어 판단 | 구현됨 | `pack_folder.dart` |
| 379 | L754 | OSM 값을 master·rail과 섞지 않음 | 구현됨 | OSM 값이 아직 없어 위반 없음 |
| 380 | L754 | verified는 사람이 확인했다는 뜻만 | 구현됨 | pack: hub·junction verified 0 |

### §2.12 구축된 파이프라인 (L761~788)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 381 | L761 | 항목마다 JSON 한 줄 YAML | 구현됨 | data/source/nodes/jr.yaml |
| 382 | L763 | 시드 | 구현됨 | T/gen_source.py |
| 383 | L764 | 위키 | 구현됨 | T/gen_wiki.py |
| 384 | L765 | 옛 폐선, 사철 2000년 전 outside | 구현됨 | T/gen_old.py, T/gen_source.py:874 |
| 385 | L767 | 선형 N02 5개 판 | 구현됨 | T/gen_geometry.py |
| 386 | L768 | 컴파일 | 구현됨 | CP |
| 387 | L769 | 타일과 manifest | 구현됨 | T/gen_tiles.py |
| 388 | L770 | 대조 | 구현됨 | T/verify.py |
| 389 | L771 | 현황 문서 생성 | 구현됨 | T/status.py |
| 390 | L772 | 역 문서 | 구현됨 | T/wiki_station.py |
| 391 | L773 | 역명 이력 | 구현됨 | T/gen_renames.py |
| 392 | L774 | 재검토 | 구현됨 | T/audit_db.py, T/audit_ext.py |
| 393 | L775 | 사람이 고친 값 | 구현됨 | data/overrides |
| 394 | L777 | 노드는 사업자별, JR 계열 한 묶음 | 구현됨 | pack n_nagoya가 신칸센·재래선 공용 |
| 395 | L778 | 옛 역은 위키에 km·연도 있으면 노드 | 구현됨 | data/overrides/wiki_insert.json |
| 396 | L779 | 공식 부품은 계통 하나, 끊긴 부품은 이어서 한 계통 | 구현됨 | pack r_nemuro_main_line |
| 397 | L780 | 위키만으로 기록 가능 노선을 만들지 않음 | 구현됨 | T/gen_old.py:123 |
| 398 | L781 | 옛 폐선 구간 이력은 old_history.json | 구현됨 | data/overrides/old_history.json |
| 399 | L782 | 역 날짜는 역 문서 우선 | 구현됨 | T/wiki_station.py |
| 400 | L783 | 3섹 이관 역 이름 대응표 | 구현됨 | T/gen_source.py:97 |
| 401 | L784 | 환승 묶음 350m, 문서 근거 | 구현됨 | CP:427~429 |
| 402 | L785 | 끝에서 이어짐 판정과 NOCONT | 구현됨 | T/gen_wiki.py:202 |
| 403 | L786 | 현행 역 좌표 N02 대조 | 구현됨 | T/n02_stations.py |
| 404 | L787 | 대표 이름은 가장 늦은 시기 | 구현됨 | T/gen_source.py |
| 405 | L788 | 노선 이름 짝짓기, lines_ko·lines_kana | 구현됨 | data/overrides/lines_ko.json |

### §3.1 완주율 3기준 (L795~799)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 406 | L795 | 현행 | 구현됨 | C/score/scorer.dart:57, ST:87 |
| 407 | L796 | 역대 | 구현됨 | C/score/scorer.dart:57, ST:88 |
| 408 | L797 | 특정 연도 Y | 구현됨 | C/score/scorer.dart:57,71, ST:28 |
| 409 | L799 | 단위는 승계 설정에 따름, 분자는 분모 안에서 | 구현됨 | pack denominator_unit on·off, C/score/scorer.dart:78 |

### §3.2 변화 유형별 처리 (L804~813)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 410 | L804 | 사업자 전환: 기본 승계, 끄기 설정 | 구현됨 | `carryoverProvider`, 설정 스위치 |
| 411 | L805 | 이설: 옛 선로는 폐선 기록, 새 선로는 다시 타야 함 | 구현됨 | pack 별도 edge, C/score/scorer.dart |
| 412 | L806 | 부분 폐선: 폐지 구간은 역대에만 | 구현됨 | C/score/scorer.dart:57 |
| 413 | L807 | 중간 폐선: 노선 하나, intentional_gap | 부분 | 노선·진행률 하나 구현. intentional_gap 없음 |
| 414 | L808 | 연장 개업으로 완주 풀림 → 노선 변경 소식 | 구현됨 | `lineReopened` |
| 415 | L809 | 지난 역 신설은 open_stop | 구현됨 | data/source/events |
| 416 | L809 | 앞으로의 역은 new-station 도구 | 미구현 | 도구 없음 |
| 417 | L810 | 폐역은 그 역을 지나는 기록에 영향 없음 | 구현됨 | close_stop은 edge를 안 건드림 CP:183 |
| 418 | L811 | 폐선 후 재개업 | 구현됨 | CP:121 `life_open`. 사례 0건 |
| 419 | L812 | 재해 불통: 현행 분모 포함, 탑승 불가 | 구현됨 | pack 불통 edge 103개, SL:115 운휴 |
| 420 | L812 | 재해 불통 구간의 역 방문 가능 | 구현됨 | 방문은 구간 영업 상태를 보지 않음 MP:29-41, LD:88-113 |
| 421 | L813 | BRT는 폐선과 같이 처리 | 구현됨 | L246 |

### §3.3 노선 상세 화면 (L817~821)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 422 | L817 | 노선 상세: 노선 이름과 현행·역대 km·% 두 줄 | 구현됨 | LD:293-297,329-370. 줄을 탭하면 역 선택기는 그대로 BS:240 |
| 423 | L821 | 배지 `현행 완주` / `역대 완주` 별도 | 구현됨 | LD:295-296,355-363 현행·역대를 따로 표시. 목록은 체크 표시 A/features/record/ui/line_tile.dart:60-61 |
| 424 | L821 | 완주 상태가 바뀌면 노선 변경 소식 알림 | 구현됨 | `lineReopened` |

### §4.1 수록 정책 (L828~850)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 425 | L828 | 현행 전부 + 1950-01-01 이후 폐지 | 구현됨 | pack 2026-11-04.1: 노선 836, 법적 폐지 기준일 전 0건. N05 노선 묶음 판정은 data/candidates/n05_report.json |
| 426 | L832 | 지도 표시 등급 | 구현됨 | pack coverage 593 |
| 427 | L833 | 기록 가능 등급 | 구현됨 | pack coverage 173 |
| 428 | L834 | 열람 전용 등급: 노선 화면에 표시 | 구현됨 | pack archive, SL:632 |
| 429 | L835 | 보류 등급은 staging에만 | 부분 | staging 폴더 없음 (L191) |
| 430 | L838 | 기준일 이전 폐지는 탑승 불가 | 구현됨 | archive가 route_edge 밖 |
| 431 | L839 | 날짜는 조건 아님, 연도만 표시 | 구현됨 | pack archive_stop opened NULL 410, SL:646 |
| 432 | L840 | 선형 추가만으로 승격 | 구현됨 | CP:574 GEO, CP:643 |
| 433 | L841 | 신호장 완전성은 조건 아님 | 구현됨 | CP:639~644 |
| 434 | L846 | JR 수록, 계절 운행 포함 | 구현됨 | pack: ガーラ湯沢 r_joetsu_line_echigo_yuzawa_gala_yuzawa |
| 435 | L847 | 사철 수록, 제3종 제외 | 구현됨 | pack operator·line |
| 436 | L848 | 폐선 이름은 탑승일 기준, km는 폐지 직전 | 구현됨 | S/pack/pack_reader.dart:95, edge_km |
| 437 | L849 | 별선·단락선 extra, 梅田貨物線 별선 | 구현됨 | pack: l_umeda_freight_line extra |
| 438 | L850 | 연락선·BRT·삭도 등 미수록 | 구현됨 | pack 해당 이름 0 |

### §4.2 1970년대 미확인 노선 표 (L860~888)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 439 | L860 | 山形交通尾花沢線 기록 가능 후보 | 구현됨 | §4.2는 조건부 후보. 역 목록·km 미확정이면 열람 전용이 규칙대로 (§4.1, §4.5). pack names.name entity_type=archive 확인. 湯野浜線은 line |
| 440 | L861 | 茨城交通茨城線 | 구현됨 | pack 기록 가능, outside |
| 441 | L862 | 北陸鉄道 山中線·山代線 | 구현됨 | pack 기록 가능, outside |
| 442 | L863 | 横荘線 | 구현됨 | pack 기록 가능, outside |
| 443 | L864 | 金石線 | 구현됨 | pack 기록 가능, outside |
| 444 | L865 | 世知原線·臼ノ浦線 | 구현됨 | pack 기록 가능, normal |
| 445 | L866 | 鍛冶屋原線 | 구현됨 | pack 기록 가능 |
| 446 | L867 | 細島線 | 구현됨 | pack 기록 가능 |
| 447 | L868 | 上田交通真田傍陽線 | 구현됨 | §4.2는 조건부 후보. 역 목록·km 미확정이면 열람 전용이 규칙대로 (§4.1, §4.5). pack names.name entity_type=archive 확인. 湯野浜線은 line |
| 448 | L869 | 三国線·篠山線 | 구현됨 | pack 기록 가능 |
| 449 | L870 | 川俣線 | 구현됨 | pack 기록 가능 |
| 450 | L871 | 美唄鉄道 | 구현됨 | §4.2는 조건부 후보. 역 목록·km 미확정이면 열람 전용이 규칙대로 (§4.1, §4.5). pack names.name entity_type=archive 확인. 湯野浜線은 line |
| 451 | L872 | 北陸鉄道能登線 | 구현됨 | pack 기록 가능, outside |
| 452 | L873 | 加越鉄道 | 구현됨 | §4.2는 조건부 후보. 역 목록·km 미확정이면 열람 전용이 규칙대로 (§4.1, §4.5). pack names.name entity_type=archive 확인. 湯野浜線은 line |
| 453 | L874 | 松尾鉱業鉄道 | 구현됨 | §4.2는 조건부 후보. 역 목록·km 미확정이면 열람 전용이 규칙대로 (§4.1, §4.5). pack names.name entity_type=archive 확인. 湯野浜線은 line |
| 454 | L875 | 上武鉄道 | 구현됨 | §4.2는 조건부 후보. 역 목록·km 미확정이면 열람 전용이 규칙대로 (§4.1, §4.5). pack names.name entity_type=archive 확인. 湯野浜線은 line |
| 455 | L876 | 西鉄福岡市内線 수록 제외 | 구현됨 | pack 없음 |
| 456 | L877 | 名鉄拳母線 | 구현됨 | §4.2는 조건부 후보. 역 목록·km 미확정이면 열람 전용이 규칙대로 (§4.1, §4.5). pack names.name entity_type=archive 확인. 湯野浜線은 line |
| 457 | L878 | 雄勝線 | 구현됨 | pack 기록 가능 |
| 458 | L879 | 福井鉄道鯖浦線 | 구현됨 | §4.2는 조건부 후보. 역 목록·km 미확정이면 열람 전용이 규칙대로 (§4.1, §4.5). pack names.name entity_type=archive 확인. 湯野浜線은 line |
| 459 | L880 | 北丹鉄道 | 구현됨 | pack 지도 표시, outside |
| 460 | L881 | 東濃鉄道駄知線 | 구현됨 | pack 기록 가능 |
| 461 | L882 | 山形交通 三山線·高畠線 | 구현됨 | pack 기록 가능 |
| 462 | L883 | 富山地鉄笹津線 · 庄内交通湯野浜線 | 구현됨 | §4.2는 조건부 후보. 역 목록·km 미확정이면 열람 전용이 규칙대로 (§4.1, §4.5). pack names.name entity_type=archive 확인. 湯野浜線은 line |
| 463 | L884 | 越後交通栃尾線 | 구현됨 | pack 기록 가능 |
| 464 | L885 | 大分交通耶馬渓線 | 구현됨 | pack 기록 가능 |
| 465 | L886 | 北恵那鉄道 | 구현됨 | §4.2는 조건부 후보. 역 목록·km 미확정이면 열람 전용이 규칙대로 (§4.1, §4.5). pack names.name entity_type=archive 확인. 湯野浜線은 line |
| 466 | L887 | 東濃鉄道笠原線 | 구현됨 | pack 기록 가능 |
| 467 | L888 | 姫路市営モノレール | 구현됨 | §4.2는 조건부 후보. 역 목록·km 미확정이면 열람 전용이 규칙대로 (§4.1, §4.5). pack names.name entity_type=archive 확인. 湯野浜線은 line |
| 468 | L853 | 폐선 목록은 위키 일람과 개별 문서로 만듦 | 구현됨 | T/gen_old.py:167, data/imports/old_titles.json. 판정 결과는 기록 가능 또는 archive |

### §4.4 노면전차망 (L912)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 469 | L912 | 옛 노면전차망 미수록 | 구현됨 | pack: 京都·名古屋·横浜·大阪市電 0 |
| 470 | L912 | 현행 노면전차와 최근 부분 폐지는 일반 규칙 | 구현됨 | pack: tram 53노선 |

### §4.5 열람 전용 (L915~940)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 471 | L915 | 표시는 데이터 상태, 기록 허용은 기준일로 판정 | 구현됨 | T/gen_old.py:123 |
| 472 | L915 | archive 파일 구조, 왓카나이잔교 | 구현됨 | pack: 稚内桟橋 a_4d17d97f, r_soya_main_line, n_wakkanai 다음 |
| 473 | L925 | 이름은 names/, 한글 검사, after·before | 구현됨 | pack name archive ko 579, archive_stop.after_id·before_id |
| 474 | L929 | 폐역·폐선과 같은 3단계 흐림 | 구현됨 | SL:632~679 |
| 475 | L929 | 메인 설정 체크박스 (기본 켬) | 구현됨 | A/features/settings/ui/settings_screen.dart:30~48 |
| 476 | L929 | 기록 화면 맨 위 체크박스 | 구현됨 | RS:194 `_DisplayBar` |
| 477 | L930 | 연도만, 모르면 `~?`, km도 `?` | 구현됨 | S/pack/pack_reader.dart:209, SL:646, SL:666 |
| 478 | L931 | 출발·도착 불가, 탭하면 폐지 연도와 안내 | 구현됨 | SL:651 |
| 479 | L932 | 끝 역 너머 줄기를 가늘고 흐리게 | 구현됨 | SL:20 `tail`, SL:59 |
| 480 | L933 | 완주율·거리 제외 | 구현됨 | network_reader가 archive를 안 읽음 |
| 481 | L934 | 지도에 그리지 않음 | 구현됨 | T/gen_tiles.py archive 미사용 |
| 482 | L935 | 역 방문 기록 불가 | 구현됨 | archive ID는 node가 아님 |
| 483 | L936 | 승격 규칙 | 구현됨 | T/gen_old.py:123 |
| 484 | L937 | 옛 노면전차망·전용선·미개업선 제외 | 구현됨 | pack archive 이름 검사 |
| 485 | L939 | 파일을 지워도 기록·통계 동일 | 구현됨 | edges·km·events 무참조 |
| 486 | L940 | km 모르는 역은 선로망에 넣지 않음 | 구현됨 | archive_stop km NULL 115행 |

### §4.6 탑승 기록 허용 범위 (L945~989)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 487 | L945 | 기준일 전 날짜는 "입력해도 저장되지 않고" | 문서 오류 | L504·L1026은 입력값이 date_input에 남는다고 함. 구현도 남김 RC:586, C/date/date_rules.dart:14 |
| 488 | L949 | 현행 노선 허용·포함 | 구현됨 | pack |
| 489 | L950 | 국철·JR 폐선 1950-01-01 이후 허용·포함 | 구현됨 | pack 幸袋線 normal |
| 490 | L954 | 사철 폐선 2000년 이후 허용·포함 | 구현됨 | pack normal 34노선 |
| 491 | L952 | 사철 1950-01-01~1999 허용, 분모 제외, 화면 미표시 | 구현됨 | pack 2026-11-04.1 outside 105노선(1950~1969 국철 포함), C/score/ride_preview.dart:48 |
| 492 | L956 | 기준일 이전 폐지 표시만 | 구현됨 | pack archive |
| 493 | L980 | 국철 이관 뒤 폐지 구간은 분모 | 구현됨 | CP:158 이관 때 등급 승계. pack: 黒石線 국철 단위 normal. 이관 뒤 사철 시기 행이 없는 노선도 있음 |
| 494 | L981 | 국철·JR은 139개 + 추가분과 대조 | 구현됨 | T/audit_ext.py |
| 495 | L982 | 根北線 수록 | 구현됨 | pack 1970-12-01 |
| 496 | L983 | 手宮線: 법적 폐지일로 범위, 선택기는 마지막 운행일 | 구현됨 | pack valid_to 1962-05-15, legal 1985-11-05 |
| 497 | L984 | 범위 폐지일 하한 판정 | 구현됨 | pack 범위 폐지일 edge 0건 |
| 498 | L985 | 특정 연도는 1970년부터 | 구현됨 | ST:40 |
| 499 | L986 | 기준일 전 날짜는 날짜 모름, 설명 문구 없음 | 구현됨 | C/date/date_rules.dart:14, RR:112 |
| 500 | L986 | 입력칸이 바로 `날짜 모름`으로 바뀜 | 구현됨 | RS:99-101 칩이 바로 `날짜 모름`. 운전 계통 화면 칩은 입력값 그대로 SS:74 |
| 501 | L986 | 연대는 1970년대부터 고름 | 구현됨 | 연대 입력 `198X`, `1980s`, `1980년대`, `1980年代` |
| 502 | L987 | 탈 수 없는 날짜는 경고 팝업, 저장하지 않음 (v0.48) | 구현됨 | C/network/ride_interpreter.dart:118 `unridable`, A/features/record/ui/session_date.dart:137 `showUnridable` |
| 503 | L988 | CSV 해당 행도 같음, 원문 보존 | 구현됨 | RI:46~52, C/importing/csv_import.dart:316 |
| 504 | L989 | 사철 행: 검증되면 outside, 아니면 unknown_ref | 구현됨 | C/importing/csv_import.dart:14, RR:137 |

### §4.7 지도 위치 상태 (L995~1000)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 505 | L995 | 역 quality와 checked | 구현됨 | pack precise 9,467, approx 1,530, none 26 |
| 506 | L996 | edge.geometry_quality | 구현됨 | pack precise 10,099, none 1,084 |
| 507 | L997 | route.map_coverage | 구현됨 | pack full 641, partial 80, none 102 |
| 508 | L1000 | approx 좌표는 지도에 점을 찍지 않음 | 대상 아님 | redesign 4.1 `역 위치 규칙`: 폐역은 approx도 점 유지. DESIGN §4.7은 미갱신 (모순 M4) |

### §5.1 구간 탑승 (L1007)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 509 | L1007 | 노선 + 출발역 + 도착역 + 날짜 | 구현됨 | RC:586~642 |
| 510 | L1007 | 시간 입력 | 구현됨 | A/features/record/ui/record_edit_screen.dart:44,164. 입력은 저장 뒤 기록 수정 화면 |
| 511 | L1007 | 열차명 입력 | 구현됨 | A/features/record/ui/record_edit_screen.dart:45,165. 입력은 저장 뒤 기록 수정 화면 |
| 512 | L1007 | 편성 입력 | 구현됨 | A/features/record/ui/record_edit_screen.dart:46,166. 입력은 저장 뒤 기록 수정 화면 |
| 513 | L1007 | 메모 입력 | 구현됨 | A/features/record/ui/record_edit_screen.dart:47,167. 입력은 저장 뒤 기록 수정 화면 |
| 514 | L1007 | 날짜 미상 허용 | 구현됨 | A/features/record/ui/session_date.dart `DateAnswer(null)` |

### §5.2 역 방문 (L1010~1014)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 515 | L1010 | 역만 방문한 경우 기록 | 구현됨 | MP:29-41,70-75, LD:88-113, A/features/record/controller/record_list_controller.dart:64-87 |
| 516 | L1011 | 기록 탭에 구간 탑승 / 역 방문 두 목록 | 구현됨 | A/features/record/ui/record_home_screen.dart:46-61 셋째 탭 `역 방문`, MP:131-165 |
| 517 | L1012 | 완주율·거리 무영향, 지도 점은 칠해짐 | 구현됨 | 방문은 ride_edge에 안 들어가 점수 무영향 S/records/record_store.dart:155-159, 지도 MS:245-281, A/app/session_providers.dart:179-188 |
| 518 | L1013 | 폐역 방문 가능 | 구현됨 | 폐역 점 시트 MH:98, 노선 상세 점 LD:238. 막는 코드 없음 |
| 519 | L1013 | 열람 전용 역은 방문 불가 | 구현됨 | L935 |
| 520 | L1014 | 방문 역 수 (현행 / 폐역) | 구현됨 | 합계와 폐역 수 |
| 521 | L1014 | 도도부현별 방문 역 수 | 구현됨 | 도도부현별 방문 역 수 A/features/stats/ui/visits_screen.dart:40, A/features/stats/controller/visits_controller.dart, C/score/collection.dart:139, 라우트 A/app/router.dart:83 |

### §5.3 지도 위 점의 상태 (L1019~1023)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 522 | L1019 | 미방문: 회색 테두리, 가운데 흰색 | 구현됨 | MS:189~208 |
| 523 | L1020 | 통과: 파란 테두리, 뚫린 원 | 구현됨 | MS:254-290 stationPassedLayer, 필터 MH:150-152 |
| 524 | L1021 | 발로 밟음: 파란색 꽉 찬 원 | 구현됨 | MS:254-290 stationSteppedLayer, 필터 MH:150-152 |
| 525 | L1023 | 폐역은 빨강 | 구현됨 | MS:274-287 `closed`면 폐선·탑승 색 |
| 526 | L1023 | 방문만 있으면 점만 칠함 | 구현됨 | 방문은 stepped에만 들고 선은 riddenEdges A/app/session_providers.dart:159-161,179-188 |

### §5.4 불확실한 날짜 (L1026~1053)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 527 | L1026 | 마스터와 기록이 같은 날짜 형식 | 구현됨 | C/date/date_span.dart |
| 528 | L1026 | 화면은 계산된 날짜를 입력 형식 그대로 | 구현됨 | C/date/date_rules.dart:83, A/features/record/ui/record_list_screen.dart:92 |
| 529 | L1026 | 날짜 모름이 된 기록은 `날짜 모름` | 구현됨 | S/records/record_queries.dart `shownDate` |
| 530 | L1026 | 입력값을 수정 화면에서 봄 | 구현됨 | A/features/record/ui/record_edit_screen.dart:43,163 date_input을 그대로 보임 |
| 531 | L1030 | 일까지 | 구현됨 | C/date/date_span.dart |
| 532 | L1031 | 월까지 | 구현됨 | C/date/date_span.dart |
| 533 | L1032 | 연도까지 | 구현됨 | C/date/date_span.dart |
| 534 | L1033 | 연대까지 (저장·표기) | 구현됨 | C/date/date_span.dart, C/date/date_rules.dart:55. 사용자 입력은 L986 |
| 535 | L1034 | 모름은 NULL, 화면 `~?` | 구현됨 | C/date/date_rules.dart:55 |
| 536 | L1035 | 끝나지 않음 ongoing | 구현됨 | C/date/date_span.dart `maxDate` |
| 537 | L1037 | NULL과 ongoing을 섞지 않음 | 구현됨 | pack valid_to, CP:559 |
| 538 | L1038 | 마스터 날짜는 화면에 연도만 | 구현됨 | C/date/date_rules.dart:55 |
| 539 | L1039 | 빌드 시 (lo, hi)로 변환, ongoing은 최댓값 | 구현됨 | CP:559, T/lib.py:77 |
| 540 | L1044 | 역 선택: 범위가 겹치면 선택 가능 | 구현됨 | C/date/date_rules.dart `stateOn`, C/network/selector.dart |
| 541 | L1045 | 애매하면 선택되고 날짜 칩 `?` + 저장 시 안내 | 구현됨 | 칩 뒤 `?` (`record_session_screen.dart`) |
| 542 | L1046 | 특정 연도: 애매한 edge 제외, `판정 불가 n구간` | 부분 | 단위 전부 certainty=certain, 화면 표시 없음 |
| 543 | L1046 | 폐지 연도만 알면 폐지 해에 영업한 것으로 침 | 구현됨 | C/score/scorer.dart:57 date_hi |
| 544 | L1047 | 현행·역대는 날짜 불확실성과 무관 | 구현됨 | C/score/scorer.dart:57 |
| 545 | L1048 | 미상·부분 기록은 유효 범위로 연도 판정 | 구현됨 | RI:111 |
| 546 | L1049 | 수록 범위 판정 | 구현됨 | T/gen_old.py:123 |
| 547 | L1051 | CI 위상은 범위 양 끝에서 검사 | 미구현 | L318과 같음 |
| 548 | L1053 | 개업 `1987~`, 폐지 `~1987` | 구현됨 | A/i18n/ko.i18n.json state.since·until |

### §6 기능 명세: 기록 (L1063~1069)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 549 | L1063 | 구간 탑승 | 구현됨 | RC:586 |
| 550 | L1063 | 경로 자동 전개 | 구현됨 | `route_resolver.dart` `record`, `across` |
| 551 | L1063 | 환승역 노선 선택 | 구현됨 | 사용자 결정: 분기 이동은 한 기록으로 묶지 않음. 다구간은 재설계안 4.2 |
| 552 | L1063 | 날짜 미상 허용 | 구현됨 | L1007 |
| 553 | L1064 | 시점 인식 역 선택기 | 구현됨 | C/network/selector.dart, RC:365 |
| 554 | L1064 | 분기선 표시 | 구현됨 | SL:478 |
| 555 | L1065 | 그 자리에서 전환 | 구현됨 | LD:78-113 |
| 556 | L1065 | 범위 지정 | 구현됨 | LD:122-156,194-203 |
| 557 | L1065 | 되돌리기 | 구현됨 | 표 2의 L1065와 같음 (undo_snack.dart) |
| 558 | L1065 | 일괄 삭제 | 구현됨 | 여정 전체 삭제 포함 |
| 559 | L1066 | 역 방문 기록 | 구현됨 | 도도부현별 방문 역 수 A/features/stats/ui/visits_screen.dart:40, A/features/stats/controller/visits_controller.dart, C/score/collection.dart:139, 라우트 A/app/router.dart:83 |
| 560 | L1067 | 운전 계통 입력 | 구현됨 | 표 2의 L1067과 같음 |
| 561 | L1067 | 순환 입력 | 구현됨 | 표 2의 L1067과 같음 |
| 562 | L1068 | 열람 전용 역·노선 표시 | 구현됨 | SL:632, SL:514 archive |
| 563 | L1069 | 여정 묶음 | 구현됨 | `TripCommands`, `TripDetailScreen` |
| 564 | L1069 | 다구간 경로 탐색 | 구현됨 | `findJourney`, `JourneyScreen`. 시각표 없는 기록 입력 보조 |
| 565 | L1069 | 사진 | 대상 아님 | 2026-11-03 결정: 뺌 |
| 566 | L1069 | 메모 | 구현됨 | A/features/record/ui/record_edit_screen.dart:47,167 |
| 567 | L1069 | GPS 근처 역 | 대상 아님 | 2026-11-03 결정: 뺌. 위치는 `가까운 곳`에만 씀 |

### §6 기능 명세: 지도 (L1071~1073)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 568 | L1071 | 현행·폐선·탑승 상태 | 구현됨 | MS 층 구성, MH:27 |
| 569 | L1071 | 역 원 | 구현됨 | 3상태 MS:206-281, MH:150-152. 폐역·폐선을 꺼도 칠해진 폐역 점은 남음 (필터에 closed 조건 없음 MH:151-152) |
| 570 | L1071 | 도도부현 경계 | 구현됨 | `base.pmtiles`의 `border` 층 |
| 571 | L1071 | 위치 미확인 구간 표식 | 구현됨 | `master.map_marker` 115행, 표식 층, `MarkerSheet` |
| 572 | L1072 | 미승 구간만 보기. v0.41에서 `승차만` 보기로 바뀜 | 구현됨 | L514과 같음. `승차만` 보기로 대체 |
| 573 | L1072 | 노선 단독 보기 | 구현됨 | 표 2의 L1072과 같음 |
| 574 | L1072 | 노선 탭 → 정보 시트 | 구현됨 | MH:84-122, A/app/router.dart:75-96, MP:83-128 |
| 575 | L1073 | 타임 슬라이더 | 구현됨 | 지도 `연도` 칩 |
| 576 | L1073 | 도도부현 히트맵 | 구현됨 | 지도 층 A/features/map/map_style.dart:41,60,371, 칠하기 A/features/map/ui/map_home_screen.dart:222, 칩 :443-448 |

### §6 기능 명세: 통계 (L1074~1075)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 577 | L1074 | 완주율 현행·역대 | 구현됨 | ST |
| 578 | L1074 | 승차 거리 | 구현됨 | 탄 영업km와 누적 탑승 거리 |
| 579 | L1074 | 전체 | 구현됨 | ST:124 |
| 580 | L1074 | 사업자별 | 구현됨 | ST:217 |
| 581 | L1074 | 노선별 | 구현됨 | ST:218 |
| 582 | L1074 | 도도부현별 | 구현됨 | ST:215 |
| 583 | L1075 | 특정 연도 완주율 | 부분 | 연도 고르기는 됨 ST:29-51. §5.4의 `판정 불가 n구간` 표시 없음 (L1046 행) |
| 584 | L1075 | 승계 끔 모드 | 구현됨 | 설정 스위치 A/features/settings/ui/settings_screen.dart:97-101, carryoverProvider A/app/session_providers.dart:233, 모든 집계가 이 값을 씀. 팩 분모 off 33,161.8km를 시나리오로 확인. 단 AR:L237의 켜기 결함 있음 |
| 585 | L1075 | 연도별 그래프 | 구현됨 | `YearsScreen`, 자체 위젯 |
| 586 | L1075 | 활동 캘린더 | 구현됨 | A/features/stats/ui/activity_screen.dart:13, 라우트 A/app/router.dart:82 |
| 587 | L1075 | 폐선 컬렉션 | 구현됨 | 폐선 컬렉션과 폐지 늦은 순 C/score/activity.dart:113 이하, A/features/stats/ui/collection_screen.dart:95,126 |
| 588 | L1075 | 방문 역 통계 | 구현됨 | 도도부현별 방문 역 수 A/features/stats/ui/visits_screen.dart:40, A/features/stats/controller/visits_controller.dart, C/score/collection.dart:139, 라우트 A/app/router.dart:83 |

### §6 기능 명세: 수집·데이터·서버 (L1076~1079)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 589 | L1076 | 현행/역대 완주 배지 | 구현됨 | `CollectionScreen` |
| 590 | L1076 | 축하 카드 | 구현됨 | `showCompleteCard` |
| 591 | L1076 | 공유 카드 | 구현됨 | 축하 카드를 이미지로 공유 |
| 592 | L1076 | 위젯 | 대상 아님 | L1076 "P1~P2", L1769 Phase 3 목록에 위젯 없음 |
| 593 | L1077 | JSON 백업 | 구현됨 | C/backup/backup_codec.dart, S/backup/auto_backup.dart |
| 594 | L1077 | 자동 백업 파일 | 구현됨 | A/app/start_gate.dart `_paused`, S/backup/auto_backup.dart:53 |
| 595 | L1077 | CSV 내보내기 | 구현됨 | A/features/data/ui/data_settings_screen.dart:24-38,75-84, A/features/data/controller/export_controller.dart:25-38, CE:127-275 |
| 596 | L1077 | 앱 업데이트로 데이터 갱신 | 구현됨 | C/pack/pack_choice.dart:18, S/records/cache_rebuild.dart |
| 597 | L1078 | 노리츠부시 CSV 가져오기 | 부분 | 일반판·코멘트판 구현. 수동 선택, 중복 후보, 일괄 승하차 없음 (L1607) |
| 598 | L1078 | 앱 안에서 데이터 내려받기 | 미구현 | http 코드 없음 |
| 599 | L1078 | 노선 변경 소식 | 구현됨 | `NewsGate`, `networkNews` |
| 600 | L1079 | 기기 간 동기화 | 대상 아님 | L1079 "P2", L1772 이후 |
| 601 | L1079 | 순위표 | 대상 아님 | L1079 "P2", L1772 이후 |

### §6.1 첫 기능 목록에서 되살린 항목 (v0.42)

| # | 행 | 요구 | 판정 | 근거 |
|---|---|---|---|---|
| 602 | v0.42 L1087 | 같은 구간 반복 탑승 횟수 (P1) | 미구현 | 구간별 횟수 계산 없음. S/records/record_queries.dart:114-117은 DISTINCT만 |
| 603 | v0.42 L1087 | 반복 탑승 횟수 통계 (P1) | 미구현 | ST에 없음 |
| 604 | v0.42 L1088 | GPS 주행 로그 자동 기록. 백그라운드, 옵트인, 위치는 기기 밖으로 나가지 않음 (P2) | 대상 아님 | L1116 P2 |
| 605 | v0.42 L1089 | 즐겨찾기 고정 (P1) | 미구현 | 코드·저장 없음 (L145 행) |
| 606 | v0.42 L1089 | 열차명 검색 (P1) | 대상 아님 | redesign 4.1 `수송밀도·열차명 검색: P2 (출처 없음)`. DESIGN §6.1은 미갱신 |
| 607 | v0.42 L1089 | 도도부현별 입력 (P1) | 미구현 | A/features/record에 도도부현 경로 없음 (L133 행) |
| 608 | v0.42 L1089 | 기록 목록 정렬 (P1) | 미구현 | S/records/record_queries.dart:93 고정 순서 |
| 609 | v0.42 L1089 | 기록 목록 필터 (P1) | 미구현 | A/features/record/ui/record_list_screen.dart에 필터 없음 |
| 610 | v0.42 L1090 | 역 방문의 메모·사진·차량 (P2) | 대상 아님 | L1118 P2. 지금은 방문 토글뿐 MP:70-75 |
| 611 | v0.42 L1090 | 차량 도감 (P2) | 대상 아님 | L1118 P2 |
| 612 | v0.42 L1091 | 지도 필터: 사업자 (P1) | 미구현 | 칩은 승차만·폐선·역 이름뿐 MH:238-257. 타일에 사업자 속성 없음 T/gen_tiles.py:22-27 |
| 613 | v0.42 L1091 | 지도 필터: 노선 종류 (P1) | 미구현 | 위와 같음 |
| 614 | v0.42 L1091 | 지도 필터: 지역 (P1) | 미구현 | 위와 같음 |
| 615 | v0.42 L1092 | 기록 재생 애니메이션 (P2) | 대상 아님 | L1120 P2 |
| 616 | v0.42 L1093 | 지도 우측 버튼 묶음 (P1) | 대상 아님 | redesign 4.4 #1 지도 버튼과 근처 역 뺌 |
| 617 | v0.42 L1093 | 지도 종류 전환 (P1) | 대상 아님 | redesign 4.4 #1 지도 버튼과 근처 역 뺌 |
| 618 | v0.42 L1094 | 미승 구간 추천: 현재 위치나 고른 지역 근처의 안 탄 구간 (P1) | 구현됨 | `가까운 곳`, 반경 50km |
| 619 | v0.42 L1094 | 미승 구간 목록 (P1) | 구현됨 | `RemainingScreen` |
| 620 | v0.42 L1095 | 개인 기록: 하루 최장 거리 (P1) | 미구현 | ST에 없음 |
| 621 | v0.42 L1095 | 개인 기록: 최다 탑승 노선 (P1) | 미구현 | ST에 없음 |
| 622 | v0.42 L1095 | 개인 기록: 첫 탑승일 (P1) | 미구현 | ST에 없음 |
| 623 | v0.42 L1095 | 개인 기록: 최근 완주 노선 (P1) | 미구현 | ST에 없음 |
| 624 | v0.42 L1096 | 수송밀도 구간별 진행률 (P1) | 대상 아님 | redesign 4.1 `수송밀도·열차명 검색: P2 (출처 없음)`. DESIGN §6.1은 미갱신 |
| 625 | v0.42 L1096 | 분모 밖 노선 자체 진행률 (P1) | 구현됨 | LD:278-292, DG:180-194 |
| 626 | v0.42 L1097 | 업적 배지와 마일스톤 (P1) | 구현됨 | `CollectionScreen`, 역 수 기준 100~3,000 |
| 627 | v0.42 L1097 | 역 스탬프북 (P1) | 미구현 | 코드 없음 |
| 628 | v0.42 L1097 | 폐선 컬렉션 정렬 (P1) | 구현됨 | 폐선 컬렉션과 폐지 늦은 순 C/score/activity.dart:113 이하, A/features/stats/ui/collection_screen.dart:95,126 |
| 629 | v0.42 L1098 | 월간·연간 결산 카드 (P2) | 대상 아님 | L1127 P2 |
| 630 | v0.42 L1098 | 経県値식 단일 점수 `철도 경험치` (P2) | 대상 아님 | L1127 P2 |
| 631 | v0.42 L1099 | 마스코트 (P2) | 대상 아님 | L1128 P2 |
| 632 | v0.42 L1099 | 곁들임 정보 (P2) | 대상 아님 | L1128 P2 |
| 633 | v0.42 L1099 | 공유 카드의 다크 지도 기본값 후보 (P2) | 대상 아님 | L1128 P2 |
| 634 | v0.42 L1100 | 鉄ログ 백업 가져오기 (P2) | 대상 아님 | L1129 P2 |
| 635 | v0.42 L1100 | 데이터 오류 제보 (P2) | 대상 아님 | L1129 P2 |

## 요구가 아니어서 항목에서 뺀 행

문서를 처음부터 다시 훑어 대조했습니다. 아래는 요구가 아니라 사실 기록이나 근거라서 항목으로 세지 않았습니다.

| 행 | 내용 |
|---|---|
| L1~12, L16~17 | 제목과 변경 이력 |
| L49~57 | 두 서비스의 방식 비교. noriori 열이 없는 사실 표 |
| L71, L76 | 노리츠부시 사실. 반영 열은 §4.3, §10 참조뿐이고 §10은 범위 밖 |
| L99~104 | 불리한 점과 추정이라는 단서 |
| L107~123 | 테츠로그 직접 테스트 결과 (사실 기록) |
| L853~855 일부 | 2026-10-30 조사 수치. 목록 작성 요구만 L853로 셈 |
| L890 | 집계의 한계 메모 |
| L892~901 | 노리츠부시 수록 범위 측정과 대조 |
| L904~910 | 다른 서비스의 노면전차 수록 조사 |
| L941~942 | 자료량 측정과 목업 메모 |
| L958~964 | 기준일을 고른 이유 |
| L966~978 | 측정 근거 |
| L990 | 다른 서비스 조사 |
| 표 머리글과 구역 제목 | L24, L37, L62, L80, L110, L126, L136~137, L157~158 등 |
