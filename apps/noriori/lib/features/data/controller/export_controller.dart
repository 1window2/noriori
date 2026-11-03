import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noriori_core/noriori_core.dart';
import 'package:noriori_store/noriori_store.dart' show userSchemaVersion;

import '../../../app/file_share.dart';
import '../../../app/session_providers.dart';

enum ExportKind { compat, full }

/// 내보낸 결과. CP932에 없는 글자가 있으면 UTF-8로 저장했다고 알린다.
final class ExportDone {
  const ExportDone({required this.name, required this.fellBack});

  final String name;
  final bool fellBack;
}

final exportCommandsProvider = Provider<ExportCommands>(ExportCommands.new);

/// CSV를 OS 공유 시트로 내보낸다 (DESIGN §10.3).
final class ExportCommands {
  const ExportCommands(this._ref);

  final Ref _ref;

  Future<ExportDone> export(ExportKind kind) async {
    final session = _ref.read(sessionProvider);
    final names = await _ref.read(packReaderProvider).exportNames();
    final contents = await session.records.snapshot();
    final exporter = CsvExporter(_ref.read(networkProvider), names);
    final bytes = switch (kind) {
      ExportKind.compat => compatBytes(exporter.compat(contents.rides)),
      ExportKind.full => fullBytes(exporter.full(contents)),
    };
    final day = _ref.read(todayProvider).replaceAll('-', '');
    final name = 'noriori-${kind.name}-$day.csv';
    await _ref.read(fileShareProvider).share(name, Uint8List.fromList(bytes.bytes));
    return ExportDone(name: name, fellBack: bytes.fellBack);
  }

  /// 자동 백업과 같은 파일을 지금 만들어 보낸다 (ARCHITECTURE §3.7).
  Future<void> exportBackup() async {
    final session = _ref.read(sessionProvider);
    final at = _ref.read(nowProvider)();
    final text = BackupFile(
      header: BackupHeader(
        userVersion: userSchemaVersion,
        edition: session.pack.edition,
        appBuild: session.appBuild,
        exportedAt: at,
      ),
      contents: await session.records.snapshot(),
    ).encode();
    await _ref
        .read(fileShareProvider)
        .share('${BackupHeader.namePrefix}$at.json', Uint8List.fromList(utf8.encode(text)));
  }
}
