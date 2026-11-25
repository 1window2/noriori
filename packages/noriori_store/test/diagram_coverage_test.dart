import 'dart:io';

import 'package:noriori_core/noriori_core.dart';
import 'package:noriori_store/noriori_store.dart';
import 'package:test/test.dart';

/// 실제 판의 모든 계통을 앱과 같은 순서(선택기 → 보이는 역 → 표시 규칙)로 그려 본다 (DESIGN §8.1).
/// 예외가 없어야 하고, 보이는 역에 달린 연결(환승·분기·끝 이어짐)은 그림 어딘가에 나와야 한다.
void main() {
  final masterFile = File('../../build/master.sqlite');
  final skip = masterFile.existsSync() ? null : '빌드가 없다';
  const today = '2026-11-02';
  const dates = <String?>[null, today, '1990-06-15', '1975-06-15', '1955-06-15'];

  test('모든 계통의 노선 그림', () async {
    final db = UserDb(openDirect(File(':memory:')));
    final dir = masterFile.absolute.parent.path;
    await db.customStatement("ATTACH 'file:$dir/master.sqlite?mode=ro&immutable=1' AS master");
    final network = Network(await NetworkReader(db).read());
    final reader = PackReader(db);
    final builder = SelectorBuilder(network);
    final rules = DisplayRules(network, today: today);
    const options = DisplayOptions();
    final errors = <String>[];
    final dropped = <String, List<String>>{};
    final shape = <String, int>{};
    void count(String key) => shape[key] = (shape[key] ?? 0) + 1;
    var drawn = 0;
    for (final routeId in network.routes.keys) {
      final links = await reader.routeLinks(routeId);
      final stops = await reader.archiveStops(routeId);
      final parallels = await reader.routeParallels(routeId);
      for (final raw in dates) {
        final date = raw == null ? null : DateSpan.parse(raw);
        try {
          final rows = builder.build(routeId, date, links: links);
          final visible = rules.visible(rows, options);
          final openGaps = builder.openBetween(routeId, visible, date);
          final sectionGaps = date == null ? builder.openBetween(routeId, visible, DateSpan.parse(today)) : openGaps;
          final branches = await reader.archiveBranches(rows.map((row) => row.node), routes: {routeId, ...builder.handRoutes(routeId)});
          final lines = rules.lines(
            lineId: network.routes[routeId]!.lineId,
            rows: visible,
            openGaps: openGaps,
            options: options,
            closedRoute: network.routes[routeId]!.closed,
            archiveStops: stops,
            archiveBranches: branches,
            sectionGaps: sectionGaps,
            undated: date == null,
            parallels: parallels,
            date: date,
            shownLineId: network.lineOnDate(routeId, date),
          );
          drawn++;
          final shown = <SelectorLink>{};
          for (final line in lines) {
            switch (line) {
              case FoldLine():
                count('접힌 줄');
              case StopLine(:final transfers, :final lanes):
                for (final mark in lanes) {
                  count('병주 ${mark.role.name}');
                }
                if (transfers.length > 1) count('번호 묶음 ${transfers.length}');
                for (final group in transfers) {
                  for (final item in group.items) {
                    shown.add(item.link);
                    shown.addAll(item.before);
                  }
                }
              case BranchLine(:final item, :final archive, :final parallel):
                if (archive == null) shown.add(item.link);
                if (parallel != null) count('병주 ${item.link.side == 'up' ? '들어옴' : '나감'}');
                shown.addAll(item.before);
                if (item.link.midway) count('역 사이 분기');
              case EndLine(:final items, :final up, :final parallel):
                if (parallel != null) count('병주 끝 이어짐 ${up ? '위' : '아래'}');
                for (final item in items) {
                  shown.add(item.link);
                  shown.addAll(item.before);
                }
                count(up ? '위 끝 이어짐' : '아래 끝 이어짐');
                if (items.length > 1) count('끝 이어짐 두 방면');
              case ArchiveLine():
                count('열람 전용 역');
              case SectionLine():
                count('폐지 구분선');
              case TransferLine():
                count('이관 구분선');
              case NoticeLine(:final kind):
                count('괄호 ${kind.name}');
            }
          }
          // 날짜를 모를 때는 그 계통의 모든 연결이 후보다. 그림에 안 나온 것을 종류별로 센다
          if (raw == null) {
            // 병주 구간 안의 역에서 상대 노선의 행은 병주 선이 대신한다
            final replaced = {
              for (final run in parallels)
                for (final row in visible)
                  if (row.seq >= run.fromSeq && row.seq <= run.toSeq) '${row.seq}\u0000${run.otherLineId}',
            };
            for (final row in visible) {
              for (final link in row.links) {
                if (shown.contains(link) || replaced.contains('${row.seq}\u0000${link.otherLineId}')) continue;
                (dropped[link.kind] ??= []).add('$routeId@${row.node}→${link.otherLineId}');
              }
            }
          }
        } catch (error) {
          errors.add('$routeId $raw $error');
        }
      }
    }
    await db.close();
    // ignore: avoid_print
    print('그림 $drawn, 예외 ${errors.length} ${errors.take(5).toList()}');
    // ignore: avoid_print
    print('모양 $shape');
    for (final entry in dropped.entries) {
      // ignore: avoid_print
      print('안 나온 ${entry.key} ${entry.value.length}: ${entry.value.take(12).toList()}');
    }
    expect(errors, isEmpty);
  }, skip: skip, timeout: const Timeout(Duration(minutes: 10)));
}
