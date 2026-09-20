import 'package:dio/dio.dart';

/// Supplies a Firebase ID token. Abstract so the interceptor is testable
/// without Firebase: production wraps `FirebaseAuth.currentUser.getIdToken`.
abstract class IdTokenProvider {
  /// A currently valid token, or null when signed out. `forceRefresh` asks
  /// Firebase for a fresh one even if the cached one has not expired.
  Future<String?> idToken({bool forceRefresh = false});

  /// Called when a refreshed token is still rejected. The session is dead.
  Future<void> onSessionInvalid();
}

/// Attaches `Authorization: Bearer <id token>` to every request and, on 401,
/// refreshes the token and retries exactly once (§11).
///
/// Exactly once, on purpose: a second 401 after a forced refresh means the
/// token is not merely stale but rejected — revoked by sign-out on another
/// device, or the account is disabled — and the right response is to drop
/// the session, not to loop.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokens, this._dio);

  final IdTokenProvider _tokens;
  final Dio _dio;

  static const _retriedFlag = 'fitos.retried';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // A retry re-enters this hook via `_dio.fetch`. Its header was set to the
    // freshly refreshed token by `onError`; overwriting it with the cached
    // (stale) one here would make the refresh pointless. Found by the test
    // that asserts the second attempt carries the new token.
    if (options.extra[_retriedFlag] == true) {
      return handler.next(options);
    }
    final token = await _tokens.idToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final is401 = err.response?.statusCode == 401;
    if (!is401) return handler.next(err);

    // This is the retry itself coming back 401: the refreshed token was
    // rejected. Invalidate here, exactly once, and let the error propagate.
    if (err.requestOptions.extra[_retriedFlag] == true) {
      await _tokens.onSessionInvalid();
      return handler.next(err);
    }

    final fresh = await _tokens.idToken(forceRefresh: true);
    if (fresh == null) {
      await _tokens.onSessionInvalid();
      return handler.next(err);
    }

    final retry = err.requestOptions
      ..headers['Authorization'] = 'Bearer $fresh'
      ..extra[_retriedFlag] = true;

    try {
      handler.resolve(await _dio.fetch<dynamic>(retry));
    } on DioException catch (retryError) {
      // The nested onError above has already handled invalidation for a 401.
      handler.next(retryError);
    }
  }
}
