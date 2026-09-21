import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../domain/entities/workout.dart';
import '../domain/repositories/workout_repository.dart';
import 'workout_api.dart';

enum SyncKind {
  start,
  logSets,
  patchSet,
  deleteSet,
  addExercise,
  patchExercise,
  complete,
  abandon,
}

/// Drains the sync queue (§33): oldest first, one at a time, each request
/// idempotent on the server, so being interrupted anywhere — app killed,
/// signal lost — costs nothing but a retry.
///
/// Failure policy:
///  - offline / unauthenticated: stop; nothing is charged to the entry.
///    Connectivity or the next sign-in drains again.
///  - a completed-elsewhere conflict: resend once with `merge: true`.
///  - anything else: exponential backoff, five attempts, then PARKED with
///    the error, surfaced as "n changes not synced · Retry". Never dropped.
class SyncEngine {
  SyncEngine(
    this._db,
    this._api, {
    DateTime Function()? now,
    this.maxAttempts = 5,
    this.baseDelay = const Duration(milliseconds: 300),
  }) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final WorkoutApi _api;
  final DateTime Function() _now;
  final int maxAttempts;
  final Duration baseDelay;

  bool _draining = false;
  bool _again = false;
  Completer<void>? _done;

  /* ----------------------------------------------------------- queue -- */

  Future<void> enqueue({
    required SyncKind kind,
    required String clientSessionId,
    String? clientKey,
    required Map<String, dynamic> payload,
  }) =>
      _db.into(_db.syncQueue).insert(
            SyncQueueCompanion.insert(
              kind: kind.name,
              clientSessionId: clientSessionId,
              clientKey: Value(clientKey),
              payloadJson: jsonEncode(payload),
              createdAt: _now().toUtc().toIso8601String(),
            ),
          );

  Future<SyncQueueData?> _pendingBatch(String clientSessionId) =>
      (_db.select(_db.syncQueue)
            ..where(
              (t) =>
                  t.clientSessionId.equals(clientSessionId) &
                  t.kind.equals(SyncKind.logSets.name) &
                  t.parked.equals(false),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.id)])
            ..limit(1))
          .getSingleOrNull();

  Future<void> _writePayload(int id, Map<String, dynamic> payload) =>
      (_db.update(_db.syncQueue)..where((t) => t.id.equals(id)))
          .write(SyncQueueCompanion(payloadJson: Value(jsonEncode(payload))));

  /// Append a set to the session's pending batch (or open one). Batching
  /// keeps a whole workout to a handful of requests.
  Future<void> enqueueSet(String clientSessionId, LogSetInput set) async {
    final batch = await _pendingBatch(clientSessionId);
    if (batch == null || batch.attempts > 0) {
      await enqueue(
        kind: SyncKind.logSets,
        clientSessionId: clientSessionId,
        payload: LogSetsRequest(sets: [set]).toJson(),
      );
      return;
    }
    final request = LogSetsRequest.fromJson(
      jsonDecode(batch.payloadJson) as Map<String, dynamic>,
    );
    await _writePayload(
      batch.id,
      request.copyWith(sets: [...request.sets, set]).toJson(),
    );
  }

  /// A set that has not reached the server is edited in its batch. True
  /// when that happened; false when the set is already on the server.
  Future<bool> amendPendingSet(String clientSessionId, LocalSetLog row) async {
    if (row.serverId != null) return false;
    for (final batch in await _batches(clientSessionId)) {
      final request = LogSetsRequest.fromJson(
        jsonDecode(batch.payloadJson) as Map<String, dynamic>,
      );
      final i =
          request.sets.indexWhere((s) => s.clientSetId == row.clientSetId);
      if (i < 0) continue;
      final next = [...request.sets];
      next[i] = next[i].copyWith(
        setType: SetType.values.firstWhere((t) => t.wire == row.setType),
        weightKg: row.weightKg,
        reps: row.reps,
        rir: row.rir,
      );
      await _writePayload(batch.id, request.copyWith(sets: next).toJson());
      return true;
    }
    // Sent, answer not yet reconciled: a patch will resolve the id later.
    return false;
  }

  /// A set that has not reached the server is simply not sent.
  Future<bool> dropPendingSet(
    String clientSessionId,
    String clientSetId,
  ) async {
    for (final batch in await _batches(clientSessionId)) {
      final request = LogSetsRequest.fromJson(
        jsonDecode(batch.payloadJson) as Map<String, dynamic>,
      );
      if (!request.sets.any((s) => s.clientSetId == clientSetId)) continue;
      final next =
          request.sets.where((s) => s.clientSetId != clientSetId).toList();
      if (next.isEmpty) {
        await (_db.delete(_db.syncQueue)..where((t) => t.id.equals(batch.id)))
            .go();
      } else {
        await _writePayload(batch.id, request.copyWith(sets: next).toJson());
      }
      return true;
    }
    final row = await (_db.select(_db.localSetLogs)
          ..where((t) => t.clientSetId.equals(clientSetId)))
        .getSingleOrNull();
    // Never sent and not in a batch: nothing for the server to delete.
    return row != null && row.serverId == null;
  }

  Future<List<SyncQueueData>> _batches(String clientSessionId) =>
      (_db.select(_db.syncQueue)
            ..where(
              (t) =>
                  t.clientSessionId.equals(clientSessionId) &
                  t.kind.equals(SyncKind.logSets.name),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .get();

  /// An exercise whose `addExercise` is still queued is edited there.
  Future<bool> amendPendingExercise(
    String clientSessionId,
    String clientExerciseId, {
    int? orderIndex,
    int? supersetGroup,
    bool supersetCleared = false,
    String? exerciseId,
    bool removed = false,
  }) async {
    final pending = await (_db.select(_db.syncQueue)
          ..where(
            (t) =>
                t.clientKey.equals(clientExerciseId) &
                t.kind.equals(SyncKind.addExercise.name),
          )
          ..limit(1))
        .getSingleOrNull();
    if (pending == null) return false;
    if (removed) {
      await (_db.delete(_db.syncQueue)..where((t) => t.id.equals(pending.id)))
          .go();
      return true;
    }
    final request = AddSessionExerciseRequest.fromJson(
      jsonDecode(pending.payloadJson) as Map<String, dynamic>,
    );
    await _writePayload(
      pending.id,
      request
          .copyWith(
            orderIndex: orderIndex ?? request.orderIndex,
            supersetGroup: supersetCleared
                ? null
                : (supersetGroup ?? request.supersetGroup),
            exerciseId: exerciseId ?? request.exerciseId,
          )
          .toJson(),
    );
    return true;
  }

  /* ---------------------------------------------------------- status -- */

  Future<SyncStatus> status() async {
    final rows = await _db.select(_db.syncQueue).get();
    final parked = rows.where((r) => r.parked).toList();
    return SyncStatus(
      pending: rows.length - parked.length,
      parked: parked.length,
      lastError: parked.isEmpty ? null : parked.last.lastError,
    );
  }

  Stream<SyncStatus> watchStatus() async* {
    yield await status();
    await for (final _
        in _db.tableUpdates(TableUpdateQuery.onTable(_db.syncQueue))) {
      yield await status();
    }
  }

  Future<void> retryParked() async {
    await (_db.update(_db.syncQueue)..where((t) => t.parked.equals(true)))
        .write(
      const SyncQueueCompanion(
        parked: Value(false),
        attempts: Value(0),
        nextAttemptAt: Value(null),
      ),
    );
    await drain();
  }

  /* ----------------------------------------------------------- drain -- */

  /// Fire and forget: the caller is on the tap path.
  void kick() {
    unawaited(drain());
  }

  Future<void> drain() {
    if (_draining) {
      _again = true;
      return _done!.future;
    }
    _draining = true;
    _done = Completer<void>();
    unawaited(_run());
    return _done!.future;
  }

  Future<void> _run() async {
    try {
      do {
        _again = false;
        await _loop();
      } while (_again);
    } finally {
      _draining = false;
      _done!.complete();
    }
  }

  Future<void> _loop() async {
    while (true) {
      final now = _now().toUtc().toIso8601String();
      final entry = await (_db.select(_db.syncQueue)
            ..where(
              (t) =>
                  t.parked.equals(false) &
                  (t.nextAttemptAt.isNull() |
                      t.nextAttemptAt.isSmallerOrEqualValue(now)),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.id)])
            ..limit(1))
          .getSingleOrNull();
      if (entry == null) return;
      // An entry ahead of it is waiting on backoff: keep order, stop here.
      final blocker = await (_db.select(_db.syncQueue)
            ..where(
              (t) => t.parked.equals(false) & t.id.isSmallerThanValue(entry.id),
            )
            ..limit(1))
          .getSingleOrNull();
      if (blocker != null) return;

      final outcome = await _send(entry);
      switch (outcome) {
        case _Sent():
          continue;
        case _Stop():
          return;
        case _Failed(:final message):
          final attempts = entry.attempts + 1;
          final park = attempts >= maxAttempts;
          final delay = baseDelay * (1 << (attempts - 1));
          await (_db.update(_db.syncQueue)..where((t) => t.id.equals(entry.id)))
              .write(
            SyncQueueCompanion(
              attempts: Value(attempts),
              lastError: Value(message),
              parked: Value(park),
              nextAttemptAt: Value(
                park ? null : _now().add(delay).toUtc().toIso8601String(),
              ),
            ),
          );
          if (park) continue; // the next entry may be independent
          return; // wait out the backoff; the next kick resumes
      }
    }
  }

  Future<String?> _serverSessionId(String clientSessionId) async {
    final row = await (_db.select(_db.localSessions)
          ..where((t) => t.clientSessionId.equals(clientSessionId)))
        .getSingleOrNull();
    return row?.serverId;
  }

  Future<_Outcome> _send(SyncQueueData entry) async {
    final kind = SyncKind.values.byName(entry.kind);
    final payload = jsonDecode(entry.payloadJson) as Map<String, dynamic>;
    if (kind == SyncKind.start) {
      final result = await _api.start(StartSessionRequest.fromJson(payload));
      return _settle(entry, result);
    }
    final serverId = await _serverSessionId(entry.clientSessionId);
    if (serverId == null) {
      // The start request ahead of this one has not succeeded.
      return const _Failed('The session has not reached the server yet.');
    }
    switch (kind) {
      case SyncKind.start:
        throw StateError('unreachable');
      case SyncKind.logSets:
        final request = LogSetsRequest.fromJson(payload);
        if (request.sets.isEmpty) {
          await (_db.delete(_db.syncQueue)..where((t) => t.id.equals(entry.id)))
              .go();
          return const _Sent();
        }
        var result = await _api.logSets(serverId, request);
        final failure = result is Err<WorkoutSession> ? result.failure : null;
        if (failure is Conflict &&
            failure.issue == SessionStatus.completed.wire &&
            !request.merge) {
          // Completed on another device (§33): merge our sets into it.
          result = await _api.logSets(serverId, request.copyWith(merge: true));
        }
        return _settleBatch(entry, request, result);
      case SyncKind.patchSet:
      case SyncKind.deleteSet:
        final row = await (_db.select(_db.localSetLogs)
              ..where((t) => t.clientSetId.equals(entry.clientKey!)))
            .getSingleOrNull();
        if (row?.serverId == null) {
          return const _Failed('The set has not reached the server yet.');
        }
        final result = kind == SyncKind.patchSet
            ? await _api.patchSet(
                serverId,
                row!.serverId!,
                PatchSetRequest.fromJson(payload),
              )
            : await _api.deleteSet(serverId, row!.serverId!);
        return _settle(entry, result);
      case SyncKind.addExercise:
        return _settle(
          entry,
          await _api.addExercise(
            serverId,
            AddSessionExerciseRequest.fromJson(payload),
          ),
        );
      case SyncKind.patchExercise:
        final row = await (_db.select(_db.localSessionExercises)
              ..where((t) => t.clientExerciseId.equals(entry.clientKey!)))
            .getSingleOrNull();
        if (row?.serverId == null) {
          return const _Failed('The exercise has not reached the server yet.');
        }
        return _settle(
          entry,
          await _api.patchExercise(
            serverId,
            row!.serverId!,
            PatchSessionExerciseRequest.fromJson(payload),
          ),
        );
      case SyncKind.complete:
        return _settle(
          entry,
          await _api.complete(
            serverId,
            CompleteSessionRequest.fromJson(payload),
          ),
        );
      case SyncKind.abandon:
        return _settle(entry, await _api.abandon(serverId));
    }
  }

  Future<_Outcome> _settle(
    SyncQueueData entry,
    Result<WorkoutSession> result,
  ) async {
    switch (result) {
      case Ok<WorkoutSession>(:final value):
        await reconcile(value);
        await (_db.delete(_db.syncQueue)..where((t) => t.id.equals(entry.id)))
            .go();
        return const _Sent();
      case Err<WorkoutSession>(:final failure):
        return _fail(failure);
    }
  }

  /// A batch may have grown while it was in flight: keep what was not sent.
  Future<_Outcome> _settleBatch(
    SyncQueueData entry,
    LogSetsRequest sent,
    Result<WorkoutSession> result,
  ) async {
    switch (result) {
      case Ok<WorkoutSession>(:final value):
        await reconcile(value);
        final current = await (_db.select(_db.syncQueue)
              ..where((t) => t.id.equals(entry.id)))
            .getSingleOrNull();
        if (current != null) {
          final sentIds = sent.sets.map((s) => s.clientSetId).toSet();
          final request = LogSetsRequest.fromJson(
            jsonDecode(current.payloadJson) as Map<String, dynamic>,
          );
          final rest = request.sets
              .where((s) => !sentIds.contains(s.clientSetId))
              .toList();
          if (rest.isEmpty) {
            await (_db.delete(_db.syncQueue)
                  ..where((t) => t.id.equals(entry.id)))
                .go();
          } else {
            await _writePayload(
              entry.id,
              request.copyWith(sets: rest).toJson(),
            );
          }
        }
        return const _Sent();
      case Err<WorkoutSession>(:final failure):
        return _fail(failure);
    }
  }

  _Outcome _fail(Failure failure) => switch (failure) {
        Offline() || Unauthenticated() => const _Stop(),
        _ => _Failed(failure.message),
      };

  /* ------------------------------------------------------- reconcile -- */

  /// Fold the server's answer into the local rows: server ids, records,
  /// status and the snapshot (targets, last performance, summary). Adds
  /// what the phone does not have; never deletes what it has.
  Future<void> reconcile(WorkoutSession s) => _db.transaction(() async {
        final local = await (_db.select(_db.localSessions)
              ..where((t) => t.clientSessionId.equals(s.clientSessionId)))
            .getSingleOrNull();
        if (local == null) return;
        // A phone-side completion/abandon that has not synced yet wins over
        // the server's "active".
        final localStatus =
            SessionStatus.values.firstWhere((t) => t.wire == local.status);
        final keepLocalStatus = localStatus != SessionStatus.active &&
            s.status == SessionStatus.active;
        await (_db.update(_db.localSessions)
              ..where((t) => t.clientSessionId.equals(s.clientSessionId)))
            .write(
          LocalSessionsCompanion(
            serverId: Value(s.id),
            status:
                keepLocalStatus ? const Value.absent() : Value(s.status.wire),
            completedAt:
                keepLocalStatus ? const Value.absent() : Value(s.completedAt),
            notes: Value(s.notes ?? local.notes),
            snapshotJson:
                Value(jsonEncode(s.copyWith(exercises: const []).toJson())),
            updatedAt: Value(_now().toUtc().toIso8601String()),
          ),
        );
        for (final x in s.exercises) {
          final row = await (_db.select(_db.localSessionExercises)
                ..where((t) => t.clientExerciseId.equals(x.clientExerciseId)))
              .getSingleOrNull();
          final meta = jsonEncode(x.copyWith(sets: const []).toJson());
          if (row == null) {
            await _db.into(_db.localSessionExercises).insert(
                  LocalSessionExercisesCompanion.insert(
                    clientExerciseId: x.clientExerciseId,
                    clientSessionId: s.clientSessionId,
                    serverId: Value(x.id),
                    exerciseId: x.exerciseId,
                    plannedExerciseId: Value(x.plannedExerciseId),
                    orderIndex: x.orderIndex,
                    supersetGroup: Value(x.supersetGroup),
                    exerciseJson: meta,
                  ),
                );
          } else {
            await (_db.update(_db.localSessionExercises)
                  ..where((t) => t.clientExerciseId.equals(x.clientExerciseId)))
                .write(
              LocalSessionExercisesCompanion(
                serverId: Value(x.id),
                exerciseJson: Value(meta),
              ),
            );
          }
          for (final set in x.sets) {
            final existing = await (_db.select(_db.localSetLogs)
                  ..where((t) => t.clientSetId.equals(set.clientSetId)))
                .getSingleOrNull();
            if (existing == null) {
              await _db.into(_db.localSetLogs).insert(
                    LocalSetLogsCompanion.insert(
                      clientSetId: set.clientSetId,
                      clientExerciseId: x.clientExerciseId,
                      serverId: Value(set.id),
                      setIndex: set.setIndex,
                      setType: set.setType.wire,
                      weightKg: Value(set.weightKg),
                      reps: set.reps,
                      rir: Value(set.rir),
                      loggedAt: set.loggedAt,
                      plannedSetId: Value(set.plannedSetId),
                      isPr: Value(set.isPr),
                    ),
                  );
            } else {
              await (_db.update(_db.localSetLogs)
                    ..where((t) => t.clientSetId.equals(set.clientSetId)))
                  .write(
                LocalSetLogsCompanion(
                  serverId: Value(set.id),
                  isPr: Value(set.isPr),
                ),
              );
            }
          }
        }
      });
}

sealed class _Outcome {
  const _Outcome();
}

class _Sent extends _Outcome {
  const _Sent();
}

class _Stop extends _Outcome {
  const _Stop();
}

class _Failed extends _Outcome {
  const _Failed(this.message);
  final String message;
}
