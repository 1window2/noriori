import 'dart:io';

import 'package:noriori_core/noriori_core.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as s3;

/// `user.sqlite` 파일 자체를 다루는 곳. 열어 보고, 사본을 만들고, 격리한다.
final class UserDbFile {
  const UserDbFile(this.file, {required this.quarantine});

  final File file;
  final Directory quarantine;

  static const _copyPrefix = 'user.before-';

  /// `-wal`이 먼저다. 본체를 먼저 옮긴 뒤에 죽으면 남은 `-wal`을 다음 DB가 지운다.
  static const sidecars = ['-wal', '-shm', ''];

  /// 복원을 마친 격리 파일은 이 안으로 옮겨 시작을 막지 않는다. 지우지 않는다.
  Directory get _closed => Directory(p.join(quarantine.path, 'closed'));

  List<FileSystemEntity> get _open => quarantine.existsSync()
      ? [
          for (final entry in quarantine.listSync())
            if (entry.path != _closed.path) entry,
        ]
      : const [];

  bool get hasQuarantine => _open.isNotEmpty;

  // 폴더 목록 순서는 파일 시스템마다 다르다. 이름순으로 고정해 복원 화면의 순서가 기기마다 같게 한다
  List<File> get quarantined => [
        for (final entry in _open)
          if (entry is Directory)
            ...entry.listSync(recursive: true).whereType<File>()
          else if (entry is File)
            entry,
      ]..sort((a, b) => a.path.compareTo(b.path));

  /// 사용자가 복원을 마치고 화면을 닫았다. 다음 시작부터 보통 길로 간다.
  void closeQuarantine() {
    _closed.createSync(recursive: true);
    for (final entry in _open) {
      entry.renameSync(p.join(_closed.path, p.basename(entry.path)));
    }
  }

  /// 손상은 SQLite가 그렇다고 답할 때만이다. 권한이나 공간 문제로 기록을 격리하면 안 된다.
  ///
  /// 읽기 전용으로 연다. 쓰기로 열면 손상된 파일을 닫으면서 SQLite가 `-wal`을 지운다.
  UserDbProbe probe() {
    if (!file.existsSync()) return const UserDbAbsent();
    s3.Database? db;
    try {
      db = s3.sqlite3.open(file.path, mode: s3.OpenMode.readOnly);
      final version = db.select('PRAGMA user_version').single.values.first! as int;
      db.select('SELECT count(*) FROM sqlite_master');
      // 첫 페이지만 보면 데이터 페이지 손상을 지나친다. 앱이 쓰다가 막히고 자동 백업도 실패한다
      final verdict = db.select('PRAGMA quick_check(1)').single.values.first;
      if (verdict != 'ok') return const UserDbCorrupt();
      return UserDbReadable(version);
    } on s3.SqliteException catch (e) {
      final code = e.resultCode;
      if (code == s3.SqlError.SQLITE_CORRUPT || code == s3.SqlError.SQLITE_NOTADB) {
        return const UserDbCorrupt();
      }
      return UserDbUnavailable(e.message);
    } on FileSystemException catch (e) {
      return UserDbUnavailable(e.message);
    } finally {
      db?.close();
    }
  }

  /// 마이그레이션 전 사본. 고정 이름에 `VACUUM INTO`를 하면 재시도가 막히므로 임시 이름을 거친다.
  void copyBeforeMigration(int fromVersion) {
    final dir = file.parent;
    final target = File(p.join(dir.path, '$_copyPrefix$fromVersion.sqlite'));
    final temp = File('${target.path}.tmp');
    if (temp.existsSync()) temp.deleteSync();
    final db = s3.sqlite3.open(file.path, mode: s3.OpenMode.readWrite);
    try {
      db.execute('VACUUM INTO ?', [temp.path]);
    } finally {
      db.close();
    }
    temp.renameSync(target.path);
  }

  /// 사본은 마지막 마이그레이션의 것 하나만 둔다. 그 앞의 사본은 지금 DB가 대신한다.
  void pruneCopies({required int keep}) {
    final kept = '$_copyPrefix$keep.sqlite';
    for (final entry in file.parent.listSync().whereType<File>()) {
      final name = p.basename(entry.path);
      if (name.startsWith(_copyPrefix) && name != kept) entry.deleteSync();
    }
  }

  /// 본체와 `-wal`을 함께 옮긴다. 본체만 옮기면 체크포인트 안 된 행이 사라진다.
  void moveToQuarantine(int now) {
    // 같은 이름으로 옮기면 먼저 격리한 파일을 덮어쓴다.
    var dir = Directory(p.join(quarantine.path, '$now'));
    for (var i = 1; dir.existsSync(); i++) {
      dir = Directory(p.join(quarantine.path, '$now-$i'));
    }
    dir.createSync(recursive: true);
    for (final suffix in sidecars) {
      final part = File('${file.path}$suffix');
      if (part.existsSync()) {
        part.renameSync(p.join(dir.path, p.basename(part.path)));
      }
    }
  }
}
