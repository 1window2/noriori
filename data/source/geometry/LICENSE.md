# 선형의 이용 조건

이 폴더의 선형은 원 자료의 조건을 따르고 다시 허락하지 않습니다. 파일마다 조건이 달라 나눴습니다.

| 파일 | 원 자료 | 조건 |
|---|---|---|
| `n02.yaml` | 国土数値情報 鉄道データ (N02) 2020·2024판 | CC BY 4.0 |
| `n02_legacy.yaml` | 国土数値情報 鉄道データ (N02) 2005·2008·2015판 | 国土数値情報 이용 조건 (商用可). CC BY 4.0 아님 |
| `osm.yaml` | OpenStreetMap | Open Database License (ODbL) 1.0 |

N02 표시: 「国土数値情報（鉄道データ）」（国土交通省）を加工して作成。このデータは国土交通省が作成したものではありません。

## OpenStreetMap

`osm.yaml`과 여기서 만든 `rail-osm.pmtiles`는 © OpenStreetMap contributors 자료에서 뽑은 데이터베이스이고 Open Database License 1.0으로 제공합니다. 조문은 <https://opendatacommons.org/licenses/odbl/1-0/>, 안내는 <https://www.openstreetmap.org/copyright>에 있습니다.

- 지도나 앱에 쓸 때는 `© OpenStreetMap contributors`를 표시합니다.
- 이 데이터베이스를 고쳐 공개하면 고친 내용도 ODbL로 공개합니다.
- `osm.yaml`의 선형은 `master.sqlite`, `names.sqlite`, `rail.pmtiles`에 넣지 않습니다. 역의 원래 좌표에도 쓰지 않습니다. 이 선에 맞춘 역 점은 `rail-osm.pmtiles`에만 있습니다 (설계 §2.11).

받은 원본은 `data/imports/osm/`에 있고 공개하지 않습니다. 판과 받은 날은 `data/sources.lock`에 있습니다.
