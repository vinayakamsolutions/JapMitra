import 'package:flutter/material.dart';

class AppTheme {
  static const saffron = Color(0xFFE87822);
  static const cream = Color(0xFFFFF8ED);
  static const brown = Color(0xFF3E2415);
  static const gold = Color(0xFFD8A94A);

  static ThemeData light() => _base(ColorScheme.fromSeed(
        seedColor: saffron,
        primary: saffron,
        secondary: gold,
        surface: cream,
        onSurface: brown,
        brightness: Brightness.light,
      ));

  static ThemeData dark() => _base(ColorScheme.fromSeed(
        seedColor: saffron,
        primary: const Color(0xFFFFA94D),
        secondary: const Color(0xFFE3B95B),
        surface: const Color(0xFF241510),
        onSurface: const Color(0xFFF3E7D2),
        brightness: Brightness.dark,
      ));

  static ThemeData _base(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      fontFamily: 'Noto Sans Devanagari',
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? const Color(0xFF33231A) : Colors.white,
        margin: const EdgeInsets.all(10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF2A1A12) : Colors.white,
        indicatorColor: gold.withValues(alpha: 0.35),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            backgroundColor: saffron, foregroundColor: Colors.white),
      ),
      dividerTheme:
          DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.5)),
    );
  }

  static ThemeMode mode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
