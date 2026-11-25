import 'dart:io';

import 'package:noriori_core/noriori_core.dart';
import 'package:noriori_store/noriori_store.dart';
import 'package:test/test.dart';

/// 감사용: 같은 노선 이어 그리기(DESIGN §8.3) 화면을 앱과 같은 계산으로 글로 펼친다. 목업(tools/dev/stitch_mock.py)과 대조한다.
/// RENDER_STITCH=<출력 폴더>, RENDER_LINES=노선,노선 (없으면 계통이 둘 이상인 모든 노선), RENDER_DATES=날짜,날짜 (모름은 늘 포함)
void main() {
  final out = Platform.environment['RENDER_STITCH'];
  test('stitch dump', () async {
    final db = UserDb(openDirect(File(':memory:')));
    await db.customStatement("ATTACH 'file:${File('../../build/master.sqlite').absolute.path}?mode=ro&immutable=1' AS master");
    await db.customStatement("ATTACH 'file:${File('../../build/names.sqlite').absolute.path}?mode=ro&immutable=1' AS names");
    final network = Network(await NetworkReader(db).read());
    final reader = PackReader(db);
    final today = Platform.environment['RENDER_TODAY'] ?? '2026-11-22';
    final todaySpan = DateSpan.parse(today);
    final names = {
      for (final row in await db.customSelect("SELECT entity_id, text FROM names.name WHERE lang='ja' AND (valid_to IS NULL OR valid_to='' OR valid_to='ongoing') AND valid_from IS NULL").get())
        row.read<String>('entity_id'): row.read<String>('text'),
    };
    // 앱과 같은 이름: 그 노선·그날 이름(노선 한정 이름이 다른 노선에 새지 않게)
    var shownNames = <String, String>{};
    String nm(String? id) => id == null ? '-' : '${shownNames[id] ?? names[id] ?? id}[$id]';
    final wanted = (Platform.environment['RENDER_LINES'] ?? '').split(',').where((s) => s.isNotEmpty).toList();
    final lines = wanted.isNotEmpty
        ? wanted
        : {for (final r in network.routes.values) r.lineId}.where((l) => network.routesOfLine(l).length > 1).toList();
    final dates = [today, ...(Platform.environment['RENDER_DATES'] ?? '').split(',').where((d) => d.isNotEmpty), null];
    Directory(out!).createSync(recursive: true);
    const options = DisplayOptions();
    final rules = DisplayRules(network, today: today);
    final builder = SelectorBuilder(network);
    for (final lineId in lines) {
      final buf = StringBuffer('# $lineId\n');
      final screens = <(String, String?), RouteRows>{};
      for (final r in LineStitcher.routesFor(network, lineId)) {
        for (final d in {...dates.map((x) => x == null ? null : DateSpan.parse(x)), todaySpan}) {
          final all = builder.fillHanded(r, builder.build(r, d, links: await reader.routeLinks(r)), d,
              links: {for (final o in builder.handRoutes(r)) o: await reader.routeLinks(o)});
          final shown = rules.visible(all, options);
          screens[(r, d?.lo)] = RouteRows(
            routeId: r,
            rows: shown,
            openGaps: builder.openBetween(r, shown, d),
            sectionGaps: d == null ? builder.openBetween(r, shown, todaySpan, offSeasonOpen: true) : builder.openBetween(r, shown, d),
            sectionEnds: builder.sectionEnds(r, shown, todaySpan, date: d),
          );
        }
      }
      for (final raw in dates) {
        final date = raw == null ? null : DateSpan.parse(raw);
        final stitcher = LineStitcher(network, today: todaySpan, screen: (r, d) => screens[(r, d?.lo)]);
        final main = network.routesOfLineMainFirst(lineId).first;
        final s = stitcher.stitch(lineId, main, date);
        shownNames = await reader.nodeNames(
            {for (final r in s.main.rows) r.node, for (final f in s.folds) for (final r in f.rows.rows) r.node}.toList(),
            lineId: lineId,
            date: raw,
            languages: const ['ja']);
        final chips = [for (final r in network.routesOfLineMainFirst(lineId)) if (r != main && !s.used.contains(r)) r];
        buf.writeln('\n## 날짜 ${raw ?? '모름'} 길이 ${s.lengthKm.toStringAsFixed(1)} 칩 ${chips.join(',')}');
        List<SelectorLine> linesOf(RouteRows rr) => rules.lines(
              lineId: lineId,
              rows: rr.rows,
              openGaps: rr.openGaps,
              options: options,
              closedRoute: false,
              archiveStops: const [],
              archiveBranches: const [],
              sectionGaps: rr.sectionGaps,
              sectionEnds: rr.sectionEnds,
              undated: date == null,
              date: date,
              shownLineId: network.lineOnDate(main, date),
            );
        final all = withFolds(linesOf(s.main), [
          for (final f in s.folds) FoldLine(fold: f, at: s.main.rows.firstWhere((r) => r.seq == f.anchor), lines: foldInner(linesOf(f.frame ?? f.rows), period: f.period, edges: {f.anchor, ?f.rejoin})),
        ]);
        void dump(List<SelectorLine> ls, String pad) {
          for (final l in ls) {
            switch (l) {
              case StopLine(:final row):
                buf.writeln('$pad● ${nm(row.node)} km=${row.kmEstimated ? '${row.kmCum}?' : row.kmCum} ${row.state.name}${row.selectable ? '' : ' 못고름'}'
                    '${row.closeYear == null ? '' : ' ~${row.closeYear}'}${row.openYear == null ? '' : ' ${row.openYear}~'}${s.foreignKm.contains(row.seq) ? ' 띠km' : ''}');
              case BranchLine(:final item, :final up):
                buf.writeln('$pad  ${up ? '┌' : '└'} 분기 ${item.link.otherLineId}/${item.link.otherRouteId} 다음 ${nm(item.link.nextStop)}${item.suspended ? ' 운휴 중' : item.gone ? ' 끝남' : ''}');
              case EndLine(:final items, :final up):
                buf.writeln('$pad  ${up ? '▲' : '▼'} 끝이어짐 ${items.map((i) => '${i.link.otherLineId}/${i.link.otherRouteId}').join(' · ')}');
              case NoticeLine(:final kind, :final top, :final bottom, :final year, :final lineId):
                String a(BracketAnchor b) {
                  final hit = ls.whereType<StopLine>().where(b.matches);
                  return hit.isEmpty ? '?' : nm(hit.first.row.node);
                }
                buf.writeln('$pad  [ 괄호 ${kind.name} ${a(top)}~${a(bottom)} ${year ?? ''} ${lineId ?? ''}');
              case SectionLine(:final year, :final opens):
                buf.writeln('$pad  - - - 구분선 ${opens ?? year ?? ''}');
              case TransferLine(:final lineId, :final on):
                buf.writeln('$pad  = = = 이관 $lineId $on');
              case ArchiveLine(:final stop):
                buf.writeln('$pad  ○ 열람전용 ${stop.id}');
              case FoldLine(:final fold, :final lines):
                buf.writeln('$pad  ▸ 접힌 줄 ${fold.period} ${fold.up ? '위' : '아래'} ${fold.single ? '한역' : '${fold.count}역'}${fold.rejoin == null ? '' : ' 돌아옴'}${fold.dead ? ' 죽음' : ''}'
                    ' 칸 ${[for (var k = 0; k < fold.rows.sectionGaps.length; k++) '${fold.rows.sectionGaps[k] ? 'o' : 'x'}${fold.rows.sectionEnds[k].year ?? ''}'].join(' ')}');
                dump(lines, '$pad      ');
            }
          }
        }

        dump(all, '');
      }
      File('$out/$lineId.txt').writeAsStringSync(buf.toString());
    }
    await db.close();
  }, skip: out == null ? 'RENDER_STITCH 없음' : null, timeout: const Timeout(Duration(minutes: 60)));
}
