import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:noriori_core/noriori_core.dart';
import 'package:noriori_store/noriori_store.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as s3;

/// 작은 합성 팩. 실제 판의 복사는 한 시험에서만 한다.
Map<String, Uint8List> packFiles(Directory scratch) {
  final dir = scratch.createTempSync('pack');
  Uint8List sqlite(String name, void Function(s3.Database) fill) {
    final path = p.join(dir.path, name);
    final db = s3.sqlite3.open(path);
    fill(db);
    db.close();
    return File(path).readAsBytesSync();
  }

  return {
    'master.sqlite': sqlite('master.sqlite', (db) {
      db.execute('CREATE TABLE node(id TEXT)');
      db.execute("INSERT INTO node VALUES ('n_a'), ('n_b')");
      db.execute('CREATE VIEW node_public AS SELECT * FROM node');
      db.execute('CREATE TABLE line(id TEXT)');
      db.execute("INSERT INTO line VALUES ('l_a')");
    }),
    'names.sqlite': sqlite('names.sqlite', (db) => db.execute('CREATE TABLE name(text TEXT)')),
    'rail.pmtiles': Uint8List.fromList([...utf8.encode('PMTiles'), 3, 0, 0, 0]),
  };
}

String manifestOf(Map<String, Uint8List> files, {required String edition, int schema = 1}) =>
    jsonEncode({
      'edition': edition,
      'schema_version': schema,
      'files': {
        for (final MapEntry(:key, :value) in files.entries)
          key: {'sha256': sha256.convert(value).toString(), 'size': value.length},
      },
    });

final class MemoryAssets implements PackAssets {
  MemoryAssets(this.files, {required this.edition, this.schema = 1});

  final Map<String, Uint8List> files;
  String edition;
  final int schema;

  /// 이 파일을 읽을 때 죽는다. 복사 도중의 강제 종료를 흉내 낸다.
  String? failOn;

  /// 복사할 때 나는 파일 오류. 공간 부족을 흉내 낸다.
  FileSystemException? failure;

  @override
  Future<Uint8List> fileBytes(String name) async {
    if (name == failOn) throw StateError('복사 중 종료');
    final error = failure;
    if (error != null) throw error;
    return files[name]!;
  }

  @override
  Future<String> manifestText() async => manifestOf(files, edition: edition, schema: schema);


  @override
  Future<String?> signatureText() async => null;
}

/// 폴더에 이미 받아 둔 판을 만든다.
void installPack(
  Directory datasets,
  Map<String, Uint8List> files, {
  required String edition,
  int schema = 1,
}) {
  final dir = Directory(p.join(datasets.path, edition))..createSync(recursive: true);
  for (final MapEntry(:key, :value) in files.entries) {
    File(p.join(dir.path, key)).writeAsBytesSync(value);
  }
  File(p.join(dir.path, 'manifest.json'))
      .writeAsStringSync(manifestOf(files, edition: edition, schema: schema));
}

/// 규칙이 아직 없는 자리. km10은 구간 수이고 메모가 `깨짐`이면 계산에 실패한다.
final class StubInterpreter implements RecordInterpreter {
  int rides = 0;

  /// 이 메모의 기록은 캐시 쓰기에서 실패한다. 공간 부족 같은 저장 실패를 흉내 낸다.
  static const unwritable = '쓰기 실패';

  @override
  RideDerived ride(Ride ride) {
    rides++;
    if (ride.note == '깨짐') throw StateError('깨짐');
    if (ride.note == unwritable) return duplicatedLegs(ride);
    return RideDerived(
      status: ResolveStatus.ok,
      km10: ride.legs.length,
      edges: [
        for (final leg in ride.legs)
          EdgeHit(edge: leg.seq, legSeq: leg.seq, unitOn: leg.seq, unitOff: leg.seq),
      ],
      legs: [
        for (final leg in ride.legs)
          LegDerived(seq: leg.seq, lineId: leg.lineId, routeId: leg.routeId, km10: 1),
      ],
    );
  }

  @override
  VisitDerived visit(Visit visit) {
    if (visit.note == '깨짐') throw StateError('깨짐');
    return VisitDerived(date: visit.dateInput, groupId: 'g_${visit.nodeId}');
  }
}

/// 기본 키가 겹쳐 쓰기에서 실패하는 결과.
RideDerived duplicatedLegs(Ride ride) => const RideDerived(
      status: ResolveStatus.ok,
      legs: [
        LegDerived(seq: 0, lineId: LineId('l'), routeId: RouteId('r'), km10: 1),
        LegDerived(seq: 0, lineId: LineId('l'), routeId: RouteId('r'), km10: 1),
      ],
    );

Ride sampleRide(String id, {String? note, int legs = 1, int? deletedAt}) => Ride(
      rideId: RideId(id),
      datasetVersion: '2026-11-02',
      createdAt: 1,
      updatedAt: 0,
      deviceId: 'd',
      note: note,
      deletedAt: deletedAt,
      trainName: 'はやぶさ3号',
      transferNodes: const [NodeId('n_b')],
      legs: [
        for (var seq = 0; seq < legs; seq++)
          RideLeg(
            seq: seq,
            lineId: const LineId('l_a'),
            routeId: const RouteId('r_a'),
            fromNode: const NodeId('n_a'),
            toNode: const NodeId('n_b'),
            lineLabel: '線',
            fromLabel: 'A',
            toLabel: 'B',
          ),
      ],
    );

Visit sampleVisit(String id, {String? note}) => Visit(
      visitId: VisitId(id),
      nodeId: const NodeId('n_a'),
      nodeLabel: 'A',
      nodeExplicit: true,
      createdAt: 1,
      updatedAt: 0,
      deviceId: 'd',
      note: note,
    );
