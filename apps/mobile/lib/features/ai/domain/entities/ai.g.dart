// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AiStatus _$AiStatusFromJson(Map<String, dynamic> json) => _AiStatus(
      configured: json['configured'] as bool,
      provider: json['provider'] as String,
      model: json['model'] as String?,
      excludes: (json['excludes'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
    );

Map<String, dynamic> _$AiStatusToJson(_AiStatus instance) => <String, dynamic>{
      'configured': instance.configured,
      'provider': instance.provider,
      'model': instance.model,
      'excludes': instance.excludes,
    };

_AiChatMessage _$AiChatMessageFromJson(Map<String, dynamic> json) =>
    _AiChatMessage(
      role: $enumDecode(_$AiRoleEnumMap, json['role']),
      content: json['content'] as String,
    );

Map<String, dynamic> _$AiChatMessageToJson(_AiChatMessage instance) =>
    <String, dynamic>{
      'role': _$AiRoleEnumMap[instance.role]!,
      'content': instance.content,
    };

const _$AiRoleEnumMap = {
  AiRole.user: 'user',
  AiRole.assistant: 'assistant',
};

_AiChatRequest _$AiChatRequestFromJson(Map<String, dynamic> json) =>
    _AiChatRequest(
      message: json['message'] as String,
      history: (json['history'] as List<dynamic>?)
              ?.map((e) => AiChatMessage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <AiChatMessage>[],
    );

Map<String, dynamic> _$AiChatRequestToJson(_AiChatRequest instance) =>
    <String, dynamic>{
      'message': instance.message,
      'history': instance.history,
    };

_AiAction _$AiActionFromJson(Map<String, dynamic> json) => _AiAction(
      type: $enumDecode(_$AiActionTypeEnumMap, json['type']),
      label: json['label'] as String,
      exerciseId: json['exerciseId'] as String? ?? null,
      sessionId: json['sessionId'] as String? ?? null,
    );

Map<String, dynamic> _$AiActionToJson(_AiAction instance) => <String, dynamic>{
      'type': _$AiActionTypeEnumMap[instance.type]!,
      'label': instance.label,
      'exerciseId': instance.exerciseId,
      'sessionId': instance.sessionId,
    };

const _$AiActionTypeEnumMap = {
  AiActionType.openWorkout: 'open-workout',
  AiActionType.openPlan: 'open-plan',
  AiActionType.openVolume: 'open-volume',
  AiActionType.openProgression: 'open-progression',
  AiActionType.openProfile: 'open-profile',
  AiActionType.openNutrition: 'open-nutrition',
  AiActionType.openExercise: 'open-exercise',
  AiActionType.openHistory: 'open-history',
};

_AiChatResponse _$AiChatResponseFromJson(Map<String, dynamic> json) =>
    _AiChatResponse(
      text: json['text'] as String,
      actions: (json['actions'] as List<dynamic>?)
              ?.map((e) => AiAction.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <AiAction>[],
      toolsUsed: (json['toolsUsed'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      model: json['model'] as String,
    );

Map<String, dynamic> _$AiChatResponseToJson(_AiChatResponse instance) =>
    <String, dynamic>{
      'text': instance.text,
      'actions': instance.actions,
      'toolsUsed': instance.toolsUsed,
      'model': instance.model,
    };
