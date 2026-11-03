import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/session_providers.dart';

/// 남은 구간 화면이 보는 값.
final class RemainingData {
  const RemainingData({required this.groups, required this.names, required this.positions, required this.all});

  /// 탄 적 있는 노선의 남은 구간. 회사별로 묶었고 조금 남은 노선이 먼저다.
  final List<(String, List<RemainingSection>)> groups;

  /// 현재 노선 전체의 남은 구간. `가까운 곳`이 쓴다.
  final List<RemainingSection> all;
  final Map<String, String> names;
  final Map<String, (double, double)> positions;

  /// 회사를 가리지 않고 조금 남은 노선부터.
  List<RemainingSection> get byShortest {
    final total = <String, int>{};
    final sections = groups.expand((group) => group.$2).toList();
    for (final section in sections) {
      total[section.lineId] = (total[section.lineId] ?? 0) + section.meters;
    }
    return sections
      ..sort((a, b) {
        final line = total[a.lineId]!.compareTo(total[b.lineId]!);
        return line != 0 ? line : a.lineId.compareTo(b.lineId);
      });
  }
}

final remainingProvider = FutureProvider.autoDispose<RemainingData>((ref) async {
  final network = ref.watch(networkProvider);
  final today = ref.watch(todayProvider);
  final carryover = ref.watch(carryoverProvider);
  final hits = await ref.watch(unitHitsProvider.future);
  final tree = browseTree(network, era: BrowseEra.current, hits: hits, today: today, carryover: carryover);
  final byLine = <String, List<RemainingSection>>{};
  for (final line in tree.lines) {
    if (line.score.complete) continue;
    final diagram = lineDiagram(network, line.lineId, hits: hits, today: today, carryover: carryover);
    byLine[line.lineId] = remainingSections(diagram);
  }
  final groups = <(String, List<RemainingSection>)>[];
  for (final category in tree.categories) {
    for (final operator in category.operators) {
      final open = [
        for (final line in operator.lines)
          if (line.score.started && !line.score.complete) line,
      ]..sort((a, b) => a.score.remainingMeters.compareTo(b.score.remainingMeters));
      if (open.isEmpty) continue;
      groups.add((operator.operatorId, [for (final line in open) ...?byLine[line.lineId]]));
    }
  }
  final all = byLine.values.expand((sections) => sections).toList();
  final ends = {for (final section in all) ...[section.from, section.to]};
  final reader = ref.watch(packReaderProvider);
  return RemainingData(
    groups: groups,
    all: all,
    names: await reader.nodeNames(ends),
    positions: await reader.nodePositions({for (final section in all) ...section.nodes}),
  );
});
