import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/session_providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/tokens.dart';
import '../../../i18n/strings.g.dart';
import '../controller/record_session_controller.dart';
import 'fold_view.dart';
import 'one_way_bubble.dart';
import 'session_painters.dart';
import 'switchback_mark.dart';

/// 줄기 칸의 색. 칠하기는 고른 구간, 이미 탄 구간, 영업 상태 순이다.
class TrunkStyle {
  TrunkStyle(this.state, this.ridden, this.tokens, {this.scroll}) : handed = handedGaps(state.lines);

  /// 점선 박자를 목록 전체 위치에 맞추는 목록 스크롤
  final ScrollController? scroll;

  final RecordSessionState state;
  final List<bool> ridden;
  final AppTokens tokens;

  /// 그날 다른 노선으로 기록되는 이관 괄호 안의 칸 번호 (사용자 결정 2026-11-19)
  final Set<int> handed;

  TrunkPiece get tail => TrunkPiece(tokens.selectorGone, SelectorRuler.closedWidth);

  /// 그 자리(첫 역 앞 -1, 끝 역 뒤 = 마지막 역 번호)에 열람 전용 역이 있는가
  bool archiveAt(int gap) => state.lines.any((line) => line is ArchiveLine && line.gap == gap);

  /// 첫 역 앞·끝 역 뒤에는 역 사이 칸이 없다. 그 자리에 열람 전용 역이 있으면 사이 줄(끝 이어짐·구분선)도 폐지 구간 줄기로 잇는다.
  /// 비워 두면 줄기가 구분선에서 끊겨 열람 전용 역 묶음이 노선과 떨어져 보였다 (志度線 瓦町 앞, 2026-11-18 사용자 지적)
  TrunkPiece? beyond(int gap) => (gap < 0 || gap >= state.visible.length - 1) && archiveAt(gap) ? tail : null;

  TrunkPiece? gap(int gap) {
    final rows = state.visible;
    if (gap < 0 || gap >= rows.length - 1) return null;
    final already = gap < ridden.length && ridden[gap];
    final oneWay = gap < state.oneWayGaps.length ? state.oneWayGaps[gap] : null;
    if (state.coversBelow(rows[gap].seq)) {
      return TrunkPiece(tokens.lineRidden, SelectorRuler.openWidth, dashed: !already, oneWay: oneWay, scroll: scroll);
    }
    if (already) {
      return TrunkPiece(tokens.lineRiddenSoft, SelectorRuler.openWidth, oneWay: oneWay);
    }
    // 계절 운행의 비시즌 칸은 닫힌 칸이 아니라 운행하지 않는 날일 뿐이다. 이관 띠처럼 굵은 검은 점선으로 그린다
    final open = gap >= state.openGaps.length || state.openGaps[gap] || handed.contains(gap);
    return open ? TrunkPiece(tokens.text, SelectorRuler.openWidth, handed: handed.contains(gap), oneWay: oneWay, scroll: scroll) : tail;
  }
}

/// 이관 괄호 안의 칸 번호. 괄호 맨 위 역부터 맨 아래 역 앞까지다.
/// 계절 운행의 비시즌 괄호도 같은 굵은 검은 점선 줄기로 그린다(괄호 색만 녹색, 사용자 결정 2026-11-24)
Set<int> handedGaps(List<SelectorLine> lines) {
  final out = <int>{};
  for (final notice in lines.whereType<NoticeLine>()) {
    if (notice.kind != NoticeKind.hand && notice.kind != NoticeKind.season) continue;
    final top = lines.firstWhere(notice.top.matches, orElse: () => notice);
    final bottom = lines.firstWhere(notice.bottom.matches, orElse: () => notice);
    if (top is! StopLine || bottom is! StopLine) continue;
    for (var gap = top.index; gap < bottom.index; gap++) {
      out.add(gap);
    }
  }
  return out;
}

/// 괄호와 안내 상자의 색. 이관은 바탕색에 가까운 베이지, 폐지는 붉은 계열, 운휴는 누런 계열, 개업 전은 회색이다 (사용자 결정 2026-11-19)
({Color bracket, Color box, Color title, Color body}) noticeColors(NoticeKind kind, AppTokens tokens, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return switch (kind) {
    NoticeKind.hand => (
        bracket: tokens.textMuted,
        box: dark ? const Color(0xFF2B2F36) : const Color(0xFFEDE6D8),
        title: tokens.text,
        body: tokens.textMuted,
      ),
    NoticeKind.closed => (
        bracket: dark ? const Color(0xFFD98A80) : const Color(0xFFB9675B),
        box: dark ? const Color(0xFF3A2624) : const Color(0xFFF6E2DD),
        title: dark ? const Color(0xFFFFB3A8) : const Color(0xFF8E3324),
        body: dark ? const Color(0xFFD9A59D) : const Color(0xFF7E4A41),
      ),
    NoticeKind.suspended => (
        bracket: dark ? const Color(0xFFD1A85A) : const Color(0xFFA9802F),
        box: dark ? const Color(0xFF3A3220) : const Color(0xFFF4EBD5),
        title: dark ? const Color(0xFFF0CF8A) : const Color(0xFF7A5512),
        body: dark ? const Color(0xFFCDB487) : const Color(0xFF6E5A35),
      ),
    NoticeKind.before => (
        bracket: tokens.textClosed,
        box: dark ? const Color(0xFF2A2E33) : const Color(0xFFECEAE4),
        title: tokens.text,
        body: tokens.textMuted,
      ),
    // 계절 운행의 비시즌은 녹색 계열이다(폐지·운휴와 구분, 사용자 결정 2026-11-24)
    NoticeKind.season => (
        bracket: dark ? const Color(0xFF7FBF8E) : const Color(0xFF3F8A55),
        box: dark ? const Color(0xFF1F3326) : const Color(0xFFE1F0E4),
        title: dark ? const Color(0xFFA8DDB4) : const Color(0xFF235C33),
        body: dark ? const Color(0xFF9CC4A6) : const Color(0xFF3E6A4A),
      ),
  };
}

/// 줄마다 걸리는 괄호 토막. 안내 줄이 가리키는 맨 위 줄부터 맨 아래 줄까지다
List<List<BracketPiece>> bracketPieces(List<SelectorLine> lines, AppTokens tokens, Brightness brightness, {bool Function(NoticeLine notice)? only}) {
  final out = List.generate(lines.length, (_) => <BracketPiece>[]);
  for (final notice in lines.whereType<NoticeLine>()) {
    if (only != null && !only(notice)) continue;
    final top = lines.indexWhere(notice.top.matches);
    final bottom = lines.indexWhere(notice.bottom.matches);
    if (top < 0 || bottom <= top) continue;
    final color = noticeColors(notice.kind, tokens, brightness).bracket;
    for (var i = top; i <= bottom; i++) {
      out[i].add(BracketPiece(color: color, start: i == top, end: i == bottom));
    }
  }
  return out;
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
  const SessionLineTile({super.key, required this.line, this.prev, required this.next, required this.trunk, this.brackets = const [], this.mainBrackets = const [], this.foldBracket});

  /// 이 줄에 걸치는 접힌 선형의 괄호 토막 (DESIGN §8.3)
  final ({List<BracketPiece> pieces, double? nodeY, double reach})? foldBracket;

  /// 접힌 선형 안 줄에 걸치는 본선 괄호 토막. 접힌 선형 칸으로 옮기지 않고 제자리에 그린다 (DESIGN §8.3)
  final List<BracketPiece> mainBrackets;

  final SelectorLine line;

  /// 이 줄에 걸리는 괄호 토막 (사용자 결정 2026-11-19)
  final List<BracketPiece> brackets;
  final SelectorLine? prev;
  final SelectorLine? next;

  /// 역 바로 옆 줄인지. 위로 가는 줄은 아래 이웃이, 아래로 가는 줄은 위 이웃이 역이다
  bool _fromStop(bool up) => (up ? next : prev) is StopLine;
  final TrunkStyle trunk;

  @override
  Widget build(BuildContext context) {
    var tile = _tile(context);
    final inFold = FoldView.of(context)?.ctx.containsKey(line) ?? false;
    // 접힌 선형 안의 분기·끝 이어짐·안내 줄은 글자까지 통째로 선형 칸으로 옮긴다 (목업과 같다). 역 줄은 그림만 옮기고 글자는 본선 역과 같은 줄이다
    final padded = inFold && foldPadded(line);
    if (brackets.isNotEmpty && line is! StopLine) {
      final overlay = BracketOverlay(brackets, nodeY: line is ArchiveLine ? 18 : null);
      tile = CustomPaint(foregroundPainter: inFold && !padded ? FoldPainter(overlay, ctx: null, centerY: 24, shiftOnly: true) : overlay, child: tile);
    }
    if (padded) tile = Padding(padding: const EdgeInsets.only(left: foldTextShift), child: tile);
    if (mainBrackets.isNotEmpty) tile = CustomPaint(foregroundPainter: BracketOverlay(mainBrackets), child: tile);
    final fb = foldBracket;
    return fb == null ? tile : CustomPaint(foregroundPainter: FoldBracketOverlay(fb.pieces, nodeY: fb.nodeY, reach: fb.reach), child: tile);
  }

  Widget _tile(BuildContext context) => switch (line) {
        final StopLine stop => _StopTile(
            brackets: brackets,
            line: stop,
            above: trunk.gap(stop.index - 1) ?? (stop.index == 0 && prev is ArchiveLine ? trunk.tail : trunk.beyond(stop.index - 1)),
            below: trunk.gap(stop.index) ?? (next is ArchiveLine ? trunk.tail : trunk.beyond(stop.index)),
          ),
        final BranchLine branch => _BranchTile(line: branch, trunk: trunk.gap(branch.gap) ?? trunk.beyond(branch.gap), fromStop: _fromStop(branch.up)),
        final EndLine end => _EndTile(line: end, fromStop: _fromStop(end.up), trunk: trunk.gap(end.gap) ?? trunk.beyond(end.gap)),
        final ArchiveLine archive => _ArchiveTile(
            line: archive,
            // 첫 역 앞(-1)의 열람 전용 역은 위로 잇는 것이 없고 아래 첫 역으로 이어진다 (10회차 G1 chugoku_shikoku_2-003)
            above: archive.gap < 0 ? (prev is ArchiveLine ? trunk.tail : null) : trunk.gap(archive.gap) ?? trunk.tail,
            below: archive.gap < 0 ? trunk.tail : trunk.gap(archive.gap) ?? (next is ArchiveLine ? trunk.tail : null),
          ),
        // 열람 전용 역 묶음 바깥(맨 위) 구분선은 줄기를 긋지 않는다. 묶음과 역 사이 구분선만 잇는다
        final SectionLine section => _SectionTile(
            line: section,
            trunk: trunk.gap(section.gap) ?? (prev is ArchiveLine || (next is ArchiveLine && prev != null) ? trunk.beyond(section.gap) : null),
          ),
        final TransferLine hand => _HandTile(line: hand, trunk: trunk.gap(hand.gap)),
        final NoticeLine notice => _NoticeTile(line: notice, prev: prev, trunk: trunk),
        final FoldLine fold => FoldHeadTile(line: fold, trunk: trunk.gap(_anchorIndex(fold)), next: next, prev: prev),
      };

  /// 접힌 줄 머리 자리의 본선 칸: 아래로 붙으면 붙는 역 아래 칸, 위로 붙으면 위 칸
  int _anchorIndex(FoldLine fold) {
    final at = trunk.state.visible.indexWhere((row) => row.seq == fold.fold.anchor);
    return fold.fold.up ? at - 1 : at;
  }
}

class _StopTile extends ConsumerWidget {
  const _StopTile({required this.line, required this.above, required this.below, this.brackets = const []});

  final StopLine line;
  final List<BracketPiece> brackets;
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
  void _whyNot(BuildContext context, RecordSessionState state) {
    final t = context.t.session;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        // 임시 운행만 있는 계통은 폐지·운휴가 아니라 그날 임시 열차가 없던 것이다 (사용자 결정 2026-11-19)
        content: Text(line.row.viewOnly
            ? (line.row.noBoarding
                ? t.whyViewNoBoarding
                : line.row.staffOnly
                    ? t.whyViewStaff
                    : t.whyViewSignal)
            : state.isTemporary
                ? t.tempNoRun
                : line.row.state == StopState.suspended
                    ? t.whySuspended
                    : t.whyClosed),
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
    // 역은 있으나 그날 이 계통이 서지 않는 끝 노드: 보통 역 모양에 「승하차 불가」 (결정 A 추천안, 2026-11-21)
    if (row.noBoarding) return context.t.session.spokenPassing;
    // 그날 신호장·분기점으로 지나는 행(회색)은 역 정차가 끝난 해를 붙이지 않는다. 신호장이 없어지면 그때 폐지 해가 붙는다
    if (row.passing) return null;
    return switch (row.state) {
      StopState.maybe => t.maybe,
      StopState.beforeOpen => t.since(year: row.openYear ?? '?'),
      // 운휴는 시작 해를 붙인다(폐역 「~해」와 짝). 역 정차만 운휴인 곳(全列車通過, 羽前前波)도 같다 (사용자 결정 2026-11-16)
      StopState.suspended => row.suspendedSince == null ? t.suspended : t.suspendedSince(year: row.suspendedSince!),
      StopState.offSeason => t.offSeason,
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
    // 보이기만 하는 행(그날 끝이 아닌 신호장·승하차 불가 역)은 고를 수 없어도 흐리게 그리지 않는다
    final tier3 = !row.selectable && !row.viewOnly;
    // 임시 운행만 있는 계통: 운행일이 아닌 날의 역은 영업 역과 같은 크기의 흐린 원·흐린 이름이다(폐역의 작은 원·「~해」와 다르다).
    // 끝난 해·운휴 표시는 어느 날에도 붙이지 않는다 (사용자 결정 2026-11-19, 목업 5판)
    final temp = state.isTemporary;
    final fade = temp && tier3;
    final rowHeight = line.small ? 32.0 : (tier3 && !fade ? 40.0 : 48.0);
    final style = fade
        ? text.titleMedium?.copyWith(fontWeight: FontWeight.w500, color: tokens.textMuted)
        : tier3
        ? closedNameStyle(text, tokens)
        : text.titleMedium?.copyWith(fontWeight: end ? FontWeight.w700 : FontWeight.w500, color: tokens.text);
    final nameLocale = japaneseOnlyLocale(name0: state.nameOf(row.node));
    final scaler = MediaQuery.textScalerOf(context);
    final lineHeight = scaler.scale((style?.fontSize ?? 16) * (style?.height ?? 1.3));
    final top = ((rowHeight - lineHeight) / 2).clamp(2.0, 24.0);
    final centerY = top + lineHeight / 2;
    final note = temp ? null : _note(context);
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
    final circle = archived ? 3.5 : (tier3 && !fade ? 4.5 : 8.5);
    // 접힌 선형 안 역은 고를 수 있어도(날짜 모름) 분기선과 같은 짙은 회색 테다 (DESIGN §8.3)
    final inFold = FoldView.of(context)?.ctx.containsKey(line) ?? false;
    final ring = end || picked || mark != StationMark.none
        ? tokens.lineRidden
        : (tier3 ? tokens.textClosed : (inFold ? tokens.lineUnridden : tokens.text));
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
      if (!temp && row.closeYear != null && row.handedTo == null)
        t.spokenClosed(year: row.closeYear!)
      else if (row.passing || row.noBoarding)
        t.spokenPassing
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
        onTap: row.selectable ? () => _tap(context, ref, state) : () => _whyNot(context, state),
        child: CustomPaint(
          painter: foldPaint(context, line, StopPainter(
            brackets: brackets,
            lanes: line.lanes,
            laneStyle: laneStyleOf(tokens),
            endUp: switch (line.endUp) {
              null => null,
              true when !temp => tokens.selectorGone,
              _ => tokens.lineUnridden,
            },
            endDown: switch (line.endDown) {
              null => null,
              true when !temp => tokens.selectorGone,
              _ => tokens.lineUnridden,
            },
            centerY: centerY,
            above: above,
            below: below,
            ring: ring,
            // 승하차 불가 끝 노드(분기점·신호장, 그날 서지 않는 계통 끝 역)는 같은 크기·모양에 가운데만 회색이다 (junction-nodes-rule)
            fill: archived
                ? tokens.textClosed
                : (end || mark == StationMark.stepped ? tokens.lineRidden : (row.passing ? tokens.textClosed : tokens.surface)),
            background: tokens.surface,
            radius: circle,
            ringWidth: tier3 && !fade ? 2 : 3.5,
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
                : foldShoulder(context, line, up: true),
            stemDown: line.branchDown
                ? (line.branchDownGone ? tokens.selectorGone : tokens.lineUnridden)
                : foldShoulder(context, line, up: false),
          ), centerY: centerY),
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
                            TextSpan(text: name, style: nameLocale == null ? style : japaneseStyle(style), locale: nameLocale),
                            if (past != null) TextSpan(text: ' ${past.label}', style: text.labelSmall),
                          ]),
                          TextSpan(text: '  ${kinsoku(aside)}', style: japaneseStyle(asideStyle), locale: const Locale('ja')),
                          box.maxWidth,
                          // 한 방향 칩은 글자 폭으로 잴 수 없어 넉넉히 더한다
                          extra: oneWay == null ? 0 : 72 * MediaQuery.textScalerOf(context).scale(1),
                        );
                        return Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: nameLocale == null ? name : kinsoku(name), style: nameLocale == null ? style : japaneseStyle(style), locale: nameLocale),
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
                                text: besideName ? '  ${kinsoku(aside)}' : '\n${kinsoku(aside)}',
                                locale: const Locale('ja'),
                                style: japaneseStyle(asideStyle),
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
                        // 이관 띠 안 역의 km는 이어받은 노선의 km라 흐리게 적는다 (DESIGN §8.3)
                        color: tier3 || state.foreignKm.contains(row.seq) ? tokens.textClosed : tokens.textMuted,
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
                // 이름까지 바뀐 옛 자리는 역명 바로 아래·환승 목록 위에 「~년 ~로 이전」 (사용자 결정 2026-11-18)
                if (state.movedNotes[row.node] case final moved?)
                  Text(
                    t.movedTo(year: moved.year, name: koDirectional(context, moved.name)),
                    style: text.bodySmall?.copyWith(color: tier3 ? tokens.textClosed : tokens.textMuted),
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
          state.isTemporary
              ? _Entry(name, station, null, gone: false, lineId: link.otherLineId)
              : _Entry(name, station, _tail(context, link, gone: item.gone, suspended: item.suspended), gone: item.gone, lineId: link.otherLineId),
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
    // 옛 이름은 노선 이름과 같은 크기로 적는다(위아래 줄 글자 크기가 달라 보이던 것, 실화면 2026-11-19)
    final oldHeight = MediaQuery.textScalerOf(context).scale(19);
    final centerY = 24.0 + item.before.length * oldHeight;
    return Semantics(
      container: true,
      button: true,
      label: context.t.session.spokenBranch(line: name, next: arrow ?? ''),
      excludeSemantics: true,
      child: InkWell(
        onTap: () => _open(context, ref, name),
        child: CustomPaint(
          painter: foldPaint(context, line, BranchPainter(
            goneColor: tokens.selectorGone,
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
          ), centerY: centerY, branchY: centerY),
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
                        style: text.bodyMedium?.copyWith(fontSize: 13, color: tokens.selectorGoneText),
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
    // 임시 운행만 있는 계통의 끝 이어짐(직통)은 상대 노선이 살아 있으면 어느 날에도 살아 있게 그린다 (사용자 결정 2026-11-19)
    final gone = !state.isTemporary && line.items.every((item) => item.gone);
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
        painter: foldPaint(context, line, EndPainter(
          // 묶음의 선은 그 묶음에 현행이 하나라도 있으면 현행색 하나로 옅어진다. 글줄(번호·이름)은 줄마다 제 색이다 (사용자 결정 2026-11-20)
          color: (line.stackOf > 1 ? !line.stackLive : gone) ? tokens.selectorGone : tokens.lineUnridden,
          up: line.up,
          parallel: line.parallel,
          trunkThrough: line.trunkThrough,
          stackAt: line.stackAt,
          stackOf: line.stackOf,
          fromStop: fromStop,
          trunk: trunk,
          lanes: line.lanes,
          laneStyle: laneStyleOf(tokens),
        )),
        child: ConstrainedBox(
          // 같은 끝의 노선이 여럿이면 목록처럼 촘촘히 쌓는다 (A안)
          // 같은 끝의 직통이 여럿이면 줄마다 속이 찬 번호를 붙이고, 번호 옆 스위치백 표식과 헷갈리지 않게 줄 간격을 넉넉히 둔다 (사용자 결정 2026-11-19)
          constraints: const BoxConstraints(minHeight: 48),
          child: line.stackOf > 1
              ? Stack(
                  // 글줄이 줄 높이(48) 안에서 가운데에 오게 제약을 그대로 넘긴다. 번호도 같은 가운데다
                  fit: StackFit.passthrough,
                  children: [
                    Positioned(
                      left: SelectorRuler.textX - 27,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Container(
                          width: 18,
                          height: 18,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: gone ? tokens.selectorGoneText : tokens.textMuted),
                          // 원 크기가 고정이라 숫자도 글자 크기 설정을 따르지 않는다(환승 캡슐 번호와 같다). 큰 글자에서 숫자가 원 밖으로 잘렸다 (실화면 2026-11-19)
                          child: Text(
                            '${line.stackAt + 1}',
                            textScaler: TextScaler.noScaling,
                            style: text.labelSmall?.copyWith(fontSize: 11, height: 1, fontWeight: FontWeight.w700, color: tokens.surface),
                          ),
                        ),
                      ),
                    ),
                    _endText(context, text, tokens, book.lines, name, where, tail, color),
                  ],
                )
              : _endText(context, text, tokens, book.lines, name, where, tail, color),
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

  Widget _endText(BuildContext context, TextTheme text, AppTokens tokens, Map<String, String> lineNames, String name, String? where, String? tail, Color color) =>
      Padding(
            padding: const EdgeInsets.fromLTRB(SelectorRuler.textX, 0, 12, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              // 이어받기 전 노선(같은 사슬)은 같은 줄 묶음 안에서 바로 위에 이름과 끝난 해만 적는다. 간격 없이 붙여 한 노선의 이어짐으로 읽힌다
              // (佐世保: 松浦線 ~1988 / 松浦鉄道西九州線 ~2020 → 환승, 사용자 결정 2026-11-19)
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final old in line.items.first.before)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${lineNames[old.otherLineId] ?? old.otherLineId ?? ''}  ${_tail(context, old, gone: true) ?? ''}',
                        style: text.bodyMedium?.copyWith(fontSize: 13, color: tokens.selectorGoneText),
                      ),
                    ),
                  // 폭이 모자라면 방면 역·노선 이름을 말줄임하고 끝난 해는 끝까지 보인다 (실화면 2026-11-19)
                  // 끝난 해는 끝까지 보이고, 모자라면 방면 역부터, 그다음 노선 이름을 말줄임한다.
                  // 끝 글자는 줄 폭의 60%까지만 차지해 아주 좁거나 글자가 클 때도 넘치지 않는다 (실화면 2026-11-19)
                  LayoutBuilder(
                    builder: (context, box) => Row(
                      spacing: 10,
                      children: [
                        // 노선 이름과 방면 역을 한 글줄로 이어 남는 폭을 다 쓰고, 넘치면 끝(방면 역)부터 말줄임한다.
                        // 비율로 폭을 나누면 자리가 남아도 방면 역이 일찍 잘린다 (실화면 2026-11-19 新潟)
                        Flexible(
                          child: Text.rich(
                            TextSpan(
                              style: text.bodyMedium?.copyWith(fontSize: 13, color: color),
                              children: [
                                TextSpan(text: name),
                                if (where != null) ...[
                                  const WidgetSpan(child: SizedBox(width: 10)),
                                  TextSpan(text: where, style: text.bodySmall?.copyWith(fontSize: 11.5, color: color)),
                                ],
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            // 말줄임한 글의 실제 폭만 차지한다. 부모 폭을 다 잡으면 꼬리(끝 역) 앞에 빈칸이 벌어진다
                            textWidthBasis: TextWidthBasis.longestLine,
                          ),
                        ),
                        if (tail != null)
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: box.maxWidth * .6),
                            child: Text(tail, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall?.copyWith(fontSize: 11.5, color: color)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
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
    final aside = state.archiveAside[stop.id];
    final year = context.t.session.state.until(year: stop.closedYear);
    final now = state.archiveNow[stop.id];
    final message = now == null
        ? context.t.session.archiveStop(name: name, year: stop.closedYear)
        : context.t.session.archiveStopNow(name: name, year: stop.closedYear, now: now);
    final km = stop.km;
    final style = closedNameStyle(text, tokens);
    return InkWell(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), persist: false),
      ),
      child: CustomPaint(
        painter: foldPaint(context, line, PlainPainter(
          above: above,
          below: below,
          node: tokens.textClosed,
          lanes: line.lanes,
          laneStyle: laneStyleOf(tokens),
        )),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(SelectorRuler.textX, 8, 12, 8),
            child: Row(
              spacing: 10,
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: name,
                        style: japaneseOnlyLocale(name0: name) == null ? style : japaneseStyle(style),
                        locale: japaneseOnlyLocale(name0: name),
                      ),
                      if (aside != null)
                        TextSpan(text: '  ${kinsoku(aside)}', style: japaneseStyle(text.bodySmall?.copyWith(color: tokens.textClosed)), locale: const Locale('ja')),
                    ]),
                  ),
                ),
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
      painter: foldPaint(context, line, PlainPainter(
        above: trunk,
        below: trunk,
        dash: tokens.textClosed,
        lanes: line.lanes,
        laneStyle: laneStyleOf(tokens),
        stem: switch (line.stem) { null => null, true => tokens.selectorGone, false => tokens.lineUnridden },
        stemUp: line.gap < 0,
      )),
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
                        line.suspended
                            ? context.t.session.suspendedSection
                            : line.opens != null
                                ? context.t.session.openedSection(year: line.opens!)
                                : closedNote(context, year),
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
        painter: foldPaint(context, line, PlainPainter(
          above: trunk,
          below: trunk,
          dash: tokens.textClosed,
          lanes: line.lanes,
          laneStyle: laneStyleOf(tokens),
        )),
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
/// 기록할 수 없는 폐역 줄과 열람 전용 역 줄의 이름은 같은 글자다. 예전에는 역 줄 16px·열람 전용 줄 14px로 갈려
/// 한 노선 일람에서 폐역 글씨 크기가 제각각이었다 (西鉄 甘木線 将軍梅前·富安, 사용자 지적 2026-11-18)
TextStyle? closedNameStyle(TextTheme text, AppTokens tokens) =>
    text.titleMedium?.copyWith(fontWeight: FontWeight.w400, color: tokens.textClosed);

final _hangul = RegExp(r'[\uAC00-\uD7A3\u3131-\u318E]');
final _kanjiKana = RegExp(r'[\u3040-\u30FF\u3400-\u9FFF]');

/// 한국어·영어 이름이 없어 일본어 표기 그대로 보이는 이름은 일본어 글꼴 모양으로 그린다. 앱 글꼴(Pretendard)에 한자가 없어
/// 로캘 없이 그리면 시스템 대체 글꼴(중국어 모양)이 골라져 한글 이름보다 크고 모양이 다르다 (2026-11-18)
Locale? japaneseOnlyLocale({required String name0}) =>
    _kanjiKana.hasMatch(name0) && !_hangul.hasMatch(name0) ? const Locale('ja') : null;

/// 일본어 줄머리 금칙: 작은 가나·장음·닫는 부호 앞에서는 줄을 바꾸지 않는다(「たばたしんごうじ|ょう」 금지, 5회차 2026-11-26).
/// 줄 안에서는 여전히 글자가 차는 대로 끊고(사용자 결정 2026-11-16), 금칙 글자만 앞 글자에 붙인다. 글자 사이에 폭 없는 이음표(U+2060)를 넣는다
final _kinsokuHead = RegExp(r'(?=[ぁぃぅぇぉっゃゅょゎゕゖァィゥェォッャュョヮヵヶㇰ-ㇿー々ゝゞヽヾ・、。，．）」』】〕〉》！？])');
String kinsoku(String s) => s.replaceAll(_kinsokuHead, '\u2060');

/// 일본어 글자(일본어로만 보이는 이름, 이름 옆 일본어·읽기)는 한 일본어 글꼴로, 한글과 같아 보이는 크기로 그린다.
/// 앱 글꼴 Pretendard에는 한국 표준 한자(KS X 1001)만 있어, 競·馬·場·前은 Pretendard 한자(한글과 같은 크기, 약 0.87em)로,
/// 将·国·蛍 같은 일본 신자체는 시스템 일본어 글꼴(1em)로 섞여 그려졌다. 그래서 같은 일본어 이름인 競馬場前과 将軍梅前의 크기가 달랐다
/// (西鉄 甘木線, 사용자 지적 2026-11-18: 일본어만 있는 이름은 한국어 역 이름과 같은 크기). 줄 높이는 원래 글자와 같게 두어 줄기 정렬이 그대로다
const _jaScale = 0.875;
TextStyle? japaneseStyle(TextStyle? base) {
  if (base == null) return null;
  final size = base.fontSize ?? 14;
  return base.copyWith(
    fontFamily: 'Hiragino Sans',
    fontFamilyFallback: const ['Hiragino Kaku Gothic ProN', 'Noto Sans CJK JP', 'Noto Sans JP'],
    fontSize: size * _jaScale,
    height: (base.height ?? 1.3) / _jaScale,
  );
}

/// 한국어판에서 이름 뒤 방향 조사(로/으로). 끝 글자에 받침이 있고 ㄹ이 아니면 「으로」다(신주쿠역으로·니가타로). 다른 언어는 이름 그대로
String koDirectional(BuildContext context, String name) {
  if (Localizations.localeOf(context).languageCode != 'ko' || name.isEmpty) return name;
  final c = name.codeUnitAt(name.length - 1);
  if (c < 0xAC00 || c > 0xD7A3) return '$name(으)로';
  final jong = (c - 0xAC00) % 28;
  return jong == 0 || jong == 8 ? '$name로' : '$name으로';
}

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

/// 괄호 맨 위 역 바로 아래의 안내 상자 (사용자 결정 2026-11-19). 이관이면 넘어간 날과 노선, 「노선 보기」, 그 노선으로 기록된다는 말을,
/// 폐지·운휴·개업 전이면 그 해와 기록할 수 있는 날짜를 적는다. 줄기는 상자 왼쪽으로 그대로 지나간다
class _NoticeTile extends ConsumerWidget {
  const _NoticeTile({required this.line, required this.prev, required this.trunk});

  final NoticeLine line;
  final SelectorLine? prev;
  final TrunkStyle trunk;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    final t = context.t.session;
    final colors = noticeColors(line.kind, tokens, Theme.of(context).brightness);
    final book = ref.watch(nameBookProvider);
    final session = ref.read(recordSessionProvider.notifier);
    final lineId = line.lineId;
    final year = line.year ?? '?';
    final title = switch (line.kind) {
      NoticeKind.hand => t.handSince(date: handDate(line.on ?? ''), line: book.lines[lineId] ?? lineId ?? ''),
      NoticeKind.closed => closedNote(context, year),
      NoticeKind.suspended => line.year == null ? t.suspendedSection : t.state.suspendedSince(year: line.year!),
      NoticeKind.before => t.openedSection(year: year),
      NoticeKind.season => t.seasonSection,
    };
    final body = switch (line.kind) {
      NoticeKind.hand => t.handNote,
      NoticeKind.closed => t.noticeClosedSub,
      NoticeKind.suspended => t.noticeSuspendedSub,
      NoticeKind.before => t.noticeBeforeSub,
      NoticeKind.season => () {
          final months = year.split('-');
          String month(String m) {
            final n = int.tryParse(m) ?? 0;
            if (Localizations.localeOf(context).languageCode != 'en' || n < 1 || n > 12) return m;
            return const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][n - 1];
          }
          return line.anyDate ? t.noticeSeasonAnySub(from: month(months.first), to: month(months.last)) : t.noticeSeasonSub(from: month(months.first), to: month(months.last));
        }(),
    };
    final open = lineId != null && session.canOpen(lineId);
    Future<void> go() async {
      final at = line.at;
      if (lineId == null || at == null) return;
      if (await confirmLeave(context, ref)) await session.jumpToLine(lineId, at.node);
    }

    // 상자는 괄호 맨 위 역 아래 칸에 놓이므로 그 칸의 줄기를 긋는다. 바로 위 줄(접힌 줄 머리 등)과 상관없이 괄호의 맨 위 역으로 칸을 찾는다.
    // 접힌 선형 안 상자는 그 선형의 칸이고, 맨 위가 붙는 역이면 머리 쪽 칸이다 (DESIGN §8.3)
    final style = trunk;
    final top = line.top.seq;
    int? gap;
    if (style is FoldTrunk) {
      final rows = (style.fold.fold.frame ?? style.fold.fold.rows).rows;
      final at = rows.indexWhere((row) => row.seq == top);
      gap = at >= 0 ? at : null;
    } else {
      final at = style.state.visible.indexWhere((row) => row.seq == top);
      gap = at >= 0
          ? at
          : switch (prev) {
              StopLine(:final index) => index,
              BranchLine(:final gap) => gap,
              EndLine(:final gap) => gap,
              _ => null,
            };
    }
    final piece = gap == null ? null : trunk.gap(gap);
    return CustomPaint(
      painter: foldPaint(context, line, PlainPainter(above: piece, below: piece, lanes: line.lanes, laneStyle: laneStyleOf(tokens))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(SelectorRuler.textX - 12, 6, 12, 8),
        child: InkWell(
          onTap: open ? go : null,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
            decoration: BoxDecoration(color: colors.box, borderRadius: BorderRadius.circular(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 3,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    Expanded(child: Text(title, style: text.bodySmall?.copyWith(color: colors.title, fontWeight: FontWeight.w700))),
                    if (open) Text(t.handOpen, style: text.bodySmall?.copyWith(color: tokens.lineRidden)),
                  ],
                ),
                Text(body, style: text.bodySmall?.copyWith(color: colors.body)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
