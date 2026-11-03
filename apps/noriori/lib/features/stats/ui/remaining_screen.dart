import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:noriori_core/noriori_core.dart';

import '../../../app/location.dart';
import '../../../app/session_providers.dart';
import '../../../app/widgets/load_error.dart';
import '../../../app/widgets/pills.dart';
import '../../../i18n/strings.g.dart';
import '../controller/remaining_controller.dart';

enum _View { shortest, near, operators }

/// 남은 구간. 안 탄 곳을 이어 붙여 보여 주고 누르면 지도에서 그 노선을 본다.
class RemainingScreen extends ConsumerStatefulWidget {
  const RemainingScreen({super.key});

  @override
  ConsumerState<RemainingScreen> createState() => _RemainingScreenState();
}

class _RemainingScreenState extends ConsumerState<RemainingScreen> {
  _View _view = _View.shortest;
  (double, double)? _here;
  bool _denied = false;
  bool _locating = false;

  /// 위치 권한은 `가까운 곳`을 처음 누를 때만 묻는다.
  Future<void> _near() async {
    setState(() {
      _view = _View.near;
      _denied = false;
    });
    if (_here != null) return;
    setState(() => _locating = true);
    (double, double)? here;
    try {
      here = await ref.read(locationProvider).current();
    } on Object catch (error) {
      debugPrint('위치 실패: $error');
    }
    if (!mounted) return;
    setState(() {
      _here = here;
      _denied = here == null;
      _locating = false;
    });
  }

  void _showOnMap(String lineId) {
    ref.read(soloLineIdProvider.notifier).set(lineId);
    context.go('/map');
  }

  Widget _tile(RemainingData data, RemainingSection section, {String? trailing}) {
    final book = ref.read(nameBookProvider);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      title: Text(book.lines[section.lineId] ?? section.lineId),
      subtitle: Text('${data.names[section.from] ?? section.from} – ${data.names[section.to] ?? section.to}'),
      trailing: Text(trailing ?? '${kmLabel(section.meters)} km'),
      onTap: () => _showOnMap(section.lineId),
    );
  }

  List<Widget> _rows(RemainingData data) {
    final t = context.t.remaining;
    final text = Theme.of(context).textTheme;
    Widget center(String message) => Padding(
          padding: const EdgeInsets.all(32),
          child: Center(child: Text(message, textAlign: TextAlign.center)),
        );
    switch (_view) {
      case _View.shortest:
        final rows = data.byShortest;
        if (rows.isEmpty) return [center(t.empty)];
        return [for (final section in rows) _tile(data, section)];
      case _View.near:
        if (_locating) return [const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))];
        final here = _here;
        if (here == null) return [center(_denied ? t.nearDenied : t.empty)];
        final rows = nearbySections(data.all, positions: data.positions, lat: here.$1, lon: here.$2);
        if (rows.isEmpty) return [center(t.nearNone(km: nearbyKm.round()))];
        return [
          for (final (section, km) in rows)
            _tile(data, section, trailing: t.nearAway(km: km.toStringAsFixed(km < 10 ? 1 : 0))),
        ];
      case _View.operators:
        if (data.groups.isEmpty) return [center(t.empty)];
        final book = ref.read(nameBookProvider);
        return [
          for (final (operator, sections) in data.groups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
              child: Text(book.operators[operator] ?? operator, style: text.titleSmall),
            ),
            for (final section in sections) _tile(data, section),
          ],
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t.remaining;
    return Scaffold(
      appBar: AppBar(title: Text(t.title)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilterPillRow(
            pills: [
              FilterPill(
                label: t.shortest,
                selected: _view == _View.shortest,
                onTap: () => setState(() => _view = _View.shortest),
              ),
              FilterPill(label: t.near, selected: _view == _View.near, onTap: _near),
              FilterPill(
                label: t.operators,
                selected: _view == _View.operators,
                onTap: () => setState(() => _view = _View.operators),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: switch (ref.watch(remainingProvider)) {
              AsyncValue(hasValue: true, value: final data?) => ListView(children: _rows(data)),
              AsyncValue(hasError: true, :final error) => LoadError(error),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ],
      ),
    );
  }
}
