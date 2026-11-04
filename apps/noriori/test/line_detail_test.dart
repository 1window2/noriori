import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:noriori/app/date_text.dart';
import 'package:noriori/app/session_providers.dart';
import 'package:noriori/app/theme/app_theme.dart';
import 'package:noriori/app/file_share.dart';
import 'package:noriori/features/data/controller/export_controller.dart';
import 'package:noriori/features/data/controller/news_controller.dart';
import 'package:noriori/features/record/controller/line_detail_controller.dart';
import 'package:noriori/features/record/controller/line_search_controller.dart';
import 'package:noriori/features/record/controller/record_session_controller.dart';
import 'package:noriori/features/record/controller/service_session_controller.dart';
import 'package:noriori/features/record/ui/complete_card.dart';
import 'package:noriori/features/record/ui/line_detail_screen.dart';
import 'package:noriori/features/record/ui/service_session_screen.dart';
import 'package:noriori/features/record/controller/trip_controller.dart';
import 'package:noriori/features/stats/controller/remaining_controller.dart';
import 'package:noriori/i18n/strings.g.dart';
import 'package:noriori_core/noriori_core.dart';
import 'package:noriori_store/noriori_store.dart';

// 실제 판으로 구간 끄기와 노선 상세를 돈다. 팩은 tools/sync_pack.sh로 넣는다.
final _skip = File('assets/pack/manifest.json').existsSync() ? null : '팩이 없다';

final class _FileAssets implements PackAssets {
  @override
  Future<String> manifestText() => File('assets/pack/manifest.json').readAsString();

  @override
  Future<Uint8List> fileBytes(String name) => File('assets/pack/$name').readAsBytes();
}

final class _Rig {
  _Rig(this.session, this.network, this.names);

  final AppSession session;
  final Network network;
  final NameBook names;

  Future<List<Ride>> rides() => session.records.allRides();

  String line(String name) => names.lines.entries.firstWhere((e) => e.value == name).key;

  ProviderContainer container({FileShare? share}) => ProviderContainer(
        overrides: [
          if (share != null) fileShareProvider.overrideWithValue(share),
          sessionProvider.overrideWithValue(session),
          networkProvider.overrideWithValue(network),
          nameBookProvider.overrideWithValue(names),
          editionProvider.overrideWithValue(session.pack.edition),
          todayProvider.overrideWithValue('2026-11-02'),
        ],
      );

  /// 노선의 표시 역 [a]번째에서 [b]번째까지 탄 기록.
  Ride ride(String id, String lineId, int a, int b, {String? date}) {
    final route = network.routesOfLine(lineId).firstWhere((r) => network.routes[r]!.role == 'main');
    final shown = network.stops(route).where((s) => network.isShown(s.node)).toList();
    return Ride(
      rideId: RideId(id),
      legs: [
        RideLeg(
          seq: 0,
          lineId: LineId(lineId),
          routeId: RouteId(route),
          fromNode: NodeId(shown[a].node),
          toNode: NodeId(shown[b].node),
          lineLabel: '노선',
          fromLabel: '가',
          toLabel: '나',
        ),
      ],
      datasetVersion: session.pack.edition,
      createdAt: 1000,
      updatedAt: 1000,
      deviceId: 'd',
      dateInput: date,
      note: '메모',
    );
  }
}

Future<_Rig> _open() async {
  final dir = Directory.systemTemp.createTempSync('line');
  Network? network;
  NameBook? names;
  final outcome = await ColdStart(
    paths: StorePaths(dir),
    assets: _FileAssets(),
    appBuild: 1,
    supportedPackSchema: supportedPackSchema,
    connect: openDirect,
    interpreter: (db) async {
      network = Network(await NetworkReader(db).read());
      names = await PackReader(db).nameBook();
      return RideInterpreter(network!);
    },
    now: () => DateTime.now().millisecondsSinceEpoch,
  ).run();
  return _Rig((outcome as StartReady).session, network!, names!);
}

Widget _app(ProviderContainer container, String lineId) => TranslationProvider(
      child: UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: appTheme(Brightness.light),
          locale: const Locale('ko'),
          supportedLocales: AppLocaleUtils.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          routerConfig: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (context, state) => LineDetailScreen(lineId: lineId)),
            ],
          ),
        ),
      ),
    );

Future<void> _frames(WidgetTester tester, [int count = 20]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

RideDerived interpreter(Network network, List<RideLeg> legs) => RideInterpreter(network).ride(
      Ride(
        rideId: const RideId('p'),
        legs: legs,
        datasetVersion: '',
        createdAt: 0,
        updatedAt: 0,
        deviceId: '',
      ),
    );

final class _FakeShare implements FileShare {
  String name = '';
  Uint8List bytes = Uint8List(0);

  @override
  Future<void> share(String name, Uint8List bytes) async {
    this.name = name;
    this.bytes = bytes;
  }
}

final class _NoFolder implements BackupFolder {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Rig rig;

  setUpAll(() async {
    if (_skip == null) rig = await _open();
  });

  test('세 언어 모두 문구를 동기로 읽어 앱이 시작된다', () {
    // main()이 runApp 전에 부른다. 지연 로딩이면 여기서 죽어 첫 화면이 나오지 않는다
    addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.ko));
    LocaleSettings.setLocaleSync(AppLocale.en);
    expect(t.tabs.map, 'Map');
    expect(t.session.stops(n: 1), '1 station');
    expect(t.session.stops(n: 2), '2 stations');
    expect(t.importing.missed(n: 1, count: '1'), '1 row with no matching line');
    expect(dateText(t, '2026-11-02'), 'Nov 2, 2026');
    expect(dateText(t, '2026-11-XX'), 'Nov 2026');
    LocaleSettings.setLocaleSync(AppLocale.ja);
    expect(t.tabs.map, '地図');
    expect(dateText(t, '2026-11-02'), '2026.11.2');
    expect(t.prefNames.length, 47);
    expect(nameLanguages(AppLocale.en), PackReader.englishFirst);
    expect(nameLanguages(AppLocale.ja).first, 'ja');
  });

  test('기기 언어가 셋 중 하나가 아니면 영어다', () {
    expect(deviceLanguage('ko'), AppLocale.ko);
    expect(deviceLanguage('ja'), AppLocale.ja);
    expect(deviceLanguage('fr'), AppLocale.en);
  });

  test('실제 판의 무작위 기록을 잘라도 조각이 같은 경로와 날짜로 펼쳐진다', skip: _skip, () {
    final random = math.Random(11);
    final network = rig.network;
    final interpreter = RideInterpreter(network);
    final routes = [
      for (final route in network.routes.values)
        if (network.stops(route.id).where((s) => network.isShown(s.node)).length >= 4) route,
    ];
    var ok = 0;
    var skipped = 0;
    final blocked = <String, int>{};
    for (var i = 0; i < 4000; i++) {
      final route = routes[random.nextInt(routes.length)];
      final stops = network.stops(route.id).where((s) => network.isShown(s.node)).toList();
      final picks = [random.nextInt(stops.length), random.nextInt(stops.length)]..sort();
      if (picks[0] == picks[1]) {
        skipped++;
        continue;
      }
      final ride = Ride(
        rideId: RideId('r$i'),
        legs: [
          RideLeg(
            seq: 0,
            lineId: LineId(route.lineId),
            routeId: RouteId(route.id),
            fromNode: NodeId(stops[picks[0]].node),
            toNode: NodeId(stops[picks[1]].node),
            direction: route.closed ? (random.nextBool() ? seqUp : seqDown) : null,
            lineLabel: 'l',
            fromLabel: 'a',
            toLabel: 'b',
          ),
        ],
        datasetVersion: 'v',
        createdAt: 1,
        updatedAt: 1,
        deviceId: 'd',
        dateInput: random.nextBool() ? '2024-05-05' : null,
      );
      final derived = interpreter.ride(ride);
      if (derived.status != ResolveStatus.ok || derived.edges.length < 3) {
        skipped++;
        continue;
      }
      final hit = derived.edges[random.nextInt(derived.edges.length)];
      var next = 0;
      final outcome = cutSection(
        ride,
        network,
        offUnits: {hit.unitOn},
        carryover: true,
        nameOf: (node) => node,
        newId: () => 'n${next++}',
        now: 5,
      );
      switch (outcome) {
        case CutMissed():
          skipped++;
        case CutBlocked(:final reason):
          blocked[reason.name] = (blocked[reason.name] ?? 0) + 1;
        case CutDone(:final after):
          final all = <int>[];
          for (final piece in after) {
            all.addAll(interpreter.ride(piece).edges.map((e) => e.edge));
          }
          expect(all..sort(), [for (final e in derived.edges) e.edge]..sort());
          ok++;
      }
    }
    // ignore: avoid_print
    print('구간 끄기: 일치 $ok, 막힘 $blocked, 건너뜀 $skipped');
    expect(blocked[CutBlock.changesPath.name] ?? 0, 0);
    expect(ok, greaterThan(1500));
  });

  test('모든 노선의 노선도가 표시 역 사이 구간을 빠짐없이 만든다', skip: _skip, () {
    final network = rig.network;
    var empty = 0;
    var lost = 0;
    final lostNames = <String>[];
    for (final lineId in {for (final route in network.routes.values) route.lineId}) {
      final diagram = lineDiagram(network, lineId, hits: const {}, today: '2026-11-02');
      final drawn = {
        for (final route in diagram.routes)
          for (final section in route.sections) ...section.edges,
      };
      for (final route in diagram.routes) {
        if (route.sections.every((s) => s.edges.isEmpty)) empty++;
        expect(route.sections.length, route.stops.length - 1);
        for (final hop in network.hops(route.routeId)) {
          if (!drawn.contains(hop.edge)) {
            lost++;
            if (lost <= 12) lostNames.add('$lineId/${route.routeId}/${hop.edge}');
          }
        }
      }
    }
    // ignore: avoid_print
    print('노선도: 빈 계통 $empty, 그리지 못한 구간 $lost $lostNames');
    expect(empty, 0);
  });

  test('연도나 연대만 아는 날짜도 운전 계통은 질문 없이 펼쳐진다', skip: _skip, () {
    final network = rig.network;
    final splitter = ServiceSplitter(network);
    final interpreter = RideInterpreter(network);
    final asked = <String>{};
    var tried = 0;
    for (final raw in const ['197X-XX-XX', '198X-XX-XX', '199X-XX-XX', '200X-XX-XX', '201X-XX-XX', '1990-XX-XX', '2005-XX-XX', '2015-XX-XX']) {
      final date = DateSpan.parse(raw);
      for (final service in network.data.services) {
        final stops = splitter.stops(service, date);
        for (var a = 0; a < stops.length; a += 3) {
          for (var b = 0; b < stops.length; b += 4) {
            if (stops[a].node == stops[b].node) continue;
            for (final up in service.closed ? const [true, false] : const [true]) {
              final legs = splitter.legs(service, stops, stops[a], stops[b],
                  date: date, up: up, lineName: (id) => id, nodeName: (node) => node);
              if (legs == null) continue;
              tried++;
              for (final expansion in interpreter.expansions(Ride(
                rideId: const RideId('s'),
                legs: legs,
                datasetVersion: 'v',
                createdAt: 1,
                updatedAt: 1,
                deviceId: 'd',
                dateInput: raw,
              ))) {
                if (expansion.status == ResolveStatus.needsInput) asked.add('$raw ${service.id} ${expansion.reason}');
              }
            }
          }
        }
      }
    }
    // ignore: avoid_print
    print('운전 계통 날짜 범위: $tried조합, 질문 필요 ${asked.length} ${asked.take(10)}');
    expect(asked, isEmpty, reason: '이설 질문이 필요해지면 저장 화면에 답을 넣어야 한다');
  });

  test('운전 계통은 어느 두 역을 골라도 공식 구간으로 나뉘어 펼쳐진다', skip: _skip, () {
    final network = rig.network;
    final splitter = ServiceSplitter(network);
    final interpreter = RideInterpreter(network);
    final bad = <String>[];
    var ok = 0;
    for (final service in network.data.services) {
      final stops = splitter.stops(service, null);
      expect(stops.length, greaterThan(2), reason: service.id);
      for (var a = 0; a < stops.length; a += 3) {
        for (var b = 0; b < stops.length; b += 4) {
          if (stops[a].node == stops[b].node) continue;
          for (final up in service.closed ? const [true, false] : const [true]) {
            final legs = splitter.legs(
              service,
              stops,
              stops[a],
              stops[b],
              date: null,
              up: up,
              lineName: (id) => id,
              nodeName: (node) => node,
            );
            final ride = legs == null
                ? null
                : splitter.ride(
                    service,
                    legs,
                    id: const RideId('s'),
                    dateInput: null,
                    datasetVersion: 'v',
                    deviceId: 'd',
                    now: 1,
                  );
            if (ride == null) {
              if (bad.length < 12) bad.add('${service.id} ${stops[a].node}~${stops[b].node}');
              continue;
            }
            expect(interpreter.ride(ride).edges, isNotEmpty);
            ok++;
          }
        }
      }
    }
    // ignore: avoid_print
    print('운전 계통: 일치 $ok, 실패 ${bad.length} $bad');
    expect(bad, isEmpty);
  });

  test('츄오 쾌속선 도쿄~신주쿠는 명세의 세 노선으로 나뉜다', skip: _skip, () {
    final network = rig.network;
    final splitter = ServiceSplitter(network);
    final service = network.data.services.firstWhere((s) => s.id == 's_chuo_rapid');
    final stops = splitter.stops(service, null);
    final legs = splitter.legs(
      service,
      stops,
      stops.firstWhere((s) => s.node == 'n_tokyo'),
      stops.firstWhere((s) => s.node == 'n_shinjuku'),
      date: null,
      lineName: (id) => id,
      nodeName: (node) => node,
    )!;
    expect([for (final leg in legs) leg.routeId.value], [
      'r_tohoku_main_line',
      'r_chuo_main_line_kanda_yoyogi',
      'r_yamanote_line',
    ]);
    final rows = summarizeLegs(interpreter(network, legs));
    expect([for (final row in rows) row.km10], [13, 83, 7]);
  });

  testWidgets('운전 계통을 검색해서 두 역을 고르면 분해를 보여 주고 공식 구간으로 저장한다', skip: _skip != null, (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = rig.container();
    addTearDown(container.dispose);
    final hits = await tester.runAsync(() => container.read(lineSearchProvider('츄오 쾌속').future));
    expect(hits!.where((row) => row.serviceId == 's_chuo_rapid'), isNotEmpty);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const Scaffold(body: Text('처음'))),
        GoRoute(
          path: '/service',
          builder: (context, state) => const ServiceSessionScreen(serviceId: 's_chuo_rapid'),
        ),
      ],
    );
    await tester.pumpWidget(
      TranslationProvider(
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
      ),
    );
    await _frames(tester, 3);
    unawaited(router.push<void>('/service'));
    await _frames(tester, 10);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await _frames(tester, 10);
    final notifier = container.read(serviceSessionProvider.notifier);
    final stops = container.read(serviceSessionProvider).stops;
    notifier
      ..tap(stops.firstWhere((s) => s.node == 'n_tokyo'))
      ..tap(stops.firstWhere((s) => s.node == 'n_shinjuku'));
    await _frames(tester, 3);
    final state = container.read(serviceSessionProvider);
    expect(state.covers(0), isTrue);
    expect(state.passes('n_kanda_chuo_main'), isTrue);
    expect(state.passes('n_takao'), isFalse);
    expect(find.textContaining('1.3km'), findsOneWidget);
    expect(find.textContaining('8.3km'), findsOneWidget);
    await tester.tap(find.text('기록하기'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await _frames(tester, 10);
    final live = (await tester.runAsync(rig.rides))!.where((r) => !r.isDeleted).toList();
    final ride = live.singleWhere((r) => r.serviceId?.value == 's_chuo_rapid');
    expect(ride.legs.length, 3);
    await tester.runAsync(
      () => rig.session.records.apply(Change(before: [ride], after: [ride.withDeletedAt(9999999)])),
    );
  });

  test('앱의 폐선 구간 판정이 타일의 closed 값과 같다', skip: _skip, () async {
    final rows = await rig.session.db.customSelect(
      "SELECT n FROM master.edge WHERE id NOT IN "
      "(SELECT edge_id FROM master.edge_life WHERE valid_to = 'ongoing')",
    ).get();
    expect(rig.network.closedEdges, {for (final row in rows) row.read<int>('n')});
  });

  testWidgets('여정은 고른 기록을 묶고 풀어도 기록은 남으며 되돌릴 수 있다', (tester) async {
    final container = rig.container();
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      await container.read(deviceIdProvider.future);
      final lineId = rig.line('야마노테선');
      final a = rig.ride('trip-a', lineId, 0, 2);
      final b = rig.ride('trip-b', lineId, 3, 5);
      final records = rig.session.records;
      await records.apply(Change(before: const [], after: [a, b]));
      final commands = container.read(tripCommandsProvider);
      await commands.make('간사이 여행', [a.rideId, b.rideId]);
      final queries = container.read(recordQueriesProvider);
      final trips = await queries.watchTrips().first;
      final trip = trips.singleWhere((item) => item.title == '간사이 여행');
      expect(trip.rides, 2);
      expect(trip.km10, greaterThan(0));
      await commands.rename(trip.tripId, '오사카 여행');
      expect((await queries.watchTrips().first).single.title, '오사카 여행');
      final change = (await commands.dissolve(trip.tripId))!;
      expect(await queries.watchTrips().first, isEmpty);
      expect((await records.ride(a.rideId))!.tripId, isNull);
      expect((await records.ride(a.rideId))!.deletedAt, isNull);
      await commands.undo(change);
      expect((await queries.watchTrips().first).single.rides, 2);
      expect((await records.ride(b.rideId))!.tripId, trip.tripId);
      final now = await records.ride(a.rideId);
      final other = await records.ride(b.rideId);
      final kept = await records.trip(trip.tripId);
      await records.apply(Change(before: [?now, ?other, ?kept], after: [
        now!.withDeletedAt(99999999),
        other!.withDeletedAt(99999999),
        kept!.withDeletedAt(99999999),
      ]));
    });
  }, skip: _skip != null);

  testWidgets('처음 완주하면 축하 카드가 뜨고 카드 이미지를 공유한다', (tester) async {
    final shared = _FakeShare();
    final container = rig.container(share: shared);
    addTearDown(container.dispose);
    const score = Score(numMeters: 6600, denMeters: 6600, numUnits: 8, denUnits: 8);
    const partly = Score(numMeters: 3000, denMeters: 6600, numUnits: 3, denUnits: 8);
    const data = RideTicketData(
      lineName: '쇼난 모노레일',
      fromName: 'a',
      toName: 'b',
      dateInput: '2026-11-03',
      meters: 3600,
      before: partly,
      after: score,
    );
    expect(data.completed, isTrue);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TranslationProvider(
          child: MaterialApp(
            theme: appTheme(Brightness.light),
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => showCompleteCard(context, data),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text('쇼난 모노레일'), findsOneWidget);
    expect(find.textContaining('6.6 km'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('공유하기'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    expect(shared.name, endsWith('.png'));
    expect(shared.bytes.take(4), [0x89, 0x50, 0x4E, 0x47]);
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(find.text('쇼난 모노레일'), findsNothing);
  }, skip: _skip != null);

  testWidgets('남은 구간은 현재 노선 전체를 계산하고 폐지 구간은 뺀다', (tester) async {
    final container = rig.container();
    addTearDown(container.dispose);
    final watch = Stopwatch()..start();
    final data = (await tester.runAsync(() async {
      final keep = container.listen(remainingProvider, (_, _) {});
      final value = await container.read(remainingProvider.future);
      keep.close();
      return value;
    }))!;
    // ignore: avoid_print
    print('남은 구간: ${data.all.length}구간 ${watch.elapsedMilliseconds}ms');
    expect(data.all, isNotEmpty);
    final gone = rig.network.closedEdges;
    for (final section in data.all.take(200)) {
      final diagram = lineDiagram(rig.network, section.lineId, hits: const {}, today: '2026-11-02');
      expect(diagram.routes, isNotEmpty);
    }
    expect(gone, isNotEmpty);
    final near = nearbySections(data.all, positions: data.positions, lat: 35.466, lon: 139.622);
    expect(near, isNotEmpty);
    expect(near.last.$2, lessThanOrEqualTo(nearbyKm));
  }, skip: _skip != null);

  test('변경 소식은 신설과 폐지를 모으고 키는 판이 바뀌어도 같다', skip: _skip, () {
    final items = networkNews(rig.network, '2026-11-02');
    expect(items.map((item) => item.kind).toSet(), NewsKind.values.toSet());
    expect(items.every((item) => item.date.compareTo('2026-11-02') <= 0), isTrue);
    expect(items.first.date.compareTo(items.last.date), greaterThanOrEqualTo(0));
    final later = networkNews(rig.network, '2030-01-01');
    expect(later.length, greaterThanOrEqualTo(items.length));
    expect(items.map((item) => item.key).toSet().length, items.length);
    expect(newsHash('abc'), newsHash('abc'));
    // ignore: avoid_print
    print('변경 소식: ${items.length}건 예: ${items.take(3).map((i) => i.key)}');
  });

  testWidgets('처음 켜면 소식을 띄우지 않고 새 소식만 한 번 보여 준다', (tester) async {
    final container = rig.container();
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      final store = SettingStore(rig.session.db);
      await store.delete('news_seen');
      final first = await container.read(unseenNewsProvider.future);
      expect(first.items, isEmpty);
      final raw = (await store.read('news_seen'))!;
      expect(raw, isNotEmpty);
      container.invalidate(unseenNewsProvider);
      expect((await container.read(unseenNewsProvider.future)).items, isEmpty);
      final hashes = raw.split(',');
      await store.write('news_seen', hashes.skip(1).join(','));
      container.invalidate(unseenNewsProvider);
      expect((await container.read(unseenNewsProvider.future)).items.length, 1);
      await store.delete('news_seen');
    });
  }, skip: _skip != null);

  test('두 역을 노선을 넘어 잇고 구간마다 재해석된다', skip: _skip, () {
    final network = rig.network;
    final interpreter = RideInterpreter(network);
    final stops = [
      for (final route in network.routes.values)
        if (route.role == 'main')
          ...network.stops(route.id).where((stop) => stop.isStop && network.isShown(stop.node)).map((stop) => stop.node),
    ].toList();
    final random = math.Random(7);
    final day = DateSpan.parse('2026-11-02');
    var found = 0;
    final watch = Stopwatch()..start();
    for (var run = 0; run < 60; run++) {
      final a = stops[random.nextInt(stops.length)];
      final b = stops[random.nextInt(stops.length)];
      if (a == b) continue;
      final journey = findJourney(network, a, b, date: day, today: '2026-11-02');
      if (journey == null) continue;
      found++;
      for (final leg in journey.legs) {
        expect(leg.from, isNot(leg.to));
        final ride = Ride(
          rideId: const RideId('j'),
          datasetVersion: 'v',
          createdAt: 1,
          updatedAt: 1,
          deviceId: 'd',
          dateInput: '2026-11-02',
          legs: [
            RideLeg(
              seq: 0,
              lineId: LineId(leg.lineId),
              routeId: RouteId(leg.routeId),
              fromNode: NodeId(leg.from),
              toNode: NodeId(leg.to),
              direction: network.routes[leg.routeId]!.closed
                  ? RouteResolver(network).record(leg.routeId, leg.from, leg.to, date: day).direction
                  : null,
              lineLabel: '',
              fromLabel: '',
              toLabel: '',
            ),
          ],
        );
        final status = interpreter.ride(ride).status;
        expect(status, anyOf(ResolveStatus.ok, ResolveStatus.needsInput), reason: '${leg.routeId} ${leg.from} ${leg.to}');
      }
    }
    // ignore: avoid_print
    print('경로 찾기: 60회 중 $found개 ${watch.elapsedMilliseconds}ms');
    expect(found, greaterThan(30));
  });

  test('판이 바뀌어 기록이 달라지면 변경 내역을 남긴다', skip: _skip, () async {
    final lineId = rig.line('야마노테선');
    final ride = rig.ride('report', lineId, 0, 3);
    final records = rig.session.records;
    await records.apply(Change(before: const [], after: [ride]));
    final db = rig.session.db;
    await db.customStatement('UPDATE ride_cache SET km10 = 1 WHERE ride_id = ?', [ride.rideId.value]);
    final state = (await db.select(db.cacheStateTable).get()).single;
    final rebuild = CacheRebuild(db, records);
    await rebuild.runIfStale(edition: 'test-next', appBuild: state.appBuild);
    final queries = RecordQueries(db);
    final report = (await queries.watchChangeReports().first).first;
    expect(report.edition, 'test-next');
    final change = report.changes.single;
    expect(change.before, 1);
    expect(change.after, greaterThan(1));
    expect(change.statusChanged, isFalse);
    await db.customStatement("DELETE FROM change_report WHERE edition = 'test-next'");
    await rebuild.runIfStale(edition: state.edition, appBuild: state.appBuild);
    await records.apply(Change(before: [ride], after: [ride.withDeletedAt(99999999)]));
  });

  test('백업 폴더 없이 공유로 내보내고 그 파일로 복원한다', skip: _skip, () async {
    final shared = _FakeShare();
    final container = rig.container(share: shared);
    addTearDown(container.dispose);
    final lineId = rig.line('야마노테선');
    final ride = rig.ride('share', lineId, 0, 3);
    await rig.session.records.apply(Change(before: const [], after: [ride]));
    final commands = container.read(exportCommandsProvider);
    await commands.export(ExportKind.compat);
    expect(shared.name, endsWith('.csv'));
    expect(shared.bytes, isNotEmpty);
    await commands.export(ExportKind.full);
    expect(shared.name, contains('full'));
    await commands.exportBackup();
    expect(shared.name, startsWith(BackupHeader.namePrefix));
    final text = utf8.decode(shared.bytes);
    await rig.session.records.apply(Change(before: [ride], after: [ride.withDeletedAt(99999999)]));
    final restore = BackupRestore(folder: _NoFolder(), records: rig.session.records);
    expect(await restore.mergeText(shared.name, text), isA<RestoreMerged>());
    final refused = await restore.mergeText('other.json', '{}');
    expect(refused, isA<RestoreRefused>());
    final back = await rig.session.records.ride(ride.rideId);
    await rig.session.records.apply(Change(before: [?back], after: [ride.withDeletedAt(99999999)]));
  });

  test('승계를 끄면 JR 시절 기록이 넘어간 노선을 채우지 않는다', skip: _skip, () {
    final network = rig.network;
    final byEdge = <String, List<NetAttr>>{};
    for (final attr in network.data.attrs) {
      (byEdge[attr.edgeId] ??= []).add(attr);
    }
    const today = '2026-11-02';
    var checked = 0;
    for (final MapEntry(key: edge, value: attrs) in byEdge.entries) {
      final split = [
        for (final attr in attrs)
          for (final other in attrs)
            if (attr.lineageId == other.lineageId &&
                attr.carryoverGroup != other.carryoverGroup &&
                other.period.toHi == DateSpan.maxDate)
              (attr, other),
      ];
      if (split.isEmpty) continue;
      final (old, now) = split.first;
      final on = network.unitOf(old.lineId, edge, carryover: true);
      final off = network.unitOf(old.lineId, edge, carryover: false);
      if (on == null || off == null || !on.normal) continue;
      Score? line({required bool carryover, required int unit}) => scoreTable(
            network,
            hits: {unit: null},
            basis: const BasisCurrent(),
            carryover: carryover,
            today: today,
          ).byLine[now.lineId];
      expect(line(carryover: true, unit: on.n)?.numUnits ?? 0, greaterThan(0), reason: edge);
      expect(line(carryover: false, unit: off.n)?.numUnits ?? 0, 0, reason: edge);
      if (++checked >= 40) break;
    }
    expect(checked, 40);
  });

  testWidgets('지선 역에서 칩을 바꿔 본선 역을 고르면 분기역에서 나눠 저장한다', (tester) async {
    final network = rig.network;
    var tried = 0;
    final interpreter = RideInterpreter(network);
    for (final branch in network.routes.values.where((r) => r.role != 'main')) {
      final routes = network.routesOfLine(branch.lineId);
      final main = routes.firstWhere((id) => network.routes[id]!.role == 'main', orElse: () => '');
      if (main.isEmpty) continue;
      final onMain = {for (final stop in network.stops(main)) stop.node};
      final onBranch = network.stops(branch.id).where((s) => network.isShown(s.node)).toList();
      if (onBranch.every((s) => onMain.contains(s.node))) continue;
      final container = rig.container();
      addTearDown(container.dispose);
      final session = container.read(recordSessionProvider.notifier);
      await tester.runAsync(
        () => session.open(lineId: branch.lineId, routeId: branch.id, dateUnknown: true),
      );
      final start = container.read(recordSessionProvider).rows
          .where((row) => row.selectable && !onMain.contains(row.node))
          .firstOrNull;
      if (start == null) continue;
      session.tap(start);
      await tester.runAsync(() => session.selectRoute(main));
      final state = container.read(recordSessionProvider);
      expect(state.from?.node, start.node, reason: '칩을 바꿔도 출발역이 남는다');
      final end = state.rows.where((row) => row.selectable).toList();
      if (end.isEmpty) continue;
      session.tap(end.last);
      final preview = container.read(recordSessionProvider).preview;
      if (preview == null || !preview.saved) continue;
      // 본선과 겹치는 계통은 한 구간으로 끝날 수 있다
      final outcome = await tester.runAsync(session.save);
      final done = outcome! as SaveDone;
      final ride = done.change.after.single as Ride;
      expect(ride.legs.length, preview.legs.length, reason: branch.id);
      expect(interpreter.ride(ride).status, ResolveStatus.ok, reason: branch.id);
      expect((interpreter.ride(ride).km10 ?? 0) * 100, closeTo(preview.meters!, 100), reason: branch.id);
      await tester.runAsync(
        () => rig.session.records.apply(Change(before: [ride], after: [ride.withDeletedAt(9999999)])),
      );
      if (preview.legs.length > 1) tried++;
    }
    // ignore: avoid_print
    print('계통 넘기: $tried개 지선');
    expect(tried, greaterThan(20));
  }, skip: _skip != null);

  testWidgets('닫힌 계통은 맨 위와 맨 아래 같은 역을 고르면 한 바퀴이고 끝 줄이 돌아옴이다', (tester) async {
    for (final route in rig.network.routes.values.where((r) => r.closed)) {
      final container = rig.container();
      addTearDown(container.dispose);
      final session = container.read(recordSessionProvider.notifier);
      await tester.runAsync(
        () => session.open(lineId: route.lineId, routeId: route.id, dateUnknown: true),
      );
      final state = container.read(recordSessionProvider);
      final rows = state.rows.where((row) => row.selectable).toList();
      final pairs = [
        for (final (at, row) in rows.indexed)
          for (final later in rows.skip(at + 1))
            if (later.node == row.node) (row, later),
      ];
      expect(pairs, isNotEmpty, reason: route.id);
      final (top, bottom) = pairs.first;
      session
        ..tap(top)
        ..tap(bottom);
      final picked = container.read(recordSessionProvider);
      expect(picked.isLap, isTrue, reason: route.id);
      expect(picked.ridePreview, isNotNull, reason: '${route.id} 한 바퀴를 저장할 수 있어야 한다');
      final lines = picked.lines.whereType<StopLine>();
      expect(lines.where((line) => line.returnsTo != null), isNotEmpty, reason: route.id);
    }
  }, skip: _skip != null);

  testWidgets('역 선택기에서 두 바퀴를 저장하면 실패로 보이지 않고 한 건만 남는다', skip: _skip != null, (tester) async {
    final container = rig.container();
    addTearDown(container.dispose);
    final network = rig.network;
    final route = network.routes.values.firstWhere((r) => r.closed);
    final session = container.read(recordSessionProvider.notifier);
    await tester.runAsync(
      () => session.open(lineId: route.lineId, routeId: route.id, dateUnknown: true),
    );
    final row = container.read(recordSessionProvider).rows.firstWhere((r) => r.selectable);
    session.tap(row);
    session.pickLap();
    session.setLaps(2);
    final outcome = (await tester.runAsync(session.save))!;
    expect(outcome, isA<SaveDone>());
    final done = outcome as SaveDone;
    final ride = done.change.after.single as Ride;
    expect(ride.legs.length, 2);
    final one = RideInterpreter(network).ride(ride).km10!;
    expect(done.ticket.meters, closeTo(one * 100, 100));
    await tester.runAsync(
      () => rig.session.records.apply(Change(before: [ride], after: [ride.withDeletedAt(9999999)])),
    );
  });

  testWidgets('운전 계통 고리는 짧은 쪽이 기본이고 한 바퀴와 횟수를 저장하며 없던 날은 못 고른다', skip: _skip != null, (tester) async {
    final container = rig.container();
    addTearDown(container.dispose);
    final sub = container.listen(serviceSessionProvider, (_, _) {});
    addTearDown(sub.close);
    final notifier = container.read(serviceSessionProvider.notifier);
    await tester.runAsync(() => notifier.open('s_yamanote_loop'));
    final stops = container.read(serviceSessionProvider).stops;
    final tokyo = stops.firstWhere((s) => s.node == 'n_tokyo');
    final kanda = stops.firstWhere((s) => s.node == 'n_kanda_chuo_main');
    notifier
      ..tap(tokyo)
      ..tap(kanda);
    var state = container.read(serviceSessionProvider);
    expect(state.ways, isNotNull);
    expect(state.meters, lessThan(3000), reason: '기본은 짧은 쪽이다');
    notifier.setUp(!(state.up ?? true));
    state = container.read(serviceSessionProvider);
    expect(state.meters, greaterThan(30000));
    notifier
      ..clear()
      ..tap(tokyo);
    expect(notifier.asksLap(tokyo), isTrue);
    notifier
      ..pickLap()
      ..setLaps(2);
    state = container.read(serviceSessionProvider);
    final once = state.legs!.length ~/ 2;
    expect(once, greaterThanOrEqualTo(3));
    expect((state.meters! / 1000).round(), closeTo(69, 2), reason: '일주 34.5km를 두 번');
    final saved = (await tester.runAsync(notifier.save))! as ServiceSaved;
    final ride = saved.change.after.single as Ride;
    expect(ride.serviceId?.value, 's_yamanote_loop');
    await tester.runAsync(
      () => rig.session.records.apply(Change(before: [ride], after: [ride.withDeletedAt(9999999)])),
    );
    await tester.runAsync(() => notifier.open('s_ueno_tokyo'));
    notifier.setDate('2000-01-01');
    state = container.read(serviceSessionProvider);
    expect(state.open, isEmpty, reason: '2015년 개통 전이다');
    notifier.tap(state.stops.first);
    expect(container.read(serviceSessionProvider).from, isNull);
    // 고른 구간을 그날 탈 수 없으면 날짜를 바꾸지 않는다. 고른 역과 원래 날짜는 그대로다 (DESIGN §8.0.1)
    notifier.setDate(null);
    state = container.read(serviceSessionProvider);
    notifier
      ..tap(state.stops.first)
      ..tap(state.stops.last);
    final picked = container.read(serviceSessionProvider);
    expect(picked.legs, isNotNull);
    expect(notifier.setDate('2000-01-01'), isTrue);
    state = container.read(serviceSessionProvider);
    expect(state.dateInput, isNull);
    expect(state.from?.node, picked.from?.node);
    expect(state.to?.node, picked.to?.node);
    expect(state.legs, isNotNull);
    // 기준일 이전은 기록 범위 밖이라 받고, 날짜 모름처럼 모든 역을 고를 수 있다
    expect(notifier.setDate('1949-05-05'), isFalse);
    state = container.read(serviceSessionProvider);
    expect(state.dateInput, '1949-05-05');
    expect(state.to?.node, picked.to?.node);
  });

  testWidgets('분기로 넘어가면 고른 역이 지워지고 뒤로 가면 직전 노선으로 돌아온다', skip: _skip != null, (tester) async {
    final container = rig.container();
    addTearDown(container.dispose);
    final session = container.read(recordSessionProvider.notifier);
    final start = rig.line('소야 본선');
    await tester.runAsync(() => session.open(lineId: start, dateUnknown: true));
    var state = container.read(recordSessionProvider);
    final branch = state.lines.whereType<BranchLine>().firstWhere((b) => session.canOpen(b.item.link.otherLineId));
    final route = state.routeId;
    session.tap(state.rows.firstWhere((r) => r.selectable));
    await tester.runAsync(() => session.jumpTo(branch.item.link, branch.at));
    state = container.read(recordSessionProvider);
    expect(state.lineId, branch.item.link.otherLineId);
    expect(state.from, isNull, reason: '고른 역은 넘어가며 지워진다');
    expect(state.depth, 1);
    expect(state.rows.any((r) => r.seq == state.focus && r.node == branch.at.node), isTrue);
    expect(await tester.runAsync(session.jumpBack), isTrue);
    state = container.read(recordSessionProvider);
    expect((state.lineId, state.routeId), (start, route));
    expect(state.depth, 0);
    expect(await tester.runAsync(session.jumpBack), isFalse, reason: '더 돌아갈 곳이 없으면 화면을 닫는다');
  });

  test('두 바퀴 기록은 같은 구간을 두 번 지나도 저장된다', skip: _skip, () async {
    final network = rig.network;
    final route = network.routes.values.firstWhere((r) => r.closed);
    final start = network.stops(route.id).firstWhere((s) => network.isShown(s.node)).node;
    RideLeg lap(int seq) => RideLeg(
          seq: seq,
          lineId: LineId(route.lineId),
          routeId: RouteId(route.id),
          fromNode: NodeId(start),
          toNode: NodeId(start),
          direction: seqUp,
          lineLabel: 'l',
          fromLabel: 'a',
          toLabel: 'a',
        );
    final ride = Ride(
      rideId: const RideId('laps'),
      legs: [lap(0), lap(1)],
      datasetVersion: rig.session.pack.edition,
      createdAt: 5,
      updatedAt: 5,
      deviceId: 'd',
    );
    final one = RideInterpreter(network).ride(
      Ride(
        rideId: const RideId('one'),
        legs: [lap(0)],
        datasetVersion: 'v',
        createdAt: 5,
        updatedAt: 5,
        deviceId: 'd',
      ),
    );
    final two = RideInterpreter(network).ride(ride);
    expect(two.km10, one.km10! * 2);
    await rig.session.records.apply(Change(before: const [], after: [ride]));
    await rig.session.records.apply(Change(before: [ride], after: [ride.withDeletedAt(9999999)]));
  });

  group('노선 상세', () {
    late String lineId;

    setUp(() => lineId = rig.line('난부선'));

    Future<ProviderContainer> show(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final container = rig.container();
      addTearDown(container.dispose);
      await tester.pumpWidget(_app(container, lineId));
      await tester.runAsync(() => container.read(lineStopNamesProvider(lineId).future));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await _frames(tester, 10);
      return container;
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
      await _frames(tester, 10);
    }

    tearDown(() async {
      final live = await rig.rides();
      await rig.session.records.apply(
        Change(before: live, after: [for (final r in live) r.withDeletedAt(9999999)]),
      );
    });

    testWidgets('구간을 누르면 기록이 잘리고 되돌리기로 돌아온다', skip: _skip != null, (tester) async {
      await tester.runAsync(
        () => rig.session.records.apply(
          Change(before: const [], after: [rig.ride('whole', lineId, 0, 4, date: '2024-05-05')]),
        ),
      );
      final container = await show(tester);
      await settle(tester);
      final diagram = container.read(lineDiagramProvider(lineId)).value!;
      expect(diagram.routes.first.sections.take(4).every((s) => s.ridden), isTrue);
      await tester.tap(find.byType(InkWell).at(2 + 1));
      await settle(tester);
      final after = (await tester.runAsync(rig.rides))!;
      final live = [for (final r in after) if (!r.isDeleted) r];
      expect(live.length, greaterThanOrEqualTo(1));
      expect(after.where((r) => r.rideId.value == 'whole').single.dateInput, '2024-05-05');
      for (final piece in live) {
        expect(piece.dateInput, '2024-05-05');
        expect(piece.note, '메모');
      }
      expect(find.textContaining('기록 1건을 고쳤습니다'), findsOneWidget);
      await tester.tap(find.text('되돌리기'));
      await settle(tester);
      final back = (await tester.runAsync(rig.rides))!.where((r) => !r.isDeleted).toList();
      expect(back.single.rideId.value, 'whole');
      expect(back.single.legs.single.toNode, rig.ride('x', lineId, 0, 4).legs.single.toNode);
    });

    testWidgets('끈 구간을 다시 켜면 날짜째 되살아나고 없으면 날짜 없는 기록이 된다', skip: _skip != null, (tester) async {
      await tester.runAsync(
        () => rig.session.records.apply(
          Change(before: const [], after: [rig.ride('whole', lineId, 0, 3, date: '2024-05-05')]),
        ),
      );
      final container = await show(tester);
      await settle(tester);
      final commands = container.read(sectionCommandsProvider);
      final section = container.read(lineDiagramProvider(lineId)).value!.routes.first.sections[1];
      final off = await tester.runAsync(() => commands.turnOff(lineId, [section]));
      expect(off, isA<SectionOff>());
      await settle(tester);
      final fresh = container.read(lineDiagramProvider(lineId)).value!.routes.first.sections;
      expect(fresh[1].ridden, isFalse);
      final on = await tester.runAsync(() => commands.turnOn(lineId, [fresh[1]]));
      expect((on! as SectionOn).restored, isTrue);
      await settle(tester);
      var live = (await tester.runAsync(rig.rides))!.where((r) => !r.isDeleted).toList();
      expect(live.every((r) => r.dateInput == '2024-05-05'), isTrue);
      final far = container.read(lineDiagramProvider(lineId)).value!.routes.first.sections[6];
      final made = await tester.runAsync(() => commands.turnOn(lineId, [far]));
      expect((made! as SectionOn).restored, isFalse);
      live = (await tester.runAsync(rig.rides))!.where((r) => !r.isDeleted).toList();
      final undated = live.singleWhere((r) => r.dateInput == null);
      expect((undated.fromAlighted, undated.toAlighted), (false, false));
    });

    testWidgets('길게 누른 뒤 끌면 여러 구간을 한 번에 켜고 되돌릴 수 있다', skip: _skip != null, (tester) async {
      final container = await show(tester);
      await settle(tester);
      final rows = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_SectionRow');
      final first = tester.getCenter(rows.at(0));
      final third = tester.getCenter(rows.at(2));
      final gesture = await tester.startGesture(first);
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(Offset(first.dx, (first.dy + third.dy) / 2));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveTo(third);
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();
      await settle(tester);
      final sections = container.read(lineDiagramProvider(lineId)).value!.routes.first.sections;
      expect(sections.take(3).every((s) => s.ridden), isTrue);
      expect(sections[3].ridden, isFalse);
      final live = (await tester.runAsync(rig.rides))!.where((r) => !r.isDeleted).toList();
      expect(live.length, 1, reason: '이어진 구간은 기록 하나다');
      await tester.tap(find.text('되돌리기'));
      await settle(tester);
      expect((await tester.runAsync(rig.rides))!.where((r) => !r.isDeleted), isEmpty);
    });

    testWidgets('머리에 큰 %, 현행·역대, 구간 km가 나온다', skip: _skip != null, (tester) async {
      await show(tester);
      expect(find.text('현재 구간'), findsOneWidget);
      expect(find.text('폐지 구간 포함'), findsOneWidget);
      expect(find.text('이 노선 기록하기'), findsOneWidget);
      expect(find.textContaining('km'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
