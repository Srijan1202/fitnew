import 'package:fitos/core/db/app_database.dart';
import 'package:fitos/features/ai/presentation/controllers/ai_providers.dart';
import 'package:fitos/features/mess/presentation/mess_providers.dart';
import 'package:fitos/features/notifications/presentation/notification_coordinator.dart';
import 'package:fitos/features/nutrition/presentation/controllers/food_log_providers.dart';
import 'package:fitos/features/progress/presentation/progress_providers.dart';
import 'package:fitos/features/recovery/presentation/recovery_providers.dart';
import 'package:fitos/features/today/presentation/today_providers.dart';
import 'package:fitos/features/workout/presentation/controllers/rest_timer.dart';
import 'package:fitos/features/workout/presentation/controllers/workout_providers.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_ai_api.dart';
import 'fake_food_log_api.dart';
import 'fake_mess_api.dart';
import 'fake_notifications.dart';
import 'fake_progress_api.dart';
import 'fake_recovery_api.dart';
import 'fake_today_api.dart';
import 'fake_workout_api.dart';

/// Everything a widget test needs so the workout feature runs on an
/// in-memory database against the fake server, with no platform plugins:
/// no path_provider, no connectivity, no notifications.
List<Override> workoutOverrides(
  AppDatabase db,
  FakeWorkoutApi api, {
  FakeFoodLogApi? foodLog,
  FakeMessApi? mess,
  FakeTodayApi? today,
  FakeProgressApi? progress,
  FakeRecoveryApi? recovery,
  FakeAiApi? ai,
  FakeNotificationsApi? notifications,
  FakeNotificationScheduler? scheduler,
}) {
  SharedPreferences.setMockInitialValues(const {});
  return [
    appDatabaseProvider.overrideWithValue(db),
    workoutApiProvider.overrideWithValue(api),
    connectivityStreamProvider.overrideWithValue(const Stream.empty()),
    restNotifierProvider.overrideWithValue(const NoopRestNotifier()),
    // Widget tests drive the queue by hand on a fake clock; the engine's own
    // retries are covered with real timers in automatic_sync_test.dart.
    syncWakesItselfProvider.overrideWithValue(false),
    // Phase 8: the nutrition feature (Home reads today's food) talks to a
    // scripted server too, never the network.
    foodLogApiProvider.overrideWithValue(foodLog ?? FakeFoodLogApi()),
    // Phase 9: mess menus from a scripted server; no mess unless a test says.
    messApiProvider.overrideWithValue(mess ?? FakeMessApi(mine: null)),
    // Phase 11: TODAY from a scripted server; no actions unless a test says.
    todayApiProvider.overrideWithValue(today ?? FakeTodayApi()),
    // Phase 12: Progress from a scripted server; an empty history unless a test says.
    progressApiProvider.overrideWithValue(progress ?? FakeProgressApi()),
    // Phase 13: Recovery from a scripted server; nothing checked in unless a test says.
    recoveryApiProvider.overrideWithValue(recovery ?? FakeRecoveryApi()),
    // Phase 14: FITOS AI switched off unless a test says, so no AI entry
    // point (Describe your meal, Explain simply) appears by default.
    aiApiProvider.overrideWithValue(ai ?? FakeAiApi.off()),
    // Phase 15: a scripted plan server and a recording device; no FCM.
    notificationsApiProvider
        .overrideWithValue(notifications ?? FakeNotificationsApi()),
    notificationSchedulerProvider
        .overrideWithValue(scheduler ?? FakeNotificationScheduler()),
    pushTokenSourceProvider.overrideWithValue(() async => null),
  ];
}
