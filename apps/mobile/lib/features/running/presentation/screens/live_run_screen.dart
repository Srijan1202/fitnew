import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/fit_glass.dart';
import '../../domain/race.dart';
import '../../domain/run.dart';
import '../../domain/units.dart';
import '../../domain/workout.dart';
import '../controllers/run_recorder.dart';
import '../controllers/running_providers.dart';
import '../widgets/run_map.dart';
import '../widgets/run_widgets.dart';

/// Beta 4.0 (ADR-038): the run as it happens. Big numbers first (time,
/// distance, pace), a swipe for the rest, the map below. Leaving the screen
/// does not stop the run: it carries on in the background (the
/// notification brings you back) until you finish it here.
class LiveRunScreen extends ConsumerStatefulWidget {
  const LiveRunScreen({super.key});

  @override
  ConsumerState<LiveRunScreen> createState() => _LiveRunScreenState();
}

class _LiveRunScreenState extends ConsumerState<LiveRunScreen> {
  bool _locked = false;
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _onChange(LiveRun? before, LiveRun? now) {
    if (now == null || !mounted) return;
    final unit = ref.read(runSettingsProvider).unit;
    final messenger = ScaffoldMessenger.of(context);
    final splits = now.track.splitSeconds;
    if (before != null && now.splitCount > before.splitCount) {
      unawaited(HapticFeedback.mediumImpact());
      messenger.showSnackBar(
        SnackBar(
          key: ValueKey('run.split.toast.${splits.length}'),
          content: Text(
            '${unit.label.toUpperCase()} ${splits.length} · '
            '${formatUnitPace(splits.last)} ${unit.paceLabel}',
          ),
          duration: const Duration(seconds: 4),
          // Above Pause and Finish: a message never covers the controls.
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 104),
        ),
      );
    }
    if (before != null && !before.goalReached && now.goalReached) {
      unawaited(HapticFeedback.heavyImpact());
      messenger.showSnackBar(
        const SnackBar(
          key: ValueKey('run.goal.reached'),
          content: Text('Goal reached. Keep going or finish the run.'),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(16, 0, 16, 104),
        ),
      );
    }
    // Beta 4.1 (C2): every step of a session is felt as well as heard.
    if (before?.session != null &&
        now.session != null &&
        now.session!.index != before!.session!.index) {
      unawaited(HapticFeedback.heavyImpact());
    }
    if (before != null &&
        before.status != now.status &&
        now.status == RunStatus.autoPaused) {
      unawaited(HapticFeedback.selectionClick());
    }
  }

  Future<void> _finish() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('run.finish.confirm'),
        title: const Text('Finish this run?'),
        content:
            const Text('You can save it or discard it on the next screen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            key: const ValueKey('run.finish.yes'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Finish'),
          ),
        ],
      ),
    );
    if (!(yes ?? false) || !mounted) return;
    await ref.read(runRecorderProvider.notifier).finish();
    if (mounted) context.pushReplacement(Routes.runFinish);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LiveRun?>(runRecorderProvider, _onChange);
    final run = ref.watch(runRecorderProvider);
    final unit = ref.watch(runSettingsProvider).unit;
    final t = Theme.of(context).textTheme;
    if (run == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text('No run in progress.', style: t.bodyLarge),
        ),
      );
    }
    if (run.status == RunStatus.finished) {
      // Finished elsewhere (or restored finished): straight to the summary.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.pushReplacement(Routes.runFinish);
      });
    }
    final recorder = ref.read(runRecorderProvider.notifier);
    final outdoor = run.kind == RunKind.outdoor;
    final segments = [
      for (final s in run.track.segments) [for (final p in s) (p.lat, p.lon)],
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          switch (run.status) {
            RunStatus.recording => 'Running',
            RunStatus.autoPaused => 'Auto-paused',
            RunStatus.paused => 'Paused',
            RunStatus.finished => 'Finished',
          },
          key: const ValueKey('run.status'),
        ),
        actions: [
          if (outdoor) _GpsChip(signal: run.gps),
          const SizedBox(width: FitSpacing.sm),
        ],
      ),
      body: FitBackdrop(
        child: Stack(
          children: [
            Column(
              children: [
                if (run.restored)
                  const _Banner(
                    key: ValueKey('run.restored'),
                    text: 'FITOS was closed during your run. It is paused at '
                        'your last point: resume or finish.',
                  ),
                if (run.plannedTitle != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      FitSpacing.screen,
                      FitSpacing.sm,
                      FitSpacing.screen,
                      0,
                    ),
                    child: Text(
                      'Plan: ${run.plannedTitle}',
                      key: const ValueKey('run.planned'),
                      style: t.bodyMedium?.copyWith(color: FitColors.ink),
                    ),
                  ),
                if (run.session != null)
                  _SessionCard(
                    session: run.session!,
                    unit: unit,
                    onNext: recorder.nextStep,
                  ),
                if (run.goal.kind != RunGoalKind.free)
                  _GoalLine(run: run, unit: unit),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    FitSpacing.screen,
                    FitSpacing.sm,
                    FitSpacing.screen,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Semantics(
                          label: 'Time ${formatDuration(run.activeSeconds)}',
                          excludeSemantics: true,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              formatDuration(run.activeSeconds),
                              key: const ValueKey('run.time'),
                              style: t.displayLarge?.copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: FitSpacing.md),
                      SizedBox(
                        height: 124,
                        child: PageView(
                          controller: _pages,
                          onPageChanged: (i) => setState(() => _page = i),
                          children: [
                            _Pair(
                              left: RunStat(
                                value: outdoor
                                    ? formatDistance(run.track.distanceM, unit)
                                    : '–',
                                label: unit.label,
                                big: true,
                                valueKey: const ValueKey('run.distance'),
                              ),
                              right: RunStat(
                                value: formatPace(run.avgPaceSecPerKm, unit),
                                label: 'Avg pace ${unit.paceLabel}',
                                big: true,
                                valueKey: const ValueKey('run.avgPace'),
                              ),
                            ),
                            _Pair(
                              left: RunStat(
                                value: formatPace(
                                  run.track.currentPaceSecPerKm,
                                  unit,
                                ),
                                label: 'Pace now ${unit.paceLabel}',
                                big: true,
                                valueKey: const ValueKey('run.pace'),
                              ),
                              right: RunStat(
                                value: formatSpeed(
                                  run.track.currentSpeedMs,
                                  unit,
                                ),
                                label: unit == DistanceUnit.km ? 'km/h' : 'mph',
                                big: true,
                                valueKey: const ValueKey('run.speed'),
                              ),
                            ),
                            _Pair(
                              left: RunStat(
                                value: run.track.splitSeconds.isEmpty
                                    ? '–:––'
                                    : formatUnitPace(
                                        run.track.splitSeconds.last,
                                      ),
                                label: 'Last ${unit.label}',
                                big: true,
                                valueKey: const ValueKey('run.lastSplit'),
                              ),
                              right: RunStat(
                                value: run.track.elevationGainM == null
                                    ? '–'
                                    : '${run.track.elevationGainM!.round()}',
                                label: 'Climb m',
                                big: true,
                                valueKey: const ValueKey('run.climb'),
                              ),
                            ),
                            _Pair(
                              left: RunStat(
                                value: run.track.calories?.toString() ?? '–',
                                label: 'kcal',
                                big: true,
                                valueKey: const ValueKey('run.calories'),
                              ),
                              right: RunStat(
                                value: '${run.track.splitSeconds.length}',
                                label: '${unit.label} done',
                                big: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _Dots(count: 4, index: _page),
                    ],
                  ),
                ),
                const SizedBox(height: FitSpacing.sm),
                Expanded(
                  child: outdoor
                      ? ClipRRect(
                          borderRadius:
                              BorderRadius.circular(fitGlass ? 18 : 0),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: FitSpacing.sm,
                            ),
                            child: ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(fitGlass ? 18 : 0),
                              child: RunMap(
                                key: const ValueKey('run.map'),
                                segments: segments,
                                follow: true,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Padding(
                            padding: const EdgeInsets.all(FitSpacing.lg),
                            child: Text(
                              'Treadmill run: type the distance from the '
                              'treadmill when you finish.',
                              textAlign: TextAlign.center,
                              style: t.bodyLarge,
                            ),
                          ),
                        ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(FitSpacing.md),
                    child: Row(
                      children: [
                        IconButton.outlined(
                          key: const ValueKey('run.lock'),
                          tooltip: 'Lock the screen',
                          iconSize: 28,
                          onPressed: () => setState(() => _locked = true),
                          icon: const Icon(Icons.lock_outline),
                        ),
                        const SizedBox(width: FitSpacing.md),
                        Expanded(
                          child: run.isRunning
                              ? FilledButton.icon(
                                  key: const ValueKey('run.pause'),
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(56),
                                  ),
                                  onPressed: recorder.pause,
                                  icon: const Icon(Icons.pause),
                                  label: const Text('Pause'),
                                )
                              : Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.icon(
                                        key: const ValueKey('run.resume'),
                                        style: FilledButton.styleFrom(
                                          minimumSize:
                                              const Size.fromHeight(56),
                                        ),
                                        onPressed: recorder.resume,
                                        icon: const Icon(Icons.play_arrow),
                                        label: const Text('Resume'),
                                      ),
                                    ),
                                    const SizedBox(width: FitSpacing.sm),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        key: const ValueKey('run.finish'),
                                        style: OutlinedButton.styleFrom(
                                          minimumSize:
                                              const Size.fromHeight(56),
                                        ),
                                        onPressed: _finish,
                                        icon: const Icon(Icons.stop),
                                        label: const Text('Finish'),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_locked)
              Positioned.fill(
                child: _LockOverlay(
                  onUnlock: () => setState(() => _locked = false),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Pair extends StatelessWidget {
  const _Pair({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const SizedBox(width: FitSpacing.md),
          Expanded(child: right),
        ],
      );
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == index ? FitColors.ink : FitColors.ink35,
              ),
            ),
        ],
      );
}

class _GpsChip extends StatelessWidget {
  const _GpsChip({required this.signal});

  final GpsSignal signal;

  @override
  Widget build(BuildContext context) {
    final (label, colour) = switch (signal) {
      GpsSignal.good => ('GPS good', FitColors.pine),
      GpsSignal.weak => ('GPS weak', FitColors.amber),
      GpsSignal.searching => ('Finding GPS', FitColors.amber),
      GpsSignal.lost => ('GPS lost', FitColors.oxide),
    };
    return Chip(
      key: const ValueKey('run.gps'),
      avatar: Icon(Icons.gps_fixed, size: 16, color: colour),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _GoalLine extends StatelessWidget {
  const _GoalLine({required this.run, required this.unit});

  final LiveRun run;
  final DistanceUnit unit;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final g = run.goal;
    final value = g.value ?? 0;
    String text;
    double? progress = run.progress;
    switch (g.kind) {
      case RunGoalKind.distance:
        text = 'Goal ${formatDistance(value.toDouble(), unit)} ${unit.label}';
        if (run.goalReached) text = '$text · reached';
      case RunGoalKind.time:
        text = 'Goal ${formatDuration(value)}';
        if (run.goalReached) text = '$text · reached';
      case RunGoalKind.pace:
        progress = null;
        final avg = run.avgPaceSecPerKm;
        text = 'Target ${formatPace(value.toDouble(), unit)} ${unit.paceLabel}';
        if (avg != null) {
          final diff = ((avg - value) * unit.metres / 1000).round();
          text = diff.abs() <= 5
              ? '$text · on target'
              : diff > 0
                  ? '$text · ${diff}s slower'
                  : '$text · ${-diff}s faster';
        }
      case RunGoalKind.free:
        return const SizedBox.shrink();
      case RunGoalKind.race:
        final plan = RacePlan.of(g);
        if (plan == null) return const SizedBox.shrink();
        return _RacePanel(run: run, plan: plan, unit: unit);
    }
    return Padding(
      key: const ValueKey('run.goal'),
      padding: const EdgeInsets.fromLTRB(
        FitSpacing.screen,
        FitSpacing.sm,
        FitSpacing.screen,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(text, style: t.bodyMedium?.copyWith(color: FitColors.ink)),
          if (progress != null) ...[
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: progress,
              color: FitPalette.current.glow,
              backgroundColor: FitColors.ink.withValues(alpha: 0.1),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: FitColors.amber.withValues(alpha: 0.15),
        padding: const EdgeInsets.symmetric(
          horizontal: FitSpacing.screen,
          vertical: FitSpacing.sm,
        ),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      );
}

/// Pocket protection: every tap is caught; holding the button unlocks.
class _LockOverlay extends StatefulWidget {
  const _LockOverlay({required this.onUnlock});

  final VoidCallback onUnlock;

  @override
  State<_LockOverlay> createState() => _LockOverlayState();
}

class _LockOverlayState extends State<_LockOverlay> {
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return GestureDetector(
      key: const ValueKey('run.locked'),
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: ColoredBox(
        color: FitColors.paper.withValues(alpha: 0.55),
        child: SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(FitSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Locked', style: t.titleMedium),
                  const SizedBox(height: FitSpacing.sm),
                  GestureDetector(
                    key: const ValueKey('run.unlock'),
                    onLongPress: widget.onUnlock,
                    child: Semantics(
                      button: true,
                      label: 'Hold to unlock',
                      onTap: widget.onUnlock,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: FitSpacing.lg,
                          vertical: FitSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: FitColors.ink,
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_open, color: FitColors.paper),
                            const SizedBox(width: FitSpacing.sm),
                            Text(
                              'Hold to unlock',
                              style: t.titleMedium
                                  ?.copyWith(color: FitColors.paper),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Beta 4.1: the step in progress, what is left of it, and the next one.
class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.unit,
    required this.onNext,
  });

  final LiveSession session;
  final DistanceUnit unit;
  final VoidCallback onNext;

  static String _what(WorkoutStep s, DistanceUnit unit) {
    final end = s.distanceM != null
        ? (s.distanceM! >= 1000
            ? '${formatDistance(s.distanceM!, unit)} ${unit.label}'
            : '${s.distanceM!.round()} m')
        : formatDuration(s.seconds!);
    final how = s.pace != null
        ? ' at ${formatPace(s.pace!.fast.toDouble(), unit)}–${formatPace(s.pace!.slow.toDouble(), unit)}'
        : (s.effort.isEmpty ? '' : ', ${s.effort}');
    final label = switch (s.kind) {
      StepKind.warmup => 'Warm-up',
      StepKind.cooldown => 'Cool-down',
      StepKind.recover => 'Recover',
      StepKind.work => s.repOf != null && s.repOf! > 1
          ? 'Rep ${s.repIndex} of ${s.repOf}'
          : 'Work',
    };
    return '$label · $end$how';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final step = session.step;
    final left = session.metresLeft != null
        ? '${session.metresLeft!.round()} m left'
        : session.secondsLeft != null
            ? '${formatDuration(session.secondsLeft!)} left'
            : '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FitSpacing.screen,
        FitSpacing.sm,
        FitSpacing.screen,
        0,
      ),
      child: FitBlock(
        key: const ValueKey('run.session'),
        padding: const EdgeInsets.all(FitSpacing.md),
        child: step == null
            ? Text(
                '${session.name}: done. Finish when you are ready.',
                style: t.titleMedium,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${session.name.toUpperCase()} · STEP ${session.index + 1} OF ${session.count}',
                    style: t.labelSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _what(step, unit),
                    key: const ValueKey('run.session.step'),
                    style: t.titleMedium,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          [
                            left,
                            if (session.next != null)
                              'next: ${_what(session.next!, unit)}',
                          ].where((x) => x.isNotEmpty).join(' · '),
                          key: const ValueKey('run.session.left'),
                          style: t.bodyMedium,
                        ),
                      ),
                      TextButton(
                        key: const ValueKey('run.session.next'),
                        onPressed: onNext,
                        child: const Text('Next step'),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

/// Beta 4.9 (owner): race mode — this km's pace to hold, big; how far ahead
/// or behind the plan; the finish the pace so far gives.
class _RacePanel extends StatelessWidget {
  const _RacePanel({required this.run, required this.plan, required this.unit});

  final LiveRun run;
  final RacePlan plan;
  final DistanceUnit unit;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final d = run.distanceM;
    final delta = plan.deltaAt(d, run.activeSeconds);
    final projected = plan.projectedFinish(d, run.activeSeconds);
    final (deltaText, deltaColour) = d < 50
        ? ('Go', FitColors.ink)
        : delta.abs() <= 2
            ? ('On plan', FitColors.pine)
            : delta > 0
                ? ('${raceGap(delta)} behind', FitColors.oxide)
                : ('${raceGap(delta)} ahead', FitColors.pine);
    return Padding(
      key: const ValueKey('run.goal'),
      padding: const EdgeInsets.fromLTRB(
        FitSpacing.screen,
        FitSpacing.sm,
        FitSpacing.screen,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('HOLD', style: t.labelSmall),
                    Text(
                      '${formatPace(plan.paceAt(d), unit)} ${unit.paceLabel}',
                      key: const ValueKey('run.race.pace'),
                      style: t.headlineSmall?.copyWith(color: FitColors.ink),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    deltaText,
                    key: const ValueKey('run.race.delta'),
                    style: t.titleMedium?.copyWith(color: deltaColour),
                  ),
                  Text(
                    projected == null
                        ? 'Target ${formatDuration(plan.targetSeconds)}'
                        : 'Finish ~${formatDuration(projected)}',
                    key: const ValueKey('run.race.finish'),
                    style: t.bodySmall,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: run.progress,
            color: FitPalette.current.glow,
            backgroundColor: FitColors.ink.withValues(alpha: 0.1),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }
}
