import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../domain/entities/food.dart';

/// Formatting only. Every value is the server's; nothing here rounds a
/// range inward, fills in a missing number, or turns "not reported" into 0.
abstract final class FoodFormat {
  /// 130 → "130", 2.5 → "2.5", 0.45 → "0.5". One decimal at most.
  static String number(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    final fixed = v.toStringAsFixed(1);
    return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
  }

  /// An exact value is one number; an estimate is "low–high".
  static String range(double low, double high) =>
      low == high ? number(low) : '${number(low)}–${number(high)}';

  static String kcal(FoodNutrition n) => '${range(n.kcalLow, n.kcalHigh)} kcal';

  /// "Per 100 g", "Per 1 katori (150 g)", "Per 1 bar".
  static String serving(FoodNutrition n) {
    if (n.basis == NutritionBasis.per100g) return 'Per 100 g';
    final grams = n.servingGrams;
    final showGrams = grams != null && !n.servingLabel.contains('(');
    return 'Per ${n.servingLabel}${showGrams ? ' (${number(grams)} g)' : ''}';
  }

  /// The short serving a result row shows: "100 g", "1 katori".
  static String servingShort(FoodNutrition n) =>
      n.basis == NutritionBasis.per100g ? '100 g' : n.servingLabel;
}

/// The one-word provenance a row carries: USDA (verified), Estimate, Yours.
/// Colour follows the token meanings: pine for measured, amber for estimated.
class FoodSourceBadge extends StatelessWidget {
  const FoodSourceBadge({required this.food, super.key});

  final Food food;

  Color get _colour => switch (food.source) {
        FoodSource.estimated => FitColors.amber,
        FoodSource.usda ||
        FoodSource.ifct ||
        FoodSource.indb =>
          food.isVerified ? FitColors.pine : FitColors.ink60,
        FoodSource.user || FoodSource.userCorrected => FitColors.ink60,
      };

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: _colour,
        );
    return Semantics(
      label: 'Source: ${food.source.label}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(color: _colour),
          borderRadius: const BorderRadius.all(FitRadius.small),
        ),
        child: Text(food.source.badge.toUpperCase(), style: style),
      ),
    );
  }
}

/// One nutrition row as a small table: energy, protein, carbs, fat, fibre.
/// Ranges stay ranges; unknown fibre says so.
class NutritionTable extends StatelessWidget {
  const NutritionTable({required this.row, super.key});

  final FoodNutrition row;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    Widget line(String name, String value, {Key? key, Color? colour}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: FitSpacing.xs),
          child: Row(
            children: <Widget>[
              Expanded(child: Text(name, style: textTheme.bodyLarge)),
              Text(
                value,
                key: key,
                style: textTheme.titleMedium?.copyWith(color: colour),
              ),
            ],
          ),
        );
    final r = row;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        line('Energy', FoodFormat.kcal(r)),
        line('Protein', '${FoodFormat.range(r.proteinLow, r.proteinHigh)} g'),
        line('Carbohydrate', '${FoodFormat.range(r.carbLow, r.carbHigh)} g'),
        line('Fat', '${FoodFormat.range(r.fatLow, r.fatHigh)} g'),
        if (r.fibreKnown)
          line('Fibre', '${FoodFormat.range(r.fibreLow!, r.fibreHigh!)} g')
        else
          line(
            'Fibre',
            'Not known',
            key: const ValueKey('fibre.unknown'),
            colour: FitColors.ink60,
          ),
      ],
    );
  }
}

/// USDA's data is public domain; FITOS names it wherever it is used.
class UsdaAttribution extends StatelessWidget {
  const UsdaAttribution({super.key});

  static const text =
      'Includes data from USDA FoodData Central (fdc.nal.usda.gov), '
      'U.S. Department of Agriculture, Agricultural Research Service — '
      'public domain (CC0 1.0).';

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      key: const ValueKey('usda.attribution'),
      style: Theme.of(context)
          .textTheme
          .bodyMedium
          ?.copyWith(color: FitColors.ink60),
    );
  }
}
