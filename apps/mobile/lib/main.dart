import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/device_time_zone.dart';
import 'core/config/env.dart';
import 'core/config/firebase_options.dart';
import 'core/diagnostics/crash_reporting.dart';
import 'core/theme/theme_controller.dart';
import 'features/running/data/watch_background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase owns credentials (§11). Options come from --dart-define so a
  // build without them is a clear splash-screen message, not a native crash.
  // A hosted build with a disallowed API address stops there too (Phase 6.7).
  CrashReporter reporter = NoCrashReporter();
  if (Env.ready) {
    await Firebase.initializeApp(options: FirebaseConfig.android);
    // Phase 19 (ADR-026): crash reports, unless the user turned them off.
    // Never from a debug build.
    if (!kDebugMode) reporter = CrashlyticsReporter();
  }
  await installCrashReporting(reporter);

  // Phase 19: open in the theme chosen last time (FITOS Dark by default).
  await loadSavedPalette();

  // The phone's IANA zone, for sign-in and Profile (never blocks: null on failure).
  await DeviceTimeZone.load();

  // Riverpod is the only DI container (§7.1) — a second one would be redundant.
  runApp(
    ProviderScope(
      overrides: [crashReporterProvider.overrideWithValue(reporter)],
      child: const FitOSApp(),
    ),
  );
}

/// Beta 4.9: the native WatchImportWorker starts this without a screen —
/// one Galaxy Watch import (watch_background.dart).
@pragma('vm:entry-point')
Future<void> watchImportMain() => watchImportInBackground();
