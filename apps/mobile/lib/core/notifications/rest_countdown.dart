import 'dart:convert';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Beta 6.4 (N2, owner Q1): the rest between sets on the lock screen while
/// FITOS is hidden — a live countdown with +15 s and Skip, and "Rest over"
/// when it ends. The actions work without opening FITOS: they move or cancel
/// "Rest over", show the countdown again, and tell the session in progress
/// (through [restPortName]) when FITOS is running.
abstract final class RestCountdown {
  /// "Rest over" (Phase 5) and the countdown.
  static const overId = 5001;
  static const countdownId = 5002;

  static const addAction = 'rest-add15';
  static const skipAction = 'rest-skip';
  static const added = Duration(seconds: 15);

  /// The session in progress listens here for the actions' changes.
  static const restPortName = 'fitos.rest';

  static const _overChannel = AndroidNotificationDetails(
    'rest-timer',
    'Rest timer',
    channelDescription: 'Tells you when your rest between sets is up.',
    importance: Importance.high,
    priority: Priority.high,
  );

  /// A quiet, ongoing countdown that shows on the lock screen.
  static AndroidNotificationDetails countdownDetails(DateTime endsAt) =>
      AndroidNotificationDetails(
        'rest-countdown',
        'Rest countdown',
        channelDescription:
            'The rest between sets, with +15 s and Skip, while FITOS is hidden.',
        importance: Importance.low,
        priority: Priority.low,
        category: AndroidNotificationCategory.stopwatch,
        visibility: NotificationVisibility.public,
        ongoing: true,
        autoCancel: false,
        onlyAlertOnce: true,
        silent: true,
        showWhen: true,
        when: endsAt.millisecondsSinceEpoch,
        usesChronometer: true,
        chronometerCountDown: true,
        // Gone by itself when the rest is over ("Rest over" takes its place).
        timeoutAfter: endsAt
            .difference(DateTime.now())
            .inMilliseconds
            .clamp(1000, 1 << 30),
        actions: const [
          AndroidNotificationAction(addAction, '+15 s'),
          AndroidNotificationAction(
            skipAction,
            'Skip',
            cancelNotification: true,
          ),
        ],
      );

  /// What a countdown carries, so an action knows the rest it is about.
  static String payload(DateTime endsAt, String exercise) => jsonEncode({
        'endsAt': endsAt.millisecondsSinceEpoch,
        'exercise': exercise,
      });

  static ({DateTime endsAt, String exercise})? readPayload(String? p) {
    if (p == null) return null;
    try {
      final j = jsonDecode(p) as Map<String, dynamic>;
      return (
        endsAt: DateTime.fromMillisecondsSinceEpoch(j['endsAt'] as int),
        exercise: j['exercise'] as String? ?? '',
      );
    } on Object {
      return null;
    }
  }

  /// When the rest ends after +15 s: 15 s from the later of its end and now.
  static DateTime extended(DateTime endsAt, DateTime now) =>
      (endsAt.isAfter(now) ? endsAt : now).add(added);

  static Future<void> show(
    FlutterLocalNotificationsPlugin plugin,
    DateTime endsAt, {
    required String exercise,
  }) =>
      plugin.show(
        id: countdownId,
        title: 'Rest',
        body: exercise.isEmpty ? 'Next set soon' : 'Next set: $exercise',
        notificationDetails:
            NotificationDetails(android: countdownDetails(endsAt)),
        payload: payload(endsAt, exercise),
      );

  /// "Rest over" at [endsAt] (exact when the phone allows it).
  static Future<void> scheduleOver(
    FlutterLocalNotificationsPlugin plugin,
    DateTime endsAt, {
    required String body,
  }) async {
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final exact = await android?.canScheduleExactNotifications() ?? false;
    final wait = endsAt.difference(DateTime.now());
    await plugin.zonedSchedule(
      id: overId,
      title: 'Rest over',
      body: body,
      scheduledDate: tz.TZDateTime.now(tz.UTC)
          .add(wait.isNegative ? const Duration(seconds: 1) : wait),
      notificationDetails: const NotificationDetails(android: _overChannel),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  static Future<void> cancelAll(FlutterLocalNotificationsPlugin plugin) async {
    await plugin.cancel(id: countdownId);
    await plugin.cancel(id: overId);
  }

  /// +15 s or Skip, from the lock screen. Runs in FITOS or in the plugin's
  /// background isolate (the plugin set up already). Returns false for any
  /// other action.
  static Future<bool> handle(
    FlutterLocalNotificationsPlugin plugin,
    NotificationResponse r, {
    DateTime Function() now = DateTime.now,
  }) async {
    if (r.actionId != addAction && r.actionId != skipAction) return false;
    final rest = readPayload(r.payload);
    final port = IsolateNameServer.lookupPortByName(restPortName);
    if (r.actionId == skipAction || rest == null) {
      await cancelAll(plugin);
      port?.send(const <String, Object>{'skip': true});
      return true;
    }
    final endsAt = extended(rest.endsAt, now());
    await show(plugin, endsAt, exercise: rest.exercise);
    await scheduleOver(
      plugin,
      endsAt,
      body: rest.exercise.isEmpty
          ? 'Time for the next set'
          : 'Next set: ${rest.exercise}',
    );
    port?.send(<String, Object>{'endsAt': endsAt.millisecondsSinceEpoch});
    return true;
  }

  /// The session's end of the line: what an action changed, or null.
  static ({DateTime? endsAt, bool skip})? readMessage(Object? m) {
    if (m is! Map) return null;
    if (m['skip'] == true) return (endsAt: null, skip: true);
    final at = m['endsAt'];
    return at is int
        ? (endsAt: DateTime.fromMillisecondsSinceEpoch(at), skip: false)
        : null;
  }

  /// Listens for the actions' changes in the session in progress.
  static ReceivePort listen(void Function(Object? message) onMessage) {
    final port = ReceivePort()..listen(onMessage);
    IsolateNameServer.removePortNameMapping(restPortName);
    IsolateNameServer.registerPortWithName(port.sendPort, restPortName);
    return port;
  }

  static void stopListening(ReceivePort port) {
    IsolateNameServer.removePortNameMapping(restPortName);
    port.close();
  }
}
