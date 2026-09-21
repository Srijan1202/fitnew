import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/hairline_section.dart';
import '../../domain/entities/workout.dart';
import '../controllers/workout_providers.dart';

/// TODAY's one training panel (Phase 5; the ranked-actions engine is
/// Phase 11): today's session by name with Start, Resume, or Done.
class TodaySessionPanel extends ConsumerWidget {
  const TodaySessionPanel({super.key});

  Future<void> _start(
    BuildContext context,
    WidgetRef ref,
    TodayResponse? day,
  ) async {
    final repo = ref.read(workoutRepositoryProvider);
    final active = await repo.activeSession();
    if (!context.mounted) return;
    if (active != null) {
      await context.push(Routes.session(active.clientSessionId));
      return;
    }
    final session = await repo.startSession(day: day);
    if (!context.mounted) return;
    await context.push(Routes.session(session.clientSessionId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final active = ref.watch(activeSessionProvider).value;
    final today = ref.watch(todayProvider);

    Widget body;
    if (active != null) {
      final minutes =
          DateTime.now().difference(DateTime.parse(active.startedAt)).inMinutes;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(active.name, style: textTheme.displaySmall),
          const SizedBox(height: FitSpacing.xs),
          Text(
            'In progress · $minutes min · ${active.workingSetsLogged} sets logged',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: FitSpacing.md),
          FilledButton(
            key: const ValueKey('today.resume'),
            onPressed: () =>
                context.push(Routes.session(active.clientSessionId)),
            child: const Text('Resume'),
          ),
        ],
      );
    } else {
      body = today.when(
        loading: () =>
            Container(width: 160, height: 28, color: FitColors.paper2),
        error: (_, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Could not load today. Your plan still works offline.',
              style: textTheme.bodyMedium?.copyWith(color: FitColors.amber),
            ),
            const SizedBox(height: FitSpacing.md),
            OutlinedButton(
              key: const ValueKey('today.retry'),
              onPressed: () => ref.invalidate(todayProvider),
              child: const Text('Try again'),
            ),
          ],
        ),
        data: (t) {
          if (t.completedSessionId != null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  t.sessionName ?? 'Session',
                  style:
                      textTheme.displaySmall?.copyWith(color: FitColors.pine),
                ),
                const SizedBox(height: FitSpacing.xs),
                Text(
                  'Done for today.',
                  key: const ValueKey('today.done'),
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: FitSpacing.md),
                OutlinedButton(
                  key: const ValueKey('today.summary'),
                  onPressed: () =>
                      context.push(Routes.historyDetail(t.completedSessionId!)),
                  child: const Text('See the summary'),
                ),
              ],
            );
          }
          if (t.isRest) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Rest', style: textTheme.displaySmall),
                const SizedBox(height: FitSpacing.xs),
                Text(
                  t.programId == null
                      ? 'No programme yet. Build one under Training, or log something anyway.'
                      : 'Nothing planned. Recovery is part of the programme.',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: FitSpacing.md),
                OutlinedButton(
                  key: const ValueKey('today.startEmpty'),
                  onPressed: () => _start(context, ref, null),
                  child: const Text('Start empty session'),
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(t.sessionName ?? 'Session', style: textTheme.displaySmall),
              const SizedBox(height: FitSpacing.xs),
              Text(
                '${t.exercises.length} exercises · ${t.exercises.fold<int>(0, (n, x) => n + x.targets.length)} sets',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: FitSpacing.md),
              FilledButton(
                key: const ValueKey('today.start'),
                onPressed: () => _start(context, ref, t),
                child: const Text('Start session'),
              ),
            ],
          );
        },
      );
    }
    return HairlineSection(label: 'Today', child: body);
  }
}
