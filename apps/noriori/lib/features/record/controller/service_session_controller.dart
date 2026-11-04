import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/session_providers.dart';
import 'record_session_controller.dart' show RideTicketData;

/// 운전 계통 입력의 상태. 한 줄 노선도에서 두 역을 고른다 (DESIGN §8).
final class ServiceSessionState {
  const ServiceSessionState({
    this.service,
    this.title = '',
    this.dateInput,
    this.stops = const [],
    this.open = const {},
    this.names = const {},
    this.lines = const {},
    this.from,
    this.to,
    this.up,
    this.ways,
    this.laps = 1,
    this.path = const [],
    this.legs,
    this.summary = const [],
    this.meters,
  });

  final NetService? service;
  final String title;
  final String? dateInput;

  /// 날짜와 상관없는 전체 역. 그날 없는 역은 흐리게 그린다.
  final List<ServiceStop> stops;

  /// 그날 고를 수 있는 역.
  final Set<String> open;
  final Map<String, String> names;
  final Map<String, String> lines;
  final ServiceStop? from;
  final ServiceStop? to;

  /// 고리의 방향. 고르지 않으면 짧은 쪽이다.
  final bool? up;

  /// 고리에서 두 방향의 거리.
  final ({int up, int down})? ways;

  /// 한 바퀴를 몇 번 돌았는가.
  final int laps;

  /// 고른 구간을 지나는 역.
  final List<ServiceStop> path;
  final List<RideLeg>? legs;
  final List<ServiceLegSummary> summary;
  final int? meters;

  String nameOf(String node) => names[node] ?? node;

  bool get isLap => from != null && from?.node == to?.node;

  /// 출발역을 고른 뒤 도착역 후보까지 몇 역인가.
  int? stopsAway(ServiceStop stop) {
    final start = from;
    if (start == null || to != null || !open.contains(stop.node) || start.index == stop.index) {
      return null;
    }
    final lo = start.index < stop.index ? start.index : stop.index;
    final hi = start.index < stop.index ? stop.index : start.index;
    return stops.where((s) => s.index > lo && s.index <= hi && open.contains(s.node)).length;
  }

  /// `stops[index]`와 다음 역 사이가 고른 구간에 드는가.
  bool covers(int index) {
    for (var at = 0; at + 1 < path.length; at++) {
      final a = path[at].node;
      final b = path[at + 1].node;
      final p = stops[index].node;
      final q = stops[index + 1].node;
      if ((a == p && b == q) || (a == q && b == p)) return true;
    }
    return false;
  }

  bool passes(String node) => path.any((stop) => stop.node == node);
}

sealed class ServiceOutcome {
  const ServiceOutcome();
}

/// 저장 결과. 승차권에 그대로 넘긴다.
final class ServiceSaved extends ServiceOutcome {
  const ServiceSaved(this.change, {required this.ticket});

  final Change change;
  final RideTicketData ticket;
}

/// 그날 그 구간을 탈 수 없다. 경고하고 저장하지 않는다 (DESIGN §2.8 J).
final class ServiceUnridable extends ServiceOutcome {
  const ServiceUnridable();
}

final serviceSessionProvider =
    NotifierProvider.autoDispose<ServiceSessionController, ServiceSessionState>(
  ServiceSessionController.new,
);

final class ServiceSessionController extends Notifier<ServiceSessionState> {
  @override
  ServiceSessionState build() => const ServiceSessionState();

  Network get _network => ref.read(networkProvider);

  ServiceSplitter get _splitter => ServiceSplitter(_network);

  /// 고를 때 쓰는 날짜. 기준일보다 이르면 날짜 모름이다 (DESIGN §4.6).
  DateSpan? get _date {
    final raw = state.dateInput;
    return raw == null ? null : normalizeRideDate(DateSpan.parse(raw));
  }

  Future<void> open(String serviceId) async {
    final service = _network.data.services.firstWhere((s) => s.id == serviceId);
    final title = (await ref.read(packReaderProvider).serviceNames([serviceId]))[serviceId] ?? serviceId;
    final stops = _splitter.stops(service, null);
    final names = await ref.read(packReaderProvider).nodeNames(stops.map((s) => s.node));
    state = ServiceSessionState(
      service: service,
      title: title,
      dateInput: ref.read(todayProvider),
      stops: stops,
      names: names,
      lines: ref.read(nameBookProvider).lines,
    );
    _applyDate();
  }

  void _applyDate() {
    final current = state;
    state = _with(current, open: _splitter.openOn(current.service!, _date));
  }

  /// 탑승일을 바꾸면 고를 수 있는 역을 다시 정한다.
  ///
  /// 고른 구간을 그날 탈 수 없으면 날짜 변경을 받지 않는다. 고른 역과 원래 날짜는 그대로다
  /// (DESIGN §8.0.1 탑승일, §2.8 J). 받지 않았으면 참이고 화면이 경고한다.
  bool setDate(String? raw) {
    final current = state;
    state = ServiceSessionState(
      service: current.service,
      title: current.title,
      dateInput: raw,
      stops: current.stops,
      names: current.names,
      lines: current.lines,
    );
    _applyDate();
    final from = current.from;
    final to = current.to;
    if (from == null) return false;
    final lost = [from, ?to].any((stop) => !state.open.contains(stop.node));
    if (!lost && to != null) _pick(from, to, current.up, current.laps);
    if (lost || _unridable()) {
      state = current;
      return true;
    }
    if (to == null) state = _with(state, from: from);
    return false;
  }

  /// 고른 구간을 탑승일에 탈 수 없는가. 기준일 이전은 기록 범위 밖이라 아니다.
  bool _unridable() {
    final legs = state.legs;
    if (legs == null) return false;
    return RideInterpreter(_network).unridable(
      Ride(
        rideId: const RideId('draft'),
        legs: legs,
        datasetVersion: '',
        createdAt: 0,
        updatedAt: 0,
        deviceId: '',
        dateInput: state.dateInput,
      ),
    );
  }

  ServiceSessionState _with(
    ServiceSessionState base, {
    Set<String>? open,
    ServiceStop? from,
    ServiceStop? to,
    bool? up,
    ({int up, int down})? ways,
    int? laps,
    List<ServiceStop>? path,
    List<RideLeg>? legs,
    List<ServiceLegSummary>? summary,
    int? meters,
  }) =>
      ServiceSessionState(
        service: base.service,
        title: base.title,
        dateInput: base.dateInput,
        stops: base.stops,
        open: open ?? base.open,
        names: base.names,
        lines: base.lines,
        from: from,
        to: to,
        up: up,
        ways: ways,
        laps: laps ?? 1,
        path: path ?? const [],
        legs: legs,
        summary: summary ?? const [],
        meters: meters,
      );

  /// 고리에서 같은 역을 다시 누르면 해제와 한 바퀴 중에 고른다 (DESIGN §8).
  bool asksLap(ServiceStop stop) =>
      (state.service?.closed ?? false) && state.from?.index == stop.index && state.to == null;

  void pickLap() {
    final from = state.from;
    if (from != null) _pick(from, from, null, 1);
  }

  /// 첫 탭은 출발역, 둘째 탭은 도착역이다. 범위가 있을 때 다시 누르면 처음부터다.
  void tap(ServiceStop stop) {
    if (!state.open.contains(stop.node)) return;
    final from = state.from;
    if (from == null || state.to != null) {
      state = _with(state, from: stop);
    } else if (from.index == stop.index) {
      state = _with(state);
    } else {
      _pick(from, stop, null, 1);
    }
  }

  void setUp(bool up) {
    final from = state.from;
    final to = state.to;
    if (from != null && to != null) _pick(from, to, up, state.laps);
  }

  void setLaps(int laps) {
    final from = state.from;
    final to = state.to;
    if (from != null && to != null) _pick(from, to, state.up, laps.clamp(1, 99));
  }

  void clear() => state = _with(state);

  List<RideLeg>? _legs(ServiceStop from, ServiceStop to, bool up) => _splitter.legs(
        state.service!,
        state.stops,
        from,
        to,
        date: _date,
        up: up,
        lineName: (id) => state.lines[id] ?? id,
        nodeName: state.nameOf,
      );

  RideDerived? _derive(List<RideLeg>? legs) {
    if (legs == null) return null;
    final derived = RideInterpreter(_network).ride(
      Ride(
        rideId: const RideId('preview'),
        legs: legs,
        datasetVersion: '',
        createdAt: 0,
        updatedAt: 0,
        deviceId: '',
        dateInput: state.dateInput,
      ),
    );
    return derived.status == ResolveStatus.ok ? derived : null;
  }

  void _pick(ServiceStop from, ServiceStop to, bool? chosen, int laps) {
    final closed = state.service!.closed;
    final upLegs = _legs(from, to, true);
    final downLegs = closed ? _legs(from, to, false) : null;
    final upKm = _derive(upLegs)?.km10;
    final downKm = _derive(downLegs)?.km10;
    final ways = upKm != null && downKm != null && from.node != to.node
        ? (up: upKm * 100, down: downKm * 100)
        : null;
    final up = chosen ?? (ways == null || ways.up <= ways.down);
    final once = up ? upLegs : downLegs;
    final repeat = state.service!.closed && from.node == to.node ? laps : 1;
    final legs = once == null
        ? null
        : [
            for (var lap = 0; lap < repeat; lap++)
              for (final leg in once)
                RideLeg(
                  seq: lap * once.length + leg.seq,
                  lineId: leg.lineId,
                  routeId: leg.routeId,
                  fromNode: leg.fromNode,
                  toNode: leg.toNode,
                  direction: leg.direction,
                  lineLabel: leg.lineLabel,
                  fromLabel: leg.fromLabel,
                  toLabel: leg.toLabel,
                ),
          ];
    final derived = _derive(legs);
    state = _with(
      state,
      from: from,
      to: to,
      up: chosen ?? (closed ? up : null),
      ways: ways,
      laps: laps,
      path: _splitter.path(state.service!, state.stops, from, to, up: up),
      legs: derived == null ? null : legs,
      summary: derived == null ? const [] : summarizeLegs(derived),
      meters: derived == null ? null : (derived.km10 ?? 0) * 100,
    );
  }

  Future<ServiceOutcome?> save() async {
    final legs = state.legs;
    if (legs == null) return null;
    final session = ref.read(sessionProvider);
    final now = ref.read(nowProvider)();
    final ride = _splitter.ride(
      state.service!,
      legs,
      id: RideId(uuidV7(millis: now, randomBytes: secureRandomBytes())),
      dateInput: state.dateInput,
      datasetVersion: session.pack.edition,
      deviceId: await ref.read(deviceIdProvider.future),
      now: now,
    );
    if (ride == null) return null;
    final interpreter = RideInterpreter(_network);
    // 그날 탈 수 없으면 날짜 모름으로 내리지 않고 경고한다 (DESIGN §2.8 J)
    if (interpreter.unridable(ride)) return const ServiceUnridable();
    final expansions = interpreter.expansions(ride);
    // 기준일보다 이른 날짜는 설명 없이 날짜 모름이다 (DESIGN §4.6)
    final demoted = expansions.any((expansion) => expansion.demoted);
    // 저장 뒤에는 탄 구간이 이미 들어가 있으니 오르는 값은 먼저 계산한다
    final preview = previewRide(
      _network,
      lineIds: {for (final leg in ride.legs) leg.lineId.value}.toList(),
      expansions: expansions,
      hits: ref.read(unitHitsProvider).value ?? const {},
      today: ref.read(todayProvider),
      carryover: ref.read(carryoverProvider),
    );
    final change = await session.records.apply(Change(before: const [], after: [ride]));
    return ServiceSaved(
      change,
      ticket: RideTicketData(
        lineName: state.title,
        fromName: ride.legs.first.fromLabel,
        toName: ride.legs.last.toLabel,
        dateInput: demoted ? null : state.dateInput,
        meters: state.meters ?? 0,
        before: preview.before,
        after: preview.after,
      ),
    );
  }
}
