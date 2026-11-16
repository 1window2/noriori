import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../i18n/strings.g.dart';
import '../controller/backup_controller.dart';
import '../controller/export_controller.dart';
import 'deleted_screen.dart';
import 'format.dart';

/// 백업과 복원 (ARCHITECTURE §2.3 `/settings/data`).
class DataSettingsScreen extends ConsumerWidget {
  const DataSettingsScreen({super.key});

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final t = context.t.data;
    final picked = await ref.read(backupControllerProvider.notifier).pick();
    if (picked != null && picked.insideApp) {
      messenger.showSnackBar(SnackBar(content: Text(t.insideApp)));
    }
  }

  Future<void> _export(BuildContext context, WidgetRef ref, ExportKind kind) async {
    final messenger = ScaffoldMessenger.of(context);
    final t = context.t.data;
    try {
      final done = await ref.read(exportCommandsProvider).export(kind);
      if (done.fellBack) messenger.showSnackBar(SnackBar(content: Text(t.exportedUtf8(name: done.name))));
    } on Object catch (error) {
      debugPrint('내보내기 실패: $error');
      messenger.showSnackBar(SnackBar(content: Text(t.exportFailed)));
    }
  }

  Future<void> _share(BuildContext context, Future<void> Function() send) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.t.data.exportFailed;
    try {
      await send();
    } on Object catch (error) {
      debugPrint('내보내기 실패: $error');
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(backupControllerProvider);
    final controller = ref.read(backupControllerProvider.notifier);
    final t = context.t.data;
    final folder = state.folder;
    final last = state.lastAt;
    return Scaffold(
      appBar: AppBar(title: Text(t.title)),
      body: ListView(
        children: [
          ListTile(
            title: Text(t.folder),
            subtitle: Text(t.folderHint),
            trailing: Text(folder == null ? t.folderNone : folder.name),
            onTap: () => _pick(context, ref),
          ),
          ListTile(
            title: Text(t.lastBackup),
            subtitle: state.failed ? Text(t.lastFailed) : null,
            trailing: Text(last == null ? t.never : formatTime(last)),
          ),
          // 기록 파일이 커서 Android 클라우드 백업에 들어가지 않을 수 있다 (ARCHITECTURE §3.7)
          if (ref.watch(osBackupLargeProvider).value ?? false)
            ListTile(leading: const Icon(Icons.info_outline), title: Text(t.osBackupLarge)),
          ListTile(
            title: Text(t.backupNow),
            enabled: folder != null && folder.granted && !state.running,
            trailing: state.running
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator())
                : null,
            onTap: controller.run,
          ),
          ListTile(
            title: Text(t.restore),
            subtitle: Text(t.restoreHint),
            onTap: () => context.push('/settings/data/restore'),
          ),
          ListTile(
            title: Text(t.exportBackup),
            subtitle: Text(t.exportBackupHint),
            onTap: () => _share(context, () => ref.read(exportCommandsProvider).exportBackup()),
          ),
          for (final (kind, title, hint) in [
            (ExportKind.compat, t.exportCompat, t.exportCompatHint),
            (ExportKind.full, t.exportFull, t.exportFullHint),
          ])
            ListTile(
              title: Text(title),
              subtitle: Text(hint),
              onTap: () => _export(context, ref, kind),
            ),
          const ImportedFilesSection(),
          ListTile(
            title: Text(context.t.importing.title),
            subtitle: Text(context.t.importing.entryHint),
            onTap: () => context.push('/settings/data/import'),
          ),
        ],
      ),
    );
  }
}
