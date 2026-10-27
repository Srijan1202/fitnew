import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/errors/result.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
import '../../../workout/presentation/controllers/workout_providers.dart';
import '../../data/location_source.dart';
import '../../data/run_sync_engine.dart';
import '../../data/running_api.dart';
import '../../data/running_repository.dart';
import '../../domain/run.dart';
import '../../domain/units.dart';

/// Beta 4.0 (ADR-038): running's providers.

final runningApiProvider = Provider<RunningApi>(
  (ref) => DioRunningApi(ref.watch(dioProvider)),
);

final runningRepositoryProvider = Provider<RunningRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final api = ref.watch(runningApiProvider);
  final repo = RunningRepository(
    db,
    api,
    RunSyncEngine(db, api, wakeItself: ref.watch(syncWakesItselfProvider)),
  );
  ref.onDispose(repo.dispose);
  return repo;
});

final locationSourceProvider =
    Provider<LocationSource>((ref) => GeolocatorSource());

final runNotificationProvider =
    Provider<RunNotification>((ref) => AndroidRunNotification());

final batteryAccessProvider =
    Provider<BatteryAccess>((ref) => AndroidBatteryAccess());

/// The clock a run is timed by; tests hand in their own.
final runClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Drains the run queue on connectivity, resume and sign-in, like workouts.
final runSyncCoordinatorProvider = Provider<void>((ref) {
  if (ref.watch(sessionUserIdProvider) == null) return;
  final repo = ref.watch(runningRepositoryProvider);
  final sub = ref.watch(connectivityStreamProvider).listen((results) {
    if (results.any((r) => r != ConnectivityResult.none)) repo.sync();
  });
  final lifecycle = AppLifecycleListener(onResume: repo.sync);
  repo.sync();
  ref.onDispose(() {
    sub.cancel();
    lifecycle.dispose();
  });
});

/* ------------------------------------------------------------ settings -- */

class RunSettings {
  const RunSettings({
    this.unit = DistanceUnit.km,
    this.autoPause = true,
    this.batteryAsked = false,
  });

  final DistanceUnit unit;
  final bool autoPause;

  /// The battery question was asked once (the answer is the phone's).
  final bool batteryAsked;

  RunSettings copyWith({
    DistanceUnit? unit,
    bool? autoPause,
    bool? batteryAsked,
  }) =>
      RunSettings(
        unit: unit ?? this.unit,
        autoPause: autoPause ?? this.autoPause,
        batteryAsked: batteryAsked ?? this.batteryAsked,
      );
}

/// Owner defaults: km, auto-pause on. Kept on the phone.
class RunSettingsController extends Notifier<RunSettings> {
  static const _unit = 'running.unit';
  static const _autoPause = 'running.autoPause';
  static const _battery = 'running.batteryAsked';

  /// Set once the runner changes something: a late load must not undo it.
  bool _changed = false;

  @override
  RunSettings build() {
    unawaited(_load());
    return const RunSettings();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!ref.mounted || _changed) return;
      state = RunSettings(
        unit: DistanceUnit.parse(p.getString(_unit)),
        autoPause: p.getBool(_autoPause) ?? true,
        batteryAsked: p.getBool(_battery) ?? false,
      );
    } on Object {
      // Defaults stand.
    }
  }

  Future<void> _save() async {
    _changed = true;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_unit, state.unit.name);
      await p.setBool(_autoPause, state.autoPause);
      await p.setBool(_battery, state.batteryAsked);
    } on Object {
      // Kept for this session only.
    }
  }

  Future<void> setUnit(DistanceUnit unit) async {
    state = state.copyWith(unit: unit);
    await _save();
  }

  Future<void> setAutoPause(bool on) async {
    state = state.copyWith(autoPause: on);
    await _save();
  }

  Future<void> markBatteryAsked() async {
    state = state.copyWith(batteryAsked: true);
    await _save();
  }
}

final runSettingsProvider =
    NotifierProvider<RunSettingsController, RunSettings>(
  RunSettingsController.new,
);

/* ------------------------------------------------------------- history -- */

/// The history: runs the server has not confirmed (newest first), then the
/// server's first page — cached, so it shows offline.
class RunHistory {
  const RunHistory({
    required this.unsynced,
    required this.list,
    required this.offline,
  });

  final List<RunSummary> unsynced;
  final RunList? list;

  /// The server was not reachable: [list] is the cached copy (or null).
  final bool offline;

  List<RunSummary> get all => [
        ...unsynced,
        for (final r in list?.runs ?? const <RunSummary>[])
          if (!unsynced.any((u) => u.id == r.id)) r,
      ];
}

final unsyncedRunsProvider = StreamProvider<List<RunSummary>>(
  (ref) => ref.watch(runningRepositoryProvider).watchUnsynced(),
);

final runListProvider = FutureProvider<(RunList?, bool)>((ref) async {
  final repo = ref.watch(runningRepositoryProvider);
  // A run that reached the server refreshes the list.
  final sub = repo.engine.drained.listen((_) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);
  return switch (await repo.fetchList()) {
    Ok(:final value) => (value, false),
    Err() => (await repo.cachedList(), true),
  };
});

final runHistoryProvider = Provider<AsyncValue<RunHistory>>((ref) {
  final unsynced = ref.watch(unsyncedRunsProvider);
  final list = ref.watch(runListProvider);
  if (list.isLoading && !list.hasValue) return const AsyncLoading();
  return AsyncData(
    RunHistory(
      unsynced: unsynced.value ?? const [],
      list: list.value?.$1,
      offline: list.value?.$2 ?? true,
    ),
  );
});

/// One run: the phone's copy or cache first, then the server's record.
final runDetailProvider =
    StreamProvider.family<RunDetail?, String>((ref, id) async* {
  final repo = ref.watch(runningRepositoryProvider);
  final weight =
      ref.read(profileControllerProvider).value?.profile.latestWeightKg;
  final local = await repo.local(id, weightKg: weight);
  if (local != null) yield local;
  if (local?.pending ?? false) return;
  final result = await repo.fetch(id);
  if (result case Ok(:final value)) {
    yield value;
  } else if (local == null) {
    yield null;
  }
});
