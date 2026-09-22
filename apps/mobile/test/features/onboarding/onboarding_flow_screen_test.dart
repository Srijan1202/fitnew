import 'package:fitos/core/errors/result.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:fitos/core/theme/tokens.dart';
import 'package:fitos/features/auth/domain/entities/auth_state.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_providers.dart';
import 'package:fitos/features/onboarding/domain/entities/onboarding.dart';
import 'package:fitos/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:fitos/features/onboarding/presentation/screens/onboarding_flow_screen.dart';
import 'package:fitos/features/profile/domain/entities/vocabulary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_onboarding_repository.dart';

/// The flow screen with a scripted server. What is asserted is the §32
/// behaviour, not pixels: the client decides nothing, a rejection stays on
/// the screen with the form intact, and a resume opens where the server
/// says.
void main() {
  late FakeAuthRepository auth;
  late FakeOnboardingRepository repo;

  setUp(() {
    auth = FakeAuthRepository()
      ..restoreResult = AuthState.signedIn(newUserProfile);
    repo = FakeOnboardingRepository();
  });
  tearDown(() => auth.dispose());

  Widget harness() => ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          onboardingRepositoryProvider.overrideWithValue(repo),
          sessionUserIdProvider.overrideWithValue(newUserProfile.id),
        ],
        child: MaterialApp(
          theme: FitTheme.build(),
          home: const OnboardingFlowScreen(),
        ),
      );

  Finder continueButton() => find.widgetWithText(FilledButton, 'Continue');

  testWidgets('screen 1 needs a choice before Continue is enabled',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('STEP 1 OF 7'), findsOneWidget);
    expect(find.text('Back'), findsNothing);
    expect(
      tester.widget<FilledButton>(continueButton()).onPressed,
      isNull,
    );

    await tester.tap(find.text('Lose fat'));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(continueButton()).onPressed,
      isNotNull,
    );
  });

  testWidgets('an accepted answer sends the wire shape and advances',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lose fat'));
    await tester.pump();
    await tester.tap(continueButton());
    await tester.pumpAndSettle();

    expect(
      repo.answers.single,
      const OnboardingAnswer.goal(goalType: GoalType.fatLoss),
    );
    expect(find.text('STEP 2 OF 7'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
  });

  testWidgets('a server rejection stays on the screen with the form intact',
      (tester) async {
    // The 18+ rule is the server's (§23). The client shows the message in
    // oxide beside the form; it does not clear, advance or retry.
    // Fields pre-filled from the server's copy (a resume onto screen 2);
    // consent is the one thing that must be given afresh here.
    repo.nextState = Ok(
      freshState.copyWith(
        stage: OnboardingStage.about,
        answered: [OnboardingStage.goal],
        profile: midwayProfile.copyWith(onboardingStage: 'about'),
      ),
    );
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    expect(find.text('STEP 2 OF 7'), findsOneWidget);
    expect(find.text('2005-03-14'), findsOneWidget);

    // Phase 6.6: the name comes first and is required.
    expect(find.text('What should we call you?'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('about.displayName')),
        matching: find.byType(TextField),
      ),
      '  Srijan ',
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('about.consent')));
    await tester.tap(find.byKey(const ValueKey('about.consent')));
    await tester.pump();

    repo.nextAnswer = const Err(under18);
    await tester.tap(continueButton());
    await tester.pumpAndSettle();

    expect(find.text('STEP 2 OF 7'), findsOneWidget);
    expect(find.text(under18.message), findsOneWidget);
    final message = tester.widget<Text>(find.text(under18.message));
    expect(message.style?.color, FitColors.oxide);
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const ValueKey('about.heightCm')),
              matching: find.byType(TextField),
            ),
          )
          .controller
          ?.text,
      '160',
    );
    expect(repo.answers.single, isA<AboutAnswer>());
    final sent = repo.answers.single as AboutAnswer;
    expect(sent.displayName, 'Srijan');
    expect(sent.consent.policyVersion, freshState.policyVersion);
    expect(sent.consent.types, ConsentType.values);
  });

  testWidgets(
      'about: without a name Continue stays disabled; the identity provider\'s name pre-fills',
      (tester) async {
    auth.suggestedDisplayName = 'Srijan Srivastava';
    repo.nextState = Ok(
      midwayState.copyWith(
        stage: OnboardingStage.about,
        answered: const [OnboardingStage.goal],
        missing: OnboardingStage.steps.skip(1).toList(),
        profile: midwayProfile.copyWith(onboardingStage: 'about'),
      ),
    );
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    final field = find.descendant(
      of: find.byKey(const ValueKey('about.displayName')),
      matching: find.byType(TextField),
    );
    expect(
      tester.widget<TextField>(field).controller?.text,
      'Srijan Srivastava',
    );
    await tester.enterText(field, '');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('about.consent')));
    await tester.tap(find.byKey(const ValueKey('about.consent')));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(continueButton()).onPressed,
      isNull,
      reason: 'no name, no Continue',
    );
    expect(repo.answers, isEmpty);
  });

  testWidgets('resume opens on the server\'s next step, Back walks down',
      (tester) async {
    repo.nextState = const Ok(midwayState);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('STEP 4 OF 7'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('STEP 3 OF 7'), findsOneWidget);
    // Pre-filled from the server's copy of the earlier answer.
    expect(find.text('Beginner'), findsOneWidget);
    expect(repo.calls, ['getState'], reason: 'Back is local, no request');
  });

  testWidgets('a failed load offers retry rather than a blank screen',
      (tester) async {
    repo.nextState = const Err(under18);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    expect(find.text('Could not load your progress'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
