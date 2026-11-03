import 'dart:io';
import 'dart:typed_data';

import 'package:noriori_core/noriori_core.dart';
import 'package:noriori_store/noriori_store.dart';
import 'package:test/test.dart';

import 'support.dart';

// tools/model_check.py의 백업 시나리오를 실제 SQLite와 파일로 돌린다.

/// 앱을 지우면 사라지는 쪽. 백업 폴더는 이 밖에 있다.
final class Device {
  Device(this.root, this.clock) {
    db = UserDb(openDirect(File('${root.path}/user.sqlite')));
    store = RecordStore(db, interpreter: StubInterpreter(), now: () => clock.value);
  }

  final Directory root;
  final Clock clock;
  late final UserDb db;
  late final RecordStore store;

  Future<void> save(UserRecord row) =>
      store.apply(Change(before: const [], after: [row]));
}

final class Clock {
  int value = 1000;
}

/// 구름 자리표시자, 쓰기 실패, 잘린 쓰기를 흉내 낸다.
final class FlakyFolder implements BackupFolder {
  FlakyFolder(this.inner);

  final LocalBackupFolder inner;
  final Set<String> placeholders = {};
  bool truncateWrites = false;
  bool failWrites = false;

  @override
  Future<List<String>> names() => inner.names();

  @override
  Future<String?> read(String name) async =>
      placeholders.contains(name) ? null : inner.read(name);

  @override
  Future<void> write(String name, String text) {
    if (failWrites) throw const FileSystemException('공간 부족');
    return inner.write(name, truncateWrites ? text.substring(0, text.length ~/ 2) : text);
  }

  @override
  Future<void> writeBytes(String name, Uint8List bytes) => inner.writeBytes(name, bytes);

  @override
  Future<void> delete(String name) => inner.delete(name);
}

void main() {
  late Directory scratch;
  late FlakyFolder folder;
  late Clock clock;
  late Device device;

  setUp(() {
    scratch = Directory.systemTemp.createTempSync('backup');
    addTearDown(() => scratch.deleteSync(recursive: true));
    folder = FlakyFolder(LocalBackupFolder(Directory('${scratch.path}/folder')));
    clock = Clock();
    device = freshDevice(scratch, clock, 'a');
    addTearDown(device.db.close);
  });

  Future<BackupReport> backup(Device on) {
    clock.value += 10;
    return AutoBackup(
      folder: folder,
      records: on.store,
      edition: '2026-11-02',
      appBuild: 1,
      now: () => clock.value,
    ).run();
  }

  /// 바뀐 것이 있어야 쓴다. 방문 한 행을 고치고 백업한다.
  Future<BackupReport> edited(Device on, int i) async {
    await on.save(sampleVisit('tick', note: '$i'));
    return backup(on);
  }

  Future<int> filesHolding(String id) async {
    var count = 0;
    for (final name in await folder.inner.names()) {
      final text = await folder.inner.read(name);
      if (BackupFile.decode(text!).contents.stamps.containsKey(id)) count++;
    }
    return count;
  }

  /// 앱을 지우고 다시 깐다. 백업 폴더만 남는다.
  Device reinstall(String name) {
    final next = freshDevice(scratch, clock, name);
    addTearDown(next.db.close);
    return next;
  }

  group('회전', () {
    test('읽을 수 있는 파일 3개를 유지한다', () async {
      await device.save(sampleRide('r'));
      for (var i = 0; i < 6; i++) {
        final report = await edited(device, i);
        expect(report.written, isTrue);
      }
      expect(await folder.names(), hasLength(3));
    });

    test('재설치 뒤 복원을 미뤄도 옛 기록이 든 파일이 지워지지 않는다', () async {
      for (var i = 0; i < 40; i++) {
        await device.save(sampleRide('old$i'));
      }
      for (var i = 0; i < 3; i++) {
        await edited(device, i);
      }
      final next = reinstall('b');
      await next.save(sampleRide('new'));
      for (var i = 0; i < 5; i++) {
        final report = await edited(next, i);
        expect(report.needsMerge, hasLength(3));
      }
      expect(await filesHolding('old7'), 3);

      // 복원을 마치면 옛 파일은 무변경이 되어 다시 회전한다.
      final latest = BackupFile.decode((await folder.read((await folder.names()).first))!);
      await next.store.merge(latest.contents);
      expect(await next.store.allRides(), hasLength(41));
      final report = await backup(next);
      expect(report.needsMerge, isEmpty);
      expect(report.deleted, isNotEmpty);
    });

    test('OS 복원으로 DB가 되돌아가도 새 값이 든 파일이 지워지지 않는다', () async {
      await device.save(sampleRide('r', note: '옛값'));
      await device.db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
      final snapshot = File('${device.root.path}/user.sqlite').readAsBytesSync();
      clock.value += 100;
      await device.save(sampleRide('r', note: '새값'));
      for (var i = 0; i < 3; i++) {
        await edited(device, i);
      }
      await device.db.close();
      final restored = Directory('${scratch.path}/restored')..createSync();
      File('${restored.path}/user.sqlite').writeAsBytesSync(snapshot);
      final next = Device(restored, clock);
      addTearDown(next.db.close);
      expect((await next.store.ride(const RideId('r')))!.note, '옛값');
      for (var i = 0; i < 4; i++) {
        final report = await edited(next, i);
        expect(report.needsMerge, isNotEmpty);
      }
      final holders = [
        for (final name in await folder.inner.names())
          if (BackupFile.decode((await folder.read(name))!).contents.rides.single.note == '새값')
            name,
      ];
      expect(holders, hasLength(3));
    });

    test('읽지 못한 파일은 지우지 않고 알린다', () async {
      await device.save(sampleRide('r'));
      for (var i = 0; i < 3; i++) {
        await edited(device, i);
      }
      folder.placeholders.addAll(await folder.names());
      for (var i = 0; i < 3; i++) {
        final report = await edited(device, i + 10);
        expect(report.unreadable, hasLength(3));
      }
      expect(await folder.names(), hasLength(6));
      expect(folder.placeholders.every((n) => File('${folder.inner.directory.path}/$n').existsSync()), isTrue);
    });

    test('앱보다 새 스키마 파일은 읽지 못한 파일이다', () async {
      await device.save(sampleRide('r'));
      final newer = BackupFile(
        header: const BackupHeader(userVersion: 99, edition: 'e', appBuild: 1, exportedAt: 1),
        contents: await device.store.snapshot(),
      );
      await folder.write('noriori-1.json', newer.encode());
      for (var i = 0; i < 5; i++) {
        expect((await backup(device)).unreadable, ['noriori-1.json']);
      }
      expect(await folder.names(), contains('noriori-1.json'));
    });

    test('다른 앱의 JSON은 지우지 않고 안내도 하지 않는다', () async {
      await device.save(sampleRide('r'));
      await folder.write('photos.json', '{"mine":true}');
      await folder.write('list.json', '[1,2]');
      for (var i = 0; i < 5; i++) {
        final report = await edited(device, i);
        expect(report.unreadable, isEmpty);
      }
      expect(await folder.names(), containsAll(['photos.json', 'list.json']));
    });

    test('다른 앱의 JSON은 복원 목록에도 없다', () async {
      await device.save(sampleRide('r'));
      await backup(device);
      await folder.write('photos.json', '{"mine":true}');
      final found = await BackupRestore(folder: folder, records: device.store).candidates();
      expect(found.map((c) => c.name), isNot(contains('photos.json')));
      expect(found, hasLength(1));
    });

    test('앱보다 새 형식의 파일은 읽지 못한 파일이고 복원하지 않는다', () async {
      await device.save(sampleRide('r'));
      final newer = BackupFile(
        header: const BackupHeader(
          userVersion: userSchemaVersion,
          edition: 'e',
          appBuild: 1,
          exportedAt: 1,
          format: BackupHeader.currentFormat + 1,
        ),
        contents: await device.store.snapshot(),
      );
      await folder.write('noriori-1.json', newer.encode());
      expect((await backup(device)).unreadable, ['noriori-1.json']);
      final restore = BackupRestore(folder: folder, records: device.store);
      final found = await restore.candidates();
      expect(found.firstWhere((c) => c.name == 'noriori-1.json').state, CandidateState.tooNew);
      expect(await restore.merge('noriori-1.json'), isA<RestoreRefused>());
    });
  });

  group('변경이 있을 때만 쓴다', () {
    test('같은 내용이 폴더에 있으면 쓰지 않고 실패도 아니다', () async {
      await device.save(sampleRide('r'));
      expect((await backup(device)).written, isTrue);
      final report = await backup(device);
      expect(report.written, isFalse);
      expect(report.upToDate, isTrue);
      expect(await folder.names(), hasLength(1));
    });

    test('파일을 사용자가 지웠으면 다시 쓴다', () async {
      await device.save(sampleRide('r'));
      await backup(device);
      await folder.delete((await folder.names()).single);
      expect((await backup(device)).written, isTrue);
    });

    test('빈 DB는 쓰지 않고 옛 파일을 알린다', () async {
      await device.save(sampleRide('r'));
      await backup(device);
      final next = reinstall('b');
      final report = await backup(next);
      expect(report.written, isFalse);
      expect(report.needsMerge, hasLength(1));
      expect(await folder.names(), hasLength(1));
    });
  });

  group('복원', () {
    BackupRestore restoreOn(Device on, {int version = 1, Map<int, BackupStep> steps = const {}}) =>
        BackupRestore(folder: folder, records: on.store, appUserVersion: version, steps: steps);

    test('새 파일이 먼저 나오고 읽지 못한 파일과 앱보다 새 파일을 구분한다', () async {
      await device.save(sampleRide('r'));
      await backup(device);
      await edited(device, 1);
      final newer = (await device.store.snapshot());
      await folder.write(
        'noriori-9.json',
        BackupFile(
          header: const BackupHeader(userVersion: 99, edition: 'e', appBuild: 1, exportedAt: 9),
          contents: newer,
        ).encode(),
      );
      await folder.write('noriori-8.json', '{"kind":"noriori-backup","trun');
      await folder.write('photos.json', '{"mine":true}');
      final list = await restoreOn(device).candidates();
      final ready = list.where((c) => c.state == CandidateState.ready).toList();
      expect(ready, hasLength(2));
      expect(ready.first.exportedAt, greaterThan(ready.last.exportedAt!));
      expect(ready.first.rowCount, 2);
      expect(list.where((c) => c.state == CandidateState.tooNew).single.name, 'noriori-9.json');
      expect(list.where((c) => c.state == CandidateState.unreadable).single.name, 'noriori-8.json');
      expect(list.map((c) => c.name), isNot(contains('photos.json')));
    });

    test('재설치 뒤 병합하면 행과 캐시가 돌아오고 다시 해도 같다', () async {
      await device.save(sampleRide('r'));
      await device.save(sampleVisit('v'));
      await backup(device);
      final name = (await folder.names()).single;
      final next = reinstall('b');
      final restore = restoreOn(next);
      expect(await restore.merge(name), isA<RestoreMerged>());
      expect(await next.store.allRides(), hasLength(1));
      expect(await next.store.allVisits(), hasLength(1));
      expect(await next.db.select(next.db.rideCacheTable).get(), hasLength(1));
      final again = await restore.merge(name);
      expect((again as RestoreMerged).taken, 0);
    });

    test('앱보다 새 파일은 거부하고 아무것도 바꾸지 않는다', () async {
      await device.save(sampleRide('r'));
      await folder.write(
        'noriori-9.json',
        BackupFile(
          header: const BackupHeader(userVersion: 99, edition: 'e', appBuild: 1, exportedAt: 9),
          contents: await device.store.snapshot(),
        ).encode(),
      );
      final next = reinstall('b');
      final result = await restoreOn(next).merge('noriori-9.json');
      expect((result as RestoreRefused).state, CandidateState.tooNew);
      expect(await next.store.allRides(), isEmpty);
    });

    test('옛 스키마 파일은 단계를 거쳐 올린 뒤 병합한다', () async {
      await device.save(sampleRide('r', note: '옛'));
      await backup(device);
      final name = (await folder.names()).single;
      final next = reinstall('b');
      Map<String, Object?> rename(Map<String, Object?> tables) => {
            ...tables,
            'ride': [
              for (final row in tables['ride']! as List<Object?>)
                {...row! as Map<String, Object?>, 'note': '올림'},
            ],
          };
      final result = await restoreOn(next, version: 2, steps: {1: rename}).merge(name);
      expect(result, isA<RestoreMerged>());
      expect((await next.store.ride(const RideId('r')))!.note, '올림');
    });

    test('올리는 단계가 없으면 읽지 못한 파일이다', () async {
      await device.save(sampleRide('r'));
      await backup(device);
      final name = (await folder.names()).single;
      final next = reinstall('b');
      final result = await restoreOn(next, version: 2).merge(name);
      expect((result as RestoreRefused).state, CandidateState.unreadable);
      expect(await next.store.allRides(), isEmpty);
    });
  });

  group('쓰기 실패', () {
    test('잘린 파일은 남기지 않고 성공으로 치지 않는다', () async {
      await device.save(sampleRide('r'));
      await backup(device);
      folder.truncateWrites = true;
      final report = await edited(device, 1);
      expect(report.written, isFalse);
      expect(report.upToDate, isFalse);
      expect(await folder.names(), hasLength(1));
    });

    test('쓰지 못하면 아무것도 지우지 않는다', () async {
      await device.save(sampleRide('r'));
      for (var i = 0; i < 3; i++) {
        await edited(device, i);
      }
      await folder.write('noriori-1.json', (await folder.read((await folder.names()).first))!);
      folder.failWrites = true;
      final before = await folder.names();
      final report = await edited(device, 9);
      expect(report.written, isFalse);
      expect(report.upToDate, isFalse);
      expect(report.deleted, isEmpty);
      expect(await folder.names(), unorderedEquals(before));
    });
  });

  group('병합', () {
    Future<BackupContents> fileOf(Device on) async => on.store.snapshot();

    test('옛 파일을 복원해도 새 기록이 사라지지 않는다', () async {
      await device.save(sampleRide('r', note: '옛값'));
      final old = await fileOf(device);
      clock.value += 10;
      await device.save(sampleRide('r', note: '새값'));
      await device.save(sampleRide('s'));
      expect(await device.store.merge(old), 0);
      expect((await device.store.ride(const RideId('r')))!.note, '새값');
      expect(await device.store.ride(const RideId('s')), isNotNull);
    });

    test('옛 파일 뒤에 새 파일을 병합해도 새 값이 이긴다', () async {
      await device.save(sampleRide('r', note: '옛값'));
      final older = await fileOf(device);
      clock.value += 10;
      await device.save(sampleRide('r', note: '새값'));
      final newer = await fileOf(device);
      final next = reinstall('b');
      await next.store.merge(older);
      await next.store.merge(newer);
      expect((await next.store.ride(const RideId('r')))!.note, '새값');
    });

    test('병합한 기록의 캐시가 만들어지고 삭제 표시는 캐시를 남기지 않는다', () async {
      await device.save(sampleRide('r'));
      await device.save(sampleRide('gone', deletedAt: 5));
      final next = reinstall('b');
      expect(await next.store.merge(await fileOf(device)), 2);
      final caches = await next.db.select(next.db.rideCacheTable).get();
      expect(caches.map((c) => c.rideId), ['r']);
      expect((await next.store.ride(const RideId('gone')))!.isDeleted, isTrue);
    });

    test('시계가 되돌아간 뒤의 수정이 옛 파일에 지지 않는다', () async {
      await device.save(sampleRide('r', note: 'v1'));
      await backup(device);
      final old = await fileOf(device);
      clock.value = 500;
      await device.save(sampleRide('r', note: 'v2'));
      await device.store.merge(old);
      expect((await device.store.ride(const RideId('r')))!.note, 'v2');
    });

    test('시계가 되돌아간 뒤의 삭제가 되살아나지 않는다', () async {
      final saved = await device.store.apply(
        Change(before: const [], after: [sampleRide('r')]),
      );
      final old = await fileOf(device);
      clock.value = 500;
      await device.store.apply(
        Change(before: saved.after, after: [saved.after.single.withDeletedAt(500)]),
      );
      await device.store.merge(old);
      expect((await device.store.ride(const RideId('r')))!.isDeleted, isTrue);
    });

    test('되돌린 삭제는 그 사이 나간 백업을 복원해도 유지된다', () async {
      final saved = await device.store.apply(
        Change(before: const [], after: [sampleRide('r')]),
      );
      final deleted = await device.store.apply(
        Change(before: saved.after, after: [saved.after.single.withDeletedAt(clock.value)]),
      );
      final whileDeleted = await fileOf(device);
      await device.store.apply(deleted.undo(now: clock.value));
      await device.store.merge(whileDeleted);
      expect((await device.store.ride(const RideId('r')))!.isDeleted, isFalse);
    });

    test('병합이 도중에 실패하면 없던 일이다', () async {
      final next = reinstall('b');
      final bad = BackupContents(
        trips: const [],
        rides: [sampleRide('a'), sampleRide('b', note: StubInterpreter.unwritable)],
        visits: const [],
      );
      await expectLater(next.store.merge(bad), throwsA(anything));
      expect(await next.store.allRides(), isEmpty);
    });
  });
}

Device freshDevice(Directory scratch, Clock clock, String name) {
  final root = Directory('${scratch.path}/$name')..createSync();
  return Device(root, clock);
}
