// 문서 구조 재현: 드리프트 서버 1개(쓰기+읽기풀), UI 격리(watch), 작업 격리(쓰기). 연결마다 URI ATTACH.
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as s3;

class Db extends GeneratedDatabase {
  Db(super.e);
  @override Iterable<TableInfo<Table, dynamic>> get allTables => const [];
  @override int get schemaVersion => 1;
  @override MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await customStatement('create table ride(id text primary key, note text)');
      await customStatement('create table ride_cache(ride_id text primary key, km10 int)');
    });
}

// sqlite3 바인딩을 감싸 uri:true 를 강제
final class UriSqlite3 implements s3.Sqlite3 {
  final s3.Sqlite3 inner; UriSqlite3(this.inner);
  @override s3.Database open(String filename, {String? vfs, s3.OpenMode mode = s3.OpenMode.readWriteCreate, bool uri = false, bool? mutex})
    => inner.open(filename, vfs: vfs, mode: mode, uri: true, mutex: mutex);
  @override noSuchMethod(Invocation i) => Function.apply((inner as dynamic).noSuchMethod, [i]);
}
s3.Sqlite3 uriResolver() => UriSqlite3(s3.sqlite3);

void setupConn(s3.Database db) {
  final dir = Directory.current.path + '/work';
  db.execute('PRAGMA journal_mode=WAL');
  db.execute("ATTACH 'file:$dir/master.sqlite?mode=ro&immutable=1' AS master");
  db.execute("ATTACH 'file:$dir/names.sqlite?mode=ro&immutable=1' AS names");
}

DatabaseConnection serverOpen() => NativeDatabase.createBackgroundConnection(
  File(Directory.current.path + '/work/user.sqlite'),
  setup: setupConn, sqlite3: uriResolver, readPool: 2);

Future<void> worker(SendPort p) async {
  final iso = DriftIsolate.fromConnectPort(p);
  final db = Db(await iso.connect());
  await db.transaction(() async {
    await db.customStatement("insert into ride values('r1','hello')");
    await db.customStatement("insert into ride_cache select 'r1', count(*) from master.edge");
  });
  db.notifyUpdates({const TableUpdate('ride', kind: UpdateKind.insert)});
  await Future.delayed(const Duration(milliseconds: 100));
  await db.close();
}

void main() async {
  final dir = Directory.current.path + '/work';
  for (final f in ['user.sqlite','user.sqlite-wal','user.sqlite-shm']) { final x=File('$dir/$f'); if (x.existsSync()) x.deleteSync(); }
  final iso = await DriftIsolate.spawn(serverOpen);
  final ui = Db(await iso.connect());
  print('opened');
  final seen = Completer<void>();
  final sub = ui.tableUpdates(TableUpdateQuery.onTableName('ride')).listen((u){ print('UI saw update: $u'); if(!seen.isCompleted) seen.complete(); });
  print('edges=' + (await ui.customSelect('select count(*) c from master.edge').getSingle()).data.toString());
  print('fts=' + (await ui.customSelect("select count(*) c from names.sqlite_master where name like 'name_fts%'").getSingle()).data.toString());
  await Isolate.spawn(worker, iso.connectPort);
  await seen.future.timeout(const Duration(seconds: 5), onTimeout: (){ print('UI NEVER SAW UPDATE'); });
  await Future.delayed(const Duration(milliseconds: 200));
  print('join=' + (await ui.customSelect("select r.id, c.km10 from ride r join ride_cache c on r.id=c.ride_id").get()).map((e)=>e.data).toString());
  try { await ui.customStatement("create table master.x(a)"); print('WRITE TO PACK SUCCEEDED'); } catch (e) { print('pack write blocked: ${e.toString().split('\n').first}'); }
  final dbl = await ui.customSelect('pragma database_list').get();
  print(dbl.map((e)=>e.data['name']).toList());
  final jm = await ui.customSelect('pragma journal_mode').getSingle(); print(jm.data);
  await sub.cancel(); await ui.close(); await iso.shutdownAll();
  print('done');
}
