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
