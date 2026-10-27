import 'dart:async';

import 'package:fitos/core/config/apk_update.dart';
import 'package:fitos/core/config/app_config.dart';
import 'package:fitos/core/config/app_update.dart';
import 'package:fitos/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_update_test.dart' show FakeFeed, FakeOpener, MemoryPrefs;

/// Beta 4.1 (updates plan, U2): "Update now" downloads FITOS's own APK from
/// tryfitos.me, checks its SHA-256 against version.json's, and hands it to
/// Android's installer; a file that does not match is thrown away; Android's
/// permission is asked for with a reason first; anything that fails offers
/// the download page.
const sha = 'a3f1c2d4e5b60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';

class FakeDownloader implements ApkDownloader {
  FakeDownloader({this.digest = sha});

  String digest;
  Object? error;

  /// When set, the download waits for it (to see the progress, or cancel).
  Completer<void>? gate;
  final downloads = <(String, String)>[];
  final deleted = <String>[];

  @override
  Future<void> download(
    String url,
    String path, {
    required void Function(int received) onProgress,
    required Future<void> cancel,
  }) async {
    downloads.add((url, path));
    onProgress(25 * 1024 * 1024);
    final e = error;
    if (e != null) throw e;
    final g = gate;
    if (g == null) return;
    var cancelled = false;
    await Future.any([g.future, cancel.then((_) => cancelled = true)]);
    if (cancelled) throw const ApkCancelled();
  }

  @override
  Future<String> sha256Of(String path) async => digest;

  @override
  Future<String> pathFor(int build) async => '/cache/updates/fitos-$build.apk';

  @override
  Future<void> delete(String path) async => deleted.add(path);
}

class FakeInstaller implements ApkInstaller {
  bool allowed = true;
  bool opens = true;
  int settingsOpened = 0;
  final installed = <String>[];

  @override
  Future<bool> canInstall() async => allowed;

  @override
  Future<void> openInstallSettings() async => settingsOpened++;

  @override
  Future<bool> install(String path) async {
    installed.add(path);
    return opens;
  }
}

const apkUrl = 'https://tryfitos.me/downloads/fitos-beta-4.1-18.apk';

const beta41 = LatestRelease(
  version: '1.0.0-beta.4.1',
  build: 18,
  url: 'https://tryfitos.me/download/',
  apkUrl: apkUrl,
  sha256: sha,
  sizeBytes: 50 * 1024 * 1024,
);

void main() {
  late FakeDownloader downloader;
  late FakeInstaller installer;

  setUp(() {
    downloader = FakeDownloader();
    installer = FakeInstaller();
  });

  group('what version.json may name', () {
    test('the APK fields are read, and kept in the cache', () {
      final r = LatestRelease.fromJson(beta41.toJson())!;
      expect(r.apkUrl, apkUrl);
      expect(r.sha256, sha);
      expect(r.sizeBytes, 50 * 1024 * 1024);
      final file = ApkFile.of(r)!;
      expect(file.url, apkUrl);
    });

    test('only an APK on tryfitos.me with a real SHA-256 and size', () {
      LatestRelease with_({String? url, String? digest, int? size}) =>
          LatestRelease(
            version: beta41.version,
            build: 18,
            url: beta41.url,
            apkUrl: url,
            sha256: digest,
            sizeBytes: size,
          );
      expect(ApkFile.of(with_(url: apkUrl, digest: sha, size: 1)), isNotNull);
      // An older website: no APK fields, so the download page.
      expect(ApkFile.of(with_()), isNull);
      expect(
        ApkFile.of(
          with_(url: 'https://evil.example/fitos.apk', digest: sha, size: 1),
        ),
        isNull,
      );
      expect(
        ApkFile.of(
          with_(url: 'http://tryfitos.me/fitos.apk', digest: sha, size: 1),
        ),
        isNull,
      );
      expect(
        ApkFile.of(
          with_(url: 'https://tryfitos.me/fitos.zip', digest: sha, size: 1),
        ),
        isNull,
      );
      expect(
        ApkFile.of(with_(url: apkUrl, digest: sha.toUpperCase(), size: 1)),
        isNull,
      );
      expect(ApkFile.of(with_(url: apkUrl, digest: 'abc', size: 1)), isNull);
      expect(ApkFile.of(with_(url: apkUrl, digest: sha, size: 0)), isNull);
    });
  });

  group('the flow', () {
    ApkUpdateFlow flow() => ApkUpdateFlow(
          file: ApkFile.of(beta41)!,
          build: 18,
          downloader: downloader,
          installer: installer,
        );

    test('a matching file goes to Android’s installer', () async {
      final f = flow();
      await f.run();
      expect(
        downloader.downloads.single,
        (apkUrl, '/cache/updates/fitos-18.apk'),
      );
      expect(installer.installed, ['/cache/updates/fitos-18.apk']);
      expect(f.value, isA<ApkHandedOver>());
      expect(downloader.deleted, isEmpty);
    });

    test('a file that does not match is thrown away, never installed',
        () async {
      downloader.digest = sha.replaceFirst('a', 'b');
      final f = flow();
      await f.run();
      expect(installer.installed, isEmpty);
      expect(downloader.deleted, ['/cache/updates/fitos-18.apk']);
      expect((f.value as ApkFailed).reason, ApkFailure.mismatch);
    });

    test('a download that fails is thrown away and says so', () async {
      downloader.error = Exception('offline');
      final f = flow();
      await f.run();
      expect(installer.installed, isEmpty);
      expect(downloader.deleted, hasLength(1));
      expect((f.value as ApkFailed).reason, ApkFailure.download);
    });

    test('Cancel stops the download and throws the part away', () async {
      downloader.gate = Completer<void>();
      final f = flow();
      final running = f.run();
      await Future<void>.delayed(Duration.zero);
      expect((f.value as ApkDownloading).fraction, 0.5);
      f.cancel();
      await running;
      expect(f.value, isA<ApkCancelledStep>());
      expect(downloader.deleted, hasLength(1));
      expect(installer.installed, isEmpty);
    });

    test('not yet allowed: nothing is downloaded until Android allows it',
        () async {
      installer.allowed = false;
      final f = flow();
      await f.run();
      expect(f.value, isA<ApkNeedsPermission>());
      expect(downloader.downloads, isEmpty);
      await f.openSettings();
      expect(installer.settingsOpened, 1);
      installer.allowed = true;
      await f.run();
      expect(f.value, isA<ApkHandedOver>());
    });

    test('the installer not opening is a failure with the page as the way',
        () async {
      installer.opens = false;
      final f = flow();
      await f.run();
      expect((f.value as ApkFailed).reason, ApkFailure.installer);
    });
  });

  group('on screen', () {
    late FakeOpener opener;

    Widget host({LatestRelease release = beta41, bool android = true}) {
      opener = FakeOpener();
      return ProviderScope(
        overrides: [
          appBuildProvider.overrideWith((_) async => 17),
          releaseFeedProvider.overrideWithValue(FakeFeed(release)),
          updatePrefsProvider.overrideWithValue(MemoryPrefs()),
          linkOpenerProvider.overrideWithValue(opener),
          updateClockProvider
              .overrideWithValue(() => DateTime.utc(2026, 10, 28, 9)),
          inAppInstallProvider.overrideWithValue(android),
          apkDownloaderProvider.overrideWithValue(downloader),
          apkInstallerProvider.overrideWithValue(installer),
        ],
        child: MaterialApp(
          theme: FitTheme.build(),
          home: const Scaffold(
            body: Column(
              children: <Widget>[UpdatePromptHost(), UpdateBanner()],
            ),
          ),
        ),
      );
    }

    Finder key(String k) => find.byKey(ValueKey(k));

    testWidgets('Update now: the progress, then Android’s installer',
        (tester) async {
      downloader.gate = Completer<void>();
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: key('update.now'),
          matching: find.text('Update now'),
        ),
        findsOneWidget,
      );
      await tester.tap(key('update.now'));
      await tester.pump();
      await tester.pump();
      expect(key('update.downloading'), findsOneWidget);
      expect(
        tester.widget<Text>(key('update.progress.text')).data,
        '25.0 of 50.0 MB',
      );
      downloader.gate!.complete();
      await tester.pumpAndSettle();
      expect(installer.installed, ['/cache/updates/fitos-18.apk']);
      expect(key('update.downloading'), findsNothing);
      expect(opener.opened, isEmpty);
    });

    testWidgets(
        'a file that does not match: said, and the download page offered',
        (tester) async {
      downloader.digest = sha.replaceFirst('a', 'b');
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.tap(key('update.now'));
      await tester.pumpAndSettle();
      expect(key('update.failed'), findsOneWidget);
      expect(find.textContaining('thrown away'), findsOneWidget);
      await tester.tap(key('update.failed.page'));
      await tester.pumpAndSettle();
      expect(opener.opened, ['https://tryfitos.me/download/']);
      expect(installer.installed, isEmpty);
    });

    testWidgets('Cancel closes it; nothing is installed', (tester) async {
      downloader.gate = Completer<void>();
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.tap(key('update.now'));
      await tester.pump();
      await tester.pump();
      await tester.tap(key('update.cancel'));
      await tester.pumpAndSettle();
      expect(key('update.downloading'), findsNothing);
      expect(installer.installed, isEmpty);
      expect(opener.opened, isEmpty);
    });

    testWidgets(
        'not yet allowed: the reason, the settings page, and back in FITOS it carries on',
        (tester) async {
      installer.allowed = false;
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.tap(key('update.now'));
      await tester.pumpAndSettle();
      expect(key('update.permission'), findsOneWidget);
      await tester.tap(key('update.permission.open'));
      await tester.pumpAndSettle();
      expect(installer.settingsOpened, 1);
      installer.allowed = true;
      // Away in Settings, then back.
      for (final s in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await tester.pumpAndSettle();
      expect(installer.installed, ['/cache/updates/fitos-18.apk']);
      expect(key('update.permission'), findsNothing);
    });

    testWidgets('the banner’s Update goes the same way', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.tap(key('update.later'));
      await tester.pumpAndSettle();
      await tester.tap(key('update.banner.open'));
      await tester.pumpAndSettle();
      expect(installer.installed, hasLength(1));
      expect(opener.opened, isEmpty);
    });

    testWidgets('no APK in version.json, or not Android: the download page',
        (tester) async {
      await tester.pumpWidget(
        host(
          release: const LatestRelease(
            version: '1.0.0-beta.4.1',
            build: 18,
            url: 'https://tryfitos.me/download/',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: key('update.now'), matching: find.text('Update')),
        findsOneWidget,
      );
      await tester.tap(key('update.now'));
      await tester.pumpAndSettle();
      expect(opener.opened, ['https://tryfitos.me/download/']);

      await tester.pumpWidget(Container());
      await tester.pumpWidget(host(android: false));
      await tester.pumpAndSettle();
      await tester.tap(key('update.now'));
      await tester.pumpAndSettle();
      expect(opener.opened, ['https://tryfitos.me/download/']);
      expect(downloader.downloads, isEmpty);
    });
  });
}
