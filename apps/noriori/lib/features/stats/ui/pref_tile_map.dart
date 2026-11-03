import 'package:flutter/material.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/theme/app_theme.dart';
import '../../../i18n/strings.g.dart';

/// JIS 코드 순서의 타일 자리(열, 행). 일본 지형을 따라 놓았다. 이름은 번역 파일의 같은 순서다.
const _prefs = <int, (int, int)>{
  1: (12, 0), 2: (12, 1), 3: (12, 2), 4: (12, 3),
  5: (11, 2), 6: (11, 3), 7: (11, 4), 8: (12, 5),
  9: (11, 5), 10: (10, 5), 11: (10, 6), 12: (12, 6),
  13: (11, 6), 14: (10, 7), 15: (10, 4), 16: (9, 4),
  17: (8, 4), 18: (7, 5), 19: (9, 6), 20: (9, 5),
  21: (8, 5), 22: (9, 7), 23: (8, 6), 24: (7, 7),
  25: (7, 6), 26: (6, 6), 27: (5, 7), 28: (5, 6),
  29: (6, 7), 30: (6, 8), 31: (4, 6), 32: (3, 6),
  33: (4, 7), 34: (3, 7), 35: (2, 7), 36: (5, 8),
  37: (4, 8), 38: (3, 8), 39: (4, 9), 40: (1, 8),
  41: (0, 8), 42: (0, 9), 43: (1, 9), 44: (2, 8),
  45: (2, 9), 46: (1, 10), 47: (0, 11),
};

/// 도도부현 타일 지도. 47칸이면 작은 화면에서도 전국을 한눈에 비교한다.
class PrefTileMap extends StatelessWidget {
  const PrefTileMap({super.key, required this.scores});

  final Map<int, Score> scores;

  static const _columns = 13;
  static const _rows = 12;
  static const _gap = 3.0;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final t = context.t.stats;
    return LayoutBuilder(
      builder: (context, box) {
        final width = (box.maxWidth - _gap * (_columns - 1)) / _columns;
        final height = width * .72;
        return SizedBox(
          height: _rows * (height + _gap),
          child: Stack(
            children: [
              for (final MapEntry(key: code, value: (column, row)) in _prefs.entries)
                Positioned(
                  left: column * (width + _gap),
                  top: row * (height + _gap),
                  width: width,
                  height: height,
                  child: Tooltip(
                    triggerMode: TooltipTriggerMode.tap,
                    message: t.prefLabel(
                      name: context.t.prefNames[code - 1],
                      percent: scores[code] == null ? '0%' : percentLabel(scores[code]!),
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _tone(tokens.track, tokens.lineRidden, scores[code]),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// 한 색의 진하기로만 나타낸다. 조금이라도 탔으면 바탕과 구분되게 한다.
  Color _tone(Color base, Color full, Score? score) {
    if (score == null || !score.started) return base;
    return Color.lerp(base, full, .2 + .8 * score.ratio)!;
  }
}
