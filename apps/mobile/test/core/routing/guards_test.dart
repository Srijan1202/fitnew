import 'package:fitos/core/routing/guards.dart';
import 'package:fitos/core/routing/router.dart';
import 'package:fitos/features/auth/domain/entities/auth_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';

/// The guard is a pure function, so every (state × location) cell is a
/// one-line assertion. Any regression in routing shows up here first.
void main() {
  const loading = AsyncLoading<AuthState>();
  const signedOut = AsyncData<AuthState>(AuthState.signedOut());
  final signedIn = AsyncData<AuthState>(AuthState.signedIn(testProfile));
  final unfinished =
      AsyncData<AuthState>(AuthState.signedIn(midOnboardingProfile));

  group('while restoring', () {
    test('holds on the splash, never flashes sign-in', () {
      expect(authRedirect(loading, Routes.splash), isNull);
      expect(authRedirect(loading, Routes.today), Routes.splash);
      expect(authRedirect(loading, Routes.signIn), Routes.splash);
    });
  });

  group('signed out', () {
    test('may see every auth screen', () {
      for (final r in Routes.authRoutes) {
        expect(authRedirect(signedOut, r), isNull, reason: r);
      }
    });

    test('is sent to sign-in from anywhere else', () {
      expect(authRedirect(signedOut, Routes.today), Routes.signIn);
      expect(authRedirect(signedOut, Routes.splash), Routes.signIn);
      expect(authRedirect(signedOut, '/train'), Routes.signIn);
    });
  });

  group('signed in', () {
    test('is kept off the auth screens and the splash', () {
      for (final r in Routes.authRoutes) {
        expect(authRedirect(signedIn, r), Routes.today, reason: r);
      }
      expect(authRedirect(signedIn, Routes.splash), Routes.today);
    });

    test('goes where it likes otherwise', () {
      expect(authRedirect(signedIn, Routes.today), isNull);
      expect(authRedirect(signedIn, '/train'), isNull);
      expect(authRedirect(signedIn, Routes.profile), isNull);
    });

    test('may revisit the plan screen once onboarded', () {
      // Screen 7 marks the session complete while still on screen; the guard
      // must not yank it away (§32: the plan is shown, not flashed).
      expect(authRedirect(signedIn, Routes.onboarding), isNull);
    });
  });

  group('signed in, onboarding unfinished', () {
    test('is sent to onboarding from anywhere but onboarding', () {
      expect(authRedirect(unfinished, Routes.today), Routes.onboarding);
      expect(authRedirect(unfinished, Routes.profile), Routes.onboarding);
      expect(authRedirect(unfinished, Routes.splash), Routes.onboarding);
      for (final r in Routes.authRoutes) {
        expect(authRedirect(unfinished, r), Routes.onboarding, reason: r);
      }
    });

    test('stays on onboarding', () {
      expect(authRedirect(unfinished, Routes.onboarding), isNull);
    });

    test('a fresh sign-up is treated the same as a resume', () {
      final fresh = AsyncData<AuthState>(
        AuthState.signedIn(newUserProfile, isNewUser: true),
      );
      expect(authRedirect(fresh, Routes.today), Routes.onboarding);
      expect(authRedirect(fresh, Routes.onboarding), isNull);
    });
  });

  test('an error state with no prior value is treated as not-yet-known', () {
    final errored = AsyncError<AuthState>(Exception('x'), StackTrace.empty);
    expect(authRedirect(errored, Routes.today), Routes.splash);
  });
}
