import '../../nutrition/domain/entities/food.dart';
import '../../nutrition/domain/entities/food_log.dart';

/// Wire shapes of `@fitos/contracts` mess.ts (Phase 9). The server mirrors
/// MessIT and parses it; the app only ever sees these normalised shapes,
/// never MessIT's own format. Hand-written (ADR-004): the menu resolution
/// is a union on `kind`.

enum DietClass {
  veg('veg', 'Veg'),
  egg('egg', 'Egg'),
  nonveg('nonveg', 'Non-veg'),

  /// Deliberate: the classifier could not tell. Never shown as veg.
  unknown('unknown', 'Diet not known');

  const DietClass(this.wire, this.label);
  final String wire;
  final String label;

  static DietClass fromWire(String? w) =>
      values.firstWhere((d) => d.wire == w, orElse: () => DietClass.unknown);
}

enum MirrorError {
  unreachable('unreachable'),
  malformed('malformed');

  const MirrorError(this.wire);
  final String wire;

  static MirrorError? fromWire(String? w) =>
      w == null ? null : values.where((e) => e.wire == w).firstOrNull;
}

/// How fresh the SERVER's copy of one endpoint is — MessIT has no timestamp
/// of its own. `stale`: no successful fetch in 24 h.
class MessFreshness {
  const MessFreshness({
    required this.lastSuccessAt,
    required this.lastAttemptAt,
    required this.lastError,
    required this.stale,
    required this.latestPublishedDate,
  });

  factory MessFreshness.fromJson(Map<String, dynamic> json) => MessFreshness(
        lastSuccessAt: json['lastSuccessAt'] as String?,
        lastAttemptAt: json['lastAttemptAt'] as String?,
        lastError: MirrorError.fromWire(json['lastError'] as String?),
        stale: json['stale'] as bool,
        latestPublishedDate: json['latestPublishedDate'] as String?,
      );

  final String? lastSuccessAt;
  final String? lastAttemptAt;
  final MirrorError? lastError;
  final bool stale;
  final String? latestPublishedDate;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'lastSuccessAt': lastSuccessAt,
        'lastAttemptAt': lastAttemptAt,
        'lastError': lastError?.wire,
        'stale': stale,
        'latestPublishedDate': latestPublishedDate,
      };
}

class Mess {
  const Mess({
    required this.code,
    required this.providerSlug,
    required this.hostelId,
    required this.hostelLabel,
    required this.messId,
    required this.messLabel,
    required this.servesNonVeg,
    required this.freshness,
  });

  factory Mess.fromJson(Map<String, dynamic> json) => Mess(
        code: json['code'] as String,
        providerSlug: json['providerSlug'] as String,
        hostelId: json['hostelId'] as String,
        hostelLabel: json['hostelLabel'] as String,
        messId: json['messId'] as String,
        messLabel: json['messLabel'] as String,
        servesNonVeg: json['servesNonVeg'] as bool,
        freshness:
            MessFreshness.fromJson(json['freshness'] as Map<String, dynamic>),
      );

  final String code;
  final String providerSlug;
  final String hostelId;
  final String hostelLabel;
  final String messId;
  final String messLabel;
  final bool servesNonVeg;
  final MessFreshness freshness;

  /// "Men's Hostel · Vegetarian".
  String get label => '$hostelLabel · $messLabel';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'code': code,
        'providerSlug': providerSlug,
        'hostelId': hostelId,
        'hostelLabel': hostelLabel,
        'messId': messId,
        'messLabel': messLabel,
        'servesNonVeg': servesNonVeg,
        'freshness': freshness.toJson(),
      };
}

class MessProviderInfo {
  const MessProviderInfo({
    required this.slug,
    required this.displayName,
    required this.status,
  });

  factory MessProviderInfo.fromJson(Map<String, dynamic> json) =>
      MessProviderInfo(
        slug: json['slug'] as String,
        displayName: json['displayName'] as String,
        status: json['status'] as String,
      );

  final String slug;
  final String displayName;
  final String status;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'slug': slug,
        'displayName': displayName,
        'status': status,
      };
}

class MessesResponse {
  const MessesResponse({required this.provider, required this.items});

  factory MessesResponse.fromJson(Map<String, dynamic> json) => MessesResponse(
        provider:
            MessProviderInfo.fromJson(json['provider'] as Map<String, dynamic>),
        items: (json['items'] as List<dynamic>)
            .map((e) => Mess.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final MessProviderInfo provider;
  final List<Mess> items;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'provider': provider.toJson(),
        'items': items.map((m) => m.toJson()).toList(),
      };
}

/// How the menu on screen was found (§14.4) — always shown, never hidden.
sealed class MenuResolution {
  const MenuResolution(this.date);

  factory MenuResolution.fromJson(Map<String, dynamic> json) =>
      switch (json['kind']) {
        'exact' => ExactMenu(json['date'] as String),
        'cycle-inferred' => InferredMenu(
            json['date'] as String,
            sourceDate: json['sourceDate'] as String,
            cycleLengthDays: json['cycleLengthDays'] as int,
          ),
        _ => UnavailableMenu(
            json['date'] as String,
            latestAvailable: json['latestAvailable'] as String?,
          ),
      };

  final String date;

  Map<String, dynamic> toJson();
}

/// The mess published this date.
class ExactMenu extends MenuResolution {
  const ExactMenu(super.date);

  @override
  Map<String, dynamic> toJson() =>
      <String, dynamic>{'kind': 'exact', 'date': date};
}

/// Not published: the menu repeats every [cycleLengthDays], so this is the
/// menu of [sourceDate]. Never presented as the published menu.
class InferredMenu extends MenuResolution {
  const InferredMenu(
    super.date, {
    required this.sourceDate,
    required this.cycleLengthDays,
  });

  final String sourceDate;
  final int cycleLengthDays;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': 'cycle-inferred',
        'date': date,
        'sourceDate': sourceDate,
        'cycleLengthDays': cycleLengthDays,
      };
}

/// Neither published nor inferable.
class UnavailableMenu extends MenuResolution {
  const UnavailableMenu(super.date, {required this.latestAvailable});

  final String? latestAvailable;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': 'unavailable',
        'date': date,
        'latestAvailable': latestAvailable,
      };
}

class MessDish {
  const MessDish({
    required this.slug,
    required this.name,
    required this.label,
    required this.diet,
    required this.role,
    required this.alternatives,
    required this.isAmbient,
    required this.nutrition,
    required this.correctionPending,
  });

  factory MessDish.fromJson(Map<String, dynamic> json) => MessDish(
        slug: json['slug'] as String,
        name: json['name'] as String,
        label: json['label'] as String?,
        diet: DietClass.fromWire(json['diet'] as String?),
        role: json['role'] as String,
        alternatives: (json['alternatives'] as List<dynamic>).cast<String>(),
        isAmbient: json['isAmbient'] as bool,
        nutrition: json['nutrition'] == null
            ? null
            : messRowFromJson(json['nutrition'] as Map<String, dynamic>),
        correctionPending: json['correctionPending'] as bool,
      );

  final String slug;
  final String name;
  final String? label;
  final DietClass diet;
  final String role;
  final List<String> alternatives;

  /// Bread, tea, jam… at every meal: loggable, shown quietly.
  final bool isAmbient;

  /// The estimate per serving as a food row; null = no estimate (not
  /// tap-loggable).
  final FoodNutrition? nutrition;

  /// You reported this dish; the report is awaiting review (owner D17).
  final bool correctionPending;

  /// The dish as a food, so the Phase 8 portion step can take it. It is
  /// never stored as a food: logging sends the dish slug.
  Food asFood() => Food(
        id: 'mess:$slug',
        slug: slug,
        name: name,
        brand: null,
        barcode: null,
        source: FoodSource.estimated,
        sourceRef: null,
        isVerified: false,
        isCustom: false,
        aliases: const <String>[],
        nutrition: nutrition == null ? const [] : [nutrition!],
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'slug': slug,
        'name': name,
        'label': label,
        'diet': diet.wire,
        'role': role,
        'alternatives': alternatives,
        'isAmbient': isAmbient,
        'nutrition': nutrition == null ? null : messRowToJson(nutrition!),
        'correctionPending': correctionPending,
      };
}

class MessMeal {
  const MessMeal({
    required this.slot,
    required this.rawMenu,
    required this.dishes,
  });

  factory MessMeal.fromJson(Map<String, dynamic> json) => MessMeal(
        slot: MealSlot.fromWire(json['slot'] as String),
        rawMenu: json['rawMenu'] as String,
        dishes: (json['dishes'] as List<dynamic>)
            .map((e) => MessDish.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final MealSlot slot;

  /// Exactly what the mess published for this meal (owner D20).
  final String rawMenu;
  final List<MessDish> dishes;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'slot': slot.wire,
        'rawMenu': rawMenu,
        'dishes': dishes.map((d) => d.toJson()).toList(),
      };
}

class MessLoggedDish {
  const MessLoggedDish({
    required this.dishSlug,
    required this.mealSlot,
    required this.clientLogId,
  });

  factory MessLoggedDish.fromJson(Map<String, dynamic> json) => MessLoggedDish(
        dishSlug: json['dishSlug'] as String,
        mealSlot: MealSlot.fromWire(json['mealSlot'] as String),
        clientLogId: json['clientLogId'] as String,
      );

  final String dishSlug;
  final MealSlot mealSlot;
  final String clientLogId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'dishSlug': dishSlug,
        'mealSlot': mealSlot.wire,
        'clientLogId': clientLogId,
      };
}

class MessMenu {
  const MessMenu({
    required this.mess,
    required this.date,
    required this.today,
    required this.resolution,
    required this.meals,
    required this.logged,
  });

  factory MessMenu.fromJson(Map<String, dynamic> json) => MessMenu(
        mess: Mess.fromJson(json['mess'] as Map<String, dynamic>),
        date: json['date'] as String,
        today: json['today'] as String,
        resolution: MenuResolution.fromJson(
          json['resolution'] as Map<String, dynamic>,
        ),
        meals: (json['meals'] as List<dynamic>)
            .map((e) => MessMeal.fromJson(e as Map<String, dynamic>))
            .toList(),
        logged: (json['logged'] as List<dynamic>)
            .map((e) => MessLoggedDish.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final Mess mess;
  final String date;
  final String today;
  final MenuResolution resolution;
  final List<MessMeal> meals;
  final List<MessLoggedDish> logged;

  MessMeal? meal(MealSlot slot) =>
      meals.where((m) => m.slot == slot).firstOrNull;

  bool isLogged(String slug) => logged.any((l) => l.dishSlug == slug);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'mess': mess.toJson(),
        'date': date,
        'today': today,
        'resolution': resolution.toJson(),
        'meals': meals.map((m) => m.toJson()).toList(),
        'logged': logged.map((l) => l.toJson()).toList(),
      };
}

/* --------------------------------------------------------- corrections -- */

enum CorrectionField {
  kcal('kcal', 'Calories', 'kcal'),
  protein('protein', 'Protein', 'g'),
  carb('carb', 'Carbs', 'g'),
  fat('fat', 'Fat', 'g'),
  diet('diet', 'Diet type', ''),
  other('other', 'Something else', '');

  const CorrectionField(this.wire, this.label, this.unit);
  final String wire;
  final String label;
  final String unit;

  bool get isMacro => unit.isNotEmpty;
}

/// A report that a dish's estimate is wrong (owner D17): stored as pending,
/// changes nothing until a later review.
class MessCorrectionRequest {
  const MessCorrectionRequest({
    required this.clientCorrectionId,
    required this.field,
    this.low,
    this.high,
    this.diet,
    this.note,
  });

  final String clientCorrectionId;
  final CorrectionField field;
  final double? low;
  final double? high;
  final DietClass? diet;
  final String? note;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'clientCorrectionId': clientCorrectionId,
        'field': field.wire,
        if (low != null) 'low': low,
        if (high != null) 'high': high,
        if (diet != null) 'diet': diet!.wire,
        if (note != null) 'note': note,
      };
}

class MessCorrection {
  const MessCorrection({
    required this.id,
    required this.clientCorrectionId,
    required this.dishSlug,
    required this.field,
    required this.low,
    required this.high,
    required this.diet,
    required this.note,
    required this.status,
    required this.createdAt,
  });

  factory MessCorrection.fromJson(Map<String, dynamic> json) => MessCorrection(
        id: json['id'] as String,
        clientCorrectionId: json['clientCorrectionId'] as String,
        dishSlug: json['dishSlug'] as String,
        field: CorrectionField.values.firstWhere(
          (f) => f.wire == json['field'],
          orElse: () => CorrectionField.other,
        ),
        low: (json['low'] as num?)?.toDouble(),
        high: (json['high'] as num?)?.toDouble(),
        diet: json['diet'] == null
            ? null
            : DietClass.fromWire(json['diet'] as String),
        note: json['note'] as String?,
        status: json['status'] as String,
        createdAt: json['createdAt'] as String,
      );

  final String id;
  final String clientCorrectionId;
  final String dishSlug;
  final CorrectionField field;
  final double? low;
  final double? high;
  final DietClass? diet;
  final String? note;
  final String status;
  final String createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'clientCorrectionId': clientCorrectionId,
        'dishSlug': dishSlug,
        'field': field.wire,
        'low': low,
        'high': high,
        'diet': diet?.wire,
        'note': note,
        'status': status,
        'createdAt': createdAt,
      };
}
