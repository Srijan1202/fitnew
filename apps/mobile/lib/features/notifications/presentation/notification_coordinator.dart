import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/notifications/activity_signal.dart';
import '../../../core/notifications/local_notifications.dart';
import '../../../core/routing/router.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../auth/presentation/controllers/auth_providers.dart';
import '../../health/presentation/controllers/health_providers.dart';
import '../../nutrition/domain/entities/food_log.dart';
import '../../nutrition/presentation/controllers/food_log_providers.dart';
import '../../nutrition/presentation/controllers/food_logger.dart';
import '../data/notification_scheduler.dart';
import '../data/notifications_api.dart';
import '../domain/notifications.dart';

final notificationsApiProvider = Provider<NotificationsApi>(
  (ref) => DioNotificationsApi(ref.watch(dioProvider)),
);

final notificationSchedulerProvider =
    Provider<NotificationScheduler>((_) => LocalNotificationScheduler());

/// The clock (tests pin it).
final notifyClockProvider = Provider<DateTime Function()>((_) => DateTime.now);

/// Today's protein so far (the server's day, high end) for [date], or null.
final notifyProteinSourceProvider =
    Provider<Future<double?> Function(String date)>((ref) {
  final repo = ref.watch(nutritionLogRepositoryProvider);
  return (date) async =>
      (await repo.watchDay(date).first).server?.totals.proteinHigh;
});

/// Fires when the food-log queue has delivered (the server day is fresh).
final notifyDrainedProvider = Provider<Stream<void>>(
  (ref) => ref.watch(nutritionLogRepositoryProvider).drained,
);

/// This device's FCM token, or null (no Play services, or not allowed).
final pushTokenSourceProvider = Provider<Future<String?> Function()>(
  (_) => () async {
    try {
      // firebase_messaging 17 prefers register()/onRegistered, which yields
      // an installation id (FID), not this FCM token. Server push (BACKLOG
      // O9) is not built yet; it moves to the FID with it.
      // ignore: deprecated_member_use
      return await FirebaseMessaging.instance.getToken();
    } on Object {
      return null;
    }
  },
);

/// What the phone remembers about the plan between launches.
class _Stored {
  _Stored({
    this.items = const [],
    Set<String>? cancelled,
    Set<String>? reported,
    List<NotifyEvent>? pending,
    Set<String>? happened,
    this.permitted = false,
  })  : cancelled = cancelled ?? <String>{},
        reported = reported ?? <String>{},
        pending = pending ?? <NotifyEvent>[],
        happened = happened ?? <String>{};

  factory _Stored.fromJson(Map<String, dynamic> j) => _Stored(
        items: [
          for (final i in j['items'] as List<dynamic>)
            PlannedNotification.fromJson(i as Map<String, dynamic>),
        ],
        cancelled: {...(j['cancelled'] as List<dynamic>).cast<String>()},
        reported: {...(j['reported'] as List<dynamic>).cast<String>()},
        pending: [
          for (final e in j['pending'] as List<dynamic>)
            NotifyEvent.fromJson(e as Map<String, dynamic>),
        ],
        happened: {
          ...(j['happened'] as List<dynamic>? ?? const []).cast<String>(),
        },
        permitted: j['permitted'] as bool? ?? false,
      );

  List<PlannedNotification> items;
  final Set<String> cancelled;
  final Set<String> reported;
  final List<NotifyEvent> pending;

  /// Beta 3.5: what the user did ("event|day" and "event|day|slot"), so a
  /// plan fetched before the server knows (a session not yet synced) never
  /// brings back a reminder it made pointless. Kept for a few days.
  final Set<String> happened;

  /// Whether the items were put on the device (so a past one was shown).
  bool permitted;

  Map<String, dynamic> toJson() => {
        'items': [for (final i in items) i.toJson()],
        'cancelled': [...cancelled],
        'reported': [...reported],
        'pending': [for (final e in pending) e.toJson()],
        'happened': [...happened],
        'permitted': permitted,
      };
}

class NotifyState {
  const NotifyState({this.plan, this.failure, this.permitted});

  /// The plan on the device (null before the first one).
  final NotifyPlan? plan;
  final Failure? failure;

  /// Whether Android lets FITOS show notifications (null: not checked yet).
  final bool? permitted;

  /// What is still ahead and not cancelled, soonest first.
  List<PlannedNotification> upcoming(
    DateTime now,
    Set<String> cancelled,
  ) =>
      [
        for (final i in plan?.items ?? const <PlannedNotification>[])
          if (i.at.isAfter(now) && !cancelled.contains(i.id)) i,
      ];
}

/// Phase 15 (ADR-021): keeps the server's notification plan on the device.
///
///  * On sign-in, launch and every resume it reports what happened to the
///    last plan (shown, opened, cancelled), fetches the next one, and
///    schedules it — replacing the previous items.
///  * When the user does something a reminder was for ([ActivitySignal],
///    or protein reaching the target once the food queue delivers), the
///    matching reminders are cancelled at once, offline too, and a fresh
///    plan is asked for.
///  * A tap opens the screen the reminder was about.
///
/// Nothing here decides what to send or when: that is core `notify/`.
class NotificationCoordinator extends Notifier<NotifyState> {
  _Stored _stored = _Stored();
  String? _userId;
  bool _busy = false;
  bool _again = false;
  Timer? _debounce;
  final Set<String> _cancelledNow = {};

  NotificationsApi get _api => ref.read(notificationsApiProvider);
  NotificationScheduler get _scheduler =>
      ref.read(notificationSchedulerProvider);
  DateTime _now() => ref.read(notifyClockProvider)();

  /// The ids cancelled on the phone for the current plan.
  Set<String> get cancelled => {..._stored.cancelled};

  @override
  NotifyState build() {
    final userId = ref.watch(sessionUserIdProvider);
    _userId = userId;
    if (userId == null) return const NotifyState();

    final activity = ActivitySignal.stream.listen(onActivity);
    final drained =
        ref.read(notifyDrainedProvider).listen((_) => checkProtein());
    final lifecycle =
        AppLifecycleListener(onResume: () => unawaited(refresh()));
    FitNotifications.onTap = (r) => unawaited(onTap(r.payload));
    ref.onDispose(() {
      activity.cancel();
      drained.cancel();
      lifecycle.dispose();
      _debounce?.cancel();
      if (FitNotifications.onTap != null) FitNotifications.onTap = null;
    });

    Future.microtask(() async {
      await _load(userId);
      final launched = FitNotifications.launchedFrom;
      if (launched != null) {
        FitNotifications.launchedFrom = null;
        await onTap(launched.payload);
      }
      await refresh();
      await _registerToken();
    });
    return const NotifyState();
  }

  String get _key => 'notify.plan.$_userId';

  Future<void> _load(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('notify.plan.$userId');
      if (raw != null) {
        _stored = _Stored.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } on Object {
      _stored = _Stored();
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(_stored.toJson()));
    } on Object {
      // A lost save costs one report, never a reminder.
    }
  }

  Future<void> _registerToken() async {
    final token = await ref.read(pushTokenSourceProvider)();
    if (token != null && ref.mounted) await _api.registerToken(token);
  }

  /// The local day of [at] in the user's calendar.
  String _dayOf(DateTime at) {
    final local =
        tz.TZDateTime.from(at, userLocation(ref.read(userTimezoneProvider)));
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd';
  }

  /// Report, fetch, replace. Offline it keeps the plan already on the device.
  Future<void> refresh() async {
    if (_userId == null) return;
    if (_busy) {
      _again = true;
      return;
    }
    _busy = true;
    try {
      final now = _now();
      // Opening the app is what the comeback reminders wait for.
      await _cancelWhere((r) => r.event == 'app-opened');
      if (_stored.permitted) {
        for (final i in _stored.items) {
          if (!i.at.isAfter(now) &&
              !_stored.cancelled.contains(i.id) &&
              !_stored.reported.contains(i.id)) {
            _stored.reported.add(i.id);
            _stored.pending
                .add(NotifyEvent(id: i.id, event: 'delivered', at: i.at));
          }
        }
      }
      await _save();

      final sent = [..._stored.pending];
      final r = await _api.plan(sent);
      if (!ref.mounted) return;
      switch (r) {
        case Ok(:final value):
          final permitted = await _permission(ask: value.items.isNotEmpty);
          for (final old in _stored.items) {
            if (old.at.isAfter(now)) await _scheduler.cancel(old);
          }
          // Beta 3.5: never re-schedule what the user already did today, even
          // if the server has not heard of it yet (it is told as cancelled).
          final met = <String>{
            for (final item in value.items)
              if (item.cancelOn.any(_alreadyMet)) item.id,
          };
          final told = {
            for (final e in sent)
              if (e.event == 'cancelled') e.id,
          };
          if (permitted) {
            for (final item in value.items) {
              if (!met.contains(item.id)) await _scheduler.schedule(item);
            }
          }
          _stored = _Stored(
            items: value.items,
            permitted: permitted,
            cancelled: met,
            happened: _stored.happened,
            pending: [
              for (final e in _stored.pending)
                if (!sent.contains(e)) e,
              for (final id in met)
                if (!told.contains(id))
                  NotifyEvent(id: id, event: 'cancelled', at: _now()),
            ],
          );
          _cancelledNow.clear();
          await _save();
          state = NotifyState(plan: value, permitted: permitted);
        case Err(:final failure):
          state = NotifyState(
            plan: state.plan,
            failure: failure,
            permitted: state.permitted,
          );
      }
    } finally {
      _busy = false;
      if (_again && ref.mounted) {
        _again = false;
        unawaited(refresh());
      }
    }
  }

  /// Asks once by itself (Android 13+); the settings screen can ask again.
  Future<bool> _permission({required bool ask}) async {
    if (await _scheduler.permitted()) return true;
    if (!ask) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('notify.asked') ?? false) return false;
      await prefs.setBool('notify.asked', true);
    } on Object {
      return false;
    }
    return _scheduler.requestPermission();
  }

  /// Phase 17: the account was deleted — nothing of it stays on the phone:
  /// every scheduled reminder is cancelled and the stored plan forgotten.
  Future<void> forgetAll() async {
    for (final i in _stored.items) {
      await _scheduler.cancel(i);
    }
    _stored = _Stored();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } on Object {
      // Prefs are wiped wholesale by the caller as well.
    }
    state = const NotifyState();
  }

  /// The settings screen's "Allow notifications".
  Future<bool> askPermission() async {
    final ok = await _scheduler.requestPermission();
    if (ok) {
      // A plan fetched without permission was never scheduled.
      _stored.permitted = false;
      await refresh();
    } else {
      state = NotifyState(plan: state.plan, permitted: false);
    }
    return ok;
  }

  Future<void> _cancelWhere(bool Function(CancelRule r) match) async {
    var changed = false;
    for (final i in _stored.items) {
      if (_stored.cancelled.contains(i.id) || _stored.reported.contains(i.id)) {
        continue;
      }
      if (!i.cancelOn.any(match)) continue;
      await _scheduler.cancel(i);
      _stored.cancelled.add(i.id);
      _cancelledNow.add(i.id);
      _stored.pending
          .add(NotifyEvent(id: i.id, event: 'cancelled', at: _now()));
      changed = true;
    }
    if (changed) {
      await _save();
      state = NotifyState(
        plan: state.plan,
        failure: state.failure,
        permitted: state.permitted,
      );
    }
  }

  /// Whether [r] is already met by something the user did on its day.
  bool _alreadyMet(CancelRule r) =>
      _stored.happened.contains('${r.event}|${r.localDate}') ||
      (r.event == 'food-logged' &&
          r.slot != null &&
          _stored.happened.contains('food-logged|${r.localDate}|${r.slot}')) ||
      (r.event == 'any-activity' &&
          _stored.happened.any((h) => h.split('|')[1] == r.localDate));

  /// Something the user did: cancel the reminders it makes pointless.
  Future<void> onActivity(Activity a) async {
    if (_userId == null) return;
    final day = _dayOf(a.at);
    // Beta 3.5: remembered, so a later plan cannot re-schedule them. A meal
    // log only meets its own meal's rule.
    final slot = a.kind == ActivityKind.foodLogged ? a.slot : null;
    _stored.happened
      ..removeWhere(
        (h) =>
            h
                .split('|')[1]
                .compareTo(_dayOf(_now().subtract(const Duration(days: 3)))) <
            0,
      )
      ..add(slot == null ? '${a.kind.wire}|$day' : '${a.kind.wire}|$day|$slot');
    await _cancelWhere(
      (r) =>
          r.localDate == day &&
          (r.event == 'any-activity' ||
              (r.event == a.kind.wire &&
                  (r.slot == null || slot == null || r.slot == slot))),
    );
    if (a.kind == ActivityKind.foodLogged) unawaited(checkProtein());
    // A fresh plan (a weigh-in moves the next one, a session the streak…).
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), () => unawaited(refresh()));
  }

  /// Protein on track for today: the protein nudge goes.
  Future<void> checkProtein() async {
    if (_userId == null) return;
    final today = _dayOf(_now());
    final rules = [
      for (final i in _stored.items)
        for (final r in i.cancelOn)
          if (r.event == 'protein-reached' && r.localDate == today) r,
    ];
    if (rules.isEmpty) return;
    final high = await ref.read(notifyProteinSourceProvider)(today);
    if (high == null) return;
    await _cancelWhere(
      (r) =>
          r.event == 'protein-reached' &&
          r.localDate == today &&
          r.grams != null &&
          high >= r.grams!,
    );
  }

  /// A tap: report it opened and go where it points.
  Future<void> onTap(String? payload) async {
    if (payload == null) return;
    final p = jsonDecode(payload) as Map<String, dynamic>;
    final id = p['id'] as String?;
    if (id != null && !_stored.reported.contains(id)) {
      _stored.reported.add(id);
      _stored.pending.add(NotifyEvent(id: id, event: 'opened', at: _now()));
      await _save();
    }
    if (!ref.mounted) return;
    final router = ref.read(routerProvider);
    switch (p['screen']) {
      case 'plan':
        router.go(Routes.plan);
      case 'progress':
        router.go(Routes.progress);
      case 'food-log':
        router
          ..go(Routes.nutrition)
          ..push(
            Routes.foodLog,
            extra: LogTarget(
              date: p['localDate'] as String? ?? _dayOf(_now()),
              // Beta 3.6: a meal reminder opens its own meal (the protein
              // nudge is about dinner).
              slot: p['slot'] is String
                  ? MealSlot.fromWire(p['slot'] as String)
                  : MealSlot.dinner,
            ),
          );
      default:
        router.go(Routes.today);
    }
  }
}

final notificationCoordinatorProvider =
    NotifierProvider<NotificationCoordinator, NotifyState>(
  NotificationCoordinator.new,
);

/// Settings, read and changed through the server (they shape the plan).
final notifySettingsProvider = FutureProvider<NotifySettings>(
  (ref) async {
    requireSession(ref);
    final r = await ref.watch(notificationsApiProvider).settings();
    return r.when(ok: (s) => s, err: (f) => throw f);
  },
  retry: (_, __) => null,
);
