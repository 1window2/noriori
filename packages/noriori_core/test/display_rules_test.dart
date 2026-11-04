import 'package:noriori_core/noriori_core.dart';
import 'package:test/test.dart';

SelectorRow row(
  int seq,
  String node, {
  List<SelectorLink> links = const [],
  List<SelectorLink> gone = const [],
  StopState state = StopState.open,
  bool selectable = true,
  double? km,
  String? closeYear,
}) =>
    SelectorRow(
      seq: seq,
      node: node,
      state: state,
      selectable: selectable,
      isExtension: false,
      kmCum: km,
      links: links,
      goneLinks: gone,
      closeYear: closeYear,
    );

SelectorLink link(
  String kind,
  String line, {
  int seq = 1,
  String? flow,
  String? side,
  String? from,
  String? to,
  String? other,
  String? next,
  String? terminal,
  bool midway = false,
}) =>
    SelectorLink(
      seq: seq,
      kind: kind,
      otherLineId: line,
      otherRouteId: null,
      validFromLo: from,
      validToHi: to,
      flow: flow,
      side: side,
      otherNode: other,
      nextStop: next,
      terminal: terminal,
      midway: midway,
    );

Network companies() => Network(
      NetworkData(
        routes: const [],
        edges: const [],
        routeEdges: const [],
        stops: const [],
        attrs: [
          for (final (line, operator) in const [
            ('me', 'jr-east'),
            ('other-jr', 'jr-west'),
            ('private', 'keio'),
          ])
            NetAttr(
              edgeId: 'e',
              lineId: line,
              operatorId: operator,
              lineageId: line,
              carryoverGroup: line,
              period: const NetPeriod(fromLo: '1900-01-01', fromHi: '1900-01-01'),
            ),
        ],
        lives: const [],
        units: const [],
        publicNodes: const {},
        nodeGroups: const {},
        operators: const [
          NetOperator(id: 'jr-east', category: 'jr'),
          NetOperator(id: 'jr-west', category: 'jr'),
          NetOperator(id: 'keio', category: 'major'),
        ],
      ),
    );

void main() {
  final rules = DisplayRules(companies(), today: '2026-11-02');
  const all = DisplayOptions();

  List<SelectorLine> lines(
    List<SelectorRow> rows, {
    List<bool>? open,
    DisplayOptions options = all,
    List<ArchiveStop> stops = const [],
    List<ArchiveBranch> branches = const [],
    bool loop = false,
  }) =>
      rules.lines(
        lineId: 'me',
        rows: rows,
        openGaps: open ?? List.filled(rows.length - 1, true),
        options: options,
        closedRoute: loop,
        archiveStops: stops,
        archiveBranches: branches,
      );

  group('환승', () {
    test('세로선 모양이 같으면 한 점이고 번호는 묶음이 둘 이상일 때만 붙는다', () {
      final one = rules.transfers(
        row(1, 'a', links: [link('transfer', 'private', flow: 'through')]),
        'me',
        all,
      );
      expect(one.single.number, isNull);
      final three = rules.transfers(
        row(
          1,
          'a',
          links: [
            link('transfer', 'private', flow: 'down'),
            link('transfer', 'other-jr', flow: 'through'),
            link('transfer', 'x', flow: 'up'),
          ],
        ),
        'me',
        all,
      );
      expect(three.map((g) => g.flow), [TransferFlow.through, TransferFlow.up, TransferFlow.down]);
      expect(three.map((g) => g.number), [1, 2, 3]);
    });

    test('번호는 종류에 고정이고 없는 종류의 번호는 건너뛴다', () {
      List<int?> numbers(List<String?> flows) => rules
          .transfers(
            row(1, 'a', links: [
              for (final (i, flow) in flows.indexed) link('transfer', 'l$i', flow: flow),
            ]),
            'me',
            all,
          )
          .map((g) => g.number)
          .toList();
      // 지나감과 아래에서 끝남만 있으면 ①③ (DESIGN §2.9 환승 번호)
      expect(numbers(['down', 'through']), [1, 3]);
      expect(numbers(['down', 'up']), [2, 3]);
      expect(numbers(['unknown', 'up']), [2, 4]);
      expect(numbers([null, 'through', 'up', 'down']), [1, 2, 3, 4]);
      expect(numbers(['down']), [null]);
    });

    test('같은 회사 → 현행 → 폐선 순이고 JR 각사는 하나로 본다', () {
      final groups = rules.transfers(
        row(
          1,
          'a',
          links: [
            link('transfer', 'private', flow: 'through'),
            link('transfer', 'gone', flow: 'through', to: '1980-01-01'),
            link('transfer', 'other-jr', flow: 'through'),
          ],
        ),
        'me',
        all,
      );
      expect(groups.single.items.map((i) => i.link.otherLineId), ['other-jr', 'private', 'gone']);
    });

    test('같은 노선이 방향별로 두 번 있어도 한 번만 적는다', () {
      final groups = rules.transfers(
        row(
          1,
          'a',
          links: [
            link('transfer', 'private', flow: 'through', next: 'x'),
            link('transfer', 'private', flow: 'through', next: 'y'),
          ],
        ),
        'me',
        all,
      );
      expect(groups.single.items, hasLength(1));
    });

    test('이어받은 노선은 앞 노선을 이름으로만 둔다', () {
      final groups = rules.transfers(
        row(
          1,
          'a',
          links: [link('transfer', 'next', flow: 'down', from: '1987-03-15', terminal: 't')],
          gone: [link('transfer', 'old', flow: 'down', to: '1987-03-15', terminal: 't')],
        ),
        'me',
        all,
      );
      final item = groups.single.items.single;
      expect(item.link.otherLineId, 'next');
      expect(item.before.single.otherLineId, 'old');
    });

    test('그날 없던 노선은 체크박스를 끄면 빠지고 켜면 3단계다', () {
      final stop = row(1, 'a', gone: [link('transfer', 'old', flow: 'through')]);
      expect(rules.transfers(stop, 'me', const DisplayOptions(showClosed: false)), isEmpty);
      expect(rules.transfers(stop, 'me', all).single.gone, isTrue);
    });
  });

  group('줄', () {
    test('분기는 역 위아래의 독립된 줄이고 side가 비면 아래다', () {
      final out = lines([
        row(0, 'a'),
        row(1, 'b', links: [
          link('branch', 'up', side: 'up'),
          link('branch', 'plain'),
        ]),
        row(2, 'c'),
      ]);
      expect(out.map((line) => line.runtimeType), [
        StopLine,
        BranchLine,
        StopLine,
        BranchLine,
        StopLine,
      ]);
      expect((out[1] as BranchLine).up, isTrue);
      expect((out[1] as BranchLine).gap, 0);
      expect((out[3] as BranchLine).up, isFalse);
      expect((out[3] as BranchLine).gap, 1);
      expect((out[2] as StopLine).branchUp, isTrue);
      expect((out[2] as StopLine).branchDown, isTrue);
    });

    test('같은 쪽에 여럿이면 줄이 쌓인다', () {
      final out = lines([
        row(0, 'a'),
        row(1, 'b', links: [link('branch', 'x'), link('branch', 'y')]),
        row(2, 'c'),
      ]);
      final branches = out.whereType<BranchLine>().toList();
      expect(branches.map((b) => b.stacked), [true, false]);
    });

    test('줄기 끝의 이어짐은 노선마다 한 줄이고 방면을 모은다', () {
      final out = lines([
        row(0, 'a', links: [
          link('continue', 'x', seq: 0, next: 'p'),
          link('continue', 'x', seq: 0, next: 'q'),
          link('continue', 'y', seq: 0, next: 'r'),
        ]),
        row(1, 'b', links: [link('continue', 'z', next: 's')]),
      ]);
      final ends = out.whereType<EndLine>().toList();
      expect(ends, hasLength(3));
      expect(ends[0].items, hasLength(2));
      expect(ends[0].up, isTrue);
      expect(ends.last.up, isFalse);
      expect(out.first, isA<EndLine>());
      expect(out.last, isA<EndLine>());
    });

    test('역 사이 분기는 그 칸에 놓이고 역의 어깨를 만들지 않는다', () {
      final out = lines([
        row(0, 'a', links: [link('branch', 'x', seq: 0, midway: true)]),
        row(1, 'b'),
      ]);
      expect((out[0] as StopLine).branchDown, isFalse);
      expect((out[1] as BranchLine).item.link.midway, isTrue);
    });

    test('폐역은 끄면 숨고 현행 분기가 있으면 작은 노드로 남는다', () {
      final rows = [
        row(0, 'a'),
        row(1, 'x', state: StopState.closed, selectable: false),
        row(2, 'y', state: StopState.closed, selectable: false, links: [link('branch', 'l', seq: 2)]),
        row(3, 'b'),
      ];
      const off = DisplayOptions(showClosed: false);
      final visible = rules.visible(rows, off);
      expect(visible.map((r) => r.node), ['a', 'y', 'b']);
      final stop = lines(visible, options: off).whereType<StopLine>().firstWhere((s) => s.row.node == 'y');
      expect(stop.small, isTrue);
      expect(rules.visible(rows, all), hasLength(4));
    });

    test('분기선을 끄면 분기 줄이 없다', () {
      final out = lines(
        [row(0, 'a'), row(1, 'b', links: [link('branch', 'x')]), row(2, 'c')],
        options: const DisplayOptions(showBranches: false),
      );
      expect(out.whereType<BranchLine>(), isEmpty);
    });

    test('영업 구간과 폐지 구간의 경계에 구분선이 있다', () {
      final out = lines(
        [row(0, 'a'), row(1, 'b'), row(2, 'c', closeYear: '2020')],
        open: const [true, false],
      );
      final section = out.whereType<SectionLine>().single;
      expect(section.gap, 1);
      expect(section.year, '2020');
    });

    test('첫 구간부터 폐지됐으면 구분선이 첫 역 위에 한 번만 온다', () {
      final out = lines(
        [row(0, 'a', closeYear: '1989'), row(1, 'b', closeYear: '1989'), row(2, 'c', closeYear: '1989')],
        open: const [false, false],
      );
      final section = out.whereType<SectionLine>().single;
      expect(section.gap, -1);
      expect(section.year, '1989');
      expect(out.indexOf(section), lessThan(out.indexWhere((line) => line is StopLine)));
    });

    test('분기선을 끄면 그 노선이 캡슐로 온다', () {
      final out = lines(
        [row(0, 'a'), row(1, 'b', links: [link('branch', 'x')]), row(2, 'c')],
        options: const DisplayOptions(showBranches: false),
      );
      final stop = out.whereType<StopLine>().firstWhere((line) => line.row.node == 'b');
      expect(stop.transfers.single.items.single.link.otherLineId, 'x');
    });

    test('올가미의 두 번째 줄은 돌아온 역이다', () {
      final out = lines([row(0, 'a'), row(1, 'b'), row(2, 'c'), row(3, 'b')], loop: true);
      final stops = out.whereType<StopLine>().toList();
      expect(stops[1].returnsTo, isNull);
      expect(stops[3].returnsTo, 'b');
    });

    test('순환의 마지막 줄은 첫 역으로 돌아온다', () {
      final out = lines([row(0, 'a'), row(1, 'b'), row(2, 'a')], loop: true);
      expect((out.last as StopLine).returnsTo, 'a');
    });
  });

  group('열람 전용', () {
    const pier = ArchiveStop(
      id: 'pier',
      afterNode: 'z',
      beforeNode: null,
      closedYear: '1945',
      km: null,
    );

    test('끝역 뒤에 놓인다', () {
      final out = lines([row(0, 'a'), row(1, 'z')], stops: const [pier]);
      expect(out.last, isA<ArchiveLine>());
      expect((out.last as ArchiveLine).gap, 1);
    });

    test('앞 역을 모르면 뒤 역 앞에, 둘 다 모르면 km로 찾고 km순으로 놓는다', () {
      const before = ArchiveStop(
        id: 'b',
        afterNode: null,
        beforeNode: 'c',
        closedYear: '1950',
        km: 5,
      );
      const byKm = ArchiveStop(id: 'k', afterNode: null, beforeNode: null, closedYear: '1950', km: 4);
      final out = lines(
        [row(0, 'a', km: 0), row(1, 'b', km: 3), row(2, 'c', km: 9)],
        stops: const [before, byKm],
      );
      final found = out.whereType<ArchiveLine>().toList();
      expect(found.map((a) => a.stop.id), ['k', 'b']);
      expect(found.every((a) => a.gap == 1), isTrue);
    });

    test('체크박스를 끄면 숨고 폐역을 꺼도 숨는다', () {
      final rows = [row(0, 'a'), row(1, 'z')];
      expect(
        lines(rows, stops: const [pier], options: const DisplayOptions(showArchive: false))
            .whereType<ArchiveLine>(),
        isEmpty,
      );
      expect(
        lines(rows, stops: const [pier], options: const DisplayOptions(showClosed: false))
            .whereType<ArchiveLine>(),
        isEmpty,
      );
    });

    test('열람 전용 노선은 그 역의 분기 줄이다', () {
      const old = ArchiveBranch(id: 'old', atNode: 'a', closedYear: '1950');
      final out = lines([row(0, 'a'), row(1, 'b')], branches: const [old]);
      final branch = out.whereType<BranchLine>().single;
      expect(branch.archive, old);
      expect(branch.item.gone, isTrue);
      expect((out.first as StopLine).branchDown, isTrue);
    });
  });

  group('폐지 구간 표시', () {
    test('폐선과 현행 분기가 겹치면 바깥 줄로 가는 줄기는 현행색이다', () {
      final rows = [
        row(0, 'a', links: [
          link('branch', 'gone', side: 'down', to: '1990-01-01'),
          link('branch', 'open', side: 'down'),
        ]),
        row(1, 'b'),
      ];
      final branches = DisplayRules(companies(), today: '2026-01-01')
          .lines(lineId: 'l', rows: rows, openGaps: const [true], options: const DisplayOptions(showClosed: true))
          .whereType<BranchLine>()
          .toList();
      expect(branches, hasLength(2));
      final inner = branches.first;
      final outer = branches.last;
      expect(inner.stacked, isTrue);
      expect(inner.stemGone || outer.stemGone, isFalse, reason: '역에서 바깥 현행 분기까지 줄기는 현행색이다');
      expect(inner.throughGone, outer.item.gone);
    });

    final rules = DisplayRules(companies(), today: '2026-01-01');
    const options = DisplayOptions();

    test('폐지 단계마다 구분선을 두고 같은 해에 폐역된 역은 연도를 또 적지 않는다', () {
      final rows = [
        row(0, 'a'),
        row(1, 'b', closeYear: '1990', state: StopState.closed, selectable: false),
        row(2, 'c', closeYear: '1990', state: StopState.closed, selectable: false),
        row(3, 'd', closeYear: '2000', state: StopState.closed, selectable: false),
      ];
      final lines = rules.lines(
        lineId: 'l',
        rows: rows,
        openGaps: const [false, false, false],
        options: options,
      );
      expect([for (final s in lines.whereType<SectionLine>()) s.year], ['1990', '2000']);
      final stops = lines.whereType<StopLine>().toList();
      expect(stops[2].quiet, isTrue);
    });

    test('날짜를 모르면 줄기는 그대로 두고 구분선만 오늘 기준으로 그린다', () {
      final rows = [row(0, 'a'), row(1, 'b', closeYear: '1990', state: StopState.unknown)];
      final lines = rules.lines(
        lineId: 'l',
        rows: rows,
        openGaps: const [true],
        sectionGaps: const [false],
        options: options,
        undated: true,
      );
      expect(lines.whereType<SectionLine>().single.year, '1990');
    });

    test('날짜를 모르면 체크박스를 꺼도 지금 없는 노선은 숨긴다', () {
      final rows = [
        row(0, 'a', links: [link('transfer', 'l2', to: '1990-01-01')]),
        row(1, 'b'),
      ];
      final shown = rules.transfers(rows.first, 'l', const DisplayOptions(showClosed: false), undated: true);
      expect(shown, isEmpty);
      final dated = rules.transfers(rows.first, 'l', const DisplayOptions(showClosed: false));
      expect(dated, isNotEmpty, reason: '그날 있던 노선은 그대로다');
    });

    test('끝 이어짐은 뒤에 폐역이 있어도 마지막 현행 역에 붙는다', () {
      final rows = [
        row(0, 'a'),
        row(1, 'b', links: [link('continue', 'l2', seq: 1)]),
        row(2, 'c', closeYear: '1990', state: StopState.closed, selectable: false),
      ];
      final lines = rules.lines(lineId: 'l', rows: rows, openGaps: const [true, false], options: options);
      final end = lines.whereType<EndLine>().single;
      expect(end.at.node, 'b');
    });
  });
}
