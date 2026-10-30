import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/widgets/fit_glass.dart';
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
      // The paper and the glow are the route's (FitCanvas, owner
      // 2026-10-30), drawn behind the bars too.
      scaffoldBackgroundColor: Colors.transparent,
      pageTransitionsTheme: PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          for (final e in const PageTransitionsTheme().builders.entries)
            e.key: FitPageTransitions(e.value),
        },
      ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(FitRadius.small),
          ),
          // 44×44 minimum tap target (§6.8).
          minimumSize: const Size(88, 48),
          textStyle: textTheme.titleMedium,
        ),
      ),
      // ADR-029: on glass, text fields are rounded and filled; on Paper the
      // Material default (each screen draws its own hairline).
      inputDecorationTheme: FitPalette.current.glass
          ? InputDecorationTheme(
              filled: true,
              fillColor: FitColors.ink.withValues(alpha: 0.06),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(FitRadius.small),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(FitRadius.small),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(FitRadius.small),
                borderSide: BorderSide(color: FitColors.accent, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(FitRadius.small),
                borderSide: BorderSide(color: FitColors.oxide),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(FitRadius.small),
                borderSide: BorderSide(color: FitColors.oxide, width: 1.5),
              ),
              hintStyle: textTheme.bodyLarge?.copyWith(color: FitColors.ink35),
              prefixIconColor: FitColors.ink60,
              suffixIconColor: FitColors.ink60,
            )
          : null,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: FitColors.ink,
        selectionColor: FitColors.accent.withValues(alpha: 0.35),
        selectionHandleColor: FitColors.accent,
      ),
      // See-through on the route's canvas, the title on the left, on every
      // pushed page alike (owner 2026-10-30).
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        centerTitle: false,
        foregroundColor: FitColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: overlayStyle,
      ),
      // ADR-029: on the glass palettes, controls are rounded the iPhone way;
      // Paper keeps its 2 px corners (FitRadius follows the palette).
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(FitRadius.small),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(FitRadius.small),
          ),
          selectedBackgroundColor: FitPalette.current.glass
              ? FitColors.accent
              : FitColors.ink.withValues(alpha: 0.12),
          selectedForegroundColor:
              FitPalette.current.glass ? FitColors.onAccent : FitColors.ink,
          // Beta 4.8: the options not chosen in plain ink, like every other
          // switch (Material drew them in the accent: 1W / 1M / 3M).
          foregroundColor: FitColors.ink,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: FitColors.paper,
        surfaceTintColor: Colors.transparent,
        shape: FitPalette.current.glass
            ? const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              )
            : null,
        // ADR-029: every sheet shows the iOS grab handle on glass.
        showDragHandle: FitPalette.current.glass ? true : null,
        dragHandleColor: FitColors.ink35,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: FitColors.paper,
        surfaceTintColor: Colors.transparent,
        shape: FitPalette.current.glass
            ? const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(28)),
              )
            : null,
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
