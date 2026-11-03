import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noriori/app/theme/app_theme.dart';
import 'package:noriori/app/widgets/pills.dart';
import 'package:noriori/features/data/ui/blocked_start_screen.dart';
import 'package:noriori/i18n/strings.g.dart';

// 작은 화면과 큰 글자에서 부모가 내용을 누르지 않는지 본다. 넘침은 예외로 나오지만,
// 고정 높이에 눌린 글자는 예외 없이 찌그러지므로 크기로 확인한다.
const _scales = [1.0, 1.3, 2.0];

Future<void> _pump(WidgetTester tester, Widget child, double scale) async {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    TranslationProvider(
      child: ProviderScope(
        child: MediaQuery(
          data: MediaQueryData(size: const Size(320, 568), textScaler: TextScaler.linear(scale)),
          child: MaterialApp(
            theme: appTheme(Brightness.light),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(body: child),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  for (final scale in _scales) {
    testWidgets('칩은 눌리지 않고 터치 영역은 48dp 이상이다 (글자 $scale배)', (tester) async {
      await _pump(
        tester,
        Column(
          children: [
            FilterPillRow(
              pills: [
                for (final label in const ['전체', '타는 중', '안 탄 노선', '완주'])
                  FilterPill(label: label, selected: label == '전체', onTap: () {}),
              ],
            ),
          ],
        ),
        scale,
      );
      expect(tester.takeException(), isNull);
      for (final label in const ['전체', '타는 중', '안 탄 노선', '완주']) {
        final text = tester.getSize(find.text(label));
        expect(text.height, greaterThanOrEqualTo(13 * scale), reason: label);
        final pill = tester.getSize(
          find.ancestor(of: find.text(label), matching: find.byType(FilterPill)),
        );
        expect(pill.height, greaterThanOrEqualTo(48), reason: label);
        final chip = tester.getSize(
          find.ancestor(of: find.text(label), matching: find.byType(AnimatedContainer)),
        );
        expect(chip.height, greaterThanOrEqualTo(text.height + 12), reason: label);
      }
    });

    testWidgets('토글도 글자를 누르지 않는다 (글자 $scale배)', (tester) async {
      await _pump(
        tester,
        Align(
          alignment: Alignment.topRight,
          child: PillToggle<int>(
            values: const [0, 1, 2],
            label: (value) => ['현행', '역대', '연도'][value],
            selected: 0,
            onChanged: (_) {},
          ),
        ),
        scale,
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.text('현행')).height, greaterThanOrEqualTo(12 * scale));
      expect(
        tester.getSize(find.byType(PillToggle<int>)).height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('막힌 시작 화면은 어떤 글자 크기에서도 단추에 닿는다 (글자 $scale배)', (tester) async {
      await _pump(
        tester,
        BlockedStartScreen.noSpace(reason: 'ENOSPC ' * 40, onAction: () {}),
        scale,
      );
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.byType(FilledButton), 200);
      expect(find.byType(FilledButton).hitTestable(), findsOneWidget);
    });
  }

  testWidgets('테마 단추는 눌러도 끌어도 값이 바뀐다', (tester) async {
    var value = 'b';
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          theme: appTheme(Brightness.light),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SizedBox(
                width: 300,
                child: SlidingChoice<String>(
                  values: const ['a', 'b', 'c'],
                  label: (v) => v,
                  selected: value,
                  onChanged: (next) => setState(() => value = next),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('c'));
    await tester.pumpAndSettle();
    expect(value, 'c');
    await tester.drag(find.text('c'), const Offset(-280, 0));
    await tester.pumpAndSettle();
    expect(value, 'a');
    expect(tester.getSize(find.byType(SlidingChoice<String>)).height, greaterThanOrEqualTo(48));
  });
}
