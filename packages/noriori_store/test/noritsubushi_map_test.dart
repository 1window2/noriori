import 'dart:io';

import 'package:noriori_core/noriori_core.dart';
import 'package:noriori_store/noriori_store.dart';
import 'package:test/test.dart';

/// 노리츠부시 대응표(DESIGN §10.2): 공식 노선 구성과 다르게 나뉜 노리츠부시 노선명이 공식 구간의 기록으로 들어간다.
/// 실제 판(build/)으로 본다.
void main() {
  final masterFile = File('../../build/master.sqlite');
  final skip = masterFile.existsSync() ? null : '판이 없다';

  late Network network;
  late ImportNames names;

  setUpAll(() async {
    if (skip != null) return;
    final dir = masterFile.absolute.parent.path;
    final db = UserDb(openDirect(File(':memory:')));
    await db.customStatement("ATTACH 'file:$dir/names.sqlite?mode=ro&immutable=1' AS names");
    await db.customStatement("ATTACH 'file:$dir/master.sqlite?mode=ro&immutable=1' AS master");
    network = Network(await NetworkReader(db).read());
    names = await PackReader(db).importNames();
    await db.close();
  });

  RowMatched match(String company, String line, String from, String to, String km, String date) {
    final text = '会社名,路線名,乗車開始駅,乗車終了駅,乗車キロ,乗車日\r\n$company,$line,$from,$to,$km,$date\r\n';
    final row = parseNoritsubushiCsv(text).rides.single;
    final result = CsvMatcher(network, names).match(row);
    expect(result, isA<RowMatched>(), reason: '$line $from→$to');
    return result as RowMatched;
  }

  List<(String, String, String)> legs(RowMatched found) => [
        for (final leg in found.legs.isEmpty
            ? [RideLeg(seq: 0, lineId: LineId(found.lineId), routeId: RouteId(found.routeId), fromNode: NodeId(found.fromNode), toNode: NodeId(found.toNode), lineLabel: '', fromLabel: '', toLabel: '')]
            : found.legs)
          (leg.lineId.value, leg.fromNode.value, leg.toNode.value),
      ];

  test('副都心線 和光市→渋谷는 有楽町線 和光市–小竹向原과 副都心線 小竹向原–渋谷이다', () {
    final found = match('東京地下鉄', '副都心線 (13号線)', '和光市', '渋谷', '20.2', '2020-01-01');
    expect(legs(found), [
      ('l_yurakucho_line', 'n_wakoshi_tokyo_metro', 'n_kotake_mukaihara_tokyo_metro'),
      ('l_fukutoshin_line', 'n_kotake_mukaihara_tokyo_metro', 'n_shibuya_tokyo_metro'),
    ]);
  }, skip: skip);

  test('札幌市電 한 노선은 탄 구간의 법적 노선마다 나뉜다', () {
    final found = match('札幌市交通事業振興公社', '1条線・山鼻線・山鼻西線・都心線', '西4丁目', 'すすきの', '8.5', '2020-01-01');
    expect([for (final leg in legs(found)) leg.$1], ['l_ichijo_line', 'l_yamahana_nishi_line', 'l_yamahana_line']);
  }, skip: skip);

  test('桟橋線 高知駅前→桟橋通五丁目은 駅前線과 桟橋線이다', () {
    final found = match('とさでん交通', '桟橋線', '高知駅前', '桟橋通五丁目', '3.2', '2020-01-01');
    expect([for (final leg in legs(found)) leg.$1], ['l_ekimae_line', 'l_sambashi_line']);
  }, skip: skip);

  test('東武 半蔵門線直通 押上→曳舟은 伊勢崎線 押上 계통이다', () {
    final found = match('東武鉄道', '半蔵門線直通', '押上', '曳舟', '2.4', '2020-01-01');
    expect((found.lineId, found.routeId), ('l_isesaki_line', 'r_isesaki_line_oshiage_hikifune'));
  }, skip: skip);
}
