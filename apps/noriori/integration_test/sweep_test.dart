import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:noriori/app/session_providers.dart';
import 'package:noriori/features/map/ui/map_home_screen.dart';
import 'package:noriori/i18n/strings.g.dart';
import 'package:noriori/features/record/controller/record_session_controller.dart';
import 'package:noriori/features/record/ui/switchback_mark.dart';
import 'package:noriori/main.dart' as app;

/// 고친 노선·역을 빠짐없이 찍는 순회 시험이다 (tour_test보다 넓다).
///
/// `--dart-define=SWEEP_ROUTES=r_a@2026-11-20|undated|1955-06-01,r_b@undated`처럼 계통과 날짜를 고른다.
/// 기록 화면마다 맨 위부터 한 화면씩 끝까지 내리며 `TOUR_SHOT:`을 찍는다.
/// `SWEEP_SEARCH=dogokoen,Fukuoka Airport`면 찾기 화면에 차례로 넣어 결과를 찍는다.
/// 갈무리는 tools/dev/tour.sh가 simctl로 한다 (TOUR_TEST=integration_test/sweep_test.dart)
const _routes = String.fromEnvironment('SWEEP_ROUTES');
const _search = String.fromEnvironment('SWEEP_SEARCH');
const _lang = String.fromEnvironment('SWEEP_LANG');
const _maxPages = int.fromEnvironment('SWEEP_MAX_PAGES', defaultValue: 400);
const _maps = bool.fromEnvironment('SWEEP_MAPS');
const _details = bool.fromEnvironment('SWEEP_DETAILS');
const _taps = bool.fromEnvironment('SWEEP_TAPS');

Future<void> _wait(WidgetTester tester, bool Function() done, {Duration limit = const Duration(seconds: 90)}) async {
  final end = DateTime.now().add(limit);
  while (!done()) {
    if (DateTime.now().isAfter(end)) fail('$limit 안에 화면이 나오지 않았다');
    await tester.pump(const Duration(milliseconds: 200));
  }
}

var _errors = 0;

Future<void> _shot(WidgetTester tester, String name, {int millis = 1600}) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
  // ignore: avoid_print
  print('TOUR_SHOT:$name');
  final end = DateTime.now().add(Duration(milliseconds: millis));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  // 넘침 같은 그리기 오류는 멈추지 않고 자세한 내용과 함께 적은 뒤 계속 찍는다(끝에 모아서 실패로 센다)
  final ex = tester.takeException();
  if (ex != null) {
    _errors++;
    // ignore: avoid_print
    print('SWEEP_EXCEPTION:$name|${(ex is FlutterError ? ex.toStringDeep() : '$ex').replaceAll('\n', ' ⏎ ')}');
  }
}

ScrollableState? _mainList(WidgetTester tester) {
  ScrollableState? best;
  for (final e in find.byType(Scrollable).evaluate()) {
    final s = (e as StatefulElement).state as ScrollableState;
    if (s.position.axis != Axis.vertical || !s.position.hasContentDimensions) continue;
    if (best == null || s.position.maxScrollExtent > best.position.maxScrollExtent) best = s;
  }
  return best;
}


/// 화면에 보이는 글 상자끼리 겹치는지 본다(서로 다른 글이 6px 넘게 겹치면 SWEEP_OVERLAP). 말줄임된 글은 SWEEP_ELLIPSIS로 따로 적는다
void _layoutCheck(WidgetTester tester, String name) {
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  final boxes = <(RenderParagraph, Rect, String)>[];
  for (final e in find.byType(RichText).evaluate()) {
    final r = e.renderObject;
    if (r is! RenderParagraph || !r.attached || !r.hasSize) continue;
    final text = r.text.toPlainText();
    if (text.trim().isEmpty) continue;
    final origin = r.localToGlobal(Offset.zero);
    final sel = r.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: text.length));
    if (sel.isEmpty) continue;
    var rect = sel.first.toRect();
    for (final b in sel.skip(1)) {
      rect = rect.expandToInclude(b.toRect());
    }
    rect = rect.shift(origin);
    if (rect.bottom < 0 || rect.top > size.height) continue;
    boxes.add((r, rect, text));
    if (r.didExceedMaxLines) {
      // ignore: avoid_print
      print('SWEEP_ELLIPSIS:$name|${text.replaceAll('\n', ' ')}');
    }
  }
  bool related(RenderObject a, RenderObject b) {
    for (RenderObject? x = a.parent; x != null; x = x.parent) {
      if (identical(x, b)) return true;
    }
    for (RenderObject? x = b.parent; x != null; x = x.parent) {
      if (identical(x, a)) return true;
    }
    return false;
  }
  for (var i = 0; i < boxes.length; i++) {
    for (var j = i + 1; j < boxes.length; j++) {
      final o = boxes[i].$2.intersect(boxes[j].$2);
      if (o.width > 6 && o.height > 6 && !related(boxes[i].$1, boxes[j].$1)) {
        // ignore: avoid_print
        print('SWEEP_OVERLAP:$name|${boxes[i].$3.replaceAll('\n', ' ')}|${boxes[j].$3.replaceAll('\n', ' ')}');
      }
    }
  }
}

Future<void> _scrollShots(WidgetTester tester, String tag, {Future<void> Function(int page)? onPage}) async {
  var page = 0;
  while (true) {
    final name = '${tag}_p${page.toString().padLeft(2, '0')}';
    await _shot(tester, name);
    _layoutCheck(tester, name);
    if (onPage != null) await onPage(page);
    final list = _mainList(tester);
    if (list == null) break;
    final pos = list.position;
    if (pos.pixels >= pos.maxScrollExtent - 1 || ++page >= _maxPages) break;
    pos.jumpTo((pos.pixels + pos.viewportDimension * 0.85).clamp(0, pos.maxScrollExtent));
  }
}

String _safe(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('고친 계통·검색어를 끝까지 찍는다', (tester) async {
    app.main();
    await _wait(tester, () => find.byType(MapHomeScreen).evaluate().isNotEmpty);
    for (var i = 0; i < 25 && find.byType(Dialog).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    if (find.byType(Dialog).evaluate().isNotEmpty) {
      await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.byType(FilledButton)).last);
      await tester.pump(const Duration(milliseconds: 500));
    }
    final context = tester.element(find.byType(MapHomeScreen));
    final container = ProviderScope.containerOf(context);
    final router = GoRouter.of(context);
    // 앱 언어는 기기 언어가 아니라 앱 설정이다. 고른 언어로 바꾸고(저장됨) 이름 순서도 따라 바뀐다
    if (_lang.isNotEmpty) {
      await container.read(languageProvider.notifier).set(AppLocale.values.firstWhere((l) => l.languageCode == _lang));
      await tester.pump(const Duration(seconds: 2));
    }
    final network = container.read(networkProvider);
    final session = container.read(recordSessionProvider.notifier);

    final lines = <String>{
      for (final spec in _routes.isEmpty ? const <String>[] : _routes.split(','))
        if (network.routes[spec.split('@').first]?.lineId case final String l) l,
    };
    if (_maps) {
      // 지도: 노선 하나만 강조해 그 노선의 역 점·선을 본다 (지도는 네이티브라 화면 갈무리는 밖에서)
      for (final l in lines) {
        container.read(soloLineIdProvider.notifier).set(l);
        await _shot(tester, 'map_${_safe(l)}', millis: 4500);
      }
      container.read(soloLineIdProvider.notifier).set(null);
    }
    if (_details) {
      for (final l in lines) {
        unawaited(router.push('/line/$l'));
        await _wait(tester, () => _mainList(tester) != null, limit: const Duration(seconds: 30));
        await _scrollShots(tester, 'detail_${_safe(l)}');
        router.pop();
        await tester.pump(const Duration(milliseconds: 400));
      }
    }
    for (final spec in _routes.isEmpty ? const <String>[] : _routes.split(',')) {
      final at = spec.indexOf('@');
      final route = at < 0 ? spec : spec.substring(0, at);
      final days = at < 0 ? const ['undated'] : spec.substring(at + 1).split('|');
      final line = network.routes[route]?.lineId;
      if (line == null) {
        // ignore: avoid_print
        print('SWEEP_MISSING:$route');
        continue;
      }
      for (final day in days) {
        await session.open(lineId: line, routeId: route, dateUnknown: day == 'undated');
        if (day != 'undated' && day != 'today') await session.setDate(day);
        unawaited(router.push('/record/session?back=1'));
        await _wait(tester, () => _mainList(tester) != null, limit: const Duration(seconds: 30));
        final tag = '${_safe(route)}_${_safe(day)}';
        final tapped = <String>{};
        await _scrollShots(tester, tag, onPage: !_taps
            ? null
            : (page) async {
                // 열람 전용 역 줄을 누르면 「기록할 수 없는 옛 역」(이은 노드면 「지금의 ○○역」) 안내, 스위치백 표식을 누르면 말풍선이 뜬다
                final targets = [
                  ...find.byWidgetPredicate((w) => w.runtimeType.toString() == '_ArchiveTile').hitTestable().evaluate().take(2),
                  ...find.byType(SwitchbackMark).hitTestable().evaluate().take(2),
                ];
                for (final (k, e) in targets.indexed) {
                  final key = '${e.widget.runtimeType}#${e.widget.hashCode}';
                  if (!tapped.add(key)) continue;
                  await tester.tapAt(tester.getCenter(find.byElementPredicate((x) => identical(x, e))));
                  for (var i = 0; i < 4; i++) {
                    await tester.pump(const Duration(milliseconds: 150));
                  }
                  await _shot(tester, '${tag}_p${page.toString().padLeft(2, '0')}_tap$k', millis: 900);
                  ScaffoldMessenger.maybeOf(tester.element(find.byType(Scaffold).last))?.hideCurrentSnackBar();
                  await tester.tapAt(const Offset(5, 400));
                  await tester.pump(const Duration(milliseconds: 400));
                }
              });
        router.pop();
        await tester.pump(const Duration(milliseconds: 400));
      }
    }

    final queries = _search.isEmpty ? const <String>[] : _search.split(',');
    for (var qi = 0; qi < queries.length; qi++) {
      final query = queries[qi];
      unawaited(router.push('/search'));
      await _wait(tester, () => find.byType(TextField).evaluate().isNotEmpty, limit: const Duration(seconds: 20));
      await tester.enterText(find.byType(TextField).first, query);
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      // 한자·한글 검색어는 파일 이름에서 지워지므로 순번을 붙인다
      await _shot(tester, 'search_${qi.toString().padLeft(2, '0')}_${_safe(query)}');
      _layoutCheck(tester, 'search_$qi');
      router.pop();
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(_errors, 0, reason: '그리기 오류 $_errors건 (SWEEP_EXCEPTION 줄)');
  }, timeout: const Timeout(Duration(minutes: 600)));
}
