import 'package:flutter/material.dart';

/// Design tokens for Rise Protocol.
///
/// Everything visual — spacing, radii, motion, and the semantic colors that
/// [ColorScheme] doesn't cover (surface tiers, success/warning, the mission
/// accent, the ringing-screen ground) — lives here as a single
/// [ThemeExtension] so screens never reach for raw `Color(0xFF…)` or
/// `SizedBox(height: 24)` literals.
///
/// Access it with `context.tokens` (see the extension at the bottom of this
/// file). The three factories — [AppTokens.light], [AppTokens.dark],
/// [AppTokens.ringing] — are wired into the matching [ThemeData] in
/// `app_theme.dart`.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.isDark,
    required this.brand,
    required this.brandMuted,
    required this.onBrand,
    required this.missionAccent,
    required this.success,
    required this.warning,
    required this.danger,
    required this.surface0,
    required this.surface1,
    required this.surface2,
    required this.hairline,
    required this.textPrimary,
    required this.textSecondary,
    required this.textFaint,
    required this.ringingBackground,
    required this.ringingForeground,
  });

  /// Whether this token set is a dark one. Lets shadow opacity adapt without
  /// a [BuildContext]; not a design-surface value on its own.
  final bool isDark;

  // ---- Semantic colors -----------------------------------------------------

  /// Primary brand accent — the warm amber the app is built around.
  final Color brand;

  /// A desaturated brand tint for fills behind brand-colored content.
  final Color brandMuted;

  /// Foreground that sits on top of [brand].
  final Color onBrand;

  /// Used only for mission UI (progress rings, "start mission" affordances)
  /// so the wake-up task reads as distinct from ordinary brand chrome.
  final Color missionAccent;

  final Color success;
  final Color warning;
  final Color danger;

  /// Page background.
  final Color surface0;

  /// Cards and list rows.
  final Color surface1;

  /// Controls and nested fills that need to lift off [surface1].
  final Color surface2;

  /// 1px separators / card borders.
  final Color hairline;

  final Color textPrimary;
  final Color textSecondary;

  /// Disabled text and the faintest supporting labels.
  final Color textFaint;

  /// The ringing screen deliberately ignores light/dark — it is always a
  /// near-black ground with high-contrast foreground so it can't be misread
  /// half asleep.
  final Color ringingBackground;
  final Color ringingForeground;

  // ---- Spacing scale (4-point) ------------------------------------------
  static const double space2 = 2;
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space40 = 40;
  static const double space56 = 56;

  // ---- Radii ------------------------------------------------------------
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double radiusXl = 28;
  static const double radiusPill = 999;

  static const BorderRadius cornerSm = BorderRadius.all(Radius.circular(radiusSm));
  static const BorderRadius cornerMd = BorderRadius.all(Radius.circular(radiusMd));
  static const BorderRadius cornerLg = BorderRadius.all(Radius.circular(radiusLg));
  static const BorderRadius cornerXl = BorderRadius.all(Radius.circular(radiusXl));

  // ---- Motion ---------------------------------------------------------------
  /// Toggles, chips, small state changes.
  static const Duration motionFast = Duration(milliseconds: 140);

  /// Default for most transitions.
  static const Duration motionBase = Duration(milliseconds: 240);

  /// Page and sheet transitions.
  static const Duration motionSlow = Duration(milliseconds: 360);

  /// The ringing screen's ambient background drift — intentionally very slow.
  static const Duration motionAmbient = Duration(seconds: 12);

  static const Curve easeStandard = Curves.easeOutCubic;
  static const Curve easeEmphasized = Curves.easeOutBack;

  // ---- Elevation ----------------------------------------------------------
  /// Soft resting shadow for raised cards (the next-alarm hero, sheets).
  /// Large and diffuse rather than tight — reads as depth, not a drop line.
  List<BoxShadow> get shadowCard => [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.40 : 0.05),
          blurRadius: 24,
          spreadRadius: -4,
          offset: const Offset(0, 8),
        ),
      ];

  List<BoxShadow> get shadowLifted => [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.55 : 0.14),
          blurRadius: 48,
          spreadRadius: -8,
          offset: const Offset(0, 20),
        ),
      ];

  /// Amber glow for the one primary action / hero per screen. In the sleek
  /// dark UI the brand shows up as this halo, not as big flat fills.
  List<BoxShadow> get glow => [
        BoxShadow(
          color: brand.withOpacity(isDark ? 0.30 : 0.20),
          blurRadius: 40,
          spreadRadius: -12,
          offset: const Offset(0, 8),
        ),
      ];

  // ---- Factories ----------------------------------------------------------

  factory AppTokens.light() {
    return const AppTokens(
      isDark: false,
      brand: Color(0xFFB35A22),
      brandMuted: Color(0xFFF6E7DA),
      onBrand: Color(0xFFFFFFFF),
      missionAccent: Color(0xFF1F7A6C),
      success: Color(0xFF2E7D4F),
      warning: Color(0xFFA9760C),
      danger: Color(0xFFB5432F),
      surface0: Color(0xFFF6F6F8),
      surface1: Color(0xFFFFFFFF),
      surface2: Color(0xFFECECEF),
      hairline: Color(0x14101014),
      textPrimary: Color(0xFF16161A),
      textSecondary: Color(0xFF56555E),
      textFaint: Color(0xFF95949E),
      ringingBackground: Color(0xFF060608),
      ringingForeground: Color(0xFFF7F6FA),
    );
  }

  factory AppTokens.dark() {
    return const AppTokens(
      isDark: true,
      brand: Color(0xFFF2A65E),
      brandMuted: Color(0xFF2A1F16),
      onBrand: Color(0xFF1A1206),
      missionAccent: Color(0xFF5BC0AE),
      success: Color(0xFF57C98A),
      warning: Color(0xFFE6B95E),
      danger: Color(0xFFEB7A63),
      surface0: Color(0xFF0A0A0C),
      surface1: Color(0xFF121216),
      surface2: Color(0xFF1B1B21),
      hairline: Color(0x14FFFFFF),
      textPrimary: Color(0xFFF4F3F6),
      textSecondary: Color(0xFFA9A7B2),
      textFaint: Color(0xFF6E6C77),
      ringingBackground: Color(0xFF060608),
      ringingForeground: Color(0xFFF6F5F8),
    );
  }

  /// Ringing palette — a fixed, deeper dark scheme regardless of app theme.
  factory AppTokens.ringing() {
    return const AppTokens(
      isDark: true,
      brand: Color(0xFFF2A65E),
      brandMuted: Color(0xFF2A1F16),
      onBrand: Color(0xFF1A1206),
      missionAccent: Color(0xFF5BC0AE),
      success: Color(0xFF57C98A),
      warning: Color(0xFFE6B95E),
      danger: Color(0xFFEB7A63),
      surface0: Color(0xFF060608),
      surface1: Color(0xFF0E0E12),
      surface2: Color(0xFF17171D),
      hairline: Color(0x14FFFFFF),
      textPrimary: Color(0xFFF7F6FA),
      textSecondary: Color(0xFFB6B4C0),
      textFaint: Color(0xFF75737E),
      ringingBackground: Color(0xFF060608),
      ringingForeground: Color(0xFFF7F6FA),
    );
  }

  // ---- ThemeExtension plumbing ----------------------------------------

  @override
  AppTokens copyWith({
    bool? isDark,
    Color? brand,
    Color? brandMuted,
    Color? onBrand,
    Color? missionAccent,
    Color? success,
    Color? warning,
    Color? danger,
    Color? surface0,
    Color? surface1,
    Color? surface2,
    Color? hairline,
    Color? textPrimary,
    Color? textSecondary,
    Color? textFaint,
    Color? ringingBackground,
    Color? ringingForeground,
  }) {
    return AppTokens(
      isDark: isDark ?? this.isDark,
      brand: brand ?? this.brand,
      brandMuted: brandMuted ?? this.brandMuted,
      onBrand: onBrand ?? this.onBrand,
      missionAccent: missionAccent ?? this.missionAccent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      surface0: surface0 ?? this.surface0,
      surface1: surface1 ?? this.surface1,
      surface2: surface2 ?? this.surface2,
      hairline: hairline ?? this.hairline,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textFaint: textFaint ?? this.textFaint,
      ringingBackground: ringingBackground ?? this.ringingBackground,
      ringingForeground: ringingForeground ?? this.ringingForeground,
    );
  }

  @override
  AppTokens lerp(covariant ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      isDark: t < 0.5 ? isDark : other.isDark,
      brand: Color.lerp(brand, other.brand, t)!,
      brandMuted: Color.lerp(brandMuted, other.brandMuted, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      missionAccent: Color.lerp(missionAccent, other.missionAccent, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      surface0: Color.lerp(surface0, other.surface0, t)!,
      surface1: Color.lerp(surface1, other.surface1, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textFaint: Color.lerp(textFaint, other.textFaint, t)!,
      ringingBackground: Color.lerp(ringingBackground, other.ringingBackground, t)!,
      ringingForeground: Color.lerp(ringingForeground, other.ringingForeground, t)!,
    );
  }
}

/// Ergonomic access: `context.tokens.brand`, `context.tokens.surface1`, …
extension AppTokensX on BuildContext {
  AppTokens get tokens =>
      Theme.of(this).extension<AppTokens>() ?? AppTokens.light();
}
