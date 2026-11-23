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
      sectionEnds: builder.sectionEnds(routeId, visible, DateSpan.parse(today), date: date),
      undated: date == null,
      parallels: await reader.routeParallels(routeId),
      date: date,
      shownLineId: network.lineOnDate(routeId, date),
    );
  }

  StopLine stopAt(List<SelectorLine> lines, String node) =>
      lines.whereType<StopLine>().firstWhere((line) => line.row.node == node);

  // 5번 결정(2026-11-19, 입력 단계 재구성 2026-11-20): 확장 행 대신 승하차 불가 끝 노드와 끝 이어짐
  Future<StopLine> endNode(String route, String? raw, String node) async => stopAt(await screen(route, raw), node);
  bool continuesTo(StopLine line, String lineId) =>
      line.row.links.any((l) => l.kind == 'continue' && l.otherLineId == lineId);

  test('분기점 끝 노드는 가운데가 회색인 고를 수 있는 행이고 그 노선으로 끝 이어짐이 있다 (犬山線 枇杷島分岐点)', () async {
    final end = await endNode('r_inuyama_line', today, 'n_biwajima_junction');
    expect(end.row.passing, isTrue);
    expect(end.row.selectable, isTrue);
    expect(continuesTo(end, 'l_nagoya_main_line'), isTrue);
  }, skip: skip);

  // 회색은 신호장·분기점만이다. 승객 없는 역(화물역 北鹿島 1970–1994)은 보통 역 모양에 「승하차 불가」로 고를 수 있다 (사용자 결정 2026-11-21, 결정 A 추천안)
  test('그날 서지 않는 계통 끝 역은 「승하차 불가」 끝 노드이고 끝 너머 노선으로 이어진다 (大洗鹿島線 北鹿島 1990)', () async {
    final end = await endNode('r_oarai_kashima_line', '1990-06-01', 'n_kashima_soccer_stadium_kashima_rinkai');
    expect(end.row.noBoarding, isTrue);
    expect(end.row.passing, isFalse);
    expect(end.row.selectable, isTrue);
    expect(continuesTo(end, 'l_kashima_line'), isTrue);
  }, skip: skip);

  test('끝 노드를 역 노드로 합쳐도 연락선은 그 역에 서지 않는다 (西武秩父鉄道連絡線 御花畑)', () async {
    final lines = await screen('r_chichibu_railway_connecting_line', today);
    // 御花畑는 역(秩父本線이 섬)이라 연락선 화면에서는 「승하차 불가」, 분기점은 회색이다
    expect(stopAt(lines, 'n_ohanabatake').row.noBoarding, isTrue);
    expect(stopAt(lines, 'n_seibu_chichibu_through').row.passing, isTrue);
    expect(continuesTo(stopAt(lines, 'n_ohanabatake'), 'l_chichibu_main_line'), isTrue);
  }, skip: skip);

  test('지나가는 계통의 정차 공백 동안 그 노드가 다른 계통의 끝이면 끝 이어짐이 그 기간에도 있다 (広電 옛 경로 観音町 1960)', () async {
    final end = await endNode('r_hiroden_main_line_tenmacho_hiroden_nishi_hiroshima', '1960-06-01', 'n_kanonmachi');
    expect(end.row.passing, isTrue);
    expect(continuesTo(end, 'l_hiroden_main_line'), isTrue);
  }, skip: skip);

  test('확장 행 사이에는 폐지 구분선이 없다 (富山 新富町, 東北貨物線·山手貨物線 三河島)', () async {
    for (final route in [
      'r_tramway_toyama_station_north_south_link',
      'r_tohoku_freight_line',
      'r_yamanote_freight_line',
    ]) {
      for (final raw in [today, null]) {
        expect((await screen(route, raw)).whereType<NoticeLine>().where((n) => n.kind != NoticeKind.hand), isEmpty, reason: '$route $raw');
      }
    }
  }, skip: skip);

  test('통째 이관 뒤 폐지된 노선의 오늘·날짜 모름 화면은 첫 역부터 끝 역까지 폐지 괄호 하나다 (神岡線·高千穂線)', () async {
    // 폐지일이 지난 칸은 이관보다 폐지가 앞선다 (사용자 결정 2026-11-19)
    for (final route in ['r_kamioka_line', 'r_takachiho_line']) {
      for (final raw in [today, null]) {
        final lines = await screen(route, raw);
        final notices = lines.whereType<NoticeLine>().toList();
        expect([for (final n in notices) n.kind], [NoticeKind.closed], reason: '$route $raw');
        expect(notices.single.top.matches(lines.whereType<StopLine>().first), isTrue, reason: '$route $raw');
        expect(notices.single.bottom.matches(lines.whereType<StopLine>().last), isTrue, reason: '$route $raw');
      }
    }
    // 재개 없이 폐지로 끝난 운휴는 운휴 시작(2005-09-06 태풍 불통)으로 소급해 닫히므로 안내의 해도 그해다
    // (DESIGN §2.2 「운행을 다시 시작하지 않고 끝난 휴지」, 결정 122. 법적 폐지 2007·2008은 legal_abolition)
    final takachiho = await screen('r_takachiho_line', today);
    expect([for (final line in takachiho.whereType<NoticeLine>()) line.year], ['2005']);
    // 폐지 전 날짜면 화면 제목이 이어받은 노선(高千穂鉄道高千穂線)이라 이관 괄호도 없다. 같은 노선으로의 이관 안내는 제목과 겹친다 (실화면 2026-11-19)
    final before = await screen('r_takachiho_line', '2000-06-01');
    expect(network.lineOnDate('r_takachiho_line', DateSpan.parse('2000-06-01')), 'l_takachiho_line_takachiho');
    expect(before.whereType<NoticeLine>(), isEmpty);
  }, skip: skip);

  test('이관 구간 안에서 이어받은 노선이 옮기거나 닫은 옛 자리는 이관 괄호를 끊지 않는다 (湯前線 川村, 東北本線 野内（旧）)', () async {
    // 오늘 화면은 제목이 くま川鉄道湯前線이라 괄호가 없다. 날짜 모름 화면(제목 湯前線)으로 본다
    final yunomae = await screen('r_yunomae_line', null);
    expect([for (final n in yunomae.whereType<NoticeLine>()) (n.kind, n.lineId)], [(NoticeKind.hand, 'l_yunomae_line_kumagawa')]);
    final tohoku = await screen('r_tohoku_main_line', today);
    final nonai = tohoku.indexWhere((line) => line is StopLine && line.row.node == 'n_nonai_aoimori_aoimori_railway_old');
    final around = [
      for (final n in tohoku.whereType<NoticeLine>())
        if (tohoku.indexWhere(n.top.matches) < nonai && tohoku.indexWhere(n.bottom.matches) > nonai) n,
    ];
    expect([for (final n in around) (n.kind, n.lineId)], [(NoticeKind.hand, 'l_aoimori_railway_line')]);
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

  test('이관된 상대 노선은 그 날의 노선 하나만 보인다 (十和田観光電鉄線 三沢: 오늘은 青い森鉄道線, 2000년은 東北本線, 사용자 결정 2026-11-19)', () async {
    final now = [for (final g in stopAt(await screen('r_towada_kanko_electric_railway_line', today), 'n_misawa_towada_kanko').transfers) ...g.items].single;
    expect(now.link.otherLineId, 'l_aoimori_railway_line');
    expect(now.before, isEmpty);
    final then = [for (final g in stopAt(await screen('r_towada_kanko_electric_railway_line', '2000-06-01'), 'n_misawa_towada_kanko').transfers) ...g.items].single;
    expect(then.link.otherLineId, 'l_tohoku_main_line');
  }, skip: skip);

  test('맨 끝 역의 직통은 그 역이 이어받은 노선도 떠난 옛 자리여도 끝 이어짐이다 (信越本線 新潟（旧）)', () async {
    for (final raw in [today, null]) {
      final lines = await screen('r_shinetsu_main_line_niigata_old_sekiya', raw);
      expect(lines.whereType<EndLine>().single.items.single.link.otherLineId, 'l_shinetsu_main_line', reason: '$raw');
      expect(lines.whereType<BranchLine>(), isEmpty, reason: '$raw');
    }
  }, skip: skip);
}
