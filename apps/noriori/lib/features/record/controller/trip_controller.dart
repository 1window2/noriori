import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noriori_core/noriori_core.dart';
import 'package:noriori_store/noriori_store.dart';

import '../../../app/session_providers.dart';

export 'package:noriori_store/noriori_store.dart' show TripSummary;

/// 여정 목록. 기록이 하나도 없는 여정은 보이지 않는다.
final tripListProvider = StreamProvider<List<TripSummary>>(
  (ref) => ref.watch(recordQueriesProvider).watchTrips(),
);

final tripCommandsProvider = Provider<TripCommands>(TripCommands.new);

/// 여정은 기록을 묶을 뿐이다. 풀어도 기록은 남는다 (DESIGN §6.1).
final class TripCommands {
  const TripCommands(this._ref);

  final Ref _ref;

  RecordStore get _records => _ref.read(sessionProvider).records;

  int get _now => _ref.read(nowProvider)();

  Future<List<Ride>> _rides(Iterable<RideId> ids) async => [
        for (final id in ids) ?await _records.ride(id),
      ];

  /// 고른 기록을 새 여정으로 묶는다. 다른 여정에 있던 기록은 옮겨 온다.
  Future<Change> make(String title, Iterable<RideId> ids) async {
    final now = _now;
    final trip = Trip(
      tripId: TripId(uuidV7(millis: now, randomBytes: secureRandomBytes())),
      title: title,
      createdAt: now,
      updatedAt: now,
      deviceId: await _ref.read(deviceIdProvider.future),
    );
    final rides = await _rides(ids);
    return _records.apply(
      Change(
        before: rides,
        after: [trip, for (final ride in rides) ride.inTrip(trip.tripId)],
      ),
    );
  }

  Future<Change?> rename(TripId id, String title) async {
    final trip = await _records.trip(id);
    if (trip == null) return null;
    return _records.apply(Change(before: [trip], after: [trip.named(title)]));
  }

  /// 묶음만 없앤다.
  Future<Change?> dissolve(TripId id) async {
    final trip = await _records.trip(id);
    if (trip == null) return null;
    final rides = await _rides(await _ref.read(recordQueriesProvider).ridesInTrip(id));
    return _records.apply(
      Change(
        before: [trip, ...rides],
        after: [
          trip.withDeletedAt(_now),
          for (final ride in rides) ride.inTrip(null),
        ],
      ),
    );
  }

  /// 여정과 묶인 기록을 함께 지운다. 되돌릴 수 있다.
  Future<Change?> deleteWithRides(TripId id) async {
    final trip = await _records.trip(id);
    if (trip == null) return null;
    final rides = await _rides(await _ref.read(recordQueriesProvider).ridesInTrip(id));
    final at = _now;
    return _records.apply(
      Change(
        before: [trip, ...rides],
        after: [
          trip.withDeletedAt(at),
          for (final ride in rides) ride.withDeletedAt(at),
        ],
      ),
    );
  }

  Future<void> undo(Change change) => _records.apply(change.undo(now: _now));
}
