import 'package:dio/dio.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../domain/mess.dart';

/// The Phase 9 mess endpoints. Envelope mapping only. The server serves its
/// own mirror of MessIT; this never talks to MessIT, and sends nothing but
/// the date and a mess code.
abstract class MessApi {
  Future<Result<MessesResponse>> messes({String provider = vitProvider});

  /// [mess] null = the user's configured mess (404 when there is none).
  Future<Result<MessMenu>> menu({required String date, String? mess});

  Future<Result<MessCorrection>> correct(
    String dishSlug,
    MessCorrectionRequest request,
  );

  static const vitProvider = 'vit-vellore';
}

class DioMessApi implements MessApi {
  DioMessApi(this._dio);

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
  Future<Result<MessesResponse>> messes({
    String provider = MessApi.vitProvider,
  }) =>
      _guard(
        () => _dio.get<Map<String, dynamic>>(
          '/v1/mess/providers/$provider/messes',
        ),
        MessesResponse.fromJson,
      );

  @override
  Future<Result<MessMenu>> menu({required String date, String? mess}) => _guard(
        () => _dio.get<Map<String, dynamic>>(
          '/v1/mess/menu',
          queryParameters: <String, String>{
            'date': date,
            if (mess != null) 'mess': mess,
          },
        ),
        MessMenu.fromJson,
      );

  @override
  Future<Result<MessCorrection>> correct(
    String dishSlug,
    MessCorrectionRequest request,
  ) =>
      _guard(
        () => _dio.post<Map<String, dynamic>>(
          '/v1/mess/dishes/$dishSlug/correction',
          data: request.toJson(),
        ),
        MessCorrection.fromJson,
      );
}
