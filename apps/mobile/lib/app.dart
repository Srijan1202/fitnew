import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/router.dart';
import 'core/theme/app_theme.dart';
import 'features/nutrition/presentation/controllers/food_log_providers.dart';
import 'features/workout/presentation/controllers/workout_providers.dart';
import 'features/health/presentation/controllers/health_providers.dart';

/// Root widget. Owns the theme; the router comes from Riverpod so the auth
/// guard can read the same provider the screens do.
class FitOSApp extends ConsumerWidget {
  const FitOSApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Keeps the offline queue draining for the signed-in user (§33).
    ref.watch(syncCoordinatorProvider);
    // …and the food-log queue, with its own engine (Phase 8).
    ref.watch(nutritionSyncCoordinatorProvider);
    ref.watch(healthRefreshCoordinatorProvider);

    return MaterialApp.router(
      title: 'FITOS',
      debugShowCheckedModeBanner: false,
      theme: FitTheme.build(),
      routerConfig: router,
      builder: (context, child) {
        // Text scaling is supported to 200% (§6.8). Large metrics cap their
        // scale factor so they never truncate; body text scales freely.
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler.clamp(maxScaleFactor: 2.0),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
