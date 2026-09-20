import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../domain/entities/profile.dart';

/// Daily targets as the engine computed them. Anton for the numbers (§6.3),
/// Archivo for everything else; every figure carries a screen-reader label
/// because a number without one is meaningless aurally (§6.8).
///
/// These values are `calculated` (§6.5): shown in full ink, with the "why"
/// rendered beside them by the caller. Nothing here rounds, converts or
/// re-derives — the server's integers are shown as sent.
class TargetsDisplay extends StatelessWidget {
  const TargetsDisplay({required this.targets, super.key});

  final NutritionTargets targets;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // The calorie target is the hero: large, alone, first.
        Semantics(
          label: '${targets.kcal} kilocalories per day',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                '${targets.kcal}',
                style: textTheme.displayLarge,
                textScaler:
                    MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
              ),
              const SizedBox(width: FitSpacing.sm),
              Text('kcal / day', style: textTheme.titleMedium),
            ],
          ),
        ),
        const SizedBox(height: FitSpacing.md),
        Row(
          children: <Widget>[
            _Macro(label: 'Protein', grams: targets.proteinG),
            const SizedBox(width: FitSpacing.lg),
            _Macro(label: 'Carbs', grams: targets.carbG),
            const SizedBox(width: FitSpacing.lg),
            _Macro(label: 'Fat', grams: targets.fatG),
            const SizedBox(width: FitSpacing.lg),
            _Macro(label: 'Fibre', grams: targets.fiberG),
          ],
        ),
      ],
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro({required this.label, required this.grams});

  final String label;
  final int grams;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      label: '$label $grams grams',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('$grams', style: textTheme.displaySmall),
          Text('$label g', style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// Layout-matching skeleton for while targets are being computed (§6.6: no
/// spinner over 400ms of content).
class TargetsSkeleton extends StatelessWidget {
  const TargetsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(width: 200, height: 72, color: FitColors.paper2),
        const SizedBox(height: FitSpacing.md),
        Row(
          children: <Widget>[
            for (var i = 0; i < 4; i++) ...<Widget>[
              Container(width: 56, height: 40, color: FitColors.paper2),
              const SizedBox(width: FitSpacing.lg),
            ],
          ],
        ),
      ],
    );
  }
}
