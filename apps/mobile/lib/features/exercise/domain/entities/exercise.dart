import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../profile/domain/entities/vocabulary.dart';

part 'exercise.freezed.dart';
part 'exercise.g.dart';

/// Wire shapes and closed vocabularies of `@fitos/contracts` exercise.ts.
/// The library is the backend's (§30: exercise substitution is not the
/// client's); this renders it and filters only by asking the server.

/// Exactly the rows of the §12.3 volume-landmark table.
enum MuscleGroup {
  @JsonValue('chest')
  chest('chest', 'Chest'),
  @JsonValue('back')
  back('back', 'Back'),
  @JsonValue('quads')
  quads('quads', 'Quads'),
  @JsonValue('hamstrings')
  hamstrings('hamstrings', 'Hamstrings'),
  @JsonValue('glutes')
  glutes('glutes', 'Glutes'),
  @JsonValue('shoulders')
  shoulders('shoulders', 'Shoulders'),
  @JsonValue('biceps')
  biceps('biceps', 'Biceps'),
  @JsonValue('triceps')
  triceps('triceps', 'Triceps'),
  @JsonValue('calves')
  calves('calves', 'Calves'),
  @JsonValue('abs')
  abs('abs', 'Abs');

  const MuscleGroup(this.wire, this.label);
  final String wire;
  final String label;
}

enum MovementPattern {
  @JsonValue('squat')
  squat('squat', 'Squat'),
  @JsonValue('hinge')
  hinge('hinge', 'Hinge'),
  @JsonValue('lunge')
  lunge('lunge', 'Lunge'),
  @JsonValue('horizontal-push')
  horizontalPush('horizontal-push', 'Horizontal push'),
  @JsonValue('vertical-push')
  verticalPush('vertical-push', 'Vertical push'),
  @JsonValue('horizontal-pull')
  horizontalPull('horizontal-pull', 'Horizontal pull'),
  @JsonValue('vertical-pull')
  verticalPull('vertical-pull', 'Vertical pull'),
  @JsonValue('elbow-flexion')
  elbowFlexion('elbow-flexion', 'Curl'),
  @JsonValue('elbow-extension')
  elbowExtension('elbow-extension', 'Triceps'),
  @JsonValue('shoulder-isolation')
  shoulderIsolation('shoulder-isolation', 'Shoulder isolation'),
  @JsonValue('chest-isolation')
  chestIsolation('chest-isolation', 'Chest isolation'),
  @JsonValue('leg-isolation')
  legIsolation('leg-isolation', 'Leg isolation'),
  @JsonValue('calf-raise')
  calfRaise('calf-raise', 'Calf raise'),
  @JsonValue('core')
  core('core', 'Core'),
  @JsonValue('carry')
  carry('carry', 'Carry');

  const MovementPattern(this.wire, this.label);
  final String wire;
  final String label;
}

enum Difficulty {
  @JsonValue('beginner')
  beginner('beginner', 'Beginner'),
  @JsonValue('intermediate')
  intermediate('intermediate', 'Intermediate'),
  @JsonValue('advanced')
  advanced('advanced', 'Advanced');

  const Difficulty(this.wire, this.label);
  final String wire;
  final String label;
}

enum MuscleRole {
  @JsonValue('primary')
  primary('primary'),
  @JsonValue('secondary')
  secondary('secondary');

  const MuscleRole(this.wire);
  final String wire;
}

enum AlternativeReason {
  @JsonValue('equipment')
  equipment('equipment', 'Different equipment'),
  @JsonValue('injury')
  injury('injury', 'Easier on the joints'),
  @JsonValue('preference')
  preference('preference', 'Same idea, different feel');

  const AlternativeReason(this.wire, this.label);
  final String wire;
  final String label;
}

@freezed
abstract class ExerciseSummary with _$ExerciseSummary {
  const factory ExerciseSummary({
    required String id,
    required String slug,
    required String name,
    required MovementPattern movementPattern,
    required List<Equipment> equipment,
    required Difficulty difficulty,
    required bool isUnilateral,
    required List<MuscleGroup> primaryMuscles,
  }) = _ExerciseSummary;

  factory ExerciseSummary.fromJson(Map<String, dynamic> json) =>
      _$ExerciseSummaryFromJson(json);
}

@freezed
abstract class ExerciseMuscle with _$ExerciseMuscle {
  const factory ExerciseMuscle({
    required MuscleGroup muscleGroup,
    required MuscleRole role,
    required double contribution,
  }) = _ExerciseMuscle;

  factory ExerciseMuscle.fromJson(Map<String, dynamic> json) =>
      _$ExerciseMuscleFromJson(json);
}

@freezed
abstract class ExerciseAlternative with _$ExerciseAlternative {
  const factory ExerciseAlternative({
    required String id,
    required String slug,
    required String name,
    required AlternativeReason reason,
    required List<Equipment> equipment,
  }) = _ExerciseAlternative;

  factory ExerciseAlternative.fromJson(Map<String, dynamic> json) =>
      _$ExerciseAlternativeFromJson(json);
}

@freezed
abstract class ExerciseDetail with _$ExerciseDetail {
  const factory ExerciseDetail({
    required String id,
    required String slug,
    required String name,
    required MovementPattern movementPattern,
    required List<Equipment> equipment,
    required Difficulty difficulty,
    required bool isUnilateral,
    required List<MuscleGroup> primaryMuscles,
    required double defaultIncrementKg,
    required List<String> instructions,
    required String? videoUrl,
    required List<ExerciseMuscle> muscles,
    required List<ExerciseAlternative> alternatives,
    required List<BodyPart> contraindications,
  }) = _ExerciseDetail;

  factory ExerciseDetail.fromJson(Map<String, dynamic> json) =>
      _$ExerciseDetailFromJson(json);
}

@freezed
abstract class ExerciseListResponse with _$ExerciseListResponse {
  const factory ExerciseListResponse({
    required List<ExerciseSummary> items,
    required int total,
    required int limit,
    required int offset,
  }) = _ExerciseListResponse;

  factory ExerciseListResponse.fromJson(Map<String, dynamic> json) =>
      _$ExerciseListResponseFromJson(json);
}

/// The `GET /exercises` query. `equipment` is what the user HAS; the server
/// answers with what they can perform.
@freezed
abstract class ExerciseQuery with _$ExerciseQuery {
  const ExerciseQuery._();

  const factory ExerciseQuery({
    @Default('') String q,
    @Default(<Equipment>{}) Set<Equipment> equipment,
    MuscleGroup? muscle,
    MovementPattern? pattern,
    @Default(200) int limit,
    @Default(0) int offset,
  }) = _ExerciseQuery;

  bool get hasFilters =>
      q.trim().isNotEmpty ||
      equipment.isNotEmpty ||
      muscle != null ||
      pattern != null;

  /// Query-string parameters exactly as the contract's `exerciseListQuerySchema`
  /// reads them (comma-separated equipment, omitted when empty).
  Map<String, String> toQueryParameters() => <String, String>{
        if (q.trim().isNotEmpty) 'q': q.trim(),
        if (equipment.isNotEmpty)
          'equipment':
              (equipment.map((e) => e.wire).toList()..sort()).join(','),
        if (muscle != null) 'muscle': muscle!.wire,
        if (pattern != null) 'pattern': pattern!.wire,
        'limit': '$limit',
        'offset': '$offset',
      };
}
