import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../exercise/domain/entities/exercise.dart';
import '../../../profile/domain/entities/vocabulary.dart';
import '../../../training/domain/entities/program.dart';

part 'workout.freezed.dart';
part 'workout.g.dart';

/// Wire shapes of `@fitos/contracts` workout.ts (Phase 5 + 6). A session is
/// what the user actually did; targets come from the plan, "last time"
/// from history. Phase 6 adds the engine's recommendation with its reason,
/// the prior best, the deload state and volume — all computed on the
/// server; nothing here decides a load.

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

/* ------------------------------------------------- Phase 6: progression -- */

/// §12.4 branches, exactly as the engine names them.
enum ProgressionAction {
  @JsonValue('increase-load')
  increaseLoad('increase-load', 'Increase load'),
  @JsonValue('add-reps')
  addReps('add-reps', 'Add reps'),
  @JsonValue('hold')
  hold('hold', 'Hold'),
  @JsonValue('reduce-load')
  reduceLoad('reduce-load', 'Reduce load'),
  @JsonValue('deload')
  deload('deload', 'Deload'),
  @JsonValue('establish-baseline')
  establishBaseline('establish-baseline', 'Establish baseline');

  const ProgressionAction(this.wire, this.label);
  final String wire;
  final String label;
}

/// What to do next on a lift, with — always — the reason (§12.4).
@freezed
abstract class ProgressionRecommendation with _$ProgressionRecommendation {
  const factory ProgressionRecommendation({
    required ProgressionAction action,
    required double? weightKg,
    required String repTarget,
    required int targetRir,
    required String reason,
    required String basis,
    required int sessionsConsidered,
  }) = _ProgressionRecommendation;

  factory ProgressionRecommendation.fromJson(Map<String, dynamic> json) =>
      _$ProgressionRecommendationFromJson(json);
}

/// The user's best so far on a lift, so a set can be recognised as a
/// record the moment it is logged.
@freezed
abstract class PriorBest with _$PriorBest {
  const PriorBest._();

  const factory PriorBest({
    required double? weightKg,
    required int? repsAtBestWeight,
    required double? estimated1rm,
  }) = _PriorBest;

  factory PriorBest.fromJson(Map<String, dynamic> json) =>
      _$PriorBestFromJson(json);

  static const none =
      PriorBest(weightKg: null, repsAtBestWeight: null, estimated1rm: null);
}

enum SubstitutionTrigger {
  @JsonValue('equipment')
  equipment('equipment'),
  @JsonValue('limitation')
  limitation('limitation'),
  @JsonValue('rejected')
  rejected('rejected');

  const SubstitutionTrigger(this.wire);
  final String wire;
}

@freezed
abstract class SubstitutionAlternative with _$SubstitutionAlternative {
  const factory SubstitutionAlternative({
    required String exerciseId,
    required String slug,
    required String name,
    required List<Equipment> equipment,
  }) = _SubstitutionAlternative;

  factory SubstitutionAlternative.fromJson(Map<String, dynamic> json) =>
      _$SubstitutionAlternativeFromJson(json);
}

/// §12.6: why a planned lift should be swapped and for what — or,
/// honestly, that the library has nothing (`alternative` null).
@freezed
abstract class Substitution with _$Substitution {
  const factory Substitution({
    required SubstitutionTrigger trigger,
    required SubstitutionAlternative? alternative,
    required String reason,
  }) = _Substitution;

  factory Substitution.fromJson(Map<String, dynamic> json) =>
      _$SubstitutionFromJson(json);
}

enum DeloadStatus {
  @JsonValue('none')
  none('none'),
  @JsonValue('offered')
  offered('offered'),
  @JsonValue('active')
  active('active');

  const DeloadStatus(this.wire);
  final String wire;
}

enum DeloadTrigger {
  @JsonValue('fatigue')
  fatigue('fatigue'),
  @JsonValue('mrv')
  mrv('mrv');

  const DeloadTrigger(this.wire);
  final String wire;
}

@freezed
abstract class DeloadState with _$DeloadState {
  const factory DeloadState({
    required DeloadStatus state,
    required DeloadTrigger? trigger,
    required String reason,
    required String? endsOn,
  }) = _DeloadState;

  factory DeloadState.fromJson(Map<String, dynamic> json) =>
      _$DeloadStateFromJson(json);

  static const none = DeloadState(
    state: DeloadStatus.none,
    trigger: null,
    reason: 'No deload is due.',
    endsOn: null,
  );
}

/// An owned muscle with no working set in the last six days (owner 12.7).
@freezed
abstract class NeglectedMuscle with _$NeglectedMuscle {
  const factory NeglectedMuscle({
    required MuscleGroup muscle,
    required int? daysSince,
  }) = _NeglectedMuscle;

  factory NeglectedMuscle.fromJson(Map<String, dynamic> json) =>
      _$NeglectedMuscleFromJson(json);
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
    @Default(null) ProgressionRecommendation? recommendation,
    @Default(PriorBest.none) PriorBest priorBest,
    @Default(null) List<PlannedSet>? originalTargets,
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
    @Default(null) ProgressionRecommendation? recommendation,
    @Default(PriorBest.none) PriorBest priorBest,
    @Default(null) List<PlannedSet>? originalTargets,
    @Default(null) Substitution? substitution,
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
    @Default(null) int? mesocycleWeek,
    @Default(DeloadState.none) DeloadState deload,
    @Default(<NeglectedMuscle>[]) List<NeglectedMuscle> neglected,
  }) = _TodayResponse;

  factory TodayResponse.fromJson(Map<String, dynamic> json) =>
      _$TodayResponseFromJson(json);
}

/* ------------------------------------------------------ Phase 6: volume -- */

enum LandmarkStatus {
  @JsonValue('none')
  none('none', 'None'),
  @JsonValue('below-mv')
  belowMv('below-mv', 'Below MV'),
  @JsonValue('below-mev')
  belowMev('below-mev', 'Below MEV'),
  @JsonValue('mev-to-mav')
  mevToMav('mev-to-mav', 'Productive'),
  @JsonValue('above-mav')
  aboveMav('above-mav', 'Above MAV'),
  @JsonValue('at-mrv')
  atMrv('at-mrv', 'At MRV');

  const LandmarkStatus(this.wire, this.label);
  final String wire;
  final String label;
}

@freezed
abstract class VolumeLandmarks with _$VolumeLandmarks {
  const factory VolumeLandmarks({
    required double mv,
    required double mev,
    required double mavLow,
    required double mavHigh,
    required double mrv,
  }) = _VolumeLandmarks;

  factory VolumeLandmarks.fromJson(Map<String, dynamic> json) =>
      _$VolumeLandmarksFromJson(json);
}

@freezed
abstract class MuscleWeek with _$MuscleWeek {
  const factory MuscleWeek({
    required MuscleGroup muscle,
    required double hardSets,
    required double tonnageKg,
    required LandmarkStatus status,
    required VolumeLandmarks landmarks,
    required bool owned,
  }) = _MuscleWeek;

  factory MuscleWeek.fromJson(Map<String, dynamic> json) =>
      _$MuscleWeekFromJson(json);
}

@freezed
abstract class VolumeWeek with _$VolumeWeek {
  const factory VolumeWeek({
    required String isoWeek,
    required List<MuscleWeek> muscles,
  }) = _VolumeWeek;

  factory VolumeWeek.fromJson(Map<String, dynamic> json) =>
      _$VolumeWeekFromJson(json);
}

/// Current ISO week + 3 previous (owner 12.8), oldest first.
@freezed
abstract class VolumeResponse with _$VolumeResponse {
  const factory VolumeResponse({
    required List<VolumeWeek> weeks,
    required List<MuscleGroup> owned,
    required List<NeglectedMuscle> neglected,
    required int? mesocycleWeek,
    required DeloadState deload,
  }) = _VolumeResponse;

  factory VolumeResponse.fromJson(Map<String, dynamic> json) =>
      _$VolumeResponseFromJson(json);
}

@freezed
abstract class ProgressionTarget with _$ProgressionTarget {
  const factory ProgressionTarget({
    required int repMin,
    required int repMax,
    required int targetRir,
    required int sets,
    required double incrementKg,
  }) = _ProgressionTarget;

  factory ProgressionTarget.fromJson(Map<String, dynamic> json) =>
      _$ProgressionTargetFromJson(json);
}

@freezed
abstract class ProgressionHistorySet with _$ProgressionHistorySet {
  const factory ProgressionHistorySet({
    required int setIndex,
    required double? weightKg,
    required int reps,
    required int? rir,
  }) = _ProgressionHistorySet;

  factory ProgressionHistorySet.fromJson(Map<String, dynamic> json) =>
      _$ProgressionHistorySetFromJson(json);
}

@freezed
abstract class ProgressionHistoryEntry with _$ProgressionHistoryEntry {
  const factory ProgressionHistoryEntry({
    required String sessionId,
    required String date,
    required List<ProgressionHistorySet> sets,
  }) = _ProgressionHistoryEntry;

  factory ProgressionHistoryEntry.fromJson(Map<String, dynamic> json) =>
      _$ProgressionHistoryEntryFromJson(json);
}

/// One lift's last three sessions and what the engine makes of them.
@freezed
abstract class ProgressionDetail with _$ProgressionDetail {
  const factory ProgressionDetail({
    required String exerciseId,
    required String name,
    required ProgressionTarget? target,
    required ProgressionRecommendation recommendation,
    required List<ProgressionHistoryEntry> history,
  }) = _ProgressionDetail;

  factory ProgressionDetail.fromJson(Map<String, dynamic> json) =>
      _$ProgressionDetailFromJson(json);
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
