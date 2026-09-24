import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fitos/core/db/app_database.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/health/presentation/controllers/health_providers.dart';
import 'package:fitos/features/home/presentation/controllers/home_providers.dart';
import 'package:fitos/features/mess/presentation/mess_providers.dart';
import 'package:fitos/features/nutrition/domain/entities/food.dart';
import 'package:fitos/features/nutrition/domain/entities/food_log.dart';
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
import '../../support/fake_mess_api.dart';
import '../../support/fake_food_repository.dart';
import 'eat_screen_test.dart' show serverSnapshot;

/// Phase 8 UI remediation: the EAT and Log Food screens lay out on the S24
/// and on a small phone, with the keyboard closed and open, at 100 % and
/// 200 % text — with ZERO overflow (a RenderFlex overflow fails the test as
/// an exception). With the keyboard open, the search field and the first
/// results stay above it and can be tapped.
void main() {
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

  /// Logical size and device pixel ratio.
  const s24 = (w: 411.0, h: 891.0, dpr: 2.625);
  const small = (w: 360.0, h: 640.0, dpr: 2.0);
  const keyboard = 320.0; // logical px, Samsung keyboard with its toolbar

  late AppDatabase db;
  late FakeFoodLogApi api;

  setUp(() {
    db = AppDatabase.inMemory();
    api = FakeFoodLogApi(todayDate: today, targets: targets);
    api.snapshot[dalTadka.id] = serverSnapshot(dalTadka);
    api.snapshot[honey.id] = serverSnapshot(honey);
    api.recent = [
      const RecentFood(
        food: honey,
        lastLoggedAt: '2026-09-23T12:00:00.000Z',
        lastBasis: NutritionBasis.perServing,
        lastServingLabel: '1 tbsp',
        lastServings: 2,
      ),
    ];
  });

  tearDown(() => db.close());

  void screen(
    WidgetTester tester,
    ({double w, double h, double dpr}) size, {
    bool keyboardOpen = false,
  }) {
    tester.view.physicalSize = Size(size.w * size.dpr, size.h * size.dpr);
    tester.view.devicePixelRatio = size.dpr;
    tester.view.viewInsets = keyboardOpen
        ? FakeViewPadding(bottom: keyboard * size.dpr)
        : FakeViewPadding.zero;
    addTearDown(tester.view.reset);
  }

  Widget harness({double textScale = 1, String initial = '/nutrition'}) {
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
        // Phase 9: no mess configured — the Phase 8 screens as they were.
        messApiProvider.overrideWithValue(FakeMessApi(mine: null)),
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
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> seedDay() async {
    await api.createLog(
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
  }

  Future<void> openLog(WidgetTester tester) async {
    final button = find.byKey(const ValueKey('eat.log'));
    await tester.scrollUntilVisible(
      button,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester);
    await tester.tap(button);
    await settle(tester);
  }

  /// Fails on any overflow or other framework exception during the pumps.
  void expectClean(WidgetTester tester, String state) {
    final e = tester.takeException();
    expect(e, isNull, reason: '$state: $e');
  }

  for (final size in [s24, small]) {
    for (final scale in [1.0, 2.0]) {
      final label = '${size.w.toInt()}×${size.h.toInt()} @ ${scale}x text';

      testWidgets('$label: EAT empty and with logged food — no overflow',
          (tester) async {
        screen(tester, size);
        await tester.pumpWidget(harness(textScale: scale));
        await settle(tester);
        expectClean(tester, 'EAT empty');
        // The list builds lazily: scroll the meals in, checking as we go.
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('eat.slot.breakfast')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await settle(tester);
        expectClean(tester, 'EAT scrolled to the meals');
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, 3000),
        );
        await settle(tester);
        await seedDay();
        ProviderScope.containerOf(tester.element(find.byType(EatScreen)))
            .invalidate(nutritionDayRefreshProvider(today));
        await settle(tester);
        expectClean(tester, 'EAT with food');
        expect(find.byKey(const ValueKey('eat.hero.value')), findsOneWidget);
        // The logging control is on the first screen, not below the fold.
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, 2000),
        );
        await settle(tester);
        if (scale == 1.0) {
          final log = tester.getRect(find.byKey(const ValueKey('eat.log')));
          expect(
            log.bottom,
            lessThanOrEqualTo(size.h),
            reason: 'Log food above the fold at normal text size',
          );
        }
        await tester.tap(find.byKey(const ValueKey('eat.prev')));
        await settle(tester);
        expectClean(tester, 'previous day');
      });

      testWidgets(
          '$label: Log Food — Recent, Saved, Quick add, keyboard closed and open — no overflow',
          (tester) async {
        screen(tester, size);
        await tester.pumpWidget(harness(textScale: scale));
        await settle(tester);
        await openLog(tester);
        expectClean(tester, 'Log Food, Recent');
        for (final source in ['Saved meals', 'Quick add', 'Recent']) {
          await tester.tap(find.byKey(ValueKey('log.source.$source')));
          await settle(tester);
          expectClean(tester, source);
        }
        await tester.tap(find.byKey(const ValueKey('log.source.Quick add')));
        await settle(tester);
        screen(tester, size, keyboardOpen: true);
        await tester.showKeyboard(find.byKey(const ValueKey('quick.kcal')));
        await settle(tester);
        expectClean(tester, 'Quick add, keyboard open');
        // The focused field is scrolled above the keyboard.
        final field = tester.getRect(find.byKey(const ValueKey('quick.kcal')));
        expect(field.bottom, lessThanOrEqualTo(size.h - keyboard));
      });

      testWidgets(
          '$label: Search with the keyboard open — field and results above it, tappable; portion step fits',
          (tester) async {
        screen(tester, size);
        await tester.pumpWidget(harness(textScale: scale));
        await settle(tester);
        await openLog(tester);
        await tester.tap(find.byKey(const ValueKey('log.source.Search')));
        await settle(tester);
        expectClean(tester, 'Search, keyboard closed');
        // The keyboard opens (the field autofocuses).
        screen(tester, size, keyboardOpen: true);
        await settle(tester);
        expectClean(tester, 'Search, keyboard open');
        await tester.enterText(find.byKey(const ValueKey('log.search')), 'dal');
        await tester.pump(const Duration(milliseconds: 300));
        await settle(tester);
        expectClean(tester, 'results, keyboard open');
        final visible = size.h - keyboard;
        final field = tester.getRect(find.byKey(const ValueKey('log.search')));
        expect(field.top, greaterThanOrEqualTo(0));
        expect(
          field.bottom,
          lessThanOrEqualTo(visible),
          reason: 'field above the keyboard',
        );
        // Scroll the results under the pinned field; the field stays.
        await tester.drag(
          find.byKey(const ValueKey('log.scroll')),
          const Offset(0, -300),
        );
        await settle(tester);
        final fieldAfter =
            tester.getRect(find.byKey(const ValueKey('log.search')));
        expect(fieldAfter.bottom, lessThanOrEqualTo(visible));
        expect(fieldAfter.top, greaterThanOrEqualTo(0));
        // A result is above the keyboard and can be tapped.
        final result = find.byKey(const ValueKey('food.dal-tadka'));
        await tester.ensureVisible(result);
        await settle(tester);
        expect(tester.getRect(result).top, lessThan(visible));
        await tester.tap(result.hitTestable());
        await settle(tester);
        expect(find.byKey(const ValueKey('portion.sheet')), findsOneWidget);
        expectClean(tester, 'portion step');
        // Keyboard dismissed: still no overflow.
        screen(tester, size);
        await settle(tester);
        expectClean(tester, 'after keyboard dismissal');
      });
    }
  }
}
