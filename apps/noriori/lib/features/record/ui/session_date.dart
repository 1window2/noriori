import 'package:flutter/material.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/theme/app_theme.dart';
import '../../../i18n/strings.g.dart';

/// 날짜는 큰 줄 대신 제목 옆의 칩이다.
class SessionDateChip extends StatelessWidget {
  const SessionDateChip({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: tokens.hairline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 2,
              children: [
                Text(label, style: text.labelMedium?.copyWith(color: tokens.text)),
                Icon(Icons.expand_more, size: 16, color: tokens.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class DateAnswer {
  const DateAnswer(this.value);

  final String? value;
}

/// 하루, 달, 해를 받는다. 달력에 없는 날짜와 앞날은 받지 않는다.
class SessionDateDialog extends StatefulWidget {
  const SessionDateDialog({super.key, required this.current, required this.today});

  final String? current;
  final String today;

  @override
  State<SessionDateDialog> createState() => _SessionDateDialogState();
}

class _SessionDateDialogState extends State<SessionDateDialog> {
  late final _field = TextEditingController(
    text: widget.current?.replaceAll('-XX', ''),
  );
  bool _bad = false;

  void _apply() {
    try {
      final value = parseDateInput(_field.text);
      if (value != null && DateSpan.parse(value).lo.compareTo(widget.today) > 0) {
        throw const FormatException('앞날이다');
      }
      Navigator.pop(context, DateAnswer(value));
    } on FormatException {
      setState(() => _bad = true);
    }
  }

  Future<void> _pick() async {
    final now = DateTime.parse(widget.today);
    final raw = widget.current;
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1872),
      lastDate: now,
      initialDate: raw == null ? now : DateTime.parse(DateSpan.parse(raw).lo),
    );
    if (picked == null) return;
    final mm = '${picked.month}'.padLeft(2, '0');
    final dd = '${picked.day}'.padLeft(2, '0');
    _field.text = '${picked.year}-$mm-$dd';
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.session;
    return AlertDialog(
      title: Text(t.dateTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _field,
            decoration: InputDecoration(
              hintText: t.dateHint,
              errorText: _bad ? t.dateBad : null,
            ),
          ),
          // 오늘은 누르면 바로 적용한다 (사용자 요청 2026-11-08)
          Row(
            children: [
              TextButton(onPressed: _pick, child: Text(t.datePick)),
              TextButton(
                onPressed: () => Navigator.pop(context, DateAnswer(widget.today)),
                child: Text(t.dateToday),
              ),
            ],
          ),
          // 날짜 모름 화면의 기준을 알린다: 역은 모든 시기, 연결(직통·환승)은 마지막 상태 (사용자 결정 2026-11-19)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(t.dateUnknownHint, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, const DateAnswer(null)),
          child: Text(t.dateUnknown),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
        FilledButton(onPressed: _apply, child: Text(t.apply)),
      ],
    );
  }
}

/// 그날 그 구간을 탈 수 없다는 경고. 저장이나 날짜 변경을 받지 않았음을 [body]로 알린다 (DESIGN §2.8 J).
Future<void> showUnridable(BuildContext context, String body) {
  final t = context.t.session;
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(t.unridableTitle),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t.unridableOk)),
      ],
    ),
  );
}
