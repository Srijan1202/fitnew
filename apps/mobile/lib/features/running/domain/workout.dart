/// Beta 4.1 (ADR-039): structured runs and running plans, as the server
/// sends them (packages/contracts `running.ts`). The server builds them; the
/// phone only walks through them.
library;

class PaceRange {
  const PaceRange(this.fast, this.slow);

  factory PaceRange.fromJson(Map<String, dynamic> j) =>
      PaceRange((j['fast'] as num).toInt(), (j['slow'] as num).toInt());

  /// Seconds per km; [fast] is the lower number.
  final int fast;
  final int slow;

  int get middle => ((fast + slow) / 2).round();

  Map<String, dynamic> toJson() => {'fast': fast, 'slow': slow};
}

enum StepKind {
  warmup,
  work,
  recover,
  cooldown;

  static StepKind parse(String s) =>
      StepKind.values.firstWhere((k) => k.name == s, orElse: () => work);
}

/// One step: it ends after its distance or its time (exactly one).
class WorkoutStep {
  const WorkoutStep({
    required this.kind,
    this.distanceM,
    this.seconds,
    this.pace,
    this.effort = '',
    this.repIndex,
    this.repOf,
  });

  factory WorkoutStep.fromJson(Map<String, dynamic> j) {
    final rep = j['rep'] as Map<String, dynamic>?;
    return WorkoutStep(
      kind: StepKind.parse(j['kind'] as String),
      distanceM: (j['distanceM'] as num?)?.toDouble(),
      seconds: (j['seconds'] as num?)?.toInt(),
      pace: j['pace'] == null
          ? null
          : PaceRange.fromJson(j['pace'] as Map<String, dynamic>),
      effort: j['effort'] as String? ?? '',
      repIndex: (rep?['index'] as num?)?.toInt(),
      repOf: (rep?['of'] as num?)?.toInt(),
    );
  }

  final StepKind kind;
  final double? distanceM;
  final int? seconds;
  final PaceRange? pace;
  final String effort;
  final int? repIndex;
  final int? repOf;

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'distanceM': distanceM,
        'seconds': seconds,
        'pace': pace?.toJson(),
        'effort': effort,
        'rep': repIndex == null ? null : {'index': repIndex, 'of': repOf},
      };
}

class RunWorkout {
  const RunWorkout({required this.name, required this.steps});

  factory RunWorkout.fromJson(Map<String, dynamic> j) => RunWorkout(
        name: j['name'] as String,
        steps: [
          for (final s in j['steps'] as List)
            WorkoutStep.fromJson(s as Map<String, dynamic>),
        ],
      );

  final String name;
  final List<WorkoutStep> steps;

  Map<String, dynamic> toJson() => {
        'name': name,
        'steps': [for (final s in steps) s.toJson()],
      };
}

/// Where a step began and ended on the run's clock (seconds since start).
class LapMark {
  const LapMark(this.step, this.startT, this.endT);

  factory LapMark.fromJson(Map<String, dynamic> j) => LapMark(
        (j['step'] as num).toInt(),
        (j['startT'] as num).toDouble(),
        (j['endT'] as num).toDouble(),
      );

  final int step;
  final double startT;
  final double endT;

  Map<String, dynamic> toJson() =>
      {'step': step, 'startT': startT, 'endT': endT};
}

/// A lap as the server measured it on the track.
class Lap {
  const Lap({
    required this.step,
    required this.distanceM,
    required this.seconds,
    required this.pace,
  });

  factory Lap.fromJson(Map<String, dynamic> j) => Lap(
        step: (j['step'] as num).toInt(),
        distanceM: (j['distanceM'] as num).toDouble(),
        seconds: (j['seconds'] as num).toDouble(),
        pace: (j['pace'] as num?)?.toDouble(),
      );

  final int step;
  final double distanceM;
  final double seconds;
  final double? pace;
}

class PaceZones {
  const PaceZones({
    required this.vdot,
    required this.easy,
    required this.marathon,
    required this.threshold,
    required this.interval,
    required this.repetition,
  });

  factory PaceZones.fromJson(Map<String, dynamic> j) => PaceZones(
        vdot: (j['vdot'] as num).toDouble(),
        easy: PaceRange.fromJson(j['easy'] as Map<String, dynamic>),
        marathon: (j['marathon'] as num).toInt(),
        threshold: (j['threshold'] as num).toInt(),
        interval: (j['interval'] as num).toInt(),
        repetition: (j['repetition'] as num).toInt(),
      );

  final double vdot;
  final PaceRange easy;
  final int marathon;
  final int threshold;
  final int interval;
  final int repetition;
}

class WorkoutPreset {
  const WorkoutPreset({
    required this.id,
    required this.name,
    required this.about,
    required this.steps,
  });

  factory WorkoutPreset.fromJson(Map<String, dynamic> j) => WorkoutPreset(
        id: j['id'] as String,
        name: j['name'] as String,
        about: j['about'] as String,
        steps: [
          for (final s in j['steps'] as List)
            WorkoutStep.fromJson(s as Map<String, dynamic>),
        ],
      );

  final String id;
  final String name;
  final String about;
  final List<WorkoutStep> steps;

  RunWorkout get workout => RunWorkout(name: name, steps: steps);
}

class WorkoutPresets {
  const WorkoutPresets({required this.zones, required this.presets});

  factory WorkoutPresets.fromJson(Map<String, dynamic> j) => WorkoutPresets(
        zones: j['zones'] == null
            ? null
            : PaceZones.fromJson(j['zones'] as Map<String, dynamic>),
        presets: [
          for (final p in j['presets'] as List)
            WorkoutPreset.fromJson(p as Map<String, dynamic>),
        ],
      );

  final PaceZones? zones;
  final List<WorkoutPreset> presets;
}

enum PlannedRunStatus {
  planned,
  done,
  skipped;

  static PlannedRunStatus parse(String s) => PlannedRunStatus.values
      .firstWhere((k) => k.name == s, orElse: () => planned);
}

class PlannedRun {
  const PlannedRun({
    required this.id,
    required this.date,
    required this.week,
    required this.kind,
    required this.title,
    required this.distanceM,
    required this.seconds,
    required this.pace,
    required this.steps,
    required this.note,
    required this.status,
    required this.runId,
    required this.movedFrom,
  });

  factory PlannedRun.fromJson(Map<String, dynamic> j) => PlannedRun(
        id: j['id'] as String,
        date: j['date'] as String,
        week: (j['week'] as num).toInt(),
        kind: j['kind'] as String,
        title: j['title'] as String,
        distanceM: (j['distanceM'] as num?)?.toDouble(),
        seconds: (j['seconds'] as num?)?.toInt(),
        pace: j['pace'] == null
            ? null
            : PaceRange.fromJson(j['pace'] as Map<String, dynamic>),
        steps: j['steps'] == null
            ? null
            : [
                for (final s in j['steps'] as List)
                  WorkoutStep.fromJson(s as Map<String, dynamic>),
              ],
        note: j['note'] as String,
        status: PlannedRunStatus.parse(j['status'] as String),
        runId: j['runId'] as String?,
        movedFrom: j['movedFrom'] as String?,
      );

  final String id;

  /// yyyy-mm-dd, the user's local date.
  final String date;
  final int week;

  /// `easy` | `long` | `tempo` | `intervals` | `run-walk` | `race`.
  final String kind;
  final String title;
  final double? distanceM;
  final int? seconds;
  final PaceRange? pace;
  final List<WorkoutStep>? steps;
  final String note;
  final PlannedRunStatus status;
  final String? runId;
  final String? movedFrom;

  bool get structured => steps != null && steps!.isNotEmpty;
}

class RunningPlan {
  const RunningPlan({
    required this.id,
    required this.goal,
    required this.level,
    required this.weeks,
    required this.weekdays,
    required this.longRunWeekday,
    required this.startDate,
    required this.zones,
    required this.predictedSeconds,
    required this.gymOverlap,
    required this.runs,
  });

  factory RunningPlan.fromJson(Map<String, dynamic> j) => RunningPlan(
        id: j['id'] as String,
        goal: j['goal'] as String,
        level: j['level'] as String,
        weeks: (j['weeks'] as num).toInt(),
        weekdays: [for (final d in j['weekdays'] as List) (d as num).toInt()],
        longRunWeekday: (j['longRunWeekday'] as num).toInt(),
        startDate: j['startDate'] as String,
        zones: j['zones'] == null
            ? null
            : PaceZones.fromJson(j['zones'] as Map<String, dynamic>),
        predictedSeconds: (j['predictedSeconds'] as num?)?.toInt(),
        gymOverlap: [
          for (final d in j['gymOverlap'] as List) (d as num).toInt(),
        ],
        runs: [
          for (final r in j['runs'] as List)
            PlannedRun.fromJson(r as Map<String, dynamic>),
        ],
      );

  /// `5k` | `10k` | `half` | `marathon`.
  final String goal;
  final String id;
  final String level;
  final int weeks;
  final List<int> weekdays;
  final int longRunWeekday;
  final String startDate;
  final PaceZones? zones;
  final int? predictedSeconds;
  final List<int> gymOverlap;
  final List<PlannedRun> runs;

  String get goalLabel => switch (goal) {
        '5k' => '5K',
        '10k' => '10K',
        'half' => 'Half marathon',
        _ => 'Marathon',
      };

  /// The plan's runs in the ISO week holding [date] (yyyy-mm-dd).
  List<PlannedRun> weekOf(String date) {
    final d = DateTime.parse(date);
    final monday = d.subtract(Duration(days: d.weekday - 1));
    String iso(DateTime x) => x.toIso8601String().substring(0, 10);
    final from = iso(monday);
    final to = iso(monday.add(const Duration(days: 6)));
    return [
      for (final r in runs)
        if (r.date.compareTo(from) >= 0 && r.date.compareTo(to) <= 0) r,
    ];
  }
}
