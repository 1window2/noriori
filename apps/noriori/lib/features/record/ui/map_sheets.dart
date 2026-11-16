import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/date_text.dart';
import '../../../app/session_providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/load_error.dart';
import '../../../app/widgets/undo_snack.dart';
import '../../../i18n/strings.g.dart';
import '../controller/record_list_controller.dart';
import '../controller/record_session_controller.dart';
import 'session_date.dart';
import 'session_lines.dart' show closedNote;

/// 시트를 닫고 그 노선의 역 선택기를 연다.
Future<void> _record(
  BuildContext context,
  WidgetRef ref, {
  required String lineId,
  String? routeId,
  String? fromNode,
}) async {
  final router = GoRouter.of(context);
  Navigator.pop(context);
  await ref.read(recordSessionProvider.notifier).open(
        lineId: lineId,
        routeId: routeId,
        fromNode: fromNode,
      );
  await router.push('/record/session?back=1');
}

/// 시트를 닫고 노선 상세로 간다.
void _showLine(BuildContext context, String lineId) {
  final router = GoRouter.of(context);
  Navigator.pop(context);
  router.push('/line/$lineId');
}

/// 지도에서 역을 눌렀을 때의 시트. 노선을 고르거나 방문을 남긴다.
class StationSheet extends ConsumerWidget {
  const StationSheet({super.key, required this.node, required this.name});

  final String node;
  final String name;

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
              onTap: () => _record(
                context,
                ref,
                lineId: network.routes[routeId]!.lineId,
                routeId: routeId,
                fromNode: node,
              ),
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
    // 끝 역의 km가 추정값이면 구간 길이도 보이지 않는다 (DESIGN §4.5)
    final network = ref.watch(networkProvider);
    final estimated = network.kmEstimatedBetween(marker.lineId, marker.anchorNode, marker.toNode);
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
                '${marker.km.toStringAsFixed(1)}${estimated ? '?' : ''} km',
                if (year != null) closedNote(context, year),
                t.unlocated,
                if (facts != null && facts.$2 > 0) t.rideCount(count: facts.$2),
              ].join(' · '),
              style: text.bodyMedium,
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _showLine(context, marker.lineId),
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
                onPressed: () => _showLine(context, lineId),
              ),
              onTap: () => _record(context, ref, lineId: lineId),
            ),
        ],
      ),
    );
  }
}

/// 겹친 노선 고르기 (DESIGN §7.4). 화면을 바꾸지 않고 누른 자리 근처에 작은 카드를 띄운다.
Future<void> showLinePicker(
  BuildContext context,
  WidgetRef ref, {
  required Offset at,
  required List<TappedLine> lines,
}) {
  final names = ref.read(nameBookProvider).lines;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 150),
    transitionBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child),
    pageBuilder: (context, _, _) => Consumer(
      builder: (context, ref, _) => LinePicker(
        at: at,
        lines: lines,
        names: names,
        onPick: (lineId) => _record(context, ref, lineId: lineId),
        onInfo: (lineId) => _showLine(context, lineId),
      ),
    ),
  );
}

/// 겹친 노선 팝업의 카드. 현행, 일부 폐지, 전체 폐선 순으로 받은 줄을 그대로 그린다.
class LinePicker extends StatelessWidget {
  const LinePicker({
    super.key,
    required this.at,
    required this.lines,
    required this.names,
    required this.onPick,
    required this.onInfo,
  });

  /// 누른 자리. 화면 좌표(논리 픽셀)다.
  final Offset at;
  final List<TappedLine> lines;
  final Map<String, String> names;

  /// 줄을 눌렀다. 그 노선의 기록 화면으로 간다.
  final void Function(String lineId) onPick;

  /// 줄 끝의 정보 단추. 노선 상세로 간다.
  final void Function(String lineId) onInfo;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    final t = context.t.mapSheet;
    return CustomSingleChildLayout(
      delegate: _PickerLayout(at: at, padding: MediaQuery.paddingOf(context)),
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: t.pickerLabel,
        child: Material(
          color: tokens.paper,
          surfaceTintColor: Colors.transparent,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: tokens.hairline),
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicWidth(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final line in lines)
                    _PickerRow(
                      name: names[line.lineId] ?? line.lineId,
                      note: switch (line.kind) {
                        TappedLineKind.current => null,
                        TappedLineKind.partlyClosed => t.partlyClosed,
                        TappedLineKind.closed => t.closed,
                      },
                      color: line.kind == TappedLineKind.current ? tokens.text : tokens.textClosed,
                      infoColor: line.kind == TappedLineKind.current ? tokens.textMuted : tokens.textClosed,
                      style: text.bodyLarge,
                      noteStyle: text.bodySmall,
                      onTap: () => onPick(line.lineId),
                      onInfo: () => onInfo(line.lineId),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.name,
    required this.note,
    required this.color,
    required this.infoColor,
    required this.style,
    required this.noteStyle,
    required this.onTap,
    required this.onInfo,
  });

  final String name;
  final String? note;
  final Color color;
  final Color infoColor;
  final TextStyle? style;
  final TextStyle? noteStyle;
  final VoidCallback onTap;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              spacing: 8,
              children: [
                Expanded(child: Text(name, style: style?.copyWith(color: color))),
                if (note case final note?) Text(note, style: noteStyle?.copyWith(color: color)),
                IconButton(
                  tooltip: context.t.lineDetail.open,
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  icon: Icon(Icons.info_outline, color: infoColor),
                  onPressed: onInfo,
                ),
              ],
            ),
          ),
        ),
      );
}

/// 카드를 누른 자리 바로 아래에 둔다. 아래가 모자라면 위로 올리고, 화면 가장자리에서 16dp 띄운다.
final class _PickerLayout extends SingleChildLayoutDelegate {
  const _PickerLayout({required this.at, required this.padding});

  final Offset at;
  final EdgeInsets padding;

  static const _margin = 16.0;
  static const _gap = 12.0;
  static const _minWidth = 220.0;
  static const _maxWidth = 320.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final size = constraints.biggest;
    final width = (size.width - _margin * 2).clamp(0.0, _maxWidth).toDouble();
    final height = math.max(0.0, size.height - padding.vertical - _margin * 2);
    return BoxConstraints(minWidth: math.min(_minWidth, width), maxWidth: width, maxHeight: height);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final left = (at.dx - childSize.width / 2)
        .clamp(_margin, math.max(_margin, size.width - childSize.width - _margin))
        .toDouble();
    final top = padding.top + _margin;
    final bottom = size.height - padding.bottom - _margin - childSize.height;
    final below = at.dy + _gap;
    final above = at.dy - _gap - childSize.height;
    final y = below <= bottom ? below : above >= top ? above : bottom;
    return Offset(left, math.max(top, y));
  }

  @override
  bool shouldRelayout(_PickerLayout old) => old.at != at || old.padding != padding;
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
