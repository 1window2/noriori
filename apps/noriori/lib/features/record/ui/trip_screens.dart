import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/date_text.dart';
import '../../../app/widgets/load_error.dart';
import '../../../app/widgets/undo_snack.dart';
import '../../../i18n/strings.g.dart';
import '../controller/record_list_controller.dart';
import '../controller/trip_controller.dart';
import 'ride_tile.dart';

/// 여정 이름을 묻는다. 취소하면 null.
Future<String?> askTripName(BuildContext context, {String? current}) => showDialog<String>(
      context: context,
      builder: (context) => _NameDialog(current: current),
    );

class _NameDialog extends StatefulWidget {
  const _NameDialog({this.current});

  final String? current;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _field = TextEditingController(text: widget.current);

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _done() {
    final value = _field.text.trim();
    if (value.isNotEmpty) Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.trip;
    return AlertDialog(
      title: Text(t.nameTitle),
      content: TextField(
        controller: _field,
        autofocus: true,
        decoration: InputDecoration(hintText: t.nameHint),
        onSubmitted: (_) => _done(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.t.session.cancel)),
        FilledButton(onPressed: _done, child: Text(t.save)),
      ],
    );
  }
}

String _meta(BuildContext context, TripSummary trip) {
  final t = context.t;
  final first = trip.firstDate;
  final last = trip.lastDate;
  final dates = first == null
      ? null
      : (first == last ? dateText(t, first) : '${dateText(t, first)} – ${dateText(t, last!)}');
  return [
    ?dates,
    t.trip.rides(n: trip.rides),
    t.record.km(km: kmLabel(trip.km10 * 100)),
  ].join(' · ');
}

/// 기록 탭의 여정 목록.
class TripListView extends ConsumerWidget {
  const TripListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t.trip;
    final text = Theme.of(context).textTheme;
    return switch (ref.watch(tripListProvider)) {
      AsyncValue(hasValue: true, value: final list?) when list.isEmpty => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [Text(t.empty), Text(t.emptyHint, textAlign: TextAlign.center, style: text.bodySmall)],
            ),
          ),
        ),
      AsyncValue(hasValue: true, value: final list?) => ListView.separated(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: list.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final trip = list[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              title: Text(trip.title),
              subtitle: Text(_meta(context, trip)),
              onTap: () => context.push('/trip/${trip.tripId.value}'),
            );
          },
        ),
      AsyncValue(hasError: true, :final error) => LoadError(error),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

/// 여정 하나. 묶인 기록과 이름 바꾸기, 풀기.
class TripDetailScreen extends ConsumerWidget {
  const TripDetailScreen({super.key, required this.tripId});

  final String tripId;

  Future<void> _rename(BuildContext context, WidgetRef ref, TripSummary trip) async {
    final name = await askTripName(context, current: trip.title);
    if (name != null) await ref.read(tripCommandsProvider).rename(trip.tripId, name);
  }

  Future<void> _end(
    BuildContext context,
    WidgetRef ref,
    TripSummary trip, {
    required bool withRides,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final t = context.t;
    final commands = ref.read(tripCommandsProvider);
    final change = withRides
        ? await commands.deleteWithRides(trip.tripId)
        : await commands.dissolve(trip.tripId);
    if (context.mounted) router.pop();
    if (change == null) return;
    showUndoSnack(
      messenger,
      message: withRides ? t.trip.deleted : t.trip.dissolved,
      undoLabel: t.record.undo,
      onUndo: () => commands.undo(change),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t.trip;
    final text = Theme.of(context).textTheme;
    final trips = ref.watch(tripListProvider).value ?? const <TripSummary>[];
    final trip = trips.where((item) => item.tripId.value == tripId).firstOrNull;
    if (trip == null) return Scaffold(appBar: AppBar());
    final rides = (ref.watch(rideListProvider).value ?? const <RideSummary>[])
        .where((ride) => ride.tripId?.value == tripId)
        .toList()
        .reversed
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(trip.title)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
            child: Text(_meta(context, trip), style: text.bodyMedium),
          ),
          const Divider(height: 1),
          for (final ride in rides) ...[
            InkWell(
              onTap: () => context.push('/record/${ride.rideId.value}'),
              child: RideTile(ride: ride),
            ),
            const Divider(height: 1),
          ],
          ListTile(title: Text(t.rename), onTap: () => _rename(context, ref, trip)),
          ListTile(
            title: Text(t.dissolve),
            subtitle: Text(t.dissolveHint),
            onTap: () => _end(context, ref, trip, withRides: false),
          ),
          ListTile(
            title: Text(t.delete),
            subtitle: Text(t.deleteHint),
            onTap: () => _end(context, ref, trip, withRides: true),
          ),
        ],
      ),
    );
  }
}
