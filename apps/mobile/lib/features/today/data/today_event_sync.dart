import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../../core/db/app_database.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../domain/today.dart';
import 'today_api.dart';

/// Drains the TODAY event queue (Phase 11, D9). Its own engine: the workout
/// SyncEngine and the NutritionSyncEngine are untouched — this shares their
/// POLICY (ADR-006), not their code.
///
///  - FIFO; an action's later event never overtakes an earlier one still
///    waiting (the server needs `shown` before `accepted`, `accepted` before
///    `completed`).
///  - Offline / server not answering / signed out: stop and charge nothing;
///    connectivity, app resume, the next sign-in or its own wake drains again.
///    Offline events stay queued for catch-up (the server accepts them up to
///    7 days after they happened, P3).
///  - 201 / 200 (stored, or an exact replay): done.
///  - 409 (the client id collided), 422 (a transition, a time or evidence the
///    server refuses), 404 (no such action): a retry cannot change the
///    answer, so the entry leaves the queue at once — never an endless retry.
///  - Anything else: backoff 300 ms · 2ⁿ, five attempts, then it leaves.
///  - Every retry sends the SAME clientEventId and occurredAt, so a kill
///    mid-request or a double drain is an exact replay (200), never a
///    second event.
class TodayEventSync {
  TodayEventSync(
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
  final TodayApi _api;
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
  bool _sentAny = false;
  Completer<void>? _done;
  final _drained = StreamController<void>.broadcast();

  /// Fires after a drain in which something reached the server.
  Stream<void> get drained => _drained.stream;

  @visibleForTesting
  bool get hasScheduledWake => _wake?.isActive ?? false;

  void dispose() {
    _disposed = true;
    _wake?.cancel();
    _wake = null;
    _drained.close();
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

  void _scheduleWake(Duration delay) {
    if (_disposed || !wakeItself) return;
    _wake?.cancel();
    _wake = Timer(delay < Duration.zero ? Duration.zero : delay, kick);
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
    final next = await (_db.select(_db.todayEventQueue)
          ..where((t) => t.nextAttemptAt.isNotNull())
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
        final due = await (_db.select(_db.todayEventQueue)
              ..where(
                (t) =>
                    t.nextAttemptAt.isNull() |
                    t.nextAttemptAt.isSmallerOrEqualValue(now),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.id)])
              ..limit(100))
            .get();
        for (final next in due) {
          // The action's earlier event (waiting out a backoff) holds it.
          final blocker = await (_db.select(_db.todayEventQueue)
                ..where(
                  (t) =>
                      t.recommendationId.equals(next.recommendationId) &
                      t.id.isSmallerThanValue(next.id),
                )
                ..limit(1))
              .getSingleOrNull();
          if (blocker == null) return next;
        }
        return null;
      });
      if (entry == null) return null;

      final outcome = await _send(entry);
      switch (outcome) {
        case _Sent():
          _sentAny = true;
          _offlineMisses = 0;
          continue;
        case _Stop():
          return outcome;
        case _Drop(:final status, :final message):
          await _finish(entry, status: status, message: message);
          continue;
        case _Failed(:final message):
          final attempts = entry.attempts + 1;
          if (attempts >= maxAttempts) {
            await _finish(entry, status: 'failed', message: message);
          } else {
            final delay = baseDelay * (1 << (attempts - 1).clamp(0, 16));
            await (_db.update(_db.todayEventQueue)
                  ..where((t) => t.id.equals(entry.id)))
                .write(
              TodayEventQueueCompanion(
                attempts: Value(attempts),
                lastError: Value(message),
                nextAttemptAt:
                    Value(_now().add(delay).toUtc().toIso8601String()),
              ),
            );
          }
          continue;
      }
    }
  }

  /// The entry leaves the queue; the ledger keeps what became of it.
  Future<void> _finish(
    TodayEventQueueData entry, {
    required String status,
    String? message,
  }) =>
      _db.transaction(() async {
        await (_db.delete(_db.todayEventQueue)
              ..where((t) => t.id.equals(entry.id)))
            .go();
        await (_db.update(_db.todayEventLedger)
              ..where(
                (t) =>
                    t.recommendationId.equals(entry.recommendationId) &
                    t.event.equals(entry.event),
              ))
            .write(TodayEventLedgerCompanion(status: Value(status)));
      });

  Future<_Outcome> _send(TodayEventQueueData entry) async {
    final result = await _api.event(
      entry.recommendationId,
      TodayEventRequest(
        clientEventId: entry.clientEventId,
        event: TodayEventName.fromWire(entry.event),
        occurredAt: entry.occurredAt,
      ),
    );
    switch (result) {
      case Ok():
        await _finish(entry, status: 'sent');
        return const _Sent();
      case Err(:final failure):
        return switch (failure) {
          // Offline and ServiceUnavailable (an Offline): wait, charge nothing.
          Offline() => const _Stop(retry: true),
          // The interceptor already refreshed the token once; the session is
          // gone. Keep the event for the next sign-in.
          Unauthenticated() => const _Stop(retry: false),
          Conflict(:final message) => _Drop('rejected', message),
          Validation(:final message) => _Drop('rejected', message),
          NotFound(:final message) => _Drop('rejected', message),
          _ => _Failed(failure.message),
        };
    }
  }
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

class _Drop extends _Outcome {
  const _Drop(this.status, this.message);
  final String status;
  final String message;
}

class _Failed extends _Outcome {
  const _Failed(this.message);
  final String message;
}
