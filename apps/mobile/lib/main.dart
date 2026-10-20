import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/device_time_zone.dart';
import 'core/config/env.dart';
import 'core/config/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase owns credentials (§11). Options come from --dart-define so a
  // build without them is a clear splash-screen message, not a native crash.
  // A hosted build with a disallowed API address stops there too (Phase 6.7).
  if (Env.ready) {
    await Firebase.initializeApp(options: FirebaseConfig.android);
  }

  // The phone's IANA zone, for sign-in and Profile (never blocks: null on failure).
  await DeviceTimeZone.load();

  // Riverpod is the only DI container (§7.1) — a second one would be redundant.
  runApp(const ProviderScope(child: FitOSApp()));
}
