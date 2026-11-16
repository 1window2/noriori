import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noriori/app/theme/app_theme.dart';
import 'package:noriori/features/record/ui/one_way_bubble.dart';
import 'package:noriori/features/record/ui/switchback_mark.dart';
import 'package:noriori/i18n/strings.g.dart';

/// 끝 역 스위치백 직통 표식 (사용자 확정 디자인, 11회차 S3).
Future<void> _pump(WidgetTester tester, Widget child, {double scale = 1.0, double width = 360}) async {
  tester.view.physicalSize = Size(width * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        theme: appTheme(Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  tearDown(OneWayBubble.dismiss);

  testWidgets('표식은 둥근 테 하나, 다리 둘, 화살촉 둘을 한 색으로 그린다', (tester) async {
    const color = Color(0xff667788);
    await _pump(tester, const Center(child: CustomPaint(size: Size.square(28), painter: SwitchbackMarkPainter(color))));
    expect(
      find.byWidgetPredicate((widget) => widget is CustomPaint && widget.painter is SwitchbackMarkPainter),
      paints
        ..rrect(color: color, style: PaintingStyle.stroke, strokeWidth: 1.5)
        ..path(color: color, style: PaintingStyle.stroke)
        ..path(color: color, style: PaintingStyle.stroke)
        ..path(color: color, style: PaintingStyle.fill)
        ..path(color: color, style: PaintingStyle.fill),
    );
  });

  for (final (scale, side, hit) in const [(1.0, 28.0, 44.0), (1.3, 36.4, 44.0), (2.0, 56.0, 56.0)]) {
    testWidgets('표식은 글자 $scale배에 맞춰 $side로 커지고 눌림 영역은 44 이상이다', (tester) async {
      await _pump(
        tester,
        const Center(child: SwitchbackMark(color: Colors.black54, message: 'm', spoken: 's')),
        scale: scale,
      );
      final paint = find.byWidgetPredicate((widget) => widget is CustomPaint && widget.painter is SwitchbackMarkPainter);
      expect(tester.getSize(paint).width, closeTo(side, 0.01));
      expect(tester.getSize(find.byType(SwitchbackMark)).width, closeTo(hit, 0.01));
    });
  }

  // 전수 화면 점검과 같은 좁은 폰·큰 글자, 세 언어 (사용자 지시 2026-11-12)
  for (final locale in AppLocale.values) {
    testWidgets('누르면 말풍선에 직통 문구가 넘치지 않고 뜬다 (폭 360, 글자 1.3배, ${locale.languageCode})', (tester) async {
      LocaleSettings.setLocaleSync(locale);
      addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.ko));
      final t = Translations.of;
      late String now;
      late String used;
      await _pump(
        tester,
        Builder(builder: (context) {
          final line = switch (locale) { AppLocale.ko => withKoreanRo('후지큐 가와구치코선'), AppLocale.ja => '富士急行河口湖線', AppLocale.en => 'Fujikyu Kawaguchiko Line' };
          now = t(context).session.reverseNow(line: line);
          used = t(context).session.reverseUsed(line: line);
          return ListView(children: [
            for (final message in [now, used])
              SizedBox(
                height: 48,
                child: Stack(children: [
                  Positioned(
                    left: 20,
                    top: 0,
                    bottom: 0,
                    width: SwitchbackMark.hitOf(context),
                    child: Center(child: SwitchbackMark(color: Colors.black54, message: message, spoken: t(context).session.spokenReverse)),
                  ),
                ]),
              ),
          ]);
        }),
        scale: 1.3,
      );
      expect(find.bySemanticsLabel(switch (locale) { AppLocale.ko => '방향 바꿈', AppLocale.ja => 'スイッチバック', AppLocale.en => 'reverses direction' }), findsNWidgets(2));
      for (final message in [now, used]) {
        final marks = find.byType(SwitchbackMark);
        await tester.tap(message == now ? marks.first : marks.last);
        await tester.pump();
        expect(find.text(message), findsOneWidget);
        final box = tester.getRect(find.text(message));
        expect(box.right, lessThanOrEqualTo(360));
        expect(tester.takeException(), isNull);
        OneWayBubble.dismiss();
        await tester.pump();
      }
      expect(now, isNot(used));
      await tester.pump(const Duration(seconds: 9));
    });
  }

  // 말풍선 밖 어디를 눌러도 닫힌다. 시간이 지나기를 기다리지 않는다 (사용자 지적 2026-11-16)
  testWidgets('말풍선은 바깥을 누르면 바로 닫힌다', (tester) async {
    await _pump(
      tester,
      Builder(builder: (context) => ListView(children: [
            SizedBox(
              height: 48,
              child: Stack(children: [
                Positioned(
                  left: 20,
                  top: 0,
                  bottom: 0,
                  width: SwitchbackMark.hitOf(context),
                  child: const Center(child: SwitchbackMark(color: Colors.black54, message: '말풍선 문구', spoken: '방향 바꿈')),
                ),
              ]),
            ),
            const SizedBox(height: 600),
          ])),
      scale: 1.0,
    );
    await tester.tap(find.byType(SwitchbackMark));
    await tester.pump();
    expect(find.text('말풍선 문구'), findsOneWidget);
    // 말풍선 문구를 눌러도 닫히지 않는다
    await tester.tap(find.text('말풍선 문구'));
    await tester.pump();
    expect(find.text('말풍선 문구'), findsOneWidget);
    await tester.tapAt(const Offset(300, 500));
    await tester.pump();
    expect(find.text('말풍선 문구'), findsNothing);
  });

  test('한국어 조사는 받침에 따라 붙는다', () {
    expect(withKoreanRo('도호쿠 본선'), '도호쿠 본선으로');
    expect(withKoreanRo('모노레일'), '모노레일로');
    expect(withKoreanRo('나가라가와 철도'), '나가라가와 철도로');
    expect(withKoreanRo('JR'), 'JR(으)로');
  });
}
