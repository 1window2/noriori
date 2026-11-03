import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/session_providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/pills.dart';
import '../../../i18n/strings.g.dart';

enum _Metric { distance, rides, fresh }

const _minSlots = 6;

/// 연도별 그래프. 막대를 누르면 그해 숫자로 바뀐다.
class YearsScreen extends ConsumerStatefulWidget {
  const YearsScreen({super.key});

  @override
  ConsumerState<YearsScreen> createState() => _YearsScreenState();
}

class _YearsScreenState extends ConsumerState<YearsScreen> {
  _Metric _metric = _Metric.distance;
  int? _picked;

  int _value(YearStat stat) => switch (_metric) {
        _Metric.distance => stat.km10 * 100,
        _Metric.rides => stat.rides,
        _Metric.fresh => stat.newMeters,
      };

  String _label(YearStat stat) => switch (_metric) {
        _Metric.rides => context.t.years.rides(n: stat.rides),
        _ => '${kmLabel(_value(stat))} km',
      };

  @override
  Widget build(BuildContext context) {
    final t = context.t.years;
    final text = Theme.of(context).textTheme;
    final network = ref.watch(networkProvider);
    final today = ref.watch(todayProvider);
    final rides = ref.watch(rideDaysProvider).value ?? const <RideDay>[];
    final edgeMeters = {for (final edge in network.edges.values) edge.n: edge.meters};
    final stats = yearlyStats(
      rides,
      edgeYears: ref.watch(riddenYearsProvider).value ?? const {},
      edgeMeters: edgeMeters,
      lastYear: int.parse(today.substring(0, 4)),
    );
    final shown = stats.length > 12 ? stats.sublist(stats.length - 12) : stats;
    final current = shown.isEmpty
        ? null
        : shown.firstWhere((stat) => stat.year == _picked, orElse: () => shown.last);
    final top = shown.isEmpty ? 1 : shown.map(_value).reduce((a, b) => a > b ? a : b);
    final busiest = stats.isEmpty ? null : stats.reduce((a, b) => b.km10 > a.km10 ? b : a);
    return Scaffold(
      appBar: AppBar(title: Text(t.title)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          FilterPillRow(
            pills: [
              for (final (metric, label) in [
                (_Metric.distance, t.distance),
                (_Metric.rides, t.count),
                (_Metric.fresh, t.fresh),
              ])
                FilterPill(
                  label: label,
                  selected: _metric == metric,
                  onTap: () => setState(() => _metric = metric),
                ),
            ],
          ),
          if (current == null)
            Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(t.empty)))
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_label(current), style: text.headlineMedium),
                  Text(context.t.stats.yearLabel(year: current.year), style: text.bodySmall),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 180,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      spacing: 6,
                      children: [
                        // 해가 적어도 막대 하나가 화면을 다 차지하지 않게 칸 수를 지킨다
                        for (var slot = shown.length; slot < _minSlots; slot++) const Spacer(),
                        for (final stat in shown)
                          Expanded(
                            child: _Bar(
                              stat: stat,
                              ratio: top == 0 ? 0 : _value(stat) / top,
                              selected: stat.year == current.year,
                              onTap: () => setState(() => _picked = stat.year),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (busiest != null)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                title: Text(t.busiest),
                trailing: Text(context.t.stats.yearLabel(year: busiest.year)),
              ),
          ],
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: Text(t.undated),
            subtitle: Text(t.undatedHint),
            trailing: Text(t.rides(n: undatedRides(rides))),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.stat, required this.ratio, required this.selected, required this.onTap});

  final YearStat stat;
  final double ratio;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        spacing: 4,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: ratio == 0 ? 0 : ratio.clamp(0.02, 1),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: selected ? tokens.lineRidden : tokens.lineRiddenSoft,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
          Text('${stat.year % 100}'.padLeft(2, '0'), style: text.labelSmall?.copyWith(color: tokens.textMuted)),
        ],
      ),
    );
  }
}
