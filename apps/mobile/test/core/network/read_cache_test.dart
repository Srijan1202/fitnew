import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fitos/core/network/read_cache.dart';
import 'package:fitos/core/network/retry_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

/// Beta 4.1.1 (owner: "unable to open even profile" on a slow network).

class _Store implements ReadStore {
  final Map<String, KeptRead> rows = {};

  @override
  Future<KeptRead?> read(String key) async => rows[key];

  @override
  Future<void> write(String key, Uint8List body) async =>
      rows[key] = KeptRead(body, DateTime.now().toUtc());

  @override
  Future<void> forget(String prefix) async =>
      rows.removeWhere((k, _) => k.startsWith(prefix));

  void keep(String key, Object json, {Duration age = Duration.zero}) =>
      rows[key] = KeptRead(
        Uint8List.fromList(utf8.encode(jsonEncode(json))),
        DateTime.now().toUtc().subtract(age),
      );
}

/// Answers each request with what [next] says: a body, an error, or a
/// future that has not finished yet (a slow network).
class _Network implements HttpClientAdapter {
  final List<RequestOptions> calls = [];
  Future<ResponseBody> Function(RequestOptions o) next =
      (_) async => _json({'ok': true});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    calls.add(options);
    return next(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object json, [int status = 200]) => ResponseBody.fromString(
      jsonEncode(json),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

void main() {
  late _Store store;
  late _Network network;
  late Dio dio;
  String? user;

  setUp(() {
    store = _Store();
    network = _Network();
    user = 'u1';
    dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
      ..httpClientAdapter = ReadCacheAdapter(
        network,
        store: store,
        userId: () => user,
        softDeadline: const Duration(milliseconds: 60),
      );
    dio.interceptors.add(
      RetryInterceptor(dio, baseDelay: const Duration(milliseconds: 1)),
    );
  });

  group('which reads', () {
    test('screens with no copy of their own are served; labelled ones not', () {
      expect(readKindOf('/v1/user/profile'), ReadKind.serve);
      expect(readKindOf('/v1/training/program'), ReadKind.serve);
      expect(readKindOf('/v1/training/templates/ppl'), ReadKind.serve);
      expect(readKindOf('/v1/exercises'), ReadKind.serve);
      expect(readKindOf('/v1/today'), ReadKind.own);
      expect(readKindOf('/v1/nutrition/day/2026-10-29'), ReadKind.own);
      expect(readKindOf('/v1/running/runs'), ReadKind.own);
      // Never: sign-in, onboarding, search, AI, shared links, config.
      expect(readKindOf('/v1/onboarding/state'), isNull);
      expect(readKindOf('/v1/nutrition/foods/search'), isNull);
      expect(readKindOf('/v1/training/shared/ABC'), isNull);
      expect(readKindOf('/v1/meta/config'), isNull);
      // A prefix is a path segment, not a string prefix.
      expect(readKindOf('/v1/todayx'), isNull);
    });

    test('a write makes its resource stale; any user write all of /v1/user',
        () {
      expect(staleUnder('/v1/training/program/days/3'), '/v1/training/program');
      expect(
        staleUnder('/v1/training/sessions/s1/sets'),
        '/v1/training/sessions',
      );
      expect(staleUnder('/v1/user/profile'), '/v1/user');
      expect(staleUnder('/v1/user/goal'), '/v1/user');
    });
  });

  test('a first read waits for the network and keeps the answer', () async {
    network.next = (_) async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      return _json({'name': 'Asha'});
    };
    final r = await dio.get<Map<String, dynamic>>('/v1/user/profile');
    expect(r.data, {'name': 'Asha'});
    expect(store.rows.keys, ['http.u1./v1/user/profile']);
  });

  test(
      'slow: the kept answer is served after the deadline, and the late one kept for next time',
      () async {
    store.keep('http.u1./v1/user/profile', {'name': 'old'});
    final late = Completer<ResponseBody>();
    network.next = (_) => late.future;
    final watch = Stopwatch()..start();
    final r = await dio.get<Map<String, dynamic>>('/v1/user/profile');
    expect(r.data, {'name': 'old'});
    expect(r.headers.value(ReadCacheAdapter.keptHeader), isNotNull);
    expect(watch.elapsedMilliseconds, lessThan(1000));
    late.complete(_json({'name': 'new'}));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(
      utf8.decode(store.rows['http.u1./v1/user/profile']!.body),
      '{"name":"new"}',
    );
  });

  test('no connection: the kept answer at once, not after three tries',
      () async {
    store.keep('http.u1./v1/training/program', {'days': 4});
    network.next = (o) async => throw DioException.connectionError(
          requestOptions: o,
          reason: 'offline',
        );
    final r = await dio.get<Map<String, dynamic>>('/v1/training/program');
    expect(r.data, {'days': 4});
    expect(network.calls, hasLength(1));
  });

  test('fast: the network answer, not the kept one', () async {
    store.keep('http.u1./v1/user/profile', {'name': 'old'});
    network.next = (_) async => _json({'name': 'new'});
    final r = await dio.get<Map<String, dynamic>>('/v1/user/profile');
    expect(r.data, {'name': 'new'});
    expect(r.headers.value(ReadCacheAdapter.keptHeader), isNull);
  });

  test(
      'a labelled screen with an old kept answer: a timeout after the deadline, not retried, so it shows its own copy',
      () async {
    store.keep(
      'http.u1./v1/today',
      {'plan': 'old'},
      age: const Duration(hours: 3),
    );
    network.next = (_) => Completer<ResponseBody>().future;
    await expectLater(
      dio.get<Map<String, dynamic>>('/v1/today'),
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.connectionTimeout,
        ),
      ),
    );
    expect(network.calls, hasLength(1));
  });

  test(
      'a labelled screen with a recent kept answer (a late one): served, so a slow network still moves on',
      () async {
    store.keep(
      'http.u1./v1/today',
      {'plan': 'five minutes ago'},
      age: const Duration(minutes: 5),
    );
    network.next = (_) => Completer<ResponseBody>().future;
    final r = await dio.get<Map<String, dynamic>>('/v1/today');
    expect(r.data, {'plan': 'five minutes ago'});
  });

  test('a labelled screen offline with an old kept answer: the error as before',
      () async {
    store.keep(
      'http.u1./v1/today',
      {'plan': 'old'},
      age: const Duration(days: 1),
    );
    network.next = (o) async => throw DioException.connectionError(
          requestOptions: o,
          reason: 'offline',
        );
    await expectLater(
      dio.get<Map<String, dynamic>>('/v1/today'),
      throwsA(isA<DioException>()),
    );
  });

  test('a write forgets the kept answers it makes stale, and only those',
      () async {
    store
      ..keep('http.u1./v1/user/profile', {'name': 'old'})
      ..keep('http.u1./v1/user/targets', {'kcal': 2000})
      ..keep('http.u1./v1/training/program', {'days': 4});
    await dio.patch<Object?>('/v1/user/profile', data: {'name': 'new'});
    expect(store.rows.keys, ['http.u1./v1/training/program']);
  });

  test('a failed write forgets nothing', () async {
    store.keep('http.u1./v1/user/profile', {'name': 'old'});
    network.next = (_) async => _json({'error': 'no'}, 422);
    await expectLater(
      dio.patch<Object?>('/v1/user/profile', data: {'name': 'new'}),
      throwsA(isA<DioException>()),
    );
    expect(store.rows.keys, ['http.u1./v1/user/profile']);
  });

  test('kept per user: another account never gets this one\'s answer',
      () async {
    store.keep('http.u1./v1/user/profile', {'name': 'u1'});
    user = 'u2';
    network.next = (_) => Completer<ResponseBody>().future;
    // u2 has nothing kept: it waits for the network (here, forever).
    final r = dio.get<Map<String, dynamic>>('/v1/user/profile');
    await Future<void>.delayed(const Duration(milliseconds: 150));
    var done = false;
    unawaited(r.then((_) => done = true, onError: (_) => done = true));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(done, isFalse);
  });

  test('no session, and reads it does not cover: untouched, nothing kept',
      () async {
    user = null;
    await dio.get<Object?>('/v1/user/profile');
    user = 'u1';
    await dio.get<Object?>('/v1/onboarding/state');
    expect(store.rows, isEmpty);
  });

  test('an error answer is not kept', () async {
    network.next = (_) async => _json({'error': 'down'}, 503);
    await expectLater(
      dio.get<Object?>('/v1/user/profile'),
      throwsA(isA<DioException>()),
    );
    expect(store.rows, isEmpty);
  });

  test('a store that fails never fails the request', () async {
    final broken = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
      ..httpClientAdapter = ReadCacheAdapter(
        network,
        store: _Broken(),
        userId: () => 'u1',
      );
    final r = await broken.get<Map<String, dynamic>>('/v1/user/profile');
    expect(r.data, {'ok': true});
    await broken.patch<Object?>('/v1/user/profile');
  });
}

class _Broken implements ReadStore {
  @override
  Future<KeptRead?> read(String key) => throw StateError('no db');

  @override
  Future<void> write(String key, Uint8List body) => throw StateError('no db');

  @override
  Future<void> forget(String prefix) => throw StateError('no db');
}
