import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/errors/result.dart';
import '../domain/run.dart';
import '../domain/run_math.dart';
import '../domain/track.dart';
import '../domain/workout.dart';
import 'run_store.dart';
import 'run_sync_engine.dart';
import 'running_api.dart';

/// Beta 4.0 (ADR-038): runs for the screens. A saved run shows at once from
/// the phone (its own preview, marked "not synced yet") and from the
/// server's record once it has it; the history's first page and every run
/// opened are cached, so the history reads offline.
class RunningRepository {
  RunningRepository(
    this._db,
    this._api,
    this.engine, {
    DateTime Function()? now,
  })  : _store = RunStore(_db),
        _now = now ?? DateTime.now;

  final AppDatabase _db;
  final RunningApi _api;
  final RunSyncEngine engine;
  final RunStore _store;
  final DateTime Function() _now;

  RunStore get store => _store;

  void sync() => engine.kick();

  void dispose() => engine.dispose();

  /* ---------------------------------------------------------- history -- */

  /// Saved runs the server does not have yet, as list rows.
  Stream<List<RunSummary>> watchUnsynced() =>
      _store.watchUnsynced().asyncMap((rows) async {
        return [for (final r in rows) (await preview(r)).summary];
      });

  /// The cached first page (offline), or null.
  Future<RunList?> cachedList() async {
    final row = await (_db.select(_db.cachedJson)
          ..where((c) => c.key.equals(runListCacheKey)))
        .getSingleOrNull();
    if (row == null) return null;
    try {
      return RunList.fromJson(jsonDecode(row.json) as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }

  /// The server's first page (or the next one, `before`). The first page
  /// is cached; a run deleted on this phone but not yet on the server is
  /// left out.
  Future<Result<RunList>> fetchList({String? before}) async {
    final result = await _api.runs(before: before);
    if (result case Ok(:final value) when before == null) {
      await _db.into(_db.cachedJson).insertOnConflictUpdate(
            CachedJsonCompanion.insert(
              key: runListCacheKey,
              json: jsonEncode(_listJson(value)),
              storedAt: _now().toUtc().toIso8601String(),
            ),
          );
    }
    if (result case Ok(:final value)) {
      final deleting = await _pendingDeletes();
      return Ok(
        RunList(
          runs: [
            for (final r in value.runs)
              if (!deleting.contains(r.id)) r,
          ],
          nextBefore: value.nextBefore,
          week: value.week,
          month: value.month,
        ),
      );
    }
    return result;
  }

  Future<Set<String>> _pendingDeletes() async {
    final rows = await (_db.select(_db.runSyncQueue)
          ..where((q) => q.kind.equals(RunSyncKind.delete.name)))
        .get();
    return {for (final r in rows) r.clientRunId};
  }

  Map<String, dynamic> _listJson(RunList l) => {
        'runs': [for (final r in l.runs) _summaryJson(r)],
        'nextBefore': l.nextBefore,
        'totals': {
          'week': _totalsJson(l.week),
          'month': _totalsJson(l.month),
        },
      };

  Map<String, dynamic> _totalsJson(RunTotals t) => {
        'runs': t.runs,
        'distanceM': t.distanceM,
        'durationSeconds': t.durationSeconds,
      };

  Map<String, dynamic> _summaryJson(RunSummary r) => {
        'id': r.id,
        'kind': r.kind.name,
        'name': r.name,
        'startedAt': r.startedAt.toUtc().toIso8601String(),
        'endedAt': r.endedAt.toUtc().toIso8601String(),
        'durationSeconds': r.durationSeconds,
        'distanceM': r.distanceM,
        'avgPaceSecPerKm': r.avgPaceSecPerKm,
        'elevationGainM': r.elevationGainM,
        'calories': r.calories,
        'effort': r.effort,
        'outline': [
          for (final p in r.outline) [p.$1, p.$2],
        ],
      };

  /* ------------------------------------------------------------- a run -- */

  /// The phone's own figures for a run it still holds (finished or saved).
  Future<RunDetail> preview(LocalRun r, {double? weightKg}) async {
    final kind = RunKind.parse(r.kind);
    final duration = r.activeMs ~/ 1000;
    final track =
        kind == RunKind.outdoor ? await _store.track(r.clientRunId) : null;
    final f = track != null
        ? summarizeTrack(track, duration, weightKg)
        : summarizeTreadmill(r.treadmillDistanceM ?? 0, duration, weightKg);
    final started = DateTime.parse(r.startedAt);
    return RunDetail(
      summary: RunSummary(
        id: r.clientRunId,
        kind: kind,
        name: r.name ?? defaultRunName(started.toLocal(), kind),
        startedAt: started,
        endedAt: r.endedAt == null ? _now() : DateTime.parse(r.endedAt!),
        durationSeconds: duration,
        distanceM: f.distanceM,
        avgPaceSecPerKm: f.avgPaceSecPerKm,
        elevationGainM: f.elevationGainM,
        calories: f.calories,
        effort: r.effort,
        outline: f.outline,
      ),
      note: r.note,
      goal: RunGoal.stored(
        r.goalKind,
        r.goalValue,
        r.goalTargetSeconds,
        r.goalSplit,
      ),
      track: track,
      splitsKm: f.splitsKm,
      splitsMi: f.splitsMi,
      series: f.series,
      pending: true,
      workout: r.workoutJson == null
          ? null
          : RunWorkout.fromJson(
              jsonDecode(r.workoutJson!) as Map<String, dynamic>,
            ),
      plannedRunId: r.plannedRunId,
    );
  }

  /// A run: the phone's copy while it has one, else the cached record.
  Future<RunDetail?> local(String id, {double? weightKg}) async {
    final row = await _store.byId(id);
    if (row != null) return preview(row, weightKg: weightKg);
    final cached = await (_db.select(_db.cachedJson)
          ..where((c) => c.key.equals(runCacheKey(id))))
        .getSingleOrNull();
    if (cached == null) return null;
    return RunDetail.fromJson(jsonDecode(cached.json) as Map<String, dynamic>);
  }

  /// The server's record of a run (cached for offline).
  Future<Result<RunDetail>> fetch(String id) async {
    final result = await _api.run(id);
    switch (result) {
      case Ok(:final value):
        await _db.into(_db.cachedJson).insertOnConflictUpdate(
              CachedJsonCompanion.insert(
                key: runCacheKey(id),
                json: jsonEncode(value),
                storedAt: _now().toUtc().toIso8601String(),
              ),
            );
        return Ok(RunDetail.fromJson(value));
      case Err(:final failure):
        return Err(failure);
    }
  }

  /// Saves a finished run: it is queued with everything the server needs.
  Future<void> save(
    String id, {
    required String name,
    String? note,
    int? effort,
    double? treadmillDistanceM,
  }) async {
    final row = await _store.byId(id);
    if (row == null) return;
    final kind = RunKind.parse(row.kind);
    final duration = row.activeMs ~/ 1000;
    final body = <String, dynamic>{
      'clientRunId': id,
      'kind': kind.name,
      'name': name,
      'startedAt': row.startedAt,
      'endedAt': row.endedAt ?? _now().toUtc().toIso8601String(),
      'durationSeconds': duration,
      'goal': RunGoal.stored(
        row.goalKind,
        row.goalValue,
        row.goalTargetSeconds,
        row.goalSplit,
      ).toJson(),
      if (note != null && note.isNotEmpty) 'note': note,
      if (effort != null) 'effort': effort,
      if (kind == RunKind.outdoor)
        'track': encodeTrack(await _store.track(id)).toJson()
      else
        'distanceM': treadmillDistanceM ?? 0,
      // Beta 4.1: the session, where its steps began and ended, the plan's run.
      if (row.workoutJson != null) 'workout': jsonDecode(row.workoutJson!),
      if (row.workoutJson != null &&
          row.lapsJson != null &&
          kind == RunKind.outdoor)
        'laps': jsonDecode(row.lapsJson!),
      if (row.plannedRunId != null) 'plannedRunId': row.plannedRunId,
    };
    await _db.transaction(() async {
      await _store.update(
        id,
        LocalRunsCompanion(
          status: const Value('saved'),
          name: Value(name),
          note: Value(note),
          effort: Value(effort),
          treadmillDistanceM: Value(treadmillDistanceM),
          updatedAt: Value(_now().toUtc().toIso8601String()),
        ),
      );
      await engine.enqueue(RunSyncKind.create, id, body, wake: false);
    });
    engine.kick();
  }

  /// Changes a run's name, note or effort. An upload that has not left yet
  /// takes the change itself (no edit for a run the server never saw).
  Future<void> edit(
    String id, {
    String? name,
    String? note,
    int? effort,
    bool clearEffort = false,
  }) async {
    final pending = await engine.pendingCreate(id);
    if (pending != null && !engine.isInFlight(id)) {
      final body = jsonDecode(pending.payloadJson) as Map<String, dynamic>;
      if (name != null) body['name'] = name;
      if (note != null) {
        if (note.isEmpty) {
          body.remove('note');
        } else {
          body['note'] = note;
        }
      }
      if (effort != null) body['effort'] = effort;
      if (clearEffort) body.remove('effort');
      await engine.replacePayload(pending.id, body);
      await _store.update(
        id,
        LocalRunsCompanion(
          name: name == null ? const Value.absent() : Value(name),
          note: note == null ? const Value.absent() : Value(note),
          effort: clearEffort
              ? const Value(null)
              : effort == null
                  ? const Value.absent()
                  : Value(effort),
        ),
      );
      return;
    }
    await engine.enqueue(RunSyncKind.patch, id, {
      if (name != null) 'name': name,
      if (note != null) 'note': note.isEmpty ? null : note,
      if (effort != null) 'effort': effort,
      if (clearEffort) 'effort': null,
    });
  }

  /// Deletes a run everywhere. One the server never had goes at once.
  Future<void> delete(String id) async {
    final pending = await engine.pendingCreate(id);
    if (pending != null && !engine.isInFlight(id)) {
      await _db.transaction(() async {
        await (_db.delete(_db.runSyncQueue)
              ..where((q) => q.clientRunId.equals(id)))
            .go();
        await _store.delete(id);
      });
      return;
    }
    await _db.transaction(() async {
      await _store.delete(id);
      await (_db.delete(_db.cachedJson)
            ..where((c) => c.key.equals(runCacheKey(id))))
          .go();
      await engine.enqueue(RunSyncKind.delete, id, const {}, wake: false);
    });
    engine.kick();
  }

  Stream<int> watchParkedCount() =>
      engine.watchParked().map((rows) => rows.length);
}
