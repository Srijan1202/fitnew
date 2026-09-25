import 'package:dio/dio.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../domain/progress.dart';

/// The Phase 12 Progress endpoints. Envelope mapping only; the auth header is
/// the interceptor's. Writes are online-only (owner D9): there is no queue.
abstract class ProgressApi {
  Future<Result<ProgressSummary>> summary(ProgressWindow window);
  Future<Result<SavedReading>> logWeight(LogWeightRequest request);
  Future<Result<SavedReading>> logMeasurement(LogMeasurementRequest request);
}

class DioProgressApi implements ProgressApi {
  DioProgressApi(this._dio);

  final Dio _dio;

  @override
  Future<Result<ProgressSummary>> summary(ProgressWindow window) async {
    try {
      final data = (await _dio.get<Map<String, dynamic>>(
        '/v1/progress/summary',
        queryParameters: {'window': window.wire},
      ))
          .data;
      if (data == null) return const Err(Unknown());
      return Ok(ProgressSummary.fromJson(data));
    } on DioException catch (e) {
      return Err(ErrorMapper.fromDio(e));
    }
  }

  @override
  Future<Result<SavedReading>> logWeight(LogWeightRequest request) async {
    try {
      final r = await _dio.post<Map<String, dynamic>>(
        '/v1/progress/weight',
        data: request.toJson(),
      );
      final w = r.data?['weight'] as Map<String, dynamic>?;
      if (w == null) return const Err(Unknown());
      return Ok(
        SavedReading(
          date: w['date'] as String,
          value: (w['weightKg'] as num).toDouble(),
          created: r.statusCode == 201,
        ),
      );
    } on DioException catch (e) {
      return Err(ErrorMapper.fromDio(e));
    }
  }

  @override
  Future<Result<SavedReading>> logMeasurement(
    LogMeasurementRequest request,
  ) async {
    try {
      final r = await _dio.post<Map<String, dynamic>>(
        '/v1/progress/measurement',
        data: request.toJson(),
      );
      final m = r.data?['measurement'] as Map<String, dynamic>?;
      if (m == null) return const Err(Unknown());
      return Ok(
        SavedReading(
          date: m['date'] as String,
          value: (m['valueCm'] as num).toDouble(),
          site: MeasurementSite.fromWire(m['site'] as String),
          created: r.statusCode == 201,
        ),
      );
    } on DioException catch (e) {
      return Err(ErrorMapper.fromDio(e));
    }
  }
}
