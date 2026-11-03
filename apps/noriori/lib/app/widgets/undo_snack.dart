import 'package:flutter/material.dart';

/// 모든 변경 뒤 5초간 되돌리기를 띄운다. 확인 팝업은 쓰지 않는다 (DESIGN §8.2).
void showUndoSnack(
  ScaffoldMessengerState messenger, {
  required String message,
  required String undoLabel,
  required VoidCallback onUndo,
}) {
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 5),
      persist: false,
      action: SnackBarAction(label: undoLabel, onPressed: onUndo),
    ),
  );
}
