import 'dart:async';
import 'dart:isolate';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/feedback/app_feedback.dart';
import '../../../../core/notifications/local_notifications.dart';
import '../../../../core/notifications/rest_countdown.dart';
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

/// Fires "Rest over" when the app is in the background; beta 6.4 (N2) also
/// shows the countdown with +15 s and Skip on the lock screen. Abstract so
/// tests and desktop runs need no plugin.
abstract class RestNotifier {
  Future<void> schedule(Duration inFuture, {required String body});

  /// The live countdown to [endsAt] (beta 6.4).
  Future<void> showCountdown(DateTime endsAt, {required String exercise});

  /// Both: "Rest over" and the countdown.
  Future<void> cancel();
}

class NoopRestNotifier implements RestNotifier {
  const NoopRestNotifier();
  @override
  Future<void> schedule(Duration inFuture, {required String body}) async {}
  @override
  Future<void> showCountdown(
    DateTime endsAt, {
    required String exercise,
  }) async {}
  @override
  Future<void> cancel() async {}
}

class LocalRestNotifier implements RestNotifier {
  LocalRestNotifier([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FitNotifications.plugin;

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

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
    await RestCountdown.scheduleOver(
      _plugin,
      DateTime.now().add(inFuture),
      body: body,
    );
  }

  @override
  Future<void> showCountdown(
    DateTime endsAt, {
    required String exercise,
  }) async {
    await _init();
    await RestCountdown.show(_plugin, endsAt, exercise: exercise);
  }

  @override
  Future<void> cancel() async {
    await _init();
    await RestCountdown.cancelAll(_plugin);
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
  ReceivePort? _actions;
  DateTime Function() _now = DateTime.now;

  @override
  RestTimerState? build() {
    _lifecycle = AppLifecycleListener(
      onHide: _onBackground,
      onShow: _onForeground,
    );
    // Beta 6.4 (N2): +15 s and Skip pressed on the lock screen.
    try {
      _actions = RestCountdown.listen(onAction);
    } on Object {
      _actions = null;
    }
    ref.onDispose(() {
      _tick?.cancel();
      _lifecycle?.dispose();
      final p = _actions;
      if (p != null) RestCountdown.stopListening(p);
    });
    return null;
  }

  /// What a lock-screen action changed: a later end, or the rest skipped.
  /// The notifications were already changed by the action itself.
  void onAction(Object? message) {
    final m = RestCountdown.readMessage(message);
    final s = state;
    if (m == null || s == null) return;
    if (m.skip) {
      _tick?.cancel();
      state = null;
      return;
    }
    final endsAt = m.endsAt!;
    state = s.copyWith(
      endsAt: endsAt,
      total: s.total + endsAt.difference(s.endsAt),
      remaining: endsAt.difference(_now()),
    );
    // A rest that had already run out ticks again.
    if (!(_tick?.isActive ?? false)) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
    }
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

  /// Hidden (locked, or another app): "Rest over" at the end, and the
  /// countdown with +15 s and Skip on the lock screen (owner Q1: only then).
  void _onBackground() {
    final s = state;
    if (s == null || s.done) return;
    _notifier
      ..schedule(
        s.endsAt.difference(_now()),
        body: 'Next set: ${s.exerciseName}',
      )
      ..showCountdown(s.endsAt, exercise: s.exerciseName);
  }

  void _onForeground() {
    _notifier.cancel();
    _refresh(quiet: true);
  }
}

final restTimerProvider =
    NotifierProvider<RestTimer, RestTimerState?>(RestTimer.new);
