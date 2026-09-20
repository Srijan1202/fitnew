import '../../../../core/errors/result.dart';
import '../entities/auth_state.dart';

/// The auth contract the presentation layer depends on. Contains no business
/// rules (§7.3): it authenticates with Firebase, exchanges the token with the
/// backend, and persists the result. Everything about *who this user is* is
/// decided by the backend's `/auth/session`.
abstract class AuthRepository {
  /// Restores the persisted session on cold start. Resolves to `signedIn`
  /// with the cached profile when Firebase still has a user, `signedOut`
  /// otherwise. Never throws — a failure to restore is `signedOut`.
  Future<AuthState> restore();

  /// Emits whenever the Firebase user changes: sign-in, sign-out, or a
  /// revocation detected on token refresh. Used to keep the gate honest when
  /// a session ends outside the app's own actions.
  Stream<AuthState> changes();

  Future<Result<AuthState>> signInWithEmail({
    required String email,
    required String password,
  });

  Future<Result<AuthState>> signUpWithEmail({
    required String email,
    required String password,
  });

  Future<Result<AuthState>> signInWithGoogle();

  Future<Result<void>> sendPasswordReset({required String email});

  /// Revokes on the server (best effort — works offline), signs out of
  /// Firebase and Google, clears local storage. Always ends `signedOut`.
  Future<void> signOut();

  /// Updates the cached profile so the next cold start routes correctly.
  /// Called after `/onboarding/complete` succeeds; the server is already
  /// authoritative, this keeps the local fast path in step with it.
  Future<void> cacheOnboardingStage(String stage);
}
