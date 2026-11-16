/// 불확실할 수 있는 날짜 하나. EDTF 원문과 그 하한, 상한을 함께 든다 (DESIGN §5.4).
///
/// ISO 날짜 문자열은 사전순이 곧 날짜순이므로 비교에 문자열을 그대로 쓴다.
final class DateSpan {
  const DateSpan._(this.raw, this.lo, this.hi);

  /// 입력 원문. 저장과 표시는 이 값을 쓴다.
  final String raw;
  final String lo;
  final String hi;

  /// 영업 중인 기간의 끝을 나타내는 값.
  static const maxDate = '9999-12-31';

  static final _day = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
  static final _month = RegExp(r'^(\d{4})-(\d{2})-XX$');
  static final _year = RegExp(r'^(\d{4})-XX-XX$');
  static final _decade = RegExp(r'^(\d{3})X-XX-XX$');
  static final _century = RegExp(r'^(\d{2})XX-XX-XX$');
  static final _range = RegExp(r'^\[(.*)\.\.(.*)\]$');

  /// 하루, 달, 해, 10년, 100년과 범위 `[A..B]`를 받는다. 그 밖의 값은 [FormatException].
  factory DateSpan.parse(String raw) {
    if (raw == 'ongoing') return const DateSpan._('ongoing', maxDate, maxDate);
    if (_day.hasMatch(raw)) return DateSpan._(raw, raw, raw);
    final month = _month.firstMatch(raw);
    if (month != null) {
      final year = month[1]!;
      final mm = month[2]!;
      if (int.parse(mm) case < 1 || > 12) throw FormatException('달이 아니다', raw);
      final last = _lastDay(int.parse(year), int.parse(mm));
      return DateSpan._(raw, '$year-$mm-01', '$year-$mm-$last');
    }
    final year = _year.firstMatch(raw);
    if (year != null) {
      return DateSpan._(raw, '${year[1]}-01-01', '${year[1]}-12-31');
    }
    final decade = _decade.firstMatch(raw);
    if (decade != null) {
      return DateSpan._(raw, '${decade[1]}0-01-01', '${decade[1]}9-12-31');
    }
    final century = _century.firstMatch(raw);
    if (century != null) {
      return DateSpan._(raw, '${century[1]}00-01-01', '${century[1]}99-12-31');
    }
    // 그 사이 어느 날인지 모르는 범위 (EDTF 「하나의 값」 [A..B]). 끝 하나는 비울 수 있다
    final range = _range.firstMatch(raw);
    if (range != null) {
      final lo = range[1]!.isEmpty ? '0000-01-01' : DateSpan.parse(range[1]!).lo;
      final hi = range[2]!.isEmpty ? maxDate : DateSpan.parse(range[2]!).hi;
      if (lo.compareTo(hi) > 0) throw FormatException('범위가 거꾸로다', raw);
      return DateSpan._(raw, lo, hi);
    }
    throw FormatException('EDTF 해석 불가', raw);
  }

  /// 하루로 정해진 날짜인가. 하루로 정해진 날짜는 `resolve_as_of`보다 앞선다.
  bool get isDay => lo == hi;

  static String _lastDay(int year, int month) {
    final leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
    const days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    final last = month == 2 && leap ? 29 : days[month - 1];
    return '$last'.padLeft(2, '0');
  }

  @override
  bool operator ==(Object other) => other is DateSpan && other.raw == raw;

  @override
  int get hashCode => raw.hashCode;

  @override
  String toString() => raw;
}
