import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/hairline_section.dart';
import '../../domain/entities/workout.dart';
import '../controllers/workout_providers.dart';
import '../widgets/rest_bar.dart';
import '../widgets/sync_pill.dart';

/// After Finish: what the session amounted to. Duration, sets and tonnage
/// are arithmetic over the phone's rows and show at once; hard sets per
/// muscle and records come from the server's summary once it has synced
/// (the numbers are the engine's, not the phone's).
class SessionSummaryScreen extends ConsumerWidget {
  const SessionSummaryScreen({required this.clientSessionId, super.key});

  final String clientSessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider(clientSessionId)).value;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: const <Widget>[SyncPill()],
      ),
      body: SafeArea(
        child: session == null
            ? const SizedBox.shrink()
            : SummaryBody(
                session: session,
                onDone: () => context.go(Routes.plan),
              ),
      ),
    );
  }
}

/// Shared by the post-session screen and history detail.
class SummaryBody extends StatelessWidget {
  const SummaryBody({required this.session, this.onDone, super.key});

  final WorkoutSession session;
  final VoidCallback? onDone;

  static String _kg(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final s = session;
    final started = DateTime.parse(s.startedAt);
    final ended =
        s.completedAt == null ? DateTime.now() : DateTime.parse(s.completedAt!);
    final duration = s.durationSeconds != null
        ? Duration(seconds: s.durationSeconds!)
        : ended.difference(started);
    final sets = [for (final x in s.exercises) ...x.sets];
    final working = sets.where((t) => t.setType == SetType.working).length;
    final tonnage = sets
        .where((t) => t.setType != SetType.warmup && t.weightKg != null)
        .fold<double>(0, (t, x) => t + x.weightKg! * x.reps);
    final summary = s.summary;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        FitSpacing.screen,
        FitSpacing.sm,
        FitSpacing.screen,
        FitSpacing.xl,
      ),
      children: <Widget>[
        Text(
          s.status == SessionStatus.abandoned ? 'DISCARDED' : 'SESSION DONE',
          style: textTheme.labelSmall,
        ),
        const SizedBox(height: FitSpacing.xs),
        Text(
          s.name,
          key: const ValueKey('summary.title'),
          style: textTheme.displayMedium,
        ),
        const SizedBox(height: FitSpacing.lg),
        Row(
          children: <Widget>[
            _Metric(
              label: 'TIME',
              value: formatClock(duration),
              keyName: 'summary.time',
            ),
            _Metric(label: 'SETS', value: '$working', keyName: 'summary.sets'),
            _Metric(
              label: 'KG MOVED',
              value: _kg(tonnage),
              keyName: 'summary.tonnage',
            ),
          ],
        ),
        const SizedBox(height: FitSpacing.lg),
        if (summary != null && summary.prs.isNotEmpty) ...<Widget>[
          HairlineSection(
            label: 'Records',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final pr in summary.prs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: FitSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${pr.exerciseName} · ${pr.prType.label}',
                          key: ValueKey(
                            'summary.pr.${pr.prType.wire}.${pr.exerciseId}',
                          ),
                          style: textTheme.titleMedium
                              ?.copyWith(color: FitColors.pine),
                        ),
                        Text(pr.reason, style: textTheme.bodyMedium),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: FitSpacing.lg),
        ],
        if (summary != null)
          HairlineSection(
            label: 'Hard sets by muscle',
            child: Wrap(
              spacing: FitSpacing.md,
              runSpacing: FitSpacing.xs,
              children: <Widget>[
                for (final e in summary.hardSetsByMuscle.entries
                    .where((e) => e.value > 0))
                  Text(
                    '${e.key} ${e.value % 1 == 0 ? e.value.toInt() : e.value}',
                    style: textTheme.bodyLarge,
                  ),
              ],
            ),
          )
        else
          Text(
            'Records and the muscle breakdown appear once this session has synced.',
            key: const ValueKey('summary.pending'),
            style: textTheme.bodyMedium?.copyWith(color: FitColors.amber),
          ),
        const SizedBox(height: FitSpacing.lg),
        HairlineSection(
          label: 'What you did',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final x in s.exercises)
                Padding(
                  padding: const EdgeInsets.only(bottom: FitSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(x.name, style: textTheme.titleMedium),
                      Text(
                        x.sets.isEmpty
                            ? 'skipped'
                            : x.sets
                                .map(
                                  (t) =>
                                      '${t.weightKg == null ? '—' : _kg(t.weightKg!)}×${t.reps}${t.isPr ? ' ★' : ''}${t.setType == SetType.working ? '' : ' (${t.setType.label.toLowerCase()})'}',
                                )
                                .join('  '),
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (onDone != null) ...<Widget>[
          const SizedBox(height: FitSpacing.xl),
          FilledButton(
            key: const ValueKey('summary.done'),
            onPressed: onDone,
            child: const Text('Done'),
          ),
        ],
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.keyName,
  });

  final String label;
  final String value;
  final String keyName;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: textTheme.labelSmall),
          Text(value, key: ValueKey(keyName), style: textTheme.displaySmall),
        ],
      ),
    );
  }
}
