import '../date/date_rules.dart';
import '../date/date_span.dart';
import '../network/network.dart';
import '../network/network_data.dart';
import 'scorer.dart';

/// 기록 탭의 첫 갈래. 폐선은 노선이 아니라 구간으로 판정한다.
enum BrowseEra { current, closed }

/// 노선 하나. 폐선 쪽의 수치는 그 노선의 폐지 구간만이다.
final class BrowseLine {
  const BrowseLine({
    required this.lineId,
    required this.score,
    this.edgeIds = const {},
    this.riddenEdgeIds = const {},
    this.outside = false,
  });

  final String lineId;
  final Score score;

  /// 별선·단락선(extra)만 있는 노선. 노선 자체의 km로 세고 회사·분류·요약 합계에는 들지 않는다 (DESIGN §8.0).
  final bool outside;

  /// 이 줄에 드는 구간. 위치 띠의 범위다.
  final Set<String> edgeIds;
  final Set<String> riddenEdgeIds;
}

final class BrowseOperator {
  const BrowseOperator({required this.operatorId, required this.score, required this.lines});

  final String operatorId;
  final Score score;
  final List<BrowseLine> lines;
}

final class BrowseCategory {
  const BrowseCategory({required this.category, required this.score, required this.operators});

  final String category;
  final Score score;
  final List<BrowseOperator> operators;
}

final class BrowseTree {
  const BrowseTree({required this.era, required this.total, required this.categories});

  final BrowseEra era;
  final Score total;
  final List<BrowseCategory> categories;

  BrowseCategory? category(String id) {
    for (final item in categories) {
      if (item.category == id) return item;
    }
    return null;
  }

  Iterable<BrowseLine> get lines sync* {
    for (final category in categories) {
      for (final operator in category.operators) {
        yield* operator.lines;
      }
    }
  }

  /// 두 회사가 나눠 가진 노선은 하나로 센다.
  Map<String, Score> get _byLine {
    final out = <String, Score>{};
    // 분모 밖 줄은 요약의 노선 수에 들지 않는다
    for (final line in lines.where((line) => !line.outside)) {
      final held = out[line.lineId];
      final score = line.score;
      out[line.lineId] = held == null
          ? score
          : Score(
              numMeters: held.numMeters + score.numMeters,
              denMeters: held.denMeters + score.denMeters,
              numUnits: held.numUnits + score.numUnits,
              denUnits: held.denUnits + score.denUnits,
            );
    }
    return out;
  }

  int get lineCount => _byLine.length;

  int get startedLineCount => _byLine.values.where((s) => s.started).length;

  int get completeLineCount => _byLine.values.where((s) => s.complete).length;

  int get startedOperatorCount {
    var count = 0;
    for (final category in categories) {
      count += category.operators.where((o) => o.score.started).length;
    }
    return count;
  }

  /// 남은 거리가 짧은 노선부터. 다음 여행의 이유가 된다.
  List<BrowseLine> nearlyComplete({int limit = 3}) {
    final open = [
      for (final line in lines)
        if (!line.outside && line.score.started && !line.score.complete) line,
    ]..sort((a, b) => a.score.remainingMeters.compareTo(b.score.remainingMeters));
    return open.take(limit).toList();
  }
}

/// 분류의 순서. 노리츠부시의 분류를 따른다 (DESIGN §2.5).
const browseCategories = [
  'jr',
  'major_private',
  'semi_major_private',
  'public',
  'general_private',
  'monorail',
  'agt',
  'cable',
];

/// 현행/폐선 → 분류 → 회사 → 노선. 진행률은 [computeScore] 하나로 낸다.
///
/// 현행은 오늘의 소속으로 묶으므로 두 회사가 나눠 가진 노선은 회사마다 나온다. 폐선은 구간마다
/// 마지막 소유자 한 곳에만 넣는다. 그래야 국철에서 JR로 넘어간 구간이 두 번 잡히지 않는다.
BrowseTree browseTree(
  Network network, {
  required BrowseEra era,
  required Map<int, String?> hits,
  required String today,
  bool carryover = true,
}) {
  final basis = era == BrowseEra.current ? const BasisCurrent() : const BasisAllTime();
  final owners = era == BrowseEra.current
      ? _currentOwners(network, today, carryover)
      : _closedOwners(network, today, carryover);
  final byLine = <String, Map<String, Set<NetUnit>>>{};
  final byOperator = <String, Set<NetUnit>>{};
  for (final (unit, attr) in owners) {
    ((byLine[attr.operatorId] ??= {})[attr.lineId] ??= {}).add(unit);
    (byOperator[attr.operatorId] ??= {}).add(unit);
  }
  Score of(Iterable<NetUnit> units) =>
      computeScore(units: units, hits: hits, basis: basis, today: today);
  // 별선·단락선(extra)만 있는 노선도 줄로 둔다. 그 줄은 노선 자체의 km로 세고 회사·분류·요약 합계에는 넣지 않는다 (DESIGN §8.0)
  final outside = <String, Map<String, Set<NetUnit>>>{};
  final counted = <int, NetUnit>{};
  for (final (unit, attr) in _outsideOwners(network, era, today, carryover)) {
    if (byLine[attr.operatorId]?.containsKey(attr.lineId) ?? false) continue;
    ((outside[attr.operatorId] ??= {})[attr.lineId] ??= {}).add(counted[unit.n] ??= _counted(unit));
  }
  outside.forEach((operator, lines) => lines.removeWhere((lineId, _) => _hasCounted(byLine, lineId)));
  final lineOrder = {for (final (i, id) in network.data.lineOrder.indexed) id: i};
  final categories = <BrowseCategory>[];
  for (final category in browseCategories) {
    final operators = <BrowseOperator>[];
    final units = <NetUnit>{};
    for (final operator in network.data.operators) {
      if (operator.category != category) continue;
      final lines = {...?byLine[operator.id], ...?outside[operator.id]};
      if (lines.isEmpty) continue;
      final mine = byOperator[operator.id] ?? const <NetUnit>{};
      units.addAll(mine);
      operators.add(BrowseOperator(
        operatorId: operator.id,
        score: of(mine),
        lines: [
          for (final lineId in lines.keys.toList()
            ..sort((a, b) => (lineOrder[a] ?? 0).compareTo(lineOrder[b] ?? 0)))
            BrowseLine(
              lineId: lineId,
              score: of(lines[lineId]!),
              outside: !(byLine[operator.id]?.containsKey(lineId) ?? false),
              edgeIds: {for (final unit in lines[lineId]!) unit.edgeId},
              riddenEdgeIds: {
                for (final unit in lines[lineId]!)
                  if (hits.containsKey(unit.n)) unit.edgeId,
              },
            ),
        ],
      ));
    }
    if (operators.isEmpty) continue;
    categories.add(BrowseCategory(category: category, score: of(units), operators: operators));
  }
  return BrowseTree(
    era: era,
    total: of({for (final (unit, _) in owners) unit}),
    categories: categories,
  );
}

Iterable<(NetUnit, NetAttr)> _currentOwners(Network network, String today, bool carryover) sync* {
  final day = DateSpan.parse(today);
  for (final attr in network.data.attrs) {
    if (stateOfPeriod(day, attr.period) != PeriodState.yes) continue;
    final unit = network.unitOf(attr.lineId, attr.edgeId, carryover: carryover);
    if (unit != null && unitCounts(unit, const BasisCurrent(), today: today)) yield (unit, attr);
  }
}

Iterable<(NetUnit, NetAttr)> _closedOwners(Network network, String today, bool carryover) {
  final last = <NetUnit, NetAttr>{};
  for (final attr in network.data.attrs) {
    final unit = network.unitOf(attr.lineId, attr.edgeId, carryover: carryover);
    if (unit == null || !unit.normal) continue;
    if (unitCounts(unit, const BasisCurrent(), today: today)) continue;
    final held = last[unit];
    if (held == null || _end(attr).compareTo(_end(held)) > 0) last[unit] = attr;
  }
  return [for (final MapEntry(:key, :value) in last.entries) (key, value)];
}

String _end(NetAttr attr) => attr.period.toHi ?? DateSpan.maxDate;

/// 분모 밖(extra·outside) 구간. 현행은 오늘 영업하는 것, 폐선은 오늘 영업하지 않는 것이다.
Iterable<(NetUnit, NetAttr)> _outsideOwners(Network network, BrowseEra era, String today, bool carryover) sync* {
  final day = DateSpan.parse(today);
  for (final attr in network.data.attrs) {
    final unit = network.unitOf(attr.lineId, attr.edgeId, carryover: carryover);
    if (unit == null || unit.normal) continue;
    final running = stateOfPeriod(day, attr.period) == PeriodState.yes;
    if (running == (era == BrowseEra.current)) yield (unit, attr);
  }
}

/// 다른 회사 쪽에서라도 분모 단위가 있는 노선은 그 단위로 센다.
bool _hasCounted(Map<String, Map<String, Set<NetUnit>>> byLine, String lineId) =>
    byLine.values.any((lines) => lines.containsKey(lineId));

/// 노선 자체 진행률을 내려고 분모 밖 단위를 센다. 이 값은 그 줄에만 쓴다.
NetUnit _counted(NetUnit unit) => NetUnit(
      n: unit.n,
      key: unit.key,
      carryover: unit.carryover,
      edgeId: unit.edgeId,
      meters: unit.meters,
      normal: true,
      dateLo: unit.dateLo,
      dateHi: unit.dateHi,
      fromHi: unit.fromHi,
      toLo: unit.toLo,
    );
