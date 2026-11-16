import '../ids.dart';

/// 사용자 기록의 공통 부분. 이 값들이 원본이고 나머지는 전부 다시 계산한다.
sealed class UserRecord {
  const UserRecord({
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
    required this.deviceId,
  });

  String get id;

  /// UTC 밀리초. 날짜가 없는 기록의 유효 범위 상한이기도 하다.
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;

  bool get isDeleted => deletedAt != null;

  /// 시각 두 개만 다른 사본. 나머지 열이 빠지지 않도록 한 곳에서만 복사한다.
  UserRecord withMeta({required int updatedAt, required int? deletedAt});

  UserRecord withDeletedAt(int? at) => withMeta(updatedAt: updatedAt, deletedAt: at);

  UserRecord stamped(int at) => withMeta(updatedAt: at, deletedAt: deletedAt);
}

/// 판이 바뀌며 달라진 기록의 내역. 옛 판이 없어지면 다시 만들 수 없어 원본이다.
final class ChangeNote extends UserRecord {
  const ChangeNote({
    required this.noteId,
    required this.edition,
    required this.body,
    required super.createdAt,
    required super.updatedAt,
    required super.deviceId,
    super.deletedAt,
  });

  final String noteId;
  final String edition;
  final String body;

  @override
  String get id => noteId;

  @override
  ChangeNote withMeta({required int updatedAt, required int? deletedAt}) => ChangeNote(
        noteId: noteId,
        edition: edition,
        body: body,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deviceId: deviceId,
        deletedAt: deletedAt,
      );
}

final class Trip extends UserRecord {
  const Trip({
    required this.tripId,
    required this.title,
    required super.createdAt,
    required super.updatedAt,
    required super.deviceId,
    super.deletedAt,
    this.note,
  });

  final TripId tripId;
  final String title;
  final String? note;

  @override
  String get id => tripId;

  Trip named(String title) => Trip(
        tripId: tripId,
        title: title,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deviceId: deviceId,
        deletedAt: deletedAt,
        note: note,
      );

  @override
  Trip withMeta({required int updatedAt, required int? deletedAt}) => Trip(
        tripId: tripId,
        title: title,
        note: note,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deviceId: deviceId,
        deletedAt: deletedAt,
      );
}

/// 기록의 한 구간. 경로는 저장하지 않는다. 판이 바뀌어도 다시 펼칠 수 있어야 한다.
final class RideLeg {
  const RideLeg({
    required this.seq,
    required this.lineId,
    required this.routeId,
    required this.fromNode,
    required this.toNode,
    required this.lineLabel,
    required this.fromLabel,
    required this.toLabel,
    this.direction,
    this.resolveAsOf,
    this.resolveUnknown = false,
  });

  final int seq;
  final LineId lineId;
  final RouteId routeId;
  final NodeId fromNode;
  final NodeId toNode;

  /// `seq_up` 또는 `seq_down`. 순환의 한 바퀴는 출발과 도착이 같고 이 값이 있다.
  final String? direction;
  final String? resolveAsOf;
  final bool resolveUnknown;

  /// 저장 당시의 표시 이름. ID가 사라져도 기록을 보여 줄 수 있어야 한다.
  final String lineLabel;
  final String fromLabel;
  final String toLabel;

  /// 경로 답만 바꾼 사본.
  RideLeg _answered({required String? direction, required String? asOf, required bool unknown}) => RideLeg(
        seq: seq,
        lineId: lineId,
        routeId: routeId,
        fromNode: fromNode,
        toNode: toNode,
        direction: direction,
        resolveAsOf: asOf,
        resolveUnknown: unknown,
        lineLabel: lineLabel,
        fromLabel: fromLabel,
        toLabel: toLabel,
      );
}

final class Ride extends UserRecord {
  const Ride({
    required this.rideId,
    required this.legs,
    required this.datasetVersion,
    required super.createdAt,
    required super.updatedAt,
    required super.deviceId,
    super.deletedAt,
    this.tripId,
    this.dateInput,
    this.times,
    this.trainName,
    this.carNo,
    this.note,
    this.serviceId,
    this.transferNodes = const [],
    this.fromAlighted = true,
    this.toAlighted = true,
    this.importSource,
    this.importRaw,
  });

  final RideId rideId;
  final TripId? tripId;

  /// 입력 원문. 날짜를 모르면 null. `date`는 계산 값이라 저장하지 않는다.
  final String? dateInput;
  final String? times;
  final String? trainName;
  final String? carNo;
  final String? note;
  final ServiceId? serviceId;
  final List<NodeId> transferNodes;
  final bool fromAlighted;
  final bool toAlighted;
  final String datasetVersion;
  final String? importSource;
  final String? importRaw;
  final List<RideLeg> legs;

  @override
  String get id => rideId;

  /// 사용자가 고친 사본. 날짜를 바꾸면 경로 답을 지우고 다시 펼친다 (DESIGN §2.8 J).
  Ride edited({
    required String? dateInput,
    required String? times,
    required String? trainName,
    required String? carNo,
    required String? note,
    required bool fromAlighted,
    required bool toAlighted,
    List<NodeId>? transferNodes,
  }) {
    final moved = dateInput != this.dateInput;
    return Ride(
      rideId: rideId,
      legs: [
        for (final leg in legs)
          leg._answered(
            direction: leg.direction,
            asOf: moved ? null : leg.resolveAsOf,
            unknown: !moved && leg.resolveUnknown,
          ),
      ],
      datasetVersion: datasetVersion,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deviceId: deviceId,
      deletedAt: deletedAt,
      tripId: tripId,
      dateInput: dateInput,
      times: times,
      trainName: trainName,
      carNo: carNo,
      note: note,
      serviceId: serviceId,
      transferNodes: transferNodes ?? this.transferNodes,
      fromAlighted: fromAlighted,
      toAlighted: toAlighted,
      importSource: importSource,
      importRaw: importRaw,
    );
  }

  /// 경로 답을 그 구간에만 붙인다. 운행 계통은 구간마다 답이 다르다 (DESIGN §2.8 D).
  Ride answered(
    bool Function(RideLeg leg) where, {
    String? direction,
    String? asOf,
    bool unknown = false,
  }) =>
      piece(
        id: rideId,
        legs: [
          for (final leg in legs)
            if (where(leg))
              leg._answered(direction: direction ?? leg.direction, asOf: asOf, unknown: unknown)
            else
              leg,
        ],
        transferNodes: transferNodes,
        fromAlighted: fromAlighted,
        toAlighted: toAlighted,
        updatedAt: updatedAt,
        deletedAt: deletedAt,
      );

  /// 여정만 바꾼 사본. 기록의 내용은 그대로다.
  Ride inTrip(TripId? trip) => Ride(
        rideId: rideId,
        legs: legs,
        datasetVersion: datasetVersion,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deviceId: deviceId,
        deletedAt: deletedAt,
        tripId: trip,
        dateInput: dateInput,
        times: times,
        trainName: trainName,
        carNo: carNo,
        note: note,
        serviceId: serviceId,
        transferNodes: transferNodes,
        fromAlighted: fromAlighted,
        toAlighted: toAlighted,
        importSource: importSource,
        importRaw: importRaw,
      );

  /// 구간 끄기의 조각. ID, 시각, 구간, 잘린 끝 말고는 전부 복사한다 (ARCHITECTURE §3.4).
  Ride piece({
    required RideId id,
    required List<RideLeg> legs,
    required List<NodeId> transferNodes,
    required bool fromAlighted,
    required bool toAlighted,
    required int updatedAt,
    required int? deletedAt,
  }) =>
      Ride(
        rideId: id,
        legs: legs,
        datasetVersion: datasetVersion,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deviceId: deviceId,
        deletedAt: deletedAt,
        tripId: tripId,
        dateInput: dateInput,
        times: times,
        trainName: trainName,
        carNo: carNo,
        note: note,
        serviceId: serviceId,
        transferNodes: transferNodes,
        fromAlighted: fromAlighted,
        toAlighted: toAlighted,
        importSource: importSource,
        importRaw: importRaw,
      );

  @override
  Ride withMeta({required int updatedAt, required int? deletedAt}) => piece(
        id: rideId,
        legs: legs,
        transferNodes: transferNodes,
        fromAlighted: fromAlighted,
        toAlighted: toAlighted,
        updatedAt: updatedAt,
        deletedAt: deletedAt,
      );
}

final class Visit extends UserRecord {
  const Visit({
    required this.visitId,
    required this.nodeId,
    required this.nodeLabel,
    required this.nodeExplicit,
    required super.createdAt,
    required super.updatedAt,
    required super.deviceId,
    super.deletedAt,
    this.dateInput,
    this.note,
  });

  final VisitId visitId;
  final NodeId nodeId;
  final String nodeLabel;
  final bool nodeExplicit;
  final String? dateInput;
  final String? note;

  @override
  String get id => visitId;

  /// 방문일을 고친 사본.
  Visit dated(String? input) => Visit(
        visitId: visitId,
        nodeId: nodeId,
        nodeLabel: nodeLabel,
        nodeExplicit: nodeExplicit,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deviceId: deviceId,
        deletedAt: deletedAt,
        dateInput: input,
        note: note,
      );

  @override
  Visit withMeta({required int updatedAt, required int? deletedAt}) => Visit(
        visitId: visitId,
        nodeId: nodeId,
        nodeLabel: nodeLabel,
        nodeExplicit: nodeExplicit,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deviceId: deviceId,
        deletedAt: deletedAt,
        dateInput: dateInput,
        note: note,
      );
}
