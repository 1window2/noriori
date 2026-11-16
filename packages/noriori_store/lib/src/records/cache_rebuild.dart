import 'package:drift/drift.dart';
import 'package:noriori_core/noriori_core.dart';

import '../db/user_db.dart';
import 'cache_writer.dart';
import 'record_store.dart';

/// 캐시 키가 다르면 전부 다시 만든다. 한 트랜잭션이라 끝나지 않으면 없던 일이다.
///
/// 앱 빌드 번호가 키이므로 규칙을 고치고 올리는 것을 잊을 상수가 없다.
final class CacheRebuild {
  CacheRebuild(this._db, this._records);

  final UserDb _db;
  final RecordStore _records;

  /// 다시 만들었으면 참.
  Future<bool> runIfStale({required String edition, required int appBuild}) async {
    final state = await _db.select(_db.cacheStateTable).getSingleOrNull();
    if (state != null && state.edition == edition && state.appBuild == appBuild) {
      return false;
    }
    await _rebuild(edition: edition, appBuild: appBuild, compare: state != null);
    return true;
  }

  Future<Map<String, RideOutcome>> _outcomes() async {
    final legs = {
      for (final ride in await _records.allRides())
        if (!ride.isDeleted && ride.legs.isNotEmpty) ride.id: ride.legs.first,
    };
    final rows = await _db.select(_db.rideCacheTable).get();
    return {
      for (final row in rows)
        if (legs[row.rideId] case final leg?)
          row.rideId: RideOutcome(
            lineId: leg.lineId.value,
            label: leg.lineLabel,
            status: row.resolveStatus,
            km10: row.km10,
            date: row.date,
          ),
    };
  }

  /// 데이터나 규칙이 바뀌어 달라진 기록을 남긴다. 옛 판은 곧 없어져 다시 만들 수 없다.
  Future<void> _report(String edition, int appBuild, Map<String, RideOutcome> before) async {
    final changes = diffRides(before, await _outcomes());
    if (changes.isEmpty) return;
    final now = _records.now();
    await _db.into(_db.changeReportTable).insert(
          ChangeReportTableCompanion.insert(
            id: 'change-$edition-$appBuild',
            createdAt: now,
            updatedAt: now,
            deviceId: '',
            edition: edition,
            body: encodeRideChanges(changes),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<void> _rebuild({required String edition, required int appBuild, required bool compare}) =>
      _db.transaction(() async {
        final before = compare ? await _outcomes() : null;
        final caches = CacheWriter(_db);
        await caches.clearAll();
        final interpreter = _records.interpreter;
        for (final ride in await _records.allRides()) {
          if (ride.isDeleted) continue;
          await caches.writeRide(ride.id, interpretRideIsolated(interpreter, ride));
        }
        for (final visit in await _records.allVisits()) {
          if (visit.isDeleted) continue;
          await caches.writeVisit(visit.id, interpretVisitIsolated(interpreter, visit));
        }
        await _db.into(_db.cacheStateTable).insert(
              CacheStateTableCompanion.insert(edition: edition, appBuild: appBuild),
            );
        if (before != null) await _report(edition, appBuild, before);
      });
}
