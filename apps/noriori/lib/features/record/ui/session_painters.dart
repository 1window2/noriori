import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:noriori_core/noriori_core.dart';

/// 왼쪽 그림 열의 자 (DESIGN §8.1). 글자는 [textX]부터 한 열이다.
abstract final class SelectorRuler {
  static const trunkX = 66.0;
  static const dotGap = 18.0;
  static const stemX = 82.0;
  static const nodeX = 99.0;
  static const textX = 114.0;
  static const bend = 6.0;
  static const openWidth = 7.0;
  static const closedWidth = 4.0;
}

/// 줄기 한 칸.
final class TrunkPiece {
  const TrunkPiece(this.color, this.width, {this.dashed = false});

  final Color color;
  final double width;

  /// 고른 구간 중 처음 타는 곳. 이미 탄 곳은 실선이다.
  final bool dashed;
}

void _trunk(Canvas canvas, TrunkPiece? piece, double from, double to) {
  if (piece == null) return;
  final paint = Paint()
    ..color = piece.color
    ..strokeWidth = piece.width;
  const x = SelectorRuler.trunkX;
  if (!piece.dashed) {
    canvas.drawLine(Offset(x, from), Offset(x, to), paint);
    return;
  }
  for (var y = from; y < to; y += 15) {
    canvas.drawLine(Offset(x, y), Offset(x, math.min(y + 10, to)), paint);
  }
}

Paint _stroke(Color color, [double width = 2]) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width;

/// 환승 점 하나.
final class TransferDot {
  const TransferDot({required this.flow, required this.color, this.number});

  final TransferFlow flow;
  final Color color;
  final int? number;
}

/// 역 줄의 그림. 줄기, 분기 어깨, 환승 캡슐, 역 원.
class StopPainter extends CustomPainter {
  const StopPainter({
    required this.centerY,
    required this.above,
    required this.below,
    required this.ring,
    required this.fill,
    required this.background,
    required this.radius,
    required this.ringWidth,
    required this.selected,
    required this.selectColor,
    required this.dots,
    required this.capsule,
    this.stemUp,
    this.stemDown,
  });

  final double centerY;
  final TrunkPiece? above;
  final TrunkPiece? below;
  final Color ring;
  final Color fill;
  final Color background;
  final double radius;
  final double ringWidth;
  final bool selected;
  final Color selectColor;
  final List<TransferDot> dots;
  final Color? capsule;
  final Color? stemUp;
  final Color? stemDown;

  @override
  void paint(Canvas canvas, Size size) {
    const x = SelectorRuler.trunkX;
    final y = centerY;
    _trunk(canvas, above, 0, y);
    _trunk(canvas, below, y, size.height);
    const sx = SelectorRuler.stemX;
    const r = SelectorRuler.bend;
    final up = stemUp;
    if (up != null) {
      canvas.drawPath(
        Path()
          ..moveTo(x, y)
          ..lineTo(sx - r, y)
          ..arcToPoint(const Offset(sx, 0) + Offset(0, y - r), radius: const Radius.circular(r), clockwise: false)
          ..lineTo(sx, 0),
        _stroke(up, 2.5),
      );
    }
    final down = stemDown;
    if (down != null) {
      canvas.drawPath(
        Path()
          ..moveTo(x, y)
          ..lineTo(sx - r, y)
          ..arcToPoint(Offset(sx, y + r), radius: const Radius.circular(r))
          ..lineTo(sx, size.height),
        _stroke(down, 2.5),
      );
    }
    final n = dots.length;
    if (n > 0) {
      for (final (index, dot) in dots.indexed) {
        final cx = x - SelectorRuler.dotGap * (n - index);
        final goesUp = dot.flow == TransferFlow.through || dot.flow == TransferFlow.up;
        final goesDown = dot.flow == TransferFlow.through || dot.flow == TransferFlow.down;
        void leg(double sign) {
          canvas.drawLine(Offset(cx, y), Offset(cx, y + sign * 18), _stroke(dot.color));
          canvas.drawLine(
            Offset(cx, y + sign * 21),
            Offset(cx, y + sign * 24),
            _stroke(dot.color.withValues(alpha: .8)),
          );
          canvas.drawLine(
            Offset(cx, y + sign * 26),
            Offset(cx, y + sign * 28),
            _stroke(dot.color.withValues(alpha: .45)),
          );
        }

        if (goesUp) leg(-1);
        if (goesDown) leg(1);
      }
      final left = x - SelectorRuler.dotGap * n - 10;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(left, y - 13, x + 13, y + 13),
          const Radius.circular(13),
        ),
        _stroke(capsule ?? dots.first.color, 1.5),
      );
      for (final (index, dot) in dots.indexed) {
        final cx = x - SelectorRuler.dotGap * (n - index);
        final numbered = dot.number != null;
        final rd = numbered ? 6.5 : 4.5;
        canvas.drawCircle(Offset(cx, y), rd, Paint()..color = background);
        canvas.drawCircle(Offset(cx, y), rd, _stroke(dot.color, numbered ? 1.6 : 1));
        if (numbered) _number(canvas, '${dot.number}', Offset(cx, y), dot.color);
      }
    }
    canvas.drawCircle(Offset(x, y), radius, Paint()..color = fill);
    canvas.drawCircle(Offset(x, y), radius, _stroke(ring, ringWidth));
    if (selected) canvas.drawCircle(Offset(x, y), 13, _stroke(selectColor));
  }

  void _number(Canvas canvas, String label, Offset at, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at - Offset(painter.width / 2, painter.height / 2));
    painter.dispose();
  }

  @override
  bool shouldRepaint(StopPainter old) =>
      old.centerY != centerY ||
      old.above?.color != above?.color ||
      old.below?.color != below?.color ||
      old.ring != ring ||
      old.fill != fill ||
      old.selected != selected ||
      old.dots.length != dots.length ||
      old.stemUp != stemUp ||
      old.stemDown != stemDown;
}

/// 분기 줄의 그림. 어깨에서 내려온 곡선이 작은 원으로 끝난다.
class BranchPainter extends CustomPainter {
  const BranchPainter({
    required this.trunk,
    required this.color,
    required this.stem,
    required this.through,
    required this.background,
    required this.up,
    required this.stacked,
    required this.centerY,
    this.fromTrunk = false,
  });

  /// 역이 아니라 줄기에서 바로 갈라진다.
  final bool fromTrunk;
  final TrunkPiece? trunk;

  /// 이 분기의 곡선과 원.
  final Color color;

  /// 역에서 이 줄까지 오는 줄기. 바깥 줄이 현행이면 이 줄이 폐선이어도 현행색이다.
  final Color stem;

  /// 이 줄을 지나 바깥 줄로 가는 줄기.
  final Color through;
  final Color background;
  final bool up;
  final bool stacked;
  final double centerY;

  @override
  void paint(Canvas canvas, Size size) {
    _trunk(canvas, trunk, 0, size.height);
    const sx = SelectorRuler.stemX;
    const r = SelectorRuler.bend;
    const q = SelectorRuler.nodeX;
    final y = centerY;
    // 줄기를 먼저 그린다. 곡선은 그 위로 지나간다
    if (!fromTrunk) {
      final near = up ? size.height : 0.0;
      final far = up ? 0.0 : size.height;
      final bend = up ? y + r : y - r;
      if (stacked) canvas.drawLine(Offset(sx, bend), Offset(sx, far), _stroke(through, 2.5));
      canvas.drawLine(Offset(sx, near), Offset(sx, bend), _stroke(stem, 2.5));
    }
    final path = Path();
    if (fromTrunk) {
      const x = SelectorRuler.trunkX;
      path
        ..moveTo(x, y - r - 6)
        ..lineTo(x, y - r)
        ..arcToPoint(Offset(x + r, y), radius: const Radius.circular(r), clockwise: false)
        ..lineTo(q - 5, y);
    } else if (up) {
      path
        ..moveTo(sx, y + r)
        ..arcToPoint(Offset(sx + r, y), radius: const Radius.circular(r))
        ..lineTo(q - 5, y);
    } else {
      path
        ..moveTo(sx, y - r)
        ..arcToPoint(Offset(sx + r, y), radius: const Radius.circular(r), clockwise: false)
        ..lineTo(q - 5, y);
    }
    canvas.drawPath(path, _stroke(color, 2.5));
    canvas.drawCircle(Offset(q, y), 5, Paint()..color = background);
    canvas.drawCircle(Offset(q, y), 5, _stroke(color, 1.5));
  }

  @override
  bool shouldRepaint(BranchPainter old) =>
      old.trunk?.color != trunk?.color ||
      old.color != color ||
      old.stem != stem ||
      old.through != through ||
      old.centerY != centerY;
}

/// 줄기 끝에서 이어지는 점선.
class EndPainter extends CustomPainter {
  const EndPainter({required this.color, required this.up});

  final Color color;
  final bool up;

  @override
  void paint(Canvas canvas, Size size) {
    const x = SelectorRuler.trunkX;
    final length = math.min(size.height, 34.0);
    final paint = _stroke(color);
    for (var at = 0.0; at < length; at += 7) {
      final y = up ? size.height - at : at;
      canvas.drawLine(Offset(x, y), Offset(x, up ? y - 3 : y + 3), paint);
    }
  }

  @override
  bool shouldRepaint(EndPainter old) => old.color != color || old.up != up;
}

/// 열람 전용 역과 경계 줄의 그림.
class PlainPainter extends CustomPainter {
  const PlainPainter({
    required this.above,
    required this.below,
    this.node,
    this.dash,
    this.centerY = 18,
  });

  final TrunkPiece? above;
  final TrunkPiece? below;
  final Color? node;
  final Color? dash;
  final double centerY;

  @override
  void paint(Canvas canvas, Size size) {
    _trunk(canvas, above, 0, centerY);
    _trunk(canvas, below, centerY, size.height);
    final color = node;
    if (color != null) {
      canvas.drawCircle(const Offset(SelectorRuler.trunkX, 0) + Offset(0, centerY), 4.5,
          Paint()..color = color);
    }
    final line = dash;
    if (line != null) {
      for (var x = 20.0; x < size.width - 16; x += 8) {
        canvas.drawLine(Offset(x, 0.5), Offset(x + 4, 0.5), _stroke(line, 1));
      }
    }
  }

  @override
  bool shouldRepaint(PlainPainter old) =>
      old.above?.color != above?.color || old.below?.color != below?.color || old.node != node;
}
