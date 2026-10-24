import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The one flutter_local_notifications set-up for the app: the rest timer
/// (Phase 5) and the Phase 15 reminders share it, so a tap is always routed
/// (initialising the plugin twice would replace the tap handler).
abstract final class FitNotifications {
  static final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();
  static Future<void>? _ready;

  /// What to do with a tap on a reminder (set by the coordinator).
  static void Function(NotificationResponse response)? onTap;

  /// The reminder the app was launched from, if any (read once).
  static NotificationResponse? launchedFrom;

  static const reminderChannel = AndroidNotificationDetails(
    'fitos-reminders',
    'Reminders',
    channelDescription:
        'Workout, meal, protein, streak and weekly reminders — at most four a day.',
    importance: Importance.high,
    priority: Priority.high,
    styleInformation: BigTextStyleInformation(''),
  );

  static AndroidNotificationDetails reminderDetails({required bool snooze}) =>
      AndroidNotificationDetails(
        reminderChannel.channelId,
        reminderChannel.channelName,
        channelDescription: reminderChannel.channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: const BigTextStyleInformation(''),
        actions: snooze
            ? const [
                AndroidNotificationAction(
                  'snooze',
                  'Snooze 1 h',
                  cancelNotification: true,
                ),
              ]
            : null,
      );

  static Future<void> ensureInitialized() =>
      _ready ??= _init().catchError((Object e) {
        _ready = null;
        throw e;
      });

  static Future<void> _init() async {
    tzdata.initializeTimeZones();
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (r) {
        if (r.actionId == 'snooze') {
          snooze(r);
        } else {
          onTap?.call(r);
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationBackgroundTap,
    );
    final launch = await plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      launchedFrom = launch!.notificationResponse;
    }
  }

  /// Shows the same reminder again in an hour (the payload carries its words).
  static Future<void> snooze(NotificationResponse r) async {
    final payload = r.payload;
    if (payload == null) return;
    final p = jsonDecode(payload) as Map<String, dynamic>;
    final exact = await plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.canScheduleExactNotifications() ??
        false;
    await plugin.zonedSchedule(
      r.id ?? 0,
      p['title'] as String? ?? 'FITOS',
      p['body'] as String? ?? '',
      tz.TZDateTime.now(tz.UTC).add(const Duration(hours: 1)),
      NotificationDetails(android: reminderDetails(snooze: false)),
      payload: payload,
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
}

/// A Snooze tapped while the app is not running: a fresh isolate, so the
/// plugin and the zones are set up again before re-scheduling.
@pragma('vm:entry-point')
void notificationBackgroundTap(NotificationResponse response) {
  if (response.actionId != 'snooze') return;
  tzdata.initializeTimeZones();
  FitNotifications.plugin
      .initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      )
      .then((_) => FitNotifications.snooze(response))
      .catchError((Object e) => debugPrint('snooze failed: $e'));
}
