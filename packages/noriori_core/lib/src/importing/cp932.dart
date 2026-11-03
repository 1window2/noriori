import 'dart:typed_data';

import 'cp932_table.dart';

const _trailsPerLead = 188;

/// CP932(Shift_JIS의 Windows판)를 글자로. 읽지 못하는 바이트는 U+FFFD다.
String decodeCp932(List<int> bytes) {
  final out = StringBuffer();
  for (var i = 0; i < bytes.length; i++) {
    final byte = bytes[i];
    if (byte < 0x80) {
      out.writeCharCode(byte);
    } else if (byte >= 0xA1 && byte <= 0xDF) {
      out.writeCharCode(0xFF61 + byte - 0xA1);
    } else {
      final lead = _leadIndex(byte);
      final trail = i + 1 < bytes.length ? _trailIndex(bytes[i + 1]) : null;
      if (lead == null || trail == null) {
        out.writeCharCode(0xFFFD);
      } else {
        out.write(cp932Table[lead * _trailsPerLead + trail]);
        i++;
      }
    }
  }
  return out.toString();
}

final Map<int, int> _reverse = () {
  final map = <int, int>{};
  for (var i = 0; i < cp932Table.length; i++) {
    final code = cp932Table.codeUnitAt(i);
    if (code == 0xFFFD) continue;
    final leadIndex = i ~/ _trailsPerLead;
    final trailIndex = i % _trailsPerLead;
    final lead = leadIndex < 31 ? 0x81 + leadIndex : 0xE0 + leadIndex - 31;
    final trail = trailIndex < 63 ? 0x40 + trailIndex : 0x80 + trailIndex - 63;
    map.putIfAbsent(code, () => lead << 8 | trail);
  }
  return map;
}();

/// 글자를 CP932로. 적지 못하는 글자가 있으면 null이다.
Uint8List? encodeCp932(String text) {
  final out = <int>[];
  for (final code in text.codeUnits) {
    if (code < 0x80) {
      out.add(code);
    } else if (code >= 0xFF61 && code <= 0xFF9F) {
      out.add(code - 0xFF61 + 0xA1);
    } else {
      final pair = _reverse[code];
      if (pair == null) return null;
      out
        ..add(pair >> 8)
        ..add(pair & 0xFF);
    }
  }
  return Uint8List.fromList(out);
}

int? _leadIndex(int byte) {
  if (byte >= 0x81 && byte <= 0x9F) return byte - 0x81;
  if (byte >= 0xE0 && byte <= 0xFC) return byte - 0xE0 + 31;
  return null;
}

int? _trailIndex(int byte) {
  if (byte >= 0x40 && byte <= 0x7E) return byte - 0x40;
  if (byte >= 0x80 && byte <= 0xFC) return byte - 0x80 + 63;
  return null;
}
