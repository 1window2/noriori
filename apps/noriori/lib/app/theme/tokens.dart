import 'package:flutter/material.dart';

/// 색 토큰 (DESIGN §7.1). 지도 스타일 JSON도 이 값에서 만든다.
///
/// 파랑과 빨강은 탄 구간과 기록 동작에만 쓴다. 나머지는 종이와 먹이다.
@immutable
final class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.land,
    required this.water,
    required this.surface,
    required this.paper,
    required this.text,
    required this.textMuted,
    required this.textClosed,
    required this.hairline,
    required this.track,
    required this.lineUnridden,
    required this.lineClosedUnridden,
    required this.selectorGone,
    required this.selectorGoneText,
    required this.lineRidden,
    required this.lineRiddenSoft,
    required this.lineClosedRidden,
    required this.onAccent,
  });

  static const light = AppTokens(
    land: Color(0xFFF5F0E6),
    water: Color(0xFFCFE0E6),
    surface: Color(0xFFFBF8F1),
    paper: Color(0xFFFFFDF8),
    text: Color(0xFF1F2328),
    textMuted: Color(0xFF5C6066),
    textClosed: Color(0xFF8A8478),
    hairline: Color(0xFFE6DFD1),
    track: Color(0xFFDDD6C7),
    lineUnridden: Color(0xFF7A7F86),
    lineClosedUnridden: Color(0xFFA2988A),
    selectorGone: Color(0xFFE3E6E0),
    selectorGoneText: Color(0xFFD3D7D0),
    lineRidden: Color(0xFF1F6FEB),
    lineRiddenSoft: Color(0xFFBFD6F8),
    lineClosedRidden: Color(0xFFC8352B),
    onAccent: Color(0xFFFFFFFF),
  );

  static const dark = AppTokens(
    land: Color(0xFF14171C),
    water: Color(0xFF0F1F2B),
    surface: Color(0xFF1C2027),
    paper: Color(0xFF232830),
    text: Color(0xFFE8EAED),
    textMuted: Color(0xFFA7ADB5),
    textClosed: Color(0xFF8E949D),
    hairline: Color(0xFF333A44),
    track: Color(0xFF3A414C),
    lineUnridden: Color(0xFF8A919B),
    lineClosedUnridden: Color(0xFF666E7A),
    selectorGone: Color(0xFF2F3530),
    selectorGoneText: Color(0xFF3D443E),
    lineRidden: Color(0xFF5AA2FF),
    lineRiddenSoft: Color(0xFF27476F),
    lineClosedRidden: Color(0xFFFF6B60),
    onAccent: Color(0xFF0B1320),
  );

  final Color land;
  final Color water;

  /// 화면 바탕.
  final Color surface;

  /// 바탕 위에 놓인 카드와 탭 바.
  final Color paper;
  final Color text;
  final Color textMuted;
  final Color textClosed;

  /// 구분선.
  final Color hairline;

  /// 진행률 막대의 바탕.
  final Color track;
  final Color lineUnridden;
  final Color lineClosedUnridden;

  /// 역 선택기의 폐선 줄기. 사용자가 승인한 목업 색이라 지도보다 옅다.
  final Color selectorGone;

  /// 폐선 분기의 이름과 행선지. 분기선과 거의 같은 농도로 읽히게만 조금 진하다.
  final Color selectorGoneText;
  final Color lineRidden;

  /// 이미 탄 구간. 지금 고르는 구간([lineRidden])과 구분한다.
  final Color lineRiddenSoft;
  final Color lineClosedRidden;

  /// 파랑 위의 글자.
  final Color onAccent;

  @override
  AppTokens copyWith() => this;

  @override
  AppTokens lerp(AppTokens? other, double t) => t < .5 || other == null ? this : other;
}
