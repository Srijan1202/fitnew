import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/fit_glass.dart';
import '../../domain/race.dart';
import '../../domain/run.dart';
import '../../domain/units.dart';
import '../../domain/workout.dart';
import '../../domain/replay.dart';
import 'efforts_widgets.dart';
import 'race_result.dart';
import 'route_painter.dart';
import 'run_map.dart';
import 'run_widgets.dart';

/// Beta 4.0: a run in full — the map, the figures, the splits and the chart.
/// The summary after a run and the run in the history both show it.
class RunReport extends StatelessWidget {
  const RunReport({
    required this.run,
    required this.unit,
    this.header,
    this.footer = const [],
    this.onReplay,
    super.key,
  });

  final RunDetail run;
  final DistanceUnit unit;
  final Widget? header;
  final List<Widget> footer;

  /// Beta 4.4: the run's page offers its replay (null: none, e.g. the
  /// summary before it is saved).
  final VoidCallback? onReplay;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = run.summary;
    final track = run.track;
    final segments = track == null
        ? const <List<(double, double)>>[]
        : [
            for (final seg in track.segments)
              [for (final p in seg) (p.lat, p.lon)],
          ];
    final splits = unit == DistanceUnit.km ? run.splitsKm : run.splitsMi;
    // Beta 4.4 (owner): the route coloured by pace against the run's average.
    final pace = track == null ? const <PaceStretch>[] : paceStretches(track);
    final day =
        MaterialLocalizations.of(context).formatFullDate(s.startedAt.toLocal());
    final time = TimeOfDay.fromDateTime(s.startedAt.toLocal()).format(context);
    return ListView(
      key: const ValueKey('run.report.list'),
      padding: const EdgeInsets.fromLTRB(
        FitSpacing.screen,
        FitSpacing.sm,
        FitSpacing.screen,
        FitSpacing.xl,
      ),
      children: [
        if (header != null) header!,
        Text(
          s.source == RunSource.watch
              ? '$day · $time · Galaxy Watch'
              : '$day · $time',
          key: const ValueKey('run.report.when'),
          style: t.bodyMedium,
        ),
        if (s.source == RunSource.watch &&
            track == null &&
            s.kind == RunKind.outdoor)
          Padding(
            padding: const EdgeInsets.only(top: FitSpacing.xs),
            child: Text(
              'No map: Samsung Health did not share this run\u2019s route.',
              key: const ValueKey('run.report.noRoute'),
              style: t.bodyMedium,
            ),
          ),
        if (run.pending)
          Padding(
            padding: const EdgeInsets.only(top: FitSpacing.xs),
            child: Row(
              key: const ValueKey('run.pending'),
              children: [
                Icon(
                  Icons.cloud_upload_outlined,
                  size: 16,
                  color: FitColors.amber,
                ),
                const SizedBox(width: FitSpacing.xs),
                Expanded(
                  child: Text(
                    'Not synced yet: these are the phone’s figures; the '
                    'saved run replaces them.',
                    style: t.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        if (segments.isNotEmpty && segments.any((x) => x.length >= 2)) ...[
          const SizedBox(height: FitSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(fitGlass ? 18 : 0),
            child: SizedBox(
              height: 260,
              child: RunMap(
                key: const ValueKey('run.report.map'),
                segments: segments,
                coloured: pace.isEmpty
                    ? null
                    : [
                        for (final p in pace)
                          (p.points, paceColour(p.relative)),
                      ],
              ),
            ),
          ),
          const SizedBox(height: FitSpacing.xs),
          Row(
            children: [
              if (pace.isNotEmpty) const Expanded(child: PaceLegend()),
              if (pace.isEmpty) const Spacer(),
              if (onReplay != null)
                TextButton.icon(
                  key: const ValueKey('run.replay'),
                  onPressed: onReplay,
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Replay'),
                ),
            ],
          ),
        ],
        const SizedBox(height: FitSpacing.md),
        FitBlock(
          padding: const EdgeInsets.all(FitSpacing.md),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: RunStat(
                      value: formatDistance(s.distanceM, unit),
                      label: unit.label,
                      big: true,
                      valueKey: const ValueKey('run.report.distance'),
                    ),
                  ),
                  Expanded(
                    child: RunStat(
                      value: formatDuration(s.durationSeconds),
                      label: 'Time',
                      big: true,
                      valueKey: const ValueKey('run.report.time'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: FitSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: RunStat(
                      value: formatPace(s.avgPaceSecPerKm, unit),
                      label: 'Avg pace ${unit.paceLabel}',
                      valueKey: const ValueKey('run.report.pace'),
                    ),
                  ),
                  Expanded(
                    child: RunStat(
                      value: s.elevationGainM == null
                          ? '–'
                          : '${s.elevationGainM!.round()} m',
                      label: 'Climb',
                    ),
                  ),
                  Expanded(
                    child: RunStat(
                      value: s.calories?.toString() ?? '–',
                      label: 'kcal',
                      valueKey: const ValueKey('run.report.kcal'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Beta 4.9: a race's result against its plan.
        if (RacePlan.of(run.goal) case final plan?)
          Padding(
            padding: const EdgeInsets.only(top: FitSpacing.sm),
            child: RaceResult(run: run, plan: plan),
          ),
        // Beta 4.5: the watch's heart rate.
        if (s.hrAvg != null || s.hrMax != null)
          Padding(
            padding: const EdgeInsets.only(top: FitSpacing.sm),
            child: FitBlock(
              key: const ValueKey('run.report.heart'),
              padding: const EdgeInsets.all(FitSpacing.md),
              child: Row(
                children: [
                  Icon(Icons.favorite, color: FitColors.oxide),
                  const SizedBox(width: FitSpacing.sm),
                  Expanded(
                    child: RunStat(
                      value: s.hrAvg?.toString() ?? '–',
                      label: 'Avg bpm',
                      valueKey: const ValueKey('run.report.hrAvg'),
                    ),
                  ),
                  Expanded(
                    child: RunStat(
                      value: s.hrMax?.toString() ?? '–',
                      label: 'Max bpm',
                      valueKey: const ValueKey('run.report.hrMax'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Beta 4.9: the watch's cadence.
        if (s.cadenceAvg != null)
          Padding(
            padding: const EdgeInsets.only(top: FitSpacing.sm),
            child: FitBlock(
              key: const ValueKey('run.report.cadence'),
              padding: const EdgeInsets.all(FitSpacing.md),
              child: Row(
                children: [
                  Icon(Icons.directions_run, color: FitPalette.current.glow),
                  const SizedBox(width: FitSpacing.sm),
                  Expanded(
                    child: RunStat(
                      value: '${s.cadenceAvg}',
                      label: 'Avg spm',
                      valueKey: const ValueKey('run.report.cadenceAvg'),
                    ),
                  ),
                  Expanded(
                    child: RunStat(
                      value: s.cadenceMax?.toString() ?? '–',
                      label: 'Max spm',
                      valueKey: const ValueKey('run.report.cadenceMax'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (s.calories == null && s.distanceM > 0)
          Padding(
            padding: const EdgeInsets.only(top: FitSpacing.xs),
            child: Text(
              'Calories need your weight (Profile → Personal details).',
              style: t.bodyMedium,
            ),
          ),
        if (splits.isNotEmpty)
          RunSection(
            label: 'Splits',
            child: SplitsTable(
              key: const ValueKey('run.report.splits'),
              splits: splits,
              unit: unit,
            ),
          ),
        // Beta 4.2: the fastest stretch of each distance, with medals.
        if (run.efforts.isNotEmpty)
          RunSection(
            label: 'Best efforts',
            child: BestEffortsList(efforts: run.efforts, unit: unit),
          ),
        if (run.workout != null)
          RunSection(
            label: run.workout!.name,
            child: _Laps(run: run, unit: unit),
          ),
        if (run.series.length >= 2)
          RunSection(
            label: 'Pace and elevation',
            child: PaceChart(series: run.series, unit: unit),
          ),
        if ((run.note ?? '').isNotEmpty || s.effort != null)
          RunSection(
            label: 'Notes',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (s.effort != null)
                  Text(
                    'Effort ${s.effort} of 10 · ${effortWord(s.effort!)}',
                    style: t.titleMedium,
                  ),
                if ((run.note ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: FitSpacing.xs),
                    child: Text(run.note!, style: t.bodyLarge),
                  ),
              ],
            ),
          ),
        ...footer,
      ],
    );
  }
}

/// 1–10 in words (how hard it felt).
String effortWord(int effort) => switch (effort) {
      <= 2 => 'very easy',
      <= 4 => 'easy',
      <= 6 => 'moderate',
      <= 8 => 'hard',
      _ => 'all out',
    };

/// Beta 4.1: a session rep by rep — the server's laps, measured on the track.
class _Laps extends StatelessWidget {
  const _Laps({required this.run, required this.unit});

  final RunDetail run;
  final DistanceUnit unit;

  static String _label(WorkoutStep s) => switch (s.kind) {
        StepKind.warmup => 'Warm-up',
        StepKind.cooldown => 'Cool-down',
        StepKind.recover => 'Recover',
        StepKind.work =>
          s.repOf != null && s.repOf! > 1 ? 'Rep ${s.repIndex}' : 'Work',
      };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final steps = run.workout!.steps;
    if (run.laps.isEmpty) {
      return Text(
        run.pending
            ? 'Each rep’s distance, time and pace appear once the run is saved.'
            : 'No laps were recorded.',
        style: t.bodyMedium,
      );
    }
    return Column(
      key: const ValueKey('run.report.laps'),
      children: [
        for (final l in run.laps)
          if (l.step < steps.length)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _label(steps[l.step]),
                      style: t.bodyLarge?.copyWith(
                        fontWeight: steps[l.step].kind == StepKind.work
                            ? FontWeight.w600
                            : null,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      '${l.distanceM.round()} m',
                      textAlign: TextAlign.end,
                      style: t.bodyMedium,
                    ),
                  ),
                  SizedBox(
                    width: 56,
                    child: Text(
                      formatDuration(l.seconds.round()),
                      textAlign: TextAlign.end,
                      style: t.bodyMedium,
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      formatPace(l.pace, unit),
                      textAlign: TextAlign.end,
                      style: t.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
        ..._best(context, steps),
      ],
    );
  }

  /// Beta 4.1 (C3): the fastest rep, and for sprints how far to trust it.
  List<Widget> _best(BuildContext context, List<WorkoutStep> steps) {
    final t = Theme.of(context).textTheme;
    final reps = [
      for (final l in run.laps)
        if (l.step < steps.length &&
            steps[l.step].kind == StepKind.work &&
            steps[l.step].distanceM != null)
          (l, steps[l.step]),
    ];
    if (reps.length < 2) return const [];
    final (best, step) =
        reps.reduce((a, b) => b.$1.seconds < a.$1.seconds ? b : a);
    final sprint = reps.every((r) => r.$2.distanceM! <= 400);
    return [
      const SizedBox(height: FitSpacing.xs),
      Text(
        'Best: ${_label(step)} · ${best.seconds < 100 ? '${best.seconds.toStringAsFixed(1)} s' : formatDuration(best.seconds.round())}',
        key: const ValueKey('run.report.laps.best'),
        style: t.titleMedium,
      ),
      if (sprint)
        Text(
          'Phone GPS is good to a few metres, so a 100 m time can be about '
          'half a second out; 400 m is far closer.',
          key: const ValueKey('run.report.laps.gps'),
          style: t.bodyMedium,
        ),
    ];
  }
}
