import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keychain/Keystore-backed storage for the session (§7.1, §11).
///
/// Two things live here and nothing else:
///  - the last-known Firebase ID token, so the first API call after a cold
///    start can be authenticated before the Firebase SDK has finished
///    re-hydrating;
///  - the app session profile, so the gate can route straight to TODAY on
///    restart without a network round-trip.
///
/// Neither is a long-lived secret — Firebase's own persisted session is the
/// source of truth and refreshes the token — but both are user-identifying,
/// so they stay out of SharedPreferences (§7.1: "trivial flags only").
abstract class SessionStore {
  Future<String?> readIdToken();
  Future<void> writeIdToken(String token);

  Future<String?> readProfileJson();
  Future<void> writeProfileJson(String json);

  /// Sign-out: everything goes, in one call, so a partial clear is impossible.
  Future<void> clear();
}

class SecureSessionStore implements SessionStore {
  SecureSessionStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  static const _kIdToken = 'session.idToken';
  static const _kProfile = 'session.profile';

  @override
  Future<String?> readIdToken() => _storage.read(key: _kIdToken);

  @override
  Future<void> writeIdToken(String token) =>
      _storage.write(key: _kIdToken, value: token);

  @override
  Future<String?> readProfileJson() => _storage.read(key: _kProfile);

  @override
  Future<void> writeProfileJson(String json) =>
      _storage.write(key: _kProfile, value: json);

  @override
  Future<void> clear() async {
    await _storage.delete(key: _kIdToken);
    await _storage.delete(key: _kProfile);
  }
}

/// In-memory store for tests and for the gate before storage is available.
class InMemorySessionStore implements SessionStore {
  String? _token;
  String? _profile;

  @override
  Future<String?> readIdToken() async => _token;
  @override
  Future<void> writeIdToken(String token) async => _token = token;
  @override
  Future<String?> readProfileJson() async => _profile;
  @override
  Future<void> writeProfileJson(String json) async => _profile = json;
  @override
  Future<void> clear() async {
    _token = null;
    _profile = null;
  }
}
