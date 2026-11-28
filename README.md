# noriori

[![Flutter](https://img.shields.io/github/check-runs/1window2/noriori/main?nameFilter=flutter%20%2F%20flutter&label=Flutter&logo=flutter)](https://github.com/1window2/noriori/actions/workflows/ci.yml?query=branch%3Amain) [![Android](https://img.shields.io/github/check-runs/1window2/noriori/main?nameFilter=android%20%2F%20android&label=Android&logo=android)](https://github.com/1window2/noriori/actions/workflows/ci.yml?query=branch%3Amain) [![iOS](https://img.shields.io/github/check-runs/1window2/noriori/main?nameFilter=ios%20%2F%20ios&label=iOS&logo=apple)](https://github.com/1window2/noriori/actions/workflows/ci.yml?query=branch%3Amain)

An app for recording how much of Japan's railway network you have ridden. Pick the stretch you rode and it is painted on the map, with completion rates by line, operator and prefecture.

- Covers every passenger line in Japan that was open on or after 1 January 1950, including lines that have since closed: JR and the former JNR, private railways, subways, trams, monorails, AGT, cable cars, and the few guideway bus, trolleybus and maglev lines run as railways. Lines and stations that closed before 1950 are shown for reference only and cannot be recorded.
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

Line composition and ownership follow official sources (the MLIT railway handbook 鉄道要覧 and legal records). Track geometry comes from the National Land Numerical Information datasets (N02, N05), with a few sections traced from the GSI railway centerline. Station lists, dates, distances and readings are cross-checked against company histories, official statistics, the National Diet Library's digitised collections and Wikipedia. A fact is used only when one primary source or two independent secondary sources support it, and the source is kept with every corrected row. The one exception is readings found only in the railforum station lists, which are used and marked as resting on a single source (see below). Dates are actual service dates. When only a range is known, the range is stored as is.

## Help wanted

These are facts we could not confirm from any public source. For now they are stored as ranges or estimates, or left blank. If you have material that settles any of them (company histories, timetables, 官報 or official notices, transport bureau records, old route maps), please open an [issue](https://github.com/1window2/noriori/issues) or a [discussion](https://github.com/1window2/noriori/discussions). Even just the title, year and page helps a lot.

<details>
<summary>Readings of old stop and station names</summary>

Readings are never guessed. A name with no confirmed reading shows in kanji only.

- About 80 names with no reading found at all, most of them old tram stops (札幌 and 仙台 市電 among them) and the 苫小牧製紙 (王子軽便鉄道) stops.
- About 1,300 readings rest on a single source, the railforum station lists. One independent source (a timetable, company history or official station list) would confirm each of them.
- About 15 more readings rest on one source other than railforum (長住町 and others), and six disagree with the reading of the place name (六角橋 and others).
- The readings of 小野田港北口 and 新銭町, and the name of the 岩見沢 freight station in 1882–1885.
</details>

<details>
<summary>Tram stop dates, existence and transfers (1940s–60s)</summary>

- とさでん 城見町 suspension; 阪堺 five stops suspended in 1944 and reopened in 1955; 大阪市電 市岡元町五丁目 reopening; 阪神国道線 御幣島
- Transfers: 嵐電 西院 to 京都市電 西大路四条; 大阪市電 浄正橋 to 福島 and 阿倍野橋
- End dates or details for 神戸市電 高松, 京都市電 東寺道, 別大線 競輪場前, 岡崎市内線 地蔵堂, 水浜線 仲町, 秋田市電 連隊前 and 表鉄砲町, 名古屋市電 東起
- 万葉線: the stop list and stop names from December 1980 to April 2002
- 京都市電 堀川線: whether it still served 京都駅前 between July 1926 and April 1927, when its terminus was at 西洞院塩小路
- 西稲永 (名古屋市電): the date it was renamed from 稲永
</details>

<details>
<summary>Stops with the same name</summary>

Where two stops or stations of the same name stood apart at the same time, we count them as one station only if the operator treated them as one, or if they served as one interchange in front of the station. Distance alone does not decide it.

- 都電 錦糸町駅前: the exact date the north stop (石原線) changed its name from 錦糸堀 to 錦糸町駅前 (between September 1958 and 1962). It is not in the data yet.
- 都電 新宿駅前: what the 1963 change from the "old" to the "new" 新宿駅前 on route 14 was (a single snippet; the two 新宿駅前 stops are already separate stations).
- 東武 伊香保軌道線 高崎線 (高崎駅前–渋川) 九蔵町: where the stop stood. Its position is only interpolated, so the map line ends about 270 m from it.
- 名古屋市電 大曽根: the exact position of the stop at the 大曽根 crossing (we have only an approximate one).
- 東急 玉川線 二子玉川: whether the tram stop and the station were one stop (二子玉川園).
</details>

<details>
<summary>JNR freight branches and temporary stops</summary>

- Freight branches 1967–1987 (尼崎市場, 京都市場, 北旭川) and closing dates (武豊港, 根室港, 海神奈川, 瑞穂, 新生)
- Opening dates of 仮乗降場 and 臨時駅: 山口線 周防下郷 and 矢原 (1953), 筑肥線 深江浜, and 16 short-lived stops seen only in N05
- Passenger handling at 長崎港駅 and at 小坂鉄道 長木沢
</details>

<details>
<summary>Wartime closures (1941–1945)</summary>

- 有田鉄道 明王寺 (opened 1935): closing date
- 都電 高円寺線 新宿駅前–角筈一丁目 (0.3 km, suspended 1944): the exact section
- 生駒鋼索線 宝山寺–生駒山上 suspension and reopening dates
- 箱根登山 鋼索線: whether the 1944 suspension began on 10 or 11 February
- 関西本線 志紀: whether the suspension began in September or October 1947
- 近鉄 名古屋線 霞ヶ浦 (the first station of that name): the year it became a regular station
</details>

<details>
<summary>Through services and track connections</summary>

- 近鉄 江戸橋: 名古屋線–伊勢線 through services, 1950–1959
- 大阪 京橋: track connection between 大阪環状線 and JR東西線
- 十勝鉄道 下清水 to 国鉄 十勝清水 transfer (1950–1951)
- 東横線 神奈川 (1945–1950)
- Whether the 鹿島臨海鉄道 大洗 through service ran after 1988
- 秋田市電 新大工町線, September 1950 to February 1951: whether cars from 新大工町 ran on to 土崎 or to 県庁前 after the 県庁前 extension
- Whether cars reversed and ran straight through at 名鉄 岩倉 (一宮線 and 岩倉支線, 1920–1964), 琴電 瓦町 (長尾線 to 琴平線, 1945–1951) and 豊橋 神明 (東田本線 to 柳生橋支線, 1946–1950)
- Nine junctions where the recorded through-service destinations and the station positions point to opposite sides for the connecting track: 築別, 勝田 (湊線), 植木, 松本 (上高地線), 川西能勢口, 鵜沼, 金谷 (大井川本線), 西宮北口 and 函館 十字街. A track diagram or photo would settle each.
- 上田交通 上田: whether the 別所線 and 真田傍陽線 tracks were connected inside the station (there was no through passenger service)
- Stopping patterns of some services: 横須賀線 before 1980, 高崎線 before 1968, つばさ (1992), こまち and あさま (1997)
- About 70 places where a closed branch or tram line met another line: which way the connecting curve faced, that is, toward which neighbouring stop cars could run straight on. About a third have one source and the rest have none. For 東京 the 電車運轉系統 tables in 東京市電気局『電気事業成績調書』 (NDL, public) list the main stops of each route and settle many of them; we have read only the 1932 table so far. Old route maps (運転系統図), track layouts and photos of the junctions are the most useful material.
</details>

<details>
<summary>Records that can only be seen on request</summary>

These records are open to the public but not online, so they can only be read by requesting a copy or at a library or archive. If you have seen any of them, or have a copy, please tell us.

- 東京都公文書館, microfilm: track diagrams of 都電 junctions (新橋, 萬世橋, 四谷見附, 駕籠町, 虎ノ門, 上野広小路, 浅草橋, 飯田橋, 関口水道町, 茅場町, 新常盤橋, 緑町)
- 国立公文書館, 軌道特許 files on the connecting tracks at 虎ノ門, 浅草橋際 and 万世橋南詰 (1920), 駕籠町 (1920) and 坂本町 (1921)
- 国立公文書館, 鉄道省 files on 有田鉄道 (1933–1946), including the 1934 file on opening 明王寺: for the closing date of 明王寺
- 京都市交通局『軌道事業略史』(1952, held by NDL but not online): for the 京都駅前 stop of the 堀川線
- 『近畿日本鉄道100年のあゆみ』 (江戸橋 through services, 生駒鋼索線 dates), 『鹿島臨海鉄道30年史』 (大洗 through service), and the GSI 1:10,000 old topographic maps of 上田 (the track connection at 上田)
</details>

<details>
<summary>English station names</summary>

Station names follow each operator's official English spelling. About 540 current stations, most of them on JR Kyushu and small private lines, still use a Wikidata label or a name generated by our romanisation rules because we have not found an official spelling. A photo of the station name sign, or an official English station list or route map, is enough.

- About 100 of them are JR Kyushu stations. For 86 we have no lead at all, because the company website refuses automated requests; its English route map would settle many of them.
- About 30 rest only on sign photos taken before 2010, so the spelling may have changed since.
- About 50 closed stations where ん comes before b, m or p: whether the old official spelling used n or m (Honmachi or Hommachi) rests on a single source.
</details>

<details>
<summary>Distances (営業キロ)</summary>

- 都電 菊川一丁目, 阪急 梅田 (old site), 豊橋 東田本線 old route, 松本電鉄 浅間線 学校前, 西武 拝島線 小平–萩山 (old section)
- 北陸鉄道 金沢市内線 stops
- 秋田臨海鉄道 秋田博前 (the 1986 アッキー号)
</details>

## Development

Requires Flutter stable, Python 3 and tippecanoe.

```bash
bash tools/all.sh       # build the data pack
bash tools/sync_pack.sh # copy it into the app
cd apps/noriori && flutter run
```

The repository is laid out as `apps/noriori` (app), `packages/noriori_core` (rules), `packages/noriori_store` (storage), `tools/` (data pipeline) and `data/` (sources). The design is described in [docs/DESIGN.md](docs/DESIGN.md) and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), which are written in Korean.

## License

Code is under the [Apache License 2.0](LICENSE) and data under [CC BY-SA 4.0](data/LICENSE). Track geometry follows the terms of its original sources. Data derived from the MLIT N05 railway time series (mainly geometry and coordinates of closed stations) may be used for non-commercial purposes only; noriori is a free, ad-free, non-commercial tool. See [NOTICE](NOTICE) and [data/NOTICE.md](data/NOTICE.md) for details.
