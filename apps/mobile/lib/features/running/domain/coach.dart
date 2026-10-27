import 'track.dart';
import 'units.dart';
import 'workout.dart';

/// Beta 4.1 (ADR-039): what the voice coach says, and when. Pure: the
/// recorder asks it once a second with the live figures and speaks what it
/// returns. It reads only what the phone already shows (§7.3's running
/// exception, ADR-038 D8); nothing it says is kept.
///
///  - Every km or mile (or every half): the distance, the time, the last
///    split and the average.
///  - Off a pace target by more than [paceToleranceSec] for [paceHoldSec]:
///    "ease off" or "pick it up", at most once every [paceGapSec].
///  - Start guidance: in the first km, [startFastSec] faster than the target
///    is "hold back". Two thirds into a distance goal on target: "on track".
///  - Goals: halfway, the last km (or last five minutes), reached.
///  - Workouts: each step as it begins, the last 10 s of a timed step, and a
///    3-2-1 into a rep from a rest.
class CoachSettings {
  const CoachSettings({
    this.enabled = true,
    this.everyHalf = false,
    this.splits = true,
  });

  final bool enabled;

  /// Calls every half unit as well as every whole one.
  final bool everyHalf;

  /// Off: no distance calls (the pace and goal calls stay).
  final bool splits;
}

class CoachInput {
  const CoachInput({
    required this.activeSeconds,
    required this.distanceM,
    required this.avgPaceSecPerKm,
    required this.currentPaceSecPerKm,
    required this.lastSplitSeconds,
    required this.goalKind,
    required this.goalValue,
    required this.target,
  });

  final int activeSeconds;
  final double distanceM;
  final double? avgPaceSecPerKm;
  final double? currentPaceSecPerKm;

  /// The last whole split's seconds (per unit), if any.
  final double? lastSplitSeconds;

  /// `free` | `distance` | `time` | `pace`.
  final String goalKind;
  final int? goalValue;

  /// The pace to hold now (seconds per km): the step's, the plan's, or the goal's.
  final PaceRange? target;
}

const int paceToleranceSec = 10;
const int paceHoldSec = 30;
const int paceGapSec = 60;
const int startFastSec = 15;

String _plural(int n, String one, [String? many]) =>
    '$n ${n == 1 ? one : many ?? '${one}s'}';

/// "27 minutes 10", "1 hour 5 minutes", "45 seconds".
String spokenDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  if (h > 0) return '${_plural(h, 'hour')} ${_plural(m, 'minute')}';
  if (m == 0) return _plural(s, 'second');
  return s == 0 ? _plural(m, 'minute') : '${_plural(m, 'minute')} $s';
}

/// A pace per unit as said aloud: "5 40", "5 05".
String spokenPace(double secPerUnit) {
  final s = jsRound(secPerUnit);
  return '${s ~/ 60} ${(s % 60).toString().padLeft(2, '0')}';
}

String _unitWord(DistanceUnit u, {bool plural = true}) => u == DistanceUnit.km
    ? (plural ? 'kilometres' : 'kilometre')
    : (plural ? 'miles' : 'mile');

String _distanceSaid(double metres, DistanceUnit u) {
  final v = metres / u.metres;
  final whole = (v * 2).round() / 2;
  final text = whole == whole.roundToDouble()
      ? '${whole.round()}'
      : whole.toStringAsFixed(1);
  return '$text ${_unitWord(u, plural: whole != 1)}';
}

class Coach {
  Coach({required this.settings, required this.unit});

  final CoachSettings settings;
  final DistanceUnit unit;

  int _halves = 0;
  int? _fastSince;
  int? _slowSince;
  int _lastPaceCue = -100000;
  bool _startSaid = false;
  bool _onTrackSaid = false;
  bool _halfwaySaid = false;
  bool _lastStretchSaid = false;
  bool _reachedSaid = false;

  double get _perUnit => unit.metres / 1000;

  /// What to say this second (often nothing).
  List<String> tick(CoachInput i) {
    if (!settings.enabled) return const [];
    final out = <String>[];
    _splits(i, out);
    _goal(i, out);
    _pace(i, out);
    return out;
  }

  void _splits(CoachInput i, List<String> out) {
    final halves = (i.distanceM / (unit.metres / 2)).floor();
    if (halves <= _halves) return;
    _halves = halves;
    if (!settings.splits) return;
    final whole = halves.isEven;
    if (!whole && !settings.everyHalf) return;
    final parts = <String>[
      '${_distanceSaid(halves * unit.metres / 2, unit)}.',
      '${spokenDuration(i.activeSeconds)}.',
    ];
    if (whole && i.lastSplitSeconds != null) {
      parts.add(
        'Last ${_unitWord(unit, plural: false)} ${spokenPace(i.lastSplitSeconds!)}.',
      );
    }
    if (i.avgPaceSecPerKm != null) {
      parts.add('Average ${spokenPace(i.avgPaceSecPerKm! * _perUnit)}.');
    }
    out.add(parts.join(' '));
  }

  void _goal(CoachInput i, List<String> out) {
    final g = i.goalValue;
    if (g == null || g <= 0) return;
    if (i.goalKind == 'distance') {
      if (!_reachedSaid && i.distanceM >= g) {
        _reachedSaid = _halfwaySaid = _lastStretchSaid = true;
        out.add(
          'Goal reached. ${_distanceSaid(g.toDouble(), unit)} in ${spokenDuration(i.activeSeconds)}.',
        );
        return;
      }
      if (!_halfwaySaid && i.distanceM >= g / 2) {
        _halfwaySaid = true;
        out.add('Halfway. ${_distanceSaid(g - i.distanceM, unit)} to go.');
      }
      if (!_lastStretchSaid &&
          g >= 2 * unit.metres &&
          g - i.distanceM <= unit.metres) {
        _lastStretchSaid = true;
        out.add('One ${_unitWord(unit, plural: false)} to go.');
      }
      final t = i.target;
      final avg = i.avgPaceSecPerKm;
      if (!_onTrackSaid &&
          t != null &&
          avg != null &&
          i.distanceM >= g * 2 / 3) {
        _onTrackSaid = true;
        if (avg >= t.fast - 5 && avg <= t.slow + 5) {
          out.add('On track. Hold this or pick it up to the finish.');
        }
      }
    } else if (i.goalKind == 'time') {
      if (!_reachedSaid && i.activeSeconds >= g) {
        _reachedSaid = _halfwaySaid = _lastStretchSaid = true;
        out.add(
          'Goal reached. ${spokenDuration(g)}, ${_distanceSaid(i.distanceM, unit)}.',
        );
        return;
      }
      if (!_halfwaySaid && i.activeSeconds >= g / 2) {
        _halfwaySaid = true;
        out.add('Halfway. ${spokenDuration(g - i.activeSeconds)} to go.');
      }
      if (!_lastStretchSaid && g >= 900 && g - i.activeSeconds <= 300) {
        _lastStretchSaid = true;
        out.add('Five minutes to go.');
      }
    }
  }

  void _pace(CoachInput i, List<String> out) {
    final t = i.target;
    final now = i.currentPaceSecPerKm;
    if (t == null || now == null) {
      _fastSince = _slowSince = null;
      return;
    }
    // Start guidance: the classic mistake is going out too fast.
    if (!_startSaid &&
        i.distanceM < 1000 &&
        i.activeSeconds >= 60 &&
        now < t.fast - startFastSec) {
      _startSaid = true;
      _lastPaceCue = i.activeSeconds;
      out.add("Easy start. Hold back for now, you'll thank yourself later.");
      return;
    }
    final fast = now < t.fast - paceToleranceSec;
    final slow = now > t.slow + paceToleranceSec;
    _fastSince = fast ? (_fastSince ?? i.activeSeconds) : null;
    _slowSince = slow ? (_slowSince ?? i.activeSeconds) : null;
    final since = _fastSince ?? _slowSince;
    if (since == null ||
        i.activeSeconds - since < paceHoldSec ||
        i.activeSeconds - _lastPaceCue < paceGapSec) {
      return;
    }
    _lastPaceCue = i.activeSeconds;
    final off = jsRound(((fast ? t.fast - now : now - t.slow)) * _perUnit);
    out.add(
      fast
          ? 'About ${_plural(off, 'second')} fast. Ease off a little.'
          : 'About ${_plural(off, 'second')} slow. Pick it up a little.',
    );
  }

  String paused() => 'Paused.';
  String resumed() => 'Resumed.';

  /// A step as it begins. [afterRest]: a rep straight after a recovery.
  String step(WorkoutStep s, {required bool afterRest}) {
    final what = s.distanceM != null
        ? (s.distanceM! >= 1000 && s.distanceM! % 100 == 0
            ? _distanceSaid(s.distanceM!, DistanceUnit.km)
            : '${s.distanceM!.round()} metres')
        : spokenDuration(s.seconds!);
    final pace = s.pace == null
        ? s.effort
        : 'at ${spokenPace(s.pace!.middle * _perUnit)}';
    return switch (s.kind) {
      StepKind.warmup => 'Warm-up. $what easy.',
      StepKind.cooldown => 'Cool-down. $what easy.',
      StepKind.recover => 'Recover. $what, ${s.effort}.',
      StepKind.work => '${afterRest ? 'Go! ' : ''}'
          '${s.repOf != null && s.repOf! > 1 ? 'Rep ${s.repIndex} of ${s.repOf}. ' : ''}'
          '$what $pace.',
    };
  }

  /// The last seconds of a timed step: "10 seconds", and a count into a rep.
  String? countdown(WorkoutStep s, int secondsLeft, {required bool nextIsRep}) {
    if (!settings.enabled || s.seconds == null) return null;
    if (nextIsRep && secondsLeft == 3) return 'Three. Two. One.';
    if (secondsLeft == 10 && s.seconds! > 20) return '10 seconds.';
    return null;
  }

  String workoutDone() => 'Workout done. Well run.';

  /// Spoken by the settings' Test button.
  static const String sample = '1 kilometre. 5 minutes 40. Average 5 40.';
}

/// The pace to hold now: the workout step's, else the planned run's, else a
/// pace goal's (± 5 s).
PaceRange? targetPace({
  WorkoutStep? step,
  PaceRange? planned,
  required String goalKind,
  required int? goalValue,
}) {
  if (step != null) return step.kind == StepKind.work ? step.pace : null;
  if (planned != null) return planned;
  if (goalKind == 'pace' && goalValue != null) {
    return PaceRange(goalValue - 5, goalValue + 5);
  }
  return null;
}

/// The track's own clock now: seconds since the run started.
double clockSecondsOf(DateTime startedAt, DateTime now) =>
    now.difference(startedAt).inMilliseconds / 1000;
