import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../../core/db/app_database.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import 'run_store.dart';
import 'running_api.dart';

enum RunSyncKind { create, patch, delete }

/// The cache key of a run the server holds.
String runCacheKey(String id) => 'running.run.$id';

/// The cache key of the history's first page.
const String runListCacheKey = 'running.list';

/// Drains the run queue (beta 4.0, ADR-038) with ADR-006's policy, its own
/// queue (as Phase 8 did for food):
///
///  - FIFO; a run's edit or deletion never overtakes its upload.
///  - Offline, the server not answering or signed out: stop and charge
///    nothing; connectivity, app resume or its own wake drains again.
///  - A refusal a retry cannot change (422): parked with the server's words,
///    shown with Retry, never dropped. Anything else backs off
///    300 ms · 2ⁿ for five attempts, then parks.
///  - Every request is idempotent (clientRunId), so a replay costs nothing.
///
/// A confirmed upload caches the server's run and removes the phone's copy
/// (the row and its points) in one transaction.
class RunSyncEngine {
  RunSyncEngine(
    this._db,
    this._api, {
    DateTime Function()? now,
    this.maxAttempts = 5,
    this.baseDelay = const Duration(milliseconds: 300),
    this.offlineRetry = const Duration(seconds: 15),
    this.offlineRetryMax = const Duration(minutes: 2),
    this.wakeItself = true,
  })  : _now = now ?? DateTime.now,
        _store = RunStore(_db);

  final AppDatabase _db;
  final RunningApi _api;
  final RunStore _store;
  final DateTime Function() _now;
  final int maxAttempts;
  final Duration baseDelay;
  final Duration offlineRetry;
  final Duration offlineRetryMax;
  final bool wakeItself;

  Timer? _wake;
  int _offlineMisses = 0;
  bool _disposed = false;
  bool _draining = false;
  bool _again = false;
  Completer<void>? _done;
  String? _inFlight;
  final _drained = StreamController<void>.broadcast();

  /// Fires after a drain in which something reached the server.
  Stream<void> get drained => _drained.stream;

  bool isInFlight(String clientRunId) => _inFlight == clientRunId;

  @visibleForTesting
  bool get hasScheduledWake => _wake?.isActive ?? false;

  void dispose() {
    _disposed = true;
    _wake?.cancel();
    _drained.close();
  }

  /// Queues a mutation. Inside a transaction pass `wake: false` and [kick]
  /// after it commits (a drain must not start inside the transaction).
  Future<void> enqueue(
    RunSyncKind kind,
    String clientRunId,
    Map<String, dynamic> payload, {
    bool wake = true,
  }) async {
    await _db.into(_db.runSyncQueue).insert(
          RunSyncQueueCompanion.insert(
            kind: kind.name,
            clientRunId: clientRunId,
            payloadJson: jsonEncode(payload),
            createdAt: _now().toUtc().toIso8601String(),
          ),
        );
    if (wake) kick();
  }

  /// The waiting upload of a run, if it has not left yet.
  Future<RunSyncQueueData?> pendingCreate(String clientRunId) =>
      (_db.select(_db.runSyncQueue)
            ..where(
              (q) =>
                  q.clientRunId.equals(clientRunId) &
                  q.kind.equals(RunSyncKind.create.name),
            )
            ..limit(1))
          .getSingleOrNull();

  Future<void> replacePayload(int id, Map<String, dynamic> payload) =>
      (_db.update(_db.runSyncQueue)..where((q) => q.id.equals(id))).write(
        RunSyncQueueCompanion(payloadJson: Value(jsonEncode(payload))),
      );

  Future<void> remove(int id) =>
      (_db.delete(_db.runSyncQueue)..where((q) => q.id.equals(id))).go();

  /// Parked entries go back with a fresh budget (the user's Retry).
  Future<void> retryParked() async {
    await (_db.update(_db.runSyncQueue)..where((q) => q.parked.equals(true)))
        .write(
      const RunSyncQueueCompanion(
        parked: Value(false),
        attempts: Value(0),
        nextAttemptAt: Value(null),
      ),
    );
    kick();
  }

  /// Entries that gave up, with the server's last words.
  Stream<List<RunSyncQueueData>> watchParked() =>
      (_db.select(_db.runSyncQueue)..where((q) => q.parked.equals(true)))
          .watch();

  void kick() {
    if (_disposed) return;
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
    var sentAny = false;
    _wake?.cancel();
    try {
      do {
        _again = false;
        final (stop, sent) = await _loop();
        sentAny = sentAny || sent;
        await _scheduleNext(stop);
      } while (_again);
    } finally {
      _draining = false;
      _done!.complete();
      if (sentAny && !_drained.isClosed) _drained.add(null);
    }
  }

  void _scheduleWake(Duration delay) {
    if (_disposed || !wakeItself) return;
    _wake?.cancel();
    _wake = Timer(delay < Duration.zero ? Duration.zero : delay, kick);
  }

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
    final next = await (_db.select(_db.runSyncQueue)
          ..where((q) => q.parked.equals(false) & q.nextAttemptAt.isNotNull())
          ..orderBy([(q) => OrderingTerm.asc(q.nextAttemptAt)])
          ..limit(1))
        .getSingleOrNull();
    if (next == null) return;
    _scheduleWake(DateTime.parse(next.nextAttemptAt!).difference(_now()));
  }

  Future<(_Stop?, bool)> _loop() async {
    var sent = false;
    while (true) {
      final now = _now().toUtc().toIso8601String();
      final due = await (_db.select(_db.runSyncQueue)
            ..where(
              (q) =>
                  q.parked.equals(false) &
                  (q.nextAttemptAt.isNull() |
                      q.nextAttemptAt.isSmallerOrEqualValue(now)),
            )
            ..orderBy([(q) => OrderingTerm.asc(q.id)]))
          .get();
      RunSyncQueueData? entry;
      for (final next in due) {
        // An earlier entry for the same run (its upload, backing off) holds it.
        final blocker = await (_db.select(_db.runSyncQueue)
              ..where(
                (q) =>
                    q.clientRunId.equals(next.clientRunId) &
                    q.id.isSmallerThanValue(next.id),
              )
              ..limit(1))
            .getSingleOrNull();
        if (blocker == null) {
          entry = next;
          break;
        }
      }
      if (entry == null) return (null, sent);
      _inFlight = entry.clientRunId;
      final _Outcome outcome;
      try {
        outcome = await _send(entry);
      } finally {
        _inFlight = null;
      }
      switch (outcome) {
        case _Sent():
          sent = true;
          _offlineMisses = 0;
        case _Stop():
          return (outcome, sent);
        case _Park(:final message):
          await _mark(entry, entry.attempts + 1, park: true, message: message);
        case _Failed(:final message):
          final attempts = entry.attempts + 1;
          await _mark(
            entry,
            attempts,
            park: attempts >= maxAttempts,
            message: message,
          );
      }
    }
  }

  Future<void> _mark(
    RunSyncQueueData entry,
    int attempts, {
    required bool park,
    required String message,
  }) {
    final delay = baseDelay * (1 << (attempts - 1).clamp(0, 16));
    return (_db.update(_db.runSyncQueue)..where((q) => q.id.equals(entry.id)))
        .write(
      RunSyncQueueCompanion(
        attempts: Value(attempts),
        lastError: Value(message),
        parked: Value(park),
        nextAttemptAt: Value(
          park ? null : _now().add(delay).toUtc().toIso8601String(),
        ),
      ),
    );
  }

  Future<void> _cache(String id, Map<String, dynamic> json) =>
      _db.into(_db.cachedJson).insertOnConflictUpdate(
            CachedJsonCompanion.insert(
              key: runCacheKey(id),
              json: jsonEncode(json),
              storedAt: _now().toUtc().toIso8601String(),
            ),
          );

  Future<_Outcome> _send(RunSyncQueueData entry) async {
    final kind = RunSyncKind.values.byName(entry.kind);
    final payload = jsonDecode(entry.payloadJson) as Map<String, dynamic>;
    final id = entry.clientRunId;
    switch (kind) {
      case RunSyncKind.create:
        final result = await _api.createRun(payload);
        if (result case Ok(:final value)) {
          await _db.transaction(() async {
            await _cache(id, value);
            await _store.delete(id);
            await remove(entry.id);
          });
          return const _Sent();
        }
        return _classify((result as Err).failure);
      case RunSyncKind.patch:
        final result = await _api.patchRun(id, payload);
        if (result case Ok(:final value)) {
          await _db.transaction(() async {
            await _cache(id, value);
            await remove(entry.id);
          });
          return const _Sent();
        }
        final failure = (result as Err).failure;
        // Deleted meanwhile (here or elsewhere): nothing left to change.
        if (failure is NotFound) {
          await remove(entry.id);
          return const _Sent();
        }
        return _classify(failure);
      case RunSyncKind.delete:
        final result = await _api.deleteRun(id);
        final failure = switch (result) {
          Err(:final failure) => failure,
          Ok() => null,
        };
        if (failure == null || failure is NotFound) {
          await _db.transaction(() async {
            await (_db.delete(_db.cachedJson)
                  ..where((c) => c.key.equals(runCacheKey(id))))
                .go();
            await remove(entry.id);
          });
          return const _Sent();
        }
        return _classify(failure);
    }
  }

  _Outcome _classify(Failure failure) => switch (failure) {
        Offline() => const _Stop(retry: true),
        Unauthenticated() => const _Stop(retry: false),
        Validation(:final message) => _Park(message),
        Forbidden(:final message) => _Park(message),
        _ => _Failed(failure.message),
      };
}

sealed class _Outcome {
  const _Outcome();
}

class _Sent extends _Outcome {
  const _Sent();
}

class _Stop extends _Outcome {
  const _Stop({required this.retry});
  final bool retry;
}

class _Park extends _Outcome {
  const _Park(this.message);
  final String message;
}

class _Failed extends _Outcome {
  const _Failed(this.message);
  final String message;
}
