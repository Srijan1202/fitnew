import '../../../nutrition/presentation/widgets/food_widgets.dart';
import '../../../profile/domain/entities/vocabulary.dart';
import '../../domain/mess.dart';
import '../../domain/recommendation.dart';

/// Words for the Phase 10 reason codes. The server sends codes and numbers;
/// this is the only place they become sentences, so every wording is
/// deterministic and testable. Numbers are the server's, only formatted.
abstract final class ReasonText {
  static String _n(num? v) => v == null ? '?' : FoodFormat.number(v.toDouble());

  static String _allergen(String? wire) =>
      Allergen.values
          .where((a) => a.wire == wire)
          .firstOrNull
          ?.label
          .toLowerCase() ??
      wire ??
      '';

  static String _goal(String? wire) => switch (wire) {
        'muscle-gain' => 'muscle gain',
        'fat-loss' => 'fat loss',
        'recomposition' => 'recomposition',
        'strength' => 'strength',
        'maintenance' => 'maintenance',
        _ => 'your goal',
      };

  /// A plate reason. [names] maps dish slugs to names (from the plate).
  static String plate(Reason r, Map<String, String> names) {
    String name() => names[r.s('dishSlug')] ?? r.s('dishSlug') ?? '';
    return switch (r.code) {
      'protein-covers' =>
        'Covers your ${_n(r.n('target'))} g protein for this meal — at least ${_n(r.n('low'))} g.',
      'protein-may-fall-short' =>
        '${_n(r.n('low'))}–${_n(r.n('high'))} g protein against ${_n(r.n('target'))} g — it may fall a little short.',
      'protein-short' =>
        'At most ${_n(r.n('high'))} g protein against the ${_n(r.n('target'))} g this meal needs.',
      'kcal-within' =>
        'Within this meal\'s ${_n(r.n('target'))} kcal — at most ${_n(r.n('high'))}.',
      'kcal-may-exceed' =>
        '${_n(r.n('low'))}–${_n(r.n('high'))} kcal against ${_n(r.n('target'))} — it may go over.',
      'kcal-over' =>
        'At least ${_n(r.n('low'))} kcal — over this meal\'s ${_n(r.n('target'))}.',
      'carb-within' => 'Carbs within ${_n(r.n('target'))} g.',
      'carb-over' =>
        'Carbs ${_n(r.n('low'))}–${_n(r.n('high'))} g, above ${_n(r.n('target'))} g.',
      'fat-within' => 'Fat within ${_n(r.n('target'))} g.',
      'fat-over' =>
        'Fat ${_n(r.n('low'))}–${_n(r.n('high'))} g, above ${_n(r.n('target'))} g.',
      'goal-weighting' => switch (r.s('goal')) {
          'muscle-gain' =>
            'Weighted for muscle gain: falling short on calories counts more than going over a little.',
          'fat-loss' ||
          'recomposition' =>
            'Weighted for ${_goal(r.s('goal'))}: going over calories counts more than staying under.',
          final g =>
            'Weighted for ${_goal(g)}: calories kept close to this meal\'s share.',
        },
      'top-protein-dish' =>
        '${name()} is the most protein-dense dish on this plate.',
      'post-workout-carbs' =>
        'After your workout: ${_n(r.n('low'))}–${_n(r.n('high'))} g carbs toward ${_n(r.n('target'))} g.',
      'repeat' =>
        '${name()}: you had it on ${_n(r.n('days'))} of the last 3 days.',
      'low-confidence-dish' => '${name()}\'s estimate is low confidence.',
      'inferred-menu' =>
        'Based on the inferred menu of ${r.s('sourceDate') ?? ''} — the mess has not published this day.',
      _ => r.code,
    };
  }

  /// Why a dish is, or is not, on a plate.
  static String dish(Reason r, DietType diet) => switch (r.code) {
        'on-plate' =>
          'On plate ${(r.values['ranks'] as List<dynamic>? ?? const []).join(', ')}.',
        'diet' => switch (DietClass.fromWire(r.s('dietClass'))) {
            DietClass.unknown =>
              'Diet not known — never offered to a ${diet.label.toLowerCase()} plate.',
            final c => '${c.label} — not ${diet.label.toLowerCase()}.',
          },
        'diet-alternative' =>
          'Its alternative ${r.s('alternative')} is ${DietClass.fromWire(r.s('dietClass')).label.toLowerCase()}.',
        'allergen' => _allergenLine(r.s('status'), _allergen(r.s('allergen'))),
        'allergen-alternative' =>
          'Its alternative ${r.s('alternative')}: ${_allergenLine(r.s('status'), _allergen(r.s('allergen'))).toLowerCase()}',
        'no-estimate' => 'No nutrition estimate yet.',
        'ambient' =>
          'Served with every meal — not part of the plate. You can still log it.',
        'not-a-plate-dish' => 'A side, not a plate dish.',
        'disliked' => 'You asked not to be suggested this.',
        'not-top-candidate' =>
          'Less protein per calorie than the dishes considered.',
        'not-chosen' => 'Fits your filters; another combination scored higher.',
        _ => r.code,
      };

  static String _allergenLine(String? status, String allergen) =>
      switch (status) {
        'contains' => 'Contains $allergen.',
        'likely' => 'Likely contains $allergen.',
        _ => 'Not confirmed free of $allergen.',
      };

  /// "Vegetarian · no known peanut or milk ingredient".
  static String filters(DietType diet, List<Allergen> allergies) {
    if (allergies.isEmpty) return '${diet.label} · no allergies set';
    final names = allergies.map((a) => a.label.toLowerCase()).toList();
    final list = names.length == 1
        ? names.first
        : '${names.sublist(0, names.length - 1).join(', ')} or ${names.last}';
    return '${diet.label} · no known $list ingredient';
  }
}
