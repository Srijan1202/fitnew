import 'package:flutter/widgets.dart';

/// Design tokens from spec §6.2.
///
/// These are the whole palette. There are exactly three semantic colours
/// ([pine], [amber], [oxide]) and adding a fourth requires a recorded decision.
/// Colour carries meaning only — primary actions are solid [ink] blocks, never
/// coloured, so colour never competes with semantics.
///
/// Phase 19 (ADR-027): the values come from the active [FitPalette]. Paper
/// is the default and every free user's; the premium themes swap the whole
/// palette at once, so every screen keeps its meaning.
abstract final class FitColors {
  /// Canvas. Bone, not cream.
  static Color get paper => FitPalette.current.paper;

  /// Recessed surfaces.
  static Color get paper2 => FitPalette.current.paper2;

  /// Primary type and primary buttons.
  static Color get ink => FitPalette.current.ink;

  /// Secondary type.
  static Color get ink60 => FitPalette.current.ink60;

  /// Tertiary and disabled type.
  static Color get ink35 => FitPalette.current.ink35;

  /// Hairlines. Sections are separated by these, not by card margins (§6.4).
  static Color get rule => FitPalette.current.rule;

  /// On track / complete / logged.
  static Color get pine => FitPalette.current.pine;

  /// Attention / approaching limit / estimated.
  static Color get amber => FitPalette.current.amber;

  /// Fatigue / missed / destructive.
  static Color get oxide => FitPalette.current.oxide;
}

/// Phase 19 (ADR-027): one complete set of the nine tokens.
class FitPalette {
  const FitPalette({
    required this.id,
    required this.label,
    required this.brightness,
    required this.paper,
    required this.paper2,
    required this.ink,
    required this.ink60,
    required this.ink35,
    required this.rule,
    required this.pine,
    required this.amber,
    required this.oxide,
    this.premium = true,
  });

  final String id;
  final String label;
  final Brightness brightness;
  final Color paper;
  final Color paper2;
  final Color ink;
  final Color ink60;
  final Color ink35;
  final Color rule;
  final Color pine;
  final Color amber;
  final Color oxide;
  final bool premium;

  /// The palette every screen reads now. Set by the theme controller before
  /// the app rebuilds; Paper unless a premium user chose another.
  static FitPalette current = paperPalette;

  /// The §6.2 original: light, paper and ink.
  static const paperPalette = FitPalette(
    id: 'paper',
    label: 'Paper',
    brightness: Brightness.light,
    paper: Color(0xFFEDEBE4),
    paper2: Color(0xFFE4E1D8),
    ink: Color(0xFF17171A),
    ink60: Color(0xFF5E5D58),
    ink35: Color(0xFF95938C),
    rule: Color(0xFFC9C6BB),
    pine: Color(0xFF1E6B47),
    amber: Color(0xFFA8641B),
    oxide: Color(0xFF9E2B21),
    premium: false,
  );

  /// Premium: ink becomes the canvas; the meanings keep their hues, lifted.
  static const night = FitPalette(
    id: 'night',
    label: 'Night',
    brightness: Brightness.dark,
    paper: Color(0xFF16171B),
    paper2: Color(0xFF202127),
    ink: Color(0xFFECEAE3),
    ink60: Color(0xFFA9A7A0),
    ink35: Color(0xFF6E6D68),
    rule: Color(0xFF34353C),
    pine: Color(0xFF4DB383),
    amber: Color(0xFFE09A4A),
    oxide: Color(0xFFE2675A),
  );

  /// Premium: a green-tinted paper.
  static const forest = FitPalette(
    id: 'forest',
    label: 'Forest',
    brightness: Brightness.light,
    paper: Color(0xFFE6ECE4),
    paper2: Color(0xFFDAE3D7),
    ink: Color(0xFF14201A),
    ink60: Color(0xFF52625A),
    ink35: Color(0xFF8B988F),
    rule: Color(0xFFBFCABF),
    pine: Color(0xFF1B6A45),
    amber: Color(0xFF9A5E1B),
    oxide: Color(0xFF9E2B21),
  );

  /// Premium: a cool blue-grey paper.
  static const ocean = FitPalette(
    id: 'ocean',
    label: 'Ocean',
    brightness: Brightness.light,
    paper: Color(0xFFE5EAEE),
    paper2: Color(0xFFD9E0E6),
    ink: Color(0xFF121A22),
    ink60: Color(0xFF4F5D69),
    ink35: Color(0xFF8A96A0),
    rule: Color(0xFFBCC6CF),
    pine: Color(0xFF1E6B57),
    amber: Color(0xFFA0621E),
    oxide: Color(0xFF9C2E28),
  );

  static const all = <FitPalette>[paperPalette, night, forest, ocean];

  static FitPalette byId(String? id) =>
      all.firstWhere((p) => p.id == id, orElse: () => paperPalette);
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
