import 'package:freezed_annotation/freezed_annotation.dart';

import 'user_profile.dart';

part 'auth_state.freezed.dart';

/// What the gate needs to know, and nothing more.
///
/// `unknown` exists so the splash can hold while the persisted session is
/// restored; routing on `signedOut` before that resolves would flash the
/// sign-in screen at every cold start for a user who is in fact signed in.
@freezed
sealed class AuthState with _$AuthState {
  /// Not yet restored from storage. Show the splash.
  const factory AuthState.unknown() = AuthUnknown;

  /// No session. Route to sign-in.
  const factory AuthState.signedOut() = AuthSignedOut;

  /// Session present. `isNewUser` is true only on the sign-in that created
  /// the account, so the gate can route into onboarding (Phase 2) once.
  const factory AuthState.signedIn(
    UserProfile profile, {
    @Default(false) bool isNewUser,
  }) = AuthSignedIn;
}
