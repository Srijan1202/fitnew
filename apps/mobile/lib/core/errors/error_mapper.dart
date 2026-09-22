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
        return const Offline();
      case DioExceptionType.badResponse:
        return fromEnvelope(e.response?.statusCode ?? 0, e.response?.data);
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const Unknown();
    }
  }

  /// Reads the §10 envelope. Falls back to the status code if the body is not
  /// ours. Public so it can be unit-tested without constructing a DioException.
  static Failure fromEnvelope(int status, Object? body) {
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
    if (code == 'RATE_LIMITED' || status == 429) {
      return RateLimited(
        message ?? 'Too many attempts. Wait a minute and try again.',
      );
    }
    // 503: the server's message is written for the user ("AI is not set up
    // on this server", "FITOS AI took too long") — keep it.
    if (code == 'UPSTREAM_UNAVAILABLE' || status == 503) {
      return Unknown(message ?? 'Something is unavailable right now.');
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
