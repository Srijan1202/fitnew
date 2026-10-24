import '../../../nutrition/domain/entities/food_log.dart';
import 'ai_draft.dart';

/// Wire shapes of `@fitos/contracts` ai.ts, beta 3.6 (owner F15): "What
/// should I eat?" — POST /nutrition/guide. Hand-written (ADR-004); the
/// conformance test keeps them in step with the server.
///
/// The model picks from what the person has and the mess menu; every number
/// here is the food database's or the mess table's. Nothing is stored until
/// the person logs a plate, through the ordinary food-log queue.

/// The server's GUIDE_HAVE_MAX, GUIDE_HAVE_ITEM_MAX and GUIDE_FEEL_MAX.
const kGuideHaveMax = 20;
const kGuideHaveItemMax = 40;
const kGuideFeelMax = 120;

double _d(Object? v) => (v! as num).toDouble();

class FoodGuideRequest {
  const FoodGuideRequest({
    required this.slot,
    required this.fromMess,
    required this.have,
    this.feel,
  });

  final MealSlot slot;
  final bool fromMess;
  final List<String> have;
  final String? feel;

  Map<String, dynamic> toJson() => {
        'slot': slot.wire,
        'fromMess': fromMess,
        'have': have,
        'feel': feel,
      };
}

/// kcalLow … fatHigh.
class GuideMacros {
  const GuideMacros(this.values);

  factory GuideMacros.fromJson(Map<String, dynamic> j) =>
      GuideMacros(j.map((k, v) => MapEntry(k, _d(v))));

  final Map<String, double> values;

  double get kcalLow => values['kcalLow']!;
  double get kcalHigh => values['kcalHigh']!;
  double get proteinLow => values['proteinLow']!;
  double get proteinHigh => values['proteinHigh']!;

  /// The middle of the range, whole.
  int get kcal => ((kcalLow + kcalHigh) / 2).round();
  int get proteinG => ((proteinLow + proteinHigh) / 2).round();
}

class GuideItem {
  const GuideItem({
    required this.source,
    required this.name,
    required this.servings,
    required this.servingLabel,
    required this.macros,
    required this.food,
    required this.dishSlug,
  });

  factory GuideItem.fromJson(Map<String, dynamic> j) => GuideItem(
        source: j['source'] as String,
        name: j['name'] as String,
        servings: _d(j['servings']),
        servingLabel: j['servingLabel'] as String,
        macros: GuideMacros.fromJson(j['macros'] as Map<String, dynamic>),
        food: j['food'] == null
            ? null
            : DraftMatch.fromJson(j['food'] as Map<String, dynamic>),
        dishSlug: j['dishSlug'] as String?,
      );

  /// mess or have.
  final String source;
  final String name;
  final double servings;
  final String servingLabel;
  final GuideMacros macros;

  /// Something the person has: logged as a database food.
  final DraftMatch? food;

  /// A mess dish: logged as one.
  final String? dishSlug;

  bool get fromMess => source == 'mess';
}

class GuideOption {
  const GuideOption({
    required this.title,
    required this.why,
    required this.items,
    required this.totals,
    required this.caution,
  });

  factory GuideOption.fromJson(Map<String, dynamic> j) => GuideOption(
        title: j['title'] as String,
        why: j['why'] as String,
        items: [
          for (final i in j['items'] as List<dynamic>)
            GuideItem.fromJson(i as Map<String, dynamic>),
        ],
        totals: GuideMacros.fromJson(j['totals'] as Map<String, dynamic>),
        caution: (j['caution'] as List<dynamic>).cast<String>(),
      );

  final String title;
  final String why;
  final List<GuideItem> items;
  final GuideMacros totals;

  /// Allergens the names cannot rule out.
  final List<String> caution;
}

class FoodGuideResponse {
  const FoodGuideResponse({
    required this.slot,
    required this.date,
    required this.messCode,
    required this.menuDate,
    required this.remainingKcal,
    required this.remainingProteinG,
    required this.options,
    required this.unknown,
    required this.refused,
    required this.messNote,
    required this.model,
  });

  factory FoodGuideResponse.fromJson(Map<String, dynamic> j) {
    final mess = j['mess'] as Map<String, dynamic>?;
    final remaining = j['remaining'] as Map<String, dynamic>?;
    return FoodGuideResponse(
      slot: MealSlot.fromWire(j['slot'] as String),
      date: j['date'] as String,
      messCode: mess?['code'] as String?,
      menuDate: mess?['menuDate'] as String?,
      remainingKcal: remaining?['kcal'] as int?,
      remainingProteinG: remaining?['proteinG'] as int?,
      options: [
        for (final o in j['options'] as List<dynamic>)
          GuideOption.fromJson(o as Map<String, dynamic>),
      ],
      unknown: (j['unknown'] as List<dynamic>).cast<String>(),
      refused: (j['refused'] as List<dynamic>).cast<String>(),
      messNote: j['messNote'] as String?,
      model: j['model'] as String,
    );
  }

  final MealSlot slot;
  final String date;
  final String? messCode;
  final String? menuDate;
  final int? remainingKcal;
  final int? remainingProteinG;
  final List<GuideOption> options;
  final List<String> unknown;
  final List<String> refused;
  final String? messNote;
  final String model;
}
