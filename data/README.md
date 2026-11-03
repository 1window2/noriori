# noriori 데이터

| 폴더·파일 | 내용 | 누가 쓰나 |
|---|---|---|
| `imports/` | 원천 스냅샷 (노리츠부시 표, 위키백과 문서, Wikidata, N02, station_database, 나무위키 이름 표). 재배포하지 않아 저장소에 없음 | 수집 도구 |
| `candidates/` | 도구가 만든 후보와 보고서. 저장소에 없음 | 기계 |
| `overrides/` | 사람이 정한 값 (읽기, 노선·사업자 한글 이름, 운전 계통, 옛 폐선 구간 이력, 끼워 넣을 옛 역 목록, 판의 기준일, 역 좌표, 선형 검사 예외) | 사람 |
| `source/` | 설계 §2.1의 모듈 파일. 항목마다 JSON 한 줄인 YAML | 생성기, 이후 사람 |
| `sources.lock` | `imports/`의 판 기록: 경로, 크기, sha256, 받은 날, 원천 URL, 도구 버전 | `tools/lock_sources.py` |

## 다시 만들기

```bash
bash tools/all.sh
python3 -I tools/status.py
```

`all.sh`는 네트워크를 쓰지 않습니다. 같은 입력이면 `source/`와 `build/`가 바이트까지 같습니다.

- `imports/`가 있으면: 시드 생성 → 위키 대조 → 시드 재생성(옛 역 삽입) → 위키 대조 → 판 기록 → 컴파일 → 선형 → 컴파일 → 타일 → 검증 → 선형 검사
- `imports/`가 없으면 (깨끗한 체크아웃): 생성을 건너뛴다고 알리고 저장소의 `source/`를 컴파일하고 검증합니다. 원천이 필요한 대조는 건너뜁니다. `candidates/`도 없어도 됩니다.

결과는 `build/master.sqlite`, `build/names.sqlite`, `build/rail.pmtiles`, `build/rail-osm.pmtiles`, `build/manifest.json`, `build/report.json`, `build/verify.json`, `build/check_geometry.json`입니다. `rail.pmtiles`, `rail-osm.pmtiles`, `manifest.json`은 tippecanoe가 있어야 만들어집니다. 없으면 그렇게 알리고 넘어갑니다. 쓴 판은 `sources.lock`에 있습니다.

`tools/check_geometry.py`는 현행 구간의 선형 없음, 길이 비율, 끝점과 역의 거리, 이웃 끝 간격, 역과 선로의 거리, 되돌아가는 꺾임을 재고 기준을 넘으면 실패합니다. 예외는 `overrides/geometry_exceptions.json`에 사유와 함께 적은 것만 허용하고, 쓰이지 않게 된 예외도 실패로 봅니다.

`tools/status.py`는 `docs/db-status.md`를 다시 씁니다. 다른 곳에 쓰려면 경로를 인자로 줍니다.

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
python3 -I tools/wiki_kana.py data/candidates/kana_want.json data/imports/wiki_kana.json
python3 -I tools/osm_fetch.py                                    # OSM 선로. Overpass를 1도 칸씩 천천히 부른다
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

`geometry/n02.yaml`은 N02 2020·2024판(CC BY 4.0), `geometry/n02_legacy.yaml`은 2005·2008·2015판(商用可 조건), `geometry/osm.yaml`은 OpenStreetMap(ODbL 1.0)입니다. 조건이 달라 파일을 나눴고 조건은 `geometry/LICENSE.md`에 있습니다. `osm.yaml`은 `master.sqlite`, `rail.pmtiles`에 넣지 않고 `rail-osm.pmtiles`로만 만듭니다. 역의 원래 좌표에도 쓰지 않습니다. 이 선에 맞춘 역 점은 `rail-osm.pmtiles`에만 있습니다.

선형 행의 `plat`은 그 끝을 노선의 N02 승강장에 맞췄다는 뜻입니다 (`a`, `b`). 한 노드를 여러 노선이 쓰면 좌표는 하나뿐이라 노선마다 승강장이 노드 좌표와 떨어져 있습니다.

## 역 좌표

`source/positions/`의 좌표는 이렇게 정합니다. 뒤의 값이 앞의 값을 덮습니다.

1. station_database. 같은 이름의 다른 사업자 역과 좌표가 같은 경우가 많습니다.
2. Wikidata, 또는 앞뒤 역에서 km로 보간한 값 (`interpolated`).
3. 현행 역이 자기 사업자의 N02 승강장 선분에서 300m 넘게 떨어지면 승강장 가운데. 묶음과 환승 판정이 끝난 뒤에 고칩니다. 거리로 판정하는 값이 교정 때문에 흔들리면 안 되기 때문입니다.
4. `overrides/node_fix.json`의 `lat`, `lon`. 원천에 좌표가 없는 신호장과 연락선 분기입니다. `pos_note`에 근거를 적습니다.
5. `gen_geometry.py`가 옮긴 값. 보간 좌표와 지금 서지 않는 옛 역은 N02 선로 위 km 지점으로, 역 이전(`overrides/moved.json`)의 옛 역은 이전 전 N02 판의 승강장으로 옮깁니다.

노리츠부시의 사업자 코드와 노선 번호가 일부 ID에 남아 있습니다. 공개 전에 중립 값으로 바꾸고 `ids.lock`을 만듭니다. 계통별 표 km 대조는 `candidates/n_routes.json`이 있을 때만 `compile.py`가 합니다.
