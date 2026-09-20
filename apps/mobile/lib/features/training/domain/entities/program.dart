import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../exercise/domain/entities/exercise.dart';
import '../../../profile/domain/entities/vocabulary.dart';

part 'program.freezed.dart';
part 'program.g.dart';

/// Wire shapes of `@fitos/contracts` training.ts. Programme generation is
/// the backend's (§30); the client renders the week and edits it by
/// sending the server exactly what changed.

enum SplitType {
  @JsonValue('full-body')
  fullBody('full-body', 'Full body'),
  @JsonValue('upper-lower')
  upperLower('upper-lower', 'Upper / lower'),
  @JsonValue('push-pull-legs')
  pushPullLegs('push-pull-legs', 'Push / pull / legs'),
  @JsonValue('upper-lower-full')
  upperLowerFull('upper-lower-full', 'Upper / lower + full'),
  @JsonValue('ppl-upper-lower')
  pplUpperLower('ppl-upper-lower', 'PPL + upper / lower'),
  @JsonValue('custom')
  custom('custom', 'Custom');

  const SplitType(this.wire, this.label);
  final String wire;
  final String label;
}

enum ProgramSource {
  @JsonValue('generated')
  generated('generated'),
  @JsonValue('custom')
  custom('custom');

  const ProgramSource(this.wire);
  final String wire;
}

enum ShortfallReason {
  @JsonValue('no-performable-exercise')
  noPerformableExercise('no-performable-exercise'),
  @JsonValue('session-time')
  sessionTime('session-time'),
  @JsonValue('limitation')
  limitation('limitation');

  const ShortfallReason(this.wire);
  final String wire;
}

/// ISO weekday labels, 1 = Monday.
const List<String> kWeekdayLabels = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

@freezed
abstract class PlannedExercise with _$PlannedExercise {
  const PlannedExercise._();

  const factory PlannedExercise({
    required String id,
    required String exerciseId,
    required String slug,
    required String name,
    required MovementPattern movementPattern,
    required List<Equipment> equipment,
    required Difficulty difficulty,
    required bool isUnilateral,
    required List<MuscleGroup> primaryMuscles,
    required int orderIndex,
    required int setCount,
    required int repMin,
    required int repMax,
    required int targetRir,
    required double incrementKg,
    required String? reason,
  }) = _PlannedExercise;

  factory PlannedExercise.fromJson(Map<String, dynamic> json) =>
      _$PlannedExerciseFromJson(json);

  /// "4 × 6–12 @ RIR 1" — the prescription as the engine wrote it.
  String get prescription =>
      '$setCount × ${repMin == repMax ? '$repMin' : '$repMin–$repMax'} @ RIR $targetRir';

  /// The same row as a request to send back, for edits.
  CustomExercise toCustom() => CustomExercise(
        exerciseId: exerciseId,
        setCount: setCount,
        repMin: repMin,
        repMax: repMax,
        targetRir: targetRir,
        incrementKg: incrementKg,
      );
}

@freezed
abstract class ProgramDay with _$ProgramDay {
  const factory ProgramDay({
    required String id,
    required int dayOfWeek,
    required String sessionName,
    required List<MuscleGroup> focus,
    required bool isRest,
    required int estimatedMinutes,
    required List<PlannedExercise> exercises,
  }) = _ProgramDay;

  factory ProgramDay.fromJson(Map<String, dynamic> json) =>
      _$ProgramDayFromJson(json);
}

@freezed
abstract class VolumeShortfall with _$VolumeShortfall {
  const factory VolumeShortfall({
    required MuscleGroup muscle,
    required double targetSets,
    required double plannedSets,
    required ShortfallReason reason,
    required String detail,
  }) = _VolumeShortfall;

  factory VolumeShortfall.fromJson(Map<String, dynamic> json) =>
      _$VolumeShortfallFromJson(json);
}

@freezed
abstract class Program with _$Program {
  const factory Program({
    required String id,
    required String name,
    required SplitType splitType,
    required int daysPerWeek,
    required ProgramSource source,
    required int mesocycleWeek,
    required bool active,
    required String createdAt,
    required List<ProgramDay> days,
    required Map<String, double> weeklyVolume,
    required List<String> rationale,
    required List<VolumeShortfall> shortfalls,
  }) = _Program;

  factory Program.fromJson(Map<String, dynamic> json) =>
      _$ProgramFromJson(json);
}

/* ---------------------------------------------------------------- write -- */

/// The server's bodies are `.strict()` and optional fields are absent, not
/// null. `toJson` keeps nulls; this drops them before sending.
Map<String, dynamic> withoutNulls(Map<String, dynamic> json) =>
    Map.fromEntries(json.entries.where((e) => e.value != null));

@freezed
abstract class GenerateProgramRequest with _$GenerateProgramRequest {
  const factory GenerateProgramRequest({
    int? daysPerWeek,
    int? preferredSessionMinutes,
  }) = _GenerateProgramRequest;

  factory GenerateProgramRequest.fromJson(Map<String, dynamic> json) =>
      _$GenerateProgramRequestFromJson(json);
}

@freezed
abstract class CustomExercise with _$CustomExercise {
  const factory CustomExercise({
    required String exerciseId,
    required int setCount,
    required int repMin,
    required int repMax,
    required int targetRir,
    double? incrementKg,
  }) = _CustomExercise;

  factory CustomExercise.fromJson(Map<String, dynamic> json) =>
      _$CustomExerciseFromJson(json);
}

@freezed
abstract class CustomDay with _$CustomDay {
  const factory CustomDay({
    required int dayOfWeek,
    required String sessionName,
    required List<CustomExercise> exercises,
  }) = _CustomDay;

  factory CustomDay.fromJson(Map<String, dynamic> json) =>
      _$CustomDayFromJson(json);
}

@freezed
abstract class PutProgramRequest with _$PutProgramRequest {
  const factory PutProgramRequest({
    required String name,
    required List<CustomDay> days,
  }) = _PutProgramRequest;

  factory PutProgramRequest.fromJson(Map<String, dynamic> json) =>
      _$PutProgramRequestFromJson(json);
}

@freezed
abstract class PatchProgramDayRequest with _$PatchProgramDayRequest {
  const factory PatchProgramDayRequest({
    String? sessionName,
    List<CustomExercise>? exercises,
  }) = _PatchProgramDayRequest;

  factory PatchProgramDayRequest.fromJson(Map<String, dynamic> json) =>
      _$PatchProgramDayRequestFromJson(json);
}
