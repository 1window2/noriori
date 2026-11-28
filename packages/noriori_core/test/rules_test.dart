import 'package:noriori_core/noriori_core.dart';
import 'package:test/test.dart';

void main() {
  group('날짜 입력', () {
    test('해, 달, 날을 EDTF로 바꾼다', () {
      expect(parseDateInput(''), isNull);
      expect(parseDateInput('2015'), '2015-XX-XX');
      expect(parseDateInput('2015-3'), '2015-03-XX');
      expect(parseDateInput('2015.3.14'), '2015-03-14');
      expect(parseDateInput('2024-02-29'), '2024-02-29');
    });

    test('화면에는 쓴 그대로 보인다', () {
      String label(String raw) => dateLabel(raw, decade: (year) => '$year년대');
      expect(label('2015-03-14'), '2015.3.14');
      expect(label('2015-03-XX'), '2015.3');
      expect(label('2015-XX-XX'), '2015');
      expect(label('198X-XX-XX'), '1980년대');
    });

    test('달력에 없는 날짜는 받지 않는다', () {
      for (final bad in ['2023-02-29', '2015-13', '20', '2015-03-14-01', 'abcd']) {
        expect(() => parseDateInput(bad), throwsFormatException, reason: bad);
      }
    });
  });

  group('이름', () {
    const rows = [
      NameRow(text: '기본'),
      NameRow(text: '옛이름', validFrom: '1900-01-01', validTo: '2000-01-01'),
      NameRow(text: '노선명', lineId: 'l'),
      NameRow(text: '노선옛이름', lineId: 'l', validFrom: '1900-01-01', validTo: '2000-01-01'),
    ];

    test('노선 고유 + 날짜 > 노선 고유 > 기본 + 날짜 > 기본', () {
      expect(pickName(rows, lineId: 'l', date: '1990-01-01'), '노선옛이름');
      expect(pickName(rows, lineId: 'l', date: '2010-01-01'), '노선명');
      expect(pickName(rows, date: '1990-01-01'), '옛이름');
      expect(pickName(rows, date: '2010-01-01'), '기본');
      expect(pickName(rows), '기본');
    });

    test('날짜를 몰라도 지금 이어지는 노선 고유 이름(지금 臨時駅)을 쓰고, 끝난 것은 쓰지 않는다', () {
      const now = [
        NameRow(text: '田井ノ浜'),
        NameRow(text: '(臨)田井ノ浜', lineId: 'l', validFrom: '1960-07-03'),
      ];
      expect(pickName(now, lineId: 'l'), '(臨)田井ノ浜');
      expect(pickName(now, lineId: 'm'), '田井ノ浜');
      const past = [
        NameRow(text: '原生花園'),
        NameRow(text: '原生花園仮乗降場', lineId: 'l', validFrom: '1964-06-01', validTo: '1978-10-02'),
      ];
      expect(pickName(past, lineId: 'l'), '原生花園');
    });

    test('기간의 끝 날은 그 이름이 아니다', () {
      expect(pickName(rows, date: '2000-01-01'), '기본');
    });
  });

  group('검색어', () {
    test('가나를 히라가나로 맞추고 한 글자씩 나눈다', () {
      expect(searchQuery('シンジュク'), '"し ん じ ゅ く"');
      expect(foldSearchText('霞ヶ関'), foldSearchText('霞ケ関'));
      expect(searchQuery('中央・快速'), '"中 央 快 速"');
    });

    test('따옴표로 검색식을 깨지 못하고 빈 값은 찾지 않는다', () {
      expect(searchQuery('a"b'), '"a b"');
      expect(searchQuery('  "  '), isNull);
    });

    test('영어 Mt. 산 이름은 산 읽기로도 찾는다', () {
      expect(searchQuery('Mt. Takao'),
          '"m t . t a k a o" OR "t a k a o s a n" OR "t a k a o z a n" OR "t a k a o y a m a" OR "t a k a o d a k e" OR "t a k a o t a k e"');
      expect(searchQuery('Mount Koya'), contains('"k o y a s a n"'));
      expect(searchQuery('mt.fuji'), startsWith('"m t . f u j i" OR "f u j i s a n"'));
      // Mt로 시작하는 다른 낱말과 「Mt.」만 친 것은 그대로
      expect(searchQuery('Mtsu'), '"m t s u"');
      expect(searchQuery('Mt.'), '"m t ."');
    });

    test('Mt. 검색어의 접은 꼴은 옛 이름 순위에도 같은 산 꼬리를 쓴다', () {
      expect(searchFoldedVariants('Mt. Takao'), contains('t a k a o s a n'));
      expect(searchFoldedVariants('新宿'), ['新 宿']);
      expect(searchFoldedVariants('  '), isEmpty);
    });
  });

  group('완주율', () {
    NetUnit unit(int n, int meters, {String? lo, String? hi, bool normal = true}) => NetUnit(
          n: n,
          key: 'u$n',
          carryover: true,
          edgeId: 'e$n',
          meters: meters,
          normal: normal,
          dateLo: lo,
          dateHi: hi,
        );

    test('특정 연도는 확실히 영업한 단위만 세고 애매하면 판정 불가로 뺀다 (DESIGN §5.4)', () {
      NetUnit span(String? from, String to) {
        final f = from == null ? null : DateSpan.parse(from);
        final t = DateSpan.parse(to);
        return NetUnit(
          n: 1,
          key: 'u',
          carryover: true,
          edgeId: 'e',
          meters: 1000,
          normal: true,
          dateLo: f?.lo,
          dateHi: t.hi,
          fromHi: f?.hi,
          toLo: t.lo,
        );
      }

      bool counts(NetUnit u, int y) => unitCounts(u, BasisYear(y), today: '2026-11-02');
      // 개업일을 모르면 어느 해에도 확실하지 않다
      final unknown = span(null, '1969-10-01');
      expect(counts(unknown, 1960), isFalse);
      expect(unitUndecided(unknown, 1960), isTrue);
      expect(unitUndecided(unknown, 1970), isFalse);
      // 폐지 연도만 알면 그해에 영업한 것으로 친다
      final closedYear = span('1950-04-01', '1972-XX-XX');
      expect(counts(closedYear, 1972), isTrue);
      expect(counts(closedYear, 1973), isFalse);
      expect(unitUndecided(closedYear, 1972), isFalse);
      // 개업 연도만 알아도 그해에 센다
      expect(counts(span('1972-XX-XX', 'ongoing'), 1972), isTrue);
      // 연대까지만 알면 그 연대 안의 해는 판정 불가, 그 뒤는 확실하다
      final decade = span('197X-XX-XX', 'ongoing');
      expect(counts(decade, 1975), isFalse);
      expect(unitUndecided(decade, 1975), isTrue);
      expect(counts(decade, 1980), isTrue);
      // 1월 1일 폐지는 그해에 영업하지 않았다
      expect(counts(span('1950-04-01', '1972-01-01'), 1972), isFalse);
      expect(unitUndecided(span('1950-04-01', '1972-01-01'), 1972), isFalse);
      // 현행과 역대는 날짜 불확실성과 무관하다
      expect(unitCounts(unknown, const BasisAllTime(), today: '2026-11-02'), isTrue);
      final score = computeScore(
        units: [unknown, closedYear],
        hits: const {},
        basis: const BasisYear(1960),
        today: '2026-11-02',
      );
      expect(score.denUnits, 1);
      expect(score.undecidedUnits, 1);
    });

    final units = [
      unit(1, 1000, lo: '1900-01-01', hi: DateSpan.maxDate),
      unit(2, 1000, lo: '1900-01-01', hi: '1990-01-01'),
      unit(3, 1000, lo: '1900-01-01', hi: DateSpan.maxDate, normal: false),
    ];

    Score score(ScoreBasis basis, Map<int, String?> hits) =>
        computeScore(units: units, hits: hits, basis: basis, today: '2026-11-02');

    test('분자는 분모의 부분집합이다', () {
      final current = score(const BasisCurrent(), {1: '2020-01-01', 2: '1980-01-01', 3: '2020-01-01'});
      expect(current.denMeters, 1000);
      expect(current.numMeters, 1000);
      final allTime = score(const BasisAllTime(), {1: null, 2: null, 3: null});
      expect(allTime.denMeters, 2000);
      expect(allTime.numMeters, 2000);
    });

    test('연도 기준은 그해 말까지 끝난 기록만 센다', () {
      expect(score(const BasisYear(1985), {1: '1985-12-31'}).numUnits, 1);
      expect(score(const BasisYear(1985), {1: '1986-01-01'}).numUnits, 0);
      expect(score(const BasisYear(1985), {1: null}).numUnits, 0);
      expect(score(const BasisYear(1995), const {}).denUnits, 1);
    });

    test('표시는 내림이라 다 타기 전에는 100.0이 아니다', () {
      const almost = Score(numMeters: 999999, denMeters: 1000000, numUnits: 9, denUnits: 10);
      expect(almost.permille, 999);
      const all = Score(numMeters: 1000000, denMeters: 1000000, numUnits: 10, denUnits: 10);
      expect(all.permille, 1000);
      const none = Score(numMeters: 0, denMeters: 0, numUnits: 0, denUnits: 0);
      expect(none.permille, 0);
    });
  });

  group('글자 표기', () {
    Score score(int num, int den) =>
        Score(numMeters: num, denMeters: den, numUnits: num > 0 ? 1 : 0, denUnits: 2);

    test('탄 구간이 있으면 0%로 보이지 않는다', () {
      expect(percentLabel(score(7500, 27352300)), '0.02%');
      expect(percentLabel(score(100, 27352300)), '<0.01%');
      expect(percentLabel(score(0, 100)), '0%');
    });

    test('보통은 소수 한 자리이고 내림이다', () {
      expect(percentLabel(score(7500, 20600)), '36.4%');
      expect(percentLabel(score(999999, 1000000)), '99.9%');
    });

    test('다 타야 100%다', () {
      expect(percentLabel(score(1000, 1000)), '100%');
      expect(percentLabel(score(0, 0)), '0%');
    });

    test('km는 천 단위 쉼표를 쓰고 큰 분모는 소수를 뺀다', () {
      expect(kmLabel(4223600), '4,223.6');
      expect(kmLabel(27352300), '27,352.3');
      expect(kmLabel(6572), '6.6', reason: '분모도 소수 한 자리다');
      expect(kmLabel(950), '1.0');
      expect(kmLabel(0), '0.0');
      expect(kmLabel(713700), '713.7');
    });

    test('연도 기준은 같은 해면 같은 값이다', () {
      expect(const BasisYear(1985), const BasisYear(1985));
      expect(const BasisYear(1985) == const BasisYear(1986), isFalse);
    });
  });

  group('백업 안내', () {
    test('OS 백업 크기가 20MB를 넘으면 설정에서 알린다 (ARCHITECTURE §3.7)', () {
      expect(osBackupTooLarge(20 * 1024 * 1024), isFalse);
      expect(osBackupTooLarge(20 * 1024 * 1024 + 1), isTrue);
      expect(osBackupTooLarge(0), isFalse);
    });

    const day = 24 * 60 * 60 * 1000;
    BackupNotice? notice({
      bool hasFolder = true,
      bool granted = true,
      bool failed = false,
      bool unreadable = false,
      bool needsMerge = false,
      int? lastBackupAt = 1000,
      int? lastChangeAt = 1000,
      int now = 2000,
    }) =>
        backupNotice(
          hasFolder: hasFolder,
          granted: granted,
          failed: failed,
          unreadable: unreadable,
          needsMerge: needsMerge,
          lastBackupAt: lastBackupAt,
          lastChangeAt: lastChangeAt,
          now: now,
        );

    test('이상이 없으면 조용하다', () {
      expect(notice(), isNull);
      expect(notice(hasFolder: false, lastChangeAt: null), isNull);
    });

    test('병합이 가장 먼저고 그다음 실패다', () {
      expect(notice(needsMerge: true, failed: true), BackupNotice.needsMerge);
      expect(notice(failed: true, unreadable: true), BackupNotice.failed);
    });

    test('권한을 잃으면 알린다', () {
      expect(notice(granted: false), BackupNotice.folderLost);
    });

    test('기록이 있는데 폴더가 없으면 알린다', () {
      expect(notice(hasFolder: false), BackupNotice.noFolder);
    });

    test('바뀐 것이 없으면 오래돼도 알리지 않는다', () {
      expect(notice(lastChangeAt: 500, now: 30 * day), isNull);
    });

    test('바뀐 기록이 일주일 넘게 백업되지 않으면 알린다', () {
      expect(notice(lastChangeAt: 2000, now: 8 * day), BackupNotice.stale);
      expect(notice(lastChangeAt: 2000, now: day), isNull);
    });
  });

  group('수집', () {
    Score score(int num, int den) => Score(numMeters: num, denMeters: den, numUnits: num, denUnits: den);

    test('완주가 먼저이고 안 탄 것은 빠진다. 전에 얻은 배지는 완주 칸으로 남는다', () {
      final items = collectionItems(
        {'a': score(3, 10), 'b': score(5, 5), 'c': score(0, 5), 'd': score(9, 10)},
        held: {'d'},
      );
      expect(items.map((item) => item.key), ['b', 'd', 'a']);
      expect(items[1].kept, isTrue);
      expect(items[1].complete, isTrue);
      expect(items.first.kept, isFalse, reason: '지금 완주한 것은 남긴 배지가 아니다');
    });

    test('현행 완주 배지는 한 번 얻으면 남고, 그 노선 기록을 다 지우면 사라진다 (DESIGN §3.3)', () {
      Set<String> held(Set<String> earned, Map<String, Score> lines) =>
          heldBadges(earned, lines: lines, operators: const {}, prefs: const {});
      // 지금 완주하면 얻는다
      expect(held({}, {'l': score(5, 5)}), {lineBadge('l')});
      // 새 역·연장으로 100%가 아니게 되어도 남는다
      expect(held({lineBadge('l')}, {'l': score(5, 7)}), {lineBadge('l')});
      // 그 노선의 탄 기록을 모두 지우면 사라진다
      expect(held({lineBadge('l')}, {'l': score(0, 7)}), isEmpty);
      // 다 폐지되어 현행 점수가 없어도 남는다
      expect(held({lineBadge('gone')}, const {}), {lineBadge('gone')});
      // 얻은 적 없는 미완주는 배지가 아니다
      expect(held({}, {'m': score(4, 5)}), isEmpty);
      expect(
        heldBadges({}, lines: const {}, operators: {'o': score(2, 2)}, prefs: {13: score(1, 1)}),
        {operatorBadge('o'), prefBadge(13)},
      );
    });

    test('배지는 지니는 완주 배지와 넘긴 역 수의 합이다', () {
      expect(badgeCount(held: {lineBadge('a'), operatorBadge('o')}, stations: 600), 4);
    });

    test('가까운 곳은 50km 안만 가까운 순으로 보인다', () {
      const near = RemainingSection(lineId: 'l', from: 'a', to: 'b', meters: 1000);
      const far = RemainingSection(lineId: 'l', from: 'c', to: 'd', meters: 1000);
      const nearer = RemainingSection(lineId: 'm', from: 'e', to: 'f', meters: 1000);
      final found = nearbySections(
        [near, far, nearer],
        positions: const {
          'a': (35.4, 139.6),
          'b': (35.3, 139.6),
          'c': (36.5, 139.6),
          'd': (36.6, 139.6),
          'e': (35.46, 139.62),
        },
        lat: 35.46,
        lon: 139.62,
      );
      expect(found.map((item) => item.$1), [nearer, near]);
      const long = RemainingSection(lineId: 'n', from: 'c', to: 'd', meters: 1000, nodes: ['c', 'e', 'd']);
      final middle = nearbySections(
        [long],
        positions: const {'c': (36.5, 139.6), 'd': (36.6, 139.6), 'e': (35.46, 139.62)},
        lat: 35.46,
        lon: 139.62,
      );
      expect(middle.single.$2, lessThan(1), reason: '끝이 멀어도 중간 역이 가까우면 보인다');
      expect(distanceKm(35.0, 139.0, 36.0, 139.0), closeTo(111.2, 0.2));
    });
  });

  group('연도별과 활동', () {
    const rides = [
      RideDay(date: '2024-03-01', km10: 100, exact: true),
      RideDay(date: '2024-03-01', km10: 50, exact: true),
      RideDay(date: '2024-01-01', km10: 10),
      RideDay(date: '2026-11-02', km10: 30, exact: true),
      RideDay(date: null, km10: 70),
    ];

    test('연도별은 첫 해부터 빈 해까지 채우고 날짜 모름은 뺀다', () {
      final stats = yearlyStats(
        rides,
        edgeYears: const {1: 2024, 2: 2026},
        edgeMeters: const {1: 1000, 2: 500},
        lastYear: 2026,
      );
      expect(stats.map((stat) => stat.year), [2024, 2025, 2026]);
      expect(stats.first.km10, 160);
      expect(stats.first.rides, 3);
      expect(stats.first.newMeters, 1000);
      expect(stats[1].km10, 0);
      expect(undatedRides(rides), 1);
    });

    test('캘린더는 하루까지 아는 기록만 찍고 세 건부터 가장 진하다', () {
      final days = dailyActivity(rides, 2024);
      expect(days.keys, ['2024-03-01']);
      expect(days['2024-03-01']!.km10, 150);
      expect(activityLevel(days['2024-03-01']), 2);
      expect(activityLevel(null), 0);
      expect(activityLevel(const DayActivity(rides: 5, km10: 1)), 3);
    });

    test('폐선 기록은 마지막으로 탄 뒤 몇 년 만에 없어졌는지 안다', () {
      const ride = ClosedRide(lineId: 'l', from: 'a', to: 'b', meters: 1, closeYear: 2026, lastYear: 2023);
      expect(ride.yearsBefore, 3);
      expect(const ClosedRide(lineId: 'l', from: 'a', to: 'b', meters: 1, closeYear: 2026).yearsBefore, isNull);
    });
  });

  test('도도부현별 방문 역은 많은 곳부터 세고 모르는 역은 뺀다', () {
    expect(
      stationsByPref(
        [1, 2, 3, 4, 5, 1],
        const {1: 14, 2: 13, 3: 13, 4: 1},
      ),
      [(13, 2), (1, 1), (14, 1)],
    );
  });

  test('연대만 아는 기록은 어느 해에도 넣지 않고 해를 모르는 기록으로 센다', () {
    const rides = [
      RideDay(date: '198X-XX-XX', km10: 10),
      RideDay(date: '2015-XX-XX', km10: 20),
      RideDay(date: '2015-03-XX', km10: 30),
      RideDay(date: '2016-01-02', km10: 40, exact: true),
      RideDay(date: null, km10: 50),
    ];
    final years = yearlyStats(rides, edgeYears: const {}, edgeMeters: const {}, lastYear: 2016);
    expect([for (final year in years) (year.year, year.km10, year.rides)], [(2015, 50, 2), (2016, 40, 1)]);
    expect(undatedRides(rides), 2);
    expect(yearOf('198X-XX-XX'), isNull);
  });

  test('파일의 날짜는 입력란 규칙으로 고치고 못 읽으면 거부한다', () {
    expect(fileDate(null), isNull);
    expect(fileDate('2015-03-14'), '2015-03-14');
    expect(fileDate('198X-XX-XX'), '198X-XX-XX');
    expect(fileDate('2015/3/14'), '2015-03-14');
    expect(() => fileDate('어제'), throwsFormatException);
    expect(() => fileDate('2015-02-30'), throwsFormatException, reason: '달력에 없는 날');
    expect(() => fileDate('2015-02-29'), throwsFormatException, reason: '윤년이 아니다');
    expect(fileDate('2016-02-29'), '2016-02-29');
  });
}
