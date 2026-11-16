import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:noriori_core/noriori_core.dart';

import '../db/user_db.dart';

/// 팩의 선로망을 core가 계산할 값으로 읽는다. 세션에 한 번 읽고 메모리에 둔다.
final class NetworkReader {
  const NetworkReader(this._db);

  final UserDb _db;

  Future<List<QueryRow>> _rows(String sql) => _db.customSelect(sql).get();

  Future<NetworkData> read() async {
    final routes = await _rows(
      'SELECT id, line_id, role, from_node, to_node, closed, extend_to FROM master.route',
    );
    final edges = await _rows('''
      SELECT e.id, e.n, e.from_node, e.to_node, k.m
      FROM master.edge e JOIN master.edge_km k ON k.edge_id = e.id
    ''');
    final routeEdges = await _rows(
      'SELECT route_id, seq, edge_id FROM master.route_edge ORDER BY route_id, seq',
    );
    final stops = await _rows('''
      SELECT route_id, seq, node_id, km_cum, is_stop, is_extension, km_estimated,
             valid_from_lo, valid_from_hi, valid_to_lo, valid_to_hi
      FROM master.route_stop ORDER BY route_id, seq
    ''');
    final attrs = await _rows('''
      SELECT edge_id, line_id, operator_id, lineage_id, carryover_group,
             valid_from_lo, valid_from_hi, valid_to_lo, valid_to_hi
      FROM master.edge_attr
    ''');
    final lives = await _rows('''
      SELECT edge_id, status, valid_from_lo, valid_from_hi, valid_to_lo, valid_to_hi
      FROM master.edge_life
    ''');
    final units = await _rows('''
      SELECT n, unit_key, carryover, edge_id, m, class, date_lo, date_hi, valid_from, valid_to
      FROM master.denominator_unit
    ''');
    final nodes = await _rows('SELECT id, group_id FROM master.node_public');
    final operators = await _rows('SELECT id, category FROM master.operator ORDER BY rowid');
    final lines = await _rows('SELECT id FROM master.line ORDER BY rowid');
    final prefs = await _rows('SELECT edge_id, pref, km FROM master.edge_pref');
    // 정차 기간 사이 서지 않은 때. 이 표가 없는 옛 판이면 없다
    final hasGap = (await _rows("SELECT 1 FROM master.sqlite_master WHERE type = 'table' AND name = 'route_stop_gap'")).isNotEmpty;
    final gapsOf = <String, List<NetPeriod>>{};
    if (hasGap) {
      for (final row in await _rows(
        'SELECT route_id, seq, gap_from_lo, gap_from_hi, gap_to_lo, gap_to_hi FROM master.route_stop_gap',
      )) {
        (gapsOf['${row.read<String>('route_id')}|${row.read<int>('seq')}'] ??= []).add(NetPeriod(
          fromLo: row.readNullable('gap_from_lo'),
          fromHi: row.readNullable('gap_from_hi'),
          toLo: row.readNullable('gap_to_lo'),
          toHi: row.readNullable('gap_to_hi'),
        ));
      }
    }
    final hasEra = (await _rows("SELECT 1 FROM master.sqlite_master WHERE type = 'table' AND name = 'edge_km_era'")).isNotEmpty;
    final era = hasEra ? await _rows('SELECT edge_id, line_id, m FROM master.edge_km_era') : const <QueryRow>[];
    final services = await _rows('SELECT id, closed, valid_from, valid_to FROM master.service');
    // 한 방향 운행 칸과 한 방향 정차 (DESIGN §8). 이 표가 없는 옛 판이면 없다
    Future<bool> has(String table) async =>
        (await _rows("SELECT 1 FROM master.sqlite_master WHERE type = 'table' AND name = '$table'")).isNotEmpty;
    NetPeriod periodOf(QueryRow row) => NetPeriod(
          fromLo: row.readNullable('valid_from_lo'),
          fromHi: row.readNullable('valid_from_hi'),
          toLo: row.readNullable('valid_to_lo'),
          toHi: row.readNullable('valid_to_hi'),
        );
    final oneWays = [
      if (await has('edge_one_way'))
        for (final row in await _rows(
          'SELECT route_id, edge_id, from_node, to_node, valid_from_lo, valid_from_hi, valid_to_lo, valid_to_hi FROM master.edge_one_way',
        ))
          NetOneWay(
            routeId: row.read('route_id'),
            edgeId: row.read('edge_id'),
            from: row.read('from_node'),
            to: row.read('to_node'),
            period: periodOf(row),
          ),
    ];
    final stopDirections = [
      if (await has('stop_direction'))
        for (final row in await _rows(
          'SELECT route_id, node_id, direction, label, use, valid_from_lo, valid_from_hi, valid_to_lo, valid_to_hi FROM master.stop_direction',
        ))
          NetStopDirection(
            routeId: row.read('route_id'),
            node: row.read('node_id'),
            direction: row.read('direction'),
            label: row.readNullable('label'),
            use: row.readNullable('use'),
            period: periodOf(row),
          ),
    ];
    return NetworkData(
      services: await _services(services),
      routes: [
        for (final row in routes)
          NetRoute(
            id: row.read('id'),
            lineId: row.read('line_id'),
            role: row.read('role'),
            fromNode: row.read('from_node'),
            toNode: row.read('to_node'),
            closed: row.read<int>('closed') != 0,
            extendTo: [
              for (final node in jsonDecode(row.read('extend_to')) as List<Object?>)
                node! as String,
            ],
          ),
      ],
      edges: [
        for (final row in edges)
          NetEdge(
            id: row.read('id'),
            n: row.read('n'),
            from: row.read('from_node'),
            to: row.read('to_node'),
            meters: row.read('m'),
          ),
      ],
      routeEdges: [
        for (final row in routeEdges)
          NetRouteEdge(
            routeId: row.read('route_id'),
            seq: row.read('seq'),
            edgeId: row.read('edge_id'),
          ),
      ],
      stops: [
        for (final row in stops)
          NetStop(
            routeId: row.read('route_id'),
            seq: row.read('seq'),
            node: row.read('node_id'),
            kmCum: row.readNullable<double>('km_cum'),
            isStop: row.read<int>('is_stop') != 0,
            isExtension: row.read<int>('is_extension') != 0,
            kmEstimated: row.read<int>('km_estimated') != 0,
            period: _period(row),
            gaps: gapsOf['${row.read<String>('route_id')}|${row.read<int>('seq')}'] ?? const [],
          ),
      ],
      attrs: [
        for (final row in attrs)
          NetAttr(
            edgeId: row.read('edge_id'),
            lineId: row.read('line_id'),
            operatorId: row.read('operator_id'),
            lineageId: row.read('lineage_id'),
            carryoverGroup: row.read('carryover_group'),
            period: _period(row),
          ),
      ],
      lives: [
        for (final row in lives)
          NetLife(
            edgeId: row.read('edge_id'),
            suspended: row.read<String>('status') == 'suspended',
            period: _period(row),
          ),
      ],
      units: [
        for (final row in units)
          NetUnit(
            n: row.read('n'),
            key: row.read('unit_key'),
            carryover: row.read<String>('carryover') == 'on',
            edgeId: row.read('edge_id'),
            meters: row.read('m'),
            normal: row.read<String>('class') == 'normal',
            dateLo: row.readNullable('date_lo'),
            dateHi: row.readNullable('date_hi'),
            fromHi: _span(row.readNullable('valid_from'))?.hi,
            toLo: _span(row.readNullable('valid_to'))?.lo,
          ),
      ],
      publicNodes: {for (final row in nodes) row.read<String>('id')},
      nodeGroups: {
        for (final row in nodes)
          if (row.readNullable<String>('group_id') != null)
            row.read<String>('id'): row.read<String>('group_id'),
      },
      groupNumbers: {
        for (final row in await _db.customSelect('SELECT id, n FROM master.station_group').get())
          row.read<String>('id'): row.read<int>('n'),
      },
      operators: [
        for (final row in operators)
          NetOperator(id: row.read('id'), category: row.read('category')),
      ],
      lineOrder: [for (final row in lines) row.read<String>('id')],
      oneWays: oneWays,
      stopDirections: stopDirections,
      eraMeters: {
        for (final row in era) '${row.read<String>('line_id')}\u0000${row.read<String>('edge_id')}': row.read<int>('m'),
      },
      edgePrefs: [
        for (final row in prefs)
          NetEdgePref(
            edgeId: row.read('edge_id'),
            pref: int.parse(row.read<String>('pref')),
            meters: (row.read<double>('km') * 1000).round(),
          ),
      ],
    );
  }

  /// 운행 계통과 판. 판 표(`service_edition`)가 없는 옛 팩은 운행 계통마다 정차역 없는(모든 역) 판 하나다.
  Future<List<NetService>> _services(List<QueryRow> services) async {
    final hasEdition =
        (await _rows("SELECT 1 FROM master.sqlite_master WHERE type = 'table' AND name = 'service_edition'")).isNotEmpty;
    final parts = await _rows(hasEdition
        ? 'SELECT service_id, edition, route_id, from_node, to_node FROM master.service_part ORDER BY service_id, edition, seq'
        : 'SELECT service_id, 0 AS edition, route_id, from_node, to_node FROM master.service_part ORDER BY service_id, seq');
    final partsOf = <String, List<NetServicePart>>{};
    for (final row in parts) {
      (partsOf['${row.read<String>('service_id')}|${row.read<int>('edition')}'] ??= []).add(
        NetServicePart(
          routeId: row.read('route_id'),
          from: row.read('from_node'),
          to: row.read('to_node'),
        ),
      );
    }
    if (!hasEdition) {
      return [
        for (final row in services)
          NetService(
            id: row.read('id'),
            closed: row.read<int>('closed') == 1,
            editions: [
              NetServiceEdition(
                validFrom: _span(row.readNullable('valid_from'))?.lo,
                validTo: row.readNullable<String>('valid_to') == null ? null : _span(row.read('valid_to'))?.hi,
                parts: partsOf['${row.read<String>('id')}|0'] ?? const [],
              ),
            ],
          ),
      ];
    }
    final stopsOf = <String, Set<String>>{};
    for (final row in await _rows('SELECT service_id, edition, node_id FROM master.service_stop')) {
      (stopsOf['${row.read<String>('service_id')}|${row.read<int>('edition')}'] ??= {}).add(row.read('node_id'));
    }
    final editionsOf = <String, List<NetServiceEdition>>{};
    for (final row in await _rows('''
      SELECT service_id, edition, valid_from_lo, valid_to, valid_to_hi, all_stops
      FROM master.service_edition ORDER BY service_id, edition
    ''')) {
      final key = '${row.read<String>('service_id')}|${row.read<int>('edition')}';
      (editionsOf[row.read<String>('service_id')] ??= []).add(NetServiceEdition(
        // 범위로 적힌 날짜는 넓게 본다. 겹치는 판이 둘이면 늦은 판을 쓴다 (ServiceSplitter.edition)
        validFrom: row.readNullable('valid_from_lo'),
        validTo: row.readNullable<String>('valid_to') == 'ongoing' ? 'ongoing' : row.readNullable('valid_to_hi'),
        parts: partsOf[key] ?? const [],
        stops: row.read<int>('all_stops') == 1 ? null : (stopsOf[key] ?? const {}),
      ));
    }
    return [
      for (final row in services)
        NetService(
          id: row.read('id'),
          closed: row.read<int>('closed') == 1,
          editions: editionsOf[row.read<String>('id')] ?? const [],
        ),
    ];
  }

  NetPeriod _period(QueryRow row) => NetPeriod(
        fromLo: row.readNullable('valid_from_lo'),
        fromHi: row.readNullable('valid_from_hi'),
        toLo: row.readNullable('valid_to_lo'),
        toHi: row.readNullable('valid_to_hi'),
      );

  /// 분모 단위의 기간 원문. 모르는 날짜는 null이다.
  static DateSpan? _span(String? raw) => raw == null ? null : DateSpan.parse(raw);
}
