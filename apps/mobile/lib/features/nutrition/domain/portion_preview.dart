import 'entities/food.dart';
import 'entities/food_log.dart';

/// Owner J10 — a DISPLAY-ONLY preview of what a portion will log, shown
/// while choosing it and on an entry that has not reached the server yet.
///
/// It mirrors packages/core (`resolvePortion`, `snapshotNutrition`) and is
/// tested against the same fixture (packages/core/test/fixtures/
/// portion-preview.json), but it is never a total: every total on screen is
/// the server's. What the server stores is computed by the server, at log
/// time, from the food as it is then.
abstract final class PortionPreview {
  static const double servingsMin = 0.1;
  static const double servingsMax = 20;
  static const double gramsMax = 5000;

  /// Grams in one serving of [row] (100 for per-100 g), or null.
  static double? gramsPerServing(FoodNutrition row) =>
      row.basis == NutritionBasis.per100g ? 100 : row.servingGrams;

  static bool _isHundredths(double v) =>
      ((v * 100) - (v * 100).roundToDouble()).abs() < 1e-6;

  static double _round(double v, int decimals, _Mode mode) {
    final f = decimals == 0 ? 1 : 10;
    final scaled = v * f;
    final r = switch (mode) {
      _Mode.nearest => scaled.roundToDouble(),
      _Mode.down => (scaled + 1e-9).floorToDouble(),
      _Mode.up => (scaled - 1e-9).ceilToDouble(),
    };
    return r / f + 0;
  }

  /// The portion as a multiplier on [row], or why it cannot be logged.
  /// Exactly one of [servings] / [grams].
  static PortionResult resolve(
    FoodNutrition row, {
    double? servings,
    double? grams,
  }) {
    final per = gramsPerServing(row);
    if (servings != null) {
      if (!servings.isFinite ||
          servings < servingsMin - 1e-9 ||
          servings > servingsMax + 1e-9) {
        return const PortionResult.invalid(
          'Between 0.1 and 20 servings.',
        );
      }
      if (!_isHundredths(servings)) {
        return const PortionResult.invalid('Use at most two decimals.');
      }
      final s = (servings * 100).roundToDouble() / 100;
      return PortionResult.ok(
        servings: s,
        grams: per == null ? null : (s * per * 10).roundToDouble() / 10,
      );
    }
    final g = grams;
    if (g == null || !g.isFinite || g <= 0 || g > gramsMax) {
      return const PortionResult.invalid('More than 0 and at most 5000 g.');
    }
    if (per == null || per <= 0) {
      return const PortionResult.invalid(
        'This serving has no weight; enter servings instead.',
      );
    }
    return PortionResult.ok(
      servings: g / per,
      grams: (g * 10).roundToDouble() / 10,
    );
  }

  /// [row] × [servings], rounded as the server rounds its snapshot: an
  /// exact row to nearest, an estimate outward.
  static PreviewNutrition scale(FoodNutrition row, double servings) {
    final exact = row.isExact;
    final lo = exact ? _Mode.nearest : _Mode.down;
    final hi = exact ? _Mode.nearest : _Mode.up;
    double l(double v, int d) => _round(v * servings, d, lo);
    double h(double v, int d) => _round(v * servings, d, hi);
    final fibreKnown = row.fibreLow != null && row.fibreHigh != null;
    return PreviewNutrition(
      kcalLow: l(row.kcalLow, 0),
      kcalHigh: h(row.kcalHigh, 0),
      proteinLow: l(row.proteinLow, 1),
      proteinHigh: h(row.proteinHigh, 1),
      carbLow: l(row.carbLow, 1),
      carbHigh: h(row.carbHigh, 1),
      fatLow: l(row.fatLow, 1),
      fatHigh: h(row.fatHigh, 1),
      fibreLow: fibreKnown ? l(row.fibreLow!, 1) : null,
      fibreHigh: fibreKnown ? h(row.fibreHigh!, 1) : null,
    );
  }

  /// A quick add's own numbers, rounded as the server stores them.
  static PreviewNutrition quickAdd(QuickAdd q) {
    double n(double v, int d) => _round(v, d, _Mode.nearest);
    final f = q.fibreG == null ? null : n(q.fibreG!, 1);
    return PreviewNutrition(
      kcalLow: n(q.kcal, 0),
      kcalHigh: n(q.kcal, 0),
      proteinLow: n(q.proteinG, 1),
      proteinHigh: n(q.proteinG, 1),
      carbLow: n(q.carbG, 1),
      carbHigh: n(q.carbG, 1),
      fatLow: n(q.fatG, 1),
      fatHigh: n(q.fatG, 1),
      fibreLow: f,
      fibreHigh: f,
    );
  }

  /// A saved meal as it would log now, or null when an item's food is no
  /// longer available (the server would refuse it too).
  static PreviewNutrition? savedMeal(SavedMeal meal) {
    PreviewNutrition? total;
    for (final item in meal.items) {
      final PreviewNutrition p;
      switch (item) {
        case SavedFoodItem(:final row, :final servings):
          if (row == null) return null;
          p = scale(row, servings);
        case SavedMessItem(:final row, :final servings):
          if (row == null) return null;
          p = scale(row, servings);
        case SavedQuickAddItem():
          p = quickAdd(
            QuickAdd(
              kcal: item.kcal,
              proteinG: item.proteinG,
              carbG: item.carbG,
              fatG: item.fatG,
              fibreG: item.fibreG,
            ),
          );
      }
      total = total == null ? p : total + p;
    }
    return total;
  }
}

enum _Mode { nearest, down, up }

class PortionResult {
  const PortionResult.ok({required this.servings, required this.grams})
      : problem = null;
  const PortionResult.invalid(this.problem)
      : servings = null,
        grams = null;

  final double? servings;
  final double? grams;
  final String? problem;

  bool get ok => problem == null;
}

/// A preview's numbers. Never a total, never stored.
class PreviewNutrition {
  const PreviewNutrition({
    required this.kcalLow,
    required this.kcalHigh,
    required this.proteinLow,
    required this.proteinHigh,
    required this.carbLow,
    required this.carbHigh,
    required this.fatLow,
    required this.fatHigh,
    required this.fibreLow,
    required this.fibreHigh,
  });

  final double kcalLow;
  final double kcalHigh;
  final double proteinLow;
  final double proteinHigh;
  final double carbLow;
  final double carbHigh;
  final double fatLow;
  final double fatHigh;
  final double? fibreLow;
  final double? fibreHigh;

  /// For a multi-item preview (a saved meal). Unknown fibre stays unknown.
  PreviewNutrition operator +(PreviewNutrition o) {
    double r(double v) => (v * 10).roundToDouble() / 10;
    final fibre = fibreLow == null || o.fibreLow == null;
    return PreviewNutrition(
      kcalLow: kcalLow + o.kcalLow,
      kcalHigh: kcalHigh + o.kcalHigh,
      proteinLow: r(proteinLow + o.proteinLow),
      proteinHigh: r(proteinHigh + o.proteinHigh),
      carbLow: r(carbLow + o.carbLow),
      carbHigh: r(carbHigh + o.carbHigh),
      fatLow: r(fatLow + o.fatLow),
      fatHigh: r(fatHigh + o.fatHigh),
      fibreLow: fibre ? null : r(fibreLow! + o.fibreLow!),
      fibreHigh: fibre ? null : r(fibreHigh! + o.fibreHigh!),
    );
  }

  Map<String, double?> toMap() => <String, double?>{
        'kcalLow': kcalLow,
        'kcalHigh': kcalHigh,
        'proteinLow': proteinLow,
        'proteinHigh': proteinHigh,
        'carbLow': carbLow,
        'carbHigh': carbHigh,
        'fatLow': fatLow,
        'fatHigh': fatHigh,
        'fibreLow': fibreLow,
        'fibreHigh': fibreHigh,
      };

  static PreviewNutrition fromMap(Map<String, dynamic> m) {
    double d(String k) => (m[k] as num).toDouble();
    double? dn(String k) => (m[k] as num?)?.toDouble();
    return PreviewNutrition(
      kcalLow: d('kcalLow'),
      kcalHigh: d('kcalHigh'),
      proteinLow: d('proteinLow'),
      proteinHigh: d('proteinHigh'),
      carbLow: d('carbLow'),
      carbHigh: d('carbHigh'),
      fatLow: d('fatLow'),
      fatHigh: d('fatHigh'),
      fibreLow: dn('fibreLow'),
      fibreHigh: dn('fibreHigh'),
    );
  }
}
