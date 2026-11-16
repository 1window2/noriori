import 'package:noriori_core/noriori_core.dart';
import 'package:test/test.dart';

const ongoing = NetPeriod(
  fromLo: '1900-01-01',
  fromHi: '1900-01-01',
  toLo: DateSpan.maxDate,
  toHi: DateSpan.maxDate,
);

NetStop _stop(String routeId, int seq, String node) => NetStop(
      routeId: routeId,
      seq: seq,
      node: node,
      kmCum: null,
      isStop: true,
      isExtension: false,
      period: ongoing,
    );

NetAttr _attr(String edge, String line) => NetAttr(
      edgeId: edge,
      lineId: line,
      operatorId: 'o',
      lineageId: 'lg-$line',
      carryoverGroup: 'c-$line',
      period: ongoing,
    );

NetUnit _unit(int n, String edge, String line, int meters) => NetUnit(
      n: n,
      key: 'lg-$line:$edge',
      carryover: true,
      edgeId: edge,
      meters: meters,
      normal: true,
      dateLo: '1900-01-01',
      dateHi: DateSpan.maxDate,
    );

const _r1 = [NetServicePart(routeId: 'r1', from: 'a', to: 'd')];
const _r12 = [
  NetServicePart(routeId: 'r1', from: 'a', to: 'd'),
  NetServicePart(routeId: 'r2', from: 'd', to: 'f'),
];

/// 노선 l1(a-b-c-d)과 l2(d-e-f)를 잇는 운행 계통.
/// 1985년 판은 a~d에서 a·c·d에 서고, 1986년 판은 a~f에서 a·c·f에 선다. 노선이 바뀌는 d에는 서지 않는다.
NetService _service({bool withStops = true}) => NetService(
      id: 's',
      closed: false,
      editions: [
        NetServiceEdition(
          validFrom: '1985-09-30',
          validTo: '1986-03-03',
          parts: _r1,
          stops: withStops ? const {'a', 'c', 'd'} : null,
        ),
        NetServiceEdition(
          validFrom: '1986-03-03',
          validTo: 'ongoing',
          parts: _r12,
          stops: withStops ? const {'a', 'c', 'f'} : null,
        ),
      ],
    );

Network _network(NetService service) => Network(
      NetworkData(
        routes: const [
          NetRoute(id: 'r1', lineId: 'l1', role: 'main', fromNode: 'a', toNode: 'd', closed: false, extendTo: []),
          NetRoute(id: 'r2', lineId: 'l2', role: 'main', fromNode: 'd', toNode: 'f', closed: false, extendTo: []),
        ],
        edges: const [
          NetEdge(id: 'ab', n: 1, from: 'a', to: 'b', meters: 1000),
          NetEdge(id: 'bc', n: 2, from: 'b', to: 'c', meters: 2000),
          NetEdge(id: 'cd', n: 3, from: 'c', to: 'd', meters: 3000),
          NetEdge(id: 'de', n: 4, from: 'd', to: 'e', meters: 400),
          NetEdge(id: 'ef', n: 5, from: 'e', to: 'f', meters: 600),
        ],
        routeEdges: const [
          NetRouteEdge(routeId: 'r1', seq: 0, edgeId: 'ab'),
          NetRouteEdge(routeId: 'r1', seq: 1, edgeId: 'bc'),
          NetRouteEdge(routeId: 'r1', seq: 2, edgeId: 'cd'),
          NetRouteEdge(routeId: 'r2', seq: 0, edgeId: 'de'),
          NetRouteEdge(routeId: 'r2', seq: 1, edgeId: 'ef'),
        ],
        stops: [
          _stop('r1', 0, 'a'),
          _stop('r1', 1, 'b'),
          _stop('r1', 2, 'c'),
          _stop('r1', 3, 'd'),
          _stop('r2', 0, 'd'),
          _stop('r2', 1, 'e'),
          _stop('r2', 2, 'f'),
        ],
        attrs: [_attr('ab', 'l1'), _attr('bc', 'l1'), _attr('cd', 'l1'), _attr('de', 'l2'), _attr('ef', 'l2')],
        lives: [for (final e in const ['ab', 'bc', 'cd', 'de', 'ef']) NetLife(edgeId: e, suspended: false, period: ongoing)],
        units: [
          _unit(1, 'ab', 'l1', 1000),
          _unit(2, 'bc', 'l1', 2000),
          _unit(3, 'cd', 'l1', 3000),
          _unit(4, 'de', 'l2', 400),
          _unit(5, 'ef', 'l2', 600),
        ],
        publicNodes: const {'a', 'b', 'c', 'd', 'e', 'f'},
        nodeGroups: const {},
        services: [service],
      ),
    );

void main() {
  DateSpan day(String raw) => DateSpan.parse(raw);
  List<String> nodes(List<ServiceStop> stops) => [for (final stop in stops) stop.node];

  final service = _service();
  final network = _network(service);
  final splitter = ServiceSplitter(network);

  group('판', () {
    test('탑승일이 든 판을 고르고 날짜를 모르면 지금 판이다', () {
      expect(splitter.edition(service, day('1985-12-01')), same(service.editions.first));
      expect(splitter.edition(service, day('1986-03-02')), same(service.editions.first));
      expect(splitter.edition(service, day('1986-03-03')), same(service.editions.last));
      expect(splitter.edition(service, day('2020-05-01')), same(service.editions.last));
      expect(splitter.edition(service, null), same(service.editions.last));
    });

    test('판마다 경로가 다르다', () {
      expect(nodes(splitter.stops(service, day('1985-12-01'))), ['a', 'b', 'c', 'd']);
      expect(nodes(splitter.stops(service, day('1986-05-01'))), ['a', 'b', 'c', 'd', 'e', 'f']);
    });

    test('어느 판에도 없는 날짜는 고르지 못하고 화면은 마지막 판을 그린다', () {
      expect(splitter.edition(service, day('1980-01-01')), isNull);
      expect(splitter.usable(service, day('1980-01-01')), isFalse);
      expect(splitter.openOn(service, day('1980-01-01')), isEmpty);
      expect(splitter.layout(service, day('1980-01-01')), same(service.editions.last));
    });

    test('두 판에 걸친 범위 날짜는 늦은 판이다', () {
      expect(splitter.edition(service, day('1986-XX-XX')), same(service.editions.last));
      expect(splitter.edition(service, day('[1985-10-01..1985-11-30]')), same(service.editions.first));
    });
  });

  group('정차역', () {
    test('계통 화면에는 그 판의 정차역만 보인다', () {
      expect(nodes(splitter.halts(service, day('1985-12-01'))), ['a', 'c', 'd']);
      expect(nodes(splitter.halts(service, day('1986-05-01'))), ['a', 'c', 'f']);
      expect(splitter.openOn(service, day('1986-05-01')), {'a', 'c', 'f'});
    });

    test('정차역을 적지 않은 판(옛 꼴)은 모든 역에 선다', () {
      final plain = _service(withStops: false);
      expect(nodes(ServiceSplitter(_network(plain)).halts(plain, null)), ['a', 'b', 'c', 'd', 'e', 'f']);
    });

    test('정차역의 자리와 거리는 전체 경로의 값이다', () {
      final halts = splitter.halts(service, null);
      expect([for (final stop in halts) stop.index], [0, 2, 5]);
      expect([for (final stop in halts) stop.meters], [0, 3000, 7000]);
    });

    test('서지 않는 역에서 노선이 바뀌어도 공식 구간으로 나뉘고 km는 공식 경로 전체다', () {
      final all = splitter.stops(service, null);
      final halts = [for (final stop in all) if (stop.halts) stop];
      final legs = splitter.legs(
        service,
        all,
        halts.first,
        halts.last,
        date: null,
        lineName: (id) => id,
        nodeName: (node) => node,
      )!;
      expect([for (final leg in legs) (leg.routeId.value, leg.fromNode.value, leg.toNode.value)], [
        ('r1', 'a', 'd'),
        ('r2', 'd', 'f'),
      ]);
      final ride = splitter.ride(service, legs, id: const RideId('x'), dateInput: null, datasetVersion: 'v', deviceId: 'd', now: 1)!;
      final derived = RideInterpreter(network).ride(ride);
      expect(derived.km10, 70);
      expect(derived.edges.length, 5);

      // 정차역이 없던 옛 동작과 분해·km가 같다
      final plain = _service(withStops: false);
      final plainNet = _network(plain);
      final plainSplitter = ServiceSplitter(plainNet);
      final plainAll = plainSplitter.stops(plain, null);
      final plainLegs = plainSplitter.legs(
        plain,
        plainAll,
        plainAll.first,
        plainAll.last,
        date: null,
        lineName: (id) => id,
        nodeName: (node) => node,
      )!;
      expect([for (final leg in plainLegs) (leg.routeId.value, leg.fromNode.value, leg.toNode.value)],
          [for (final leg in legs) (leg.routeId.value, leg.fromNode.value, leg.toNode.value)]);
      final plainRide =
          plainSplitter.ride(plain, plainLegs, id: const RideId('y'), dateInput: null, datasetVersion: 'v', deviceId: 'd', now: 1)!;
      expect(RideInterpreter(plainNet).ride(plainRide).km10, derived.km10);
    });

    test('고른 구간의 지나는 역은 서지 않는 역까지 들어 있다', () {
      final all = splitter.stops(service, null);
      final path = splitter.path(service, all, all[2], all[5]);
      expect(nodes(path), ['c', 'd', 'e', 'f']);
      expect(nodes([for (final stop in path) if (stop.halts) stop]), ['c', 'f']);
    });
  });

  test('날짜를 모르는데 이설 구간이 있으면 판의 마지막 날 선형으로 행을 그린다 (嵯峨野線)', () {
    const before = NetPeriod(fromLo: '1900-01-01', fromHi: '1900-01-01', toLo: '2000-01-01', toHi: '2000-01-01');
    const after = NetPeriod(fromLo: '2000-01-01', fromHi: '2000-01-01', toLo: DateSpan.maxDate, toHi: DateSpan.maxDate);
    const moved = NetService(id: 'm', closed: false, editions: [
      NetServiceEdition(parts: [NetServicePart(routeId: 'r', from: 'a', to: 'c')]),
    ]);
    final relocated = Network(NetworkData(
      routes: const [NetRoute(id: 'r', lineId: 'l', role: 'main', fromNode: 'a', toNode: 'c', closed: false, extendTo: [])],
      edges: const [
        NetEdge(id: 'old', n: 1, from: 'a', to: 'b', meters: 1000),
        NetEdge(id: 'new', n: 2, from: 'a', to: 'x', meters: 700),
        NetEdge(id: 'xb', n: 3, from: 'x', to: 'b', meters: 700),
        NetEdge(id: 'bc', n: 4, from: 'b', to: 'c', meters: 500),
      ],
      routeEdges: const [
        NetRouteEdge(routeId: 'r', seq: 0, edgeId: 'old'),
        NetRouteEdge(routeId: 'r', seq: 1, edgeId: 'new'),
        NetRouteEdge(routeId: 'r', seq: 2, edgeId: 'xb'),
        NetRouteEdge(routeId: 'r', seq: 3, edgeId: 'bc'),
      ],
      stops: [_stop('r', 0, 'a'), _stop('r', 1, 'x'), _stop('r', 2, 'b'), _stop('r', 3, 'c')],
      attrs: [
        const NetAttr(edgeId: 'old', lineId: 'l', operatorId: 'o', lineageId: 'lg', carryoverGroup: 'c', period: before),
        const NetAttr(edgeId: 'new', lineId: 'l', operatorId: 'o', lineageId: 'lg', carryoverGroup: 'c', period: after),
        const NetAttr(edgeId: 'xb', lineId: 'l', operatorId: 'o', lineageId: 'lg', carryoverGroup: 'c', period: after),
        _attr('bc', 'l'),
      ],
      lives: const [
        NetLife(edgeId: 'old', suspended: false, period: before),
        NetLife(edgeId: 'new', suspended: false, period: after),
        NetLife(edgeId: 'xb', suspended: false, period: after),
        NetLife(edgeId: 'bc', suspended: false, period: ongoing),
      ],
      units: const [],
      publicNodes: const {'a', 'x', 'b', 'c'},
      nodeGroups: const {},
      services: const [moved],
    ));
    final splitter = ServiceSplitter(relocated);
    expect(nodes(splitter.stops(moved, null)), ['a', 'x', 'b', 'c']);
    expect(splitter.openOn(moved, null), {'a', 'x', 'b', 'c'});
    expect(nodes(splitter.stops(moved, day('1990-01-01'))), ['a', 'b', 'c']);
  });
}
