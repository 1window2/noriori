import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noriori_core/noriori_core.dart';
import 'package:noriori_store/noriori_store.dart';

import '../../../app/session_providers.dart';

const _seenKey = 'news_seen';
const _reportKey = 'news_report_seen';

/// 변경 소식 한 번치. 이름은 화면에 바로 쓴다.
final class NewsData {
  const NewsData({required this.items, required this.names, this.changes = const []});

  final List<NewsItem> items;
  final Map<String, String> names;

  /// 데이터 정정으로 달라진 기록.
  final List<RideChange> changes;

  bool get isEmpty => items.isEmpty && changes.isEmpty;
}

/// 역 이름은 그 사건 날의 이름이다. 폐역은 마지막 날 이름, 개업은 그날 이름이다.
/// 지금 이름을 쓰면 신호장으로 격하된 역이 「산기아사케 신호장역 폐역」으로 나왔다 (2026-11-21)
Future<NewsData> _named(Ref ref, List<NewsItem> items, List<RideChange> changes) async {
  final reader = ref.watch(packReaderProvider);
  final names = <String, String>{};
  for (final item in items) {
    final node = item.node;
    if (node == null || names.containsKey(node)) continue;
    final day = item.kind == NewsKind.stationClosed ? _dayBefore(item.date) : item.date;
    final got = await reader.nodeNames([node], lineId: item.lineId, date: day);
    names[node] = got[node] ?? (await reader.nodeNames([node]))[node] ?? node;
  }
  return NewsData(items: items, changes: changes, names: names);
}

String _dayBefore(String date) {
  final parsed = DateTime.tryParse(date);
  if (parsed == null) return date;
  final d = parsed.subtract(const Duration(days: 1));
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// 지금까지의 소식 전체. 설정의 변경 내역이 쓴다. 최근 200건만 보인다.
final newsHistoryProvider = FutureProvider.autoDispose<NewsData>((ref) async {
  final items = networkNews(ref.watch(networkProvider), ref.watch(todayProvider));
  final reports = await ref.watch(recordQueriesProvider).watchChangeReports().first;
  return _named(ref, items.take(200).toList(), [for (final report in reports) ...report.changes]);
});

/// 아직 안 본 소식. 처음 켠 사람에게는 과거 전체가 소식이 아니므로 기준만 남긴다.
final unseenNewsProvider = FutureProvider<NewsData>((ref) async {
  final items = networkNews(ref.watch(networkProvider), ref.watch(todayProvider));
  final store = SettingStore(ref.watch(sessionProvider).db);
  final reports = await ref.watch(recordQueriesProvider).watchChangeReports().first;
  final after = int.tryParse(await store.read(_reportKey) ?? '') ?? 0;
  final changes = [
    for (final report in reports)
      if (report.createdAt > after) ...report.changes,
  ];
  final raw = await store.read(_seenKey);
  if (raw == null) {
    await store.write(_seenKey, _encode(items));
    return NewsData(items: const [], names: const {}, changes: changes);
  }
  final seen = {
    for (final hash in raw.split(','))
      if (hash.isNotEmpty) int.parse(hash, radix: 16),
  };
  return _named(ref, [
    for (final item in items)
      if (!seen.contains(newsHash(item.key))) item,
  ], changes);
});

String _encode(Iterable<NewsItem> items) =>
    [for (final item in items) newsHash(item.key).toRadixString(16)].join(',');

/// 소식을 본 것으로 남긴다. 다음부터 다시 띄우지 않는다.
Future<void> markNewsSeen(WidgetRef ref) async {
  final items = networkNews(ref.read(networkProvider), ref.read(todayProvider));
  final store = SettingStore(ref.read(sessionProvider).db);
  await store.write(_seenKey, _encode(items));
  await store.write(_reportKey, '${ref.read(nowProvider)()}');
}
