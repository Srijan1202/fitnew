import 'dart:math' as math;

import 'track.dart';

/// Beta 4.0 (ADR-038): what a run adds up to — the same rules as packages/core
/// `running/summary.ts`, which keeps the record on the server.
///
/// MASTER-SPEC §7.3 keeps business rules off the phone; this is the one
/// exception (ADR-038): a run's numbers must show live, every second, with
/// no signal, and a finished run must show its summary before it uploads.
/// The server's figures replace these once it has the run. The shared
/// fixtures (packages/core/test/fixtures/running) hold both to the same
/// numbers.

const double mileM = 1609.344;
const double minPaceDistanceM = 10;
const double climbThresholdM = 5;
const double walkBelowMPerMin = 100;
const double maxCalorieSpeedMPerMin = 400;
const double seriesBucketM = 50;
const int seriesMaxBuckets = 100;
const int outlineMaxPoints = 64;
const double minLastSplitM = 10;

double round1(double x) => jsRound(x * 10) / 10;

class RunSplit {
  const RunSplit({
    required this.index,
    required this.distanceM,
    required this.seconds,
    required this.pace,
    required this.elevationChangeM,
  });

  factory RunSplit.fromJson(Map<String, dynamic> j) => RunSplit(
        index: (j['index'] as num).toInt(),
        distanceM: (j['distanceM'] as num).toDouble(),
        seconds: (j['seconds'] as num).toDouble(),
        pace: (j['pace'] as num).toDouble(),
        elevationChangeM: (j['elevationChangeM'] as num?)?.toDouble(),
      );

  final int index;
  final double distanceM;
  final double seconds;

  /// Seconds per unit (per km or per mile).
  final double pace;
  final double? elevationChangeM;
}

class SeriesPoint {
  const SeriesPoint({
    required this.distanceM,
    required this.pace,
    required this.ele,
  });

  factory SeriesPoint.fromJson(Map<String, dynamic> j) => SeriesPoint(
        distanceM: (j['distanceM'] as num).toDouble(),
        pace: (j['pace'] as num).toDouble(),
        ele: (j['ele'] as num?)?.toDouble(),
      );

  final double distanceM;

  /// Seconds per km over the bucket.
  final double pace;
  final double? ele;
}

class RunFigures {
  const RunFigures({
    required this.distanceM,
    required this.durationSeconds,
    required this.avgPaceSecPerKm,
    required this.elevationGainM,
    required this.calories,
    required this.splitsKm,
    required this.splitsMi,
    required this.series,
    required this.outline,
  });

  final double distanceM;
  final int durationSeconds;
  final double? avgPaceSecPerKm;
  final double? elevationGainM;
  final int? calories;
  final List<RunSplit> splitsKm;
  final List<RunSplit> splitsMi;
  final List<SeriesPoint> series;
  final List<(double, double)> outline;
}

/// The track flattened with running totals.
class _Profile {
  final d = <double>[];
  final m = <double>[];
  final ele = <double?>[];
  final lat = <double>[];
  final lon = <double>[];

  double get total => d.isEmpty ? 0 : d.last;
}

_Profile _profileOf(Track track) {
  final p = _Profile();
  var d = 0.0;
  var m = 0.0;
  for (final segment in track.segments) {
    for (var i = 0; i < segment.length; i++) {
      final pt = segment[i];
      if (i > 0) {
        d += distanceBetween(segment[i - 1], pt);
        m += pt.t - segment[i - 1].t;
      }
      p.d.add(d);
      p.m.add(m);
      p.ele.add(pt.ele);
      p.lat.add(pt.lat);
      p.lon.add(pt.lon);
    }
  }
  return p;
}

({double m, double? ele}) _at(_Profile p, double x) {
  var j = 0;
  while (p.d[j] < x) {
    j++;
  }
  if (j == 0 || p.d[j] == p.d[j - 1]) return (m: p.m[j], ele: p.ele[j]);
  final i = j - 1;
  final f = (x - p.d[i]) / (p.d[j] - p.d[i]);
  final ei = p.ele[i];
  final ej = p.ele[j];
  return (
    m: p.m[i] + f * (p.m[j] - p.m[i]),
    ele: ei == null || ej == null ? null : ei + f * (ej - ei),
  );
}

List<RunSplit> _splitsOf(_Profile p, double unit) {
  final total = p.total;
  final out = <RunSplit>[];
  if (total <= 0) return out;
  var from = _at(p, 0);
  var start = 0.0;
  for (var k = 1; start < total; k++) {
    final end = math.min(k * unit, total);
    final dist = end - start;
    if (end == total && end < k * unit && dist < minLastSplitM) break;
    final to = _at(p, end);
    final seconds = to.m - from.m;
    out.add(
      RunSplit(
        index: k,
        distanceM: round1(dist),
        seconds: round1(seconds),
        pace: round1(seconds / (dist / unit)),
        elevationChangeM: from.ele == null || to.ele == null
            ? null
            : round1(to.ele! - from.ele!),
      ),
    );
    from = to;
    start = end;
  }
  return out;
}

List<SeriesPoint> _seriesOf(_Profile p) {
  final total = p.total;
  final n = math.min(seriesMaxBuckets, (total / seriesBucketM).floor());
  if (n < 1) return const [];
  final w = total / n;
  final out = <SeriesPoint>[];
  var from = _at(p, 0);
  for (var k = 1; k <= n; k++) {
    final x = k == n ? total : k * w;
    final to = _at(p, x);
    out.add(
      SeriesPoint(
        distanceM: round1(x),
        pace: round1((to.m - from.m) / (w / 1000)),
        ele: to.ele == null ? null : round1(to.ele!),
      ),
    );
    from = to;
  }
  return out;
}

/// Climbs of at least [climbThresholdM] over the lowest point since the last.
class ElevationGain {
  double? _base;
  double _gain = 0;
  bool _any = false;

  void add(double? e) {
    if (e == null) return;
    _any = true;
    final base = _base;
    if (base == null || e < base) {
      _base = e;
    } else if (e - base >= climbThresholdM) {
      _gain += e - base;
      _base = e;
    }
  }

  double? get value => _any ? round1(_gain) : null;
}

double? elevationGain(Track track) {
  final g = ElevationGain();
  for (final s in track.segments) {
    for (final p in s) {
      g.add(p.ele);
    }
  }
  return g.value;
}

/// ACSM gross VO2 (ml/kg/min), level ground.
double vo2At(double metresPerMinute) {
  final s = math.min(metresPerMinute, maxCalorieSpeedMPerMin);
  return s < walkBelowMPerMin ? 0.1 * s + 3.5 : 0.2 * s + 3.5;
}

double kcalAt(double metresPerMinute, double seconds, double weightKg) =>
    vo2At(metresPerMinute) * weightKg / 1000 * 5 * (seconds / 60);

double _caloriesOf(Track track, double weightKg) {
  var kcal = 0.0;
  for (final segment in track.segments) {
    for (var i = 1; i < segment.length; i++) {
      final a = segment[i - 1];
      final b = segment[i];
      final dt = b.t - a.t;
      kcal += kcalAt(distanceBetween(a, b) / dt * 60, dt, weightKg);
    }
  }
  return kcal;
}

List<(double, double)> _outlineOf(_Profile p) {
  final n = p.lat.length;
  if (n == 0) return const [];
  final take = math.min(n, outlineMaxPoints);
  return [
    for (var k = 0; k < take; k++)
      () {
        final i = take == 1 ? 0 : jsRound(k * (n - 1) / (take - 1));
        return (jsRound(p.lat[i] * 1e5) / 1e5, jsRound(p.lon[i] * 1e5) / 1e5);
      }(),
  ];
}

double? paceOf(int durationSeconds, double distanceM) =>
    distanceM < minPaceDistanceM
        ? null
        : round1(durationSeconds / (distanceM / 1000));

/// An outdoor run, as the server will work it out.
RunFigures summarizeTrack(Track track, int durationSeconds, double? weightKg) {
  final p = _profileOf(track);
  final distanceM = round1(p.total);
  return RunFigures(
    distanceM: distanceM,
    durationSeconds: durationSeconds,
    avgPaceSecPerKm: paceOf(durationSeconds, distanceM),
    elevationGainM: elevationGain(track),
    calories: weightKg == null ? null : jsRound(_caloriesOf(track, weightKg)),
    splitsKm: _splitsOf(p, 1000),
    splitsMi: _splitsOf(p, mileM),
    series: _seriesOf(p),
    outline: _outlineOf(p),
  );
}

/// A treadmill run: the typed distance, an even pace.
RunFigures summarizeTreadmill(
  double distanceM,
  int durationSeconds,
  double? weightKg,
) {
  final speed = durationSeconds > 0 ? distanceM / durationSeconds * 60 : 0.0;
  return RunFigures(
    distanceM: round1(distanceM),
    durationSeconds: durationSeconds,
    avgPaceSecPerKm: paceOf(durationSeconds, distanceM),
    elevationGainM: null,
    calories: weightKg == null
        ? null
        : jsRound(kcalAt(speed, durationSeconds.toDouble(), weightKg)),
    splitsKm: const [],
    splitsMi: const [],
    series: const [],
    outline: const [],
  );
}
