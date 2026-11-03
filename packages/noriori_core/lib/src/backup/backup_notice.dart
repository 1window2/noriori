/// 지도 홈에 띄울 백업 안내. 위에 있을수록 먼저 보여 준다.
enum BackupNotice {
  /// 이 기기보다 새로운 값이 든 파일이 있다. 재설치나 OS 복원 뒤다.
  needsMerge,

  /// 마지막 자동 백업이 실패했다.
  failed,

  /// 폴더 권한을 잃었다.
  folderLost,

  /// 읽지 못한 파일이 있다. 지우지 않고 알린다.
  unreadable,

  /// 바뀐 기록이 오랫동안 백업되지 않았다.
  stale,

  /// 기록이 있는데 백업 폴더를 고르지 않았다.
  noFolder,
}

/// 이 기간이 지나도록 바뀐 기록이 백업되지 않으면 알린다.
const staleBackupMillis = 7 * 24 * 60 * 60 * 1000;

BackupNotice? backupNotice({
  required bool hasFolder,
  required bool granted,
  required bool failed,
  required bool unreadable,
  required bool needsMerge,
  required int? lastBackupAt,
  required int? lastChangeAt,
  required int now,
}) {
  if (needsMerge) return BackupNotice.needsMerge;
  if (failed) return BackupNotice.failed;
  if (hasFolder && !granted) return BackupNotice.folderLost;
  if (unreadable) return BackupNotice.unreadable;
  if (lastChangeAt == null) return null;
  if (!hasFolder) return BackupNotice.noFolder;
  final last = lastBackupAt;
  final behind = last == null || lastChangeAt > last;
  if (behind && now - (last ?? lastChangeAt) > staleBackupMillis) return BackupNotice.stale;
  return null;
}
