import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/tokens.dart';
import '../../shared/widgets/fit_glass.dart';
import 'apk_update.dart';
import 'app_config.dart';

/// Beta 3.2 (ADR-026 amendment): "a new version is available".
///
/// The website publishes the latest beta at [kReleaseFeedUrl], built from the
/// same file that describes the APK, so every website deploy with a new APK
/// updates it. The app reads it at most every [kUpdateCheckEvery] and compares
/// the build number with its own. Beta 3.5 (owner 2026-10-24): while a newer
/// build exists, the dialog shows over whatever screen is open EVERY time the
/// app is opened, and again when it comes back after
/// [kUpdatePromptAfterAway] in the background (never in the middle of a
/// workout); the banner sits at the very top of Home and × hides it only
/// until the next open. Nothing about the user is sent: it is a plain GET of
/// a public file. Offline, or a bad file, shows nothing.
///
/// Beta 3.9 (owner: the 3.8 notification came, the pop-up did not): the
/// answer was kept for an hour, so a phone that had looked just before the
/// release still believed the old build was the latest. A tapped "FITOS beta
/// N is out" now reads the website at once ([UpdateController.checkNow]), and
/// the answer is kept for 15 minutes.
const kReleaseFeedUrl = 'https://tryfitos.me/version.json';
const kDownloadUrl = 'https://tryfitos.me/download/';
const kUpdateCheckEvery = Duration(minutes: 15);

/// Back in the app after at least this long away counts as opening it again.
const kUpdatePromptAfterAway = Duration(minutes: 5);

/// The latest beta as the website describes it.
class LatestRelease {
  const LatestRelease({
    required this.version,
    required this.build,
    required this.url,
    this.notesUrl,
    this.apkUrl,
    this.sha256,
    this.sizeBytes,
  });

  /// Null for anything that is not the expected shape.
  static LatestRelease? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final version = json['version'];
    final build = json['build'];
    final url = json['url'];
    final notes = json['notesUrl'];
    final apk = json['apkUrl'];
    final sha = json['sha256'];
    final size = json['sizeBytes'];
    if (version is! String || build is! int || url is! String) return null;
    return LatestRelease(
      version: version,
      build: build,
      url: url,
      notesUrl: notes is String ? notes : null,
      apkUrl: apk is String ? apk : null,
      sha256: sha is String ? sha : null,
      sizeBytes: size is int ? size : null,
    );
  }

  final String version;
  final int build;
  final String url;
  final String? notesUrl;

  /// Beta 4.1 (U2): the APK itself, for "Update now" inside the app. An
  /// older version.json has none; the download page is used then.
  final String? apkUrl;
  final String? sha256;
  final int? sizeBytes;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'version': version,
        'build': build,
        'url': url,
        if (notesUrl != null) 'notesUrl': notesUrl,
        if (apkUrl != null) 'apkUrl': apkUrl,
        if (sha256 != null) 'sha256': sha256,
        if (sizeBytes != null) 'sizeBytes': sizeBytes,
      };

  /// "beta 3.2" for "1.0.0-beta.3.2"; the whole version otherwise.
  String get label {
    final m = RegExp(r'beta\.([0-9.]+)$').firstMatch(version);
    return m == null ? version : 'beta ${m.group(1)}';
  }

  /// Only FITOS's own site is ever opened; anything else falls back to the
  /// download page.
  static String safe(String? url) =>
      url != null && url.startsWith('https://tryfitos.me/')
          ? url
          : kDownloadUrl;
}

abstract class ReleaseFeed {
  /// Null when it cannot be read or is not the expected shape.
  Future<LatestRelease?> latest();
}

class HttpReleaseFeed implements ReleaseFeed {
  HttpReleaseFeed([Dio? dio])
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 6),
                receiveTimeout: const Duration(seconds: 6),
              ),
            );

  final Dio _dio;

  @override
  Future<LatestRelease?> latest() async {
    try {
      final r = await _dio.get<Object?>(kReleaseFeedUrl);
      final data = r.data;
      return LatestRelease.fromJson(
        data is String ? jsonDecode(data) : data,
      );
    } on Object {
      return null;
    }
  }
}

/// What the phone remembers between launches (trivial flags, §7.1).
abstract class UpdatePrefs {
  Future<DateTime?> lastChecked();
  Future<LatestRelease?> cached();
  Future<void> saveCheck(DateTime at, LatestRelease? release);
}

class SharedUpdatePrefs implements UpdatePrefs {
  static const _checked = 'update.checkedAt';
  static const _release = 'update.release';

  Future<SharedPreferences> get _p => SharedPreferences.getInstance();

  @override
  Future<DateTime?> lastChecked() async {
    final ms = (await _p).getInt(_checked);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  @override
  Future<LatestRelease?> cached() async {
    final s = (await _p).getString(_release);
    if (s == null) return null;
    try {
      return LatestRelease.fromJson(jsonDecode(s));
    } on Object {
      return null;
    }
  }

  @override
  Future<void> saveCheck(DateTime at, LatestRelease? release) async {
    final p = await _p;
    await p.setInt(_checked, at.millisecondsSinceEpoch);
    if (release != null) {
      await p.setString(_release, jsonEncode(release.toJson()));
    }
  }
}

abstract class LinkOpener {
  /// False when nothing could open it.
  Future<bool> open(String url);
}

class BrowserLinkOpener implements LinkOpener {
  @override
  Future<bool> open(String url) async {
    try {
      return await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } on Object {
      return false;
    }
  }
}

final releaseFeedProvider = Provider<ReleaseFeed>((_) => HttpReleaseFeed());
final updatePrefsProvider = Provider<UpdatePrefs>((_) => SharedUpdatePrefs());
final linkOpenerProvider = Provider<LinkOpener>((_) => BrowserLinkOpener());
final updateClockProvider = Provider<DateTime Function()>((_) => DateTime.now);

/// Beta 4.1 (U2): FITOS can install its own APK (Android); elsewhere, and in
/// tests unless overridden, "Update" opens the download page.
final inAppInstallProvider = Provider<bool>((_) => Platform.isAndroid);

/// A newer build than this one, and what to show for it.
class AvailableUpdate {
  const AvailableUpdate({
    required this.release,
    required this.promptDue,
    required this.bannerVisible,
  });

  final LatestRelease release;

  /// The once-per-version dialog has not been shown for this build.
  final bool promptDue;

  /// The Home banner is not hidden for this build.
  final bool bannerVisible;

  AvailableUpdate copyWith({bool? promptDue, bool? bannerVisible}) =>
      AvailableUpdate(
        release: release,
        promptDue: promptDue ?? this.promptDue,
        bannerVisible: bannerVisible ?? this.bannerVisible,
      );
}

/// Set by [UpdateController.checkNow]: the next build reads the website even
/// within [kUpdateCheckEvery]. Kept outside the notifier, which a rebuild may
/// replace.
class _ForceCheck {
  bool due = false;
}

final _forceCheckProvider = Provider<_ForceCheck>((_) => _ForceCheck());

/// Null when this is the latest build, or when nothing is known.
class UpdateController extends AsyncNotifier<AvailableUpdate?> {
  UpdatePrefs get _prefs => ref.read(updatePrefsProvider);

  @override
  Future<AvailableUpdate?> build() async {
    final own = await ref.watch(appBuildProvider.future);
    final now = ref.read(updateClockProvider)();
    final last = await _prefs.lastChecked();
    var release = await _prefs.cached();
    final force = ref.read(_forceCheckProvider);
    final forced = force.due;
    force.due = false;
    if (forced || last == null || now.difference(last) >= kUpdateCheckEvery) {
      final fresh = await ref.read(releaseFeedProvider).latest();
      if (fresh != null) release = fresh;
      // A failed read is not retried at once: offline stays quiet.
      await _prefs.saveCheck(now, fresh);
    }
    if (release == null || release.build <= own) return null;
    // Every open asks again: the dialog and the banner are due afresh each
    // time this is built (a launch, or a return after being away).
    return AvailableUpdate(
      release: release,
      promptDue: true,
      bannerVisible: true,
    );
  }

  /// Beta 3.9: read the website now, whenever it was last read — a tapped
  /// "FITOS beta N is out" push. The dialog and banner follow its answer.
  void checkNow() {
    ref.read(_forceCheckProvider).due = true;
    ref.invalidateSelf();
  }

  /// Shown for this open; it asks again the next time the app is opened.
  void markPrompted() {
    final u = state.value;
    if (u == null) return;
    state = AsyncData(u.copyWith(promptDue: false));
  }

  /// Hidden until the next open.
  void hideBanner() {
    final u = state.value;
    if (u == null) return;
    state = AsyncData(u.copyWith(bannerVisible: false));
  }

  /// Opens the download page in the browser.
  Future<bool> openDownload() {
    final u = state.value;
    return ref
        .read(linkOpenerProvider)
        .open(LatestRelease.safe(u?.release.url));
  }
}

final updateControllerProvider =
    AsyncNotifierProvider<UpdateController, AvailableUpdate?>(
  UpdateController.new,
  retry: (_, __) => null,
);

/// Coming back after [kUpdatePromptAfterAway] in the background is a new
/// open: the check runs again (the feed itself still at most every
/// [kUpdateCheckEvery]) and the dialog is due again. A quick switch — the
/// camera, a share sheet — is not. Watched once from the app root.
class UpdateCheckCoordinator {
  UpdateCheckCoordinator(this._reopened, {DateTime Function()? now})
      : _now = now ?? DateTime.now {
    _lifecycle = AppLifecycleListener(onHide: hidden, onResume: resumed);
  }

  final VoidCallback _reopened;
  final DateTime Function() _now;
  DateTime? _hiddenAt;
  late final AppLifecycleListener _lifecycle;

  @visibleForTesting
  void hidden() => _hiddenAt ??= _now();

  @visibleForTesting
  void resumed() {
    final since = _hiddenAt;
    _hiddenAt = null;
    if (since != null && _now().difference(since) >= kUpdatePromptAfterAway) {
      _reopened();
    }
  }

  void dispose() => _lifecycle.dispose();
}

final updateCheckCoordinatorProvider = Provider<UpdateCheckCoordinator>((ref) {
  final c = UpdateCheckCoordinator(
    () => ref.invalidate(updateControllerProvider),
  );
  ref.onDispose(c.dispose);
  return c;
});

/* ------------------------------------------------------------------ UI -- */

/// Shows the dialog when one is due, over whatever screen is open: it sits
/// at the app's root and opens the dialog on the root navigator. Not while
/// [suppressed] says so (a workout in progress). Renders nothing.
class UpdatePromptHost extends ConsumerStatefulWidget {
  const UpdatePromptHost({this.navigatorContext, this.suppressed, super.key});

  /// The root navigator's context; this widget's own context when null.
  final BuildContext? Function()? navigatorContext;

  /// True while the dialog must wait (it is tried again on the next build).
  final bool Function()? suppressed;

  @override
  ConsumerState<UpdatePromptHost> createState() => _UpdatePromptHostState();
}

class _UpdatePromptHostState extends ConsumerState<UpdatePromptHost> {
  bool _showing = false;

  void _maybeShow(AvailableUpdate? u) {
    if (u == null || !u.promptDue || _showing) return;
    _showing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final dialogContext = widget.navigatorContext?.call() ?? context;
      if (!mounted ||
          !dialogContext.mounted ||
          (widget.suppressed?.call() ?? false)) {
        _showing = false;
        return;
      }
      final controller = ref.read(updateControllerProvider.notifier)
        ..markPrompted();
      final inApp =
          ref.read(inAppInstallProvider) && ApkFile.of(u.release) != null;
      final update = await showDialog<bool>(
        context: dialogContext,
        builder: (ctx) => AlertDialog(
          key: const ValueKey('update.dialog'),
          title: Text('FITOS ${u.release.label} is out'),
          content: const Text(
            'A new beta with fixes and new features. It installs over this one and keeps your data.',
          ),
          actions: <Widget>[
            TextButton(
              key: const ValueKey('update.later'),
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Later'),
            ),
            FilledButton(
              key: const ValueKey('update.now'),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(inApp ? 'Update now' : 'Update'),
            ),
          ],
        ),
      );
      if ((update ?? false) && dialogContext.mounted) {
        await startUpdate(dialogContext, ref, controller);
      }
      _showing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    _maybeShow(ref.watch(updateControllerProvider).value);
    return const SizedBox.shrink();
  }
}

/// The slim banner at the very top of Home after the dialog; × hides it until
/// the next open.
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = ref.watch(updateControllerProvider).value;
    if (u == null || u.promptDue || !u.bannerVisible) {
      return const SizedBox.shrink();
    }
    final textTheme = Theme.of(context).textTheme;
    final controller = ref.read(updateControllerProvider.notifier);
    return FitBlock(
      key: const ValueKey('update.banner'),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, FitSpacing.md),
      padding: const EdgeInsets.fromLTRB(FitSpacing.md, 4, 4, 4),
      child: Row(
        children: <Widget>[
          Icon(Icons.system_update_outlined, color: FitColors.accent, size: 20),
          const SizedBox(width: FitSpacing.sm),
          Expanded(
            child: Text(
              'FITOS ${u.release.label} is out',
              style: textTheme.bodyMedium,
            ),
          ),
          TextButton(
            key: const ValueKey('update.banner.open'),
            onPressed: () => startUpdate(context, ref, controller),
            child: const Text('Update'),
          ),
          IconButton(
            key: const ValueKey('update.banner.hide'),
            tooltip: 'Hide for now',
            onPressed: controller.hideBanner,
            icon: Icon(Icons.close, size: 18, color: FitColors.ink60),
          ),
        ],
      ),
    );
  }
}

/// Beta 4.1 (U2): "Update now" — FITOS downloads, checks and hands its own
/// APK to Android's installer when it can; the download page otherwise, and
/// whenever the in-app way fails.
Future<void> startUpdate(
  BuildContext context,
  WidgetRef ref,
  UpdateController controller,
) async {
  final u = ref.read(updateControllerProvider).value;
  final file = u == null ? null : ApkFile.of(u.release);
  if (u == null || file == null || !ref.read(inAppInstallProvider)) {
    await controller.openDownload();
    return;
  }
  final flow = ApkUpdateFlow(
    file: file,
    build: u.release.build,
    downloader: ref.read(apkDownloaderProvider),
    installer: ref.read(apkInstallerProvider),
  );
  final fallback = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ApkUpdateDialog(flow: flow, label: u.release.label),
  );
  flow.dispose();
  if (fallback ?? false) await controller.openDownload();
}

/// The in-app update as it goes: Android's permission, the download with
/// Cancel, the check, and a way to the download page when anything fails.
/// Pops true for "use the download page".
class ApkUpdateDialog extends StatefulWidget {
  const ApkUpdateDialog({required this.flow, required this.label, super.key});

  final ApkUpdateFlow flow;
  final String label;

  @override
  State<ApkUpdateDialog> createState() => _ApkUpdateDialogState();
}

class _ApkUpdateDialogState extends State<ApkUpdateDialog> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    widget.flow.addListener(_changed);
    // Back from Android's settings page: carry on if it is now allowed.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (widget.flow.value is ApkNeedsPermission) widget.flow.run();
      },
    );
    widget.flow.run();
  }

  void _changed() {
    if (!mounted) return;
    final step = widget.flow.value;
    if (step is ApkHandedOver || step is ApkCancelledStep) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.flow.removeListener(_changed);
    _lifecycle.dispose();
    super.dispose();
  }

  static String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final step = widget.flow.value;
    final pop = Navigator.of(context).pop;
    return switch (step) {
      ApkNeedsPermission() => AlertDialog(
          key: const ValueKey('update.permission'),
          title: const Text('Let FITOS install its updates'),
          content: const Text(
            'Android asks once. FITOS only ever installs its own updates, '
            'downloaded from tryfitos.me and checked first. Turn on '
            '\u201cAllow from this source\u201d, then come back.',
          ),
          actions: [
            TextButton(
              onPressed: () => pop(false),
              child: const Text('Not now'),
            ),
            FilledButton(
              key: const ValueKey('update.permission.open'),
              onPressed: widget.flow.openSettings,
              child: const Text('Open settings'),
            ),
          ],
        ),
      ApkFailed(:final message) => AlertDialog(
          key: const ValueKey('update.failed'),
          title: const Text('The update did not install'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => pop(false),
              child: const Text('Close'),
            ),
            FilledButton(
              key: const ValueKey('update.failed.page'),
              onPressed: () => pop(true),
              child: const Text('Download page'),
            ),
          ],
        ),
      ApkDownloading(:final received, :final total, :final fraction) =>
        AlertDialog(
          key: const ValueKey('update.downloading'),
          title: Text('Downloading FITOS ${widget.label}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(
                key: const ValueKey('update.progress'),
                value: fraction,
              ),
              const SizedBox(height: FitSpacing.sm),
              Text(
                '${_mb(received)} of ${_mb(total)} MB',
                key: const ValueKey('update.progress.text'),
              ),
            ],
          ),
          actions: [
            TextButton(
              key: const ValueKey('update.cancel'),
              onPressed: widget.flow.cancel,
              child: const Text('Cancel'),
            ),
          ],
        ),
      _ => const AlertDialog(
          key: ValueKey('update.verifying'),
          content: Text('Checking the file\u2026'),
        ),
    };
  }
}
