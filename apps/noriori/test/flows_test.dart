import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
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
import 'package:noriori/features/record/ui/record_edit_screen.dart';
import 'package:noriori/features/record/ui/record_session_screen.dart';
import 'package:noriori/features/record/ui/session_date.dart';
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

  List<Override> overrides({String? today}) => [
        sessionProvider.overrideWithValue(session),
        networkProvider.overrideWithValue(world.network),
        nameBookProvider.overrideWithValue(world.books[AppLocale.ko]!),
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
      final book = await PackReader(db).nameBook();
      world = PackWorld(network: network, books: {for (final locale in AppLocale.values) locale: book});
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

Widget _app(GoRouter router, ProviderContainer container) => TranslationProvider(
      child: UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: appTheme(Brightness.light),
          locale: const Locale('ko'),
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
    expect(wrapped.above, {3});
    expect(wrapped.stops, {0, 2, 3});
    final plain = PickedPath.of(rows, const ['x', 'hidden', 'y', 'z']);
    expect(plain.below, {0, 1});
    expect(plain.above, {1, 2});
  });
}
