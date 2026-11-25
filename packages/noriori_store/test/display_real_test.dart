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
      archiveBranches: await reader.archiveBranches(rows.map((row) => row.node), routes: {routeId, ...builder.handRoutes(routeId)}),
      sectionGaps: date == null ? builder.openBetween(routeId, visible, DateSpan.parse(today), offSeasonOpen: true) : openGaps,
      sectionEnds: builder.sectionEnds(routeId, visible, DateSpan.parse(today), date: date),
      undated: date == null,
      parallels: await reader.routeParallels(routeId),
      date: date,
      shownLineId: network.lineOnDate(routeId, date),
    );
  }

  StopLine stopAt(List<SelectorLine> lines, String node) =>
      lines.whereType<StopLine>().firstWhere((line) => line.row.node == node);

  // 구간 괄호는 그 화면 날짜의 상태다(2026-11-23). 운휴 뒤 재개한 칸은 운휴 중 날짜에 「폐지」가 아니라 「운휴」이고,
  // 칸은 있어도 이 노선이 아직 쓰기 전이면 「개업 전」이다
  NoticeLine noticeAt(List<SelectorLine> lines, String node) {
    final seq = stopAt(lines, node).row.seq;
    return lines.whereType<NoticeLine>().firstWhere((n) => n.top.seq == seq || n.bottom.seq == seq);
  }

  test('운휴 중 날짜의 구간 괄호는 운휴다 (常磐線 相馬–駒ヶ嶺 2013, 只見線 会津川口–只見 2013)', () async {
    expect(noticeAt(await screen('r_joban_line', '2013-06-01'), 'n_komagamine').kind, NoticeKind.suspended);
    expect(noticeAt(await screen('r_tadami_line', '2013-06-01'), 'n_tadami').kind, NoticeKind.suspended);
  }, skip: skip);

  test('계절 운행 노선의 비시즌 날짜는 녹색 계절 괄호이고 역은 고를 수 없다 (黒部峡谷鉄道 2020-01-15, 叡山ケーブル 2020-02-01)', () async {
    final winter = await screen('r_kurobe_gorge_main_line', '2020-01-15');
    // 괄호는 노선 전체(宇奈月~欅平)에 하나다. 가운데 역은 괄호 안에 든다
    NoticeLine over(List<SelectorLine> lines, String node) {
      final seq = stopAt(lines, node).row.seq;
      return lines.whereType<NoticeLine>().firstWhere((n) => (n.top.seq ?? -1) <= seq && seq <= (n.bottom.seq ?? -1));
    }
    expect(over(winter, 'n_kuronagi').kind, NoticeKind.season);
    expect(over(winter, 'n_kuronagi').year, '4-11');
    expect(stopAt(winter, 'n_kuronagi').row.state, StopState.offSeason);
    expect(stopAt(winter, 'n_kuronagi').row.selectable, isFalse);
    // 승객 미취급 역은 비시즌에도 회색 통과역으로 남고(柳橋), 한시 개방 역도 사라지지 않는다(笹平·猫又)
    expect(stopAt(winter, 'n_yanagibashi').row.passing, isTrue);
    expect(stopAt(winter, 'n_yanagibashi').row.staffOnly, isTrue);
    expect(stopAt(winter, 'n_sasadaira').row.passing, isTrue);
    expect(stopAt(winter, 'n_nekomata').row.passing, isTrue);
    final summer = await screen('r_kurobe_gorge_main_line', '2020-07-15');
    expect(summer.whereType<NoticeLine>().where((n) => n.kind == NoticeKind.season), isEmpty);
    expect(stopAt(summer, 'n_kuronagi').row.selectable, isTrue);
    expect(noticeAt(await screen('r_eizan_cable', '2020-02-01'), 'n_cable_hiei').kind, NoticeKind.season);
  });

  test('승객 미취급 정식 역은 일람에 회색으로 보이고 고를 수 없으며, 한시 개방 기간에만 고를 수 있다 (黒部峡谷鉄道 柳橋·猫又)', () async {
    final y2020 = await screen('r_kurobe_gorge_main_line', '2020-07-15');
    expect(stopAt(y2020, 'n_yanagibashi').row.selectable, isFalse);
    expect(stopAt(y2020, 'n_yanagibashi').row.passing, isTrue);
    expect(stopAt(y2020, 'n_nekomata').row.state, isNot(StopState.beforeOpen));
    expect(stopAt(y2020, 'n_nekomata').row.selectable, isFalse);
    expect(stopAt(await screen('r_kurobe_gorge_main_line', '2025-07-15'), 'n_nekomata').row.selectable, isTrue);
    // 개방이 끝난 뒤에도 역은 일람에 남고 폐역 해가 붙지 않는다(2025-07-15 笹平는 2025-05 개방 뒤, 猫又는 개방 중이라도 끝 해 없음)
    final y2025 = await screen('r_kurobe_gorge_main_line', '2025-07-15');
    expect(stopAt(y2025, 'n_sasadaira').row.passing, isTrue);
    expect(stopAt(y2025, 'n_sasadaira').row.closeYear, isNull);
    expect(stopAt(y2025, 'n_nekomata').row.closeYear, isNull);
    // 승객 미취급 역은 신호장과 같은 모양이어도 고를 수 없는 까닭이 다르다(안내 문구가 갈린다). 개방 중인 猫又는 보통 역이다
    expect(stopAt(y2025, 'n_yanagibashi').row.staffOnly, isTrue);
    expect(stopAt(y2025, 'n_yanagibashi').row.viewOnly, isTrue);
    expect(stopAt(y2025, 'n_nekomata').row.staffOnly, isFalse);
    // 날짜 모름: 마지막 개방 뒤 끝 없는 정차 공백은 승객 미취급 역의 본래 모습이라 운휴가 아니다
    final undated = await screen('r_kurobe_gorge_main_line', null);
    expect(stopAt(undated, 'n_sasadaira').row.suspendedSince, isNull);
    expect(stopAt(undated, 'n_nekomata').row.suspendedSince, isNull);
  });

  test('노선이 칸을 쓰기 전 날짜의 구간 괄호는 개업 전이다 (井原鉄道 総社–清音 1990)', () async {
    final n = noticeAt(await screen('r_ibara_line', '1990-06-01'), 'n_soja');
    expect((n.kind, n.year), (NoticeKind.before, '1999'));
  }, skip: skip);

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
  // 끝난 계절 노선의 운행 시절 비시즌: 계절 괄호는 해를 적지 않으니 역 줄의 「비시즌」을 지우지 않는다 (5회차 시뮬레이터 시험 2026-11-24)
  test('끝난 계절 노선의 비시즌 표시', () async {
    final lines = await screen('r_kanden_tunnel_trolleybus', '2010-01-15');
    for (final node in ['n_ogizawa', 'n_kurobe_dam']) {
      expect(stopAt(lines, node).row.state, StopState.offSeason);
      expect(stopAt(lines, node).quiet, isFalse);
    }
  }, skip: skip);
  // 운휴 중 이설해 계승한 역(常磐線 2011→2016): 옛 역은 새 역 개업 전날까지 운휴, 그 뒤는 폐역이다. 기록은 마지막 운행일까지만 (설계 audit5-relocation-successor-design.md)
  test('이설 계승역은 새 역 개업 전까지 운휴', () async {
    const route = 'r_joban_line_komagamine_hamayoshida';
    final y2010 = await screen(route, '2010-06-01');
    final y2013 = await screen(route, '2013-06-01');
    for (final node in ['n_shinchi_old', 'n_sakamoto_joban_old', 'n_yamashita_old']) {
      expect(stopAt(y2010, node).row.state, StopState.open, reason: node);
      expect(stopAt(y2013, node).row.state, StopState.suspended, reason: node);
      expect(stopAt(y2013, node).row.suspendedSince, '2011', reason: node);
      expect(stopAt(y2013, node).row.selectable, isFalse, reason: node);
    }
  }, skip: skip);
}
