import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../domain/entities/food_log.dart';
import '../domain/portion_preview.dart';
import 'food_log_api.dart';
import 'nutrition_sync_engine.dart';

/// Phase 8 — food logging, local first (§33, owner J11).
///
/// A log is written to the phone and queued in one transaction, shown at
/// once as "not synced yet", and sent by the [NutritionSyncEngine]. The
/// server's day — its snapshots, totals and what remains — is cached per
/// date and is the ONLY source of any total on screen. A pending entry
/// carries a display-only preview (owner J10), never counted in a total.
class NutritionLogRepository {
  NutritionLogRepository(
    this._db,
    this._api,
    this._engine, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final FoodLogApi _api;
  final NutritionSyncEngine _engine;
  final DateTime Function() _now;

  static const recentKey = 'nutrition.recent';
  static const savedMealsKey = 'nutrition.savedMeals';

  NutritionSyncEngine get engine => _engine;

  /// Something reached the server (a log or delete confirmed).
  Stream<void> get drained => _engine.drained;

  void dispose() => _engine.dispose();

  void sync() => _engine.kick();

  Future<void> retryParked() => _engine.retryParked();

  /* ------------------------------------------------------------- days -- */

  /// The day, live. Subscribes to the tables BEFORE the first read (a write
  /// in between is never missed) and reloads in order (a stale read never
  /// lands after a fresh one).
  Stream<DayView> watchDay(String date) {
    StreamSubscription<Set<TableUpdate>>? updates;
    var chain = Future<void>.value();
    late final StreamController<DayView> out;
    void reload() {
      chain = chain.then((_) async {
        final view = await _loadDay(date);
        if (!out.isClosed) out.add(view);
      });
    }

    out = StreamController<DayView>(
      onListen: () {
        updates = _db
            .tableUpdates(
              TableUpdateQuery.onAllTables(
                [_db.cachedJson, _db.localFoodLogs, _db.nutritionSyncQueue],
              ),
            )
            .listen((_) => reload());
        reload();
      },
      onCancel: () async {
        await updates?.cancel();
        await out.close();
      },
    );
    return out.stream;
  }

  Future<DayView> _loadDay(String date) async {
    final cached = await (_db.select(_db.cachedJson)
          ..where((t) => t.key.equals(nutritionDayCacheKey(date))))
        .getSingleOrNull();
    final local = await (_db.select(_db.localFoodLogs)
          ..where((t) => t.localDate.equals(date))
          ..orderBy([(t) => OrderingTerm.asc(t.loggedAt)]))
        .get();
    final queue = await _db.select(_db.nutritionSyncQueue).get();
    final parkedCreates = {
      for (final q in queue)
        if (q.parked && q.kind == NutritionSyncKind.create.name)
          q.clientLogId: q.lastError,
    };
    return DayView(
      date: date,
      server: cached == null
          ? null
          : NutritionDay.fromJson(
              jsonDecode(cached.json) as Map<String, dynamic>,
            ),
      storedAt: cached?.storedAt,
      pending: [
        for (final row in local)
          PendingLog(
            clientLogId: row.clientLogId,
            localDate: row.localDate,
            mealSlot: MealSlot.fromWire(row.mealSlot),
            loggedAt: row.loggedAt,
            preview: PendingPreview.fromJson(
              jsonDecode(row.previewJson) as Map<String, dynamic>,
            ),
            parked: parkedCreates.containsKey(row.clientLogId),
            error: parkedCreates[row.clientLogId],
          ),
      ],
      deleting: {
        for (final q in queue)
          if (q.kind == NutritionSyncKind.delete.name) q.clientLogId,
      },
      parkedCount: queue.where((q) => q.parked).length,
      unsyncedCount: queue.length,
    );
  }

  /// Asks the server for [date] and caches the answer. A failure leaves the
  /// cached day (if any) on screen, marked as not current.
  Future<Result<NutritionDay>> refreshDay(String date) async {
    final result = await _api.day(date);
    if (result case Ok(:final value)) {
      await _cache(nutritionDayCacheKey(date), value.toJson());
    }
    return result;
  }

  Future<void> _cache(String key, Object json) =>
      _db.into(_db.cachedJson).insertOnConflictUpdate(
            CachedJsonCompanion.insert(
              key: key,
              json: jsonEncode(json),
              storedAt: _now().toUtc().toIso8601String(),
            ),
          );

  Future<Object?> _cached(String key) async {
    final row = await (_db.select(_db.cachedJson)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row == null ? null : jsonDecode(row.json);
  }

  /* ------------------------------------------------------- mutations -- */

  /// Logs food: on the phone and in the queue, together; the engine sends it.
  Future<void> log(
    CreateLogRequest request, {
    required String localDate,
    required PendingPreview preview,
  }) async {
    await _db.transaction(() async {
      await _db.into(_db.localFoodLogs).insert(
            LocalFoodLogsCompanion.insert(
              clientLogId: request.clientLogId,
              localDate: localDate,
              mealSlot: request.mealSlot.wire,
              loggedAt: request.loggedAt,
              requestJson: jsonEncode(request.toJson()),
              previewJson: jsonEncode(preview.toJson()),
              createdAt: _now().toUtc().toIso8601String(),
            ),
          );
      await _engine.enqueue(
        NutritionSyncKind.create,
        request.clientLogId,
        request.toJson(),
      );
    });
    _engine.kick();
  }

  /// Deletes a whole log (owner J9). One the server has never seen is simply
  /// not sent — its row and its queued create go together (folding); one on
  /// the server, or on its way there, gets a delete queued behind it.
  Future<void> delete(String clientLogId) async {
    await _db.transaction(() async {
      final local = await (_db.select(_db.localFoodLogs)
            ..where((t) => t.clientLogId.equals(clientLogId)))
          .getSingleOrNull();
      if (local != null && !_engine.isInFlight(clientLogId)) {
        await (_db.delete(_db.nutritionSyncQueue)
              ..where((t) => t.clientLogId.equals(clientLogId)))
            .go();
        await (_db.delete(_db.localFoodLogs)
              ..where((t) => t.clientLogId.equals(clientLogId)))
            .go();
        return;
      }
      final already = await (_db.select(_db.nutritionSyncQueue)
            ..where(
              (t) =>
                  t.clientLogId.equals(clientLogId) &
                  t.kind.equals(NutritionSyncKind.delete.name),
            ))
          .get();
      if (already.isNotEmpty) return;
      await _engine.enqueue(
        NutritionSyncKind.delete,
        clientLogId,
        <String, dynamic>{'clientLogId': clientLogId},
      );
    });
    _engine.kick();
  }

  /* ---------------------------------------- recent foods, saved meals -- */

  /// The server's list, or the last one fetched when it cannot be reached.
  Future<Result<Cached<List<RecentFood>>>> recentFoods() async {
    final r = await _api.recentFoods();
    switch (r) {
      case Ok(:final value):
        await _cache(recentKey, value.map((e) => e.toJson()).toList());
        return Ok(Cached(value, stale: false));
      case Err(:final failure):
        final cached = await _cached(recentKey);
        if (cached is! List) return Err(failure);
        return Ok(
          Cached(
            cached
                .map((e) => RecentFood.fromJson(e as Map<String, dynamic>))
                .toList(),
            stale: true,
          ),
        );
    }
  }

  Future<Result<Cached<List<SavedMeal>>>> savedMeals() async {
    final r = await _api.savedMeals();
    switch (r) {
      case Ok(:final value):
        await _cache(savedMealsKey, value.map((e) => e.toJson()).toList());
        return Ok(Cached(value, stale: false));
      case Err(:final failure):
        final cached = await _cached(savedMealsKey);
        if (cached is! List) return Err(failure);
        return Ok(
          Cached(
            cached
                .map((e) => SavedMeal.fromJson(e as Map<String, dynamic>))
                .toList(),
            stale: true,
          ),
        );
    }
  }

  /// Online only: a meal is saved from logs the server holds (owner J7).
  Future<Result<SavedMeal>> createSavedMeal(CreateSavedMealRequest request) =>
      _api.createSavedMeal(request);

  Future<Result<void>> deleteSavedMeal(String id) => _api.deleteSavedMeal(id);
}

/// A value from the server, or the last one fetched ([stale]).
class Cached<T> {
  const Cached(this.value, {required this.stale});
  final T value;
  final bool stale;
}

/// One day as the EAT screen shows it: the server's day (cached), plus what
/// this phone has not had confirmed yet.
class DayView {
  const DayView({
    required this.date,
    required this.server,
    required this.storedAt,
    required this.pending,
    required this.deleting,
    required this.parkedCount,
    required this.unsyncedCount,
  });

  final String date;

  /// The server's day: every total comes from here. Null before the first
  /// successful fetch of this date.
  final NutritionDay? server;

  /// When [server] was fetched (UTC ISO).
  final String? storedAt;

  /// Logs made here that the server has not confirmed. Not in any total.
  final List<PendingLog> pending;

  /// Server logs with a delete on its way — still in the server's totals.
  final Set<String> deleting;

  /// Queue entries (any day) that gave up — shown with Retry.
  final int parkedCount;

  /// Queue entries (any day) not yet confirmed.
  final int unsyncedCount;
}

class PendingLog {
  const PendingLog({
    required this.clientLogId,
    required this.localDate,
    required this.mealSlot,
    required this.loggedAt,
    required this.preview,
    required this.parked,
    required this.error,
  });

  final String clientLogId;
  final String localDate;
  final MealSlot mealSlot;
  final String loggedAt;
  final PendingPreview preview;
  final bool parked;
  final String? error;
}

/// What a pending entry shows: its items and their DISPLAY-ONLY previews.
class PendingPreview {
  const PendingPreview({required this.items});

  factory PendingPreview.fromJson(Map<String, dynamic> json) => PendingPreview(
        items: (json['items'] as List<dynamic>)
            .map((e) => PendingItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final List<PendingItem> items;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'items': items.map((i) => i.toJson()).toList(),
      };
}

class PendingItem {
  const PendingItem({
    required this.name,
    required this.portion,
    required this.preview,
  });

  factory PendingItem.fromJson(Map<String, dynamic> json) => PendingItem(
        name: json['name'] as String,
        portion: json['portion'] as String,
        preview: json['preview'] == null
            ? null
            : PreviewNutrition.fromMap(json['preview'] as Map<String, dynamic>),
      );

  final String name;
  final String portion;

  /// Null when no preview can be made (a saved meal with a food gone).
  final PreviewNutrition? preview;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'portion': portion,
        'preview': preview?.toMap(),
      };
}

/// Why a mutation could not be made (for the screen's error line).
Failure failureOf(Object e) => e is Failure ? e : const Unknown();
