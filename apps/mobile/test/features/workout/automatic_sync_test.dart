import 'dart:async';

import 'package:fitos/core/db/app_database.dart';
import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/features/workout/data/local_workout_repository.dart';
import 'package:fitos/features/workout/data/sync_engine.dart';
import 'package:fitos/features/workout/domain/entities/workout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import '../../support/fake_workout_api.dart';

/// Phase 6.6 Gate 7 — found on the Samsung S24: sessions finished with
/// "1 not synced" and only reached History after Retry. The server logs
/// showed why: every DELETE was rejected (422, a JSON content type on an
/// empty body), so a removed set stayed on the server; the set re-logged in
/// its slot then hit the one-live-set-per-position rule (409); those entries
/// backed off with nothing to wake them, then parked. A quick double tap
/// produced the same 409 without any delete.
///
/// These tests drive the real repository + sync engine against a fake
/// server that enforces the same position rule, and never call `sync()`
/// where the point is that sync happens by itself.
void main() {
  late AppDatabase db;
  late _GatedApi api;
  late SyncEngine engine;
  late LocalWorkoutRepository repo;

  setUp(() {
    db = AppDatabase.inMemory();
    api = _GatedApi();
    engine = SyncEngine(
      db,
      api,
      baseDelay: const Duration(milliseconds: 1),
      offlineRetry: const Duration(milliseconds: 20),
      offlineRetryMax: const Duration(milliseconds: 40),
    );
    repo = LocalWorkoutRepository(db, api, engine: engine, uuid: const Uuid());
  });
  tearDown(() async {
    engine.dispose();
    await db.close();
  });

  /// Poll until [condition] holds, or fail after [timeout]. Never drains.
  Future<void> eventually(
    Future<bool> Function() condition, {
    Duration timeout = const Duration(seconds: 5),
    String reason = '',
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!await condition()) {
      if (DateTime.now().isAfter(deadline)) {
        final st = await repo.syncStatus();
        final queue = await db.select(db.syncQueue).get();
        fail(
          'timed out waiting: $reason — pending ${st.pending}, parked '
          '${st.parked}, lastError ${st.lastError}; queue '
          '${queue.map((q) => '${q.id}:${q.kind}(a${q.attempts}${q.parked ? ',parked' : ''}${q.nextAttemptAt == null ? '' : ',next'})').toList()}; '
          'calls ${api.calls}; waking ${engine.hasScheduledWake}',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  Future<bool> clean() async => (await repo.syncStatus()).clean;

  LogSetInput set(SessionExercise x, int index, {double kg = 80}) =>
      LogSetInput(
        clientSetId: const Uuid().v4(),
        clientExerciseId: x.clientExerciseId,
        setIndex: index,
        setType: SetType.working,
        weightKg: kg,
        reps: 10,
        rir: 1,
        loggedAt: DateTime.now().toUtc().toIso8601String(),
        plannedSetId: null,
      );

  WorkoutSession? onServer(String clientSessionId) =>
      api.sessions[clientSessionId];

  List<SetLog> liveSetsAt(String clientSessionId, int index) => [
        for (final x in onServer(clientSessionId)!.exercises)
          for (final s in x.sets)
            if (s.setIndex == index && s.setType == SetType.working) s,
      ];

  group('A–D: completion syncs by itself', () {
    test('A. completed online → synced with no Retry and no sync() call',
        () async {
      final s = await repo.startSession(day: api.todayResponse);
      final x = s.exercises.first;
      await repo.logSet(s.clientSessionId, set(x, 1));
      await repo.logSet(s.clientSessionId, set(x, 2));
      await repo.complete(s.clientSessionId);

      await eventually(clean, reason: 'queue drained');
      expect(onServer(s.clientSessionId)!.status, SessionStatus.completed);
      expect(onServer(s.clientSessionId)!.exercises.first.sets, hasLength(2));
      expect((await repo.syncStatus()).parked, 0);
    });

    test(
        'B. completed while the server is unreachable → kept on the phone, pending, nothing parked, a retry scheduled',
        () async {
      api.offline = true;
      final s = await repo.startSession(day: api.todayResponse);
      await repo.logSet(s.clientSessionId, set(s.exercises.first, 1));
      await repo.complete(s.clientSessionId);

      await eventually(
        () async => engine.hasScheduledWake,
        reason: 'a retry is scheduled',
      );
      final status = await repo.syncStatus();
      expect(status.pending, greaterThan(0));
      expect(status.parked, 0, reason: 'unreachable is not a failure');
      expect(
        (await repo.session(s.clientSessionId))!.status,
        SessionStatus.completed,
      );
      expect(onServer(s.clientSessionId), isNull);
    });

    test(
        'C. the server comes back while Wi-Fi never dropped → the queue drains on its own',
        () async {
      api.offline = true;
      final s = await repo.startSession(day: api.todayResponse);
      await repo.logSet(s.clientSessionId, set(s.exercises.first, 1));
      await repo.complete(s.clientSessionId);
      await eventually(() async => engine.hasScheduledWake);

      api.offline = false; // no connectivity event, no resume, no tap

      await eventually(clean, reason: 'drained after the server returned');
      expect(onServer(s.clientSessionId)!.status, SessionStatus.completed);
    });

    test('D. two sessions finished while unreachable → both sync, in order',
        () async {
      api.offline = true;
      final first = await repo.startSession(day: api.todayResponse);
      await repo.logSet(first.clientSessionId, set(first.exercises.first, 1));
      await repo.complete(first.clientSessionId);
      final second = await repo.startSession(day: api.todayResponse);
      await repo.logSet(second.clientSessionId, set(second.exercises.first, 1));
      await repo.logSet(second.clientSessionId, set(second.exercises.first, 2));
      await repo.complete(second.clientSessionId);

      api.offline = false;

      await eventually(clean, reason: 'both drained');
      expect(onServer(first.clientSessionId)!.status, SessionStatus.completed);
      expect(onServer(second.clientSessionId)!.status, SessionStatus.completed);
      expect(
        onServer(second.clientSessionId)!.exercises.first.sets,
        hasLength(2),
      );
      // Failed offline attempts were retried; the server holds exactly two.
      expect(api.sessions, hasLength(2));
    });
  });

  group('E–F: failures are retried, parked, never dropped; Retry recovers', () {
    test(
        'E. a rejected request is retried by itself and parked — later work still syncs, the set stays on the phone',
        () async {
      final s = await repo.startSession(day: api.todayResponse);
      await eventually(clean);
      api.rejectSets = true;
      await repo.logSet(s.clientSessionId, set(s.exercises.first, 1));
      await repo.complete(s.clientSessionId);

      await eventually(
        () async => (await repo.syncStatus()).parked == 1,
        reason: 'parked after five automatic attempts',
      );
      await eventually(
        () async =>
            onServer(s.clientSessionId)?.status == SessionStatus.completed,
        reason: 'the independent completion went through',
      );
      expect(api.rejectedSets, 5);
      expect(
        (await repo.session(s.clientSessionId))!.exercises.first.sets,
        hasLength(1),
        reason: 'never dropped',
      );
    });

    test('F. Retry sends the parked entry once the server accepts it',
        () async {
      final s = await repo.startSession(day: api.todayResponse);
      await eventually(clean);
      api.rejectSets = true;
      await repo.logSet(s.clientSessionId, set(s.exercises.first, 1));
      await eventually(() async => (await repo.syncStatus()).parked == 1);

      api.rejectSets = false;
      await repo.retryParked();

      await eventually(clean);
      expect(onServer(s.clientSessionId)!.exercises.first.sets, hasLength(1));
    });
  });

  group(
      'Gate 7 (S24, 2026-09-23): a session FITOS holds that this phone lost blocks new starts',
      () {
    /// What the S24 did: a session was started and synced, then sign-out
    /// wiped the phone (queue included) before its end reached FITOS. The
    /// server still has it active; this phone knows nothing of it.
    Future<WorkoutSession> orphanOnServer() async {
      final r = await api.start(
        StartSessionRequest(
          clientSessionId: const Uuid().v4(),
          startedAt: DateTime.now().toUtc().toIso8601String(),
        ),
      );
      return (r as Ok<WorkoutSession>).value;
    }

    test(
        'the new session is kept on the phone, its start is refused, retried and parked — never a second session on the server, however often Retry is pressed',
        () async {
      final orphan = await orphanOnServer();
      final s = await repo.startSession(day: api.todayResponse);
      await repo.logSet(s.clientSessionId, set(s.exercises.first, 1));
      await repo.complete(s.clientSessionId);

      await eventually(() async => (await repo.syncStatus()).parked > 0);
      for (var i = 0; i < 3; i++) {
        await repo.retryParked();
        await eventually(() async => (await repo.syncStatus()).parked > 0);
      }
      expect(api.sessions, hasLength(1), reason: 'only the orphan');
      expect(api.sessions.values.single.id, orphan.id);
      expect(
        (await repo.session(s.clientSessionId))!.status,
        SessionStatus.completed,
        reason: 'the phone keeps its own session',
      );
    });

    test(
        'once the user ends the orphan, Retry sends the blocked session exactly once — start, sets, completion — and a second Retry is a no-op',
        () async {
      final orphan = await orphanOnServer();
      final s = await repo.startSession(day: api.todayResponse);
      await repo.logSet(s.clientSessionId, set(s.exercises.first, 1));
      await repo.complete(s.clientSessionId);
      await eventually(() async => (await repo.syncStatus()).parked > 0);

      // The user's explicit choice (the notice's "Finish it").
      await api.complete(
        orphan.id,
        CompleteSessionRequest(completedAt: orphan.startedAt),
      );
      await repo.retryParked();

      await eventually(clean, reason: 'everything drained after the block');
      expect(api.sessions, hasLength(2));
      final mine = onServer(s.clientSessionId)!;
      expect(mine.status, SessionStatus.completed);
      expect(mine.exercises.first.sets, hasLength(1));
      final starts = api.calls.where((c) => c == 'start').length;
      await repo.retryParked();
      await repo.sync();
      expect(api.calls.where((c) => c == 'start').length, starts);
      expect(api.sessions, hasLength(2), reason: 'Retry again changes nothing');
    });

    test(
        'app restart with a completed session still queued: the next engine drains it without Retry',
        () async {
      api.offline = true;
      final s = await repo.startSession(day: api.todayResponse);
      await repo.logSet(s.clientSessionId, set(s.exercises.first, 1));
      await repo.complete(s.clientSessionId);
      engine.dispose(); // the app is killed; the queue stays on disk

      api.offline = false;
      final engine2 = SyncEngine(
        db,
        api,
        baseDelay: const Duration(milliseconds: 1),
        offlineRetry: const Duration(milliseconds: 20),
      );
      addTearDown(engine2.dispose);
      final restarted = LocalWorkoutRepository(
        db,
        api,
        engine: engine2,
        uuid: const Uuid(),
      );
      // What the app does on launch (SyncCoordinator): one drain.
      await restarted.sync();

      await eventually(
        () async => (await restarted.syncStatus()).clean,
        reason: 'restart drained the queue',
      );
      expect(onServer(s.clientSessionId)!.status, SessionStatus.completed);
    });
  });

  group('H: one live set per position — no duplicates, no 409', () {
    test(
        'a double tap on the same row corrects the set instead of queueing a second',
        () async {
      final s = await repo.startSession(day: api.todayResponse);
      final x = s.exercises.first;
      await repo.logSet(s.clientSessionId, set(x, 1));
      await repo.logSet(s.clientSessionId, set(x, 1, kg: 82.5));

      final local = (await repo.session(s.clientSessionId))!
          .exercises
          .first
          .sets
          .where((t) => t.setIndex == 1)
          .toList();
      expect(local, hasLength(1));
      expect(local.single.weightKg, 82.5);

      await eventually(clean);
      expect(liveSetsAt(s.clientSessionId, 1), hasLength(1));
      expect(liveSetsAt(s.clientSessionId, 1).single.weightKg, 82.5);
      expect(api.positionConflicts, 0);
    });

    test(
        'a synced set removed and re-logged at the same position: deleted on the server first, one live set, no 409',
        () async {
      final s = await repo.startSession(day: api.todayResponse);
      final x = s.exercises.first;
      final original = set(x, 1);
      await repo.logSet(s.clientSessionId, original);
      await eventually(clean);

      await repo.deleteSet(s.clientSessionId, original.clientSetId);
      final again = set(x, 1, kg: 85);
      await repo.logSet(s.clientSessionId, again);
      await repo.complete(s.clientSessionId);

      await eventually(clean);
      expect(api.calls, contains('deleteSet'));
      expect(api.positionConflicts, 0);
      final live = liveSetsAt(s.clientSessionId, 1);
      expect(live.map((t) => t.clientSetId), [again.clientSetId]);
      expect(onServer(s.clientSessionId)!.status, SessionStatus.completed);
    });

    test(
        'removed and re-logged while its batch is on the wire: the server deletes it after the batch lands, then takes the new one',
        () async {
      final s = await repo.startSession(day: api.todayResponse);
      await eventually(clean);
      final x = s.exercises.first;
      api.gate = Completer<void>();
      final original = set(x, 1);
      await repo.logSet(s.clientSessionId, original);
      await eventually(() async => api.waiting, reason: 'batch in flight');

      await repo.deleteSet(s.clientSessionId, original.clientSetId);
      final again = set(x, 1, kg: 90);
      await repo.logSet(s.clientSessionId, again);
      api.gate!.complete();

      await eventually(clean);
      expect(api.positionConflicts, 0);
      expect(
        liveSetsAt(s.clientSessionId, 1).map((t) => t.clientSetId),
        [again.clientSetId],
      );
    });

    test(
        'edited while its batch is on the wire: the edit reaches the server as a patch, not lost',
        () async {
      final s = await repo.startSession(day: api.todayResponse);
      await eventually(clean);
      final x = s.exercises.first;
      api.gate = Completer<void>();
      final original = set(x, 1);
      await repo.logSet(s.clientSessionId, original);
      await eventually(() async => api.waiting);

      await repo.updateSet(
        s.clientSessionId,
        original.clientSetId,
        weightKg: 95,
      );
      api.gate!.complete();

      await eventually(clean);
      expect(liveSetsAt(s.clientSessionId, 1).single.weightKg, 95);
    });

    test(
        'an answer lost in flight and the batch re-sent: still exactly one set (idempotent on the client id)',
        () async {
      final s = await repo.startSession(day: api.todayResponse);
      await eventually(clean);
      api.loseNextAnswer = true;
      await repo.logSet(s.clientSessionId, set(s.exercises.first, 1));
      await eventually(clean);
      expect(api.calls.where((c) => c.startsWith('logSets')).length, 2);
      expect(liveSetsAt(s.clientSessionId, 1), hasLength(1));
    });
  });
}

/// The fake server, plus: a gate that holds a logSets request on the wire,
/// a switch that rejects sets, and a lost answer (applied, then "offline").
class _GatedApi extends FakeWorkoutApi {
  Completer<void>? gate;
  bool waiting = false;
  bool rejectSets = false;
  int rejectedSets = 0;
  bool loseNextAnswer = false;

  @override
  Future<Result<WorkoutSession>> logSets(
    String id,
    LogSetsRequest request,
  ) async {
    if (rejectSets) {
      rejectedSets++;
      return const Err(Validation('The server rejected that set.'));
    }
    final g = gate;
    if (g != null) {
      waiting = true;
      await g.future;
      waiting = false;
      gate = null;
    }
    final result = await super.logSets(id, request);
    if (loseNextAnswer) {
      loseNextAnswer = false;
      return const Err(Offline());
    }
    return result;
  }
}
