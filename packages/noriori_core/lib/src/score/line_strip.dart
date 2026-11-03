import '../network/network.dart';
import 'browse_tree.dart';

/// 노선을 실제 길이로 편 띠에서 탄 자리 하나. 단위는 미터다.
final class StripSegment {
  const StripSegment(this.from, this.to);

  final int from;
  final int to;
}

/// 얼마나 탔는지가 아니라 어디를 탔는지를 보여 주는 값 (DESIGN §1.5 가로 스트립).
final class LineStrip {
  const LineStrip({
    required this.totalMeters,
    required this.segments,
    this.startNode,
    this.endNode,
  });

  final int totalMeters;
  final List<StripSegment> segments;
  final String? startNode;
  final String? endNode;

  bool get complete =>
      segments.length == 1 && segments.single.from == 0 && segments.single.to >= totalMeters;
}

/// 본선부터 계통 순서로 구간을 늘어놓는다. 지선은 뒤에 잇고 같은 구간은 한 번만 센다.
LineStrip lineStrip(Network network, BrowseLine line) {
  final routes = network.routesOfLine(line.lineId).toList()
    ..sort((a, b) {
      final x = network.routes[a]!.role == 'main' ? 0 : 1;
      final y = network.routes[b]!.role == 'main' ? 0 : 1;
      return x.compareTo(y);
    });
  final ordered = <String>[];
  final seen = <String>{};
  String? first;
  String? last;
  for (final routeId in routes) {
    final byPair = <String, List<String>>{};
    for (final hop in network.hops(routeId)) {
      (byPair[_pair(hop.a, hop.b)] ??= []).add(hop.edge);
    }
    final stops = network.stops(routeId);
    for (var i = 0; i + 1 < stops.length; i++) {
      final p = stops[i].node;
      final q = stops[i + 1].node;
      for (final edge in byPair[_pair(p, q)] ?? const <String>[]) {
        if (!line.edgeIds.contains(edge) || !seen.add(edge)) continue;
        ordered.add(edge);
        if (routeId == routes.first) {
          first ??= p;
          last = q;
        }
      }
    }
  }
  // 계통에 없는 구간도 분모에는 들어 있으므로 뒤에 붙인다
  for (final edge in line.edgeIds) {
    if (seen.add(edge)) ordered.add(edge);
  }
  final segments = <StripSegment>[];
  var at = 0;
  for (final edge in ordered) {
    final meters = network.edges[edge]?.meters ?? 0;
    if (line.riddenEdgeIds.contains(edge)) {
      if (segments.isNotEmpty && segments.last.to == at) {
        segments[segments.length - 1] = StripSegment(segments.last.from, at + meters);
      } else {
        segments.add(StripSegment(at, at + meters));
      }
    }
    at += meters;
  }
  return LineStrip(totalMeters: at, segments: segments, startNode: first, endNode: last);
}

String _pair(String a, String b) => a.compareTo(b) < 0 ? '$a\u0000$b' : '$b\u0000$a';
