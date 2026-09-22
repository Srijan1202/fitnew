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
    ..add(const NoBodyNoContentType())
    ..add(RetryInterceptor(dio))
    ..add(AuthInterceptor(tokens, dio));
  return dio;
}

/// A request without a body declares no `Content-Type`.
///
/// [BaseOptions.contentType] stamps `application/json` on every request, and
/// Dio leaves it on body-less ones. Fastify rejects a JSON content type with
/// an empty body ("Body cannot be empty when content-type is set to
/// 'application/json'", 422 here), so every DELETE — removing a logged set,
/// signing out — failed on the server. A removed set therefore stayed there,
/// the set re-logged in its place hit the one-live-set-per-position rule
/// (409), and the session's sync queue parked: the S24's "1 not synced".
class NoBodyNoContentType extends Interceptor {
  const NoBodyNoContentType();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.data == null) options.contentType = null;
    handler.next(options);
  }
}
