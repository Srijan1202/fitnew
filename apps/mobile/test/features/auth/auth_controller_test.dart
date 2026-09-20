import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/features/auth/domain/entities/auth_state.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitos/features/auth/presentation/controllers/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';

/// Spec §31 Phase 1: "Flutter auth controller unit tests" — against a mocked
/// repository, no Firebase, no network.
void main() {
  late FakeAuthRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakeAuthRepository();
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
  });

  tearDown(() {
    container.dispose();
    repo.dispose();
  });

  AuthController notifier() => container.read(authControllerProvider.notifier);
  Future<AsyncValue<AuthState>> settled() async {
    await container.read(authControllerProvider.future);
    return container.read(authControllerProvider);
  }

  group('restore on build', () {
    test('signed out when nothing is persisted', () async {
      repo.restoreResult = const AuthState.signedOut();
      final state = await settled();
      expect(state.value, isA<AuthSignedOut>());
      expect(repo.calls, ['restore']);
    });

    test('signed in from the persisted session — token survives restart',
        () async {
      repo.restoreResult = AuthState.signedIn(testProfile);
      final state = await settled();
      expect(state.value, isA<AuthSignedIn>());
      expect((state.value! as AuthSignedIn).profile.email, 'student@vit.ac.in');
    });
  });

  group('sign in', () {
    test('success moves to signedIn and carries isNewUser from the server',
        () async {
      await settled();
      repo.nextSignIn = Ok(AuthState.signedIn(testProfile, isNewUser: true));

      await notifier().signInWithEmail(email: 'a@b.c', password: 'password1');

      final state = container.read(authControllerProvider);
      expect(state.hasValue, isTrue);
      final signedIn = state.value! as AuthSignedIn;
      expect(signedIn.isNewUser, isTrue);
      expect(repo.calls, contains('signInWithEmail:a@b.c'));
    });

    test('failure surfaces the Failure, not an exception, and stays signed out',
        () async {
      await settled();
      repo.nextSignIn = const Err(wrongPassword);

      await notifier().signInWithEmail(email: 'a@b.c', password: 'wrong');

      final state = container.read(authControllerProvider);
      expect(state.hasError, isTrue);
      expect(state.error, isA<Credential>());
      expect(
        (state.error! as Failure).message,
        'Email or password is incorrect.',
      );
      expect(state.value, isNot(isA<AuthSignedIn>()));
    });

    test('is loading while the repository works', () async {
      await settled();
      final future = notifier().signInWithGoogle();
      expect(container.read(authControllerProvider).isLoading, isTrue);
      await future;
      expect(container.read(authControllerProvider).isLoading, isFalse);
    });

    test('sign up uses the sign-up path', () async {
      await settled();
      await notifier().signUpWithEmail(email: 'new@b.c', password: 'password1');
      expect(repo.calls, contains('signUpWithEmail:new@b.c'));
    });
  });

  group('sign out', () {
    test('clears to signedOut and calls the repository', () async {
      repo.restoreResult = AuthState.signedIn(testProfile);
      await settled();

      await notifier().signOut();

      expect(
        container.read(authControllerProvider).value,
        isA<AuthSignedOut>(),
      );
      expect(repo.calls, contains('signOut'));
    });

    test('a session ended elsewhere downgrades the state automatically',
        () async {
      repo.restoreResult = AuthState.signedIn(testProfile);
      await settled();
      expect(container.read(authControllerProvider).value, isA<AuthSignedIn>());

      repo.emitExternal(const AuthState.signedOut());
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(authControllerProvider).value,
        isA<AuthSignedOut>(),
      );
    });

    test('an external signedIn event does NOT upgrade state — only actions do',
        () async {
      repo.restoreResult = const AuthState.signedOut();
      await settled();

      repo.emitExternal(AuthState.signedIn(testProfile));
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(authControllerProvider).value,
        isA<AuthSignedOut>(),
      );
    });
  });

  group('password reset', () {
    test('returns null on success without touching auth state', () async {
      await settled();
      final before = container.read(authControllerProvider);
      final failure = await notifier().sendPasswordReset(email: 'a@b.c');
      expect(failure, isNull);
      expect(container.read(authControllerProvider), same(before));
    });

    test('returns the failure inline', () async {
      await settled();
      repo.nextReset = const Err(Offline());
      final failure = await notifier().sendPasswordReset(email: 'a@b.c');
      expect(failure, isA<Offline>());
    });
  });

  test('acknowledgeNewUser clears the flag once, and is a no-op otherwise',
      () async {
    await settled();
    repo.nextSignIn = Ok(AuthState.signedIn(testProfile, isNewUser: true));
    await notifier().signInWithEmail(email: 'a@b.c', password: 'password1');

    notifier().acknowledgeNewUser();
    final after = container.read(authControllerProvider).value! as AuthSignedIn;
    expect(after.isNewUser, isFalse);
    expect(after.profile, testProfile);

    notifier().acknowledgeNewUser(); // idempotent
    expect(
      (container.read(authControllerProvider).value! as AuthSignedIn).isNewUser,
      isFalse,
    );
  });
}
