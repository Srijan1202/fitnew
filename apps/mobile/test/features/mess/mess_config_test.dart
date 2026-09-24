import 'dart:convert';

import 'package:fitos/core/db/app_database.dart';
import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/core/routing/router.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/mess/data/mess_repository.dart';
import 'package:fitos/features/mess/presentation/mess_providers.dart';
import 'package:fitos/features/onboarding/domain/entities/onboarding.dart';
import 'package:fitos/features/onboarding/presentation/screens/steps/vit_step.dart';
import 'package:fitos/features/profile/data/profile_repository.dart';
import 'package:fitos/features/profile/domain/entities/profile.dart';
import 'package:fitos/features/profile/presentation/screens/profile_screen.dart';
import 'package:fitos/features/workout/presentation/controllers/workout_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/fake_mess_api.dart';
import '../../support/fake_onboarding_repository.dart';
import '../../support/fake_profile_repository.dart';
import '../../support/fake_workout_api.dart';
import '../../support/workout_overrides.dart';

/// Phase 9: the mess setting (owner D13) and the offline copy (D18).
void main() {
  late AppDatabase db;
  late FakeMessApi mess;

  setUp(() {
    db = AppDatabase.inMemory();
    mess = FakeMessApi();
  });
  tearDown(() => db.close());

  group('MessRepository — the offline copy (owner D18)', () {
    test('a fetched menu is cached; offline, the cached copy is served, marked',
        () async {
      final repo = MessRepository(db, mess);
      final fresh = await repo.menu('2026-09-24');
      expect(fresh, isA<MenuLoaded>());
      expect((fresh as MenuLoaded).fromCache, isFalse);
      expect(await repo.myMessCode(), 'mens-veg');
      mess.offline = true;
      final cached = await repo.menu('2026-09-24');
      expect(cached, isA<MenuLoaded>());
      expect((cached as MenuLoaded).fromCache, isTrue);
      expect(cached.failure, isA<Offline>());
      expect(cached.storedAt, isNotNull);
      expect(cached.menu.mess.code, 'mens-veg');
      // A day never fetched: nothing to show.
      expect(await repo.menu('2026-09-27'), isA<MenuFailed>());
    });

    test('no mess configured: NotConfigured, and "my mess" is forgotten',
        () async {
      final repo = MessRepository(db, mess);
      await repo.menu('2026-09-24');
      mess.mine = null;
      expect(await repo.menu('2026-09-24'), isA<MenuNotConfigured>());
      expect(await repo.myMessCode(), isNull);
    });

    test('the list of messes is cached for the picker', () async {
      final repo = MessRepository(db, mess);
      final online = await repo.messes();
      expect((online as Ok).value, hasLength(6));
      mess.offline = true;
      final offline = await repo.messes();
      expect((offline as Ok).value, hasLength(6));
    });

    test("today's own menu fetches tomorrow's ahead (owner D18)", () async {
      final container = ProviderContainer(
        overrides: [
          sessionUserIdProvider.overrideWithValue('user-1'),
          ...workoutOverrides(db, FakeWorkoutApi(), mess: mess),
        ],
      );
      addTearDown(container.dispose);
      final today = container.read(messDateProvider);
      final sub = container.listen(
        messMenuProvider((date: today, code: null)),
        (_, __) {},
      );
      addTearDown(sub.close);
      await container.read(messMenuProvider((date: today, code: null)).future);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(mess.calls, contains(startsWith('menu mine $today')));
      final tomorrow = DateTime.parse(today).add(const Duration(days: 1));
      final t =
          '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';
      expect(mess.calls, contains('menu mine $t'));
    });
  });

  group('Profile — the mess by name, changeable (owner D13)', () {
    late FakeProfileRepository profile;

    setUp(() {
      profile = FakeProfileRepository();
      final p = (profile.nextProfile as Ok<UserProfileDetail>).value;
      profile.nextProfile = Ok(
        p.copyWith(
          isVitStudent: true,
          mess: const MessRef(
            providerId: 'vit-vellore',
            hostelId: 'mens',
            messId: 'veg',
          ),
        ),
      );
    });

    Widget app() {
      final router = GoRouter(
        initialLocation: Routes.profile,
        routes: [
          GoRoute(
            path: Routes.profile,
            builder: (_, __) => const ProfileScreen(),
          ),
        ],
      );
      return ProviderScope(
        overrides: [
          sessionUserIdProvider.overrideWithValue('user-1'),
          profileRepositoryProvider.overrideWithValue(profile),
          ...workoutOverrides(db, FakeWorkoutApi(), mess: mess),
        ],
        child:
            MaterialApp.router(theme: FitTheme.build(), routerConfig: router),
      );
    }

    void tall(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('shows the mess by its name, not raw ids', (tester) async {
      tall(tester);
      await tester.pumpWidget(app());
      await settle(tester);
      final row = find.byKey(const ValueKey('profile.mess'));
      await tester.ensureVisible(row);
      expect(tester.widget<Text>(row).data, "Men's Hostel · Vegetarian");
    });

    testWidgets('Change → pick another mess → one PATCH with the server ids',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(app());
      await settle(tester);
      final change = find.byKey(const ValueKey('profile.mess.change'));
      await tester.ensureVisible(change);
      await tester.tap(change);
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('mess.pick.womens-nonveg')));
      await settle(tester);
      expect(profile.messChanges, [
        const MessRef(
          providerId: 'vit-vellore',
          hostelId: 'womens',
          messId: 'nonveg',
        ),
      ]);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('profile.mess'))).data,
        "Women's Hostel · Non-Vegetarian",
      );
    });

    testWidgets('"I do not eat at a VIT mess" clears it', (tester) async {
      tall(tester);
      await tester.pumpWidget(app());
      await settle(tester);
      final change = find.byKey(const ValueKey('profile.mess.change'));
      await tester.ensureVisible(change);
      await tester.tap(change);
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('mess.pick.none')));
      await settle(tester);
      expect(profile.messChanges, [null]);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('profile.mess'))).data,
        'Not set',
      );
    });

    testWidgets('a refused change says why', (tester) async {
      tall(tester);
      profile.failMess = const Validation('That mess is not one FITOS knows.');
      await tester.pumpWidget(app());
      await settle(tester);
      final change = find.byKey(const ValueKey('profile.mess.change'));
      await tester.ensureVisible(change);
      await tester.tap(change);
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('mess.pick.womens-nonveg')));
      await settle(tester);
      expect(find.text('That mess is not one FITOS knows.'), findsOneWidget);
    });
  });

  group('onboarding screen 6 reads the server list (owner D13)', () {
    testWidgets('Yes → hostels and messes from the server → the answer',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final answers = <OnboardingAnswer>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            messApiProvider.overrideWithValue(mess),
            sessionUserIdProvider.overrideWithValue('user-1'),
          ],
          child: MaterialApp(
            theme: FitTheme.build(),
            home: Scaffold(
              body: VitStep(
                state: midwayState,
                submit: (a) async {
                  answers.add(a);
                  return null;
                },
                onBack: null,
                onNext: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(mess.calls, isEmpty); // not asked until the user says yes
      await tester.tap(find.text('Yes, I live in a VIT Vellore hostel'));
      await tester.pumpAndSettle();
      expect(mess.calls, ['messes']);
      await tester.tap(find.text("Women's Hostel"));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Special'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();
      expect(jsonDecode(jsonEncode(answers.single.toJson())), {
        'step': 'vit',
        'isVitStudent': true,
        'mess': {
          'providerId': 'vit-vellore',
          'hostelId': 'womens',
          'messId': 'special',
        },
      });
    });

    testWidgets('offline: says the list needs a connection', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      mess.offline = true;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            messApiProvider.overrideWithValue(mess),
            sessionUserIdProvider.overrideWithValue('user-1'),
          ],
          child: MaterialApp(
            theme: FitTheme.build(),
            home: Scaffold(
              body: VitStep(
                state: midwayState,
                submit: (_) async => null,
                onBack: null,
                onNext: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yes, I live in a VIT Vellore hostel'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('vit.messesError')), findsOneWidget);
    });
  });
}
