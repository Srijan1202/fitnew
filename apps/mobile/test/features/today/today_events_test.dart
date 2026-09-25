import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:fitos/core/db/app_database.dart';
import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/features/today/data/today_event_sync.dart';
import 'package:fitos/features/today/data/today_repository.dart';
import 'package:fitos/features/today/domain/today.dart';
import 'package:fitos/features/today/domain/today_completion.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_today_api.dart';

/// Phase 11 — TODAY's events on the phone: recorded once each (ledger),
/// queued in their own FIFO (Drift v3 `today_event_queue`) and drained by
/// the TodayEventSync — never the workout or nutrition engines. Offline,
/// reconnect, kill / reopen, exact replay, 409 / 422 / 404 that must not
/// retry, 401 recovery, the five-attempt budget, and the local P2 guard.
void main() {
  const date = '2026-09-24';
  late AppDatabase db;
  late FakeTodayApi api;
  late DateTime clock;
  late TodayRepository repo;

  TodayRepository open(AppDatabase on) => TodayRepository(
        on,
        api,
        TodayEventSync(on, api, now: () => clock, wakeItself: false),
        now: () => clock,
      );

  setUp(() {
    db = AppDatabase.inMemory();
    api = FakeTodayApi(date: date);
    clock = DateTime.utc(2026, 9, 24, 6, 30);
    repo = open(db);
  });

  tearDown(() async {
    await repo.drain(); // a drain a record() started finishes first
    repo.dispose();
    await db.close();
  });

  final start = FakeTodayApi.action(TodayKind.startWorkout, id: 'a-start');
  final rest = FakeTodayApi.action(TodayKind.restDay, id: 'a-rest');
  final eat = FakeTodayApi.action(
    TodayKind.eatMeal,
    id: 'a-eat',
    subjectKey: 'lunch',
  );

  Future<List<TodayEventQueueData>> queue() =>
      (db.select(db.todayEventQueue)..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .get();

  /// The events recorded on this phone, in order.
  Future<List<String>> recorded() async => [
        for (final r in await (db.select(db.todayEventLedger)
              ..orderBy([(t) => OrderingTerm.asc(t.occurredAt)]))
            .get())
          '${r.recommendationId}:${r.event}',
      ];

  Future<Map<String, String>> ledgerStatus() async => {
        for (final r in await db.select(db.todayEventLedger).get())
          '${r.recommendationId}:${r.event}': r.status,
      };

  Future<void> drain() => repo.drain();

  group('recording (ledger + local P2 guard)', () {
    test('shown is recorded once however often a card is drawn', () async {
      expect(await repo.record(start.ref, date, TodayEventName.shown), isTrue);
      expect(await repo.record(start.ref, date, TodayEventName.shown), isFalse);
      expect(await repo.record(start.ref, date, TodayEventName.shown), isFalse);
      await drain();
      expect(await recorded(), ['a-start:shown']);
      expect(api.sent, ['a-start:shown']);
    });

    test('interacting with a card records the missing shown first, in order',
        () async {
      await repo.record(start.ref, date, TodayEventName.opened);
      await drain();
      expect(api.sent, ['a-start:shown', 'a-start:opened']);
      final at = [
        for (final e in api.events) DateTime.parse(e.request.occurredAt),
      ];
      expect(at[0].isBefore(at[1]), isTrue);
    });

    test('no completed before accepted; opened is not required', () async {
      await repo.record(start.ref, date, TodayEventName.shown);
      expect(
        await repo.record(start.ref, date, TodayEventName.completed),
        isFalse,
      );
      expect(
        await repo.record(start.ref, date, TodayEventName.accepted),
        isTrue,
      );
      expect(
        await repo.record(start.ref, date, TodayEventName.completed),
        isTrue,
      );
      await drain();
      expect(
        api.sent,
        ['a-start:shown', 'a-start:accepted', 'a-start:completed'],
      );
    });

    test('informational actions are never completed', () async {
      await repo.record(rest.ref, date, TodayEventName.accepted);
      expect(
        await repo.record(rest.ref, date, TodayEventName.completed),
        isFalse,
      );
      expect(TodayKind.restDay.completable, isFalse);
      expect(TodayKind.celebratePr.completable, isFalse);
      expect(TodayKind.injuredLimitation.completable, isFalse);
    });

    test('dismissed shuts the rest; accepted and dismissed exclude each other',
        () async {
      await repo.record(eat.ref, date, TodayEventName.dismissed);
      for (final e in [
        TodayEventName.opened,
        TodayEventName.accepted,
        TodayEventName.completed,
      ]) {
        expect(await repo.record(eat.ref, date, e), isFalse, reason: e.wire);
      }
      await repo.record(start.ref, date, TodayEventName.accepted);
      expect(
        await repo.record(start.ref, date, TodayEventName.dismissed),
        isFalse,
      );
    });

    test('the local guard is the approved matrix', () {
      const s = TodayEventName.shown;
      const o = TodayEventName.opened;
      const a = TodayEventName.accepted;
      const d = TodayEventName.dismissed;
      const c = TodayEventName.completed;
      LocalTransition t(Set<TodayEventName> have, TodayEventName next) =>
          localTransition(TodayKind.eatMeal, have, next);
      // Valid.
      expect(t({}, s), LocalTransition.record);
      expect(t({s}, o), LocalTransition.record);
      expect(t({s}, a), LocalTransition.record);
      expect(t({s, o}, a), LocalTransition.record);
      expect(t({s, a}, c), LocalTransition.record);
      expect(t({s, o, a}, c), LocalTransition.record);
      expect(t({s}, d), LocalTransition.record);
      expect(t({s, o}, d), LocalTransition.record);
      // Invalid.
      expect(t({s}, c), LocalTransition.invalid);
      for (final e in [o, a, d, c]) {
        expect(t({}, e), LocalTransition.invalid, reason: 'no shown: $e');
      }
      expect(t({s, d}, a), LocalTransition.invalid);
      expect(t({s, d}, o), LocalTransition.invalid);
      expect(t({s, d}, c), LocalTransition.invalid);
      expect(t({s, a}, d), LocalTransition.invalid);
      expect(
        localTransition(TodayKind.restDay, {s, a}, c),
        LocalTransition.invalid,
      );
      // A repeat is a replay, not a new event.
      expect(t({s}, s), LocalTransition.duplicate);
    });
  });

  group('the TODAY queue (its own engine)', () {
    test(
        'FIFO: 201 / 200 remove the entry; the ledger keeps it as sent; the same client id and time go out',
        () async {
      api.eventFailure = const Offline();
      await repo.record(start.ref, date, TodayEventName.accepted);
      await drain();
      final queued = await queue();
      expect(queued.map((q) => q.event), ['shown', 'accepted']);
      api
        ..eventFailure = null
        ..events.clear();
      await drain();
      expect(api.sent, ['a-start:shown', 'a-start:accepted']);
      expect(await queue(), isEmpty);
      expect(await ledgerStatus(), {
        'a-start:shown': 'sent',
        'a-start:accepted': 'sent',
      });
      expect(
        api.events.map((e) => e.request.clientEventId),
        queued.map((q) => q.clientEventId),
      );
      expect(
        api.events.map((e) => e.request.occurredAt),
        queued.map((q) => q.occurredAt),
      );
    });

    test(
        'offline: events stay queued with nothing charged; reconnect delivers them once, in order',
        () async {
      api.eventFailure = const Offline();
      await repo.record(start.ref, date, TodayEventName.accepted);
      await repo.record(eat.ref, date, TodayEventName.dismissed);
      await drain();
      final waiting = await queue();
      expect(waiting, hasLength(4));
      expect(waiting.every((q) => q.attempts == 0), isTrue);
      final ids = waiting.map((q) => q.clientEventId).toList();

      api
        ..eventFailure = null
        ..events.clear();
      await drain();
      expect(api.sent, [
        'a-start:shown',
        'a-start:accepted',
        'a-eat:shown',
        'a-eat:dismissed',
      ]);
      expect(api.events.map((e) => e.request.clientEventId), ids);
      expect(await queue(), isEmpty);
    });

    test(
        'kill and reopen: the queue survives on disk and drains with the SAME client ids (an exact replay)',
        () async {
      final dir = Directory.systemTemp.createTempSync('fitos-today');
      final file = File('${dir.path}/fitos.sqlite');
      addTearDown(() => dir.deleteSync(recursive: true));

      var disk = AppDatabase(NativeDatabase(file));
      var onDisk = open(disk);
      api.eventFailure = const Offline();
      await onDisk.record(start.ref, date, TodayEventName.accepted);
      await onDisk.drain();
      final before = [
        for (final q in await disk.select(disk.todayEventQueue).get())
          q.clientEventId,
      ];
      onDisk.dispose();
      await disk.close();

      // The app comes back, online.
      api
        ..eventFailure = null
        ..events.clear();
      disk = AppDatabase(NativeDatabase(file));
      onDisk = open(disk);
      await onDisk.drain();
      expect(api.events.map((e) => e.request.clientEventId), before);
      expect(await disk.select(disk.todayEventQueue).get(), isEmpty);
      // Recording again after the restart is not a second event.
      expect(
        await onDisk.record(start.ref, date, TodayEventName.accepted),
        isFalse,
      );
      await onDisk.drain();
      onDisk.dispose();
      await disk.close();
    });

    test(
        'a retry after a lost answer re-sends the same client id (the server answers 200, no duplicate)',
        () async {
      api.eventAnswers.addAll([const Unknown()]);
      await repo.record(start.ref, date, TodayEventName.shown);
      await drain(); // the record's own drain: one attempt, then a backoff
      final first = api.events.single.request.clientEventId;
      expect((await queue()).single.attempts, 1);
      clock = clock.add(const Duration(seconds: 1));
      await drain();
      expect(api.events, hasLength(2));
      expect(api.events.last.request.clientEventId, first);
      expect(await queue(), isEmpty);
    });

    test('409 (client id collision) leaves the queue at once — no retry',
        () async {
      api.eventAnswers.add(const Conflict('reused'));
      await repo.record(start.ref, date, TodayEventName.shown);
      await drain();
      clock = clock.add(const Duration(minutes: 5));
      await drain();
      expect(api.events, hasLength(1));
      expect(await queue(), isEmpty);
      expect((await ledgerStatus())['a-start:shown'], 'rejected');
    });

    test('422 (refused transition, time or evidence) and 404 leave at once',
        () async {
      api.eventAnswers.addAll([
        const Validation('outside the window'),
        const NotFound(),
      ]);
      await repo.record(start.ref, date, TodayEventName.shown);
      await repo.record(eat.ref, date, TodayEventName.shown);
      await drain();
      clock = clock.add(const Duration(minutes: 5));
      await drain();
      expect(api.events, hasLength(2));
      expect(await queue(), isEmpty);
      expect(await ledgerStatus(), {
        'a-start:shown': 'rejected',
        'a-eat:shown': 'rejected',
      });
    });

    test('401: stop without charging; the next sign-in drains the same events',
        () async {
      api.eventFailure = const Unauthenticated();
      await repo.record(start.ref, date, TodayEventName.accepted);
      await drain();
      await drain();
      final waiting = await queue();
      expect(waiting.map((q) => q.event), ['shown', 'accepted']);
      expect(waiting.every((q) => q.attempts == 0), isTrue);
      // Each drain tried the head only, then stopped.
      expect(api.sent.toSet(), {'a-start:shown'});
      api
        ..eventFailure = null
        ..events.clear();
      await drain();
      expect(api.sent, ['a-start:shown', 'a-start:accepted']);
      expect(await queue(), isEmpty);
    });

    test(
        'a failing server: backoff 300 ms · 2ⁿ, five attempts, then it leaves as failed; the action waits behind it',
        () async {
      api.eventFailure = const Unknown();
      await repo.record(start.ref, date, TodayEventName.accepted);
      await drain();
      for (var attempt = 2; attempt <= 4; attempt++) {
        // Waiting out its backoff, the head holds the action's next event.
        expect(api.sent.toSet(), {'a-start:shown'});
        clock = clock.add(const Duration(seconds: 10));
        await drain();
      }
      expect(api.sent, List.filled(4, 'a-start:shown'));
      clock = clock.add(const Duration(seconds: 10));
      await drain();
      // The fifth attempt spends the budget: the entry leaves as failed,
      // and only then does `accepted` go (never before `shown`).
      expect(api.sent.take(5), List.filled(5, 'a-start:shown'));
      expect(api.sent[5], 'a-start:accepted');
      expect((await ledgerStatus())['a-start:shown'], 'failed');
      expect((await queue()).single.event, 'accepted');
    });

    test('another action is not held up by one waiting out a backoff',
        () async {
      api.eventFailure = const Offline();
      await repo.record(start.ref, date, TodayEventName.shown);
      await repo.record(eat.ref, date, TodayEventName.shown);
      await drain();
      api
        ..eventFailure = null
        ..events.clear()
        ..eventAnswers.add(const Unknown());
      await drain();
      expect(api.sent, ['a-start:shown', 'a-eat:shown']);
      expect((await queue()).single.recommendationId, 'a-start');
    });
  });

  group('the plan cache', () {
    test(
        'a valid answer is cached; a failed fetch leaves the last one in place',
        () async {
      api.plan = TodayPlan(
        date: date,
        generatedAt: '${date}T06:30:00.000Z',
        engineVersion: 'today-1',
        actions: [start],
      );
      expect(await repo.refresh(), isA<Ok<TodayPlan>>());
      api.todayFailure = const Offline();
      expect(await repo.refresh(), isA<Err<TodayPlan>>());
      final cached = await repo.cached();
      expect(cached!.plan.actions.single.id, 'a-start');
      expect(cached.storedAt, '2026-09-24T06:30:00.000Z');
    });
  });

  group('completion evidence (never on accept alone)', () {
    LedgerEntry e(
      String id,
      TodayKind k,
      TodayEventName ev, {
      String subject = '',
      String status = 'sent',
    }) =>
        LedgerEntry(
          recommendationId: id,
          event: ev,
          kind: k.wire,
          subjectKey: subject,
          localDate: date,
          status: status,
        );

    List<String> due(List<LedgerEntry> l, CompletionEvidence ev) =>
        dueCompletions(l, ev).map((a) => a.id).toList();

    test('each completable kind completes on its own server evidence only', () {
      final ledger = [
        e('s', TodayKind.startWorkout, TodayEventName.accepted),
        e('p', TodayKind.progressLoad, TodayEventName.accepted, subject: 'ex1'),
        e(
          'm',
          TodayKind.muscleNeglected,
          TodayEventName.accepted,
          subject: 'calves',
        ),
        e('f', TodayKind.eatMeal, TodayEventName.accepted, subject: 'lunch'),
        e('w', TodayKind.logWeight, TodayEventName.accepted),
        e('d', TodayKind.deload, TodayEventName.accepted),
      ];
      expect(due(ledger, const CompletionEvidence(date: date)), isEmpty);
      expect(
        due(
          ledger,
          const CompletionEvidence(
            date: date,
            sessionCompleted: true,
            sessionExerciseIds: {'ex1'},
            sessionPrimaryMuscles: {'quads'},
            loggedSlots: {'dinner'},
          ),
        ),
        ['s', 'p'],
      );
      expect(
        due(
          ledger,
          const CompletionEvidence(
            date: date,
            sessionPrimaryMuscles: {'calves'},
            loggedSlots: {'lunch'},
            weighed: true,
            deloadActive: true,
          ),
        ),
        ['m', 'f', 'w', 'd'],
      );
    });

    test(
        'Phase 12: calorie-adjust completes only on its own evidence (the new target row), after accept',
        () {
      final ledger = [
        e('c', TodayKind.calorieAdjust, TodayEventName.accepted),
      ];
      expect(due(ledger, const CompletionEvidence(date: date)), isEmpty);
      expect(
        due(ledger, const CompletionEvidence(date: date, weighed: true)),
        isEmpty,
      );
      expect(
        due(ledger, const CompletionEvidence(date: date, targetAdjusted: true)),
        ['c'],
      );
      expect(
        due(
          [e('c', TodayKind.calorieAdjust, TodayEventName.shown)],
          const CompletionEvidence(date: date, targetAdjusted: true),
        ),
        isEmpty,
      );
      expect(TodayKind.calorieAdjust.completable, isTrue);
    });

    test(
        'not without accepted, not twice, not after dismissed, not for informational kinds, not for another day',
        () {
      const all = CompletionEvidence(
        date: date,
        sessionCompleted: true,
        weighed: true,
      );
      expect(
        due([e('s', TodayKind.startWorkout, TodayEventName.shown)], all),
        isEmpty,
      );
      expect(
        due(
          [
            e('s', TodayKind.startWorkout, TodayEventName.accepted),
            e('s', TodayKind.startWorkout, TodayEventName.completed),
          ],
          all,
        ),
        isEmpty,
      );
      expect(
        due(
          [
            e(
              's',
              TodayKind.startWorkout,
              TodayEventName.accepted,
              status: 'rejected',
            ),
          ],
          all,
        ),
        isEmpty,
      );
      expect(
        due([e('r', TodayKind.restDay, TodayEventName.accepted)], all),
        isEmpty,
      );
      expect(
        due(
          [
            const LedgerEntry(
              recommendationId: 'w',
              event: TodayEventName.accepted,
              kind: 'log-weight',
              subjectKey: '',
              localDate: '2026-09-23',
              status: 'sent',
            ),
          ],
          all,
        ),
        isEmpty,
      );
    });
  });

  group('drift schema v2 → v3 (Phase 11)', () {
    test(
        'an upgrade adds the TODAY queue and ledger and keeps a queued workout and a queued food log',
        () async {
      final dir = Directory.systemTemp.createTempSync('fitos-drift-v3');
      final file = File('${dir.path}/fitos.sqlite');
      addTearDown(() => dir.deleteSync(recursive: true));

      // A phone on the Phase 8–10 app: schema 2, unsent work in both queues.
      final v2 = AppDatabase(NativeDatabase(file));
      await v2.into(v2.syncQueue).insert(
            SyncQueueCompanion.insert(
              kind: 'start',
              clientSessionId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
              payloadJson: '{}',
              createdAt: '2026-09-24T05:00:00.000Z',
            ),
          );
      await v2.into(v2.nutritionSyncQueue).insert(
            NutritionSyncQueueCompanion.insert(
              kind: 'create',
              clientLogId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
              payloadJson: '{}',
              createdAt: '2026-09-24T06:00:00.000Z',
            ),
          );
      await v2.customStatement('DROP TABLE today_event_queue');
      await v2.customStatement('DROP TABLE today_event_ledger');
      await v2.customStatement('PRAGMA user_version = 2');
      await v2.close();

      final v3 = AppDatabase(NativeDatabase(file));
      addTearDown(v3.close);
      expect((await v3.select(v3.syncQueue).get()).single.kind, 'start');
      expect(
        (await v3.select(v3.nutritionSyncQueue).get()).single.clientLogId,
        'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      );
      final onV3 = open(v3);
      addTearDown(onV3.dispose);
      api.eventFailure = const Offline();
      expect(await onV3.record(start.ref, date, TodayEventName.shown), isTrue);
      await onV3.drain();
      expect(await v3.select(v3.todayEventQueue).get(), hasLength(1));
      final version = await v3.customSelect('PRAGMA user_version').getSingle();
      expect(version.data.values.single, 3);
    });
  });
}
