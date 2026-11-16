/// 데이터 팩의 선로망을 그대로 옮긴 값. store가 읽어 넘기고 core는 계산만 한다.
final class NetRoute {
  const NetRoute({
    required this.id,
    required this.lineId,
    required this.role,
    required this.fromNode,
    required this.toNode,
    required this.closed,
    required this.extendTo,
  });

  final String id;
  final String lineId;
  final String role;
  final String fromNode;
  final String toNode;
  final bool closed;
  final List<String> extendTo;
}

final class NetEdge {
  const NetEdge({
    required this.id,
    required this.n,
    required this.from,
    required this.to,
    required this.meters,
  });

  final String id;

  /// 타일과 `ride_edge`가 쓰는 정수 키.
  final int n;
  final String from;
  final String to;
  final int meters;
}

final class NetRouteEdge {
  const NetRouteEdge({required this.routeId, required this.seq, required this.edgeId});

  final String routeId;
  final int seq;
  final String edgeId;
}

/// 위치 미확인 표식 (DESIGN §7.3). 기준 역과 방향은 빌드가 정한다.
final class MapMarker {
  const MapMarker({
    required this.id,
    required this.anchorNode,
    required this.lineId,
    required this.toNode,
    required this.km,
    required this.abolished,
    required this.edges,
  });

  final int id;
  final String anchorNode;
  final String lineId;
  final String toNode;
  final double km;
  final String? abolished;

  /// 표식이 가리키는 구간. 이 중 하나라도 탔으면 빨강이다.
  final Set<int> edges;
}

/// 운행 계통. 입력 편의용이고 통계 단위가 아니다 (DESIGN §2.7).
final class NetService {
  const NetService({
    required this.id,
    required this.closed,
    required this.editions,
  });

  final String id;
  final bool closed;

  /// 시기별 판. 시작일 순이고 기간이 겹치지 않는다. 마지막이 지금 판(폐지됐으면 마지막 판)이다.
  final List<NetServiceEdition> editions;

  String? get validFrom => editions.isEmpty ? null : editions.first.validFrom;
  String? get validTo => editions.isEmpty ? null : editions.last.validTo;

  /// 마지막 판의 부분. 검색 결과의 끝 역처럼 날짜와 상관없는 표시에만 쓴다.
  List<NetServicePart> get parts => editions.isEmpty ? const [] : editions.last.parts;
}

/// 운행 계통의 한 판. 그 기간의 경로(parts)와 정차역이다.
final class NetServiceEdition {
  const NetServiceEdition({
    this.validFrom,
    this.validTo,
    required this.parts,
    this.stops,
  });

  /// 판의 시작일. 범위면 하한이고 모르면 null(처음부터)이다.
  final String? validFrom;

  /// 판이 끝난 날. 범위면 상한이고 지금도 이면 `ongoing`이다.
  final String? validTo;
  final List<NetServicePart> parts;

  /// 그 계통 열차가 서는 역. null이면 경로의 모든 역에 선다.
  final Set<String>? stops;

  bool halts(String node) => stops?.contains(node) ?? true;
}

final class NetServicePart {
  const NetServicePart({required this.routeId, required this.from, required this.to});

  final String routeId;
  final String from;
  final String to;
}

/// 기간의 하한, 상한. 비교는 ISO 문자열 그대로 한다.
final class NetPeriod {
  const NetPeriod({this.fromLo, this.fromHi, this.toLo, this.toHi});

  final String? fromLo;
  final String? fromHi;
  final String? toLo;
  final String? toHi;
}

final class NetStop {
  const NetStop({
    required this.routeId,
    required this.seq,
    required this.node,
    required this.kmCum,
    required this.isStop,
    required this.isExtension,
    required this.period,
    this.kmEstimated = false,
    this.gaps = const [],
  });

  final String routeId;
  final int seq;
  final String node;
  final double? kmCum;
  final bool isStop;
  final bool isExtension;
  final NetPeriod period;

  /// 정차 기간 사이 서지 않은 때 (印場 1944~1995). from이 서지 않기 시작한 날, to가 다시 선 날이다.
  final List<NetPeriod> gaps;

  /// 営業キロ를 몰라 선 위 위치로 추정한 km다. 계산에만 쓰고 화면은 `? km` (DESIGN §4.5).
  final bool kmEstimated;
}

final class NetAttr {
  const NetAttr({
    required this.edgeId,
    required this.lineId,
    required this.operatorId,
    required this.lineageId,
    required this.carryoverGroup,
    required this.period,
  });

  final String edgeId;
  final String lineId;
  final String operatorId;
  final String lineageId;
  final String carryoverGroup;
  final NetPeriod period;
}

final class NetLife {
  const NetLife({required this.edgeId, required this.suspended, required this.period});

  final String edgeId;
  final bool suspended;
  final NetPeriod period;
}

/// 한 방향으로만 지나는 칸. 그 계통에서 [from]에서 [to]로만 간다 (DESIGN §8 한 방향 운행).
final class NetOneWay {
  const NetOneWay({required this.routeId, required this.edgeId, required this.from, required this.to, required this.period});

  final String routeId;
  final String edgeId;
  final String from;
  final String to;
  final NetPeriod period;
}

/// 한 방향 열차만 서는 역. [direction]은 계통 순서 기준이고 [label]은 상·하행 이름(`down`·`up`)이다 (DESIGN §8 한 방향 정차).
final class NetStopDirection {
  const NetStopDirection({
    required this.routeId,
    required this.node,
    required this.direction,
    required this.period,
    this.label,
    this.use,
  });

  final String routeId;
  final String node;
  final String direction;
  final String? label;

  /// `alight`면 내리기만(출발역으로 못 고름), `board`면 타기만이다. 없으면 둘 다다 (仮降車場, DESIGN §8 한 방향 정차).
  final String? use;
  final NetPeriod period;
}

/// 완주율의 단위 하나 (DESIGN §3.1).
final class NetUnit {
  const NetUnit({
    required this.n,
    required this.key,
    required this.carryover,
    required this.edgeId,
    required this.meters,
    required this.normal,
    required this.dateLo,
    required this.dateHi,
    String? fromHi,
    String? toLo,
  })  : fromHi = fromHi ?? dateLo,
        toLo = toLo ?? dateHi;

  final int n;
  final String key;
  final bool carryover;
  final String edgeId;
  final int meters;

  /// 분모에 드는 단위인가.
  final bool normal;

  /// 개업일의 하한과 폐지일의 상한. 모르면 null.
  final String? dateLo;
  final String? dateHi;

  /// 개업일의 상한과 폐지일의 하한. 날짜가 범위일 때 특정 연도에 확실히 영업했는지 가린다 (DESIGN §5.4).
  /// 하루로 정해진 날짜면 [dateLo], [dateHi]와 같다.
  final String? fromHi;
  final String? toLo;
}

/// 구간이 도도부현마다 지나는 길이. 현 경계를 넘는 구간은 행이 여럿이다.
final class NetEdgePref {
  const NetEdgePref({required this.edgeId, required this.pref, required this.meters});

  final String edgeId;

  /// JIS 코드.
  final int pref;
  final int meters;
}

/// 사업자. 목록은 팩에 든 순서대로 보여 준다.
final class NetOperator {
  const NetOperator({required this.id, required this.category});

  final String id;
  final String category;
}

final class NetworkData {
  const NetworkData({
    required this.routes,
    required this.edges,
    required this.routeEdges,
    required this.stops,
    required this.attrs,
    required this.lives,
    required this.units,
    required this.publicNodes,
    required this.nodeGroups,
    this.groupNumbers = const {},
    this.services = const [],
    this.operators = const [],
    this.lineOrder = const [],
    this.edgePrefs = const [],
    this.eraMeters = const {},
    this.oneWays = const [],
    this.stopDirections = const [],
  });

  final List<NetRoute> routes;
  final List<NetEdge> edges;

  /// 계통, 순번 순서.
  final List<NetRouteEdge> routeEdges;

  /// 계통, 순번 순서.
  final List<NetStop> stops;
  final List<NetAttr> attrs;
  final List<NetLife> lives;
  final List<NetUnit> units;
  final Set<String> publicNodes;
  final List<NetService> services;
  final Map<String, String> nodeGroups;

  /// 역 묶음의 정수 키. 지도 타일의 `g`와 같다.
  final Map<String, int> groupNumbers;
  final List<NetOperator> operators;

  /// 팩에 든 노선 순서. 시드의 순서라 한 회사의 간선이 먼저 온다.
  final List<String> lineOrder;
  final List<NetEdgePref> edgePrefs;

  /// 3섹 전환 때 営業キロ를 다시 정한 구간의 국철·JR 시대 길이. 키는 `노선\u0000edge` (DESIGN §2.9 E)
  final Map<String, int> eraMeters;
  final List<NetOneWay> oneWays;
  final List<NetStopDirection> stopDirections;
}
