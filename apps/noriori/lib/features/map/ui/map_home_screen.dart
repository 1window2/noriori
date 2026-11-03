import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/session_providers.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/pills.dart';
import '../../../i18n/strings.g.dart';
import '../map_style.dart';

/// 탑승 칠하기 (ARCHITECTURE §2.6 후보 A). 방식이 바뀌어도 화면은 이 뒤를 모른다.
abstract interface class MapPaintPort {
  Future<void> paint(Set<int> edges);
}

final class _FilterPaint implements MapPaintPort {
  const _FilterPaint(this._map, this._suffixes, this._closed);

  final MapLibreMapController _map;
  final List<String> _suffixes;
  final Set<int> _closed;

  /// 층마다 그 층에 있는 구간만 보낸다. 식이 작을수록 저장 뒤 칠하기가 빠르다 (ARCHITECTURE §2.6).
  @override
  Future<void> paint(Set<int> edges) async {
    final closed = edges.intersection(_closed);
    final current = edges.difference(_closed);
    for (final suffix in _suffixes) {
      await _map.setFilter('$riddenCurrentLayer$suffix', riddenFilter(current, closed: false));
      await _map.setFilter('$riddenClosedLayer$suffix', riddenFilter(closed, closed: true));
    }
  }
}

/// 지도에서 누른 것.
final class MapFeature {
  const MapFeature.station(String this.node) : edge = null, marker = null;

  const MapFeature.edge(int this.edge) : node = null, marker = null;

  const MapFeature.marker(int this.marker) : node = null, edge = null;

  final String? node;
  final int? edge;
  final int? marker;
}

/// 일본 전체. 첫 화면은 빈 바다 대신 이 범위에 꽉 맞춘다.
final _japan = LatLngBounds(
  southwest: const LatLng(30.4, 128.9),
  northeast: const LatLng(45.6, 145.9),
);

/// 지도 홈. 지도가 주인공이고 점수는 작은 캡슐이다.
class MapHomeScreen extends ConsumerStatefulWidget {
  const MapHomeScreen({
    super.key,
    this.notice,
    this.sheet,
    this.sheetHeight = 0,
    this.onFeature,
  });

  /// 기능끼리 직접 만나지 않도록 안내와 시트는 앱이 끼워 준다.
  final Widget? notice;
  final Widget? sheet;
  final double sheetHeight;

  /// 역이나 선로를 눌렀다. 시트는 앱이 끼워 준다.
  final void Function(MapFeature feature)? onFeature;

  @override
  ConsumerState<MapHomeScreen> createState() => _MapHomeScreenState();
}

class _MapHomeScreenState extends ConsumerState<MapHomeScreen> {
  MapLibreMapController? _map;
  MapPaintPort? _painter;
  bool _onlyRidden = false;
  bool _showNames = true;

  /// 도도부현 히트맵.
  bool _heat = false;

  /// 히트맵이 보이는 배율인가. 범례가 따라간다.
  bool _heatInView = true;
  bool _heatPainted = false;

  Timer? _refreshTimer;
  bool _refreshing = false;
  bool _wantPaint = false;
  bool _flushing = false;

  /// 타임 슬라이더의 해. 켜지 않았으면 null이다.
  int? _year;
  int? _shownYear;
  bool _painting = false;

  /// 테마가 바뀌어도 보던 자리를 지키도록 처음 한 번만 맞춘다.
  bool _fitted = false;

  /// 눌린 자리의 역이나 선로를 찾아 시트를 연다. 손가락 크기만큼 넓게 본다.
  Future<void> _tapped(math.Point<double> point) async {
    final map = _map;
    final sheet = widget.onFeature;
    if (map == null || sheet == null) return;
    // Android는 눌린 자리와 사각형이 물리 픽셀이고 iOS는 논리 픽셀이다
    final android = Theme.of(context).platform == TargetPlatform.android;
    final reach = 16.0 * (android ? MediaQuery.devicePixelRatioOf(context) : 1);
    final box = Rect.fromCenter(
      center: Offset(point.x, point.y),
      width: reach * 2,
      height: reach * 2,
    );
    Future<List<Object?>> at(List<String> layers) async =>
        (await map.queryRenderedFeaturesInRect(box, layers, null)).cast<Object?>();
    final markers = await at([
      for (final suffix in _suffixes) ...['$markerLayer$suffix', '$markerRiddenLayer$suffix'],
    ]);
    if (markers.isNotEmpty) {
      final map = markers.first! as Map<Object?, Object?>;
      final id = (map['properties'] as Map<Object?, Object?>)['m'];
      if (id is num && mounted) sheet(MapFeature.marker(id.toInt()));
      return;
    }
    final stations = await at([
      for (final suffix in _suffixes) ...[
        '$stationLayer$suffix',
        '$stationClosedLayer$suffix',
        '$stationPassedLayer$suffix',
        '$stationSteppedLayer$suffix',
      ],
    ]);
    final lines = stations.isNotEmpty
        ? const <Object?>[]
        : await at([
            for (final suffix in _suffixes) ...[
              '$riddenCurrentLayer$suffix',
              '$riddenClosedLayer$suffix',
              '$railLayer$suffix',
              '$railClosedLayer$suffix',
            ],
          ]);
    Map<String, Object?> props(Object? feature) {
      final map = feature as Map<Object?, Object?>;
      return (map['properties'] as Map<Object?, Object?>).cast<String, Object?>();
    }

    if (!mounted) return;
    if (stations.isNotEmpty) {
      final node = props(stations.first)['node'];
      if (node is String) sheet(MapFeature.station(node));
    } else if (lines.isNotEmpty) {
      final edge = props(lines.first)['n'];
      if (edge is num) sheet(MapFeature.edge(edge.toInt()));
    }
  }

  List<String> get _suffixes => [
        '',
        if (ref.read(osmTilesProvider) != null) osmSuffix,
      ];

  /// 저장 한 번이 스트림 여럿을 깨운다. 플랫폼 호출이 몰리지 않게 한 번으로 묶는다.
  void _refreshMap({bool paint = false}) {
    _wantPaint = _wantPaint || paint;
    _refreshing = true;
    _refreshTimer?.cancel();
    _refreshTimer = Timer(const Duration(milliseconds: 24), () => unawaited(_flushMap()));
  }

  Future<void> _flushMap() async {
    if (_flushing) return;
    _flushing = true;
    while (_refreshing && mounted) {
      final paint = _wantPaint;
      _refreshing = false;
      _wantPaint = false;
      await (paint ? _repaint() : _applyLayers());
    }
    _flushing = false;
  }

  Future<void> _repaint() async {
    final painter = _painter;
    final edges = ref.read(riddenEdgesProvider).value;
    if (painter == null || edges == null) return;
    final year = _year;
    await painter.paint(
      year == null
          ? ref.read(soloLineProvider)?.ridden ?? edges
          : {
              for (final MapEntry(key: edge, value: first) in (ref.read(riddenYearsProvider).value ?? const <int, int>{}).entries)
                if (first <= year) edge,
            },
    );
    await _applyLayers();
  }

  /// 칠하기 뒤에 언제나 돈다. 저장으로 다시 칠해도 끈 층이 되살아나면 안 된다.
  Future<void> _applyLayers() async {
    final map = _map;
    if (map == null || _painter == null) return;
    final solo = ref.read(soloLineProvider);
    final ridden = solo?.groups ?? (_onlyRidden ? _riddenGroups() : null);
    final year = _year;
    // 옛 철도망을 보는 중이면 폐선을 끈 설정보다 그해의 모습이 먼저다
    final showClosed = year != null || ref.read(displayOptionsProvider).showClosed;
    for (final suffix in _suffixes) {
      await map.setFilter('$railLayer$suffix', railFilter(closed: false, only: solo?.edges, year: year));
      await map.setFilter('$railClosedLayer$suffix', railFilter(closed: true, only: solo?.edges, year: year));
      await map.setLayerVisibility('$railLayer$suffix', !_onlyRidden);
      await map.setLayerVisibility('$railClosedLayer$suffix', showClosed && !_onlyRidden);
      await map.setLayerVisibility('$riddenClosedLayer$suffix', showClosed);
      await map.setLayerVisibility('$stationClosedLayer$suffix', showClosed);
      await map.setLayerVisibility('$stationNameLayer$suffix', _showNames);
    }
    await _applyMarkers(map, solo, showClosed);
    await _applyHeat(map);
    final marks = ref.read(stationMarksProvider);
    // 탄 역 표시는 지금 기준이라 과거 화면에서는 비운다
    Set<int> shown(Set<int> groups) => year != null
        ? const {}
        : (solo == null ? groups : groups.intersection(solo.groups));
    for (final suffix in _suffixes) {
      await map.setFilter('$stationPassedLayer$suffix', markFilter(shown(marks.passed), showClosed: showClosed));
      await map.setFilter('$stationSteppedLayer$suffix', markFilter(shown(marks.stepped), showClosed: showClosed));
      await map.setFilter('$stationLayer$suffix', stationFilter(closed: false, ridden: ridden, year: year));
      await map.setFilter('$stationClosedLayer$suffix', stationFilter(closed: true, ridden: ridden, year: year));
      await map.setFilter(
        '$stationNameLayer$suffix',
        stationNameFilter(showClosed: showClosed, ridden: ridden, year: year),
      );
    }
  }


  /// 통계의 타일 지도와 같은 값으로 칠한다.
  Future<void> _applyHeat(MapLibreMapController map) async {
    if (ref.read(baseTilesProvider) == null) return;
    // 꺼진 채로 있으면 고칠 것이 없다. 저장마다 필터 네 개를 보내지 않는다
    if (!_heat && !_heatPainted) return;
    _heatPainted = _heat;
    final levels = List.generate(heatLevels.length, (_) => <int>{});
    if (_heat) {
      for (final MapEntry(key: pref, value: score) in ref.read(prefScoresProvider(const BasisCurrent())).entries) {
        if (heatLevel(score.ratio) case final level?) levels[level].add(pref);
      }
    }
    for (final (level, prefs) in levels.indexed) {
      await map.setFilter('$heatLayer$level', heatFilter(prefs));
    }
  }

  /// 수록 기준일의 해.
  static const _firstYear = 1970;

  void _toggleYear(int thisYear) {
    setState(() => _year = _year == null ? thisYear : null);
    unawaited(_repaint());
  }

  /// 끌 때마다 칠하면 밀린다. 그리는 중이면 마지막 해만 남겼다가 이어서 칠한다.
  Future<void> _slide(int year) async {
    setState(() => _year = year);
    if (_painting) return;
    _painting = true;
    while (_shownYear != _year) {
      _shownYear = _year;
      await _repaint();
    }
    _painting = false;
  }

  Set<int> _riddenGroups() {
    final data = ref.read(networkProvider).data;
    return {
      for (final node in ref.read(riddenNodesProvider).value ?? const <String>{})
        ?data.groupNumbers[data.nodeGroups[node]],
    };
  }

  /// 탄 구간의 표식은 빨강이다. 승차만 볼 때는 탄 것만 남긴다.
  Future<void> _applyMarkers(MapLibreMapController map, SoloLine? solo, bool showClosed) async {
    final soloLine = ref.read(soloLineIdProvider);
    final markers = [
      for (final marker in ref.read(mapMarkersProvider).value ?? const <MapMarker>[])
        if (soloLine == null || marker.lineId == soloLine) marker,
    ];
    final ridden = ref.read(riddenEdgesProvider).value ?? const <int>{};
    final hit = {
      for (final marker in markers)
        if (marker.edges.any(ridden.contains)) marker.id,
    };
    final rest = _onlyRidden ? const <int>{} : {for (final marker in markers) marker.id}.difference(hit);
    final visible = showClosed && _year == null;
    for (final suffix in _suffixes) {
      await map.setFilter('$markerLayer$suffix', markerFilter(visible ? rest : const {}));
      await map.setFilter('$markerRiddenLayer$suffix', markerFilter(visible ? hit : const {}));
    }
  }

  /// 꼬리 그림. 위로 갈수록 사라지는 점선이다. 16dp를 세 배로 그린다.
  /// 지도 라이브러리가 PNG를 화면 배율로 읽으므로 3배 화면에서 제 크기다.
  Future<Uint8List> _tail(Color color) async {
    const width = 12.0;
    const height = 48.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (var dash = 0; dash < 3; dash++) {
      final paint = Paint()
        ..color = color.withValues(alpha: 1 - dash * .3)
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round;
      final bottom = height - dash * 16.0 - 4;
      canvas.drawLine(Offset(width / 2, bottom), Offset(width / 2, bottom - 7), paint);
    }
    final image = await recorder.endRecording().toImage(width.toInt(), height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  Future<void> _addMarkerImages() async {
    final map = _map;
    if (map == null) return;
    final tokens = context.tokens;
    final plain = await _tail(tokens.lineClosedUnridden);
    final red = await _tail(tokens.lineClosedRidden);
    await map.addImage(markerImage, plain);
    await map.addImage(markerRiddenImage, red);
  }

  /// 단독 보기를 켜면 그 노선에 맞춘다.
  Future<void> _fitLine(SoloLine solo) async {
    final box = await ref.read(packReaderProvider).boundsOf(solo.nodes);
    if (box == null || !mounted) return;
    final padding = MediaQuery.paddingOf(context);
    await _map?.moveCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(box.south, box.west),
          northeast: LatLng(box.north, box.east),
        ),
        left: 32,
        right: 32,
        top: padding.top + 160,
        // 전국 보기 단추에 끝 역이 가리지 않게 띄운다
        bottom: widget.sheetHeight + 88,
      ),
    );
  }

  Future<void> _fitJapan() async {
    final padding = MediaQuery.paddingOf(context);
    await _map?.moveCamera(
      CameraUpdate.newLatLngBounds(
        _japan,
        left: 8,
        right: 8,
        top: padding.top + 96,
        bottom: widget.sheetHeight + 8,
      ),
    );
  }

  void _toggle(void Function() change) {
    setState(change);
    unawaited(_repaint());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(riddenEdgesProvider, (_, next) => _refreshMap(paint: true));
    ref.listen(riddenNodesProvider, (_, next) => _refreshMap());
    ref.listen(stationMarksProvider, (_, next) => _refreshMap());
    ref.listen(displayOptionsProvider, (_, next) => _refreshMap());
    ref.listen(mapMarkersProvider, (_, next) => _refreshMap());
    ref.listen(soloLineProvider, (before, next) {
      unawaited(_repaint());
      if (next != null && before == null) unawaited(_fitLine(next));
    });
    final showClosed = ref.watch(displayOptionsProvider).showClosed;
    final tokens = context.tokens;
    final score = ref.watch(scoreTableProvider(const BasisCurrent())).value?.total;
    final t = context.t.map;
    final sheet = widget.sheet;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: tokens.land),
        MapLibreMap(
          styleString: railStyle(
            tiles: ref.watch(railTilesProvider),
            osmTiles: ref.watch(osmTilesProvider),
            baseTiles: ref.watch(baseTilesProvider),
            glyphs: ref.watch(glyphsProvider),
            tokens: tokens,
          ),
          initialCameraPosition: const CameraPosition(target: LatLng(36.5, 137.5), zoom: 4.2),
          minMaxZoomPreference: const MinMaxZoomPreference(3.5, 17.5),
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
          compassEnabled: false,
          attributionButtonPosition: AttributionButtonPosition.bottomLeft,
          attributionButtonMargins: math.Point(10, widget.sheetHeight + 10),
          attributionButtonColor: tokens.textMuted,
          trackCameraPosition: true,
          onMapCreated: (map) => _map = map,
          onMapClick: (point, _) => unawaited(_tapped(point)),
          onCameraIdle: () {
            final zoom = _map?.cameraPosition?.zoom;
            if (zoom != null && (zoom < heatMaxZoom) != _heatInView) {
              setState(() => _heatInView = zoom < heatMaxZoom);
            }
          },
          onStyleLoadedCallback: () {
            _painter = _FilterPaint(_map!, _suffixes, ref.read(networkProvider).closedEdges);
            if (!_fitted) {
              _fitted = true;
              unawaited(_fitJapan());
            }
            unawaited(_addMarkerImages().then((_) => _repaint()));
          },
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SearchBar(label: t.search, score: score, tag: t.scoreLabel),
                FilterPillRow(
                  left: 0,
                  clip: Clip.none,
                  pills: [
                    FilterPill(
                      label: t.onlyRidden,
                      selected: _onlyRidden,
                      elevated: true,
                      onTap: () => _toggle(() => _onlyRidden = !_onlyRidden),
                    ),
                    FilterPill(
                      label: t.closed,
                      selected: showClosed,
                      elevated: true,
                      onTap: () => ref
                          .read(displayOptionsProvider.notifier)
                          .update(showClosed: !showClosed),
                    ),
                    FilterPill(
                      label: t.names,
                      selected: _showNames,
                      elevated: true,
                      onTap: () => _toggle(() => _showNames = !_showNames),
                    ),
                    if (ref.watch(baseTilesProvider) != null)
                      FilterPill(
                        label: t.heat,
                        selected: _heat,
                        elevated: true,
                        onTap: () => _toggle(() => _heat = !_heat),
                      ),
                    FilterPill(
                      label: t.year,
                      selected: _year != null,
                      elevated: true,
                      onTap: () => _toggleYear(int.parse(ref.read(todayProvider).substring(0, 4))),
                    ),
                  ],
                ),
                if (ref.watch(soloLineIdProvider) case final solo?)
                  FilterPill(
                    label: '${ref.watch(nameBookProvider).lines[solo] ?? solo} · ${t.soloOff}',
                    selected: true,
                    elevated: true,
                    onTap: () => ref.read(soloLineIdProvider.notifier).set(null),
                  ),
                if (_heat && _heatInView)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: tokens.paper,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: softShadow,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 3,
                          children: [
                            Text('0%', style: Theme.of(context).textTheme.labelSmall),
                            for (final opacity in heatLevels)
                              SizedBox(
                                width: 20,
                                height: 8,
                                child: ColoredBox(color: tokens.lineRidden.withValues(alpha: opacity)),
                              ),
                            Text('50%+', style: Theme.of(context).textTheme.labelSmall),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_year case final year?)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: tokens.paper,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: softShadow,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 6, 6, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(context.t.stats.yearLabel(year: year), style: Theme.of(context).textTheme.titleMedium),
                                Expanded(
                                  child: Slider(
                                    value: year.toDouble(),
                                    min: _firstYear.toDouble(),
                                    max: double.parse(ref.watch(todayProvider).substring(0, 4)),
                                    divisions: int.parse(ref.watch(todayProvider).substring(0, 4)) - _firstYear,
                                    onChanged: (value) => _slide(value.round()),
                                  ),
                                ),
                              ],
                            ),
                            Text(t.yearHint, style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ),
                  ),
                ?widget.notice,
              ],
            ),
          ),
        ),
        Positioned(
          right: 14,
          bottom: widget.sheetHeight + 14,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.paper,
              borderRadius: BorderRadius.circular(14),
              boxShadow: softShadow,
            ),
            child: IconButton(
              tooltip: t.wholeJapan,
              icon: Icon(Icons.zoom_out_map, size: 22, color: tokens.text),
              onPressed: _fitJapan,
            ),
          ),
        ),
        // 시트가 스스로 높이를 정한다. 끌어 올리면 지도를 덮는다
        ?sheet,
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.label, required this.score, required this.tag});

  final String label;
  final Score? score;
  final String tag;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    final value = score;
    return GestureDetector(
      onTap: () => context.push('/search'),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
        decoration: BoxDecoration(
          color: tokens.paper,
          borderRadius: BorderRadius.circular(999),
          boxShadow: softShadow,
        ),
        child: Row(
          spacing: 8,
          children: [
            Icon(Icons.search, size: 20, color: tokens.textMuted),
            Expanded(
              child: Text(label, style: text.bodyMedium?.copyWith(fontSize: 15, color: tokens.textMuted)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: tokens.text, borderRadius: BorderRadius.circular(999)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                spacing: 5,
                children: [
                  Text(
                    value == null ? '–' : percentLabel(value),
                    style: text.titleSmall?.copyWith(fontSize: 15, color: tokens.surface),
                  ),
                  Text(tag, style: text.labelSmall?.copyWith(color: tokens.surface)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
