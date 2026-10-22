import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tokens.dart';

/// Phase 19 (ADR-027, ADR-028): the chosen palette, kept on this phone (a
/// trivial flag, §7.1). FITOS Dark by default; FITOS Light and Paper for
/// everyone; the others are premium — the app falls back to the brand theme
/// of the same brightness as soon as it knows the user is not premium.
const kThemePreference = 'theme_id';

/// Read once by main() before the first frame, so the app opens in its theme.
Future<void> loadSavedPalette() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    FitPalette.current = FitPalette.byId(prefs.getString(kThemePreference));
  } on Object {
    FitPalette.current = FitPalette.fitosDark;
  }
}

class ThemeController extends Notifier<FitPalette> {
  @override
  FitPalette build() => FitPalette.current;

  Future<void> choose(FitPalette palette) async {
    FitPalette.current = palette;
    state = palette;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kThemePreference, palette.id);
    } on Object {
      // The choice still applies for this run.
    }
  }
}

final themeControllerProvider =
    NotifierProvider<ThemeController, FitPalette>(ThemeController.new);

/// Every widget reads the tokens when it builds; after a palette change the
/// whole tree rebuilds in place (no screen is lost, no state is reset).
void rebuildEverything(BuildContext context) {
  void mark(Element e) {
    e.markNeedsBuild();
    e.visitChildren(mark);
  }

  (context as Element).visitChildren(mark);
}
