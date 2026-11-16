import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/session_providers.dart';
import '../../../app/widgets/load_error.dart';
import '../../../app/widgets/undo_snack.dart';
import '../../../i18n/strings.g.dart';
import '../controller/record_list_controller.dart';
import 'session_date.dart' show showUnridable;
import 'session_save_bar.dart' show relocationLabel;

/// 기록 수정과 재해석 답변 (ARCHITECTURE §2.3 `/record/:rideId`).
class RecordEditScreen extends ConsumerWidget {
  const RecordEditScreen({super.key, required this.rideId});

  final String rideId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ride = ref.watch(rideProvider(rideId));
    final t = context.t.editRide;
    return Scaffold(
      appBar: AppBar(title: Text(t.title)),
      body: switch (ride) {
        AsyncValue(hasValue: true, value: final found?) => _Form(ride: found),
        AsyncValue(hasValue: true) => Center(child: Text(t.missing)),
        AsyncValue(hasError: true, :final error) => LoadError(error),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.ride});

  final Ride ride;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  late final _date = TextEditingController(text: widget.ride.dateInput?.replaceAll('-XX', ''));
  late final _times = TextEditingController(text: widget.ride.times);
  late final _train = TextEditingController(text: widget.ride.trainName);
  late final _car = TextEditingController(text: widget.ride.carNo);
  late final _note = TextEditingController(text: widget.ride.note);
  late bool _fromAlighted = widget.ride.fromAlighted;
  late bool _toAlighted = widget.ride.toAlighted;
  late final _transfers = {for (final node in widget.ride.transferNodes) node.value};
  final _answers = <String, _Answer>{};
  bool _badDate = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final field in [_date, _times, _train, _car, _note]) {
      field.dispose();
    }
    super.dispose();
  }

  String? _text(TextEditingController field) {
    final value = field.text.trim();
    return value.isEmpty ? null : value;
  }

  /// 경로가 갈려 답이 필요한 구간. 같은 구간을 여러 번 돌았으면 한 번만 묻는다.
  List<_Question> get _questions {
    final raw = widget.ride.dateInput;
    final date = raw == null ? null : DateSpan.parse(raw);
    final resolver = RouteResolver(ref.read(networkProvider));
    final out = <String, _Question>{};
    for (final leg in widget.ride.legs) {
      Expansion record({String? direction}) => resolver.record(
            leg.routeId.value,
            leg.fromNode.value,
            leg.toNode.value,
            date: date,
            direction: direction ?? leg.direction,
            askDirection: true,
          );
      final open = record();
      if (open.status != ResolveStatus.needsInput) continue;
      final Iterable<_Answer> answers = open.reason == ExpandReason.ambiguousPath
          ? [
              for (final direction in const [seqUp, seqDown])
                if (record(direction: direction).meters case final meters?)
                  _Answer(direction: direction, meters: meters),
            ]
          : [for (final option in open.options) _Answer(asOf: option.asOf, meters: option.meters)];
      out[_legKey(leg)] = _Question(
        leg,
        answers.toList(),
        byDirection: open.reason == ExpandReason.ambiguousPath,
        options: open.options,
      );
    }
    return out.values.toList();
  }

  bool _chosen(RideLeg leg, _Answer answer) => _answers[_legKey(leg)] == null
      ? (answer.unknown && leg.resolveUnknown) ||
          (answer.asOf != null && answer.asOf == leg.resolveAsOf)
      : _answers[_legKey(leg)] == answer;

  Future<void> _save() async {
    final String? date;
    try {
      date = parseDateInput(_date.text);
      final today = ref.read(todayProvider);
      if (date != null && DateSpan.parse(date).lo.compareTo(today) > 0) {
        throw const FormatException('앞날이다');
      }
    } on FormatException {
      setState(() => _badDate = true);
      return;
    }
    setState(() {
      _saving = true;
      _badDate = false;
    });
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final t = context.t.editRide;
    final saved = t.saved;
    final refused = t.unridable;
    final undo = context.t.record.undo;
    try {
      final ride = widget.ride;
      final commands = ref.read(recordCommandsProvider);
      var after = ride.edited(
              dateInput: date,
              times: _text(_times),
              trainName: _text(_train),
              carNo: _text(_car),
              note: _text(_note),
              fromAlighted: _fromAlighted,
              toAlighted: _toAlighted,
              transferNodes: [for (final node in _transfers) NodeId(node)],
            );
      for (final MapEntry(:key, value: answer) in _answers.entries) {
        after = after.answered(
          (leg) => _legKey(leg) == key,
          direction: answer.direction,
          asOf: answer.asOf,
          unknown: answer.unknown,
        );
      }
      // 날짜를 바꿔 그날 탈 수 없게 되면 고치지 않고 원래 날짜로 돌린다 (DESIGN §2.8 J)
      if (date != ride.dateInput && RideInterpreter(ref.read(networkProvider)).unridable(after)) {
        setState(() {
          _saving = false;
          _date.text = ride.dateInput?.replaceAll('-XX', '') ?? '';
        });
        await showUnridable(context, refused);
        return;
      }
      final change = await commands.save(ride, after);
      if (mounted) router.pop();
      showUndoSnack(
        messenger,
        message: saved,
        undoLabel: undo,
        onUndo: () => commands.undo(change),
      );
    } on Object catch (error) {
      debugPrint('수정 실패: $error');
      messenger.showSnackBar(SnackBar(content: Text(t.failed)));
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    setState(() => _saving = true);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final t = context.t.record;
    final commands = ref.read(recordCommandsProvider);
    final Change? change;
    try {
      change = await commands.delete(widget.ride.rideId);
    } on Object catch (error) {
      debugPrint('삭제 실패: $error');
      messenger.showSnackBar(SnackBar(content: Text(context.t.editRide.failed)));
      if (mounted) setState(() => _saving = false);
      return;
    }
    if (mounted) router.pop();
    if (change case final done?) {
      showUndoSnack(
        messenger,
        message: t.deleted,
        undoLabel: t.undo,
        onUndo: () => commands.undo(done),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.editRide;
    final text = Theme.of(context).textTheme;
    final ride = widget.ride;
    final questions = _questions;
    final session = context.t.session;
    final stops = ref.watch(rideStopsProvider(ride.rideId.value)).value ?? const {};
    Widget field(TextEditingController controller, String label, {String? error, int lines = 1}) =>
        TextField(
          controller: controller,
          maxLines: lines,
          decoration: InputDecoration(labelText: label, errorText: error),
        );
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        for (final leg in ride.legs)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(_legTitle(leg), style: text.titleMedium),
          ),
        const SizedBox(height: 12),
        field(_date, t.date, error: _badDate ? context.t.session.dateBad : null),
        field(_times, t.times),
        field(_train, t.train),
        field(_car, t.car),
        field(_note, t.note, lines: 3),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(t.fromAlighted),
          value: _fromAlighted,
          onChanged: (value) => setState(() => _fromAlighted = value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(t.toAlighted),
          value: _toAlighted,
          onChanged: (value) => setState(() => _toAlighted = value),
        ),
        if (stops.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(t.transfers),
            subtitle: Text(t.transfersHint),
            children: [
              for (final MapEntry(:key, :value) in stops.entries)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(value),
                  value: _transfers.contains(key),
                  onChanged: (on) => setState(() {
                    if (on ?? false) {
                      _transfers.add(key);
                    } else {
                      _transfers.remove(key);
                    }
                  }),
                ),
            ],
          ),
        for (final question in questions) ...[
          const SizedBox(height: 8),
          Text(
            question.byDirection ? session.chooseDirection : session.chooseRelocation,
            style: text.titleSmall,
          ),
          if (questions.length > 1)
            Text(_legTitle(question.leg), style: text.bodySmall),
          for (final answer in [...question.answers, const _Answer(unknown: true)])
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(switch (answer) {
                _Answer(unknown: true) => session.dontKnow,
                _Answer(:final asOf?) => relocationLabel(
                    context,
                    question.options,
                    question.options.firstWhere((option) => option.asOf == asOf),
                  ),
                _ => session.directionKm(km: kmLabel(answer.meters ?? 0)),
              }),
              trailing: _chosen(question.leg, answer) ? const Icon(Icons.check) : null,
              onTap: () => setState(() => _answers[_legKey(question.leg)] = answer),
            ),
        ],
        const SizedBox(height: 16),
        FilledButton(onPressed: _saving ? null : _save, child: Text(t.save)),
        TextButton(onPressed: _saving ? null : _delete, child: Text(t.delete)),
      ],
    );
  }
}

String _legKey(RideLeg leg) => '${leg.routeId.value}|${leg.fromNode.value}|${leg.toNode.value}';

/// `노선 · 출발 → 도착`.
String _legTitle(RideLeg leg) => '${leg.lineLabel} · ${leg.fromLabel} → ${leg.toLabel}';

/// 경로 질문의 답 하나.
final class _Answer {
  const _Answer({this.direction, this.asOf, this.meters, this.unknown = false});

  final String? direction;
  final String? asOf;
  final int? meters;

  /// `모름`. 공통 구간만 크레딧을 받는다.
  final bool unknown;

  @override
  bool operator ==(Object other) =>
      other is _Answer && other.direction == direction && other.asOf == asOf && other.unknown == unknown;

  @override
  int get hashCode => Object.hash(direction, asOf, unknown);
}

final class _Question {
  const _Question(this.leg, this.answers, {required this.byDirection, required this.options});

  final RideLeg leg;
  final List<_Answer> answers;
  final bool byDirection;
  final List<RelocationOption> options;
}
