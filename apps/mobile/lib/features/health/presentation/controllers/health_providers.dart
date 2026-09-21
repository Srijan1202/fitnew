import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/db/app_database.dart';
import '../../../auth/domain/entities/auth_state.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../workout/presentation/controllers/rest_timer.dart'
    show sharedPreferencesProvider;
import '../../../workout/presentation/controllers/workout_providers.dart'
    show appDatabaseProvider;
import '../../data/health_connect_channel.dart';
import '../../data/health_connect_provider.dart';
import '../../domain/entities/health.dart';
import '../../domain/health_data_provider.dart';

/// Phase 6.5 — health state for the Home screen. The provider is Health
/// Connect on Android and honest `unsupported` elsewhere; the snapshot is
/// fetched on demand (Home shown, app resumed, permissions changed, pull
/// to refresh) and never polled; the last good answer for today is kept
/// in the phone's `cached_json` so a reopen shows it at once — marked
/// `fromCache` until the provider answers again. Nothing here leaves the
/// device (owner D2).

final healthDataProviderProvider = Provider<HealthDataProvider>((ref) {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return HealthConnectProvider(const MethodChannelHealthConnect());
  }
  return const UnsupportedHealthProvider();
});

/// The signed-in user's calendar; the server's `users.timezone`.
final userTimezoneProvider = Provider<String>((ref) {
  final state = ref.watch(authControllerProvider).value;
  return state is AuthSignedIn ? state.profile.timezone : 'UTC';
});

/// Today's local date (yyyy-mm-dd) in the user's calendar, computed once
/// per read; tests override it.
final localTodayProvider = Provider<String>((ref) {
  final zone = ref.watch(userTimezoneProvider);
  final now = tz.TZDateTime.now(_location(zone));
  final mm = now.month.toString().padLeft(2, '0');
  final dd = now.day.toString().padLeft(2, '0');
  return '${now.year}-$mm-$dd';
});

bool _tzReady = false;

/// The tz database, loaded once on first use (also by the provider).
tz.Location _location(String zone) {
  if (!_tzReady) {
    tzdata.initializeTimeZones();
    _tzReady = true;
  }
  try {
    return tz.getLocation(zone);
  } on Object {
    return tz.UTC;
  }
}

/// For other providers that need a zone.
tz.Location userLocation(String zone) => _location(zone);

/* --------------------------------------------------------- connection -- */

class HealthConnectionController extends AsyncNotifier<HealthConnectionState> {
  HealthDataProvider get _provider => ref.read(healthDataProviderProvider);

  @override
  Future<HealthConnectionState> build() {
    requireSession(ref);
    return _provider.connection();
  }

  /// Re-read the SDK status and grants (a permission may have been
  /// revoked in Health Connect since).
  Future<void> refresh() async {
    state = AsyncData(await _provider.connection());
    ref.invalidate(healthSnapshotProvider);
  }

  /// Ask for a category's permissions (the provider's own sheet), then
  /// re-read everything.
  Future<HealthConnectionState> connect(Set<HealthCategory> categories) async {
    final kinds = <HealthMetricKind>{
      for (final c in categories) ...HealthMetricKind.inCategory(c),
    };
    final next = await _provider.requestPermissions(kinds);
    state = AsyncData(next);
    ref.invalidate(healthSnapshotProvider);
    return next;
  }

  Future<bool> openSettings() => _provider.openSettings();
}

final healthConnectionProvider =
    AsyncNotifierProvider<HealthConnectionController, HealthConnectionState>(
  HealthConnectionController.new,
  retry: (_, __) => null,
);

/* ----------------------------------------------------------- snapshot -- */

class HealthSnapshotController extends AsyncNotifier<HealthSnapshot> {
  static String _key(String date) => 'health:$date';

  @override
  Future<HealthSnapshot> build() async {
    requireSession(ref);
    // A change of grants rebuilds the snapshot.
    ref.watch(healthConnectionProvider);
    return _load();
  }

  Future<HealthSnapshot> _load() async {
    final date = ref.read(localTodayProvider);
    final zone = ref.read(userTimezoneProvider);
    final provider = ref.read(healthDataProviderProvider);
    final db = ref.read(appDatabaseProvider);
    final live = await provider.snapshot(date: date, timezone: zone);
    final anyValue = live.metrics.any((m) => m.isAvailable) ||
        live.exerciseAvailability == HealthAvailability.available;
    if (anyValue) {
      await db.into(db.cachedJson).insertOnConflictUpdate(
            CachedJsonCompanion.insert(
              key: _key(date),
              json: jsonEncode(live.toJson()),
              storedAt: live.fetchedAt,
            ),
          );
      return live;
    }
    // Only a provider hiccup falls back to the cache; "not connected",
    // "denied" and "unsupported" are the truth and must show as such.
    final hiccup = live.metrics.any(
      (m) => m.availability == HealthAvailability.temporarilyUnavailable,
    );
    if (hiccup) {
      final row = await (db.select(db.cachedJson)
            ..where((t) => t.key.equals(_key(date))))
          .getSingleOrNull();
      if (row != null) {
        return HealthSnapshot.fromJson(
          jsonDecode(row.json) as Map<String, dynamic>,
        ).copyWith(fromCache: true);
      }
    }
    return live;
  }

  /// Foreground refresh: Home shown, app resumed, pull to refresh.
  Future<void> refresh() async {
    state = AsyncData(await _load());
  }
}

final healthSnapshotProvider =
    AsyncNotifierProvider<HealthSnapshotController, HealthSnapshot>(
  HealthSnapshotController.new,
  retry: (_, __) => null,
);

/* ------------------------------------------------------------ refresh -- */

/// Refreshes the health snapshot when the app returns to the foreground.
/// Watched once from the app root, like the sync coordinator. No polling.
class HealthRefreshCoordinator {
  HealthRefreshCoordinator(this._onResume) {
    _lifecycle = AppLifecycleListener(onResume: _onResume);
  }

  final VoidCallback _onResume;
  late final AppLifecycleListener _lifecycle;

  void dispose() => _lifecycle.dispose();
}

final healthRefreshCoordinatorProvider =
    Provider<HealthRefreshCoordinator?>((ref) {
  if (ref.watch(sessionUserIdProvider) == null) return null;
  final c = HealthRefreshCoordinator(() {
    // Grants may have changed while away; the connection refresh
    // invalidates the snapshot, which refetches.
    ref.read(healthConnectionProvider.notifier).refresh();
  });
  ref.onDispose(c.dispose);
  return c;
});

/* ---------------------------------------------------------- step goal -- */

/// Owner D4: a daily step goal, 8,000 by default, kept on the phone.
class StepGoal extends Notifier<int> {
  static const defaultGoal = 8000;
  static const key = 'health.stepGoal';

  @override
  int build() {
    final prefs = ref.watch(sharedPreferencesProvider).value;
    return prefs?.getInt(key) ?? defaultGoal;
  }

  Future<void> set(int goal) async {
    state = goal;
    await ref.read(sharedPreferencesProvider).value?.setInt(key, goal);
  }
}

final stepGoalProvider = NotifierProvider<StepGoal, int>(StepGoal.new);
