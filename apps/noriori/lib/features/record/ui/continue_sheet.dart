import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/session_providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/guarded_write.dart';
import '../../../app/widgets/line_strip_bar.dart';
import '../../../i18n/strings.g.dart';
import '../controller/browse_controller.dart';
import '../controller/record_session_controller.dart';
import 'line_tile.dart';

/// 지도 홈 아래의 시트 높이. 카메라가 이만큼 비켜 앉는다.
const continueSheetHeight = 172.0;

/// 지도 아래의 "이어서 타기". 끌어 올리면 기록 탭처럼 목록으로 펼쳐진다.
class ContinueSheet extends ConsumerStatefulWidget {
  const ContinueSheet({super.key});

  @override
  ConsumerState<ContinueSheet> createState() => _ContinueSheetState();
}

class _ContinueSheetState extends ConsumerState<ContinueSheet> with GuardedWrite {
  static const _full = 0.92;

  final _sheet = DraggableScrollableController();
  bool _open = false;

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  Future<void> _go(String lineId) => guarded(() async {
        await ref.read(recordSessionProvider.notifier).open(lineId: lineId);
        if (mounted) unawaited(context.push('/record/session?back=1'));
      }, failed: context.t.session.saveFailed);

  void _toggle(double rest) => _sheet.animateTo(
        _open ? rest : _full,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) {
          final rest = continueSheetHeight / box.maxHeight;
          return PopScope(
            canPop: !_open,
            onPopInvokedWithResult: (popped, _) {
              if (!popped) _toggle(rest);
            },
            child: NotificationListener<DraggableScrollableNotification>(
              onNotification: (note) {
                final open = note.extent > rest + 0.05;
                if (open != _open) setState(() => _open = open);
                return false;
              },
              child: DraggableScrollableSheet(
                controller: _sheet,
                initialChildSize: rest,
                minChildSize: rest,
                maxChildSize: _full,
                snap: true,
                builder: (context, scroll) => _body(scroll, rest),
              ),
            ),
          );
        },
      );

  Widget _body(ScrollController scroll, double rest) {
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    final t = context.t.map;
    final rows = ref.watch(continueRowsProvider).value ?? const <LineRow>[];
    final book = ref.watch(nameBookProvider);
    final first = Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: [
          Text(t.firstRide, style: text.titleMedium),
          Text(t.firstRideHint, style: text.bodySmall),
        ],
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: tokens.paper,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: const [
          BoxShadow(color: Color(0x29000000), offset: Offset(0, -3), blurRadius: 16),
        ],
      ),
      child: CustomScrollView(
        controller: scroll,
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  button: true,
                  label: t.sheetHandle,
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _toggle(rest),
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 8, bottom: 6),
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: tokens.track,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.continueTitle,
                          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: t.add,
                        excludeSemantics: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => context.push('/search'),
                          // 단추는 작게 보여도 누르는 곳은 48dp다
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Material(
                              color: tokens.lineRidden,
                              borderRadius: BorderRadius.circular(999),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(999),
                                onTap: () => context.push('/search'),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 7, 14, 7),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    spacing: 4,
                                    children: [
                                      Icon(Icons.add, size: 18, color: tokens.onAccent),
                                      Text(
                                        t.add,
                                        style: text.labelLarge?.copyWith(
                                          fontSize: 14,
                                          color: tokens.onAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (rows.isEmpty)
            SliverToBoxAdapter(child: first)
          else if (_open)
            SliverList.builder(
              itemCount: rows.length,
              itemBuilder: (context, index) => LineTile(
                row: rows[index],
                title: book.lines[rows[index].line.lineId] ?? rows[index].line.lineId,
                onTap: () => _go(rows[index].line.lineId),
              ),
            )
          else
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                // 카드 높이는 내용이 정한다. 가장 큰 카드에 맞춰 나란히 선다
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 10,
                    children: [
                      for (final row in rows)
                        _LineCard(
                          row: row,
                          name: book.lines[row.line.lineId] ?? row.line.lineId,
                          onTap: () => _go(row.line.lineId),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({required this.row, required this.name, required this.onTap});

  final LineRow row;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    final score = row.line.score;
    return Material(
      color: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: tokens.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 214,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 5,
            children: [
              Row(
                spacing: 6,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(percentLabel(score), style: text.titleSmall),
                ],
              ),
              LineStripBar(strip: row.strip),
              Text(
                context.t.map.left(km: kmLabel(score.remainingMeters)),
                style: text.labelSmall?.copyWith(color: tokens.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
