import 'package:noriori_core/noriori_core.dart';
import 'package:test/test.dart';

// 기준: tools/appsim.py의 edtf_range, state_on, normalize_date.
void main() {
  group('DateSpan', () {
    test('하루, 달, 해, 연대', () {
      expect(DateSpan.parse('1985-05-01').lo, '1985-05-01');
      expect(DateSpan.parse('1985-05-01').isDay, isTrue);
      expect(DateSpan.parse('2024-02-XX').hi, '2024-02-29');
      expect(DateSpan.parse('2023-02-XX').hi, '2023-02-28');
      expect(DateSpan.parse('1900-02-XX').hi, '1900-02-28');
      expect(DateSpan.parse('1985-XX-XX').lo, '1985-01-01');
      expect(DateSpan.parse('1985-XX-XX').hi, '1985-12-31');
      expect(DateSpan.parse('201X-XX-XX').lo, '2010-01-01');
      expect(DateSpan.parse('201X-XX-XX').hi, '2019-12-31');
      expect(DateSpan.parse('201X-XX-XX').isDay, isFalse);
    });

    test('ongoing은 끝이 없다', () {
      expect(DateSpan.parse('ongoing').hi, DateSpan.maxDate);
    });

    test('해석할 수 없는 값은 거부한다', () {
      expect(() => DateSpan.parse('1985/05/01'), throwsFormatException);
      expect(() => DateSpan.parse('19XX-XX-XX'), throwsFormatException);
    });
  });

  group('normalizeRideDate', () {
    test('기준일 앞은 날짜 모름', () {
      expect(normalizeRideDate(DateSpan.parse('1969-12-07')), isNull);
      expect(normalizeRideDate(DateSpan.parse('1969-12-08')), isNotNull);
    });

    test('범위가 기준일에 걸쳐도 날짜 모름', () {
      expect(normalizeRideDate(DateSpan.parse('1969-XX-XX')), isNull);
      expect(normalizeRideDate(DateSpan.parse('196X-XX-XX')), isNull);
      expect(normalizeRideDate(DateSpan.parse('1970-XX-XX')), isNotNull);
    });
  });

  group('stateOn', () {
    const open = '1950-06-01';
    const close = '2000-06-01';
    PeriodState on(String? d) => stateOn(
          d == null ? null : DateSpan.parse(d),
          fromLo: open,
          fromHi: open,
          toLo: close,
          toHi: close,
        );

    test('날짜 없음', () => expect(on(null), PeriodState.unknown));
    test('기간 안', () {
      expect(on('1985-05-01'), PeriodState.yes);
      expect(on('2000-05-31'), PeriodState.yes);
      expect(on('199X-XX-XX'), PeriodState.yes);
    });
    test('개업 전', () => expect(on('194X-XX-XX'), PeriodState.before));
    test('폐지일부터는 뒤', () {
      expect(on('2000-06-01'), PeriodState.after);
      expect(on('2001-XX-XX'), PeriodState.after);
    });
    test('범위가 경계에 걸치면 maybe', () {
      expect(on('1950-XX-XX'), PeriodState.maybe);
      expect(on('195X-XX-XX'), PeriodState.maybe);
      expect(on('2000-XX-XX'), PeriodState.maybe);
    });
    test('개업일 모름', () {
      expect(stateOn(DateSpan.parse('1985-05-01')), PeriodState.maybe);
    });
    test('폐지일 불확실', () {
      expect(
        stateOn(
          DateSpan.parse('1985-XX-XX'),
          fromLo: open,
          toLo: '1985-01-01',
          toHi: '1986-12-31',
        ),
        PeriodState.maybe,
      );
    });
  });

  group('jstDate', () {
    test('UTC 15시는 JST 다음 날이다', () {
      final at = DateTime.utc(2026, 11, 1, 15).millisecondsSinceEpoch;
      expect(jstDate(at), '2026-11-02');
    });
    test('UTC 14시 59분은 같은 날이다', () {
      final at = DateTime.utc(2026, 11, 1, 14, 59).millisecondsSinceEpoch;
      expect(jstDate(at), '2026-11-01');
    });
  });

  test('다음 JST 자정까지 남은 시간', () {
    final noon = DateTime.utc(2026, 11, 2, 3).millisecondsSinceEpoch;
    expect(millisToNextJstDay(noon), const Duration(hours: 12).inMilliseconds);
    final midnight = DateTime.utc(2026, 11, 1, 15).millisecondsSinceEpoch;
    expect(millisToNextJstDay(midnight), const Duration(hours: 24).inMilliseconds);
    expect(jstDate(noon + millisToNextJstDay(noon)), '2026-11-03');
  });

  test('아는 만큼만 해를 쓴다', () {
    expect(yearLabel('2017-03-04', '2017-03-04'), '2017');
    expect(yearLabel('2017-01-01', '2017-12-31'), '2017');
    expect(yearLabel('1970-01-01', '1979-12-31'), '197?');
    expect(yearLabel('1970-01-01', '1985-12-31'), '?');
    expect(yearLabel(null, null), '?');
  });

  test('숫자가 아닌 입력과 없는 달은 형식 오류다', () {
    expect(() => parseDateInput('+201'), throwsFormatException);
    expect(() => parseDateInput('20-15'), throwsFormatException);
    expect(() => DateSpan.parse('2015-13-XX'), throwsFormatException);
    expect(() => DateSpan.parse('2015-00-XX'), throwsFormatException);
  });

  test('연대를 입력할 수 있다', () {
    for (final text in ['198X', '198x', '1980s', '1980년대', '1980年代']) {
      expect(parseDateInput(text), '198X-XX-XX');
    }
    expect(DateSpan.parse('198X-XX-XX').lo, '1980-01-01');
  });
}
