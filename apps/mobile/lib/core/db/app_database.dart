import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// The local database (§33): the workout that is happening right now, food
/// logged on this phone (Phase 8), and the queues of everything the server
/// has not confirmed yet.
///
/// Write locally first, render from here, sync later. Every row a client
/// creates carries the client id the server treats as its idempotency key,
/// so draining the queue twice is harmless.

/// A session as the phone knows it. `serverId` is null until the start
/// request has been confirmed.
class LocalSessions extends Table {
  TextColumn get clientSessionId => text()();
  TextColumn get serverId => text().nullable()();
  TextColumn get status => text()();
  TextColumn get name => text()();
  TextColumn get programId => text().nullable()();
  TextColumn get programDayId => text().nullable()();
  TextColumn get startedAt => text()();
  TextColumn get completedAt => text().nullable()();
  TextColumn get notes => text().nullable()();

  /// The server's last answer (or the offline seed), as JSON: targets,
  /// last performance and the summary live here, not in columns.
  TextColumn get snapshotJson => text()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column<Object>> get primaryKey => {clientSessionId};
}

class LocalSessionExercises extends Table {
  TextColumn get clientExerciseId => text()();
  TextColumn get clientSessionId => text()();
  TextColumn get serverId => text().nullable()();
  TextColumn get exerciseId => text()();
  TextColumn get plannedExerciseId => text().nullable()();
  IntColumn get orderIndex => integer()();
  IntColumn get supersetGroup => integer().nullable()();
  BoolColumn get removed => boolean().withDefault(const Constant(false))();

  /// Catalogue metadata + targets + last performance, as JSON.
  TextColumn get exerciseJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {clientExerciseId};
}

class LocalSetLogs extends Table {
  TextColumn get clientSetId => text()();
  TextColumn get clientExerciseId => text()();
  TextColumn get serverId => text().nullable()();
  IntColumn get setIndex => integer()();
  TextColumn get setType => text()();
  RealColumn get weightKg => real().nullable()();
  IntColumn get reps => integer()();
  IntColumn get rir => integer().nullable()();
  TextColumn get loggedAt => text()();
  TextColumn get plannedSetId => text().nullable()();
  BoolColumn get isPr => boolean().withDefault(const Constant(false))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {clientSetId};
}

/// One mutation the server has not confirmed. Drained FIFO.
class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// `start` | `logSets` | `patchSet` | `deleteSet` | `addExercise` |
  /// `patchExercise` | `complete` | `abandon`.
  TextColumn get kind => text()();
  TextColumn get clientSessionId => text()();

  /// The row this mutation is about (a client set id, a client exercise id).
  TextColumn get clientKey => text().nullable()();
  TextColumn get payloadJson => text()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get nextAttemptAt => text().nullable()();
  TextColumn get lastError => text().nullable()();

  /// Parked: gave up after the retry budget; shown to the user with Retry.
  BoolColumn get parked => boolean().withDefault(const Constant(false))();
  TextColumn get createdAt => text()();
}

/// Small key → JSON cache: today's plan, so the day renders offline.
class CachedJson extends Table {
  TextColumn get key => text()();
  TextColumn get json => text()();
  TextColumn get storedAt => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Phase 8: a food log made on this phone that the server has not confirmed
/// yet. The row goes when the server's answer lands (the server's day, in
/// [CachedJson], then holds the log). `previewJson` is the display-only
/// preview (owner J10) — shown as "not synced yet", never in a total.
class LocalFoodLogs extends Table {
  TextColumn get clientLogId => text()();

  /// The day it is shown on until synced (the user's zone); the server decides.
  TextColumn get localDate => text()();
  TextColumn get mealSlot => text()();
  TextColumn get loggedAt => text()();

  /// The `POST /nutrition/logs` body, sent as is.
  TextColumn get requestJson => text()();
  TextColumn get previewJson => text()();
  TextColumn get createdAt => text()();

  @override
  Set<Column<Object>> get primaryKey => {clientLogId};
}

/// Phase 8: food-log mutations the server has not confirmed, drained FIFO by
/// the NutritionSyncEngine — separate from the workout [SyncQueue].
class NutritionSyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// `create` | `delete`.
  TextColumn get kind => text()();
  TextColumn get clientLogId => text()();
  TextColumn get payloadJson => text()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get nextAttemptAt => text().nullable()();
  TextColumn get lastError => text().nullable()();
  BoolColumn get parked => boolean().withDefault(const Constant(false))();
  TextColumn get createdAt => text()();
}

/// Phase 11: TODAY events the server has not confirmed yet, drained FIFO by
/// the TodayEventSync — separate from the workout [SyncQueue] and the
/// [NutritionSyncQueue] (D9). A row leaves when the server answers for good:
/// stored or replayed (201 / 200), or refused in a way a retry cannot change
/// (409, 422, 404), or after its retry budget.
class TodayEventQueue extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Minted once when the event happened; every retry reuses it.
  TextColumn get clientEventId => text()();
  TextColumn get recommendationId => text()();

  /// `shown` | `opened` | `accepted` | `dismissed` | `completed`.
  TextColumn get event => text()();

  /// When it happened on this phone (UTC ISO) — sent as is, never "now".
  TextColumn get occurredAt => text()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get nextAttemptAt => text().nullable()();
  TextColumn get lastError => text().nullable()();
  TextColumn get createdAt => text()();
}

/// Phase 11: every TODAY event recorded on this phone, one per (action,
/// event). It is what makes `shown` go once per action however often Home
/// rebuilds, and what the phone's own state machine reads (a dismissed
/// card stays hidden, `completed` waits for `accepted`). Kept after the
/// queue row leaves; pruned after a week.
class TodayEventLedger extends Table {
  TextColumn get recommendationId => text()();
  TextColumn get event => text()();
  TextColumn get clientEventId => text()();
  TextColumn get kind => text()();
  TextColumn get subjectKey => text()();

  /// The action's local date (the server's `generated_for`).
  TextColumn get localDate => text()();
  TextColumn get occurredAt => text()();

  /// `queued` | `sent` | `rejected` | `failed`.
  TextColumn get status => text()();

  @override
  Set<Column<Object>> get primaryKey => {recommendationId, event};
}

@DriftDatabase(
  tables: [
    LocalSessions,
    LocalSessionExercises,
    LocalSetLogs,
    SyncQueue,
    CachedJson,
    LocalFoodLogs,
    NutritionSyncQueue,
    TodayEventQueue,
    TodayEventLedger,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// The on-device file. Tests use [AppDatabase.inMemory].
  factory AppDatabase.open() => AppDatabase(
        LazyDatabase(() async {
          final dir = await getApplicationDocumentsDirectory();
          return NativeDatabase.createInBackground(
            File(p.join(dir.path, 'fitos.sqlite')),
          );
        }),
      );

  /// Streams close synchronously here: Drift otherwise keeps a closed
  /// query's cache for one zero-length timer, which a widget test sees as a
  /// timer still pending after its tree is gone (Phase 11: Home now listens
  /// to the TODAY ledger).
  factory AppDatabase.inMemory() => AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );

  /// 1 — Phase 5 (workout, sync queue, cache). 2 — Phase 8 (food logs and
  /// their own queue). 3 — Phase 11 (TODAY events: queue and ledger). An
  /// upgrade only ADDS tables: a phone that still holds an unsent workout or
  /// food log keeps it.
  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(localFoodLogs);
            await m.createTable(nutritionSyncQueue);
          }
          if (from < 3) {
            await m.createTable(todayEventQueue);
            await m.createTable(todayEventLedger);
          }
        },
      );

  /// Everything, on sign-out: the next user starts from nothing.
  Future<void> clearAll() => transaction(() async {
        for (final t in allTables) {
          await delete(t).go();
        }
      });
}
