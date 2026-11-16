import 'dart:convert';
import 'dart:io';

import 'package:noriori_core/noriori_core.dart';
import 'package:noriori_store/noriori_store.dart';
import 'package:test/test.dart';

/// 실제 판으로 core가 파이썬 기준(`tools/appsim.py`)과 같은지 본다. 대조표는 `tools/core_fixture.py`가 만든다.
void main() {
  final fixture = File('../../build/core_fixture.json');
  final masterFile = File('../../build/master.sqlite');
  final skip = fixture.existsSync() && masterFile.existsSync() ? null : '대조표가 없다';

  late Network network;
  late Map<String, Object?> table;

  setUpAll(() async {
    if (skip != null) return;
    table = jsonDecode(fixture.readAsStringSync()) as Map<String, Object?>;
    final db = UserDb(openDirect(File(':memory:')));
    final dir = masterFile.absolute.parent.path;
    await db.customStatement("ATTACH 'file:$dir/master.sqlite?mode=ro&immutable=1' AS master");
    network = Network(await NetworkReader(db).read());
    await db.close();
  });

  test('노리츠부시 CSV가 판에 맞는다', () async {
    // 개인 기록이라 저장소에 두지 않는다. 경로를 받았을 때만 돈다
    final path = Platform.environment['NORIORI_CSV'];
    if (path == null) return;
    final dir = masterFile.absolute.parent.path;
    final db = UserDb(openDirect(File(':memory:')));
    await db.customStatement("ATTACH 'file:$dir/names.sqlite?mode=ro&immutable=1' AS names");
    await db.customStatement("ATTACH 'file:$dir/master.sqlite?mode=ro&immutable=1' AS master");
    final names = await PackReader(db).importNames();
    final exportNames = await PackReader(db).exportNames();
    final operatorRows = await db.customSelect(
      "SELECT entity_id, text FROM names.name WHERE entity_type = 'operator' AND lang = 'ja'",
    ).get();
    await db.close();
    final file = parseNoritsubushiCsv(decodeCsvBytes(File(path).readAsBytesSync()));
    final plan = planImport(file, CsvMatcher(network, names), const {}, idOf: uuidV5);
    final reasons = <String, int>{};
    for (final row in plan.missed) {
      final key = (row.result as RowMissed).reason.name;
      reasons[key] = (reasons[key] ?? 0) + 1;
    }
    print('행 ${plan.rows.length}, 깨짐 ${plan.broken.length}, 못 맞춤 ${plan.missed.length} $reasons, '
        '거리 다름 ${plan.kmDiffers.length}, 합계 ${plan.freshMeters}m');
    for (final row in plan.kmDiffers) {
      final found = row.result as RowMatched;
      print('거리 다름 ${row.row.line}: 파일 ${row.row.meters}, 앱 ${found.routeId} ${found.meters}');
    }
    expect(plan.missed, isEmpty);
    expect(plan.broken, isEmpty);

    // 노리츠부시 자체 집계와 회사별로 맞춘다. 규칙 밖의 값이다
    final site = Platform.environment['NORIORI_SITE'];
    if (site == null) return;
    final interpreter = RideInterpreter(network);
    final hits = <int, String?>{};
    final rides = <Ride>[];
    for (final row in plan.rows) {
      final ride = importedRide(
        row,
        edition: 'e',
        now: 1,
        deviceId: 'd',
        lineLabel: '',
        fromLabel: '',
        toLabel: '',
      );
      rides.add(ride);
      for (final edge in interpreter.ride(ride).edges) {
        hits[edge.unitOn] = null;
      }
    }
    final tree = browseTree(network, era: BrowseEra.current, hits: hits, today: '2026-11-02');
    final idsOf = <String, List<String>>{};
    for (final row in operatorRows) {
      (idsOf[row.read<String>('text')] ??= []).add(row.read('entity_id'));
    }
    final scores = {
      for (final category in tree.categories)
        for (final operator in category.operators) operator.operatorId: operator.score,
    };
    final wrong = <String>[];
    final table = (jsonDecode(File(site).readAsStringSync()) as List<Object?>).cast<List<Object?>>();
    for (final row in table) {
      final name = row[0]! as String;
      final score = scores[(idsOf[name] ?? const []).where(scores.containsKey).firstOrNull];
      final den = ((row[1]! as num) * 10).round();
      final ridden = ((row[2]! as num) * 10).round();
      if (score == null) {
        wrong.add('$name: 앱에 없음 ($den)');
      } else if ((score.denMeters + 50) ~/ 100 != den ||
          (score.numMeters + 50) ~/ 100 != ridden) {
        wrong.add('$name: 사이트 $ridden/$den, 앱 ${score.numMeters}/${score.denMeters}');
      }
    }
    print('회사 ${table.length}곳 대조, 어긋남 ${wrong.length}');
    wrong.forEach(print);
    print('앱에만 있는 회사 ${scores.length - table.length}곳');
    // 내보낸 호환판을 다시 읽어도 같은 경로와 거리다
    final exporter = CsvExporter(network, exportNames);
    final out = parseNoritsubushiCsv(exporter.compat(rides));
    final back = out.rides.map(CsvMatcher(network, names).match).toList();
    final lost = back.whereType<RowMissed>().length;
    final meters = back.whereType<RowMatched>().fold(0, (sum, row) => sum + row.meters);
    final total = plan.rows.map((row) => row.result).whereType<RowMatched>().fold(
          0,
          (sum, row) => sum + row.meters,
        );
    print('내보내기 ${out.rides.length}행, 못 맞춤 $lost, 합계 ${meters}m');
    expect(lost, 0);
    expect(meters, total);
  }, skip: skip);

  test('펼치기 결과가 같다', () {
    final resolver = RouteResolver(network);
    final rows = (table['expand']! as List<Object?>).cast<Map<String, Object?>>();
    final wrong = <String>[];
    for (final row in rows) {
      final raw = row['date'] as String?;
      final got = resolver.record(
        row['route']! as String,
        row['a']! as String,
        row['b']! as String,
        date: raw == null ? null : DateSpan.parse(raw),
      );
      final same = got.status.wire == row['status'] &&
          _same(got.edges, row['edges']) &&
          got.demoted == row['demoted'] &&
          (row['m'] == null || got.meters == row['m']) &&
          (row['nodes'] == null || _same(got.nodes, row['nodes'])) &&
          (row['direction'] == null || got.direction == row['direction']) &&
          (row['lines'] == null ||
              _same({for (final leg in got.legs) leg.lineId}.toList()..sort(), row['lines']));
      if (!same) {
        wrong.add('${row['route']} ${row['a']} ${row['b']} ${row['date']}: '
            '${got.status.wire}/${row['status']} ${got.reason} ${got.meters}/${row['m']} '
            '${got.demoted}/${row['demoted']}');
      }
    }
    expect(wrong.take(10).toList(), isEmpty, reason: '${wrong.length}/${rows.length} 불일치');
  }, skip: skip);

  test('선택기 상태가 같다', () {
    final builder = SelectorBuilder(network);
    final rows = (table['picker']! as List<Object?>).cast<Map<String, Object?>>();
    final wrong = <String>[];
    const wire = {
      StopState.open: 'open',
      StopState.maybe: 'maybe',
      StopState.unknown: 'unknown',
      StopState.beforeOpen: 'before_open',
      StopState.closed: 'closed',
      StopState.suspended: 'suspended',
      StopState.lineClosed: 'line_closed',
      StopState.noEdge: 'no_edge',
    };
    for (final row in rows) {
      final raw = row['date'] as String?;
      final got = builder.build(row['route']! as String, raw == null ? null : DateSpan.parse(raw));
      final want = (row['rows']! as List<Object?>).cast<List<Object?>>();
      if (got.length != want.length) {
        wrong.add('${row['route']} $raw 행 수 ${got.length}/${want.length}');
        continue;
      }
      for (final (i, item) in got.indexed) {
        final w = want[i];
        if (item.seq != w[0] ||
            item.node != w[1] ||
            wire[item.state] != w[2] ||
            item.selectable != w[3] ||
            item.savedAs != w[4]) {
          wrong.add('${row['route']} $raw ${item.node}: ${wire[item.state]}/${w[2]} ${item.savedAs}/${w[4]}');
        }
      }
    }
    expect(wrong.take(10).toList(), isEmpty, reason: '${wrong.length} 불일치');
  }, skip: skip);

  test('기록 탭의 트리가 빌드의 분모와 맞다', () async {
    const today = '2026-11-02';
    final current = browseTree(network, era: BrowseEra.current, hits: const {}, today: today);
    final closed = browseTree(network, era: BrowseEra.closed, hits: const {}, today: today);

    // 현행과 폐선을 합치면 역대다. 구간이 빠지거나 두 번 들어가지 않는다
    final allTime = computeScore(
      units: network.data.units.where((u) => u.carryover),
      hits: const {},
      basis: const BasisAllTime(),
      today: today,
    );
    expect(current.total.denMeters + closed.total.denMeters, allTime.denMeters);
    expect(current.total.denUnits + closed.total.denUnits, allTime.denUnits);

    // 폐선은 구간마다 한 곳에만 들어간다
    var lines = 0;
    for (final category in closed.categories) {
      for (final operator in category.operators) {
        // 별선·단락선만 있는 줄은 합계에 들지 않는다 (DESIGN §8.0)
        lines += operator.lines.where((line) => !line.outside).fold(0, (sum, line) => sum + line.score.denMeters);
      }
    }
    expect(lines, closed.total.denMeters);

    // 노선별 현행 분모는 빌드가 따로 계산한 값과 같다
    final db = UserDb(openDirect(File(':memory:')));
    final dir = masterFile.absolute.parent.path;
    await db.customStatement("ATTACH 'file:$dir/master.sqlite?mode=ro&immutable=1' AS master");
    final rows = await db.customSelect(
      "SELECT scope, km FROM master.denominator WHERE basis = 'current' AND carryover = 'on' "
      "AND scope LIKE 'l\\_%' ESCAPE '\\'",
    ).get();
    await db.close();
    final built = {for (final row in rows) row.read<String>('scope'): row.read<double>('km')};
    expect(built.length, greaterThan(500));
    final wrong = <String>[];
    final seen = <String, int>{};
    for (final category in current.categories) {
      for (final operator in category.operators) {
        for (final line in operator.lines.where((line) => !line.outside)) {
          seen[line.lineId] = (seen[line.lineId] ?? 0) + line.score.denMeters;
        }
      }
    }
    for (final MapEntry(:key, :value) in seen.entries) {
      final want = built[key];
      if (want == null || (value / 100).round() != (want * 10).round()) {
        wrong.add('$key $value/$want');
      }
    }
    expect(wrong.take(10).toList(), isEmpty, reason: '${wrong.length}/${seen.length} 불일치');
  }, skip: skip);

  test('분모와 완주율이 같다', () {
    final interpreter = RideInterpreter(network);
    final rides = (table['rides']! as List<Object?>).cast<Map<String, Object?>>();
    final derived = <RideDerived>[];
    final wrongHi = <String>[];
    for (final (i, row) in rides.indexed) {
      final ride = Ride(
        rideId: RideId('r$i'),
        datasetVersion: 'e',
        createdAt: DateTime.utc(2026, 10, 31, 16).millisecondsSinceEpoch,
        updatedAt: 1,
        deviceId: 'd',
        dateInput: row['date'] as String?,
        fromAlighted: true,
        toAlighted: true,
        legs: [
          RideLeg(
            seq: 0,
            lineId: LineId(network.routes[row['route']!]!.lineId),
            routeId: RouteId(row['route']! as String),
            fromNode: NodeId(row['a']! as String),
            toNode: NodeId(row['b']! as String),
            lineLabel: '',
            fromLabel: '',
            toLabel: '',
          ),
        ],
      );
      final one = interpreter.ride(ride);
      derived.add(one);
      if (one.effectiveHi != row['hi'] && row['hi'] != null) {
        wrongHi.add('${row['route']} ${row['date']}: ${one.effectiveHi}/${row['hi']}');
      }
    }
    final today = table['today']! as String;
    final wrong = <String>[];
    for (final row in (table['scores']! as List<Object?>).cast<Map<String, Object?>>()) {
      final carryover = row['carryover'] == 'on';
      final basis = switch (row['basis']) {
        'current' => const BasisCurrent(),
        'alltime' => const BasisAllTime(),
        final String year => BasisYear(int.parse(year)),
        _ => throw StateError('기준'),
      };
      final hits = <int, String?>{};
      for (final one in derived.take(row['n']! as int)) {
        for (final hit in one.edges) {
          final unit = carryover ? hit.unitOn : hit.unitOff;
          final old = hits[unit];
          final hi = one.effectiveHi;
          if (!hits.containsKey(unit) || (hi != null && old != null && hi.compareTo(old) < 0)) {
            hits[unit] = hi;
          }
        }
      }
      final score = computeScore(
        units: network.data.units.where((u) => u.carryover == carryover),
        hits: hits,
        basis: basis,
        today: today,
      );
      if (score.denUnits != row['den_units'] ||
          score.numUnits != row['num_units'] ||
          (score.denMeters / 100).round() != ((row['den']! as num) * 10).round() ||
          (score.numMeters / 100).round() != ((row['num']! as num) * 10).round()) {
        wrong.add('$row -> ${score.numUnits}/${score.denUnits} ${score.numMeters}/${score.denMeters}');
      }
    }
    expect(wrongHi.take(10).toList(), isEmpty, reason: '${wrongHi.length} 불일치');
    expect(wrong.take(6).toList(), isEmpty, reason: '${wrong.length} 불일치');
  }, skip: skip);
}

bool _same(List<String> got, Object? want) {
  final list = (want! as List<Object?>).cast<String>();
  if (got.length != list.length) return false;
  for (var i = 0; i < got.length; i++) {
    if (got[i] != list[i]) return false;
  }
  return true;
}
