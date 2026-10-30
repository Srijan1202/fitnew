import 'run.dart';
import 'run_math.dart';
import 'units.dart';

/// Beta 4.9 (owner): race-day pacing. Pure: the setup shows the plan, the
/// live screen and the coach read where the runner is against it, the result
/// compares each km with it.
///
/// Even: one pace the whole way. Negative: the first half 2 % slower than
/// the even pace and the second 2 % faster — the same finishing time.
class RacePlan {
  const RacePlan({
    required this.distanceM,
    required this.targetSeconds,
    required this.split,
  });

  /// The race goal's plan; null for any other goal.
  static RacePlan? of(RunGoal goal) {
    if (goal.kind != RunGoalKind.race) return null;
    final d = goal.value;
    final t = goal.targetSeconds;
    if (d == null || d <= 0 || t == null || t <= 0) return null;
    return RacePlan(
      distanceM: d.toDouble(),
      targetSeconds: t,
      split: goal.split ?? RaceSplit.even,
    );
  }

  static const double negativeShare = 0.02;

  final double distanceM;
  final int targetSeconds;
  final RaceSplit split;

  /// The even pace, seconds per km.
  double get evenPace => targetSeconds / (distanceM / 1000);

  /// The pace to hold at [metres], seconds per km.
  double paceAt(double metres) => switch (split) {
        RaceSplit.even => evenPace,
        RaceSplit.negative => metres < distanceM / 2
            ? evenPace * (1 + negativeShare)
            : evenPace * (1 - negativeShare),
      };

  /// Where the plan has the runner at [metres], in seconds.
  double plannedAt(double metres) {
    final m = metres.clamp(0, distanceM).toDouble();
    if (split == RaceSplit.even) return evenPace * m / 1000;
    final half = distanceM / 2;
    final first = m < half ? m : half;
    final second = m < half ? 0.0 : m - half;
    return (evenPace * (1 + negativeShare) * first +
            evenPace * (1 - negativeShare) * second) /
        1000;
  }

  /// Seconds behind the plan (positive) or ahead of it (negative).
  int deltaAt(double metres, int elapsedSeconds) =>
      (elapsedSeconds - plannedAt(metres)).round();

  /// The finish at the average pace so far; null before 200 m.
  int? projectedFinish(double metres, int elapsedSeconds) =>
      metres < 200 ? null : (elapsedSeconds * distanceM / metres).round();

  /// The race's time from the run's km splits: when the runner crossed the
  /// race distance (within its split, at that split's pace); null when the
  /// run stopped short of it (20 m grace for the GPS).
  int? finishFrom(List<RunSplit> splitsKm) {
    var metres = 0.0;
    var seconds = 0.0;
    for (final s in splitsKm) {
      if (metres + s.distanceM >= distanceM) {
        final part =
            s.distanceM <= 0 ? 0.0 : (distanceM - metres) / s.distanceM;
        return (seconds + s.seconds * part).round();
      }
      metres += s.distanceM;
      seconds += s.seconds;
    }
    return metres >= distanceM - 20 ? seconds.round() : null;
  }

  /// Each km's planned seconds (the last one partial), in order.
  List<double> kmSplits() {
    final out = <double>[];
    for (var km = 0.0; km < distanceM; km += 1000) {
      final end = km + 1000 < distanceM ? km + 1000 : distanceM;
      out.add(plannedAt(end) - plannedAt(km));
    }
    return out;
  }
}

/// A gap in seconds, said short: "32 s", "1:05".
String raceGap(int seconds) {
  final s = seconds.abs();
  return s < 60 ? '$s s' : formatDuration(s);
}

/// After the race: the finish against the target — "32 s under target".
String raceVerdict(int finishSeconds, int targetSeconds) {
  final d = targetSeconds - finishSeconds;
  if (d.abs() <= 1) return 'On target';
  return d > 0 ? '${raceGap(d)} under target' : '${raceGap(d)} over target';
}

/// The race's name: "5K", "10K", "Half marathon", "Marathon", or its km.
String raceName(double metres) => switch (metres.round()) {
      5000 => '5K',
      10000 => '10K',
      21097 => 'Half marathon',
      42195 => 'Marathon',
      final m => '${(m / 1000).toStringAsFixed(m % 1000 == 0 ? 0 : 1)} km race',
    };
