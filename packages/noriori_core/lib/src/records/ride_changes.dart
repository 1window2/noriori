import 'dart:convert';

/// 판이 바뀌기 전후의 해석 결과 한 건.
final class RideOutcome {
  const RideOutcome({required this.lineId, required this.label, required this.status, this.km10, this.date});

  final String lineId;
  final String label;
  final String status;
  final int? km10;
  final String? date;
}

/// 데이터 정정으로 달라진 기록 (DESIGN §2.8 I).
final class RideChange {
  const RideChange({
    required this.lineId,
    required this.label,
    this.before,
    this.after,
    this.statusChanged = false,
    this.dateChanged = false,
  });

  factory RideChange.fromJson(Map<String, Object?> json) => RideChange(
        lineId: json['line'] as String? ?? '',
        label: json['label']! as String,
        before: json['before'] as int?,
        after: json['after'] as int?,
        statusChanged: json['status'] == true,
        dateChanged: json['date'] == true,
      );

  /// 화면은 이 ID로 지금 언어의 이름을 찾는다. [label]은 저장 당시 이름이다.
  final String lineId;
  final String label;
  final int? before;
  final int? after;

  /// 거리가 아니라 상태가 바뀌었다. 답이 새로 필요할 수 있다.
  final bool statusChanged;

  /// 정지 기간이 정정되어 날짜가 사라지거나 되살아났다.
  final bool dateChanged;

  Map<String, Object?> toJson() => {
        'line': lineId,
        'label': label,
        'before': before,
        'after': after,
        if (statusChanged) 'status': true,
        if (dateChanged) 'date': true,
      };
}

/// 두 해석을 비교한다. 양쪽에 다 있는 기록만 본다.
List<RideChange> diffRides(Map<String, RideOutcome> before, Map<String, RideOutcome> after) => [
      for (final MapEntry(key: id, value: old) in before.entries)
        if (after[id] case final now?)
          if (now.status != old.status || now.km10 != old.km10 || now.date != old.date)
            RideChange(
              lineId: now.lineId,
              label: now.label,
              before: old.km10,
              after: now.km10,
              statusChanged: now.status != old.status,
              dateChanged: now.date != old.date,
            ),
    ];

String encodeRideChanges(List<RideChange> changes) =>
    jsonEncode([for (final change in changes) change.toJson()]);

List<RideChange> decodeRideChanges(String body) => [
      for (final item in jsonDecode(body) as List<Object?>)
        RideChange.fromJson((item! as Map<Object?, Object?>).cast<String, Object?>()),
    ];
