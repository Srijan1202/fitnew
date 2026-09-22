import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fitos/core/network/auth_interceptor.dart';
import 'package:fitos/core/network/dio_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 6.6 Gate 7: every DELETE from the S24 failed on the server with
/// "Body cannot be empty when content-type is set to 'application/json'"
/// (422), because the client declared a JSON body it never sent. Removed
/// sets stayed on the server; sign-out's revocation never happened.
class _Capture implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
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
  late _Capture adapter;
  late Dio dio;

  setUp(() {
    adapter = _Capture();
    dio = buildDio(_Tokens(), baseUrl: 'http://10.1.2.3:8080')
      ..httpClientAdapter = adapter;
  });

  String? contentType(RequestOptions o) =>
      o.headers[Headers.contentTypeHeader] as String?;

  test('a DELETE without a body declares no content type', () async {
    await dio.delete<Map<String, dynamic>>('/v1/training/sessions/a/sets/b');
    await dio.delete<void>('/v1/auth/session');
    expect(adapter.requests.map(contentType), [null, null]);
  });

  test('a GET declares no content type either', () async {
    await dio.get<Map<String, dynamic>>('/v1/training/today');
    expect(contentType(adapter.requests.single), isNull);
  });

  test('a request with a JSON body still says so', () async {
    await dio.post<Map<String, dynamic>>(
      '/v1/training/sessions/a/sets',
      data: {'sets': <Object>[]},
    );
    await dio.patch<Map<String, dynamic>>('/v1/user/profile', data: {'x': 1});
    expect(
      adapter.requests.map(contentType),
      everyElement(startsWith('application/json')),
    );
  });

  test('the auth header is still attached to a body-less DELETE', () async {
    await dio.delete<void>('/v1/auth/session');
    expect(adapter.requests.single.headers['Authorization'], 'Bearer t');
  });
}
