import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/device_time_zone.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/read_cache.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../data/auth_repository_impl.dart';
import '../../data/firebase_auth_data_source.dart';
import '../../data/session_remote_data_source.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../workout/presentation/controllers/workout_providers.dart';
import 'auth_controller.dart';

/// Dependency wiring. Riverpod is the only DI container (§7.1). Tests override
/// [authRepositoryProvider] and never touch the rest.
///
/// Plain providers rather than generated ones: these are singletons with no
/// parameters, and keeping them free of codegen means the wiring is readable
/// without opening a `.g.dart`.

final sessionStoreProvider = Provider<SessionStore>((ref) {
  return SecureSessionStore();
});

final credentialSourceProvider = Provider<CredentialSource>((ref) {
  return FirebaseCredentialSource();
});

final dioProvider = Provider<Dio>((ref) {
  final dio = buildDio(ref.watch(credentialSourceProvider));
  // Beta 4.1.1 (owner): on a slow or no network a screen shows the phone's
  // last good copy instead of waiting (read_cache.dart).
  dio.httpClientAdapter = ReadCacheAdapter(
    dio.httpClientAdapter,
    store: DriftReadStore(() => ref.read(appDatabaseProvider)),
    userId: () {
      try {
        return ref.read(sessionUserIdProvider);
      } on Object {
        return null; // no session yet: nothing kept, nothing served
      }
    },
  );
  return dio;
});

final sessionRemoteDataSourceProvider =
    Provider<SessionRemoteDataSource>((ref) {
  return DioSessionRemoteDataSource(ref.watch(dioProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    credentials: ref.watch(credentialSourceProvider),
    session: ref.watch(sessionRemoteDataSourceProvider),
    store: ref.watch(sessionStoreProvider),
    // The phone's IANA zone from the `fitos/device` channel (audit
    // 2026-10-20). `DateTime.now().timeZoneName` is only an abbreviation
    // ("IST") the server would reject; when the zone cannot be read (or has
    // the wrong shape) nothing is sent and the server keeps Asia/Kolkata.
    // The server stores it at the first sign-in only; afterwards Profile
    // offers the phone's zone when it differs.
    timeZoneName: () => ref.read(deviceTimeZoneProvider),
    localeTag: deviceLocaleTag,
  );
});

/// `Platform.localeName` is "en_IN", but can also be "en_US_POSIX" or
/// "zh_Hans_CN", neither of which the server's BCP 47 shape accepts. Send only
/// a clean language[-REGION] tag, or nothing and let the server default to
/// en-IN. A locale must never be the reason a sign-in fails.
String? deviceLocaleTag([String? raw]) {
  final parts = (raw ?? Platform.localeName).split(RegExp('[_-]'));
  final lang = parts.isNotEmpty ? parts[0].toLowerCase() : '';
  if (!RegExp(r'^[a-z]{2,3}$').hasMatch(lang)) return null;
  final region = parts.length > 1 ? parts[1].toUpperCase() : null;
  if (region != null && RegExp(r'^[A-Z]{2}$').hasMatch(region)) {
    return '$lang-$region';
  }
  return lang;
}
