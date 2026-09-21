import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/routing/router.dart';
import '../../../../core/routing/navigation.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/hairline_section.dart';
import '../../../auth/presentation/widgets/auth_form_field.dart';
import '../../domain/entities/exercise.dart';
import '../controllers/exercise_providers.dart';

/// One exercise: what it trains, what you need, how to do it, what to do
/// instead. Instructions are shown as the library has them — never
/// paraphrased (§7.3).
class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(exerciseDetailProvider(id));
    return Scaffold(
      appBar: AppBar(leading: BackButton(onPressed: () => context.popOrHome())),
      body: SafeArea(
        child: async.when(
          loading: () => const _DetailSkeleton(),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(FitSpacing.screen),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AuthFeedback.error(
                  (e is Failure ? e : const Unknown()).message,
                ),
                const SizedBox(height: FitSpacing.md),
                FilledButton(
                  onPressed: () => ref.invalidate(exerciseDetailProvider(id)),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
          data: (d) => _Detail(detail: d),
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.detail});

  final ExerciseDetail detail;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final d = detail;
    final primary = d.muscles
        .where((m) => m.role == MuscleRole.primary)
        .map((m) => m.muscleGroup.label)
        .join(', ');
    final secondary = d.muscles
        .where((m) => m.role == MuscleRole.secondary)
        .map((m) => m.muscleGroup.label)
        .join(', ');

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
            '${d.movementPattern.label} · ${d.difficulty.label}'
                    '${d.isUnilateral ? ' · one side at a time' : ''}'
                .toUpperCase(),
            style: textTheme.labelSmall,
          ),
          const SizedBox(height: FitSpacing.xs),
          Text(d.name, style: textTheme.displaySmall),
          const SizedBox(height: FitSpacing.lg),
          _Fact(label: 'Works', value: primary),
          if (secondary.isNotEmpty) _Fact(label: 'Also', value: secondary),
          _Fact(
            label: 'Needs',
            value: d.equipment.map((e) => e.label).join(' + '),
          ),
          _Fact(
            label: 'Load step',
            value:
                '${_kg(d.defaultIncrementKg)} kg when you clear the top of the rep range',
          ),
          if (d.contraindications.isNotEmpty)
            _Fact(
              label: 'Skip if',
              value:
                  '${d.contraindications.map((b) => b.label.toLowerCase()).join(', ')} is bothering you',
              emphasis: true,
            ),
          const SizedBox(height: FitSpacing.lg),
          HairlineSection(
            label: 'How to do it',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (var i = 0; i < d.instructions.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: FitSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(
                          width: 28,
                          child: Text('${i + 1}', style: textTheme.titleMedium),
                        ),
                        Expanded(
                          child: Text(
                            d.instructions[i],
                            style: textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (d.alternatives.isNotEmpty) ...<Widget>[
            const SizedBox(height: FitSpacing.lg),
            HairlineSection(
              label: 'Instead, try',
              child: Column(
                children: <Widget>[
                  for (final a in d.alternatives) ...<Widget>[
                    InkWell(
                      key: ValueKey('alternative.${a.slug}'),
                      onTap: () => context.push(Routes.exerciseDetail(a.id)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: FitSpacing.sm,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(a.name, style: textTheme.titleMedium),
                                  Text(
                                    '${a.reason.label} · ${a.equipment.map((e) => e.label).join(' + ')}',
                                    style: textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward,
                              size: 18,
                              color: FitColors.ink60,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(color: FitColors.rule, height: 1),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _kg(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.label,
    required this.value,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: FitSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 88,
            child: Text(label, style: textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodyLarge?.copyWith(
                // Amber is the "caution" meaning (§6.2); the only colour here.
                color: emphasis ? FitColors.amber : FitColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(FitSpacing.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(width: 120, height: 11, color: FitColors.paper2),
          const SizedBox(height: FitSpacing.sm),
          Container(width: 240, height: 28, color: FitColors.paper2),
          const SizedBox(height: FitSpacing.lg),
          for (final w in const [200.0, 160.0, 220.0])
            Padding(
              padding: const EdgeInsets.only(bottom: FitSpacing.sm),
              child: Container(width: w, height: 14, color: FitColors.paper2),
            ),
        ],
      ),
    );
  }
}
