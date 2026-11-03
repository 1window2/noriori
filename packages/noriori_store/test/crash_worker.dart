import 'dart:io';

import 'package:noriori_core/noriori_core.dart';
import 'package:noriori_store/noriori_store.dart';

import 'support.dart';

/// `crash_test.dart`가 띄우고 SIGKILL로 죽이는 프로세스. 앱과 같은 연결로 쉬지 않고 쓴다.
///
/// 커밋이 끝난 뒤에만 `ack`를 찍는다. 찍힌 행은 강제 종료 뒤에도 있어야 한다.
Future<void> main(List<String> args) async {
  final root = Directory(args[0]);
  final mode = args[1];
  final paths = StorePaths(Directory('${root.path}/app'));
  final files = packFiles(root);
  final outcome = await ColdStart(
    paths: paths,
    assets: MemoryAssets(files, edition: '2026-11-02'),
    appBuild: 1,
    supportedPackSchema: 1,
    interpreter: (_) async => StubInterpreter(),
    now: () => DateTime.now().millisecondsSinceEpoch,
  ).run();
  final session = (outcome as StartReady).session;
  final folder = LocalBackupFolder(Directory('${root.path}/folder'));
  final backup = AutoBackup(
    folder: folder,
    records: session.records,
    edition: '2026-11-02',
    appBuild: 1,
    now: () => DateTime.now().millisecondsSinceEpoch,
  );
  final restore = BackupRestore(folder: folder, records: session.records);
  stdout.writeln('ready');
  for (var i = 0;; i++) {
    final id = '${args[2]}-$i';
    final change = await session.records.apply(
      Change(before: const [], after: [sampleRide(id, legs: 3)]),
    );
    stdout.writeln('ack $id ${change.after.single.updatedAt}');
    if (mode == 'backup' && i % 7 == 0) await backup.run();
    if (mode == 'restore' && i % 7 == 3) {
      final list = await restore.candidates();
      if (list.isNotEmpty) await restore.merge(list.first.name);
    }
  }
}
