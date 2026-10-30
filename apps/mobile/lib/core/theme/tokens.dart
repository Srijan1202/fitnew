import 'package:flutter/widgets.dart';

/// Design tokens from spec §6.2.
///
/// There are four semantic colours ([pine], [amber], [oxide] and, since beta
/// 4.1.1, [sky]); adding another requires a recorded decision.
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

  /// Beta 4.1.1 (owner, 2026-10-29): too little, the cool side of a range
  /// whose warm side is [amber] and [oxide], so "very low" and "very high"
  /// never share a colour (weekly volume).
  static Color get sky => FitPalette.current.sky;

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
    required this.sky,
    Color? accent,
    Color? onAccent,
    Color? glow,
    this.brandMark = false,
    this.glass = true,
    this.premium = true,
    this.reward,
  })  : accent = accent ?? ink,
        onAccent = onAccent ?? paper,
        glow = glow ?? pine;

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
  final Color sky;
  final Color accent;
  final Color onAccent;

  /// The logo's mark in the lime gradient (the brand themes), not in ink.
  final bool brandMark;

  /// ADR-029: rounded, translucent blocks with a soft coloured shadow. Every
  /// palette but Paper, which keeps the flat §6 look exactly.
  final bool glass;

  /// The colour of the blocks' soft shadow and the background glow.
  final Color glow;
  final bool premium;

  /// Beta 3.4: a theme only a streak earns (its reward id), else null.
  /// Beta 4.2: or a running badge (its badge id: the Road theme).
  final String? reward;

  /// The palette every screen reads now. Set by the theme controller before
  /// the app rebuilds: Dark or Light with the phone's mode unless the user
  /// chose another (owner 2026-10-30).
  static FitPalette current = dark;

  /// True while no theme was chosen: Dark or Light follows the phone.
  static bool followsDevice = true;

  /// Owner 2026-10-30: the main themes, neutral — near-black with white
  /// actions, near-white with black actions. Each is the default in its
  /// mode; the meanings (good, warning, bad) keep their colours.
  static const dark = FitPalette(
    id: 'dark',
    label: 'Dark',
    brightness: Brightness.dark,
    paper: Color(0xFF0B0B0C),
    paper2: Color(0xFF17171A),
    ink: Color(0xFFF4F4F5),
    ink60: Color(0xFFA1A1AA),
    ink35: Color(0xFF71717A),
    rule: Color(0xFF27272A),
    pine: Color(0xFF4ADE80),
    amber: Color(0xFFF5B342),
    oxide: Color(0xFFFF6B57),
    sky: Color(0xFF5AB4F5),
    glow: Color(0xFF8A8A93),
    premium: false,
  );

  static const light = FitPalette(
    id: 'light',
    label: 'Light',
    brightness: Brightness.light,
    paper: Color(0xFFFAFAFA),
    paper2: Color(0xFFEEEEF0),
    ink: Color(0xFF111113),
    ink60: Color(0xFF52525B),
    ink35: Color(0xFF8A8A93),
    rule: Color(0xFFDDDDE1),
    pine: Color(0xFF1F8A4C),
    amber: Color(0xFFA8641B),
    oxide: Color(0xFFB3261E),
    sky: Color(0xFF1F6FB8),
    glow: Color(0xFFA1A1AA),
    premium: false,
  );

  /// Owner 2026-10-30, free: true black with cobalt blue actions.
  static const cobalt = FitPalette(
    id: 'cobalt',
    label: 'Cobalt',
    brightness: Brightness.dark,
    paper: Color(0xFF000000),
    paper2: Color(0xFF0E1116),
    ink: Color(0xFFF2F5FA),
    ink60: Color(0xFFA9B3C1),
    ink35: Color(0xFF6B7685),
    rule: Color(0xFF1E2530),
    pine: Color(0xFF4ADE80),
    amber: Color(0xFFF5B342),
    oxide: Color(0xFFFF6B57),
    sky: Color(0xFF7DB7FF),
    accent: Color(0xFF2E6BF0),
    onAccent: Color(0xFFFFFFFF),
    glow: Color(0xFF2E6BF0),
    premium: false,
  );

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
    sky: Color(0xFF5AB4F5),
    accent: Color(0xFFC6F432),
    onAccent: Color(0xFF0A0D0B),
    glow: Color(0xFFC6F432),
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
    sky: Color(0xFF1F6FB8),
    glow: Color(0xFF5BC62A),
    brandMark: true,
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
    sky: Color(0xFF5AB4F5),
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
    sky: Color(0xFF1F6FB8),
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
    sky: Color(0xFF1F6FB8),
    glow: Color(0xFF2E7DB5),
  );

  /// Beta 3.4: earned with a 14-day streak (not premium): carbon warmed
  /// through, with ember-orange actions.
  static const ember = FitPalette(
    id: 'ember',
    label: 'Ember',
    brightness: Brightness.dark,
    paper: Color(0xFF120C0A),
    paper2: Color(0xFF1E1511),
    ink: Color(0xFFF6EFEA),
    ink60: Color(0xFFC4B4AA),
    ink35: Color(0xFF8C7C72),
    rule: Color(0xFF35271F),
    pine: Color(0xFF8FD16A),
    amber: Color(0xFFF5B342),
    oxide: Color(0xFFFF6B57),
    sky: Color(0xFF5AB4F5),
    accent: Color(0xFFFF7A2F),
    onAccent: Color(0xFF120C0A),
    glow: Color(0xFFFF7A2F),
    premium: false,
    reward: 'ember-theme',
  );

  /// Beta 4.2: earned with a first half marathon (not premium): asphalt,
  /// with steel-blue actions. Its sky is lighter than the actions, so a
  /// "too little" volume never reads as a button.
  static const road = FitPalette(
    id: 'road',
    label: 'Road',
    brightness: Brightness.dark,
    paper: Color(0xFF0D1116),
    paper2: Color(0xFF161C24),
    ink: Color(0xFFEEF2F6),
    ink60: Color(0xFFAAB4BF),
    ink35: Color(0xFF75808C),
    rule: Color(0xFF26303B),
    pine: Color(0xFF7BD389),
    amber: Color(0xFFF5B342),
    oxide: Color(0xFFFF6B57),
    sky: Color(0xFF8AD4F8),
    accent: Color(0xFF6FA8DC),
    onAccent: Color(0xFF0D1116),
    glow: Color(0xFF6FA8DC),
    premium: false,
    reward: 'first-half',
  );

  /// Beta 4.5: earned with 1,000 km run in total (not premium): a dark
  /// night road, deep orange actions.
  static const mileage = FitPalette(
    id: 'mileage',
    label: 'Mileage',
    brightness: Brightness.dark,
    paper: Color(0xFF110D0A),
    paper2: Color(0xFF1C1612),
    ink: Color(0xFFF7F0EA),
    ink60: Color(0xFFC2B3A6),
    ink35: Color(0xFF8A7B6F),
    rule: Color(0xFF332820),
    pine: Color(0xFF8FD16A),
    amber: Color(0xFFF5B342),
    oxide: Color(0xFFFF6B57),
    sky: Color(0xFF8AD4F8),
    accent: Color(0xFFFF8A1F),
    onAccent: Color(0xFF110D0A),
    glow: Color(0xFFFF8A1F),
    premium: false,
    reward: 'total-1000k',
  );

  static const all = <FitPalette>[
    dark,
    light,
    cobalt,
    fitosDark,
    fitosLight,
    night,
    forest,
    ocean,
    ember,
    road,
    mileage,
  ];

  /// The main theme for a mode: Dark or Light.
  static FitPalette forMode(Brightness mode) =>
      mode == Brightness.dark ? dark : light;

  /// A theme by id; an unknown one (Paper, dropped on 2026-10-30) is null.
  static FitPalette? byId(String? id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }
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

/// Radius was 2px, 4px maximum (§6.2). ADR-029: the glass palettes round
/// controls and blocks the iPhone way; Paper keeps 2 and 4.
abstract final class FitRadius {
  /// Controls: buttons, inputs, chips, small panels.
  static Radius get small => Radius.circular(FitPalette.current.glass ? 14 : 2);

  /// Bars and larger panels.
  static Radius get medium =>
      Radius.circular(FitPalette.current.glass ? 20 : 4);

  /// Blocks (ADR-029); unused on Paper, where blocks are flat.
  static const Radius block = Radius.circular(22);
}
