import 'package:flutter/material.dart';

import 'tokens.dart';

/// Type scale from spec §6.3.
///
/// Hierarchy comes from type scale and whitespace, not from boxes. Numbers are
/// the hero: [metricLarge] and friends are for numerals only.
///
/// The font families are declared here but the binaries are not yet bundled in
/// pubspec.yaml, so at Phase 0 these resolve to the platform sans-serif.
abstract final class FitTypography {
  static const String metricFamily = 'Anton';
  static const String bodyFamily = 'Archivo';

  static const TextTheme textTheme = TextTheme(
    // Metrics — Anton, large numbers only, 26–88px.
    displayLarge: TextStyle(
      fontFamily: metricFamily,
      fontSize: 88,
      height: 0.95,
      letterSpacing: -1.5,
      color: FitColors.ink,
    ),
    displayMedium: TextStyle(
      fontFamily: metricFamily,
      fontSize: 56,
      height: 1,
      letterSpacing: -0.8,
      color: FitColors.ink,
    ),
    displaySmall: TextStyle(
      fontFamily: metricFamily,
      fontSize: 26,
      height: 1.05,
      color: FitColors.ink,
    ),

    // Everything else — Archivo, 11–19px, weights 400/600/700.
    titleLarge: TextStyle(
      fontFamily: bodyFamily,
      fontSize: 19,
      fontWeight: FontWeight.w700,
      height: 1.3,
      color: FitColors.ink,
    ),
    titleMedium: TextStyle(
      fontFamily: bodyFamily,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.35,
      color: FitColors.ink,
    ),
    bodyLarge: TextStyle(
      fontFamily: bodyFamily,
      fontSize: 15,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: FitColors.ink,
    ),
    bodyMedium: TextStyle(
      fontFamily: bodyFamily,
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: FitColors.ink60,
    ),

    /// Eyebrow / label. Uppercase, tracked out.
    labelSmall: TextStyle(
      fontFamily: bodyFamily,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.3,
      color: FitColors.ink35,
    ),
  );
}
