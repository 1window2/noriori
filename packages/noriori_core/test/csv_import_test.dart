import 'dart:convert';

import 'package:noriori_core/noriori_core.dart';
import 'package:noriori_core/src/importing/cp932.dart';
import 'package:test/test.dart';

const ongoing = NetPeriod(
  fromLo: '1900-01-01',
  fromHi: '1900-01-01',
  toLo: DateSpan.maxDate,
  toHi: DateSpan.maxDate,
);
const before2000 = NetPeriod(
  fromLo: '1900-01-01',
  fromHi: '1900-01-01',
  toLo: '2000-01-01',
  toHi: '2000-01-01',
);
const after2000 = NetPeriod(
  fromLo: '2000-01-01',
  fromHi: '2000-01-01',
  toLo: DateSpan.maxDate,
  toHi: DateSpan.maxDate,
);

NetRoute route(String id, String line, String role, String from, String to, {bool closed = false}) =>
    NetRoute(
      id: id,
      lineId: line,
      role: role,
      fromNode: from,
      toNode: to,
      closed: closed,
      extendTo: const [],
    );

NetStop stop(String routeId, int seq, String node) => NetStop(
      routeId: routeId,
      seq: seq,
      node: node,
      kmCum: null,
      isStop: true,
      isExtension: false,
      period: ongoing,
    );

NetAttr attr(String edge, String line, {NetPeriod period = ongoing}) => NetAttr(
      edgeId: edge,
      lineId: line,
      operatorId: 'o',
      lineageId: 'lg-$line',
      carryoverGroup: 'c-$line',
      period: period,
    );

NetLife life(String edge, {NetPeriod period = ongoing}) =>
    NetLife(edgeId: edge, suspended: false, period: period);

/// 본선 a-b-c, 지선 b-d, 이설 구간 p-q, 고리 x-y-z.
Network sample() => Network(
      NetworkData(
        routes: [
          route('main', 'l', 'main', 'a', 'c'),
          route('branch', 'l', 'branch', 'b', 'd'),
          route('moved', 'm', 'main', 'p', 'q'),
          route('loop', 'o', 'main', 'x', 'x', closed: true),
        ],
        edges: const [
          NetEdge(id: 'ab', n: 1, from: 'a', to: 'b', meters: 1000),
          NetEdge(id: 'bc', n: 2, from: 'b', to: 'c', meters: 2000),
          NetEdge(id: 'bd', n: 3, from: 'b', to: 'd', meters: 3000),
          NetEdge(id: 'old', n: 4, from: 'p', to: 'q', meters: 1000),
          NetEdge(id: 'new', n: 5, from: 'p', to: 'q', meters: 1200),
          NetEdge(id: 'xy', n: 6, from: 'x', to: 'y', meters: 100),
          NetEdge(id: 'yz', n: 7, from: 'y', to: 'z', meters: 200),
          NetEdge(id: 'zx', n: 8, from: 'z', to: 'x', meters: 400),
        ],
        routeEdges: const [
          NetRouteEdge(routeId: 'main', seq: 0, edgeId: 'ab'),
          NetRouteEdge(routeId: 'main', seq: 1, edgeId: 'bc'),
          NetRouteEdge(routeId: 'branch', seq: 0, edgeId: 'bd'),
          NetRouteEdge(routeId: 'moved', seq: 0, edgeId: 'old'),
          NetRouteEdge(routeId: 'moved', seq: 1, edgeId: 'new'),
          NetRouteEdge(routeId: 'loop', seq: 0, edgeId: 'xy'),
          NetRouteEdge(routeId: 'loop', seq: 1, edgeId: 'yz'),
          NetRouteEdge(routeId: 'loop', seq: 2, edgeId: 'zx'),
        ],
        stops: [
          stop('main', 0, 'a'),
          stop('main', 1, 'b'),
          stop('main', 2, 'c'),
          stop('branch', 0, 'b'),
          stop('branch', 1, 'd'),
          stop('moved', 0, 'p'),
          stop('moved', 1, 'q'),
          stop('loop', 0, 'x'),
          stop('loop', 1, 'y'),
          stop('loop', 2, 'z'),
          stop('loop', 3, 'x'),
        ],
        attrs: [
          attr('ab', 'l'),
          attr('bc', 'l'),
          attr('bd', 'l'),
          attr('old', 'm', period: before2000),
          attr('new', 'm', period: after2000),
          attr('xy', 'o'),
          attr('yz', 'o'),
          attr('zx', 'o'),
        ],
        lives: [
          life('ab'),
          life('bc'),
          life('bd'),
          life('old', period: before2000),
          life('new', period: after2000),
          life('xy'),
          life('yz'),
          life('zx'),
        ],
        units: const [],
        publicNodes: const {'a', 'b', 'c', 'd', 'p', 'q', 'x', 'y', 'z'},
        nodeGroups: const {},
      ),
    );

const names = ImportNames(
  routes: {'本線(支線)': {'branch'}},
  lines: {'本線': {'l'}, '移設線': {'m'}, '環状線': {'o'}, '愛称線': {'l'}},
  nodes: {
    'えー': {'a'},
    'びー': {'b'},
    'しー': {'c'},
    'でぃー': {'d'},
    'ぴー': {'p'},
    'きゅー': {'q'},
    'えっくす': {'x'},
    'わい': {'y'},
    'ぜっと': {'z'},
    'よそ': {'elsewhere'},
    'けや': {'c'},
  },
);

String csv(List<String> rows, {bool comment = false}) => [
      '会社名,路線名,乗車開始駅,乗車終了駅,乗車キロ,乗車日${comment ? ',コメント' : ''}',
      ...rows,
      '',
    ].join('\n');

String idOf(String key) => key;

CsvRide one(String row) => parseNoritsubushiCsv(csv([row])).rides.single;

void main() {
  final matcher = CsvMatcher(sample(), names);

  group('글자', () {
    test('CP932 확장 글자와 반각 가나를 읽는다', () {
      expect(decodeCp932([0xED, 0x95, 0xEE, 0xE0, 0x87, 0x40, 0x81, 0x60]), '﨑髙①～');
      expect(decodeCp932([0x41, 0xB6, 0xC0]), 'Aｶﾀ');
      expect(decodeCp932([0x90, 0xE7, 0x91, 0xCA, 0x83, 0x50, 0x92, 0x4A]), '千駄ケ谷');
    });

    test('잘린 바이트는 대체 글자다', () {
      expect(decodeCp932([0x41, 0x90]), 'A�');
      expect(decodeCp932([0xFF, 0x41]), '�A');
    });

    test('UTF-8은 그대로, 나머지는 CP932다', () {
      expect(decodeCsvBytes(utf8.encode('﻿駅')), '駅');
      expect(decodeCsvBytes([0x8B, 0x9E]), '京');
    });
  });

  group('파일', () {
    test('일반판과 코멘트판을 읽는다', () {
      final plain = one('会社,本線,えー,びー,1.0,0000-00-00');
      expect(plain.dateInput, isNull);
      expect(plain.meters, 1000);
      expect(plain.comment, isNull);
      expect(plain.raw, '会社,本線,えー,びー,1.0,0000-00-00');
      final file = parseNoritsubushiCsv(csv(['会社,本線,えー,びー,1.0,2015-03-14,메모'], comment: true));
      expect(file.rides.single.dateInput, '2015-03-14');
      expect(file.rides.single.comment, '메모');
    });

    test('코멘트의 쉼표와 줄바꿈과 따옴표를 지킨다', () {
      final file = parseNoritsubushiCsv(
        csv(['会社,本線,えー,びー,1.0,0000-00-00,"가,나\n다 ""라"""'], comment: true),
      );
      expect(file.rides.single.comment, '가,나\n다 "라"');
    });

    test('CRLF와 마지막 줄바꿈 없는 파일도 같다', () {
      const text = '会社名,路線名,乗車開始駅,乗車終了駅,乗車キロ,乗車日\r\n'
          '会社,本線,えー,びー,1.0,0000-00-00\r\n'
          '会社,本線,びー,しー,2.0,0000-00-00';
      final rides = parseNoritsubushiCsv(text).rides;
      expect(rides.map((r) => r.raw), [
        '会社,本線,えー,びー,1.0,0000-00-00',
        '会社,本線,びー,しー,2.0,0000-00-00',
      ]);
    });

    test('모양이 깨진 행은 따로 둔다', () {
      final file = parseNoritsubushiCsv(csv([
        '会社,本線,えー',
        '会社,本線,えー,びー,1.0,어제',
        '会社,本線,,びー,1.0,0000-00-00',
        '会社,本線,えー,びー,1.0,0000-00-00',
      ]));
      expect(file.rides, hasLength(1));
      expect(file.broken, hasLength(3));
    });

    test('다른 파일은 거부한다', () {
      expect(() => parseNoritsubushiCsv(''), throwsFormatException);
      expect(() => parseNoritsubushiCsv('a,b,c\n1,2,3\n'), throwsFormatException);
    });
  });

  group('맞추기', () {
    RowMatched matched(String row) => matcher.match(one(row)) as RowMatched;

    test('괄호까지 맞는 계통이 먼저다', () {
      final got = matched('会社,本線 (支線),びー,でぃー,3.0,0000-00-00');
      expect(got.routeId, 'branch');
      expect(got.lineId, 'l');
      expect(got.meters, 3000);
    });

    test('애칭 괄호는 노선 이름으로 내려간다', () {
      expect(matched('会社,愛称線 (3号線),えー,しー,3.0,0000-00-00').routeId, 'main');
    });

    test('ケ와 ヶ, 띄어쓰기는 같은 이름이다', () {
      expect(importKey('千駄ケ谷'), importKey('千駄ヶ谷'));
      expect(importKey('本線 （支線）'), importKey('本線(支線)'));
      expect(matched('会社,本線,えー,ケや,3.0,0000-00-00').toNode, 'c');
    });

    test('못 맞춘 까닭을 나눈다', () {
      RowMissed missed(String row) => matcher.match(one(row)) as RowMissed;
      expect(missed('会社,없는선,えー,びー,1.0,0000-00-00').reason, MissReason.line);
      expect(missed('会社,本線,えー,없는역,1.0,0000-00-00').reason, MissReason.station);
      expect(missed('会社,本線,えー,よそ,1.0,0000-00-00').reason, MissReason.path);
    });

    test('순환 방향은 파일의 거리로 고른다', () {
      expect(matched('会社,環状線,えっくす,ぜっと,0.3,0000-00-00').direction, seqUp);
      expect(matched('会社,環状線,えっくす,ぜっと,0.4,0000-00-00').direction, seqDown);
      expect(matched('会社,環状線,えっくす,ぜっと,0.4,0000-00-00').meters, 400);
    });

    test('같은 역으로 돌아오면 한 바퀴다', () {
      expect(matched('会社,環状線,えっくす,えっくす,0.7,0000-00-00').meters, 700);
    });

    test('이설 구간은 파일의 거리로 고른다', () {
      final old = matched('会社,移設線,ぴー,きゅー,1.0,0000-00-00');
      expect(old.meters, 1000);
      expect(old.asOf, isNotNull);
      expect(matched('会社,移設線,ぴー,きゅー,1.2,0000-00-00').meters, 1200);
    });

    test('날짜가 있으면 그날 선로로 맞춘다', () {
      final got = matched('会社,移設線,ぴー,きゅー,1.0,2010-05-01');
      expect(got.meters, 1200);
      expect(got.asOf, isNull);
    });
  });

  group('계획', () {
    CsvFile file(List<String> rows) => parseNoritsubushiCsv(csv(rows));

    test('ID는 내용으로 정해지고 일반판과 코멘트판이 같다', () {
      final plain = one('会社,本線,えー,びー,1.0,0000-00-00');
      final comment = parseNoritsubushiCsv(
        csv(['会社,本線,えー,びー,1.0,0000-00-00,메모'], comment: true),
      ).rides.single;
      expect(csvRideKey(plain, 1), csvRideKey(comment, 1));
      expect(csvRideKey(plain, 1), isNot(csvRideKey(plain, 2)));
    });

    test('같은 행이 두 번 있으면 두 기록이다', () {
      final plan = planImport(
        file(['会社,本線,えー,びー,1.0,0000-00-00', '会社,本線,えー,びー,1.0,0000-00-00']),
        matcher,
        const {},
        idOf: idOf,
      );
      expect(plan.rows.map((r) => r.rideId).toSet(), hasLength(2));
    });

    test('있던 기록과 지운 기록을 가른다', () {
      final rows = file(['会社,本線,えー,びー,1.0,0000-00-00', '会社,本線,びー,しー,2.0,0000-00-00',
          '会社,本線,えー,しー,3.0,0000-00-00']);
      final first = planImport(rows, matcher, const {}, idOf: idOf);
      expect(first.ofState(ImportState.fresh), hasLength(3));
      expect(first.freshMeters, 6000);
      final second = planImport(rows, matcher, {
        first.rows[0].rideId.value: false,
        first.rows[1].rideId.value: true,
      }, idOf: idOf);
      expect(second.rows.map((r) => r.state),
          [ImportState.existing, ImportState.deleted, ImportState.fresh]);
      expect(second.freshMeters, 3000);
    });

    test('그날 탈 수 없는 행과 기준일 이전 행은 날짜 모름으로 넣고 건수를 센다', () {
      // 2000년에 폐지된 노선 하나
      final closed = Network(
        NetworkData(
          routes: [route('gone', 'g', 'main', 'e', 'f')],
          edges: const [NetEdge(id: 'ef', n: 1, from: 'e', to: 'f', meters: 1000)],
          routeEdges: const [NetRouteEdge(routeId: 'gone', seq: 0, edgeId: 'ef')],
          stops: [stop('gone', 0, 'e'), stop('gone', 1, 'f')],
          attrs: [attr('ef', 'g', period: before2000)],
          lives: [life('ef', period: before2000)],
          units: const [],
          publicNodes: const {'e', 'f'},
          nodeGroups: const {},
        ),
      );
      const gone = ImportNames(
        routes: {},
        lines: {'廃線': {'g'}},
        nodes: {'いー': {'e'}, 'えふ': {'f'}},
      );
      final plan = planImport(
        file([
          '会社,廃線,いー,えふ,1.0,1990-05-01',
          '会社,廃線,いー,えふ,1.0,2010-05-01',
          '会社,廃線,いー,えふ,1.0,1949-05-01',
          '会社,廃線,いー,えふ,1.0,0000-00-00',
          '会社,없는선,いー,えふ,1.0,2010-05-01',
        ]),
        CsvMatcher(closed, gone),
        const {},
        idOf: idOf,
      );
      expect(plan.rows.map((r) => r.undated), [false, true, true, false, false]);
      expect(plan.undated.map((r) => r.row.dateInput), ['2010-05-01', '1949-05-01']);
      // 파일의 날짜는 date_input에 그대로 남고 계산된 날짜만 날짜 모름이다
      final ride = importedRide(
        plan.rows[1],
        edition: 'e',
        now: 0,
        deviceId: 'd',
        lineLabel: '',
        fromLabel: '',
        toLabel: '',
      );
      expect(ride.dateInput, '2010-05-01');
      expect(ride.importRaw, '会社,廃線,いー,えふ,1.0,2010-05-01');
      expect(RideInterpreter(closed).ride(ride).date, isNull);
      // 이미 있는 행은 세지 않는다
      final again = planImport(
        file(['会社,廃線,いー,えふ,1.0,2010-05-01']),
        CsvMatcher(closed, gone),
        {plan.rows[1].rideId.value: false},
        idOf: idOf,
      );
      expect(again.undated, isEmpty);
    });

    test('거리가 다른 행을 찾는다', () {
      final plan = planImport(
        file(['会社,本線,えー,びー,1.0,0000-00-00', '会社,本線,びー,しー,2.2,0000-00-00']),
        matcher,
        const {},
        idOf: idOf,
      );
      expect(plan.kmDiffers.single.row.to, 'しー');
    });
  });

  group('기록', () {
    Ride ride(ImportRow row) => importedRide(
          row,
          edition: 'e',
          now: 5,
          deviceId: 'd',
          lineLabel: '선',
          fromLabel: '출발',
          toLabel: '도착',
        );

    test('끝은 통과이고 원문을 남긴다', () {
      final plan = planImport(
        parseNoritsubushiCsv(csv(['会社,本線,えー,びー,1.0,2015-03-14,메모'], comment: true)),
        matcher,
        const {},
        idOf: idOf,
      );
      final got = ride(plan.rows.single);
      expect(got.fromAlighted, isFalse);
      expect(got.toAlighted, isFalse);
      expect(got.importSource, importSourceNoritsubushi);
      expect(got.importRaw, '会社,本線,えー,びー,1.0,2015-03-14,메모');
      expect(got.note, '메모');
      expect(got.dateInput, '2015-03-14');
      expect(got.legs.single.routeId, const RouteId('main'));
      expect(RideInterpreter(sample()).ride(got).status, ResolveStatus.ok);
    });

    test('못 맞춘 행은 기록으로 남고 완주율에 들지 않는다', () {
      final plan = planImport(
        parseNoritsubushiCsv(csv(['会社,없는선,えー,びー,1.0,0000-00-00'])),
        matcher,
        const {},
        idOf: idOf,
      );
      expect(plan.missed, hasLength(1));
      expect(RideInterpreter(sample()).ride(ride(plan.rows.single)).status, ResolveStatus.unknownRef);
    });
  });

  group('따옴표', () {
    const head = '会社名,路線名,乗車開始駅,乗車終了駅,乗車キロ,乗車日,コメント\n';

    test('칸 가운데 따옴표는 글자다', () {
      final file = parseNoritsubushiCsv('$head会社,線,A,B,1.0,2015-03-14,5"ゲージ\n会社,線,B,C,1.0,2015-03-14,\n');
      expect(file.rides.length, 2);
      expect(file.rides.first.comment, '5"ゲージ');
    });

    test('닫히지 않은 따옴표는 깨진 행이다', () {
      final file = parseNoritsubushiCsv('$head会社,線,A,B,1.0,2015-03-14,"ゲージ\n会社,線,B,C,1.0,2015-03-14,\n');
      expect(file.rides, isEmpty);
      expect(file.broken.length, 1);
    });

    test('무한대 거리는 거리를 모르는 것으로 읽는다', () {
      final file = parseNoritsubushiCsv('$head会社,線,A,B,Infinity,2015-03-14,\n');
      expect(file.rides.single.meters, isNull);
    });
  });
}
