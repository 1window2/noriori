import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/date_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/meter.dart';
import '../../../i18n/strings.g.dart';
import '../controller/record_session_controller.dart';

/// 지금 떠 있는 승차권. 새 표가 오면 먼저 치운다.
OverlayEntry? _shownTicket;

/// 저장 확인. 표 한 장이 위에서 내려오고 5초 뒤 사라진다. 흐름을 막지 않는다 (DESIGN §8.0).
void showRideTicket(
  BuildContext context,
  RideTicketData data, {
  required bool demoted,
  required VoidCallback onUndo,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  if (_shownTicket?.mounted ?? false) _shownTicket!.remove();
  late final OverlayEntry entry;
  void close() {
    if (entry.mounted) entry.remove();
  }

  entry = OverlayEntry(
    builder: (context) => _TicketDrop(
      onDone: close,
      child: RideTicket(
        data: data,
        demoted: demoted,
        onUndo: () {
          close();
          onUndo();
        },
      ),
    ),
  );
  _shownTicket = entry;
  overlay.insert(entry);
}

class _TicketDrop extends StatefulWidget {
  const _TicketDrop({required this.onDone, required this.child});

  final VoidCallback onDone;
  final Widget child;

  @override
  State<_TicketDrop> createState() => _TicketDropState();
}

class _TicketDropState extends State<_TicketDrop> with SingleTickerProviderStateMixin {
  late final _slide = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _slide.forward();
    _timer = Timer(const Duration(seconds: 5), _leave);
  }

  Future<void> _leave() async {
    _timer?.cancel();
    if (!mounted) return;
    await _slide.reverse();
    widget.onDone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _slide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SlideTransition(
              position: Tween(begin: const Offset(0, -1.4), end: Offset.zero)
                  .animate(CurvedAnimation(parent: _slide, curve: Curves.easeOut)),
              child: GestureDetector(
                onVerticalDragEnd: (drag) {
                  if ((drag.primaryVelocity ?? 0) < 0) _leave();
                },
                // 오버레이에는 글자 기본 모양이 없다
                child: Material(type: MaterialType.transparency, child: widget.child),
              ),
            ),
          ),
        ),
      );
}

class RideTicket extends StatelessWidget {
  const RideTicket({
    super.key,
    required this.data,
    required this.demoted,
    required this.onUndo,
  });

  final RideTicketData data;
  final bool demoted;
  final VoidCallback onUndo;

  static const _stubWidth = 98.0;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    final t = context.t.ticket;
    final raw = data.dateInput;
    final before = data.before;
    final after = data.after;
    return PhysicalShape(
      clipper: const _TicketShape(stubWidth: _stubWidth),
      color: tokens.paper,
      elevation: 8,
      shadowColor: Colors.black54,
      child: CustomPaint(
        painter: _Perforation(color: tokens.track, stubWidth: _stubWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 0, 12),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    spacing: 2,
                    children: [
                      Text(data.lineName, style: text.labelMedium),
                      Text(
                        '${data.fromName} → ${data.toName}',
                        style: text.titleLarge?.copyWith(fontSize: 22),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        [
                          if (raw == null) t.noDate else dateText(context.t, raw),
                          '${kmLabel(data.meters)} km',
                        ].join(' · '),
                        style: text.bodySmall,
                      ),
                      if (demoted)
                        Text(
                          t.savedUnknown,
                          style: text.labelSmall,
                          maxLines: 2,
                        )
                      else if (before != null && after != null) ...[
                        const SizedBox(height: 6),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: before.ratio, end: after.ratio),
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) => Meter(
                            ratio: value,
                            height: 6,
                            under: after.ratio,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${percentLabel(before)} → ${percentLabel(after)}',
                          style: text.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: tokens.text,
                          ),
                        ),
                      ],
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onUndo,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 16, right: 16),
                          child: Text(
                            t.undo,
                            style: text.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: tokens.lineRidden,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: _stubWidth,
                child: Center(
                  child: RideStamp(
                    label: data.completed ? t.completeStamp : t.rideStamp,
                    date: raw,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RideStamp extends StatelessWidget {
  const RideStamp({super.key, required this.label, required this.date});

  final String label;
  final String? date;

  @override
  Widget build(BuildContext context) {
    final color = context.tokens.lineClosedRidden;
    final day = date;
    final short = day != null && DateSpan.parse(day).isDay
        ? '${int.parse(day.substring(5, 7))}.${int.parse(day.substring(8, 10))}'
        : null;
    return Transform.rotate(
      angle: -10 * math.pi / 180,
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2.5),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 일본어 글자라 일본어 글꼴 모양으로 그린다
            Text(
              label,
              locale: const Locale('ja'),
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            if (short != null)
              Text(
                short,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
          ),
        ),
      ),
    );
  }
}

/// 표의 윤곽. 절취선 양 끝에 구멍이 있다.
class _TicketShape extends CustomClipper<Path> {
  const _TicketShape({required this.stubWidth});

  final double stubWidth;

  static const _radius = 14.0;
  static const _notch = 9.0;

  @override
  Path getClip(Size size) {
    final x = size.width - stubWidth;
    final body = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(_radius),
        ),
      );
    final holes = Path()
      ..addOval(Rect.fromCircle(center: Offset(x, 0), radius: _notch))
      ..addOval(
        Rect.fromCircle(center: Offset(x, size.height), radius: _notch),
      );
    return Path.combine(PathOperation.difference, body, holes);
  }

  @override
  bool shouldReclip(_TicketShape old) => old.stubWidth != stubWidth;
}

class _Perforation extends CustomPainter {
  const _Perforation({required this.color, required this.stubWidth});

  final Color color;
  final double stubWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width - stubWidth;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    for (var y = 12.0; y < size.height - 10; y += 10) {
      canvas.drawLine(Offset(x, y), Offset(x, y + 5), paint);
    }
  }

  @override
  bool shouldRepaint(_Perforation old) =>
      old.color != color || old.stubWidth != stubWidth;
}
