import 'package:flutter/material.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/meter.dart';
import '../../../i18n/strings.g.dart';

/// 이름, km, 완주율과 그 아래 얇은 막대가 한 버튼이다.
class ProgressTile extends StatelessWidget {
  const ProgressTile({
    super.key,
    required this.title,
    required this.score,
    required this.onTap,
  });

  final String title;
  final Score score;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    final total = kmLabel(score.denMeters);
    final km = score.started
        ? context.t.stats.ridden(num: kmLabel(score.numMeters), den: total)
        : '$total km';
    return InkWell(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tokens.hairline))),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 7,
            children: [
              Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: Text(title, style: text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Text(km, style: text.bodySmall?.copyWith(fontFeatures: tabularFigures)),
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
              Meter(ratio: score.ratio),
            ],
          ),
        ),
      ),
    );
  }
}
