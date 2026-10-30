import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/env.dart';
import '../../../core/config/firebase_options.dart';
import '../../../core/errors/result.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/notifications/local_notifications.dart';
import '../../auth/data/firebase_auth_data_source.dart';
import '../../health/data/health_connect_channel.dart';
import '../domain/units.dart';
import 'running_api.dart';
import 'watch_import.dart';

/// Beta 4.9 (owner): Galaxy Watch runs come in without opening FITOS.
///
/// Android's WorkManager wakes the app every 6 hours (any network, battery
/// not low) while the Running switch is on and Health Connect lets FITOS
/// read in the background. The native worker (WatchImportWorker.kt) starts
/// [watchImportInBackground] without a screen; it imports through the same
/// [WatchImporter] — once, not doubled — and says when it is done.
///
/// No database is opened here (the app may have it open): the phone runs
/// to leave out are the server's latest page. A phone run not uploaded yet
/// is the one gap, and Running opening closes it as before.
abstract final class WatchBackground {
  static const _device = MethodChannel('fitos/device');
  static const _done = MethodChannel('fitos/background');

  static const _userKey = 'running.watchImport.user';
  static const _notifiedKey = 'running.watchImport.notified';

  /// The notification's id: one at a time, the newest replacing the last.
  static const notificationId = 4900;

  /// Turns the 6-hourly import on or off (the switch, and whether Health
  /// Connect allows background reads). Never throws.
  static Future<void> schedule({required bool on}) async {
    try {
      await _device.invokeMethod<void>('scheduleWatchImport', on);
    } on Object {
      // Not Android, or an older build: imports stay on Running opening.
    }
  }

  /// Who the background import runs as: the FITOS user and their Firebase
  /// uid, kept when Running imports with the app open.
  static Future<void> remember({
    required String userId,
    required String? firebaseUid,
  }) async {
    try {
      final p = await SharedPreferences.getInstance();
      if (firebaseUid == null) {
        await p.remove(_userKey);
      } else {
        await p.setString(_userKey, '$userId $firebaseUid');
      }
    } on Object {
      // The background import waits for the next time.
    }
  }

  /// "Watch run added: 5.2 km · 26:10", or "3 watch runs added".
  static String message(List<WatchRun> runs, DistanceUnit unit) {
    if (runs.length != 1) return '${runs.length} watch runs added';
    final w = runs.single;
    return 'Watch run added: ${formatDistance(w.metres, unit)} ${unit.label} · '
        '${formatDuration(w.movingSeconds)}';
  }

  /// Whether a notification may go out today (at most one a day), and if so
  /// marks today used.
  static Future<bool> takeToday(SharedPreferences p, DateTime now) async {
    final day = '${now.year}-${now.month}-${now.day}';
    if (p.getString(_notifiedKey) == day) return false;
    await p.setString(_notifiedKey, day);
    return true;
  }

  /// One import, as the user Running last imported as. Returns what came in.
  static Future<WatchImportResult?> importOnce({
    required WatchRunSource source,
    required RunningApi api,
    required String? Function() currentUid,
  }) async {
    final p = await SharedPreferences.getInstance();
    if (!(p.getBool('running.watchImport') ?? true)) return null;
    final who = (p.getString(_userKey) ?? '').split(' ');
    if (who.length != 2 || who[1] != currentUid()) return null;
    final phoneRuns = switch (await api.runs()) {
      Ok(:final value) => value.runs,
      // Offline: nothing to compare with, so nothing is sent this time.
      Err() => null,
    };
    if (phoneRuns == null) return null;
    return WatchImporter(source: source, api: api, userId: who[0])
        .run(phoneRuns);
  }
}

/// The native worker's entry point (see `main.dart`): sign-in from Firebase,
/// one import, at most one quiet notification a day, then "done".
Future<void> watchImportInBackground() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (!Env.ready) return;
    await Firebase.initializeApp(options: FirebaseConfig.android);
    final credentials = FirebaseCredentialSource();
    // Firebase restores the session as it starts; wait for it briefly.
    if (credentials.currentUid == null) {
      await credentials
          .uidChanges()
          .firstWhere((u) => u != null)
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
    }
    final result = await WatchBackground.importOnce(
      source: const HealthConnectWatchSource(MethodChannelHealthConnect()),
      api: DioRunningApi(buildDio(credentials)),
      currentUid: () => credentials.currentUid,
    );
    if (result == null || result.added.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    if (!await WatchBackground.takeToday(p, DateTime.now())) return;
    final unit = p.getString('running.unit') == DistanceUnit.mi.name
        ? DistanceUnit.mi
        : DistanceUnit.km;
    await FitNotifications.ensureInitialized();
    await FitNotifications.plugin.show(
      id: WatchBackground.notificationId,
      title: 'FITOS',
      body: WatchBackground.message(result.added, unit),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          FitNotifications.reminderChannel.channelId,
          FitNotifications.reminderChannel.channelName,
          channelDescription:
              FitNotifications.reminderChannel.channelDescription,
          importance: Importance.low,
          priority: Priority.low,
        ),
      ),
    );
  } on Object {
    // Tried again in 6 hours, or when Running opens.
  } finally {
    try {
      await WatchBackground._done.invokeMethod<void>('done');
    } on Object {
      // The worker's own time limit ends it.
    }
  }
}
