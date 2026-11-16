import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/session_providers.dart';

/// 삭제 표시된 기록과 역 방문. 최근에 지운 것이 위다.
final deletedRecordsProvider = FutureProvider.autoDispose<List<UserRecord>>((ref) async {
  ref.watch(lastChangeProvider);
  final records = ref.watch(sessionProvider).records;
  final all = <UserRecord>[...await records.deletedRides(), ...await records.deletedVisits()];
  return all..sort((a, b) => (b.deletedAt ?? 0).compareTo(a.deletedAt ?? 0));
});

/// 가져온 파일별 기록. 키는 `출처:파일 이름`이고 파일 이름을 적기 전 기록은 출처뿐이다.
/// 파일 전체를 한 번에 지운다 (DESIGN §8.2).
final importedFilesProvider = FutureProvider.autoDispose<Map<String, List<Ride>>>((ref) async {
  ref.watch(lastChangeProvider);
  final rides = await ref.watch(sessionProvider).records.allRides();
  final files = <String, List<Ride>>{};
  for (final ride in rides) {
    final source = ride.importSource;
    if (source != null && !ride.isDeleted) (files[source] ??= []).add(ride);
  }
  return files;
});

final deletedCommandsProvider = Provider<DeletedCommands>((ref) => DeletedCommands(ref));

final class DeletedCommands {
  const DeletedCommands(this._ref);

  final Ref _ref;

  /// 여정째 지운 기록이면 여정도 함께 되살린다. 여정 없이 살아나면 묶음이 사라진다.
  Future<Change> restore(UserRecord record) async {
    final records = _ref.read(sessionProvider).records;
    final tripId = record is Ride ? record.tripId : null;
    final trip = tripId == null ? null : await records.trip(tripId);
    final before = [record, if (trip != null && trip.isDeleted) trip];
    return records.apply(Change(before: before, after: [for (final r in before) r.withDeletedAt(null)]));
  }

  Future<Change> deleteAll(List<Ride> rides) {
    final at = _ref.read(nowProvider)();
    return _ref.read(sessionProvider).records.apply(
          Change(before: rides, after: [for (final ride in rides) ride.withDeletedAt(at)]),
        );
  }

  Future<void> undo(Change change) =>
      _ref.read(sessionProvider).records.apply(change.undo(now: _ref.read(nowProvider)()));
}
