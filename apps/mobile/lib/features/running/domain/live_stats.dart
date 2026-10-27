import 'dart:math' as math;

import 'run_math.dart';
import 'track.dart';

/// Beta 4.0 (ADR-038): the numbers on screen while you run, added up point
/// by point with the server's rules (run_math.dart) so the total at the end
/// is the one the summary and the server get.
class LiveTrack {
  LiveTrack({this.weightKg, this.splitUnitM = 1000});

  final double? weightKg;

  /// Where splits fall: 1000 m, or a mile.
  final double splitUnitM;

  final List<List<TrackPoint>> segments = [];
  final ElevationGain _gain = ElevationGain();
  double _distance = 0;
  double _moving = 0;
  double _kcal = 0;

  /// Completed splits so far (seconds each), in the split unit.
  final List<double> splitSeconds = [];
  double _splitStartMoving = 0;

  /// The window the current pace looks back over.
  static const double paceWindowSeconds = 30;

  /// Less than this in the window gives no current pace (standing, a weak fix).
  static const double paceWindowMinM = 20;

  double get distanceM => _distance;
  double get movingSeconds => _moving;
  double? get elevationGainM => _gain.value;
  int? get calories => weightKg == null ? null : jsRound(_kcal);
  Track get track => Track(segments);

  /// Adds a stored point; [newSegment] after a pause.
  void add(TrackPoint p, {bool newSegment = false}) {
    if (newSegment || segments.isEmpty) segments.add(<TrackPoint>[]);
    final seg = segments.last;
    _gain.add(p.ele);
    if (seg.isNotEmpty) {
      final a = seg.last;
      final step = distanceBetween(a, p);
      final dt = p.t - a.t;
      final before = _distance;
      final movingBefore = _moving;
      _distance += step;
      _moving += dt;
      if (weightKg != null) _kcal += kcalAt(step / dt * 60, dt, weightKg!);
      // Every split boundary this step crossed, interpolated inside it.
      var next = (splitSeconds.length + 1) * splitUnitM;
      while (_distance >= next && step > 0) {
        final f = (next - before) / step;
        final at = movingBefore + f * dt;
        splitSeconds.add(at - _splitStartMoving);
        _splitStartMoving = at;
        next = (splitSeconds.length + 1) * splitUnitM;
      }
    }
    seg.add(p);
  }

  /// Seconds per km over the last [paceWindowSeconds] of the current
  /// segment; null when that covers under [paceWindowMinM].
  double? get currentPaceSecPerKm {
    if (segments.isEmpty || segments.last.length < 2) return null;
    final seg = segments.last;
    final end = seg.last;
    var d = 0.0;
    var i = seg.length - 1;
    while (i > 0 && end.t - seg[i - 1].t <= paceWindowSeconds) {
      d += distanceBetween(seg[i - 1], seg[i]);
      i--;
    }
    final dt = end.t - seg[i].t;
    if (d < paceWindowMinM || dt <= 0) return null;
    return dt / (d / 1000);
  }

  /// Metres a second over the same window.
  double? get currentSpeedMs {
    final pace = currentPaceSecPerKm;
    return pace == null ? null : 1000 / pace;
  }

  /// The split in progress: how far into it, and for how long.
  ({double metres, double seconds}) get splitSoFar => (
        metres: math.max(0, _distance - splitSeconds.length * splitUnitM),
        seconds: math.max(0, _moving - _splitStartMoving),
      );
}

/// Where a run is against its goal, 0–1; null for a free run or pace goal.
double? goalProgress({
  required String goalKind,
  required int? goalValue,
  required double distanceM,
  required int activeSeconds,
}) {
  if (goalValue == null || goalValue <= 0) return null;
  return switch (goalKind) {
    'distance' => math.min(1, distanceM / goalValue),
    'time' => math.min(1, activeSeconds / goalValue),
    _ => null,
  };
}
