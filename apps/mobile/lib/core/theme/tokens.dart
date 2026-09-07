import 'package:flutter/widgets.dart';

/// Design tokens from spec §6.2.
///
/// These are the whole palette. There are exactly three semantic colours
/// ([pine], [amber], [oxide]) and adding a fourth requires a recorded decision.
/// Colour carries meaning only — primary actions are solid [ink] blocks, never
/// coloured, so colour never competes with semantics.
abstract final class FitColors {
  /// Canvas. Bone, not cream.
  static const Color paper = Color(0xFFEDEBE4);

  /// Recessed surfaces.
  static const Color paper2 = Color(0xFFE4E1D8);

  /// Primary type and primary buttons.
  static const Color ink = Color(0xFF17171A);

  /// Secondary type.
  static const Color ink60 = Color(0xFF5E5D58);

  /// Tertiary and disabled type.
  static const Color ink35 = Color(0xFF95938C);

  /// Hairlines. Sections are separated by these, not by card margins (§6.4).
  static const Color rule = Color(0xFFC9C6BB);

  /// On track / complete / logged.
  static const Color pine = Color(0xFF1E6B47);

  /// Attention / approaching limit / estimated.
  static const Color amber = Color(0xFFA8641B);

  /// Fatigue / missed / destructive.
  static const Color oxide = Color(0xFF9E2B21);
}

/// 8px base grid (§6.4).
abstract final class FitSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  /// Screen padding.
  static const double screen = 18;

  /// Gap that follows a hairline section rule.
  static const double afterRule = 14;
}

/// Radius is 2px, 4px maximum, never more (§6.2).
abstract final class FitRadius {
  static const Radius small = Radius.circular(2);
  static const Radius medium = Radius.circular(4);
}
