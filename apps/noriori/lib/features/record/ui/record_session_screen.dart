import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/date_text.dart';
import '../../../app/session_providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/pills.dart';
import '../../../i18n/strings.g.dart';
import '../controller/record_session_controller.dart';
import 'session_date.dart';
import 'session_lines.dart';
import 'session_save_bar.dart';

/// 역 선택기 (DESIGN §8, §8.1). 세로 노선도 한 줄에서 두 번 탭한다.
class RecordSessionScreen extends ConsumerStatefulWidget {
  const RecordSessionScreen({super.key, this.returnBack = false});

  /// 저장하면 온 목록으로 돌아간다. 이어서 다른 노선을 기록하기 좋다.
  final bool returnBack;

  @override
  ConsumerState<RecordSessionScreen> createState() => _RecordSessionScreenState();
}

class _RecordSessionScreenState extends ConsumerState<RecordSessionScreen> {
  /// 역 찾기. null이면 찾고 있지 않다.
  String? _query;

  /// 지금 언어의 이름과 일본어 이름 어느 쪽으로도 찾는다.
  bool _matches(RecordSessionState state, String node, String query) {
    final want = query.toLowerCase();
    return state.nameOf(node).toLowerCase().contains(want) || (state.japanese[node] ?? '').contains(want);
  }
  final _lines = ScrollController();
  final _focusKey = GlobalKey();
  int? _focusLine;
  int _lastBuilt = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(recordSessionProvider);
      if (state.focus != null) _reveal(state.focus!);
    });
  }

  /// 고른 역까지 옮긴다. 줄 높이가 제각각이라 그릴 때까지 다가간다.
  Future<void> _reveal(int seq) async {
    final lines = ref.read(recordSessionProvider).lines;
    final target = lines.indexWhere((line) => line is StopLine && line.row.seq == seq);
    if (target < 0) return;
    setState(() => _focusLine = target);
    for (var step = 0; step < 12; step++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !_lines.hasClients) return;
      final found = _focusKey.currentContext;
      if (found != null) {
        await Scrollable.ensureVisible(found, alignment: 0.3);
        return;
      }
      final jump = (target - _lastBuilt) * 56.0;
      _lines.jumpTo((_lines.offset + jump).clamp(0.0, _lines.position.maxScrollExtent));
    }
  }

  @override
  void dispose() {
    _lines.dispose();
    super.dispose();
  }

  String _routeLabel(String routeId) {
    final route = ref.read(networkProvider).routes[routeId]!;
    if (route.role == 'main') return context.t.session.main;
    return ref.read(nameBookProvider).routes[routeId] ?? routeId;
  }

  Future<void> _editDate(RecordSessionController controller, String? current) async {
    final result = await showDialog<DateAnswer>(
      context: context,
      builder: (context) => SessionDateDialog(current: current, today: ref.read(todayProvider)),
    );
    if (result == null) return;
    // 고른 구간을 그날 탈 수 없으면 날짜를 바꾸지 않고 경고한다 (DESIGN §8.0.1 탑승일)
    final refused = await controller.setDate(result.value);
    if (refused && mounted) await showUnridable(context, context.t.session.unridableDate);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(recordSessionProvider.select((s) => s.focus), (_, next) {
      if (next != null) _reveal(next);
    });
    final state = ref.watch(recordSessionProvider);
    final controller = ref.read(recordSessionProvider.notifier);
    final book = ref.watch(nameBookProvider);
    final network = ref.watch(networkProvider);
    final t = context.t.session;
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    final today = ref.watch(todayProvider);
    final choices = controller.routeChoices;
    final ridden = ref.watch(riddenEdgesProvider).value ?? const <int>{};
    final routeId = state.routeId;
    final gaps = routeId == null
        ? const <bool>[]
        : SelectorBuilder(network).riddenBetween(routeId, state.visible, ridden);
    final raw = state.dateInput;
    // 기준일보다 이른 날짜는 입력해도 날짜 모름이다. 칩이 바로 그렇게 보여 준다 (DESIGN §4.6)
    final known = raw != null && normalizeRideDate(DateSpan.parse(raw)) != null;
    final dateChip = !known
        ? t.dateUnknown
        : (raw == today
              ? t.today
              : dateText(context.t, raw));
    // 범위 날짜는 그날 있었는지 모르는 역이 생긴다. 칩이 먼저 알린다 (DESIGN §5.4)
    final unsure = known && state.rows.any((row) => row.state == StopState.maybe);
    final shownLine = controller.shownLine;
    final day = raw == null ? today : DateSpan.parse(raw).lo;
    final (units, _) = lineUnits(network, shownLine, day, carryover: ref.watch(carryoverProvider));
    final lineMeters = units.fold(0, (sum, unit) => sum + unit.meters);
    final lineScore = ref.watch(scoreTableProvider(const BasisCurrent())).value?.byLine[shownLine];
    final stuck = state.rows.isNotEmpty && !state.rows.any((row) => row.selectable);
    final query = _query;
    final searching = query != null && query.isNotEmpty;
    final lines = searching
        ? [
            for (final line in state.lines)
              if (line is StopLine && _matches(state, line.row.node, query)) line,
          ]
        : state.lines;
    final trunk = TrunkStyle(state, gaps, tokens);
    return PopScope(
      // 분기로 넘어왔으면 뒤로 가기는 직전 노선이다
      canPop: state.depth == 0,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await confirmLeave(context, ref)) await controller.jumpBack();
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: query != null
              ? TextField(
                  autofocus: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(hintText: t.findStop, border: InputBorder.none),
                  onChanged: (value) => setState(() => _query = value),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book.lines[shownLine] ?? ''),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        t.meta(
                          operator: controller.operatorName,
                          km: lineScore == null || !lineScore.started
                              ? '${kmLabel(lineMeters)} km'
                              : t.progress(
                                  num: kmLabel(lineScore.numMeters),
                                  den: kmLabel(lineScore.denMeters),
                                  percent: percentLabel(lineScore),
                                ),
                        ),
                        style: text.bodySmall,
                      ),
                    ),
                  ],
                ),
          actions: [
            SessionDateChip(label: unsure ? '$dateChip ?' : dateChip, onTap: () => _editDate(controller, raw)),
            IconButton(
              tooltip: context.t.lineDetail.open,
              icon: const Icon(Icons.info_outline),
              onPressed: () => context.push('/line/$shownLine'),
            ),
            IconButton(
              tooltip: t.findStop,
              icon: Icon(query == null ? Icons.search : Icons.close),
              onPressed: () => setState(() => _query = query == null ? '' : null),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            const _DisplayBar(),
            if (choices.length > 1)
              FilterPillRow(
                pills: [
                  for (final choice in choices)
                    FilterPill(
                      label: _routeLabel(choice),
                      selected: choice == routeId,
                      onTap: () => controller.selectRoute(choice),
                    ),
                ],
              ),
            if (stuck)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: Text(t.nonePickable, style: text.bodySmall),
              ),
            Expanded(
              // 긴 노선은 손잡이를 끌어 이동한다. 도쿄에서 오사카까지 약 9,000dp다 (DESIGN §8 역 찾기)
              child: Scrollbar(
                controller: _lines,
                interactive: true,
                thumbVisibility: lines.length > 30,
                thickness: 8,
                radius: const Radius.circular(4),
                child: ListView.builder(
                  controller: _lines,
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: lines.length,
                  itemBuilder: (context, index) {
                    _lastBuilt = index;
                    return KeyedSubtree(
                      key: index == _focusLine ? _focusKey : null,
                      child: SessionLineTile(
                        line: lines[index],
                        next: index + 1 < lines.length ? lines[index + 1] : null,
                        trunk: trunk,
                      ),
                    );
                  },
                ),
              ),
            ),
            SessionSaveBar(state: state, returnBack: widget.returnBack),
          ],
        ),
      ),
    );
  }
}

/// 화면 맨 위의 표시 설정. 앱 설정의 값을 그대로 쓴다 (DESIGN §8).
class _DisplayBar extends ConsumerWidget {
  const _DisplayBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(displayOptionsProvider);
    final controller = ref.read(displayOptionsProvider.notifier);
    final t = context.t.session;
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    Widget check(String label, bool value, ValueChanged<bool>? change) => InkWell(
      onTap: change == null ? null : () => change(!value),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: value,
              onChanged: change == null ? null : (next) => change(next ?? false),
              visualDensity: VisualDensity.compact,
            ),
            Text(
              label,
              style: text.bodySmall?.copyWith(
                color: change == null ? tokens.textClosed : tokens.textMuted,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.hairline)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          children: [
            check(
              t.showClosed,
              options.showClosed,
              (value) => controller.update(showClosed: value),
            ),
            check(
              t.showArchive,
              options.showArchive,
              options.showClosed ? (value) => controller.update(showArchive: value) : null,
            ),
          ],
        ),
      ),
    );
  }
}
