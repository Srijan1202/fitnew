import 'dart:math' as math;

import 'track.dart';

/// Beta 4.0 (ADR-038): from raw GPS fixes to the points a run stores. This is
/// sensor cleaning, not a figure: what it lets through is the track, and the
/// phone and the server then compute every number from the same points.
///
///  - A fix worse than [maxAccuracyM] is dropped.
///  - A fix that would mean running faster than [maxSpeedMs] from the last
///    good one is a jump and dropped; after [jumpResetAfter] in a row the
///    phone has really moved (out of a tunnel) and the filter starts again
///    from there.
///  - Positions pass through a small Kalman filter (process noise
///    [processNoiseMs]): a fix counts more the more accurate it is, and
///    jitter on a straight line is smoothed out.
///  - A point is stored only [minStepM] or more from the last one stored, so
///    standing at a crossing adds no distance.
///  - Elevation is smoothed (an exponential average) and kept only when the
///    phone reports one.

class GpsFix {
  const GpsFix({
    required this.at,
    required this.lat,
    required this.lon,
    required this.accuracyM,
    this.altitudeM,
    this.speedMs,
  });

  final DateTime at;
  final double lat;
  final double lon;
  final double accuracyM;

  /// Null when the phone gave no altitude.
  final double? altitudeM;

  /// The receiver's own (Doppler) speed; null when it gave none.
  final double? speedMs;
}

const double maxAccuracyM = 20;
const double maxSpeedMs = 12.5;
const int jumpResetAfter = 8;
const double processNoiseMs = 3;
const double minStepM = 3;
const double elevationSmoothing = 0.25;

/// Lat/lon Kalman filter with a variance in square metres.
class _Kalman {
  double? _lat;
  double? _lon;
  double _variance = -1;
  DateTime? _at;

  void reset() {
    _variance = -1;
    _lat = null;
    _lon = null;
    _at = null;
  }

  (double, double) process(GpsFix f) {
    final acc = math.max(1.0, f.accuracyM);
    if (_variance < 0 || _lat == null) {
      _lat = f.lat;
      _lon = f.lon;
      _variance = acc * acc;
      _at = f.at;
    } else {
      final dtMs = f.at.difference(_at!).inMilliseconds;
      if (dtMs > 0) {
        _variance += dtMs * processNoiseMs * processNoiseMs / 1000;
        _at = f.at;
      }
      final k = _variance / (_variance + acc * acc);
      _lat = _lat! + k * (f.lat - _lat!);
      _lon = _lon! + k * (f.lon - _lon!);
      _variance = (1 - k) * _variance;
    }
    return (_lat!, _lon!);
  }
}

/// What one fix did: stored a point (or not) and the speed it gives.
class FilterResult {
  const FilterResult({this.point, this.speedMs});

  /// The point to store, rounded as the encoding keeps it; null when none.
  final TrackPoint? point;

  /// The best speed estimate now (Doppler, else from the smoothed track);
  /// null when the fix was dropped.
  final double? speedMs;
}

class GpsFilter {
  GpsFilter({required this.startedAt});

  /// The run's start: point times are seconds since it.
  final DateTime startedAt;

  final _kalman = _Kalman();
  GpsFix? _lastGood;
  (double, double)? _lastSmoothed;
  TrackPoint? _lastStored;
  double? _ele;
  int _jumps = 0;

  /// A pause ends the segment: the next point stored starts a new one.
  void newSegment() {
    _lastStored = null;
  }

  FilterResult add(GpsFix f) {
    if (f.accuracyM > maxAccuracyM) return const FilterResult();
    final last = _lastGood;
    if (last != null) {
      final dt = f.at.difference(last.at).inMilliseconds / 1000;
      if (dt <= 0) return const FilterResult();
      final moved = haversine(
        (lat: last.lat, lon: last.lon),
        (lat: f.lat, lon: f.lon),
      );
      if (moved / dt > maxSpeedMs) {
        _jumps++;
        if (_jumps < jumpResetAfter) return const FilterResult();
        _kalman.reset();
        _lastSmoothed = null;
      }
    }
    _jumps = 0;
    final previous = _lastGood;
    _lastGood = f;

    final smoothed = _kalman.process(f);
    double? derived;
    final before = _lastSmoothed;
    if (before != null && previous != null) {
      final dt = f.at.difference(previous.at).inMilliseconds / 1000;
      derived = haversine(
            (lat: before.$1, lon: before.$2),
            (lat: smoothed.$1, lon: smoothed.$2),
          ) /
          dt;
    }
    _lastSmoothed = smoothed;
    final speed = f.speedMs ?? derived;

    if (f.altitudeM != null) {
      _ele = _ele == null
          ? f.altitudeM
          : _ele! + elevationSmoothing * (f.altitudeM! - _ele!);
    }
    final t = f.at.difference(startedAt).inMilliseconds / 1000;
    final candidate = TrackPoint(
      t: t,
      lat: smoothed.$1,
      lon: smoothed.$2,
      ele: f.altitudeM == null ? null : _ele,
    ).quantized();
    final stored = _lastStored;
    if (stored != null) {
      if (candidate.t <= stored.t ||
          distanceBetween(stored, candidate) < minStepM) {
        return FilterResult(speedMs: speed);
      }
    } else if (candidate.t < 0) {
      return FilterResult(speedMs: speed);
    }
    _lastStored = candidate;
    return FilterResult(point: candidate, speedMs: speed);
  }
}

/// Auto-pause: stopped when slower than [stopBelowMs] for [stopAfter];
/// moving again after [moveAbove] twice in a row.
class AutoPause {
  static const double stopBelowMs = 0.6;
  static const Duration stopAfter = Duration(seconds: 8);
  static const double moveAboveMs = 1.2;
  static const int moveFixes = 2;

  DateTime? _slowSince;
  int _fast = 0;
  bool _paused = false;

  bool get paused => _paused;

  /// Feeds one speed; true when the state changed.
  bool add(DateTime at, double? speedMs) {
    if (speedMs == null) return false;
    if (!_paused) {
      if (speedMs < stopBelowMs) {
        _slowSince ??= at;
        if (at.difference(_slowSince!) >= stopAfter) {
          _paused = true;
          _fast = 0;
          return true;
        }
      } else {
        _slowSince = null;
      }
      return false;
    }
    if (speedMs > moveAboveMs) {
      _fast++;
      if (_fast >= moveFixes) {
        _paused = false;
        _slowSince = null;
        _fast = 0;
        return true;
      }
    } else {
      _fast = 0;
    }
    return false;
  }

  void reset() {
    _paused = false;
    _slowSince = null;
    _fast = 0;
  }
}
