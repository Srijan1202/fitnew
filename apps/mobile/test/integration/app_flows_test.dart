import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fitos/app.dart';
import 'package:fitos/core/db/app_database.dart';
import 'package:fitos/features/auth/domain/entities/auth_state.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_providers.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/features/health/presentation/controllers/health_providers.dart';
import 'package:fitos/features/home/presentation/controllers/home_providers.dart';
import 'package:fitos/features/home/presentation/screens/home_screen.dart';
import 'package:fitos/features/mess/presentation/mess_screen.dart';
import 'package:fitos/features/nutrition/domain/entities/food.dart';
import 'package:fitos/features/nutrition/domain/entities/food_log.dart';
import 'package:fitos/features/nutrition/domain/portion_preview.dart';
import 'package:fitos/features/nutrition/presentation/controllers/food_log_providers.dart';
import 'package:fitos/features/nutrition/presentation/controllers/food_logger.dart';
import 'package:fitos/features/nutrition/presentation/controllers/food_providers.dart';
import 'package:fitos/features/onboarding/domain/entities/onboarding.dart';
import 'package:fitos/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:fitos/features/profile/data/profile_repository.dart';
import 'package:fitos/features/profile/domain/entities/vocabulary.dart';
import 'package:fitos/features/today/domain/today.dart';
import 'package:fitos/features/workout/domain/entities/workout.dart';
import 'package:fitos/features/workout/presentation/controllers/rest_timer.dart';
import 'package:fitos/features/workout/presentation/controllers/workout_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_auth_repository.dart';
import '../support/fake_food_log_api.dart';
import '../support/fake_food_repository.dart';
import '../support/fake_mess_api.dart';
import '../support/fake_onboarding_repository.dart';
import '../support/fake_profile_repository.dart';
import '../support/fake_today_api.dart';
import '../support/fake_workout_api.dart';
import '../support/workout_overrides.dart';

/// Phase 18 (§26.4): the three integration paths, each through the whole
/// app (FitOSApp: the router, the auth gate, the shell, the real screens and
/// controllers, the phone's database in memory) with every server scripted.
/// Nothing here reaches into a controller to do the user's part: each step
/// is a tap, a typed value or a connectivity event.
void main() {
  const today = '2026-09-24';
  final noonIst = DateTime.utc(2026, 9, 24, 7, 30);

  late FakeAuthRepository auth;
  late FakeOnboardingRepository onboarding;
  late AppDatabase db;
  late FakeWorkoutApi workoutApi;
  late FakeFoodLogApi foodLog;
  late FakeMessApi mess;
  late FakeTodayApi todayApi;
  late StreamController<List<ConnectivityResult>> connectivity;

  setUp(() {
    auth = FakeAuthRepository();
    onboarding = FakeOnboardingRepository();
    db = AppDatabase.inMemory();
    workoutApi = FakeWorkoutApi();
    foodLog = FakeFoodLogApi(todayDate: today);
    mess = FakeMessApi();
    todayApi = FakeTodayApi(date: today);
    connectivity = StreamController<List<ConnectivityResult>>.broadcast();
  });
  tearDown(() async {
    auth.dispose();
    await connectivity.close();
    await db.close();
  });

  Widget app() => ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          onboardingRepositoryProvider.overrideWithValue(onboarding),
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          foodRepositoryProvider.overrideWithValue(FakeFoodRepository()),
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
          ...workoutOverrides(
            db,
            workoutApi,
            foodLog: foodLog,
            mess: mess,
            today: todayApi,
            // The flows below go offline and come back.
            connectivity: connectivity.stream,
          ),
        ],
        child: const FitOSApp(),
      );

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 4200);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
  }

  /// The workout screen ticks a clock every second, so `pumpAndSettle`
  /// never settles there; a fixed run of short pumps covers route
  /// transitions and the database streams.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(ValueKey(key));
    await tester.ensureVisible(f);
    await settle(tester);
    await tester.tap(f);
    await settle(tester);
  }

  Future<void> next(WidgetTester tester) async {
    final f = find.widgetWithText(FilledButton, 'Continue');
    await tester.ensureVisible(f);
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String key, String value) async {
    await tester.enterText(
      find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(TextField),
      ),
      value,
    );
    await tester.pump();
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(FitOSApp)));

  testWidgets(
      'full onboarding: sign up, seven screens, the server\'s plan, Start → TODAY',
      (tester) async {
    tall(tester);
    auth.restoreResult = const AuthState.signedOut();
    auth.nextSignIn = Ok(AuthState.signedIn(newUserProfile, isNewUser: true));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    // 1. Goal.
    expect(find.text('STEP 1 OF 7'), findsOneWidget);
    await tester.tap(find.text('Lose fat'));
    await tester.pump();
    await next(tester);

    // 2. About you: name, sex, birth date (the picker's default), height,
    // weight, the required consents.
    expect(find.text('STEP 2 OF 7'), findsOneWidget);
    await enter(tester, 'about.displayName', 'Asha');
    await tester.tap(find.text('Female'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('about.birthDate')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await enter(tester, 'about.heightCm', '160');
    await enter(tester, 'about.weightKg', '58');
    await tester.ensureVisible(find.byKey(const ValueKey('about.consent')));
    await tester.tap(find.byKey(const ValueKey('about.consent')));
    await tester.pump();
    await next(tester);

    // 3. Experience (four days a week and light activity are the defaults).
    expect(find.text('STEP 3 OF 7'), findsOneWidget);
    await tester.tap(find.text('Beginner'));
    await tester.pump();
    await next(tester);

    // 4. Training.
    expect(find.text('STEP 4 OF 7'), findsOneWidget);
    await tester.tap(find.text('Campus gym'));
    await tester.pump();
    await tester.ensureVisible(find.text('Dumbbells'));
    await tester.tap(find.text('Dumbbells'));
    await tester.pump();
    await next(tester);

    // 5. Food.
    expect(find.text('STEP 5 OF 7'), findsOneWidget);
    await tester.tap(find.text('Vegetarian'));
    await tester.pump();
    await next(tester);

    // 6. VIT: a hostel and its mess, from the server's list.
    expect(find.text('STEP 6 OF 7'), findsOneWidget);
    await tester.tap(find.text('Yes, I live in a VIT Vellore hostel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Women's Hostel"));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Vegetarian'));
    await tester.tap(find.text('Vegetarian'));
    await tester.pump();
    await next(tester);

    // 7. The plan is what the server calculated, shown as it came.
    expect(find.text('STEP 7 OF 7'), findsOneWidget);
    expect(find.text('2276'), findsOneWidget);
    expect(find.text('Mifflin-St Jeor BMR 1348 kcal'), findsOneWidget);

    // Every screen's answer reached the server, in order, in its wire shape.
    expect(onboarding.answers, [
      isA<GoalAnswer>(),
      isA<AboutAnswer>(),
      isA<ExperienceAnswer>(),
      isA<TrainingAnswer>(),
      isA<FoodAnswer>(),
      isA<VitAnswer>(),
    ]);
    expect(
      onboarding.answers.first,
      const OnboardingAnswer.goal(goalType: GoalType.fatLoss),
    );
    final about = onboarding.answers[1] as AboutAnswer;
    expect(about.displayName, 'Asha');
    expect(about.sex, Sex.female);
    expect(about.consent.types, ConsentType.required);
    final training = onboarding.answers[3] as TrainingAnswer;
    expect(training.trainingLocation, TrainingLocation.campusGym);
    expect(training.equipment, contains(Equipment.dumbbell));
    final vit = onboarding.answers[5] as VitAnswer;
    expect(vit.isVitStudent, isTrue);
    expect(onboarding.calls, contains('complete'));

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets(
      'a workout logged offline: started from TODAY, every set kept on the phone, synced when the connection returns',
      (tester) async {
    tall(tester);
    auth.restoreResult = AuthState.signedIn(testProfile);
    todayApi.plan = TodayPlan(
      date: today,
      generatedAt: '${today}T06:30:00.000Z',
      engineVersion: 'today-1',
      actions: [
        FakeTodayApi.action(
          TodayKind.startWorkout,
          id: '00000000-0000-4000-8000-0000000000aa',
          headline: 'Legs is ready',
          detail: '2 movements · about 18 min.',
        ),
      ],
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    // The connection drops before the session starts.
    workoutApi.offline = true;
    connectivity.add(const [ConnectivityResult.none]);
    await tapKey(tester, 'home.suggestion.start-workout.action');

    final container = containerOf(tester);
    final session =
        (await container.read(workoutRepositoryProvider).activeSession())!;
    final squat = 'session.${session.exercises.first.clientExerciseId}';
    expect(find.text('Barbell Back Squat'), findsOneWidget);

    for (final i in [1, 2, 3]) {
      await tapKey(tester, '$squat.set.$i.done');
    }
    expect(
      tester.widget<Text>(find.byKey(ValueKey('$squat.count'))).data,
      '3 / 3',
    );
    expect(find.byKey(const ValueKey('sync.pending')), findsOneWidget);
    // The rest timer ticks every second; stop it so no timer outlives the test.
    container.read(restTimerProvider.notifier).skip();
    await tapKey(tester, 'session.finish');
    await settle(tester);

    // Finished on the phone; the server has not seen it.
    expect(find.byKey(const ValueKey('summary.title')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('summary.sets'))).data,
      '3',
    );
    expect(find.byKey(const ValueKey('summary.pending')), findsOneWidget);
    expect(
      workoutApi.sessions[session.clientSessionId]?.status,
      isNot(SessionStatus.completed),
    );

    // The connection returns: the app syncs by itself — no tap, no resume.
    workoutApi.offline = false;
    connectivity.add(const [ConnectivityResult.wifi]);
    await settle(tester);
    await settle(tester);

    final onServer = workoutApi.sessions[session.clientSessionId]!;
    expect(onServer.status, SessionStatus.completed);
    expect(onServer.exercises.first.sets, hasLength(3));
    expect(find.byKey(const ValueKey('summary.pending')), findsNothing);
    expect(find.textContaining('Heaviest'), findsOneWidget);
  });

  testWidgets(
      'a mess meal: Nutrition → today\'s mess → a dish, a portion → logged as a mess dish; the server\'s snapshot lands in the day',
      (tester) async {
    tall(tester);
    auth.restoreResult = AuthState.signedIn(testProfile);
    foodLog.messSnapshot['phulka'] = (req) {
      const row = FakeMessApi.phulka;
      final portion =
          PortionPreview.resolve(row, servings: req.servings, grams: req.grams);
      final p = PortionPreview.scale(row, portion.servings!);
      return FoodLogItem(
        id: 'i-phulka',
        position: 0,
        foodId: null,
        messDishSlug: 'phulka',
        foodName: 'Phulka',
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
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tapKey(tester, 'nav.Nutrition');
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('eat.mess.line'))).data,
      'Lunch · 6 dishes',
    );
    await tapKey(tester, 'eat.mess');
    expect(find.byType(MessScreen), findsOneWidget);

    await tapKey(tester, 'mess.dish.phulka');
    expect(find.byKey(const ValueKey('portion.sheet')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('portion.amount')), '3');
    await settle(tester);
    await tapKey(tester, 'portion.log');

    final sent = foodLog.logs.values.single;
    expect(sent.entryMethod, EntryMethod.mess);
    expect(sent.messCode, 'mens-veg');
    expect(sent.mealSlot, MealSlot.lunch);
    expect(sent.localDate, today);
    expect(sent.items.single.messDishSlug, 'phulka');
    expect(sent.items.single.servings, 3);
    expect((sent.items.single.kcalLow, sent.items.single.kcalHigh), (255, 360));
    expect(find.text('Logged Phulka.'), findsOneWidget);
    // Synced: nothing is left queued on the phone.
    expect(await db.select(db.localFoodLogs).get(), isEmpty);
  });
}
