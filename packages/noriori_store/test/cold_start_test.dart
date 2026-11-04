import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Migrator, MigrationStrategy;
import 'package:noriori_core/noriori_core.dart';
import 'package:noriori_store/noriori_store.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as s3;
import 'package:test/test.dart';

import 'support.dart';

// tools/model_check.py의 시작 시나리오를 실제 파일과 SQLite로 돌린다.
void main() {
  late Directory support;
  late StorePaths paths;
  late Map<String, Uint8List> files;
  late MemoryAssets assets;
  late StubInterpreter interpreter;

  setUp(() {
    support = Directory.systemTemp.createTempSync('cold');
    addTearDown(() => support.deleteSync(recursive: true));
    paths = StorePaths(Directory(p.join(support.path, 'app')));
    files = packFiles(support);
    assets = MemoryAssets(files, edition: '2026-11-02');
    interpreter = StubInterpreter();
  });

  ColdStart cold({int appBuild = 1, int version = 1, Map<int, SchemaStep>? steps}) => ColdStart(
        paths: paths,
        assets: assets,
        appBuild: appBuild,
        supportedPackSchema: 1,
        interpreter: (_) async => interpreter,
        now: () => 1000,
        connect: openDirect,
        appUserVersion: version,
        steps: steps ?? const {},
      );

  Future<AppSession> ready({int appBuild = 1, int version = 1, Map<int, SchemaStep>? steps}) async {
    final outcome = await cold(appBuild: appBuild, version: version, steps: steps).run();
    final session = (outcome as StartReady).session;
    addTearDown(session.close);
    return session;
  }

  List<String> packFolders() => paths.datasets
      .listSync()
      .map((e) => p.basename(e.path))
      .toList()
    ..sort();

  group('데이터 팩', () {
    test('첫 시작은 앱 자산을 복사하고 팩을 붙인다', () async {
      final session = await ready();
      expect(session.pack.edition, '2026-11-02');
      expect(packFolders(), ['2026-11-02']);
      final summary = await PackReader(session.db).summary();
      expect(summary.stations, 2);
      expect(summary.lines, 1);
    });

    test('팩은 읽기 전용이다', () async {
      final session = await ready();
      await expectLater(
        session.db.customStatement("INSERT INTO master.line VALUES ('x')"),
        throwsA(anything),
      );
    });

    test('폴더의 더 높은 판을 고른다', () async {
      installPack(paths.datasets, files, edition: '2027-01-01');
      expect((await ready()).pack.edition, '2027-01-01');
    });

    test('지원하지 않는 스키마의 판은 고르지 않는다', () async {
      installPack(paths.datasets, files, edition: '2099-01-01', schema: 2);
      expect((await ready()).pack.edition, '2026-11-02');
    });

    test('잘린 판은 지우고 다음 판을 고른다', () async {
      installPack(paths.datasets, files, edition: '2027-01-01');
      final master = File(p.join(paths.datasets.path, '2027-01-01', 'master.sqlite'));
      master.writeAsBytesSync(master.readAsBytesSync().sublist(0, 100));
      expect((await ready()).pack.edition, '2026-11-02');
      expect(packFolders(), ['2026-11-02']);
    });

    test('헤더가 깨진 판도 같다', () async {
      installPack(paths.datasets, files, edition: '2027-01-01');
      final rail = File(p.join(paths.datasets.path, '2027-01-01', 'rail.pmtiles'));
      rail.writeAsBytesSync(Uint8List(rail.lengthSync()));
      expect((await ready()).pack.edition, '2026-11-02');
    });

    test('매니페스트를 읽을 수 없는 폴더는 지운다', () async {
      Directory(p.join(paths.datasets.path, '2027-01-01')).createSync(recursive: true);
      expect((await ready()).pack.edition, '2026-11-02');
      expect(packFolders(), ['2026-11-02']);
    });

    test('복사 도중 죽으면 임시 폴더만 남고 다음 시작이 처음부터 한다', () async {
      assets.failOn = 'rail.pmtiles';
      await expectLater(cold().run(), throwsStateError);
      expect(packFolders().single, startsWith('.tmp-'));
      assets.failOn = null;
      await ready();
      expect(packFolders(), ['2026-11-02']);
    });

    test('자산의 해시가 다르면 쓰지 않는다', () async {
      final broken = Map.of(files);
      final manifest = await assets.manifestText();
      // 크기와 헤더는 멀쩡하고 내부만 깨진 파일. 해시만 잡을 수 있다.
      final master = Uint8List.fromList(files['master.sqlite']!);
      master[master.length - 1] ^= 0xff;
      broken['master.sqlite'] = master;
      final bad = _FixedManifest(broken, manifest);
      final start = ColdStart(
        paths: paths,
        assets: bad,
        appBuild: 1,
        supportedPackSchema: 1,
        interpreter: (_) async => interpreter,
        now: () => 1000,
        connect: openDirect,
      );
      await expectLater(start.run(), throwsA(isA<PackUnavailable>()));
    });

    test('쓰지 않는 판은 첫 화면 뒤에 지운다', () async {
      installPack(paths.datasets, files, edition: '2027-01-01');
      installPack(paths.datasets, files, edition: '2027-02-01');
      final session = await ready();
      expect(packFolders(), hasLength(2));
      session.deleteUnusedPacks();
      expect(packFolders(), ['2027-02-01']);
    });
  });

  group('캐시 키', () {
    Future<void> seed() async {
      final session = await ready();
      await session.records.apply(Change(before: const [], after: [sampleRide('r')]));
      await session.close();
    }

    test('판과 빌드가 같으면 다시 만들지 않는다', () async {
      await seed();
      interpreter.rides = 0;
      await ready();
      expect(interpreter.rides, 0);
    });

    test('앱 빌드가 바뀌면 다시 만든다', () async {
      await seed();
      interpreter.rides = 0;
      await ready(appBuild: 2);
      expect(interpreter.rides, 1);
    });

    test('판이 바뀌면 다시 만든다', () async {
      await seed();
      interpreter.rides = 0;
      installPack(paths.datasets, files, edition: '2027-01-01');
      await ready();
      expect(interpreter.rides, 1);
    });

    test('재해석 도중 죽으면 옛 캐시와 키가 그대로다', () async {
      final first = await ready();
      await first.records.apply(
        Change(before: const [], after: [sampleRide('r'), sampleRide('s')]),
      );
      await first.close();
      final failing = _FailOnSecond();
      await expectLater(
        ColdStart(
          paths: paths,
          assets: assets,
          appBuild: 2,
          supportedPackSchema: 1,
          interpreter: (_) async => failing,
          now: () => 1000,
          connect: openDirect,
        ).run(),
        throwsA(anything),
      );
      final session = await ready();
      final state = await session.db.select(session.db.cacheStateTable).getSingle();
      expect(state.appBuild, 1);
      expect(await session.db.select(session.db.rideCacheTable).get(), hasLength(2));
    });
  });

  group('user.sqlite', () {
    Future<void> seed() async {
      final session = await ready();
      await session.records.apply(Change(before: const [], after: [sampleRide('r')]));
      await session.close();
    }

    test('앱보다 새 스키마면 파일을 건드리지 않는다', () async {
      await seed();
      final db = s3.sqlite3.open(paths.userDb.path)..execute('PRAGMA user_version = 9');
      db.close();
      final before = paths.userDb.readAsBytesSync();
      final outcome = await cold().run();
      expect((outcome as StartNeedsAppUpdate).fileVersion, 9);
      expect(paths.userDb.readAsBytesSync(), before);
    });

    test('마이그레이션은 사본을 남기고 올린다', () async {
      await seed();
      interpreter.rides = 0;
      final session = await ready(
        version: 2,
        steps: {
          1: (db, m) => db.customStatement('ALTER TABLE ride ADD COLUMN extra TEXT'),
        },
      );
      expect(await session.records.ride(const RideId('r')), isNotNull);
      expect(interpreter.rides, 1, reason: '캐시는 마이그레이션하지 않고 다시 만든다');
      final version = await session.db.customSelect('PRAGMA user_version').getSingle();
      expect(version.read<int>('user_version'), 2);
      expect(File(p.join(paths.support.path, 'user.before-1.sqlite')).existsSync(), isTrue);
      expect(await session.db.select(session.db.rideCacheTable).get(), hasLength(1));
    });

    test('마이그레이션이 실패하면 파일을 그대로 두고 고침 릴리스가 다시 올린다', () async {
      await seed();
      Future<void> broken(UserDb db, Migrator m) async {
        await db.customStatement('ALTER TABLE ride ADD COLUMN extra TEXT');
        throw StateError('버그');
      }

      final outcome = await cold(version: 2, steps: {1: broken}).run();
      expect(outcome, isA<StartRetryLater>());
      expect(paths.userDb.existsSync(), isTrue);

      final session = await ready(
        version: 2,
        steps: {1: (db, m) => db.customStatement('ALTER TABLE ride ADD COLUMN extra TEXT')},
      );
      expect(await session.records.ride(const RideId('r')), isNotNull);
    });

    test('마이그레이션 직후 죽어도 다음 시작이 같은 단계를 다시 돌리지 않는다', () async {
      await seed();
      Future<void> addColumn(UserDb db, Migrator m) =>
          db.customStatement('ALTER TABLE ride ADD COLUMN extra TEXT');

      // 드리프트가 버전을 쓰기 직전에 죽는다.
      final crashing = _DiesBeforeVersionWrite(
        openDirect(paths.userDb),
        version: 2,
        steps: {1: addColumn},
      );
      await expectLater(crashing.customSelect('SELECT 1').get(), throwsStateError);
      await crashing.close();

      final session = await ready(version: 2, steps: {1: addColumn});
      expect(await session.records.ride(const RideId('r')), isNotNull);
    });

    test('사본 임시 파일이 남아 있어도 재시도가 막히지 않는다', () async {
      await seed();
      // 실제 잔여물은 만들다 만 DB 파일이다.
      paths.userDb.copySync(p.join(paths.support.path, 'user.before-1.sqlite.tmp'));
      final session = await ready(
        version: 2,
        steps: {1: (db, m) => db.customStatement('ALTER TABLE ride ADD COLUMN extra TEXT')},
      );
      expect(await session.records.ride(const RideId('r')), isNotNull);
    });

    test('손상된 파일은 -wal까지 격리하고 빈 DB로 넘어가지 않는다', () async {
      await seed();
      paths.userDb.writeAsBytesSync(Uint8List.fromList(List.filled(8192, 7)));
      File('${paths.userDb.path}-wal').writeAsStringSync('wal');

      final first = await cold().run();
      expect(first, isA<StartRestoreOnly>());
      expect(paths.userDb.existsSync(), isFalse);
      final moved = (first as StartRestoreOnly).quarantined.map((f) => p.basename(f.path));
      expect(moved, containsAll(['user.sqlite', 'user.sqlite-wal']));

      expect(await cold().run(), isA<StartRestoreOnly>());
      expect(paths.userDb.existsSync(), isFalse);
    });

    test('데이터 페이지만 손상돼도 격리로 간다', () async {
      final session = await ready();
      for (var i = 0; i < 400; i++) {
        await session.records.apply(Change(before: const [], after: [sampleRide('r$i')]));
      }
      await session.checkpoint();
      await session.close();
      final bytes = paths.userDb.readAsBytesSync();
      const page = 4096;
      final pages = bytes.length ~/ page;
      expect(pages, greaterThan(20));
      // 첫 페이지와 스키마는 멀쩡하다
      for (var at = page * (pages ~/ 2); at < page * (pages - 2); at++) {
        bytes[at] = 0xA5;
      }
      paths.userDb.writeAsBytesSync(bytes);

      final outcome = await cold().run();
      expect(outcome, isA<StartRestoreOnly>());
      expect(paths.userDb.existsSync(), isFalse);
    });

    test('기록이 멀쩡한데 판을 읽다 손상을 만나면 판만 다시 고른다', () async {
      await seed();
      var calls = 0;
      final start = ColdStart(
        paths: paths,
        assets: assets,
        appBuild: 1,
        supportedPackSchema: 1,
        interpreter: (_) async {
          if (++calls == 1) throw s3.SqliteException(extendedResultCode: 11, message: 'malformed');
          return interpreter;
        },
        now: () => 1000,
        connect: openDirect,
        appUserVersion: 1,
        steps: const {},
      );
      final outcome = await start.run();
      expect(outcome, isA<StartReady>());
      addTearDown((outcome as StartReady).session.close);
      expect(calls, 2);
      expect(paths.userDb.existsSync(), isTrue);
      expect(paths.quarantine.existsSync(), isFalse);
    });

    test('다시 고른 판도 읽지 못해도 멀쩡한 기록을 격리하지 않는다', () async {
      await seed();
      final broken = ColdStart(
        paths: paths,
        assets: assets,
        appBuild: 1,
        supportedPackSchema: 1,
        interpreter: (_) async =>
            throw s3.SqliteException(extendedResultCode: 11, message: 'malformed'),
        now: () => 1000,
        connect: openDirect,
        appUserVersion: 1,
        steps: const {},
      );
      expect(await broken.run(), isA<StartRetryLater>());
      expect(paths.userDb.existsSync(), isTrue);
    });

    test('세션을 여는 도중 기록 DB가 깨졌으면 격리로 간다', () async {
      await seed();
      final broken = ColdStart(
        paths: paths,
        assets: assets,
        appBuild: 1,
        supportedPackSchema: 1,
        interpreter: (_) async {
          // 열린 뒤에 드러난 손상을 만든다
          final bytes = paths.userDb.readAsBytesSync();
          for (var at = 4096; at < bytes.length; at++) {
            bytes[at] = 0xff;
          }
          paths.userDb.writeAsBytesSync(bytes);
          throw s3.SqliteException(extendedResultCode: 11, message: 'malformed');
        },
        now: () => 1000,
        connect: openDirect,
        appUserVersion: 1,
        steps: const {},
      );
      expect(await broken.run(), isA<StartRestoreOnly>());
      expect(paths.userDb.existsSync(), isFalse);
    });

    test('격리는 -wal을 본체보다 먼저 옮긴다', () {
      expect(UserDbFile.sidecars.first, '-wal');
      expect(UserDbFile.sidecars.last, '');
    });

    test('검사는 체크포인트 안 된 행을 건드리지 않는다', () async {
      final session = await ready();
      await session.records.apply(Change(before: const [], after: [sampleRide('r')]));
      // 닫지 않고 복사해 강제 종료 직후의 파일을 만든다.
      final crashed = Directory(p.join(support.path, 'crashed'))..createSync();
      final copy = File(p.join(crashed.path, 'user.sqlite'));
      paths.userDb.copySync(copy.path);
      final wal = File('${paths.userDb.path}-wal');
      expect(wal.lengthSync(), greaterThan(0));
      final copiedWal = wal.copySync('${copy.path}-wal');

      final file = UserDbFile(copy, quarantine: Directory(p.join(crashed.path, 'q')));
      expect(file.probe(), isA<UserDbReadable>());
      expect(copiedWal.existsSync(), isTrue);

      final db = s3.sqlite3.open(copy.path);
      expect(db.select('SELECT count(*) AS n FROM ride').single['n'], 1);
      db.close();
    });

    group('복원 전용', () {
      Future<void> corrupt() async {
        await seed();
        paths.userDb.writeAsBytesSync(Uint8List.fromList(List.filled(8192, 7)));
        expect(await cold().run(), isA<StartRestoreOnly>());
      }

      test('화면을 닫으면 보통 길로 돌아가고 격리 파일은 남는다', () async {
        await corrupt();
        final outcome = await cold().run(restoring: true);
        final session = (outcome as StartReady).session;
        addTearDown(session.close);
        expect(session.quarantined.map((f) => p.basename(f.path)), contains('user.sqlite'));
        session.closeQuarantine();
        expect(session.quarantined, isEmpty);
        await session.close();

        final next = await cold().run();
        expect(next, isA<StartReady>());
        await (next as StartReady).session.close();
        final kept = paths.quarantine
            .listSync(recursive: true)
            .whereType<File>()
            .map((f) => p.basename(f.path));
        expect(kept, contains('user.sqlite'));
      });

      test('닫기 전에 죽으면 복원한 내용을 지키고 다시 복원 화면이다', () async {
        await corrupt();
        final outcome = await cold().run(restoring: true);
        final session = (outcome as StartReady).session;
        await session.records.apply(Change(before: const [], after: [sampleRide('복원')]));
        await session.close();

        expect(await cold().run(), isA<StartRestoreOnly>());
        final again = (await cold().run(restoring: true)) as StartReady;
        addTearDown(again.session.close);
        expect(await again.session.records.allRides(), hasLength(1));
      });

      test('복원 세션의 새 DB가 다시 손상되어도 먼저 격리한 파일과 함께 남는다', () async {
        await corrupt();
        final first = (await cold().run(restoring: true)) as StartReady;
        await first.session.close();
        paths.userDb.writeAsBytesSync(Uint8List.fromList(List.filled(8192, 9)));
        for (final suffix in ['-wal', '-shm']) {
          final part = File('${paths.userDb.path}$suffix');
          if (part.existsSync()) part.deleteSync();
        }
        final second = await cold().run(restoring: true);
        final session = (second as StartReady).session;
        addTearDown(session.close);
        final moved = session.quarantined.where((f) => p.basename(f.path) == 'user.sqlite');
        expect(moved, hasLength(2));
      });
    });

    test('사본은 마지막 마이그레이션의 것만 남긴다', () async {
      await seed();
      File('${paths.support.path}/user.before-0.sqlite').writeAsStringSync('옛 사본');
      final session = await ready(
        version: 2,
        steps: {1: (db, m) async => db.customStatement('CREATE TABLE extra(a)')},
      );
      expect(session.db, isNotNull);
      final copies = paths.support
          .listSync()
          .map((e) => p.basename(e.path))
          .where((name) => name.startsWith('user.before-'));
      expect(copies, ['user.before-1.sqlite']);
    });

    test('공간이 모자라 팩을 복사하지 못하면 공간 부족으로 알린다', () async {
      assets.failure = const FileSystemException('쓰기 실패', 'x', OSError('No space', 28));
      final outcome = await cold().run();
      expect((outcome as StartRetryLater).noSpace, isTrue);
      assets.failure = null;
      final session = await ready();
      expect(session.pack.edition, '2026-11-02');
    });

    test('Android의 할당량 초과도 공간 부족이다', () async {
      assets.failure = const FileSystemException('쓰기 실패', 'x', OSError('Quota', 122));
      expect(((await cold().run()) as StartRetryLater).noSpace, isTrue);
    });

    test('백그라운드 연결의 SQLITE_FULL도 공간 부족이다', () async {
      final outcome = await ColdStart(
        paths: paths,
        assets: assets,
        appBuild: 1,
        supportedPackSchema: 1,
        interpreter: (db) async {
          await db.customStatement('PRAGMA max_page_count = 1');
          await db.customStatement('CREATE TABLE full_test (a TEXT)');
          throw StateError('공간이 남았다');
        },
        now: () => 1000,
        appUserVersion: 1,
        steps: const {},
      ).run();
      expect((outcome as StartRetryLater).noSpace, isTrue);
    });

    test('공간 때문이 아닌 파일 오류는 공간 부족이라 하지 않는다', () async {
      assets.failure = const FileSystemException('쓰기 실패', 'x', OSError('Denied', 13));
      await expectLater(cold().run(), throwsA(isA<FileSystemException>()));
    });

    test('재설치 뒤 빈 폴더는 새 DB로 시작한다', () async {
      await seed();
      paths.support.deleteSync(recursive: true);
      final session = await ready();
      expect(await session.records.allRides(), isEmpty);
    });
  });

  test('실제 판을 붙인다', () async {
    final build = Directory(p.join('..', '..', 'build'));
    if (!File(p.join(build.path, 'master.sqlite')).existsSync()) {
      markTestSkipped('build/가 없다');
      return;
    }
    Uint8List read(String name) => File(p.join(build.path, name)).readAsBytesSync();
    final real = {for (final n in PackManifest.required) n: read(n)};
    assets = MemoryAssets(real, edition: 'real');
    final session = await ready();
    final summary = await PackReader(session.db).summary();
    expect(summary.stations, 11771);
    expect(summary.lines, 836);
  }, timeout: const Timeout(Duration(minutes: 1)));
}

class _DiesBeforeVersionWrite extends UserDb {
  _DiesBeforeVersionWrite(super.executor, {super.version, super.steps});

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: super.migration.onCreate,
        onUpgrade: super.migration.onUpgrade,
        beforeOpen: (details) => throw StateError('종료'),
      );
}

final class _FixedManifest implements PackAssets {
  _FixedManifest(this.files, this.manifest);

  final Map<String, Uint8List> files;
  final String manifest;

  @override
  Future<Uint8List> fileBytes(String name) async => files[name]!;

  @override
  Future<String> manifestText() async => manifest;
}

/// 두 번째 기록을 쓰다가 저장이 실패한다.
final class _FailOnSecond implements RecordInterpreter {
  int _calls = 0;

  @override
  RideDerived ride(Ride ride) =>
      ++_calls == 2 ? duplicatedLegs(ride) : const RideDerived(status: ResolveStatus.ok);

  @override
  VisitDerived visit(Visit visit) => const VisitDerived();
}
