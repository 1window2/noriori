import 'package:noriori_core/noriori_core.dart';
import 'package:test/test.dart';

const ongoing = NetPeriod(
  fromLo: '1900-01-01',
  fromHi: '1900-01-01',
  toLo: DateSpan.maxDate,
  toHi: DateSpan.maxDate,
);

NetStop stop(String routeId, int seq, String node, {bool shown = true}) => NetStop(
      routeId: routeId,
      seq: seq,
      node: node,
      kmCum: seq.toDouble(),
      isStop: shown,
      
      period: ongoing,
    );

NetAttr attr(String edge, String line, {NetPeriod period = ongoing}) => NetAttr(
      edgeId: edge,
      lineId: line,
      operatorId: 'o',
      lineageId: 'lg-$line',
      carryoverGroup: 'c-$line',
      period: period,
    );

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

/// 곧은 노선 a-b-h-c-d. h는 숨은 분기점이고 m 노선이 h-p로 이어진다.
/// 고리 x-y-z는 닫힌 계통이다.
Network sample() {
  const edges = {
    'ab': ('a', 'b', 1),
    'bh': ('b', 'h', 2),
    'hc': ('h', 'c', 3),
    'cd': ('c', 'd', 4),
    'hp': ('h', 'p', 5),
    'xy': ('x', 'y', 6),
    'yz': ('y', 'z', 7),
    'zx': ('z', 'x', 8),
  };
  final lineOf = {
    for (final e in ['ab', 'bh', 'hc', 'cd']) e: 'l',
    'hp': 'm',
    for (final e in ['xy', 'yz', 'zx']) e: 'r',
  };
  return Network(
    NetworkData(
      routes: const [
        NetRoute(id: 'rl', lineId: 'l', role: 'main', fromNode: 'a', toNode: 'd', closed: false),
        NetRoute(id: 'rm', lineId: 'm', role: 'main', fromNode: 'h', toNode: 'p', closed: false),
        NetRoute(id: 'rr', lineId: 'r', role: 'main', fromNode: 'x', toNode: 'x', closed: true),
      ],
      edges: [
        for (final MapEntry(:key, :value) in edges.entries)
          NetEdge(id: key, n: value.$3, from: value.$1, to: value.$2, meters: value.$3 * 1000),
      ],
      routeEdges: const [
        NetRouteEdge(routeId: 'rl', seq: 1, edgeId: 'ab'),
        NetRouteEdge(routeId: 'rl', seq: 2, edgeId: 'bh'),
        NetRouteEdge(routeId: 'rl', seq: 3, edgeId: 'hc'),
        NetRouteEdge(routeId: 'rl', seq: 4, edgeId: 'cd'),
        NetRouteEdge(routeId: 'rm', seq: 1, edgeId: 'hp'),
        NetRouteEdge(routeId: 'rr', seq: 1, edgeId: 'xy'),
        NetRouteEdge(routeId: 'rr', seq: 2, edgeId: 'yz'),
        NetRouteEdge(routeId: 'rr', seq: 3, edgeId: 'zx'),
      ],
      stops: [
        stop('rl', 1, 'a'),
        stop('rl', 2, 'b'),
        stop('rl', 3, 'h', shown: false),
        stop('rl', 4, 'c'),
        stop('rl', 5, 'd'),
        stop('rm', 1, 'h', shown: false),
        stop('rm', 2, 'p'),
        stop('rr', 1, 'x'),
        stop('rr', 2, 'y'),
        stop('rr', 3, 'z'),
        stop('rr', 4, 'x'),
      ],
      attrs: [for (final MapEntry(:key, :value) in lineOf.entries) attr(key, value)],
      lives: [for (final e in edges.keys) NetLife(edgeId: e, suspended: false, period: ongoing)],
      units: [
        for (final MapEntry(:key, :value) in edges.entries)
          unit(value.$3, key, lineOf[key]!, value.$3 * 1000),
      ],
      publicNodes: const {'a', 'b', 'c', 'd', 'p', 'x', 'y', 'z'},
      nodeGroups: const {},
    ),
  );
}

NetPeriod between(String from, String to) => NetPeriod(fromLo: from, fromHi: from, toLo: to, toHi: to);

/// 열린 노선 e-f-g-k. f-g는 1970년에 옛 역 o를 거치던 선로에서 옮겼고, e-f는 1980년에 열었다.
/// 날짜 없는 e→k는 e-f와 함께 있던 날이 있는 새 선로 하나로 펼쳐진다 (中央本線 田立과 みどり湖의 모양).
Network relocated() {
  const edges = {
    'ef': ('e', 'f', 11, '1980-01-01', DateSpan.maxDate),
    'fg': ('f', 'g', 12, '1970-01-01', DateSpan.maxDate),
    'fo': ('f', 'o', 13, '1955-01-01', '1970-01-01'),
    'og': ('o', 'g', 14, '1955-01-01', '1970-01-01'),
    'gk': ('g', 'k', 15, '1955-01-01', DateSpan.maxDate),
  };
  return Network(
    NetworkData(
      routes: const [
        NetRoute(id: 'rv', lineId: 'v', role: 'main', fromNode: 'e', toNode: 'k', closed: false),
      ],
      edges: [
        for (final MapEntry(:key, :value) in edges.entries)
          NetEdge(id: key, n: value.$3, from: value.$1, to: value.$2, meters: 1000),
      ],
      routeEdges: [
        for (final (seq, edge) in edges.keys.indexed) NetRouteEdge(routeId: 'rv', seq: seq + 1, edgeId: edge),
      ],
      stops: [for (final (seq, node) in ['e', 'f', 'o', 'g', 'k'].indexed) stop('rv', seq + 1, node)],
      attrs: [
        for (final MapEntry(:key, :value) in edges.entries) attr(key, 'v', period: between(value.$4, value.$5)),
      ],
      lives: [
        for (final MapEntry(:key, :value) in edges.entries)
          NetLife(edgeId: key, suspended: false, period: between(value.$4, value.$5)),
      ],
      units: [
        for (final MapEntry(:key, :value) in edges.entries) unit(value.$3, key, 'v', 1000),
      ],
      publicNodes: const {'e', 'f', 'o', 'g', 'k'},
      nodeGroups: const {},
    ),
  );
}

RideLeg leg(int seq, String route, String line, String from, String to, {String? direction}) => RideLeg(
      seq: seq,
      lineId: LineId(line),
      routeId: RouteId(route),
      fromNode: NodeId(from),
      toNode: NodeId(to),
      direction: direction,
      lineLabel: line,
      fromLabel: from.toUpperCase(),
      toLabel: to.toUpperCase(),
    );

Ride ride(List<RideLeg> legs, {String? date, List<String> transfers = const []}) => Ride(
      rideId: const RideId('ride'),
      legs: legs,
      datasetVersion: 'v1',
      createdAt: 100,
      updatedAt: 100,
      deviceId: 'dev',
      tripId: const TripId('trip'),
      dateInput: date,
      times: '09:00',
      trainName: '열차',
      carNo: '3',
      note: '메모',
      importSource: 'file.csv',
      importRaw: 'raw',
      transferNodes: [for (final node in transfers) NodeId(node)],
    );

CutOutcome cut(Network network, Ride target, Set<int> units) {
  var next = 0;
  return cutSection(
    target,
    network,
    offUnits: units,
    carryover: true,
    nameOf: (node) => node.toUpperCase(),
    newId: () => 'new-${next++}',
    now: 500,
  );
}

void main() {
  final network = sample();

  test('가운데를 끄면 앞뒤 조각과 삭제 표시 조각이 남는다', () {
    final done = cut(network, ride([leg(0, 'rl', 'l', 'a', 'd')], date: '2020-01-02'), {3, 2}) as CutDone;
    expect([for (final r in done.after) r.rideId.value], ['ride', 'new-0', 'new-1']);
    final [front, off, back] = done.after;
    expect((front.legs.single.fromNode.value, front.legs.single.toNode.value), ('a', 'b'));
    expect((back.legs.single.fromNode.value, back.legs.single.toNode.value), ('c', 'd'));
    expect((off.legs.single.fromNode.value, off.legs.single.toNode.value), ('b', 'c'));
    expect(front.isDeleted, isFalse);
    expect(back.isDeleted, isFalse);
    expect(off.deletedAt, 500);
  });

  test('경로 외 열은 전부 복사하고 잘린 끝만 통과가 된다', () {
    final done = cut(network, ride([leg(0, 'rl', 'l', 'a', 'd')], date: '2020-01-02'), {2, 3}) as CutDone;
    final [front, off, back] = done.after;
    for (final piece in done.after) {
      expect(piece.dateInput, '2020-01-02');
      expect(piece.createdAt, 100);
      expect(piece.tripId?.value, 'trip');
      expect(piece.times, '09:00');
      expect(piece.trainName, '열차');
      expect(piece.carNo, '3');
      expect(piece.note, '메모');
      expect(piece.importSource, 'file.csv');
      expect(piece.importRaw, 'raw');
      expect(piece.deviceId, 'dev');
      expect(piece.updatedAt, 500);
    }
    expect((front.fromAlighted, front.toAlighted), (true, false));
    expect((off.fromAlighted, off.toAlighted), (false, false));
    expect((back.fromAlighted, back.toAlighted), (false, true));
  });

  test('갈아탄 역은 그 조각의 경로 안에 있을 때만 남는다', () {
    final done = cut(
      network,
      ride([leg(0, 'rl', 'l', 'a', 'b'), leg(1, 'rl', 'l', 'b', 'd')], transfers: ['b']),
      {4},
    ) as CutDone;
    final [front, off] = done.after;
    expect(front.transferNodes, [const NodeId('b')]);
    expect(off.transferNodes, isEmpty);
    expect(front.legs.length, 2);
    expect(front.legs.last.seq, 1);
  });

  test('끝을 끄면 조각이 하나고 원래 ID를 지킨다', () {
    final done = cut(network, ride([leg(0, 'rl', 'l', 'a', 'd')]), {4}) as CutDone;
    final [front, off] = done.after;
    expect(front.rideId.value, 'ride');
    expect(off.isDeleted, isTrue);
    expect((front.fromAlighted, front.toAlighted), (true, false));
    expect((off.fromAlighted, off.toAlighted), (false, true));
  });

  test('맨 앞을 꺼도 남는 조각이 원래 ID다', () {
    final done = cut(network, ride([leg(0, 'rl', 'l', 'a', 'd')]), {1}) as CutDone;
    final [off, rest] = done.after;
    expect(off.isDeleted, isTrue);
    expect(off.rideId.value, 'new-0');
    expect(rest.rideId.value, 'ride');
  });

  test('전부 끄면 원래 기록의 삭제 표시 하나다', () {
    final done = cut(network, ride([leg(0, 'rl', 'l', 'a', 'b')]), {1}) as CutDone;
    expect(done.after.single.rideId.value, 'ride');
    expect(done.after.single.isDeleted, isTrue);
  });

  test('지나지 않는 기록은 그대로 둔다', () {
    expect(cut(network, ride([leg(0, 'rl', 'l', 'a', 'b')]), {4}), isA<CutMissed>());
  });

  test('숨은 노드에서 끊어야 하면 막는다', () {
    final outcome = cut(
      network,
      ride([leg(0, 'rl', 'l', 'b', 'h'), leg(1, 'rm', 'm', 'h', 'p')]),
      {2},
    );
    expect(outcome, isA<CutBlocked>());
    expect((outcome as CutBlocked).reason, CutBlock.hiddenNode);
  });

  test('순환 한 바퀴를 자른 조각은 같은 방향으로 다시 펼쳐진다', () {
    final done = cut(
      network,
      ride([leg(0, 'rr', 'r', 'x', 'x', direction: seqDown)]),
      {7},
    ) as CutDone;
    final interpreter = RideInterpreter(network);
    final kept = [for (final r in done.after) if (!r.isDeleted) r];
    final edges = {for (final r in kept) for (final hit in interpreter.ride(r).edges) hit.edge};
    expect(edges, {6, 8});
  });

  test('노선도는 숨은 노드를 건너 표시 역끼리 구간을 만든다', () {
    final diagram = lineDiagram(network, 'l', hits: const {2: null}, today: '2026-01-01');
    final route = diagram.routes.single;
    expect([for (final s in route.stops) s.node], ['a', 'b', 'c', 'd']);
    expect([for (final s in route.sections) s.units], [{1}, {2, 3}, {4}]);
    expect([for (final s in route.sections) s.ridden], [false, true, false]);
    expect(route.current.numMeters, 2000);
    expect(route.current.denMeters, 10000);
  });

  test('이어진 구간은 하나로 합치고 떨어진 구간은 둔다', () {
    final route = lineDiagram(network, 'l', hits: const {}, today: '2026-01-01').routes.single;
    final joined = joinSections([route.sections[0], route.sections[1]]);
    expect(joined.single.units, {1, 2, 3});
    expect((joined.single.from, joined.single.to), ('a', 'c'));
    expect(joinSections([route.sections[0], route.sections[2]]).length, 2);
  });

  test('켜기는 같은 구간의 가장 최근 삭제 조각을 고른다', () {
    Ride deleted(String id, int at, String from, String to) => ride([leg(0, 'rl', 'l', from, to)])
        .piece(
          id: RideId(id),
          legs: [leg(0, 'rl', 'l', from, to)],
          transferNodes: const [],
          fromAlighted: false,
          toAlighted: false,
          updatedAt: at,
          deletedAt: at,
        );
    final found = restorableRide(
      [deleted('old', 10, 'c', 'd'), deleted('new', 20, 'c', 'd'), deleted('other', 30, 'a', 'b')],
      {4},
      network: network,
    );
    expect(found?.rideId.value, 'new');
  });

  test('되살릴 조각이 없으면 날짜 없는 기록을 만들고 끝은 통과다', () {
    final route = lineDiagram(network, 'l', hits: const {}, today: '2026-01-01').routes.single;
    final made = sectionRide(
      network,
      route.sections[1],
      id: const RideId('made'),
      lineLabel: 'L',
      fromLabel: 'B',
      toLabel: 'C',
      datasetVersion: 'v1',
      deviceId: 'dev',
      now: 500,
    )!;
    expect(made.dateInput, isNull);
    expect((made.fromAlighted, made.toAlighted), (false, false));
    expect({for (final hit in RideInterpreter(network).ride(made).edges) hit.edge}, {2, 3});
  });

  test('단독 보기는 그 노선 크레딧으로만 탄 구간을 고른다', () {
    final diagram = lineDiagram(network, 'l', hits: const {2: null, 5: null}, today: '2026-01-01');
    final solo = soloLine(network, diagram, hits: const {2: null, 5: null});
    expect(solo.edges, {1, 2, 3, 4});
    expect(solo.ridden, {2}, reason: 'm 노선의 구간은 들지 않는다');
    expect(solo.nodes, {'a', 'b', 'c', 'd'});
  });

  test('날짜 없는 기록의 조각은 원래 지난 이설 선형을 날짜로 지킨다', () {
    final moved = relocated();
    final interpreter = RideInterpreter(moved);
    final whole = ride([leg(0, 'rv', 'v', 'e', 'k')]);
    expect({for (final hit in interpreter.ride(whole).edges) hit.edge}, {11, 12, 15});
    // e-f를 끄면 f→k는 옛·새 선형이 둘 다 남는다. 새 선형을 고른 날로 적는다
    final done = cut(moved, whole, {11}) as CutDone;
    final kept = done.after.singleWhere((r) => !r.isDeleted);
    expect(kept.legs.single.resolveAsOf, '1970-01-01');
    expect({for (final hit in interpreter.ride(kept).edges) hit.edge}, {12, 15});
    // 선형이 하나로 남는 조각은 답을 적지 않는다
    final front = (cut(moved, whole, {15}) as CutDone).after.singleWhere((r) => !r.isDeleted);
    expect(front.legs.single.resolveAsOf, isNull);
    expect({for (final hit in interpreter.ride(front).edges) hit.edge}, {11, 12});
  });
}
