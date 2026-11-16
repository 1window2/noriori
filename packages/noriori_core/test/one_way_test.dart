import 'package:noriori_core/noriori_core.dart';
import 'package:test/test.dart';

const ongoing = NetPeriod(fromLo: '1900-01-01', fromHi: '1900-01-01', toLo: DateSpan.maxDate, toHi: DateSpan.maxDate);
const from2000 = NetPeriod(fromLo: '2000-01-01', fromHi: '2000-01-01', toLo: DateSpan.maxDate, toHi: DateSpan.maxDate);
const before2000 = NetPeriod(fromLo: '1900-01-01', fromHi: '1900-01-01', toLo: '2000-01-01', toHi: '2000-01-01');

NetStop stop(String routeId, int seq, String node) => NetStop(
      routeId: routeId,
      seq: seq,
      node: node,
      kmCum: null,
      isStop: true,
      isExtension: false,
      period: ongoing,
    );

NetAttr attr(String edge, String line) => NetAttr(
      edgeId: edge,
      lineId: line,
      operatorId: 'o',
      lineageId: 'lg-$line',
      carryoverGroup: 'c-$line',
      period: ongoing,
    );

/// 열린 계통 o: a–b–c. b→c는 늘 한 방향, a는 2000년부터 seq_up 열차만 선다. d–e는 2000년 전에만 d→e 한 방향이다.
/// 닫힌 계통 loop: x→y→z→x 한 방향 고리.
Network sample() => Network(
      NetworkData(
        routes: const [
          NetRoute(id: 'o', lineId: 'l', role: 'main', fromNode: 'a', toNode: 'e', closed: false, extendTo: []),
          NetRoute(id: 'loop', lineId: 'm', role: 'main', fromNode: 'x', toNode: 'x', closed: true, extendTo: []),
        ],
        edges: const [
          NetEdge(id: 'ab', n: 1, from: 'a', to: 'b', meters: 1000),
          NetEdge(id: 'bc', n: 2, from: 'b', to: 'c', meters: 1000),
          NetEdge(id: 'cd', n: 3, from: 'c', to: 'd', meters: 1000),
          NetEdge(id: 'de', n: 4, from: 'd', to: 'e', meters: 1000),
          NetEdge(id: 'xy', n: 5, from: 'x', to: 'y', meters: 100),
          NetEdge(id: 'yz', n: 6, from: 'y', to: 'z', meters: 200),
          NetEdge(id: 'zx', n: 7, from: 'z', to: 'x', meters: 400),
        ],
        routeEdges: const [
          NetRouteEdge(routeId: 'o', seq: 0, edgeId: 'ab'),
          NetRouteEdge(routeId: 'o', seq: 1, edgeId: 'bc'),
          NetRouteEdge(routeId: 'o', seq: 2, edgeId: 'cd'),
          NetRouteEdge(routeId: 'o', seq: 3, edgeId: 'de'),
          NetRouteEdge(routeId: 'loop', seq: 0, edgeId: 'xy'),
          NetRouteEdge(routeId: 'loop', seq: 1, edgeId: 'yz'),
          NetRouteEdge(routeId: 'loop', seq: 2, edgeId: 'zx'),
        ],
        stops: [
          stop('o', 0, 'a'),
          stop('o', 1, 'b'),
          stop('o', 2, 'c'),
          stop('o', 3, 'd'),
          stop('o', 4, 'e'),
          stop('loop', 0, 'x'),
          stop('loop', 1, 'y'),
          stop('loop', 2, 'z'),
          stop('loop', 3, 'x'),
        ],
        attrs: [for (final e in ['ab', 'bc', 'cd', 'de']) attr(e, 'l'), for (final e in ['xy', 'yz', 'zx']) attr(e, 'm')],
        lives: [for (final e in ['ab', 'bc', 'cd', 'de', 'xy', 'yz', 'zx']) NetLife(edgeId: e, suspended: false, period: ongoing)],
        units: const [],
        publicNodes: const {'a', 'b', 'c', 'd', 'e', 'x', 'y', 'z'},
        nodeGroups: const {},
        oneWays: const [
          NetOneWay(routeId: 'o', edgeId: 'bc', from: 'b', to: 'c', period: ongoing),
          NetOneWay(routeId: 'o', edgeId: 'de', from: 'd', to: 'e', period: before2000),
          NetOneWay(routeId: 'loop', edgeId: 'xy', from: 'x', to: 'y', period: ongoing),
          NetOneWay(routeId: 'loop', edgeId: 'yz', from: 'y', to: 'z', period: ongoing),
          NetOneWay(routeId: 'loop', edgeId: 'zx', from: 'z', to: 'x', period: ongoing),
        ],
        stopDirections: const [
          NetStopDirection(routeId: 'o', node: 'a', direction: seqUp, label: 'down', period: from2000),
          NetStopDirection(routeId: 'o', node: 'c', direction: seqUp, label: 'down', use: 'alight', period: ongoing),
        ],
      ),
    );

void main() {
  final network = sample();
  final resolver = RouteResolver(network);
  DateSpan day(String raw) => DateSpan.parse(raw);

  group('한 방향 칸 (DESIGN §8 한 방향 운행)', () {
    test('운행 방향으로는 지나고 거꾸로는 그 이유로 막는다', () {
      expect(resolver.record('o', 'b', 'c').status, ResolveStatus.ok);
      final back = resolver.record('o', 'c', 'b');
      expect(back.status, ResolveStatus.invalid);
      expect(back.reason, ExpandReason.oneWay);
    });

    test('거꾸로 막힌 날을 날짜 모름으로 내려 저장하지 않는다', () {
      final back = resolver.record('o', 'c', 'b', date: day('2010-01-01'));
      expect(back.reason, ExpandReason.oneWay);
      expect(back.demoted, isFalse);
    });

    test('기간이 있는 한 방향은 그 기간에만 막고, 날짜를 모르면 막지 않는다', () {
      expect(resolver.record('o', 'e', 'd', date: day('1990-01-01')).reason, ExpandReason.oneWay);
      expect(resolver.record('o', 'e', 'd', date: day('2010-01-01')).status, ResolveStatus.ok);
      expect(resolver.record('o', 'e', 'd').status, ResolveStatus.ok);
    });

    test('칸의 한 방향을 그날 기준으로 알려 준다', () {
      expect(network.oneWayOf('o', 'bc', null), ('b', 'c'));
      expect(network.oneWayOf('o', 'de', day('1990-01-01')), ('d', 'e'));
      expect(network.oneWayOf('o', 'de', day('2010-01-01')), isNull);
      expect(network.oneWayOf('o', 'ab', null), isNull);
    });

    test('이웃한 두 역 사이의 한 방향을 목록 방향으로 알려 준다', () {
      expect(network.oneWayBetween('o', 'b', 'c', null), isTrue);
      expect(network.oneWayBetween('o', 'c', 'b', null), isFalse);
      expect(network.oneWayBetween('o', 'a', 'b', null), isNull);
      expect(network.oneWayBetween('loop', 'z', 'x', null), isTrue);
    });
  });

  group('한 방향 순환', () {
    test('방향을 정하지 않으면 운행 방향으로 돌아가는 길이고 그렇다고 표시한다', () {
      final result = resolver.record('loop', 'y', 'x');
      expect(result.status, ResolveStatus.ok);
      expect(result.edges, ['yz', 'zx']);
      expect(result.meters, 600);
      expect(result.direction, seqUp);
      expect(result.around, isTrue);
    });

    test('운행 방향 그대로면 돌아가는 길이 아니다', () {
      expect(resolver.record('loop', 'x', 'y').around, isFalse);
    });

    test('반대 방향은 고를 수 없다', () {
      expect(resolver.record('loop', 'y', 'x', direction: seqDown).status, ResolveStatus.invalid);
    });

    test('한 바퀴도 운행 방향으로만 돈다', () {
      expect(resolver.record('loop', 'x', 'x', direction: seqUp).status, ResolveStatus.ok);
      final back = resolver.record('loop', 'x', 'x', direction: seqDown);
      expect(back.status, ResolveStatus.invalid);
      expect(back.reason, ExpandReason.oneWay);
    });
  });

  group('한 방향 정차 (DESIGN §8 한 방향 정차)', () {
    test('그 방향 열차만 서는 역은 반대 방향의 출발·도착이 될 수 없다', () {
      expect(resolver.record('o', 'a', 'b', date: day('2010-01-01')).status, ResolveStatus.ok);
      final back = resolver.record('o', 'b', 'a', date: day('2010-01-01'));
      expect(back.status, ResolveStatus.invalid);
      expect(back.reason, ExpandReason.stopDirection);
    });

    test('제한 전 날짜와, 제한이 정차 기간 전체를 덮지 않을 때의 날짜 모름은 받는다', () {
      expect(resolver.record('o', 'b', 'a', date: day('1990-01-01')).status, ResolveStatus.ok);
      expect(resolver.record('o', 'b', 'a').status, ResolveStatus.ok);
    });

    test('내리기만 하는 역은 도착역으로만 고를 수 있다', () {
      expect(resolver.record('o', 'b', 'c').status, ResolveStatus.ok);
      expect(resolver.record('o', 'c', 'd').reason, ExpandReason.stopDirection);
    });

    test('정차 방향 행을 그날 기준으로 알려 준다', () {
      expect(network.stopDirectionOf('o', 'a', day('2010-01-01'))?.label, 'down');
      expect(network.stopDirectionOf('o', 'a', day('1990-01-01')), isNull);
      expect(network.stopDirectionOf('o', 'a', null), isNull);
    });
  });
}
