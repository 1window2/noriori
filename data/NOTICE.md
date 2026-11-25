# 데이터 출처와 라이선스

## 라이선스 범위

`data/`와 그 결과물인 `master.sqlite`, `names.sqlite`, `rail.pmtiles`의 `station` 레이어는 [CC BY-SA 4.0](LICENSE)입니다. 선형은 아래처럼 원 자료의 조건을 따릅니다.

이 라이선스는 noriori가 권리를 가진 부분에만 적용됩니다. 데이터의 선택과 구성, 손으로 정한 값, 도구가 만든 값입니다. 역 이름, 노선 이름, 영업거리, 개업일과 폐지일 같은 사실 정보 자체에는 권리를 주장하지 않습니다.

행마다 `source`에 값의 출처가 있습니다.

## 파일별

| 파일 | 내용 | 조건 |
|---|---|---|
| `master.sqlite` | 역, 선로, 이벤트, km, 계통, 분모 단위. 선형은 들어 있지 않음 | CC BY-SA 4.0 |
| `names.sqlite` | 표시 이름, 별칭, 검색 색인 | CC BY-SA 4.0. 표기는 사실 정보로 취급 |
| `rail.pmtiles`의 `station` 레이어 | 역 점 | CC BY-SA 4.0. 단, 출처가 N05인 점은 아래 줄 |
| `source/positions/positions.yaml`의 `source: n05` 행과 그 값이 들어간 `master.sqlite` `node_position`(`source` = `n05`), `rail.pmtiles` `station` 레이어의 그 점 (약 2,900곳, 주로 폐역) | 역 좌표 | 国土数値情報 이용 조건 (非商用). CC BY-SA 4.0에서 뺀다. 원 자료가 유료 간행물(『停車場変遷大辞典』)을 원전으로 써서 영리·상업 목적이 아닌 이용에 한해 제공된다. noriori는 판매·광고 없는 비영리 기록 도구로 이 조건 안에서 쓴다. 상업적으로 다시 쓰려면 이 행들을 빼야 한다 |
| `rail.pmtiles`의 `edge` 레이어, `source/geometry/` | 선로 모양 | [원 자료의 조건](source/geometry/LICENSE.md) |
| `source/geometry/n05.yaml`, `overrides/geometry/n05_fill.yaml`, `overrides/positions/n05_fill.yaml` (`rail.pmtiles`의 `edge` 레이어와 역 좌표에 포함) | N02와 OSM에 없는 폐선 구간의 선로 모양 | 国土数値情報 이용 조건 (非商用). CC BY 4.0 아님 |
| `overrides/platforms/n05.yaml` (`master.sqlite`의 `platform`·`station_hub`·`station_platform` 표, `rail.pmtiles`의 `hubnode`·`platform`·`spoke` 레이어) | 환승역의 노선별 승강장 위치와 통합 노드 (DESIGN §7.5) | 国土数値情報 이용 조건 (非商用). `tools/dev/platforms.py`가 N05 역 점에서 고름 |
| `overrides/source_patch/geometry/n05_refit.yaml`, `overrides/positions/research_29.yaml`(출처 n05인 행) | 좌표를 고친 옛 역에 닿는 선로 모양, 옛 역 좌표 | 国土数値情報 이용 조건 (非商用). `research_29.yaml`의 출처 wikidata 행은 CC0 |
| `overrides/source_patch/geometry/nagao_old.yaml` | 長尾線 1951 전 옛 경로의 선로 모양 (N05 1950 판에서 잘라 냄) | 国土数値情報 이용 조건 (非商用) |
| `overrides/source_patch/geometry/johoku_old.yaml`, `overrides/source_patch/positions/johoku_old.yaml` | 伊予鉄道 城北線 1969 전 옛 上一万 칸의 선로 모양과 정류장 위치. 국토지리원 1961~1969년 공중사진을 보고 손으로 읽은 좌표 | 사실 정보(좌표)로 CC BY-SA 4.0. 판독에 쓴 자료: 국토지리원 空中写真 (出典：国土地理院) |
| `overrides/source_patch/geometry/tabata_2026-11-24.yaml` (`rail.pmtiles`의 `edge` 레이어) | 田端信号場 일대 山手貨物線·東北貨物線 3칸의 선로 모양 | 国土地理院コンテンツ利用規約 (CC BY 4.0 호환). 出典：国土地理院ベクトルタイル（鉄道中心線）を加工して作成 |
| `rail-osm.pmtiles`, `source/geometry/osm.yaml`, `overrides/osm_manual.json` | N02에 없는 선로 모양과 그 선에 맞춘 역 점 | [ODbL 1.0](source/geometry/LICENSE.md). © OpenStreetMap contributors. 역 이름과 연도는 사실 정보로 취급 |

## 출처

| 출처 | 쓴 곳 | 원 자료의 조건 |
|---|---|---|
| [国土数値情報 鉄道データ (N02)](https://nlftp.mlit.go.jp/ksj/gml/datalist/KsjTmplt-N02-2024.html), 일본 국토교통성 | 선로 모양, 현행 역 좌표 교정 | 2020년 이후 판 CC BY 4.0, 그 이전 판은 国土数値情報 이용 조건 |
| [国土地理院 ベクトルタイル 鉄道中心線](https://maps.gsi.go.jp/development/vt.html), 일본 국토지리원 | 田端信号場 일대 선로 모양 3칸 | [国土地理院コンテンツ利用規約](https://www.gsi.go.jp/kikakuchousei/kikakuchousei40182.html) (CC BY 4.0 호환) |
| [国土数値情報 行政区域データ (N03)](https://nlftp.mlit.go.jp/ksj/gml/datalist/KsjTmplt-N03-2025.html), 일본 국토교통성 | 일본 윤곽과 도도부현 경계 (`base.pmtiles`, `data/base/`), 경계를 넘는 구간의 도도부현별 km (`master.sqlite`의 `edge_pref`) | 「国土数値情報（行政区域データ）」（国土交通省）を加工して作成 |
| Noto Sans, Noto Sans CJK | 지도 역 이름의 글리프 (`glyph-*.pbf`, 한자·가나·한글 포함) | SIL OFL 1.1 ([전문](base/LICENSE-Noto.txt)) |
| [OpenStreetMap](https://www.openstreetmap.org/copyright) | N02에 없는 선로 모양과 그 선에 맞춘 역 점 (`rail-osm.pmtiles`만) | © OpenStreetMap contributors. ODbL 1.0 |
| [国土数値情報 鉄道時系列データ (N05)](https://nlftp.mlit.go.jp/ksj/gml/datalist/KsjTmplt-N05-2024.html), 일본 국토교통성 | N02와 OSM에 없는 폐선 구간의 선로 모양 (`source/geometry/n05.yaml`), OSM 폐선 경로의 대조 (`overrides/closed_geometry.json`) | 国土数値情報 이용 조건 (非商用). 「国土数値情報（鉄道時系列データ）」（国土交通省）を加工して作成 |
| [station_database](https://github.com/Seo-4d696b75/station_database), Seo-4d696b75 | 역 목록과 좌표의 시드 | CC BY-SA 4.0 |
| [일본어 위키백과](https://ja.wikipedia.org/) | 노선도, 분기와 연결, 폐선 구간의 이력과 거리, 역명의 옛 표기와 읽기 | CC BY-SA 4.0 |
| [Wikidata](https://www.wikidata.org/) | 영어 이름, 일부 역 좌표 | CC0 1.0 |
| [나무위키](https://namu.wiki/) | 한국어 표제어 표기. 문서 본문은 쓰지 않음 | 사이트 라이선스 CC BY-NC-SA 2.0 KR. 표제어 표기는 사실 정보로 취급 |
| [노리츠부시](https://www.noritsubushi.org/) (乗りつぶし) | 영업거리, 역 순서, 개업일과 폐지일의 뼈대, 일본어 표기 | 사실 정보로 취급. 사이트의 문장과 이미지는 쓰지 않음 |

배경 지도는 데이터 팩에 들어가지 않습니다. 앱이 [OpenFreeMap](https://openfreemap.org/)에서 받아 그리고, 지도 위 안내 단추에 `OpenFreeMap © OpenMapTiles Data from OpenStreetMap` 표기가 나옵니다.

## 고지

「国土数値情報（鉄道データ）」（国土交通省）を加工して作成。

「国土数値情報（鉄道時系列データ）」（国土交通省）（https://nlftp.mlit.go.jp/ksj/gml/datalist/KsjTmplt-N05-2024.html）を加工して作成。

「国土数値情報（行政区域データ）」（国土交通省）を加工して作成。

このデータは国土交通省が作成したものではありません。

데이터의 정확성과 최신성을 보증하지 않습니다. 생명이나 안전에 관련된 용도에 쓰지 마세요.
