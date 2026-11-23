import 'package:noriori_core/noriori_core.dart';
import 'package:test/test.dart';

/// 이관 구간 B안 2단계 (DESIGN §8.0.1). 국철 노선 `jr`의 b–d가 2024-03-16에 `3s`로 넘어갔다.
/// b는 국철 역으로 남고, n은 이관 뒤 2026-03-14에 생긴 3섹 역이라 국철 계통에는 숨은 노드로만 있다.
const _ongoing = NetPeriod(fromLo: '1900-01-01', fromHi: '1900-01-01', toLo: DateSpan.maxDate, toHi: DateSpan.maxDate);
const _jr = NetPeriod(fromLo: '1900-01-01', fromHi: '1900-01-01', toLo: '2024-03-16', toHi: '2024-03-16');
const _third = NetPeriod(fromLo: '2024-03-16', fromHi: '2024-03-16', toLo: DateSpan.maxDate, toHi: DateSpan.maxDate);
const _new = NetPeriod(fromLo: '2026-03-14', fromHi: '2026-03-14', toLo: DateSpan.maxDate, toHi: DateSpan.maxDate);

NetStop _stop(String route, int seq, String node, double km, NetPeriod period, {bool isStop = true}) => NetStop(
      routeId: route,
      seq: seq,
      node: node,
      kmCum: km,
      isStop: isStop,
      
      period: period,
    );

NetAttr _attr(String edge, String line, NetPeriod period) => NetAttr(
      edgeId: edge,
      lineId: line,
      operatorId: 'o-$line',
      lineageId: 'lg',
      carryoverGroup: 'c-$line',
      period: period,
    );

SelectorLink _link(int seq, String line, {String? from, String? to}) => SelectorLink(
      seq: seq,
      kind: 'transfer',
      otherLineId: line,
      otherRouteId: null,
      validFromLo: from,
      validToHi: to,
      flow: 'down',
    );

final _network = Network(
  NetworkData(
    routes: const [
      NetRoute(id: 'r_jr', lineId: 'jr', role: 'main', fromNode: 'a', toNode: 'd', closed: false),
      NetRoute(id: 'r_3s', lineId: '3s', role: 'main', fromNode: 'b', toNode: 'd', closed: false),
    ],
    edges: const [
      NetEdge(id: 'ab', n: 1, from: 'a', to: 'b', meters: 1000),
      NetEdge(id: 'bn', n: 2, from: 'b', to: 'n', meters: 2000),
      NetEdge(id: 'nc', n: 3, from: 'n', to: 'c', meters: 3000),
      NetEdge(id: 'cd', n: 4, from: 'c', to: 'd', meters: 4000),
    ],
    routeEdges: const [
      NetRouteEdge(routeId: 'r_jr', seq: 0, edgeId: 'ab'),
      NetRouteEdge(routeId: 'r_jr', seq: 1, edgeId: 'bn'),
      NetRouteEdge(routeId: 'r_jr', seq: 2, edgeId: 'nc'),
      NetRouteEdge(routeId: 'r_jr', seq: 3, edgeId: 'cd'),
      NetRouteEdge(routeId: 'r_3s', seq: 0, edgeId: 'bn'),
      NetRouteEdge(routeId: 'r_3s', seq: 1, edgeId: 'nc'),
      NetRouteEdge(routeId: 'r_3s', seq: 2, edgeId: 'cd'),
    ],
    stops: [
      _stop('r_jr', 0, 'a', 0, _ongoing),
      _stop('r_jr', 1, 'b', 1, _ongoing),
      _stop('r_jr', 2, 'n', 3, _jr, isStop: false),
      _stop('r_jr', 3, 'c', 6, _jr),
      _stop('r_jr', 4, 'd', 10, _jr),
      _stop('r_3s', 0, 'b', 0, _third),
      _stop('r_3s', 1, 'n', 2, _new),
      _stop('r_3s', 2, 'c', 5, _third),
      _stop('r_3s', 3, 'd', 9, _third),
    ],
    attrs: [
      _attr('ab', 'jr', _ongoing),
      for (final edge in ['bn', 'nc', 'cd']) ...[_attr(edge, 'jr', _jr), _attr(edge, '3s', _third)],
    ],
    lives: [
      for (final edge in ['ab', 'bn', 'nc', 'cd']) NetLife(edgeId: edge, suspended: false, period: _ongoing),
    ],
    units: const [],
    publicNodes: const {'a', 'b', 'n', 'c', 'd'},
    nodeGroups: const {},
  ),
);

/// c에서 국철 시절 x(이관 때 끝남), y(1980에 끝남)로 갈아탔고, 3섹은 x와 국철 노선으로 갈아탄다.
final _jrLinks = [_link(3, 'x', from: '1950-01-01', to: '2024-03-16'), _link(3, 'y', from: '1950-01-01', to: '1980-04-01')];
final _thirdLinks = {
  'r_3s': [_link(2, 'x', from: '2024-03-16'), _link(2, 'jr', from: '2024-03-16')],
};

void main() {
  final builder = SelectorBuilder(_network);
  List<SelectorRow> rows(String? raw) {
    final date = raw == null ? null : DateSpan.parse(raw);
    return builder.fillHanded('r_jr', builder.build('r_jr', date, links: _jrLinks), date, links: _thirdLinks);
  }

  test('이어받은 노선의 계통을 찾는다', () {
    expect(builder.handRoutes('r_jr'), {'r_3s'});
    expect(builder.handRoutes('r_3s'), isEmpty);
  });

  test('이관 뒤 날짜면 이관 뒤 새 역이 이 계통의 순번과 누적 km로 들어온다', () {
    final got = rows('2026-11-07');
    expect(got.map((row) => row.node), ['a', 'b', 'n', 'c', 'd']);
    final added = got[2];
    expect(added.seq, 2);
    expect(added.kmCum, 3, reason: '이 노선의 누적 km로 이어 쓴다');
    expect(added.handedOnly, isTrue);
    expect(added.selectable, isTrue);
    expect(added.state, StopState.open);
    expect(added.savedAs, '3s');
    expect((added.handedTo, added.handedOn), ('3s', '2024-03-16'));
    expect(added.openYear, '2026');
    expect(DisplayRules.bandOf(added), ('3s', '2024-03-16'));
  });

  test('구간 안 역의 환승은 이어받은 노선의 것이고 이관 전에 끝난 옛 환승은 폐선으로 남는다', () {
    final c = rows('2026-11-07')[3];
    expect([for (final link in c.links) (link.otherLineId, link.seq, link.validToHi)], [('x', 3, null)]);
    // 이 노선을 가리키는 3섹의 연결은 넣지 않고, 이관 때 끝난 국철 쪽 x는 3섹의 x가 대신한다
    expect([for (final link in c.goneLinks) link.otherLineId], ['y']);
  });

  test('이관 구간은 괄호 하나이고 안내는 괄호 맨 위 역 바로 아래에 한 번 놓인다', () {
    final got = rows('2026-11-07');
    final rules = DisplayRules(_network, today: '2026-11-07');
    final lines = rules.lines(
      lineId: 'jr',
      rows: got,
      openGaps: List.filled(got.length - 1, true),
      options: const DisplayOptions(),
    );
    // 이관 구간은 괄호 하나이고 안내는 괄호 맨 위 역 바로 아래다 (사용자 결정 2026-11-19)
    final hands = lines.whereType<NoticeLine>().toList();
    expect(hands, hasLength(1));
    expect(hands.single.kind, NoticeKind.hand);
    expect(hands.single.lineId, '3s');
    expect(lines.indexOf(hands.single), lines.indexWhere(hands.single.top.matches) + 1);
  });

  test('새 역이 생기기 전 이관 뒤 날짜면 개업 전이라 고를 수 없다', () {
    final added = rows('2025-01-01')[2];
    expect(added.node, 'n');
    expect(added.state, StopState.beforeOpen);
    expect(added.selectable, isFalse);
  });

  test('이관 전 날짜면 그대로다', () {
    final got = rows('2020-05-01');
    expect(got.map((row) => row.node), ['a', 'b', 'c', 'd']);
    final c = got[2];
    expect([for (final link in c.links) link.otherLineId], ['x']);
    expect([for (final link in c.goneLinks) link.otherLineId], ['y']);
  });

  test('날짜를 모르면 두 쪽 역을 합친 모든 역을 고를 수 있다', () {
    final got = rows(null);
    expect(got.map((row) => row.node), ['a', 'b', 'n', 'c', 'd']);
    final added = got[2];
    expect(added.state, StopState.unknown);
    expect(added.selectable, isTrue);
    expect(added.savedAs, isNull);
    expect(DisplayRules.bandOf(added, undated: true), ('3s', '2024-03-16'));
  });

  test('이관 구간이 없는 계통은 그대로다', () {
    final plain = builder.build('r_3s', DateSpan.parse('2026-11-07'));
    expect(identical(builder.fillHanded('r_3s', plain, DateSpan.parse('2026-11-07')), plain), isTrue);
  });

  group('저장', () {
    final resolver = RouteResolver(_network);

    test('이관 뒤 날짜면 이 계통으로 펼쳐도 이어받은 노선의 km로 나뉜다', () {
      final inside = resolver.record('r_jr', 'n', 'c', date: DateSpan.parse('2026-11-07'));
      expect([for (final leg in inside.legs) leg.lineId], ['3s']);
      expect(inside.meters, 3000);
      final crossing = resolver.record('r_jr', 'a', 'n', date: DateSpan.parse('2026-11-07'));
      expect({for (final leg in crossing.legs) leg.lineId: _network.metersOf(leg.edges, lineId: leg.lineId)},
          {'jr': 1000, '3s': 2000});
    });

    test('날짜를 모르면 이어받은 노선 계통을 넘어 나눈다', () {
      final result = resolver.acrossRoutes(['r_jr', 'r_3s'], 'a', 'n');
      expect([for (final leg in result.legs) (leg.lineId, leg.routeId, leg.from, leg.to)], [
        ('jr', 'r_jr', 'a', 'b'),
        ('3s', 'r_3s', 'b', 'n'),
      ]);
      expect(result.meters, 3000);
    });
  });
}
