import '../date/date_span.dart';
import 'display_rules.dart';
import 'network.dart';
import 'selector.dart';

/// 한 계통의 그날 선택기 행과 행 사이 상태 (선택기 계산 그대로, DESIGN §8.0.1).
final class RouteRows {
  const RouteRows({
    required this.routeId,
    required this.rows,
    required this.openGaps,
    required this.sectionGaps,
    required this.sectionEnds,
  });

  final String routeId;

  /// 체크박스를 거친 행 (보이는 행).
  final List<SelectorRow> rows;
  final List<bool> openGaps;
  final List<bool> sectionGaps;
  final List<SectionEnd> sectionEnds;
}

/// 그날 다니지 않던 같은 노선 선형 하나. 선로가 갈라지는 역에 붙는다 (DESIGN §8.3).
final class StitchFold {
  const StitchFold({
    required this.anchor,
    required this.up,
    required this.rows,
    required this.period,
    required this.next,
    required this.last,
    required this.count,
    this.rejoin,
    this.dead = false,
    this.frame,
  });

  /// 괄호를 셀 때 쓰는 행: 접힌 선형 행 앞(위로 붙으면 뒤)에 붙는 본선 역, 돌아오면 끝에 돌아오는 본선 역을 더했다(본선 seq 그대로).
  /// 괄호가 갈라지는 역·돌아오는 역까지 걸치면 그 끝에서 갈고리로 끝난다 (목업의 HEAD·TAIL, DESIGN §8.3)
  final RouteRows? frame;

  /// 붙는 본선 행의 seq. [up]이면 그 행 위, 아니면 아래다.
  final int anchor;
  final bool up;

  /// 접힌 선형의 행 (seq는 본선과 겹치지 않는 새 번호). 위로 붙으면 화면 순서(아래에서 위로 갈수록 멀다)대로다.
  final RouteRows rows;

  /// 본선으로 돌아오는 역의 seq. 돌아오지 않으면 null.
  final int? rejoin;

  /// 「~1983」「1957~」.
  final String period;
  final String next;
  final String last;
  final int count;

  /// 날짜 모름인데 품은 구간이 폐지돼 함께 죽었다 (고를 수 없다).
  final bool dead;

  /// 역 하나뿐이라 접지 않고 꺾여 나간 선 위에 바로 보인다 (「]」).
  bool get single => count == 1;
}

/// 행 하나의 출처.
typedef StitchOrigin = ({String routeId, int seq});

/// 그날의 노선 한 줄 (DESIGN §8.3).
final class StitchedLine {
  const StitchedLine({
    required this.main,
    required this.folds,
    required this.origin,
    required this.used,
    required this.lengthKm,
    required this.foreignKm,
  });

  /// 본선 줄 (seq는 새 번호).
  final RouteRows main;
  final List<StitchFold> folds;

  /// 새 seq → 원래 계통과 seq. 접힌 줄 행도 들어 있다.
  final Map<int, StitchOrigin> origin;

  /// 이 줄에 쓴 계통 (칩에서 빠진다).
  final Set<String> used;

  /// 이 노선 구간 길이의 합 (제목).
  final double lengthKm;

  /// km가 이어받은 노선의 km인 행(이관 띠 안)의 새 seq. 흐리게 적는다.
  final Set<int> foreignKm;

  /// 고른 두 행 사이를 지나는 계통들 (계통마다 나눠 저장할 때 쓴다).
  Set<String> routesOf(Iterable<int> seqs) => {for (final s in seqs) ?origin[s]?.routeId};
}

typedef RouteScreen = RouteRows? Function(String routeId, DateSpan? date);

/// 같은 노선의 계통들을 그날의 한 줄로 잇는다 (DESIGN §8.3, 기준 구현 tools/dev/stitch_mock.py).
final class LineStitcher {
  LineStitcher(this.network, {required this.today, required this.screen, this.extra = const {}});

  final Network network;

  /// 오늘 (그날 다니는지와 달리 「오늘도 다니는가」를 가릴 때).
  final DateSpan today;

  /// 계통의 그날 행. 날짜 모름은 null 날짜다.
  final RouteScreen screen;

  /// 섞지 않는 화물·임시 계통.
  final Set<String> extra;

  /// 본선이 이미 가져간 계통 (지선 칩이 못 쓴다).
  final Set<String> claimed = {};

  StitchedLine stitch(String lineId, String mainRoute, DateSpan? date, {Set<String> exclude = const {}}) =>
      _Stitch(this, lineId, mainRoute, date, exclude).run();

  /// 이 노선의 계통과, 한때 이 노선에 속했던 다른 노선 계통 (`line_period` member, 例 柳ヶ瀬線 = 北陸本線 ~1957).
  /// 구간만 속했던 것(唐津線 山本–唐津 = 筑肥線 1983~1987)은 아직 넣지 않는다
  static List<String> routesFor(Network network, String lineId) => [
        ...network.routesOfLineMainFirst(lineId),
        for (final m in network.data.members)
          if (m.memberOf == lineId && m.fromNode == null)
            for (final r in network.routesOfLine(m.lineId)) r,
      ];

  /// 그날 이 노선의 조각인 계통. 날짜 모름이면 한때라도 속했던 계통 모두다
  static List<String> routesOn(Network network, String lineId, DateSpan? date) => [
        ...network.routesOfLineMainFirst(lineId),
        for (final m in network.data.members)
          if (m.memberOf == lineId && m.fromNode == null && (date == null || m.on(date.lo)))
            for (final r in network.routesOfLine(m.lineId)) r,
      ];
}

bool _open(SelectorRow r) => r.state == StopState.open || r.state == StopState.maybe || r.state == StopState.unknown;

final class _R {
  _R(this.row, this.route);

  SelectorRow row;
  final String route;
  bool dropLinks = false;
  String get node => row.node;
}

final class _Fold {
  _Fold({required this.anchor, required this.up, required this.rows, required this.period, this.rejoin});

  _R anchor;
  final bool up;
  final List<_R> rows;
  String period;
  final String? rejoin;
}

final class _Stitch {
  _Stitch(this.s, this.lineId, this.mainRoute, this.date, this.exclude);

  final LineStitcher s;
  final String lineId;
  final String mainRoute;
  final DateSpan? date;
  final Set<String> exclude;

  late final List<String> lineRoutes = LineStitcher.routesOn(s.network, lineId, date);
  final used = <String>{};
  final done = <String>{};
  var items = <_R>[];
  final folds = <_Fold>[];

  Network get net => s.network;

  RouteRows? rows(String r) => _member(r, s.screen(r, date));
  RouteRows? undated(String r) => _member(r, s.screen(r, null));
  RouteRows? todays(String r) => s.screen(r, s.today);

  /// 한때 이 노선에 속했던 계통은 그 기간의 모습이다: 나뉜 뒤에 생긴 역은 이 노선 역이었던 적이 없고, 그 뒤 폐역은 나뉜 해로 본다
  late final Map<String, String> _until = {
    for (final m in s.network.data.members)
      if (m.memberOf == lineId && m.fromNode == null && m.validTo != null)
        for (final r in s.network.routesOfLine(m.lineId)) r: m.validTo!.substring(0, 4),
  };
  late final Map<String, String> _untilDay = {
    for (final m in s.network.data.members)
      if (m.memberOf == lineId && m.fromNode == null && m.validTo != null)
        for (final r in s.network.routesOfLine(m.lineId)) r: m.validTo!,
  };
  final _memberCache = <String, RouteRows?>{};
  RouteRows? _member(String r, RouteRows? rr) {
    final until = _until[r];
    if (until == null || rr == null) return rr;
    return _memberCache.putIfAbsent('$r\u0000${identityHashCode(rr)}', () {
      final keep = <int>[for (var k = 0; k < rr.rows.length; k++) if ((rr.rows[k].openYear ?? '0000').compareTo(until) < 0) k];
      List<T> gaps<T>(List<T> g) => [for (var i = 0; i + 1 < keep.length; i++) if (keep[i] < g.length) g[keep[i]]];
      return RouteRows(
        routeId: r,
        rows: [
          for (final k in keep)
            if (rr.rows[k].closeYear case final c? when c.compareTo(until) > 0) rr.rows[k].copy(closeYearAs: until, closedOnAs: _untilDay[r]) else rr.rows[k],
        ],
        openGaps: gaps(rr.openGaps),
        sectionGaps: gaps(rr.sectionGaps),
        // 칸의 폐지 해도 이 노선의 조각으로서 끝난 해(나뉜 해)로 자른다
        sectionEnds: [
          for (final e in gaps(rr.sectionEnds))
            if (e.year case final y? when y.compareTo(until) > 0) SectionEnd(year: until, suspended: false, opens: e.opens) else e,
        ],
      );
    });
  }

  bool free(String r) =>
      !used.contains(r) && !exclude.contains(r) && !s.claimed.contains(r) && !s.extra.contains(r) && lineRoutes.contains(r) && rows(r) != null;

  bool openOn(String r, RouteRows? rr) => rr != null && rr.rows.any(_open);

  bool liveToday(String r) => openOn(r, todays(r));

  /// 길을 고를 때 보는 그날 상태. 날짜 모름은 가장 최신 상태(오늘)로 고른다. 그리는 행은 날짜 모름 그대로다 (DESIGN §8.3)
  bool openThen(_R x) {
    if (date != null) return _open(x.row);
    final t = todays(x.route);
    return t != null && t.rows.any((r) => r.node == x.node && _open(r));
  }

  int idx(String node) => items.indexWhere((x) => x.node == node);

  Iterable<SelectorLink> sameLineLinks(SelectorRow row) => [...row.links, ...row.goneLinks]
      .where((l) => (l.kind == 'branch' || l.kind == 'continue') && l.otherRouteId != null && lineRoutes.contains(l.otherRouteId));

  /// 링크가 가리키는 계통. 같은 노선이면 그 계통이고, 링크에 계통이 없으면 다음 역이 있는 계통이다
  String? r2Of(SelectorLink l) {
    final r = l.otherRouteId;
    if (r != null && free(r)) return r;
    return null;
  }

  ({int? lo, int? hi}) span(List<SelectorRow> rs) {
    int? year(String? y) => y == null ? null : int.tryParse(y.length >= 4 ? y.substring(0, 4) : y);
    final oy = [for (final r in rs) ?year(r.openYear)];
    final cy = [for (final r in rs) ?year(r.closeYear)];
    final live = rs.any((r) => r.closeYear == null);
    return (lo: oy.isEmpty ? 0 : oy.reduce((a, b) => a < b ? a : b), hi: live || cy.isEmpty ? 9999 : cy.reduce((a, b) => a > b ? a : b));
  }

  bool exclusive(({int? lo, int? hi}) a, ({int? lo, int? hi}) b) => a.hi! <= b.lo! || b.hi! <= a.lo!;

  /// r2의 행을 [a] 역에서 바깥쪽으로 (a 제외), [b]가 있으면 그 앞까지.
  List<_R> walk(String r2, String a, {String? b, bool? forward}) {
    final rs = rows(r2)!.rows;
    final ka = rs.indexWhere((x) => x.node == a);
    final kb = b == null ? -1 : rs.indexWhere((x) => x.node == b);
    final fwd = forward ?? (kb >= 0 ? kb > ka : ka == 0);
    if (fwd) return [for (final row in rs.sublist(ka + 1, kb >= 0 ? kb : rs.length)) _R(row, r2)];
    return rev([for (final row in rs.sublist(kb >= 0 ? kb + 1 : 0, ka)) _R(row, r2)]);
  }

  /// 행을 거꾸로 놓는다. 거꾸로 읽은 행의 분기 자리·환승 흐름도 뒤집는다 (두 번 뒤집으면 원래대로다)
  List<_R> rev(List<_R> list) => [
        for (final x in list.reversed)
          _R(x.row.withLinksBoth([for (final l in x.row.links) l.flipped()], [for (final l in x.row.goneLinks) l.flipped()]), x.route),
      ];

  /// 그 링크 줄이 역 위쪽인가. 끝 이어짐은 줄의 첫 역이면 위쪽이다
  bool upOf(_R at, SelectorLink l) => l.kind == 'continue' ? identical(items.first, at) || items.first.node == at.node && items.length > 1 && items.last.node != at.node : l.side == 'up';

  String? yearOf(String? y) => y == null || y.length < 4 ? null : y.substring(0, 4);

  String periodOld(List<_R> rs) {
    final cy = [for (final r in rs) ?yearOf(r.row.closeYear)];
    if (cy.length != rs.length || cy.isEmpty) return '';
    return '~${cy.reduce((a, b) => a.compareTo(b) > 0 ? a : b)}';
  }

  String periodNew(List<_R> rs) {
    final oy = [for (final r in rs) ?yearOf(r.row.openYear)];
    return oy.isEmpty ? '' : '${oy.reduce((a, b) => a.compareTo(b) < 0 ? a : b)}~';
  }

  /// 옛 선형(old)을 갈아 끼운 본선 선형(path: 갈라지는 역 … 다시 만나는 역)이 그 노선의 길이 된 해.
  /// 옛 선형이 닫힌 날(c)과, c 뒤까지 이어지는 그 선형 칸의 열린 기간이 모두 시작된 날 가운데 늦은 쪽이다.
  /// 운휴 뒤 새 선형 개업(常磐線 2016, 仙石線 2015), 옛 선형 일부가 먼저 닫힘(室蘭本線 1978), 운휴했다 다시 연 선형(近鉄京都線 1968),
  /// 선형보다 늦게 생긴 역이 모두 이 규칙 하나로 맞는다. 칸을 못 찾으면 역 해로 어림한다.
  String periodBuilt(List<String> path, List<_R> old, List<_R> rs) {
    final cs = [for (final x in old) ?x.row.closeYear]..sort();
    final c = cs.isEmpty ? null : cs.first;
    var built = c;
    for (var k = 0; k + 1 < path.length; k++) {
      final es = net.edgesBetween(mainRoute, path[k], path[k + 1]);
      if (es.isEmpty) return periodAfter(old, rs);
      for (final e in es) {
        final from = [
          for (final l in net.livesOf(e))
            if (!l.suspended && (c == null || l.period.toHi == null || l.period.toHi!.compareTo(c) > 0)) ?l.period.fromLo,
        ]..sort();
        if (from.isEmpty) return periodAfter(old, rs);
        if (built == null || from.first.compareTo(built) > 0) built = from.first;
      }
    }
    final y = built == null ? null : yearOf(built);
    return y == null ? periodAfter(old, rs) : '$y~';
  }

  /// 옛 선형(old)을 갈아 끼운 선형(rs)의 시작 해. 옛 선형이 닫힌 해와 새 선형 역이 처음 연 해 가운데 늦은 쪽이다.
  /// 둘 사이가 비면(운휴 뒤 새 선형 개업) 새 선형 개업 해, 옛 역을 그대로 쓰는 새 선형이면 옛 선형이 닫힌 해다.
  String periodAfter(List<_R> old, List<_R> rs) {
    final cy = [for (final x in old) ?yearOf(x.row.closeYear)];
    final oy = [for (final r in rs) ?yearOf(r.row.openYear)];
    final c = cy.isEmpty ? null : cy.reduce((a, b) => a.compareTo(b) < 0 ? a : b);
    final o = oy.isEmpty ? null : oy.reduce((a, b) => a.compareTo(b) < 0 ? a : b);
    final y = c == null ? o : o == null || c.compareTo(o) >= 0 ? c : o;
    return y == null ? '' : '$y~';
  }

  /// r2 끝 역에서 이어지는 같은 노선 계통.
  List<_R> tailOf(String r2, String lastNode, bool closed) {
    for (final row in rows(r2)!.rows) {
      for (final l in sameLineLinks(row)) {
        if (net.stops(mainRoute).any((m) => m.node == l.nextStop)) continue;
        final r3 = r2Of(l);
        if (r3 == null) continue;
        final r3rows = rows(r3)!.rows;
        final r2nodes = {for (final x in rows(r2)!.rows) x.node};
        final jn = r3rows.firstWhere((x) => r2nodes.contains(x.node), orElse: () => r3rows.first).node;
        if (jn != lastNode) continue;
        if (closed && openOn(r3, date == null ? todays(r3) : rows(r3))) continue;
        used.add(r3);
        return [
          for (final x in walk(r3, jn))
            closed && date != null ? (_R(_closed(x.row), r3)) : x,
        ];
      }
    }
    return [];
  }

  SelectorRow _closed(SelectorRow r) => r.copy(state: _open(r) ? StopState.closed : r.state, selectable: false);

  void zeroOwn(String r2) {
    used.add(r2);
    final rs = rows(r2)!.rows;
    final ends = {for (final x in rs) x.node};
    final ix = [for (final n in ends) idx(n)]..sort();
    if (ix.first < 0) return;
    final lo = ix.first, hi = ix.last;
    final betweenOpen = [for (var k = lo + 1; k < hi; k++) items[k]].any((x) => _open(x.row));
    if (!(date != null && ends.length >= 2 && rs.every(_open) && !liveToday(r2) && !betweenOpen)) return;
    final byNode = {for (final x in rs) x.node: x};
    for (var k = lo + 1; k <= hi; k++) {
      final src = byNode[items[k].node] ?? items[k].row;
      items[k] = _R(src.copy(state: StopState.open, selectable: true, clearClose: true), r2);
    }
  }

  StitchedLine run() {
    final main = rows(mainRoute);
    if (main == null) return const StitchedLine(main: RouteRows(routeId: '', rows: [], openGaps: [], sectionGaps: [], sectionEnds: []), folds: [], origin: {}, used: {}, lengthKm: 0, foreignKm: {});
    used.add(mainRoute);
    items = [for (final r in main.rows) _R(r, mainRoute)];
    for (var guard = 0; guard < 60; guard++) {
      // 처리하지 않은 같은 노선 링크 하나
      _R? at;
      SelectorLink? link;
      for (final x in items) {
        for (final l in sameLineLinks(x.row)) {
          final key = '${x.route}\u0000${x.row.seq}\u0000${l.otherRouteId}\u0000${l.nextStop}';
          if (done.contains(key)) continue;
          done.add(key);
          at = x;
          link = l;
          break;
        }
        if (link != null) break;
      }
      if (link == null || at == null) break;
      final r2 = r2Of(link);
      if (r2 == null) continue;
      final r2rows = rows(r2)!.rows;
      if (r2rows.isEmpty) continue;
      final mn = {for (final x in items) x.node};
      final sh = [for (var k = 0; k < r2rows.length; k++) if (mn.contains(r2rows[k].node)) k];
      if (sh.isEmpty) continue;
      // 첫 역과 마지막 역을 잇는 조각은 고리를 닫는다
      final first = items.first.node, last = items.last.node;
      if (items.length > 2 && first != last && {r2rows.first.node, r2rows.last.node}.containsAll({first, last})) {
        used.add(r2);
        final closing = r2rows.firstWhere((x) => x.node == first);
        items = [...items, ...walk(r2, last, b: first), _R(closing, r2)];
        continue;
      }
      // 따로 된 역이 없는 계통
      if (r2rows.every((x) => mn.contains(x.node))) {
        zeroOwn(r2);
        continue;
      }
      final bypass = sh.contains(0) && sh.contains(r2rows.length - 1) && r2rows.length > 2;
      late String a;
      String? b;
      late int ia;
      late int ib;
      late List<_R> own;
      late List<int> region;
      if (bypass) {
        a = r2rows.first.node;
        b = r2rows.last.node;
        ia = idx(a);
        ib = idx(b);
        if (ia > ib) {
          (a, b) = (b, a);
          (ia, ib) = (ib, ia);
        }
        own = walk(r2, a, b: b);
        region = [for (var k = ia + 1; k < ib; k++) k];
      } else {
        final jr = sh.last < r2rows.length - 1 ? sh.last : sh.first;
        a = r2rows[jr].node;
        ia = idx(a);
        ib = ia;
        own = walk(r2, a, forward: jr == sh.last && jr < r2rows.length - 1);
        final up = upOf(at, link);
        region = up ? [for (var k = 0; k < ia; k++) k] : [for (var k = ia + 1; k < items.length; k++) k];
      }
      if (own.isEmpty) continue;
      final mainLive = region.any((k) => openThen(items[k]));
      final r2Open = own.any(openThen);
      // 같은 시기에 함께 다닌 구간은 진짜 지선이다. 다만 그날 그 구간의 유일한 길이면 잇는다 (날짜별, 결정 B)
      if (region.isNotEmpty) {
        final whole2 = (undated(r2) ?? rows(r2)!).rows.where((x) => !mn.contains(x.node)).toList();
        final regNodes = {for (final k in region) items[k].node};
        final wholeMain = (undated(mainRoute) ?? main).rows.where((x) => regNodes.contains(x.node)).toList();
        if (wholeMain.isNotEmpty && whole2.isNotEmpty && !exclusive(span(whole2), span(wholeMain)) && !(r2Open && !mainLive)) continue;
      }
      if (liveToday(r2) && mainLive && !bypass) continue;
      used.add(r2);
      final up = !bypass && upOf(at, link);
      if (r2Open && !mainLive) {
        // 그날의 길이 r2다: 본선 줄에 잇고, 본선의 그 구간은 다른 시기 선형으로 접는다
        final frows = [for (final k in region) _R(items[k].row.copy(selectable: date == null && items[k].row.selectable), items[k].route)];
        final seq = <_R>[...own];
        if (!bypass) {
          final tail = tailOf(r2, own.last.node, false);
          seq.addAll(date != null && tail.every((x) => !_open(x.row)) ? [for (final x in tail) _R(_closed(x.row), x.route)] : tail);
        }
        if (bypass) {
          final anchorRow = items[ia];
          items = [...items.sublist(0, ia + 1), ...seq, ...items.sublist(ib)];
          if (frows.isNotEmpty) {
            folds.add(_Fold(anchor: anchorRow, up: false, rows: frows, rejoin: b, period: periodBuilt([items[ia].node, for (final x in frows) x.node, ?b], own, frows)));
          }
        } else if (!up) {
          final anchorRow = items[ia];
          items = [...items.sublist(0, ia + 1), ...seq];
          if (frows.isNotEmpty) folds.add(_Fold(anchor: anchorRow, up: false, rows: frows, period: periodNew(frows)));
        } else {
          final anchorRow = items[ia];
          items = [...rev(seq), ...items.sublist(ia)];
          // 접힌 행은 늘 화면 순서(위→아래)다. 본선 구간(region)은 이미 그 순서라 뒤집지 않는다(瀬戸線 1965 栄町·東大手, 総武本線 1965 東京–錦糸町)
          if (frows.isNotEmpty) folds.add(_Fold(anchor: anchorRow, up: true, rows: frows, period: periodNew(frows)));
        }
        continue;
      }
      if (region.isEmpty && !bypass) {
        // 줄 끝 너머로 곧게 이어지는 구간
        final closed = date != null && own.every((x) => !_open(x.row));
        final rowsOut = [for (final x in own) closed ? _R(_closed(x.row), x.route) : x];
        items = up ? [...rev(rowsOut), ...items.sublist(ia)] : [...items.sublist(0, ia + 1), ...rowsOut, ...items.sublist(ia + 1)];
        continue;
      }
      // 다른 시기 선형: 갈라지는 역에 접힌 줄 하나
      // 오늘도 다니는 같은 노선 구간(筑肥線 山本~伊万里)은 접힌 옛 선형의 꼬리로 끌어오지 않는다. 그 구간은 칩이다
      final tail = bypass ? <_R>[] : tailOf(r2, own.last.node, true);
      final frows = [for (final x in [...own, ...tail]) _R(x.row.copy(selectable: date == null && x.row.selectable), x.route)];
      folds.add(_Fold(anchor: items[ia], up: up, rows: up ? rev(frows) : frows, rejoin: b, period: periodOld(own)));
    }
    // 그날 열린 줄 끝에서 같은 노선 조각이 하나만 이어지면 한 줄이다 (둘 이상이면 갈라짐이라 칩)
    while (items.isNotEmpty) {
      final t = items.last;
      if (!openThen(t)) break;
      final have = {for (final x in items) x.node};
      final cand = [
        for (final r in lineRoutes)
          if (free(r))
            if ((date == null ? todays(r) : rows(r))?.rows case final rs?
                when rs.isNotEmpty && rs.first.node == t.node && rs.take(2).every((x) => x.state != StopState.beforeOpen) && !rs.skip(1).any((x) => have.contains(x.node)))
              r,
      ];
      if (cand.length != 1) break;
      used.add(cand.single);
      items = [...items, ...walk(cand.single, t.node)];
    }
    // 이어짐 줄이 가리키지 않아도 따로 된 역이 없는 계통은 같은 규칙이다
    for (final r in lineRoutes) {
      if (!free(r)) continue;
      final rs = rows(r)!.rows;
      final mn = {for (final x in items) x.node};
      if (rs.isNotEmpty && rs.every((x) => mn.contains(x.node))) zeroOwn(r);
    }
    if (exclude.isEmpty) s.claimed.addAll(used.difference({mainRoute}));
    // 그날 이 줄에 쓴 계통으로 가는 같은 노선 링크는 지운다
    bool keep(SelectorLink l) => !used.contains(l.otherRouteId) || l.kind == 'transfer';
    for (final x in items) {
      x.row = x.row.withLinksBoth([for (final l in x.row.links) if (keep(l)) l], [for (final l in x.row.goneLinks) if (keep(l)) l]);
    }
    // 접힌 선형 안에는 같은 노선 다른 계통으로 가는 이어짐을 그리지 않는다. 그 계통은 본선 줄이거나 다른 접힌 줄·칩이다
    // 본선 줄에 같은 노선·같은 다음 역 이어짐이 이미 있으면 접힌 선형에서 또 그리지 않는다 (筑肥線 博多（旧）의 鹿児島本線 吉塚 방면)
    final mainLinks = {
      for (final x in items)
        for (final l in [...x.row.links, ...x.row.goneLinks])
          if (l.kind != 'transfer') '${l.otherLineId}\u0000${l.nextStop}',
    };
    bool keepInFold(SelectorLink l) =>
        l.kind == 'transfer' || (!lineRoutes.contains(l.otherRouteId) && !mainLinks.contains('${l.otherLineId}\u0000${l.nextStop}'));
    for (final f in folds) {
      for (final x in f.rows) {
        x.row = x.row.withLinksBoth([for (final l in x.row.links) if (keepInFold(l)) l], [for (final l in x.row.goneLinks) if (keepInFold(l)) l]);
      }
    }
    // 이관 표시가 붙은 역이라도 이은 같은 노선의 다른 계통에 그날 그 역이 자기 역(이관 표시 없음)으로 있으면 그 행을 쓴다.
    // 그 역이 이관 띠의 끝이자 다음 구간의 기점이다 (鹿児島本線 川内: 본선 계통에서는 이관 구간 끝 역, 川内~鹿児島 계통에서는 기점)
    final ownRow = <String, (SelectorRow, String)>{};
    for (final r in used) {
      for (final x in rows(r)?.rows ?? const <SelectorRow>[]) {
        // 그날(날짜 모름은 지금) 그 계통의 현재 역일 때만이다. 끝난 옛 선형(北陸本線 谷浜–直江津 ~1969)의 행은 쓰지 않는다
        if (x.handedTo == null && x.savedAs == null && (date == null ? x.closeYear == null : _open(x))) ownRow.putIfAbsent('${x.node}\u0000$r', () => (x, r));
      }
    }
    items = [
      for (final x in items)
        if (x.row.handedTo != null || x.row.savedAs != null)
          if ([for (final r in used) if (r != x.route) ownRow['${x.node}\u0000$r']].nonNulls.firstOrNull case final own?)
            _R(own.$1.withLinksBoth(x.row.links, x.row.goneLinks), own.$2)
          else
            x
        else
          x,
    ];
    // 이어 붙인 역은 그날 이은 계통 가운데 하나라도 그 역을 열었으면 열린 역이다
    if (date != null) {
      final openRow = <String, (SelectorRow, String)>{};
      for (final r in used) {
        for (final x in rows(r)?.rows ?? const <SelectorRow>[]) {
          if (_open(x)) openRow.putIfAbsent(x.node, () => (x, r));
        }
      }
      items = [
        for (final x in items)
          if (!_open(x.row) && openRow[x.node] != null) _R(openRow[x.node]!.$1.withLinksBoth(x.row.links, x.row.goneLinks), openRow[x.node]!.$2) else x,
      ];
    }
    return _finish();
  }

  // ---- 번호, 행 사이 상태, km ----
  StitchedLine _finish() {
    var next = 0;
    final origin = <int, StitchOrigin>{};
    final foreign = <int>{};
    SelectorRow renum(_R x) {
      final n = next++;
      origin[n] = (routeId: x.route, seq: x.row.seq);
      return x.row.copy(seq: n);
    }

    // 행 사이 상태: 두 역을 잇는 계통의 그 칸 값을 쓴다
    ({bool open, bool section, SectionEnd end}) gapOf(_R p, _R q) {
      for (final r in {q.route, p.route, ...used}) {
        final rr = rows(r);
        if (rr == null) continue;
        for (var k = 0; k + 1 < rr.rows.length; k++) {
          final a = rr.rows[k].node, b = rr.rows[k + 1].node;
          if ((a == p.node && b == q.node) || (a == q.node && b == p.node)) {
            return (
              open: k < rr.openGaps.length ? rr.openGaps[k] : true,
              section: k < rr.sectionGaps.length ? rr.sectionGaps[k] : true,
              end: k < rr.sectionEnds.length ? rr.sectionEnds[k] : const SectionEnd(),
            );
          }
        }
      }
      return (open: true, section: true, end: const SectionEnd());
    }

    RouteRows pack(String routeId, List<_R> list) {
      final gaps = [for (var k = 0; k + 1 < list.length; k++) gapOf(list[k], list[k + 1])];
      return RouteRows(
        routeId: routeId,
        rows: [for (final x in list) renum(x)],
        openGaps: [for (final g in gaps) g.open],
        sectionGaps: [for (final g in gaps) g.section],
        sectionEnds: [for (final g in gaps) g.end],
      );
    }

    final kmMain = _chain(items);
    final mainRows = pack(mainRoute, kmMain);
    final seqOf = <_R, int>{for (var k = 0; k < kmMain.length; k++) kmMain[k]: mainRows.rows[k].seq};
    for (final k in _bandRows) {
      if (k < mainRows.rows.length) foreign.add(mainRows.rows[k].seq);
    }
    final out = <StitchFold>[];
    for (final f in folds) {
      final anchorIdx = kmMain.indexWhere((x) => identical(x, f.anchor) || x.node == f.anchor.node);
      if (anchorIdx < 0) continue;
      final rowsKm = _chainFold(f, kmMain, anchorIdx);
      final pk = pack(f.rows.first.route, rowsKm);
      final rejoinIdx = f.rejoin == null ? -1 : kmMain.indexWhere((x) => x.node == f.rejoin);
      final dead = date == null && _deadIn(mainRows, anchorIdx, f.up);
      final anchorRow = mainRows.rows[anchorIdx];
      final rejoinRow = rejoinIdx < 0 ? null : mainRows.rows[rejoinIdx];
      final edgeHead = gapOf(kmMain[anchorIdx], f.up ? rowsKm.last : rowsKm.first);
      final edgeTail = rejoinIdx < 0 ? null : gapOf(rowsKm.last, kmMain[rejoinIdx]);
      final frame = f.up
          ? RouteRows(
              routeId: pk.routeId,
              rows: [...pk.rows, anchorRow],
              openGaps: [...pk.openGaps, edgeHead.open],
              sectionGaps: [...pk.sectionGaps, edgeHead.section],
              sectionEnds: [...pk.sectionEnds, edgeHead.end],
            )
          : RouteRows(
              routeId: pk.routeId,
              rows: [anchorRow, ...pk.rows, ?rejoinRow],
              openGaps: [edgeHead.open, ...pk.openGaps, ?edgeTail?.open],
              sectionGaps: [edgeHead.section, ...pk.sectionGaps, ?edgeTail?.section],
              sectionEnds: [edgeHead.end, ...pk.sectionEnds, ?edgeTail?.end],
            );
      out.add(StitchFold(
        frame: frame,
        anchor: seqOf[kmMain[anchorIdx]]!,
        up: f.up,
        // 날짜 모름에서 고를 수 있는지는 역 행이 정한다(1950 뒤 여객 정차). 폐지된 본선 칸 안의 접힌 줄도 폐지된 본선 역과 같다 (2026-11-23)
        rows: pk,
        rejoin: rejoinIdx < 0 ? null : mainRows.rows[rejoinIdx].seq,
        period: f.period,
        next: '',
        last: '',
        count: pk.rows.length,
        dead: dead,
      ));
    }
    // 제목 길이: 이 노선 구간 길이의 합 (띠 안 역은 빼고)
    var length = 0.0;
    final own = [
      for (final r in mainRows.rows)
        if (!foreign.contains(r.seq) && r.kmCum != null && (date == null || _open(r))) r.kmCum!,
    ];
    for (var k = 0; k + 1 < own.length; k++) {
      if (own[k + 1] > own[k]) length += own[k + 1] - own[k];
    }
    return StitchedLine(main: mainRows, folds: out, origin: origin, used: used, lengthKm: length, foreignKm: foreign);
  }

  /// 날짜 모름에서 접힌 줄을 품은 본선 칸이 오늘 폐지됐는가(흐리게 그린다. 고를 수 있는지는 바꾸지 않는다)
  bool _deadIn(RouteRows main, int anchorIdx, bool up) {
    final k = up ? anchorIdx - 1 : anchorIdx;
    if (k < 0 || k >= main.sectionGaps.length) return false;
    return !main.sectionGaps[k];
  }

  ({double km, bool est})? _official(String route, String node) {
    for (final st in net.stops(route)) {
      if (st.node == node && st.kmCum != null) return (km: st.kmCum!, est: st.kmEstimated);
    }
    return null;
  }

  ({double d, bool est})? _dist(_R a, _R b) {
    for (final r in {b.route, a.route, ...used}) {
      final x = _official(r, a.node), y = _official(r, b.node);
      if (x != null && y != null) return (d: (y.km - x.km).abs(), est: x.est || y.est);
    }
    return null;
  }

  double _round(double v) => (v * 10).roundToDouble() / 10;

  /// [nodes]를 모두 지나는 계통 (그날 이은 계통 가운데, [prefer]를 먼저)
  String? _through(List<String> nodes, String prefer) {
    for (final r in {prefer, ...used}) {
      final on = {for (final st in net.stops(r)) st.node};
      if (nodes.every(on.contains)) return r;
    }
    return null;
  }

  ({double d, bool est})? _distOn(String r, String a, String b) {
    final x = _official(r, a), y = _official(r, b);
    return x == null || y == null ? null : (d: (y.km - x.km).abs(), est: x.est || y.est);
  }

  /// 그날의 영업거리 (결정 A): 그날 다닌 길의 구간 거리를 잇는다.
  /// 이관 띠는 화면 이관 괄호와 같은 계산(역 사이 칸마다 위·아래 역의 이관 구간)으로 잡는다. 띠 안 역(띠 안 폐역 포함)은 이어받은 노선 km,
  /// 띠 끝 역 너머가 다른 계통(법적으로 따로인 구간)이면 그 역이 새 기점이다. 추정 km 역은 다음 역을 재는 기준이 되지 않는다
  List<_R> _chain(List<_R> list) {
    if (list.isEmpty) return list;
    bool liveRoute(String r) => date == null || openOn(r, rows(r));
    // km 원점은 그날 다니는 계통의 기점(km 0) 행이다. 계통 km는 그 계통 기점에서 잰 값이라, 줄 머리에 붙은 다른 계통 조각의 중간 km
    // (福知山線 1965 尼崎港線 尼崎港 4.6, 塚口에서 잼)로 잡으면 본선 km가 통째로 밀린다. 기점 행이 없을 때만 맨 위 공식 km 행이다
    var o = list.indexWhere((x) => _official(x.route, x.node)?.km == 0 && liveRoute(x.route));
    if (o < 0) o = list.indexWhere((x) => _official(x.route, x.node) != null && liveRoute(x.route));
    if (o < 0) o = list.indexWhere((x) => _official(x.route, x.node)?.km == 0);
    if (o < 0) o = list.indexWhere((x) => _official(x.route, x.node) != null);
    if (o < 0) return list;
    final n = list.length;
    final km = List<double?>.filled(n, null);
    final est = List<bool>.filled(n, false);
    // 이관 띠: 칸 g의 띠 = 위 역의 띠, 없으면 아래 역의 띠 (DisplayRules._bracketize와 같다)
    final shown = net.lineOnDate(mainRoute, date);
    (String, String)? band(SelectorRow r) => switch (DisplayRules.bandOf(r, undated: date == null, date: date)) {
          (final to, _) when to == shown => null,
          final b => b,
        };
    final owner = <int, String>{};
    final starts = <int>{};
    var g = 0;
    while (g + 1 < n) {
      final key = band(list[g].row) ?? band(list[g + 1].row);
      if (key == null) {
        g++;
        continue;
      }
      var b = g + 1;
      while (b + 1 < n && (band(list[b].row) ?? band(list[b + 1].row)) == key) {
        b++;
      }
      for (var k = g + 1; k < b; k++) {
        owner[k] = key.$1;
      }
      if (b + 1 < n && list[b + 1].route != list[g].route) {
        starts.add(b);
      } else {
        owner[b] = key.$1;
      }
      g = b;
    }
    void fresh(int k, String route) {
      final v = _official(route, list[k].node);
      km[k] = v?.km;
      est[k] = v?.est ?? false;
    }

    fresh(o, list[o].route);
    var last = o;
    var prev = o;
    var restart = false;
    for (var k = o + 1; k < n; k++) {
      final x = list[k];
      if (owner[k] case final line?) {
        km[k] = _ownerKm(x, line);
        _bandRows.add(k);
        restart = true;
        continue;
      }
      if (starts.contains(k) || restart) {
        restart = false;
        fresh(k, starts.contains(k) ? list[k + 1].route : x.route);
        if (km[k] != null) last = prev = k;
        continue;
      }
      // 사이 역을 모두 지나는 계통 하나가 있어야 그날의 길이다. 없으면 앞 역에서 잇는다
      final through = list[last].node == x.node ? null : _through([for (var j = last; j <= k; j++) list[j].node], x.route);
      var from = last;
      var d = through == null ? null : _distOn(through, list[last].node, x.node);
      if (d == null && prev >= 0) {
        from = prev;
        d = list[prev].node == x.node ? null : _dist(list[prev], x);
      }
      if (d == null || km[from] == null) continue;
      km[k] = _round(km[from]! + d.d);
      est[k] = est[from] || d.est;
      prev = k;
      if (!est[k] || est[last]) last = k;
    }
    last = o;
    for (var k = o - 1; k >= 0; k--) {
      final d = _dist(list[k], list[last]);
      if (d == null || km[last] == null) continue;
      km[k] = _round(km[last]! - d.d);
      est[k] = est[last] || d.est;
      if (!est[k] || est[last]) last = k;
    }
    return [
      for (var k = 0; k < n; k++)
        _R(list[k].row.copy(kmCum: km[k], clearKm: km[k] == null, kmEstimated: owner.containsKey(k) ? false : est[k]), list[k].route),
    ];
  }

  /// 띠 안 역의 km 자리 (원래 순번)
  final _bandRows = <int>{};

  double? _ownerKm(_R x, String line) {
    final day = date ?? s.today;
    for (final r in net.routesAt(x.node)) {
      if (net.routes[r]?.lineId != line) continue;
      for (final st in net.stops(r)) {
        final p = st.period;
        final on = (p.fromLo == null || p.fromLo!.compareTo(day.hi) <= 0) && (p.toHi == null || day.lo.compareTo(p.toHi!) < 0);
        if (st.node == x.node && st.kmCum != null && on) return st.kmCum;
      }
    }
    // 그날 그 노선이 서지 않는 역(띠 안 폐역)은 그 노선 계통의 자리 km다
    for (final r in net.routesOfLine(line)) {
      for (final st in net.stops(r)) {
        if (st.node == x.node && st.kmCum != null) return st.kmCum;
      }
    }
    return null;
  }

  /// 접힌 줄 km: 갈라지는 쪽에서 가장 가까운, 두 선형 모두 확실한 km가 있는 본선 역에서 그 선로를 따라 잰다.
  /// 붙는 역의 옛 선형 km가 추정값이면 그 너머 역(遠州鉄道 遠州病院 대신 八幡)에서 잰다. 추정 km 역은 다음 역을 재는 기준이 되지 않는다
  List<_R> _chainFold(_Fold f, List<_R> main, int anchorIdx) {
    final foldRoutes = {for (final r in f.rows) r.route};
    bool exactOn(String node) => foldRoutes.any((r) => _official(r, node)?.est == false);
    var b = anchorIdx;
    final step = f.up ? 1 : -1;
    for (var k = anchorIdx; k >= 0 && k < main.length; k += step) {
      final m = main[k];
      if (m.row.kmCum != null && !m.row.kmEstimated && exactOn(m.node)) {
        b = k;
        break;
      }
      if (!foldRoutes.any((r) => _official(r, m.node) != null)) break;
    }
    var baseNode = main[b];
    var baseKm = main[b].row.kmCum;
    var baseEst = main[b].row.kmEstimated || !exactOn(main[b].node);
    _R? prev;
    double? prevKm;
    var prevEst = false;
    final seqRows = f.up ? f.rows.reversed.toList() : f.rows;
    final km = <_R, double?>{};
    final est = <_R, bool>{};
    for (final r in seqRows) {
      var d = baseKm == null ? null : _dist(baseNode, r);
      var fromKm = baseKm, fromEst = baseEst;
      if (d == null && prev != null && prevKm != null) {
        d = _dist(prev, r);
        fromKm = prevKm;
        fromEst = prevEst;
      }
      if (d == null || fromKm == null) {
        km[r] = null;
        prev = r;
        prevKm = null;
        continue;
      }
      final v = _round(f.up ? fromKm - d.d : fromKm + d.d);
      final e = fromEst || d.est;
      km[r] = v;
      est[r] = e;
      prev = r;
      prevKm = v;
      prevEst = e;
      if (!e) {
        baseNode = r;
        baseKm = v;
        baseEst = false;
      }
    }
    return [for (final r in f.rows) _R(r.row.copy(kmCum: km[r], clearKm: km[r] == null, kmEstimated: est[r] ?? false), r.route)];
  }
}
