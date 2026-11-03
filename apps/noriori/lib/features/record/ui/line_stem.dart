import 'package:flutter/material.dart';

/// 세로 노선도의 왼쪽 칸 너비.
const lineStemColumn = 56.0;

/// 줄기와 역 점. 위아래 구간 색이 다를 수 있어 역 가운데에서 나눠 그린다.
class LineNodePainter extends CustomPainter {
  const LineNodePainter({
    required this.above,
    required this.aboveWidth,
    required this.below,
    required this.belowWidth,
    required this.ring,
    required this.fill,
  });

  final Color? above;
  final double aboveWidth;
  final Color? below;
  final double belowWidth;
  final Color ring;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    const x = lineStemColumn / 2;
    final y = size.height / 2;
    if (above != null) {
      canvas.drawRect(Rect.fromLTRB(x - aboveWidth / 2, 0, x + aboveWidth / 2, y), Paint()..color = above!);
    }
    if (below != null) {
      canvas.drawRect(
        Rect.fromLTRB(x - belowWidth / 2, y, x + belowWidth / 2, size.height),
        Paint()..color = below!,
      );
    }
    canvas.drawCircle(Offset(x, y), 8, Paint()..color = fill);
    canvas.drawCircle(
      Offset(x, y),
      8,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(LineNodePainter old) =>
      old.above != above ||
      old.aboveWidth != aboveWidth ||
      old.below != below ||
      old.belowWidth != belowWidth ||
      old.ring != ring ||
      old.fill != fill;
}
