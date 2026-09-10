import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Raw brand palette. Prefer the semantic roles on `context.tokens`
/// ([AppTokens]) in feature code — these constants exist for the theme
/// wiring below and a few legacy call sites.
class AppColors {
  static const accent = Color(0xFFE58A4D);
  static const accentDark = Color(0xFFC85A1E);
  static const danger = Color(0xFFB5432F);
  static const teal = Color(0xFF2E7D6F);
}

/// Builds the three [ThemeData] variants the app uses: [light], [dark], and
/// the fixed-dark [ringing] theme. Each one carries a matching [AppTokens]
/// in its `extensions`, so `context.tokens` always resolves.
class AppTheme {
  static ThemeData light() => _build(
        brightness: Brightness.light,
        tokens: AppTokens.light(),
        seed: AppColors.accentDark,
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        tokens: AppTokens.dark(),
        seed: AppColors.accent,
      );

  /// The ringing screen intentionally ignores the light/dark toggle — it
  /// should always be high-contrast and impossible to misread half asleep.
  static ThemeData ringing() => _build(
        brightness: Brightness.dark,
        tokens: AppTokens.ringing(),
        seed: AppColors.accent,
      );

  static ThemeData _build({
    required Brightness brightness,
    required AppTokens tokens,
    required Color seed,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    ).copyWith(
      primary: tokens.brand,
      onPrimary: tokens.onBrand,
      surface: tokens.surface0,
      error: tokens.danger,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: tokens.surface0,
      splashFactory: InkSparkle.splashFactory,
      extensions: [tokens],
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme, tokens),
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.surface0,
        foregroundColor: tokens.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardTheme(
        color: tokens.surface1,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: AppTokens.cornerLg),
      ),
      dividerTheme: DividerThemeData(
        color: tokens.hairline,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: tokens.surface2,
        selectedColor: tokens.brand,
        side: BorderSide.none,
        showCheckmark: false,
        labelStyle: TextStyle(
          color: tokens.textSecondary,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: TextStyle(
          color: tokens.onBrand,
          fontWeight: FontWeight.w600,
        ),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space12,
          vertical: AppTokens.space8,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.brand,
          foregroundColor: tokens.onBrand,
          disabledBackgroundColor: tokens.surface2,
          disabledForegroundColor: tokens.textFaint,
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: const RoundedRectangleBorder(borderRadius: AppTokens.cornerMd),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.textPrimary,
          side: BorderSide(color: tokens.hairline),
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: const RoundedRectangleBorder(borderRadius: AppTokens.cornerMd),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tokens.textSecondary,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? tokens.onBrand : tokens.surface0,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? tokens.brand : tokens.surface2,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surface2,
        hintStyle: TextStyle(color: tokens.textFaint),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space16,
          vertical: AppTokens.space16,
        ),
        border: const OutlineInputBorder(
          borderRadius: AppTokens.cornerMd,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppTokens.cornerMd,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppTokens.cornerMd,
          borderSide: BorderSide(color: tokens.brand, width: 2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: tokens.surface2,
        contentTextStyle: TextStyle(color: tokens.textPrimary),
        shape: const RoundedRectangleBorder(borderRadius: AppTokens.cornerMd),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: EdgeInsets.zero,
        iconColor: tokens.textSecondary,
      ),
    );
  }

  /// Type scale. Inter carries everything except the display sizes, which
  /// switch to Space Grotesk — the clock and countdowns read as an
  /// instrument: tight tracking, tabular figures, no jitter.
  static const _display = 'Space Grotesk';

  static TextTheme _textTheme(TextTheme base, AppTokens t) {
    final scaled = base.apply(
      bodyColor: t.textPrimary,
      displayColor: t.textPrimary,
    );
    return scaled.copyWith(
      displayLarge: scaled.displayLarge?.copyWith(
        fontFamily: _display,
        fontWeight: FontWeight.w300,
        letterSpacing: -2.0,
        height: 1.0,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      displayMedium: scaled.displayMedium?.copyWith(
        fontFamily: _display,
        fontWeight: FontWeight.w400,
        letterSpacing: -1.4,
        height: 1.0,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      displaySmall: scaled.displaySmall?.copyWith(
        fontFamily: _display,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.6,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      headlineMedium: scaled.headlineMedium?.copyWith(
        fontFamily: _display,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.8,
      ),
      headlineSmall: scaled.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      titleLarge: scaled.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleMedium: scaled.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleSmall: scaled.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: t.textSecondary,
      ),
      bodyMedium: scaled.bodyMedium?.copyWith(color: t.textSecondary, height: 1.45),
      bodySmall: scaled.bodySmall?.copyWith(color: t.textFaint, height: 1.4),
      labelLarge: scaled.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      labelSmall: scaled.labelSmall?.copyWith(
        color: t.textFaint,
        letterSpacing: 1.4,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
