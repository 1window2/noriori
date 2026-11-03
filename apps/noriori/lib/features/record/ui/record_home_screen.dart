import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/widgets/pills.dart';
import '../../../i18n/strings.g.dart';
import '../controller/browse_controller.dart';
import 'browse_screens.dart';
import 'map_sheets.dart';
import 'record_list_screen.dart';
import 'trip_screens.dart';

/// 기록 탭. 찾아서 고르는 길과 훑어서 고르는 길을 나란히 둔다.
class RecordHomeScreen extends ConsumerWidget {
  const RecordHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(recordViewProvider);
    final t = context.t.record;
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: t.add,
        onPressed: () => context.push('/search'),
        child: const Icon(Icons.add, size: 28),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(t.title, style: Theme.of(context).textTheme.headlineMedium),
                  ),
                  IconButton(
                    tooltip: context.t.map.search,
                    icon: const Icon(Icons.search),
                    onPressed: () => context.push('/search'),
                  ),
                ],
              ),
            ),
            UnderlineTabs<RecordView>(
              values: RecordView.values,
              label: (value) => switch (value) {
                RecordView.lines => t.view.lines,
                RecordView.rides => t.view.rides,
                RecordView.trips => t.view.trips,
                RecordView.visits => t.view.visits,
              },
              selected: view,
              onChanged: ref.read(recordViewProvider.notifier).set,
            ),
            Expanded(
              child: switch (view) {
                RecordView.lines => const LineBrowseView(),
                RecordView.rides => const RecordListScreen(),
                RecordView.trips => const TripListView(),
                RecordView.visits => const VisitListView(),
              },
            ),
          ],
        ),
      ),
    );
  }
}
