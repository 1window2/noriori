import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:noriori_core/noriori_core.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../app/session_providers.dart';
import '../../../app/widgets/pills.dart';
import '../../../i18n/strings.g.dart';

/// 앱 버전 줄.
final _versionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});

/// 언어 이름은 번역하지 않는다. 다른 언어로 잘못 바꿔도 찾을 수 있어야 한다.
const _languages = {AppLocale.ko: '한국어', AppLocale.en: 'English', AppLocale.ja: '日本語'};

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => SafeArea(
        child: ListView(
          children: [
            ListTile(
              title: Text(context.t.settings.dataEdition),
              subtitle: switch (ref.watch(packFactsProvider)) {
                AsyncData(value: final v) =>
                  Text(context.t.settings.packSummary(
                    stations: countLabel(v.stations),
                    lines: countLabel(v.lines),
                  )),
                _ => null,
              },
              trailing: Text(ref.watch(editionProvider)),
            ),
            _Choice(
              title: context.t.settings.language,
              child: SlidingChoice<AppLocale>(
                values: _languages.keys.toList(),
                label: (value) => _languages[value]!,
                selected: ref.watch(languageProvider),
                onChanged: (value) => ref.read(languageProvider.notifier).set(value),
              ),
            ),
            _Choice(
              title: context.t.settings.theme,
              child: SlidingChoice<ThemeChoice>(
                values: ThemeChoice.values,
                label: (value) => switch (value) {
                  ThemeChoice.light => context.t.settings.themeLight,
                  ThemeChoice.dark => context.t.settings.themeDark,
                  ThemeChoice.system => context.t.settings.themeSystem,
                },
                selected: ref.watch(themeChoiceProvider),
                onChanged: ref.read(themeChoiceProvider.notifier).set,
              ),
            ),
            for (final (label, value, change) in [
              (
                context.t.settings.showClosed,
                ref.watch(displayOptionsProvider).showClosed,
                (bool next) =>
                    ref.read(displayOptionsProvider.notifier).update(showClosed: next),
              ),
              (
                context.t.settings.showArchive,
                ref.watch(displayOptionsProvider).showArchive,
                (bool next) =>
                    ref.read(displayOptionsProvider.notifier).update(showArchive: next),
              ),
              (
                context.t.settings.showBranches,
                ref.watch(displayOptionsProvider).showBranches,
                (bool next) =>
                    ref.read(displayOptionsProvider.notifier).update(showBranches: next),
              ),
            ])
              SwitchListTile(title: Text(label), value: value, onChanged: change),
            SwitchListTile(
              title: Text(context.t.settings.carryover),
              subtitle: Text(context.t.settings.carryoverHint),
              value: ref.watch(carryoverProvider),
              onChanged: (next) => ref.read(displayOptionsProvider.notifier).update(carryover: next),
            ),
            _Link(title: context.t.settings.data, onTap: () => context.push('/settings/data')),
            _Link(title: context.t.news.history, onTap: () => context.push('/settings/news')),
            _Link(title: context.t.deleted.title, onTap: () => context.push('/settings/deleted')),
            _Link(title: context.t.settings.sources, onTap: () => context.push('/settings/sources')),
            _Link(
              title: context.t.settings.licenses,
              onTap: () => showLicensePage(
                context: context,
                applicationName: context.t.app.name,
              ),
            ),
            ListTile(
              title: Text(context.t.settings.version),
              trailing: Text(ref.watch(_versionProvider).value ?? ''),
            ),
          ],
        ),
      );
}

/// 제목 아래의 고르기 단추 한 벌.
class _Choice extends StatelessWidget {
  const _Choice({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            child,
          ],
        ),
      );
}

/// 다른 화면으로 가는 줄.
class _Link extends StatelessWidget {
  const _Link({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      );
}
