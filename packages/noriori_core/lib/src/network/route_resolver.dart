import '../date/date_rules.dart';
import '../date/date_span.dart';
import '../records/derived.dart';
import 'network.dart';

const seqUp = 'seq_up';
const seqDown = 'seq_down';

/// 왜 펼치지 못했는가. 화면의 안내와 재해석 판정이 이 값으로 갈린다.
enum ExpandReason {
  sameNode,
  noPathOnDate,
  noPathEver,
  notClosedOnDate,
  noSuchDirection,
  ambiguousPath,
  relocatedParallel,
}

/// 이설 구간의 선택지. edge 조합이 아니라 실제로 존재한 시점의 경로다 (DESIGN §2.8 D).
final class RelocationOption {
  const RelocationOption({required this.asOf, required this.meters});

  final String asOf;
  final int meters;
}

/// 그날 노선으로 맞춘 구간 묶음.
final class ExpandedLeg {
  const ExpandedLeg({required this.lineId, required this.routeId, required this.edges, this.from, this.to});

  final String lineId;
  final String routeId;
  final List<String> edges;

  /// 계통을 넘는 경로에서 이 구간의 양 끝.
  final String? from;
  final String? to;
}

/// 펼친 결과.
final class Expansion {
  const Expansion({
    required this.status,
    this.edges = const [],
    this.nodes = const [],
    this.legs = const [],
    this.meters,
    this.date,
    this.direction,
    this.reason,
    this.options = const [],
    this.distances = const [],
    this.demoted = false,
  });

  final ResolveStatus status;
  final List<String> edges;
  final List<String> nodes;
  final List<ExpandedLeg> legs;
  final int? meters;

  /// 펼칠 때 쓴 날짜.
  final DateSpan? date;
  final String? direction;
  final ExpandReason? reason;
  final List<RelocationOption> options;

  /// 경로가 갈릴 때 경로별 거리.
  final List<int> distances;

  /// 그날 경로가 없어 날짜 모름으로 내렸는가.
  final bool demoted;

  bool get saved => status == ResolveStatus.ok || status == ResolveStatus.partial;

  /// 아직 답이 없어 크레딧을 못 준 거리. 갈리는 경로 중 가장 짧은 쪽으로 센다.
  int get pendingMeters {
    final ways = [...distances, for (final option in options) option.meters];
    if (ways.isEmpty) return 0;
    final shortest = ways.reduce((a, b) => a < b ? a : b);
    final left = shortest - (meters ?? 0);
    return left < 0 ? 0 : left;
  }

  Expansion copyWith({bool? demoted, List<int>? distances}) => Expansion(
        status: status,
        edges: edges,
        nodes: nodes,
        legs: legs,
        meters: meters,
        date: date,
        direction: direction,
        reason: reason,
        options: options,
        distances: distances ?? this.distances,
        demoted: demoted ?? this.demoted,
      );
}

typedef _Hop = ({String from, String edge, String to});
typedef _Link = ({String edge, String a, String b});

/// 탑승 펼치기 (ARCHITECTURE §3.3 `RouteResolver`). 기준은 `tools/appsim.py`의 `App`이다.
final class RouteResolver {
  const RouteResolver(this.network);

  final Network network;

  static const _pathLimit = 64;

  /// 저장 흐름. 그날 경로가 없으면 날짜 모름으로 내려 저장한다 (DESIGN §4.6).
  Expansion record(
    String routeId,
    String a,
    String b, {
    DateSpan? date,
    String? direction,
    DateSpan? asOf,
    bool resolveUnknown = false,
    bool askDirection = false,
  }) {
    final day = normalizeRideDate(date);
    var result = expandAny(routeId, a, b,
        date: day,
        direction: direction,
        asOf: asOf,
        resolveUnknown: resolveUnknown,
        askDirection: askDirection);
    var demoted = date != null && day == null;
    if (result.status == ResolveStatus.invalid &&
        day != null &&
        (result.reason == ExpandReason.noPathOnDate ||
            result.reason == ExpandReason.notClosedOnDate)) {
      result = expandAny(routeId, a, b,
          direction: direction,
          asOf: asOf,
          resolveUnknown: resolveUnknown,
          askDirection: askDirection);
      demoted = true;
    }
    return result.copyWith(demoted: demoted);
  }

  /// 선택기에서 고른 두 역을 펼친다. 연장 역이면 그 역이 속한 계통으로 나눈다 (DESIGN §2.7).
  Expansion expandAny(
    String routeId,
    String a,
    String b, {
    DateSpan? date,
    String? direction,
    DateSpan? asOf,
    bool resolveUnknown = false,
    bool askDirection = false,
  }) {
    Expansion plain(String x, String y) => expand(routeId, x, y,
        date: date,
        direction: direction,
        asOf: asOf,
        resolveUnknown: resolveUnknown,
        askDirection: askDirection);
    final route = network.routes[routeId];
    if (route == null) return const Expansion(status: ResolveStatus.unknownRef);
    final extension = route.extendTo.toSet();
    if (!extension.contains(a) && !extension.contains(b)) return plain(a, b);
    final here = {
      for (final hop in network.hops(routeId)) ...[hop.a, hop.b],
    };
    final parents = <String>[];
    for (final node in {a, b}.intersection(extension)) {
      for (final other in network.routesAt(node)) {
        if (other == routeId) continue;
        if (network.stops(other).any((s) => here.contains(s.node))) parents.add(other);
      }
    }
    if (parents.isNotEmpty) {
      final crossed = _expandCross(a, b, date, [routeId, ...parents]);
      if (crossed.status == ResolveStatus.ok) return crossed;
    }
    // 부모 계통이 숨은 끝을 지나지 않는 연결선: 연장 역까지는 거리 없이 계통 안의 구간만 펼친다
    final stops = network.stops(routeId);
    final picked = {for (final stop in network.picks(routeId)) stop.node: stop.seq};
    String anchor(String node) {
      if (!extension.contains(node) || stops.any((s) => s.node == node)) return node;
      return picked[node]! < stops.first.seq ? stops.first.node : stops.last.node;
    }

    return plain(anchor(a), anchor(b));
  }

  Expansion expand(
    String routeId,
    String a,
    String b, {
    DateSpan? date,
    String? direction,
    DateSpan? asOf,
    bool resolveUnknown = false,

    /// 재해석은 닫힌 계통이라도 짧은 쪽을 고르지 않고 답을 기다린다 (ARCHITECTURE §7.2).
    bool askDirection = false,
  }) {
    final route = network.routes[routeId];
    if (route == null) return const Expansion(status: ResolveStatus.unknownRef);
    // 하루로 정해진 날짜가 as_of를 이긴다
    final day = normalizeRideDate(date != null && date.isDay ? date : (asOf ?? date));
    final all = network.hops(routeId);
    if (a == b) {
      if (route.closed && (direction == seqUp || direction == seqDown)) {
        return lap(routeId, a, date: day, direction: direction!);
      }
      return const Expansion(status: ResolveStatus.invalid, reason: ExpandReason.sameNode, meters: 0);
    }
    final usable = <_Link>[];
    for (final hop in all) {
      final state = network.edgeUsable(routeId, hop.edge, day);
      if (state == Usable.ok || state == Usable.maybe) {
        usable.add((edge: hop.edge, a: hop.a, b: hop.b));
      }
    }
    final paths = _simplePaths(a, b, usable);
    if (paths.isEmpty) {
      final any = _simplePaths(a, b, [
        for (final hop in all) (edge: hop.edge, a: hop.a, b: hop.b),
      ]);
      return Expansion(
        status: ResolveStatus.invalid,
        date: day,
        reason: any.isEmpty ? ExpandReason.noPathEver : ExpandReason.noPathOnDate,
      );
    }
    // 평행 구간(이설)으로 갈린 경로와 방향으로 갈린 경로를 구분한다
    final groups = <String, List<List<_Hop>>>{};
    for (final path in paths) {
      (groups[path.map((h) => h.from).join('\u0000')] ??= []).add(path);
    }
    var keys = groups.keys.toList();
    if (keys.length > 1) {
      if (direction == seqUp || direction == seqDown) {
        keys = [
          for (final key in keys)
            if (_direction(routeId, groups[key]!.first) == direction) key,
        ];
        if (keys.isEmpty) {
          return const Expansion(
            status: ResolveStatus.invalid,
            reason: ExpandReason.noSuchDirection,
          );
        }
      } else if (direction == null && route.closed && !askDirection) {
        int length(String key) => network.metersOf(groups[key]!.first.map((h) => h.edge));
        keys = [_minBy(keys, length)]; // 기본은 짧은 쪽 (DESIGN §8)
      } else {
        final distances = [
          for (final key in keys) network.metersOf(groups[key]!.first.map((h) => h.edge)),
        ];
        if (resolveUnknown) {
          return _common(routeId, [for (final key in keys) ...groups[key]!], day, distances);
        }
        return Expansion(
          status: ResolveStatus.needsInput,
          reason: ExpandReason.ambiguousPath,
          distances: distances,
        );
      }
    }
    final chosen = groups[keys.first]!;
    if (chosen.length > 1) {
      if (resolveUnknown) {
        return _common(routeId, chosen, day, [
          for (final path in chosen) network.metersOf(path.map((h) => h.edge)),
        ]);
      }
      return Expansion(
        status: ResolveStatus.needsInput,
        reason: ExpandReason.relocatedParallel,
        options: relocationOptions(routeId, a, b),
      );
    }
    return _result(
      routeId,
      [for (final hop in chosen.first) hop.edge],
      day,
      ResolveStatus.ok,
      chosen.first,
    );
  }

  /// 닫힌 계통 한 바퀴. 올가미는 고리 부분만 돈다 (DESIGN §2.8 G).
  Expansion lap(String routeId, String start, {DateSpan? date, String direction = seqUp}) {
    final ring = ringNodes(routeId);
    final stops = network.stops(routeId);
    final candidates = <String, List<String>>{};
    for (final hop in network.hops(routeId)) {
      (candidates[_pair(hop.a, hop.b)] ??= []).add(hop.edge);
    }
    final edges = <String>[];
    final nodes = <String>[];
    for (var i = 0; i + 1 < stops.length; i++) {
      final p = stops[i].node;
      final q = stops[i + 1].node;
      if (!ring.contains(p) || !ring.contains(q)) continue;
      final open = [
        for (final edge in candidates[_pair(p, q)] ?? const <String>[])
          if (_ridable(network.edgeUsable(routeId, edge, date))) edge,
      ];
      if (open.isEmpty) {
        return const Expansion(
          status: ResolveStatus.invalid,
          reason: ExpandReason.notClosedOnDate,
        );
      }
      if (nodes.isEmpty) nodes.add(p);
      nodes.add(q);
      edges.add(open.first);
    }
    final (ordered, path) = _fromStart(edges, nodes, start, direction);
    return Expansion(
      status: ResolveStatus.ok,
      edges: ordered,
      nodes: path,
      meters: network.metersOf(edges),
      date: date,
      direction: direction,
      legs: _align(routeId, ordered, date),
    );
  }

  /// 고리를 고른 역에서 시작하게 돌린다. 승하차 판정이 경로의 양 끝을 본다.
  (List<String>, List<String>) _fromStart(
    List<String> edges,
    List<String> nodes,
    String start,
    String direction,
  ) {
    final at = nodes.indexOf(start);
    final ring = nodes.isNotEmpty && nodes.first == nodes.last;
    final turned = at <= 0 || !ring
        ? (edges, nodes)
        : (
            [...edges.sublist(at), ...edges.sublist(0, at)],
            [...nodes.sublist(at, nodes.length - 1), ...nodes.sublist(0, at), start],
          );
    if (direction != seqDown) return turned;
    return (turned.$1.reversed.toList(), turned.$2.reversed.toList());
  }

  /// 계통 그래프의 고리. 꼬리(올가미의 放射部)를 떼어 낸다.
  Set<String> ringNodes(String routeId) {
    final adjacent = <String, Set<String>>{};
    for (final hop in network.hops(routeId)) {
      (adjacent[hop.a] ??= {}).add(hop.b);
      (adjacent[hop.b] ??= {}).add(hop.a);
    }
    final alive = adjacent.keys.toSet();
    var changed = true;
    while (changed) {
      changed = false;
      for (final node in alive.toList()) {
        if (adjacent[node]!.intersection(alive).length < 2) {
          alive.remove(node);
          changed = true;
        }
      }
    }
    return alive;
  }

  List<RelocationOption> relocationOptions(String routeId, String a, String b) {
    final dates = network.lifeDates(routeId).toSet().toList()..sort();
    final seen = <String, RelocationOption>{};
    for (final date in dates) {
      if (date.compareTo(floorDate) < 0) continue;
      final result = expand(routeId, a, b, date: DateSpan.parse(date));
      if (result.status == ResolveStatus.ok) {
        final key = ([...result.edges]..sort()).join(',');
        seen.putIfAbsent(key, () => RelocationOption(asOf: date, meters: result.meters!));
      }
    }
    return seen.values.toList();
  }

  bool _ridable(Usable state) => state == Usable.ok || state == Usable.maybe;

  String _pair(String a, String b) =>
      a.compareTo(b) < 0 ? '$a\u0000$b' : '$b\u0000$a';

  T _minBy<T>(List<T> items, int Function(T) key) {
    var best = items.first;
    var bestKey = key(best);
    for (final item in items.skip(1)) {
      final value = key(item);
      if (value < bestKey) {
        best = item;
        bestKey = value;
      }
    }
    return best;
  }

  /// 무향 다중 그래프에서 a→b 단순 경로.
  List<List<_Hop>> _simplePaths(String a, String b, List<_Link> links) {
    final graph = <String, List<(String, String)>>{};
    for (final link in links) {
      (graph[link.a] ??= []).add((link.b, link.edge));
      (graph[link.b] ??= []).add((link.a, link.edge));
    }
    final results = <List<_Hop>>[];
    final seen = <String>{a};
    final path = <_Hop>[];
    void walk(String node) {
      if (results.length >= _pathLimit) return;
      if (node == b && path.isNotEmpty) {
        results.add(List.of(path));
        return;
      }
      for (final (next, edge) in graph[node] ?? const <(String, String)>[]) {
        if (!seen.add(next)) continue;
        path.add((from: node, edge: edge, to: next));
        walk(next);
        path.removeLast();
        seen.remove(next);
      }
    }

    walk(a);
    return results;
  }

  /// 올가미는 고리 위의 첫 구간으로 판정한다.
  String _direction(String routeId, List<_Hop> path) {
    final stops = network.stops(routeId);
    final next = <String, Set<String>>{};
    for (var i = 0; i + 1 < stops.length; i++) {
      (next[stops[i].node] ??= {}).add(stops[i + 1].node);
    }
    final route = network.routes[routeId]!;
    if (route.fromNode == route.toNode) {
      (next[stops.last.node] ??= {}).add(stops.first.node);
    }
    final ring = ringNodes(routeId);
    final hop = path.firstWhere(
      (h) => ring.contains(h.from) && ring.contains(h.to),
      orElse: () => path.first,
    );
    return (next[hop.from] ?? const {}).contains(hop.to) ? seqUp : seqDown;
  }

  List<ExpandedLeg> _align(String routeId, List<String> edges, DateSpan? date) {
    final line = network.routes[routeId]!.lineId;
    final byLine = <String, List<String>>{};
    for (final edge in edges) {
      (byLine[_lineOn(edge, line, date)] ??= []).add(edge);
    }
    return [
      for (final MapEntry(:key, :value) in byLine.entries)
        ExpandedLeg(lineId: key, routeId: routeId, edges: value),
    ];
  }

  /// 그날의 노선. 이관 날짜에 걸친 범위 날짜면 입력한 노선을 유지한다 (DESIGN §2.8 J).
  String _lineOn(String edge, String line, DateSpan? date) {
    if (date == null) return line;
    final (attr, state) = network.attrOn(edge, line, date);
    if (attr == null) return line;
    if (state == PeriodState.yes) return attr.lineId;
    final mine = network.attrsOf(edge, line).any((row) {
      final overlap = stateOfPeriod(date, row.period);
      return overlap == PeriodState.yes || overlap == PeriodState.maybe;
    });
    return mine ? line : attr.lineId;
  }

  /// `모름`이라고 답한 구간. 어느 경로든 지나는 곳만 크레딧을 준다 (DESIGN §2.8 D).
  Expansion _common(String routeId, List<List<_Hop>> paths, DateSpan? day, List<int> distances) {
    final common = paths.first.map((h) => h.edge).toSet();
    for (final path in paths.skip(1)) {
      common.retainAll(path.map((h) => h.edge));
    }
    return _result(
      routeId,
      [
        for (final hop in paths.first)
          if (common.contains(hop.edge)) hop.edge,
      ],
      day,
      ResolveStatus.partial,
      paths.first,
    ).copyWith(distances: distances);
  }

  Expansion _result(
    String routeId,
    List<String> edges,
    DateSpan? date,
    ResolveStatus status,
    List<_Hop> path,
  ) =>
      Expansion(
        status: status,
        edges: edges,
        nodes: [path.first.from, for (final hop in path) hop.to],
        legs: _align(routeId, edges, date),
        meters: network.metersOf(edges),
        date: date,
        direction: _direction(routeId, path),
      );

  /// 같은 노선 안에서 계통을 넘는다 (DESIGN §2.8 F). 지선 역에서 본선 역으로 가는 경우다.
  Expansion across(String lineId, String a, String b, {DateSpan? date}) {
    final routes = network.routesOfLine(lineId).toList();
    final day = normalizeRideDate(date);
    final result = _expandCross(a, b, day, routes);
    if (result.status != ResolveStatus.invalid || day == null) {
      return result.copyWith(demoted: date != null && day == null);
    }
    return _expandCross(a, b, null, routes).copyWith(demoted: true);
  }

  /// 숨은 노드 경계 자동 분할 (DESIGN §2.8 F). 후보 계통을 합친 그래프에서 찾는다.
  Expansion _expandCross(String a, String b, DateSpan? date, List<String> routeIds) {
    final day = normalizeRideDate(date);
    final links = <_Link>[];
    final owner = <String, String>{};
    for (final routeId in routeIds) {
      for (final hop in network.hops(routeId)) {
        if (_ridable(network.edgeUsable(routeId, hop.edge, day))) {
          links.add((edge: hop.edge, a: hop.a, b: hop.b));
          owner[hop.edge] = routeId;
        }
      }
    }
    final paths = _simplePaths(a, b, links);
    if (paths.isEmpty) return const Expansion(status: ResolveStatus.invalid);
    final path = _minBy(paths, (p) => network.metersOf(p.map((h) => h.edge)));
    // 본선에서 지선을 거쳐 본선으로 돌아오면 세 구간이다. 지나간 순서대로 나눈다
    final pieces = <List<_Hop>>[];
    for (final hop in path) {
      if (pieces.isEmpty || owner[pieces.last.last.edge] != owner[hop.edge]) pieces.add([]);
      pieces.last.add(hop);
    }
    final edges = [for (final hop in path) hop.edge];
    return Expansion(
      status: ResolveStatus.ok,
      edges: edges,
      nodes: [path.first.from, for (final hop in path) hop.to],
      legs: [
        for (final piece in pieces)
          ExpandedLeg(
            lineId: network.routes[owner[piece.first.edge]!]!.lineId,
            routeId: owner[piece.first.edge]!,
            edges: [for (final hop in piece) hop.edge],
            from: piece.first.from,
            to: piece.last.to,
          ),
      ],
      meters: network.metersOf(edges),
      date: day,
    );
  }
}
