import 'package:flutter/material.dart';

/// Palette echoes the plan document: warm amber-orange accent on a near-black
/// (dark) or warm-cream (light) ground, not a stock Material purple/blue.
class AppColors {
  static const accent = Color(0xFFE58A4D);
  static const accentDark = Color(0xFFC85A1E);
  static const danger = Color(0xFFB5432F);
  static const teal = Color(0xFF2E7D6F);
}

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accentDark,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF7F5F0),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF7F5F0),
        foregroundColor: Color(0xFF211D17),
        elevation: 0,
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF15130F),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF15130F),
        foregroundColor: Color(0xFFF2EDE3),
        elevation: 0,
      ),
    );
  }

  /// Ringing screen intentionally ignores the light/dark toggle — it should
  /// always be high-contrast and impossible to misread half-asleep.
  static ThemeData ringing() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF0D0B08),
    );
  }
}
