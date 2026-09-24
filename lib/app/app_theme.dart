import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const Color _seed = Color(0xFF0878D7);
  static const Color recordingRed = Color(0xFFD64545);
  static const Color successGreen = Color(0xFF2E9E5B);
  static const Color warningAmber = Color(0xFFB8860B);

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(seedColor: _seed);
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF7F9FE),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      chipTheme: ChipThemeData(
        selectedColor: colorScheme.primaryContainer,
        backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        labelStyle: TextStyle(color: colorScheme.onSurface),
        shape: StadiumBorder(side: BorderSide(color: colorScheme.outlineVariant)),
      ),
      dividerTheme: DividerThemeData(color: colorScheme.outlineVariant, space: 32),
    );
  }
}

/// Semantic status colors used across ai_intake widgets to keep the honesty
/// labeling (real / stub / unsupported / experimental) visually consistent.
abstract final class AppStatusColors {
  static const Color realFeature = Color(0xFF2E9E5B);
  static const Color stubFeature = Color(0xFFB8860B);
  static const Color unsupportedFeature = Color(0xFF9AA0A6);
}
