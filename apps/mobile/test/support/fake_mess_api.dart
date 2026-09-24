import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/features/mess/data/mess_api.dart';
import 'package:fitos/features/mess/domain/mess.dart';
import 'package:fitos/features/mess/domain/recommendation.dart';
import 'package:fitos/features/profile/domain/entities/vocabulary.dart';
import 'package:fitos/features/nutrition/domain/entities/food.dart';
import 'package:fitos/features/nutrition/domain/entities/food_log.dart';

/// A scripted mess server for Phase 9 tests. Serves [menus] by
/// (code, date) — the user's own mess is [mine] — records every call, and
/// scripts offline / not-configured. Nothing here reaches a network.
class FakeMessApi implements MessApi {
  FakeMessApi({this.mine = 'mens-veg'});

  /// The user's configured mess code; null = none configured (404).
  String? mine;
  bool offline = false;
  final List<String> calls = [];
  final List<(String, MessCorrectionRequest)> corrections = [];

  /// Menus by "code/date". A missing one is built from [defaultMenu].
  final Map<String, MessMenu> menus = {};

  @override
  Future<Result<MessesResponse>> messes({
    String provider = MessApi.vitProvider,
  }) async {
    calls.add('messes');
    if (offline) return const Err(Offline());
    return Ok(
      MessesResponse(
        provider: const MessProviderInfo(
          slug: 'vit-vellore',
          displayName: 'VIT Vellore',
          status: 'active',
        ),
        items: [for (final c in codes) messOf(c)],
      ),
    );
  }

  @override
  Future<Result<MessMenu>> menu({required String date, String? mess}) async {
    calls.add('menu ${mess ?? 'mine'} $date');
    if (offline) return const Err(Offline());
    final code = mess ?? mine;
    if (code == null) return const Err(NotFound());
    return Ok(menus['$code/$date'] ?? defaultMenu(code, date));
  }

  @override
  Future<Result<MessCorrection>> correct(
    String dishSlug,
    MessCorrectionRequest request,
  ) async {
    calls.add('correct $dishSlug');
    if (offline) return const Err(Offline());
    corrections.add((dishSlug, request));
    return Ok(
      MessCorrection(
        id: 'corr-${corrections.length}',
        clientCorrectionId: request.clientCorrectionId,
        dishSlug: dishSlug,
        field: request.field,
        low: request.low,
        high: request.high,
        diet: request.diet,
        note: request.note,
        status: 'pending',
        createdAt: '2026-09-24T07:30:00.000Z',
      ),
    );
  }

  /// Phase 10: scripted recommendations by "date/slot" (slot 'default' when
  /// none is asked); a missing one is built by [defaultRecommendation].
  final Map<String, MessRecommendation> recommendations = {};
  final List<String> recommendCalls = [];

  @override
  Future<Result<MessRecommendation>> recommend({
    required String date,
    String? mess,
    String? slot,
  }) async {
    recommendCalls
        .add('recommend ${mess ?? 'mine'} $date ${slot ?? 'default'}');
    if (offline) return const Err(Offline());
    final code = mess ?? mine;
    if (code == null) return const Err(NotFound());
    return Ok(
      recommendations['$date/${slot ?? 'default'}'] ??
          defaultRecommendation(
            code,
            date,
            slot: slot == null ? MealSlot.lunch : MealSlot.fromWire(slot),
          ),
    );
  }

  static PlateItem plateItem(
    String slug,
    String name,
    int servings,
    FoodNutrition row,
  ) =>
      PlateItem(
        dishSlug: slug,
        name: name,
        servings: servings,
        servingLabel: row.servingLabel,
        servingGrams: row.servingGrams,
        macros: Macros(
          kcalLow: row.kcalLow * servings,
          kcalHigh: row.kcalHigh * servings,
          proteinLow: row.proteinLow * servings,
          proteinHigh: row.proteinHigh * servings,
          carbLow: row.carbLow * servings,
          carbHigh: row.carbHigh * servings,
          fatLow: row.fatLow * servings,
          fatHigh: row.fatHigh * servings,
        ),
        confidence: row.confidence.wire,
      );

  static Macros sum(List<PlateItem> items) => Macros(
        kcalLow: items.fold(0, (s, i) => s + i.macros.kcalLow),
        kcalHigh: items.fold(0, (s, i) => s + i.macros.kcalHigh),
        proteinLow: items.fold(0, (s, i) => s + i.macros.proteinLow),
        proteinHigh: items.fold(0, (s, i) => s + i.macros.proteinHigh),
        carbLow: items.fold(0, (s, i) => s + i.macros.carbLow),
        carbHigh: items.fold(0, (s, i) => s + i.macros.carbHigh),
        fatLow: items.fold(0, (s, i) => s + i.macros.fatLow),
        fatHigh: items.fold(0, (s, i) => s + i.macros.fatHigh),
      );

  /// A vegetarian lunch with two plates and one dish kept off for diet.
  static MessRecommendation defaultRecommendation(
    String code,
    String date, {
    MealSlot slot = MealSlot.lunch,
    RecommendationStatus status = RecommendationStatus.ok,
    bool loggable = true,
    List<Allergen> allergies = const [],
    Gap? proteinShortfall,
    Gap? kcalShortfall,
    String? basis = 'published',
    bool slotAlreadyLogged = false,
    MealTarget? target = const MealTarget(
      share: 0.4667,
      kcal: 900,
      protein: 45,
      carb: 110,
      fat: 25,
    ),
  }) {
    final plate1 = [
      plateItem('phulka', 'Phulka', 3, phulka),
      plateItem('dhal-makhani', 'Dhal Makhani', 1, dal),
    ];
    final plate2 = [plateItem('dhal-makhani', 'Dhal Makhani', 2, dal)];
    return MessRecommendation(
      status: status,
      mess: messOf(code),
      date: date,
      today: '2026-09-24',
      slot: slot,
      slotAlreadyLogged: slotAlreadyLogged,
      loggable: loggable,
      resolution: ExactMenu(date),
      basis: status == RecommendationStatus.ok ? basis : null,
      diet: DietType.vegetarian,
      allergies: allergies,
      goal: 'muscle-gain',
      target: target,
      postWorkout: false,
      plates: status != RecommendationStatus.ok
          ? const []
          : [
              Plate(
                rank: 1,
                items: plate1,
                totals: sum(plate1),
                confidence: 'medium',
                reasons: const [
                  Reason(
                    'protein-may-fall-short',
                    {'target': 45, 'low': 14.5, 'high': 20.8},
                  ),
                  Reason('kcal-within', {'target': 900, 'high': 620}),
                  Reason('goal-weighting', {'goal': 'muscle-gain'}),
                  Reason('top-protein-dish', {'dishSlug': 'dhal-makhani'}),
                ],
              ),
              Plate(
                rank: 2,
                items: plate2,
                totals: sum(plate2),
                confidence: 'medium',
                reasons: const [
                  Reason('goal-weighting', {'goal': 'muscle-gain'}),
                ],
              ),
            ],
      proteinShortfall: proteinShortfall,
      kcalShortfall: kcalShortfall,
      dishes: const [
        DishOutcome(
          dishSlug: 'phulka',
          name: 'Phulka',
          diet: DietClass.veg,
          onPlate: true,
          reasons: [
            Reason('on-plate', {
              'ranks': [1],
            }),
          ],
          alternatives: [],
        ),
        DishOutcome(
          dishSlug: 'scrambled-egg',
          name: 'Scrambled Egg',
          diet: DietClass.egg,
          onPlate: false,
          reasons: [
            Reason('diet', {'dietClass': 'egg'}),
          ],
          alternatives: [
            AlternativeOutcome(
              name: 'Paneer Bhurji',
              diet: DietClass.veg,
              allergens: [(allergen: 'milk', status: 'contains')],
            ),
          ],
        ),
        DishOutcome(
          dishSlug: 'groundnut-chutney',
          name: 'Groundnut Chutney',
          diet: DietClass.veg,
          onPlate: false,
          reasons: [
            Reason('allergen', {'allergen': 'peanut', 'status': 'contains'}),
          ],
          alternatives: [],
        ),
      ],
    );
  }

  static const codes = [
    'mens-veg',
    'mens-nonveg',
    'mens-special',
    'womens-veg',
    'womens-nonveg',
    'womens-special',
  ];

  static Mess messOf(String code, {MessFreshness? freshness}) {
    final parts = code.split('-');
    final hostel = parts[0];
    final kind = parts[1];
    return Mess(
      code: code,
      providerSlug: 'vit-vellore',
      hostelId: hostel,
      hostelLabel: hostel == 'mens' ? "Men's Hostel" : "Women's Hostel",
      messId: kind,
      messLabel: switch (kind) {
        'veg' => 'Vegetarian',
        'nonveg' => 'Non-Vegetarian',
        _ => 'Special',
      },
      servesNonVeg: kind != 'veg',
      freshness: freshness ??
          const MessFreshness(
            lastSuccessAt: '2026-09-24T06:00:00.000Z',
            lastAttemptAt: '2026-09-24T06:00:00.000Z',
            lastError: null,
            stale: false,
            latestPublishedDate: '2026-09-30',
          ),
    );
  }

  static const phulka = FoodNutrition(
    basis: NutritionBasis.perServing,
    servingLabel: '1 piece',
    servingGrams: 40,
    kcalLow: 85,
    kcalHigh: 120,
    proteinLow: 2.5,
    proteinHigh: 3.6,
    carbLow: 16,
    carbHigh: 22,
    fatLow: 0.8,
    fatHigh: 3,
    fibreLow: null,
    fibreHigh: null,
    confidence: NutritionConfidence.medium,
  );

  static const dal = FoodNutrition(
    basis: NutritionBasis.perServing,
    servingLabel: '1 katori',
    servingGrams: 150,
    kcalLow: 180,
    kcalHigh: 260,
    proteinLow: 7,
    proteinHigh: 10,
    carbLow: 18,
    carbHigh: 25,
    fatLow: 8,
    fatHigh: 15,
    fibreLow: null,
    fibreHigh: null,
    confidence: NutritionConfidence.medium,
  );

  static const kulambu = FoodNutrition(
    basis: NutritionBasis.perServing,
    servingLabel: '1 katori',
    servingGrams: null,
    kcalLow: 60,
    kcalHigh: 160,
    proteinLow: 1.5,
    proteinHigh: 4,
    carbLow: 8,
    carbHigh: 18,
    fatLow: 2,
    fatHigh: 9,
    fibreLow: null,
    fibreHigh: null,
    confidence: NutritionConfidence.low,
  );

  static MessDish dish(
    String slug,
    String name, {
    FoodNutrition? nutrition,
    DietClass diet = DietClass.veg,
    bool ambient = false,
    bool pending = false,
  }) =>
      MessDish(
        slug: slug,
        name: name,
        label: null,
        diet: diet,
        role: 'other',
        alternatives: const [],
        isAmbient: ambient,
        nutrition: nutrition,
        correctionPending: pending,
      );

  /// A full four-meal menu, published for [date].
  static MessMenu defaultMenu(
    String code,
    String date, {
    MenuResolution? resolution,
    List<MessLoggedDish> logged = const [],
    MessFreshness? freshness,
  }) =>
      MessMenu(
        mess: messOf(code, freshness: freshness),
        date: date,
        today: '2026-09-24',
        resolution: resolution ?? ExactMenu(date),
        logged: logged,
        meals: [
          MessMeal(
            slot: MealSlot.breakfast,
            rawMenu: 'Idly, Sambar, Chutney, Tea',
            dishes: [
              dish('idly', 'Idly'),
              dish('tea', 'Tea', ambient: true),
            ],
          ),
          MessMeal(
            slot: MealSlot.lunch,
            rawMenu:
                'Phulka, Dhal Makhani, Kara Kulambu, Urapadai, Scrambled Egg, Chicken Gravy',
            dishes: [
              dish('phulka', 'Phulka', nutrition: phulka),
              dish('dhal-makhani', 'Dhal Makhani', nutrition: dal),
              dish('kara-kulambu', 'Kara Kulambu', nutrition: kulambu),
              dish('urapadai', 'Urapadai'),
              dish(
                'scrambled-egg',
                'Scrambled Egg',
                nutrition: dal,
                diet: DietClass.egg,
              ),
              dish(
                'veg-puff',
                'Veg Puff',
                nutrition: dal,
                diet: DietClass.unknown,
              ),
            ],
          ),
          MessMeal(
            slot: MealSlot.snacks,
            rawMenu: 'Masala Vada, Tea',
            dishes: [dish('masala-vada', 'Masala Vada', nutrition: dal)],
          ),
          MessMeal(
            slot: MealSlot.dinner,
            rawMenu: 'Chapathi, Curd Rice',
            dishes: [dish('chapathi', 'Chapathi', nutrition: phulka)],
          ),
        ],
      );
}
