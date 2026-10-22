import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../features/auth/presentation/controllers/auth_providers.dart';
import '../theme/tokens.dart';
import '../../shared/widgets/fit_glass.dart';

/// Phase 19 (E1, E18; ADR-026): the server's public start-up config,
/// `GET /v1/meta/config`: the feature flags and the oldest build allowed.
class AppConfig {
  const AppConfig({required this.flags, required this.minimumBuild});

  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
        flags: (json['flags'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v as bool)),
        minimumBuild: json['minimumBuild'] as int,
      );

  final Map<String, bool> flags;
  final int minimumBuild;

  Map<String, dynamic> toJson() =>
      {'flags': flags, 'minimumBuild': minimumBuild};
}

abstract class MetaApi {
  /// Null when it cannot be read (offline): nothing is then blocked.
  Future<AppConfig?> config();
}

class DioMetaApi implements MetaApi {
  DioMetaApi(this._dio);

  final Dio _dio;

  @override
  Future<AppConfig?> config() async {
    try {
      final r = await _dio.get<Map<String, dynamic>>('/v1/meta/config');
      return AppConfig.fromJson(r.data!);
    } on Object {
      return null;
    }
  }
}

final metaApiProvider =
    Provider<MetaApi>((ref) => DioMetaApi(ref.watch(dioProvider)));

/// This build's number (pubspec `+N`, the Android versionCode).
final appBuildProvider = FutureProvider<int>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return int.tryParse(info.buildNumber) ?? 0;
});

final appConfigProvider = FutureProvider<AppConfig?>(
  (ref) => ref.watch(metaApiProvider).config(),
  retry: (_, __) => null,
);

/// True only when the server says this build is too old. Unknown (offline,
/// still loading, an error) is never "too old": the app keeps working.
final updateRequiredProvider = Provider<bool>((ref) {
  final config = ref.watch(appConfigProvider).value;
  final build = ref.watch(appBuildProvider).value;
  if (config == null || build == null) return false;
  return config.minimumBuild > 0 && build < config.minimumBuild;
});

/// A feature flag from the server; [fallback] until the config is read.
bool flagOn(WidgetRef ref, String key, {bool fallback = true}) =>
    ref.watch(appConfigProvider).value?.flags[key] ?? fallback;

/// Everything the app shows while its build is below the minimum.
class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      key: const ValueKey('update.required'),
      body: FitBackdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(FitSpacing.screen),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('UPDATE FITOS', style: textTheme.labelSmall),
                const SizedBox(height: FitSpacing.sm),
                Text(
                  'This version is too old.',
                  style: textTheme.headlineMedium,
                ),
                const SizedBox(height: FitSpacing.sm),
                Text(
                  'Install the latest FITOS from where you got it (the Play Store '
                  'testing link or the beta group). Your data is safe on the '
                  'server and comes back when you sign in.',
                  style: textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
