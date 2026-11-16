import 'dart:io';

import 'package:noriori_core/noriori_core.dart';
import 'package:noriori_store/noriori_store.dart';
import 'package:test/test.dart';

/// 이관 구간 B안 2단계를 실제 판으로 본다 (DESIGN §8.0.1). 北陸本線의 敦賀 아래는 2024-03-16에 ハピラインふくい線으로 넘어갔다.
void main() {
  final master = File('../../build/master.sqlite');
  final skip = master.existsSync() ? null : '판이 없다';
  const route = 'r_hokuriku_main_line';

  late UserDb db;
  late PackReader reader;
  late Network network;

  setUpAll(() async {
    if (skip != null) return;
    db = UserDb(openDirect(File(':memory:')));
    await db.customStatement("ATTACH 'file:${master.absolute.path}?mode=ro&immutable=1' AS master");
    reader = PackReader(db);
    network = Network(await NetworkReader(db).read());
  });

  tearDownAll(() async {
    if (skip == null) await db.close();
  });

  /// 기록 화면과 같은 순서로 줄을 만든다.
  Future<List<SelectorRow>> rows(String? raw) async {
    final builder = SelectorBuilder(network);
    final date = raw == null ? null : DateSpan.parse(raw);
    return builder.fillHanded(
      route,
      builder.build(route, date, links: await reader.routeLinks(route, carryover: true)),
      date,
      links: {for (final other in builder.handRoutes(route)) other: await reader.routeLinks(other)},
    );
  }

  List<String> nodes(List<SelectorRow> rows, String from, String to) {
    final all = rows.map((row) => row.node).toList();
    return all.sublist(all.indexOf(from), all.indexOf(to) + 1);
  }

  test('2026-11-07에는 敦賀 아래 구간에 しきぶ가 이 노선의 km로 나온다', () async {
    final got = await rows('2026-11-07');
    expect(nodes(got, 'n_oshio_hapi_line_fukui', 'n_takefu'), ['n_oshio_hapi_line_fukui', 'n_shikibu', 'n_takefu']);
    final shikibu = got.singleWhere((row) => row.node == 'n_shikibu');
    expect(shikibu.selectable, isTrue);
    expect(shikibu.savedAs, 'l_hapi_line_fukui_line');
    expect(shikibu.kmCum, 79.2);
    expect(DisplayRules.bandOf(shikibu), ('l_hapi_line_fukui_line', '2024-03-16'));
    // 다른 이관 구간의 새 역도 나온다
    expect(got.map((row) => row.node), containsAll(['n_nishi_matto', 'n_takaoka_yabunami']));
  }, skip: skip);

  test('2020-05-01에는 しきぶ가 없다', () async {
    final got = await rows('2020-05-01');
    expect(got.map((row) => row.node), isNot(contains('n_shikibu')));
    // 2015년 이관분의 새 역(高岡やぶなみ, 2018 개업)은 그날도 나온다
    expect(got.map((row) => row.node), contains('n_takaoka_yabunami'));
  }, skip: skip);

  test('武生에는 지금 환승(福武線)이 현행으로, 1981년에 끝난 南越線이 폐선으로 나온다', () async {
    final takefu = (await rows('2026-11-07')).singleWhere((row) => row.node == 'n_takefu');
    final fukubu = takefu.links.singleWhere((link) => link.otherLineId == 'l_fukubu_line');
    expect(fukubu.validToHi, DateSpan.maxDate);
    expect(fukubu.kind, 'transfer');
    expect(takefu.goneLinks.map((link) => link.otherLineId), contains('l_nan_etsu_line'));
    expect(takefu.goneLinks.map((link) => link.otherLineId), isNot(contains('l_fukubu_line')));
  }, skip: skip);

  test('날짜를 모르면 しきぶ도 고를 수 있다', () async {
    final shikibu = (await rows(null)).singleWhere((row) => row.node == 'n_shikibu');
    expect(shikibu.selectable, isTrue);
    expect(shikibu.handedOnly, isTrue);
  }, skip: skip);
}
