import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/date_text.dart';
import '../../../app/file_share.dart';
import '../../../app/session_providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../i18n/strings.g.dart';
import '../controller/record_session_controller.dart';
import 'ride_ticket.dart';

/// 노선을 처음 완주하면 축하 카드를 띄운다. 닫기가 있고 흐름을 막지 않는다 (DESIGN §3.3).
Future<void> showCompleteCard(BuildContext context, RideTicketData data) => showDialog<void>(
      context: context,
      builder: (context) => _CompleteCard(data: data),
    );

class _CompleteCard extends ConsumerStatefulWidget {
  const _CompleteCard({required this.data});

  final RideTicketData data;

  @override
  ConsumerState<_CompleteCard> createState() => _CompleteCardState();
}

class _CompleteCardState extends ConsumerState<_CompleteCard> {
  final _card = GlobalKey();

  /// 보이는 카드를 그대로 이미지로 만들어 보낸다.
  Future<void> _share() async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.t.data.exportFailed;
    final name = 'noriori-${ref.read(todayProvider)}.png';
    try {
      final boundary = _card.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await ref.read(fileShareProvider).share(name, bytes!.buffer.asUint8List());
    } on Object catch (error) {
      debugPrint('공유 실패: $error');
      messenger.showSnackBar(SnackBar(content: Text(failed), persist: false));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    final data = widget.data;
    final raw = data.dateInput;
    final total = data.after?.denMeters ?? data.meters;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          RepaintBoundary(
            key: _card,
            child: DecoratedBox(
              decoration: BoxDecoration(color: tokens.paper, borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 8,
                  children: [
                    RideStamp(label: t.ticket.completeStamp, date: raw),
                    const SizedBox(height: 4),
                    Text(data.lineName, textAlign: TextAlign.center, style: text.titleLarge),
                    Text(
                      [
                        '${kmLabel(total)} km',
                        if (raw != null) dateText(t, raw),
                      ].join(' · '),
                      style: text.bodyMedium,
                    ),
                    Text(t.complete.credit, style: text.bodySmall?.copyWith(color: tokens.textMuted)),
                  ],
                ),
              ),
            ),
          ),
          FilledButton(onPressed: _share, child: Text(t.complete.share)),
          TextButton(
            style: TextButton.styleFrom(backgroundColor: tokens.paper),
            onPressed: () => Navigator.pop(context),
            child: Text(t.complete.close),
          ),
        ],
      ),
    );
  }
}
