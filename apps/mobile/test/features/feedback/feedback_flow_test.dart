import 'package:fitos/app.dart';
import 'package:fitos/core/db/app_database.dart';
import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/features/auth/domain/entities/auth_state.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_providers.dart';
import 'package:fitos/features/feedback/data/feedback_api.dart';
import 'package:fitos/features/home/presentation/screens/home_screen.dart';
import 'package:fitos/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:fitos/features/profile/data/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_feedback_api.dart';
import '../../support/fake_onboarding_repository.dart';
import '../../support/fake_profile_repository.dart';
import '../../support/fake_workout_api.dart';
import '../../support/workout_overrides.dart';

/// Phase 19 (§31 "feedback channel", ADR-026): Profile → Send feedback, and
/// the update gate (E1) — both through the whole app.
void main() {
  late FakeAuthRepository auth;
  late AppDatabase db;
  late FakeFeedbackApi feedback;
  late FakeMetaApi meta;

  setUp(() {
    auth = FakeAuthRepository()
      ..restoreResult = AuthState.signedIn(testProfile);
    db = AppDatabase.inMemory();
    feedback = FakeFeedbackApi();
    meta = FakeMetaApi();
  });
  tearDown(() async {
    auth.dispose();
    await db.close();
  });

  Widget app({int build = 4}) => ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          onboardingRepositoryProvider
              .overrideWithValue(FakeOnboardingRepository()),
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          ...workoutOverrides(
            db,
            FakeWorkoutApi(),
            feedback: feedback,
            meta: meta,
            appBuild: build,
          ),
        ],
        child: const FitOSApp(),
      );

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 4200);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
  }

  Future<void> openFeedback(WidgetTester tester) async {
    tall(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home.profile')));
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('profile.feedback'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  FilledButton send(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byKey(const ValueKey('feedback.send')));

  testWidgets(
      'Send is off until a category and a message are given; sent with the app version, then cleared',
      (tester) async {
    await openFeedback(tester);
    expect(send(tester).onPressed, isNull);
    await tester.enterText(
      find.byKey(const ValueKey('feedback.message')),
      '  The rest timer froze after set three.  ',
    );
    await tester.pump();
    expect(send(tester).onPressed, isNull, reason: 'no category yet');
    await tester.tap(find.byKey(const ValueKey('feedback.category.bug')));
    await tester.pump();
    expect(send(tester).onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('feedback.send')));
    await tester.pumpAndSettle();

    expect(feedback.sent.single.category, FeedbackCategory.bug);
    expect(
      feedback.sent.single.message,
      'The rest timer froze after set three.',
    );
    expect(feedback.sent.single.appVersion, '1.0.0-alpha.1+4');
    expect(find.textContaining('Sent. Thank you'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('feedback.message')))
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets('a failure keeps what was typed and says why', (tester) async {
    await openFeedback(tester);
    feedback.nextFailure = const Offline();
    await tester.enterText(
      find.byKey(const ValueKey('feedback.message')),
      'Paneer tikka is missing from the mess',
    );
    await tester.tap(find.byKey(const ValueKey('feedback.category.food')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('feedback.send')));
    await tester.pumpAndSettle();
    expect(feedback.sent, isEmpty);
    expect(find.textContaining('needs a connection'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('feedback.message')))
          .controller!
          .text,
      'Paneer tikka is missing from the mess',
    );
    // A second try goes through.
    await tester.tap(find.byKey(const ValueKey('feedback.send')));
    await tester.pumpAndSettle();
    expect(feedback.sent.single.category, FeedbackCategory.food);
  });

  group('E1: the update gate', () {
    testWidgets('a build below the server minimum shows only "Update FITOS"',
        (tester) async {
      meta.minimumBuild = 9;
      await tester.pumpWidget(app(build: 4));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('update.required')), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('at or above the minimum, or with no minimum, the app runs',
        (tester) async {
      meta.minimumBuild = 4;
      await tester.pumpWidget(app(build: 4));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('update.required')), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('an unreachable server never blocks the app', (tester) async {
      meta
        ..minimumBuild = 99
        ..offline = true;
      await tester.pumpWidget(app(build: 4));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('update.required')), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });
}
