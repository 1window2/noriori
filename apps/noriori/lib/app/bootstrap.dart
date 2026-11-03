import 'dart:io';

import 'package:noriori_core/noriori_core.dart';
import 'package:noriori_store/noriori_store.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../features/data/platform/channel_backup_folder.dart';
import '../i18n/strings.g.dart';
import 'bundle_pack_assets.dart';
import 'session_providers.dart';

/// 세션 동안 바뀌지 않는, 팩에서 읽은 값 (불변식 4).
final class PackWorld {
  const PackWorld({
    required this.network,
    required this.books,
    this.language = AppLocale.ko,
    this.options = const DisplayOptions(),
    this.theme = ThemeChoice.system,
  });

  final Network network;

  /// 언어별 이름.
  final Map<AppLocale, NameBook> books;
  final AppLocale language;

  /// 저장된 표시 설정과 테마.
  final DisplayOptions options;
  final ThemeChoice theme;
}

final class AppStart {
  const AppStart(this.outcome, this.world);

  final StartOutcome outcome;

  /// [StartReady]일 때만 있다.
  final PackWorld? world;
}

/// 앱 지원 폴더와 빌드 번호를 모아 콜드 스타트를 돌린다.
///
/// [restoring]이면 격리 파일을 둔 채 복원 전용 화면이 쓸 세션을 연다.
Future<AppStart> startApp({bool restoring = false}) async {
  final support = await getApplicationSupportDirectory();
  final info = await PackageInfo.fromPlatform();
  final paths = StorePaths(Directory(support.path));
  await const ChannelBackupFolder().excludeFromOsBackup([
    for (final folder in paths.outsideOsBackup) folder.path,
  ]);
  PackWorld? world;
  final outcome = await ColdStart(
    paths: paths,
    assets: const BundlePackAssets(),
    appBuild: int.parse(info.buildNumber),
    supportedPackSchema: supportedPackSchema,
    interpreter: (db) async {
      final network = Network(await NetworkReader(db).read());
      final language = await readLanguage(SettingStore(db)) ?? LocaleSettings.currentLocale;
      LocaleSettings.setLocaleSync(language);
      world = PackWorld(
        network: network,
        books: {
          for (final locale in AppLocale.values)
            locale: await PackReader(db, languages: nameLanguages(locale)).nameBook(),
        },
        language: language,
        options: await readDisplayOptions(SettingStore(db)),
        theme: await readThemeChoice(SettingStore(db)),
      );
      return RideInterpreter(network);
    },
    now: () => DateTime.now().millisecondsSinceEpoch,
  ).run(restoring: restoring);
  return AppStart(outcome, world);
}
