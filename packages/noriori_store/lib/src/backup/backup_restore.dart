import 'package:noriori_core/noriori_core.dart';

import '../db/user_db.dart';
import '../records/record_store.dart';
import 'backup_folder.dart';

enum CandidateState {
  ready,

  /// 앱보다 새 파일이다. 앱을 갱신해야 한다.
  tooNew,

  /// 읽지 못했다. 구름 자리표시자나 깨진 파일이다.
  unreadable,
}

/// 복원 화면의 파일 한 줄.
final class BackupCandidate {
  const BackupCandidate({
    required this.name,
    required this.state,
    this.exportedAt,
    this.rowCount,
  });

  final String name;
  final CandidateState state;
  final int? exportedAt;
  final int? rowCount;
}

sealed class RestoreOutcome {
  const RestoreOutcome();
}

/// 들어온 행 수. 0이면 이미 다 있는 파일이다.
final class RestoreMerged extends RestoreOutcome {
  const RestoreMerged(this.taken);

  final int taken;
}

final class RestoreRefused extends RestoreOutcome {
  const RestoreRefused(this.state);

  final CandidateState state;
}

/// 복원은 병합만 있다 (ARCHITECTURE §3.7). 옛 파일을 골라도 새 기록이 사라지지 않는다.
final class BackupRestore {
  const BackupRestore({
    required this.folder,
    required this.records,
    this.appUserVersion = userSchemaVersion,
    this.steps = backupSteps,
  });

  final BackupFolder folder;
  final RecordStore records;
  final int appUserVersion;
  final Map<int, BackupStep> steps;

  /// 머리말로 알아본다. 이름이 비슷해도 noriori 백업이 아니면 고를 수 없다. 새 파일이 먼저다.
  Future<List<BackupCandidate>> candidates() async {
    final found = <BackupCandidate>[];
    for (final name in await folder.names()) {
      final text = await _read(name);
      if (isOurBackup(name, text)) found.add(_inspect(name, text));
    }
    found.sort((a, b) => (b.exportedAt ?? 0).compareTo(a.exportedAt ?? 0));
    return found;
  }

  Future<String?> _read(String name) async {
    try {
      return await folder.read(name);
    } on Object {
      return null;
    }
  }

  BackupCandidate _inspect(String name, String? text) {
    if (text == null) return BackupCandidate(name: name, state: CandidateState.unreadable);
    try {
      final header = BackupFile.decodeHeader(text);
      if (restorePath(header: header, appVersion: appUserVersion) == RestorePath.refuse) {
        return BackupCandidate(
          name: name,
          state: CandidateState.tooNew,
          exportedAt: header.exportedAt,
        );
      }
      final file = BackupFile.decode(text, upgradeTo: appUserVersion, steps: steps);
      return BackupCandidate(
        name: name,
        state: CandidateState.ready,
        exportedAt: header.exportedAt,
        rowCount: file.contents.rowCount,
      );
    } on Object {
      return BackupCandidate(name: name, state: CandidateState.unreadable);
    }
  }

  /// 전체가 한 트랜잭션이다. 도중에 죽으면 없던 일이고 다시 해도 결과가 같다.
  Future<RestoreOutcome> merge(String name) async => mergeText(name, await _read(name));

  /// 공유로 받은 파일처럼 폴더 밖에서 고른 백업도 같은 길로 합친다.
  Future<RestoreOutcome> mergeText(String name, String? text) async {
    if (text != null && !isOurBackup(name, text)) return const RestoreRefused(CandidateState.unreadable);
    final inspected = _inspect(name, text);
    if (inspected.state != CandidateState.ready) return RestoreRefused(inspected.state);
    final file = BackupFile.decode(text!, upgradeTo: appUserVersion, steps: steps);
    return RestoreMerged(await records.merge(file.contents));
  }
}
