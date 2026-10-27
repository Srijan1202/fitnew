import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/result.dart';
import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/fit_glass.dart';
import '../../domain/units.dart';
import '../../domain/workout.dart';
import '../controllers/running_providers.dart';
import '../screens/run_start.dart';

/// Beta 4.1 (ADR-039): the running plan on Running — this week's runs, start
/// today's, skip or move one, stop the plan; or the way to make one.
class PlanCard extends ConsumerWidget {
  const PlanCard({required this.today, super.key});

  /// yyyy-mm-dd, the user's local date.
  final String today;

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(currentPlanProvider);
    final unit = ref.watch(runSettingsProvider).unit;
    final t = Theme.of(context).textTheme;
    final plan = async.value;
    if (async.isLoading && plan == null) return const SizedBox.shrink();
    if (plan == null) {
      return FitBlock(
        key: const ValueKey('running.plan.none'),
        padding: const EdgeInsets.all(FitSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TRAIN FOR A RACE', style: t.labelSmall),
            const SizedBox(height: FitSpacing.xs),
            Text(
              'A 5K, 10K, half marathon or marathon plan: the right runs on '
              'your days, at your paces, with the coach.',
              style: t.bodyLarge,
            ),
            const SizedBox(height: FitSpacing.sm),
            OutlinedButton(
              key: const ValueKey('running.plan.new'),
              onPressed: () => context.push(Routes.runPlanNew),
              child: const Text('Choose a plan'),
            ),
          ],
        ),
      );
    }
    final week = plan.weekOf(today);
    final weekNo = week.isEmpty ? null : week.first.week;
    final z = plan.zones;
    return FitBlock(
      key: const ValueKey('running.plan'),
      padding: const EdgeInsets.all(FitSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${plan.goalLabel.toUpperCase()} PLAN'
                  '${weekNo == null ? '' : ' · WEEK $weekNo OF ${plan.weeks}'}',
                  style: t.labelSmall,
                ),
              ),
              PopupMenuButton<String>(
                key: const ValueKey('running.plan.menu'),
                onSelected: (v) {
                  if (v == 'stop') _stop(context, ref);
                  if (v == 'new') context.push(Routes.runPlanNew);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'new', child: Text('Make a new plan')),
                  PopupMenuItem(
                    key: ValueKey('running.plan.stop'),
                    value: 'stop',
                    child: Text('Stop this plan'),
                  ),
                ],
              ),
            ],
          ),
          if (plan.predictedSeconds != null)
            Text(
              'Predicted ${plan.goalLabel}: ${formatDuration(plan.predictedSeconds!)}',
              style: t.titleMedium,
            ),
          if (z != null)
            Text(
              'Easy ${formatPace(z.easy.fast.toDouble(), unit)}–'
              '${formatPace(z.easy.slow.toDouble(), unit)} · threshold '
              '${formatPace(z.threshold.toDouble(), unit)} · interval '
              '${formatPace(z.interval.toDouble(), unit)} ${unit.paceLabel}',
              style: t.bodyMedium,
            ),
          const SizedBox(height: FitSpacing.sm),
          if (week.isEmpty)
            Text('No runs planned this week.', style: t.bodyMedium)
          else
            for (final r in week) _PlannedRow(run: r, today: today, unit: unit),
          if (plan.gymOverlap.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: FitSpacing.xs),
              child: Text(
                'Gym too on ${plan.gymOverlap.map((d) => _days[d - 1]).join(', ')}.',
                style: t.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _stop(BuildContext context, WidgetRef ref) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stop this plan?'),
        content: const Text(
          'Its runs still to come go. The runs you did stay in your history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            key: const ValueKey('running.plan.stop.yes'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Stop', style: TextStyle(color: FitColors.oxide)),
          ),
        ],
      ),
    );
    if (!(yes ?? false)) return;
    await ref.read(runningApiProvider).stopPlan();
    ref.invalidate(currentPlanProvider);
    ref.invalidate(workoutPresetsProvider);
  }
}

class _PlannedRow extends ConsumerWidget {
  const _PlannedRow({
    required this.run,
    required this.today,
    required this.unit,
  });

  final PlannedRun run;
  final String today;
  final DistanceUnit unit;

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  Future<void> _patch(WidgetRef ref, Map<String, dynamic> body) async {
    final r = await ref.read(runningApiProvider).patchPlanned(run.id, body);
    if (r is Ok) ref.invalidate(currentPlanProvider);
  }

  Future<void> _move(BuildContext context, WidgetRef ref) async {
    final d = DateTime.parse(run.date);
    final monday = d.subtract(Duration(days: d.weekday - 1));
    final now = DateTime.parse(today);
    final days = [
      for (var i = 0; i < 7; i++) monday.add(Duration(days: i)),
    ].where((x) => !x.isBefore(now) && x != d).toList();
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final x in days)
              ListTile(
                key: ValueKey('running.move.${x.weekday}'),
                title: Text(_days[x.weekday - 1]),
                onTap: () => Navigator.of(ctx).pop(x),
              ),
            if (days.isEmpty)
              const ListTile(title: Text('No other day left this week.')),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await _patch(ref, {
      'action': 'move',
      'date': picked.toIso8601String().substring(0, 10),
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final isToday = run.date == today;
    final past = run.date.compareTo(today) < 0;
    final day = _days[DateTime.parse(run.date).weekday - 1];
    final (icon, colour) = switch (run.status) {
      PlannedRunStatus.done => (Icons.check_circle, FitColors.pine),
      PlannedRunStatus.skipped => (
          Icons.remove_circle_outline,
          FitColors.ink35
        ),
      PlannedRunStatus.planned => past
          ? (Icons.radio_button_unchecked, FitColors.amber)
          : (Icons.radio_button_unchecked, FitColors.ink60),
    };
    final pace = run.pace == null
        ? ''
        : ' · ${formatPace(run.pace!.fast.toDouble(), unit)}–'
            '${formatPace(run.pace!.slow.toDouble(), unit)}';
    return Padding(
      key: ValueKey('running.planned.${run.id}'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colour),
          const SizedBox(width: FitSpacing.sm),
          SizedBox(
            width: 40,
            child: Text(
              isToday ? 'Today' : day,
              style: t.bodyMedium?.copyWith(
                color: isToday ? FitColors.ink : FitColors.ink60,
                fontWeight: isToday ? FontWeight.w700 : null,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${run.title}$pace',
              style: t.bodyLarge?.copyWith(
                decoration: run.status == PlannedRunStatus.skipped
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
          ),
          if (run.status == PlannedRunStatus.planned && isToday)
            FilledButton(
              key: ValueKey('running.planned.start.${run.id}'),
              onPressed: () => startPlannedRun(context, ref, run),
              child: const Text('Start'),
            ),
          if (run.status == PlannedRunStatus.skipped && !past)
            TextButton(
              onPressed: () => _patch(ref, {'action': 'unskip'}),
              child: const Text('Undo'),
            ),
          if (run.status == PlannedRunStatus.planned && !past)
            PopupMenuButton<String>(
              key: ValueKey('running.planned.menu.${run.id}'),
              onSelected: (v) {
                if (v == 'skip') _patch(ref, {'action': 'skip'});
                if (v == 'move') _move(context, ref);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'skip', child: Text('Skip')),
                PopupMenuItem(
                  value: 'move',
                  child: Text('Move to another day'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
