import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/session_providers.dart';

/// 노선 상세의 세로 노선도. 탄 단위가 바뀌면 다시 그린다.
final lineDiagramProvider = Provider.autoDispose.family<AsyncValue<LineDiagram>, String>(
  (ref, lineId) => ref.watch(unitHitsProvider).whenData(
        (hits) => lineDiagram(
          ref.watch(networkProvider),
          lineId,
          hits: hits,
          today: ref.watch(todayProvider),
          carryover: ref.watch(carryoverProvider),
        ),
      ),
);

/// 노선도의 역 이름.
final lineStopNamesProvider = FutureProvider.autoDispose.family<Map<String, String>, String>((ref, lineId) {
  final network = ref.watch(networkProvider);
  final nodes = {
    for (final routeId in network.routesOfLine(lineId))
      for (final stop in network.stops(routeId)) stop.node,
  };
  return ref.watch(packReaderProvider).nodeNames(nodes, lineId: lineId);
});

/// 구간 전환의 결과. 화면은 이 값으로 안내만 고른다.
sealed class SectionEdit {
  const SectionEdit();
}

final class SectionOff extends SectionEdit {
  const SectionOff(this.change, this.rides);

  final Change change;

  /// 영향 건수 (DESIGN §8.2).
  final int rides;
}

final class SectionOn extends SectionEdit {
  const SectionOn(this.change, {required this.restored});

  final Change change;
  final bool restored;
}

final class SectionRefused extends SectionEdit {
  const SectionRefused(this.reason);

  /// null이면 켤 수 없는 구간이다.
  final CutBlock? reason;
}

final class SectionUntouched extends SectionEdit {
  const SectionUntouched();
}

final sectionCommandsProvider = Provider<SectionCommands>((ref) => SectionCommands(ref));

/// 노선 상세에서 그 자리에서 고치는 명령 (DESIGN §8.2).
final class SectionCommands {
  const SectionCommands(this._ref);

  final Ref _ref;

  String _id() => uuidV7(millis: _ref.read(nowProvider)(), randomBytes: secureRandomBytes());

  /// 덮는 기록을 전부 자른다. 하나라도 막히면 아무것도 고치지 않는다.
  Future<SectionEdit> turnOff(String lineId, Iterable<DiagramSection> sections) async {
    final session = _ref.read(sessionProvider);
    final network = _ref.read(networkProvider);
    final units = {
      for (final section in sections) ...section.units,
    };
    final ids = await _ref.read(recordQueriesProvider).ridesCovering(units, carryover: _ref.read(carryoverProvider));
    if (ids.isEmpty) return const SectionUntouched();
    final rides = [
      for (final id in ids) ?await session.records.ride(id),
    ];
    final interpreter = RideInterpreter(network);
    final nodes = {
      for (final ride in rides)
        for (final expansion in interpreter.expansions(ride)) ...expansion.nodes,
    };
    final names = await _ref.read(packReaderProvider).nodeNames(nodes, lineId: lineId);
    final now = _ref.read(nowProvider)();
    final before = <UserRecord>[];
    final after = <UserRecord>[];
    for (final ride in rides) {
      final outcome = cutSection(
        ride,
        network,
        offUnits: units,
        carryover: _ref.read(carryoverProvider),
        nameOf: (node) => names[node] ?? node,
        newId: _id,
        now: now,
      );
      switch (outcome) {
        case CutMissed():
          break;
        case CutBlocked(:final reason):
          return SectionRefused(reason);
        case CutDone(before: final old, after: final pieces):
          before.add(old);
          after.addAll(pieces);
      }
    }
    if (before.isEmpty) return const SectionUntouched();
    final change = await session.records.apply(Change(before: before, after: after));
    return SectionOff(change, before.length);
  }

  /// 안 탄 구간을 켠다. 이어진 구간마다 삭제 조각을 되살리거나 날짜 없는 기록을 만든다.
  Future<SectionEdit> turnOn(String lineId, Iterable<DiagramSection> sections) async {
    final session = _ref.read(sessionProvider);
    final network = _ref.read(networkProvider);
    final deleted = await session.records.deletedRides();
    final joined = joinSections(sections);
    final names = await _ref.read(packReaderProvider).nodeNames(
      {for (final section in joined) ...[section.from, section.to]},
      lineId: lineId,
    );
    final deviceId = await _ref.read(deviceIdProvider.future);
    final book = _ref.read(nameBookProvider);
    final now = _ref.read(nowProvider)();
    final before = <UserRecord>[];
    final after = <UserRecord>[];
    for (final section in joined) {
      final found = restorableRide(
        deleted,
        section.units,
        network: network,
        carryover: _ref.read(carryoverProvider),
      );
      if (found != null) {
        before.add(found);
        after.add(found.withDeletedAt(null));
        continue;
      }
      final made = sectionRide(
        network,
        section,
        id: RideId(_id()),
        lineLabel: book.lines[lineId] ?? lineId,
        fromLabel: names[section.from] ?? section.from,
        toLabel: names[section.to] ?? section.to,
        datasetVersion: session.pack.edition,
        deviceId: deviceId,
        now: now,
      );
      if (made == null) return const SectionRefused(null);
      after.add(made);
    }
    final change = await session.records.apply(Change(before: before, after: after));
    return SectionOn(change, restored: before.length == after.length);
  }
}
