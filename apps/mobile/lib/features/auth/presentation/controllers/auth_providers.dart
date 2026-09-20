import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../data/auth_repository_impl.dart';
import '../../data/firebase_auth_data_source.dart';
import '../../data/session_remote_data_source.dart';
import '../../domain/repositories/auth_repository.dart';

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
  return buildDio(ref.watch(credentialSourceProvider));
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
    // TIME ZONE IS DELIBERATELY NOT SENT IN PHASE 1.
    // `DateTime.now().timeZoneName` on Android returns an abbreviation ("IST"),
    // not the IANA name the server requires (§9.1), so sending it would 422
    // on every sign-in. Dart cannot produce "Asia/Kolkata" without a platform
    // channel. The server therefore applies its default, Asia/Kolkata, which
    // is correct for every V1 user (VIT Vellore).
    // TODO(Phase 2): add flutter_timezone for detection and let the profile
    // screen set it explicitly.
    timeZoneName: () => null,
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
