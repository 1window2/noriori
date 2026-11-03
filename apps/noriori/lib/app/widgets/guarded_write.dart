import 'package:flutter/material.dart';

/// 쓰기 동작을 한 번에 하나만 돌린다. 저장이 늦어져도 연타가 기록 두 건이 되지 않고,
/// 실패는 화면에 알린다 (ARCHITECTURE §3.1).
mixin GuardedWrite<T extends StatefulWidget> on State<T> {
  bool writing = false;

  Future<void> guarded(Future<void> Function() work, {required String failed}) async {
    if (writing) return;
    setState(() => writing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await work();
    } on Object catch (error) {
      debugPrint('쓰기 실패: $error');
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    } finally {
      if (mounted) setState(() => writing = false);
    }
  }
}
