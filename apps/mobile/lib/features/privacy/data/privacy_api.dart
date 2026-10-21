import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../profile/domain/entities/vocabulary.dart';
import '../domain/privacy.dart';

/// `/v1/user/consents`, `/v1/user/export`, `DELETE /v1/user` (Phase 17).
abstract class PrivacyApi {
  Future<Result<Consents>> consents();
  Future<Result<Consents>> setConsent(
    ConsentType type, {
    required bool granted,
  });

  /// The export as the server sent it (JSON text), to save as a file.
  Future<Result<String>> exportJson();

  /// Everything, now. Ok(true) when the sign-in account went too.
  Future<Result<bool>> deleteAccount();
}

class DioPrivacyApi implements PrivacyApi {
  DioPrivacyApi(this._dio);

  final Dio _dio;

  Future<Result<T>> _guard<T>(Future<T> Function() call) async {
    try {
      return Ok(await call());
    } on DioException catch (e) {
      return Err(ErrorMapper.fromDio(e));
    } on Object {
      return const Err(Unknown());
    }
  }

  @override
  Future<Result<Consents>> consents() => _guard(() async {
        final r = await _dio.get<Map<String, dynamic>>('/v1/user/consents');
        return Consents.fromJson(r.data!);
      });

  /// Wire encoder, public for the conformance test.
  static Map<String, dynamic> consentJson(
    ConsentType type, {
    required bool granted,
  }) =>
      {'type': type.wire, 'granted': granted};

  @override
  Future<Result<Consents>> setConsent(
    ConsentType type, {
    required bool granted,
  }) =>
      _guard(() async {
        final r = await _dio.post<Map<String, dynamic>>(
          '/v1/user/consents',
          data: consentJson(type, granted: granted),
        );
        return Consents.fromJson(r.data!);
      });

  @override
  Future<Result<String>> exportJson() => _guard(() async {
        final r = await _dio.post<Object>(
          '/v1/user/export',
          options: Options(
            responseType: ResponseType.plain,
            receiveTimeout: const Duration(seconds: 60),
          ),
        );
        final body = r.data;
        return body is String ? body : jsonEncode(body);
      });

  @override
  Future<Result<bool>> deleteAccount() => _guard(() async {
        final r = await _dio.delete<Map<String, dynamic>>(
          '/v1/user',
          data: {'confirm': 'DELETE'},
        );
        return r.data?['signInRemoved'] as bool? ?? false;
      });
}
