import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../training/domain/entities/program.dart';
import '../../domain/entities/workout.dart';
import '../controllers/workout_providers.dart';
import 'discard_session.dart';
import 'orphan_session_notice.dart';

/// "Start session" on a training day, "Start empty session" on a rest
/// day, "Resume · 12 min" (and Discard) whenever a session is in progress on this phone
/// (one at a time, whatever day it belongs to), and "Done today" with the
/// summary once today's session is finished (owner 2026-10-23: the day
/// screen offered Start again right after finishing).
class StartSessionButton extends ConsumerWidget {
  const StartSessionButton({
    required this.dayOfWeek,
    required this.isRest,
    required this.onStart,
    this.completedSessionId,
    super.key,
  });

  final int dayOfWeek;
  final bool isRest;
  final VoidCallback onStart;

  /// The session finished today (the server's `completedSessionId`), when
  /// this is today's day. Another session can still be started from ⋯.
  final String? completedSessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final button = _button(context, ref);
    // Phase 6.6 Gate 7: say why a new session would not reach FITOS, right
    // where it is started. Starting stays possible (gyms have no signal).
    if (ref.watch(orphanedSessionProvider).value == null) return button;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const OrphanSessionNotice(),
        const SizedBox(height: FitSpacing.sm),
        button,
      ],
    );
  }

  Widget _button(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeSessionProvider).value;
    if (active == null && completedSessionId != null) {
      return Row(
        key: const ValueKey('day.done'),
        children: <Widget>[
          Icon(Icons.check_circle, color: FitColors.pine, size: 22),
          const SizedBox(width: FitSpacing.sm),
          Expanded(
            child: Text(
              'Done today',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: FitColors.pine),
            ),
          ),
          OutlinedButton(
            key: const ValueKey('day.viewSession'),
            onPressed: () =>
                context.push(Routes.historyDetail(completedSessionId!)),
            child: const Text('View session'),
          ),
        ],
      );
    }
    if (active != null) {
      final minutes =
          DateTime.now().difference(DateTime.parse(active.startedAt)).inMinutes;
      // Beta 3.8: a session started by mistake can be thrown away here.
      return Row(
        children: <Widget>[
          Expanded(
            child: FilledButton(
              key: const ValueKey('day.resume'),
              onPressed: onStart,
              child: Text('Resume ${active.name} · $minutes min'),
            ),
          ),
          const SizedBox(width: FitSpacing.sm),
          OutlinedButton(
            key: const ValueKey('day.discard'),
            onPressed: () => confirmDiscardSession(context, ref, active),
            child: const Text('Discard'),
          ),
        ],
      );
    }
    if (isRest) {
      return OutlinedButton(
        key: const ValueKey('day.startEmpty'),
        onPressed: onStart,
        style: OutlinedButton.styleFrom(
          foregroundColor: FitColors.ink,
          side: BorderSide(color: FitColors.ink),
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
