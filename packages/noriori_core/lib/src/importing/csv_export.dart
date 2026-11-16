import 'dart:convert';
import 'dart:typed_data';

import '../backup/backup_codec.dart';
import '../date/date_rules.dart';
import '../date/date_span.dart';
import '../ids.dart';
import '../network/network.dart';
import '../network/route_resolver.dart';
import '../records/record.dart';
import 'cp932.dart';
import 'noritsubushi_csv.dart';

const _compatColumns = ['会社名', '路線名', '乗車開始駅', '乗車終了駅', '乗車キロ', '乗車日'];
const _commentColumn = 'コメント';
const _noDate = '0000-00-00';

/// 전체판에는 수정 시각이 없다. 수정 내용의 복원은 JSON이 맡으므로 어떤 백업에도 진다 (DESIGN §10.2).
const _beforeAnyBackup = 0;
const _fullColumns = [
  'ride_id',
  'leg_seq',
  'type',
  'line_id',
  'route_id',
  'from_node',
  'to_node',
  'date_input',
  'resolve_as_of',
  'resolve_unknown',
  'direction',
  'from_alighted',
  'to_alighted',
  'transfer_nodes',
  'service_id',
  'node_id',
  'created_at',
  'dataset_version',
];

/// 내보내기에 쓰는 일본어 공식명 (DESIGN §10.3).
final class ExportNames {
  const ExportNames({
    required this.operators,
    required this.lines,
    required this.routes,
    required this.nodes,
  });

  final Map<String, String> operators;
  final Map<String, String> lines;

  /// 노리츠부시 방식의 괄호 노선명. 없으면 공식명이다.
  final Map<String, String> routes;
  final Map<String, String> nodes;
}

/// 호환판 한 행.
final class CompatRow {
  const CompatRow({
    required this.company,
    required this.line,
    required this.from,
    required this.to,
    required this.meters,
    required this.date,
    this.comment,
  });

  final String company;
  final String line;
  final String from;
  final String to;
  final int meters;
  final String date;
  final String? comment;
}

/// 내보낼 바이트. CP932에 없는 글자가 있으면 알리고 UTF-8로 저장한다 (DESIGN §10.3).
final class CsvBytes {
  const CsvBytes(this.bytes, {required this.fellBack});

  final Uint8List bytes;
  final bool fellBack;
}

String _cell(Object? value) {
  final text = value?.toString() ?? '';
  final quote = text.contains(RegExp('[",\n\r]'));
  return quote ? '"${text.replaceAll('"', '""')}"' : text;
}

String _line(Iterable<Object?> cells) => '${cells.map(_cell).join(',')}\n';

String _km(int meters) => (meters / 1000).toStringAsFixed(1);

final class CsvExporter {
  CsvExporter(this.network, this.names) : _resolver = RouteResolver(network);

  final Network network;
  final ExportNames names;
  final RouteResolver _resolver;

  Expansion _expand(Ride ride, RideLeg leg) {
    final raw = ride.dateInput;
    final asOf = leg.resolveAsOf;
    return _resolver.record(
      leg.routeId.value,
      leg.fromNode.value,
      leg.toNode.value,
      date: raw == null ? null : DateSpan.parse(raw),
      direction: leg.direction,
      asOf: asOf == null ? null : DateSpan.parse(asOf),
      resolveUnknown: leg.resolveUnknown,
    );
  }

  String _lineName(String lineId, String routeId) =>
      names.routes[routeId] ?? names.lines[lineId] ?? lineId;

  String _node(String id, String label) => names.nodes[id] ?? label;

  String _operatorOf(String edge, String lineId, DateSpan? date) {
    final rows = network.attrsOf(edge, lineId);
    if (rows.isEmpty) return '';
    final (attr, _) = network.attrOn(edge, lineId, date);
    return (attr ?? rows.last).operatorId;
  }

  /// 호환판은 (사업자, 노선, 계통)마다 한 행이다.
  List<CompatRow> rows(Ride ride) {
    final raw = ride.dateInput;
    final span = raw == null ? null : DateSpan.parse(raw);
    final out = <CompatRow>[];
    for (final leg in ride.legs) {
      final expansion = _expand(ride, leg);
      final day = !expansion.demoted && span != null && span.isDay ? raw! : _noDate;
      // 연도만 아는 날짜는 코멘트 끝에 원래 값을 덧붙인다
      final kept = day == _noDate && raw != null ? dateLabel(raw, decade: (year) => '$year年代') : null;
      final comment = [?ride.note, ?kept].join(' ');
      CompatRow row(String company, String lineId, String from, String to, int meters) => CompatRow(
            company: names.operators[company] ?? company,
            line: _lineName(lineId, leg.routeId.value),
            from: _node(from, leg.fromLabel),
            to: _node(to, leg.toLabel),
            meters: meters,
            date: day,
            comment: comment.isEmpty ? null : comment,
          );
      if (!expansion.saved || expansion.edges.isEmpty) {
        out.add(row('', leg.lineId.value, leg.fromNode.value, leg.toNode.value, 0));
        continue;
      }
      final lineOf = {
        for (final part in expansion.legs)
          for (final edge in part.edges) edge: part.lineId,
      };
      final nodes = expansion.nodes;
      var start = 0;
      for (var i = 0; i < expansion.edges.length; i++) {
        final edge = expansion.edges[i];
        final line = lineOf[edge] ?? leg.lineId.value;
        final company = _operatorOf(edge, line, expansion.date);
        final next = i + 1 < expansion.edges.length ? expansion.edges[i + 1] : null;
        final sameNext = next != null &&
            (lineOf[next] ?? leg.lineId.value) == line &&
            _operatorOf(next, line, expansion.date) == company;
        if (sameNext) continue;
        final meters = network.metersOf(expansion.edges.sublist(start, i + 1), lineId: line);
        // 한 바퀴처럼 노드 수가 다른 경로는 기록의 양 끝을 쓴다
        final from = start < nodes.length ? nodes[start] : leg.fromNode.value;
        final to = i + 1 < nodes.length ? nodes[i + 1] : leg.toNode.value;
        out.add(row(company, line, from, to, meters));
        start = i + 1;
      }
    }
    return out;
  }

  String compat(Iterable<Ride> rides) {
    final all = [
      for (final ride in rides)
        if (!ride.isDeleted) ...rows(ride),
    ];
    final comments = all.any((row) => row.comment != null);
    final out = StringBuffer(_line([..._compatColumns, if (comments) _commentColumn]));
    for (final row in all) {
      out.write(
        _line([
          row.company,
          row.line,
          row.from,
          row.to,
          _km(row.meters),
          row.date,
          if (comments) row.comment,
        ]),
      );
    }
    return out.toString();
  }

  /// 전체판은 leg마다 한 행이고 방문은 `type=visit` 행이다.
  String full(BackupContents contents) {
    final out = StringBuffer(_line([..._compatColumns, _commentColumn, ..._fullColumns]));
    for (final ride in contents.rides) {
      if (ride.isDeleted) continue;
      for (final leg in ride.legs) {
        final expansion = _expand(ride, leg);
        final raw = ride.dateInput;
        final day = !expansion.demoted && raw != null && DateSpan.parse(raw).isDay ? raw : _noDate;
        final edge = expansion.edges.firstOrNull;
        final company = edge == null
            ? ''
            : _operatorOf(edge, leg.lineId.value, expansion.date);
        out.write(
          _line([
            names.operators[company] ?? company,
            _lineName(leg.lineId.value, leg.routeId.value),
            _node(leg.fromNode.value, leg.fromLabel),
            _node(leg.toNode.value, leg.toLabel),
            _km(expansion.meters ?? 0),
            day,
            ride.note,
            ride.rideId.value,
            leg.seq,
            'ride',
            leg.lineId.value,
            leg.routeId.value,
            leg.fromNode.value,
            leg.toNode.value,
            raw,
            leg.resolveAsOf,
            leg.resolveUnknown,
            leg.direction,
            ride.fromAlighted,
            ride.toAlighted,
            ride.transferNodes.map((node) => node.value).join('|'),
            ride.serviceId?.value,
            null,
            ride.createdAt,
            ride.datasetVersion,
          ]),
        );
      }
    }
    for (final visit in contents.visits) {
      if (visit.isDeleted) continue;
      final raw = visit.dateInput;
      out.write(
        _line([
          '',
          '',
          _node(visit.nodeId.value, visit.nodeLabel),
          '',
          '',
          raw != null && DateSpan.parse(raw).isDay ? raw : _noDate,
          visit.note,
          visit.visitId.value,
          0,
          'visit',
          null,
          null,
          null,
          null,
          raw,
          null,
          null,
          null,
          null,
          null,
          null,
          null,
          visit.nodeId.value,
          visit.createdAt,
          null,
        ]),
      );
    }
    return out.toString();
  }
}

/// 호환판은 CP932다. 못 적는 글자가 있으면 BOM 붙은 UTF-8로 내려간다.
CsvBytes compatBytes(String text) {
  final bytes = encodeCp932(text);
  return bytes == null ? fullBytes(text, fellBack: true) : CsvBytes(bytes, fellBack: false);
}

/// 전체판은 BOM 붙은 UTF-8이다.
CsvBytes fullBytes(String text, {bool fellBack = false}) => CsvBytes(
      Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(text)]),
      fellBack: fellBack,
    );

/// noriori 전체판인가. 헤더로 구분한다 (DESIGN §10.2).
bool isFullCsv(String text) {
  final rows = csvRows(text);
  return rows.isNotEmpty && rows.first.contains('ride_id');
}

/// 전체판을 원본으로. 없는 `ride_id`만 들어오도록 병합으로 넣는다. 이름은 다시 맞추지 않는다.
BackupContents parseFullCsv(String text, {required String deviceId}) {
  final rows = csvRows(text);
  if (rows.isEmpty) throw const FormatException('빈 파일이다');
  final header = rows.first;
  final at = {for (final (index, name) in header.indexed) name: index};
  if (!at.containsKey('ride_id')) throw const FormatException('전체판이 아니다');
  String? cell(List<String> row, String name) {
    final index = at[name];
    if (index == null || index >= row.length || row[index].isEmpty) return null;
    return row[index];
  }

  final legs = <String, List<(List<String>, RideLeg)>>{};
  final visits = <Visit>[];
  for (final row in rows.skip(1)) {
    if (row.length != header.length) throw const FormatException('열 수가 다르다');
    final id = cell(row, 'ride_id') ?? (throw const FormatException('ride_id가 없다'));
    final created = int.parse(cell(row, 'created_at') ?? '0');
    if (cell(row, 'type') == 'visit') {
      visits.add(
        Visit(
          visitId: VisitId(id),
          nodeId: NodeId(cell(row, 'node_id') ?? ''),
          nodeLabel: cell(row, '乗車開始駅') ?? '',
          nodeExplicit: true,
          createdAt: created,
          updatedAt: _beforeAnyBackup,
          deviceId: deviceId,
          dateInput: fileDate(cell(row, 'date_input')),
          note: cell(row, _commentColumn),
        ),
      );
      continue;
    }
    (legs[id] ??= []).add((
      row,
      RideLeg(
        seq: int.parse(cell(row, 'leg_seq') ?? '0'),
        lineId: LineId(cell(row, 'line_id') ?? ''),
        routeId: RouteId(cell(row, 'route_id') ?? ''),
        fromNode: NodeId(cell(row, 'from_node') ?? ''),
        toNode: NodeId(cell(row, 'to_node') ?? ''),
        direction: cell(row, 'direction'),
        resolveAsOf: cell(row, 'resolve_as_of'),
        resolveUnknown: cell(row, 'resolve_unknown') == 'true',
        lineLabel: cell(row, '路線名') ?? '',
        fromLabel: cell(row, '乗車開始駅') ?? '',
        toLabel: cell(row, '乗車終了駅') ?? '',
      ),
    ));
  }
  return BackupContents(
    trips: const [],
    visits: visits,
    rides: [
      for (final MapEntry(:key, :value) in legs.entries)
        () {
          final row = value.first.$1;
          final created = int.parse(cell(row, 'created_at') ?? '0');
          final transfers = cell(row, 'transfer_nodes');
          final service = cell(row, 'service_id');
          return Ride(
            rideId: RideId(key),
            legs: [for (final (_, leg) in value) leg],
            datasetVersion: cell(row, 'dataset_version') ?? '',
            createdAt: created,
            updatedAt: _beforeAnyBackup,
            deviceId: deviceId,
            dateInput: fileDate(cell(row, 'date_input')),
            note: cell(row, _commentColumn),
            serviceId: service == null ? null : ServiceId(service),
            transferNodes: [
              if (transfers != null)
                for (final node in transfers.split('|')) NodeId(node),
            ],
            fromAlighted: cell(row, 'from_alighted') != 'false',
            toAlighted: cell(row, 'to_alighted') != 'false',
          );
        }(),
    ],
  );
}
