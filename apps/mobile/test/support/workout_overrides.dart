import 'package:fitos/core/db/app_database.dart';
import 'package:fitos/features/workout/presentation/controllers/rest_timer.dart';
import 'package:fitos/features/workout/presentation/controllers/workout_providers.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_workout_api.dart';

/// Everything a widget test needs so the workout feature runs on an
/// in-memory database against the fake server, with no platform plugins:
/// no path_provider, no connectivity, no notifications.
List<Override> workoutOverrides(AppDatabase db, FakeWorkoutApi api) {
  SharedPreferences.setMockInitialValues(const {});
  return [
    appDatabaseProvider.overrideWithValue(db),
    workoutApiProvider.overrideWithValue(api),
    connectivityStreamProvider.overrideWithValue(const Stream.empty()),
    restNotifierProvider.overrideWithValue(const NoopRestNotifier()),
  ];
}
