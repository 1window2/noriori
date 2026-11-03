import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/date_text.dart';
import '../../../app/session_providers.dart';
import '../../../app/widgets/load_error.dart';
import '../../../app/widgets/undo_snack.dart';
import '../../../i18n/strings.g.dart';
import '../controller/record_list_controller.dart';
import '../controller/record_session_controller.dart';
import 'session_date.dart';
import 'session_lines.dart' show closedNote;

/// 지도에서 역을 눌렀을 때의 시트. 노선을 고르거나 방문을 남긴다.
class StationSheet extends ConsumerWidget {
  const StationSheet({super.key, required this.node, required this.name});

  final String node;
  final String name;

  Future<void> _ride(BuildContext context, WidgetRef ref, String routeId, String lineId) async {
    final router = GoRouter.of(context);
    Navigator.pop(context);
    await ref.read(recordSessionProvider.notifier).open(
          lineId: lineId,
          routeId: routeId,
          fromNode: node,
        );
    await router.push('/record/session?back=1');
  }

  /// 되돌리기가 시트에 가리지 않도록 시트를 닫는다.
  Future<void> _toggleVisit(BuildContext context, WidgetRef ref, List<VisitSummary> visits) async {
    final t = context.t.lineDetail;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final commands = ref.read(recordCommandsProvider);
    final change = visits.isNotEmpty
        ? await commands.deleteVisits(visits.map((visit) => visit.visitId))
        : await commands.addVisit(
            node: node,
            label: name,
            deviceId: await ref.read(deviceIdProvider.future),
            id: uuidV7(millis: ref.read(nowProvider)(), randomBytes: secureRandomBytes()),
          );
    navigator.pop();
    if (change == null) return;
    showUndoSnack(
      messenger,
      message: visits.isNotEmpty ? t.visitRemoved : t.visitAdded,
      undoLabel: t.undo,
      onUndo: () => commands.undo(change),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t.mapSheet;
    final network = ref.watch(networkProvider);
    final book = ref.watch(nameBookProvider);
    final text = Theme.of(context).textTheme;
    // 묶음의 다른 node로 남긴 방문도 같은 역이다 (DESIGN §2.8 B)
    final visits = [
      for (final visit in ref.watch(visitsProvider).value ?? const <VisitSummary>[])
        if (network.sameStation(visit.node, node)) visit,
    ];
    final alighted = (ref.watch(alightedNodesProvider).value ?? const <String>{})
        .any((other) => network.sameStation(other, node));
    final seen = <String>{};
    final routes = [
      for (final routeId in network.routesAtStation(node))
        if (seen.add(network.routes[routeId]!.lineId)) routeId,
    ];
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(name, style: text.titleLarge),
          ),
          for (final routeId in routes)
            ListTile(
              title: Text(book.lines[network.routes[routeId]!.lineId] ?? routeId),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _ride(context, ref, routeId, network.routes[routeId]!.lineId),
            ),
          SwitchListTile(
            title: Text(t.visited),
            subtitle: Text(t.visitedHint),
            value: visits.isNotEmpty || alighted,
            onChanged: (_) {
              if (visits.isNotEmpty || !alighted) return unawaited(_toggleVisit(context, ref, visits));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.t.lineDetail.visitByRide), persist: false),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 위치 미확인 표식의 시트 (DESIGN §7.3).
final _markerFactsProvider = FutureProvider.autoDispose.family<(Map<String, String>, int), MapMarker>((ref, marker) async {
  final names = await ref.watch(packReaderProvider).nodeNames([marker.anchorNode, marker.toNode]);
  final rides = await ref.watch(recordQueriesProvider).countRidesOn(marker.edges);
  return (names, rides);
});

class MarkerSheet extends ConsumerWidget {
  const MarkerSheet({super.key, required this.marker});

  final MapMarker marker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t.mapSheet;
    final text = Theme.of(context).textTheme;
    final facts = ref.watch(_markerFactsProvider(marker)).value;
    final names = facts?.$1 ?? const <String, String>{};
    final year = marker.abolished?.substring(0, 4);
    final line = ref.watch(nameBookProvider).lines[marker.lineId] ?? marker.lineId;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Text(t.beyond, style: text.titleLarge),
            Text(
              [
                line,
                '${names[marker.anchorNode] ?? ''}–${names[marker.toNode] ?? ''}',
                '${marker.km.toStringAsFixed(1)} km',
                if (year != null) closedNote(context, year),
                t.unlocated,
                if (facts != null && facts.$2 > 0) t.rideCount(count: facts.$2),
              ].join(' · '),
              style: text.bodyMedium,
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final router = GoRouter.of(context);
                  Navigator.pop(context);
                  router.push('/line/${marker.lineId}');
                },
                child: Text(t.viewSection),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 지도에서 선로를 눌렀을 때의 시트. 그 구간을 지나는 노선과 완주율을 보여 준다.
class LineSheet extends ConsumerWidget {
  const LineSheet({super.key, required this.lineIds});

  final List<String> lineIds;

  Future<void> _open(BuildContext context, WidgetRef ref, String lineId) async {
    final router = GoRouter.of(context);
    Navigator.pop(context);
    await ref.read(recordSessionProvider.notifier).open(lineId: lineId);
    await router.push('/record/session?back=1');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(nameBookProvider);
    final scores = ref.watch(scoreTableProvider(const BasisCurrent())).value?.byLine;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          for (final lineId in lineIds)
            ListTile(
              title: Text(book.lines[lineId] ?? lineId),
              subtitle: scores?[lineId] == null
                  ? null
                  : Text(
                      '${kmLabel(scores![lineId]!.numMeters)} / '
                      '${kmLabel(scores[lineId]!.denMeters)} km · ${percentLabel(scores[lineId]!)}',
                    ),
              trailing: IconButton(
                tooltip: context.t.lineDetail.open,
                icon: const Icon(Icons.info_outline),
                onPressed: () {
                  final router = GoRouter.of(context);
                  Navigator.pop(context);
                  router.push('/line/$lineId');
                },
              ),
              onTap: () => _open(context, ref, lineId),
            ),
        ],
      ),
    );
  }
}

/// 역 방문 목록 (DESIGN §5.2). 기록 탭의 셋째 목록이다.
class VisitListView extends ConsumerWidget {
  const VisitListView({super.key});

  Future<void> _delete(BuildContext context, WidgetRef ref, VisitSummary visit) async {
    final t = context.t.lineDetail;
    final messenger = ScaffoldMessenger.of(context);
    final commands = ref.read(recordCommandsProvider);
    final change = await commands.deleteVisit(visit.visitId);
    if (change == null) return;
    showUndoSnack(
      messenger,
      message: t.visitRemoved,
      undoLabel: t.undo,
      onUndo: () => commands.undo(change),
    );
  }

  Future<void> _editDate(BuildContext context, WidgetRef ref, VisitSummary visit) async {
    final commands = ref.read(recordCommandsProvider);
    final result = await showDialog<DateAnswer>(
      context: context,
      builder: (context) => SessionDateDialog(current: visit.dateInput, today: ref.read(todayProvider)),
    );
    if (result == null) return;
    final change = await commands.setVisitDate(visit.visitId, result.value);
    if (change == null || !context.mounted) return;
    final t = context.t.lineDetail;
    showUndoSnack(
      ScaffoldMessenger.of(context),
      message: t.visitDated,
      undoLabel: t.undo,
      onUndo: () => commands.undo(change),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visits = ref.watch(visitsProvider);
    final t = context.t.mapSheet;
    return switch (visits) {
      AsyncValue(hasValue: true, value: final list?) when list.isEmpty => Center(child: Text(t.noVisits)),
      AsyncValue(hasValue: true, value: final list?) => ListView.separated(
          itemCount: list.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final visit = list[index];
            return Dismissible(
              key: ValueKey(visit.visitId),
              direction: DismissDirection.endToStart,
              onDismissed: (_) => _delete(context, ref, visit),
              child: ListTile(
                title: Text(visit.label),
                onTap: () => _editDate(context, ref, visit),
                subtitle: Text(
                  visit.date == null
                      ? context.t.record.dateUnknown
                      : dateText(context.t, visit.dateInput!),
                ),
              ),
            );
          },
        ),
      AsyncValue(hasError: true, :final error) => LoadError(error),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}
