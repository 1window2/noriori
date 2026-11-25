import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noriori/app/session_providers.dart';
import 'package:noriori/features/map/ui/map_home_screen.dart';
import 'package:noriori/i18n/strings.g.dart';
import 'package:noriori/features/record/controller/record_session_controller.dart';
import 'package:noriori/main.dart' as app;

/// 고친 노선·역을 빠짐없이 찍는 순회 시험이다 (tour_test보다 넓다).
///
/// `--dart-define=SWEEP_ROUTES=r_a@2026-11-20|undated|1955-06-01,r_b@undated`처럼 계통과 날짜를 고른다.
/// 기록 화면마다 맨 위부터 한 화면씩 끝까지 내리며 `TOUR_SHOT:`을 찍는다.
/// `SWEEP_SEARCH=dogokoen,Fukuoka Airport`면 찾기 화면에 차례로 넣어 결과를 찍는다.
/// 갈무리는 tools/dev/tour.sh가 simctl로 한다 (TOUR_TEST=integration_test/sweep_test.dart)
const _routes = String.fromEnvironment('SWEEP_ROUTES');
const _search = String.fromEnvironment('SWEEP_SEARCH');
const _lang = String.fromEnvironment('SWEEP_LANG');
const _maxPages = int.fromEnvironment('SWEEP_MAX_PAGES', defaultValue: 40);

Future<void> _wait(WidgetTester tester, bool Function() done, {Duration limit = const Duration(seconds: 90)}) async {
  final end = DateTime.now().add(limit);
  while (!done()) {
    if (DateTime.now().isAfter(end)) fail('$limit 안에 화면이 나오지 않았다');
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _shot(WidgetTester tester, String name, {int millis = 1600}) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
  // ignore: avoid_print
  print('TOUR_SHOT:$name');
  final end = DateTime.now().add(Duration(milliseconds: millis));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(tester.takeException(), isNull, reason: name);
}

ScrollableState? _mainList(WidgetTester tester) {
  ScrollableState? best;
  for (final e in find.byType(Scrollable).evaluate()) {
    final s = (e as StatefulElement).state as ScrollableState;
    if (s.position.axis != Axis.vertical || !s.position.hasContentDimensions) continue;
    if (best == null || s.position.maxScrollExtent > best.position.maxScrollExtent) best = s;
  }
  return best;
}

String _safe(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('고친 계통·검색어를 끝까지 찍는다', (tester) async {
    app.main();
    await _wait(tester, () => find.byType(MapHomeScreen).evaluate().isNotEmpty);
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
    // 앱 언어는 기기 언어가 아니라 앱 설정이다. 고른 언어로 바꾸고(저장됨) 이름 순서도 따라 바뀐다
    if (_lang.isNotEmpty) {
      await container.read(languageProvider.notifier).set(AppLocale.values.firstWhere((l) => l.languageCode == _lang));
      await tester.pump(const Duration(seconds: 2));
    }
    final network = container.read(networkProvider);
    final session = container.read(recordSessionProvider.notifier);

    for (final spec in _routes.isEmpty ? const <String>[] : _routes.split(',')) {
      final at = spec.indexOf('@');
      final route = at < 0 ? spec : spec.substring(0, at);
      final days = at < 0 ? const ['undated'] : spec.substring(at + 1).split('|');
      final line = network.routes[route]?.lineId;
      if (line == null) {
        // ignore: avoid_print
        print('SWEEP_MISSING:$route');
        continue;
      }
      for (final day in days) {
        await session.open(lineId: line, routeId: route, dateUnknown: day == 'undated');
        if (day != 'undated' && day != 'today') await session.setDate(day);
        unawaited(router.push('/record/session?back=1'));
        await _wait(tester, () => _mainList(tester) != null, limit: const Duration(seconds: 30));
        final tag = '${_safe(route)}_${_safe(day)}';
        var page = 0;
        while (true) {
          await _shot(tester, '${tag}_p${page.toString().padLeft(2, '0')}');
          final list = _mainList(tester);
          if (list == null) break;
          final pos = list.position;
          if (pos.pixels >= pos.maxScrollExtent - 1 || ++page >= _maxPages) break;
          pos.jumpTo((pos.pixels + pos.viewportDimension * 0.85).clamp(0, pos.maxScrollExtent));
        }
        router.pop();
        await tester.pump(const Duration(milliseconds: 400));
      }
    }

    for (final query in _search.isEmpty ? const <String>[] : _search.split(',')) {
      unawaited(router.push('/search'));
      await _wait(tester, () => find.byType(TextField).evaluate().isNotEmpty, limit: const Duration(seconds: 20));
      await tester.enterText(find.byType(TextField).first, query);
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      await _shot(tester, 'search_${_safe(query)}');
      router.pop();
      await tester.pump(const Duration(milliseconds: 400));
    }
  }, timeout: const Timeout(Duration(minutes: 120)));
}
