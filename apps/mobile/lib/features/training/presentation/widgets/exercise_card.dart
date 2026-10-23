import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tokens.dart';
import '../../../exercise/presentation/controllers/exercise_providers.dart';
import '../../../workout/domain/entities/workout.dart';
import '../../domain/entities/program.dart';
import 'set_row.dart';
import '../../../../shared/widgets/fit_glass.dart';

/// One exercise on the workout-day screen, in two states (progressive
/// disclosure). Collapsed: number, name, primary muscle, sets × reps, the
/// starting weight, a chevron. Expanded: every set editable in place, then
/// equipment, how to do it (fetched on first open), why it is here, and
/// replace / remove. No cards inside cards: a hairline above, ink for the
/// number, nothing filled.
class ExerciseCard extends ConsumerWidget {
  const ExerciseCard({
    required this.index,
    required this.exercise,
    required this.expanded,
    required this.enabled,
    required this.onToggle,
    required this.onSetChanged,
    required this.onReplace,
    required this.onRemove,
    this.onAddSet,
    this.onRemoveSet,
    this.last,
    super.key,
  });

  /// 1-based position in the day.
  final int index;
  final PlannedExercise exercise;
  final bool expanded;
  final bool enabled;
  final VoidCallback onToggle;
  final void Function(int setIndex, PlannedSet set) onSetChanged;
  final VoidCallback onReplace;
  final VoidCallback onRemove;

  /// Set-count editing (Phase 5 carry-over): another set below the last,
  /// or one fewer. Null where the count is fixed.
  final VoidCallback? onAddSet;
  final ValueChanged<int>? onRemoveSet;

  /// What was lifted last time (the server's day; null offline or before
  /// the first session). Shown beside the plan, never written into it.
  final LastPerformance? last;

  /// Last time's heaviest weight, if any.
  static double? lastTopWeight(LastPerformance? last) {
    final w = last?.sets.map((s) => s.weightKg).whereType<double>().toList();
    if (w == null || w.isEmpty) return null;
    return w.reduce((a, b) => a > b ? a : b);
  }

  static String _kg(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  /// Last time's weight for this set number, if that set was lifted.
  double? _lastWeightFor(int setIndex) {
    final sets = last?.sets;
    if (sets == null || setIndex < 1 || setIndex > sets.length) return null;
    return sets[setIndex - 1].weightKg;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => FitBlock(
        // ADR-029: each exercise its own block on the glass palettes.
        margin: const EdgeInsets.fromLTRB(12, 5, 12, 5),
        child: _content(context, ref),
      );

  Widget _content(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final x = exercise;
    final primary = x.primaryMuscles.map((m) => m.label).join(', ');
    final weight = x.startingWeightKg;
    final lastTop = lastTopWeight(last);
    final cardKey = 'exercise.${x.id}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const FitRule(),
        InkWell(
          key: ValueKey('$cardKey.header'),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: FitSpacing.screen,
              vertical: FitSpacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 34,
                  child: Text(
                    '$index',
                    style: textTheme.displaySmall?.copyWith(height: 1),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(x.name, style: textTheme.titleLarge),
                      const SizedBox(height: FitSpacing.xs),
                      Text(
                        '$primary · ${x.equipment.map((e) => e.label).join(' + ')}',
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: FitSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(x.prescription, style: textTheme.titleMedium),
                    const SizedBox(height: FitSpacing.xs),
                    Text(
                      weight != null
                          ? '${_kg(weight)} kg'
                          : lastTop != null
                              ? 'last ${_kg(lastTop)} kg'
                              : 'set weight',
                      key: ValueKey('$cardKey.weight'),
                      style: textTheme.bodyMedium?.copyWith(
                        color: weight != null
                            ? FitColors.ink
                            : lastTop != null
                                ? FitColors.ink60
                                : FitColors.amber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: FitSpacing.sm),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      Icons.expand_more,
                      size: 22,
                      color: FitColors.ink60,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              FitSpacing.screen,
              0,
              FitSpacing.screen,
              FitSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (last != null && last!.sets.isNotEmpty) ...<Widget>[
                  Text(
                    'Last time: ${last!.sets.map((s) => '${s.weightKg == null ? '—' : _kg(s.weightKg!)}×${s.reps}').join('  ')}',
                    key: ValueKey('$cardKey.last'),
                    style:
                        textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
                  ),
                  const SizedBox(height: FitSpacing.xs),
                ],
                for (final set in x.sets)
                  SetRow(
                    key: ValueKey('$cardKey.set.${set.setIndex}'),
                    rowKey: '$cardKey.set.${set.setIndex}',
                    set: set,
                    lastWeightKg: _lastWeightFor(set.setIndex) ?? lastTop,
                    incrementKg: x.incrementKg,
                    enabled: enabled,
                    onChanged: (next) => onSetChanged(set.setIndex, next),
                    trailing: onRemoveSet == null || x.sets.length <= 1
                        ? null
                        : InkWell(
                            key:
                                ValueKey('$cardKey.set.${set.setIndex}.remove'),
                            onTap: enabled
                                ? () => onRemoveSet!(set.setIndex)
                                : null,
                            borderRadius: BorderRadius.all(FitRadius.medium),
                            child: SizedBox(
                              width: 32,
                              height: 44,
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: FitColors.ink35,
                              ),
                            ),
                          ),
                  ),
                if (onAddSet != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      key: ValueKey('$cardKey.addSet'),
                      onPressed: enabled ? onAddSet : null,
                      child: const Text('+ Add set'),
                    ),
                  ),
                const SizedBox(height: FitSpacing.md),
                _Instructions(exerciseId: x.exerciseId),
                if (x.reason != null) ...<Widget>[
                  const SizedBox(height: FitSpacing.md),
                  Text('WHY THIS EXERCISE', style: textTheme.labelSmall),
                  const SizedBox(height: FitSpacing.xs),
                  Text(x.reason!, style: textTheme.bodyMedium),
                ],
                const SizedBox(height: FitSpacing.md),
                Row(
                  children: <Widget>[
                    TextButton(
                      key: ValueKey('$cardKey.replace'),
                      onPressed: enabled ? onReplace : null,
                      child: const Text('Replace'),
                    ),
                    TextButton(
                      key: ValueKey('$cardKey.remove'),
                      onPressed: enabled ? onRemove : null,
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Instructions come from the library on first expand; a card that is never
/// opened never fetches.
class _Instructions extends ConsumerWidget {
  const _Instructions({required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final async = ref.watch(exerciseDetailProvider(exerciseId));
    return async.when(
      loading: () => Container(width: 200, height: 12, color: FitColors.paper2),
      error: (_, __) => const SizedBox.shrink(),
      data: (d) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('HOW TO DO IT', style: textTheme.labelSmall),
          const SizedBox(height: FitSpacing.xs),
          for (var i = 0; i < d.instructions.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: FitSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 22,
                    child: Text('${i + 1}', style: textTheme.bodyMedium),
                  ),
                  Expanded(
                    child: Text(d.instructions[i], style: textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
