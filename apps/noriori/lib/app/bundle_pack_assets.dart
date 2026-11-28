import 'package:flutter/services.dart';
import 'package:noriori_store/noriori_store.dart';

/// 앱에 든 데이터 팩. store가 Flutter를 모르게 하는 어댑터다.
final class BundlePackAssets implements PackAssets {
  const BundlePackAssets();

  static const _root = 'assets/pack';

  @override
  Future<String> manifestText() => rootBundle.loadString('$_root/${PackManifest.fileName}');

  /// 서명 파일은 서명한 판에만 있다. 없으면 null
  @override
  Future<String?> signatureText() async {
    try {
      return await rootBundle.loadString('$_root/${PackManifest.fileName}.sig');
    } on Object {
      return null;
    }
  }

  @override
  Future<Uint8List> fileBytes(String name) async {
    final data = await rootBundle.load('$_root/$name');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }
}
