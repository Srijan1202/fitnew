import 'package:freezed_annotation/freezed_annotation.dart';

part 'ai.freezed.dart';
part 'ai.g.dart';

/// Wire shapes of `@fitos/contracts` ai.ts (Phase 6.6). The assistant runs
/// on the FITOS server over the user's own FITOS data; the phone sends the
/// recent exchange and shows the answer. Nothing here calls a model.

@freezed
abstract class AiStatus with _$AiStatus {
  const factory AiStatus({
    required bool configured,
    required String provider,
    required String? model,
    @Default(<String>[]) List<String> excludes,
  }) = _AiStatus;

  factory AiStatus.fromJson(Map<String, dynamic> json) =>
      _$AiStatusFromJson(json);
}

enum AiRole {
  @JsonValue('user')
  user('user'),
  @JsonValue('assistant')
  assistant('assistant');

  const AiRole(this.wire);
  final String wire;
}

@freezed
abstract class AiChatMessage with _$AiChatMessage {
  const factory AiChatMessage({
    required AiRole role,
    required String content,
  }) = _AiChatMessage;

  factory AiChatMessage.fromJson(Map<String, dynamic> json) =>
      _$AiChatMessageFromJson(json);
}

@freezed
abstract class AiChatRequest with _$AiChatRequest {
  const factory AiChatRequest({
    required String message,
    @Default(<AiChatMessage>[]) List<AiChatMessage> history,
  }) = _AiChatRequest;

  factory AiChatRequest.fromJson(Map<String, dynamic> json) =>
      _$AiChatRequestFromJson(json);
}

/// Navigation the assistant may offer under an answer; nothing changes by it.
enum AiActionType {
  @JsonValue('open-workout')
  openWorkout('open-workout'),
  @JsonValue('open-plan')
  openPlan('open-plan'),
  @JsonValue('open-volume')
  openVolume('open-volume'),
  @JsonValue('open-progression')
  openProgression('open-progression'),
  @JsonValue('open-profile')
  openProfile('open-profile'),
  @JsonValue('open-nutrition')
  openNutrition('open-nutrition'),
  @JsonValue('open-exercise')
  openExercise('open-exercise'),
  @JsonValue('open-history')
  openHistory('open-history');

  const AiActionType(this.wire);
  final String wire;
}

@freezed
abstract class AiAction with _$AiAction {
  const factory AiAction({
    required AiActionType type,
    required String label,
    @Default(null) String? exerciseId,
    @Default(null) String? sessionId,
  }) = _AiAction;

  factory AiAction.fromJson(Map<String, dynamic> json) =>
      _$AiActionFromJson(json);
}

@freezed
abstract class AiChatResponse with _$AiChatResponse {
  const factory AiChatResponse({
    required String text,
    @Default(<AiAction>[]) List<AiAction> actions,
    @Default(<String>[]) List<String> toolsUsed,
    required String model,
  }) = _AiChatResponse;

  factory AiChatResponse.fromJson(Map<String, dynamic> json) =>
      _$AiChatResponseFromJson(json);
}
