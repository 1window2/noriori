import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// 한글과 라틴 글자는 앱에 넣은 글꼴로 그린다. 일본어 한자는 기기 글꼴로 내려간다.
const appFontFamily = 'Pretendard';

/// 글꼴은 SIL OFL이라 배포물에 라이선스를 함께 넣어야 한다.
void registerFontLicense() => LicenseRegistry.addLicense(() async* {
      final text = await rootBundle.loadString('assets/fonts/LICENSE-Pretendard.txt');
      yield LicenseEntryWithLineBreaks(const [appFontFamily], text);
      // 지도의 역 이름 글리프다. 앱 글꼴은 아니지만 함께 나간다
      final noto = await rootBundle.loadString('assets/fonts/LICENSE-Noto.txt');
      yield LicenseEntryWithLineBreaks(const ['Noto Sans', 'Noto Sans CJK'], noto);
    });

/// 숫자 열은 자리를 맞춘다. 큰 대표 수치에는 쓰지 않는다.
const tabularFigures = [FontFeature.tabularFigures()];

/// 상단바는 앱 바탕이 비치게 둔다. 값이 없는 화면에서 Android는 회색 띠를 남긴다.
SystemUiOverlayStyle overlayStyle(Brightness brightness) => SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: brightness,
      statusBarIconBrightness: brightness == Brightness.light ? Brightness.dark : Brightness.light,
    );

/// 화면마다 AppBar가 있지는 않다. 앱 전체에 한 번 깐다.
Widget withOverlayStyle(BuildContext context, Widget? child) => AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle(Theme.of(context).brightness),
      child: child ?? const SizedBox.shrink(),
    );

ThemeData appTheme(Brightness brightness) {
  final t = brightness == Brightness.light ? AppTokens.light : AppTokens.dark;
  // 시드 색으로 만들면 탭과 버튼이 라벤더가 되어 크림색과 어긋난다. 역할을 직접 적는다.
  final scheme = ColorScheme(
    brightness: brightness,
    primary: t.lineRidden,
    onPrimary: t.onAccent,
    primaryContainer: t.lineRiddenSoft,
    onPrimaryContainer: t.text,
    secondary: t.text,
    onSecondary: t.surface,
    secondaryContainer: t.land,
    onSecondaryContainer: t.text,
    error: t.lineClosedRidden,
    onError: t.onAccent,
    surface: t.surface,
    onSurface: t.text,
    onSurfaceVariant: t.textMuted,
    surfaceContainerLowest: t.paper,
    surfaceContainerLow: t.paper,
    surfaceContainer: t.paper,
    surfaceContainerHigh: t.paper,
    surfaceContainerHighest: t.land,
    outline: t.hairline,
    outlineVariant: t.hairline,
    inverseSurface: t.text,
    onInverseSurface: t.surface,
    inversePrimary: t.lineRiddenSoft,
    surfaceTint: Colors.transparent,
  );
  final base = ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: appFontFamily,
  ).textTheme;
  TextStyle size(TextStyle? style, double px, FontWeight weight, Color color, [double height = 1.3]) =>
      style!.copyWith(
        fontSize: px,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: 0,
      );
  // 굵기 3단계, 크기 5단계 (시안 0번)
  final text = base.copyWith(
    displayMedium: size(base.displayMedium, 52, FontWeight.w700, t.text, 1.05),
    displaySmall: size(base.displaySmall, 40, FontWeight.w700, t.text, 1.1),
    headlineMedium: size(base.headlineMedium, 28, FontWeight.w700, t.text),
    titleLarge: size(base.titleLarge, 20, FontWeight.w700, t.text, 1.25),
    titleMedium: size(base.titleMedium, 16, FontWeight.w500, t.text),
    titleSmall: size(base.titleSmall, 14, FontWeight.w700, t.text),
    bodyLarge: size(base.bodyLarge, 16, FontWeight.w400, t.text),
    bodyMedium: size(base.bodyMedium, 14, FontWeight.w400, t.text),
    bodySmall: size(base.bodySmall, 12, FontWeight.w400, t.textMuted),
    labelLarge: size(base.labelLarge, 15, FontWeight.w700, t.text),
    labelMedium: size(base.labelMedium, 13, FontWeight.w500, t.textMuted),
    labelSmall: size(base.labelSmall, 11, FontWeight.w400, t.textClosed),
  );
  return ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: appFontFamily,
    textTheme: text,
    scaffoldBackgroundColor: t.surface,
    splashFactory: InkRipple.splashFactory,
    extensions: [t],
    dividerTheme: DividerThemeData(color: t.hairline, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: t.surface,
      foregroundColor: t.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
      systemOverlayStyle: overlayStyle(brightness),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: t.lineRidden,
      foregroundColor: t.onAccent,
      shape: const CircleBorder(),
      elevation: 4,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: t.lineRidden,
        foregroundColor: t.onAccent,
        disabledBackgroundColor: t.track,
        disabledForegroundColor: t.textClosed,
        textStyle: text.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
    ),
    dialogTheme: DialogThemeData(backgroundColor: t.paper),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: t.paper),
    listTileTheme: ListTileThemeData(
      titleTextStyle: text.titleMedium,
      subtitleTextStyle: text.bodySmall,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: t.text,
      contentTextStyle: text.bodyMedium?.copyWith(color: t.surface),
      actionTextColor: t.lineRiddenSoft,
    ),
  );
}

extension AppThemeTokens on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}
