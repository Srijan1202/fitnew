// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserProfile _$UserProfileFromJson(Map<String, dynamic> json) => _UserProfile(
      id: json['id'] as String,
      email: json['email'] as String?,
      displayName: json['displayName'] as String? ?? null,
      timezone: json['timezone'] as String,
      locale: json['locale'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      onboardingStage: json['onboardingStage'] as String? ?? 'goal',
    );

Map<String, dynamic> _$UserProfileToJson(_UserProfile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'displayName': instance.displayName,
      'timezone': instance.timezone,
      'locale': instance.locale,
      'createdAt': instance.createdAt.toIso8601String(),
      'onboardingStage': instance.onboardingStage,
    };
