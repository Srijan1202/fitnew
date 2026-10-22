import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 19 (ADR-026, owner 2026-10-22): crash reports to Firebase
/// Crashlytics, on unless the user turns them off in Privacy & data.
///
/// A report holds the error, the stack, the app version and the phone's
/// model — never an account, health, food or workout value: the app sets no
/// user identifier and no custom keys. Turning reports off also deletes any
/// report not yet sent. Debug builds never report.
abstract class CrashReporter {
  Future<void> setEnabled(bool enabled);
  void recordFlutterError(FlutterErrorDetails details);
  void recordError(Object error, StackTrace stack);
}

/// Firebase Crashlytics. Collection stays off (AndroidManifest) until
/// [setEnabled] applies the user's choice at start-up.
class CrashlyticsReporter implements CrashReporter {
  CrashlyticsReporter([FirebaseCrashlytics? crashlytics])
      : _crashlytics = crashlytics ?? FirebaseCrashlytics.instance;

  final FirebaseCrashlytics _crashlytics;
  bool _enabled = false;

  @override
  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    await _crashlytics.setCrashlyticsCollectionEnabled(enabled);
    if (!enabled) await _crashlytics.deleteUnsentReports();
  }

  @override
  void recordFlutterError(FlutterErrorDetails details) {
    if (_enabled) _crashlytics.recordFlutterFatalError(details);
  }

  @override
  void recordError(Object error, StackTrace stack) {
    if (_enabled) _crashlytics.recordError(error, stack, fatal: true);
  }
}

/// No Firebase (a build without it, debug builds, tests): nothing is sent.
class NoCrashReporter implements CrashReporter {
  bool enabled = false;

  @override
  Future<void> setEnabled(bool enabled) async => this.enabled = enabled;

  @override
  void recordFlutterError(FlutterErrorDetails details) {}

  @override
  void recordError(Object error, StackTrace stack) {}
}

/// main() overrides this with the real reporter when Firebase is ready.
final crashReporterProvider = Provider<CrashReporter>((_) => NoCrashReporter());

/// The user's choice, kept on this phone (a trivial flag, §7.1). On unless
/// turned off; deleting the account wipes it back to the default.
const kCrashReportsPreference = 'crash_reports_enabled';

Future<bool> crashReportsEnabled() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kCrashReportsPreference) ?? true;
  } on Object {
    return true;
  }
}

class CrashReportsController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => crashReportsEnabled();

  Future<void> set(bool enabled) async {
    state = AsyncData(enabled);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kCrashReportsPreference, enabled);
    } on Object {
      // The choice still applies for this run.
    }
    await ref.read(crashReporterProvider).setEnabled(enabled);
  }
}

final crashReportsProvider =
    AsyncNotifierProvider<CrashReportsController, bool>(
  CrashReportsController.new,
);

/// Wires the reporter into Flutter's two error paths. Called once by main().
Future<void> installCrashReporting(CrashReporter reporter) async {
  await reporter.setEnabled(await crashReportsEnabled());
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    reporter.recordFlutterError(details);
    previous?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    reporter.recordError(error, stack);
    return true;
  };
}
