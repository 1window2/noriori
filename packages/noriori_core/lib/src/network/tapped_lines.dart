import '../date/date_rules.dart';
import '../date/date_span.dart';
import 'network.dart';

/// 지도에서 누른 자리의 노선이 그 자리에서 어떤 상태인가 (DESIGN §7.4).
enum TappedLineKind {
  /// 누른 구간에서 오늘 영업 중이다.
  current,

  /// 다른 곳에서는 영업 중이지만 누른 구간은 아니다.
  partlyClosed,

  /// 어디서도 영업 중이 아니다.
  closed,
}

/// 겹친 노선 팝업의 줄 하나.
final class TappedLine {
  const TappedLine({required this.lineId, required this.kind});

  final String lineId;
  final TappedLineKind kind;

  @override
  bool operator ==(Object other) =>
      other is TappedLine && other.lineId == lineId && other.kind == kind;

  @override
  int get hashCode => Object.hash(lineId, kind);

  @override
  String toString() => 'TappedLine($lineId, ${kind.name})';
}

/// 지도에서 누른 선로 [tiles](타일의 edge 번호 `n`)를 지나는 노선들 (DESIGN §7.4).
///
/// 현행, 일부 폐지, 전체 폐선 순이고 같은 갈래 안은 팩의 노선 순서다. 판정은 [today]의
/// 집계 행으로만 한다. 승계로 넘어간 옛 노선도 그 구간에 행이 있으므로 따로 줄이 되고,
/// 그 구간에서는 영업 중이 아니라 폐선 쪽에 선다.
List<TappedLine> tappedLines(Network network, Iterable<int> tiles, {required String today}) {
  final day = DateSpan.parse(today);
  final wanted = tiles.toSet();
  final lines = <String>{};
  final openHere = <String>{};
  for (final edge in network.edges.values) {
    if (!wanted.contains(edge.n)) continue;
    for (final attr in network.attrsOfEdge(edge.id)) {
      lines.add(attr.lineId);
      if (stateOfPeriod(day, attr.period) == PeriodState.yes) openHere.add(attr.lineId);
    }
  }
  final openElsewhere = <String>{};
  for (final attr in network.data.attrs) {
    if (!lines.contains(attr.lineId) || openHere.contains(attr.lineId)) continue;
    if (stateOfPeriod(day, attr.period) == PeriodState.yes) openElsewhere.add(attr.lineId);
  }
  final rank = {
    for (final (index, line) in network.data.lineOrder.indexed)
      if (lines.contains(line)) line: index,
  };
  final rows = [
    for (final line in lines)
      TappedLine(
        lineId: line,
        kind: openHere.contains(line)
            ? TappedLineKind.current
            : openElsewhere.contains(line)
                ? TappedLineKind.partlyClosed
                : TappedLineKind.closed,
      ),
  ];
  final seen = lines.toList();
  int order(TappedLine row) => rank[row.lineId] ?? network.data.lineOrder.length + seen.indexOf(row.lineId);
  return rows
    ..sort((a, b) {
      final kind = a.kind.index.compareTo(b.kind.index);
      return kind != 0 ? kind : order(a).compareTo(order(b));
    });
}

/// 환승역의 승강장 노드나 통합 노드를 눌렀을 때 띄울 노선 (DESIGN §7.5).
///
/// [nodes]에 정차하는 노선을 모으고, [only]를 주면 그 노선만 남긴다(노선별로 나뉜 승강장).
/// 갈래와 순서는 [tappedLines]와 같고, 판정은 그 역에 닿는 선로로 한다.
List<TappedLine> stationLines(
  Network network,
  Iterable<String> nodes, {
  Set<String> only = const {},
  required String today,
}) {
  final at = nodes.toSet();
  final served = <String>{
    for (final node in at)
      for (final route in network.routesAt(node))
        if (network.routes[route] case final r?) r.lineId,
  };
  final wanted = only.isEmpty ? served : served.intersection(only);
  final tiles = [
    for (final edge in network.edges.values)
      if (at.contains(edge.from) || at.contains(edge.to)) edge.n,
  ];
  return [
    for (final row in tappedLines(network, tiles, today: today))
      if (wanted.contains(row.lineId)) row,
  ];
}
