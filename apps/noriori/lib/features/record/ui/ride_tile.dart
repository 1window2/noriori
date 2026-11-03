import 'package:flutter/material.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/date_text.dart';
import '../../../app/theme/app_theme.dart';
import '../../../i18n/strings.g.dart';
import '../controller/record_list_controller.dart';

/// 기록 목록과 여정 화면의 한 줄.
class RideTile extends StatelessWidget {
  const RideTile({super.key, required this.ride});

  final RideSummary ride;

  String? _badge(BuildContext context) {
    final t = context.t.record.status;
    return switch (ride.status) {
      ResolveStatus.ok => null,
      ResolveStatus.partial => t.partial,
      ResolveStatus.needsInput => t.needsInput,
      ResolveStatus.unknownRef => t.unknownRef,
      ResolveStatus.invalid => t.invalid,
      ResolveStatus.error => t.error,
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.record;
    final km = ride.km10;
    final raw = ride.shownDate;
    final text = Theme.of(context).textTheme;
    final parts = [
      switch (ride.serviceName) {
        final name? => t.viaService(name: name),
        null => ride.lineLabel,
      },
      if (raw == null) t.dateUnknown else dateText(context.t, raw),
      ?_badge(context),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        spacing: 12,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text('${ride.fromLabel} → ${ride.toLabel}', style: text.titleMedium),
                Text(parts.join(' · '), style: text.bodySmall),
              ],
            ),
          ),
          if (km != null)
            Text(
              t.km(km: kmLabel(km * 100)),
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700, fontFeatures: tabularFigures),
            ),
        ],
      ),
    );
  }
}
