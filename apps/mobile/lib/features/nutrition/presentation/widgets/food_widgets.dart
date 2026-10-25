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

  /// An exact value is one number; an estimate is "low–high". Beta 3.7: only
  /// where a range is asked for (a food's page, a tapped logged item).
  static String range(double low, double high) =>
      low == high ? number(low) : '${number(low)}–${number(high)}';

  /// Beta 3.7 (ADR-036, owner: "one number, range in details"): the one
  /// number an estimate shows, the middle of its range — whole from 10 up,
  /// one decimal below.
  static double middle(double low, double high) {
    final m = (low + high) / 2;
    return m.abs() >= 10 ? m.roundToDouble() : (m * 10).roundToDouble() / 10;
  }

  /// An exact value is itself ("130"); an estimate is "about 330".
  static String about(double low, double high) =>
      low == high ? number(low) : 'about ${number(middle(low, high))}';

  static String kcal(FoodNutrition n) => '${about(n.kcalLow, n.kcalHigh)} kcal';

  /// "about 520" → "About 520", for the start of a sentence.
  static String capitalised(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  /// What a tap on an estimate shows: "Range 300–360 kcal · 9–11 g protein ·
  /// INDB"; null for exact values.
  static String? rangeLine({
    required double kcalLow,
    required double kcalHigh,
    required double proteinLow,
    required double proteinHigh,
    required FoodSource source,
  }) =>
      kcalLow == kcalHigh && proteinLow == proteinHigh
          ? null
          : 'Range ${range(kcalLow, kcalHigh)} kcal · '
              '${range(proteinLow, proteinHigh)} g protein · ${source.label}';

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

/// The one-word provenance a row carries: USDA, IFCT, INDB, CoFID, Estimate,
/// Yours.
/// Colour follows the token meanings: pine for measured, amber for estimated.
class FoodSourceBadge extends StatelessWidget {
  const FoodSourceBadge({required this.food, super.key});

  final Food food;

  Color get _colour => switch (food.source) {
        FoodSource.estimated => FitColors.amber,
        FoodSource.usda ||
        FoodSource.ifct ||
        FoodSource.indb ||
        FoodSource.cofid =>
          food.isVerified ? FitColors.pine : FitColors.ink60,
        FoodSource.user || FoodSource.userCorrected => FitColors.ink60,
      };

  /// Beta 3.2 (ADR-032): someone else's shared food says Community; your own
  /// shared food says so too.
  String get _badge => food.community && !food.isCustom
      ? 'Community'
      : food.community
          ? 'Yours · shared'
          : food.source.badge;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: _colour,
        );
    return Semantics(
      label: food.community && !food.isCustom
          ? 'Community food, unverified'
          : 'Source: ${food.source.label}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(color: _colour),
          borderRadius: BorderRadius.all(FitRadius.small),
        ),
        child: Text(_badge.toUpperCase(), style: style),
      ),
    );
  }
}

/// One nutrition row as a small table: energy, protein, carbs, fat, fibre.
/// The food's page is where the ranges show (beta 3.7); unknown fibre says
/// so.
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
        line('Energy', '${FoodFormat.range(r.kcalLow, r.kcalHigh)} kcal'),
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

/// UK CoFID's licence (OGL v3.0) asks for this statement wherever it is used.
class CofidAttribution extends StatelessWidget {
  const CofidAttribution({super.key});

  static const text = "Includes McCance and Widdowson's Composition of Foods "
      'Integrated Dataset 2021 (Public Health England). Crown copyright. '
      'Contains public sector information licensed under the Open '
      'Government Licence v3.0.';

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      key: const ValueKey('cofid.attribution'),
      style: Theme.of(context)
          .textTheme
          .bodyMedium
          ?.copyWith(color: FitColors.ink60),
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
