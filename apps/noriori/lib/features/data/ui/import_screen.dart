import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../i18n/strings.g.dart';
import '../controller/import_controller.dart';

/// 노리츠부시 CSV 가져오기. 확인을 누르기 전에는 아무것도 쓰지 않는다.
class ImportScreen extends ConsumerWidget {
  const ImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(importControllerProvider);
    final t = context.t.importing;
    return Scaffold(
      appBar: AppBar(title: Text(t.title)),
      body: switch (step) {
        ImportBusy() => const Center(child: CircularProgressIndicator()),
        ImportIdle(:final undone) => _Pick(message: undone ? t.undone : t.hint),
        ImportRefused(:final fileName) => _Pick(message: t.refused(name: fileName)),
        ImportFailed() => _Pick(message: t.failed),
        ImportReady(:final fileName, :final plan) => _Review(fileName: fileName, plan: plan),
        ImportDone(:final count, :final undated) => _Finished(count: count, undated: undated),
        ImportFullReady(:final fileName, :final contents) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 20,
              children: [
                Text(fileName, style: Theme.of(context).textTheme.titleMedium),
                Text(t.fullHint(count: contents.rowCount)),
                FilledButton(
                  onPressed: ref.read(importControllerProvider.notifier).confirmFull,
                  child: Text(t.confirm(n: contents.rowCount, count: countLabel(contents.rowCount))),
                ),
              ],
            ),
          ),
        ImportMerged(:final count) => _Pick(message: t.merged(n: count)),
      },
    );
  }
}

class _Pick extends ConsumerWidget {
  const _Pick({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 20,
          children: [
            Text(message, style: Theme.of(context).textTheme.bodyLarge),
            FilledButton(
              onPressed: ref.read(importControllerProvider.notifier).choose,
              child: Text(context.t.importing.choose),
            ),
          ],
        ),
      );
}

class _Review extends ConsumerStatefulWidget {
  const _Review({required this.fileName, required this.plan});

  final String fileName;
  final ImportPlan plan;

  @override
  ConsumerState<_Review> createState() => _ReviewState();
}

class _ReviewState extends ConsumerState<_Review> {
  bool _restoreDeleted = false;

  @override
  Widget build(BuildContext context) {
    final t = context.t.importing;
    final plan = widget.plan;
    final text = Theme.of(context).textTheme;
    final fresh = plan.ofState(ImportState.fresh).length;
    final existing = plan.ofState(ImportState.existing).length;
    final deleted = plan.ofState(ImportState.deleted).length;
    final total = fresh + (_restoreDeleted ? deleted : 0);
    final matched = fresh - plan.missed.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _Line(title: t.file, value: widget.fileName),
              _Line(title: t.fresh, value: t.rows(count: countLabel(matched))),
              _Line(title: t.distance, value: '${kmLabel(plan.freshMeters)} km'),
              if (existing > 0) _Line(title: t.existing, value: t.rows(count: countLabel(existing))),
              if (deleted > 0)
                SwitchListTile(
                  title: Text(t.deleted),
                  subtitle: Text(t.rows(count: countLabel(deleted))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  value: _restoreDeleted,
                  onChanged: (value) => setState(() => _restoreDeleted = value),
                ),
              if (plan.missed.isNotEmpty)
                _Problems(
                  title: t.missed(n: plan.missed.length, count: countLabel(plan.missed.length)),
                  hint: t.missedHint,
                  rows: [for (final row in plan.missed) row.row.raw],
                ),
              if (plan.broken.isNotEmpty)
                _Problems(
                  title: t.broken(n: plan.broken.length, count: countLabel(plan.broken.length)),
                  hint: t.brokenHint,
                  rows: plan.broken,
                ),
              if (plan.kmDiffers.isNotEmpty)
                _Problems(
                  title: t.kmDiffers(n: plan.kmDiffers.length, count: countLabel(plan.kmDiffers.length)),
                  hint: t.kmDiffersHint,
                  rows: [
                    for (final row in plan.kmDiffers)
                      t.kmDiffersRow(
                        raw: row.row.raw,
                        km: kmLabel((row.result as RowMatched).meters),
                      ),
                  ],
                ),
              if (total == 0)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(t.nothing, style: text.bodyMedium),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: FilledButton(
              onPressed: total == 0
                  ? null
                  : () => ref
                      .read(importControllerProvider.notifier)
                      .confirm(restoreDeleted: _restoreDeleted),
              child: Text(t.confirm(n: total, count: countLabel(total))),
            ),
          ),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        title: Text(title),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Text(value, overflow: TextOverflow.ellipsis),
        ),
      );
}

/// 문제가 있는 행. 원문을 그대로 보여 주므로 사용자가 무엇인지 알아볼 수 있다.
class _Problems extends StatelessWidget {
  const _Problems({required this.title, required this.hint, required this.rows});

  final String title;
  final String hint;
  final List<String> rows;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 24),
      childrenPadding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      title: Text(title),
      subtitle: Text(hint, style: small),
      children: [for (final row in rows) Text(row, style: small)],
    );
  }
}

class _Finished extends ConsumerWidget {
  const _Finished({required this.count, required this.undated});

  final int count;

  /// 그날 탈 수 없거나 기준일 이전이라 날짜 모름으로 넣은 행. 건수만 보여 준다 (DESIGN §10.2).
  final int undated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t.importing;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Text(t.done(n: count, count: countLabel(count)), style: Theme.of(context).textTheme.titleLarge),
          if (undated > 0) Text(t.undated(n: undated, count: countLabel(undated))),
          const SizedBox(height: 8),
          FilledButton(onPressed: () => context.pop(), child: Text(t.close)),
          OutlinedButton(
            onPressed: ref.read(importControllerProvider.notifier).undo,
            child: Text(t.undo),
          ),
        ],
      ),
    );
  }
}
