import 'dart:math' as math;

import 'track.dart';

/// Beta 4.4 (owner 2026-10-29): a run told again — pace colours along the
/// route, and the replay that draws it with a moving dot. Both read the
/// run's own track (the phone has it); nothing new is sent or kept.

/// One stretch of the route and how its pace compares with the run's
/// average: -1 much faster, 0 the average, +1 much slower.
class PaceStretch {
  const PaceStretch(this.points, this.relative);

  /// [lat, lon] pairs; consecutive stretches share their boundary point.
  final List<(double, double)> points;
  final double relative;
}

/// How far from the average reads as "much" faster or slower (±15 %).
const double paceColourSpread = 0.15;

/// The route in stretches of about [bucketM] metres (a stretch never spans
/// a pause), each smoothed with its neighbours so GPS noise does not paint
/// stripes. Empty for a route too short to compare.
List<PaceStretch> paceStretches(Track track, {double bucketM = 50}) {
  final raw = <({List<(double, double)> pts, double m, double s})>[];
  var totalM = 0.0;
  var totalS = 0.0;
  for (final seg in track.segments) {
    if (seg.length < 2) continue;
    var pts = <(double, double)>[(seg.first.lat, seg.first.lon)];
    var m = 0.0;
    var s = 0.0;
    for (var i = 1; i < seg.length; i++) {
      m += distanceBetween(seg[i - 1], seg[i]);
      s += seg[i].t - seg[i - 1].t;
      pts.add((seg[i].lat, seg[i].lon));
      if (m >= bucketM || i == seg.length - 1) {
        raw.add((pts: pts, m: m, s: s));
        totalM += m;
        totalS += s;
        pts = [(seg[i].lat, seg[i].lon)];
        m = 0;
        s = 0;
      }
    }
  }
  if (raw.length < 2 || totalM <= 0) return const [];
  final avg = totalS / totalM;
  double pace(int i) => raw[i].m <= 0 ? avg : raw[i].s / raw[i].m;
  return [
    for (var i = 0; i < raw.length; i++)
      PaceStretch(
        raw[i].pts,
        (((pace(math.max(0, i - 1)) +
                            pace(i) +
                            pace(math.min(raw.length - 1, i + 1))) /
                        3 -
                    avg) /
                avg /
                paceColourSpread)
            .clamp(-1.0, 1.0),
      ),
  ];
}

/// The replay's moment: where the runner was, after how long (moving) and
/// how far, and the pace there (over the last ~200 m; null at the start).
class ReplayMoment {
  const ReplayMoment({
    required this.position,
    required this.seconds,
    required this.distanceM,
    required this.paceSecPerKm,
  });

  final (double, double) position;
  final double seconds;
  final double distanceM;
  final double? paceSecPerKm;
}

/// A run along its moving time: [at] a fraction 0–1 of the run gives the
/// moment, and [routeTo] the route drawn so far. Pauses take no replay
/// time: the dot jumps the gap.
class ReplayTimeline {
  ReplayTimeline(Track track) {
    for (final seg in track.segments) {
      for (var i = 0; i < seg.length; i++) {
        if (i > 0) {
          _d += distanceBetween(seg[i - 1], seg[i]);
          _m += seg[i].t - seg[i - 1].t;
        } else if (_lat.isNotEmpty) {
          _breaks.add(_lat.length);
        }
        _lat.add(seg[i].lat);
        _lon.add(seg[i].lon);
        _dist.add(_d);
        _move.add(_m);
      }
    }
  }

  final _lat = <double>[];
  final _lon = <double>[];
  final _dist = <double>[];
  final _move = <double>[];

  /// The index of each segment's first point after the first.
  final _breaks = <int>[];
  double _d = 0;
  double _m = 0;

  bool get isEmpty => _lat.length < 2 || _m <= 0;
  double get totalSeconds => _m;
  double get totalDistanceM => _d;

  /// The last point at or before moving second [s] (binary search).
  int _indexAt(double s) {
    var lo = 0;
    var hi = _move.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (_move[mid] <= s) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  ReplayMoment at(double fraction) {
    final s = fraction.clamp(0.0, 1.0) * _m;
    final i = _indexAt(s);
    final j = math.min(i + 1, _lat.length - 1);
    final span = _move[j] - _move[i];
    final f = span <= 0 || _breaks.contains(j) ? 0.0 : (s - _move[i]) / span;
    final d = _dist[i] + f * (_dist[j] - _dist[i]);
    // Pace over the last ~200 m (moving time, so a pause adds nothing).
    final back = d - 200;
    double? pace;
    if (back > 0) {
      final k = _indexAtDistance(back);
      final ds = d - _dist[k];
      final ts = s - _move[k];
      if (ds > 1) pace = ts / (ds / 1000);
    }
    return ReplayMoment(
      position: (
        _lat[i] + f * (_lat[j] - _lat[i]),
        _lon[i] + f * (_lon[j] - _lon[i]),
      ),
      seconds: s,
      distanceM: d,
      paceSecPerKm: pace,
    );
  }

  int _indexAtDistance(double d) {
    var lo = 0;
    var hi = _dist.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (_dist[mid] <= d) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  /// The route up to [fraction], one list per stretch between pauses, the
  /// last one ending where the dot is.
  List<List<(double, double)>> routeTo(double fraction) {
    final m = at(fraction);
    final i = _indexAt(m.seconds);
    final out = <List<(double, double)>>[];
    var current = <(double, double)>[];
    for (var k = 0; k <= i; k++) {
      if (_breaks.contains(k)) {
        if (current.length >= 2) out.add(current);
        current = [];
      }
      current.add((_lat[k], _lon[k]));
    }
    current.add(m.position);
    if (current.length >= 2) out.add(current);
    return out;
  }
}
