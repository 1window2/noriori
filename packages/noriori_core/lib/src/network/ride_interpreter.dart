import '../date/date_rules.dart';
import '../date/date_span.dart';
import '../ids.dart';
import '../records/derived.dart';
import '../records/record.dart';
import 'network.dart';
import 'network_data.dart';
import 'route_resolver.dart';

/// 저장과 재해석이 함께 쓰는 해석 (ARCHITECTURE §3.4). 입력에서 파생 값만 만든다.
final class RideInterpreter implements RecordInterpreter {
  RideInterpreter(this.network) : _resolver = RouteResolver(network);

  final Network network;
  final RouteResolver _resolver;

  static const _order = [
    ResolveStatus.ok,
    ResolveStatus.partial,
    ResolveStatus.needsInput,
    ResolveStatus.unknownRef,
    ResolveStatus.invalid,
  ];

  /// 기록의 구간마다 펼친 결과. 구간 끄기가 경로를 나누려고 쓴다.
  List<Expansion> expansions(Ride ride) {
    final raw = ride.dateInput;
    final input = raw == null ? null : DateSpan.parse(raw);
    return [
      for (final leg in ride.legs)
        _resolver.record(
          leg.routeId,
          leg.fromNode,
          leg.toNode,
          date: input,
          direction: leg.direction,
          asOf: leg.resolveAsOf == null ? null : DateSpan.parse(leg.resolveAsOf!),
          resolveUnknown: leg.resolveUnknown,
          askDirection: true,
        ),
    ];
  }

  @override
  RideDerived ride(Ride ride) {
    final raw = ride.dateInput;
    final input = raw == null ? null : DateSpan.parse(raw);
    var status = ResolveStatus.ok;
    final expansions = this.expansions(ride);
    for (final expansion in expansions) {
      if (_order.indexOf(expansion.status) > _order.indexOf(status)) status = expansion.status;
    }
    if (status != ResolveStatus.ok && status != ResolveStatus.partial) {
      return RideDerived(status: status);
    }
    var dated = expansions.every((e) => !e.demoted) ? normalizeRideDate(input) : null;
    // 입력과 멤버십, 정차 기간의 교집합이 비면 날짜 모름이다 (DESIGN §2.8 J)
    if (dated != null && !_fits(ride, dated, expansions)) dated = null;
    final hi = _effectiveHi(ride, dated, expansions);
    final legs = <LegDerived>[];
    final edges = <EdgeHit>[];
    final nodes = <String, NodeRole>{};
    var meters = 0;
    for (final (index, expansion) in expansions.indexed) {
      // 구간마다 그날 노선의 길이다. 3섹 전환 때 km가 바뀐 구간은 국철·JR 날짜에 옛 km다
      if (expansion.meters != null) {
        meters += expansion.legs.fold(0, (sum, leg) => sum + network.metersOf(leg.edges, lineId: leg.lineId));
      }
      for (final leg in expansion.legs) {
        final seq = legs.length;
        legs.add(LegDerived(
          seq: seq,
          lineId: LineId(leg.lineId),
          routeId: RouteId(leg.routeId),
          km10: km10(network.metersOf(leg.edges, lineId: leg.lineId)),
        ));
        for (final edge in leg.edges) {
          edges.add(EdgeHit(
            edge: network.edges[edge]!.n,
            legSeq: seq,
            unitOn: network.unitOf(leg.lineId, edge, carryover: true)?.n ?? 0,
            unitOff: network.unitOf(leg.lineId, edge, carryover: false)?.n ?? 0,
          ));
        }
      }
      final path = expansion.nodes;
      for (final (at, node) in path.indexed) {
        final first = index == 0 && at == 0;
        final last = index == expansions.length - 1 && at == path.length - 1;
        // leg 경계는 갈아탄 곳이 아니다. 같은 열차로 지나간 역은 `transfer_nodes`에 없다
        final alighted = (first && ride.fromAlighted) ||
            (last && ride.toAlighted) ||
            ride.transferNodes.contains(NodeId(node));
        if (alighted) {
          nodes[node] = NodeRole.alighted;
        } else {
          nodes.putIfAbsent(node, () => NodeRole.passed);
        }
      }
    }
    return RideDerived(
      status: status,
      date: dated?.raw,
      km10: km10(meters),
      effectiveLo: dated?.lo,
      effectiveHi: hi,
      legs: legs,
      edges: edges,
      nodes: [
        for (final MapEntry(:key, :value) in nodes.entries)
          NodeHit(node: NodeId(key), role: value),
      ],
    );
  }

  /// 입력한 날에 그 구간을 탈 수 없는가 (DESIGN §2.8 J, ARCHITECTURE §3.4).
  ///
  /// 폐지 뒤, 개업 전, 운휴, 정차하지 않는 역, 범위 날짜에서 유효 범위가 비는 경우다. 저장과 날짜 수정은
  /// 참이면 경고하고 저장하지 않는다. 기준일 이전은 기록 범위 밖이라 거짓이다. 날짜 없이도 경로가 없으면
  /// 날짜 탓이 아니므로 거짓이다.
  bool unridable(Ride ride) {
    final raw = ride.dateInput;
    final day = raw == null ? null : normalizeRideDate(DateSpan.parse(raw));
    if (day == null) return false;
    final expansions = this.expansions(ride);
    if (expansions.any((e) => e.status == ResolveStatus.invalid || e.status == ResolveStatus.unknownRef)) {
      return false;
    }
    if (expansions.any((e) => e.demoted)) return true;
    if (!expansions.every((e) => e.saved)) return false;
    return !_fits(ride, day, expansions);
  }

  /// 입력과 멤버십, 정차 기간의 교집합이 있는가.
  bool _fits(Ride ride, DateSpan date, List<Expansion> expansions) =>
      _effectiveHi(ride, date, expansions).compareTo(date.lo) >= 0 && !_beforeStop(ride, date, expansions);

  @override
  VisitDerived visit(Visit visit) {
    final raw = visit.dateInput;
    final date = raw == null ? null : normalizeRideDate(DateSpan.parse(raw));
    return VisitDerived(date: date?.raw, groupId: network.data.nodeGroups[visit.nodeId]);
  }

  /// 유효 날짜 범위의 끝 (DESIGN §2.8 J). 날짜가 없는 기록만 등록일을 상한으로 쓴다.
  String _effectiveHi(Ride ride, DateSpan? date, List<Expansion> expansions) {
    var hi = date?.hi ?? jstDate(ride.createdAt);
    void cap(String? end) {
      if (end == null || end.compareTo(DateSpan.maxDate) >= 0) return;
      final last = dayBefore(end);
      if (last.compareTo(hi) < 0) hi = last;
    }

    for (final expansion in expansions) {
      for (final leg in expansion.legs) {
        for (final edge in leg.edges) {
          final rows = network.attrsOf(edge, leg.lineId);
          if (rows.isNotEmpty) cap(_latestEnd(rows.map((row) => row.period)));
        }
      }
    }
    for (final stops in _endStops(ride, expansions)) {
      cap(_latestEnd(stops.map((stop) => stop.period)));
    }
    return hi;
  }

  /// 기간들 가운데 가장 늦은 끝. 끝이 없는 기간은 영업 중이다.
  String _latestEnd(Iterable<NetPeriod> periods) => periods
      .map((period) => period.toHi ?? DateSpan.maxDate)
      .reduce((end, to) => to.compareTo(end) > 0 ? to : end);

  /// 입력한 날에 아직 개업하지 않았거나 정차 기간 사이라 서지 않은 승하차역이 있는가.
  bool _beforeStop(Ride ride, DateSpan date, List<Expansion> expansions) => _endStops(ride, expansions).any(
        (stops) => stops.every((stop) {
          final from = stop.period.fromLo;
          return (from != null && date.hi.compareTo(from) < 0) || inStopGap(date, stop);
        }),
      );

  /// 승하차한 끝의 정차 행. 잘린 끝은 통과라 보지 않는다.
  ///
  /// 이관 뒤 날짜로 옛 노선 화면에서 고르면 그날 맡은 노선으로 펼쳐지므로 그 노선에서 찾는다.
  Iterable<List<NetStop>> _endStops(Ride ride, List<Expansion> expansions) sync* {
    List<NetStop> rows(String? lineId, String route, String node) {
      List<NetStop> on(Iterable<String> ids) => [
            for (final id in ids)
              for (final stop in network.stops(id))
                if (stop.isStop && stop.node == node) stop,
          ];
      final found = lineId == null ? const <NetStop>[] : on(network.routesOfLine(lineId));
      return found.isNotEmpty ? found : on([route]);
    }

    if (ride.fromAlighted) {
      final leg = ride.legs.first;
      final found = rows(expansions.first.legs.firstOrNull?.lineId, leg.routeId, leg.fromNode);
      if (found.isNotEmpty) yield found;
    }
    if (ride.toAlighted) {
      final leg = ride.legs.last;
      final found = rows(expansions.last.legs.lastOrNull?.lineId, leg.routeId, leg.toNode);
      if (found.isNotEmpty) yield found;
    }
  }
}

/// 미터를 0.1km로. 표시용 값이고 계산은 미터로 한다.
int km10(int meters) => (meters + 50) ~/ 100;
