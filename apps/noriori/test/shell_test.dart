import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noriori/app/router.dart';
import 'package:noriori/app/session_providers.dart';
import 'package:noriori/app/theme/app_theme.dart';
import 'package:noriori/features/data/ui/blocked_start_screen.dart';
import 'package:noriori/i18n/strings.g.dart';

Widget _app(Widget child) => TranslationProvider(child: child);

/// 저장소 없이 테마 값만 바꾼다.
final class _FakeTheme extends ThemeController {
  _FakeTheme(this.value);

  final ValueNotifier<ThemeChoice> value;

  @override
  ThemeChoice build() => value.value;

  @override
  Future<void> set(ThemeChoice next) async {
    value.value = next;
    state = next;
  }
}

void main() {
  testWidgets('탭을 옮겨도 판 번호가 보인다', (tester) async {
    await tester.pumpWidget(
      _app(
        ProviderScope(
          overrides: [
            editionProvider.overrideWithValue('2026-11-02'),
            packFactsProvider.overrideWith(
              (ref) async => const PackFacts(stations: 11005, lines: 766),
            ),
          ],
          child: MaterialApp.router(
            theme: appTheme(Brightness.light),
            routerConfig: buildRouter(map: const Text('지도 자리')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('지도 자리'), findsOneWidget);

    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();
    expect(find.text('2026-11-02'), findsOneWidget);
    expect(find.text('역 11,005곳 · 노선 766개'), findsOneWidget);
  });

  testWidgets('설정에서 테마를 고를 수 있고 앱에 적용된다', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final choice = ValueNotifier(ThemeChoice.system);
    await tester.pumpWidget(
      _app(
        ProviderScope(
          overrides: [
            editionProvider.overrideWithValue('2026-11-02'),
            packFactsProvider.overrideWith((ref) async => const PackFacts(stations: 1, lines: 1)),
            themeChoiceProvider.overrideWith(() => _FakeTheme(choice)),
          ],
          child: Consumer(
            builder: (context, ref, _) => MaterialApp.router(
              theme: appTheme(Brightness.light),
              darkTheme: appTheme(Brightness.dark),
              themeMode: ref.watch(themeChoiceProvider).mode,
              routerConfig: buildRouter(map: const Text('지도 자리')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();
    expect(find.text('테마'), findsOneWidget);
    expect(find.text('시스템 설정'), findsOneWidget);
    await tester.tap(find.text('다크'));
    await tester.pumpAndSettle();
    expect(choice.value, ThemeChoice.dark);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });

  testWidgets('데이터 출처를 설정에서 볼 수 있다', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        ProviderScope(
          overrides: [
            editionProvider.overrideWithValue('2026-11-02'),
            packFactsProvider.overrideWith(
              (ref) async => const PackFacts(stations: 1, lines: 1),
            ),
          ],
          child: MaterialApp.router(
            theme: appTheme(Brightness.light),
            routerConfig: buildRouter(map: const Text('지도 자리')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('데이터 출처'));
    await tester.pumpAndSettle();
    expect(find.textContaining('CC BY-SA 4.0'), findsWidgets);
    expect(find.textContaining('国土数値情報（鉄道データ）'), findsOneWidget);
    expect(find.text('OpenFreeMap'), findsOneWidget);
    expect(find.text('나무위키'), findsOneWidget);
  });

  test('글꼴 라이선스가 앱 라이선스에 들어간다', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFontLicense();
    final entries = await LicenseRegistry.licenses.toList();
    final font = entries.singleWhere((entry) => entry.packages.contains(appFontFamily));
    expect(font.paragraphs.map((p) => p.text).join(), contains('SIL OPEN FONT LICENSE'));
  });

  testWidgets('손상 화면에는 기록을 지우는 길이 없다', (tester) async {
    await tester.pumpWidget(
      _app(const MaterialApp(home: BlockedStartScreen.restoreOnly())),
    );
    await tester.pumpAndSettle();
    expect(find.text('기록 파일이 손상되었습니다'), findsOneWidget);
    expect(find.textContaining('삭제'), findsNothing);
    expect(find.textContaining('초기화'), findsNothing);
  });
}
