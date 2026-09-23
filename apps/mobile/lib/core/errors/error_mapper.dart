import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'failure.dart';

/// Turns SDK exceptions into [Failure]s. One place, so copy is consistent and
/// no screen has to know what a `FirebaseAuthException` is.
abstract final class ErrorMapper {
  static Failure fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        // Name the server we could not reach. On the LAN alpha the address is
        // baked into the build, so "offline" alone sent a Gate 6 tester
        // hunting the network for two minutes when the PC's IP had simply
        // changed since the APK was built. The host is not a secret: it is
        // the phone's own Wi-Fi, and it is already on the Profile screen.
        return Offline(offlineMessage(_authorityOf(e)));
      case DioExceptionType.badResponse:
        return fromEnvelope(
          e.response?.statusCode ?? 0,
          e.response?.data,
          authority: _authorityOf(e),
        );
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const Unknown();
    }
  }

  /// `host:port` of the request that failed, or null when it cannot be read.
  static String? _authorityOf(DioException e) {
    try {
      final uri = e.requestOptions.uri;
      if (uri.host.isEmpty) return null;
      return uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
    } on Object {
      return null;
    }
  }

  /// The words for "the server did not answer": the same sentence everywhere,
  /// naming the address when we know it.
  static String offlineMessage(String? authority) => authority == null
      ? 'You appear to be offline.'
      : 'Could not reach FITOS at $authority. Check your Wi-Fi and that the server is running.';

  /// The words for "reached, but not answering" (Phase 6.7): a hosted front
  /// end's 502 / 503 / 504, or Cloud Run's own 429.
  static String unavailableMessage(String? authority) => authority == null
      ? 'FITOS is not answering right now. Try again in a moment.'
      : 'FITOS is not answering at $authority right now. Try again in a moment.';

  /// Reads the §10 envelope. Falls back to the status code if the body is not
  /// ours. Public so it can be unit-tested without constructing a DioException.
  /// [authority] (`host[:port]` of the request) names the server in the
  /// "not answering" message.
  static Failure fromEnvelope(int status, Object? body, {String? authority}) {
    String? code;
    String? message;
    String? field;
    String? issue;
    if (body is Map<String, dynamic>) {
      final error = body['error'];
      if (error is Map<String, dynamic>) {
        code = error['code'] as String?;
        message = error['message'] as String?;
        final details = error['details'];
        if (details is List && details.isNotEmpty) {
          final first = details.first;
          if (first is Map<String, dynamic>) {
            field = first['path'] as String?;
            issue = first['issue'] as String?;
          }
        }
      }
    }
    if (code == 'CONFLICT' || status == 409) {
      return Conflict(
        message ?? 'That changed while you were away.',
        path: field,
        issue: issue,
      );
    }
    if (code == 'UNAUTHENTICATED' || status == 401) {
      return Unauthenticated(message ?? 'Sign in to continue.');
    }
    if (code == 'VALIDATION_FAILED' || status == 422) {
      return Validation(message ?? 'Please check your details.', field: field);
    }
    // 429 from FITOS itself (its envelope says RATE_LIMITED): the API's own
    // limit, as before. A 429 WITHOUT our envelope came from Cloud Run (no
    // instance free to take the request): the service is busy, not the user.
    if (code == 'RATE_LIMITED' || (status == 429 && code == null)) {
      return code == 'RATE_LIMITED'
          ? RateLimited(
              message ?? 'Too many attempts. Wait a minute and try again.',
            )
          : ServiceUnavailable(unavailableMessage(authority));
    }
    if (code == 'NOT_FOUND' || status == 404) {
      return NotFound(message ?? 'That no longer exists.');
    }
    // 503 from FITOS (UPSTREAM_UNAVAILABLE): its message is written for the
    // user ("AI is not set up on this server", "FITOS AI took too long",
    // "FITOS is temporarily unavailable") — keep it. A 502 / 503 / 504 from
    // the hosted front end (no envelope): the service is not answering.
    // Either way temporary (Phase 6.7): the sync queue waits, never parks.
    if (code == 'UPSTREAM_UNAVAILABLE' ||
        status == 502 ||
        status == 503 ||
        status == 504) {
      return ServiceUnavailable(message ?? unavailableMessage(authority));
    }
    return const Unknown();
  }

  static Failure fromFirebaseAuth(FirebaseAuthException e) {
    // Never shame, never over-explain (§6, §21). "Incorrect" is the one place
    // precision helps the user act.
    final message = switch (e.code) {
      'invalid-email' => 'That email address does not look right.',
      'user-disabled' => 'This account has been disabled.',
      'user-not-found' => 'No account with that email.',
      'wrong-password' ||
      'invalid-credential' =>
        'Email or password is incorrect.',
      'email-already-in-use' => 'An account with that email already exists.',
      'weak-password' => 'Choose a longer password, at least 8 characters.',
      'too-many-requests' => 'Too many attempts. Wait a minute and try again.',
      'network-request-failed' => 'You appear to be offline.',
      _ => 'Could not sign in. Please try again.',
    };
    if (e.code == 'network-request-failed') return Offline(message);
    if (e.code == 'too-many-requests') return RateLimited(message);
    return Credential(message, code: e.code);
  }
}
