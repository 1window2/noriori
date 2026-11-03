import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/session_providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tokens.dart';
import '../../../i18n/strings.g.dart';
import '../controller/record_session_controller.dart';
import 'session_painters.dart';

/// 줄기 칸의 색. 칠하기는 고른 구간, 이미 탄 구간, 영업 상태 순이다.
final class TrunkStyle {
  const TrunkStyle(this.state, this.ridden, this.tokens);

  final RecordSessionState state;
  final List<bool> ridden;
  final AppTokens tokens;

  TrunkPiece get tail => TrunkPiece(tokens.selectorGone, SelectorRuler.closedWidth);

  TrunkPiece? gap(int gap) {
    final rows = state.visible;
    if (gap < 0 || gap >= rows.length - 1) return null;
    final already = gap < ridden.length && ridden[gap];
    if (state.coversBelow(rows[gap].seq)) {
      return TrunkPiece(tokens.lineRidden, SelectorRuler.openWidth, dashed: !already);
    }
    if (already) {
      return TrunkPiece(tokens.lineRiddenSoft, SelectorRuler.openWidth);
    }
    final open = gap >= state.openGaps.length || state.openGaps[gap];
    return open ? TrunkPiece(tokens.text, SelectorRuler.openWidth) : tail;
  }
}

String? _year(String? raw) => raw?.substring(0, 4);

/// `~1985`, `1987~`. 이관 뒤 폐지된 노선은 `1989~2006`이다 (DESIGN §8.1).
String? _tail(BuildContext context, SelectorLink link, {required bool gone, bool chained = false}) {
  final t = context.t.session.state;
  final end = link.validToHi;
  final from = _year(link.validFromLo);
  if (end != null && end != DateSpan.maxDate && gone) {
    final year = _year(end) ?? '?';
    return chained && from != null ? t.span(from: from, to: year) : t.until(year: year);
  }
  return gone && from != null ? t.since(year: from) : null;
}

/// 폐지 구간의 한 줄. 연도를 모르면 낱말만 적는다.
String closedNote(BuildContext context, String year) {
  final t = context.t.session;
  return year == '?' ? t.closedUnknown : t.closedSection(year: year);
}

/// 고른 역이 있으면 넘어가기 전에 묻는다. 없으면 그대로 넘어간다 (DESIGN §8).
Future<bool> confirmLeave(BuildContext context, WidgetRef ref) async {
  if (ref.read(recordSessionProvider).from == null) return true;
  final t = context.t.session;
  final leave = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(t.leaveTitle),
      content: Text(t.leaveBody),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancel)),
        TextButton(onPressed: () => Navigator.pop(context, true), child: Text(t.leave)),
      ],
    ),
  );
  return leave ?? false;
}

/// 선택기의 한 줄을 그린다.
class SessionLineTile extends StatelessWidget {
  const SessionLineTile({super.key, required this.line, required this.next, required this.trunk});

  final SelectorLine line;
  final SelectorLine? next;
  final TrunkStyle trunk;

  @override
  Widget build(BuildContext context) => switch (line) {
        final StopLine stop => _StopTile(
            line: stop,
            above: trunk.gap(stop.index - 1),
            below: trunk.gap(stop.index) ?? (next is ArchiveLine ? trunk.tail : null),
          ),
        final BranchLine branch => _BranchTile(line: branch, trunk: trunk.gap(branch.gap)),
        final EndLine end => _EndTile(line: end),
        final ArchiveLine archive => _ArchiveTile(
            line: archive,
            above: trunk.gap(archive.gap) ?? trunk.tail,
            below: trunk.gap(archive.gap) ?? (next is ArchiveLine ? trunk.tail : null),
          ),
        final SectionLine section => _SectionTile(line: section, trunk: trunk.gap(section.gap)),
      };
}

class _StopTile extends ConsumerWidget {
  const _StopTile({required this.line, required this.above, required this.below});

  final StopLine line;
  final TrunkPiece? above;
  final TrunkPiece? below;

  Future<void> _tap(BuildContext context, WidgetRef ref, RecordSessionState state) async {
    final session = ref.read(recordSessionProvider.notifier);
    final row = line.row;
    if (!session.asksLap(row)) return session.tap(row);
    final t = context.t.session;
    final lap = await showDialog<bool>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(state.nameOf(row.node)),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.clear),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.lap),
          ),
        ],
      ),
    );
    if (lap == null) return;
    if (lap) {
      session.pickLap();
    } else {
      session.tap(row);
    }
  }

  /// 고를 수 없는 역을 누르면 이유를 알린다 (10-30 승인 목업).
  void _whyNot(BuildContext context) {
    final t = context.t.session;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(line.row.state == StopState.suspended ? t.whySuspended : t.whyClosed),
        persist: false,
      ),
    );
  }

  /// 체크박스의 상태표대로 글자 하나를 고른다 (DESIGN §8 탑승일 상태표).
  String? _note(BuildContext context) {
    final t = context.t.session.state;
    final row = line.row;
    // 구분선과 같은 해에 폐역된 역은 그 줄에 연도가 있다. 더 일찍 폐역된 역에만 적는다
    if (line.quiet) return null;
    return switch (row.state) {
      StopState.maybe => t.maybe,
      StopState.beforeOpen => t.since(year: row.openYear ?? '?'),
      StopState.suspended => t.suspended,
      StopState.closed || StopState.lineClosed || StopState.noEdge =>
        t.until(year: row.closeYear ?? '?'),
      StopState.open => row.closeYear == null ? null : t.until(year: row.closeYear!),
      // 날짜를 모르면 탈 수는 있어도 그날 있었는지 모른다
      StopState.unknown =>
        row.closeYear == null ? null : '${t.until(year: row.closeYear!)} ${t.maybe}',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordSessionProvider);
    final book = ref.watch(nameBookProvider);
    final t = context.t.session;
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    final row = line.row;
    final picked = state.isPicked(row.seq);
    final end = row.seq == state.from?.seq || row.seq == state.to?.seq;
    final mark = ref.watch(stationMarksProvider).of(ref.watch(networkProvider), row.node);
    final tier3 = !row.selectable;
    final rowHeight = line.small ? 32.0 : (tier3 ? 40.0 : 48.0);
    final style = text.titleMedium?.copyWith(
      fontWeight: tier3 ? FontWeight.w400 : (end ? FontWeight.w700 : FontWeight.w500),
      color: tier3 ? tokens.textClosed : tokens.text,
    );
    final scaler = MediaQuery.textScalerOf(context);
    final lineHeight = scaler.scale((style?.fontSize ?? 16) * (style?.height ?? 1.3));
    final top = ((rowHeight - lineHeight) / 2).clamp(2.0, 24.0);
    final centerY = top + lineHeight / 2;
    final note = _note(context);
    final name = state.nameOf(row.node);
    final japanese = state.japanese[row.node];
    final km = row.kmCum;
    final saved = row.savedAs;
    final returns = line.returnsTo;
    // 폐역의 환승은 캡슐 없이 글자로만 적는다. 날짜를 몰라도 같다 (DESIGN §8.1)
    final onTransfers = !tier3 && row.closeYear == null && line.transfers.isNotEmpty;
    final circle = tier3 ? 4.5 : 8.5;
    final ring = end || picked || mark != StationMark.none
        ? tokens.lineRidden
        : (tier3 ? tokens.textClosed : tokens.text);
    final count = line.transfers.fold(0, (sum, group) => sum + group.items.length);
    final spoken = [
      name,
      if (km != null) t.spokenKm(km: km.toStringAsFixed(1)),
      if (row.closeYear != null) t.spokenClosed(year: row.closeYear!) else t.spokenOpen,
      if (mark != StationMark.none) t.spokenRidden,
      if (count > 0) t.spokenTransfer(n: count),
      if (row.seq == state.from?.seq) t.spokenFrom else if (row.seq == state.to?.seq) t.spokenTo,
    ].join(', ');
    return Semantics(
      container: true,
      button: true,
      enabled: row.selectable,
      selected: picked,
      label: spoken,
      excludeSemantics: true,
      child: InkWell(
        onTap: row.selectable ? () => _tap(context, ref, state) : () => _whyNot(context),
        child: CustomPaint(
          painter: StopPainter(
            centerY: centerY,
            above: above,
            below: below,
            ring: ring,
            fill: end || mark == StationMark.stepped ? tokens.lineRidden : tokens.surface,
            background: tokens.surface,
            radius: circle,
            ringWidth: tier3 ? 2 : 3.5,
            selected: end,
            selectColor: tokens.lineRidden,
            dots: [
              // 폐역의 환승은 캡슐 없이 글자로만 적는다 (DESIGN §8.1)
              if (onTransfers)
                for (final group in line.transfers)
                  TransferDot(
                    flow: group.flow,
                    color: group.gone ? tokens.selectorGone : tokens.lineUnridden,
                    number: group.number,
                  ),
            ],
            capsule: line.transfers.every((group) => group.gone)
                ? tokens.selectorGone
                : tokens.lineUnridden,
            stemUp: line.branchUp
                ? (line.branchUpGone ? tokens.selectorGone : tokens.lineUnridden)
                : null,
            stemDown: line.branchDown
                ? (line.branchDownGone ? tokens.selectorGone : tokens.lineUnridden)
                : null,
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(SelectorRuler.textX, top, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 10,
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: name, style: style),
                            if (japanese != null && japanese != name)
                              TextSpan(
                                text: '  $japanese',
                                locale: const Locale('ja'),
                                style: text.bodySmall?.copyWith(
                                  color: tier3 ? tokens.textClosed : tokens.textMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (end)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          row.seq == state.from?.seq ? t.from : t.to,
                          style: text.bodySmall?.copyWith(
                            color: tokens.lineRidden,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (state.stopsAway(row) case final away?)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          t.away(n: away),
                          style: text.bodySmall?.copyWith(color: tokens.textMuted),
                        ),
                      ),
                    if (note != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(note, style: text.bodySmall?.copyWith(color: tokens.textClosed)),
                      ),
                    Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          km?.toStringAsFixed(1) ?? '?',
                          style: text.bodySmall?.copyWith(
                            color: tier3 ? tokens.textClosed : tokens.textMuted,
                            fontFeatures: tabularFigures,
                          ),
                        ),
                      ),
                  ],
                ),
                if (saved != null)
                  Text(
                    t.savedAs(line: book.lines[saved] ?? saved),
                    style: text.bodySmall,
                  ),
                if (returns != null)
                  Text(t.returnsTo(name: state.nameOf(returns)), style: text.bodySmall)
                else if (line.transfers.isNotEmpty)
                  _Transfers(
                    stop: name,
                    groups: line.transfers,
                    state: state,
                    lines: book.lines,
                    sameCompany: ref.watch(displayRulesProvider).sameCompany,
                  ),
                SizedBox(height: line.transfers.isEmpty ? top : 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 글자 한 조각. 같은 역의 같은 회사 노선은 한 조각으로 묶는다.
final class _Entry {
  _Entry(this.name, this.station, this.tail, {required this.gone, required this.lineId});

  String name;
  final String? lineId;
  final String station;
  final String? tail;
  final bool gone;

  String get text => '$name${station.isEmpty ? '' : '($station)'}${tail == null ? '' : ' $tail'}';
}

/// 역 이름 아래의 환승 목록. 묶음이 둘 이상이면 번호를 붙인다 (DESIGN §8.1).
class _Transfers extends StatelessWidget {
  const _Transfers({
    required this.stop,
    required this.groups,
    required this.state,
    required this.lines,
    required this.sameCompany,
  });

  final String stop;
  final List<TransferGroup> groups;
  final RecordSessionState state;
  final Map<String, String> lines;
  final bool Function(String? a, String? b) sameCompany;

  /// 다른 이름 역이면 괄호로 적는다 (DESIGN §8.1).
  String _station(SelectorLink link) {
    final other = link.otherNode == null ? '' : state.nameOf(link.otherNode!);
    return other == stop || other.isEmpty ? '' : '($other)';
  }

  String _lineName(String? id) => lines[id] ?? id ?? '';

  List<_Entry> _entries(BuildContext context, TransferGroup group) {
    final out = <_Entry>[];
    for (final item in group.items) {
      if (item.before.isNotEmpty) continue;
      final link = item.link;
      final other = link.otherNode == null ? '' : state.nameOf(link.otherNode!);
      final station = other == stop ? '' : other;
      final name = _lineName(link.otherLineId);
      final owner = name.split(' ').first;
      _Entry? same;
      for (final entry in out) {
        if (station.isNotEmpty &&
            !item.gone &&
            !entry.gone &&
            entry.station == station &&
            sameCompany(entry.lineId, link.otherLineId)) {
          same = entry;
        }
      }
      if (same != null) {
        // 이름 앞의 회사명이 같으면 한 번만 적는다
        final prefixed = same.name.split(' ').first == owner;
        same.name = '${same.name}·${prefixed ? name.substring(owner.length).trim() : name}';
      } else {
        out.add(
          _Entry(name, station, _tail(context, link, gone: item.gone), gone: item.gone, lineId: link.otherLineId),
        );
      }
    }
    return out;
  }

  InlineSpan _span(List<_Entry> entries, BuildContext context) {
    final tokens = context.tokens;
    final style = Theme.of(context).textTheme.bodySmall;
    return TextSpan(
      children: [
        for (final (index, entry) in entries.indexed) ...[
          if (index > 0) TextSpan(text: ' · ', style: style?.copyWith(color: tokens.textClosed)),
          TextSpan(
            text: entry.text,
            style: style?.copyWith(color: entry.gone ? tokens.textClosed : tokens.textMuted),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    final children = <Widget>[];
    for (final group in groups) {
      for (final item in group.items) {
        if (item.before.isEmpty) continue;
        for (final old in item.before) {
          children.add(
            Text(
              '${_lineName(old.otherLineId)}${_station(old)} ${_tail(context, old, gone: true) ?? ''}',
              style: text.bodySmall?.copyWith(color: tokens.textClosed),
            ),
          );
        }
        // 이관 뒤 폐지되면 선은 3단계이고 글자는 폐선색이다 (DESIGN §8.1)
        children.add(
          Text(
            '${_lineName(item.link.otherLineId)}${_station(item.link)} '
            '${item.gone ? _tail(context, item.link, gone: true, chained: true) ?? '' : context.t.session.state.since(year: _year(item.link.validFromLo) ?? '?')}',
            style: text.bodySmall?.copyWith(color: item.gone ? tokens.textClosed : tokens.textMuted),
          ),
        );
      }
      final entries = _entries(context, group);
      if (entries.isEmpty) continue;
      final body = Text.rich(_span(entries, context));
      final number = group.number;
      children.add(
        number == null
            ? body
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  _NumberMark(number: number, gone: group.gone),
                  Expanded(child: body),
                ],
              ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 1,
      children: children,
    );
  }
}

/// 목록의 번호. 왼쪽 점의 번호와 같다.
class _NumberMark extends StatelessWidget {
  const _NumberMark({required this.number, required this.gone});

  final int number;
  final bool gone;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = gone ? tokens.selectorGone : tokens.lineUnridden;
    // 왼쪽 그림의 번호와 같은 크기로 둔다. 원 안의 숫자는 글자 배율을 따르지 않는다
    return MediaQuery.withNoTextScaling(child: Container(
      width: 14,
      height: 14,
      margin: const EdgeInsets.only(top: 1),
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 1.4)),
      child: Text(
        '$number',
        style: TextStyle(fontSize: 9.5, height: 1, fontWeight: FontWeight.w700, color: color),
      ),
    ));
  }
}

class _BranchTile extends ConsumerWidget {
  const _BranchTile({required this.line, required this.trunk});

  final BranchLine line;
  final TrunkPiece? trunk;

  void _say(ScaffoldMessengerState messenger, String message) =>
      messenger.showSnackBar(SnackBar(content: Text(message), persist: false));

  Future<void> _open(BuildContext context, WidgetRef ref, String name) async {
    final t = context.t.session;
    final messenger = ScaffoldMessenger.of(context);
    final session = ref.read(recordSessionProvider.notifier);
    final link = line.item.link;
    if (line.archive != null || !session.canOpen(link.otherLineId)) {
      return _say(messenger, t.archiveLine(name: name));
    }
    if (await confirmLeave(context, ref)) await session.jumpTo(link, line.at);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordSessionProvider);
    final book = ref.watch(nameBookProvider);
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    final item = line.item;
    final link = item.link;
    final archive = line.archive;
    final name = archive != null
        ? state.archiveNames[archive.id] ?? archive.id
        : book.lines[link.otherLineId] ?? link.otherLineId ?? '';
    final next = link.nextStop == null ? null : state.nameOf(link.nextStop!);
    final last = link.terminal == null ? null : state.nameOf(link.terminal!);
    final arrow = next == null ? null : (last == null || last == next ? next : '$next › $last');
    final at = state.nameOf(line.at.node);
    final other = link.otherNode == null ? '' : state.nameOf(link.otherNode!);
    final station = other.isEmpty || other == at ? '' : '($other)';
    final tail = archive != null ? context.t.session.state.until(year: archive.closedYear) : _tail(context, link, gone: item.gone);
    final color = item.gone ? tokens.selectorGoneText : tokens.textMuted;
    // 옛 이름 줄의 높이는 글자 크기를 따른다. 그림의 곡선 위치가 이 값을 쓴다
    final oldHeight = MediaQuery.textScalerOf(context).scale(16);
    final centerY = 24.0 + item.before.length * oldHeight;
    return Semantics(
      container: true,
      button: true,
      label: context.t.session.spokenBranch(line: name, next: arrow ?? ''),
      excludeSemantics: true,
      child: InkWell(
        onTap: () => _open(context, ref, name),
        child: CustomPaint(
          painter: BranchPainter(
            trunk: trunk,
            color: item.gone ? tokens.selectorGone : tokens.lineUnridden,
            stem: line.stemGone ? tokens.selectorGone : tokens.lineUnridden,
            through: line.throughGone ? tokens.selectorGone : tokens.lineUnridden,
            background: tokens.surface,
            up: line.up,
            stacked: line.stacked,
            centerY: centerY,
            fromTrunk: link.midway,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: 48 + item.before.length * oldHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(SelectorRuler.textX, 0, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final old in item.before)
                    SizedBox(
                      height: oldHeight,
                      child: Text(
                        '${book.lines[old.otherLineId] ?? ''} ${_tail(context, old, gone: true) ?? ''}',
                        style: text.bodySmall?.copyWith(color: tokens.selectorGoneText),
                      ),
                    ),
                  Row(
                    spacing: 8,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '$name$station',
                              style: text.bodyMedium?.copyWith(fontSize: 13, color: color),
                            ),
                            if (arrow != null)
                              Text(arrow, style: text.bodySmall?.copyWith(fontSize: 11.5, color: color)),
                          ],
                        ),
                      ),
                      if (tail != null)
                        Text(tail, style: text.bodySmall?.copyWith(fontSize: 11.5, color: color)),
                    ],
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

class _EndTile extends ConsumerWidget {
  const _EndTile({required this.line});

  final EndLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordSessionProvider);
    final book = ref.watch(nameBookProvider);
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    final first = line.items.first.link;
    final name = book.lines[first.otherLineId] ?? first.otherLineId ?? '';
    final nexts = {
      for (final item in line.items)
        if (item.link.nextStop != null) state.nameOf(item.link.nextStop!),
    }.toList();
    final where = nexts.length > 1
        ? context.t.session.bound(names: nexts.join('·'))
        : nexts.firstOrNull;
    final session = ref.read(recordSessionProvider.notifier);
    final gone = line.items.every((item) => item.gone);
    final color = gone ? tokens.selectorGoneText : tokens.textMuted;
    return InkWell(
      onTap: session.canOpen(first.otherLineId)
          ? () async {
              if (await confirmLeave(context, ref)) await session.jumpTo(first, line.at);
            }
          : null,
      child: CustomPaint(
        painter: EndPainter(color: gone ? tokens.selectorGone : tokens.lineUnridden, up: line.up),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(SelectorRuler.textX, 0, 12, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(name, style: text.bodyMedium?.copyWith(fontSize: 13, color: color)),
                  if (where != null)
                    Text(where, style: text.bodySmall?.copyWith(fontSize: 11.5, color: color)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArchiveTile extends ConsumerWidget {
  const _ArchiveTile({required this.line, required this.above, required this.below});

  final ArchiveLine line;
  final TrunkPiece? above;
  final TrunkPiece? below;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recordSessionProvider);
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    final stop = line.stop;
    final name = state.archiveNames[stop.id] ?? stop.id;
    final year = context.t.session.state.until(year: stop.closedYear);
    final message = context.t.session.archiveStop(name: name, year: stop.closedYear);
    final km = stop.km;
    final style = text.bodyMedium?.copyWith(color: tokens.textClosed);
    return InkWell(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), persist: false),
      ),
      child: CustomPaint(
        painter: PlainPainter(above: above, below: below, node: tokens.textClosed),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(SelectorRuler.textX, 8, 12, 8),
            child: Row(
              spacing: 10,
              children: [
                Expanded(child: Text(name, style: style)),
                Text(year, style: text.bodySmall?.copyWith(color: tokens.textClosed)),
                Text(
                  km == null ? '?' : km.toStringAsFixed(1),
                  style: text.bodySmall?.copyWith(
                    color: tokens.textClosed,
                    fontFeatures: tabularFigures,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 폐지 구간의 경계. 점선 구분선 바로 아래에 해를 적는다.
class _SectionTile extends ConsumerWidget {
  const _SectionTile({required this.line, required this.trunk});

  final SectionLine line;
  final TrunkPiece? trunk;

  /// 이 구간이 위치 미확인이면 지도에 없다고 알린다 (DESIGN §8.1).
  bool _unlocated(WidgetRef ref) {
    final state = ref.watch(recordSessionProvider);
    final rows = state.visible;
    final gap = line.gap;
    if (gap < 0 || gap + 1 >= rows.length) return false;
    final ends = {rows[gap].node, rows[gap + 1].node};
    final markers = ref.watch(mapMarkersProvider).value ?? const <MapMarker>[];
    return markers.any((m) => m.lineId == state.lineId && ends.contains(m.anchorNode));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    final year = line.year;
    final unlocated = _unlocated(ref);
    return CustomPaint(
      painter: PlainPainter(above: trunk, below: trunk, dash: tokens.textClosed),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(SelectorRuler.textX, 4, 12, 4),
        child: SizedBox(
          width: double.infinity,
          child: year == null
              ? const SizedBox(height: 16)
              : Row(
                  spacing: 6,
                  children: [
                    Flexible(
                      child: Text(
                        closedNote(context, year),
                        style: text.bodySmall?.copyWith(color: tokens.textClosed),
                      ),
                    ),
                    if (unlocated) ...[
                      Icon(Icons.location_off_outlined, size: 14, color: tokens.textClosed),
                      Flexible(
                        child: Text(
                          context.t.mapSheet.unmapped,
                          style: text.bodySmall?.copyWith(color: tokens.textClosed),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
