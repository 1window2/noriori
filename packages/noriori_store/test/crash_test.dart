@Tags(['crash'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:noriori_core/noriori_core.dart';
import 'package:noriori_store/noriori_store.dart';
import 'package:test/test.dart';

import 'support.dart';

/// 실제 프로세스를 SIGKILL로 죽인다. 불변식 1, 5를 예외 흉내가 아니라 진짜 강제 종료로 본다.
///
/// 전원 차단은 아니다. OS가 살아 있으므로 커널이 들고 있는 쓰기는 디스크에 간다.
void main() {
  test('강제 종료해도 커밋한 기록이 남고 원본과 캐시가 맞다', () async {
    final root = Directory.systemTemp.createTempSync('crash');
    addTearDown(() => root.deleteSync(recursive: true));
    final random = Random(20261102);
    final acked = <String, int>{};
    const modes = ['plain', 'backup', 'restore', 'backup', 'plain', 'restore'];

    for (var round = 0; round < 12; round++) {
      final mode = modes[round % modes.length];
      final process = await Process.start(
        Platform.resolvedExecutable,
        ['run', 'test/crash_worker.dart', root.path, mode, 'r$round'],
      );
      unawaited(process.stderr.drain<void>());
      final lines = process.stdout.transform(utf8.decoder).transform(const LineSplitter());
      final target = 5 + random.nextInt(60);
      var seen = 0;
      final done = Completer<void>();
      final subscription = lines.listen(
        (line) {
          final parts = line.split(' ');
          if (parts.first == 'ack') {
            acked[parts[1]] = int.parse(parts[2]);
            if (++seen == target && !done.isCompleted) done.complete();
          }
        },
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
      );
      await done.future.timeout(const Duration(seconds: 60));
      await Future<void>.delayed(Duration(milliseconds: random.nextInt(40)));
      process.kill(ProcessSignal.sigkill);
      await process.exitCode;
      await subscription.cancel();

      final check = await ColdStart(
        paths: StorePaths(Directory('${root.path}/app')),
        assets: MemoryAssets(packFiles(root), edition: '2026-11-02'),
        appBuild: 1,
        supportedPackSchema: 1,
        interpreter: (_) async => StubInterpreter(),
        now: () => DateTime.now().millisecondsSinceEpoch,
        connect: openDirect,
      ).run();
      final session = (check as StartReady).session;
      final rides = {for (final ride in await session.records.allRides()) ride.id: ride};
      for (final MapEntry(:key, :value) in acked.entries) {
        final ride = rides[key];
        expect(ride, isNotNull, reason: '$key가 사라졌다 ($mode, $round회)');
        expect(ride!.updatedAt, greaterThanOrEqualTo(value));
        expect(ride.legs, hasLength(3));
      }
      final cached = await session.db.select(session.db.rideCacheTable).get();
      expect(cached.map((row) => row.rideId).toSet(), rides.keys.toSet());
      final folder = LocalBackupFolder(Directory('${root.path}/folder'));
      for (final name in await folder.names()) {
        expect(() => BackupFile.decode(File('${folder.directory.path}/$name').readAsStringSync()),
            returnsNormally,
            reason: '$name이 잘렸다');
      }
      await session.close();
    }
    expect(acked.length, greaterThan(50));
  }, timeout: const Timeout(Duration(minutes: 4)));
}
