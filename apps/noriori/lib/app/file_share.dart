import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 파일을 다른 앱으로 넘긴다. 시험에서 바꿔 끼운다.
abstract interface class FileShare {
  Future<void> share(String name, Uint8List bytes);
}

/// OS 공유 시트. 백업 폴더가 없어도 저장, 메일, 드라이브로 보낼 수 있다.
final class OsFileShare implements FileShare {
  const OsFileShare();

  @override
  Future<void> share(String name, Uint8List bytes) async {
    final root = await getTemporaryDirectory();
    final folder = await Directory('${root.path}/export').create(recursive: true);
    final file = File('${folder.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }
}

final fileShareProvider = Provider<FileShare>((ref) => const OsFileShare());
