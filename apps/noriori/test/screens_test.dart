import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:noriori/app/session_providers.dart';
import 'package:noriori/app/theme/app_theme.dart';
import 'package:noriori/app/theme/tokens.dart';
import 'package:noriori/app/widgets/line_strip_bar.dart';
import 'package:noriori/app/widgets/meter.dart';
import 'package:noriori/app/widgets/summary_actions.dart';
import 'package:noriori/features/data/ui/blocked_start_screen.dart';
import 'package:noriori/features/data/controller/import_controller.dart';
import 'package:noriori/features/data/ui/import_screen.dart';
import 'package:noriori/features/map/map_style.dart';
import 'package:noriori/features/record/controller/browse_controller.dart';
import 'package:noriori/features/record/controller/record_list_controller.dart';
import 'package:noriori/features/record/controller/record_session_controller.dart';
import 'package:noriori/features/record/ui/browse_screens.dart';
import 'package:noriori/features/record/ui/record_list_screen.dart';
import 'package:noriori/features/record/ui/ride_ticket.dart';
import 'package:noriori/features/stats/ui/activity_screen.dart';
import 'package:noriori/features/stats/controller/visits_controller.dart';
import 'package:noriori/features/stats/ui/stats_screen.dart';
import 'package:noriori/features/stats/ui/visits_screen.dart';
import 'package:noriori/i18n/strings.g.dart';
import 'package:noriori_core/noriori_core.dart';
import 'package:noriori_store/noriori_store.dart';

const _ongoing = NetPeriod(
  fromLo: '1900-01-01',
  fromHi: '1900-01-01',
  toLo: DateSpan.maxDate,
  toHi: DateSpan.maxDate,
);

Network _network() => Network(
      const NetworkData(
        routes: [],
        edges: [],
        routeEdges: [],
        stops: [],
        attrs: [
          NetAttr(
            edgeId: 'e1',
            lineId: 'l',
            operatorId: 'o',
            lineageId: 'lg',
            carryoverGroup: 'c',
            period: _ongoing,
          ),
          NetAttr(
            edgeId: 'e2',
            lineId: 'l',
            operatorId: 'o',
            lineageId: 'lg',
            carryoverGroup: 'c',
            period: _ongoing,
          ),
        ],
        lives: [],
        units: [
          NetUnit(
            n: 1,
            key: 'lg:e1',
            carryover: true,
            edgeId: 'e1',
            meters: 1000,
            normal: true,
            dateLo: '1900-01-01',
            dateHi: DateSpan.maxDate,
          ),
          NetUnit(
            n: 2,
            key: 'lg:e2',
            carryover: true,
            edgeId: 'e2',
            meters: 3000,
            normal: true,
            dateLo: '1900-01-01',
            dateHi: DateSpan.maxDate,
          ),
        ],
        publicNodes: {},
        nodeGroups: {},
        operators: [NetOperator(id: 'o', category: 'jr')],
        lineOrder: ['l'],
      ),
    );

Widget _app(Widget child, List<Override> overrides) => TranslationProvider(
      child: ProviderScope(
        overrides: overrides,
        child: MaterialApp(theme: appTheme(Brightness.light), home: Scaffold(body: child)),
      ),
    );

final class _Fixed extends ImportController {
  _Fixed(this.step);

  final ImportStep step;

  @override
  ImportStep build() => step;
}

const _row = CsvRide(
  company: '会社',
  line: '線',
  from: 'A',
  to: 'B',
  meters: 1200,
  dateInput: null,
  comment: null,
  raw: '会社,線,A,B,1.2,0000-00-00',
);

ImportRow _imported(RowResult result, ImportState state) =>
    ImportRow(row: _row, result: result, rideId: const RideId('r'), state: state);

void main() {
  group('가져오기', () {
    const matched = RowMatched(
      lineId: 'l',
      routeId: 'r',
      fromNode: 'a',
      toNode: 'b',
      meters: 1200,
    );

    testWidgets('확인 화면은 무엇이 들어오는지 보여 주고 지운 기록은 고를 때만 넣는다', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final plan = ImportPlan(
        rows: [
          _imported(matched, ImportState.fresh),
          _imported(const RowMissed(MissReason.line), ImportState.fresh),
          _imported(matched, ImportState.existing),
          _imported(matched, ImportState.deleted),
        ],
        broken: const ['깨진 행'],
      );
      await tester.pumpWidget(
        _app(const ImportScreen(), [
          importControllerProvider.overrideWith(() => _Fixed(ImportReady('a.csv', plan))),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.text('a.csv'), findsOneWidget);
      expect(find.text('노선을 찾지 못한 행 1건'), findsOneWidget);
      expect(find.text('읽지 못한 행 1건'), findsOneWidget);
      expect(find.text('1.2 km'), findsOneWidget);
      expect(find.text('2건 가져오기'), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.text('3건 가져오기'), findsOneWidget);
    });

    testWidgets('넣을 것이 없으면 버튼을 막는다', (tester) async {
      final plan = ImportPlan(rows: [_imported(matched, ImportState.existing)], broken: const []);
      await tester.pumpWidget(
        _app(const ImportScreen(), [
          importControllerProvider.overrideWith(() => _Fixed(ImportReady('a.csv', plan))),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.text('새로 가져올 기록이 없습니다'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('실패하면 기록이 그대로임을 알리고 다시 고를 수 있다', (tester) async {
      await tester.pumpWidget(
        _app(const ImportScreen(), [
          importControllerProvider.overrideWith(() => _Fixed(const ImportFailed())),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.text('가져오지 못했습니다. 기록은 바뀌지 않았습니다.'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('노리츠부시 파일이 아니면 이름을 알려 준다', (tester) async {
      await tester.pumpWidget(
        _app(const ImportScreen(), [
          importControllerProvider.overrideWith(() => _Fixed(const ImportRefused('b.txt'))),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('b.txt'), findsOneWidget);
    });
  });

  group('지도 스타일', () {
    test('탄 구간 필터의 값은 문자열이다', () {
      // Android의 식 변환은 배열 첫 값을 연산자로 읽어 숫자 배열을 조용히 망가뜨린다
      final filter = riddenFilter({30, 4}, closed: false);
      final match = filter.last as List<Object>;
      expect(match.first, 'match');
      expect(match[2], ['4', '30']);
    });

    test('탄 구간이 없으면 아무것도 고르지 않는다', () {
      final filter = riddenFilter(const {}, closed: true);
      expect(filter.last, ['==', ['get', 'n'], -1]);
    });

    test('히트맵은 탄 비율을 네 단계로 나눈다', () {
      expect(heatLevel(0), isNull);
      expect(heatLevel(0.05), 0);
      expect(heatLevel(0.1), 1);
      expect(heatLevel(0.3), 2);
      expect(heatLevel(0.9), 3);
      expect(jsonEncode(heatFilter(const {})), contains('-1'));
    });

    test('타임 슬라이더는 그해에 있던 것만 남긴다', () {
      final filter = jsonEncode(railFilter(closed: false, year: 1985));
      expect(filter, contains('["<=",["coalesce",["get","fy"],0],1985]'));
      expect(filter, contains('[">=",["coalesce",["get","ty"],9999],1985]'));
      expect(railFilter(closed: false).length, 2);
    });

    test('내장 배경이 있으면 바다가 바탕이고 경계는 내장 층이다', () {
      final style = jsonDecode(
        railStyle(tiles: '/x/rail.pmtiles', baseTiles: '/x/base.pmtiles', glyphs: '/x/glyph-{range}.pbf', tokens: AppTokens.dark),
      ) as Map<String, Object?>;
      expect(style['glyphs'], 'file:///x/glyph-{range}.pbf');
      final layers = (style['layers']! as List<Object?>).cast<Map<String, Object?>>();
      expect((layers.first['paint']! as Map<String, Object?>)['background-color'], '#0f1f2b');
      expect(layers[1]['id'], 'japan-land');
      expect(layers.firstWhere((l) => l['id'] == 'pref-border')['source'], 'japan');
    });

    test('OSM 선에 맞춘 역과 표식도 같은 층으로 그린다', () {
      final style = jsonDecode(
        railStyle(tiles: '/x/rail.pmtiles', osmTiles: '/x/rail-osm.pmtiles', tokens: AppTokens.dark),
      ) as Map<String, Object?>;
      final layers = (style['layers']! as List<Object?>).cast<Map<String, Object?>>();
      final osm = {
        for (final layer in layers)
          if (layer['source'] == 'rail-osm') layer['id'],
      };
      expect(osm, containsAll([
        for (final id in [
          stationLayer,
          stationClosedLayer,
          stationPassedLayer,
          stationSteppedLayer,
          stationNameLayer,
          markerLayer,
          markerRiddenLayer,
        ])
          '$id$osmSuffix',
      ]));
    });

    test('색은 토큰에서 오고 스타일은 올바른 JSON이다', () {
      final style = jsonDecode(railStyle(tiles: '/x/rail.pmtiles', tokens: AppTokens.dark))
          as Map<String, Object?>;
      final sources = style['sources']! as Map<String, Object?>;
      expect((sources['rail']! as Map<String, Object?>)['url'], 'pmtiles://file:///x/rail.pmtiles');
      final layers = (style['layers']! as List<Object?>).cast<Map<String, Object?>>();
      final land = layers.first['paint']! as Map<String, Object?>;
      expect(land['background-color'], '#14171c');
      expect(layers.map((l) => l['id']), containsAll([riddenCurrentLayer, riddenClosedLayer]));
    });
  });

  testWidgets('통계는 탄 만큼 보여 주고 표시는 내림이다', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(const StatsScreen(), [
        networkProvider.overrideWithValue(_network()),
        nameBookProvider.overrideWithValue(
          const NameBook(lines: {'l': '시험선'}, routes: {}, operators: {'o': '시험철도'}),
        ),
        todayProvider.overrideWithValue('2026-11-02'),
        unitHitsProvider.overrideWith((ref) => Stream.value(const {1: '2026-01-01'})),
        riddenNodesProvider.overrideWith((ref) => Stream.value(const <String>{})),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('25.0'), findsOneWidget);
    expect(find.text('25.0%'), findsNWidgets(2));
    expect(find.text('1.0 / 4.0 km'), findsOneWidget);
    expect(find.text('시험선'), findsNWidgets(2));
    expect(find.text('시험철도'), findsOneWidget);
    expect(find.text('탄 노선'), findsOneWidget);
    expect(find.text('곧 완주'), findsOneWidget);
  });

  group('노선별 목록', () {
    List<Override> tree({Map<int, String?> hits = const {1: '2026-01-01'}}) => [
          networkProvider.overrideWithValue(_network()),
          nameBookProvider.overrideWithValue(
            const NameBook(lines: {'l': '시험선'}, routes: {}, operators: {'o': '시험철도'}),
          ),
          todayProvider.overrideWithValue('2026-11-02'),
          unitHitsProvider.overrideWith((ref) => Stream.value(hits)),
        ];

    testWidgets('분류마다 이름과 진행률이 한 버튼에 있다', (tester) async {
      await tester.pumpWidget(_app(const LineBrowseView(), tree()));
      await tester.pumpAndSettle();
      expect(find.text('현재'), findsOneWidget);
      expect(find.text('폐선'), findsOneWidget);
      expect(find.text('JR'), findsOneWidget);
      expect(find.text('25.0%'), findsNWidgets(2));
      expect(find.text('1.0 / 4.0 km'), findsOneWidget);
      expect(find.text('1.0'), findsOneWidget);
      final bars = tester.widgetList<Meter>(find.byType(Meter));
      expect(bars.map((bar) => bar.ratio), [0.25, 0.25]);
    });

    testWidgets('폐선을 고르면 폐지된 구간이 없는 분류는 나오지 않는다', (tester) async {
      await tester.pumpWidget(_app(const LineBrowseView(), tree()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('폐선'));
      await tester.pumpAndSettle();
      expect(find.text('JR'), findsNothing);
    });

    testWidgets('회사와 노선도 같은 모양이다', (tester) async {
      await tester.pumpWidget(
        _app(const OperatorListScreen(era: BrowseEra.current, category: 'jr'), tree()),
      );
      await tester.pumpAndSettle();
      expect(find.text('시험철도'), findsOneWidget);
    });

    testWidgets('다 타면 노선이 100.0%다', (tester) async {
      await tester.pumpWidget(
        _app(
          const LineListScreen(era: BrowseEra.current, category: 'jr', operatorId: 'o'),
          [
            ...tree(hits: const {1: null, 2: null}),
            lineRowsProvider.overrideWith(
              (ref, key) async => [
                const LineRow(
                  line: BrowseLine(
                    lineId: 'l',
                    score: Score(numMeters: 4000, denMeters: 4000, numUnits: 2, denUnits: 2),
                  ),
                  strip: LineStrip(totalMeters: 4000, segments: [StripSegment(0, 4000)]),
                ),
              ],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('시험선'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.byType(LineStripBar), findsOneWidget);
    });
  });

  group('활동 캘린더', () {
    RideSummary ride(String id, String? date, {String? input}) => RideSummary(
          rideId: RideId(id),
          status: ResolveStatus.ok,
          lineLabel: '시험선',
          fromLabel: '출발$id',
          toLabel: '도착$id',
          date: date,
          dateInput: input ?? date,
          km10: 12,
        );

    Future<void> open(WidgetTester tester, List<RideSummary> rides) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(const ActivityScreen(), [
          todayProvider.overrideWithValue('2026-11-03'),
          rideSummariesProvider.overrideWith((ref) => Stream.value(rides)),
        ]),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('세로는 요일이고 가장 최근에 탄 날이 처음부터 열려 있다', (tester) async {
      await open(tester, [ride('a', '2026-11-01'), ride('b', '2026-11-02'), ride('c', '2026-03-01')]);
      final top = tester.getTopLeft(find.byKey(const ValueKey('day-2026-11-01')));
      final next = tester.getTopLeft(find.byKey(const ValueKey('day-2026-11-02')));
      expect(next.dx, top.dx);
      expect(next.dy, greaterThan(top.dy));
      final week = tester.getTopLeft(find.byKey(const ValueKey('day-2026-11-08')));
      expect(week.dy, top.dy);
      expect(week.dx, greaterThan(top.dx));
      expect(find.text('출발b → 도착b'), findsOneWidget);
      expect(find.text('출발a → 도착a'), findsNothing);
    });

    testWidgets('칸을 누르면 그날 기록이 나오고 없는 날은 없다고 한다', (tester) async {
      await open(tester, [ride('a', '2026-11-01'), ride('b', '2026-11-02')]);
      await tester.tap(find.byKey(const ValueKey('day-2026-11-01')));
      await tester.pump();
      expect(find.text('출발a → 도착a'), findsOneWidget);
      expect(find.text('출발b → 도착b'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('day-2026-11-03')));
      await tester.pump();
      expect(find.text('기록 없음'), findsOneWidget);
    });

    testWidgets('연도만 아는 기록은 칸에 찍지 않는다', (tester) async {
      await open(tester, [ride('a', '2026-06-30', input: '2026')]);
      expect(find.text('출발a → 도착a'), findsNothing);
      expect(find.text('기록 없음'), findsNothing);
    });
  });

  testWidgets('방문 역은 도도부현별로 많은 곳부터 보여 준다', (tester) async {
    await tester.pumpWidget(
      _app(const VisitsScreen(), [
        visitsDataProvider.overrideWith(
          (ref) async => const VisitsData(total: 6, closed: 1, byPref: [(13, 3), (14, 2)]),
        ),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('6곳'), findsOneWidget);
    expect(find.text('현행 5곳 · 폐역 1곳 · 도도부현 2 / 47'), findsOneWidget);
    final tokyo = tester.getTopLeft(find.text('도쿄'));
    final kanagawa = tester.getTopLeft(find.text('가나가와'));
    expect(tokyo.dy, lessThan(kanagawa.dy));
    expect(find.text('도도부현을 모르는 역 1곳'), findsOneWidget);
  });

  testWidgets('글자를 키우면 요약이 안에서 스크롤하고 버튼은 화면에 남는다', (tester) async {
    tester.view.physicalSize = const Size(360, 733);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(360, 733), textScaler: TextScaler.linear(2)),
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Expanded(child: SizedBox.expand(key: ValueKey('list'))),
                SummaryActions(
                  summary: Text('아주 긴 요약 ' * 40),
                  actions: [FilledButton(onPressed: () {}, child: const Text('저장'))],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getBottomLeft(find.text('저장')).dy, lessThanOrEqualTo(733));
    expect(tester.getSize(find.byKey(const ValueKey('list'))).height, greaterThan(300));
  });

  testWidgets('승차권 글자에 기본 밑줄이 붙지 않는다', (tester) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showRideTicket(
              context,
              const RideTicketData(lineName: '선', fromName: '가', toName: '나', meters: 1200, dateInput: '2026-11-03'),
              demoted: false,
              onUndo: () {},
            ),
            child: const Text('열기'),
          ),
        ),
        const [],
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    final stamp = tester.element(find.text('乗車'));
    expect(DefaultTextStyle.of(stamp).style.decoration, isNot(TextDecoration.underline));
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('乗車'), findsNothing);
  });

  testWidgets('기록이 없으면 첫 기록을 안내한다', (tester) async {
    await tester.pumpWidget(
      _app(const RecordListScreen(), [
        rideListProvider.overrideWith((ref) => Stream.value(const [])),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('아직 기록이 없습니다'), findsOneWidget);
  });

  testWidgets('기록 목록은 확인이 필요한 기록을 숨기지 않는다', (tester) async {
    await tester.pumpWidget(
      _app(const RecordListScreen(), [
        rideListProvider.overrideWith(
          (ref) => Stream.value(const [
            RideSummary(
              rideId: RideId('a'),
              status: ResolveStatus.unknownRef,
              lineLabel: '옛 노선',
              fromLabel: '가',
              toLabel: '나',
            ),
          ]),
        ),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('가 → 나'), findsOneWidget);
    expect(find.textContaining('확인 필요'), findsOneWidget);
    expect(find.textContaining('날짜 모름'), findsOneWidget);
  });

  testWidgets('기록을 길게 누르면 여러 개를 고를 수 있다', (tester) async {
    await tester.pumpWidget(
      _app(const RecordListScreen(), [
        rideListProvider.overrideWith(
          (ref) => Stream.value(const [
            RideSummary(
              rideId: RideId('a'),
              status: ResolveStatus.ok,
              lineLabel: '노선',
              fromLabel: '가',
              toLabel: '나',
            ),
            RideSummary(
              rideId: RideId('b'),
              status: ResolveStatus.ok,
              lineLabel: '노선',
              fromLabel: '다',
              toLabel: '라',
            ),
          ]),
        ),
      ]),
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.text('가 → 나'));
    await tester.pumpAndSettle();
    expect(find.text('1건 선택'), findsOneWidget);
    await tester.tap(find.text('다 → 라'));
    await tester.pumpAndSettle();
    expect(find.text('2건 선택'), findsOneWidget);
    expect(find.text('삭제'), findsOneWidget);
  });

  testWidgets('공간이 부족하면 안내하고 다시 시도할 수 있다', (tester) async {
    var retried = 0;
    await tester.pumpWidget(
      _app(BlockedStartScreen.noSpace(reason: 'ENOSPC', onAction: () => retried++), const []),
    );
    await tester.pumpAndSettle();
    expect(find.text('저장 공간이 부족합니다'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    expect(retried, 1);
  });
}
