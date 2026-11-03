import 'dart:convert';

import '../date/date_rules.dart';
import '../ids.dart';
import '../records/record.dart';
import 'backup_envelope.dart';

/// 백업에 들어가는 원본. 캐시는 다시 만들 수 있으므로 넣지 않는다.
final class BackupContents {
  const BackupContents({
    required this.trips,
    required this.rides,
    required this.visits,
    this.settings = const {},
    this.changeNotes = const [],
  });

  final List<Trip> trips;
  final List<Ride> rides;
  final List<Visit> visits;
  final List<ChangeNote> changeNotes;

  /// 표시와 테마 설정. 기기에 묶인 값은 빠져 있다.
  final Map<String, String> settings;

  Iterable<UserRecord> get all sync* {
    yield* trips;
    yield* rides;
    yield* visits;
    yield* changeNotes;
  }

  /// 행별 `updated_at`. 회전 판단은 이 값만 있으면 된다.
  Map<String, int> get stamps => {for (final row in all) row.id: row.updatedAt};

  int get rowCount => trips.length + rides.length + visits.length + changeNotes.length;

  /// 같은 원본인가. 행 순서는 보지 않는다. 바뀐 것이 없으면 자동 백업을 쓰지 않는 근거다.
  bool sameAs(BackupContents other) => _canonical == other._canonical;

  String get _canonical {
    List<Map<String, Object?>> sorted(Iterable<Map<String, Object?>> rows) =>
        rows.toList()..sort((a, b) => (a['id']! as String).compareTo(b['id']! as String));
    return jsonEncode([
      sorted(trips.map(_tripToJson)),
      sorted(rides.map(_rideToJson)),
      sorted(visits.map(_visitToJson)),
      sorted(changeNotes.map(_noteToJson)),
      [for (final key in settings.keys.toList()..sort()) [key, settings[key]]],
    ]);
  }
}

/// 옛 백업의 표를 한 버전 올린다. `from`에서 `from + 1`로 간다.
typedef BackupStep = Map<String, Object?> Function(Map<String, Object?> tables);

/// 스키마를 올릴 때 마이그레이션과 함께 추가한다. 나간 파일은 고칠 수 없다.
const Map<int, BackupStep> backupSteps = {};

/// 백업 파일 하나. 형식은 첫 공개 뒤에 고칠 수 없으므로 열 이름을 DB 열과 같게 둔다.
final class BackupFile {
  const BackupFile({required this.header, required this.contents});

  final BackupHeader header;
  final BackupContents contents;

  String encode() => jsonEncode({
        ...header.toJson(),
        'tables': {
          'trip': contents.trips.map(_tripToJson).toList(),
          'ride': contents.rides.map(_rideToJson).toList(),
          'visit': contents.visits.map(_visitToJson).toList(),
          'setting': [
            for (final MapEntry(:key, :value) in contents.settings.entries) {'key': key, 'value': value},
          ],
          // 사진은 뺐다. 이미 나간 형식과 맞추려고 빈 표를 둔다
          'photo': const <Object>[],
          'change_report': contents.changeNotes.map(_noteToJson).toList(),
        },
      });

  /// 머리말만 읽는다. 앱보다 새 파일은 내용을 해석하지 않는다.
  static BackupHeader decodeHeader(String text) =>
      BackupHeader.fromJson(_object(text));

  /// noriori 백업이 아니거나 잘린 파일이면 [FormatException].
  ///
  /// [upgradeTo]를 주면 옛 파일을 그 버전까지 올린다. 앱의 마이그레이션 순서와 같다.
  factory BackupFile.decode(
    String text, {
    int? upgradeTo,
    Map<int, BackupStep> steps = backupSteps,
  }) {
    final json = _object(text);
    final header = BackupHeader.fromJson(json);
    if (header.format > BackupHeader.currentFormat) {
      throw FormatException('앱보다 새 형식이다: ${header.format}');
    }
    var tables = json['tables'];
    if (tables is! Map<String, Object?>) {
      throw const FormatException('백업에 표가 없다');
    }
    for (var version = header.userVersion; version < (upgradeTo ?? 0); version++) {
      final step = steps[version];
      if (step == null) throw FormatException('$version에서 올리는 단계가 없다');
      tables = step(tables as Map<String, Object?>);
    }
    try {
      return BackupFile(
        header: header,
        contents: BackupContents(
          trips: _rows(tables as Map<String, Object?>, 'trip', _tripFromJson),
          rides: _rows(tables, 'ride', _rideFromJson),
          visits: _rows(tables, 'visit', _visitFromJson),
          changeNotes: tables.containsKey('change_report') ? _rows(tables, 'change_report', _noteFromJson) : const [],
          settings: {
            // 설정을 넣기 전의 파일에는 이 표가 없다
            if (tables.containsKey('setting'))
              for (final row in _rows(tables, 'setting', (json) => json))
                row['key']! as String: row['value']! as String,
          },
        ),
      );
    } on TypeError catch (e) {
      throw FormatException('백업의 행을 읽을 수 없다: $e');
    }
  }

  static Map<String, Object?> _object(String text) {
    final Object? value = jsonDecode(text);
    if (value is! Map<String, Object?>) {
      throw const FormatException('백업이 객체가 아니다');
    }
    return value;
  }

  static List<T> _rows<T>(
    Map<String, Object?> tables,
    String name,
    T Function(Map<String, Object?>) read,
  ) =>
      [
        for (final row in tables[name]! as List<Object?>)
          read(row! as Map<String, Object?>),
      ];
}

/// 백업 폴더에 다른 앱의 파일이 섞일 수 있다. 그런 파일은 읽지 못한 백업이 아니라 없는 파일이다.
///
/// 우리 이름이면 깨졌어도 우리 파일이다. 이름을 바꾼 사본은 머리말로 알아본다.
bool isOurBackup(String name, String? text) {
  if (name.startsWith(BackupHeader.namePrefix)) return true;
  if (text == null) return false;
  try {
    final Object? value = jsonDecode(text);
    return value is Map<String, Object?> && value['kind'] == BackupHeader.formatName;
  } on FormatException {
    return false;
  }
}

Map<String, Object?> _meta(UserRecord row) => {
      'id': row.id,
      'created_at': row.createdAt,
      'updated_at': row.updatedAt,
      'deleted_at': row.deletedAt,
      'device_id': row.deviceId,
    };

Map<String, Object?> _noteToJson(ChangeNote note) => {
      ..._meta(note),
      'edition': note.edition,
      'body': note.body,
    };

ChangeNote _noteFromJson(Map<String, Object?> json) => ChangeNote(
      noteId: json['id']! as String,
      edition: json['edition']! as String,
      body: json['body']! as String,
      createdAt: json['created_at']! as int,
      updatedAt: json['updated_at']! as int,
      deletedAt: json['deleted_at'] as int?,
      deviceId: json['device_id']! as String,
    );

Map<String, Object?> _tripToJson(Trip trip) => {
      ..._meta(trip),
      'title': trip.title,
      'note': trip.note,
    };

Trip _tripFromJson(Map<String, Object?> json) => Trip(
      tripId: TripId(json['id']! as String),
      title: json['title']! as String,
      note: json['note'] as String?,
      createdAt: json['created_at']! as int,
      updatedAt: json['updated_at']! as int,
      deletedAt: json['deleted_at'] as int?,
      deviceId: json['device_id']! as String,
    );

Map<String, Object?> _legToJson(RideLeg leg) => {
      'seq': leg.seq,
      'line_id': leg.lineId,
      'route_id': leg.routeId,
      'from_node': leg.fromNode,
      'to_node': leg.toNode,
      'direction': leg.direction,
      'resolve_as_of': leg.resolveAsOf,
      'resolve_unknown': leg.resolveUnknown,
      'line_label': leg.lineLabel,
      'from_label': leg.fromLabel,
      'to_label': leg.toLabel,
    };

RideLeg _legFromJson(Map<String, Object?> json) => RideLeg(
      seq: json['seq']! as int,
      lineId: LineId(json['line_id']! as String),
      routeId: RouteId(json['route_id']! as String),
      fromNode: NodeId(json['from_node']! as String),
      toNode: NodeId(json['to_node']! as String),
      direction: json['direction'] as String?,
      resolveAsOf: json['resolve_as_of'] as String?,
      resolveUnknown: json['resolve_unknown']! as bool,
      lineLabel: json['line_label']! as String,
      fromLabel: json['from_label']! as String,
      toLabel: json['to_label']! as String,
    );

Map<String, Object?> _rideToJson(Ride ride) => {
      ..._meta(ride),
      'trip_id': ride.tripId,
      'date_input': ride.dateInput,
      'times': ride.times,
      'train_name': ride.trainName,
      'car_no': ride.carNo,
      'note': ride.note,
      'service_id': ride.serviceId,
      'transfer_nodes': ride.transferNodes,
      'from_alighted': ride.fromAlighted,
      'to_alighted': ride.toAlighted,
      'dataset_version': ride.datasetVersion,
      'import_source': ride.importSource,
      'import_raw': ride.importRaw,
      'legs': ride.legs.map(_legToJson).toList(),
    };

Ride _rideFromJson(Map<String, Object?> json) => Ride(
      rideId: RideId(json['id']! as String),
      createdAt: json['created_at']! as int,
      updatedAt: json['updated_at']! as int,
      deletedAt: json['deleted_at'] as int?,
      deviceId: json['device_id']! as String,
      tripId: _map(json['trip_id'], TripId.new),
      dateInput: fileDate(json['date_input'] as String?),
      times: json['times'] as String?,
      trainName: json['train_name'] as String?,
      carNo: json['car_no'] as String?,
      note: json['note'] as String?,
      serviceId: _map(json['service_id'], ServiceId.new),
      transferNodes: [
        for (final node in json['transfer_nodes']! as List<Object?>)
          NodeId(node! as String),
      ],
      fromAlighted: json['from_alighted']! as bool,
      toAlighted: json['to_alighted']! as bool,
      datasetVersion: json['dataset_version']! as String,
      importSource: json['import_source'] as String?,
      importRaw: json['import_raw'] as String?,
      legs: _legs(json),
    );

/// 구간 없는 기록은 앱이 만들지 않는다. 파일이 잘못된 것이다.
List<RideLeg> _legs(Map<String, Object?> json) {
  final legs = [
    for (final leg in json['legs']! as List<Object?>) _legFromJson(leg! as Map<String, Object?>),
  ];
  if (legs.isEmpty) throw FormatException('구간이 없는 기록이다: ${json['id']}');
  return legs;
}

Map<String, Object?> _visitToJson(Visit visit) => {
      ..._meta(visit),
      'node_id': visit.nodeId,
      'node_label': visit.nodeLabel,
      'node_explicit': visit.nodeExplicit,
      'date_input': visit.dateInput,
      'note': visit.note,
    };

Visit _visitFromJson(Map<String, Object?> json) => Visit(
      visitId: VisitId(json['id']! as String),
      nodeId: NodeId(json['node_id']! as String),
      nodeLabel: json['node_label']! as String,
      nodeExplicit: json['node_explicit']! as bool,
      createdAt: json['created_at']! as int,
      updatedAt: json['updated_at']! as int,
      deletedAt: json['deleted_at'] as int?,
      deviceId: json['device_id']! as String,
      dateInput: fileDate(json['date_input'] as String?),
      note: json['note'] as String?,
    );

T? _map<T>(Object? value, T Function(String) wrap) =>
    value == null ? null : wrap(value as String);
