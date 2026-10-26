import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/notifications/local_notifications.dart';
import '../domain/notifications.dart';

/// Puts planned reminders on the device. Abstract so widget tests and
/// desktop runs need no plugin.
abstract class NotificationScheduler {
  Future<bool> permitted();

  /// Android 13+: the system prompt. True when allowed.
  Future<bool> requestPermission();

  Future<void> schedule(PlannedNotification item);
  Future<void> cancel(PlannedNotification item);

  /// Shows a notification now (the settings "Try it").
  Future<void> showNow(String title, String body);

  /// A stable int id for a plan item (the plugin's ids are ints).
  static int idOf(String uuid) =>
      100000 + int.parse(uuid.replaceAll('-', '').substring(0, 7), radix: 16);

  /// What a tap or Snooze needs to act without the plan at hand.
  static String payloadOf(PlannedNotification item) => jsonEncode({
        'id': item.id,
        'screen': item.screen,
        'slot': item.slot,
        'localDate': item.localDate,
        'title': item.title,
        'body': item.body,
      });
}

class LocalNotificationScheduler implements NotificationScheduler {
  FlutterLocalNotificationsPlugin get _plugin => FitNotifications.plugin;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<bool> permitted() async {
    await FitNotifications.ensureInitialized();
    return await _android?.areNotificationsEnabled() ?? false;
  }

  @override
  Future<bool> requestPermission() async {
    await FitNotifications.ensureInitialized();
    return await _android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> schedule(PlannedNotification item) async {
    await FitNotifications.ensureInitialized();
    final exact = await _android?.canScheduleExactNotifications() ?? false;
    await _plugin.zonedSchedule(
      id: NotificationScheduler.idOf(item.id),
      title: item.title,
      body: item.body,
      scheduledDate: tz.TZDateTime.from(item.at.toUtc(), tz.UTC),
      notificationDetails: NotificationDetails(
        android: FitNotifications.reminderDetails(
          snooze: item.actions.contains('snooze'),
        ),
      ),
      payload: NotificationScheduler.payloadOf(item),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancel(PlannedNotification item) async {
    await FitNotifications.ensureInitialized();
    await _plugin.cancel(id: NotificationScheduler.idOf(item.id));
  }

  @override
  Future<void> showNow(String title, String body) async {
    await FitNotifications.ensureInitialized();
    await _plugin.show(
      id: 99999,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: FitNotifications.reminderDetails(snooze: false),
      ),
    );
  }
}
