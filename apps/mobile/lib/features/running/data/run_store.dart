import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../domain/track.dart';

/// Beta 4.0 (ADR-038): runs on this phone (drift). The run being recorded is
/// written as it happens — every point, every pause — so a crash, a killed
/// app or a flat battery loses nothing already recorded.
class RunStore {
  RunStore(this._db);

  final AppDatabase _db;

  static const live = ['recording', 'paused', 'autoPaused', 'finished'];

  /// The run being recorded, paused, or finished and waiting for Save.
  Future<LocalRun?> current() => (_db.select(_db.localRuns)
        ..where((r) => r.status.isIn(live))
        ..orderBy([(r) => OrderingTerm.desc(r.startedAt)])
        ..limit(1))
      .getSingleOrNull();

  Future<LocalRun?> byId(String id) =>
      (_db.select(_db.localRuns)..where((r) => r.clientRunId.equals(id)))
          .getSingleOrNull();

  /// Saved runs the server has not confirmed, newest first.
  Stream<List<LocalRun>> watchUnsynced() => (_db.select(_db.localRuns)
        ..where((r) => r.status.equals('saved'))
        ..orderBy([(r) => OrderingTerm.desc(r.startedAt)]))
      .watch();

  Future<void> insert(LocalRunsCompanion run) =>
      _db.into(_db.localRuns).insert(run);

  Future<void> update(String id, LocalRunsCompanion change) =>
      (_db.update(_db.localRuns)..where((r) => r.clientRunId.equals(id)))
          .write(change);

  /// Appends points; [firstSeq] is the next sequence number.
  Future<void> addPoints(
    String id,
    int firstSeq,
    int segment,
    List<TrackPoint> points,
  ) =>
      _db.batch((b) {
        for (var i = 0; i < points.length; i++) {
          final p = points[i];
          b.insert(
            _db.localRunPoints,
            LocalRunPointsCompanion.insert(
              clientRunId: id,
              seq: firstSeq + i,
              segment: segment,
              t: p.t,
              lat: p.lat,
              lon: p.lon,
              ele: Value(p.ele),
            ),
          );
        }
      });

  /// The stored track, split at every pause.
  Future<Track> track(String id) async {
    final rows = await (_db.select(_db.localRunPoints)
          ..where((p) => p.clientRunId.equals(id))
          ..orderBy([(p) => OrderingTerm.asc(p.seq)]))
        .get();
    final segments = <List<TrackPoint>>[];
    int? current;
    for (final r in rows) {
      if (r.segment != current) {
        segments.add(<TrackPoint>[]);
        current = r.segment;
      }
      segments.last.add(TrackPoint(t: r.t, lat: r.lat, lon: r.lon, ele: r.ele));
    }
    return Track(segments);
  }

  Future<int> pointCount(String id) async {
    final count = _db.localRunPoints.seq.count();
    final row = await (_db.selectOnly(_db.localRunPoints)
          ..addColumns([count])
          ..where(_db.localRunPoints.clientRunId.equals(id)))
        .getSingle();
    return row.read(count) ?? 0;
  }

  /// The run and its points, gone.
  Future<void> delete(String id) => _db.transaction(() async {
        await (_db.delete(_db.localRunPoints)
              ..where((p) => p.clientRunId.equals(id)))
            .go();
        await (_db.delete(_db.localRuns)
              ..where((r) => r.clientRunId.equals(id)))
            .go();
      });
}
