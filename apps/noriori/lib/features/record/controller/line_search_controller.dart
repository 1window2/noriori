import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/session_providers.dart';
import '../../../i18n/strings.g.dart';

/// 검색 결과 한 줄. 역을 찾으면 그 역을 지나는 노선마다 한 줄이다.
final class SearchRow {
  const SearchRow({
    required this.title,
    required this.subtitle,
    required this.lineId,
    this.routeId,
    this.fromNode,
    this.focusNode,
    this.serviceId,
  });

  final String title;
  final String subtitle;
  final String lineId;
  final String? routeId;
  final String? fromNode;

  /// 열람 전용이면 고르지 않고 그 자리(앞 역)로만 옮겨 간다.
  final String? focusNode;

  /// 운행 계통이면 한 줄 노선도로 간다.
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
  final archiveIds = [
    for (final hit in hits)
      if (hit.kind == 'archive') hit.id,
  ];
  final archiveNames = await reader.archiveNames(archiveIds);
  final places = await reader.archivePlaces(archiveIds);
  final lineNames = book.lines.values.toSet();
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
        final name = services[hit.id] ?? hit.id;
        // 고리는 처음과 끝이 같아 구간을 적지 않는다
        final span = switch (service(hit.id)) {
          final item? when item.parts.isNotEmpty && !item.closed =>
            (ends[item.parts.first.from], ends[item.parts.last.to]),
          _ => null,
        };
        // 이름이 공식 노선과 같은 운행 계통(高崎線, 常磐線 등)은 범위를 붙여 노선과 구분한다
        final twin = span != null && lineNames.contains(name);
        rows.add(SearchRow(
          title: twin ? _withSpan(name, span.$1, span.$2) : name,
          subtitle: span == null || twin ? '' : '${span.$1}–${span.$2}',
          lineId: '',
          serviceId: hit.id,
        ));
      // 열람 전용 역은 그 계통, 열람 전용 노선은 갈라지는 역을 지나는 노선마다 한 줄이다 (사용자 결정 2026-11-08)
      case 'archive':
        final place = places[hit.id];
        final node = place?.node;
        final routeIds = [
          if (place?.routeId case final route? when network.routes.containsKey(route)) route
          else if (node != null) ...network.routesAt(node),
        ];
        final seen = <String>{};
        for (final routeId in routeIds) {
          final route = network.routes[routeId]!;
          if (!seen.add(route.lineId)) continue;
          rows.add(SearchRow(
            title: archiveNames[hit.id] ?? hit.id,
            subtitle: '${book.lines[route.lineId] ?? route.lineId} · ${t.search.archive}',
            lineId: route.lineId,
            routeId: routeId,
            focusNode: node,
          ));
        }
      case 'node':
        final seen = <String>{};
        for (final routeId in network.routesAt(hit.id)) {
          // 그 역에 서지 않고 지나기만 하는 계통은 그 역의 노선이 아니다 (筑豊電鉄 계통의 黒崎車庫前: 北九州線 시절 1999 폐지, 7회차 2026-11-14)
          if (!network.stops(routeId).any((stop) => stop.node == hit.id && stop.isStop)) continue;
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

/// 운행 계통 이름에 범위를 붙인다. 일본어 이름은 「高崎線（東京～高崎）」, 그 밖은 `Takasaki Line (Tokyo~Takasaki)`이다.
String _withSpan(String name, String? from, String? to) {
  final cjk = RegExp(r'[\u3040-\u30ff\u4e00-\u9fff]').hasMatch(name);
  return cjk ? '$name（$from～$to）' : '$name ($from~$to)';
}
