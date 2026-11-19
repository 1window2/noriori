import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:noriori_core/noriori_core.dart';

/// 왼쪽 그림 열의 자 (DESIGN §8.1). 글자는 [textX]부터 한 열이다.
abstract final class SelectorRuler {
  static const trunkX = 76.0;
  static const dotGap = 17.0;
  /// 역 원 중심에서 가장 가까운 환승 점 중심까지. 역 원 테(반지름 8.5, 굵기 3.5)와 번호 점 테 사이가 점끼리와 같게 띄운다.
  /// 점 자리는 모든 줄에서 같아 환승 점이 하나인 줄도 같은 칸에 선다
  static const nodeGap = 20.0;
  /// 캡슐 끝의 반원은 끝 점과 같은 중심이다. 캡슐은 화면 끝에서 [edge] 이상 떨어진다
  static const capsuleRadius = 13.0;
  static const edge = 8.0;
  static const stemX = 92.0;
  static const nodeX = 109.0;
  static const textX = 124.0;
  static const bend = 6.0;
  static const openWidth = 7.0;
  static const closedWidth = 4.0;
}

/// 줄기 한 칸.
final class TrunkPiece {
  const TrunkPiece(this.color, this.width, {this.dashed = false, this.oneWay});

  final Color color;
  final double width;

  /// 고른 구간 중 처음 타는 곳. 이미 탄 곳은 실선이다.
  final bool dashed;

  /// 한 방향으로만 다니는 칸. 참이면 목록 아래로, 거짓이면 위로 간다 (DESIGN §8 한 방향 운행).
  final bool? oneWay;
}

/// 한 방향 칸의 갈매기표. 줄기 위에 바탕색으로 진행 방향을 향해 꺾인 표시를 그린다 (사용자 결정 2026-11-12).
void _chevron(Canvas canvas, TrunkPiece? piece, double y, Color background) {
  final down = piece?.oneWay;
  if (down == null) return;
  const x = SelectorRuler.trunkX;
  final tip = down ? 2.0 : -2.0;
  canvas.drawPath(
    Path()
      ..moveTo(x - 3.5, y - tip)
      ..lineTo(x, y + tip)
      ..lineTo(x + 3.5, y - tip),
    Paint()
      ..color = background
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round,
  );
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

/// 병주 선의 자리 (DESIGN §8.1). 환승 캡슐 오른쪽 끝(줄기+13)과 점(반지름 4)이 닿지 않게 분기 어깨보다 4 바깥이고,
/// 겹치는 토막은 분기 원(nodeX−5) 앞까지 6씩 더 비켜 선다
double laneX(int lane) => SelectorRuler.stemX + 4 + 6.0 * lane;

/// 병주 선의 색.
final class LaneStyle {
  const LaneStyle({required this.color, required this.gone, required this.background});

  final Color color;
  final Color gone;
  final Color background;
}

/// 줄을 지나는 병주 선. 상대도 서는 역에는 작은 점, 상대의 기점·종점은 역 노드에서 꺾인다.
void paintLanes(Canvas canvas, Size size, List<LaneMark> lanes, LaneStyle? style, double centerY) {
  if (style == null || lanes.isEmpty) return;
  const x = SelectorRuler.trunkX;
  const r = SelectorRuler.bend;
  final y = centerY;
  for (final mark in lanes) {
    final lx = laneX(mark.lane);
    final paint = _stroke(mark.gone ? style.gone : style.color, 2.5);
    switch (mark.role) {
      case LaneRole.pass || LaneRole.stop:
        canvas.drawLine(Offset(lx, 0), Offset(lx, size.height), paint);
      case LaneRole.startNode:
        canvas.drawPath(
          Path()
            ..moveTo(x, y)
            ..lineTo(lx - r, y)
            ..arcToPoint(Offset(lx, y + r), radius: const Radius.circular(r))
            ..lineTo(lx, size.height),
          paint,
        );
      case LaneRole.endNode:
        canvas.drawPath(
          Path()
            ..moveTo(lx, 0)
            ..lineTo(lx, y - r)
            ..arcToPoint(Offset(lx - r, y), radius: const Radius.circular(r))
            ..lineTo(x, y),
          paint,
        );
    }
  }
  for (final mark in lanes) {
    if (mark.role != LaneRole.stop) continue;
    final at = Offset(laneX(mark.lane), y);
    canvas.drawCircle(at, 4, Paint()..color = style.background);
    canvas.drawCircle(at, 4, _stroke(mark.gone ? style.gone : style.color, 2));
  }
}

/// 3 그리고 4 쉬는 점선. 끝 이어짐 점선과 같은 박자다. [start]만큼 비우고 시작한다
void _dashed(Canvas canvas, Path path, Paint paint, {double start = 0}) {
  for (final metric in path.computeMetrics()) {
    for (var at = start; at < metric.length; at += 7) {
      canvas.drawPath(metric.extractPath(at, math.min(at + 3, metric.length)), paint);
    }
  }
}

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
    this.lanes = const [],
    this.laneStyle,
    this.endUp,
    this.endDown,
  });

  final List<LaneMark> lanes;
  final LaneStyle? laneStyle;

  /// 줄기가 다른 노선으로 이어지는 쪽의 색. 역 노드에서 줄 끝까지 실선이고, 바깥 끝 이어짐 줄에서 점선이 된다
  final Color? endUp;
  final Color? endDown;
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
    _chevron(canvas, below, (y + size.height) / 2 + 4, background);
    final eu = endUp;
    if (eu != null && above == null) canvas.drawLine(const Offset(x, 0), Offset(x, y), _stroke(eu, 2.5));
    final ed = endDown;
    if (ed != null && below == null) canvas.drawLine(Offset(x, y), Offset(x, size.height), _stroke(ed, 2.5));
    const sx = SelectorRuler.stemX;
    const r = SelectorRuler.bend;
    // 끝 역 너머로 줄기가 이어지면(폐지 구간·열람 전용 줄) 끝 이어짐은 분기처럼 어깨로 비켜 나간다
    final up = stemUp ?? (above != null ? eu : null);
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
    final down = stemDown ?? (below != null ? ed : null);
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
    paintLanes(canvas, size, lanes, laneStyle, y);
    final n = dots.length;
    if (n > 0) {
      // 점이 많으면 간격을 줄여 캡슐이 화면 끝에 닿지 않게 한다
      const room = x - SelectorRuler.nodeGap - SelectorRuler.capsuleRadius - SelectorRuler.edge;
      final gap = n > 1 ? math.min(SelectorRuler.dotGap, room / (n - 1)) : 0.0;
      double cxOf(int index) => x - SelectorRuler.nodeGap - gap * (n - 1 - index);
      for (final (index, dot) in dots.indexed) {
        final cx = cxOf(index);
        final goesUp = dot.flow == TransferFlow.through || dot.flow == TransferFlow.up;
        final goesDown = dot.flow == TransferFlow.through || dot.flow == TransferFlow.down;
        // 환승 다리는 자기 줄 안에서만 그린다. 줄이 낮으면(환승 모음 한 줄·없음) 위 줄의 아래 다리와 이 줄의 위 다리가 겹쳤다.
        // 길이를 줄 끝까지 남은 높이(끝 2px 비움)로 줄이고, 실선·흐린 점의 비율은 그대로 둔다 (2026-11-19 사용자 지적)
        void leg(double sign) {
          final room = (sign > 0 ? size.height - y : y) - 2;
          final l = math.min(28.0, math.max(0.0, room));
          if (l <= 0) return;
          canvas.drawLine(Offset(cx, y), Offset(cx, y + sign * l * 18 / 28), _stroke(dot.color));
          canvas.drawLine(
            Offset(cx, y + sign * l * 21 / 28),
            Offset(cx, y + sign * l * 24 / 28),
            _stroke(dot.color.withValues(alpha: .8)),
          );
          canvas.drawLine(
            Offset(cx, y + sign * l * 26 / 28),
            Offset(cx, y + sign * l),
            _stroke(dot.color.withValues(alpha: .45)),
          );
        }

        if (goesUp) leg(-1);
        if (goesDown) leg(1);
      }
      const cr = SelectorRuler.capsuleRadius;
      final left = cxOf(0) - cr;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(left, y - cr, x + cr, y + cr),
          const Radius.circular(cr),
        ),
        _stroke(capsule ?? dots.first.color, 1.5),
      );
      for (final (index, dot) in dots.indexed) {
        final cx = cxOf(index);
        final numbered = dot.number != null;
        // 간격이 줄면 원도 줄여 이웃 원과 겹치지 않게 한다
        final rd = numbered ? math.min(6.5, n > 1 ? gap / 2 - 1 : 6.5) : math.min(4.5, n > 1 ? gap / 2 - 1 : 4.5);
        canvas.drawCircle(Offset(cx, y), rd, Paint()..color = background);
        canvas.drawCircle(Offset(cx, y), rd, _stroke(dot.color, numbered ? 1.6 : 1));
        if (numbered) _number(canvas, '${dot.number}', Offset(cx, y), dot.color, 9.5 * rd / 6.5);
      }
    }
    canvas.drawCircle(Offset(x, y), radius, Paint()..color = fill);
    canvas.drawCircle(Offset(x, y), radius, _stroke(ring, ringWidth));
    if (selected) canvas.drawCircle(Offset(x, y), 13, _stroke(selectColor));
  }

  void _number(Canvas canvas, String label, Offset at, Color color, double size) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(fontSize: size, fontWeight: FontWeight.w700, color: color),
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
      old.below?.oneWay != below?.oneWay ||
      old.ring != ring ||
      old.fill != fill ||
      old.selected != selected ||
      old.dots.length != dots.length ||
      old.stemUp != stemUp ||
      old.stemDown != stemDown ||
      old.endUp != endUp ||
      old.endDown != endDown ||
      old.lanes.length != lanes.length;
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
    this.parallel,
    this.endThrough,
    this.lanes = const [],
    this.laneStyle,
    this.fromStop = true,
  });

  /// 역 바로 옆 줄이다 (EndPainter.fromStop과 같음).
  final bool fromStop;

  /// 끝 너머의 끝 이어짐으로 가는 줄기 점선의 색. 이 줄을 곧게 지나간다 (분기만 오른쪽으로 꺾음)
  final Color? endThrough;

  /// 병주 상대가 들고 나는 줄이면 그 병주 선의 자리. 곡선이 그 선에서 나온다.
  final int? parallel;
  final List<LaneMark> lanes;
  final LaneStyle? laneStyle;

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
    final dots = endThrough;
    if (dots != null) {
      // 줄기가 이 줄을 지나가면 끝 이어짐 점선은 분기 줄기 칸으로 비켜 선다 (EndPainter와 같음)
      final x = trunk == null ? SelectorRuler.trunkX : SelectorRuler.stemX;
      final paint = _stroke(dots);
      // 지나가는 줄기는 끝 이어짐 줄들과 같은 박자로 긋는다 (EndPainter와 같음)
      _stacked((at) {
        final dy = up ? size.height - at : at;
        canvas.drawLine(Offset(x, dy), Offset(x, up ? dy - 3 : dy + 3), paint);
      }, size.height, first: fromStop);
    }
    const sx = SelectorRuler.stemX;
    const r = SelectorRuler.bend;
    const q = SelectorRuler.nodeX;
    final y = centerY;
    paintLanes(canvas, size, lanes, laneStyle, y);
    final lane = parallel;
    if (lane != null) {
      // 바깥의 다른 분기로 가는 줄기는 그대로 지나간다
      if (stacked) canvas.drawLine(const Offset(sx, 0), Offset(sx, size.height), _stroke(through, 2.5));
      final lx = laneX(lane);
      final path = up
          ? (Path()
            ..moveTo(q - 5, y)
            ..lineTo(lx + r, y)
            ..arcToPoint(Offset(lx, y + r), radius: const Radius.circular(r), clockwise: false)
            ..lineTo(lx, size.height))
          : (Path()
            ..moveTo(lx, 0)
            ..lineTo(lx, y - r)
            ..arcToPoint(Offset(lx + r, y), radius: const Radius.circular(r), clockwise: false)
            ..lineTo(q - 5, y));
      canvas.drawPath(path, _stroke(color, 2.5));
      canvas.drawCircle(Offset(q, y), 5, Paint()..color = background);
      canvas.drawCircle(Offset(q, y), 5, _stroke(color, 1.5));
      return;
    }
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
      old.fromStop != fromStop ||
      old.endThrough != endThrough ||
      old.trunk?.color != trunk?.color ||
      old.color != color ||
      old.stem != stem ||
      old.through != through ||
      old.centerY != centerY ||
      old.parallel != parallel ||
      old.lanes.length != lanes.length;
}

/// 줄기 끝에서 이어지는 점선.
/// 여러 줄에 걸친 점선 한 줄기. 줄마다 빈틈으로 끝나고 다음 줄은 점선으로 시작해, 경계에서 점선이 붙거나 겹치지 않는다.
/// 역에 붙은 첫 줄만 4를 비우고 시작한다. 간격은 줄 높이에 맞춰 7 언저리로 고르게 늘인다 (실화면 검수 2026-11-08, 和歌山)
void _stacked(void Function(double at) dash, double height, {required bool first}) {
  final start = first ? 4.0 : 0.0;
  final count = math.max(1, ((height - start) / 7).round());
  final step = (height - start) / count;
  for (var i = 0; i < count; i++) {
    dash(start + step * i);
  }
}

class EndPainter extends CustomPainter {
  const EndPainter({
    required this.color,
    required this.up,
    this.parallel,
    this.trunkThrough = false,
    this.stackAt = 0,
    this.stackOf = 1,
    this.lanes = const [],
    this.laneStyle,
    this.fromStop = true,
    this.trunk,
  });

  final Color color;
  final bool up;

  /// 끝 역 너머로 이어지는 줄기 한 칸. 있으면 줄기를 곧게 긋고 끝 이어짐 점선은 분기 줄의 칸으로 비켜 선다
  final TrunkPiece? trunk;

  /// 역 바로 옆 줄이다. 점선은 역 쪽 끝에서 4를 비우고 시작하고, 분기 줄 너머의 줄은 앞 줄의 박자를 이어 바로 시작한다.
  final bool fromStop;

  /// 같은 끝에 노선이 여럿이면 모든 줄에 점선을 줄 끝까지 이어 긋는다. [stackAt] 0이 역에 가장 가까운 줄이다 (A안)
  final int stackAt;
  final int stackOf;

  /// 끝 너머에서 들고 나는 병주 상대면 그 병주 선의 자리. 점선이 그 선에서 꺾여 글씨로 간다(B′, 끝 줄 3안).
  final int? parallel;

  /// 바깥의 다른 끝 이어짐으로 가는 줄기 점선이 이 줄을 지나간다.
  final bool trunkThrough;
  final List<LaneMark> lanes;
  final LaneStyle? laneStyle;

  @override
  void paint(Canvas canvas, Size size) {
    _trunk(canvas, trunk, 0, size.height);
    final x = trunk == null ? SelectorRuler.trunkX : SelectorRuler.stemX;
    final y = size.height / 2;
    paintLanes(canvas, size, lanes, laneStyle, y);
    final paint = _stroke(color);
    // 점선은 모두 역 쪽 끝에서 4를 비우고 시작한다. 역 줄의 실선이 줄기와 병주 선에서 같은 길이로 끝난다
    void dash(double at) {
      final dy = up ? size.height - at : at;
      canvas.drawLine(Offset(x, dy), Offset(x, up ? dy - 3 : dy + 3), paint);
    }

    final lane = parallel;
    if (lane != null) {
      if (trunkThrough) _stacked(dash, size.height, first: fromStop);
      const r = SelectorRuler.bend;
      const tx = SelectorRuler.textX - 8;
      final lx = laneX(lane);
      _dashed(
        canvas,
        up
            ? (Path()
              ..moveTo(lx, size.height)
              ..lineTo(lx, y + r)
              ..arcToPoint(Offset(lx + r, y), radius: const Radius.circular(r))
              ..lineTo(tx, y))
            : (Path()
              ..moveTo(lx, 0)
              ..lineTo(lx, y - r)
              ..arcToPoint(Offset(lx + r, y), radius: const Radius.circular(r), clockwise: false)
              ..lineTo(tx, y)),
        paint,
        start: 4,
      );
      return;
    }
    // 같은 끝의 노선 여럿은 줄마다 점선을 줄 끝까지 이어 맨 바깥 줄까지 한 줄기로 닿는다 (사용자 결정 2026-11-08)
    if (stackOf > 1) {
      _stacked(dash, size.height, first: fromStop);
      return;
    }
    final length = math.min(size.height, 38.0);
    for (var at = fromStop ? 4.0 : 0.0; at + 3 <= length; at += 7) {
      dash(at);
    }
  }

  @override
  bool shouldRepaint(EndPainter old) =>
      old.color != color ||
      old.trunk?.color != trunk?.color ||
      old.fromStop != fromStop ||
      old.up != up ||
      old.parallel != parallel ||
      old.stackAt != stackAt ||
      old.stackOf != stackOf ||
      old.lanes.length != lanes.length;
}

/// 열람 전용 역과 경계 줄의 그림.
class PlainPainter extends CustomPainter {
  const PlainPainter({
    required this.above,
    required this.below,
    this.node,
    this.dash,
    this.centerY = 18,
    this.lanes = const [],
    this.laneStyle,
    this.stem,
    this.stemUp = true,
  });

  final List<LaneMark> lanes;
  final LaneStyle? laneStyle;

  /// 끝 이어짐 안쪽 구분선 줄을 지나가는 점선 줄기의 색. [stemUp]이면 역이 아래(위쪽 끝 이어짐으로 간다).
  /// 역 쪽 끝에서 4를 비우고, 줄 높이에 맞춰 박자를 조금 늘여 바깥 끝도 4를 비운다. 다음 끝 이어짐 줄은 박자를 이어 바로 시작해
  /// 줄 경계에서 점이 겹치거나 벌어지지 않는다 (사용자 결정 2026-11-19)
  final Color? stem;
  final bool stemUp;

  final TrunkPiece? above;
  final TrunkPiece? below;
  final Color? node;
  final Color? dash;
  final double centerY;

  @override
  void paint(Canvas canvas, Size size) {
    _trunk(canvas, above, 0, centerY);
    _trunk(canvas, below, centerY, size.height);
    paintLanes(canvas, size, lanes, laneStyle, centerY);
    final color = node;
    if (color != null) {
      canvas.drawCircle(const Offset(SelectorRuler.trunkX, 0) + Offset(0, centerY), 4.5,
          Paint()..color = color);
    }
    final through = stem;
    if (through != null) {
      const x = SelectorRuler.trunkX;
      final length = size.height - 4;
      final count = math.max(1, (length / 7).round());
      final period = length / count;
      final on = period * 3 / 7;
      for (var i = 0; i < count; i++) {
        final at = 4 + i * period;
        final y = stemUp ? size.height - at : at;
        canvas.drawLine(Offset(x, y), Offset(x, stemUp ? y - on : y + on), _stroke(through));
      }
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
      old.above?.color != above?.color || old.below?.color != below?.color || old.node != node || old.stem != stem || old.stemUp != stemUp;
}
