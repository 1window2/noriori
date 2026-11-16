import 'dart:math' as math;

import '../network/line_diagram.dart';
import 'scorer.dart';

/// 탄 역 수 배지의 기준 (DESIGN §3.3).
const stationMilestones = [100, 500, 1000, 3000];

/// 수집 화면의 한 칸. 진행률은 지금 기록으로 계산하고, 배지만 얻은 것을 기억한다.
final class CollectionItem<K> {
  const CollectionItem({required this.key, required this.score, this.kept = false});

  final K key;
  final Score score;

  /// 전에 현행 완주 배지를 얻었고 새 역·연장으로 지금은 100%가 아니다. 배지는 남는다 (DESIGN §3.3).
  final bool kept;

  bool get complete => score.complete || kept;
}

/// 탄 적 있는 것만 고른다. 완주가 먼저이고 나머지는 많이 탄 순서다. [held]는 얻은 배지의 열쇠다.
List<CollectionItem<K>> collectionItems<K extends Comparable<dynamic>>(
  Map<K, Score> scores, {
  Set<K> held = const {},
}) {
  final items = [
    for (final MapEntry(:key, value: score) in scores.entries)
      if (score.started)
        CollectionItem(key: key, score: score, kept: !score.complete && held.contains(key)),
  ];
  // 비율이 같으면 들어온 순서다. ID는 이름이라 ID 순이면 회사 이름의 알파벳 순이 된다
  final order = {for (final (index, key) in scores.keys.indexed) key: index};
  return items
    ..sort((a, b) {
      final done = (b.complete ? 1 : 0) - (a.complete ? 1 : 0);
      if (done != 0) return done;
      final ratio = b.score.ratio.compareTo(a.score.ratio);
      return ratio != 0 ? ratio : order[a.key]!.compareTo(order[b.key]!);
    });
}

/// 배지의 열쇠. 설정 표에 저장한다.
String lineBadge(String lineId) => 'line:$lineId';
String operatorBadge(String operatorId) => 'operator:$operatorId';
String prefBadge(int pref) => 'pref:$pref';

/// 지금 지니는 현행 완주 배지 (DESIGN §3.3, 사용자 결정 2026-11-05).
///
/// 지금 완주한 것과 전에 얻은 것의 합이다. 한 번 얻으면 새 역·연장으로 100%가 아니게 되어도 남고,
/// 그 노선(회사, 도도부현)의 탄 기록을 모두 지우면 사라진다. 노선이 다 폐지되어 현행 점수가 없어져도 남는다.
/// 역대 완주 배지는 없다.
Set<String> heldBadges(
  Set<String> earned, {
  required Map<String, Score> lines,
  required Map<String, Score> operators,
  required Map<int, Score> prefs,
}) {
  final scores = {
    for (final MapEntry(:key, :value) in lines.entries) lineBadge(key): value,
    for (final MapEntry(:key, :value) in operators.entries) operatorBadge(key): value,
    for (final MapEntry(:key, :value) in prefs.entries) prefBadge(key): value,
  };
  return {
    for (final MapEntry(:key, :value) in scores.entries)
      if (value.complete || (value.started && earned.contains(key))) key,
    for (final key in earned)
      if (!scores.containsKey(key)) key,
  };
}

/// 얻은 배지 수. 지니는 현행 완주 배지와 넘긴 역 수 기준의 합이다.
int badgeCount({required Set<String> held, required int stations}) =>
    held.length + stationMilestones.where((goal) => stations >= goal).length;

/// 아직 안 탄 구간 하나.
final class RemainingSection {
  const RemainingSection({
    required this.lineId,
    required this.from,
    required this.to,
    required this.meters,
    this.nodes = const [],
  });

  final String lineId;
  final String from;
  final String to;
  final int meters;

  /// 구간 안의 모든 역. 긴 구간은 끝이 멀어도 중간이 가까울 수 있다.
  final List<String> nodes;
}

/// 노선의 안 탄 구간을 이어 붙인다. 폐지되었거나 다른 노선으로 넘어간 구간은 뺀다.
List<RemainingSection> remainingSections(LineDiagram diagram) {
  final out = <RemainingSection>[];
  for (final route in diagram.routes) {
    final open = route.sections
        .where((section) => !section.ridden && !section.closed && section.held && section.editable)
        .toList();
    for (final joined in joinSections(open)) {
      final inside = <String>{joined.from, joined.to};
      var on = false;
      for (final section in open) {
        if (section.from == joined.from) on = true;
        if (on) inside.addAll([section.from, section.to]);
        if (section.to == joined.to) on = false;
      }
      out.add(
        RemainingSection(
          lineId: diagram.lineId,
          from: joined.from,
          to: joined.to,
          meters: joined.meters,
          nodes: inside.toList(),
        ),
      );
    }
  }
  return out;
}

/// 두 좌표 사이의 km.
double distanceKm(double lat1, double lon1, double lat2, double lon2) {
  const radius = 6371.0;
  double rad(double degree) => degree * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLon / 2), 2);
  return radius * 2 * math.asin(math.sqrt(a));
}

/// `가까운 곳`의 경계. 당일로 다녀올 수 있는 거리다 (사용자 결정, 2026-11-03).
const nearbyKm = 50.0;

/// 지금 위치에서 가까운 안 탄 구간. 구간 안에서 가장 가까운 역으로 잰다.
List<(RemainingSection, double)> nearbySections(
  Iterable<RemainingSection> sections, {
  required Map<String, (double, double)> positions,
  required double lat,
  required double lon,
}) {
  double? away(String node) {
    final at = positions[node];
    return at == null ? null : distanceKm(lat, lon, at.$1, at.$2);
  }

  final near = <(RemainingSection, double)>[];
  for (final section in sections) {
    final sides = (section.nodes.isEmpty ? [section.from, section.to] : section.nodes).map(away).nonNulls;
    if (sides.isEmpty) continue;
    final km = sides.reduce(math.min);
    if (km <= nearbyKm) near.add((section, km));
  }
  return near..sort((a, b) => a.$2.compareTo(b.$2));
}

/// 도도부현별 방문 역 수. 많은 곳이 먼저이고 같으면 도도부현 번호 순이다 (DESIGN §5.2).
/// 도도부현을 모르는 역은 세지 않는다.
List<(int, int)> stationsByPref(Iterable<int> stations, Map<int, int> prefs) {
  final counts = <int, int>{};
  for (final station in stations.toSet()) {
    final pref = prefs[station];
    if (pref != null) counts[pref] = (counts[pref] ?? 0) + 1;
  }
  final rows = [for (final MapEntry(:key, :value) in counts.entries) (key, value)];
  return rows
    ..sort((a, b) {
      final count = b.$2.compareTo(a.$2);
      return count != 0 ? count : a.$1.compareTo(b.$1);
    });
}
