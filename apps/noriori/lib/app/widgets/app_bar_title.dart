import 'package:flutter/material.dart';

/// 머리글 제목이 한 줄에 다 들어가지 않으면 두 줄로 접고, 늘어난 줄 높이만큼 머리글을 키운다.
/// 긴 노선 이름(大阪市電松島南恩加島線·秋田内陸縦貫鉄道秋田内陸線)이 큰 글자에서 「大阪市電松島南…」로 잘려 어느 노선인지 알 수 없었다 (기기 순회 2026-11-26).
/// 두 줄로도 넘치면 둘째 줄 끝을 말줄임한다. [room]은 제목이 쓸 수 있는 폭이다.
({int lines, double? toolbarHeight}) fitAppBarTitle(BuildContext context, String title, TextStyle? style, double room) {
  final scaler = MediaQuery.textScalerOf(context);
  TextPainter paint(int maxLines) => TextPainter(
        text: TextSpan(text: title, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: maxLines,
      )..layout(maxWidth: room < 1 ? 1 : room);
  final one = paint(1);
  if (!one.didExceedMaxLines) return (lines: 1, toolbarHeight: null);
  final two = paint(2);
  return (lines: 2, toolbarHeight: kToolbarHeight + two.height - one.height);
}
