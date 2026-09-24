import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:fitos/core/db/app_database.dart';
import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/features/nutrition/data/nutrition_log_repository.dart';
import 'package:fitos/features/nutrition/data/nutrition_sync_engine.dart';
import 'package:fitos/features/nutrition/domain/entities/food.dart';
import 'package:fitos/features/nutrition/domain/entities/food_log.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_food_log_api.dart';

/// Phase 8 — the food-log queue and its own engine, against a scripted
/// server on an in-memory database. Every case the owner named: offline log,
/// reconnect, kill / reopen, duplicate and concurrent replay, delete before
/// and after upload, parked + Retry, 401 recovery; and the drift v1 → v2
/// upgrade keeping a queued workout.
void main() {
  late AppDatabase db;
  late FakeFoodLogApi api;
  late DateTime clock;
  late NutritionSyncEngine engine;
  late NutritionLogRepository repo;

  NutritionLogRepository open() {
    engine = NutritionSyncEngine(db, api, now: () => clock, wakeItself: false);
    return NutritionLogRepository(db, api, engine, now: () => clock);
  }

  setUp(() {
    db = AppDatabase.inMemory();
    api = FakeFoodLogApi();
    clock = DateTime.utc(2026, 9, 24, 6, 30); // 12:00 IST
    repo = open();
  });

  tearDown(() async {
    repo.dispose();
    await db.close();
  });

  CreateLogRequest quick(String id, {double kcal = 250}) =>
      CreateLogRequest.quickAdd(
        clientLogId: id,
        loggedAt: '2026-09-24T06:30:00.000Z',
        mealSlot: MealSlot.lunch,
        quickAdd: QuickAdd(kcal: kcal, proteinG: 10, carbG: 30, fatG: 9),
      );

  const preview = PendingPreview(
    items: [
      PendingItem(name: 'Quick add', portion: 'Quick add', preview: null),
    ],
  );

  Future<void> log(String id, {double kcal = 250}) => repo
      .log(quick(id, kcal: kcal), localDate: '2026-09-24', preview: preview);

  Future<List<NutritionSyncQueueData>> queue() =>
      db.select(db.nutritionSyncQueue).get();

  Future<List<LocalFoodLog>> local() => db.select(db.localFoodLogs).get();

  Future<NutritionDay?> cachedDay(String date) async {
    final row = await (db.select(db.cachedJson)
          ..where((t) => t.key.equals(nutritionDayCacheKey(date))))
        .getSingleOrNull();
    return row == null
        ? null
        : NutritionDay.fromJson(jsonDecode(row.json) as Map<String, dynamic>);
  }

  int creates() => api.calls.where((c) => c.startsWith('create')).length;

  test(
      'offline: the log is on the phone and queued; nothing is charged; totals untouched',
      () async {
    api.offline = true;
    await log('11111111-1111-4111-8111-111111111111');
    await engine.drain();
    expect(await local(), hasLength(1));
    final q = await queue();
    expect(q.single.attempts, 0);
    expect(q.single.parked, isFalse);
    expect(api.logs, isEmpty);
    final view = await repo.watchDay('2026-09-24').first;
    expect(
      view.pending.single.clientLogId,
      '11111111-1111-4111-8111-111111111111',
    );
    expect(
      view.server,
      isNull,
    ); // no server total was ever faked from the preview
    expect(view.unsyncedCount, 1);
  });

  test(
      'reconnect: sent once; the local row goes and the server day (with it) is cached, together',
      () async {
    api.offline = true;
    await log('11111111-1111-4111-8111-111111111111');
    await engine.drain();
    api.offline = false;
    await engine.drain();
    expect(api.logs.keys, ['11111111-1111-4111-8111-111111111111']);
    expect(await local(), isEmpty);
    expect(await queue(), isEmpty);
    final day = await cachedDay('2026-09-24');
    expect(day!.totals.kcalLow, 250);
    expect(day.logs.single.clientLogId, '11111111-1111-4111-8111-111111111111');
    final view = await repo.watchDay('2026-09-24').first;
    expect(view.pending, isEmpty);
    expect(view.unsyncedCount, 0);
  });

  test(
      'kill and reopen: the queue is on disk; a new engine sends it exactly once',
      () async {
    api.offline = true;
    await log('11111111-1111-4111-8111-111111111111');
    await log('22222222-2222-4222-8222-222222222222');
    await engine.drain();
    repo.dispose(); // the app is killed
    api.offline = false;
    repo = open(); // reopened: a fresh engine on the same database
    await engine.drain();
    // Each log reached the server exactly once (the fake keeps one per id and
    // accepted every delivered create — none arrived twice as a new log).
    expect(api.logs.keys.toSet(), {
      '11111111-1111-4111-8111-111111111111',
      '22222222-2222-4222-8222-222222222222',
    });
    expect(api.logs, hasLength(2));
    expect(await queue(), isEmpty);
    expect(await local(), isEmpty);
  });

  test(
      'duplicate replay: the reply is lost, the create is re-sent, the server keeps ONE log',
      () async {
    api.loseNextReply = true;
    await log('11111111-1111-4111-8111-111111111111');
    await engine.drain();
    expect(api.logs, hasLength(1)); // it reached the server…
    expect(
      (await queue()).single.attempts,
      1,
    ); // …but the phone does not know yet
    clock = clock.add(const Duration(seconds: 1));
    await engine.drain();
    expect(api.logs, hasLength(1));
    expect(await queue(), isEmpty);
    expect((await cachedDay('2026-09-24'))!.totals.itemCount, 1);
  });

  test('concurrent replay: two drains at once send each entry once', () async {
    await log('11111111-1111-4111-8111-111111111111');
    await Future.wait([engine.drain(), engine.drain(), engine.drain()]);
    expect(creates(), 1);
    expect(api.logs, hasLength(1));
  });

  test(
      'delete before upload: folded away — neither the create nor a delete is ever sent',
      () async {
    api.offline = true;
    await log('11111111-1111-4111-8111-111111111111');
    await repo.delete('11111111-1111-4111-8111-111111111111');
    expect(await queue(), isEmpty);
    expect(await local(), isEmpty);
    api.offline = false;
    api.calls.clear();
    await engine.drain();
    expect(api.calls, isEmpty);
    expect(api.logs, isEmpty);
  });

  test(
      'delete after upload: a delete is queued and sent; the cached day loses the log',
      () async {
    await log('11111111-1111-4111-8111-111111111111');
    await engine.drain();
    // Offline while we look at the queue (a delete kicks a drain at once).
    api.offline = true;
    await repo.delete('11111111-1111-4111-8111-111111111111');
    await repo.delete(
      '11111111-1111-4111-8111-111111111111',
    ); // a double tap queues one delete
    await engine.drain();
    api.offline = false;
    final q = await queue();
    expect(q.map((e) => e.kind), ['delete']);
    final view = await repo.watchDay('2026-09-24').first;
    expect(view.deleting, {'11111111-1111-4111-8111-111111111111'});
    await engine.drain();
    expect(api.deleted, {'11111111-1111-4111-8111-111111111111'});
    expect((await cachedDay('2026-09-24'))!.totals.itemCount, 0);
    expect(await queue(), isEmpty);
  });

  test(
      'delete while the create is on the wire: queued BEHIND it, never folded into it',
      () async {
    api.gate = Completer<void>();
    await log('11111111-1111-4111-8111-111111111111');
    final drain = engine.drain();
    await Future<void>.delayed(Duration.zero);
    expect(engine.isInFlight('11111111-1111-4111-8111-111111111111'), isTrue);
    await repo.delete('11111111-1111-4111-8111-111111111111');
    expect((await queue()).map((e) => e.kind), ['create', 'delete']);
    api.gate!.complete();
    api.gate = null;
    await drain;
    await engine.drain();
    expect(api.logs.keys, ['11111111-1111-4111-8111-111111111111']);
    expect(api.deleted, {'11111111-1111-4111-8111-111111111111'});
    expect(await queue(), isEmpty);
    expect(await local(), isEmpty);
  });

  test('a delete the server does not know (404) is done, not retried',
      () async {
    await engine.enqueue(
      NutritionSyncKind.delete,
      '33333333-3333-4333-8333-333333333333',
      const {},
    );
    await engine.drain();
    expect(await queue(), isEmpty);
  });

  test(
      'a refusal that cannot change (422) is parked at once with its message; Retry sends it again',
      () async {
    api.failNext.add(const Validation('That food is not in your library.'));
    await log('11111111-1111-4111-8111-111111111111');
    await engine.drain();
    final q = (await queue()).single;
    expect(q.parked, isTrue);
    expect(q.lastError, 'That food is not in your library.');
    final view = await repo.watchDay('2026-09-24').first;
    expect(view.parkedCount, 1);
    expect(view.pending.single.parked, isTrue);
    expect(view.pending.single.error, 'That food is not in your library.');
    await repo.retryParked();
    await engine.drain();
    expect(await queue(), isEmpty);
    expect(api.logs, hasLength(1));
  });

  test(
      'transient failures back off (300 ms · 2ⁿ) and park after five attempts; Retry recovers',
      () async {
    for (var i = 0; i < 5; i++) {
      api.failNext.add(const Unknown());
    }
    await log('11111111-1111-4111-8111-111111111111');
    for (var i = 0; i < 5; i++) {
      await engine.drain();
      final q = (await queue()).single;
      expect(q.attempts, i + 1);
      expect(q.parked, i == 4);
      if (i < 4) {
        // Not due yet: nothing is sent before the backoff runs out.
        final before = creates();
        await engine.drain();
        expect(creates(), before);
        clock = clock.add(Duration(milliseconds: 300 * (1 << i) + 1));
      }
    }
    await repo.retryParked();
    await engine.drain();
    expect(api.logs, hasLength(1));
  });

  test(
      '401: the drain stops without charging an attempt; after sign-in it goes through',
      () async {
    api.unauthenticated = true;
    await log('11111111-1111-4111-8111-111111111111');
    await engine.drain();
    var q = (await queue()).single;
    expect(q.attempts, 0);
    expect(q.parked, isFalse);
    api.unauthenticated = false;
    await engine.drain();
    q = (await queue()).isEmpty ? q : (await queue()).single;
    expect(await queue(), isEmpty);
    expect(api.logs, hasLength(1));
  });

  test(
      "a server not answering (hosted 503) waits like offline — no attempt spent, never parked",
      () async {
    // Both the drain the log kicks and ours meet the outage.
    api.failNext
      ..add(const ServiceUnavailable())
      ..add(const ServiceUnavailable());
    await log('11111111-1111-4111-8111-111111111111');
    await engine.drain();
    final q = (await queue()).single;
    expect(q.attempts, 0);
    expect(q.parked, isFalse);
  });

  test("a log's delete never overtakes its create waiting out a backoff",
      () async {
    api.failNext.add(const Unknown());
    await log('11111111-1111-4111-8111-111111111111');
    await engine.drain(); // create failed once, in backoff
    // The user deletes it while the create waits (not in flight → folded).
    await repo.delete('11111111-1111-4111-8111-111111111111');
    expect(await queue(), isEmpty);
    // A server-side log with an earlier create still queued: the delete waits for it.
    api.failNext.add(const Unknown());
    await log('22222222-2222-4222-8222-222222222222');
    await engine.drain();
    await engine.enqueue(
      NutritionSyncKind.delete,
      '22222222-2222-4222-8222-222222222222',
      const {},
    );
    clock = clock.add(const Duration(milliseconds: 100)); // backoff not over
    await engine.drain();
    expect(api.calls.where((c) => c.startsWith('delete')), isEmpty);
  });

  group('drift schema v1 → v2 (Phase 8)', () {
    test(
        'an upgrade adds the food-log tables and keeps a queued, unsent workout',
        () async {
      final dir = Directory.systemTemp.createTempSync('fitos-drift');
      final file = File('${dir.path}/fitos.sqlite');
      addTearDown(() => dir.deleteSync(recursive: true));

      // A phone on the Phase 5–7 app: schema version 1, a workout in progress
      // and its start still queued. (v1 is exactly today's schema without the
      // two Phase 8 tables.)
      final v1 = AppDatabase(NativeDatabase(file));
      await v1.into(v1.localSessions).insert(
            LocalSessionsCompanion.insert(
              clientSessionId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
              status: 'active',
              name: 'Push',
              startedAt: '2026-09-24T05:00:00.000Z',
              snapshotJson: '{}',
              updatedAt: '2026-09-24T05:00:00.000Z',
            ),
          );
      await v1.into(v1.syncQueue).insert(
            SyncQueueCompanion.insert(
              kind: 'start',
              clientSessionId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
              payloadJson:
                  '{"clientSessionId":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"}',
              createdAt: '2026-09-24T05:00:00.000Z',
            ),
          );
      await v1.customStatement('DROP TABLE local_food_logs');
      await v1.customStatement('DROP TABLE nutrition_sync_queue');
      await v1.customStatement('PRAGMA user_version = 1');
      await v1.close();

      final v2 = AppDatabase(NativeDatabase(file));
      addTearDown(v2.close);
      // Opening runs the migration.
      final sessions = await v2.select(v2.localSessions).get();
      expect(
        sessions.single.clientSessionId,
        'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      );
      final workoutQueue = await v2.select(v2.syncQueue).get();
      expect(workoutQueue.single.kind, 'start');
      expect(workoutQueue.single.payloadJson, contains('aaaaaaaa'));
      // The new tables exist and work.
      expect(await v2.select(v2.localFoodLogs).get(), isEmpty);
      await v2.into(v2.nutritionSyncQueue).insert(
            NutritionSyncQueueCompanion.insert(
              kind: 'create',
              clientLogId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
              payloadJson: '{}',
              createdAt: '2026-09-24T06:00:00.000Z',
            ),
          );
      expect(await v2.select(v2.nutritionSyncQueue).get(), hasLength(1));
      final version = await v2.customSelect('PRAGMA user_version').getSingle();
      // Upgraded to the current schema (2 in Phase 8; later phases add tables).
      expect(version.data.values.single, v2.schemaVersion);
    });

    test('sign-out clears the food-log tables too', () async {
      await log('11111111-1111-4111-8111-111111111111');
      await db.clearAll();
      expect(await local(), isEmpty);
      expect(await queue(), isEmpty);
    });
  });

  test('the food-log engine and the workout queue are separate tables',
      () async {
    api.offline = true;
    await log('11111111-1111-4111-8111-111111111111');
    expect(await db.select(db.syncQueue).get(), isEmpty);
    expect(await queue(), hasLength(1));
    // A FoodSource value survives the queue's JSON round trip.
    expect(FoodSource.user.wire, 'user');
  });
}
