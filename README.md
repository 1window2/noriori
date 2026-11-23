# noriori

[![Flutter](https://img.shields.io/github/actions/workflow/status/1window2/noriori/flutter.yml?branch=main&label=Flutter&logo=flutter)](https://github.com/1window2/noriori/actions/workflows/flutter.yml) [![Android](https://img.shields.io/github/actions/workflow/status/1window2/noriori/android.yml?branch=main&label=Android&logo=android)](https://github.com/1window2/noriori/actions/workflows/android.yml) [![iOS](https://img.shields.io/github/actions/workflow/status/1window2/noriori/ios.yml?branch=main&label=iOS&logo=apple)](https://github.com/1window2/noriori/actions/workflows/ios.yml)

An app for recording how much of Japan's railway network you have ridden. Pick the stretch you rode and it is painted on the map, with completion rates by line, operator and prefecture.

- Covers every passenger line in Japan that was open on or after 1 January 1950, including lines that have since closed: JR and the former JNR, private railways, subways, trams, monorails, AGT, cable cars, and the few guideway bus, trolleybus and maglev lines run as railways. Lines that closed before 1950 are not included.
- Rides can be dated. Stations, distances, transfers and through services follow the network as it was on that day, so a ride on a line that has since closed or been renamed is recorded as it was.
- The map and line diagrams work offline.
- Records stay on your device and are backed up automatically to a folder you choose. No account, no ads.
- Imports the CSV exported from Noritsubushi and exports in the same format.
- Available in English, Japanese and Korean. In Japanese, station names written in kanji show their reading in hiragana.
- Android first. iOS is distributed by sideloading.

## Install

- **Android**: download the APK from [Releases](https://github.com/1window2/noriori/releases).
- **iOS**: add the source below to AltStore or SideStore and install noriori. New versions then show up there as updates. Apps installed with a free Apple ID must be re-signed every 7 days, and AltStore or SideStore picks up updates when it re-signs.

  ```
  https://github.com/1window2/noriori/releases/latest/download/altstore.json
  ```

  In AltStore or SideStore, open `Sources`, tap `+` and paste this address. To get the IPA directly, use `noriori-<version>-b<build>.ipa` from Releases.

## Data

Line composition and ownership follow official sources (the MLIT railway handbook 鉄道要覧 and legal records). Track geometry comes from the National Land Numerical Information datasets (N02, N05). Station lists, dates, distances and readings are cross-checked against company histories, official statistics, the National Diet Library's digitised collections and Wikipedia. A fact is used only when one primary source or two independent secondary sources support it, and the source is kept with every corrected row. Dates are actual service dates. When only a range is known, the range is stored as is.

## Help wanted

These are facts we could not confirm from any public source. For now they are stored as ranges or estimates, or left blank. If you have material that settles any of them (company histories, timetables, 官報 or official notices, transport bureau records, old route maps), please open an [issue](https://github.com/1window2/noriori/issues) or a [discussion](https://github.com/1window2/noriori/discussions). Even just the title, year and page helps a lot.

公開資料では確認できなかった事実の一覧です。社史・時刻表・官報・交通局資料などをお持ちの方は、Issue か Discussion で書名・発行年・ページを教えていただけると助かります。

<details>
<summary>Readings of old tram stop and station names (about 850)</summary>

Names used in the 1950s–70s whose reading (kana) we could not confirm from two sources. Readings are never guessed, so these show in kanji only.

- 東京 都電 142, 札幌 46, 仙台 41, 北九州 (西鉄) 34, 名古屋 27, 京都 and 熊本 23 each, 鹿児島 22, 大阪 20, 岡山 15, 福岡 (西鉄 市内線) 13, 横浜 12, 函館, 高知, 富山 and 群馬 (東武 軌道) 10 each, about 70 in other cities
- About 300 former or period names of JNR and private railway stations
</details>

<details>
<summary>Tram stop dates, existence and transfers (1940s–60s)</summary>

- とさでん 城見町 suspension; 阪堺 five stops suspended in 1944 and reopened in 1955; 大阪市電 市岡元町五丁目 reopening; 阪神国道線 御幣島
- Transfers: 嵐電 西院 to 京都市電 西大路四条; 大阪市電 浄正橋 to 福島 and 阿倍野橋
- End dates or details for 神戸市電 高松, 京都市電 東寺道, 別大線 競輪場前, 岡崎市内線 地蔵堂, 水浜線 仲町, 秋田市電 連隊前 and 表鉄砲町, 名古屋市電 東起, 専売局前 and 池ノ端
</details>

<details>
<summary>JNR freight branches and temporary stops</summary>

- Freight branches 1967–1987 (尼崎市場, 京都市場, 北旭川) and closing dates (武豊港, 根室港, 海神奈川, 瑞穂, 新生)
- Opening dates of 仮乗降場 and 臨時駅: 山口線 周防下郷 and 矢原 (1953), 筑肥線 深江浜, and 16 short-lived stops seen only in N05
- Passenger handling at 長崎港駅 and at 小坂鉄道 長木沢
</details>

<details>
<summary>Through services and track connections</summary>

- 近鉄 江戸橋: 名古屋線–伊勢線 through services, 1950–1959
- 大阪 京橋: track connection between 大阪環状線 and JR東西線
- 十勝鉄道 下清水 to 国鉄 十勝清水 transfer (1950–1951)
- 東横線 神奈川 (1945–1950)
- Whether the 鹿島臨海鉄道 大洗 through service ran after 1988
- 秋田市電 新大工町線, September 1950 to February 1951: whether cars from 新大工町 ran on to 土崎 or to 県庁前 after the 県庁前 extension
</details>

<details>
<summary>Distances (営業キロ)</summary>

- 都電 菊川一丁目, 阪急 梅田 (old site), 豊橋 東田本線 old route, 松本電鉄 浅間線 学校前, 西武 拝島線 小平–萩山 (old section)
- 北陸鉄道 金沢市内線 stops
- 秋田臨海鉄道 秋田博前 (the 1986 アッキー号)
</details>

## Development

Requires Flutter stable and tippecanoe.

```bash
bash tools/all.sh       # build the data pack
bash tools/sync_pack.sh # copy it into the app
cd apps/noriori && flutter run
```

The repository is laid out as `apps/noriori` (app), `packages/noriori_core` (rules), `packages/noriori_store` (storage), `tools/` (data pipeline) and `data/` (sources). The design is described in [docs/DESIGN.md](docs/DESIGN.md) and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), which are written in Korean.

## License

Code is under the [Apache License 2.0](LICENSE) and data under [CC BY-SA 4.0](data/LICENSE). Track geometry follows the terms of its original sources. See [NOTICE](NOTICE) and [data/NOTICE.md](data/NOTICE.md) for details.
