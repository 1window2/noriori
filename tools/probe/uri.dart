import 'dart:io';
import 'dart:isolate';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';

void main() async {
  final dir = Directory.current.path + '/work';
  final m = '$dir/master.sqlite';
  final n = '$dir/names.sqlite';
  print('sqlite ${sqlite3.version.libVersion}');
  final uf = File('$dir/plain.sqlite'); if (uf.existsSync()) uf.deleteSync();
  // 1) sqlite3.open default uri:false - same as drift NativeDatabase
  var db = sqlite3.open(uf.path);
  print('compile opts: ' + db.select('pragma compile_options').map((r)=>r.values.first).where((v)=>'$v'.contains('URI')||'$v'.contains('FTS')||'$v'.contains('THREADSAFE')).join(', '));
  try {
    db.execute("ATTACH 'file:$m?mode=ro&immutable=1' AS master_");
    print('default open: ATTACH ok; db list=' + db.select('pragma database_list').map((r)=>'${r['name']}=${r['file']}').join(' | '));
    final c = db.select("select count(*) c from master_.sqlite_master");
    print('default open: master tables=${c.first['c']}');
    try { db.execute("create table master_.x(a)"); print('default open: WRITE to attached SUCCEEDED'); } catch (e) { print('default open: write blocked: $e'); }
  } catch (e) { print('default open: ATTACH failed: $e'); }
  db.dispose();
  print('files after: ' + Directory(dir).listSync().map((f)=>f.path.split('/').last).join(', '));
}
