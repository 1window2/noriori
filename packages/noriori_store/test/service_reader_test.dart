import 'dart:io';

import 'package:noriori_core/noriori_core.dart';
import 'package:noriori_store/noriori_store.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as s3;
import 'package:test/test.dart';

/// 운행 계통 판과 정차역을 팩에서 읽는다. a-b-c-d 한 노선의 합성 팩이다.
void main() {
  late Directory scratch;

  setUp(() {
    scratch = Directory.systemTemp.createTempSync('service');
    addTearDown(() => scratch.deleteSync(recursive: true));
  });

  /// [editions]가 거짓이면 판 표가 없던 옛 팩이다.
  String pack({required bool editions}) {
    final path = p.join(scratch.path, 'master.sqlite');
    final db = s3.sqlite3.open(path);
    db.execute('''
      CREATE TABLE route(id, line_id, role, from_node, to_node, closed);
      INSERT INTO route VALUES ('r', 'l', 'main', 'a', 'd', 0);
      CREATE TABLE edge(id, n, from_node, to_node);
      INSERT INTO edge VALUES ('ab', 1, 'a', 'b'), ('bc', 2, 'b', 'c'), ('cd', 3, 'c', 'd');
      CREATE TABLE edge_km(edge_id, km, m);
      INSERT INTO edge_km VALUES ('ab', 1.0, 1000), ('bc', 2.0, 2000), ('cd', 3.0, 3000);
      CREATE TABLE route_edge(route_id, seq, edge_id);
      INSERT INTO route_edge VALUES ('r', 0, 'ab'), ('r', 1, 'bc'), ('r', 2, 'cd');
      CREATE TABLE route_stop(route_id, seq, node_id, km_cum, is_stop, is_end_point, km_estimated,
        valid_from_lo, valid_from_hi, valid_to_lo, valid_to_hi);
      INSERT INTO route_stop VALUES
        ('r', 0, 'a', 0.0, 1, 0, 0, '1900-01-01', '1900-01-01', '9999-12-31', '9999-12-31'),
        ('r', 1, 'b', 1.0, 1, 0, 0, '1900-01-01', '1900-01-01', '9999-12-31', '9999-12-31'),
        ('r', 2, 'c', 3.0, 1, 0, 0, '1900-01-01', '1900-01-01', '9999-12-31', '9999-12-31'),
        ('r', 3, 'd', 6.0, 1, 0, 0, '1900-01-01', '1900-01-01', '9999-12-31', '9999-12-31');
      CREATE TABLE edge_attr(edge_id, line_id, operator_id, lineage_id, carryover_group,
        valid_from_lo, valid_from_hi, valid_to_lo, valid_to_hi);
      INSERT INTO edge_attr SELECT id, 'l', 'o', 'lg', 'cg', '1900-01-01', '1900-01-01', '9999-12-31', '9999-12-31' FROM edge;
      CREATE TABLE edge_life(edge_id, status, valid_from_lo, valid_from_hi, valid_to_lo, valid_to_hi);
      INSERT INTO edge_life SELECT id, 'open', '1900-01-01', '1900-01-01', '9999-12-31', '9999-12-31' FROM edge;
      CREATE TABLE denominator_unit(n, unit_key, carryover, edge_id, m, class, date_lo, date_hi, valid_from, valid_to);
      CREATE TABLE node(id, group_id);
      INSERT INTO node VALUES ('a', NULL), ('b', NULL), ('c', NULL), ('d', NULL);
      CREATE VIEW node_public AS SELECT * FROM node;
      CREATE TABLE station_group(id, n);
      CREATE TABLE operator(id, category);
      CREATE TABLE line(id);
      INSERT INTO line VALUES ('l');
      CREATE TABLE edge_pref(edge_id, pref, km);
      CREATE TABLE service(id, closed, valid_from, valid_to);
      INSERT INTO service VALUES ('s', 0, '1985-09-30', 'ongoing');
    ''');
    if (editions) {
      db.execute('''
        CREATE TABLE service_edition(service_id, edition, valid_from, valid_from_lo, valid_from_hi,
          valid_to, valid_to_lo, valid_to_hi, all_stops);
        INSERT INTO service_edition VALUES
          ('s', 0, '1985-09-30', '1985-09-30', '1985-09-30', '1986-03-03', '1986-03-03', '1986-03-03', 0),
          ('s', 1, '1986-03-03', '1986-03-03', '1986-03-03', 'ongoing', '9999-12-31', '9999-12-31', 1);
        CREATE TABLE service_part(service_id, edition, seq, route_id, from_node, to_node);
        INSERT INTO service_part VALUES ('s', 0, 0, 'r', 'a', 'c'), ('s', 1, 0, 'r', 'a', 'd');
        CREATE TABLE service_stop(service_id, edition, seq, node_id);
        INSERT INTO service_stop VALUES ('s', 0, 0, 'a'), ('s', 0, 1, 'c');
      ''');
    } else {
      db.execute('''
        CREATE TABLE service_part(service_id, seq, route_id, from_node, to_node);
        INSERT INTO service_part VALUES ('s', 0, 'r', 'a', 'd');
      ''');
    }
    db.close();
    return path;
  }

  Future<NetworkData> read(String master) async {
    final db = UserDb(openDirect(File(':memory:')));
    addTearDown(db.close);
    await db.customStatement("ATTACH 'file:$master?mode=ro' AS master");
    return NetworkReader(db).read();
  }

  List<String> nodes(List<ServiceStop> stops) => [for (final stop in stops) stop.node];

  test('판마다 기간·경로·정차역을 읽는다', () async {
    final data = await read(pack(editions: true));
    final service = data.services.single;
    expect(service.editions, hasLength(2));
    final [first, last] = service.editions;
    expect((first.validFrom, first.validTo), ('1985-09-30', '1986-03-03'));
    expect((last.validFrom, last.validTo), ('1986-03-03', 'ongoing'));
    expect(first.stops, {'a', 'c'});
    expect(last.stops, isNull, reason: '정차역을 적지 않은 판은 모든 역');
    expect([for (final part in first.parts) (part.from, part.to)], [('a', 'c')]);
    expect([for (final part in last.parts) (part.from, part.to)], [('a', 'd')]);

    final splitter = ServiceSplitter(Network(data));
    expect(nodes(splitter.halts(service, DateSpan.parse('1985-12-01'))), ['a', 'c']);
    expect(nodes(splitter.stops(service, DateSpan.parse('1985-12-01'))), ['a', 'b', 'c']);
    expect(nodes(splitter.halts(service, DateSpan.parse('1990-01-01'))), ['a', 'b', 'c', 'd']);
    expect(splitter.usable(service, DateSpan.parse('1980-01-01')), isFalse);
  });

  test('판 표가 없는 옛 팩은 정차역 없는 판 하나다', () async {
    final data = await read(pack(editions: false));
    final service = data.services.single;
    expect(service.editions, hasLength(1));
    expect(service.editions.single.stops, isNull);
    expect(service.validFrom, '1985-09-30');
    final splitter = ServiceSplitter(Network(data));
    expect(nodes(splitter.halts(service, null)), ['a', 'b', 'c', 'd']);
    expect(splitter.usable(service, DateSpan.parse('1980-01-01')), isFalse);
    expect(splitter.usable(service, DateSpan.parse('2000-01-01')), isTrue);
  });
}
