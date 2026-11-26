import 'dart:math' as math;

/// 경계 상자를 지도 크기와 여백 안에 맞추는 가운데·배율을 웹 메르카토르로 직접 구한다.
/// MapLibre iOS의 경계 맞춤(cameraThatFitsCoordinateBounds)은 고도로 바꾸는 과정에서 배율이 9~34% 크게 나와
/// 단독 보기의 끝 역이 화면·시트 밖으로 나갔다 (기기 순회 2026-11-26 大阪市電東野田沢上江町線·名古屋市電御黒門線).
/// MapLibre의 배율 z에서 세계 폭은 512·2^z 포인트다.
({double lat, double lon, double zoom}) fitCamera({
  required double south,
  required double west,
  required double north,
  required double east,
  required double width,
  required double height,
  required double left,
  required double top,
  required double right,
  required double bottom,
  double minZoom = 3.5,
  double maxZoom = 17.5,
}) {
  double x(double lon) => (lon + 180) / 360;
  double y(double lat) {
    final r = lat * math.pi / 180;
    return (1 - math.log(math.tan(r) + 1 / math.cos(r)) / math.pi) / 2;
  }

  double lat(double y) => math.atan(_sinh(math.pi * (1 - 2 * y))) * 180 / math.pi;
  final dx = (x(east) - x(west)).abs();
  final dy = (y(south) - y(north)).abs();
  final roomW = math.max(1.0, width - left - right);
  final roomH = math.max(1.0, height - top - bottom);
  final zx = dx == 0 ? maxZoom : math.log(roomW / (512 * dx)) / math.ln2;
  final zy = dy == 0 ? maxZoom : math.log(roomH / (512 * dy)) / math.ln2;
  final zoom = math.min(zx, zy).clamp(minZoom, maxZoom).toDouble();
  // 상자 가운데를 여백 안쪽 가운데에 둔다. 지도 가운데는 그만큼 반대로 옮긴 자리다
  final world = 512 * math.pow(2, zoom);
  final cx = (x(west) + x(east)) / 2 - (left - right) / 2 / world;
  final cy = (y(north) + y(south)) / 2 - (top - bottom) / 2 / world;
  return (lat: lat(cy), lon: cx * 360 - 180, zoom: zoom);
}

double _sinh(double v) => (math.exp(v) - math.exp(-v)) / 2;
