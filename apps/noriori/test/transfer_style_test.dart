import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:noriori/app/theme/tokens.dart';
import 'package:noriori/features/map/map_style.dart';

/// 환승역의 통합 노드·승강장 노드·연결선 (DESIGN §7.5).
void main() {
  markTests();
  final layers = [
    for (final layer in (jsonDecode(railStyle(tiles: 'rail.pmtiles', tokens: AppTokens.light)) as Map)['layers'] as List)
      layer as Map<String, Object?>,
  ];
  int indexOf(String id) => layers.indexWhere((layer) => layer['id'] == id);

  test('연결선은 선로 아래에 그리고 승강장 노드와 함께 많이 확대한 뒤부터 보인다', () {
    expect(indexOf(spokeLayer), lessThan(indexOf(railLayer)));
    expect(indexOf(spokeLayer), lessThan(indexOf(railClosedLayer)));
    for (final id in [spokeLayer, platformLayer]) {
      expect(layers[indexOf(id)]['minzoom'], platformMinZoom);
    }
  });

  test('간접 환승 선은 주황 점선으로 선로 아래에 그린다 (§7.5)', () {
    final walk = layers[indexOf(walkLayer)];
    expect(indexOf(walkLayer), lessThan(indexOf(railLayer)));
    expect((walk['paint'] as Map)['line-color'], '#d2691e');
    expect((walk['paint'] as Map)['line-dasharray'], isNotNull);
  });

  test('통합 노드는 줌 제한 없이 역 점 위에 그린다', () {
    final hub = layers[indexOf(hubNodeLayer)];
    expect(hub.containsKey('minzoom'), isFalse);
    expect(indexOf(hubNodeLayer), greaterThan(indexOf(stationLayer)));
    expect(indexOf(hubNameLayer), greaterThan(indexOf(hubNodeLayer)));
  });

  test('환승역 배치에 들어간 역(sh)은 기존 역 점과 이름에서 빠진다', () {
    expect(stationFilter(closed: false), anyElement(equals(['!', ['has', 'sh']])));
    expect(stationNameFilter(showClosed: true), anyElement(equals(['!', ['has', 'sh']])));
  });
}

void markTests() {
  test('환승역의 탄 표시는 노드 id로 고르고 통합 노드 위에 그린다', () {
    expect(transferMarkFilter(const {}, showClosed: true), anyElement(equals(['==', ['get', 'node'], ''])));
    expect(
      transferMarkFilter(const {'n_b', 'n_a'}, showClosed: false),
      anyElement(equals(['match', ['get', 'node'], ['n_a', 'n_b'], true, false])),
    );
    final layers = [
      for (final layer in (jsonDecode(railStyle(tiles: 'rail.pmtiles', tokens: AppTokens.light)) as Map)['layers'] as List)
        (layer as Map)['id'],
    ];
    expect(layers.indexOf(hubSteppedLayer), greaterThan(layers.indexOf(hubNodeLayer)));
    expect(layers.indexOf(platformSteppedLayer), greaterThan(layers.indexOf(platformLayer)));
  });
}
