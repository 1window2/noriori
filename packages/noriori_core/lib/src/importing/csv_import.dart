import '../date/date_span.dart';
import '../ids.dart';
import '../name/name_lookup.dart';
import '../network/network.dart';
import '../network/route_resolver.dart';
import '../records/record.dart';
import 'noritsubushi_csv.dart';

const importSourceNoritsubushi = 'noritsubushi';

/// 못 맞춘 행의 자리표시자. 선로망에 없는 ID라 재해석이 `unknown_ref`로 둔다.
const unmatchedRef = 'unmatched';

/// 일본어 이름과 별칭에서 ID로 가는 표. 키는 [importKey]다.
final class ImportNames {
  const ImportNames({required this.routes, required this.lines, required this.nodes});

  final Map<String, Set<String>> routes;
  final Map<String, Set<String>> lines;
  final Map<String, Set<String>> nodes;
}

/// `ケ`와 `ヶ`, 전각 괄호, 띄어쓰기 차이를 없앤다.
String importKey(String name) =>
    foldSearchText(name.replaceAll('（', '(').replaceAll('）', ')')).replaceAll(' ', '');

enum MissReason { line, station, path }

sealed class RowResult {
  const RowResult();
}

/// 맞춘 행. 값은 재해석이 같은 경로를 다시 찾는 데 필요한 입력이다.
final class RowMatched extends RowResult {
  const RowMatched({
    required this.lineId,
    required this.routeId,
    required this.fromNode,
    required this.toNode,
    required this.meters,
    this.direction,
    this.asOf,
  });

  final String lineId;
  final String routeId;
  final String fromNode;
  final String toNode;
  final int meters;
  final String? direction;
  final String? asOf;
}

final class RowMissed extends RowResult {
  const RowMissed(this.reason);

  final MissReason reason;
}

/// CSV 행을 (계통, 역, 경로)로 맞춘다 (DESIGN §10.2).
final class CsvMatcher {
  CsvMatcher(this.network, this.names) : _resolver = RouteResolver(network);

  final Network network;
  final ImportNames names;
  final RouteResolver _resolver;

  RowResult match(CsvRide row) {
    final routes = _routesOf(row.line);
    if (routes.isEmpty) return const RowMissed(MissReason.line);
    final froms = names.nodes[importKey(row.from)];
    final tos = names.nodes[importKey(row.to)];
    if (froms == null || tos == null) return const RowMissed(MissReason.station);
    RowMatched? best;
    var bestGap = 0;
    for (final routeId in routes) {
      final stops = {for (final stop in network.stops(routeId)) stop.node};
      for (final from in froms.where(stops.contains)) {
        for (final to in tos.where(stops.contains)) {
          final found = _expand(routeId, from, to, row);
          if (found == null) continue;
          final gap = _gap(found.meters, row.meters);
          if (best == null || gap < bestGap) {
            best = found;
            bestGap = gap;
          }
        }
      }
    }
    return best ?? const RowMissed(MissReason.path);
  }

  /// 괄호까지 맞는 계통이 먼저다. 애칭 괄호는 노선 이름으로 내려간다. 본선이 앞선다.
  List<String> _routesOf(String line) {
    final key = importKey(line);
    final exact = names.routes[key];
    final lines = names.lines[key] ?? names.lines[importKey(_withoutParens(line))];
    final ids = {
      if (exact != null) ...exact else if (lines != null)
        for (final id in lines) ...network.routesOfLine(id),
    }.where(network.routes.containsKey).toList()
      ..sort((a, b) {
        final main = _rank(a).compareTo(_rank(b));
        return main != 0 ? main : a.compareTo(b);
      });
    return ids;
  }

  int _rank(String routeId) => network.routes[routeId]!.role == 'main' ? 0 : 1;

  String _withoutParens(String line) => line.split(RegExp('[(（]')).first;

  int _gap(int meters, int? fileMeters) => fileMeters == null ? 0 : (meters - fileMeters).abs();

  /// 묻는 대신 파일의 거리로 고른다. 순환 방향과 이설 선로는 거리가 다르다.
  RowMatched? _expand(String routeId, String from, String to, CsvRide row) {
    final date = row.dateInput == null ? null : DateSpan.parse(row.dateInput!);
    RowMatched? take(Expansion result, {String? direction, String? asOf}) => result.saved
        ? RowMatched(
            lineId: network.routes[routeId]!.lineId,
            routeId: routeId,
            fromNode: from,
            toNode: to,
            meters: result.meters ?? 0,
            direction: direction,
            asOf: asOf,
          )
        : null;
    List<RowMatched> ways() => [
          for (final direction in const [seqUp, seqDown])
            take(_resolver.record(routeId, from, to, date: date, direction: direction),
                direction: direction),
        ].nonNulls.toList();
    // 순환 계통은 방향을 안 주면 짧은 쪽이라 긴 쪽으로 탄 행이 틀린다
    if (network.routes[routeId]!.closed && row.meters != null) {
      return _closest(ways(), row.meters);
    }
    final plain = _resolver.record(routeId, from, to, date: date);
    switch (plain.reason) {
      case ExpandReason.ambiguousPath:
        return _closest(ways(), row.meters);
      case ExpandReason.relocatedParallel:
        final options = [
          for (final option in plain.options.reversed)
            take(
              _resolver.record(routeId, from, to, date: date, asOf: DateSpan.parse(option.asOf)),
              asOf: option.asOf,
            ),
        ].nonNulls.toList();
        return _closest(options, row.meters);
      default:
        return take(plain);
    }
  }

  RowMatched? _closest(List<RowMatched> options, int? fileMeters) {
    RowMatched? best;
    for (final option in options) {
      if (best == null || _gap(option.meters, fileMeters) < _gap(best.meters, fileMeters)) {
        best = option;
      }
    }
    return best;
  }
}

enum ImportState { fresh, existing, deleted }

/// 가져올 파일의 행 하나와 그 결과.
final class ImportRow {
  const ImportRow({
    required this.row,
    required this.result,
    required this.rideId,
    required this.state,
  });

  final CsvRide row;
  final RowResult result;
  final RideId rideId;
  final ImportState state;

  /// 파일의 거리와 0.1km 단위로 다른가.
  bool get kmDiffers {
    final matched = result;
    final file = row.meters;
    if (matched is! RowMatched || file == null) return false;
    return (matched.meters + 50) ~/ 100 != (file + 50) ~/ 100;
  }
}

/// 확인 화면의 내용. 아직 아무것도 쓰지 않았다.
final class ImportPlan {
  const ImportPlan({required this.rows, required this.broken});

  final List<ImportRow> rows;
  final List<String> broken;

  Iterable<ImportRow> ofState(ImportState state) => rows.where((row) => row.state == state);

  /// 못 맞춘 행. 이미 들어온 행은 다시 묻지 않는다.
  List<ImportRow> get missed => [
        for (final row in ofState(ImportState.fresh))
          if (row.result is RowMissed) row,
      ];

  List<ImportRow> get kmDiffers => [
        for (final row in rows)
          if (row.kmDiffers) row,
      ];

  /// 새로 넣는 행의 거리 합계.
  int get freshMeters => ofState(ImportState.fresh).fold(0, (sum, row) {
        final result = row.result;
        return result is RowMatched ? sum + result.meters : sum;
      });
}

/// ID의 재료. 같은 파일을 다시 넣어도 같고 일반판과 코멘트판도 같다 (DESIGN §10.2).
String csvRideKey(CsvRide row, int occurrence) => [
      importSourceNoritsubushi,
      row.company,
      row.line,
      row.from,
      row.to,
      row.dateInput ?? '',
      '$occurrence',
    ].join('\n');

/// [known]은 이미 있는 기록의 ID와 삭제 여부다. [idOf]는 재료에서 ID를 만든다.
ImportPlan planImport(
  CsvFile file,
  CsvMatcher matcher,
  Map<String, bool> known, {
  required String Function(String key) idOf,
}) {
  final seen = <String, int>{};
  final rows = <ImportRow>[];
  for (final row in file.rides) {
    final key = [row.company, row.line, row.from, row.to, row.dateInput].join('\n');
    final occurrence = seen[key] = (seen[key] ?? 0) + 1;
    final id = RideId(idOf(csvRideKey(row, occurrence)));
    rows.add(
      ImportRow(
        row: row,
        result: matcher.match(row),
        rideId: id,
        state: switch (known[id.value]) {
          null => ImportState.fresh,
          true => ImportState.deleted,
          false => ImportState.existing,
        },
      ),
    );
  }
  return ImportPlan(rows: rows, broken: file.broken);
}

/// 저장할 기록. 끝은 승하차가 아니라 통과다 (DESIGN §10.2).
Ride importedRide(
  ImportRow item, {
  required String edition,
  required int now,
  required String deviceId,
  required String lineLabel,
  required String fromLabel,
  required String toLabel,
  String? fileName,
}) {
  final result = item.result;
  final matched = result is RowMatched ? result : null;
  return Ride(
    rideId: item.rideId,
    datasetVersion: edition,
    createdAt: now,
    updatedAt: now,
    deviceId: deviceId,
    dateInput: item.row.dateInput,
    note: item.row.comment,
    fromAlighted: false,
    toAlighted: false,
    importSource: fileName == null ? importSourceNoritsubushi : '$importSourceNoritsubushi:$fileName',
    importRaw: item.row.raw,
    legs: [
      RideLeg(
        seq: 0,
        lineId: LineId(matched?.lineId ?? unmatchedRef),
        routeId: RouteId(matched?.routeId ?? unmatchedRef),
        fromNode: NodeId(matched?.fromNode ?? unmatchedRef),
        toNode: NodeId(matched?.toNode ?? unmatchedRef),
        direction: matched?.direction,
        resolveAsOf: matched?.asOf,
        lineLabel: lineLabel,
        fromLabel: fromLabel,
        toLabel: toLabel,
      ),
    ],
  );
}
