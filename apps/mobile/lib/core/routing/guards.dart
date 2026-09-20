import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/entities/auth_state.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import 'router.dart';

/// Route guard (§11: go_router guards).
///
/// Pure function of (auth state, location) → redirect or null, so it is
/// unit-testable without a widget tree. The three states map to three
/// regions of the app:
///
///   unknown   → hold on the splash until the session is restored
///   signedOut → the auth screens only
///   signedIn  → onboarding until complete, then everything except auth
String? authRedirect(AsyncValue<AuthState> auth, String location) {
  final isAuthRoute = Routes.authRoutes.contains(location);
  final isSplash = location == Routes.splash;
  final isOnboarding = location.startsWith(Routes.onboarding);

  // Restoring: park on the splash. Sends the user to sign-in only once we
  // know they are signed out, never merely because we have not checked yet.
  if (auth.isLoading && auth.value == null) {
    return isSplash ? null : Routes.splash;
  }

  return switch (auth.value) {
    null || AuthUnknown() => isSplash ? null : Routes.splash,
    AuthSignedOut() => isAuthRoute ? null : Routes.signIn,
    AuthSignedIn(:final profile) => switch (profile.onboardingStage) {
        // Signed in but onboarding unfinished — from a fresh sign-up OR a
        // returning user who quit halfway (§32: resumes after a kill). The
        // only places they may be are the onboarding screens.
        != 'complete' => isOnboarding ? null : Routes.onboarding,
        // Fully onboarded: keep them off auth and the splash. Onboarding
        // stays reachable so screen 7 (the plan) is still on screen after
        // /complete marks the session; "Start" leaves it explicitly.
        _ => (isAuthRoute || isSplash) ? Routes.today : null,
      },
  };
}

/// Makes go_router re-evaluate redirects whenever auth state changes, without
/// rebuilding the router. Listenable is what go_router wants; Riverpod is
/// where the state lives.
class AuthRefresh extends ChangeNotifier {
  AuthRefresh(Ref ref) {
    _sub = ref.listen<AsyncValue<AuthState>>(
      authControllerProvider,
      (_, __) => notifyListeners(),
    );
  }

  late final ProviderSubscription<AsyncValue<AuthState>> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
