import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/session_providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/load_error.dart';
import '../../../app/widgets/meter.dart';
import '../../../app/widgets/pills.dart';
import '../../../i18n/strings.g.dart';
import '../controller/browse_controller.dart';
import '../controller/record_session_controller.dart';
import 'line_tile.dart';
import 'progress_tile.dart';

String _categoryName(BuildContext context, String category) {
  final t = context.t.record.category;
  return switch (category) {
    'jr' => t.jr,
    'major_private' => t.majorPrivate,
    'semi_major_private' => t.semiMajorPrivate,
    'public' => t.public,
    'general_private' => t.generalPrivate,
    'monorail' => t.monorail,
    'agt' => t.agt,
    'cable' => t.cable,
    _ => category,
  };
}

/// 트리가 준비된 뒤에만 그린다.
class _TreeBuilder extends ConsumerWidget {
  const _TreeBuilder({required this.era, required this.builder});

  final BrowseEra era;
  final Widget Function(BuildContext context, BrowseTree tree) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) => switch (ref.watch(
    browseTreeProvider(era),
  )) {
    AsyncValue(hasValue: true, value: final tree?) => builder(context, tree),
    AsyncValue(hasError: true, :final error) => LoadError(error),
    _ => const Center(child: CircularProgressIndicator()),
  };
}

/// 요약 카드와 분류. 현행/폐선은 카드 안에서 고른다.
class LineBrowseView extends ConsumerWidget {
  const LineBrowseView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final era = ref.watch(browseEraProvider);
    return _TreeBuilder(
      era: era,
      builder: (context, tree) => ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
            child: _SummaryCard(tree: tree),
          ),
          for (final item in tree.categories)
            ProgressTile(
              title: _categoryName(context, item.category),
              score: item.score,
              onTap: () =>
                  context.go('/record/browse/${era.name}/${item.category}'),
            ),
        ],
      ),
    );
  }
}

class _SummaryCard extends ConsumerWidget {
  const _SummaryCard({required this.tree});

  final BrowseTree tree;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t.record;
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    final total = tree.total;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(
        color: tokens.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tree.era == BrowseEra.current
                      ? t.currentLabel
                      : t.closedLabel,
                  style: text.labelMedium,
                ),
              ),
              PillToggle<BrowseEra>(
                values: BrowseEra.values,
                label: (era) =>
                    era == BrowseEra.current ? t.era.current : t.era.closed,
                selected: tree.era,
                onChanged: ref.read(browseEraProvider.notifier).set,
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: 6,
            children: [
              // 큰 글자와 좁은 화면에서는 숫자를 줄여 % 자리를 지킨다
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    spacing: 6,
                    children: [
                      Text(kmLabel(total.numMeters), style: text.displaySmall),
                      Text(
                        'km',
                        style: text.titleMedium?.copyWith(color: tokens.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
              Text(percentLabel(total), style: text.titleLarge),
            ],
          ),
          Meter(ratio: total.ratio, height: 8),
          Wrap(
            spacing: 14,
            children: [
              Text(
                t.of(km: kmLabel(total.denMeters)),
                style: text.bodySmall,
              ),
              Text(
                t.lineCount(num: tree.startedLineCount, den: tree.lineCount),
                style: text.bodySmall,
              ),
              Text(
                t.completeCount(num: tree.completeLineCount),
                style: text.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 한 분류의 회사들.
class OperatorListScreen extends ConsumerWidget {
  const OperatorListScreen({
    super.key,
    required this.era,
    required this.category,
  });

  final BrowseEra era;
  final String category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = ref.watch(nameBookProvider).operators;
    return Scaffold(
      appBar: AppBar(title: Text(_categoryName(context, category))),
      body: _TreeBuilder(
        era: era,
        builder: (context, tree) => ListView(
          children: [
            for (final item
                in tree.category(category)?.operators ??
                    const <BrowseOperator>[])
              ProgressTile(
                title: names[item.operatorId] ?? item.operatorId,
                score: item.score,
                onTap: () => context.go(
                  '/record/browse/${era.name}/$category/${item.operatorId}',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _LineFilter { all, riding, unridden, complete }

/// 한 회사의 노선들. 막대 대신 어디를 탔는지 보여 주는 위치 띠를 쓴다.
class LineListScreen extends ConsumerStatefulWidget {
  const LineListScreen({
    super.key,
    required this.era,
    required this.category,
    required this.operatorId,
  });

  final BrowseEra era;
  final String category;
  final String operatorId;

  @override
  ConsumerState<LineListScreen> createState() => _LineListScreenState();
}

class _LineListScreenState extends ConsumerState<LineListScreen> {
  _LineFilter _filter = _LineFilter.all;

  /// 세션이 뜨기 전의 연타가 화면을 두 장 쌓지 않게 막는다.
  bool _opening = false;

  bool _shows(LineRow row) {
    final score = row.line.score;
    return switch (_filter) {
      _LineFilter.all => true,
      _LineFilter.riding => score.started && !score.complete,
      _LineFilter.unridden => !score.started,
      _LineFilter.complete => score.complete,
    };
  }

  Future<void> _open(String lineId) async {
    if (_opening) return;
    _opening = true;
    try {
      await ref
          .read(recordSessionProvider.notifier)
          .open(lineId: lineId, dateUnknown: widget.era == BrowseEra.closed);
      if (mounted) await context.push('/record/session?back=1');
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final book = ref.watch(nameBookProvider);
    final t = context.t.record;
    final text = Theme.of(context).textTheme;
    final rows = ref.watch(
      lineRowsProvider((
        era: widget.era,
        category: widget.category,
        operatorId: widget.operatorId,
      )),
    );
    final tree = ref.watch(browseTreeProvider(widget.era)).value;
    BrowseOperator? operator;
    for (final item
        in tree?.category(widget.category)?.operators ??
            const <BrowseOperator>[]) {
      if (item.operatorId == widget.operatorId) operator = item;
    }
    final score = operator?.score;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(book.operators[widget.operatorId] ?? widget.operatorId),
            if (score != null)
              Text(
                t.lineSub(
                  era: widget.era == BrowseEra.current
                      ? t.era.current
                      : t.era.closed,
                  num: kmLabel(score.numMeters),
                  den: kmLabel(score.denMeters),
                  percent: percentLabel(score),
                ),
                style: text.bodySmall,
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          FilterPillRow(
            left: 24,
            pills: [
              for (final value in _LineFilter.values)
                FilterPill(
                  label: switch (value) {
                    _LineFilter.all => t.filter.all,
                    _LineFilter.riding => t.filter.riding,
                    _LineFilter.unridden => t.filter.unridden,
                    _LineFilter.complete => t.filter.complete,
                  },
                  selected: value == _filter,
                  onTap: () => setState(() => _filter = value),
                ),
            ],
          ),
          Expanded(
            child: switch (rows) {
              AsyncValue(hasValue: true, value: final list?) => () {
                final shown = list.where(_shows).toList();
                if (shown.isEmpty) return Center(child: Text(t.filterEmpty));
                return ListView.builder(
                  itemCount: shown.length,
                  itemBuilder: (context, index) {
                    final row = shown[index];
                    return LineTile(
                      row: row,
                      title: book.lines[row.line.lineId] ?? row.line.lineId,
                      onTap: () => _open(row.line.lineId),
                    );
                  },
                );
              }(),
              AsyncValue(hasError: true, :final error) => LoadError(error),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ],
      ),
    );
  }
}
