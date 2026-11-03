import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../i18n/strings.g.dart';
import '../controller/backup_controller.dart';

/// 지도 홈의 백업 안내. 백업은 기록을 보장하는 유일한 수단이라 조용히 실패하지 않는다.
class BackupNoticeBar extends ConsumerWidget {
  const BackupNoticeBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notice = ref.watch(backupNoticeProvider);
    if (notice == null) return const SizedBox.shrink();
    final t = context.t.data.notice;
    final message = switch (notice) {
      BackupNotice.needsMerge => t.needsMerge,
      BackupNotice.failed => t.failed,
      BackupNotice.folderLost => t.folderLost,
      BackupNotice.unreadable => t.unreadable,
      BackupNotice.stale => t.stale,
      BackupNotice.noFolder => t.noFolder,
    };
    final tokens = context.tokens;
    return Material(
      color: tokens.surface.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/settings/data'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              Icon(Icons.info_outline, size: 18, color: tokens.textMuted),
              Flexible(child: Text(message, style: Theme.of(context).textTheme.bodySmall)),
            ],
          ),
        ),
      ),
    );
  }
}
