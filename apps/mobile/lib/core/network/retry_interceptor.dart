import 'dart:async';

import 'package:dio/dio.dart';

/// Retries transient network failures with exponential backoff.
///
/// Only *idempotent-safe* failures are retried: connection errors and
/// timeouts where the request may never have reached the server. A 5xx is
/// not retried here — the request arrived, and re-sending a non-idempotent
/// POST could duplicate a log entry. Offline write replay is the sync queue's
/// job (§33), not this interceptor's.
class RetryInterceptor extends Interceptor {
  RetryInterceptor(
    this._dio, {
    this.maxAttempts = 3,
    this.baseDelay = const Duration(milliseconds: 300),
  });

  final Dio _dio;
  final int maxAttempts;
  final Duration baseDelay;

  static const _attemptKey = 'fitos.attempt';

  static bool _isTransient(DioException e) => switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.connectionError =>
          true,
        _ => false,
      };

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final attempt = (err.requestOptions.extra[_attemptKey] as int?) ?? 1;
    if (!_isTransient(err) || attempt >= maxAttempts) {
      return handler.next(err);
    }

    await Future<void>.delayed(baseDelay * (1 << (attempt - 1)));
    final next = err.requestOptions..extra[_attemptKey] = attempt + 1;
    try {
      handler.resolve(await _dio.fetch<dynamic>(next));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
