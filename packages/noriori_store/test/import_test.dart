import 'dart:io';

import 'package:noriori_core/noriori_core.dart';
import 'package:noriori_store/noriori_store.dart';
import 'package:sqlite3/sqlite3.dart' as s3;
import 'package:test/test.dart';

import 'support.dart';

Ride ride(String id, {int updatedAt = 1}) => Ride(
      rideId: RideId(id),
      datasetVersion: 'e',
      createdAt: 1,
      updatedAt: updatedAt,
      deviceId: 'd',
      importSource: importSourceNoritsubushi,
      fromAlighted: false,
      toAlighted: false,
      legs: const [
        RideLeg(
          seq: 0,
          lineId: LineId('l'),
          routeId: RouteId('r'),
          fromNode: NodeId('a'),
          toNode: NodeId('b'),
          lineLabel: '선',
          fromLabel: 'A',
          toLabel: 'B',
        ),
      ],
    );

void main() {
  group('내용 ID', () {
    test('UUIDv5는 표준값과 같다', () {
      const dns = [
        0x6b, 0xa7, 0xb8, 0x10, 0x9d, 0xad, 0x11, 0xd1, //
        0x80, 0xb4, 0x00, 0xc0, 0x4f, 0xd4, 0x30, 0xc8,
      ];
      expect(uuidV5('python.org', namespace: dns), '886313e1-3b8a-5372-9b90-0c9aee199e5d');
    });

    test('이름공간이 바뀌면 다시 가져온 기록이 겹쳐 들어간다', () {
      const row = CsvRide(
        company: '会社',
        line: '本線',
        from: 'えー',
        to: 'びー',
        meters: 1000,
        dateInput: null,
        comment: null,
        raw: '',
      );
      expect(uuidV5(csvRideKey(row, 1)), '967b6f43-a057-5c58-ae02-dfde98978c25');
    });
  });

  test('이름과 별칭을 접어서 읽는다', () async {
    final dir = Directory.systemTemp.createTempSync('names');
    addTearDown(() => dir.deleteSync(recursive: true));
    final names = s3.sqlite3.open('${dir.path}/names.sqlite');
    names.execute('CREATE TABLE name(entity_type, entity_id, lang, text)');
    names.execute('CREATE TABLE alias(entity_type, entity_id, lang, text, kind)');
    names.execute("INSERT INTO name VALUES ('node', 'n_a', 'ja', '千駄ヶ谷'), "
        "('node', 'n_a', 'ko', '센다가야'), ('line', 'l_a', 'ja', '中央本線')");
    names.execute("INSERT INTO alias VALUES ('route', 'r_a', 'ja', '中央本線 (神田-代々木)', 'noritsubushi')");
    names.close();
    final db = UserDb(openDirect(File(':memory:')));
    addTearDown(db.close);
    await db.customStatement("ATTACH 'file:${dir.path}/names.sqlite?mode=ro' AS names");
    final got = await PackReader(db).importNames();
    expect(got.nodes[importKey('千駄ケ谷')], {'n_a'});
    expect(got.nodes.containsKey(importKey('센다가야')), isFalse);
    expect(got.lines[importKey('中央本線')], {'l_a'});
    expect(got.routes[importKey('中央本線 (神田-代々木)')], {'r_a'});
  });

  test('가져온 기록을 되돌렸다가 다시 넣을 수 있다', () async {
    var clock = 100;
    final db = UserDb(openDirect(File(':memory:')));
    addTearDown(db.close);
    final store = RecordStore(db, interpreter: StubInterpreter(), now: () => clock++);
    final change = await store.apply(Change(before: const [], after: [ride('a'), ride('b')]));
    expect(await store.allRides(), hasLength(2));

    await store.apply(change.undo(now: clock++));
    final gone = await store.allRides();
    expect(gone.every((row) => row.deletedAt != null), isTrue);

    final back = await store.apply(Change(before: gone, after: [ride('a'), ride('b')]));
    final rows = await store.allRides();
    expect(rows.every((row) => row.deletedAt == null), isTrue);
    expect(rows.first.updatedAt, greaterThan(gone.first.updatedAt));
    await store.apply(back.undo(now: clock++));
    expect((await store.allRides()).every((row) => row.deletedAt != null), isTrue);
  });
}
