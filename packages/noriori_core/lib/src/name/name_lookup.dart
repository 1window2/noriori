import '../date/date_span.dart';

/// 이름 후보 한 행.
final class NameRow {
  const NameRow({required this.text, this.lineId, this.validFrom, this.validTo, this.kana});

  final String text;
  final String? lineId;
  final String? validFrom;
  final String? validTo;

  /// 일본어 이름의 읽기(히라가나). 근거 없는 읽기는 비어 있다
  final String? kana;
}

/// 노선 고유 + 날짜 > 노선 고유 > 기본 + 날짜 > 기본 (DESIGN §14.2).
String? pickName(Iterable<NameRow> rows, {String? lineId, String? date}) =>
    pickNameRow(rows, lineId: lineId, date: date)?.text;

/// [pickName]이 고르는 행. 그 이름의 읽기를 함께 쓸 때 쓴다.
NameRow? pickNameRow(Iterable<NameRow> rows, {String? lineId, String? date}) {
  NameRow? best;
  var rank = 9;
  for (final row in rows) {
    final to = row.validTo;
    final dated = row.validFrom != null || (to != null && to != 'ongoing');
    if (row.lineId != null && row.lineId != lineId) continue;
    // 날짜를 모를 때도 지금 이어지는 노선 고유 이름(지금 臨時駅인 역의 (臨) 표시)은 쓴다 (사용자 결정 2026-11-07)
    final current = row.lineId != null && (to == null || to == 'ongoing');
    if (dated && date == null && current) {
      if (0 < rank) {
        best = row;
        rank = 0;
      }
      continue;
    }
    if (dated) {
      if (date == null) continue;
      final from = row.validFrom == null ? null : DateSpan.parse(row.validFrom!).lo;
      final until = to == null ? null : DateSpan.parse(to).hi;
      if (from != null && date.compareTo(from) < 0) continue;
      if (until != null && date.compareTo(until) >= 0) continue;
    }
    final level = row.lineId != null ? (dated ? 0 : 1) : (dated ? 2 : 3);
    if (level < rank) {
      best = row;
      rank = level;
    }
  }
  return best;
}

/// 일본어판에서 이름 옆에 읽기를 다는가. 한자가 섞인 이름만 단다. 가나·로마자뿐인 이름은 읽기가 이름 그대로다
/// (역 표지·노선도의 후리가나처럼 한자에만 읽기가 필요하다).
bool needsReading(String name) => RegExp(r'[\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff\u3005\u3006\u30f6]').hasMatch(name);

/// 색인과 같은 정규화. 가나는 히라가나로, `ヶ`류는 한 형태로 맞춘다 (ARCHITECTURE §4.3).
String foldSearchText(String text) {
  final out = <String>[];
  for (final rune in text.toLowerCase().runes) {
    var code = rune;
    // 제어 문자(NUL 등)는 이름에 없고, FTS 구 안에 들면 검색어가 끊긴다
    if (code < 0x20 || code == 0x7F) continue;
    if (code >= 0x30A1 && code <= 0x30F6) code -= 0x60;
    if (code == 0x3095) code = 0x304B;
    if (code == 0x3096) code = 0x3051;
    // 한국어 음차는 쵸/초·죠/조처럼 갈린다 (DESIGN §9.2). 찾을 때는 같은 글자로 본다
    code = _koFold[code] ?? code;
    final char = String.fromCharCode(code);
    if (char.trim().isEmpty || char == '・' || char == '·') continue;
    out.add(char);
  }
  return out.join(' ');
}

const _koFold = {0xCD78: 0xCD08, 0xC8E0: 0xC870, 0xC96C: 0xC8FC, 0xCE04: 0xCD94, 0xCC60: 0xCC28, 0xC7C8: 0xC790}; // 쵸초 죠조 쥬주 츄추 챠차 쟈자

/// FTS 검색어. 비면 null. 한 글자 토큰의 구로 찾는다.
/// 영어로 「Mt. Takao」처럼 산을 앞에 붙여 치면 역 이름의 산 읽기(-san·-zan·-yama·-dake)로도 찾는다:
/// 「Mt. Takao」 → Takaosan·Takaosanguchi. 색인에 「Mt.」 별칭을 넣지 않는 것은 金山(광산)·成田山(절)처럼
/// 산이 아닌 〜山 이름에 틀린 별칭이 붙기 때문이다 (6회차 2026-11-27).
String? searchQuery(String text) {
  final plain = text.replaceAll('"', '');
  final folded = foldSearchText(plain);
  if (folded.isEmpty) return null;
  final mount = _mount.firstMatch(plain.trim());
  final rest = mount == null ? '' : foldSearchText(mount.group(1)!);
  if (rest.isEmpty) return '"$folded"';
  return ['"$folded"', for (final tail in _mountTails) '"$rest $tail"'].join(' OR ');
}

/// 검색어가 들어맞을 수 있는 접은 꼴들. 옛 이름으로만 맞았는지 가리는 데 쓴다(searchQuery와 같은 「Mt.」 규칙)
List<String> searchFoldedVariants(String text) {
  final plain = text.replaceAll('"', '');
  final folded = foldSearchText(plain);
  if (folded.isEmpty) return const [];
  final mount = _mount.firstMatch(plain.trim());
  final rest = mount == null ? '' : foldSearchText(mount.group(1)!);
  return [folded, if (rest.isNotEmpty) for (final tail in _mountTails) '$rest $tail'];
}

final _mount = RegExp(r'^(?:mt\.|mt\s|mount\s)\s*(.*\S)$', caseSensitive: false);
const _mountTails = ['s a n', 'z a n', 'y a m a', 'd a k e', 't a k e'];
