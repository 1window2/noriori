import 'package:drift/drift.dart';
import 'package:noriori_core/noriori_core.dart';

import '../db/user_db.dart';
import 'cache_writer.dart';
import 'record_mapper.dart';

/// 사용자 기록을 쓰는 유일한 곳. 동기화가 끼어들 자리도 여기다.
///
/// 원본 행과 그 기록의 캐시를 한 트랜잭션에 쓰므로 둘을 맞추는 절차가 따로 없다.
/// 백업에 넣는 설정. `device_id`와 폴더 주소처럼 기기에 묶인 값은 옮기지 않는다.
const backedUpSettings = ['theme', 'language', 'carryover', 'show_closed', 'show_archive', 'show_branches'];

final class RecordStore {
  RecordStore(this._db, {required this.interpreter, required this.now})
      : _caches = CacheWriter(_db);

  final UserDb _db;
  final CacheWriter _caches;
  final RecordInterpreter interpreter;

  /// UTC 밀리초. 시험에서 시계를 움직일 수 있게 받는다.
  final int Function() now;

  /// [change]를 저장하고 시각이 찍힌 변경을 돌려준다. 되돌리기는 이 반환값으로 만든다.
  Future<Change> apply(Change change) => _db.transaction(() async {
        final at = now();
        final written = <UserRecord>[];
        for (final row in change.after) {
          final stamped = row.stamped(
            nextStamp(now: at, previous: await _stampOf(row)),
          );
          await _write(stamped);
          written.add(stamped);
        }
        return Change(before: change.before, after: written);
      });

  /// 병합 복원. 시각을 새로 찍지 않는다. 찍으면 옛 파일이 뒤따르는 새 파일을 이긴다.
  ///
  /// 들어온 행 수를 돌려준다. 전체가 한 트랜잭션이라 도중에 죽으면 없던 일이다.
  Future<int> merge(BackupContents contents) => _db.transaction(() async {
        var taken = 0;
        for (final row in contents.all) {
          if (incomingWins(local: await _stampOf(row), incoming: row.updatedAt)) {
            await _write(row);
            taken++;
          }
        }
        for (final MapEntry(:key, :value) in contents.settings.entries) {
          if (!backedUpSettings.contains(key)) continue;
          // 옛 파일이 지금 고른 설정을 덮지 않는다. 재설치 뒤처럼 빈 값만 채운다
          await _db.into(_db.settingTable).insert(
                SettingTableCompanion.insert(key: key, value: value),
                mode: InsertMode.insertOrIgnore,
              );
        }
        return taken;
      });

  /// 백업에 넣을 원본 전부. 한 읽기 트랜잭션이라 기록과 구간이 어긋나지 않는다.
  Future<BackupContents> snapshot() => _db.transaction(() async {
        final trips = await _db.select(_db.tripTable).get();
        final settings = await (_db.select(_db.settingTable)
              ..where((t) => t.key.isIn(backedUpSettings)))
            .get();
        return BackupContents(
          trips: [for (final row in trips) tripFromRow(row)],
          rides: await allRides(),
          visits: await allVisits(),
          changeNotes: [
            for (final row in await _db.select(_db.changeReportTable).get()) noteFromRow(row),
          ],
          settings: {for (final row in settings) row.key: row.value},
        );
      });

  Future<Ride?> ride(RideId id) async {
    final row = await (_db.select(_db.rideTable)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : rideFromRow(row, await _legsOf(id));
  }

  Future<Trip?> trip(TripId id) async {
    final row = await (_db.select(_db.tripTable)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : tripFromRow(row);
  }

  Future<Visit?> visit(VisitId id) async {
    final row = await (_db.select(_db.visitTable)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : visitFromRow(row);
  }

  /// 삭제 표시를 포함한 모든 기록. 재해석과 백업이 쓴다.
  Future<List<Ride>> allRides() async {
    final legs = await (_db.select(_db.rideLegTable)
          ..orderBy([(t) => OrderingTerm(expression: t.rideId), (t) => OrderingTerm(expression: t.seq)]))
        .get();
    final byRide = <String, List<RideLegRow>>{};
    for (final leg in legs) {
      (byRide[leg.rideId] ??= []).add(leg);
    }
    final rows = await _db.select(_db.rideTable).get();
    return [for (final row in rows) rideFromRow(row, byRide[row.id] ?? const [])];
  }

  /// 삭제 표시된 기록. 구간 켜기가 되살릴 조각을 찾고, 삭제한 기록 화면이 보여 준다.
  Future<List<Ride>> deletedRides() async {
    final rows = await (_db.select(_db.rideTable)..where((t) => t.deletedAt.isNotNull())).get();
    return [
      for (final row in rows) rideFromRow(row, await _legsOf(row.id)),
    ];
  }

  /// 삭제 표시된 역 방문. 삭제한 기록 화면이 보여 준다.
  Future<List<Visit>> deletedVisits() async {
    final rows = await (_db.select(_db.visitTable)..where((t) => t.deletedAt.isNotNull())).get();
    return [for (final row in rows) visitFromRow(row)];
  }

  Future<List<Visit>> allVisits() async {
    final rows = await _db.select(_db.visitTable).get();
    return [for (final row in rows) visitFromRow(row)];
  }

  Future<int?> _stampOf(UserRecord row) async {
    final (TableInfo<Table, Object?> table, GeneratedColumn<String> id, GeneratedColumn<int> stamp) = switch (row) {
      Ride() => (_db.rideTable, _db.rideTable.id, _db.rideTable.updatedAt),
      Visit() => (_db.visitTable, _db.visitTable.id, _db.visitTable.updatedAt),
      Trip() => (_db.tripTable, _db.tripTable.id, _db.tripTable.updatedAt),
      ChangeNote() => (_db.changeReportTable, _db.changeReportTable.id, _db.changeReportTable.updatedAt),
    };
    final query = _db.selectOnly(table)
      ..addColumns([stamp])
      ..where(id.equals(row.id));
    final result = await query.getSingleOrNull();
    return result?.read(stamp);
  }

  Future<List<RideLegRow>> _legsOf(String rideId) => (_db.select(_db.rideLegTable)
        ..where((t) => t.rideId.equals(rideId))
        ..orderBy([(t) => OrderingTerm(expression: t.seq)]))
      .get();

  Future<void> _write(UserRecord row) => switch (row) {
        Ride() => _writeRide(row),
        Visit() => _writeVisit(row),
        Trip() => _db.into(_db.tripTable).insertOnConflictUpdate(tripToRow(row)),
        ChangeNote() => _db.into(_db.changeReportTable).insertOnConflictUpdate(noteToRow(row)),
      };

  Future<void> _writeRide(Ride ride) async {
    await _db.into(_db.rideTable).insertOnConflictUpdate(rideToRow(ride));
    await (_db.delete(_db.rideLegTable)..where((t) => t.rideId.equals(ride.id))).go();
    await _db.batch(
      (batch) => batch.insertAll(_db.rideLegTable, [
        for (final leg in ride.legs) legToRow(ride.rideId, leg),
      ]),
    );
    if (ride.isDeleted) return _caches.clearRide(ride.id);
    await _caches.writeRide(ride.id, interpretRideIsolated(interpreter, ride));
  }

  Future<void> _writeVisit(Visit visit) async {
    await _db.into(_db.visitTable).insertOnConflictUpdate(visitToRow(visit));
    if (visit.isDeleted) return _caches.clearVisit(visit.id);
    await _caches.writeVisit(visit.id, interpretVisitIsolated(interpreter, visit));
  }
}
