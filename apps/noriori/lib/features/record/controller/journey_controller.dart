import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/session_providers.dart';

/// 고른 두 역의 경로. 날짜가 바뀌면 다시 찾는다.
final journeyProvider = Provider.autoDispose
    .family<Journey?, ({String from, String to, String? date})>((ref, pick) => findJourney(
          ref.watch(networkProvider),
          pick.from,
          pick.to,
          date: pick.date == null ? null : DateSpan.parse(pick.date!),
          today: ref.watch(todayProvider),
        ));

final journeyCommandsProvider = Provider<JourneyCommands>(JourneyCommands.new);

/// 노선마다 한 건씩 저장하고 여정 하나로 묶는다 (DESIGN §6.1).
final class JourneyCommands {
  const JourneyCommands(this._ref);

  final Ref _ref;

  Future<Change> save(Journey journey, {required String title, required String? date}) async {
    final session = _ref.read(sessionProvider);
    final network = _ref.read(networkProvider);
    final book = _ref.read(nameBookProvider);
    final names = await _ref.read(packReaderProvider).nodeNames({
      for (final leg in journey.legs) ...[leg.from, leg.to],
    });
    final device = await _ref.read(deviceIdProvider.future);
    final now = _ref.read(nowProvider)();
    final resolver = RouteResolver(network);
    final day = date == null ? null : DateSpan.parse(date);
    String id() => uuidV7(millis: now, randomBytes: secureRandomBytes());
    final trip = Trip(tripId: TripId(id()), title: title, createdAt: now, updatedAt: now, deviceId: device);
    return session.records.apply(
      Change(
        before: const [],
        after: [
          trip,
          for (final leg in journey.legs)
            Ride(
              rideId: RideId(id()),
              datasetVersion: session.pack.edition,
              createdAt: now,
              updatedAt: now,
              deviceId: device,
              dateInput: date,
              tripId: trip.tripId,
              legs: [
                RideLeg(
                  seq: 0,
                  lineId: LineId(leg.lineId),
                  routeId: RouteId(leg.routeId),
                  fromNode: NodeId(leg.from),
                  toNode: NodeId(leg.to),
                  direction: network.routes[leg.routeId]!.closed
                      ? resolver.record(leg.routeId, leg.from, leg.to, date: day).direction
                      : null,
                  lineLabel: book.lines[leg.lineId] ?? leg.lineId,
                  fromLabel: names[leg.from] ?? leg.from,
                  toLabel: names[leg.to] ?? leg.to,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> undo(Change change) =>
      _ref.read(sessionProvider).records.apply(change.undo(now: _ref.read(nowProvider)()));
}
