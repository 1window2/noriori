import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/session_providers.dart';

/// 삭제 표시된 기록. 최근에 지운 것이 위다.
final deletedRidesProvider = FutureProvider.autoDispose<List<Ride>>((ref) async {
  ref.watch(lastChangeProvider);
  final rides = await ref.watch(sessionProvider).records.deletedRides();
  return rides..sort((a, b) => (b.deletedAt ?? 0).compareTo(a.deletedAt ?? 0));
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

  Future<Change> restore(Ride ride) => _ref.read(sessionProvider).records.apply(
        Change(before: [ride], after: [ride.withDeletedAt(null)]),
      );

  Future<Change> deleteAll(List<Ride> rides) {
    final at = _ref.read(nowProvider)();
    return _ref.read(sessionProvider).records.apply(
          Change(before: rides, after: [for (final ride in rides) ride.withDeletedAt(at)]),
        );
  }

  Future<void> undo(Change change) =>
      _ref.read(sessionProvider).records.apply(change.undo(now: _ref.read(nowProvider)()));
}
