import '../date/date_span.dart';

/// 이름 후보 한 행.
final class NameRow {
  const NameRow({required this.text, this.lineId, this.validFrom, this.validTo});

  final String text;
  final String? lineId;
  final String? validFrom;
  final String? validTo;
}

/// 노선 고유 + 날짜 > 노선 고유 > 기본 + 날짜 > 기본 (DESIGN §14.2).
String? pickName(Iterable<NameRow> rows, {String? lineId, String? date}) {
  String? best;
  var rank = 9;
  for (final row in rows) {
    final to = row.validTo;
    final dated = row.validFrom != null || (to != null && to != 'ongoing');
    if (row.lineId != null && row.lineId != lineId) continue;
    if (dated) {
      if (date == null) continue;
      final from = row.validFrom == null ? null : DateSpan.parse(row.validFrom!).lo;
      final until = to == null ? null : DateSpan.parse(to).hi;
      if (from != null && date.compareTo(from) < 0) continue;
      if (until != null && date.compareTo(until) >= 0) continue;
    }
    final level = row.lineId != null ? (dated ? 0 : 1) : (dated ? 2 : 3);
    if (level < rank) {
      best = row.text;
      rank = level;
    }
  }
  return best;
}

/// 색인과 같은 정규화. 가나는 히라가나로, `ヶ`류는 한 형태로 맞춘다 (ARCHITECTURE §4.3).
String foldSearchText(String text) {
  final out = <String>[];
  for (final rune in text.toLowerCase().runes) {
    var code = rune;
    if (code >= 0x30A1 && code <= 0x30F6) code -= 0x60;
    if (code == 0x3095) code = 0x304B;
    if (code == 0x3096) code = 0x3051;
    final char = String.fromCharCode(code);
    if (char.trim().isEmpty || char == '・' || char == '·') continue;
    out.add(char);
  }
  return out.join(' ');
}

/// FTS 검색어. 비면 null. 한 글자 토큰의 구로 찾는다.
String? searchQuery(String text) {
  final folded = foldSearchText(text.replaceAll('"', ''));
  return folded.isEmpty ? null : '"$folded"';
}
