import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noriori_core/noriori_core.dart';
import 'package:noriori_store/noriori_store.dart';

import '../i18n/strings.g.dart';

/// 지금 세션. 세션 안에서 데이터 팩은 바뀌지 않으므로 화면은 판 교체를 모른다.
final sessionProvider = Provider<AppSession>(
  (ref) => throw UnimplementedError('시작 결과로 덮어쓴다'),
);

/// UUIDv7에 넣는 난수 10바이트.
Uint8List secureRandomBytes() {
  final random = Random.secure();
  return Uint8List.fromList([for (var i = 0; i < 10; i++) random.nextInt(256)]);
}

/// 기기 ID. 처음 쓸 때 만들고 복원으로 옮기지 않는다.
final deviceIdProvider = FutureProvider<String>((ref) {
  final session = ref.watch(sessionProvider);
  return SettingStore(session.db).readOrCreate(
    'device_id',
    () => uuidV7(millis: ref.read(nowProvider)(), randomBytes: secureRandomBytes()),
  );
});

final networkProvider = Provider<Network>(
  (ref) => throw UnimplementedError('시작 결과로 덮어쓴다'),
);

/// 언어별 이름. 시작할 때 세 벌을 읽어 둔다.
final nameBooksProvider = Provider<Map<AppLocale, NameBook>>(
  (ref) => throw UnimplementedError('시작 결과로 덮어쓴다'),
);

final nameBookProvider = Provider<NameBook>(
  (ref) => ref.watch(nameBooksProvider)[ref.watch(languageProvider)]!,
);

/// 지금 세션의 데이터 판.
final editionProvider = Provider<String>(
  (ref) => throw UnimplementedError('시작 결과로 덮어쓴다'),
);

/// 선로 타일 파일.
final railTilesProvider = Provider<String>(
  (ref) => throw UnimplementedError('시작 결과로 덮어쓴다'),
);

/// OSM 선로 타일 파일. 없을 수 있다.
final osmTilesProvider = Provider<String?>((ref) => null);

/// 앱에 넣은 기본 배경과 글리프. 인터넷이 없어도 지도가 그려진다.
final baseTilesProvider = Provider<String?>((ref) => null);
final glyphsProvider = Provider<String?>((ref) => null);

/// 데이터 팩의 규모.
final class PackFacts {
  const PackFacts({required this.stations, required this.lines});

  final int stations;
  final int lines;
}

final packFactsProvider = FutureProvider<PackFacts>(
  (ref) => throw UnimplementedError('시작 결과로 덮어쓴다'),
);

/// 앱 언어에 맞춘 이름 순서. 없는 표기는 일본어로 내려간다.
List<String> nameLanguages(AppLocale locale) => switch (locale) {
      AppLocale.ko => PackReader.koreanFirst,
      AppLocale.en => PackReader.englishFirst,
      AppLocale.ja => PackReader.japaneseFirst,
    };

/// 기기 언어. 세 언어가 아니면 영어다.
AppLocale deviceLanguage(String code) =>
    AppLocale.values.firstWhere((value) => value.languageCode == code, orElse: () => AppLocale.en);

Future<AppLocale?> readLanguage(SettingStore store) async {
  final name = await store.read('language');
  for (final value in AppLocale.values) {
    if (value.languageCode == name) return value;
  }
  return null;
}

/// 시작할 때 정한 언어. 시험에서는 한국어다.
final initialLanguageProvider = Provider<AppLocale>((ref) => AppLocale.ko);

/// 설정의 언어. 고르면 문구와 이름이 그 자리에서 바뀐다.
final languageProvider = NotifierProvider<LanguageController, AppLocale>(LanguageController.new);

class LanguageController extends Notifier<AppLocale> {
  @override
  AppLocale build() => ref.watch(initialLanguageProvider);

  Future<void> set(AppLocale next) async {
    LocaleSettings.setLocaleSync(next);
    state = next;
    await SettingStore(ref.read(sessionProvider).db).write('language', next.languageCode);
  }
}

final packReaderProvider = Provider<PackReader>(
  (ref) => PackReader(ref.watch(sessionProvider).db, languages: nameLanguages(ref.watch(languageProvider))),
);

enum ThemeChoice {
  light(ThemeMode.light),
  dark(ThemeMode.dark),
  system(ThemeMode.system);

  const ThemeChoice(this.mode);

  final ThemeMode mode;
}

/// 시작할 때 읽은 테마. 시험에서는 기본값이다.
final initialThemeProvider = Provider<ThemeChoice>((ref) => ThemeChoice.system);

/// 테마는 라이트·다크·시스템 세 가지다 (DESIGN §7.1).
final themeChoiceProvider = NotifierProvider<ThemeController, ThemeChoice>(ThemeController.new);

Future<ThemeChoice> readThemeChoice(SettingStore store) async {
  final name = await store.read('theme');
  return ThemeChoice.values.firstWhere((value) => value.name == name, orElse: () => ThemeChoice.system);
}

class ThemeController extends Notifier<ThemeChoice> {
  @override
  ThemeChoice build() => ref.watch(initialThemeProvider);

  Future<void> set(ThemeChoice next) async {
    state = next;
    await SettingStore(ref.read(sessionProvider).db).write('theme', next.name);
  }
}

/// 시작할 때 읽은 표시 설정. 시험에서는 기본값이다.
final initialDisplayOptionsProvider = Provider<DisplayOptions>((ref) => const DisplayOptions());

/// 폐역·폐선 표시는 지도와 기록 화면이 하나다 (DESIGN §8).
final displayOptionsProvider =
    NotifierProvider<DisplayOptionsController, DisplayOptions>(DisplayOptionsController.new);

Future<DisplayOptions> readDisplayOptions(SettingStore store) async {
  Future<bool> flag(String key) async => await store.read(key) != '0';
  return DisplayOptions(
    showClosed: await flag('show_closed'),
    showArchive: await flag('show_archive'),
    showBranches: await flag('show_branches'),
    carryover: await flag('carryover'),
  );
}

final class DisplayOptionsController extends Notifier<DisplayOptions> {
  @override
  DisplayOptions build() => ref.watch(initialDisplayOptionsProvider);

  Future<void> set(DisplayOptions next) async {
    state = next;
    final store = SettingStore(ref.read(sessionProvider).db);
    await store.write('show_closed', next.showClosed ? '1' : '0');
    await store.write('show_archive', next.showArchive ? '1' : '0');
    await store.write('show_branches', next.showBranches ? '1' : '0');
    await store.write('carryover', next.carryover ? '1' : '0');
  }

  Future<void> update({bool? showClosed, bool? showArchive, bool? showBranches, bool? carryover}) => set(
        DisplayOptions(
          showClosed: showClosed ?? state.showClosed,
          showArchive: showArchive ?? state.showArchive,
          showBranches: showBranches ?? state.showBranches,
          carryover: carryover ?? state.carryover,
        ),
      );
}

/// UTC 밀리초. 시험에서 시계를 바꿀 수 있게 둔다.
final nowProvider = Provider<int Function()>(
  (ref) => () => DateTime.now().millisecondsSinceEpoch,
);

/// 앱의 "오늘"은 기기 시간대가 아니라 JST다. 켜 둔 채 자정을 넘기면 다시 계산한다.
final todayProvider = Provider<String>((ref) {
  final now = ref.watch(nowProvider)();
  final midnight = Timer(Duration(milliseconds: millisToNextJstDay(now)), ref.invalidateSelf);
  ref.onDispose(midnight.cancel);
  return jstDate(now);
});

final recordQueriesProvider = Provider<RecordQueries>(
  (ref) => RecordQueries(ref.watch(sessionProvider).db),
);

/// 기록 목록. 표시 이름까지 붙인 값이다.
final rideSummariesProvider = StreamProvider<List<RideSummary>>((ref) {
  final reader = ref.watch(packReaderProvider);
  return ref.watch(recordQueriesProvider).watchRides().asyncMap(reader.currentNames);
});

/// 통계가 쓰는 기록. 하루까지 아는 기록만 캘린더에 찍는다.
final rideDaysProvider = Provider<AsyncValue<List<RideDay>>>(
  (ref) => ref.watch(rideSummariesProvider).whenData(
        (rides) => [
          for (final ride in rides)
            RideDay(
              date: ride.shownDate,
              km10: ride.km10 ?? 0,
              exact: ride.onExactDay,
            ),
        ],
      ),
);

/// 구간을 처음 탄 해.
final riddenYearsProvider = StreamProvider<Map<int, int>>(
  (ref) => ref.watch(recordQueriesProvider).watchRiddenEdgeYears(),
);

/// 탄 구간. 저장하면 지도가 다시 칠한다.
final riddenEdgesProvider = StreamProvider<Set<int>>(
  (ref) => ref.watch(recordQueriesProvider).watchRiddenEdges(),
);

/// 사업자가 바뀌어도 기록을 잇는가. 모든 집계가 이 값을 따른다 (DESIGN §2.8 E).
final carryoverProvider = Provider<bool>((ref) => ref.watch(displayOptionsProvider).carryover);

/// 탄 단위와 최소 `effective_hi`.
final unitHitsProvider = StreamProvider<Map<int, String?>>(
  (ref) => ref.watch(recordQueriesProvider).watchUnitHits(carryover: ref.watch(carryoverProvider)),
);

/// 역 방문 목록.
final visitsProvider = StreamProvider<List<VisitSummary>>(
  (ref) => ref.watch(recordQueriesProvider).watchVisits(),
);

/// 승하차한 역.
/// 완주에서 빠진 기록의 합계 (DESIGN §2.8). `partial`은 남은 구간만 센다.
final reviewProvider = StreamProvider<({int rides, int meters})>((ref) {
  final interpreter = RideInterpreter(ref.watch(networkProvider));
  final records = ref.watch(sessionProvider).records;
  return ref.watch(recordQueriesProvider).watchRides().asyncMap((rides) async {
    final open = [
      for (final ride in rides)
        if (ride.status != ResolveStatus.ok) ride,
    ];
    var meters = 0;
    for (final summary in open) {
      final ride = await records.ride(summary.rideId);
      if (ride == null) continue;
      for (final expansion in interpreter.expansions(ride)) {
        meters += expansion.pendingMeters;
      }
    }
    return (rides: open.length, meters: meters);
  });
});

final alightedNodesProvider = StreamProvider<Set<String>>(
  (ref) => ref.watch(recordQueriesProvider).watchAlightedNodes(),
);

/// 도도부현별 완주율. 통계, 수집, 히트맵이 같은 값을 본다.
final prefScoresProvider = Provider.family<Map<int, Score>, ScoreBasis>(
  (ref, basis) => prefScores(
    ref.watch(networkProvider),
    hits: ref.watch(unitHitsProvider).value ?? const {},
    basis: basis,
    today: ref.watch(todayProvider),
    carryover: ref.watch(carryoverProvider),
  ),
);

/// 지도 점의 상태. 판정은 core 하나다.
final stationMarksProvider = Provider<StationMarks>(
  (ref) => stationMarks(
    ref.watch(networkProvider),
    alighted: ref.watch(alightedNodesProvider).value ?? const {},
    visited: [
      for (final visit in ref.watch(visitsProvider).value ?? const <VisitSummary>[]) visit.node,
    ],
    ridden: ref.watch(riddenNodesProvider).value ?? const {},
  ),
);

/// 누적 탑승 거리. 0.1km 단위다.
final totalKm10Provider = StreamProvider<int>(
  (ref) => ref.watch(recordQueriesProvider).watchTotalKm10(),
);

/// 지도에 혼자 보이는 노선. 노선 상세가 켜고 지도가 끈다.
final soloLineIdProvider = NotifierProvider<SoloLineId, String?>(SoloLineId.new);

final class SoloLineId extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? lineId) => state = lineId;
}

/// 단독 보기의 구간과 역.
final soloLineProvider = Provider<SoloLine?>((ref) {
  final lineId = ref.watch(soloLineIdProvider);
  final hits = ref.watch(unitHitsProvider).value;
  if (lineId == null || hits == null) return null;
  final network = ref.watch(networkProvider);
  final carryover = ref.watch(carryoverProvider);
  final diagram = lineDiagram(network, lineId, hits: hits, carryover: carryover, today: ref.watch(todayProvider));
  return soloLine(network, diagram, hits: hits, carryover: carryover);
});

/// 선택기 표시 규칙. 회사 표를 한 번만 만든다.
final displayRulesProvider = Provider<DisplayRules>(
  (ref) => DisplayRules(ref.watch(networkProvider), today: ref.watch(todayProvider)),
);

/// 위치 미확인 표식.
final mapMarkersProvider = FutureProvider<List<MapMarker>>(
  (ref) => ref.watch(packReaderProvider).mapMarkers(),
);

/// 지도에 선이 없는 노선.
final unmappedLinesProvider = FutureProvider<Set<String>>(
  (ref) => ref.watch(packReaderProvider).unmappedLines(),
);

/// 날짜 모름 기록으로 탄 단위. 이번 달 km에서 뺀다.
final undatedUnitsProvider = StreamProvider<Set<int>>(
  (ref) => ref.watch(recordQueriesProvider).watchUndatedUnits(carryover: ref.watch(carryoverProvider)),
);

/// 지나간 역. 신호장 같은 숨은 노드는 역이 아니다.
final riddenNodesProvider = StreamProvider<Set<String>>((ref) {
  final public = ref.watch(networkProvider).data.publicNodes;
  return ref
      .watch(recordQueriesProvider)
      .watchRiddenNodes()
      .map((nodes) => nodes.where(public.contains).toSet());
});

/// 마지막으로 바뀐 시각. 기록이 바뀌면 다시 읽을 화면이 본다.
final lastChangeProvider = StreamProvider<int?>(
  (ref) => ref.watch(recordQueriesProvider).watchLastChange(),
);

/// 최근에 탄 노선.
final recentLinesProvider = StreamProvider<List<String>>(
  (ref) => ref.watch(recordQueriesProvider).watchRecentLines(),
);

/// 저장 뒤 바뀐 탄 단위로 다시 계산한다. 판정은 core 하나다.
final scoreTableProvider = Provider.family<AsyncValue<ScoreTable>, ScoreBasis>(
  (ref, basis) => ref.watch(unitHitsProvider).whenData(
        (hits) => scoreTable(
          ref.watch(networkProvider),
          hits: hits,
          basis: basis,
          carryover: ref.watch(carryoverProvider),
          today: ref.watch(todayProvider),
        ),
      ),
);

/// 현행/폐선 → 분류 → 회사 → 노선.
final browseTreeProvider = Provider.family<AsyncValue<BrowseTree>, BrowseEra>(
  (ref, era) => ref.watch(unitHitsProvider).whenData(
        (hits) => browseTree(
          ref.watch(networkProvider),
          era: era,
          hits: hits,
          today: ref.watch(todayProvider),
          carryover: ref.watch(carryoverProvider),
        ),
      ),
);
