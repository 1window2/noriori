import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:noriori/features/map/fit_camera.dart';

double _x(double lon, double zoom) => (lon + 180) / 360 * 512 * math.pow(2, zoom);
double _y(double lat, double zoom) {
  final r = lat * math.pi / 180;
  return (1 - math.log(math.tan(r) + 1 / math.cos(r)) / math.pi) / 2 * 512 * math.pow(2, zoom);
}

void main() {
  // 지도 402×783, 위 246·아래 260·양옆 32 여백 안에 상자 네 모서리가 다 들어가고, 한쪽은 꽉 찬다
  for (final (name, s, w, n, e) in [
    ('東野田沢上江町線(세로)', 34.699796, 135.52251, 34.708352, 135.528408),
    ('御黒門線(가로)', 35.157507, 136.901085, 35.157879, 136.906245),
    ('常磐線(긴 노선)', 35.73, 139.77, 38.26, 140.92),
  ]) {
    test('상자가 여백 안에 든다: $name', () {
      const width = 402.0, height = 783.0, left = 32.0, top = 246.0, right = 32.0, bottom = 260.0;
      final c = fitCamera(south: s, west: w, north: n, east: e, width: width, height: height, left: left, top: top, right: right, bottom: bottom);
      final ox = _x(c.lon, c.zoom) - width / 2, oy = _y(c.lat, c.zoom) - height / 2;
      final x0 = _x(w, c.zoom) - ox, x1 = _x(e, c.zoom) - ox, y0 = _y(n, c.zoom) - oy, y1 = _y(s, c.zoom) - oy;
      expect(x0, greaterThanOrEqualTo(left - 0.01));
      expect(x1, lessThanOrEqualTo(width - right + 0.01));
      expect(y0, greaterThanOrEqualTo(top - 0.01));
      expect(y1, lessThanOrEqualTo(height - bottom + 0.01));
      final fullX = (x0 - left).abs() < 0.01 && (x1 - (width - right)).abs() < 0.01;
      final fullY = (y0 - top).abs() < 0.01 && (y1 - (height - bottom)).abs() < 0.01;
      expect(fullX || fullY, isTrue);
    });
  }
  test('점 하나는 최대 배율로 그 점에 맞춘다', () {
    final c = fitCamera(south: 35, west: 139, north: 35, east: 139, width: 400, height: 800, left: 0, top: 0, right: 0, bottom: 0);
    expect(c.zoom, 17.5);
    expect(c.lat, closeTo(35, 1e-9));
    expect(c.lon, closeTo(139, 1e-9));
  });
}
