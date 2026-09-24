import 'package:dio/dio.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../domain/today.dart';

/// The Phase 11 TODAY endpoints. Envelope mapping only; the auth header is
/// the interceptor's.
abstract class TodayApi {
  /// `GET /v1/today`: the server's ranked actions for the user's local day.
  Future<Result<TodayPlan>> today();

  /// `POST /v1/today/actions/{id}/event`. Ok for 201 (stored) and 200 (a
  /// replay of the same client id, or an event already on record).
  Future<Result<TodayEventRecord>> event(
    String recommendationId,
    TodayEventRequest request,
  );
}

class DioTodayApi implements TodayApi {
  DioTodayApi(this._dio);

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

  @override
  Future<Result<TodayPlan>> today() => _guard(
        () => _dio.get<Map<String, dynamic>>('/v1/today'),
        TodayPlan.fromJson,
      );

  @override
  Future<Result<TodayEventRecord>> event(
    String recommendationId,
    TodayEventRequest request,
  ) =>
      _guard(
        () => _dio.post<Map<String, dynamic>>(
          '/v1/today/actions/$recommendationId/event',
          data: request.toJson(),
        ),
        TodayEventRecord.fromJson,
      );
}
