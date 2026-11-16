import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noriori/features/map/ui/map_home_screen.dart';
import 'package:noriori/features/record/controller/record_session_controller.dart';
import 'package:noriori/main.dart' as app;

/// 노선 중간의 역을 기록 화면에서 그 역에 맞춰 띄운다 (tour_test는 목록 위쪽만 찍는다).
///
/// `--dart-define=FOCUS=노선|계통|노드;노선|계통|노드`로 고른다. 화면마다 `TOUR_SHOT:<이름>`을 찍으므로
/// `TOUR_TEST=integration_test/focus_test.dart tools/dev/tour.sh <기기> <ios|android> <폴더> --dart-define=FOCUS=...`로 갈무리한다.
const _focus = String.fromEnvironment('FOCUS');

Future<void> _wait(WidgetTester tester, bool Function() done, {Duration limit = const Duration(seconds: 90)}) async {
  final end = DateTime.now().add(limit);
  while (!done()) {
    if (DateTime.now().isAfter(end)) fail('$limit 안에 화면이 나오지 않았다');
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _shot(WidgetTester tester, String name, {int seconds = 2}) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  // ignore: avoid_print
  print('TOUR_SHOT:$name');
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(tester.takeException(), isNull, reason: name);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('노선 중간의 역을 기록 화면에서 그 역에 맞춰 띄운다', (tester) async {
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
    for (final item in _focus.split(';').where((x) => x.isNotEmpty)) {
      final [lineId, routeId, node] = item.split('|');
      for (final unknown in const [false, true]) {
        await container
            .read(recordSessionProvider.notifier)
            .open(lineId: lineId, routeId: routeId, focusNode: node, dateUnknown: unknown);
        unawaited(router.push('/record/session?back=1'));
        await _shot(tester, 'focus_${routeId}_${node}_${unknown ? 'undated' : 'today'}');
        router.pop();
      }
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}
