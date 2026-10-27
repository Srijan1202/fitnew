import 'run_math.dart';
import 'track.dart';

/// Beta 4.0 (ADR-038): runs as the server keeps them (packages/contracts
/// `running.ts`) and the few words the app needs around them.

enum RunKind {
  outdoor,
  treadmill;

  static RunKind parse(String s) => s == 'treadmill' ? treadmill : outdoor;
}

enum RunGoalKind {
  free,
  distance,
  time,
  pace;

  static RunGoalKind parse(String s) =>
      RunGoalKind.values.firstWhere((k) => k.name == s, orElse: () => free);
}

/// What the runner set out to do. `value`: metres, seconds, or seconds per km.
class RunGoal {
  const RunGoal(this.kind, [this.value]);

  const RunGoal.free()
      : kind = RunGoalKind.free,
        value = null;

  factory RunGoal.fromJson(Map<String, dynamic> j) => RunGoal(
        RunGoalKind.parse(j['kind'] as String),
        (j['value'] as num?)?.toInt(),
      );

  final RunGoalKind kind;
  final int? value;

  Map<String, dynamic> toJson() => {'kind': kind.name, 'value': value};

  @override
  bool operator ==(Object other) =>
      other is RunGoal && other.kind == kind && other.value == value;

  @override
  int get hashCode => Object.hash(kind, value);
}

double? _d(Object? v) => (v as num?)?.toDouble();

/// A history row.
class RunSummary {
  const RunSummary({
    required this.id,
    required this.kind,
    required this.name,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
    required this.distanceM,
    required this.avgPaceSecPerKm,
    required this.elevationGainM,
    required this.calories,
    required this.effort,
    required this.outline,
  });

  factory RunSummary.fromJson(Map<String, dynamic> j) => RunSummary(
        id: j['id'] as String,
        kind: RunKind.parse(j['kind'] as String),
        name: j['name'] as String,
        startedAt: DateTime.parse(j['startedAt'] as String),
        endedAt: DateTime.parse(j['endedAt'] as String),
        durationSeconds: (j['durationSeconds'] as num).toInt(),
        distanceM: (j['distanceM'] as num).toDouble(),
        avgPaceSecPerKm: _d(j['avgPaceSecPerKm']),
        elevationGainM: _d(j['elevationGainM']),
        calories: (j['calories'] as num?)?.toInt(),
        effort: (j['effort'] as num?)?.toInt(),
        outline: [
          for (final p in j['outline'] as List)
            (
              ((p as List)[0] as num).toDouble(),
              (p[1] as num).toDouble(),
            ),
        ],
      );

  final String id;
  final RunKind kind;
  final String name;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSeconds;
  final double distanceM;
  final double? avgPaceSecPerKm;
  final double? elevationGainM;
  final int? calories;
  final int? effort;
  final List<(double, double)> outline;
}

/// One run in full, from the server — or, before it has the run, the
/// phone's own preview of the same figures ([pending]).
class RunDetail {
  const RunDetail({
    required this.summary,
    required this.note,
    required this.goal,
    required this.track,
    required this.splitsKm,
    required this.splitsMi,
    required this.series,
    this.pending = false,
  });

  factory RunDetail.fromJson(Map<String, dynamic> j) {
    final track = j['track'] as Map<String, dynamic>?;
    return RunDetail(
      summary: RunSummary.fromJson(j),
      note: j['note'] as String?,
      goal: RunGoal.fromJson(j['goal'] as Map<String, dynamic>),
      track: track == null ? null : decodeTrack(EncodedTrack.fromJson(track)),
      splitsKm: [
        for (final s in j['splitsKm'] as List)
          RunSplit.fromJson(s as Map<String, dynamic>),
      ],
      splitsMi: [
        for (final s in j['splitsMi'] as List)
          RunSplit.fromJson(s as Map<String, dynamic>),
      ],
      series: [
        for (final s in j['series'] as List)
          SeriesPoint.fromJson(s as Map<String, dynamic>),
      ],
    );
  }

  final RunSummary summary;
  final String? note;
  final RunGoal goal;

  /// Null indoors.
  final Track? track;
  final List<RunSplit> splitsKm;
  final List<RunSplit> splitsMi;
  final List<SeriesPoint> series;

  /// The phone's preview: the server has not confirmed this run yet.
  final bool pending;

  String get id => summary.id;
}

class RunTotals {
  const RunTotals({
    required this.runs,
    required this.distanceM,
    required this.durationSeconds,
  });

  factory RunTotals.fromJson(Map<String, dynamic> j) => RunTotals(
        runs: (j['runs'] as num).toInt(),
        distanceM: (j['distanceM'] as num).toDouble(),
        durationSeconds: (j['durationSeconds'] as num).toInt(),
      );

  static const zero = RunTotals(runs: 0, distanceM: 0, durationSeconds: 0);

  final int runs;
  final double distanceM;
  final int durationSeconds;
}

class RunList {
  const RunList({
    required this.runs,
    required this.nextBefore,
    required this.week,
    required this.month,
  });

  factory RunList.fromJson(Map<String, dynamic> j) {
    final totals = j['totals'] as Map<String, dynamic>;
    return RunList(
      runs: [
        for (final r in j['runs'] as List)
          RunSummary.fromJson(r as Map<String, dynamic>),
      ],
      nextBefore: j['nextBefore'] as String?,
      week: RunTotals.fromJson(totals['week'] as Map<String, dynamic>),
      month: RunTotals.fromJson(totals['month'] as Map<String, dynamic>),
    );
  }

  final List<RunSummary> runs;
  final String? nextBefore;
  final RunTotals week;
  final RunTotals month;
}

/// The name a run gets until the runner changes it.
String defaultRunName(DateTime startedLocal, RunKind kind) {
  if (kind == RunKind.treadmill) return 'Treadmill run';
  final h = startedLocal.hour;
  final part = h >= 5 && h < 12
      ? 'Morning'
      : h >= 12 && h < 17
          ? 'Afternoon'
          : h >= 17 && h < 21
              ? 'Evening'
              : 'Night';
  return '$part run';
}
