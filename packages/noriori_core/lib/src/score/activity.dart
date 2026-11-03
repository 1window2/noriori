import '../date/date_span.dart';
import '../network/line_diagram.dart';
import '../network/network.dart';
import 'scorer.dart';

/// 통계가 쓰는 기록 한 건.
final class RideDay {
  const RideDay({required this.date, required this.km10, this.exact = false});

  /// 계산된 날짜. 날짜 모름이면 없다.
  final String? date;
  final int km10;

  /// 하루까지 아는 기록. 캘린더는 이것만 찍는다.
  final bool exact;
}

/// 한 해의 숫자.
final class YearStat {
  const YearStat({required this.year, required this.km10, required this.rides, required this.newMeters});

  final int year;
  final int km10;
  final int rides;

  /// 그해 처음 탄 구간의 거리.
  final int newMeters;
}

/// 어느 해의 기록인가. 연대까지만 알면 해를 정할 수 없다.
int? yearOf(String? date) {
  if (date == null) return null;
  final span = DateSpan.parse(date);
  final year = span.lo.substring(0, 4);
  return year == span.hi.substring(0, 4) ? int.parse(year) : null;
}

/// 처음 기록한 해부터 [lastYear]까지. 기록이 없는 해도 빈 막대로 둔다.
List<YearStat> yearlyStats(
  Iterable<RideDay> rides, {
  required Map<int, int> edgeYears,
  required Map<int, int> edgeMeters,
  required int lastYear,
}) {
  final km = <int, int>{};
  final counts = <int, int>{};
  for (final ride in rides) {
    final year = yearOf(ride.date);
    if (year == null) continue;
    km[year] = (km[year] ?? 0) + ride.km10;
    counts[year] = (counts[year] ?? 0) + 1;
  }
  final fresh = <int, int>{};
  for (final MapEntry(key: edge, value: year) in edgeYears.entries) {
    fresh[year] = (fresh[year] ?? 0) + (edgeMeters[edge] ?? 0);
  }
  if (km.isEmpty) return const [];
  final first = km.keys.reduce((a, b) => a < b ? a : b);
  return [
    for (var year = first; year <= lastYear; year++)
      YearStat(year: year, km10: km[year] ?? 0, rides: counts[year] ?? 0, newMeters: fresh[year] ?? 0),
  ];
}

/// 해를 모르는 기록 수. 그래프 아래에 적는다.
int undatedRides(Iterable<RideDay> rides) => rides.where((ride) => yearOf(ride.date) == null).length;

/// 하루의 기록. 캘린더의 한 칸이다.
final class DayActivity {
  const DayActivity({required this.rides, required this.km10});

  final int rides;
  final int km10;
}

Map<String, DayActivity> dailyActivity(Iterable<RideDay> rides, int year) {
  final days = <String, DayActivity>{};
  final prefix = '$year-';
  for (final ride in rides) {
    final date = ride.date;
    if (!ride.exact || date == null || !date.startsWith(prefix)) continue;
    final held = days[date];
    days[date] = DayActivity(rides: (held?.rides ?? 0) + 1, km10: (held?.km10 ?? 0) + ride.km10);
  }
  return days;
}

/// 달력 칸의 진하기. 0은 탄 날이 아니다.
int activityLevel(DayActivity? day) => day == null ? 0 : (day.rides >= 3 ? 3 : day.rides);

/// 탔고 지금은 없어진 구간. 폐선 컬렉션의 한 줄이다.
final class ClosedRide {
  const ClosedRide({
    required this.lineId,
    required this.from,
    required this.to,
    required this.meters,
    this.closeYear,
    this.lastYear,
  });

  final String lineId;
  final String from;
  final String to;
  final int meters;
  final int? closeYear;

  /// 마지막으로 탄 해. 날짜 모름이면 없다.
  final int? lastYear;

  /// 마지막으로 탄 뒤 폐지까지 지난 해.
  int? get yearsBefore {
    final closed = closeYear;
    final last = lastYear;
    return closed == null || last == null || closed < last ? null : closed - last;
  }
}

/// 폐지일이 늦은 것부터. 같은 구간이 계통마다 겹치면 한 번만 센다.
///
/// [lastYears]는 단위마다 마지막으로 탄 해다. 날짜 모름 기록은 들지 않는다.
List<ClosedRide> closedRides(
  Network network, {
  required Iterable<String> lines,
  required Map<int, String?> hits,
  required String today,
  Map<int, int> lastYears = const {},
  bool carryover = true,
}) {
  final seen = <String>{};
  final out = <ClosedRide>[];
  for (final lineId in lines) {
    final diagram = lineDiagram(network, lineId, hits: hits, today: today, carryover: carryover);
    for (final route in diagram.routes) {
      for (final section in joinSections(route.sections.where((s) => s.ridden && s.closed))) {
        if (!seen.add('$lineId|${(section.edges.toList()..sort()).join(',')}')) continue;
        final ends = section.edges.map(network.endOf).nonNulls.toList()..sort();
        final years = section.units.map((unit) => lastYears[unit]).nonNulls;
        out.add(
          ClosedRide(
            lineId: lineId,
            from: section.from,
            to: section.to,
            meters: section.meters,
            closeYear: ends.isEmpty ? null : int.parse(ends.last.substring(0, 4)),
            lastYear: years.isEmpty ? null : years.reduce((a, b) => a > b ? a : b),
          ),
        );
      }
    }
  }
  return out
    ..sort((a, b) {
      final year = (b.closeYear ?? 0).compareTo(a.closeYear ?? 0);
      return year != 0 ? year : a.lineId.compareTo(b.lineId);
    });
}

/// 폐선 컬렉션의 대상. 폐선 포함으로 한 번이라도 탄 노선이다.
Iterable<String> startedLines(ScoreTable allTime) => [
      for (final MapEntry(:key, value: score) in allTime.byLine.entries)
        if (score.started) key,
    ];
