import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:noriori/app/bootstrap.dart' show PackWorld;
import 'package:noriori/app/session_providers.dart';
import 'package:noriori/app/theme/app_theme.dart';
import 'package:noriori/features/record/controller/browse_controller.dart';
import 'package:noriori/features/record/controller/record_list_controller.dart';
import 'package:noriori/features/record/controller/record_session_controller.dart';
import 'package:noriori/features/record/ui/browse_screens.dart';
import 'package:noriori/features/record/ui/continue_sheet.dart';
import 'package:noriori/features/record/ui/line_tile.dart';
import 'package:noriori/features/record/ui/one_way_bubble.dart';
import 'package:noriori/features/record/ui/record_edit_screen.dart';
import 'package:noriori/features/record/ui/record_session_screen.dart';
import 'package:noriori/features/record/ui/session_date.dart';
import 'package:noriori/features/record/ui/switchback_mark.dart';
import 'package:noriori/features/stats/ui/stats_screen.dart';
import 'package:noriori/i18n/strings.g.dart';
import 'package:noriori_core/noriori_core.dart';
import 'package:noriori_store/noriori_store.dart';

// 실제 판으로 화면 흐름을 돈다. 팩은 tools/sync_pack.sh로 넣는다.
final _skip = File('assets/pack/manifest.json').existsSync() ? null : '팩이 없다';

final class _FileAssets implements PackAssets {
  @override
  Future<String> manifestText() => File('assets/pack/manifest.json').readAsString();

  @override
  Future<Uint8List> fileBytes(String name) => File('assets/pack/$name').readAsBytes();
}

/// 쓰기에서 기본 키가 겹쳐 트랜잭션이 실패한다. 공간 부족 같은 저장 실패의 대역이다.
final class _BadInterpreter implements RecordInterpreter {
  _BadInterpreter(this.inner);

  final RecordInterpreter inner;

  @override
  RideDerived ride(Ride ride) => const RideDerived(
        status: ResolveStatus.ok,
        legs: [
          LegDerived(seq: 0, lineId: LineId('l'), routeId: RouteId('r'), km10: 1),
          LegDerived(seq: 0, lineId: LineId('l'), routeId: RouteId('r'), km10: 1),
        ],
      );

  @override
  VisitDerived visit(Visit visit) => inner.visit(visit);
}

final class _Rig {
  _Rig(this.session, this.world);

  final AppSession session;
  final PackWorld world;

  Future<List<Ride>> live() async =>
      (await session.records.allRides()).where((ride) => !ride.isDeleted).toList();

  String line(String name) => world.books[AppLocale.ko]!.lines.entries.firstWhere((e) => e.value == name).key;

  List<Override> overrides({String? today, AppLocale locale = AppLocale.ko}) => [
        sessionProvider.overrideWithValue(session),
        networkProvider.overrideWithValue(world.network),
        nameBookProvider.overrideWithValue(world.books[locale]!),
        if (locale != AppLocale.ko)
          packReaderProvider.overrideWithValue(PackReader(session.db, languages: nameLanguages(locale))),
        editionProvider.overrideWithValue(session.pack.edition),
        if (today != null) todayProvider.overrideWithValue(today),
      ];
}

Future<_Rig> _open({RecordInterpreter Function(RecordInterpreter)? interpreter}) async {
  final dir = Directory.systemTemp.createTempSync('flows');
  PackWorld? world;
  final outcome = await ColdStart(
    paths: StorePaths(dir),
    assets: _FileAssets(),
    appBuild: 1,
    supportedPackSchema: supportedPackSchema,
    connect: openDirect,
    interpreter: (db) async {
      final network = Network(await NetworkReader(db).read());
      // 언어마다 노선·역 이름이 다르다. 전수 화면 점검은 세 언어로 돈다
      world = PackWorld(network: network, books: {
        for (final locale in AppLocale.values) locale: await PackReader(db, languages: nameLanguages(locale)).nameBook(),
      });
      final real = RideInterpreter(network);
      return interpreter == null ? real : interpreter(real);
    },
    now: () => DateTime.now().millisecondsSinceEpoch,
  ).run();
  return _Rig((outcome as StartReady).session, world!);
}

GoRouter _router(Widget home) => GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => Scaffold(body: home)),
        GoRoute(path: '/record', builder: (context, state) => const Scaffold(body: Text('기록 탭'))),
        GoRoute(
          path: '/record/session',
          builder: (context, state) =>
              RecordSessionScreen(returnBack: state.uri.queryParameters['back'] == '1'),
        ),
      ],
    );

Widget _app(GoRouter router, ProviderContainer container, {AppLocale locale = AppLocale.ko}) => TranslationProvider(
      child: UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: appTheme(Brightness.light),
          locale: Locale(locale.languageCode),
          supportedLocales: AppLocaleUtils.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          routerConfig: router,
        ),
      ),
    );

/// 진짜 파일 쓰기가 끼면 pumpAndSettle이 끝나지 않는다. 프레임만 민다.
Future<void> _frames(WidgetTester tester, [int count = 20]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// 화면 글자에 새어 나온 내부 ID(`n_…`, `r_…`, `l_…` 등). 이름 행이 없으면 ID가 그대로 나온다
final _idLike = RegExp(r'\b[nrlega]_[a-z0-9_]{3,}\b');
String? _leakedId(WidgetTester tester) {
  for (final paragraph in tester.allRenderObjects.whereType<RenderParagraph>()) {
    final match = _idLike.firstMatch(paragraph.text.toPlainText());
    if (match != null) return match.group(0);
  }
  return null;
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// 세션 화면을 띄우고 위에서 [a]번째, [b]번째 역을 고른다.
Future<ProviderContainer> _session(
  WidgetTester tester,
  _Rig rig,
  String line, {
  int a = 1,
  int b = 3,
  String? routeId,
  bool dateUnknown = false,
  String? today,
}) async {
  final container = ProviderContainer(overrides: rig.overrides(today: today));
  addTearDown(container.dispose);
  final session = container.read(recordSessionProvider.notifier);
  await tester.runAsync(
    () => session.open(lineId: line, routeId: routeId, dateUnknown: dateUnknown),
  );
  final router = _router(const Text('처음'));
  await tester.pumpWidget(_app(router, container));
  await _frames(tester, 3);
  unawaited(router.push<void>('/record/session?back=1'));
  await _frames(tester, 30);
  final rows = container.read(recordSessionProvider).rows;
  session.tap(rows[a]);
  session.tap(rows[b]);
  await _frames(tester, 3);
  return container;
}

void main() {
  late _Rig rig;

  setUpAll(() async {
    if (_skip == null) rig = await _open();
  });

  testWidgets('순환에서 고른 방향은 날짜를 바꿔도 남는다', skip: _skip != null, (tester) async {
    final network = rig.world.network;
    final container = ProviderContainer(overrides: rig.overrides());
    addTearDown(container.dispose);
    final route = network.routes.values.firstWhere((item) => item.closed && item.role == 'main');
    final session = container.read(recordSessionProvider.notifier);
    await tester.runAsync(() => session.open(lineId: route.lineId, routeId: route.id));
    final rows = container.read(recordSessionProvider).rows.where((row) => row.selectable).toList();
    session.tap(rows[1]);
    session.tap(rows[4]);
    final shorter = container.read(recordSessionProvider).preview?.direction;
    final longer = shorter == seqUp ? seqDown : seqUp;
    session.setDirection(longer);
    final meters = container.read(recordSessionProvider).preview?.meters;
    await tester.runAsync(() => session.setDate('2026-01-01'));
    final state = container.read(recordSessionProvider);
    expect(state.direction, longer);
    expect(state.preview?.meters, meters);
  });

  testWidgets('연달아 연 노선은 마지막 노선의 줄만 남는다', skip: _skip != null, (tester) async {
    final container = ProviderContainer(overrides: rig.overrides());
    addTearDown(container.dispose);
    final session = container.read(recordSessionProvider.notifier);
    final tokaido = rig.line('도카이도 본선');
    final yamanote = rig.line('야마노테선');
    await tester.runAsync(
      () => Future.wait([session.open(lineId: tokaido), session.open(lineId: yamanote)]),
    );
    final state = container.read(recordSessionProvider);
    expect(state.lineId, yamanote);
    final nodes = rig.world.network.routesOfLine(yamanote).expand(rig.world.network.picks).map((stop) => stop.node).toSet();
    expect(state.rows.every((row) => nodes.contains(row.node)), isTrue);
  });

  testWidgets('역 묶음의 도도부현을 팩에서 읽는다', skip: _skip != null, (tester) async {
    await tester.runAsync(() async {
      final db = rig.session.db;
      final rows = await db.customSelect("SELECT n FROM master.station_group WHERE id = 'g_shinjuku'").get();
      final group = rows.single.read<int>('n');
      expect(await PackReader(db).groupPrefs({group, -1}), {group: 13});
    });
  });

  testWidgets('기록하기를 두 번 눌러도 한 건이다', skip: _skip != null, (tester) async {
    _phone(tester);
    final before = (await tester.runAsync(rig.live))!.length;
    await _session(tester, rig, rig.line('야마노테선'));
    final save = find.text('기록하기');
    await tester.tap(save);
    await tester.tap(save, warnIfMissed: false);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await _frames(tester, 30);
    expect((await tester.runAsync(rig.live))!.length, before + 1);
  });

  testWidgets('이설 질문을 바깥을 눌러 닫으면 저장하지 않는다', skip: _skip != null, (tester) async {
    _phone(tester);
    final network = rig.world.network;
    final resolver = RouteResolver(network);
    late String route;
    late int a;
    late int b;
    search:
    for (final id in network.routes.keys) {
      final rows = SelectorBuilder(network).build(id, null).where((row) => row.selectable).toList();
      if (rows.length > 40) continue;
      for (final (i, x) in rows.indexed) {
        for (final (j, y) in rows.indexed) {
          if (j <= i) continue;
          if (resolver.record(id, x.node, y.node).reason == ExpandReason.relocatedParallel) {
            (route, a, b) = (id, i, j);
            break search;
          }
        }
      }
    }
    final before = (await tester.runAsync(rig.live))!.length;
    await _session(
      tester,
      rig,
      network.routes[route]!.lineId,
      routeId: route,
      a: a,
      b: b,
      dateUnknown: true,
    );
    await tester.tap(find.text('기록하기'));
    await _frames(tester);
    expect(find.text('어느 시기의 선로였나요?'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await _frames(tester, 30);
    expect(find.text('어느 시기의 선로였나요?'), findsNothing);
    expect(find.byType(RecordSessionScreen), findsOneWidget);
    expect((await tester.runAsync(rig.live))!.length, before);
  });

  testWidgets('탑승일을 바꿔도 스크롤이 맨 위로 가지 않는다', skip: _skip != null, (tester) async {
    _phone(tester);
    final container = await _session(tester, rig, rig.line('도카이도 본선'));
    final list = find.byType(ListView).last;
    await tester.drag(list, const Offset(0, -2500));
    await _frames(tester, 60);
    double offset() => tester
        .state<ScrollableState>(find.descendant(of: list, matching: find.byType(Scrollable)).first)
        .position
        .pixels;
    final before = offset();
    expect(before, greaterThan(0));
    final change = container.read(recordSessionProvider.notifier).setDate('2000-01-01');
    await tester.pump();
    expect(offset(), before);
    await tester.runAsync(() => change);
    await _frames(tester);
    expect(offset(), before);
  });

  testWidgets('노선을 연달아 눌러도 세션 화면은 한 장이다', skip: _skip != null, (tester) async {
    _phone(tester);
    final network = rig.world.network;
    final tree = browseTree(network, era: BrowseEra.current, hits: const {}, today: '2026-11-02');
    final category = tree.categories.first;
    final container = ProviderContainer(
      overrides: [
        ...rig.overrides(today: '2026-11-02'),
        unitHitsProvider.overrideWith((ref) => Stream.value(const <int, String?>{})),
      ],
    );
    addTearDown(container.dispose);
    final router = _router(
      LineListScreen(
        era: BrowseEra.current,
        category: category.category,
        operatorId: category.operators.first.operatorId,
      ),
    );
    await tester.pumpWidget(_app(router, container));
    await _frames(tester, 30);
    final row = find.byType(InkWell).at(6);
    await tester.tap(row);
    await tester.tap(row, warnIfMissed: false);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await _frames(tester, 40);
    expect(find.byType(RecordSessionScreen, skipOffstage: false), findsOneWidget);
  });

  testWidgets('저장에 실패하면 화면에 알리고 그 화면에 남는다', skip: _skip != null, (tester) async {
    _phone(tester);
    final broken = (await tester.runAsync(() => _open(interpreter: _BadInterpreter.new)))!;
    await _session(tester, broken, broken.line('야마노테선'));
    await tester.tap(find.text('기록하기'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await _frames(tester, 30);
    expect(find.text('저장하지 못했습니다. 기록은 바뀌지 않았습니다'), findsOneWidget);
    expect(find.byType(RecordSessionScreen), findsOneWidget);
  });

  testWidgets('순환선은 짧은 쪽을 칠하고 탄 방향을 저장한다', skip: _skip != null, (tester) async {
    _phone(tester);
    final network = rig.world.network;
    final route = network.routes.values.firstWhere((route) => route.closed);
    final container = await _session(tester, rig, route.lineId, routeId: route.id, a: 1, b: 0);
    final session = container.read(recordSessionProvider.notifier);
    final rows = container.read(recordSessionProvider).rows;
    // 끝을 넘는 짧은 쪽: 끝에서 두 번째 역 → 두 번째 역
    session.tap(rows[rows.length - 2]);
    session.tap(rows[1]);
    await _frames(tester, 3);
    final state = container.read(recordSessionProvider);
    final preview = state.preview!;
    expect(preview.saved, isTrue);
    final walked = preview.nodes.where(network.data.publicNodes.contains).toSet();
    final painted = {
      for (final row in rows)
        if (state.isPicked(row.seq)) row.node,
    };
    expect(painted, walked);
    expect(state.coversBelow(rows[rows.length ~/ 2].seq), isFalse);

    final before = (await tester.runAsync(rig.live))!.length;
    await tester.tap(find.text('기록하기'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await _frames(tester, 30);
    final rides = (await tester.runAsync(rig.live))!;
    expect(rides.length, before + 1);
    final saved = rides.reduce((a, b) => a.createdAt >= b.createdAt ? a : b);
    expect(saved.legs.single.direction, preview.direction);
    expect(saved.legs.single.direction, isNotNull);
  });

  testWidgets('날짜 모름으로 내려간 기록은 입력한 날짜로 보이지 않는다', skip: _skip != null, (tester) async {
    _phone(tester);
    final container = await _session(tester, rig, rig.line('야마노테선'), a: 2, b: 4);
    final session = container.read(recordSessionProvider.notifier);
    await tester.runAsync(() => session.setDate('1949-05-05'));
    await _frames(tester, 3);
    final state = container.read(recordSessionProvider);
    if (state.preview == null) {
      session.tap(state.rows[2]);
      session.tap(state.rows[4]);
    }
    await tester.tap(find.text('기록하기'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await _frames(tester, 30);
    final rides = (await tester.runAsync(
      () => RecordQueries(rig.session.db).watchRides().first,
    ))!;
    final shown = rides.firstWhere((ride) => ride.dateInput == '1949-05-05');
    expect(shown.date, isNull);
    expect(shown.shownDate, isNull);
  });

  /// 오늘은 고를 역이 없고 날짜를 모르면 고를 수 있는 폐선 계통. 고를 수 있는 줄의 번호를 함께 준다.
  (String, List<int>) closedRoute() {
    final network = rig.world.network;
    final builder = SelectorBuilder(network);
    for (final route in network.routes.values) {
      if (route.closed || route.role != 'main') continue;
      if (builder.build(route.id, DateSpan.parse('2026-11-02')).any((row) => row.selectable)) continue;
      final rows = builder.build(route.id, null);
      final open = [for (final (i, row) in rows.indexed) if (row.selectable) i];
      if (open.length >= 4) return (route.id, open);
    }
    throw StateError('폐선 계통이 없다');
  }

  testWidgets('고른 구간을 그날 탈 수 없으면 날짜를 바꾸지 않고 경고한다', skip: _skip != null, (tester) async {
    _phone(tester);
    final (route, open) = closedRoute();
    final container = await _session(
      tester,
      rig,
      rig.world.network.routes[route]!.lineId,
      routeId: route,
      a: open[1],
      b: open[3],
      dateUnknown: true,
      today: '2026-11-02',
    );
    final before = container.read(recordSessionProvider);
    expect(before.dateInput, isNull);
    expect(before.preview?.saved, isTrue);
    await tester.tap(find.byType(SessionDateChip));
    await _frames(tester, 10);
    await tester.enterText(
      find.descendant(of: find.byType(SessionDateDialog), matching: find.byType(TextField)),
      '2026-11-01',
    );
    await tester.tap(find.text('적용'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await _frames(tester, 20);
    expect(find.text('그 날짜에는 탈 수 없는 구간입니다'), findsOneWidget);
    expect(find.textContaining('1950'), findsNothing);
    final after = container.read(recordSessionProvider);
    expect(after.dateInput, isNull, reason: '원래 날짜를 지킨다');
    expect(after.from?.seq, before.from?.seq);
    expect(after.to?.seq, before.to?.seq);
    expect(after.preview?.saved, isTrue);
    await tester.tap(find.widgetWithText(TextButton, '확인'));
    await _frames(tester, 40);
    expect(find.text('그 날짜에는 탈 수 없는 구간입니다'), findsNothing);
    // 기준일보다 이른 날짜는 기록 범위 밖이라 경고 없이 받는다
    final session = container.read(recordSessionProvider.notifier);
    expect(await tester.runAsync(() => session.setDate('1949-05-05')), isFalse);
    expect(container.read(recordSessionProvider).dateInput, '1949-05-05');
    expect(container.read(recordSessionProvider).to?.seq, before.to?.seq);
  });

  testWidgets('기록의 날짜를 그날 탈 수 없는 날로 고치면 경고하고 고치지 않는다', skip: _skip != null, (tester) async {
    _phone(tester);
    final (route, open) = closedRoute();
    final container = await _session(
      tester,
      rig,
      rig.world.network.routes[route]!.lineId,
      routeId: route,
      a: open[1],
      b: open[3],
      dateUnknown: true,
      today: '2026-11-02',
    );
    final outcome = await tester.runAsync(() => container.read(recordSessionProvider.notifier).save());
    expect(outcome, isA<SaveDone>());
    final ride = (outcome! as SaveDone).change.after.single as Ride;
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const Scaffold(body: Text('처음'))),
        GoRoute(path: '/edit', builder: (context, state) => RecordEditScreen(rideId: ride.rideId.value)),
      ],
    );
    await tester.pumpWidget(_app(router, container));
    await _frames(tester, 3);
    unawaited(router.push<void>('/edit'));
    await _frames(tester, 10);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await _frames(tester, 10);
    await tester.enterText(find.widgetWithText(TextField, '탑승일'), '2026-11-01');
    await _frames(tester, 3);
    await tester.ensureVisible(find.text('저장'));
    await _frames(tester, 3);
    await tester.tap(find.text('저장'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await _frames(tester, 20);
    expect(find.text('그 날짜에는 탈 수 없는 구간입니다'), findsOneWidget);
    final kept = (await tester.runAsync(() => rig.session.records.ride(ride.rideId)))!;
    expect(kept.dateInput, isNull);
    expect(kept.updatedAt, ride.updatedAt);
  });

  testWidgets('첫 기록이 아주 짧아도 통계 머리가 깨지지 않는다', skip: _skip != null, (tester) async {
    _phone(tester);
    final unit = rig.world.network.data.units.firstWhere(
      (unit) => unit.carryover && unit.normal && unit.meters < 1500 && unit.dateHi == DateSpan.maxDate,
    );
    final container = ProviderContainer(
      overrides: [
        ...rig.overrides(today: '2026-11-02'),
        unitHitsProvider.overrideWith((ref) => Stream.value({unit.n: '2026-11-02'})),
        riddenNodesProvider.overrideWith((ref) => Stream.value(const <String>{})),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      TranslationProvider(
        child: UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: appTheme(Brightness.light),
            home: const Scaffold(body: StatsScreen()),
          ),
        ),
      ),
    );
    await _frames(tester, 30);
    expect(find.text('<0.01%'), findsOneWidget);
    expect(find.text('<0.01'), findsNothing);
  });

  testWidgets('켜 둔 채 자정을 넘기면 오늘이 바뀐다', (tester) async {
    var clock = DateTime.utc(2026, 11, 2, 14, 59, 59).millisecondsSinceEpoch;
    final container = ProviderContainer(overrides: [nowProvider.overrideWithValue(() => clock)]);
    final seen = <String>[];
    final watch = container.listen(todayProvider, (_, next) => seen.add(next), fireImmediately: true);
    expect(seen, ['2026-11-02']);
    clock += 1000;
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(seen, ['2026-11-02', '2026-11-03']);
    watch.close();
    container.dispose();
  });

  testWidgets('역 선택기에 환승, 분기, 폐역, 열람 전용 역이 나온다', skip: _skip != null, (tester) async {
    _phone(tester);
    final container = await _session(
      tester,
      rig,
      rig.line('소야 본선'),
      a: 0,
      b: 1,
      today: '2026-11-02',
    );
    final state = container.read(recordSessionProvider);
    expect(state.lines.whereType<BranchLine>(), isNotEmpty);
    expect(state.lines.whereType<EndLine>(), isNotEmpty);
    final pier = state.lines.whereType<ArchiveLine>().last;
    expect(state.archiveNames[pier.stop.id], '왓카나이잔교');
    expect(state.lines.last, pier);
    expect(find.text('세키호쿠 본선'), findsOneWidget);
    expect(find.text('폐역·폐선 표시'), findsOneWidget);
    expect(find.textContaining('旭川'), findsWidgets);
    expect(state.rows.any((row) => row.closeYear == '2021' && !row.selectable), isTrue);
  });

  testWidgets('운휴로 끊긴 연결은 끝난 해 대신 운휴 중으로 적는다 (外房線 大原의 いすみ線, 10회차 G1 kanto_3-007)', skip: _skip != null, (tester) async {
    // 전수 화면 점검과 같은 좁은 폰·큰 글자 (사용자 지시 2026-11-12: 세 언어)
    for (final (width, scale, locale) in const [(360.0, 1.3, AppLocale.ko), (360.0, 1.3, AppLocale.en), (360.0, 1.3, AppLocale.ja)]) {
      LocaleSettings.setLocaleSync(locale);
      tester.view.physicalSize = Size(width * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      final container = ProviderContainer(overrides: rig.overrides(today: '2026-11-16', locale: locale));
      final session = container.read(recordSessionProvider.notifier);
      await tester.runAsync(() => session.open(lineId: 'l_sotobo_line', routeId: 'r_sotobo_line'));
      final router = _router(const Text('처음'));
      await tester.pumpWidget(_app(router, container, locale: locale));
      await _frames(tester, 2);
      unawaited(router.push<void>('/record/session?back=1'));
      await _frames(tester, 12);
      final state = container.read(recordSessionProvider);
      expect(state.lines.whereType<BranchLine>().any((line) => line.item.suspended && line.item.link.otherLineId == 'l_isumi_line'), isTrue);
      final word = switch (locale) { AppLocale.ko => '운휴 중', AppLocale.en => 'Suspended', AppLocale.ja => '運休中' };
      await tester.scrollUntilVisible(find.textContaining(word), 300, scrollable: find.descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable)).first);
      expect(find.textContaining(word), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    }
    // 세션 화면이 남긴 지연 타이머를 흘려 보낸다
    await tester.pump(const Duration(seconds: 10));
    LocaleSettings.setLocaleSync(AppLocale.ko);
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });

  testWidgets('첫 역 앞의 열람 전용 역은 첫 역 위에 보인다 (志度線 瓦町 앞 中野町·藤塚·公園前, 10회차 G1 chugoku_shikoku_2-003)', skip: _skip != null, (tester) async {
    for (final locale in AppLocale.values) {
      LocaleSettings.setLocaleSync(locale);
      tester.view.physicalSize = const Size(360 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      final container = ProviderContainer(overrides: rig.overrides(today: '2026-11-16', locale: locale));
      final session = container.read(recordSessionProvider.notifier);
      await tester.runAsync(() => session.open(lineId: 'l_shido_line', routeId: 'r_shido_line'));
      final router = _router(const Text('처음'));
      await tester.pumpWidget(_app(router, container, locale: locale));
      await _frames(tester, 2);
      unawaited(router.push<void>('/record/session?back=1'));
      await _frames(tester, 12);
      final state = container.read(recordSessionProvider);
      final top = state.lines.takeWhile((line) => line is! StopLine).whereType<ArchiveLine>().toList();
      expect(top.length, greaterThanOrEqualTo(3));
      expect(top.every((line) => line.gap == -1), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    }
    // 세션 화면이 남긴 지연 타이머를 흘려 보낸다
    await tester.pump(const Duration(seconds: 10));
    LocaleSettings.setLocaleSync(AppLocale.ko);
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });

  testWidgets('끝 역 스위치백 직통은 점선 왼쪽 표식을 누르면 말풍선으로 알린다 (富士山 大月線→河口湖線, 11회차 S3)', skip: _skip != null, (tester) async {
    for (final locale in AppLocale.values) {
      LocaleSettings.setLocaleSync(locale);
      tester.view.physicalSize = const Size(360 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      final container = ProviderContainer(overrides: rig.overrides(today: '2026-11-16', locale: locale));
      final session = container.read(recordSessionProvider.notifier);
      await tester.runAsync(() => session.open(lineId: 'l_otsuki_line', routeId: 'r_otsuki_line'));
      final router = _router(const Text('처음'));
      await tester.pumpWidget(_app(router, container, locale: locale));
      await _frames(tester, 2);
      unawaited(router.push<void>('/record/session?back=1'));
      await _frames(tester, 12);
      final state = container.read(recordSessionProvider);
      final end = state.lines.whereType<EndLine>().where((line) => line.items.first.link.otherLineId == 'l_kawaguchiko_line');
      // 표식 칸이 없는 옛 판이면 표식도 없다
      if (end.isEmpty || !end.first.items.any((item) => reverseOn(item.link, DateSpan.parse('2026-11-16')) != null)) {
        await tester.pumpWidget(const SizedBox());
        container.dispose();
        continue;
      }
      final mark = find.byType(SwitchbackMark);
      await tester.scrollUntilVisible(mark, 300, scrollable: find.descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable)).first);
      await tester.tap(mark.first);
      await tester.pump();
      final word = switch (locale) { AppLocale.ko => '진행 방향을 바꿔', AppLocale.en => 'Trains reverse here', AppLocale.ja => '進行方向を変えて' };
      expect(find.textContaining(word), findsOneWidget);
      expect(tester.takeException(), isNull);
      OneWayBubble.dismiss();
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    }
    // 세션 화면과 말풍선이 남긴 지연 타이머를 흘려 보낸다
    await tester.pump(const Duration(seconds: 10));
    LocaleSettings.setLocaleSync(AppLocale.ko);
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });

  testWidgets('환승 묶음이 둘 이상이면 번호를 붙인다', skip: _skip != null, (tester) async {
    _phone(tester);
    final container = await _session(tester, rig, rig.line('도카이도 본선'), today: '2026-11-02');
    final state = container.read(recordSessionProvider);
    final numbered = state.lines
        .whereType<StopLine>()
        .where((line) => line.transfers.length > 1)
        .toList();
    expect(numbered, isNotEmpty);
    // 번호는 종류에 고정이다: ① 지나감 ② 위 ③ 아래 ④ unknown (DESIGN §2.9)
    for (final line in numbered) {
      expect(line.transfers.map((g) => g.number), [for (final g in line.transfers) g.flow.index + 1]);
    }
    expect(numbered.every((line) => line.transfers.length <= 4), isTrue);
  });

  testWidgets('폐역 표시를 끄면 그날 없는 역이 사라지고 켜면 돌아온다', skip: _skip != null, (tester) async {
    _phone(tester);
    final container = await _session(tester, rig, rig.line('소야 본선'), today: '2026-11-02');
    final before = container.read(recordSessionProvider).visible.length;
    await tester.runAsync(() async {
      container.read(displayOptionsProvider.notifier).state = const DisplayOptions(showClosed: false);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await _frames(tester, 5);
    final hidden = container.read(recordSessionProvider);
    expect(hidden.visible.length, lessThan(before));
    expect(hidden.lines.whereType<ArchiveLine>(), isEmpty);
    await tester.runAsync(() async {
      container.read(displayOptionsProvider.notifier).state = const DisplayOptions();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await _frames(tester, 5);
    expect(container.read(recordSessionProvider).visible.length, before);
  });

  testWidgets('순환은 두 방향의 거리를 보여 주고 고른 방향으로 칠한다', skip: _skip != null, (tester) async {
    _phone(tester);
    final network = rig.world.network;
    final route = network.routes.values.firstWhere((route) => route.closed);
    final container = await _session(tester, rig, route.lineId, routeId: route.id, a: 1, b: 3);
    final state = container.read(recordSessionProvider);
    final ways = state.ways!;
    expect(ways.up, isNot(ways.down));
    final session = container.read(recordSessionProvider.notifier);
    final longer = ways.up > ways.down ? seqUp : seqDown;
    session.setDirection(longer);
    await _frames(tester, 3);
    expect(container.read(recordSessionProvider).preview!.meters, [ways.up, ways.down].reduce(math.max));
  });

  testWidgets('이어서 타기를 끌어 올리면 목록이 된다', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        continueRowsProvider.overrideWith(
          (ref) async => [
            const LineRow(
              line: BrowseLine(
                lineId: 'l',
                score: Score(numMeters: 1000, denMeters: 4000, numUnits: 1, denUnits: 2),
              ),
              strip: LineStrip(totalMeters: 4000, segments: [StripSegment(0, 1000)]),
              startName: '처음역',
            ),
          ],
        ),
        nameBookProvider.overrideWithValue(
          const NameBook(lines: {'l': '시험선'}, routes: {}, operators: {}),
        ),
      ],
    );
    await tester.pumpWidget(
      TranslationProvider(
        child: UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: appTheme(Brightness.light),
            home: const Scaffold(body: Stack(fit: StackFit.expand, children: [ContinueSheet()])),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LineTile), findsNothing);
    await tester.drag(find.text('이어서 타기'), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.byType(LineTile), findsOneWidget);
    expect(find.text('처음역'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('기록을 고치면 날짜와 메모가 바뀌고 다시 해석된다', skip: _skip != null, (tester) async {
    _phone(tester);
    final session = rig.session;
    final container = await _session(tester, rig, rig.line('야마노테선'), a: 2, b: 4);
    await tester.tap(find.text('기록하기'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await _frames(tester, 30);
    final rides = (await tester.runAsync(rig.live))!;
    final ride = rides.reduce((a, b) => a.createdAt >= b.createdAt ? a : b);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const Scaffold(body: Text('처음'))),
        GoRoute(
          path: '/edit',
          builder: (context, state) => RecordEditScreen(rideId: ride.rideId.value),
        ),
      ],
    );
    await tester.pumpWidget(_app(router, container));
    await _frames(tester, 3);
    unawaited(router.push<void>('/edit'));
    await _frames(tester, 10);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await _frames(tester, 10);
    await tester.enterText(find.widgetWithText(TextField, '탑승일'), '2020-05');
    await tester.enterText(find.widgetWithText(TextField, '메모'), '처음 탄 날');
    await _frames(tester, 3);
    // 기록 직후의 안내가 아직 떠 있으면 아래쪽 버튼을 가린다
    ScaffoldMessenger.of(tester.element(find.byType(RecordEditScreen))).removeCurrentSnackBar();
    await _frames(tester, 3);
    await tester.ensureVisible(find.text('저장'));
    await _frames(tester, 3);
    await tester.tap(find.text('저장'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await _frames(tester, 20);
    final saved = (await tester.runAsync(() => session.records.ride(ride.rideId)))!;
    expect(saved.dateInput, '2020-05-XX');
    expect(saved.note, '처음 탄 날');
    expect(saved.updatedAt, greaterThan(ride.updatedAt));
    final list = (await tester.runAsync(() => RecordQueries(session.db).watchRides().first))!;
    expect(list.firstWhere((row) => row.rideId == ride.rideId).date, '2020-05-XX');
  });

  testWidgets('방문은 완주율을 바꾸지 않고 지도의 점만 칠한다', skip: _skip != null, (tester) async {
    _phone(tester);
    final network = rig.world.network;
    final node = network.stops(network.routes.values.first.id).first.node;
    final container = ProviderContainer(overrides: rig.overrides(today: '2026-11-02'));
    addTearDown(container.dispose);
    final commands = container.read(recordCommandsProvider);
    final queries = RecordQueries(rig.session.db);
    final before = (await tester.runAsync(rig.live))!.length;
    await tester.runAsync(
      () => commands.addVisit(node: node, label: '시험역', deviceId: 'd', id: 'visit-1'),
    );
    final visits = (await tester.runAsync(() => queries.watchVisits().first))!;
    expect(visits.single.label, '시험역');
    expect((await tester.runAsync(rig.live))!.length, before);
    await tester.runAsync(() => commands.deleteVisit(const VisitId('visit-1')));
    expect((await tester.runAsync(() => queries.watchVisits().first))!, isEmpty);
  });

  /// 北陸本線을 열고 [from], [to] 역을 골라 저장한다. 저장한 기록과 목록의 요약을 돌려준다 (DESIGN §8.0.1 이관 구간).
  Future<(Ride, RideSummary)> saveOnHokuriku(
    WidgetTester tester,
    String from,
    String to, {
    bool dateUnknown = false,
  }) async {
    final container = await _session(tester, rig, 'l_hokuriku_main_line', today: '2026-11-07', dateUnknown: dateUnknown);
    final session = container.read(recordSessionProvider.notifier);
    SelectorRow at(String node) => container.read(recordSessionProvider).rows.singleWhere((row) => row.node == node);
    session.clearPicks();
    session.tap(at(from));
    session.tap(at(to));
    await _frames(tester, 3);
    final state = container.read(recordSessionProvider);
    expect(state.preview?.saved, isTrue);
    // 고른 두 역 사이가 칠해진다
    expect(state.rows.where((row) => state.isPicked(row.seq)).map((row) => row.node), containsAll([from, to]));
    final before = (await tester.runAsync(rig.live))!.length;
    await tester.tap(find.text('기록하기'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await _frames(tester, 30);
    final rides = (await tester.runAsync(rig.live))!;
    expect(rides.length, before + 1);
    final saved = rides.reduce((a, b) => a.createdAt >= b.createdAt ? a : b);
    final list = (await tester.runAsync(() => RecordQueries(rig.session.db).watchRides().first))!;
    return (saved, list.singleWhere((ride) => ride.rideId == saved.rideId));
  }

  testWidgets('이관 뒤 날짜에 구간 안의 새 역을 골라 저장하면 이어받은 노선과 그 km로 저장된다', skip: _skip != null, (tester) async {
    _phone(tester);
    final (saved, summary) = await saveOnHokuriku(tester, 'n_shikibu', 'n_fukui');
    final derived = RideInterpreter(rig.world.network).ride(saved);
    // ハピラインふくい線 しきぶ 33.3km → 福井 54.0km
    expect([for (final leg in derived.legs) (leg.lineId, leg.km10)], [('l_hapi_line_fukui_line', 207)]);
    expect(derived.date, '2026-11-07');
    expect(summary.lineId, 'l_hapi_line_fukui_line');
    expect(summary.km10, 207);
    expect(summary.lineLabel, '하피라인 후쿠이선');
  });

  testWidgets('국철 쪽 역에서 이관 뒤 새 역까지 고르면 두 노선에 나눠 저장된다', skip: _skip != null, (tester) async {
    _phone(tester);
    final (saved, summary) = await saveOnHokuriku(tester, 'n_shin_hikida', 'n_shikibu');
    final derived = RideInterpreter(rig.world.network).ride(saved);
    // 新疋田 39.2km → 敦賀 45.9km는 北陸本線, 敦賀 → しきぶ 33.3km는 ハピラインふくい線
    expect([for (final leg in derived.legs) (leg.lineId, leg.km10)], [
      ('l_hokuriku_main_line', 67),
      ('l_hapi_line_fukui_line', 333),
    ]);
    expect(summary.km10, 400);
  });

  testWidgets('날짜 모름에서 이관 뒤 새 역을 고르면 이어받은 노선 계통으로 저장된다', skip: _skip != null, (tester) async {
    _phone(tester);
    final (saved, summary) = await saveOnHokuriku(tester, 'n_shikibu', 'n_fukui', dateUnknown: true);
    expect(saved.dateInput, isNull);
    expect([for (final leg in saved.legs) (leg.lineId, leg.routeId, leg.fromNode, leg.toNode, leg.lineLabel)], [
      ('l_hapi_line_fukui_line', 'r_hapi_line_fukui_line', 'n_shikibu', 'n_fukui', '하피라인 후쿠이선'),
    ]);
    expect(summary.km10, 207);
  });

  testWidgets('뒤쪽 역을 먼저 누르면 그 역이 출발역, 다음에 누른 역이 도착역으로 저장된다', skip: _skip != null, (tester) async {
    _phone(tester);
    final (saved, summary) = await saveOnHokuriku(tester, 'n_fukui', 'n_shikibu', dateUnknown: true);
    expect([for (final leg in saved.legs) (leg.fromNode, leg.toNode)], [('n_fukui', 'n_shikibu')]);
    expect(summary.km10, 207);
  });






  group('한 방향 운행·정차 (DESIGN §8)', () {
    Future<(ProviderContainer, SelectorRow Function(String))> open(WidgetTester tester, String line, String route, {String? date}) async {
      final container = ProviderContainer(overrides: rig.overrides(today: '2026-11-07'));
      addTearDown(container.dispose);
      final session = container.read(recordSessionProvider.notifier);
      await tester.runAsync(() async {
        await session.open(lineId: line, routeId: route);
        if (date != null) await session.setDate(date);
      });
      SelectorRow at(String node) => container.read(recordSessionProvider).rows.firstWhere((row) => row.node == node);
      return (container, at);
    }

    testWidgets('한 방향 순환을 거꾸로 고르면 돌아가는 길로 받고 알린다', skip: _skip != null, (tester) async {
      final (container, at) = await open(tester, 'l_yukarigaoka_line', 'r_yukarigaoka_line');
      final session = container.read(recordSessionProvider.notifier);
      expect(container.read(recordSessionProvider).oneWayGaps.whereType<bool>(), isNotEmpty);
      expect(session.tap(at('n_chugakko')), isNull);
      final note = session.tap(at('n_joshidai'));
      expect(note?.kind, OneWayKind.around);
      final state = container.read(recordSessionProvider);
      // 中学校→井野→公園→女子大 = 0.8 + 0.6 + 0.9
      expect(state.preview?.meters, 2300);
      expect(state.ways, isNull);
      // 방향 바꾸기는 女子大→中学校로 바로 간다
      expect(session.reverse(note!), isNull);
      expect(container.read(recordSessionProvider).preview?.meters, 800);
    });

    testWidgets('한 방향 열차만 서는 역을 거꾸로 고르면 받지 않고, 방향 바꾸기로 뒤집는다', skip: _skip != null, (tester) async {
      final (container, at) = await open(tester, 'l_joban_line', 'r_joban_line', date: '2026-02-20');
      final session = container.read(recordSessionProvider.notifier);
      final kairakuen = at('n_kairakuen');
      expect(container.read(recordSessionProvider).stopDirections[kairakuen.seq]?.label, 'down');
      session.tap(at('n_mito'));
      final note = session.tap(kairakuen);
      expect(note?.kind, OneWayKind.stop);
      expect(note?.label, 'down');
      var state = container.read(recordSessionProvider);
      expect(state.from?.node, 'n_mito');
      expect(state.to, isNull);
      session.reverse(note!);
      state = container.read(recordSessionProvider);
      expect((state.from?.node, state.to?.node), ('n_kairakuen', 'n_mito'));
      expect(state.preview?.saved, isTrue);
    });

    testWidgets('하차전용 역은 첫 탭에서 바로 알리고 출발역으로 받지 않는다', skip: _skip != null, (tester) async {
      final (container, at) = await open(tester, 'l_joban_line', 'r_joban_line', date: '1960-03-01');
      final session = container.read(recordSessionProvider.notifier);
      final kairakuen = at('n_kairakuen');
      expect(container.read(recordSessionProvider).stopDirections[kairakuen.seq]?.use, 'alight');
      final note = session.tap(kairakuen);
      expect((note?.kind, note?.alight, note?.canReverse), (OneWayKind.stop, true, false));
      expect(container.read(recordSessionProvider).from, isNull);
      // 도착역으로는 고를 수 있다
      session.tap(at('n_akatsuka_joban'));
      expect(session.tap(kairakuen), isNull);
      expect(container.read(recordSessionProvider).preview?.saved, isTrue);
    });

    testWidgets('한 방향으로만 다니는 구간을 거꾸로 고르면 받지 않는다', skip: _skip != null, (tester) async {
      final (container, at) = await open(tester, 'l_hakodate_main_line', 'r_fujishiro_line');
      final session = container.read(recordSessionProvider.notifier);
      session.tap(at('n_onuma'));
      final note = session.tap(at('n_nanae'));
      expect(note?.kind, OneWayKind.section);
      expect(container.read(recordSessionProvider).to, isNull);
      session.reverse(note!);
      expect(container.read(recordSessionProvider).preview?.saved, isTrue);
    });
  });

  test('경로가 끝을 넘으면 그 사이만 칠한다', () {
    SelectorRow row(int seq, String node) => SelectorRow(
          seq: seq,
          node: node,
          state: StopState.open,
          selectable: true,
          isExtension: false,
          kmCum: null,
          links: const [],
        );
    final rows = [row(0, 'x'), row(1, 'y'), row(2, 'z'), row(3, 'x')];
    final wrapped = PickedPath.of(rows, const ['z', 'x']);
    expect(wrapped.below, {2});
    expect(wrapped.stops, {0, 2, 3});
    final plain = PickedPath.of(rows, const ['x', 'hidden', 'y', 'z']);
    expect(plain.below, {0, 1});
  });

  // 전수 화면 점검: 모든 계통의 세션 화면과 모든 분류의 노선 일람을 좁은 폰·큰 글자로 끝까지 내려 그리기 오류(넘침 등)가 없는지 본다.
  // 오래 걸려 FULL_RENDER=1일 때만 돈다 (`FULL_RENDER=1 flutter test test/flows_test.dart --plain-name 전수`)
  final full = Platform.environment['FULL_RENDER'] == '1' ? null : 'FULL_RENDER=1일 때만';
  // 영어는 글이 길어 칩·줄이 넘치기 쉽다. 한국어만이 아니라 세 언어 모두 좁은 폰·큰 글자로 본다 (사용자 지시 2026-11-12)
  for (final (width, scale, locale) in const [
    (390.0, 1.0, AppLocale.ko),
    (360.0, 1.3, AppLocale.ko),
    (390.0, 1.0, AppLocale.en),
    (360.0, 1.3, AppLocale.en),
    (360.0, 1.3, AppLocale.ja),
  ]) {
    testWidgets('전수: 모든 계통의 세션 화면을 끝까지 내려도 그리기 오류가 없다 (폭 $width, 글자 $scale배, ${locale.languageCode})',
        skip: _skip != null || full != null, (tester) async {
      LocaleSettings.setLocaleSync(locale);
      addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.ko));
      tester.view.physicalSize = Size(width * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final network = rig.world.network;
      final failures = <String>[];
      var screens = 0, steps = 0;
      final only = Platform.environment['FULL_RENDER_ROUTE'];
      // 한 계통만 보거나 FULL_RENDER_VERBOSE=1이면 넘친 위젯과 글을 알 수 있게 오류 내용을 모두 찍는다
      if (only != null || Platform.environment['FULL_RENDER_VERBOSE'] == '1') {
        final previous = FlutterError.onError;
        FlutterError.onError = (details) {
          // ignore: avoid_print
          print(details.toString());
          previous?.call(details);
        };
        addTearDown(() => FlutterError.onError = previous);
      }
      for (final routeId in network.routes.keys.where((r) => only == null || r == only).toList()..sort()) {
        for (final unknown in const [false, true]) {
          final container = ProviderContainer(overrides: rig.overrides(today: '2026-11-11', locale: locale));
          final session = container.read(recordSessionProvider.notifier);
          await tester.runAsync(
            () => session.open(lineId: network.routes[routeId]!.lineId, routeId: routeId, dateUnknown: unknown),
          );
          final router = _router(const Text('처음'));
          await tester.pumpWidget(_app(router, container, locale: locale));
          await _frames(tester, 2);
          unawaited(router.push<void>('/record/session?back=1'));
          await _frames(tester, 12);
          Object? error = tester.takeException();
          var leaked = _leakedId(tester);
          final list = find.byType(ListView);
          for (var step = 0; error == null && list.evaluate().isNotEmpty && step < 200; step++) {
            final scrollable = tester.state<ScrollableState>(
              find.descendant(of: list.last, matching: find.byType(Scrollable)).first,
            );
            if (scrollable.position.pixels >= scrollable.position.maxScrollExtent) break;
            await tester.drag(list.last, const Offset(0, -600), warnIfMissed: false);
            await _frames(tester, 4);
            error = tester.takeException();
            leaked ??= _leakedId(tester);
            steps++;
          }
          screens++;
          if (only != null) {
            final rows = container.read(recordSessionProvider).rows.length;
            // ignore: avoid_print
            print('$routeId 행 $rows, 내림 $steps, 보이는 줄 ${find.byType(ListView).evaluate().length}');
          }
          if (error != null) failures.add('$routeId ${unknown ? '날짜 모름' : '오늘'}: ${'$error'.split('\n').first}');
          if (leaked != null) failures.add('$routeId ${unknown ? '날짜 모름' : '오늘'}: 화면에 ID $leaked');
          await tester.pumpWidget(const SizedBox());
          container.dispose();
        }
      }
      // 세션 화면이 남긴 지연 타이머를 흘려 보낸다
      await tester.pump(const Duration(seconds: 10));
      // ignore: avoid_print
      print('세션 화면 $screens개, 내림 $steps번, 오류 ${failures.length}');
      if (only == null) expect(screens, network.routes.length * 2);
      expect(failures, isEmpty, reason: failures.take(30).join('\n'));
    }, timeout: const Timeout(Duration(hours: 2)));

    testWidgets('전수: 모든 분류·사업자의 노선 일람을 끝까지 내려도 그리기 오류가 없다 (폭 $width, 글자 $scale배, ${locale.languageCode})',
        skip: _skip != null || full != null, (tester) async {
      LocaleSettings.setLocaleSync(locale);
      addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.ko));
      if (Platform.environment['FULL_RENDER_VERBOSE'] == '1') {
        final previous = FlutterError.onError;
        FlutterError.onError = (details) {
          // ignore: avoid_print
          print(details.toString());
          previous?.call(details);
        };
        addTearDown(() => FlutterError.onError = previous);
      }
      tester.view.physicalSize = Size(width * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final network = rig.world.network;
      final failures = <String>[];
      for (final era in BrowseEra.values) {
        final tree = browseTree(network, era: era, hits: const {}, today: '2026-11-11');
        for (final category in tree.categories) {
          for (final operator in category.operators) {
            final container = ProviderContainer(
              overrides: [
                ...rig.overrides(today: '2026-11-11', locale: locale),
                unitHitsProvider.overrideWith((ref) => Stream.value(const <int, String?>{})),
              ],
            );
            await tester.pumpWidget(
              _app(
                _router(LineListScreen(era: era, category: category.category, operatorId: operator.operatorId)),
                container,
                locale: locale,
              ),
            );
            await _frames(tester, 6);
            Object? error = tester.takeException();
            var leaked = _leakedId(tester);
            final list = find.byType(Scrollable);
            for (var step = 0; error == null && list.evaluate().isNotEmpty && step < 100; step++) {
              final scrollable = tester.state<ScrollableState>(list.first);
              if (scrollable.position.pixels >= scrollable.position.maxScrollExtent) break;
              await tester.drag(list.first, const Offset(0, -600), warnIfMissed: false);
              await _frames(tester, 3);
              error = tester.takeException();
              leaked ??= _leakedId(tester);
            }
            if (error != null && failures.isEmpty) {
              // 넘친 가로 줄의 글자를 찾아 적는다
              for (final flex in tester.allRenderObjects.whereType<RenderFlex>()) {
                if (flex.direction != Axis.horizontal) continue;
                var used = 0.0;
                flex.visitChildren((child) => used += (child as RenderBox).size.width);
                if (used <= flex.size.width + 0.5) continue;
                final texts = <String>[];
                void walk(RenderObject node) {
                  if (node is RenderParagraph) texts.add(node.text.toPlainText());
                  node.visitChildren(walk);
                }
                walk(flex);
                // ignore: avoid_print
                print('넘침 ${used - flex.size.width}: ${texts.join(' | ')}');
              }
            }
            if (error != null) failures.add('${era.name} ${category.category} ${operator.operatorId}: ${'$error'.split('\n').first}');
            if (leaked != null) failures.add('${era.name} ${category.category} ${operator.operatorId}: 화면에 ID $leaked');
            await tester.pumpWidget(const SizedBox());
            container.dispose();
          }
        }
      }
      expect(failures, isEmpty, reason: failures.take(30).join('\n'));
    }, timeout: const Timeout(Duration(hours: 1)));
  }
}
