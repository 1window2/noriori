import 'record.dart';

/// 모든 변경의 단위. 저장, 수정, 삭제, 구간 탭, 일괄 삭제, 가져오기, 복원이 모두 이것이다.
final class Change {
  const Change({required this.before, required this.after});

  /// 변경 전 행. 새 행은 여기에 없다.
  final List<UserRecord> before;
  final List<UserRecord> after;

  /// 되돌리기. 원래 행을 그대로 쓰지 않고 새 변경을 만든다.
  ///
  /// 그 사이 자동 백업이 나갔어도 복원에서 되돌린 결과가 이겨야 하고,
  /// 되돌림으로 없어지는 새 행은 지우지 않고 삭제 표시로 둔다 (ARCHITECTURE §3.4).
  Change undo({required int now}) {
    final byId = {for (final row in before) row.id: row};
    return Change(
      before: after,
      after: [
        for (final row in after) byId[row.id] ?? row.withDeletedAt(now),
      ],
    );
  }
}

/// `updated_at`. 기기 시계가 돌아가도 그 행에서는 앞으로만 간다 (ARCHITECTURE §3.4).
int nextStamp({required int now, required int? previous}) {
  if (previous == null || now > previous) return now;
  return previous + 1;
}
