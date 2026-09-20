import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_profile.freezed.dart';
part 'user_profile.g.dart';

/// The app-facing profile, exactly as `POST /v1/auth/session` returns it
/// (`@fitos/contracts` userProfileSchema). No Firebase uid, no password —
/// the backend owns this shape and the client only renders it.
@freezed
abstract class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String id,
    required String? email,
    required String timezone,
    required String locale,
    required DateTime createdAt,

    /// Next onboarding step or 'complete' (Phase 2). Drives the route guard.
    @Default('goal') String onboardingStage,
  }) = _UserProfile;

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);
}
