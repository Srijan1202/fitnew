import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/routing/router.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../community/domain/community.dart';
import '../../health/presentation/controllers/health_providers.dart';
import '../../home/presentation/controllers/home_providers.dart';
import '../../nutrition/presentation/controllers/food_log_providers.dart';
import '../../nutrition/presentation/controllers/food_logger.dart';
import '../../progress/presentation/progress_sheets.dart';
import '../../running/presentation/controllers/running_providers.dart';
import '../../training/presentation/controllers/program_controller.dart';
import '../../training/presentation/screens/training_tab_screen.dart';
import '../../water/domain/water.dart';
import '../../water/presentation/water_providers.dart';
import '../../workout/domain/entities/workout.dart';
import '../../workout/presentation/controllers/workout_providers.dart';
import '../domain/widget_snapshot.dart';

/// Beta 5.0 (owner): the home-screen widgets' side of the app.
///
///  * Whenever what they show changes (a meal, a workout or run, the plan,
///    the streak, the targets), the snapshot is written where the native
///    widgets read it and they are asked to redraw — a second after the
///    last change, so a burst writes once.
///  * A widget tap opens FITOS with `fitos://widget/<target>`; the screen
///    opens here (nothing starts without a tap there). Beta 6.2: so does an
///    invite link (`https://tryfitos.me/c/<code>`, `/u/<handle>`).
abstract class HomeWidgets {
  Future<void> save(Map<String, Object?> snapshot);

  /// The tap FITOS was opened from, once (null when none).
  Future<String?> takeLaunch();

  /// Taps while FITOS is open.
  Stream<String> get taps;

  /// Beta 6.4 (N1): glasses tapped on the widget since the last time, per
  /// day, now forgotten by the widget.
  Future<Map<String, int>> takeWater();
}

class ChannelHomeWidgets implements HomeWidgets {
  ChannelHomeWidgets() {
    _widget.setMethodCallHandler((call) async {
      if (call.method == 'open' && call.arguments is String) {
        _taps.add(call.arguments as String);
      }
    });
  }

  static const _device = MethodChannel('fitos/device');
  static const _widget = MethodChannel('fitos/widget');

  /// The shared preference the widgets read (Android stores it as
  /// `flutter.widgets.snapshot`).
  static const key = 'widgets.snapshot';

  final _taps = StreamController<String>.broadcast();

  @override
  Future<void> save(Map<String, Object?> snapshot) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(key, jsonEncode(snapshot));
      await _device.invokeMethod<void>('updateWidgets');
    } on Object {
      // The widgets keep their last picture; the next change tries again.
    }
  }

  @override
  Future<String?> takeLaunch() async {
    try {
      return await _widget.invokeMethod<String>('takeLaunch');
    } on Object {
      return null;
    }
  }

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<Map<String, int>> takeWater() async {
    try {
      final p = await SharedPreferences.getInstance();
      // The widget wrote it outside this app's cached copy.
      await p.reload();
      final taps = WidgetWater.parse(p.getString(WidgetWater.key));
      if (taps.isNotEmpty) await p.remove(WidgetWater.key);
      return taps;
    } on Object {
      return const {};
    }
  }
}

/// Android only (the widgets are Android's); tests hand in a fake.
final homeWidgetsProvider = Provider<HomeWidgets?>(
  (_) => !kIsWeb && Platform.isAndroid ? ChannelHomeWidgets() : null,
);

/// Watched from the app root.
final homeWidgetsCoordinatorProvider = Provider<void>((ref) {
  final widgets = ref.watch(homeWidgetsProvider);
  if (widgets == null) return;
  final userId = ref.watch(sessionUserIdProvider);
  Timer? pending;
  void write(Map<String, Object?> snapshot) {
    pending?.cancel();
    pending = Timer(const Duration(seconds: 1), () => widgets.save(snapshot));
  }

  ref.onDispose(() => pending?.cancel());
  if (userId == null) {
    write(WidgetSnapshot.signedOut());
    return;
  }

  final today = ref.watch(localTodayProvider);
  write(
    WidgetSnapshot.build(
      today: today,
      food: ref.watch(nutritionDayViewProvider(today)).value?.server,
      program: ref.watch(programControllerProvider).value,
      runningPlan: ref.watch(currentPlanProvider).value,
      streak: ref.watch(streakProvider).value,
      workoutDoneToday:
          ref.watch(todayProvider).value?.completedSessionId != null,
      unit: ref.watch(runSettingsProvider).unit,
      // Beta 6.4 (N1): the widget's water taps add to this.
      water: ref.watch(waterProvider).value,
    ),
  );

  // Beta 6.4 (N1, owner Q4): water tapped on the widget, now and whenever
  // FITOS comes back.
  Future<void> water() async {
    final taps = await widgets.takeWater();
    if (taps.isEmpty || !ref.mounted) return;
    await addWidgetWater(ref, taps);
  }

  unawaited(water());
  final lifecycle = AppLifecycleListener(onResume: () => unawaited(water()));
  ref.onDispose(lifecycle.dispose);

  // Taps: the one FITOS opened from, then any while open.
  final taps = widgets.taps.listen((link) => _open(ref, link));
  ref.onDispose(taps.cancel);
  unawaited(
    widgets.takeLaunch().then((link) {
      if (link != null && ref.mounted) _open(ref, link);
    }),
  );
});

/// Opens the screen a widget asked for. Beta 6.2 (C8, C15): or a
/// tryfitos.me club or friend link Android handed to FITOS (App Links),
/// which comes the same way so it waits until someone is signed in.
void _open(Ref ref, String link) {
  final invite = InviteLink.parse(link);
  if (invite != null) {
    ref.read(routerProvider).push(Routes.communityInvite, extra: invite);
    return;
  }
  final target = WidgetTarget.fromLink(link);
  if (target == null) return;
  final router = ref.read(routerProvider);
  final mode = ref.read(trainingModeProvider.notifier);
  switch (target) {
    case WidgetTarget.food:
      router
        ..go(Routes.nutrition)
        ..push(
          Routes.foodLog,
          extra: LogTarget(
            date: ref.read(localTodayProvider),
            slot: slotAt(DateTime.now().hour),
          ),
        );
    case WidgetTarget.workout:
      mode.set(TrainingMode.gym);
      router.go(Routes.plan);
    // Beta 6.4 (N1): straight into today's session, already started.
    case WidgetTarget.session:
      mode.set(TrainingMode.gym);
      unawaited(_startSession(ref));
    case WidgetTarget.run:
      mode.set(TrainingMode.running);
      router.go(Routes.plan);
    case WidgetTarget.training:
      final today = ref.read(localTodayProvider);
      final runToday = ref
              .read(currentPlanProvider)
              .value
              ?.runs
              .any((r) => r.date == today) ??
          false;
      mode.set(runToday ? TrainingMode.running : TrainingMode.gym);
      router.go(Routes.plan);
    case WidgetTarget.weight:
      router.go(Routes.today);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = router.routerDelegate.navigatorKey.currentContext;
        if (context != null) unawaited(showQuickWeightSheet(context));
      });
    case WidgetTarget.streak:
      router.go(Routes.rewards);
  }
}

/// Beta 6.4 (N1): a running session resumes; today's planned one starts and
/// opens; a rest day, a done day or no programme opens the plan.
Future<void> _startSession(Ref ref) async {
  final router = ref.read(routerProvider);
  final repo = ref.read(workoutRepositoryProvider);
  try {
    final active = await repo.activeSession();
    TodayResponse? today;
    if (active == null) {
      today = await ref.read(todayProvider.future);
    }
    if (!ref.mounted) return;
    switch (sessionStartFor(today, active: active != null)) {
      case SessionStart.resume:
        router.push(Routes.session(active!.clientSessionId));
      case SessionStart.start:
        final session = await repo.startSession(day: today);
        if (!ref.mounted) return;
        router.push(Routes.session(session.clientSessionId));
      case SessionStart.plan:
        router.go(Routes.plan);
    }
  } on Object {
    // Offline before today was ever loaded: the plan, where Start is.
    if (ref.mounted) router.go(Routes.plan);
  }
}

/// Adds the widget's glasses to their days: today through the water
/// controller (synced as any tap is), an earlier day as that day's total.
Future<void> addWidgetWater(Ref ref, Map<String, int> taps) async {
  final today = ref.read(localTodayProvider);
  for (final MapEntry(key: date, value: glasses) in taps.entries) {
    final ml = glasses * kWaterGlassMl;
    if (date == today) {
      try {
        await ref.read(waterProvider.future);
      } on Object {
        // Offline and nothing kept yet: the controller still counts it.
      }
      if (!ref.mounted) return;
      ref.read(waterProvider.notifier).add(ml);
    } else {
      await ref.read(waterProvider.notifier).addToDay(date, ml);
    }
  }
}
