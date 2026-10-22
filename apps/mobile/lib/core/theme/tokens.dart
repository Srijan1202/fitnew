import 'package:flutter/widgets.dart';

/// Design tokens from spec §6.2.
///
/// There are exactly three semantic colours ([pine], [amber], [oxide]) and
/// adding a fourth requires a recorded decision.
///
/// Phase 19 (ADR-027): the values come from the active [FitPalette]; a theme
/// swaps the whole palette at once, so every screen keeps its meaning.
/// ADR-028 (brand kit): [accent] is the primary action — the lime of FITOS
/// Dark, ink everywhere else — so Paper's ink buttons are unchanged.
abstract final class FitColors {
  /// Canvas.
  static Color get paper => FitPalette.current.paper;

  /// Recessed surfaces.
  static Color get paper2 => FitPalette.current.paper2;

  /// Primary type.
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

  /// Primary buttons and the selected tab (ADR-028).
  static Color get accent => FitPalette.current.accent;

  /// Type and icons on [accent].
  static Color get onAccent => FitPalette.current.onAccent;
}

/// The brand kit's colours (brand/README.md), for the logo.
abstract final class FitBrand {
  static const Color limeHi = Color(0xFFE4FF52);
  static const Color lime = Color(0xFFC6F432);
  static const Color green = Color(0xFF5BC62A);
  static const Color carbon = Color(0xFF0A0D0B);
}

/// Phase 19 (ADR-027): one complete set of the tokens.
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
    Color? accent,
    Color? onAccent,
    this.brandMark = false,
    this.premium = true,
  })  : accent = accent ?? ink,
        onAccent = onAccent ?? paper;

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
  final Color accent;
  final Color onAccent;

  /// The logo's mark in the lime gradient (the brand themes), not in ink.
  final bool brandMark;
  final bool premium;

  /// The palette every screen reads now. Set by the theme controller before
  /// the app rebuilds; FITOS Dark unless the user chose another.
  static FitPalette current = fitosDark;

  /// ADR-028, the default: the brand kit's primary logo — carbon, white type,
  /// lime actions.
  static const fitosDark = FitPalette(
    id: 'fitos-dark',
    label: 'FITOS Dark',
    brightness: Brightness.dark,
    paper: Color(0xFF0A0D0B),
    paper2: Color(0xFF151A16),
    ink: Color(0xFFF3F5F1),
    ink60: Color(0xFFB4BCB5),
    ink35: Color(0xFF7D867F),
    rule: Color(0xFF262D27),
    pine: Color(0xFFC6F432),
    amber: Color(0xFFF5B342),
    oxide: Color(0xFFFF6B57),
    accent: Color(0xFFC6F432),
    onAccent: Color(0xFF0A0D0B),
    brandMark: true,
    premium: false,
  );

  /// ADR-028: the brand kit's light side — paper white, ink actions, green
  /// darkened enough to read as text.
  static const fitosLight = FitPalette(
    id: 'fitos-light',
    label: 'FITOS Light',
    brightness: Brightness.light,
    paper: Color(0xFFF5F6F3),
    paper2: Color(0xFFE8EBE5),
    ink: Color(0xFF0B0B0C),
    ink60: Color(0xFF4A504B),
    ink35: Color(0xFF858C86),
    rule: Color(0xFFD3D8D1),
    pine: Color(0xFF2F7A18),
    amber: Color(0xFFA8641B),
    oxide: Color(0xFFB3261E),
    brandMark: true,
    premium: false,
  );

  /// The §6.2 original: light, paper and ink. Optional since ADR-028.
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

  static const all = <FitPalette>[
    fitosDark,
    fitosLight,
    paperPalette,
    night,
    forest,
    ocean,
  ];

  /// Where a theme the user may no longer have falls back to: the brand
  /// theme of the same brightness.
  FitPalette get freeFallback =>
      brightness == Brightness.dark ? fitosDark : fitosLight;

  static FitPalette byId(String? id) =>
      all.firstWhere((p) => p.id == id, orElse: () => fitosDark);
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
