import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/date_text.dart';
import '../../../app/session_providers.dart';
import '../../../app/widgets/guarded_write.dart';
import '../../../app/widgets/undo_snack.dart';
import '../../../i18n/strings.g.dart';
import '../controller/journey_controller.dart';
import '../controller/line_search_controller.dart';
import 'session_date.dart';

typedef _Station = ({String node, String name});

/// 여러 노선 한 번에 기록. 환승이 많은 여행을 노선마다 따로 넣지 않게 한다.
class JourneyScreen extends ConsumerStatefulWidget {
  const JourneyScreen({super.key});

  @override
  ConsumerState<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends ConsumerState<JourneyScreen> with GuardedWrite {
  _Station? _from;
  _Station? _to;
  late String? _date = ref.read(todayProvider);

  Future<void> _pick(bool start) async {
    final picked = await showDialog<_Station>(
      context: context,
      useSafeArea: false,
      builder: (context) => const _StationPicker(),
    );
    if (picked == null) return;
    setState(() => start ? _from = picked : _to = picked);
  }

  Future<void> _editDate() async {
    final result = await showDialog<DateAnswer>(
      context: context,
      builder: (context) => SessionDateDialog(current: _date, today: ref.read(todayProvider)),
    );
    if (result != null) setState(() => _date = result.value);
  }

  Future<void> _save(Journey journey) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final t = context.t;
    final commands = ref.read(journeyCommandsProvider);
    final change = await commands.save(journey, title: '${_from!.name} → ${_to!.name}', date: _date);
    if (mounted) router.go('/record');
    showUndoSnack(
      messenger,
      message: t.journey.saved(n: journey.legs.length),
      undoLabel: t.record.undo,
      onUndo: () => commands.undo(change),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.journey;
    final text = Theme.of(context).textTheme;
    final book = ref.watch(nameBookProvider);
    final from = _from;
    final to = _to;
    final date = _date;
    final journey = from == null || to == null || from.node == to.node
        ? null
        : ref.watch(journeyProvider((from: from.node, to: to.node, date: date)));
    return Scaffold(
      appBar: AppBar(title: Text(t.title)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(t.hint, style: text.bodySmall),
          ),
          ListTile(
            title: Text(t.from),
            trailing: Text(from?.name ?? t.choose),
            onTap: () => _pick(true),
          ),
          ListTile(
            title: Text(t.to),
            trailing: Text(to?.name ?? t.choose),
            onTap: () => _pick(false),
          ),
          ListTile(
            title: Text(context.t.session.dateTitle),
            trailing: Text(date == null ? context.t.session.dateUnknown : dateText(context.t, date)),
            onTap: _editDate,
          ),
          const Divider(height: 1),
          if (journey != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
              child: Text('${kmLabel(journey.meters)} km', style: text.titleLarge),
            ),
            for (final leg in journey.legs)
              _LegRow(line: book.lines[leg.lineId] ?? leg.lineId, leg: leg),
            Padding(
              padding: const EdgeInsets.all(24),
              child: FilledButton(onPressed: writing ? null : () => guarded(() => _save(journey), failed: context.t.session.saveFailed), child: Text(t.save)),
            ),
          ] else if (from != null && to != null)
            Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(t.none))),
        ],
      ),
    );
  }
}

class _LegRow extends ConsumerWidget {
  const _LegRow({required this.line, required this.leg});

  final String line;
  final JourneyLeg leg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = ref.watch(_legNames((leg.from, leg.to))).value ?? const <String, String>{};
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      title: Text(line),
      subtitle: Text('${names[leg.from] ?? ''} → ${names[leg.to] ?? ''}'),
      trailing: Text('${kmLabel(leg.meters)} km'),
    );
  }
}

final _legNames = FutureProvider.autoDispose.family<Map<String, String>, (String, String)>(
  (ref, pair) => ref.watch(packReaderProvider).nodeNames([pair.$1, pair.$2]),
);

class _StationPicker extends ConsumerStatefulWidget {
  const _StationPicker();

  @override
  ConsumerState<_StationPicker> createState() => _StationPickerState();
}

class _StationPickerState extends ConsumerState<_StationPicker> {
  String _text = '';

  @override
  Widget build(BuildContext context) {
    final t = context.t.journey;
    final value = _text.trim();
    final rows = value.isEmpty ? const <SearchRow>[] : ref.watch(lineSearchProvider(value)).value ?? const <SearchRow>[];
    // 같은 역이 회사마다 따로 있어도 한 줄이다. 이름만 같은 다른 역은 노선으로 구분한다
    final groups = ref.watch(networkProvider).data.nodeGroups;
    final seen = <String>{};
    final stations = [
      for (final row in rows)
        if (row.fromNode case final node? when seen.add(groups[node] ?? node))
          (node: node, name: row.title, line: row.subtitle),
    ];
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: TextField(
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(hintText: t.stationHint, border: InputBorder.none),
            onChanged: (value) => setState(() => _text = value),
          ),
        ),
        body: ListView.builder(
          itemCount: stations.length,
          itemBuilder: (context, index) => ListTile(
            title: Text(stations[index].name),
            subtitle: Text(stations[index].line),
            onTap: () => Navigator.pop(
              context,
              (node: stations[index].node, name: stations[index].name),
            ),
          ),
        ),
      ),
    );
  }
}
