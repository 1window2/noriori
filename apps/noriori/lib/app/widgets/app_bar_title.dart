import 'package:flutter/material.dart';

import '../../features/record/ui/session_lines.dart' show fitLongWord;

/// 머리글 제목이 한 줄에 다 들어가지 않으면 두 줄로 접고, 늘어난 줄 높이만큼 머리글을 키운다.
/// 긴 노선 이름(大阪市電松島南恩加島線·秋田内陸縦貫鉄道秋田内陸線)이 큰 글자에서 「大阪市電松島南…」로 잘려 어느 노선인지 알 수 없었다 (기기 순회 2026-11-26).
/// 두 줄로도 넘치면 세 줄까지 접는다(영어 「Toden Ochanomizu Line」도 단추 둘 옆에서는 두 줄에 안 들어갔다, 기기 순회 2026-11-26).
/// 세 줄로도 넘치면 마지막 줄 끝을 말줄임한다. [room]은 제목이 쓸 수 있는 폭이다.
/// 줄을 접어도 낱말 하나가 폭보다 길면(「Tenjimbashinishisuji」) 낱말 가운데서 끊기므로, 그 낱말이 한 줄에 들도록 글자를 줄인 꼴([style])도 돌려준다 (기기 순회 2026-11-26).
({int lines, double? toolbarHeight, TextStyle? style}) fitAppBarTitle(BuildContext context, String title, TextStyle? baseStyle, double room, {int maxLines = 3}) {
  final scaler = MediaQuery.textScalerOf(context);
  final style = fitLongWord(context, title, baseStyle, room);
  TextPainter paint(int maxLines) => TextPainter(
        text: TextSpan(text: title, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        locale: Localizations.maybeLocaleOf(context),
        maxLines: maxLines,
      )..layout(maxWidth: room < 1 ? 1 : room);
  final one = paint(1);
  if (!one.didExceedMaxLines) return (lines: 1, toolbarHeight: null, style: style);
  var lines = 2;
  var many = paint(lines);
  while (many.didExceedMaxLines && lines < maxLines) {
    many = paint(++lines);
  }
  return (lines: lines, toolbarHeight: kToolbarHeight + many.height - one.height, style: style);
}
