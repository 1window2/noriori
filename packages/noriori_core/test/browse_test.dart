import 'package:noriori_core/noriori_core.dart';
import 'package:test/test.dart';

const today = '2026-11-02';

NetPeriod span(String from, String to) =>
    NetPeriod(fromLo: from, fromHi: from, toLo: to, toHi: to);

NetAttr attr(String edge, String line, String operator, NetPeriod period) => NetAttr(
      edgeId: edge,
      lineId: line,
      operatorId: operator,
      lineageId: 'lg-$line',
      carryoverGroup: 'c-$line',
      period: period,
    );

NetUnit unit(int n, String edge, String line, int meters, String hi) => NetUnit(
      n: n,
      key: 'lg-$line:$edge',
      carryover: true,
      edgeId: edge,
      meters: meters,
      normal: true,
      dateLo: '1900-01-01',
      dateHi: hi,
    );

/// e1은 국철에서 JR로 넘어간 뒤 2000년에 폐지됐다. e2는 같은 노선의 현행 구간이다.
/// e3은 사철 m의 폐선이고 e4는 두 회사가 나눠 가진 노선 n의 현행 구간이다.
Network sample() => Network(
      NetworkData(
        routes: const [],
        edges: const [],
        routeEdges: const [],
        stops: const [],
        attrs: [
          // 마지막 소유자가 행 순서로 정해지지 않게 나중 소유자를 먼저 둔다
          attr('e1', 'l', 'east', span('1987-04-01', '2000-01-01')),
          attr('e1', 'l', 'jnr', span('1900-01-01', '1987-04-01')),
          attr('e2', 'l', 'east', span('1987-04-01', DateSpan.maxDate)),
          attr('e3', 'm', 'pri', span('1900-01-01', '2010-01-01')),
          attr('e4', 'n', 'east', span('1987-04-01', DateSpan.maxDate)),
          attr('e5', 'n', 'central', span('1987-04-01', DateSpan.maxDate)),
        ],
        lives: const [],
        units: [
          unit(1, 'e1', 'l', 1000, '2000-01-01'),
          unit(2, 'e2', 'l', 3000, DateSpan.maxDate),
          unit(3, 'e3', 'm', 500, '2010-01-01'),
          unit(4, 'e4', 'n', 700, DateSpan.maxDate),
          unit(5, 'e5', 'n', 300, DateSpan.maxDate),
        ],
        publicNodes: const {},
        nodeGroups: const {},
        operators: const [
          NetOperator(id: 'jnr', category: 'jr'),
          NetOperator(id: 'east', category: 'jr'),
          NetOperator(id: 'central', category: 'jr'),
          NetOperator(id: 'pri', category: 'general_private'),
        ],
        lineOrder: const ['l', 'm', 'n'],
      ),
    );

/// a-b-c-d-e 한 줄. c는 숨은 노드다. 구간은 100, 200, 300, 400m이고 ab와 bc 일부가 도쿄다.
final stripNetwork = Network(
  NetworkData(
    routes: const [
      NetRoute(
        id: 'r',
        lineId: 'l',
        role: 'main',
        fromNode: 'a',
        toNode: 'e',
        closed: false,
      ),
    ],
    edges: const [
      NetEdge(id: 'ab', n: 1, from: 'a', to: 'b', meters: 100),
      NetEdge(id: 'bc', n: 2, from: 'b', to: 'c', meters: 200),
      NetEdge(id: 'cd', n: 3, from: 'c', to: 'd', meters: 300),
      NetEdge(id: 'de', n: 4, from: 'd', to: 'e', meters: 400),
    ],
    routeEdges: const [
      NetRouteEdge(routeId: 'r', seq: 0, edgeId: 'ab'),
      NetRouteEdge(routeId: 'r', seq: 1, edgeId: 'bc'),
      NetRouteEdge(routeId: 'r', seq: 2, edgeId: 'cd'),
      NetRouteEdge(routeId: 'r', seq: 3, edgeId: 'de'),
    ],
    stops: [
      for (final (i, node) in const ['a', 'b', 'c', 'd', 'e'].indexed)
        NetStop(
          routeId: 'r',
          seq: i,
          node: node,
          kmCum: null,
          isStop: node != 'c',
          
          period: span('1900-01-01', DateSpan.maxDate),
        ),
    ],
    attrs: [
      for (final edge in const ['ab', 'bc', 'cd', 'de'])
        attr(edge, 'l', 'east', span('1900-01-01', DateSpan.maxDate)),
    ],
    lives: [
      for (final edge in const ['ab', 'bc', 'cd', 'de'])
        NetLife(edgeId: edge, suspended: false, period: span('1900-01-01', DateSpan.maxDate)),
    ],
    units: [
      unit(1, 'ab', 'l', 100, DateSpan.maxDate),
      unit(2, 'bc', 'l', 200, DateSpan.maxDate),
      unit(3, 'cd', 'l', 300, DateSpan.maxDate),
      unit(4, 'de', 'l', 400, DateSpan.maxDate),
    ],
    publicNodes: const {'a', 'b', 'd', 'e'},
    nodeGroups: const {},
    operators: const [NetOperator(id: 'east', category: 'jr')],
    lineOrder: const ['l'],
    edgePrefs: const [
      NetEdgePref(edgeId: 'ab', pref: 13, meters: 100),
      NetEdgePref(edgeId: 'bc', pref: 13, meters: 150),
      NetEdgePref(edgeId: 'bc', pref: 14, meters: 50),
      NetEdgePref(edgeId: 'cd', pref: 13, meters: 150),
      NetEdgePref(edgeId: 'cd', pref: 14, meters: 150),
      NetEdgePref(edgeId: 'de', pref: 14, meters: 400),
    ],
  ),
);

void main() {
  final network = sample();
  BrowseTree tree(BrowseEra era, [Map<int, String?> hits = const {}]) =>
      browseTree(network, era: era, hits: hits, today: today);

  group('현행', () {
    test('오늘 영업 중인 구간만 든다', () {
      final current = tree(BrowseEra.current);
      expect(current.total.denMeters, 4000);
      expect(current.categories.map((c) => c.category), ['jr']);
    });

    test('두 회사가 나눠 가진 노선은 회사마다 자기 구간만 나온다', () {
      final operators = tree(BrowseEra.current).categories.single.operators;
      expect(operators.map((o) => o.operatorId), ['east', 'central']);
      final east = operators.first.lines;
      expect(east.map((l) => l.lineId), ['l', 'n']);
      expect(east.last.score.denMeters, 700);
      expect(operators.last.lines.single.score.denMeters, 300);
    });
  });

  group('폐선', () {
    test('일부만 폐지된 노선은 폐지 구간만 든다', () {
      final closed = tree(BrowseEra.closed);
      final line = closed.category('jr')!.operators.single.lines.single;
      expect(line.lineId, 'l');
      expect(line.score.denMeters, 1000);
    });

    test('이관된 구간은 마지막 소유자에게만 든다', () {
      final operators = tree(BrowseEra.closed).category('jr')!.operators;
      expect(operators.map((o) => o.operatorId), ['east']);
    });

    test('회사가 사라져도 분류 아래 남는다', () {
      final closed = tree(BrowseEra.closed);
      expect(closed.category('general_private')!.operators.single.operatorId, 'pri');
      expect(closed.total.denMeters, 1500);
    });

    test('날짜와 무관하게 탄 구간을 센다', () {
      final closed = tree(BrowseEra.closed, const {1: '1990-01-01'});
      expect(closed.category('jr')!.score.permille, 1000);
      expect(closed.total.numMeters, 1000);
    });
  });

  group('요약 수치', () {
    test('두 회사가 나눠 가진 노선은 한 노선이다', () {
      final current = tree(BrowseEra.current, const {4: null});
      expect(current.lineCount, 2);
      expect(current.startedLineCount, 1);
      expect(current.completeLineCount, 0);
    });

    test('다 탄 노선만 완주다', () {
      final current = tree(BrowseEra.current, const {4: null, 5: null});
      expect(current.completeLineCount, 1);
      expect(current.startedOperatorCount, 2);
    });

    test('곧 완주는 시작했고 덜 탄 노선만이고 남은 거리가 짧은 순서다', () {
      final current = browseTree(
        stripNetwork,
        era: BrowseEra.current,
        hits: const {1: null, 2: null},
        today: today,
      );
      final near = current.nearlyComplete();
      expect(near.single.lineId, 'l');
      expect(near.single.score.remainingMeters, 700);
      final done = browseTree(
        stripNetwork,
        era: BrowseEra.current,
        hits: const {1: null, 2: null, 3: null, 4: null},
        today: today,
      );
      expect(done.nearlyComplete(), isEmpty);
    });
  });

  group('위치 띠', () {
    LineStrip strip(Map<int, String?> hits) => lineStrip(
          stripNetwork,
          browseTree(stripNetwork, era: BrowseEra.current, hits: hits, today: today)
              .lines
              .single,
        );

    test('탄 구간을 실제 자리에 놓고 이어진 구간은 합친다', () {
      final result = strip(const {1: null, 2: null, 4: null});
      expect(result.totalMeters, 1000);
      expect(result.segments.map((s) => (s.from, s.to)), [(0, 300), (600, 1000)]);
      expect(result.complete, isFalse);
    });

    test('다 타면 한 덩어리다', () {
      expect(strip(const {1: null, 2: null, 3: null, 4: null}).complete, isTrue);
    });

    test('안 탔으면 칠할 것이 없다', () {
      expect(strip(const {}).segments, isEmpty);
    });

    test('그 줄에 든 구간만 띠에 놓는다', () {
      const line = BrowseLine(
        lineId: 'l',
        score: Score(numMeters: 0, denMeters: 0, numUnits: 0, denUnits: 0),
        edgeIds: {'bc', 'cd'},
        riddenEdgeIds: {'cd'},
      );
      final result = lineStrip(stripNetwork, line);
      expect(result.totalMeters, 500);
      expect(result.segments.single.from, 200);
      expect(result.startNode, 'b');
      expect(result.endNode, 'd');
    });

    test('숨은 역은 끝 역 이름으로 고르지 않는다', () {
      const line = BrowseLine(
        lineId: 'l',
        score: Score(numMeters: 0, denMeters: 0, numUnits: 0, denUnits: 0),
        edgeIds: {'cd', 'de'},
        riddenEdgeIds: {},
      );
      final result = lineStrip(stripNetwork, line);
      expect(result.startNode, 'd');
      expect(result.endNode, 'e');
    });

    test('양 끝 역을 안다', () {
      final result = strip(const {});
      expect(result.startNode, 'a');
      expect(result.endNode, 'e');
    });
  });

  group('행 사이', () {
    test('숨은 역을 지나도 사이를 다 타야 탄 것이다', () {
      final builder = SelectorBuilder(stripNetwork);
      final rows = builder.build('r', null);
      expect(rows.map((r) => r.node), ['a', 'b', 'd', 'e']);
      expect(builder.riddenBetween('r', rows, const {1, 3, 4}), [true, false, true, false]);
      expect(builder.riddenBetween('r', rows, const {1, 2, 3}), [true, true, false, false]);
    });
  });

  group('저장 미리 보기', () {
    Expansion expand(String a, String b) => RouteResolver(stripNetwork).expand('r', a, b);

    test('처음 타는 구간과 오를 완주율을 알려 준다', () {
      final result = previewRide(
        stripNetwork,
        lineIds: ['l'],
        expansions: [expand('a', 'b')],
        hits: const {4: null},
        today: today,
      );
      expect(result.newMeters, 100);
      expect(result.before!.numMeters, 400);
      expect(result.after!.numMeters, 500);
    });

    test('이미 탄 구간은 오르지 않는다', () {
      final result = previewRide(
        stripNetwork,
        lineIds: ['l'],
        expansions: [expand('a', 'b')],
        hits: const {1: null},
        today: today,
      );
      expect(result.newMeters, 0);
      expect(result.after!.numMeters, result.before!.numMeters);
    });
  });

  group('도도부현', () {
    test('경계를 넘는 구간은 현마다 나눠 센다', () {
      final scores = prefScores(
        stripNetwork,
        hits: const {2: null},
        basis: const BasisCurrent(),
        today: today,
      );
      expect(scores[13]!.denMeters, 400);
      expect(scores[13]!.numMeters, 150);
      expect(scores[14]!.denMeters, 600);
      expect(scores[14]!.numMeters, 50);
    });

    test('이번 달에 처음 탄 km만 센다', () {
      final meters = newMetersSince(
        stripNetwork,
        hits: const {1: '2026-11-01', 2: '2026-10-31', 3: null},
        since: '2026-11-01',
        today: today,
      );
      expect(meters, 100);
    });
  });

  test('현행과 폐선을 합치면 빠지는 구간이 없다', () {
    final current = tree(BrowseEra.current).total.denUnits;
    final closed = tree(BrowseEra.closed).total.denUnits;
    expect(current + closed, network.data.units.length);
  });

  test('분류는 정한 순서로 나오고 빈 분류는 없다', () {
    final closed = tree(BrowseEra.closed);
    expect(closed.categories.map((c) => c.category), ['jr', 'general_private']);
  });
}
