import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:noriori_core/noriori_core.dart' show BrowseEra;

import '../features/data/ui/backup_notice_bar.dart';
import '../features/data/ui/news_screens.dart';
import '../features/data/ui/data_settings_screen.dart';
import '../features/data/ui/deleted_screen.dart';
import '../features/data/ui/import_screen.dart';
import '../features/data/ui/restore_screen.dart';
import '../features/map/ui/map_home_screen.dart';
import '../features/record/ui/browse_screens.dart';
import '../features/record/ui/continue_sheet.dart';
import '../features/record/ui/line_detail_screen.dart';
import '../features/record/ui/journey_screen.dart';
import '../features/record/ui/line_search_screen.dart';
import '../features/record/ui/map_sheets.dart';
import '../features/record/ui/record_edit_screen.dart';
import '../features/record/ui/record_home_screen.dart';
import '../features/record/ui/record_session_screen.dart';
import '../features/record/ui/service_session_screen.dart';
import '../features/record/ui/trip_screens.dart';
import '../features/settings/ui/data_sources_screen.dart';
import '../features/settings/ui/settings_screen.dart';
import '../features/stats/ui/activity_screen.dart';
import '../features/stats/ui/collection_screen.dart';
import '../features/stats/ui/remaining_screen.dart';
import '../features/stats/ui/stats_screen.dart';
import '../features/stats/ui/visits_screen.dart';
import '../features/stats/ui/years_screen.dart';
import '../i18n/strings.g.dart';
import 'session_providers.dart';
import 'theme/app_theme.dart';

/// 하단 탭은 탭별로 스택을 유지한다 (ARCHITECTURE §2.3). 입력은 탭 위의 전체 화면이다.
GoRouter buildRouter({
  Widget map = const _Map(),
}) =>
    GoRouter(
      initialLocation: '/map',
      routes: [
        GoRoute(path: '/search', builder: (context, state) => const LineSearchScreen()),
        GoRoute(
          path: '/record/session',
          builder: (context, state) => RecordSessionScreen(
            returnBack: state.uri.queryParameters['back'] == '1',
          ),
        ),
        GoRoute(
          path: '/record/:rideId',
          builder: (context, state) => RecordEditScreen(rideId: state.pathParameters['rideId']!),
        ),
        GoRoute(path: '/journey', builder: (context, state) => const JourneyScreen()),
        GoRoute(
          path: '/trip/:id',
          builder: (context, state) => TripDetailScreen(tripId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/line/:id',
          builder: (context, state) => LineDetailScreen(lineId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/service/:id',
          builder: (context, state) => ServiceSessionScreen(serviceId: state.pathParameters['id']!),
        ),
        GoRoute(path: '/settings/data', builder: (context, state) => const DataSettingsScreen()),
        GoRoute(path: '/settings/news', builder: (context, state) => const NewsHistoryScreen()),
        GoRoute(path: '/settings/deleted', builder: (context, state) => const DeletedScreen()),
        GoRoute(path: '/settings/sources', builder: (context, state) => const DataSourcesScreen()),
        GoRoute(path: '/settings/data/restore', builder: (context, state) => const RestoreScreen()),
        GoRoute(path: '/settings/data/import', builder: (context, state) => const ImportScreen()),
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => _TabShell(shell: shell),
          branches: [
            _tab('/map', map),
            _tab('/record', const RecordHomeScreen(), routes: [_browse]),
            _tab('/stats', const StatsScreen(), routes: [
              GoRoute(path: 'collection', builder: (context, state) => const CollectionScreen()),
              GoRoute(path: 'remaining', builder: (context, state) => const RemainingScreen()),
              GoRoute(path: 'years', builder: (context, state) => const YearsScreen()),
              GoRoute(path: 'activity', builder: (context, state) => const ActivityScreen()),
              GoRoute(path: 'visits', builder: (context, state) => const VisitsScreen()),
            ]),
            _tab('/settings', const SettingsScreen()),
          ],
        ),
      ],
    );

/// 지도와 기록을 앱이 잇는다. 기능끼리는 서로를 모른다.
class _Map extends ConsumerWidget {
  const _Map();

  Future<void> _open(BuildContext context, WidgetRef ref, MapFeature feature) async {
    final node = feature.node;
    if (node != null) {
      final names = await ref.read(packReaderProvider).nodeNames([node]);
      if (!context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => StationSheet(node: node, name: names[node] ?? node),
      );
      return;
    }
    final marker = feature.marker;
    if (marker != null) {
      final markers = await ref.read(mapMarkersProvider.future);
      if (!context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => MarkerSheet(marker: markers.firstWhere((m) => m.id == marker)),
      );
      return;
    }
    final network = ref.read(networkProvider);
    final edges = network.edges.values.where((edge) => edge.n == feature.edge);
    if (edges.isEmpty) return;
    final lines = {for (final attr in network.attrsOfEdge(edges.first.id)) attr.lineId}.toList();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => LineSheet(lineIds: lines),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => MapHomeScreen(
        notice: const NewsGate(child: BackupNoticeBar()),
        sheet: const ContinueSheet(),
        sheetHeight: continueSheetHeight,
        onFeature: (feature) => _open(context, ref, feature),
      );
}

StatefulShellBranch _tab(String path, Widget screen, {List<RouteBase> routes = const []}) =>
    StatefulShellBranch(
      routes: [GoRoute(path: path, builder: (context, state) => screen, routes: routes)],
    );

/// 분류 → 회사 → 노선. 탭 안에 있어 아래 탭이 보이고 스택이 유지된다.
final _browse = GoRoute(
  path: 'browse/:era/:category',
  builder: (context, state) => OperatorListScreen(
    era: BrowseEra.values.byName(state.pathParameters['era']!),
    category: state.pathParameters['category']!,
  ),
  routes: [
    GoRoute(
      path: ':operator',
      builder: (context, state) => LineListScreen(
        era: BrowseEra.values.byName(state.pathParameters['era']!),
        category: state.pathParameters['category']!,
        operatorId: state.pathParameters['operator']!,
      ),
    ),
  ],
);

class _TabShell extends StatelessWidget {
  const _TabShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final tabs = context.t.tabs;
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    final items = [
      (Icons.map_outlined, tabs.map),
      (Icons.train_outlined, tabs.record),
      (Icons.bar_chart_outlined, tabs.stats),
      (Icons.tune, tabs.settings),
    ];
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.paper,
          border: Border(top: BorderSide(color: tokens.hairline)),
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: IntrinsicHeight(child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, (icon, label)) in items.indexed)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: index == shell.currentIndex,
                      child: InkResponse(
                      onTap: () => shell.goBranch(
                        index,
                        initialLocation: index == shell.currentIndex,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        spacing: 2,
                        children: [
                          Icon(
                            icon,
                            size: 23,
                            color: index == shell.currentIndex ? tokens.text : tokens.textClosed,
                          ),
                          Text(
                            label,
                            style: text.labelSmall?.copyWith(
                              fontWeight: index == shell.currentIndex
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: index == shell.currentIndex ? tokens.text : tokens.textClosed,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ),
                  ),
              ],
            )),
          ),
        ),
      ),
    );
  }
}
