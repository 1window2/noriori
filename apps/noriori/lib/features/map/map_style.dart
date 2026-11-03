import 'dart:convert';
import 'dart:ui' show Color;

import '../../app/theme/tokens.dart';
import '../../i18n/strings.g.dart';

String _hex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// 선 굵기. 미승은 얇게, 탄 선은 굵게 해서 탄 구간이 지도에서 먼저 보이게 한다.
/// 폐선은 같은 값의 0.8배다.
List<Object> _width(List<num> widths, {double scale = 1}) => [
      'interpolate',
      ['linear'],
      ['zoom'],
      for (final (i, zoom) in const [4, 8, 11, 14, 17].indexed) ...[zoom, widths[i] * scale],
    ];

const _unridden = [0.4, 0.8, 1.4, 2.2, 3.6];
const _ridden = [1.8, 2.4, 3.2, 4.4, 6.0];

/// 폐선은 현행보다 흐리지만 전국 화면에서 보일 만큼은 굵다. 켜고 끄는 차이가 보여야 한다.
const _closedUnridden = [1.0, 1.3, 1.6, 2.2, 3.2];

List<Object> _matchInts(String key, Set<int> values) => [
      'match',
      ['to-string', ['get', key]],
      [for (final value in values.toList()..sort()) '$value'],
      true,
      false,
    ];

/// 탄 구간만 고르는 필터. `match`의 값은 문자열로 준다. Android의 식 변환이 배열 첫 값을
/// 연산자로 읽어 문자열로 바꾸므로, 숫자 배열은 형식이 섞여 조용히 무시된다.
List<Object> riddenFilter(Set<int> edges, {required bool closed}) => [
      'all',
      ['==', ['get', 'closed'], if (closed) 1 else 0],
      if (edges.isEmpty) ['==', ['get', 'n'], -1] else _matchInts('n', edges),
    ];

const heatLayer = 'pref-heat-';

/// 이보다 확대하면 히트맵이 사라지고 선로가 보인다.
const heatMaxZoom = 9.5;

/// 히트맵 네 단계의 진하기.
const heatLevels = [0.16, 0.34, 0.56, 0.8];

/// 탄 비율의 단계. 안 탔으면 없다.
int? heatLevel(double ratio) => ratio <= 0
    ? null
    : switch (ratio) {
        < 0.1 => 0,
        < 0.25 => 1,
        < 0.5 => 2,
        _ => 3,
      };

/// 그 단계에 드는 도도부현만 고른다.
List<Object> heatFilter(Set<int> prefs) =>
    prefs.isEmpty ? ['==', ['get', 'pref'], -1] : _matchInts('pref', prefs);

/// 그해에 있던 것만 남긴다. 그해 안에 생기거나 없어진 것도 든다 (타임 슬라이더).
List<Object> yearFilter(int year) => [
      ['<=', ['coalesce', ['get', 'fy'], 0], year],
      ['>=', ['coalesce', ['get', 'ty'], 9999], year],
    ];

/// 안 탄 선까지 그리는 층의 필터. [only]를 주면 그 구간만 남긴다 (노선 단독 보기).
List<Object> railFilter({required bool closed, Set<int>? only, int? year}) => [
      'all',
      ['==', ['get', 'closed'], if (closed) 1 else 0],
      if (year != null) ...yearFilter(year),
      if (only != null)
        if (only.isEmpty) ['==', ['get', 'n'], -1] else _matchInts('n', only),
    ];

/// 역 점. [ridden]을 주면 그 역 묶음만 남긴다. 승차만 볼 때 빈 땅에 역이 떠 있으면 안 된다.
List<Object> stationFilter({required bool closed, Set<int>? ridden, int? year}) => [
      'all',
      ['==', ['get', 'closed'], if (closed) 1 else 0],
      if (year != null) ...yearFilter(year),
      if (ridden != null)
        if (ridden.isEmpty) ['==', ['get', 'g'], -1] else _matchInts('g', ridden),
    ];

/// 지도 점의 상태를 고르는 필터. 비면 아무것도 고르지 않는다.
List<Object> markFilter(Set<int> groups, {required bool showClosed}) => [
      'all',
      if (groups.isEmpty) ['==', ['get', 'g'], -1] else _matchInts('g', groups),
      if (!showClosed) ['==', ['get', 'closed'], 0],
    ];

/// 위치 미확인 표식. 비면 아무것도 고르지 않는다.
List<Object> markerFilter(Set<int> ids) =>
    ids.isEmpty ? ['==', ['get', 'm'], -1] : _matchInts('m', ids);

/// 역 이름. 폐선을 끄면 폐역 이름도 함께 지운다.
List<Object> stationNameFilter({required bool showClosed, Set<int>? ridden, int? year}) => [
      'all',
      if (year != null) ...yearFilter(year),
      // 폐역 이름은 z13부터다 (DESIGN §7.2)
      [
        'case',
        ['==', ['get', 'closed'], 1],
        ['>=', ['zoom'], 13],
        ['any', ['==', ['get', 'hub'], 1], ['>=', ['zoom'], 12]],
      ],
      if (!showClosed) ['==', ['get', 'closed'], 0],
      if (ridden != null)
        if (ridden.isEmpty) ['==', ['get', 'g'], -1] else _matchInts('g', ridden),
    ];

/// 환승역은 z8.5~9.5, 일반역은 z10~11에 서서히 나타난다 (DESIGN §7.2).
const _stationFade = [
  'interpolate',
  ['linear'],
  ['zoom'],
  8.5,
  0,
  9.5,
  ['case', ['==', ['get', 'hub'], 1], 1, 0],
  10,
  ['case', ['==', ['get', 'hub'], 1], 1, 0],
  11,
  1,
];

/// 폐역은 z11.5~12에 서서히 나타난다.
const _closedStationFade = [
  'interpolate',
  ['linear'],
  ['zoom'],
  11.5,
  0,
  12,
  1,
];

const railLayer = 'rail';
const railClosedLayer = 'rail-closed';
const riddenCurrentLayer = 'rail-ridden';
const riddenClosedLayer = 'rail-closed-ridden';

/// OSM 파일의 같은 층. 선로가 두 파일로 나뉘어도 칠하기와 표시는 한 벌이다.
const osmSuffix = '-osm';
const markerLayer = 'marker';
const markerRiddenLayer = 'marker-ridden';
const markerImage = 'tail';
const markerRiddenImage = 'tail-ridden';
const stationLayer = 'station';
const stationNameLayer = 'station-name';
const stationClosedLayer = 'station-closed';
const stationPassedLayer = 'station-passed';
const stationSteppedLayer = 'station-stepped';

List<Map<String, Object>> _railLayers(String source, String suffix, AppTokens tokens) => [
      {
        'id': '$railClosedLayer$suffix',
        'type': 'line',
        'source': source,
        'source-layer': 'edge',
        'filter': railFilter(closed: true),
        'layout': {'line-cap': 'butt', 'line-join': 'round'},
        'paint': {
          'line-color': _hex(tokens.lineClosedUnridden),
          'line-width': _width(_closedUnridden),
          'line-dasharray': const [3, 2],
        },
      },
      {
        'id': '$railLayer$suffix',
        'type': 'line',
        'source': source,
        'source-layer': 'edge',
        'filter': railFilter(closed: false),
        'layout': {'line-cap': 'round', 'line-join': 'round'},
        'paint': {
          'line-color': _hex(tokens.lineUnridden),
          'line-width': _width(_unridden),
        },
      },
      {
        'id': '$riddenClosedLayer$suffix',
        'type': 'line',
        'source': source,
        'source-layer': 'edge',
        'filter': riddenFilter(const {}, closed: true),
        'layout': {'line-cap': 'round', 'line-join': 'round'},
        'paint': {
          'line-color': _hex(tokens.lineClosedRidden),
          'line-width': _width(_ridden, scale: 0.8),
        },
      },
      {
        'id': '$riddenCurrentLayer$suffix',
        'type': 'line',
        'source': source,
        'source-layer': 'edge',
        'filter': riddenFilter(const {}, closed: false),
        'layout': {'line-cap': 'round', 'line-join': 'round'},
        'paint': {
          'line-color': _hex(tokens.lineRidden),
          'line-width': _width(_ridden),
        },
      },
    ];

/// 역 점. 파일마다 같은 층을 둔다. OSM 선에 맞춘 역은 OSM 파일에 있다.
List<Map<String, Object>> _stationDots(String source, String suffix, AppTokens tokens) => [
        {
          'id': '$stationLayer$suffix',
          'type': 'circle',
          'source': source,
          'source-layer': 'station',
          'filter': stationFilter(closed: false),
          'paint': {
            'circle-radius': [
              'interpolate',
              ['linear'],
              ['zoom'],
              9,
              1.5,
              14,
              4,
            ],
            'circle-color': _hex(tokens.surface),
            'circle-stroke-color': _hex(tokens.lineUnridden),
            'circle-stroke-width': 1,
            'circle-opacity': _stationFade,
            'circle-stroke-opacity': _stationFade,
          },
        },
        {
          'id': '$stationClosedLayer$suffix',
          'type': 'circle',
          'source': source,
          'source-layer': 'station',
          'minzoom': 11.5,
          'filter': stationFilter(closed: true),
          'paint': {
            'circle-radius': 3,
            'circle-color': _hex(tokens.surface),
            'circle-stroke-color': _hex(tokens.lineClosedUnridden),
            'circle-stroke-width': 1,
            'circle-opacity': _closedStationFade,
            'circle-stroke-opacity': _closedStationFade,
          },
        },
    ];

List<Map<String, Object>> _stationMarks(String source, String suffix, AppTokens tokens) => [
        // 통과는 뚫린 원, 승하차와 방문은 꽉 찬 원이다. 폐역은 빨강이다 (DESIGN §5.3)
        for (final (id, solid) in const [(stationPassedLayer, false), (stationSteppedLayer, true)])
          {
            'id': '$id$suffix',
            'type': 'circle',
            'source': source,
            'source-layer': 'station',
            'filter': markFilter(const {}, showClosed: true),
            'paint': {
              'circle-radius': [
                'interpolate',
                ['linear'],
                ['zoom'],
                9,
                2,
                14,
                5,
              ],
              'circle-color': solid
                  ? [
                      'case',
                      ['==', ['get', 'closed'], 1],
                      _hex(tokens.lineClosedRidden),
                      _hex(tokens.lineRidden),
                    ]
                  : _hex(tokens.surface),
              'circle-stroke-color': [
                'case',
                ['==', ['get', 'closed'], 1],
                _hex(tokens.lineClosedRidden),
                _hex(tokens.lineRidden),
              ],
              'circle-stroke-width': 1.5,
              'circle-opacity': _stationFade,
              'circle-stroke-opacity': _stationFade,
            },
          },
        {
          'id': '$stationNameLayer$suffix',
          'type': 'symbol',
          'source': source,
          'source-layer': 'station',
          'minzoom': 9.5,
          'filter': stationNameFilter(showClosed: true),
          'layout': {
            'text-field': [
              'coalesce',
              ['get', LocaleSettings.currentLocale.languageCode],
              ['get', 'ja'],
            ],
            'text-font': ['Noto Sans Regular'],
            'text-size': 11,
            'text-offset': [0, 0.9],
            'text-anchor': 'top',
          },
          'paint': {
            // 폐역은 노드뿐 아니라 이름도 현행과 확연히 구분되게 흐리다 (사용자 지시)
            'text-color': [
              'case',
              ['==', ['get', 'closed'], 1],
              _hex(tokens.lineClosedUnridden),
              _hex(tokens.text),
            ],
            'text-opacity': [
              'case',
              ['==', ['get', 'closed'], 1],
              0.75,
              1,
            ],
            'text-halo-color': _hex(tokens.land),
            'text-halo-width': 1.2,
          },
        },
    ];

List<Map<String, Object>> _markers(String source, String suffix, AppTokens tokens) => [
      for (final (id, image) in const [(markerLayer, markerImage), (markerRiddenLayer, markerRiddenImage)])
        {
          'id': '$id$suffix',
          'type': 'symbol',
          'source': source,
          'source-layer': 'marker',
          'minzoom': 9,
          'filter': markerFilter(const {}),
          'layout': {
            'icon-image': image,
            'icon-rotate': ['get', 'bearing'],
            'icon-rotation-alignment': 'map',
            'icon-anchor': 'bottom',
            'icon-allow-overlap': true,
            'icon-ignore-placement': true,
          },
        },
    ];

/// 온라인 배경. 시험 빌드는 닿지 않는 주소를 넣어 인터넷이 끊긴 지도를 확인한다.
const _onlineBase = String.fromEnvironment(
  'NORIORI_ONLINE_BASE',
  defaultValue: 'https://tiles.openfreemap.org/planet',
);

/// 지도 스타일. 색은 토큰에서만 온다. 온라인 배경이 없어도 선로는 보인다 (ARCHITECTURE §2.6).
String railStyle({
  required String tiles,
  String? osmTiles,
  String? baseTiles,
  String? glyphs,
  required AppTokens tokens,
}) =>
    jsonEncode({
      'version': 8,
      'glyphs': glyphs == null
          ? 'https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf'
          : 'file://$glyphs',
      'sources': {
        'base': {'type': 'vector', 'url': _onlineBase},
        'rail': {'type': 'vector', 'url': 'pmtiles://file://$tiles'},
        if (osmTiles != null)
          'rail-osm': {
            'type': 'vector',
            'url': 'pmtiles://file://$osmTiles',
            'attribution': '© OpenStreetMap contributors',
          },
        if (baseTiles != null) 'japan': {'type': 'vector', 'url': 'pmtiles://file://$baseTiles'},
      },
      'layers': [
        {
          'id': 'land',
          'type': 'background',
          'paint': {'background-color': _hex(baseTiles == null ? tokens.land : tokens.water)},
        },
        // 내장 배경이 먼저 깔리고 온라인 배경은 그 위에 호수와 강을 더한다 (DESIGN §13)
        if (baseTiles != null) ...[
          {
            'id': 'japan-land',
            'type': 'fill',
            'source': 'japan',
            'source-layer': 'land',
            'paint': {'fill-color': _hex(tokens.land)},
          },
          // 히트맵은 한 색의 진하기 네 단계다. 확대하면 선로가 보이도록 사라진다 (DESIGN §7.2)
          for (final (level, opacity) in heatLevels.indexed)
            {
              'id': '$heatLayer$level',
              'type': 'fill',
              'source': 'japan',
              'source-layer': 'pref',
              'maxzoom': heatMaxZoom,
              'filter': heatFilter(const {}),
              'paint': {'fill-color': _hex(tokens.lineRidden), 'fill-opacity': opacity},
            },
        ],
        {
          'id': 'water',
          'type': 'fill',
          'source': 'base',
          'source-layer': 'water',
          'paint': {'fill-color': _hex(tokens.water)},
        },
        {
          'id': 'pref-border',
          'type': 'line',
          'source': baseTiles == null ? 'base' : 'japan',
          'source-layer': baseTiles == null ? 'boundary' : 'border',
          if (baseTiles == null) 'filter': ['==', ['get', 'admin_level'], 4],
          'paint': {
            'line-color': _hex(tokens.lineClosedUnridden),
            'line-width': 0.6,
            'line-opacity': [
              'interpolate',
              ['linear'],
              ['zoom'],
              3.5,
              0.15,
              6,
              0.7,
            ],
          },
        },
        ..._railLayers('rail', '', tokens),
        if (osmTiles != null) ..._railLayers('rail-osm', osmSuffix, tokens),
        ..._stationDots('rail', '', tokens),
        if (osmTiles != null) ..._stationDots('rail-osm', osmSuffix, tokens),
        // 위치 미확인 구간은 짧게 사라지는 꼬리만 남긴다 (DESIGN §7.3)
        ..._markers('rail', '', tokens),
        if (osmTiles != null) ..._markers('rail-osm', osmSuffix, tokens),
        ..._stationMarks('rail', '', tokens),
        if (osmTiles != null) ..._stationMarks('rail-osm', osmSuffix, tokens),
      ],
    });
