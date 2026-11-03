import 'dart:convert';

import 'package:noriori_core/noriori_core.dart';

final class PackFile {
  const PackFile({required this.sha256, required this.size});

  final String sha256;
  final int size;
}

/// 팩의 `manifest.json`. 서명은 별도 파일이고 정규화 없이 이 파일 그대로 검사한다.
final class PackManifest {
  const PackManifest({
    required this.edition,
    required this.schemaVersion,
    required this.files,
  });

  /// 판 하나에 반드시 있어야 하는 파일. `rail-osm`은 선택이다.
  static const required = ['master.sqlite', 'names.sqlite', 'rail.pmtiles'];
  static const fileName = 'manifest.json';

  final String edition;
  final int schemaVersion;
  final Map<String, PackFile> files;

  factory PackManifest.parse(String text) {
    final json = jsonDecode(text) as Map<String, Object?>;
    final files = json['files'] as Map<String, Object?>;
    return PackManifest(
      edition: json['edition'] as String,
      schemaVersion: json['schema_version'] as int,
      files: {
        for (final MapEntry(:key, :value) in files.entries)
          key: PackFile(
            sha256: (value as Map<String, Object?>)['sha256'] as String,
            size: value['size'] as int,
          ),
      },
    );
  }

  PackCandidate candidate({required bool fromAssets}) => PackCandidate(
        edition: edition,
        schemaVersion: schemaVersion,
        fromAssets: fromAssets,
      );
}
