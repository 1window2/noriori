import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:noriori_core/noriori_core.dart';
import 'package:path/path.dart' as p;

import '../db/connection.dart';
import 'pack_manifest.dart';

/// 앱에 든 팩. 앱이 번들에서 읽어 주므로 store는 Flutter를 모른다.
abstract interface class PackAssets {
  Future<String> manifestText();
  Future<Uint8List> fileBytes(String name);
}

/// 쓸 수 있는 팩이 하나도 없다. 앱 자산까지 깨진 경우다.
final class PackUnavailable implements Exception {
  const PackUnavailable(this.reason);

  final String reason;

  @override
  String toString() => 'PackUnavailable: $reason';
}

/// 고른 판. 폴더는 불변이다.
final class InstalledPack {
  const InstalledPack(this.directory, this.manifest);

  final Directory directory;
  final PackManifest manifest;

  String get edition => manifest.edition;

  String file(String name) => p.join(directory.path, name);

  PackDatabases get databases =>
      PackDatabases(master: file('master.sqlite'), names: file('names.sqlite'));

  String get railTiles => file('rail.pmtiles');

  /// N02에 없는 선로. ODbL이라 파일을 나눈다. 없으면 그 구간은 그리지 않는다.
  String? get osmRailTiles {
    final path = file('rail-osm.pmtiles');
    return File(path).existsSync() ? path : null;
  }

  /// 일본 윤곽과 도도부현 경계. 없으면 온라인 배경만 쓴다.
  String? get baseTiles {
    final path = file('base.pmtiles');
    return File(path).existsSync() ? path : null;
  }

  /// 라틴 글리프 주소 틀. 없으면 온라인 글리프를 쓴다.
  String? get glyphs => File(file('glyph-0-255.pbf')).existsSync() ? file('glyph-{range}.pbf') : null;
}

/// `datasets/` 폴더. 활성 판을 저장하지 않고 시작할 때마다 폴더에서 고른다 (ARCHITECTURE §3.6).
final class PackFolder {
  PackFolder(this.root, {required this.assets, required this.supportedSchema});

  static const _tempPrefix = '.tmp-';
  static const _sqliteHeader = 'SQLite format 3';
  static const _tilesHeader = 'PMTiles';

  final Directory root;
  final PackAssets assets;
  final int supportedSchema;

  /// 1~3단계. 깨진 판은 지우고 다시 고른다.
  Future<InstalledPack> select() async {
    root.createSync(recursive: true);
    _clearTemp();
    final bundled = PackManifest.parse(await assets.manifestText());
    if (bundled.schemaVersion != supportedSchema) {
      throw PackUnavailable('앱 자산의 스키마가 ${bundled.schemaVersion}이다');
    }
    // 폴더의 깨진 판을 하나씩 지워 나간다. 마지막에는 자산을 새로 복사한다.
    final attempts = _folders().length + 2;
    for (var attempt = 0; attempt < attempts; attempt++) {
      final installed = _installed();
      final choice = choosePack(
        assets: bundled.candidate(fromAssets: true),
        folders: installed.map((pack) => pack.manifest.candidate(fromAssets: false)),
        supportedSchema: supportedSchema,
      );
      final pack = choice.fromAssets
          ? await _copyFromAssets(bundled)
          : installed.firstWhere((pack) => pack.edition == choice.edition);
      if (_isIntact(pack)) return pack;
      pack.directory.deleteSync(recursive: true);
    }
    throw const PackUnavailable('앱 자산의 팩이 깨졌다');
  }

  /// 읽다가 깨진 것이 드러난 판을 버린다. 크기와 헤더만으로는 알 수 없다.
  void discard(InstalledPack pack) => pack.directory.deleteSync(recursive: true);

  /// 6단계. 화면이 뜬 뒤에 지운다.
  void deleteOthers(InstalledPack keep) {
    for (final folder in _folders()) {
      if (folder.path != keep.directory.path) folder.deleteSync(recursive: true);
    }
  }

  Iterable<Directory> _entries() => root.listSync().whereType<Directory>();

  List<Directory> _folders() => [
        for (final dir in _entries())
          if (!p.basename(dir.path).startsWith(_tempPrefix)) dir,
      ];

  void _clearTemp() {
    for (final dir in _entries()) {
      if (p.basename(dir.path).startsWith(_tempPrefix)) dir.deleteSync(recursive: true);
    }
  }

  /// 매니페스트를 읽을 수 없는 폴더는 팩이 아니므로 지운다.
  List<InstalledPack> _installed() {
    final packs = <InstalledPack>[];
    for (final dir in _folders()) {
      final manifest = File(p.join(dir.path, PackManifest.fileName));
      try {
        packs.add(InstalledPack(dir, PackManifest.parse(manifest.readAsStringSync())));
      } on Object {
        dir.deleteSync(recursive: true);
      }
    }
    return packs;
  }

  /// 임시 폴더에 복사하고 해시를 확인한 뒤 이름을 바꾼다. 도중에 죽으면 다음 시작이 지운다.
  Future<InstalledPack> _copyFromAssets(PackManifest manifest) async {
    final target = Directory(p.join(root.path, manifest.edition));
    if (target.existsSync()) return InstalledPack(target, manifest);
    final temp = Directory(p.join(root.path, '$_tempPrefix${manifest.edition}'))
      ..createSync();
    for (final MapEntry(key: name, value: expected) in manifest.files.entries) {
      final bytes = await assets.fileBytes(name);
      if (sha256.convert(bytes).toString() != expected.sha256) {
        temp.deleteSync(recursive: true);
        throw PackUnavailable('앱 자산의 $name 해시가 다르다');
      }
      File(p.join(temp.path, name)).writeAsBytesSync(bytes, flush: true);
    }
    final text = await assets.manifestText();
    File(p.join(temp.path, PackManifest.fileName)).writeAsStringSync(text, flush: true);
    temp.renameSync(target.path);
    return InstalledPack(target, manifest);
  }

  /// 시작할 때는 해시를 다시 계산하지 않는다. 크기와 헤더만 본다.
  bool _isIntact(InstalledPack pack) {
    for (final name in PackManifest.required) {
      final expected = pack.manifest.files[name];
      final file = File(pack.file(name));
      if (expected == null || !file.existsSync()) return false;
      if (file.lengthSync() != expected.size) return false;
      final header = name.endsWith('.sqlite') ? _sqliteHeader : _tilesHeader;
      if (!_startsWith(file, header)) return false;
    }
    return true;
  }

  bool _startsWith(File file, String header) {
    final handle = file.openSync();
    try {
      return String.fromCharCodes(handle.readSync(header.length)) == header;
    } finally {
      handle.closeSync();
    }
  }
}
