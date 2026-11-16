import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import 'session_painters.dart';

/// 한 방향 운행·정차 때문에 고를 수 없을 때 누른 역 바로 옆에 붙는 말풍선 (DESIGN §8, 사용자 결정 2026-11-12).
///
/// 모양은 시안 C(역 옆 말풍선), 안쪽 아래의 `방향 바꾸기`는 시안 B(기호 붙은 버튼)다. 말풍선 밖을 누르거나 목록을 움직이거나
/// 화면을 떠나면 사라진다.
abstract final class OneWayBubble {
  static OverlayEntry? _entry;
  static Timer? _timer;
  static ScrollPosition? _scroll;

  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _scroll?.removeListener(dismiss);
    _scroll = null;
    _entry?.remove();
    _entry = null;
  }

  /// [detail]이 없으면 제목 한 줄이다. [anchorX]가 있으면 꼬리가 화면의 그 x를 가리킨다(끝 역 스위치백 표식, 11회차 S3)
  static void show(
    BuildContext context, {
    required String title,
    required String? detail,
    required String? action,
    required VoidCallback onAction,
    double? anchorX,
  }) {
    dismiss();
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final overlay = Overlay.of(context);
    final route = ModalRoute.of(context);
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final media = MediaQuery.of(context);
    final origin = box.localToGlobal(Offset.zero);
    // 화면 아래쪽 역이면 위에 띄운다. 기록 막대에 가리지 않게
    final above = origin.dy + box.size.height > media.size.height * 0.6;
    const width = 280.0;
    const tipX = 22.0;
    final left = (anchorX == null ? SelectorRuler.textX - 18 : anchorX - tipX - 7).clamp(8.0, media.size.width - width - 8);
    // 왼쪽 끝에 붙어 밀린 말풍선도 꼬리는 가리키는 자리에 둔다
    final tipLeft = anchorX == null ? tipX : (anchorX - 7 - left).clamp(10.0, width - 24);
    final tip = Padding(
      padding: EdgeInsets.only(left: tipLeft),
      child: CustomPaint(size: const Size(14, 7), painter: _Tip(tokens.text, up: !above)),
    );
    final card = Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 2),
      decoration: BoxDecoration(
        color: tokens.text,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Color(0x42000000), blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.labelLarge?.copyWith(color: tokens.surface)),
                if (detail != null) ...[
                  const SizedBox(height: 2),
                  Text(detail, style: text.bodySmall?.copyWith(color: tokens.surface.withValues(alpha: 0.82))),
                ],
              ],
            ),
          ),
          if (action == null)
            const SizedBox(height: 8)
          else
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.inversePrimary,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.swap_vert, size: 18),
                label: Text(action),
                onPressed: () {
                  dismiss();
                  onAction();
                },
              ),
            ),
        ],
      ),
    );
    _entry = OverlayEntry(
      builder: (_) {
        // 다른 화면이 위에 올라오면 그리지 않는다
        if (route != null && !route.isCurrent) return const SizedBox.shrink();
        return Positioned(
          left: left,
          top: above ? null : origin.dy + box.size.height - 4,
          bottom: above ? media.size.height - origin.dy - 4 : null,
          // 말풍선 밖 어디를 눌러도 닫는다. 누른 자리의 동작(다른 역 고르기 등)은 그대로 간다 (사용자 지적 2026-11-16)
          child: TapRegion(
            onTapOutside: (_) => dismiss(),
            child: Material(
              color: Colors.transparent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: above ? [card, tip] : [tip, card],
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_entry!);
    _scroll = Scrollable.maybeOf(context)?.position;
    _scroll?.addListener(dismiss);
    _timer = Timer(const Duration(seconds: 8), dismiss);
  }
}

class _Tip extends CustomPainter {
  _Tip(this.color, {required this.up});

  final Color color;
  final bool up;

  @override
  void paint(Canvas canvas, Size size) {
    final path = up
        ? (Path()
          ..moveTo(0, size.height)
          ..lineTo(size.width / 2, 0)
          ..lineTo(size.width, size.height))
        : (Path()
          ..moveTo(0, 0)
          ..lineTo(size.width / 2, size.height)
          ..lineTo(size.width, 0));
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_Tip old) => old.color != color || old.up != up;
}
