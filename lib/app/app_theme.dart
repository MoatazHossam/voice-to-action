import 'package:flutter/material.dart';

/// Design reference: "AI Voice to Text" (Figma). The screenshot was not
/// available in this environment, so this theme approximates the described
/// states (idle / active / progress / result) with a calm, single-accent
/// Material 3 palette rather than a pixel-accurate port. Replace the seed
/// color and text styles here once the real Figma file/screenshot is
/// accessible; nothing in modules/ai_intake depends on these exact values.
abstract final class AppTheme {
  static const Color _seed = Color(0xFF2F6F5E);
  static const Color recordingRed = Color(0xFFD64545);
  static const Color successGreen = Color(0xFF2E9E5B);
  static const Color warningAmber = Color(0xFFB8860B);

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(seedColor: _seed);
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
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
