import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fitos/core/db/app_database.dart';
import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/health/presentation/controllers/health_providers.dart';
import 'package:fitos/features/home/presentation/controllers/home_providers.dart';
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

/// The fake server snapshots a food as the real one does (row × portion,
/// the core rounding the preview mirrors — checked in portion_preview_test).
FoodLogItem Function(LogFoodItemRequest) serverSnapshot(Food food) => (req) {
      final row = food.nutrition.firstWhere(
        (r) => r.servingLabel == req.servingLabel && r.basis == req.basis,
      );
      final portion = PortionPreview.resolve(
        row,
        servings: req.servings,
        grams: req.grams,
      );
      final p = PortionPreview.scale(row, portion.servings!);
      return FoodLogItem(
        id: 'i-${food.slug}',
        position: 0,
        foodId: food.id,
        foodName: food.name,
        foodSource: food.source,
        basis: row.basis,
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
        fibreLow: p.fibreLow,
        fibreHigh: p.fibreHigh,
        confidence: row.confidence,
      );
    };

void main() {
  late AppDatabase db;
  late FakeFoodLogApi api;
  late FakeFoodRepository foods;

  setUp(() {
    db = AppDatabase.inMemory();
    api = FakeFoodLogApi(todayDate: today, targets: targets);
    api.snapshot[dalTadka.id] = serverSnapshot(dalTadka);
    api.snapshot[honey.id] = serverSnapshot(honey);
    foods = FakeFoodRepository();
  });

  tearDown(() => db.close());

  /// 13:00 IST on the test's today.
  final noonIst = DateTime.utc(2026, 9, 24, 7, 30);

  Widget harness() {
    final router = GoRouter(
      initialLocation: '/nutrition',
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
        foodRepositoryProvider.overrideWithValue(foods),
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

  /// Drift's streams and the scripted server resolve over a few pumps; a
  /// progress indicator never settles, so no `pumpAndSettle`.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Text textOf(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(ValueKey(key)));

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(EatScreen)));

  Future<void> seedServerLog(CreateLogRequest request) async {
    await api.createLog(request);
    api.calls.clear();
  }

  CreateLogRequest quick(
    String id, {
    double kcal = 250,
    double? fibre,
    MealSlot slot = MealSlot.lunch,
  }) =>
      CreateLogRequest.quickAdd(
        clientLogId: id,
        loggedAt: '2026-09-24T07:30:00.000Z',
        mealSlot: slot,
        quickAdd: QuickAdd(
          kcal: kcal,
          proteinG: 10,
          carbG: 30,
          fatG: 9,
          fibreG: fibre,
        ),
      );

  Future<void> openLog(WidgetTester tester, String source) async {
    await tester.tap(find.byKey(const ValueKey('eat.log')));
    await settle(tester);
    await tester.tap(find.byKey(ValueKey('log.source.$source')));
    await settle(tester);
  }

  Future<void> quickAdd(WidgetTester tester, {String kcal = '250'}) async {
    await openLog(tester, 'Quick add');
    await tester.enterText(find.byKey(const ValueKey('quick.kcal')), kcal);
    await tester.enterText(find.byKey(const ValueKey('quick.protein')), '10');
    await tester.enterText(find.byKey(const ValueKey('quick.carb')), '30');
    await tester.enterText(find.byKey(const ValueKey('quick.fat')), '9');
    await tester.tap(find.byKey(const ValueKey('quick.log')));
    await settle(tester);
  }

  /// Nothing on EAT may be a fake total: every number has a label, and an
  /// unknown fibre never reads "0 g".
  group('the day', () {
    testWidgets(
        'empty: an instruction, never "0 kcal eaten" pretending to be data; the full target is left',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(harness());
      await settle(tester);
      expect(textOf(tester, 'eat.date').data, 'Today');
      expect(textOf(tester, 'eat.hero.value').data, '2,400');
      expect(textOf(tester, 'eat.hero.caption').data, 'kcal left of 2,400');
      expect(find.text('Nothing logged today.'), findsOneWidget);
      expect(find.byKey(const ValueKey('eat.log')), findsOneWidget);
    });

    testWidgets('no targets yet: says so; what was eaten is still shown',
        (tester) async {
      tall(tester);
      api.targets = null;
      await seedServerLog(quick('11111111-1111-4111-8111-111111111111'));
      await tester.pumpWidget(harness());
      await settle(tester);
      expect(find.byKey(const ValueKey('eat.noTargets')), findsOneWidget);
      expect(textOf(tester, 'eat.eaten').data, 'Eaten 250 kcal');
    });

    testWidgets(
        'estimates make the hero and totals ranges; unknown fibre is counted, never 0',
        (tester) async {
      tall(tester);
      await seedServerLog(
        const CreateLogRequest.search(
          clientLogId: '22222222-2222-4222-8222-222222222222',
          loggedAt: '2026-09-24T07:30:00.000Z',
          mealSlot: MealSlot.lunch,
          items: [
            LogFoodItemRequest(
              foodId: '31111111-1111-4111-8111-111111111111',
              basis: NutritionBasis.perServing,
              servingLabel: '1 katori',
              servings: 1.5,
            ),
          ],
        ),
      );
      await seedServerLog(
        quick('33333333-3333-4333-8333-333333333333', fibre: 3),
      );
      await tester.pumpWidget(harness());
      await settle(tester);
      expect(textOf(tester, 'eat.hero.value').data, '1,872–1,970');
      expect(textOf(tester, 'eat.eaten').data, 'Eaten 430–528 kcal');
      expect(find.byKey(const ValueKey('eat.estimated')), findsOneWidget);
      expect(
        textOf(tester, 'eat.fibre').data,
        'Fibre 3 g + not known for 1 item / 30 g',
      );
      expect(find.text('Dal tadka · 1.5 × 1 katori (225 g)'), findsOneWidget);
      expect(find.text('180–278 kcal'), findsOneWidget);
    });

    testWidgets('over target: shown as over, never "0 left"', (tester) async {
      tall(tester);
      await seedServerLog(
        quick('44444444-4444-4444-8444-444444444444', kcal: 2520),
      );
      await tester.pumpWidget(harness());
      await settle(tester);
      expect(textOf(tester, 'eat.hero.value').data, '120');
      expect(textOf(tester, 'eat.hero.caption').data, 'kcal over 2,400');
    });

    testWidgets(
        'offline with a day loaded before: the day stays, marked as not current',
        (tester) async {
      tall(tester);
      await seedServerLog(quick('55555555-5555-4555-8555-555555555555'));
      await tester.pumpWidget(harness());
      await settle(tester);
      api.offline = true;
      container(tester).invalidate(nutritionDayRefreshProvider(today));
      await settle(tester);
      expect(find.byKey(const ValueKey('eat.stale')), findsOneWidget);
      expect(textOf(tester, 'eat.eaten').data, 'Eaten 250 kcal');
    });

    testWidgets(
        'day history: back to yesterday and past days; never into the future; 31 days back is read-only',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(harness());
      await settle(tester);
      final next = tester.widget<IconButton>(
        find.byKey(const ValueKey('eat.next')),
      );
      expect(next.onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('eat.prev')));
      await settle(tester);
      expect(textOf(tester, 'eat.date').data, 'Yesterday');
      expect(api.calls, contains('day 2026-09-23'));
      await tester.tap(find.byKey(const ValueKey('eat.prev')));
      await settle(tester);
      expect(textOf(tester, 'eat.date').data, 'Tue 22 Sep');
      expect(find.byKey(const ValueKey('eat.log')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('eat.next')));
      await settle(tester);
      expect(textOf(tester, 'eat.date').data, 'Yesterday');
      container(tester).read(eatDateProvider.notifier).set('2026-08-24');
      await settle(tester);
      expect(find.byKey(const ValueKey('eat.log')), findsNothing);
      expect(
        find.text('Food can be logged up to 30 days back.'),
        findsOneWidget,
      );
      container(tester).read(eatDateProvider.notifier).set('2026-08-25');
      await settle(tester);
      expect(find.byKey(const ValueKey('eat.log')), findsOneWidget);
      container(tester).read(eatDateProvider.notifier).set('2026-09-30');
      await settle(tester);
      expect(textOf(tester, 'eat.date').data, 'Today');
    });
  });

  group('logging', () {
    testWidgets(
        'quick add → the server total lands on EAT (log → total), the request carries J6 fields',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(harness());
      await settle(tester);
      await quickAdd(tester);
      expect(api.logs, hasLength(1));
      final log = api.logs.values.single;
      expect(log.entryMethod, EntryMethod.quickAdd);
      expect(log.mealSlot, MealSlot.lunch);
      expect(log.items.single.fibreLow, isNull);
      expect(textOf(tester, 'eat.eaten').data, 'Eaten 250 kcal');
      expect(textOf(tester, 'eat.hero.value').data, '2,150');
      expect(find.text('Quick add · Quick add'), findsOneWidget);
    });

    testWidgets('quick add refuses a missing macro — nothing is logged',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(harness());
      await settle(tester);
      await openLog(tester, 'Quick add');
      await tester.enterText(find.byKey(const ValueKey('quick.kcal')), '250');
      await tester.tap(find.byKey(const ValueKey('quick.log')));
      await settle(tester);
      expect(find.text('Required.'), findsNWidgets(3));
      expect(api.logs, isEmpty);
    });

    testWidgets(
        'search → portion step: rows, servings, a display-only preview, 0.01 steps enforced, logged',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(harness());
      await settle(tester);
      await openLog(tester, 'Search');
      await tester.enterText(find.byKey(const ValueKey('log.search')), 'dal');
      await tester.pump(const Duration(milliseconds: 300));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('food.dal-tadka')));
      await settle(tester);
      expect(find.byKey(const ValueKey('portion.sheet')), findsOneWidget);
      expect(
        textOf(tester, 'portion.preview').data,
        '≈ 120–185 kcal · 6–9 g protein · 150 g',
      );
      expect(find.textContaining('Preview only'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('portion.amount')),
        '1.005',
      );
      await tester.pump();
      expect(
        textOf(tester, 'portion.problem').data,
        'Use at most two decimals.',
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('portion.log')))
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const ValueKey('portion.amount')),
        '1.5',
      );
      await tester.pump();
      expect(
        textOf(tester, 'portion.preview').data,
        '≈ 180–278 kcal · 9–13.5 g protein · 225 g',
      );
      await tester.tap(find.byKey(const ValueKey('portion.slot.Dinner')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('portion.log')));
      await settle(tester);
      final log = api.logs.values.single;
      expect(log.mealSlot, MealSlot.dinner);
      expect(log.items.single.servings, 1.5);
      // The server's snapshot equals the preview the user saw.
      expect([log.items.single.kcalLow, log.items.single.kcalHigh], [180, 278]);
      expect(find.byKey(const ValueKey('eat.slot.dinner')), findsOneWidget);
    });

    testWidgets('a per-100 g row is entered in grams', (tester) async {
      tall(tester);
      await tester.pumpWidget(harness());
      await settle(tester);
      await openLog(tester, 'Search');
      await tester.enterText(find.byKey(const ValueKey('log.search')), 'honey');
      await tester.pump(const Duration(milliseconds: 300));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('food.honey')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('portion.row.Per 100 g')));
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('portion.amount')))
            .controller!
            .text,
        '100',
      );
      await tester.enterText(
        find.byKey(const ValueKey('portion.amount')),
        '21',
      );
      await tester.pump();
      expect(
        textOf(tester, 'portion.preview').data,
        '≈ 64 kcal · 0.1 g protein · 21 g',
      );
      await tester.tap(find.byKey(const ValueKey('portion.log')));
      await settle(tester);
      expect(api.logs.values.single.items.single.grams, 21);
    });

    testWidgets('recent foods open with the last portion', (tester) async {
      tall(tester);
      api.recent = [
        const RecentFood(
          food: honey,
          lastLoggedAt: '2026-09-23T12:00:00.000Z',
          lastBasis: NutritionBasis.perServing,
          lastServingLabel: '1 tbsp',
          lastServings: 2,
        ),
      ];
      await tester.pumpWidget(harness());
      await settle(tester);
      await openLog(tester, 'Recent');
      expect(find.text('Last: 2 × 1 tbsp'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('recent.honey')));
      await settle(tester);
      expect(
        textOf(tester, 'portion.preview').data,
        '≈ 128 kcal · 0.2 g protein · 42 g',
      );
      await tester.tap(find.byKey(const ValueKey('portion.log')));
      await settle(tester);
      expect(api.logs.values.single.items.single.kcalLow, 128);
    });

    testWidgets(
        'saved meal: a preview on the list, one tap logs it (server snapshots current values)',
        (tester) async {
      tall(tester);
      api.meals = [
        SavedMeal(
          id: 'meal-1',
          clientMealId: 'c1',
          name: 'Usual dinner',
          createdAt: '2026-09-20T12:00:00.000Z',
          items: [
            SavedFoodItem(
              foodId: dalTadka.id,
              foodName: 'Dal tadka',
              basis: NutritionBasis.perServing,
              servingLabel: '1 katori',
              servings: 1,
              grams: 150,
              row: dalTadka.nutrition.first,
            ),
            const SavedQuickAddItem(
              quickAddName: 'Curd',
              kcal: 60,
              proteinG: 3,
              carbG: 4,
              fatG: 3,
              fibreG: null,
            ),
          ],
        ),
      ];
      await tester.pumpWidget(harness());
      await settle(tester);
      await openLog(tester, 'Saved meals');
      expect(find.text('≈ 180–245 kcal · preview'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('saved.meal-1.log')));
      await settle(tester);
      final log = api.logs.values.single;
      expect(log.entryMethod, EntryMethod.savedMeal);
      expect(log.savedMealId, 'meal-1');
      expect(log.items.map((i) => i.foodName), ['Dal tadka', 'Curd']);
      expect(textOf(tester, 'eat.eaten').data, 'Eaten 180–245 kcal');
    });

    testWidgets('"Save as meal" saves the slot\'s logs by their client ids',
        (tester) async {
      tall(tester);
      await seedServerLog(quick('66666666-6666-4666-8666-666666666666'));
      await tester.pumpWidget(harness());
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('eat.save.lunch')));
      await settle(tester);
      await tester.enterText(
        find.byKey(const ValueKey('savedMeal.name')),
        'Canteen lunch',
      );
      await tester.tap(find.byKey(const ValueKey('savedMeal.save')));
      await settle(tester);
      expect(api.meals.single.name, 'Canteen lunch');
      expect(api.meals.single.items.single.name, 'Quick add');
    });
  });

  group('offline and sync', () {
    testWidgets(
        'offline: the log shows at once as "not synced", NOT in the totals; on reconnect the server total arrives',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(harness());
      await settle(tester);
      api.offline = true;
      await quickAdd(tester);
      final pending = find.textContaining('Not synced yet');
      expect(pending, findsOneWidget);
      expect(find.textContaining('≈ 250 kcal'), findsOneWidget);
      expect(
        textOf(tester, 'eat.hero.value').data,
        '2,400',
      ); // the preview is not a total
      expect(find.byKey(const ValueKey('eat.unsynced')), findsOneWidget);
      api.offline = false;
      container(tester).read(nutritionLogRepositoryProvider).sync();
      await settle(tester);
      expect(find.textContaining('Not synced yet'), findsNothing);
      expect(textOf(tester, 'eat.eaten').data, 'Eaten 250 kcal');
      expect(api.logs, hasLength(1));
    });

    testWidgets('a refused log is parked with the reason; Retry sends it again',
        (tester) async {
      tall(tester);
      api.failNextCreate
          .add(const Validation('A food in this meal is no longer available.'));
      await tester.pumpWidget(harness());
      await settle(tester);
      await quickAdd(tester);
      expect(find.byKey(const ValueKey('eat.parked')), findsOneWidget);
      expect(
        find.text('Not synced: A food in this meal is no longer available.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Retry'));
      await settle(tester);
      expect(find.byKey(const ValueKey('eat.parked')), findsNothing);
      expect(api.logs, hasLength(1));
    });

    testWidgets(
        'delete: confirmed, the whole entry goes and the server total drops by exactly it',
        (tester) async {
      tall(tester);
      await seedServerLog(
        quick('77777777-7777-4777-8777-777777777777', kcal: 300),
      );
      await seedServerLog(
        quick(
          '88888888-8888-4888-8888-888888888888',
          kcal: 200,
          slot: MealSlot.dinner,
        ),
      );
      await tester.pumpWidget(harness());
      await settle(tester);
      expect(textOf(tester, 'eat.eaten').data, 'Eaten 500 kcal');
      await tester.tap(
        find.byKey(
          const ValueKey('log.77777777-7777-4777-8777-777777777777.delete'),
        ),
      );
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('delete.confirm')));
      await settle(tester);
      expect(api.deleted, {'77777777-7777-4777-8777-777777777777'});
      expect(textOf(tester, 'eat.eaten').data, 'Eaten 200 kcal');
      expect(
        find.byKey(
          const ValueKey('log.77777777-7777-4777-8777-777777777777'),
        ),
        findsNothing,
      );
    });

    testWidgets(
        'offline delete of a synced log: shown as deleting, still in the server totals until confirmed',
        (tester) async {
      tall(tester);
      await seedServerLog(quick('99999999-9999-4999-8999-999999999999'));
      await tester.pumpWidget(harness());
      await settle(tester);
      api.offline = true;
      await tester.tap(
        find.byKey(
          const ValueKey('log.99999999-9999-4999-8999-999999999999.delete'),
        ),
      );
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('delete.confirm')));
      await settle(tester);
      expect(
        find.byKey(
          const ValueKey(
            'log.99999999-9999-4999-8999-999999999999.deleting',
          ),
        ),
        findsOneWidget,
      );
      expect(textOf(tester, 'eat.eaten').data, 'Eaten 250 kcal');
      api.offline = false;
      container(tester).read(nutritionLogRepositoryProvider).sync();
      await settle(tester);
      expect(textOf(tester, 'eat.eaten').data, 'Eaten 0 kcal');
    });

    testWidgets('deleting a log that never synced removes it without a request',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(harness());
      await settle(tester);
      api.offline = true;
      await quickAdd(tester);
      final id = (await db.select(db.localFoodLogs).get()).single.clientLogId;
      await tester.tap(find.byKey(ValueKey('pending.$id.delete')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('delete.confirm')));
      await settle(tester);
      expect(find.textContaining('Not synced yet'), findsNothing);
      api.offline = false;
      api.calls.clear();
      container(tester).read(nutritionLogRepositoryProvider).sync();
      await settle(tester);
      expect(
        api.calls
            .where((c) => c.startsWith('create') || c.startsWith('delete')),
        isEmpty,
      );
    });
  });
}
