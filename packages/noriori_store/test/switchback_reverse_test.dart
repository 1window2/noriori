import 'dart:io';

import 'package:noriori_core/noriori_core.dart';
import 'package:noriori_store/noriori_store.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as s3;
import 'package:test/test.dart';

/// 끝 역 스위치백 직통 표식 기간(route_link_reverse)을 이음에 붙여 읽는다. 표가 없는 옛 판은 표식이 없다 (11회차 S3).
void main() {
  Future<List<SelectorLink>> read(String path, String route) async {
    final db = UserDb(openDirect(File(':memory:')));
    try {
      await db.customStatement("ATTACH 'file:$path?mode=ro&immutable=1' AS master");
      return await PackReader(db).routeLinks(route);
    } finally {
      await db.close();
    }
  }

  String pack({required bool withReverse}) {
    final dir = Directory.systemTemp.createTempSync('reverse');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = p.join(dir.path, 'master.sqlite');
    final db = s3.sqlite3.open(path);
    db.execute('CREATE TABLE route_link (route_id,seq,other_line_id,other_route_id,kind,side,at_edge,other_node,'
        'next_stop_node,terminal_node,flow,flow_source,valid_from,valid_to)');
    // 한 이음(1950~)에 표식 기간은 1959~2018뿐이다. 다른 줄은 표식이 없다
    db.execute("INSERT INTO route_link VALUES ('r_a',0,'l_b',NULL,'continue',NULL,0,NULL,'n_x','n_y',NULL,NULL,'1950-08-24','ongoing')");
    db.execute("INSERT INTO route_link VALUES ('r_a',3,'l_c',NULL,'continue',NULL,0,NULL,'n_z','n_z',NULL,NULL,NULL,'ongoing')");
    db.execute("INSERT INTO route_link VALUES ('r_a',3,'l_b',NULL,'transfer',NULL,0,NULL,'n_x','n_y',NULL,NULL,NULL,'ongoing')");
    if (withReverse) {
      db.execute('CREATE TABLE route_link_reverse (route_id,seq,other_line_id,next_stop_node,valid_from,valid_to)');
      db.execute("INSERT INTO route_link_reverse VALUES ('r_a',0,'l_b','n_x','1959-12-12','2018-03-17')");
    }
    db.close();
    return path;
  }

  test('표식 기간이 걸린 끝 이어짐만 표식이고, 그날 기간 밖이면 없다', () async {
    final links = await read(pack(withReverse: true), 'r_a');
    final marked = links.singleWhere((link) => link.reverseSpans.isNotEmpty);
    expect(marked.otherLineId, 'l_b');
    expect(marked.kind, 'continue');
    expect(reverseOn(marked, null), ReverseState.used);
    expect(reverseOn(marked, DateSpan.parse('1970-06-01')), ReverseState.used);
    expect(reverseOn(marked, DateSpan.parse('2026-11-16')), isNull);
    expect(reverseOn(marked, DateSpan.parse('1955-06-01')), isNull);
  });

  test('끝나지 않은 표식 기간이면 지금 직통이다', () {
    const link = SelectorLink(
      seq: 0,
      kind: 'continue',
      otherLineId: 'l_b',
      otherRouteId: null,
      validFromLo: '1950-08-24',
      validToHi: DateSpan.maxDate,
      reverseSpans: [ReverseSpan('1950-08-24', DateSpan.maxDate)],
    );
    expect(reverseOn(link, null), ReverseState.now);
    expect(reverseOn(link, DateSpan.parse('2026-11-16')), ReverseState.now);
  });

  test('표식 표가 없는 옛 판은 표식이 없다', () async {
    final links = await read(pack(withReverse: false), 'r_a');
    expect(links.every((link) => link.reverseSpans.isEmpty), isTrue);
  });

  final master = File('../../build/master.sqlite');
  final hasTable = master.existsSync() &&
      s3.sqlite3
          .open(master.path, mode: s3.OpenMode.readOnly)
          .select("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'route_link_reverse'")
          .isNotEmpty;
  test('실제 판: 富士山 大月線→河口湖線 이어짐은 지금 스위치백 직통이고 분기·환승 줄에는 표식이 없다', () async {
    final links = await read(master.absolute.path, 'r_otsuki_line');
    final fuji = links.where((link) => link.kind == 'continue' && link.otherLineId == 'l_kawaguchiko_line' && link.validToHi == DateSpan.maxDate).toList();
    expect(fuji, isNotEmpty);
    expect(fuji.every((link) => reverseOn(link, DateSpan.parse('2026-11-16')) == ReverseState.now), isTrue);
    expect(links.where((link) => link.kind != 'continue').every((link) => link.reverseSpans.isEmpty), isTrue);
  }, skip: hasTable ? null : '표식 표가 있는 판이 없다');
}
