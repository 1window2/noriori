import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/date_text.dart';
import '../../../app/widgets/undo_snack.dart';
import '../../../i18n/strings.g.dart';
import '../controller/deleted_controller.dart';

/// 삭제한 기록 (DESIGN §8.2). 5초가 지난 뒤의 복구는 여기서 한다.
class DeletedScreen extends ConsumerWidget {
  const DeletedScreen({super.key});

  Future<void> _restore(BuildContext context, WidgetRef ref, UserRecord record) async {
    final t = context.t.deleted;
    final messenger = ScaffoldMessenger.of(context);
    final commands = ref.read(deletedCommandsProvider);
    final change = await commands.restore(record);
    ref.invalidate(deletedRecordsProvider);
    showUndoSnack(
      messenger,
      message: t.restored,
      undoLabel: context.mounted ? context.t.record.undo : '',
      onUndo: () => commands.undo(change),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t.deleted;
    final records = ref.watch(deletedRecordsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.title)),
      body: switch (records) {
        AsyncValue(hasValue: true, value: final list?) when list.isEmpty => Center(child: Text(t.empty)),
        AsyncValue(hasValue: true, value: final list?) => ListView.separated(
            itemCount: list.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final record = list[index];
              final (title, parts) = switch (record) {
                Ride(:final legs, :final dateInput) => (
                    legs.isEmpty ? '' : legs.first.lineLabel,
                    [
                      if (legs.isNotEmpty) '${legs.first.fromLabel} → ${legs.last.toLabel}',
                      if (dateInput != null) dateText(context.t, dateInput),
                    ],
                  ),
                Visit(:final nodeLabel, :final dateInput) => (
                    nodeLabel,
                    [context.t.record.view.visits, if (dateInput != null) dateText(context.t, dateInput)],
                  ),
                _ => ('', const <String>[]),
              };
              return ListTile(
                title: Text(title),
                subtitle: Text(parts.join(' · ')),
                trailing: TextButton(
                  onPressed: () => _restore(context, ref, record),
                  child: Text(t.restore),
                ),
              );
            },
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// 가져온 파일 전체를 한 번에 지운다. 되돌릴 수 있지만 한 번에 지우는 양이 커서 먼저 묻는다 (DESIGN §8.2).
class ImportedFilesSection extends ConsumerWidget {
  const ImportedFilesSection({super.key});

  Future<void> _delete(BuildContext context, WidgetRef ref, String file, List<Ride> rides) async {
    final t = context.t.deleted;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.fileDeleteTitle(n: rides.length)),
        content: Text(t.fileDeleteBody(file: file)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.fileDeleteCancel)),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.fileDeleteConfirm),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final commands = ref.read(deletedCommandsProvider);
    final undo = context.t.record.undo;
    final change = await commands.deleteAll(rides);
    messenger.showSnackBar(
      SnackBar(
        content: Text(t.fileDeleted(n: rides.length)),
        duration: const Duration(seconds: 5),
        persist: false,
        action: SnackBarAction(label: undo, onPressed: () => commands.undo(change)),
      ),
    );
  }

  static String _name(Translations$deleted$ko t, String key) =>
      key.contains(':') ? key.substring(key.indexOf(':') + 1) : t.fileOldest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t.deleted;
    final files = ref.watch(importedFilesProvider).value ?? const {};
    return Column(
      children: [
        for (final MapEntry(:key, :value) in files.entries)
          ListTile(
            title: Text(_name(t, key)),
            subtitle: Text(t.fileRides(n: value.length)),
            trailing: TextButton(
              onPressed: () => _delete(context, ref, _name(t, key), value),
              child: Text(t.fileDelete),
            ),
          ),
      ],
    );
  }
}
