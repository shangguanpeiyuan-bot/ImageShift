import 'package:flutter/material.dart';

abstract final class ShiftTheme {
  static const ink = Color(0xff173a3a);
  static const teal = Color(0xff087f73);
  static const canvas = Color(0xfff5f7f6);
  static const amber = Color(0xffb87916);

  static ThemeData build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: teal,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? const Color(0xff121c1d) : canvas,
      fontFamily: 'Microsoft YaHei',
      fontFamilyFallback: const ['Noto Sans CJK SC', 'sans-serif'],
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.w700,
          height: 1.35,
          letterSpacing: -1,
        ),
        headlineMedium: TextStyle(
          fontSize: 27,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
        titleLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(fontSize: 13, height: 1.6),
        bodySmall: TextStyle(fontSize: 12, height: 1.5),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .55)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: dark ? scheme.surfaceContainerLow : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: .65),
        thickness: 1,
      ),
      navigationBarTheme: const NavigationBarThemeData(height: 72),
      tooltipTheme: const TooltipThemeData(
        waitDuration: Duration(milliseconds: 400),
      ),
    );
  }
}

String formatBytes(int value) {
  if (value.abs() < 1024) return '$value B';
  if (value.abs() < 1024 * 1024) {
    return '${(value / 1024).toStringAsFixed(1)} KB';
  }
  return '${(value / (1024 * 1024)).toStringAsFixed(2)} MB';
}

String sizeChange(int before, int after) {
  if (before == 0) return '—';
  final change = (after - before) / before * 100;
  if (change.abs() < .05) return '大小基本不变';
  return '${change > 0 ? '增加' : '减少'} ${change.abs().toStringAsFixed(1)}%';
}
