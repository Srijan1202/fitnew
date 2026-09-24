import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fitos/core/db/app_database.dart';
import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/health/presentation/controllers/health_providers.dart';
import 'package:fitos/features/home/presentation/controllers/home_providers.dart';
import 'package:fitos/features/mess/domain/mess.dart';
import 'package:fitos/features/mess/domain/recommendation.dart';
import 'package:fitos/features/mess/presentation/mess_providers.dart';
import 'package:fitos/features/mess/presentation/mess_screen.dart';
import 'package:fitos/features/mess/presentation/widgets/recommend_words.dart';
import 'package:fitos/features/nutrition/domain/entities/food.dart';
import 'package:fitos/features/nutrition/domain/entities/food_log.dart';
import 'package:fitos/features/nutrition/domain/portion_preview.dart';
import 'package:fitos/features/nutrition/presentation/controllers/food_log_providers.dart';
import 'package:fitos/features/nutrition/presentation/controllers/food_logger.dart';
import 'package:fitos/features/nutrition/presentation/controllers/food_providers.dart';
import 'package:fitos/features/nutrition/presentation/screens/eat_screen.dart';
import 'package:fitos/features/nutrition/presentation/screens/log_food_screen.dart';
import 'package:fitos/features/profile/data/profile_repository.dart';
import 'package:fitos/features/profile/domain/entities/profile.dart';
import 'package:fitos/features/profile/domain/entities/vocabulary.dart';
import 'package:fitos/features/profile/presentation/screens/food_preferences_screen.dart';
import 'package:fitos/features/workout/presentation/controllers/workout_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_food_log_api.dart';
import '../../support/fake_food_repository.dart';
import '../../support/fake_mess_api.dart';
import '../../support/fake_profile_repository.dart';

const today = '2026-09-24';
const tomorrow = '2026-09-25';

/// The fake server snapshots a mess dish as its stored estimate × servings.
FoodLogItem Function(LogMessDishRequest) snap(String name, FoodNutrition row) =>
    (req) {
      final p = PortionPreview.scale(row, req.servings!);
      return FoodLogItem(
        id: 'i-${req.dishSlug}',
        position: 0,
        foodId: null,
        messDishSlug: req.dishSlug,
        foodName: name,
        foodSource: FoodSource.estimated,
        basis: NutritionBasis.perServing,
        servingLabel: row.servingLabel,
        servingGrams: row.servingGrams,
        servings: req.servings!,
        grams: null,
        kcalLow: p.kcalLow,
        kcalHigh: p.kcalHigh,
        proteinLow: p.proteinLow,
        proteinHigh: p.proteinHigh,
        carbLow: p.carbLow,
        carbHigh: p.carbHigh,
        fatLow: p.fatLow,
        fatHigh: p.fatHigh,
        fibreLow: null,
        fibreHigh: null,
        confidence: row.confidence,
      );
    };

void main() {
  late AppDatabase db;
  late FakeFoodLogApi api;
  late FakeMessApi mess;
  late FakeProfileRepository profile;

  setUp(() {
    db = AppDatabase.inMemory();
    api = FakeFoodLogApi(todayDate: today);
    api.messSnapshot['phulka'] = snap('Phulka', FakeMessApi.phulka);
    api.messSnapshot['dhal-makhani'] = snap('Dhal Makhani', FakeMessApi.dal);
    mess = FakeMessApi();
    profile = FakeProfileRepository();
  });
  tearDown(() => db.close());

  Widget harness({String initial = '/nutrition/mess', double textScale = 1}) {
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: '/nutrition',
          builder: (_, __) => const EatScreen(),
          routes: [
            GoRoute(
              path: 'log',
              builder: (_, s) => LogFoodScreen(
                target: s.extra is LogTarget ? s.extra! as LogTarget : null,
              ),
            ),
            GoRoute(path: 'mess', builder: (_, __) => const MessScreen()),
            GoRoute(
              path: 'library',
              builder: (_, __) => const Scaffold(body: Text('LIBRARY')),
            ),
          ],
        ),
        GoRoute(
          path: '/profile/food',
          builder: (_, __) => const FoodPreferencesScreen(),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        foodLogApiProvider.overrideWithValue(api),
        messApiProvider.overrideWithValue(mess),
        profileRepositoryProvider.overrideWithValue(profile),
        foodRepositoryProvider.overrideWithValue(FakeFoodRepository()),
        connectivityStreamProvider.overrideWithValue(
          const Stream<List<ConnectivityResult>>.empty(),
        ),
        syncWakesItselfProvider.overrideWithValue(false),
        sessionUserIdProvider.overrideWithValue('user-1'),
        localTodayProvider.overrideWithValue(today),
        localHourProvider.overrideWithValue(13),
        userTimezoneProvider.overrideWithValue('Asia/Kolkata'),
        foodLoggerProvider.overrideWith(
          (ref) => FoodLogger(
            ref.watch(nutritionLogRepositoryProvider),
            zone: 'Asia/Kolkata',
            today: today,
            now: () => DateTime.utc(2026, 9, 24, 7, 30),
          ),
        ),
      ],
      child: MaterialApp.router(
        theme: FitTheme.build(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    );
  }

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 5200);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await settle(tester);
    await tester.tap(f);
    await settle(tester);
  }

  String text(WidgetTester tester, String key) => tester
      .widget<Text>(
        find
            .descendant(
              of: find.byKey(ValueKey(key)),
              matching: find.byType(Text),
              matchRoot: true,
            )
            .first,
      )
      .data!;

  group('What should I eat?', () {
    testWidgets(
        'a plate: the thali, dishes with servings, ranges, confidence, worded reasons, and the filters',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(harness());
      await settle(tester);
      expect(find.byKey(const ValueKey('rec.section')), findsOneWidget);
      expect(find.byKey(const ValueKey('rec.thali.1')), findsOneWidget);
      expect(find.byKey(const ValueKey('rec.item.phulka')), findsOneWidget);
      expect(find.text('3 × 1 piece'), findsOneWidget);
      expect(text(tester, 'rec.kcal'), '435–620 kcal');
      expect(text(tester, 'rec.protein'), '14.5–20.8 g');
      expect(
        text(tester, 'rec.confidence'),
        'Estimate · medium confidence · fibre not known',
      );
      expect(
        find.text(
          '· Weighted for muscle gain: falling short on calories counts more than going over a little.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          '· Dhal Makhani is the most protein-dense dish on this plate.',
        ),
        findsOneWidget,
      );
      expect(text(tester, 'rec.filters.text'), 'Vegetarian · no allergies set');
      expect(find.byKey(const ValueKey('rec.crossContact')), findsNothing);
      expect(mess.recommendCalls.single, 'recommend mine $today default');
    });

    testWidgets(
        'allergies: "no known … ingredient" and the cross-contact note (requirement 4)',
        (tester) async {
      tall(tester);
      mess.recommendations['$today/default'] =
          FakeMessApi.defaultRecommendation(
        'mens-veg',
        today,
        allergies: const [Allergen.peanut, Allergen.milk],
      );
      await tester.pumpWidget(harness());
      await settle(tester);
      expect(
        text(tester, 'rec.filters.text'),
        'Vegetarian · no known peanut or milk ingredient',
      );
      expect(
        text(tester, 'rec.crossContact'),
        'Ingredient status confirmed by FITOS rules from dish names. Shared mess kitchens can have cross-contact FITOS cannot rule out.',
      );
    });

    testWidgets(
        'Log this plate: ONE mess log, one item per dish at whole servings, for today',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(harness());
      await settle(tester);
      await tap(tester, find.byKey(const ValueKey('rec.log')));
      final log = api.logs.values.single;
      expect(log.entryMethod, EntryMethod.mess);
      expect(log.messCode, 'mens-veg');
      expect(log.mealSlot, MealSlot.lunch);
      expect(
        log.items.map((i) => [i.messDishSlug, i.servings]).toList(),
        [
          ['phulka', 3.0],
          ['dhal-makhani', 1.0],
        ],
      );
      expect(find.text('Logged plate 1 to Lunch.'), findsOneWidget);
    });

    testWidgets(
        'offline: the queued plate log carries no numbers, and syncs once',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(harness());
      await settle(tester);
      api.offline = true;
      await tap(tester, find.byKey(const ValueKey('rec.log')));
      final local = await db.select(db.localFoodLogs).get();
      expect(local, hasLength(1));
      expect(local.single.requestJson, contains('"entryMethod":"mess"'));
      expect(local.single.requestJson, isNot(contains('kcal')));
      api.offline = false;
      ProviderScope.containerOf(tester.element(find.byType(MessScreen)))
          .read(nutritionLogRepositoryProvider)
          .sync();
      await settle(tester);
      expect(api.logs, hasLength(1));
    });

    testWidgets('tomorrow: a planning plate, no log button', (tester) async {
      tall(tester);
      mess.recommendations['$tomorrow/default'] =
          FakeMessApi.defaultRecommendation(
        'mens-veg',
        tomorrow,
        slot: MealSlot.breakfast,
        loggable: false,
      );
      await tester.pumpWidget(harness());
      await settle(tester);
      await tap(tester, find.byKey(const ValueKey('mess.next')));
      expect(mess.recommendCalls.last, 'recommend mine $tomorrow default');
      expect(find.byKey(const ValueKey('rec.log')), findsNothing);
      expect(
        text(tester, 'rec.planning'),
        'Planning for Fri 25 Sep — log it on the day.',
      );
    });

    testWidgets('a past day or two days ahead: no request, just the rule',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(harness());
      await settle(tester);
      mess.recommendCalls.clear();
      await tap(tester, find.byKey(const ValueKey('mess.prev')));
      expect(find.byKey(const ValueKey('rec.outOfRange')), findsOneWidget);
      expect(mess.recommendCalls, isEmpty);
    });

    testWidgets(
        'offline: a connection-needed state — never the earlier plate (requirement 22)',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(harness());
      await settle(tester);
      expect(find.byKey(const ValueKey('rec.thali.1')), findsOneWidget);
      mess.offline = true;
      ProviderScope.containerOf(tester.element(find.byType(MessScreen)))
          .invalidate(messRecommendProvider);
      await settle(tester);
      expect(find.byKey(const ValueKey('rec.offline')), findsOneWidget);
      expect(find.byKey(const ValueKey('rec.thali.1')), findsNothing);
      expect(find.byKey(const ValueKey('rec.log')), findsNothing);
    });

    testWidgets(
        'scrolling the menu away and back keeps the chosen plate — no refetch',
        (tester) async {
      tester.view.physicalSize = const Size(360 * 2.0, 640 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(harness(textScale: 2));
      await settle(tester);
      await tap(tester, find.byKey(const ValueKey('rec.plate.2')));
      final list = find.byType(Scrollable).first;
      // To the very end of the menu: far past the list's cache extent.
      for (var i = 0; i < 30; i++) {
        await tester.drag(list, const Offset(0, -600));
        await settle(tester);
      }
      // Scrolled far past the cache extent: the section is off screen but
      // kept, not rebuilt.
      expect(find.byKey(const ValueKey('rec.section')), findsNothing);
      expect(
        find.byKey(const ValueKey('rec.section'), skipOffstage: false),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('rec.thali.2')),
        -400,
        scrollable: list,
      );
      await settle(tester);
      expect(find.byKey(const ValueKey('rec.thali.2')), findsOneWidget);
      expect(mess.recommendCalls, hasLength(1));
    });

    testWidgets('choosing a meal asks for that meal', (tester) async {
      tall(tester);
      await tester.pumpWidget(harness());
      await settle(tester);
      await tap(tester, find.byKey(const ValueKey('rec.slot.Dinner')));
      expect(mess.recommendCalls.last, 'recommend mine $today dinner');
    });

    testWidgets(
        'other plates can be shown; "Why not" explains every dish left off',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(harness());
      await settle(tester);
      await tap(tester, find.byKey(const ValueKey('rec.plate.2')));
      expect(find.byKey(const ValueKey('rec.thali.2')), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('rec.whyNot')));
      expect(find.text('Egg — not vegetarian.'), findsOneWidget);
      expect(find.text('or Paneer Bhurji — veg'), findsOneWidget);
      expect(find.text('Contains peanut.'), findsOneWidget);
    });

    testWidgets('an honest shortfall with its range', (tester) async {
      tall(tester);
      mess.recommendations['$today/default'] =
          FakeMessApi.defaultRecommendation(
        'mens-veg',
        today,
        proteinShortfall: const Gap(
          target: 85,
          gapLow: 45.3,
          gapHigh: 60,
          menuMax: 46,
          menuCanMeet: false,
        ),
      );
      await tester.pumpWidget(harness());
      await settle(tester);
      expect(
        text(tester, 'rec.shortfall.protein'),
        '45.3–60 g protein below this meal\'s 85 g. No plate from this menu reaches it (at most 46 g).',
      );
    });

    for (final (status, key) in [
      (RecommendationStatus.noTargets, 'rec.noTargets'),
      (RecommendationStatus.targetReached, 'rec.targetReached'),
      (RecommendationStatus.menuUnavailable, 'rec.unavailable'),
      (RecommendationStatus.mealNotServed, 'rec.notServed'),
      (RecommendationStatus.nothingSafe, 'rec.nothingSafe'),
      (RecommendationStatus.nothingFits, 'rec.nothingFits'),
    ]) {
      testWidgets('status ${status.wire}: its own message, and no plate',
          (tester) async {
        tall(tester);
        mess.recommendations['$today/default'] =
            FakeMessApi.defaultRecommendation(
          'mens-veg',
          today,
          status: status,
        );
        await tester.pumpWidget(harness());
        await settle(tester);
        expect(find.byKey(ValueKey(key)), findsOneWidget);
        expect(find.byKey(const ValueKey('rec.log')), findsNothing);
        expect(find.byKey(const ValueKey('rec.thali.1')), findsNothing);
      });
    }

    testWidgets('zero budget still names the protein still needed',
        (tester) async {
      tall(tester);
      mess.recommendations['$today/default'] =
          FakeMessApi.defaultRecommendation(
        'mens-veg',
        today,
        status: RecommendationStatus.targetReached,
        target:
            const MealTarget(share: 1, kcal: 0, protein: 40, carb: 0, fat: 0),
      );
      await tester.pumpWidget(harness());
      await settle(tester);
      expect(text(tester, 'rec.targetReached'), contains('about 40 g protein'));
    });

    testWidgets('an inferred menu and an already-logged meal are both said',
        (tester) async {
      tall(tester);
      mess.recommendations['$today/default'] =
          FakeMessApi.defaultRecommendation(
        'mens-veg',
        today,
        basis: 'inferred',
        slotAlreadyLogged: true,
      );
      await tester.pumpWidget(harness());
      await settle(tester);
      expect(find.byKey(const ValueKey('rec.inferred')), findsOneWidget);
      expect(find.byKey(const ValueKey('rec.alreadyLogged')), findsOneWidget);
    });

    testWidgets('EAT links to today\'s suggestion', (tester) async {
      tall(tester);
      await tester.pumpWidget(harness(initial: '/nutrition'));
      await settle(tester);
      await tap(tester, find.byKey(const ValueKey('eat.mess.suggest')));
      expect(find.byType(MessScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('rec.section')), findsOneWidget);
    });
  });

  group('Profile → Food (diet and allergies)', () {
    testWidgets('edit and save: one PUT with the list; suggestions refetch',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(harness(initial: '/profile/food'));
      await settle(tester);
      await tap(tester, find.text('Eggetarian'));
      await tap(tester, find.byKey(const ValueKey('food.allergen.peanut')));
      await tap(tester, find.text('Severe'));
      await tap(tester, find.byKey(const ValueKey('food.save')));
      expect(profile.dietChanges.single, {
        'dietType': 'eggetarian',
        'allergies': ['peanut:severe'],
      });
    });

    testWidgets('a failed save says why and keeps the form', (tester) async {
      tall(tester);
      profile.failDiet = const Offline();
      await tester.pumpWidget(harness(initial: '/profile/food'));
      await settle(tester);
      await tap(tester, find.byKey(const ValueKey('food.save')));
      expect(find.text('Saving needs a connection.'), findsOneWidget);
      expect(find.byKey(const ValueKey('food.list')), findsOneWidget);
    });

    test('the summary line', () {
      expect(
        foodSummary(
          const DietPreferences(
            dietType: DietType.vegetarian,
            allergies: [
              Allergy(
                allergen: Allergen.peanut,
                severity: AllergySeverity.severe,
              ),
            ],
            excludedDishIds: [],
            budgetTier: null,
          ),
        ),
        'Vegetarian · peanut (severe)',
      );
    });
  });

  group('reason wording', () {
    const codes = <String, Map<String, dynamic>>{
      'protein-covers': {'target': 40, 'low': 42},
      'protein-may-fall-short': {'target': 40, 'low': 30, 'high': 45},
      'protein-short': {'target': 85, 'high': 39.7},
      'kcal-within': {'target': 900, 'high': 800},
      'kcal-may-exceed': {'target': 900, 'low': 800, 'high': 1000},
      'kcal-over': {'target': 900, 'low': 950},
      'carb-within': {'target': 100, 'high': 90},
      'carb-over': {'target': 100, 'low': 110, 'high': 130},
      'fat-within': {'target': 25, 'high': 20},
      'fat-over': {'target': 25, 'low': 26, 'high': 40},
      'goal-weighting': {'goal': 'recomposition'},
      'top-protein-dish': {'dishSlug': 'dal'},
      'post-workout-carbs': {'target': 100, 'low': 90, 'high': 120},
      'repeat': {'dishSlug': 'dal', 'days': 2},
      'low-confidence-dish': {'dishSlug': 'dal'},
      'inferred-menu': {'sourceDate': '2026-09-18'},
    };
    test('every plate code has words (never the raw code)', () {
      for (final e in codes.entries) {
        final t =
            ReasonText.plate(Reason(e.key, e.value), const {'dal': 'Dal'});
        expect(t, isNot(e.key), reason: e.key);
        expect(t, isNot(contains('?')), reason: e.key);
      }
      expect(
        ReasonText.plate(
          const Reason('goal-weighting', {'goal': 'recomposition'}),
          const {},
        ),
        'Weighted for recomposition: going over calories counts more than staying under.',
      );
      expect(
        ReasonText.plate(
          const Reason('repeat', {'dishSlug': 'dal', 'days': 2}),
          const {'dal': 'Dal'},
        ),
        'Dal: you had it on 2 of the last 3 days.',
      );
    });
    test('dish codes', () {
      const d = DietType.vegetarian;
      expect(
        ReasonText.dish(const Reason('diet', {'dietClass': 'unknown'}), d),
        'Diet not known — never offered to a vegetarian plate.',
      );
      expect(
        ReasonText.dish(
          const Reason(
            'allergen',
            {'allergen': 'tree-nut', 'status': 'likely'},
          ),
          d,
        ),
        'Likely contains tree nuts.',
      );
      expect(
        ReasonText.dish(
          const Reason('allergen', {'allergen': 'milk', 'status': 'unknown'}),
          d,
        ),
        'Not confirmed free of milk.',
      );
      expect(
        ReasonText.dish(
          const Reason('allergen-alternative', {
            'alternative': 'Peanut Rice',
            'allergen': 'peanut',
            'status': 'contains',
          }),
          d,
        ),
        'Its alternative Peanut Rice: contains peanut.',
      );
      expect(
        ReasonText.dish(const Reason('ambient', {}), d),
        'Served with every meal — not part of the plate. You can still log it.',
      );
    });
  });

  group('layout (S24 and a small phone, 100 % and 200 % text)', () {
    const s24 = (w: 411.0, h: 891.0, dpr: 2.625);
    const small = (w: 360.0, h: 640.0, dpr: 2.0);
    for (final size in [s24, small]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
            '${size.w.toInt()}×${size.h.toInt()} @ ${scale}x: MESS with a plate, a shortfall and Why not; the Food editor — no overflow',
            (tester) async {
          tester.view.physicalSize = Size(size.w * size.dpr, size.h * size.dpr);
          tester.view.devicePixelRatio = size.dpr;
          addTearDown(tester.view.reset);
          mess.recommendations['$today/default'] =
              FakeMessApi.defaultRecommendation(
            'mens-veg',
            today,
            allergies: const [Allergen.peanut, Allergen.treeNut, Allergen.milk],
            proteinShortfall: const Gap(
              target: 85,
              gapLow: 45.3,
              gapHigh: 60,
              menuMax: 46,
              menuCanMeet: false,
            ),
          );
          await tester.pumpWidget(harness(textScale: scale));
          await settle(tester);
          expect(tester.takeException(), isNull);
          for (final k in [
            'rec.thali.1',
            'rec.shortfall',
            'rec.log',
            'rec.whyNot',
          ]) {
            await tester.scrollUntilVisible(
              find.byKey(ValueKey(k)),
              200,
              scrollable: find.byType(Scrollable).first,
            );
            await settle(tester);
            expect(tester.takeException(), isNull, reason: k);
          }
          await tester.tap(find.byKey(const ValueKey('rec.whyNot')));
          await settle(tester);
          expect(tester.takeException(), isNull);

          await tester
              .pumpWidget(harness(initial: '/profile/food', textScale: scale));
          await settle(tester);
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('food.allergen.mustard')),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(find.byKey(const ValueKey('food.allergen.mustard')));
          await settle(tester);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  test('status wire names match the contract', () {
    expect(
      RecommendationStatus.values.map((s) => s.wire).toList(),
      [
        'ok',
        'no-targets',
        'target-reached',
        'menu-unavailable',
        'meal-not-served',
        'nothing-safe',
        'nothing-fits',
      ],
    );
    expect(
      DietClass.values.map((d) => d.wire),
      containsAll(['veg', 'egg', 'nonveg', 'unknown']),
    );
  });
}
