import '../date/date_rules.dart';
import '../date/date_span.dart';
import 'network_data.dart';

enum LifeState { open, suspended, maybeOpen, maybeSuspended, closed, before, unknown }

/// 이 계통으로 그날 탈 수 있는 구간인가.
enum Usable {
  ok,
  maybe,
  suspended,
  no;

  /// 경로를 찾을 때 지나갈 수 있다. 애매한 구간도 지난다.
  bool get ridable => this == ok || this == maybe;
}

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

/// 끝이 없는 정차 공백(재개 미정의 정차 운휴, 陸羽西線 羽前前波 2022~). 그 날(날짜를 모르면 지금) 운휴 중이면 그 공백이다.
/// 노선 운휴와 같게 「운휴」다. 앞뒤 칸이 운행 중인지는 칸 수명(edge_life)이 따로 안다 (사용자 결정 2026-11-16)
NetPeriod? openStopGap(DateSpan? date, NetStop stop) {
  for (final gap in stop.gaps) {
    // 끝 없는 공백은 끝이 ongoing(가장 늦은 날)이다
    if (gap.toLo != null && gap.toLo!.compareTo(DateSpan.maxDate) < 0) continue;
    if (date == null || date.lo.compareTo(gap.fromHi ?? DateSpan.maxDate) >= 0) return gap;
  }
  return null;
}

/// 그 날짜 범위 전체가 정차 기간 사이 서지 않은 때에 드는가. 걸치기만 하면 거짓이다.
bool inStopGap(DateSpan date, NetStop stop) => stop.gaps.any(
      (gap) => date.lo.compareTo(gap.fromHi ?? DateSpan.maxDate) >= 0 && date.hi.compareTo(gap.toLo ?? '0000-01-01') < 0,
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
      (_stops[stop.routeId] ??= []).add(stop);
      (_stopRoutes[stop.node] ??= {}).add(stop.routeId);
      if (stop.isStop && data.publicNodes.contains(stop.node)) _shown.add(stop.node);
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
    for (final row in data.oneWays) {
      (_oneWay['${row.routeId}\u0000${row.edgeId}'] ??= []).add(row);
    }
    for (final row in data.stopDirections) {
      (_stopDirection['${row.routeId}\u0000${row.node}'] ??= []).add(row);
    }
  }

  final Map<String, List<NetOneWay>> _oneWay = {};

  /// 한 방향 칸이 있는 계통인가.
  bool hasOneWay(String routeId) => _oneWayRoutes.contains(routeId);
  late final Set<String> _oneWayRoutes = {for (final row in data.oneWays) row.routeId};
  final Map<String, List<NetStopDirection>> _stopDirection = {};

  /// 그 계통에서 그 칸을 [from]에서 [to]로 지날 수 있는가 (DESIGN §8 한 방향 운행).
  /// 날짜를 모르면 그 칸이 있던 모든 날에 반대 방향이 막혀 있을 때만 막는다.
  bool passable(String routeId, String edge, String from, String to, DateSpan? date) {
    final rows = _oneWay['$routeId\u0000$edge'];
    if (rows == null) return true;
    final against = [for (final row in rows) if (row.from != from || row.to != to) row.period];
    if (against.isEmpty) return true;
    if (date != null) return !against.any((period) => stateOfPeriod(date, period) == PeriodState.yes);
    final life = _life[edge] ?? const <NetLife>[];
    if (life.isEmpty) return true;
    return !_coversAll(against, [for (final row in life) row.period]);
  }

  /// 그 계통에서 그 칸이 그날 한 방향이면 지나는 방향(앞 노드, 뒤 노드). 날짜를 모르면 [passable]과 같은 기준이다.
  (String, String)? oneWayOf(String routeId, String edge, DateSpan? date) {
    final rows = _oneWay['$routeId\u0000$edge'];
    if (rows == null) return null;
    for (final row in rows) {
      if (!passable(routeId, edge, row.to, row.from, date)) return (row.from, row.to);
    }
    return null;
  }

  /// 그 계통에서 이웃한 두 역 사이 칸이 그날 모두 한 방향이면 그 방향(참이면 [p]에서 [q]로). 아니면 null이다.
  /// 다른 역은 지나지 않고 숨은 노드만 거친다. 노선 일람의 갈매기표에 쓴다 (DESIGN §8 한 방향 운행).
  bool? oneWayBetween(String routeId, String p, String q, DateSpan? date) {
    if (!hasOneWay(routeId) || p == q) return null;
    final others = {for (final stop in stops(routeId)) stop.node}..removeAll([p, q]);
    final next = <String, List<RouteHop>>{};
    for (final hop in hops(routeId)) {
      (next[hop.a] ??= []).add(hop);
      (next[hop.b] ??= []).add(hop);
    }
    final back = <String, (String, String)>{p: ('', '')};
    final queue = [p];
    for (var at = 0; at < queue.length && !back.containsKey(q); at++) {
      final node = queue[at];
      for (final hop in next[node] ?? const <RouteHop>[]) {
        final other = hop.a == node ? hop.b : hop.a;
        if (back.containsKey(other) || others.contains(other)) continue;
        back[other] = (node, hop.edge);
        queue.add(other);
      }
    }
    if (!back.containsKey(q)) return null;
    bool? way;
    for (var node = q; node != p;) {
      final (prev, edge) = back[node]!;
      final one = oneWayOf(routeId, edge, date);
      final forward = one == null ? null : (one.$1 == prev ? true : (one.$1 == node ? false : null));
      if (forward == null || (way != null && way != forward)) return null;
      way = forward;
      node = prev;
    }
    return way;
  }

  /// 그 역이 그날 한 방향 열차만 받으면 그 행. 날짜를 모르면 그 정차가 있던 모든 날에 걸릴 때만이다 (DESIGN §8 한 방향 정차).
  NetStopDirection? stopDirectionOf(String routeId, String node, DateSpan? date) {
    final rows = _stopDirection['$routeId\u0000$node'];
    if (rows == null) return null;
    if (date != null) {
      for (final row in rows) {
        if (stateOfPeriod(date, row.period) == PeriodState.yes) return row;
      }
      return null;
    }
    final life = [
      for (final stop in stops(routeId))
        if (stop.node == node && stop.isStop) stop.period,
    ];
    if (life.isEmpty) return null;
    for (final direction in const ['seq_up', 'seq_down']) {
      final same = [for (final row in rows) if (row.direction == direction) row];
      if (same.isNotEmpty && _coversAll([for (final row in same) row.period], life)) return same.first;
    }
    return null;
  }

  /// [cover] 기간들을 이으면 [life]의 처음부터 끝까지를 모두 덮는가. 범위로 적힌 끝은 좁은 쪽으로 본다.
  static bool _coversAll(List<NetPeriod> cover, List<NetPeriod> life) {
    final start = life.map((p) => p.fromLo ?? '0000-01-01').reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
    final end = life.map((p) => p.toHi ?? DateSpan.maxDate).reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
    final spans = [
      for (final p in cover) (p.fromHi ?? p.fromLo ?? '0000-01-01', p.toLo ?? p.toHi ?? DateSpan.maxDate),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    var reached = start;
    for (final (from, to) in spans) {
      if (from.compareTo(reached) > 0) return false;
      if (to.compareTo(reached) > 0) reached = to;
      if (reached.compareTo(end) >= 0) return true;
    }
    return reached.compareTo(end) >= 0;
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

  /// 이 판의 선로에 있는 역인가.
  bool knowsNode(String node) => _nodes.contains(node);
  late final Set<String> _nodes = {for (final edge in edges.values) ...[edge.from, edge.to]};
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

  /// 노선의 계통을 본선부터 늘어놓는다. 노선도와 가로 띠가 이 순서로 잇는다.
  List<String> routesOfLineMainFirst(String lineId) => routesOfLine(lineId).toList()
    ..sort((a, b) {
      final x = routes[a]!.role == 'main' ? 0 : 1;
      final y = routes[b]!.role == 'main' ? 0 : 1;
      return x.compareTo(y);
    });
  Set<String> routesAt(String node) => _stopRoutes[node] ?? const {};

  /// 계통 안에서 두 노드를 바로 잇는 구간. 방향은 보지 않고 계통의 순서를 따른다.
  List<String> edgesBetween(String routeId, String a, String b) =>
      (_pairEdges[routeId] ??= _pairsOf(routeId))[_pair(a, b)] ?? const [];
  final Map<String, Map<String, List<String>>> _pairEdges = {};

  Map<String, List<String>> _pairsOf(String routeId) {
    final byPair = <String, List<String>>{};
    for (final hop in hops(routeId)) {
      (byPair[_pair(hop.a, hop.b)] ??= []).add(hop.edge);
    }
    return byPair;
  }

  String _pair(String a, String b) => a.compareTo(b) < 0 ? '$a\u0000$b' : '$b\u0000$a';

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

  /// 이 노선에서 이 역의 km가 추정값인가. 그 역에서 타거나 내린 기록은 km를 `?`로 보인다 (DESIGN §4.5).
  bool kmEstimatedOn(String? lineId, String? node) =>
      lineId != null && node != null && _estimated.contains('$lineId|$node');
  /// 양 끝 중 하나라도 km가 추정값인 구간. 화면의 km는 `?`다 (DESIGN §4.5).
  bool kmEstimatedBetween(String? lineId, String? from, String? to) =>
      kmEstimatedOn(lineId, from) || kmEstimatedOn(lineId, to);
  late final Set<String> _estimated = {
    for (final stop in data.stops)
      if (stop.kmEstimated) '${routes[stop.routeId]?.lineId}|${stop.node}',
  };

  List<NetAttr> attrsOfEdge(String edge) => _attrs[edge] ?? const [];

  /// 노선을 주면 그 노선 시대의 길이다. 3섹 전환 때 km가 바뀐 구간은 국철·JR 노선에서 옛 km다
  int metersOf(Iterable<String> edgeIds, {String? lineId}) => edgeIds.fold(
        0,
        (sum, id) => sum + ((lineId == null ? null : data.eraMeters['$lineId\u0000$id']) ?? edges[id]!.meters),
      );

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

  List<NetLife> livesOf(String edge) => _life[edge] ?? const [];

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
  /// 그날 이 계통 노선이 가진 칸이 하나라도 있으면 그 노선이다. 첫 칸만 보면 넘겨준 옛 구간이 계통 머리에 있을 때
  /// (徳島線 三縄–阿波池田, 1935부터 土讃線) 오늘 화면이 土讃線으로 나왔다 (2026-11-21)
  String lineOnDate(String routeId, DateSpan? date) {
    final line = routes[routeId]!.lineId;
    if (date == null) return line;
    String? other;
    for (final hop in hops(routeId)) {
      final (attr, state) = attrOn(hop.edge, line, date);
      if (attr == null || state != PeriodState.yes) continue;
      if (attr.lineId == line) return line;
      other ??= attr.lineId;
    }
    return other ?? line;
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
