import 'package:dio/dio.dart';
import 'package:fitos/core/network/auth_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

/// Scripted token source.
class FakeTokens implements IdTokenProvider {
  FakeTokens({this.current = 'tok-1', this.refreshed = 'tok-2'});
  String? current;
  String? refreshed;
  int refreshes = 0;
  int invalidations = 0;

  @override
  Future<String?> idToken({bool forceRefresh = false}) async {
    if (forceRefresh) {
      refreshes += 1;
      return refreshed;
    }
    return current;
  }

  @override
  Future<void> onSessionInvalid() async => invalidations += 1;
}

/// An adapter that answers from a script and records every request it sees,
/// including the Authorization header each one carried.
class ScriptedAdapter implements HttpClientAdapter {
  ScriptedAdapter(this.statuses);
  final List<int> statuses;
  final List<String?> authHeaders = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    authHeaders.add(options.headers['Authorization'] as String?);
    final status = statuses.length > 1 ? statuses.removeAt(0) : statuses.first;
    return ResponseBody.fromString(
      '{"ok":$status}',
      status,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  Dio build(FakeTokens tokens, ScriptedAdapter adapter) {
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(AuthInterceptor(tokens, dio));
    return dio;
  }

  test('attaches the current token as a Bearer header', () async {
    final tokens = FakeTokens();
    final adapter = ScriptedAdapter([200]);
    await build(tokens, adapter).get<void>('/x');
    expect(adapter.authHeaders, ['Bearer tok-1']);
    expect(tokens.refreshes, 0);
  });

  test('sends no header when signed out', () async {
    final tokens = FakeTokens(current: null);
    final adapter = ScriptedAdapter([200]);
    await build(tokens, adapter).get<void>('/x');
    expect(adapter.authHeaders, [null]);
  });

  test('on 401: refreshes, retries once with the new token, succeeds',
      () async {
    final tokens = FakeTokens();
    final adapter = ScriptedAdapter([401, 200]);
    final response = await build(tokens, adapter).get<void>('/x');
    expect(response.statusCode, 200);
    expect(adapter.authHeaders, ['Bearer tok-1', 'Bearer tok-2']);
    expect(tokens.refreshes, 1);
    expect(tokens.invalidations, 0);
  });

  test('on a second 401 after refresh: gives up and invalidates the session',
      () async {
    final tokens = FakeTokens();
    final adapter = ScriptedAdapter([401, 401]);
    await expectLater(
      build(tokens, adapter).get<void>('/x'),
      throwsA(isA<DioException>()),
    );
    // Exactly two attempts: never a loop.
    expect(adapter.authHeaders.length, 2);
    expect(tokens.refreshes, 1);
    expect(tokens.invalidations, 1);
  });

  test('on 401 when refresh yields nothing: invalidates without retrying',
      () async {
    final tokens = FakeTokens(refreshed: null);
    final adapter = ScriptedAdapter([401]);
    await expectLater(
      build(tokens, adapter).get<void>('/x'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.authHeaders.length, 1);
    expect(tokens.invalidations, 1);
  });

  test('non-401 errors pass straight through untouched', () async {
    final tokens = FakeTokens();
    final adapter = ScriptedAdapter([500]);
    await expectLater(
      build(tokens, adapter).get<void>('/x'),
      throwsA(isA<DioException>()),
    );
    expect(tokens.refreshes, 0);
    expect(tokens.invalidations, 0);
  });
}
