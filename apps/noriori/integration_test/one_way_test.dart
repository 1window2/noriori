import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noriori/app/session_providers.dart';
import 'package:noriori/features/map/ui/map_home_screen.dart';
import 'package:noriori/features/record/controller/record_session_controller.dart';
import 'package:noriori/i18n/strings.g.dart';
import 'package:noriori/main.dart' as app;

/// 한 방향 운행·정차 화면(칩·갈매기표·말풍선)을 시뮬레이터에서 찍는다 (DESIGN §8).
///
/// `tools/dev/tour.sh`처럼 `TOUR_SHOT:<이름>` 줄을 밖에서 받아 찍는다. `--dart-define=TOUR_LANG=en`이면 영어 화면이다.
const _lang = String.fromEnvironment('TOUR_LANG', defaultValue: 'ko');

Future<void> _pumpFor(WidgetTester tester, int ms) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  await _pumpFor(tester, 900);
  // ignore: avoid_print
  print('TOUR_SHOT:${_lang}_$name');
  await _pumpFor(tester, 2500);
  expect(tester.takeException(), isNull, reason: name);
}

Finder get _list => find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('한 방향 운행·정차 화면', (tester) async {
    app.main();
    final ready = DateTime.now().add(const Duration(seconds: 90));
    while (find.byType(MapHomeScreen).evaluate().isEmpty) {
      if (DateTime.now().isAfter(ready)) fail('지도가 뜨지 않았다');
      await tester.pump(const Duration(milliseconds: 200));
    }
    for (var i = 0; i < 25 && find.byType(Dialog).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    if (find.byType(Dialog).evaluate().isNotEmpty) {
      await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.byType(FilledButton)).last);
      await tester.pump(const Duration(milliseconds: 500));
    }
    final context = tester.element(find.byType(MapHomeScreen));
    final container = ProviderScope.containerOf(context);
    final router = GoRouter.of(context);
    final before = container.read(languageProvider);
    final language = AppLocale.values.firstWhere((value) => value.languageCode == _lang);
    await container.read(languageProvider.notifier).set(language);
    await _pumpFor(tester, 1500);

    /// 그 역 줄을 화면 가운데쯤으로 내리고 그 줄을 돌려준다.
    Future<Finder> stop(String node) async {
      final state = container.read(recordSessionProvider);
      final name = state.nameOf(node);
      // 역 줄의 글은 이름 뒤에 칩 자리(\uFFFC)나 띄어쓰기와 일본어 이름이 온다. 「미토선」 같은 분기 줄은 고르지 않는다
      bool exact(String text) => text == name || text.startsWith('$name  ') || text.startsWith('$name\uFFFC');
      final rows = find.byWidgetPredicate((w) => w is RichText && exact(w.text.toPlainText()));
      final row = rows.first;
      if (rows.evaluate().isEmpty) {
        tester.state<ScrollableState>(_list).position.jumpTo(0);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.scrollUntilVisible(rows, 120, scrollable: _list);
      }
      await Scrollable.ensureVisible(tester.element(row), alignment: 0.35);
      await _pumpFor(tester, 400);
      return row;
    }

    Future<void> open(String line, String route, {String? date}) async {
      final session = container.read(recordSessionProvider.notifier);
      await session.open(lineId: line, routeId: route);
      if (date != null) await session.setDate(date);
      unawaited(router.push('/record/session?back=1'));
      await _pumpFor(tester, 1500);
    }

    // 1. 常磐線 偕楽園: 하행만 칩, 水戸 출발 뒤 偕楽園을 누르면 말풍선, 방향 바꾸기
    await open('l_joban_line', 'r_joban_line', date: '2026-02-20');
    await stop('n_kairakuen');
    await _shot(tester, 'kairakuen_chip');
    await tester.tap(await stop('n_mito'));
    await _pumpFor(tester, 300);
    await tester.tap(await stop('n_kairakuen'));
    await _shot(tester, 'kairakuen_bubble');
    await tester.tap(find.byIcon(Icons.swap_vert));
    await _shot(tester, 'kairakuen_reversed');
    router.pop();
    await _pumpFor(tester, 800);

    // 2. 같은 역의 仮降車場 시절(1960): 하차전용 칩, 첫 탭(출발역)으로 고르면 바로 말풍선
    await open('l_joban_line', 'r_joban_line', date: '1960-03-01');
    await tester.tap(await stop('n_kairakuen'));
    await _shot(tester, 'kairakuen_alight');
    router.pop();
    await _pumpFor(tester, 800);

    // 3. 山万ユーカリが丘線: 갈매기표, 거꾸로 고르면 돌아가는 길 말풍선
    await open('l_yukarigaoka_line', 'r_yukarigaoka_line');
    await _shot(tester, 'yukarigaoka_chevrons');
    await tester.tap(await stop('n_chugakko'));
    await _pumpFor(tester, 300);
    final joshidai = container.read(recordSessionProvider).rows.firstWhere((row) => row.node == 'n_joshidai');
    // 女子大는 한 줄뿐이라 이름으로 찾는다
    expect(joshidai.selectable, isTrue);
    await tester.tap(await stop('n_joshidai'));
    await _shot(tester, 'yukarigaoka_around');
    router.pop();
    await _pumpFor(tester, 800);

    // 4. 函館本線 藤城線: 거꾸로 고르면 한 방향 구간 말풍선
    await open('l_hakodate_main_line', 'r_fujishiro_line');
    await tester.tap(await stop('n_onuma'));
    await _pumpFor(tester, 300);
    await tester.tap(await stop('n_nanae'));
    await _shot(tester, 'fujishiro_section');
    router.pop();
    await _pumpFor(tester, 800);

    await container.read(languageProvider.notifier).set(before);
    await _pumpFor(tester, 500);
  }, timeout: const Timeout(Duration(minutes: 20)));
}
