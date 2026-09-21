import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/auth_state.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_providers.dart';

/// Drives the gate and the auth screens.
///
/// State is `AsyncValue<AuthState>`: `loading` while an action is in flight,
/// `error` carrying a [Failure] when one fails, `data` otherwise. Screens
/// render exactly those three and never see an SDK exception (§7.4).
///
/// No business rules live here. Whether a user exists, is new, or what their
/// profile contains is decided by the backend; this class only asks and
/// relays.
class AuthController extends AsyncNotifier<AuthState> {
  StreamSubscription<AuthState>? _changes;

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  Future<AuthState> build() async {
    final repo = _repo;
    // Keep the gate honest if the session ends outside our own actions —
    // revoked on another device, account disabled, token refresh refused.
    _changes?.cancel();
    _changes = repo.changes().listen((next) {
      // Only downgrade automatically. Upgrades come from explicit actions,
      // which already set state and carry isNewUser.
      if (next is AuthSignedOut && state.value is! AuthSignedOut) {
        state = AsyncData(next);
      }
    });
    ref.onDispose(() => _changes?.cancel());
    return repo.restore();
  }

  Future<void> _run(Future<Result<AuthState>> Function() action) async {
    state = const AsyncLoading();
    final result = await action();
    state = result.when<AsyncValue<AuthState>>(
      ok: AsyncData<AuthState>.new,
      err: (Failure failure) =>
          AsyncError<AuthState>(failure, StackTrace.current),
    );
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) =>
      _run(() => _repo.signInWithEmail(email: email, password: password));

  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) =>
      _run(() => _repo.signUpWithEmail(email: email, password: password));

  Future<void> signInWithGoogle() => _run(_repo.signInWithGoogle);

  /// Password reset does not change auth state, so it returns the failure
  /// (or null) for the screen to show inline rather than touching `state`.
  Future<Failure?> sendPasswordReset({required String email}) async {
    final result = await _repo.sendPasswordReset(email: email);
    return result.when(ok: (_) => null, err: (f) => f);
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    await _repo.signOut();
    state = const AsyncData(AuthState.signedOut());
  }

  /// Onboarding finished: the guard must open TODAY now and on every later
  /// cold start, so both the live state and the cached profile change.
  Future<void> markOnboardingComplete() async {
    final current = state.value;
    if (current is AuthSignedIn) {
      state = AsyncData(
        AuthState.signedIn(
          current.profile.copyWith(onboardingStage: 'complete'),
        ),
      );
    }
    await _repo.cacheOnboardingStage('complete');
  }

  /// After the gate has routed a new user into onboarding once, clear the
  /// flag so a rebuild does not route them again.
  void acknowledgeNewUser() {
    final current = state.value;
    if (current is AuthSignedIn && current.isNewUser) {
      state = AsyncData(AuthState.signedIn(current.profile));
    }
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthState>(AuthController.new);

/// The signed-in user's id, or null when there is no session.
///
/// Every provider that loads THIS user's data (profile, programme,
/// onboarding state, templates) watches it, so a sign-out, a sign-in as
/// someone else, or a session re-created after the backend rejected the old
/// one rebuilds them from scratch. Before this, those providers lived for
/// the app's lifetime: an error caught during one session (a 401 while the
/// session was being invalidated) was still the provider's state when the
/// next session opened the Profile screen — the "intermittent error on first
/// load" the owner saw.
final sessionUserIdProvider = Provider<String?>((ref) {
  final state = ref.watch(authControllerProvider).value;
  return state is AuthSignedIn ? state.profile.id : null;
});

/// For session-scoped `build()`s: the current user id, or an
/// [Unauthenticated] failure to throw when there is none (the guard keeps
/// those screens off-screen while signed out, so it is never shown).
String requireSession(Ref ref) {
  final id = ref.watch(sessionUserIdProvider);
  if (id == null) throw const Unauthenticated();
  return id;
}
