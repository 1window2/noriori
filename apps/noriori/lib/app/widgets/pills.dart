import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 작은 전환 단추. 선택은 먹색이다.
class PillToggle<T> extends StatelessWidget {
  const PillToggle({
    super.key,
    required this.values,
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  final List<T> values;
  final String Function(T value) label;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    // 보이는 캡슐은 그대로 두고 누르는 곳만 위아래로 48dp까지 넓힌다
    return Stack(
      children: [
        Positioned.fill(
          top: _reach - 3,
          bottom: _reach - 3,
          child: DecoratedBox(
            decoration: BoxDecoration(color: tokens.land, borderRadius: BorderRadius.circular(999)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final value in values)
                Semantics(
                  button: true,
                  selected: value == selected,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(value),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: _reach),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: value == selected ? tokens.text : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          label(value),
                          style: text.labelMedium?.copyWith(
                            fontSize: 12,
                            fontWeight: value == selected ? FontWeight.w700 : FontWeight.w500,
                            color: value == selected ? tokens.surface : tokens.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static const _reach = 12.0;
}

/// 밀어서 고르는 단추. 지금 값 위로 바탕이 미끄러져 온다. 눌러도 끌어도 바뀐다.
class SlidingChoice<T> extends StatelessWidget {
  const SlidingChoice({
    super.key,
    required this.values,
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  final List<T> values;
  final String Function(T value) label;
  final T selected;
  final ValueChanged<T> onChanged;

  void _drag(double x, double width) {
    final index = (x / width * values.length).floor().clamp(0, values.length - 1);
    if (values[index] != selected) onChanged(values[index]);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    final at = values.indexOf(selected);
    return LayoutBuilder(
      builder: (context, box) => GestureDetector(
        onHorizontalDragUpdate: (drag) => _drag(drag.localPosition.dx, box.maxWidth),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: tokens.land, borderRadius: BorderRadius.circular(14)),
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment(-1 + 2 * at / (values.length - 1), 0),
                  child: FractionallySizedBox(
                    widthFactor: 1 / values.length,
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: tokens.paper,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: softShadow,
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final value in values)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: value == selected,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onChanged(value),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 44),
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: (text.labelLarge ?? const TextStyle()).copyWith(
                                  fontSize: 14,
                                  fontWeight: value == selected ? FontWeight.w700 : FontWeight.w500,
                                  color: value == selected ? tokens.text : tokens.textMuted,
                                ),
                                child: Text(label(value)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 필터 칩 하나.
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.elevated = false,
    this.badge,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// 이름 뒤의 작은 네모 표시(임시 운행만 있는 계통의 「임시」, 사용자 결정 2026-11-19)
  final String? badge;

  /// 지도 위에 뜬 칩이다.
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // 칩은 작게 보여도 누르는 곳은 48dp다
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? tokens.text : (elevated ? tokens.paper : Colors.transparent),
              borderRadius: BorderRadius.circular(999),
              border: selected || elevated ? null : Border.all(color: tokens.hairline),
              boxShadow: elevated ? softShadow : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                Text(
                  label,
                  style: text.labelMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? tokens.surface : tokens.textMuted,
                  ),
                ),
                if (badge case final mark?)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: selected ? tokens.surface : tokens.textMuted),
                    ),
                    child: Text(
                      mark,
                      style: text.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected ? tokens.surface : tokens.textMuted,
                        height: 1.2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 가로로 미는 칩 줄. 높이는 칩이 정한다.
///
/// 부모가 높이를 숫자로 정하면 칩의 터치 영역이나 글자 크기가 바뀔 때 칩이 눌려 찌그러진다.
/// 칩 줄은 항상 이 위젯으로 만든다.
class FilterPillRow extends StatelessWidget {
  const FilterPillRow({super.key, required this.pills, this.left = 16, this.clip = Clip.hardEdge});

  final List<Widget> pills;

  /// 화면 글자 열에 맞춘다.
  final double left;

  /// 지도 위에서는 칩 그림자가 잘리지 않게 끈다.
  final Clip clip;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: clip,
        padding: EdgeInsets.only(left: left, right: left),
        child: Row(spacing: 8, children: pills),
      );
}

const softShadow = [
  BoxShadow(color: Color(0x24000000), offset: Offset(0, 2), blurRadius: 10),
];

/// 밑줄 탭. 토글을 두 줄 쌓지 않으려고 쓴다.
class UnderlineTabs<T> extends StatelessWidget {
  const UnderlineTabs({
    super.key,
    required this.values,
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  final List<T> values;
  final String Function(T value) label;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tokens.hairline))),
      child: Padding(
        padding: const EdgeInsets.only(left: 24),
        // 글자를 키우거나 말이 길면 옆으로 넘긴다
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
          spacing: 20,
          children: [
            for (final value in values)
              Semantics(
                button: true,
                selected: value == selected,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(value),
                  child: Container(
                    padding: const EdgeInsets.only(top: 14, bottom: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          width: 2,
                          color: value == selected ? tokens.text : Colors.transparent,
                        ),
                      ),
                    ),
                    child: Text(
                      label(value),
                      style: text.bodyLarge?.copyWith(
                        fontSize: 15,
                        fontWeight: value == selected ? FontWeight.w700 : FontWeight.w400,
                        color: value == selected ? tokens.text : tokens.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
          ],
          ),
        ),
      ),
    );
  }
}
