// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_db.dart';

// ignore_for_file: type=lint
class $TripTableTable extends TripTable
    with TableInfo<$TripTableTable, TripRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TripTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
    title,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trip';
  @override
  VerificationContext validateIntegrity(
    Insertable<TripRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TripRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TripRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $TripTableTable createAlias(String alias) {
    return $TripTableTable(attachedDatabase, alias);
  }
}

class TripRow extends DataClass implements Insertable<TripRow> {
  final String id;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;
  final String title;
  final String? note;
  const TripRow({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.deviceId,
    required this.title,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  TripTableCompanion toCompanion(bool nullToAbsent) {
    return TripTableCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deviceId: Value(deviceId),
      title: Value(title),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory TripRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TripRow(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      title: serializer.fromJson<String>(json['title']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'deviceId': serializer.toJson<String>(deviceId),
      'title': serializer.toJson<String>(title),
      'note': serializer.toJson<String?>(note),
    };
  }

  TripRow copyWith({
    String? id,
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    String? deviceId,
    String? title,
    Value<String?> note = const Value.absent(),
  }) => TripRow(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
    title: title ?? this.title,
    note: note.present ? note.value : this.note,
  );
  TripRow copyWithCompanion(TripTableCompanion data) {
    return TripRow(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      title: data.title.present ? data.title.value : this.title,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TripRow(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('title: $title, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, createdAt, updatedAt, deletedAt, deviceId, title, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TripRow &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId &&
          other.title == this.title &&
          other.note == this.note);
}

class TripTableCompanion extends UpdateCompanion<TripRow> {
  final Value<String> id;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<String> deviceId;
  final Value<String> title;
  final Value<String?> note;
  final Value<int> rowid;
  const TripTableCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.title = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TripTableCompanion.insert({
    required String id,
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    required String deviceId,
    required String title,
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       deviceId = Value(deviceId),
       title = Value(title);
  static Insertable<TripRow> custom({
    Expression<String>? id,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<String>? deviceId,
    Expression<String>? title,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (title != null) 'title': title,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TripTableCompanion copyWith({
    Value<String>? id,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<String>? deviceId,
    Value<String>? title,
    Value<String?>? note,
    Value<int>? rowid,
  }) {
    return TripTableCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      title: title ?? this.title,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TripTableCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('title: $title, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RideTableTable extends RideTable
    with TableInfo<$RideTableTable, RideRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RideTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tripIdMeta = const VerificationMeta('tripId');
  @override
  late final GeneratedColumn<String> tripId = GeneratedColumn<String>(
    'trip_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dateInputMeta = const VerificationMeta(
    'dateInput',
  );
  @override
  late final GeneratedColumn<String> dateInput = GeneratedColumn<String>(
    'date_input',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timesMeta = const VerificationMeta('times');
  @override
  late final GeneratedColumn<String> times = GeneratedColumn<String>(
    'times',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trainNameMeta = const VerificationMeta(
    'trainName',
  );
  @override
  late final GeneratedColumn<String> trainName = GeneratedColumn<String>(
    'train_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _carNoMeta = const VerificationMeta('carNo');
  @override
  late final GeneratedColumn<String> carNo = GeneratedColumn<String>(
    'car_no',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serviceIdMeta = const VerificationMeta(
    'serviceId',
  );
  @override
  late final GeneratedColumn<String> serviceId = GeneratedColumn<String>(
    'service_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _transferNodesMeta = const VerificationMeta(
    'transferNodes',
  );
  @override
  late final GeneratedColumn<String> transferNodes = GeneratedColumn<String>(
    'transfer_nodes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _fromAlightedMeta = const VerificationMeta(
    'fromAlighted',
  );
  @override
  late final GeneratedColumn<bool> fromAlighted = GeneratedColumn<bool>(
    'from_alighted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("from_alighted" IN (0, 1))',
    ),
  );
  static const VerificationMeta _toAlightedMeta = const VerificationMeta(
    'toAlighted',
  );
  @override
  late final GeneratedColumn<bool> toAlighted = GeneratedColumn<bool>(
    'to_alighted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("to_alighted" IN (0, 1))',
    ),
  );
  static const VerificationMeta _datasetVersionMeta = const VerificationMeta(
    'datasetVersion',
  );
  @override
  late final GeneratedColumn<String> datasetVersion = GeneratedColumn<String>(
    'dataset_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _importSourceMeta = const VerificationMeta(
    'importSource',
  );
  @override
  late final GeneratedColumn<String> importSource = GeneratedColumn<String>(
    'import_source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _importRawMeta = const VerificationMeta(
    'importRaw',
  );
  @override
  late final GeneratedColumn<String> importRaw = GeneratedColumn<String>(
    'import_raw',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
    tripId,
    dateInput,
    times,
    trainName,
    carNo,
    note,
    serviceId,
    transferNodes,
    fromAlighted,
    toAlighted,
    datasetVersion,
    importSource,
    importRaw,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ride';
  @override
  VerificationContext validateIntegrity(
    Insertable<RideRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('trip_id')) {
      context.handle(
        _tripIdMeta,
        tripId.isAcceptableOrUnknown(data['trip_id']!, _tripIdMeta),
      );
    }
    if (data.containsKey('date_input')) {
      context.handle(
        _dateInputMeta,
        dateInput.isAcceptableOrUnknown(data['date_input']!, _dateInputMeta),
      );
    }
    if (data.containsKey('times')) {
      context.handle(
        _timesMeta,
        times.isAcceptableOrUnknown(data['times']!, _timesMeta),
      );
    }
    if (data.containsKey('train_name')) {
      context.handle(
        _trainNameMeta,
        trainName.isAcceptableOrUnknown(data['train_name']!, _trainNameMeta),
      );
    }
    if (data.containsKey('car_no')) {
      context.handle(
        _carNoMeta,
        carNo.isAcceptableOrUnknown(data['car_no']!, _carNoMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('service_id')) {
      context.handle(
        _serviceIdMeta,
        serviceId.isAcceptableOrUnknown(data['service_id']!, _serviceIdMeta),
      );
    }
    if (data.containsKey('transfer_nodes')) {
      context.handle(
        _transferNodesMeta,
        transferNodes.isAcceptableOrUnknown(
          data['transfer_nodes']!,
          _transferNodesMeta,
        ),
      );
    }
    if (data.containsKey('from_alighted')) {
      context.handle(
        _fromAlightedMeta,
        fromAlighted.isAcceptableOrUnknown(
          data['from_alighted']!,
          _fromAlightedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fromAlightedMeta);
    }
    if (data.containsKey('to_alighted')) {
      context.handle(
        _toAlightedMeta,
        toAlighted.isAcceptableOrUnknown(data['to_alighted']!, _toAlightedMeta),
      );
    } else if (isInserting) {
      context.missing(_toAlightedMeta);
    }
    if (data.containsKey('dataset_version')) {
      context.handle(
        _datasetVersionMeta,
        datasetVersion.isAcceptableOrUnknown(
          data['dataset_version']!,
          _datasetVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_datasetVersionMeta);
    }
    if (data.containsKey('import_source')) {
      context.handle(
        _importSourceMeta,
        importSource.isAcceptableOrUnknown(
          data['import_source']!,
          _importSourceMeta,
        ),
      );
    }
    if (data.containsKey('import_raw')) {
      context.handle(
        _importRawMeta,
        importRaw.isAcceptableOrUnknown(data['import_raw']!, _importRawMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RideRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RideRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      tripId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trip_id'],
      ),
      dateInput: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date_input'],
      ),
      times: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}times'],
      ),
      trainName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}train_name'],
      ),
      carNo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}car_no'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      serviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}service_id'],
      ),
      transferNodes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transfer_nodes'],
      )!,
      fromAlighted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}from_alighted'],
      )!,
      toAlighted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}to_alighted'],
      )!,
      datasetVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dataset_version'],
      )!,
      importSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}import_source'],
      ),
      importRaw: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}import_raw'],
      ),
    );
  }

  @override
  $RideTableTable createAlias(String alias) {
    return $RideTableTable(attachedDatabase, alias);
  }
}

class RideRow extends DataClass implements Insertable<RideRow> {
  final String id;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;
  final String? tripId;
  final String? dateInput;
  final String? times;
  final String? trainName;
  final String? carNo;
  final String? note;
  final String? serviceId;

  /// JSON 배열.
  final String transferNodes;
  final bool fromAlighted;
  final bool toAlighted;
  final String datasetVersion;
  final String? importSource;
  final String? importRaw;
  const RideRow({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.deviceId,
    this.tripId,
    this.dateInput,
    this.times,
    this.trainName,
    this.carNo,
    this.note,
    this.serviceId,
    required this.transferNodes,
    required this.fromAlighted,
    required this.toAlighted,
    required this.datasetVersion,
    this.importSource,
    this.importRaw,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    if (!nullToAbsent || tripId != null) {
      map['trip_id'] = Variable<String>(tripId);
    }
    if (!nullToAbsent || dateInput != null) {
      map['date_input'] = Variable<String>(dateInput);
    }
    if (!nullToAbsent || times != null) {
      map['times'] = Variable<String>(times);
    }
    if (!nullToAbsent || trainName != null) {
      map['train_name'] = Variable<String>(trainName);
    }
    if (!nullToAbsent || carNo != null) {
      map['car_no'] = Variable<String>(carNo);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || serviceId != null) {
      map['service_id'] = Variable<String>(serviceId);
    }
    map['transfer_nodes'] = Variable<String>(transferNodes);
    map['from_alighted'] = Variable<bool>(fromAlighted);
    map['to_alighted'] = Variable<bool>(toAlighted);
    map['dataset_version'] = Variable<String>(datasetVersion);
    if (!nullToAbsent || importSource != null) {
      map['import_source'] = Variable<String>(importSource);
    }
    if (!nullToAbsent || importRaw != null) {
      map['import_raw'] = Variable<String>(importRaw);
    }
    return map;
  }

  RideTableCompanion toCompanion(bool nullToAbsent) {
    return RideTableCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deviceId: Value(deviceId),
      tripId: tripId == null && nullToAbsent
          ? const Value.absent()
          : Value(tripId),
      dateInput: dateInput == null && nullToAbsent
          ? const Value.absent()
          : Value(dateInput),
      times: times == null && nullToAbsent
          ? const Value.absent()
          : Value(times),
      trainName: trainName == null && nullToAbsent
          ? const Value.absent()
          : Value(trainName),
      carNo: carNo == null && nullToAbsent
          ? const Value.absent()
          : Value(carNo),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      serviceId: serviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(serviceId),
      transferNodes: Value(transferNodes),
      fromAlighted: Value(fromAlighted),
      toAlighted: Value(toAlighted),
      datasetVersion: Value(datasetVersion),
      importSource: importSource == null && nullToAbsent
          ? const Value.absent()
          : Value(importSource),
      importRaw: importRaw == null && nullToAbsent
          ? const Value.absent()
          : Value(importRaw),
    );
  }

  factory RideRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RideRow(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      tripId: serializer.fromJson<String?>(json['tripId']),
      dateInput: serializer.fromJson<String?>(json['dateInput']),
      times: serializer.fromJson<String?>(json['times']),
      trainName: serializer.fromJson<String?>(json['trainName']),
      carNo: serializer.fromJson<String?>(json['carNo']),
      note: serializer.fromJson<String?>(json['note']),
      serviceId: serializer.fromJson<String?>(json['serviceId']),
      transferNodes: serializer.fromJson<String>(json['transferNodes']),
      fromAlighted: serializer.fromJson<bool>(json['fromAlighted']),
      toAlighted: serializer.fromJson<bool>(json['toAlighted']),
      datasetVersion: serializer.fromJson<String>(json['datasetVersion']),
      importSource: serializer.fromJson<String?>(json['importSource']),
      importRaw: serializer.fromJson<String?>(json['importRaw']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'deviceId': serializer.toJson<String>(deviceId),
      'tripId': serializer.toJson<String?>(tripId),
      'dateInput': serializer.toJson<String?>(dateInput),
      'times': serializer.toJson<String?>(times),
      'trainName': serializer.toJson<String?>(trainName),
      'carNo': serializer.toJson<String?>(carNo),
      'note': serializer.toJson<String?>(note),
      'serviceId': serializer.toJson<String?>(serviceId),
      'transferNodes': serializer.toJson<String>(transferNodes),
      'fromAlighted': serializer.toJson<bool>(fromAlighted),
      'toAlighted': serializer.toJson<bool>(toAlighted),
      'datasetVersion': serializer.toJson<String>(datasetVersion),
      'importSource': serializer.toJson<String?>(importSource),
      'importRaw': serializer.toJson<String?>(importRaw),
    };
  }

  RideRow copyWith({
    String? id,
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    String? deviceId,
    Value<String?> tripId = const Value.absent(),
    Value<String?> dateInput = const Value.absent(),
    Value<String?> times = const Value.absent(),
    Value<String?> trainName = const Value.absent(),
    Value<String?> carNo = const Value.absent(),
    Value<String?> note = const Value.absent(),
    Value<String?> serviceId = const Value.absent(),
    String? transferNodes,
    bool? fromAlighted,
    bool? toAlighted,
    String? datasetVersion,
    Value<String?> importSource = const Value.absent(),
    Value<String?> importRaw = const Value.absent(),
  }) => RideRow(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
    tripId: tripId.present ? tripId.value : this.tripId,
    dateInput: dateInput.present ? dateInput.value : this.dateInput,
    times: times.present ? times.value : this.times,
    trainName: trainName.present ? trainName.value : this.trainName,
    carNo: carNo.present ? carNo.value : this.carNo,
    note: note.present ? note.value : this.note,
    serviceId: serviceId.present ? serviceId.value : this.serviceId,
    transferNodes: transferNodes ?? this.transferNodes,
    fromAlighted: fromAlighted ?? this.fromAlighted,
    toAlighted: toAlighted ?? this.toAlighted,
    datasetVersion: datasetVersion ?? this.datasetVersion,
    importSource: importSource.present ? importSource.value : this.importSource,
    importRaw: importRaw.present ? importRaw.value : this.importRaw,
  );
  RideRow copyWithCompanion(RideTableCompanion data) {
    return RideRow(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      tripId: data.tripId.present ? data.tripId.value : this.tripId,
      dateInput: data.dateInput.present ? data.dateInput.value : this.dateInput,
      times: data.times.present ? data.times.value : this.times,
      trainName: data.trainName.present ? data.trainName.value : this.trainName,
      carNo: data.carNo.present ? data.carNo.value : this.carNo,
      note: data.note.present ? data.note.value : this.note,
      serviceId: data.serviceId.present ? data.serviceId.value : this.serviceId,
      transferNodes: data.transferNodes.present
          ? data.transferNodes.value
          : this.transferNodes,
      fromAlighted: data.fromAlighted.present
          ? data.fromAlighted.value
          : this.fromAlighted,
      toAlighted: data.toAlighted.present
          ? data.toAlighted.value
          : this.toAlighted,
      datasetVersion: data.datasetVersion.present
          ? data.datasetVersion.value
          : this.datasetVersion,
      importSource: data.importSource.present
          ? data.importSource.value
          : this.importSource,
      importRaw: data.importRaw.present ? data.importRaw.value : this.importRaw,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RideRow(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('tripId: $tripId, ')
          ..write('dateInput: $dateInput, ')
          ..write('times: $times, ')
          ..write('trainName: $trainName, ')
          ..write('carNo: $carNo, ')
          ..write('note: $note, ')
          ..write('serviceId: $serviceId, ')
          ..write('transferNodes: $transferNodes, ')
          ..write('fromAlighted: $fromAlighted, ')
          ..write('toAlighted: $toAlighted, ')
          ..write('datasetVersion: $datasetVersion, ')
          ..write('importSource: $importSource, ')
          ..write('importRaw: $importRaw')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
    tripId,
    dateInput,
    times,
    trainName,
    carNo,
    note,
    serviceId,
    transferNodes,
    fromAlighted,
    toAlighted,
    datasetVersion,
    importSource,
    importRaw,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RideRow &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId &&
          other.tripId == this.tripId &&
          other.dateInput == this.dateInput &&
          other.times == this.times &&
          other.trainName == this.trainName &&
          other.carNo == this.carNo &&
          other.note == this.note &&
          other.serviceId == this.serviceId &&
          other.transferNodes == this.transferNodes &&
          other.fromAlighted == this.fromAlighted &&
          other.toAlighted == this.toAlighted &&
          other.datasetVersion == this.datasetVersion &&
          other.importSource == this.importSource &&
          other.importRaw == this.importRaw);
}

class RideTableCompanion extends UpdateCompanion<RideRow> {
  final Value<String> id;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<String> deviceId;
  final Value<String?> tripId;
  final Value<String?> dateInput;
  final Value<String?> times;
  final Value<String?> trainName;
  final Value<String?> carNo;
  final Value<String?> note;
  final Value<String?> serviceId;
  final Value<String> transferNodes;
  final Value<bool> fromAlighted;
  final Value<bool> toAlighted;
  final Value<String> datasetVersion;
  final Value<String?> importSource;
  final Value<String?> importRaw;
  final Value<int> rowid;
  const RideTableCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.tripId = const Value.absent(),
    this.dateInput = const Value.absent(),
    this.times = const Value.absent(),
    this.trainName = const Value.absent(),
    this.carNo = const Value.absent(),
    this.note = const Value.absent(),
    this.serviceId = const Value.absent(),
    this.transferNodes = const Value.absent(),
    this.fromAlighted = const Value.absent(),
    this.toAlighted = const Value.absent(),
    this.datasetVersion = const Value.absent(),
    this.importSource = const Value.absent(),
    this.importRaw = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RideTableCompanion.insert({
    required String id,
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    required String deviceId,
    this.tripId = const Value.absent(),
    this.dateInput = const Value.absent(),
    this.times = const Value.absent(),
    this.trainName = const Value.absent(),
    this.carNo = const Value.absent(),
    this.note = const Value.absent(),
    this.serviceId = const Value.absent(),
    this.transferNodes = const Value.absent(),
    required bool fromAlighted,
    required bool toAlighted,
    required String datasetVersion,
    this.importSource = const Value.absent(),
    this.importRaw = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       deviceId = Value(deviceId),
       fromAlighted = Value(fromAlighted),
       toAlighted = Value(toAlighted),
       datasetVersion = Value(datasetVersion);
  static Insertable<RideRow> custom({
    Expression<String>? id,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<String>? deviceId,
    Expression<String>? tripId,
    Expression<String>? dateInput,
    Expression<String>? times,
    Expression<String>? trainName,
    Expression<String>? carNo,
    Expression<String>? note,
    Expression<String>? serviceId,
    Expression<String>? transferNodes,
    Expression<bool>? fromAlighted,
    Expression<bool>? toAlighted,
    Expression<String>? datasetVersion,
    Expression<String>? importSource,
    Expression<String>? importRaw,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (tripId != null) 'trip_id': tripId,
      if (dateInput != null) 'date_input': dateInput,
      if (times != null) 'times': times,
      if (trainName != null) 'train_name': trainName,
      if (carNo != null) 'car_no': carNo,
      if (note != null) 'note': note,
      if (serviceId != null) 'service_id': serviceId,
      if (transferNodes != null) 'transfer_nodes': transferNodes,
      if (fromAlighted != null) 'from_alighted': fromAlighted,
      if (toAlighted != null) 'to_alighted': toAlighted,
      if (datasetVersion != null) 'dataset_version': datasetVersion,
      if (importSource != null) 'import_source': importSource,
      if (importRaw != null) 'import_raw': importRaw,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RideTableCompanion copyWith({
    Value<String>? id,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<String>? deviceId,
    Value<String?>? tripId,
    Value<String?>? dateInput,
    Value<String?>? times,
    Value<String?>? trainName,
    Value<String?>? carNo,
    Value<String?>? note,
    Value<String?>? serviceId,
    Value<String>? transferNodes,
    Value<bool>? fromAlighted,
    Value<bool>? toAlighted,
    Value<String>? datasetVersion,
    Value<String?>? importSource,
    Value<String?>? importRaw,
    Value<int>? rowid,
  }) {
    return RideTableCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      tripId: tripId ?? this.tripId,
      dateInput: dateInput ?? this.dateInput,
      times: times ?? this.times,
      trainName: trainName ?? this.trainName,
      carNo: carNo ?? this.carNo,
      note: note ?? this.note,
      serviceId: serviceId ?? this.serviceId,
      transferNodes: transferNodes ?? this.transferNodes,
      fromAlighted: fromAlighted ?? this.fromAlighted,
      toAlighted: toAlighted ?? this.toAlighted,
      datasetVersion: datasetVersion ?? this.datasetVersion,
      importSource: importSource ?? this.importSource,
      importRaw: importRaw ?? this.importRaw,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (tripId.present) {
      map['trip_id'] = Variable<String>(tripId.value);
    }
    if (dateInput.present) {
      map['date_input'] = Variable<String>(dateInput.value);
    }
    if (times.present) {
      map['times'] = Variable<String>(times.value);
    }
    if (trainName.present) {
      map['train_name'] = Variable<String>(trainName.value);
    }
    if (carNo.present) {
      map['car_no'] = Variable<String>(carNo.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (serviceId.present) {
      map['service_id'] = Variable<String>(serviceId.value);
    }
    if (transferNodes.present) {
      map['transfer_nodes'] = Variable<String>(transferNodes.value);
    }
    if (fromAlighted.present) {
      map['from_alighted'] = Variable<bool>(fromAlighted.value);
    }
    if (toAlighted.present) {
      map['to_alighted'] = Variable<bool>(toAlighted.value);
    }
    if (datasetVersion.present) {
      map['dataset_version'] = Variable<String>(datasetVersion.value);
    }
    if (importSource.present) {
      map['import_source'] = Variable<String>(importSource.value);
    }
    if (importRaw.present) {
      map['import_raw'] = Variable<String>(importRaw.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RideTableCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('tripId: $tripId, ')
          ..write('dateInput: $dateInput, ')
          ..write('times: $times, ')
          ..write('trainName: $trainName, ')
          ..write('carNo: $carNo, ')
          ..write('note: $note, ')
          ..write('serviceId: $serviceId, ')
          ..write('transferNodes: $transferNodes, ')
          ..write('fromAlighted: $fromAlighted, ')
          ..write('toAlighted: $toAlighted, ')
          ..write('datasetVersion: $datasetVersion, ')
          ..write('importSource: $importSource, ')
          ..write('importRaw: $importRaw, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RideLegTableTable extends RideLegTable
    with TableInfo<$RideLegTableTable, RideLegRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RideLegTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _rideIdMeta = const VerificationMeta('rideId');
  @override
  late final GeneratedColumn<String> rideId = GeneratedColumn<String>(
    'ride_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lineIdMeta = const VerificationMeta('lineId');
  @override
  late final GeneratedColumn<String> lineId = GeneratedColumn<String>(
    'line_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _routeIdMeta = const VerificationMeta(
    'routeId',
  );
  @override
  late final GeneratedColumn<String> routeId = GeneratedColumn<String>(
    'route_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fromNodeMeta = const VerificationMeta(
    'fromNode',
  );
  @override
  late final GeneratedColumn<String> fromNode = GeneratedColumn<String>(
    'from_node',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toNodeMeta = const VerificationMeta('toNode');
  @override
  late final GeneratedColumn<String> toNode = GeneratedColumn<String>(
    'to_node',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _directionMeta = const VerificationMeta(
    'direction',
  );
  @override
  late final GeneratedColumn<String> direction = GeneratedColumn<String>(
    'direction',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resolveAsOfMeta = const VerificationMeta(
    'resolveAsOf',
  );
  @override
  late final GeneratedColumn<String> resolveAsOf = GeneratedColumn<String>(
    'resolve_as_of',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resolveUnknownMeta = const VerificationMeta(
    'resolveUnknown',
  );
  @override
  late final GeneratedColumn<bool> resolveUnknown = GeneratedColumn<bool>(
    'resolve_unknown',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("resolve_unknown" IN (0, 1))',
    ),
  );
  static const VerificationMeta _lineLabelMeta = const VerificationMeta(
    'lineLabel',
  );
  @override
  late final GeneratedColumn<String> lineLabel = GeneratedColumn<String>(
    'line_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fromLabelMeta = const VerificationMeta(
    'fromLabel',
  );
  @override
  late final GeneratedColumn<String> fromLabel = GeneratedColumn<String>(
    'from_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toLabelMeta = const VerificationMeta(
    'toLabel',
  );
  @override
  late final GeneratedColumn<String> toLabel = GeneratedColumn<String>(
    'to_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    rideId,
    seq,
    lineId,
    routeId,
    fromNode,
    toNode,
    direction,
    resolveAsOf,
    resolveUnknown,
    lineLabel,
    fromLabel,
    toLabel,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ride_leg';
  @override
  VerificationContext validateIntegrity(
    Insertable<RideLegRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('ride_id')) {
      context.handle(
        _rideIdMeta,
        rideId.isAcceptableOrUnknown(data['ride_id']!, _rideIdMeta),
      );
    } else if (isInserting) {
      context.missing(_rideIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    if (data.containsKey('line_id')) {
      context.handle(
        _lineIdMeta,
        lineId.isAcceptableOrUnknown(data['line_id']!, _lineIdMeta),
      );
    } else if (isInserting) {
      context.missing(_lineIdMeta);
    }
    if (data.containsKey('route_id')) {
      context.handle(
        _routeIdMeta,
        routeId.isAcceptableOrUnknown(data['route_id']!, _routeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_routeIdMeta);
    }
    if (data.containsKey('from_node')) {
      context.handle(
        _fromNodeMeta,
        fromNode.isAcceptableOrUnknown(data['from_node']!, _fromNodeMeta),
      );
    } else if (isInserting) {
      context.missing(_fromNodeMeta);
    }
    if (data.containsKey('to_node')) {
      context.handle(
        _toNodeMeta,
        toNode.isAcceptableOrUnknown(data['to_node']!, _toNodeMeta),
      );
    } else if (isInserting) {
      context.missing(_toNodeMeta);
    }
    if (data.containsKey('direction')) {
      context.handle(
        _directionMeta,
        direction.isAcceptableOrUnknown(data['direction']!, _directionMeta),
      );
    }
    if (data.containsKey('resolve_as_of')) {
      context.handle(
        _resolveAsOfMeta,
        resolveAsOf.isAcceptableOrUnknown(
          data['resolve_as_of']!,
          _resolveAsOfMeta,
        ),
      );
    }
    if (data.containsKey('resolve_unknown')) {
      context.handle(
        _resolveUnknownMeta,
        resolveUnknown.isAcceptableOrUnknown(
          data['resolve_unknown']!,
          _resolveUnknownMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_resolveUnknownMeta);
    }
    if (data.containsKey('line_label')) {
      context.handle(
        _lineLabelMeta,
        lineLabel.isAcceptableOrUnknown(data['line_label']!, _lineLabelMeta),
      );
    } else if (isInserting) {
      context.missing(_lineLabelMeta);
    }
    if (data.containsKey('from_label')) {
      context.handle(
        _fromLabelMeta,
        fromLabel.isAcceptableOrUnknown(data['from_label']!, _fromLabelMeta),
      );
    } else if (isInserting) {
      context.missing(_fromLabelMeta);
    }
    if (data.containsKey('to_label')) {
      context.handle(
        _toLabelMeta,
        toLabel.isAcceptableOrUnknown(data['to_label']!, _toLabelMeta),
      );
    } else if (isInserting) {
      context.missing(_toLabelMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {rideId, seq};
  @override
  RideLegRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RideLegRow(
      rideId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ride_id'],
      )!,
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      lineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}line_id'],
      )!,
      routeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}route_id'],
      )!,
      fromNode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_node'],
      )!,
      toNode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_node'],
      )!,
      direction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direction'],
      ),
      resolveAsOf: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resolve_as_of'],
      ),
      resolveUnknown: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}resolve_unknown'],
      )!,
      lineLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}line_label'],
      )!,
      fromLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_label'],
      )!,
      toLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_label'],
      )!,
    );
  }

  @override
  $RideLegTableTable createAlias(String alias) {
    return $RideLegTableTable(attachedDatabase, alias);
  }
}

class RideLegRow extends DataClass implements Insertable<RideLegRow> {
  final String rideId;
  final int seq;
  final String lineId;
  final String routeId;
  final String fromNode;
  final String toNode;
  final String? direction;
  final String? resolveAsOf;
  final bool resolveUnknown;
  final String lineLabel;
  final String fromLabel;
  final String toLabel;
  const RideLegRow({
    required this.rideId,
    required this.seq,
    required this.lineId,
    required this.routeId,
    required this.fromNode,
    required this.toNode,
    this.direction,
    this.resolveAsOf,
    required this.resolveUnknown,
    required this.lineLabel,
    required this.fromLabel,
    required this.toLabel,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['ride_id'] = Variable<String>(rideId);
    map['seq'] = Variable<int>(seq);
    map['line_id'] = Variable<String>(lineId);
    map['route_id'] = Variable<String>(routeId);
    map['from_node'] = Variable<String>(fromNode);
    map['to_node'] = Variable<String>(toNode);
    if (!nullToAbsent || direction != null) {
      map['direction'] = Variable<String>(direction);
    }
    if (!nullToAbsent || resolveAsOf != null) {
      map['resolve_as_of'] = Variable<String>(resolveAsOf);
    }
    map['resolve_unknown'] = Variable<bool>(resolveUnknown);
    map['line_label'] = Variable<String>(lineLabel);
    map['from_label'] = Variable<String>(fromLabel);
    map['to_label'] = Variable<String>(toLabel);
    return map;
  }

  RideLegTableCompanion toCompanion(bool nullToAbsent) {
    return RideLegTableCompanion(
      rideId: Value(rideId),
      seq: Value(seq),
      lineId: Value(lineId),
      routeId: Value(routeId),
      fromNode: Value(fromNode),
      toNode: Value(toNode),
      direction: direction == null && nullToAbsent
          ? const Value.absent()
          : Value(direction),
      resolveAsOf: resolveAsOf == null && nullToAbsent
          ? const Value.absent()
          : Value(resolveAsOf),
      resolveUnknown: Value(resolveUnknown),
      lineLabel: Value(lineLabel),
      fromLabel: Value(fromLabel),
      toLabel: Value(toLabel),
    );
  }

  factory RideLegRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RideLegRow(
      rideId: serializer.fromJson<String>(json['rideId']),
      seq: serializer.fromJson<int>(json['seq']),
      lineId: serializer.fromJson<String>(json['lineId']),
      routeId: serializer.fromJson<String>(json['routeId']),
      fromNode: serializer.fromJson<String>(json['fromNode']),
      toNode: serializer.fromJson<String>(json['toNode']),
      direction: serializer.fromJson<String?>(json['direction']),
      resolveAsOf: serializer.fromJson<String?>(json['resolveAsOf']),
      resolveUnknown: serializer.fromJson<bool>(json['resolveUnknown']),
      lineLabel: serializer.fromJson<String>(json['lineLabel']),
      fromLabel: serializer.fromJson<String>(json['fromLabel']),
      toLabel: serializer.fromJson<String>(json['toLabel']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'rideId': serializer.toJson<String>(rideId),
      'seq': serializer.toJson<int>(seq),
      'lineId': serializer.toJson<String>(lineId),
      'routeId': serializer.toJson<String>(routeId),
      'fromNode': serializer.toJson<String>(fromNode),
      'toNode': serializer.toJson<String>(toNode),
      'direction': serializer.toJson<String?>(direction),
      'resolveAsOf': serializer.toJson<String?>(resolveAsOf),
      'resolveUnknown': serializer.toJson<bool>(resolveUnknown),
      'lineLabel': serializer.toJson<String>(lineLabel),
      'fromLabel': serializer.toJson<String>(fromLabel),
      'toLabel': serializer.toJson<String>(toLabel),
    };
  }

  RideLegRow copyWith({
    String? rideId,
    int? seq,
    String? lineId,
    String? routeId,
    String? fromNode,
    String? toNode,
    Value<String?> direction = const Value.absent(),
    Value<String?> resolveAsOf = const Value.absent(),
    bool? resolveUnknown,
    String? lineLabel,
    String? fromLabel,
    String? toLabel,
  }) => RideLegRow(
    rideId: rideId ?? this.rideId,
    seq: seq ?? this.seq,
    lineId: lineId ?? this.lineId,
    routeId: routeId ?? this.routeId,
    fromNode: fromNode ?? this.fromNode,
    toNode: toNode ?? this.toNode,
    direction: direction.present ? direction.value : this.direction,
    resolveAsOf: resolveAsOf.present ? resolveAsOf.value : this.resolveAsOf,
    resolveUnknown: resolveUnknown ?? this.resolveUnknown,
    lineLabel: lineLabel ?? this.lineLabel,
    fromLabel: fromLabel ?? this.fromLabel,
    toLabel: toLabel ?? this.toLabel,
  );
  RideLegRow copyWithCompanion(RideLegTableCompanion data) {
    return RideLegRow(
      rideId: data.rideId.present ? data.rideId.value : this.rideId,
      seq: data.seq.present ? data.seq.value : this.seq,
      lineId: data.lineId.present ? data.lineId.value : this.lineId,
      routeId: data.routeId.present ? data.routeId.value : this.routeId,
      fromNode: data.fromNode.present ? data.fromNode.value : this.fromNode,
      toNode: data.toNode.present ? data.toNode.value : this.toNode,
      direction: data.direction.present ? data.direction.value : this.direction,
      resolveAsOf: data.resolveAsOf.present
          ? data.resolveAsOf.value
          : this.resolveAsOf,
      resolveUnknown: data.resolveUnknown.present
          ? data.resolveUnknown.value
          : this.resolveUnknown,
      lineLabel: data.lineLabel.present ? data.lineLabel.value : this.lineLabel,
      fromLabel: data.fromLabel.present ? data.fromLabel.value : this.fromLabel,
      toLabel: data.toLabel.present ? data.toLabel.value : this.toLabel,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RideLegRow(')
          ..write('rideId: $rideId, ')
          ..write('seq: $seq, ')
          ..write('lineId: $lineId, ')
          ..write('routeId: $routeId, ')
          ..write('fromNode: $fromNode, ')
          ..write('toNode: $toNode, ')
          ..write('direction: $direction, ')
          ..write('resolveAsOf: $resolveAsOf, ')
          ..write('resolveUnknown: $resolveUnknown, ')
          ..write('lineLabel: $lineLabel, ')
          ..write('fromLabel: $fromLabel, ')
          ..write('toLabel: $toLabel')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    rideId,
    seq,
    lineId,
    routeId,
    fromNode,
    toNode,
    direction,
    resolveAsOf,
    resolveUnknown,
    lineLabel,
    fromLabel,
    toLabel,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RideLegRow &&
          other.rideId == this.rideId &&
          other.seq == this.seq &&
          other.lineId == this.lineId &&
          other.routeId == this.routeId &&
          other.fromNode == this.fromNode &&
          other.toNode == this.toNode &&
          other.direction == this.direction &&
          other.resolveAsOf == this.resolveAsOf &&
          other.resolveUnknown == this.resolveUnknown &&
          other.lineLabel == this.lineLabel &&
          other.fromLabel == this.fromLabel &&
          other.toLabel == this.toLabel);
}

class RideLegTableCompanion extends UpdateCompanion<RideLegRow> {
  final Value<String> rideId;
  final Value<int> seq;
  final Value<String> lineId;
  final Value<String> routeId;
  final Value<String> fromNode;
  final Value<String> toNode;
  final Value<String?> direction;
  final Value<String?> resolveAsOf;
  final Value<bool> resolveUnknown;
  final Value<String> lineLabel;
  final Value<String> fromLabel;
  final Value<String> toLabel;
  final Value<int> rowid;
  const RideLegTableCompanion({
    this.rideId = const Value.absent(),
    this.seq = const Value.absent(),
    this.lineId = const Value.absent(),
    this.routeId = const Value.absent(),
    this.fromNode = const Value.absent(),
    this.toNode = const Value.absent(),
    this.direction = const Value.absent(),
    this.resolveAsOf = const Value.absent(),
    this.resolveUnknown = const Value.absent(),
    this.lineLabel = const Value.absent(),
    this.fromLabel = const Value.absent(),
    this.toLabel = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RideLegTableCompanion.insert({
    required String rideId,
    required int seq,
    required String lineId,
    required String routeId,
    required String fromNode,
    required String toNode,
    this.direction = const Value.absent(),
    this.resolveAsOf = const Value.absent(),
    required bool resolveUnknown,
    required String lineLabel,
    required String fromLabel,
    required String toLabel,
    this.rowid = const Value.absent(),
  }) : rideId = Value(rideId),
       seq = Value(seq),
       lineId = Value(lineId),
       routeId = Value(routeId),
       fromNode = Value(fromNode),
       toNode = Value(toNode),
       resolveUnknown = Value(resolveUnknown),
       lineLabel = Value(lineLabel),
       fromLabel = Value(fromLabel),
       toLabel = Value(toLabel);
  static Insertable<RideLegRow> custom({
    Expression<String>? rideId,
    Expression<int>? seq,
    Expression<String>? lineId,
    Expression<String>? routeId,
    Expression<String>? fromNode,
    Expression<String>? toNode,
    Expression<String>? direction,
    Expression<String>? resolveAsOf,
    Expression<bool>? resolveUnknown,
    Expression<String>? lineLabel,
    Expression<String>? fromLabel,
    Expression<String>? toLabel,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (rideId != null) 'ride_id': rideId,
      if (seq != null) 'seq': seq,
      if (lineId != null) 'line_id': lineId,
      if (routeId != null) 'route_id': routeId,
      if (fromNode != null) 'from_node': fromNode,
      if (toNode != null) 'to_node': toNode,
      if (direction != null) 'direction': direction,
      if (resolveAsOf != null) 'resolve_as_of': resolveAsOf,
      if (resolveUnknown != null) 'resolve_unknown': resolveUnknown,
      if (lineLabel != null) 'line_label': lineLabel,
      if (fromLabel != null) 'from_label': fromLabel,
      if (toLabel != null) 'to_label': toLabel,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RideLegTableCompanion copyWith({
    Value<String>? rideId,
    Value<int>? seq,
    Value<String>? lineId,
    Value<String>? routeId,
    Value<String>? fromNode,
    Value<String>? toNode,
    Value<String?>? direction,
    Value<String?>? resolveAsOf,
    Value<bool>? resolveUnknown,
    Value<String>? lineLabel,
    Value<String>? fromLabel,
    Value<String>? toLabel,
    Value<int>? rowid,
  }) {
    return RideLegTableCompanion(
      rideId: rideId ?? this.rideId,
      seq: seq ?? this.seq,
      lineId: lineId ?? this.lineId,
      routeId: routeId ?? this.routeId,
      fromNode: fromNode ?? this.fromNode,
      toNode: toNode ?? this.toNode,
      direction: direction ?? this.direction,
      resolveAsOf: resolveAsOf ?? this.resolveAsOf,
      resolveUnknown: resolveUnknown ?? this.resolveUnknown,
      lineLabel: lineLabel ?? this.lineLabel,
      fromLabel: fromLabel ?? this.fromLabel,
      toLabel: toLabel ?? this.toLabel,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (rideId.present) {
      map['ride_id'] = Variable<String>(rideId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (lineId.present) {
      map['line_id'] = Variable<String>(lineId.value);
    }
    if (routeId.present) {
      map['route_id'] = Variable<String>(routeId.value);
    }
    if (fromNode.present) {
      map['from_node'] = Variable<String>(fromNode.value);
    }
    if (toNode.present) {
      map['to_node'] = Variable<String>(toNode.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(direction.value);
    }
    if (resolveAsOf.present) {
      map['resolve_as_of'] = Variable<String>(resolveAsOf.value);
    }
    if (resolveUnknown.present) {
      map['resolve_unknown'] = Variable<bool>(resolveUnknown.value);
    }
    if (lineLabel.present) {
      map['line_label'] = Variable<String>(lineLabel.value);
    }
    if (fromLabel.present) {
      map['from_label'] = Variable<String>(fromLabel.value);
    }
    if (toLabel.present) {
      map['to_label'] = Variable<String>(toLabel.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RideLegTableCompanion(')
          ..write('rideId: $rideId, ')
          ..write('seq: $seq, ')
          ..write('lineId: $lineId, ')
          ..write('routeId: $routeId, ')
          ..write('fromNode: $fromNode, ')
          ..write('toNode: $toNode, ')
          ..write('direction: $direction, ')
          ..write('resolveAsOf: $resolveAsOf, ')
          ..write('resolveUnknown: $resolveUnknown, ')
          ..write('lineLabel: $lineLabel, ')
          ..write('fromLabel: $fromLabel, ')
          ..write('toLabel: $toLabel, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VisitTableTable extends VisitTable
    with TableInfo<$VisitTableTable, VisitRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VisitTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nodeIdMeta = const VerificationMeta('nodeId');
  @override
  late final GeneratedColumn<String> nodeId = GeneratedColumn<String>(
    'node_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nodeLabelMeta = const VerificationMeta(
    'nodeLabel',
  );
  @override
  late final GeneratedColumn<String> nodeLabel = GeneratedColumn<String>(
    'node_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nodeExplicitMeta = const VerificationMeta(
    'nodeExplicit',
  );
  @override
  late final GeneratedColumn<bool> nodeExplicit = GeneratedColumn<bool>(
    'node_explicit',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("node_explicit" IN (0, 1))',
    ),
  );
  static const VerificationMeta _dateInputMeta = const VerificationMeta(
    'dateInput',
  );
  @override
  late final GeneratedColumn<String> dateInput = GeneratedColumn<String>(
    'date_input',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
    nodeId,
    nodeLabel,
    nodeExplicit,
    dateInput,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'visit';
  @override
  VerificationContext validateIntegrity(
    Insertable<VisitRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('node_id')) {
      context.handle(
        _nodeIdMeta,
        nodeId.isAcceptableOrUnknown(data['node_id']!, _nodeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_nodeIdMeta);
    }
    if (data.containsKey('node_label')) {
      context.handle(
        _nodeLabelMeta,
        nodeLabel.isAcceptableOrUnknown(data['node_label']!, _nodeLabelMeta),
      );
    } else if (isInserting) {
      context.missing(_nodeLabelMeta);
    }
    if (data.containsKey('node_explicit')) {
      context.handle(
        _nodeExplicitMeta,
        nodeExplicit.isAcceptableOrUnknown(
          data['node_explicit']!,
          _nodeExplicitMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nodeExplicitMeta);
    }
    if (data.containsKey('date_input')) {
      context.handle(
        _dateInputMeta,
        dateInput.isAcceptableOrUnknown(data['date_input']!, _dateInputMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VisitRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VisitRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      nodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}node_id'],
      )!,
      nodeLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}node_label'],
      )!,
      nodeExplicit: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}node_explicit'],
      )!,
      dateInput: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date_input'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $VisitTableTable createAlias(String alias) {
    return $VisitTableTable(attachedDatabase, alias);
  }
}

class VisitRow extends DataClass implements Insertable<VisitRow> {
  final String id;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;
  final String nodeId;
  final String nodeLabel;
  final bool nodeExplicit;
  final String? dateInput;
  final String? note;
  const VisitRow({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.deviceId,
    required this.nodeId,
    required this.nodeLabel,
    required this.nodeExplicit,
    this.dateInput,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    map['node_id'] = Variable<String>(nodeId);
    map['node_label'] = Variable<String>(nodeLabel);
    map['node_explicit'] = Variable<bool>(nodeExplicit);
    if (!nullToAbsent || dateInput != null) {
      map['date_input'] = Variable<String>(dateInput);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  VisitTableCompanion toCompanion(bool nullToAbsent) {
    return VisitTableCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deviceId: Value(deviceId),
      nodeId: Value(nodeId),
      nodeLabel: Value(nodeLabel),
      nodeExplicit: Value(nodeExplicit),
      dateInput: dateInput == null && nullToAbsent
          ? const Value.absent()
          : Value(dateInput),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory VisitRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VisitRow(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      nodeId: serializer.fromJson<String>(json['nodeId']),
      nodeLabel: serializer.fromJson<String>(json['nodeLabel']),
      nodeExplicit: serializer.fromJson<bool>(json['nodeExplicit']),
      dateInput: serializer.fromJson<String?>(json['dateInput']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'deviceId': serializer.toJson<String>(deviceId),
      'nodeId': serializer.toJson<String>(nodeId),
      'nodeLabel': serializer.toJson<String>(nodeLabel),
      'nodeExplicit': serializer.toJson<bool>(nodeExplicit),
      'dateInput': serializer.toJson<String?>(dateInput),
      'note': serializer.toJson<String?>(note),
    };
  }

  VisitRow copyWith({
    String? id,
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    String? deviceId,
    String? nodeId,
    String? nodeLabel,
    bool? nodeExplicit,
    Value<String?> dateInput = const Value.absent(),
    Value<String?> note = const Value.absent(),
  }) => VisitRow(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
    nodeId: nodeId ?? this.nodeId,
    nodeLabel: nodeLabel ?? this.nodeLabel,
    nodeExplicit: nodeExplicit ?? this.nodeExplicit,
    dateInput: dateInput.present ? dateInput.value : this.dateInput,
    note: note.present ? note.value : this.note,
  );
  VisitRow copyWithCompanion(VisitTableCompanion data) {
    return VisitRow(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      nodeId: data.nodeId.present ? data.nodeId.value : this.nodeId,
      nodeLabel: data.nodeLabel.present ? data.nodeLabel.value : this.nodeLabel,
      nodeExplicit: data.nodeExplicit.present
          ? data.nodeExplicit.value
          : this.nodeExplicit,
      dateInput: data.dateInput.present ? data.dateInput.value : this.dateInput,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VisitRow(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('nodeId: $nodeId, ')
          ..write('nodeLabel: $nodeLabel, ')
          ..write('nodeExplicit: $nodeExplicit, ')
          ..write('dateInput: $dateInput, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
    nodeId,
    nodeLabel,
    nodeExplicit,
    dateInput,
    note,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VisitRow &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId &&
          other.nodeId == this.nodeId &&
          other.nodeLabel == this.nodeLabel &&
          other.nodeExplicit == this.nodeExplicit &&
          other.dateInput == this.dateInput &&
          other.note == this.note);
}

class VisitTableCompanion extends UpdateCompanion<VisitRow> {
  final Value<String> id;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<String> deviceId;
  final Value<String> nodeId;
  final Value<String> nodeLabel;
  final Value<bool> nodeExplicit;
  final Value<String?> dateInput;
  final Value<String?> note;
  final Value<int> rowid;
  const VisitTableCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.nodeId = const Value.absent(),
    this.nodeLabel = const Value.absent(),
    this.nodeExplicit = const Value.absent(),
    this.dateInput = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VisitTableCompanion.insert({
    required String id,
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    required String deviceId,
    required String nodeId,
    required String nodeLabel,
    required bool nodeExplicit,
    this.dateInput = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       deviceId = Value(deviceId),
       nodeId = Value(nodeId),
       nodeLabel = Value(nodeLabel),
       nodeExplicit = Value(nodeExplicit);
  static Insertable<VisitRow> custom({
    Expression<String>? id,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<String>? deviceId,
    Expression<String>? nodeId,
    Expression<String>? nodeLabel,
    Expression<bool>? nodeExplicit,
    Expression<String>? dateInput,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (nodeId != null) 'node_id': nodeId,
      if (nodeLabel != null) 'node_label': nodeLabel,
      if (nodeExplicit != null) 'node_explicit': nodeExplicit,
      if (dateInput != null) 'date_input': dateInput,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VisitTableCompanion copyWith({
    Value<String>? id,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<String>? deviceId,
    Value<String>? nodeId,
    Value<String>? nodeLabel,
    Value<bool>? nodeExplicit,
    Value<String?>? dateInput,
    Value<String?>? note,
    Value<int>? rowid,
  }) {
    return VisitTableCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      nodeId: nodeId ?? this.nodeId,
      nodeLabel: nodeLabel ?? this.nodeLabel,
      nodeExplicit: nodeExplicit ?? this.nodeExplicit,
      dateInput: dateInput ?? this.dateInput,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (nodeId.present) {
      map['node_id'] = Variable<String>(nodeId.value);
    }
    if (nodeLabel.present) {
      map['node_label'] = Variable<String>(nodeLabel.value);
    }
    if (nodeExplicit.present) {
      map['node_explicit'] = Variable<bool>(nodeExplicit.value);
    }
    if (dateInput.present) {
      map['date_input'] = Variable<String>(dateInput.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VisitTableCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('nodeId: $nodeId, ')
          ..write('nodeLabel: $nodeLabel, ')
          ..write('nodeExplicit: $nodeExplicit, ')
          ..write('dateInput: $dateInput, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PhotoTableTable extends PhotoTable
    with TableInfo<$PhotoTableTable, PhotoRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PhotoTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerTypeMeta = const VerificationMeta(
    'ownerType',
  );
  @override
  late final GeneratedColumn<String> ownerType = GeneratedColumn<String>(
    'owner_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _thumbPathMeta = const VerificationMeta(
    'thumbPath',
  );
  @override
  late final GeneratedColumn<String> thumbPath = GeneratedColumn<String>(
    'thumb_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
    ownerType,
    ownerId,
    sha256,
    thumbPath,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'photo';
  @override
  VerificationContext validateIntegrity(
    Insertable<PhotoRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('owner_type')) {
      context.handle(
        _ownerTypeMeta,
        ownerType.isAcceptableOrUnknown(data['owner_type']!, _ownerTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerTypeMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    } else if (isInserting) {
      context.missing(_sha256Meta);
    }
    if (data.containsKey('thumb_path')) {
      context.handle(
        _thumbPathMeta,
        thumbPath.isAcceptableOrUnknown(data['thumb_path']!, _thumbPathMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PhotoRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PhotoRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      ownerType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_type'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      )!,
      thumbPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumb_path'],
      ),
    );
  }

  @override
  $PhotoTableTable createAlias(String alias) {
    return $PhotoTableTable(attachedDatabase, alias);
  }
}

class PhotoRow extends DataClass implements Insertable<PhotoRow> {
  final String id;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;
  final String ownerType;
  final String ownerId;
  final String sha256;
  final String? thumbPath;
  const PhotoRow({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.deviceId,
    required this.ownerType,
    required this.ownerId,
    required this.sha256,
    this.thumbPath,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    map['owner_type'] = Variable<String>(ownerType);
    map['owner_id'] = Variable<String>(ownerId);
    map['sha256'] = Variable<String>(sha256);
    if (!nullToAbsent || thumbPath != null) {
      map['thumb_path'] = Variable<String>(thumbPath);
    }
    return map;
  }

  PhotoTableCompanion toCompanion(bool nullToAbsent) {
    return PhotoTableCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deviceId: Value(deviceId),
      ownerType: Value(ownerType),
      ownerId: Value(ownerId),
      sha256: Value(sha256),
      thumbPath: thumbPath == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbPath),
    );
  }

  factory PhotoRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PhotoRow(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      ownerType: serializer.fromJson<String>(json['ownerType']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      sha256: serializer.fromJson<String>(json['sha256']),
      thumbPath: serializer.fromJson<String?>(json['thumbPath']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'deviceId': serializer.toJson<String>(deviceId),
      'ownerType': serializer.toJson<String>(ownerType),
      'ownerId': serializer.toJson<String>(ownerId),
      'sha256': serializer.toJson<String>(sha256),
      'thumbPath': serializer.toJson<String?>(thumbPath),
    };
  }

  PhotoRow copyWith({
    String? id,
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    String? deviceId,
    String? ownerType,
    String? ownerId,
    String? sha256,
    Value<String?> thumbPath = const Value.absent(),
  }) => PhotoRow(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
    ownerType: ownerType ?? this.ownerType,
    ownerId: ownerId ?? this.ownerId,
    sha256: sha256 ?? this.sha256,
    thumbPath: thumbPath.present ? thumbPath.value : this.thumbPath,
  );
  PhotoRow copyWithCompanion(PhotoTableCompanion data) {
    return PhotoRow(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      ownerType: data.ownerType.present ? data.ownerType.value : this.ownerType,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      thumbPath: data.thumbPath.present ? data.thumbPath.value : this.thumbPath,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PhotoRow(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('ownerType: $ownerType, ')
          ..write('ownerId: $ownerId, ')
          ..write('sha256: $sha256, ')
          ..write('thumbPath: $thumbPath')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
    ownerType,
    ownerId,
    sha256,
    thumbPath,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PhotoRow &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId &&
          other.ownerType == this.ownerType &&
          other.ownerId == this.ownerId &&
          other.sha256 == this.sha256 &&
          other.thumbPath == this.thumbPath);
}

class PhotoTableCompanion extends UpdateCompanion<PhotoRow> {
  final Value<String> id;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<String> deviceId;
  final Value<String> ownerType;
  final Value<String> ownerId;
  final Value<String> sha256;
  final Value<String?> thumbPath;
  final Value<int> rowid;
  const PhotoTableCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.ownerType = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.thumbPath = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PhotoTableCompanion.insert({
    required String id,
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    required String deviceId,
    required String ownerType,
    required String ownerId,
    required String sha256,
    this.thumbPath = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       deviceId = Value(deviceId),
       ownerType = Value(ownerType),
       ownerId = Value(ownerId),
       sha256 = Value(sha256);
  static Insertable<PhotoRow> custom({
    Expression<String>? id,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<String>? deviceId,
    Expression<String>? ownerType,
    Expression<String>? ownerId,
    Expression<String>? sha256,
    Expression<String>? thumbPath,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (ownerType != null) 'owner_type': ownerType,
      if (ownerId != null) 'owner_id': ownerId,
      if (sha256 != null) 'sha256': sha256,
      if (thumbPath != null) 'thumb_path': thumbPath,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PhotoTableCompanion copyWith({
    Value<String>? id,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<String>? deviceId,
    Value<String>? ownerType,
    Value<String>? ownerId,
    Value<String>? sha256,
    Value<String?>? thumbPath,
    Value<int>? rowid,
  }) {
    return PhotoTableCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      ownerType: ownerType ?? this.ownerType,
      ownerId: ownerId ?? this.ownerId,
      sha256: sha256 ?? this.sha256,
      thumbPath: thumbPath ?? this.thumbPath,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (ownerType.present) {
      map['owner_type'] = Variable<String>(ownerType.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (thumbPath.present) {
      map['thumb_path'] = Variable<String>(thumbPath.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PhotoTableCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('ownerType: $ownerType, ')
          ..write('ownerId: $ownerId, ')
          ..write('sha256: $sha256, ')
          ..write('thumbPath: $thumbPath, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingTableTable extends SettingTable
    with TableInfo<$SettingTableTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'setting';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingTableTable createAlias(String alias) {
    return $SettingTableTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;
  final String value;
  const SettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingTableCompanion toCompanion(bool nullToAbsent) {
    return SettingTableCompanion(key: Value(key), value: Value(value));
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingRow copyWith({String? key, String? value}) =>
      SettingRow(key: key ?? this.key, value: value ?? this.value);
  SettingRow copyWithCompanion(SettingTableCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingTableCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingTableCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingTableCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingTableCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingTableCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingTableCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChangeReportTableTable extends ChangeReportTable
    with TableInfo<$ChangeReportTableTable, ChangeReportRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChangeReportTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _editionMeta = const VerificationMeta(
    'edition',
  );
  @override
  late final GeneratedColumn<String> edition = GeneratedColumn<String>(
    'edition',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    deviceId,
    edition,
    body,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'change_report';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChangeReportRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('edition')) {
      context.handle(
        _editionMeta,
        edition.isAcceptableOrUnknown(data['edition']!, _editionMeta),
      );
    } else if (isInserting) {
      context.missing(_editionMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChangeReportRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChangeReportRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      edition: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}edition'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
    );
  }

  @override
  $ChangeReportTableTable createAlias(String alias) {
    return $ChangeReportTableTable(attachedDatabase, alias);
  }
}

class ChangeReportRow extends DataClass implements Insertable<ChangeReportRow> {
  final String id;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  final String deviceId;
  final String edition;
  final String body;
  const ChangeReportRow({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.deviceId,
    required this.edition,
    required this.body,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['device_id'] = Variable<String>(deviceId);
    map['edition'] = Variable<String>(edition);
    map['body'] = Variable<String>(body);
    return map;
  }

  ChangeReportTableCompanion toCompanion(bool nullToAbsent) {
    return ChangeReportTableCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      deviceId: Value(deviceId),
      edition: Value(edition),
      body: Value(body),
    );
  }

  factory ChangeReportRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChangeReportRow(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      edition: serializer.fromJson<String>(json['edition']),
      body: serializer.fromJson<String>(json['body']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'deviceId': serializer.toJson<String>(deviceId),
      'edition': serializer.toJson<String>(edition),
      'body': serializer.toJson<String>(body),
    };
  }

  ChangeReportRow copyWith({
    String? id,
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    String? deviceId,
    String? edition,
    String? body,
  }) => ChangeReportRow(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deviceId: deviceId ?? this.deviceId,
    edition: edition ?? this.edition,
    body: body ?? this.body,
  );
  ChangeReportRow copyWithCompanion(ChangeReportTableCompanion data) {
    return ChangeReportRow(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      edition: data.edition.present ? data.edition.value : this.edition,
      body: data.body.present ? data.body.value : this.body,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChangeReportRow(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('edition: $edition, ')
          ..write('body: $body')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, createdAt, updatedAt, deletedAt, deviceId, edition, body);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChangeReportRow &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deviceId == this.deviceId &&
          other.edition == this.edition &&
          other.body == this.body);
}

class ChangeReportTableCompanion extends UpdateCompanion<ChangeReportRow> {
  final Value<String> id;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<String> deviceId;
  final Value<String> edition;
  final Value<String> body;
  final Value<int> rowid;
  const ChangeReportTableCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.edition = const Value.absent(),
    this.body = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChangeReportTableCompanion.insert({
    required String id,
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    required String deviceId,
    required String edition,
    required String body,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       deviceId = Value(deviceId),
       edition = Value(edition),
       body = Value(body);
  static Insertable<ChangeReportRow> custom({
    Expression<String>? id,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<String>? deviceId,
    Expression<String>? edition,
    Expression<String>? body,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (edition != null) 'edition': edition,
      if (body != null) 'body': body,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChangeReportTableCompanion copyWith({
    Value<String>? id,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<String>? deviceId,
    Value<String>? edition,
    Value<String>? body,
    Value<int>? rowid,
  }) {
    return ChangeReportTableCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deviceId: deviceId ?? this.deviceId,
      edition: edition ?? this.edition,
      body: body ?? this.body,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (edition.present) {
      map['edition'] = Variable<String>(edition.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChangeReportTableCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('edition: $edition, ')
          ..write('body: $body, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CacheStateTableTable extends CacheStateTable
    with TableInfo<$CacheStateTableTable, CacheStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CacheStateTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _editionMeta = const VerificationMeta(
    'edition',
  );
  @override
  late final GeneratedColumn<String> edition = GeneratedColumn<String>(
    'edition',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _appBuildMeta = const VerificationMeta(
    'appBuild',
  );
  @override
  late final GeneratedColumn<int> appBuild = GeneratedColumn<int>(
    'app_build',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, edition, appBuild];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cache_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<CacheStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('edition')) {
      context.handle(
        _editionMeta,
        edition.isAcceptableOrUnknown(data['edition']!, _editionMeta),
      );
    } else if (isInserting) {
      context.missing(_editionMeta);
    }
    if (data.containsKey('app_build')) {
      context.handle(
        _appBuildMeta,
        appBuild.isAcceptableOrUnknown(data['app_build']!, _appBuildMeta),
      );
    } else if (isInserting) {
      context.missing(_appBuildMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CacheStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CacheStateRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      edition: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}edition'],
      )!,
      appBuild: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}app_build'],
      )!,
    );
  }

  @override
  $CacheStateTableTable createAlias(String alias) {
    return $CacheStateTableTable(attachedDatabase, alias);
  }
}

class CacheStateRow extends DataClass implements Insertable<CacheStateRow> {
  final int id;
  final String edition;
  final int appBuild;
  const CacheStateRow({
    required this.id,
    required this.edition,
    required this.appBuild,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['edition'] = Variable<String>(edition);
    map['app_build'] = Variable<int>(appBuild);
    return map;
  }

  CacheStateTableCompanion toCompanion(bool nullToAbsent) {
    return CacheStateTableCompanion(
      id: Value(id),
      edition: Value(edition),
      appBuild: Value(appBuild),
    );
  }

  factory CacheStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CacheStateRow(
      id: serializer.fromJson<int>(json['id']),
      edition: serializer.fromJson<String>(json['edition']),
      appBuild: serializer.fromJson<int>(json['appBuild']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'edition': serializer.toJson<String>(edition),
      'appBuild': serializer.toJson<int>(appBuild),
    };
  }

  CacheStateRow copyWith({int? id, String? edition, int? appBuild}) =>
      CacheStateRow(
        id: id ?? this.id,
        edition: edition ?? this.edition,
        appBuild: appBuild ?? this.appBuild,
      );
  CacheStateRow copyWithCompanion(CacheStateTableCompanion data) {
    return CacheStateRow(
      id: data.id.present ? data.id.value : this.id,
      edition: data.edition.present ? data.edition.value : this.edition,
      appBuild: data.appBuild.present ? data.appBuild.value : this.appBuild,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CacheStateRow(')
          ..write('id: $id, ')
          ..write('edition: $edition, ')
          ..write('appBuild: $appBuild')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, edition, appBuild);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CacheStateRow &&
          other.id == this.id &&
          other.edition == this.edition &&
          other.appBuild == this.appBuild);
}

class CacheStateTableCompanion extends UpdateCompanion<CacheStateRow> {
  final Value<int> id;
  final Value<String> edition;
  final Value<int> appBuild;
  const CacheStateTableCompanion({
    this.id = const Value.absent(),
    this.edition = const Value.absent(),
    this.appBuild = const Value.absent(),
  });
  CacheStateTableCompanion.insert({
    this.id = const Value.absent(),
    required String edition,
    required int appBuild,
  }) : edition = Value(edition),
       appBuild = Value(appBuild);
  static Insertable<CacheStateRow> custom({
    Expression<int>? id,
    Expression<String>? edition,
    Expression<int>? appBuild,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (edition != null) 'edition': edition,
      if (appBuild != null) 'app_build': appBuild,
    });
  }

  CacheStateTableCompanion copyWith({
    Value<int>? id,
    Value<String>? edition,
    Value<int>? appBuild,
  }) {
    return CacheStateTableCompanion(
      id: id ?? this.id,
      edition: edition ?? this.edition,
      appBuild: appBuild ?? this.appBuild,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (edition.present) {
      map['edition'] = Variable<String>(edition.value);
    }
    if (appBuild.present) {
      map['app_build'] = Variable<int>(appBuild.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CacheStateTableCompanion(')
          ..write('id: $id, ')
          ..write('edition: $edition, ')
          ..write('appBuild: $appBuild')
          ..write(')'))
        .toString();
  }
}

class $RideCacheTableTable extends RideCacheTable
    with TableInfo<$RideCacheTableTable, RideCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RideCacheTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _rideIdMeta = const VerificationMeta('rideId');
  @override
  late final GeneratedColumn<String> rideId = GeneratedColumn<String>(
    'ride_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resolveStatusMeta = const VerificationMeta(
    'resolveStatus',
  );
  @override
  late final GeneratedColumn<String> resolveStatus = GeneratedColumn<String>(
    'resolve_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _km10Meta = const VerificationMeta('km10');
  @override
  late final GeneratedColumn<int> km10 = GeneratedColumn<int>(
    'km10',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _effectiveLoMeta = const VerificationMeta(
    'effectiveLo',
  );
  @override
  late final GeneratedColumn<String> effectiveLo = GeneratedColumn<String>(
    'effective_lo',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _effectiveHiMeta = const VerificationMeta(
    'effectiveHi',
  );
  @override
  late final GeneratedColumn<String> effectiveHi = GeneratedColumn<String>(
    'effective_hi',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    rideId,
    resolveStatus,
    date,
    km10,
    effectiveLo,
    effectiveHi,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ride_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<RideCacheRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('ride_id')) {
      context.handle(
        _rideIdMeta,
        rideId.isAcceptableOrUnknown(data['ride_id']!, _rideIdMeta),
      );
    } else if (isInserting) {
      context.missing(_rideIdMeta);
    }
    if (data.containsKey('resolve_status')) {
      context.handle(
        _resolveStatusMeta,
        resolveStatus.isAcceptableOrUnknown(
          data['resolve_status']!,
          _resolveStatusMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_resolveStatusMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    }
    if (data.containsKey('km10')) {
      context.handle(
        _km10Meta,
        km10.isAcceptableOrUnknown(data['km10']!, _km10Meta),
      );
    }
    if (data.containsKey('effective_lo')) {
      context.handle(
        _effectiveLoMeta,
        effectiveLo.isAcceptableOrUnknown(
          data['effective_lo']!,
          _effectiveLoMeta,
        ),
      );
    }
    if (data.containsKey('effective_hi')) {
      context.handle(
        _effectiveHiMeta,
        effectiveHi.isAcceptableOrUnknown(
          data['effective_hi']!,
          _effectiveHiMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {rideId};
  @override
  RideCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RideCacheRow(
      rideId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ride_id'],
      )!,
      resolveStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resolve_status'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      ),
      km10: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}km10'],
      ),
      effectiveLo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}effective_lo'],
      ),
      effectiveHi: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}effective_hi'],
      ),
    );
  }

  @override
  $RideCacheTableTable createAlias(String alias) {
    return $RideCacheTableTable(attachedDatabase, alias);
  }
}

class RideCacheRow extends DataClass implements Insertable<RideCacheRow> {
  final String rideId;
  final String resolveStatus;
  final String? date;
  final int? km10;
  final String? effectiveLo;
  final String? effectiveHi;
  const RideCacheRow({
    required this.rideId,
    required this.resolveStatus,
    this.date,
    this.km10,
    this.effectiveLo,
    this.effectiveHi,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['ride_id'] = Variable<String>(rideId);
    map['resolve_status'] = Variable<String>(resolveStatus);
    if (!nullToAbsent || date != null) {
      map['date'] = Variable<String>(date);
    }
    if (!nullToAbsent || km10 != null) {
      map['km10'] = Variable<int>(km10);
    }
    if (!nullToAbsent || effectiveLo != null) {
      map['effective_lo'] = Variable<String>(effectiveLo);
    }
    if (!nullToAbsent || effectiveHi != null) {
      map['effective_hi'] = Variable<String>(effectiveHi);
    }
    return map;
  }

  RideCacheTableCompanion toCompanion(bool nullToAbsent) {
    return RideCacheTableCompanion(
      rideId: Value(rideId),
      resolveStatus: Value(resolveStatus),
      date: date == null && nullToAbsent ? const Value.absent() : Value(date),
      km10: km10 == null && nullToAbsent ? const Value.absent() : Value(km10),
      effectiveLo: effectiveLo == null && nullToAbsent
          ? const Value.absent()
          : Value(effectiveLo),
      effectiveHi: effectiveHi == null && nullToAbsent
          ? const Value.absent()
          : Value(effectiveHi),
    );
  }

  factory RideCacheRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RideCacheRow(
      rideId: serializer.fromJson<String>(json['rideId']),
      resolveStatus: serializer.fromJson<String>(json['resolveStatus']),
      date: serializer.fromJson<String?>(json['date']),
      km10: serializer.fromJson<int?>(json['km10']),
      effectiveLo: serializer.fromJson<String?>(json['effectiveLo']),
      effectiveHi: serializer.fromJson<String?>(json['effectiveHi']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'rideId': serializer.toJson<String>(rideId),
      'resolveStatus': serializer.toJson<String>(resolveStatus),
      'date': serializer.toJson<String?>(date),
      'km10': serializer.toJson<int?>(km10),
      'effectiveLo': serializer.toJson<String?>(effectiveLo),
      'effectiveHi': serializer.toJson<String?>(effectiveHi),
    };
  }

  RideCacheRow copyWith({
    String? rideId,
    String? resolveStatus,
    Value<String?> date = const Value.absent(),
    Value<int?> km10 = const Value.absent(),
    Value<String?> effectiveLo = const Value.absent(),
    Value<String?> effectiveHi = const Value.absent(),
  }) => RideCacheRow(
    rideId: rideId ?? this.rideId,
    resolveStatus: resolveStatus ?? this.resolveStatus,
    date: date.present ? date.value : this.date,
    km10: km10.present ? km10.value : this.km10,
    effectiveLo: effectiveLo.present ? effectiveLo.value : this.effectiveLo,
    effectiveHi: effectiveHi.present ? effectiveHi.value : this.effectiveHi,
  );
  RideCacheRow copyWithCompanion(RideCacheTableCompanion data) {
    return RideCacheRow(
      rideId: data.rideId.present ? data.rideId.value : this.rideId,
      resolveStatus: data.resolveStatus.present
          ? data.resolveStatus.value
          : this.resolveStatus,
      date: data.date.present ? data.date.value : this.date,
      km10: data.km10.present ? data.km10.value : this.km10,
      effectiveLo: data.effectiveLo.present
          ? data.effectiveLo.value
          : this.effectiveLo,
      effectiveHi: data.effectiveHi.present
          ? data.effectiveHi.value
          : this.effectiveHi,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RideCacheRow(')
          ..write('rideId: $rideId, ')
          ..write('resolveStatus: $resolveStatus, ')
          ..write('date: $date, ')
          ..write('km10: $km10, ')
          ..write('effectiveLo: $effectiveLo, ')
          ..write('effectiveHi: $effectiveHi')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(rideId, resolveStatus, date, km10, effectiveLo, effectiveHi);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RideCacheRow &&
          other.rideId == this.rideId &&
          other.resolveStatus == this.resolveStatus &&
          other.date == this.date &&
          other.km10 == this.km10 &&
          other.effectiveLo == this.effectiveLo &&
          other.effectiveHi == this.effectiveHi);
}

class RideCacheTableCompanion extends UpdateCompanion<RideCacheRow> {
  final Value<String> rideId;
  final Value<String> resolveStatus;
  final Value<String?> date;
  final Value<int?> km10;
  final Value<String?> effectiveLo;
  final Value<String?> effectiveHi;
  final Value<int> rowid;
  const RideCacheTableCompanion({
    this.rideId = const Value.absent(),
    this.resolveStatus = const Value.absent(),
    this.date = const Value.absent(),
    this.km10 = const Value.absent(),
    this.effectiveLo = const Value.absent(),
    this.effectiveHi = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RideCacheTableCompanion.insert({
    required String rideId,
    required String resolveStatus,
    this.date = const Value.absent(),
    this.km10 = const Value.absent(),
    this.effectiveLo = const Value.absent(),
    this.effectiveHi = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : rideId = Value(rideId),
       resolveStatus = Value(resolveStatus);
  static Insertable<RideCacheRow> custom({
    Expression<String>? rideId,
    Expression<String>? resolveStatus,
    Expression<String>? date,
    Expression<int>? km10,
    Expression<String>? effectiveLo,
    Expression<String>? effectiveHi,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (rideId != null) 'ride_id': rideId,
      if (resolveStatus != null) 'resolve_status': resolveStatus,
      if (date != null) 'date': date,
      if (km10 != null) 'km10': km10,
      if (effectiveLo != null) 'effective_lo': effectiveLo,
      if (effectiveHi != null) 'effective_hi': effectiveHi,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RideCacheTableCompanion copyWith({
    Value<String>? rideId,
    Value<String>? resolveStatus,
    Value<String?>? date,
    Value<int?>? km10,
    Value<String?>? effectiveLo,
    Value<String?>? effectiveHi,
    Value<int>? rowid,
  }) {
    return RideCacheTableCompanion(
      rideId: rideId ?? this.rideId,
      resolveStatus: resolveStatus ?? this.resolveStatus,
      date: date ?? this.date,
      km10: km10 ?? this.km10,
      effectiveLo: effectiveLo ?? this.effectiveLo,
      effectiveHi: effectiveHi ?? this.effectiveHi,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (rideId.present) {
      map['ride_id'] = Variable<String>(rideId.value);
    }
    if (resolveStatus.present) {
      map['resolve_status'] = Variable<String>(resolveStatus.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (km10.present) {
      map['km10'] = Variable<int>(km10.value);
    }
    if (effectiveLo.present) {
      map['effective_lo'] = Variable<String>(effectiveLo.value);
    }
    if (effectiveHi.present) {
      map['effective_hi'] = Variable<String>(effectiveHi.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RideCacheTableCompanion(')
          ..write('rideId: $rideId, ')
          ..write('resolveStatus: $resolveStatus, ')
          ..write('date: $date, ')
          ..write('km10: $km10, ')
          ..write('effectiveLo: $effectiveLo, ')
          ..write('effectiveHi: $effectiveHi, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RideLegCacheTableTable extends RideLegCacheTable
    with TableInfo<$RideLegCacheTableTable, RideLegCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RideLegCacheTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _rideIdMeta = const VerificationMeta('rideId');
  @override
  late final GeneratedColumn<String> rideId = GeneratedColumn<String>(
    'ride_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lineIdMeta = const VerificationMeta('lineId');
  @override
  late final GeneratedColumn<String> lineId = GeneratedColumn<String>(
    'line_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _routeIdMeta = const VerificationMeta(
    'routeId',
  );
  @override
  late final GeneratedColumn<String> routeId = GeneratedColumn<String>(
    'route_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _km10Meta = const VerificationMeta('km10');
  @override
  late final GeneratedColumn<int> km10 = GeneratedColumn<int>(
    'km10',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [rideId, seq, lineId, routeId, km10];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ride_leg_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<RideLegCacheRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('ride_id')) {
      context.handle(
        _rideIdMeta,
        rideId.isAcceptableOrUnknown(data['ride_id']!, _rideIdMeta),
      );
    } else if (isInserting) {
      context.missing(_rideIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    if (data.containsKey('line_id')) {
      context.handle(
        _lineIdMeta,
        lineId.isAcceptableOrUnknown(data['line_id']!, _lineIdMeta),
      );
    } else if (isInserting) {
      context.missing(_lineIdMeta);
    }
    if (data.containsKey('route_id')) {
      context.handle(
        _routeIdMeta,
        routeId.isAcceptableOrUnknown(data['route_id']!, _routeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_routeIdMeta);
    }
    if (data.containsKey('km10')) {
      context.handle(
        _km10Meta,
        km10.isAcceptableOrUnknown(data['km10']!, _km10Meta),
      );
    } else if (isInserting) {
      context.missing(_km10Meta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {rideId, seq};
  @override
  RideLegCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RideLegCacheRow(
      rideId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ride_id'],
      )!,
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      lineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}line_id'],
      )!,
      routeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}route_id'],
      )!,
      km10: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}km10'],
      )!,
    );
  }

  @override
  $RideLegCacheTableTable createAlias(String alias) {
    return $RideLegCacheTableTable(attachedDatabase, alias);
  }
}

class RideLegCacheRow extends DataClass implements Insertable<RideLegCacheRow> {
  final String rideId;
  final int seq;
  final String lineId;
  final String routeId;
  final int km10;
  const RideLegCacheRow({
    required this.rideId,
    required this.seq,
    required this.lineId,
    required this.routeId,
    required this.km10,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['ride_id'] = Variable<String>(rideId);
    map['seq'] = Variable<int>(seq);
    map['line_id'] = Variable<String>(lineId);
    map['route_id'] = Variable<String>(routeId);
    map['km10'] = Variable<int>(km10);
    return map;
  }

  RideLegCacheTableCompanion toCompanion(bool nullToAbsent) {
    return RideLegCacheTableCompanion(
      rideId: Value(rideId),
      seq: Value(seq),
      lineId: Value(lineId),
      routeId: Value(routeId),
      km10: Value(km10),
    );
  }

  factory RideLegCacheRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RideLegCacheRow(
      rideId: serializer.fromJson<String>(json['rideId']),
      seq: serializer.fromJson<int>(json['seq']),
      lineId: serializer.fromJson<String>(json['lineId']),
      routeId: serializer.fromJson<String>(json['routeId']),
      km10: serializer.fromJson<int>(json['km10']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'rideId': serializer.toJson<String>(rideId),
      'seq': serializer.toJson<int>(seq),
      'lineId': serializer.toJson<String>(lineId),
      'routeId': serializer.toJson<String>(routeId),
      'km10': serializer.toJson<int>(km10),
    };
  }

  RideLegCacheRow copyWith({
    String? rideId,
    int? seq,
    String? lineId,
    String? routeId,
    int? km10,
  }) => RideLegCacheRow(
    rideId: rideId ?? this.rideId,
    seq: seq ?? this.seq,
    lineId: lineId ?? this.lineId,
    routeId: routeId ?? this.routeId,
    km10: km10 ?? this.km10,
  );
  RideLegCacheRow copyWithCompanion(RideLegCacheTableCompanion data) {
    return RideLegCacheRow(
      rideId: data.rideId.present ? data.rideId.value : this.rideId,
      seq: data.seq.present ? data.seq.value : this.seq,
      lineId: data.lineId.present ? data.lineId.value : this.lineId,
      routeId: data.routeId.present ? data.routeId.value : this.routeId,
      km10: data.km10.present ? data.km10.value : this.km10,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RideLegCacheRow(')
          ..write('rideId: $rideId, ')
          ..write('seq: $seq, ')
          ..write('lineId: $lineId, ')
          ..write('routeId: $routeId, ')
          ..write('km10: $km10')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(rideId, seq, lineId, routeId, km10);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RideLegCacheRow &&
          other.rideId == this.rideId &&
          other.seq == this.seq &&
          other.lineId == this.lineId &&
          other.routeId == this.routeId &&
          other.km10 == this.km10);
}

class RideLegCacheTableCompanion extends UpdateCompanion<RideLegCacheRow> {
  final Value<String> rideId;
  final Value<int> seq;
  final Value<String> lineId;
  final Value<String> routeId;
  final Value<int> km10;
  final Value<int> rowid;
  const RideLegCacheTableCompanion({
    this.rideId = const Value.absent(),
    this.seq = const Value.absent(),
    this.lineId = const Value.absent(),
    this.routeId = const Value.absent(),
    this.km10 = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RideLegCacheTableCompanion.insert({
    required String rideId,
    required int seq,
    required String lineId,
    required String routeId,
    required int km10,
    this.rowid = const Value.absent(),
  }) : rideId = Value(rideId),
       seq = Value(seq),
       lineId = Value(lineId),
       routeId = Value(routeId),
       km10 = Value(km10);
  static Insertable<RideLegCacheRow> custom({
    Expression<String>? rideId,
    Expression<int>? seq,
    Expression<String>? lineId,
    Expression<String>? routeId,
    Expression<int>? km10,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (rideId != null) 'ride_id': rideId,
      if (seq != null) 'seq': seq,
      if (lineId != null) 'line_id': lineId,
      if (routeId != null) 'route_id': routeId,
      if (km10 != null) 'km10': km10,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RideLegCacheTableCompanion copyWith({
    Value<String>? rideId,
    Value<int>? seq,
    Value<String>? lineId,
    Value<String>? routeId,
    Value<int>? km10,
    Value<int>? rowid,
  }) {
    return RideLegCacheTableCompanion(
      rideId: rideId ?? this.rideId,
      seq: seq ?? this.seq,
      lineId: lineId ?? this.lineId,
      routeId: routeId ?? this.routeId,
      km10: km10 ?? this.km10,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (rideId.present) {
      map['ride_id'] = Variable<String>(rideId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (lineId.present) {
      map['line_id'] = Variable<String>(lineId.value);
    }
    if (routeId.present) {
      map['route_id'] = Variable<String>(routeId.value);
    }
    if (km10.present) {
      map['km10'] = Variable<int>(km10.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RideLegCacheTableCompanion(')
          ..write('rideId: $rideId, ')
          ..write('seq: $seq, ')
          ..write('lineId: $lineId, ')
          ..write('routeId: $routeId, ')
          ..write('km10: $km10, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RideEdgeTableTable extends RideEdgeTable
    with TableInfo<$RideEdgeTableTable, RideEdgeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RideEdgeTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _edgeMeta = const VerificationMeta('edge');
  @override
  late final GeneratedColumn<int> edge = GeneratedColumn<int>(
    'edge',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rideIdMeta = const VerificationMeta('rideId');
  @override
  late final GeneratedColumn<String> rideId = GeneratedColumn<String>(
    'ride_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _legSeqMeta = const VerificationMeta('legSeq');
  @override
  late final GeneratedColumn<int> legSeq = GeneratedColumn<int>(
    'leg_seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitOnMeta = const VerificationMeta('unitOn');
  @override
  late final GeneratedColumn<int> unitOn = GeneratedColumn<int>(
    'unit_on',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitOffMeta = const VerificationMeta(
    'unitOff',
  );
  @override
  late final GeneratedColumn<int> unitOff = GeneratedColumn<int>(
    'unit_off',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _effectiveHiMeta = const VerificationMeta(
    'effectiveHi',
  );
  @override
  late final GeneratedColumn<String> effectiveHi = GeneratedColumn<String>(
    'effective_hi',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    edge,
    rideId,
    legSeq,
    unitOn,
    unitOff,
    effectiveHi,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ride_edge';
  @override
  VerificationContext validateIntegrity(
    Insertable<RideEdgeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('edge')) {
      context.handle(
        _edgeMeta,
        edge.isAcceptableOrUnknown(data['edge']!, _edgeMeta),
      );
    } else if (isInserting) {
      context.missing(_edgeMeta);
    }
    if (data.containsKey('ride_id')) {
      context.handle(
        _rideIdMeta,
        rideId.isAcceptableOrUnknown(data['ride_id']!, _rideIdMeta),
      );
    } else if (isInserting) {
      context.missing(_rideIdMeta);
    }
    if (data.containsKey('leg_seq')) {
      context.handle(
        _legSeqMeta,
        legSeq.isAcceptableOrUnknown(data['leg_seq']!, _legSeqMeta),
      );
    } else if (isInserting) {
      context.missing(_legSeqMeta);
    }
    if (data.containsKey('unit_on')) {
      context.handle(
        _unitOnMeta,
        unitOn.isAcceptableOrUnknown(data['unit_on']!, _unitOnMeta),
      );
    } else if (isInserting) {
      context.missing(_unitOnMeta);
    }
    if (data.containsKey('unit_off')) {
      context.handle(
        _unitOffMeta,
        unitOff.isAcceptableOrUnknown(data['unit_off']!, _unitOffMeta),
      );
    } else if (isInserting) {
      context.missing(_unitOffMeta);
    }
    if (data.containsKey('effective_hi')) {
      context.handle(
        _effectiveHiMeta,
        effectiveHi.isAcceptableOrUnknown(
          data['effective_hi']!,
          _effectiveHiMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  RideEdgeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RideEdgeRow(
      edge: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}edge'],
      )!,
      rideId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ride_id'],
      )!,
      legSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}leg_seq'],
      )!,
      unitOn: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unit_on'],
      )!,
      unitOff: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unit_off'],
      )!,
      effectiveHi: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}effective_hi'],
      ),
    );
  }

  @override
  $RideEdgeTableTable createAlias(String alias) {
    return $RideEdgeTableTable(attachedDatabase, alias);
  }
}

class RideEdgeRow extends DataClass implements Insertable<RideEdgeRow> {
  final int edge;
  final String rideId;
  final int legSeq;
  final int unitOn;
  final int unitOff;
  final String? effectiveHi;
  const RideEdgeRow({
    required this.edge,
    required this.rideId,
    required this.legSeq,
    required this.unitOn,
    required this.unitOff,
    this.effectiveHi,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['edge'] = Variable<int>(edge);
    map['ride_id'] = Variable<String>(rideId);
    map['leg_seq'] = Variable<int>(legSeq);
    map['unit_on'] = Variable<int>(unitOn);
    map['unit_off'] = Variable<int>(unitOff);
    if (!nullToAbsent || effectiveHi != null) {
      map['effective_hi'] = Variable<String>(effectiveHi);
    }
    return map;
  }

  RideEdgeTableCompanion toCompanion(bool nullToAbsent) {
    return RideEdgeTableCompanion(
      edge: Value(edge),
      rideId: Value(rideId),
      legSeq: Value(legSeq),
      unitOn: Value(unitOn),
      unitOff: Value(unitOff),
      effectiveHi: effectiveHi == null && nullToAbsent
          ? const Value.absent()
          : Value(effectiveHi),
    );
  }

  factory RideEdgeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RideEdgeRow(
      edge: serializer.fromJson<int>(json['edge']),
      rideId: serializer.fromJson<String>(json['rideId']),
      legSeq: serializer.fromJson<int>(json['legSeq']),
      unitOn: serializer.fromJson<int>(json['unitOn']),
      unitOff: serializer.fromJson<int>(json['unitOff']),
      effectiveHi: serializer.fromJson<String?>(json['effectiveHi']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'edge': serializer.toJson<int>(edge),
      'rideId': serializer.toJson<String>(rideId),
      'legSeq': serializer.toJson<int>(legSeq),
      'unitOn': serializer.toJson<int>(unitOn),
      'unitOff': serializer.toJson<int>(unitOff),
      'effectiveHi': serializer.toJson<String?>(effectiveHi),
    };
  }

  RideEdgeRow copyWith({
    int? edge,
    String? rideId,
    int? legSeq,
    int? unitOn,
    int? unitOff,
    Value<String?> effectiveHi = const Value.absent(),
  }) => RideEdgeRow(
    edge: edge ?? this.edge,
    rideId: rideId ?? this.rideId,
    legSeq: legSeq ?? this.legSeq,
    unitOn: unitOn ?? this.unitOn,
    unitOff: unitOff ?? this.unitOff,
    effectiveHi: effectiveHi.present ? effectiveHi.value : this.effectiveHi,
  );
  RideEdgeRow copyWithCompanion(RideEdgeTableCompanion data) {
    return RideEdgeRow(
      edge: data.edge.present ? data.edge.value : this.edge,
      rideId: data.rideId.present ? data.rideId.value : this.rideId,
      legSeq: data.legSeq.present ? data.legSeq.value : this.legSeq,
      unitOn: data.unitOn.present ? data.unitOn.value : this.unitOn,
      unitOff: data.unitOff.present ? data.unitOff.value : this.unitOff,
      effectiveHi: data.effectiveHi.present
          ? data.effectiveHi.value
          : this.effectiveHi,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RideEdgeRow(')
          ..write('edge: $edge, ')
          ..write('rideId: $rideId, ')
          ..write('legSeq: $legSeq, ')
          ..write('unitOn: $unitOn, ')
          ..write('unitOff: $unitOff, ')
          ..write('effectiveHi: $effectiveHi')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(edge, rideId, legSeq, unitOn, unitOff, effectiveHi);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RideEdgeRow &&
          other.edge == this.edge &&
          other.rideId == this.rideId &&
          other.legSeq == this.legSeq &&
          other.unitOn == this.unitOn &&
          other.unitOff == this.unitOff &&
          other.effectiveHi == this.effectiveHi);
}

class RideEdgeTableCompanion extends UpdateCompanion<RideEdgeRow> {
  final Value<int> edge;
  final Value<String> rideId;
  final Value<int> legSeq;
  final Value<int> unitOn;
  final Value<int> unitOff;
  final Value<String?> effectiveHi;
  final Value<int> rowid;
  const RideEdgeTableCompanion({
    this.edge = const Value.absent(),
    this.rideId = const Value.absent(),
    this.legSeq = const Value.absent(),
    this.unitOn = const Value.absent(),
    this.unitOff = const Value.absent(),
    this.effectiveHi = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RideEdgeTableCompanion.insert({
    required int edge,
    required String rideId,
    required int legSeq,
    required int unitOn,
    required int unitOff,
    this.effectiveHi = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : edge = Value(edge),
       rideId = Value(rideId),
       legSeq = Value(legSeq),
       unitOn = Value(unitOn),
       unitOff = Value(unitOff);
  static Insertable<RideEdgeRow> custom({
    Expression<int>? edge,
    Expression<String>? rideId,
    Expression<int>? legSeq,
    Expression<int>? unitOn,
    Expression<int>? unitOff,
    Expression<String>? effectiveHi,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (edge != null) 'edge': edge,
      if (rideId != null) 'ride_id': rideId,
      if (legSeq != null) 'leg_seq': legSeq,
      if (unitOn != null) 'unit_on': unitOn,
      if (unitOff != null) 'unit_off': unitOff,
      if (effectiveHi != null) 'effective_hi': effectiveHi,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RideEdgeTableCompanion copyWith({
    Value<int>? edge,
    Value<String>? rideId,
    Value<int>? legSeq,
    Value<int>? unitOn,
    Value<int>? unitOff,
    Value<String?>? effectiveHi,
    Value<int>? rowid,
  }) {
    return RideEdgeTableCompanion(
      edge: edge ?? this.edge,
      rideId: rideId ?? this.rideId,
      legSeq: legSeq ?? this.legSeq,
      unitOn: unitOn ?? this.unitOn,
      unitOff: unitOff ?? this.unitOff,
      effectiveHi: effectiveHi ?? this.effectiveHi,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (edge.present) {
      map['edge'] = Variable<int>(edge.value);
    }
    if (rideId.present) {
      map['ride_id'] = Variable<String>(rideId.value);
    }
    if (legSeq.present) {
      map['leg_seq'] = Variable<int>(legSeq.value);
    }
    if (unitOn.present) {
      map['unit_on'] = Variable<int>(unitOn.value);
    }
    if (unitOff.present) {
      map['unit_off'] = Variable<int>(unitOff.value);
    }
    if (effectiveHi.present) {
      map['effective_hi'] = Variable<String>(effectiveHi.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RideEdgeTableCompanion(')
          ..write('edge: $edge, ')
          ..write('rideId: $rideId, ')
          ..write('legSeq: $legSeq, ')
          ..write('unitOn: $unitOn, ')
          ..write('unitOff: $unitOff, ')
          ..write('effectiveHi: $effectiveHi, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RideNodeTableTable extends RideNodeTable
    with TableInfo<$RideNodeTableTable, RideNodeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RideNodeTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _nodeMeta = const VerificationMeta('node');
  @override
  late final GeneratedColumn<String> node = GeneratedColumn<String>(
    'node',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rideIdMeta = const VerificationMeta('rideId');
  @override
  late final GeneratedColumn<String> rideId = GeneratedColumn<String>(
    'ride_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [node, rideId, role];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ride_node';
  @override
  VerificationContext validateIntegrity(
    Insertable<RideNodeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('node')) {
      context.handle(
        _nodeMeta,
        node.isAcceptableOrUnknown(data['node']!, _nodeMeta),
      );
    } else if (isInserting) {
      context.missing(_nodeMeta);
    }
    if (data.containsKey('ride_id')) {
      context.handle(
        _rideIdMeta,
        rideId.isAcceptableOrUnknown(data['ride_id']!, _rideIdMeta),
      );
    } else if (isInserting) {
      context.missing(_rideIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  RideNodeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RideNodeRow(
      node: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}node'],
      )!,
      rideId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ride_id'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
    );
  }

  @override
  $RideNodeTableTable createAlias(String alias) {
    return $RideNodeTableTable(attachedDatabase, alias);
  }
}

class RideNodeRow extends DataClass implements Insertable<RideNodeRow> {
  final String node;
  final String rideId;
  final String role;
  const RideNodeRow({
    required this.node,
    required this.rideId,
    required this.role,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['node'] = Variable<String>(node);
    map['ride_id'] = Variable<String>(rideId);
    map['role'] = Variable<String>(role);
    return map;
  }

  RideNodeTableCompanion toCompanion(bool nullToAbsent) {
    return RideNodeTableCompanion(
      node: Value(node),
      rideId: Value(rideId),
      role: Value(role),
    );
  }

  factory RideNodeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RideNodeRow(
      node: serializer.fromJson<String>(json['node']),
      rideId: serializer.fromJson<String>(json['rideId']),
      role: serializer.fromJson<String>(json['role']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'node': serializer.toJson<String>(node),
      'rideId': serializer.toJson<String>(rideId),
      'role': serializer.toJson<String>(role),
    };
  }

  RideNodeRow copyWith({String? node, String? rideId, String? role}) =>
      RideNodeRow(
        node: node ?? this.node,
        rideId: rideId ?? this.rideId,
        role: role ?? this.role,
      );
  RideNodeRow copyWithCompanion(RideNodeTableCompanion data) {
    return RideNodeRow(
      node: data.node.present ? data.node.value : this.node,
      rideId: data.rideId.present ? data.rideId.value : this.rideId,
      role: data.role.present ? data.role.value : this.role,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RideNodeRow(')
          ..write('node: $node, ')
          ..write('rideId: $rideId, ')
          ..write('role: $role')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(node, rideId, role);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RideNodeRow &&
          other.node == this.node &&
          other.rideId == this.rideId &&
          other.role == this.role);
}

class RideNodeTableCompanion extends UpdateCompanion<RideNodeRow> {
  final Value<String> node;
  final Value<String> rideId;
  final Value<String> role;
  final Value<int> rowid;
  const RideNodeTableCompanion({
    this.node = const Value.absent(),
    this.rideId = const Value.absent(),
    this.role = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RideNodeTableCompanion.insert({
    required String node,
    required String rideId,
    required String role,
    this.rowid = const Value.absent(),
  }) : node = Value(node),
       rideId = Value(rideId),
       role = Value(role);
  static Insertable<RideNodeRow> custom({
    Expression<String>? node,
    Expression<String>? rideId,
    Expression<String>? role,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (node != null) 'node': node,
      if (rideId != null) 'ride_id': rideId,
      if (role != null) 'role': role,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RideNodeTableCompanion copyWith({
    Value<String>? node,
    Value<String>? rideId,
    Value<String>? role,
    Value<int>? rowid,
  }) {
    return RideNodeTableCompanion(
      node: node ?? this.node,
      rideId: rideId ?? this.rideId,
      role: role ?? this.role,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (node.present) {
      map['node'] = Variable<String>(node.value);
    }
    if (rideId.present) {
      map['ride_id'] = Variable<String>(rideId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RideNodeTableCompanion(')
          ..write('node: $node, ')
          ..write('rideId: $rideId, ')
          ..write('role: $role, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VisitCacheTableTable extends VisitCacheTable
    with TableInfo<$VisitCacheTableTable, VisitCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VisitCacheTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _visitIdMeta = const VerificationMeta(
    'visitId',
  );
  @override
  late final GeneratedColumn<String> visitId = GeneratedColumn<String>(
    'visit_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [visitId, date, groupId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'visit_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<VisitCacheRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('visit_id')) {
      context.handle(
        _visitIdMeta,
        visitId.isAcceptableOrUnknown(data['visit_id']!, _visitIdMeta),
      );
    } else if (isInserting) {
      context.missing(_visitIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {visitId};
  @override
  VisitCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VisitCacheRow(
      visitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}visit_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      ),
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      ),
    );
  }

  @override
  $VisitCacheTableTable createAlias(String alias) {
    return $VisitCacheTableTable(attachedDatabase, alias);
  }
}

class VisitCacheRow extends DataClass implements Insertable<VisitCacheRow> {
  final String visitId;
  final String? date;
  final String? groupId;
  const VisitCacheRow({required this.visitId, this.date, this.groupId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['visit_id'] = Variable<String>(visitId);
    if (!nullToAbsent || date != null) {
      map['date'] = Variable<String>(date);
    }
    if (!nullToAbsent || groupId != null) {
      map['group_id'] = Variable<String>(groupId);
    }
    return map;
  }

  VisitCacheTableCompanion toCompanion(bool nullToAbsent) {
    return VisitCacheTableCompanion(
      visitId: Value(visitId),
      date: date == null && nullToAbsent ? const Value.absent() : Value(date),
      groupId: groupId == null && nullToAbsent
          ? const Value.absent()
          : Value(groupId),
    );
  }

  factory VisitCacheRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VisitCacheRow(
      visitId: serializer.fromJson<String>(json['visitId']),
      date: serializer.fromJson<String?>(json['date']),
      groupId: serializer.fromJson<String?>(json['groupId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'visitId': serializer.toJson<String>(visitId),
      'date': serializer.toJson<String?>(date),
      'groupId': serializer.toJson<String?>(groupId),
    };
  }

  VisitCacheRow copyWith({
    String? visitId,
    Value<String?> date = const Value.absent(),
    Value<String?> groupId = const Value.absent(),
  }) => VisitCacheRow(
    visitId: visitId ?? this.visitId,
    date: date.present ? date.value : this.date,
    groupId: groupId.present ? groupId.value : this.groupId,
  );
  VisitCacheRow copyWithCompanion(VisitCacheTableCompanion data) {
    return VisitCacheRow(
      visitId: data.visitId.present ? data.visitId.value : this.visitId,
      date: data.date.present ? data.date.value : this.date,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VisitCacheRow(')
          ..write('visitId: $visitId, ')
          ..write('date: $date, ')
          ..write('groupId: $groupId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(visitId, date, groupId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VisitCacheRow &&
          other.visitId == this.visitId &&
          other.date == this.date &&
          other.groupId == this.groupId);
}

class VisitCacheTableCompanion extends UpdateCompanion<VisitCacheRow> {
  final Value<String> visitId;
  final Value<String?> date;
  final Value<String?> groupId;
  final Value<int> rowid;
  const VisitCacheTableCompanion({
    this.visitId = const Value.absent(),
    this.date = const Value.absent(),
    this.groupId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VisitCacheTableCompanion.insert({
    required String visitId,
    this.date = const Value.absent(),
    this.groupId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : visitId = Value(visitId);
  static Insertable<VisitCacheRow> custom({
    Expression<String>? visitId,
    Expression<String>? date,
    Expression<String>? groupId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (visitId != null) 'visit_id': visitId,
      if (date != null) 'date': date,
      if (groupId != null) 'group_id': groupId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VisitCacheTableCompanion copyWith({
    Value<String>? visitId,
    Value<String?>? date,
    Value<String?>? groupId,
    Value<int>? rowid,
  }) {
    return VisitCacheTableCompanion(
      visitId: visitId ?? this.visitId,
      date: date ?? this.date,
      groupId: groupId ?? this.groupId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (visitId.present) {
      map['visit_id'] = Variable<String>(visitId.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VisitCacheTableCompanion(')
          ..write('visitId: $visitId, ')
          ..write('date: $date, ')
          ..write('groupId: $groupId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$UserDb extends GeneratedDatabase {
  _$UserDb(QueryExecutor e) : super(e);
  $UserDbManager get managers => $UserDbManager(this);
  late final $TripTableTable tripTable = $TripTableTable(this);
  late final $RideTableTable rideTable = $RideTableTable(this);
  late final $RideLegTableTable rideLegTable = $RideLegTableTable(this);
  late final $VisitTableTable visitTable = $VisitTableTable(this);
  late final $PhotoTableTable photoTable = $PhotoTableTable(this);
  late final $SettingTableTable settingTable = $SettingTableTable(this);
  late final $ChangeReportTableTable changeReportTable =
      $ChangeReportTableTable(this);
  late final $CacheStateTableTable cacheStateTable = $CacheStateTableTable(
    this,
  );
  late final $RideCacheTableTable rideCacheTable = $RideCacheTableTable(this);
  late final $RideLegCacheTableTable rideLegCacheTable =
      $RideLegCacheTableTable(this);
  late final $RideEdgeTableTable rideEdgeTable = $RideEdgeTableTable(this);
  late final $RideNodeTableTable rideNodeTable = $RideNodeTableTable(this);
  late final $VisitCacheTableTable visitCacheTable = $VisitCacheTableTable(
    this,
  );
  late final Index rideEdgeEdge = Index(
    'ride_edge_edge',
    'CREATE INDEX ride_edge_edge ON ride_edge (edge)',
  );
  late final Index rideEdgeRide = Index(
    'ride_edge_ride',
    'CREATE INDEX ride_edge_ride ON ride_edge (ride_id)',
  );
  late final Index rideEdgeOn = Index(
    'ride_edge_on',
    'CREATE INDEX ride_edge_on ON ride_edge (unit_on, effective_hi)',
  );
  late final Index rideEdgeOff = Index(
    'ride_edge_off',
    'CREATE INDEX ride_edge_off ON ride_edge (unit_off, effective_hi)',
  );
  late final Index rideNodeNode = Index(
    'ride_node_node',
    'CREATE INDEX ride_node_node ON ride_node (node)',
  );
  late final Index rideNodeRide = Index(
    'ride_node_ride',
    'CREATE INDEX ride_node_ride ON ride_node (ride_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    tripTable,
    rideTable,
    rideLegTable,
    visitTable,
    photoTable,
    settingTable,
    changeReportTable,
    cacheStateTable,
    rideCacheTable,
    rideLegCacheTable,
    rideEdgeTable,
    rideNodeTable,
    visitCacheTable,
    rideEdgeEdge,
    rideEdgeRide,
    rideEdgeOn,
    rideEdgeOff,
    rideNodeNode,
    rideNodeRide,
  ];
}

typedef $$TripTableTableCreateCompanionBuilder = TripTableCompanion Function({
  required String id,
  required int createdAt,
  required int updatedAt,
  Value<int?> deletedAt,
  required String deviceId,
  required String title,
  Value<String?> note,
  Value<int> rowid,
});
typedef $$TripTableTableUpdateCompanionBuilder = TripTableCompanion Function({
  Value<String> id,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<String> deviceId,
  Value<String> title,
  Value<String?> note,
  Value<int> rowid,
});

class $$TripTableTableFilterComposer
    extends Composer<_$UserDb, $TripTableTable> {
  $$TripTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TripTableTableOrderingComposer
    extends Composer<_$UserDb, $TripTableTable> {
  $$TripTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TripTableTableAnnotationComposer
    extends Composer<_$UserDb, $TripTableTable> {
  $$TripTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);
}

class $$TripTableTableTableManager
    extends
        RootTableManager<
          _$UserDb,
          $TripTableTable,
          TripRow,
          $$TripTableTableFilterComposer,
          $$TripTableTableOrderingComposer,
          $$TripTableTableAnnotationComposer,
          $$TripTableTableCreateCompanionBuilder,
          $$TripTableTableUpdateCompanionBuilder,
          (TripRow, BaseReferences<_$UserDb, $TripTableTable, TripRow>),
          TripRow,
          PrefetchHooks Function()
        > {
  $$TripTableTableTableManager(_$UserDb db, $TripTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TripTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TripTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TripTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TripTableCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                title: title,
                note: note,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                required String deviceId,
                required String title,
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TripTableCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                title: title,
                note: note,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TripTableTable, TripRow>(table),
                  BaseReferences<_$UserDb, $TripTableTable, TripRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TripTableTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDb,
      $TripTableTable,
      TripRow,
      $$TripTableTableFilterComposer,
      $$TripTableTableOrderingComposer,
      $$TripTableTableAnnotationComposer,
      $$TripTableTableCreateCompanionBuilder,
      $$TripTableTableUpdateCompanionBuilder,
      (TripRow, BaseReferences<_$UserDb, $TripTableTable, TripRow>),
      TripRow,
      PrefetchHooks Function()
    >;
typedef $$RideTableTableCreateCompanionBuilder = RideTableCompanion Function({
  required String id,
  required int createdAt,
  required int updatedAt,
  Value<int?> deletedAt,
  required String deviceId,
  Value<String?> tripId,
  Value<String?> dateInput,
  Value<String?> times,
  Value<String?> trainName,
  Value<String?> carNo,
  Value<String?> note,
  Value<String?> serviceId,
  Value<String> transferNodes,
  required bool fromAlighted,
  required bool toAlighted,
  required String datasetVersion,
  Value<String?> importSource,
  Value<String?> importRaw,
  Value<int> rowid,
});
typedef $$RideTableTableUpdateCompanionBuilder = RideTableCompanion Function({
  Value<String> id,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<String> deviceId,
  Value<String?> tripId,
  Value<String?> dateInput,
  Value<String?> times,
  Value<String?> trainName,
  Value<String?> carNo,
  Value<String?> note,
  Value<String?> serviceId,
  Value<String> transferNodes,
  Value<bool> fromAlighted,
  Value<bool> toAlighted,
  Value<String> datasetVersion,
  Value<String?> importSource,
  Value<String?> importRaw,
  Value<int> rowid,
});

class $$RideTableTableFilterComposer
    extends Composer<_$UserDb, $RideTableTable> {
  $$RideTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tripId => $composableBuilder(
    column: $table.tripId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dateInput => $composableBuilder(
    column: $table.dateInput,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get times => $composableBuilder(
    column: $table.times,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trainName => $composableBuilder(
    column: $table.trainName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get carNo => $composableBuilder(
    column: $table.carNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serviceId => $composableBuilder(
    column: $table.serviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transferNodes => $composableBuilder(
    column: $table.transferNodes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get fromAlighted => $composableBuilder(
    column: $table.fromAlighted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get toAlighted => $composableBuilder(
    column: $table.toAlighted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get datasetVersion => $composableBuilder(
    column: $table.datasetVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get importSource => $composableBuilder(
    column: $table.importSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get importRaw => $composableBuilder(
    column: $table.importRaw,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RideTableTableOrderingComposer
    extends Composer<_$UserDb, $RideTableTable> {
  $$RideTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tripId => $composableBuilder(
    column: $table.tripId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dateInput => $composableBuilder(
    column: $table.dateInput,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get times => $composableBuilder(
    column: $table.times,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trainName => $composableBuilder(
    column: $table.trainName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get carNo => $composableBuilder(
    column: $table.carNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serviceId => $composableBuilder(
    column: $table.serviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transferNodes => $composableBuilder(
    column: $table.transferNodes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get fromAlighted => $composableBuilder(
    column: $table.fromAlighted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get toAlighted => $composableBuilder(
    column: $table.toAlighted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get datasetVersion => $composableBuilder(
    column: $table.datasetVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get importSource => $composableBuilder(
    column: $table.importSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get importRaw => $composableBuilder(
    column: $table.importRaw,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RideTableTableAnnotationComposer
    extends Composer<_$UserDb, $RideTableTable> {
  $$RideTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get tripId =>
      $composableBuilder(column: $table.tripId, builder: (column) => column);

  GeneratedColumn<String> get dateInput =>
      $composableBuilder(column: $table.dateInput, builder: (column) => column);

  GeneratedColumn<String> get times =>
      $composableBuilder(column: $table.times, builder: (column) => column);

  GeneratedColumn<String> get trainName =>
      $composableBuilder(column: $table.trainName, builder: (column) => column);

  GeneratedColumn<String> get carNo =>
      $composableBuilder(column: $table.carNo, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get serviceId =>
      $composableBuilder(column: $table.serviceId, builder: (column) => column);

  GeneratedColumn<String> get transferNodes => $composableBuilder(
    column: $table.transferNodes,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get fromAlighted => $composableBuilder(
    column: $table.fromAlighted,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get toAlighted => $composableBuilder(
    column: $table.toAlighted,
    builder: (column) => column,
  );

  GeneratedColumn<String> get datasetVersion => $composableBuilder(
    column: $table.datasetVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get importSource => $composableBuilder(
    column: $table.importSource,
    builder: (column) => column,
  );

  GeneratedColumn<String> get importRaw =>
      $composableBuilder(column: $table.importRaw, builder: (column) => column);
}

class $$RideTableTableTableManager
    extends
        RootTableManager<
          _$UserDb,
          $RideTableTable,
          RideRow,
          $$RideTableTableFilterComposer,
          $$RideTableTableOrderingComposer,
          $$RideTableTableAnnotationComposer,
          $$RideTableTableCreateCompanionBuilder,
          $$RideTableTableUpdateCompanionBuilder,
          (RideRow, BaseReferences<_$UserDb, $RideTableTable, RideRow>),
          RideRow,
          PrefetchHooks Function()
        > {
  $$RideTableTableTableManager(_$UserDb db, $RideTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RideTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RideTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RideTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String?> tripId = const Value.absent(),
                Value<String?> dateInput = const Value.absent(),
                Value<String?> times = const Value.absent(),
                Value<String?> trainName = const Value.absent(),
                Value<String?> carNo = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> serviceId = const Value.absent(),
                Value<String> transferNodes = const Value.absent(),
                Value<bool> fromAlighted = const Value.absent(),
                Value<bool> toAlighted = const Value.absent(),
                Value<String> datasetVersion = const Value.absent(),
                Value<String?> importSource = const Value.absent(),
                Value<String?> importRaw = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RideTableCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                tripId: tripId,
                dateInput: dateInput,
                times: times,
                trainName: trainName,
                carNo: carNo,
                note: note,
                serviceId: serviceId,
                transferNodes: transferNodes,
                fromAlighted: fromAlighted,
                toAlighted: toAlighted,
                datasetVersion: datasetVersion,
                importSource: importSource,
                importRaw: importRaw,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                required String deviceId,
                Value<String?> tripId = const Value.absent(),
                Value<String?> dateInput = const Value.absent(),
                Value<String?> times = const Value.absent(),
                Value<String?> trainName = const Value.absent(),
                Value<String?> carNo = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> serviceId = const Value.absent(),
                Value<String> transferNodes = const Value.absent(),
                required bool fromAlighted,
                required bool toAlighted,
                required String datasetVersion,
                Value<String?> importSource = const Value.absent(),
                Value<String?> importRaw = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RideTableCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                tripId: tripId,
                dateInput: dateInput,
                times: times,
                trainName: trainName,
                carNo: carNo,
                note: note,
                serviceId: serviceId,
                transferNodes: transferNodes,
                fromAlighted: fromAlighted,
                toAlighted: toAlighted,
                datasetVersion: datasetVersion,
                importSource: importSource,
                importRaw: importRaw,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RideTableTable, RideRow>(table),
                  BaseReferences<_$UserDb, $RideTableTable, RideRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RideTableTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDb,
      $RideTableTable,
      RideRow,
      $$RideTableTableFilterComposer,
      $$RideTableTableOrderingComposer,
      $$RideTableTableAnnotationComposer,
      $$RideTableTableCreateCompanionBuilder,
      $$RideTableTableUpdateCompanionBuilder,
      (RideRow, BaseReferences<_$UserDb, $RideTableTable, RideRow>),
      RideRow,
      PrefetchHooks Function()
    >;
typedef $$RideLegTableTableCreateCompanionBuilder =
    RideLegTableCompanion Function({
      required String rideId,
      required int seq,
      required String lineId,
      required String routeId,
      required String fromNode,
      required String toNode,
      Value<String?> direction,
      Value<String?> resolveAsOf,
      required bool resolveUnknown,
      required String lineLabel,
      required String fromLabel,
      required String toLabel,
      Value<int> rowid,
    });
typedef $$RideLegTableTableUpdateCompanionBuilder =
    RideLegTableCompanion Function({
      Value<String> rideId,
      Value<int> seq,
      Value<String> lineId,
      Value<String> routeId,
      Value<String> fromNode,
      Value<String> toNode,
      Value<String?> direction,
      Value<String?> resolveAsOf,
      Value<bool> resolveUnknown,
      Value<String> lineLabel,
      Value<String> fromLabel,
      Value<String> toLabel,
      Value<int> rowid,
    });

class $$RideLegTableTableFilterComposer
    extends Composer<_$UserDb, $RideLegTableTable> {
  $$RideLegTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get rideId => $composableBuilder(
    column: $table.rideId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lineId => $composableBuilder(
    column: $table.lineId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get routeId => $composableBuilder(
    column: $table.routeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fromNode => $composableBuilder(
    column: $table.fromNode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toNode => $composableBuilder(
    column: $table.toNode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resolveAsOf => $composableBuilder(
    column: $table.resolveAsOf,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get resolveUnknown => $composableBuilder(
    column: $table.resolveUnknown,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lineLabel => $composableBuilder(
    column: $table.lineLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fromLabel => $composableBuilder(
    column: $table.fromLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toLabel => $composableBuilder(
    column: $table.toLabel,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RideLegTableTableOrderingComposer
    extends Composer<_$UserDb, $RideLegTableTable> {
  $$RideLegTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get rideId => $composableBuilder(
    column: $table.rideId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lineId => $composableBuilder(
    column: $table.lineId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get routeId => $composableBuilder(
    column: $table.routeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fromNode => $composableBuilder(
    column: $table.fromNode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toNode => $composableBuilder(
    column: $table.toNode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resolveAsOf => $composableBuilder(
    column: $table.resolveAsOf,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get resolveUnknown => $composableBuilder(
    column: $table.resolveUnknown,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lineLabel => $composableBuilder(
    column: $table.lineLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fromLabel => $composableBuilder(
    column: $table.fromLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toLabel => $composableBuilder(
    column: $table.toLabel,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RideLegTableTableAnnotationComposer
    extends Composer<_$UserDb, $RideLegTableTable> {
  $$RideLegTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get rideId =>
      $composableBuilder(column: $table.rideId, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get lineId =>
      $composableBuilder(column: $table.lineId, builder: (column) => column);

  GeneratedColumn<String> get routeId =>
      $composableBuilder(column: $table.routeId, builder: (column) => column);

  GeneratedColumn<String> get fromNode =>
      $composableBuilder(column: $table.fromNode, builder: (column) => column);

  GeneratedColumn<String> get toNode =>
      $composableBuilder(column: $table.toNode, builder: (column) => column);

  GeneratedColumn<String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<String> get resolveAsOf => $composableBuilder(
    column: $table.resolveAsOf,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get resolveUnknown => $composableBuilder(
    column: $table.resolveUnknown,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lineLabel =>
      $composableBuilder(column: $table.lineLabel, builder: (column) => column);

  GeneratedColumn<String> get fromLabel =>
      $composableBuilder(column: $table.fromLabel, builder: (column) => column);

  GeneratedColumn<String> get toLabel =>
      $composableBuilder(column: $table.toLabel, builder: (column) => column);
}

class $$RideLegTableTableTableManager
    extends
        RootTableManager<
          _$UserDb,
          $RideLegTableTable,
          RideLegRow,
          $$RideLegTableTableFilterComposer,
          $$RideLegTableTableOrderingComposer,
          $$RideLegTableTableAnnotationComposer,
          $$RideLegTableTableCreateCompanionBuilder,
          $$RideLegTableTableUpdateCompanionBuilder,
          (
            RideLegRow,
            BaseReferences<_$UserDb, $RideLegTableTable, RideLegRow>,
          ),
          RideLegRow,
          PrefetchHooks Function()
        > {
  $$RideLegTableTableTableManager(_$UserDb db, $RideLegTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RideLegTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RideLegTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RideLegTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> rideId = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<String> lineId = const Value.absent(),
                Value<String> routeId = const Value.absent(),
                Value<String> fromNode = const Value.absent(),
                Value<String> toNode = const Value.absent(),
                Value<String?> direction = const Value.absent(),
                Value<String?> resolveAsOf = const Value.absent(),
                Value<bool> resolveUnknown = const Value.absent(),
                Value<String> lineLabel = const Value.absent(),
                Value<String> fromLabel = const Value.absent(),
                Value<String> toLabel = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RideLegTableCompanion(
                rideId: rideId,
                seq: seq,
                lineId: lineId,
                routeId: routeId,
                fromNode: fromNode,
                toNode: toNode,
                direction: direction,
                resolveAsOf: resolveAsOf,
                resolveUnknown: resolveUnknown,
                lineLabel: lineLabel,
                fromLabel: fromLabel,
                toLabel: toLabel,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String rideId,
                required int seq,
                required String lineId,
                required String routeId,
                required String fromNode,
                required String toNode,
                Value<String?> direction = const Value.absent(),
                Value<String?> resolveAsOf = const Value.absent(),
                required bool resolveUnknown,
                required String lineLabel,
                required String fromLabel,
                required String toLabel,
                Value<int> rowid = const Value.absent(),
              }) => RideLegTableCompanion.insert(
                rideId: rideId,
                seq: seq,
                lineId: lineId,
                routeId: routeId,
                fromNode: fromNode,
                toNode: toNode,
                direction: direction,
                resolveAsOf: resolveAsOf,
                resolveUnknown: resolveUnknown,
                lineLabel: lineLabel,
                fromLabel: fromLabel,
                toLabel: toLabel,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RideLegTableTable, RideLegRow>(table),
                  BaseReferences<_$UserDb, $RideLegTableTable, RideLegRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RideLegTableTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDb,
      $RideLegTableTable,
      RideLegRow,
      $$RideLegTableTableFilterComposer,
      $$RideLegTableTableOrderingComposer,
      $$RideLegTableTableAnnotationComposer,
      $$RideLegTableTableCreateCompanionBuilder,
      $$RideLegTableTableUpdateCompanionBuilder,
      (RideLegRow, BaseReferences<_$UserDb, $RideLegTableTable, RideLegRow>),
      RideLegRow,
      PrefetchHooks Function()
    >;
typedef $$VisitTableTableCreateCompanionBuilder = VisitTableCompanion Function({
  required String id,
  required int createdAt,
  required int updatedAt,
  Value<int?> deletedAt,
  required String deviceId,
  required String nodeId,
  required String nodeLabel,
  required bool nodeExplicit,
  Value<String?> dateInput,
  Value<String?> note,
  Value<int> rowid,
});
typedef $$VisitTableTableUpdateCompanionBuilder = VisitTableCompanion Function({
  Value<String> id,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<String> deviceId,
  Value<String> nodeId,
  Value<String> nodeLabel,
  Value<bool> nodeExplicit,
  Value<String?> dateInput,
  Value<String?> note,
  Value<int> rowid,
});

class $$VisitTableTableFilterComposer
    extends Composer<_$UserDb, $VisitTableTable> {
  $$VisitTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nodeId => $composableBuilder(
    column: $table.nodeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nodeLabel => $composableBuilder(
    column: $table.nodeLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get nodeExplicit => $composableBuilder(
    column: $table.nodeExplicit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dateInput => $composableBuilder(
    column: $table.dateInput,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VisitTableTableOrderingComposer
    extends Composer<_$UserDb, $VisitTableTable> {
  $$VisitTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nodeId => $composableBuilder(
    column: $table.nodeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nodeLabel => $composableBuilder(
    column: $table.nodeLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get nodeExplicit => $composableBuilder(
    column: $table.nodeExplicit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dateInput => $composableBuilder(
    column: $table.dateInput,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VisitTableTableAnnotationComposer
    extends Composer<_$UserDb, $VisitTableTable> {
  $$VisitTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get nodeId =>
      $composableBuilder(column: $table.nodeId, builder: (column) => column);

  GeneratedColumn<String> get nodeLabel =>
      $composableBuilder(column: $table.nodeLabel, builder: (column) => column);

  GeneratedColumn<bool> get nodeExplicit => $composableBuilder(
    column: $table.nodeExplicit,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dateInput =>
      $composableBuilder(column: $table.dateInput, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);
}

class $$VisitTableTableTableManager
    extends
        RootTableManager<
          _$UserDb,
          $VisitTableTable,
          VisitRow,
          $$VisitTableTableFilterComposer,
          $$VisitTableTableOrderingComposer,
          $$VisitTableTableAnnotationComposer,
          $$VisitTableTableCreateCompanionBuilder,
          $$VisitTableTableUpdateCompanionBuilder,
          (VisitRow, BaseReferences<_$UserDb, $VisitTableTable, VisitRow>),
          VisitRow,
          PrefetchHooks Function()
        > {
  $$VisitTableTableTableManager(_$UserDb db, $VisitTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VisitTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VisitTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VisitTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> nodeId = const Value.absent(),
                Value<String> nodeLabel = const Value.absent(),
                Value<bool> nodeExplicit = const Value.absent(),
                Value<String?> dateInput = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VisitTableCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                nodeId: nodeId,
                nodeLabel: nodeLabel,
                nodeExplicit: nodeExplicit,
                dateInput: dateInput,
                note: note,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                required String deviceId,
                required String nodeId,
                required String nodeLabel,
                required bool nodeExplicit,
                Value<String?> dateInput = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VisitTableCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                nodeId: nodeId,
                nodeLabel: nodeLabel,
                nodeExplicit: nodeExplicit,
                dateInput: dateInput,
                note: note,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$VisitTableTable, VisitRow>(table),
                  BaseReferences<_$UserDb, $VisitTableTable, VisitRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VisitTableTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDb,
      $VisitTableTable,
      VisitRow,
      $$VisitTableTableFilterComposer,
      $$VisitTableTableOrderingComposer,
      $$VisitTableTableAnnotationComposer,
      $$VisitTableTableCreateCompanionBuilder,
      $$VisitTableTableUpdateCompanionBuilder,
      (VisitRow, BaseReferences<_$UserDb, $VisitTableTable, VisitRow>),
      VisitRow,
      PrefetchHooks Function()
    >;
typedef $$PhotoTableTableCreateCompanionBuilder = PhotoTableCompanion Function({
  required String id,
  required int createdAt,
  required int updatedAt,
  Value<int?> deletedAt,
  required String deviceId,
  required String ownerType,
  required String ownerId,
  required String sha256,
  Value<String?> thumbPath,
  Value<int> rowid,
});
typedef $$PhotoTableTableUpdateCompanionBuilder = PhotoTableCompanion Function({
  Value<String> id,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int?> deletedAt,
  Value<String> deviceId,
  Value<String> ownerType,
  Value<String> ownerId,
  Value<String> sha256,
  Value<String?> thumbPath,
  Value<int> rowid,
});

class $$PhotoTableTableFilterComposer
    extends Composer<_$UserDb, $PhotoTableTable> {
  $$PhotoTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerType => $composableBuilder(
    column: $table.ownerType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbPath => $composableBuilder(
    column: $table.thumbPath,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PhotoTableTableOrderingComposer
    extends Composer<_$UserDb, $PhotoTableTable> {
  $$PhotoTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerType => $composableBuilder(
    column: $table.ownerType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbPath => $composableBuilder(
    column: $table.thumbPath,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PhotoTableTableAnnotationComposer
    extends Composer<_$UserDb, $PhotoTableTable> {
  $$PhotoTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get ownerType =>
      $composableBuilder(column: $table.ownerType, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<String> get thumbPath =>
      $composableBuilder(column: $table.thumbPath, builder: (column) => column);
}

class $$PhotoTableTableTableManager
    extends
        RootTableManager<
          _$UserDb,
          $PhotoTableTable,
          PhotoRow,
          $$PhotoTableTableFilterComposer,
          $$PhotoTableTableOrderingComposer,
          $$PhotoTableTableAnnotationComposer,
          $$PhotoTableTableCreateCompanionBuilder,
          $$PhotoTableTableUpdateCompanionBuilder,
          (PhotoRow, BaseReferences<_$UserDb, $PhotoTableTable, PhotoRow>),
          PhotoRow,
          PrefetchHooks Function()
        > {
  $$PhotoTableTableTableManager(_$UserDb db, $PhotoTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PhotoTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PhotoTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PhotoTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> ownerType = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<String> sha256 = const Value.absent(),
                Value<String?> thumbPath = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PhotoTableCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                ownerType: ownerType,
                ownerId: ownerId,
                sha256: sha256,
                thumbPath: thumbPath,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                required String deviceId,
                required String ownerType,
                required String ownerId,
                required String sha256,
                Value<String?> thumbPath = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PhotoTableCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                ownerType: ownerType,
                ownerId: ownerId,
                sha256: sha256,
                thumbPath: thumbPath,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PhotoTableTable, PhotoRow>(table),
                  BaseReferences<_$UserDb, $PhotoTableTable, PhotoRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PhotoTableTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDb,
      $PhotoTableTable,
      PhotoRow,
      $$PhotoTableTableFilterComposer,
      $$PhotoTableTableOrderingComposer,
      $$PhotoTableTableAnnotationComposer,
      $$PhotoTableTableCreateCompanionBuilder,
      $$PhotoTableTableUpdateCompanionBuilder,
      (PhotoRow, BaseReferences<_$UserDb, $PhotoTableTable, PhotoRow>),
      PhotoRow,
      PrefetchHooks Function()
    >;
typedef $$SettingTableTableCreateCompanionBuilder =
    SettingTableCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SettingTableTableUpdateCompanionBuilder =
    SettingTableCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SettingTableTableFilterComposer
    extends Composer<_$UserDb, $SettingTableTable> {
  $$SettingTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingTableTableOrderingComposer
    extends Composer<_$UserDb, $SettingTableTable> {
  $$SettingTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingTableTableAnnotationComposer
    extends Composer<_$UserDb, $SettingTableTable> {
  $$SettingTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingTableTableTableManager
    extends
        RootTableManager<
          _$UserDb,
          $SettingTableTable,
          SettingRow,
          $$SettingTableTableFilterComposer,
          $$SettingTableTableOrderingComposer,
          $$SettingTableTableAnnotationComposer,
          $$SettingTableTableCreateCompanionBuilder,
          $$SettingTableTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$UserDb, $SettingTableTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$SettingTableTableTableManager(_$UserDb db, $SettingTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SettingTableCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SettingTableCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingTableTable, SettingRow>(table),
                  BaseReferences<_$UserDb, $SettingTableTable, SettingRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingTableTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDb,
      $SettingTableTable,
      SettingRow,
      $$SettingTableTableFilterComposer,
      $$SettingTableTableOrderingComposer,
      $$SettingTableTableAnnotationComposer,
      $$SettingTableTableCreateCompanionBuilder,
      $$SettingTableTableUpdateCompanionBuilder,
      (SettingRow, BaseReferences<_$UserDb, $SettingTableTable, SettingRow>),
      SettingRow,
      PrefetchHooks Function()
    >;
typedef $$ChangeReportTableTableCreateCompanionBuilder =
    ChangeReportTableCompanion Function({
      required String id,
      required int createdAt,
      required int updatedAt,
      Value<int?> deletedAt,
      required String deviceId,
      required String edition,
      required String body,
      Value<int> rowid,
    });
typedef $$ChangeReportTableTableUpdateCompanionBuilder =
    ChangeReportTableCompanion Function({
      Value<String> id,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> deletedAt,
      Value<String> deviceId,
      Value<String> edition,
      Value<String> body,
      Value<int> rowid,
    });

class $$ChangeReportTableTableFilterComposer
    extends Composer<_$UserDb, $ChangeReportTableTable> {
  $$ChangeReportTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get edition => $composableBuilder(
    column: $table.edition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChangeReportTableTableOrderingComposer
    extends Composer<_$UserDb, $ChangeReportTableTable> {
  $$ChangeReportTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get edition => $composableBuilder(
    column: $table.edition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChangeReportTableTableAnnotationComposer
    extends Composer<_$UserDb, $ChangeReportTableTable> {
  $$ChangeReportTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get edition =>
      $composableBuilder(column: $table.edition, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);
}

class $$ChangeReportTableTableTableManager
    extends
        RootTableManager<
          _$UserDb,
          $ChangeReportTableTable,
          ChangeReportRow,
          $$ChangeReportTableTableFilterComposer,
          $$ChangeReportTableTableOrderingComposer,
          $$ChangeReportTableTableAnnotationComposer,
          $$ChangeReportTableTableCreateCompanionBuilder,
          $$ChangeReportTableTableUpdateCompanionBuilder,
          (
            ChangeReportRow,
            BaseReferences<_$UserDb, $ChangeReportTableTable, ChangeReportRow>,
          ),
          ChangeReportRow,
          PrefetchHooks Function()
        > {
  $$ChangeReportTableTableTableManager(
    _$UserDb db,
    $ChangeReportTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChangeReportTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChangeReportTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChangeReportTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> edition = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChangeReportTableCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                edition: edition,
                body: body,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                required String deviceId,
                required String edition,
                required String body,
                Value<int> rowid = const Value.absent(),
              }) => ChangeReportTableCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                deviceId: deviceId,
                edition: edition,
                body: body,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChangeReportTableTable, ChangeReportRow>(table),
                  BaseReferences<
                    _$UserDb,
                    $ChangeReportTableTable,
                    ChangeReportRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChangeReportTableTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDb,
      $ChangeReportTableTable,
      ChangeReportRow,
      $$ChangeReportTableTableFilterComposer,
      $$ChangeReportTableTableOrderingComposer,
      $$ChangeReportTableTableAnnotationComposer,
      $$ChangeReportTableTableCreateCompanionBuilder,
      $$ChangeReportTableTableUpdateCompanionBuilder,
      (
        ChangeReportRow,
        BaseReferences<_$UserDb, $ChangeReportTableTable, ChangeReportRow>,
      ),
      ChangeReportRow,
      PrefetchHooks Function()
    >;
typedef $$CacheStateTableTableCreateCompanionBuilder =
    CacheStateTableCompanion Function({
      Value<int> id,
      required String edition,
      required int appBuild,
    });
typedef $$CacheStateTableTableUpdateCompanionBuilder =
    CacheStateTableCompanion Function({
      Value<int> id,
      Value<String> edition,
      Value<int> appBuild,
    });

class $$CacheStateTableTableFilterComposer
    extends Composer<_$UserDb, $CacheStateTableTable> {
  $$CacheStateTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get edition => $composableBuilder(
    column: $table.edition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get appBuild => $composableBuilder(
    column: $table.appBuild,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CacheStateTableTableOrderingComposer
    extends Composer<_$UserDb, $CacheStateTableTable> {
  $$CacheStateTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get edition => $composableBuilder(
    column: $table.edition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get appBuild => $composableBuilder(
    column: $table.appBuild,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CacheStateTableTableAnnotationComposer
    extends Composer<_$UserDb, $CacheStateTableTable> {
  $$CacheStateTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get edition =>
      $composableBuilder(column: $table.edition, builder: (column) => column);

  GeneratedColumn<int> get appBuild =>
      $composableBuilder(column: $table.appBuild, builder: (column) => column);
}

class $$CacheStateTableTableTableManager
    extends
        RootTableManager<
          _$UserDb,
          $CacheStateTableTable,
          CacheStateRow,
          $$CacheStateTableTableFilterComposer,
          $$CacheStateTableTableOrderingComposer,
          $$CacheStateTableTableAnnotationComposer,
          $$CacheStateTableTableCreateCompanionBuilder,
          $$CacheStateTableTableUpdateCompanionBuilder,
          (
            CacheStateRow,
            BaseReferences<_$UserDb, $CacheStateTableTable, CacheStateRow>,
          ),
          CacheStateRow,
          PrefetchHooks Function()
        > {
  $$CacheStateTableTableTableManager(_$UserDb db, $CacheStateTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CacheStateTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CacheStateTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CacheStateTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> edition = const Value.absent(),
                Value<int> appBuild = const Value.absent(),
              }) => CacheStateTableCompanion(
                id: id,
                edition: edition,
                appBuild: appBuild,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String edition,
                required int appBuild,
              }) => CacheStateTableCompanion.insert(
                id: id,
                edition: edition,
                appBuild: appBuild,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CacheStateTableTable, CacheStateRow>(table),
                  BaseReferences<
                    _$UserDb,
                    $CacheStateTableTable,
                    CacheStateRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CacheStateTableTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDb,
      $CacheStateTableTable,
      CacheStateRow,
      $$CacheStateTableTableFilterComposer,
      $$CacheStateTableTableOrderingComposer,
      $$CacheStateTableTableAnnotationComposer,
      $$CacheStateTableTableCreateCompanionBuilder,
      $$CacheStateTableTableUpdateCompanionBuilder,
      (
        CacheStateRow,
        BaseReferences<_$UserDb, $CacheStateTableTable, CacheStateRow>,
      ),
      CacheStateRow,
      PrefetchHooks Function()
    >;
typedef $$RideCacheTableTableCreateCompanionBuilder =
    RideCacheTableCompanion Function({
      required String rideId,
      required String resolveStatus,
      Value<String?> date,
      Value<int?> km10,
      Value<String?> effectiveLo,
      Value<String?> effectiveHi,
      Value<int> rowid,
    });
typedef $$RideCacheTableTableUpdateCompanionBuilder =
    RideCacheTableCompanion Function({
      Value<String> rideId,
      Value<String> resolveStatus,
      Value<String?> date,
      Value<int?> km10,
      Value<String?> effectiveLo,
      Value<String?> effectiveHi,
      Value<int> rowid,
    });

class $$RideCacheTableTableFilterComposer
    extends Composer<_$UserDb, $RideCacheTableTable> {
  $$RideCacheTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get rideId => $composableBuilder(
    column: $table.rideId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resolveStatus => $composableBuilder(
    column: $table.resolveStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get km10 => $composableBuilder(
    column: $table.km10,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get effectiveLo => $composableBuilder(
    column: $table.effectiveLo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get effectiveHi => $composableBuilder(
    column: $table.effectiveHi,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RideCacheTableTableOrderingComposer
    extends Composer<_$UserDb, $RideCacheTableTable> {
  $$RideCacheTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get rideId => $composableBuilder(
    column: $table.rideId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resolveStatus => $composableBuilder(
    column: $table.resolveStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get km10 => $composableBuilder(
    column: $table.km10,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get effectiveLo => $composableBuilder(
    column: $table.effectiveLo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get effectiveHi => $composableBuilder(
    column: $table.effectiveHi,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RideCacheTableTableAnnotationComposer
    extends Composer<_$UserDb, $RideCacheTableTable> {
  $$RideCacheTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get rideId =>
      $composableBuilder(column: $table.rideId, builder: (column) => column);

  GeneratedColumn<String> get resolveStatus => $composableBuilder(
    column: $table.resolveStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get km10 =>
      $composableBuilder(column: $table.km10, builder: (column) => column);

  GeneratedColumn<String> get effectiveLo => $composableBuilder(
    column: $table.effectiveLo,
    builder: (column) => column,
  );

  GeneratedColumn<String> get effectiveHi => $composableBuilder(
    column: $table.effectiveHi,
    builder: (column) => column,
  );
}

class $$RideCacheTableTableTableManager
    extends
        RootTableManager<
          _$UserDb,
          $RideCacheTableTable,
          RideCacheRow,
          $$RideCacheTableTableFilterComposer,
          $$RideCacheTableTableOrderingComposer,
          $$RideCacheTableTableAnnotationComposer,
          $$RideCacheTableTableCreateCompanionBuilder,
          $$RideCacheTableTableUpdateCompanionBuilder,
          (
            RideCacheRow,
            BaseReferences<_$UserDb, $RideCacheTableTable, RideCacheRow>,
          ),
          RideCacheRow,
          PrefetchHooks Function()
        > {
  $$RideCacheTableTableTableManager(_$UserDb db, $RideCacheTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RideCacheTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RideCacheTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RideCacheTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> rideId = const Value.absent(),
                Value<String> resolveStatus = const Value.absent(),
                Value<String?> date = const Value.absent(),
                Value<int?> km10 = const Value.absent(),
                Value<String?> effectiveLo = const Value.absent(),
                Value<String?> effectiveHi = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RideCacheTableCompanion(
                rideId: rideId,
                resolveStatus: resolveStatus,
                date: date,
                km10: km10,
                effectiveLo: effectiveLo,
                effectiveHi: effectiveHi,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String rideId,
                required String resolveStatus,
                Value<String?> date = const Value.absent(),
                Value<int?> km10 = const Value.absent(),
                Value<String?> effectiveLo = const Value.absent(),
                Value<String?> effectiveHi = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RideCacheTableCompanion.insert(
                rideId: rideId,
                resolveStatus: resolveStatus,
                date: date,
                km10: km10,
                effectiveLo: effectiveLo,
                effectiveHi: effectiveHi,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RideCacheTableTable, RideCacheRow>(table),
                  BaseReferences<_$UserDb, $RideCacheTableTable, RideCacheRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RideCacheTableTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDb,
      $RideCacheTableTable,
      RideCacheRow,
      $$RideCacheTableTableFilterComposer,
      $$RideCacheTableTableOrderingComposer,
      $$RideCacheTableTableAnnotationComposer,
      $$RideCacheTableTableCreateCompanionBuilder,
      $$RideCacheTableTableUpdateCompanionBuilder,
      (
        RideCacheRow,
        BaseReferences<_$UserDb, $RideCacheTableTable, RideCacheRow>,
      ),
      RideCacheRow,
      PrefetchHooks Function()
    >;
typedef $$RideLegCacheTableTableCreateCompanionBuilder =
    RideLegCacheTableCompanion Function({
      required String rideId,
      required int seq,
      required String lineId,
      required String routeId,
      required int km10,
      Value<int> rowid,
    });
typedef $$RideLegCacheTableTableUpdateCompanionBuilder =
    RideLegCacheTableCompanion Function({
      Value<String> rideId,
      Value<int> seq,
      Value<String> lineId,
      Value<String> routeId,
      Value<int> km10,
      Value<int> rowid,
    });

class $$RideLegCacheTableTableFilterComposer
    extends Composer<_$UserDb, $RideLegCacheTableTable> {
  $$RideLegCacheTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get rideId => $composableBuilder(
    column: $table.rideId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lineId => $composableBuilder(
    column: $table.lineId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get routeId => $composableBuilder(
    column: $table.routeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get km10 => $composableBuilder(
    column: $table.km10,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RideLegCacheTableTableOrderingComposer
    extends Composer<_$UserDb, $RideLegCacheTableTable> {
  $$RideLegCacheTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get rideId => $composableBuilder(
    column: $table.rideId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lineId => $composableBuilder(
    column: $table.lineId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get routeId => $composableBuilder(
    column: $table.routeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get km10 => $composableBuilder(
    column: $table.km10,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RideLegCacheTableTableAnnotationComposer
    extends Composer<_$UserDb, $RideLegCacheTableTable> {
  $$RideLegCacheTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get rideId =>
      $composableBuilder(column: $table.rideId, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get lineId =>
      $composableBuilder(column: $table.lineId, builder: (column) => column);

  GeneratedColumn<String> get routeId =>
      $composableBuilder(column: $table.routeId, builder: (column) => column);

  GeneratedColumn<int> get km10 =>
      $composableBuilder(column: $table.km10, builder: (column) => column);
}

class $$RideLegCacheTableTableTableManager
    extends
        RootTableManager<
          _$UserDb,
          $RideLegCacheTableTable,
          RideLegCacheRow,
          $$RideLegCacheTableTableFilterComposer,
          $$RideLegCacheTableTableOrderingComposer,
          $$RideLegCacheTableTableAnnotationComposer,
          $$RideLegCacheTableTableCreateCompanionBuilder,
          $$RideLegCacheTableTableUpdateCompanionBuilder,
          (
            RideLegCacheRow,
            BaseReferences<_$UserDb, $RideLegCacheTableTable, RideLegCacheRow>,
          ),
          RideLegCacheRow,
          PrefetchHooks Function()
        > {
  $$RideLegCacheTableTableTableManager(
    _$UserDb db,
    $RideLegCacheTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RideLegCacheTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RideLegCacheTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RideLegCacheTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> rideId = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<String> lineId = const Value.absent(),
                Value<String> routeId = const Value.absent(),
                Value<int> km10 = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RideLegCacheTableCompanion(
                rideId: rideId,
                seq: seq,
                lineId: lineId,
                routeId: routeId,
                km10: km10,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String rideId,
                required int seq,
                required String lineId,
                required String routeId,
                required int km10,
                Value<int> rowid = const Value.absent(),
              }) => RideLegCacheTableCompanion.insert(
                rideId: rideId,
                seq: seq,
                lineId: lineId,
                routeId: routeId,
                km10: km10,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RideLegCacheTableTable, RideLegCacheRow>(table),
                  BaseReferences<
                    _$UserDb,
                    $RideLegCacheTableTable,
                    RideLegCacheRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RideLegCacheTableTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDb,
      $RideLegCacheTableTable,
      RideLegCacheRow,
      $$RideLegCacheTableTableFilterComposer,
      $$RideLegCacheTableTableOrderingComposer,
      $$RideLegCacheTableTableAnnotationComposer,
      $$RideLegCacheTableTableCreateCompanionBuilder,
      $$RideLegCacheTableTableUpdateCompanionBuilder,
      (
        RideLegCacheRow,
        BaseReferences<_$UserDb, $RideLegCacheTableTable, RideLegCacheRow>,
      ),
      RideLegCacheRow,
      PrefetchHooks Function()
    >;
typedef $$RideEdgeTableTableCreateCompanionBuilder =
    RideEdgeTableCompanion Function({
      required int edge,
      required String rideId,
      required int legSeq,
      required int unitOn,
      required int unitOff,
      Value<String?> effectiveHi,
      Value<int> rowid,
    });
typedef $$RideEdgeTableTableUpdateCompanionBuilder =
    RideEdgeTableCompanion Function({
      Value<int> edge,
      Value<String> rideId,
      Value<int> legSeq,
      Value<int> unitOn,
      Value<int> unitOff,
      Value<String?> effectiveHi,
      Value<int> rowid,
    });

class $$RideEdgeTableTableFilterComposer
    extends Composer<_$UserDb, $RideEdgeTableTable> {
  $$RideEdgeTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get edge => $composableBuilder(
    column: $table.edge,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rideId => $composableBuilder(
    column: $table.rideId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get legSeq => $composableBuilder(
    column: $table.legSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unitOn => $composableBuilder(
    column: $table.unitOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unitOff => $composableBuilder(
    column: $table.unitOff,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get effectiveHi => $composableBuilder(
    column: $table.effectiveHi,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RideEdgeTableTableOrderingComposer
    extends Composer<_$UserDb, $RideEdgeTableTable> {
  $$RideEdgeTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get edge => $composableBuilder(
    column: $table.edge,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rideId => $composableBuilder(
    column: $table.rideId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get legSeq => $composableBuilder(
    column: $table.legSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unitOn => $composableBuilder(
    column: $table.unitOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unitOff => $composableBuilder(
    column: $table.unitOff,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get effectiveHi => $composableBuilder(
    column: $table.effectiveHi,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RideEdgeTableTableAnnotationComposer
    extends Composer<_$UserDb, $RideEdgeTableTable> {
  $$RideEdgeTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get edge =>
      $composableBuilder(column: $table.edge, builder: (column) => column);

  GeneratedColumn<String> get rideId =>
      $composableBuilder(column: $table.rideId, builder: (column) => column);

  GeneratedColumn<int> get legSeq =>
      $composableBuilder(column: $table.legSeq, builder: (column) => column);

  GeneratedColumn<int> get unitOn =>
      $composableBuilder(column: $table.unitOn, builder: (column) => column);

  GeneratedColumn<int> get unitOff =>
      $composableBuilder(column: $table.unitOff, builder: (column) => column);

  GeneratedColumn<String> get effectiveHi => $composableBuilder(
    column: $table.effectiveHi,
    builder: (column) => column,
  );
}

class $$RideEdgeTableTableTableManager
    extends
        RootTableManager<
          _$UserDb,
          $RideEdgeTableTable,
          RideEdgeRow,
          $$RideEdgeTableTableFilterComposer,
          $$RideEdgeTableTableOrderingComposer,
          $$RideEdgeTableTableAnnotationComposer,
          $$RideEdgeTableTableCreateCompanionBuilder,
          $$RideEdgeTableTableUpdateCompanionBuilder,
          (
            RideEdgeRow,
            BaseReferences<_$UserDb, $RideEdgeTableTable, RideEdgeRow>,
          ),
          RideEdgeRow,
          PrefetchHooks Function()
        > {
  $$RideEdgeTableTableTableManager(_$UserDb db, $RideEdgeTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RideEdgeTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RideEdgeTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RideEdgeTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> edge = const Value.absent(),
                Value<String> rideId = const Value.absent(),
                Value<int> legSeq = const Value.absent(),
                Value<int> unitOn = const Value.absent(),
                Value<int> unitOff = const Value.absent(),
                Value<String?> effectiveHi = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RideEdgeTableCompanion(
                edge: edge,
                rideId: rideId,
                legSeq: legSeq,
                unitOn: unitOn,
                unitOff: unitOff,
                effectiveHi: effectiveHi,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int edge,
                required String rideId,
                required int legSeq,
                required int unitOn,
                required int unitOff,
                Value<String?> effectiveHi = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RideEdgeTableCompanion.insert(
                edge: edge,
                rideId: rideId,
                legSeq: legSeq,
                unitOn: unitOn,
                unitOff: unitOff,
                effectiveHi: effectiveHi,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RideEdgeTableTable, RideEdgeRow>(table),
                  BaseReferences<_$UserDb, $RideEdgeTableTable, RideEdgeRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RideEdgeTableTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDb,
      $RideEdgeTableTable,
      RideEdgeRow,
      $$RideEdgeTableTableFilterComposer,
      $$RideEdgeTableTableOrderingComposer,
      $$RideEdgeTableTableAnnotationComposer,
      $$RideEdgeTableTableCreateCompanionBuilder,
      $$RideEdgeTableTableUpdateCompanionBuilder,
      (RideEdgeRow, BaseReferences<_$UserDb, $RideEdgeTableTable, RideEdgeRow>),
      RideEdgeRow,
      PrefetchHooks Function()
    >;
typedef $$RideNodeTableTableCreateCompanionBuilder =
    RideNodeTableCompanion Function({
      required String node,
      required String rideId,
      required String role,
      Value<int> rowid,
    });
typedef $$RideNodeTableTableUpdateCompanionBuilder =
    RideNodeTableCompanion Function({
      Value<String> node,
      Value<String> rideId,
      Value<String> role,
      Value<int> rowid,
    });

class $$RideNodeTableTableFilterComposer
    extends Composer<_$UserDb, $RideNodeTableTable> {
  $$RideNodeTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get node => $composableBuilder(
    column: $table.node,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rideId => $composableBuilder(
    column: $table.rideId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RideNodeTableTableOrderingComposer
    extends Composer<_$UserDb, $RideNodeTableTable> {
  $$RideNodeTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get node => $composableBuilder(
    column: $table.node,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rideId => $composableBuilder(
    column: $table.rideId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RideNodeTableTableAnnotationComposer
    extends Composer<_$UserDb, $RideNodeTableTable> {
  $$RideNodeTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get node =>
      $composableBuilder(column: $table.node, builder: (column) => column);

  GeneratedColumn<String> get rideId =>
      $composableBuilder(column: $table.rideId, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);
}

class $$RideNodeTableTableTableManager
    extends
        RootTableManager<
          _$UserDb,
          $RideNodeTableTable,
          RideNodeRow,
          $$RideNodeTableTableFilterComposer,
          $$RideNodeTableTableOrderingComposer,
          $$RideNodeTableTableAnnotationComposer,
          $$RideNodeTableTableCreateCompanionBuilder,
          $$RideNodeTableTableUpdateCompanionBuilder,
          (
            RideNodeRow,
            BaseReferences<_$UserDb, $RideNodeTableTable, RideNodeRow>,
          ),
          RideNodeRow,
          PrefetchHooks Function()
        > {
  $$RideNodeTableTableTableManager(_$UserDb db, $RideNodeTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RideNodeTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RideNodeTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RideNodeTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> node = const Value.absent(),
                Value<String> rideId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RideNodeTableCompanion(
                node: node,
                rideId: rideId,
                role: role,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String node,
                required String rideId,
                required String role,
                Value<int> rowid = const Value.absent(),
              }) => RideNodeTableCompanion.insert(
                node: node,
                rideId: rideId,
                role: role,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RideNodeTableTable, RideNodeRow>(table),
                  BaseReferences<_$UserDb, $RideNodeTableTable, RideNodeRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RideNodeTableTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDb,
      $RideNodeTableTable,
      RideNodeRow,
      $$RideNodeTableTableFilterComposer,
      $$RideNodeTableTableOrderingComposer,
      $$RideNodeTableTableAnnotationComposer,
      $$RideNodeTableTableCreateCompanionBuilder,
      $$RideNodeTableTableUpdateCompanionBuilder,
      (RideNodeRow, BaseReferences<_$UserDb, $RideNodeTableTable, RideNodeRow>),
      RideNodeRow,
      PrefetchHooks Function()
    >;
typedef $$VisitCacheTableTableCreateCompanionBuilder =
    VisitCacheTableCompanion Function({
      required String visitId,
      Value<String?> date,
      Value<String?> groupId,
      Value<int> rowid,
    });
typedef $$VisitCacheTableTableUpdateCompanionBuilder =
    VisitCacheTableCompanion Function({
      Value<String> visitId,
      Value<String?> date,
      Value<String?> groupId,
      Value<int> rowid,
    });

class $$VisitCacheTableTableFilterComposer
    extends Composer<_$UserDb, $VisitCacheTableTable> {
  $$VisitCacheTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get visitId => $composableBuilder(
    column: $table.visitId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VisitCacheTableTableOrderingComposer
    extends Composer<_$UserDb, $VisitCacheTableTable> {
  $$VisitCacheTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get visitId => $composableBuilder(
    column: $table.visitId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VisitCacheTableTableAnnotationComposer
    extends Composer<_$UserDb, $VisitCacheTableTable> {
  $$VisitCacheTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get visitId =>
      $composableBuilder(column: $table.visitId, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);
}

class $$VisitCacheTableTableTableManager
    extends
        RootTableManager<
          _$UserDb,
          $VisitCacheTableTable,
          VisitCacheRow,
          $$VisitCacheTableTableFilterComposer,
          $$VisitCacheTableTableOrderingComposer,
          $$VisitCacheTableTableAnnotationComposer,
          $$VisitCacheTableTableCreateCompanionBuilder,
          $$VisitCacheTableTableUpdateCompanionBuilder,
          (
            VisitCacheRow,
            BaseReferences<_$UserDb, $VisitCacheTableTable, VisitCacheRow>,
          ),
          VisitCacheRow,
          PrefetchHooks Function()
        > {
  $$VisitCacheTableTableTableManager(_$UserDb db, $VisitCacheTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VisitCacheTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VisitCacheTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VisitCacheTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> visitId = const Value.absent(),
                Value<String?> date = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VisitCacheTableCompanion(
                visitId: visitId,
                date: date,
                groupId: groupId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String visitId,
                Value<String?> date = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VisitCacheTableCompanion.insert(
                visitId: visitId,
                date: date,
                groupId: groupId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$VisitCacheTableTable, VisitCacheRow>(table),
                  BaseReferences<
                    _$UserDb,
                    $VisitCacheTableTable,
                    VisitCacheRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VisitCacheTableTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDb,
      $VisitCacheTableTable,
      VisitCacheRow,
      $$VisitCacheTableTableFilterComposer,
      $$VisitCacheTableTableOrderingComposer,
      $$VisitCacheTableTableAnnotationComposer,
      $$VisitCacheTableTableCreateCompanionBuilder,
      $$VisitCacheTableTableUpdateCompanionBuilder,
      (
        VisitCacheRow,
        BaseReferences<_$UserDb, $VisitCacheTableTable, VisitCacheRow>,
      ),
      VisitCacheRow,
      PrefetchHooks Function()
    >;

class $UserDbManager {
  final _$UserDb _db;
  $UserDbManager(this._db);
  $$TripTableTableTableManager get tripTable =>
      $$TripTableTableTableManager(_db, _db.tripTable);
  $$RideTableTableTableManager get rideTable =>
      $$RideTableTableTableManager(_db, _db.rideTable);
  $$RideLegTableTableTableManager get rideLegTable =>
      $$RideLegTableTableTableManager(_db, _db.rideLegTable);
  $$VisitTableTableTableManager get visitTable =>
      $$VisitTableTableTableManager(_db, _db.visitTable);
  $$PhotoTableTableTableManager get photoTable =>
      $$PhotoTableTableTableManager(_db, _db.photoTable);
  $$SettingTableTableTableManager get settingTable =>
      $$SettingTableTableTableManager(_db, _db.settingTable);
  $$ChangeReportTableTableTableManager get changeReportTable =>
      $$ChangeReportTableTableTableManager(_db, _db.changeReportTable);
  $$CacheStateTableTableTableManager get cacheStateTable =>
      $$CacheStateTableTableTableManager(_db, _db.cacheStateTable);
  $$RideCacheTableTableTableManager get rideCacheTable =>
      $$RideCacheTableTableTableManager(_db, _db.rideCacheTable);
  $$RideLegCacheTableTableTableManager get rideLegCacheTable =>
      $$RideLegCacheTableTableTableManager(_db, _db.rideLegCacheTable);
  $$RideEdgeTableTableTableManager get rideEdgeTable =>
      $$RideEdgeTableTableTableManager(_db, _db.rideEdgeTable);
  $$RideNodeTableTableTableManager get rideNodeTable =>
      $$RideNodeTableTableTableManager(_db, _db.rideNodeTable);
  $$VisitCacheTableTableTableManager get visitCacheTable =>
      $$VisitCacheTableTableTableManager(_db, _db.visitCacheTable);
}
