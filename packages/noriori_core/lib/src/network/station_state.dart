import 'network.dart';

/// 지도 점의 상태 (DESIGN §5.3). 값은 역 묶음의 정수 키다.
final class StationMarks {
  const StationMarks({this.stepped = const {}, this.passed = const {}});

  /// 승하차했거나 방문한 역. 꽉 찬 원이다.
  final Set<int> stepped;

  /// 지나가기만 한 역. 뚫린 원이다.
  final Set<int> passed;

  StationMark of(Network network, String node) {
    final data = network.data;
    final group = data.groupNumbers[data.nodeGroups[node]];
    if (stepped.contains(group)) return StationMark.stepped;
    return passed.contains(group) ? StationMark.passed : StationMark.none;
  }
}

/// 역 원 하나의 상태.
enum StationMark { stepped, passed, none }

/// 같은 역 묶음에서 한 곳이라도 밟았으면 그 묶음은 밟은 역이다.
StationMarks stationMarks(
  Network network, {
  required Iterable<String> alighted,
  required Iterable<String> visited,
  required Iterable<String> ridden,
}) {
  final data = network.data;
  int? group(String node) => data.groupNumbers[data.nodeGroups[node]];
  final stepped = {
    for (final node in alighted) ?group(node),
    for (final node in visited) ?group(node),
  };
  return StationMarks(
    stepped: stepped,
    passed: {for (final node in ridden) ?group(node)}.difference(stepped),
  );
}
