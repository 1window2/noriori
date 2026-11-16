import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/session_providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/load_error.dart';
import '../../../app/widgets/pills.dart';
import '../../../i18n/strings.g.dart';

enum _Group { lines, operators, prefs, stations, closed }

/// 수집. 완주한 것과 타는 중인 것을 칸으로 보여 준다 (DESIGN §3.3).
class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key});

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  _Group _group = _Group.lines;

  @override
  Widget build(BuildContext context) {
    final t = context.t.collection;
    final network = ref.watch(networkProvider);
    final book = ref.watch(nameBookProvider);
    final current = ref.watch(scoreTableProvider(const BasisCurrent())).value;
    if (current == null) return Scaffold(appBar: AppBar(title: Text(t.title)));
    final prefs = ref.watch(prefScoresProvider(const BasisCurrent()));
    // 배지는 현행 완주만이고 한 번 얻으면 남는다 (DESIGN §3.3)
    final held = ref.watch(heldBadgesProvider).value ?? const <String>{};
    final nodes = ref.watch(riddenNodesProvider).value ?? const <String>{};
    final stations = {for (final node in nodes) network.data.nodeGroups[node] ?? node}.length;
    final cells = switch (_group) {
      _Group.lines => [
          for (final item in collectionItems(current.byLine, held: {for (final key in current.byLine.keys) if (held.contains(lineBadge(key))) key}))
            _Cell(
              name: book.lines[item.key] ?? item.key,
              score: item.score,
              complete: item.complete,
              onTap: () => context.push('/line/${item.key}'),
            ),
        ],
      _Group.operators => [
          for (final item in collectionItems(current.byOperator, held: {for (final key in current.byOperator.keys) if (held.contains(operatorBadge(key))) key}))
            _Cell(name: book.operators[item.key] ?? item.key, score: item.score, complete: item.complete),
        ],
      _Group.prefs => [
          for (final item in collectionItems(prefs, held: {for (final key in prefs.keys) if (held.contains(prefBadge(key))) key}))
            _Cell(name: context.t.prefNames[item.key - 1], score: item.score, complete: item.complete),
        ],
      _Group.closed => const <Widget>[],
      _Group.stations => [
          for (final goal in stationMilestones)
            _Cell(
              name: t.stationGoal(n: countLabel(goal)),
              score: Score(
                numMeters: stations.clamp(0, goal),
                denMeters: goal,
                numUnits: stations.clamp(0, goal),
                denUnits: goal,
              ),
            ),
        ],
    };
    return Scaffold(
      appBar: AppBar(title: Text(t.title)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilterPillRow(
            pills: [
              for (final (group, label) in [
                (_Group.lines, t.lines),
                (_Group.operators, t.operators),
                (_Group.prefs, t.prefs),
                (_Group.stations, t.stations),
                (_Group.closed, t.closed),
              ])
                FilterPill(
                  label: label,
                  selected: _group == group,
                  onTap: () => setState(() => _group = group),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _group == _Group.closed
                ? const _ClosedList()
                : cells.isEmpty
                ? Center(child: Text(t.empty))
                : GridView.count(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: cells,
                  ),
          ),
        ],
      ),
    );
  }
}

/// 탔고 지금은 없어진 구간. 폐지일이 늦은 것부터 보여 준다.
final _closedProvider = FutureProvider.autoDispose<(List<ClosedRide>, Map<String, String>)>((ref) async {
  final network = ref.watch(networkProvider);
  final hits = await ref.watch(unitHitsProvider.future);
  final today = ref.watch(todayProvider);
  final carryover = ref.watch(carryoverProvider);
  final table = scoreTable(network, hits: hits, basis: const BasisAllTime(), carryover: carryover, today: today);
  final lastYears = await ref.watch(recordQueriesProvider).lastRideYears(carryover: carryover);
  final rides = closedRides(
    network,
    lines: startedLines(table),
    hits: hits,
    today: today,
    lastYears: lastYears,
    carryover: carryover,
  );
  final names = await ref.watch(packReaderProvider).nodeNames({
    for (final ride in rides) ...[ride.from, ride.to],
  });
  return (rides, names);
});

class _ClosedList extends ConsumerWidget {
  const _ClosedList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t.collection;
    final book = ref.watch(nameBookProvider);
    final network = ref.watch(networkProvider);
    final text = Theme.of(context).textTheme;
    return switch (ref.watch(_closedProvider)) {
      AsyncValue(hasValue: true, value: (final rides, _)?) when rides.isEmpty =>
        Center(child: Padding(padding: const EdgeInsets.all(32), child: Text(t.closedEmpty, textAlign: TextAlign.center))),
      AsyncValue(hasValue: true, value: (final rides, final names)?) => ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                t.closedTotal(
                  n: rides.length,
                  km: kmLabel(rides.fold(0, (sum, ride) => sum + ride.meters)),
                ),
                style: text.bodySmall,
              ),
            ),
            for (final ride in rides)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                title: Text(book.lines[ride.lineId] ?? ride.lineId),
                subtitle: Text(
                  [
                    '${names[ride.from] ?? ride.from} – ${names[ride.to] ?? ride.to}',
                    if (ride.closeYear case final year?) t.closedYear(year: year),
                    if (ride.yearsBefore case final years? when years > 0) t.closedAfter(n: years),
                  ].join(' · '),
                ),
                trailing: Text(
                  network.kmEstimatedBetween(ride.lineId, ride.from, ride.to) ? '? km' : '${kmLabel(ride.meters)} km',
                ),
                onTap: () => context.push('/line/${ride.lineId}'),
              ),
          ],
        ),
      AsyncValue(hasError: true, :final error) => LoadError(error),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.name, required this.score, this.complete, this.onTap});

  final String name;
  final Score score;

  /// 배지를 지녔는가. 정하지 않으면 지금 완주했는지로 본다
  final bool? complete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    final done = complete ?? score.complete;
    return Material(
      color: tokens.paper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: done ? tokens.lineRidden : tokens.hairline, width: done ? 1.5 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 4,
            children: [
              Flexible(
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(fontWeight: done ? FontWeight.w700 : FontWeight.w500),
                ),
              ),
              if (!done)
                Text(percentLabel(score), style: text.labelSmall?.copyWith(color: tokens.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}
