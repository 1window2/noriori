import 'package:flutter/material.dart';

import '../../../i18n/strings.g.dart';

enum _Blocked { update, retry, noSpace, restoreOnly }

/// 앱 본체로 들어갈 수 없을 때의 화면. 어떤 경우에도 기록을 지우는 길을 두지 않는다.
class BlockedStartScreen extends StatelessWidget {
  const BlockedStartScreen.update({super.key})
      : _kind = _Blocked.update,
        reason = null,
        onAction = null;

  const BlockedStartScreen.retry({super.key, required this.reason, this.onAction})
      : _kind = _Blocked.retry;

  const BlockedStartScreen.noSpace({super.key, required this.reason, this.onAction})
      : _kind = _Blocked.noSpace;

  const BlockedStartScreen.restoreOnly({super.key, this.onAction})
      : _kind = _Blocked.restoreOnly,
        reason = null;

  final _Blocked _kind;
  final String? reason;

  /// 다시 시도하거나 복원을 시작한다.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final start = context.t.start;
    final (title, body, action) = switch (_kind) {
      _Blocked.update => (start.updateTitle, start.updateBody, null),
      _Blocked.retry => (start.retryTitle, start.retryBody, start.retry),
      _Blocked.noSpace => (start.noSpaceTitle, start.noSpaceBody, start.retry),
      _Blocked.restoreOnly => (start.restoreTitle, start.restoreBody, start.restoreAction),
    };
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        // 큰 글자에서도 단추가 화면 밖으로 나가면 안 된다. 여기서는 다른 길이 없다
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Text(title, style: text.headlineSmall),
              Text(body, style: text.bodyLarge),
              if (reason != null) Text(reason!, style: text.bodySmall),
              if (action != null && onAction != null)
                FilledButton(onPressed: onAction, child: Text(action)),
            ],
          ),
        ),
      ),
    );
  }
}
