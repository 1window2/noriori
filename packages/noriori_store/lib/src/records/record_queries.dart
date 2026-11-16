import 'package:drift/drift.dart' as d;

import 'package:noriori_core/noriori_core.dart';

import '../db/user_db.dart';

/// 기록 목록 한 줄. 라벨은 저장 당시 값이고 화면은 [PackReader.currentNames]를 거쳐 받는다.
final class RideSummary {
  const RideSummary({
    required this.rideId,
    required this.status,
    required this.lineLabel,
    required this.fromLabel,
    required this.toLabel,
    this.lineId,
    this.fromNode,
    this.toNode,
    this.date,
    this.dateInput,
    this.effectiveHi,
    this.tripId,
    this.km10,
    this.serviceId,
    this.serviceName,
  });

  final RideId rideId;
  final ResolveStatus status;
  final String lineLabel;
  final String fromLabel;
  final String toLabel;
  final String? lineId;
  final String? fromNode;
  final String? toNode;
  final String? date;
  final String? dateInput;

  /// 이 기록을 이 날짜의 이름으로 보여 준다 (DESIGN §14.2).
  final String? effectiveHi;
  final TripId? tripId;
  final int? km10;

  /// 운행 계통으로 입력한 기록. 표시용이다 (DESIGN §2.7).
  final ServiceId? serviceId;
  final String? serviceName;

  /// 하루까지 아는 기록. 활동 캘린더는 이것만 찍는다.
  bool get onExactDay {
    final day = date;
    return day != null && dateInput == day && DateSpan.parse(day).isDay;
  }

  /// 화면에 보이는 날짜. 해석한 기록은 캐시가 답이다. 날짜 모름으로 내려갔으면 입력을 보이지 않는다.
  String? get shownDate => status == ResolveStatus.ok || status == ResolveStatus.partial
      ? date
      : date ?? dateInput;

  RideSummary named({String? line, String? from, String? to, String? service}) => RideSummary(
        rideId: rideId,
        status: status,
        lineLabel: line ?? lineLabel,
        fromLabel: from ?? fromLabel,
        toLabel: to ?? toLabel,
        lineId: lineId,
        fromNode: fromNode,
        toNode: toNode,
        date: date,
        dateInput: dateInput,
        effectiveHi: effectiveHi,
        tripId: tripId,
        km10: km10,
        serviceId: serviceId,
        serviceName: service ?? serviceName,
      );
}

/// 판 하나의 변경 내역.
final class RideChangeReport {
  const RideChangeReport({required this.edition, required this.createdAt, required this.changes});

  final String edition;
  final int createdAt;
  final List<RideChange> changes;
}

/// 여정 한 줄.
final class TripSummary {
  const TripSummary({
    required this.tripId,
    required this.title,
    required this.rides,
    required this.km10,
    this.firstDate,
    this.lastDate,
  });

  final TripId tripId;
  final String title;
  final int rides;
  final int km10;
  final String? firstDate;
  final String? lastDate;
}

/// 역 방문 한 줄.
final class VisitSummary {
  const VisitSummary({
    required this.visitId,
    required this.node,
    required this.label,
    this.dateInput,
    this.date,
    this.note,
  });

  final VisitId visitId;
  final String node;
  final String label;
  final String? dateInput;

  /// 계산된 날짜. 기준일보다 이르면 입력값이 있어도 없다 (DESIGN §4.6).
  final String? date;
  final String? note;
}

/// 화면이 지켜보는 쿼리. 지도와 통계는 캐시 없이 여기서 계산한다 (ARCHITECTURE §0.2).
final class RecordQueries {
  const RecordQueries(this._db);

  final UserDb _db;

  Stream<List<RideSummary>> watchRides() => _db.customSelect(
        '''
        SELECT r.id, r.date_input, r.service_id, r.trip_id, c.date, c.km10, c.resolve_status, c.effective_hi,
               first.line_label, first.from_label, last.to_label,
               coalesce(lc.line_id, first.line_id) AS line_id, first.from_node, last.to_node,
               CASE WHEN c.resolve_status IN ('ok', 'partial') THEN c.date
                    ELSE coalesce(c.date, r.date_input) END AS shown
        FROM ride r
        JOIN ride_cache c ON c.ride_id = r.id
        JOIN ride_leg first ON first.ride_id = r.id
          AND first.seq = (SELECT min(seq) FROM ride_leg WHERE ride_id = r.id)
        JOIN ride_leg last ON last.ride_id = r.id
          AND last.seq = (SELECT max(seq) FROM ride_leg WHERE ride_id = r.id)
        LEFT JOIN ride_leg_cache lc ON lc.ride_id = r.id AND lc.seq = 0
        WHERE r.deleted_at IS NULL
        ORDER BY shown IS NULL, shown DESC, r.created_at DESC
        ''',
        readsFrom: {_db.rideTable, _db.rideCacheTable, _db.rideLegTable, _db.rideLegCacheTable},
      ).watch().map((rows) => [
            for (final row in rows)
              RideSummary(
                rideId: RideId(row.read('id')),
                status: _status(row.read('resolve_status')),
                lineLabel: row.read('line_label'),
                fromLabel: row.read('from_label'),
                toLabel: row.read('to_label'),
                lineId: row.read('line_id'),
                fromNode: row.read('from_node'),
                toNode: row.read('to_node'),
                date: row.readNullable('date'),
                dateInput: row.readNullable('date_input'),
                effectiveHi: row.readNullable('effective_hi'),
                tripId: switch (row.readNullable<String>('trip_id')) {
                  final id? => TripId(id),
                  null => null,
                },
                km10: row.readNullable('km10'),
                serviceId: switch (row.readNullable<String>('service_id')) {
                  final id? => ServiceId(id),
                  null => null,
                },
              ),
          ]);

  /// 탄 구간의 정수 키. 지도 칠하기가 쓴다.
  Stream<Set<int>> watchRiddenEdges() => _db.customSelect(
        'SELECT DISTINCT edge FROM ride_edge',
        readsFrom: {_db.rideEdgeTable},
      ).watch().map((rows) => {for (final row in rows) row.read<int>('edge')});

  /// 데이터 정정으로 달라진 기록. 최근 판이 먼저다.
  Stream<List<RideChangeReport>> watchChangeReports() => _db.customSelect(
        'SELECT edition, body, created_at FROM change_report WHERE deleted_at IS NULL ORDER BY created_at DESC',
        readsFrom: {_db.changeReportTable},
      ).watch().map((rows) => [
            for (final row in rows)
              RideChangeReport(
                edition: row.read('edition'),
                createdAt: row.read('created_at'),
                changes: decodeRideChanges(row.read('body')),
              ),
          ]);

  /// 구간을 처음 탄 해. 날짜 모름 기록은 들지 않는다. 타임 슬라이더가 쓴다.
  Stream<Map<int, int>> watchRiddenEdgeYears() => _db.customSelect(
        'SELECT e.edge, min(substr(c.date, 1, 4)) AS first FROM ride_edge e '
        'JOIN ride_cache c ON c.ride_id = e.ride_id '
        "WHERE c.date IS NOT NULL AND c.date NOT LIKE '___X%' GROUP BY e.edge",
        readsFrom: {_db.rideEdgeTable, _db.rideCacheTable},
      ).watch().map((rows) => {
            for (final row in rows) row.read<int>('edge'): int.parse(row.read<String>('first')),
          });

  /// 단위마다 마지막으로 탄 해. 해를 아는 기록만 든다. 폐선 컬렉션이 쓴다.
  Future<Map<int, int>> lastRideYears({required bool carryover}) async {
    final unit = _unit(carryover);
    final rows = await _db.customSelect(
      'SELECT e.$unit AS unit, max(substr(c.date, 1, 4)) AS last FROM ride_edge e '
      'JOIN ride_cache c ON c.ride_id = e.ride_id '
      "WHERE c.date IS NOT NULL AND c.date NOT LIKE '___X%' GROUP BY e.$unit",
      readsFrom: {_db.rideEdgeTable, _db.rideCacheTable},
    ).get();
    return {for (final row in rows) row.read<int>('unit'): int.parse(row.read<String>('last'))};
  }

  /// 지나간 역. 지도와 통계가 묶음으로 세어 쓴다.
  Stream<Set<String>> watchRiddenNodes() => _db.customSelect(
        'SELECT DISTINCT node FROM ride_node',
        readsFrom: {_db.rideNodeTable},
      ).watch().map((rows) => {for (final row in rows) row.read<String>('node')});

  /// 승하차한 역. 지도의 꽉 찬 원이다 (DESIGN §5.3).
  Stream<Set<String>> watchAlightedNodes() => _db.customSelect(
        "SELECT DISTINCT node FROM ride_node WHERE role = 'alighted'",
        readsFrom: {_db.rideNodeTable},
      ).watch().map((rows) => {for (final row in rows) row.read<String>('node')});

  /// 여정 목록. 최근에 탄 것이 먼저다. 기록이 없는 여정은 뺀다.
  Stream<List<TripSummary>> watchTrips() => _db.customSelect(
        'SELECT t.id, t.title, count(r.id) AS rides, coalesce(sum(c.km10), 0) AS km10, '
        'min(c.date) AS first_date, max(c.date) AS last_date FROM trip t '
        'JOIN ride r ON r.trip_id = t.id AND r.deleted_at IS NULL '
        'LEFT JOIN ride_cache c ON c.ride_id = r.id '
        'WHERE t.deleted_at IS NULL GROUP BY t.id '
        'ORDER BY last_date IS NULL, last_date DESC, t.created_at DESC',
        readsFrom: {_db.tripTable, _db.rideTable, _db.rideCacheTable},
      ).watch().map((rows) => [
            for (final row in rows)
              TripSummary(
                tripId: TripId(row.read('id')),
                title: row.read('title'),
                rides: row.read('rides'),
                km10: row.read('km10'),
                firstDate: row.readNullable('first_date'),
                lastDate: row.readNullable('last_date'),
              ),
          ]);

  /// 여정에 묶인 기록.
  Future<List<RideId>> ridesInTrip(TripId id) async {
    final rows = await _db.customSelect(
      'SELECT id FROM ride WHERE trip_id = ? AND deleted_at IS NULL',
      variables: [d.Variable.withString(id.value)],
    ).get();
    return [for (final row in rows) RideId(row.read<String>('id'))];
  }

  /// 역 방문 목록. 최근 것이 먼저다.
  Stream<List<VisitSummary>> watchVisits() => _db.customSelect(
        'SELECT v.id, v.node_id, v.node_label, v.date_input, v.note, c.date FROM visit v '
        'LEFT JOIN visit_cache c ON c.visit_id = v.id '
        'WHERE v.deleted_at IS NULL ORDER BY v.created_at DESC',
        readsFrom: {_db.visitTable, _db.visitCacheTable},
      ).watch().map((rows) => [
            for (final row in rows)
              VisitSummary(
                visitId: VisitId(row.read('id')),
                node: row.read('node_id'),
                label: row.read('node_label'),
                dateInput: row.readNullable('date_input'),
                date: row.readNullable('date'),
                note: row.readNullable('note'),
              ),
          ]);

  /// 최근에 탄 노선. "이어서 타기"가 쓴다.
  Stream<List<String>> watchRecentLines({int limit = 40}) => _db.customSelect(
        'SELECT l.line_id, max(r.created_at) AS at FROM ride_leg_cache l '
        'JOIN ride r ON r.id = l.ride_id WHERE r.deleted_at IS NULL '
        'GROUP BY 1 ORDER BY at DESC LIMIT $limit',
        readsFrom: {_db.rideLegCacheTable, _db.rideTable},
      ).watch().map((rows) => [for (final row in rows) row.read<String>('line_id')]);

  /// 탄 단위와 그 단위의 최소 `effective_hi`.
  Stream<Map<int, String?>> watchUnitHits({required bool carryover}) {
    final unit = _unit(carryover);
    return _db.customSelect(
      'SELECT $unit AS unit, min(effective_hi) AS hi FROM ride_edge GROUP BY 1',
      readsFrom: {_db.rideEdgeTable},
    ).watch().map(
          (rows) => {
            for (final row in rows) row.read<int>('unit'): row.readNullable<String>('hi'),
          },
        );
  }

  /// 실제로 달린 누적 거리. 분모 밖 구간과 반복 탑승까지 든다 (DESIGN §3.1).
  Stream<int> watchTotalKm10() => _db.customSelect(
        'SELECT coalesce(sum(km10), 0) AS km FROM ride_cache',
        readsFrom: {_db.rideCacheTable},
      ).watchSingle().map((row) => row.read<int>('km'));

  /// 이 구간을 지난 기록의 수.
  Future<int> countRidesOn(Set<int> edges) async {
    if (edges.isEmpty) return 0;
    final row = await _db.customSelect(
      'SELECT count(DISTINCT ride_id) AS n FROM ride_edge WHERE edge IN (${_marks(edges.length)})',
      variables: [for (final n in edges) d.Variable.withInt(n)],
    ).getSingle();
    return row.read<int>('n');
  }

  /// 이 단위를 덮는 기록. 구간 끄기가 고칠 대상이다 (ARCHITECTURE §3.4).
  Future<List<RideId>> ridesCovering(Set<int> units, {required bool carryover}) async {
    if (units.isEmpty) return const [];
    final rows = await _db.customSelect(
      'SELECT DISTINCT ride_id FROM ride_edge WHERE ${_unit(carryover)} IN (${_marks(units.length)})',
      variables: [for (final n in units) d.Variable.withInt(n)],
    ).get();
    return [for (final row in rows) RideId(row.read<String>('ride_id'))];
  }

  /// 날짜 모름 기록으로 탄 단위.
  Stream<Set<int>> watchUndatedUnits({bool carryover = true}) => _db.customSelect(
        'SELECT DISTINCT e.${_unit(carryover)} AS unit FROM ride_edge e '
        'JOIN ride_cache c ON c.ride_id = e.ride_id WHERE c.date IS NULL',
        readsFrom: {_db.rideEdgeTable, _db.rideCacheTable},
      ).watch().map((rows) => {for (final row in rows) row.read<int>('unit')});

  /// 마지막으로 바뀐 시각. 백업이 오래됐는지 판단한다.
  Stream<int?> watchLastChange() => _db.customSelect(
        'SELECT max(at) AS at FROM ('
        'SELECT max(updated_at) AS at FROM ride '
        'UNION ALL SELECT max(updated_at) FROM visit '
        'UNION ALL SELECT max(updated_at) FROM trip)',
        readsFrom: {_db.rideTable, _db.visitTable, _db.tripTable},
      ).watchSingle().map((row) => row.readNullable<int>('at'));

  /// 승계 설정에 맞는 단위 열.
  String _unit(bool carryover) => carryover ? 'unit_on' : 'unit_off';

  String _marks(int count) => List.filled(count, '?').join(', ');

  ResolveStatus _status(String wire) =>
      ResolveStatus.values.firstWhere((s) => s.wire == wire, orElse: () => ResolveStatus.error);
}
