import 'dart:convert';
import 'dart:io';

import 'package:noriori_core/noriori_core.dart';
import 'package:noriori_store/noriori_store.dart';
import 'package:test/test.dart';

/// 감사용: 모든 계통의 선택기 화면을 앱과 같은 계산으로 글로 펼친다. RENDER_OUT이 없으면 건너뛴다.
/// RENDER_DETAIL=1이면 연결마다 종류·기간을 함께 찍는다. RENDER_JSON=1이면 같은 화면을 `json/<계통>.json`으로도 낸다
/// (연결·환승·승계 화면 이상 전수 탐지, tools/dev/screen_check.py가 읽는다)
void main() {
  final out = Platform.environment['RENDER_OUT'];
  final detail = Platform.environment['RENDER_DETAIL'] == '1';
  final asJson = Platform.environment['RENDER_JSON'] == '1';
  final master = File('../../build/master.sqlite');
  final namesDb = File('../../build/names.sqlite');
  test('dump', () async {
    final db = UserDb(openDirect(File(':memory:')));
    await db.customStatement("ATTACH 'file:${master.absolute.path}?mode=ro&immutable=1' AS master");
    await db.customStatement("ATTACH 'file:${namesDb.absolute.path}?mode=ro&immutable=1' AS names");
    final network = Network(await NetworkReader(db).read());
    final reader = PackReader(db);
    final today = Platform.environment['RENDER_TODAY'] ?? '2026-11-07';
    final lineNames = {
      for (final row in await db
          .customSelect("SELECT entity_id, text FROM names.name WHERE entity_type='line' AND lang='ja' AND line_id IS NULL AND valid_from IS NULL AND (valid_to IS NULL OR valid_to = 'ongoing')")
          .get())
        row.read<String>('entity_id'): row.read<String>('text'),
    };
    String ln(String? id) => id == null ? '?' : '${lineNames[id] ?? id}($id)';
    final rules = DisplayRules(network, today: today);
    Directory(out!).createSync(recursive: true);
    if (asJson) Directory('$out/json').createSync(recursive: true);
    Map<String, Object?> lk(SelectorLink l) => {
          'kind': l.kind,
          'line': l.otherLineId,
          'route': l.otherRouteId,
          'node': l.otherNode,
          'next': l.nextStop,
          'terminal': l.terminal,
          'from': l.validFromLo,
          'to': l.validToHi,
          'side': l.side,
          'flow': l.flow,
          if (l.midway) 'midway': true,
        };
    Map<String, Object?> dj(DisplayLink d) => {...lk(d.link), 'gone': d.gone, if (d.suspended) 'suspended': true, 'before': [for (final b in d.before) lk(b)]};
    Map<String, Object?> rj(SelectorRow r) => {
          'seq': r.seq,
          'node': r.node,
          'state': r.state.name,
          if (r.passing) 'passing': true,
          if (r.savedAs != null) 'savedAs': r.savedAs,
          if (r.handedTo != null) 'handedTo': r.handedTo,
          if (r.handedOn != null) 'handedOn': r.handedOn,
          if (r.handedOnly) 'handedOnly': true,
          'current': r.current,
          if (r.closeYear != null) 'closeYear': r.closeYear,
        };
    // RENDER_ONLY=계통,계통 이면 그 계통만 펼친다(고친 화면만 빨리 볼 때)
    final only = (Platform.environment['RENDER_ONLY'] ?? '').split(',').where((id) => id.isNotEmpty).toSet();
    for (final routeId in network.routes.keys) {
      if (only.isNotEmpty && !only.contains(routeId)) continue;
      final route = network.routes[routeId]!;
      final buf = StringBuffer('# ${ln(route.lineId)} 계통 $routeId closed=${route.closed}\n');
      // 임시 운행만 있는 계통의 운행 토막(앱과 같은 PackReader.tempWindows). 빌드가 토막을 잃으면 화면 대조에서 드러난다
      final temp = await reader.tempWindows(routeId);
      if (temp.isNotEmpty) buf.writeln('임시 운행만: ${[for (final w in temp) '${w.from}~${w.to}'].join(', ')}');
      final screens = <Map<String, Object?>>[];
      // RENDER_DATES=1990-11-17,1950-11-17 이면 그 날짜 화면도 펼친다(오늘은 RENDER_TODAY 그대로, 기록 화면에서 날짜를 고른 것과 같다)
      final extra = (Platform.environment['RENDER_DATES'] ?? '').split(',').where((d) => d.isNotEmpty);
      for (final raw in [today, ...extra, null]) {
        final date = raw == null ? null : DateSpan.parse(raw);
        const options = DisplayOptions();
        final builder = SelectorBuilder(network);
        final rows = builder.fillHanded(
          routeId,
          builder.build(
            routeId,
            date,
            links: await reader.routeLinks(routeId, carryover: options.carryover),
            carryoverStops: options.carryover ? await reader.carryoverStops(routeId) : const {},
          ),
          date,
          links: {for (final other in builder.handRoutes(routeId)) other: await reader.routeLinks(other)},
        );
        final visible = rules.visible(rows, options);
        final openGaps = builder.openBetween(routeId, visible, date);
        final sectionGaps = date == null ? builder.openBetween(routeId, visible, DateSpan.parse(today)) : openGaps;
        final stops = await reader.archiveStops(routeId);
        final parallels = await reader.routeParallels(routeId);
        final branches = await reader.archiveBranches(rows.map((row) => row.node));
        final lines = rules.lines(
          lineId: route.lineId,
          rows: visible,
          openGaps: openGaps,
          options: options,
          closedRoute: route.closed,
          archiveStops: stops,
          archiveBranches: branches,
          sectionGaps: sectionGaps,
          sectionEnds: builder.sectionEnds(routeId, visible, DateSpan.parse(today), date: date),
          undated: date == null,
          parallels: parallels,
          date: date,
          shownLineId: network.lineOnDate(routeId, date),
        );
        // 병주 상대의 다음 역·끝 역도 이름을 불러온다 (기록 화면과 같다)
        final ids = <String>{
          for (final run in parallels) ...[?run.inNext, ?run.inTerminal, ?run.outNext, ?run.outTerminal],
          for (final row in rows) row.node,
          for (final row in rows)
            for (final link in [...row.links, ...row.goneLinks]) ...[?link.otherNode, ?link.nextStop, ?link.terminal],
        };
        final names = await reader.nodeNames(ids, lineId: route.lineId, date: date?.lo, languages: const ['ja']);
        final archive = await reader.archiveNames([for (final s in stops) s.id, for (final b in branches) b.id], languages: const ['ja']);
        String nm(String? id) => id == null ? '-' : '${names[id] ?? id}[$id]';
        // 끝난 연결 줄의 상대 역은 그 연결이 끝난 날 전날, 상대 노선의 이름이다 (기록 화면 linkNameOf와 같다, 4회차 kyushu_2-007)
        final endedNames = <String, String>{};
        for (final row in rows) {
          for (final link in [...row.links, ...row.goneLinks]) {
            final day = endedLinkNameDay(link, date);
            if (day == null) continue;
            final got = await reader.nodeNames([?link.otherNode, ?link.nextStop, ?link.terminal], lineId: link.otherLineId, date: day, languages: const ['ja']);
            for (final e in got.entries) {
              endedNames[endedLinkNameKey(e.key, link.otherLineId, day)] = e.value;
            }
          }
        }
        String lnm(SelectorLink link, String? id) {
          if (id == null) return '-';
          final day = endedLinkNameDay(link, date);
          final got = day == null ? null : endedNames[endedLinkNameKey(id, link.otherLineId, day)];
          return got == null ? nm(id) : '$got[$id]';
        }
        // 이어받기 전 노선(이관 노선 병기, DESIGN §8.1)은 앞에 「옛 노선 ~끝 › 」으로 적는다
        String dl(DisplayLink d) =>
            '${d.before.map((b) => '${ln(b.otherLineId)} ~${b.validToHi ?? '?'} › ').join()}'
            '${ln(d.link.otherLineId)}${d.link.otherNode == null ? '' : '@${lnm(d.link, d.link.otherNode)}'}'
            '${d.link.nextStop == null ? '' : ' 다음 ${lnm(d.link, d.link.nextStop)}'}${d.link.terminal == null ? '' : ' 끝 ${lnm(d.link, d.link.terminal)}'}'
            '${d.gone ? (d.suspended ? ' (운휴 중 ${d.link.validToHi ?? '?'}~)' : ' (끝남 ~${d.link.validToHi ?? '?'})') : ''}'
            '${detail ? ' {${d.link.kind} ${d.link.validFromLo ?? ''}~${d.link.validToHi ?? ''}}' : ''}';
        final jl = <Map<String, Object?>>[];
        screens.add({'date': raw, 'rows': [for (final r in rows) {...rj(r), 'links': [for (final l in r.links) lk(l)], 'goneLinks': [for (final l in r.goneLinks) lk(l)]}], 'lines': jl});
        final moved = await reader.movedNotes(rows.map((row) => row.node), lineId: route.lineId, date: date?.lo);
        buf.writeln('\n## 날짜 ${raw ?? '모름'} (행 ${rows.length}, 보이는 행 ${visible.length})');
        for (final line in lines) {
          switch (line) {
            case final StopLine s:
              final r = s.row;
              buf.writeln('● ${nm(r.node)} km=${r.kmEstimated ? '?' : r.kmCum?.toStringAsFixed(1)} 상태=${r.state.name}'
                  '${r.selectable ? '' : ' 못고름'}${r.openYear == null ? '' : ' 개업${r.openYear}'}${r.closeYear == null ? '' : ' 폐역${r.closeYear}'}'
                  '${r.savedAs == null ? '' : ' 저장=${ln(r.savedAs)}'}${r.handedOnly ? ' 이관뒤역' : ''}${s.small ? ' 작음' : ''}${s.returnsTo == null ? '' : ' 돌아옴'}');
              // 이름까지 바뀐 옛 자리의 이전 표시(앱과 같은 PackReader.movedNotes)
              if (moved[r.node] case final mv?) buf.writeln('    이전: ${mv.year} → ${mv.name}');
              jl.add({'t': 'stop', ...rj(r), 'transfers': [for (final g in s.transfers) {'flow': g.flow.name, 'items': [for (final i in g.items) dj(i)]}]});
              for (final g in s.transfers) {
                buf.writeln('    환승${g.number == null ? '' : '#${g.number}'}(${g.flow.name}): ${g.items.map(dl).join(' · ')}');
              }
            case final BranchLine b:
              jl.add({'t': 'branch', 'at': b.at.node, 'atSeq': b.at.seq, 'up': b.up, if (b.archive != null) 'archive': b.archive!.id else 'item': dj(b.item)});
              buf.writeln('  ${b.up ? '┌' : '└'} 분기${b.parallel == null ? '' : '(병주)'} ${b.archive == null ? dl(b.item) : '열람전용 ${archive[b.archive!.id] ?? b.archive!.id} ~${b.archive!.closedYear}'}');
            case final EndLine e:
              jl.add({'t': 'end', 'at': e.at.node, 'atSeq': e.at.seq, 'up': e.up, 'items': [for (final i in e.items) dj(i)]});
              buf.writeln('  ${e.up ? '▲' : '▼'} 끝이어짐${e.parallel == null ? '' : '(병주)'} ${e.items.map(dl).join(' · ')}');
            case final SectionLine sec:
              jl.add({'t': 'section', 'gap': sec.gap, 'year': sec.year, 'suspended': sec.suspended, if (sec.opens != null) 'opens': sec.opens});
              buf.writeln('  - - - 구분선${sec.suspended ? ' 운휴 중' : sec.opens != null ? ' ${sec.opens} 개업' : sec.year == null ? '' : ' ~${sec.year} 폐지'}');
            case final TransferLine h:
              jl.add({'t': 'hand', 'line': h.lineId, 'on': h.on, 'at': h.at.node, 'atSeq': h.at.seq, 'whole': h.whole, 'back': h.back, 'closedYear': h.closedYear});
              buf.writeln('  = = = 이관${h.whole ? '(노선 전체)' : ''}${h.back ? ' 돌아옴' : ''} ${ln(h.lineId)} ${h.on}${h.closedYear == null ? '' : ' +~${h.closedYear} 폐지'}');
            case final NoticeLine n:
              String anchor(BracketAnchor b) => switch (lines.firstWhere(b.matches, orElse: () => n)) {
                    StopLine(:final row) => row.node,
                    ArchiveLine(:final stop) => stop.id,
                    _ => '?',
                  };
              jl.add({'t': 'notice', 'kind': n.kind.name, 'top': anchor(n.top), 'bottom': anchor(n.bottom), 'year': n.year, 'line': n.lineId, 'on': n.on});
              buf.writeln('  [ 괄호 ${n.kind.name} ${anchor(n.top)}~${anchor(n.bottom)}${n.year == null ? '' : ' ${n.year}'}${n.lineId == null ? '' : ' ${ln(n.lineId!)} ${n.on}'}');
            case FoldLine():
              break; // 계통 하나씩 펼치는 감사 화면에는 접힌 줄이 없다 (이어 그린 줄은 RENDER_STITCH)
            case final ArchiveLine a:
              jl.add({'t': 'archive', 'id': a.stop.id, 'gap': a.gap});
              buf.writeln('  ○ 열람전용역 ${archive[a.stop.id] ?? a.stop.id} ~${a.stop.closedYear} km=${a.stop.km}');
          }
        }
      }
      File('$out/$routeId.txt').writeAsStringSync(buf.toString());
      if (asJson) {
        File('$out/json/$routeId.json').writeAsStringSync(jsonEncode({
          'route': routeId,
          'line': route.lineId,
          'closed': route.closed,
          'screens': screens,
        }));
      }
    }
    await db.close();
  }, skip: out == null ? 'RENDER_OUT 없음' : null, timeout: const Timeout(Duration(minutes: 30)));
}
