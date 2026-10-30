import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tokens.dart';

/// Phase 19 (ADR-027, ADR-028), owner 2026-10-30: the chosen palette, kept
/// on this phone (a trivial flag, §7.1). With none chosen, Dark or Light
/// follows the phone's mode (Automatic). Cobalt and the green FITOS themes
/// are for everyone; the others are premium or rewards — losing one goes
/// back to Automatic.
const kThemePreference = 'theme.v2';

/// Before 2026-10-30. Read never again: everyone moved to the main themes
/// once (owner), so it is only removed.
const kOldThemePreference = 'theme_id';

/// The phone's mode now (main() starts the binding before reading it).
Brightness get deviceMode =>
    WidgetsBinding.instance.platformDispatcher.platformBrightness;

/// Read once by main() before the first frame, so the app opens in its theme.
Future<void> loadSavedPalette() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kOldThemePreference);
    final chosen = FitPalette.byId(prefs.getString(kThemePreference));
    FitPalette.followsDevice = chosen == null;
    FitPalette.current = chosen ?? FitPalette.forMode(deviceMode);
  } on Object {
    FitPalette.followsDevice = true;
    FitPalette.current = FitPalette.forMode(deviceMode);
  }
}

class ThemeController extends Notifier<FitPalette> with WidgetsBindingObserver {
  @override
  FitPalette build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() => WidgetsBinding.instance.removeObserver(this));
    return FitPalette.current;
  }

  /// The phone switched between dark and light: Automatic follows it.
  @override
  void didChangePlatformBrightness() {
    if (!FitPalette.followsDevice) return;
    final p = FitPalette.forMode(deviceMode);
    if (p.id == state.id) return;
    FitPalette.current = p;
    state = p;
  }

  Future<void> choose(FitPalette palette) async {
    FitPalette.followsDevice = false;
    FitPalette.current = palette;
    state = palette;
    ref.read(themeFollowsDeviceProvider.notifier).set(false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kThemePreference, palette.id);
    } on Object {
      // The choice still applies for this run.
    }
  }

  /// Automatic: Dark or Light with the phone's mode.
  Future<void> followDevice() async {
    FitPalette.followsDevice = true;
    final p = FitPalette.forMode(deviceMode);
    FitPalette.current = p;
    state = p;
    ref.read(themeFollowsDeviceProvider.notifier).set(true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kThemePreference);
    } on Object {
      // Automatic still applies for this run.
    }
  }
}

final themeControllerProvider =
    NotifierProvider<ThemeController, FitPalette>(ThemeController.new);

/// Whether Automatic is on (the picker marks it).
class ThemeFollowsDevice extends Notifier<bool> {
  @override
  bool build() => FitPalette.followsDevice;

  void set(bool on) => state = on;
}

final themeFollowsDeviceProvider =
    NotifierProvider<ThemeFollowsDevice, bool>(ThemeFollowsDevice.new);

/// Every widget reads the tokens when it builds; after a palette change the
/// whole tree rebuilds in place (no screen is lost, no state is reset).
void rebuildEverything(BuildContext context) {
  void mark(Element e) {
    e.markNeedsBuild();
    e.visitChildren(mark);
  }

  (context as Element).visitChildren(mark);
}
