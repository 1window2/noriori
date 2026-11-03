import '../ids.dart';
import '../records/derived.dart';
import '../records/record.dart';
import 'network.dart';
import 'ride_interpreter.dart';
import 'route_resolver.dart';

/// 구간 끄기를 하지 않은 이유.
enum CutBlock {
  /// 표시 역이 아닌 곳에서 끊어야 한다. 안내만 한다 (DESIGN §8.2).
  hiddenNode,

  /// 조각을 다시 펼치면 경로나 날짜가 달라진다. 기록을 건드리지 않는다.
  changesPath,
}

sealed class CutOutcome {
  const CutOutcome();
}

/// 이 기록은 그 구간을 지나지 않는다.
final class CutMissed extends CutOutcome {
  const CutMissed();
}

final class CutBlocked extends CutOutcome {
  const CutBlocked(this.reason);

  final CutBlock reason;
}

/// [before]를 [after]로 바꾸면 끝난다. 남는 조각이 없으면 원래 기록의 삭제 표시 하나다.
final class CutDone extends CutOutcome {
  const CutDone(this.before, this.after);

  final Ride before;
  final List<Ride> after;
}

typedef _Hop = ({int leg, String route, String from, String to, String edge, bool off});

/// 기록에서 [offUnits]에 든 구간을 잘라 낸다 (ARCHITECTURE §3.4 `cutSection`).
///
/// 남는 조각의 맨 앞이 원래 ID를 갖고, 끈 구간은 삭제 표시 조각으로 남는다.
CutOutcome cutSection(
  Ride ride,
  Network network, {
  required Set<int> offUnits,
  required bool carryover,
  required String Function(String node) nameOf,
  required String Function() newId,
  required int now,
}) {
  final interpreter = RideInterpreter(network);
  final expansions = interpreter.expansions(ride);
  final hops = <_Hop>[];
  for (final (index, expansion) in expansions.indexed) {
    if (!expansion.saved) return const CutMissed();
    // 일부만 아는 이설 구간은 노드와 구간이 짝이 맞지 않아 자를 수 없다
    if (expansion.nodes.length != expansion.edges.length + 1) {
      return const CutBlocked(CutBlock.changesPath);
    }
    final owner = {
      for (final leg in expansion.legs)
        for (final edge in leg.edges) edge: leg,
    };
    for (final (at, edge) in expansion.edges.indexed) {
      final leg = owner[edge]!;
      final unit = network.unitOf(leg.lineId, edge, carryover: carryover);
      hops.add((
        leg: index,
        route: leg.routeId,
        from: expansion.nodes[at],
        to: expansion.nodes[at + 1],
        edge: edge,
        off: unit != null && offUnits.contains(unit.n),
      ));
    }
  }
  if (!hops.any((h) => h.off)) return const CutMissed();
  if (hops.every((h) => h.off)) {
    return CutDone(ride, [ride.withMeta(updatedAt: now, deletedAt: now)]);
  }
  final runs = <List<_Hop>>[];
  for (final hop in hops) {
    if (runs.isEmpty || runs.last.first.off != hop.off) runs.add([]);
    runs.last.add(hop);
  }
  for (final run in runs.skip(1)) {
    if (!network.isShown(run.first.from)) return const CutBlocked(CutBlock.hiddenNode);
  }
  final before = interpreter.ride(ride);
  var keptFirst = false;
  final after = <Ride>[];
  for (final (at, run) in runs.indexed) {
    final off = run.first.off;
    final nodes = {for (final hop in run) ...[hop.from, hop.to]};
    final piece = ride.piece(
      id: off || keptFirst ? RideId(newId()) : ride.rideId,
      legs: _legsOf(network, run, hops, ride, expansions, nameOf),
      transferNodes: [
        for (final node in ride.transferNodes)
          if (nodes.contains(node.value)) node,
      ],
      fromAlighted: at == 0 && ride.fromAlighted,
      toAlighted: at == runs.length - 1 && ride.toAlighted,
      updatedAt: now,
      deletedAt: off ? now : null,
    );
    keptFirst = keptFirst || !off;
    final derived = interpreter.ride(piece);
    final same = derived.status == ResolveStatus.ok &&
        _sameEdges(network, derived, run) &&
        (before.date == null || derived.date == before.date);
    if (!same) return const CutBlocked(CutBlock.changesPath);
    after.add(piece);
  }
  return CutDone(ride, after);
}

bool _sameEdges(Network network, RideDerived derived, List<_Hop> run) {
  final got = [for (final hit in derived.edges) hit.edge]..sort();
  final want = [for (final hop in run) network.edges[hop.edge]!.n]..sort();
  if (got.length != want.length) return false;
  for (var i = 0; i < got.length; i++) {
    if (got[i] != want[i]) return false;
  }
  return true;
}

/// 조각의 legs. 원래 구간을 통째로 지나면 그대로 두고, 잘린 구간은 새 끝을 준다.
List<RideLeg> _legsOf(
  Network network,
  List<_Hop> run,
  List<_Hop> all,
  Ride ride,
  List<Expansion> expansions,
  String Function(String node) nameOf,
) {
  final groups = <List<_Hop>>[];
  for (final hop in run) {
    if (groups.isEmpty || groups.last.first.leg != hop.leg || groups.last.first.route != hop.route) {
      groups.add([]);
    }
    groups.last.add(hop);
  }
  final legs = <RideLeg>[];
  for (final group in groups) {
    final index = group.first.leg;
    final leg = ride.legs[index];
    final whole = all.where((h) => h.leg == index).toList();
    final atStart = group.first == whole.first;
    final atEnd = group.last == whole.last;
    final from = atStart ? leg.fromNode.value : group.first.from;
    final to = atEnd ? leg.toNode.value : group.last.to;
    final sameRoute = group.first.route == leg.routeId.value;
    legs.add(
      RideLeg(
        seq: legs.length,
        lineId: sameRoute ? leg.lineId : LineId(network.routes[group.first.route]!.lineId),
        routeId: RouteId(group.first.route),
        fromNode: NodeId(from),
        toNode: NodeId(to),
        direction: atStart && atEnd ? leg.direction : leg.direction ?? expansions[index].direction,
        resolveAsOf: leg.resolveAsOf,
        resolveUnknown: leg.resolveUnknown,
        lineLabel: leg.lineLabel,
        fromLabel: atStart ? leg.fromLabel : nameOf(from),
        toLabel: atEnd ? leg.toLabel : nameOf(to),
      ),
    );
  }
  return legs;
}
