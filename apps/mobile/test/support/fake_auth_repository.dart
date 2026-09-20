import 'dart:async';

import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/features/auth/domain/entities/auth_state.dart';
import 'package:fitos/features/auth/domain/entities/user_profile.dart';
import 'package:fitos/features/auth/domain/repositories/auth_repository.dart';

final testProfile = UserProfile(
  id: '4f0b9a2e-1c2d-4e3f-8a9b-0c1d2e3f4a5b',
  email: 'student@vit.ac.in',
  timezone: 'Asia/Kolkata',
  locale: 'en-IN',
  createdAt: DateTime.utc(2026, 9, 20, 10),
);

/// Scripted AuthRepository. Every method returns what the test told it to and
/// records that it was called.
class FakeAuthRepository implements AuthRepository {
  AuthState restoreResult = const AuthState.signedOut();
  Result<AuthState> nextSignIn = Ok(AuthState.signedIn(testProfile));
  Result<void> nextReset = const Ok(null);

  final calls = <String>[];
  final _changes = StreamController<AuthState>.broadcast();

  /// Simulate the session ending outside the app (revoked elsewhere).
  void emitExternal(AuthState state) => _changes.add(state);

  @override
  Future<AuthState> restore() async {
    calls.add('restore');
    return restoreResult;
  }

  @override
  Stream<AuthState> changes() => _changes.stream;

  @override
  Future<Result<AuthState>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    calls.add('signInWithEmail:$email');
    return nextSignIn;
  }

  @override
  Future<Result<AuthState>> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    calls.add('signUpWithEmail:$email');
    return nextSignIn;
  }

  @override
  Future<Result<AuthState>> signInWithGoogle() async {
    calls.add('signInWithGoogle');
    return nextSignIn;
  }

  @override
  Future<Result<void>> sendPasswordReset({required String email}) async {
    calls.add('sendPasswordReset:$email');
    return nextReset;
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
  }

  void dispose() => _changes.close();
}

/// A failure with a recognisable message, for assertions.
const wrongPassword = Credential(
  'Email or password is incorrect.',
  code: 'wrong-password',
);
