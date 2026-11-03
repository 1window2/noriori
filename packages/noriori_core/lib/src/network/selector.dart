import '../date/date_rules.dart';
import '../date/date_span.dart';
import 'network.dart';
import 'network_data.dart';

/// 그날 그 역의 상태 (DESIGN §8 탑승일 상태표).
enum StopState { open, maybe, unknown, beforeOpen, closed, suspended, lineClosed, noEdge }

final class SelectorLink {
  const SelectorLink({
    required this.seq,
    required this.kind,
    required this.otherLineId,
    required this.otherRouteId,
    required this.validFromLo,
    required this.validToHi,
    this.side,
    this.flow,
    this.otherNode,
    this.nextStop,
    this.terminal,
    this.midway = false,
  });

  final int seq;

  /// branch, continue, transfer.
  final String kind;
  final String? otherLineId;
  final String? otherRouteId;
  final String? validFromLo;
  final String? validToHi;

  /// 분기가 역 위쪽(`up`)인가 아래쪽(`down`)인가.
  final String? side;

  /// 환승 노선의 흐름. through, up, down, unknown.
  final String? flow;

  /// 다른 이름의 역이면 그 역.
  final String? otherNode;
  final String? nextStop;
  final String? terminal;

  /// 역이 아니라 역 사이의 선로에서 갈라진다 (DESIGN §8.1 역이 아닌 곳의 분기).
  final bool midway;
}

final class SelectorRow {
  const SelectorRow({
    required this.seq,
    required this.node,
    required this.state,
    required this.selectable,
    required this.isExtension,
    required this.kmCum,
    required this.links,
    this.goneLinks = const [],
    this.savedAs,
    this.openYear,
    this.closeYear,
  });

  final int seq;
  final String node;
  final StopState state;
  final bool selectable;
  final bool isExtension;
  final double? kmCum;
  final List<SelectorLink> links;

  /// 그날 없던 연결. 체크박스를 켜면 3단계로 그린다.
  final List<SelectorLink> goneLinks;

  /// 그날은 다른 노선이다. 저장은 그 노선으로 된다.
  final String? savedAs;

  /// `2016~`, `~2017`에 쓰는 해.
  final String? openYear;
  final String? closeYear;
}

/// 계통과 탑승일로 선택기 행을 만든다 (ARCHITECTURE §2.5). DB를 읽지 않는다.
final class SelectorBuilder {
  const SelectorBuilder(this.network);

  final Network network;

  List<SelectorRow> build(
    String routeId,
    DateSpan? date, {
    List<SelectorLink> links = const [],
  }) {
    final day = normalizeRideDate(date);
    final route = network.routes[routeId]!;
    final adjacent = <String, List<String>>{};
    for (final hop in network.hops(routeId)) {
      (adjacent[hop.a] ??= []).add(hop.edge);
      (adjacent[hop.b] ??= []).add(hop.edge);
    }
    final bySeq = <int, List<SelectorLink>>{};
    final goneBySeq = <int, List<SelectorLink>>{};
    for (final link in links) {
      final on = day == null || _linkOn(link, day);
      ((on ? bySeq : goneBySeq)[link.seq] ??= []).add(link);
    }
    final rows = <SelectorRow>[];
    for (final stop in network.picks(routeId)) {
      if (!stop.isStop && !stop.isExtension) continue;
      if (!network.data.publicNodes.contains(stop.node)) continue;
      final around = adjacent[stop.node] ?? const <String>[];
      var (state, selectable) = _state(routeId, stop, around, day);
      String? savedAs;
      if (day != null && (state == StopState.beforeOpen || state == StopState.closed)) {
        savedAs = _earlierLine(route.lineId, stop.node, around, day);
        if (savedAs != null) (state, selectable) = (StopState.open, true);
      }
      rows.add(SelectorRow(
        seq: stop.seq,
        node: stop.node,
        state: state,
        selectable: selectable,
        isExtension: stop.isExtension,
        kmCum: stop.kmCum,
        links: bySeq[stop.seq] ?? const [],
        goneLinks: goneBySeq[stop.seq] ?? const [],
        savedAs: savedAs,
        openYear: yearLabel(stop.period.fromLo, stop.period.fromHi),
        closeYear: _ended(stop.period) ? yearLabel(stop.period.toLo, stop.period.toHi) : null,
      ));
    }
    return rows;
  }

  bool _ended(NetPeriod period) {
    final end = period.toHi;
    return end != null && end.compareTo(DateSpan.maxDate) < 0;
  }

  /// 행과 다음 행 사이가 그날 영업했는가. 날짜를 모르면 모두 1단계다 (DESIGN §8 상태표).
  List<bool> openBetween(String routeId, List<SelectorRow> rows, DateSpan? date) {
    final day = normalizeRideDate(date);
    if (rows.length < 2) return const [];
    if (day == null) return List.filled(rows.length - 1, true);
    final byPair = <String, List<String>>{};
    for (final hop in network.hops(routeId)) {
      (byPair[_pair(hop.a, hop.b)] ??= []).add(hop.edge);
    }
    final stops = network.stops(routeId);
    return [
      for (var i = 0; i + 1 < rows.length; i++)
        () {
          final inside = [
            for (var at = 0; at + 1 < stops.length; at++)
              if (stops[at].seq >= rows[i].seq && stops[at].seq < rows[i + 1].seq)
                (byPair[_pair(stops[at].node, stops[at + 1].node)] ?? const <String>[]).any((edge) {
                  final state = network.edgeUsable(routeId, edge, day);
                  return state == Usable.ok || state == Usable.maybe;
                }),
          ];
          return inside.isNotEmpty && inside.every((open) => open);
        }(),
    ];
  }

  /// 행과 다음 행 사이를 이미 탔는가. 숨은 역을 지나면 사이의 구간을 다 타야 한다.
  List<bool> riddenBetween(String routeId, List<SelectorRow> rows, Set<int> ridden) {
    final byPair = <String, List<String>>{};
    for (final hop in network.hops(routeId)) {
      (byPair[_pair(hop.a, hop.b)] ??= []).add(hop.edge);
    }
    final stops = network.stops(routeId);
    final gaps = <int, bool>{};
    for (var i = 0; i + 1 < stops.length; i++) {
      gaps[stops[i].seq] = (byPair[_pair(stops[i].node, stops[i + 1].node)] ?? const <String>[])
          .any((edge) => ridden.contains(network.edges[edge]!.n));
    }
    final out = <bool>[];
    for (var i = 0; i < rows.length; i++) {
      if (i == rows.length - 1) {
        out.add(false);
        continue;
      }
      final inside = [
        for (final stop in stops)
          if (stop.seq >= rows[i].seq && stop.seq < rows[i + 1].seq) gaps[stop.seq] ?? false,
      ];
      out.add(inside.isNotEmpty && inside.every((value) => value));
    }
    return out;
  }

  String _pair(String a, String b) => a.compareTo(b) < 0 ? '$a\u0000$b' : '$b\u0000$a';

  (StopState, bool) _state(String routeId, NetStop stop, List<String> around, DateSpan? day) {
    final period = stateOfPeriod(day, stop.period);
    final lines = [for (final edge in around) network.edgeUsable(routeId, edge, day)];
    if (stop.isExtension && day != null) {
      return period == PeriodState.yes || period == PeriodState.maybe
          ? (StopState.open, true)
          : (StopState.closed, false);
    }
    if (day == null) return (StopState.unknown, true);
    if (period == PeriodState.before) return (StopState.beforeOpen, false);
    if (period == PeriodState.after) return (StopState.closed, false);
    if (lines.contains(Usable.ok) && period == PeriodState.yes) return (StopState.open, true);
    if (lines.contains(Usable.ok) || lines.contains(Usable.maybe)) return (StopState.maybe, true);
    if (lines.contains(Usable.suspended)) return (StopState.suspended, false);
    if (around.isNotEmpty && lines.every((u) => u == Usable.no)) {
      return (StopState.lineClosed, false);
    }
    return (StopState.noEdge, false);
  }

  /// 이관 전 날짜는 같은 사슬의 앞 노선에서 정차 기간을 찾는다 (ARCHITECTURE §3.5).
  String? _earlierLine(String lineId, String node, List<String> around, DateSpan day) {
    String? found;
    for (final edge in around) {
      final (attr, _) = network.attrOn(edge, lineId, day);
      if (attr == null || attr.lineId == lineId) continue;
      for (final routeId in network.routesOfLine(attr.lineId)) {
        for (final stop in network.stops(routeId)) {
          if (stop.node != node || !stop.isStop) continue;
          final state = stateOfPeriod(day, stop.period);
          if (state == PeriodState.yes || state == PeriodState.maybe) found = attr.lineId;
        }
      }
    }
    return found;
  }

  /// 범위 날짜는 기간과 겹치면 그린다. 그 범위 안 어느 날에는 이어져 있었다.
  bool _linkOn(SelectorLink link, DateSpan day) {
    final from = link.validFromLo;
    final to = link.validToHi;
    return (from == null || from.compareTo(day.hi) <= 0) && (to == null || day.lo.compareTo(to) < 0);
  }
}
