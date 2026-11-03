import 'package:drift/drift.dart';

// ARCHITECTURE §3.8이 기준이다. 원본 테이블은 백업되고, 캐시 테이블은 언제든 버리고 다시 만든다.

mixin RecordColumns on Table {
  TextColumn get id => text()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  TextColumn get deviceId => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

// ---------------------------------------------------------------- 원본

@DataClassName('TripRow')
class TripTable extends Table with RecordColumns {
  @override
  String get tableName => 'trip';

  TextColumn get title => text()();
  TextColumn get note => text().nullable()();
}

@DataClassName('RideRow')
class RideTable extends Table with RecordColumns {
  @override
  String get tableName => 'ride';

  TextColumn get tripId => text().nullable()();
  TextColumn get dateInput => text().nullable()();
  TextColumn get times => text().nullable()();
  TextColumn get trainName => text().nullable()();
  TextColumn get carNo => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get serviceId => text().nullable()();

  /// JSON 배열.
  TextColumn get transferNodes => text().withDefault(const Constant('[]'))();
  BoolColumn get fromAlighted => boolean()();
  BoolColumn get toAlighted => boolean()();
  TextColumn get datasetVersion => text()();
  TextColumn get importSource => text().nullable()();
  TextColumn get importRaw => text().nullable()();
}

@DataClassName('RideLegRow')
class RideLegTable extends Table {
  @override
  String get tableName => 'ride_leg';

  TextColumn get rideId => text()();
  IntColumn get seq => integer()();
  TextColumn get lineId => text()();
  TextColumn get routeId => text()();
  TextColumn get fromNode => text()();
  TextColumn get toNode => text()();
  TextColumn get direction => text().nullable()();
  TextColumn get resolveAsOf => text().nullable()();
  BoolColumn get resolveUnknown => boolean()();
  TextColumn get lineLabel => text()();
  TextColumn get fromLabel => text()();
  TextColumn get toLabel => text()();

  @override
  Set<Column<Object>> get primaryKey => {rideId, seq};
}

@DataClassName('VisitRow')
class VisitTable extends Table with RecordColumns {
  @override
  String get tableName => 'visit';

  TextColumn get nodeId => text()();
  TextColumn get nodeLabel => text()();
  BoolColumn get nodeExplicit => boolean()();
  TextColumn get dateInput => text().nullable()();
  TextColumn get note => text().nullable()();
}

@DataClassName('PhotoRow')
class PhotoTable extends Table with RecordColumns {
  @override
  String get tableName => 'photo';

  TextColumn get ownerType => text()();
  TextColumn get ownerId => text()();
  TextColumn get sha256 => text()();
  TextColumn get thumbPath => text().nullable()();
}

@DataClassName('SettingRow')
class SettingTable extends Table {
  @override
  String get tableName => 'setting';

  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// 판 사이 변경 내역. 다시 만들 수 없으므로 원본 쪽에 둔다.
@DataClassName('ChangeReportRow')
class ChangeReportTable extends Table with RecordColumns {
  @override
  String get tableName => 'change_report';

  TextColumn get edition => text()();
  TextColumn get body => text()();
}

// ---------------------------------------------------------------- 캐시

@DataClassName('CacheStateRow')
class CacheStateTable extends Table {
  @override
  String get tableName => 'cache_state';

  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get edition => text()();
  IntColumn get appBuild => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('RideCacheRow')
class RideCacheTable extends Table {
  @override
  String get tableName => 'ride_cache';

  TextColumn get rideId => text()();
  TextColumn get resolveStatus => text()();
  TextColumn get date => text().nullable()();
  IntColumn get km10 => integer().nullable()();
  TextColumn get effectiveLo => text().nullable()();
  TextColumn get effectiveHi => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {rideId};
}

@DataClassName('RideLegCacheRow')
class RideLegCacheTable extends Table {
  @override
  String get tableName => 'ride_leg_cache';

  TextColumn get rideId => text()();
  IntColumn get seq => integer()();
  TextColumn get lineId => text()();
  TextColumn get routeId => text()();
  IntColumn get km10 => integer()();

  @override
  Set<Column<Object>> get primaryKey => {rideId, seq};
}

@DataClassName('RideEdgeRow')
@TableIndex(name: 'ride_edge_edge', columns: {#edge})
@TableIndex(name: 'ride_edge_ride', columns: {#rideId})
@TableIndex(name: 'ride_edge_on', columns: {#unitOn, #effectiveHi})
@TableIndex(name: 'ride_edge_off', columns: {#unitOff, #effectiveHi})
class RideEdgeTable extends Table {
  @override
  String get tableName => 'ride_edge';

  IntColumn get edge => integer()();
  TextColumn get rideId => text()();
  IntColumn get legSeq => integer()();
  IntColumn get unitOn => integer()();
  IntColumn get unitOff => integer()();
  TextColumn get effectiveHi => text().nullable()();
}

@DataClassName('RideNodeRow')
@TableIndex(name: 'ride_node_node', columns: {#node})
@TableIndex(name: 'ride_node_ride', columns: {#rideId})
class RideNodeTable extends Table {
  @override
  String get tableName => 'ride_node';

  TextColumn get node => text()();
  TextColumn get rideId => text()();
  TextColumn get role => text()();
}

@DataClassName('VisitCacheRow')
class VisitCacheTable extends Table {
  @override
  String get tableName => 'visit_cache';

  TextColumn get visitId => text()();
  TextColumn get date => text().nullable()();
  TextColumn get groupId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {visitId};
}
