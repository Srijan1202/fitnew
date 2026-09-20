import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/sign_in_screen.dart';
import '../../features/auth/presentation/screens/sign_up_screen.dart';
import '../../features/auth/presentation/screens/splash_gate_screen.dart';
import '../../features/exercise/presentation/screens/exercise_browser_screen.dart';
import '../../features/exercise/presentation/screens/exercise_detail_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_flow_screen.dart';
import '../../features/profile/presentation/screens/goal_editor_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/today/presentation/screens/today_placeholder_screen.dart';
import 'guards.dart';

/// Application routes. Auth in Phase 1; the remaining destinations (train,
/// eat, mess, progress) arrive with their features.
abstract final class Routes {
  static const String splash = '/splash';
  static const String signIn = '/sign-in';
  static const String signUp = '/sign-up';
  static const String forgotPassword = '/forgot-password';
  static const String onboarding = '/onboarding';
  static const String profile = '/profile';
  static const String goalEditor = '/profile/goal';
  static const String exercises = '/exercises';
  static String exerciseDetail(String id) => '/exercises/$id';
  static const String today = '/';

  /// Screens a signed-out user may see. Everything else needs a session.
  static const Set<String> authRoutes = {signIn, signUp, forgotPassword};
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) =>
        authRedirect(ref.read(authControllerProvider), state.matchedLocation),
    routes: <RouteBase>[
      GoRoute(
        path: Routes.splash,
        name: 'splash',
        builder: (context, state) => const SplashGateScreen(),
      ),
      GoRoute(
        path: Routes.signIn,
        name: 'sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: Routes.signUp,
        name: 'sign-up',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: Routes.forgotPassword,
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: Routes.onboarding,
        name: 'onboarding',
        builder: (context, state) => const OnboardingFlowScreen(),
      ),
      GoRoute(
        path: Routes.profile,
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'goal',
            name: 'goal-editor',
            builder: (context, state) => const GoalEditorScreen(),
          ),
        ],
      ),
      GoRoute(
        path: Routes.exercises,
        name: 'exercises',
        builder: (context, state) => const ExerciseBrowserScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: ':id',
            name: 'exercise-detail',
            builder: (context, state) =>
                ExerciseDetailScreen(id: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: Routes.today,
        name: 'today',
        builder: (context, state) => const TodayPlaceholderScreen(),
      ),
    ],
  );
});
