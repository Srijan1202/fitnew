import 'dart:convert';

import 'package:fitos/core/errors/result.dart';
import 'package:fitos/features/auth/domain/entities/auth_state.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_providers.dart';
import 'package:fitos/features/onboarding/domain/entities/onboarding.dart';
import 'package:fitos/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:fitos/features/profile/domain/entities/vocabulary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_onboarding_repository.dart';

/// The controller is a thin pipe: the server's state in, the server's state
/// out. These tests pin that it never invents a stage of its own.
void main() {
  late FakeAuthRepository auth;
  late FakeOnboardingRepository repo;
  late ProviderContainer container;

  // The listener starts the build, so a test that scripts the load result
  // configures the repo before calling this.
  void start() {
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        onboardingRepositoryProvider.overrideWithValue(repo),
        sessionUserIdProvider.overrideWithValue(newUserProfile.id),
      ],
    );
    // Riverpod 3 auto-disposes an unlistened provider mid-build; the app has
    // the router listening, so mirror that here.
    container.listen(onboardingControllerProvider, (_, __) {});
    container.listen(authControllerProvider, (_, __) {});
  }

  setUp(() {
    auth = FakeAuthRepository()
      ..restoreResult = AuthState.signedIn(newUserProfile);
    repo = FakeOnboardingRepository();
  });

  tearDown(() {
    container.dispose();
    auth.dispose();
  });

  OnboardingController notifier() =>
      container.read(onboardingControllerProvider.notifier);
  Future<OnboardingState> settled() =>
      container.read(onboardingControllerProvider.future);

  test('build loads the server state, nothing else', () async {
    start();
    final state = await settled();
    expect(state, freshState);
    expect(repo.calls, ['getState']);
  });

  test('build surfaces a load failure as an error state', () async {
    repo.nextState = const Err(under18);
    start();
    await expectLater(settled(), throwsA(under18));
    final state = container.read(onboardingControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.isLoading, isFalse, reason: 'no silent retry (§6.6)');
    expect(state.error, under18);
  });

  test('an accepted answer replaces state with the server response', () async {
    start();
    await settled();
    final failure = await notifier().answer(
      const OnboardingAnswer.goal(goalType: GoalType.fatLoss),
    );
    expect(failure, isNull);
    final state = container.read(onboardingControllerProvider).requireValue;
    expect(state.stage, OnboardingStage.about);
    expect(state.answered, [OnboardingStage.goal]);
    expect(repo.answers.single, isA<GoalAnswer>());
  });

  test('a rejected answer returns the failure and leaves state alone',
      () async {
    start();
    await settled();
    repo.nextAnswer = const Err(under18);
    final failure = await notifier().answer(
      const OnboardingAnswer.about(
        displayName: 'Persona',
        sex: Sex.male,
        birthDate: '2015-01-01',
        heightCm: 170,
        weightKg: 60,
        consent: ConsentGrant(
          policyVersion: '2026-09-21',
          types: ConsentType.values,
        ),
      ),
    );
    expect(failure, under18);
    final state = container.read(onboardingControllerProvider).requireValue;
    expect(state, freshState, reason: 'the form must stay where it was');
  });

  test('complete marks the session complete and keeps the returned profile',
      () async {
    start();
    await settled();
    await container.read(authControllerProvider.future);

    final result = await notifier().complete();
    expect(result, isA<Ok<OnboardingCompleteResponse>>());
    expect(repo.calls, contains('complete'));
    expect(auth.calls, contains('cacheOnboardingStage:complete'));

    final authState = container.read(authControllerProvider).requireValue;
    expect(authState, isA<AuthSignedIn>());
    expect((authState as AuthSignedIn).profile.onboardingStage, 'complete');

    final state = container.read(onboardingControllerProvider).requireValue;
    expect(state.profile.onboardingStage, 'complete');
  });

  test('a failed complete does not touch the session', () async {
    start();
    await settled();
    await container.read(authControllerProvider.future);
    repo.nextComplete = const Err(under18);

    final result = await notifier().complete();
    expect(result, isA<Err<OnboardingCompleteResponse>>());
    expect(auth.calls, isNot(contains('cacheOnboardingStage:complete')));
    final authState = container.read(authControllerProvider).requireValue;
    expect((authState as AuthSignedIn).profile.onboardingStage, 'goal');
  });

  test('wire shape of every answer matches the contract discriminator', () {
    start();
    // `step` is the discriminator (contracts/onboarding.ts); each variant
    // serialises to the kebab-case name the server switches on. Encoded the
    // way dio does it, so nested objects are exercised too.
    Object? wire(OnboardingAnswer a) => jsonDecode(jsonEncode(a.toJson()));
    expect(
      wire(const OnboardingAnswer.goal(goalType: GoalType.muscleGain)),
      {'step': 'goal', 'goalType': 'muscle-gain'},
    );
    expect(
      wire(const OnboardingAnswer.vit(isVitStudent: false, mess: null)),
      {'step': 'vit', 'isVitStudent': false, 'mess': null},
    );
    final about = wire(
      const OnboardingAnswer.about(
        displayName: 'Persona',
        sex: Sex.female,
        birthDate: '2005-03-14',
        heightCm: 160,
        weightKg: 58,
        consent: ConsentGrant(
          policyVersion: '2026-09-21',
          types: ConsentType.values,
        ),
      ),
    ) as Map<String, Object?>;
    expect(about['step'], 'about');
    expect(about['consent'], {
      'policyVersion': '2026-09-21',
      'types': ['privacy-policy', 'health-data-processing'],
    });
  });
}
