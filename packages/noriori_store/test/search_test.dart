import 'dart:io';

import 'package:noriori_store/noriori_store.dart';
import 'package:test/test.dart';

/// 찾기는 일본어(한자·가나), 한국어, 영어로 된다. 검색어는 바인딩 값이라 SQL이나 FTS 문법이 되지 않는다. 판이 없으면 건너뛴다.
void main() {
  final master = File('../../build/master.sqlite');
  final names = File('../../build/names.sqlite');
  final skip = master.existsSync() && names.existsSync() ? null : '판이 없다';
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

  Future<Set<String>> ids(String text) async => {for (final hit in await reader.search(text)) hit.id};

  test('열람 전용 역·노선도 찾고, 그 자리(계통·앞 역)를 안다', () async {
    final hits = await reader.search('稚内桟橋');
    final archive = [for (final hit in hits) if (hit.kind == 'archive') hit.id];
    expect(archive, isNotEmpty);
    final place = (await reader.archivePlaces(archive))[archive.first];
    expect(place?.routeId, 'r_soya_main_line');
    expect(await ids('왓카나이잔교'), contains(archive.first));
    final line = [for (final hit in await reader.search('安倍鉄道')) if (hit.kind == 'archive') hit.id];
    expect((await reader.archivePlaces(line))[line.single]?.node, isNotNull);
  }, skip: skip);

  test('한자·히라가나·가타카나·한국어·영어로 같은 역과 노선을 찾는다', () async {
    for (final text in ['大曽根', 'おおぞね', 'オオゾネ', '오조네', 'Ozone', 'ozone']) {
      expect(await ids(text), contains('n_ozone'), reason: text);
    }
    for (final text in ['三江線', '산코선', 'Sanko']) {
      expect(await ids(text), contains('l_sanko_line'), reason: text);
    }
  });

  test('한국어 음차의 쵸/초·죠/조는 어느 쪽으로 쳐도 찾는다', () async {
    for (final text in ['하마마츠쵸', '하마마츠초']) {
      expect(await ids(text), contains('n_hamamatsucho'), reason: text);
    }
  });

  test('같은 길이로 맞으면 지금 이름이 옛 이름보다 먼저다', () async {
    // 手取温泉의 옛 이름이 上野(かみの)다
    final hits = [for (final hit in await reader.search('上野')) hit.id];
    expect(hits, containsAll(['n_ueno', 'n_tedori_onsen']));
    expect(hits.indexOf('n_ueno'), lessThan(hits.indexOf('n_tedori_onsen')));
  });

  test('버스 구간의 통칭으로 찾으면 이어지는 기록 노선이 나온다', () async {
    for (final text in ['ゆとりーと', 'ゆとりーとライン', '유토리토', 'Yutorito']) {
      expect(await ids(text), contains('l_guideway_bus_shidami_line'), reason: text);
    }
  });

  test('SQL·FTS 문법이 든 검색어도 오류 없이 글자로만 찾는다', () async {
    for (final text in [
      "' OR 1=1 --",
      '"; DROP TABLE ride; --',
      'a" OR "b',
      'NEAR(大 曽)',
      '大曽根*',
      'text:大曽根',
      '大曽根 OR 三江線',
      '^大',
      '(',
      '"',
      '\u0000',
    ]) {
      await expectLater(reader.search(text), completes, reason: text);
    }
    expect(await ids('大曽根 OR 三江線'), isEmpty);
    expect(await ids("' OR 1=1 --"), isEmpty);
  });
}
