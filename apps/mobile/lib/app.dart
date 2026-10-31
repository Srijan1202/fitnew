import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/config/app_update.dart';
import 'core/routing/router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/theme/tokens.dart';
import 'shared/widgets/fit_glass.dart';
import 'features/home_widgets/presentation/home_widgets_coordinator.dart';
import 'features/premium/presentation/app_icon_controller.dart';
import 'features/premium/presentation/premium_providers.dart';
import 'features/nutrition/presentation/controllers/food_log_providers.dart';
import 'features/workout/presentation/controllers/workout_providers.dart';
import 'features/health/presentation/controllers/health_providers.dart';
import 'features/notifications/presentation/notification_coordinator.dart';
import 'features/today/presentation/today_providers.dart';
import 'core/config/app_features.dart';
import 'features/premium/presentation/rewards_providers.dart';
import 'features/progress/presentation/photos/progress_photos_screen.dart';
import 'features/running/presentation/controllers/running_providers.dart';

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
    // …and finished runs, with their own queue (beta 4.0, ADR-038).
    ref.watch(runSyncCoordinatorProvider);
    // …and TODAY's events, with a third, separate queue (Phase 11, D9);
    // `completed` goes once the server holds the evidence.
    ref.watch(todayCoordinatorProvider);
    ref.watch(todayCompletionWatcherProvider);
    ref.watch(healthRefreshCoordinatorProvider);
    // Phase 15: the reminder plan on the device, kept current.
    ref.watch(notificationCoordinatorProvider);
    // Beta 3.2: re-check for a newer beta when the app comes back.
    ref.watch(updateCheckCoordinatorProvider);
    // Beta 3.3 (ADR-033): the admin's feature switches, re-read on return.
    ref.watch(configRefreshCoordinatorProvider);
    // Beta 5.0: the home-screen widgets' snapshot and taps.
    ref.watch(homeWidgetsCoordinatorProvider);
    // Phase 19 (E1): a build below the server's minimum shows only
    // "Update FITOS". Unknown (offline) never blocks.
    final updateRequired = ref.watch(updateRequiredProvider);
    // Phase 19 (ADR-027): the palette every token reads; a change rebuilds
    // the whole tree in place. A premium palette goes back to Automatic
    // (Dark or Light with the phone, owner 2026-10-30) as soon as the app
    // knows the user is not premium.
    final palette = ref.watch(themeControllerProvider);
    FitPalette.current = palette;
    ref.listen(themeControllerProvider, (previous, next) {
      if (previous?.id == next.id) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) rebuildEverything(context);
      });
    });
    ref.listen(isPremiumProvider, (_, premium) {
      if (premium == false && FitPalette.current.premium) {
        ref.read(themeControllerProvider.notifier).followDevice();
      }
      // Beta 3.2: and a premium app icon goes back to Standard.
      if (premium == false) {
        ref.read(appIconControllerProvider.notifier).keepWithin(premium: false);
      }
    });
    // Beta 3.4: a streak theme or icon this account has not earned (another
    // account on the phone) goes back once the earned list is known.
    // Beta 4.2: and a running badge's (once both lists are known).
    ref.listen(earnedUnlocksProvider, (_, earned) {
      if (earned == null) return;
      final reward = FitPalette.current.reward;
      if (reward != null && !earned.contains(reward)) {
        ref.read(themeControllerProvider.notifier).followDevice();
      }
      ref.read(appIconControllerProvider.notifier).keepEarned(earned);
    });

    return MaterialApp.router(
      title: 'FITOS',
      debugShowCheckedModeBanner: false,
      theme: FitTheme.build(),
      routerConfig: router,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        // Status-bar icons that read on the canvas, on every screen.
        value: FitTheme.overlayStyle,
        child: Builder(
          builder: (context) {
            // Text scaling is supported to 200% (§6.8). Large metrics cap their
            // scale factor so they never truncate; body text scales freely.
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: mediaQuery.textScaler.clamp(maxScaleFactor: 2.0),
              ),
              // The paper and the glow, once under every page and its bar
              // (owner 2026-10-30); the Scaffolds above are clear. The
              // router's pages have no transition, so only the top one
              // paints over it.
              child: FitCanvas(
                child: updateRequired
                    ? const UpdateRequiredScreen()
                    : Stack(
                        children: <Widget>[
                          Positioned.fill(
                            child: child ?? const SizedBox.shrink(),
                          ),
                          // Beta 3.5: a newer beta, asked over any screen at
                          // every open — never in the middle of a workout.
                          UpdatePromptHost(
                            navigatorContext: () => router
                                .routerDelegate.navigatorKey.currentContext,
                            suppressed: () => router
                                .routerDelegate.currentConfiguration.uri.path
                                .startsWith('/plan/session'),
                          ),
                          // Beta 3.6: a camera photo Android kept for us.
                          LostPhotoHost(
                            navigatorContext: () => router
                                .routerDelegate.navigatorKey.currentContext,
                            suppressed: () => router
                                .routerDelegate.currentConfiguration.uri.path
                                .startsWith('/plan/session'),
                          ),
                        ],
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}
