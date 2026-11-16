import 'dart:io';

import 'package:noriori_core/noriori_core.dart';
import 'package:noriori_store/noriori_store.dart';
import 'package:test/test.dart';

/// 선택기 표시 규칙을 실제 판의 화면으로 본다 (DESIGN §8.0.1·§8.1). 감사 2회차 B4 지적 사례다.
void main() {
  final master = File('../../build/master.sqlite');
  final skip = master.existsSync() ? null : '판이 없다';
  const today = '2026-11-11';

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

  /// 기록 화면과 같은 순서로 줄을 만든다 (record_session_controller).
  Future<List<SelectorLine>> screen(String routeId, String? raw) async {
    const options = DisplayOptions();
    final date = raw == null ? null : DateSpan.parse(raw);
    final builder = SelectorBuilder(network);
    final rows = builder.fillHanded(
      routeId,
      builder.build(
        routeId,
        date,
        links: await reader.routeLinks(routeId, carryover: options.carryover),
        carryoverStops: await reader.carryoverStops(routeId),
      ),
      date,
      links: {for (final other in builder.handRoutes(routeId)) other: await reader.routeLinks(other)},
    );
    final rules = DisplayRules(network, today: today);
    final visible = rules.visible(rows, options);
    final openGaps = builder.openBetween(routeId, visible, date);
    return rules.lines(
      lineId: network.routes[routeId]!.lineId,
      rows: visible,
      openGaps: openGaps,
      options: options,
      closedRoute: network.routes[routeId]!.closed,
      archiveStops: await reader.archiveStops(routeId),
      archiveBranches: await reader.archiveBranches(rows.map((row) => row.node)),
      sectionGaps: date == null ? builder.openBetween(routeId, visible, DateSpan.parse(today)) : openGaps,
      sectionEnds: builder.sectionEnds(routeId, visible, DateSpan.parse(today)),
      undated: date == null,
      parallels: await reader.routeParallels(routeId),
      date: date,
    );
  }

  StopLine stopAt(List<SelectorLine> lines, String node) =>
      lines.whereType<StopLine>().firstWhere((line) => line.row.node == node);

  test('확장 행 사이에는 폐지 구분선이 없다 (富山 新富町, 東北貨物線·山手貨物線 三河島)', () async {
    for (final route in [
      'r_tramway_toyama_station_north_south_link',
      'r_tohoku_freight_line',
      'r_yamanote_freight_line',
    ]) {
      for (final raw in [today, null]) {
        expect((await screen(route, raw)).whereType<SectionLine>(), isEmpty, reason: '$route $raw');
      }
    }
  }, skip: skip);

  test('통째 이관 뒤 폐지된 노선의 오늘 화면은 날짜 모름처럼 머리 띠 하나이고 끝 역 앞 빈 구분선이 없다 (神岡線·高千穂線)', () async {
    for (final route in ['r_kamioka_line', 'r_takachiho_line']) {
      for (final raw in [today, null]) {
        final lines = await screen(route, raw);
        expect(lines.whereType<TransferLine>().single.whole, isTrue, reason: '$route $raw');
        expect(lines.whereType<SectionLine>().where((line) => line.year == null), isEmpty, reason: '$route $raw');
      }
    }
    // 재개 없이 폐지로 끝난 운휴는 운휴 시작(2005-09-06 태풍 불통)으로 소급해 닫히므로 구분선 연도도 그해다
    // (DESIGN §2.2 「운행을 다시 시작하지 않고 끝난 휴지」, 결정 122. 법적 폐지 2007·2008은 legal_abolition)
    final takachiho = await screen('r_takachiho_line', today);
    expect([for (final line in takachiho.whereType<SectionLine>()) line.year], ['2005']);
  }, skip: skip);

  test('이관 구간 안에서 이어받은 노선이 옮기거나 닫은 옛 자리는 구간을 끊지 않는다 (湯前線 川村, 東北本線 野内（旧）)', () async {
    final yunomae = (await screen('r_yunomae_line', today)).whereType<TransferLine>().toList();
    expect([for (final h in yunomae) (h.lineId, h.whole, h.back)], [('l_yunomae_line_kumagawa', true, false)]);
    final tohoku = await screen('r_tohoku_main_line', today);
    expect(tohoku.whereType<TransferLine>().where((h) => h.back), isEmpty);
    final nonai = tohoku.indexWhere((line) => line is StopLine && line.row.node == 'n_nonai_aoimori_aoimori_railway_old');
    final band = tohoku.lastIndexWhere((line) => line is TransferLine, nonai);
    expect((tohoku[band] as TransferLine).lineId, 'l_aoimori_railway_line');
  }, skip: skip);

  test('폐선 화면의 환승은 같은 노선이면 가장 늦게 끝난 연결을 남긴다 (枝光線 枝光駅前의 鹿児島本線)', () async {
    final stop = stopAt(await screen('r_edamitsu_line', today), 'n_edamitsu_ekimae');
    final item = [for (final g in stop.transfers) ...g.items].singleWhere((i) => i.link.otherLineId == 'l_kagoshima_main_line');
    expect(item.link.validToHi, '1985-10-20');
    expect(item.link.flow, 'through');
  }, skip: skip);

  test('오늘 화면에서도 끝난 병주 토막은 흐린 병주 선이고 그 칸 역 환승에서 빠진다 (北5条線↔鉄北線)', () async {
    final lines = await screen('r_kitagojo_line', today);
    expect(lines.whereType<StopLine>().expand((line) => line.lanes), isNotEmpty);
    expect(lines.whereType<StopLine>().expand((line) => line.lanes).every((mark) => mark.gone), isTrue);
    final ekimae = stopAt(lines, 'n_sapporo_ekimae');
    expect([for (final g in ekimae.transfers) for (final i in g.items) i.link.otherLineId], isNot(contains('l_teppoku_line')));
    // 병주가 끝난 뒤에도 더 오래 환승이었으면 그 환승이 남는다 (西野田線 1932년 병주 끝, 野田線 1964년까지 환승)
    expect((await screen('r_nishinoda_line', today)).whereType<StopLine>().expand((line) => line.lanes), isEmpty);
  }, skip: skip);

  test('이관된 상대 노선은 앞 노선 이름을 위에 두고 한 줄로 적는다 (十和田観光電鉄線 三沢의 東北本線 ~2010 › 青い森鉄道線)', () async {
    final stop = stopAt(await screen('r_towada_kanko_electric_railway_line', today), 'n_misawa_towada_kanko');
    final item = [for (final g in stop.transfers) ...g.items].single;
    expect(item.link.otherLineId, 'l_aoimori_railway_line');
    expect(item.before.map((link) => link.otherLineId), ['l_tohoku_main_line']);
  }, skip: skip);

  test('맨 끝 역의 직통은 그 역이 이어받은 노선도 떠난 옛 자리여도 끝 이어짐이다 (信越本線 新潟（旧）)', () async {
    for (final raw in [today, null]) {
      final lines = await screen('r_shinetsu_main_line_niigata_old_sekiya', raw);
      expect(lines.whereType<EndLine>().single.items.single.link.otherLineId, 'l_shinetsu_main_line', reason: '$raw');
      expect(lines.whereType<BranchLine>(), isEmpty, reason: '$raw');
    }
  }, skip: skip);
}
