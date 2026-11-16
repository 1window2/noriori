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
/// 열람 전용 항목의 자리 (검색에서 그 노선 화면으로 갈 때).
final class ArchivePlace {
  const ArchivePlace({this.routeId, this.node});

  final String? routeId;
  final String? node;
}

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
    // ゆとりーとライン 버스 구간은 이어짐 표시용이라 노선 수에 넣지 않는다 (DESIGN §8)
    final bus = await _hasTable('bus_section');
    final row = await _db.customSelect(
      'SELECT (SELECT count(*) FROM master.node_public) AS stations, '
      '(SELECT count(*) FROM master.line'
      '${bus ? ' WHERE id NOT IN (SELECT line_id FROM master.bus_section)' : ''}) AS lines',
    ).getSingle();
    return PackSummary(
      stations: row.read<int>('stations'),
      lines: row.read<int>('lines'),
    );
  }

  Future<NameBook> nameBook() async {
    final rows = await _db.customSelect(
      'SELECT entity_type, entity_id, lang, text FROM names.name '
      "WHERE entity_type IN ('line', 'route', 'operator') "
      // 지금 이름이 먼저다. 기간이 끝난 옛 이름(小本線·大阪市営地下鉄…)은 지금 이름이 없을 때만 쓴다 (감사 3회차 tohoku_2-007)
      "ORDER BY valid_to IS NOT NULL AND valid_to <> 'ongoing', valid_from IS NOT NULL",
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
      "AND entity_type IN ('route', 'line', 'node', 'service') "
      'UNION ALL SELECT entity_type, entity_id, text FROM names.alias '
      "WHERE entity_type IN ('route', 'line', 'node', 'service')",
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
      services: byKind['service'] ?? const {},
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
      (kind[row.read<String>('entity_id')] ??= []).add(_nameRow(row));
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
    // 일본어 표시 이름(広島電鉄本線)이 공식명(本線)과 다르면 공식명은 official 별칭에 있다. 내보내기는 공식명이다
    final lines = plain('line');
    for (final row in await _db
        .customSelect("SELECT entity_id, text FROM names.alias WHERE entity_type = 'line' AND kind = 'official'")
        .get()) {
      lines[row.read('entity_id')] = row.read('text');
    }
    return ExportNames(
      operators: plain('operator'),
      lines: lines,
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

  /// 운행 계통의 화면 이름.
  Future<Map<String, String>> serviceNames(Iterable<String> ids) async {
    final list = ids.toSet().toList();
    final grouped = await _nameRows('service', list);
    return {
      for (final id in list) id: _pick(grouped[id], languages) ?? id,
    };
  }

  /// 그날의 역 이름. [routeId]를 주면 그 계통 한정 이름(names.name_route, 尼崎港線의 尼崎仮乗降場)이
  /// 언어마다 노선 이름보다 먼저다.
  Future<Map<String, String>> nodeNames(
    Iterable<String> ids, {
    String? lineId,
    String? routeId,
    String? date,
    List<String>? languages,
  }) async {
    final list = ids.toSet().toList();
    final grouped = await _nameRows('node', list);
    final routed = routeId == null ? const <String, Map<String, List<NameRow>>>{} : await _routeNameRows(routeId, list);
    final langs = languages ?? this.languages;
    return {
      for (final id in list)
        id: langs
                .map((lang) =>
                    pickName(routed[id]?[lang] ?? const [], lineId: lineId, date: date) ??
                    pickName(grouped[id]?[lang] ?? const [], lineId: lineId, date: date))
                .nonNulls
                .firstOrNull ??
            id,
    };
  }

  /// 그날 일본어 역 이름의 읽기(히라가나). [nodeNames]가 고르는 일본어 행의 읽기이고, 한자가 섞인 이름만 넣는다.
  /// 읽기 근거가 없는 역(아주 옛 폐역 등)은 빠진다. 일본어판 노선 일람이 이름 옆에 단다. 지도에는 달지 않는다.
  Future<Map<String, String>> nodeReadings(
    Iterable<String> ids, {
    String? lineId,
    String? routeId,
    String? date,
  }) async {
    final list = ids.toSet().toList();
    final grouped = await _nameRows('node', list);
    final routed = routeId == null ? const <String, Map<String, List<NameRow>>>{} : await _routeNameRows(routeId, list);
    final out = <String, String>{};
    for (final id in list) {
      final row = pickNameRow(routed[id]?['ja'] ?? const [], lineId: lineId, date: date) ??
          pickNameRow(grouped[id]?['ja'] ?? const [], lineId: lineId, date: date);
      final kana = row?.kana;
      // 위키 읽기의 낱말 사이 띄어쓰기(しま いそべ)는 표지처럼 붙여 적는다
      final reading = kana?.replaceAll(RegExp(r'[\s\u3000]'), '');
      if (row != null && reading != null && reading.isNotEmpty && needsReading(row.text)) out[id] = reading;
    }
    return out;
  }

  Future<bool> _hasNamesTable(String table) async =>
      (await _db.customSelect("SELECT 1 FROM names.sqlite_master WHERE type = 'table' AND name = ?",
              variables: [Variable.withString(table)]).get())
          .isNotEmpty;

  /// 계통 한정 이름 행. 표가 없는 옛 판이면 비어 있다
  Future<Map<String, Map<String, List<NameRow>>>> _routeNameRows(String routeId, List<String> ids) async {
    if (ids.isEmpty || !await _hasNamesTable('name_route')) return const {};
    final rows = await _db.customSelect(
      'SELECT entity_id, lang, text, kana, line_id, valid_from, valid_to FROM names.name_route '
      "WHERE entity_type = 'node' AND route_id = ? AND entity_id IN (${List.filled(ids.length, '?').join(',')})",
      variables: [Variable.withString(routeId), for (final id in ids) Variable.withString(id)],
    ).get();
    final grouped = <String, Map<String, List<NameRow>>>{};
    for (final row in rows) {
      final byLanguage = grouped[row.read<String>('entity_id')] ??= {};
      (byLanguage[row.read<String>('lang')] ??= []).add(_nameRow(row));
    }
    return grouped;
  }

  /// 그 노선에서 예전에만 仮乗降場·臨時駅이었던 역 → `kari`·`rinji`. 날짜 모름 화면의 작은 표식이다.
  /// 지금도 仮·臨인 역은 이름에 표시가 붙으므로 넣지 않는다 (사용자 결정 2026-11-07). 표가 없는 옛 판이면 비어 있다
  /// [routeId]를 주면 그 계통에서만 仮·臨이던 표식(names.stop_mark_route, 尼崎港線 尼崎)도 더한다.
  Future<Map<String, String>> pastTempMarks(Iterable<String> ids, String lineId, {String? routeId}) async {
    final list = ids.toSet().toList();
    if (list.isEmpty) return const {};
    if (!await _hasNamesTable('stop_mark')) return const {};
    final marks = List.filled(list.length, '?').join(',');
    final routed = routeId != null && await _hasNamesTable('stop_mark_route');
    final rows = await _db.customSelect(
      'SELECT node_id, kind, valid_from, valid_to FROM names.stop_mark '
      'WHERE line_id = ? AND node_id IN ($marks)'
      '${routed ? ' UNION ALL SELECT node_id, kind, valid_from, valid_to FROM names.stop_mark_route '
          'WHERE route_id = ? AND node_id IN ($marks)' : ''} ORDER BY valid_from',
      variables: [
        Variable.withString(lineId),
        for (final id in list) Variable.withString(id),
        if (routed) ...[Variable.withString(routeId), for (final id in list) Variable.withString(id)],
      ],
    ).get();
    final now = <String>{};
    final last = <String, String>{};
    for (final row in rows) {
      final node = row.read<String>('node_id');
      // 끝 없는 표식은 지금도 仮·臨이다. 옛 판은 NULL, 지금 판은 ongoing으로 적는다
      final to = row.readNullable<String>('valid_to');
      if (to == null || to == 'ongoing') now.add(node);
      last[node] = row.read<String>('kind');
    }
    return {for (final MapEntry(:key, :value) in last.entries) if (!now.contains(key)) key: value};
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
      'SELECT entity_id, lang, text, kana, line_id, valid_from, valid_to FROM names.name '
      'WHERE entity_type = ? AND entity_id IN ($marks)',
      variables: [Variable.withString(type), for (final id in ids) Variable.withString(id)],
    ).get();
    final grouped = <String, Map<String, List<NameRow>>>{};
    for (final row in rows) {
      final byLanguage = grouped[row.read<String>('entity_id')] ??= {};
      (byLanguage[row.read<String>('lang')] ??= []).add(_nameRow(row));
    }
    return grouped;
  }

  NameRow _nameRow(QueryRow row) => NameRow(
        text: row.read('text'),
        lineId: row.readNullable('line_id'),
        validFrom: row.readNullable('valid_from'),
        validTo: row.readNullable('valid_to'),
        kana: row.data.containsKey('kana') ? row.readNullable('kana') : null,
      );

  /// 한 글자 토큰 색인. 짧은 이름이 먼저고, 길이가 같으면 옛 이름으로만 맞은 것이 뒤다
  /// (上野로 찾으면 上野 역이 옛 이름 上野였던 手取温泉보다 먼저).
  Future<List<SearchHit>> search(String text, {int limit = 60}) async {
    final query = searchQuery(text);
    if (query == null) return const [];
    final rows = await _db.customSelect(
      'SELECT entity_type, entity_id, min(length(text)) AS size FROM names.search '
      'WHERE search MATCH ? GROUP BY 1, 2 ORDER BY size LIMIT ?',
      variables: [Variable.withString(query), Variable.withInt(limit)],
    ).get();
    final oldOnly = await _matchedOnlyByOldName(
      foldSearchText(text.replaceAll('"', '')),
      {for (final row in rows) row.read<String>('entity_id')},
    );
    final ranked = [
      for (final (i, row) in rows.indexed)
        (row.read<int>('size'), oldOnly.contains(row.read<String>('entity_id')) ? 1 : 0, i, row),
    ]..sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : (a.$2 != b.$2 ? a.$2 - b.$2 : a.$3 - b.$3));
    return [
      for (final (_, _, _, row) in ranked)
        SearchHit(kind: row.read('entity_type'), id: row.read('entity_id')),
    ];
  }

  /// 기간이 있는 이름으로만 검색어가 들어맞는 ID. 기간 없는 이름이나 별칭으로 맞으면 넣지 않는다
  Future<Set<String>> _matchedOnlyByOldName(String folded, Set<String> ids) async {
    if (ids.isEmpty || folded.isEmpty) return const {};
    final rows = await _db.customSelect(
      'SELECT entity_id, text, kana, valid_from, valid_to FROM names.name '
      'WHERE entity_id IN (${List.filled(ids.length, '?').join(',')})',
      variables: [for (final id in ids) Variable.withString(id)],
    ).get();
    final current = <String>{};
    final old = <String>{};
    for (final row in rows) {
      final to = row.readNullable<String>('valid_to');
      final dated = row.readNullable<String>('valid_from') != null || (to != null && to != 'ongoing');
      final hit = [row.read<String>('text'), row.readNullable<String>('kana')]
          .any((x) => x != null && foldSearchText(x).contains(folded));
      if (hit) (dated ? old : current).add(row.read('entity_id'));
    }
    return old.difference(current);
  }

  Future<List<SelectorLink>> routeLinks(String routeId, {bool carryover = false}) async {
    // 승계 켬이면 국철 시대 구선로도 잇는다 (route_link_carryover, DESIGN §2.9 E). 이 표가 없는 옛 판이면 없다
    final extra = carryover && await _hasTable('route_link_carryover');
    const columns = 'seq, kind, side, flow, at_edge, other_line_id, other_route_id, other_node, '
        'next_stop_node, terminal_node, valid_from, valid_to';
    // 스위치백 직통 표식 기간(route_link_reverse). 표가 없는 옛 판이면 표식이 없다 (11회차 S3)
    final spans = <(int, String?, String?), List<ReverseSpan>>{};
    if (await _hasTable('route_link_reverse')) {
      final rows = await _db.customSelect(
        'SELECT seq, other_line_id, next_stop_node, valid_from, valid_to FROM master.route_link_reverse WHERE route_id = ?',
        variables: [Variable.withString(routeId)],
      ).get();
      for (final row in rows) {
        (spans[(row.read<int>('seq'), row.readNullable<String>('other_line_id'), row.readNullable<String>('next_stop_node'))] ??= [])
            .add(ReverseSpan(_lo(row.readNullable('valid_from')) ?? '0000-01-01', _hi(row.readNullable('valid_to')) ?? DateSpan.maxDate));
      }
    }
    final rows = await _db.customSelect(
      'SELECT $columns FROM master.route_link WHERE route_id = ?1'
      '${extra ? ' UNION ALL SELECT $columns FROM master.route_link_carryover WHERE route_id = ?1' : ''} '
      'ORDER BY seq',
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
          reverseSpans: row.read<String>('kind') != 'continue'
              ? const []
              : _overlapping(
                  spans[(row.read<int>('seq'), row.readNullable<String>('other_line_id'), row.readNullable<String>('next_stop_node'))],
                  _lo(row.readNullable('valid_from')) ?? '0000-01-01',
                  _hi(row.readNullable('valid_to')) ?? DateSpan.maxDate,
                ),
        ),
    ];
  }

  /// 이음 기간 [lo, hi)와 겹치는 표식 기간
  static List<ReverseSpan> _overlapping(List<ReverseSpan>? spans, String lo, String hi) => [
        for (final span in spans ?? const <ReverseSpan>[])
          if (span.lo.compareTo(hi) < 0 && lo.compareTo(span.hi) < 0) span,
      ];

  Future<bool> _hasTable(String name) async => (await _db.customSelect(
        "SELECT 1 FROM master.sqlite_master WHERE type = 'table' AND name = ?",
        variables: [Variable.withString(name)],
      ).get())
          .isNotEmpty;

  /// 승계 켬일 때 그 계통에서 정차역으로 보이는 국철 시대 폐역. 계통 순번 → 정차 기간 (DESIGN §2.9 E)
  Future<Map<int, NetPeriod>> carryoverStops(String routeId) async {
    if (!await _hasTable('route_stop_carryover')) return const {};
    final rows = await _db.customSelect(
      'SELECT seq, valid_from_lo, valid_from_hi, valid_to_lo, valid_to_hi FROM master.route_stop_carryover WHERE route_id = ?',
      variables: [Variable.withString(routeId)],
    ).get();
    return {
      for (final row in rows)
        row.read<int>('seq'): NetPeriod(
          fromLo: row.readNullable('valid_from_lo'),
          fromHi: row.readNullable('valid_from_hi'),
          toLo: row.readNullable('valid_to_lo'),
          toHi: row.readNullable('valid_to_hi'),
        ),
    };
  }

  /// 그 계통의 병주 토막 (DESIGN §8.1). 이 표가 없는 옛 판이면 없다.
  Future<List<ParallelRun>> routeParallels(String routeId) async {
    final has = await _db.customSelect(
      "SELECT 1 FROM master.sqlite_master WHERE type = 'table' AND name = 'route_parallel'",
    ).get();
    if (has.isEmpty) return const [];
    final rows = await _db.customSelect(
      'SELECT other_line_id, other_route_id, from_seq, to_seq, stop_seqs, in_next_stop, in_terminal, '
      'out_next_stop, out_terminal, valid_from_lo, valid_to_hi '
      'FROM master.route_parallel WHERE route_id = ? ORDER BY from_seq',
      variables: [Variable.withString(routeId)],
    ).get();
    return [
      for (final row in rows)
        ParallelRun(
          otherLineId: row.read('other_line_id'),
          otherRouteId: row.readNullable('other_route_id'),
          fromSeq: row.read('from_seq'),
          toSeq: row.read('to_seq'),
          stopSeqs: {for (final seq in jsonDecode(row.read<String>('stop_seqs')) as List) seq as int},
          inNext: row.readNullable('in_next_stop'),
          inTerminal: row.readNullable('in_terminal'),
          outNext: row.readNullable('out_next_stop'),
          outTerminal: row.readNullable('out_terminal'),
          validFromLo: row.readNullable('valid_from_lo'),
          validToHi: row.readNullable('valid_to_hi'),
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
  /// 열람 전용 항목이 놓인 자리. 역이면 그 계통과 앞 역, 노선이면 갈라지는 역이다.
  Future<Map<String, ArchivePlace>> archivePlaces(Iterable<String> ids) async {
    final list = ids.toSet().toList();
    if (list.isEmpty) return const {};
    final marks = List.filled(list.length, '?').join(',');
    final out = <String, ArchivePlace>{};
    final stops = await _db.customSelect(
      'SELECT id, route_id, after_id, before_id FROM master.archive_stop WHERE id IN ($marks)',
      variables: [for (final id in list) Variable.withString(id)],
    ).get();
    for (final row in stops) {
      out[row.read<String>('id')] = ArchivePlace(
        routeId: row.readNullable<String>('route_id'),
        node: row.readNullable<String>('after_id') ?? row.readNullable<String>('before_id'),
      );
    }
    final lines = await _db.customSelect(
      'SELECT id, at_node FROM master.archive_line WHERE id IN ($marks)',
      variables: [for (final id in list) Variable.withString(id)],
    ).get();
    for (final row in lines) {
      out[row.read<String>('id')] = ArchivePlace(node: row.readNullable<String>('at_node'));
    }
    return out;
  }

  /// [languages]를 주면 그 언어 순서로 고른다(감사 렌더는 일본어판과 같은 `['ja']`, 10회차 G1 chubu_2-011)
  Future<Map<String, String>> archiveNames(Iterable<String> ids, {List<String>? languages}) async {
    final list = ids.toSet().toList();
    final grouped = await _nameRows('archive', list);
    return {for (final id in list) id: _pick(grouped[id], languages ?? this.languages) ?? id};
  }

  String _year(String? raw) {
    if (raw == null) return '?';
    final span = DateSpan.parse(raw);
    return yearLabel(span.lo, span.hi);
  }

  String? _lo(String? raw) => raw == null ? null : DateSpan.parse(raw).lo;
  String? _hi(String? raw) => raw == null ? null : DateSpan.parse(raw).hi;
}
