import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../features/record/controller/record_session_controller.dart';
import '../features/record/ui/fold_view.dart';

/// 디버그 빌드에서만: 앱 문서 폴더의 `debug_open.json`({"line", "route"?, "date"?, "focus"?, "folds"?})이 있으면
/// 시작할 때 그 노선의 역 선택기를 연다. "date"가 null이면 날짜 모름, 없으면 기본(오늘)이다. 시뮬레이터 화면 대조용이다
Future<void> debugOpen(WidgetRef ref, GoRouter router) async {
  if (!kDebugMode) return;
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/debug_open.json');
  if (!file.existsSync()) return;
  final spec = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  // 한 번만 쓴다. 남아 있으면 다음 실행에도 같은 화면이 열리고 접힌 줄을 접을 수 없다
  file.deleteSync();
  debugOpenAllFolds = spec['folds'] == true;
  final session = ref.read(recordSessionProvider.notifier);
  await session.open(lineId: spec['line']! as String, routeId: spec['route'] as String?, focusNode: spec['focus'] as String?);
  if (spec.containsKey('date')) await session.setDate(spec['date'] as String?);
  if (spec['focus'] case final String node) {
    for (final row in ref.read(recordSessionProvider).rows) {
      if (row.node == node) ref.read(recordSessionProvider.notifier).focusOn(row.seq);
    }
  }
  unawaited(router.push('/record/session'));
}
