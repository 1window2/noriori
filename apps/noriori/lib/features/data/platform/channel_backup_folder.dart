import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:noriori_store/noriori_store.dart';

/// 지금 고른 폴더의 상태.
final class FolderStatus {
  const FolderStatus({required this.name, required this.granted});

  final String name;

  /// 재설치하면 권한이 사라지고 폴더를 다시 골라야 한다.
  final bool granted;
}

/// 폴더를 고른 결과.
final class FolderPick {
  const FolderPick({required this.name, required this.insideApp});

  final String name;

  /// 앱을 지우면 함께 사라지는 위치다. 고르지 않은 것으로 다룬다.
  final bool insideApp;
}

/// Android 저장소 접근과 iOS 책갈피의 어댑터. 판단은 store가 한다.
final class ChannelBackupFolder implements BackupFolder {
  const ChannelBackupFolder();

  static const _channel = MethodChannel('app.noriori/backup_folder');

  Future<FolderStatus?> status() async {
    final value = await _channel.invokeMapMethod<String, Object?>('status');
    if (value == null) return null;
    return FolderStatus(name: value['name']! as String, granted: value['granted']! as bool);
  }

  /// 취소하면 null.
  Future<FolderPick?> pick() async {
    final value = await _channel.invokeMapMethod<String, Object?>('pick');
    if (value == null) return null;
    return FolderPick(name: value['name']! as String, insideApp: value['insideApp']! as bool);
  }

  /// iOS는 백그라운드로 가면 곧 멈춘다. 백업이 끝날 때까지 시간을 얻는다.
  Future<T> keepAlive<T>(Future<T> Function() work) async {
    await _channel.invokeMethod<void>('beginTask');
    try {
      return await work();
    } finally {
      await _channel.invokeMethod<void>('endTask');
    }
  }

  /// iOS는 앱 지원 폴더 전체가 OS 백업에 든다. Android는 매니페스트 규칙으로 뺀다.
  Future<void> excludeFromOsBackup(List<String> paths) =>
      _channel.invokeMethod<void>('excludeFromBackup', {'paths': paths});

  @override
  Future<List<String>> names() async =>
      await _channel.invokeListMethod<String>('names') ?? const [];

  @override
  Future<String?> read(String name) async {
    final bytes = await _channel.invokeMethod<Uint8List>('read', {'name': name});
    if (bytes == null) return null;
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> write(String name, String text) =>
      writeBytes(name, Uint8List.fromList(utf8.encode(text)));

  @override
  Future<void> writeBytes(String name, Uint8List bytes) =>
      _channel.invokeMethod<void>('write', {'name': name, 'bytes': bytes});

  @override
  Future<void> delete(String name) => _channel.invokeMethod<void>('delete', {'name': name});
}
