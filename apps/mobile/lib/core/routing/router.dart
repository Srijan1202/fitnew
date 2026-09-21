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
import '../../features/training/presentation/screens/custom_builder_screen.dart';
import '../../features/training/presentation/screens/day_editor_screen.dart';
import '../../features/training/presentation/screens/generate_options_screen.dart';
import '../../features/training/presentation/screens/plan_start_screen.dart';
import '../../features/training/presentation/screens/template_library_screen.dart';
import '../../features/training/presentation/screens/template_preview_screen.dart';
import '../../features/training/presentation/screens/workout_week_screen.dart';
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

  /// Same browser, returning the tapped exercise to the caller.
  static const String exercisePicker = '/exercises/pick';
  static const String plan = '/plan';
  static const String planNew = '/plan/new';
  static const String planGenerate = '/plan/new/generate';
  static const String planTemplates = '/plan/templates';
  static String planTemplate(String slug) => '/plan/templates/$slug';
  static const String planCustom = '/plan/custom';
  static String planDayEdit(String dayId) => '/plan/days/$dayId/edit';
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
            path: 'pick',
            name: 'exercise-picker',
            builder: (context, state) =>
                const ExerciseBrowserScreen(pickMode: true),
          ),
          GoRoute(
            path: ':id',
            name: 'exercise-detail',
            builder: (context, state) =>
                ExerciseDetailScreen(id: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: Routes.plan,
        name: 'plan',
        builder: (context, state) => const WorkoutWeekScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'new',
            name: 'plan-new',
            builder: (context, state) => const PlanStartScreen(canGoBack: true),
            routes: <RouteBase>[
              GoRoute(
                path: 'generate',
                name: 'plan-generate',
                builder: (context, state) => const GenerateOptionsScreen(),
              ),
            ],
          ),
          GoRoute(
            path: 'templates',
            name: 'plan-templates',
            builder: (context, state) => const TemplateLibraryScreen(),
            routes: <RouteBase>[
              GoRoute(
                path: ':slug',
                name: 'plan-template',
                builder: (context, state) => TemplatePreviewScreen(
                  slug: state.pathParameters['slug']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'custom',
            name: 'plan-custom',
            builder: (context, state) => const CustomBuilderScreen(),
          ),
          GoRoute(
            path: 'days/:dayId/edit',
            name: 'plan-day-edit',
            builder: (context, state) =>
                DayEditorScreen(dayId: state.pathParameters['dayId']!),
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
