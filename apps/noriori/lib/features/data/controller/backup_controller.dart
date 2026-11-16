import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noriori_core/noriori_core.dart';
import 'package:noriori_store/noriori_store.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/session_providers.dart';
import '../platform/channel_backup_folder.dart';

export 'package:noriori_core/noriori_core.dart' show BackupNotice;
export 'package:noriori_store/noriori_store.dart'
    show BackupCandidate, CandidateState, RestoreMerged, RestoreOutcome, RestoreRefused;

/// Android 클라우드 백업의 한계에 가까운가 (ARCHITECTURE §3.7). iOS는 OS 백업을 보장으로 치지 않아 알리지 않는다
final osBackupLargeProvider = FutureProvider.autoDispose<bool>((ref) async {
  if (!Platform.isAndroid) return false;
  final support = await getApplicationSupportDirectory();
  return osBackupTooLarge(await StorePaths(Directory(support.path)).osBackupBytes());
});

const _lastAtKey = 'backup.last_at';
const _failedKey = 'backup.failed';

final class BackupState {
  const BackupState({
    this.folder,
    this.lastAt,
    this.failed = false,
    this.unreadable = const [],
    this.needsMerge = const [],
    this.running = false,
  });

  final FolderStatus? folder;
  final int? lastAt;
  final bool failed;
  final List<String> unreadable;
  final List<String> needsMerge;
  final bool running;

  BackupState copyWith({
    FolderStatus? folder,
    int? lastAt,
    bool? failed,
    List<String>? unreadable,
    List<String>? needsMerge,
    bool? running,
  }) =>
      BackupState(
        folder: folder ?? this.folder,
        lastAt: lastAt ?? this.lastAt,
        failed: failed ?? this.failed,
        unreadable: unreadable ?? this.unreadable,
        needsMerge: needsMerge ?? this.needsMerge,
        running: running ?? this.running,
      );
}

final backupFolderProvider = Provider<ChannelBackupFolder>((ref) => const ChannelBackupFolder());

final backupControllerProvider =
    NotifierProvider<BackupController, BackupState>(BackupController.new);

/// 지도 홈에 띄울 안내. 판단은 core가 한다.
final backupNoticeProvider = Provider<BackupNotice?>((ref) {
  final state = ref.watch(backupControllerProvider);
  final folder = state.folder;
  return backupNotice(
    hasFolder: folder != null,
    granted: folder?.granted ?? false,
    failed: state.failed,
    unreadable: state.unreadable.isNotEmpty,
    needsMerge: state.needsMerge.isNotEmpty,
    lastBackupAt: state.lastAt,
    lastChangeAt: ref.watch(lastChangeProvider).value,
    now: ref.read(nowProvider)(),
  );
});

/// 자동 백업을 앱에 잇는다. 무엇을 쓰고 지울지는 store의 `AutoBackup`이 정한다.
final class BackupController extends Notifier<BackupState> {
  Future<void>? _running;

  @override
  BackupState build() {
    unawaited(_load());
    return const BackupState();
  }

  SettingStore get _settings => SettingStore(ref.read(sessionProvider).db);

  Future<void> _load() async {
    final FolderStatus? folder;
    try {
      folder = await ref.read(backupFolderProvider).status();
    } on Object catch (e) {
      // 폴더 상태를 못 읽으면 백업이 도는지 알 수 없다. 지도 홈에 실패로 알린다
      debugPrint('백업 폴더 상태 실패: $e');
      state = const BackupState(failed: true);
      return;
    }
    final last = await _settings.read(_lastAtKey);
    final failed = await _settings.read(_failedKey);
    state = BackupState(
      folder: folder,
      lastAt: last == null ? null : int.parse(last),
      failed: failed == 'true',
    );
    if (folder != null && folder.granted) await run();
  }

  /// 폴더를 고르면 바로 한 번 돈다. 재설치 뒤라면 여기서 병합 복원을 알게 된다.
  Future<FolderPick?> pick() async {
    final folders = ref.read(backupFolderProvider);
    final picked = await folders.pick();
    if (picked == null || picked.insideApp) return picked;
    state = state.copyWith(folder: await folders.status());
    await run();
    return picked;
  }

  /// 겹쳐 돌지 않는다. 앱이 백그라운드로 갈 때와 사용자가 누를 때 부른다.
  Future<void> run() => _running ??= _run().whenComplete(() => _running = null);

  Future<void> _run() async {
    final folder = state.folder;
    if (folder == null || !folder.granted) return;
    final session = ref.read(sessionProvider);
    final folders = ref.read(backupFolderProvider);
    state = state.copyWith(running: true);
    final now = ref.read(nowProvider);
    try {
      final report = await folders.keepAlive(
        () => AutoBackup(
          folder: folders,
          records: session.records,
          edition: session.pack.edition,
          appBuild: session.appBuild,
          now: now,
        ).run(),
      );
      final ok = report.written || report.upToDate;
      final lastAt = report.written ? now() : report.heldAt;
      if (lastAt != null) await _settings.write(_lastAtKey, '$lastAt');
      await _settings.write(_failedKey, '${!ok}');
      state = state.copyWith(
        lastAt: lastAt,
        failed: !ok,
        unreadable: report.unreadable,
        needsMerge: report.needsMerge,
        running: false,
      );
    } on Object {
      // 먼저 상태를 푼다. 기록까지 실패하면 `지금 백업`이 꺼진 채로 남는다
      state = state.copyWith(failed: true, running: false);
      try {
        await _settings.write(_failedKey, 'true');
      } on Object {
        // 다음 실행이 다시 쓴다
      }
    }
  }

  BackupRestore get _restore => BackupRestore(
        folder: ref.read(backupFolderProvider),
        records: ref.read(sessionProvider).records,
      );

  Future<List<BackupCandidate>> candidates() => _restore.candidates();

  /// 폴더 밖에서 고른 백업 파일을 합친다.
  Future<RestoreOutcome> restoreFile(String name, String text) async {
    final outcome = await _restore.mergeText(name, text);
    await run();
    return outcome;
  }

  /// 병합한 뒤 다시 돌아 안내를 지운다.
  Future<RestoreOutcome> restore(String name) async {
    final outcome = await _restore.merge(name);
    await run();
    return outcome;
  }

  /// 손상된 파일을 고른 폴더로 내보낸다. 사용자가 다른 도구로 살려 볼 수 있게 한다.
  Future<int> exportQuarantined() async {
    final session = ref.read(sessionProvider);
    final folders = ref.read(backupFolderProvider);
    var count = 0;
    for (final file in session.quarantined) {
      final stamp = file.parent.uri.pathSegments.where((part) => part.isNotEmpty).last;
      final name = file.uri.pathSegments.last;
      await folders.writeBytes('quarantine-$stamp-$name', await file.readAsBytes());
      count++;
    }
    return count;
  }
}
