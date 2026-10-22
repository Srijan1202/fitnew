import 'package:flutter/material.dart';

import 'tokens.dart';

/// Type scale from spec §6.3.
///
/// Hierarchy comes from type scale and whitespace, not from boxes. Numbers are
/// the hero: [metricLarge] and friends are for numerals only.
///
/// ADR-028 (brand kit): one family, Barlow (bundled, SIL OFL) — the free
/// equivalent of the kit's Bahnschrift. Metrics are Barlow SemiBold.
abstract final class FitTypography {
  static const String family = 'Barlow';

  /// Built on every read: the colours come from the active palette, so a
  /// theme change repaints the type too (a cached copy kept the first
  /// palette's ink — dark text on Night).
  static TextTheme get textTheme => TextTheme(
        // Metrics — large numbers only, 26–88px.
        displayLarge: TextStyle(
          fontFamily: family,
          fontSize: 88,
          fontWeight: FontWeight.w600,
          height: 0.95,
          letterSpacing: -1.5,
          color: FitColors.ink,
        ),
        displayMedium: TextStyle(
          fontFamily: family,
          fontSize: 56,
          fontWeight: FontWeight.w600,
          height: 1,
          letterSpacing: -0.8,
          color: FitColors.ink,
        ),
        displaySmall: TextStyle(
          fontFamily: family,
          fontSize: 26,
          fontWeight: FontWeight.w600,
          height: 1.05,
          color: FitColors.ink,
        ),

        // Everything else — 11–19px, weights 400/500/600/700.
        titleLarge: TextStyle(
          fontFamily: family,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          height: 1.3,
          color: FitColors.ink,
        ),
        titleMedium: TextStyle(
          fontFamily: family,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.35,
          color: FitColors.ink,
        ),
        bodyLarge: TextStyle(
          fontFamily: family,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: FitColors.ink,
        ),
        bodyMedium: TextStyle(
          fontFamily: family,
          fontSize: 13,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: FitColors.ink60,
        ),

        /// Eyebrow / label. Uppercase, tracked out.
        labelSmall: TextStyle(
          fontFamily: family,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.3,
          color: FitColors.ink35,
        ),
      );
}
