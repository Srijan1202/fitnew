import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fitos/core/db/app_database.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/health/presentation/controllers/health_providers.dart';
import 'package:fitos/features/home/presentation/controllers/home_providers.dart';
import 'package:fitos/features/mess/domain/mess.dart';
import 'package:fitos/features/mess/presentation/mess_providers.dart';
import 'package:fitos/features/mess/presentation/mess_screen.dart';
import 'package:fitos/features/nutrition/presentation/controllers/food_log_providers.dart';
import 'package:fitos/features/nutrition/presentation/controllers/food_logger.dart';
import 'package:fitos/features/nutrition/presentation/controllers/food_providers.dart';
import 'package:fitos/features/nutrition/presentation/screens/eat_screen.dart';
import 'package:fitos/features/nutrition/presentation/screens/log_food_screen.dart';
import 'package:fitos/features/workout/presentation/controllers/workout_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_food_log_api.dart';
import '../../support/fake_food_repository.dart';
import '../../support/fake_mess_api.dart';

/// Phase 9: the MESS screen, the EAT strip, the log sheet's Mess pane, the
/// dish step and the report sheet lay out on the S24 and on a small phone,
/// at 100 % and 200 % text, keyboard closed and open — with ZERO overflow
/// (an overflow fails the test as an exception).
void main() {
  const today = '2026-09-24';
  const s24 = (w: 411.0, h: 891.0, dpr: 2.625);
  const small = (w: 360.0, h: 640.0, dpr: 2.0);
  const keyboard = 320.0;

  late AppDatabase db;
  late FakeMessApi mess;

  setUp(() {
    db = AppDatabase.inMemory();
    mess = FakeMessApi();
    // A long published line and an inferred, stale day: the worst case.
    final base = FakeMessApi.defaultMenu(
      'womens-special',
      today,
      resolution: const InferredMenu(
        today,
        sourceDate: '2026-09-10',
        cycleLengthDays: 14,
      ),
      freshness: const MessFreshness(
        lastSuccessAt: '2026-09-21T06:00:00.000Z',
        lastAttemptAt: '2026-09-24T06:00:00.000Z',
        lastError: MirrorError.unreachable,
        stale: true,
        latestPublishedDate: '2026-09-30',
      ),
    );
    mess.mine = 'womens-special';
    mess.menus['womens-special/$today'] = MessMenu(
      mess: base.mess,
      date: today,
      today: today,
      resolution: base.resolution,
      logged: base.logged,
      meals: [
        for (final m in base.meals)
          MessMeal(
            slot: m.slot,
            rawMenu:
                '${m.rawMenu}, Veg: Chettinad Veg Biriyani, Non Veg: Chicken Hyderabadi Dum Biriyani, Sweet: Kova Mysorepaku',
            dishes: [
              ...m.dishes,
              FakeMessApi.dish(
                'chicken-hyderabadi-dum-biriyani-with-raitha-and-salna',
                'Chicken Hyderabadi Dum Biriyani With Raitha And Salna',
                nutrition: FakeMessApi.dal,
                diet: DietClass.nonveg,
                pending: true,
              ),
            ],
          ),
      ],
    );
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

  Widget harness({double textScale = 1, String initial = '/nutrition/mess'}) {
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
          ],
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        foodLogApiProvider.overrideWithValue(FakeFoodLogApi(todayDate: today)),
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

  void expectClean(WidgetTester tester, String state) {
    final e = tester.takeException();
    expect(e, isNull, reason: '$state: $e');
  }

  for (final size in [s24, small]) {
    for (final scale in [1.0, 2.0]) {
      final label = '${size.w.toInt()}×${size.h.toInt()} @ ${scale}x text';

      testWidgets(
          '$label: MESS — banners, every meal, the published text, the dish step and the report sheet with the keyboard — no overflow',
          (tester) async {
        screen(tester, size);
        await tester.pumpWidget(harness(textScale: scale));
        await settle(tester);
        expectClean(tester, 'MESS top');
        expect(find.byKey(const ValueKey('mess.inferred')), findsOneWidget);
        for (final slot in ['breakfast', 'lunch', 'snacks', 'dinner']) {
          final raw = find.byKey(ValueKey('mess.raw.$slot'));
          await tester.scrollUntilVisible(
            raw,
            250,
            scrollable: find.byType(Scrollable).first,
          );
          await settle(tester);
          await tester.tap(raw);
          await settle(tester);
          expectClean(tester, 'MESS $slot, published text open');
        }
        final dish = find.byKey(const ValueKey('mess.dish.phulka'));
        await tester.scrollUntilVisible(
          dish,
          -250,
          scrollable: find.byType(Scrollable).first,
        );
        await settle(tester);
        await tester.tap(dish);
        await settle(tester);
        expect(find.byKey(const ValueKey('portion.sheet')), findsOneWidget);
        expectClean(tester, 'dish step');
        final report = find.byKey(const ValueKey('mess.report'));
        await tester.ensureVisible(report);
        await settle(tester);
        await tester.tap(report);
        await settle(tester);
        expect(find.byKey(const ValueKey('mess.correction')), findsOneWidget);
        expectClean(tester, 'report sheet');
        screen(tester, size, keyboardOpen: true);
        await tester.showKeyboard(find.byKey(const ValueKey('correction.low')));
        await settle(tester);
        expectClean(tester, 'report sheet, keyboard open');
        screen(tester, size);
        await settle(tester);
        expectClean(tester, 'keyboard dismissed');
      });

      testWidgets(
          '$label: EAT with the mess strip, and the log sheet on its Mess pane — no overflow',
          (tester) async {
        screen(tester, size);
        await tester
            .pumpWidget(harness(textScale: scale, initial: '/nutrition'));
        await settle(tester);
        final strip = find.byKey(const ValueKey('eat.mess'));
        await tester.scrollUntilVisible(
          strip,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await settle(tester);
        expectClean(tester, 'EAT with the mess strip');
        final log = find.byKey(const ValueKey('eat.log'));
        await tester.scrollUntilVisible(
          log,
          -200,
          scrollable: find.byType(Scrollable).first,
        );
        await settle(tester);
        await tester.tap(log);
        await settle(tester);
        expect(find.byKey(const ValueKey('log.source.Mess')), findsOneWidget);
        expectClean(tester, 'log sheet, Mess pane');
        await tester.drag(
          find.byKey(const ValueKey('log.scroll')),
          const Offset(0, -2000),
        );
        await settle(tester);
        expectClean(tester, 'log sheet, Mess pane scrolled');
      });
    }
  }
}
