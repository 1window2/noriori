import 'package:flutter/widgets.dart';

/// 로마자 이름의 가장 긴 낱말이 줄 폭보다 길면 그 낱말이 한 줄에 들도록 글자를 줄인 꼴을 준다(원래 크기의 60%까지. 큰 글자 1.4배에서도 기본 크기의 84%다).
/// 영어 이름은 띄어쓰기·하이픈 말고는 끊을 곳이 없어, 큰 글자에서 「Odawarahigash/icho」처럼 낱말 가운데서 줄이 바뀌었다 (기기 순회 2026-11-26).
/// 한글·한자 이름은 글자 사이에서 끊는 것이 자연스러워 그대로 둔다
TextStyle? fitLongWord(
  BuildContext context,
  String name,
  TextStyle? style,
  double width,
) {
  if (style == null || !RegExp('[A-Za-z]{6,}').hasMatch(name) || width <= 0) {
    return style;
  }
  final scaler = MediaQuery.textScalerOf(context);
  var longest = 0.0;
  for (final word in name.split(RegExp(r'[\s\-‐–]+'))) {
    if (word.length < 6) continue;
    final painter = TextPainter(
      text: TextSpan(text: word, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      locale: Localizations.maybeLocaleOf(context),
      maxLines: 1,
    )..layout();
    if (painter.width > longest) longest = painter.width;
    painter.dispose();
  }
  if (longest <= width) return style;
  final size = style.fontSize ?? 14;
  final factor = (width / longest).clamp(0.6, 1.0);
  return style.copyWith(fontSize: size * factor * 0.99);
}
