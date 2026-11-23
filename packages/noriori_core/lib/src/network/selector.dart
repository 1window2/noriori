import '../date/date_rules.dart';
import '../date/date_span.dart';
import 'network.dart';
import 'network_data.dart';

/// 그날 그 역의 상태 (DESIGN §8 탑승일 상태표).
enum StopState { open, maybe, unknown, beforeOpen, closed, suspended, lineClosed, noEdge }

final class SelectorLink {
  const SelectorLink({
    required this.seq,
    required this.kind,
    required this.otherLineId,
    required this.otherRouteId,
    required this.validFromLo,
    required this.validToHi,
    this.side,
    this.flow,
    this.otherNode,
    this.nextStop,
    this.terminal,
    this.midway = false,
    this.reverseSpans = const [],
  });

  final int seq;

  /// branch, continue, transfer.
  final String kind;
  final String? otherLineId;
  final String? otherRouteId;
  final String? validFromLo;
  final String? validToHi;

  /// 분기가 역 위쪽(`up`)인가 아래쪽(`down`)인가.
  final String? side;

  /// 환승 노선의 흐름. through, up, down, unknown.
  final String? flow;

  /// 다른 이름의 역이면 그 역.
  final String? otherNode;
  final String? nextStop;
  final String? terminal;

  /// 역이 아니라 역 사이의 선로에서 갈라진다 (DESIGN §8.1 역이 아닌 곳의 분기).
  final bool midway;

  /// 끝 역 이어짐에서 열차가 진행 방향을 바꿔 상대 노선으로 들어가던 기간들(스위치백 직통, route_link_reverse, 11회차 S3). 표가 없는 옛 판은 비었다
  final List<ReverseSpan> reverseSpans;

  /// 계통을 거꾸로 읽을 때의 연결: 분기 자리(위·아래)와 환승 흐름(위·아래)이 뒤집힌다 (같은 노선 이어 그리기, DESIGN §8.3)
  SelectorLink flipped() {
    String? swap(String? v) => switch (v) {
          'up' => 'down',
          'down' => 'up',
          _ => v,
        };
    return SelectorLink(
      seq: seq,
      kind: kind,
      otherLineId: otherLineId,
      otherRouteId: otherRouteId,
      validFromLo: validFromLo,
      validToHi: validToHi,
      side: swap(side),
      flow: swap(flow),
      otherNode: otherNode,
      nextStop: nextStop,
      terminal: terminal,
      midway: midway,
      reverseSpans: reverseSpans,
    );
  }
}

/// 스위치백 직통 표식 기간 하나. [lo]는 시작 하한, [hi]는 끝 상한이다(끝나지 않았으면 [DateSpan.maxDate]).
final class ReverseSpan {
  const ReverseSpan(this.lo, this.hi);

  final String lo;
  final String hi;
}

enum ReverseState { now, used }

/// 그날 그 이음의 스위치백 표식. 날짜 모름(null)이면 어느 기간이든 걸린다. 걸리는 기간이 없으면 null,
/// 걸리는 기간 가운데 끝나지 않은 것이 있으면 [ReverseState.now], 모두 끝났으면 [ReverseState.used]다 (11회차 S3)
ReverseState? reverseOn(SelectorLink link, DateSpan? date) {
  final spans = [
    for (final span in link.reverseSpans)
      if (date == null || (span.lo.compareTo(date.hi) <= 0 && date.lo.compareTo(span.hi) < 0)) span,
  ];
  if (spans.isEmpty) return null;
  return spans.any((span) => span.hi == DateSpan.maxDate) ? ReverseState.now : ReverseState.used;
}

/// 끝난 연결 줄의 상대 역(다음 역·끝 역·다른 이름 역) 이름을 고를 날 (4회차 kyushu_2-007).
///
/// 그 연결이 끝난 날의 전날이다. 끝난 연결 줄은 그 연결이 있던 때의 이름(臼ノ浦線 「松浦線 다음 上佐々」, 2007 개칭 전)으로 적는다.
/// 연결이 끝나지 않았거나, 고른 날에 아직 있는 연결이면 null이다(그날 또는 지금 이름).
String? endedLinkNameDay(SelectorLink link, DateSpan? date) {
  final end = link.validToHi;
  if (end == null || end == DateSpan.maxDate) return null;
  if (date != null && date.lo.compareTo(end) < 0) return null;
  final parts = end.split('-').map(int.tryParse).toList();
  if (parts.length != 3 || parts.contains(null)) return null;
  final day = DateTime.utc(parts[0]!, parts[1]!, parts[2]!).subtract(const Duration(days: 1));
  return day.toIso8601String().substring(0, 10);
}

/// 끝난 연결 줄 상대 역 이름을 이름 표에 둘 때의 열쇠. 노드 ID와 겹치지 않는다
String endedLinkNameKey(String node, String? otherLine, String day) => '$node\u0000${otherLine ?? ''}\u0000$day';

final class SelectorRow {
  const SelectorRow({
    required this.seq,
    required this.node,
    required this.state,
    required this.selectable,
    this.passing = false,
    this.noBoarding = false,
    this.viewOnly = false,
    required this.kmCum,
    required this.links,
    this.kmEstimated = false,
    this.goneLinks = const [],
    this.savedAs,
    this.openYear,
    this.closeYear,
    this.suspendedSince,
    this.handedTo,
    this.handedOn,
    this.closedOn,
    this.handedOnly = false,
    this.beforeFloor = false,
    this.handedEnded = false,
    this.hiddenAfter = const [],
    this.hiddenAbove = const [],
  });

  final int seq;
  final String node;
  final StopState state;
  final bool selectable;

  /// 승하차 불가 끝 노드로 그린다: 가운데가 회색인 노드, 고를 수 있다(km 계산). 분기점·신호장, 그날 서지 않는 계통 끝 역
  /// (大洗鹿島線 北鹿島 1985–1994, 三岐線 三岐朝明 1989~, 徳島線 佃 1935–1962). 이름은 그날 이름이다 (5번 결정 junction-nodes-rule, 2026-11-19)
  final bool passing;

  /// 계통 끝 노드인데 그날 역(또는 화물역)은 있고 이 계통이 서지 않는다: 보통 역 모양에 「승하차 불가」를 적고 고를 수 있다
  /// (梅田貨物線 福島, 大洗鹿島線 北鹿島 1985–1994. 회색 가운데는 신호장·분기점만, 사용자 결정 2026-11-21 결정 A 추천안)
  final bool noBoarding;

  /// 그날 이 계통이나 이어진 계통의 끝이 아니라서 보이기만 하고 출발·도착역으로 고를 수 없다(신호장·승하차 불가 역).
  /// 그 자리에서 갈라지거나 이어지는 노선이 없으면 거기서 기록을 끊을 까닭이 없다 (사용자 결정 2026-11-21)
  final bool viewOnly;
  final double? kmCum;

  /// km가 추정값이라 화면은 `? km` (DESIGN §4.5).
  final bool kmEstimated;
  final List<SelectorLink> links;

  /// 그날 없던 연결. 체크박스를 켜면 3단계로 그린다.
  final List<SelectorLink> goneLinks;

  /// 그날은 다른 노선이다. 저장은 그 노선으로 된다.
  final String? savedAs;

  /// `2016~`, `~2017`에 쓰는 해.
  final String? openYear;
  final String? closeYear;

  /// 운휴가 시작된 해(`운휴 2022~`). 그 날(날짜를 모르면 지금) 역 정차나 앞뒤 칸이 운휴일 때만 있다
  final String? suspendedSince;

  /// 이 노선의 정차가 이관으로 끝났으면 이어받은 노선과 그 날 (DESIGN §8.0.1 이관 구간).
  /// 이 역의 `~연도`는 폐역이 아니라 이관이라 칩을 달지 않는다
  final String? handedTo;
  final String? handedOn;

  /// 이어받은 노선(같은 사슬)도 지금은 이 역에 서지 않는다(神岡鉄道 2006 폐지, 野内（旧） 2011 이전).
  /// 이관된 역은 이어받은 노선이 서야 지금 역이다 (DESIGN §8.0.1)
  final bool handedEnded;

  /// 지금 역인가. 폐역이 아니거나, 이관됐어도 이어받은 노선이 아직 선다 (DESIGN §8.0.1 이관 구간, §8 구분선)
  bool get current => closeYear == null || (handedTo != null && !handedEnded);

  /// 이 노선의 정차가 끝난 날(범위면 이른 끝). 이관 전에 폐역됐는지 가린다.
  final String? closedOn;

  /// 이 노선은 서지 않고 이어받은 노선만 서는 역이다(이관 뒤 새 역 しきぶ). 이 계통에는 숨은 노드로 있다.
  /// 날짜 모름에서 이 역을 고르면 이어받은 노선 계통을 넘어 저장한다
  final bool handedOnly;

  /// 정차가 기록 하한(1950-01-01) 전에 모두 끝났다. 열람 전용 역처럼 꽉 찬 점으로 그리고 고를 수 없다 (사용자 결정 2026-11-08)
  final bool beforeFloor;

  /// 같은 행에 연결만 바꾼 것 (숨긴 경계점 행의 끝 이어짐을 옮겨 붙일 때)
  /// 그날 화면에서 숨긴 행(옮긴 역의 옛 자리·새 자리, 아직 없던 경계점) 중 이 행 바로 뒤에 있던 것의 노드.
  /// 그 노드에 붙은 열람 전용 역을 이 행 뒤 자리에 놓는다(大師線 港町（旧） 뒤 久根崎, 2026-11-21)
  final List<String> hiddenAfter;

  /// 첫 행 앞에서 숨긴 행의 노드. 그 노드에 붙은 열람 전용 역은 첫 행 위 자리다
  final List<String> hiddenAbove;

  SelectorRow withLinks(List<SelectorLink> links) => _withLinks(links, goneLinks);

  SelectorRow withHidden({List<String>? after, List<String>? above}) =>
      _withLinks(links, goneLinks, hiddenAfter: after, hiddenAbove: above);

  /// km만 바꾼 행 (지선·옛 경로 계통을 그날 첫 행에서 잴 때)
  SelectorRow withKm(double? km) => _withLinks(links, goneLinks, km: km);

  /// 지금 연결과 그날 없던 연결을 함께 바꾼 행 (같은 노선 이어 그리기에서 이은 계통으로 가는 링크를 지울 때, DESIGN §8.3)
  SelectorRow withLinksBoth(List<SelectorLink> links, List<SelectorLink> goneLinks) => _withLinks(links, goneLinks);

  /// 같은 노선 이어 그리기(DESIGN §8.3)에서 행을 옮겨 쓸 때 바꾸는 값들.
  SelectorRow copy({
    int? seq,
    StopState? state,
    bool? selectable,
    double? kmCum,
    bool clearKm = false,
    bool? kmEstimated,
    bool clearClose = false,
    String? closeYearAs,
    String? closedOnAs,
  }) =>
      SelectorRow(
        seq: seq ?? this.seq,
        node: node,
        state: state ?? this.state,
        selectable: selectable ?? this.selectable,
        passing: passing,
        noBoarding: noBoarding,
        viewOnly: viewOnly,
        kmCum: clearKm ? null : (kmCum ?? this.kmCum),
        links: links,
        kmEstimated: kmEstimated ?? this.kmEstimated,
        goneLinks: goneLinks,
        savedAs: savedAs,
        openYear: openYear,
        closeYear: clearClose ? null : (closeYearAs ?? closeYear),
        suspendedSince: suspendedSince,
        handedTo: handedTo,
        handedOn: handedOn,
        closedOn: clearClose ? null : (closedOnAs ?? closedOn),
        handedOnly: handedOnly,
        beforeFloor: beforeFloor,
        handedEnded: handedEnded,
        hiddenAfter: hiddenAfter,
        hiddenAbove: hiddenAbove,
      );

  SelectorRow _withLinks(List<SelectorLink> links, List<SelectorLink> goneLinks,
          {double? km, List<String>? hiddenAfter, List<String>? hiddenAbove}) =>
      SelectorRow(
        seq: seq,
        node: node,
        state: state,
        selectable: selectable,
        passing: passing,
        noBoarding: noBoarding,
        viewOnly: viewOnly,
        kmCum: km ?? kmCum,
        links: links,
        kmEstimated: kmEstimated,
        goneLinks: goneLinks,
        savedAs: savedAs,
        openYear: openYear,
        closeYear: closeYear,
        suspendedSince: suspendedSince,
        handedTo: handedTo,
        handedOn: handedOn,
        closedOn: closedOn,
        handedOnly: handedOnly,
        beforeFloor: beforeFloor,
        handedEnded: handedEnded,
        hiddenAfter: hiddenAfter ?? this.hiddenAfter,
        hiddenAbove: hiddenAbove ?? this.hiddenAbove,
      );
}

/// 행 사이 구간의 끝난 해와 운휴 여부.
final class SectionEnd {
  const SectionEnd({this.year, this.suspended = false, this.opens});

  final String? year;
  final bool suspended;

  /// 고른 날에 아직 개업 전인 구간이 개업한 해. 그 날 화면에서는 폐지 해 대신 이 해를 적는다
  final String? opens;
}

/// 계통과 탑승일로 선택기 행을 만든다 (ARCHITECTURE §2.5). DB를 읽지 않는다.
final class SelectorBuilder {
  const SelectorBuilder(this.network);

  final Network network;

  List<SelectorRow> build(
    String routeId,
    DateSpan? date, {
    List<SelectorLink> links = const [],
    Map<int, NetPeriod> carryoverStops = const {},
  }) {
    final day = normalizeRideDate(date);
    final route = network.routes[routeId]!;
    final adjacent = _around(routeId);
    final bySeq = <int, List<SelectorLink>>{};
    final goneBySeq = <int, List<SelectorLink>>{};
    for (final link in links) {
      final on = day == null || _linkOn(link, day);
      ((on ? bySeq : goneBySeq)[link.seq] ??= []).add(link);
    }
    final rows = <SelectorRow>[];
    final carry = _Carry();
    // 숨긴 행의 노드: 앞 행 번호별, 첫 행 앞
    final hiddenAfter = <int, List<String>>{};
    final hiddenAbove = <String>[];
    void hide(String node) => rows.isEmpty ? hiddenAbove.add(node) : (hiddenAfter[rows.length - 1] ??= []).add(node);
    final picks = network.picks(routeId);
    final ends = {if (picks.isNotEmpty) picks.first.seq, if (picks.isNotEmpty) picks.last.seq};
    for (final pick in picks) {
      // 승계 켬이면 이관 전에 폐역된 역도 그 시기 정차역으로 본다 (DESIGN §2.9 E). 고를 수 있는지는 날짜가 정한다
      final earlier = pick.isStop ? null : carryoverStops[pick.seq];
      final stop = earlier == null
          ? pick
          : NetStop(
              routeId: pick.routeId,
              seq: pick.seq,
              node: pick.node,
              kmCum: pick.kmCum,
              isStop: true,
              isEndPoint: pick.isEndPoint,
              period: earlier,
              kmEstimated: pick.kmEstimated,
            );
      if (!stop.isStop && !stop.isEndPoint) continue;
      if (!stop.isEndPoint && !network.data.publicNodes.contains(stop.node)) continue;
      // 역을 옮긴 옛 자리·새 자리는 날짜를 고른 화면에서 그날의 자리만 보인다(날짜 모름이면 다 보인다, 사용자 결정 2026-11-21)
      if (day != null && !_stopsOn(stop, day) && _movedOn(stop, day)) {
        hide(stop.node);
        continue;
      }
      final around = adjacent[stop.node] ?? const <String>[];
      var (state, selectable) = _state(routeId, stop, around, day);
      // 승하차 불가 끝 노드: 분기점·신호장(서지 않는 노드), 또는 그날 서지 않는 계통 끝 역. 그날 지나는 칸이 있으면 고를 수 있다
      var passing = false;
      // 그날 서지 않는 역도 그날 영업하는 다른 계통이 거기서 끝나면 끝 노드다(長尾線 옛 경로 瓦町–花園 1945–1951의 끝 花園을 본선 일람에서 골라야 花園–御坊川을 탄다).
      // 「어떤 여객 노선의 끝인 분기점은 그 지점을 지나는 다른 노선 일람에도 나온다」(사용자 결정 2026-11-19)
      var noBoarding = false;
      var viewOnly = false;
      // 고를 수 있는지는 컴파일이 정한 표(route_stop_select) 하나만 본다. 앱에서 따로 끝인지 다시 계산하지 않는다 (검토 M1, 2026-11-21)
      final span = !stop.isStop || !_stopsOn(stop, day) ? _spanOn(stop, day) : null;
      if (span != null && _ridable(routeId, around, day)) {
        // 그날 노드의 정체가 모양을 정한다. 신호장·분기점만 회색, 역은 「승하차 불가」, 아직 없던 경계점은 숨긴다.
        // 「_view」는 그날 끝이 아니라 보이기만 하고 고를 수 없다
        viewOnly = span.style.endsWith('_view');
        final style = viewOnly ? span.style.substring(0, span.style.length - 5) : span.style;
        if (style == 'none') {
          // 경계점 행의 끝 이어짐은 이웃한 끝 행으로 옮겨 그린다 (三岐線 富田 계통 1950 전 三岐朝明 → 富田에서 大矢知 쪽)
          // 중간의 경계점(다른 계통을 나중 갈림으로 나눈 자리)은 그날 없던 자리라 그 연결도 그리지 않는다
          if (ends.contains(stop.seq)) carry.addAll(bySeq[stop.seq] ?? const []);
          hide(stop.node);
          continue;
        }
        state = StopState.open;
        selectable = !viewOnly;
        passing = style != 'nostop';
        noBoarding = style == 'nostop';
      }
      // 정차가 끝난 날 이 역이 다른 노선(같은 사슬)에 서면 폐역이 아니라 이관이다.
      // 그 전날 이 노선 것이 아니었던 칸이면 앞 노선 시절에 끝난 역이다 (ふるさと銀河線의 釧北)
      final ended = _ended(stop.period) ? stop.period.toLo : null;
      final handedTo = ended == null || !_ownedUntil(route.lineId, around, ended)
          ? null
          : _earlierLine(route.lineId, stop.node, around, DateSpan.parse(ended));
      String? savedAs;
      if (day != null && (state == StopState.beforeOpen || state == StopState.closed || earlier != null)) {
        savedAs = _earlierLine(route.lineId, stop.node, around, day);
        if (savedAs != null) (state, selectable) = _savedState(savedAs, around, day);
      }
      rows.add(SelectorRow(
        seq: stop.seq,
        node: stop.node,
        state: state,
        selectable: selectable,
        passing: passing,
        noBoarding: noBoarding,
        viewOnly: viewOnly,
        kmCum: stop.kmCum,
        kmEstimated: stop.kmEstimated,
        links: [...?(rows.isEmpty && carry.isNotEmpty ? carry.splice() : null), ...?bySeq[stop.seq]],
        goneLinks: goneBySeq[stop.seq] ?? const [],
        savedAs: savedAs,
        openYear: yearLabel(stop.period.fromLo, stop.period.fromHi),
        // 이관된 역을 이어받은 노선도 닫았으면 끝난 해는 이어받은 노선에서 닫힌 해다. 이관된 해를 적으면
        // 「~2001 폐지」 괄호 안 역이 「~1985」로 보였다 (北条線 北条町（旧）, 七尾線 能登三井, 실화면 2026-11-19)
        // 정차가 끝났어도 지금도 고를 수 있으면(격하된 신호장) 끝난 해가 없다
        closeYear: _ended(stop.period) && _spanOn(stop, null) == null
            ? (handedTo == null ? _lastSelectYear(stop) : _laterCloseYear(route.lineId, stop.node, around)) ?? yearLabel(stop.period.toLo, stop.period.toHi)
            : null,
        suspendedSince: _suspendedSince(stop, around, day),
        handedTo: handedTo,
        handedOn: handedTo == null ? null : ended,
        closedOn: ended,
        beforeFloor: stop.period.toHi != null && stop.period.toHi!.compareTo(floorDate) < 0,
        handedEnded: handedTo != null && !_servedLater(route.lineId, stop.node, around),
      ));
    }
    // 맨 끝 경계점 행을 숨겼으면 그 끝 이어짐은 마지막 행에 붙인다
    if (carry.isNotEmpty && rows.isNotEmpty) rows[rows.length - 1] = rows.last.withLinks([...rows.last.links, ...carry.splice()]);
    for (final MapEntry(:key, :value) in hiddenAfter.entries) {
      rows[key] = rows[key].withHidden(after: value);
    }
    if (hiddenAbove.isNotEmpty && rows.isNotEmpty) rows[0] = rows[0].withHidden(above: hiddenAbove);
    // 지선·옛 경로 계통의 km는 그 계통 안의 위치다. 그날 기점이 앞 역으로 바뀌었으면(그날 없던 끝 역 대신 붙인 앞 역, 키쿠치선 구선 1995 전 쿠로이시)
    // 그날 첫 행에서 잰다 (사용자 결정 2026-11-21)
    final base = route.role == 'branch' && rows.isNotEmpty ? rows.first.kmCum : null;
    if (base != null && base < 0) {
      for (var i = 0; i < rows.length; i++) {
        final km = rows[i].kmCum;
        if (km != null) rows[i] = rows[i].withKm(double.parse((km - base).toStringAsFixed(3)));
      }
    }
    return rows;
  }

  /// 정차가 끝난 뒤에도 이 계통에서 고를 수 있던(격하된 신호장 등) 마지막 해. 그 뒤에 끝났으면 폐지 해는 그 해다 (八幡口 1972 신호장 → 1996 폐지)
  String? _lastSelectYear(NetStop stop) {
    NetPeriod? last;
    for (final span in stop.selectSpans) {
      if (span.style == 'none' || span.style == 'moved' || span.period.toHi == null || span.period.toHi!.compareTo(DateSpan.maxDate) >= 0) continue;
      if ((span.period.toLo ?? '').compareTo(stop.period.toLo ?? '') <= 0) continue;
      if (last == null || span.period.toLo!.compareTo(last.toLo!) > 0) last = span.period;
    }
    return last == null ? null : yearLabel(last.toLo, last.toHi);
  }

  /// 그날(날짜를 모르면 지금 상태) 그 행을 서지 않고 고를 수 있는 기간. 없으면 고를 수 없다
  bool _movedOn(NetStop stop, DateSpan day) => stop.selectSpans.any(
      (span) => span.style == 'moved' && const [PeriodState.yes, PeriodState.maybe].contains(stateOfPeriod(day, span.period)));

  NetSelectSpan? _spanOn(NetStop stop, DateSpan? day) {
    for (final span in stop.selectSpans) {
      if (span.style == 'moved') continue;
      final on = day == null
          ? span.period.toHi == null || span.period.toHi!.compareTo(DateSpan.maxDate) >= 0
          : const [PeriodState.yes, PeriodState.maybe].contains(stateOfPeriod(day, span.period));
      if (on) return span;
    }
    return null;
  }

  /// 운휴가 시작된 해. 역 정차의 끝 없는 공백이 먼저고, 아니면 그 날 운휴인 앞뒤 칸의 운휴 시작 가운데 이른 것이다.
  /// 날짜를 모르면 지금(끝 없는 운휴 행) 기준이다
  String? _suspendedSince(NetStop stop, List<String> around, DateSpan? day) {
    if (_ended(stop.period) && day == null) return null;
    final gap = openStopGap(day, stop);
    if (gap != null) return yearLabel(gap.fromLo, gap.fromHi);
    NetPeriod? first;
    for (final edge in around) {
      for (final life in network.livesOf(edge)) {
        if (!life.suspended) continue;
        final on = day == null
            ? life.period.toHi == null || life.period.toHi!.compareTo(DateSpan.maxDate) >= 0
            : stateOfPeriod(day, life.period) == PeriodState.yes;
        if (!on) continue;
        if (first == null || (life.period.fromLo ?? '').compareTo(first.fromLo ?? '') < 0) first = life.period;
      }
    }
    return first == null ? null : yearLabel(first.fromLo, first.fromHi);
  }

  /// 계통 안에서 노드마다 닿는 구간.
  Map<String, List<String>> _around(String routeId) {
    final adjacent = <String, List<String>>{};
    for (final hop in network.hops(routeId)) {
      (adjacent[hop.a] ??= []).add(hop.edge);
      (adjacent[hop.b] ??= []).add(hop.edge);
    }
    return adjacent;
  }

  /// 이 계통의 구간을 이어받은 노선들의 계통 (DESIGN §8.0.1 이관 구간). 날짜와 상관없다.
  /// 화면은 이 계통들의 `route_link`를 읽어 [fillHanded]에 넘긴다
  Set<String> handRoutes(String routeId) {
    final line = network.routes[routeId]!.lineId;
    final lines = {
      for (final hop in network.hops(routeId)) ..._successors(line, hop.edge),
    };
    return {
      for (final other in lines) ...network.routesOfLine(other),
    };
  }

  /// 이관 구간 안의 역 줄을 이어받은 노선의 역·환승·분기로 채운다 (DESIGN §8.0.1 B안).
  ///
  /// 이관 뒤 생긴 역(しきぶ, 西松任)은 이 계통에 숨은 노드로 있어서 이 계통의 순번과 누적 km로 끼운다.
  /// 그래서 고르기·칠하기·저장이 이 계통 그대로 돌고, 날짜가 있으면 저장은 펼칠 때 그날 노선(이어받은 노선)으로 된다.
  /// 구간 안 역의 연결은 이어받은 노선의 것으로 바꾸고, 이 노선 쪽 연결은 이어받은 노선에 없는 것만 남긴다
  /// (이관 전에 끝난 옛 환승·분기. 그날은 끝났으니 폐선 표시다). [links]는 [handRoutes]의 계통별 연결이다.
  /// 이관 전 날짜면 그대로다.
  ///
  /// 날짜를 모르면 두 쪽 역을 합친 모든 역이 나온다. 날짜 모름에도 구분선이 있어 구간 안은 이어받은 노선의 구간이고,
  /// 날짜를 모르면 그 구간에 있던 역을 모두 고를 수 있어야 한다(DESIGN §8.0.1 상태표 아래). 이관 뒤 새 역을 골랐다면
  /// 탄 날이 이관 뒤라는 뜻이라 저장은 이어받은 노선 계통으로 나눈다(기록 화면). 두 쪽에 다 있는 역끼리면 지금처럼 이 노선이다
  List<SelectorRow> fillHanded(
    String routeId,
    List<SelectorRow> rows,
    DateSpan? date, {
    Map<String, List<SelectorLink>> links = const {},
  }) {
    if (!rows.any((row) => row.handedTo != null)) return rows;
    final day = normalizeRideDate(date);
    // 기준일보다 이른 날짜는 이관 전이다
    if (date != null && day == null) return rows;
    final line = network.routes[routeId]!.lineId;
    final around = _around(routeId);
    final aroundOf = <String, Map<String, List<String>>>{};
    final out = [...rows];
    final have = {for (final row in rows) row.seq};
    for (final stop in network.stops(routeId)) {
      if (stop.isStop || have.contains(stop.seq) || !network.data.publicNodes.contains(stop.node)) continue;
      final edges = around[stop.node] ?? const <String>[];
      var key = _handKey(line, edges);
      if (key == null) continue;
      // 이웃 역과 같은 노선으로 넘어갔으면 그 역의 이관 날을 따른다. 정차 기간과 구간 멤버십의 날이 달라도 구간이 갈리지 않게
      for (final next in [_nearest(rows, stop.seq, before: true), _nearest(rows, stop.seq, before: false)]) {
        if (next != null && next.handedTo == key!.$1 && next.handedOn != null) {
          key = (next.handedTo!, next.handedOn!);
          break;
        }
      }
      final later = {for (final edge in edges) ..._successors(line, edge)};
      final savedAs = day == null ? null : _dayLine(line, edges, day, later);
      // 이어받은 노선도 그날 끝났으면 저장할 노선은 없지만 구간은 그대로 이관 구간이라 그 역을 폐역으로 둔다 (神岡鉄道 2006 폐지 뒤의 神岡大橋)
      if (day != null && savedAs == null && !_handedBy(day, key!.$2)) continue;
      final found = _stopOn(savedAs == null ? later : {savedAs}, stop.node, day);
      if (found == null) continue;
      final (other, at) = found;
      final (state, selectable) = _state(other, at, (aroundOf[other] ??= _around(other))[stop.node] ?? const [], day);
      final row = SelectorRow(
        seq: stop.seq,
        node: stop.node,
        state: state,
        selectable: selectable,
        kmCum: stop.kmCum,
        kmEstimated: stop.kmEstimated,
        links: const [],
        savedAs: savedAs,
        openYear: yearLabel(at.period.fromLo, at.period.fromHi),
        closeYear: _ended(at.period) ? yearLabel(at.period.toLo, at.period.toHi) : null,
        handedTo: key!.$1,
        handedOn: key.$2,
        handedOnly: true,
        handedEnded: !_servedLater(line, stop.node, edges),
      );
      final place = out.indexWhere((other) => other.seq > stop.seq);
      out.insert(place < 0 ? out.length : place, row);
    }
    // 이어받은 노선의 연결을 노선·역별로 모은다. 연결의 순번은 그 노선 계통의 것이라 역으로 옮긴다
    final byLine = <String, Map<String, List<SelectorLink>>>{};
    for (final MapEntry(key: other, value: list) in links.entries) {
      final otherLine = network.routes[other]?.lineId;
      if (otherLine == null) continue;
      final nodeOf = {for (final stop in network.picks(other)) stop.seq: stop.node};
      for (final link in list) {
        final node = nodeOf[link.seq];
        if (node != null) ((byLine[otherLine] ??= {})[node] ??= []).add(link);
      }
    }
    return [
      for (final row in out)
        if (row.handedTo != null && row.handedOn != null && (day == null || row.savedAs != null || _handedBy(day, row.handedOn!)))
          _handLinks(row, line, day, byLine)
        else
          row,
    ];
  }

  /// 구간 안 역의 연결. 날짜가 있으면 그날 노선의 것, 날짜를 모르면 이어받은 노선들의 것이다.
  /// 이 노선이나 이 구간을 맡은 노선을 가리키는 연결은 구분선이 대신한다
  SelectorRow _handLinks(
    SelectorRow row,
    String line,
    DateSpan? day,
    Map<String, Map<String, List<SelectorLink>>> byLine,
  ) {
    final lines = day == null ? byLine.keys.toSet() : {row.savedAs ?? row.handedTo!};
    final band = {row.handedTo, row.savedAs, ...lines};
    String place(SelectorLink link) => '${link.otherLineId}\u0000${link.otherNode}';
    final seen = <String>{};
    final theirs = [
      for (final other in lines)
        for (final link in byLine[other]?[row.node] ?? const <SelectorLink>[])
          if (link.otherLineId != line &&
              !band.contains(link.otherLineId) &&
              seen.add('${link.kind}\u0000${place(link)}\u0000${link.validFromLo}\u0000${link.side}\u0000${link.flow}'))
            _moved(link, row.seq),
    ];
    // 같은 자리의 연결은 이어받은 노선 것이 대신한다. 다만 이 노선 시대의 선로 연결(이어짐·분기)은 이어받은 노선 쪽에 선로 연결이 없으면 남긴다.
    // 이어받은 노선의 환승만으로 덮으면 이관 전 선로 연결이 화면에서 사라진다 (二俣線 新所原 東海道本線 1936–1987 이어짐, 10회차 G1 chubu_1-014·S12)
    bool track(SelectorLink link) => link.kind == 'continue' || link.kind == 'branch';
    final taken = {for (final link in theirs) place(link)};
    final takenTrack = {for (final link in theirs) if (track(link)) place(link)};
    final mine = [
      for (final link in [...row.links, ...row.goneLinks])
        if (!band.contains(link.otherLineId) && (track(link) ? !takenTrack.contains(place(link)) : !taken.contains(place(link)))) link,
    ];
    final on = <SelectorLink>[];
    final gone = <SelectorLink>[];
    for (final link in [...theirs, ...mine]) {
      (day == null || _linkOn(link, day) ? on : gone).add(link);
    }
    return row._withLinks(on, gone);
  }

  SelectorLink _moved(SelectorLink link, int seq) => SelectorLink(
        seq: seq,
        kind: link.kind,
        otherLineId: link.otherLineId,
        otherRouteId: link.otherRouteId,
        validFromLo: link.validFromLo,
        validToHi: link.validToHi,
        side: link.side,
        flow: link.flow,
        otherNode: link.otherNode,
        nextStop: link.nextStop,
        terminal: link.terminal,
        midway: link.midway,
        reverseSpans: link.reverseSpans,
      );

  /// 그날이 이관된 날 뒤다. 이어받은 노선이 그날 서지 않아도 그 구간은 이관 구간이다 (DESIGN §8.0.1 구분선은 이관일 이후면 둔다)
  static bool _handedBy(DateSpan day, String on) => day.lo.compareTo(on) >= 0;

  /// [seq] 바로 앞(뒤) 역 줄.
  SelectorRow? _nearest(List<SelectorRow> rows, int seq, {required bool before}) {
    SelectorRow? found;
    for (final row in rows) {
      if (before ? row.seq < seq : row.seq > seq) {
        found = row;
        if (!before) break;
      }
    }
    return found;
  }

  /// 이 구간에서 이 노선이 끝난 뒤 같은 사슬로 이어받은 노선들. 이 노선이 아직 달리면 없다.
  Set<String> _successors(String line, String edge) {
    final mine = network.attrsOf(edge, line);
    if (mine.isEmpty || !mine.every((attr) => _ended(attr.period))) return const {};
    final end = _lastEnd(mine);
    final lineages = {for (final attr in mine) attr.lineageId};
    return {
      for (final attr in network.attrsOfEdge(edge))
        if (attr.lineId != line &&
            lineages.contains(attr.lineageId) &&
            (attr.period.fromHi ?? attr.period.fromLo ?? '').compareTo(end) >= 0)
          attr.lineId,
    };
  }

  /// 같은 사슬의 다른 노선이 지금도 이 역에 서는가.
  bool _servedLater(String line, String node, List<String> around) {
    final lineages = {
      for (final edge in around)
        for (final attr in network.attrsOf(edge, line)) attr.lineageId,
    };
    final later = {
      for (final edge in around)
        for (final attr in network.attrsOfEdge(edge))
          if (attr.lineId != line && lineages.contains(attr.lineageId)) attr.lineId,
    };
    return later.any((other) => network.routesOfLine(other).any((routeId) =>
        network.stops(routeId).any((stop) => stop.isStop && stop.node == node && !_ended(stop.period))));
  }

  /// 같은 사슬의 뒤 노선들에서 그 역이 마지막으로 끝난 해. 뒤 노선 어디서든 아직 서면 null이다
  String? _laterCloseYear(String line, String node, List<String> around) {
    final lineages = {
      for (final edge in around)
        for (final attr in network.attrsOf(edge, line)) attr.lineageId,
    };
    final later = {
      for (final edge in around)
        for (final attr in network.attrsOfEdge(edge))
          if (attr.lineId != line && lineages.contains(attr.lineageId)) attr.lineId,
    };
    NetPeriod? last;
    for (final other in later) {
      for (final routeId in network.routesOfLine(other)) {
        for (final stop in network.stops(routeId)) {
          if (!stop.isStop || stop.node != node) continue;
          if (!_ended(stop.period)) return null;
          if (last == null || stop.period.toHi!.compareTo(last.toHi!) > 0) last = stop.period;
        }
      }
    }
    return last == null ? null : yearLabel(last.toLo, last.toHi);
  }

  String _lastEnd(List<NetAttr> attrs) => attrs
      .map((attr) => attr.period.toLo ?? attr.period.toHi!)
      .reduce((end, to) => to.compareTo(end) > 0 ? to : end);

  /// 숨은 노드가 드는 이관 구간 (이어받은 노선, 넘어간 날). 닿는 구간이 모두 이 노선에서 끝나 다른 노선이 이어받았을 때만 있다.
  (String, String)? _handKey(String line, List<String> edges) {
    (String, String)? key;
    for (final edge in edges) {
      if (_successors(line, edge).isEmpty) return null;
      final end = _lastEnd(network.attrsOf(edge, line));
      final (next, _) = network.attrOn(edge, line, DateSpan.parse(end));
      if (next == null || next.lineId == line) return null;
      key ??= (next.lineId, end);
    }
    return key;
  }

  /// 그날 이 구간을 맡은 이어받은 노선.
  String? _dayLine(String line, List<String> edges, DateSpan day, Set<String> later) {
    for (final edge in edges) {
      final (attr, state) = network.attrOn(edge, line, day);
      if (attr != null && state == PeriodState.yes && later.contains(attr.lineId)) return attr.lineId;
    }
    return null;
  }

  /// [lines]의 계통에서 그 역에 서는 행. 그날 서는 행이 먼저다.
  (String, NetStop)? _stopOn(Iterable<String> lines, String node, DateSpan? day) {
    (String, NetStop)? found;
    for (final other in lines) {
      for (final routeId in network.routesOfLine(other)) {
        for (final stop in network.stops(routeId)) {
          if (!stop.isStop || stop.node != node) continue;
          final state = stateOfPeriod(day, stop.period);
          if (day == null || state == PeriodState.yes || state == PeriodState.maybe) return (routeId, stop);
          found ??= (routeId, stop);
        }
      }
    }
    return found;
  }

  /// 그날(날짜를 모르면 마지막 상태) 이 역에 이 계통이 서는가.
  bool _stopsOn(NetStop stop, DateSpan? day) {
    if (day == null) return !_ended(stop.period);
    if (inStopGap(day, stop)) return false;
    return const [PeriodState.yes, PeriodState.maybe].contains(stateOfPeriod(day, stop.period));
  }

  /// 그날(날짜를 모르면 지금) 이 노드에 닿는 칸 하나라도 탈 수 있는가.
  bool _ridable(String routeId, List<String> around, DateSpan? day) {
    if (day != null) return around.any((edge) => network.edgeUsable(routeId, edge, day).ridable);
    return around.any((edge) => network.livesOf(edge).any((life) => !life.suspended && (life.period.toHi == null || life.period.toHi!.compareTo(DateSpan.maxDate) >= 0)));
  }

  bool _ended(NetPeriod period) {
    final end = period.toHi;
    return end != null && end.compareTo(DateSpan.maxDate) < 0;
  }

  /// 행과 다음 행 사이가 그날 영업했는가. 날짜를 모르면 모두 1단계다 (DESIGN §8 상태표).
  List<bool> openBetween(String routeId, List<SelectorRow> rows, DateSpan? date) {
    final day = normalizeRideDate(date);
    if (rows.length < 2) return const [];
    if (day == null) return List.filled(rows.length - 1, true);
    return _between(
      routeId,
      rows,
      (edges) => edges.any((edge) => network.edgeUsable(routeId, edge, day).ridable),
      last: null,
    );
  }

  /// 행과 다음 행 사이 구간이 끝난 해와, [today]에 운휴 중인가 (DESIGN §8 구분선, 재설계 R11).
  /// 해는 구간 수명(없으면 이 노선 소속)이 끝난 날에서 읽고, 역의 폐역 연도로 짐작하지 않는다.
  /// [date]를 주면 그날 아직 개업 전인 구간(칸의 수명이 모두 그 뒤에 시작)의 개업 해도 낸다. 1950년 秋田市内線 秋田駅前–県庁前(1951 재개통)은
  /// 「~1966 폐지」가 아니라 「1951년 개업」이다 (11회차 시뮬레이터 시험)
  List<SectionEnd> sectionEnds(String routeId, List<SelectorRow> rows, DateSpan today, {DateSpan? date}) {
    final lineId = network.routes[routeId]!.lineId;
    final stops = network.stops(routeId);
    return [
      for (var i = 0; i + 1 < rows.length; i++)
        () {
          final edges = <String>{
            for (var at = 0; at < stops.length; at++)
              if (stops[at].seq >= rows[i].seq && stops[at].seq < rows[i + 1].seq)
                for (var to = at + 1; to < stops.length && to <= at + 4 && stops[to].seq <= rows[i + 1].seq; to++)
                  ...network.edgesBetween(routeId, stops[at].node, stops[to].node),
          };
          final suspended = edges.any((edge) => network.lifeOn(edge, today) == LifeState.suspended);
          String? lo, hi;
          for (final edge in edges) {
            NetPeriod? last;
            // 수명은 운휴 행까지다. 운휴인 채 폐지된 칸은 폐지 신고일이 끝이다(高千穂線 ~2007·~2008. 운휴 시작 2005가 아님, 감사 2회차 K33).
            // 이 노선 소속은 보통 폐지일까지라 같은 해가 나오고, 이관 뒤에 운휴·폐지된 칸만 달라진다
            for (final period in [...network.livesOf(edge).map((l) => l.period), ...network.attrsOf(edge, lineId).map((a) => a.period)]) {
              final to = period.toHi;
              if (to == null || to.compareTo(DateSpan.maxDate) >= 0) continue;
              if (last == null || to.compareTo(last.toHi!) > 0) last = period;
            }
            if (last == null) continue;
            if (hi == null || last.toHi!.compareTo(hi) > 0) (lo, hi) = (last.toLo, last.toHi);
          }
          String? opens;
          if (date != null && edges.isNotEmpty && edges.every((edge) => network.lifeOn(edge, date) == LifeState.before)) {
            String? first, firstHi;
            for (final edge in edges) {
              for (final life in network.livesOf(edge)) {
                final from = life.period.fromLo;
                if (from != null && (first == null || from.compareTo(first) < 0)) (first, firstHi) = (from, life.period.fromHi);
              }
            }
            if (first != null) opens = yearLabel(first, firstHi ?? first);
          }
          return SectionEnd(year: hi == null ? null : yearLabel(lo, hi), suspended: suspended, opens: opens);
        }(),
    ];
  }

  /// 행과 다음 행 사이를 이미 탔는가. 숨은 역을 지나면 사이의 구간을 다 타야 한다.
  List<bool> riddenBetween(String routeId, List<SelectorRow> rows, Set<int> ridden) => _between(
        routeId,
        rows,
        (edges) => edges.any((edge) => ridden.contains(network.edges[edge]!.n)),
        last: false,
      );

  /// 계통 순서의 이웃 역 사이마다 [ok]한 칸이 덮는지 본다. 옛 선형과 새 선형의 역이 km 순으로 섞인 계통(常磐線 新地~山下)은
  /// 그날의 칸이 몇 역 건너 이어지므로, 세 역 안에서 이어지는 칸이 그 사이를 덮으면 이어진 것이다
  /// 사이에 이 계통의 역이 없는 칸(확장 행 사이)은 [empty]가 정하고, 없으면 끊긴 칸이다
  List<bool> _between(
    String routeId,
    List<SelectorRow> rows,
    bool Function(List<String> edges) ok, {
    bool? last,
    bool Function(SelectorRow a, SelectorRow b)? empty,
  }) {
    final stops = network.stops(routeId);
    final covered = List.filled(stops.length, false);
    for (var at = 0; at + 1 < stops.length; at++) {
      for (var to = at + 1; to < stops.length && to <= at + 4; to++) {
        if (!ok(network.edgesBetween(routeId, stops[at].node, stops[to].node))) continue;
        for (var k = at; k < to; k++) {
          covered[k] = true;
        }
      }
    }
    return [
      for (var i = 0; i + 1 < rows.length; i++)
        () {
          final inside = [
            for (var at = 0; at + 1 < stops.length; at++)
              if (stops[at].seq >= rows[i].seq && stops[at].seq < rows[i + 1].seq) covered[at],
          ];
          if (inside.isEmpty) return empty?.call(rows[i], rows[i + 1]) ?? false;
          return inside.every((open) => open);
        }(),
      if (last != null && rows.isNotEmpty) last,
    ];
  }

  (StopState, bool) _state(String routeId, NetStop stop, List<String> around, DateSpan? day) {
    final period = stateOfPeriod(day, stop.period);
    final lines = [for (final edge in around) network.edgeUsable(routeId, edge, day)];
    if (day == null) return (StopState.unknown, true);
    if (period == PeriodState.before) return (StopState.beforeOpen, false);
    if (openStopGap(day, stop) != null) return (StopState.suspended, false);
    if (inStopGap(day, stop)) return (StopState.closed, false);
    if (period == PeriodState.after) return (StopState.closed, false);
    if (lines.contains(Usable.ok) && period == PeriodState.yes) return (StopState.open, true);
    if (lines.contains(Usable.ok) || lines.contains(Usable.maybe)) return (StopState.maybe, true);
    if (lines.contains(Usable.suspended)) return (StopState.suspended, false);
    if (around.isNotEmpty && lines.every((u) => u == Usable.no)) {
      return (StopState.lineClosed, false);
    }
    return (StopState.noEdge, false);
  }

  /// 다른 노선으로 저장되는 역도 그 노선에서 그날 탈 수 있어야 고른다. 운휴면 운휴로 보인다 (いすみ鉄道 2024 운휴 중의 国鉄 木原線)
  (StopState, bool) _savedState(String lineId, List<String> around, DateSpan day) {
    final uses = [
      for (final routeId in network.routesOfLine(lineId))
        for (final edge in around) network.edgeUsable(routeId, edge, day),
    ];
    if (uses.any((u) => u.ridable)) return (StopState.open, true);
    if (uses.contains(Usable.suspended)) return (StopState.suspended, false);
    return (StopState.lineClosed, false);
  }

  /// [ended] 전날 이 역의 칸 가운데 하나가 이 노선 것이었는가.
  bool _ownedUntil(String lineId, List<String> around, String ended) {
    if (DateTime.tryParse(ended) == null) return true;
    final day = DateSpan.parse(dayBefore(ended));
    return around.any((edge) => network.attrOn(edge, lineId, day).$1?.lineId == lineId);
  }

  /// 이관 전 날짜는 같은 사슬의 앞 노선에서 정차 기간을 찾는다 (ARCHITECTURE §3.5).
  String? _earlierLine(String lineId, String node, List<String> around, DateSpan day) {
    String? found;
    for (final edge in around) {
      final (attr, _) = network.attrOn(edge, lineId, day);
      if (attr == null || attr.lineId == lineId) continue;
      for (final routeId in network.routesOfLine(attr.lineId)) {
        for (final stop in network.stops(routeId)) {
          if (stop.node != node || !stop.isStop) continue;
          final state = stateOfPeriod(day, stop.period);
          if (state == PeriodState.yes || state == PeriodState.maybe) found = attr.lineId;
        }
      }
    }
    return found;
  }

  /// 범위 날짜는 기간과 겹치면 그린다. 그 범위 안 어느 날에는 이어져 있었다.
  bool _linkOn(SelectorLink link, DateSpan day) {
    final from = link.validFromLo;
    final to = link.validToHi;
    return (from == null || from.compareTo(day.hi) <= 0) && (to == null || day.lo.compareTo(to) < 0);
  }
}

/// 숨긴 경계점 행의 연결을 이웃한 끝 행으로 옮기기 위한 임시 목록
final class _Carry {
  final List<SelectorLink> _items = [];
  bool get isNotEmpty => _items.isNotEmpty;
  void addAll(Iterable<SelectorLink> links) => _items.addAll(links);
  List<SelectorLink> splice() {
    final out = List<SelectorLink>.of(_items);
    _items.clear();
    return out;
  }
}
