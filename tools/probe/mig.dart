// 문서 §3.6 절차 재현. 인자: seed | crash | plain | fixed
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as s3;

class Db extends GeneratedDatabase {
  final int ver; final String mode;
  Db(super.e, this.ver, this.mode);
  @override Iterable<TableInfo<Table, dynamic>> get allTables => const [];
  @override int get schemaVersion => ver;
  @override MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async { await customStatement('create table ride(id text primary key, note text)'); await customStatement("insert into ride values('r1','keep me')"); },
    onUpgrade: (m, from, to) async {
      await transaction(() async {
        await customStatement('alter table ride add column extra text');
        if (mode == 'fixed') await customStatement('PRAGMA user_version = $to');
      });
      if (mode == 'crash') { stdout.writeln('  [migration committed; dying before drift writes user_version]'); await stdout.flush(); exit(9); }
    });
}
void main(List<String> a) async {
  final dir = Directory.current.path + '/work';
  final f = File('$dir/mig.sqlite');
  final m = a[0];
  final ver = m == 'seed' ? 1 : 2;
  final db = Db(NativeDatabase(f), ver, m);
  try {
    final r = await db.customSelect('select * from ride').get();
    final uv = await db.customSelect('pragma user_version').getSingle();
    stdout.writeln('  ok rows=${r.map((e)=>e.data)} user_version=${uv.data}');
  } catch (e) { stdout.writeln('  OPEN FAILED: ${e.toString().split("\n").first}'); }
  await db.close();
}
