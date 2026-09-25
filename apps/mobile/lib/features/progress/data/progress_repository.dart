import 'dart:convert';

import '../../../core/db/app_database.dart';
import '../../../core/errors/result.dart';
import '../domain/progress.dart';
import 'progress_api.dart';

/// The last valid summary for a window, as this phone stored it.
class CachedProgress {
  const CachedProgress(this.summary, this.storedAt);

  final ProgressSummary summary;

  /// When it was fetched (UTC ISO).
  final String storedAt;
}

/// Progress on the phone (Phase 12): the server's summary, cached per window
/// in `cached_json` for an honest offline view (owner D9). Readings are sent
/// straight to the server — online only, never queued: no new sync engine.
class ProgressRepository {
  ProgressRepository(this._db, this._api, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final ProgressApi _api;
  final DateTime Function() _now;

  static String cacheKey(ProgressWindow w) => 'progress.summary.${w.wire}';

  Future<Result<ProgressSummary>> refresh(ProgressWindow window) async {
    final result = await _api.summary(window);
    if (result case Ok(:final value)) {
      await _db.into(_db.cachedJson).insertOnConflictUpdate(
            CachedJsonCompanion.insert(
              key: cacheKey(window),
              json: jsonEncode(value.toJson()),
              storedAt: _now().toUtc().toIso8601String(),
            ),
          );
    }
    return result;
  }

  Future<CachedProgress?> cached(ProgressWindow window) async {
    final row = await (_db.select(_db.cachedJson)
          ..where((t) => t.key.equals(cacheKey(window))))
        .getSingleOrNull();
    if (row == null) return null;
    try {
      return CachedProgress(
        ProgressSummary.fromJson(jsonDecode(row.json) as Map<String, dynamic>),
        row.storedAt,
      );
    } on Object {
      return null; // an unreadable cache is no cache
    }
  }

  Future<Result<SavedReading>> logWeight(LogWeightRequest r) =>
      _api.logWeight(r);

  Future<Result<SavedReading>> logMeasurement(LogMeasurementRequest r) =>
      _api.logMeasurement(r);
}
