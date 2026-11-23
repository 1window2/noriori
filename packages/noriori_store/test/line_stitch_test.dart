import 'dart:io';

import 'package:noriori_core/noriori_core.dart';
import 'package:noriori_store/noriori_store.dart';
import 'package:test/test.dart';

/// 같은 노선 이어 그리기(DESIGN §8.3)를 실제 빌드 DB로 검사한다. 값은 기준 구현 tools/dev/stitch_mock.py와 같아야 한다.
void main() {
  final master = File('../../build/master.sqlite');
  final namesDb = File('../../build/names.sqlite');
  late UserDb db;
  late Network network;
  late PackReader reader;
  const today = '2026-11-22';

  setUpAll(() async {
    db = UserDb(openDirect(File(':memory:')));
    await db.customStatement("ATTACH 'file:${master.absolute.path}?mode=ro&immutable=1' AS master");
    await db.customStatement("ATTACH 'file:${namesDb.absolute.path}?mode=ro&immutable=1' AS names");
    network = Network(await NetworkReader(db).read());
    reader = PackReader(db);
  });
  tearDownAll(() => db.close());

  Future<StitchedLine> stitch(String lineId, String? day) async {
    final date = day == null ? null : DateSpan.parse(day);
    final rules = DisplayRules(network, today: today);
    const options = DisplayOptions();
    final builder = SelectorBuilder(network);
    final cache = <(String, String?), RouteRows>{};
    final routes = LineStitcher.routesFor(network, lineId);
    for (final r in routes) {
      for (final d in {day, today, null}) {
        final ds = d == null ? null : DateSpan.parse(d);
        final rows = builder.fillHanded(r, builder.build(r, ds, links: await reader.routeLinks(r)), ds,
            links: {for (final o in builder.handRoutes(r)) o: await reader.routeLinks(o)});
        final visible = rules.visible(rows, options);
        cache[(r, d)] = RouteRows(
          routeId: r,
          rows: visible,
          openGaps: builder.openBetween(r, visible, ds),
          sectionGaps: builder.openBetween(r, visible, DateSpan.parse(today)),
          sectionEnds: builder.sectionEnds(r, visible, DateSpan.parse(today), date: ds),
        );
      }
    }
    final s = LineStitcher(network, today: DateSpan.parse(today), screen: (r, d) => cache[(r, d?.lo)]);
    return s.stitch(lineId, network.routesOfLineMainFirst(lineId).first, date);
  }

  double? km(StitchedLine s, String node) => s.main.rows.firstWhere((r) => r.node == node).kmCum;
  bool has(StitchedLine s, String node) => s.main.rows.any((r) => r.node == node);

  test('갈아 끼운 선형 fold의 기간은 그 선형 칸이 모두 생긴 해다 (운휴 뒤 새 선형 개업 포함)', () async {
    String per(StitchedLine s, String node) => s.folds.firstWhere((f) => f.rows.rows.any((r) => r.node == node)).period;
    // 옛 선형이 2011년에 끊기고 새 선형이 2016·2015년에 열렸다. 끊긴 해가 아니라 연 해다
    expect(per(await stitch('l_joban_line', '2011-03-01'), 'n_sakamoto_joban'), '2016~');
    expect(per(await stitch('l_senseki_line', '2011-03-01'), 'n_nobiru'), '2015~');
    // 선형은 1978년에 생겼다. 옛 선형 일부가 1968년에 먼저 닫혀도 1968이 아니다
    expect(per(await stitch('l_muroran_main_line', '1970-07-31'), 'n_sakimori'), '1978~');
    // 운휴했다 다시 연 선형은 처음 생긴 해(1928)가 아니라 다시 노선의 길이 된 해다
    expect(per(await stitch('l_kyoto_line', '1965-08-22'), 'n_kintetsu_tambabashi'), '1968~');
  });

  test('접힌 줄은 화면 순서이고 km는 붙는 역에서 잰다. 줄 km 원점은 그날 다니는 계통의 맨 위 기점이다', () async {
    // 그날의 길을 본선에 잇고 위로 접은 본선 구간(総武本線 1965 東京–錦糸町, 瀬戸線 1965 栄町·東大手)
    final sobu = await stitch('l_sobu_main_line', '1965-06-01');
    final up = sobu.folds.firstWhere((f) => f.rows.rows.any((r) => r.node == 'n_bakurocho'));
    expect(up.rows.rows.firstWhere((r) => r.node == 'n_bakurocho').kmCum, 1.8);
    final seto = await stitch('l_seto_line', '1965-06-01');
    final sf = seto.folds.firstWhere((f) => f.rows.rows.any((r) => r.node == 'n_higashiote'));
    expect(sf.rows.rows.map((r) => r.node), ['n_sakaemachi_meitetsu', 'n_higashiote']);
    expect(sf.rows.rows.last.kmCum, 2.1);
    // 줄 머리의 다른 계통 조각(尼崎港線, 塚口에서 잰 km)이 원점을 밀지 않는다
    expect(km(await stitch('l_fukuchiyama_line', '1965-06-01'), 'n_amagasaki'), 0.0);
  });

  test('室蘭本線: 志文–岩見沢 옛 선로는 칩 없이 그날의 길과 km만', () async {
    final y1965 = await stitch('l_muroran_main_line', '1965-06-01');
    expect(km(y1965, 'n_iwamizawa'), 209.3);
    // 추정 km 역(崎守町) 뒤의 옛 선형 역과 그 너머도 확실한 역에서 잴 수 있으면 「?」가 아니다
    expect(y1965.main.rows.firstWhere((r) => r.node == 'n_jinyamachi').kmEstimated, isFalse);
    expect(y1965.main.rows.firstWhere((r) => r.node == 'n_moto_wanishi').kmEstimated, isFalse);
    expect(y1965.main.rows.firstWhere((r) => r.node == 'n_iwamizawa').kmEstimated, isFalse);
    expect(y1965.used, contains('r_muroran_main_line_shibun_iwamizawa'));
    final now = await stitch('l_muroran_main_line', today);
    expect(km(now, 'n_iwamizawa'), 211.0);
    expect(now.used, contains('r_muroran_main_line_shibun_iwamizawa'));
    expect(now.folds.where((f) => f.single).map((f) => f.rows.rows.single.node), contains('n_toyoizumi'));
    // 추정 km 역(崎守町) 뒤라도 확실한 역에서 바로 잴 수 있으면 「?」가 번지지 않는다
    final sakimori = now.folds.firstWhere((f) => f.rows.rows.any((r) => r.node == 'n_jinyamachi'));
    final jinya = sakimori.rows.rows.firstWhere((r) => r.node == 'n_jinyamachi');
    expect(jinya.kmCum, 69.7);
    expect(jinya.kmEstimated, isFalse);
  });

  test('北陸本線 1955: 柳ヶ瀬 경유가 본선, 그날 영업거리', () async {
    final s = await stitch('l_hokuriku_main_line', '1955-06-01');
    expect(has(s, 'n_yanagase'), isTrue);
    expect(km(s, 'n_tsuruga'), 48.5);
    expect(km(s, 'n_imajo'), 74.9);
    final s60 = await stitch('l_hokuriku_main_line', '1960-06-01');
    expect(has(s60, 'n_yanagase'), isFalse);
    expect(km(s60, 'n_imajo'), 72.3);
  });

  test('鹿児島本線 오늘: 이관 띠 너머 川内~鹿児島까지 한 줄, 구간 기점부터', () async {
    final s = await stitch('l_kagoshima_main_line', today);
    expect(km(s, 'n_yatsushiro'), 232.3);
    expect(km(s, 'n_sendai_hisatsu_orange'), 0.0);
    expect(km(s, 'n_kagoshima'), 49.3);
    expect(s.lengthKm, closeTo(281.6, 0.05));
  });

  test('筑肥線 1955 한 줄, 오늘은 두 구간', () async {
    final y = await stitch('l_chikuhi_line', '1955-06-01');
    expect(km(y, 'n_hakata_old'), 0.0);
    expect(km(y, 'n_imari'), 86.0);
    final now = await stitch('l_chikuhi_line', today);
    expect(km(now, 'n_meinohama'), 0.0);
    expect(km(now, 'n_karatsu'), 42.6);
    expect(now.used, isNot(contains('r_chikuhi_line_yamamoto_imari')));
  });

  test('西鉄循環線: 고리를 닫고, 날짜 모름에서 폐지 구간의 접힌 줄은 흐리게 그리되 역은 폐지된 본선 역처럼 고를 수 있다', () async {
    final y = await stitch('l_loop_line_nishitetsu', '1955-06-01');
    expect(y.main.rows.first.node, 'n_chidoribashi_kaizuka');
    expect(y.main.rows.last.node, 'n_chidoribashi_kaizuka');
    expect(y.main.rows.last.kmCum, 7.0);
    final u = await stitch('l_loop_line_nishitetsu', null);
    expect(u.folds, isNotEmpty);
    expect(u.folds.every((f) => f.dead), isTrue);
    final closedMain = u.main.rows.firstWhere((r) => r.node == 'n_gionmachi').selectable;
    expect(u.folds.expand((f) => f.rows.rows).every((r) => r.selectable == closedMain), isTrue);
  });

  test('中央本線 1955: 辰野 경유가 그날의 본선 (날짜별)', () async {
    final y = await stitch('l_chuo_main_line', '1955-06-01');
    expect(has(y, 'n_tatsuno_chuo_main'), isTrue);
    expect(has(y, 'n_midoriko'), isFalse);
    final now = await stitch('l_chuo_main_line', today);
    expect(has(now, 'n_midoriko'), isTrue);
    expect(has(now, 'n_tatsuno_chuo_main'), isFalse);
  });

}
