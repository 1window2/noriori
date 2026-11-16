import 'dart:io';

import 'package:noriori_core/noriori_core.dart';
import 'package:noriori_store/noriori_store.dart';
import 'package:test/test.dart';

/// 승계 켬일 때만 3섹 화면에 국철 시대 폐역과 구선로가 보인다 (DESIGN §2.9 E). 고를 수 있는지는 날짜가 정한다.
void main() {
  final master = File('../../build/master.sqlite');
  final skip = master.existsSync() ? null : '판이 없다';

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

  test('会津鉄道 화면의 国鉄 구선로(舟子·桑原)는 승계 켬에만 붙는다', () async {
    const old = 'r_aizu_line_ashinomaki_onsen_yunokami_onsen';
    final off = await reader.routeLinks('r_aizu_line_aizu');
    final on = await reader.routeLinks('r_aizu_line_aizu', carryover: true);
    expect(off.map((link) => link.otherRouteId), isNot(contains(old)));
    expect(on.map((link) => link.otherRouteId), contains(old));
    // 이관 전에 끝난 선로라 오늘은 없던 연결이다
    final rows = SelectorBuilder(network).build('r_aizu_line_aizu', DateSpan.parse('2026-11-01'), links: on);
    expect(rows.expand((row) => row.links).map((link) => link.otherRouteId), isNot(contains(old)));
    expect(rows.expand((row) => row.goneLinks).map((link) => link.otherRouteId), contains(old));
  }, skip: skip);

  test('三陸 リアス線의 織笠(국철·JR 시대 역)은 승계 켬에만 정차역이고 그 시기 날짜에만 고른다', () async {
    final stops = await reader.carryoverStops('r_rias_line');
    final builder = SelectorBuilder(network);
    final offRows = builder.build('r_rias_line', DateSpan.parse('2000-06-15'));
    expect(offRows.map((row) => row.node), isNot(contains('n_orikasa')));
    final then = builder
        .build('r_rias_line', DateSpan.parse('2000-06-15'), carryoverStops: stops)
        .singleWhere((row) => row.node == 'n_orikasa');
    expect(then.selectable, isTrue);
    expect(then.savedAs, isNotNull);
    final now = builder
        .build('r_rias_line', DateSpan.parse('2026-11-01'), carryoverStops: stops)
        .singleWhere((row) => row.node == 'n_orikasa');
    expect(now.selectable, isFalse);
  }, skip: skip);
}
