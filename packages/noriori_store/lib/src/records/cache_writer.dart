import 'package:drift/drift.dart';
import 'package:noriori_core/noriori_core.dart';

import '../db/user_db.dart';

/// 캐시 행을 쓰는 유일한 곳. 원본과 같은 트랜잭션 안에서 불린다.
final class CacheWriter {
  const CacheWriter(this._db);

  final UserDb _db;

  Future<void> clearRide(String rideId) async {
    await (_db.delete(_db.rideCacheTable)..where((t) => t.rideId.equals(rideId))).go();
    await (_db.delete(_db.rideLegCacheTable)..where((t) => t.rideId.equals(rideId))).go();
    await (_db.delete(_db.rideEdgeTable)..where((t) => t.rideId.equals(rideId))).go();
    await (_db.delete(_db.rideNodeTable)..where((t) => t.rideId.equals(rideId))).go();
  }

  Future<void> writeRide(String rideId, RideDerived derived) async {
    await clearRide(rideId);
    await _db.into(_db.rideCacheTable).insert(
          RideCacheTableCompanion.insert(
            rideId: rideId,
            resolveStatus: derived.status.wire,
            date: Value(derived.date),
            km10: Value(derived.km10),
            effectiveLo: Value(derived.effectiveLo),
            effectiveHi: Value(derived.effectiveHi),
          ),
        );
    await _db.batch((batch) {
      batch.insertAll(_db.rideLegCacheTable, [
        for (final leg in derived.legs)
          RideLegCacheTableCompanion.insert(
            rideId: rideId,
            seq: leg.seq,
            lineId: leg.lineId,
            routeId: leg.routeId,
            km10: leg.km10,
          ),
      ]);
      batch.insertAll(_db.rideEdgeTable, [
        for (final hit in derived.edges)
          RideEdgeTableCompanion.insert(
            edge: hit.edge,
            rideId: rideId,
            legSeq: hit.legSeq,
            unitOn: hit.unitOn,
            unitOff: hit.unitOff,
            effectiveHi: Value(derived.effectiveHi),
          ),
      ]);
      batch.insertAll(_db.rideNodeTable, [
        for (final hit in derived.nodes)
          RideNodeTableCompanion.insert(
            node: hit.node,
            rideId: rideId,
            role: hit.role.wire,
          ),
      ]);
    });
  }

  Future<void> clearVisit(String visitId) =>
      (_db.delete(_db.visitCacheTable)..where((t) => t.visitId.equals(visitId))).go();

  Future<void> writeVisit(String visitId, VisitDerived derived) =>
      _db.into(_db.visitCacheTable).insertOnConflictUpdate(
            VisitCacheTableCompanion.insert(
              visitId: visitId,
              date: Value(derived.date),
              groupId: Value(derived.groupId),
            ),
          );

  Future<void> clearAll() async {
    for (final table in _db.cacheTables) {
      await _db.delete(table).go();
    }
  }
}
