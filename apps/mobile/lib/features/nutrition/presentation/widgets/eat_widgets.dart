import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../profile/domain/entities/profile.dart';
import '../../domain/entities/food.dart';
import '../../domain/entities/food_log.dart';
import 'food_widgets.dart';

/// Words for the EAT screen. Every number here is the SERVER's (its
/// snapshots, its totals, its "remaining"); these functions only format.
abstract final class EatFormat {
  static String kcal(double low, double high) =>
      '${_grouped(low)}${low == high ? '' : '–${_grouped(high)}'}';

  static String _grouped(double v) {
    final s = FoodFormat.number(v);
    if (s.contains('.') || s.length <= 3) return s;
    final digits = s.replaceAll('-', '');
    final buf = StringBuffer(s.startsWith('-') ? '-' : '');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  static String grams(double low, double high) =>
      '${FoodFormat.range(low, high)} g';

  /// The hero: what is left, or how far over, as the server computed it.
  static ({String value, String caption}) heroKcal(RemainingRange r) {
    final target = _grouped(r.target);
    return switch (r.state) {
      RemainingState.under => (
          value: kcal(r.low, r.high),
          caption: 'kcal left of $target',
        ),
      RemainingState.over => (
          value: kcal(-r.high, -r.low),
          caption: 'kcal over $target',
        ),
      RemainingState.around => (
          value: 'At target',
          caption:
              'Your $target kcal target is inside what you ate — it may be just under or just over.',
        ),
    };
  }

  static String protein(RemainingRange r) {
    final target = FoodFormat.number(r.target);
    return switch (r.state) {
      RemainingState.under =>
        '${grams(r.low, r.high)} protein left of $target g',
      RemainingState.over => '${grams(-r.high, -r.low)} protein over $target g',
      RemainingState.around => 'Protein at your $target g target',
    };
  }

  static String consumedLine(
    String name,
    double low,
    double high,
    int? target,
  ) =>
      target == null
          ? '$name ${grams(low, high)}'
          : '$name ${FoodFormat.range(low, high)} / $target g';

  /// Unknown fibre is never 0 (owner J15): the known part, then what is unknown.
  static String fibre(NutritionTotals t, NutritionTargets? targets) {
    final known = t.itemCount > t.fibreUnknownItems;
    final target = targets == null ? '' : ' / ${targets.fiberG} g';
    final knownText = FoodFormat.range(t.fibreKnownLow, t.fibreKnownHigh);
    if (t.fibreUnknownItems == 0) {
      return targets == null ? 'Fibre $knownText g' : 'Fibre $knownText$target';
    }
    final items =
        t.fibreUnknownItems == 1 ? '1 item' : '${t.fibreUnknownItems} items';
    return known
        ? 'Fibre ${grams(t.fibreKnownLow, t.fibreKnownHigh)} + not known for $items$target'
        : 'Fibre not known ($items)$target';
  }

  static String portion(FoodLogItem i) {
    if (i.isQuickAdd) return 'Quick add';
    final label = i.servingLabel ?? '';
    if (i.basis == NutritionBasis.per100g && i.grams != null) {
      return '${FoodFormat.number(i.grams!)} g';
    }
    final grams = i.grams != null && !label.contains('(')
        ? ' (${FoodFormat.number(i.grams!)} g)'
        : '';
    return '${FoodFormat.number((i.servings * 100).roundToDouble() / 100)} × $label$grams';
  }
}

/// A small, quiet line of state (offline, not synced). Never a modal.
class EatNotice extends StatelessWidget {
  const EatNotice({
    required this.text,
    this.action,
    this.onAction,
    this.colour = FitColors.ink60,
    super.key,
  });

  final String text;
  final String? action;
  final VoidCallback? onAction;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: FitSpacing.xs),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              text,
              style: textTheme.bodyMedium?.copyWith(color: colour),
            ),
          ),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}
