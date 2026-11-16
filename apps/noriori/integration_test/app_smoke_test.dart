import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noriori/i18n/strings.g.dart';
import 'package:noriori/main.dart' as app;

/// 에뮬레이터·실기기에서 진짜 앱을 띄운다. 원격 작업 환경에는 에뮬레이터가 없어 맥에서 돌린다 (docs/TODO.md).
///
/// `flutter test integration_test -d <기기>`. 지도는 네이티브 화면이라 pumpAndSettle이 끝나지 않을 수 있어 시간으로 기다린다.
Future<void> _wait(WidgetTester tester, bool Function() done, {Duration limit = const Duration(seconds: 60)}) async {
  final end = DateTime.now().add(limit);
  while (!done()) {
    if (DateTime.now().isAfter(end)) fail('$limit 안에 화면이 나오지 않았다');
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('앱이 시작되고 네 탭과 설정의 데이터 출처가 열린다', (tester) async {
    final watch = Stopwatch()..start();
    app.main();
    // 첫 실행은 팩 복사가 있어 더 걸린다 (ARCHITECTURE §0.2)
    await _wait(tester, () => find.byIcon(Icons.train_outlined).evaluate().isNotEmpty);
    // ignore: avoid_print
    print('시작에서 탭까지 ${watch.elapsedMilliseconds}ms');
    for (final icon in [Icons.train_outlined, Icons.bar_chart_outlined, Icons.tune, Icons.map_outlined]) {
      await tester.tap(find.byIcon(icon));
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: '$icon');
    }
    await tester.tap(find.byIcon(Icons.tune));
    await _settle(tester);
    await tester.scrollUntilVisible(find.text(t.settings.sources), 200);
    await tester.tap(find.text(t.settings.sources));
    await _settle(tester);
    expect(find.text(t.sources.n05.name), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
