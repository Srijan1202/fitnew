import 'package:flutter/material.dart';

import '../../../../core/routing/navigation.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/fit_glass.dart';
import '../../domain/demo/exercise_demos.dart';
import '../widgets/exercise_demo_view.dart';

/// Beta 5.1 (owner): every exercise demo on one page, to check them all —
/// the 30 lifts, then the variants that share one with the line that says
/// what differs. Each plays as on its exercise's page.
class ExerciseDemosScreen extends StatelessWidget {
  const ExerciseDemosScreen({super.key});

  /// "barbell-back-squat" → "Barbell back squat".
  static String nameOf(String slug) {
    final s = slug.replaceAll('-', ' ');
    return s[0].toUpperCase() + s.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final lifts = exerciseDemos.keys.toList()..sort();
    final variants = demoVariants.keys.toList()..sort();
    Widget tile(String slug) {
      final m = demoFor(slug)!;
      return FitBlock(
        key: ValueKey('demos.$slug'),
        padding: const EdgeInsets.all(FitSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(nameOf(slug), style: t.titleMedium),
            const SizedBox(height: FitSpacing.sm),
            ExerciseDemoView(demo: m.demo, name: nameOf(slug), note: m.note),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.popOrHome()),
        title: Text('EXERCISE DEMOS', style: t.labelSmall),
        centerTitle: false,
      ),
      body: ListView(
        key: const ValueKey('demos.list'),
        padding: const EdgeInsets.fromLTRB(
          FitSpacing.screen,
          FitSpacing.sm,
          FitSpacing.screen,
          FitSpacing.xl,
        ),
        children: [
          Text(
            '${lifts.length} lifts and ${variants.length} variants. Each '
            'plays three times; tap it to play again.',
            style: t.bodyMedium,
          ),
          for (final slug in lifts) ...[
            const SizedBox(height: FitSpacing.md),
            tile(slug),
          ],
          const SizedBox(height: FitSpacing.lg),
          Text('VARIANTS', style: t.labelSmall),
          for (final slug in variants) ...[
            const SizedBox(height: FitSpacing.md),
            tile(slug),
          ],
        ],
      ),
    );
  }
}
