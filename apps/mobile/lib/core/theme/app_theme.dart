import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';
import 'typography.dart';

/// The single ThemeData for the app, built from the active palette.
///
/// ADR-028 (brand kit): FITOS Dark is the default, FITOS Light its light
/// side; Paper (§6.2's original) stays as an option for everyone, and the
/// premium palettes (ADR-027) are built from the same tokens, so meaning
/// never changes with the colours.
abstract final class FitTheme {
  /// Status-bar and navigation-bar icons that read on the canvas.
  static SystemUiOverlayStyle get overlayStyle {
    final dark = FitPalette.current.brightness == Brightness.dark;
    return (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
        .copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: FitColors.paper,
      systemNavigationBarIconBrightness:
          dark ? Brightness.light : Brightness.dark,
    );
  }

  static ThemeData build() {
    final textTheme = FitTypography.textTheme;
    final colorScheme = ColorScheme(
      brightness: FitPalette.current.brightness,
      primary: FitColors.accent,
      onPrimary: FitColors.onAccent,
      secondary: FitColors.pine,
      onSecondary: FitColors.paper,
      error: FitColors.oxide,
      onError: FitColors.paper,
      surface: FitColors.paper,
      onSurface: FitColors.ink,
      onSurfaceVariant: FitColors.ink60,
      outline: FitColors.rule,
      outlineVariant: FitColors.rule,
      surfaceContainerLowest: FitColors.paper,
      surfaceContainerLow: FitColors.paper2,
      surfaceContainer: FitColors.paper2,
      surfaceContainerHigh: FitColors.paper2,
      surfaceContainerHighest: FitColors.paper2,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: FitTypography.family,
      scaffoldBackgroundColor: FitColors.paper,
      textTheme: textTheme,
      dividerTheme: DividerThemeData(
        color: FitColors.rule,
        thickness: 1,
        space: 1,
      ),
      // Primary actions are solid blocks in the accent: ink on Paper, lime
      // on FITOS Dark (ADR-028).
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: FitColors.accent,
          foregroundColor: FitColors.onAccent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(FitRadius.small),
          ),
          // 44×44 minimum tap target (§6.8).
          minimumSize: const Size(88, 48),
          textStyle: textTheme.titleMedium,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: FitColors.ink,
        selectionColor: FitColors.accent.withValues(alpha: 0.35),
        selectionHandleColor: FitColors.accent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: FitColors.paper,
        foregroundColor: FitColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: overlayStyle,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: FitColors.paper,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: FitColors.paper,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: FitColors.ink,
        contentTextStyle: textTheme.bodyLarge?.copyWith(color: FitColors.paper),
        actionTextColor: FitColors.paper,
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
