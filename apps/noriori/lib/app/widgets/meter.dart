import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 진행률 막대. 탄 구간이 있으면 아주 작아도 보이게 최소 폭을 둔다.
class Meter extends StatelessWidget {
  const Meter({super.key, required this.ratio, this.height = 4, this.under});

  final double ratio;
  final double height;

  /// 앞으로 오를 값. 옅게 깐다.
  final double? under;

  static const _minVisible = 5.0;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return LayoutBuilder(
      builder: (context, box) {
        double width(double value) =>
            value <= 0 ? 0 : (box.maxWidth * value).clamp(_minVisible, box.maxWidth);
        Widget bar(double value, Color color) => Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: width(value),
                height: height,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
            );
        final soft = under;
        return ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: Container(
            height: height,
            color: tokens.track,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (soft != null) bar(soft, tokens.lineRiddenSoft),
                bar(ratio, tokens.lineRidden),
              ],
            ),
          ),
        );
      },
    );
  }
}
