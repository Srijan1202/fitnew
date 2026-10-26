import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tokens.dart';
import '../../domain/entities/workout.dart';
import '../controllers/rest_timer.dart';
import '../controllers/workout_providers.dart';

/// Beta 3.8 (tester feedback: "only option to resume"): Discard next to
/// every Resume, and in the session's ⋯ menu. Asks first. A session with
/// nothing logged is deleted by the server, so a start by mistake leaves no
/// trace; one with sets stays in History as abandoned. True when discarded.
Future<bool> confirmDiscardSession(
  BuildContext context,
  WidgetRef ref,
  WorkoutSession session,
) async {
  final sets = session.setsLogged;
  final yes = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const ValueKey('session.discard.dialog'),
      backgroundColor: FitColors.paper,
      title: const Text('Discard this session?'),
      content: Text(
        sets == 0
            ? 'Nothing is logged in ${session.name} yet, so it is removed completely.'
            : '${session.name} stays in your history as discarded, with its '
                '${sets == 1 ? '1 set' : '$sets sets'}, and never counts toward a record.',
      ),
      actions: <Widget>[
        TextButton(
          key: const ValueKey('session.discard.cancel'),
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Keep it'),
        ),
        FilledButton(
          key: const ValueKey('session.discard.confirm'),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Discard'),
        ),
      ],
    ),
  );
  if (yes != true) return false;
  ref.read(restTimerProvider.notifier).skip();
  await ref.read(workoutRepositoryProvider).abandon(session.clientSessionId);
  ref
    ..invalidate(todayProvider)
    ..invalidate(dayProvider)
    ..invalidate(historyProvider);
  return true;
}
