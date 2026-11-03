/// 백업 JSON의 머리말. 첫 공개 뒤에는 나간 파일을 고칠 수 없으므로 고정이다 (ARCHITECTURE §3.7).
final class BackupHeader {
  const BackupHeader({
    required this.userVersion,
    required this.edition,
    required this.appBuild,
    required this.exportedAt,
    this.format = currentFormat,
  });

  /// 파일은 이름이 아니라 이 값으로 알아본다.
  static const formatName = 'noriori-backup';
  static const currentFormat = 1;

  /// 자동 백업 파일 이름의 앞부분.
  static const namePrefix = 'noriori-';

  final int format;
  final int userVersion;
  final String edition;
  final int appBuild;
  final int exportedAt;

  Map<String, Object?> toJson() => {
        'kind': formatName,
        'format': format,
        'user_version': userVersion,
        'edition': edition,
        'app_build': appBuild,
        'exported_at': exportedAt,
      };

  /// noriori 백업이 아니면 [FormatException].
  factory BackupHeader.fromJson(Map<String, Object?> json) {
    if (json['kind'] != formatName) {
      throw const FormatException('noriori 백업이 아니다');
    }
    return BackupHeader(
      format: _int(json, 'format'),
      userVersion: _int(json, 'user_version'),
      edition: json['edition'] as String,
      appBuild: _int(json, 'app_build'),
      exportedAt: _int(json, 'exported_at'),
    );
  }

  static int _int(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is int) return value;
    throw FormatException('머리말에 $key가 없다');
  }
}

enum RestorePath {
  /// 그대로 병합한다.
  direct,

  /// 앱의 마이그레이션 순서대로 올린 뒤 병합한다.
  upgradeFirst,

  /// 앱보다 새 파일이다. 모르는 열을 버리지 않도록 거부하고 앱 갱신을 안내한다.
  refuse,
}

/// 형식이 앞선 파일은 스키마가 같아도 읽을 수 없다. 모르는 표를 버리지 않도록 같이 거부한다.
RestorePath restorePath({required BackupHeader header, required int appVersion}) {
  if (header.format > BackupHeader.currentFormat) return RestorePath.refuse;
  if (header.userVersion > appVersion) return RestorePath.refuse;
  if (header.userVersion < appVersion) return RestorePath.upgradeFirst;
  return RestorePath.direct;
}
