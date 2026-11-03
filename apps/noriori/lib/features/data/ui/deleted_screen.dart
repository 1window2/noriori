import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/date_text.dart';
import '../../../i18n/strings.g.dart';
import '../controller/deleted_controller.dart';

/// 삭제한 기록 (DESIGN §8.2). 5초가 지난 뒤의 복구는 여기서 한다.
class DeletedScreen extends ConsumerWidget {
  const DeletedScreen({super.key});

  Future<void> _restore(BuildContext context, WidgetRef ref, Ride ride) async {
    final t = context.t.deleted;
    final messenger = ScaffoldMessenger.of(context);
    final commands = ref.read(deletedCommandsProvider);
    final change = await commands.restore(ride);
    ref.invalidate(deletedRidesProvider);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(t.restored),
        duration: const Duration(seconds: 5),
        persist: false,
        action: SnackBarAction(
          label: context.mounted ? context.t.record.undo : '',
          onPressed: () => commands.undo(change),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t.deleted;
    final rides = ref.watch(deletedRidesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.title)),
      body: switch (rides) {
        AsyncValue(hasValue: true, value: final list?) when list.isEmpty => Center(child: Text(t.empty)),
        AsyncValue(hasValue: true, value: final list?) => ListView.separated(
            itemCount: list.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final ride = list[index];
              final legs = ride.legs;
              return ListTile(
                title: Text(legs.isEmpty ? '' : legs.first.lineLabel),
                subtitle: Text(
                  [
                    if (legs.isNotEmpty) '${legs.first.fromLabel} → ${legs.last.toLabel}',
                    if (ride.dateInput != null) dateText(context.t, ride.dateInput!),
                  ].join(' · '),
                ),
                trailing: TextButton(
                  onPressed: () => _restore(context, ref, ride),
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

/// 가져온 파일 전체를 한 번에 지운다. 되돌릴 수 있다.
class ImportedFilesSection extends ConsumerWidget {
  const ImportedFilesSection({super.key});

  Future<void> _delete(BuildContext context, WidgetRef ref, List<Ride> rides) async {
    final t = context.t.deleted;
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t.deleted;
    final files = ref.watch(importedFilesProvider).value ?? const {};
    return Column(
      children: [
        for (final MapEntry(:key, :value) in files.entries)
          ListTile(
            title: Text(key.contains(':') ? key.substring(key.indexOf(':') + 1) : t.fileOldest),
            subtitle: Text(t.fileRides(n: value.length)),
            trailing: TextButton(
              onPressed: () => _delete(context, ref, value),
              child: Text(t.fileDelete),
            ),
          ),
      ],
    );
  }
}
