import 'package:dio/dio.dart';

import '../config/env.dart';
import 'auth_interceptor.dart';
import 'retry_interceptor.dart';

/// The one HTTP client. Base URL from [Env], JSON in and out, auth and retry
/// interceptors wired in the order that matters: retry sits *inside* auth so
/// a transient failure is retried with the same token, and a 401 is handled
/// after retries are exhausted rather than refreshing on every attempt.
Dio buildDio(IdTokenProvider tokens, {String? baseUrl}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl ?? Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      headers: const {'Accept': 'application/json'},
      contentType: 'application/json',
      responseType: ResponseType.json,
    ),
  );
  dio.interceptors
    ..add(RetryInterceptor(dio))
    ..add(AuthInterceptor(tokens, dio));
  return dio;
}
