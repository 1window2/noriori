import '../date/date_rules.dart';
import '../date/date_span.dart';
import '../network/network.dart';
import '../network/network_data.dart';

/// 완주율의 기준 (DESIGN §3.1).
sealed class ScoreBasis {
  const ScoreBasis();
}

final class BasisCurrent extends ScoreBasis {
  const BasisCurrent();
}

final class BasisAllTime extends ScoreBasis {
  const BasisAllTime();
}

final class BasisYear extends ScoreBasis {
  const BasisYear(this.year);

  final int year;

  @override
  bool operator ==(Object other) => other is BasisYear && other.year == year;

  @override
  int get hashCode => year.hashCode;
}

final class Score {
  const Score({
    required this.numMeters,
    required this.denMeters,
    required this.numUnits,
    required this.denUnits,
    this.undecidedUnits = 0,
  });

  final int numMeters;
  final int denMeters;
  final int numUnits;
  final int denUnits;

  /// 특정 연도에서 날짜가 애매해 분모·분자에서 뺀 단위 수 (DESIGN §5.4 판정 불가).
  final int undecidedUnits;

  /// 0.1% 단위. 내림이라 99.95%가 100.0%로 보이지 않고, 전 구간을 탔을 때만 1000이다.
  int get permille => denMeters == 0 ? 0 : numMeters * 1000 ~/ denMeters;

  double get ratio => denMeters == 0 ? 0 : numMeters / denMeters;

  int get remainingMeters => denMeters - numMeters;

  bool get started => numUnits > 0;

  bool get complete => denUnits > 0 && numUnits == denUnits;
}

/// 판정은 여기 하나다. SQL은 탄 단위별 최소 `effective_hi`만 준다 (ARCHITECTURE §3.1).
/// 특정 연도는 그해에 확실히 영업한 단위만 센다. 애매한 단위는 [unitUndecided]이고 분모·분자 모두에서 빠진다 (DESIGN §5.4).
bool unitCounts(NetUnit unit, ScoreBasis basis, {required String today}) {
  if (!unit.normal) return false;
  final lo = unit.dateLo;
  final hi = unit.dateHi;
  return switch (basis) {
    BasisAllTime() => true,
    BasisCurrent() => (lo == null || lo.compareTo(today) <= 0) &&
        today.compareTo(hi ?? DateSpan.maxDate) < 0,
    BasisYear(:final year) => _mayRunIn(unit, year) && _surelyRanIn(unit, year),
  };
}

/// 그해와 겹칠 수 있지만 확실하지 않은 분모 단위. 화면에는 `판정 불가 n구간`으로 따로 센다 (DESIGN §5.4).
bool unitUndecided(NetUnit unit, int year) =>
    unit.normal && _mayRunIn(unit, year) && !_surelyRanIn(unit, year);

bool _mayRunIn(NetUnit unit, int year) =>
    (unit.dateLo ?? '0000-01-01').compareTo('${year + 1}-01-01') < 0 &&
    (unit.dateHi ?? DateSpan.maxDate).compareTo('$year-01-01') > 0;

/// 개업이 늦어도 그해 안이고 폐지가 이르러도 그해 첫날 이후다. 폐지 연도만 아는 구간은 그해에 영업한 것으로 친다.
bool _surelyRanIn(NetUnit unit, int year) {
  final fromHi = unit.fromHi;
  final toLo = unit.toLo;
  return fromHi != null &&
      fromHi.compareTo('${year + 1}-01-01') < 0 &&
      toLo != null &&
      toLo.compareTo('$year-01-01') >= 0;
}

/// 연도 기준은 유효 날짜 범위가 그해 말까지 끝나는 기록만 센다.
bool hitCounts(String? effectiveHi, ScoreBasis basis) => switch (basis) {
      BasisYear(:final year) =>
        effectiveHi != null && effectiveHi.compareTo('$year-12-31') <= 0,
      _ => true,
    };

/// [hits]는 탄 단위 번호와 그 단위의 최소 `effective_hi`다. 분자는 분모의 부분집합이다 (불변식 3).
Score computeScore({
  required Iterable<NetUnit> units,
  required Map<int, String?> hits,
  required ScoreBasis basis,
  required String today,
}) {
  var numMeters = 0;
  var denMeters = 0;
  var numUnits = 0;
  var denUnits = 0;
  var undecided = 0;
  for (final unit in units) {
    if (basis case BasisYear(:final year) when unitUndecided(unit, year)) undecided++;
    if (!unitCounts(unit, basis, today: today)) continue;
    denMeters += unit.meters;
    denUnits++;
    if (hits.containsKey(unit.n) && hitCounts(hits[unit.n], basis)) {
      numMeters += unit.meters;
      numUnits++;
    }
  }
  return Score(
    numMeters: numMeters,
    denMeters: denMeters,
    numUnits: numUnits,
    denUnits: denUnits,
    undecidedUnits: undecided,
  );
}

/// 전체와 노선별, 사업자별 완주율.
final class ScoreTable {
  const ScoreTable({required this.total, required this.byLine, required this.byOperator});

  final Score total;
  final Map<String, Score> byLine;
  final Map<String, Score> byOperator;
}

/// 묶음별 판정도 [unitCounts] 하나를 쓴다. 현행은 오늘의 소속, 그 밖은 그 기간의 소속으로 묶는다.
ScoreTable scoreTable(
  Network network, {
  required Map<int, String?> hits,
  required ScoreBasis basis,
  required bool carryover,
  required String today,
}) {
  final day = DateSpan.parse(today);
  // 승계 켬에서 사슬은 한 단위이고 지금 노선의 이름으로 보인다 (DESIGN §2.8 E)
  final latest = <int, NetAttr>{};
  if (basis is BasisAllTime && carryover) {
    for (final attr in network.data.attrs) {
      final unit = network.unitOf(attr.lineId, attr.edgeId, carryover: true);
      if (unit == null) continue;
      final held = latest[unit.n];
      if (held == null || (attr.period.fromLo ?? '').compareTo(held.period.fromLo ?? '') > 0) {
        latest[unit.n] = attr;
      }
    }
  }
  final byLine = <String, Set<NetUnit>>{};
  final byOperator = <String, Set<NetUnit>>{};
  for (final attr in network.data.attrs) {
    final member = switch (basis) {
      BasisCurrent() => stateOfPeriod(day, attr.period) == PeriodState.yes,
      BasisAllTime() => true,
      BasisYear(:final year) =>
        (attr.period.fromLo ?? '0000-01-01').compareTo('${year + 1}-01-01') < 0 &&
            (attr.period.toHi ?? DateSpan.maxDate).compareTo('$year-01-01') > 0,
    };
    if (!member) continue;
    final unit = network.unitOf(attr.lineId, attr.edgeId, carryover: carryover);
    if (unit == null || !unitCounts(unit, basis, today: today)) continue;
    if (latest.isNotEmpty && !identical(latest[unit.n], attr)) continue;
    (byLine[attr.lineId] ??= {}).add(unit);
    (byOperator[attr.operatorId] ??= {}).add(unit);
  }
  Score of(Iterable<NetUnit> units) =>
      computeScore(units: units, hits: hits, basis: basis, today: today);
  return ScoreTable(
    total: of(network.data.units.where((u) => u.carryover == carryover)),
    byLine: {for (final MapEntry(:key, :value) in byLine.entries) key: of(value)},
    byOperator: {for (final MapEntry(:key, :value) in byOperator.entries) key: of(value)},
  );
}
