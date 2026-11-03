import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/session_providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/line_strip_bar.dart';
import '../../../app/widgets/load_error.dart';
import '../../../app/widgets/meter.dart';
import '../../../app/widgets/pills.dart';
import '../../../i18n/strings.g.dart';
import 'pref_tile_map.dart';

final _basisProvider = NotifierProvider<_Basis, ScoreBasis>(_Basis.new);

final class _Basis extends Notifier<ScoreBasis> {
  @override
  ScoreBasis build() => const BasisCurrent();

  void set(ScoreBasis value) => state = value;
}

enum _Kind { current, allTime, year }

/// 큰 숫자 하나, 숫자 카드 넷, 그리고 다음 목표. 판정은 core 하나다.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  Future<void> _pickYear(BuildContext context, WidgetRef ref, String today) async {
    final last = int.parse(today.substring(0, 4));
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Text(context.t.stats.yearPick, style: Theme.of(context).textTheme.titleLarge),
            ),
            for (var year = last; year >= 1970; year--)
              ListTile(
                title: Text(context.t.stats.yearLabel(year: year)),
                onTap: () => Navigator.pop(context, year),
              ),
          ],
        ),
      ),
    );
    if (picked != null) ref.read(_basisProvider.notifier).set(BasisYear(picked));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final basis = ref.watch(_basisProvider);
    final table = ref.watch(scoreTableProvider(basis));
    final t = context.t.stats;
    final text = Theme.of(context).textTheme;
    final today = ref.watch(todayProvider);
    final kind = switch (basis) {
      BasisCurrent() => _Kind.current,
      BasisAllTime() => _Kind.allTime,
      BasisYear() => _Kind.year,
    };
    final yearName = switch (basis) {
      BasisYear(:final year) => '$year',
      _ => t.year,
    };
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 2),
            child: Row(
              children: [
                Expanded(child: Text(t.title, style: text.headlineMedium)),
                PillToggle<_Kind>(
                  values: _Kind.values,
                  label: (value) => switch (value) {
                    _Kind.current => t.current,
                    _Kind.allTime => t.allTime,
                    _Kind.year => yearName,
                  },
                  selected: kind,
                  onChanged: (value) => switch (value) {
                    _Kind.current => ref.read(_basisProvider.notifier).set(const BasisCurrent()),
                    _Kind.allTime => ref.read(_basisProvider.notifier).set(const BasisAllTime()),
                    _Kind.year => _pickYear(context, ref, today),
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: switch (table) {
              AsyncValue(hasValue: true, value: final data?) => _Body(data: data, basis: basis),
              AsyncValue(hasError: true, :final error) => LoadError(error),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ],
      ),
    );
  }
}

/// 통계 안의 입구. 탭을 늘리지 않으려고 둔다.
class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(child: Text(label, style: text.titleSmall)),
            Text(value, style: text.bodySmall),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.data, required this.basis});

  final ScoreTable data;
  final ScoreBasis basis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t.stats;
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    final network = ref.watch(networkProvider);
    final book = ref.watch(nameBookProvider);
    final today = ref.watch(todayProvider);
    final hits = ref.watch(unitHitsProvider).value ?? const <int, String?>{};
    final nodes = ref.watch(riddenNodesProvider).value ?? const <String>{};
    final total = data.total;
    final percent = percentLabel(total);
    // 방문 역 수는 역 방문과 승하차역의 합이다. 완주율과 별도 지표다 (DESIGN §5.2)
    final stepped = ref.watch(stationMarksProvider).stepped;
    final visited = stepped.length;
    final visitedClosed = stepped.difference(network.openGroups).length;
    final stations = {for (final node in nodes) network.data.nodeGroups[node] ?? node}.length;
    final month = newMetersSince(
      network,
      hits: hits,
      since: '${today.substring(0, 7)}-01',
      today: today,
      undated: ref.watch(undatedUnitsProvider).value ?? const {},
      carryover: ref.watch(carryoverProvider),
    );
    final tree = ref.watch(browseTreeProvider(BrowseEra.current)).value;
    final nearly = basis is BasisCurrent ? tree?.nearlyComplete() ?? const <BrowseLine>[] : const <BrowseLine>[];
    final startedLines = data.byLine.values.where((s) => s.started).length;
    final completeLines = data.byLine.values.where((s) => s.complete).length;
    final startedOperators = data.byOperator.values.where((s) => s.started).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            // `<0.01%`은 통째로 쓴다
            if (!percent.startsWith('<')) ...[
              Text(percent.substring(0, percent.length - 1), style: text.displayMedium),
              const SizedBox(width: 4),
              Text('%', style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w500, color: tokens.textMuted)),
            ] else
              Text(percent, style: text.headlineMedium),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          [
            t.rodeOf(num: kmLabel(total.numMeters), den: kmLabel(total.denMeters)),
            if (month > 0) t.month(km: kmLabel(month)),
          ].join(' · '),
          style: text.bodySmall?.copyWith(fontSize: 13),
        ),
        if (ref.watch(reviewProvider).value case final review? when review.rides > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(t.review(n: review.rides, km: kmLabel(review.meters)), style: text.bodySmall),
          ),
        const SizedBox(height: 8),
        Meter(ratio: total.ratio, height: 8),
        const SizedBox(height: 16),
        Row(
          spacing: 8,
          children: [
            _Kpi(value: '$startedLines', label: t.kpi.lines),
            _Kpi(value: '$completeLines', label: t.kpi.complete),
            _Kpi(value: '$stations', label: t.kpi.stations),
            _Kpi(value: '$startedOperators', label: t.kpi.operators),
          ],
        ),
        if (ref.watch(totalKm10Provider).value case final km10? when km10 > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(t.totalRidden(km: kmLabel(km10 * 100)), style: text.bodySmall),
          ),
        if (visited > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              [
                t.visited(n: visited),
                if (visitedClosed > 0) t.visitedClosed(n: visitedClosed),
              ].join(' · '),
              style: text.bodySmall,
            ),
          ),
        // 폐선만 탔어도 기록은 있다. 수집과 연도별로 가는 입구를 숨기지 않는다
        if (hits.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: Text(t.empty))),
        if (hits.isNotEmpty && basis is BasisCurrent) ...[
          const SizedBox(height: 12),
          _EntryRow(
            label: context.t.remaining.title,
            value: context.t.remaining.entry,
            onTap: () => context.push('/stats/remaining'),
          ),
          _EntryRow(
            label: context.t.collection.title,
            value: t.badges(
              n: badgeCount(
                lines: data.byLine.values,
                operators: data.byOperator.values,
                prefs: ref.watch(prefScoresProvider(basis)).values,
                stations: stations,
              ),
            ),
            onTap: () => context.push('/stats/collection'),
          ),
          _EntryRow(
            label: context.t.years.title,
            value: '',
            onTap: () => context.push('/stats/years'),
          ),
          _EntryRow(
            label: context.t.years.activity,
            value: '',
            onTap: () => context.push('/stats/activity'),
          ),
        ],
        if (visited > 0)
          _EntryRow(
            label: context.t.visits.title,
            value: context.t.visits.count(n: visited),
            onTap: () => context.push('/stats/visits'),
          ),
        if (nearly.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(t.nearly, style: text.titleSmall),
          const SizedBox(height: 8),
          for (final line in nearly)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 3,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          book.lines[line.lineId] ?? line.lineId,
                          style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        t.left(km: kmLabel(line.score.remainingMeters)),
                        style: text.labelMedium,
                      ),
                    ],
                  ),
                  LineStripBar(strip: lineStrip(network, line)),
                ],
              ),
            ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: Text(t.prefs, style: text.titleSmall)),
            Text(t.prefHint, style: text.labelSmall),
          ],
        ),
        const SizedBox(height: 10),
        PrefTileMap(scores: ref.watch(prefScoresProvider(basis))),
        const SizedBox(height: 12),
        _Section(title: t.operators, scores: data.byOperator, names: book.operators),
        _Section(
          title: t.lines,
          scores: data.byLine,
          names: book.lines,
          onRow: (id) => context.push('/line/$id'),
        ),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
        decoration: BoxDecoration(
          color: tokens.paper,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tokens.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: text.titleLarge?.copyWith(fontSize: 19)),
            Text(label, style: text.labelSmall?.copyWith(color: tokens.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.scores, required this.names, this.onRow});

  final String title;
  final Map<String, Score> scores;
  final Map<String, String> names;
  final ValueChanged<String>? onRow;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final MapEntry(:key, :value) in scores.entries)
        if (value.numUnits > 0) (id: key, score: value),
    ]..sort((a, b) => b.score.numMeters.compareTo(a.score.numMeters));
    if (rows.isEmpty) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(title, style: text.titleSmall),
        const SizedBox(height: 4),
        for (final row in rows)
          InkWell(
            onTap: onRow == null ? null : () => onRow!(row.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 5,
                children: [
                  Row(
                    spacing: 8,
                    children: [
                      Expanded(
                        child: Text(
                          names[row.id] ?? row.id,
                          style: text.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${kmLabel(row.score.numMeters)} km',
                        style: text.bodySmall?.copyWith(fontFeatures: tabularFigures),
                      ),
                      Text(
                        percentLabel(row.score),
                        style: text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: tokens.text,
                          fontFeatures: tabularFigures,
                        ),
                      ),
                    ],
                  ),
                  Meter(ratio: row.score.ratio),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
