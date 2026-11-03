import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noriori_core/noriori_core.dart';
import 'package:noriori_store/noriori_store.dart';

import '../../../app/session_providers.dart';

export 'package:noriori_store/noriori_store.dart' show RideSummary, VisitSummary;

/// 이름은 지금 판의 값이다. 표기를 정정하면 옛 기록에도 보인다.
final rideListProvider = rideSummariesProvider;

/// 수정 화면이 여는 기록.
final rideProvider = FutureProvider.autoDispose.family<Ride?, String>(
  (ref, id) => ref.watch(sessionProvider).records.ride(RideId(id)),
);

/// 기록 경로 위의 표시 역과 이름. `여기서 갈아탐`을 고른다.
final rideStopsProvider = FutureProvider.autoDispose.family<Map<String, String>, String>((ref, id) async {
  final ride = await ref.watch(rideProvider(id).future);
  if (ride == null) return const {};
  final network = ref.watch(networkProvider);
  final nodes = [
    for (final expansion in RideInterpreter(network).expansions(ride))
      for (final node in expansion.nodes)
        if (network.isShown(node)) node,
  ];
  if (nodes.length < 3) return const {};
  final inside = nodes.sublist(1, nodes.length - 1);
  return ref.watch(packReaderProvider).nodeNames(inside);
});

final recordCommandsProvider = Provider<RecordCommands>(
  (ref) => RecordCommands(ref.watch(sessionProvider).records, ref.watch(nowProvider)),
);

/// 기록을 바꾸는 명령. 모든 변경은 `RecordStore.apply`를 지난다.
final class RecordCommands {
  const RecordCommands(this._records, this._now);

  final RecordStore _records;
  final int Function() _now;

  /// 되돌릴 수 있도록 저장된 변경을 돌려준다.
  Future<Change?> delete(RideId id) async {
    final ride = await _records.ride(id);
    if (ride == null) return null;
    return _records.apply(Change(before: [ride], after: [ride.withDeletedAt(_now())]));
  }

  /// 여러 기록을 한 변경으로 지운다. 되돌리기 한 번으로 모두 돌아온다 (DESIGN §8.2).
  Future<Change?> deleteAll(Iterable<RideId> ids) async {
    final rides = [
      for (final id in ids) ?await _records.ride(id),
    ];
    if (rides.isEmpty) return null;
    final at = _now();
    return _records.apply(Change(before: rides, after: [for (final ride in rides) ride.withDeletedAt(at)]));
  }

  /// 역 방문을 남긴다. 완주율과 거리에는 들지 않고 지도의 점만 칠한다 (DESIGN §5.2).
  Future<Change> addVisit({
    required String node,
    required String label,
    required String deviceId,
    required String id,
  }) {
    final now = _now();
    return _records.apply(
      Change(
        before: const [],
        after: [
          Visit(
            visitId: VisitId(id),
            nodeId: NodeId(node),
            nodeLabel: label,
            nodeExplicit: true,
            createdAt: now,
            updatedAt: now,
            deviceId: deviceId,
          ),
        ],
      ),
    );
  }

  /// 역 방문을 지운다.
  Future<Change?> deleteVisit(VisitId id) async {
    final visit = await _records.visit(id);
    if (visit == null) return null;
    return _records.apply(Change(before: [visit], after: [visit.withDeletedAt(_now())]));
  }

  /// 한 역의 방문을 모두 지운다.
  Future<Change?> deleteVisits(Iterable<VisitId> ids) async {
    final visits = [
      for (final id in ids) ?await _records.visit(id),
    ];
    if (visits.isEmpty) return null;
    final at = _now();
    return _records.apply(Change(before: visits, after: [for (final visit in visits) visit.withDeletedAt(at)]));
  }

  /// 방문일을 고친다.
  Future<Change?> setVisitDate(VisitId id, String? date) async {
    final visit = await _records.visit(id);
    if (visit == null) return null;
    return _records.apply(Change(before: [visit], after: [visit.dated(date)]));
  }

  /// 고친 기록을 저장한다. 재해석은 저장과 같은 함수다.
  Future<Change> save(Ride before, Ride after) =>
      _records.apply(Change(before: [before], after: [after]));

  /// 되돌리기는 새 변경이다. 그 사이 나간 백업을 이긴다.
  Future<void> undo(Change change) => _records.apply(change.undo(now: _now()));
}
