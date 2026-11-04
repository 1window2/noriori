import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:noriori_core/noriori_core.dart';

import '../db/user_db.dart';
import '../records/record_queries.dart';

/// 이 코드가 읽을 수 있는 데이터 팩의 스키마. 쿼리가 팩 스키마에 묶이므로 여기에 둔다.
const supportedPackSchema = 2;

/// 팩의 규모. 판이 붙었는지 화면과 시험에서 확인하는 값이다.
final class PackSummary {
  const PackSummary({required this.stations, required this.lines});

  final int stations;
  final int lines;
}

/// 검색 결과 하나.
final class SearchHit {
  const SearchHit({required this.kind, required this.id});

  /// `line`, `node`, `service`.
  final String kind;
  final String id;
}

/// 판이 바뀌지 않는 세션 동안 메모리에 두는 이름. 역 이름은 필요할 때 읽는다.
final class NameBook {
  const NameBook({required this.lines, required this.routes, required this.operators});

  final Map<String, String> lines;
  final Map<String, String> routes;
  final Map<String, String> operators;
}

/// 데이터 팩을 읽는 쿼리. 앱 코드는 `node`가 아니라 `node_public`을 읽는다.
final class PackReader {
  const PackReader(this._db, {this.languages = koreanFirst});

  final UserDb _db;

  /// 이름을 고르는 순서. 앱 언어를 따른다.
  final List<String> languages;

  /// 화면 이름은 한국어를 먼저, 없으면 일본어다.
  static const koreanFirst = ['ko', 'ja'];
  static const englishFirst = ['en', 'ja', 'ko'];
  static const japaneseFirst = ['ja', 'ko'];

  Future<PackSummary> summary() async {
    final row = await _db.customSelect(
      'SELECT (SELECT count(*) FROM master.node_public) AS stations, '
      '(SELECT count(*) FROM master.line) AS lines',
    ).getSingle();
    return PackSummary(
      stations: row.read<int>('stations'),
      lines: row.read<int>('lines'),
    );
  }

  Future<NameBook> nameBook() async {
    final rows = await _db.customSelect(
      'SELECT entity_type, entity_id, lang, text FROM names.name '
      "WHERE entity_type IN ('line', 'route', 'operator')",
    ).get();
    final byKind = <String, Map<String, Map<String, String>>>{};
    for (final row in rows) {
      final kind = byKind[row.read<String>('entity_type')] ??= {};
      final texts = kind[row.read<String>('entity_id')] ??= {};
      texts.putIfAbsent(row.read('lang'), () => row.read('text'));
    }
    Map<String, String> pick(String kind) => {
          for (final MapEntry(:key, :value) in (byKind[kind] ?? const {}).entries)
            key: _first(value) ?? key,
        };
    return NameBook(lines: pick('line'), routes: pick('route'), operators: pick('operator'));
  }

  /// 가져오기가 쓰는 일본어 이름과 별칭. 자주 쓰지 않아 세션에 들고 있지 않는다.
  Future<ImportNames> importNames() async {
    final rows = await _db.customSelect(
      "SELECT entity_type, entity_id, text FROM names.name WHERE lang = 'ja' "
      "AND entity_type IN ('route', 'line', 'node') "
      'UNION ALL SELECT entity_type, entity_id, text FROM names.alias '
      "WHERE entity_type IN ('route', 'line', 'node')",
    ).get();
    final byKind = <String, Map<String, Set<String>>>{};
    for (final row in rows) {
      final kind = byKind[row.read<String>('entity_type')] ??= {};
      (kind[importKey(row.read('text'))] ??= {}).add(row.read('entity_id'));
    }
    return ImportNames(
      routes: byKind['route'] ?? const {},
      lines: byKind['line'] ?? const {},
      nodes: byKind['node'] ?? const {},
    );
  }

  /// 내보내기가 쓰는 일본어 공식명. `export_name`이 있으면 그것을 쓴다: 숨은 노드, 역 이전의 옛 역 (DESIGN §10.3).
  Future<ExportNames> exportNames() async {
    final rows = await _db.customSelect(
      'SELECT entity_type, entity_id, text, line_id, valid_from, valid_to FROM names.name '
      "WHERE lang = 'ja' AND entity_type IN ('node', 'line', 'operator')",
    ).get();
    final grouped = <String, Map<String, List<NameRow>>>{};
    for (final row in rows) {
      final kind = grouped[row.read<String>('entity_type')] ??= {};
      (kind[row.read<String>('entity_id')] ??= []).add(
        NameRow(
          text: row.read('text'),
          lineId: row.readNullable('line_id'),
          validFrom: row.readNullable('valid_from'),
          validTo: row.readNullable('valid_to'),
        ),
      );
    }
    Map<String, String> plain(String kind) => {
          for (final MapEntry(:key, :value) in (grouped[kind] ?? const {}).entries)
            key: pickName(value) ?? value.first.text,
        };
    final nodes = plain('node');
    for (final row in await _db
        .customSelect('SELECT id, export_name FROM master.node WHERE export_name IS NOT NULL')
        .get()) {
      nodes[row.read('id')] = row.read('export_name');
    }
    final aliases = await _db.customSelect(
      'SELECT entity_id, text FROM names.alias '
      "WHERE entity_type = 'route' AND kind = 'noritsubushi' ORDER BY text",
    ).get();
    return ExportNames(
      operators: plain('operator'),
      lines: plain('line'),
      nodes: nodes,
      routes: {for (final row in aliases.reversed) row.read<String>('entity_id'): row.read('text')},
    );
  }

  String? _first(Map<String, String> texts) {
    for (final language in languages) {
      final text = texts[language];
      if (text != null) return text;
    }
    return null;
  }

  /// 위치 미확인 표식.
  Future<List<MapMarker>> mapMarkers() async {
    final rows = await _db.customSelect(
      'SELECT id, anchor_node, line_id, to_node, km, abolished, edges FROM master.map_marker',
    ).get();
    return [
      for (final row in rows)
        MapMarker(
          id: row.read('id'),
          anchorNode: row.read('anchor_node'),
          lineId: row.read('line_id'),
          toNode: row.read('to_node'),
          km: row.read<double>('km'),
          abolished: row.readNullable('abolished'),
          edges: (jsonDecode(row.read('edges')) as List<Object?>).cast<int>().toSet(),
        ),
    ];
  }

  /// 지도에 선이 하나도 없는 노선. 목록에서 `지도 미표시`로 알린다 (DESIGN §7.3).
  Future<Set<String>> unmappedLines() async {
    final rows = await _db.customSelect(
      'SELECT line_id FROM master.closed_section GROUP BY line_id HAVING max(map_visible) = 0 '
      "EXCEPT SELECT line_id FROM master.edge_attr WHERE valid_to = 'ongoing' "
      // 구간 하나만 선이 없고 나머지는 그려지는 노선은 지도에 있다
      "EXCEPT SELECT line_id FROM master.edge_attr WHERE edge_id IN (SELECT id FROM master.edge WHERE geometry_quality <> 'none')",
    ).get();
    return {for (final row in rows) row.read<String>('line_id')};
  }

  /// 역 좌표의 범위. 좌표가 없는 역은 뺀다.
  Future<({double south, double west, double north, double east})?> boundsOf(Iterable<String> nodes) async {
    final list = nodes.toSet().toList();
    if (list.isEmpty) return null;
    final marks = List.filled(list.length, '?').join(', ');
    final row = await _db.customSelect(
      'SELECT min(lat) AS s, min(lon) AS w, max(lat) AS n, max(lon) AS e '
      'FROM master.node_position WHERE node_id IN ($marks)',
      variables: [for (final id in list) Variable.withString(id)],
    ).getSingle();
    final south = row.readNullable<double>('s');
    if (south == null) return null;
    return (south: south, west: row.read<double>('w'), north: row.read<double>('n'), east: row.read<double>('e'));
  }

  /// 역 좌표. 좌표가 없는 역은 뺀다.
  Future<Map<String, (double, double)>> nodePositions(Iterable<String> nodes) async {
    final want = nodes.toSet();
    final rows = await _db.customSelect(
      'SELECT node_id, lat, lon FROM master.node_position WHERE lat IS NOT NULL',
    ).get();
    return {
      for (final row in rows)
        if (want.contains(row.read<String>('node_id')))
          row.read<String>('node_id'): (row.read<double>('lat'), row.read<double>('lon')),
    };
  }

  /// 역 묶음의 도도부현 번호. 한 묶음의 역은 모두 같은 도도부현이다.
  Future<Map<int, int>> groupPrefs(Iterable<int> groups) async {
    final want = groups.toSet();
    final rows = await _db.customSelect(
      'SELECT g.n AS n, node.pref AS pref FROM master.station_group g '
      'JOIN master.node ON node.group_id = g.id WHERE node.pref IS NOT NULL',
    ).get();
    return {
      for (final row in rows)
        if (want.contains(row.read<int>('n'))) row.read<int>('n'): row.read<int>('pref'),
    };
  }

  /// 운전 계통의 화면 이름.
  Future<Map<String, String>> serviceNames(Iterable<String> ids) async {
    final list = ids.toSet().toList();
    final grouped = await _nameRows('service', list);
    return {
      for (final id in list) id: _pick(grouped[id], languages) ?? id,
    };
  }

  /// 그날의 역 이름.
  Future<Map<String, String>> nodeNames(
    Iterable<String> ids, {
    String? lineId,
    String? date,
    List<String>? languages,
  }) async {
    final list = ids.toSet().toList();
    final grouped = await _nameRows('node', list);
    return {
      for (final id in list)
        id: _pick(grouped[id], languages ?? this.languages, lineId: lineId, date: date) ?? id,
    };
  }

  /// 기록 목록의 이름을 지금 판으로 바꾼다. 표기 정정이 옛 기록에도 보이고, 판에 없는 ID는
  /// 저장 당시 라벨로 남는다.
  Future<List<RideSummary>> currentNames(List<RideSummary> rides) async {
    final nodes = await _nameRows('node', {
      for (final ride in rides) ...[?ride.fromNode, ?ride.toNode],
    }.toList());
    final lines = await _nameRows('line', {
      for (final ride in rides) ?ride.lineId,
    }.toList());
    final services = await serviceNames([
      for (final ride in rides) ?ride.serviceId?.value,
    ]);
    return [
      for (final ride in rides)
        () {
          final raw = ride.shownDate;
          final date = ride.effectiveHi ?? (raw == null ? null : DateSpan.parse(raw).lo);
          String? node(String? id) =>
              _pick(nodes[id], languages, lineId: ride.lineId, date: date);
          return ride.named(
            line: _pick(lines[ride.lineId], languages, lineId: ride.lineId, date: date),
            from: node(ride.fromNode),
            to: node(ride.toNode),
            service: services[ride.serviceId?.value],
          );
        }(),
    ];
  }

  String? _pick(
    Map<String, List<NameRow>>? byLanguage,
    List<String> languages, {
    String? lineId,
    String? date,
  }) =>
      languages
          .map((lang) => pickName(byLanguage?[lang] ?? const [], lineId: lineId, date: date))
          .nonNulls
          .firstOrNull;

  Future<Map<String, Map<String, List<NameRow>>>> _nameRows(String type, List<String> ids) async {
    if (ids.isEmpty) return const {};
    final marks = List.filled(ids.length, '?').join(',');
    final rows = await _db.customSelect(
      'SELECT entity_id, lang, text, line_id, valid_from, valid_to FROM names.name '
      'WHERE entity_type = ? AND entity_id IN ($marks)',
      variables: [Variable.withString(type), for (final id in ids) Variable.withString(id)],
    ).get();
    final grouped = <String, Map<String, List<NameRow>>>{};
    for (final row in rows) {
      final byLanguage = grouped[row.read<String>('entity_id')] ??= {};
      (byLanguage[row.read<String>('lang')] ??= []).add(
        NameRow(
          text: row.read('text'),
          lineId: row.readNullable('line_id'),
          validFrom: row.readNullable('valid_from'),
          validTo: row.readNullable('valid_to'),
        ),
      );
    }
    return grouped;
  }

  /// 한 글자 토큰 색인. 짧은 이름이 먼저다.
  Future<List<SearchHit>> search(String text, {int limit = 60}) async {
    final query = searchQuery(text);
    if (query == null) return const [];
    final rows = await _db.customSelect(
      'SELECT entity_type, entity_id, min(length(text)) AS size FROM names.search '
      'WHERE search MATCH ? GROUP BY 1, 2 ORDER BY size LIMIT ?',
      variables: [Variable.withString(query), Variable.withInt(limit)],
    ).get();
    return [
      for (final row in rows)
        SearchHit(kind: row.read('entity_type'), id: row.read('entity_id')),
    ];
  }

  Future<List<SelectorLink>> routeLinks(String routeId) async {
    final rows = await _db.customSelect(
      'SELECT seq, kind, side, flow, at_edge, other_line_id, other_route_id, other_node, '
      'next_stop_node, terminal_node, valid_from, valid_to '
      'FROM master.route_link WHERE route_id = ? ORDER BY seq',
      variables: [Variable.withString(routeId)],
    ).get();
    return [
      for (final row in rows)
        SelectorLink(
          seq: row.read('seq'),
          kind: row.read('kind'),
          otherLineId: row.readNullable('other_line_id'),
          otherRouteId: row.readNullable('other_route_id'),
          validFromLo: _lo(row.readNullable('valid_from')),
          validToHi: _hi(row.readNullable('valid_to')),
          side: row.readNullable('side'),
          flow: row.readNullable('flow'),
          otherNode: row.readNullable('other_node'),
          nextStop: row.readNullable('next_stop_node'),
          terminal: row.readNullable('terminal_node'),
          midway: row.read<int>('at_edge') == 1,
        ),
    ];
  }

  /// 그 계통의 열람 전용 역.
  Future<List<ArchiveStop>> archiveStops(String routeId) async {
    final rows = await _db.customSelect(
      'SELECT id, after_id, before_id, closed, km FROM master.archive_stop WHERE route_id = ?',
      variables: [Variable.withString(routeId)],
    ).get();
    return [
      for (final row in rows)
        ArchiveStop(
          id: row.read('id'),
          afterNode: row.readNullable('after_id'),
          beforeNode: row.readNullable('before_id'),
          closedYear: _year(row.readNullable('closed')),
          km: row.readNullable('km'),
        ),
    ];
  }

  /// 그 역들에서 갈라지던 열람 전용 노선.
  Future<List<ArchiveBranch>> archiveBranches(Iterable<String> nodes) async {
    final list = nodes.toSet().toList();
    if (list.isEmpty) return const [];
    final marks = List.filled(list.length, '?').join(',');
    final rows = await _db.customSelect(
      'SELECT id, at_node, closed FROM master.archive_line WHERE at_node IN ($marks)',
      variables: [for (final id in list) Variable.withString(id)],
    ).get();
    return [
      for (final row in rows)
        ArchiveBranch(
          id: row.read('id'),
          atNode: row.read('at_node'),
          closedYear: _year(row.readNullable('closed')),
        ),
    ];
  }

  /// 열람 전용 항목의 이름.
  Future<Map<String, String>> archiveNames(Iterable<String> ids) async {
    final list = ids.toSet().toList();
    final grouped = await _nameRows('archive', list);
    return {for (final id in list) id: _pick(grouped[id], languages) ?? id};
  }

  String _year(String? raw) {
    if (raw == null) return '?';
    final span = DateSpan.parse(raw);
    return yearLabel(span.lo, span.hi);
  }

  String? _lo(String? raw) => raw == null ? null : DateSpan.parse(raw).lo;
  String? _hi(String? raw) => raw == null ? null : DateSpan.parse(raw).hi;
}
