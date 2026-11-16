# 같은 이름 허브 쌍 판정 (samename audit 3)

대상: samename_candidates.json 128쌍 + 나머지 599쌍 훑기에서 찾은 2쌍(표 끝, `extra`). 출처는 일본어 위키백과 문서 제목과 oldid(revid).

## 판정 수

| 판정 | 수 | 뜻 | 할 일 |
|---|---|---|---|
| TRANSFER | 28 | 실제 환승역·같은 역 구역(연결 통로, 문서의 乗換 표기, 역 앞 정류장) | 유지 |
| SEPARATE | 27 | 이름만 같은 다른 역(다른 자리, 공식 환승 없음) | 허브에서 가름, same_group이면 묶음도 가름 |
| RELOCATED | 37 | 같은 역의 옛·새 자리(이전) | 허브에서 가름(둘 다 제3의 역과 환승이면 허브 유지 가능), moved.json 짝 확인 |
| SUCCESSOR | 34 | 시기가 겹치지 않는 다른 노선의 역이 거의 같은 자리(대략 300 m 이내)에 이어짐 | 환승은 생기지 않음(시기 안 겹침). 허브 유지 무해, 가르려면 가름 |
| PHANTOM | 1 | 원천 오독으로 생긴 가짜 노드 | 노드·정차 삭제 |
| UNSURE | 3 | 자료 부족 | 추가 조사 |

판정 기준: 시기가 겹치는 쌍만 지도에서 환승으로 그려지고 환승 링크가 생김(compile.py `linked()`는 같은 묶음이면 무조건 환승으로 봄). 시기가 겹치지 않는 쌍은 자리가 300 m 넘게 다르면 SEPARATE, 가까우면 SUCCESSOR로 둠.

## 가를 것 (SEPARATE · PHANTOM)

- **社尺別** `n_sha_shakubetsu` / `n_sha_shakubetsu_nemuro_main` (hub_sha_shakubetsu, 3183 m, PHANTOM) — 根室本線 문서 노선도에 尺別鉄道 분기 쪽 社尺別가 그려진 것을 根室本線 정차역으로 잘못 읽은 가짜 노드. 社尺別은 尺別鉄道 역으로 国鉄 尺別駅과 연락(社尺別駅 105383923, 根室本線 110395326)
- **松島** `n_matsushima` / `n_matsushima_tohoku_main` (hub_matsushima, 2384 m, SEPARATE) — 초대 松島(山線)는 1962-07-01 폐지, 같은 날 海線의 新松島(1956~)가 2대 松島로 개칭. 1956~1962엔 松島·新松島로 따로 있었고 약 2.4 km 떨어짐(松島駅 111576541). moved.json에 넣으면 新松島 시절(1956~1962) 정차가 지워지므로 허브·묶음만 가름
- **木屋瀬** `n_koyanose` / `n_koyanose_chikuho` (hub_koyanose, 1008 m, SEPARATE) — 筑豊鉱業鉄道(鞍手軽便鉄道) 木屋瀬(1915~1950, 香月–野面)와 筑豊電気鉄道 木屋瀬(1958~)는 다른 노선의 다른 역, 약 1 km(筑豊鉄道 (2代) 96175349)
- **根室** `n_nemuro` / `n_nemuro_nemuro_takushoku` (hub_nemuro, 1004 m, SEPARATE) — 根室拓殖鉄道 根室駅은 国鉄 根室駅과 별지점(有磯町, 직선 800 m 정도)(根室拓殖鉄道 107467623, 根室駅 111218959)
- **川原石** `n_kawaraishi` / `n_kawaraishi_kure_city_transportation_bureau` (hub_kawaraishi, 977 m, SEPARATE) — 呉市電 川原石 停留所는 海岸一丁目 교차점 부근 종점, 呉線 川原石駅과 연락 기술 없음(呉市電 105517988). JR 역은 1999년 海岸二丁目→三丁目로 500 m 移転(川原石駅 110541475)
- **石屋川** `n_ishiyagawa` / `n_ishiyagawa_ishiyagawa` (hub_ishiyagawa, 809 m, SEPARATE) — 神戸市電石屋川線 石屋川 停留場은 阪神 石屋川駅과 別の場所(約900m, 灘区 vs 東灘区)(神戸市電石屋川線 107416152)
- **守口** `n_moriguchi` / `n_moriguchi_osaka_metro` (hub_moriguchi, 691 m, SEPARATE) — 大阪市電 都島守口線 守口 停留所(~1969)와 谷町線 守口(1977~)는 시기·자리가 다름. 守口駅 문서가 市電 停留所를 별개로 안내(守口駅 109789216, 大阪市電都島守口線 90280167)
- **野田** `n_noda` / `n_noda_hanshin` (hub_ebie, 607 m, SEPARATE) — JR 野田와 阪神 野田는 約500m離れており、乗り換え駅ではない(野田駅 (JR西日本) 109478458, 野田駅 (阪神) 111513004)
- **小本** `n_komoto` / `n_komoto_nagoya_rinkai_rapid_transit` (hub_komoto, 575 m, SEPARATE) — 名古屋市電 下之一色線 小本電停(~1969)은 西名古屋港線 평면교차 앞의 정류장, あおなみ線 小本(2004~)과 시기 겹치지 않고 DB상 575 m(名古屋市電下之一色線 105378136)
- **芦屋川** `n_ashiyagawa` / `n_ashiyagawa_kokudo` (hub_ashiyagawa, 564 m, SEPARATE) — 阪神国道線 芦屋川(국도2호 위)과 阪急 芦屋川는 다른 곳. 国道線은 本線과도 연락이 나빴다고 기술(阪神国道線 110799720, 芦屋川駅 110396671)
- **緑町** `n_midoricho` / `n_midoricho_odawarashinai` (hub_midoricho, 482 m, SEPARATE) — 箱根登山 小田原市内線 緑町(小田原駅前 0.3 km, 緑一丁目)과 大雄山線 緑町는 다른 곳(箱根登山鉄道小田原市内線 110985582, 緑町駅 109769741)
- **尾頭橋** `n_otobashi` / `n_otobashi_shimoegawa` (hub_furuwataribashi, 453 m, SEPARATE) — 名古屋市電 尾頭橋 停留場은 堀川의 尾頭橋(駅の南東) 부근 江川線 위, JR 尾頭橋(1995~)와 시기 겹치지 않음(尾頭橋駅 111165813)
- **馬車道** `n_bashamichi` / `n_bashamichi_hommoku` (hub_bashamichi, 442 m, SEPARATE) — みなとみらい線 馬車道駅 자리는 横浜市電 本町四丁目 停留所 쪽이고, 市電 馬車道 停留所는 다른 곳(横浜市電 108362204)
- **玉出** `n_tamade_nankai` / `n_tamade_osaka_metro` (hub_higashitamade, 403 m, SEPARATE) — 地下鉄 玉出는 「他線への乗り換えのない駅」, 南海 岸里玉出(옛 玉出) 玉出口까지 650 m(玉出駅 109154768, 岸里玉出駅 111041283)
- **北府** `n_kitago_fukui_fukubu` / `n_kitago_fukui_nan_etsu` (hub_kitago_fukui_fukubu, 396 m, SEPARATE) — 南越線 北府(きたごう)는 福武線 北府(きたご)와 別の駅, 読み・所在地も異なる. 南越線 시절 福武線 역은 西武生(北府駅 (南越線) 101435847, 北府駅 111543420)
- **茂住** `n_mozumi` / `n_mozumi_mitsui_mining_and_smelting` (hub_mozumi, 346 m, SEPARATE) — 神岡軌道 茂住는 国鉄 神岡線과 川を挟んだ対岸에 있었고 1962 여객 폐지, 神岡線 茂住(1966~)와 다른 자리(神岡軌道 110986155, 茂住駅 110034086)
- **上伊田** `n_kami_ita` / `n_kamiita` (hub_kami_ita, 332 m, SEPARATE) — 国鉄 添田線 上伊田와 平成筑豊 上伊田는 場所は異なる, 移転したものではない(약 400 m)(上伊田駅 108423508)
- **朝倉** `n_asakura` / `n_asakura_tosaden_kotsu` (hub_asakura, 279 m, SEPARATE) — 이 노드는 とさでん 伊野線 「朝倉」 停留場(乗換 없음)이고 JR 朝倉駅 앞 정류장은 이웃 「朝倉駅前」(n_asakura_ekimae)(朝倉停留場 111312194, 朝倉駅 (高知県) 111312178)
- **寺田町** `n_teradacho` / `n_teradacho_osaka_municipal_transportation_bureau` (hub_gengahashi, 241 m, SEPARATE) — 百済線 寺田町(0.0 km, 시내선 교차점)과 별도로 0.3 km에 城東線과 접속하는 「寺田町駅前」이 있었음(大阪市電百済線 111563981)
- **亀山** `n_kameyama_bantan` / `n_kameyama_sanyo` (hub_kameyama_bantan, 230 m, SEPARATE) — 山陽 亀山는 1991년까지 亀山御坊·電鉄亀山이라는 다른 이름, 国鉄 亀山(~1986)는 北方300m(亀山駅 (兵庫県) 109360888)
- **築地** `n_tsukiji` / `n_tsukiji_kachidokibashi` (hub_shintomicho, 224 m, SEPARATE) — 都電 築地 電停은 현재의 東銀座駅 위치에 있었음 — 日比谷線 築地와 다른 곳(東京都電車 110874184)
- **伊野** `n_ino_dosan` / `n_ino_tosaden_kotsu` (hub_ino_dosan, 187 m, SEPARATE) — 이 노드는 とさでん 「伊野」 停留場(종점, 乗換 없음)이고 JR 伊野駅 앞은 이웃 「伊野駅前」(伊野停留場 101769960, 伊野駅 111422386)
- **稲永町** `n_inaeicho` / `n_inaeicho_tsukiji_line_nagoya_city` (hub_inaeicho, 167 m, SEPARATE) — 稲永町(I, 2.5 km, ~1956)과 稲永町(II, 2.7 km)는 같은 築地線의 이웃 정류장. II는 1956-09-15까지 「西稲永」, 그날 I 폐지·II 개칭(名古屋市電築地線 92163572)
- **長町** `n_nagamachi_sendai_city` / `n_nagamachi_sennan` (hub_nagamachi, 0 m, SEPARATE) — 秋保電気鉄道 長町는 東北本線 長町駅과 떨어진 旧長町宿 남단(既存の2つの長町駅が離れていた). 南北線 長町는 JR 長町 쪽(長町駅 110859024)
- **坂越** `n_sakoshi` / `n_sakoshi_ako` (hub_sakoshi, 0 m, SEPARATE) — 赤穂鉄道 坂越(9.4 km)는 赤穂線 坂越와 다른 자리(노선도상 赤穂線 교차 전), 시기 안 겹침(赤穂鉄道 109282965)
- **播州赤穂** `n_banshu_ako` / `n_banshu_ako_ako` (hub_banshu_ako, 0 m, SEPARATE) — 赤穂鉄道 播州赤穂駅은 赤穂線の播州赤穂駅とは別駅(赤穂鉄道 109282965)
- **大多羅** `n_odara` / `n_odara_ryobi` (hub_odara, 0 m, SEPARATE) — 西大寺鉄道 大多羅는 JR駅から西に約400m離れた位置(大多羅駅 111649481, 西大寺鉄道 109417111)
- **西分** `n_nishibun` / `n_nishibun_aki` (hub_nishibun, 0 m, SEPARATE) — ごめん・なはり線 西分는 安芸線 西分 跡에서 800m西側(西分駅 (土佐電気鉄道) 111331595)

## 이전 (RELOCATED) — moved.json에 없는 짝

- `{"old": "n_higashi_aoyama_osaka", "new": "n_higashi_aoyama", "date": "1975-11-23"}` — 1975-11-23 新青山トンネル 새 선으로 東に2.7km 移転(東青山駅 111440026)
- `{"old": "n_tadachi_chuo_main", "new": "n_tadachi", "date": "1973-05-25"}` — 1973-05-25 複線化로 旧位置より1.5km坂下寄りへ移転(田立駅 110192418)
- `{"old": "n_ikazaki_uchiko", "new": "n_ikazaki", "date": "1986-03-03"}` — 1986-03-03 予讃線新線 개업 때 約1.6km西の現在地へ移転(五十崎駅 110657141)
- `{"old": "n_nishi_aoyama_osaka", "new": "n_nishi_aoyama", "date": "1975-11-23"}` — 1975-11-23 新青山トンネル 새 선으로 西に1.1km移転(西青山駅 109687422)
- `{"old": "n_yahata_kagoshima_main", "new": "n_yahata", "date": "1955-08-01"}` — 1955-08-01 約1km西側へ移転(八幡駅 (福岡県) 110919454)
- `{"old": "n_tosa_ananai_dosan", "new": "n_tosa_ananai", "date": "1954-03-30"}` — 1954-03-30 和田トンネル 새 선으로 移転(土佐穴内駅 110668654)
- `{"old": "n_oarai_suihin_old", "new": "n_oarai_suihin", "date": "1954-01-22"}` — 1954-01-22 大洗駅が旧駅の南側に移転(茨城交通水浜線 109665329)
- `{"old": "n_nishihino_hachioji", "new": "n_nishihino", "date": "1976-04-01"}` — 1976-04-01 日永–西日野 복구 때 当駅は0.1キロ日永方に移設(西日野駅 109414905). 후보 128개 밖
- `{"old": "n_uchiko_uchiko", "new": "n_uchiko", "date": "1986-03-03"}` — 1986-03-03 予讃線新線 개업과 함께 旧駅から南西の現在地に移転(内子駅 110902744). 후보 128개 밖

이미 moved.json에 있는 RELOCATED: 28쌍 (표 참조).

## 좌표·이름 문제

- 社尺別 `n_sha_shakubetsu`/`n_sha_shakubetsu_nemuro_main`: n_sha_shakubetsu_nemuro_main은 根室本線 route에서 빼야 함. 진짜 환승 짝은 国鉄 尺別(n_shakubetsu)–社尺別(n_sha_shakubetsu)
- 東青山 `n_higashi_aoyama`/`n_higashi_aoyama_osaka`: 새 노드 정차가 1930부터로 되어 있음(1975-11-23부터가 맞음)
- 松島 `n_matsushima`/`n_matsushima_tohoku_main`: n_matsushima에 1956-07-09~1962-07-01 옛 이름 「新松島」이 없음
- 田立 `n_tadachi`/`n_tadachi_chuo_main`: 옛 노드 정차가 1948부터(1909부터가 맞음), 새 노드 정차가 1909/1948부터로 되어 있음
- 五十崎 `n_ikazaki`/`n_ikazaki_uchiko`: 새 노드 정차가 1920부터로 되어 있음
- 八幡 `n_yahata`/`n_yahata_kagoshima_main`: 옛 노드 끝이 1955-XX-XX로만 되어 있음
- 川原石 `n_kawaraishi`/`n_kawaraishi_kure_city_transportation_bureau`: DB의 JR 川原石 좌표는 1999년 移転 뒤 위치뿐(1935~1999 옛 위치 노드 없음)
- 土佐穴内 `n_tosa_ananai`/`n_tosa_ananai_dosan`: 새 노드 정차가 1934부터로 되어 있음
- 守口 `n_moriguchi`/`n_moriguchi_osaka_metro`: DB 거리 691 m(市電 쪽 n05 근사)
- 杉田 `n_sugita_keikyu`/`n_sugita_sugita`: 市電 쪽 좌표 n05 근사
- 南千住 `n_minami_senju`/`n_minami_senju_senju`: 都電 쪽 좌표(n05)가 390 m 남쪽 — 営業所 자리로 고칠 필요
- 南千住 `n_minami_senju_senju`/`n_minami_senju_tokyo_metro`: 都電 쪽 좌표 n05 근사
- 北府 `n_kitago_fukui_fukubu`/`n_kitago_fukui_nan_etsu`: 福武線 n_kitago_fukui_fukubu에 1924~2010 옛 이름 「西武生」이 없음
- 朝倉 `n_asakura`/`n_asakura_tosaden_kotsu`: JR 朝倉 허브에는 이름이 다른 n_asakura_ekimae가 들어가야 함
- 井土ヶ谷 `n_idogaya`/`n_idogaya_idogaya`: 市電 쪽 좌표 n05 근사(279 m)
- 磯子 `n_isogo`/`n_isogo_sugita`: 市電 쪽 좌표 n05 근사
- 穴内 `n_ananai`/`n_ananai_aki`: DB 254 m, 같은 자리 여부 문서에 없음
- 寺田町 `n_teradacho`/`n_teradacho_osaka_municipal_transportation_bureau`: JR 寺田町 허브에는 n_teradacho_ekimae가 맞음
- 亀山 `n_kameyama_bantan`/`n_kameyama_sanyo`: n_kameyama_sanyo에 옛 이름(亀山御坊 1923~1944, 電鉄亀山 1944~1991)이 없음
- 築地 `n_tsukiji`/`n_tsukiji_kachidokibashi`: 都電 築地 좌표(n05)를 東銀座 쪽으로 고칠 필요
- 伊野 `n_ino_dosan`/`n_ino_tosaden_kotsu`: JR 伊野 허브에는 n_ino_ekimae가 맞음
- 稲永町 `n_inaeicho`/`n_inaeicho_tsukiji_line_nagoya_city`: n_inaeicho_tsukiji_line_nagoya_city에 1925~1956 옛 이름 「西稲永」이 없음
- 大洗 `n_oarai_suihin`/`n_oarai_suihin_old`: 새 노드 정차가 1926부터로 되어 있음
- 上野幌 `n_kami_nopporo`/`n_kami_nopporo_chitose`: 옛 노드 좌표가 새 역 좌표를 그대로 복사함(0 m) — 옛 위치로 고쳐야 함
- 大船 `n_ofuna_dream`/`n_ofuna_shonan_monorail`: 두 노드 좌표가 같음(복사) — ドリーム交通 大船는 JR 북측 栄区 쪽
- 長町 `n_nagamachi_sendai_city`/`n_nagamachi_sennan`: 秋保 長町 좌표가 지하철 長町 좌표 복사(0 m) — 옛 위치로 고쳐야 함
- 新潟 `n_niigata`/`n_niigata_old`: 옛 노드 좌표가 새 역 좌표를 그대로 복사함(0 m) — 옛 위치로 고쳐야 함
- 竪堀 `n_tatebori`/`n_tatebori_minobu`: 옛 노드 좌표가 새 역 좌표를 그대로 복사함(0 m) — 옛 위치로 고쳐야 함
- 佐久間 `n_sakuma`/`n_sakuma_iida`: 옛 노드 좌표가 새 역 좌표를 그대로 복사함(0 m) — 옛 위치로 고쳐야 함
- 武田尾 `n_takedao`/`n_takedao_fukuchiyama`: 옛 노드 좌표가 새 역 좌표를 그대로 복사함(0 m) — 옛 위치로 고쳐야 함
- 坂越 `n_sakoshi`/`n_sakoshi_ako`: 赤穂鉄道 坂越 좌표가 JR 좌표 복사(0 m)
- 播州赤穂 `n_banshu_ako`/`n_banshu_ako_ako`: 赤穂鉄道 播州赤穂 좌표가 JR 좌표 복사(0 m)
- 大多羅 `n_odara`/`n_odara_ryobi`: 西大寺鉄道 大多羅 좌표가 JR 좌표 복사(0 m)
- 日羽 `n_hiwa`/`n_hiwa_hakubi`: 옛 노드 좌표가 새 역 좌표를 그대로 복사함(0 m) — 옛 위치로 고쳐야 함
- 三滝 `n_mitaki`/`n_mitaki_kabe`: 옛 노드 좌표가 새 역 좌표를 그대로 복사함(0 m) — 옛 위치로 고쳐야 함
- 宇多津 `n_utazu`/`n_utazu_yosan`: 옛 노드 좌표가 새 역 좌표를 그대로 복사함(0 m) — 옛 위치로 고쳐야 함
- 土佐北川 `n_tosa_kitagawa`/`n_tosa_kitagawa_dosan`: 옛 노드 좌표가 새 역 좌표를 그대로 복사함(0 m) — 옛 위치로 고쳐야 함
- 江戸川橋 `n_edogawabashi`/`n_edogawabashi_edogawa`: 두 노드 좌표 같음(복사)
- 桜田門 `n_sakuradamon`/`n_sakuradamon_hanzomon_line_toei`: 두 노드 좌표 같음(복사)
- 半蔵門 `n_hanzomon`/`n_hanzomon_bancho_line_toei`: 두 노드 좌표 같음(복사)
- 天神 `n_tenjin`/`n_tenjin_loop_line_nishitetsu`: 두 노드 좌표 같음(복사)
- 八乙女 `n_yaotome`/`n_yaotome_sendai`: 仙台鉄道 八乙女 좌표가 지하철 좌표 복사(0 m) — 38.31411,140.88611로
- 北加賀屋 `n_kitakagaya`/`n_kitakagaya_osaka_municipal_transportation_bureau`: 두 노드 좌표 같음(복사)
- 恵美須町 `n_ebisucho`/`n_ebisucho_osaka_metro`: 두 노드 좌표 같음(복사)
- 西分 `n_nishibun`/`n_nishibun_aki`: 安芸線 西分 좌표가 새 역 좌표 복사(0 m) — 33.51831,133.79803로
- 糠平 `n_nukabira`/`n_nukabira_shihoro`: 옛 노드 좌표가 새 역 좌표를 그대로 복사함(0 m) — 옛 위치로 고쳐야 함
- 荒子 `n_arako`/`n_arako_shimonoishiki`: 두 노드 좌표 같음(복사)
- 嶺 `n_mine_shimizushinai`/`n_mine_shimizushinai_line_nishikubo_sodeshi_old_route`: 옛 노드 좌표가 새 역 좌표를 그대로 복사함(0 m) — 옛 위치로 고쳐야 함(n05)
- 鈴木島 `n_suzukijima`/`n_suzukijima_shimizushinai_line_nishikubo_sodeshi_old_route`: 옛 노드 좌표가 새 역 좌표를 그대로 복사함(0 m) — 옛 위치로 고쳐야 함(n05)
- 草牟田 `n_somuta`/`n_somuta_ishiki_line_shinshoin_ishiki_old_route`: 옛 노드 좌표가 새 역 좌표를 그대로 복사함(0 m) — 옛 위치로 고쳐야 함(n05)
- 中草牟田 `n_nakasomuta`/`n_nakasomuta_ishiki_line_shinshoin_ishiki_old_route`: 옛 노드 좌표가 새 역 좌표를 그대로 복사함(0 m) — 옛 위치로 고쳐야 함(n05)
- 西日野 `n_nishihino`/`n_nishihino_hachioji`: 새 노드 정차가 1912부터로 되어 있음
- 内子 `n_uchiko`/`n_uchiko_uchiko`: 옛 노드 좌표가 새 역 좌표를 그대로 복사함(0 m) — 옛 위치로 고쳐야 함. 새 노드 内子線 정차가 1920부터로 되어 있음

## 구현 메모

- `data/overrides/hub_not.json`은 이름 쌍(frozenset)으로 거르므로 이름이 같은 두 노드를 가를 수 없음. 노드 단위로 허브·묶음을 가르는 보정이 필요.
- moved.json은 컴파일 때 새 노드의 묶음을 옛 노드 묶음으로 합침 — RELOCATED 쌍은 같은 묶음으로 남음(시기가 이전일에서 갈리므로 환승은 생기지 않음).
- 松島(1956~1962 新松島)처럼 옛 이름 기간이 있는 새 노드는 moved.json에 넣으면 그 기간 정차가 지워지므로 넣지 않음.

## 전체 표

| # | 이름 | A 노선 | B 노선 | 거리 m | 묶음 | 판정 | 확신 | 근거 |
|---|---|---|---|---|---|---|---|---|
| 0 | 社尺別<br>`n_sha_shakubetsu`<br>`n_sha_shakubetsu_nemuro_main` | 尺別鉄道線 1962~1970 | 根室本線 1942~1970 | 3183 | 같음 | PHANTOM | high | 根室本線 문서 노선도에 尺別鉄道 분기 쪽 社尺別가 그려진 것을 根室本線 정차역으로 잘못 읽은 가짜 노드. 社尺別은 尺別鉄道 역으로 国鉄 尺別駅과 연락(社尺別駅 105383923, 根室本線 110395326) |
| 1 | 東青山<br>`n_higashi_aoyama`<br>`n_higashi_aoyama_osaka` | 大阪線 1930~1975<br>大阪線 1930~ | 大阪線 1930~1975 | 2772 | 같음 | RELOCATED | high | 1975-11-23 新青山トンネル 새 선으로 東に2.7km 移転(東青山駅 111440026) |
| 2 | 松島<br>`n_matsushima`<br>`n_matsushima_tohoku_main` | 東北本線 1956~<br>東北本線 2015~ | 東北本線 1890~1962 | 2384 | 같음 | SEPARATE | high | 초대 松島(山線)는 1962-07-01 폐지, 같은 날 海線의 新松島(1956~)가 2대 松島로 개칭. 1956~1962엔 松島·新松島로 따로 있었고 약 2.4 km 떨어짐(松島駅 111576541). moved.json에 넣으면 新松島 시절(1956~1962) 정차가 지워지므로 허브·묶음만 가름 |
| 3 | 名立 / 名立（旧）<br>`n_nadachi`<br>`n_nadachi_hokuriku_main` | 北陸本線 1969~2015<br>日本海ひすいライン 2015~ | 北陸本線 1911~1969 | 1500 | 같음 | RELOCATED | high | 1969-09-29 北陸本線 복선 신선으로 移転(名立駅 108804869) |
| 4 | 田立<br>`n_tadachi`<br>`n_tadachi_chuo_main` | 中央本線 1909~1973<br>中央本線 1948~ | 中央本線 1948~1973 | 1484 | 같음 | RELOCATED | high | 1973-05-25 複線化로 旧位置より1.5km坂下寄りへ移転(田立駅 110192418) |
| 5 | 野内 / 野内（旧）<br>`n_nonai_aoimori_aoimori_railway`<br>`n_nonai_aoimori_aoimori_railway_old` | 青い森鉄道線 2011~ | 東北本線 1891~1968<br>東北本線 1891~2010<br>青い森鉄道線 2010~2011 | 1376 | 같음 | RELOCATED | high | 2011-03-12 青森寄りに1.6km移転(野内駅 109620273) |
| 6 | 五十崎<br>`n_ikazaki`<br>`n_ikazaki_uchiko` | 内子線 1920~ | 内子線 1920~1986 | 1373 | 같음 | RELOCATED | high | 1986-03-03 予讃線新線 개업 때 約1.6km西の現在地へ移転(五十崎駅 110657141) |
| 7 | 西青山<br>`n_nishi_aoyama`<br>`n_nishi_aoyama_osaka` | 大阪線 1930~1975<br>大阪線 1930~ | 大阪線 1930~1975 | 1315 | 같음 | RELOCATED | high | 1975-11-23 新青山トンネル 새 선으로 西に1.1km移転(西青山駅 109687422) |
| 8 | 筒石 / 筒石（旧）<br>`n_tsutsuishi`<br>`n_tsutsuishi_hokuriku_main` | 北陸本線 1969~2015<br>日本海ひすいライン 2015~ | 北陸本線 1912~1969 | 1303 | 같음 | RELOCATED | high | 1969-09-29 頸城トンネル 안 새 역으로 移転(筒石駅 110726053) |
| 9 | 八幡<br>`n_yahata`<br>`n_yahata_kagoshima_main` | 鹿児島本線 1902~1999<br>鹿児島本線 1902~ | 鹿児島本線 1902~1955 | 1050 | 같음 | RELOCATED | high | 1955-08-01 約1km西側へ移転(八幡駅 (福岡県) 110919454) |
| 10 | 楓 / 楓（旧）<br>`n_kaede`<br>`n_kaede_old` | 石勝線 1981~2004 | 夕張線登川支線 1907~1981 | 1032 | 같음 | RELOCATED | high | 1981 石勝線 개업으로 약 1 km 移転(楓駅 111421778, 1967년에도 한 번 移転) |
| 11 | 木屋瀬<br>`n_koyanose`<br>`n_koyanose_chikuho` | 筑豊電気鉄道 1958~ | 筑豊鉱業鉄道線 1915~1950 | 1008 | 같음 | SEPARATE | medium | 筑豊鉱業鉄道(鞍手軽便鉄道) 木屋瀬(1915~1950, 香月–野面)와 筑豊電気鉄道 木屋瀬(1958~)는 다른 노선의 다른 역, 약 1 km(筑豊鉄道 (2代) 96175349) |
| 12 | 根室<br>`n_nemuro`<br>`n_nemuro_nemuro_takushoku` | 根室本線 1921~ | 根室拓殖鉄道線 1929~1959 | 1004 | 같음 | SEPARATE | high | 根室拓殖鉄道 根室駅은 国鉄 根室駅과 별지점(有磯町, 직선 800 m 정도)(根室拓殖鉄道 107467623, 根室駅 111218959) |
| 13 | 川原石<br>`n_kawaraishi`<br>`n_kawaraishi_kure_city_transportation_bureau` | 呉線 1935~ | 市内線 1910~1967 | 977 | 같음 | SEPARATE | medium | 呉市電 川原石 停留所는 海岸一丁目 교차점 부근 종점, 呉線 川原石駅과 연락 기술 없음(呉市電 105517988). JR 역은 1999년 海岸二丁目→三丁目로 500 m 移転(川原石駅 110541475) |
| 14 | 三河知立 / 三河知立（旧）<br>`n_mikawa_chiryu_meitetsu_mikawa`<br>`n_mikawa_chiryu_meitetsu_mikawa_old` | 三河線 2024~ | 三河線 1920~2024 | 949 | 같음 | RELOCATED | high | 2024-03-16 約900m移転(三河知立駅 111029893) |
| 15 | 土佐穴内<br>`n_tosa_ananai`<br>`n_tosa_ananai_dosan` | 土讃線 1934~1954<br>土讃線 1934~ | 土讃線 1934~1954 | 895 | 같음 | RELOCATED | high | 1954-03-30 和田トンネル 새 선으로 移転(土佐穴内駅 110668654) |
| 16 | 織笠（旧） / 織笠<br>`n_orikasa`<br>`n_orikasa_sanriku` | 山田線 1936~2019 | リアス線 2019~ | 839 | 같음 | RELOCATED | high | 2019-03-23 三陸鉄道 전환 때 旧駅から1km北側へ移転(織笠駅 108744289) |
| 17 | 和賀仙人 / 和賀仙人（旧）<br>`n_waka_sennin`<br>`n_waka_sennin_kitakami` | 北上線 1962~ | 北上線 1921~1962 | 829 | 같음 | RELOCATED | high | 1962-12-01 湯田ダム로 루트 변경, 移転(和賀仙人駅 105772281) |
| 18 | 大貞公園 / 大貞公園（旧）<br>`n_osadakoen_oita_transportation_yabakei`<br>`n_osadakoen_oita_transportation_yabakei_old` | 耶馬渓線 1944~1975 | 耶馬渓線 1913~1944 | 820 | 같음 | RELOCATED | high | 1944-03-01 770 m上ノ原寄りに移転(大貞公園駅 111056418) |
| 19 | 石屋川<br>`n_ishiyagawa`<br>`n_ishiyagawa_ishiyagawa` | 本線 1905~ | 石屋川線 1953~1969 | 809 | 같음 | SEPARATE | high | 神戸市電石屋川線 石屋川 停留場은 阪神 石屋川駅과 別の場所(約900m, 灘区 vs 東灘区)(神戸市電石屋川線 107416152) |
| 20 | 守口<br>`n_moriguchi`<br>`n_moriguchi_osaka_metro` | 都島守口線 1931~1969 | 谷町線 1977~ | 691 | 같음 | SEPARATE | low | 大阪市電 都島守口線 守口 停留所(~1969)와 谷町線 守口(1977~)는 시기·자리가 다름. 守口駅 문서가 市電 停留所를 별개로 안내(守口駅 109789216, 大阪市電都島守口線 90280167) |
| 21 | 能生 / 能生（旧）<br>`n_no`<br>`n_no_hokuriku_main` | 北陸本線 1969~2015<br>日本海ひすいライン 2015~ | 北陸本線 1912~1969 | 635 | 같음 | RELOCATED | high | 1969-09-29 新線으로 移転, 旧駅跡은 文化体育館(能生駅 109443757) |
| 22 | 野田<br>`n_noda`<br>`n_noda_hanshin` | 大阪環状線 1898~ | 国道線 1927~1975<br>本線 1905~ | 607 | 같음 | SEPARATE | high | JR 野田와 阪神 野田는 約500m離れており、乗り換え駅ではない(野田駅 (JR西日本) 109478458, 野田駅 (阪神) 111513004) |
| 23 | 杉田<br>`n_sugita_keikyu`<br>`n_sugita_sugita` | 本線 1930~ | 杉田線 1927~1967 | 576 | 같음 | UNSURE | low | 横浜市電 杉田線 종점 杉田(~1967)는 지명 杉田에 링크될 뿐 京急 杉田駅과의 위치 관계 기술 없음(横浜市电 108362204). 停留所 위치 자료 필요 |
| 24 | 小本<br>`n_komoto`<br>`n_komoto_nagoya_rinkai_rapid_transit` | 下之一色線 1913~1969 | 西名古屋港線 2004~ | 575 | 같음 | SEPARATE | low | 名古屋市電 下之一色線 小本電停(~1969)은 西名古屋港線 평면교차 앞의 정류장, あおなみ線 小本(2004~)과 시기 겹치지 않고 DB상 575 m(名古屋市電下之一色線 105378136) |
| 25 | 芦屋川<br>`n_ashiyagawa`<br>`n_ashiyagawa_kokudo` | 神戸本線 1920~ | 国道線 1927~1974 | 564 | 같음 | SEPARATE | medium | 阪神国道線 芦屋川(국도2호 위)과 阪急 芦屋川는 다른 곳. 国道線은 本線과도 연락이 나빴다고 기술(阪神国道線 110799720, 芦屋川駅 110396671) |
| 26 | 北森 / 北森（旧）<br>`n_kitamori_hanawa`<br>`n_kitamori_hanawa_old` | 花輪線 2015~ | 花輪線 1961~2015 | 508 | 같음 | RELOCATED | high | 2015 平館寄り500m 移転(北森駅 108435583) |
| 27 | 緑町<br>`n_midoricho`<br>`n_midoricho_odawarashinai` | 大雄山線 1935~ | 小田原市内線 1920~1956 | 482 | 같음 | SEPARATE | medium | 箱根登山 小田原市内線 緑町(小田原駅前 0.3 km, 緑一丁目)과 大雄山線 緑町는 다른 곳(箱根登山鉄道小田原市内線 110985582, 緑町駅 109769741) |
| 28 | 大阪梅田<br>`n_osaka_umeda_hankyu`<br>`n_osaka_umeda_hanshin` | 宝塚本線 1910~<br>神戸本線 1926~ | 本線 1906~ | 461 | 같음 | TRANSFER | high | 서로 乗換 표기(大阪梅田駅 (阪急) 110973806, 大阪梅田駅 (阪神) 110987597) |
| 29 | 尾頭橋<br>`n_otobashi`<br>`n_otobashi_shimoegawa` | 東海道本線 1995~ | 下之一色線 1913~1969<br>下江川線 1912~1971 | 453 | 같음 | SEPARATE | low | 名古屋市電 尾頭橋 停留場은 堀川의 尾頭橋(駅の南東) 부근 江川線 위, JR 尾頭橋(1995~)와 시기 겹치지 않음(尾頭橋駅 111165813) |
| 30 | 馬車道<br>`n_bashamichi`<br>`n_bashamichi_hommoku` | みなとみらい21線 2004~ | 本牧線 1905~1970 | 442 | 같음 | SEPARATE | medium | みなとみらい線 馬車道駅 자리는 横浜市電 本町四丁目 停留所 쪽이고, 市電 馬車道 停留所는 다른 곳(横浜市電 108362204) |
| 31 | 京橋<br>`n_kyobashi`<br>`n_kyobashi_osaka_metro` | JR東西線 1997~<br>大阪環状線 1895~<br>片町線 1895~ | 長堀鶴見緑地線 1990~ | 431 | 같음 | TRANSFER | high | 京橋 JR·京阪·地下鉄 3社 乗り換え(改札外)(京橋駅 (大阪府) 111392924) |
| 32 | 京橋<br>`n_kyobashi_keihan`<br>`n_kyobashi_osaka_metro` | 京阪本線 1910~ | 長堀鶴見緑地線 1990~ | 431 | 같음 | TRANSFER | high | 京橋 京阪–地下鉄 乗り換え(京橋駅 (大阪府) 111392924) |
| 33 | 玉出<br>`n_tamade_nankai`<br>`n_tamade_osaka_metro` | 南海本線 1885~1993 | 四つ橋線 1958~ | 403 | 같음 | SEPARATE | high | 地下鉄 玉出는 「他線への乗り換えのない駅」, 南海 岸里玉出(옛 玉出) 玉出口까지 650 m(玉出駅 109154768, 岸里玉出駅 111041283) |
| 34 | 南千住<br>`n_minami_senju`<br>`n_minami_senju_senju` | 常磐線 1896~ | 千住線 1910~1971 | 396 | 같음 | TRANSFER | medium | 都電 22系統 南千住 종점은 南千住電車営業所(현 都営バス南千住営業所, 日比谷線 역 남동쪽)에 있었음(南千住駅 111072980, 東京都電車 110874184) |
| 35 | 南千住<br>`n_minami_senju_senju`<br>`n_minami_senju_tokyo_metro` | 千住線 1910~1971 | 日比谷線 1961~ | 396 | 같음 | TRANSFER | medium | 위와 같음. 日比谷線 역 남동쪽 営業所 자리(南千住駅 111072980) |
| 36 | 南千住<br>`n_minami_senju_senju`<br>`n_minami_senju_tsukuba_express` | 千住線 1910~1971 | つくばエクスプレス線 2005~ | 396 | 같음 | SUCCESSOR | medium | 都電 南千住(~1971)와 TX 南千住(2005~)는 시기 안 겹침, 같은 南千住 역 구역(南千住駅 111072980) |
| 37 | 北府<br>`n_kitago_fukui_fukubu`<br>`n_kitago_fukui_nan_etsu` | 福武線 1924~ | 南越線 1927~1981 | 396 | 같음 | SEPARATE | high | 南越線 北府(きたごう)는 福武線 北府(きたご)와 別の駅, 読み・所在地も異なる. 南越線 시절 福武線 역은 西武生(北府駅 (南越線) 101435847, 北府駅 111543420) |
| 38 | 新大阪<br>`n_shin_osaka`<br>`n_shin_osaka_osaka_metro` | おおさか東線 2019~<br>山陽新幹線 1972~<br>東海道新幹線 1964~<br>東海道本線 1964~<br>梅田貨物線 1988~ | 御堂筋線 1964~ | 395 | 같음 | TRANSFER | high | 2階に地下鉄への連絡通路(新大阪駅 111452806) |
| 39 | 両国<br>`n_ryogoku`<br>`n_ryogoku_toei` | 総武本線 1904~ | 大江戸線 2000~ | 390 | 같음 | TRANSFER | high | 総武線–大江戸線 接続駅(출구 300 m 남짓)(両国駅 111504371) |
| 40 | 六地蔵<br>`n_rokujizo`<br>`n_rokujizo_keihan` | 奈良線 1992~ | 宇治線 1913~ | 377 | 같음 | TRANSFER | high | JR·地下鉄 六地蔵와 京阪 六地蔵 서로 乗換 표기, 徒歩5分 約400m(六地蔵駅 (JR西日本・京都市営地下鉄) 111628839, 六地蔵駅 (京阪) 111625271) |
| 41 | 六地蔵<br>`n_rokujizo_keihan`<br>`n_rokujizo_kyoto_city` | 宇治線 1913~ | 東西線 2004~ | 377 | 같음 | TRANSFER | high | 위와 같음(六地蔵駅 (京阪) 111625271) |
| 42 | 大手町<br>`n_otemachi_toei`<br>`n_otemachi_tokyo_metro` | 三田線 1972~ | 丸ノ内線 1956~<br>千代田線 1969~<br>半蔵門線 1989~<br>東西線 1966~ | 354 | 같음 | TRANSFER | high | 三田線–メトロ 각 선 乗り換え(大手町駅 (東京都) 111289713) |
| 43 | 茂住<br>`n_mozumi`<br>`n_mozumi_mitsui_mining_and_smelting` | 神岡線 1966~1984<br>神岡線 1984~2006 | 神岡鉄道線 1949~1962 | 346 | 같음 | SEPARATE | medium | 神岡軌道 茂住는 国鉄 神岡線과 川を挟んだ対岸에 있었고 1962 여객 폐지, 神岡線 茂住(1966~)와 다른 자리(神岡軌道 110986155, 茂住駅 110034086) |
| 44 | 上伊田<br>`n_kami_ita`<br>`n_kamiita` | 添田線 1915~1985 | 田川線 2001~ | 332 | 같음 | SEPARATE | high | 国鉄 添田線 上伊田와 平成筑豊 上伊田는 場所は異なる, 移転したものではない(약 400 m)(上伊田駅 108423508) |
| 45 | 木幡<br>`n_kohata`<br>`n_kowata` | 奈良線 1896~ | 宇治線 1913~ | 279 | 같음 | TRANSFER | high | JR 木幡(こはた)–京阪 木幡(こわた) 서로 乗換 표기, 徒歩5分(木幡駅 (JR西日本) 109478733, 木幡駅 (京阪) 111625295) |
| 46 | 朝倉<br>`n_asakura`<br>`n_asakura_tosaden_kotsu` | 土讃線 1924~ | 伊野線 1925~ | 279 | 같음 | SEPARATE | high | 이 노드는 とさでん 伊野線 「朝倉」 停留場(乗換 없음)이고 JR 朝倉駅 앞 정류장은 이웃 「朝倉駅前」(n_asakura_ekimae)(朝倉停留場 111312194, 朝倉駅 (高知県) 111312178) |
| 47 | 井土ヶ谷<br>`n_idogaya`<br>`n_idogaya_idogaya` | 本線 1930~ | 井土ヶ谷線 1956~1968 | 279 | 같음 | TRANSFER | high | 横浜市電 井土ヶ谷線의 「井土ヶ谷駅前停留場」이 역 앞에 隣接(1956~1968)(井土ヶ谷駅 108855432) |
| 48 | 神戸三宮<br>`n_kobe_sannomiya_hankyu`<br>`n_kobe_sannomiya_hanshin` | 神戸本線 1936~<br>神戸高速線 1968~ | 本線 1933~ | 277 | 같음 | TRANSFER | high | 서로 乗換 표기(神戸三宮駅 (阪急) 110412714, 神戸三宮駅 (阪神) 111184674) |
| 49 | 下天津<br>`n_shimo_amazu`<br>`n_shimoamazu` | 宮福線 1988~ | 北丹鉄道 1923~1971 | 277 | 같음 | SUCCESSOR | medium | 北丹鉄道 下天津(~1971)와 宮福線 下天津(1988~), 시기 안 겹침, 문서 좌표상 약 280 m(下天津駅 (北丹鉄道) 101144638) |
| 50 | 磯子<br>`n_isogo`<br>`n_isogo_sugita` | 根岸線 1964~ | 杉田線 1925~1967 | 275 | 같음 | UNSURE | low | 横浜市電 杉田線 磯子 停留所(~1967)와 根岸線 磯子(1964~)의 위치 관계 기술 없음(横浜市電 108362204는 磯子駅에 링크만). 1964~1967 겹침 |
| 51 | 松森<br>`n_matsumori_meitetsu`<br>`n_matsumori_nagaragawa` | 美濃町線 1911~1999 | 越美南線 1999~ | 266 | 같음 | SUCCESSOR | medium | 長良川鉄道 松森는 1999-03-31 폐지된 名鉄 美濃町線 松森의 代替駅(1999-04-01), 약 270 m(松森駅 106148786) |
| 52 | 穴内<br>`n_ananai`<br>`n_ananai_aki` | 阿佐線 2002~ | 安芸線 1930~1974 | 254 | 같음 | SUCCESSOR | low | 安芸線 跡을 쓴 ごめん・なはり線에 同名駅, 安芸線 穴内(~1974)와 시기 안 겹침(穴内駅 111318229, 土佐電気鉄道安芸線 111330992) |
| 53 | 寺田町<br>`n_teradacho`<br>`n_teradacho_osaka_municipal_transportation_bureau` | 大阪環状線 1932~ | 百済線 1949~1968 | 241 | 같음 | SEPARATE | high | 百済線 寺田町(0.0 km, 시내선 교차점)과 별도로 0.3 km에 城東線과 접속하는 「寺田町駅前」이 있었음(大阪市電百済線 111563981) |
| 54 | 亀山<br>`n_kameyama_bantan`<br>`n_kameyama_sanyo` | 播但線 1897~1986 | 本線 1923~ | 230 | 같음 | SEPARATE | high | 山陽 亀山는 1991년까지 亀山御坊·電鉄亀山이라는 다른 이름, 国鉄 亀山(~1986)는 北方300m(亀山駅 (兵庫県) 109360888) |
| 55 | 築地<br>`n_tsukiji`<br>`n_tsukiji_kachidokibashi` | 日比谷線 1963~ | 勝鬨橋線 1944~1968<br>築地線 1904~1971 | 224 | 같음 | SEPARATE | medium | 都電 築地 電停은 현재의 東銀座駅 위치에 있었음 — 日比谷線 築地와 다른 곳(東京都電車 110874184) |
| 56 | 小島新田 / 小島新田（旧）<br>`n_kojimashinden`<br>`n_kojimashinden_daishi` | 大師線 1964~ | 大師線 1944~1964 | 211 | 같음 | RELOCATED | high | 1964-03-25 京急大師線 小島新田 移転(小島新田駅 108741953) |
| 57 | 片町<br>`n_katamachi`<br>`n_katamachi_keihan_main` | 天満橋善源寺町線 1924~1968 | 京阪本線 1910~1969 | 209 | 같음 | TRANSFER | medium | 大阪市電 天満橋善源寺町線 片町 停留場은 片町駅(JR·京阪) 근처, 京阪과 평면교차(片町駅 108219744, 大阪市電天満橋善源寺町線 90739768) |
| 58 | 金沢八景 / 金沢八景（旧）<br>`n_kanazawa_hakkei_keikyu`<br>`n_kanazawa_hakkei_yokohama_seaside_line_kanazawa_seaside_old` | 本線 1930~<br>逗子線 1930~ | 金沢シーサイド線 1989~2019 | 207 | 같음 | TRANSFER | high | シーサイドライン 仮駅舎(1989~2019) 시절에도 京急 金沢八景와 환승역(金沢八景駅 111620343) |
| 59 | 金沢八景 / 金沢八景（旧）<br>`n_kanazawa_hakkei_yokohama_seaside_line_kanazawa_seaside`<br>`n_kanazawa_hakkei_yokohama_seaside_line_kanazawa_seaside_old` | 金沢シーサイド線 2019~ | 金沢シーサイド線 1989~2019 | 207 | 같음 | RELOCATED | high | 2019-03-31 仮駅舎から本駅舎に移転(金沢八景駅 111620343). 둘 다 京急 金沢八景와 환승이므로 허브 자체는 유지해도 됨 |
| 60 | 仙台<br>`n_sendai_sendai_city`<br>`n_sendai_senseki` | 南北線 1987~<br>東西線 2015~ | 仙山線 1929~<br>仙石線 1925~<br>東北新幹線 1982~<br>東北本線 1887~ | 195 | 같음 | TRANSFER | high | JR–地下鉄 乗り換え 西口地下歩道(仙台駅 111369685) |
| 61 | 安曇川<br>`n_adogawa`<br>`n_adogawa_kojaku` | 湖西線 1974~ | 江若鉄道線 1929~1969 | 194 | 같음 | SUCCESSOR | medium | 江若 安曇川(~1969)와 湖西線 安曇川(1974~), 문서 좌표상 약 170~250 m, 시기 안 겹침(安曇川駅 (江若鉄道) 106827826, 江若鉄道 110542243) |
| 62 | 近江舞子<br>`n_omi_maiko`<br>`n_omimaiko` | 湖西線 1974~ | 江若鉄道線 1926~1969 | 193 | 같음 | SUCCESSOR | medium | 江若 近江舞子와 湖西線 近江舞子, 약 150~210 m, 시기 안 겹침(近江舞子駅 (江若鉄道) 108866651) |
| 63 | 伊野<br>`n_ino_dosan`<br>`n_ino_tosaden_kotsu` | 土讃線 1924~ | 伊野線 1907~ | 187 | 같음 | SEPARATE | high | 이 노드는 とさでん 「伊野」 停留場(종점, 乗換 없음)이고 JR 伊野駅 앞은 이웃 「伊野駅前」(伊野停留場 101769960, 伊野駅 111422386) |
| 64 | 桜本<br>`n_sakuramoto`<br>`n_sakuramoto_kawasaki_city_transportation_bureau` | 大師線 1945~1951 | 川崎市電 1945~1969 | 177 | 같음 | TRANSFER | high | 京急大師線과 川崎市電의 接続駅, ホームが隣り合う(桜本駅 111029882) |
| 65 | 新橋 / 新橋（旧）<br>`n_shimbashi`<br>`n_shimbashi_yurikamome_old` | 東海道本線 1909~ | 東京臨海新交通臨海線 1995~2001 | 167 | 같음 | TRANSFER | high | ゆりかもめ 新橋 仮設駅(1995~2001)도 新橋 환승역(新橋駅 111582115) |
| 66 | 新橋 / 新橋（旧）<br>`n_shimbashi_toei`<br>`n_shimbashi_yurikamome_old` | 浅草線 1963~ | 東京臨海新交通臨海線 1995~2001 | 167 | 같음 | TRANSFER | high | 위와 같음(新橋駅 111582115) |
| 67 | 新橋 / 新橋（旧）<br>`n_shimbashi_tokyo_metro`<br>`n_shimbashi_yurikamome_old` | 銀座線 1934~ | 東京臨海新交通臨海線 1995~2001 | 167 | 같음 | TRANSFER | high | 위와 같음(新橋駅 111582115) |
| 68 | 新橋 / 新橋（旧）<br>`n_shimbashi_yurikamome`<br>`n_shimbashi_yurikamome_old` | 東京臨海新交通臨海線 2001~ | 東京臨海新交通臨海線 1995~2001 | 167 | 같음 | RELOCATED | high | 2001-03-22 仮設駅より少し西へ移動(新橋駅 111582115). 둘 다 JR·지하철 新橋와 환승이므로 허브는 유지해도 됨 |
| 69 | 稲永町<br>`n_inaeicho`<br>`n_inaeicho_tsukiji_line_nagoya_city` | 築地線 1917~1956 | 築地線 1925~1971<br>築地線支線 1956~1971 | 167 | 같음 | SEPARATE | medium | 稲永町(I, 2.5 km, ~1956)과 稲永町(II, 2.7 km)는 같은 築地線의 이웃 정류장. II는 1956-09-15까지 「西稲永」, 그날 I 폐지·II 개칭(名古屋市電築地線 92163572) |
| 70 | 長野<br>`n_nagano`<br>`n_nagano_nagano` | 信越本線 1888~<br>北しなの線 2015~<br>北陸新幹線 1997~ | 長野線 1928~ | 166 | 같음 | TRANSFER | high | 長野電鉄 長野는 改札外の連絡通路로 JR와 乗り換え(長野駅 111656404) |
| 71 | 小牧原<br>`n_komakihara_meitetsu`<br>`n_komakihara_tokadai_new_transit` | 小牧線 1931~ | 桃花台線 1991~2006 | 159 | 같음 | TRANSFER | high | 桃花台線 小牧原 乗換=名鉄小牧線(小牧原駅 108756446) |
| 72 | 和邇<br>`n_wani`<br>`n_wani_kojaku` | 湖西線 1974~ | 江若鉄道線 1924~1969 | 147 | 같음 | SUCCESSOR | medium | 江若 和邇와 湖西線 和邇, 약 150 m, 시기 안 겹침(和邇駅 (江若鉄道) 103501429) |
| 73 | 新富町<br>`n_shintomicho`<br>`n_shintomicho_tokyo_metro` | 築地線 1904~1971 | 有楽町線 1980~ | 146 | 같음 | SUCCESSOR | low | 都電 新富町(~1971)와 有楽町線 新富町(1980~), 146 m, 시기 안 겹침(新富町駅 110911705) |
| 74 | 羽田空港第3ターミナル<br>`n_haneda_airport_terminal_3_keikyu`<br>`n_haneda_airport_terminal_3_tokyo_monorail` | 空港線 2010~ | 東京モノレール羽田空港線 2010~ | 122 | 같음 | TRANSFER | high | 京急–東京モノレール 같은 터미널 환승(羽田空港第3ターミナル駅 110707548) |
| 75 | 公庄<br>`n_gujo_hokutan`<br>`n_gujo_kyoto_tango_railway_willer_trains` | 北丹鉄道 1923~1971 | 宮福線 1988~ | 112 | 같음 | SUCCESSOR | medium | 北丹 公庄와 宮福線 公庄, 약 110 m, 시기 안 겹침(公庄駅 (北丹鉄道) 101145303) |
| 76 | 大洗<br>`n_oarai_suihin`<br>`n_oarai_suihin_old` | 水浜線 1926~1966 | 水浜線 1926~1954 | 111 | 같음 | RELOCATED | high | 1954-01-22 大洗駅が旧駅の南側に移転(茨城交通水浜線 109665329) |
| 77 | 北小松<br>`n_kita_komatsu`<br>`n_kitakomatu` | 湖西線 1974~ | 江若鉄道線 1927~1969 | 102 | 같음 | SUCCESSOR | medium | 江若 北小松와 湖西線 北小松, 약 70~90 m, 시기 안 겹침(北小松駅 (江若鉄道) 103501483) |
| 78 | 甲浦 / 甲浦（旧）<br>`n_kannoura_asa_seaside_asato`<br>`n_kannoura_asa_seaside_asato_old` | 阿佐東線 2021~ | 阿佐東線 1992~2021 | 55 | 같음 | RELOCATED | high | 2021-12-25 阿佐東線 0.1 km 연장, 甲浦 이전(甲浦信号場 107021034) |
| 79 | 入江崎<br>`n_iriezaki`<br>`n_iriezaki_kawasaki_city_transportation_bureau` | 大師線 1944~1951 | 川崎市電 1951~1964 | 1 | 같음 | SUCCESSOR | high | 京急大師線 入江崎(1944~)를 1952 川崎市電에 譲渡, 같은 역(入江崎駅 111030203) |
| 80 | 上野幌 / 上野幌（旧）<br>`n_kami_nopporo`<br>`n_kami_nopporo_chitose` | 千歳線 1973~ | 千歳線 1926~1973 | 0 | 같음 | RELOCATED | high | 1973 千歳線 이설, 旧駅は北西約1km(上野幌駅 111090560) |
| 81 | 大船<br>`n_ofuna_dream`<br>`n_ofuna_shonan_monorail` | ドリームランド線 1966~1967 | 江の島線 1970~ | 0 | 같음 | TRANSFER | medium | ドリーム交通 大船(1966~1967, 栄区側)과 湘南モノレール 大船(1970~)는 서로 시기 안 겹치지만 각각 JR 大船와 환승 — 허브 유지(大船駅 111579622, ドリーム開発ドリームランド線 109710235) |
| 82 | 長町<br>`n_nagamachi_sendai_city`<br>`n_nagamachi_sennan` | 南北線 1987~ | 秋保線 1914~1961 | 0 | 같음 | SEPARATE | high | 秋保電気鉄道 長町는 東北本線 長町駅과 떨어진 旧長町宿 남단(既存の2つの長町駅が離れていた). 南北線 長町는 JR 長町 쪽(長町駅 110859024) |
| 83 | 新潟 / 新潟（旧）<br>`n_niigata`<br>`n_niigata_old` | 上越新幹線 1982~<br>信越本線 1958~<br>白新線 1958~<br>越後線 1958~ | 信越本線 1904~1958 | 0 | 같음 | RELOCATED | high | 1958-04-29 新潟駅 移転(新潟駅 111526782) |
| 84 | 竪堀 / 竪堀（旧）<br>`n_tatebori`<br>`n_tatebori_minobu` | 身延線 1969~ | 身延線 1926~1969 | 0 | 같음 | RELOCATED | high | 1969-09-28 身延線 고가 신선으로 移転(竪堀駅 110308739) |
| 85 | 佐久間 / 佐久間（旧）<br>`n_sakuma`<br>`n_sakuma_iida` | 飯田線 1955~ | 飯田線 1936~1955 | 0 | 같음 | RELOCATED | high | 1955-11-11 佐久間 – 大嵐 経路変更に伴い移転(佐久間駅 110660067) |
| 86 | 比良<br>`n_hira`<br>`n_hira_kojaku` | 湖西線 1974~ | 江若鉄道線 1926~1969 | 0 | 같음 | SUCCESSOR | high | 江若 比良와 湖西線 比良, 약 20~40 m, 시기 안 겹침(比良駅 (江若鉄道) 103501465) |
| 87 | 武田尾 / 武田尾（旧）<br>`n_takedao`<br>`n_takedao_fukuchiyama` | 福知山線 1986~ | 福知山線 1899~1986 | 0 | 같음 | RELOCATED | high | 1986-08-01 生瀬–道場 新線으로 現在地に移転(武田尾駅 111202374) |
| 88 | 福知山<br>`n_fukuchiyama_hokutan`<br>`n_fukuchiyama_kyoto_tango_railway_willer_trains` | 北丹鉄道 1923~1971 | 宮福線 1988~ | 0 | 같음 | SUCCESSOR | high | 北丹鉄道 福知山은 福知山駅 구내(高架化前のホーム 자리), 宮福線 福知山도 같은 역 — 각각 JR와 환승, 허브 유지(福知山駅 111369748) |
| 89 | 坂越<br>`n_sakoshi`<br>`n_sakoshi_ako` | 赤穂線 1951~ | 赤穂鉄道線 1921~1951 | 0 | 같음 | SEPARATE | medium | 赤穂鉄道 坂越(9.4 km)는 赤穂線 坂越와 다른 자리(노선도상 赤穂線 교차 전), 시기 안 겹침(赤穂鉄道 109282965) |
| 90 | 播州赤穂<br>`n_banshu_ako`<br>`n_banshu_ako_ako` | 赤穂線 1951~ | 赤穂鉄道線 1921~1951 | 0 | 같음 | SEPARATE | high | 赤穂鉄道 播州赤穂駅은 赤穂線の播州赤穂駅とは別駅(赤穂鉄道 109282965) |
| 91 | 大多羅<br>`n_odara`<br>`n_odara_ryobi` | 赤穂線 1962~ | 西大寺鉄道線 1911~1962 | 0 | 같음 | SEPARATE | high | 西大寺鉄道 大多羅는 JR駅から西に約400m離れた位置(大多羅駅 111649481, 西大寺鉄道 109417111) |
| 92 | 日羽 / 日羽（旧）<br>`n_hiwa`<br>`n_hiwa_hakubi` | 伯備線 1970~ | 伯備線 1956~1970 | 0 | 같음 | RELOCATED | high | 1970-09-07 複線化に伴い現在地に移転(日羽駅 111019291) |
| 93 | 三滝 / 三滝（旧）<br>`n_mitaki`<br>`n_mitaki_kabe` | 可部線 1962~ | 可部線 1930~1962 | 0 | 같음 | RELOCATED | high | 1962 可部線 太田川放水路 동안→이설(三滝駅 110225140) |
| 94 | 円町<br>`n_emmachi`<br>`n_emmachi_marutamachi` | 山陰本線 2000~ | 丸太町線 1928~1976 | 0 | 같음 | SUCCESSOR | medium | 京都市電 丸太町線 종점 円町(~1976, 山陰本線 위)와 JR 円町(2000~)는 円町交差点 같은 자리, 시기 안 겹침(京都市電丸太町線 107404759, 円町駅 110987995) |
| 95 | 宇多津 / 宇多津（旧）<br>`n_utazu`<br>`n_utazu_yosan` | 予讃線 1987~<br>本四備讃線 1988~ | 予讃線 1897~1987 | 0 | 같음 | RELOCATED | high | 1987 予讃線 坂出–丸亀 고가 이설(宇多津駅 110600002) |
| 96 | 土佐北川 / 土佐北川（旧）<br>`n_tosa_kitagawa`<br>`n_tosa_kitagawa_dosan` | 土讃線 1986~ | 土讃線 1960~1986 | 0 | 같음 | RELOCATED | high | 1986-03-03 土讃線 経路変更, 大王信号場と統合して移転(土佐北川駅 110799132) |
| 97 | 後免<br>`n_gomen_aki`<br>`n_gomen_tosa_kuroshio` | 安芸線 1926~1974 | 阿佐線 2002~ | 0 | 같음 | SUCCESSOR | high | 安芸線 後免와 ごめん・なはり線 後免는 둘 다 JR 後免駅에 접속, 시기 안 겹침 — 허브 유지(後免駅 111406739) |
| 98 | 田吉<br>`n_tayoshi`<br>`n_tayoshi_miyazaki` | 宮崎空港線 1996~<br>日南線 1996~ | 宮崎交通線 1913~1962 | 0 | 같음 | SUCCESSOR | low | 宮崎交通線 田吉(初代 ~1962)와 日南線 田吉(2대 1963~1971, 3대 1996~)는 한 문서에서 다룸, 같은 자리인지는 명시 없음(田吉駅 111585766) |
| 99 | 南方<br>`n_minamikata`<br>`n_minamikata_miyazaki` | 日南線 1963~ | 宮崎交通線 1913~1962 | 0 | 같음 | SUCCESSOR | medium | 宮崎交通線 跡を日南線が利用, 같은 문서의 같은 역(宮崎交通線 110279373, 南方駅 (宮崎県) 110421205) |
| 100 | 木花<br>`n_kibana`<br>`n_kibana_miyazaki` | 日南線 1963~ | 宮崎交通線 1913~1962 | 0 | 같음 | SUCCESSOR | medium | 위와 같음(宮崎交通線 110279373, 木花駅 110421224) |
| 101 | 曽山寺<br>`n_sosanji`<br>`n_sosanji_miyazaki` | 日南線 1963~ | 宮崎交通線 1913~1962 | 0 | 같음 | SUCCESSOR | medium | 위와 같음(宮崎交通線 110279373, 曽山寺駅 110421264) |
| 102 | 子供の国<br>`n_kodomonokuni`<br>`n_kodomonokuni_miyazaki` | 日南線 1963~ | 宮崎交通線 1913~1962 | 0 | 같음 | SUCCESSOR | medium | 위와 같음(宮崎交通線 110279373, 子供の国駅 111292162) |
| 103 | 青島<br>`n_aoshima`<br>`n_aoshima_miyazaki` | 日南線 1963~ | 宮崎交通線 1913~1962 | 0 | 같음 | SUCCESSOR | medium | 위와 같음(宮崎交通線 110279373, 青島駅 110421297) |
| 104 | 江戸川橋<br>`n_edogawabashi`<br>`n_edogawabashi_edogawa` | 有楽町線 1974~ | 江戸川線 1907~1968 | 0 | 같음 | SUCCESSOR | medium | 有楽町線 江戸川橋는 都電 停留場名をそのまま踏襲(江戸川橋駅 111043483), 시기 안 겹침 |
| 105 | 桜田門<br>`n_sakuradamon`<br>`n_sakuradamon_hanzomon_line_toei` | 有楽町線 1974~ | 半蔵門線 1903~1968 | 0 | 같음 | SUCCESSOR | low | 都電 桜田門(~1968)와 有楽町線 桜田門(1974~), 같은 桜田門 앞, 시기 안 겹침(東京都電車 110874184) |
| 106 | 半蔵門<br>`n_hanzomon`<br>`n_hanzomon_bancho_line_toei` | 半蔵門線 1982~ | 半蔵門線 1903~1968<br>番町線 1905~1963 | 0 | 같음 | SUCCESSOR | low | 都電 半蔵門(~1968)와 半蔵門線 半蔵門(1982~), 같은 半蔵門 앞, 시기 안 겹침(東京都電車 110874184) |
| 107 | 新開地<br>`n_shinkaichi`<br>`n_shinkaichi_hankyu` | 湊川線 1922~1968 | 神戸高速線 1968~ | 0 | 같음 | TRANSFER | medium | 神戸市電 湊川線 新開地 停留場은 新開地駅 문서로 이어짐(같은 곳). 湊川線 폐지 1968-04-21, 神戸高速 개업 1968-04-07로 2주 겹침(神戸市電湊川線 99345259) |
| 108 | 新開地<br>`n_shinkaichi`<br>`n_shinkaichi_hanshin` | 湊川線 1922~1968 | 神戸高速線 1968~ | 0 | 같음 | TRANSFER | medium | 위와 같음(神戸市電湊川線 99345259) |
| 109 | 新開地<br>`n_shinkaichi`<br>`n_shinkaichi_kobe` | 湊川線 1922~1968 | 神戸高速線 1968~ | 0 | 같음 | TRANSFER | medium | 위와 같음(神戸市電湊川線 99345259) |
| 110 | 新開地<br>`n_shinkaichi`<br>`n_shinkaichi_sanyo` | 湊川線 1922~1968 | 神戸高速線 1968~2010 | 0 | 같음 | TRANSFER | medium | 위와 같음(神戸市電湊川線 99345259) |
| 111 | 天神<br>`n_tenjin`<br>`n_tenjin_loop_line_nishitetsu` | 空港線 1981~ | 循環線 1911~1979 | 0 | 같음 | SUCCESSOR | low | 西鉄 福岡市内線 循環線 天神(~1979)와 空港線 天神(1981~), 天神 교차점, 시기 안 겹침(天神駅 111056898) |
| 112 | 澄川<br>`n_sumikawa`<br>`n_sumikawa_jozankei` | 南北線 1971~ | 定山渓鉄道線 1918~1969 | 0 | 같음 | SUCCESSOR | medium | 定山渓鉄道 澄川(~1969) 문서 좌표가 南北線 澄川와 같음(4 m), 시기 안 겹침(澄川駅 (定山渓鉄道) 110918909) |
| 113 | 八乙女<br>`n_yaotome`<br>`n_yaotome_sendai` | 南北線 1987~ | 仙台鉄道線 1922~1956 | 0 | 같음 | SUCCESSOR | medium | 仙台鉄道 八乙女(~1950)는 南北線 八乙女 近く, 문서 좌표상 약 230 m(八乙女駅 110860344) |
| 114 | 北加賀屋<br>`n_kitakagaya`<br>`n_kitakagaya_osaka_municipal_transportation_bureau` | 四つ橋線 1972~ | 阪堺線 1944~1968 | 0 | 같음 | SUCCESSOR | low | 大阪市電 阪堺線 北加賀屋(~1968)와 四つ橋線 北加賀屋(1972~), 시기 안 겹침. 같은 자리인지 문서에 명시 없음(大阪市電阪堺線 102558425) |
| 115 | 恵美須町<br>`n_ebisucho`<br>`n_ebisucho_osaka_metro` | 西道頓堀天王寺線 1909~1968 | 堺筋線 1969~ | 0 | 같음 | SUCCESSOR | low | 大阪市電 恵美須町(~1968)와 堺筋線 恵美須町(1969~), 恵美須町 교차점, 시기 안 겹침(恵美須町駅 109680796) |
| 116 | 立田<br>`n_tateda`<br>`n_tateda_aki` | 阿佐線 2002~ | 安芸線 1924~1974 | 0 | 같음 | SUCCESSOR | high | かつてはほぼ同地点に安芸線の駅(立田駅 111310572) |
| 117 | 夜須<br>`n_yasu_aki`<br>`n_yasu_tosa_kuroshio` | 安芸線 1924~1974 | 阿佐線 2002~ | 0 | 같음 | SUCCESSOR | high | かつてはほぼ同地点に安芸線の駅(夜須駅 111317524) |
| 118 | 西分<br>`n_nishibun`<br>`n_nishibun_aki` | 阿佐線 2002~ | 安芸線 1930~1974 | 0 | 같음 | SEPARATE | high | ごめん・なはり線 西分는 安芸線 西分 跡에서 800m西側(西分駅 (土佐電気鉄道) 111331595) |
| 119 | 和食<br>`n_wajiki`<br>`n_wajiki_aki` | 阿佐線 2002~ | 安芸線 1930~1974 | 0 | 같음 | SUCCESSOR | high | かつては同位置に安芸線の駅(和食駅 111317428) |
| 120 | 赤野<br>`n_akano`<br>`n_akano_aki` | 阿佐線 2002~ | 安芸線 1930~1974 | 0 | 같음 | SUCCESSOR | high | かつては同地点に安芸線の駅(赤野駅 111317501) |
| 121 | 糠平 / 糠平（旧）<br>`n_nukabira`<br>`n_nukabira_shihoro` | 士幌線 1955~1987 | 士幌線 1937~1955 | 0 | 같음 | RELOCATED | high | 1955-08-01 糠平ダム建設のため移転(糠平駅 109409276) |
| 122 | 荒子<br>`n_arako`<br>`n_arako_shimonoishiki` | 西名古屋港線 2004~ | 下之一色線 1913~1969 | 0 | 같음 | UNSURE | low | 名古屋市電 下之一色線 荒子電停(4.6 km, ~1969)과 あおなみ線 荒子(2004~)의 위치 관계 기술 없음(名古屋市電下之一色線 105378136). 시기 안 겹침 |
| 123 | 岡地<br>`n_okaji`<br>`n_okaji_okuyama` | 天竜浜名湖線 1987~ | 奥山線 1954~1964 | 0 | 같음 | SUCCESSOR | high | 遠州鉄道 奥山線 岡地 廃止後、その跡地付近に天浜線の駅(岡地駅 99800394), 문서 좌표 55 m |
| 124 | 嶺 / 嶺（旧）<br>`n_mine_shimizushinai`<br>`n_mine_shimizushinai_line_nishikubo_sodeshi_old_route` | 清水市内線 1951~1975 | 清水市内線 西久保–袖師 旧線 1929~1951 | 0 | 같음 | RELOCATED | medium | 1951-07-21 静岡鉄道 清水市内線 西久保–袖師 이설(静岡鉄道清水市内線 107659703, moved.json 기존 항목) |
| 125 | 鈴木島 / 鈴木島（旧）<br>`n_suzukijima`<br>`n_suzukijima_shimizushinai_line_nishikubo_sodeshi_old_route` | 清水市内線 1951~1975 | 清水市内線 西久保–袖師 旧線 1929~1951 | 0 | 같음 | RELOCATED | medium | 같은 이설(静岡鉄道清水市内線 107659703, moved.json 기존 항목) |
| 126 | 草牟田 / 草牟田（旧）<br>`n_somuta`<br>`n_somuta_ishiki_line_shinshoin_ishiki_old_route` | 伊敷線 1952~1985 | 伊敷線 新照院–伊敷 旧線 1918~1952 | 0 | 같음 | RELOCATED | medium | 1952-08-10 鹿児島市電 伊敷線 新線 이설(鹿児島市電伊敷線 108122176, moved.json 기존 항목) |
| 127 | 中草牟田 / 中草牟田（旧）<br>`n_nakasomuta`<br>`n_nakasomuta_ishiki_line_shinshoin_ishiki_old_route` | 伊敷線 1952~1985 | 伊敷線 新照院–伊敷 旧線 1920~1952 | 0 | 같음 | RELOCATED | medium | 같은 이설(鹿児島市電伊敷線 108122176, moved.json 기존 항목) |
| 128 | 西日野 (extra)<br>`n_nishihino`<br>`n_nishihino_hachioji` | 八王子線 1912~ | 八王子線 1912~1976 | 96 | 같음 | RELOCATED | high | 1976-04-01 日永–西日野 복구 때 当駅は0.1キロ日永方に移設(西日野駅 109414905). 후보 128개 밖 |
| 129 | 内子 (extra)<br>`n_uchiko`<br>`n_uchiko_uchiko` | 予讃線 1986~<br>内子線 1920~ | 内子線 1920~1986 | 0 | 같음 | RELOCATED | high | 1986-03-03 予讃線新線 개업과 함께 旧駅から南西の現在地に移転(内子駅 110902744). 후보 128개 밖 |
