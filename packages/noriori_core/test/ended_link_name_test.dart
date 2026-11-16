import 'package:noriori_core/noriori_core.dart';
import 'package:test/test.dart';

/// 끝난 연결 줄의 상대 역 이름을 고를 날 (4회차 kyushu_2-007: 臼ノ浦線 「松浦線 다음 上佐々」 ~1971-12-26).
SelectorLink _link(String? toHi) => SelectorLink(
      seq: 0,
      kind: 'branch',
      otherLineId: 'l_matsuura_line',
      otherRouteId: null,
      validFromLo: '1931-01-01',
      validToHi: toHi,
      nextStop: 'n_seiho_koukou_mae',
    );

void main() {
  test('끝난 연결은 끝난 날 전날 이름', () {
    expect(endedLinkNameDay(_link('1971-12-26'), null), '1971-12-25');
    expect(endedLinkNameDay(_link('1971-03-01'), DateSpan.parse('2000-01-01')), '1971-02-28');
  });
  test('그날 아직 있는 연결과 끝나지 않은 연결은 그날 이름', () {
    expect(endedLinkNameDay(_link('1971-12-26'), DateSpan.parse('1960-05-01')), isNull);
    expect(endedLinkNameDay(_link(DateSpan.maxDate), null), isNull);
    expect(endedLinkNameDay(_link(null), null), isNull);
  });
  test('열쇠는 노드 ID와 겹치지 않는다', () {
    final key = endedLinkNameKey('n_kouda', 'l_matsuura_line', '1971-12-25');
    expect(key, isNot('n_kouda'));
    expect(key.contains('\u0000'), isTrue);
  });
}
