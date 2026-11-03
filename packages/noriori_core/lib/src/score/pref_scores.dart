import '../network/network.dart';
import 'scorer.dart';

/// 도도부현별 완주율. 키는 JIS 코드(1~47)다. 경계에 걸친 구간은 현마다 나눠 센다.
Map<int, Score> prefScores(
  Network network, {
  required Map<int, String?> hits,
  required ScoreBasis basis,
  required String today,
  bool carryover = true,
}) {
  final byEdge = <String, List<(int, int)>>{};
  for (final row in network.data.edgePrefs) {
    (byEdge[row.edgeId] ??= []).add((row.pref, row.meters));
  }
  final num = <int, int>{};
  final den = <int, int>{};
  final numUnits = <int, int>{};
  final denUnits = <int, int>{};
  for (final unit in network.data.units) {
    if (unit.carryover != carryover || !unitCounts(unit, basis, today: today)) continue;
    final hit = hits.containsKey(unit.n) && hitCounts(hits[unit.n], basis);
    for (final (pref, meters) in byEdge[unit.edgeId] ?? const <(int, int)>[]) {
      den[pref] = (den[pref] ?? 0) + meters;
      denUnits[pref] = (denUnits[pref] ?? 0) + 1;
      if (hit) {
        num[pref] = (num[pref] ?? 0) + meters;
        numUnits[pref] = (numUnits[pref] ?? 0) + 1;
      }
    }
  }
  return {
    for (final pref in den.keys)
      pref: Score(
        numMeters: num[pref] ?? 0,
        denMeters: den[pref]!,
        numUnits: numUnits[pref] ?? 0,
        denUnits: denUnits[pref]!,
      ),
  };
}

/// 이번 달에 처음 탄 km. 날짜 모름 기록은 언제 탔는지 모르므로 세지 않는다. 가져온 기록이
/// 이번 달 값으로 잡히면 안 된다. [undated]는 날짜 모름 기록으로 탄 단위다.
int newMetersSince(
  Network network, {
  required Map<int, String?> hits,
  required String since,
  required String today,
  Set<int> undated = const {},
  bool carryover = true,
}) {
  var meters = 0;
  for (final unit in network.data.units) {
    if (unit.carryover != carryover || !unitCounts(unit, const BasisAllTime(), today: today)) continue;
    if (!hits.containsKey(unit.n) || undated.contains(unit.n)) continue;
    final hi = hits[unit.n];
    if (hi != null && hi.compareTo(since) >= 0) meters += unit.meters;
  }
  return meters;
}
