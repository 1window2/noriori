import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noriori/app/session_providers.dart';
import 'package:noriori/features/map/ui/map_home_screen.dart';
import 'package:noriori/features/record/controller/record_session_controller.dart';
import 'package:noriori/main.dart' as app;

/// 에뮬레이터·시뮬레이터에서 대표 노선의 지도·노선 상세·기록 화면을 차례로 띄운다.
///
/// 화면마다 `TOUR_SHOT:<이름>`을 찍고 잠깐 멈춘다. 화면 갈무리는 밖에서 한다(지도는 네이티브 화면이라
/// 앱 안 갈무리에 안 잡힌다). `tools/dev/tour.sh <기기>`가 이 줄을 보고 simctl·adb로 찍는다.
const _lines = [
  'l_tokaido_main_line', 'l_yamanote_line', 'l_chuo_main_line', 'l_joetsu_line', 'l_tohoku_main_line',
  'l_ou_main_line', 'l_tazawako_line', 'l_hakodate_main_line', 'l_nemuro_main_line', 'l_osaka_loop_line',
  'l_keishin_line', 'l_kyoto_line', 'l_keio_line', 'l_chiba_line', 'l_hokuso_line', 'l_keikyu_airport_line',
  'l_hibiya_line', 'l_namboku_line', 'l_seibu_yurakucho_line', 'l_jr_tozai_line', 'l_ashio_line',
  'l_takachiho_line', 'l_hiroden_main_line', 'l_miyajima_line', 'l_nagasaki_tram_main_line',
  'l_oura_branch_line', 'l_yagi_connecting_line', 'l_tateyama_cable_car', 'l_kurobe_cable_car',
  'l_miike_railway_main_line',
];

/// `--dart-define=TOUR_LINES=l_a,l_b`로 노선을 고르고, `TOUR_SESSION_ONLY=true`면 기록 화면만,
/// `TOUR_SCROLL_END=true`면 기록 화면을 맨 아래까지 내려 한 장 더 찍는다(끝 역 주변 확인용)
const _pick = String.fromEnvironment('TOUR_LINES');
const _sessionOnly = bool.fromEnvironment('TOUR_SESSION_ONLY');
const _scrollEnd = bool.fromEnvironment('TOUR_SCROLL_END');
final _tour = _pick.isEmpty ? _lines : _pick.split(',');

Future<void> _wait(WidgetTester tester, bool Function() done, {Duration limit = const Duration(seconds: 90)}) async {
  final end = DateTime.now().add(limit);
  while (!done()) {
    if (DateTime.now().isAfter(end)) fail('$limit 안에 화면이 나오지 않았다');
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// 밖에서 찍을 시간을 준다.
Future<void> _shot(WidgetTester tester, String name, {int seconds = 4}) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  // ignore: avoid_print
  print('TOUR_SHOT:$name');
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(tester.takeException(), isNull, reason: name);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('대표 노선의 지도·노선 상세·기록 화면을 차례로 띄운다', (tester) async {
    app.main();
    await _wait(tester, () => find.byType(MapHomeScreen).evaluate().isNotEmpty);
    // 판이 바뀌면 뜨는 「철도망이 바뀌었습니다」 안내를 닫는다 (찍는 화면을 가리지 않게)
    for (var i = 0; i < 25 && find.byType(Dialog).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    if (find.byType(Dialog).evaluate().isNotEmpty) {
      await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.byType(FilledButton)).last);
      await tester.pump(const Duration(milliseconds: 500));
    }
    if (!_sessionOnly) await _shot(tester, 'map_japan', seconds: 6);
    final context = tester.element(find.byType(MapHomeScreen));
    final container = ProviderScope.containerOf(context);
    final router = GoRouter.of(context);
    for (final lineId in _sessionOnly ? const <String>[] : _tour) {
      container.read(soloLineIdProvider.notifier).set(lineId);
      await _shot(tester, 'map_$lineId', seconds: 5);
    }
    container.read(soloLineIdProvider.notifier).set(null);
    final network = container.read(networkProvider);
    for (final lineId in _tour) {
      if (!_sessionOnly) {
        unawaited(router.push('/line/$lineId'));
        await _shot(tester, 'detail_$lineId', seconds: 2);
        router.pop();
      }
      final route = network.routesOfLineMainFirst(lineId).first;
      for (final unknown in const [false, true]) {
        await container.read(recordSessionProvider.notifier).open(lineId: lineId, routeId: route, dateUnknown: unknown);
        unawaited(router.push('/record/session?back=1'));
        await _shot(tester, 'session_${lineId}_${unknown ? 'undated' : 'today'}', seconds: 2);
        if (_scrollEnd) {
          final lists = find.byType(Scrollable).evaluate().map((e) => (e as StatefulElement).state as ScrollableState);
          for (final list in lists) {
            if (list.position.axis == Axis.vertical) list.position.jumpTo(list.position.maxScrollExtent);
          }
          await _shot(tester, 'session_${lineId}_${unknown ? 'undated' : 'today'}_end', seconds: 2);
        }
        router.pop();
      }
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}
