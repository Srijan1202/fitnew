import 'package:dio/dio.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../domain/water.dart';

/// Beta 6.0 (F7, ADR-059): `/v1/water` — today's total and target, and the
/// PUT that replaces a day's total.
abstract class WaterApi {
  Future<Result<WaterDay>> today();
  Future<Result<WaterDay>> set(String date, int ml);
}

class DioWaterApi implements WaterApi {
  DioWaterApi(this._dio);

  final Dio _dio;

  @override
  Future<Result<WaterDay>> today() => _guard(() async {
        final r = await _dio.get<Map<String, dynamic>>('/water/today');
        return WaterDay.fromJson(r.data!);
      });

  @override
  Future<Result<WaterDay>> set(String date, int ml) => _guard(() async {
        final r = await _dio.put<Map<String, dynamic>>(
          '/water/days/$date',
          data: setJson(ml),
        );
        return WaterDay.fromJson(r.data!);
      });

  /// The wire encoder, public for the conformance test.
  static Map<String, dynamic> setJson(int ml) => {'ml': ml};

  Future<Result<T>> _guard<T>(Future<T> Function() call) async {
    try {
      return Ok(await call());
    } on DioException catch (e) {
      return Err(ErrorMapper.fromDio(e));
    } on Object {
      return const Err(Unknown());
    }
  }
}
