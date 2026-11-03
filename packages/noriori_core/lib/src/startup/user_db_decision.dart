/// 시작할 때 `user.sqlite`를 들여다본 결과. 판단은 여기서 하고 실행은 store가 한다.
sealed class UserDbProbe {
  const UserDbProbe();
}

/// 파일이 없다. 첫 실행이거나 재설치다.
final class UserDbAbsent extends UserDbProbe {
  const UserDbAbsent();
}

final class UserDbReadable extends UserDbProbe {
  const UserDbReadable(this.userVersion);

  final int userVersion;
}

/// SQLite가 손상이라고 답했다 (CORRUPT, NOTADB만).
final class UserDbCorrupt extends UserDbProbe {
  const UserDbCorrupt();
}

/// 그 밖의 이유로 못 열었다. 권한이나 공간 문제일 수 있으므로 손상으로 보지 않는다.
final class UserDbUnavailable extends UserDbProbe {
  const UserDbUnavailable(this.reason);

  final String reason;
}

enum UserDbAction {
  /// 그대로 연다. 파일이 없으면 새로 만든다.
  open,

  /// 사본을 남기고 마이그레이션한다.
  migrate,

  /// 앱보다 새 스키마다. 파일을 건드리지 않고 앱 갱신을 안내한다.
  askAppUpdate,

  /// 파일을 그대로 두고 다음 시작에 다시 시도한다.
  retryLater,

  /// 손상된 파일을 격리하고 복원 전용 화면으로 간다.
  quarantine,

  /// 이미 격리한 파일이 있다. 복원을 마칠 때까지 빈 DB로 넘어가지 않는다.
  holdRestoreOnly,
}

/// 시작 0단계의 결정표 (ARCHITECTURE §3.6).
UserDbAction decideUserDb({
  required UserDbProbe probe,
  required bool quarantinePresent,
  required int appUserVersion,
}) {
  if (quarantinePresent) return UserDbAction.holdRestoreOnly;
  return switch (probe) {
    UserDbAbsent() => UserDbAction.open,
    UserDbCorrupt() => UserDbAction.quarantine,
    UserDbUnavailable() => UserDbAction.retryLater,
    // 0은 아직 만들어지지 않은 DB다. 첫 생성 중 죽었어도 다시 만들면 된다.
    UserDbReadable(userVersion: 0) => UserDbAction.open,
    UserDbReadable(:final userVersion) when userVersion > appUserVersion =>
      UserDbAction.askAppUpdate,
    UserDbReadable(:final userVersion) when userVersion < appUserVersion =>
      UserDbAction.migrate,
    UserDbReadable() => UserDbAction.open,
  };
}
