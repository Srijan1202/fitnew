import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../../core/db/app_database.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../domain/entities/food_log.dart';
import 'food_log_api.dart';

enum NutritionSyncKind { create, delete }

/// The cache key of a server day (the same one the repository reads).
String nutritionDayCacheKey(String date) => 'nutrition.day.$date';

/// Drains the food-log queue (§33, Phase 8). Separate from the workout
/// SyncEngine by design (owner): it shares ADR-006's POLICY, not its code.
///
///  - FIFO; a log's delete never overtakes its create.
///  - Offline / server not answering / signed out: stop, charge nothing;
///    connectivity, app resume, the next sign-in or its own wake drains again.
///  - A refusal that cannot change on retry (422, a 404 on create): parked at
///    once with the server's message, shown with Retry — never dropped.
///  - Anything else: backoff 300 ms · 2ⁿ, five attempts, then parked.
///  - Every request is idempotent on the server (clientLogId), so a kill
///    mid-request, a replay or a double drain costs nothing.
///
/// A confirmed create writes the server's day into the cache and removes
/// the local row in ONE transaction, so the log is never shown twice or
/// missing.
class NutritionSyncEngine {
  NutritionSyncEngine(
    this._db,
    this._api, {
    DateTime Function()? now,
    this.maxAttempts = 5,
    this.baseDelay = const Duration(milliseconds: 300),
    this.offlineRetry = const Duration(seconds: 15),
    this.offlineRetryMax = const Duration(minutes: 2),
    this.wakeItself = true,
  }) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final FoodLogApi _api;
  final DateTime Function() _now;
  final int maxAttempts;
  final Duration baseDelay;
  final Duration offlineRetry;
  final Duration offlineRetryMax;
  final bool wakeItself;

  Timer? _wake;
  int _offlineMisses = 0;
  bool _disposed = false;

  /// The entry on the wire, if any. The repository never folds into it.
  int? _inFlightId;
  String? _inFlightLog;

  bool isInFlight(String clientLogId) => _inFlightLog == clientLogId;

  @visibleForTesting
  bool get hasScheduledWake => _wake?.isActive ?? false;

  bool _draining = false;
  bool _again = false;
  bool _sentAny = false;
  Completer<void>? _done;
  final _drained = StreamController<void>.broadcast();

  /// Fires after a drain in which something reached the server.
  Stream<void> get drained => _drained.stream;

  void dispose() {
    _disposed = true;
    _wake?.cancel();
    _wake = null;
    _drained.close();
  }

  void _scheduleWake(Duration delay) {
    if (_disposed || !wakeItself) return;
    _wake?.cancel();
    _wake = Timer(delay < Duration.zero ? Duration.zero : delay, kick);
  }

  /* ----------------------------------------------------------- queue -- */

  Future<int> enqueue(
    NutritionSyncKind kind,
    String clientLogId,
    Map<String, dynamic> payload,
  ) =>
      _db.into(_db.nutritionSyncQueue).insert(
            NutritionSyncQueueCompanion.insert(
              kind: kind.name,
              clientLogId: clientLogId,
              payloadJson: jsonEncode(payload),
              createdAt: _now().toUtc().toIso8601String(),
            ),
          );

  /// Parked entries go back to the front with a fresh budget (the user's Retry).
  Future<void> retryParked() async {
    await (_db.update(_db.nutritionSyncQueue)
          ..where((t) => t.parked.equals(true)))
        .write(
      const NutritionSyncQueueCompanion(
        parked: Value(false),
        attempts: Value(0),
        nextAttemptAt: Value(null),
      ),
    );
    kick();
  }

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
    _sentAny = false;
    _wake?.cancel();
    _Stop? stop;
    try {
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
    final next = await (_db.select(_db.nutritionSyncQueue)
          ..where((t) => t.parked.equals(false) & t.nextAttemptAt.isNotNull())
          ..orderBy([(t) => OrderingTerm.asc(t.nextAttemptAt)])
          ..limit(1))
        .getSingleOrNull();
    if (next == null) return;
    _scheduleWake(DateTime.parse(next.nextAttemptAt!).difference(_now()));
  }

  Future<_Stop?> _loop() async {
    while (true) {
      final entry = await _db.transaction(() async {
        final now = _now().toUtc().toIso8601String();
        final due = await (_db.select(_db.nutritionSyncQueue)
              ..where(
                (t) =>
                    t.parked.equals(false) &
                    (t.nextAttemptAt.isNull() |
                        t.nextAttemptAt.isSmallerOrEqualValue(now)),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.id)])
              ..limit(100))
            .get();
        for (final next in due) {
          // A log's earlier entry (its create, waiting out a backoff) holds it.
          final blocker = await (_db.select(_db.nutritionSyncQueue)
                ..where(
                  (t) =>
                      t.clientLogId.equals(next.clientLogId) &
                      t.id.isSmallerThanValue(next.id),
                )
                ..limit(1))
              .getSingleOrNull();
          if (blocker != null) continue;
          _inFlightId = next.id;
          _inFlightLog = next.clientLogId;
          return next;
        }
        return null;
      });
      if (entry == null) return null;

      final _Outcome outcome;
      try {
        outcome = await _send(entry);
      } finally {
        _inFlightId = null;
        _inFlightLog = null;
      }
      switch (outcome) {
        case _Sent():
          _sentAny = true;
          _offlineMisses = 0;
          continue;
        case _Stop():
          return outcome;
        case _Park(:final message):
          await _mark(
            entry,
            attempts: entry.attempts + 1,
            park: true,
            message: message,
          );
          continue;
        case _Failed(:final message):
          final attempts = entry.attempts + 1;
          await _mark(
            entry,
            attempts: attempts,
            park: attempts >= maxAttempts,
            message: message,
          );
          continue;
      }
    }
  }

  Future<void> _mark(
    NutritionSyncQueueData entry, {
    required int attempts,
    required bool park,
    required String message,
  }) {
    final delay = baseDelay * (1 << (attempts - 1).clamp(0, 16));
    return (_db.update(_db.nutritionSyncQueue)
          ..where((t) => t.id.equals(entry.id)))
        .write(
      NutritionSyncQueueCompanion(
        attempts: Value(attempts),
        lastError: Value(message),
        parked: Value(park),
        nextAttemptAt: Value(
          park ? null : _now().add(delay).toUtc().toIso8601String(),
        ),
      ),
    );
  }

  Future<void> _cacheDay(NutritionDay day) =>
      _db.into(_db.cachedJson).insertOnConflictUpdate(
            CachedJsonCompanion.insert(
              key: nutritionDayCacheKey(day.date),
              json: jsonEncode(day.toJson()),
              storedAt: _now().toUtc().toIso8601String(),
            ),
          );

  Future<_Outcome> _send(NutritionSyncQueueData entry) async {
    final kind = NutritionSyncKind.values.byName(entry.kind);
    final payload = jsonDecode(entry.payloadJson) as Map<String, dynamic>;
    switch (kind) {
      case NutritionSyncKind.create:
        final result = await _api.createLog(CreateLogRequest.fromJson(payload));
        switch (result) {
          case Ok(:final value):
            await _db.transaction(() async {
              await _cacheDay(value.day);
              await (_db.delete(_db.localFoodLogs)
                    ..where((t) => t.clientLogId.equals(entry.clientLogId)))
                  .go();
              await _remove(entry.id);
            });
            return const _Sent();
          case Err(:final failure):
            return _classify(failure, create: true);
        }
      case NutritionSyncKind.delete:
        final result = await _api.deleteLog(entry.clientLogId);
        switch (result) {
          case Ok(:final value):
            await _db.transaction(() async {
              await _cacheDay(value.day);
              await _remove(entry.id);
            });
            return const _Sent();
          case Err(:final failure):
            // Not on the server: the log is gone either way — done.
            if (failure is NotFound) {
              await _remove(entry.id);
              return const _Sent();
            }
            return _classify(failure, create: false);
        }
    }
  }

  Future<void> _remove(int id) =>
      (_db.delete(_db.nutritionSyncQueue)..where((t) => t.id.equals(id))).go();

  _Outcome _classify(Failure failure, {required bool create}) =>
      switch (failure) {
        // Offline and ServiceUnavailable (an Offline): wait, charge nothing.
        Offline() => const _Stop(retry: true),
        Unauthenticated() => const _Stop(retry: false),
        Validation(:final message) => _Park(message),
        NotFound(:final message) when create => _Park(message),
        _ => _Failed(failure.message),
      };

  @visibleForTesting
  int? get inFlightId => _inFlightId;
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
