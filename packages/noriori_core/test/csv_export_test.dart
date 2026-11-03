import 'dart:convert';

import 'package:noriori_core/noriori_core.dart';
import 'package:test/test.dart';

const ongoing = NetPeriod(
  fromLo: '1900-01-01',
  fromHi: '1900-01-01',
  toLo: DateSpan.maxDate,
  toHi: DateSpan.maxDate,
);

NetStop stop(int seq, String node) => NetStop(
      routeId: 'r',
      seq: seq,
      node: node,
      kmCum: null,
      isStop: true,
      isExtension: false,
      period: ongoing,
    );

NetAttr attr(String edge, String operator) => NetAttr(
      edgeId: edge,
      lineId: 'l',
      operatorId: operator,
      lineageId: 'lg',
      carryoverGroup: 'c',
      period: ongoing,
    );

/// a-b는 가 회사, b-c는 나 회사가 맡는다.
Network network() => Network(
      NetworkData(
        routes: const [
          NetRoute(
            id: 'r',
            lineId: 'l',
            role: 'main',
            fromNode: 'a',
            toNode: 'c',
            closed: false,
            extendTo: [],
          ),
        ],
        edges: const [
          NetEdge(id: 'ab', n: 1, from: 'a', to: 'b', meters: 1200),
          NetEdge(id: 'bc', n: 2, from: 'b', to: 'c', meters: 2500),
        ],
        routeEdges: const [
          NetRouteEdge(routeId: 'r', seq: 0, edgeId: 'ab'),
          NetRouteEdge(routeId: 'r', seq: 1, edgeId: 'bc'),
        ],
        stops: [stop(0, 'a'), stop(1, 'b'), stop(2, 'c')],
        attrs: [attr('ab', 'east'), attr('bc', 'west')],
        lives: const [
          NetLife(edgeId: 'ab', suspended: false, period: ongoing),
          NetLife(edgeId: 'bc', suspended: false, period: ongoing),
        ],
        units: const [],
        publicNodes: const {'a', 'b', 'c'},
        nodeGroups: const {},
      ),
    );

const names = ExportNames(
  operators: {'east': '東社', 'west': '西社'},
  lines: {'l': '試験線'},
  routes: {},
  nodes: {'a': '甲', 'b': '乙', 'c': '丙'},
);

Ride ride({String? date, String? note, String id = 'r1'}) => Ride(
      rideId: RideId(id),
      datasetVersion: 'e',
      createdAt: 5,
      updatedAt: 6,
      deviceId: 'd',
      dateInput: date,
      note: note,
      fromAlighted: false,
      transferNodes: const [NodeId('b')],
      legs: const [
        RideLeg(
          seq: 0,
          lineId: LineId('l'),
          routeId: RouteId('r'),
          fromNode: NodeId('a'),
          toNode: NodeId('c'),
          lineLabel: '시험선',
          fromLabel: '갑',
          toLabel: '병',
        ),
      ],
    );

void main() {
  final exporter = CsvExporter(network(), names);

  group('호환판', () {
    test('노리츠부시 모양이고 사업자마다 한 행이다', () {
      final file = parseNoritsubushiCsv(exporter.compat([ride(date: '2020-03-04')]));
      expect(file.broken, isEmpty);
      expect(file.rides.map((row) => row.company), ['東社', '西社']);
      expect(file.rides.first.from, '甲');
      expect(file.rides.first.to, '乙');
      expect(file.rides.first.meters, 1200);
      expect(file.rides.last.dateInput, '2020-03-04');
    });

    test('연도만 아는 날짜는 코멘트 끝에 남긴다', () {
      final rows = exporter.rows(ride(date: '2015-XX-XX', note: '메모'));
      expect(rows.first.date, '0000-00-00');
      expect(rows.first.comment, '메모 2015');
    });

    test('지운 기록은 넣지 않는다', () {
      final file = parseNoritsubushiCsv(exporter.compat([ride().withDeletedAt(9) as Ride]));
      expect(file.rides, isEmpty);
    });

    test('쉼표와 따옴표는 RFC 4180으로 적는다', () {
      final file = parseNoritsubushiCsv(exporter.compat([ride(note: 'a,"b"')]));
      expect(file.rides.first.comment, 'a,"b"');
    });

    test('CP932로 쓰고 한글이 있으면 알린 뒤 UTF-8로 쓴다', () {
      final plain = compatBytes('甲,ｱ,a\n');
      expect(plain.fellBack, isFalse);
      expect(decodeCsvBytes(plain.bytes), '甲,ｱ,a\n');
      final korean = compatBytes('한글\n');
      expect(korean.fellBack, isTrue);
      expect(decodeCsvBytes(korean.bytes), '한글\n');
    });
  });

  group('전체판', () {
    const visit = Visit(
      visitId: VisitId('v1'),
      nodeId: NodeId('b'),
      nodeLabel: '을',
      nodeExplicit: true,
      createdAt: 7,
      updatedAt: 7,
      deviceId: 'd',
      dateInput: '2020-XX-XX',
    );

    test('경로와 날짜가 돌아온다', () {
      final contents = BackupContents(
        trips: const [],
        rides: [ride(date: '2015-XX-XX', note: 'a,b')],
        visits: const [visit],
      );
      final text = exporter.full(contents);
      expect(isFullCsv(text), isTrue);
      final back = parseFullCsv(text, deviceId: 'me');
      final got = back.rides.single;
      expect(got.rideId.value, 'r1');
      expect(got.dateInput, '2015-XX-XX');
      expect(got.note, 'a,b');
      expect(got.fromAlighted, isFalse);
      expect(got.toAlighted, isTrue);
      expect(got.transferNodes.single.value, 'b');
      expect(got.legs.single.routeId.value, 'r');
      expect(got.legs.single.toNode.value, 'c');
      expect(got.createdAt, 5);
      expect(back.visits.single.nodeId.value, 'b');
      expect(back.visits.single.dateInput, '2020-XX-XX');
    });

    test('BOM 붙은 UTF-8이다', () {
      final bytes = fullBytes('a\n').bytes;
      expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
      expect(utf8.decode(bytes.skip(3).toList()), 'a\n');
    });

    test('노리츠부시 파일은 전체판이 아니다', () {
      expect(isFullCsv('会社名,路線名,乗車開始駅,乗車終了駅,乗車キロ,乗車日\n'), isFalse);
    });
  });
}
