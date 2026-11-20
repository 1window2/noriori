import 'package:noriori_core/noriori_core.dart';
import 'package:test/test.dart';

const always = NetPeriod(fromLo: '1900-01-01', fromHi: '1900-01-01');
const ongoing = NetPeriod(
  fromLo: '1900-01-01',
  fromHi: '1900-01-01',
  toLo: DateSpan.maxDate,
  toHi: DateSpan.maxDate,
);
const before2000 = NetPeriod(
  fromLo: '1900-01-01',
  fromHi: '1900-01-01',
  toLo: '2000-01-01',
  toHi: '2000-01-01',
);
const after2000 = NetPeriod(
  fromLo: '2000-01-01',
  fromHi: '2000-01-01',
  toLo: DateSpan.maxDate,
  toHi: DateSpan.maxDate,
);

NetStop stop(String routeId, int seq, String node, {NetPeriod period = ongoing, bool estimated = false}) => NetStop(
      routeId: routeId,
      seq: seq,
      node: node,
      kmCum: null,
      isStop: true,
      
      period: period,
      kmEstimated: estimated,
    );

NetAttr attr(
  String edge,
  String line, {
  NetPeriod period = ongoing,
  String operatorId = 'o',
}) =>
    NetAttr(
      edgeId: edge,
      lineId: line,
      operatorId: operatorId,
      lineageId: 'lg-$line',
      carryoverGroup: 'c-$line',
      period: period,
    );

NetLife life(String edge, {NetPeriod period = ongoing, bool suspended = false}) =>
    NetLife(edgeId: edge, suspended: suspended, period: period);

NetUnit unit(int n, String edge, String line, int meters) => NetUnit(
      n: n,
      key: 'lg-$line:$edge',
      carryover: true,
      edgeId: edge,
      meters: meters,
      normal: true,
      dateLo: '1900-01-01',
      dateHi: DateSpan.maxDate,
    );

/// a-b는 2000년에 이설했다. 옛 선은 1000m, 새 선은 1200m다. b-c는 운휴 중이다.
/// 고리 x-y-z는 닫힌 계통이다. b의 km는 추정값이다.
Network sample() => Network(
      NetworkData(
        routes: const [
          NetRoute(
            id: 'r',
            lineId: 'l',
            role: 'main',
            fromNode: 'a',
            toNode: 'c',
            closed: false,
          ),
          NetRoute(
            id: 'loop',
            lineId: 'm',
            role: 'main',
            fromNode: 'x',
            toNode: 'x',
            closed: true,
          ),
        ],
        edges: const [
          NetEdge(id: 'old', n: 1, from: 'a', to: 'b', meters: 1000),
          NetEdge(id: 'new', n: 2, from: 'a', to: 'b', meters: 1200),
          NetEdge(id: 'bc', n: 3, from: 'b', to: 'c', meters: 500),
          NetEdge(id: 'xy', n: 4, from: 'x', to: 'y', meters: 100),
          NetEdge(id: 'yz', n: 5, from: 'y', to: 'z', meters: 200),
          NetEdge(id: 'zx', n: 6, from: 'z', to: 'x', meters: 400),
        ],
        routeEdges: const [
          NetRouteEdge(routeId: 'r', seq: 0, edgeId: 'old'),
          NetRouteEdge(routeId: 'r', seq: 1, edgeId: 'new'),
          NetRouteEdge(routeId: 'r', seq: 2, edgeId: 'bc'),
          NetRouteEdge(routeId: 'loop', seq: 0, edgeId: 'xy'),
          NetRouteEdge(routeId: 'loop', seq: 1, edgeId: 'yz'),
          NetRouteEdge(routeId: 'loop', seq: 2, edgeId: 'zx'),
        ],
        stops: [
          stop('r', 0, 'a'),
          stop('r', 1, 'b', estimated: true),
          stop('r', 2, 'c'),
          stop('loop', 0, 'x'),
          stop('loop', 1, 'y'),
          stop('loop', 2, 'z'),
          stop('loop', 3, 'x'),
        ],
        attrs: [
          attr('old', 'l', period: before2000),
          attr('new', 'l', period: after2000),
          attr('bc', 'l'),
          attr('xy', 'm'),
          attr('yz', 'm'),
          attr('zx', 'm'),
        ],
        lives: [
          life('old', period: before2000),
          life('new', period: after2000),
          life('bc', period: const NetPeriod(fromLo: '1900-01-01', fromHi: '1900-01-01', toLo: '2020-01-01', toHi: '2020-01-01')),
          life(
            'bc',
            suspended: true,
            period: const NetPeriod(fromLo: '2020-01-01', fromHi: '2020-01-01', toLo: DateSpan.maxDate, toHi: DateSpan.maxDate),
          ),
          life('xy'),
          life('yz'),
          life('zx'),
        ],
        units: [
          unit(1, 'old', 'l', 1000),
          unit(2, 'new', 'l', 1200),
          unit(3, 'bc', 'l', 500),
        ],
        publicNodes: const {'a', 'b', 'c', 'x', 'y', 'z'},
        nodeGroups: const {'a': 'g-a'},
      ),
    );

void main() {
  final network = sample();
  final resolver = RouteResolver(network);
  DateSpan day(String raw) => DateSpan.parse(raw);

  test('km 추정값은 그 노선의 그 역에만 붙는다 (DESIGN §4.5)', () {
    expect(network.kmEstimatedOn('l', 'b'), isTrue);
    expect(network.kmEstimatedOn('l', 'a'), isFalse);
    expect(network.kmEstimatedOn('m', 'b'), isFalse);
    expect(network.kmEstimatedOn(null, 'b'), isFalse);
  });

  group('이설', () {
    test('날짜를 모르면 어느 시기인지 묻는다', () {
      final result = resolver.record('r', 'a', 'b');
      expect(result.status, ResolveStatus.needsInput);
      expect(result.reason, ExpandReason.relocatedParallel);
      expect(result.options.map((o) => o.meters), [1000, 1200]);
    });

    test('날짜가 있으면 그날의 선을 탄다', () {
      expect(resolver.record('r', 'a', 'b', date: day('1990-01-01')).edges, ['old']);
      expect(resolver.record('r', 'a', 'b', date: day('2010-01-01')).edges, ['new']);
    });

    test('하루로 정한 날짜가 as_of를 이기고 범위 날짜는 as_of를 따른다', () {
      final fixed = resolver.record('r', 'a', 'b', date: day('1990-01-01'), asOf: day('2010-01-01'));
      expect(fixed.edges, ['old']);
      final rough = resolver.record('r', 'a', 'b', date: day('199X-XX-XX'), asOf: day('2010-01-01'));
      expect(rough.edges, ['new']);
    });

    test('모른다고 답하면 공통 구간만 잡는다', () {
      final result = resolver.record('r', 'a', 'c', resolveUnknown: true);
      expect(result.status, ResolveStatus.partial);
      expect(result.edges, ['bc']);
    });
  });

  group('영업 판정', () {
    test('운휴 구간은 탈 수 없고 날짜 모름으로 내려간다', () {
      final result = resolver.record('r', 'b', 'c', date: day('2021-01-01'));
      expect(result.demoted, isTrue);
      expect(result.date, isNull);
      expect(result.status, ResolveStatus.ok);
    });

    test('기준일보다 이른 날짜는 날짜 모름이다', () {
      final result = resolver.record('r', 'b', 'c', date: day('1949-12-31'));
      expect(result.demoted, isTrue);
    });
  });

  test('맡은 회사를 모두 보고, 끝난 노선은 마지막 회사다', () {
    final owners = Network(
      NetworkData(
        routes: const [],
        edges: const [],
        routeEdges: const [],
        stops: const [],
        attrs: [
          attr('n', 'shared', operatorId: 'east'),
          attr('s', 'shared', operatorId: 'west'),
          attr('x', 'ended', operatorId: 'first', period: before2000),
          attr('y', 'ended', operatorId: 'second', period: before2000),
        ],
        lives: const [],
        units: const [],
        publicNodes: const {},
        nodeGroups: const {},
      ),
    );
    final today = day('2020-01-01');
    expect(owners.operatorsOn('shared', today), ['east', 'west']);
    expect(owners.operatorsOn('ended', today), ['second']);
    expect(owners.operatorsOn('none', today), isEmpty);
  });

  group('순환', () {
    test('기본은 짧은 쪽이다', () {
      final result = resolver.record('loop', 'x', 'z');
      expect(result.edges, ['xy', 'yz']);
      expect(result.meters, 300);
    });

    test('방향을 주면 긴 쪽으로도 돈다', () {
      final result = resolver.record('loop', 'x', 'z', direction: seqDown);
      expect(result.edges, ['zx']);
      expect(result.direction, seqDown);
    });

    test('한 바퀴는 고른 역에서 시작하고 방향을 따른다', () {
      final up = resolver.record('loop', 'y', 'y', direction: seqUp);
      expect(up.nodes, ['y', 'z', 'x', 'y']);
      expect(up.edges, ['yz', 'zx', 'xy']);
      final down = resolver.record('loop', 'y', 'y', direction: seqDown);
      expect(down.nodes, ['y', 'x', 'z', 'y']);
      expect(down.edges, ['xy', 'zx', 'yz']);
      expect(down.meters, 700);
    });

    test('같은 역을 방향과 함께 고르면 한 바퀴다', () {
      final result = resolver.record('loop', 'x', 'x', direction: seqUp);
      expect(result.meters, 700);
      expect(result.legs.single.lineId, 'm');
      expect(resolver.record('loop', 'x', 'x').reason, ExpandReason.sameNode);
    });
  });

  test('밟은 역은 꽉 찬 원이고 지나가기만 한 역은 뚫린 원이다', () {
    final marks = Network(
      const NetworkData(
        routes: [],
        edges: [],
        routeEdges: [],
        stops: [],
        attrs: [],
        lives: [],
        units: [],
        publicNodes: {'a', 'a2', 'b', 'c'},
        nodeGroups: {'a': 'ga', 'a2': 'ga', 'b': 'gb', 'c': 'gc'},
        groupNumbers: {'ga': 1, 'gb': 2, 'gc': 3},
      ),
    );
    final got = stationMarks(marks, alighted: const ['a'], visited: const ['c'], ridden: const ['a2', 'b', 'c']);
    expect(got.stepped, {1, 3});
    expect(got.passed, {2});
    // 환승역 승강장 노드는 노드 단위다. 같은 묶음의 a2는 지나가기만 했다 (DESIGN §7.5)
    expect(got.steppedNodes, {'a', 'c'});
    expect(got.passedNodes, {'a2', 'b'});
  });

  group('선택기', () {
    test('그날의 상태를 그린다', () {
      final rows = SelectorBuilder(network).build('r', day('2021-01-01'));
      final byNode = {for (final row in rows) row.node: row};
      expect(byNode['a']!.state, StopState.open);
      expect(byNode['c']!.state, StopState.suspended);
      expect(byNode['c']!.selectable, isFalse);
    });

    test('날짜를 모르면 있었던 역을 모두 고른다', () {
      final rows = SelectorBuilder(network).build('r', null);
      expect(rows.every((row) => row.selectable), isTrue);
    });

    test('기간 밖의 연결은 그리지 않는다', () {
      const link = SelectorLink(
        seq: 0,
        kind: 'transfer',
        otherLineId: 'm',
        otherRouteId: 'loop',
        validFromLo: '2000-01-01',
        validToHi: '2010-01-01',
      );
      List<SelectorLink> links(String date) =>
          SelectorBuilder(network).build('r', day(date), links: const [link]).first.links;
      expect(links('2005-01-01'), hasLength(1));
      expect(links('2010-01-01'), isEmpty);
      expect(links('1999-12-31'), isEmpty);
    });

    test('범위 날짜는 기간과 겹치면 연결을 그린다', () {
      const link = SelectorLink(
        seq: 0,
        kind: 'transfer',
        otherLineId: 'm',
        otherRouteId: 'loop',
        validFromLo: '2000-06-01',
        validToHi: '2010-01-01',
      );
      List<SelectorLink> links(String date) =>
          SelectorBuilder(network).build('r', day(date), links: const [link]).first.links;
      expect(links('2000-XX-XX'), hasLength(1));
      expect(links('1999-XX-XX'), isEmpty);
      expect(links('2010-XX-XX'), isEmpty);
    });
  });

  group('이관', () {
    NetAttr member(String edge, String line, NetPeriod period) => NetAttr(
          edgeId: edge,
          lineId: line,
          operatorId: line,
          lineageId: 'lg',
          carryoverGroup: line,
          period: period,
        );

    const untilMove = NetPeriod(
      fromLo: '1900-01-01',
      fromHi: '1900-01-01',
      toLo: '2000-06-01',
      toHi: '2000-06-01',
    );
    const sinceMove = NetPeriod(
      fromLo: '2000-06-01',
      fromHi: '2000-06-01',
      toLo: DateSpan.maxDate,
      toHi: DateSpan.maxDate,
    );

    Network moved() => Network(
          NetworkData(
            routes: const [
              NetRoute(
                id: 'old',
                lineId: 'before',
                role: 'main',
                fromNode: 'p',
                toNode: 'q',
                closed: false,
              ),
            ],
            edges: const [NetEdge(id: 'pq', n: 1, from: 'p', to: 'q', meters: 100)],
            routeEdges: const [NetRouteEdge(routeId: 'old', seq: 0, edgeId: 'pq')],
            stops: [stop('old', 0, 'p'), stop('old', 1, 'q')],
            attrs: [
              member('pq', 'before', untilMove),
              member('pq', 'after', sinceMove),
            ],
            lives: [life('pq')],
            units: const [],
            publicNodes: const {'p', 'q'},
            nodeGroups: const {},
          ),
        );

    test('이관 날짜에 걸친 범위 날짜는 입력한 노선을 유지한다', () {
      final result = RouteResolver(moved()).record('old', 'p', 'q', date: day('2000-XX-XX'));
      expect(result.legs.single.lineId, 'before');
    });

    test('선택기 제목은 그날의 노선을 따른다', () {
      final network = moved();
      expect(network.lineOnDate('old', day('1990-01-01')), 'before');
      expect(network.lineOnDate('old', day('2005-01-01')), 'after');
      expect(network.lineOnDate('old', null), 'before');
    });

    test('이관 뒤로 정해진 날짜는 그날의 노선이다', () {
      final result = RouteResolver(moved()).record('old', 'p', 'q', date: day('2001-XX-XX'));
      expect(result.legs.single.lineId, 'after');
      final exact = RouteResolver(moved()).record('old', 'p', 'q', date: day('2005-03-01'));
      expect(exact.legs.single.lineId, 'after');
    });
  });

  group('해석', () {
    Ride ride({String? date, String from = 'b', String to = 'c', int created = 0}) => Ride(
          rideId: const RideId('r'),
          datasetVersion: 'e',
          createdAt: created,
          updatedAt: 1,
          deviceId: 'd',
          dateInput: date,
          legs: [
            RideLeg(
              seq: 0,
              lineId: const LineId('l'),
              routeId: const RouteId('r'),
              fromNode: NodeId(from),
              toNode: NodeId(to),
              lineLabel: '',
              fromLabel: '',
              toLabel: '',
            ),
          ],
        );

    test('원본에서 캐시 값을 만든다', () {
      final derived = RideInterpreter(network).ride(ride(date: '2010-01-01', from: 'a'));
      expect(derived.status, ResolveStatus.ok);
      expect(derived.km10, 17);
      expect(derived.date, '2010-01-01');
      expect(derived.effectiveHi, '2010-01-01');
      expect(derived.edges.map((e) => e.edge), [2, 3]);
      expect(derived.edges.map((e) => e.unitOn), [2, 3]);
      expect(derived.nodes.first.role, NodeRole.alighted);
    });

    test('그날 탈 수 없는 날짜를 가리고 기준일 이전은 기록 범위 밖이라 가리지 않는다', () {
      final interpreter = RideInterpreter(network);
      // b-c는 2020년부터 운휴다 (DESIGN §2.8 J)
      expect(interpreter.unridable(ride(date: '2021-01-01')), isTrue);
      expect(interpreter.unridable(ride(date: '2010-01-01')), isFalse);
      // 범위 날짜는 영업 기간과 겹치면 탈 수 있다
      expect(interpreter.unridable(ride(date: '2019-XX-XX')), isFalse);
      expect(interpreter.unridable(ride(date: '201X-XX-XX')), isFalse);
      expect(interpreter.unridable(ride(date: '1949-12-31')), isFalse);
      expect(interpreter.unridable(ride()), isFalse);
      // 재해석은 묻지 않고 날짜 모름으로 둔다
      expect(interpreter.ride(ride(date: '2021-01-01')).date, isNull);
    });

    test('방향 없는 닫힌 계통은 재해석에서 답을 기다리고 모름은 공통 구간만 준다', () {
      Ride ride({bool unknown = false, String? direction}) => Ride(
            rideId: const RideId('r'),
            datasetVersion: 'e',
            createdAt: 0,
            updatedAt: 1,
            deviceId: 'd',
            legs: [
              RideLeg(
                seq: 0,
                lineId: const LineId('m'),
                routeId: const RouteId('loop'),
                fromNode: const NodeId('x'),
                toNode: const NodeId('y'),
                direction: direction,
                resolveUnknown: unknown,
                lineLabel: '',
                fromLabel: '',
                toLabel: '',
              ),
            ],
          );
      final interpreter = RideInterpreter(network);
      final open = interpreter.ride(ride());
      expect(open.status, ResolveStatus.needsInput);
      final waiting = interpreter.expansions(ride()).single;
      expect(waiting.distances, hasLength(2));
      expect(waiting.pendingMeters, greaterThan(0));
      final unknown = interpreter.ride(ride(unknown: true));
      expect(unknown.status, ResolveStatus.partial);
      expect(interpreter.expansions(ride(unknown: true)).single.edges, isEmpty);
      expect(interpreter.ride(ride().answered((_) => true, direction: seqUp)).status, ResolveStatus.ok);
      expect(RouteResolver(network).record('loop', 'x', 'y').status, ResolveStatus.ok, reason: '저장 전 미리 보기는 짧은 쪽이다');
    });

    test('leg 경계는 지나간 역이고 갈아탄 역만 내린 역이다', () {
      RideLeg leg(int seq, String from, String to) => RideLeg(
            seq: seq,
            lineId: const LineId('m'),
            routeId: const RouteId('loop'),
            fromNode: NodeId(from),
            toNode: NodeId(to),
            direction: seqUp,
            lineLabel: '',
            fromLabel: '',
            toLabel: '',
          );
      Ride through({List<NodeId> transfers = const []}) => Ride(
            rideId: const RideId('r'),
            datasetVersion: 'e',
            createdAt: 0,
            updatedAt: 1,
            deviceId: 'd',
            transferNodes: transfers,
            legs: [leg(0, 'x', 'y'), leg(1, 'y', 'z')],
          );
      Map<String, NodeRole> roles(Ride ride) => {
            for (final hit in RideInterpreter(network).ride(ride).nodes) hit.node.value: hit.role,
          };
      expect(roles(through()), {
        'x': NodeRole.alighted,
        'y': NodeRole.passed,
        'z': NodeRole.alighted,
      });
      expect(roles(through(transfers: const [NodeId('y')]))['y'], NodeRole.alighted);
    });

    test('내린 역이 그날 없으면 날짜 모름이고 입력은 남는다', () {
      final closed = Network(
        NetworkData(
          routes: const [
            NetRoute(
              id: 't',
              lineId: 'l',
              role: 'main',
              fromNode: 'p',
              toNode: 'q',
              closed: false,
            ),
          ],
          edges: const [NetEdge(id: 'pq', n: 1, from: 'p', to: 'q', meters: 100)],
          routeEdges: const [NetRouteEdge(routeId: 't', seq: 0, edgeId: 'pq')],
          stops: [stop('t', 0, 'p'), stop('t', 1, 'q', period: before2000)],
          attrs: [attr('pq', 'l')],
          lives: [life('pq')],
          units: const [],
          publicNodes: const {'p', 'q'},
          nodeGroups: const {},
        ),
      );
      final created = DateTime.utc(2024, 5, 1).millisecondsSinceEpoch;
      Ride on(String date) => Ride(
            rideId: const RideId('r'),
            datasetVersion: 'e',
            createdAt: created,
            updatedAt: 1,
            deviceId: 'd',
            dateInput: date,
            legs: const [
              RideLeg(
                seq: 0,
                lineId: LineId('l'),
                routeId: RouteId('t'),
                fromNode: NodeId('p'),
                toNode: NodeId('q'),
                lineLabel: '',
                fromLabel: '',
                toLabel: '',
              ),
            ],
          );
      final late = RideInterpreter(closed).ride(on('2010-01-01'));
      expect(late.date, isNull);
      expect(late.effectiveLo, isNull);
      expect(late.effectiveHi, '1999-12-31');
      final early = RideInterpreter(closed).ride(on('1990-01-01'));
      expect(early.date, '1990-01-01');
      // 저장과 날짜 수정은 정차하지 않는 역을 막는다. 범위 날짜에서 유효 범위가 비어도 같다
      expect(RideInterpreter(closed).unridable(on('2010-01-01')), isTrue);
      expect(RideInterpreter(closed).unridable(on('200X-XX-XX')), isTrue);
      expect(RideInterpreter(closed).unridable(on('199X-XX-XX')), isFalse);
      expect(RideInterpreter(closed).unridable(on('1990-01-01')), isFalse);
    });

    test('정차 기간이 둘인 역은 그 사이 날짜에 서지 않는다 (印場 1905~1944·1995~)', () {
      final twice = Network(
        NetworkData(
          routes: const [
            NetRoute(id: 't', lineId: 'l', role: 'main', fromNode: 'p', toNode: 'q', closed: false),
          ],
          edges: const [NetEdge(id: 'pq', n: 1, from: 'p', to: 'q', meters: 100)],
          routeEdges: const [NetRouteEdge(routeId: 't', seq: 0, edgeId: 'pq')],
          stops: [
            stop('t', 0, 'p'),
            const NetStop(
              routeId: 't',
              seq: 1,
              node: 'q',
              kmCum: null,
              isStop: true,
              
              period: ongoing,
              gaps: [NetPeriod(fromLo: '1944-01-01', fromHi: '1944-12-31', toLo: '1995-12-22', toHi: '1995-12-22')],
            ),
          ],
          attrs: [attr('pq', 'l')],
          lives: [life('pq')],
          units: const [],
          publicNodes: const {'p', 'q'},
          nodeGroups: const {},
        ),
      );
      Ride on(String date) => Ride(
            rideId: const RideId('r'),
            datasetVersion: 'e',
            createdAt: 0,
            updatedAt: 1,
            deviceId: 'd',
            dateInput: date,
            legs: const [
              RideLeg(
                seq: 0,
                lineId: LineId('l'),
                routeId: RouteId('t'),
                fromNode: NodeId('p'),
                toNode: NodeId('q'),
                lineLabel: '',
                fromLabel: '',
                toLabel: '',
              ),
            ],
          );
      final interpreter = RideInterpreter(twice);
      expect(interpreter.unridable(on('1970-05-01')), isTrue);
      expect(interpreter.unridable(on('1996-01-01')), isFalse);
      // 쉬기 시작한 해만 알면 그 해 안의 날짜는 막지 않는다
      expect(interpreter.unridable(on('1944-06-01')), isFalse);
      expect(interpreter.unridable(on('197X-XX-XX')), isTrue);
      expect(interpreter.unridable(on('199X-XX-XX')), isFalse);
      // 이 시험의 印場는 계통 끝이라, 서지 않는 날에는 승하차 불가 끝 노드(가운데 회색, 고를 수 있음)다 (5번 결정 junction-nodes-rule, 2026-11-19).
      // 실제 印場처럼 중간 역이면 고를 수 없는 폐역이다
      final rows = SelectorBuilder(twice).build('t', DateSpan.parse('1970-05-01'));
      expect(rows.last.passing, isTrue);
      expect(rows.last.selectable, isTrue);
    });

    test('분모 밖 구간은 저장 전 값에 나오지 않는다', () {
      final outside = Network(
        NetworkData(
          routes: const [
            NetRoute(
              id: 't',
              lineId: 'l',
              role: 'main',
              fromNode: 'p',
              toNode: 'q',
              closed: false,
            ),
          ],
          edges: const [NetEdge(id: 'pq', n: 1, from: 'p', to: 'q', meters: 100)],
          routeEdges: const [NetRouteEdge(routeId: 't', seq: 0, edgeId: 'pq')],
          stops: [stop('t', 0, 'p'), stop('t', 1, 'q')],
          attrs: [attr('pq', 'l')],
          lives: [life('pq')],
          units: const [
            NetUnit(
              n: 1,
              key: 'lg-l:pq',
              carryover: true,
              edgeId: 'pq',
              meters: 100,
              normal: false,
              dateLo: '1900-01-01',
              dateHi: DateSpan.maxDate,
            ),
          ],
          publicNodes: const {'p', 'q'},
          nodeGroups: const {},
        ),
      );
      final expansion = RouteResolver(outside).record('t', 'p', 'q');
      final preview = previewRide(
        outside,
        lineIds: ['l'],
        expansions: [expansion],
        hits: const {},
        today: '2026-11-02',
      );
      expect(preview.newMeters, 0);
    });

    test('날짜 모름 기록은 이번 달 km에 들지 않는다', () {
      const since = '2026-11-01';
      final hits = {3: '2026-11-02'};
      expect(newMetersSince(network, hits: hits, since: since, today: '2026-11-02'), 500);
      expect(
        newMetersSince(network, hits: hits, since: since, today: '2026-11-02', undated: const {3}),
        0,
      );
    });

    test('없는 계통은 버리지 않고 확인 필요로 둔다', () {
      const lost = Ride(
        rideId: RideId('r'),
        datasetVersion: 'e',
        createdAt: 0,
        updatedAt: 1,
        deviceId: 'd',
        legs: [
          RideLeg(
            seq: 0,
            lineId: LineId('사라짐'),
            routeId: RouteId('사라짐'),
            fromNode: NodeId('a'),
            toNode: NodeId('b'),
            lineLabel: '',
            fromLabel: '',
            toLabel: '',
          ),
        ],
      );
      expect(RideInterpreter(network).ride(lost).status, ResolveStatus.unknownRef);
    });

    test('있는 계통이라도 판에 없는 역이면 확인 필요다', () {
      final route = network.routes.values.first;
      final known = network.stops(route.id).first.node;
      final resolver = RouteResolver(network);
      expect(resolver.expand(route.id, known, '사라진 역').status, ResolveStatus.unknownRef);
      final other = network.stops(route.id).last.node;
      expect(resolver.expand(route.id, known, other).status, isNot(ResolveStatus.unknownRef));
    });

    test('날짜가 없는 기록은 등록일이 유효 범위의 끝이다', () {
      final created = DateTime.utc(2024, 5, 1).millisecondsSinceEpoch;
      final derived = RideInterpreter(network).ride(ride(created: created));
      expect(derived.date, isNull);
      expect(derived.effectiveHi, '2024-05-01');
    });

    test('방문은 묶음을 찾는다', () {
      const visit = Visit(
        visitId: VisitId('v'),
        nodeId: NodeId('a'),
        nodeLabel: 'A',
        nodeExplicit: true,
        createdAt: 0,
        updatedAt: 1,
        deviceId: 'd',
        dateInput: '1949-12-31',
      );
      final derived = RideInterpreter(network).visit(visit);
      expect(derived.groupId, 'g-a');
      expect(derived.date, isNull);
    });
  });
}
