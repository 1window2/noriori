import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/date_text.dart';
import '../../../app/session_providers.dart';
import '../../../app/widgets/load_error.dart';
import '../../../i18n/strings.g.dart';
import '../controller/news_controller.dart';

String _describe(BuildContext context, WidgetRef ref, NewsItem item, NewsData data) {
  final t = context.t.news;
  final line = ref.read(nameBookProvider).lines[item.lineId] ?? item.lineId;
  final station = data.names[item.node] ?? item.node ?? '';
  final km = kmLabel(item.meters);
  // 다 탔던 노선이 연장되면 남은 거리가 새 구간과 같다
  final score = ref.read(scoreTableProvider(const BasisCurrent())).value?.byLine[item.lineId];
  final reopened = score != null && score.started && score.remainingMeters == item.meters;
  return switch (item.kind) {
    NewsKind.lineOpened when reopened => t.lineReopened(line: line, km: km),
    NewsKind.lineOpened => t.lineOpened(line: line, km: km),
    NewsKind.lineClosed => t.lineClosed(line: line, km: km),
    NewsKind.stationOpened => t.stationOpened(station: station, line: line),
    NewsKind.stationClosed => t.stationClosed(station: station, line: line),
  };
}

/// 노선이나 역이 새로 생기거나 없어졌으면 앱을 열 때 한 번 보여 준다 (사용자 결정, 2026-11-03).
class NewsGate extends ConsumerStatefulWidget {
  const NewsGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NewsGate> createState() => _NewsGateState();
}

class _NewsGateState extends ConsumerState<NewsGate> {
  bool _asked = false;

  Future<void> _show(NewsData data) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _NewsDialog(data: data),
    );
    await markNewsSeen(ref);
    ref.invalidate(unseenNewsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(unseenNewsProvider).value;
    if (data != null && !data.isEmpty && !_asked) {
      _asked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _show(data);
      });
    }
    return widget.child;
  }
}

String _changed(BuildContext context, WidgetRef ref, RideChange change) {
  final t = context.t.news;
  final line = ref.read(nameBookProvider).lines[change.lineId] ?? change.label;
  final before = change.before;
  final after = change.after;
  if (change.statusChanged || change.dateChanged || before == null || after == null) {
    return t.rideReview(line: line);
  }
  return t.rideDistance(line: line, before: kmLabel(before * 100), after: kmLabel(after * 100));
}

class _NewsDialog extends ConsumerWidget {
  const _NewsDialog({required this.data});

  final NewsData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t.news;
    final items = data.items.take(6).toList();
    final more = data.items.length - items.length;
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      scrollable: true,
      title: Text(t.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          for (final change in data.changes.take(4)) Text(_changed(context, ref, change), style: text.bodyMedium),
          for (final item in items)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_describe(context, ref, item, data), style: text.bodyMedium),
                Text(dateText(context.t, item.date), style: text.bodySmall),
              ],
            ),
          if (more > 0) Text(t.more(n: more), style: text.bodySmall),
        ],
      ),
      actions: [FilledButton(onPressed: () => Navigator.pop(context), child: Text(t.ok))],
    );
  }
}

/// 설정의 변경 내역.
class NewsHistoryScreen extends ConsumerWidget {
  const NewsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t.news;
    return Scaffold(
      appBar: AppBar(title: Text(t.history)),
      body: switch (ref.watch(newsHistoryProvider)) {
        AsyncValue(hasValue: true, value: final data?) => ListView.separated(
            itemCount: data.changes.length + data.items.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index < data.changes.length) {
                return ListTile(title: Text(_changed(context, ref, data.changes[index])));
              }
              final item = data.items[index - data.changes.length];
              return ListTile(
                title: Text(_describe(context, ref, item, data)),
                subtitle: Text(dateText(context.t, item.date)),
              );
            },
          ),
        AsyncValue(hasError: true, :final error) => LoadError(error),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
