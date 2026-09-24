import 'package:fitos/core/db/app_database.dart';
import 'package:fitos/features/mess/presentation/mess_providers.dart';
import 'package:fitos/features/nutrition/presentation/controllers/food_log_providers.dart';
import 'package:fitos/features/today/presentation/today_providers.dart';
import 'package:fitos/features/workout/presentation/controllers/rest_timer.dart';
import 'package:fitos/features/workout/presentation/controllers/workout_providers.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_food_log_api.dart';
import 'fake_mess_api.dart';
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
  ];
}
