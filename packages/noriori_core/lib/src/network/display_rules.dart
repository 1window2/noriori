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
  });

  final String id;
  final String? afterNode;
  final String? beforeNode;
  final String closedYear;
  final double? km;
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
  const DisplayLink({required this.link, required this.gone, this.before = const []});

  final SelectorLink link;

  /// 3단계로 그린다. 지금은 없거나 그날 없던 노선이다.
  final bool gone;

  /// 같은 자리를 이어받기 전 노선. 선 없이 이름만 위에 적는다.
  final List<SelectorLink> before;
}

enum TransferFlow { through, up, down, unknown }

/// 세로선 모양이 같은 환승 노선 묶음. 점 하나가 된다.
final class TransferGroup {
  const TransferGroup({required this.flow, required this.items, this.number});

  final TransferFlow flow;
  final List<DisplayLink> items;

  /// 묶음이 둘 이상일 때만 있다. 왼쪽부터 1이다.
  final int? number;

  bool get gone => items.every((item) => item.gone);
}

/// 선택기의 한 줄 (DESIGN §8.1). 역과 분기가 각각 독립된 줄이다.
sealed class SelectorLine {
  const SelectorLine();
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
  });

  final int gap;
  final SelectorRow at;
  final DisplayLink item;
  final bool up;

  /// 같은 쪽의 줄이 더 바깥에 있어 줄기가 이어진다.
  final bool stacked;

  /// 역에서 이 줄까지 오는 줄기가 폐선만 지나는가. 바깥에 현행 분기가 있으면 현행색이다.
  final bool stemGone;

  /// 이 줄을 지나 바깥으로 이어지는 줄기가 폐선만 지나는가.
  final bool throughGone;

  /// 열람 전용 노선이면 그 항목이다.
  final ArchiveBranch? archive;
}

/// 줄기 끝에서 이어지는 노선. 위쪽 끝이면 [up]이다.
final class EndLine extends SelectorLine {
  const EndLine({
    required this.gap,
    required this.at,
    required this.items,
    required this.up,
  });

  final int gap;
  final SelectorRow at;

  /// 한 노선의 방면들. 그 역을 지나가는 노선이면 둘이다.
  final List<DisplayLink> items;
  final bool up;
}

/// 열람 전용 역 줄.
final class ArchiveLine extends SelectorLine {
  const ArchiveLine({required this.gap, required this.stop});

  final int gap;
  final ArchiveStop stop;
}

/// 폐지 구간의 경계. 위쪽이 영업, 아래쪽이 폐지면 [year]가 있다.
final class SectionLine extends SelectorLine {
  const SectionLine({required this.gap, this.year});

  final int gap;
  final String? year;
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

  /// 같은 회사인가. 회사 판정은 이름이 아니라 `operator_id`다 (DESIGN §8.1).
  bool sameCompany(String? a, String? b) =>
      (_companies[a] ?? const <String>{}).intersection(_companies[b] ?? const <String>{}).isNotEmpty;

  bool _gone(SelectorLink link, {required bool onDate}) {
    final end = link.validToHi;
    return !onDate || (end != null && end.compareTo(today) <= 0);
  }

  /// 앞 노선이 끝난 날 뒤 노선이 시작하면 이어받은 것이다. 앞 노선은 이름만 남긴다.
  List<DisplayLink> _chained(List<DisplayLink> items) {
    final out = <DisplayLink>[];
    final taken = <DisplayLink>{};
    for (final item in items) {
      if (taken.contains(item)) continue;
      // 두 번 이상 이관되면 옛 이름을 시간 순으로 쌓는다
      final earlier = <DisplayLink>[];
      var from = item.link.validFromLo;
      while (from != null) {
        final found = [
          for (final other in items)
            if (!identical(other, item) &&
                !earlier.contains(other) &&
                other.link.validToHi == from &&
                other.link.terminal == item.link.terminal &&
                other.link.side == item.link.side &&
                other.link.flow == item.link.flow)
              other,
        ];
        if (found.isEmpty) break;
        earlier.insertAll(0, found);
        from = found.first.link.validFromLo;
      }
      taken.addAll(earlier);
      out.add(
        earlier.isEmpty
            ? item
            : DisplayLink(
                link: item.link,
                gone: item.gone,
                before: [for (final row in earlier) row.link],
              ),
      );
    }
    final merged = {for (final item in taken) item.link};
    return [
      for (final item in out)
        if (!merged.contains(item.link)) item,
    ];
  }

  /// 날짜를 모르면 그날 없던 노선을 가를 수 없어 오늘 기준으로 체크박스를 따른다.
  List<DisplayLink> _links(
    SelectorRow row,
    String kind,
    DisplayOptions options, {
    bool undated = false,
  }) =>
      _chained([
        for (final link in row.links)
          if (link.kind == kind && (options.showClosed || !undated || !_gone(link, onDate: true)))
            DisplayLink(link: link, gone: _gone(link, onDate: true)),
        if (options.showClosed)
          for (final link in row.goneLinks)
            if (link.kind == kind) DisplayLink(link: link, gone: _gone(link, onDate: false)),
      ]);

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
  }) {
    final seen = <String>{};
    final unique = [
      for (final item in [
        ..._links(row, 'transfer', options, undated: undated),
        // 분기선을 끄면 곡선 대신 그 노선을 캡슐로 보여 준다 (DESIGN §8.1)
        if (!options.showBranches) ..._links(row, 'branch', options, undated: undated),
      ])
        if (seen.add('${item.link.otherLineId}\u0000${item.link.otherNode}')) item,
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
    return [
      for (final (index, flow) in kinds.indexed)
        TransferGroup(
          flow: flow,
          items: [for (final item in items) if (flowOf(item) == flow) item],
          number: kinds.length > 1 ? index + 1 : null,
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
  List<SelectorRow> visible(List<SelectorRow> rows, DisplayOptions options) {
    if (options.showClosed) return rows;
    return [
      for (final row in rows)
        if (!_isGoneStop(row) || row.links.any((link) => link.kind == 'branch')) row,
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
    bool undated = false,
  }) {
    final archive = options.showClosed && options.showArchive;
    final places = _place(rows, archive ? archiveStops : const []);
    final out = <SelectorLine>[];
    // 끝 이어짐의 기준은 마지막 현행 역이다. 뒤에 폐지 구간이 있어도 유지한다 (DESIGN §8.1)
    final current = [
      for (final (index, row) in rows.indexed)
        if (row.closeYear == null) index,
    ];
    final first = current.isEmpty ? 0 : current.first;
    final last = current.isEmpty ? rows.length - 1 : current.last;
    final gaps = sectionGaps ?? openGaps;
    // 첫 구간부터 폐지됐으면 구분선을 첫 역 위에 둔다. 첫 역 아래에 두면 첫 역만 남은 것처럼 보인다
    final topClosed = gaps.isNotEmpty && !gaps.first;
    // 칸마다 그 폐지 구간의 연도. 구분선 아래 칸부터 다음 구분선까지 같다
    final yearOf = <int, String>{};
    String? running;
    for (var at = 0; at < gaps.length; at++) {
      if (gaps[at]) {
        running = null;
        continue;
      }
      final year = rows[at + 1].closeYear ?? rows[at].closeYear ?? '?';
      if (running == null || year != running) running = year;
      yearOf[at] = running;
    }
    for (final (index, row) in rows.indexed) {
      final isFirst = index == first;
      final isLast = index == last;
      final branches = options.showBranches
          ? _links(row, 'branch', options, undated: undated)
          : const <DisplayLink>[];
      final continues = _links(row, 'continue', options, undated: undated);
      final inner = [
        ...branches,
        if (!isFirst && !isLast) ...continues,
      ];
      final ups = inner.where((item) => item.link.side == 'up' && !item.link.midway).toList();
      final downs = inner.where((item) => item.link.side != 'up' && !item.link.midway).toList();
      final midway = inner.where((item) => item.link.midway).toList();
      final old = [
        if (options.showBranches && archive)
          for (final branch in archiveBranches)
            if (branch.atNode == row.node) branch,
      ];
      if (isFirst) out.addAll(_ends(continues, gap: -1, at: row, up: true));
      if (index == 0 && topClosed) out.add(SectionLine(gap: -1, year: yearOf[0]));
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
          ),
        );
      }
      out.add(
        StopLine(
          index: index,
          row: row,
          transfers: transfers(row, lineId, options, undated: undated),
          branchUp: ups.isNotEmpty,
          branchDown: downs.isNotEmpty || old.isNotEmpty,
          small: !options.showClosed && _isGoneStop(row),
          branchUpGone: ups.isNotEmpty && ups.every((item) => item.gone),
          branchDownGone: (downs.isNotEmpty || old.isNotEmpty) && downs.every((item) => item.gone),
          quiet: row.closeYear != null &&
              (row.closeYear == yearOf[index - 1] || row.closeYear == yearOf[index]),
          returnsTo: closedRoute && rows.take(index).any((earlier) => earlier.node == row.node)
              ? row.node
              : null,
        ),
      );
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
          ),
        );
      }
      // 역이 아닌 곳의 분기는 그 역 다음 칸의 선로에서 바로 갈라진다
      for (final item in midway) {
        out.add(
          BranchLine(gap: index, at: row, item: item, up: false, stacked: false, stemGone: item.gone, throughGone: item.gone),
        );
      }
      for (final (at, branch) in old.indexed) {
        out.add(
          BranchLine(
            gap: index,
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
            stacked: at < old.length - 1,
            stemGone: true,
            throughGone: true,
            archive: branch,
          ),
        );
      }
      if (isLast) out.addAll(_ends(continues, gap: index, at: row, up: false));
      for (final stop in places[index] ?? const <ArchiveStop>[]) {
        out.add(ArchiveLine(gap: index, stop: stop));
      }
      if (index < gaps.length) {
        final below = gaps[index];
        final above = index == 0 ? !topClosed : gaps[index - 1];
        final yearAbove = index == 0 ? (topClosed ? yearOf[0] : null) : yearOf[index - 1];
        // 폐지 단계마다 구분선과 날짜를 둔다 (DESIGN §8)
        if (below != above || (!below && yearOf[index] != yearAbove)) {
          out.add(SectionLine(gap: index, year: below ? null : yearOf[index]));
        }
      }
    }
    return out;
  }

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
    return [
      for (final group in byLine.values) EndLine(gap: gap, at: at, items: group, up: up),
    ];
  }

  /// 앞 역 뒤에 놓는다. 앞 역을 모르면 뒤 역 앞에, 둘 다 모르면 km로 찾는다.
  Map<int, List<ArchiveStop>> _place(List<SelectorRow> rows, List<ArchiveStop> stops) {
    final places = <int, List<ArchiveStop>>{};
    int? slot(ArchiveStop stop) {
      final after = rows.lastIndexWhere((row) => row.node == stop.afterNode);
      if (stop.afterNode != null && after >= 0) return after;
      final before = rows.indexWhere((row) => row.node == stop.beforeNode);
      if (stop.beforeNode != null && before > 0) return before - 1;
      final km = stop.km;
      if (km == null) return null;
      final near = rows.lastIndexWhere((row) => (row.kmCum ?? double.infinity) <= km);
      return near >= 0 ? near : null;
    }

    for (final stop in stops) {
      final at = slot(stop);
      if (at != null) (places[at] ??= []).add(stop);
    }
    for (final list in places.values) {
      list.sort((a, b) => (a.km ?? double.infinity).compareTo(b.km ?? double.infinity));
    }
    return places;
  }
}
