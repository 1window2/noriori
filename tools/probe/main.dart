import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Table;
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as s3;

class Db extends GeneratedDatabase {
  Db(super.e);
  @override Iterable<TableInfo<Table, dynamic>> get allTables => const [];
  @override int get schemaVersion => 1;
  @override MigrationStrategy get migration => MigrationStrategy(onCreate: (m) async {
    await customStatement('create table ride(id text primary key)');
  });
}
final class UriSqlite3 implements s3.Sqlite3 {
  final s3.Sqlite3 inner; UriSqlite3(this.inner);
  @override s3.Database open(String filename, {String? vfs, s3.OpenMode mode = s3.OpenMode.readWriteCreate, bool uri = false, bool? mutex}) =>
      inner.open(filename, vfs: vfs, mode: mode, uri: true, mutex: mutex);
  @override noSuchMethod(Invocation i) => Function.apply((inner as dynamic).noSuchMethod, [i]);
}
s3.Sqlite3 uriResolver() => UriSqlite3(s3.sqlite3);

class Args { final String dir; Args(this.dir); }
DatabaseConnection serverOpen(Args a) => NativeDatabase.createBackgroundConnection(
  File('${a.dir}/user.sqlite'),
  setup: (db) {
    db.execute('PRAGMA journal_mode=WAL');
    db.execute("ATTACH 'file:${a.dir}/pack/master.sqlite?mode=ro&immutable=1' AS master");
    db.execute("ATTACH 'file:${a.dir}/pack/names.sqlite?mode=ro&immutable=1' AS names");
  },
  sqlite3: uriResolver, readPool: 2);

final logs = <String>[];
late String outPath;
void log(String s) { logs.add(s); debugPrint('PROBE $s'); File(outPath).writeAsStringSync(logs.join('\n')); }

Future<void> workerWrite(SendPort p) async {
  final db = Db(await DriftIsolate.fromConnectPort(p).connect());
  await db.transaction(() async { await db.customStatement("insert or replace into ride select 'r'||count(*) from master.edge"); });
  db.notifyUpdates({const TableUpdate('ride', kind: UpdateKind.insert)});
  await Future.delayed(const Duration(milliseconds: 50));
  await db.close();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = (await getApplicationSupportDirectory()).path;
  outPath = '$dir/probe.log';
  final pack = Directory('$dir/pack')..createSync(recursive: true);
  for (final f in ['master.sqlite', 'names.sqlite', 'rail.pmtiles']) {
    final d = await rootBundle.load('assets/$f');
    File('${pack.path}/$f').writeAsBytesSync(d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes));
  }
  log('copied pack to $dir');
  final sw = Stopwatch()..start();
  final args = Args(dir);
  final iso = await DriftIsolate.spawn(() => serverOpen(args));
  final ui = Db(await iso.connect());
  final edges = (await ui.customSelect('select id from master.edge').get()).map((r) => r.data['id'] as String).toList();
  log('drift ok edges=${edges.length} ${sw.elapsedMilliseconds}ms');
  final seen = ui.tableUpdates(TableUpdateQuery.onTableName('ride')).first;
  await Isolate.spawn(workerWrite, iso.connectPort);
  await seen.timeout(const Duration(seconds: 5)); log('worker write -> UI update ok');
  log('rides=' + (await ui.customSelect('select id from ride').get()).map((e) => e.data['id']).toList().toString());
  try { final f = await ui.customSelect("select count(*) c from names.name_fts where name_fts match ?", variables: [Variable.withString('s*')]).getSingle(); log('fts in attached ok ${f.data}'); } catch (e) { log('fts: $e'); }
  try { await ui.customStatement('create table master.x(a)'); log('PACK WRITE SUCCEEDED'); } catch (e) { log('pack write blocked'); }
  runApp(MaterialApp(home: Probe(path: '${pack.path}/rail.pmtiles', edges: edges)));
}

class Probe extends StatefulWidget { final String path; final List<String> edges; const Probe({super.key, required this.path, required this.edges}); @override State<Probe> createState() => _P(); }
const ch = MethodChannel('probe/folder');
int bkN = 0;
class _P extends State<Probe> with WidgetsBindingObserver {
  MapLibreMapController? c; bool done = false;
  @override void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); folderStart(); }
  Future<void> folderStart() async {
    try {
      final saved = await ch.invokeMethod<String>('saved');
      final granted = await ch.invokeMethod('granted');
      log('folder saved=$saved granted=$granted');
      if (saved != null && (granted as List).isNotEmpty) { log('folder list=${await ch.invokeMethod('list')}'); log('folder readall=${await ch.invokeMethod('readall')}'); }
      else { final u = await ch.invokeMethod<String>('pick'); log('picked=$u'); }
    } catch (e) { log('folder err $e'); }
  }
  @override void didChangeAppLifecycleState(AppLifecycleState s) { log('lifecycle $s'); if (s == AppLifecycleState.paused) backup(); }
  Future<void> backup() async {
    final bytes = Uint8List(17 * 1024 * 1024);   // 2만 건 JSON 크기
    final name = 'noriori-${DateTime.now().millisecondsSinceEpoch}.json';
    try { log(await ch.invokeMethod<String>('write', {'name': name, 'bytes': bytes}) ?? 'null'); } catch (e) { log('write err $e'); }
  }

  String get style => jsonEncode({
    'version': 8,
    'sources': {'rail': {'type': 'vector', 'url': 'pmtiles://file://${widget.path}'}},
    'layers': [
      {'id': 'bg', 'type': 'background', 'paint': {'background-color': '#f4efe6'}},
      {'id': 'edge', 'type': 'line', 'source': 'rail', 'source-layer': 'edge', 'paint': {'line-color': '#999999', 'line-width': 1}},
      {'id': 'ridden', 'type': 'line', 'source': 'rail', 'source-layer': 'edge', 'filter': ['==', ['get', 'id'], '__none__'], 'paint': {'line-color': '#0057ff', 'line-width': 3}},
    ]});
  List flt(List<String> ids) => ['match', ['get', 'id'], ids, true, false];
  Future<void> go() async {
    if (done || c == null) return; done = true;
    await Future.delayed(const Duration(seconds: 3));
    final q = await c!.queryRenderedFeatures(const math.Point<double>(200, 400), ['edge'], null);
    log('style loaded; features at point=${q.length}');
    final half = [for (var i = 0; i < widget.edges.length; i += 2) widget.edges[i]];
    for (final (n, ids) in [('half', half), ('all', widget.edges), ('half2', half)]) {
      final sw = Stopwatch()..start();
      try { await c!.setFilter('ridden', flt(ids)); log('setFilter match $n n=${ids.length} json=${jsonEncode(flt(ids)).length} ${sw.elapsedMilliseconds}ms'); }
      catch (e) { log('setFilter $n FAILED $e'); }
      await Future.delayed(const Duration(seconds: 2));
    }
    log('END');
  }
  @override Widget build(BuildContext x) => Scaffold(body: MapLibreMap(
    styleString: style,
    initialCameraPosition: const CameraPosition(target: LatLng(35.68, 139.76), zoom: 8.5),
    onMapCreated: (m) => c = m,
    onStyleLoadedCallback: go,
  ));
}
