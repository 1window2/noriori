import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/session_providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/widgets/guarded_write.dart';
import '../../../app/widgets/line_strip_bar.dart';
import '../../../app/widgets/meter.dart';
import '../../../app/widgets/pills.dart';
import '../../../i18n/strings.g.dart';
import '../controller/line_detail_controller.dart';
import '../controller/record_list_controller.dart';
import '../controller/record_session_controller.dart';
import 'line_stem.dart';
import 'session_lines.dart' show closedNote;

/// 노선 상세 (DESIGN §3.3, §8.2). 세로 노선도에서 그 자리에서 고친다.
class LineDetailScreen extends ConsumerStatefulWidget {
  const LineDetailScreen({super.key, required this.lineId});

  final String lineId;

  @override
  ConsumerState<LineDetailScreen> createState() => _LineDetailScreenState();
}

class _LineDetailScreenState extends ConsumerState<LineDetailScreen> with GuardedWrite {
  final _scroll = ScrollController();
  final _sectionKeys = <int, GlobalKey>{};
  String? _routeId;
  int? _dragFrom;
  int? _dragTo;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _say(String message, {Change? undo}) {
    final messenger = ScaffoldMessenger.of(context);
    final commands = ref.read(recordCommandsProvider);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
        persist: false,
        action: undo == null
            ? null
            : SnackBarAction(
                label: context.t.lineDetail.undo,
                onPressed: () => commands.undo(undo),
              ),
      ),
    );
  }

  void _report(SectionEdit edit) {
    if (!mounted) return;
    final t = context.t.lineDetail;
    switch (edit) {
      case SectionOff(:final change, :final rides):
        _say(t.turnedOff(n: rides), undo: change);
      case SectionOn(:final change, :final restored):
        _say(restored ? t.restored : t.turnedOn, undo: change);
      case SectionRefused(reason: CutBlock.hiddenNode):
        _say(t.blockedHidden);
      case SectionRefused(reason: CutBlock.changesPath):
        _say(t.blockedPath);
      case SectionRefused(reason: CutBlock.noStop):
        _say(t.blockedNoStop);
      case SectionRefused():
        _say(t.blockedOn);
      case SectionUntouched():
        break;
    }
  }

  Future<void> _toggle(List<DiagramSection> sections, {required bool off}) =>
      guarded(() => _write(sections, off: off), failed: context.t.session.saveFailed);

  Future<void> _write(List<DiagramSection> sections, {required bool off}) async {
    final commands = ref.read(sectionCommandsProvider);
    final targets = [
      for (final section in sections)
        if (section.editable && section.ridden == off) section,
    ];
    if (targets.isEmpty) return;
    _report(off ? await commands.turnOff(widget.lineId, targets) : await commands.turnOn(widget.lineId, targets));
  }

  Future<void> _toggleVisit(DiagramStop stop, String name) =>
      guarded(() => _writeVisit(stop, name), failed: context.t.session.saveFailed);

  Future<void> _writeVisit(DiagramStop stop, String name) async {
    final t = context.t.lineDetail;
    final commands = ref.read(recordCommandsProvider);
    final network = ref.read(networkProvider);
    bool same(String node) => network.sameStation(node, stop.node);
    final visits = [
      for (final visit in ref.read(visitsProvider).value ?? const <VisitSummary>[])
        if (same(visit.node)) visit,
    ];
    if (visits.isNotEmpty) {
      final change = await commands.deleteVisits(visits.map((v) => v.visitId));
      if (mounted) _say(t.visitRemoved, undo: change);
      return;
    }
    if ((ref.read(alightedNodesProvider).value ?? const {}).any(same)) {
      _say(t.visitByRide);
      return;
    }
    final change = await commands.addVisit(
      node: stop.node,
      label: name,
      deviceId: await ref.read(deviceIdProvider.future),
      id: uuidV7(millis: ref.read(nowProvider)(), randomBytes: secureRandomBytes()),
    );
    if (mounted) _say(t.visitAdded, undo: change);
  }

  Future<void> _record(String routeId) => guarded(() async {
        final router = GoRouter.of(context);
        await ref.read(recordSessionProvider.notifier).open(lineId: widget.lineId, routeId: routeId);
        unawaited(router.push('/record/session?back=1'));
      }, failed: context.t.session.saveFailed);

  /// 길게 눌러 끄는 동안 손가락 아래의 구간. 행 높이가 글자 크기를 따라가므로 실제 상자를 본다.
  int? _sectionAt(Offset global) {
    for (final MapEntry(:key, :value) in _sectionKeys.entries) {
      final box = value.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      if (global.dy >= top && global.dy < top + box.size.height) return key;
    }
    return null;
  }

  void _dragMoved(Offset global) {
    final at = _sectionAt(global);
    if (at != null && at != _dragTo) setState(() => _dragTo = at);
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !_scroll.hasClients) return;
    final y = box.globalToLocal(global).dy;
    const edge = 72.0;
    final step = y < edge ? -24.0 : (y > box.size.height - edge ? 24.0 : 0.0);
    if (step != 0) {
      _scroll.jumpTo((_scroll.offset + step).clamp(0.0, _scroll.position.maxScrollExtent));
    }
  }

  Future<void> _dragEnded(RouteDiagram route) async {
    final from = _dragFrom;
    final to = _dragTo ?? from;
    setState(() {
      _dragFrom = null;
      _dragTo = null;
    });
    if (from == null || to == null) return;
    final lo = from < to ? from : to;
    final hi = from < to ? to : from;
    await _toggle(route.sections.sublist(lo, hi + 1), off: route.sections[from].ridden);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.lineDetail;
    final book = ref.watch(nameBookProvider);
    final diagram = ref.watch(lineDiagramProvider(widget.lineId)).value;
    final names = ref.watch(lineStopNamesProvider(widget.lineId)).value ?? const {};
    final marks = ref.watch(stationMarksProvider);
    final network = ref.watch(networkProvider);
    final title = book.lines[widget.lineId] ?? widget.lineId;
    if (diagram == null || diagram.routes.isEmpty) {
      return Scaffold(appBar: AppBar(title: Text(title)));
    }
    final route = diagram.routes.firstWhere(
      (r) => r.routeId == _routeId,
      orElse: () => diagram.routes.first,
    );
    final lo = _dragFrom == null ? null : (_dragFrom! < (_dragTo ?? _dragFrom!) ? _dragFrom : _dragTo);
    final hi = _dragFrom == null ? null : (_dragFrom! < (_dragTo ?? _dragFrom!) ? _dragTo ?? _dragFrom : _dragFrom);
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: t.soloMap,
            icon: const Icon(Icons.map_outlined),
            onPressed: () {
              ref.read(soloLineIdProvider.notifier).set(widget.lineId);
              context.go('/map');
            },
          ),
          PopupMenuButton<void>(
            itemBuilder: (context) => [
              PopupMenuItem(
                onTap: () => _toggle(
                  [for (final r in diagram.routes) ...r.sections],
                  off: true,
                ),
                child: Text(t.clear),
              ),
            ],
          ),
        ],
      ),
      body: GestureDetector(
        onLongPressStart: (details) {
          final at = _sectionAt(details.globalPosition);
          if (at == null) return;
          setState(() {
            _dragFrom = at;
            _dragTo = at;
          });
        },
        onLongPressMoveUpdate: (details) => _dragMoved(details.globalPosition),
        onLongPressEnd: (_) => _dragEnded(route),
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverToBoxAdapter(
              child: _Header(
                lineId: widget.lineId,
                diagram: diagram,
                routeId: route.routeId,
                names: names,
                onRecord: () => _record(route.routeId),
                onRoute: (id) => setState(() => _routeId = id),
              ),
            ),
            SliverList.builder(
              itemCount: route.stops.length * 2 - 1,
              itemBuilder: (context, index) {
                final at = index ~/ 2;
                if (index.isOdd) {
                  final section = route.sections[at];
                  final starts = section.gone && (at == 0 || !route.sections[at - 1].gone);
                  return _SectionRow(
                    key: _sectionKeys[at] ??= GlobalKey(),
                    section: section,
                    closedYear: starts ? route.stops[at + 1].closeYear ?? '?' : null,
                    from: names[route.sections[at].from] ?? '',
                    to: names[route.sections[at].to] ?? '',
                    picked: lo != null && at >= lo && at <= hi!,
                    onTap: () => _toggle([route.sections[at]], off: route.sections[at].ridden),
                  );
                }
                final stop = route.stops[at];
                return _StopRow(
                  stop: stop,
                  above: at == 0 ? null : route.sections[at - 1],
                  below: at == route.sections.length ? null : route.sections[at],
                  name: names[stop.node] ?? '',
                  mark: marks.of(network, stop.node),
                  onNode: () => _toggleVisit(stop, names[stop.node] ?? stop.node),
                  onRoute: (id) => setState(() => _routeId = id),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

/// 맨 위의 큰 %와 현행·역대 두 줄, 가로 띠, 계통 칩.
class _Header extends ConsumerWidget {
  const _Header({
    required this.lineId,
    required this.diagram,
    required this.routeId,
    required this.names,
    required this.onRecord,
    required this.onRoute,
  });

  final String lineId;
  final LineDiagram diagram;
  final String routeId;
  final Map<String, String> names;
  final VoidCallback onRecord;
  final ValueChanged<String> onRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t.lineDetail;
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    final network = ref.watch(networkProvider);
    final book = ref.watch(nameBookProvider);
    final current = ref.watch(scoreTableProvider(const BasisCurrent())).value?.byLine[lineId];
    final allTime = ref.watch(scoreTableProvider(const BasisAllTime())).value?.byLine[lineId];
    final outside = (allTime?.denMeters ?? 0) == 0;
    final big = outside ? diagram.selfScore : (current?.denMeters ?? 0) > 0 ? current! : allTime!;
    final strip = diagramStrip(diagram);
    final route = diagram.routes.firstWhere((r) => r.routeId == routeId);
    String label(String id) =>
        network.routes[id]!.role == 'main' ? context.t.session.main : book.routes[id] ?? id;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(percentLabel(big), style: text.displaySmall?.copyWith(fontFeatures: tabularFigures)),
          if (outside)
            Text(t.selfScore, style: text.bodySmall?.copyWith(color: tokens.textMuted))
          else ...[
            if (current != null && current.denMeters > 0)
              _ScoreRow(
                label: t.current,
                score: current,
                badge: t.completeCurrent,
                // 한 번 얻은 현행 완주 배지는 새 역이 생겨도 남는다 (DESIGN §3.3)
                held: ref.watch(heldBadgesProvider).value?.contains(lineBadge(lineId)) ?? false,
              ),
            // 역대 완주 배지는 없다. 폐선 포함 진행률은 숫자로만 보인다 (DESIGN §3.3)
            if (allTime != null) _ScoreRow(label: t.allTime, score: allTime),
          ],
          if (ref.watch(unmappedLinesProvider).value?.contains(lineId) ?? false)
            Text(context.t.mapSheet.unmapped, style: text.labelMedium?.copyWith(color: tokens.textMuted)),
          LineStripBar(strip: strip),
          // 양 끝 역 이름은 칸을 반씩 쓰고 넘치면 줄인다(영어 이름이 길다, 세 언어 전수 점검 2026-11-12)
          Row(
            children: [
              Expanded(
                child: Text(
                  names[strip.startNode] ?? '',
                  style: text.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  names[strip.endNode] ?? '',
                  style: text.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: onRecord, child: Text(t.record)),
          ),
          if (diagram.routes.length > 1) ...[
            FilterPillRow(
              pills: [
                for (final item in diagram.routes)
                  FilterPill(
                    label: label(item.routeId),
                    selected: item.routeId == routeId,
                    onTap: () => onRoute(item.routeId),
                  ),
              ],
            ),
            // 다 폐지된 계통은 현행 분모가 없다
            if (route.current.denMeters > 0)
              _ScoreRow(label: label(routeId), score: route.current, badge: t.completeCurrent)
            else
              _ScoreRow(label: label(routeId), score: route.allTime),
          ],
          Text(t.hint, style: text.bodySmall?.copyWith(color: tokens.textMuted)),
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.label, required this.score, this.badge, this.held = false});

  final String label;
  final Score score;

  /// 완주 배지 글자. 없으면 배지를 보이지 않는다.
  final String? badge;

  /// 전에 얻은 배지라 100%가 아니어도 보인다.
  final bool held;

  @override
  Widget build(BuildContext context) {
    final t = context.t.lineDetail;
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(label, style: text.labelLarge),
            Text(
              '${t.km(num: kmLabel(score.numMeters), den: kmLabel(score.denMeters))}  ${percentLabel(score)}',
              style: text.bodyMedium?.copyWith(fontFeatures: tabularFigures),
            ),
            if (badge != null && (score.complete || held))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: tokens.lineRiddenSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(badge!, style: text.labelSmall),
              ),
          ],
        ),
        Meter(ratio: score.ratio),
      ],
    );
  }
}

/// 역 한 줄. 점을 누르면 방문이 바뀐다.
class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.stop,
    required this.above,
    required this.below,
    required this.name,
    required this.mark,
    required this.onNode,
    required this.onRoute,
  });

  final DiagramStop stop;
  final DiagramSection? above;
  final DiagramSection? below;
  final String name;
  final StationMark mark;
  final VoidCallback onNode;
  final ValueChanged<String> onRoute;

  @override
  Widget build(BuildContext context) {
    final t = context.t.lineDetail;
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    final color = mark != StationMark.none
        ? tokens.lineRidden
        : (stop.gone ? tokens.lineClosedUnridden : tokens.lineUnridden);
    return CustomPaint(
      painter: LineNodePainter(
        above: above == null ? null : _stemColor(above!, tokens),
        aboveWidth: above == null ? 0 : _stemWidth(above!),
        below: below == null ? null : _stemColor(below!, tokens),
        belowWidth: below == null ? 0 : _stemWidth(below!),
        ring: color,
        fill: mark == StationMark.stepped ? tokens.lineRidden : tokens.surface,
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: t.stopNode(name: name),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onNode,
              child: const SizedBox(width: lineStemColumn, height: 48),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  name,
                  style: text.bodyLarge?.copyWith(color: stop.gone ? tokens.textClosed : tokens.text),
                ),
                for (final other in stop.others)
                  Consumer(
                    builder: (context, ref, _) => TextButton(
                      onPressed: () => onRoute(other),
                      child: Text(t.joinsTo(name: ref.watch(nameBookProvider).routes[other] ?? other)),
                    ),
                  ),
              ],
            ),
          ),
          if (stop.kmCum != null)
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 16),
              child: Text(
                // 営業キロ를 몰라 추정한 역은 숫자 뒤에 `?` (54.1?, DESIGN §4.5)
                '${stop.kmCum!.toStringAsFixed(1)}${stop.kmEstimated ? '?' : ''}',
                style: text.labelSmall?.copyWith(color: tokens.textMuted, fontFeatures: tabularFigures),
              ),
            ),
        ],
      ),
    );
  }
}

Color _stemColor(DiagramSection section, AppTokens tokens) => section.ridden
    ? tokens.lineRidden
    : (section.gone ? tokens.lineClosedUnridden : tokens.lineUnridden);

double _stemWidth(DiagramSection section) => section.ridden ? 6 : 4;

/// 역 사이 한 칸. 누르면 탑승과 미승이 바뀐다.
class _SectionRow extends StatelessWidget {
  const _SectionRow({
    super.key,
    required this.section,
    this.closedYear,
    required this.from,
    required this.to,
    required this.picked,
    required this.onTap,
  });

  final DiagramSection section;

  /// 폐지 구간이 여기서 시작하면 그 연도다 (DESIGN §8).
  final String? closedYear;
  final String from;
  final String to;
  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.t.lineDetail;
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    return Semantics(
      button: section.editable,
      label: section.ridden ? t.sectionRidden(from: from, to: to) : t.sectionOpen(from: from, to: to),
      child: InkWell(
        onTap: section.editable ? onTap : null,
        child: ColoredBox(
          color: picked ? tokens.lineRiddenSoft : Colors.transparent,
          // 글이 길면(영어·큰 글자) 줄을 늘려 두 줄로 쓴다. 줄기는 줄 높이를 따라간다 (세 언어 전수 점검 2026-11-12)
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: lineStemColumn,
                    child: Center(
                      child: Container(width: _stemWidth(section), color: _stemColor(section, tokens)),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          [
                            '${kmLabel(section.meters)} km',
                            if (closedYear != null) closedNote(context, closedYear!),
                          ].join(' · '),
                          style: text.labelSmall?.copyWith(
                            color: tokens.textMuted,
                            fontFeatures: tabularFigures,
                          ),
                        ),
                      ),
                    ),
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
