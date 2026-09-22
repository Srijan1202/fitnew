import 'dart:convert';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/storage/secure_storage.dart';
import '../domain/entities/auth_state.dart';
import '../domain/entities/user_profile.dart';
import '../domain/repositories/auth_repository.dart';
import 'dtos/session_dto.dart';
import 'firebase_auth_data_source.dart';
import 'session_remote_data_source.dart';

/// Composes the §11 flow:
///   Firebase authenticates → ID token → POST /auth/session → profile.
///
/// This class decides nothing about the user. It moves a credential to the
/// backend and stores what the backend says back.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required CredentialSource credentials,
    required SessionRemoteDataSource session,
    required SessionStore store,
    required String? Function() timeZoneName,
    required String? Function() localeTag,
  })  : _credentials = credentials,
        _session = session,
        _store = store,
        _timeZoneName = timeZoneName,
        _localeTag = localeTag;

  final CredentialSource _credentials;
  final SessionRemoteDataSource _session;
  final SessionStore _store;
  final String? Function() _timeZoneName;
  final String? Function() _localeTag;

  @override
  Future<AuthState> restore() async {
    if (_credentials.currentUid == null) {
      await _store.clear();
      return const AuthState.signedOut();
    }
    // Fast path: the profile we stored last time. No network at cold start.
    final cached = await _store.readProfileJson();
    if (cached != null) {
      try {
        final profile = UserProfile.fromJson(
          jsonDecode(cached) as Map<String, dynamic>,
        );
        return AuthState.signedIn(profile);
      } on FormatException {
        // Corrupt cache: fall through and re-fetch.
      }
    }
    // Firebase has a user but we have no profile (fresh install with a
    // restored Firebase session, or a cleared cache): ask the server. The
    // backend is the source of truth for who this is and how far they got —
    // an existing account comes back at its real onboarding stage, never at
    // "goal" — so nothing is asked of the user that the server already has.
    final exchanged = await _exchange(keepCredentialOnFailure: true);
    return exchanged.when(
      ok: (state) => state,
      // Could not reach the server: the Firebase session is kept so the next
      // cold start (or the next sign-in) does not need a password again.
      err: (_) => const AuthState.signedOut(),
    );
  }

  @override
  Stream<AuthState> changes() async* {
    await for (final uid in _credentials.uidChanges()) {
      if (uid == null) {
        await _store.clear();
        yield const AuthState.signedOut();
      } else {
        yield await restore();
      }
    }
  }

  /// The token exchange. Runs after every successful Firebase sign-in.
  ///
  /// [keepCredentialOnFailure]: at cold start a transient failure (offline,
  /// server down) must not throw away a valid Firebase session; after an
  /// explicit sign-in it must, so no half-signed-in state is left behind.
  Future<Result<AuthState>> _exchange({
    bool keepCredentialOnFailure = false,
  }) async {
    final token = await _credentials.idToken();
    if (token != null) await _store.writeIdToken(token);

    final result = await _session.createSession(
      CreateSessionRequest(timezone: _timeZoneName(), locale: _localeTag()),
    );
    return result.when(
      ok: (response) async {
        await _store.writeProfileJson(jsonEncode(response.user.toJson()));
        return Ok(
          AuthState.signedIn(response.user, isNewUser: response.isNewUser),
        );
      },
      err: (failure) async {
        // Firebase accepted the credential but the backend did not create a
        // session. Do not leave a half-signed-in state behind — unless this
        // is a cold-start restore that merely could not reach the server.
        final transient =
            failure is Offline || failure is Unknown || failure is RateLimited;
        if (!(keepCredentialOnFailure && transient)) {
          await _credentials.signOut();
        }
        await _store.clear();
        return Err<AuthState>(failure);
      },
    );
  }

  Future<Result<AuthState>> _afterCredential(Result<void> signIn) =>
      signIn.when(
        ok: (_) => _exchange(),
        err: (failure) async => Err(failure),
      );

  @override
  Future<Result<AuthState>> signInWithEmail({
    required String email,
    required String password,
  }) async =>
      _afterCredential(await _credentials.signInWithEmail(email, password));

  @override
  Future<Result<AuthState>> signUpWithEmail({
    required String email,
    required String password,
  }) async =>
      _afterCredential(await _credentials.signUpWithEmail(email, password));

  @override
  Future<Result<AuthState>> signInWithGoogle() async =>
      _afterCredential(await _credentials.signInWithGoogle());

  @override
  Future<Result<void>> sendPasswordReset({required String email}) =>
      _credentials.sendPasswordReset(email);

  @override
  Future<void> cacheOnboardingStage(String stage) async {
    final cached = await _store.readProfileJson();
    if (cached == null) return;
    try {
      final profile = UserProfile.fromJson(
        jsonDecode(cached) as Map<String, dynamic>,
      );
      await _store.writeProfileJson(
        jsonEncode(profile.copyWith(onboardingStage: stage).toJson()),
      );
    } on FormatException {
      // A corrupt cache is rebuilt on the next restore; nothing to do here.
    }
  }

  @override
  String? get suggestedDisplayName => _credentials.currentDisplayName;

  @override
  Future<void> signOut() async {
    // Server first while we still hold a valid token; best effort.
    await _session.deleteSession();
    await _credentials.signOut();
    await _store.clear();
  }
}
