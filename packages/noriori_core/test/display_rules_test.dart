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
  String? savedAs,
  String? handedTo,
  String? handedOn,
  String? closedOn,
  bool handedEnded = false,
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
      savedAs: savedAs,
      handedTo: handedTo,
      handedOn: handedOn,
      closedOn: closedOn ?? handedOn,
      handedEnded: handedEnded,
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

    test('같은 노선이 모두 끝났으면 가장 늦게 끝난 연결을 남긴다 (枝光線 枝光駅前)', () {
      final groups = rules.transfers(
        row(1, 'a', gone: [
          link('transfer', 'private', flow: 'up', to: '1966-10-01', next: 'old'),
          link('transfer', 'private', flow: 'through', from: '1966-10-01', to: '1985-10-20'),
        ]),
        'me',
        all,
      );
      expect(groups.single.items.single.link.validToHi, '1985-10-20');
    });

    test('기록 하한 전에 끝난 연결은 옛 노선도 표시를 켰을 때만 흐리게 보인다 (감사 3회차 hokkaido_1-007)', () {
      final stop = row(1, 'a', links: [link('transfer', 'private', flow: 'through', to: '1944-10-16')]);
      expect(rules.transfers(stop, 'me', const DisplayOptions(showArchive: false)), isEmpty);
      expect(rules.transfers(stop, 'me', all).single.items.single.gone, isTrue);
    });

    test('지금 선로로 이어진 노선의 옛 환승은 끝난 환승으로 적지 않는다 (감사 3회차 kinki_1-07)', () {
      final groups = rules.transfers(
        row(
          1,
          'a',
          links: [link('continue', 'private', next: 'b'), link('transfer', 'x', flow: 'through')],
          gone: [link('transfer', 'private', flow: 'through', to: '1986-11-01')],
        ),
        'me',
        all,
      );
      expect([for (final group in groups) for (final item in group.items) item.link.otherLineId], ['x']);
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

    test('앞 노선 연결이 운휴로 기간만 나뉘었어도 앞 노선 이름 하나로 묶는다 (十和田観光電鉄線 三沢)', () {
      final groups = rules.transfers(
        row(
          1,
          'a',
          links: [link('transfer', 'next', flow: 'down', from: '2010-12-04', terminal: 't')],
          gone: [
            link('transfer', 'old', flow: 'down', from: '1968-07-01', to: '2010-12-04', terminal: 't'),
            link('transfer', 'old', flow: 'down', to: '1968-05-16', terminal: 't'),
          ],
        ),
        'me',
        all,
      );
      final item = groups.single.items.single;
      expect(item.link.otherLineId, 'next');
      expect(item.before.map((link) => link.otherLineId), ['old']);
    });

    test('같은 노선이 다음 역만 바뀌어 기간이 나뉜 환승은 한 줄이다 (近鉄志摩線 鳥羽의 参宮線)', () {
      final groups = rules.transfers(
        row(
          1,
          'a',
          links: [link('transfer', 'jr', flow: 'up', from: '2020-03-14', next: 'm', terminal: 't')],
          gone: [
            link('transfer', 'jr', flow: 'up', from: '1989-07-16', to: '2020-03-14', next: 'i', terminal: 't'),
            link('transfer', 'jr', flow: 'up', from: '1970-03-01', to: '1989-07-16', next: 'm', terminal: 't'),
          ],
        ),
        'me',
        all,
      );
      final item = groups.single.items.single;
      expect(item.link.validFromLo, '2020-03-14');
      expect(item.before, isEmpty);
    });

    test('같은 사슬이 아닌 노선은 끝 역이 같아도 앞 노선으로 묶지 않는다 (札幌市電 西4丁目線 › 地下鉄南北線, 長野 信越本線 › 北陸新幹線)', () {
      final groups = rules.transfers(
        row(
          1,
          'a',
          links: [link('transfer', 'private', flow: 'through', from: '2015-03-14')],
          gone: [link('transfer', 'other-jr', flow: 'through', to: '2015-03-14')],
        ),
        'me',
        all,
      );
      final items = [for (final g in groups) ...g.items];
      expect([for (final i in items) i.link.otherLineId]..sort(), ['other-jr', 'private']);
      expect(items.every((i) => i.before.isEmpty), isTrue);
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

    test('같은 상대의 같은 쪽 분기가 기간만 나뉘었으면 한 줄이다 (감사 3회차 kanto_1-002)', () {
      final out = lines([
        row(0, 'a'),
        row(1, 'b', links: [
          link('branch', 'x', side: 'up', to: '1963-12-01', terminal: 'old'),
          link('branch', 'x', side: 'up', from: '1963-12-01', terminal: 'new'),
        ]),
        row(2, 'c'),
      ]);
      final branches = out.whereType<BranchLine>().toList();
      expect(branches, hasLength(1));
      expect(branches.single.item.link.terminal, 'new');
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

    test('이설로 폐지된 구간이 지금 역에서 끝나면 끝 구분선은 그 역 위에 온다', () {
      // 駒ヶ嶺 · 新地 · 新地(旧) · 山下(旧) · 山下 · 浜吉田
      final out = lines(
        [row(0, 'z'), row(1, 'a'), row(2, 'a_old', closeYear: '2016'), row(3, 'b_old', closeYear: '2016'), row(4, 'b'), row(5, 'c')],
        open: const [true, false, false, false, true],
      );
      final sections = out.whereType<SectionLine>().toList();
      expect([for (final s in sections) s.gap], [1, 3]);
      expect(sections.last.year, isNull);
      final b = out.indexWhere((line) => line is StopLine && line.row.node == 'b');
      expect(out.indexOf(sections.last), lessThan(b));
    });

    test('없어진 역에서 끝나는 폐지 구간은 그 역 아래에서 닫는다', () {
      final out = lines(
        [row(0, 'z'), row(1, 'a'), row(2, 'b', closeYear: '2020'), row(3, 'c')],
        open: const [true, false, true],
      );
      expect([for (final s in out.whereType<SectionLine>()) s.gap], [1, 2]);
    });

    test('지금 역 사이 한 칸만 운휴면 구분선은 그 칸에 하나다', () {
      final out = lines(
        [row(0, 'z'), row(1, 'a'), row(2, 'b'), row(3, 'c')],
        open: const [true, false, true],
      );
      expect([for (final s in out.whereType<SectionLine>()) s.gap], [1]);
    });

    test('지금 역인 첫 역은 폐지 구간 밖에 두고, 맨 끝 역 위에는 경계가 없어 구분선을 두지 않는다', () {
      final out = lines(
        [row(0, 'a'), row(1, 'b', closeYear: '2016'), row(2, 'c', closeYear: '2016'), row(3, 'd')],
        open: const [false, false, false],
      );
      final sections = out.whereType<SectionLine>().toList();
      expect([for (final s in sections) s.gap], [0]);
      expect(sections.first.year, '2016');
    });

    test('이어받은 노선도 떠난 끝 역은 지금 역이 아니라 끝 구분선을 따로 두지 않는다 (神岡線 神岡)', () {
      SelectorRow handed(int seq, String node, {bool ended = true}) => row(seq, node,
          closeYear: '1984', handedTo: 'x', handedOn: '1984-10-01', handedEnded: ended, state: StopState.closed, selectable: false);
      final gone = lines([handed(0, 'a'), handed(1, 'b'), handed(2, 'c')], open: const [false, false]);
      expect([for (final s in gone.whereType<SectionLine>()) s.gap], [-1]);
      // 이어받은 노선이 아직 서는 역도 계통 맨 끝이면 그 아래 구간이 없어 끝 구분선을 두지 않는다 (信越本線 横川–軽井沢를 끝에서 자른 꼴)
      final kept = lines([row(0, 'a', closeYear: '1997', state: StopState.closed), handed(1, 'b', ended: false)], open: const [false]);
      expect([for (final s in kept.whereType<SectionLine>()) s.gap], [-1]);
    });

    test('맨 끝 역의 직통은 그 역이 폐역이어도 끝 이어짐이다 (信越本線 新潟（旧）)', () {
      final out = lines(
        [row(0, 'old', closeYear: '1958', links: [link('continue', 'x', seq: 0)]), row(1, 'b'), row(2, 'c')],
        open: const [false, true],
      );
      expect(out.whereType<EndLine>().single.at.node, 'old');
      expect(out.whereType<BranchLine>(), isEmpty);
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

    test('첫 구간 폐지 구분선은 첫 역의 끝 이어짐 줄 바깥에 온다 (肥前吉井)', () {
      final out = lines(
        [
          row(0, 'a', closeYear: '1971', links: [link('continue', 'x', seq: 0, next: 'p')]),
          row(1, 'b', closeYear: '1971'),
        ],
        open: const [false],
      );
      final section = out.indexWhere((line) => line is SectionLine);
      final end = out.indexWhere((line) => line is EndLine);
      final stop = out.indexWhere((line) => line is StopLine);
      expect(section, lessThan(end));
      expect(end + 1, stop);
    });

    test('어느 구분선도 역과 그 역의 끝 이어짐 사이에 끼지 않는다', () {
      final out = lines(
        [
          row(0, 'a', closeYear: '1980'),
          row(1, 'b', links: [link('continue', 'x', seq: 1, next: 'p')]),
          row(2, 'c'),
        ],
        open: const [false, true],
      );
      final end = out.indexWhere((line) => line is EndLine && line.up);
      final stop = out.indexWhere((line) => line is StopLine && line.row.node == 'b');
      expect(end + 1, stop);
      expect(out.sublist(0, end).whereType<SectionLine>(), isNotEmpty);
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

    test('끝역 뒤에 놓이고, 한 역뿐이면 구분선을 두지 않는다', () {
      final out = lines([row(0, 'a'), row(1, 'z')], stops: const [pier]);
      expect(out.last, isA<ArchiveLine>());
      expect((out.last as ArchiveLine).gap, 1);
      expect(out.whereType<SectionLine>(), isEmpty);
    });

    test('끝역 뒤 여러 역 묶음은 끝 역 바로 아래에 폐지 해 구분선이 선다', () {
      final out = lines([row(0, 'a'), row(1, 'z')], stops: const [
        pier,
        ArchiveStop(id: 'pier2', afterNode: 'pier', beforeNode: null, closedYear: '1950', km: null),
      ]);
      expect(out.last, isA<ArchiveLine>());
      final at = out.indexWhere((l) => l is ArchiveLine);
      expect(out[at - 1], isA<SectionLine>().having((l) => l.year, 'year', '1950'));
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

    test('끝에 분기와 끝 이어짐이 함께 있으면 분기 줄을 줄기 점선이 곧게 지나간다 (倶利伽羅)', () {
      final rows = [
        row(0, 'a'),
        row(1, 'b', links: [
          link('branch', 'l_old', seq: 1, side: 'down', to: '2015-03-14'),
          link('continue', 'l_next', seq: 1, side: 'down'),
        ]),
      ];
      final lines = rules.lines(lineId: 'l', rows: rows, openGaps: const [true], options: options, undated: true);
      final branch = lines.whereType<BranchLine>().single;
      expect(branch.endThrough, isFalse, reason: '이어짐이 현행이라 점선은 현행색');
      final end = lines.whereType<EndLine>().single;
      expect(lines.indexOf(branch), lessThan(lines.indexOf(end)));
    });

    test('끝이던 때의 이어짐과 뒤의 분기가 같은 노선·같은 쪽이면 한 줄이다 (青い森鉄道 八戸의 八戸線)', () {
      final rows = [
        row(0, 'a'),
        row(1, 'b', links: [link('branch', 'l2', seq: 1, side: 'down', from: '2010-12-04')], gone: [
          link('continue', 'l2', seq: 1, side: 'down', from: '2002-12-01', to: '2010-12-04'),
          link('continue', 'l3', seq: 1, from: '2002-12-01', to: '2010-12-04'),
        ]),
        row(2, 'c'),
      ];
      final lines = rules.lines(lineId: 'l', rows: rows, openGaps: const [true, true], options: options, date: DateSpan.parse('2026-01-01'));
      expect([for (final b in lines.whereType<BranchLine>()) (b.item.link.otherLineId, b.item.link.kind)], [('l2', 'branch'), ('l3', 'continue')]);
    });

    test('끝 역의 옛 분기와 뒤의 끝 이어짐이 같은 노선·같은 쪽이면 끝 이어짐 하나다 (播但線 姫路의 山陽本線)', () {
      final rows = [
        row(0, 'a', links: [link('continue', 'l2', seq: 0, from: '1986-11-01')], gone: [
          link('branch', 'l2', seq: 0, side: 'up', to: '1986-11-01'),
        ]),
        row(1, 'b'),
      ];
      final lines = rules.lines(lineId: 'l', rows: rows, openGaps: const [true], options: options, undated: true);
      expect(lines.whereType<BranchLine>(), isEmpty);
      expect(lines.whereType<EndLine>().single.items.single.link.kind, 'continue');
    });

    test('끝 역의 분기와 끝 이어짐이 다른 쪽이면 둘 다 남는다 (弥彦線 東三条)', () {
      final rows = [
        row(0, 'a'),
        row(1, 'b', links: [link('continue', 'l2', seq: 1, from: '1985-04-01')], gone: [
          link('branch', 'l2', seq: 1, side: 'up', to: '1985-04-01'),
        ]),
      ];
      final lines = rules.lines(lineId: 'l', rows: rows, openGaps: const [true], options: options, undated: true);
      expect(lines.whereType<BranchLine>().single.up, isTrue);
      expect(lines.whereType<EndLine>().single.up, isFalse);
    });

    test('같은 끝의 끝 이어짐 여럿은 한 묶음이고 역에 가까운 줄이 stackAt 0이다 (A안)', () {
      final rows = [
        row(0, 'a', links: [link('continue', 'l2', seq: 0, side: 'up'), link('continue', 'l3', seq: 0, side: 'up')]),
        row(1, 'b', links: [link('continue', 'l4', seq: 1, side: 'down'), link('continue', 'l5', seq: 1, side: 'down')]),
      ];
      final lines = rules.lines(lineId: 'l', rows: rows, openGaps: const [true], options: options);
      final ends = lines.whereType<EndLine>().toList();
      expect([for (final e in ends) (e.up, e.stackAt, e.stackOf)], [(true, 1, 2), (true, 0, 2), (false, 0, 2), (false, 1, 2)]);
    });

    test('이관 구간이 이어지면 앞 역의 이어짐은 분기이고, 이어받은 노선으로 가는 줄은 없다 (敦賀)', () {
      final rows = [
        row(0, 'a'),
        row(1, 'b', links: [link('continue', 'l2', seq: 1, side: 'down'), link('continue', 'l_x', seq: 1, side: 'down')]),
        row(2, 'c', closeYear: '2024', savedAs: 'l_x', handedTo: 'l_x', handedOn: '2024-03-16'),
      ];
      final lines = rules.lines(lineId: 'l', rows: rows, openGaps: const [true, true], options: options);
      expect(lines.whereType<EndLine>(), isEmpty);
      expect([for (final b in lines.whereType<BranchLine>()) b.item.link.otherLineId], ['l2']);
      expect(lines.whereType<TransferLine>().single.lineId, 'l_x');
    });

    // 날짜를 고른 화면도 그날의 끝 역이 기준이다. 끝 역 너머 구간이 보여도 직통은 분기가 아니라 끝 이어짐(어깨로 비켜 곧게)이다.
    // 예전에는 날짜 화면이 오늘 기준 끝 역을 써서 분기로 그렸다(名鉄岐阜市内線 1990 徹明町의 美濃町線, 사용자 규칙 2026-11-18)
    test('시기별 끝 역의 직통은 뒤 구간이 보여도 숨어도 끝 이어짐이다 (金沢 2015–2024)', () {
      final rows = [
        row(0, 'a'),
        row(1, 'b', closeYear: '2024', handedTo: 'l_x', handedOn: '2024-03-16', links: [
          link('continue', 'l_x', seq: 1, side: 'down', from: '2015-03-14', to: '2024-03-16'),
        ]),
        row(2, 'c', closeYear: '2015', state: StopState.closed, selectable: false, handedTo: 'l_y', handedOn: '2015-03-14'),
      ];
      final date = DateSpan.parse('2020-01-01');
      final shown = rules.lines(lineId: 'l', rows: rows, openGaps: const [true, false], options: options, date: date);
      expect(shown.whereType<BranchLine>(), isEmpty);
      expect([for (final e in shown.whereType<EndLine>()) (e.at.node, e.up)], [('b', false)]);
      const hide = DisplayOptions(showClosed: false);
      final kept = rules.visible(rows, hide);
      expect([for (final r in kept) r.node], ['a', 'b']);
      final hidden = rules.lines(lineId: 'l', rows: kept, openGaps: const [true], options: hide, date: date);
      expect(hidden.whereType<BranchLine>(), isEmpty);
      expect(hidden.whereType<EndLine>().single.at.node, 'b');
    });

    test('이관 구간 경계 역은 이어받은 노선을 환승 캡슐로 다시 적지 않는다 (長野)', () {
      final rows = [
        row(0, 'a'),
        row(1, 'b', links: [link('transfer', 'l_x', seq: 1), link('transfer', 'l_y', seq: 1)]),
        row(2, 'c', closeYear: '2015', savedAs: 'l_x', handedTo: 'l_x', handedOn: '2015-03-14'),
      ];
      final lines = rules.lines(lineId: 'l', rows: rows, openGaps: const [true, true], options: options);
      final b = lines.whereType<StopLine>().firstWhere((line) => line.row.node == 'b');
      expect([for (final g in b.transfers) for (final i in g.items) i.link.otherLineId], ['l_y']);
    });
  });

  group('병주 (DESIGN §8.1)', () {
    List<SelectorLine> run(List<SelectorRow> rows, List<ParallelRun> runs, {DateSpan? date}) => rules.lines(
          lineId: 'me',
          rows: rows,
          openGaps: List.filled(rows.length - 1, true),
          options: all,
          parallels: runs,
          date: date,
        );

    test('중간에서 들어와 나가면 위·아래 분기 줄이고, 그 구간의 환승 캡슐에서 상대가 빠진다', () {
      final rows = [
        row(0, 'a'),
        row(1, 'b', links: [link('transfer', 'private', seq: 1, flow: 'through')]),
        row(2, 'c', links: [link('transfer', 'private', seq: 2, flow: 'through')]),
        row(3, 'd'),
      ];
      final out = run(rows, const [
        ParallelRun(otherLineId: 'private', fromSeq: 1, toSeq: 2, stopSeqs: {1, 2}, inNext: 'x', outNext: 'y'),
      ]);
      final stops = out.whereType<StopLine>().toList();
      expect(stops[1].transfers, isEmpty);
      expect(stops[2].transfers, isEmpty);
      final par = out.whereType<BranchLine>().where((line) => line.parallel != null).toList();
      expect(par.map((line) => line.up), [true, false]);
      expect(par.map((line) => line.item.link.nextStop), ['x', 'y']);
      expect(stops[1].lanes.single.role, LaneRole.stop);
      expect(stops[2].lanes.single.role, LaneRole.stop);
      expect(stops[0].lanes, isEmpty);
      expect(stops[3].lanes, isEmpty);
    });

    test('상대의 기점·종점이면 역 노드에서 나오고 들어간다', () {
      final rows = [row(0, 'a'), row(1, 'b'), row(2, 'c'), row(3, 'd')];
      final out = run(rows, const [ParallelRun(otherLineId: 'private', fromSeq: 1, toSeq: 2)]);
      final stops = out.whereType<StopLine>().toList();
      expect(stops[1].lanes.single.role, LaneRole.startNode);
      expect(stops[2].lanes.single.role, LaneRole.endNode);
      expect(out.whereType<BranchLine>(), isEmpty);
    });

    test('끝 너머에서 들어오면 끝 이어짐 줄이고, 직통 이어짐은 그 바깥에 그대로 남는다 (B′, 끝 줄 3안)', () {
      final rows = [
        row(0, 'a', links: [
          link('continue', 'other-jr', seq: 0, next: 'z'),
          link('continue', 'private', seq: 0, next: 'x'),
        ]),
        row(1, 'b'),
        row(2, 'c'),
      ];
      final out = run(rows, const [
        ParallelRun(otherLineId: 'private', fromSeq: 0, toSeq: 1, inNext: 'x', outNext: 'y'),
      ]);
      final ends = out.whereType<EndLine>().toList();
      expect(ends.map((line) => line.items.single.link.otherLineId), ['other-jr', 'private']);
      expect(ends.last.parallel, 0);
      expect(ends.last.trunkThrough, isTrue);
      expect(out.indexOf(ends.last), lessThan(out.indexWhere((line) => line is StopLine)));
    });

    test('그날 없던 토막은 그리지 않고 상대는 환승으로 남는다', () {
      final rows = [
        row(0, 'a', links: [link('transfer', 'private', seq: 0, flow: 'through')]),
        row(1, 'b', links: [link('transfer', 'private', seq: 1, flow: 'through')]),
      ];
      final out = run(
        rows,
        const [ParallelRun(otherLineId: 'private', fromSeq: 0, toSeq: 1, validFromLo: '2010-01-01')],
        date: DateSpan.parse('2000-06-01'),
      );
      expect(out.whereType<StopLine>().every((line) => line.lanes.isEmpty), isTrue);
      expect(out.whereType<StopLine>().first.transfers, isNotEmpty);
    });

    test('그날 이미 끝난 토막은 흐린 병주 선이고, 그 칸 연결이 더 늦게 끝나면 그 연결이 남는다 (北5条線, 西野田線)', () {
      List<SelectorRow> rows(String to) => [
            row(0, 'a', gone: [link('transfer', 'private', seq: 0, flow: 'through', to: to)]),
            row(1, 'b', gone: [link('transfer', 'private', seq: 1, flow: 'through', to: to)]),
          ];
      const runs = [ParallelRun(otherLineId: 'private', fromSeq: 0, toSeq: 1, validToHi: '1971-10-01')];
      final date = DateSpan.parse('2026-11-02');
      final drawn = run(rows('1971-10-01'), runs, date: date);
      expect(drawn.whereType<StopLine>().expand((line) => line.lanes).every((mark) => mark.gone), isTrue);
      expect(drawn.whereType<StopLine>().first.lanes, isNotEmpty);
      expect(drawn.whereType<StopLine>().every((line) => line.transfers.isEmpty), isTrue);
      final later = run(rows('1990-01-01'), runs, date: date);
      expect(later.whereType<StopLine>().every((line) => line.lanes.isEmpty), isTrue);
      expect(later.whereType<StopLine>().first.transfers, isNotEmpty);
    });

    test('겹치는 두 토막은 다른 자리에 선다', () {
      final rows = [row(0, 'a'), row(1, 'b'), row(2, 'c'), row(3, 'd')];
      final out = run(rows, const [
        ParallelRun(otherLineId: 'private', fromSeq: 0, toSeq: 2),
        ParallelRun(otherLineId: 'other-jr', fromSeq: 1, toSeq: 3),
      ]);
      final middle = out.whereType<StopLine>().toList()[2];
      expect(middle.lanes.map((mark) => mark.lane).toSet(), {0, 1});
    });
  });

  group('이관 구간 (DESIGN §8.0.1 B안)', () {
    StopLine stop(int i, SelectorRow r) => StopLine(index: i, row: r, transfers: const [], branchUp: false, branchDown: false, small: false);
    SelectorRow hand(int seq, String to, String on, {bool saved = true}) =>
        row(seq, 'n$seq', closeYear: on.substring(0, 4), savedAs: saved ? to : null, handedTo: to, handedOn: on);

    test('단계마다 구분선 하나, 돌아오는 곳에도 하나', () {
      final out = DisplayRules.handOver([
        stop(0, row(1, 'a')),
        stop(1, hand(2, 'l_x', '2024-03-16')),
        stop(2, hand(3, 'l_x', '2024-03-16')),
        stop(3, hand(4, 'l_y', '2015-03-14')),
        stop(4, row(5, 'b')),
      ], lineId: 'l_me');
      final hands = out.whereType<TransferLine>().toList();
      expect([for (final h in hands) (h.lineId, h.on, h.back)], [
        ('l_x', '2024-03-16', false),
        ('l_y', '2015-03-14', false),
        ('l_me', '2015-03-14', true),
      ]);
      expect(out.indexOf(hands.first), 1);
    });

    test('이관 전 날짜면 구분선이 없고, 날짜를 모르면 있다', () {
      final rows = [stop(0, row(1, 'a')), stop(1, hand(2, 'l_x', '2024-03-16', saved: false))];
      expect(DisplayRules.handOver(rows, lineId: 'l_me').whereType<TransferLine>(), isEmpty);
      expect(DisplayRules.handOver(rows, lineId: 'l_me', undated: true).whereType<TransferLine>(), hasLength(1));
    });

    test('노선 전체가 넘어가면 머리 띠 하나, 폐지 구분선과 같은 자리면 합친다', () {
      final whole = DisplayRules.handOver([
        stop(0, hand(1, 'l_x', '1988-04-01')),
        stop(1, hand(2, 'l_x', '1988-04-01')),
      ], lineId: 'l_me');
      expect(whole.first, isA<TransferLine>().having((h) => h.whole, 'whole', true));
      final merged = DisplayRules.handOver([
        stop(0, row(1, 'a')),
        const SectionLine(gap: 0, year: '1997'),
        stop(1, hand(2, 'l_x', '1997-10-01')),
        stop(2, row(3, 'b')),
      ], lineId: 'l_me');
      expect(merged.whereType<SectionLine>(), isEmpty);
      expect(merged.whereType<TransferLine>().first.closedYear, '1997');
    });

    test('이관일 뒤 날짜면 이어받은 노선이 그날 서지 않아도 이관 구간이다 (湯前線 川村, 高千穂線)', () {
      final out = DisplayRules.handOver([
        stop(0, hand(1, 'l_x', '1989-10-01')),
        stop(1, hand(2, 'l_x', '1989-10-01', saved: false)),
        stop(2, hand(3, 'l_x', '1989-10-01')),
      ], lineId: 'l_me', date: DateSpan.parse('2026-11-11'));
      expect([for (final h in out.whereType<TransferLine>()) (h.whole, h.back)], [(true, false)]);
      expect(DisplayRules.bandOf(hand(2, 'l_x', '1989-10-01', saved: false), date: DateSpan.parse('1980-01-01')), isNull);
    });

    test('이관 전·이관 날에 폐역된 역은 날짜를 몰라도 구간을 끊지 않는다', () {
      for (final (closedOn, undated) in [('1968-07-21', false), ('1968-07-21', true), ('2010-12-04', true)]) {
        final out = DisplayRules.handOver([
          stop(0, row(1, 'a')),
          stop(1, hand(2, 'l_x', '2010-12-04')),
          stop(2, row(3, 'old', closeYear: closedOn.substring(0, 4), closedOn: closedOn, state: StopState.unknown)),
          stop(3, hand(4, 'l_x', '2010-12-04')),
        ], lineId: 'l_me', undated: undated);
        expect(out.whereType<TransferLine>(), hasLength(1), reason: '$closedOn $undated');
      }
      // 이관 뒤에 폐역된 역은 이어받은 회사 역이 아니라 이 노선으로 돌아온 것이다
      final later = DisplayRules.handOver([
        stop(0, hand(1, 'l_x', '2010-12-04')),
        stop(1, row(2, 'later', closeYear: '2012', closedOn: '2012-04-01', state: StopState.closed)),
        stop(2, hand(3, 'l_x', '2010-12-04')),
      ], lineId: 'l_me');
      expect(later.whereType<TransferLine>(), hasLength(3));
    });
  });

  group('10회차 G1 (전수 점검 4회차)', () {
    SelectorRow ext(int seq, String node, {String? openYear, String? closeYear}) => SelectorRow(
          seq: seq,
          node: node,
          state: StopState.closed,
          selectable: false,
          isExtension: true,
          kmCum: null,
          links: const [],
          openYear: openYear,
          closeYear: closeYear,
        );

    test('운휴로 비었다가 다시 이은 같은 노선 앞 토막 너머 이관 앞 노선도 잇는다 (上田 信越本線 ~1997 › しなの鉄道線)', () {
      final network = Network(NetworkData(
        routes: const [],
        edges: const [],
        routeEdges: const [],
        stops: const [],
        attrs: [
          for (final line in const ['me', 'old', 'new'])
            NetAttr(
              edgeId: 'e',
              lineId: line,
              operatorId: line == 'me' ? 'a' : 'b',
              lineageId: line == 'me' ? 'me' : 'shared',
              carryoverGroup: line,
              period: const NetPeriod(fromLo: '1900-01-01', fromHi: '1900-01-01'),
            ),
        ],
        lives: const [],
        units: const [],
        publicNodes: const {},
        nodeGroups: const {},
        operators: const [NetOperator(id: 'a', category: 'major'), NetOperator(id: 'b', category: 'major')],
      ));
      final r = DisplayRules(network, today: '2026-11-16');
      final row0 = row(0, 'x', links: [
        link('transfer', 'old', seq: 0, flow: 'through', from: '1924-08-15', to: '1997-10-01'),
        link('transfer', 'new', seq: 0, flow: 'through', from: '1997-10-01', to: '2019-10-12'),
        link('transfer', 'new', seq: 0, flow: 'through', from: '2021-03-28'),
      ]);
      final groups = r.transfers(row0, 'me', all, undated: true);
      final items = [for (final g in groups) ...g.items];
      expect(items.map((i) => i.link.otherLineId), ['new']);
      expect(items.single.before.map((b) => b.otherLineId), ['old']);
    });

    test('같은 쪽 같은 노선 분기가 기간이 엇갈려 겹치면(옮겨 간 방면) 하나만 남는다 (東村山 西武園線)', () {
      final rows = [
        row(0, 'a'),
        row(1, 'b', links: [
          link('branch', 'private', seq: 1, side: 'down', next: 'new', terminal: 'new', from: '1950-05-23'),
        ], gone: [
          link('branch', 'private', seq: 1, side: 'down', next: 'old', terminal: 'old', from: '1948-04-01', to: '1951-03-01'),
        ]),
        row(2, 'c'),
      ];
      final out = lines(rows);
      final branches = out.whereType<BranchLine>().toList();
      expect(branches.map((b) => b.item.link.nextStop), ['new']);
    });

    test('같은 쪽 같은 노선의 두 방면(기간 같음)은 둘 다 남는다', () {
      final rows = [
        row(0, 'a'),
        row(1, 'b', links: [
          link('branch', 'private', seq: 1, side: 'down', next: 'p', terminal: 'p', from: '1950-01-01'),
          link('branch', 'private', seq: 1, side: 'down', next: 'q', terminal: 'q', from: '1950-01-01'),
        ]),
        row(2, 'c'),
      ];
      expect(lines(rows).whereType<BranchLine>(), hasLength(2));
    });

    test('첫 역 앞의 열람 전용 역은 첫 역 위(-1)에 놓이고, 앞 역이 열람 전용 역이면 그 옆이다', () {
      final rows = [row(0, 'a', km: 0), row(1, 'b', km: 1)];
      final out = lines(rows, stops: const [
        ArchiveStop(id: 'x1', afterNode: null, beforeNode: 'a', closedYear: '1945', km: null),
        ArchiveStop(id: 'x2', afterNode: 'x1', beforeNode: null, closedYear: '1945', km: null),
      ]);
      // 첫 역 앞 없어진 구간: 바깥(맨 위)에 폐지 해 구분선, 안쪽에 끝 구분선 (志度線 瓦町 앞, 사용자 결정 2026-11-18)
      expect(out.first, isA<SectionLine>().having((l) => l.year, 'year', '1945'));
      expect(out[1], isA<ArchiveLine>());
      final archives = out.whereType<ArchiveLine>().toList();
      expect(archives.map((a) => a.stop.id).toSet(), {'x1', 'x2'});
      expect(archives.every((a) => a.gap == -1), isTrue);
      expect(out.indexWhere((l) => l is StopLine), greaterThan(out.lastIndexWhere((l) => l is ArchiveLine)));
    });

    test('같은 자리의 여러 열람 전용 역은 계통 순번(seq) 순으로 놓이고, 순번이 없으면 예전처럼 km 순이다 (志度線 瓦町 앞)', () {
      final rows = [row(0, 'a', km: 0), row(1, 'b', km: 1)];
      // 받은 순서(DB에 들어간 순서)와 다른 순번. km를 모르는 역(손 행)과 아는 역이 섞여도 순번이 이긴다
      final out = lines(rows, stops: const [
        ArchiveStop(id: 'koen', afterNode: null, beforeNode: 'a', closedYear: '1945', km: null, seq: 1),
        ArchiveStop(id: 'higashida', afterNode: null, beforeNode: 'a', closedYear: '1937', km: 0.5, seq: 4),
        ArchiveStop(id: 'nakano', afterNode: null, beforeNode: 'a', closedYear: '1945', km: null, seq: 2),
        ArchiveStop(id: 'fujitsuka', afterNode: null, beforeNode: 'a', closedYear: '1945', km: null, seq: 3),
      ]);
      expect(out.whereType<ArchiveLine>().map((a) => a.stop.id), ['koen', 'nakano', 'fujitsuka', 'higashida']);
      expect(out.indexWhere((l) => l is StopLine), greaterThan(out.lastIndexWhere((l) => l is ArchiveLine)));
      // 옛 팩(순번 없음)은 km 순, 모르는 km는 뒤
      final old = lines(rows, stops: const [
        ArchiveStop(id: 'p', afterNode: 'a', beforeNode: 'b', closedYear: '1940', km: null),
        ArchiveStop(id: 'q', afterNode: 'a', beforeNode: 'b', closedYear: '1940', km: 0.7),
        ArchiveStop(id: 'r', afterNode: 'a', beforeNode: 'b', closedYear: '1940', km: 0.3),
      ]);
      expect(old.whereType<ArchiveLine>().map((a) => a.stop.id), ['r', 'q', 'p']);
    });

    test('병주 토막이 기간만 나뉘면 그날 토막 하나만 그린다 (のと鉄道七尾線 끝 輪島 ~2001 → 穴水)', () {
      final rows = [row(0, 'a'), row(1, 'b'), row(2, 'c')];
      const runs = [
        ParallelRun(otherLineId: 'private', fromSeq: 1, toSeq: 2, outNext: 'n', outTerminal: 'old', validFromLo: '1991-09-01', validToHi: '2001-04-01'),
        ParallelRun(otherLineId: 'private', fromSeq: 1, toSeq: 2, outNext: 'n', outTerminal: 'new', validFromLo: '2001-04-01'),
      ];
      for (final (date, want) in [(null, 'new'), (DateSpan.parse('1995-05-05'), 'old'), (DateSpan.parse('2026-01-01'), 'new')]) {
        final out = rules.lines(lineId: 'me', rows: rows, openGaps: const [true, true], options: all, parallels: runs, date: date);
        final ends = [
          for (final l in out.whereType<EndLine>())
            if (l.parallel != null) ...l.items.map((i) => i.link.terminal),
          for (final l in out.whereType<BranchLine>())
            if (l.parallel != null) l.item.link.terminal,
        ];
        expect(ends, [want], reason: '$date');
      }
    });

    test('날짜 모름 화면의 병주 시작은 이어진 토막의 첫 시작이다 (日豊本線 小倉 → 鹿児島本線, 11회차 F1)', () {
      final rows = [row(0, 'a'), row(1, 'b'), row(2, 'c')];
      const runs = [
        ParallelRun(otherLineId: 'private', fromSeq: 1, toSeq: 2, outNext: 'n', outTerminal: 'old', validFromLo: '1902-12-27', validToHi: '1970-07-01'),
        ParallelRun(otherLineId: 'private', fromSeq: 1, toSeq: 2, outNext: 'n', outTerminal: 'mid', validFromLo: '1970-07-01', validToHi: '2004-03-13'),
        ParallelRun(otherLineId: 'private', fromSeq: 1, toSeq: 2, outNext: 'n', outTerminal: 'new', validFromLo: '2004-03-13'),
        // 끊긴 뒤 다시 시작한 다른 칸 토막은 이어지지 않는다
        ParallelRun(otherLineId: 'other', fromSeq: 1, toSeq: 2, outNext: 'n', outTerminal: 'x', validFromLo: '1960-01-01', validToHi: '1970-01-01'),
        ParallelRun(otherLineId: 'other', fromSeq: 1, toSeq: 2, outNext: 'n', outTerminal: 'y', validFromLo: '1980-01-01'),
      ];
      for (final (date, want) in [
        (null, {'private': ('new', '1902-12-27'), 'other': ('y', '1980-01-01')}),
        (DateSpan.parse('1990-05-05'), {'private': ('mid', '1970-07-01'), 'other': ('y', '1980-01-01')}),
        (DateSpan.parse('2026-01-01'), {'private': ('new', '2004-03-13'), 'other': ('y', '1980-01-01')}),
      ]) {
        final out = rules.lines(lineId: 'me', rows: rows, openGaps: const [true, true], options: all, parallels: runs, date: date);
        final got = {
          for (final l in out.whereType<EndLine>())
            if (l.parallel != null)
              for (final i in l.items) i.link.otherLineId!: (i.link.terminal!, i.link.validFromLo!),
          for (final l in out.whereType<BranchLine>())
            if (l.parallel != null) l.item.link.otherLineId!: (l.item.link.terminal!, l.item.link.validFromLo!),
        };
        expect(got, want, reason: '$date');
      }
    });

    test('상대 노선 칸이 운휴에 들어가 끝난 연결은 운휴 중이다 (外房線 大原 いすみ線)', () {
      final network = Network(const NetworkData(
        routes: [],
        edges: [NetEdge(id: 'e1', n: 1, from: 'ohara', to: 'next', meters: 1000)],
        routeEdges: [],
        stops: [],
        attrs: [
          NetAttr(edgeId: 'e1', lineId: 'isumi', operatorId: 'o', lineageId: 'isumi', carryoverGroup: 'isumi', period: NetPeriod(fromLo: '1988-03-24', fromHi: '1988-03-24')),
        ],
        lives: [
          NetLife(edgeId: 'e1', suspended: false, period: NetPeriod(fromLo: '1988-03-24', fromHi: '1988-03-24', toLo: '2024-10-05', toHi: '2024-10-05')),
          NetLife(edgeId: 'e1', suspended: true, period: NetPeriod(fromLo: '2024-10-05', fromHi: '2024-10-05')),
        ],
        units: [],
        publicNodes: {},
        nodeGroups: {},
        operators: [NetOperator(id: 'o', category: 'third')],
      ));
      final r = DisplayRules(network, today: '2026-11-16');
      final rows = [
        row(0, 'a'),
        row(1, 'ohara', gone: [link('branch', 'isumi', seq: 1, side: 'up', next: 'next', terminal: 'next', from: '1988-03-24', to: '2024-10-05')]),
        row(2, 'c'),
      ];
      final out = r.lines(lineId: 'me', rows: rows, openGaps: const [true, true], options: all);
      final b = out.whereType<BranchLine>().single;
      expect(b.item.gone, isTrue);
      expect(b.item.suspended, isTrue);
      // 폐지로 끝난 연결은 운휴가 아니다
      final closed = rules.lines(lineId: 'me', rows: rows, openGaps: const [true, true], options: all);
      expect(closed.whereType<BranchLine>().single.item.suspended, isFalse);
    });

    test('계통 끝 너머 확장 묶음이 시기마다 다르면 묶음 사이에 글 없는 구분선 (鹿島線 北鹿島 너머)', () {
      final rows = [
        row(0, 'a'),
        row(1, 'b'),
        ext(2, 'koya', openYear: '1985', closeYear: '1994'),
        ext(3, 'ikiri', openYear: '1978', closeYear: '1978'),
        ext(4, 'konan', openYear: '1978', closeYear: '1983'),
      ];
      final out = rules.lines(lineId: 'me', rows: rows, openGaps: const [true, true, true, true], options: all);
      final sections = out.whereType<SectionLine>().where((s) => s.year == null && !s.suspended).toList();
      expect(sections.map((s) => s.gap), [2]);
    });
  });
}

