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
  @JsonValue('bro-split')
  broSplit('bro-split', 'Bro split'),
  @JsonValue('upper-lower-6')
  upperLower6('upper-lower-6', 'Upper / lower'),
  @JsonValue('full-body-2')
  fullBody2('full-body-2', 'Full body'),
  @JsonValue('push-pull')
  pushPull('push-pull', 'Push / pull'),
  @JsonValue('two-muscle')
  twoMuscle('two-muscle', 'Two muscle groups per day'),
  @JsonValue('bodybuilding-5')
  bodybuilding5('bodybuilding-5', '5-day bodybuilding'),
  @JsonValue('full-body-3')
  fullBody3('full-body-3', '3-day full body'),
  @JsonValue('upper-lower-4')
  upperLower4('upper-lower-4', '4-day upper / lower'),
  @JsonValue('push-pull-legs-6')
  pushPullLegs6('push-pull-legs-6', '6-day push / pull / legs'),
  @JsonValue('custom')
  custom('custom', 'Custom');

  const SplitType(this.wire, this.label);
  final String wire;
  final String label;
}

enum ProgramSource {
  @JsonValue('generated')
  generated('generated', 'Generated for you'),
  @JsonValue('template')
  template('template', 'Professional structure'),
  @JsonValue('custom')
  custom('custom', 'Your own');

  const ProgramSource(this.wire, this.label);
  final String wire;
  final String label;
}

enum TemplateLevel {
  @JsonValue('beginner')
  beginner('beginner', 'Beginner'),
  @JsonValue('intermediate')
  intermediate('intermediate', 'Intermediate'),
  @JsonValue('advanced')
  advanced('advanced', 'Advanced'),
  @JsonValue('any')
  any('any', 'Any level');

  const TemplateLevel(this.wire, this.label);
  final String wire;
  final String label;
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

/// One set's TARGET (Phase 4 rework): a rep range, or a pinned number when
/// min == max; the starting weight the user typed, or null — never invented.
@freezed
abstract class PlannedSet with _$PlannedSet {
  const PlannedSet._();

  const factory PlannedSet({
    required int setIndex,
    required int repsMin,
    required int repsMax,
    required double? weightKg,
    required int rir,
  }) = _PlannedSet;

  factory PlannedSet.fromJson(Map<String, dynamic> json) =>
      _$PlannedSetFromJson(json);

  String get repsLabel => repsMin == repsMax ? '$repsMin' : '$repsMin–$repsMax';

  CustomSet toCustom() => CustomSet(
        repsMin: repsMin,
        repsMax: repsMax,
        weightKg: weightKg,
        rir: rir,
      );
}

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
    required List<PlannedSet> sets,
  }) = _PlannedExercise;

  factory PlannedExercise.fromJson(Map<String, dynamic> json) =>
      _$PlannedExerciseFromJson(json);

  /// "4 × 6–12" — the prescription as the engine wrote it.
  String get prescription =>
      '$setCount × ${repMin == repMax ? '$repMin' : '$repMin–$repMax'}';

  /// The weight on the first set that has one, or null when none is set yet.
  double? get startingWeightKg {
    for (final s in sets) {
      if (s.weightKg != null) return s.weightKg;
    }
    return null;
  }

  /// The same row as a request to send back, with every set, for edits.
  CustomExercise toCustom() => CustomExercise(
        exerciseId: exerciseId,
        setCount: sets.length,
        repMin: repMin,
        repMax: repMax,
        targetRir: targetRir,
        incrementKg: incrementKg,
        sets: sets.map((s) => s.toCustom()).toList(),
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
    required String? templateSlug,
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
abstract class CustomSet with _$CustomSet {
  const factory CustomSet({
    required int repsMin,
    required int repsMax,
    required double? weightKg,
    required int rir,
  }) = _CustomSet;

  factory CustomSet.fromJson(Map<String, dynamic> json) =>
      _$CustomSetFromJson(json);
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
    double? startingWeightKg,
    List<CustomSet>? sets,
  }) = _CustomExercise;

  factory CustomExercise.fromJson(Map<String, dynamic> json) =>
      _$CustomExerciseFromJson(json);
}

@freezed
abstract class CustomDay with _$CustomDay {
  const factory CustomDay({
    required int dayOfWeek,
    required String sessionName,
    List<MuscleGroup>? focus,
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
    List<MuscleGroup>? focus,
    List<CustomExercise>? exercises,
  }) = _PatchProgramDayRequest;

  factory PatchProgramDayRequest.fromJson(Map<String, dynamic> json) =>
      _$PatchProgramDayRequestFromJson(json);
}

/* ------------------------------------------------------------ templates -- */

@freezed
abstract class TemplateDay with _$TemplateDay {
  const factory TemplateDay({
    required int dayOfWeek,
    required String sessionName,
    required List<MuscleGroup> muscles,
  }) = _TemplateDay;

  factory TemplateDay.fromJson(Map<String, dynamic> json) =>
      _$TemplateDayFromJson(json);
}

/// A professional structure as listed: no exercises until previewed.
@freezed
abstract class ProgramTemplate with _$ProgramTemplate {
  const factory ProgramTemplate({
    required String slug,
    required String name,
    required int daysPerWeek,
    required TemplateLevel level,
    required int approxMinutes,
    required String summary,
    required List<TemplateDay> days,
  }) = _ProgramTemplate;

  factory ProgramTemplate.fromJson(Map<String, dynamic> json) =>
      _$ProgramTemplateFromJson(json);
}

/// A previewed exercise: like a planned one but not yet stored (no id).
@freezed
abstract class PreviewExercise with _$PreviewExercise {
  const factory PreviewExercise({
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
    required List<PlannedSet> sets,
  }) = _PreviewExercise;

  factory PreviewExercise.fromJson(Map<String, dynamic> json) =>
      _$PreviewExerciseFromJson(json);
}

@freezed
abstract class PreviewDay with _$PreviewDay {
  const factory PreviewDay({
    required int dayOfWeek,
    required String sessionName,
    required List<MuscleGroup> focus,
    required bool isRest,
    required int estimatedMinutes,
    required List<PreviewExercise> exercises,
  }) = _PreviewDay;

  factory PreviewDay.fromJson(Map<String, dynamic> json) =>
      _$PreviewDayFromJson(json);
}

@freezed
abstract class TemplatePreview with _$TemplatePreview {
  const factory TemplatePreview({
    required ProgramTemplate template,
    required List<PreviewDay> days,
    required Map<String, double> weeklyVolume,
    required List<String> rationale,
    required List<VolumeShortfall> shortfalls,
  }) = _TemplatePreview;

  factory TemplatePreview.fromJson(Map<String, dynamic> json) =>
      _$TemplatePreviewFromJson(json);
}
