import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fitos/core/db/app_database.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/health/presentation/controllers/health_providers.dart';
import 'package:fitos/features/home/presentation/controllers/home_providers.dart';
import 'package:fitos/features/mess/data/mess_repository.dart';
import 'package:fitos/features/mess/domain/mess.dart';
import 'package:fitos/features/mess/presentation/mess_providers.dart';
import 'package:fitos/features/mess/presentation/mess_screen.dart';
import 'package:fitos/features/mess/presentation/widgets/mess_widgets.dart';
import 'package:fitos/features/nutrition/domain/entities/food.dart';
import 'package:fitos/features/nutrition/domain/entities/food_log.dart';
import 'package:fitos/features/nutrition/domain/portion_preview.dart';
import 'package:fitos/features/nutrition/presentation/controllers/food_log_providers.dart';
import 'package:fitos/features/nutrition/presentation/controllers/food_logger.dart';
import 'package:fitos/features/nutrition/presentation/controllers/food_providers.dart';
import 'package:fitos/features/nutrition/presentation/screens/eat_screen.dart';
import 'package:fitos/features/nutrition/presentation/screens/log_food_screen.dart';
import 'package:fitos/features/profile/domain/entities/profile.dart';
import 'package:fitos/features/workout/presentation/controllers/workout_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_food_log_api.dart';
import '../../support/fake_food_repository.dart';
import '../../support/fake_mess_api.dart';

const today = '2026-09-24';

const targets = NutritionTargets(
  effectiveFrom: '2026-09-01',
  kcal: 2400,
  proteinG: 140,
  carbG: 290,
  fatG: 70,
  fiberG: 30,
  bmr: 1700,
  tdeeEstimate: 2500,
  rationale: ['test'],
  reason: 'onboarding',
);

/// The fake server snapshots a mess dish as the real one does: its stored
/// estimate × the portion, rounded outward (checked in the API suite).
FoodLogItem Function(LogMessDishRequest) messSnapshot(
  String name,
  FoodNutrition row,
) =>
    (req) {
      final portion =
          PortionPreview.resolve(row, servings: req.servings, grams: req.grams);
      final p = PortionPreview.scale(row, portion.servings!);
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
        servings: portion.servings!,
        grams: portion.grams,
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

  setUp(() {
    db = AppDatabase.inMemory();
    api = FakeFoodLogApi(todayDate: today, targets: targets);
    api.messSnapshot['phulka'] = messSnapshot('Phulka', FakeMessApi.phulka);
    api.messSnapshot['dhal-makhani'] =
        messSnapshot('Dhal Makhani', FakeMessApi.dal);
    mess = FakeMessApi();
  });

  tearDown(() => db.close());

  final noonIst = DateTime.utc(2026, 9, 24, 7, 30);

  Widget harness({String initial = '/nutrition/mess'}) {
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
      ],
    );
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        foodLogApiProvider.overrideWithValue(api),
        messApiProvider.overrideWithValue(mess),
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
            now: () => noonIst,
          ),
        ),
      ],
      child: MaterialApp.router(theme: FitTheme.build(), routerConfig: router),
    );
  }

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 4200);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> tapDish(WidgetTester tester, String slug) async {
    final dish = find.byKey(ValueKey('mess.dish.$slug'));
    await tester.ensureVisible(dish);
    await settle(tester);
    await tester.tap(dish);
    await settle(tester);
  }

  group('MESS screen', () {
    testWidgets(
        'a published menu: the mess, four meals, dishes with diet and estimate; the published text on request',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(harness());
      await settle(tester);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('mess.title'))).data,
        "Men's Hostel · Vegetarian",
      );
      expect(find.byKey(const ValueKey('mess.date')), findsOneWidget);
      for (final slot in ['breakfast', 'lunch', 'snacks', 'dinner']) {
        expect(find.byKey(ValueKey('mess.meal.$slot')), findsOneWidget);
      }
      expect(find.text('Phulka'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('mess.dish.phulka')),
          matching: find.text('85–120 kcal · 1 piece'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('mess.dish.urapadai')),
          matching: find.text('No estimate yet'),
        ),
        findsOneWidget,
      );
      // Diet marks are labelled; "unknown" is never called veg.
      DietClass dietOf(String slug) => tester
          .widget<DietMark>(
            find.descendant(
              of: find.byKey(ValueKey('mess.dish.$slug')),
              matching: find.byType(DietMark),
            ),
          )
          .diet;
      expect(dietOf('scrambled-egg'), DietClass.egg);
      expect(dietOf('veg-puff'), DietClass.unknown);
      expect(dietOf('phulka'), DietClass.veg);
      // No qualifier on a published menu.
      expect(find.byKey(const ValueKey('mess.inferred')), findsNothing);
      expect(find.byKey(const ValueKey('mess.stale')), findsNothing);
      // The mess's own words, verbatim, behind a toggle (owner D20).
      expect(find.byKey(const ValueKey('mess.raw.lunch.text')), findsNothing);
      await tester.ensureVisible(find.byKey(const ValueKey('mess.raw.lunch')));
      await tester.tap(find.byKey(const ValueKey('mess.raw.lunch')));
      await settle(tester);
      expect(
        find.text(
          'Phulka, Dhal Makhani, Kara Kulambu, Urapadai, Scrambled Egg, Chicken Gravy',
        ),
        findsOneWidget,
      );
      expect(mess.calls.first, 'menu mine $today');
    });

    testWidgets(
        'an inferred menu always carries its banner, with the source date (§14.4)',
        (tester) async {
      tall(tester);
      mess.menus['mens-veg/$today'] = FakeMessApi.defaultMenu(
        'mens-veg',
        today,
        resolution: const InferredMenu(
          today,
          sourceDate: '2026-09-10',
          cycleLengthDays: 14,
        ),
      );
      await tester.pumpWidget(harness());
      await settle(tester);
      expect(find.byKey(const ValueKey('mess.inferred')), findsOneWidget);
      expect(find.textContaining('menu of Thu 10 Sep'), findsOneWidget);
      expect(find.textContaining('It may differ'), findsOneWidget);
    });

    testWidgets(
        'an unavailable day says so, with the latest published date; a stale copy says when it was fetched',
        (tester) async {
      tall(tester);
      final menu = FakeMessApi.defaultMenu(
        'mens-veg',
        today,
        resolution: const UnavailableMenu(today, latestAvailable: '2026-08-31'),
        freshness: const MessFreshness(
          lastSuccessAt: '2026-09-20T06:00:00.000Z',
          lastAttemptAt: '2026-09-24T06:00:00.000Z',
          lastError: MirrorError.unreachable,
          stale: true,
          latestPublishedDate: '2026-08-31',
        ),
      );
      mess.menus['mens-veg/$today'] = MessMenu(
        mess: menu.mess,
        date: today,
        today: today,
        resolution: menu.resolution,
        meals: const [],
        logged: const [],
      );
      await tester.pumpWidget(harness());
      await settle(tester);
      expect(find.byKey(const ValueKey('mess.unavailable')), findsOneWidget);
      expect(find.textContaining('Mon 31 Aug'), findsOneWidget);
      expect(find.byKey(const ValueKey('mess.stale')), findsOneWidget);
      expect(find.textContaining('last fetched this menu'), findsOneWidget);
    });

    testWidgets('no mess configured: "Choose your mess"', (tester) async {
      tall(tester);
      mess.mine = null;
      await tester.pumpWidget(harness());
      await settle(tester);
      expect(find.byKey(const ValueKey('mess.notConfigured')), findsOneWidget);
      expect(find.byKey(const ValueKey('mess.choose')), findsOneWidget);
    });

    testWidgets(
        'offline: the menu saved on this phone is shown, marked as saved (owner D18)',
        (tester) async {
      tall(tester);
      // First visit online caches today and (ahead) tomorrow.
      final repo = MessRepository(db, mess);
      await repo.menu(today);
      await repo.menu('2026-09-25');
      mess.offline = true;
      await tester.pumpWidget(harness());
      await settle(tester);
      expect(find.byKey(const ValueKey('mess.offline')), findsOneWidget);
      expect(find.text('Phulka'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('mess.next')));
      await settle(tester);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('mess.date'))).data,
        'Tomorrow',
      );
      expect(find.text('Phulka'), findsOneWidget);
      expect(find.byKey(const ValueKey('mess.offline')), findsOneWidget);
    });

    testWidgets('browsing another mess never changes the setting (owner D14)',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(harness());
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('mess.switch')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('mess.pick.womens-special')));
      await settle(tester);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('mess.title'))).data,
        "Women's Hostel · Special",
      );
      expect(find.byKey(const ValueKey('mess.browsing')), findsOneWidget);
      expect(mess.calls, contains('menu womens-special $today'));
      await tester.tap(find.text('Mine'));
      await settle(tester);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('mess.title'))).data,
        "Men's Hostel · Vegetarian",
      );
    });
  });

  group('logging a dish', () {
    testWidgets(
        'tap → portion step with the estimate note → log: the request names the dish, never numbers; the server snapshot lands in the day',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(harness());
      await settle(tester);
      await tapDish(tester, 'phulka');
      expect(find.byKey(const ValueKey('portion.sheet')), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('mess.estimateNote')))
            .data,
        'Mess estimate · medium confidence · fibre not known',
      );
      expect(find.byKey(const ValueKey('mess.report')), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('portion.amount')), '3');
      await settle(tester);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('portion.preview.kcal')))
            .data,
        '255–360 kcal',
      );
      await tester.tap(find.byKey(const ValueKey('portion.log')));
      await settle(tester);
      final create = api.logs.values.single;
      expect(create.entryMethod, EntryMethod.mess);
      expect(create.messCode, 'mens-veg');
      expect(create.mealSlot, MealSlot.lunch);
      expect(create.items.single.messDishSlug, 'phulka');
      expect(create.items.single.kcalLow, 255);
      expect(create.items.single.kcalHigh, 360);
      // The queued request itself carried no nutrition.
      final queued = await db.select(db.localFoodLogs).get();
      expect(queued, isEmpty); // synced
      expect(find.text('Logged Phulka.'), findsOneWidget);
    });

    testWidgets('grams only when the serving has a weight', (tester) async {
      tall(tester);
      await tester.pumpWidget(harness());
      await settle(tester);
      await tapDish(tester, 'kara-kulambu');
      expect(find.byKey(const ValueKey('portion.mode.Grams')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('portion.sheet')));
      Navigator.of(tester.element(find.byKey(const ValueKey('portion.sheet'))))
          .pop();
      await settle(tester);
      await tapDish(tester, 'dhal-makhani');
      expect(find.byKey(const ValueKey('portion.mode.Grams')), findsOneWidget);
    });

    testWidgets(
        'a dish with no estimate cannot be tap-logged, and says why; a future day is view-only',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(harness());
      await settle(tester);
      await tapDish(tester, 'urapadai');
      expect(find.byKey(const ValueKey('mess.info')), findsOneWidget);
      expect(find.textContaining('no estimate for this dish'), findsOneWidget);
      expect(find.byKey(const ValueKey('portion.sheet')), findsNothing);
      Navigator.of(tester.element(find.byKey(const ValueKey('mess.info'))))
          .pop();
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('mess.next')));
      await settle(tester);
      await tapDish(tester, 'phulka');
      expect(find.textContaining('has not happened yet'), findsOneWidget);
      expect(api.logs, isEmpty);
    });

    testWidgets(
        'offline, a dish logs to the queue and shows as not synced; it reaches the server once back online',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(harness());
      await settle(tester);
      api.offline = true;
      await tapDish(tester, 'dhal-makhani');
      await tester.tap(find.byKey(const ValueKey('portion.log')));
      await settle(tester);
      final local = await db.select(db.localFoodLogs).get();
      expect(local, hasLength(1));
      expect(local.single.requestJson, contains('"entryMethod":"mess"'));
      expect(local.single.requestJson, contains('"dishSlug":"dhal-makhani"'));
      expect(local.single.requestJson, isNot(contains('kcal')));
      api.offline = false;
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MessScreen)),
      );
      container.read(nutritionLogRepositoryProvider).sync();
      await settle(tester);
      expect(api.logs.values.single.items.single.messDishSlug, 'dhal-makhani');
      expect(await db.select(db.localFoodLogs).get(), isEmpty);
    });

    testWidgets('a logged dish is ticked on the menu', (tester) async {
      tall(tester);
      mess.menus['mens-veg/$today'] = FakeMessApi.defaultMenu(
        'mens-veg',
        today,
        logged: const [
          MessLoggedDish(
            dishSlug: 'phulka',
            mealSlot: MealSlot.lunch,
            clientLogId: 'c',
          ),
        ],
      );
      await tester.pumpWidget(harness());
      await settle(tester);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('mess.dish.phulka')),
          matching: find.byKey(const ValueKey('mess.logged')),
        ),
        findsOneWidget,
      );
    });
  });

  group('corrections (owner D17)', () {
    testWidgets(
        'report wrong nutrition: sent as pending; the estimate on screen is unchanged',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(harness());
      await settle(tester);
      await tapDish(tester, 'phulka');
      await tester.tap(find.byKey(const ValueKey('mess.report')));
      await settle(tester);
      expect(find.byKey(const ValueKey('mess.correction')), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('correction.low')),
        '150',
      );
      await tester.enterText(
        find.byKey(const ValueKey('correction.high')),
        '200',
      );
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('correction.send')));
      await settle(tester);
      expect(mess.corrections, hasLength(1));
      final (slug, req) = mess.corrections.single;
      expect(slug, 'phulka');
      expect(req.toJson(), {
        'clientCorrectionId': req.clientCorrectionId,
        'field': 'kcal',
        'low': 150.0,
        'high': 200.0,
      });
      expect(find.textContaining('pending review'), findsOneWidget);
    });

    testWidgets('a pending report is shown on the dish', (tester) async {
      tall(tester);
      final base = FakeMessApi.defaultMenu('mens-veg', today);
      mess.menus['mens-veg/$today'] = MessMenu(
        mess: base.mess,
        date: today,
        today: today,
        resolution: base.resolution,
        logged: const [],
        meals: [
          MessMeal(
            slot: MealSlot.lunch,
            rawMenu: 'Phulka',
            dishes: [
              FakeMessApi.dish(
                'phulka',
                'Phulka',
                nutrition: FakeMessApi.phulka,
                pending: true,
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(harness());
      await settle(tester);
      expect(
        find.text('85–120 kcal · 1 piece · report pending'),
        findsOneWidget,
      );
      await tapDish(tester, 'phulka');
      expect(find.byKey(const ValueKey('mess.reportPending')), findsOneWidget);
      expect(find.byKey(const ValueKey('mess.report')), findsNothing);
    });
  });

  group('EAT and the log sheet', () {
    testWidgets(
        "EAT shows today's mess (the meal of the hour); tapping opens the menu",
        (tester) async {
      tall(tester);
      await tester.pumpWidget(harness(initial: '/nutrition'));
      await settle(tester);
      expect(find.byKey(const ValueKey('eat.mess')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('eat.mess.line'))).data,
        'Lunch · 6 dishes',
      );
      await tester.tap(find.byKey(const ValueKey('eat.mess')));
      await settle(tester);
      expect(find.byType(MessScreen), findsOneWidget);
    });

    testWidgets('EAT marks an inferred menu', (tester) async {
      tall(tester);
      mess.menus['mens-veg/$today'] = FakeMessApi.defaultMenu(
        'mens-veg',
        today,
        resolution: const InferredMenu(
          today,
          sourceDate: '2026-09-10',
          cycleLengthDays: 14,
        ),
      );
      await tester.pumpWidget(harness(initial: '/nutrition'));
      await settle(tester);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('eat.mess.line'))).data,
        'Lunch · 6 dishes · inferred',
      );
    });

    testWidgets('EAT has no mess strip without a mess', (tester) async {
      tall(tester);
      mess.mine = null;
      await tester.pumpWidget(harness(initial: '/nutrition'));
      await settle(tester);
      expect(find.byKey(const ValueKey('eat.mess')), findsNothing);
    });

    testWidgets(
        'the log sheet opens on Mess for a user with a mess; a dish logs to the chosen meal',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(harness(initial: '/nutrition'));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('eat.log')));
      await settle(tester);
      expect(find.byKey(const ValueKey('log.source.Mess')), findsOneWidget);
      expect(find.byKey(const ValueKey('mess.dish.phulka')), findsOneWidget);
      // Dinner's dishes when Dinner is chosen.
      await tester.tap(find.byKey(const ValueKey('log.slot.Dinner')));
      await settle(tester);
      expect(find.byKey(const ValueKey('mess.dish.chapathi')), findsOneWidget);
      expect(find.byKey(const ValueKey('mess.dish.phulka')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('log.slot.Lunch')));
      await settle(tester);
      await tapDish(tester, 'phulka');
      await tester.tap(find.byKey(const ValueKey('portion.log')));
      await settle(tester);
      expect(api.logs.values.single.items.single.messDishSlug, 'phulka');
      expect(find.byType(EatScreen), findsOneWidget);
    });

    testWidgets(
        'a saved meal with a mess dish previews it as a range and logs it as a mess dish (owner D11)',
        (tester) async {
      tall(tester);
      mess.mine = null;
      api.meals = [
        const SavedMeal(
          id: 'm1',
          clientMealId: 'c1',
          name: 'Mess lunch',
          createdAt: '2026-09-23T07:30:00.000Z',
          items: [
            SavedMessItem(
              dishSlug: 'dhal-makhani',
              dishName: 'Dhal Makhani',
              servings: 2,
              row: FakeMessApi.dal,
            ),
          ],
        ),
      ];
      await tester.pumpWidget(harness(initial: '/nutrition'));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('eat.log')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('log.source.Saved meals')));
      await settle(tester);
      expect(find.textContaining('360–520 kcal'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('saved.m1.log')));
      await settle(tester);
      final item = api.logs.values.single.items.single;
      expect(item.messDishSlug, 'dhal-makhani');
      expect([item.kcalLow, item.kcalHigh], [360, 520]);
    });
  });
}
