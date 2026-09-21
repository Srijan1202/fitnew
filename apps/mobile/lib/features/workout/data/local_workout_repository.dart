import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../exercise/domain/entities/exercise.dart';
import '../domain/entities/workout.dart';
import '../domain/repositories/workout_repository.dart';
import 'sync_engine.dart';
import 'workout_api.dart';

/// Local-first workout logging (§33, §39 offline flow).
///
/// Every mutation: write the phone's row, enqueue the request, kick the
/// drainer. Reads of the live session come from the phone's rows and are
/// re-emitted on every change. The server's answers only ever ADD
/// information (server ids, records, the summary); they never remove a
/// row the phone holds, because that row may still be on its way up.
class LocalWorkoutRepository implements WorkoutRepository {
  LocalWorkoutRepository(
    this._db,
    this._api, {
    Uuid? uuid,
    DateTime Function()? now,
    SyncEngine? engine,
  })  : _uuid = uuid ?? const Uuid(),
        _now = now ?? DateTime.now,
        _sync = engine ?? SyncEngine(_db, _api);

  final AppDatabase _db;
  final WorkoutApi _api;
  final Uuid _uuid;
  final DateTime Function() _now;
  final SyncEngine _sync;

  String _stamp() => _now().toUtc().toIso8601String();

  late final TableUpdateQuery _anySessionTable = TableUpdateQuery.onAllTables([
    _db.localSessions,
    _db.localSessionExercises,
    _db.localSetLogs,
  ]);

  /* ------------------------------------------------------------ reads -- */

  Future<WorkoutSession?> _load(String clientSessionId) async {
    final row = await (_db.select(_db.localSessions)
          ..where((t) => t.clientSessionId.equals(clientSessionId)))
        .getSingleOrNull();
    if (row == null) return null;
    final snapshot = WorkoutSession.fromJson(
      jsonDecode(row.snapshotJson) as Map<String, dynamic>,
    );
    final exRows = await (_db.select(_db.localSessionExercises)
          ..where(
            (t) =>
                t.clientSessionId.equals(clientSessionId) &
                t.removed.equals(false),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
        .get();
    final setRows = exRows.isEmpty
        ? const <LocalSetLog>[]
        : await (_db.select(_db.localSetLogs)
              ..where(
                (t) =>
                    t.clientExerciseId
                        .isIn(exRows.map((e) => e.clientExerciseId)) &
                    t.deleted.equals(false),
              )
              ..orderBy([
                (t) => OrderingTerm.asc(t.setIndex),
                (t) => OrderingTerm.asc(t.loggedAt),
              ]))
            .get();
    final exercises = <SessionExercise>[
      for (final e in exRows)
        SessionExercise.fromJson(
          jsonDecode(e.exerciseJson) as Map<String, dynamic>,
        ).copyWith(
          id: e.serverId ?? e.clientExerciseId,
          clientExerciseId: e.clientExerciseId,
          exerciseId: e.exerciseId,
          orderIndex: e.orderIndex,
          supersetGroup: e.supersetGroup,
          plannedExerciseId: e.plannedExerciseId,
          sets: [
            for (final s in setRows)
              if (s.clientExerciseId == e.clientExerciseId)
                SetLog(
                  id: s.serverId ?? s.clientSetId,
                  clientSetId: s.clientSetId,
                  setIndex: s.setIndex,
                  setType: SetType.values.firstWhere(
                    (t) => t.wire == s.setType,
                  ),
                  weightKg: s.weightKg,
                  reps: s.reps,
                  rir: s.rir,
                  isPr: s.isPr,
                  loggedAt: s.loggedAt,
                  plannedSetId: s.plannedSetId,
                ),
          ],
        ),
    ];
    return snapshot.copyWith(
      id: row.serverId ?? clientSessionId,
      clientSessionId: clientSessionId,
      status: SessionStatus.values.firstWhere((s) => s.wire == row.status),
      name: row.name,
      programId: row.programId,
      programDayId: row.programDayId,
      startedAt: row.startedAt,
      completedAt: row.completedAt,
      notes: row.notes,
      exercises: exercises,
    );
  }

  @override
  Future<WorkoutSession?> session(String clientSessionId) =>
      _load(clientSessionId);

  @override
  Stream<WorkoutSession?> watchSession(String clientSessionId) async* {
    yield await _load(clientSessionId);
    await for (final _ in _db.tableUpdates(_anySessionTable)) {
      yield await _load(clientSessionId);
    }
  }

  Future<String?> _activeClientId() async {
    final row = await (_db.select(_db.localSessions)
          ..where((t) => t.status.equals(SessionStatus.active.wire))
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
          ..limit(1))
        .getSingleOrNull();
    return row?.clientSessionId;
  }

  @override
  Future<WorkoutSession?> activeSession() async {
    final id = await _activeClientId();
    return id == null ? null : _load(id);
  }

  @override
  Stream<WorkoutSession?> watchActiveSession() async* {
    yield await activeSession();
    await for (final _ in _db.tableUpdates(_anySessionTable)) {
      yield await activeSession();
    }
  }

  @override
  Future<Result<TodayResponse>> today({int? dayOfWeek}) async {
    final key = 'today:${dayOfWeek ?? 'today'}';
    final result = await _api.today(dayOfWeek: dayOfWeek);
    return result.when(
      ok: (t) async {
        await _db.into(_db.cachedJson).insertOnConflictUpdate(
              CachedJsonCompanion.insert(
                key: key,
                json: jsonEncode(t.toJson()),
                storedAt: _stamp(),
              ),
            );
        return Ok(t);
      },
      err: (f) async {
        final cached = await (_db.select(_db.cachedJson)
              ..where((t) => t.key.equals(key)))
            .getSingleOrNull();
        if (cached == null || f is Unauthenticated) return Err(f);
        return Ok(
          TodayResponse.fromJson(
            jsonDecode(cached.json) as Map<String, dynamic>,
          ),
        );
      },
    );
  }

  @override
  Future<Result<SessionListResponse>> history({
    String? before,
    int limit = 20,
  }) =>
      _api.list(before: before, limit: limit);

  @override
  Future<Result<WorkoutSession>> fetchSession(String serverId) =>
      _api.get(serverId);

  /* ----------------------------------------------------------- writes -- */

  @override
  Future<WorkoutSession> startSession({TodayResponse? day}) async {
    final clientSessionId = _uuid.v4();
    final startedAt = _stamp();
    final fromDay = day != null && !day.isRest && day.programDayId != null;
    final seeded = <SessionExercise>[
      if (fromDay)
        for (final x in day.exercises)
          SessionExercise(
            id: _uuid.v4(),
            clientExerciseId: '',
            exerciseId: x.exerciseId,
            slug: x.slug,
            name: x.name,
            movementPattern: x.movementPattern,
            equipment: x.equipment,
            difficulty: x.difficulty,
            primaryMuscles: x.primaryMuscles,
            secondaryMuscles: x.secondaryMuscles,
            incrementKg: x.incrementKg,
            orderIndex: x.orderIndex,
            supersetGroup: null,
            plannedExerciseId: x.plannedExerciseId,
            targets: x.targets,
            lastPerformance: x.lastPerformance,
            sets: const [],
          ),
    ].map((x) => x.copyWith(clientExerciseId: x.id)).toList();
    final session = WorkoutSession(
      id: clientSessionId,
      clientSessionId: clientSessionId,
      status: SessionStatus.active,
      programId: fromDay ? day.programId : null,
      programDayId: fromDay ? day.programDayId : null,
      name: fromDay ? (day.sessionName ?? 'Session') : 'Session',
      startedAt: startedAt,
      completedAt: null,
      durationSeconds: null,
      notes: null,
      exercises: seeded,
      summary: null,
    );
    await _db.transaction(() async {
      await _db.into(_db.localSessions).insert(
            LocalSessionsCompanion.insert(
              clientSessionId: clientSessionId,
              status: session.status.wire,
              name: session.name,
              programId: Value(session.programId),
              programDayId: Value(session.programDayId),
              startedAt: startedAt,
              snapshotJson: jsonEncode(session.toJson()),
              updatedAt: startedAt,
            ),
          );
      for (final x in seeded) {
        await _db
            .into(_db.localSessionExercises)
            .insert(_exerciseRow(x, clientSessionId));
      }
      await _sync.enqueue(
        kind: SyncKind.start,
        clientSessionId: clientSessionId,
        payload: StartSessionRequest(
          clientSessionId: clientSessionId,
          programDayId: session.programDayId,
          startedAt: startedAt,
          exercises: [
            for (final x in seeded)
              SeededExercise(
                clientExerciseId: x.clientExerciseId,
                exerciseId: x.exerciseId,
                plannedExerciseId: x.plannedExerciseId,
                orderIndex: x.orderIndex,
              ),
          ],
        ).toJson(),
      );
    });
    _sync.kick();
    return (await _load(clientSessionId))!;
  }

  LocalSessionExercisesCompanion _exerciseRow(
    SessionExercise x,
    String clientSessionId,
  ) =>
      LocalSessionExercisesCompanion.insert(
        clientExerciseId: x.clientExerciseId,
        clientSessionId: clientSessionId,
        exerciseId: x.exerciseId,
        plannedExerciseId: Value(x.plannedExerciseId),
        orderIndex: x.orderIndex,
        supersetGroup: Value(x.supersetGroup),
        exerciseJson: jsonEncode(x.copyWith(sets: const []).toJson()),
      );

  Future<void> _touch(String clientSessionId) => (_db.update(_db.localSessions)
        ..where((t) => t.clientSessionId.equals(clientSessionId)))
      .write(LocalSessionsCompanion(updatedAt: Value(_stamp())));

  @override
  Future<void> logSet(String clientSessionId, LogSetInput set) async {
    await _db.transaction(() async {
      await _db.into(_db.localSetLogs).insert(
            LocalSetLogsCompanion.insert(
              clientSetId: set.clientSetId,
              clientExerciseId: set.clientExerciseId,
              setIndex: set.setIndex,
              setType: set.setType.wire,
              weightKg: Value(set.weightKg),
              reps: set.reps,
              rir: Value(set.rir),
              loggedAt: set.loggedAt,
              plannedSetId: Value(set.plannedSetId),
            ),
            mode: InsertMode.insertOrReplace,
          );
      await _sync.enqueueSet(clientSessionId, set);
      await _touch(clientSessionId);
    });
    _sync.kick();
  }

  @override
  Future<void> updateSet(
    String clientSessionId,
    String clientSetId, {
    SetType? setType,
    double? weightKg,
    bool weightCleared = false,
    int? reps,
    int? rir,
    bool rirCleared = false,
  }) async {
    await _db.transaction(() async {
      await (_db.update(_db.localSetLogs)
            ..where((t) => t.clientSetId.equals(clientSetId)))
          .write(
        LocalSetLogsCompanion(
          setType: setType == null ? const Value.absent() : Value(setType.wire),
          weightKg: weightCleared
              ? const Value(null)
              : weightKg == null
                  ? const Value.absent()
                  : Value(weightKg),
          reps: reps == null ? const Value.absent() : Value(reps),
          rir: rirCleared
              ? const Value(null)
              : rir == null
                  ? const Value.absent()
                  : Value(rir),
        ),
      );
      final row = await (_db.select(_db.localSetLogs)
            ..where((t) => t.clientSetId.equals(clientSetId)))
          .getSingle();
      // Not on the server yet: amend the pending batch instead of patching
      // a row that does not exist there.
      final folded = await _sync.amendPendingSet(clientSessionId, row);
      if (!folded) {
        await _sync.enqueue(
          kind: SyncKind.patchSet,
          clientSessionId: clientSessionId,
          clientKey: clientSetId,
          payload: PatchSetRequest(
            setType: setType,
            weightKg: weightKg,
            weightCleared: weightCleared,
            reps: reps,
            rir: rir,
            rirCleared: rirCleared,
          ).toJson(),
        );
      }
      await _touch(clientSessionId);
    });
    _sync.kick();
  }

  @override
  Future<void> deleteSet(String clientSessionId, String clientSetId) async {
    await _db.transaction(() async {
      await (_db.update(_db.localSetLogs)
            ..where((t) => t.clientSetId.equals(clientSetId)))
          .write(const LocalSetLogsCompanion(deleted: Value(true)));
      final dropped = await _sync.dropPendingSet(clientSessionId, clientSetId);
      if (!dropped) {
        await _sync.enqueue(
          kind: SyncKind.deleteSet,
          clientSessionId: clientSessionId,
          clientKey: clientSetId,
          payload: const <String, dynamic>{},
        );
      }
      await _touch(clientSessionId);
    });
    _sync.kick();
  }

  static SessionExercise _fromSummary(
    ExerciseSummary e, {
    required String clientExerciseId,
    required int orderIndex,
    String? plannedExerciseId,
    int? supersetGroup,
  }) =>
      SessionExercise(
        id: clientExerciseId,
        clientExerciseId: clientExerciseId,
        exerciseId: e.id,
        slug: e.slug,
        name: e.name,
        movementPattern: e.movementPattern,
        equipment: e.equipment,
        difficulty: e.difficulty,
        primaryMuscles: e.primaryMuscles,
        secondaryMuscles: const [],
        // The catalogue's increment arrives with the server's answer; until
        // then the smallest common plate jump.
        incrementKg: 2.5,
        orderIndex: orderIndex,
        supersetGroup: supersetGroup,
        plannedExerciseId: plannedExerciseId,
        targets: const [],
        lastPerformance: null,
        sets: const [],
      );

  @override
  Future<String> addExercise(
    String clientSessionId,
    ExerciseSummary exercise, {
    String? plannedExerciseId,
    int? orderIndex,
    int? supersetGroup,
  }) async {
    final clientExerciseId = _uuid.v4();
    await _db.transaction(() async {
      final existing = await _liveExercises(clientSessionId);
      final at = orderIndex == null
          ? existing.length
          : orderIndex.clamp(0, existing.length);
      final x = _fromSummary(
        exercise,
        clientExerciseId: clientExerciseId,
        orderIndex: at,
        plannedExerciseId: plannedExerciseId,
        supersetGroup: supersetGroup,
      );
      await _db
          .into(_db.localSessionExercises)
          .insert(_exerciseRow(x, clientSessionId));
      await _renumber(clientSessionId, insertAt: (clientExerciseId, at));
      await _sync.enqueue(
        kind: SyncKind.addExercise,
        clientSessionId: clientSessionId,
        clientKey: clientExerciseId,
        payload: AddSessionExerciseRequest(
          clientExerciseId: clientExerciseId,
          exerciseId: exercise.id,
          plannedExerciseId: plannedExerciseId,
          orderIndex: at,
          supersetGroup: supersetGroup,
        ).toJson(),
      );
      await _touch(clientSessionId);
    });
    _sync.kick();
    return clientExerciseId;
  }

  Future<List<LocalSessionExercise>> _liveExercises(String clientSessionId) =>
      (_db.select(_db.localSessionExercises)
            ..where(
              (t) =>
                  t.clientSessionId.equals(clientSessionId) &
                  t.removed.equals(false),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]))
          .get();

  /// Keep order indices dense after an insert, move or removal.
  Future<void> _renumber(
    String clientSessionId, {
    (String, int)? insertAt,
    (String, int)? moveTo,
  }) async {
    final rows = await _liveExercises(clientSessionId);
    final ids = rows.map((r) => r.clientExerciseId).toList();
    final target = insertAt ?? moveTo;
    if (target != null) {
      ids.remove(target.$1);
      ids.insert(target.$2.clamp(0, ids.length), target.$1);
    }
    for (var i = 0; i < ids.length; i++) {
      await (_db.update(_db.localSessionExercises)
            ..where((t) => t.clientExerciseId.equals(ids[i])))
          .write(LocalSessionExercisesCompanion(orderIndex: Value(i)));
    }
  }

  @override
  Future<void> updateExercise(
    String clientSessionId,
    String clientExerciseId, {
    int? orderIndex,
    int? supersetGroup,
    bool supersetCleared = false,
    ExerciseSummary? replaceWith,
    bool removed = false,
  }) async {
    await _db.transaction(() async {
      final row = await (_db.select(_db.localSessionExercises)
            ..where((t) => t.clientExerciseId.equals(clientExerciseId)))
          .getSingle();
      var meta = SessionExercise.fromJson(
        jsonDecode(row.exerciseJson) as Map<String, dynamic>,
      );
      if (replaceWith != null) {
        // Same row, new movement; the plan's targets stay, no load carries over.
        meta = _fromSummary(
          replaceWith,
          clientExerciseId: clientExerciseId,
          orderIndex: row.orderIndex,
          plannedExerciseId: row.plannedExerciseId,
          supersetGroup: row.supersetGroup,
        ).copyWith(targets: meta.targets, id: meta.id);
      }
      await (_db.update(_db.localSessionExercises)
            ..where((t) => t.clientExerciseId.equals(clientExerciseId)))
          .write(
        LocalSessionExercisesCompanion(
          exerciseId: replaceWith == null
              ? const Value.absent()
              : Value(replaceWith.id),
          exerciseJson:
              Value(jsonEncode(meta.copyWith(sets: const []).toJson())),
          supersetGroup: supersetCleared
              ? const Value(null)
              : supersetGroup == null
                  ? const Value.absent()
                  : Value(supersetGroup),
          removed: removed ? const Value(true) : const Value.absent(),
        ),
      );
      if (orderIndex != null) {
        await _renumber(
          clientSessionId,
          moveTo: (clientExerciseId, orderIndex),
        );
      } else if (removed) {
        await _renumber(clientSessionId);
      }
      final folded = await _sync.amendPendingExercise(
        clientSessionId,
        clientExerciseId,
        orderIndex: orderIndex,
        supersetGroup: supersetGroup,
        supersetCleared: supersetCleared,
        exerciseId: replaceWith?.id,
        removed: removed,
      );
      if (!folded) {
        await _sync.enqueue(
          kind: SyncKind.patchExercise,
          clientSessionId: clientSessionId,
          clientKey: clientExerciseId,
          payload: PatchSessionExerciseRequest(
            orderIndex: orderIndex,
            supersetGroup: supersetGroup,
            supersetCleared: supersetCleared,
            exerciseId: replaceWith?.id,
            removed: removed,
          ).toJson(),
        );
      }
      await _touch(clientSessionId);
    });
    _sync.kick();
  }

  Future<void> _finish(
    String clientSessionId,
    SessionStatus status, {
    String? notes,
  }) async {
    final at = _stamp();
    await _db.transaction(() async {
      await (_db.update(_db.localSessions)
            ..where((t) => t.clientSessionId.equals(clientSessionId)))
          .write(
        LocalSessionsCompanion(
          status: Value(status.wire),
          completedAt: Value(at),
          notes: Value(notes),
          updatedAt: Value(at),
        ),
      );
      await _sync.enqueue(
        kind: status == SessionStatus.completed
            ? SyncKind.complete
            : SyncKind.abandon,
        clientSessionId: clientSessionId,
        payload: status == SessionStatus.completed
            ? CompleteSessionRequest(completedAt: at, notes: notes).toJson()
            : const <String, dynamic>{},
      );
    });
    _sync.kick();
  }

  @override
  Future<void> complete(String clientSessionId, {String? notes}) =>
      _finish(clientSessionId, SessionStatus.completed, notes: notes);

  @override
  Future<void> abandon(String clientSessionId) =>
      _finish(clientSessionId, SessionStatus.abandoned);

  /* ------------------------------------------------------------ sync -- */

  @override
  Stream<SyncStatus> watchSync() => _sync.watchStatus();

  @override
  Future<SyncStatus> syncStatus() => _sync.status();

  @override
  Future<void> sync() => _sync.drain();

  @override
  Future<void> retryParked() => _sync.retryParked();

  @override
  Future<void> clearLocal() => _db.clearAll();
}
