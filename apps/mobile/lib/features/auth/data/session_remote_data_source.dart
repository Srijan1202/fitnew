import 'package:dio/dio.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import 'dtos/session_dto.dart';

/// The two calls behind `/v1/auth/session`. Auth header is added by the
/// interceptor; this class never touches a token.
abstract class SessionRemoteDataSource {
  Future<Result<CreateSessionResponse>> createSession(
    CreateSessionRequest request,
  );

  /// Best-effort. Returns `Ok` even when offline so sign-out can always
  /// complete locally; the server's revocation is a defence in depth, not a
  /// precondition of signing out.
  Future<Result<void>> deleteSession();
}

class DioSessionRemoteDataSource implements SessionRemoteDataSource {
  DioSessionRemoteDataSource(this._dio);

  final Dio _dio;

  @override
  Future<Result<CreateSessionResponse>> createSession(
    CreateSessionRequest request,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/auth/session',
        data: request.toJson()..removeWhere((_, Object? v) => v == null),
      );
      final data = response.data;
      if (data == null) return const Err(Unknown());
      return Ok(CreateSessionResponse.fromJson(data));
    } on DioException catch (e) {
      return Err(ErrorMapper.fromDio(e));
    }
  }

  @override
  Future<Result<void>> deleteSession() async {
    try {
      await _dio.delete<void>('/v1/auth/session');
      return const Ok(null);
    } on DioException catch (e) {
      final failure = ErrorMapper.fromDio(e);
      // Offline or already-unauthenticated: the session is as good as gone.
      if (failure is Offline || failure is Unauthenticated) {
        return const Ok(null);
      }
      return Err(failure);
    }
  }
}
