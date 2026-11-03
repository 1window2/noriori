import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/session_providers.dart';

/// 검색 결과 한 줄. 역을 찾으면 그 역을 지나는 노선마다 한 줄이다.
final class SearchRow {
  const SearchRow({
    required this.title,
    required this.subtitle,
    required this.lineId,
    this.routeId,
    this.fromNode,
    this.serviceId,
  });

  final String title;
  final String subtitle;
  final String lineId;
  final String? routeId;
  final String? fromNode;

  /// 운전 계통이면 한 줄 노선도로 간다.
  final String? serviceId;
}

final lineSearchProvider = FutureProvider.autoDispose.family<List<SearchRow>, String>((ref, text) async {
  final reader = ref.watch(packReaderProvider);
  final network = ref.watch(networkProvider);
  final book = ref.watch(nameBookProvider);
  final hits = await reader.search(text);
  final stationIds = [
    for (final hit in hits)
      if (hit.kind == 'node') hit.id,
  ];
  final stations = await reader.nodeNames(stationIds);
  final services = await reader.serviceNames([
    for (final hit in hits)
      if (hit.kind == 'service') hit.id,
  ]);
  NetService? service(String id) {
    for (final item in network.data.services) {
      if (item.id == id) return item;
    }
    return null;
  }

  final ends = await reader.nodeNames([
    for (final hit in hits)
      if (hit.kind == 'service')
        if (service(hit.id) case final item? when item.parts.isNotEmpty) ...[
          item.parts.first.from,
          item.parts.last.to,
        ],
  ]);
  final rows = <SearchRow>[];
  for (final hit in hits) {
    switch (hit.kind) {
      case 'line':
        final attrs = network.data.attrs.where((a) => a.lineId == hit.id);
        final operatorId = attrs.isEmpty ? null : attrs.last.operatorId;
        rows.add(SearchRow(
          title: book.lines[hit.id] ?? hit.id,
          subtitle: book.operators[operatorId] ?? '',
          lineId: hit.id,
        ));
      case 'service':
        rows.add(SearchRow(
          title: services[hit.id] ?? hit.id,
          subtitle: switch (service(hit.id)) {
            // 고리는 처음과 끝이 같아 구간을 적지 않는다
            final item? when item.parts.isNotEmpty && !item.closed =>
              '${ends[item.parts.first.from]}–${ends[item.parts.last.to]}',
            _ => '',
          },
          lineId: '',
          serviceId: hit.id,
        ));
      case 'node':
        final seen = <String>{};
        for (final routeId in network.routesAt(hit.id)) {
          final route = network.routes[routeId]!;
          if (!seen.add(route.lineId)) continue;
          rows.add(SearchRow(
            title: stations[hit.id] ?? hit.id,
            subtitle: book.lines[route.lineId] ?? route.lineId,
            lineId: route.lineId,
            routeId: routeId,
            fromNode: hit.id,
          ));
        }
    }
  }
  return rows;
});
