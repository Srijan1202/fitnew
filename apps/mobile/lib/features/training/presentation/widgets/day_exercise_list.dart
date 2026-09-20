import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../exercise/domain/entities/exercise.dart';
import '../../domain/entities/program.dart';

/// A draft exercise in an editor: what the server needs (a
/// [CustomExercise]) plus the name to show. Pure client state until saved.
class DraftExercise {
  const DraftExercise({
    required this.exerciseId,
    required this.name,
    required this.setCount,
    required this.repMin,
    required this.repMax,
    required this.targetRir,
    this.incrementKg,
  });

  factory DraftExercise.fromPlanned(PlannedExercise x) => DraftExercise(
        exerciseId: x.exerciseId,
        name: x.name,
        setCount: x.setCount,
        repMin: x.repMin,
        repMax: x.repMax,
        targetRir: x.targetRir,
        incrementKg: x.incrementKg,
      );

  /// A new pick starts at the most common hypertrophy prescription (§12.1
  /// muscle-gain row); the user adjusts from there.
  factory DraftExercise.fromSummary(ExerciseSummary s) => DraftExercise(
        exerciseId: s.id,
        name: s.name,
        setCount: 3,
        repMin: 6,
        repMax: 12,
        targetRir: 2,
      );

  final String exerciseId;
  final String name;
  final int setCount;
  final int repMin;
  final int repMax;
  final int targetRir;
  final double? incrementKg;

  DraftExercise copyWith({
    int? setCount,
    int? repMin,
    int? repMax,
    int? targetRir,
  }) =>
      DraftExercise(
        exerciseId: exerciseId,
        name: name,
        setCount: setCount ?? this.setCount,
        repMin: repMin ?? this.repMin,
        repMax: repMax ?? this.repMax,
        targetRir: targetRir ?? this.targetRir,
        incrementKg: incrementKg,
      );

  CustomExercise toCustom() => CustomExercise(
        exerciseId: exerciseId,
        setCount: setCount,
        repMin: repMin,
        repMax: repMax,
        targetRir: targetRir,
        incrementKg: incrementKg,
      );
}

/// Editable list of a day's exercises: sets / reps / RIR steppers, remove,
/// and "Add exercise" which opens the library in picker mode.
class DayExerciseList extends StatelessWidget {
  const DayExerciseList({
    required this.exercises,
    required this.onChanged,
    required this.enabled,
    this.keyPrefix = 'day',
    super.key,
  });

  final List<DraftExercise> exercises;
  final ValueChanged<List<DraftExercise>> onChanged;
  final bool enabled;
  final String keyPrefix;

  Future<void> _add(BuildContext context) async {
    final picked = await context.push<ExerciseSummary>(Routes.exercisePicker);
    if (picked == null) return;
    onChanged([...exercises, DraftExercise.fromSummary(picked)]);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var i = 0; i < exercises.length; i++) ...<Widget>[
          _Row(
            key: ValueKey('$keyPrefix.exercise.$i'),
            draft: exercises[i],
            enabled: enabled,
            onChanged: (d) {
              final next = [...exercises];
              next[i] = d;
              onChanged(next);
            },
            onRemove: () => onChanged([...exercises]..removeAt(i)),
          ),
          const Divider(color: FitColors.rule, height: 1),
        ],
        const SizedBox(height: FitSpacing.sm),
        TextButton(
          key: ValueKey('$keyPrefix.add'),
          onPressed: enabled ? () => _add(context) : null,
          child: Text('+ Add exercise', style: textTheme.titleMedium),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.draft,
    required this.enabled,
    required this.onChanged,
    required this.onRemove,
    super.key,
  });

  final DraftExercise draft;
  final bool enabled;
  final ValueChanged<DraftExercise> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: FitSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(draft.name, style: textTheme.titleMedium)),
              IconButton(
                tooltip: 'Remove',
                onPressed: enabled ? onRemove : null,
                icon: const Icon(Icons.close, size: 18, color: FitColors.ink60),
              ),
            ],
          ),
          Wrap(
            spacing: FitSpacing.lg,
            runSpacing: FitSpacing.xs,
            children: <Widget>[
              _Stepper(
                label: 'sets',
                value: draft.setCount,
                min: 1,
                max: 10,
                enabled: enabled,
                onChanged: (v) => onChanged(draft.copyWith(setCount: v)),
              ),
              _Stepper(
                label: 'reps from',
                value: draft.repMin,
                min: 1,
                max: draft.repMax,
                enabled: enabled,
                onChanged: (v) => onChanged(draft.copyWith(repMin: v)),
              ),
              _Stepper(
                label: 'to',
                value: draft.repMax,
                min: draft.repMin,
                max: 50,
                enabled: enabled,
                onChanged: (v) => onChanged(draft.copyWith(repMax: v)),
              ),
              _Stepper(
                label: 'RIR',
                value: draft.targetRir,
                min: 0,
                max: 5,
                enabled: enabled,
                onChanged: (v) => onChanged(draft.copyWith(targetRir: v)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// −  value  + in the hairline language: no filled buttons, the number is
/// the hero (§6.3), 44px hit targets.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label, style: textTheme.bodyMedium),
        const SizedBox(width: FitSpacing.xs),
        IconButton(
          tooltip: 'Fewer $label',
          onPressed: enabled && value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove, size: 18),
        ),
        Text('$value', style: textTheme.titleLarge),
        IconButton(
          tooltip: 'More $label',
          onPressed: enabled && value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add, size: 18),
        ),
      ],
    );
  }
}
