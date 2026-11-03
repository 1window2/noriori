import '../ids.dart';
import 'record.dart';

/// 해석 결과. `error`는 앱이 계산하지 못한 기록이고, 그 기록만 이 상태가 된다.
enum ResolveStatus {
  ok('ok'),
  partial('partial'),
  needsInput('needs_input'),
  unknownRef('unknown_ref'),
  invalid('invalid'),
  error('error');

  const ResolveStatus(this.wire);

  /// `ride_cache.resolve_status`에 쓰는 값.
  final String wire;
}

final class LegDerived {
  const LegDerived({
    required this.seq,
    required this.lineId,
    required this.routeId,
    required this.km10,
  });

  final int seq;
  final LineId lineId;
  final RouteId routeId;
  final int km10;
}

final class EdgeHit {
  const EdgeHit({
    required this.edge,
    required this.legSeq,
    required this.unitOn,
    required this.unitOff,
  });

  /// 판 안에서만 유효한 정수 키.
  final int edge;
  final int legSeq;
  final int unitOn;
  final int unitOff;
}

enum NodeRole {
  alighted('alighted'),
  passed('passed');

  const NodeRole(this.wire);

  final String wire;
}

final class NodeHit {
  const NodeHit({required this.node, required this.role});

  final NodeId node;
  final NodeRole role;
}

/// 입력과 데이터 팩에서 다시 계산할 수 있는 값. 캐시 행의 원본이다.
final class RideDerived {
  const RideDerived({
    required this.status,
    this.date,
    this.km10,
    this.effectiveLo,
    this.effectiveHi,
    this.legs = const [],
    this.edges = const [],
    this.nodes = const [],
  });

  const RideDerived.error() : this(status: ResolveStatus.error);

  final ResolveStatus status;
  final String? date;
  final int? km10;
  final String? effectiveLo;
  final String? effectiveHi;
  final List<LegDerived> legs;
  final List<EdgeHit> edges;
  final List<NodeHit> nodes;
}

final class VisitDerived {
  const VisitDerived({this.date, this.groupId});

  final String? date;

  /// 묶음 ID는 판마다 바뀔 수 있으므로 캐시에만 둔다.
  final String? groupId;
}

/// 저장과 재해석이 함께 쓰는 순수 계산. store는 이 뒤의 규칙을 모른다.
abstract interface class RecordInterpreter {
  RideDerived ride(Ride ride);
  VisitDerived visit(Visit visit);
}

/// 한 기록의 실패가 나머지를 막지 않게 한다 (불변식 2).
RideDerived interpretRideIsolated(RecordInterpreter interpreter, Ride ride) {
  try {
    return interpreter.ride(ride);
  } on Object {
    return const RideDerived.error();
  }
}

/// 방문도 같다. 해석하지 못한 방문은 날짜와 묶음이 없는 채로 남는다.
VisitDerived interpretVisitIsolated(RecordInterpreter interpreter, Visit visit) {
  try {
    return interpreter.visit(visit);
  } on Object {
    return const VisitDerived();
  }
}
