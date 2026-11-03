# noriori 명세 전수 감사: ARCHITECTURE, server-notes, db-status, data/README

판정 시각 2026-11-02 21시 작업본. 표는 19:23 코드로 만들었고, 그 뒤 `미구현`·`부분`·`미연결` 행을 코드에서 다시 읽어 판정했습니다. `구현됨` 행은 다시 보지 않았고 그 행의 근거 행 번호는 표를 만든 때 기준입니다. 문서 행 번호도 표를 만든 때 기준이고, 새 항목만 ARCHITECTURE v0.11의 행입니다.

경로 줄임: `core/` = packages/noriori_core/lib/src/, `store/` = packages/noriori_store/lib/src/, `app/` = apps/noriori/lib/. 파일 이름만 쓴 근거는 앞 행의 폴더와 같습니다. 문서 줄임: A = ARCHITECTURE, dbs = db-status, SN = server-notes, R = data/README.

판정은 코드, 빌드 산출물(build/master.sqlite, build/names.sqlite 읽기 전용), 도구를 직접 열어 했습니다. 테스트와 앱은 실행하지 않았습니다. 화면 항목의 `구현됨`은 코드를 읽어 내린 판정이고, 추적표 규칙 5의 목업 대조는 하지 않았습니다. 시험 결과 행은 도구가 있는지만 봤고 재실행하지 않았습니다.

## 개수

총 697항목

| 판정 | 전체 | A | dbs | R | SN |
|---|---:|---:|---:|---:|---:|
| 구현됨 | 421 | 320 | 60 | 41 | 0 |
| 구현됨(이름 다름) | 18 | 18 | 0 | 0 | 0 |
| 부분 | 57 | 54 | 2 | 1 | 0 |
| 미구현 | 108 | 104 | 4 | 0 | 0 |
| 미연결 | 1 | 1 | 0 | 0 | 0 |
| 문서 오류 | 8 | 6 | 1 | 0 | 1 |
| 대상 아님 | 84 | 9 | 9 | 0 | 66 |

## 전체 항목표

### docs/ARCHITECTURE.md

| 문서:행 | 요구 요약 | 판정 | 근거 파일:행 |
|---|---|---|---|
| A:19 | 앱이 곧 제품. 기록, 지도, 통계, 백업이 기기 안에서 끝남 | 구현됨 | 서버 코드 없음. 온라인 의존은 배경과 글리프뿐 app/features/map/map_style.dart:101-104 |
| A:20 | 저장은 user.sqlite 하나와 통째로 교체하는 읽기 전용 데이터 팩 | 구현됨 | store/startup/cold_start.dart:18-30, store/pack/pack_folder.dart:51-85 |
| A:21 | 사용자 입력이 원본, 나머지는 입력과 팩에서 재계산 | 구현됨 | core/records/record.dart:3, store/records/cache_rebuild.dart:26-42 |
| A:22 | Flutter, MapLibre 네이티브, 규칙은 순수 Dart noriori_core | 구현됨 | apps/noriori/pubspec.yaml:21, tools/check_boundaries.py:18-21 |
| A:23 | 서버는 v1.0 범위 밖, 최소 준비만 | 구현됨 | server/ 없음. §5 표 참조 |
| A:27 | data/source → compile.py → master, names | 구현됨 | tools/all.sh:21 |
| A:28 | gen_tiles.py → rail.pmtiles | 구현됨 | tools/all.sh:23, tools/gen_tiles.py:47-51 |
| A:30 | 팩은 앱에 포함 | 구현됨 | apps/noriori/pubspec.yaml assets/pack/, tools/sync_pack.sh |
| A:46 | 불변식 1: 지우지 않은 기록은 업데이트, 교체, 복원, 강제 종료 뒤에도 남음 | 구현됨 | packages/noriori_store/test/crash_test.dart:19, backup_test.dart:382-451, cold_start_test.dart:172 |
| A:47 | 불변식 2: 해석 못 하는 기록도 버리지 않고 확인 필요로 표시 | 구현됨 | app/features/record/ui/record_list_screen.dart:76-86, store/records/record_queries.dart:59-92. 답변 화면은 §2.3 /record/:rideId 행 |
| A:48 | 불변식 3: 완주율은 입력만으로 결정, 분자는 분모의 부분집합, 전 구간일 때만 100% | 구현됨 | core/score/scorer.dart:57-103, core/score/score_format.dart:26-36 |
| A:49 | 불변식 4: 한 세션은 팩 하나 | 구현됨 | store/startup/cold_start.dart:66-71, app/app/start_gate.dart:71-81 |
| A:50 | 불변식 5: 원본과 캐시가 어긋나지 않음 | 구현됨 | store/records/record_store.dart:23-34, 122-138 |
| A:51 | 불변식 6: 1인이 끝까지 유지 가능 | 부분 | 판 릴리스 자동화 없음(dataset 잡 없음), 판 사이 변경 리포트 없음. .github/workflows에 lint-test.yml만 |
| A:53 | 복잡도 규칙: 측정 없이 메커니즘 넣지 않음 | 구현됨 | 정책. 작업 격리 미도입이 사례(A:72) |
| A:59 | 전체 재해석은 배경 빌드 없이 시작할 때 한 번에 | 구현됨 | store/records/cache_rebuild.dart:17-24 |
| A:60 | 통계 캐시 없음, 판정은 순수 함수 | 구현됨 | store/records/record_queries.dart:115-125, core/score/scorer.dart:78 |
| A:61 | 지도용 탄 구간 집합은 캐시 없이 SQL | 구현됨 | store/records/record_queries.dart:95-98 |
| A:62 | 한 파일로 충분, 정수 키로 줄임 | 구현됨 | store/db/tables.dart:162-177 |
| A:72 | 작업 격리를 아직 만들지 않음 | 대상 아님 | 근거 A:72 "작업 격리를 아직 만들지 않습니다" |
| A:72 | 기록이 많을 때 재서 예산을 넘으면 작업 격리를 넣음 | 미구현 | 측정 도구와 기록 없음. A:631 남은 실험과 같음 |
| A:72 | 60fps와 저장 반영 시간 측정 | 부분 | 벤치 파일과 integration_test 폴더 없음 (find 0건). ARCHITECTURE §0.2, §2.6 |
| A:76 | 단일 저장소, pub workspace | 구현됨 | pubspec.yaml:7-10 |
| A:80 | apps/noriori Flutter 앱 | 구현됨 | apps/noriori/ |
| A:82 | noriori_core 순수 Dart, I/O와 Flutter 금지 | 구현됨 | packages/noriori_core/pubspec.yaml, tools/check_boundaries.py:18-21 |
| A:83 | noriori_store: drift, DB, 쿼리, 변경 적용, 팩 선택 | 구현됨 | packages/noriori_store/lib/src/ |
| A:84 | tools/, data/ 파이프라인 | 구현됨 | tools/, data/ |
| A:85 | build/ 데이터 산출물은 git 제외 | 구현됨 | .gitignore:25 |
| A:87 | .github/workflows/ | 구현됨 | .github/workflows/lint-test.yml |
| A:90 | 의존 방향 apps → store → core 검사 | 구현됨 | tools/check_boundaries.py:22-24, lint-test.yml:31 |
| A:90 | core의 I/O 금지 검사 | 구현됨 | tools/check_boundaries.py:18-20 |
| A:90 | 기능끼리 직접 import 금지 검사 | 구현됨 | tools/check_boundaries.py:30-32 |
| A:90 | 화면의 저장소 접근 금지 검사 | 구현됨 | tools/check_boundaries.py:33 |
| A:98 | Flutter stable 3.47.1 | 구현됨 | .github/workflows/lint-test.yml:11 |
| A:99 | maplibre_gl + 로컬 PMTiles | 구현됨 | apps/noriori/pubspec.yaml:21, app/features/map/map_style.dart |
| A:100 | drift + SQLite | 구현됨 | store/db/user_db.dart |
| A:101 | Riverpod | 구현됨 | app/app/session_providers.dart |
| A:102 | go_router, 탭별 스택 유지 | 구현됨 | app/app/router.dart:43-51 |
| A:103 | slang | 구현됨 | apps/noriori/slang.yaml |
| A:104 | fl_chart (통계 P1) | 대상 아님 | 자체 위젯으로 그림 (시안 묶음 2). 문서에서 뺌 |
| A:106 | 버전은 pubspec.lock에 고정 | 구현됨 | pubspec.lock |
| A:106 | 지도 패키지를 올릴 때마다 지도 벤치 재실행 | 미구현 | 지도 벤치 없음 |
| A:112 | 화면 계층 features/*/ui, SQL과 규칙 판단 금지 | 구현됨 | tools/check_boundaries.py:33 |
| A:113 | 컨트롤러는 화면 상태를 불변 객체로 관리 | 구현됨 | app/features/record/controller/record_session_controller.dart:52-113 |
| A:114 | 유스케이스 계층 features/*/usecase | 구현됨(이름 다름) | usecase 폴더 없음. 여러 단계 묶기는 controller가 맡음: RecordSessionController.save, ImportController._save |
| A:115 | core는 값을 받아 결과를 주는 순수 함수 | 구현됨 | tools/check_boundaries.py:8,18-21 |
| A:116 | store는 쿼리와 트랜잭션, 규칙 판단 금지 | 구현됨 | store/startup/cold_start.dart:92 "판단은 core" |
| A:120 | UI 격리에서 행 높이 측정, TextPainter는 여기서만 | 미구현 | 행 높이 측정 없음. TextPainter는 번호 글자 그리기 1곳 app/features/record/ui/session_painters.dart:168 |
| A:120 | UI 격리에서 탑승일 변경 시 상태표 재적용 | 구현됨 | app/features/record/controller/record_session_controller.dart:249-296 |
| A:121 | 작업 격리 1개가 NetworkGraph, 펼치기, 재해석, 저장, CSV, 백업을 맡음 | 대상 아님 | 근거 A:72. Isolate 코드 없음, 전부 UI 격리와 drift 백그라운드 연결 |
| A:121 | 그래프는 첫 프레임 뒤에 만듦 | 문서 오류 | 코드는 콜드 스타트 안에서 먼저 읽음 app/app/bootstrap.dart interpreter. A:72도 "그동안 화면은 시작 화면"이라 A:121과 모순 |
| A:122 | drift 연결 쓰기 1개 + 읽기 풀 | 구현됨 | store/db/connection.dart:88-94 readPool 2 |
| A:124 | core는 저장소를 부르지 않음, 시나리오가 DB 없이 돎 | 구현됨 | core/records/derived.dart:99-102, packages/noriori_core/test/ |
| A:126 | 기능 폴더 map, record, line, stats, visit, search, settings, data | 문서 오류 | 기능 폴더는 map·record·stats·settings·data. ARCH §2.2 목록 낡음 |
| A:126 | 기능끼리 라우트와 공용 provider로만 만남 | 구현됨 | app/app/router.dart:22-28, tools/check_boundaries.py:30-32 |
| A:132 | /map 지도 홈, 하단 탭 | 구현됨 | app/app/router.dart:46 |
| A:132 | /map 큰 점수, (+) 버튼 | 문서 오류 | (+)는 시트에 있음 app/features/record/ui/continue_sheet.dart. 점수는 "작은 캡슐" app/features/map/ui/map_home_screen.dart:39, DESIGN:136 채택. A:132 표현이 낡음 |
| A:133 | /map/edge/:id, /map/station/:group 노선·역 정보 시트 | 구현됨(이름 다름) | 라우트 없이 모달 시트 app/app/router.dart:75-96, app/features/record/ui/map_sheets.dart:12-128. 지도 탭 app/features/map/ui/map_home_screen.dart:84-122 |
| A:134 | /record 노선별 목록과 탑승 기록, (+)는 검색 | 구현됨 | app/features/record/ui/record_home_screen.dart:20-56 |
| A:134 | /record 여러 개 선택 삭제 | 구현됨 | app/features/record/ui/record_list_screen.dart:40-50,67-87 |
| A:135 | /record/browse/:era/:category, :operator. 분류→회사→노선, 각 줄 진행률 막대 | 구현됨 | app/app/router.dart:61-77, app/features/record/ui/browse_screens.dart, line_tile.dart:81 |
| A:136 | /record/session 전체 화면 역 선택기 | 구현됨 | app/app/router.dart:33-38 |
| A:136 | 시작점을 쿼리로 (line, route, service, from) | 문서 오류 | 시작점은 provider open으로 넘김 A/features/record/controller/record_session_controller.dart. RecordSession이 상태를 소유한다는 ARCH §2.4와 맞음. §2.3 표 문구만 낡음 |
| A:137 | /record/:rideId 기록 수정, 재해석 답변 | 구현됨 | 방향·이설·모름 답 A/features/record/ui/record_edit_screen.dart:70-100,243-266 |
| A:138 | /search 노선·역 통합 검색, 지도·기록에서 진입 | 구현됨 | app/app/router.dart:32, map_home_screen.dart _SearchBar, record_home_screen.dart:22 |
| A:138 | /search 운전 계통 검색 | 구현됨 | app/features/record/controller/line_search_controller.dart:36-39,51-57 |
| A:139 | /visit/:group 역 방문 기록 | 구현됨(이름 다름) | 라우트 없이 시트 A/features/record/ui/map_sheets.dart:18. 방문일 입력 :229,264, A/features/record/controller/record_list_controller.dart:104 |
| A:140 | /stats 완주율, 사업자·노선·도도부현 | 구현됨 | app/features/stats/ui/stats_screen.dart:208-218 |
| A:141 | /line/:id 노선 상세, 구간 탭, 범위 지정, 계통 칩 | 구현됨 | app/app/router.dart:46-49, app/features/record/ui/line_detail_screen.dart 구간 탭 :78-86, 범위 :122-156, 계통 칩 :309-319 |
| A:142 | /settings, /settings/data 백업 | 구현됨 | app/features/data/ui/data_settings_screen.dart |
| A:142 | /settings/data의 CSV | 구현됨 | app/features/data/ui/data_settings_screen.dart:75-90 내보내기와 가져오기 |
| A:142 | /settings/data의 데이터셋 | 부분 | 판 번호와 규모 표시뿐 app/features/settings/ui/settings_screen.dart:37-48. 데이터셋 확인과 내려받기 없음 |
| A:142 | /settings/data의 변경 내역 | 구현됨 | `CacheRebuild`, `watchChangeReports`, `NewsHistoryScreen` |
| A:142 | 라우트 표가 코드와 일치 | 문서 오류 | 코드의 /settings/sources, /settings/data/restore가 표에 없음. /settings/data는 표에서 하단 탭이나 실제는 탭 밖 app/app/router.dart:39-41 |
| A:143 | /settings/data/import 노리츠부시 CSV 가져오기, 탭 밖 | 구현됨 | app/app/router.dart:42, app/features/data/ui/import_screen.dart |
| A:144 | /settings/deleted 삭제한 기록 복원 (P1) | 구현됨 | app/app/router.dart:55, app/features/data/ui/deleted_screen.dart:9-65 |
| A:148 | 루트 provider packProvider, 값은 시작 때 고른 팩 | 구현됨(이름 다름) | sessionProvider, editionProvider, networkProvider 등을 시작 결과로 덮어씀 app/app/session_providers.dart:10-45, start_gate.dart:71-81 |
| A:148 | 화면에 팩 교체 처리 코드 없음 | 구현됨 | 세션 안 교체 없음. app/app/session_providers.dart:9 |
| A:149 | 사용자 기록은 drift watch, 지도·통계는 묶어서 한 번 재계산 | 구현됨 | store/records/record_queries.dart, app/app/session_providers.dart:147-158 |
| A:150 | 입력 상태를 RecordSession 하나가 소유 | 구현됨(이름 다름) | recordSessionProvider, autoDispose 아님 app/features/record/controller/record_session_controller.dart:169-174 |
| A:150 | 분기 줄을 탭해 다른 노선으로 넘어가도 세션 유지 | 구현됨 | app/features/record/controller/record_session_controller.dart:354-375, app/features/record/ui/session_lines.dart:449-466 |
| A:150 | 5초 되돌리기가 앞 노선 선택을 복원 | 대상 아님 | app/features/record/controller/record_session_controller.dart:378-382, app/features/record/ui/session_lines.dart:463 |
| A:151 | 세션 선택은 from(route, seq, node), to(route, seq, node) | 구현됨(이름 다름) | StopPick(seq,node) + state.routeId, 계통 넘는 출발역은 _carried A/features/record/controller/record_session_controller.dart:284,415. 동작 차이 없음. 문서 타입 이름만 낡음 |
| A:151 | 계통 칩을 바꿔도 출발역 유지 | 구현됨 | record_session_controller.dart:234-246 |
| A:151 | 운전 계통 입력이면 serviceId를 듦 | 구현됨(이름 다름) | 운전 계통은 별도 세션 app/features/record/controller/service_session_controller.dart:7-70, 저장 때 core/network/service_splitter.dart:170 |
| A:152 | 설정은 setting 테이블이 원본, provider는 캐시 | 구현됨 | 설정 항목은 setting 저장 A/app/session_providers.dart:152-186. 통계 기준과 지도 칩은 설정 항목이 아닌 화면 상태 |
| A:158 | RouteSnapshot: 계통의 stop, link, 이름을 날짜 정수 배열로 한 번 읽음 | 미구현 | RouteSnapshot 검색 0건 |
| A:159 | SelectorBuilder가 탑승일로 List<SelectorRow>를 만듦 | 구현됨 | core/network/selector.dart:80-. 입력은 스냅숏 대신 Network |
| A:159 | 탑승일을 바꿔도 DB를 다시 읽지 않음 | 미구현 | _refresh가 날짜 변경마다 routeLinks, nodeNames를 읽음 app/features/record/controller/record_session_controller.dart:409-465 |
| A:160 | 행 높이를 TextPainter로 재고 (문자열, 크기, 폭)별 캐시 | 미구현 | 행 높이 측정과 캐시 없음. app/features/record/ui/session_painters.dart:168은 번호 글자뿐. 행 높이는 고정값 app/features/record/ui/session_lines.dart:148 |
| A:161 | 지연 목록, 행마다 CustomPainter | 구현됨 | record_session_screen.dart ListView.builder, _RailMark |
| A:161 | 탭하면 범위 안의 행만 다시 그림 | 미구현 | 모든 _StopTile이 recordSessionProvider 전체를 watch app/features/record/ui/session_lines.dart:138 |
| A:163 | 골든 이미지로 표시 규칙 고정 | 미구현 | matchesGoldenFile 0건 |
| A:169 | 기본 배경 base.pmtiles (일본 윤곽, 도도부현 경계) 앱 내장 | 구현됨 | `base.pmtiles`, `tools/gen_base.sh` |
| A:170 | 온라인 배경 OpenFreeMap, 없어도 지도가 보임 | 구현됨 | map_style.dart base 소스, land 배경과 rail은 로컬 |
| A:171 | 선로, 역은 rail.pmtiles | 구현됨 | map_style.dart rail 소스, tools/gen_tiles.py |
| A:172 | 옛 선로 rail-osm.pmtiles, 없으면 표식 | 구현됨 | apps/noriori/assets/pack/rail-osm.pmtiles 있음, T/sync_pack.sh:12, S/pack/pack_folder.dart:44 |
| A:173 | 탑승 표시는 저장할 때 ride_edge에서 갱신 | 구현됨 | app/features/map/ui/map_home_screen.dart:116, record_queries.dart:95 |
| A:174 | 위치 미확인 표식 | 구현됨 | pack map_marker 115행, T/gen_tiles.py:92, A/features/map/map_style.dart:147,411, A/features/map/ui/map_home_screen.dart:271, 시트 A/features/record/ui/map_sheets.dart MarkerSheet |
| A:176 | feature state 쓰지 않음 | 구현됨 | map_style.dart, map_home_screen.dart |
| A:180 | 후보 A: 타일 정수 ID에 match 필터 | 구현됨 | map_style.dart:24-41 |
| A:183 | in이 아니라 match | 구현됨 | map_style.dart:24-30 |
| A:183 | 전 구간 탄 상태와 절반 탄 상태 둘 다 재서 A·B 결정 | 구현됨 | ARCHITECTURE §2.6 실측 (Note10, 절반 41~82ms, 거의 전부 58~109ms), A 채택. iOS 측정은 AR:L531 |
| A:183 | 둘 다 MapPaintPort 뒤에 둠 | 구현됨 | map_home_screen.dart:17-30 |
| A:183 | B를 쓰지 않으면 edge_shape를 배포에서 뺌 | 구현됨 | edge_shape, junction, denominator를 판에서 뺌 (tools/gen_tiles.py, pack-master.sqlite) |
| A:186 | 지도 점은 역 묶음 단위 | 구현됨 | tools/gen_tiles.py:33-46 |
| A:186 | 역 피처에 g, 폐역 여부, 시작·끝 연도, ko·ja·en | 구현됨 | 역 fy T/gen_tiles.py:84-85, g·hub·closed·ty·ja·ko·en :83,86-87 |
| A:187 | 3상태(미방문, 통과, 발로 밟음)를 StationState가 묶음별 계산, 지도 칠하기 | 구현됨(이름 다름) | StationMarks core/network/station_state.dart:4-41, 지도 app/features/map/map_style.dart:245-281, app/features/map/ui/map_home_screen.dart:150-152 |
| A:188 | 글자는 ['get', lang]로 고름 | 구현됨 | 글리프를 앱에 내장 (한글 포함). 명세 고침 |
| A:188 | 한자·가나·한글은 기기 글꼴, 라틴 글리프 앱 내장 | 구현됨 | 글리프를 앱에 내장 (한글 포함). 명세 고침 |
| A:190 | 표식의 (anchor_node, bearing)을 빌드가 만듦 | 구현됨 | tools에 없음, 팩에 없음 |
| A:194 | theme/tokens.dart 하나에 색 토큰 | 구현됨 | app/app/theme/tokens.dart |
| A:194 | 지도 스타일 JSON도 토큰에서 만듦 | 구현됨 | app/features/map/map_style.dart:1-8 |
| A:194 | 행 높이는 글자 크기의 함수, 최소 48dp | 구현됨 | record_session_screen.dart:343 minHeight 58 + IntrinsicHeight |
| A:194 | 화면 낭독 문구는 core의 A11yLabel이 만듦 | 부분 | A11yLabel 0건. 역 행만 화면이 직접 조립 app/features/record/ui/session_lines.dart:169-175 |
| A:202 | user.sqlite (-wal 포함) OS 백업 포함 | 구현됨 | android res/xml/backup_rules.xml, data_extraction_rules.xml |
| A:203 | photos/ OS 백업 제외, 자동 백업 포함 | 대상 아님 | 2026-11-03 결정: 사진 뺌 |
| A:204 | quarantine/ 손상 파일 보존, OS 백업 제외 | 구현됨 | store/startup/user_db_file.dart:99-112, cold_start.dart:29 |
| A:205 | datasets/ 데이터 팩, OS 백업 제외 | 구현됨 | store/pack/pack_folder.dart, cold_start.dart:29 |
| A:206 | 판 폴더에 master, names, rail, manifest, 선택 rail-osm | 구현됨 | store/pack/pack_folder.dart:122-139, pack_manifest.dart:21. 주석은 아직 옛 이름 pack_manifest.dart:20 |
| A:207 | 앱 자산에 팩 | 구현됨 | app/app/bundle_pack_assets.dart |
| A:212 | 모든 변경은 RecordStore.apply를 지나고 원본과 캐시를 한 트랜잭션에 | 구현됨 | store/records/record_store.dart:23-34. 복원만 시각 보존을 위해 merge(:39-48), 같은 _write |
| A:213 | 캐시 키 cache_state(edition, app_build) | 구현됨 | store/records/cache_rebuild.dart:17-24 |
| A:214 | SQL은 최소 effective_hi만, 판정은 Scorer 하나 | 구현됨(이름 다름) | record_queries.dart:115-125, core/score/scorer.dart computeScore·unitCounts. 분모 배열은 메모리 Network |
| A:215 | 계산 못 한 기록은 ride_cache에 error, 나머지 계속 | 구현됨 | core/records/derived.dart:105-111, tables.dart |
| A:216 | 공간 부족이면 저장 트랜잭션 실패, 화면에 알리고 입력 유지 | 구현됨 | record_session_screen.dart:513-526, apps/noriori/test/flows_test.dart:268 |
| A:217 | 삭제는 deleted_at, 삭제된 기록의 캐시 행 제거 | 구현됨 | store/records/record_store.dart:130 |
| A:220 | 판 폴더 불변 | 구현됨 | store/pack/pack_folder.dart:122-139 덮어쓰기 없음 |
| A:221 | 경로는 앱 지원 폴더 기준 상대 경로만 | 구현됨 | store/startup/cold_start.dart:18-30. DB에 경로 저장 없음 |
| A:222 | 해시는 첫 복사 때 검사 | 구현됨 | store/pack/pack_folder.dart:127-132 |
| A:222 | 시작할 때는 파일 크기와 SQLite 헤더만 | 구현됨 | store/pack/pack_folder.dart:142-152 |
| A:223 | 연결마다 팩 두 파일을 mode=ro&immutable=1로 ATTACH | 구현됨 | store/db/connection.dart:73-85 |
| A:223 | drift 열기를 Sqlite3 래퍼로 uri: true | 구현됨 | store/db/connection.dart:17-30 |
| A:224 | 앱 코드는 node가 아니라 node_public을 읽음 | 부분 | T/compile.py에 sys.exit 없음, ERR는 report.json에만. lint-test.yml은 check_boundaries, all.sh, core_fixture, sync_pack. audit_db·invariants·appsim·model_check 미실행. T/check_boundaries.py에 node 규칙 없음 |
| A:224 | 호환판 CSV의 export_name 쿼리를 내보내기 파일에 격리 | 구현됨 | store/pack/pack_reader.dart:99-136 exportNames, 내보내기만 씀 |
| A:225 | 백그라운드로 갈 때 체크포인트 | 구현됨 | app/app/start_gate.dart:203-206, cold_start.dart:87 |
| A:226 | synchronous=FULL | 구현됨 | store/db/connection.dart:81 |
| A:227 | 시작 때 들여다보는 연결은 읽기 전용 | 구현됨 | store/startup/user_db_file.dart:50-54 |
| A:232 | DateSpan: EDTF 원문 + lo, hi, 모름 null, 진행 중 ongoing | 구현됨 | core/date/date_span.dart |
| A:233 | Selection { route, seq, node } | 구현됨(이름 다름) | StopPick(seq,node) + state.routeId, 계통 넘는 출발역은 _carried A/features/record/controller/record_session_controller.dart:284,415. 동작 차이 없음. 문서 타입 이름만 낡음 |
| A:234 | RideDraft { from, to, date, dateInput, service, ... } | 구현됨(이름 다름) | StopPick(seq,node) + state.routeId, 계통 넘는 출발역은 _carried A/features/record/controller/record_session_controller.dart:284,415. 동작 차이 없음. 문서 타입 이름만 낡음 |
| A:235 | ResolvedRide { legs, status, effective } | 구현됨(이름 다름) | Expansion + RideDerived core/network/route_resolver.dart:38, core/records/derived.dart:65 |
| A:236 | ResolvedLeg { lineId, routeId, fromNode, toNode, edges, km } | 구현됨(이름 다름) | ExpandedLeg + LegDerived. from·to 노드는 없음 |
| A:237 | ResolveStatus { ok, partial, needsInput, unknownRef, invalid } | 구현됨 | core/records/derived.dart:5-17, error 추가(A:389) |
| A:238 | NetworkGraph: 판 전체를 정수 배열로, 날짜별 그래프 | 구현됨(이름 다름) | Network core/network/network.dart:37. 문자열 Map이고 정수 배열 아님 |
| A:239 | Change { before, after }, 되돌리기는 before로 새 Change | 구현됨 | core/records/change.dart |
| A:242 | NetworkGraph는 판마다 한 번 만들어 DB 왕복 없이 탐색 | 구현됨 | app/app/bootstrap.dart interpreter, session_providers networkProvider |
| A:242 | NetworkGraph를 작업 격리에 둠 | 대상 아님 | 근거 A:72 |
| A:248 | DateRules: 날짜, 구간 → 저장 날짜 | 구현됨(이름 다름) | core/date/date_rules.dart normalizeRideDate, stateOn, parseDateInput |
| A:249 | SelectorBuilder: 스냅숏, 탑승일 → 행 목록 | 구현됨 | core/network/selector.dart:80 |
| A:250 | RouteResolver: 선택 두 개, 날짜 → legs | 구현됨 | core/network/route_resolver.dart:92 |
| A:250 | 숨은 노드와 is_extension에서 leg 분할 | 구현됨 | route_resolver.dart:125-163, 470-501 |
| A:251 | MembershipAligner: legs → 그날의 line_id·route_id | 구현됨(이름 다름) | route_resolver.dart:427-450 _align, _lineOn. route_id는 입력 그대로 |
| A:252 | ServiceSplitter: 운전 계통 → 공식 구간 legs | 구현됨 | core/network/service_splitter.dart:22-175, store/pack/network_reader.dart:49-73 |
| A:253 | LoopInput: 순환·올가미의 방향, 한 바퀴 | 구현됨(이름 다름) | LoopInput 이름은 없고 app/features/record/controller/record_session_controller.dart:483-495, app/features/record/ui/session_lines.dart:80-107, app/features/record/ui/session_save_bar.dart:174-205, route_resolver.dart:268 |
| A:254 | EffectiveDate: 기록 → 유효 날짜 범위 | 구현됨 | 승계 끔 켜기, 유효 날짜 양쪽 교집합, 변경 내역 트랜잭션·날짜·빌드, 판 번호 수 비교, 역대 표 지금 노선 이름 (공개 전 검토) |
| A:255 | ride_cut.dart: cutSection, 범위 지정 (v0.11에서 RideEditor 대신) | 구현됨 | core/network/ride_cut.dart:45-119 |
| A:256 | StationState: 방문, 승하차, 통과 → 묶음별 상태 | 구현됨 | core/network/station_state.dart:25-41 |
| A:257 | Scorer: 단위별 탑승 → 3기준 완주율 | 구현됨(이름 다름) | core/score/scorer.dart computeScore, scoreTable. 현행, 역대, 연도 |
| A:258 | NameLookup: ID, 노선, 날짜 → 이름 | 구현됨(이름 다름) | core/name/name_lookup.dart:14 pickName, store/pack/pack_reader.dart:95 |
| A:259 | DisplayRules: route_link → 캡슐, 곡선, 이어짐 묶음 | 구현됨 | core/network/display_rules.dart:158-382, app/features/record/controller/record_session_controller.dart:419-432 |
| A:260 | browseTree | 구현됨 | core/score/browse_tree.dart:124 |
| A:261 | lineStrip | 구현됨 | core/score/line_strip.dart:31 |
| A:262 | previewRide | 구현됨 | core/score/ride_preview.dart:36, record_session_controller.dart:331 |
| A:263 | prefScores, 경계 구간은 edge_pref로 나눔 | 구현됨 | core/score/pref_scores.dart:5 |
| A:264 | percentLabel, kmLabel, dateLabel | 구현됨 | core/score/score_format.dart, core/date/date_rules.dart:80 |
| A:265 | Reinterpreter: 기록, 그래프 → 파생 값, 상태 | 구현됨(이름 다름) | core/network/ride_interpreter.dart:10 RideInterpreter, store/records/cache_rebuild.dart |
| A:265 | Reinterpreter: 변경 내역 | 구현됨 | `CacheRebuild`, `watchChangeReports`, `NewsHistoryScreen` |
| A:266 | parseNoritsubushiCsv | 구현됨 | core/importing/noritsubushi_csv.dart:58 |
| A:266 | CsvMatcher | 구현됨 | core/importing/csv_import.dart:61 |
| A:266 | planImport | 구현됨 | core/importing/csv_import.dart:231 |
| A:266 | importedRide | 구현됨 | core/importing/csv_import.dart:260 |
| A:270 | 모든 변경은 Change 하나 (저장, 수정, 삭제, 구간 탭, 일괄 삭제, CSV, 복원) | 문서 오류 | M22. 구현 S/records/record_store.dart:42-57 |
| A:272 | 저장과 재해석이 같은 순수 함수 | 구현됨 | route_resolver.dart:100 record를 양쪽이 씀: record_session_controller.dart:354, ride_interpreter.dart:31 |
| A:274 | date_input이 원본, date는 계산 값 | 구현됨 | core/records/record.dart:119, derived.dart |
| A:275 | 하한이 기준일보다 이르면 날짜 없음 | 구현됨 | core/date/date_rules.dart:10-13 |
| A:276 | 그 날짜로 펼치고, 없으면 날짜 없이, 어느 쪽도 없으면 invalid. 범위는 겹치면 탈 수 있음 | 구현됨 | route_resolver.dart:100-122, date_rules.dart:16-31 |
| A:277 | 경로가 둘 이상이면 저장할 때 물음 (범위가 이설에 걸쳐도) | 구현됨 | record_session_controller.dart:375-386, record_session_screen.dart:533-579 |
| A:277 | 재해석에서는 묻지 않고 needs_input | 구현됨 | core/network/ride_interpreter.dart:43-45. 닫힌 계통 예외는 A:566 행 |
| A:278 | MembershipAligner로 그날 노선과 계통을 맞춤 | 구현됨(이름 다름) | route_resolver.dart:427 |
| A:279 | EffectiveDate로 유효 범위, 비면 날짜 없이 5번부터 다시 | 구현됨 | 승계 끔 켜기, 유효 날짜 양쪽 교집합, 변경 내역 트랜잭션·날짜·빌드, 판 번호 수 비교, 역대 표 지금 노선 이름 (공개 전 검토) |
| A:281 | 저장은 결과를 원본과 함께 한 트랜잭션 | 구현됨 | record_store.dart:122-132 |
| A:281 | 재해석은 캐시만 씀 | 구현됨 | cache_rebuild.dart:26-42 |
| A:281 | 집계와 표시는 캐시의 line_id, route_id | 구현됨 | record_queries.dart:63 coalesce(lc.line_id...), :107 |
| A:281 | 폐지일이 정정되면 date_input에서 날짜가 되살아남 | 구현됨 | ride_interpreter.dart:26-27,46 |
| A:281 | 순환의 한 바퀴는 from_node == to_node에 direction이 있는 leg | 구현됨 | app/features/record/controller/record_session_controller.dart:566,615, route_resolver.dart:179-184 |
| A:283 | updated_at = max(현재, 이전 + 1) | 구현됨 | core/records/change.dart:27-30, record_store.dart:27-29 |
| A:283 | 날짜를 고치면 resolve_as_of, resolve_unknown을 지우고 다시 펼침 | 구현됨 | core/records/record.dart:138-168, app/features/record/ui/record_edit_screen.dart:102-115 |
| A:283 | 하루로 정해진 날짜는 resolve_as_of보다 앞섬 | 구현됨 | route_resolver.dart:177 |
| A:286 | cutSection(ride, network, offUnits) 순수 함수, 조각마다 legs 재분할 | 구현됨 | core/network/ride_cut.dart:45-119,132-174 |
| A:287 | 조각 하나면 고침, 둘이면 앞 조각이 원래 ID, 없으면 삭제 표시 | 구현됨 | core/network/ride_cut.dart:81-83,93-118 |
| A:288 | 조각끼리 id, updated_at, legs, 잘린 끝만 다르고 나머지 복사, transfer_nodes는 경로 안만, 사진은 원래 ID | 구현됨 | core/records/record.dart:189-218, core/network/ride_cut.dart:101-104. 사진은 없음 |
| A:289 | 잘려서 생긴 끝은 통과 | 구현됨 | core/network/ride_cut.dart:105-106, ride_interpreter.dart:144 |
| A:290 | 덮는 기록이 여럿이면 전부 고치고 건수 표시, ride_edge로 찾음 | 구현됨 | app/features/record/controller/line_detail_controller.dart:71-114, store/records/record_queries.dart:169-178 |
| A:291 | 끈 구간 자체도 삭제 표시 조각으로 남음 | 구현됨 | core/network/ride_cut.dart:95-118 |
| A:292 | 켜기: 같은 삭제 조각을 되살리거나 날짜 없는 새 기록 | 구현됨 | 승계 끔 켜기, 유효 날짜 양쪽 교집합, 변경 내역 트랜잭션·날짜·빌드, 판 번호 수 비교, 역대 표 지금 노선 이름 (공개 전 검토) |
| A:293 | 숨은 노드에서 끊어야 하면 안내만 | 구현됨 | core/network/ride_cut.dart:89-91, app/features/record/ui/line_detail_screen.dart:67-68 |
| A:295 | 되돌리기는 Change.before로 새 변경을 만들어 apply | 구현됨 | core/records/change.dart:15-23, record_list_controller.dart:34 |
| A:295 | 되돌림으로 없어지는 새 행은 삭제 표시 | 구현됨 | core/records/change.dart:20 |
| A:295 | 5초가 지나면 Change.before를 버림 | 구현됨 | record_list_screen.dart:22, ride_ticket.dart:30 스낵바 수명 |
| A:295 | 그 뒤의 복구는 삭제한 기록 화면 | 구현됨 | app/features/data/ui/deleted_screen.dart:9-65 |
| A:301 | 이관 전 날짜: lineage로 앞 노선 계통을 찾아 판정, 저장은 그날 노선 | 구현됨 | core/network/selector.dart:214 _earlierLine, network.dart:141-149 |
| A:302 | 펼치기는 날짜별 그래프로 | 구현됨 | route_resolver.dart:185-192 |
| A:303 | km_cum은 표시용, 탑승 거리는 edge_km 합 | 구현됨 | network.dart:88 metersOf |
| A:304 | 이설과 날짜 모름: 선택지는 시점별 경로 | 구현됨 | route_resolver.dart:347-359 |
| A:305 | 올가미 방향은 고리 위 다음 역으로 판정 | 구현됨 | route_resolver.dart:409-425 |
| A:306 | 폐지일 없는 역은 선로 상태까지 봄 | 구현됨 | selector.dart _state |
| A:307 | edge_life suspended 기간은 탑승 불가 | 구현됨 | network.dart:150-164 |
| A:307 | suspended 기간에도 역 방문은 가능 | 구현됨 | 방문은 구간 상태를 보지 않음 app/features/record/ui/map_sheets.dart:29-41, app/features/record/ui/line_detail_screen.dart:88-113 |
| A:308 | 숨은 끝: is_extension 역이면 그 역의 계통으로 leg 분할 | 구현됨 | route_resolver.dart:125-163 |
| A:309 | 분모는 denominator_unit 합산 | 구현됨 | core/score/scorer.dart:57-68 |
| A:309 | 날짜가 불확실한 단위는 판정 불가로 뺌 | 부분 | certainty 열을 읽지 않음 store/pack/network_reader.dart:41. 지금 팩은 23,130행 전부 certain이라 영향 없음 |
| A:310 | 분기 기간은 route_link의 기간 | 구현됨 | selector.dart _linkOn |
| A:311 | 계통 칩: 본선은 본선, 나머지 route 이름 | 구현됨 | record_session_screen.dart:29-33 |
| A:311 | alias는 CSV 변환 전용 | 구현됨 | store/pack/pack_reader.dart:75-92 |
| A:312 | 오늘은 JST | 구현됨 | core/date/date_rules.dart:36, app/app/session_providers.dart:106 |
| A:313 | id_redirect는 읽을 때만 적용 | 미구현 | 읽는 코드 0건. 팩의 id_redirect 0행 |
| A:314 | visit은 노드와 date_input 저장, 묶음과 날짜는 파생 | 구현됨 | 방문일 입력 A/features/record/ui/map_sheets.dart:229, A/features/record/controller/record_list_controller.dart:104 |
| A:315 | 역 이전: lineage와 node_move로 순서를 맞춤, 캐시에서만 | 미구현 | node_move 없음. Reinterpreter에 해당 코드 없음 |
| A:316 | 범위 날짜는 (하한, 상한)으로 비교 | 구현됨 | core/date/date_rules.dart:16-31 |
| A:317 | 계산된 날짜가 없는 기록만 created_at JST가 상한 | 구현됨 | ride_interpreter.dart:115 |
| A:321 | 활성 판을 저장하지 않고 시작마다 고름 | 구현됨 | store/pack/pack_folder.dart:63-85 |
| A:325 | 0. user.sqlite 열기 → user_version 확인 | 구현됨 | store/startup/user_db_file.dart:50-72 |
| A:325 | 0. 필요하면 VACUUM INTO 사본 뒤 마이그레이션 | 구현됨 | user_db_file.dart:75-87, cold_start.dart:181-195 |
| A:326 | 사본이나 마이그레이션 실패 시 파일 유지, 재시도 화면 | 구현됨 | cold_start.dart:192-194, app/features/data/ui/blocked_start_screen.dart |
| A:327 | 손상이면 quarantine/으로 옮기고 복원 전용 화면 | 구현됨 | cold_start.dart:142-145 |
| A:328 | quarantine/에 파일이 있으면 복원을 마칠 때까지 빈 DB로 안 감 | 구현됨 | core/startup/user_db_decision.dart:55 |
| A:329 | 1. .tmp-* 삭제 | 구현됨 | pack_folder.dart:101-105 |
| A:330 | 2. 지원 스키마에서 가장 높은 판 | 구현됨 | 승계 끔 켜기, 유효 날짜 양쪽 교집합, 변경 내역 트랜잭션·날짜·빌드, 판 번호 수 비교, 역대 표 지금 노선 이름 (공개 전 검토) |
| A:331 | 자산 팩이 뽑혔는데 폴더에 없으면 .tmp로 복사 후 이름 변경 | 구현됨 | pack_folder.dart:122-139 |
| A:332 | 3. 크기와 헤더 확인, 깨졌으면 폴더 지우고 2번 | 구현됨 | pack_folder.dart:71-83 |
| A:333 | 4. cache_state가 다르면 전체 재해석, 한 트랜잭션 | 구현됨 | cache_rebuild.dart:17-42 |
| A:333 | 4. 진행 표시 | 구현됨 | 시작 화면 스피너와 문구 A/app/start_gate.dart:121-133. 명세는 진행률 숫자를 요구하지 않음 |
| A:333 | 4. 변경 내역 저장 | 구현됨 | 승계 끔 켜기, 유효 날짜 양쪽 교집합, 변경 내역 트랜잭션·날짜·빌드, 판 번호 수 비교, 역대 표 지금 노선 이름 (공개 전 검토) |
| A:334 | 5. 화면 | 구현됨 | app/app/start_gate.dart:46-56 |
| A:335 | 6. 쓰지 않는 팩 폴더 삭제 | 구현됨 | start_gate.dart:192-194, cold_start.dart:84 |
| A:338 | 모든 단계는 재실행 안전, 마이그레이션과 4번은 트랜잭션 | 구현됨 | store/db/user_db.dart:47-63, cold_start_test.dart:172,232,250 |
| A:338 | PRAGMA user_version도 같은 트랜잭션 | 구현됨 | user_db.dart:44-46,84 |
| A:338 | 사본은 임시 이름, 남은 임시 파일 먼저 삭제 | 구현됨 | user_db_file.dart:75-87 |
| A:339 | 복원 전용 화면에 JSON 복원과 격리 파일 내보내기 | 구현됨 | app/features/data/ui/restore_screen.dart:99-111 |
| A:340 | 세션 중 교체 없음 | 구현됨 | cold_start.dart:66 |
| A:340 | 내려받기는 폴더에 넣는 것까지, 적용은 다음 시작 | 미구현 | 내려받기 없음 |
| A:341 | 앱 업데이트, OS 복원도 같은 길 | 구현됨 | cold_start.dart:126-178 |
| A:342 | 판은 앞으로만 | 구현됨 | core/pack/pack_choice.dart |
| A:343 | 재해석 결과가 같으면 조용히, 다르면 변경 내역 표시 | 구현됨 | 승계 끔 켜기, 유효 날짜 양쪽 교집합, 변경 내역 트랜잭션·날짜·빌드, 판 번호 수 비교, 역대 표 지금 노선 이름 (공개 전 검토) |
| A:343 | 비교는 옛 ride_cache로 함 | 구현됨 | `CacheRebuild`, `watchChangeReports`, `NewsHistoryScreen` |
| A:345 | 내려받기: manifest와 .sig를 받아 서명 확인 | 미구현 | 서명 코드 0건 |
| A:345 | 내려받기: 스키마 확인 | 미구현 | 내려받기 없음 |
| A:345 | 내려받기: .tmp-<판>/에 받고 해시 확인 후 이름 변경 | 미구현 | 내려받기 없음. .tmp 정리만 있음 |
| A:345 | 내려받기: 공간이 모자라면 시작하지 않음, 중단되면 처음부터 | 미구현 | 내려받기 없음 |
| A:345 | 내려받기: 사용자가 누를 때만 | 미구현 | 내려받기 없음 |
| A:351 | 자동 백업: 사용자가 고른 위치 (Android SAF, iOS 폴더) | 구현됨 | android BackupFolderChannel.kt, ios AppDelegate.swift:68- |
| A:351 | 변경이 있으면 백그라운드로 갈 때 JSON을 씀 | 구현됨 | start_gate.dart:203-206, store/backup/auto_backup.dart:53-119 |
| A:351 | 새 파일을 다시 읽어 확인한 뒤에만 회전 | 구현됨 | auto_backup.dart:99-112,122-131 |
| A:351 | 읽을 수 있는 파일 3개 유지 | 구현됨 | core/backup/rotation.dart:19 |
| A:351 | 옛 파일은 병합이 무변경일 때만 지움 | 구현됨 | core/backup/rotation.dart:25-38, core/records/merge.dart:8-16 |
| A:351 | 재설치, OS 복원 뒤 옛 파일을 지우지 않고 병합 복원을 물음 | 구현됨 | auto_backup.dart:73-75, backup_notice.dart:35 |
| A:351 | 읽지 못한 파일은 지우지 않고 지도 홈에 표시 | 구현됨 | auto_backup.dart:65-71, app/features/data/ui/backup_notice_bar.dart |
| A:351 | 같은 위치 photos/에 해시 이름으로 새 사진만 복사 | 대상 아님 | 2026-11-03 결정: 사진 뺌 |
| A:351 | 설정에 마지막 백업 시각 | 구현됨 | data_settings_screen.dart:39-43 |
| A:351 | 오래됐거나 실패하면 지도 홈에 표시 | 구현됨 | core/backup/backup_notice.dart |
| A:352 | 수동 백업: 같은 JSON과 사진을 ZIP으로 | 대상 아님 | 2026-11-03 결정: 사진 뺌 |
| A:353 | 복원은 병합만. 같은 ID는 늦은 쪽, 같으면 로컬, 없는 ID 추가 | 구현됨 | core/records/merge.dart:2-3, record_store.dart:39-48 |
| A:353 | user.sqlite를 못 열 때도 복원 전용 화면에서 같은 절차 | 구현됨 | start_gate.dart:47-55 |
| A:354 | 머리말 kind, format, user_version, edition, app_build, exported_at, tables | 구현됨 | core/backup/backup_envelope.dart:24-31 |
| A:354 | 파일은 이름이 아니라 머리말로 알아봄 | 구현됨 | core/backup/backup_codec.dart:128-137. 우리 이름이면 깨져도 우리 파일로 침 |
| A:354 | 파일 user_version이 앱보다 높으면 거부하고 갱신 안내 | 구현됨 | backup_envelope.dart:66-71, restore_screen.dart:121 |
| A:354 | 더 낮으면 마이그레이션 순서대로 올려 병합 | 구현됨 | backup_codec.dart:87-91 |
| A:355 | 같은 내용(행 순서 무시) 파일이 있으면 쓰지 않고 실패도 아님, 시각은 그 파일 값 | 구현됨 | auto_backup.dart:72,78-87, backup_controller.dart:131-133 |
| A:355 | 빈 DB는 쓰지 않음 | 구현됨 | auto_backup.dart:78 |
| A:356 | 안내 우선순위 병합 필요 > 실패 > 권한 소실 > 읽지 못한 파일 > 오래됨 > 폴더 없음 | 구현됨 | core/backup/backup_notice.dart:25-45 |
| A:356 | 바뀐 기록이 7일 넘게 백업 안 되면 오래됨, 바뀐 것 없으면 안 알림 | 구현됨 | backup_notice.dart:23,39-43 |
| A:357 | 옛 파일은 backupSteps로 올린 뒤 병합, 단계 없으면 읽지 못한 파일 | 구현됨 | backup_codec.dart:48,87-91, store/backup/backup_restore.dart:100 |
| A:358 | 복원 전용: 격리를 둔 채 빈 DB와 팩으로 세션, 탭 없음 | 구현됨 | start_gate.dart:84-96, cold_start.dart:126,132 |
| A:358 | 화면을 닫으면 quarantine/closed/로, 지우지 않음 | 구현됨 | user_db_file.dart:40-45 |
| A:358 | 닫기 전에 죽으면 복원한 행을 지키고 다시 이 화면 | 구현됨 | cold_start_test.dart:386 |
| A:358 | 같은 시각에 다시 격리해도 먼저 격리한 파일을 덮지 않음 | 구현됨 | user_db_file.dart:99-104 |
| A:359 | 마지막 마이그레이션의 사본 하나만 | 구현됨 | user_db_file.dart:90-96 |
| A:360 | 팩 복사, 사본, 마이그레이션, 재해석의 공간 오류는 파일 유지와 안내 | 구현됨 | cold_start.dart:161,171,193,201-214 |
| A:361 | Android 임시 이름으로 쓰고 이름 변경, 못 하면 바로 씀 | 구현됨 | BackupFolderChannel.kt:149-180 |
| A:362 | 앱 안 폴더는 저장하지 않고 다른 폴더를 고르게 함 | 구현됨 | BackupFolderChannel.kt:87, AppDelegate.swift:200-205, data_settings_screen.dart:17 |
| A:363 | OS 백업은 user.sqlite와 -wal만, 사진 제외 | 구현됨 | android res/xml/*.xml, bootstrap.dart excludeFromOsBackup |
| A:363 | 20MB를 넘으면 설정에 안내 | 미구현 | 크기 검사 0건 |
| A:364 | user_version이 앱보다 높으면 열지 않고 갱신 안내 | 구현됨 | user_db_decision.dart:62-63, blocked_start_screen.dart |
| A:365 | 스키마 변경 전 VACUUM INTO, 캐시는 마이그레이션 없이 다시 만듦 | 구현됨 | user_db.dart:52-63 |
| A:366 | 재설치 뒤 백업 폴더를 고르면 병합 복원을 먼저 물음 | 구현됨 | backup_controller.dart:102-109, backup_notice.dart |
| A:370 | 사용자 기록 ID는 UUIDv7 | 구현됨 | core/records/uuid.dart, record_session_controller.dart:392 |
| A:370 | 가져온 행은 UUIDv5 | 구현됨 | store/records/content_id.dart, import_controller.dart:97 |
| A:370 | 공통 컬럼, ride_leg는 ride에 묶임, setting은 자연키, 시각 UTC ms | 구현됨 | store/db/tables.dart:5-14,50-69,95-104 |
| A:376 | trip: title, note | 구현됨 | tables.dart:18-25. 스키마만, 앱에서 쓰는 곳 없음 |
| A:377 | ride 전 컬럼 | 구현됨 | tables.dart:28-47. times, train_name, car_no, note를 입력하는 화면 없음 |
| A:378 | ride_leg 전 컬럼 | 구현됨 | tables.dart:50-69 |
| A:379 | visit 전 컬럼 | 구현됨 | tables.dart:72-81 |
| A:380 | photo 전 컬럼 | 구현됨 | tables.dart:84-92. 쓰는 코드 없음 |
| A:381 | setting key, value | 구현됨 | tables.dart:95-104 |
| A:382 | change_report | 구현됨 | 쓰기 S/records/cache_rebuild.dart:49-66, 읽기 S/records/record_queries.dart:180, 화면 A/features/data/ui/news_screens.dart:108 |
| A:388 | cache_state | 구현됨 | tables.dart:119-129 |
| A:389 | ride_cache | 구현됨 | tables.dart:132-145 |
| A:390 | ride_leg_cache | 구현됨 | tables.dart:148-160 |
| A:391 | ride_edge와 인덱스 | 구현됨 | tables.dart:162-177 |
| A:392 | ride_node | 구현됨 | tables.dart:179-189 |
| A:393 | visit_cache | 구현됨 | tables.dart:191-202 |
| A:401 | 시드 단계: tools/all.sh가 data/source 생성 | 구현됨 | tools/all.sh:7-18 |
| A:402 | 유지 단계: data/source와 ids.lock이 원본, 도구는 후보 제안 | 미구현 | 동결 전. ids.lock 없음, gen_source.py가 여전히 data/source를 다시 씀 |
| A:404 | all.sh는 data/imports와 proto/를 읽고 네트워크를 씀, CI에서 돌릴 수 없음 | 문서 오류 | all.sh:3 네트워크 안 씀, tools에 proto 참조 0건, imports 없으면 건너뜀 :19, CI가 실제로 돌림 lint-test.yml:33. data/README:18이 맞음 |
| A:404 | imports 없이 compile.py만 돌려도 같은 DB | 구현됨 | tools/all.sh:18-21 |
| A:404 | 공개 준비 첫 단계에서 시드 동결 | 미구현 | 미실행 |
| A:408 | 공개 뒤 ID 재생성을 멈춤 | 미구현 | 동결 전. 빌드마다 ID 생성 |
| A:410 | 자연키 원장 만들지 않음 | 구현됨 | 원장 없음 |
| A:413 | 1. gen_source.py 결과를 data/source로 확정 | 미구현 | 미실행 |
| A:414 | 2. data/overrides를 data/source에 흡수 | 미구현 | overrides 23개 파일이 입력으로 남음 |
| A:415 | 3. gen_source.py는 candidates/에 차이만 제안 | 미구현 | gen_source.py가 source를 직접 씀 |
| A:416 | 4. ids.lock 생성 (추가 전용, 은퇴 목록) | 미구현 | 파일 없음 |
| A:421 | 검사: 삭제 금지 | 미구현 | 도구 없음 |
| A:422 | 검사: 재사용 금지 | 미구현 | 도구 없음 |
| A:423 | 검사: edge split 은퇴 자유, 재사용 금지 | 미구현 | 도구 없음 |
| A:424 | 검사: 지문 | 미구현 | 도구 없음 |
| A:426 | 타일의 n, g는 판 안에서만 유효, 기록에 저장 안 함 | 구현됨 | ride_edge는 캐시 tables.dart:162, ride에 저장 없음 |
| A:432 | 거리 정수화: edge_km, denominator_unit | 구현됨 | master.edge_km.m, denominator_unit.m, network_reader.dart |
| A:432 | 거리 정수화: edge_pref | 부분 | edge_pref는 km 실수 그대로, 앱이 반올림 store/pack/network_reader.dart prefs. A:449의 완료 표기에도 edge_pref는 없음 |
| A:433 | 분모 기간 date_lo, date_hi | 구현됨 | denominator_unit 스키마 |
| A:434 | 住吉 중복 병합 | 미구현 | n_sumiyoshi_nagasaki_tram_akasako_branch, n_sumiyoshi_nagasaki_tram_nagasaki_tram_main 둘 다 남음 build/master.sqlite node |
| A:435 | moved를 master의 node_move로 배포 | 미구현 | 테이블 없음. data/overrides/moved.json만 |
| A:436 | 인덱스 edge_pref, edge_km, route_edge(edge_id), name(entity_type, entity_id), node(group_id) | 구현됨 | ix_edge_pref_edge_id_, ix_edge_km_edge_id_, ix_route_edge_edge_id_, ix_name_entity, ix_node_group_id_ |
| A:437 | 검색 색인 한 글자 토큰, 읽기, 운전 계통, 옛 이름 포함 | 구현됨 | names.search: line, node, service. 新宿 19, 空港 34, しんじゅく 17, 주쿠 39, 中央快速 1건 |
| A:438 | 타일 필드 선로 n, 노선, 기간(연도) | 문서 오류 | 노선 필드 없이 n match로 단독 보기 동작 A/app/session_providers.dart:299-307 |
| A:438 | 타일 필드 역 g, 폐역 여부, 기간, 3개 언어 이름 | 구현됨 | 역 fy T/gen_tiles.py:84-85, g·hub·closed·ty·ja·ko·en :83,86-87 |
| A:439 | 현행 선형 공백 60구간 173.4km 메우기, 안 되면 approx | 구현됨 | 선형 복구 작업 중이라 판정 유지. build/check_geometry.json 20:55판 실패 41건 |
| A:440 | 표식 (anchor_node, bearing) 생성 | 구현됨 | tools와 팩에 없음 |
| A:441 | 서명 manifest.json과 분리한 manifest.json.sig | 미구현 | 서명 코드 0건, tools/gen_tiles.py:58 |
| A:442 | 빌드 날짜는 고정 값 주입 | 구현됨 | data/overrides/as_of.json, tools/lib.py:10, compile.py:7 |
| A:443 | denominator, junction 배포 제외 | 구현됨 | edge_shape, junction, denominator를 판에서 뺌 (tools/gen_tiles.py, pack-master.sqlite) |
| A:444 | 직통 표시 점검: continue 415행을 위키 노선도와 대조 | 미구현 | 대조 도구와 기록 없음. route_link.flow_source 1,375행 전부 빈 값 |
| A:445 | 분기 방향 route_link.side가 빈 125행 채움 | 구현됨 | redesign 3절 1단계: 분기 side 97행 채움, 28행은 각도로 판단 불가. pack route_link branch side NULL 28행 실측 |
| A:446 | 소소한 값: モンキーパーク line.type, 東山 역명, 東山本線 km 0.1 | 미구현 | line.type이 아직 rail (l_monkey_park_monorail). 나머지 두 건 처리 기록 없음 |
| A:447 | proto/build 의존 제거, 시나리오는 tools/appsim.py | 구현됨 | tools에 proto 참조 0건 |
| A:449 | 팩 스키마 2로 끝낸 것 | 구현됨 | tools/gen_tiles.py:58, 위 행들로 확인. edge_pref 제외 |
| A:461 | trigram 안 씀. 가나는 히라가나, ヶ류는 한 형태 | 구현됨 | core/name/name_lookup.dart:38-50, names.search tokenize unicode61 |
| A:467 | lint-test 잡: 모든 푸시 | 구현됨 | lint-test.yml:2 push, pull_request |
| A:467 | lint-test: Dart 분석 | 구현됨 | lint-test.yml:47 |
| A:467 | lint-test: core·store 테스트 | 구현됨 | lint-test.yml:48-51 |
| A:467 | lint-test: 의존 방향 | 구현됨 | lint-test.yml:31 |
| A:467 | lint-test: Python 검사 | 부분 | check_boundaries, all.sh 안의 verify·check_geometry. invariants, appsim, audit_db, model_check 미실행 .github/workflows/lint-test.yml |
| A:468 | dataset 잡: compile → gen_tiles → audit_db → 시나리오 → 쿼리 계획 검사, 판 간 변경 리포트 | 미구현 | 워크플로 없음. 쿼리 계획 검사 코드 0건 |
| A:469 | app-android 잡: APK | 미구현 | 워크플로 없음 |
| A:469 | app-ios 잡: 서명 안 된 IPA | 미구현 | 워크플로 없음 |
| A:471 | verify.py, audit_ext.py는 로컬에서 | 구현됨 | verify는 all.sh가 imports 없으면 건너뜀. audit_ext.py 존재 |
| A:471 | CI는 네트워크를 쓰지 않음 | 문서 오류 | lint-test.yml:26이 tippecanoe를 curl로 받음. 캐시로 줄일 뿐 |
| A:475 | 데이터 팩은 앱에 포함 | 구현됨 | tools/sync_pack.sh |
| A:475 | 같은 파일과 manifest, .sig를 GitHub Releases에 올림 | 미구현 | 릴리스 워크플로 없음 |
| A:475 | edition은 날짜, schema_version은 정수 | 구현됨 | build/manifest.json |
| A:475 | 필수 master, names, rail, manifest, 선택 rail-osm | 구현됨 | store/pack/pack_manifest.dart:21 |
| A:475 | 서명은 사람이 오프라인 키로 | 미구현 | 도구 없음 |
| A:477 | 앱 서명을 첫 공개 전에 정함 | 부분 | gradle이 key.properties를 읽고 없으면 막음 android/app/build.gradle.kts:11,43-70. 키는 사용자 몫(A:642) |
| A:478 | GitHub APK와 Play는 같은 키, Play App Signing | 미구현 | 미결정, 공개 준비 |
| A:479 | F-Droid는 재현 빌드가 될 때만, 안 되면 v1.0 뒤로 | 대상 아님 | 근거 A:479 "안 되면 v1.0 뒤로 미룹니다" |
| A:483 | 서버는 v1.0 범위 밖 | 대상 아님 | 근거 A:483 |
| A:485 | 동기화와 순위 대결은 홈 미니PC 한 대로 | 대상 아님 | 근거 A:483 |
| A:489 | 사용자 기록 ID를 UUIDv7로 | 구현됨 | record_session_controller.dart:392 |
| A:490 | updated_at, deleted_at, device_id | 구현됨 | tables.dart:5-14 |
| A:491 | 변경은 RecordStore.apply 한 곳 | 구현됨 | record_store.dart:23 |
| A:492 | 통계는 순수 함수 | 구현됨 | core/score/scorer.dart |
| A:494 | HLC, 슬롯, 전송 상태, 계정, 암호화는 만들지 않음 | 구현됨 | 코드 없음 |
| A:500 | 분석 도구와 텔레메트리 없음 | 구현됨 | pubspec, 검색 0건 |
| A:500 | 데이터셋 확인과 지도 배경 외 통신 없음 | 구현됨 | 네트워크 클라이언트 없음. 지도 소스뿐 |
| A:501 | core는 결과 타입으로 돌려줌, 기록은 버리지 않음 | 구현됨 | core/network/route_resolver.dart:38 Expansion, derived.dart:105 |
| A:502 | 로그는 기기 안 파일만, 내보내기는 사용자가 고름 | 미구현 | debugPrint뿐. 파일 로그와 내보내기 없음 |
| A:503 | 제보: ID가 채워진 GitHub 이슈 링크 | 미구현 | 0건 |
| A:504 | 라이선스 화면: 출처와 파일별 라이선스 | 구현됨 | app/features/settings/ui/data_sources_screen.dart, settings_screen.dart showLicensePage, app_theme.dart:11 |
| A:510 | 콜드 스타트 → 지도 1.5초, 통합 시험 | 부분 | 실측 846~876ms(A:69, 기록 없음). integration_test 없음 |
| A:511 | 저장 → 지도 100ms (전 구간, 절반 구간) | 부분 | 벤치 파일과 integration_test 폴더 없음 (find 0건). ARCHITECTURE §0.2, §2.6 |
| A:512 | 통계 200ms, 쿼리 계획 검사 + store 벤치 | 미구현 | 없음 |
| A:513 | 검색 50ms, 색인 벤치 | 미구현 | 없음 |
| A:514 | 기록 화면 첫 프레임 300ms, 東海道本線 위젯 벤치 | 미구현 | 없음 |
| A:515 | 탑승일 변경 다음 프레임, 상태표 재적용 벤치 | 미구현 | 없음. 지금은 DB 왕복이 끼어 있음 |
| A:521 | core 시험: 날짜, 경로, 상태표, 점수 표 기반 | 구현됨 | packages/noriori_core/test/ 155건, core_parity_test.dart |
| A:521 | core 시험: cutSection | 구현됨 | packages/noriori_core/test/ride_cut_test.dart:151-301 |
| A:522 | 데이터 계약: 판마다 시나리오 재실행, FAIL 0 | 부분 | tools/appsim.py 있음. all.sh, CI에 안 묶임 |
| A:523 | 불변식: tools/invariants.py, 판을 낼 때마다 실행 | 부분 | 도구 있음, 실행 묶음 없음 |
| A:524 | 재해석: 전 노선 × 여러 날짜의 합성 기록을 옛 판과 새 판에서 비교 | 부분 | tools/repro/ 시작점뿐 (A:564 미완) |
| A:525 | ID: 판 사이 지문 비교 | 미구현 | 도구 없음 |
| A:526 | store 시험: 옛 스키마 파일로 마이그레이션 | 구현됨 | cold_start_test.dart:215-268 |
| A:526 | store 시험: 쿼리 계획 | 미구현 | EXPLAIN QUERY PLAN 0건 |
| A:526 | store 시험: cutSection이 경로 외 열을 전부 보존 | 부분 | 경로 외 열 보존은 core 시험 packages/noriori_core/test/ride_cut_test.dart:163뿐. store 시험은 없음 |
| A:526 | store 시험: 더 새로운 user_version 백업 거부 | 구현됨 | backup_test.dart:184,309 |
| A:527 | UI 시험: 행 단위 골든 이미지 | 미구현 | matchesGoldenFile 0건. 위젯 시험은 42건 |
| A:528 | 장애 시험: 저장·시작 중 강제 종료 | 부분 | crash_test.dart 1건, cold_start_test 일부. 단계마다 끊지는 않음 |
| A:528 | 장애 시험: 공간 부족 | 구현됨 | cold_start_test.dart:431-463, flows_test.dart:268 |
| A:529 | 규칙 시험 tools/mutate_dart.py로 규칙을 깨뜨려 시험 실패 확인 | 구현됨 | T/mutate_dart.py 규칙 91개의 원본 문자열이 전부 지금 코드에 있음 (파일을 고치는 도구라 실행은 안 함, 문자열 대조만) |
| A:529 | 규칙 25개 전부 잡힘 | 문서 오류 | 지금 규칙은 67개이고 5개가 도구 쪽에서 낡음 |
| A:530 | 규칙 모델 tools/model_check.py, --mutate | 구현됨 | tools/model_check.py:293 |
| A:530 | 앱을 만든 뒤 같은 시나리오를 실제 store로 다시 돌림 | 부분 | backup_test, cold_start_test가 일부 옮김. 시나리오 대응표 없음 |
| A:531 | 벤치마크: §6 예산, 중급 Android 실기기 | 미구현 | 벤치 없음 |
| A:537 | 앱 시나리오 121건 FAIL 0 (결과 기록) | 구현됨 | tools/appsim.py. 재실행하지 않음 |
| A:538 | 도달성 못 채운 단위 0 (결과 기록) | 구현됨 | tools/invariants.py reach. 재실행하지 않음 |
| A:539 | 날짜별 도달성 못 넣는 구간 0 (결과 기록) | 구현됨 | tools/invariants.py on_date. 재실행하지 않음 |
| A:540 | 포함 크레딧 0건 (결과 기록) | 구현됨 | tools/invariants.py sums. 재실행하지 않음 |
| A:541 | 구간 끄기 5,445조각 일치 (결과 기록) | 부분 | 파이썬 모델 tools/invariants.py cuts. Dart cutSection은 있으나 같은 표본을 돌린 기록 없음 |
| A:542 | 규칙 모델 40,000건 (결과 기록) | 구현됨 | tools/model_check.py. 재실행하지 않음 |
| A:543 | 규칙 20개 끄기 (결과 기록) | 구현됨 | tools/model_check.py:7 RULES. 재실행하지 않음 |
| A:549 | 멈춤 기준 1: 새 테이블을 요구하는 지적 없음 | 구현됨 | 절차 |
| A:550 | 멈춤 기준 2: 불변식마다 실제로 돌아가는 시험 | 문서 오류 | 불변식 6은 운영 원칙이라 시험 대상 아님. 1~5 시험 있음 |
| A:551 | 멈춤 기준 3: 규칙을 끄면 시험 실패 | 구현됨 | T/mutate_dart.py 규칙 91개의 원본 문자열이 전부 지금 코드에 있음 (파일을 고치는 도구라 실행은 안 함, 문자열 대조만) |
| A:552 | 멈춤 기준 4: 데이터 표본 오류 유형별 전수 집계 | 구현됨 | docs/audit-2026-11-01.md, audit_db.py |
| A:553 | 멈춤 기준 5: 규칙으로 고친 결과를 규칙 밖에서 확인 | 구현됨 | audit_ext.py, verify.py |
| A:563 | 뼈대 끝: 저장소 만들기와 CI 첫 실행 | 미구현 | 프로젝트 루트에 .git 없음. CI는 한 번도 돌지 않음 |
| A:563 | 뼈대 끝: iOS 실기기 폴더 책갈피와 백그라운드 쓰기 | 부분 | 코드는 AppDelegate.swift:128-133,157-179. 실기기 확인 기록 없음, 사용자 기기 필요 |
| A:564 | 데이터 선행: 住吉 중복 | 미구현 | 위 A:434 |
| A:564 | 데이터 선행: node_move 배포 | 미구현 | 위 A:435 |
| A:564 | 데이터 선행: 현행 선형 공백 | 구현됨 | 위 A:439 |
| A:564 | 데이터 선행: 표식 | 구현됨 | 위 A:440 |
| A:564 | 데이터 선행: 서명 | 미구현 | 위 A:441 |
| A:564 | 데이터 선행: 빌드 날짜 고정 | 구현됨 | 위 A:442 |
| A:564 | 데이터 선행: denominator·junction 배포 제외 | 구현됨 | edge_shape, junction, denominator를 판에서 뺌 (tools/gen_tiles.py, pack-master.sqlite) |
| A:564 | 데이터 선행: 직통 표시 점검 | 미구현 | 위 A:444 |
| A:564 | 데이터 선행: 분기 방향 | 구현됨 | redesign 3절 1단계: 분기 side 97행 채움, 28행은 각도로 판단 불가. pack route_link branch side NULL 28행 실측 |
| A:564 | 데이터 선행: 소소한 값 | 미구현 | 위 A:446 |
| A:564 | 데이터 선행: 판 사이 재해석 도구 | 부분 | tools/repro/만 |
| A:564 | 데이터 선행: hub_evidence.json을 §4.2 흡수 목록에 추가 | 미구현 | A:412-416에 없음. 파일은 data/source/hubs/hub_evidence.json |
| A:564 | 데이터 선행: _2 같은 순서 의존 override 키 18개 확인 | 미구현 | data/overrides에 _2 키가 남고 확인 기록 없음 (moved.json 9줄 등) |
| A:564 | 데이터 선행: 동시 멤버십 없음에 맞춰 DESIGN §2.7·§14 문구 정리 | 구현됨 | DESIGN:301 "(line, edge)당 동시 행은 1개" |
| A:565 | 백업: photo를 백업에 포함 | 대상 아님 | 2026-11-03 결정: 사진 뺌 |
| A:565 | 백업: setting을 백업에 포함 | 구현됨 | core/backup/backup_codec.dart:62-75,110-115, store/records/record_store.dart:12,50-55,60-71 |
| A:565 | 백업: change_report를 백업에 포함 | 구현됨 | change_report 백업 포함, 전체판 CSV resolve_unknown 열 (공개 전 검토) |
| A:565 | 백업: 사진은 임시 이름 뒤 해시 확인 | 대상 아님 | 2026-11-03 결정: 사진 뺌 |
| A:565 | 백업: 수동 백업 ZIP | 대상 아님 | 2026-11-03 결정: 사진 뺌 |
| A:565 | 백업: setting의 device_id는 복원으로 옮기지 않음 | 구현됨 | store/records/record_store.dart:12 backedUpSettings에 device_id 없음 |
| A:566 | core: 완주율 표시는 내림 | 구현됨 | core/score/scorer.dart:45, score_format.dart:31 |
| A:566 | core: 조각 셋 이상 | 구현됨 | core/network/ride_cut.dart:84-118 조각 수 제한 없음, 시험 ride_cut_test.dart:151 |
| A:566 | core: 이설일 경계의 대표 날짜 | 구현됨 | core/network/network.dart:166-175, route_resolver.dart:347-359 |
| A:566 | core: 재해석에서 방향 없는 닫힌 계통은 needs_input | 구현됨 | C/network/ride_interpreter.dart:38 askDirection:true, C/network/route_resolver.dart:250. 大江戸線 방향 없는 기록 needs_input 실행 확인 |
| A:566 | core: 전체판 CSV의 resolve_unknown·node_explicit | 구현됨 | change_report 백업 포함, 전체판 CSV resolve_unknown 열 (공개 전 검토) |
| A:566 | core: UUIDv5 입력 열 명시 | 구현됨 | core/importing/csv_import.dart:220-228 |
| A:572 | drift + 팩 ATTACH + 읽기 풀 + 작업 격리 동작 (프로브) | 구현됨 | tools/probe/, proto/. 앱은 작업 격리 제외 |
| A:573 | Flutter + maplibre_gl + 로컬 rail.pmtiles 렌더링 (프로브) | 구현됨 | 앱에 반영 |
| A:574 | match 필터로 절반 칠하기 동작, 갱신 시간 미측정 | 구현됨 | ARCHITECTURE §2.6 실측 (Note10, 절반 41~82ms, 거의 전부 58~109ms), A 채택. iOS 측정은 AR:L531 |
| A:575 | Android 폴더 백그라운드 쓰기 (프로브) | 구현됨 | BackupFolderChannel.kt |
| A:576 | iOS 폴더 책갈피 (프로브) | 구현됨 | AppDelegate.swift:68- |
| A:577 | 재설치: 권한 소실, 재선택 뒤 이전 파일 읽기 (프로브) | 구현됨 | backup_controller.dart:102-109 |
| A:583 | 골격: 저장소, CI, 팩, user.sqlite, 시작 절차, 자동 백업 | 부분 | 저장소와 CI 첫 실행 안 됨, 나머지 있음 |
| A:583 | 골격 조건: 앱이 판 번호 표시 | 구현됨 | settings_screen.dart:16-27 |
| A:583 | 골격 조건: model_check 강제 종료·복원 시나리오를 실제 store로 | 부분 | store 시험에 일부 |
| A:583 | 골격 조건: 자동 백업을 Android와 iOS 실기기에서 확인 | 부분 | 기록은 A:634 Android 로컬 폴더뿐 |
| A:584 | 수직 슬라이스: core 이식, 선택기 → 저장 → 지도 → 통계, 스키마 2 | 구현됨 | core_parity_test.dart, flows_test.dart |
| A:584 | 수직 슬라이스 조건: 두 플랫폼에서 한 번 완주 | 부분 | 기록 없음 |
| A:585 | 데이터 선행: §4.3의 나머지 | 미구현 | A:434-446 대부분 남음 |
| A:585 | 데이터 선행 조건: 검색 시험, 쿼리 계획 검사, 앱 시나리오 통과 | 부분 | 검색과 시나리오 있음, 쿼리 계획 없음 |
| A:586 | 지도 벤치: 기본 배경, 칠하기 A·B 비교, 60fps, 100ms | 구현됨 | A안 실측 41~109ms. 60fps 항목은 미측정 |
| A:587 | 역 선택기 다듬기: 스냅숏, 행 높이 캐시, 환승·분기 표시 | 부분 | 환승·분기 표시는 됨 core/network/display_rules.dart, session_lines.dart. 스냅숏과 행 높이 캐시 없음 (A:158, A:160) |
| A:588 | P0: 전국 입력 | 구현됨 | 검색·트리에서 어느 노선이든 입력 |
| A:588 | P0: 방문 | 구현됨 | 방문일·방문 통계 모두 있음 A/features/record/ui/map_sheets.dart:229, A/features/stats/ui/visits_screen.dart |
| A:588 | P0: 운전 계통 | 구현됨 | 줄기 입력 A/features/record/ui/service_session_screen.dart, `○○로 탑승` A/features/record/ui/record_list_screen.dart:195. 판 선택은 결정으로 빠짐 |
| A:588 | P0: 순환 | 구현됨 | 닫힌 계통은 됨. 운전 계통 고리는 km 토글, 짧은 쪽 기본값, 한 바퀴, 횟수가 없음. 두 바퀴 이상 저장에 결함 |
| A:588 | P0: 수정 | 구현됨 | app/features/record/ui/record_edit_screen.dart. 재해석 답변의 남은 것은 A:137 |
| A:588 | P0: 구간 끄기 | 구현됨 | core/network/ride_cut.dart |
| A:588 | P0: 되돌리기 | 구현됨 | 저장, 삭제, 구간·방문 전환 등에는 있음. 기록 수정 저장과 수정 화면 삭제, 지도 시트 방문, 방문 목록 지우기에는 없음 (표 2 L964) |
| A:588 | P0: 백업과 자동 백업 파일 | 구현됨 | change_report 백업 포함, 전체판 CSV resolve_unknown 열 (공개 전 검토) |
| A:588 | P0: CSV 내보내기 | 구현됨 | core/importing/csv_export.dart:93-288, app/features/data/controller/export_controller.dart |
| A:589 | P1: 열람 전용 | 구현됨 | app/features/record/controller/record_session_controller.dart:422-432, app/features/record/ui/session_lines.dart:597-644, store/pack/pack_reader.dart:271-312 |
| A:589 | P1: 특정 연도 | 구현됨 | stats_screen.dart:28-50, core BasisYear |
| A:589 | P1: 승계 끔 | 구현됨 | 설정 스위치 A/features/settings/ui/settings_screen.dart:97-101, carryoverProvider A/app/session_providers.dart:233, 모든 집계가 이 값을 씀. 팩 분모 off 33,161.8km를 시나리오로 확인. 단 AR:L224의 켜기 결함 있음 |
| A:589 | P1: 타임 슬라이더 | 구현됨 | 끝남 |
| A:589 | P1: 사진 | 대상 아님 | 2026-11-03 결정: 사진 뺌 |
| A:589 | P1: 배지 | 구현됨 | 끝남 |
| A:589 | P1: 삭제한 기록 | 구현됨 | app/features/data/ui/deleted_screen.dart:9-65 |
| A:589 | P1: 데이터 내려받기 | 미구현 | 0건 |
| A:590 | 공개 준비: 시드 동결과 ids.lock | 미구현 | 없음 |
| A:590 | 공개 준비: 옛 선로 파일 | 구현됨 | 없음 |
| A:590 | 공개 준비: 채널별 서명 | 미구현 | 없음 |
| A:590 | 공개 준비: 나무위키 본수집 | 미구현 | docs/db-status.md:108 "본수집이 남아 있습니다" |
| A:590 | 공개 준비: 내부 시험 | 미구현 | 기록 없음 |
| A:591 | 이후: 서버 | 대상 아님 | 근거 A:483 |
| A:597 | CP932 표를 코드로 생성해 core에 | 구현됨 | tools/gen_cp932.py, core/importing/cp932_table.dart |
| A:598 | 내용 ID는 store, core는 재료만 | 구현됨 | store/records/content_id.dart, csv_import.dart:220 |
| A:599 | Pretendard 정적 세 벌 | 구현됨 | apps/noriori/pubspec.yaml |
| A:600 | MaterialApp에 한국어 지역화 위임자 | 구현됨 | start_gate.dart:110,165 |
| A:601 | 규칙은 순수 Dart, core는 I/O 없음 | 구현됨 | check_boundaries.py:18-21 |
| A:602 | ID는 시드 동결로 고정 | 미구현 | 동결 전 |
| A:603 | 쓰기 DB 하나, 한 트랜잭션 | 구현됨 | record_store.dart |
| A:604 | 재계산은 시작할 때만, 한 트랜잭션 | 구현됨 | cache_rebuild.dart |
| A:605 | 활성 판 저장 안 함 | 구현됨 | pack_folder.dart:63 |
| A:606 | 판은 앞으로만 | 구현됨 | pack_choice.dart |
| A:607 | 통계 캐시 없음 | 구현됨 | record_queries.dart:115 |
| A:608 | 구간 끄기는 기록 편집 | 구현됨 | core/network/ride_cut.dart:45-119 |
| A:609 | 복원은 병합만 | 구현됨 | record_store.dart:39 |
| A:610 | 회전은 병합 무변경일 때만 | 구현됨 | rotation.dart |
| A:611 | updated_at 행마다 단조 증가 | 구현됨 | change.dart:27 |
| A:612 | 자동 백업은 폴더 방식만 | 구현됨 | BackupFolder 인터페이스 |
| A:613 | infer_path, via_nodes 제거 | 구현됨 | 앱 코드 0건. 팩 route.via_nodes는 남음 compile.py:575, 앱은 안 읽음 |
| A:614 | 동기화 준비는 UUID, updated_at, deleted_at, apply까지 | 구현됨 | §5 표 |
| A:615 | OS 백업은 보장으로 치지 않음 | 구현됨 | 정책 |
| A:616 | 날짜 원본은 입력값 | 구현됨 | record.dart:119 |
| A:617 | 판 폴더 불변 | 구현됨 | pack_folder.dart |
| A:618 | feature state 안 씀 | 구현됨 | map_style.dart |
| A:619 | 서버는 저장과 중계만 | 대상 아님 | 근거 A:483 |
| A:620 | 클라우드 연동 안 함 | 구현됨 | 코드 없음 |
| A:621 | 뼈대를 수직 슬라이스까지로 봄 | 구현됨 | 절차 |
| A:622 | 첫 커밋은 기능이 갖춰진 뒤 | 대상 아님 | 근거 A:622 "사용자 지시", 시점은 사용자가 정함 |
| A:623 | 지도 홈의 안내와 시트는 앱이 끼워 줌 | 구현됨 | router.dart:22-28 |
| A:624 | 저장 확인은 화면을 어둡게 하지 않음 | 구현됨 | ride_ticket.dart:20-31 |
| A:625 | 현재 위치 버튼 보류, 전국 보기로 대신 | 구현됨 | map_home_screen.dart _fitJapan, AndroidManifest 위치 권한 제거 |
| A:626 | 지도 필터 값은 문자열 | 구현됨 | map_style.dart:24-30 |
| A:629 | 남은 실험: match 필터 갱신 시간, iOS 포함 | 부분 | 벤치 파일과 integration_test 폴더 없음 (find 0건). ARCHITECTURE §0.2, §2.6 |
| A:630 | 남은 실험: 기기 글꼴 + 내장 라틴 글리프 | 구현됨 | 끝남 |
| A:631 | 남은 실험: 기록이 많을 때 재해석과 통계 쿼리 시간 | 미구현 | 미실시 |
| A:634 | 남은 실험: Android 폴더 선택의 클라우드 드라이브 지원 | 미구현 | 기록 없음 |
| A:635 | 남은 실험: iOS 책갈피와 7일 재서명, beginBackgroundTask | 부분 | beginBackgroundTask는 있음 AppDelegate.swift:128-133. 재서명 확인 없음 |
| A:640 | 사용자: 중급 Android 실기기 연결 | 부분 | A:64 Note10 측정 있음, 벤치 없음 |
| A:641 | 사용자: 앱 ID 확정 | 부분 | 작업 값 app.noriori, build.gradle.kts:30 |
| A:642 | 사용자: APK 서명 키 | 부분 | key.properties.example만 |

### ARCHITECTURE v0.11에서 새로 넣은 항목

| 문서:행 | 요구 요약 | 판정 | 근거 파일:행 |
|---|---|---|---|
| A:148 | /service/:id 운전 계통 입력. 한 줄 노선도와 공식 노선별 분해 | 구현됨 | 한 줄 노선도에 줄기·범위 칠하기·역 상태·그날 없는 구간 흐림 A/features/record/ui/service_session_screen.dart:118-123,150-165. 판 선택은 결정으로 빠짐 |
| A:261 | line_diagram.dart: 세로 노선도, 구간 묶기, 켜기 (restorableRide, sectionRide) | 구현됨 | core/network/line_diagram.dart:85-195,227-321 |

### docs/server-notes.md

| 문서:행 | 요구 요약 | 판정 | 근거 파일:행 |
|---|---|---|---|
| SN:13 | 암호화한 슬롯 저장·중계 기록 해석, 내용 읽기, 통계 계산 | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:14 | 공개에 동의한 통계 요약 순위표 개별 기록 공개, 지도·데이터셋 서빙 | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:24 | 서버는 암호문만 저장 복호화, 경로 계산, 재해석이 서버에 없음 | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:25 | 기록당 슬롯 고정 기록을 고쳐도 저장량이 늘지 않음. 이력을 쌓지 않음 | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:26 | 순위는 기기가 올린 요약 서버는 정렬만 함 | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:27 | 변경분 폴링 연결을 유지하지 않음. 앱을 열 때, 저장 뒤, 켜 둔 동안 주기적으로 | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:28 | 데이터셋은 정적 파일 GitHub Releases가 그대로 처리 | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:29 | 프로세스 1개, SQLite 파일 1개 운영 대상이 볼륨 하나 | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:35 | 기록 10만 건 (슬롯 20만 개, 기록 평문 200~560바이트 가정) 파일 74.1MB | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:36 | 새 변경 없는 폴링 0.002ms | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:37 | 변경 50행 받기 0.017ms | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:38 | 새 기기가 기록 500건 전부 받기 0.4ms | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:39 | 올리기 (회당 슬롯 20개, 회마다 커밋) 734회/초 | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:46 | 실행 Docker 이미지 하나, 볼륨 하나 | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:47 | 나와 가족, 친구 Tailscale. 공유기 포트를 열지 않음 | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:48 | 공개 순위 리버스 프록시 + 도메인. TLS는 앞단이 맡음 | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:49 | 서버가 꺼졌을 때 앱은 그대로 동작. 켜지면 밀린 슬롯을 주고받음 | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:50 | 서버 디스크를 잃었을 때 기기마다 전체 사본이 있음. `server_epoch`가 바뀌면 기기가 전부 다시 올림 (§5.4) | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:51 | 서버 볼륨을 스냅숏으로 되돌릴 때 전용 명령을 씀. 이 명령이 `server_epoch`를 새로 만듦. 볼륨을 손으로 되돌리면 | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:65 | ride` + `ride_leg content`, `delete | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:66 | ride_exclusion content` 하나 | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:67 | visit` (라벨 포함) content`, `delete | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:68 | trip content`, `delete | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:69 | setting` (허용 목록) content | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:70 | photo`, `change_set`, 파생 전부 없음 | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:72 | setting 허용 목록은 basis, carryover, show_closed, show_archive,  | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:73 | HLC는 (물리 시각, 카운터, device_id)입니다. 동점이 없습니다. | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:74 | 가져온 행의 첫 HLC는 (0, 0, device_id)입니다. 두 기기가 같은 파일을 가져와도 사용자가 고친 값을 덮지  | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:75 | 전송 상태는 서버 단계에서 sync_state(entity, slot, pushed_hlc)로 더합니다. 보낼 것은 | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:76 | 서버가 초기화되면 기기가 알아챕니다. /v1/info가 server_epoch를 주고, sync_state와 | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:77 | 서버는 (account_id, entity_key, slot)마다 HLC가 가장 높은 행만 남깁니다. 내용은 보지 않고 값 | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:78 | 받은 행은 원본에 병합하고 change_seq를 올립니다. 파생은 평소처럼 따라옵니다. 내 판이 모르는 ID면 unkno | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:82 | account id, recovery_hash, rejoin_hash, created_at, display_name?, pub | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:83 | device id, account_id, token_hash, added_at, revoked_at? | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:84 | slot seq, account_id, entity_key, slot, hlc, ciphertext | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:85 | public_stat account_id, current_km, alltime_km, edition, updated_at | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:89 | GET /v1/info | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:90 | POST /v1/accounts | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:91 | DELETE /v1/accounts/me | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:92 | POST /v1/accounts/recover | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:93 | POST /v1/accounts/rejoin | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:94 | POST /v1/devices/pair | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:95 | POST /v1/sync/push | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:96 | GET /v1/sync/pull?since= | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:97 | PUT /v1/stats/public | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:98 | GET /v1/leaderboard | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:102 | 인증: 기기별 무작위 토큰. 서버는 해시만 저장합니다. | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:103 | 비밀 하나: 복구 문구 하나에서 HKDF로 account_id, 복구 증명, 재가입 증명, 데이터 키, ID 키를  | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:104 | 암호화: 슬롯을 XChaCha20-Poly1305로 암호화하고 (entity_key, slot, hlc)를 인증 데 | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:105 | 서버 ID: 서버에는 엔티티 ID 대신 HMAC(ID 키, id)를 보냅니다. 가져온 행의 UUIDv5가 파일 내용 | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:106 | 기기 해제: 토큰을 폐기합니다. 키를 회전하지 않습니다. 해제된 기기는 복구 증명이 없고 재가입은 서버가 초기화된 때만 | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:107 | 서버 초기화: account_id가 복구 문구에서 나오므로 기기들이 따로 재가입해도 계정이 갈라지지 않습니다. 해제 | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:108 | 유출이 의심되면: 새 복구 문구로 새 계정을 만들어 전부 다시 올립니다. | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:109 | 키 분실: 복구 문구를 잃어도 기기가 남아 있으면 그대로 씁니다. 기기까지 모두 잃으면 서버 데이터는 못 씁니다. | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:119 | 사용자 기록 ID를 UUIDv7로 기기끼리 충돌 없음 | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:120 | content_hlc`, `delete_hlc`, `deleted 나중에 채우면 기존 기록의 순서를 알 수 없음 | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:121 | device_id`, `install_id`, `hlc_last OS 복원 처리와 시계 순서에 지금도 필요 | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:122 | change_seq 파생 따라잡기에 지금도 필요 | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:123 | ride_exclusion`, 삭제 표시 구간 끄기와 복구에 지금도 필요 | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:124 | 데이터셋 주소 설정 미러 | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:125 | SyncPort` 인터페이스와 빈 구현 UI와 store가 서버를 몰라도 됨 | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:129 | server/`, `noriori_protocol`, `noriori_sync 서버 단계 | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:130 | 계정, 로그인, 암호화 코드 서버 단계 | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:131 | sync_state` 테이블 서버 단계의 마이그레이션 1회 | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:132 | 순위 화면 서버 단계 | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:133 | 사진 동기화 첫 서버 범위 밖 | 대상 아님 | 근거 server-notes:3 "v1.0을 만들 때 이 문서를 따르지 않습니다" |
| SN:120 | 지금 앱에 넣음 표(content_hlc, SyncPort 등)가 ARCHITECTURE §5와 다름 | 문서 오류 | server-notes:5가 v1.0에 없다고 했고 A:489-494가 기준. 표 자체는 옛 v0.4 내용 |

### docs/db-status.md

| 문서:행 | 요구 요약 | 판정 | 근거 파일:행 |
|---|---|---|---|
| dbs:9 | 사업자: 211 | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:10 | 노선: 766 (현행 600, 현행 멤버십 없음 166) | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:11 | 계통: 823 | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:12 | 노드: 11023 (공개 11005) | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:13 | edge: 11183 | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:14 | 사건: 6683 | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:15 | 계통 위 역 행: 12784 | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:16 | 이어짐·분기·환승 링크: 5884 (이어짐 1375, 분기 421, 환승 4088) | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:17 | 환승 묶음: 799 | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:18 | 분기 지점: 1234 | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:19 | 열람 전용: 역 439, 노선 140 | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:25 | JR 홋카이도: 1 | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:26 | JR 나머지 5사: 5 | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:27 | 대형·준대형 사철: 18 | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:28 | 공영: 11 | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:29 | 그 밖의 사철·3섹: 111 | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:30 | 모노레일·신교통: 15 | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:31 | 강삭: 15 | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:32 | **합계**: 176 | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:40 | 현행: 27,352.3 | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:41 | 역대, 승계 켬: 30,961.8 | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:42 | 역대, 승계 끔: 33,161.8 | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:43 | 1970년: 25,579.1 | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:44 | 1980년: 26,882.8 | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:45 | 1987년: 27,557.8 | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:46 | 2000년: 27,202.8 | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:47 | 2010년: 27,345.3 | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:48 | 2020년: 27,455.8 | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:54 | 사업자별 현행 km, 노리츠부시 표 대조: 176개 중 불일치 0 | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:55 | 컴파일 구조 검사 오류: 0 | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:56 | 해결 못 한 시드 항목: 0 | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:57 | 계통 km 경고: 10건 (폐선 계통, 이관 뒤 구간의 km를 현행값으로 쓰면서 생긴 0.5km 이내 차이) | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:58 | 역 간격, 위키 노선도 대조: 8564쌍 중 8315쌍 일치 (97.1%, 0.25km 기준) | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:59 | 현행 역 이름, station_database 대조: 우리 8819, 원자료 8445, 공통 8422 | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:60 | JR→타사 이관: 52건 | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:61 | 오늘자 이웃 역 쌍, 노리츠부시 표 대조: 9551쌍 일치, 표에만 있는 11쌍은 화물·연락선·기간 한정 별선 | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:69 | 역 위치 정밀: 9467 | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:70 | 역 위치 근사 (좌표 보간): 1530 | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:71 | 역 위치 없음: 26 | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:72 | 선형 있는 edge: 10099 / 11183 | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:80 | 개업일 없는 구간 행: 0 / 17406 (대부분 옛 사철) | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:81 | 폐지일 없는 폐역: 3 / 2374 | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:82 | 기준일 전 여객 종료 edge: 15 (여객 영업은 끝났지만 법적 폐지가 기준일 뒤라 수록) | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:83 | 마지막 운행일이 따로 있는 edge: 209 | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:84 | 폐지 사유: 폐지 1402, BRT 37, 정기 영업 없음 5, 이설 10 | 구현됨 | status.py 재생성 결과와 같음. build/report.json, build/verify.json |
| dbs:34 | 노선 종류 분포 | 구현됨 | master.line 조회 일치 (rail 668, tram 53, monorail 12, agt 9, cable 22, trolley 2) |
| dbs:63 | 규칙 검사 audit_db.py, 전수 대조 audit_ext.py | 구현됨 | tools/audit_db.py, tools/audit_ext.py |
| dbs:74 | 선형은 N02 2005~2024판 | 구현됨 | data/source/geometry/ |
| dbs:3 | tools/status.py가 빌드 결과로 만든 문서 | 구현됨 | 재생성 결과가 docs/db-status.md와 한 글자도 다르지 않음 (임시 폴더에 다시 만들어 비교) |
| dbs:90 | lines_ko.json, lines_kana.json | 구현됨 | data/overrides/ |
| dbs:91 | kana.json, kana_est.json, 추정 값은 estimated 표시 | 구현됨 | data/overrides/ |
| dbs:92 | operators_ko.json, names_ko.json | 구현됨 | data/overrides/ |
| dbs:93 | services.json 운전 계통 16개 | 문서 오류 | 파일과 팩 모두 17개, 같은 문서 :104도 17개. 틀린 글자는 tools/status.py:129 |
| dbs:94 | old_hand.json, old_history.json | 구현됨 | data/overrides/ |
| dbs:96 | 코드 안의 표 RENAME, BRTDAY, SVC, OPHIST, ARCH_CLOSE | 구현됨 | tools/gen_source.py 등 |
| dbs:100 | 한계: 폐선 선형, rail-osm.pmtiles 미생성 | 구현됨 | rail-osm.pmtiles 생성·앱 포함. docs/db-status.md:100 문구만 낡음 (T/status.py 재생성 필요) |
| dbs:101 | 한계: 작은 기본 배경과 도도부현 경계선 없음 | 구현됨 | `base.pmtiles` |
| dbs:102 | 한계: manifest ed25519 서명 비어 있음 | 미구현 | 서명 필드 자체가 없음 build/manifest.json. 문서는 "비어 있습니다" |
| dbs:103 | 한계: 도도부현 경계 km 근사 | 부분 | edge_pref.approx 476행. 표시 구분 없음 |
| dbs:104 | 한계: 운전 계통 17개만 | 구현됨 | service 17행 |
| dbs:105 | 한계: 사철 사명 변경 이력 | 대상 아님 | 근거 dbs:105. 수록 범위를 명시한 한계 |
| dbs:106 | 한계: 현행 노선의 옛 구간 이력 | 대상 아님 | 근거 dbs:106 |
| dbs:107 | 한계: 열람 전용 폐선은 km 없으면 기록 불가 | 대상 아님 | 근거 dbs:107 |
| dbs:108 | 한계: 나무위키 본수집이 남음 | 미구현 | A:590 공개 준비 |
| dbs:109 | 한계: 임시역 3곳 미수록 | 대상 아님 | 근거 dbs:109 |
| dbs:110 | 한계: 1969년 이전 역 개업일 | 대상 아님 | 근거 dbs:110 |
| dbs:111 | 한계: 구간 km 이력은 구간당 한 값 | 대상 아님 | 근거 dbs:111 |
| dbs:112 | 한계: 역명 이력 자동 추출 | 대상 아님 | 근거 dbs:112 |
| dbs:113 | 한계: 불통 이력은 주요 건만 | 대상 아님 | 근거 dbs:113 |
| dbs:114 | 한계: 기준일 뒤 폐지 열람 전용 29개 노선 | 대상 아님 | 근거 dbs:114 |
| dbs:115 | 한계: 표시 규칙 목업 미반영 | 문서 오류 | 승인 시안은 docs/mockups/station-selector.tpl.html (§8.1). wiki-compare는 옛 파일 |
| dbs:120 | bash tools/all.sh | 구현됨 | tools/all.sh |
| dbs:121 | tools/verify.py | 구현됨 | tools/verify.py |
| dbs:122 | tools/audit_db.py | 구현됨 | tools/audit_db.py |
| dbs:123 | tools/audit_ext.py | 구현됨 | tools/audit_ext.py |
| dbs:124 | tools/status.py | 구현됨 | tools/status.py |

### data/README.md

| 문서:행 | 요구 요약 | 판정 | 근거 파일:행 |
|---|---|---|---|
| R:5 | imports/ 원천 스냅샷, 재배포 안 함 | 구현됨 | .gitignore:2 |
| R:6 | candidates/ 도구 후보, 저장소에 없음 | 구현됨 | .gitignore:5 |
| R:7 | overrides/ 사람이 정한 값 (as_of 포함) | 구현됨 | data/overrides/ |
| R:8 | source/ 모듈 파일, 항목마다 JSON 한 줄 | 구현됨 | data/source/ |
| R:9 | sources.lock: 경로, 크기, sha256, 받은 날, URL, 도구 버전 | 구현됨 | data/sources.lock, tools/lock_sources.py |
| R:14 | bash tools/all.sh | 구현됨 | tools/all.sh |
| R:15 | python3 -I tools/status.py | 구현됨 | 재실행 확인 |
| R:18 | all.sh는 네트워크를 쓰지 않음 | 구현됨 | tools/all.sh:3. 수집 도구는 따로 |
| R:18 | 같은 입력이면 source/와 build/가 바이트까지 같음 | 부분 | CI 비교나 시험 없음. 이번에 재확인하지 않음 |
| R:20 | imports가 있으면 시드 → 위키 → 재생성 → 선형 → 위키 → 판 기록 → 컴파일 → 타일 → 검증 | 구현됨 | tools/all.sh:7-27. gen_extra 단계는 문서에 없음 |
| R:21 | imports가 없으면 생성을 건너뛰고 컴파일과 검증 | 구현됨 | tools/all.sh:18-20 |
| R:21 | candidates/가 없어도 됨 | 구현됨 | tools/compile.py:28 |
| R:23 | 결과물 master, names, rail, manifest, report, verify | 구현됨 | build/ |
| R:23 | tippecanoe가 없으면 알리고 넘어감 | 구현됨 | tools/all.sh:22-26 |
| R:25 | status.py는 경로 인자로 다른 곳에 씀 | 구현됨 | tools/status.py:7 |
| R:30 | 앱에 팩 넣기: all.sh 후 sync_pack.sh | 구현됨 | tools/sync_pack.sh |
| R:34 | sync_pack.sh가 네 파일을 assets/pack/으로 복사 | 구현됨 | tools/sync_pack.sh:6 |
| R:34 | assets/pack은 저장소에 안 넣음 | 구현됨 | .gitignore |
| R:34 | tippecanoe가 없으면 실패 | 구현됨 | cp 실패, set -e |
| R:38 | as_of가 판의 기준일. 현행 분모, checked, edition이 이 값 | 구현됨 | tools/lib.py:10, compile.py:7, gen_tiles.py:58 |
| R:38 | 실행한 날은 팩 값에 영향 없음 | 구현됨 | tools/*.py에 오늘 날짜 호출 없음 |
| R:38 | 앱은 edition을 비교해 판을 고름 | 구현됨 | core/pack/pack_choice.dart |
| R:45 | wiki_fetch.py | 구현됨 | tools/wiki_fetch.py |
| R:46 | wiki_station.py | 구현됨 | tools/wiki_station.py |
| R:47 | wd_fetch.py | 구현됨 | tools/wd_fetch.py |
| R:48 | fill_kana.py | 구현됨 | tools/fill_kana.py |
| R:49 | wiki_kana.py | 구현됨 | tools/wiki_kana.py |
| R:52 | 같은 sha256의 받은 날 유지 | 구현됨 | tools/lock_sources.py |
| R:52 | 옛 역 후보는 candidates/wiki_insert.json, 계속 쓰려면 overrides/로 | 구현됨 | data/candidates/wiki_insert.json, data/overrides/wiki_insert.json |
| R:52 | audit_check.py가 감사 항목을 DB에서 재확인 | 구현됨 | tools/audit_check.py |
| R:60 | source 값 noritsubushi | 구현됨 | names.name.source |
| R:61 | source 값 wikipedia, wikipedia:<revid> | 구현됨 | 같음 |
| R:62 | source 값 station_database | 구현됨 | 같음 |
| R:63 | source 값 wikidata | 구현됨 | 같음 |
| R:64 | source 값 namuwiki | 구현됨 | 같음 |
| R:65 | source 값 rule | 구현됨 | 같음 |
| R:66 | source 값 estimated | 구현됨 | 같음 |
| R:67 | source 값 hand | 구현됨 | 같음 |
| R:68 | source 값 a+b | 구현됨 | 같음 |
| R:70 | geometry/n02.yaml과 n02_legacy.yaml을 조건별로 분리 | 구현됨 | data/source/geometry/ |
| R:72 | 사이트 내부 식별자를 공개 데이터에 넣지 않음 | 구현됨 | data/source/lines 검색 0건 |
| R:72 | 계통별 표 km 대조는 n_routes.json이 있을 때만 | 구현됨 | tools/compile.py:28 |
