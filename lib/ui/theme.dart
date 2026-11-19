import 'package:flutter/material.dart';

/// Renk paleti: koyu zümrüt yeşili, açık sıcak krem, yumuşak altın.
class Palette {
  static const emerald = Color(0xFF0E4D3A);
  static const emeraldDeep = Color(0xFF093527);
  static const emeraldSoft = Color(0xFF6CC3A0);
  static const cream = Color(0xFFFBF3E1);
  static const creamLight = Color(0xFFFFFAEF);
  static const gold = Color(0xFFE9B949);
  static const goldDeep = Color(0xFF8A6410);
  static const ink = Color(0xFF13241D);

  // Koyu mod
  static const nightBg = Color(0xFF07170F);
  static const nightSurface = Color(0xFF10291F);
  static const nightCard = Color(0xFF173A2C);
  static const nightText = Color(0xFFF6EDD6);
}

TextTheme _text(Color c) => TextTheme(
      displaySmall: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: c, height: 1.1),
      headlineLarge: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: c, height: 1.15),
      headlineMedium: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: c),
      headlineSmall: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: c),
      titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: c),
      titleMedium: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: c),
      titleSmall: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: c),
      bodyLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: c, height: 1.35),
      bodyMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: c, height: 1.35),
      bodySmall: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: c),
      labelLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c),
      labelMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c),
      labelSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c),
    );

ThemeData _base(ColorScheme cs, Color text, Color scaffold) {
  final t = _text(text);
  // Koyu modda vurgu rengi altın (zümrüt koyu zeminde okunmaz).
  final accent = cs.brightness == Brightness.dark ? cs.secondary : cs.primary;
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: scaffold,
    textTheme: t,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    appBarTheme: AppBarTheme(
      backgroundColor: cs.primary,
      foregroundColor: cs.onPrimary,
      centerTitle: true,
      toolbarHeight: 68,
      titleTextStyle: t.headlineSmall!.copyWith(color: cs.onPrimary),
      iconTheme: IconThemeData(color: cs.onPrimary, size: 30),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 68),
        textStyle: t.titleMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 60),
        textStyle: t.titleSmall,
        foregroundColor: accent,
        side: BorderSide(color: accent, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    listTileTheme: ListTileThemeData(
      minVerticalPadding: 14,
      titleTextStyle: t.titleSmall,
      subtitleTextStyle: t.bodySmall!.copyWith(color: text.withValues(alpha: .78)),
      iconColor: accent,
    ),
    switchTheme: const SwitchThemeData(
      materialTapTargetSize: MaterialTapTargetSize.padded,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accent,
        minimumSize: const Size(56, 56),
        textStyle: t.titleSmall,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 82,
      labelTextStyle: WidgetStatePropertyAll(t.labelMedium),
      iconTheme: const WidgetStatePropertyAll(IconThemeData(size: 32)),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    dividerTheme: DividerThemeData(color: text.withValues(alpha: .15), thickness: 1),
  );
}

final ThemeData lightTheme = _base(
  const ColorScheme(
    brightness: Brightness.light,
    primary: Palette.emerald,
    onPrimary: Palette.cream,
    secondary: Palette.gold,
    onSecondary: Palette.ink,
    tertiary: Palette.goldDeep,
    onTertiary: Colors.white,
    error: Color(0xFFB3261E),
    onError: Colors.white,
    surface: Palette.creamLight,
    onSurface: Palette.ink,
    surfaceContainerHighest: Color(0xFFF1E5C8),
    surfaceContainerHigh: Color(0xFFF5EBD3),
    surfaceContainer: Palette.cream,
    primaryContainer: Color(0xFFD5EADF),
    onPrimaryContainer: Palette.emeraldDeep,
    secondaryContainer: Color(0xFFFBE7B0),
    onSecondaryContainer: Palette.ink,
  ),
  Palette.ink,
  Palette.cream,
);

final ThemeData darkTheme = _base(
  const ColorScheme(
    brightness: Brightness.dark,
    primary: Palette.emerald,
    onPrimary: Palette.nightText,
    secondary: Palette.gold,
    onSecondary: Palette.ink,
    tertiary: Palette.gold,
    onTertiary: Palette.ink,
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    surface: Palette.nightSurface,
    onSurface: Palette.nightText,
    surfaceContainerHighest: Color(0xFF214A39),
    surfaceContainerHigh: Palette.nightCard,
    surfaceContainer: Palette.nightSurface,
    primaryContainer: Color(0xFF1E5A44),
    onPrimaryContainer: Palette.nightText,
    secondaryContainer: Color(0xFF5A4512),
    onSecondaryContainer: Palette.nightText,
  ),
  Palette.nightText,
  Palette.nightBg,
);
