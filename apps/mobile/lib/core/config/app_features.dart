import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_config.dart';

/// Beta 3.3 (ADR-033): the features the admin panel switches on and off,
/// the same list as `APP_FEATURES` in packages/contracts (a test checks).
/// Off hides the feature's entry points; the server refuses it too.
enum AppFeature {
  shareProgramme('share-programme'),
  messRatings('mess-ratings'),
  streaks('streaks'),
  communityFoods('community-foods'),
  foodRequests('food-requests'),
  weeklyReport('weekly-report'),
  progressPhotos('progress-photos'),
  // Beta 3.6 (F15): "What should I eat?" from FITOS AI.
  foodGuide('food-guide');

  const AppFeature(this.key);

  final String key;
}

/// On unless the server says off; unknown (offline, still loading) is on.
final featureOnProvider = Provider.family<bool, AppFeature>(
  (ref, feature) =>
      ref.watch(appConfigProvider).value?.flags[feature.key] ?? true,
);

/// How often coming back to the app re-reads `/meta/config`.
const kConfigRefreshInterval = Duration(minutes: 5);

/// Re-reads the config when the app returns to the foreground, at most every
/// [kConfigRefreshInterval], so a switch reaches phones within minutes.
class ConfigRefreshCoordinator {
  ConfigRefreshCoordinator(this._refresh, {DateTime Function()? now})
      : _now = now ?? DateTime.now {
    _last = _now();
    _lifecycle = AppLifecycleListener(onResume: resumed);
  }

  final VoidCallback _refresh;
  final DateTime Function() _now;
  late DateTime _last;
  late final AppLifecycleListener _lifecycle;

  @visibleForTesting
  void resumed() {
    final now = _now();
    if (now.difference(_last) < kConfigRefreshInterval) return;
    _last = now;
    _refresh();
  }

  void dispose() => _lifecycle.dispose();
}

final configRefreshCoordinatorProvider =
    Provider<ConfigRefreshCoordinator>((ref) {
  final c = ConfigRefreshCoordinator(() => ref.invalidate(appConfigProvider));
  ref.onDispose(c.dispose);
  return c;
});
