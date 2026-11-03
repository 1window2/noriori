import '../date/date_rules.dart';
import '../date/date_span.dart';
import '../records/derived.dart';
import 'network.dart';
import 'route_resolver.dart';

/// 경로의 한 구간. 한 계통 위를 달린다.
final class JourneyLeg {
  const JourneyLeg({
    required this.lineId,
    required this.routeId,
    required this.from,
    required this.to,
    required this.meters,
  });

  final String lineId;
  final String routeId;
  final String from;
  final String to;
  final int meters;
}

final class Journey {
  const Journey(this.legs);

  final List<JourneyLeg> legs;

  int get meters => legs.fold(0, (sum, leg) => sum + leg.meters);
}

/// 갈아타기 한 번을 이만큼의 거리로 친다. 조금 돌더라도 환승이 적은 길을 고른다.
const _transferMeters = 3000;

final class _Step {
  const _Step(this.cost, this.node, this.routeId);

  final int cost;
  final String node;
  final String routeId;
}

/// 최소 힙. core는 패키지를 쓰지 않는다.
final class _Heap {
  final _items = <_Step>[];

  bool get isEmpty => _items.isEmpty;

  void add(_Step step) {
    _items.add(step);
    var at = _items.length - 1;
    while (at > 0) {
      final up = (at - 1) ~/ 2;
      if (_items[up].cost <= _items[at].cost) break;
      final held = _items[up];
      _items[up] = _items[at];
      _items[at] = held;
      at = up;
    }
  }

  _Step take() {
    final top = _items.first;
    final last = _items.removeLast();
    if (_items.isNotEmpty) {
      _items[0] = last;
      var at = 0;
      while (true) {
        final left = at * 2 + 1;
        final right = left + 1;
        var least = at;
        if (left < _items.length && _items[left].cost < _items[least].cost) least = left;
        if (right < _items.length && _items[right].cost < _items[least].cost) least = right;
        if (least == at) break;
        final held = _items[least];
        _items[least] = _items[at];
        _items[at] = held;
        at = least;
      }
    }
    return top;
  }
}

/// 노선을 넘어 두 역을 잇는다. 시각표는 보지 않는다. 기록을 한 번에 넣기 위한 길찾기다 (DESIGN §6.1).
///
/// 저장은 노선마다 한 건이고 여정으로 묶는다.
///
/// 날짜를 모르면 [today]의 망에서 먼저 찾고 없을 때만 폐선까지 넓힌다.
Journey? findJourney(Network network, String from, String to, {DateSpan? date, required String today}) {
  final day = normalizeRideDate(date);
  if (day != null) return _search(network, from, to, day, date);
  return _search(network, from, to, DateSpan.parse(today), date) ?? _search(network, from, to, null, date);
}

Journey? _search(Network network, String from, String to, DateSpan? day, DateSpan? date) {
  final groups = network.data.nodeGroups;
  final members = <String, List<String>>{};
  for (final MapEntry(:key, :value) in groups.entries) {
    (members[value] ??= []).add(key);
  }
  List<String> sameStation(String node) => members[groups[node]] ?? [node];
  final goal = sameStation(to).toSet();
  // 역마다 지나는 계통의 이웃
  final next = <String, List<(String routeId, String node, int meters)>>{};
  for (final route in network.routes.keys) {
    for (final hop in network.hops(route)) {
      final state = network.edgeUsable(route, hop.edge, day);
      if (state != Usable.ok && state != Usable.maybe) continue;
      final meters = network.edges[hop.edge]!.meters;
      (next[hop.a] ??= []).add((route, hop.b, meters));
      (next[hop.b] ??= []).add((route, hop.a, meters));
    }
  }
  String key(String node, String route) => '$node\u0000$route';
  final best = <String, int>{};
  final back = <String, (String node, String route)>{};
  final heap = _Heap();
  for (final node in sameStation(from)) {
    for (final (route, _, _) in next[node] ?? const <(String, String, int)>[]) {
      final at = key(node, route);
      if (best.containsKey(at)) continue;
      best[at] = 0;
      heap.add(_Step(0, node, route));
    }
  }
  _Step? arrived;
  while (!heap.isEmpty) {
    final step = heap.take();
    if (step.cost > (best[key(step.node, step.routeId)] ?? 0)) continue;
    if (goal.contains(step.node)) {
      arrived = step;
      break;
    }
    void go(String node, String route, int cost) {
      final at = key(node, route);
      if (cost >= (best[at] ?? 1 << 62)) return;
      best[at] = cost;
      back[at] = (step.node, step.routeId);
      heap.add(_Step(cost, node, route));
    }

    for (final (route, node, meters) in next[step.node] ?? const <(String, String, int)>[]) {
      if (route == step.routeId) go(node, route, step.cost + meters);
    }
    // 같은 역의 다른 계통으로 갈아탄다
    for (final node in sameStation(step.node)) {
      for (final (route, _, _) in next[node] ?? const <(String, String, int)>[]) {
        if (route != step.routeId) go(node, route, step.cost + _transferMeters);
      }
    }
  }
  if (arrived == null) return null;
  final path = <(String, String)>[(arrived.node, arrived.routeId)];
  for (var before = back[key(arrived.node, arrived.routeId)];
      before != null;
      before = back[key(before.$1, before.$2)]) {
    path.add(before);
  }
  final legs = <JourneyLeg>[];
  final ordered = path.reversed.toList();
  var start = 0;
  for (var at = 1; at <= ordered.length; at++) {
    if (at < ordered.length && ordered[at].$2 == ordered[start].$2) continue;
    final route = ordered[start].$2;
    final a = ordered[start].$1;
    final b = ordered[at - 1].$1;
    start = at;
    if (a == b) continue;
    final walked = RouteResolver(network).record(route, a, b, date: date ?? day);
    if (!walked.saved && walked.status != ResolveStatus.needsInput) return null;
    legs.add(
      JourneyLeg(
        lineId: network.routes[route]!.lineId,
        routeId: route,
        from: a,
        to: b,
        meters: walked.meters ?? 0,
      ),
    );
  }
  return legs.isEmpty ? null : Journey(legs);
}
