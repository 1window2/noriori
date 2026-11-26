import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noriori/app/widgets/long_word.dart';

void main() {
  testWidgets('긴 로마자 낱말은 한 줄에 들도록 줄이고, 짧은 이름·한글은 그대로 둔다', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
      child: Builder(builder: (context) {
        ctx = context;
        return const SizedBox();
      }),
    ));
    const base = TextStyle(fontSize: 16);
    final long = fitLongWord(ctx, 'Odawarahigashicho', base, 120)!;
    expect(long.fontSize, lessThan(16));
    expect(long.fontSize, greaterThanOrEqualTo(16 * 0.6 * 0.99 - 0.01));
    expect(fitLongWord(ctx, 'Sendai', base, 200), base);
    expect(fitLongWord(ctx, '오다와라히가시초', base, 60), base);
    expect(fitLongWord(ctx, 'Kami-Nakazato Higashi', base, 400), base);
  });
}
