import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/navigation.dart';
import '../../../../core/routing/router.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/hairline_section.dart';
import '../../../health/presentation/controllers/health_providers.dart';
import '../../../home/presentation/controllers/home_providers.dart';
import '../../domain/entities/food.dart';
import '../../domain/entities/food_log.dart';
import '../controllers/food_log_providers.dart';
import '../controllers/food_logger.dart';
import '../widgets/food_widgets.dart';
import '../widgets/portion_sheet.dart';

/// One food: what it contains, per 100 g and per serving, and where every
/// number comes from. Estimates are ranges and say so; a verified USDA
/// record says which record; your own food says it came from your label.
/// Phase 8: "Log this food" opens the portion step and logs it to today
/// ("Log it now" right after the user created it from a label).
///
/// The food arrives with the navigation (there is no single-food endpoint in
/// Phase 7); opened without one — a restored route — it says so and offers
/// the library instead of guessing.
/// What the detail route carries: the food, and whether it was just made.
class FoodDetailArgs {
  const FoodDetailArgs({required this.food, this.justCreated = false});
  final Food food;
  final bool justCreated;
}

class FoodDetailScreen extends ConsumerWidget {
  const FoodDetailScreen({
    required this.food,
    this.justCreated = false,
    super.key,
  });

  final Food? food;

  /// Opened right after the custom-food form saved it (owner item 27).
  final bool justCreated;

  Future<void> _log(BuildContext context, WidgetRef ref, Food food) async {
    final choice = await showPortionSheet(
      context,
      food: food,
      slot: MealSlot.forHour(ref.read(localHourProvider)),
    );
    if (choice == null || !context.mounted) return;
    final today = ref.read(localTodayProvider);
    await ref.read(foodLoggerProvider).logFood(
          food,
          choice.row,
          choice.portion,
          asGrams: choice.asGrams,
          target: LogTarget(date: today, slot: choice.slot),
        );
    if (!context.mounted) return;
    ref.read(eatDateProvider.notifier).toToday();
    context.go(Routes.nutrition);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final food = this.food;
    return Scaffold(
      appBar: AppBar(leading: BackButton(onPressed: () => context.popOrHome())),
      body: SafeArea(
        child: food == null
            ? const _Missing()
            : _Detail(
                food: food,
                justCreated: justCreated,
                onLog: () => _log(context, ref, food),
              ),
      ),
    );
  }
}

class _Missing extends StatelessWidget {
  const _Missing();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(FitSpacing.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Open this food from the library', style: textTheme.titleLarge),
          const SizedBox(height: FitSpacing.md),
          FilledButton(
            onPressed: () => context.go(Routes.nutrition),
            child: const Text('Food library'),
          ),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.food,
    required this.justCreated,
    required this.onLog,
  });

  final Food food;
  final bool justCreated;
  final VoidCallback onLog;

  String get _explainer => switch (food.source) {
        FoodSource.estimated =>
          'A FITOS estimate, shown as a range: the real value depends on the '
              'recipe, the oil and the portion. Not a measured value.',
        FoodSource.usda || FoodSource.ifct || FoodSource.indb => food.isVerified
            ? 'Measured values, exactly as ${food.source.label} publishes them.'
            : 'Values from ${food.source.label}.',
        FoodSource.user => 'From the label you entered. Only you can see it; '
            'FITOS has not verified it.',
        FoodSource.userCorrected =>
          'Your correction. Only you can see it; FITOS has not verified it.',
      };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final confidence = food.nutrition.first.confidence;
    // USDA records, and estimates composed from USDA ingredients, credit USDA.
    final creditsUsda = food.source == FoodSource.usda ||
        (food.sourceRef?.contains('USDA') ?? false);
    return ListView(
      key: const ValueKey('food.detail'),
      padding: const EdgeInsets.fromLTRB(
        FitSpacing.screen,
        FitSpacing.sm,
        FitSpacing.screen,
        FitSpacing.xl,
      ),
      children: <Widget>[
        Row(
          children: <Widget>[
            FoodSourceBadge(food: food),
            const SizedBox(width: FitSpacing.sm),
            Flexible(
              child: Text(
                food.isVerified
                    ? 'Verified · ${confidence.label}'
                    : confidence.label,
                key: const ValueKey('food.confidence'),
                style: textTheme.labelSmall?.copyWith(color: FitColors.ink60),
              ),
            ),
          ],
        ),
        const SizedBox(height: FitSpacing.sm),
        Text(food.name, style: textTheme.displaySmall),
        if (food.brand != null) ...<Widget>[
          const SizedBox(height: FitSpacing.xs),
          Text(food.brand!, style: textTheme.bodyLarge),
        ],
        const SizedBox(height: FitSpacing.sm),
        Text(
          _explainer,
          key: const ValueKey('food.explainer'),
          style: textTheme.bodyMedium?.copyWith(
            color: food.isEstimate ? FitColors.amber : FitColors.ink60,
          ),
        ),
        const SizedBox(height: FitSpacing.md),
        if (justCreated)
          Text(
            'Saved to your foods.',
            key: const ValueKey('food.saved'),
            style: textTheme.bodyMedium?.copyWith(color: FitColors.pine),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            key: const ValueKey('food.log'),
            onPressed: onLog,
            icon: const Icon(Icons.add),
            label: Text(justCreated ? 'Log it now' : 'Log this food'),
          ),
        ),
        const SizedBox(height: FitSpacing.lg),
        for (final row in food.nutrition) ...<Widget>[
          HairlineSection(
            label: FoodFormat.serving(row),
            child: NutritionTable(row: row),
          ),
          const SizedBox(height: FitSpacing.lg),
        ],
        if (food.aliases.isNotEmpty) ...<Widget>[
          HairlineSection(
            label: 'Also called',
            child: Text(food.aliases.join(', '), style: textTheme.bodyLarge),
          ),
          const SizedBox(height: FitSpacing.lg),
        ],
        HairlineSection(
          label: 'Source',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(food.source.label, style: textTheme.titleMedium),
              if (food.sourceRef != null) ...<Widget>[
                const SizedBox(height: FitSpacing.xs),
                Text(
                  food.sourceRef!,
                  key: const ValueKey('food.sourceRef'),
                  style: textTheme.bodyMedium?.copyWith(color: FitColors.ink60),
                ),
              ],
              if (creditsUsda) ...<Widget>[
                const SizedBox(height: FitSpacing.sm),
                const UsdaAttribution(),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
