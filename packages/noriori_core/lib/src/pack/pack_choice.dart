/// 고를 수 있는 데이터 팩 하나. 활성 판은 저장하지 않고 시작할 때마다 계산한다.
final class PackCandidate {
  const PackCandidate({
    required this.edition,
    required this.schemaVersion,
    required this.fromAssets,
  });

  /// `2026-11-03` 또는 같은 날의 고침 판 `2026-11-03.5`.
  final String edition;
  final int schemaVersion;
  final bool fromAssets;
}

/// 판의 순서. 날짜가 같으면 고침 번호를 수로 비교한다. 없으면 0번이다.
int compareEditions(String a, String b) {
  (String, int) parts(String edition) {
    final at = edition.indexOf('.');
    if (at < 0) return (edition, 0);
    return (edition.substring(0, at), int.tryParse(edition.substring(at + 1)) ?? 0);
  }

  final (dayA, numberA) = parts(a);
  final (dayB, numberB) = parts(b);
  final day = dayA.compareTo(dayB);
  return day != 0 ? day : numberA.compareTo(numberB);
}

/// 앱이 지원하는 스키마에서 가장 높은 판. 같은 판이면 이미 폴더에 있는 쪽을 쓴다.
///
/// 앱 자산은 그 앱이 지원하는 스키마이므로 후보가 비는 일은 없다.
PackCandidate choosePack({
  required PackCandidate assets,
  required Iterable<PackCandidate> folders,
  required int supportedSchema,
}) {
  var best = assets;
  for (final pack in folders) {
    if (pack.schemaVersion != supportedSchema) continue;
    final order = compareEditions(pack.edition, best.edition);
    if (order > 0 || (order == 0 && best.fromAssets)) best = pack;
  }
  return best;
}
