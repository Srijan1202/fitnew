import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app_update.dart';

/// Beta 4.1 (the updates plan, U2): FITOS installs its own APK.
///
/// "Update now" downloads the APK the website names in version.json into the
/// app's cache, checks its SHA-256 against the one version.json carries
/// (a file that does not match is thrown away, never installed), then hands
/// it to Android's installer, where the tester taps Update once. Android
/// asks the first time whether FITOS may install apps; FITOS says why and
/// opens that settings page. Anything that fails falls back to the download
/// page. Only tryfitos.me is ever downloaded from.

/// The pieces of the APK on the website; null when version.json has none
/// (an older website) or they are not FITOS's own.
class ApkFile {
  const ApkFile({
    required this.url,
    required this.sha256,
    required this.sizeBytes,
  });

  static ApkFile? of(LatestRelease r) {
    final url = r.apkUrl;
    final sha = r.sha256;
    final size = r.sizeBytes;
    if (url == null || sha == null || size == null) return null;
    if (!url.startsWith('https://tryfitos.me/') || !url.endsWith('.apk')) {
      return null;
    }
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(sha) || size <= 0) return null;
    return ApkFile(url: url, sha256: sha, sizeBytes: size);
  }

  final String url;
  final String sha256;
  final int sizeBytes;
}

/// Downloads to a file, reporting the bytes so far.
abstract class ApkDownloader {
  /// Throws [ApkCancelled] when [cancel] completes first.
  Future<void> download(
    String url,
    String path, {
    required void Function(int received) onProgress,
    required Future<void> cancel,
  });

  /// The SHA-256 of the file at [path], lowercase hex.
  Future<String> sha256Of(String path);

  /// Where the APK for [build] goes: the app's cache, which the installer's
  /// FileProvider shares (`res/xml/update_paths.xml`).
  Future<String> pathFor(int build);

  Future<void> delete(String path);
}

class ApkCancelled implements Exception {
  const ApkCancelled();
}

class DioApkDownloader implements ApkDownloader {
  DioApkDownloader([Dio? dio])
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 60),
              ),
            );

  final Dio _dio;

  @override
  Future<void> download(
    String url,
    String path, {
    required void Function(int received) onProgress,
    required Future<void> cancel,
  }) async {
    final token = CancelToken();
    unawaited(cancel.then((_) => token.cancel()));
    try {
      await _dio.download(
        url,
        path,
        cancelToken: token,
        deleteOnError: true,
        onReceiveProgress: (received, _) => onProgress(received),
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) throw const ApkCancelled();
      rethrow;
    }
  }

  @override
  Future<String> sha256Of(String path) async =>
      (await sha256.bind(File(path).openRead()).first).toString();

  @override
  Future<String> pathFor(int build) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/updates');
    // Only the newest is ever kept: an older download is no use.
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    return '${dir.path}/fitos-$build.apk';
  }

  @override
  Future<void> delete(String path) async {
    try {
      await File(path).delete();
    } on Object {
      // Already gone.
    }
  }
}

/// Android's side: may FITOS install apps, the settings page that allows it,
/// and the installer.
abstract class ApkInstaller {
  Future<bool> canInstall();
  Future<void> openInstallSettings();

  /// Opens Android's installer on the file; false when it could not.
  Future<bool> install(String path);
}

class ChannelApkInstaller implements ApkInstaller {
  static const _channel = MethodChannel('fitos/device');

  @override
  Future<bool> canInstall() async {
    try {
      return await _channel.invokeMethod<bool>('canInstallApks') ?? false;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> openInstallSettings() async {
    try {
      await _channel.invokeMethod<void>('openInstallSettings');
    } on Object {
      // The tester can still find it in Settings; the dialog says where.
    }
  }

  @override
  Future<bool> install(String path) async {
    try {
      await _channel.invokeMethod<void>('installApk', path);
      return true;
    } on Object {
      return false;
    }
  }
}

final apkDownloaderProvider =
    Provider<ApkDownloader>((_) => DioApkDownloader());
final apkInstallerProvider =
    Provider<ApkInstaller>((_) => ChannelApkInstaller());

/// Where an in-app update is.
sealed class ApkStep {
  const ApkStep();
}

/// Android has not yet let FITOS install apps.
class ApkNeedsPermission extends ApkStep {
  const ApkNeedsPermission();
}

class ApkDownloading extends ApkStep {
  const ApkDownloading(this.received, this.total);
  final int received;
  final int total;
  double get fraction => total <= 0 ? 0 : (received / total).clamp(0, 1);
}

class ApkVerifying extends ApkStep {
  const ApkVerifying();
}

/// Handed to Android's installer; FITOS has nothing left to do.
class ApkHandedOver extends ApkStep {
  const ApkHandedOver();
}

class ApkCancelledStep extends ApkStep {
  const ApkCancelledStep();
}

enum ApkFailure { download, mismatch, installer }

class ApkFailed extends ApkStep {
  const ApkFailed(this.reason);
  final ApkFailure reason;

  String get message => switch (reason) {
        ApkFailure.download =>
          'The download did not finish. Check the connection, or get it from the download page.',
        ApkFailure.mismatch =>
          'The downloaded file was not the one the website named, so it was thrown away. Get it from the download page.',
        ApkFailure.installer =>
          'Android’s installer did not open. Get it from the download page.',
      };
}

/// One in-app update: permission, download, check, install. The dialog
/// listens to it; it never touches the UI itself.
class ApkUpdateFlow extends ValueNotifier<ApkStep> {
  ApkUpdateFlow({
    required this.file,
    required this.build,
    required ApkDownloader downloader,
    required ApkInstaller installer,
  })  : _downloader = downloader,
        _installer = installer,
        super(const ApkDownloading(0, 0));

  final ApkFile file;
  final int build;
  final ApkDownloader _downloader;
  final ApkInstaller _installer;
  Completer<void>? _cancel;
  bool _running = false;

  /// Starts, or carries on after the settings page; a no-op while running.
  Future<void> run() async {
    if (_running) return;
    _running = true;
    try {
      if (!await _installer.canInstall()) {
        value = const ApkNeedsPermission();
        return;
      }
      final path = await _downloader.pathFor(build);
      value = ApkDownloading(0, file.sizeBytes);
      final cancel = _cancel = Completer<void>();
      try {
        await _downloader.download(
          file.url,
          path,
          onProgress: (r) => value = ApkDownloading(r, file.sizeBytes),
          cancel: cancel.future,
        );
      } on ApkCancelled {
        await _downloader.delete(path);
        value = const ApkCancelledStep();
        return;
      } on Object {
        await _downloader.delete(path);
        value = const ApkFailed(ApkFailure.download);
        return;
      }
      value = const ApkVerifying();
      final sha = await _downloader.sha256Of(path);
      if (sha != file.sha256) {
        await _downloader.delete(path);
        value = const ApkFailed(ApkFailure.mismatch);
        return;
      }
      value = await _installer.install(path)
          ? const ApkHandedOver()
          : const ApkFailed(ApkFailure.installer);
    } finally {
      _cancel = null;
      _running = false;
    }
  }

  void cancel() {
    final c = _cancel;
    if (c != null && !c.isCompleted) c.complete();
  }

  Future<void> openSettings() => _installer.openInstallSettings();
}
