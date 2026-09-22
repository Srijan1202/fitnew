import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

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
///
/// The engine wakes itself (Phase 6.6 Gate 7): a backoff or an unreachable
/// server schedules the next attempt, so a queue left behind by one failed
/// request drains without the user touching Retry. Before, "the next kick
/// resumes" meant the next tap — after a session's last request there is
/// none, and the S24 showed "1 not synced" until Retry.
class SyncEngine {
  SyncEngine(
    this._db,
    this._api, {
    DateTime Function()? now,
    this.maxAttempts = 5,
    this.baseDelay = const Duration(milliseconds: 300),
    this.offlineRetry = const Duration(seconds: 15),
    this.offlineRetryMax = const Duration(minutes: 2),
    this.wakeItself = true,
  }) : _now = now ?? DateTime.now;

  /// Off only where a test drives every drain by hand (widget tests run the
  /// screens offline on a fake clock and must end with no timers pending).
  final bool wakeItself;

  final AppDatabase _db;
  final WorkoutApi _api;
  final DateTime Function() _now;
  final int maxAttempts;
  final Duration baseDelay;

  /// First retry after the server did not answer; doubles per miss up to
  /// [offlineRetryMax]. Connectivity events and app resume still drain at
  /// once — this covers a server that comes back while the Wi-Fi never
  /// dropped (the PC's API restarted).
  final Duration offlineRetry;
  final Duration offlineRetryMax;

  Timer? _wake;
  int _offlineMisses = 0;
  bool _disposed = false;

  /// The logSets batch on the wire, and its set ids. A batch in flight is
  /// sealed: sets logged, edited or removed meanwhile go to their own queue
  /// entries (behind it), because the server has already been sent this
  /// payload. Folding into it lost edits and left removed sets on the
  /// server, where a re-logged set at the same position then hit the
  /// server's one-live-set-per-position rule (409) forever.
  int? _sealedBatchId;
  Set<String> _sealedSetIds = const {};

  /// When the engine will next drain by itself, if it is going to.
  @visibleForTesting
  bool get hasScheduledWake => _wake?.isActive ?? false;

  /// Stop waking. The queue stays on disk; the next engine drains it.
  void dispose() {
    _disposed = true;
    _wake?.cancel();
    _wake = null;
  }

  void _scheduleWake(Duration delay) {
    if (_disposed || !wakeItself) return;
    _wake?.cancel();
    _wake = Timer(delay < Duration.zero ? Duration.zero : delay, kick);
  }

  bool _draining = false;
  bool _again = false;
  bool _sentAny = false;
  Completer<void>? _done;
  final _drained = StreamController<void>.broadcast();

  /// Fires after a drain in which at least one mutation reached the
  /// server — the moment the server's view of the user (today, volume,
  /// recommendations) may have moved.
  Stream<void> get drained => _drained.stream;

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
                  t.parked.equals(false) &
                  _notSealed(t),
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

  Expression<bool> _notSealed($SyncQueueTable t) {
    final sealed = _sealedBatchId;
    return sealed == null ? const Constant(true) : t.id.equals(sealed).not();
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
    // On the wire right now: the server will have it, so it must be
    // deleted there, after the batch lands.
    if (_sealedSetIds.contains(clientSetId)) return false;
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
                  t.kind.equals(SyncKind.logSets.name) &
                  _notSealed(t),
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
    _sentAny = false;
    _wake?.cancel();
    _Stop? stop;
    try {
      // A kick that lands while this drain runs sets [_again]. It is checked
      // again after the wake is scheduled — that await is a window in which
      // a kick would otherwise be lost and its entry stranded until the next
      // tap (found by automatic_sync_test.dart). No await may follow the
      // final check before [_draining] is cleared.
      do {
        do {
          _again = false;
          stop = await _loop();
        } while (_again);
        await _scheduleNext(stop);
      } while (_again);
    } finally {
      _draining = false;
      _done!.complete();
      if (_sentAny && !_drained.isClosed) _drained.add(null);
    }
  }

  /// After a drain that left work behind: wake when it can make progress.
  /// Unreachable server → back off (15 s, doubling to 2 min); an entry in
  /// backoff → when it is due; signed out or nothing left → stay asleep.
  Future<void> _scheduleNext(_Stop? stop) async {
    if (stop != null) {
      if (!stop.retry) return;
      final factor = 1 << (_offlineMisses < 4 ? _offlineMisses : 4);
      final delay = offlineRetry * factor;
      _offlineMisses++;
      _scheduleWake(delay > offlineRetryMax ? offlineRetryMax : delay);
      return;
    }
    _offlineMisses = 0;
    final next = await (_db.select(_db.syncQueue)
          ..where((t) => t.parked.equals(false) & t.nextAttemptAt.isNotNull())
          ..orderBy([(t) => OrderingTerm.asc(t.nextAttemptAt)])
          ..limit(1))
        .getSingleOrNull();
    if (next == null) return;
    _scheduleWake(DateTime.parse(next.nextAttemptAt!).difference(_now()));
  }

  /// Sends until the queue is empty, blocked, or the server is unreachable;
  /// answers the stop, if that is why it ended.
  Future<_Stop?> _loop() async {
    while (true) {
      // Pick the next entry and, for a set batch, seal it — in ONE
      // transaction. The repository edits batches inside its own
      // transactions, and drift runs transactions one at a time, so an edit
      // either lands before this read (and is sent) or sees the seal (and is
      // queued behind). Sealing after the read let an edit fold into a
      // payload already read for sending, then be trimmed away on landing.
      final entry = await _db.transaction(() async {
        final now = _now().toUtc().toIso8601String();
        final next = await (_db.select(_db.syncQueue)
              ..where(
                (t) =>
                    t.parked.equals(false) &
                    (t.nextAttemptAt.isNull() |
                        t.nextAttemptAt.isSmallerOrEqualValue(now)),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.id)])
              ..limit(1))
            .getSingleOrNull();
        if (next == null) return null;
        // An entry ahead of it is waiting on backoff: keep order, stop here.
        final blocker = await (_db.select(_db.syncQueue)
              ..where(
                (t) =>
                    t.parked.equals(false) & t.id.isSmallerThanValue(next.id),
              )
              ..limit(1))
            .getSingleOrNull();
        if (blocker != null) return null;
        if (next.kind == SyncKind.logSets.name) {
          _sealedBatchId = next.id;
          _sealedSetIds = {
            for (final x in LogSetsRequest.fromJson(
              jsonDecode(next.payloadJson) as Map<String, dynamic>,
            ).sets)
              x.clientSetId,
          };
        }
        return next;
      });
      if (entry == null) return null;

      final _Outcome outcome;
      try {
        outcome = await _send(entry);
      } finally {
        _sealedBatchId = null;
        _sealedSetIds = const {};
      }
      switch (outcome) {
        case _Sent():
          _sentAny = true;
          _offlineMisses = 0;
          continue;
        case _Stop():
          return outcome;
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
          return null; // wait out the backoff; _scheduleNext wakes us
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
        // Sealed by _loop for the whole round trip (see there).
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
        // The server did not answer: nothing is charged, try again later.
        Offline() => const _Stop(retry: true),
        // Signed out: the next sign-in drains; retrying alone cannot help.
        Unauthenticated() => const _Stop(retry: false),
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
  const _Stop({required this.retry});

  /// Whether waiting and trying again on our own can help.
  final bool retry;
}

class _Failed extends _Outcome {
  const _Failed(this.message);
  final String message;
}
