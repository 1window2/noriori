import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:noriori_core/noriori_core.dart';
import 'package:noriori_store/noriori_store.dart';

import '../../../app/session_providers.dart';
import '../platform/channel_file_pick.dart';

export 'package:noriori_core/noriori_core.dart'
    show BackupContents, CsvRide, ImportPlan, ImportRow, ImportState, MissReason, RowMatched, RowMissed;

/// 가져오기의 단계 (DESIGN §10.2). 확인 전에는 아무것도 쓰지 않는다.
sealed class ImportStep {
  const ImportStep();
}

final class ImportIdle extends ImportStep {
  const ImportIdle({this.undone = false});

  final bool undone;
}

final class ImportBusy extends ImportStep {
  const ImportBusy();
}

final class ImportRefused extends ImportStep {
  const ImportRefused(this.fileName);

  final String fileName;
}

/// 읽기나 저장이 실패했다. 저장은 한 트랜잭션이라 쓴 것이 없다.
final class ImportFailed extends ImportStep {
  const ImportFailed();
}

final class ImportReady extends ImportStep {
  const ImportReady(this.fileName, this.plan);

  final String fileName;
  final ImportPlan plan;
}

/// noriori 전체판. 이름을 다시 맞추지 않고 없는 기록만 병합한다.
final class ImportFullReady extends ImportStep {
  const ImportFullReady(this.fileName, this.contents);

  final String fileName;
  final BackupContents contents;
}

/// 전체판을 병합했다.
final class ImportMerged extends ImportStep {
  const ImportMerged(this.count);

  final int count;
}

final class ImportDone extends ImportStep {
  const ImportDone(this.change, {this.undated = 0});

  final Change change;

  /// 날짜 모름으로 넣은 행 수. 기준일은 말하지 않는다 (DESIGN §10.2).
  final int undated;

  int get count => change.after.length;
}

final importControllerProvider =
    NotifierProvider.autoDispose<ImportController, ImportStep>(ImportController.new);

class ImportController extends Notifier<ImportStep> {
  final _files = const ChannelFilePick();

  @override
  ImportStep build() => const ImportIdle();

  /// 도중에 화면을 나가도 끝까지 돈다. 실패하면 처음 화면에서 다시 고를 수 있다.
  Future<void> _guard(Future<void> Function() work) async {
    final alive = ref.keepAlive();
    try {
      await work();
    } on Object catch (error) {
      debugPrint('가져오기 실패: $error');
      state = const ImportFailed();
    } finally {
      alive.close();
    }
  }

  Future<void> choose() => _guard(() async {
        final picked = await _files.pick();
        if (picked == null) return;
        await _read(picked.name, picked.bytes);
      });

  /// 판단은 core가 한다. 여기서는 판의 이름과 지금 있는 기록을 건넨다.
  Future<void> _read(String name, List<int> bytes) async {
    state = const ImportBusy();
    final text = decodeCsvBytes(bytes);
    if (isFullCsv(text)) {
      final deviceId = await ref.read(deviceIdProvider.future);
      try {
        state = ImportFullReady(name, parseFullCsv(text, deviceId: deviceId));
      } on FormatException {
        state = ImportRefused(name);
      }
      return;
    }
    final CsvFile file;
    try {
      file = parseNoritsubushiCsv(text);
    } on FormatException {
      state = ImportRefused(name);
      return;
    }
    final names = await ref.read(packReaderProvider).importNames();
    final rides = await ref.read(sessionProvider).records.allRides();
    final plan = planImport(
      file,
      CsvMatcher(ref.read(networkProvider), names),
      {for (final ride in rides) ride.rideId.value: ride.deletedAt != null},
      idOf: uuidV5,
    );
    state = ImportReady(name, plan);
  }

  /// 전체판은 병합이라 있는 기록을 건드리지 않는다.
  Future<void> confirmFull() {
    final ready = state;
    if (ready is! ImportFullReady) return Future.value();
    return _guard(() async {
      state = const ImportBusy();
      state = ImportMerged(await ref.read(sessionProvider).records.merge(ready.contents));
    });
  }

  /// 전체가 변경 하나라 도중에 죽으면 없던 일이고 한 번에 되돌릴 수 있다.
  Future<void> confirm({required bool restoreDeleted}) {
    final ready = state;
    if (ready is! ImportReady) return Future.value();
    return _guard(() => _save(ready, restoreDeleted: restoreDeleted));
  }

  Future<void> _save(ImportReady ready, {required bool restoreDeleted}) async {
    state = const ImportBusy();
    final session = ref.read(sessionProvider);
    final rows = ready.plan.ofState(ImportState.fresh);
    final now = ref.read(nowProvider)();
    final deviceId = await ref.read(deviceIdProvider.future);
    final rides = [
      for (final row in rows)
        await _ride(
          row,
          edition: session.pack.edition,
          now: now,
          deviceId: deviceId,
          fileName: ready.fileName,
        ),
    ];
    // 되살리기는 삭제 표시만 푼다. 파일에서 다시 만들면 사용자가 고친 값이 덮인다 (DESIGN §10.2)
    final deleted = [
      if (restoreDeleted)
        for (final row in ready.plan.ofState(ImportState.deleted)) (await session.records.ride(row.rideId))!,
    ];
    final change = await session.records.apply(
      Change(before: deleted, after: [...rides, for (final ride in deleted) ride.withDeletedAt(null)]),
    );
    state = ImportDone(change, undated: ready.plan.undated.length);
  }

  Future<Ride> _ride(
    ImportRow row, {
    required String edition,
    required int now,
    required String deviceId,
    required String fileName,
  }) async {
    final result = row.result;
    var lineLabel = row.row.line;
    var fromLabel = row.row.from;
    var toLabel = row.row.to;
    if (result is RowMatched) {
      final labels = await ref.read(packReaderProvider).nodeNames(
        [result.fromNode, result.toNode],
        lineId: result.lineId,
        date: row.row.dateInput == null ? null : DateSpan.parse(row.row.dateInput!).lo,
      );
      lineLabel = ref.read(nameBookProvider).lines[result.lineId] ?? lineLabel;
      fromLabel = labels[result.fromNode] ?? fromLabel;
      toLabel = labels[result.toNode] ?? toLabel;
    }
    return importedRide(
      row,
      edition: edition,
      now: now,
      deviceId: deviceId,
      lineLabel: lineLabel,
      fromLabel: fromLabel,
      toLabel: toLabel,
      fileName: fileName,
    );
  }

  /// 되돌리기는 새 변경이다. 그 사이 나간 백업을 이긴다.
  Future<void> undo() {
    final done = state;
    if (done is! ImportDone) return Future.value();
    return _guard(() async {
      state = const ImportBusy();
      final now = ref.read(nowProvider)();
      await ref.read(sessionProvider).records.apply(done.change.undo(now: now));
      state = const ImportIdle(undone: true);
    });
  }
}
