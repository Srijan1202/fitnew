import '../../../nutrition/domain/entities/food.dart';

/// Wire shapes of `@fitos/contracts` ai.ts, Phase 14 (ADR-020): the meal
/// draft from POST /nutrition/parse (and, beta 5.5, POST
/// /nutrition/parse-photo) and the reworded reason from POST /ai/explain. Hand-written (ADR-004); the conformance test keeps
/// them in step with the server.
///
/// §19.2: a draft is never a log. Nothing here is stored until the user
/// confirms it, and then only through the ordinary food-log queue.

enum AiConfidence {
  high('high'),
  medium('medium'),
  low('low');

  const AiConfidence(this.wire);
  final String wire;

  static AiConfidence of(Object? wire) =>
      values.firstWhere((c) => c.wire == wire, orElse: () => AiConfidence.low);
}

double _d(Object? v) => (v! as num).toDouble();
double? _dn(Object? v) => v == null ? null : (v as num).toDouble();

/// A phrase matched to a FITOS food: the numbers are the database's.
class DraftMatch {
  const DraftMatch({
    required this.foodId,
    required this.name,
    required this.matchKind,
    required this.servings,
    required this.row,
    required this.snapshot,
  });

  factory DraftMatch.fromJson(Map<String, dynamic> json) => DraftMatch(
        foodId: json['foodId'] as String,
        name: json['name'] as String,
        matchKind:
            FoodMatchKind.values.firstWhere((k) => k.wire == json['matchKind']),
        servings: _d(json['servings']),
        row: FoodNutrition.fromJson(json['row'] as Map<String, dynamic>),
        snapshot: Map<String, double>.from(
          (json['snapshot'] as Map<String, dynamic>)
              .map((k, v) => MapEntry(k, _d(v))),
        ),
      );

  final String foodId;
  final String name;
  final FoodMatchKind matchKind;

  /// The portion as servings of [row] — what the log will send.
  final double servings;

  /// The food's own row (its basis and serving label name it in the log).
  final FoodNutrition row;

  /// The server's rounding of [row] at [servings] (kcalLow … fatHigh).
  final Map<String, double> snapshot;

  NutritionBasis get basis => row.basis;
  String get servingLabel => row.servingLabel;

  Map<String, dynamic> toJson() => {
        'foodId': foodId,
        'name': name,
        'matchKind': matchKind.wire,
        'basis': row.basis.wire,
        'servingLabel': row.servingLabel,
        'servings': servings,
        'row': row.toJson(),
        'snapshot': snapshot,
      };
}

/// A food FITOS does not have: the model's estimate, inside §19.2's bounds.
class DraftEstimate {
  const DraftEstimate({
    required this.name,
    required this.grams,
    required this.kcal,
    required this.proteinG,
    required this.carbG,
    required this.fatG,
  });

  factory DraftEstimate.fromJson(Map<String, dynamic> json) => DraftEstimate(
        name: json['name'] as String,
        grams: _dn(json['grams']),
        kcal: _d(json['kcal']),
        proteinG: _d(json['proteinG']),
        carbG: _d(json['carbG']),
        fatG: _d(json['fatG']),
      );

  final String name;
  final double? grams;
  final double kcal;
  final double proteinG;
  final double carbG;
  final double fatG;

  Map<String, dynamic> toJson() => {
        'name': name,
        'grams': grams,
        'kcal': kcal,
        'proteinG': proteinG,
        'carbG': carbG,
        'fatG': fatG,
      };
}

Map<String, double> _macros(Object? v) => Map<String, double>.from(
      (v! as Map<String, dynamic>).map((k, v) => MapEntry(k, _d(v))),
    );

/// Beta 5.5: a dish on the person's mess menu, seen in a meal photo. The
/// numbers are the mess table's; the log sends the dish and its servings as
/// a mess log for the menu the answer names.
class DraftMessDish {
  const DraftMessDish({
    required this.dishSlug,
    required this.name,
    required this.servingLabel,
    required this.servings,
    required this.perServing,
    required this.snapshot,
  });

  factory DraftMessDish.fromJson(Map<String, dynamic> json) => DraftMessDish(
        dishSlug: json['dishSlug'] as String,
        name: json['name'] as String,
        servingLabel: json['servingLabel'] as String,
        servings: _d(json['servings']),
        perServing: _macros(json['perServing']),
        snapshot: _macros(json['snapshot']),
      );

  /// Quarters, 0.25–10.
  static const servingsMin = 0.25;
  static const servingsMax = 10.0;

  final String dishSlug;
  final String name;
  final String servingLabel;
  final double servings;

  /// One serving (kcalLow … fatHigh), for previewing a changed amount.
  final Map<String, double> perServing;

  /// The server's rounding at [servings].
  final Map<String, double> snapshot;

  Map<String, dynamic> toJson() => {
        'dishSlug': dishSlug,
        'name': name,
        'servingLabel': servingLabel,
        'servings': servings,
        'perServing': perServing,
        'snapshot': snapshot,
      };
}

/// One food from the description: a [match], a [messDish] (beta 5.5,
/// photos), an [estimate], or a [problem].
class DraftItem {
  const DraftItem({
    required this.phrase,
    required this.quantity,
    required this.unit,
    required this.confidence,
    this.match,
    this.messDish,
    this.estimate,
    this.problem,
  });

  factory DraftItem.fromJson(Map<String, dynamic> json) => DraftItem(
        phrase: json['phrase'] as String,
        quantity: _d(json['quantity']),
        unit: json['unit'] as String,
        confidence: AiConfidence.of(json['confidence']),
        match: json['match'] == null
            ? null
            : DraftMatch.fromJson(json['match'] as Map<String, dynamic>),
        messDish: json['messDish'] == null
            ? null
            : DraftMessDish.fromJson(json['messDish'] as Map<String, dynamic>),
        estimate: json['estimate'] == null
            ? null
            : DraftEstimate.fromJson(json['estimate'] as Map<String, dynamic>),
        problem: json['problem'] as String?,
      );

  final String phrase;
  final double quantity;
  final String unit;
  final AiConfidence confidence;
  final DraftMatch? match;
  final DraftMessDish? messDish;
  final DraftEstimate? estimate;
  final String? problem;

  /// Something the user can log (a match, a mess dish or an estimate).
  bool get loggable => match != null || messDish != null || estimate != null;

  Map<String, dynamic> toJson() => {
        'phrase': phrase,
        'quantity': quantity,
        'unit': unit,
        'confidence': confidence.wire,
        'match': match?.toJson(),
        'messDish': messDish?.toJson(),
        'estimate': estimate?.toJson(),
        'problem': problem,
      };
}

/// The AiDraft (§19.2): `source` is always 'ai-draft' and
/// `requiresConfirmation` always true.
class FoodDraft {
  const FoodDraft({
    required this.items,
    required this.confidence,
    this.source = 'ai-draft',
    this.requiresConfirmation = true,
  });

  factory FoodDraft.fromJson(Map<String, dynamic> json) => FoodDraft(
        items: [
          for (final i in ((json['data'] as Map<String, dynamic>)['items']
              as List<dynamic>))
            DraftItem.fromJson(i as Map<String, dynamic>),
        ],
        confidence: AiConfidence.of(json['confidence']),
        source: json['source'] as String,
        requiresConfirmation: json['requiresConfirmation'] as bool,
      );

  final List<DraftItem> items;
  final AiConfidence confidence;
  final String source;
  final bool requiresConfirmation;

  Map<String, dynamic> toJson() => {
        'data': {
          'items': [for (final i in items) i.toJson()],
        },
        'confidence': confidence.wire,
        'source': source,
        'requiresConfirmation': requiresConfirmation,
      };
}

class ParseFoodResponse {
  const ParseFoodResponse({required this.draft, required this.model});

  factory ParseFoodResponse.fromJson(Map<String, dynamic> json) =>
      ParseFoodResponse(
        draft: FoodDraft.fromJson(json['draft'] as Map<String, dynamic>),
        model: json['model'] as String,
      );

  final FoodDraft draft;
  final String model;

  Map<String, dynamic> toJson() => {'draft': draft.toJson(), 'model': model};
}

/// Beta 5.5: the answer to a meal photo; [messCode] and [menuDate] name the
/// menu a [DraftMessDish] is logged against (null when there was none).
class ParseFoodPhotoResponse {
  const ParseFoodPhotoResponse({
    required this.draft,
    required this.model,
    this.messCode,
    this.menuDate,
  });

  factory ParseFoodPhotoResponse.fromJson(Map<String, dynamic> json) {
    final mess = json['mess'] as Map<String, dynamic>?;
    return ParseFoodPhotoResponse(
      draft: FoodDraft.fromJson(json['draft'] as Map<String, dynamic>),
      model: json['model'] as String,
      messCode: mess?['code'] as String?,
      menuDate: mess?['menuDate'] as String?,
    );
  }

  final FoodDraft draft;
  final String model;
  final String? messCode;
  final String? menuDate;

  Map<String, dynamic> toJson() => {
        'draft': draft.toJson(),
        'mess':
            messCode == null ? null : {'code': messCode, 'menuDate': menuDate},
        'model': model,
      };
}

/// Where the explanation's words came from.
enum ExplainSource {
  /// FITOS AI's rewording; every number in it is the engine's.
  ai('ai'),

  /// The engine's own words: the rewording added a number, or said nothing.
  engine('engine');

  const ExplainSource(this.wire);
  final String wire;
}

class ExplainResponse {
  const ExplainResponse({
    required this.text,
    required this.source,
    this.discarded,
  });

  factory ExplainResponse.fromJson(Map<String, dynamic> json) =>
      ExplainResponse(
        text: json['text'] as String,
        source:
            json['source'] == 'ai' ? ExplainSource.ai : ExplainSource.engine,
        discarded: json['discarded'] as String?,
      );

  final String text;
  final ExplainSource source;

  /// Why the rewording was not used: 'new-number', 'empty' or 'too-long'.
  final String? discarded;

  Map<String, dynamic> toJson() =>
      {'text': text, 'source': source.wire, 'discarded': discarded};
}
