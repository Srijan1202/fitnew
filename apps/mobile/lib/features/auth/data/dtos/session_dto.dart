import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/user_profile.dart';

part 'session_dto.freezed.dart';
part 'session_dto.g.dart';

/// Wire shape of `POST /v1/auth/session` (`createSessionResponseSchema`).
@freezed
abstract class CreateSessionResponse with _$CreateSessionResponse {
  const factory CreateSessionResponse({
    required UserProfile user,
    required bool isNewUser,
  }) = _CreateSessionResponse;

  factory CreateSessionResponse.fromJson(Map<String, dynamic> json) =>
      _$CreateSessionResponseFromJson(json);
}

/// Request body. Device context only — identity comes from the Bearer token,
/// and the server rejects any other key (`.strict()`), so this must never
/// grow a `userId`.
@freezed
abstract class CreateSessionRequest with _$CreateSessionRequest {
  const factory CreateSessionRequest({
    String? timezone,
    String? locale,
  }) = _CreateSessionRequest;

  factory CreateSessionRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateSessionRequestFromJson(json);
}
