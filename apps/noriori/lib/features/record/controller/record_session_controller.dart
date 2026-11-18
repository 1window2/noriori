import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/session_providers.dart';

final class StopPick {
  const StopPick(this.seq, this.node);

  final int seq;
  final String node;
}

/// 고른 경로가 지나는 줄. 순환 계통의 짧은 쪽은 seq 끝을 넘으므로 범위로 셀 수 없다.
final class PickedPath {
  const PickedPath({required this.stops, required this.below});

  final Set<int> stops;

  /// 아래쪽 선이 경로에 드는 줄의 seq.
  final Set<int> below;

  factory PickedPath.of(List<SelectorRow> rows, List<String> nodes) {
    String pair(String a, String b) => a.compareTo(b) < 0 ? '$a\u0000$b' : '$b\u0000$a';
    final shown = {for (final row in rows) row.node};
    final walked = nodes.where(shown.contains).toList();
    final joined = {
      for (var i = 0; i + 1 < walked.length; i++) pair(walked[i], walked[i + 1]),
    };
    final below = <int>{
      for (var i = 0; i + 1 < rows.length; i++)
        if (joined.contains(pair(rows[i].node, rows[i + 1].node))) rows[i].seq,
    };
    return PickedPath(
      stops: {
        for (final row in rows)
          if (nodes.contains(row.node)) row.seq,
      },
      below: below,
    );
  }
}

/// 입력 상태는 이 값 하나가 소유한다 (ARCHITECTURE §2.4).
final class RecordSessionState {
  const RecordSessionState({
    this.lineId,
    this.routeId,
    this.dateInput,
    this.from,
    this.to,
    this.rows = const [],
    this.visible = const [],
    this.lines = const [],
    this.openGaps = const [],
    this.names = const {},
    this.japanese = const {},
    this.readings = const {},
    this.pastMarks = const {},
    this.archiveNames = const {},
    this.archiveAside = const {},
    this.movedNotes = const {},
    this.tempWindows = const [],
    this.tempRoutes = const {},
    this.stopDirections = const {},
    this.oneWayGaps = const [],
    this.preview,
    this.ridePreview,
    this.path,
    this.direction,
    this.ways,
    this.split = const [],
    this.laps = 1,
    this.focus,
    this.depth = 0,
  });

  final String? lineId;
  final String? routeId;

  /// EDTF. null은 날짜 모름이다.
  final String? dateInput;
  final StopPick? from;
  final StopPick? to;

  /// 그 계통의 모든 역 줄.
  final List<SelectorRow> rows;

  /// 체크박스를 거친 역 줄. 줄기 칸의 번호가 이 순서다.
  final List<SelectorRow> visible;

  /// 화면에 그리는 줄 (DESIGN §8.1).
  final List<SelectorLine> lines;

  /// 보이는 역 사이가 그날 영업했는가.
  final List<bool> openGaps;
  final Map<String, String> names;

  /// 역 이름 곁에 작게 적는 일본어 이름.
  final Map<String, String> japanese;

  /// 일본어판에서 역 이름 옆에 다는 읽기(히라가나). 다른 언어판과 읽기 근거가 없는 역은 비어 있다
  final Map<String, String> readings;

  /// 날짜 모름일 때 예전에만 仮乗降場·臨時駅이었던 역 → kari·rinji (작은 표식).
  final Map<String, String> pastMarks;
  final Map<String, String> archiveNames;

  /// 열람 전용 역 이름 옆에 작게 다는 글: 다른 언어판은 일본어 이름(현지 이름과 다를 때), 일본어판은 읽기. 역 줄과 같은 규칙이다 (2026-11-18 사용자 지적)
  final Map<String, String> archiveAside;

  /// 이름까지 바뀐 옛 자리의 이전 표시(옛 자리 노드 → 새 역 이름·옮긴 해)
  final Map<String, ({String name, String year})> movedNotes;

  /// 임시 운행만 있는 계통이면 그 운행 토막 [from, to). 비어 있으면 보통 계통이다 (사용자 결정 2026-11-19)
  final List<({String from, String to})> tempWindows;

  bool get isTemporary => tempWindows.isNotEmpty;

  /// 이 노선의 계통 가운데 임시 운행만 있는 것(칩의 「임시」 표시)
  final Set<String> tempRoutes;

  /// 고른 날이 임시 열차 운행일인가. 날짜를 모르면 거짓이다
  bool tempRunsOn(String? day) => day != null && tempWindows.any((w) => w.from.compareTo(day) <= 0 && day.compareTo(w.to) < 0);

  /// 그날 한 방향 열차만 서는 역 줄(순번) → 그 행 (DESIGN §8 한 방향 정차).
  final Map<int, NetStopDirection> stopDirections;

  /// 보이는 역 사이가 그날 한 방향이면 그 방향. 참이면 목록 아래로, 거짓이면 위로 간다 (DESIGN §8 한 방향 운행).
  final List<bool?> oneWayGaps;

  /// 두 역을 고르면 만들어지는 펼친 결과.
  final Expansion? preview;

  /// 저장하면 얼마나 오르는가.
  final RidePreview? ridePreview;

  /// 펼친 경로. 아직 경로가 하나로 정해지지 않았으면 없다.
  final PickedPath? path;

  /// 순환에서 고른 방향. 없으면 짧은 쪽이다.
  final String? direction;

  /// 순환에서 두 방향의 거리.
  final ({int up, int down})? ways;

  /// 고른 구간이 여러 공식 노선으로 나뉘면 노선별 거리 (DESIGN §2.8 F).
  final List<({String lineId, int meters})> split;

  /// 한 바퀴를 몇 번 돌았는가. leg를 이 수만큼 저장한다 (DESIGN §2.8 G).
  final int laps;

  /// 화면을 옮겨 보여 줄 역 줄.
  final int? focus;

  /// 분기로 넘어온 횟수. 0이 아니면 뒤로 가기가 직전 노선으로 돌아간다.
  final int depth;

  /// 고른 두 역 중 하나의 km가 추정값이다. 승차 km를 `?`로 보인다 (DESIGN §4.5).
  bool get kmEstimated => rows.any((row) => row.kmEstimated && (row.seq == from?.seq || row.seq == to?.seq));

  RecordSessionState copyWith({
    String? dateInput,
    bool clearDate = false,
    StopPick? from,
    StopPick? to,
    bool clearPicks = false,
    List<SelectorRow>? rows,
    List<SelectorRow>? visible,
    List<SelectorLine>? lines,
    List<bool>? openGaps,
    Map<String, String>? names,
    Map<String, String>? japanese,
    Map<String, String>? readings,
    Map<String, String>? pastMarks,
    Map<String, String>? archiveNames,
    Map<String, String>? archiveAside,
    Map<String, ({String name, String year})>? movedNotes,
    List<({String from, String to})>? tempWindows,
    Set<String>? tempRoutes,
    Map<int, NetStopDirection>? stopDirections,
    List<bool?>? oneWayGaps,
    Expansion? preview,
    RidePreview? ridePreview,
    PickedPath? path,
    String? direction,
    ({int up, int down})? ways,
    int? laps,
    int? focus,
  }) =>
      RecordSessionState(
        lineId: lineId,
        routeId: routeId,
        dateInput: clearDate ? null : dateInput ?? this.dateInput,
        from: clearPicks ? null : from ?? this.from,
        to: clearPicks ? null : to ?? this.to,
        rows: rows ?? this.rows,
        visible: visible ?? this.visible,
        lines: lines ?? this.lines,
        openGaps: openGaps ?? this.openGaps,
        names: names ?? this.names,
        japanese: japanese ?? this.japanese,
        readings: readings ?? this.readings,
        pastMarks: pastMarks ?? this.pastMarks,
        archiveNames: archiveNames ?? this.archiveNames,
        archiveAside: archiveAside ?? this.archiveAside,
        movedNotes: movedNotes ?? this.movedNotes,
        tempWindows: tempWindows ?? this.tempWindows,
        tempRoutes: tempRoutes ?? this.tempRoutes,
        stopDirections: stopDirections ?? this.stopDirections,
        oneWayGaps: oneWayGaps ?? this.oneWayGaps,
        preview: clearPicks ? null : preview ?? this.preview,
        ridePreview: clearPicks ? null : ridePreview ?? this.ridePreview,
        path: clearPicks ? null : path ?? this.path,
        direction: clearPicks ? null : direction ?? this.direction,
        ways: clearPicks ? null : ways ?? this.ways,
        laps: clearPicks ? 1 : laps ?? this.laps,
        focus: focus ?? this.focus,
        depth: depth,
      );

  bool isPicked(int seq) =>
      seq == from?.seq || seq == to?.seq || (path?.stops.contains(seq) ?? _between(seq));

  bool _between(int seq) {
    final a = from?.seq;
    final b = to?.seq;
    return a != null && b != null && seq > min(a, b) && seq < max(a, b);
  }

  /// 이 역 아래쪽 선이 고른 구간에 드는가.
  bool coversBelow(int seq) {
    final known = path;
    if (known != null) return known.below.contains(seq);
    final a = from?.seq;
    final b = to?.seq;
    return a != null && b != null && seq >= min(a, b) && seq < max(a, b);
  }

  String nameOf(String node) => names[node] ?? node;

  /// 연결 줄의 상대 역 이름. 끝난 연결이면 그 연결이 끝난 날 전날, 상대 노선의 이름이다 (4회차 kyushu_2-007)
  String linkNameOf(SelectorLink link, String node) {
    final raw = dateInput;
    final day = endedLinkNameDay(link, raw == null ? null : DateSpan.parse(raw));
    return (day == null ? null : names[endedLinkNameKey(node, link.otherLineId, day)]) ?? nameOf(node);
  }

  /// 출발역을 고른 뒤 도착역 후보까지 몇 역인가 (DESIGN §1.5). 고를 수 있는 역만 센다.
  int? stopsAway(SelectorRow row) {
    final start = from;
    if (start == null || to != null || !row.selectable || row.seq == start.seq) return null;
    final lo = min(start.seq, row.seq);
    final hi = max(start.seq, row.seq);
    return rows.where((r) => r.selectable && r.seq > lo && r.seq <= hi).length;
  }

  /// 한 바퀴를 골랐는가.
  bool get isLap => from != null && from?.node == to?.node;

  /// 하단에 세는 역 수. 고를 수 있는 역만 센다 (DESIGN §8).
  int get pickedStops => {
        for (final row in rows)
          if (row.selectable && isPicked(row.seq)) row.seq,
      }.length;
}

sealed class SaveOutcome {
  const SaveOutcome();
}

final class SaveDone extends SaveOutcome {
  const SaveDone(this.change, {required this.ticket});

  final Change change;
  final RideTicketData ticket;
}

/// 승차권에 찍는 값.
final class RideTicketData {
  const RideTicketData({
    required this.lineName,
    required this.fromName,
    required this.toName,
    required this.dateInput,
    required this.meters,
    this.kmEstimated = false,
    this.before,
    this.after,
  });

  final String lineName;
  final String fromName;
  final String toName;
  final String? dateInput;
  final int meters;

  /// 탄 역이나 내린 역의 km가 추정값이다 (DESIGN §4.5).
  final bool kmEstimated;
  final Score? before;
  final Score? after;

  /// 이 기록으로 처음 완주했는가.
  bool get completed => (after?.complete ?? false) && !(before?.complete ?? false);
}

/// 경로가 둘이다. 어느 쪽으로 탔는지 묻는다.
final class SaveAskDirection extends SaveOutcome {
  const SaveAskDirection({required this.upMeters, required this.downMeters});

  final int upMeters;
  final int downMeters;
}

/// 이설 구간이다. 어느 시기의 선로였는지 묻는다.
final class SaveAskRelocation extends SaveOutcome {
  const SaveAskRelocation(this.options);

  final List<RelocationOption> options;
}

/// 그날 그 구간을 탈 수 없다. 경고하고 저장하지 않는다 (DESIGN §2.8 J).
final class SaveUnridable extends SaveOutcome {
  const SaveUnridable();
}

final class SaveFailed extends SaveOutcome {
  const SaveFailed(this.reason);

  final ExpandReason? reason;
}

final recordSessionProvider =
    NotifierProvider<RecordSessionController, RecordSessionState>(RecordSessionController.new);

final class RecordSessionController extends Notifier<RecordSessionState> {
  /// 지금 계통에 없는 출발역의 seq.
  static const _carried = -1;

  /// 넘어오기 전의 노선들. 뒤로 가기가 하나씩 되돌아간다.
  final _trail = <({String lineId, String routeId, String node})>[];

  @override
  RecordSessionState build() {
    // 체크박스를 바꾸면 줄이 달라지므로 고른 것을 푼다
    ref.listen(displayOptionsProvider, (_, next) {
      if (state.routeId == null) return;
      state = state.copyWith(clearPicks: true);
      unawaited(_refresh());
    });
    return const RecordSessionState();
  }

  Network get _network => ref.read(networkProvider);
  RouteResolver get _resolver => RouteResolver(_network);

  bool get isLoop {
    final routeId = state.routeId;
    return routeId != null && _network.routes[routeId]!.closed;
  }

  /// 노선을 연다. 기본 날짜는 현행 노선이면 오늘, 폐선이면 날짜 모름이다.
  ///
  /// 일부만 폐지된 노선을 폐선 목록에서 열면 [dateUnknown]이다. 오늘이면 그 구간을 고를 수 없다.
  Future<void> open({
    required String lineId,
    String? routeId,
    String? fromNode,
    String? focusNode,
    bool dateUnknown = false,
  }) async {
    final route = routeId ?? _mainRoute(lineId);
    final today = ref.read(todayProvider);
    _trail.clear();
    final opened = SelectorBuilder(_network).build(route, DateSpan.parse(today));
    final current = opened.any((row) => row.selectable);
    state = RecordSessionState(
      lineId: lineId,
      routeId: route,
      dateInput: current && !dateUnknown ? today : null,
    );
    await _refresh();
    _pickNode(fromNode);
    // 열람 전용을 찾아 왔으면 고르지 않고 그 자리로만 옮긴다
    if (focusNode != null) {
      for (final row in state.rows) {
        if (row.node == focusNode) state = state.copyWith(focus: row.seq);
      }
    }
  }

  void _pickNode(String? node) {
    if (node == null) return;
    for (final row in state.rows) {
      if (row.node == node && row.selectable) {
        state = state.copyWith(focus: row.seq);
        tap(row);
        return;
      }
    }
  }

  String _mainRoute(String lineId) {
    final routes = _network.routesOfLine(lineId);
    return routes.firstWhere(
      (id) => _network.routes[id]!.role == 'main',
      orElse: () => routes.first,
    );
  }

  List<String> get routeChoices => _network.routesOfLine(state.lineId ?? '');

  /// 그날의 노선. 화면 제목과 km가 이 값을 따른다.
  String get shownLine {
    final routeId = state.routeId;
    return routeId == null ? '' : _network.lineOnDate(routeId, _date);
  }

  /// 그날의 회사들. 폐선이면 마지막 회사다.
  String get operatorName {
    final day = _date ?? DateSpan.parse(ref.read(todayProvider));
    final names = ref.read(nameBookProvider).operators;
    return [
      for (final id in _network.operatorsOn(shownLine, day)) names[id] ?? '',
    ].join(' · ');
  }

  bool canOpen(String? lineId) =>
      lineId != null && _network.routesOfLine(lineId).isNotEmpty;

  /// 분기나 끝 줄로 다른 노선에 넘어간다. 고르던 역은 사라지고 날짜는 이어진다 (DESIGN §8).
  ///
  /// 화면은 고른 역이 있으면 먼저 묻는다.
  Future<void> jumpTo(SelectorLink link, SelectorRow at) async {
    final lineId = link.otherLineId;
    if (!canOpen(lineId)) return;
    _trail.add((lineId: state.lineId!, routeId: state.routeId!, node: at.node));
    await _move(lineId!, link.otherRouteId ?? _mainRoute(lineId), at.node);
  }

  /// 이관 구간의 구분선에서 이어받은 노선으로 넘어간다 (DESIGN §8.0.1). [node] 역으로 스크롤한다.
  Future<void> jumpToLine(String lineId, String node) async {
    if (!canOpen(lineId)) return;
    _trail.add((lineId: state.lineId!, routeId: state.routeId!, node: node));
    await _move(lineId, _mainRoute(lineId), node);
  }

  /// 넘어온 노선으로 돌아간다. 돌아갈 곳이 없으면 거짓이다.
  Future<bool> jumpBack() async {
    if (_trail.isEmpty) return false;
    final back = _trail.removeLast();
    await _move(back.lineId, back.routeId, back.node);
    return true;
  }

  Future<void> _move(String lineId, String routeId, String node) async {
    final date = state.dateInput;
    state = RecordSessionState(
      lineId: lineId,
      routeId: routeId,
      dateInput: date,
      depth: _trail.length,
    );
    await _refresh();
    for (final row in state.rows) {
      if (row.node == node) state = state.copyWith(focus: row.seq);
    }
  }

  /// 계통 칩을 바꿔도 출발역을 유지한다 (DESIGN §8).
  Future<void> selectRoute(String routeId) async {
    final node = state.from?.node;
    final name = node == null ? null : state.nameOf(node);
    state = RecordSessionState(
      lineId: state.lineId,
      routeId: routeId,
      dateInput: state.dateInput,
      depth: _trail.length,
    );
    await _refresh();
    if (node == null) return;
    if (state.rows.any((row) => row.node == node && row.selectable)) return _pickNode(node);
    // 이 계통에 없는 출발역은 줄이 없어도 고른 채로 둔다. 도착역은 계통을 넘어 찾는다
    state = state.copyWith(names: {...state.names, node: name!});
    _setPicks(StopPick(_carried, node), null);
  }

  /// 탑승일을 바꾸면 상태표만 다시 적용한다.
  ///
  /// 고른 구간을 그날 탈 수 없으면 날짜 변경을 받지 않는다. 고른 역과 원래 날짜는 그대로다
  /// (DESIGN §8.0.1 탑승일, §2.8 J). 받지 않았으면 참이고 화면이 경고한다.
  Future<bool> setDate(String? raw) async {
    final previous = state.dateInput;
    // 줄을 비우지 않는다. 비우면 DB를 다녀오는 사이에 목록이 맨 위로 돌아간다
    state = state.copyWith(dateInput: raw, clearDate: raw == null);
    await _refresh();
    final open = {for (final row in state.rows) if (row.selectable) row.seq};
    final from = state.from;
    final to = state.to;
    final direction = state.direction;
    final lost = (from != null && from.seq != _carried && !open.contains(from.seq)) ||
        (to != null && !open.contains(to.seq));
    if (raw != null && (lost || (from != null && to != null && _unridable(from, to, direction)))) {
      state = state.copyWith(dateInput: previous, clearDate: previous == null);
      await _refresh();
      _setPicks(from, to, direction: direction);
      return true;
    }
    _setPicks(from, to, direction: direction);
    return false;
  }

  /// 고른 구간을 탑승일에 탈 수 없는가 (DESIGN §2.8 J). 기준일 이전은 기록 범위 밖이라 아니다.
  bool _unridable(StopPick from, StopPick to, String? direction) {
    if (normalizeRideDate(_date) == null) return false;
    final result = _record(from, to, direction: direction);
    if (result.status == ResolveStatus.invalid) return false;
    if (result.demoted) return true;
    if (!result.saved) return false;
    return RideInterpreter(_network).unridable(_draft(result, from, to, direction));
  }

  /// 판정용 기록. 이름은 비워 둔다.
  Ride _draft(Expansion result, StopPick from, StopPick to, String? direction) => Ride(
        rideId: const RideId('draft'),
        datasetVersion: '',
        createdAt: 0,
        updatedAt: 0,
        deviceId: '',
        dateInput: state.dateInput,
        legs: _isAcross(from, to)
            ? [
                for (final (seq, leg) in result.legs.indexed)
                  RideLeg(
                    seq: seq,
                    lineId: LineId(leg.lineId),
                    routeId: RouteId(leg.routeId),
                    fromNode: NodeId(leg.from!),
                    toNode: NodeId(leg.to!),
                    direction: _network.routes[leg.routeId]!.closed
                        ? _resolver.record(leg.routeId, leg.from!, leg.to!).direction
                        : null,
                    lineLabel: '',
                    fromLabel: '',
                    toLabel: '',
                  ),
              ]
            : [
                RideLeg(
                  seq: 0,
                  lineId: LineId(state.lineId!),
                  routeId: RouteId(state.routeId!),
                  fromNode: NodeId(from.node),
                  toNode: NodeId(to.node),
                  direction: direction ??
                      (_network.routes[state.routeId!]!.closed ? result.direction : null),
                  lineLabel: '',
                  fromLabel: '',
                  toLabel: '',
                ),
              ],
      );

  /// 앞선 새로 읽기가 늦게 끝나 다른 노선의 줄을 덮지 않게 한다.
  int _generation = 0;

  Future<void> _refresh() async {
    final generation = ++_generation;
    final routeId = state.routeId!;
    final raw = state.dateInput;
    final date = raw == null ? null : DateSpan.parse(raw);
    final reader = ref.read(packReaderProvider);
    final options = ref.read(displayOptionsProvider);
    final network = _network;
    final today = ref.read(todayProvider);
    final builder = SelectorBuilder(network);
    // 이관 구간 안은 이어받은 노선의 그날 역·환승·분기로 채운다 (DESIGN §8.0.1 B안)
    final rows = builder.fillHanded(
      routeId,
      builder.build(
        routeId,
        date,
        links: await reader.routeLinks(routeId, carryover: options.carryover),
        carryoverStops: options.carryover ? await reader.carryoverStops(routeId) : const {},
      ),
      date,
      links: {for (final other in builder.handRoutes(routeId)) other: await reader.routeLinks(other)},
    );
    final rules = DisplayRules(network, today: today);
    final visible = rules.visible(rows, options);
    final openGaps = builder.openBetween(routeId, visible, date);
    // 날짜를 모르면 줄기는 1단계로 두고 구분선만 오늘 기준으로 그린다
    final sectionGaps = date == null
        ? builder.openBetween(routeId, visible, DateSpan.parse(today))
        : openGaps;
    final stops = await reader.archiveStops(routeId);
    final branches = await reader.archiveBranches(rows.map((row) => row.node));
    final parallels = await reader.routeParallels(routeId);
    final lines = rules.lines(
      lineId: state.lineId!,
      rows: visible,
      openGaps: openGaps,
      options: options,
      closedRoute: network.routes[routeId]!.closed,
      archiveStops: stops,
      archiveBranches: branches,
      sectionGaps: sectionGaps,
      sectionEnds: builder.sectionEnds(routeId, visible, DateSpan.parse(today), date: date),
      undated: date == null,
      parallels: parallels,
      date: date,
    );
    final ids = <String>{
      for (final run in parallels) ...[?run.inNext, ?run.inTerminal, ?run.outNext, ?run.outTerminal],
      for (final row in rows) row.node,
      for (final row in rows)
        for (final link in [...row.links, ...row.goneLinks]) ...[
          ?link.otherNode,
          ?link.nextStop,
          ?link.terminal,
        ],
    };
    final names = {...await reader.nodeNames(ids, lineId: state.lineId, routeId: routeId, date: date?.lo)};
    // 끝난 연결 줄의 상대 역은 그 연결이 끝난 날 전날, 상대 노선의 이름이다 (4회차 kyushu_2-007: 臼ノ浦線 「松浦線 다음 上佐々」)
    final endedIds = <(String?, String), Set<String>>{};
    for (final row in rows) {
      for (final link in [...row.links, ...row.goneLinks]) {
        final day = endedLinkNameDay(link, date);
        if (day == null) continue;
        (endedIds[(link.otherLineId, day)] ??= {}).addAll([?link.otherNode, ?link.nextStop, ?link.terminal]);
      }
    }
    for (final MapEntry(key: (other, day), value: list) in endedIds.entries) {
      final ended = await reader.nodeNames(list, lineId: other, date: day);
      for (final MapEntry(key: node, value: name) in ended.entries) {
        names[endedLinkNameKey(node, other, day)] = name;
      }
    }
    final japanese = await reader.nodeNames(
      rows.map((row) => row.node),
      lineId: state.lineId,
      routeId: routeId,
      date: date?.lo,
      languages: const ['ja'],
    );
    final readings = reader.languages.first == 'ja'
        ? await reader.nodeReadings(rows.map((row) => row.node), lineId: state.lineId, routeId: routeId, date: date?.lo)
        : const <String, String>{};
    // 날짜를 모를 때만 작은 표식을 단다. 날짜가 있으면 그날 이름에 표시가 붙는다
    final pastMarks = date == null && state.lineId != null
        ? await reader.pastTempMarks(rows.map((row) => row.node), state.lineId!, routeId: routeId)
        : const <String, String>{};
    final archiveIds = [
      for (final stop in stops) stop.id,
      for (final branch in branches) branch.id,
    ];
    final archiveNames = await reader.archiveNames(archiveIds);
    final archiveAside = reader.languages.first == 'ja'
        ? await reader.archiveReadings(archiveIds)
        : {
            for (final MapEntry(key: id, value: ja) in (await reader.archiveNames(archiveIds, languages: const ['ja'])).entries)
              if (ja != archiveNames[id]) id: ja,
          };
    final movedNotes = await reader.movedNotes(rows.map((row) => row.node), lineId: state.lineId, date: date?.lo);
    final tempWindows = await reader.tempWindows(routeId);
    final tempRoutes = await reader.tempRouteIds();
    // 한 방향 정차역과 한 방향 칸 (DESIGN §8 한 방향 운행·한 방향 정차)
    final stopDirections = <int, NetStopDirection>{
      for (final row in visible)
        row.seq: ?network.stopDirectionOf(routeId, row.node, date),
    };
    final oneWayGaps = [
      for (var at = 0; at + 1 < visible.length; at++)
        network.oneWayBetween(routeId, visible[at].node, visible[at + 1].node, date),
    ];
    if (generation != _generation) return;
    state = state.copyWith(
      rows: rows,
      visible: visible,
      lines: lines,
      openGaps: openGaps,
      stopDirections: stopDirections,
      oneWayGaps: oneWayGaps,
      names: {
        ...names,
        if (state.from case StopPick(seq: _carried, :final node)) node: state.nameOf(node),
      },
      japanese: japanese,
      readings: readings,
      pastMarks: pastMarks,
      archiveNames: archiveNames,
      archiveAside: archiveAside,
      movedNotes: movedNotes,
      tempWindows: tempWindows,
      tempRoutes: tempRoutes,
      path: state.preview == null || state.preview!.nodes.isEmpty
          ? null
          : PickedPath.of(visible, state.preview!.nodes),
    );
  }

  /// 첫 탭은 출발역, 두 번째 탭은 도착역이다. 범위가 있을 때 다시 탭하면 처음부터다.
  ///
  /// 한 방향 운행·정차 때문에 그 방향으로 갈 수 없으면 두 번째 탭을 받지 않고(출발역만 남음), 순환에서 돌아가는 길로
  /// 받았으면 그렇다고 알린다. 화면은 돌려준 값으로 말풍선을 띄운다 (DESIGN §8 한 방향 운행·한 방향 정차).
  OneWayNote? tap(SelectorRow row) {
    if (!row.selectable) return null;
    final from = state.from;
    final to = state.to;
    final pick = StopPick(row.seq, row.node);
    if (from == null || to != null) {
      // 하차전용 역은 출발역이 될 수 없다. 첫 탭에서 바로 알리고 받지 않는다 (DESIGN §8 한 방향 정차)
      final only = state.stopDirections[row.seq];
      if (only?.use == 'alight') {
        return OneWayNote.stop(
          node: row.node,
          label: only!.label,
          down: only.direction == seqUp,
          alight: true,
          from: pick,
          to: pick,
          canReverse: false,
        );
      }
      _setPicks(pick, null);
    } else if (from.seq == row.seq) {
      _setPicks(null, null);
    } else {
      _setPicks(from, pick);
      final preview = state.preview;
      switch (preview?.reason) {
        case ExpandReason.stopDirection:
          _setPicks(from, null);
          final refused = state.stopDirections[row.seq] ?? state.stopDirections[from.seq];
          final at = state.stopDirections.containsKey(row.seq) ? row : state.rows.firstWhere((item) => item.seq == from.seq);
          return OneWayNote.stop(
            node: at.node,
            label: refused?.label,
            down: refused?.direction == seqUp,
            alight: refused?.use == 'alight' && at.seq == from.seq,
            from: from,
            to: pick,
          );
        case ExpandReason.oneWay:
          _setPicks(from, null);
          return OneWayNote.section(down: pick.seq < from.seq, from: from, to: pick);
        default:
          if (preview?.around ?? false) {
            return OneWayNote.around(meters: preview!.meters ?? 0, down: preview.direction == seqUp, from: from, to: pick);
          }
      }
    }
    return null;
  }

  /// 말풍선의 `방향 바꾸기`. 출발과 도착을 뒤집어 고른다.
  OneWayNote? reverse(OneWayNote note) {
    _setPicks(null, null);
    final rows = state.rows;
    tap(rows.firstWhere((row) => row.seq == note.to.seq));
    return tap(rows.firstWhere((row) => row.seq == note.from.seq));
  }

  /// 순환에서 같은 역을 다시 누르면 해제와 한 바퀴 중에 고른다 (DESIGN §8).
  bool asksLap(SelectorRow row) =>
      isLoop && row.selectable && state.from?.seq == row.seq && state.to == null;

  void pickLap() {
    final from = state.from;
    if (from != null) _setPicks(from, from);
  }

  /// 고른 것을 모두 푼다.
  void clearPicks() => _setPicks(null, null);

  /// 순환의 방향을 바꾼다.
  void setDirection(String direction) => _setPicks(state.from, state.to, direction: direction);

  void _setPicks(StopPick? from, StopPick? to, {String? direction}) {
    if (from == null) {
      state = state.copyWith(clearPicks: true);
      return;
    }
    final preview = to == null ? null : _record(from, to, direction: direction);
    ({int up, int down})? ways;
    if (isLoop && to != null && from.node != to.node) {
      final up = _record(from, to, direction: seqUp).meters;
      final down = _record(from, to, direction: seqDown).meters;
      if (up != null && down != null) ways = (up: up, down: down);
    }
    // 날짜나 방향만 바꿨으면 고른 바퀴 수를 그대로 둔다
    final laps = from.seq == state.from?.seq && to?.seq == state.to?.seq ? state.laps : 1;
    final base = state.copyWith(clearPicks: true);
    state = RecordSessionState(
      lineId: base.lineId,
      routeId: base.routeId,
      dateInput: base.dateInput,
      from: from,
      to: to,
      rows: base.rows,
      visible: base.visible,
      lines: base.lines,
      openGaps: base.openGaps,
      names: base.names,
      japanese: base.japanese,
      readings: base.readings,
      pastMarks: base.pastMarks,
      archiveNames: base.archiveNames,
      archiveAside: base.archiveAside,
      movedNotes: base.movedNotes,
      tempWindows: base.tempWindows,
      tempRoutes: base.tempRoutes,
      stopDirections: base.stopDirections,
      oneWayGaps: base.oneWayGaps,
      preview: preview,
      ridePreview: preview == null ? null : _preview(preview),
      path: preview == null || preview.nodes.isEmpty
          ? null
          : PickedPath.of(base.visible, preview.nodes),
      direction: direction,
      ways: ways,
      split: _split(preview),
      laps: laps,
      focus: base.focus,
      depth: base.depth,
    );
  }

  List<({String lineId, int meters})> _split(Expansion? expansion) {
    if (expansion == null || !expansion.saved) return const [];
    final byLine = <String, int>{};
    for (final leg in expansion.legs) {
      final meters = _network.metersOf(leg.edges, lineId: leg.lineId);
      byLine.update(leg.lineId, (m) => m + meters, ifAbsent: () => meters);
    }
    if (byLine.length < 2) return const [];
    return [for (final MapEntry(:key, :value) in byLine.entries) (lineId: key, meters: value)];
  }

  /// 두 바퀴 이상은 저장 화면의 횟수로 받는다 (DESIGN §8).
  void setLaps(int laps) => state = state.copyWith(laps: laps.clamp(1, 99));

  RidePreview? _preview(Expansion expansion) {
    if (!expansion.saved) return null;
    return previewRide(
      _network,
      lineIds: [state.lineId!],
      expansions: [expansion],
      hits: ref.read(unitHitsProvider).value ?? const {},
      today: ref.read(todayProvider),
      carryover: ref.read(carryoverProvider),
    );
  }

  DateSpan? get _date {
    final raw = state.dateInput;
    return raw == null ? null : DateSpan.parse(raw);
  }

  /// 날짜 모름에서 이관 뒤 새 역을 골랐는가. 그 역은 이어받은 노선에만 서므로 그 노선 계통을 넘어 저장한다.
  /// 날짜가 있으면 이 계통으로 펼쳐도 그날 노선(이어받은 노선)으로 저장된다 (DESIGN §8.0.1 B안, §2.8 D)
  bool _handAcross(StopPick from, StopPick to) =>
      _date == null && state.rows.any((row) => row.handedOnly && (row.seq == from.seq || row.seq == to.seq));

  /// 계통을 넘어 구간마다 나눠 저장하는가.
  bool _isAcross(StopPick from, StopPick to) => from.seq == _carried || _handAcross(from, to);

  Expansion _record(
    StopPick from,
    StopPick to, {
    String? direction,
    String? asOf,
    bool resolveUnknown = false,
  }) =>
      from.seq == _carried
          ? _resolver.across(state.lineId!, from.node, to.node, date: _date)
          : _handAcross(from, to)
          ? _resolver.acrossRoutes(
              [state.routeId!, ...SelectorBuilder(_network).handRoutes(state.routeId!)],
              from.node,
              to.node,
            )
          : _resolver.record(
        state.routeId!,
        from.node,
        to.node,
        date: _date,
        // 같은 역 두 줄이면 한 바퀴다. 방향이 있어야 펼쳐진다. 한 방향 순환은 운행 방향으로 돈다 (DESIGN §8)
        direction: direction ?? (isLoop && from.node == to.node ? _lapDirection(from.node) : null),
        asOf: asOf == null ? null : DateSpan.parse(asOf),
        resolveUnknown: resolveUnknown,
      );

  String _lapDirection(String node) =>
      _resolver.record(state.routeId!, node, node, date: _date, direction: seqUp).reason == ExpandReason.oneWay
          ? seqDown
          : seqUp;

  /// 기록에 남길 노선. 펼친 구간이 모두 한 노선이면 그 노선이고, 여러 노선에 걸치면 그날의 노선이다.
  String _labelLine(Expansion result) {
    final lines = {for (final leg in result.legs) leg.lineId};
    return lines.length == 1 ? lines.single : shownLine;
  }

  /// 계통마다 한 구간으로 나눈다 (DESIGN §2.8 F).
  Future<List<RideLeg>> _acrossLegs(Expansion result) async {
    final book = ref.read(nameBookProvider);
    final names = await ref.read(packReaderProvider).nodeNames(result.nodes, date: _date?.lo);
    return [
      for (final (seq, leg) in result.legs.indexed)
        RideLeg(
          seq: seq,
          lineId: LineId(leg.lineId),
          routeId: RouteId(leg.routeId),
          fromNode: NodeId(leg.from!),
          toNode: NodeId(leg.to!),
          direction: _network.routes[leg.routeId]!.closed
              ? _resolver.record(leg.routeId, leg.from!, leg.to!, date: _date).direction
              : null,
          // 이어받은 노선 구간은 그 노선 이름이다
          lineLabel: book.lines[leg.lineId == state.lineId ? shownLine : leg.lineId] ?? leg.lineId,
          fromLabel: names[leg.from] ?? leg.from!,
          toLabel: names[leg.to] ?? leg.to!,
        ),
    ];
  }

  /// 저장 때 묻는 것이 있으면 묻는 값을 돌려준다. 답을 넣어 다시 부른다.
  Future<SaveOutcome> save({
    String? direction,
    String? asOf,
    bool resolveUnknown = false,
  }) async {
    final from = state.from;
    final to = state.to;
    if (from == null || to == null) return const SaveFailed(null);
    final chosen = direction ?? state.direction;
    final result =
        _record(from, to, direction: chosen, asOf: asOf, resolveUnknown: resolveUnknown);
    // 그날 경로가 없으면 날짜 모름으로 내리지 않고 경고한다. 기준일 이전은 내린다 (DESIGN §2.8 J)
    if (result.demoted && result.status != ResolveStatus.invalid && normalizeRideDate(_date) != null) {
      return const SaveUnridable();
    }
    switch (result) {
      case Expansion(reason: ExpandReason.ambiguousPath):
        final up = _record(from, to, direction: seqUp);
        final down = _record(from, to, direction: seqDown);
        if (up.meters == null || down.meters == null) return SaveFailed(result.reason);
        return SaveAskDirection(upMeters: up.meters!, downMeters: down.meters!);
      case Expansion(reason: ExpandReason.relocatedParallel):
        return SaveAskRelocation(result.options);
      case Expansion(saved: false):
        return SaveFailed(result.reason);
      default:
    }
    final session = ref.read(sessionProvider);
    final now = ref.read(nowProvider)();
    final lineId = state.lineId!;
    final closed = _network.routes[state.routeId!]!.closed;
    final across = _isAcross(from, to) ? await _acrossLegs(result) : null;
    final ride = Ride(
      rideId: RideId(uuidV7(millis: now, randomBytes: secureRandomBytes())),
      datasetVersion: session.pack.edition,
      createdAt: now,
      updatedAt: now,
      deviceId: await ref.read(deviceIdProvider.future),
      dateInput: state.dateInput,
      legs: across ?? [
        for (var lap = 0; lap < (state.isLap ? state.laps : 1); lap++)
          RideLeg(
            seq: lap,
            lineId: LineId(lineId),
            routeId: RouteId(state.routeId!),
            fromNode: NodeId(from.node),
            toNode: NodeId(to.node),
            // 닫힌 계통은 방향이 없으면 그 판의 짧은 쪽이다. 판이 바뀌어도 탄 쪽이 남아야 한다
            direction: chosen ?? (closed ? result.direction : null),
            resolveAsOf: asOf,
            resolveUnknown: resolveUnknown,
            // 기록에는 그날의 노선 이름을 남긴다 (DESIGN §8). 이관 구간 안만 탔으면 이어받은 노선이다
            lineLabel: ref.read(nameBookProvider).lines[_labelLine(result)] ?? lineId,
            fromLabel: state.nameOf(from.node),
            toLabel: state.nameOf(to.node),
          ),
      ],
    );
    // 유효 범위가 비거나 고른 역에 그날 서지 않으면 저장하지 않는다
    if (RideInterpreter(_network).unridable(ride)) return const SaveUnridable();
    final expected = _preview(result);
    final change = await session.records.apply(Change(before: const [], after: [ride]));
    return SaveDone(
      change,
      ticket: RideTicketData(
        lineName: ride.legs.first.lineLabel,
        fromName: ride.legs.first.fromLabel,
        toName: ride.legs.first.toLabel,
        // 기준일보다 이른 날짜는 설명 없이 날짜 모름이다 (DESIGN §4.6)
        dateInput: result.demoted ? null : state.dateInput,
        meters: (result.meters ?? 0) * (state.isLap ? state.laps : 1),
        kmEstimated: state.kmEstimated,
        before: expected?.before,
        after: expected?.after,
      ),
    );
  }
}

/// 한 방향 운행·정차 때문에 화면이 알릴 것 (DESIGN §8 한 방향 운행·한 방향 정차).
final class OneWayNote {
  const OneWayNote.stop({
    required String this.node,
    required this.label,
    required this.down,
    required this.from,
    required this.to,
    this.alight = false,
    this.canReverse = true,
  })  : kind = OneWayKind.stop,
        meters = null;
  const OneWayNote.section({required this.down, required this.from, required this.to})
      : kind = OneWayKind.section,
        alight = false,
        canReverse = true,
        node = null,
        label = null,
        meters = null;
  const OneWayNote.around({required int this.meters, required this.down, required this.from, required this.to})
      : kind = OneWayKind.around,
        alight = false,
        canReverse = true,
        node = null,
        label = null;

  final OneWayKind kind;

  /// 한 방향 열차만 서는 역.
  final String? node;

  /// 상·하행 이름(`down`·`up`). 없으면 한 방향이라고만 적는다.
  final String? label;

  /// 탈 수 있는 방향이 목록 아래쪽인가.
  final bool down;

  /// 하차전용 역(仮降車場)을 출발역으로 골랐다.
  final bool alight;

  /// `방향 바꾸기`로 풀 수 있는가. 하차전용 역을 첫 탭으로 고른 때는 아니다.
  final bool canReverse;

  /// 순환에서 돌아가는 길로 센 거리.
  final int? meters;

  /// 사용자가 고른 출발과 도착. `방향 바꾸기`가 뒤집는다.
  final StopPick from;
  final StopPick to;
}

enum OneWayKind {
  /// 한 방향 열차만 서는 역을 반대 방향으로 골랐다. 받지 않는다.
  stop,

  /// 한 방향으로만 다니는 구간을 거꾸로 골랐다. 받지 않는다.
  section,

  /// 한 방향으로만 도는 순환에서 거꾸로 골라 돌아가는 길로 받았다.
  around,
}
