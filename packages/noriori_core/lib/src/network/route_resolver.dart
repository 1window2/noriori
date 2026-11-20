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

  /// 한 방향으로만 다니는 칸을 거꾸로 지나야 한다 (DESIGN §8 한 방향 운행).
  oneWay,

  /// 고른 역이 그 방향 열차의 승하차를 받지 않는다 (DESIGN §8 한 방향 정차).
  stopDirection,
}

/// 이설 구간의 선택지. edge 조합이 아니라 실제로 존재한 시점의 경로다 (DESIGN §2.8 D).
final class RelocationOption {
  const RelocationOption({required this.asOf, required this.meters, this.until});

  final String asOf;
  final int meters;

  /// 이 길이 그날 길이 아니게 된 날. 지금도 쓰는 길이면 없다. 고르는 창에 존속 기간으로 적는다.
  final String? until;
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
    this.around = false,
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

  /// 한 방향 운행 때문에 짧은 쪽이 아니라 돌아가는 길로 펼쳤는가 (DESIGN §8 한 방향 운행).
  final bool around;

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
        around: around,
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

  /// 선택기에서 고른 두 역을 펼친다. 계통 끝은 승하차 불가 끝 노드까지라 그 계통 안에서 펼친다 (5번 결정 2026-11-19).
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
    return plain(a, b);
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

    /// 선형 목록을 만드는 중이다. 그날도 평행 선형이 둘이면 다시 목록을 만들지 않는다 (무한 재귀 방지).
    bool listing = false,
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
    final usable = <_Link>[
      for (final hop in all)
        if (network.edgeUsable(routeId, hop.edge, day).ridable) (edge: hop.edge, a: hop.a, b: hop.b),
    ];
    bool pass(String edge, String from, String to) => network.passable(routeId, edge, from, to, day);
    var paths = _simplePaths(a, b, usable, pass: pass);
    // 한 방향 칸 때문에만 길이 없으면 그 이유로 알린다 (DESIGN §8 한 방향 운행)
    if (paths.isEmpty && _simplePaths(a, b, usable).isNotEmpty) {
      return Expansion(status: ResolveStatus.invalid, date: day, reason: ExpandReason.oneWay);
    }
    // 날짜를 모르면 모든 칸이 함께 있던 날이 있는 경로만 남긴다. 그런 경로가 없으면(옛 자리 갈래와 새 선로 사이) 그대로 둔다 (appsim과 같음)
    var dated = false;
    if (day == null) {
      final together = paths.where(_oneDay).toList();
      if (together.isNotEmpty) paths = together;
      dated = together.isNotEmpty;
    }
    if (paths.isEmpty) {
      // 판에 없는 역은 데이터가 모르는 ID다. 길이 없는 것과 달리 판이 바뀌면 풀릴 수 있다 (DESIGN §2.8 상태표)
      if (!network.knowsNode(a) || !network.knowsNode(b)) return const Expansion(status: ResolveStatus.unknownRef);
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
    // 고리는 닫힌 계통에만 있다. 날짜를 모를 때 열린 계통에서 갈린 경로가 저마다 한날에 있던 길이면, 거치는 역이 달라도 옛·새 선형이다
    // (실화면 검수 2026-11-08, 常磐線 相馬–浜吉田). 옛 자리와 새 자리 사이처럼 그런 길이 없으면 고를 시기가 없어 방향으로 묻는다
    if (keys.length > 1 && !route.closed && dated) {
      groups[keys.first] = [for (final key in keys) ...groups[key]!];
      keys = [keys.first];
    }
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
    // 한 방향 순환에서 운행 반대 방향을 골랐으면 길이 하나만 남아도 받지 않는다 (DESIGN §8 한 방향 운행)
    if (route.closed &&
        (direction == seqUp || direction == seqDown) &&
        network.hasOneWay(routeId) &&
        _direction(routeId, groups[keys.first]!.first) != direction) {
      return Expansion(status: ResolveStatus.invalid, date: day, reason: ExpandReason.oneWay);
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
        options: listing ? const [] : relocationOptions(routeId, a, b),
      );
    }
    final result = _result(
      routeId,
      [for (final hop in chosen.first) hop.edge],
      day,
      ResolveStatus.ok,
      chosen.first,
    );
    if (_refuses(routeId, a, b, route.closed ? result.direction! : _seqDirection(routeId, a, b), day)) {
      return Expansion(status: ResolveStatus.invalid, date: day, reason: ExpandReason.stopDirection);
    }
    // 순환에서 방향을 정하지 않았는데 한 방향 운행이 짧은 쪽을 막았으면 돌아가는 길이다
    if (route.closed && direction == null && !listing && network.hasOneWay(routeId)) {
      final free = _simplePaths(a, b, usable);
      final shortest = free.isEmpty ? null : free.map((p) => network.metersOf(p.map((h) => h.edge))).reduce((x, y) => x < y ? x : y);
      if (shortest != null && shortest < network.metersOf(result.edges)) {
        return Expansion(
          status: result.status,
          edges: result.edges,
          nodes: result.nodes,
          legs: result.legs,
          meters: result.meters,
          date: result.date,
          direction: result.direction,
          around: true,
        );
      }
    }
    return result;
  }

  /// 열린 계통에서 a에서 b로 가는 방향. 역 순번이 커지면 `seq_up`이다.
  String _seqDirection(String routeId, String a, String b) {
    final stops = network.stops(routeId);
    final from = stops.indexWhere((stop) => stop.node == a);
    final to = stops.indexWhere((stop) => stop.node == b);
    return to > from ? seqUp : seqDown;
  }

  /// 고른 두 역 중 하나라도 그 방향 열차의 승하차를 받지 않는가 (DESIGN §8 한 방향 정차).
  bool _refuses(String routeId, String a, String b, String direction, DateSpan? day) =>
      _refusesAt(routeId, a, direction, day, departing: true) || _refusesAt(routeId, b, direction, day, departing: false);

  /// 그 역이 그 방향·그 쪽(출발 또는 도착)의 승하차를 받지 않는가. 내리기만 하는 역(仮降車場)은 출발역이 될 수 없다.
  bool _refusesAt(String routeId, String node, String direction, DateSpan? day, {required bool departing}) {
    final row = network.stopDirectionOf(routeId, node, day);
    if (row == null) return false;
    return row.direction != direction || (departing && row.use == 'alight') || (!departing && row.use == 'board');
  }

  /// 닫힌 계통 한 바퀴. 올가미는 고리 부분만 돈다 (DESIGN §2.8 G).
  Expansion lap(String routeId, String start, {DateSpan? date, String direction = seqUp}) {
    final ring = ringNodes(routeId);
    final stops = network.stops(routeId);
    final edges = <String>[];
    final nodes = <String>[];
    for (var i = 0; i + 1 < stops.length; i++) {
      final p = stops[i].node;
      final q = stops[i + 1].node;
      if (!ring.contains(p) || !ring.contains(q)) continue;
      final open = [
        for (final edge in network.edgesBetween(routeId, p, q))
          if (network.edgeUsable(routeId, edge, date).ridable) edge,
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
    for (final (index, edge) in ordered.indexed) {
      if (!network.passable(routeId, edge, path[index], path[index + 1], date)) {
        return const Expansion(status: ResolveStatus.invalid, reason: ExpandReason.oneWay);
      }
    }
    final legs = _align(routeId, ordered, date);
    return Expansion(
      status: ResolveStatus.ok,
      edges: ordered,
      nodes: path,
      meters: _legMeters(legs),
      date: date,
      direction: direction,
      legs: legs,
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
    final until = <String, String?>{};
    String? current;
    for (final date in dates) {
      if (date.compareTo(floorDate) < 0) continue;
      final result = expand(routeId, a, b, date: DateSpan.parse(date), listing: true);
      final key = result.status == ResolveStatus.ok ? ([...result.edges]..sort()).join(',') : null;
      if (key != current && current != null) until[current] = date;
      if (key != null) {
        seen.putIfAbsent(key, () => RelocationOption(asOf: date, meters: result.meters!));
        until[key] = null;
      }
      current = key;
    }
    return [
      for (final MapEntry(:key, :value) in seen.entries)
        RelocationOption(asOf: value.asOf, meters: value.meters, until: until[key]),
    ];
  }

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
  /// 경로의 칸이 모두 함께 있던 날이 있는가. 옛 선로와 새 선로를 섞은 고리 경로를 뺀다.
  bool _oneDay(List<_Hop> path) {
    var lo = '0000-01-01';
    var hi = DateSpan.maxDate;
    for (final hop in path) {
      final rows = network.attrsOfEdge(hop.edge);
      if (rows.isEmpty) continue;
      final from = rows.map((r) => r.period.fromLo ?? '0000-01-01').reduce((x, y) => x.compareTo(y) <= 0 ? x : y);
      final to = rows.map((r) => r.period.toHi ?? DateSpan.maxDate).reduce((x, y) => x.compareTo(y) >= 0 ? x : y);
      if (from.compareTo(lo) > 0) lo = from;
      if (to.compareTo(hi) < 0) hi = to;
    }
    return lo.compareTo(hi) < 0;
  }

  List<List<_Hop>> _simplePaths(
    String a,
    String b,
    List<_Link> links, {
    bool Function(String edge, String from, String to)? pass,
  }) {
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
        if (pass != null && !pass(edge, node, next)) continue;
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

  /// 길이(m)가 가장 짧은 길. 없으면 null이다. 같은 길이면 먼저 찾은 길이다.
  List<_Hop>? _shortestPath(
    String a,
    String b,
    List<_Link> links, {
    bool Function(String edge, String from, String to)? pass,
  }) {
    final graph = <String, List<(String, String)>>{};
    for (final link in links) {
      (graph[link.a] ??= []).add((link.b, link.edge));
      (graph[link.b] ??= []).add((link.a, link.edge));
    }
    if (a == b || !graph.containsKey(a) || !graph.containsKey(b)) return null;
    final best = <String, int>{a: 0};
    final back = <String, _Hop>{};
    final open = <String>{a};
    final done = <String>{};
    while (open.isNotEmpty) {
      // 후보가 많지 않아(계통 몇 개) 힙 없이 가장 가까운 노드를 고른다
      final node = open.reduce((x, y) => best[y]! < best[x]! ? y : x);
      if (node == b) break;
      open.remove(node);
      done.add(node);
      for (final (next, edge) in graph[node]!) {
        if (done.contains(next) || (pass != null && !pass(edge, node, next))) continue;
        final cost = best[node]! + network.edges[edge]!.meters;
        if (cost >= (best[next] ?? 1 << 62)) continue;
        best[next] = cost;
        back[next] = (from: node, edge: edge, to: next);
        open.add(next);
      }
    }
    if (!back.containsKey(b)) return null;
    final path = <_Hop>[];
    for (var at = b; at != a; at = path.last.from) {
      path.add(back[at]!);
    }
    return path.reversed.toList();
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
  ) {
    final legs = _align(routeId, edges, date);
    return Expansion(
      status: status,
      edges: edges,
      nodes: [path.first.from, for (final hop in path) hop.to],
      legs: legs,
      meters: _legMeters(legs),
      date: date,
      direction: _direction(routeId, path),
    );
  }

  /// 거리는 구간마다 그 노선의 km로 센다. 3섹 전환 전 노선은 국철 시대 km다 (DESIGN §2.9 E)
  int _legMeters(List<ExpandedLeg> legs) =>
      legs.fold(0, (sum, leg) => sum + network.metersOf(leg.edges, lineId: leg.lineId));

  /// 같은 노선 안에서 계통을 넘는다 (DESIGN §2.8 F). 지선 역에서 본선 역으로 가는 경우다.
  Expansion across(String lineId, String a, String b, {DateSpan? date}) =>
      acrossRoutes(network.routesOfLine(lineId).toList(), a, b, date: date);

  /// [routes]를 합친 그래프에서 펼치고 계통마다 나눈다. 같은 구간이 여러 계통에 있으면 뒤의 계통 것이다.
  /// 날짜 모름에서 이관 뒤 새 역을 고르면 이 계통 뒤에 이어받은 노선 계통을 두어 구간 안을 그 노선으로 나눈다 (DESIGN §8.0.1)
  Expansion acrossRoutes(List<String> routes, String a, String b, {DateSpan? date}) {
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
        if (network.edgeUsable(routeId, hop.edge, day).ridable) {
          links.add((edge: hop.edge, a: hop.a, b: hop.b));
          owner[hop.edge] = routeId;
        }
      }
    }
    // 가장 짧은 길 하나만 쓴다. 계통 여럿을 합친 그래프는 고리가 많아 단순 경로를 다 훑으면 끝나지 않을 수 있다
    final path = _shortestPath(a, b, links, pass: (edge, from, to) => network.passable(owner[edge]!, edge, from, to, day));
    if (path == null) {
      final blocked = _shortestPath(a, b, links) != null;
      return Expansion(status: ResolveStatus.invalid, reason: blocked ? ExpandReason.oneWay : null);
    }
    // 본선에서 지선을 거쳐 본선으로 돌아오면 세 구간이다. 지나간 순서대로 나눈다
    final pieces = <List<_Hop>>[];
    for (final hop in path) {
      if (pieces.isEmpty || owner[pieces.last.last.edge] != owner[hop.edge]) pieces.add([]);
      pieces.last.add(hop);
    }
    // 처음 구간의 출발역과 마지막 구간의 도착역도 한 방향 정차를 따른다 (DESIGN §8 한 방향 정차)
    String way(List<_Hop> piece) {
      final routeId = owner[piece.first.edge]!;
      return network.routes[routeId]!.closed
          ? _direction(routeId, piece)
          : _seqDirection(routeId, piece.first.from, piece.last.to);
    }
    bool refused(List<_Hop> piece, String node, {required bool departing}) =>
        _refusesAt(owner[piece.first.edge]!, node, way(piece), day, departing: departing);
    if (refused(pieces.first, a, departing: true) || refused(pieces.last, b, departing: false)) {
      return Expansion(status: ResolveStatus.invalid, date: day, reason: ExpandReason.stopDirection);
    }
    final edges = [for (final hop in path) hop.edge];
    final legs = [
      for (final piece in pieces)
        ExpandedLeg(
          lineId: network.routes[owner[piece.first.edge]!]!.lineId,
          routeId: owner[piece.first.edge]!,
          edges: [for (final hop in piece) hop.edge],
          from: piece.first.from,
          to: piece.last.to,
        ),
    ];
    return Expansion(
      status: ResolveStatus.ok,
      edges: edges,
      nodes: [path.first.from, for (final hop in path) hop.to],
      legs: legs,
      meters: _legMeters(legs),
      date: day,
    );
  }
}
