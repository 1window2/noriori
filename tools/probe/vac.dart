import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
void main() {
  final dir = Directory.current.path + '/work';
  for (final n in ['v.sqlite','v.copy.sqlite']) { final x=File('$dir/$n'); if (x.existsSync()) x.deleteSync(); }
  final db = sqlite3.open('$dir/v.sqlite');
  db.execute('PRAGMA journal_mode=WAL; create table t(a); insert into t values(1);');
  db.execute("VACUUM INTO '$dir/v.copy.sqlite'");
  print('first VACUUM INTO ok');
  try { db.execute("VACUUM INTO '$dir/v.copy.sqlite'"); print('second VACUUM INTO ok'); } catch (e) { print('second VACUUM INTO failed: ${e.toString().split("\n").first}'); }
  // user_version 트랜잭션성
  db.execute('BEGIN; PRAGMA user_version=7; ROLLBACK;'); print('after rollback user_version=${db.userVersion}');
  db.execute('BEGIN; PRAGMA user_version=7; COMMIT;'); print('after commit user_version=${db.userVersion}');
  try { db.execute('BEGIN'); db.execute("VACUUM INTO '$dir/v2.sqlite'"); } catch (e) { print('VACUUM in txn: ${e.toString().split("\n").first}'); db.execute('ROLLBACK'); }
  db.dispose();
}
