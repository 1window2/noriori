import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../i18n/strings.g.dart';
import '../controller/backup_controller.dart';
import 'format.dart';
import '../platform/channel_file_pick.dart';

/// 복원. 병합만 있으므로 파일을 잘못 골라도 새 기록이 사라지지 않는다.
///
/// [onFinish]가 있으면 복원 전용 화면이다. 닫기 전에는 앱 본체로 넘어가지 않는다.
class RestoreScreen extends ConsumerStatefulWidget {
  const RestoreScreen({super.key, this.onFinish});

  final VoidCallback? onFinish;

  @override
  ConsumerState<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends ConsumerState<RestoreScreen> {
  List<BackupCandidate>? _files;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final controller = ref.read(backupControllerProvider.notifier);
    try {
      final files = await controller.candidates();
      if (mounted) setState(() => _files = files);
    } on Object catch (e) {
      // 폴더 권한을 잃으면 목록을 읽지 못한다. 비어 있다고 보여 주지 않고 폴더를 다시 고르게 한다
      debugPrint('백업 목록 실패: $e');
      if (mounted) _say(context.t.data.notice.folderLost);
    }
  }

  Future<void> _work(Future<void> Function() job) async {
    setState(() => _busy = true);
    try {
      await job();
    } on Object catch (e) {
      debugPrint('복원 실패: $e'); // 병합은 한 트랜잭션이라 기록은 그대로다
      if (mounted) _say(context.t.data.refused);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _say(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _pick() => _work(() async {
        final picked = await ref.read(backupControllerProvider.notifier).pick();
        if (!mounted) return;
        if (picked != null && picked.insideApp) _say(context.t.data.insideApp);
        await _reload();
      });

  /// 병합 결과 한 줄.
  String _result(RestoreOutcome outcome) {
    final t = context.t.data;
    return switch (outcome) {
      RestoreMerged(:final taken) => t.merged(n: taken),
      RestoreRefused() => t.refused,
    };
  }

  Future<void> _merge(BackupCandidate file) => _work(() async {
        final outcome = await ref.read(backupControllerProvider.notifier).restore(file.name);
        if (!mounted) return;
        _say(_result(outcome));
        await _reload();
      });

  /// 폴더가 없어도 공유로 받은 백업을 고를 수 있다.
  Future<void> _pickFile() => _work(() async {
        final picked = await const ChannelFilePick().pick();
        if (picked == null) return;
        final outcome = await ref
            .read(backupControllerProvider.notifier)
            .restoreFile(picked.name, utf8.decode(picked.bytes, allowMalformed: true));
        if (!mounted) return;
        _say(_result(outcome));
      });

  Future<void> _export() => _work(() async {
        final t = context.t.data;
        final count = await ref.read(backupControllerProvider.notifier).exportQuarantined();
        if (!mounted) return;
        _say(t.exported(n: count));
      });

  @override
  Widget build(BuildContext context) {
    final t = context.t.data;
    final state = ref.watch(backupControllerProvider);
    final folder = state.folder;
    final files = _files ?? const <BackupCandidate>[];
    final finish = widget.onFinish;
    final writable = folder != null && folder.granted;
    return Scaffold(
      appBar: AppBar(title: Text(t.restore)),
      body: ListView(
        children: [
          Padding(padding: const EdgeInsets.all(16), child: Text(t.restoreHint)),
          ListTile(
            title: Text(t.folder),
            trailing: Text(folder == null ? t.folderNone : folder.name),
            onTap: _busy ? null : _pick,
          ),
          ListTile(
            title: Text(t.restoreFile),
            subtitle: Text(t.restoreFileHint),
            enabled: !_busy,
            onTap: _pickFile,
          ),
          const Divider(height: 1),
          if (writable && files.isEmpty && _files != null)
            Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(t.noFiles))),
          for (final file in files)
            ListTile(
              title: Text(file.exportedAt == null ? file.name : formatTime(file.exportedAt!)),
              subtitle: Text(_describe(context, file)),
              enabled: !_busy && file.state == CandidateState.ready,
              onTap: () => _merge(file),
            ),
          if (finish != null) ...[
            const Divider(height: 1),
            ListTile(
              title: Text(t.exportQuarantined),
              subtitle: Text(t.exportHint),
              enabled: writable && !_busy,
              onTap: _export,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(onPressed: _busy ? null : finish, child: Text(t.finish)),
            ),
          ],
        ],
      ),
    );
  }

  String _describe(BuildContext context, BackupCandidate file) {
    final t = context.t.data;
    return switch (file.state) {
      CandidateState.ready => t.fileRows(n: file.rowCount ?? 0),
      CandidateState.tooNew => t.fileTooNew,
      CandidateState.unreadable => t.fileUnreadable,
    };
  }
}
