import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/date_text.dart';
import '../../../app/session_providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/guarded_write.dart';
import '../../../app/widgets/pills.dart';
import '../../../app/widgets/summary_actions.dart';
import '../../../i18n/strings.g.dart';
import '../controller/record_list_controller.dart';
import '../controller/service_session_controller.dart';
import 'complete_card.dart';
import 'line_stem.dart';
import 'ride_ticket.dart';
import 'session_date.dart';

/// 운전 계통 입력. 한 줄 노선도에서 고르고 공식 노선별 분해를 보여 준 뒤 저장한다 (DESIGN §8).
class ServiceSessionScreen extends ConsumerStatefulWidget {
  const ServiceSessionScreen({super.key, required this.serviceId});

  final String serviceId;

  @override
  ConsumerState<ServiceSessionScreen> createState() => _ServiceSessionScreenState();
}

class _ServiceSessionScreenState extends ConsumerState<ServiceSessionScreen> with GuardedWrite {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(serviceSessionProvider.notifier).open(widget.serviceId));
  }

  Future<void> _editDate(String? current) async {
    final result = await showDialog<DateAnswer>(
      context: context,
      builder: (context) => SessionDateDialog(current: current, today: ref.read(todayProvider)),
    );
    if (result != null) ref.read(serviceSessionProvider.notifier).setDate(result.value);
  }

  Future<void> _tap(ServiceStop stop) async {
    final controller = ref.read(serviceSessionProvider.notifier);
    final state = ref.read(serviceSessionProvider);
    final session = context.t.session;
    if (!state.open.contains(stop.node)) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(session.whyClosed), persist: false));
      return;
    }
    if (!controller.asksLap(stop)) return controller.tap(stop);
    final lap = await showDialog<bool>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(state.nameOf(stop.node)),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, false),
            child: Text(session.clear),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, true),
            child: Text(session.lap),
          ),
        ],
      ),
    );
    if (lap == null) return;
    if (lap) {
      controller.pickLap();
    } else {
      controller.tap(stop);
    }
  }

  Future<void> _save() async {
    final t = context.t.service;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final commands = ref.read(recordCommandsProvider);
    final saved = await ref.read(serviceSessionProvider.notifier).save();
    if (saved == null) {
      messenger.showSnackBar(SnackBar(content: Text(t.failed), persist: false));
      return;
    }
    if (saved.ticket.completed && mounted) await showCompleteCard(context, saved.ticket);
    if (!mounted) return;
    showRideTicket(
      context,
      saved.ticket,
      demoted: saved.demoted,
      onUndo: () => commands.undo(saved.change),
    );
    router.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(serviceSessionProvider);
    final controller = ref.read(serviceSessionProvider.notifier);
    final t = context.t.service;
    final session = context.t.session;
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    final raw = state.dateInput;
    final today = ref.watch(todayProvider);
    // 기준일보다 이른 날짜는 입력해도 날짜 모름이다 (DESIGN §4.6)
    final known = raw != null && normalizeRideDate(DateSpan.parse(raw)) != null;
    final dateChip = !known ? session.dateUnknown : (raw == today ? session.today : dateText(context.t, raw));
    final ways = state.ways;
    final summary = state.summary;
    final stops = state.stops;
    final marks = ref.watch(stationMarksProvider);
    final network = ref.watch(networkProvider);
    Color? stem(int gap) {
      if (gap < 0 || gap >= stops.length - 1) return null;
      if (state.covers(gap)) return tokens.lineRidden;
      final a = state.open.contains(stops[gap].node);
      final b = state.open.contains(stops[gap + 1].node);
      return a && b ? tokens.lineUnridden : tokens.selectorGone;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(state.title),
        actions: [
          SessionDateChip(label: dateChip, onTap: () => _editDate(raw)),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (state.open.isEmpty && stops.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(t.none, style: text.bodySmall),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: stops.length,
              itemBuilder: (context, index) {
                final stop = stops[index];
                final open = state.open.contains(stop.node);
                final isFrom = index == state.from?.index;
                final isTo = index == state.to?.index;
                final end = isFrom || isTo;
                final mark = marks.of(network, stop.node);
                final passing = state.passes(stop.node);
                final away = state.stopsAway(stop);
                return InkWell(
                  onTap: () => _tap(stop),
                  child: CustomPaint(
                    painter: LineNodePainter(
                      above: stem(index - 1),
                      aboveWidth: 6,
                      below: stem(index),
                      belowWidth: 6,
                      ring: end || passing || mark != StationMark.none
                          ? tokens.lineRidden
                          : (open ? tokens.text : tokens.textClosed),
                      fill: end || mark == StationMark.stepped ? tokens.lineRidden : tokens.surface,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 56),
                      child: Row(
                        spacing: 10,
                        children: [
                          const SizedBox(width: lineStemColumn - 10),
                          Expanded(
                            child: Text(
                              state.nameOf(stop.node),
                              style: text.titleMedium?.copyWith(
                                fontWeight: end ? FontWeight.w700 : FontWeight.w500,
                                color: open ? tokens.text : tokens.textClosed,
                              ),
                            ),
                          ),
                          if (end)
                            Text(
                              isFrom ? session.from : session.to,
                              style: text.bodySmall?.copyWith(
                                color: tokens.lineRidden,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          if (away != null)
                            Text(
                              session.away(n: away),
                              style: text.bodySmall?.copyWith(color: tokens.textMuted),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Text(
                              (stop.meters / 1000).toStringAsFixed(1),
                              style: text.bodySmall?.copyWith(
                                color: open ? tokens.textMuted : tokens.textClosed,
                                fontFeatures: tabularFigures,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: tokens.paper,
              border: Border(top: BorderSide(color: tokens.hairline)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    if (ways != null)
                      Row(
                        spacing: 8,
                        children: [
                          FilterPill(
                            label: session.directionKm(km: kmLabel(ways.up)),
                            selected: state.up ?? true,
                            onTap: () => controller.setUp(true),
                          ),
                          FilterPill(
                            label: session.directionKm(km: kmLabel(ways.down)),
                            selected: !(state.up ?? true),
                            onTap: () => controller.setUp(false),
                          ),
                        ],
                      ),
                    if (state.isLap)
                      Row(
                        children: [
                          Text(session.laps(n: state.laps), style: text.labelLarge),
                          IconButton(
                            tooltip: session.lapLess,
                            icon: const Icon(Icons.remove),
                            onPressed: state.laps > 1 ? () => controller.setLaps(state.laps - 1) : null,
                          ),
                          IconButton(
                            tooltip: session.lapMore,
                            icon: const Icon(Icons.add),
                            onPressed: () => controller.setLaps(state.laps + 1),
                          ),
                        ],
                      ),
                    if (summary.isNotEmpty)
                      Text(
                        [
                          for (final row in summary)
                            '${state.lines[row.lineId] ?? row.lineId} ${(row.km10 / 10).toStringAsFixed(1)}km',
                        ].join(' · '),
                        style: text.bodySmall,
                      ),
                    SummaryActions(
                      summary: Text(
                            switch ((state.from, state.to, state.meters)) {
                              (null, _, _) => session.pickFrom,
                              (final from?, null, _) => session.leaving(name: state.nameOf(from.node)),
                              (final from?, final to?, final meters?) => session.summary(
                                  from: state.nameOf(from.node),
                                  to: state.nameOf(to.node),
                                  km: kmLabel(meters),
                                ),
                              _ => session.noPath,
                            },
                            style: text.labelLarge,
                          ),
                      actions: [
                        if (state.from != null)
                          TextButton(onPressed: controller.clear, child: Text(session.cancel)),
                        FilledButton(
                          onPressed: state.legs == null || writing ? null : () => guarded(_save, failed: t.failed),
                          child: Text(t.save),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
