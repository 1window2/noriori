import 'package:flutter/material.dart';

import 'app/bootstrap.dart';
import 'app/session_providers.dart';
import 'app/start_gate.dart';
import 'app/theme/app_theme.dart';
import 'i18n/strings.g.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicense();
  LocaleSettings.setLocaleSync(
    deviceLanguage(WidgetsBinding.instance.platformDispatcher.locale.languageCode),
  );
  // 한국어는 복수형이 없다. 해석기를 주지 않으면 복수 문구마다 로그가 찍힌다
  LocaleSettings.setPluralResolverSync(
    language: 'ko',
    cardinalResolver: (n, {zero, one, two, few, many, other}) => other!,
    ordinalResolver: (n, {zero, one, two, few, many, other}) => other!,
  );
  runApp(TranslationProvider(child: const StartGate(start: startApp)));
}
