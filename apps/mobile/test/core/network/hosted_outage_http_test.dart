import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/core/network/auth_interceptor.dart';
import 'package:fitos/core/network/dio_client.dart';
import 'package:fitos/features/workout/data/workout_api.dart';
import 'package:fitos/features/workout/domain/entities/workout.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 6.7 Gate 6.7-2, over real HTTP plumbing: the app's Dio client (auth
/// + retry interceptors) and DioWorkoutApi receive what Cloud Run's front end
/// sends during an outage — an HTML / plain-text 502, 503, 504 or 429 — and
/// hand the sync engine a ServiceUnavailable (an Offline), sent ONCE: the
/// retry interceptor still never re-sends a POST that reached a server.
class _Answer implements HttpClientAdapter {
  _Answer(this.status, this.body, this.contentType);

  final int status;
  final String body;
  final String contentType;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [contentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Tokens implements IdTokenProvider {
  @override
  Future<String?> idToken({bool forceRefresh = false}) async => 't';
  @override
  Future<void> onSessionInvalid() async {}
}

void main() {
  const base = 'https://fitos-api-alpha-123456789012.asia-south1.run.app';
  const host = 'fitos-api-alpha-123456789012.asia-south1.run.app';
  const start = StartSessionRequest(
    clientSessionId: '11111111-1111-4111-8111-111111111111',
    startedAt: '2026-09-23T10:00:00.000Z',
  );

  Future<(Failure, _Answer)> startAgainst(
    int status,
    String body, {
    String contentType = 'text/html; charset=UTF-8',
  }) async {
    final answer = _Answer(status, body, contentType);
    final dio = buildDio(_Tokens(), baseUrl: base)..httpClientAdapter = answer;
    final result = await DioWorkoutApi(dio).start(start);
    return ((result as Err<WorkoutSession>).failure, answer);
  }

  for (final (status, body) in <(int, String)>[
    (502, '<html><title>502 Bad Gateway</title></html>'),
    (503, '<html><title>503 Service Unavailable</title></html>'),
    (504, 'upstream request timeout'),
    (429, 'Rate exceeded.'),
  ]) {
    test('Cloud Run $status → ServiceUnavailable naming the host, sent once',
        () async {
      final (failure, answer) = await startAgainst(status, body);
      expect(failure, isA<ServiceUnavailable>());
      expect(failure, isA<Offline>());
      expect(failure.message, contains(host));
      expect(answer.requests, hasLength(1), reason: 'no blind POST re-send');
    });
  }

  test("FITOS's own 429 (JSON envelope) stays RateLimited", () async {
    final (failure, _) = await startAgainst(
      429,
      jsonEncode({
        'error': {
          'code': 'RATE_LIMITED',
          'message': 'Too many requests. Slow down and retry.',
          'requestId': 'r',
        },
      }),
      contentType: 'application/json; charset=utf-8',
    );
    expect(failure, isA<RateLimited>());
  });

  test(
      "FITOS's own 503 (database unreachable) → ServiceUnavailable, server's words",
      () async {
    final (failure, _) = await startAgainst(
      503,
      jsonEncode({
        'error': {
          'code': 'UPSTREAM_UNAVAILABLE',
          'message': 'FITOS is temporarily unavailable. Try again shortly.',
          'requestId': 'r',
        },
      }),
      contentType: 'application/json; charset=utf-8',
    );
    expect(failure, isA<ServiceUnavailable>());
    expect(
      failure.message,
      'FITOS is temporarily unavailable. Try again shortly.',
    );
  });

  test('a 500 stays Unknown (a real bug is still counted by the sync queue)',
      () async {
    final (failure, _) = await startAgainst(500, 'Internal Server Error');
    expect(failure, isA<Unknown>());
  });
}
