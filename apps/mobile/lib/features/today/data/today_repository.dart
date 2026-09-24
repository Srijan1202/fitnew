import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../../../core/errors/result.dart';
import '../domain/today.dart';
import 'today_api.dart';
import 'today_event_sync.dart';

/// The last valid `GET /v1/today` answer, as this phone stored it.
class CachedTodayPlan {
  const CachedTodayPlan(this.plan, this.storedAt);

  final TodayPlan plan;

  /// When it was fetched (UTC ISO).
  final String storedAt;
}

/// TODAY on the phone (Phase 11): the server's plan (fetched, cached for an
/// honest offline view), and the events the user's responses produce —
/// recorded once each in the ledger and queued for the [TodayEventSync].
/// It never makes an action.
class TodayRepository {
  TodayRepository(
    this._db,
    this._api,
    this._sync, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final TodayApi _api;
  final TodayEventSync _sync;
  final DateTime Function() _now;
  static const _uuid = Uuid();

  static const cacheKey = 'today.plan';

  /// Ledger rows older than this many days are pruned (the server accepts
  /// nothing older than 7 days, P3).
  static const keepDays = 8;

  Stream<void> get drained => _sync.drained;

  void sync() => _sync.kick();

  /// Drains the queue now; completes when this drain is done.
  Future<void> drain() => _sync.drain();

  void dispose() => _sync.dispose();

  /* ------------------------------------------------------------ plan -- */

  /// Fetches the current plan; a valid answer replaces the cached one.
  Future<Result<TodayPlan>> refresh() async {
    final result = await _api.today();
    if (result case Ok(:final value)) {
      await _db.into(_db.cachedJson).insertOnConflictUpdate(
            CachedJsonCompanion.insert(
              key: cacheKey,
              json: jsonEncode(value.toJson()),
              storedAt: _now().toUtc().toIso8601String(),
            ),
          );
    }
    return result;
  }

  Future<CachedTodayPlan?> cached() async {
    final row = await (_db.select(_db.cachedJson)
          ..where((t) => t.key.equals(cacheKey)))
        .getSingleOrNull();
    if (row == null) return null;
    try {
      final plan =
          TodayPlan.fromJson(jsonDecode(row.json) as Map<String, dynamic>);
      return CachedTodayPlan(plan, row.storedAt);
    } on Object {
      return null; // an unreadable cache is no cache
    }
  }

  /* ---------------------------------------------------------- ledger -- */

  Stream<List<LedgerEntry>> watchLedger(String localDate) =>
      (_db.select(_db.todayEventLedger)
            ..where((t) => t.localDate.equals(localDate)))
          .watch()
          .map((rows) => [for (final r in rows) _entry(r)]);

  Future<List<LedgerEntry>> ledger(String localDate) async => [
        for (final r in await (_db.select(_db.todayEventLedger)
              ..where((t) => t.localDate.equals(localDate)))
            .get())
          _entry(r),
      ];

  static LedgerEntry _entry(TodayEventLedgerData r) => LedgerEntry(
        recommendationId: r.recommendationId,
        event: TodayEventName.fromWire(r.event),
        kind: r.kind,
        subjectKey: r.subjectKey,
        localDate: r.localDate,
        status: r.status,
      );

  /// Records [event] for [action] (of the plan dated [localDate]) once:
  /// minted client id, the phone's time, ledger + queue in one transaction,
  /// then a drain. Interacting with a card means it was on screen, so a
  /// missing `shown` is recorded first. Returns whether [event] was
  /// recorded now (false: already recorded, or not a valid next step).
  Future<bool> record(
    ActionRef action,
    String localDate,
    TodayEventName event, {
    DateTime? at,
  }) async {
    final kind = action.kind;
    if (kind == null) return false;
    final when = (at ?? _now()).toUtc();
    final recorded = await _db.transaction(() async {
      final rows = await (_db.select(_db.todayEventLedger)
            ..where((t) => t.recommendationId.equals(action.id)))
          .get();
      final have = {for (final r in rows) TodayEventName.fromWire(r.event)};
      if (event != TodayEventName.shown &&
          !have.contains(TodayEventName.shown)) {
        await _insert(
          action,
          localDate,
          TodayEventName.shown,
          when.subtract(const Duration(milliseconds: 1)),
        );
        have.add(TodayEventName.shown);
      }
      if (localTransition(kind, have, event) != LocalTransition.record) {
        return false;
      }
      await _insert(action, localDate, event, when);
      return true;
    });
    _sync.kick();
    return recorded;
  }

  Future<void> _insert(
    ActionRef action,
    String localDate,
    TodayEventName event,
    DateTime at,
  ) async {
    final clientEventId = _uuid.v4();
    final occurredAt = at.toIso8601String();
    await _db.into(_db.todayEventLedger).insert(
          TodayEventLedgerCompanion.insert(
            recommendationId: action.id,
            event: event.wire,
            clientEventId: clientEventId,
            kind: action.kindWire,
            subjectKey: action.subjectKey,
            localDate: localDate,
            occurredAt: occurredAt,
            status: 'queued',
          ),
        );
    await _db.into(_db.todayEventQueue).insert(
          TodayEventQueueCompanion.insert(
            clientEventId: clientEventId,
            recommendationId: action.id,
            event: event.wire,
            occurredAt: occurredAt,
            createdAt: _now().toUtc().toIso8601String(),
          ),
        );
  }

  /// Drops ledger rows for days the server no longer accepts events for.
  Future<void> prune(String today) async {
    final cutoff = DateTime.parse(today)
        .subtract(const Duration(days: keepDays))
        .toIso8601String()
        .substring(0, 10);
    await (_db.delete(_db.todayEventLedger)
          ..where((t) => t.localDate.isSmallerThanValue(cutoff)))
        .go();
  }
}
