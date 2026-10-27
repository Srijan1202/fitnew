import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fitos/core/config/app_config.dart';
import 'package:fitos/core/db/app_database.dart';
import 'package:fitos/features/feedback/presentation/feedback_screen.dart';
import 'package:fitos/features/premium/presentation/premium_providers.dart';
import 'package:fitos/features/progress/presentation/weekly_report_screen.dart';
import 'package:fitos/features/ai/presentation/controllers/ai_providers.dart';
import 'package:fitos/features/mess/presentation/mess_providers.dart';
import 'package:fitos/features/notifications/presentation/notification_coordinator.dart';
import 'package:fitos/features/privacy/presentation/privacy_providers.dart';
import 'package:fitos/features/nutrition/presentation/controllers/food_log_providers.dart';
import 'package:fitos/features/progress/presentation/progress_providers.dart';
import 'package:fitos/features/recovery/presentation/recovery_providers.dart';
import 'package:fitos/features/today/presentation/today_providers.dart';
import 'package:fitos/features/workout/presentation/controllers/rest_timer.dart';
import 'package:fitos/features/workout/presentation/controllers/workout_providers.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_ai_api.dart';
import 'fake_feedback_api.dart';
import 'fake_premium_api.dart';
import 'fake_food_log_api.dart';
import 'fake_mess_api.dart';
import 'fake_notifications.dart';
import 'fake_privacy_api.dart';
import 'fake_progress_api.dart';
import 'fake_recovery_api.dart';
import 'fake_today_api.dart';
import 'fake_workout_api.dart';
import 'fake_streak_api.dart';
import 'package:fitos/features/home/presentation/controllers/home_providers.dart';
import 'fake_rewards_api.dart';
import 'fake_running.dart';
import 'package:fitos/features/running/presentation/controllers/running_providers.dart';
import 'package:fitos/features/premium/presentation/rewards_providers.dart';

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
  FakePrivacyApi? privacy,
  Stream<List<ConnectivityResult>>? connectivity,
  FakeFeedbackApi? feedback,
  FakeMetaApi? meta,
  int appBuild = 4,
  FakePremiumApi? premium,
  FakeWeeklyReportApi? weekly,
  FakeStreakApi? streak,
  FakeRewardsApi? rewards,
  FakeRunningApi? running,
  FakeLocationSource? location,
  FakeBatteryAccess? battery,
  FakeRunVoice? voice,
}) {
  SharedPreferences.setMockInitialValues(const {});
  return [
    appDatabaseProvider.overrideWithValue(db),
    workoutApiProvider.overrideWithValue(api),
    // No connectivity events unless a test sends its own (Phase 18 flows).
    connectivityStreamProvider
        .overrideWithValue(connectivity ?? const Stream.empty()),
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
    // Phase 17: consents from a scripted server; FITOS AI allowed unless a test says.
    privacyApiProvider.overrideWithValue(privacy ?? FakePrivacyApi()),
    // Phase 19: feedback and the start-up config from scripted servers; this
    // build is number 4 unless a test says (no platform plugin).
    feedbackApiProvider.overrideWithValue(feedback ?? FakeFeedbackApi()),
    metaApiProvider.overrideWithValue(meta ?? FakeMetaApi()),
    appBuildProvider.overrideWith((_) async => appBuild),
    // Phase 19 (ADR-027): free unless a test says; a scripted weekly report.
    premiumApiProvider.overrideWithValue(premium ?? FakePremiumApi()),
    weeklyReportApiProvider.overrideWithValue(weekly ?? FakeWeeklyReportApi()),
    // Beta 3.3: no streak card unless a test says.
    streakApiProvider.overrideWithValue(streak ?? FakeStreakApi()),
    // Beta 3.4: nothing earned unless a test says.
    rewardsApiProvider.overrideWithValue(rewards ?? FakeRewardsApi()),
    // Beta 4.0: runs go to a scripted server; GPS only when a test sends it.
    runningApiProvider.overrideWithValue(running ?? FakeRunningApi()),
    locationSourceProvider.overrideWithValue(location ?? FakeLocationSource()),
    runNotificationProvider.overrideWithValue(FakeRunNotification()),
    batteryAccessProvider.overrideWithValue(battery ?? FakeBatteryAccess()),
    runVoiceProvider.overrideWithValue(voice ?? FakeRunVoice()),
  ];
}
