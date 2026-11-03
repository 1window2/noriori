import 'dart:io';

import 'package:drift/drift.dart';
// ignore: experimental_member_use
import 'package:drift/remote.dart';
import 'package:noriori_core/noriori_core.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as s3;

import '../db/connection.dart';
import '../db/user_db.dart';
import '../pack/pack_folder.dart';
import '../records/cache_rebuild.dart';
import '../records/record_store.dart';
import 'user_db_file.dart';

/// 앱 지원 폴더의 구조 (ARCHITECTURE §3.1). 절대 경로는 저장하지 않는다.
final class StorePaths {
  const StorePaths(this.support);

  final Directory support;

  File get userDb => File(p.join(support.path, 'user.sqlite'));
  Directory get datasets => Directory(p.join(support.path, 'datasets'));
  Directory get quarantine => Directory(p.join(support.path, 'quarantine'));
  Directory get photos => Directory(p.join(support.path, 'photos'));

  /// OS 백업에서 뺄 폴더 (ARCHITECTURE §3.1).
  List<Directory> get outsideOsBackup => [datasets, quarantine, photos];
}

sealed class StartOutcome {
  const StartOutcome();
}

final class StartReady extends StartOutcome {
  const StartReady(this.session);

  final AppSession session;
}

/// 앱보다 새 스키마다. 파일은 건드리지 않았다.
final class StartNeedsAppUpdate extends StartOutcome {
  const StartNeedsAppUpdate(this.fileVersion);

  final int fileVersion;
}

/// 파일을 그대로 두었다. 다음 시작에 다시 시도한다.
final class StartRetryLater extends StartOutcome {
  const StartRetryLater(this.reason, {this.noSpace = false});

  final String reason;

  /// 저장 공간이 모자랐다. 화면이 공간을 확보하라고 안내한다.
  final bool noSpace;
}

/// 격리한 파일이 있다. 복원을 마칠 때까지 빈 DB로 넘어가지 않는다.
final class StartRestoreOnly extends StartOutcome {
  const StartRestoreOnly(this.quarantined);

  final List<File> quarantined;
}

/// 한 세션. 세션 안에서 데이터 팩은 바뀌지 않는다 (불변식 4).
final class AppSession {
  AppSession._(this.db, this.pack, this.records, this.appBuild, this._packs, this._file);

  final UserDb db;
  final InstalledPack pack;
  final RecordStore records;
  final int appBuild;
  final PackFolder _packs;
  final UserDbFile _file;

  /// 복원 전용 화면이 내보내는 파일.
  List<File> get quarantined => _file.quarantined;

  /// 복원을 마치고 화면을 닫았다. 파일은 지우지 않는다.
  void closeQuarantine() => _file.closeQuarantine();

  /// 6단계. 첫 화면이 뜬 뒤에 부른다.
  void deleteUnusedPacks() => _packs.deleteOthers(pack);

  /// 앱이 백그라운드로 갈 때 부른다. OS 백업이 `-wal`을 놓쳐도 본체에 들어 있게 한다.
  Future<void> checkpoint() => db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');

  Future<void> close() => db.close();
}

/// 콜드 스타트 (ARCHITECTURE §3.6). 판단은 core가 하고 여기서는 순서대로 실행만 한다.
///
/// 어느 단계에서 죽어도 다음 시작이 처음부터 하며 결과가 같다.
final class ColdStart {
  ColdStart({
    required this.paths,
    required this.assets,
    required this.appBuild,
    required this.supportedPackSchema,
    required this.interpreter,
    required this.now,
    this.connect = openBackground,
    this.appUserVersion = userSchemaVersion,
    this.steps = schemaSteps,
  });

  final StorePaths paths;
  final PackAssets assets;
  final int appBuild;
  final int supportedPackSchema;
  /// 팩이 붙은 뒤에 만든다. 해석은 그 판의 선로망을 본다.
  final Future<RecordInterpreter> Function(UserDb db) interpreter;
  final int Function() now;

  /// 백그라운드 연결을 쓰지 못하는 시험에서 바꾼다.
  final QueryExecutor Function(File file, {PackDatabases? pack}) connect;

  final int appUserVersion;
  final Map<int, SchemaStep> steps;

  UserDb _open(QueryExecutor executor) =>
      UserDb(executor, version: appUserVersion, steps: steps);

  /// [restoring]이면 복원 전용 화면이 쓰는 세션을 연다. 격리한 파일은 그대로 둔다.
  Future<StartOutcome> run({bool restoring = false}) => _run(restoring: restoring);

  Future<StartOutcome> _run({required bool restoring, bool packReplaced = false}) async {
    paths.support.createSync(recursive: true);
    final file = UserDbFile(paths.userDb, quarantine: paths.quarantine);
    final probe = file.probe();
    final action = decideUserDb(
      probe: probe,
      quarantinePresent: !restoring && file.hasQuarantine,
      appUserVersion: appUserVersion,
    );
    switch (action) {
      case UserDbAction.askAppUpdate:
        return StartNeedsAppUpdate((probe as UserDbReadable).userVersion);
      case UserDbAction.retryLater:
        return StartRetryLater((probe as UserDbUnavailable).reason);
      case UserDbAction.holdRestoreOnly:
        return StartRestoreOnly(file.quarantined);
      case UserDbAction.quarantine:
        file.moveToQuarantine(now());
        if (restoring) return _run(restoring: true);
        return StartRestoreOnly(file.quarantined);
      case UserDbAction.migrate:
        final failure = await _migrate(file, (probe as UserDbReadable).userVersion);
        if (failure != null) return failure;
      case UserDbAction.open:
        break;
    }
    final packs = PackFolder(
      paths.datasets,
      assets: assets,
      supportedSchema: supportedPackSchema,
    );
    final InstalledPack pack;
    try {
      pack = await packs.select();
    } on Object catch (e) {
      if (_isNoSpace(e)) return StartRetryLater('$e', noSpace: true);
      rethrow;
    }
    final db = _open(connect(paths.userDb, pack: pack.databases));
    try {
      final records = RecordStore(db, interpreter: await interpreter(db), now: now);
      await CacheRebuild(db, records).runIfStale(edition: pack.edition, appBuild: appBuild);
      return StartReady(AppSession._(db, pack, records, appBuild, packs, file));
    } on Object catch (e) {
      await db.close();
      if (_isNoSpace(e)) return StartRetryLater('$e', noSpace: true);
      if (_isCorrupt(e)) {
        // 오류만으로는 어느 파일이 깨졌는지 모른다. 기록이 멀쩡하면 판을 버리고 자산에서 다시 고른다
        if (file.probe() is UserDbReadable) {
          if (packReplaced) return StartRetryLater('$e');
          packs.discard(pack);
          return _run(restoring: restoring, packReplaced: true);
        }
        file.moveToQuarantine(now());
        return StartRestoreOnly(file.quarantined);
      }
      rethrow;
    }
  }

  /// 팩을 붙이지 않고 연다. 마이그레이션은 사용자 스키마만 다룬다.
  Future<StartRetryLater?> _migrate(UserDbFile file, int fromVersion) async {
    try {
      file.copyBeforeMigration(fromVersion);
      final db = _open(openDirect(paths.userDb));
      try {
        await db.customSelect('SELECT 1').get();
      } finally {
        await db.close();
      }
      file.pruneCopies(keep: fromVersion);
      return null;
    } on Object catch (e) {
      return StartRetryLater('$e', noSpace: _isNoSpace(e));
    }
  }

  /// 백그라운드 연결의 SQLite 오류는 드리프트가 한 번 싸서 보낸다.
  Object _cause(Object error) => error is DriftRemoteException ? error.remoteCause : error;

  /// 공간 부족은 파일 쪽과 SQLite 쪽 두 곳에서 온다.
  bool _isNoSpace(Object error) => switch (_cause(error)) {
        FileSystemException(:final osError?) => _noSpaceCodes.contains(osError.errorCode),
        s3.SqliteException(:final resultCode) => resultCode == s3.SqlError.SQLITE_FULL,
        _ => false,
      };

  bool _isCorrupt(Object error) => switch (_cause(error)) {
        s3.SqliteException(:final resultCode) =>
          resultCode == s3.SqlError.SQLITE_CORRUPT || resultCode == s3.SqlError.SQLITE_NOTADB,
        _ => false,
      };

  /// ENOSPC, iOS의 EDQUOT, Android의 EDQUOT.
  static const _noSpaceCodes = {28, 69, 122};
}
