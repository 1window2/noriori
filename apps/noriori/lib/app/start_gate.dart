import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';
import 'package:noriori_core/noriori_core.dart' show jstDate;
import 'package:noriori_store/noriori_store.dart';

import '../features/data/controller/backup_controller.dart';
import '../features/data/ui/blocked_start_screen.dart';
import '../features/data/ui/restore_screen.dart';
import '../i18n/strings.g.dart';
import 'bootstrap.dart';
import 'session_providers.dart';
import 'theme/app_theme.dart';
import 'router.dart';

/// 시작 결과가 나온 뒤에야 앱 본체를 만든다. 그래서 본체는 항상 고른 팩이 있는 상태다.
class StartGate extends StatefulWidget {
  const StartGate({super.key, required this.start});

  final Future<AppStart> Function({bool restoring}) start;

  @override
  State<StartGate> createState() => _StartGateState();
}

class _StartGateState extends State<StartGate> {
  late Future<AppStart> _start = widget.start();

  /// 복원 전용 화면을 닫기 전이다.
  bool _restoring = false;

  void _again({bool restoring = false}) => setState(() {
        _restoring = restoring;
        _start = widget.start(restoring: restoring);
      });

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: _start,
        builder: (context, snapshot) => switch (snapshot) {
          AsyncSnapshot(connectionState: ConnectionState.waiting) => const _Bare(child: _Splash()),
          AsyncSnapshot(hasError: true, :final error) =>
            _Bare(child: BlockedStartScreen.retry(reason: '$error', onAction: _again)),
          AsyncSnapshot(data: AppStart(outcome: StartReady(:final session), :final world?)) =>
            _restoring
                ? _RestoreApp(
                    session: session,
                    world: world,
                    onFinish: () => setState(() {
                      session.closeQuarantine();
                      _restoring = false;
                    }),
                  )
                : _SessionApp(session: session, world: world),
          AsyncSnapshot(data: AppStart(outcome: StartNeedsAppUpdate())) =>
            const _Bare(child: BlockedStartScreen.update()),
          AsyncSnapshot(data: AppStart(outcome: StartRetryLater(:final reason, noSpace: true))) =>
            _Bare(child: BlockedStartScreen.noSpace(reason: reason, onAction: _again)),
          AsyncSnapshot(data: AppStart(outcome: StartRetryLater(:final reason))) =>
            _Bare(child: BlockedStartScreen.retry(reason: reason, onAction: _again)),
          AsyncSnapshot(data: AppStart(outcome: StartRestoreOnly())) => _Bare(
              child: BlockedStartScreen.restoreOnly(onAction: () => _again(restoring: true)),
            ),
          _ => const _Bare(child: _Splash()),
        },
      );
}

List<Override> _overrides(AppSession session, PackWorld world) => [
      sessionProvider.overrideWithValue(session),
      networkProvider.overrideWithValue(world.network),
      nameBooksProvider.overrideWithValue(world.books),
      initialLanguageProvider.overrideWithValue(world.language),
      editionProvider.overrideWithValue(session.pack.edition),
      railTilesProvider.overrideWithValue(session.pack.railTiles),
      osmTilesProvider.overrideWithValue(session.pack.osmRailTiles),
      baseTilesProvider.overrideWithValue(session.pack.baseTiles),
      glyphsProvider.overrideWithValue(session.pack.glyphs),
      initialDisplayOptionsProvider.overrideWithValue(world.options),
      initialThemeProvider.overrideWithValue(world.theme),
      packFactsProvider.overrideWith((ref) async {
        final summary = await PackReader(session.db).summary();
        return PackFacts(stations: summary.stations, lines: summary.lines);
      }),
    ];

/// 복원 전용 화면. 닫기 전에는 탭이 없어 빈 DB로 넘어가지 않는다.
class _RestoreApp extends StatelessWidget {
  const _RestoreApp({required this.session, required this.world, required this.onFinish});

  final AppSession session;
  final PackWorld world;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) => ProviderScope(
        overrides: _overrides(session, world),
        child: _Bare(child: RestoreScreen(onFinish: onFinish)),
      );
}

class _Bare extends StatelessWidget {
  const _Bare({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: context.t.app.name,
        theme: appTheme(Brightness.light),
        darkTheme: appTheme(Brightness.dark),
        locale: TranslationProvider.of(context).flutterLocale,
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: child,
      );
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              const CircularProgressIndicator(),
              Text(context.t.start.loading),
            ],
          ),
        ),
      );
}

/// 한 세션의 앱. 팩과 생명주기를 여기서 묶는다.
class _SessionApp extends StatefulWidget {
  const _SessionApp({required this.session, required this.world});

  final AppSession session;
  final PackWorld world;

  @override
  State<_SessionApp> createState() => _SessionAppState();
}

class _SessionAppState extends State<_SessionApp> {
  late final GoRouter _router = buildRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return ProviderScope(
      overrides: _overrides(session, widget.world),
      child: _Lifecycle(
        child: Consumer(
          builder: (context, ref, _) => MaterialApp.router(
            title: context.t.app.name,
            theme: appTheme(Brightness.light),
            darkTheme: appTheme(Brightness.dark),
            themeMode: ref.watch(themeChoiceProvider).mode,
            locale: TranslationProvider.of(context).flutterLocale,
            supportedLocales: AppLocaleUtils.supportedLocales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            builder: withOverlayStyle,
            routerConfig: _router,
          ),
        ),
      ),
    );
  }
}

/// 앱이 백그라운드로 갈 때 체크포인트와 자동 백업을 한다.
class _Lifecycle extends ConsumerStatefulWidget {
  const _Lifecycle({required this.child});

  final Widget child;

  @override
  ConsumerState<_Lifecycle> createState() => _LifecycleState();
}

class _LifecycleState extends ConsumerState<_Lifecycle> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onPause: _paused, onResume: _resumed);
    ref.read(backupControllerProvider);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(sessionProvider).deleteUnusedPacks(),
    );
  }

  /// 잠든 동안에는 타이머가 돌지 않는다. 돌아오면 날짜부터 맞춘다.
  void _resumed() {
    final now = jstDate(ref.read(nowProvider)());
    if (now != ref.read(todayProvider)) ref.invalidate(todayProvider);
  }

  Future<void> _paused() async {
    await ref.read(sessionProvider).checkpoint();
    await ref.read(backupControllerProvider.notifier).run();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
