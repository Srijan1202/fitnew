import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_config.dart';

/// Beta 3.3 (ADR-033): the features the admin panel switches on and off,
/// the same list as `APP_FEATURES` in packages/contracts (a test checks).
/// Off hides the feature's entry points; the server refuses it too.
enum AppFeature {
  shareProgramme('share-programme', 'Share your programme'),
  messRatings('mess-ratings', 'Mess ratings'),
  streaks('streaks', 'Streak and goal ring'),
  communityFoods('community-foods', 'Community foods'),
  foodRequests('food-requests', 'Missing-food requests'),
  weeklyReport('weekly-report', 'Weekly report'),
  progressPhotos('progress-photos', 'Progress photos'),
  // Beta 3.6 (F15): "What should I eat?" from FITOS AI.
  foodGuide('food-guide', 'AI food guide'),
  // Beta 4.0 (ADR-038): the Running half of Training.
  running('running', 'Running'),

  /// Beta 5.8 (ADR-057): friends, clubs and the world board.
  community('community', 'Community'),

  /// Beta 6.0 (ADR-059): the water card on Home.
  water('water', 'Water'),

  /// Beta 6.1: the premium monthly report (a PDF made on the phone).
  monthlyReport('monthly-report', 'Monthly report');

  const AppFeature(this.key, this.label);

  final String key;

  /// The name `APP_FEATURES` gives it, for the Early access line (beta 6.1).
  final String label;
}

/// On unless the server says off; unknown (offline, still loading) is on.
/// Beta 6.1: the account's own switches first, so an early-access feature
/// is on for a premium account and off for the rest.
final featureOnProvider = Provider.family<bool, AppFeature>(
  (ref, feature) => switchFor(ref, feature.key) ?? true,
);

/// Beta 6.1: the features on for this account only because it is premium.
final earlyAccessProvider = Provider<List<AppFeature>>((ref) {
  final keys = ref.watch(myFeaturesProvider).value?.earlyAccess ?? const [];
  return [
    for (final f in AppFeature.values)
      if (keys.contains(f.key)) f,
  ];
});

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
