import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/date_text.dart';
import '../../../app/session_providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/pills.dart';
import '../../../i18n/strings.g.dart';

/// 활동 캘린더. 세로가 요일, 가로가 주다. 옆으로 넘겨 한 해를 보고, 칸을 누르면 그날 기록이 아래에 나온다.
class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  int? _year;
  String? _day;

  @override
  Widget build(BuildContext context) {
    final t = context.t.years;
    final text = Theme.of(context).textTheme;
    final today = ref.watch(todayProvider);
    final thisYear = int.parse(today.substring(0, 4));
    final rides = ref.watch(rideDaysProvider).value ?? const <RideDay>[];
    final years = {
      for (final ride in rides)
        if (ride.exact) int.parse(ride.date!.substring(0, 4)),
      thisYear,
    }.toList()
      ..sort((a, b) => b.compareTo(a));
    final year = _year ?? years.first;
    final days = dailyActivity(rides, year);
    final latest = days.isEmpty ? null : days.keys.reduce((a, b) => a.compareTo(b) > 0 ? a : b);
    final picked = _day ?? latest;
    final detail = picked == null ? null : days[picked];
    final summaries = ref.watch(rideSummariesProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text(t.activity)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          FilterPillRow(
            pills: [
              for (final item in years)
                FilterPill(
                  label: context.t.stats.yearLabel(year: item),
                  selected: item == year,
                  onTap: () => setState(() {
                    _year = item;
                    _day = null;
                  }),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _YearGrid(
              key: ValueKey(year),
              year: year,
              days: days,
              picked: picked,
              focus: year == thisYear ? today : (latest ?? '$year-01-01'),
              onPick: (day) => setState(() => _day = day),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(t.activityHint, style: text.bodySmall),
          ),
          if (picked != null) ...[
            const SizedBox(height: 8),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              title: Text(dateText(context.t, picked)),
              trailing: Text(
                detail == null ? t.noRides : '${t.rides(n: detail.rides)} · ${kmLabel(detail.km10 * 100)} km',
              ),
            ),
            for (final ride in summaries)
              if (ride.onExactDay && ride.date == picked)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  title: Text('${ride.fromLabel} → ${ride.toLabel}'),
                  subtitle: Text(ride.lineLabel),
                  trailing: ride.km10 == null ? null : Text('${kmLabel(ride.km10! * 100)} km'),
                  onTap: () => context.push('/record/${ride.rideId.value}'),
                ),
          ],
        ],
      ),
    );
  }
}

class _YearGrid extends StatefulWidget {
  const _YearGrid({
    super.key,
    required this.year,
    required this.days,
    required this.picked,
    required this.focus,
    required this.onPick,
  });

  final int year;
  final Map<String, DayActivity> days;
  final String? picked;

  /// 처음 보이는 날. 그 주가 오른쪽 끝에 온다.
  final String focus;
  final ValueChanged<String> onPick;

  @override
  State<_YearGrid> createState() => _YearGridState();
}

class _YearGridState extends State<_YearGrid> {
  static const _shownWeeks = 13;
  static const _gap = 3.0;
  static const _labelHeight = 18.0;

  ScrollController? _scroll;

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  String _key(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final t = context.t;
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(color: tokens.textMuted);
    Color shade(int level) => switch (level) {
          1 => tokens.lineRiddenSoft,
          2 => tokens.lineRidden.withValues(alpha: 0.6),
          3 => tokens.lineRidden,
          _ => tokens.track,
        };
    final first = DateTime.utc(widget.year);
    final count = DateTime.utc(widget.year + 1).difference(first).inDays;
    final lead = first.weekday % 7;
    int week(int offset) => (lead + offset) ~/ 7;
    final weeks = week(count - 1) + 1;
    return LayoutBuilder(
      builder: (context, box) {
        final cell = (box.maxWidth - _gap * (_shownWeeks - 1)) / _shownWeeks;
        final step = cell + _gap;
        final width = weeks * step - _gap;
        final focus = DateTime.parse('${widget.focus}T00:00:00Z').difference(first).inDays;
        final start = (week(focus) + 1) * step - _gap - box.maxWidth;
        final scroll = _scroll ??= ScrollController(
          initialScrollOffset: start.clamp(0, width - box.maxWidth).toDouble(),
        );
        return SingleChildScrollView(
          controller: scroll,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            height: _labelHeight + 7 * step - _gap,
            child: Stack(
              children: [
                for (var month = 1; month <= 12; month++)
                  Positioned(
                    top: 0,
                    left: week(DateTime.utc(widget.year, month).difference(first).inDays) * step,
                    child: Text(t.date.months[month - 1], style: labelStyle),
                  ),
                for (var offset = 0; offset < count; offset++)
                  Positioned(
                    top: _labelHeight + (lead + offset) % 7 * step,
                    left: week(offset) * step,
                    width: cell,
                    height: cell,
                    child: _Day(
                      key: ValueKey('day-${_key(first.add(Duration(days: offset)))}'),
                      color: shade(activityLevel(widget.days[_key(first.add(Duration(days: offset)))])),
                      picked: _key(first.add(Duration(days: offset))) == widget.picked,
                      onTap: () => widget.onPick(_key(first.add(Duration(days: offset)))),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Day extends StatelessWidget {
  const _Day({super.key, required this.color, required this.picked, required this.onTap});

  final Color color;
  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: picked ? Border.all(color: context.tokens.text, width: 1.5) : null,
          ),
        ),
      );
}
