import 'package:noriori_core/noriori_core.dart';
import 'package:test/test.dart';

void main() {
  test('읽기는 한자가 섞인 이름에만 단다', () {
    expect(needsReading('玉川'), isTrue);
    expect(needsReading('ガーラ湯沢'), isTrue);
    expect(needsReading('霞ヶ関'), isTrue);
    expect(needsReading('佐々'), isTrue);
    expect(needsReading('ひがしのだんち'), isFalse);
    expect(needsReading('テレコムセンター'), isFalse);
    expect(needsReading('JR'), isFalse);
  });

  test('읽기는 이름과 같은 행에서 고른다 (날짜에 맞는 옛 이름이면 옛 이름의 읽기)', () {
    const rows = [
      NameRow(text: '玉川', kana: 'たまがわ'),
      NameRow(text: '旧名', kana: 'きゅうめい', validTo: '1960-01-01'),
    ];
    expect(pickNameRow(rows)?.kana, 'たまがわ');
    expect(pickNameRow(rows, date: '1950-06-01')?.kana, 'きゅうめい');
    expect(pickName(rows, date: '1950-06-01'), '旧名');
  });
}
