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

Future<NewsData> _named(Ref ref, List<NewsItem> items, List<RideChange> changes) async => NewsData(
      items: items,
      changes: changes,
      names: await ref.watch(packReaderProvider).nodeNames([
        for (final item in items) ?item.node,
      ]),
    );

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
