import 'scorer.dart';

/// 천 단위 쉼표.
String countLabel(int value) {
  final digits = '$value';
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

/// km 글자. 계산은 미터로 하고 보여 줄 때만 줄인다.
///
/// 분자와 분모를 같은 자릿수로 적어야 다 탔을 때 두 값이 같게 보인다.
String kmLabel(int meters) {
  final tenths = (meters + 50) ~/ 100;
  return '${countLabel(tenths ~/ 10)}.${tenths % 10}';
}

/// 추정 km 글자. 営業キロ를 몰라 추정한 값은 숫자 뒤에 `?`를 붙인다 (54.1? km, DESIGN §4.5).
///
/// 확실하지 않은 것은 숫자이고 단위는 아니므로 물음표는 숫자에 붙인다.
String kmLabelOf(int meters, {required bool estimated}) => estimated ? '${kmLabel(meters)}?' : kmLabel(meters);

/// 완주율 글자. 내림이라 다 타기 전에는 100%가 아니다.
///
/// 탄 구간이 있으면 0%로 보이지 않게 소수를 늘린다. 막 시작한 사람에게 0.0%는 틀린 말이다.
String percentLabel(Score score) {
  final numerator = score.numMeters;
  final denominator = score.denMeters;
  if (numerator <= 0 || denominator <= 0) return '0%';
  if (numerator >= denominator) return '100%';
  final tenths = numerator * 1000 ~/ denominator;
  if (tenths > 0) return '${tenths ~/ 10}.${tenths % 10}%';
  final hundredths = numerator * 10000 ~/ denominator;
  if (hundredths > 0) return '0.0$hundredths%';
  return '<0.01%';
}
