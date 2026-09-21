import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../exercise/domain/entities/exercise.dart';
import 'draft.dart';

/// The structure of a day: exercises in order, drag to reorder, remove,
/// "+ Add exercise" through the library picker. Sets and reps are edited
/// elsewhere (the workout screen, or the builder's sets step).
class DraftExerciseList extends StatelessWidget {
  const DraftExerciseList({
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
    onChanged([
      ...exercises,
      DraftExercise.fromSummary(picked, nonce: exercises.length),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ReorderableListView(
          key: ValueKey('$keyPrefix.list'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorderItem: (from, to) {
            final next = [...exercises];
            final item = next.removeAt(from);
            next.insert(to, item);
            onChanged(next);
          },
          children: <Widget>[
            for (var i = 0; i < exercises.length; i++)
              _Row(
                key: ValueKey('$keyPrefix.exercise.${exercises[i].key}'),
                index: i,
                draft: exercises[i],
                enabled: enabled,
                onRemove: () => onChanged([...exercises]..removeAt(i)),
              ),
          ],
        ),
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
    required this.index,
    required this.draft,
    required this.enabled,
    required this.onRemove,
    super.key,
  });

  final int index;
  final DraftExercise draft;
  final bool enabled;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: const BoxDecoration(
        color: FitColors.paper,
        border: Border(bottom: BorderSide(color: FitColors.rule)),
      ),
      padding: const EdgeInsets.symmetric(vertical: FitSpacing.sm),
      child: Row(
        children: <Widget>[
          ReorderableDragStartListener(
            index: index,
            enabled: enabled,
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(Icons.drag_handle, size: 20, color: FitColors.ink60),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(draft.name, style: textTheme.titleMedium),
                Text(
                  '${draft.primaryMuscles.map((m) => m.label).join(', ')} · ${draft.sets.length} sets',
                  style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove ${draft.name}',
            onPressed: enabled ? onRemove : null,
            icon: const Icon(Icons.close, size: 18, color: FitColors.ink60),
          ),
        ],
      ),
    );
  }
}
