import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/session_providers.dart';

/// 노선 한 줄. 위치 띠와 양 끝 역 이름까지 든다.
final class LineRow {
  const LineRow({required this.line, required this.strip, this.startName, this.endName});

  final BrowseLine line;
  final LineStrip strip;
  final String? startName;
  final String? endName;
}

Future<List<LineRow>> _rows(Ref ref, Iterable<BrowseLine> lines) async {
  final network = ref.watch(networkProvider);
  final strips = [for (final line in lines) (line, lineStrip(network, line))];
  final names = await ref.watch(packReaderProvider).nodeNames({
    for (final (_, strip) in strips) ...[?strip.startNode, ?strip.endNode],
  });
  return [
    for (final (line, strip) in strips)
      LineRow(
        line: line,
        strip: strip,
        startName: names[strip.startNode],
        endName: names[strip.endNode],
      ),
  ];
}

typedef LineListKey = ({BrowseEra era, String category, String operatorId});

/// 한 회사의 노선들.
final lineRowsProvider = FutureProvider.family<List<LineRow>, LineListKey>((ref, key) async {
  final tree = ref.watch(browseTreeProvider(key.era)).value;
  if (tree == null) return const [];
  final operators = tree.category(key.category)?.operators ?? const <BrowseOperator>[];
  return _rows(ref, [
    for (final operator in operators)
      if (operator.operatorId == key.operatorId) ...operator.lines,
  ]);
});

/// 최근에 탄 노선 중 아직 다 타지 않은 것.
final continueRowsProvider = FutureProvider<List<LineRow>>((ref) async {
  final tree = ref.watch(browseTreeProvider(BrowseEra.current)).value;
  final recent = ref.watch(recentLinesProvider).value;
  if (tree == null || recent == null) return const [];
  final byLine = <String, BrowseLine>{};
  for (final line in tree.lines) {
    if (line.score.started && !line.score.complete) byLine.putIfAbsent(line.lineId, () => line);
  }
  return _rows(ref, [
    for (final id in recent)
      if (byLine[id] != null) byLine[id]!,
  ]);
});

/// 기록 탭에서 지금 보는 것. 탭을 옮겨도 유지한다.
enum RecordView { lines, rides, trips, visits }

final recordViewProvider = NotifierProvider<_Choice<RecordView>, RecordView>(
  () => _Choice(RecordView.lines),
);

final browseEraProvider = NotifierProvider<_Choice<BrowseEra>, BrowseEra>(
  () => _Choice(BrowseEra.current),
);

final class _Choice<T> extends Notifier<T> {
  _Choice(this._first);

  final T _first;

  @override
  T build() => _first;

  void set(T value) => state = value;
}
