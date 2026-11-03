import 'package:drift/drift.dart';

import 'tables.dart';

part 'user_db.g.dart';

/// 앱이 아는 `user.sqlite` 스키마 버전.
const userSchemaVersion = 1;

/// 한 버전을 올리는 단계. 원본 테이블만 다룬다. 캐시는 마이그레이션하지 않고 다시 만든다.
typedef SchemaStep = Future<void> Function(UserDb db, Migrator migrator);

/// `from`에서 `from + 1`로 올리는 단계들.
const Map<int, SchemaStep> schemaSteps = {};

@DriftDatabase(
  tables: [
    TripTable,
    RideTable,
    RideLegTable,
    VisitTable,
    PhotoTable,
    SettingTable,
    ChangeReportTable,
    CacheStateTable,
    RideCacheTable,
    RideLegCacheTable,
    RideEdgeTable,
    RideNodeTable,
    VisitCacheTable,
  ],
)
class UserDb extends _$UserDb {
  UserDb(super.executor, {int? version, Map<int, SchemaStep>? steps})
      : _version = version ?? userSchemaVersion,
        _steps = steps ?? schemaSteps;

  final int _version;
  final Map<int, SchemaStep> _steps;

  @override
  int get schemaVersion => _version;

  /// 드리프트는 버전을 마이그레이션이 끝난 뒤 따로 쓴다. 그 사이에 죽으면 다음 시작마다 같은
  /// 단계가 다시 돌아 실패하므로, 버전까지 한 트랜잭션에 쓴다 (ARCHITECTURE §3.6).
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => transaction(() async {
          await m.createAll();
          await _writeVersion(_version);
        }),
        onUpgrade: (m, from, to) => transaction(() async {
          for (var version = from; version < to; version++) {
            final step = _steps[version];
            if (step == null) {
              throw StateError('$version에서 올리는 단계가 없다');
            }
            await step(this, m);
          }
          await _dropCaches(m);
          await _writeVersion(to);
        }),
      );

  Iterable<TableInfo<Table, dynamic>> get cacheTables => [
        cacheStateTable,
        rideCacheTable,
        rideLegCacheTable,
        rideEdgeTable,
        rideNodeTable,
        visitCacheTable,
      ];

  Future<void> _dropCaches(Migrator m) async {
    for (final table in cacheTables) {
      await customStatement('DROP TABLE IF EXISTS ${table.actualTableName}');
      await m.createTable(table);
    }
    for (final index in allSchemaEntities.whereType<Index>()) {
      await m.createIndex(index);
    }
  }

  Future<void> _writeVersion(int version) =>
      customStatement('PRAGMA user_version = $version');
}
