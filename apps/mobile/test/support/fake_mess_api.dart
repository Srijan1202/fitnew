import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/features/mess/data/mess_api.dart';
import 'package:fitos/features/mess/domain/mess.dart';
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
