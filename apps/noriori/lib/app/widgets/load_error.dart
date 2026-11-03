import 'package:flutter/material.dart';

import '../../i18n/strings.g.dart';

/// 읽기 실패. 영어 예외를 그대로 보이지 않는다. 원인은 로그에 남긴다.
class LoadError extends StatelessWidget {
  const LoadError(this.error, {super.key});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    debugPrint('읽기 실패: $error');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(context.t.app.loadFailed, textAlign: TextAlign.center),
      ),
    );
  }
}
