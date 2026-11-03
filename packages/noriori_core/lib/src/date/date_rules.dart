import 'date_span.dart';

/// 기준일. 법적 폐지일 기준이고 화면에는 쓰지 않는다 (DESIGN §4.6).
const floorDate = '1969-12-08';

/// 기간에 대한 날짜의 상태. 범위 날짜는 겹치면 탈 수 있고, 다 들어가야 [yes]다.
enum PeriodState { yes, maybe, before, after, unknown }

/// 기준일보다 이른 날짜는 날짜 모름이다. 범위가 기준일에 걸쳐도 같다.
DateSpan? normalizeRideDate(DateSpan? date) {
  if (date == null || date.lo.compareTo(floorDate) < 0) return null;
  return date;
}

/// [date]가 `[fromLo..fromHi, toLo..toHi)` 기간에 대해 어떤 상태인가.
PeriodState stateOn(
  DateSpan? date, {
  String? fromLo,
  String? fromHi,
  String? toLo,
  String? toHi,
}) {
  if (date == null) return PeriodState.unknown;
  if (fromLo != null && date.hi.compareTo(fromLo) < 0) return PeriodState.before;
  if (toHi != null && date.lo.compareTo(toHi) >= 0) return PeriodState.after;
  if (fromLo == null) return PeriodState.maybe;
  if (date.lo.compareTo(fromHi ?? fromLo) < 0) return PeriodState.maybe;
  if (toLo == null) return PeriodState.maybe;
  if (date.hi.compareTo(toLo) >= 0) return PeriodState.maybe;
  return PeriodState.yes;
}

final _dateInput = RegExp(r'^\d{4}(-\d{1,2}){0,2}$');

/// 연대. `198X`, `1980s`, `1980년대`, `1980年代`를 받는다.
final _decadeInput = RegExp(r'^(\d{3})(?:[xX]|0(?:s|년대|年代))$');

/// UTC 밀리초의 JST 날짜. 앱의 "오늘"은 기기 시간대가 아니라 JST다 (ARCHITECTURE §3.5).
String jstDate(int utcMillis) {
  final jst = DateTime.fromMillisecondsSinceEpoch(utcMillis, isUtc: true)
      .add(const Duration(hours: 9));
  final mm = '${jst.month}'.padLeft(2, '0');
  final dd = '${jst.day}'.padLeft(2, '0');
  return '${jst.year}-$mm-$dd';
}

/// 다음 JST 자정까지 남은 밀리초.
int millisToNextJstDay(int utcMillis) {
  const day = 86400000;
  const jst = 32400000;
  return day - (utcMillis + jst) % day;
}

/// 해가 정해지면 `2017`, 연대까지만 알면 `201?`, 모르면 `?` (DESIGN §8).
String yearLabel(String? lo, String? hi) {
  if (lo == null || hi == null) return '?';
  if (lo.substring(0, 4) == hi.substring(0, 4)) return lo.substring(0, 4);
  if (lo.substring(0, 3) == hi.substring(0, 3)) return '${lo.substring(0, 3)}?';
  return '?';
}

/// 파일에서 읽은 날짜. 입력란과 같은 규칙으로 고치고, 읽을 수 없으면 [FormatException].
///
/// 날짜를 쓰는 곳은 많고 파일로 들어오는 입구는 적으므로 입구에서 막는다.
String? fileDate(String? raw) {
  if (raw == null) return null;
  try {
    DateSpan.parse(raw);
    return raw;
  } on FormatException {
    return parseDateInput(raw);
  }
}

/// 사용자가 쓴 날짜를 EDTF로. `2015`, `2015-03`, `2015-03-14`를 받고 비면 날짜 모름이다.
///
/// 해석할 수 없으면 [FormatException]. 달력에 없는 날짜도 같다.
String? parseDateInput(String text) {
  final value = text.trim().replaceAll('.', '-').replaceAll('/', '-');
  if (value.isEmpty) return null;
  final decade = _decadeInput.firstMatch(value);
  if (decade != null) return '${decade[1]}X-XX-XX';
  if (!_dateInput.hasMatch(value)) throw FormatException('날짜 형식이 아니다', text);
  final parts = value.split('-');
  final year = int.parse(parts.first);
  if (parts.length == 1) return '${parts.first}-XX-XX';
  final month = int.parse(parts[1]);
  if (month < 1 || month > 12) throw FormatException('달이 아니다', text);
  final mm = '$month'.padLeft(2, '0');
  if (parts.length == 2) return '${parts.first}-$mm-XX';
  final day = int.parse(parts[2]);
  final date = DateTime.utc(year, month, day);
  if (date.month != month || date.day != day) throw FormatException('없는 날짜다', text);
  return '${parts.first}-$mm-${'$day'.padLeft(2, '0')}';
}

/// 화면에 보이는 날짜. 저장은 EDTF이고 사용자는 사람의 글로 본다.
///
/// 연대(`198X`)는 화면마다 말이 달라 [decade]로 받는다.
String dateLabel(
  String raw, {
  required String Function(String year) decade,
  String Function(String year, int month)? month,
  String Function(String year, int month, int day)? day,
}) {
  final parts = raw.split('-');
  if (parts.first.contains('X')) return decade(parts.first.replaceAll('X', '0'));
  final known = [for (final part in parts.skip(1)) if (part != 'XX') int.parse(part)];
  if (known.length == 2 && day != null) return day(parts.first, known[0], known[1]);
  if (known.length == 1 && month != null) return month(parts.first, known[0]);
  return [parts.first, ...known].join('.');
}
