import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// 사용자가 고른 백업 위치. Android 저장소 접근과 iOS 책갈피는 앱의 어댑터가 구현한다.
abstract interface class BackupFolder {
  /// 백업 후보 파일 이름. 파일은 이름이 아니라 머리말로 알아본다.
  Future<List<String>> names();

  /// 지금 읽을 수 없으면 null. 구름 자리표시자가 여기에 든다.
  Future<String?> read(String name);

  Future<void> write(String name, String text);

  /// 격리 파일 내보내기가 쓴다. 이름이 `.json`이 아니므로 회전 대상이 아니다.
  Future<void> writeBytes(String name, Uint8List bytes);

  Future<void> delete(String name);
}

/// 일반 파일 폴더. 시험과 Android 앱 전용 위치에서 쓴다.
final class LocalBackupFolder implements BackupFolder {
  const LocalBackupFolder(this.directory);

  final Directory directory;

  File _file(String name) => File(p.join(directory.path, name));

  @override
  Future<List<String>> names() async {
    if (!directory.existsSync()) return const [];
    // 폴더 목록 순서는 파일 시스템마다 다르다(APFS는 이름순, ext4는 해시순). 이름순으로 고정한다
    return [
      for (final entry in directory.listSync().whereType<File>())
        if (entry.path.endsWith('.json')) p.basename(entry.path),
    ]..sort();
  }

  @override
  Future<String?> read(String name) async {
    try {
      return await _file(name).readAsString();
    } on FileSystemException {
      return null;
    }
  }

  /// 임시 이름으로 쓴 뒤 바꾼다. 도중에 죽어도 온전한 파일이 잘리지 않는다.
  @override
  Future<void> write(String name, String text) async {
    directory.createSync(recursive: true);
    final temp = _file('$name.tmp');
    await temp.writeAsString(text, flush: true);
    await temp.rename(_file(name).path);
  }

  @override
  Future<void> writeBytes(String name, Uint8List bytes) async {
    directory.createSync(recursive: true);
    await _file(name).writeAsBytes(bytes, flush: true);
  }

  @override
  Future<void> delete(String name) => _file(name).delete();
}
