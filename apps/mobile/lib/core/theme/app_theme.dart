import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

/// The single ThemeData for the app.
///
/// Light foundation is a recorded decision (§6.2): every major competitor is
/// dark, and paper reads as a training log rather than a telemetry dashboard.
/// There is deliberately no dark theme.
abstract final class FitTheme {
  static ThemeData build() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: FitColors.ink,
      onPrimary: FitColors.paper,
      secondary: FitColors.pine,
      onSecondary: FitColors.paper,
      error: FitColors.oxide,
      onError: FitColors.paper,
      surface: FitColors.paper,
      onSurface: FitColors.ink,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: FitColors.paper,
      textTheme: FitTypography.textTheme,
      dividerTheme: const DividerThemeData(
        color: FitColors.rule,
        thickness: 1,
        space: 1,
      ),
      // Primary actions are solid ink blocks, never coloured (§6.2).
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: FitColors.ink,
          foregroundColor: FitColors.paper,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(FitRadius.small),
          ),
          // 44×44 minimum tap target (§6.8).
          minimumSize: const Size(88, 48),
          textStyle: FitTypography.textTheme.titleMedium,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: FitColors.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
