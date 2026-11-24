# 선형의 이용 조건

이 폴더의 선형은 원 자료의 조건을 따르고 다시 허락하지 않습니다. 파일마다 조건이 달라 나눴습니다.

| 파일 | 원 자료 | 조건 |
|---|---|---|
| `n02.yaml` | 国土数値情報 鉄道データ (N02) 2020·2024판 | CC BY 4.0 |
| `n02_legacy.yaml` | 国土数値情報 鉄道データ (N02) 2005·2008·2015판 | 国土数値情報 이용 조건 (商用可). CC BY 4.0 아님 |
| `n05.yaml` | 国土数値情報 鉄道時系列データ (N05) 2024판. 폐선 구간 중 N02와 OSM에 없는 것만 | 国土数値情報 이용 조건 (非商用). CC BY 4.0 아님 |
| `osm.yaml` | OpenStreetMap | Open Database License (ODbL) 1.0 |
| `data/overrides/source_patch/geometry/` 중 출처 `gsi` 행 | 国土地理院 ベクトルタイル 鉄道中心線 (experimental_railcl, 2026-11 수집) | 国土地理院コンテンツ利用規約 (CC BY 4.0 호환, 출처 표시) |

N02 표시: 「国土数値情報（鉄道データ）」（国土交通省）を加工して作成。このデータは国土交通省が作成したものではありません。

지리원 표시: 出典：国土地理院ベクトルタイル（鉄道中心線）を加工して作成。田端信号場 일대 3칸(5회차 2026-11-24)에만 쓴다.

N05 표시: 「国土数値情報（鉄道時系列データ）」（国土交通省）（https://nlftp.mlit.go.jp/ksj/gml/datalist/KsjTmplt-N05-2024.html）を加工して作成。このデータは国土交通省が作成したものではありません。비상업 목적으로만 씁니다. 공간 오차는 수백 m, 시간 오차는 1~5년일 수 있습니다.

## OpenStreetMap

`osm.yaml`과 여기서 만든 `rail-osm.pmtiles`는 © OpenStreetMap contributors 자료에서 뽑은 데이터베이스이고 Open Database License 1.0으로 제공합니다. 조문은 <https://opendatacommons.org/licenses/odbl/1-0/>, 안내는 <https://www.openstreetmap.org/copyright>에 있습니다.

- 지도나 앱에 쓸 때는 `© OpenStreetMap contributors`를 표시합니다.
- 이 데이터베이스를 고쳐 공개하면 고친 내용도 ODbL로 공개합니다.
- `osm.yaml`의 선형은 `master.sqlite`, `names.sqlite`, `rail.pmtiles`에 넣지 않습니다. 역의 원래 좌표에도 쓰지 않습니다. 이 선에 맞춘 역 점은 `rail-osm.pmtiles`에만 있습니다 (설계 §2.11).

받은 원본은 `data/imports/osm/`에 있고 공개하지 않습니다. 판과 받은 날은 `data/sources.lock`에 있습니다.
