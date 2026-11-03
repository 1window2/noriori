import 'package:flutter/services.dart';

/// 고른 파일의 이름과 내용.
final class PickedFile {
  const PickedFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// 파일 하나를 고르는 시스템 창. 고른 순간에만 읽는다.
final class ChannelFilePick {
  const ChannelFilePick();

  static const _channel = MethodChannel('app.noriori/file_pick');

  /// 취소하면 null.
  Future<PickedFile?> pick() async {
    final value = await _channel.invokeMapMethod<String, Object?>('pick');
    if (value == null) return null;
    return PickedFile(name: value['name']! as String, bytes: value['bytes']! as Uint8List);
  }
}
