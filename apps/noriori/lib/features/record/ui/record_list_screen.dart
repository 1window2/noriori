import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/load_error.dart';
import '../../../app/widgets/undo_snack.dart';
import '../../../i18n/strings.g.dart';
import '../controller/record_list_controller.dart';
import '../controller/trip_controller.dart';
import 'ride_tile.dart';
import 'trip_screens.dart';

/// 기록 목록. 밀어서 지우거나 길게 눌러 여러 개를 고르고, 5초 안에 되돌릴 수 있다.
class RecordListScreen extends ConsumerStatefulWidget {
  const RecordListScreen({super.key});

  @override
  ConsumerState<RecordListScreen> createState() => _RecordListScreenState();
}

class _RecordListScreenState extends ConsumerState<RecordListScreen> {
  final _picked = <RideId>{};

  void _offerUndo(ScaffoldMessengerState messenger, Change change) {
    final t = context.t.record;
    final commands = ref.read(recordCommandsProvider);
    messenger.showSnackBar(
      SnackBar(
        content: Text(t.deleted),
        duration: const Duration(seconds: 5),
        persist: false,
        action: SnackBarAction(label: t.undo, onPressed: () => commands.undo(change)),
      ),
    );
  }

  Future<void> _delete(RideSummary ride) async {
    final messenger = ScaffoldMessenger.of(context);
    final change = await ref.read(recordCommandsProvider).delete(ride.rideId);
    if (change != null && mounted) _offerUndo(messenger, change);
  }

  Future<void> _deletePicked() async {
    final messenger = ScaffoldMessenger.of(context);
    final change = await ref.read(recordCommandsProvider).deleteAll(_picked);
    if (!mounted) return;
    setState(_picked.clear);
    if (change != null) _offerUndo(messenger, change);
  }

  /// 저장할 때 묻지 않고 나중에 고른 기록을 묶는다 (DESIGN §6.1).
  Future<void> _bundle() async {
    final messenger = ScaffoldMessenger.of(context);
    final t = context.t;
    final name = await askTripName(context);
    if (name == null || !mounted) return;
    final commands = ref.read(tripCommandsProvider);
    final change = await commands.make(name, _picked);
    if (!mounted) return;
    setState(_picked.clear);
    showUndoSnack(
      messenger,
      message: t.trip.made,
      undoLabel: t.record.undo,
      onUndo: () => commands.undo(change),
    );
  }

  void _flip(RideId id) => setState(() {
        if (!_picked.remove(id)) _picked.add(id);
      });

  @override
  Widget build(BuildContext context) {
    final rides = ref.watch(rideListProvider);
    final t = context.t.record;
    final picking = _picked.isNotEmpty;
    return switch (rides) {
      AsyncValue(hasValue: true, value: final list?) when list.isEmpty => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [Text(t.empty), Text(t.emptyHint)],
          ),
        ),
      AsyncValue(hasValue: true, value: final list?) => Column(
          children: [
            if (picking)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: context.t.session.cancel,
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(_picked.clear),
                    ),
                    Expanded(child: Text(t.picked(count: _picked.length))),
                    TextButton(
                      onPressed: () => setState(() {
                        _picked.addAll(list.map((ride) => ride.rideId));
                      }),
                      child: Text(t.pickAll),
                    ),
                    FilledButton(onPressed: _deletePicked, child: Text(t.delete)),
                  ],
                ),
              ),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.only(bottom: picking ? 16 : 88),
                itemCount: list.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final ride = list[index];
                  final tile = InkWell(
                    onTap: picking
                        ? () => _flip(ride.rideId)
                        : () => context.push('/record/${ride.rideId.value}'),
                    onLongPress: () => _flip(ride.rideId),
                    child: Row(
                      children: [
                        if (picking)
                          Checkbox(
                            value: _picked.contains(ride.rideId),
                            onChanged: (_) => _flip(ride.rideId),
                          ),
                        Expanded(child: RideTile(ride: ride)),
                      ],
                    ),
                  );
                  if (picking) return tile;
                  return Dismissible(
                    key: ValueKey(ride.rideId),
                    direction: DismissDirection.endToStart,
                    background: ColoredBox(
                      color: context.tokens.lineClosedRidden,
                      child: const Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: EdgeInsets.only(right: 20),
                          child: Icon(Icons.delete_outline, color: Colors.white),
                        ),
                      ),
                    ),
                    onDismissed: (_) => _delete(ride),
                    child: tile,
                  );
                },
              ),
            ),
            if (picking)
              Padding(
                // 오른쪽 아래의 기록 추가 단추를 피한다
                padding: const EdgeInsets.fromLTRB(16, 8, 96, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(onPressed: _bundle, child: Text(context.t.trip.make)),
                ),
              ),
          ],
        ),
      AsyncValue(hasError: true, :final error) => LoadError(error),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}
