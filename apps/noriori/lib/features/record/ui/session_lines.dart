import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/session_providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tokens.dart';
import '../../../i18n/strings.g.dart';
import '../controller/record_session_controller.dart';
import 'one_way_bubble.dart';
import 'session_painters.dart';
import 'switchback_mark.dart';

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
    final oneWay = gap < state.oneWayGaps.length ? state.oneWayGaps[gap] : null;
    if (state.coversBelow(rows[gap].seq)) {
      return TrunkPiece(tokens.lineRidden, SelectorRuler.openWidth, dashed: !already, oneWay: oneWay);
    }
    if (already) {
      return TrunkPiece(tokens.lineRiddenSoft, SelectorRuler.openWidth, oneWay: oneWay);
    }
    final open = gap >= state.openGaps.length || state.openGaps[gap];
    return open ? TrunkPiece(tokens.text, SelectorRuler.openWidth, oneWay: oneWay) : tail;
  }
}

String? _year(String? raw) => raw?.substring(0, 4);

/// `~1985`, `1987~`. 이관 뒤 폐지된 노선은 `1989~2006`이다 (DESIGN §8.1).
String? _tail(BuildContext context, SelectorLink link, {required bool gone, bool chained = false, bool suspended = false}) {
  final t = context.t.session.state;
  // 상대 노선 칸이 운휴로 끊긴 연결은 끝난 해가 아니라 운휴 중이다 (10회차 G1 kanto_3-007)
  if (suspended) return context.t.session.suspendedSection;
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

/// 고리 노선의 출발역을 다시 누르면 지울지 한 바퀴 돌지 묻는다. 닫으면 null이다.
Future<bool?> askLap(BuildContext context, String name) {
  final t = context.t.session;
  return showDialog<bool>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(name),
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
}

/// 병주 선의 색 (DESIGN §8.1). 분기 곡선과 같다.
LaneStyle laneStyleOf(AppTokens tokens) =>
    LaneStyle(color: tokens.lineUnridden, gone: tokens.selectorGone, background: tokens.surface);

/// 선택기의 한 줄을 그린다.
class SessionLineTile extends StatelessWidget {
  const SessionLineTile({super.key, required this.line, this.prev, required this.next, required this.trunk});

  final SelectorLine line;
  final SelectorLine? prev;
  final SelectorLine? next;

  /// 역 바로 옆 줄인지. 위로 가는 줄은 아래 이웃이, 아래로 가는 줄은 위 이웃이 역이다
  bool _fromStop(bool up) => (up ? next : prev) is StopLine;
  final TrunkStyle trunk;

  @override
  Widget build(BuildContext context) => switch (line) {
        final StopLine stop => _StopTile(
            line: stop,
            above: trunk.gap(stop.index - 1) ?? (stop.index == 0 && prev is ArchiveLine ? trunk.tail : null),
            below: trunk.gap(stop.index) ?? (next is ArchiveLine ? trunk.tail : null),
          ),
        final BranchLine branch => _BranchTile(line: branch, trunk: trunk.gap(branch.gap), fromStop: _fromStop(branch.up)),
        final EndLine end => _EndTile(line: end, fromStop: _fromStop(end.up), trunk: trunk.gap(end.gap)),
        final ArchiveLine archive => _ArchiveTile(
            line: archive,
            // 첫 역 앞(-1)의 열람 전용 역은 위로 잇는 것이 없고 아래 첫 역으로 이어진다 (10회차 G1 chugoku_shikoku_2-003)
            above: archive.gap < 0 ? (prev is ArchiveLine ? trunk.tail : null) : trunk.gap(archive.gap) ?? trunk.tail,
            below: archive.gap < 0 ? trunk.tail : trunk.gap(archive.gap) ?? (next is ArchiveLine ? trunk.tail : null),
          ),
        final SectionLine section => _SectionTile(line: section, trunk: trunk.gap(section.gap)),
        final TransferLine hand => _HandTile(line: hand, trunk: trunk.gap(hand.gap)),
      };
}

class _StopTile extends ConsumerWidget {
  const _StopTile({required this.line, required this.above, required this.below});

  final StopLine line;
  final TrunkPiece? above;
  final TrunkPiece? below;

  Future<void> _tap(BuildContext context, WidgetRef ref, RecordSessionState state) async {
    OneWayBubble.dismiss();
    final session = ref.read(recordSessionProvider.notifier);
    final row = line.row;
    if (!session.asksLap(row)) return _explain(context, ref, session.tap(row));
    final lap = await askLap(context, state.nameOf(row.node));
    if (lap == null) return;
    if (lap) {
      session.pickLap();
    } else if (context.mounted) {
      _explain(context, ref, session.tap(row));
    }
  }

  /// 한 방향 운행·정차 때문에 받지 않았거나 돌아가는 길로 받았으면 누른 역 옆에 말풍선을 띄운다 (DESIGN §8).
  void _explain(BuildContext context, WidgetRef ref, OneWayNote? note) {
    if (note == null || !context.mounted) return;
    final t = context.t.session;
    final state = ref.read(recordSessionProvider);
    final rows = state.rows.where((row) => row.selectable).toList();
    final toward = rows.isEmpty ? '' : state.nameOf((note.down ? rows.last : rows.first).node);
    final name = note.node == null ? '' : state.nameOf(note.node!);
    final (title, detail) = switch (note.kind) {
      OneWayKind.stop when note.alight => (t.alightTitle, t.alightDetail),
      // 막힌 역이 누른 역이 아닐 수 있어(출발역) 제목에 역 이름을 넣는다
      OneWayKind.stop => (
          switch (note.label) {
            'down' => t.stopDownTitle(name: name),
            'up' => t.stopUpTitle(name: name),
            _ => t.stopOneWayTitle(name: name),
          },
          t.towardOnly(name: toward),
        ),
      OneWayKind.section => (t.sectionTitle, t.sectionDetail),
      OneWayKind.around => (t.aroundTitle, t.aroundDetail(km: kmLabel(note.meters ?? 0))),
    };
    OneWayBubble.show(
      context,
      title: title,
      detail: detail,
      action: note.canReverse ? t.reverse : null,
      onAction: () => _explain(context, ref, ref.read(recordSessionProvider.notifier).reverse(note)),
    );
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
      // 운휴는 시작 해를 붙인다(폐역 「~해」와 짝). 역 정차만 운휴인 곳(全列車通過, 羽前前波)도 같다 (사용자 결정 2026-11-16)
      StopState.suspended => row.suspendedSince == null ? t.suspended : t.suspendedSince(year: row.suspendedSince!),
      StopState.closed || StopState.lineClosed || StopState.noEdge =>
        t.until(year: row.closeYear ?? '?'),
      // 이관으로 끝난 정차는 폐역이 아니라 구분선 한 줄로만 알린다 (DESIGN §8.0.1 B안)
      StopState.open => row.closeYear == null || row.handedTo != null ? null : t.until(year: row.closeYear!),
      // 날짜를 모르면 탈 수는 있어도 그날 있었는지 모른다. 물음표는 해에 붙인다(~1962?, 사용자 결정 2026-11-12)
      // 날짜를 모를 때 지금 운휴 중인 역은 「운휴 2022~」다
      StopState.unknown => row.closeYear == null || row.handedTo != null
          ? (row.closeYear == null && row.suspendedSince != null ? t.suspendedSince(year: row.suspendedSince!) : null)
          : '${t.until(year: row.closeYear!)}${t.maybe}',
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
    // 그날 한 방향 열차만 서는 역은 이름 뒤에 화살표 칩을 붙인다 (DESIGN §8 한 방향 정차, 사용자 결정 2026-11-12)
    final oneWay = state.stopDirections[row.seq];
    final oneWayLabel = oneWay == null
        ? null
        : oneWay.use == 'alight'
        ? t.onlyAlight
        : switch (oneWay.label) {
            'down' => t.onlyDown,
            'up' => t.onlyUp,
            _ => t.onlyOneWay,
          };
    // 다른 언어판은 일본어 이름, 일본어판은 한자 이름의 읽기(히라가나)를 작게 단다. 읽기 근거가 없으면 한자만이다
    final japanese = state.japanese[row.node];
    final reading = state.readings[row.node];
    final aside = reading ?? (japanese != null && japanese != name ? japanese : null);

    // 날짜 모름일 때 예전에만 仮乗降場·臨時駅이었던 역의 작은 표식 (사용자 결정 2026-11-07)
    final past = switch (state.pastMarks[row.node]) {
      'kari' => (label: t.pastKari, spoken: t.spokenPastKari),
      'rinji' => (label: t.pastRinji, spoken: t.spokenPastRinji),
      _ => null,
    };
    // 営業キロ를 몰라 위치로 추정한 역은 km 대신 `?` (DESIGN §4.5)
    final km = row.kmEstimated ? null : row.kmCum;
    // 이관 구간의 역은 구분선이 저장 노선을 알린다. 줄마다 적지 않는다 (DESIGN §8.0.1 B안)
    final saved = row.handedTo != null ? null : row.savedAs;
    final returns = line.returnsTo;
    // 폐역의 환승은 캡슐 없이 글자로만 적는다. 날짜를 몰라도 같다 (DESIGN §8.1)
    final onTransfers = !tier3 && (row.closeYear == null || row.handedTo != null) && line.transfers.isNotEmpty;
    // 1950년 전에 정차가 끝난 역은 열람 전용 역과 같은 꽉 찬 작은 점이다 (사용자 결정 2026-11-08)
    final archived = row.beforeFloor;
    final circle = archived ? 3.5 : (tier3 ? 4.5 : 8.5);
    final ring = end || picked || mark != StationMark.none
        ? tokens.lineRidden
        : (tier3 ? tokens.textClosed : tokens.text);
    final count = line.transfers.fold(0, (sum, group) => sum + group.items.length);
    final spoken = [
      name,
      ?past?.spoken,
      if (oneWay != null)
        switch (oneWay.label) {
          'down' => t.spokenOnlyDown,
          'up' => t.spokenOnlyUp,
          _ => t.spokenOnlyOneWay,
        },
      if (km != null) t.spokenKm(km: km.toStringAsFixed(1)),
      if (row.closeYear != null && row.handedTo == null)
        t.spokenClosed(year: row.closeYear!)
      else if (row.suspendedSince != null && (row.state == StopState.suspended || row.state == StopState.unknown))
        t.spokenSuspendedSince(year: row.suspendedSince!)
      else
        t.spokenOpen,
      if (mark != StationMark.none) t.spokenRidden,
      if (count > 0) t.spokenTransfer(n: count),
      if (row.seq == state.from?.seq) t.spokenFrom else if (row.seq == state.to?.seq) t.spokenTo,
    ].join(', ');
    // 이름 오른쪽의 작은 글자들. 이름 첫 줄에 맞춰 조금 내린다
    Widget side(String label, TextStyle? style) => Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(label, style: style),
        );
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
            lanes: line.lanes,
            laneStyle: laneStyleOf(tokens),
            endUp: switch (line.endUp) {
              null => null,
              true => tokens.selectorGone,
              false => tokens.lineUnridden,
            },
            endDown: switch (line.endDown) {
              null => null,
              true => tokens.selectorGone,
              false => tokens.lineUnridden,
            },
            centerY: centerY,
            above: above,
            below: below,
            ring: ring,
            fill: archived ? tokens.textClosed : (end || mark == StationMark.stepped ? tokens.lineRidden : tokens.surface),
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
                      child: LayoutBuilder(builder: (context, box) {
                        final asideStyle = text.bodySmall?.copyWith(
                          color: tier3 ? tokens.textClosed : tokens.textMuted,
                        );
                        // 읽기는 이름 마지막 줄의 남은 자리에 통째로 들어가면 이름 바로 뒤에, 조금이라도 넘치면 다음 줄 맨 앞부터 둔다.
                        // 이름이 여러 줄이어도 같은 규칙이다. 읽기가 이름 줄과 아랫줄로 쪼개지거나 한두 글자만 삐져나오지 않는다.
                        // 이름·읽기 모두 줄 안에서는 글자가 차는 대로 끊는다 (사용자 결정 2026-11-16)
                        final besideName = aside == null || _fitsAfter(
                          context,
                          TextSpan(children: [
                            TextSpan(text: name, style: style),
                            if (past != null) TextSpan(text: ' ${past.label}', style: text.labelSmall),
                          ]),
                          TextSpan(text: '  $aside', style: asideStyle, locale: const Locale('ja')),
                          box.maxWidth,
                          // 한 방향 칩은 글자 폭으로 잴 수 없어 넉넉히 더한다
                          extra: oneWay == null ? 0 : 72 * MediaQuery.textScalerOf(context).scale(1),
                        );
                        return Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: name, style: style),
                            if (oneWay != null)
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                // 하차전용은 방향 칩이 아니라 화살표를 붙이지 않는다 (사용자 결정 2026-11-12)
                                child: _OneWayChip(
                                  down: oneWay.use == 'alight' ? null : oneWay.direction == seqUp,
                                  label: oneWayLabel!,
                                  muted: tier3,
                                ),
                              ),
                            if (past != null)
                              TextSpan(
                                text: ' ${past.label}',
                                style: text.labelSmall?.copyWith(color: tokens.textMuted),
                              ),
                            if (aside != null)
                              TextSpan(
                                text: besideName ? '  $aside' : '\n$aside',
                                locale: const Locale('ja'),
                                style: asideStyle,
                              ),
                          ],
                        ),
                      );
                      }),
                    ),
                    if (end)
                      side(
                        row.seq == state.from?.seq ? t.from : t.to,
                        text.bodySmall?.copyWith(
                          color: tokens.lineRidden,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    if (state.stopsAway(row) case final away?)
                      side(t.away(n: away), text.bodySmall?.copyWith(color: tokens.textMuted)),
                    if (note != null) side(note, text.bodySmall?.copyWith(color: tokens.textClosed)),
                    side(
                      km?.toStringAsFixed(1) ?? '?',
                      text.bodySmall?.copyWith(
                        color: tier3 ? tokens.textClosed : tokens.textMuted,
                        fontFeatures: tabularFigures,
                      ),
                    ),
                  ],
                ),
                if (saved != null)
                  Text(
                    t.savedAs(line: book.lines[saved] ?? saved),
                    style: text.bodySmall,
                  ),
                // 처음 역으로 돌아온 끝 행은 같은 역이라 글을 붙이지 않는다 (사용자 결정 2026-11-12)
                if (returns == null && line.transfers.isNotEmpty)
                  _Transfers(
                    stop: name,
                    groups: line.transfers,
                    state: state,
                    lines: book.lines,
                    sameCompany: ref.watch(displayRulesProvider).sameCompany,
                    isJr: ref.watch(displayRulesProvider).isJr,
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
  _Entry(this.name, this.station, this.tail, {required this.gone, required this.lineId}) : first = name;

  String name;

  /// 묶기 전 첫 노선 이름. 회사 앞머리를 비교한다.
  final String first;
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
    required this.isJr,
  });

  final String stop;
  final List<TransferGroup> groups;
  final RecordSessionState state;
  final Map<String, String> lines;
  final bool Function(String? a, String? b) sameCompany;
  final bool Function(String? line) isJr;

  /// 다른 이름 역이면 괄호로 적는다 (DESIGN §8.1).
  String _station(SelectorLink link) {
    final other = link.otherNode == null ? '' : state.linkNameOf(link, link.otherNode!);
    return other == stop || other.isEmpty ? '' : '($other)';
  }

  String _lineName(String? id) => lines[id] ?? id ?? '';

  List<_Entry> _entries(BuildContext context, TransferGroup group) {
    final out = <_Entry>[];
    for (final item in group.items) {
      if (item.before.isNotEmpty) continue;
      final link = item.link;
      final other = link.otherNode == null ? '' : state.linkNameOf(link, link.otherNode!);
      final station = other == stop ? '' : other;
      final name = _lineName(link.otherLineId);
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
        // 앞 노선과 같은 회사 앞머리(낱말 단위)는 한 번만 적는다. 「고베 전철 아리마선·고베 고속선」
        same.name = '${same.name}·${isJr(link.otherLineId) ? name : _withoutPrefix(name, same.first)}';
      } else {
        out.add(
          _Entry(name, station, _tail(context, link, gone: item.gone, suspended: item.suspended), gone: item.gone, lineId: link.otherLineId),
        );
      }
    }
    return out;
  }

  /// [first]와 낱말 단위로 겹치는 앞부분을 뗀다. 남는 것이 없으면 그대로다.
  static String _withoutPrefix(String name, String first) {
    final a = name.split(' ');
    final b = first.split(' ');
    var n = 0;
    while (n < a.length - 1 && n < b.length - 1 && a[n] == b[n]) {
      n++;
    }
    return a.sublist(n).join(' ');
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
            '${item.gone ? _tail(context, item.link, gone: true, chained: true, suspended: item.suspended) ?? '' : context.t.session.state.since(year: _year(item.link.validFromLo) ?? '?')}',
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
  const _BranchTile({required this.line, required this.trunk, required this.fromStop});

  final BranchLine line;
  final TrunkPiece? trunk;
  final bool fromStop;

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
    final next = link.nextStop == null ? null : state.linkNameOf(link, link.nextStop!);
    final last = link.terminal == null ? null : state.linkNameOf(link, link.terminal!);
    final arrow = next == null ? null : (last == null || last == next ? next : '$next › $last');
    final at = state.nameOf(line.at.node);
    final other = link.otherNode == null ? '' : state.linkNameOf(link, link.otherNode!);
    final station = other.isEmpty || other == at ? '' : '($other)';
    final tail = archive != null ? context.t.session.state.until(year: archive.closedYear) : _tail(context, link, gone: item.gone, suspended: item.suspended);
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
            fromStop: fromStop,
            endThrough: switch (line.endThrough) {
              null => null,
              true => tokens.selectorGone,
              false => tokens.lineUnridden,
            },
            centerY: centerY,
            fromTrunk: link.midway,
            parallel: line.parallel,
            lanes: line.lanes,
            laneStyle: laneStyleOf(tokens),
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
  const _EndTile({required this.line, required this.fromStop, required this.trunk});

  final EndLine line;
  final bool fromStop;
  final TrunkPiece? trunk;

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
        if (item.link.nextStop != null) state.linkNameOf(item.link, item.link.nextStop!),
    }.toList();
    final where = nexts.length > 1
        ? context.t.session.bound(names: nexts.join('·'))
        : nexts.firstOrNull;
    final session = ref.read(recordSessionProvider.notifier);
    final gone = line.items.every((item) => item.gone);
    final color = gone ? tokens.selectorGoneText : tokens.textMuted;
    // 끝난 이어짐은 분기 줄처럼 끝난 해를 붙인다 (실화면 검수 2026-11-08, 川内의 宮之城線)
    final tail = gone ? _tail(context, first, gone: true, suspended: line.items.first.suspended) : null;
    // 그날(날짜 모름이면 어느 때든) 진행 방향을 바꿔 들어가는 직통(스위치백)이 있던 끝 이어짐이면 점선 왼쪽에 표식을 둔다.
    // 문구는 걸리는 표식 기간이 모두 끝났으면 「있었습니다」다 (11회차 S3)
    final date = state.dateInput == null ? null : DateSpan.parse(state.dateInput!);
    final reverse = [for (final item in line.items) ?reverseOn(item.link, date)];
    final t = context.t.session;
    // 한국어 문구는 조사까지 노선 이름에 붙여 넘긴다(「도호쿠 본선으로」·「모노레일로」)
    final toLine = context.t.$meta.locale == AppLocale.ko ? withKoreanRo(name) : name;
    final mark = reverse.isEmpty
        ? null
        : SwitchbackMark(
            color: color,
            spoken: t.spokenReverse,
            message: reverse.contains(ReverseState.now) ? t.reverseNow(line: toLine) : t.reverseUsed(line: toLine),
          );
    final tile = InkWell(
      onTap: session.canOpen(first.otherLineId)
          ? () async {
              if (await confirmLeave(context, ref)) await session.jumpTo(first, line.at);
            }
          : null,
      child: CustomPaint(
        painter: EndPainter(
          color: gone ? tokens.selectorGone : tokens.lineUnridden,
          up: line.up,
          parallel: line.parallel,
          trunkThrough: line.trunkThrough,
          stackAt: line.stackAt,
          stackOf: line.stackOf,
          fromStop: fromStop,
          trunk: trunk,
          lanes: line.lanes,
          laneStyle: laneStyleOf(tokens),
        ),
        child: ConstrainedBox(
          // 같은 끝의 노선이 여럿이면 목록처럼 촘촘히 쌓는다 (A안)
          constraints: BoxConstraints(minHeight: line.stackOf > 1 && line.stackAt > 0 ? 30 : 48),
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
                  if (tail != null)
                    Text(tail, style: text.bodySmall?.copyWith(fontSize: 11.5, color: color)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (mark == null) return tile;
    // 표식 오른쪽 끝은 점선에서 6 떨어진다. 눌림 영역은 표식과 같은 중심이다
    final dash = trunk == null ? SelectorRuler.trunkX : SelectorRuler.stemX;
    final hit = SwitchbackMark.hitOf(context);
    final center = dash - 6 - SwitchbackMark.sideOf(context) / 2;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        tile,
        Positioned(left: center - hit / 2, top: 0, bottom: 0, width: hit, child: Center(child: mark)),
      ],
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
        painter: PlainPainter(
          above: above,
          below: below,
          node: tokens.textClosed,
          lanes: line.lanes,
          laneStyle: laneStyleOf(tokens),
        ),
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
      painter: PlainPainter(
        above: trunk,
        below: trunk,
        dash: tokens.textClosed,
        lanes: line.lanes,
        laneStyle: laneStyleOf(tokens),
      ),
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
                        line.suspended ? context.t.session.suspendedSection : closedNote(context, year),
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

/// `2024-03-16` → `2024.3.16`. 모르는 자리는 뺀다.
String handDate(String raw) {
  final parts = raw.split('-');
  final out = <String>[parts[0]];
  for (final part in parts.skip(1)) {
    final n = int.tryParse(part);
    if (n == null) break;
    out.add('$n');
  }
  return out.join('.');
}

/// 이관 구간의 경계 (DESIGN §8.0.1 B안). 폐지 구분선과 같은 점선 아래에 한 번만 넘어간 노선과 날을 적는다.
/// 노선 전체가 넘어갔으면 노선 머리의 띠다
class _HandTile extends ConsumerWidget {
  const _HandTile({required this.line, required this.trunk});

  final TransferLine line;
  final TrunkPiece? trunk;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    final t = context.t.session;
    final book = ref.watch(nameBookProvider);
    final session = ref.read(recordSessionProvider.notifier);
    // 돌아오는 곳은 글 없이 점선만 둔다. 점선 구간을 지나면 다시 이 노선인 것이 보인다 (사용자 결정 2026-11-08)
    if (line.back) {
      return _SectionTile(line: SectionLine(gap: line.gap, year: line.closedYear, lanes: line.lanes), trunk: trunk);
    }
    final name = book.lines[line.lineId] ?? line.lineId;
    final label = t.handSince(date: handDate(line.on), line: name);
    final open = session.canOpen(line.lineId);
    Future<void> go() async {
      if (await confirmLeave(context, ref)) await session.jumpToLine(line.lineId, line.at.node);
    }

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        if (line.closedYear case final year?)
          Text(closedNote(context, year), style: text.bodySmall?.copyWith(color: tokens.textClosed)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Expanded(
              child: Text(label, style: text.bodySmall?.copyWith(color: tokens.text, fontWeight: FontWeight.w600)),
            ),
            if (open)
              Text(t.handOpen, style: text.bodySmall?.copyWith(color: tokens.lineRidden)),
          ],
        ),
        Text(t.handNote, style: text.bodySmall?.copyWith(color: tokens.textMuted)),
      ],
    );
    if (line.whole) {
      return InkWell(
        onTap: open ? go : null,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 2, 12, 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: tokens.hairline),
            borderRadius: BorderRadius.circular(12),
          ),
          child: body,
        ),
      );
    }
    return InkWell(
      onTap: open ? go : null,
      child: CustomPaint(
        painter: PlainPainter(
          above: trunk,
          below: trunk,
          dash: tokens.textClosed,
          lanes: line.lanes,
          laneStyle: laneStyleOf(tokens),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(SelectorRuler.textX, 9, 12, 10),
          child: SizedBox(width: double.infinity, child: body),
        ),
      ),
    );
  }
}

/// 이름 뒤의 한 방향 정차 칩. 화살표는 화면의 위아래, 글은 상·하행 이름이다. 하차전용은 화살표 없이 글만이다 (DESIGN §8 한 방향 정차).
class _OneWayChip extends StatelessWidget {
  const _OneWayChip({required this.down, required this.label, required this.muted});

  final bool? down;
  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = muted ? tokens.textClosed : tokens.textMuted;
    // 좁은 폭·큰 글자에서 남은 칸보다 길면(영어) 넘치지 않게 칸에 맞춰 줄인다
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: _chip(context, color),
    );
  }

  Widget _chip(BuildContext context, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: EdgeInsets.fromLTRB(down == null ? 6 : 4, 1, 6, 1),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (down != null) ...[
            Icon(down! ? Icons.south : Icons.north, size: 12, color: color),
            const SizedBox(width: 2),
          ],
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, height: 1.2)),
        ],
      ),
    );
  }
}

/// [tail]이 [head] 마지막 줄의 남은 자리에 통째로 들어가는가. 화면과 같은 글자 배율로 잰다.
bool _fitsAfter(BuildContext context, InlineSpan head, InlineSpan tail, double width, {double extra = 0}) {
  TextPainter paint(InlineSpan span, double max) => TextPainter(
        text: span,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.maybeLocaleOf(context),
      )..layout(maxWidth: max);
  final first = paint(head, width);
  final lines = first.computeLineMetrics();
  final used = (lines.isEmpty ? 0.0 : lines.last.width) + extra;
  first.dispose();
  final second = paint(tail, double.infinity);
  final need = second.width;
  second.dispose();
  return used + need <= width;
}
