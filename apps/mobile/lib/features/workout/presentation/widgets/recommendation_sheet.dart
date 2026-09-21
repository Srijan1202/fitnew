import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tokens.dart';
import '../../domain/entities/workout.dart';
import '../controllers/workout_providers.dart';
import 'session_exercise_card.dart';

/// Tap on the reason line (plan §6): the full reason, the last three
/// sessions of this lift from the server, and **Use last time's weight**
/// which reverts every pending row. Nothing here computes a number.
class RecommendationSheet extends ConsumerWidget {
  const RecommendationSheet({
    required this.exercise,
    required this.onUseLastWeight,
    super.key,
  });

  final SessionExercise exercise;

  /// Null when there is nothing to revert to.
  final VoidCallback? onUseLastWeight;

  static Future<void> show(
    BuildContext context,
    SessionExercise exercise, {
    VoidCallback? onUseLastWeight,
  }) =>
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: FitColors.paper,
        isScrollControlled: true,
        builder: (_) => RecommendationSheet(
          exercise: exercise,
          onUseLastWeight: onUseLastWeight,
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
            const Divider(color: FitColors.rule, height: 1),
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
                              '${h.date}  ${h.sets.map((s) => '${s.weightKg == null ? '—' : _kg(s.weightKg!)}×${s.reps}${s.rir == null ? '' : ' @${s.rir}'}').join('  ')}',
                              key: ValueKey(
                                'recommendation.history.${h.sessionId}',
                              ),
                              style: textTheme.bodyMedium,
                            ),
                          ),
                      ],
                    ),
            ),
            if (onUseLastWeight != null) ...<Widget>[
              const SizedBox(height: FitSpacing.md),
              OutlinedButton(
                key: const ValueKey('recommendation.useLast'),
                onPressed: () {
                  onUseLastWeight!();
                  Navigator.of(context).pop();
                },
                child: Text(
                  "Use last time's weight (${_kg(SessionExerciseCard.lastWeightOf(exercise)!)} kg)",
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
