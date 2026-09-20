import 'package:fitos/app.dart';
import 'package:fitos/core/theme/tokens.dart';
import 'package:fitos/features/auth/domain/entities/auth_state.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_providers.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:fitos/features/profile/domain/entities/vocabulary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth_repository.dart';
import 'support/fake_onboarding_repository.dart';

/// The whole app through the router and the auth gate, with the repository
/// faked. These are the spec's acceptance paths in miniature: a signed-out
/// launch lands on sign-in, a restored session lands on TODAY, sign-out
/// returns to sign-in.
void main() {
  late FakeAuthRepository repo;
  late FakeOnboardingRepository onboarding;

  setUp(() {
    repo = FakeAuthRepository();
    onboarding = FakeOnboardingRepository();
  });
  tearDown(() => repo.dispose());

  Widget app() => ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          onboardingRepositoryProvider.overrideWithValue(onboarding),
        ],
        child: const FitOSApp(),
      );

  testWidgets('cold start, signed out → sign-in screen on paper',
      (tester) async {
    repo.restoreResult = const AuthState.signedOut();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Phase 3'), findsNothing);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    final theme = Theme.of(tester.element(find.byType(Scaffold).first));
    expect(
      scaffold.backgroundColor ?? theme.scaffoldBackgroundColor,
      FitColors.paper,
    );
  });

  testWidgets('cold start, session persisted → straight to TODAY, no sign-in',
      (tester) async {
    repo.restoreResult = AuthState.signedIn(testProfile);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Phase 3'), findsOneWidget);
    expect(find.text('student@vit.ac.in'), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
  });

  testWidgets('sign out from TODAY returns to sign-in', (tester) async {
    repo.restoreResult = AuthState.signedIn(testProfile);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Sign out'));
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('signOut'));
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Phase 3'), findsNothing);
  });

  testWidgets('uses ink, not colour, for the primary type', (tester) async {
    repo.restoreResult = AuthState.signedIn(testProfile);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final heading = tester.widget<Text>(find.text('Phase 3'));
    final context = tester.element(find.text('Phase 3'));
    final style = heading.style ?? Theme.of(context).textTheme.displayMedium!;
    expect(style.color, FitColors.ink);
  });

  testWidgets('a restored session with onboarding unfinished resumes it',
      (tester) async {
    // §32: "resumes after interruption". The server says training is next;
    // the app opens on screen 4, not screen 1 and not TODAY.
    repo.restoreResult = AuthState.signedIn(midOnboardingProfile);
    onboarding.nextState = const Ok(midwayState);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('STEP 4 OF 7'), findsOneWidget);
    expect(find.text('Phase 3'), findsNothing);
    expect(onboarding.calls, contains('getState'));
  });

  testWidgets('a new sign-up lands on screen 1', (tester) async {
    repo.restoreResult = const AuthState.signedOut();
    repo.nextSignIn = Ok(AuthState.signedIn(newUserProfile, isNewUser: true));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(find.text('STEP 1 OF 7'), findsOneWidget);
  });

  testWidgets('screen 7 shows the engine targets and Start opens TODAY',
      (tester) async {
    // Everything answered; the flow opens straight on the plan, which calls
    // /complete and renders exactly what the server returned.
    repo.restoreResult = AuthState.signedIn(midOnboardingProfile);
    onboarding.nextState = Ok(
      midwayState.copyWith(
        stage: OnboardingStage.complete,
        answered: OnboardingStage.steps,
        missing: const [],
      ),
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(onboarding.calls, contains('complete'));
    expect(repo.calls, contains('cacheOnboardingStage:complete'));
    expect(find.text('STEP 7 OF 7'), findsOneWidget);
    expect(find.text('2276'), findsOneWidget);
    expect(find.text('106'), findsOneWidget);
    expect(find.text('Mifflin-St Jeor BMR 1348 kcal'), findsOneWidget);
    // Still on the plan — the guard did not yank the screen away.
    expect(find.text('Phase 3'), findsNothing);

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(find.text('Phase 3'), findsOneWidget);
  });
}
