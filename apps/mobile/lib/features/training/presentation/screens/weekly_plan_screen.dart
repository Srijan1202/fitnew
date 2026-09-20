import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/hairline_section.dart';
import '../../../auth/presentation/widgets/auth_form_field.dart';
import '../../domain/entities/program.dart';
import '../controllers/program_controller.dart';

/// The week (§31 Phase 4 "weekly plan"). Seven rows, Monday first, rest days
/// included; every planned exercise shows the engine's prescription and,
/// on tap, its reason. The programme is the server's; this screen offers
/// the three ways to change it: regenerate, edit a day, build your own.
class WeeklyPlanScreen extends ConsumerStatefulWidget {
  const WeeklyPlanScreen({super.key});

  @override
  ConsumerState<WeeklyPlanScreen> createState() => _WeeklyPlanScreenState();
}

class _WeeklyPlanScreenState extends ConsumerState<WeeklyPlanScreen> {
  bool _busy = false;
  Failure? _failure;

  Future<void> _generate() async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    final failure =
        await ref.read(programControllerProvider.notifier).generate();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failure = failure;
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(programControllerProvider);
    return Scaffold(
      appBar: AppBar(leading: BackButton(onPressed: () => context.pop())),
      body: SafeArea(
        child: async.when(
          loading: () => const _PlanSkeleton(),
          error: (e, _) => _Failed(
            failure: e is Failure ? e : const Unknown(),
            onRetry: () => ref.invalidate(programControllerProvider),
          ),
          data: (program) => program == null
              ? _NoProgram(
                  busy: _busy,
                  failure: _failure,
                  onGenerate: _generate,
                  onBuild: () => context.push(Routes.planBuilder),
                )
              : _Plan(
                  program: program,
                  busy: _busy,
                  failure: _failure,
                  onRegenerate: _generate,
                  onBuild: () => context.push(Routes.planBuilder),
                ),
        ),
      ),
    );
  }
}

class _NoProgram extends StatelessWidget {
  const _NoProgram({
    required this.busy,
    required this.failure,
    required this.onGenerate,
    required this.onBuild,
  });

  final bool busy;
  final Failure? failure;
  final VoidCallback onGenerate;
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(FitSpacing.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('YOUR PLAN', style: textTheme.labelSmall),
          const SizedBox(height: FitSpacing.xs),
          Text('No programme yet', style: textTheme.displaySmall),
          const SizedBox(height: FitSpacing.sm),
          Text(
            'FitOS builds one from your goal, experience, days, equipment and any limitations — with a reason for every exercise. Or build your own.',
            style: textTheme.bodyMedium,
          ),
          if (failure != null) ...<Widget>[
            const SizedBox(height: FitSpacing.md),
            AuthFeedback.error(failure!.message),
          ],
          const SizedBox(height: FitSpacing.lg),
          FilledButton(
            key: const ValueKey('plan.generate'),
            onPressed: busy ? null : onGenerate,
            child: busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: FitColors.paper,
                    ),
                  )
                : const Text('Generate my programme'),
          ),
          const SizedBox(height: FitSpacing.md),
          OutlinedButton(
            key: const ValueKey('plan.build'),
            onPressed: busy ? null : onBuild,
            child: const Text('Build my own'),
          ),
        ],
      ),
    );
  }
}

class _Plan extends StatelessWidget {
  const _Plan({
    required this.program,
    required this.busy,
    required this.failure,
    required this.onRegenerate,
    required this.onBuild,
  });

  final Program program;
  final bool busy;
  final Failure? failure;
  final VoidCallback onRegenerate;
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final p = program;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        FitSpacing.screen,
        FitSpacing.sm,
        FitSpacing.screen,
        FitSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${p.splitType.label} · WEEK ${p.mesocycleWeek} · ${p.daysPerWeek} DAYS'
                .toUpperCase(),
            style: textTheme.labelSmall,
          ),
          const SizedBox(height: FitSpacing.xs),
          Text(p.name, style: textTheme.displaySmall),
          if (p.shortfalls.isNotEmpty) ...<Widget>[
            const SizedBox(height: FitSpacing.md),
            for (final s in p.shortfalls)
              Padding(
                padding: const EdgeInsets.only(bottom: FitSpacing.xs),
                child: Text(
                  s.detail,
                  style: textTheme.bodyMedium?.copyWith(color: FitColors.amber),
                ),
              ),
          ],
          if (failure != null) ...<Widget>[
            const SizedBox(height: FitSpacing.md),
            AuthFeedback.error(failure!.message),
          ],
          const SizedBox(height: FitSpacing.lg),
          for (final day in p.days) _DayBlock(day: day),
          if (p.rationale.isNotEmpty) ...<Widget>[
            const SizedBox(height: FitSpacing.lg),
            HairlineSection(
              label: 'Why this plan',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final line in p.rationale)
                    Padding(
                      padding: const EdgeInsets.only(bottom: FitSpacing.xs),
                      child: Text(line, style: textTheme.bodyMedium),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: FitSpacing.xl),
          Row(
            children: <Widget>[
              OutlinedButton(
                key: const ValueKey('plan.regenerate'),
                onPressed: busy ? null : onRegenerate,
                child: Text(busy ? 'Working…' : 'Regenerate'),
              ),
              const SizedBox(width: FitSpacing.md),
              OutlinedButton(
                key: const ValueKey('plan.build'),
                onPressed: busy ? null : onBuild,
                child: const Text('Build my own'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayBlock extends StatelessWidget {
  const _DayBlock({required this.day});

  final ProgramDay day;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final label = kWeekdayLabels[day.dayOfWeek - 1].toUpperCase();
    if (day.isRest) {
      return Padding(
        padding: const EdgeInsets.only(bottom: FitSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Divider(color: FitColors.rule, height: 1),
            const SizedBox(height: FitSpacing.sm),
            Text(
              '$label · REST',
              style: textTheme.labelSmall?.copyWith(color: FitColors.ink35),
            ),
            const SizedBox(height: FitSpacing.sm),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: FitSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Divider(color: FitColors.rule, height: 1),
          const SizedBox(height: FitSpacing.sm),
          InkWell(
            key: ValueKey('plan.day.${day.dayOfWeek}'),
            onTap: () => context.push(Routes.planDay(day.id)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                Expanded(
                  child: Text(
                    '$label · ${day.sessionName.toUpperCase()}',
                    style: textTheme.labelSmall,
                  ),
                ),
                Text(
                  '~${day.estimatedMinutes} min · edit',
                  style: textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: FitSpacing.sm),
          for (final x in day.exercises)
            InkWell(
              key: ValueKey('plan.exercise.${x.id}'),
              onTap: () => context.push(Routes.exerciseDetail(x.exerciseId)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: FitSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(x.name, style: textTheme.titleMedium),
                    ),
                    const SizedBox(width: FitSpacing.md),
                    Text(x.prescription, style: textTheme.bodyLarge),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlanSkeleton extends StatelessWidget {
  const _PlanSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(FitSpacing.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(width: 160, height: 11, color: FitColors.paper2),
          const SizedBox(height: FitSpacing.sm),
          Container(width: 220, height: 28, color: FitColors.paper2),
          const SizedBox(height: FitSpacing.lg),
          for (var i = 0; i < 4; i++) ...<Widget>[
            const Divider(color: FitColors.rule, height: 1),
            const SizedBox(height: FitSpacing.sm),
            Container(width: 120, height: 11, color: FitColors.paper2),
            const SizedBox(height: FitSpacing.sm),
            Container(width: 240, height: 16, color: FitColors.paper2),
            const SizedBox(height: FitSpacing.md),
          ],
        ],
      ),
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
