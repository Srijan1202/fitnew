import 'package:fitos/core/db/app_database.dart';
import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/features/exercise/domain/entities/exercise.dart';
import 'package:fitos/features/profile/domain/entities/vocabulary.dart';
import 'package:fitos/features/workout/data/local_workout_repository.dart';
import 'package:fitos/features/workout/data/sync_engine.dart';
import 'package:fitos/features/workout/domain/entities/workout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import '../../support/fake_workout_api.dart';

/// §31 Phase 5 acceptance, in miniature: a full workout logged in airplane
/// mode syncs on reconnect, every set reaching the server exactly once;
/// replays and interruptions never duplicate; a session completed on
/// another device merges; failures park, never vanish.
void main() {
  late AppDatabase db;
  late FakeWorkoutApi api;
  late LocalWorkoutRepository repo;
  late SyncEngine engine;
  var clock = DateTime.utc(2026, 9, 21, 10);

  DateTime now() => clock;
  String stamp() => clock.toUtc().toIso8601String();
  void tick([int seconds = 30]) =>
      clock = clock.add(Duration(seconds: seconds));

  setUp(() {
    db = AppDatabase.inMemory();
    api = FakeWorkoutApi();
    engine = SyncEngine(db, api, now: now, baseDelay: Duration.zero);
    repo = LocalWorkoutRepository(
      db,
      api,
      now: now,
      engine: engine,
      uuid: const Uuid(),
    );
  });
  tearDown(() => db.close());

  LogSetInput set(
    SessionExercise x,
    int index, {
    double? kg = 80,
    int reps = 10,
    SetType type = SetType.working,
  }) =>
      LogSetInput(
        clientSetId: const Uuid().v4(),
        clientExerciseId: x.clientExerciseId,
        setIndex: index,
        setType: type,
        weightKg: kg,
        reps: reps,
        rir: 1,
        loggedAt: stamp(),
        plannedSetId: null,
      );

  group('offline first', () {
    test(
        'a whole session logged in airplane mode syncs on reconnect, each set exactly once, in order',
        () async {
      // Warm the cache while online (the day is viewed before the gym).
      final today = (await repo.today() as Ok<TodayResponse>).value;
      api.offline = true;

      // Start from the (cached) day: rendered from the phone, nothing sent.
      final s = await repo.startSession(day: today);
      expect(s.status, SessionStatus.active);
      expect(
        s.exercises.map((x) => x.name),
        ['Barbell Back Squat', 'Standing Calf Raise'],
      );
      expect(s.exercises.first.targets.length, 3);
      expect(s.exercises.first.lastPerformance?.sets.first.weightKg, 70);
      // (The drainer tried the start and got "offline"; nothing landed.)
      expect(api.sessions, isEmpty);

      final squat = s.exercises[0];
      final curl = s.exercises[1];
      final logged = <LogSetInput>[];
      for (var i = 1; i <= 3; i++) {
        final l = set(squat, i);
        logged.add(l);
        await repo.logSet(s.clientSessionId, l);
        tick(90);
      }
      for (var i = 1; i <= 2; i++) {
        final l = set(curl, i, kg: 40, reps: 12);
        logged.add(l);
        await repo.logSet(s.clientSessionId, l);
        tick(60);
      }
      await repo.complete(s.clientSessionId);
      // Everything is on the phone …
      final local = (await repo.session(s.clientSessionId))!;
      expect(local.status, SessionStatus.completed);
      expect(local.workingSetsLogged, 5);
      // … and nothing reached the server; the queue holds it all.
      expect(api.sessions, isEmpty);
      expect(api.calls.where((c) => c.startsWith('logSets')), isEmpty);
      final pending = await repo.syncStatus();
      expect(pending.pending, greaterThan(0));
      expect(pending.parked, 0);

      // Reconnect.
      api.offline = false;
      await repo.sync();

      final server = api.sessions[s.clientSessionId]!;
      expect(server.status, SessionStatus.completed);
      final serverSets = [for (final x in server.exercises) ...x.sets];
      expect(
        serverSets.map((t) => t.clientSetId).toList(),
        logged.map((l) => l.clientSetId).toList(),
      );
      expect(serverSets.map((t) => t.weightKg).toList(), [80, 80, 80, 40, 40]);
      // Batched: the five sets went up in one request after the start.
      expect(api.calls.where((c) => c.startsWith('logSets')).length, 1);
      expect(api.calls.last, 'complete');
      expect((await repo.syncStatus()).clean, isTrue);

      // The phone now knows the server ids, the records and the summary.
      final synced = (await repo.session(s.clientSessionId))!;
      expect(synced.id, server.id);
      expect(synced.exercises.first.id, server.exercises.first.id);
      expect(synced.exercises.first.sets.first.id, serverSets.first.id);
      expect(synced.summary?.prs.length, 1);
      expect(
        synced.exercises.first.sets.every((t) => !t.id.contains(t.clientSetId)),
        isTrue,
      );
    });

    test('interrupted mid-drain and drained again: no duplicates on the server',
        () async {
      api.offline = true;
      final s = await repo.startSession();
      final ex = await repo.addExercise(
        s.clientSessionId,
        const ExerciseSummary(
          id: '11111111-1111-4111-8111-111111111111',
          slug: 'barbell-back-squat',
          name: 'Barbell Back Squat',
          movementPattern: MovementPattern.squat,
          equipment: [Equipment.barbell],
          difficulty: Difficulty.intermediate,
          isUnilateral: false,
          primaryMuscles: [MuscleGroup.quads],
        ),
      );
      final x = (await repo.session(s.clientSessionId))!.exercises.single;
      expect(x.clientExerciseId, ex);
      for (var i = 1; i <= 3; i++) {
        await repo.logSet(s.clientSessionId, set(x, i));
      }
      // "Kill the app" after the start and the add reached the server but
      // before the sets did: simulate by going offline after two calls.
      api.offline = false;
      var calls = 0;
      final drains = <Future<void>>[];
      // Drain once; the fake goes offline once the exercise is added.
      drains.add(
        Future(() async {
          while (calls < 2) {
            await Future<void>.delayed(Duration.zero);
            calls = api.calls.length;
          }
          api.offline = true;
        }),
      );
      await repo.sync();
      await Future.wait(drains);
      // Replay everything: start and add are idempotent, sets go once.
      api.offline = false;
      await repo.sync();
      await repo.sync();
      final server = api.sessions[s.clientSessionId]!;
      expect(server.exercises.length, 1);
      expect(server.exercises.single.sets.length, 3);
      expect(
        api.calls.where((c) => c == 'start').length,
        greaterThanOrEqualTo(1),
      );
      expect((await repo.syncStatus()).clean, isTrue);
    });

    test(
        'the session in progress survives a restart of the repository (new object, same database)',
        () async {
      api.offline = true;
      final s = await repo.startSession(day: api.todayResponse);
      await repo.logSet(s.clientSessionId, set(s.exercises.first, 1));
      final again = LocalWorkoutRepository(
        db,
        api,
        now: now,
        engine: SyncEngine(db, api, now: now, baseDelay: Duration.zero),
      );
      final active = await again.activeSession();
      expect(active?.clientSessionId, s.clientSessionId);
      expect(active?.exercises.first.sets.length, 1);
    });
  });

  group('edits before and after the server knows the set', () {
    test(
        'an unsynced set is amended in its batch and never patched; a synced set is patched',
        () async {
      api.offline = true;
      final s = await repo.startSession(day: api.todayResponse);
      final x = s.exercises.first;
      final first = set(x, 1);
      await repo.logSet(s.clientSessionId, first);
      await repo.updateSet(
        s.clientSessionId,
        first.clientSetId,
        reps: 12,
        weightKg: 82.5,
      );
      api.offline = false;
      await repo.sync();
      final server = api.sessions[s.clientSessionId]!;
      expect(server.exercises.first.sets.single.reps, 12);
      expect(server.exercises.first.sets.single.weightKg, 82.5);
      expect(api.calls.where((c) => c == 'patchSet'), isEmpty);

      await repo.updateSet(s.clientSessionId, first.clientSetId, reps: 11);
      await repo.sync();
      expect(api.calls.where((c) => c == 'patchSet').length, 1);
      expect(
        api.sessions[s.clientSessionId]!.exercises.first.sets.single.reps,
        11,
      );
    });

    test(
        'deleting an unsynced set drops it from the batch; deleting a synced one is a DELETE',
        () async {
      api.offline = true;
      final s = await repo.startSession(day: api.todayResponse);
      final x = s.exercises.first;
      final a = set(x, 1);
      final b = set(x, 2);
      await repo.logSet(s.clientSessionId, a);
      await repo.logSet(s.clientSessionId, b);
      await repo.deleteSet(s.clientSessionId, b.clientSetId);
      expect(
        (await repo.session(s.clientSessionId))!.exercises.first.sets.length,
        1,
      );
      api.offline = false;
      await repo.sync();
      expect(
        api.sessions[s.clientSessionId]!.exercises.first.sets
            .map((t) => t.clientSetId),
        [a.clientSetId],
      );
      expect(api.calls.where((c) => c == 'deleteSet'), isEmpty);

      await repo.deleteSet(s.clientSessionId, a.clientSetId);
      await repo.sync();
      expect(api.calls.where((c) => c == 'deleteSet').length, 1);
      expect(api.sessions[s.clientSessionId]!.exercises.first.sets, isEmpty);
    });
  });

  group('conflicts and failures', () {
    test('completed on another device: sets are merged in (§33), not lost',
        () async {
      final s = await repo.startSession(day: api.todayResponse);
      await repo.sync();
      // The other device completes it on the server.
      final serverId = api.sessions[s.clientSessionId]!.id;
      await api.complete(
        serverId,
        CompleteSessionRequest(completedAt: stamp()),
      );
      // This phone, unaware, logs two more sets.
      await repo.logSet(s.clientSessionId, set(s.exercises.first, 1));
      await repo.logSet(s.clientSessionId, set(s.exercises.first, 2));
      await repo.sync();
      // Every rejected batch was resent once with merge:true, nothing more.
      final batches = api.calls.where((c) => c.startsWith('logSets')).toList();
      expect(
        batches.where((c) => c.endsWith(':merge')).length,
        batches.where((c) => !c.endsWith(':merge')).length,
      );
      expect(api.sessions[s.clientSessionId]!.exercises.first.sets.length, 2);
      expect((await repo.syncStatus()).clean, isTrue);
    });

    test(
        'a persistent server error parks the entry after five attempts and Retry puts it back',
        () async {
      final s = await repo.startSession(day: api.todayResponse);
      await repo.sync();
      // Make the server reject set logging.
      final failing = _RejectingApi(api);
      final engine2 =
          SyncEngine(db, failing, now: now, baseDelay: Duration.zero);
      final repo2 =
          LocalWorkoutRepository(db, failing, now: now, engine: engine2);
      await repo2.logSet(s.clientSessionId, set(s.exercises.first, 1));
      for (var i = 0; i < 6; i++) {
        await repo2.sync();
      }
      final status = await repo2.syncStatus();
      expect(status.pending, 0);
      expect(status.parked, 1);
      expect(status.lastError, contains('rejected'));
      // The set is still on the phone.
      expect(
        (await repo2.session(s.clientSessionId))!.exercises.first.sets.length,
        1,
      );
      // Retry with the server healthy again.
      failing.reject = false;
      await repo2.retryParked();
      expect((await repo2.syncStatus()).clean, isTrue);
      expect(api.sessions[s.clientSessionId]!.exercises.first.sets.length, 1);
    });

    test(
        'offline is not a failure: attempts are not burned while the network is away',
        () async {
      api.offline = true;
      final s = await repo.startSession(day: api.todayResponse);
      for (var i = 0; i < 20; i++) {
        await repo.sync();
      }
      final status = await repo.syncStatus();
      expect(status.parked, 0);
      expect(status.pending, 1);
      api.offline = false;
      await repo.sync();
      expect(api.sessions[s.clientSessionId], isNotNull);
    });
  });

  group('today', () {
    test('network first, the cache when offline, an error when neither',
        () async {
      api.offline = true;
      expect(await repo.today(), isA<Err<TodayResponse>>());
      api.offline = false;
      final online = await repo.today();
      expect((online as Ok<TodayResponse>).value.sessionName, 'Legs');
      api.offline = true;
      final cached = await repo.today();
      expect((cached as Ok<TodayResponse>).value.sessionName, 'Legs');
    });
  });
}

/// Wraps the fake to reject set batches with a non-transient error.
class _RejectingApi extends FakeWorkoutApi {
  _RejectingApi(this.inner);
  final FakeWorkoutApi inner;
  bool reject = true;

  @override
  Map<String, WorkoutSession> get sessions => inner.sessions;

  @override
  Future<Result<WorkoutSession>> logSets(
    String id,
    LogSetsRequest request,
  ) async {
    if (reject) return const Err(Validation('The server rejected that set.'));
    return inner.logSets(id, request);
  }
}
