import '../date/date_rules.dart';
import '../date/date_span.dart';
import 'line_stitch.dart';
import 'network.dart';
import 'selector.dart';

/// 열람 전용 역 (DESIGN §4.5). 기록할 수 없고 자리만 보여 준다.
final class ArchiveStop {
  const ArchiveStop({
    required this.id,
    required this.afterNode,
    required this.beforeNode,
    required this.closedYear,
    required this.km,
    this.seq,
  });

  final String id;
  final String? afterNode;
  final String? beforeNode;
  final String closedYear;
  final double? km;

  /// 그 계통 진행 방향의 순번(archive_stop.seq, DESIGN §4.5). 같은 자리에 여럿이면 이 순서다. 옛 팩에는 없다.
  final int? seq;

  /// km만 옮긴 열람 전용 역 (같은 노선 이어 그리기에서 그날 영업거리로 옮길 때, DESIGN §8.3)
  ArchiveStop shifted(double by) =>
      ArchiveStop(id: id, afterNode: afterNode, beforeNode: beforeNode, closedYear: closedYear, km: km == null ? null : ((km! + by) * 10).roundToDouble() / 10, seq: seq);
}

/// 열람 전용 노선. 역에서 갈라지는 줄로만 보인다.
final class ArchiveBranch {
  const ArchiveBranch({required this.id, required this.atNode, required this.closedYear});

  final String id;
  final String atNode;
  final String closedYear;
}

/// 체크박스 값. 앱 설정과 하나다 (DESIGN §8).
final class DisplayOptions {
  const DisplayOptions({
    this.showClosed = true,
    this.showArchive = true,
    this.showBranches = true,
    this.carryover = true,
  });

  final bool showClosed;
  final bool showArchive;
  final bool showBranches;

  /// 사업자가 바뀌어도 탄 기록을 이어 간다 (DESIGN §2.8 E).
  final bool carryover;
}

/// 줄 하나에 그릴 연결.
final class DisplayLink {
  const DisplayLink({
    required this.link,
    required this.gone,
    this.before = const [],
    this.suspended = false,
  });

  final SelectorLink link;

  /// 3단계로 그린다. 지금은 없거나 그날 없던 노선이다.
  final bool gone;

  /// 연결이 끝난 날부터 상대 노선의 그 역 칸이 운휴 중이다(폐지가 아님). 「~연도」 대신 「운휴 중」으로 적는다
  /// (外房線 大原의 いすみ線 2024~, 米坂線·肥薩線. 10회차 G1 kanto_3-007)
  final bool suspended;

  /// 같은 자리를 이어받기 전 노선. 선 없이 이름만 위에 적는다.
  final List<SelectorLink> before;
}

enum TransferFlow { through, up, down, unknown }

/// 세로선 모양이 같은 환승 노선 묶음. 점 하나가 된다.
final class TransferGroup {
  const TransferGroup({required this.flow, required this.items, this.number});

  final TransferFlow flow;
  final List<DisplayLink> items;

  /// 묶음이 둘 이상일 때만 있다. 종류에 고정이고 없는 종류는 건너뛴다 (DESIGN §2.9 환승 번호).
  final int? number;

  bool get gone => items.every((item) => item.gone);
}

/// 선택기의 한 줄 (DESIGN §8.1). 역과 분기가 각각 독립된 줄이다.
/// 병주 구간 한 토막 (DESIGN §8.1). 이 계통의 [fromSeq]~[toSeq]를 상대 노선이 같은 선로 시설로 함께 달린다.
/// 상대가 바깥에서 들어오거나 나가면 그쪽 이웃 정차역과 방면 끝 역이 있다.
final class ParallelRun {
  const ParallelRun({
    required this.otherLineId,
    required this.fromSeq,
    required this.toSeq,
    this.otherRouteId,
    this.stopSeqs = const {},
    this.inNext,
    this.inTerminal,
    this.outNext,
    this.outTerminal,
    this.validFromLo,
    this.validToHi,
  });

  final String otherLineId;
  final String? otherRouteId;
  final int fromSeq;
  final int toSeq;

  /// 상대 노선도 서는 역의 순번. 가는 선 위에 작은 점을 찍는다.
  final Set<int> stopSeqs;
  final String? inNext;
  final String? inTerminal;
  final String? outNext;
  final String? outTerminal;
  final String? validFromLo;
  final String? validToHi;

  /// 순번만 바꾼 병주 (같은 노선 이어 그리기에서 새 seq로 옮길 때, DESIGN §8.3)
  ParallelRun withSeqs(int from, int to, Set<int> stops) => ParallelRun(
        otherLineId: otherLineId,
        fromSeq: from,
        toSeq: to,
        otherRouteId: otherRouteId,
        stopSeqs: stops,
        inNext: inNext,
        inTerminal: inTerminal,
        outNext: outNext,
        outTerminal: outTerminal,
        validFromLo: validFromLo,
        validToHi: validToHi,
      );
}

/// 병주 선이 그 줄에서 하는 일.
enum LaneRole {
  /// 그대로 지나간다.
  pass,

  /// 지나가며 상대도 서는 역이다. 점을 찍는다.
  stop,

  /// 상대의 기점이다. 역 노드에서 나온다.
  startNode,

  /// 상대의 종점이다. 역 노드로 들어간다.
  endNode,
}

/// 줄 하나를 지나는 병주 선. [lane]은 줄기에서 바깥으로 센 자리다.
final class LaneMark {
  const LaneMark(this.lane, this.role, {this.gone = false});

  final int lane;
  final LaneRole role;
  final bool gone;
}

sealed class SelectorLine {
  const SelectorLine({this.lanes = const []});

  /// 이 줄을 지나는 병주 선 (DESIGN §8.1).
  final List<LaneMark> lanes;
}

/// 역 줄. [index]는 보이는 역 사이에서의 순번이고 줄기 칸의 번호다.
final class StopLine extends SelectorLine {
  const StopLine({
    required this.index,
    required this.row,
    required this.transfers,
    required this.branchUp,
    required this.branchDown,
    required this.small,
    this.branchUpGone = false,
    this.branchDownGone = false,
    this.quiet = false,
    this.returnsTo,
    this.endUp,
    this.endDown,
    super.lanes,
  });

  final int index;
  final SelectorRow row;
  final List<TransferGroup> transfers;
  final bool branchUp;
  final bool branchDown;

  /// 폐역을 꺼도 현행 분기 때문에 남은 작은 노드다.
  final bool small;

  /// 그 쪽 분기가 모두 폐선이다. 어깨 곡선을 흐리게 그린다.
  final bool branchUpGone;
  final bool branchDownGone;

  /// 폐지 구간 안에서 구분선과 같은 해에 폐역됐다. 연도를 또 적지 않는다.
  final bool quiet;

  /// 순환의 마지막 줄이다. 이 역으로 돌아온다.
  final String? returnsTo;

  /// 이 역에서 줄기가 다른 노선으로 이어진다(끝 이어짐). 값은 모두 폐선인가다.
  /// 줄기는 이 역 줄 안에서 실선으로 조금 나간 뒤 끝 이어짐 줄에서 점선이 된다 (병주 선과 같은 길이)
  final bool? endUp;
  final bool? endDown;
}

/// 분기 줄. [gap]번째 역과 그다음 역 사이에 놓인다.
final class BranchLine extends SelectorLine {
  const BranchLine({
    required this.gap,
    required this.at,
    required this.item,
    required this.up,
    required this.stacked,
    this.stemGone = false,
    this.throughGone = false,
    this.archive,
    this.parallel,
    this.endThrough,
    super.lanes,
  });

  final int gap;
  final SelectorRow at;
  final DisplayLink item;
  final bool up;

  /// 같은 쪽 끝 너머에 끝 이어짐이 있어 줄기 점선이 이 줄을 곧게 지나간다. 분기만 오른쪽으로 꺾는다 (倶利伽羅). 값은 이어짐이 모두 폐선인가다
  final bool? endThrough;

  /// 같은 쪽의 줄이 더 바깥에 있어 줄기가 이어진다.
  final bool stacked;

  /// 역에서 이 줄까지 오는 줄기가 폐선만 지나는가. 바깥에 현행 분기가 있으면 현행색이다.
  final bool stemGone;

  /// 이 줄을 지나 바깥으로 이어지는 줄기가 폐선만 지나는가.
  final bool throughGone;

  /// 열람 전용 노선이면 그 항목이다.
  final ArchiveBranch? archive;

  /// 병주 상대가 이 줄에서 들어오거나 나간다. 곡선이 그 자리의 병주 선에서 나온다.
  final int? parallel;
}

/// 줄기 끝에서 이어지는 노선. 위쪽 끝이면 [up]이다.
final class EndLine extends SelectorLine {
  const EndLine({
    required this.gap,
    required this.at,
    required this.items,
    required this.up,
    this.parallel,
    this.trunkThrough = false,
    this.stackAt = 0,
    this.stackOf = 1,
    this.stackLive = false,
    super.lanes,
  });

  final int gap;
  final SelectorRow at;

  /// 같은 끝 묶음에 그날 있는 노선이 하나라도 있다. 묶음의 옅어지는 선은 그 색(현행색) 하나로 그린다.
  /// 줄마다 색을 바꾸면 현행·폐선이 섞인 묶음에서 선이 줄 경계에서 끊겨 보였다(網走 釧網本線·湧網線, 사용자 결정 2026-11-20)
  final bool stackLive;

  /// 같은 끝에 이어지는 노선이 여럿이면 한 묶음으로 촘촘히 쌓는다 (사용자 결정 2026-11-08, A안).
  /// [stackAt] 0이 역에 가장 가까운 줄이고 그 줄만 점선을 길게 긋는다
  final int stackAt;
  final int stackOf;

  /// 한 노선의 방면들. 그 역을 지나가는 노선이면 둘이다.
  final List<DisplayLink> items;
  final bool up;

  /// 끝 너머에서 들고 나는 병주 상대다(B′). 점선이 그 자리의 병주 선에서 꺾여 글씨로 간다.
  final int? parallel;

  /// 바깥에 다른 끝 이어짐 줄이 있어 줄기 점선이 이 줄을 지나간다.
  final bool trunkThrough;
}

/// 열람 전용 역 줄.
final class ArchiveLine extends SelectorLine {
  const ArchiveLine({required this.gap, required this.stop, super.lanes});

  final int gap;
  final ArchiveStop stop;
}

/// 폐지 구간의 경계. 위쪽이 영업, 아래쪽이 폐지면 [year]가 있다.
final class SectionLine extends SelectorLine {
  const SectionLine({required this.gap, this.year, this.suspended = false, this.opens, this.stem, super.lanes});

  final int gap;
  final String? year;

  /// 끝 이어짐 줄과 역 사이에 놓인 구분선이다. 끝 이어짐(다른 노선)으로 가는 점선 줄기가 이 줄을 끊기지 않고 지나간다.
  /// 값은 그 이어짐이 모두 폐선인가다. 계통 끝에 닿은 폐지 구간은 다른 노선 줄 안쪽에서 시작하고 끝난다 (사용자 결정 2026-11-19)
  final bool? stem;

  /// 고른 날에 아직 개업 전인 구간이면 그 개업 해다. 폐지 해 대신 「1951년 개업」으로 적는다
  final String? opens;

  /// 폐지가 아니라 운휴 중인 구간의 경계다. 「운휴 중」으로 적는다 (DESIGN §8 상태표, 디자인 감사 C08)
  final bool suspended;
}

/// 이관 구간의 경계 (DESIGN §8.0.1 B안). 점선 아래에 한 번만 [lineId] 노선으로 넘어간 날 [on]을 적는다.
/// [back]이면 이 노선으로 돌아오는 곳, [whole]이면 노선 전체가 넘어가 머리 띠로 그린다.
/// 폐지 구분선과 같은 자리면 [closedYear]에 그 해를 함께 둔다
final class TransferLine extends SelectorLine {
  const TransferLine({
    required this.gap,
    required this.lineId,
    required this.on,
    required this.at,
    this.back = false,
    this.whole = false,
    this.closedYear,
    super.lanes,
  });

  final int gap;
  final String lineId;
  final String on;

  /// 구분선 바로 아래 역. 「노선 보기」가 이 역으로 넘어간다.
  final SelectorRow at;
  final bool back;
  final bool whole;
  final String? closedYear;
}

/// 괄호로 묶는 구간의 상태 (사용자 결정 2026-11-19 「칸마다 그 날짜의 상태 하나」).
/// 이관은 다른 노선으로 기록되는 구간, 나머지는 그날 탈 수 없는 구간이다
/// [season]: 계절 운행의 비시즌 구간(검은 점선 + 녹색 괄호, 2026-11-24). 안내 [NoticeLine.year]에 보통 운행 달(「4-11」)을 싣는다
enum NoticeKind { hand, closed, suspended, before, season }

/// 괄호 끝이 걸리는 줄. 역 줄이면 [seq], 열람 전용 역 줄이면 [archive]다
final class BracketAnchor {
  const BracketAnchor({this.seq, this.archive});

  final int? seq;
  final String? archive;

  bool matches(SelectorLine line) => switch (line) {
        StopLine(:final row) => seq != null && row.seq == seq,
        ArchiveLine(:final stop) => archive != null && stop.id == archive,
        _ => false,
      };
}

/// 괄호로 묶은 구간의 안내 (사용자 결정 2026-11-19, 폐지·이관 구분선을 대신함).
/// 상태가 같은 칸이 이어지는 만큼 [top]부터 [bottom]까지 괄호 하나로 묶고, 이 줄은 괄호 맨 위 역(그 역에 딸린 아래쪽 분기·끝 이어짐 줄 다음) 바로 아래에 놓인다.
/// 폐지일이 지난 칸은 이관보다 폐지가 앞선다. 날짜를 모르면 마지막 상태다
final class NoticeLine extends SelectorLine {
  const NoticeLine({
    required this.kind,
    required this.top,
    required this.bottom,
    this.lineId,
    this.on,
    this.year,
    this.at,
    this.anyDate = false,
    super.lanes,
  });

  final NoticeKind kind;

  /// 날짜 모름 화면의 안내다. 계절 운행은 「그날 운행하지 않음」을 붙이지 않는다
  final bool anyDate;
  final BracketAnchor top;
  final BracketAnchor bottom;

  /// 이관 구간이면 이어받은 노선과 넘어간 날, 「노선 보기」가 넘어갈 역
  final String? lineId;
  final String? on;
  final SelectorRow? at;

  /// 폐지 구간이면 폐지 해, 개업 전 구간이면 개업 해다. 모르면 '?'
  final String? year;
}

/// 그날 다니지 않던 같은 노선 선형 하나 (DESIGN §8.3). 붙는 역 줄 바로 아래(위로 붙으면 바로 위)에 놓인다.
/// [lines]는 접힌 선형 안의 줄이다(일반 노선과 같은 줄, 줄 전체를 덮는 괄호는 뺐다). 역이 하나면 접지 않는다
final class FoldLine extends SelectorLine {
  const FoldLine({required this.fold, required this.at, required this.lines});

  final StitchFold fold;

  /// 붙는 본선 역 줄의 행.
  final SelectorRow at;
  final List<SelectorLine> lines;
}

/// 본선 줄에 접힌 줄을 끼운다 (DESIGN §8.3). 아래로 붙으면 역 줄 바로 뒤, 위로 붙으면 역 줄 바로 앞이다
List<SelectorLine> withFolds(List<SelectorLine> main, List<FoldLine> folds) {
  final out = <SelectorLine>[];
  for (final line in main) {
    if (line is StopLine) {
      for (final f in folds) {
        if (f.fold.up && f.fold.anchor == line.row.seq) out.add(f);
      }
      out.add(line);
      for (final f in folds) {
        if (!f.fold.up && f.fold.anchor == line.row.seq) out.add(f);
      }
    } else {
      out.add(line);
    }
  }
  return out;
}

/// 접힌 선형 안 줄을 만든다 (DESIGN §8.3). [lines]는 [StitchFold.frame](붙는 역·돌아오는 역을 더한 행)으로 만든 줄이다.
/// 붙는 역·돌아오는 역의 줄(역·분기·끝 이어짐)은 본선에 있으므로 빼고, 그 역에 걸친 괄호는 남긴다.
/// 선형 전체를 덮고 해도 접힌 줄 기간과 같은 괄호는 뺀다(문구의 기간이 대신한다). 해가 다르면(菊池線 ~2022 안의 ~1986) 남긴다
List<SelectorLine> foldInner(List<SelectorLine> lines, {String period = '', Set<int> edges = const {}}) {
  bool edge(SelectorLine l) => switch (l) {
        StopLine(:final row) => edges.contains(row.seq),
        BranchLine(:final at) => edges.contains(at.seq),
        EndLine(:final at) => edges.contains(at.seq),
        _ => false,
      };
  // 접힌 선형 안 역은 폐역 해를 늘 적는다. 같은 해 폐지 괄호가 없으니(문구의 기간이 대신) 줄마다 「~1973」이 남아야 한다 (목업과 같다)
  final kept = [
    for (final l in lines)
      if (!edge(l))
        if (l is StopLine && l.quiet)
          StopLine(
            index: l.index,
            row: l.row,
            transfers: l.transfers,
            branchUp: l.branchUp,
            branchDown: l.branchDown,
            small: l.small,
            branchUpGone: l.branchUpGone,
            branchDownGone: l.branchDownGone,
            returnsTo: l.returnsTo,
            endUp: l.endUp,
            endDown: l.endDown,
            lanes: l.lanes,
          )
        else
          l,
  ];
  final stops = [for (final l in kept) if (l is StopLine) l.row.seq];
  if (stops.isEmpty) return kept;
  // 역 하나뿐인 선형(「]」)은 접힌 칸이 없어 괄호를 그리지 않는다. 역 줄의 「1978~」·「~1968」이 대신한다
  if (stops.length == 1) return [for (final l in kept) if (l is! NoticeLine) l];
  final years = period.replaceAll('~', '');
  bool atTop(int? seq) => seq == stops.first || edges.contains(seq);
  bool atBottom(int? seq) => seq == stops.last || edges.contains(seq);
  return [
    for (final l in kept)
      if (!(l is NoticeLine && atTop(l.top.seq) && atBottom(l.bottom.seq) && (l.year ?? '') == years)) l,
  ];
}

/// `route_link`를 줄로 바꾼다 (ARCHITECTURE §3.3 `DisplayRules`, DESIGN §8.1).
final class DisplayRules {
  DisplayRules(this.network, {required this.today});

  final Network network;
  final String today;

  late final Map<String, Set<String>> _companies = () {
    final jr = {
      for (final row in network.data.operators)
        if (row.category == 'jr') row.id,
    };
    final byLine = <String, Set<String>>{};
    for (final attr in network.data.attrs) {
      (byLine[attr.lineId] ??= {}).add(jr.contains(attr.operatorId) ? 'jr' : attr.operatorId);
    }
    return byLine;
  }();

  late final Map<String, Set<String>> _lineages = () {
    final byLine = <String, Set<String>>{};
    for (final attr in network.data.attrs) {
      (byLine[attr.lineId] ??= {}).add(attr.lineageId);
    }
    return byLine;
  }();

  /// [after]가 [before]를 이어받을 수 있는가. 같은 사슬(lineage)을 한 칸이라도 나눠야 승계다 (DESIGN §2.9 승계 사슬).
  /// 사슬을 모르는 노선(표시용 버스 등)은 막지 않는다
  bool _succeeds(String? before, String? after) {
    final a = _lineages[before], b = _lineages[after];
    return a == null || b == null || a.intersection(b).isNotEmpty;
  }

  /// 두 노선이 같은 사슬을 실제로 나누는가. 사슬을 모르면 거짓이다
  bool _sharesLineage(String? a, String? b) {
    final x = _lineages[a], y = _lineages[b];
    return x != null && y != null && x.intersection(y).isNotEmpty;
  }

  /// 같은 회사인가. 회사 판정은 이름이 아니라 `operator_id`다 (DESIGN §8.1).
  bool sameCompany(String? a, String? b) =>
      (_companies[a] ?? const <String>{}).intersection(_companies[b] ?? const <String>{}).isNotEmpty;

  /// JR 노선인가. JR 노선 이름에는 회사 앞머리가 없다 (도카이도 본선·도카이도 신칸센).
  bool isJr(String? line) => (_companies[line] ?? const <String>{}).contains('jr');

  /// 그날 있던 연결이라도 상대 노선이 그 역에서 오늘 영업하지 않으면 폐선 색이다.
  /// 끝난 날은 이 노선과의 연결이 끝난 날이 아니라 상대 계통의 그 역 정차가 끝난 날이다.
  /// 이관으로 이 노선 쪽 연결만 끝난 경우(2020년의 金沢 北陸新幹線)를 흐리게 그리지 않는다 (실화면 검수 2026-11-08)
  /// 연결·병주가 「없어졌는가」를 가르는 날. 날짜를 고른 화면은 그 날(범위의 첫날), 아니면 오늘이다.
  /// 예전에는 늘 오늘이라, 1990년 名鉄岐阜市内線처럼 지금은 없는 노선을 그 시절로 보면 그날 영업한 연결도 흐리게 「~2005」로 나왔다 (2026-11-18)
  String? _viewDay;
  String get _day => _viewDay ?? today;

  /// 연결 기간이 화면의 날(_day)을 덮는가
  bool _activeOn(SelectorLink link) =>
      (link.validFromLo ?? '0000').compareTo(_day) <= 0 && (link.validToHi == null || link.validToHi!.compareTo(_day) > 0);

  /// 임시 운행만 있는 계통의 운행 토막. 그리는 동안만 둔다
  List<({String from, String to})> _tempWindows = const [];

  /// 임시 운행만 있는 계통의 연결은 운행일에만 있다. 운행일 연결은 운행일이 아닌 날에도 끝난 연결로 보지 않는다
  /// (역이 운행일이 아닌 날 흐린 같은 크기 원인 것과 짝. 北方貨物線 尼崎의 福知山線·JR東西線·東海道本線, 사용자 지적 2026-11-21)
  Set<String> _tempRoutes = const {};

  bool _tempLink(SelectorLink link) => _tempRoutes.contains(link.otherRouteId) || _tempWindows.any((w) =>
      (link.validFromLo ?? '0000').compareTo(w.to) < 0 && w.from.compareTo(link.validToHi ?? DateSpan.maxDate) < 0);

  bool _gone(SelectorLink link, {required bool onDate, required String node, SelectorRow? row}) {
    if (_tempLink(link)) return false;
    if (!onDate) return true;
    // 선로 연결(끝 이어짐·분기)은 두 노선이 함께 다닐 때만 있어 기간이 끝났으면 끝남이다(相生線 美幌 → 石北本線 ~1985).
    // 이 노선 쪽이 이관돼 끝난 행(金沢 北陸本線 2015 → IRいしかわ)만 상대 역이 남아 있는지로 본다. 환승은 상대 역이 남아 있는지가 색이다
    final ended = link.validToHi != null && link.validToHi!.compareTo(_day) <= 0;
    if (ended && link.kind != 'transfer' && row != null && row.handedTo == null) return true;
    final route = link.otherRouteId;
    final at = link.otherNode ?? node;
    if (route != null && network.routes.containsKey(route)) {
      String? end;
      var found = false;
      for (final stop in network.stops(route)) {
        if (stop.node != at) continue;
        found = true;
        // 정차가 끝났어도 서지 않고 고를 수 있는 동안(격하된 신호장·끝 노드, route_stop_select)은 그 자리가 남아 있다 (三岐朝明信号場 1989~)
        for (final to in [stop.period.toHi, for (final span in stop.selectSpans) if (span.style != 'none' && span.style != 'moved') span.period.toHi]) {
          if (to == null || to.compareTo(DateSpan.maxDate) >= 0) return false;
          if (end == null || to.compareTo(end) > 0) end = to;
        }
      }
      if (found) return end!.compareTo(_day) <= 0;
    }
    final end = link.validToHi;
    return end != null && end.compareTo(_day) <= 0;
  }

  /// (노선, 노드)마다 지금도 운휴 중인 그 노선 칸이 운휴에 들어간 날들. 운휴가 끝나지 않은(또는 오늘 뒤에 끝나는) 칸만 본다
  late final Map<(String, String), Set<String>> _suspendedSince = () {
    final ends = <String, (String, String)>{for (final edge in network.data.edges) edge.id: (edge.from, edge.to)};
    final lines = <String, Set<String>>{};
    for (final attr in network.data.attrs) {
      (lines[attr.edgeId] ??= {}).add(attr.lineId);
    }
    final out = <(String, String), Set<String>>{};
    for (final life in network.data.lives) {
      if (!life.suspended) continue;
      final start = life.period.fromLo;
      final end = life.period.toLo;
      if (start == null || (end != null && end.compareTo(today) <= 0)) continue;
      final pair = ends[life.edgeId];
      if (pair == null) continue;
      for (final line in lines[life.edgeId] ?? const <String>{}) {
        (out[(line, pair.$1)] ??= {}).add(start);
        (out[(line, pair.$2)] ??= {}).add(start);
      }
    }
    return out;
  }();

  /// 열람 전용 역 묶음이 없어진 해: 가장 늦은 폐역 해. 모르면 「?」(폐지 구간)
  static String _latestYear(List<ArchiveStop> stops) {
    final years = [
      for (final stop in stops)
        ?int.tryParse(stop.closedYear.length >= 4 ? stop.closedYear.substring(0, 4) : ''),
    ];
    return years.isEmpty ? '?' : '${years.reduce((a, b) => a > b ? a : b)}';
  }

  /// 0 km 칸이 잇는 두 노드(나뉜 역 쌍). 양쪽 방향 모두 든다
  late final Set<String> _zeroPairs = {
    for (final edge in network.data.edges)
      if (edge.meters == 0) ...['${edge.from}\u0000${edge.to}', '${edge.to}\u0000${edge.from}'],
  };

  /// 끝난 연결이 상대 노선 칸의 운휴로 끝났는가. 연결이 끝난 날 그 역에 닿는 상대 노선 칸이 운휴에 들어가 지금도 운휴다
  bool _suspendedEnd(SelectorLink link, String node) {
    final end = link.validToHi;
    final line = link.otherLineId;
    if (end == null || line == null || end.compareTo(today) > 0) return false;
    return (_suspendedSince[(line, link.otherNode ?? node)] ?? const <String>{}).contains(end);
  }

  DisplayLink _display(SelectorLink link, bool gone, String node) =>
      DisplayLink(link: link, gone: gone, suspended: gone && _suspendedEnd(link, node));

  /// 앞 노선이 끝난 날 뒤 노선이 시작하면 이어받은 것이다. 앞 노선은 이름만 남긴다.
  /// 앞 노선 연결이 운휴로 기간만 나뉜 토막이면 앞 토막도 같은 이름으로 묶는다 (十和田観光電鉄線 三沢의 東北本線 1968 운휴, 감사 3회차 연결 기간 일반화)
  /// 같은 노선이 기간만 이어 나뉜 토막(다음 역·끝 역이 바뀌어 나뉨)은 이관이 아니라 한 줄이다 (近鉄志摩線 鳥羽의 参宮線: 池の浦シーサイド 1989~2020)
  /// 앞 노선은 같은 사슬이어야 한다. 끝 역이 같거나 둘 다 없다고 이어받은 것이 아니다
  /// (札幌市電 西4丁目線 ~1971 › 地下鉄南北線, 信越本線 ~2015 › 北陸新幹線 長野, 海峡線 › 北海道新幹線 津軽二股. 화면 전수 탐지 9회차 c3)
  List<DisplayLink> _chained(List<DisplayLink> items) {
    final out = <DisplayLink>[];
    final taken = <DisplayLink>{};
    // 사슬은 가장 늦게 끝나는 토막부터 잇는다. 앞 토막이 먼저 앞 노선을 가져가면 최신 토막에 앞 노선이 안 붙는다
    // (上田 しなの鉄道線: 1997–2019 토막이 信越本線을 가져가 날짜 모름 화면에서 信越本線이 사라짐, 10회차 G1 chubu_1-005)
    String endOf(DisplayLink item) => item.link.validToHi ?? DateSpan.maxDate;
    // 그날 있는 토막이 먼저다. 날짜를 고른 화면에서 가장 늦게 끝나는 토막이 그날 없던 것이면 그날 토막이 거기 묶여 흐리게 그려졌다
    // (名鉄岐阜市内線 1990 徹明町: 美濃町線 1988–1999 직통이 1999–2005 토막에 묶임, 2026-11-18). 오늘 화면은 지금 토막이 가장 늦게 끝나 순서가 같다
    final order = [...items]..sort((a, b) => a.gone != b.gone ? (a.gone ? 1 : -1) : endOf(b).compareTo(endOf(a)));
    final built = <DisplayLink, DisplayLink>{};
    for (final item in order) {
      if (taken.contains(item)) continue;
      // 두 번 이상 이관되면 옛 이름을 시간 순으로 쌓는다
      final earlier = <DisplayLink>[];
      final pieces = <DisplayLink>[];
      // 이미 대표로 뽑힌 토막은 다시 묶지 않는다. 그날 토막이 먼저 뽑힌 뒤 그날 없던 늦은 토막에 묶여 지워졌다 (名鉄岐阜市内線 1990 徹明町)
      bool fresh(DisplayLink other) =>
          !identical(other, item) &&
          !built.containsKey(other) &&
          !earlier.contains(other) &&
          !pieces.contains(other) &&
          !taken.contains(other) &&
          other.link.side == item.link.side &&
          other.link.flow == item.link.flow;
      var line = item.link.otherLineId;
      var from = item.link.validFromLo;
      // 지금 노선의 가장 이른 토막. 앞 노선은 이 토막과 끝 역이 같아야 한다(최신 토막의 끝 역이 나중에 바뀌었어도: 樽見鉄道 1989~ 樽見, 1984~ 神海).
      // 같은 노선 앞 토막은 운휴 등으로 사이가 비어도 이어 본다(上田 しなの鉄道線 2019–2021 운휴 → 信越本線 ~1997. 10회차 G1 chubu_1-005·chubu_3-012)
      var head = item;
      while (from != null) {
        final contig = [
          for (final other in items)
            if (fresh(other) && other.link.validToHi == from) other,
        ];
        final earlierSame = [
          for (final other in items)
            if (fresh(other) &&
                other.link.otherLineId == line &&
                other.link.validToHi != null &&
                other.link.validToHi!.compareTo(from) <= 0)
              other,
        ];
        if (earlierSame.isNotEmpty) {
          final latest = earlierSame.map((other) => other.link.validToHi!).reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
          final sameLine = [for (final other in earlierSame) if (other.link.validToHi == latest) other];
          pieces.addAll(sameLine);
          head = sameLine.first;
          from = sameLine.first.link.validFromLo;
          continue;
        }
        final found = [
          for (final other in contig)
            if (other.link.terminal == head.link.terminal && _succeeds(other.link.otherLineId, line)) other,
        ];
        if (found.isEmpty) break;
        earlier.insertAll(0, found);
        head = found.first;
        from = found.first.link.validFromLo;
        line = found.first.link.otherLineId;
        final more = [
          for (final other in items)
            if (fresh(other) &&
                other.link.terminal == item.link.terminal &&
                other.link.otherLineId == line &&
                from != null &&
                other.link.validToHi != null &&
                other.link.validToHi!.compareTo(from) <= 0)
              other,
        ];
        for (final piece in more) {
          pieces.add(piece);
          final lo = piece.link.validFromLo;
          if (lo == null) {
            from = null;
          } else if (from != null && lo.compareTo(from) < 0) {
            from = lo;
          }
        }
      }
      taken
        ..addAll(earlier)
        ..addAll(pieces);
      built[item] = earlier.isEmpty
          ? item
          : DisplayLink(
              link: item.link,
              gone: item.gone,
              suspended: item.suspended,
              before: [for (final row in earlier) row.link],
            );
    }
    for (final item in items) {
      if (built[item] case final done?) out.add(done);
    }
    final merged = {for (final item in taken) item.link};
    return [
      for (final item in out)
        if (!merged.contains(item.link)) item,
    ];
  }

  /// 날짜를 모르면 그날 없던 노선을 가를 수 없어 오늘 기준으로 체크박스를 따른다.
  /// [skip]은 `순번\u0000상대 노선`이다. 병주 구간 안의 역에서 그 상대의 행은 병주 선이 대신한다.
  /// 기록 하한(1950-01-01) 전에 끝난 연결은 열람 전용과 같아 「옛 역·노선도 표시」를 켰을 때만 흐리게 보인다 (감사 3회차 hokkaido_1-007)
  List<DisplayLink> _links(
    SelectorRow row,
    String kind,
    DisplayOptions options, {
    bool undated = false,
    Set<String> skip = const {},
  }) {
    final archive = options.showClosed && options.showArchive;
    bool early(SelectorLink link) => link.validToHi != null && link.validToHi!.compareTo(floorDate) <= 0;
    return _chained([
      for (final link in row.links)
        if (link.kind == kind &&
            (archive || !early(link)) &&
            (options.showClosed || !undated || !_gone(link, onDate: true, node: row.node, row: row)) &&
            !skip.contains('${row.seq}\u0000${link.otherLineId}'))
          _display(link, early(link) || _gone(link, onDate: true, node: row.node, row: row), row.node),
      // 임시 운행 계통의 운행일 연결은 폐역·폐선 표시를 꺼도 보인다(끝난 연결이 아니다)
      for (final link in row.goneLinks)
        if ((options.showClosed || _tempLink(link)) &&
            link.kind == kind &&
            (archive || !early(link)) &&
            !skip.contains('${row.seq}\u0000${link.otherLineId}'))
            _display(link, _gone(link, onDate: false, node: row.node), row.node),
    ].where((item) => _oneOnDay(row, item.link, skip)).toList());
  }

  /// 같은 노선(또는 같은 사슬을 이어받은 노선)과의 연결은 그 화면의 날(_day: 고른 날짜, 날짜 모름이면 오늘)에 맞는 것 하나만 보인다.
  /// 직통·환승이 시기에 따라 바뀌었거나(佐世保 松浦鉄道), 이관으로 노선·회사 이름이 바뀐 경우(国鉄 松浦線 → 松浦鉄道西九州線)에도
  /// 그 날 있던 연결만 그린다. 그 날 둘 다 있으면(직통 열차가 일부만 다님) 직통·분기를 보인다.
  /// 그 날 있는 것이 없으면 그 날까지 가장 늦게 끝난 것 하나(폐선은 마지막 상태)이고, 그 날 뒤에 생긴 연결은 보이지 않는다.
  /// 기간별 기록은 DB에 그대로 있고 날짜 칩으로 그 시절을 본다 (사용자 결정 2026-11-19)
  bool _oneOnDay(SelectorRow row, SelectorLink link, Set<String> skip) {
    const kinds = {'continue', 'transfer', 'branch'};
    if (!kinds.contains(link.kind)) return true;
    // 다른 노선은 같은 사슬을 나누고 두 연결의 기간이 겹치지 않을 때만(앞 노선이 끝나고 뒤 노선이 이어받음) 같은 노선으로 본다.
    // 일부 구간만 넘어가 두 노선이 함께 있는 경우(越後線·信越本線)는 서로 다른 노선이다
    bool overlap(SelectorLink a, SelectorLink b) =>
        (a.validFromLo ?? '0000').compareTo(b.validToHi ?? DateSpan.maxDate) < 0 && (b.validFromLo ?? '0000').compareTo(a.validToHi ?? DateSpan.maxDate) < 0;
    bool related(SelectorLink other) =>
        other.otherLineId == link.otherLineId || (_sharesLineage(other.otherLineId, link.otherLineId) && !overlap(other, link));
    final group = [for (final other in [...row.links, ...row.goneLinks]) if (kinds.contains(other.kind) && related(other)) other];
    // 그날 있는 연결은 연결 기간이 그날을 덮는 것이다. 「끝남」 색(상대 역이 아직 있나, _gone)과 따로 본다.
    // 섞으면 상대 계통을 적은 옛 연결(肥薩線 八代 → 鹿児島本線 ~2004)이 상대 역이 남아 있다는 이유로 그날 연결이 되어 그날 환승을 가렸다
    bool live(SelectorLink other) =>
        _tempLink(other) || (row.links.contains(other) && _activeOn(other) && !_gone(other, onDate: true, node: row.node, row: row));
    final present = [for (final other in group) if (live(other)) other];
    if (present.isNotEmpty) {
      if (!present.contains(link)) return false;
      // 그 날 직통(끝 이어짐)이 있으면 같은 노선 환승은 숨긴다(더 넓은 쪽 하나). 화면에 줄로 그려지지 않는 연결
      // (병주 선이 대신하는 행 skip, 선로만 갈라지는 분기 branch)은 환승을 가리지 않는다 (尾西線 名鉄一宮, 越後線 吉田의 弥彦線)
      return link.kind != 'transfer' || !present.any((other) => other.kind == 'continue' && !skip.contains('${row.seq}\u0000${other.otherLineId}'));
    }
    // 그 날 뒤에 생긴 연결은 보이지 않는다
    bool future(SelectorLink other) => other.validFromLo != null && other.validFromLo!.compareTo(_day) > 0;
    if (future(link)) return false;
    // 그 날까지 가장 늦게 끝난 상태 하나(종류와 상관없이). 같은 날 끝난 위·아래 두 방면은 함께 남는다.
    // 종류별로 따로 고르면 屋代의 長野電鉄屋代線처럼 옛 분기(~1982)와 마지막 환승(~2012)이 함께 남았다
    final ended = [
      for (final other in group)
        if (!future(other) && other.validToHi != null && other.validToHi != DateSpan.maxDate && other.validToHi!.compareTo(_day) <= 0)
          other.validToHi!,
    ];
    // 끝난 날을 모르는 연결뿐이면 그대로 둔다
    if (ended.isEmpty) return link.validToHi == null || link.validToHi == DateSpan.maxDate || link.validToHi!.compareTo(_day) > 0;
    final last = ended.reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
    return link.validToHi == last;
  }


  /// 같은 상대 노선의 같은 쪽 줄이 기간만 이어서 나뉘었으면 하나만 그린다. 그날 있는 것, 둘 다 같으면 늦게 끝난 것을 남긴다
  /// (青山線·浅草線 泉岳寺: 연결 종류나 끝 역이 바뀌어 행이 기간별로 나뉜 것. 감사 3회차 kanto_1-002).
  /// 기간이 겹치는 줄(같은 노선의 두 방면)은 둘 다 남는다.
  /// 분기와 끝 이어짐은 함께 넘긴다. 종류가 바뀐 토막(그 역이 끝이던 때의 이어짐과 뒤의 분기)이 한 쪽에 두 줄로 그려지지 않게
  /// [sideOf]는 그 줄이 실제로 그려지는 쪽이다 (青い森鉄道 八戸의 八戸線 2002–2010 이어짐 + 2010~ 분기, 화면 전수 탐지 9회차 b2·b3)
  List<DisplayLink> _onePerLine(List<DisplayLink> items, {String? Function(DisplayLink item)? sideOf}) {
    final side = sideOf ?? (DisplayLink item) => item.link.side;
    String startOf(DisplayLink item) => item.link.validFromLo ?? '0000-01-01';
    String endOf(DisplayLink item) => item.link.validToHi ?? DateSpan.maxDate;
    bool apart(DisplayLink a, DisplayLink b) => endOf(a).compareTo(startOf(b)) <= 0 || endOf(b).compareTo(startOf(a)) <= 0;
    // 기간이 엇갈려 겹치는 다른 계통(한쪽이 먼저 시작해 먼저 끝남)은 같은 방면이 옮겨 간 것이다. 그날 둘 다 있지 않으면 한 줄
    // (西武新宿線 東村山의 西武園線: 村山貯水池 1948–1951, 西武園 1950~. 10회차 G1 kanto_3-005). 두 방면(기간이 같음)은 둘 다 남는다
    bool staggered(DisplayLink a, DisplayLink b) =>
        a.link.otherRouteId != b.link.otherRouteId || a.link.nextStop != b.link.nextStop
            ? (startOf(a).compareTo(startOf(b)) < 0) == (endOf(a).compareTo(endOf(b)) < 0) &&
                startOf(a) != startOf(b) &&
                endOf(a) != endOf(b) &&
                (a.gone || b.gone)
            : false;
    bool better(DisplayLink a, DisplayLink than) =>
        (than.gone && !a.gone) || (than.gone == a.gone && endOf(a).compareTo(endOf(than)) > 0);
    final dropped = <DisplayLink>{};
    for (final a in items) {
      for (final b in items) {
        if (identical(a, b) ||
            a.link.otherLineId != b.link.otherLineId ||
            side(a) != side(b) ||
            a.link.midway != b.link.midway ||
            !(apart(a, b) || staggered(a, b))) {
          continue;
        }
        if (better(b, a)) dropped.add(a);
      }
    }
    return [
      for (final item in items)
        if (!dropped.contains(item)) item,
    ];
  }

  /// 같은 회사 → 현행 → 폐선. JR 각사는 하나로 본다 (DESIGN §8.1).
  List<DisplayLink> _ordered(List<DisplayLink> items, String lineId) {
    final mine = _companies[lineId] ?? const <String>{};
    int rank(DisplayLink item) {
      final same = (_companies[item.link.otherLineId] ?? const <String>{}).intersection(mine);
      return (same.isEmpty ? 2 : 0) + (item.gone ? 1 : 0);
    }

    return [...items]..sort((a, b) => rank(a).compareTo(rank(b)));
  }

  List<TransferGroup> transfers(
    SelectorRow row,
    String lineId,
    DisplayOptions options, {
    bool undated = false,
    Set<String> skip = const {},
    bool Function(DisplayLink item)? drop,
  }) {
    // 한 노선은 한 번만 적는다. 옛 자리·나눈 노드로 같은 노선이 두 역에 걸리면(新豊橋/新豊橋（旧）) 지금 것을 남긴다 (디자인 감사 S02)
    final all = [
      ..._links(row, 'transfer', options, undated: undated, skip: skip),
      // 분기선을 끄면 곡선 대신 그 노선을 캡슐로 보여 준다 (DESIGN §8.1)
      if (!options.showBranches) ..._links(row, 'branch', options, undated: undated, skip: skip),
    ];
    // 직통(끝 이어짐)으로 잇는 노선이 이 역을 지나 반대쪽으로도 이어지면 그 반대 방향은 갈아타서 간다. 환승으로 적는다
    // (唐津의 唐津線 鬼塚·山本 방면. 사용자 결정 2026-11-23, 전국 일괄 규칙)
    final tracks = [..._links(row, 'continue', options, undated: undated, skip: skip), ..._links(row, 'branch', options, undated: undated, skip: skip)];
    for (final item in _links(row, 'continue', options, undated: undated, skip: skip)) {
      final link = item.link;
      final route = link.otherRouteId;
      if (route == null || network.routes[route]?.closed == true) continue;
      if (all.any((x) => x.link.otherLineId == link.otherLineId)) continue;
      final stops = network.stops(route);
      final at = stops.indexWhere((st) => st.node == (link.otherNode ?? row.node));
      final next = stops.indexWhere((st) => st.node == link.nextStop);
      if (at <= 0 || at >= stops.length - 1 || next < 0 || next == at) continue;
      final side = next > at ? stops.sublist(0, at).reversed : stops.sublist(at + 1);
      final opposite = side.where((st) => st.isStop).firstOrNull;
      if (opposite == null) continue;
      // 같은 때 그 반대 방향도 선로 줄(끝 이어짐·분기)로 이어지면 갈아탈 필요가 없다 (都電 三宅坂 半蔵門線 양방향). 끝난 옛 연결은 보지 않는다(山田線 宮古 2019 전 분기)
      bool sameTime(SelectorLink l) =>
          (l.validFromLo ?? '').compareTo(link.validToHi ?? DateSpan.maxDate) < 0 && (link.validFromLo ?? '').compareTo(l.validToHi ?? DateSpan.maxDate) < 0;
      if ([...row.links, for (final d in tracks) d.link]
          .any((l) => (l.kind == 'continue' || l.kind == 'branch') && l.otherLineId == link.otherLineId && l.nextStop == opposite.node && sameTime(l))) {
        continue;
      }
      all.add(DisplayLink(
        link: SelectorLink(
          seq: link.seq,
          kind: 'transfer',
          otherLineId: link.otherLineId,
          otherRouteId: route,
          validFromLo: link.validFromLo,
          validToHi: link.validToHi,
          flow: 'through',
          otherNode: link.otherNode,
          nextStop: opposite.node,
        ),
        gone: item.gone,
        suspended: item.suspended,
      ));
    }
    // 이관 구간 경계 역에서 이어받은 노선은 구분선이 이미 알려 주어 캡슐로 다시 적지 않는다 (실화면 검수 2026-11-09, 長野의 北しなの線)
    if (drop != null) all.removeWhere(drop);
    // 지금 선로로 이어진(분기·끝 이어짐) 노선과의 옛 환승은 「끝남」으로 적지 않는다. 지금도 갈아탈 수 있다 (姫路 山陽本線, 감사 3회차 kinki_1-07)
    final joined = {
      for (final link in row.links)
        if ((link.kind == 'branch' || link.kind == 'continue') && _activeOn(link) && !_gone(link, onDate: true, node: row.node, row: row)) link.otherLineId,
    };
    all.removeWhere((item) => item.gone && item.link.kind == 'transfer' && joined.contains(item.link.otherLineId));
    // 둘 다 그날 있거나 둘 다 끝났으면 늦게 끝난 것을 남긴다. 폐선 화면에서 모두 끝났어도 노선이 끝날 때의 연결이 남는다
    // (枝光線 枝光駅前: 鹿児島本線 1966–1985 본선, 1966년에 끝난 옛 선로 계통이 아니라. 감사 2회차 K33)
    String endOf(DisplayLink item) => item.link.validToHi ?? DateSpan.maxDate;
    final byLine = <String?, DisplayLink>{};
    for (final item in all) {
      final had = byLine[item.link.otherLineId];
      if (had == null ||
          (had.gone && !item.gone) ||
          (had.gone == item.gone && endOf(item).compareTo(endOf(had)) > 0)) {
        byLine[item.link.otherLineId] = item;
      }
    }
    final unique = [
      for (final item in all)
        if (identical(byLine[item.link.otherLineId], item)) item,
    ];
    final items = _ordered(unique, lineId);
    TransferFlow flowOf(DisplayLink item) => switch (item.link.flow) {
          'through' => TransferFlow.through,
          'up' => TransferFlow.up,
          'down' => TransferFlow.down,
          _ => TransferFlow.unknown,
        };
    final kinds = [
      for (final flow in TransferFlow.values)
        if (items.any((item) => flowOf(item) == flow)) flow,
    ];
    // ① 지나감 ② 위에서 와서 끝남 ③ 아래에서 와서 끝남 ④ unknown. enum 순서가 곧 번호다
    return [
      for (final flow in kinds)
        TransferGroup(
          flow: flow,
          items: [for (final item in items) if (flowOf(item) == flow) item],
          number: kinds.length > 1 ? flow.index + 1 : null,
        ),
    ];
  }

  bool _isGoneStop(SelectorRow row) => switch (row.state) {
        StopState.closed ||
        StopState.beforeOpen ||
        StopState.lineClosed ||
        StopState.noEdge =>
          true,
        _ => false,
      };

  /// 체크박스를 끄면 그날 없던 역을 숨긴다. 현행 분기를 가진 폐역은 작은 노드로 남는다 (DESIGN §8.1).
  /// 1950년 전에 정차가 끝난 역은 열람 전용과 같아 「옛 역·노선도 표시」를 끄면 숨는다.
  List<SelectorRow> visible(List<SelectorRow> rows, DisplayOptions options) {
    bool branch(SelectorRow row) => row.links.any((link) => link.kind == 'branch');
    final archive = options.showClosed && options.showArchive;
    return [
      for (final row in rows)
        if ((options.showClosed || !_isGoneStop(row) || branch(row)) && (archive || !row.beforeFloor || branch(row))) row,
    ];
  }

  /// [openGaps]는 역 사이가 그날 영업했는지다. 보이는 줄 기준으로 넘긴다.
  List<SelectorLine> lines({
    required String lineId,
    required List<SelectorRow> rows,
    required List<bool> openGaps,
    required DisplayOptions options,
    bool closedRoute = false,
    List<ArchiveStop> archiveStops = const [],
    List<ArchiveBranch> archiveBranches = const [],
    List<bool>? sectionGaps,
    List<SectionEnd>? sectionEnds,
    bool undated = false,
    List<ParallelRun> parallels = const [],
    DateSpan? date,
    String? shownLineId,
    List<({String from, String to})> tempWindows = const [],
    Set<String> tempRoutes = const {},
  }) {
    // 그리는 동안만 그 화면의 날을 기준으로 삼는다. 끝나면 오늘로 되돌려 다른 호출(환승 캡슐 등)에 남지 않게 한다
    _viewDay = date?.lo;
    _tempWindows = tempWindows;
    _tempRoutes = tempRoutes;
    try {
      return _linesOn(
        lineId: lineId,
        rows: rows,
        openGaps: openGaps,
        options: options,
        closedRoute: closedRoute,
        archiveStops: archiveStops,
        archiveBranches: archiveBranches,
        sectionGaps: sectionGaps,
        sectionEnds: sectionEnds,
        undated: undated,
        parallels: parallels,
        date: date,
        shownLineId: shownLineId,
      );
    } finally {
      _viewDay = null;
      _tempWindows = const [];
      _tempRoutes = const {};
    }
  }

  List<SelectorLine> _linesOn({
    required String lineId,
    required List<SelectorRow> rows,
    required List<bool> openGaps,
    required DisplayOptions options,
    required bool closedRoute,
    required List<ArchiveStop> archiveStops,
    required List<ArchiveBranch> archiveBranches,
    required List<bool>? sectionGaps,
    required List<SectionEnd>? sectionEnds,
    required bool undated,
    required List<ParallelRun> parallels,
    required DateSpan? date,
    required String? shownLineId,
  }) {
    final archive = options.showClosed && options.showArchive;
    final places = _place(rows, archive ? archiveStops : const []);
    final out = <SelectorLine>[];
    // 끝 이어짐의 기준은 마지막 현행 역이다. 뒤에 폐지 구간이 있어도 유지한다 (DESIGN §8.1)
    // 이관된 역은 이어받은 노선이 서는 지금 역이다. 이관 구간 앞 역에서 갈라지는 노선은 끝 이어짐이 아니라 분기다 (DESIGN §8.0.1 B안)
    // 날짜를 고른 화면은 그날 영업한 역이 기준이다. 오늘 기준이면 지금은 없는 노선(名鉄岐阜市内線 1990, 끝 역 徹明町)에서
    // 끝 역을 못 찾아 끝 이어짐(직통 美濃町線)이 분기로 그려졌다 (2026-11-18, 사례가 아니라 규칙으로)
    bool aliveOn(SelectorRow row) => date == null
        ? row.current
        : const [StopState.open, StopState.maybe, StopState.suspended].contains(row.state);
    final current = [
      for (final (index, row) in rows.indexed)
        if (aliveOn(row)) index,
    ];
    final first = current.isEmpty ? 0 : current.first;
    final last = current.isEmpty ? rows.length - 1 : current.last;
    final raw = sectionGaps ?? openGaps;
    // 0 km 칸으로만 이어진 두 역 줄(나뉜 역의 나뉘기 전 노드와 나뉜 뒤 노드, 京阪 三条 → 京津三条) 사이는 구간이 아니다. 그 칸이
    // 나뉜 날 끝나는 것을 구간 폐지로 읽으면 「~1987 폐지」 단계가 생기고 1990년 화면에 구분선이 남는다 (11회차 시뮬레이터 시험).
    // 이웃 칸의 상태와 폐지 해를 따른다. km만 같은 옛 자리(新潟（旧）, 옛 선로가 있다)는 구간이다
    bool sameSpot(SelectorRow a, SelectorRow b) => _zeroPairs.contains('${a.node}\u0000${b.node}');
    bool beside(int index) =>
        index + 1 < rows.length && sameSpot(rows[index], rows[index + 1]);
    int? home(int index) {
      for (var at = index - 1; at >= 0; at--) {
        if (!beside(at)) return at;
      }
      for (var at = index + 1; at < raw.length; at++) {
        if (!beside(at)) return at;
      }
      return null;
    }
    final gaps = [
      for (final (index, open) in raw.indexed)
        if (!beside(index)) open else if (home(index) case final at?) raw[at] else true,
    ];
    // 첫 구간부터 폐지됐고 첫 역도 없어졌으면 구분선을 첫 역 위에 둔다. 첫 역 아래에 두면 첫 역만 남은 것처럼 보인다.
    // 첫 역이 지금 역이면 그 역은 폐지 구간 밖이라 아래에 둔다
    // 날짜를 고른 화면에서는 그날 영업한 역도 구간 밖이다. 1950년 秋田市内線 県庁前(1963 폐역)은 그날 영업해, 개업 전 구간의 끝 구분선이
    // 그 역 위에 온다 (11회차 시뮬레이터 시험)
    bool alive(SelectorRow row) => aliveOn(row);
    final topClosed = gaps.isNotEmpty && !gaps.first && !alive(rows.first);
    // 끝 역 너머 폐지 구간이 노드 한 역뿐이고 그 너머에 열람 전용 역도 없으면 구분선을 두지 않는다. 열람 전용 한 역(宗谷本線 稚内桟橋)과 같은 규칙이다
    // (사용자 결정 2026-11-18 「한 역에는 폐지 구간 점선을 그리지 않는다」를 노드 폐역에도: 京王線 東八王子). 대신 그 역 줄에 폐지 해를 보인다
    final aliveIdx = [for (final (i, r) in rows.indexed) if (alive(r)) i];
    final loneBottom = aliveIdx.isNotEmpty &&
        aliveIdx.last == rows.length - 2 &&
        aliveIdx.last < gaps.length &&
        !gaps[aliveIdx.last] &&
        (places[rows.length - 1] ?? const <ArchiveStop>[]).isEmpty;
    final loneTop = aliveIdx.isNotEmpty &&
        aliveIdx.first == 1 &&
        topClosed &&
        (places[-1] ?? const <ArchiveStop>[]).isEmpty &&
        (places[0] ?? const <ArchiveStop>[]).isEmpty;
    // 0 km 칸은 폐지 연도도 이웃 칸을 따른다
    final yearOf = _closedYears(rows, gaps, sectionEnds);
    for (var index = 0; index < gaps.length; index++) {
      final from = beside(index) ? home(index) : null;
      if (from == null) continue;
      final year = yearOf[from];
      if (year == null) {
        yearOf.remove(index);
      } else {
        yearOf[index] = year;
      }
    }
    bool suspendedAt(int gap) => sectionEnds != null && gap >= 0 && gap < sectionEnds.length && sectionEnds[gap].suspended;
    String? seasonAt(int gap) => sectionEnds != null && gap >= 0 && gap < sectionEnds.length ? sectionEnds[gap].season : null;
    // 행의 폐지 해를 지우는 것은 옆 괄호가 그 해를 적을 때뿐이다. 계절 운행 괄호는 해를 적지 않으니 그 옆 역은 제 표시(비시즌 등)를 그대로 단다
    // (끝난 계절 노선의 운행 시절 비시즌, 関電トンネルトロリーバス 2010-01-15, 5회차 시뮬레이터 시험 2026-11-24)
    String? shownYear(int gap) => seasonAt(gap) != null ? null : yearOf[gap];
    String? opensAt(int gap) {
      final at = gap >= 0 && beside(gap) ? home(gap) : gap;
      return sectionEnds != null && at != null && at >= 0 && at < sectionEnds.length ? sectionEnds[at].opens : null;
    }
    // 병주 토막 (DESIGN §8.1). 아직 시작하지 않은 토막은 빼고, 날짜를 모르면 끝난 토막도 흐리게 그린다.
    // 그날 이미 끝난 토막도 폐선 표시를 켜면 흐린 병주 선이다(北5条線 札幌駅前–西五丁目 1932–1971, 감사 2회차 K09).
    // 그 칸 역에서 상대와의 연결이 토막보다 늦게 끝나면 그 연결이 대신한다(西野田線 1932년 병주 끝, 1964년까지 환승).
    // 겹치는 토막은 줄기에서 바깥으로 한 칸씩 비켜 선다
    final runs = <_Run>[];
    for (final run in _oneRunPerSpan(parallels, date)) {
      final from = rows.indexWhere((row) => row.seq == run.fromSeq);
      final to = rows.indexWhere((row) => row.seq == run.toSeq);
      if (from < 0 || to <= from) continue;
      final end = run.validToHi;
      var gone = end != null && end.compareTo(_day) <= 0;
      if (date != null && (run.validFromLo ?? '0000').compareTo(date.hi) > 0) continue;
      if (date != null && end != null && end.compareTo(date.lo) <= 0) {
        final later = rows.sublist(from, to + 1).any((row) => [...row.links, ...row.goneLinks].any((link) =>
            link.otherLineId == run.otherLineId && (link.validToHi ?? DateSpan.maxDate).compareTo(end) > 0));
        if (!options.showClosed || later) continue;
        gone = true;
      }
      // 병주 상대가 여럿이어도 겹치는 칸은 선 하나로 그린다. 들고 나는 곳에서 각자 갈라진다(분기 여럿이 줄기 하나를 함께 쓰는 것과 같다).
      // 칸마다 자리를 나누면 京成本線 空港第2ビル–成田空港처럼 같은 칸을 달리는 상대(成田線·成田空港線)가 나란한 선 두 개로 보였다 (사용자 결정 2026-11-20)
      runs.add(_Run(run, from, to, 0, gone: gone));
    }
    final skip = {
      for (final run in runs)
        for (var at = run.from; at <= run.to; at++) '${rows[at].seq}\u0000${run.run.otherLineId}',
    };
    final open = <_Run>[];
    List<LaneMark> pass([_Run? except]) => [
          for (final run in open)
            if (!identical(run, except)) LaneMark(run.lane, LaneRole.pass, gone: run.gone),
        ];
    for (final (index, row) in rows.indexed) {
      final isFirst = index == first;
      final isLast = index == last;
      // 이관 구간 경계에서 띠 안쪽으로 이어받은 노선으로 가는 줄은 띠가 그린다(구분선 글과 겹친다). 띠 반대쪽으로 가는 그 노선 연결은 남긴다
      // (山田線 宮古: 宮古~釜石 三陸鉄道 띠, 久慈 방면 三陸鉄道는 그대로. 2026-11-23 일반 규칙)
      final successors = <String, Set<String>>{};
      final own = bandOf(row, undated: undated, date: date)?.$1;
      for (final step in [-1, 1]) {
        final at = index + step;
        if (at < 0 || at >= rows.length) continue;
        final to = bandOf(rows[at], undated: undated, date: date)?.$1;
        if (to == null || to == own) continue;
        final nodes = successors.putIfAbsent(to, () => <String>{});
        for (var k = at; k >= 0 && k < rows.length && bandOf(rows[k], undated: undated, date: date)?.$1 == to; k += step) {
          nodes.add(rows[k].node);
        }
      }
      bool keep(DisplayLink item) {
        final inside = successors[item.link.otherLineId];
        if (inside == null) return true;
        final next = item.link.nextStop;
        return next != null && !inside.contains(next);
      }
      // 직통이 맨 끝 역에서 이어지면 그 역이 폐역·옛 자리여도 거기서 끝 이어짐이다 (DESIGN §8.1 시기별 끝 역, 信越本線 新潟（旧）)
      final topEnd = isFirst || index == 0;
      final bottomEnd = isLast || index == rows.length - 1;
      // 끝 역의 이어짐은 끝 쪽으로, 나머지는 분기처럼 side로 그린다 (side가 없으면 아래)
      String drawnSide(DisplayLink item) => item.link.kind == 'continue' && topEnd != bottomEnd
          ? (topEnd ? 'up' : 'down')
          : (item.link.side == 'up' ? 'up' : 'down');
      // 환승이던 같은 노선이 이어서 선로 연결이 되면(연결 종류만 바뀐 토막) 그 환승 토막의 이관 앞 노선을 선로 줄에 잇는다.
      // 환승 토막은 지금 선로 연결이 있어 환승 캡슐에서 빠지므로 앞 노선이 화면에서 사라졌다 (会津鬼怒川線 会津高原尾瀬口: 会津線 ~1987 › 会津鉄道会津線, 10회차 G1 S11)
      final transferChains = [for (final item in _links(row, 'transfer', options, undated: undated, skip: skip)) if (item.before.isNotEmpty) item];
      DisplayLink inherit(DisplayLink item) {
        if (item.before.isNotEmpty) return item;
        for (final t in transferChains) {
          if (t.link.otherLineId == item.link.otherLineId && t.link.validToHi != null && t.link.validToHi == item.link.validFromLo) {
            return DisplayLink(link: item.link, gone: item.gone, suspended: item.suspended, before: t.before);
          }
        }
        return item;
      }
      final joined = _onePerLine([
        if (options.showBranches) ..._links(row, 'branch', options, undated: undated, skip: skip).where(keep).map(inherit),
        ..._links(row, 'continue', options, undated: undated, skip: skip).where(keep).map(inherit),
      ], sideOf: drawnSide);
      final branches = [for (final item in joined) if (item.link.kind == 'branch') item];
      final continues = [for (final item in joined) if (item.link.kind == 'continue') item];
      final starting = [for (final run in runs) if (run.from == index) run];
      final ending = [for (final run in runs) if (run.to == index) run];
      // 끝 너머에서 들고 나는 상대는 끝 이어짐 줄로(B′), 중간이면 분기 줄로, 상대의 기점·종점이면 역 노드에서
      final beyondUp = [for (final run in starting) if (isFirst && run.run.inNext != null) run];
      final midIn = [for (final run in starting) if (!isFirst && run.run.inNext != null) run];
      final fromNode = [for (final run in starting) if (run.run.inNext == null) run];
      final beyondDown = [for (final run in ending) if (isLast && run.run.outNext != null) run];
      final midOut = [for (final run in ending) if (!isLast && run.run.outNext != null) run];
      final toNode = [for (final run in ending) if (run.run.outNext == null) run];
      final inner = [
        ...branches,
        if (!topEnd && !bottomEnd) ...continues,
      ];
      final ups = inner.where((item) => item.link.side == 'up' && !item.link.midway).toList();
      final downs = inner.where((item) => item.link.side != 'up' && !item.link.midway).toList();
      final midway = inner.where((item) => item.link.midway).toList();
      final old = [
        if (options.showBranches && archive)
          for (final branch in archiveBranches)
            if (branch.atNode == row.node) branch,
      ];
      bool? endsGone(Iterable<EndLine> ends) =>
          ends.isEmpty ? null : ends.every((end) => end.items.every((item) => item.gone));
      final upEnds = topEnd ? _ends(continues, gap: index - 1, at: row, up: true).toList() : const <EndLine>[];
      final downEnds = bottomEnd ? _ends(continues, gap: index, at: row, up: false).toList() : const <EndLine>[];
      // 첫 역 앞의 열람 전용 역은 맨 위에 둔다(첫 역 위 끝 이어짐·구분선보다 바깥).
      // 첫 역 위가 폐지 구간이 아니면 그 묶음은 계통 끝 너머의 없어진 구간이라, 폐지 구간처럼 바깥에 폐지 해 구분선, 안쪽에 끝 구분선을 둔다.
      // 없으면 지금 노선이 그 역들까지 이어지는 것처럼 보인다 (志度線 瓦町 앞 公園前·中野町·藤塚·東田町, 사용자 결정 2026-11-18)
      if (index == 0) {
        final beyond = places[-1] ?? const <ArchiveStop>[];
        // 한 역뿐이면 구간이라 부를 것이 없어 구분선을 두지 않는다(긴 점선이 오히려 읽기 어렵다, 사용자 결정 2026-11-18)
        final fence = beyond.length > 1 && !topClosed;
        if (fence) out.add(SectionLine(gap: -1, year: _latestYear(beyond), lanes: pass()));
        for (final stop in beyond) {
          out.add(ArchiveLine(gap: -1, stop: stop, lanes: pass()));
        }
        if (fence) out.add(SectionLine(gap: -1, lanes: pass()));
      }
      // 계통 첫 구간부터 폐지면 구분선은 끝 이어짐(다른 노선) 줄 안쪽, 그 줄과 첫 역 사이에 둔다. 다른 노선까지 폐지 구간에 든 것처럼 읽히지 않게 한다.
      // 점선 줄기는 구분선 줄을 지나 끊기지 않는다 (사용자 결정 2026-11-19. 2026-11-09 「끝 이어짐 바깥」 결정을 대신함, 肥前吉井는 줄기가 이어져 해결)
      final topFence = index == 0 && topClosed && !loneTop;
      final upEndsAny = upEnds.isNotEmpty || (isFirst && beyondUp.isNotEmpty);
      if (topFence && !upEndsAny) out.add(SectionLine(gap: -1, year: yearOf[0], suspended: suspendedAt(0), opens: opensAt(0), lanes: pass()));
      // 폐지·운휴 구간이 지금 역에서 끝나면 끝 구분선을 그 역 위에 둔다. 아래에 두면 지금 역이 구간 안에 든다 (常磐線 新地~山下 이설).
      // 구간이 역 사이 한 칸뿐이면 시작 구분선과 같은 자리라 하나만 둔다
      final endsHere = endsAt(rows, gaps, index, alive: alive);
      if (endsHere && !(index == 1 ? !topClosed : gaps[index - 2]) && !(loneTop && index == 1)) out.add(SectionLine(gap: index - 1, lanes: pass()));
      out.addAll(upEnds);
      if (isFirst) {
        final ends = upEnds;
        for (final run in beyondUp) {
          out.add(EndLine(
            gap: index - 1,
            at: row,
            items: [_laneLink(run, row, up: true)],
            up: true,
            parallel: run.lane,
            trunkThrough: ends.isNotEmpty,
            lanes: pass(),
          ));
          open.add(run);
        }
      }
      if (topFence && upEndsAny) {
        out.add(SectionLine(
            gap: -1, year: yearOf[0], suspended: suspendedAt(0), opens: opensAt(0), stem: endsGone(upEnds) ?? false, lanes: pass()));
      }
      for (final (at, item) in ups.indexed) {
        out.add(
          BranchLine(
            gap: index - 1,
            at: row,
            item: item,
            up: true,
            stacked: at > 0,
            stemGone: ups.take(at + 1).every((other) => other.gone),
            throughGone: ups.take(at).every((other) => other.gone),
            endThrough: endsGone(upEnds),
            lanes: pass(),
          ),
        );
      }
      // 위로 들어오는 상대가 여럿이면 위 줄부터 적고, 아래 줄은 위 줄로 가는 병주 선이 그대로 지나간다(stacked)
      for (final (at, run) in midIn.indexed) {
        out.add(BranchLine(
          gap: index - 1,
          at: row,
          item: _laneLink(run, row, up: true),
          up: true,
          stacked: at > 0,
          stemGone: midIn.take(at + 1).every((other) => other.gone),
          throughGone: midIn.take(at).every((other) => other.gone),
          parallel: run.lane,
          lanes: pass(),
        ));
        open.add(run);
      }
      final marks = [
        for (final run in open)
          LaneMark(
            run.lane,
            toNode.contains(run)
                ? LaneRole.endNode
                : run.run.stopSeqs.contains(row.seq)
                    ? LaneRole.stop
                    : LaneRole.pass,
            gone: run.gone,
          ),
        for (final run in fromNode) LaneMark(run.lane, LaneRole.startNode, gone: run.gone),
      ];
      open
        ..removeWhere(toNode.contains)
        ..addAll(fromNode.where((run) => !toNode.contains(run)));
      out.add(
        StopLine(
          endUp: endsGone(upEnds),
          endDown: endsGone(downEnds),
          lanes: marks,
          index: index,
          row: row,
          transfers: transfers(row, lineId, options, undated: undated, skip: skip, drop: (item) => !keep(item)),
          branchUp: ups.isNotEmpty,
          branchDown: downs.isNotEmpty || old.isNotEmpty,
          small: !options.showClosed && _isGoneStop(row),
          branchUpGone: ups.isNotEmpty && ups.every((item) => item.gone),
          branchDownGone: (downs.isNotEmpty || old.isNotEmpty) && downs.every((item) => item.gone),
          // 개업 전 역의 「1951~」는 구분선 해와 같아도 지우지 않는다(지우면 개업 전인지 알 수 없다, 11회차 시뮬레이터 시험 秋田駅前)
          quiet: !(loneTop && index == 0) &&
              !(loneBottom && index == rows.length - 1) &&
              row.closeYear != null &&
              row.state != StopState.beforeOpen &&
              (row.closeYear == shownYear(index - 1) || row.closeYear == shownYear(index)),
          returnsTo: closedRoute && rows.take(index).any((earlier) => earlier.node == row.node)
              ? row.node
              : null,
        ),
      );
      // 나가는 병주 상대는 역 바로 아래(가장 안쪽) 줄이다
      for (final (at, run) in midOut.indexed) {
        out.add(BranchLine(
          gap: index,
          at: row,
          item: _laneLink(run, row, up: false),
          up: false,
          stacked: at < midOut.length - 1,
          stemGone: midOut.skip(at).every((other) => other.gone),
          throughGone: midOut.skip(at + 1).every((other) => other.gone),
          parallel: run.lane,
          lanes: pass(run),
        ));
        open.remove(run);
      }
      for (final (at, item) in downs.indexed) {
        out.add(
          BranchLine(
            gap: index,
            at: row,
            item: item,
            up: false,
            stacked: at < downs.length - 1 || old.isNotEmpty,
            stemGone: downs.skip(at).every((other) => other.gone),
            throughGone: downs.skip(at + 1).every((other) => other.gone),
            endThrough: endsGone(downEnds),
            lanes: pass(),
          ),
        );
      }
      // 역이 아닌 곳의 분기는 그 역 다음 칸의 선로에서 바로 갈라진다
      for (final item in midway) {
        out.add(
          BranchLine(
            gap: index,
            at: row,
            item: item,
            up: false,
            stacked: false,
            stemGone: item.gone,
            throughGone: item.gone,
            endThrough: isLast ? endsGone(downEnds) : null,
            lanes: pass(),
          ),
        );
      }
      for (final (at, branch) in old.indexed) {
        out.add(_archiveBranch(row, index, branch,
            stacked: at < old.length - 1, endThrough: endsGone(downEnds), lanes: pass()));
      }
      // 계통 끝 구간이 폐지면 아래로 이어지는 노선(끝 이어짐) 줄 앞에 닫는 구분선을 둔다. 이어지는 노선이 없으면 끝 역에서 끝나 닫는 선이 없다
      // (사용자 결정 2026-11-19, 海峡線 木古内–江差線 / 白糠線 北進은 없음). 끝 너머 한 역뿐인 폐역(loneBottom)은 여는 구분선도 없어 닫지 않는다
      final downEndsAny = downEnds.isNotEmpty || (isLast && beyondDown.isNotEmpty);
      if (index == rows.length - 1 && downEndsAny && !alive(row) && (index == 0 ? topClosed : !gaps[index - 1]) && !loneBottom) {
        out.add(SectionLine(gap: index, stem: endsGone(downEnds) ?? false, lanes: pass()));
      }
      if (isLast) {
        final ends = downEnds;
        for (final run in beyondDown) {
          out.add(EndLine(
            gap: index,
            at: row,
            items: [_laneLink(run, row, up: false)],
            up: false,
            parallel: run.lane,
            trunkThrough: ends.isNotEmpty,
            lanes: pass(run),
          ));
          open.remove(run);
        }
      }
      out.addAll(downEnds);
      // 끝 역 뒤의 열람 전용 역도 끝 너머 없어진 구간이다. 끝쪽 폐지 구간과 같이 끝 역 바로 아래에 폐지 해 구분선 하나만 둔다(그 뒤로 이어지는 구간이 없다)
      final tail = index == rows.length - 1 ? places[index] ?? const <ArchiveStop>[] : const <ArchiveStop>[];
      if (tail.length > 1 && alive(row)) out.add(SectionLine(gap: index, year: _latestYear(tail), lanes: pass()));
      for (final stop in places[index] ?? const <ArchiveStop>[]) {
        out.add(ArchiveLine(gap: index, stop: stop, lanes: pass()));
      }
      if (index < gaps.length) {
        final below = gaps[index];
        final above = index == 0 ? !topClosed : gaps[index - 1];
        final yearAbove = index == 0 ? (topClosed ? yearOf[0] : null) : yearOf[index - 1];
        // 날짜를 고른 화면의 개업 전 구간은 개업 해마다 단계다(浅草線 1960년: 1968·1964·1963 개업)
        final opensAbove = index == 0 ? (topClosed ? opensAt(0) : null) : opensAt(index - 1);
        // 폐지 단계마다 구분선과 날짜를 둔다 (DESIGN §8)
        if (!endsHere && !(loneBottom && index == rows.length - 2) && (below != above || (!below && (yearOf[index] != yearAbove || opensAt(index) != opensAbove)))) {
          out.add(SectionLine(
            gap: index,
            year: below ? null : yearOf[index],
            suspended: !below && suspendedAt(index),
            opens: below ? null : opensAt(index),
            lanes: pass(),
          ));
        }
      }
    }
    return _bracketize(
      attachEnds(out),
      rows: rows,
      gaps: gaps,
      yearOf: yearOf,
      suspendedAt: suspendedAt,
      seasonAt: seasonAt,
      opensAt: opensAt,
      undated: undated,
      date: date,
      shownLineId: shownLineId,
    );
  }

  /// 폐지·운휴·개업 전·이관 구분선을 괄호와 안내 줄로 바꾼다 (사용자 결정 2026-11-19).
  ///
  /// 역 사이 칸마다 그날의 상태를 하나만 정한다. 탈 수 없는 칸(폐지·운휴·개업 전)이 먼저고, 아니면 그 칸이 드는 이관 구간이다.
  /// 이관 구간은 칸 위쪽 역의 이관 구간, 없으면 아래쪽 역의 이관 구간이다(구간 첫 역 앞 칸은 아래쪽 역이, 구간이 끝나는 역 앞 칸은 위쪽 역이 정한다).
  /// 상태와 그 값(폐지 해·이어받은 노선)이 같은 칸이 이어지는 만큼 괄호 하나다. 열람 전용 역 묶음(2역 이상)이 끝 너머에 있으면 그 묶음도 폐지 괄호다.
  /// 화면이 이미 그날의 노선([shownLineId], 같은 사슬의 뒤 노선)으로 바뀌었으면 그 노선으로의 이관은 괄호가 아니다.
  /// 제목이 「三陸鉄道リアス線」인데 같은 노선으로 「이 구간은 그 노선으로 기록돼요」 괄호가 또 그려졌다 (실화면 2026-11-19 北条線, 전 노선 44계통)
  List<SelectorLine> _bracketize(
    List<SelectorLine> lines, {
    required List<SelectorRow> rows,
    required List<bool> gaps,
    required Map<int, String> yearOf,
    required bool Function(int gap) suspendedAt,
    required String? Function(int gap) seasonAt,
    required String? Function(int gap) opensAt,
    required bool undated,
    required DateSpan? date,
    required String? shownLineId,
  }) {
    final body = [for (final line in lines) if (line is! SectionLine && line is! TransferLine) line];
    (String, String)? band(SelectorRow row) => switch (bandOf(row, undated: undated, date: date)) {
          (final to, _) when to == shownLineId => null,
          final hand => hand,
        };
    final spans = <_Span>[];
    for (var gap = 0; gap + 1 < rows.length; gap++) {
      NoticeKind? kind;
      String key = '';
      String? year, lineId, on;
      SelectorRow? at;
      if (undated && gap < gaps.length && gaps[gap] && seasonAt(gap) != null) {
        // 날짜 모름 화면의 계절 운행 구간: 닫힌 구간이 아니어도 계절 운행 괄호와 운행 달 안내를 단다(줄기는 실선 그대로, 사용자 결정 2026-11-25)
        kind = NoticeKind.season;
        year = seasonAt(gap);
        key = year!;
      } else if (gap < gaps.length && !gaps[gap]) {
        if (seasonAt(gap) case final months?) {
          // 계절 운행의 비시즌: 폐지·운휴가 아니다. 보통 운행 달을 안내에 싣는다
          kind = NoticeKind.season;
          year = months;
          key = months;
        } else if (suspendedAt(gap)) {
          // 안내 제목에 운휴 시작 해를 붙인다(역 줄의 「운휴 2023~」과 짝). 시작 해가 다르면 다른 괄호다
          kind = NoticeKind.suspended;
          year = rows[gap].suspendedSince ?? rows[gap + 1].suspendedSince;
          key = year ?? '';
        } else if (opensAt(gap) case final opens?) {
          kind = NoticeKind.before;
          year = opens;
          key = opens;
        } else {
          kind = NoticeKind.closed;
          year = yearOf[gap] ?? '?';
          key = year;
        }
      } else if (band(rows[gap]) ?? band(rows[gap + 1]) case (final to, final day)) {
        kind = NoticeKind.hand;
        lineId = to;
        on = day;
        key = '$to\u0000$day';
        at = band(rows[gap]) != null ? rows[gap] : rows[gap + 1];
      }
      if (kind == null) continue;
      final last = spans.isEmpty ? null : spans.last;
      if (last != null && last.toRow == gap && last.kind == kind && last.key == key) {
        last.toRow = gap + 1;
      } else {
        spans.add(_Span(kind, key, gap, gap + 1, year: year, lineId: lineId, on: on, at: at));
      }
    }
    final notices = <(int, NoticeLine)>[];
    int indexOfRow(SelectorRow row) => body.indexWhere((line) => line is StopLine && line.row.seq == row.seq);
    // 괄호 맨 위 줄에 딸린 아래쪽 분기·끝 이어짐 다음이 안내 자리다
    int after(int index) {
      final top = body[index];
      final seq = top is StopLine ? top.row.seq : null;
      var at = index + 1;
      while (at < body.length && seq != null) {
        final line = body[at];
        final mine = switch (line) {
          BranchLine(:final at, :final up) => !up && at.seq == seq,
          EndLine(:final at, :final up) => !up && at.seq == seq,
          _ => false,
        };
        if (!mine) break;
        at++;
      }
      return at;
    }
    for (final span in spans) {
      // 끝 너머 폐역이 한 역뿐이어도 괄호로 묶는다. 「한 역에는 폐지 구간 점선을 그리지 않는다」(2026-11-18)는 긴 가로 점선 때문이었고,
      // 괄호는 그 문제가 없다 (사용자 확인 2026-11-19 목업: 北条線 北条町–北条町（旧）, 信越本線 新潟（旧）–白山)
      final topIndex = indexOfRow(rows[span.fromRow]);
      if (topIndex < 0 || indexOfRow(rows[span.toRow]) < 0) continue;
      notices.add((
        after(topIndex),
        NoticeLine(
          kind: span.kind,
          top: BracketAnchor(seq: rows[span.fromRow].seq),
          bottom: BracketAnchor(seq: rows[span.toRow].seq),
          lineId: span.lineId,
          on: span.on,
          at: span.at,
          year: span.year,
          anyDate: undated,
        ),
      ));
    }
    // 끝 너머 열람 전용 역 묶음(2역 이상)은 그 묶음과 끝 역을 폐지 괄호로 묶는다 (한 역뿐이면 묶지 않는다, 사용자 결정 2026-11-18)
    final firstStop = body.indexWhere((line) => line is StopLine);
    final lastStop = body.lastIndexWhere((line) => line is StopLine);
    if (firstStop > 0) {
      final head = [for (final line in body.sublist(0, firstStop)) if (line is ArchiveLine) line];
      if (head.length > 1) {
        final top = head.first;
        notices.add((
          body.indexOf(top) + 1,
          NoticeLine(
            kind: NoticeKind.closed,
            top: BracketAnchor(archive: top.stop.id),
            bottom: BracketAnchor(seq: (body[firstStop] as StopLine).row.seq),
            year: _latestYear([for (final line in head) line.stop]),
          ),
        ));
      }
    }
    if (lastStop >= 0 && lastStop + 1 < body.length) {
      final tail = [for (final line in body.sublist(lastStop + 1)) if (line is ArchiveLine) line];
      if (tail.length > 1) {
        notices.add((
          after(lastStop),
          NoticeLine(
            kind: NoticeKind.closed,
            top: BracketAnchor(seq: (body[lastStop] as StopLine).row.seq),
            bottom: BracketAnchor(archive: tail.last.stop.id),
            year: _latestYear([for (final line in tail) line.stop]),
          ),
        ));
      }
    }
    // 뒤에서부터 넣어 앞 자리 번호가 밀리지 않게 한다. 같은 자리면 먼저 시작한 괄호의 안내가 위다
    notices.sort((a, b) => b.$1.compareTo(a.$1));
    for (final (index, notice) in notices) {
      body.insert(index, notice);
    }
    return body;
  }

  /// 끝 이어짐 줄은 자기 역에 붙어 있어야 점선 줄기가 이어진다. 역과 끝 이어짐 사이에는 그 역의 분기·끝 이어짐 줄만 두고,
  /// 그 사이에 낀 구분선·이관 띠·열람 전용 줄은 맨 바깥 끝 이어짐 너머로 보낸다 (사용자 결정 2026-11-09, 사례가 아니라 규칙으로)
  static List<SelectorLine> attachEnds(List<SelectorLine> lines) {
    final out = [...lines];
    bool mine(SelectorLine line, SelectorRow row, bool up) => switch (line) {
          EndLine(:final at, up: final side) => side == up && at.seq == row.seq,
          BranchLine(:final at, up: final side) => side == up && at.seq == row.seq,
          // 끝 이어짐 안쪽 구분선(점선 줄기가 지나감)도 그 역의 줄이다. 바깥으로 보내지 않는다 (사용자 결정 2026-11-19)
          SectionLine(:final stem) => stem != null,
          _ => false,
        };
    for (var i = 0; i < out.length; i++) {
      final stop = out[i];
      if (stop is! StopLine) continue;
      for (final up in const [true, false]) {
        final step = up ? -1 : 1;
        var outer = -1;
        for (var j = i + step; j >= 0 && j < out.length && out[j] is! StopLine; j += step) {
          if (out[j] is EndLine && mine(out[j], stop.row, up)) outer = j;
        }
        if (outer < 0) continue;
        final lo = up ? outer : i + 1;
        final hi = up ? i - 1 : outer;
        final span = out.sublist(lo, hi + 1);
        final kept = [for (final line in span) if (mine(line, stop.row, up)) line];
        final loose = [for (final line in span) if (!mine(line, stop.row, up)) line];
        if (loose.isEmpty) continue;
        out.replaceRange(lo, hi + 1, up ? [...loose, ...kept] : [...kept, ...loose]);
      }
    }
    return out;
  }

  /// 그 역이 드는 이관 구간 (이어받은 노선, 넘어간 날). 그날 이어받은 노선으로 저장되거나, 날짜를 모르거나,
  /// [date]가 이관된 날 뒤일 때만 있다. 이어받은 노선도 그날 끝났거나 그 역을 떠났어도 구간은 이관 구간이다
  /// (DESIGN §8.0.1 「구분선은 탑승일이 그 이관일 이후이거나 날짜 모름일 때」. 高千穂線·湯前線 川村·東北本線 野内（旧）, 감사 2회차 K33)
  static (String, String)? bandOf(SelectorRow row, {bool undated = false, DateSpan? date}) {
    final to = row.handedTo, on = row.handedOn;
    if (to == null || on == null) return null;
    return row.savedAs != null || undated || (date != null && date.lo.compareTo(on) >= 0) ? (to, on) : null;
  }

  /// 이관 구간마다 경계에 구분선 한 줄을 넣는다 (DESIGN §8.0.1 B안).
  /// 그날 이어받은 노선으로 저장되는 역이거나, 날짜를 몰라 이관된 적 있는 역이 한 구간이다. 이관 전 날짜면 넣지 않는다
  static List<SelectorLine> handOver(
    List<SelectorLine> lines, {
    required String lineId,
    bool undated = false,
    DateSpan? date,
  }) {
    (String, String)? keyOf(SelectorRow row) => bandOf(row, undated: undated, date: date);

    // 이관 전·이관 날에 폐역된 역(野内（旧）, 北福井, 南四日市)은 이어받은 회사와 상관없어 구간을 끊지 않는다. 날짜를 몰라도 같다
    final handDays = {
      for (final line in lines)
        if (line is StopLine && line.row.handedOn != null) line.row.handedOn!,
    };
    bool closedBefore(SelectorRow row) =>
        row.handedTo == null && row.closedOn != null && handDays.any((day) => row.closedOn!.compareTo(day) <= 0);
    final stops = lines.whereType<StopLine>().where((stop) => !closedBefore(stop.row)).toList();
    if (stops.every((stop) => keyOf(stop.row) == null)) return lines;
    final first = keyOf(stops.first.row);
    // 첫 역부터 끝 역까지 한 노선으로 넘어갔으면 노선 머리에 띠 하나
    if (first != null && stops.every((stop) => keyOf(stop.row) == first)) {
      return [TransferLine(gap: -1, lineId: first.$1, on: first.$2, at: stops.first.row, whole: true), ...lines];
    }
    final out = <SelectorLine>[];
    (String, String)? current;
    for (final line in lines) {
      if (line is! StopLine) {
        out.add(line);
        continue;
      }
      final key = keyOf(line.row);
      if (key != current && !closedBefore(line.row)) {
        // 새 역 위의 ┌ 분기는 그 역 것이라 구분선 아래로 보낸다
        var at = out.length;
        while (at > 0 && out[at - 1] is BranchLine && (out[at - 1] as BranchLine).up) {
          at--;
        }
        // 같은 자리의 폐지 구분선은 한 구분선으로 합친다 (横川–軽井沢 ~1997 폐지 + 1997 しなの鉄道)
        String? closedYear;
        if (at > 0 && out[at - 1] is SectionLine) {
          closedYear = (out[at - 1] as SectionLine).year;
          out.removeAt(--at);
        }
        // 끝 이어짐 줄이 이어받은 노선을 가리키면 구분선 글과 겹친다
        if (key != null) {
          for (var i = at - 1; i >= 0 && out[i] is EndLine; i--) {
            final end = out[i] as EndLine;
            final rest = [for (final item in end.items) if (item.link.otherLineId != key.$1) item];
            if (rest.length == end.items.length) continue;
            if (rest.isEmpty) {
              out.removeAt(i);
              at--;
            } else {
              out[i] = EndLine(
                gap: end.gap,
                at: end.at,
                items: rest,
                up: end.up,
                parallel: end.parallel,
                trunkThrough: end.trunkThrough,
                stackAt: end.stackAt,
                stackOf: end.stackOf,
                stackLive: end.stackLive,
                lanes: end.lanes,
              );
            }
          }
        }
        final gap = line.index - 1;
        out.insert(
          at,
          key != null
              ? TransferLine(gap: gap, lineId: key.$1, on: key.$2, at: line.row, closedYear: closedYear)
              : TransferLine(gap: gap, lineId: lineId, on: current!.$2, at: line.row, back: true, closedYear: closedYear),
        );
        current = key;
      }
      out.add(line);
    }
    return out;
  }

  /// 폐지·운휴 구간이 [index]의 지금 역에서 끝나고 그 아래로 이 계통이 다시 영업하는가.
  ///
  /// 구분선은 구간 상태가 바뀌는 경계에만 둔다. 계통 맨 끝 역 아래에는 구간이 없으니 경계도 없다.
  /// 그 역이 다른 노선으로는 지금 서는 역이어도(北上線 横手, 美祢線 長門市) 끝 역 위에 구분선을 두지 않는다
  /// [alive]는 그 화면에서 역이 서 있는가다(기본은 지금 역). 날짜를 고른 화면은 그날 영업한 역도 든다
  static bool endsAt(List<SelectorRow> rows, List<bool> gaps, int index, {bool Function(SelectorRow row)? alive}) =>
      index >= 1 &&
      index < gaps.length &&
      // 이관으로 끝난 역은 폐역이 아니다. 그 역에서 폐지 구간이 끝난다 (信越本線 横川–軽井沢).
      // 이어받은 노선도 그 역을 떠났으면 지금 역이 아니라 구간 안이다 (神岡線 神岡, 감사 2회차 K33)
      (alive ?? (row) => row.current)(rows[index]) &&
      !gaps[index - 1] &&
      gaps[index];

  /// 칸마다 그 폐지 구간의 연도. 구분선 아래 칸부터 다음 구분선까지 같다.
  /// 구간 수명에서 읽은 해가 있으면 그것을 쓴다(재설계 R11). 없을 때만 역의 폐역 연도로 채우고, 이관으로 끝난 역의 해는 쓰지 않는다
  Map<int, String> _closedYears(List<SelectorRow> rows, List<bool> gaps, List<SectionEnd>? ends) {
    String? stopYear(SelectorRow row) => row.handedTo == null ? row.closeYear : null;
    return {
      for (var at = 0; at < gaps.length; at++)
        if (!gaps[at])
          at: (ends != null && at < ends.length ? ends[at].year : null) ??
              stopYear(rows[at + 1]) ??
              stopYear(rows[at]) ??
              '?',
    };
  }

  /// 같은 상대·같은 칸의 병주 토막이 기간만 이어 나뉜 것(상대 계통의 다음 역·끝 역이 바뀐 날마다 나눔)은 하나만 그린다.
  /// 날짜가 있으면 그날 토막(없으면 그날 전에 가장 늦게 끝난 토막), 날짜를 모르면 가장 늦게 끝나는 토막이다
  /// (七尾線 和倉温泉의 のと鉄道七尾線 끝 역 輪島 ~2001 → 穴水, 10회차 G1 chubu_2-009).
  /// 날짜를 모르는 화면의 시작은 그 토막과 끊김 없이 이어진 앞 토막들의 가장 이른 시작이다. 마지막 토막 시작만 적으면
  /// 상대 계통 정차가 바뀐 날이 병주가 시작한 해처럼 읽힌다(日豊本線 小倉 → 鹿児島本線 「2004~」, 실제 1902~. 11회차 F1)
  static List<ParallelRun> _oneRunPerSpan(List<ParallelRun> runs, DateSpan? date) {
    String endOf(ParallelRun run) => run.validToHi ?? DateSpan.maxDate;
    String startOf(ParallelRun run) => run.validFromLo ?? '0000-01-01';
    final groups = <String, List<ParallelRun>>{};
    for (final run in runs) {
      (groups['${run.otherLineId}\u0000${run.fromSeq}\u0000${run.toSeq}'] ??= []).add(run);
    }
    final keep = <ParallelRun>{};
    final moved = <ParallelRun, ParallelRun>{};
    for (final group in groups.values) {
      if (group.length == 1) {
        keep.add(group.single);
        continue;
      }
      ParallelRun? pick;
      if (date != null) {
        for (final run in group) {
          if (startOf(run).compareTo(date.lo) <= 0 && date.lo.compareTo(endOf(run)) < 0) pick = run;
        }
        if (pick == null) {
          final before = [for (final run in group) if (startOf(run).compareTo(date.hi) <= 0) run];
          if (before.isNotEmpty) pick = before.reduce((a, b) => endOf(a).compareTo(endOf(b)) >= 0 ? a : b);
        }
      }
      if (pick == null && date == null) {
        final last = group.reduce((a, b) => endOf(a).compareTo(endOf(b)) >= 0 ? a : b);
        var from = startOf(last);
        // 앞 토막의 끝이 지금 시작 이후면(이어지거나 겹침) 그 토막의 시작까지 거슬러 간다
        for (var more = true; more;) {
          more = false;
          for (final run in group) {
            if (startOf(run).compareTo(from) < 0 && endOf(run).compareTo(from) >= 0) {
              from = startOf(run);
              more = true;
            }
          }
        }
        pick = from == startOf(last) ? last : _startingAt(last, run: group.firstWhere((run) => startOf(run) == from));
        if (!identical(pick, last)) moved[last] = pick;
      }
      pick ??= group.reduce((a, b) => endOf(a).compareTo(endOf(b)) >= 0 ? a : b);
      keep.add(pick);
    }
    return [for (final run in runs) if (keep.contains(run)) run else if (moved[run] case final ParallelRun early) early];
  }

  /// [last]와 같은 병주 토막을 [run]의 시작부터로 (날짜 모름 화면에서 이어진 토막의 첫 시작)
  static ParallelRun _startingAt(ParallelRun last, {required ParallelRun run}) => ParallelRun(
        otherLineId: last.otherLineId,
        otherRouteId: last.otherRouteId,
        fromSeq: last.fromSeq,
        toSeq: last.toSeq,
        stopSeqs: last.stopSeqs,
        inNext: last.inNext,
        inTerminal: last.inTerminal,
        outNext: last.outNext,
        outTerminal: last.outTerminal,
        validFromLo: run.validFromLo,
        validToHi: last.validToHi,
      );

  /// 열람 전용 노선 줄. 이을 노선이 없어 빈 연결을 단다.
  BranchLine _archiveBranch(
    SelectorRow row,
    int gap,
    ArchiveBranch branch, {
    required bool stacked,
    bool? endThrough,
    List<LaneMark> lanes = const [],
  }) =>
      BranchLine(
        endThrough: endThrough,
        gap: gap,
        at: row,
        item: DisplayLink(
          link: SelectorLink(
            seq: row.seq,
            kind: 'archive',
            otherLineId: null,
            otherRouteId: null,
            validFromLo: null,
            validToHi: null,
          ),
          gone: true,
        ),
        up: false,
        stacked: stacked,
        stemGone: true,
        throughGone: true,
        archive: branch,
        lanes: lanes,
      );

  /// 병주 상대가 들고 나는 줄의 연결. 누르면 그 노선으로 넘어간다.
  DisplayLink _laneLink(_Run run, SelectorRow row, {required bool up}) => DisplayLink(
        link: SelectorLink(
          seq: row.seq,
          kind: 'branch',
          otherLineId: run.run.otherLineId,
          otherRouteId: run.run.otherRouteId,
          validFromLo: run.run.validFromLo,
          validToHi: run.run.validToHi,
          side: up ? 'up' : 'down',
          flow: 'through',
          nextStop: up ? run.run.inNext : run.run.outNext,
          terminal: up ? run.run.inTerminal : run.run.outTerminal,
        ),
        gone: run.gone,
      );

  Iterable<EndLine> _ends(
    List<DisplayLink> items, {
    required int gap,
    required SelectorRow at,
    required bool up,
  }) {
    final byLine = <String?, List<DisplayLink>>{};
    for (final item in items) {
      (byLine[item.link.otherLineId] ??= []).add(item);
    }
    // 그날 있는 노선을 역에 가까운 쪽에 둔다(목록도 현행이 먼저). 같은 처지끼리는 원래 순서다
    bool gone(List<DisplayLink> group) => group.every((item) => item.gone);
    final liveGroups = byLine.values.where((g) => !gone(g)), goneGroups = byLine.values.where(gone);
    // 위쪽 끝은 목록 뒤쪽이 역에 가깝다
    final groups = up ? [...goneGroups, ...liveGroups] : [...liveGroups, ...goneGroups];
    final live = groups.any((g) => !gone(g));
    // 위쪽 끝은 바깥 줄부터 놓여 마지막이 역에 가깝다
    return [
      for (final (i, group) in groups.indexed)
        EndLine(
          gap: gap,
          at: at,
          items: group,
          up: up,
          stackAt: up ? groups.length - 1 - i : i,
          stackOf: groups.length,
          stackLive: live,
        ),
    ];
  }

  /// 앞 역 뒤에 놓는다. 앞 역을 모르면 뒤 역 앞에, 둘 다 모르면 km로 찾는다.
  /// 앞뒤 역이 그날 숨긴 행이면 그 행이 있던 자리(숨긴 행 바로 앞 행 뒤, 첫 행 앞이면 첫 행 위)다.
  /// 숨긴 행 때문에 열람 전용 역이 화면에서 빠지지 않는다 (大師線 港町（旧） 뒤 久根崎, 2026-11-21)
  Map<int, List<ArchiveStop>> _place(List<SelectorRow> rows, List<ArchiveStop> stops) {
    final places = <int, List<ArchiveStop>>{};
    int at(String? node, {required bool last}) {
      if (node == null) return -2;
      bool here(SelectorRow row) => row.node == node || row.hiddenAfter.contains(node);
      final i = last ? rows.lastIndexWhere(here) : rows.indexWhere(here);
      if (i >= 0) return rows[i].node == node ? i : -(i + 3);
      return rows.isNotEmpty && rows.first.hiddenAbove.contains(node) ? -1 : -2;
    }

    int? slot(ArchiveStop stop) {
      // at: 0 이상 = 그 행, -1 = 첫 행 위(숨긴 행), -(i+3) = i행 뒤 숨긴 행, -2 = 없음
      final a = at(stop.afterNode, last: true);
      if (a >= 0) return a;
      if (a == -1) return -1;
      if (a <= -3) return -(a + 3);
      final b0 = at(stop.beforeNode, last: false);
      if (b0 == -1) return -1;
      if (b0 <= -3) return -(b0 + 3);
      final before = rows.indexWhere((row) => row.node == stop.beforeNode);
      // 첫 역 앞(뒤 역이 첫 줄)이면 첫 역 위 자리(-1)다. 버리면 화면에서 빠진다 (志度線 瓦町 앞 中野町·藤塚·公園前 등 34행, 10회차 G1 chugoku_shikoku_2-003)
      if (stop.beforeNode != null && before >= 0) return before - 1;
      final km = stop.km;
      if (km == null) return null;
      final near = rows.lastIndexWhere((row) => (row.kmCum ?? double.infinity) <= km);
      if (near < 0 && rows.isNotEmpty && rows.first.kmCum != null && km < rows.first.kmCum!) return -1;
      return near >= 0 ? near : null;
    }

    final placed = <String, int>{};
    final rest = <ArchiveStop>[];
    for (final stop in stops) {
      final at = slot(stop);
      if (at != null) {
        (places[at] ??= []).add(stop);
        placed[stop.id] = at;
      } else {
        rest.add(stop);
      }
    }
    // 앞뒤가 다른 열람 전용 역이면 그 역과 같은 자리다 (九条中之島線 船津橋 → 田蓑橋, 10회차 G1 S13)
    for (var changed = true; changed && rest.isNotEmpty;) {
      changed = false;
      for (final stop in [...rest]) {
        final at = placed[stop.afterNode] ?? placed[stop.beforeNode];
        if (at == null) continue;
        (places[at] ??= []).add(stop);
        placed[stop.id] = at;
        rest.remove(stop);
        changed = true;
      }
    }
    // 같은 자리는 계통 순번(seq) 순이다. 순번이 없는 옛 팩은 예전처럼 km 순(모르면 뒤)이다
    for (final list in places.values) {
      list.sort((a, b) {
        final sa = a.seq, sb = b.seq;
        if (sa != null && sb != null) return sa.compareTo(sb);
        return (a.km ?? double.infinity).compareTo(b.km ?? double.infinity);
      });
    }
    return places;
  }
}

/// 보이는 줄의 순번으로 바꾼 병주 토막.
final class _Run {
  _Run(this.run, this.from, this.to, this.lane, {required this.gone});

  final ParallelRun run;
  final int from;
  final int to;
  final int lane;
  final bool gone;
}

/// 괄호 하나. [fromRow]와 [toRow]는 그 화면 역 줄의 순번이다
final class _Span {
  _Span(this.kind, this.key, this.fromRow, this.toRow, {this.year, this.lineId, this.on, this.at});

  final NoticeKind kind;
  final String key;
  final int fromRow;
  int toRow;
  final String? year;
  final String? lineId;
  final String? on;
  final SelectorRow? at;
}
