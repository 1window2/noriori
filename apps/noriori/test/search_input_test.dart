import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:noriori/app/session_providers.dart';
import 'package:noriori/features/record/controller/line_search_controller.dart';
import 'package:noriori/features/record/ui/line_search_screen.dart';
import 'package:noriori/i18n/strings.g.dart';

/// 한글·가나는 IME가 조합 중인 글자(marked text)를 거쳐 들어온다. 조합 중에도 입력란이 글자를 잃지 않아야 한다.
void main() {
  Future<List<String>> typeComposing(WidgetTester tester, List<(String, int?)> steps) async {
    final asked = <String>[];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        lineSearchProvider.overrideWith((ref, text) async {
          asked.add(text);
          return const [];
        }),
      ],
      child: TranslationProvider(child: const MaterialApp(home: LineSearchScreen())),
    ));
    await tester.pump();
    for (final (text, composing) in steps) {
      tester.testTextInput.updateEditingValue(TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
        composing: composing == null ? TextRange.empty : TextRange(start: text.length - composing, end: text.length),
      ));
      await tester.pump();
    }
    expect(find.text(steps.last.$1), findsOneWidget);
    return asked;
  }

  testWidgets('한글을 자모 조합으로 쳐도 글자가 남고 검색된다', (tester) async {
    final asked = await typeComposing(tester, [('ㅇ', 1), ('유', 1), ('윹', 1), ('유토', 1), ('유토ㄹ', 1), ('유토리', 1), ('유토리토', null)]);
    expect(asked.last, '유토리토');
  });

  testWidgets('입력란이 추천을 끄지 않는다 (안드로이드는 추천을 끄면 비밀번호 칸이 되어 한국어·일본어 키보드가 꺼진다)', (tester) async {
    await typeComposing(tester, [('a', null)]);
    final args = tester.testTextInput.log.lastWhere((call) => call.method == 'TextInput.setClient').arguments as List;
    final config = args[1] as Map;
    expect(config['enableSuggestions'], isTrue);
    expect((config['inputType'] as Map)['name'], isNot('TextInputType.visiblePassword'));
  });

  testWidgets('가나를 조합해 한자로 바꿔도 글자가 남고 검색된다', (tester) async {
    final asked = await typeComposing(tester, [('o', 1), ('お', 1), ('おお', 2), ('おおぞね', 4), ('大曽根', null)]);
    expect(asked.last, '大曽根');
  });

  testWidgets('역 결과의 지도 단추는 그 역을 지도에 맡기고 지도로 간다 (사용자 요청 2026-11-16)', (tester) async {
    final container = ProviderContainer(overrides: [
      lineSearchProvider.overrideWith((ref, text) async => const [
            SearchRow(title: '山崎', subtitle: 'JR京都線', lineId: 'l_x', routeId: 'r_x', fromNode: 'n_yamazaki'),
            SearchRow(title: 'JR京都線', subtitle: 'JR西日本', lineId: 'l_x'),
          ]),
    ]);
    addTearDown(container.dispose);
    final router = GoRouter(initialLocation: '/search', routes: [
      GoRoute(path: '/search', builder: (_, _) => const LineSearchScreen()),
      GoRoute(path: '/map', builder: (_, _) => const Text('MAP')),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: TranslationProvider(child: MaterialApp.router(routerConfig: router)),
    ));
    await tester.enterText(find.byType(TextField), '山崎');
    await tester.pumpAndSettle();
    // 노선 결과에는 단추가 없다
    expect(find.byIcon(Icons.map_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.map_outlined));
    await tester.pumpAndSettle();
    expect(find.text('MAP'), findsOneWidget);
    expect(container.read(mapFocusProvider)?.node, 'n_yamazaki');
  });
}
