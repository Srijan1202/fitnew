import 'package:dio/dio.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../domain/premium.dart';

/// `GET /v1/premium`, `POST /v1/premium/request`, `PUT /v1/user/avatar`
/// (Phase 19, ADR-027).
abstract class PremiumApi {
  Future<Result<PremiumStatus>> status();
  Future<Result<PremiumRequestInfo>> request({String? message});
  Future<Result<String?>> setAvatar(String? avatarId);
}

class DioPremiumApi implements PremiumApi {
  DioPremiumApi(this._dio);

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

  /// Wire encoders, public for the conformance test.
  static Map<String, dynamic> requestJson({String? message}) =>
      {if (message != null && message.trim().isNotEmpty) 'message': message};

  static Map<String, dynamic> avatarJson(String? avatarId) =>
      {'avatarId': avatarId};

  @override
  Future<Result<PremiumStatus>> status() => _guard(() async {
        final r = await _dio.get<Map<String, dynamic>>('/v1/premium');
        return PremiumStatus.fromJson(r.data!);
      });

  @override
  Future<Result<PremiumRequestInfo>> request({String? message}) =>
      _guard(() async {
        final r = await _dio.post<Map<String, dynamic>>(
          '/v1/premium/request',
          data: requestJson(message: message),
        );
        return PremiumRequestInfo.fromJson(r.data!);
      });

  @override
  Future<Result<String?>> setAvatar(String? avatarId) => _guard(() async {
        final r = await _dio.put<Map<String, dynamic>>(
          '/v1/user/avatar',
          data: avatarJson(avatarId),
        );
        return r.data!['avatarId'] as String?;
      });
}
