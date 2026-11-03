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
      SELECT route_id, seq, node_id, km_cum, is_stop, is_extension,
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
      SELECT n, unit_key, carryover, edge_id, m, class, date_lo, date_hi
      FROM master.denominator_unit
    ''');
    final nodes = await _rows('SELECT id, group_id FROM master.node_public');
    final operators = await _rows('SELECT id, category FROM master.operator ORDER BY rowid');
    final lines = await _rows('SELECT id FROM master.line ORDER BY rowid');
    final prefs = await _rows('SELECT edge_id, pref, km FROM master.edge_pref');
    final services = await _rows('SELECT id, closed, valid_from, valid_to FROM master.service');
    final parts = await _rows(
      'SELECT service_id, route_id, from_node, to_node FROM master.service_part ORDER BY service_id, seq',
    );
    final partsOf = <String, List<NetServicePart>>{};
    for (final row in parts) {
      (partsOf[row.read<String>('service_id')] ??= []).add(
        NetServicePart(
          routeId: row.read('route_id'),
          from: row.read('from_node'),
          to: row.read('to_node'),
        ),
      );
    }
    return NetworkData(
      services: [
        for (final row in services)
          NetService(
            id: row.read('id'),
            closed: row.read<int>('closed') == 1,
            validFrom: row.readNullable('valid_from'),
            validTo: row.readNullable('valid_to'),
            parts: partsOf[row.read<String>('id')] ?? const [],
          ),
      ],
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
            period: _period(row),
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

  NetPeriod _period(QueryRow row) => NetPeriod(
        fromLo: row.readNullable('valid_from_lo'),
        fromHi: row.readNullable('valid_from_hi'),
        toLo: row.readNullable('valid_to_lo'),
        toHi: row.readNullable('valid_to_hi'),
      );
}
