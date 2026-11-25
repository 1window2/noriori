import 'package:flutter_test/flutter_test.dart';
import 'package:noriori/features/record/ui/session_lines.dart';

void main() {
  test('작은 가나·장음·닫는 부호 앞에는 줄바꿈을 막는 이음표가 붙고 글자는 그대로다', () {
    expect(kinsoku('たばたしんごうじょう'), 'たばたしんごうじ⁠ょう');
    expect(kinsoku('ケーブル（旧）'), 'ケ⁠ーブル（旧⁠）');
    expect(kinsoku('とうきょう').replaceAll('⁠', ''), 'とうきょう');
    expect(kinsoku('新宿'), '新宿');
  });
}
