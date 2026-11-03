import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/session_providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/line_strip_bar.dart';
import '../../../i18n/strings.g.dart';
import '../controller/browse_controller.dart';

/// 노선 한 줄. 위치 띠로 어디를 탔는지 보여 준다.
class LineTile extends ConsumerWidget {
  const LineTile({
    super.key,
    required this.row,
    required this.title,
    required this.onTap,
  });

  final LineRow row;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    final score = row.line.score;
    final unmapped = ref.watch(unmappedLinesProvider).value?.contains(row.line.lineId) ?? false;
    final km = score.started && !score.complete
        ? context.t.stats.ridden(
            num: kmLabel(score.numMeters),
            den: kmLabel(score.denMeters),
          )
        : '${kmLabel(score.denMeters)} km';
    return InkWell(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: tokens.hairline)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 11, 24, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 6,
            children: [
              Row(
                spacing: 6,
                children: [
                  Expanded(
                    child: Row(
                      spacing: 6,
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: text.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (score.complete)
                          Icon(Icons.check, size: 16, color: tokens.lineRidden),
                      ],
                    ),
                  ),
                  Text(
                    km,
                    style: text.bodySmall?.copyWith(
                      fontFeatures: tabularFigures,
                    ),
                  ),
                  Text(
                    percentLabel(score),
                    style: text.bodyMedium?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: score.started ? tokens.text : tokens.textClosed,
                      fontFeatures: tabularFigures,
                    ),
                  ),
                ],
              ),
              if (unmapped)
                Text(
                  context.t.mapSheet.unmapped,
                  style: text.labelSmall?.copyWith(color: tokens.textMuted),
                ),
              LineStripBar(strip: row.strip),
              Row(
                children: [
                  Expanded(
                    child: Text(row.startName ?? '', style: text.labelSmall),
                  ),
                  Text(row.endName ?? '', style: text.labelSmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
