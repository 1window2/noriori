import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets/load_error.dart';
import '../../../i18n/strings.g.dart';
import '../controller/visits_controller.dart';

/// 방문 역 수와 도도부현별 내역.
class VisitsScreen extends ConsumerWidget {
  const VisitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t.visits;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(t.title)),
      body: switch (ref.watch(visitsDataProvider)) {
        AsyncValue(hasValue: true, value: final data?) when data.total == 0 => Center(child: Text(t.empty)),
        AsyncValue(hasValue: true, value: final data?) => ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(t.count(n: data.total), style: text.headlineMedium),
                    Text(
                      [
                        t.split(open: data.total - data.closed, closed: data.closed),
                        t.prefs(n: data.byPref.length),
                      ].join(' · '),
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              for (final (pref, count) in data.byPref)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  title: Text(context.t.prefNames[pref - 1]),
                  trailing: Text(t.count(n: count)),
                ),
              if (data.unknown > 0)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  title: Text(t.unknown(n: data.unknown), style: text.bodySmall),
                ),
            ],
          ),
        AsyncValue(hasError: true, :final error) => LoadError(error),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
