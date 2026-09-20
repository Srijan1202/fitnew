import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config/env.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/network/auth_interceptor.dart';

/// Everything Firebase-specific about credentials, behind an interface so the
/// repository can be tested with a fake. Firebase owns the credential; this
/// class only asks it questions (§11).
abstract class CredentialSource implements IdTokenProvider {
  /// Firebase uid if a user is currently signed in, else null.
  String? get currentUid;

  /// Emits the uid (or null) on every auth change.
  Stream<String?> uidChanges();

  Future<Result<void>> signInWithEmail(String email, String password);
  Future<Result<void>> signUpWithEmail(String email, String password);
  Future<Result<void>> signInWithGoogle();
  Future<Result<void>> sendPasswordReset(String email);
  Future<void> signOut();
}

class FirebaseCredentialSource implements CredentialSource {
  FirebaseCredentialSource({
    FirebaseAuth? auth,
    GoogleSignIn? google,
    this.onSessionInvalidated,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _google = google ?? GoogleSignIn.instance;

  final FirebaseAuth _auth;
  final GoogleSignIn _google;

  /// Invoked by the interceptor when a refreshed token is still rejected.
  final Future<void> Function()? onSessionInvalidated;

  bool _googleInitialised = false;

  Future<void> _ensureGoogle() async {
    if (_googleInitialised) return;
    // v7 API: initialise once with the web client id so the returned ID token
    // carries an audience Firebase will accept.
    await _google.initialize(
      serverClientId:
          Env.googleWebClientId.isEmpty ? null : Env.googleWebClientId,
    );
    _googleInitialised = true;
  }

  @override
  String? get currentUid => _auth.currentUser?.uid;

  @override
  Stream<String?> uidChanges() => _auth.authStateChanges().map((u) => u?.uid);

  @override
  Future<String?> idToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      return await user.getIdToken(forceRefresh);
    } on FirebaseAuthException {
      return null;
    }
  }

  @override
  Future<void> onSessionInvalid() async {
    await signOut();
    await onSessionInvalidated?.call();
  }

  Future<Result<void>> _guard(Future<void> Function() action) async {
    try {
      await action();
      return const Ok(null);
    } on FirebaseAuthException catch (e) {
      return Err(ErrorMapper.fromFirebaseAuth(e));
    } on GoogleSignInException catch (e) {
      // The user closed the picker: not an error worth a red line.
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return const Err(
          Credential('Sign-in was cancelled.', code: 'cancelled'),
        );
      }
      return const Err(Unknown('Google sign-in failed. Please try again.'));
    }
  }

  @override
  Future<Result<void>> signInWithEmail(String email, String password) => _guard(
        () => _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        ),
      );

  @override
  Future<Result<void>> signUpWithEmail(String email, String password) => _guard(
        () => _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        ),
      );

  @override
  Future<Result<void>> signInWithGoogle() => _guard(() async {
        await _ensureGoogle();
        final account = await _google.authenticate();
        final idToken = account.authentication.idToken;
        if (idToken == null) {
          throw FirebaseAuthException(
            code: 'invalid-credential',
            message: 'Google returned no ID token',
          );
        }
        await _auth.signInWithCredential(
          GoogleAuthProvider.credential(idToken: idToken),
        );
      });

  @override
  Future<Result<void>> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    if (_googleInitialised) {
      // signOut, not disconnect: keep the account picker fast next time.
      await _google.signOut();
    }
  }
}
