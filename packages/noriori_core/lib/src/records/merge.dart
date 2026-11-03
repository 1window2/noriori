/// 복원은 병합만 있다. 같은 ID는 `updated_at`이 늦은 쪽, 같으면 로컬, 없는 ID는 추가.
bool incomingWins({required int? local, required int incoming}) =>
    local == null || incoming > local;

/// 이 파일을 병합해도 아무것도 안 바뀌는가. 자동 백업 회전의 유일한 삭제 근거다.
///
/// 병합과 같은 판정이므로 규칙이 하나만 있다.
bool mergeChangesNothing({
  required Map<String, int> fileStamps,
  required Map<String, int> localStamps,
}) {
  for (final MapEntry(key: id, value: stamp) in fileStamps.entries) {
    if (incomingWins(local: localStamps[id], incoming: stamp)) return false;
  }
  return true;
}
