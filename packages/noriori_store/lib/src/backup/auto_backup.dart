import 'package:noriori_core/noriori_core.dart';

import '../db/user_db.dart';
import '../records/record_store.dart';
import 'backup_folder.dart';

/// 자동 백업 한 번의 결과. 화면은 이 값으로 지도 홈의 안내를 정한다.
final class BackupReport {
  const BackupReport({
    required this.written,
    required this.deleted,
    required this.unreadable,
    required this.needsMerge,
    this.upToDate = false,
    this.heldAt,
  });

  /// 쓰고 다시 읽어 확인까지 했는가. 이때만 마지막 백업 시각을 올린다.
  final bool written;

  /// 쓸 것이 없었다. 폴더에 같은 내용이 있거나 DB가 비었다. 실패가 아니다.
  final bool upToDate;

  /// 같은 내용이 든 파일의 시각. 재설치 뒤에도 마지막 백업 시각을 알 수 있다.
  final int? heldAt;
  final List<String> deleted;

  /// 읽지 못해 지우지 않은 파일. 지도 홈에 표시한다.
  final List<String> unreadable;

  /// 이 기기보다 새로운 값이 든 파일. 재설치나 OS 복원 뒤에 생기고 병합 복원을 묻는다.
  final List<String> needsMerge;
}

/// 사용자의 기록을 보장하는 유일한 수단 (ARCHITECTURE §3.7). 스스로를 지워서는 안 된다.
final class AutoBackup {
  AutoBackup({
    required this.folder,
    required this.records,
    required this.edition,
    required this.appBuild,
    required this.now,
    this.appUserVersion = userSchemaVersion,
  });

  final BackupFolder folder;
  final RecordStore records;
  final String edition;
  final int appBuild;
  final int appUserVersion;
  final int Function() now;

  Future<BackupReport> run() async {
    final contents = await records.snapshot();
    final older = [...await folder.names()]..sort();
    final views = <BackupFileView>[];
    final unreadable = <String>[];
    final needsMerge = <String>[];
    final local = contents.stamps;
    int? heldAt;
    for (final other in older) {
      final text = await _read(other);
      if (!isOurBackup(other, text)) continue;
      final file = _contentsOf(text);
      if (file == null) {
        unreadable.add(other);
        views.add(
          BackupFileView(name: other, readable: false, mergeChangesNothing: false),
        );
        continue;
      }
      if (file.contents.sameAs(contents)) heldAt = file.header.exportedAt;
      final noop = mergeChangesNothing(fileStamps: file.contents.stamps, localStamps: local);
      if (!noop) needsMerge.add(other);
      views.add(BackupFileView(name: other, readable: true, mergeChangesNothing: noop));
    }
    // 빈 DB는 재설치 직후일 수 있다. 복원을 묻기 전에 빈 파일을 쌓지 않는다.
    if (heldAt != null || contents.rowCount == 0) {
      return BackupReport(
        written: false,
        upToDate: true,
        heldAt: heldAt,
        deleted: const [],
        unreadable: unreadable,
        needsMerge: needsMerge,
      );
    }
    final at = now();
    final name = '${BackupHeader.namePrefix}$at.json';
    final text = BackupFile(
      header: BackupHeader(
        userVersion: appUserVersion,
        edition: edition,
        appBuild: appBuild,
        exportedAt: at,
      ),
      contents: contents,
    ).encode();
    final written = await _writeVerified(name, text);
    if (!written) {
      return BackupReport(
        written: false,
        deleted: const [],
        unreadable: unreadable,
        needsMerge: needsMerge,
      );
    }
    views.add(BackupFileView(name: name, readable: true, mergeChangesNothing: true));
    final victims = rotationVictims(views);
    final deleted = <String>[];
    for (final victim in victims) {
      // 새 파일은 이미 검증했다. 옛 파일을 못 지워도 백업은 성공이고 다음에 다시 지운다
      try {
        await folder.delete(victim);
        deleted.add(victim);
      } on Object {
        continue;
      }
    }
    return BackupReport(
      written: true,
      deleted: deleted,
      unreadable: unreadable,
      needsMerge: needsMerge,
    );
  }

  /// 다시 읽어 같은 내용일 때만 쓴 것으로 친다. 아니면 지운다.
  Future<bool> _writeVerified(String name, String text) async {
    try {
      await folder.write(name, text);
      if (await folder.read(name) == text) return true;
      await folder.delete(name);
      return false;
    } on Object {
      return false;
    }
  }

  Future<String?> _read(String name) async {
    try {
      return await folder.read(name);
    } on Object {
      return null;
    }
  }

  /// 해석할 수 있으면 그 내용. 앱보다 새 파일도 읽지 못한 파일로 친다.
  BackupFile? _contentsOf(String? text) {
    if (text == null) return null;
    try {
      final header = BackupFile.decodeHeader(text);
      if (restorePath(header: header, appVersion: appUserVersion) == RestorePath.refuse) {
        return null;
      }
      return BackupFile.decode(text, upgradeTo: appUserVersion);
    } on Object {
      return null;
    }
  }
}
