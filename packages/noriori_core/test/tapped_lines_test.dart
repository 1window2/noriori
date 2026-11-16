import 'package:noriori_core/noriori_core.dart';
import 'package:test/test.dart';

const today = '2026-11-05';

NetPeriod span(String from, String to) =>
    NetPeriod(fromLo: from, fromHi: from, toLo: to, toHi: to);

NetAttr attr(String edge, String line, NetPeriod period, {String? lineage}) => NetAttr(
      edgeId: edge,
      lineId: line,
      operatorId: 'o',
      lineageId: lineage ?? 'lg-$line',
      carryoverGroup: 'c-$line',
      period: period,
    );

NetEdge edge(String id, int n) => NetEdge(id: id, n: n, from: '$id-a', to: '$id-b', meters: 100);

/// e1은 현행 a와 b가 함께 지나고 일부 폐지 노선 c의 폐지 구간도 겹친다. c는 e2에서 영업 중이다.
/// e3은 전체 폐선 d의 구간이고 e4는 신에츠 본선(s)에서 시나노 철도(t)로 넘어간 구간이다.
/// s는 e5에서 아직 영업 중이다. 팩의 노선 순서는 b가 a보다 앞이다.
final network = Network(
  NetworkData(
    routes: const [],
    edges: [edge('e1', 1), edge('e2', 2), edge('e3', 3), edge('e4', 4), edge('e5', 5)],
    routeEdges: const [],
    stops: const [],
    attrs: [
      attr('e1', 'a', span('1900-01-01', DateSpan.maxDate)),
      attr('e1', 'c', span('1900-01-01', '1990-01-01')),
      attr('e1', 'b', span('1950-01-01', DateSpan.maxDate)),
      attr('e2', 'c', span('1900-01-01', DateSpan.maxDate)),
      attr('e3', 'd', span('1900-01-01', '1980-01-01')),
      attr('e4', 's', span('1900-01-01', '1997-10-01'), lineage: 'lg-s'),
      attr('e4', 't', span('1997-10-01', DateSpan.maxDate), lineage: 'lg-s'),
      attr('e5', 's', span('1900-01-01', DateSpan.maxDate)),
    ],
    lives: const [],
    units: const [],
    publicNodes: const {},
    nodeGroups: const {},
    lineOrder: const ['b', 'a', 'c', 'd', 's', 't'],
  ),
);

void main() {
  stationTests();
  test('같은 선로를 지나는 노선은 현행이 먼저이고 같은 갈래는 팩 순서다', () {
    expect(tappedLines(network, [1], today: today), const [
      TappedLine(lineId: 'b', kind: TappedLineKind.current),
      TappedLine(lineId: 'a', kind: TappedLineKind.current),
      TappedLine(lineId: 'c', kind: TappedLineKind.partlyClosed),
    ]);
  });

  test('손가락 범위의 선로 여럿을 모으고 현행, 일부 폐지, 전체 폐선 순으로 둔다', () {
    expect(tappedLines(network, [3, 1], today: today).map((row) => (row.lineId, row.kind)), [
      ('b', TappedLineKind.current),
      ('a', TappedLineKind.current),
      ('c', TappedLineKind.partlyClosed),
      ('d', TappedLineKind.closed),
    ]);
  });

  test('누른 구간 중 하나에서라도 영업 중이면 현행이다', () {
    expect(tappedLines(network, [1, 2], today: today).map((row) => row.kind), [
      TappedLineKind.current,
      TappedLineKind.current,
      TappedLineKind.current,
    ]);
  });

  test('승계로 넘어간 옛 노선도 줄이 되고 폐선 쪽에 선다', () {
    expect(tappedLines(network, [4], today: today), const [
      TappedLine(lineId: 't', kind: TappedLineKind.current),
      TappedLine(lineId: 's', kind: TappedLineKind.partlyClosed),
    ]);
  });

  test('판정은 오늘 기준이다', () {
    expect(tappedLines(network, [3], today: '1970-01-01'), const [
      TappedLine(lineId: 'd', kind: TappedLineKind.current),
    ]);
    expect(tappedLines(network, [3], today: today), const [
      TappedLine(lineId: 'd', kind: TappedLineKind.closed),
    ]);
  });

  test('모르는 번호나 빈 입력은 빈 목록이다', () {
    expect(tappedLines(network, [99], today: today), isEmpty);
    expect(tappedLines(network, const [], today: today), isEmpty);
  });
}

/// 승강장 노드 x는 노선 p(현행)와 q(폐선)가 정차하고, y는 노선 r만 정차한다 (DESIGN §7.5).
final station = Network(
  NetworkData(
    routes: const [
      NetRoute(id: 'rp', lineId: 'p', role: 'main', fromNode: 'x', toNode: 'u', closed: false, extendTo: []),
      NetRoute(id: 'rq', lineId: 'q', role: 'main', fromNode: 'x', toNode: 'v', closed: true, extendTo: []),
      NetRoute(id: 'rr', lineId: 'r', role: 'main', fromNode: 'y', toNode: 'w', closed: false, extendTo: []),
    ],
    edges: const [
      NetEdge(id: 'ep', n: 11, from: 'x', to: 'u', meters: 100),
      NetEdge(id: 'eq', n: 12, from: 'x', to: 'v', meters: 100),
      NetEdge(id: 'er', n: 13, from: 'y', to: 'w', meters: 100),
    ],
    routeEdges: const [],
    stops: [
      for (final (route, node) in const [('rp', 'x'), ('rq', 'x'), ('rr', 'y')])
        NetStop(routeId: route, seq: 0, node: node, kmCum: 0, isStop: true, isExtension: false, period: span('1900-01-01', DateSpan.maxDate)),
    ],
    attrs: [
      attr('ep', 'p', span('1900-01-01', DateSpan.maxDate)),
      attr('eq', 'q', span('1900-01-01', '1970-01-01')),
      attr('er', 'r', span('1900-01-01', DateSpan.maxDate)),
    ],
    lives: const [],
    units: const [],
    publicNodes: const {'x', 'y'},
    nodeGroups: const {},
    lineOrder: const ['p', 'q', 'r'],
  ),
);

void stationTests() {
  test('승강장 노드는 그 자리에 정차하는 노선을 현행, 폐선 순으로 모은다', () {
    expect(stationLines(station, ['x'], today: today), const [
      TappedLine(lineId: 'p', kind: TappedLineKind.current),
      TappedLine(lineId: 'q', kind: TappedLineKind.closed),
    ]);
  });

  test('통합 노드는 역의 모든 승강장 노드의 노선이다', () {
    expect(stationLines(station, ['x', 'y'], today: today).map((row) => row.lineId), ['p', 'r', 'q']);
  });

  test('노선별로 나뉜 승강장은 그 노선만 남긴다', () {
    expect(stationLines(station, ['x'], only: {'q'}, today: today).map((row) => row.lineId), ['q']);
  });
}
