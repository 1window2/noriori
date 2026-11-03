import 'dart:convert';

import '../date/date_rules.dart';
import 'cp932.dart';

const _columns = ['会社名', '路線名', '乗車開始駅', '乗車終了駅', '乗車キロ', '乗車日'];
const _commentColumn = 'コメント';
const _noDate = '0000-00-00';

/// 노리츠부시 CSV 한 행 (DESIGN §10.1).
final class CsvRide {
  const CsvRide({
    required this.company,
    required this.line,
    required this.from,
    required this.to,
    required this.meters,
    required this.dateInput,
    required this.comment,
    required this.raw,
  });

  final String company;
  final String line;
  final String from;
  final String to;

  /// 파일에 적힌 거리. 맞춘 경로를 검증하는 데만 쓴다.
  final int? meters;

  /// `0000-00-00`은 날짜 모름이다.
  final String? dateInput;
  final String? comment;

  /// 파일의 원문.
  final String raw;
}

/// 읽은 파일. 모양이 깨진 행은 버리지 않고 확인 화면에 보여 준다.
final class CsvFile {
  const CsvFile({required this.rides, required this.broken});

  final List<CsvRide> rides;
  final List<String> broken;
}

/// 바이트를 글자로. 노리츠부시는 CP932이고 다른 도구를 거치면 UTF-8일 수 있다.
String decodeCsvBytes(List<int> bytes) {
  try {
    final text = utf8.decode(bytes);
    return text.startsWith('﻿') ? text.substring(1) : text;
  } on FormatException {
    return decodeCp932(bytes);
  }
}

/// RFC 4180으로 나눈 행.
List<List<String>> csvRows(String text) => [for (final record in _records(text)) record.fields];

/// 노리츠부시 CSV가 아니면 [FormatException].
CsvFile parseNoritsubushiCsv(String text) {
  final records = _records(text);
  if (records.isEmpty) throw const FormatException('빈 파일이다');
  final header = records.first.fields;
  if (header.length < _columns.length ||
      !Iterable<int>.generate(_columns.length).every((i) => header[i] == _columns[i])) {
    throw const FormatException('노리츠부시 CSV가 아니다');
  }
  final hasComment = header.length > _columns.length && header[_columns.length] == _commentColumn;
  final width = _columns.length + (hasComment ? 1 : 0);
  final rides = <CsvRide>[];
  final broken = <String>[];
  for (final record in records.skip(1)) {
    final ride = record.fields.length == width && !record.open ? _ride(record) : null;
    if (ride == null) {
      broken.add(record.raw);
    } else {
      rides.add(ride);
    }
  }
  return CsvFile(rides: rides, broken: broken);
}

CsvRide? _ride(_Record record) {
  final fields = record.fields;
  if (fields.take(4).any((field) => field.trim().isEmpty)) return null;
  final String? date;
  try {
    date = fields[5].trim() == _noDate ? null : parseDateInput(fields[5]);
  } on FormatException {
    return null;
  }
  final comment = fields.length > _columns.length ? fields[_columns.length].trim() : '';
  return CsvRide(
    company: fields[0].trim(),
    line: fields[1].trim(),
    from: fields[2].trim(),
    to: fields[3].trim(),
    meters: _meters(fields[4]),
    dateInput: date,
    comment: comment.isEmpty ? null : comment,
    raw: record.raw,
  );
}

int? _meters(String text) {
  final km = double.tryParse(text.trim());
  return km == null || !km.isFinite ? null : (km * 1000).round();
}

final class _Record {
  const _Record(this.fields, this.raw, {this.open = false});

  /// 따옴표가 닫히지 않은 채 파일이 끝났다. 뒤 행을 삼켰을 수 있다.
  final bool open;

  final List<String> fields;
  final String raw;
}

/// RFC 4180. 샘플에는 따옴표가 없지만 코멘트에 쉼표와 줄바꿈이 들어갈 수 있다.
List<_Record> _records(String text) {
  final records = <_Record>[];
  var fields = <String>[];
  final field = StringBuffer();
  var quoted = false;
  var start = 0;

  void endRecord(int end, {bool open = false}) {
    fields.add(field.toString());
    field.clear();
    final raw = text.substring(start, end);
    if (raw.trim().isNotEmpty) records.add(_Record(fields, raw, open: open));
    fields = <String>[];
  }

  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (quoted) {
      if (char != '"') {
        field.write(char);
      } else if (i + 1 < text.length && text[i + 1] == '"') {
        field.write('"');
        i++;
      } else {
        quoted = false;
      }
    } else if (char == '"' && field.isEmpty) {
      quoted = true; // 칸 처음이 아닌 따옴표는 글자다. `5"ゲージ` 같은 코멘트가 있다
    } else if (char == ',') {
      fields.add(field.toString());
      field.clear();
    } else if (char == '\n') {
      final crlf = i > start && text[i - 1] == '\r';
      endRecord(crlf ? i - 1 : i);
      start = i + 1;
    } else if (char != '\r') {
      field.write(char);
    }
  }
  if (start < text.length) endRecord(text.length, open: quoted);
  return records;
}
