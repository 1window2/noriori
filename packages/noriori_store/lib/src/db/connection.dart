import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as s3;

/// 연결에 붙일 데이터 팩의 두 DB.
final class PackDatabases {
  const PackDatabases({required this.master, required this.names});

  final String master;
  final String names;
}

/// 드리프트는 URI 없이 파일을 열어서 `file:` ATTACH가 실패한다. 여는 곳만 바꾼다.
final class _UriSqlite3 implements s3.Sqlite3 {
  const _UriSqlite3(this._inner);

  final s3.Sqlite3 _inner;

  @override
  s3.Database open(
    String filename, {
    String? vfs,
    s3.OpenMode mode = s3.OpenMode.readWriteCreate,
    bool uri = false,
    bool? mutex,
  }) =>
      _inner.open(filename, vfs: vfs, mode: mode, uri: true, mutex: mutex);

  @override
  s3.Version get version => _inner.version;

  @override
  String? get tempDirectory => _inner.tempDirectory;

  @override
  set tempDirectory(String? value) => _inner.tempDirectory = value;

  @override
  Iterable<String> get compileOptions => _inner.compileOptions;

  @override
  s3.Database fromPointer(Pointer<void> database, {bool borrowed = false}) =>
      _inner.fromPointer(database, borrowed: borrowed);

  @override
  s3.Database openInMemory({String? vfs}) => _inner.openInMemory(vfs: vfs);

  @override
  s3.Database copyIntoMemory(s3.Database restoreFrom) =>
      _inner.copyIntoMemory(restoreFrom);

  @override
  void ensureExtensionLoaded(s3.SqliteExtension extension) =>
      _inner.ensureExtensionLoaded(extension);

  @override
  bool usedCompileOption(String name) => _inner.usedCompileOption(name);

  @override
  void registerVirtualFileSystem(s3.VirtualFileSystem vfs, {bool makeDefault = false}) =>
      _inner.registerVirtualFileSystem(vfs, makeDefault: makeDefault);

  @override
  void unregisterVirtualFileSystem(s3.VirtualFileSystem vfs) =>
      _inner.unregisterVirtualFileSystem(vfs);
}

s3.Sqlite3 uriSqlite3() => const _UriSqlite3(s3.sqlite3);

String _attachUri(String path) {
  final uri = Uri.file(path).toString().replaceAll("'", "''");
  return '$uri?mode=ro&immutable=1';
}

/// 연결마다 한 번 돈다. 쓰기는 사용자의 입력이므로 전원이 끊겨도 남도록 FULL을 쓴다.
void configureConnection(s3.Database db, PackDatabases? pack) {
  db.execute('PRAGMA journal_mode = WAL');
  db.execute('PRAGMA synchronous = FULL');
  if (pack == null) return;
  db.execute("ATTACH DATABASE '${_attachUri(pack.master)}' AS master");
  db.execute("ATTACH DATABASE '${_attachUri(pack.names)}' AS names");
}

/// 앱이 쓰는 연결. 쓰기 하나와 읽기 풀을 백그라운드 격리에 둔다.
DatabaseConnection openBackground(File file, {PackDatabases? pack}) =>
    NativeDatabase.createBackgroundConnection(
      file,
      setup: (db) => configureConnection(db, pack),
      sqlite3: uriSqlite3,
      readPool: 2,
    );

/// 시험과 마이그레이션처럼 혼자 쓰는 연결.
QueryExecutor openDirect(File file, {PackDatabases? pack}) => NativeDatabase(
      file,
      setup: (db) => configureConnection(db, pack),
      sqlite3: uriSqlite3,
    );
