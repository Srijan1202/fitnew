import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../exercise/domain/entities/exercise.dart';
import '../../../profile/domain/entities/vocabulary.dart';
import '../../../training/domain/entities/program.dart';

part 'workout.freezed.dart';
part 'workout.g.dart';

/// Wire shapes of `@fitos/contracts` workout.ts (Phase 5). A session is
/// what the user actually did; targets come from the plan, "last time"
/// from history. Nothing here recommends a load — that is Phase 6.

enum SetType {
  @JsonValue('warmup')
  warmup('warmup', 'Warm-up'),
  @JsonValue('working')
  working('working', 'Working'),
  @JsonValue('drop')
  drop('drop', 'Drop'),
  @JsonValue('backoff')
  backoff('backoff', 'Back-off');

  const SetType(this.wire, this.label);
  final String wire;
  final String label;
}

enum SessionStatus {
  @JsonValue('active')
  active('active'),
  @JsonValue('completed')
  completed('completed'),
  @JsonValue('abandoned')
  abandoned('abandoned');

  const SessionStatus(this.wire);
  final String wire;
}

enum PrType {
  @JsonValue('1rm_est')
  oneRmEst('1rm_est', 'Estimated 1RM'),
  @JsonValue('weight')
  weight('weight', 'Heaviest'),
  @JsonValue('reps')
  reps('reps', 'Most reps'),
  @JsonValue('volume')
  volume('volume', 'Most volume');

  const PrType(this.wire, this.label);
  final String wire;
  final String label;
}

@freezed
abstract class SetLog with _$SetLog {
  const SetLog._();

  const factory SetLog({
    required String id,
    required String clientSetId,
    required int setIndex,
    required SetType setType,
    required double? weightKg,
    required int reps,
    required int? rir,
    required bool isPr,
    required String loggedAt,
    required String? plannedSetId,
  }) = _SetLog;

  factory SetLog.fromJson(Map<String, dynamic> json) => _$SetLogFromJson(json);
}

@freezed
abstract class LastSet with _$LastSet {
  const factory LastSet({
    required int setIndex,
    required double? weightKg,
    required int reps,
    required int? rir,
  }) = _LastSet;

  factory LastSet.fromJson(Map<String, dynamic> json) =>
      _$LastSetFromJson(json);
}

/// The most recent completed session's working sets for an exercise.
@freezed
abstract class LastPerformance with _$LastPerformance {
  const factory LastPerformance({
    required String sessionId,
    required String completedAt,
    required List<LastSet> sets,
  }) = _LastPerformance;

  factory LastPerformance.fromJson(Map<String, dynamic> json) =>
      _$LastPerformanceFromJson(json);
}

/// What a set row opens with (core's rule, computed by the server): the
/// plan's target reps, last time's weight when there is one, the plan's
/// RIR. A description of the past and the plan, never a recommendation.
@freezed
abstract class SetPrefill with _$SetPrefill {
  const factory SetPrefill({
    required int setIndex,
    required int reps,
    required double? weightKg,
    required int rir,
    required String weightSource,
  }) = _SetPrefill;

  factory SetPrefill.fromJson(Map<String, dynamic> json) =>
      _$SetPrefillFromJson(json);
}

@freezed
abstract class SessionExercise with _$SessionExercise {
  const SessionExercise._();

  const factory SessionExercise({
    required String id,
    required String clientExerciseId,
    required String exerciseId,
    required String slug,
    required String name,
    required MovementPattern movementPattern,
    required List<Equipment> equipment,
    required Difficulty difficulty,
    required List<MuscleGroup> primaryMuscles,
    required List<MuscleGroup> secondaryMuscles,
    required double incrementKg,
    required int orderIndex,
    required int? supersetGroup,
    required String? plannedExerciseId,
    required List<PlannedSet> targets,
    @Default(<SetPrefill>[]) List<SetPrefill> prefill,
    required LastPerformance? lastPerformance,
    required List<SetLog> sets,
  }) = _SessionExercise;

  factory SessionExercise.fromJson(Map<String, dynamic> json) =>
      _$SessionExerciseFromJson(json);

  /// Compound patterns rest longer (owner decision 8.4).
  bool get isCompound => const {
        MovementPattern.squat,
        MovementPattern.hinge,
        MovementPattern.lunge,
        MovementPattern.horizontalPush,
        MovementPattern.verticalPush,
        MovementPattern.horizontalPull,
        MovementPattern.verticalPull,
      }.contains(movementPattern);
}

@freezed
abstract class PersonalRecord with _$PersonalRecord {
  const factory PersonalRecord({
    required PrType prType,
    required String exerciseId,
    required String exerciseName,
    required double value,
    required double previous,
    required String setLogId,
    required String reason,
  }) = _PersonalRecord;

  factory PersonalRecord.fromJson(Map<String, dynamic> json) =>
      _$PersonalRecordFromJson(json);
}

@freezed
abstract class SessionSummary with _$SessionSummary {
  const factory SessionSummary({
    required int durationSeconds,
    required int totalSets,
    required int workingSets,
    required double tonnageKg,
    required Map<String, double> hardSetsByMuscle,
    required int exercisesCompleted,
    required int exercisesSkipped,
    required List<PersonalRecord> prs,
  }) = _SessionSummary;

  factory SessionSummary.fromJson(Map<String, dynamic> json) =>
      _$SessionSummaryFromJson(json);
}

@freezed
abstract class WorkoutSession with _$WorkoutSession {
  const WorkoutSession._();

  const factory WorkoutSession({
    required String id,
    required String clientSessionId,
    required SessionStatus status,
    required String? programId,
    required String? programDayId,
    required String name,
    required String startedAt,
    required String? completedAt,
    required int? durationSeconds,
    required String? notes,
    required List<SessionExercise> exercises,
    required SessionSummary? summary,
  }) = _WorkoutSession;

  factory WorkoutSession.fromJson(Map<String, dynamic> json) =>
      _$WorkoutSessionFromJson(json);

  int get workingSetsLogged => exercises.fold(
        0,
        (n, x) => n + x.sets.where((s) => s.setType == SetType.working).length,
      );
}

@freezed
abstract class SessionListItem with _$SessionListItem {
  const factory SessionListItem({
    required String id,
    required SessionStatus status,
    required String name,
    required String startedAt,
    required String? completedAt,
    required int? durationSeconds,
    required int exerciseCount,
    required int workingSets,
    required double tonnageKg,
    required int prCount,
  }) = _SessionListItem;

  factory SessionListItem.fromJson(Map<String, dynamic> json) =>
      _$SessionListItemFromJson(json);
}

@freezed
abstract class SessionListResponse with _$SessionListResponse {
  const factory SessionListResponse({
    required List<SessionListItem> items,
    required String? nextBefore,
  }) = _SessionListResponse;

  factory SessionListResponse.fromJson(Map<String, dynamic> json) =>
      _$SessionListResponseFromJson(json);
}

@freezed
abstract class TodayExercise with _$TodayExercise {
  const factory TodayExercise({
    required String plannedExerciseId,
    required String exerciseId,
    required String slug,
    required String name,
    required MovementPattern movementPattern,
    required List<Equipment> equipment,
    required Difficulty difficulty,
    required List<MuscleGroup> primaryMuscles,
    required List<MuscleGroup> secondaryMuscles,
    required int orderIndex,
    required double incrementKg,
    required List<PlannedSet> targets,
    @Default(<SetPrefill>[]) List<SetPrefill> prefill,
    required LastPerformance? lastPerformance,
  }) = _TodayExercise;

  factory TodayExercise.fromJson(Map<String, dynamic> json) =>
      _$TodayExerciseFromJson(json);
}

@freezed
abstract class TodayResponse with _$TodayResponse {
  const factory TodayResponse({
    required String date,
    required int dayOfWeek,
    required String? programId,
    required String? programDayId,
    required String? sessionName,
    required bool isRest,
    required List<MuscleGroup> focus,
    required List<TodayExercise> exercises,
    required WorkoutSession? activeSession,
    required String? completedSessionId,
  }) = _TodayResponse;

  factory TodayResponse.fromJson(Map<String, dynamic> json) =>
      _$TodayResponseFromJson(json);
}

/* ------------------------------------------------------------- requests -- */

/// An exercise seeded on the phone before the server heard of the session;
/// the server adopts the client id so offline-logged sets replay cleanly.
@freezed
abstract class SeededExercise with _$SeededExercise {
  const factory SeededExercise({
    required String clientExerciseId,
    required String exerciseId,
    String? plannedExerciseId,
    required int orderIndex,
  }) = _SeededExercise;

  factory SeededExercise.fromJson(Map<String, dynamic> json) =>
      _$SeededExerciseFromJson(json);
}

@freezed
abstract class StartSessionRequest with _$StartSessionRequest {
  const factory StartSessionRequest({
    required String clientSessionId,
    String? programDayId,
    required String startedAt,
    List<SeededExercise>? exercises,
  }) = _StartSessionRequest;

  factory StartSessionRequest.fromJson(Map<String, dynamic> json) =>
      _$StartSessionRequestFromJson(json);
}

/// One set in a batch: names its exercise by client id, so it can be
/// written before the server has ever heard of the exercise.
@freezed
abstract class LogSetInput with _$LogSetInput {
  const factory LogSetInput({
    required String clientSetId,
    required String clientExerciseId,
    required int setIndex,
    required SetType setType,
    required double? weightKg,
    required int reps,
    required int? rir,
    required String loggedAt,
    String? plannedSetId,
  }) = _LogSetInput;

  factory LogSetInput.fromJson(Map<String, dynamic> json) =>
      _$LogSetInputFromJson(json);
}

@freezed
abstract class LogSetsRequest with _$LogSetsRequest {
  const factory LogSetsRequest({
    required List<LogSetInput> sets,
    @Default(false) bool merge,
  }) = _LogSetsRequest;

  factory LogSetsRequest.fromJson(Map<String, dynamic> json) =>
      _$LogSetsRequestFromJson(json);
}

@freezed
abstract class PatchSetRequest with _$PatchSetRequest {
  const factory PatchSetRequest({
    SetType? setType,

    /// `weightCleared` sends an explicit null.
    double? weightKg,
    @Default(false) bool weightCleared,
    int? reps,
    int? rir,
    @Default(false) bool rirCleared,
  }) = _PatchSetRequest;

  factory PatchSetRequest.fromJson(Map<String, dynamic> json) =>
      _$PatchSetRequestFromJson(json);
}

@freezed
abstract class AddSessionExerciseRequest with _$AddSessionExerciseRequest {
  const factory AddSessionExerciseRequest({
    required String clientExerciseId,
    required String exerciseId,
    String? plannedExerciseId,
    int? orderIndex,
    int? supersetGroup,
  }) = _AddSessionExerciseRequest;

  factory AddSessionExerciseRequest.fromJson(Map<String, dynamic> json) =>
      _$AddSessionExerciseRequestFromJson(json);
}

@freezed
abstract class PatchSessionExerciseRequest with _$PatchSessionExerciseRequest {
  const factory PatchSessionExerciseRequest({
    int? orderIndex,
    int? supersetGroup,
    @Default(false) bool supersetCleared,
    String? exerciseId,
    @Default(false) bool removed,
  }) = _PatchSessionExerciseRequest;

  factory PatchSessionExerciseRequest.fromJson(Map<String, dynamic> json) =>
      _$PatchSessionExerciseRequestFromJson(json);
}

@freezed
abstract class CompleteSessionRequest with _$CompleteSessionRequest {
  const factory CompleteSessionRequest({
    required String completedAt,
    String? notes,
  }) = _CompleteSessionRequest;

  factory CompleteSessionRequest.fromJson(Map<String, dynamic> json) =>
      _$CompleteSessionRequestFromJson(json);
}
