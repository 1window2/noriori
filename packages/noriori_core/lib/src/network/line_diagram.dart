import '../date/date_rules.dart';
import '../date/date_span.dart';
import '../ids.dart';
import '../records/derived.dart';
import '../records/record.dart';
import '../score/line_strip.dart';
import '../score/scorer.dart';
import 'network.dart';
import 'network_data.dart';
import 'ride_interpreter.dart';
import 'route_resolver.dart';

/// 세로 노선도의 역 하나.
final class DiagramStop {
  const DiagramStop({
    required this.node,
    required this.kmCum,
    required this.gone,
    required this.others,
    this.closeYear,
    this.kmEstimated = false,
  });

  final String node;
  final double? kmCum;

  /// km가 추정값이라 화면은 `? km` (DESIGN §4.5).
  final bool kmEstimated;

  /// 오늘은 없는 역.
  final bool gone;
  final String? closeYear;

  /// 이 역에서 갈라지는 같은 노선의 다른 계통.
  final List<String> others;
}

/// 표시 역 둘 사이. 구간 탭의 단위다 (DESIGN §8.2).
final class DiagramSection {
  const DiagramSection({
    required this.routeId,
    required this.from,
    required this.to,
    required this.edges,
    required this.units,
    required this.meters,
    required this.gone,
    required this.ridden,
    this.closed = false,
    this.held = true,
  });

  final String routeId;
  final String from;
  final String to;
  final List<String> edges;
  final Set<int> units;
  final int meters;
  final bool gone;
  final bool ridden;

  /// 폐지되어 다시 탈 수 없다. 운휴는 언젠가 다시 달리므로 들지 않는다.
  final bool closed;

  /// 오늘 이 노선이 맡은 구간이다. 이관한 구간은 다른 노선의 분모에 든다.
  final bool held;

  /// 집계 단위가 없는 구간은 고칠 수 없다.
  bool get editable => units.isNotEmpty;
}

final class RouteDiagram {
  const RouteDiagram({
    required this.routeId,
    required this.stops,
    required this.sections,
    required this.current,
    required this.allTime,
  });

  final String routeId;
  final List<DiagramStop> stops;

  /// `sections[i]`는 `stops[i]`와 `stops[i + 1]` 사이다.
  final List<DiagramSection> sections;
  final Score current;
  final Score allTime;
}

/// 노선 상세가 그리는 값 (DESIGN §2.7, §3.3).
final class LineDiagram {
  const LineDiagram({required this.lineId, required this.routes, required this.selfScore});

  final String lineId;
  final List<RouteDiagram> routes;

  /// 전 구간이 분모 밖인 노선은 자기 km로 진행률을 보여 준다 (DESIGN §3.1).
  final Score selfScore;
}

/// [hits]는 탄 단위다. 본선이 먼저고 나머지는 팩의 순서다.
LineDiagram lineDiagram(
  Network network,
  String lineId, {
  required Map<int, String?> hits,
  required String today,
  bool carryover = true,
}) {
  final day = DateSpan.parse(today);
  final routes = network.routesOfLineMainFirst(lineId);
  final seen = <int, NetUnit>{};
  final diagrams = <RouteDiagram>[];
  for (final routeId in routes) {
    final (stops, cells) = _stopsAndCells(network, lineId, routeId, day);
    final routeUnits = <int, NetUnit>{};
    final sections = <DiagramSection>[];
    final heldUnits = <int, NetUnit>{};
    for (final (at, cell) in cells.indexed) {
      final units = <int>{};
      final liveUnits = <int>{};
      var held = false;
      // 이설된 칸은 지금 선로로 판단한다. 옛 선로만 탔으면 지금 선로는 안 탄 것이다
      final live = cell.where((edge) => !const {LifeState.closed, LifeState.before}.contains(network.lifeOn(edge, day)));
      for (final edge in cell) {
        final unit = network.unitOf(lineId, edge, carryover: carryover);
        if (unit == null) continue;
        units.add(unit.n);
        routeUnits[unit.n] = unit;
        seen[unit.n] = unit;
        if (!live.contains(edge)) continue;
        liveUnits.add(unit.n);
        if (network.attrsOf(edge, lineId).any((attr) => stateOfPeriod(day, attr.period) == PeriodState.yes)) {
          held = true;
          heldUnits[unit.n] = unit;
        }
      }
      sections.add(DiagramSection(
        routeId: routeId,
        from: stops[at].node,
        to: stops[at + 1].node,
        edges: cell,
        units: units,
        meters: network.metersOf(live.isEmpty ? cell : live),
        gone: !cell.any((e) => network.lifeOn(e, day) == LifeState.open),
        ridden: (live.isEmpty ? units : liveUnits).any(hits.containsKey),
        closed: live.isEmpty,
        held: held,
      ));
    }
    Score of(Iterable<NetUnit> units, ScoreBasis basis) =>
        computeScore(units: units, hits: hits, basis: basis, today: today);
    if (stops.length < 2) continue; // 표시 역이 없는 연결 계통은 그릴 것이 없다
    diagrams.add(RouteDiagram(
      routeId: routeId,
      stops: stops,
      sections: sections,
      current: of(heldUnits.values, const BasisCurrent()),
      allTime: of(routeUnits.values, const BasisAllTime()),
    ));
  }
  var done = 0;
  var total = 0;
  var doneUnits = 0;
  for (final unit in seen.values) {
    total += unit.meters;
    if (hits.containsKey(unit.n)) {
      done += unit.meters;
      doneUnits++;
    }
  }
  return LineDiagram(
    lineId: lineId,
    routes: diagrams,
    selfScore: Score(numMeters: done, denMeters: total, numUnits: doneUnits, denUnits: seen.length),
  );
}

/// 계통 하나의 표시 역과 칸. 칸마다 지나는 구간이고 표시 역 앞의 숨은 노드까지 한 칸에 든다.
(List<DiagramStop>, List<List<String>>) _stopsAndCells(
  Network network,
  String lineId,
  String routeId,
  DateSpan day,
) {
  // 공식 구간이 숨은 분기점에서 시작하는 짧은 노선은 연장 역까지 넣어야 그릴 수 있다
  // 그 계통에서 서지 않는 역(연장 칸도 아닌 통과 노드)은 그리지 않는다. 기록 화면(selector)과 같은 규칙이다
  // (筑豊電鉄 계통이 지나기만 하는 黒崎車庫前: 北九州線 시절 1999 폐지, 7회차 2026-11-14)
  bool shown(NetStop stop) => network.isShown(stop.node) && (stop.isStop || stop.isExtension);
  final own = network.stops(routeId);
  final all = own.where(shown).length < 2 ? network.picks(routeId) : own;
  final stops = <DiagramStop>[];
  final cells = <List<String>>[];
  final cellOf = <String, int>{};
  var pending = <String>[];
  for (final (at, stop) in all.indexed) {
    if (at > 0) {
      for (final edge in network.edgesBetween(routeId, all[at - 1].node, stop.node)) {
        if (!pending.contains(edge)) pending.add(edge);
      }
    }
    if (shown(stop)) {
      if (stops.isNotEmpty) {
        cells.add(pending);
        pending = [];
      }
      stops.add(_diagramStop(network, lineId, routeId, stop, day));
    }
    cellOf.putIfAbsent(stop.node, () => stops.isEmpty ? 0 : stops.length - 1);
  }
  // 첫 역 앞의 숨은 분기점은 첫 칸에, 끝 역 뒤의 것은 끝 칸에 든다
  if (cells.isNotEmpty) cells.last.addAll(pending.where((e) => !cells.last.contains(e)));
  // 이웃하지 않은 역을 잇는 옛 선로는 그 역들 사이의 칸마다 든다
  final placed = {for (final cell in cells) ...cell};
  for (final hop in network.hops(routeId)) {
    if (placed.contains(hop.edge)) continue;
    final a = cellOf[hop.a];
    final b = cellOf[hop.b];
    if (a == null || b == null) continue;
    for (var at = a < b ? a : b; at < (a < b ? b : a) && at < cells.length; at++) {
      cells[at].add(hop.edge);
    }
  }
  return (stops, cells);
}

DiagramStop _diagramStop(Network network, String lineId, String routeId, NetStop stop, DateSpan day) =>
    DiagramStop(
      node: stop.node,
      kmCum: stop.kmCum,
      kmEstimated: stop.kmEstimated,
      gone: const {PeriodState.after, PeriodState.before}.contains(stateOfPeriod(day, stop.period)),
      closeYear: stop.period.toHi == null || stop.period.toHi == DateSpan.maxDate
          ? null
          : yearLabel(stop.period.toLo, stop.period.toHi),
      others: [
        for (final other in network.routesAt(stop.node))
          if (other != routeId && network.routes[other]!.lineId == lineId) other,
      ],
    );

/// 노선 상세 위의 가로 띠. 본선부터 잇고 같은 구간은 한 번만 센다.
LineStrip diagramStrip(LineDiagram diagram) {
  final seen = <String>{};
  final segments = <StripSegment>[];
  var at = 0;
  for (final route in diagram.routes) {
    for (final section in route.sections) {
      final fresh = section.edges.where(seen.add).length;
      if (fresh == 0) continue;
      final next = at + section.meters;
      if (section.ridden) {
        if (segments.isNotEmpty && segments.last.to == at) {
          segments[segments.length - 1] = StripSegment(segments.last.from, next);
        } else {
          segments.add(StripSegment(at, next));
        }
      }
      at = next;
    }
  }
  final main = diagram.routes.isEmpty ? null : diagram.routes.first;
  return LineStrip(
    totalMeters: at,
    segments: segments,
    startNode: main == null || main.stops.isEmpty ? null : main.stops.first.node,
    endNode: main == null || main.stops.isEmpty ? null : main.stops.last.node,
  );
}

/// 노선 단독 보기 (DESIGN §2.8 L). 탄 구간은 (노선, 구간) 크레딧 기준이다.
final class SoloLine {
  const SoloLine({required this.edges, required this.ridden, required this.groups, required this.nodes});

  final Set<int> edges;
  final Set<int> ridden;
  final Set<int> groups;
  final Set<String> nodes;
}

SoloLine soloLine(
  Network network,
  LineDiagram diagram, {
  required Map<int, String?> hits,
  bool carryover = true,
}) {
  final edges = <int>{};
  final ridden = <int>{};
  final groups = <int>{};
  final nodes = <String>{};
  final data = network.data;
  for (final route in diagram.routes) {
    for (final stop in route.stops) {
      nodes.add(stop.node);
      final group = data.groupNumbers[data.nodeGroups[stop.node]];
      if (group != null) groups.add(group);
    }
    for (final section in route.sections) {
      for (final id in section.edges) {
        final edge = network.edges[id]!;
        edges.add(edge.n);
        final unit = network.unitOf(diagram.lineId, id, carryover: carryover);
        if (unit != null && hits.containsKey(unit.n)) ridden.add(edge.n);
      }
    }
  }
  return SoloLine(edges: edges, ridden: ridden, groups: groups, nodes: nodes);
}

/// 이어진 구간을 하나로 합친다. 범위 지정과 켜기가 쓴다.
List<DiagramSection> joinSections(Iterable<DiagramSection> sections) {
  final joined = <DiagramSection>[];
  for (final section in sections) {
    final tail = joined.isEmpty ? null : joined.last;
    if (tail == null || tail.to != section.from || tail.routeId != section.routeId) {
      joined.add(section);
      continue;
    }
    joined[joined.length - 1] = DiagramSection(
      routeId: tail.routeId,
      from: tail.from,
      to: section.to,
      edges: [...tail.edges, ...section.edges],
      units: {...tail.units, ...section.units},
      meters: tail.meters + section.meters,
      gone: tail.gone && section.gone,
      ridden: tail.ridden || section.ridden,
      closed: tail.closed && section.closed,
      held: tail.held || section.held,
    );
  }
  return joined;
}

/// 켜기: 그 구간과 정확히 같은 삭제 조각 중 가장 최근 하나 (ARCHITECTURE §3.4).
Ride? restorableRide(
  Iterable<Ride> rides,
  Set<int> units, {
  required Network network,
  bool carryover = true,
}) {
  final interpreter = RideInterpreter(network);
  Ride? best;
  for (final ride in rides) {
    if (!ride.isDeleted) continue;
    if (best != null && ride.updatedAt <= best.updatedAt) continue;
    final derived = interpreter.ride(ride);
    if (derived.status != ResolveStatus.ok) continue;
    final got = {for (final hit in derived.edges) carryover ? hit.unitOn : hit.unitOff};
    if (got.length == units.length && got.containsAll(units)) best = ride;
  }
  return best;
}

/// 켜기에서 되살릴 조각이 없을 때: 그 구간만 있는 날짜 없는 기록. 끝은 통과다 (DESIGN §8.2).
///
/// 어느 방향으로도 그 구간이 나오지 않으면 null이다.
Ride? sectionRide(
  Network network,
  DiagramSection section, {
  required RideId id,
  required String lineLabel,
  required String fromLabel,
  required String toLabel,
  required String datasetVersion,
  required String deviceId,
  required int now,
}) {
  final interpreter = RideInterpreter(network);
  final route = network.routes[section.routeId]!;
  Ride build(String? direction, String? asOf) => Ride(
        rideId: id,
        legs: [
          RideLeg(
            seq: 0,
            lineId: LineId(route.lineId),
            routeId: RouteId(route.id),
            fromNode: NodeId(section.from),
            toNode: NodeId(section.to),
            direction: direction,
            resolveAsOf: asOf,
            lineLabel: lineLabel,
            fromLabel: fromLabel,
            toLabel: toLabel,
          ),
        ],
        datasetVersion: datasetVersion,
        createdAt: now,
        updatedAt: now,
        deviceId: deviceId,
        fromAlighted: false,
        toAlighted: false,
      );
  bool covers(Ride ride) {
    final derived = interpreter.ride(ride);
    if (derived.status != ResolveStatus.ok || derived.edges.isEmpty) return false;
    final want = {for (final edge in section.edges) network.edges[edge]!.n};
    return derived.edges.every((hit) => want.contains(hit.edge));
  }

  for (final direction in route.closed ? const [seqUp, seqDown] : const <String?>[null]) {
    final plain = build(direction, null);
    if (covers(plain)) return plain;
    // 평행 구간이면 가장 최근 경로로 잡는다
    final options = interpreter.expansions(plain).first.options;
    if (options.isNotEmpty) {
      final latest = build(direction, options.last.asOf);
      if (covers(latest)) return latest;
    }
  }
  return null;
}
