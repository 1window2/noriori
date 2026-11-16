import '../date/date_span.dart';
import 'network.dart';
import 'network_data.dart';

enum NewsKind { lineOpened, lineClosed, stationOpened, stationClosed }

/// 철도망에 생긴 일 하나. 변경 소식이 쓴다.
final class NewsItem {
  const NewsItem({
    required this.kind,
    required this.date,
    required this.lineId,
    this.node,
    this.meters = 0,
  });

  final NewsKind kind;
  final String date;
  final String lineId;
  final String? node;
  final int meters;

  /// 판이 바뀌어도 같은 일은 같은 키다. 본 소식을 다시 보여 주지 않는 데 쓴다.
  String get key => '${kind.name}|$lineId|${node ?? ''}|$date';
}

/// 키를 짧게 저장한다. FNV-1a 32비트다.
int newsHash(String key) {
  var hash = 0x811c9dc5;
  for (final unit in key.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return hash;
}

/// 이어진 기간을 합친 영업 기간. 운휴와 이관은 안에 든다.
final class _Span {
  _Span(this.from, this.to, this.firstLine, this.lastLine);

  final String? from;
  String? to;
  final String firstLine;
  String lastLine;
}

/// 날짜를 아는 만큼만 적는다. 범위가 한 달이면 「2024-01-XX」, 한 해면 「1973-XX-XX」 (DESIGN §8.0 날짜 꼴)
String _precise(String lo, String? hi) {
  if (hi == null || hi == lo || hi == DateSpan.maxDate) return lo;
  if (lo.substring(0, 7) == hi.substring(0, 7)) return '${lo.substring(0, 7)}-XX';
  if (lo.substring(0, 4) == hi.substring(0, 4)) return '${lo.substring(0, 4)}-XX-XX';
  return lo;
}

List<_Span> _merge(Iterable<(NetPeriod, String)> rows) {
  String key(NetPeriod period) => period.fromLo ?? '';
  final sorted = rows.toList()..sort((a, b) => key(a.$1).compareTo(key(b.$1)));
  final spans = <_Span>[];
  for (final (period, lineId) in sorted) {
    final end = period.toHi == null || period.toHi == DateSpan.maxDate ? null : period.toLo;
    final open = period.toHi == null || period.toHi == DateSpan.maxDate;
    final tail = spans.isEmpty ? null : spans.last;
    final joined = tail != null &&
        (tail.to == null || period.fromLo == null || period.fromLo!.compareTo(tail.to!) <= 0);
    if (!joined) {
      final from = period.fromLo == null ? null : _precise(period.fromLo!, period.fromHi);
      spans.add(_Span(from, end == null ? null : _precise(end, period.toHi), lineId, lineId));
      continue;
    }
    if (tail.to == null) continue;
    // 마지막 노선은 영업을 가장 늦게까지 이어 간 노선이다. 먼저 끝난 노선이 뒤에 정렬돼도 덮어쓰지 않는다 (留萌 2023 폐역이 1987 폐지 羽幌線으로 나오던 것)
    if (open) {
      tail.to = null;
      tail.lastLine = lineId;
    } else if (end != null && end.compareTo(tail.to!) > 0) {
      tail.to = _precise(end, period.toHi);
      tail.lastLine = lineId;
    }
  }
  return spans;
}

/// 오늘까지 생긴 노선과 역의 신설, 폐지. 최근 것이 먼저다.
///
/// 운휴는 폐지가 아니고, 이관으로 소속만 바뀐 역은 그대로 있는 역이다 (DESIGN §2.9).
List<NewsItem> networkNews(Network network, String today) {
  final attrs = <String, List<NetAttr>>{};
  for (final attr in network.data.attrs) {
    (attrs[attr.edgeId] ??= []).add(attr);
  }
  final lines = <String, NewsItem>{};
  void addLine(NewsKind kind, String date, String lineId, int meters) {
    final key = NewsItem(kind: kind, date: date, lineId: lineId).key;
    final held = lines[key];
    lines[key] = NewsItem(kind: kind, date: date, lineId: lineId, meters: (held?.meters ?? 0) + meters);
  }

  final lives = <String, List<NetPeriod>>{};
  for (final life in network.data.lives) {
    (lives[life.edgeId] ??= []).add(life.period);
  }
  for (final MapEntry(key: edge, value: periods) in lives.entries) {
    final held = attrs[edge];
    if (held == null || held.isEmpty) continue;
    final meters = network.edges[edge]?.meters ?? 0;
    for (final span in _merge([for (final period in periods) (period, held.first.lineId)])) {
      if (span.from case final opened?) addLine(NewsKind.lineOpened, opened, held.first.lineId, meters);
      if (span.to case final closed?) addLine(NewsKind.lineClosed, closed, held.last.lineId, meters);
    }
  }
  final stations = <String, NewsItem>{};
  void addStation(NewsKind kind, NewsKind whole, String date, String lineId, String node) {
    // 노선과 함께 생기거나 없어진 역은 노선 소식에 든다
    if (lines.containsKey(NewsItem(kind: whole, date: date, lineId: lineId).key)) return;
    final item = NewsItem(kind: kind, date: date, lineId: lineId, node: node);
    stations['${kind.name}|$node|$date'] = item;
  }

  final stops = <String, List<(NetPeriod, String)>>{};
  for (final route in network.routes.values) {
    for (final stop in network.stops(route.id)) {
      if (!stop.isStop || !network.isShown(stop.node)) continue;
      (stops[stop.node] ??= []).add((stop.period, route.lineId));
    }
  }
  for (final MapEntry(key: node, value: rows) in stops.entries) {
    for (final span in _merge(rows)) {
      if (span.from case final opened?) {
        addStation(NewsKind.stationOpened, NewsKind.lineOpened, opened, span.firstLine, node);
      }
      if (span.to case final closed?) {
        addStation(NewsKind.stationClosed, NewsKind.lineClosed, closed, span.lastLine, node);
      }
    }
  }
  return [...lines.values, ...stations.values].where((item) => item.date.compareTo(today) <= 0).toList()
    ..sort((a, b) {
      final date = b.date.compareTo(a.date);
      return date != 0 ? date : a.key.compareTo(b.key);
    });
}
