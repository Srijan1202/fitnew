import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tokens.dart';
import '../../../training/domain/entities/program.dart';
import '../../domain/entities/workout.dart';
import '../controllers/workout_providers.dart';

/// "Start session" on a training day, "Start empty session" on a rest
/// day, "Resume · 12 min" whenever a session is in progress on this phone
/// (one at a time, whatever day it belongs to).
class StartSessionButton extends ConsumerWidget {
  const StartSessionButton({
    required this.dayOfWeek,
    required this.isRest,
    required this.onStart,
    super.key,
  });

  final int dayOfWeek;
  final bool isRest;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeSessionProvider).value;
    if (active != null) {
      final minutes =
          DateTime.now().difference(DateTime.parse(active.startedAt)).inMinutes;
      return FilledButton(
        key: const ValueKey('day.resume'),
        onPressed: onStart,
        child: Text('Resume ${active.name} · $minutes min'),
      );
    }
    if (isRest) {
      return OutlinedButton(
        key: const ValueKey('day.startEmpty'),
        onPressed: onStart,
        style: OutlinedButton.styleFrom(
          foregroundColor: FitColors.ink,
          side: const BorderSide(color: FitColors.ink),
        ),
        child: const Text('Start empty session'),
      );
    }
    return FilledButton(
      key: const ValueKey('day.start'),
      onPressed: onStart,
      child: const Text('Start session'),
    );
  }
}

/// The plan itself as a session seed, for a gym with no signal: the plan's
/// targets, no "last time" (that needs the server), prefill = the plan.
TodayResponse todayFromPlan(Program program, ProgramDay day) => TodayResponse(
      date: '',
      dayOfWeek: day.dayOfWeek,
      programId: program.id,
      programDayId: day.id,
      sessionName: day.sessionName,
      isRest: day.isRest,
      focus: day.focus,
      exercises: [
        for (final x in day.exercises)
          TodayExercise(
            plannedExerciseId: x.id,
            exerciseId: x.exerciseId,
            slug: x.slug,
            name: x.name,
            movementPattern: x.movementPattern,
            equipment: x.equipment,
            difficulty: x.difficulty,
            primaryMuscles: x.primaryMuscles,
            secondaryMuscles: const [],
            orderIndex: x.orderIndex,
            incrementKg: x.incrementKg,
            targets: x.sets,
            prefill: [
              for (final s in x.sets)
                SetPrefill(
                  setIndex: s.setIndex,
                  reps: s.targetReps,
                  weightKg: s.weightKg,
                  rir: s.rir,
                  weightSource: s.weightKg == null ? 'none' : 'plan',
                ),
            ],
            lastPerformance: null,
          ),
      ],
      activeSession: null,
      completedSessionId: null,
    );
