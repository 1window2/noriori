import '../date/date_rules.dart';
import '../date/date_span.dart';
import '../network/network.dart';
import '../network/network_data.dart';
import '../network/route_resolver.dart';
import 'scorer.dart';

/// 저장 전에 보여 줄 값. 저장해도 안 오르면 안 오른다고 말한다.
final class RidePreview {
  const RidePreview({required this.newMeters, required this.counted, this.before, this.after});

  /// 이 기록으로 처음 타는 km.
  final int newMeters;

  /// 분모에 드는 구간이 있는가. 분모 밖 노선을 `이미 탄 구간`으로 말하면 안 된다.
  final bool counted;

  /// 고른 노선들의 완주율을 합친 값. 분모가 없는 노선이면 없다.
  final Score? before;
  final Score? after;
}

/// 그 노선의 단위. 현행이 있으면 현행, 다 폐지된 노선이면 폐지 구간이다.
(Set<NetUnit>, ScoreBasis) lineUnits(Network network, String lineId, String today, {bool carryover = true}) {
  final day = DateSpan.parse(today);
  final current = <NetUnit>{};
  final closed = <NetUnit>{};
  for (final attr in network.data.attrs) {
    if (attr.lineId != lineId) continue;
    final unit = network.unitOf(attr.lineId, attr.edgeId, carryover: carryover);
    if (unit == null || !unit.normal) continue;
    final open = stateOfPeriod(day, attr.period) == PeriodState.yes &&
        unitCounts(unit, const BasisCurrent(), today: today);
    (open ? current : closed).add(unit);
  }
  if (current.isNotEmpty) return (current, const BasisCurrent());
  if (closed.isNotEmpty) return (closed, const BasisAllTime());
  // 전 구간이 분모 밖이면 노선 자체의 km를 보여 준다 (DESIGN §3.1)
  return (
    {
      for (final attr in network.data.attrs)
        if (attr.lineId == lineId) ?network.unitOf(attr.lineId, attr.edgeId, carryover: carryover),
    },
    const BasisAllTime(),
  );
}

RidePreview previewRide(
  Network network, {
  required List<String> lineIds,
  required List<Expansion> expansions,
  required Map<int, String?> hits,
  required String today,
  bool carryover = true,
}) {
  final fresh = <int, NetUnit>{};
  var counted = false;
  for (final leg in expansions.expand((expansion) => expansion.legs)) {
    for (final edge in leg.edges) {
      final unit = network.unitOf(leg.lineId, edge, carryover: carryover);
      counted = counted || (unit?.normal ?? false);
      // 분모 밖 구간은 어느 화면에도 km로 나오지 않는다 (DESIGN §4.6)
      if (unit != null && unit.normal && !hits.containsKey(unit.n)) fresh[unit.n] = unit;
    }
  }
  final newMeters = fresh.values.fold(0, (sum, unit) => sum + unit.meters);
  final lines = [
    for (final lineId in lineIds) lineUnits(network, lineId, today, carryover: carryover),
  ].where((line) => line.$1.isNotEmpty).toList();
  if (lines.isEmpty) return RidePreview(counted: counted, newMeters: newMeters);
  Score of(Map<int, String?> all) {
    final scores = [
      for (final (units, basis) in lines) computeScore(units: units, hits: all, basis: basis, today: today),
    ];
    return Score(
      numMeters: scores.fold(0, (sum, score) => sum + score.numMeters),
      denMeters: scores.fold(0, (sum, score) => sum + score.denMeters),
      numUnits: scores.fold(0, (sum, score) => sum + score.numUnits),
      denUnits: scores.fold(0, (sum, score) => sum + score.denUnits),
    );
  }

  final after = of({...hits, for (final n in fresh.keys) n: today});
  // 전 구간이 분모 밖이면 퍼센트가 없다
  if (after.denMeters == 0) return RidePreview(counted: counted, newMeters: newMeters);
  return RidePreview(counted: counted, newMeters: newMeters, before: of(hits), after: after);
}
