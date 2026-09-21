import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/features/auth/domain/entities/auth_state.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_providers.dart';
import 'package:fitos/features/profile/data/profile_repository.dart';
import 'package:fitos/features/training/presentation/controllers/program_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_profile_repository.dart';
import '../../support/fake_training_repository.dart';

/// The initialization sequence the owner asked to be verified:
///
///   auth restored → session established → profile request → profile
///
/// and what happens to session-scoped state across sign-out / sign-in.
/// Before `sessionUserIdProvider`, the profile and programme providers
/// lived for the app's lifetime: an error caught in one session was the
/// state the next session's Profile screen opened on ("intermittent error
/// on first load"), and user B could have been shown user A's plan.
void main() {
  late FakeAuthRepository auth;
  late FakeProfileRepository profile;
  late FakeTrainingRepository training;
  late ProviderContainer container;

  setUp(() {
    auth = FakeAuthRepository();
    profile = FakeProfileRepository();
    training = FakeTrainingRepository();
  });
  tearDown(() {
    container.dispose();
    auth.dispose();
  });

  void start() {
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(profile),
        trainingRepositoryProvider.overrideWithValue(training),
      ],
    );
    container.listen(authControllerProvider, (_, __) {});
    container.listen(profileControllerProvider, (_, __) {});
    container.listen(programControllerProvider, (_, __) {});
  }

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test(
      'nothing is requested before the session exists; loading, then the profile',
      () async {
    auth.restoreResult = AuthState.signedIn(testProfile);
    start();
    // While auth restores, the profile provider is loading — not an error —
    // and has asked nothing of the server.
    expect(container.read(profileControllerProvider).isLoading, isTrue);
    expect(profile.calls, isEmpty);

    await container.read(authControllerProvider.future);
    await settle();
    final view = await container.read(profileControllerProvider.future);
    expect(view.goal.goal.goalType, isNotNull);
    expect(profile.calls.first, 'getProfile');
    expect(profile.calls, contains('getGoal'));
  });

  test(
      'signed out: the profile provider never calls the server and holds nothing stale',
      () async {
    auth.restoreResult = const AuthState.signedOut();
    start();
    await container.read(authControllerProvider.future);
    await settle();
    final state = container.read(profileControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.error, isA<Unauthenticated>());
    expect(profile.calls, isEmpty);
  });

  test(
      'a failure in session A is gone when session B opens Profile: it reloads',
      () async {
    auth.restoreResult = AuthState.signedIn(testProfile);
    profile.nextProfile = const Err(Offline());
    start();
    await container.read(authControllerProvider.future);
    await settle();
    expect(container.read(profileControllerProvider).hasError, isTrue);
    final failedLoads = profile.calls.length;

    await container.read(authControllerProvider.notifier).signOut();
    await settle();
    profile.nextProfile = FakeProfileRepository().nextProfile;
    auth.nextSignIn = Ok(signedInAsB);
    await container
        .read(authControllerProvider.notifier)
        .signInWithEmail(email: 'b', password: 'b');
    await settle();
    final view = await container.read(profileControllerProvider.future);
    expect(view.profile, isNotNull);
    expect(container.read(profileControllerProvider).hasError, isFalse);
    expect(profile.calls.length, greaterThan(failedLoads));
  });

  test(
      'signing in as someone else rebuilds the programme: user B never sees A\'s plan',
      () async {
    auth.restoreResult = AuthState.signedIn(testProfile);
    training.stored = generatedProgram;
    start();
    await container.read(authControllerProvider.future);
    await settle();
    expect(await container.read(programControllerProvider.future), isNotNull);
    final loadsForA = training.calls.where((c) => c == 'getProgram').length;

    await container.read(authControllerProvider.notifier).signOut();
    await settle();
    training.stored = null;
    auth.nextSignIn = Ok(signedInAsB);
    await container
        .read(authControllerProvider.notifier)
        .signInWithEmail(email: 'b', password: 'b');
    await settle();
    expect(await container.read(programControllerProvider.future), isNull);
    expect(
      training.calls.where((c) => c == 'getProgram').length,
      loadsForA + 1,
    );
  });
}

/// A second account.
final AuthState signedInAsB = AuthState.signedIn(
  testProfile.copyWith(id: '9b9b9b9b-9b9b-4b9b-8b9b-9b9b9b9b9b9b'),
);
