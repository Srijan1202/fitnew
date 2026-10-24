import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/tokens.dart';
import '../../shared/widgets/fit_glass.dart';
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
const kReleaseFeedUrl = 'https://tryfitos.me/version.json';
const kDownloadUrl = 'https://tryfitos.me/download/';
const kUpdateCheckEvery = Duration(hours: 1);

/// Back in the app after at least this long away counts as opening it again.
const kUpdatePromptAfterAway = Duration(minutes: 5);

/// The latest beta as the website describes it.
class LatestRelease {
  const LatestRelease({
    required this.version,
    required this.build,
    required this.url,
    this.notesUrl,
  });

  /// Null for anything that is not the expected shape.
  static LatestRelease? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final version = json['version'];
    final build = json['build'];
    final url = json['url'];
    final notes = json['notesUrl'];
    if (version is! String || build is! int || url is! String) return null;
    return LatestRelease(
      version: version,
      build: build,
      url: url,
      notesUrl: notes is String ? notes : null,
    );
  }

  final String version;
  final int build;
  final String url;
  final String? notesUrl;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'version': version,
        'build': build,
        'url': url,
        if (notesUrl != null) 'notesUrl': notesUrl,
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

/// Null when this is the latest build, or when nothing is known.
class UpdateController extends AsyncNotifier<AvailableUpdate?> {
  UpdatePrefs get _prefs => ref.read(updatePrefsProvider);

  @override
  Future<AvailableUpdate?> build() async {
    final own = await ref.watch(appBuildProvider.future);
    final now = ref.read(updateClockProvider)();
    final last = await _prefs.lastChecked();
    var release = await _prefs.cached();
    if (last == null || now.difference(last) >= kUpdateCheckEvery) {
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
              child: const Text('Update'),
            ),
          ],
        ),
      );
      if (update ?? false) await controller.openDownload();
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
            onPressed: controller.openDownload,
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
