# noriori 데이터

| 폴더·파일 | 내용 | 누가 쓰나 |
|---|---|---|
| `imports/` | 원천 스냅샷. 출처마다 폴더 하나 (`noritsubushi`, `stationdb`, `wiki`, `wikidata`, `namuwiki`, `n02`, `n03`, `n05`, `osm`, `glyphs`). 공개하지 않는 내부 번호표 `id_map.json`만 바로 아래에 있음. 재배포하지 않아 저장소에 없음 | 수집 도구 |
| `candidates/` | 도구가 만든 후보와 보고서. 저장소에 없음 | 기계 |
| `overrides/` | 사람이 정한 값 (읽기, 노선·사업자 한글 이름, 운전 계통, 옛 폐선 구간 이력, 끼워 넣을 옛 역 목록, 판의 기준일, 역 좌표, 선형 검사 예외). 생성기 안에 있던 손 보정 표는 `hand_tables.json`에 표마다 설명과 함께 있음 | 사람 |
| `sources.json` | 출처 목록과 켜고 끄는 스위치. 끄고 다시 빌드하면 그 출처의 값이 빠짐. 필수 출처(노리츠부시, station_database, 위키백과)를 끄면 빌드가 멈춤 | 사람 |
| `source/` | 설계 §2.1의 모듈 파일. 항목마다 JSON 한 줄인 YAML | 생성기, 이후 사람 |
| `sources.lock` | `imports/`의 판 기록: 경로, 크기, sha256, 받은 날, 원천 URL, 도구 버전 | `tools/lock_sources.py` |

## 다시 만들기

```bash
bash tools/all.sh
python3 -I tools/status.py
```

`all.sh`는 네트워크를 쓰지 않습니다. 같은 입력이면 `source/`와 `build/`가 바이트까지 같습니다.

- `imports/`가 있으면: 옛 폐선(station_database, N05 교차 검증) → 시드 생성 → 위키 대조 → 시드 재생성(옛 역 삽입) → 위키 대조 → 판 기록 → 컴파일 → 선형 → 컴파일 → 타일 → 검증 → 선형 검사
- `imports/`가 없으면 (깨끗한 체크아웃): 생성을 건너뛴다고 알리고 저장소의 `source/`를 컴파일하고 검증합니다. 원천이 필요한 대조는 건너뜁니다. `candidates/`도 없어도 됩니다.

결과는 `build/master.sqlite`, `build/names.sqlite`, `build/rail.pmtiles`, `build/rail-osm.pmtiles`, `build/manifest.json`, `build/report.json`, `build/verify.json`, `build/check_geometry.json`입니다. `rail.pmtiles`, `rail-osm.pmtiles`, `manifest.json`은 tippecanoe가 있어야 만들어집니다. 없으면 그렇게 알리고 넘어갑니다. 쓴 판은 `sources.lock`에 있습니다.

`tools/check_geometry.py`는 현행 구간의 선형 없음, 길이 비율, 끝점과 역의 거리, 이웃 끝 간격, 역과 선로의 거리, 되돌아가는 꺾임을 재고 기준을 넘으면 실패합니다. 예외는 `overrides/geometry_exceptions.json`에 사유와 함께 적은 것만 허용하고, 쓰이지 않게 된 예외도 실패로 봅니다.

`tools/status.py`는 `docs/db-status.md`를 다시 씁니다. 다른 곳에 쓰려면 경로를 인자로 줍니다.

## 컴파일 단계 보정

`imports/`가 없는 체크아웃(CI, 원격 작업 환경)에서도 바로 빌드에 반영되는 보정 표입니다. 생성기(`gen_*`)가 읽는 표는 `source/`를 다시 만들어야 반영됩니다.

| 파일 | 내용 |
|---|---|
| `overrides/events_fix.json` | 생성기가 빠뜨리거나 틀리게 쓴 사건을 재생성 전까지 고친다. `match`+`set`은 사건 하나를 찾아 값을 바꾸고, `add`는 사건을 더한다. 재생성으로 `source/`가 맞아져 쓰이지 않게 된 행은 `compile.py` 오류(`events_fix_unused`)라 그때 지운다 |
| `overrides/edge_dates.json` | 구간 시작일 (`노드|노드` → EDTF) |
| `overrides/stop_dates.json`, `moved.json`, `extend.json`, `hub_pairs.json`, `hub_not.json`, `junction_side.json` | 역 기간, 역 이전, 숨은 끝 너머, 환승 묶음, 분기 방향 |
| `overrides/kana.json`, `kana_est.json`, `kana_evidence.json` | 역 읽기(`node:이름` → 가나). `kana.json`은 근거가 있는 읽기, `kana_est.json`은 근거가 모자란 읽기(출처 `estimated`, 한자로 추정했거나 근거가 중간 하나뿐인 조사 값)다. 조사한 읽기의 근거(공식 정거장 목록 쪽, railforum 행 등)는 `kana_evidence.json`에 행마다 남기고, 확정 규칙(높음 하나, 또는 서로 독립인 중간 둘. railforum의 두 목록은 하나로, 현행 지명 읽기는 세지 않음)을 넘은 것만 `confirmed: true`로 `kana.json`에 둔다 |
| `overrides/one_way.json`, `stop_direction.json` | 한 방향 운행 구간(운행 순서의 역 목록)과 한 방향 정차·하차전용 역(`direction`, `label`, `use`). 기간과 근거(`why`)를 행마다 적는다 (DESIGN §8) |
| `overrides/stop_status.json` | 仮乗降場·臨時駅이던 기간(`node`, `kind` kari/rinji, `from`, `to`). `line`이 있으면 그 노선에서만 표시한다(없으면 그 기간에 서는 모든 노선) |
| `overrides/invariant_exceptions.json` | 날짜별 도달성 검사 예외. `provisional: true`는 재생성이나 자료 보강으로 지울 임시 예외 |
| `overrides/geometry_exceptions.json` | 선형 검사 예외 |

생성기가 읽어 `source/`를 다시 만들어야 반영되는 표 가운데 칸 설명이 필요한 것:

| 파일 | 내용 |
|---|---|
| `overrides/line_gauge.json` | 노선(또는 `from_node`–`to_node` 구간)의 궤간·선로 방식 기간(`gauge` mm, `system`, `valid_from`, `valid_to`, `evidence`, `why`). `gen_source.py`가 노선 행의 `gauge`로 넘기고 `compile.py`가 `line_gauge` 표로 내며 선로 이음 판정에 쓴다(궤간이나 방식 묶음이 다르면 분기·끝 이어짐을 내지 않음, 그 역에 걸리는 구간 행이 노선 전체 행보다 앞섬). `system`은 rail·tram·third_rail·agt·monorail·linear·maglev·cable·rubber_guided·guideway_bus·trolley·bus. 없는 노선을 가리키면 생성이 멈춘다 |
| `overrides/renames_hand.json` | 손 개칭 `노드 → [[옛 이름, 시작, 끝(, 노선)]]`. 4번째 원소가 있으면 그 노선에서만 쓴 기간 이름(노선별 이름 행)이 된다 |

## 앱에 팩 넣기

```bash
bash tools/all.sh
bash tools/sync_pack.sh
```

`sync_pack.sh`는 `build/`의 `manifest.json`, `master.sqlite`, `names.sqlite`, `rail.pmtiles`를 `apps/noriori/assets/pack/`으로 복사합니다. 이 폴더는 빌드 산출물이라 저장소에 넣지 않습니다. 앱을 빌드하기 전에 실행합니다. `tippecanoe`가 없으면 `rail.pmtiles`와 `manifest.json`이 없어서 실패합니다.

## 기준일

`overrides/as_of.json`의 `as_of`가 판의 기준일입니다. 현행 분모, 이름의 `checked`, `manifest.json`의 `edition`이 이 값을 씁니다. 실행한 날은 팩 값에 영향을 주지 않습니다. 새 판을 낼 때 손으로 올립니다. 앱은 `edition`을 비교해 판을 고르므로 데이터를 바꿨으면 올려야 합니다.

## 원천을 새로 받을 때

`all.sh`와 따로, 받을 때만 실행합니다.

```bash
python3 -I tools/wiki_fetch.py <제목 목록> data/imports/wiki      # 노선 문서
python3 -I tools/wiki_station.py                                 # 역 문서
python3 -I tools/wd_fetch.py data/imports/wikidata/stations.json # Wikidata
python3 -I tools/fill_kana.py                                    # 읽기가 빈 항목 목록
python3 -I tools/wiki_kana.py data/candidates/kana_want.json data/imports/wiki/kana.json
python3 -I tools/osm_fetch.py                                    # OSM 선로. Overpass를 1도 칸씩 천천히 부른다
python3 -I tools/osm_fetch.py railbed                            # OSM 폐선 노반. 철도 태그 없이 길로 그려진 것 (○○線廃線跡, 자전거길)
```

받은 뒤 `bash tools/all.sh`를 돌리면 `sources.lock`이 갱신됩니다. 같은 sha256의 받은 날은 유지합니다. 위키 노선도에서 새로 나온 옛 역 후보는 `candidates/wiki_insert.json`에 쌓이고, 계속 쓰려면 `overrides/wiki_insert.json`으로 옮깁니다. `tools/audit_check.py`는 감사 항목을 DB에서 다시 확인합니다.

## 출처 표시

`source` 값은 그 값이 실제로 온 곳입니다.

| 값 | 뜻 |
|---|---|
| `noritsubushi` | 노리츠부시 표 |
| `wikipedia`, `wikipedia:<revid>` | 일본어 위키백과. 옛 폐선의 km, 구간 이력, 역 문서의 날짜 |
| `station_database` | station_database의 이름과 날짜 |
| `wikidata` | Wikidata |
| `namuwiki` | 나무위키 표제어. 규칙으로 나오지 않는 값만 |
| `rule` | 규칙으로 만든 값 |
| `estimated` | 한자에서 읽기를 추정한 값 |
| `hand` | 사람이 정한 값 (`overrides/`, 생성기 안의 표) |
| `a+b` | 두 출처에 걸친 값. km의 `noritsubushi+wikipedia`는 표의 km를 위키 km 비율로 나눈 끼워 넣은 역 구간 |

`geometry/n02.yaml`은 N02 2020·2024판(CC BY 4.0), `geometry/n02_legacy.yaml`은 2005·2008·2015판(商用可 조건), `geometry/n05.yaml`은 N05 2024판(国土数値情報 이용 조건, 비상업), `geometry/osm.yaml`은 OpenStreetMap(ODbL 1.0)입니다. 조건이 달라 파일을 나눴고 조건은 `geometry/LICENSE.md`에 있습니다. `osm.yaml`은 `master.sqlite`, `rail.pmtiles`에 넣지 않고 `rail-osm.pmtiles`로만 만듭니다. 역의 원래 좌표에도 쓰지 않습니다. 이 선에 맞춘 역 점은 `rail-osm.pmtiles`에만 있습니다.

폐선 구간은 OSM 폐선 조각이 경로의 절반을 넘고 끊긴 길이가 짧아야 선형을 붙입니다. 이 규칙으로 떨어진 구간 중 `overrides/closed_geometry.json`에 있는 것은 그 원천의 경로를 받아들입니다. 이 파일은 `tools/dev/n05_closed.py`가 国土数値情報 鉄道時系列(N05)과 대조해 만듭니다. 같은 노선의 N05 선형에서 경로 점의 90% 이상이 100m 안, 가장 먼 점도 150m 안이어야 합니다. 그래도 선이 없거나 끝이 역에서 300m 넘게 떨어진 폐선 구간은 N05 선형을 씁니다 (`geometry/n05.yaml`). 같은 이름 노선의 조각 중 폐지 직전 기간의 것만 씁니다. N05는 사업자가 바뀔 때도 기간을 끊어 지금 선로의 옛 기록이 폐선처럼 보이기 때문입니다.

선형 행의 `plat`은 그 끝을 노선의 N02 승강장에 맞췄다는 뜻입니다 (`a`, `b`). 한 노드를 여러 노선이 쓰면 좌표는 하나뿐이라 노선마다 승강장이 노드 좌표와 떨어져 있습니다.

## 역 좌표

`source/positions/`의 좌표는 이렇게 정합니다. 뒤의 값이 앞의 값을 덮습니다.

1. station_database. 같은 이름의 다른 사업자 역과 좌표가 같은 경우가 많습니다. 다른 지방의 같은 이름 역 좌표가 붙은 노드는 묶음 판정 전에 `overrides/hand_tables.json`의 `POSFIX`로 고칩니다. N05로 넣은 옛 폐선의 역은 station_database에 없거나 N05 역 점에서 1.5km 넘게 떨어지면 N05 역 점을 씁니다.
2. Wikidata, 또는 앞뒤 역에서 km로 보간한 값 (`interpolated`).
3. 현행 역이 자기 사업자의 N02 승강장 선분에서 300m 넘게 떨어지면 승강장 가운데. 묶음과 환승 판정이 끝난 뒤에 고칩니다. 거리로 판정하는 값이 교정 때문에 흔들리면 안 되기 때문입니다.
4. `overrides/node_fix.json`의 `lat`, `lon`. 원천에 좌표가 없는 신호장, 연락선 분기, 옛 역입니다. `pos_src`에 출처, `pos_note`에 근거를 적습니다. 생성기가 만들지 않고 `overrides/source_patch/nodes`로 넣은 노드는 node_fix가 닿지 않으므로 같은 노드의 `source_patch/positions` 행에 좌표·`quality`·`source`를 적습니다(손 판독은 `hand`). node_fix의 `"kana": null`은 다른 이름에서 가져온 틀린 읽기를 지우라는 뜻이고, 그 읽기로 만든 한국어·영어 이름도 지워 일본어 표기 그대로(`ja_as_is`)가 됩니다.
5. `gen_geometry.py`가 옮긴 값. 보간 좌표와 지금 서지 않는 옛 역은 N02 선로 위 km 지점으로, 역 이전(`overrides/moved.json`)의 옛 역은 이전 전 N02 판의 승강장으로 옮깁니다.

공개 ID는 영어 이름입니다 (ARCHITECTURE §4.2). 새 노선을 넣어 표에 없는 ID가 생기면 `gen_source.py`가 멈춥니다. 그때는 `NORIORI_NEW_IDS=1 bash tools/all.sh`로 내부 키를 그대로 내고, `python3 -I tools/new_ids.py`로 영어 이름 ID를 `imports/id_map.json`에 더한 뒤 `bash tools/all.sh`를 다시 돌립니다. 시드를 동결할 때 `ids.lock`을 만듭니다. 계통별 표 km 대조는 `candidates/n_routes.json`이 있을 때만 `compile.py`가 합니다.
