# 仮乗降場·臨時駅 3차 점검 (2026-11-07)

기계용 결과: `temp_stops.json`(116행). 근거는 일본어 위키백과(문서 제목+oldid는 JSON `why`). 저장소는 고치지 않았다. 대조한 빌드: 2026-11-07 09:17 `build/master.sqlite`·`names.sqlite`.

## 집계

| 과제 | 제안 행 | 메모(고치지 않음·못 넣음·확인) |
|---|---|---|
| A | 37 | 13 |
| B | 28 | 17 |
| C | 11 | 10 |

## A. 날짜 불일치·미수록

| 경우 | 파일 | 행 | 확신 | 지금 DB |
|---|---|---|---|---|
| 上越(石北本線) 仮乗降場 끝 | stop_dates.json | `{"n_kamikoshi": [null, "1983-01-10"]}` | medium | r_sekihoku_main_line 1932-10-01~1975-12-25 |
| 中能取(湧網線) 폐지일 | stop_dates.json | `{"n_nakanotoro": [null, "1972-02-08"]}` | high | r_yumo_line 1956-01-07~1987-03-20 |
| 土佐(湧網線) 폐지일 | stop_dates.json | `{"n_tosa": [null, "1972-02-08"]}` | high | r_yumo_line 1956-01-07~1987-03-20 |
| 常呂港(湧網線) 폐지일 | stop_dates.json | `{"n_tokoroko": [null, "1972-02-08"]}` | high | r_yumo_line 1956-01-07~1987-03-20 |
| 競輪場入口(広電宇品線) 폐지일 | stop_dates.json | `{"r_ujina_line_hiroden\|n_keirinjoiriguchi": [null, "2002-08-31"]}` | medium | r_ujina_line_hiroden 1935-12-27~194X-XX-XX |
| 競輪場入口 status 끝 | stop_status.json | `{"node": "n_keirinjoiriguchi", "change": {"to": "2002-08-31"}}` | medium | r_ujina_line_hiroden 1935-12-27~194X-XX-XX |
| 原生花園 仮乗降場 시기 | stop_dates.json | `{"n_genseikaen": ["1964-06-01", null]}` | medium | r_senmo_main_line 1987-07-01~ongoing |
| 大曲(深名線) 기간 | stop_dates.json | `{"r_shinmei_line\|n_omagari_shinmei": ["1955-08-20", "1976-02-01"]}` | high | r_shinmei_line 1932-10-25~1995-09-04 |
| 宇津内 status 끝 | stop_status.json | `{"node": "n_utsunai", "change": {"to": "1956-11-19"}}` | low | r_shinmei_line 1941-10-10~1956-11-19 |
| 於札内 끝 날짜 | 메모 | `—` | high | r_sassho_line 1959-12-01~2020-04-18 |
| 桂川(函館本線) 시작 | 메모 | `—` | medium | r_hakodate_main_line 1944-09-30~2017-03-04 |
| 鷲ノ巣 시작 | stop_dates.json | `{"n_washinosu": ["1944-09-01", null]}` | high | r_hakodate_main_line 1987-04-01~2016-03-26 |
| 今川(羽越本線) 시작 | stop_dates.json | `{"n_imagawa": ["1944-07-01", null]}` | low | r_uetsu_main_line 1987-04-01~ongoing |
| 舟子→大川ダム公園 1980 이설 | moved.json | `{"old": "n_funako", "new": "n_okawa_dam_koen", "date": "1980-12-01", "note": "舟子仮乗降場 大川ダム建設に伴う移設 (1987 舟子駅,…` | high | r_aizu_line_ashinomaki_onsen_yunokami_onsen 1968-10-17~1980-12-01 / r_ |
| 大川ダム公園 1980~1987 | stop_dates.json | `{"r_aizu_line\|n_okawa_dam_koen": ["1980-12-01", null]}` | high | r_aizu_line 1987-04-01~1987-07-16 |
| 大川ダム公園 仮乗降場 표식 | stop_status.json | `{"node": "n_okawa_dam_koen", "kind": "kari", "from": "1980-12-01", "to": "1987-04-01", "name": "大川ダム公園駅", "…` | high | r_aizu_line 1987-04-01~1987-07-16; r_aizu_line_aizu 1987-07-16~ongoing |
| 舟子 status 끝 | stop_status.json | `{"node": "n_funako", "change": {"to": "1980-12-01"}}` | high | r_aizu_line_ashinomaki_onsen_yunokami_onsen 1968-10-17~1980-12-01 |
| 布原 시작 | stop_dates.json | `{"n_nunohara": ["1953-XX-XX", null]}` | medium | r_hakubi_line 1987-04-01~ongoing |
| 柿ノ木 시작 | stop_dates.json | `{"n_kakinoki": ["1951-03-01", null]}` | high | r_tadami_line 1987-04-01~2015-03-14 |
| 江田(磐越東線) 시작 | stop_dates.json | `{"n_eda": ["1948-10-01", null]}` | high | r_banetsu_east_line 1987-03-31~ongoing |
| 清流みはらし | 메모 | `—` | high | r_gannichi_line 1960-11-01~1987-07-25 (is_stop=0); r_nishikigawa_seiry |
| 粟ヶ崎海岸 끝 | 메모 | `—` | high | r_asanogawa_line 1952-XX-XX~1972-09-01 |
| 面白山高原 시작 | stop_dates.json | `{"n_omoshiroyama_kogen": ["1937-11-10", null]}` | high | r_senzan_line 1987-04-01~ongoing |
| 鮎喰 시작 | stop_dates.json | `{"n_akui": ["1986-11-01", null]}` | high | r_tokushima_line 1934-09-20~ongoing |
| 鹿島サッカースタジアム 시작 | stop_dates.json | `{"r_kashima_line\|n_kashima_soccer_stadium": ["1994-03-12", null]}` | medium | r_kashima_line 1978-07-25~ongoing |
| 野井仮乗降場(三江北線) | 메모 | `—` | high | r_sanko_line 1972-11-XX~1973-11-XX |
| 鳥ノ沢仮乗降場 기간 | stop_dates.json | `{"n_torinosawa": ["1948-11-01", "1971-07-01"]}` | high | r_sekihoku_main_line 1912-10-05~1971-XX-XX |
| 鳥ノ沢仮乗降場 표식 | stop_status.json | `{"node": "n_torinosawa", "kind": "kari", "from": "1948-11-01", "to": "1971-07-01", "name": "鳥ノ沢仮乗降場", "sour…` | high | r_sekihoku_main_line 1912-10-05~1971-XX-XX |
| 美野仮乗降場 시작 | stop_dates.json | `{"n_mino": ["1946-07-XX", null]}` | medium | r_sekihoku_main_line 1912-10-05~1958-XX-XX |
| 美野仮乗降場 표식 | stop_status.json | `{"node": "n_mino", "kind": "kari", "from": "1946-07-XX", "to": "1958-XX-XX", "name": "美野仮乗降場", "source": "h…` | medium | r_sekihoku_main_line 1912-10-05~1958-XX-XX |
| 神路(宗谷本線) | wiki_insert.json | `{"family": "jr", "line": "宗谷本線", "name": "神路", "close": "1985", "open": "1922", "km": 143.1, "prev": "筬島", …` | high | 노드 없음 |
| 常紋(石北本線) | wiki_insert.json | `{"family": "jr", "line": "石北本線", "name": "常紋", "close": "1975", "open": "1951", "km": 148.0, "prev": "生田原",…` | medium | 노드 없음 |
| 東塩尻(中央本線 辰野経由) | wiki_insert.json | `{"family": "jr", "line": "中央本線", "name": "東塩尻", "close": "1983", "open": "1949", "km": 22.7, "prev": "小野", …` | high | 노드 없음 |
| 白浜海岸(三陸鉄道南リアス線) | wiki_insert.json | `{"family": "psanriku_railway", "line": "リアス線", "name": "白浜海岸", "close": "1992", "open": "1986", "km": 9.8, …` | medium | 노드 없음 |
| フォトデッキ(小海線) | wiki_insert.json | `{"family": "jr", "line": "小海線", "name": "フォトデッキ", "close": "1986", "open": "1986", "km": 21.1, "prev": "清里"…` | high | 노드 없음 |
| 緑化フェア梅小路(山陰本線) | wiki_insert.json | `{"family": "jr", "line": "山陰本線", "name": "緑化フェア梅小路", "close": "1994", "open": "1994", "km": 1.1, "prev": "京…` | high | 노드 없음 |
| 浜中海水浴場(留萌本線) | wiki_insert.json | `{"family": "jr", "line": "留萌本線", "name": "浜中海水浴場", "close": "1995", "open": "1989", "km": 54.0, "prev": "瀬越…` | high | 노드 없음 |
| 世界焱博(松浦鉄道西九州線) | wiki_insert.json | `{"family": "pmatsuura_railway", "line": "西九州線", "name": "世界焱博", "close": "1996", "open": "1996", "km": 2.5,…` | high | 노드 없음 |
| 一ノ堰六地蔵尊(会津鉄道会津線) | wiki_insert.json | `{"family": "paizu_railway", "line": "会津線", "name": "一ノ堰六地蔵尊", "close": "2013", "open": "2009", "km": 4.0, "…` | high | 노드 없음 |
| フイハップ浜(日高本線) | wiki_insert.json | `{"family": "jr", "line": "日高本線", "name": "フイハップ浜", "close": "1993", "open": "1989", "km": null, "prev": "汐見…` | medium | 노드 없음 |
| 静内海水浴場(日高本線) | wiki_insert.json | `{"family": "jr", "line": "日高本線", "name": "静内海水浴場", "close": "1992", "open": "1991", "km": null, "prev": "静内…` | medium | 노드 없음 |
| 東声問(天北線) | wiki_insert.json | `{"family": "jr", "line": "天北線", "name": "東声問", "close": "1987", "open": "1987", "km": null, "prev": "恵北", "…` | medium | 노드 없음 |
| 十府ヶ浦(三陸鉄道北リアス線) 1986~1994/1999 | 메모 | `—` | medium | r_kuji_line 1975-07-20~1984-04-01 (is_stop=0); r_rias_line 2017-03-25~ |
| 小松島港仮乗降場(小松島線) | 메모 | `—` | high |  |
| 船着場仮乗降場(境線) | 메모 | `—` | high |  |
| 大加島仮乗降場(井川線) | 메모 | `—` | high |  |
| 万国博中央口(北大阪急行 会場線) | 메모 | `—` | high |  |
| ナゴヤ球場正門前·福岡ボート前·秋田博前 | 메모 | `—` | high |  |
| 현행 臨時駅 5곳(仁愛グランド前·津島ノ宮·ラベンダー畑·田井ノ浜·岡山電軌 京橋) | 메모 | `—` | high |  |
| 넣지 않음: 北彩都あさひかわ·谷地坊主村·糠平ダム·内野中学校前 | 메모 | `—` | medium |  |

## B. 정차 시작일(앞선 보통 역/반대 경우)

| 경우 | 파일 | 행 | 확신 | 지금 DB |
|---|---|---|---|---|
| n_hariusu 확인 | 메모 | `—` | high | r_hakodate_main_line 1905-10-08~2006-03-18 |
| n_chito 확인 | 메모 | `—` | high | r_soya_main_line 1924-06-01~2006-03-18 |
| n_uembetsu 확인 | 메모 | `—` | high | r_shinmei_line 1931-09-15~1990-03-10 |
| n_fukinodai 확인 | 메모 | `—` | high | r_shinmei_line 1941-10-10~1990-03-10 |
| n_shirakaba 확인 | 메모 | `—` | high | r_shinmei_line 1941-10-10~1990-03-10 |
| n_hosooka 확인 | 메모 | `—` | high | r_senmo_main_line 1927-09-15~ongoing |
| n_tagokura 확인 | 메모 | `—` | high | r_tadami_line 1971-08-29~2013-03-16 |
| n_yoshiokateiten 확인 | 메모 | `—` | high | r_kaikyo_line 1988-03-13~2014-03-15 |
| n_utsunai 확인 | 메모 | `—` | high | r_shinmei_line 1941-10-10~1956-11-19 |
| n_oroen 확인 | 메모 | `—` | high | r_iburi_line 1941-10-12~1985-XX-XX |
| n_bentenjima 확인 | 메모 | `—` | high | r_tokaido_main_line 1906-07-11~ongoing |
| n_shinano_shiratori 확인 | 메모 | `—` | high | r_iiyama_line 1925-11-19~ongoing |
| n_koboro 확인 | 메모 | `—` | high | r_muroran_main_line 1943-09-25~ongoing |
| n_higashiyama 확인 | 메모 | `—` | medium | r_hakodate_main_line 1943-02-26~2017-03-04 |
| n_minamiuryu 시작 | stop_dates.json | `{"n_minamiuryu": ["1956-11-16", null]}` | high | r_sassho_line 1931-10-10~1972-06-19 |
| n_nakauryu 시작 | stop_dates.json | `{"n_nakauryu": ["1956-11-16", null]}` | high | r_sassho_line 1931-10-10~1972-06-19 |
| n_kitasato 시작 | stop_dates.json | `{"n_kitasato": ["1956-05-01", null]}` | high | r_haboro_line 1936-10-23~1970-09-07 |
| n_kokomae 시작 | stop_dates.json | `{"n_kokomae": ["1955-08-20", null]}` | high | r_aioi_line 1925-11-15~1985-04-01 |
| n_okotsu 시작 | stop_dates.json | `{"n_okotsu": ["1956-09-01", null]}` | high | r_haboro_line 1932-09-01~1987-03-30 |
| n_tomioka_haboro 시작 | stop_dates.json | `{"n_tomioka_haboro": ["1956-05-13", null]}` | high | r_haboro_line 1928-10-10~1987-03-30 |
| n_toyohama_kohin_north 시작 | stop_dates.json | `{"n_toyohama_kohin_north": ["1956-02-26", null]}` | high | r_kohin_north_line 1936-07-10~1985-07-01 |
| n_keirinjomae_toyama_chiho (r_toyamako_line) 시작 | stop_dates.json | `{"r_toyamako_line\|n_keirinjomae_toyama_chiho": ["1959-04-18", null]}` | high | r_toyamako_line 1924-07-23~2006-03-01 |
| n_keirinjomae_toyama_chiho (r_toyamako_line_toyama_chiho) 시작 | stop_dates.json | `{"r_toyamako_line_toyama_chiho\|n_keirinjomae_toyama_chiho": ["2006-04-29", null]}` | high | r_toyamako_line_toyama_chiho 2006-03-01~ongoing |
| n_aoyagigahama 시작 | stop_dates.json | `{"n_aoyagigahama": ["1949-07-01", null]}` | high | r_kojaku_railway_line 1926-08-15~1969-11-01 |
| n_bankokuhakunishiguchi 시작 | stop_dates.json | `{"n_bankokuhakunishiguchi": ["1969-11-10", null]}` | high | r_senri_line 1967-03-01~1970-09-14 |
| n_kita_karuizawa 시작 | stop_dates.json | `{"n_kita_karuizawa": ["1918-06-15", null]}` | high | r_kusakaru_electric_railway_line 1917-07-19~1960-04-25 |
| n_monju 시작 | stop_dates.json | `{"n_monju": ["1946-11-01", null]}` | high | r_utashinai_line 1941-07-01~1988-04-25 |
| n_arimagawa (r_hokuriku_main_line_uramoto_arimagawa) 시작 | stop_dates.json | `{"r_hokuriku_main_line_uramoto_arimagawa\|n_arimagawa": ["1946-09-01", null]}` | high | r_hokuriku_main_line_uramoto_arimagawa 1911-07-01~1969-09-29 |
| n_higashi_shikagoe (r_nemuro_main_line_kanayama_nemuro_main_higashi_shikagoe) 시작 | stop_dates.json | `{"r_nemuro_main_line_kanayama_nemuro_main_higashi_shikagoe\|n_higashi_shikagoe": ["1941-12-29", null]}` | medium | r_nemuro_main_line_kanayama_nemuro_main_higashi_shikagoe 1901-09-03~19 |
| n_himekawa_hakodate_main 시작 | stop_dates.json | `{"n_himekawa_hakodate_main": ["1951-05-19", null]}` | medium | r_hakodate_main_line 1913-08-01~2017-03-04 |
| n_niyama 시작 | stop_dates.json | `{"n_niyama": ["1943-XX-XX", null]}` | medium | r_hakodate_main_line 1936-09-15~2026-03-14 |
| n_hon_ishikura 시작 | stop_dates.json | `{"n_hon_ishikura": ["1948-07-01", null]}` | medium | r_hakodate_main_line 1944-09-10~2022-03-12 |
| n_nishi_shoro 시작 | stop_dates.json | `{"n_nishi_shoro": ["1951-04-01", null]}` | high | r_nemuro_main_line 1941-03-28~ongoing |
| n_omagari_shinmei / n_akui / n_kashima_soccer_stadium / n_kamikoshi | 메모 | `—` | high |  |
| n_katsuragawa_hakodate_main | 메모 | `—` | medium | r_hakodate_main_line 1944-09-30~2017-03-04 |
| n_ebikawa 시작(반대 경우: 仮·臨 시기가 정차 전) | stop_dates.json | `{"r_ohata_line\|n_ebikawa": ["1960-XX-XX", null]}` | medium | r_ohata_line 1966-12-15~1985-07-01 |
| n_funahirayama 시작(반대 경우: 仮·臨 시기가 정차 전) | stop_dates.json | `{"n_funahirayama": ["1947-XX-XX", null]}` | medium | r_yamaguchi_line 1961-04-01~ongoing |
| n_higashi_gejo 시작(반대 경우: 仮·臨 시기가 정차 전) | stop_dates.json | `{"n_higashi_gejo": ["1951-04-XX", null]}` | medium | r_banetsu_west_line 1953-01-10~ongoing |
| n_hirabayashi 시작(반대 경우: 仮·臨 시기가 정차 전) | stop_dates.json | `{"n_hirabayashi": ["1944-XX-XX", null]}` | medium | r_uetsu_main_line 1952-05-15~ongoing |
| n_kita_ichiyan 시작(반대 경우: 仮·臨 시기가 정차 전) | stop_dates.json | `{"n_kita_ichiyan": ["1954-11-XX", null]}` | medium | r_rumoi_main_line 1955-07-20~2026-04-01 |
| n_masumicho 시작(반대 경우: 仮·臨 시기가 정차 전) | stop_dates.json | `{"n_masumicho": ["1951-XX-XX", null]}` | medium | r_yubetsu_railway 1956-09-01~1970-04-16 |
| n_minamichokai 시작(반대 경우: 仮·臨 시기가 정차 전) | stop_dates.json | `{"n_minamichokai": ["1951-XX-XX", null]}` | medium | r_uetsu_main_line 1952-01-16~ongoing |
| n_nishikinohama 시작(반대 경우: 仮·臨 시기가 정차 전) | stop_dates.json | `{"n_nishikinohama": ["1936-06-XX", null]}` | medium | r_nankai_main_line 1938-10-01~ongoing |
| n_shin_yubetsu 시작(반대 경우: 仮·臨 시기가 정차 전) | stop_dates.json | `{"r_yubetsu_railway\|n_shin_yubetsu": ["1947-XX-XX", null]}` | medium | r_yubetsu_railway 1953-04-11~1970-04-16 |
| 시작 불명이라 그대로: 名寄高校(東風連)·東追分·恩根 | 메모 | `—` | medium |  |

## C. MOVED·UNSURE

| 경우 | 파일 | 행 | 확신 | 지금 DB |
|---|---|---|---|---|
| MOVED 椿宮→市坪 | stop_dates.json | `{"n_ichitsubo": ["1933-01-21", null]}` | medium | r_yosan_line 1964-10-01~ongoing |
| MOVED 椿宮→市坪 이름 | renames_hand.json | `{"n_ichitsubo": [["椿宮", null, "1964-10-01"]]}` | medium | 이름 이력 없음 |
| MOVED 下政和→政和温泉 | stop_dates.json | `{"n_seiwa_onsen": ["1955-08-20", null]}` | high | r_shinmei_line 1961-12-01~1990-03-10 |
| MOVED 下政和 이름 | renames_hand.json | `{"n_seiwa_onsen": [["下政和", null, "1961-12-01"]]}` | high | 이름 이력 없음 |
| MOVED 下政和 status | stop_status.json | `{"node": "n_seiwa_onsen", "change": {"from": "1955-08-20"}}` | high | r_shinmei_line 1961-12-01~1990-03-10 |
| MOVED 旗ヶ岡→旗の台 | 메모 | `—` | medium | r_oimachi_line 1927-07-06~ongoing; r_ikegami_line 1927-08-28~ongoing |
| MOVED 諏訪→近鉄四日市 | 메모 | `—` | medium | r_nagoya_line 1956-09-23~ongoing; r_yunoyama_line 1956-09-23~ongoing |
| MOVED 別所→大津市役所前 이름 | renames_hand.json | `{"n_otsu_shiyakusho_mae": [["兵営前", null, "1940-11-10"], ["別所", "1940-11-10", "2018-03-17"]]}` | high | 이름 이력 없음; r_ishiyama_sakamoto_line 1927-05-15~ongoing |
| MOVED 天神橋→天神橋筋六丁目(阪急) 이름 | renames_hand.json | `{"n_tenjimbashisuji_6_chome_hankyu": [["天神橋", null, "1969-12-06"]]}` | high | 이름 이력 없음; r_senri_line 1925-10-15~ongoing |
| MOVED 歌敷山→霞ヶ丘(山陽) | stop_dates.json | `{"r_sanyo_main_line_sanyo\|n_kasumigaoka_sanyo": ["1917-04-12", null]}` | medium | r_sanyo_main_line_sanyo 1964-06-01~ongoing |
| MOVED 歌敷山 이름 | renames_hand.json | `{"n_kasumigaoka_sanyo": [["歌敷山", null, "1964-06-01"]]}` | medium | 이름 이력 없음 |
| MOVED 毛矢町→足羽山公園口 이름 | renames_hand.json | `{"n_asuwayamakoenguchi": [["毛矢町", null, "1962-04-01"], ["公園口", "1962-04-01", "2016-03-27"]]}` | high | 이름 이력 없음; r_fukubu_line 1933-10-15~ongoing |
| MOVED 市荒川→越前竹原 이름 | renames_hand.json | `{"n_echizen_takehara": [["市荒川", null, "1955-09-01"]]}` | high | 이름 이력 없음; r_katsuyama_eiheiji_line 1914-02-11~ongoing |
| MOVED 宮地嶽→宮地岳 | 메모 | `—` | high | r_miyajidake_line 1925-07-01~2007-04-01 |
| UNSURE 神森(湯の山線) | 메모 | `—` | low |  |
| UNSURE 宿野(湯の山線) | 메모 | `—` | low |  |
| UNSURE 堀木(湯の山線) | 메모 | `—` | medium |  |
| UNSURE 製絨所前(湯の山線) | 메모 | `—` | medium |  |
| UNSURE 小生(湯の山線) | 메모 | `—` | medium |  |
| UNSURE 東日野(八王子線) | 메모 | `—` | medium |  |
| UNSURE 九王(予讃線) | 메모 | `—` | medium |  |
## 결정이 필요한 것

1. **信号場 시기의 여객 취급**: 鷲ノ巣는 1944-09-01(信号場 때부터 여객)로 제안했다. 小幌·東山처럼 정차 시작을 信号場 개설일로 둘지, 仮乗降場 시작(1949-08-01)으로 둘지 정책을 하나로 정해야 한다.
2. **한 정차 한 구간 제약**: 原生花園(1978~1987 공백), 十府ヶ浦(1986~ 臨時駅와 2017~ 상설역), 鮎喰(1934~1941 옛 역)은 구간이 둘이다. 지금 구조로는 하나만 고를 수 있다.
3. **행사·계절 臨時駅 8곳 넣기**(フォトデッキ, 緑化フェア梅小路, 浜中海水浴場, 世界焱博, 一ノ堰六地蔵尊, フイハップ浜, 静内海水浴場, 東声問, 白浜海岸): wiki_insert 행을 만들어 두었다. 넣을지는 미해결 질문 6의 판단이다. km를 모르는 3곳은 추정 km가 된다.
4. **현행 臨時駅 5곳**(仁愛グランド前, 津島ノ宮, ラベンダー畑, 田井ノ浜, 岡山 京橋): wiki_insert는 폐지역 전용이라 맞지 않는다. 별도 경로가 필요하다.
5. **구조상 못 넣는 것**: 小松島港·船着場(종점 뒤), 大加島(옛 선로 없음), 万国博中央口·ナゴヤ球場正門前·福岡ボート前·秋田博前(노선이 DB에 없음).
6. **鹿島サッカースタジアム**: 1978~1994 「名目上の旅客扱い」(열차 통과) 시기를 뺄지.
7. **wiki_insert로 넣은 역의 날짜**: 神路·常紋·東塩尻 등은 빌드 뒤 생긴 노드 ID로 stop_dates(정확한 날짜)와 stop_status 행을 더 써야 한다. 노드 ID는 빌드 전에 알 수 없어 행을 미리 못 적었다.

## 미해결

- 今川(羽越本線): 仮乗降場·臨時駅 시작일 불명. 1944-07-01(信号場 신설)을 하한값으로만 제안(low).
- 競輪場入口(広電宇品線): 폐지 2002-08-31은 확인, 개업일 불명(DB 1935-12-27은 노선 개업일). 작업 중인 hiroden_2025 source_patch와 겹치는지 확인.
- 桂川(函館本線)·名寄高校·東追分·恩根: 仮乗降場 시작 불명.
- 美野: 폐지 「1958年以降」 불명. DB 끝 1958-XX-XX를 그대로 씀.
- 湯の山線 神森·宿野: 역 문서 「1952年：休止」라 1950~1952 영업 가능성. 넣는다면 close 1952. 堀木·製絨所前·小生·東日野·九王은 근거 부족으로 넣지 않음.
- 旗ヶ岡→旗の台: 이름 이력을 池上線에만 거는 수단이 renames_hand에 없음(보류).
