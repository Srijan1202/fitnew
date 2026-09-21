import 'package:dio/dio.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../training/domain/entities/program.dart' show withoutNulls;
import '../domain/entities/workout.dart';

/// `/v1/training/sessions*` and `/v1/training/today` — the remote half of
/// workout logging. Nothing here is called on the tap path: the local
/// store writes first and the sync drainer calls these later (§33).
abstract class WorkoutApi {
  Future<Result<TodayResponse>> today({int? dayOfWeek});
  Future<Result<WorkoutSession>> start(StartSessionRequest request);
  Future<Result<WorkoutSession>> get(String id);
  Future<Result<WorkoutSession>> logSets(String id, LogSetsRequest request);
  Future<Result<WorkoutSession>> patchSet(
    String id,
    String setId,
    PatchSetRequest request,
  );
  Future<Result<WorkoutSession>> deleteSet(String id, String setId);
  Future<Result<WorkoutSession>> addExercise(
    String id,
    AddSessionExerciseRequest request,
  );
  Future<Result<WorkoutSession>> patchExercise(
    String id,
    String exerciseId,
    PatchSessionExerciseRequest request,
  );
  Future<Result<WorkoutSession>> complete(
    String id,
    CompleteSessionRequest request,
  );
  Future<Result<WorkoutSession>> abandon(String id);
  Future<Result<SessionListResponse>> list({
    String? before,
    int limit = 20,
    SessionStatus? status,
  });

  // Phase 6.
  Future<Result<VolumeResponse>> volume();
  Future<Result<ProgressionDetail>> progression(String exerciseId);
  Future<Result<DeloadState>> acceptDeload();
  Future<Result<DeloadState>> declineDeload();
}

class DioWorkoutApi implements WorkoutApi {
  DioWorkoutApi(this._dio);

  final Dio _dio;

  Future<Result<T>> _guard<T>(
    Future<Response<Map<String, dynamic>>> Function() call,
    T Function(Map<String, dynamic>) parse,
  ) async {
    try {
      final data = (await call()).data;
      if (data == null) return const Err(Unknown());
      return Ok(parse(data));
    } on DioException catch (e) {
      return Err(ErrorMapper.fromDio(e));
    }
  }

  /// Wire encoders are public so the contract-conformance test can check
  /// exactly what goes over the wire.
  static Map<String, dynamic> setJson(LogSetInput s) => withoutNulls({
        'clientSetId': s.clientSetId,
        'clientExerciseId': s.clientExerciseId,
        'setIndex': s.setIndex,
        'setType': s.setType.wire,
        'weightKg': s.weightKg,
        'reps': s.reps,
        'rir': s.rir,
        'loggedAt': s.loggedAt,
        'plannedSetId': s.plannedSetId,
      });

  /// A patch sends explicit nulls only where the user cleared a value.
  static Map<String, dynamic> patchSetJson(PatchSetRequest p) => {
        if (p.setType != null) 'setType': p.setType!.wire,
        if (p.weightKg != null || p.weightCleared) 'weightKg': p.weightKg,
        if (p.reps != null) 'reps': p.reps,
        if (p.rir != null || p.rirCleared) 'rir': p.rir,
      };

  static Map<String, dynamic> patchExerciseJson(
    PatchSessionExerciseRequest p,
  ) =>
      {
        if (p.orderIndex != null) 'orderIndex': p.orderIndex,
        if (p.supersetGroup != null || p.supersetCleared)
          'supersetGroup': p.supersetGroup,
        if (p.exerciseId != null) 'exerciseId': p.exerciseId,
        if (p.removed) 'removed': true,
      };

  @override
  Future<Result<TodayResponse>> today({int? dayOfWeek}) => _guard(
        () => _dio.get<Map<String, dynamic>>(
          '/v1/training/today',
          queryParameters: {if (dayOfWeek != null) 'dayOfWeek': dayOfWeek},
        ),
        TodayResponse.fromJson,
      );

  static Map<String, dynamic> startJson(StartSessionRequest request) =>
      withoutNulls({
        'clientSessionId': request.clientSessionId,
        'programDayId': request.programDayId,
        'startedAt': request.startedAt,
        if (request.exercises != null)
          'exercises': [
            for (final x in request.exercises!) withoutNulls(x.toJson()),
          ],
      });

  @override
  Future<Result<WorkoutSession>> start(StartSessionRequest request) => _guard(
        () => _dio.post<Map<String, dynamic>>(
          '/v1/training/sessions',
          data: startJson(request),
        ),
        WorkoutSession.fromJson,
      );

  @override
  Future<Result<WorkoutSession>> get(String id) => _guard(
        () => _dio.get<Map<String, dynamic>>('/v1/training/sessions/$id'),
        WorkoutSession.fromJson,
      );

  @override
  Future<Result<WorkoutSession>> logSets(String id, LogSetsRequest request) =>
      _guard(
        () => _dio.post<Map<String, dynamic>>(
          '/v1/training/sessions/$id/sets',
          data: {
            'sets': request.sets.map(setJson).toList(),
            'merge': request.merge,
          },
        ),
        WorkoutSession.fromJson,
      );

  @override
  Future<Result<WorkoutSession>> patchSet(
    String id,
    String setId,
    PatchSetRequest request,
  ) =>
      _guard(
        () => _dio.patch<Map<String, dynamic>>(
          '/v1/training/sessions/$id/sets/$setId',
          data: patchSetJson(request),
        ),
        WorkoutSession.fromJson,
      );

  @override
  Future<Result<WorkoutSession>> deleteSet(String id, String setId) => _guard(
        () => _dio.delete<Map<String, dynamic>>(
          '/v1/training/sessions/$id/sets/$setId',
        ),
        WorkoutSession.fromJson,
      );

  @override
  Future<Result<WorkoutSession>> addExercise(
    String id,
    AddSessionExerciseRequest request,
  ) =>
      _guard(
        () => _dio.post<Map<String, dynamic>>(
          '/v1/training/sessions/$id/exercises',
          data: withoutNulls(request.toJson()),
        ),
        WorkoutSession.fromJson,
      );

  @override
  Future<Result<WorkoutSession>> patchExercise(
    String id,
    String exerciseId,
    PatchSessionExerciseRequest request,
  ) =>
      _guard(
        () => _dio.patch<Map<String, dynamic>>(
          '/v1/training/sessions/$id/exercises/$exerciseId',
          data: patchExerciseJson(request),
        ),
        WorkoutSession.fromJson,
      );

  @override
  Future<Result<WorkoutSession>> complete(
    String id,
    CompleteSessionRequest request,
  ) =>
      _guard(
        () => _dio.post<Map<String, dynamic>>(
          '/v1/training/sessions/$id/complete',
          data: withoutNulls(request.toJson()),
        ),
        WorkoutSession.fromJson,
      );

  @override
  Future<Result<WorkoutSession>> abandon(String id) => _guard(
        () => _dio.post<Map<String, dynamic>>(
          '/v1/training/sessions/$id/abandon',
          data: const <String, dynamic>{},
        ),
        WorkoutSession.fromJson,
      );

  @override
  Future<Result<SessionListResponse>> list({
    String? before,
    int limit = 20,
    SessionStatus? status,
  }) =>
      _guard(
        () => _dio.get<Map<String, dynamic>>(
          '/v1/training/sessions',
          queryParameters: {
            if (before != null) 'before': before,
            'limit': limit,
            if (status != null) 'status': status.wire,
          },
        ),
        SessionListResponse.fromJson,
      );

  /* --------------------------------------------------------- Phase 6 -- */

  @override
  Future<Result<VolumeResponse>> volume() => _guard(
        () => _dio.get<Map<String, dynamic>>('/v1/training/volume'),
        VolumeResponse.fromJson,
      );

  @override
  Future<Result<ProgressionDetail>> progression(String exerciseId) => _guard(
        () => _dio.get<Map<String, dynamic>>(
          '/v1/training/progression/$exerciseId',
        ),
        ProgressionDetail.fromJson,
      );

  @override
  Future<Result<DeloadState>> acceptDeload() => _guard(
        () => _dio.post<Map<String, dynamic>>(
          '/v1/training/deload/accept',
          data: const <String, dynamic>{},
        ),
        DeloadState.fromJson,
      );

  @override
  Future<Result<DeloadState>> declineDeload() => _guard(
        () => _dio.post<Map<String, dynamic>>(
          '/v1/training/deload/decline',
          data: const <String, dynamic>{},
        ),
        DeloadState.fromJson,
      );
}
