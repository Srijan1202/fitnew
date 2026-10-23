import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/feedback/app_feedback.dart';
import '../../../../core/notifications/local_notifications.dart';
import '../../domain/entities/workout.dart';

/// Rest timer defaults (owner decision 8.4): 90 s after a compound, 60 s
/// after an isolation lift, a per-exercise override remembered on the
/// device — a trivial flag, so shared_preferences (§7.1).
class RestDefaults {
  const RestDefaults(this._prefs);

  final SharedPreferences? _prefs;

  static const compound = Duration(seconds: 90);
  static const isolation = Duration(seconds: 60);

  Duration forExercise(SessionExercise x) {
    final override = _prefs?.getInt('rest.${x.exerciseId}');
    if (override != null) return Duration(seconds: override);
    return x.isCompound ? compound : isolation;
  }

  Future<void> setOverride(String exerciseId, Duration d) async {
    await _prefs?.setInt('rest.$exerciseId', d.inSeconds);
  }
}

final sharedPreferencesProvider = FutureProvider<SharedPreferences>(
  (_) => SharedPreferences.getInstance(),
);

final restDefaultsProvider = Provider<RestDefaults>((ref) {
  return RestDefaults(ref.watch(sharedPreferencesProvider).value);
});

/// Fires "Rest over" when the app is in the background. Abstract so tests
/// and desktop runs need no plugin.
abstract class RestNotifier {
  Future<void> schedule(Duration inFuture, {required String body});
  Future<void> cancel();
}

class NoopRestNotifier implements RestNotifier {
  const NoopRestNotifier();
  @override
  Future<void> schedule(Duration inFuture, {required String body}) async {}
  @override
  Future<void> cancel() async {}
}

class LocalRestNotifier implements RestNotifier {
  LocalRestNotifier([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FitNotifications.plugin;

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;
  static const _id = 5001;

  Future<void> _init() async {
    if (_ready) return;
    // Phase 15: one shared set-up, so reminder taps stay routed.
    await FitNotifications.ensureInitialized();
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _ready = true;
  }

  @override
  Future<void> schedule(Duration inFuture, {required String body}) async {
    await _init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final exact = await android?.canScheduleExactNotifications() ?? false;
    await _plugin.zonedSchedule(
      _id,
      'Rest over',
      body,
      tz.TZDateTime.now(tz.UTC).add(inFuture),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'rest-timer',
          'Rest timer',
          channelDescription: 'Tells you when your rest between sets is up.',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancel() async {
    await _init();
    await _plugin.cancel(_id);
  }
}

final restNotifierProvider = Provider<RestNotifier>((_) => LocalRestNotifier());

class RestTimerState {
  const RestTimerState({
    required this.total,
    required this.endsAt,
    required this.exerciseName,
    required this.remaining,
  });

  final Duration total;
  final DateTime endsAt;
  final String exerciseName;
  final Duration remaining;

  bool get done => remaining <= Duration.zero;

  RestTimerState copyWith({
    Duration? total,
    DateTime? endsAt,
    Duration? remaining,
  }) =>
      RestTimerState(
        total: total ?? this.total,
        endsAt: endsAt ?? this.endsAt,
        exerciseName: exerciseName,
        remaining: remaining ?? this.remaining,
      );
}

/// One rest at a time. Counts down from `endsAt` (wall clock, so a minute
/// in the background is a minute), and hands the countdown to a local
/// notification while the app is not in the foreground.
class RestTimer extends Notifier<RestTimerState?> {
  Timer? _tick;
  AppLifecycleListener? _lifecycle;
  DateTime Function() _now = DateTime.now;

  @override
  RestTimerState? build() {
    _lifecycle = AppLifecycleListener(
      onHide: _onBackground,
      onShow: _onForeground,
    );
    ref.onDispose(() {
      _tick?.cancel();
      _lifecycle?.dispose();
    });
    return null;
  }

  /// Tests inject a clock.
  set clock(DateTime Function() now) => _now = now;

  RestNotifier get _notifier => ref.read(restNotifierProvider);

  void start(Duration total, {required String exerciseName}) {
    _tick?.cancel();
    final endsAt = _now().add(total);
    state = RestTimerState(
      total: total,
      endsAt: endsAt,
      exerciseName: exerciseName,
      remaining: total,
    );
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  /// Beta 3.2: a light tick at 10 s left, a chime and a buzz at zero.
  static const _soon = Duration(seconds: 10);

  /// [quiet]: back from the background, where the notification already
  /// told the user; no second alert.
  void _refresh({bool quiet = false}) {
    final s = state;
    if (s == null) return;
    final remaining = s.endsAt.difference(_now());
    if (remaining <= Duration.zero) {
      _tick?.cancel();
      state = s.copyWith(remaining: Duration.zero);
      if (!quiet && !s.done) _feedback(FeedbackEvent.restOver);
      return;
    }
    if (!quiet && s.remaining > _soon && remaining <= _soon) {
      _feedback(FeedbackEvent.restSoon);
    }
    state = s.copyWith(remaining: remaining);
  }

  void _feedback(FeedbackEvent e) => ref.read(appFeedbackProvider)(e);

  void adjust(Duration delta) {
    final s = state;
    if (s == null || s.done) return;
    final endsAt = s.endsAt.add(delta);
    final total = s.total + delta;
    state = s.copyWith(
      endsAt: endsAt,
      total: total < const Duration(seconds: 15)
          ? const Duration(seconds: 15)
          : total,
      remaining: endsAt.difference(_now()),
    );
    _refresh();
  }

  void skip() {
    _tick?.cancel();
    state = null;
    _notifier.cancel();
  }

  void _onBackground() {
    final s = state;
    if (s == null || s.done) return;
    _notifier.schedule(
      s.endsAt.difference(_now()),
      body: 'Next set: ${s.exerciseName}',
    );
  }

  void _onForeground() {
    _notifier.cancel();
    _refresh(quiet: true);
  }
}

final restTimerProvider =
    NotifierProvider<RestTimer, RestTimerState?>(RestTimer.new);
