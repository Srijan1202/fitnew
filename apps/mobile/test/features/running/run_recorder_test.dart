import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:fitos/core/db/app_database.dart';
import 'package:fitos/core/notifications/activity_signal.dart';
import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/profile/data/profile_repository.dart';
import 'package:fitos/features/running/data/run_sync_engine.dart';
import 'package:fitos/features/running/domain/gps_filter.dart';
import 'package:fitos/features/running/domain/run.dart';
import 'package:fitos/features/running/domain/track.dart';
import 'package:fitos/features/running/domain/workout.dart';
import 'package:fitos/features/running/presentation/controllers/run_recorder.dart';
import 'package:fitos/features/running/presentation/controllers/running_providers.dart';
import 'package:fitos/features/workout/presentation/controllers/workout_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_profile_repository.dart';
import '../../support/fake_running.dart';

/// Beta 4.0 (ADR-038): recording a run on the phone — the timer, the
/// points, pauses and auto-pause, finishing, saving into the queue, the
/// upload, and a run that survives FITOS being closed mid-run.
void main() {
  late AppDatabase db;
  late FakeRunningApi api;
  late FakeLocationSource gps;
  late FakeRunNotification note;
  late FakeRunVoice voice;
  late DateTime clock;
  late ProviderContainer c;

  ProviderContainer open() {
    final container = ProviderContainer(
      overrides: [
        sessionUserIdProvider.overrideWithValue('user-1'),
        appDatabaseProvider.overrideWithValue(db),
        runningApiProvider.overrideWithValue(api),
        locationSourceProvider.overrideWithValue(gps),
        runNotificationProvider.overrideWithValue(note),
        runClockProvider.overrideWithValue(() => clock),
        syncWakesItselfProvider.overrideWithValue(false),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        runVoiceProvider.overrideWithValue(voice),
      ],
    );
    return container;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues(const {});
    db = AppDatabase.inMemory();
    api = FakeRunningApi();
    gps = FakeLocationSource();
    note = FakeRunNotification();
    voice = FakeRunVoice();
    clock = DateTime.utc(2026, 10, 27, 1);
    c = open();
    // Let the recorder's restore find nothing.
    c.read(runRecorderProvider);
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(() async {
    // A save kicks the queue at once; let it finish before the database goes.
    await c.read(runningRepositoryProvider).engine.drain();
    c.dispose();
    await db.close();
  });

  RunRecorder recorder() => c.read(runRecorderProvider.notifier);
  LiveRun run() => c.read(runRecorderProvider)!;

  Future<void> send(Iterable<GpsFix> fixes) async {
    for (final f in fixes) {
      gps.send(f);
      await Future<void>.delayed(Duration.zero);
    }
    await recorder().flush();
  }

  Future<List<LocalRunPoint>> points() => db.select(db.localRunPoints).get();

  test('a run: the timer counts active time, points are stored as they come',
      () async {
    await recorder().start(
      kind: RunKind.outdoor,
      goal: const RunGoal(RunGoalKind.distance, 5000),
    );
    expect(gps.listening, isTrue);
    expect(run().status, RunStatus.recording);
    await send(runNorth(from: clock, seconds: 60));
    clock = clock.add(const Duration(seconds: 60));
    expect(run().track.distanceM, closeTo(177, 6));
    expect((await points()).length, run().track.segments.single.length);
    final row = (await db.select(db.localRuns).get()).single;
    expect(row.status, 'recording');
    expect(row.goalKind, 'distance');
    expect(row.goalValue, 5000);
  });

  test(
      'pause: the timer stops, nothing is stored, and the next stretch is a new segment',
      () async {
    await recorder().start(kind: RunKind.outdoor, goal: const RunGoal.free());
    await send(runNorth(from: clock, seconds: 30));
    clock = clock.add(const Duration(seconds: 30));
    recorder().pause();
    expect(run().status, RunStatus.paused);
    expect(run().activeSeconds, 30);
    final before = (await points()).length;
    await send(runNorth(from: clock, seconds: 20, lat0: 12.9702));
    clock = clock.add(const Duration(minutes: 2));
    expect((await points()).length, before);
    expect(c.read(runRecorderProvider)!.activeSeconds, 30);
    recorder().resume();
    await send(runNorth(from: clock, seconds: 30, lat0: 12.9710));
    clock = clock.add(const Duration(seconds: 30));
    await recorder().finish();
    expect(run().status, RunStatus.finished);
    expect(run().activeSeconds, 60);
    final segs = (await points()).map((p) => p.segment).toSet();
    expect(segs.length, 2);
    expect(gps.listening, isFalse);
    final row = (await db.select(db.localRuns).get()).single;
    expect(row.status, 'finished');
    expect(row.activeMs, 60000);
    expect(row.endedAt, isNotNull);
  });

  test('auto-pause stops the timer at a crossing and starts it again',
      () async {
    await recorder().start(kind: RunKind.outdoor, goal: const RunGoal.free());
    await send(runNorth(from: clock, seconds: 20));
    final stop = clock.add(const Duration(seconds: 20));
    await send(runNorth(from: stop, seconds: 10, speed: 0, lat0: 12.96974));
    expect(run().status, RunStatus.autoPaused);
    await send(
      runNorth(
        from: stop.add(const Duration(seconds: 40)),
        seconds: 10,
        lat0: 12.96974,
      ),
    );
    expect(run().status, RunStatus.recording);
    expect(run().track.segments.length, 2);
  });

  test('auto-pause can be switched off', () async {
    await c.read(runSettingsProvider.notifier).setAutoPause(false);
    await recorder().start(kind: RunKind.outdoor, goal: const RunGoal.free());
    await send(runNorth(from: clock, seconds: 20, speed: 0));
    expect(run().status, RunStatus.recording);
  });

  test(
      'saving queues the run with its track; the upload replaces the phone’s copy with the server’s',
      () async {
    await recorder().start(kind: RunKind.outdoor, goal: const RunGoal.free());
    await send(runNorth(from: clock, seconds: 120));
    clock = clock.add(const Duration(seconds: 120));
    final id = run().id;
    final track = await c.read(runningRepositoryProvider).store.track(id);
    final saved =
        await recorder().save(name: 'Lake loop', note: 'Easy', effort: 3);
    expect(saved, id);
    expect(c.read(runRecorderProvider), isNull);
    final queued = (await db.select(db.runSyncQueue).get()).single;
    final body = jsonDecode(queued.payloadJson) as Map<String, dynamic>;
    expect(body['name'], 'Lake loop');
    expect(body['effort'], 3);
    expect(body['durationSeconds'], 120);
    final sent = decodeTrack(
      EncodedTrack.fromJson(body['track'] as Map<String, dynamic>),
    );
    expect(sent.segments.single, track.segments.single);

    api.failWith = null;
    await c.read(runningRepositoryProvider).engine.drain();
    expect(api.calls, ['create $id']);
    expect(await db.select(db.localRuns).get(), isEmpty);
    expect(await points(), isEmpty);
    expect(await db.select(db.runSyncQueue).get(), isEmpty);
    final detail = await c.read(runningRepositoryProvider).local(id);
    expect(detail!.pending, isFalse);
    expect(detail.summary.name, 'Lake loop');
  });

  test('a treadmill run: no GPS, the typed distance', () async {
    await recorder().start(
      kind: RunKind.treadmill,
      goal: const RunGoal(RunGoalKind.time, 1200),
    );
    expect(gps.listens, 0);
    clock = clock.add(const Duration(minutes: 25));
    await recorder().finish();
    await recorder().save(name: 'Treadmill run', treadmillDistanceM: 5000);
    final body =
        jsonDecode((await db.select(db.runSyncQueue).get()).single.payloadJson)
            as Map<String, dynamic>;
    expect(body['kind'], 'treadmill');
    expect(body['distanceM'], 5000);
    expect(body.containsKey('track'), isFalse);
  });

  test(
      'beta 4.1: a run cancels today’s workout reminder as it starts, and "missed" once saved',
      () async {
    final seen = <ActivityKind>[];
    final sub = ActivitySignal.stream.listen((a) => seen.add(a.kind));
    addTearDown(sub.cancel);
    await recorder().start(kind: RunKind.treadmill, goal: const RunGoal.free());
    expect(seen, [ActivityKind.workoutStarted]);
    clock = clock.add(const Duration(minutes: 20));
    await recorder().finish();
    await recorder().save(name: 'Treadmill run', treadmillDistanceM: 4000);
    expect(seen, [ActivityKind.workoutStarted, ActivityKind.workoutCompleted]);
  });

  test('discard leaves nothing', () async {
    await recorder().start(kind: RunKind.outdoor, goal: const RunGoal.free());
    await send(runNorth(from: clock, seconds: 10));
    await recorder().discard();
    expect(c.read(runRecorderProvider), isNull);
    expect(await db.select(db.localRuns).get(), isEmpty);
    expect(await points(), isEmpty);
    expect(gps.listening, isFalse);
  });

  test('FITOS closed mid-run: the run comes back paused at its last point',
      () async {
    await recorder().start(kind: RunKind.outdoor, goal: const RunGoal.free());
    await send(runNorth(from: clock, seconds: 90));
    final distance = run().track.distanceM;
    // The app dies; the phone is in a pocket for ten more minutes.
    c.dispose();
    clock = clock.add(const Duration(minutes: 10));
    c = open();
    c.read(runRecorderProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final back = c.read(runRecorderProvider)!;
    expect(back.status, RunStatus.paused);
    expect(back.restored, isTrue);
    // Up to the last stored point (89 s), not the ten minutes after.
    expect(back.activeSeconds, 89);
    expect(back.track.distanceM, closeTo(distance, 0.01));
    // Resuming listens again and adds a new segment.
    c.read(runRecorderProvider.notifier).resume();
    expect(gps.listening, isTrue);
    await c.read(runRecorderProvider.notifier).flush();
    final row = (await db.select(db.localRuns).get()).single;
    expect(row.status, 'recording');
    expect(row.segment, 1);
  });

  test('a finished run waiting for Save comes back finished', () async {
    await recorder().start(kind: RunKind.outdoor, goal: const RunGoal.free());
    await send(runNorth(from: clock, seconds: 30));
    clock = clock.add(const Duration(seconds: 30));
    await recorder().finish();
    c.dispose();
    c = open();
    c.read(runRecorderProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(c.read(runRecorderProvider)!.status, RunStatus.finished);
    expect(c.read(runRecorderProvider)!.activeSeconds, 30);
  });

  test('the notification shows the distance and the pace while running',
      () async {
    await recorder().start(kind: RunKind.outdoor, goal: const RunGoal.free());
    await send(runNorth(from: clock, seconds: 40));
    recorder().pause();
    await Future<void>.delayed(Duration.zero);
    expect(note.shown.last, startsWith('Run paused |'));
  });

  group('the queue', () {
    Future<String> saved({String name = 'Run'}) async {
      await recorder().start(kind: RunKind.outdoor, goal: const RunGoal.free());
      await send(runNorth(from: clock, seconds: 60));
      clock = clock.add(const Duration(seconds: 60));
      return (await recorder().save(name: name))!;
    }

    test('offline: nothing charged, the run stays on the phone', () async {
      api.failWith = const Offline();
      final id = await saved();
      await c.read(runningRepositoryProvider).engine.drain();
      final q = (await db.select(db.runSyncQueue).get()).single;
      expect(q.attempts, 0);
      expect(q.parked, isFalse);
      expect((await db.select(db.localRuns).get()).single.clientRunId, id);
      c.listen(unsyncedRunsProvider, (_, __) {});
      final history = await c.read(unsyncedRunsProvider.future);
      expect(history.single.name, 'Run');
    });

    test('a refusal is parked with its words; Retry sends it again', () async {
      await saved();
      api.failWith =
          const Validation('The track ends in the middle of a value.');
      final engine = c.read(runningRepositoryProvider).engine;
      await engine.drain();
      final q = (await db.select(db.runSyncQueue).get()).single;
      expect(q.parked, isTrue);
      expect(q.lastError, contains('middle'));
      api.failWith = null;
      await engine.retryParked();
      await engine.drain();
      expect(await db.select(db.runSyncQueue).get(), isEmpty);
    });

    test('an edit before the upload leaves rides in the upload', () async {
      api.failWith = const Offline();
      final id = await saved();
      await c
          .read(runningRepositoryProvider)
          .edit(id, name: 'Renamed', effort: 7);
      final body = jsonDecode(
        (await db.select(db.runSyncQueue).get()).single.payloadJson,
      ) as Map<String, dynamic>;
      expect(body['name'], 'Renamed');
      expect(body['effort'], 7);
      await c
          .read(runningRepositoryProvider)
          .edit(id, clearEffort: true, note: '');
      final again = jsonDecode(
        (await db.select(db.runSyncQueue).get()).single.payloadJson,
      ) as Map<String, dynamic>;
      expect(again.containsKey('effort'), isFalse);
      expect(again.containsKey('note'), isFalse);
    });

    test('an edit after the upload is its own request', () async {
      final id = await saved();
      final repo = c.read(runningRepositoryProvider);
      await repo.engine.drain();
      await repo.edit(id, name: 'Later');
      await repo.engine.drain();
      expect(api.calls, ['create $id', 'patch $id']);
      expect(api.stored[id]!['name'], 'Later');
    });

    test('deleting a run the server never had removes it at once', () async {
      api.failWith = const Offline();
      final id = await saved();
      await c.read(runningRepositoryProvider).delete(id);
      expect(await db.select(db.runSyncQueue).get(), isEmpty);
      expect(await db.select(db.localRuns).get(), isEmpty);
      expect(api.calls.where((x) => !x.startsWith('create')), isEmpty);
      api.failWith = null;
      await c.read(runningRepositoryProvider).engine.drain();
      expect(api.stored, isEmpty);
    });

    test('deleting an uploaded run asks the server; the cache goes too',
        () async {
      final id = await saved();
      final repo = c.read(runningRepositoryProvider);
      await repo.engine.drain();
      await repo.delete(id);
      await repo.engine.drain();
      expect(api.calls.last, 'delete $id');
      expect(await repo.local(id), isNull);
      // Already gone on the server: done all the same.
      await repo.engine.enqueue(RunSyncKind.delete, id, const {});
      await repo.engine.drain();
      expect(await db.select(db.runSyncQueue).get(), isEmpty);
    });

    test('signed out: the drain stops and waits', () async {
      api.failWith = const Unauthenticated();
      await saved();
      await c.read(runningRepositoryProvider).engine.drain();
      expect((await db.select(db.runSyncQueue).get()).single.attempts, 0);
    });

    test('other failures back off, then park after five', () async {
      api.failWith = const Unknown();
      await saved();
      final engine = c.read(runningRepositoryProvider).engine;
      for (var i = 0; i < 5; i++) {
        await (db.update(db.runSyncQueue))
            .write(const RunSyncQueueCompanion(nextAttemptAt: Value(null)));
        await engine.drain();
      }
      final q = (await db.select(db.runSyncQueue).get()).single;
      expect(q.attempts, 5);
      expect(q.parked, isTrue);
    });
  });

  test(
      'a phone on beta 3.9 (schema 3) upgrades: the run tables appear, a queued food log stays',
      () async {
    final dir = Directory.systemTemp.createTempSync('fitos-runs');
    final file = File('${dir.path}/fitos.sqlite');
    addTearDown(() => dir.deleteSync(recursive: true));
    final v3 = AppDatabase(NativeDatabase(file));
    await v3.into(v3.nutritionSyncQueue).insert(
          NutritionSyncQueueCompanion.insert(
            kind: 'create',
            clientLogId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
            payloadJson: '{}',
            createdAt: '2026-10-26T06:00:00.000Z',
          ),
        );
    await v3.customStatement('DROP TABLE local_runs');
    await v3.customStatement('DROP TABLE local_run_points');
    await v3.customStatement('DROP TABLE run_sync_queue');
    await v3.customStatement('PRAGMA user_version = 3');
    await v3.close();

    final v4 = AppDatabase(NativeDatabase(file));
    addTearDown(v4.close);
    expect(
      (await v4.select(v4.nutritionSyncQueue).get()).single.kind,
      'create',
    );
    expect(await v4.select(v4.localRuns).get(), isEmpty);
    await v4.into(v4.runSyncQueue).insert(
          RunSyncQueueCompanion.insert(
            kind: 'create',
            clientRunId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
            payloadJson: '{}',
            createdAt: '2026-10-27T06:00:00.000Z',
          ),
        );
    expect(await v4.select(v4.runSyncQueue).get(), hasLength(1));
    final version = await v4.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.single, v4.schemaVersion);
  });

  test(
      'a phone on beta 4.0 (schema 4) upgrades: a run row gains its workout, laps and plan columns, and an unsent run stays',
      () async {
    final dir = Directory.systemTemp.createTempSync('fitos-runs5');
    final file = File('${dir.path}/fitos.sqlite');
    addTearDown(() => dir.deleteSync(recursive: true));
    final old = AppDatabase(NativeDatabase(file));
    await old.into(old.localRuns).insert(
          LocalRunsCompanion.insert(
            clientRunId: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
            kind: 'outdoor',
            status: 'saved',
            goalKind: 'free',
            startedAt: '2026-10-27T01:00:00.000Z',
            updatedAt: '2026-10-27T01:30:00.000Z',
          ),
        );
    for (final c in [
      'workout_json',
      'laps_json',
      'planned_run_id',
      // Beta 4.9's too: a 4.0 table had neither.
      'goal_target_seconds',
      'goal_split',
    ]) {
      await old.customStatement('ALTER TABLE local_runs DROP COLUMN $c');
    }
    await old.customStatement('PRAGMA user_version = 4');
    await old.close();

    final now = AppDatabase(NativeDatabase(file));
    addTearDown(now.close);
    final row = (await now.select(now.localRuns).get()).single;
    expect(row.clientRunId, 'dddddddd-dddd-4ddd-8ddd-dddddddddddd');
    expect(row.workoutJson, isNull);
    await (now.update(now.localRuns))
        .write(const LocalRunsCompanion(plannedRunId: Value('p1')));
    expect((await now.select(now.localRuns).get()).single.plannedRunId, 'p1');
  });

  test(
      'a phone on beta 4.1–4.8 (schema 5) upgrades: a run row gains the race target and split, and an unsent run stays',
      () async {
    final dir = Directory.systemTemp.createTempSync('fitos-runs6');
    final file = File('${dir.path}/fitos.sqlite');
    addTearDown(() => dir.deleteSync(recursive: true));
    final old = AppDatabase(NativeDatabase(file));
    await old.into(old.localRuns).insert(
          LocalRunsCompanion.insert(
            clientRunId: 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
            kind: 'outdoor',
            status: 'saved',
            goalKind: 'distance',
            goalValue: const Value(5000),
            startedAt: '2026-10-29T01:00:00.000Z',
            updatedAt: '2026-10-29T01:30:00.000Z',
          ),
        );
    for (final c in ['goal_target_seconds', 'goal_split']) {
      await old.customStatement('ALTER TABLE local_runs DROP COLUMN $c');
    }
    await old.customStatement('PRAGMA user_version = 5');
    await old.close();

    final now = AppDatabase(NativeDatabase(file));
    addTearDown(now.close);
    final row = (await now.select(now.localRuns).get()).single;
    expect(row.goalValue, 5000);
    expect(row.goalTargetSeconds, isNull);
    await (now.update(now.localRuns)).write(
      const LocalRunsCompanion(
        goalKind: Value('race'),
        goalTargetSeconds: Value(1500),
        goalSplit: Value('negative'),
      ),
    );
    final race = (await now.select(now.localRuns).get()).single;
    expect(
      RunGoal.stored(
        race.goalKind,
        race.goalValue,
        race.goalTargetSeconds,
        race.goalSplit,
      ),
      const RunGoal.race(5000, 1500, RaceSplit.negative),
    );
  });

  group('beta 4.1: sessions, plans and the coach', () {
    const session = RunWorkout(
      name: 'Two reps',
      steps: [
        WorkoutStep(
          kind: StepKind.work,
          distanceM: 100,
          effort: 'hard',
          repIndex: 1,
          repOf: 2,
        ),
        WorkoutStep(
          kind: StepKind.recover,
          seconds: 10,
          effort: 'stand',
          repIndex: 1,
          repOf: 2,
        ),
        WorkoutStep(
          kind: StepKind.work,
          distanceM: 100,
          effort: 'hard',
          repIndex: 2,
          repOf: 2,
        ),
      ],
    );

    Future<void> step(
      int seconds, {
      double speed = 3,
      double lat0 = 12.9692,
    }) async {
      await send(
        runNorth(from: clock, seconds: seconds, speed: speed, lat0: lat0),
      );
      clock = clock.add(Duration(seconds: seconds));
      recorder().tick();
      await recorder().flush();
    }

    test(
        'a session calls each step, keeps its laps, never auto-pauses, and goes up with the run',
        () async {
      api.failWith = const Offline();
      await recorder().start(
        kind: RunKind.outdoor,
        goal: const RunGoal.free(),
        workout: session,
      );
      expect(voice.said.single, 'Rep 1 of 2. 100 metres hard.');
      expect(run().session!.index, 0);
      await step(40);
      expect(run().session!.index, 1);
      expect(voice.said.last, 'Recover. 10 seconds, stand.');
      // Standing for the rest: auto-pause stays out of a session.
      await step(12, speed: 0, lat0: 12.9692 + 117 / 111195);
      expect(run().status, RunStatus.recording);
      expect(run().session!.index, 2);
      expect(voice.said.last, 'Go! Rep 2 of 2. 100 metres hard.');
      recorder().nextStep();
      expect(run().session!.done, isTrue);
      expect(voice.said.last, 'Workout done. Well run.');
      await recorder().finish();
      await recorder().save(name: 'Reps');
      final body = jsonDecode(
        (await db.select(db.runSyncQueue).get()).single.payloadJson,
      ) as Map<String, dynamic>;
      expect((body['workout'] as Map)['name'], 'Two reps');
      expect(
        [for (final m in body['laps'] as List) (m as Map)['step']],
        [0, 1, 2],
      );
    });

    test(
        'a planned run: its id goes up; a structured planned run is its session',
        () async {
      api.failWith = const Offline();
      final planned = PlannedRun.fromJson(
        plannedRunJson(
          id: 'p1',
          date: '2026-10-27',
          kind: 'intervals',
          title: 'Intervals',
          distanceM: null,
          steps: session.steps,
        ),
      );
      await recorder().start(
        kind: RunKind.outdoor,
        goal: const RunGoal.free(),
        planned: planned,
      );
      expect(run().plannedTitle, 'Intervals');
      expect(run().session!.name, 'Intervals');
      await recorder().finish();
      await recorder().save(name: 'Intervals');
      final body = jsonDecode(
        (await db.select(db.runSyncQueue).get()).single.payloadJson,
      ) as Map<String, dynamic>;
      expect(body['plannedRunId'], 'p1');
      expect((body['workout'] as Map)['steps'], hasLength(3));
    });

    test('a treadmill cannot run a distance session: it runs as a steady run',
        () async {
      await recorder().start(
        kind: RunKind.treadmill,
        goal: const RunGoal.free(),
        workout: session,
      );
      expect(run().session, isNull);
    });

    test('the coach: a km call, pause and resume; nothing with the voice off',
        () async {
      await recorder().start(kind: RunKind.outdoor, goal: const RunGoal.free());
      await step(340);
      expect(
        voice.said.where((s) => s.startsWith('1 kilometre.')),
        hasLength(1),
      );
      recorder().pause();
      expect(voice.said.last, 'Paused.');
      recorder().resume();
      expect(voice.said.last, 'Resumed.');
      final before = voice.said.length;
      await c.read(runSettingsProvider.notifier).setVoice(false);
      recorder().pause();
      expect(voice.said.length, before);
    });

    test('a session survives FITOS being closed: it comes back at its step',
        () async {
      await recorder().start(
        kind: RunKind.outdoor,
        goal: const RunGoal.free(),
        workout: session,
      );
      await step(40);
      expect(run().session!.index, 1);
      c.dispose();
      c = open();
      c.read(runRecorderProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final back = c.read(runRecorderProvider)!;
      expect(back.session!.index, 1);
      expect(back.session!.name, 'Two reps');
    });
  });
}
