import 'dart:io';

import 'package:noriori_store/noriori_store.dart';
import 'package:test/test.dart';

/// 노선 이름표는 지금 이름을 고른다. 기간이 끝난 옛 이름 행은 지금 이름이 없을 때만 쓴다. 판이 없으면 건너뛴다.
void main() {
  final master = File('../../build/master.sqlite');
  final names = File('../../build/names.sqlite');
  final skip = master.existsSync() && names.existsSync() ? null : '판이 없다';

  test('옛 노선 이름(小本線·大阪市営地下鉄御堂筋線)이 아니라 지금 이름 (감사 3회차 tohoku_2-007)', () async {
    final db = UserDb(openDirect(File(':memory:')));
    await db.customStatement("ATTACH 'file:${master.absolute.path}?mode=ro&immutable=1' AS master");
    await db.customStatement("ATTACH 'file:${names.absolute.path}?mode=ro&immutable=1' AS names");
    final book = await PackReader(db, languages: const ['ja']).nameBook();
    await db.close();
    expect(book.lines['l_iwaizumi_line'], '岩泉線');
    expect(book.lines['l_midosuji_line'], 'Osaka Metro御堂筋線');
    expect(book.lines['l_uemachi_line'], '阪堺電気軌道上町線');
  }, skip: skip);

  test('일본어판 역 읽기는 한자가 섞인 이름에만 단다 (가나뿐인 이름은 읽기가 이름 그대로)', () async {
    final db = UserDb(openDirect(File(':memory:')));
    await db.customStatement("ATTACH 'file:${master.absolute.path}?mode=ro&immutable=1' AS master");
    await db.customStatement("ATTACH 'file:${names.absolute.path}?mode=ro&immutable=1' AS names");
    final readings = await PackReader(db, languages: const ['ja']).nodeReadings(
      ['n_tamagawa_osaka_metro', 'n_gala_yuzawa', 'n_higashino_danchi', 'n_shima_isobe'],
    );
    await db.close();
    expect(readings['n_tamagawa_osaka_metro'], 'たまがわ');
    expect(readings['n_gala_yuzawa'], 'がーらゆざわ');
    expect(readings['n_higashino_danchi'], 'ひがしのだんち');
    expect(readings['n_shima_isobe'], 'しまいそべ');
  }, skip: skip);
}
