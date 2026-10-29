import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/result.dart';
import '../../health/data/health_connect_channel.dart';
import '../domain/run.dart';
import '../domain/track.dart';
import 'running_api.dart';

/// Beta 4.5 (owner 2026-10-30): runs recorded on a Galaxy Watch come in by
/// themselves. Samsung Health shares them with Health Connect; FITOS reads
/// them there (read only, with the user's permission) and sends each to the
/// server once, like a run recorded on the phone, marked as from the watch.
///
///  - Once: each run's client id comes from its Health Connect record id,
///    and the server also keys it by that id, so a replay — another phone,
///    a reinstall — finds the same run.
///  - Not doubled: a watch run that overlaps a run the phone recorded by
///    more than half its time is left out.
///  - What it has: distance (the route's, or the watch's own), time less
///    pauses, the average and max heart rate, and the route when shared.

/// One run from Health Connect, as the channel answers it.
class WatchRun {
  const WatchRun({
    required this.id,
    required this.start,
    required this.end,
    required this.treadmill,
    required this.pausedSeconds,
    this.distanceM,
    this.hrAvg,
    this.hrMax,
    this.route,
  });

  /// Null for anything that is not the expected shape.
  static WatchRun? fromChannel(Map<String, Object?> m) {
    final id = m['id'];
    final start = m['start'];
    final end = m['end'];
    if (id is! String || start is! int || end is! int || end <= start) {
      return null;
    }
    final route = m['route'];
    return WatchRun(
      id: id,
      start: DateTime.fromMillisecondsSinceEpoch(start, isUtc: true),
      end: DateTime.fromMillisecondsSinceEpoch(end, isUtc: true),
      treadmill: m['treadmill'] == true,
      pausedSeconds: (m['pausedSeconds'] as num?)?.toInt() ?? 0,
      distanceM: (m['distanceM'] as num?)?.toDouble(),
      hrAvg: (m['hrAvg'] as num?)?.toDouble(),
      hrMax: (m['hrMax'] as num?)?.toDouble(),
      route: route is List
          ? [
              for (final p in route)
                if (p is List && p.length >= 3)
                  (
                    (p[0]! as num).toInt(),
                    (p[1]! as num).toDouble(),
                    (p[2]! as num).toDouble(),
                    p.length > 3 ? (p[3] as num?)?.toDouble() : null,
                  ),
            ]
          : null,
    );
  }

  final String id;
  final DateTime start;
  final DateTime end;
  final bool treadmill;
  final int pausedSeconds;
  final double? distanceM;
  final double? hrAvg;
  final double? hrMax;

  /// (UTC ms, lat, lon, elevation) per point; null when not shared.
  final List<(int, double, double, double?)>? route;

  int get movingSeconds {
    final total = end.difference(start).inSeconds;
    final moving = total - pausedSeconds;
    return moving > 0 ? moving : total;
  }

  /// The route as FITOS's track: seconds from the start, 0.1 s steps,
  /// strictly increasing (points at the same moment are dropped). Null
  /// under two points.
  Track? get track {
    final r = route;
    if (r == null) return null;
    final points = <TrackPoint>[];
    var last = -1.0;
    for (final (ms, lat, lon, ele) in r) {
      final t = ((ms - start.millisecondsSinceEpoch) / 100).round() / 10;
      if (t < 0 || t <= last) continue;
      last = t;
      points.add(TrackPoint(t: t, lat: lat, lon: lon, ele: ele));
    }
    return points.length < 2 ? null : Track([points]);
  }

  /// Seconds this run shares with [startedAt]–[endedAt].
  int overlapSeconds(DateTime startedAt, DateTime endedAt) {
    final a = start.isAfter(startedAt) ? start : startedAt;
    final b = end.isBefore(endedAt) ? end : endedAt;
    return b.isAfter(a) ? b.difference(a).inSeconds : 0;
  }
}

/// Where watch runs are read from; the app reads Health Connect.
abstract class WatchRunSource {
  /// Whether reading runs is allowed (Health Connect has it, and the user
  /// granted exercise and distance).
  Future<bool> ready();

  /// Asks Health Connect for the watch permissions; true when granted.
  Future<bool> ask();

  Future<List<WatchRun>> runs({required DateTime start, required DateTime end});
}

class HealthConnectWatchSource implements WatchRunSource {
  const HealthConnectWatchSource(this._channel);

  final HealthConnectChannel _channel;

  static const needed = ['exercise', 'distance'];
  static const wanted = ['exercise', 'distance', 'heartRate', 'exerciseRoutes'];

  @override
  Future<bool> ready() async {
    try {
      if (await _channel.sdkStatus() != 'available') return false;
      final granted = await _channel.grantedPermissions();
      return needed.every(granted.contains);
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> ask() async {
    try {
      if (await _channel.sdkStatus() != 'available') return false;
      final granted = await _channel.requestPermissions(wanted);
      return needed.every(granted.contains);
    } on Object {
      return false;
    }
  }

  @override
  Future<List<WatchRun>> runs({
    required DateTime start,
    required DateTime end,
  }) async {
    final raw = await _channel.runningSessions(start: start, end: end);
    return [
      for (final m in raw)
        if (WatchRun.fromChannel(m) case final r?) r,
    ];
  }
}

/// What one import did: how many runs came in; [offline] when the server
/// could not be reached (what is left comes in next time).
class WatchImportResult {
  const WatchImportResult(this.imported, {this.offline = false});
  final int imported;
  final bool offline;
}

class WatchImporter {
  WatchImporter({
    required this.source,
    required this.api,
    required this.userId,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final WatchRunSource source;
  final RunningApi api;
  final String userId;
  final DateTime Function() _now;

  /// The first import looks back this far; later ones from the last, less
  /// two days (a run synced late by Samsung Health).
  static const firstLook = Duration(days: 30);
  static const overlap = Duration(days: 2);
  static const _uuid = Uuid();

  String get _cursorKey => 'running.watchImport.after.$userId';
  String get _doneKey => 'running.watchImport.done.$userId';

  /// The phone's id for a Health Connect record: the same on every phone.
  String clientIdFor(String externalId) =>
      _uuid.v5(Namespace.url.value, 'fitos-watch:$userId:$externalId');

  /// Imports what is new. [phoneRuns]: the runs FITOS has (recorded on the
  /// phone, or imported), to leave out a watch run the phone also has.
  Future<WatchImportResult> run(List<RunSummary> phoneRuns) async {
    if (!await source.ready()) return const WatchImportResult(0);
    final prefs = await SharedPreferences.getInstance();
    final now = _now().toUtc();
    final after = DateTime.tryParse(prefs.getString(_cursorKey) ?? '');
    final from = after == null || now.difference(after) > firstLook
        ? now.subtract(firstLook)
        : after.subtract(overlap);
    final done = {...prefs.getStringList(_doneKey) ?? const <String>[]};
    var imported = 0;
    final List<WatchRun> found;
    try {
      found = await source.runs(start: from, end: now);
    } on Object {
      return const WatchImportResult(0);
    }
    for (final w in found..sort((a, b) => a.start.compareTo(b.start))) {
      if (done.contains(w.id)) continue;
      final doubled = phoneRuns.any(
        (r) =>
            r.source != RunSource.watch &&
            w.overlapSeconds(r.startedAt, r.endedAt) * 2 >
                w.end.difference(w.start).inSeconds,
      );
      if (doubled) {
        done.add(w.id);
        continue;
      }
      final body = _body(w);
      if (body == null) {
        done.add(w.id);
        continue;
      }
      switch (await api.createRun(body)) {
        case Ok():
          done.add(w.id);
          imported++;
        case Err():
          // Offline, or the server said no: tried again next time.
          await _save(prefs, done, null);
          return WatchImportResult(imported, offline: true);
      }
    }
    await _save(prefs, done, now);
    return WatchImportResult(imported);
  }

  Future<void> _save(
    SharedPreferences prefs,
    Set<String> done,
    DateTime? cursor,
  ) async {
    // The last 500 ids are plenty: older runs are outside the look-back.
    final keep = done.toList();
    await prefs.setStringList(
      _doneKey,
      keep.length > 500 ? keep.sublist(keep.length - 500) : keep,
    );
    if (cursor != null) {
      await prefs.setString(_cursorKey, cursor.toIso8601String());
    }
  }

  /// The run as `POST /running/runs` takes it; null when it cannot be one
  /// (no route and no distance).
  Map<String, dynamic>? _body(WatchRun w) {
    final track = w.treadmill ? null : w.track;
    if (track == null && (w.distanceM == null || w.distanceM! <= 0)) {
      return null;
    }
    int? bpm(double? v) {
      if (v == null) return null;
      final b = v.round();
      return b >= 25 && b <= 250 ? b : null;
    }

    final local = w.start.toLocal();
    final hrAvg = bpm(w.hrAvg);
    final hrMax = bpm(w.hrMax);
    return {
      'clientRunId': clientIdFor(w.id),
      'kind': w.treadmill ? 'treadmill' : 'outdoor',
      'name':
          '${defaultRunName(local, w.treadmill ? RunKind.treadmill : RunKind.outdoor)} · Watch',
      'startedAt': w.start.toIso8601String(),
      'endedAt': w.end.toIso8601String(),
      'durationSeconds': w.movingSeconds,
      'goal': const RunGoal.free().toJson(),
      if (track != null) 'track': encodeTrack(track).toJson(),
      if (track == null) 'distanceM': w.distanceM,
      'source': 'watch',
      'externalId': w.id,
      if (hrAvg != null) 'hrAvg': hrAvg,
      if (hrMax != null) 'hrMax': hrMax,
    };
  }
}
