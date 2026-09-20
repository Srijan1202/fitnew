// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CreateSessionResponse _$CreateSessionResponseFromJson(
        Map<String, dynamic> json) =>
    _CreateSessionResponse(
      user: UserProfile.fromJson(json['user'] as Map<String, dynamic>),
      isNewUser: json['isNewUser'] as bool,
    );

Map<String, dynamic> _$CreateSessionResponseToJson(
        _CreateSessionResponse instance) =>
    <String, dynamic>{
      'user': instance.user,
      'isNewUser': instance.isNewUser,
    };

_CreateSessionRequest _$CreateSessionRequestFromJson(
        Map<String, dynamic> json) =>
    _CreateSessionRequest(
      timezone: json['timezone'] as String?,
      locale: json['locale'] as String?,
    );

Map<String, dynamic> _$CreateSessionRequestToJson(
        _CreateSessionRequest instance) =>
    <String, dynamic>{
      'timezone': instance.timezone,
      'locale': instance.locale,
    };
