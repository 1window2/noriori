import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noriori/features/record/ui/session_date.dart';
import 'package:noriori/i18n/strings.g.dart';

/// 탑승일 팝업의 「오늘」은 한 번에 오늘 날짜를 적용한다.
void main() {
  testWidgets('오늘을 누르면 오늘 날짜로 바로 닫힌다', (tester) async {
    await LocaleSettings.setLocale(AppLocale.ko);
    DateAnswer? got;
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              got = await showDialog<DateAnswer>(
                context: context,
                builder: (_) => const SessionDateDialog(current: '1985-XX-XX', today: '2026-11-08'),
              );
            },
            child: const Text('열기'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('오늘'));
    await tester.pumpAndSettle();
    expect(find.byType(SessionDateDialog), findsNothing);
    expect(got?.value, '2026-11-08');
  });
}
