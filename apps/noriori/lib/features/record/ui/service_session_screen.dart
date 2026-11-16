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
import 'session_lines.dart' show askLap;
import 'session_save_bar.dart' show LapCounter;

/// 운행 계통 입력. 한 줄 노선도에서 고르고 공식 노선별 분해를 보여 준 뒤 저장한다 (DESIGN §8).
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
    if (result == null) return;
    // 고른 구간을 그날 탈 수 없으면 날짜를 바꾸지 않고 경고한다 (DESIGN §8.0.1 탑승일)
    final refused = ref.read(serviceSessionProvider.notifier).setDate(result.value);
    if (refused && mounted) await showUnridable(context, context.t.session.unridableDate);
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
    final lap = await askLap(context, state.nameOf(stop.node));
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
    final outcome = await ref.read(serviceSessionProvider.notifier).save();
    if (outcome is ServiceUnridable) {
      if (mounted) await showUnridable(context, context.t.session.unridableSave);
      return;
    }
    if (outcome is! ServiceSaved) {
      messenger.showSnackBar(SnackBar(content: Text(t.failed), persist: false));
      return;
    }
    final saved = outcome;
    if (saved.ticket.completed && mounted) await showCompleteCard(context, saved.ticket);
    if (!mounted) return;
    showRideTicket(
      context,
      saved.ticket,
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
                return _StopRow(
                  stop: stop,
                  name: state.nameOf(stop.node),
                  open: state.open.contains(stop.node),
                  isFrom: stop.index == state.from?.index,
                  isTo: stop.index == state.to?.index,
                  mark: marks.of(network, stop.node),
                  passing: state.passes(stop.node),
                  away: state.stopsAway(stop),
                  above: stem(index - 1),
                  below: stem(index),
                  onTap: () => _tap(stop),
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
                    if (state.isLap) LapCounter(laps: state.laps, onChanged: controller.setLaps),
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
                              // 길이 둘 이상이라 저장 뒤 수정 화면에서 고른다
                              (final from?, final to?, null) when state.legs != null =>
                                '${state.nameOf(from.node)} → ${state.nameOf(to.node)}',
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

/// 계통의 역 한 줄. 누르면 출발역이나 도착역이 된다.
class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.stop,
    required this.name,
    required this.open,
    required this.isFrom,
    required this.isTo,
    required this.mark,
    required this.passing,
    required this.away,
    required this.above,
    required this.below,
    required this.onTap,
  });

  final ServiceStop stop;
  final String name;

  /// 그날 영업하는 역이다.
  final bool open;
  final bool isFrom;
  final bool isTo;
  final StationMark mark;

  /// 고른 구간이 지나는 역이다.
  final bool passing;
  final int? away;
  final Color? above;
  final Color? below;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final session = context.t.session;
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    final end = isFrom || isTo;
    return InkWell(
      onTap: onTap,
      child: CustomPaint(
        painter: LineNodePainter(
          above: above,
          aboveWidth: 6,
          below: below,
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
                  name,
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
              if (away case final count?)
                Text(
                  session.away(n: count),
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
  }
}
