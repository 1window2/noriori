import 'package:flutter/material.dart';
import 'package:noriori_core/noriori_core.dart';

import '../theme/app_theme.dart';

/// 노선을 실제 길이로 편 띠. 탄 자리에 칠한다 (DESIGN §1.5 가로 스트립).
class LineStripBar extends StatelessWidget {
  const LineStripBar({super.key, required this.strip});

  final LineStrip strip;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return SizedBox(
      height: 12,
      width: double.infinity,
      child: CustomPaint(
        painter: _StripPainter(strip: strip, base: tokens.track, ridden: tokens.lineRidden),
      ),
    );
  }
}

class _StripPainter extends CustomPainter {
  const _StripPainter({required this.strip, required this.base, required this.ridden});

  final LineStrip strip;
  final Color base;
  final Color ridden;

  static const _minWidth = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, y - 1, size.width, 2),
        const Radius.circular(1),
      ),
      Paint()..color = strip.complete ? ridden : base,
    );
    final total = strip.totalMeters;
    if (total <= 0) return;
    final paint = Paint()..color = ridden;
    for (final segment in strip.segments) {
      final left = size.width * segment.from / total;
      final right = size.width * segment.to / total;
      final width = (right - left).clamp(_minWidth, size.width);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left.clamp(0, size.width - width), y - 4, width, 8),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StripPainter old) =>
      old.strip != strip || old.base != base || old.ridden != ridden;
}
