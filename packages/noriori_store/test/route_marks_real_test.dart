import 'dart:io';

import 'package:noriori_store/noriori_store.dart';
import 'package:test/test.dart';

/// 계통 한정 이름·표식(names.name_route·stop_mark_route)은 그 계통 화면에만 나온다. 판이 없으면 건너뛴다.
void main() {
  final master = File('../../build/master.sqlite');
  final names = File('../../build/names.sqlite');
  final skip = master.existsSync() && names.existsSync() ? null : '판이 없다';
  const line = 'l_fukuchiyama_line';
  const port = 'r_fukuchiyama_line_tsukaguchi_amagasakiko';
  late UserDb db;
  late PackReader reader;

  setUpAll(() async {
    if (skip != null) return;
    db = UserDb(openDirect(File(':memory:')));
    await db.customStatement("ATTACH 'file:${master.absolute.path}?mode=ro&immutable=1' AS master");
    await db.customStatement("ATTACH 'file:${names.absolute.path}?mode=ro&immutable=1' AS names");
    reader = PackReader(db);
  });
  tearDownAll(() async {
    if (skip == null) await db.close();
  });

  test('尼崎港線 계통에서만 尼崎가 옛 臨時乗降場 표식을 단다', () async {
    expect(await reader.pastTempMarks(['n_amagasaki'], line, routeId: port), {'n_amagasaki': 'rinji'});
    expect(await reader.pastTempMarks(['n_amagasaki'], line), isEmpty);
    expect(await reader.pastTempMarks(['n_amagasaki'], line, routeId: 'r_fukuchiyama_line'), isEmpty);
  }, skip: skip);

  test('그날의 계통 한정 이름이 노선 이름보다 먼저다 (尼崎港線 1960년 尼崎乗降場)', () async {
    Future<String?> on(String? route) async =>
        (await reader.nodeNames(['n_amagasaki'], lineId: line, routeId: route, date: '1960-01-01', languages: const ['ja']))['n_amagasaki'];
    // 표식 기간 이름은 표식 행 이름의 꼬리(乗降場)를 따른다 (11회차 S1, 4회차 chugoku_shikoku_1-008)
    expect(await on(port), '尼崎乗降場');
    expect(await on(null), '尼崎');
    expect(await on('r_fukuchiyama_line'), '尼崎');
  }, skip: skip);
}
