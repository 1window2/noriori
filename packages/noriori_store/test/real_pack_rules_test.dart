import 'dart:io';

import 'package:noriori_core/noriori_core.dart';
import 'package:noriori_store/noriori_store.dart';
import 'package:test/test.dart';

/// 합성 망으로는 나오지 않는 규칙을 실제 판으로 본다. 판이 없으면 건너뛴다.
void main() {
  final master = File('../../build/master.sqlite');
  final skip = master.existsSync() ? null : '판이 없다';
  const today = '2026-11-03';

  late Network network;
  late RideInterpreter interpreter;

  setUpAll(() async {
    if (skip != null) return;
    final db = UserDb(openDirect(File(':memory:')));
    await db.customStatement("ATTACH 'file:${master.absolute.path}?mode=ro&immutable=1' AS master");
    network = Network(await NetworkReader(db).read());
    interpreter = RideInterpreter(network);
    await db.close();
  });

  // 옛 길은 2011-03-12 지진 운휴로 끝나 2016 이설 때 다시 열리지 않았다. 탈 수 있던 마지막 날이 기준이다
  test('이설 길 고르기는 길마다 그 길을 그만 쓴 날을 안다 (常磐線 新地~山下)', () {
    final options = RouteResolver(network).relocationOptions('r_joban_line', 'n_komagamine', 'n_hamayoshida');
    expect(options, hasLength(2));
    final old = options.firstWhere((o) => o.until != null);
    expect(old.until, '2011-03-12');
    expect(options.where((o) => o.until == null).single.asOf.compareTo('2016-12-10'), greaterThanOrEqualTo(0));
  }, skip: skip);

  test('날짜를 모르는 이설 구간은 방향이 아니라 길을 묻는다 (常磐線 駒ケ嶺~浜吉田)', () {
    final result = RouteResolver(network).expand('r_joban_line', 'n_komagamine', 'n_hamayoshida');
    expect(result.status, ResolveStatus.needsInput);
    expect(result.reason, ExpandReason.relocatedParallel);
    expect(result.options, hasLength(2));
  }, skip: skip);

  test('역 시트는 묶음의 다른 node에 서는 노선도 모두 보여 준다', () {
    final lines = {
      for (final route in network.routesAtStation('n_sendai_sendai_city')) network.routes[route]!.lineId,
    };
    expect(lines, containsAll(['l_tohoku_main_line', 'l_tohoku_shinkansen', 'l_namboku_line_sendai_city']));
    expect(network.routesAtStation('n_sendai_senseki'), network.routesAtStation('n_sendai_sendai_city'));
  }, skip: skip);

  test('오늘 영업하는 분모 노선은 모두 기록 탭의 현행 목록에 나온다 (DESIGN §8.0)', () {
    // 폐선 쪽은 승계 사슬의 지금 이름으로 묶이므로 노선 이름이 아니라 단위로 맞춘다 (core_parity 시험)
    final day = DateSpan.parse(today);
    final shown = {for (final line in browseTree(network, era: BrowseEra.current, hits: const {}, today: today).lines) line.lineId};
    final running = {
      for (final attr in network.data.attrs)
        if (stateOfPeriod(day, attr.period) == PeriodState.yes &&
            (network.unitOf(attr.lineId, attr.edgeId, carryover: true)?.normal ?? false))
          attr.lineId,
    };
    expect(running.difference(shown), isEmpty);
    expect(running.length, greaterThan(500));
  }, skip: skip);

  test('화물·연결선은 모선의 지선 계통이고 목록에 따로 나오지 않으며 요약 합계는 그대로다 (공식 노선 구성 2026-11-09)', () {
    final tree = browseTree(network, era: BrowseEra.current, hits: const {}, today: today);
    final shown = {for (final line in tree.lines) line.lineId};
    expect(shown.intersection({'l_tokaido_freight_line', 'l_fujishiro_line', 'l_osaki_branch_line', 'l_umeda_freight_line'}), isEmpty);
    expect(shown, containsAll(['l_hakodate_main_line', 'l_tokaido_main_line']));
    expect(network.routes['r_fujishiro_line']!.lineId, 'l_hakodate_main_line');
    expect(network.routes['r_umeda_freight_line']!.lineId, 'l_tokaido_main_line');
    // 요약 합계는 분모 단위만이다. 지선 계통의 칸은 분모 밖이라 모선 합계가 늘지 않는다
    final table = scoreTable(network, hits: const {}, basis: const BasisCurrent(), carryover: true, today: today);
    expect(tree.total.denMeters, table.total.denMeters);
    expect(tree.categories.fold<int>(0, (sum, c) => sum + c.score.denMeters), table.total.denMeters);
  }, skip: skip);

  Ride ride(String route, String from, String to, String? date, {bool alighted = true}) => Ride(
        rideId: const RideId('r'),
        datasetVersion: 'e',
        createdAt: DateTime.utc(2026, 11, 3).millisecondsSinceEpoch,
        updatedAt: 1,
        deviceId: 'd',
        dateInput: date,
        fromAlighted: alighted,
        toAlighted: alighted,
        legs: [
          RideLeg(
            seq: 0,
            lineId: LineId(network.routes[route]!.lineId),
            routeId: RouteId(route),
            fromNode: NodeId(from),
            toNode: NodeId(to),
            lineLabel: '',
            fromLabel: '',
            toLabel: '',
          ),
        ],
      );

  group('오사카 환상선 운행 계통', skip: skip, () {
    double? km(String from, String to, {required bool up}) {
      final splitter = ServiceSplitter(network);
      final service = network.data.services.firstWhere((item) => item.id == 's_osaka_loop');
      final stops = splitter.stops(service, null);
      ServiceStop at(String node) => stops.firstWhere((stop) => stop.node == node);
      final legs = splitter.legs(
        service,
        stops,
        at(from),
        at(to),
        date: null,
        lineName: (line) => line,
        nodeName: (node) => node,
        up: up,
      );
      if (legs == null) return null;
      final derived = interpreter.ride(
        Ride(
          rideId: const RideId('r'),
          legs: legs,
          datasetVersion: 'e',
          createdAt: 0,
          updatedAt: 0,
          deviceId: 'd',
        ),
      );
      return derived.status == ResolveStatus.ok ? derived.km10! / 10 : null;
    }

    test('고리를 넘는 칸은 관서 본선 구간이다', () {
      expect(km('n_shin_imamiya', 'n_tennoji', up: true), 1.0);
      expect(km('n_tennoji', 'n_shin_imamiya', up: false), 1.0);
      expect(km('n_imamiya', 'n_teradacho', up: true), 3.2);
    });

    test('두 방향의 합은 한 바퀴다', () {
      final one = km('n_osaka', 'n_kyobashi', up: true)!;
      final other = km('n_osaka', 'n_kyobashi', up: false)!;
      expect({one, other}, {4.2, 17.5});
    });

    test('한 바퀴를 저장할 수 있다', () {
      expect(km('n_tennoji', 'n_tennoji', up: true), 21.7);
    });
  });

  group('승하차역의 정차 기간', skip: skip, () {
    test('이관 뒤 날짜로 옛 노선에서 골라도 날짜가 남는다', () {
      final derived = interpreter.ride(ride('r_tohoku_main_line', 'n_sendai_senseki', 'n_aomori', '2020-05-05'));
      expect(derived.date, '2020-05-05');
      expect(derived.effectiveHi, '2020-05-05');
    });

    test('이관 전 날짜는 그대로다', () {
      expect(interpreter.ride(ride('r_tohoku_main_line', 'n_sendai_senseki', 'n_aomori', '1990-05-05')).date, '1990-05-05');
    });

    test('개업 전 날짜는 날짜 모름이 된다', () {
      final station = network.routes.keys.firstWhere(
        (route) => network.stops(route).any((stop) => stop.node == 'n_takanawa_gateway'),
      );
      expect(
        interpreter.ride(ride(station, 'n_takanawa_gateway', 'n_shinagawa', '2000-01-01')).date,
        isNull,
      );
    });

    test('잘린 끝은 통과라 개업 전이어도 날짜가 남는다', () {
      final station = network.routes.keys.firstWhere(
        (route) => network.stops(route).any((stop) => stop.node == 'n_takanawa_gateway'),
      );
      expect(
        interpreter.ride(ride(station, 'n_takanawa_gateway', 'n_shinagawa', '2000-01-01', alighted: false)).date,
        '2000-01-01',
      );
    });
  });

  group('노선도와 분모', skip: skip, () {
    test('아무것도 안 탔으면 남은 구간이 현행 분모와 같다', () {
      final table = scoreTable(network, hits: const {}, basis: const BasisCurrent(), carryover: true, today: today);
      final off = <String>[];
      for (final MapEntry(key: lineId, value: score) in table.byLine.entries) {
        final diagram = lineDiagram(network, lineId, hits: const {}, today: today);
        final seen = <String>{};
        var meters = 0;
        for (final route in diagram.routes) {
          for (final section in route.sections) {
            if (section.ridden || section.closed || !section.held || !section.editable) continue;
            for (final edge in section.edges) {
              final unit = network.unitOf(lineId, edge, carryover: true);
              final held = network.attrsOf(edge, lineId).any(
                    (attr) => stateOfPeriod(DateSpan.parse(today), attr.period) == PeriodState.yes,
                  );
              if (held && (unit?.normal ?? false) && seen.add(edge)) meters += network.edges[edge]!.meters;
            }
          }
        }
        if ((meters - score.denMeters).abs() > 1000) off.add('$lineId $meters/${score.denMeters}');
      }
      expect(off, isEmpty, reason: '${off.length}개 노선');
    });

    test('계통별 현행은 그 노선이 맡은 구간만 센다', () {
      final diagram = lineDiagram(network, 'l_tohoku_main_line', hits: const {}, today: today);
      final tree = browseTree(network, era: BrowseEra.current, hits: const {}, today: today, carryover: true);
      final line = tree.lines.firstWhere((item) => item.lineId == 'l_tohoku_main_line');
      final main = diagram.routes.first;
      expect(main.current.denMeters, lessThanOrEqualTo(line.score.denMeters));
    });

    test('역대에서 넘어간 구간은 지금 노선에만 든다', () {
      final units = <int>{for (final unit in network.data.units) if (unit.carryover && unit.normal) unit.n};
      final hits = {for (final n in units) n: '2000-01-01'};
      final table = scoreTable(network, hits: hits, basis: const BasisAllTime(), carryover: true, today: today);
      final sum = table.byLine.values.fold(0, (total, score) => total + score.denMeters);
      expect(sum, table.total.denMeters);
    });
  });

  group('변경 소식', skip: skip, () {
    late List<NewsItem> news;

    setUpAll(() {
      if (skip == null) news = networkNews(network, today);
    });

    test('운휴는 폐지가 아니다', () {
      final suspended = {
        for (final life in network.data.lives)
          if (life.suspended && (life.period.toHi == null || life.period.toHi == DateSpan.maxDate)) life.edgeId,
      };
      final lines = {for (final edge in suspended) network.attrsOfEdge(edge).last.lineId};
      for (final item in news.where((item) => item.kind == NewsKind.lineClosed)) {
        final allSuspended = network.routesOfLine(item.lineId).expand(network.hops).every(
              (hop) => suspended.contains(hop.edge),
            );
        expect(lines.contains(item.lineId) && allSuspended, isFalse, reason: item.key);
      }
    });

    test('이관한 날에 역이 폐지되거나 신설되지 않는다', () {
      final sameDay = news.where(
        (item) => item.date == '2024-03-16' && (item.kind == NewsKind.stationClosed || item.kind == NewsKind.stationOpened),
      );
      expect(sameDay.map((item) => item.node), isNot(contains('n_fukui')));
      expect(sameDay.map((item) => item.node), isNot(contains('n_tsuruga')));
    });

    test('폐역 소식의 노선은 그 역에 마지막까지 선 노선이다', () {
      // 留萌는 1987 폐지 羽幌線이 아니라 留萌本線과 함께 2023-04-01에 없어졌다. 노선과 같은 날이라 노선 소식에 든다
      expect(news.where((item) => item.node == 'n_rumoi_rumoi_main'), isEmpty);
      expect(
        news.where((item) => item.kind == NewsKind.lineClosed && item.lineId == 'l_rumoi_main_line').map((item) => item.date),
        contains('2023-04-01'),
      );
    });
  });

  // 판 데이터에 정차역이 아직 없어도 규칙은 여기서 지킨다. 정차역을 솎은 판을 만들어 모든 역일 때와 맞춘다
  test('운행 계통 화면에 정차역만 두어도 저장 분해와 km는 모든 역일 때와 같다', () {
    final splitter = ServiceSplitter(network);
    List<(String, String, String)> keys(List<RideLeg>? legs) =>
        [for (final leg in legs ?? const <RideLeg>[]) (leg.routeId.value, leg.fromNode.value, leg.toNode.value)];
    int? km(List<RideLeg>? legs) => legs == null
        ? null
        : interpreter
            .ride(Ride(rideId: const RideId('r'), legs: legs, datasetVersion: 'e', createdAt: 0, updatedAt: 0, deviceId: 'd'))
            .km10;
    var compared = 0;
    for (final service in network.data.services) {
      final all = splitter.stops(service, null);
      if (all.length < 4) continue;
      final edition = splitter.edition(service, null)!;
      // 양 끝과 세 역마다 하나에만 선다. 노선이 바뀌는 역에 서지 않는 곳이 생긴다
      final thin = NetService(id: service.id, closed: service.closed, editions: [
        NetServiceEdition(
          validFrom: edition.validFrom,
          validTo: edition.validTo,
          parts: edition.parts,
          stops: {
            for (final (at, stop) in all.indexed)
              if (at == 0 || at == all.length - 1 || at % 3 == 0) stop.node,
          },
        ),
      ]);
      final thinAll = splitter.stops(thin, null);
      final shown = splitter.halts(thin, null);
      expect(shown.length, lessThan(thinAll.length), reason: service.id);
      for (var a = 0; a < shown.length; a += 2) {
        for (var b = a + 1; b < shown.length; b += 3) {
          if (shown[a].node == shown[b].node) continue;
          for (final up in service.closed ? const [true, false] : const [true]) {
            List<RideLeg>? legs(NetService s, List<ServiceStop> stops, ServiceStop from, ServiceStop to) =>
                splitter.legs(s, stops, from, to, date: null, up: up, lineName: (id) => id, nodeName: (node) => node);
            final thinLegs = legs(thin, thinAll, shown[a], shown[b]);
            final fullLegs = legs(service, all, all[shown[a].index], all[shown[b].index]);
            expect(keys(thinLegs), keys(fullLegs), reason: '${service.id} ${shown[a].node}~${shown[b].node}');
            expect(km(thinLegs), km(fullLegs));
            compared++;
          }
        }
      }
    }
    expect(compared, greaterThan(100));
  }, skip: skip);
}
