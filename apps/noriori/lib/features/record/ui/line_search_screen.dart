import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/session_providers.dart';
import '../../../app/widgets/guarded_write.dart';
import '../../../i18n/strings.g.dart';
import '../controller/line_search_controller.dart';
import '../controller/record_session_controller.dart';

/// 노선과 역 검색. 고르면 역 선택기로 간다.
class LineSearchScreen extends ConsumerStatefulWidget {
  const LineSearchScreen({super.key});

  @override
  ConsumerState<LineSearchScreen> createState() => _LineSearchScreenState();
}

class _LineSearchScreenState extends ConsumerState<LineSearchScreen> with GuardedWrite {
  String _text = '';

  Future<void> _open(SearchRow row) => guarded(() async {
        final service = row.serviceId;
        if (service != null) {
          unawaited(context.push('/service/$service'));
          return;
        }
        await ref.read(recordSessionProvider.notifier).open(
              lineId: row.lineId,
              routeId: row.routeId,
              fromNode: row.fromNode,
              focusNode: row.focusNode,
            );
        if (mounted) unawaited(context.push('/record/session'));
      }, failed: context.t.session.saveFailed);

  @override
  Widget build(BuildContext context) {
    final t = context.t.search;
    final results = _text.trim().isEmpty ? null : ref.watch(lineSearchProvider(_text.trim()));
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          autocorrect: false,
          // enableSuggestions: false는 안드로이드에서 visiblePassword 입력이 되어 Gboard가 한국어·일본어를 끈다
          decoration: InputDecoration(hintText: t.hint, border: InputBorder.none),
          onChanged: (value) => setState(() => _text = value),
        ),
      ),
      body: switch (results) {
        null => Column(
            children: [
              ListTile(
                leading: const Icon(Icons.alt_route),
                title: Text(context.t.journey.title),
                subtitle: Text(context.t.journey.hint),
                onTap: () => context.push('/journey'),
              ),
              Expanded(child: _Message(t.prompt)),
            ],
          ),
        AsyncValue(hasValue: true, value: final rows?) when rows.isEmpty => _Message(t.none),
        AsyncValue(hasValue: true, value: final rows?) => ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              return ListTile(
                title: Text(row.title),
                subtitle: Text(
                  row.serviceId == null
                      ? row.subtitle
                      : [context.t.service.kind, if (row.subtitle.isNotEmpty) row.subtitle].join(' · '),
                ),
                // 역 결과(열람 전용 역은 그 자리)는 지도에서 그 역으로 바로 갈 수 있다 (사용자 요청 2026-11-16)
                trailing: switch (row.fromNode ?? row.focusNode) {
                  null => null,
                  final node => IconButton(
                      tooltip: t.showOnMap,
                      icon: const Icon(Icons.map_outlined),
                      onPressed: () {
                        ref.read(mapFocusProvider.notifier).focus(node);
                        context.go('/map');
                      },
                    ),
                },
                onTap: () => _open(row),
              );
            },
          ),
        AsyncValue(hasError: true, :final error) => _Message('$error'),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(padding: const EdgeInsets.all(24), child: Text(text)),
      );
}
