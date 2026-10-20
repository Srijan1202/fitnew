import 'dart:convert';

import '../../../core/db/app_database.dart';
import '../../../core/errors/result.dart';
import '../domain/recovery.dart';
import 'recovery_api.dart';

/// The last valid `/recovery/today`, as this phone stored it.
class CachedRecovery {
  const CachedRecovery(this.today, this.storedAt);

  final RecoveryToday today;

  /// When it was fetched (UTC ISO).
  final String storedAt;
}

/// Recovery on the phone (Phase 13): the server's view, cached in
/// `cached_json` for an honest offline view; the check-in goes straight to
/// the server — online only, never queued (ADR-019 D11).
class RecoveryRepository {
  RecoveryRepository(this._db, this._api, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final RecoveryApi _api;
  final DateTime Function() _now;

  static const cacheKey = 'recovery.today';

  Future<Result<RecoveryToday>> refresh() async {
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

  Future<CachedRecovery?> cached() async {
    final row = await (_db.select(_db.cachedJson)
          ..where((t) => t.key.equals(cacheKey)))
        .getSingleOrNull();
    if (row == null) return null;
    try {
      return CachedRecovery(
        RecoveryToday.fromJson(jsonDecode(row.json) as Map<String, dynamic>),
        row.storedAt,
      );
    } on Object {
      return null; // an unreadable cache is no cache
    }
  }

  Future<Result<SavedCheckIn>> log(LogRecoveryRequest r) => _api.log(r);
}
