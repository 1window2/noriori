import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/session_providers.dart';

/// 방문 역 화면이 보는 값.
final class VisitsData {
  const VisitsData({required this.total, required this.closed, required this.byPref});

  final int total;
  final int closed;

  /// (도도부현 번호, 역 수). 많은 곳이 먼저다.
  final List<(int, int)> byPref;

  int get unknown => total - byPref.fold(0, (sum, row) => sum + row.$2);
}

/// 방문 역 수는 역 방문과 승하차역의 합이다. 완주율과 별도 지표다 (DESIGN §5.2).
final visitsDataProvider = FutureProvider.autoDispose<VisitsData>((ref) async {
  final stepped = ref.watch(stationMarksProvider).stepped;
  final network = ref.watch(networkProvider);
  final prefs = await ref.watch(packReaderProvider).groupPrefs(stepped);
  return VisitsData(
    total: stepped.length,
    closed: stepped.difference(network.openGroups).length,
    byPref: stationsByPref(stepped, prefs),
  );
});
