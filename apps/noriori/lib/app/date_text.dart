import 'package:noriori_core/noriori_core.dart';

import '../i18n/strings.g.dart';

/// 화면에 보이는 날짜. 꼴은 언어마다 다르다 (DESIGN §8.0).
String dateText(Translations t, String raw) => dateLabel(
  raw,
  decade: (year) => t.stats.decade(year: year),
  month: (year, month) => t.date.month(year: year, month: t.date.months[month - 1]),
  day: (year, month, day) => t.date.day(year: year, month: t.date.months[month - 1], day: day),
);
