import '../date/date_span.dart';
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
  });

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
            if (rr.rows[k].closeYear case final c? when c.compareTo(until) > 0) rr.rows[k].copy(closeYearAs: until) else rr.rows[k],
        ],
        openGaps: gaps(rr.openGaps),
        sectionGaps: gaps(rr.sectionGaps),
        sectionEnds: gaps(rr.sectionEnds),
      );
    });
  }

  bool free(String r) =>
      !used.contains(r) && !exclude.contains(r) && !s.claimed.contains(r) && !s.extra.contains(r) && lineRoutes.contains(r) && rows(r) != null;

  bool openOn(String r, RouteRows? rr) => rr != null && rr.rows.any(_open);

  bool liveToday(String r) => openOn(r, todays(r));

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
    final picked = fwd ? rs.sublist(ka + 1, kb >= 0 ? kb : rs.length) : rs.sublist(kb >= 0 ? kb + 1 : 0, ka).reversed.toList();
    return [for (final row in picked) _R(row, r2)];
  }

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
            closed ? (_R(_closed(x.row), r3)) : x,
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
      final mainLive = date != null ? region.any((k) => _open(items[k].row)) : region.isNotEmpty;
      final r2Open = date != null && own.any((x) => _open(x.row));
      // 같은 시기에 함께 다닌 구간은 진짜 지선이다. 다만 그날 그 구간의 유일한 길이면 잇는다 (날짜별, 결정 B)
      if (region.isNotEmpty) {
        final whole2 = (undated(r2) ?? rows(r2)!).rows.where((x) => !mn.contains(x.node)).toList();
        final regNodes = {for (final k in region) items[k].node};
        final wholeMain = (undated(mainRoute) ?? main).rows.where((x) => regNodes.contains(x.node)).toList();
        if (wholeMain.isNotEmpty && whole2.isNotEmpty && !exclusive(span(whole2), span(wholeMain)) && !(r2Open && !mainLive)) continue;
      }
      if (liveToday(r2) && (mainLive || date == null) && !bypass) continue;
      used.add(r2);
      final up = !bypass && upOf(at, link);
      if (r2Open && !mainLive) {
        // 그날의 길이 r2다: 본선 줄에 잇고, 본선의 그 구간은 다른 시기 선형으로 접는다
        final frows = [for (final k in region) _R(items[k].row.copy(selectable: false), items[k].route)];
        final seq = <_R>[...own];
        if (!bypass) {
          final tail = tailOf(r2, own.last.node, false);
          seq.addAll(tail.every((x) => !_open(x.row)) ? [for (final x in tail) _R(_closed(x.row), x.route)] : tail);
        }
        if (bypass) {
          final anchorRow = items[ia];
          items = [...items.sublist(0, ia + 1), ...seq, ...items.sublist(ib)];
          if (frows.isNotEmpty) {
            final cys = [for (final x in own) ?yearOf(x.row.closeYear)]..sort();
            folds.add(_Fold(anchor: anchorRow, up: false, rows: frows, rejoin: b, period: cys.isNotEmpty ? '${cys.first}~' : periodNew(frows)));
          }
        } else if (!up) {
          final anchorRow = items[ia];
          items = [...items.sublist(0, ia + 1), ...seq];
          if (frows.isNotEmpty) folds.add(_Fold(anchor: anchorRow, up: false, rows: frows, period: periodNew(frows)));
        } else {
          final anchorRow = items[ia];
          items = [...seq.reversed, ...items.sublist(ia)];
          if (frows.isNotEmpty) folds.add(_Fold(anchor: anchorRow, up: true, rows: frows.reversed.toList(), period: periodNew(frows)));
        }
        continue;
      }
      if (region.isEmpty && !bypass) {
        // 줄 끝 너머로 곧게 이어지는 구간
        final closed = date != null && own.every((x) => !_open(x.row));
        final rowsOut = [for (final x in own) closed ? _R(_closed(x.row), x.route) : x];
        items = up ? [...rowsOut.reversed, ...items.sublist(ia)] : [...items.sublist(0, ia + 1), ...rowsOut, ...items.sublist(ia + 1)];
        continue;
      }
      // 다른 시기 선형: 갈라지는 역에 접힌 줄 하나
      final tail = bypass ? <_R>[] : tailOf(r2, own.last.node, date != null);
      final frows = [for (final x in [...own, ...tail]) _R(x.row.copy(selectable: date == null && x.row.selectable), x.route)];
      folds.add(_Fold(anchor: items[ia], up: up, rows: up ? frows.reversed.toList() : frows, rejoin: b, period: periodOld(own)));
    }
    // 그날 열린 줄 끝에서 같은 노선 조각이 하나만 이어지면 한 줄이다 (둘 이상이면 갈라짐이라 칩)
    while (date != null) {
      final t = items.last;
      if (!_open(t.row)) break;
      final have = {for (final x in items) x.node};
      final cand = [
        for (final r in lineRoutes)
          if (free(r))
            if (rows(r)!.rows case final rs when rs.isNotEmpty && rs.first.node == t.node && rs.take(2).every((x) => x.state != StopState.beforeOpen) && !rs.skip(1).any((x) => have.contains(x.node))) r,
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
    for (final r in _bandRows) {
      if (seqOf[r] case final n?) foreign.add(n);
    }
    final out = <StitchFold>[];
    for (final f in folds) {
      final anchorIdx = kmMain.indexWhere((x) => identical(x, f.anchor) || x.node == f.anchor.node);
      if (anchorIdx < 0) continue;
      final rowsKm = _chainFold(f, kmMain, anchorIdx);
      final pk = pack(f.rows.first.route, rowsKm);
      final rejoinIdx = f.rejoin == null ? -1 : kmMain.indexWhere((x) => x.node == f.rejoin);
      final dead = date == null && _deadIn(mainRows, anchorIdx, f.up);
      out.add(StitchFold(
        anchor: seqOf[kmMain[anchorIdx]]!,
        up: f.up,
        rows: dead ? RouteRows(routeId: pk.routeId, rows: [for (final r in pk.rows) r.copy(selectable: false)], openGaps: pk.openGaps, sectionGaps: pk.sectionGaps, sectionEnds: pk.sectionEnds) : pk,
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

  /// 날짜 모름에서 접힌 줄을 품은 본선 칸이 오늘 폐지됐는가
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

  /// 그날의 영업거리 (결정 A): 그날 다닌 길의 구간 거리를 잇는다
  List<_R> _chain(List<_R> list) {
    if (list.isEmpty) return list;
    bool liveRoute(String r) => date == null || openOn(r, rows(r));
    var o = list.indexWhere((x) => _official(x.route, x.node) != null && liveRoute(x.route));
    if (o < 0) o = list.indexWhere((x) => _official(x.route, x.node)?.km == 0);
    if (o < 0) o = list.indexWhere((x) => _official(x.route, x.node) != null);
    if (o < 0) return list;
    final km = List<double?>.filled(list.length, null);
    final est = List<bool>.filled(list.length, false);
    final band = <int>{};
    void fresh(int k, String route) {
      final v = _official(route, list[k].node);
      km[k] = v?.km;
      est[k] = v?.est ?? false;
    }

    fresh(o, list[o].route);
    // 이관 띠: 이어받은 노선의 km를 흐리게
    bool inBand(_R x) => x.row.handedTo != null && (date == null || (x.row.handedOn ?? '9999').compareTo(date!.lo) <= 0);
    var last = o;
    var prev = o;
    var restart = false;
    for (var k = o + 1; k < list.length; k++) {
      final x = list[k];
      if (inBand(x)) {
        final nextOther = k + 1 < list.length && list[k + 1].route != x.route && !inBand(list[k + 1]);
        if (nextOther && list[k + 1].route != list[o].route) {
          // 띠 끝 역이 다음 구간의 기점이다
          fresh(k, list[k + 1].route);
          if (km[k] != null) last = prev = k;
          restart = false;
          continue;
        }
        band.add(k);
        km[k] = _ownerKm(x);
        restart = true;
        continue;
      }
      if (restart) {
        restart = false;
        fresh(k, x.route);
        if (km[k] != null) last = prev = k;
        continue;
      }
      // 추정 km 역은 다음 역을 재는 기준이 되지 않는다. 확실한 역에서 바로 잴 수 있으면 「?」가 번지지 않는다.
      // 못 재면(한 계통에 함께 없거나 고리를 닫는 같은 역) 바로 앞 역에서 잰다
      // 사이에 다른 계통(그날 이은 선형)이 끼면 그날의 길이 아니므로 앞 역에서 잇는다
      final sameRoute = [for (var j = last; j <= k; j++) list[j].route].toSet().length == 1;
      var from = last;
      var d = list[last].node == x.node || !sameRoute ? null : _dist(list[last], x);
      if (d == null && prev >= 0) {
        from = prev;
        d = _dist(list[prev], x);
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
    final out = <_R>[];
    for (var k = 0; k < list.length; k++) {
      final r = _R(list[k].row.copy(kmCum: km[k], clearKm: km[k] == null, kmEstimated: est[k]), list[k].route);
      out.add(r);
      if (band.contains(k)) _bandRows.add(r);
    }
    return out;
  }

  final _bandRows = <_R>[];

  double? _ownerKm(_R x) {
    final line = x.row.handedTo;
    final day = date ?? s.today;
    for (final r in net.routesAt(x.node)) {
      if (net.routes[r]?.lineId != line) continue;
      for (final st in net.stops(r)) {
        final p = st.period;
        final on = (p.fromLo == null || p.fromLo!.compareTo(day.hi) <= 0) && (p.toHi == null || day.lo.compareTo(p.toHi!) < 0);
        if (st.node == x.node && st.kmCum != null && on) return st.kmCum;
      }
    }
    return null;
  }

  List<_R> _chainFold(_Fold f, List<_R> main, int anchorIdx) {
    final j = f.up ? anchorIdx : anchorIdx;
    var a = main[j];
    final seqRows = f.up ? f.rows.reversed.toList() : f.rows;
    final km = <_R, double?>{};
    final est = <_R, bool>{};
    for (final r in seqRows) {
      final d = _dist(a, r);
      if (d == null || a.row.kmCum == null && km[a] == null) {
        km[r] = null;
        continue;
      }
      final base = km[a] ?? a.row.kmCum!;
      km[r] = _round(f.up ? base - d.d : base + d.d);
      final baseEst = est[a] ?? a.row.kmEstimated;
      est[r] = baseEst || d.est;
      if (!est[r]! || baseEst) a = r;
    }
    return [for (final r in f.rows) _R(r.row.copy(kmCum: km[r], clearKm: km[r] == null, kmEstimated: est[r] ?? false), r.route)];
  }
}
