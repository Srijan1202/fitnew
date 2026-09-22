import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fitos/core/config/env.dart';
import 'package:fitos/core/errors/error_mapper.dart';
import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/core/network/auth_interceptor.dart';
import 'package:fitos/core/network/dio_client.dart';
import 'package:fitos/core/storage/secure_storage.dart';
import 'package:fitos/features/auth/data/auth_repository_impl.dart';
import 'package:fitos/features/auth/data/session_remote_data_source.dart';
import 'package:fitos/features/auth/domain/entities/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/auth/auth_repository_impl_test.dart'
    show FakeCredentials;

/// Phase 6.6 Gate 6 regression: the alpha runtime talks to the address the
/// build was given, and a Google sign-in really reaches `/v1/auth/session`
/// there. A closed-alpha APK once pointed at an address the PC no longer
/// had; nothing left the phone, and the only feedback was "offline".
///
/// Run with the alpha define to prove the plumbing end to end:
///   flutter test --dart-define=API_BASE_URL=http://10.1.2.3:8080
///
/// Records every request URI the client attempts, and answers each one.
class RecordingAdapter implements HttpClientAdapter {
  RecordingAdapter({this.status = 200, Map<String, dynamic>? body})
      : body = body ?? const <String, dynamic>{};

  final int status;
  final Map<String, dynamic> body;
  final uris = <Uri>[];

  /// When set, every request fails as a connection error instead.
  DioExceptionType? failWith;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    uris.add(options.uri);
    if (failWith case final type?) {
      throw DioException(requestOptions: options, type: type);
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _NoTokens implements IdTokenProvider {
  @override
  Future<String?> idToken({bool forceRefresh = false}) async => 'token';
  @override
  Future<void> onSessionInvalid() async {}
}

void main() {
  test('the API client is built with the configured API_BASE_URL', () {
    final dio = buildDio(_NoTokens());
    expect(dio.options.baseUrl, Env.apiBaseUrl);
    expect(
      Env.apiBaseUrl,
      const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://10.0.2.2:8080',
      ),
      reason: 'the client must read the same define the alpha build passes',
    );
    // Whatever the define says, the app must talk to a real authority.
    final uri = Uri.parse(Env.apiBaseUrl);
    expect(uri.hasScheme, isTrue);
    expect(uri.host, isNotEmpty);
    expect(Env.apiAuthority, '${uri.host}:${uri.port}');
  });

  test('a Google sign-in POSTs /v1/auth/session to that base URL', () async {
    final adapter = RecordingAdapter(
      body: <String, dynamic>{
        'user': <String, dynamic>{
          'id': '11111111-1111-4111-8111-111111111111',
          'email': 'a@vit.ac.in',
          'displayName': 'Srijan',
          'timezone': 'Asia/Kolkata',
          'locale': 'en-IN',
          'createdAt': '2026-09-01T00:00:00.000Z',
          'onboardingStage': 'complete',
        },
        'isNewUser': false,
      },
    );
    final dio = buildDio(_NoTokens())..httpClientAdapter = adapter;
    final credentials = FakeCredentials();
    final repo = AuthRepositoryImpl(
      credentials: credentials,
      session: DioSessionRemoteDataSource(dio),
      store: InMemorySessionStore(),
      timeZoneName: () => null,
      localeTag: () => 'en-IN',
    );

    final result = await repo.signInWithGoogle();

    expect(credentials.calls, contains('google'));
    expect(
      adapter.uris.map((u) => u.toString()),
      ['${Env.apiBaseUrl}/v1/auth/session'],
      reason: 'the exchange must leave the phone, at the configured address',
    );
    expect(result, isA<Ok<AuthState>>());
  });

  test(
      'when that address does not answer, the failure names it instead of a bare "offline"',
      () async {
    final adapter = RecordingAdapter()
      ..failWith = DioExceptionType.connectionTimeout;
    final dio = buildDio(_NoTokens())..httpClientAdapter = adapter;
    final repo = AuthRepositoryImpl(
      credentials: FakeCredentials(),
      session: DioSessionRemoteDataSource(dio),
      store: InMemorySessionStore(),
      timeZoneName: () => null,
      localeTag: () => 'en-IN',
    );

    final result = await repo.signInWithGoogle();

    expect(adapter.uris, isNotEmpty);
    final failure = (result as Err<AuthState>).failure;
    expect(failure, isA<Offline>());
    expect(failure.message, contains(Env.apiAuthority));
    expect(failure.message, contains('Could not reach FITOS'));
  });

  test('with no request to name, the offline message stays generic', () {
    expect(ErrorMapper.offlineMessage(null), 'You appear to be offline.');
    expect(
      ErrorMapper.offlineMessage('10.1.2.3:8080'),
      startsWith('Could not reach FITOS at 10.1.2.3:8080.'),
    );
  });
}
