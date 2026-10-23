import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tokens.dart';
import '../../domain/entities/workout.dart';
import '../controllers/workout_providers.dart';
import 'session_exercise_card.dart';
import '../../../../shared/widgets/fit_glass.dart';

/// Tap on the reason line (plan §6): the full reason, the last three
/// sessions of this lift from the server, and **Apply** which puts the
/// suggestion on every pending row (the rows open at last time's numbers,
/// owner 2026-10-23). Nothing here computes a number.
class RecommendationSheet extends ConsumerWidget {
  const RecommendationSheet({
    required this.exercise,
    required this.onApply,
    super.key,
  });

  final SessionExercise exercise;

  /// Null when there is nothing to apply.
  final VoidCallback? onApply;

  static Future<void> show(
    BuildContext context,
    SessionExercise exercise, {
    VoidCallback? onApply,
  }) =>
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: FitColors.paper,
        isScrollControlled: true,
        builder: (_) => RecommendationSheet(
          exercise: exercise,
          onApply: onApply,
        ),
      );

  static String _kg(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final r = exercise.recommendation;
    final detail = ref.watch(progressionProvider(exercise.exerciseId));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          FitSpacing.screen,
          FitSpacing.lg,
          FitSpacing.screen,
          FitSpacing.lg,
        ),
        child: Column(
          key: const ValueKey('recommendation.sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(exercise.name.toUpperCase(), style: textTheme.labelSmall),
            const SizedBox(height: FitSpacing.xs),
            if (r != null) ...<Widget>[
              Text(
                '${SessionExerciseCard.actionGlyph(r.action)} ${SessionExerciseCard.recommendationLabel(r)}',
                style: textTheme.displaySmall?.copyWith(
                  color: SessionExerciseCard.actionColor(r.action),
                ),
              ),
              const SizedBox(height: FitSpacing.sm),
              Text(
                r.reason,
                key: const ValueKey('recommendation.reason'),
                style: textTheme.bodyLarge,
              ),
              const SizedBox(height: FitSpacing.xs),
              Text(
                r.sessionsConsidered == 0
                    ? 'No completed sessions of this lift yet.'
                    : 'From your last ${r.sessionsConsidered} ${r.sessionsConsidered == 1 ? 'session' : 'sessions'} of this lift.',
                style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
              ),
            ] else
              Text(
                'No recommendation for an exercise outside the plan.',
                style: textTheme.bodyLarge,
              ),
            const SizedBox(height: FitSpacing.md),
            const FitRule(),
            const SizedBox(height: FitSpacing.md),
            Text('LAST THREE SESSIONS', style: textTheme.labelSmall),
            const SizedBox(height: FitSpacing.xs),
            detail.when(
              loading: () => Text(
                'Loading…',
                style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
              ),
              error: (_, __) => Text(
                'History needs a connection.',
                key: const ValueKey('recommendation.historyError'),
                style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
              ),
              data: (d) => d.history.isEmpty
                  ? Text(
                      'Nothing logged yet.',
                      style: textTheme.bodyMedium
                          ?.copyWith(color: FitColors.ink60),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        for (final h in d.history)
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: FitSpacing.xs),
                            child: Text(
                              '${h.date}  ${h.sets.map((s) => '${s.weightKg == null ? '—' : _kg(s.weightKg!)}×${s.reps}').join('  ')}',
                              key: ValueKey(
                                'recommendation.history.${h.sessionId}',
                              ),
                              style: textTheme.bodyMedium,
                            ),
                          ),
                      ],
                    ),
            ),
            if (onApply != null && r != null) ...<Widget>[
              const SizedBox(height: FitSpacing.md),
              FilledButton(
                key: const ValueKey('recommendation.apply'),
                onPressed: () {
                  onApply!();
                  Navigator.of(context).pop();
                },
                child: Text(
                  'Apply ${SessionExerciseCard.recommendationLabel(r)}',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
