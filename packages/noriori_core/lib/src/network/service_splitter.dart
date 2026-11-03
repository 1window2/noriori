import '../date/date_span.dart';
import '../ids.dart';
import '../records/derived.dart';
import '../records/record.dart';
import 'network.dart';
import 'network_data.dart';
import 'ride_interpreter.dart';
import 'route_resolver.dart';

/// 운전 계통의 한 줄 노선도에 놓이는 역.
final class ServiceStop {
  const ServiceStop({
    required this.index,
    required this.node,
    required this.part,
    this.meters = 0,
  });

  final int index;
  final String node;

  /// 운전 계통의 시작에서 이 역까지의 거리.
  final int meters;

  /// 이 역까지 온 부분. 첫 역은 0이다.
  final int part;
}

/// 운전 계통을 공식 구간으로 나눈다 (ARCHITECTURE `ServiceSplitter`, DESIGN §2.8 H).
final class ServiceSplitter {
  ServiceSplitter(this.network) : _resolver = RouteResolver(network);

  final Network network;
  final RouteResolver _resolver;

  /// 그날 없는 운전 계통은 고르지 못한다.
  bool usable(NetService service, DateSpan? date) {
    if (date == null) return true;
    final from = service.validFrom;
    final to = service.validTo;
    if (from != null && date.hi.compareTo(from) < 0) return false;
    return to == null || to == 'ongoing' || date.lo.compareTo(to) < 0;
  }

  Expansion _expansion(NetServicePart part, DateSpan? date) =>
      _resolver.expand(part.routeId, part.from, part.to, date: date, direction: _laps(part));

  String? _laps(NetServicePart part) =>
      network.routes[part.routeId]?.closed == true && part.from == part.to ? seqUp : null;

  /// 한 줄 노선도의 역. 부분이 이어지는 역은 한 번만 나온다.
  List<ServiceStop> stops(NetService service, DateSpan? date) {
    final stops = <ServiceStop>[];
    var meters = 0;
    for (final (index, part) in service.parts.indexed) {
      final expansion = _expansion(part, date);
      for (final (at, node) in expansion.nodes.indexed) {
        if (at > 0 && at <= expansion.edges.length) {
          meters += network.edges[expansion.edges[at - 1]]!.meters;
        }
        if (!network.isShown(node)) continue;
        if (stops.isNotEmpty && stops.last.node == node) continue;
        stops.add(ServiceStop(index: stops.length, node: node, part: index, meters: meters));
      }
    }
    return stops;
  }

  /// 그날 고를 수 있는 역. 날짜를 모르면 전부다.
  Set<String> openOn(NetService service, DateSpan? date) {
    if (!usable(service, date)) return const {};
    return {for (final stop in stops(service, date)) stop.node};
  }

  /// 고른 두 역 사이의 역들. 화면이 범위를 칠한다.
  List<ServiceStop> path(
    NetService service,
    List<ServiceStop> stops,
    ServiceStop from,
    ServiceStop to, {
    bool up = true,
  }) =>
      _walk(stops, from, to, closed: service.closed, up: up);

  /// 고른 두 역을 공식 구간 legs로 나눈다. 고리면 [up]이 역 순서 방향이다.
  ///
  /// 이름은 저장 당시 라벨이다. 펼칠 수 없으면 null이다.
  List<RideLeg>? legs(
    NetService service,
    List<ServiceStop> stops,
    ServiceStop from,
    ServiceStop to, {
    required DateSpan? date,
    required String Function(String lineId) lineName,
    required String Function(String node) nodeName,
    bool up = true,
  }) {
    final path = _walk(stops, from, to, closed: service.closed, up: up);
    if (path.length < 2) return null;
    final hops = [
      for (var at = 0; at + 1 < path.length; at++) _hop(path[at], path[at + 1], service.parts.length - 1),
    ];
    final legs = <RideLeg>[];
    var begin = 0;
    for (var at = 1; at <= hops.length; at++) {
      if (at < hops.length && hops[at] == hops[begin]) continue;
      final slice = path.sublist(begin, at + 1);
      final route = network.routes[service.parts[hops[begin]].routeId]!;
      legs.add(
        RideLeg(
          seq: legs.length,
          lineId: LineId(route.lineId),
          routeId: RouteId(route.id),
          fromNode: NodeId(slice.first.node),
          toNode: NodeId(slice.last.node),
          direction: _direction(route, slice, date),
          lineLabel: lineName(route.lineId),
          fromLabel: nodeName(slice.first.node),
          toLabel: nodeName(slice.last.node),
        ),
      );
      begin = at;
    }
    return legs;
  }

  /// 두 역 사이가 어느 부분인가. 번호가 큰 쪽 역이 그 부분에 들어 있다.
  int _hop(ServiceStop a, ServiceStop b, int lastPart) {
    final gap = a.index - b.index;
    if (gap == 1 || gap == -1) return a.index > b.index ? a.part : b.part;
    return lastPart; // 고리를 넘어가는 칸의 번호 큰 쪽 역은 고리의 끝, 곧 첫 역이다
  }

  /// 닫힌 계통은 짧은 쪽이 아니라 그 구간을 지나는 방향을 남긴다.
  String? _direction(NetRoute route, List<ServiceStop> slice, DateSpan? date) {
    if (!route.closed) return null;
    final want = [for (final stop in slice) stop.node];
    for (final direction in const [seqUp, seqDown]) {
      final nodes = _resolver.expand(route.id, want.first, want.last, date: date, direction: direction).nodes;
      final shown = nodes.where(network.isShown).toList();
      if (shown.length == want.length && _same(shown, want)) return direction;
    }
    return seqUp;
  }

  bool _same(List<String> a, List<String> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  List<ServiceStop> _walk(
    List<ServiceStop> stops,
    ServiceStop from,
    ServiceStop to, {
    required bool closed,
    required bool up,
  }) {
    if (!closed) {
      final lo = from.index < to.index ? from.index : to.index;
      final hi = from.index < to.index ? to.index : from.index;
      final slice = stops.sublist(lo, hi + 1);
      return from.index < to.index ? slice : slice.reversed.toList();
    }
    // 고리의 끝 역은 첫 역과 같으므로 한 번만 돈다
    final ring = stops.first.node == stops.last.node ? stops.sublist(0, stops.length - 1) : stops;
    final size = ring.length;
    final step = up ? 1 : size - 1;
    int position(ServiceStop stop) => ring.indexWhere((s) => s.node == stop.node);
    final path = <ServiceStop>[ring[position(from)]];
    var at = position(from);
    final end = position(to);
    do {
      at = (at + step) % size;
      path.add(ring[at]);
    } while (at != end && path.length <= size);
    return path;
  }

  /// 운전 계통으로 입력한 기록. 저장 뒤에는 평범한 기록이고 `service_id`는 표시용이다.
  Ride? ride(
    NetService service,
    List<RideLeg> legs, {
    required RideId id,
    required String? dateInput,
    required String datasetVersion,
    required String deviceId,
    required int now,
  }) {
    final ride = Ride(
      rideId: id,
      legs: legs,
      datasetVersion: datasetVersion,
      createdAt: now,
      updatedAt: now,
      deviceId: deviceId,
      dateInput: dateInput,
      serviceId: ServiceId(service.id),
    );
    final derived = RideInterpreter(network).ride(ride);
    return derived.status == ResolveStatus.ok ? ride : null;
  }
}

/// 한 공식 노선에서 달린 거리. 저장 전 요약에 쓴다 (DESIGN §8).
final class ServiceLegSummary {
  const ServiceLegSummary(this.lineId, this.km10);

  final String lineId;
  final int km10;
}

/// 같은 노선이 이어지면 한 줄로 합친다.
List<ServiceLegSummary> summarizeLegs(RideDerived derived) {
  final rows = <ServiceLegSummary>[];
  for (final leg in derived.legs) {
    if (rows.isNotEmpty && rows.last.lineId == leg.lineId.value) {
      rows[rows.length - 1] = ServiceLegSummary(leg.lineId.value, rows.last.km10 + leg.km10);
    } else {
      rows.add(ServiceLegSummary(leg.lineId.value, leg.km10));
    }
  }
  return rows;
}
