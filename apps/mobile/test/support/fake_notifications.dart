import 'package:fitos/core/errors/failure.dart';
import 'package:fitos/core/errors/result.dart';
import 'package:fitos/features/notifications/data/notification_scheduler.dart';
import 'package:fitos/features/notifications/data/notifications_api.dart';
import 'package:fitos/features/notifications/domain/notifications.dart';

NotifySettings defaultNotifySettings({bool enabled = true}) => NotifySettings(
      enabled: enabled,
      tone: NotifyTone.cheeky,
      kinds: {
        for (final k in NotifyKind.values)
          k: k != NotifyKind.weighIn && k != NotifyKind.recoveryCheckin,
      },
      quietStart: '22:30',
      quietEnd: '07:30',
    );

PlannedNotification plannedItem(
  String id, {
  String kind = 'workout-reminder',
  required DateTime at,
  String localDate = '2026-10-19',
  String screen = 'plan',
  List<CancelRule> cancelOn = const [],
  String title = 'Push in an hour',
}) =>
    PlannedNotification(
      id: id,
      kind: kind,
      localDate: localDate,
      at: at,
      title: title,
      body: 'The weights will not lift themselves.',
      variant: 'wr-c6',
      tone: 'cheeky',
      screen: screen,
      slot: screen == 'food-log' ? 'dinner' : null,
      actions: const ['snooze'],
      cancelOn: cancelOn,
      why: 'About an hour before you usually train.',
    );

/// A scripted notifications server: settings as set; each plan answers
/// `nextItems` (or fails); every request is recorded.
class FakeNotificationsApi implements NotificationsApi {
  FakeNotificationsApi({NotifySettings? settings})
      : settings_ = settings ?? defaultNotifySettings();

  NotifySettings settings_;
  List<PlannedNotification> nextItems = [];
  Failure? planFailure;
  Failure? updateFailure;
  final planCalls = <List<NotifyEvent>>[];
  final patches = <Map<String, dynamic>>[];
  final tokens = <String>[];
  final previews = <NotifyKind>[];

  @override
  Future<Result<NotifySettings>> settings() async => Ok(settings_);

  @override
  Future<Result<NotifySettings>> update(Map<String, dynamic> patch) async {
    patches.add(patch);
    final f = updateFailure;
    if (f != null) return Err(f);
    final json = settings_.toJson();
    for (final e in patch.entries) {
      if (e.key == 'kinds') {
        (json['kinds'] as Map<String, dynamic>)
            .addAll(e.value as Map<String, dynamic>);
      } else {
        json[e.key] = e.value;
      }
    }
    settings_ = NotifySettings.fromJson(json);
    return Ok(settings_);
  }

  @override
  Future<Result<NotifyPlan>> plan(List<NotifyEvent> events) async {
    planCalls.add([...events]);
    final f = planFailure;
    if (f != null) return Err(f);
    return Ok(
      NotifyPlan(
        generatedAt: DateTime.utc(2026, 10, 19, 3, 30),
        timeZone: 'Asia/Kolkata',
        settings: settings_,
        items: settings_.enabled ? [...nextItems] : const [],
      ),
    );
  }

  @override
  Future<Result<({String title, String body})>> preview(NotifyKind kind) async {
    previews.add(kind);
    return const Ok(
      (title: 'Psst. Push.', body: 'The weights will not lift themselves.'),
    );
  }

  @override
  Future<Result<void>> registerToken(String token) async {
    tokens.add(token);
    return const Ok(null);
  }
}

/// Records what would be on the device.
class FakeNotificationScheduler implements NotificationScheduler {
  FakeNotificationScheduler({this.allowed = true});

  bool allowed;
  bool grantOnRequest = true;
  int requests = 0;
  final scheduled = <String, PlannedNotification>{};
  final shown = <String>[];

  @override
  Future<bool> permitted() async => allowed;

  @override
  Future<bool> requestPermission() async {
    requests++;
    allowed = grantOnRequest;
    return allowed;
  }

  @override
  Future<void> schedule(PlannedNotification item) async =>
      scheduled[item.id] = item;

  @override
  Future<void> cancel(PlannedNotification item) async =>
      scheduled.remove(item.id);

  @override
  Future<void> showNow(String title, String body) async => shown.add(title);
}
