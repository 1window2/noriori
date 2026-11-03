import 'dart:io';

import 'package:noriori_core/noriori_core.dart';
import 'package:noriori_store/noriori_store.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  late UserDb db;
  late StubInterpreter interpreter;
  late RecordStore store;
  var clock = 1000;

  setUp(() {
    final dir = Directory.systemTemp.createTempSync('record');
    addTearDown(() => dir.deleteSync(recursive: true));
    db = UserDb(openDirect(File('${dir.path}/user.sqlite')));
    addTearDown(db.close);
    interpreter = StubInterpreter();
    clock = 1000;
    store = RecordStore(db, interpreter: interpreter, now: () => clock);
  });

  Future<int> cacheRows() async {
    final caches = await db.select(db.rideCacheTable).get();
    return caches.length;
  }

  Change insert(UserRecord row) => Change(before: const [], after: [row]);

  group('apply', () {
    test('원본과 캐시를 함께 쓴다', () async {
      await store.apply(insert(sampleRide('r', legs: 2)));
      final ride = await store.ride(const RideId('r'));
      expect(ride!.legs, hasLength(2));
      expect(ride.trainName, 'はやぶさ3号');
      expect(ride.transferNodes, [const NodeId('n_b')]);
      final cache = await db.select(db.rideCacheTable).getSingle();
      expect(cache.km10, 2);
      expect(cache.resolveStatus, 'ok');
      expect(await db.select(db.rideEdgeTable).get(), hasLength(2));
    });

    test('구간을 줄이면 옛 구간과 캐시가 남지 않는다', () async {
      await store.apply(insert(sampleRide('r', legs: 3)));
      await store.apply(insert(sampleRide('r', legs: 1)));
      expect((await store.ride(const RideId('r')))!.legs, hasLength(1));
      expect(await db.select(db.rideEdgeTable).get(), hasLength(1));
    });

    test('삭제는 표시만 남기고 캐시를 지운다', () async {
      final saved = await store.apply(insert(sampleRide('r')));
      clock = 2000;
      await store.apply(
        Change(before: saved.after, after: [saved.after.single.withDeletedAt(clock)]),
      );
      expect((await store.ride(const RideId('r')))!.isDeleted, isTrue);
      expect(await cacheRows(), 0);
      expect(await db.select(db.rideEdgeTable).get(), isEmpty);
    });

    test('계산 못 하는 기록은 그 기록만 error이고 원본은 남는다', () async {
      await store.apply(
        Change(
          before: const [],
          after: [sampleRide('good'), sampleRide('bad', note: '깨짐')],
        ),
      );
      final caches = await db.select(db.rideCacheTable).get();
      final status = {for (final c in caches) c.rideId: c.resolveStatus};
      expect(status, {'good': 'ok', 'bad': 'error'});
      expect(await store.ride(const RideId('bad')), isNotNull);
    });

    test('계산 못 하는 방문은 날짜와 묶음 없이 남는다', () async {
      await store.apply(insert(sampleVisit('v', note: '깨짐')));
      expect(await store.visit(const VisitId('v')), isNotNull);
      final cache = await db.select(db.visitCacheTable).getSingle();
      expect(cache.groupId, isNull);
    });

    test('중간에 실패하면 원본도 캐시도 남지 않는다', () async {
      final change = Change(
        before: const [],
        after: [sampleRide('r'), sampleRide('s', note: StubInterpreter.unwritable)],
      );
      await expectLater(store.apply(change), throwsA(anything));
      expect(await store.ride(const RideId('r')), isNull);
      expect(await store.ride(const RideId('s')), isNull);
      expect(await cacheRows(), 0);
    });
  });

  group('updated_at', () {
    test('시계가 되돌아가도 그 행에서는 앞으로만 간다', () async {
      await store.apply(insert(sampleRide('r')));
      clock = 500;
      final second = await store.apply(insert(sampleRide('r')));
      expect(second.after.single.updatedAt, 1001);
    });

    test('삭제도 시각을 올린다', () async {
      final saved = await store.apply(insert(sampleRide('r')));
      final deleted = await store.apply(
        Change(before: saved.after, after: [saved.after.single.withDeletedAt(clock)]),
      );
      expect(deleted.after.single.updatedAt, greaterThan(saved.after.single.updatedAt));
    });
  });

  group('되돌리기', () {
    test('새 변경으로 저장되어 그 사이 나간 백업을 이긴다', () async {
      final first = await store.apply(insert(sampleRide('r', note: '전')));
      final edit = await store.apply(
        Change(before: first.after, after: [sampleRide('r', note: '후')]),
      );
      final undone = await store.apply(edit.undo(now: clock));
      final ride = await store.ride(const RideId('r'));
      expect(ride!.note, '전');
      expect(undone.after.single.updatedAt, greaterThan(edit.after.single.updatedAt));
    });

    test('새 행은 삭제 표시가 되고 지워지지 않는다', () async {
      final saved = await store.apply(insert(sampleRide('r')));
      await store.apply(saved.undo(now: clock));
      expect((await store.ride(const RideId('r')))!.isDeleted, isTrue);
      expect(await cacheRows(), 0);
    });
  });

  test('변경 내역이 백업을 왕복한다', () async {
    await store.merge(
      const BackupContents(
        trips: [],
        rides: [],
        visits: [],
        changeNotes: [
          ChangeNote(noteId: 'n', edition: 'e', body: '[]', createdAt: 5, updatedAt: 5, deviceId: ''),
        ],
      ),
    );
    final snapshot = await store.snapshot();
    expect(snapshot.changeNotes.single.noteId, 'n');
    expect(snapshot.rowCount, 1);
  });

  test('옛 파일의 설정은 지금 고른 값을 덮지 않는다', () async {
    await db.customStatement("INSERT INTO setting (key, value) VALUES ('theme', 'light')");
    await store.merge(const BackupContents(trips: [], rides: [], visits: [], settings: {'theme': 'dark'}));
    final rows = await db.select(db.settingTable).get();
    expect(rows.singleWhere((row) => row.key == 'theme').value, 'light');
  });

  test('연대만 아는 기록이 처음 탄 해와 마지막 해를 막지 않는다', () async {
    final queries = RecordQueries(db);
    final ride = sampleRide('연대');
    await store.apply(insert(ride));
    await db.customStatement("UPDATE ride_cache SET date = '198X-XX-XX'");
    expect(await queries.watchRiddenEdgeYears().first, isEmpty);
    expect(await queries.lastRideYears(carryover: true), isEmpty);
    await db.customStatement("UPDATE ride_cache SET date = '2015-XX-XX'");
    db.markTablesUpdated([db.rideCacheTable]);
    expect((await queries.watchRiddenEdgeYears().first).values, [2015]);
    expect((await queries.lastRideYears(carryover: true)).values, [2015]);
  });
}
