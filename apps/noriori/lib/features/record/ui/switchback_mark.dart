import 'package:flutter/material.dart';

import 'one_way_bubble.dart';

/// 끝 역 이어짐 점선 왼쪽의 스위치백 직통 표식 (사용자 확정 디자인, 11회차 S3).
///
/// 둥근 네모 테 안에 두 다리가 꼭대기에서 만나는 ∧ 모양이다. 왼쪽 다리 꼭대기와 오른쪽 다리 끝에 화살촉이 있어
/// 올라갔다가 방향을 바꿔 내려가는 길을 그린다. 방향과 상관없이 한 모양이고, 글자 배율에 맞춰 커진다.
class SwitchbackMarkPainter extends CustomPainter {
  const SwitchbackMarkPainter(this.color);

  final Color color;

  /// 표식 한 변(배율 1). 그림 좌표는 24 그리드를 (2, 1.5) 옮겨 28 칸에 둔다
  static const side = 28.0;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.shortestSide / side;
    canvas.save();
    canvas.scale(k);
    final frame = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(0.75, 0.75, side - 1.5, side - 1.5), const Radius.circular(4)),
      frame,
    );
    canvas.translate(2, 1.5);
    final leg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(4, 20)
        ..quadraticBezierTo(11, 18, 12, 4),
      leg,
    );
    canvas.drawPath(
      Path()
        ..moveTo(12, 4)
        ..quadraticBezierTo(13, 18, 20, 20),
      leg,
    );
    final head = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(
      Path()
        ..moveTo(11.05, 6.2)
        ..lineTo(12.95, 6.2)
        ..lineTo(12, 2.9)
        ..close(),
      head,
    );
    canvas.drawPath(
      Path()
        ..moveTo(21.73, 21.0)
        ..lineTo(17.07, 21.08)
        ..lineTo(19.47, 16.92)
        ..close(),
      head,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(SwitchbackMarkPainter old) => old.color != color;
}

/// 누를 수 있는 스위치백 표식. 눌림 영역은 44 이상이고, 누르면 한 방향 정차 말풍선과 같은 꼴로 [message]를 띄운다.
class SwitchbackMark extends StatelessWidget {
  const SwitchbackMark({super.key, required this.color, required this.message, required this.spoken});

  final Color color;
  final String message;

  /// 화면 읽기 라벨.
  final String spoken;

  /// 글자 배율에 맞춘 표식 한 변.
  static double sideOf(BuildContext context) => MediaQuery.textScalerOf(context).scale(SwitchbackMarkPainter.side);

  /// 눌림 영역 한 변.
  static double hitOf(BuildContext context) => sideOf(context) < 44 ? 44 : sideOf(context);

  @override
  Widget build(BuildContext context) {
    final side = sideOf(context);
    final hit = hitOf(context);
    return Semantics(
      button: true,
      label: spoken,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          final box = context.findRenderObject() as RenderBox?;
          final x = box == null || !box.attached ? null : box.localToGlobal(Offset(hit / 2, 0)).dx;
          OneWayBubble.show(context, title: message, detail: null, action: null, onAction: () {}, anchorX: x);
        },
        child: SizedBox.square(
          dimension: hit,
          child: Center(
            child: CustomPaint(size: Size.square(side), painter: SwitchbackMarkPainter(color)),
          ),
        ),
      ),
    );
  }
}

/// 노선 이름에 한국어 조사 「으로/로」를 붙인다. 받침이 없거나 ㄹ 받침이면 「로」, 한글로 끝나지 않으면 「(으)로」
String withKoreanRo(String name) {
  final code = name.isEmpty ? 0 : name.codeUnitAt(name.length - 1);
  if (code < 0xAC00 || code > 0xD7A3) return '$name(으)로';
  final tail = (code - 0xAC00) % 28;
  return '$name${tail == 0 || tail == 8 ? '로' : '으로'}';
}
