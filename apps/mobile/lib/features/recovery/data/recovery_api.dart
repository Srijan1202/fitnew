import 'package:dio/dio.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../domain/recovery.dart';

/// The Phase 13 Recovery endpoints. Envelope mapping only; the auth header
/// is the interceptor's. The check-in is online only (ADR-019 D11): no queue.
abstract class RecoveryApi {
  Future<Result<RecoveryToday>> today();
  Future<Result<SavedCheckIn>> log(LogRecoveryRequest request);
}

class DioRecoveryApi implements RecoveryApi {
  DioRecoveryApi(this._dio);

  final Dio _dio;

  @override
  Future<Result<RecoveryToday>> today() async {
    try {
      final data =
          (await _dio.get<Map<String, dynamic>>('/v1/recovery/today')).data;
      if (data == null) return const Err(Unknown());
      return Ok(RecoveryToday.fromJson(data));
    } on DioException catch (e) {
      return Err(ErrorMapper.fromDio(e));
    }
  }

  @override
  Future<Result<SavedCheckIn>> log(LogRecoveryRequest request) async {
    try {
      final r = await _dio.post<Map<String, dynamic>>(
        '/v1/recovery/log',
        data: request.toJson(),
      );
      final l = r.data?['log'] as Map<String, dynamic>?;
      if (l == null) return const Err(Unknown());
      return Ok(
        SavedCheckIn(
          log: RecoveryLog.fromJson(l),
          created: r.statusCode == 201,
        ),
      );
    } on DioException catch (e) {
      return Err(ErrorMapper.fromDio(e));
    }
  }
}
