import '../date/date_rules.dart';
import '../date/date_span.dart';
import 'network_data.dart';

enum LifeState { open, suspended, maybeOpen, maybeSuspended, closed, before, unknown }

/// 이 계통으로 그날 탈 수 있는 구간인가.
enum Usable { ok, maybe, suspended, no }

/// 계통 안의 구간 하나. 순번은 역 순번과 다를 수 있어 그래프로 다룬다 (ARCHITECTURE §3.5).
final class RouteHop {
  const RouteHop(this.seq, this.edge, this.a, this.b);

  final int seq;
  final String edge;
  final String a;
  final String b;
}

PeriodState stateOfPeriod(DateSpan? date, NetPeriod p) => stateOn(
      date,
      fromLo: p.fromLo,
      fromHi: p.fromHi,
      toLo: p.toLo,
      toHi: p.toHi,
    );

/// 하루 전 날짜. 기간의 끝은 첫 무효일이다.
String dayBefore(String iso) {
  final day = DateTime.parse('${iso}T00:00:00Z').subtract(const Duration(days: 1));
  final mm = '${day.month}'.padLeft(2, '0');
  final dd = '${day.day}'.padLeft(2, '0');
  return '${'${day.year}'.padLeft(4, '0')}-$mm-$dd';
}

/// 판 하나의 선로망. 저장과 재해석이 같은 값을 본다.
final class Network {
  Network(this.data) {
    for (final route in data.routes) {
      routes[route.id] = route;
      (_lineRoutes[route.lineId] ??= []).add(route.id);
    }
    for (final edge in data.edges) {
      edges[edge.id] = edge;
    }
    for (final row in data.routeEdges) {
      final edge = edges[row.edgeId]!;
      (_routeHops[row.routeId] ??= []).add(RouteHop(row.seq, row.edgeId, edge.from, edge.to));
    }
    for (final stop in data.stops) {
      (_picks[stop.routeId] ??= []).add(stop);
      if (!stop.isExtension) {
        (_stops[stop.routeId] ??= []).add(stop);
        (_stopRoutes[stop.node] ??= {}).add(stop.routeId);
        if (stop.isStop && data.publicNodes.contains(stop.node)) _shown.add(stop.node);
      }
    }
    for (final attr in data.attrs) {
      (_attrs[attr.edgeId] ??= []).add(attr);
    }
    for (final life in data.lives) {
      (_life[life.edgeId] ??= []).add(life);
    }
    for (final unit in data.units) {
      (unit.carryover ? _unitsOn : _unitsOff)[unit.key] = unit;
    }
  }

  final NetworkData data;

  /// 지금 달리지 않는 구간의 정수 키. 타일의 `closed` 값과 같다.
  late final Set<int> closedEdges = () {
    final open = {
      for (final life in data.lives)
        if (life.period.toHi == null || life.period.toHi == DateSpan.maxDate) life.edgeId,
    };
    return {
      for (final edge in edges.values)
        if (!open.contains(edge.id)) edge.n,
    };
  }();

  /// 지금 영업하는 역이 하나라도 있는 역 묶음의 번호.
  late final Set<int> openGroups = () {
    final data = this.data;
    return {
      for (final route in routes.keys)
        for (final stop in stops(route))
          if (stop.isStop && (stop.period.toHi == null || stop.period.toHi == DateSpan.maxDate))
            ?data.groupNumbers[data.nodeGroups[stop.node]],
    };
  }();

  final Map<String, NetRoute> routes = {};
  final Map<String, NetEdge> edges = {};
  final Map<String, List<String>> _lineRoutes = {};
  final Map<String, List<RouteHop>> _routeHops = {};
  final Map<String, List<NetStop>> _picks = {};
  final Map<String, List<NetStop>> _stops = {};
  final Map<String, Set<String>> _stopRoutes = {};
  final Set<String> _shown = {};
  final Map<String, List<NetAttr>> _attrs = {};
  final Map<String, List<NetLife>> _life = {};
  final Map<String, NetUnit> _unitsOn = {};
  final Map<String, NetUnit> _unitsOff = {};

  List<RouteHop> hops(String routeId) => _routeHops[routeId] ?? const [];
  List<NetStop> stops(String routeId) => _stops[routeId] ?? const [];
  List<NetStop> picks(String routeId) => _picks[routeId] ?? const [];
  List<String> routesOfLine(String lineId) => _lineRoutes[lineId] ?? const [];
  Set<String> routesAt(String node) => _stopRoutes[node] ?? const {};

  /// 그 역에 서는 계통 전체. 묶음의 다른 node에 서는 계통도 같은 역이다 (DESIGN §2.8 B).
  /// 순서는 노선 표를 따른다. ID는 이름이라 순서에 뜻이 없다.
  List<String> routesAtStation(String node) {
    final group = data.nodeGroups[node];
    final rank = _lineRank;
    final routes = {
      ...routesAt(node),
      if (group != null)
        for (final other in _groupNodes[group]!) ...routesAt(other),
    }.toList();
    return routes
      ..sort((a, b) {
        final line = rank[this.routes[a]!.lineId]!.compareTo(rank[this.routes[b]!.lineId]!);
        return line != 0 ? line : a.compareTo(b);
      });
  }

  late final Map<String, int> _lineRank = {
    for (final (index, line) in data.lineOrder.indexed) line: index,
  };

  late final Map<String, List<String>> _groupNodes = () {
    final nodes = <String, List<String>>{};
    for (final MapEntry(:key, :value) in data.nodeGroups.entries) {
      (nodes[value] ??= []).add(key);
    }
    return nodes;
  }();

  /// 같은 역인가. 묶음이 있으면 묶음으로 본다 (DESIGN §2.8 B).
  bool sameStation(String a, String b) {
    final groups = data.nodeGroups;
    return a == b || (groups[a] != null && groups[a] == groups[b]);
  }

  /// 노선도에 그리는 역인가. 신호장과 분기점은 아니다.
  bool isShown(String node) => _shown.contains(node);

  List<NetAttr> attrsOfEdge(String edge) => _attrs[edge] ?? const [];

  int metersOf(Iterable<String> edgeIds) =>
      edgeIds.fold(0, (sum, id) => sum + edges[id]!.meters);

  LifeState lifeOn(String edge, DateSpan? date) {
    if (date == null) return LifeState.unknown;
    LifeState? best;
    var allBefore = true;
    for (final row in _life[edge] ?? const <NetLife>[]) {
      final state = stateOfPeriod(date, row.period);
      if (state != PeriodState.before) allBefore = false;
      if (state == PeriodState.yes) {
        best = row.suspended ? LifeState.suspended : LifeState.open;
      } else if (state == PeriodState.maybe) {
        best ??= row.suspended ? LifeState.maybeSuspended : LifeState.maybeOpen;
      }
    }
    if (best != null) return best;
    return allBefore ? LifeState.before : LifeState.closed;
  }

  /// 구간이 끝난 날. 아직 있으면 없다.
  String? endOf(String edge) {
    String? end;
    for (final row in _life[edge] ?? const <NetLife>[]) {
      final to = row.period.toHi;
      if (to == null || to == DateSpan.maxDate) return null;
      if (end == null || to.compareTo(end) > 0) end = to;
    }
    return end;
  }

  List<NetAttr> attrsOf(String edge, String lineId) => [
        for (final attr in attrsOfEdge(edge))
          if (attr.lineId == lineId) attr,
      ];

  /// 그날 노선을 맡은 회사들. 오이토선처럼 둘일 수 있다. 맡은 회사가 없으면 마지막 회사 하나다.
  List<String> operatorsOn(String lineId, DateSpan? date) {
    final running = <String>{};
    String? last;
    for (final attr in data.attrs) {
      if (attr.lineId != lineId) continue;
      last = attr.operatorId;
      if (stateOfPeriod(date, attr.period) == PeriodState.yes) running.add(attr.operatorId);
    }
    if (running.isNotEmpty) return running.toList();
    return [?last];
  }

  /// 그날의 (노선, 구간) 멤버십. 같은 사슬의 다른 노선까지 본다 (DESIGN §8).
  (NetAttr?, PeriodState) attrOn(String edge, String lineId, DateSpan? date) {
    final lineages = {for (final attr in attrsOf(edge, lineId)) attr.lineageId};
    (NetAttr, PeriodState)? hit;
    for (final attr in attrsOfEdge(edge)) {
      if (!lineages.contains(attr.lineageId)) continue;
      final state = stateOfPeriod(date, attr.period);
      if (state == PeriodState.yes) return (attr, PeriodState.yes);
      if (state == PeriodState.maybe) hit = (attr, PeriodState.maybe);
    }
    return hit ?? (null, PeriodState.unknown);
  }

  /// 그날 이 계통이 속한 노선. 이관 전 날짜면 같은 사슬의 앞 노선이다 (DESIGN §8).
  String lineOnDate(String routeId, DateSpan? date) {
    final line = routes[routeId]!.lineId;
    if (date == null) return line;
    for (final hop in hops(routeId)) {
      final (attr, state) = attrOn(hop.edge, line, date);
      if (attr != null && state == PeriodState.yes) return attr.lineId;
    }
    return line;
  }

  Usable edgeUsable(String routeId, String edge, DateSpan? date) {
    if (date == null) return Usable.ok;
    final life = lifeOn(edge, date);
    final (attr, state) = attrOn(edge, routes[routeId]!.lineId, date);
    return switch (life) {
      LifeState.suspended => Usable.suspended,
      LifeState.maybeSuspended => Usable.maybe,
      LifeState.before || LifeState.closed => Usable.no,
      _ when attr == null => Usable.no,
      LifeState.maybeOpen => Usable.maybe,
      _ when state == PeriodState.maybe => Usable.maybe,
      _ => Usable.ok,
    };
  }

  /// 구간 수명에서 나온 날짜들. 이설의 선택지를 만들 때 쓴다.
  Iterable<String> lifeDates(String routeId) sync* {
    for (final hop in hops(routeId)) {
      for (final row in _life[hop.edge] ?? const <NetLife>[]) {
        final from = row.period.fromLo;
        if (from != null) yield from;
        final to = row.period.toLo;
        if (to != null && to.compareTo(DateSpan.maxDate) < 0) yield dayBefore(to);
      }
    }
  }

  /// 기록한 (노선, 구간)의 단위. 승계 끔의 단위는 line_id가 이미 탑승일 기준이다.
  NetUnit? unitOf(String lineId, String edge, {required bool carryover}) {
    final rows = attrsOf(edge, lineId);
    if (rows.isEmpty) return null;
    final key = '${carryover ? rows.first.lineageId : rows.first.carryoverGroup}:$edge';
    return (carryover ? _unitsOn : _unitsOff)[key];
  }
}
