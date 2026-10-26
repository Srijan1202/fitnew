part of 'workout_week_screen.dart';

/* --------------------------------------------------------------- day -- */

class _DayView extends StatelessWidget {
  const _DayView({
    required this.day,
    required this.exercises,
    required this.startButton,
    required this.onAddSet,
    required this.onRemoveSet,
    required this.expanded,
    required this.saveState,
    required this.saveFailure,
    required this.onToggle,
    required this.onSetChanged,
    required this.onRemove,
    required this.onReplace,
    required this.onRetry,
    required this.onEditDay,
    this.deload,
    this.mesocycleWeek,
    this.substitutions = const {},
    this.onSubstitute,
    this.last = const {},
    super.key,
  });

  final ProgramDay day;
  final List<PlannedExercise> exercises;
  final Widget startButton;
  final ValueChanged<String> onAddSet;
  final void Function(String exerciseId, int setIndex) onRemoveSet;
  final Set<String> expanded;
  final _SaveState saveState;
  final Failure? saveFailure;
  final ValueChanged<String> onToggle;
  final void Function(String exerciseId, PlannedSet set) onSetChanged;
  final ValueChanged<String> onRemove;
  final ValueChanged<PlannedExercise> onReplace;
  final VoidCallback onRetry;
  final VoidCallback onEditDay;

  /// Phase 6, from the server's `/today?dayOfWeek=`; null when offline.
  final DeloadState? deload;
  final int? mesocycleWeek;

  /// Substitutions by planned exercise id.
  final Map<String, Substitution> substitutions;
  final void Function(PlannedExercise, SubstitutionAlternative)? onSubstitute;

  /// Last time's sets by planned exercise id (owner 2026-10-23: what was
  /// lifted shows on the plan, as a hint the plan does not store).
  final Map<String, LastPerformance> last;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final weekday = kWeekdayLabels[day.dayOfWeek - 1].toUpperCase();
    final sets = exercises.fold<int>(0, (s, x) => s + x.sets.length);
    final minutes = (sets * 3.5).round();

    if (day.isRest && exercises.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(FitSpacing.screen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(weekday, style: textTheme.labelSmall),
            const SizedBox(height: FitSpacing.xs),
            Text('Rest', style: textTheme.displaySmall),
            const SizedBox(height: FitSpacing.sm),
            Text(
              'Nothing planned. Recovery is part of the programme.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: FitSpacing.lg),
            OutlinedButton(
              key: const ValueKey('day.train'),
              onPressed: onEditDay,
              child: const Text('Train this day instead'),
            ),
            const SizedBox(height: FitSpacing.sm),
            startButton,
          ],
        ),
      );
    }

    // Beta 3.6: "+ Add set" right after scrolling lands first time.
    return TapThroughListView(
      listKey: const ValueKey('day.list'),
      padding: const EdgeInsets.only(bottom: FitSpacing.xl),
      children: <Widget>[
        FitBlock(
          glow: true,
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              fitGlass ? FitSpacing.md : FitSpacing.screen,
              fitGlass ? FitSpacing.md : FitSpacing.lg,
              fitGlass ? FitSpacing.md : FitSpacing.screen,
              FitSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(child: Text(weekday, style: textTheme.labelSmall)),
                    _SaveMark(
                      state: saveState,
                      failure: saveFailure,
                      onRetry: onRetry,
                    ),
                  ],
                ),
                const SizedBox(height: FitSpacing.xs),
                Text(
                  day.sessionName,
                  key: const ValueKey('day.title'),
                  style: textTheme.displayMedium,
                ),
                const SizedBox(height: FitSpacing.sm),
                Text(
                  day.focus.map((m) => m.label).join(' · '),
                  style: textTheme.bodyLarge,
                ),
                const SizedBox(height: FitSpacing.xs),
                Text(
                  '${exercises.length} exercises · $sets sets · ~$minutes min${mesocycleWeek == null ? '' : ' · week $mesocycleWeek'}',
                  key: const ValueKey('day.meta'),
                  style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
                ),
                if (deload != null && deload!.state != DeloadStatus.none) ...[
                  const SizedBox(height: FitSpacing.sm),
                  DeloadPanel(
                    deload: deload!,
                    mesocycleWeek: mesocycleWeek,
                    compact: deload!.state == DeloadStatus.active,
                  ),
                ],
                const SizedBox(height: FitSpacing.md),
                startButton,
              ],
            ),
          ),
        ),
        for (var i = 0; i < exercises.length; i++) ...<Widget>[
          ExerciseCard(
            key: ValueKey('card.${exercises[i].id}'),
            index: i + 1,
            exercise: exercises[i],
            expanded: expanded.contains(exercises[i].id),
            enabled: saveState != _SaveState.saving,
            onToggle: () => onToggle(exercises[i].id),
            onSetChanged: (_, set) => onSetChanged(exercises[i].id, set),
            onReplace: () => onReplace(exercises[i]),
            onRemove: () => onRemove(exercises[i].id),
            onAddSet: () => onAddSet(exercises[i].id),
            onRemoveSet: (index) => onRemoveSet(exercises[i].id, index),
            last: last[exercises[i].id],
          ),
          if (substitutions[exercises[i].id] != null)
            SubstitutionLine(
              keyPrefix: 'card.${exercises[i].id}',
              substitution: substitutions[exercises[i].id]!,
              onAccept: onSubstitute == null || saveState == _SaveState.saving
                  ? null
                  : (alt) => onSubstitute!(exercises[i], alt),
            ),
        ],
        const FitRule(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            FitSpacing.screen,
            FitSpacing.md,
            FitSpacing.screen,
            0,
          ),
          child: TextButton(
            key: const ValueKey('day.edit'),
            onPressed: onEditDay,
            child: const Text('Add or reorder exercises'),
          ),
        ),
      ],
    );
  }
}

/// ADR-030: today, skipped — what comes tomorrow, and the way back.
class _SkippedToday extends StatelessWidget {
  const _SkippedToday({required this.tomorrow, required this.onUndo});

  final ProgramDay tomorrow;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final next = tomorrow.isRest ? 'a rest day' : tomorrow.sessionName;
    return ListView(
      key: const ValueKey('day.skipped'),
      padding: const EdgeInsets.only(bottom: FitSpacing.xl),
      children: <Widget>[
        FitBlock(
          glow: true,
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          flatPadding: const EdgeInsets.all(FitSpacing.screen),
          padding: const EdgeInsets.all(FitSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('TODAY', style: textTheme.labelSmall),
              const SizedBox(height: FitSpacing.xs),
              Text('Skipped', style: textTheme.displayMedium),
              const SizedBox(height: FitSpacing.sm),
              Text(
                'Your week moved one day later. Tomorrow is $next.',
                key: const ValueKey('day.skipped.next'),
                style: textTheme.bodyLarge,
              ),
              const SizedBox(height: FitSpacing.md),
              OutlinedButton(
                key: const ValueKey('day.undoSkip'),
                onPressed: onUndo,
                child: const Text('Undo skip'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Saving…" / "Saved" / "Couldn't save · Retry" — small, top right of the
/// day, never a snackbar over the sets you are editing.
class _SaveMark extends StatelessWidget {
  const _SaveMark({
    required this.state,
    required this.failure,
    required this.onRetry,
  });

  final _SaveState state;
  final Failure? failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    switch (state) {
      case _SaveState.idle:
        return const SizedBox.shrink();
      case _SaveState.saving:
        return Text(
          'Saving…',
          key: const ValueKey('save.saving'),
          style: textTheme.labelSmall?.copyWith(color: FitColors.ink60),
        );
      case _SaveState.saved:
        return Text(
          'Saved',
          key: const ValueKey('save.saved'),
          style: textTheme.labelSmall?.copyWith(color: FitColors.pine),
        );
      case _SaveState.failed:
        return InkWell(
          key: const ValueKey('save.retry'),
          onTap: onRetry,
          child: Text(
            "Couldn't save · Retry",
            style: textTheme.labelSmall?.copyWith(color: FitColors.oxide),
          ),
        );
    }
  }
}

class _WeekSkeleton extends StatelessWidget {
  const _WeekSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(height: 56, color: FitColors.paper2),
        Padding(
          padding: const EdgeInsets.all(FitSpacing.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(width: 80, height: 11, color: FitColors.paper2),
              const SizedBox(height: FitSpacing.sm),
              Container(width: 180, height: 36, color: FitColors.paper2),
              const SizedBox(height: FitSpacing.lg),
              for (var i = 0; i < 4; i++) ...<Widget>[
                Divider(color: FitColors.rule, height: 1),
                const SizedBox(height: FitSpacing.md),
                Container(width: 220, height: 18, color: FitColors.paper2),
                const SizedBox(height: FitSpacing.md),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.failure, required this.onRetry});

  final Failure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(FitSpacing.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Could not load your plan', style: textTheme.titleLarge),
          const SizedBox(height: FitSpacing.sm),
          AuthFeedback.error(failure.message),
          const SizedBox(height: FitSpacing.lg),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
