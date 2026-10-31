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
import '../../health/presentation/controllers/health_providers.dart';
import '../../home/presentation/controllers/home_providers.dart';
import '../../nutrition/presentation/controllers/food_log_providers.dart';
import '../../nutrition/presentation/controllers/food_logger.dart';
import '../../progress/presentation/progress_sheets.dart';
import '../../running/presentation/controllers/running_providers.dart';
import '../../training/presentation/controllers/program_controller.dart';
import '../../training/presentation/screens/training_tab_screen.dart';
import '../../workout/presentation/controllers/workout_providers.dart';
import '../domain/widget_snapshot.dart';

/// Beta 5.0 (owner): the home-screen widgets' side of the app.
///
///  * Whenever what they show changes (a meal, a workout or run, the plan,
///    the streak, the targets), the snapshot is written where the native
///    widgets read it and they are asked to redraw — a second after the
///    last change, so a burst writes once.
///  * A widget tap opens FITOS with `fitos://widget/<target>`; the screen
///    opens here (nothing starts without a tap there).
abstract class HomeWidgets {
  Future<void> save(Map<String, Object?> snapshot);

  /// The tap FITOS was opened from, once (null when none).
  Future<String?> takeLaunch();

  /// Taps while FITOS is open.
  Stream<String> get taps;
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
    ),
  );

  // Taps: the one FITOS opened from, then any while open.
  final taps = widgets.taps.listen((link) => _open(ref, link));
  ref.onDispose(taps.cancel);
  unawaited(
    widgets.takeLaunch().then((link) {
      if (link != null && ref.mounted) _open(ref, link);
    }),
  );
});

/// Opens the screen a widget asked for.
void _open(Ref ref, String link) {
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
