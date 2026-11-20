import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/session_providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/guarded_write.dart';
import '../../../app/widgets/pills.dart';
import '../../../app/widgets/summary_actions.dart';
import '../../../i18n/strings.g.dart';
import '../controller/record_list_controller.dart';
import '../controller/record_session_controller.dart';
import 'complete_card.dart';
import 'ride_ticket.dart';
import 'session_date.dart' show showUnridable;
import 'session_lines.dart' show handDate;

/// 이설 질문의 답. 바깥을 눌러 닫으면 답이 아니라 취소다.
final class _RelocationAnswer {
  const _RelocationAnswer(this.option);

  final RelocationOption? option;
}

/// 선택 요약과 기록하기 단추 하나.
class SessionSaveBar extends ConsumerStatefulWidget {
  const SessionSaveBar({super.key, required this.state, required this.returnBack});

  final RecordSessionState state;
  final bool returnBack;

  @override
  ConsumerState<SessionSaveBar> createState() => _SessionSaveBarState();
}

class _SessionSaveBarState extends ConsumerState<SessionSaveBar> with GuardedWrite {
  Future<void> _save() async {
    final controller = ref.read(recordSessionProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final t = context.t;
    var outcome = await controller.save();
    if (!mounted) return;
    if (outcome case SaveAskDirection(:final upMeters, :final downMeters)) {
      final direction = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(t.session.chooseDirection),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, seqUp),
              child: Text(t.session.directionKm(km: kmLabel(upMeters))),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, seqDown),
              child: Text(t.session.directionKm(km: kmLabel(downMeters))),
            ),
          ],
        ),
      );
      if (direction == null) return;
      outcome = await controller.save(direction: direction);
    } else if (outcome case SaveAskRelocation(:final options)) {
      final answer = await showDialog<_RelocationAnswer>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(t.session.chooseRelocation),
          children: [
            for (final option in options)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, _RelocationAnswer(option)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(relocationLabel(context, options, option)),
                    // 길마다 존속 기간을 작게 적는다 (사용자 요청 2026-11-08)
                    Text(
                      relocationSpan(options, option),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.tokens.textMuted),
                    ),
                  ],
                ),
              ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, const _RelocationAnswer(null)),
              child: Text(t.session.dontKnow),
            ),
          ],
        ),
      );
      if (answer == null) return;
      final option = answer.option;
      outcome = option == null
          ? await controller.save(resolveUnknown: true)
          : await controller.save(asOf: option.asOf);
    }
    if (!mounted) return;
    switch (outcome) {
      case SaveDone(:final change, :final ticket):
        final commands = ref.read(recordCommandsProvider);
        if (ticket.completed) await showCompleteCard(context, ticket);
        if (!mounted) return;
        showRideTicket(
          context,
          ticket,
          onUndo: () => commands.undo(change),
        );
        if (widget.returnBack) {
          router.pop();
        } else {
          router.go('/record');
        }
      case SaveUnridable():
        await showUnridable(context, t.session.unridableSave);
      case SaveFailed():
        messenger.showSnackBar(SnackBar(content: Text(t.session.noPath)));
      default:
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final t = context.t.session;
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    final preview = state.preview;
    final from = state.from;
    final to = state.to;
    final title = switch ((from, to, preview)) {
      // 임시 운행만 있는 계통에서 운행일이 아닌 날이면 운행일부터 고르게 한다 (사용자 결정 2026-11-19)
      (null, _, _) when state.isTemporary && !state.rows.any((row) => row.selectable) => t.tempPickDay,
      (null, _, _) => t.pickFrom,
      (final start?, null, _) => t.leaving(name: state.nameOf(start.node)),
      (_?, _?, Expansion(saved: true, meters: final meters?)) => t.summary(
          from: state.nameOf(from!.node),
          to: state.nameOf(to!.node),
          km: kmLabelOf(meters * (state.isLap ? state.laps : 1), estimated: state.kmEstimated),
        ),
      (_?, _?, Expansion(status: ResolveStatus.needsInput)) =>
        '${state.nameOf(from!.node)} → ${state.nameOf(to!.node)}',
      _ => t.noPath,
    };
    final ride = state.ridePreview;
    final before = ride?.before;
    final after = ride?.after;
    final detail = ride == null
        ? null
        : [
            t.stops(n: state.pickedStops),
            if (ride.newMeters > 0)
              t.fresh(km: kmLabel(ride.newMeters))
            else if (ride.counted)
              t.noFresh,
            if (before != null && after != null && ride.newMeters > 0)
              t.change(before: percentLabel(before), after: percentLabel(after)),
          ].join(' · ');
    final unsure = state.rows.any((row) => row.state == StopState.maybe && state.isPicked(row.seq));
    final ready = preview != null &&
        (preview.saved || preview.status == ResolveStatus.needsInput);
    final ways = state.ways;
    final way = state.direction ?? preview?.direction;
    final controller = ref.read(recordSessionProvider.notifier);
    return Container(
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
            children: [
              if (ways != null)
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    FilterPill(
                      label: t.directionKm(km: kmLabel(ways.up)),
                      selected: way == seqUp,
                      onTap: () => controller.setDirection(seqUp),
                    ),
                    FilterPill(
                      label: t.directionKm(km: kmLabel(ways.down)),
                      selected: way == seqDown,
                      onTap: () => controller.setDirection(seqDown),
                    ),
                  ],
                ),
              if (state.isLap) LapCounter(laps: state.laps, onChanged: controller.setLaps),
              SummaryActions(
                summary: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title, style: text.labelLarge),
                        if (from != null && to == null) Text(t.pickTo, style: text.bodySmall),
                        if (state.split.isNotEmpty)
                          Text(
                            [
                              for (final part in state.split)
                                '${ref.read(nameBookProvider).lines[part.lineId] ?? part.lineId} ${kmLabel(part.meters)} km',
                            ].join(' · '),
                            style: text.bodySmall,
                          ),
                        if (detail != null) Text(detail, style: text.bodySmall),
                        if (to != null) Text(t.repick, style: text.bodySmall),
                        if (unsure) Text(t.maybeHint, style: text.bodySmall),
                      ],
                    ),
                actions: [
                  if (from != null)
                    TextButton(onPressed: controller.clearPicks, child: Text(t.cancel)),
                  FilledButton(
                    onPressed: ready && !writing ? () => guarded(_save, failed: t.saveFailed) : null,
                    child: Text(t.save),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 한 바퀴 기록의 바퀴 수. 하나 아래로는 줄지 않는다.
class LapCounter extends StatelessWidget {
  const LapCounter({super.key, required this.laps, required this.onChanged});

  final int laps;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.t.session;
    return Row(
      children: [
        Text(t.laps(n: laps), style: Theme.of(context).textTheme.labelLarge),
        IconButton(
          tooltip: t.lapLess,
          icon: const Icon(Icons.remove),
          onPressed: laps > 1 ? () => onChanged(laps - 1) : null,
        ),
        IconButton(
          tooltip: t.lapMore,
          icon: const Icon(Icons.add),
          onPressed: () => onChanged(laps + 1),
        ),
      ],
    );
  }
}

/// 그 길을 쓴 기간. 가장 이른 길은 기록 하한 전부터라 끝만 적는다 (`~1968.8.5`, `1968.8.5~`).
String relocationSpan(List<RelocationOption> options, RelocationOption option) {
  final first = options.every((other) => option.asOf.compareTo(other.asOf) <= 0);
  final from = first ? '' : handDate(option.asOf);
  final to = option.until == null ? '' : handDate(option.until!);
  return '$from~$to';
}

/// 이설이 한 번이면 옛 선로와 새 선로로, 더 많으면 시점으로 적는다 (DESIGN §2.8).
String relocationLabel(BuildContext context, List<RelocationOption> options, RelocationOption option) {
  final t = context.t.session;
  final km = kmLabel(option.meters);
  if (options.length != 2) return t.relocationOption(date: option.asOf, km: km);
  final isOld = option.asOf.compareTo(options.first.asOf == option.asOf ? options.last.asOf : options.first.asOf) < 0;
  return isOld ? t.relocationOld(km: km) : t.relocationNew(km: km);
}
