import '../date/date_span.dart';
import '../ids.dart';
import '../records/derived.dart';
import '../records/record.dart';
import 'network.dart';
import 'network_data.dart';
import 'ride_interpreter.dart';
import 'route_resolver.dart';

/// 운행 계통의 한 줄 노선도에 놓이는 역.
final class ServiceStop {
  const ServiceStop({
    required this.index,
    required this.node,
    required this.part,
    this.meters = 0,
    this.route = '',
    this.halts = true,
    this.onward,
  });

  /// 다음 부분이 같은 역의 다른 노드에서 시작하면 그 노드 (長崎 住吉: 赤迫支線 끝과 本線 시작). 역 줄은 하나다.
  final String? onward;

  /// 정차하지 않는 역까지 넣은 전체 목록에서의 자리.
  final int index;
  final String node;

  /// 운행 계통의 시작에서 이 역까지의 거리.
  final int meters;

  /// 이 역까지 온 부분. 첫 역은 0이다.
  final int part;

  /// 이 역까지 온 부분의 공식 계통.
  final String route;

  /// 그 판의 계통 열차가 서는 역이다. 화면은 선 역만 보이고, 구간 분해는 서지 않는 역까지 넣은 목록으로 한다.
  final bool halts;
}

/// 운행 계통을 공식 구간으로 나눈다 (ARCHITECTURE `ServiceSplitter`, DESIGN §2.8 H).
final class ServiceSplitter {
  ServiceSplitter(this.network) : _resolver = RouteResolver(network);

  final Network network;
  final RouteResolver _resolver;

  /// 그날 없는 운행 계통은 고르지 못한다.
  bool usable(NetService service, DateSpan? date) => edition(service, date) != null;

  /// 그날의 판. 날짜와 겹치는 판 중 가장 늦은 판이다. 날짜를 모르면 마지막(지금) 판이고, 그날 판이 없으면 null이다.
  NetServiceEdition? edition(NetService service, DateSpan? date) {
    if (service.editions.isEmpty) return null;
    if (date == null) return service.editions.last;
    for (final edition in service.editions.reversed) {
      if (_covers(edition, date)) return edition;
    }
    return null;
  }

  /// 화면에 그릴 판. 그날 판이 없으면 마지막 판을 그리고 역은 모두 고르지 못한다.
  NetServiceEdition? layout(NetService service, DateSpan? date) =>
      edition(service, date) ?? (service.editions.isEmpty ? null : service.editions.last);

  bool _covers(NetServiceEdition edition, DateSpan date) {
    final from = edition.validFrom;
    final to = edition.validTo;
    if (from != null && date.hi.compareTo(from) < 0) return false;
    return to == null || to == 'ongoing' || date.lo.compareTo(to) < 0;
  }

  /// 날짜를 모르면 경로를 날짜 없이 펼친다. 이설 구간이 있어 길을 못 고르면(嵯峨野線) 그 판의 마지막 날로 펼쳐 행을 그린다.
  /// 끝나지 않은 판은 지금 선형이다. 저장하는 기록의 날짜는 그대로 모름이다.
  Expansion _expansion(NetServicePart part, DateSpan? date, NetServiceEdition edition) {
    final first = _resolver.expand(part.routeId, part.from, part.to, date: date, direction: _laps(part));
    if (date != null || first.nodes.isNotEmpty) return first;
    return _resolver.expand(part.routeId, part.from, part.to, date: _lastDay(edition), direction: _laps(part));
  }

  static DateSpan _lastDay(NetServiceEdition edition) {
    final to = edition.validTo;
    if (to == null || to == 'ongoing' || to == DateSpan.maxDate) return DateSpan.parse('9999-12-30');
    final end = DateTime.parse('${to}T00:00:00Z').subtract(const Duration(days: 1));
    return DateSpan.parse(end.toIso8601String().substring(0, 10));
  }

  String? _laps(NetServicePart part) =>
      network.routes[part.routeId]?.closed == true && part.from == part.to ? seqUp : null;

  /// 한 줄 노선도의 역. 부분이 이어지는 역은 한 번만 나온다.
  ///
  /// [edition]을 주지 않으면 그날의 판([layout])이다. 정차하지 않는 역도 들어 있다([ServiceStop.halts]).
  /// 구간 분해([legs])는 이 전체 목록으로 해야 서지 않는 역에서 노선이 바뀌어도 맞게 나뉜다.
  List<ServiceStop> stops(NetService service, DateSpan? date, {NetServiceEdition? edition}) {
    final chosen = edition ?? layout(service, date);
    if (chosen == null) return const [];
    final stops = <ServiceStop>[];
    var meters = 0;
    for (final (index, part) in chosen.parts.indexed) {
      final expansion = _expansion(part, date, chosen);
      for (final (at, node) in expansion.nodes.indexed) {
        if (at > 0 && at <= expansion.edges.length) {
          meters += network.edges[expansion.edges[at - 1]]!.meters;
        }
        if (!network.isShown(node)) continue;
        if (stops.isNotEmpty && stops.last.node == node) continue;
        // 부분이 같은 역 묶음의 다른 노드로 넘어가면 한 역 줄로 두고, 다음 부분이 쓸 노드만 적는다
        if (at == 0 && stops.isNotEmpty && stops.last.part != index && network.sameStation(stops.last.node, node)) {
          final last = stops.removeLast();
          stops.add(ServiceStop(
            index: last.index,
            node: last.node,
            part: last.part,
            meters: last.meters,
            route: last.route,
            halts: last.halts || chosen.halts(node),
            onward: node,
          ));
          continue;
        }
        stops.add(ServiceStop(
          index: stops.length,
          node: node,
          part: index,
          meters: meters,
          route: part.routeId,
          halts: chosen.halts(node),
        ));
      }
    }
    return stops;
  }

  /// 계통 열차가 서는 역만. 화면의 행이다. 거리와 자리는 전체 목록의 값 그대로다.
  List<ServiceStop> halts(NetService service, DateSpan? date, {NetServiceEdition? edition}) => [
        for (final stop in stops(service, date, edition: edition))
          if (stop.halts) stop,
      ];

  /// 그날 고를 수 있는 역. 날짜를 모르면 지금 판의 전부다. 그날 판이 없으면 없다.
  Set<String> openOn(NetService service, DateSpan? date) {
    final chosen = edition(service, date);
    if (chosen == null) return const {};
    return {for (final stop in stops(service, date, edition: chosen)) if (stop.halts) stop.node};
  }

  /// 고른 두 역 사이의 역들. 화면이 범위를 칠한다. [stops]는 서지 않는 역까지 넣은 전체 목록이다.
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
  /// [stops]는 서지 않는 역까지 넣은 전체 목록([ServiceSplitter.stops])이다. 정차역만 주면 서지 않는 역에서
  /// 노선이 바뀌는 곳(中央快速線의 代々木)을 놓친다. 이름은 저장 당시 라벨이다. 펼칠 수 없으면 null이다.
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
      for (var at = 0; at + 1 < path.length; at++) _hop(path[at], path[at + 1], stops.last.part),
    ];
    // 부분 번호의 계통. 판마다 부분이 달라 운행 계통이 아니라 역 목록에서 읽는다
    final routeOf = {for (final stop in stops) stop.part: stop.route};
    final legs = <RideLeg>[];
    var begin = 0;
    for (var at = 1; at <= hops.length; at++) {
      if (at < hops.length && hops[at] == hops[begin]) continue;
      final slice = path.sublist(begin, at + 1);
      final route = network.routes[routeOf[hops[begin]]]!;
      // 부분이 같은 역의 다른 노드에서 시작하면 그 노드로 탄다. 반대 방향이면 끝 역 쪽이다
      String nodeOn(ServiceStop stop) =>
          stop.onward != null && stop.part != hops[begin] && network.stops(route.id).any((x) => x.node == stop.onward) ? stop.onward! : stop.node;
      legs.add(
        RideLeg(
          seq: legs.length,
          lineId: LineId(route.lineId),
          routeId: RouteId(route.id),
          fromNode: NodeId(nodeOn(slice.first)),
          toNode: NodeId(nodeOn(slice.last)),
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

  /// 운행 계통으로 입력한 기록. 저장 뒤에는 평범한 기록이고 `service_id`는 표시용이다.
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
