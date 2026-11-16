import 'dart:io';

import 'package:noriori_core/noriori_core.dart';
import 'package:noriori_store/noriori_store.dart';
import 'package:test/test.dart';

/// 노선 상세 그림은 그 계통에 서는 역만 그린다. 판이 없으면 건너뛴다.
void main() {
  final master = File('../../build/master.sqlite');
  final skip = master.existsSync() ? null : '판이 없다';
  late Network network;

  setUpAll(() async {
    if (skip != null) return;
    final db = UserDb(openDirect(File(':memory:')));
    await db.customStatement("ATTACH 'file:${master.absolute.path}?mode=ro&immutable=1' AS master");
    network = Network(await NetworkReader(db).read());
    await db.close();
  });

  test('지나가기만 하는 폐역은 그 계통 그림에 없다 (筑豊電鉄 계통의 黒崎車庫前: 北九州線 시절 1999 폐지)', () {
    Set<String> nodesOf(String lineId) => {
          for (final route in lineDiagram(network, lineId, hits: const {}, today: '2026-11-14').routes)
            for (final stop in route.stops) stop.node,
        };
    expect(nodesOf('l_chikuho_electric_railroad'), isNot(contains('n_kurosakishakomae')));
    expect(nodesOf('l_chikuho_electric_railroad'), containsAll(['n_kurosaki_ekimae', 'n_nishi_kurosaki', 'n_kumanishi']));
    expect(nodesOf('l_kitakyushu_line'), contains('n_kurosakishakomae'));
  }, skip: skip);
}
