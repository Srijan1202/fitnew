import 'package:fitos/core/storage/secure_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// A stand-in Keystore: values in a map; [broken] reads throw, as data the
/// version 9 plugin wrote does after the jump to version 11.
class _Storage implements FlutterSecureStorage {
  final values = <String, String>{};
  final broken = <String>{};
  final deleted = <String>[];

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (broken.contains(key)) throw Exception('cannot decrypt');
    return values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    broken.remove(key);
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    deleted.add(key);
    broken.remove(key);
    values.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('writes and reads back the token and the profile; clear removes both',
      () async {
    final storage = _Storage();
    final store = SecureSessionStore(storage);
    await store.writeIdToken('t-1');
    await store.writeProfileJson('{"id":"u"}');
    expect(await store.readIdToken(), 't-1');
    expect(await store.readProfileJson(), '{"id":"u"}');
    await store.clear();
    expect(await store.readIdToken(), isNull);
    expect(await store.readProfileJson(), isNull);
  });

  test(
      'an unreadable value (written by the old plugin) is "nothing stored", and is removed',
      () async {
    final storage = _Storage()
      ..values['session.idToken'] = 'old'
      ..broken.add('session.idToken')
      ..broken.add('session.profile');
    final store = SecureSessionStore(storage);
    expect(await store.readIdToken(), isNull);
    expect(await store.readProfileJson(), isNull);
    expect(storage.deleted, ['session.idToken', 'session.profile']);
    // The next sign-in writes fresh values that read back.
    await store.writeIdToken('t-2');
    expect(await store.readIdToken(), 't-2');
  });
}
