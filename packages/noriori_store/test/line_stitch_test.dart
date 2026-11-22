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
    final s = LineStitcher(network, today: DateSpan.parse(today), screen: (r, d) => cache[(r, d == null ? null : d.lo)]);
    return s.stitch(lineId, network.routesOfLineMainFirst(lineId).first, date);
  }

  double? km(StitchedLine s, String node) => s.main.rows.firstWhere((r) => r.node == node).kmCum;
  bool has(StitchedLine s, String node) => s.main.rows.any((r) => r.node == node);

  test('室蘭本線: 志文–岩見沢 옛 선로는 칩 없이 그날의 길과 km만', () async {
    final y1965 = await stitch('l_muroran_main_line', '1965-06-01');
    expect(km(y1965, 'n_iwamizawa'), 209.3);
    expect(y1965.used, contains('r_muroran_main_line_shibun_iwamizawa'));
    final now = await stitch('l_muroran_main_line', today);
    expect(km(now, 'n_iwamizawa'), 211.0);
    expect(now.used, contains('r_muroran_main_line_shibun_iwamizawa'));
    expect(now.folds.where((f) => f.single).map((f) => f.rows.rows.single.node), contains('n_toyoizumi'));
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

  test('西鉄循環線: 고리를 닫고, 날짜 모름에서 폐지 구간의 접힌 줄은 함께 죽는다', () async {
    final y = await stitch('l_loop_line_nishitetsu', '1955-06-01');
    expect(y.main.rows.first.node, 'n_chidoribashi_kaizuka');
    expect(y.main.rows.last.node, 'n_chidoribashi_kaizuka');
    expect(y.main.rows.last.kmCum, 7.0);
    final u = await stitch('l_loop_line_nishitetsu', null);
    expect(u.folds, isNotEmpty);
    expect(u.folds.every((f) => f.dead), isTrue);
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
