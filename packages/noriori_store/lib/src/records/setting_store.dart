import '../db/user_db.dart';

/// `setting` 테이블. 원본은 여기이고 provider는 그 캐시다.
final class SettingStore {
  const SettingStore(this._db);

  final UserDb _db;

  Future<String?> read(String key) async {
    final row = await (_db.select(_db.settingTable)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> delete(String key) => (_db.delete(_db.settingTable)..where((t) => t.key.equals(key))).go();

  Future<void> write(String key, String value) => _db.into(_db.settingTable).insertOnConflictUpdate(
        SettingTableCompanion.insert(key: key, value: value),
      );

  /// 처음 불릴 때 만들어 저장한다. 다시 묻지 않는 값에 쓴다.
  Future<String> readOrCreate(String key, String Function() create) async {
    final found = await read(key);
    if (found != null) return found;
    final value = create();
    await write(key, value);
    return value;
  }
}
