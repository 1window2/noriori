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
| `rail.pmtiles`의 `station` 레이어 | 역 점 | CC BY-SA 4.0 |
| `rail.pmtiles`의 `edge` 레이어, `source/geometry/` | 선로 모양 | [원 자료의 조건](source/geometry/LICENSE.md) |
| `rail-osm.pmtiles`, `source/geometry/osm.yaml`, `overrides/osm_manual.json` | N02에 없는 선로 모양과 그 선에 맞춘 역 점 | [ODbL 1.0](source/geometry/LICENSE.md). © OpenStreetMap contributors. 역 이름과 연도는 사실 정보로 취급 |

## 출처

| 출처 | 쓴 곳 | 원 자료의 조건 |
|---|---|---|
| [国土数値情報 鉄道データ (N02)](https://nlftp.mlit.go.jp/ksj/gml/datalist/KsjTmplt-N02-2024.html), 일본 국토교통성 | 선로 모양, 현행 역 좌표 교정 | 2020년 이후 판 CC BY 4.0, 그 이전 판은 国土数値情報 이용 조건 |
| [国土数値情報 行政区域データ (N03)](https://nlftp.mlit.go.jp/ksj/gml/datalist/KsjTmplt-N03-2025.html), 일본 국토교통성 | 일본 윤곽과 도도부현 경계 (`base.pmtiles`, `data/base/`) | 「国土数値情報（行政区域データ）」（国土交通省）を加工して作成 |
| Noto Sans, Noto Sans CJK | 지도 역 이름의 글리프 (`glyph-*.pbf`, 한자·가나·한글 포함) | SIL OFL 1.1 ([전문](base/LICENSE-Noto.txt)) |
| [OpenStreetMap](https://www.openstreetmap.org/copyright) | N02에 없는 선로 모양과 그 선에 맞춘 역 점 (`rail-osm.pmtiles`만) | © OpenStreetMap contributors. ODbL 1.0 |
| [station_database](https://github.com/Seo-4d696b75/station_database), Seo-4d696b75 | 역 목록과 좌표의 시드 | CC BY-SA 4.0 |
| [일본어 위키백과](https://ja.wikipedia.org/) | 노선도, 분기와 연결, 폐선 구간의 이력과 거리, 역명의 옛 표기와 읽기 | CC BY-SA 4.0 |
| [Wikidata](https://www.wikidata.org/) | 영어 이름, 일부 역 좌표 | CC0 1.0 |
| [나무위키](https://namu.wiki/) | 한국어 표제어 표기. 문서 본문은 쓰지 않음 | 사이트 라이선스 CC BY-NC-SA 2.0 KR. 표제어 표기는 사실 정보로 취급 |
| [노리츠부시](https://www.noritsubushi.org/) (乗りつぶし) | 영업거리, 역 순서, 개업일과 폐지일의 뼈대, 일본어 표기 | 사실 정보로 취급. 사이트의 문장과 이미지는 쓰지 않음 |

배경 지도는 데이터 팩에 들어가지 않습니다. 앱이 [OpenFreeMap](https://openfreemap.org/)에서 받아 그리고, 지도 위 안내 단추에 `OpenFreeMap © OpenMapTiles Data from OpenStreetMap` 표기가 나옵니다.

## 고지

「国土数値情報（鉄道データ）」（国土交通省）を加工して作成。

「国土数値情報（行政区域データ）」（国土交通省）を加工して作成。

このデータは国土交通省が作成したものではありません。

데이터의 정확성과 최신성을 보증하지 않습니다. 생명이나 안전에 관련된 용도에 쓰지 마세요.
