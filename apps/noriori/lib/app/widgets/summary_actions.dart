import 'package:flutter/material.dart';

/// 요약과 버튼 한 줄. 글자를 키우면 버튼을 다음 줄로 내리고 요약은 그 안에서 스크롤한다.
/// 그래야 저장 단추가 화면 밖으로 밀리지 않고 위의 역 목록도 남는다.
class SummaryActions extends StatelessWidget {
  const SummaryActions({super.key, required this.summary, required this.actions});

  final Widget summary;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.textScalerOf(context).scale(10) <= 13) {
      return Row(spacing: 12, children: [Expanded(child: summary), ...actions]);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.16),
          child: SingleChildScrollView(child: summary),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.end, spacing: 12, children: actions),
      ],
    );
  }
}
