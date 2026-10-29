import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

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
/// for the signed-in account (they need no connection to run). Beta 4.4
/// (E28): kept with the account too, so a new phone or a reinstall has them.
/// Each has the phone's id; a change is saved here at once and sent to the
/// server, and one that could not be sent (offline) waits in a small queue
/// sent before the next read. The server's list is then the list, plus what
/// is still waiting. Sessions from before 4.4 (no id) get one and go up once.
class MyWorkouts extends AsyncNotifier<List<RunWorkout>> {
  static const _uuid = Uuid();

  String get _key => 'running.myWorkouts.${ref.read(sessionUserIdProvider)}';

  /// The ids of [state], in order.
  List<String> _ids = [];

  /// Waiting to be sent: ids to put (their session is in the list) or delete.
  final Set<String> _put = {};
  final Set<String> _delete = {};

  @override
  Future<List<RunWorkout>> build() async {
    ref.watch(sessionUserIdProvider);
    final json = await _cached(ref.read(appDatabaseProvider), _key);
    final list = json?['workouts'];
    final all = <RunWorkout>[];
    _ids = [];
    _put
      ..clear()
      ..addAll([for (final x in (json?['put'] as List?) ?? const []) '$x']);
    _delete
      ..clear()
      ..addAll([for (final x in (json?['delete'] as List?) ?? const []) '$x']);
    if (list is List) {
      for (final w in list) {
        if (w is! Map<String, dynamic>) continue;
        all.add(RunWorkout.fromJson(w));
        final id = w['id'] as String?;
        if (id == null) {
          // From before 4.4: an id now, and up it goes.
          final fresh = _uuid.v4();
          _ids.add(fresh);
          _put.add(fresh);
        } else {
          _ids.add(id);
        }
      }
    }
    unawaited(_sync());
    return all;
  }

  Future<void> _store(List<RunWorkout> all) async {
    await _cache(ref.read(appDatabaseProvider), _key, {
      'workouts': [
        for (var i = 0; i < all.length; i++)
          {...all[i].toJson(), 'id': _ids[i]},
      ],
      'put': [..._put],
      'delete': [..._delete],
    });
    if (ref.mounted) state = AsyncData(all);
  }

  /// Sends what waits, then takes the server's list (plus anything still
  /// waiting). Offline, or an older server: the phone's list stands.
  Future<void> _sync() async {
    final api = ref.read(runningApiProvider);
    final mine = state.value ?? await future;
    for (final id in [..._put]) {
      final i = _ids.indexOf(id);
      if (i < 0) {
        _put.remove(id);
        continue;
      }
      if (await api.putMyWorkout(id, mine[i]) case Ok()) _put.remove(id);
    }
    for (final id in [..._delete]) {
      if (await api.deleteMyWorkout(id) case Ok()) _delete.remove(id);
    }
    if (!ref.mounted) return;
    final server = await api.myWorkouts();
    if (!ref.mounted) return;
    if (server case Ok(:final value)) {
      final current = state.value ?? mine;
      final ids = <String>[];
      final all = <RunWorkout>[];
      // Still waiting to go up: kept, first, as the phone has them.
      for (var i = 0; i < _ids.length; i++) {
        if (_put.contains(_ids[i])) {
          ids.add(_ids[i]);
          all.add(current[i]);
        }
      }
      for (final w in value) {
        final id = w['id'] as String;
        if (_delete.contains(id) || ids.contains(id)) continue;
        ids.add(id);
        all.add(RunWorkout.fromJson(w));
      }
      _ids = ids;
      await _store(all);
    } else {
      await _store(state.value ?? mine);
    }
  }

  /// Saved first in the list; returns its index there (0).
  Future<int> add(RunWorkout w) async {
    final all = [w, ...await future];
    final id = _uuid.v4();
    _ids = [id, ..._ids];
    _put.add(id);
    await _store(all);
    unawaited(_sync());
    return 0;
  }

  Future<void> removeAt(int i) async {
    final all = [...await future]..removeAt(i);
    final id = _ids.removeAt(i);
    if (!_put.remove(id)) _delete.add(id);
    await _store(all);
    unawaited(_sync());
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
