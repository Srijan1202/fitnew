import 'dart:async';
import 'dart:convert';

import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/core/storage/secure_storage.dart';
import 'package:fitos/features/auth/data/auth_repository_impl.dart';
import 'package:fitos/features/auth/data/dtos/session_dto.dart';
import 'package:fitos/features/auth/data/firebase_auth_data_source.dart';
import 'package:fitos/features/auth/data/session_remote_data_source.dart';
import 'package:fitos/features/auth/domain/entities/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';

/// Fake Firebase. Holds a uid or not; every credential action succeeds or
/// fails as scripted.
class FakeCredentials implements CredentialSource {
  String? uid;
  String? token = 'id-token';
  Result<void> next = const Ok(null);
  final calls = <String>[];
  final _uidChanges = StreamController<String?>.broadcast();

  @override
  String? get currentUid => uid;
  @override
  Stream<String?> uidChanges() => _uidChanges.stream;
  void emitUid(String? value) => _uidChanges.add(value);

  @override
  Future<String?> idToken({bool forceRefresh = false}) async => token;
  @override
  Future<void> onSessionInvalid() async {}

  Future<Result<void>> _act(String name) async {
    calls.add(name);
    if (next is Ok) uid = 'uid-1';
    return next;
  }

  @override
  Future<Result<void>> signInWithEmail(String e, String p) => _act('email');
  @override
  Future<Result<void>> signUpWithEmail(String e, String p) => _act('signup');
  @override
  Future<Result<void>> signInWithGoogle() => _act('google');
  @override
  Future<Result<void>> sendPasswordReset(String e) async {
    calls.add('reset');
    return next;
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    uid = null;
  }
}

class FakeSession implements SessionRemoteDataSource {
  Result<CreateSessionResponse> next =
      Ok(CreateSessionResponse(user: testProfile, isNewUser: true));
  CreateSessionRequest? lastRequest;
  int deletes = 0;

  @override
  Future<Result<CreateSessionResponse>> createSession(
    CreateSessionRequest request,
  ) async {
    lastRequest = request;
    return next;
  }

  @override
  Future<Result<void>> deleteSession() async {
    deletes += 1;
    return const Ok(null);
  }
}

void main() {
  late FakeCredentials creds;
  late FakeSession session;
  late InMemorySessionStore store;
  late AuthRepositoryImpl repo;

  setUp(() {
    creds = FakeCredentials();
    session = FakeSession();
    store = InMemorySessionStore();
    repo = AuthRepositoryImpl(
      credentials: creds,
      session: session,
      store: store,
      timeZoneName: () => null,
      localeTag: () => 'en-IN',
    );
  });

  group('the §11 flow', () {
    test(
        'sign-in: Firebase → token stored → POST /auth/session → profile stored',
        () async {
      final result = await repo.signInWithEmail(email: 'a', password: 'b');

      expect(result.isOk, isTrue);
      final state = (result as Ok<AuthState>).value as AuthSignedIn;
      expect(state.profile, testProfile);
      expect(state.isNewUser, isTrue);

      expect(await store.readIdToken(), 'id-token');
      expect(
        jsonDecode((await store.readProfileJson())!),
        testProfile.toJson(),
      );
      expect(session.lastRequest?.locale, 'en-IN');
      // Phase 1 sends no time zone (see auth_providers.dart).
      expect(session.lastRequest?.timezone, isNull);
    });

    test('a Firebase credential failure never reaches the server', () async {
      creds.next = const Err(wrongPassword);
      final result = await repo.signInWithEmail(email: 'a', password: 'b');
      expect(result, isA<Err<AuthState>>());
      expect(session.lastRequest, isNull);
      expect(await store.readProfileJson(), isNull);
    });

    test(
        'Firebase accepts but the server refuses: sign out of Firebase, '
        'store cleared, failure returned — no half-signed-in state', () async {
      session.next = const Err(RateLimited());
      final result = await repo.signInWithEmail(email: 'a', password: 'b');

      expect(result, isA<Err<AuthState>>());
      expect(creds.calls, contains('signOut'));
      expect(creds.uid, isNull);
      expect(await store.readProfileJson(), isNull);
    });
  });

  group('restore (cold start)', () {
    test('no Firebase user → signedOut and store cleared', () async {
      await store.writeProfileJson('{"stale":true}');
      expect(await repo.restore(), isA<AuthSignedOut>());
      expect(await store.readProfileJson(), isNull);
    });

    test('Firebase user + cached profile → signedIn with NO network call',
        () async {
      creds.uid = 'uid-1';
      await store.writeProfileJson(jsonEncode(testProfile.toJson()));
      final state = await repo.restore();
      expect(state, isA<AuthSignedIn>());
      expect((state as AuthSignedIn).profile, testProfile);
      expect(
        session.lastRequest,
        isNull,
        reason: 'fast path must not hit the API',
      );
    });

    test('Firebase user but no cached profile → re-exchanges with the server',
        () async {
      creds.uid = 'uid-1';
      final state = await repo.restore();
      expect(state, isA<AuthSignedIn>());
      expect(session.lastRequest, isNotNull);
    });

    test('corrupt cache falls through to the server instead of crashing',
        () async {
      creds.uid = 'uid-1';
      await store.writeProfileJson('not json');
      final state = await repo.restore();
      expect(state, isA<AuthSignedIn>());
      expect(session.lastRequest, isNotNull);
    });
  });

  group('sign out', () {
    test('revokes on the server, signs out of Firebase, clears the store',
        () async {
      creds.uid = 'uid-1';
      await store.writeIdToken('t');
      await store.writeProfileJson('{}');

      await repo.signOut();

      expect(session.deletes, 1);
      expect(creds.calls, contains('signOut'));
      expect(await store.readIdToken(), isNull);
      expect(await store.readProfileJson(), isNull);
    });
  });

  test('changes(): a null uid from Firebase becomes signedOut and clears',
      () async {
    await store.writeProfileJson('{}');
    final next = repo.changes().first;
    // The async* body subscribes to the credential stream one microtask after
    // `.first` listens; emitting synchronously would be lost on a broadcast
    // stream. This is a test-ordering detail, not app behaviour: Firebase
    // never emits before the app has subscribed.
    await Future<void>.delayed(Duration.zero);
    creds.emitUid(null);
    expect(await next, isA<AuthSignedOut>());
    expect(await store.readProfileJson(), isNull);
  });
}
