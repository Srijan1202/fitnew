import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/errors/result.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
import '../../../workout/presentation/controllers/workout_providers.dart';
import '../../../../core/db/app_database.dart';
import '../../data/location_source.dart';
import '../../data/run_voice.dart';
import '../../data/run_sync_engine.dart';
import '../../data/running_api.dart';
import '../../data/running_repository.dart';
import '../../domain/efforts.dart';
import '../../domain/run.dart';
import '../../domain/workout.dart';
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

/// Beta 4.1: the coach's voice.
final runVoiceProvider = Provider<RunVoice>((ref) => TtsRunVoice());

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
  // Beta 4.1: a run the server now holds may have done a planned run.
  final drained =
      repo.engine.drained.listen((_) => ref.invalidate(currentPlanProvider));
  repo.sync();
  ref.onDispose(() {
    sub.cancel();
    drained.cancel();
    lifecycle.dispose();
  });
});

/* ------------------------------------------------------------ settings -- */

class RunSettings {
  const RunSettings({
    this.unit = DistanceUnit.km,
    this.autoPause = true,
    this.batteryAsked = false,
    this.voice = true,
    this.everyHalf = false,
  });

  final DistanceUnit unit;
  final bool autoPause;

  /// Beta 4.1: the voice coach (owner default: on, every 1 km).
  final bool voice;
  final bool everyHalf;

  /// The battery question was asked once (the answer is the phone's).
  final bool batteryAsked;

  RunSettings copyWith({
    DistanceUnit? unit,
    bool? autoPause,
    bool? batteryAsked,
    bool? voice,
    bool? everyHalf,
  }) =>
      RunSettings(
        unit: unit ?? this.unit,
        autoPause: autoPause ?? this.autoPause,
        batteryAsked: batteryAsked ?? this.batteryAsked,
        voice: voice ?? this.voice,
        everyHalf: everyHalf ?? this.everyHalf,
      );
}

/// Owner defaults: km, auto-pause on. Kept on the phone.
class RunSettingsController extends Notifier<RunSettings> {
  static const _unit = 'running.unit';
  static const _autoPause = 'running.autoPause';
  static const _battery = 'running.batteryAsked';
  static const _voice = 'running.voice';
  static const _everyHalf = 'running.everyHalf';

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
        voice: p.getBool(_voice) ?? true,
        everyHalf: p.getBool(_everyHalf) ?? false,
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
      await p.setBool(_voice, state.voice);
      await p.setBool(_everyHalf, state.everyHalf);
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

  Future<void> setVoice(bool on) async {
    state = state.copyWith(voice: on);
    await _save();
  }

  Future<void> setEveryHalf(bool on) async {
    state = state.copyWith(everyHalf: on);
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

/// Beta 4.1 (C5): the last 7 days of running, for Recovery; null until the
/// history is known. Saved and not-yet-synced runs both count.
final runningLast7Provider = Provider<RunTotals?>((ref) {
  final history = ref.watch(runHistoryProvider).value;
  if (history == null) return null;
  final since = ref.watch(runClockProvider)().subtract(const Duration(days: 7));
  final recent = history.all.where((r) => r.startedAt.isAfter(since));
  return RunTotals(
    runs: recent.length,
    distanceM: recent.fold(0, (sum, r) => sum + r.distanceM),
    durationSeconds: recent.fold(0, (sum, r) => sum + r.durationSeconds),
  );
});

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

/* --------------------------------------------- beta 4.1: plans -- */

const String _planCacheKey = 'running.plan';

Future<Map<String, dynamic>?> _cached(AppDatabase db, String key) async {
  final row = await (db.select(db.cachedJson)..where((c) => c.key.equals(key)))
      .getSingleOrNull();
  if (row == null) return null;
  try {
    return jsonDecode(row.json) as Map<String, dynamic>;
  } on Object {
    return null;
  }
}

Future<void> _cache(AppDatabase db, String key, Object? json) =>
    db.into(db.cachedJson).insertOnConflictUpdate(
          CachedJsonCompanion.insert(
            key: key,
            json: jsonEncode(json),
            storedAt: DateTime.now().toUtc().toIso8601String(),
          ),
        );

/// The active running plan; the last copy when offline (null without one).
final currentPlanProvider = FutureProvider<RunningPlan?>((ref) async {
  final api = ref.watch(runningApiProvider);
  final db = ref.watch(appDatabaseProvider);
  final result = await api.currentPlan();
  final Map<String, dynamic>? json;
  switch (result) {
    case Ok(:final value):
      await _cache(db, _planCacheKey, value);
      json = value;
    case Err():
      json = await _cached(db, _planCacheKey);
  }
  final plan = json?['plan'];
  return plan is Map<String, dynamic> ? RunningPlan.fromJson(plan) : null;
});

/* --------------------------------------- beta 4.2: best efforts -- */

const String _recordsCacheKey = 'running.records';

/// The records (the best three at each distance); the last copy when
/// offline, and refreshed whenever a run reaches the server.
final recordsProvider = FutureProvider<RunningRecords?>((ref) async {
  final api = ref.watch(runningApiProvider);
  final db = ref.watch(appDatabaseProvider);
  final repo = ref.watch(runningRepositoryProvider);
  final sub = repo.engine.drained.listen((_) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);
  final result = await api.records();
  final Map<String, dynamic>? json;
  switch (result) {
    case Ok(:final value):
      await _cache(db, _recordsCacheKey, value);
      json = value;
    case Err():
      json = await _cached(db, _recordsCacheKey);
  }
  return json == null ? null : RunningRecords.fromJson(json);
});

/// Beta 4.1 (ADR-039 C2): the sessions the runner built, kept on this phone
/// for the signed-in account (they need no connection to run).
class MyWorkouts extends AsyncNotifier<List<RunWorkout>> {
  String get _key => 'running.myWorkouts.${ref.read(sessionUserIdProvider)}';

  @override
  Future<List<RunWorkout>> build() async {
    ref.watch(sessionUserIdProvider);
    final json = await _cached(ref.read(appDatabaseProvider), _key);
    final list = json?['workouts'];
    if (list is! List) return const [];
    return [
      for (final w in list)
        if (w is Map<String, dynamic>) RunWorkout.fromJson(w),
    ];
  }

  Future<void> _store(List<RunWorkout> all) async {
    await _cache(ref.read(appDatabaseProvider), _key, {
      'workouts': [for (final w in all) w.toJson()],
    });
    state = AsyncData(all);
  }

  /// Saved first in the list; returns its index there (0).
  Future<int> add(RunWorkout w) async {
    await _store([w, ...await future]);
    return 0;
  }

  Future<void> removeAt(int i) async {
    final all = [...await future]..removeAt(i);
    await _store(all);
  }
}

final myWorkoutsProvider =
    AsyncNotifierProvider<MyWorkouts, List<RunWorkout>>(MyWorkouts.new);

/// The ready-made sessions (paced from the plan's zones when there is one).
final workoutPresetsProvider = FutureProvider<WorkoutPresets?>((ref) async {
  final api = ref.watch(runningApiProvider);
  final result = await api.workouts();
  return switch (result) {
    Ok(:final value) => value,
    Err() => null,
  };
});
