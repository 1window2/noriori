import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noriori/app/theme/app_theme.dart';
import 'package:noriori/app/theme/tokens.dart';
import 'package:noriori/features/record/ui/map_sheets.dart';
import 'package:noriori/i18n/strings.g.dart';
import 'package:noriori_core/noriori_core.dart';

const _today = '2026-11-05';

NetAttr _attr(String edge, String line, String to) => NetAttr(
      edgeId: edge,
      lineId: line,
      operatorId: 'o',
      lineageId: 'lg-$line',
      carryoverGroup: 'c-$line',
      period: NetPeriod(fromLo: '1900-01-01', fromHi: '1900-01-01', toLo: to, toHi: to),
    );

/// e1 하나를 현행 a, 일부 폐지 c(e2에서 영업), 전체 폐선 d가 함께 지난다. 행은 일부러 섞어 둔다.
final _network = Network(
  NetworkData(
    routes: const [],
    edges: const [
      NetEdge(id: 'e1', n: 1, from: 'x', to: 'y', meters: 100),
      NetEdge(id: 'e2', n: 2, from: 'y', to: 'z', meters: 100),
    ],
    routeEdges: const [],
    stops: const [],
    attrs: [
      _attr('e1', 'd', '1980-01-01'),
      _attr('e1', 'c', '1990-01-01'),
      _attr('e1', 'a', DateSpan.maxDate),
      _attr('e2', 'c', DateSpan.maxDate),
    ],
    lives: const [],
    units: const [],
    publicNodes: const {},
    nodeGroups: const {},
    lineOrder: const ['d', 'c', 'a'],
  ),
);

const _names = {'a': '현행선', 'c': '일부폐지선', 'd': '폐선선'};

Future<(List<String>, List<String>)> _pump(WidgetTester tester, {Offset at = const Offset(160, 200)}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final picked = <String>[];
  final info = <String>[];
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        theme: appTheme(Brightness.light),
        home: Scaffold(
          body: LinePicker(
            at: at,
            lines: tappedLines(_network, const [1], today: _today),
            names: _names,
            onPick: picked.add,
            onInfo: info.add,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return (picked, info);
}

Color? _color(WidgetTester tester, String label) => tester.widget<Text>(find.text(label)).style?.color;

void main() {
  testWidgets('줄은 현행, 일부 폐지, 전체 폐선 순이다', (tester) async {
    await _pump(tester);
    final tops = [for (final name in ['현행선', '일부폐지선', '폐선선']) tester.getTopLeft(find.text(name)).dy];
    expect(tops, orderedEquals([...tops]..sort()));
    expect(tops.toSet(), hasLength(3));
    expect(find.text('이 구간 폐지'), findsOneWidget);
    expect(find.text('폐선'), findsOneWidget);
  });

  testWidgets('폐선 줄은 폐역 글자 색으로 흐리고 현행 줄은 본문 색이다', (tester) async {
    await _pump(tester);
    expect(_color(tester, '현행선'), AppTokens.light.text);
    expect(_color(tester, '일부폐지선'), AppTokens.light.textClosed);
    expect(_color(tester, '폐선선'), AppTokens.light.textClosed);
    expect(_color(tester, '폐선'), AppTokens.light.textClosed);
  });

  testWidgets('줄을 누르면 기록으로, 정보 단추는 노선 상세로 간다', (tester) async {
    final (picked, info) = await _pump(tester);
    await tester.tap(find.text('일부폐지선'));
    expect(picked, ['c']);
    expect(info, isEmpty);
    final buttons = find.byIcon(Icons.info_outline);
    expect(buttons, findsNWidgets(3));
    await tester.tap(buttons.last);
    expect(info, ['d']);
    expect(picked, ['c']);
  });

  testWidgets('줄과 정보 단추의 터치 영역은 48dp 이상이다', (tester) async {
    await _pump(tester);
    for (final name in _names.values) {
      final row = find.ancestor(of: find.text(name), matching: find.byType(InkWell)).first;
      expect(tester.getSize(row).height, greaterThanOrEqualTo(48), reason: name);
    }
    for (final button in tester.widgetList(find.byType(IconButton))) {
      final size = tester.getSize(find.byWidget(button));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('카드는 누른 자리 바로 아래에 뜨고 아래가 모자라면 위로 간다', (tester) async {
    await _pump(tester);
    final card = find.descendant(of: find.byType(LinePicker), matching: find.byType(Material)).first;
    var rect = tester.getRect(card);
    expect(rect.top, greaterThan(200));
    expect(rect.top, lessThan(240));
    expect(rect.left, greaterThanOrEqualTo(16));
    expect(rect.right, lessThanOrEqualTo(360 - 16));

    await _pump(tester, at: const Offset(350, 600));
    rect = tester.getRect(card);
    expect(rect.bottom, lessThan(600));
    expect(rect.right, lessThanOrEqualTo(360 - 16));
  });
}
