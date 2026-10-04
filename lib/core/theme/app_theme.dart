import 'package:flutter/material.dart';

class AppTheme {
  static const saffron = Color(0xFFD95D1E);
  static const saffronDeep = Color(0xFFC44D00);
  static const cream = Color(0xFFFAF6EE);
  static const creamDark = Color(0xFFF0D5C3);
  static const brown = Color(0xFF2E1F14);
  static const brownSoft = Color(0xFF5C4535);
  static const gold = Color(0xFFC59B3F);
  static const goldSoft = Color(0xFFF3E5C0);
  static const white = Color(0xFFFFFDFA);

  static const warmShadowBrown = Color(0x125C4535);
  static const warmShadowEspresso = Color(0x0A2E1F14);
  static const warmShadowGold = Color(0x1FC59B3F);
  static const warmShadowSaffron = Color(0x14D95D1E);

  /// The one radius every premium surface shares, so Home, Rashifal and More
  /// read as a single system rather than three hand-rolled corners. It matches
  /// [cardTheme] so a plain `Card` and an explicit surface look identical.
  static const radius = 24.0;
  static const cardRadius = BorderRadius.all(Radius.circular(radius));

  /// Three elevation tiers. Pure neutral black shadows are forbidden, so every
  /// tier pairs a soft warm brown/umber diffusion with a gold hairline glow.
  static const shadowLow = <BoxShadow>[
    BoxShadow(color: warmShadowEspresso, blurRadius: 8, offset: Offset(0, 2)),
    BoxShadow(color: warmShadowGold, blurRadius: 3, offset: Offset(0, 1)),
  ];

  /// The default resting shadow for cards and grouped surfaces.
  static const shadow = <BoxShadow>[
    BoxShadow(color: warmShadowBrown, blurRadius: 24, offset: Offset(0, 8)),
    BoxShadow(color: warmShadowGold, blurRadius: 6, offset: Offset(0, 2)),
  ];

  /// Interactive elevation: reserved for pressed or focused primary surfaces.
  static const shadowElevated = <BoxShadow>[
    BoxShadow(color: Color(0x1A5C4535), blurRadius: 36, offset: Offset(0, 14)),
    BoxShadow(color: warmShadowSaffron, blurRadius: 12, offset: Offset(0, 4)),
  ];

  /// A hairline in antique gold, used to separate a cream surface from cream.
  static BorderSide hairline([double alpha = 0.22]) =>
      BorderSide(color: gold.withValues(alpha: alpha));

  static const _serif = 'serif';

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
        surface: const Color(0xFF1A1208),
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
        color: isDark ? const Color(0xFF2A1F14) : white,
        margin: const EdgeInsets.all(10),
        shape: RoundedRectangleBorder(
          borderRadius: cardRadius,
          side: BorderSide(
            color:
                isDark ? const Color(0xFF3A2A1A) : gold.withValues(alpha: 0.22),
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: saffron.withValues(alpha: 0.15),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: saffron,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: saffron,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const StadiumBorder(),
          side: BorderSide(color: saffron.withValues(alpha: 0.5)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.3),
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? const Color(0xFF3A2A1A) : goldSoft,
        labelStyle: TextStyle(
          color: isDark ? const Color(0xFFF3E7D2) : brownSoft,
          fontWeight: FontWeight.w500,
        ),
        shape: const StadiumBorder(),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF3A2A1A) : brown,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: const StadiumBorder(),
      ),
    );
  }

  static TextStyle serif(BuildContext context, {required TextStyle base}) {
    return base.copyWith(fontFamily: _serif);
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
