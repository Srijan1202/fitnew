import '../../nutrition/domain/entities/food_log.dart';
import '../../profile/domain/entities/vocabulary.dart';
import 'mess.dart';

/// Wire shapes of `@fitos/contracts` mess-recommend.ts (Phase 10, ADR-015 and
/// ADR-016). The server computes every plate — always a meal, never the
/// cheapest dish — its numbers and reasons; the app draws them and words the
/// reason codes. Nothing here is computed, stored or reused later.

enum RecommendationStatus {
  ok('ok'),
  noTargets('no-targets'),
  targetReached('target-reached'),
  menuUnavailable('menu-unavailable'),
  mealNotServed('meal-not-served'),
  nothingSafe('nothing-safe'),

  /// ADR-016: dishes pass your filters, but no meal can be made from them.
  noMeal('no-meal'),

  /// ADR-016: a meal exists, but even the smallest goes over what is left today.
  nothingFits('nothing-fits');

  const RecommendationStatus(this.wire);
  final String wire;

  static RecommendationStatus fromWire(String w) =>
      values.firstWhere((s) => s.wire == w, orElse: () => nothingSafe);
}

/// What part of a meal a dish is (ADR-016).
enum MealComponent {
  staple('staple'),
  complete('complete'),
  protein('protein'),
  pulseGravy('pulse-gravy'),
  dairy('dairy'),
  veg('veg'),
  soup('soup'),
  fruit('fruit'),
  snack('snack'),
  dessert('dessert'),
  crisp('crisp'),
  beverage('beverage'),
  condiment('condiment'),
  other('other');

  const MealComponent(this.wire);
  final String wire;

  static MealComponent fromWire(String? w) =>
      values.firstWhere((c) => c.wire == w, orElse: () => other);
}

/// The meal a plate makes (ADR-016).
enum StructureKind {
  completeMeal('complete-meal'),
  meal('meal'),
  mealWeakProtein('meal-weak-protein'),
  limited('limited'),
  limitedNoStaple('limited-no-staple'),
  snack('snack');

  const StructureKind(this.wire);
  final String wire;

  static StructureKind fromWire(String? w) =>
      values.firstWhere((k) => k.wire == w, orElse: () => limited);
}

/// A plate's structure, and what it lacks for a complete meal
/// (`staple`, `protein`, `strong-protein`, `vegetable`).
class PlateStructure {
  const PlateStructure({required this.kind, required this.missing});

  factory PlateStructure.fromJson(Map<String, dynamic> j) => PlateStructure(
        kind: StructureKind.fromWire(j['kind'] as String?),
        missing: (j['missing'] as List<dynamic>).cast<String>(),
      );

  final StructureKind kind;
  final List<String> missing;

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'kind': kind.wire, 'missing': missing};
}

/// A reason: a code and its values. Worded by [ReasonText].
class Reason {
  const Reason(this.code, this.values);

  factory Reason.fromJson(Map<String, dynamic> json) => Reason(
        json['code'] as String,
        Map<String, dynamic>.of(json)..remove('code'),
      );

  final String code;
  final Map<String, dynamic> values;

  num? n(String k) => values[k] as num?;
  String? s(String k) => values[k] as String?;

  Map<String, dynamic> toJson() => <String, dynamic>{'code': code, ...values};
}

class Macros {
  const Macros({
    required this.kcalLow,
    required this.kcalHigh,
    required this.proteinLow,
    required this.proteinHigh,
    required this.carbLow,
    required this.carbHigh,
    required this.fatLow,
    required this.fatHigh,
  });

  factory Macros.fromJson(Map<String, dynamic> j) {
    double d(String k) => (j[k] as num).toDouble();
    return Macros(
      kcalLow: d('kcalLow'),
      kcalHigh: d('kcalHigh'),
      proteinLow: d('proteinLow'),
      proteinHigh: d('proteinHigh'),
      carbLow: d('carbLow'),
      carbHigh: d('carbHigh'),
      fatLow: d('fatLow'),
      fatHigh: d('fatHigh'),
    );
  }

  final double kcalLow;
  final double kcalHigh;
  final double proteinLow;
  final double proteinHigh;
  final double carbLow;
  final double carbHigh;
  final double fatLow;
  final double fatHigh;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'kcalLow': kcalLow,
        'kcalHigh': kcalHigh,
        'proteinLow': proteinLow,
        'proteinHigh': proteinHigh,
        'carbLow': carbLow,
        'carbHigh': carbHigh,
        'fatLow': fatLow,
        'fatHigh': fatHigh,
      };
}

class PlateItem {
  const PlateItem({
    required this.dishSlug,
    required this.name,
    required this.servings,
    required this.servingLabel,
    required this.servingGrams,
    required this.macros,
    required this.confidence,
    required this.component,
  });

  factory PlateItem.fromJson(Map<String, dynamic> j) => PlateItem(
        dishSlug: j['dishSlug'] as String,
        name: j['name'] as String,
        servings: j['servings'] as int,
        servingLabel: j['servingLabel'] as String,
        servingGrams: (j['servingGrams'] as num?)?.toDouble(),
        macros: Macros.fromJson(j),
        confidence: j['confidence'] as String,
        component: MealComponent.fromWire(j['component'] as String?),
      );

  final String dishSlug;
  final String name;
  final int servings;
  final String servingLabel;
  final double? servingGrams;
  final Macros macros;
  final String confidence;
  final MealComponent component;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'dishSlug': dishSlug,
        'name': name,
        'servings': servings,
        'servingLabel': servingLabel,
        'servingGrams': servingGrams,
        ...macros.toJson(),
        'confidence': confidence,
        'component': component.wire,
      };
}

class Plate {
  const Plate({
    required this.rank,
    required this.items,
    required this.totals,
    required this.confidence,
    required this.structure,
    required this.reasons,
  });

  factory Plate.fromJson(Map<String, dynamic> j) => Plate(
        rank: j['rank'] as int,
        items: (j['items'] as List<dynamic>)
            .map((e) => PlateItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        totals: Macros.fromJson(j['totals'] as Map<String, dynamic>),
        confidence: j['confidence'] as String,
        structure:
            PlateStructure.fromJson(j['structure'] as Map<String, dynamic>),
        reasons: (j['reasons'] as List<dynamic>)
            .map((e) => Reason.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final int rank;
  final List<PlateItem> items;
  final Macros totals;
  final String confidence;
  final PlateStructure structure;
  final List<Reason> reasons;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'rank': rank,
        'items': items.map((i) => i.toJson()).toList(),
        'totals': totals.toJson(),
        'confidence': confidence,
        'structure': structure.toJson(),
        'reasons': reasons.map((r) => r.toJson()).toList(),
      };
}

class Gap {
  const Gap({
    required this.target,
    required this.gapLow,
    required this.gapHigh,
    required this.menuMax,
    required this.menuCanMeet,
  });

  factory Gap.fromJson(Map<String, dynamic> j) => Gap(
        target: (j['target'] as num).toDouble(),
        gapLow: (j['gapLow'] as num).toDouble(),
        gapHigh: (j['gapHigh'] as num).toDouble(),
        menuMax: (j['menuMax'] as num).toDouble(),
        menuCanMeet: j['menuCanMeet'] as bool,
      );

  final double target;
  final double gapLow;
  final double gapHigh;
  final double menuMax;
  final bool menuCanMeet;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'target': target,
        'gapLow': gapLow,
        'gapHigh': gapHigh,
        'menuMax': menuMax,
        'menuCanMeet': menuCanMeet,
      };
}

class AlternativeOutcome {
  const AlternativeOutcome({
    required this.name,
    required this.diet,
    required this.allergens,
  });

  factory AlternativeOutcome.fromJson(Map<String, dynamic> j) =>
      AlternativeOutcome(
        name: j['name'] as String,
        diet: DietClass.fromWire(j['diet'] as String?),
        allergens: [
          for (final a in j['allergens'] as List<dynamic>)
            (
              allergen: (a as Map<String, dynamic>)['allergen'] as String,
              status: a['status'] as String,
            ),
        ],
      );

  final String name;
  final DietClass diet;
  final List<({String allergen, String status})> allergens;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'diet': diet.wire,
        'allergens': [
          for (final a in allergens)
            <String, dynamic>{'allergen': a.allergen, 'status': a.status},
        ],
      };
}

class DishOutcome {
  const DishOutcome({
    required this.dishSlug,
    required this.name,
    required this.diet,
    required this.onPlate,
    required this.reasons,
    required this.alternatives,
  });

  factory DishOutcome.fromJson(Map<String, dynamic> j) => DishOutcome(
        dishSlug: j['dishSlug'] as String,
        name: j['name'] as String,
        diet: DietClass.fromWire(j['diet'] as String?),
        onPlate: j['onPlate'] as bool,
        reasons: (j['reasons'] as List<dynamic>)
            .map((e) => Reason.fromJson(e as Map<String, dynamic>))
            .toList(),
        alternatives: (j['alternatives'] as List<dynamic>)
            .map((e) => AlternativeOutcome.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String dishSlug;
  final String name;
  final DietClass diet;
  final bool onPlate;
  final List<Reason> reasons;
  final List<AlternativeOutcome> alternatives;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'dishSlug': dishSlug,
        'name': name,
        'diet': diet.wire,
        'onPlate': onPlate,
        'reasons': reasons.map((r) => r.toJson()).toList(),
        'alternatives': alternatives.map((a) => a.toJson()).toList(),
      };
}

class MealTarget {
  const MealTarget({
    required this.share,
    required this.kcal,
    required this.protein,
    required this.carb,
    required this.fat,
    required this.dayRemainingKcal,
  });

  factory MealTarget.fromJson(Map<String, dynamic> j) => MealTarget(
        share: (j['share'] as num).toDouble(),
        kcal: (j['kcal'] as num).toDouble(),
        protein: (j['protein'] as num).toDouble(),
        carb: (j['carb'] as num).toDouble(),
        fat: (j['fat'] as num).toDouble(),
        dayRemainingKcal: (j['dayRemainingKcal'] as num).toDouble(),
      );

  final double share;
  final double kcal;
  final double protein;
  final double carb;
  final double fat;

  /// Everything left today, conservatively (for `nothing-fits`).
  final double dayRemainingKcal;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'share': share,
        'kcal': kcal,
        'protein': protein,
        'carb': carb,
        'fat': fat,
        'dayRemainingKcal': dayRemainingKcal,
      };
}

class MessRecommendation {
  const MessRecommendation({
    required this.status,
    required this.mess,
    required this.date,
    required this.today,
    required this.slot,
    required this.slotAlreadyLogged,
    required this.loggable,
    required this.resolution,
    required this.basis,
    required this.diet,
    required this.allergies,
    required this.goal,
    required this.target,
    required this.postWorkout,
    required this.plates,
    required this.proteinShortfall,
    required this.kcalShortfall,
    required this.dishes,
    required this.smallestMealKcal,
  });

  factory MessRecommendation.fromJson(Map<String, dynamic> j) {
    final filters = j['filters'] as Map<String, dynamic>;
    final shortfall = j['shortfall'] as Map<String, dynamic>?;
    Gap? gap(String k) => shortfall?[k] == null
        ? null
        : Gap.fromJson(shortfall![k] as Map<String, dynamic>);
    return MessRecommendation(
      status: RecommendationStatus.fromWire(j['status'] as String),
      mess: Mess.fromJson(j['mess'] as Map<String, dynamic>),
      date: j['date'] as String,
      today: j['today'] as String,
      slot: MealSlot.fromWire(j['slot'] as String),
      slotAlreadyLogged: j['slotAlreadyLogged'] as bool,
      loggable: j['loggable'] as bool,
      resolution:
          MenuResolution.fromJson(j['resolution'] as Map<String, dynamic>),
      basis: j['basis'] as String?,
      diet: DietType.values.firstWhere(
        (d) => d.wire == filters['diet'],
        orElse: () => DietType.vegetarian,
      ),
      allergies: [
        for (final a in filters['allergies'] as List<dynamic>)
          Allergen.values.firstWhere((x) => x.wire == a),
      ],
      goal: j['goal'] as String,
      target: j['target'] == null
          ? null
          : MealTarget.fromJson(j['target'] as Map<String, dynamic>),
      postWorkout: j['postWorkout'] as bool,
      plates: (j['plates'] as List<dynamic>)
          .map((e) => Plate.fromJson(e as Map<String, dynamic>))
          .toList(),
      proteinShortfall: gap('protein'),
      kcalShortfall: gap('kcal'),
      dishes: (j['dishes'] as List<dynamic>)
          .map((e) => DishOutcome.fromJson(e as Map<String, dynamic>))
          .toList(),
      smallestMealKcal: (j['smallestMealKcal'] as num?)?.toDouble(),
    );
  }

  final RecommendationStatus status;
  final Mess mess;
  final String date;
  final String today;
  final MealSlot slot;
  final bool slotAlreadyLogged;

  /// Only today's plates can be logged; tomorrow is for planning.
  final bool loggable;
  final MenuResolution resolution;

  /// 'published' | 'inferred' | null.
  final String? basis;
  final DietType diet;
  final List<Allergen> allergies;
  final String goal;
  final MealTarget? target;
  final bool postWorkout;
  final List<Plate> plates;
  final Gap? proteinShortfall;
  final Gap? kcalShortfall;
  final List<DishOutcome> dishes;

  /// `nothing-fits` only: the low-end kcal of the smallest meal on the menu.
  final double? smallestMealKcal;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'status': status.wire,
        'mess': mess.toJson(),
        'date': date,
        'today': today,
        'slot': slot.wire,
        'slotAlreadyLogged': slotAlreadyLogged,
        'loggable': loggable,
        'resolution': resolution.toJson(),
        'basis': basis,
        'filters': <String, dynamic>{
          'diet': diet.wire,
          'allergies': allergies.map((a) => a.wire).toList(),
        },
        'goal': goal,
        'target': target?.toJson(),
        'postWorkout': postWorkout,
        'plates': plates.map((p) => p.toJson()).toList(),
        'shortfall': proteinShortfall == null && kcalShortfall == null
            ? null
            : <String, dynamic>{
                'protein': proteinShortfall?.toJson(),
                'kcal': kcalShortfall?.toJson(),
              },
        'dishes': dishes.map((d) => d.toJson()).toList(),
        'smallestMealKcal': smallestMealKcal,
      };
}
