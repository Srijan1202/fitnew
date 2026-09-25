import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/sign_in_screen.dart';
import '../../features/auth/presentation/screens/sign_up_screen.dart';
import '../../features/auth/presentation/screens/splash_gate_screen.dart';
import '../../features/exercise/presentation/screens/exercise_browser_screen.dart';
import '../../features/exercise/presentation/screens/exercise_detail_screen.dart';
import '../../features/mess/presentation/mess_screen.dart';
import '../../features/progress/presentation/progress_screen.dart';
import '../../features/profile/presentation/screens/food_preferences_screen.dart';
import '../../features/nutrition/domain/entities/food.dart';
import '../../features/nutrition/presentation/screens/custom_food_screen.dart';
import '../../features/nutrition/presentation/screens/food_detail_screen.dart';
import '../../features/nutrition/presentation/controllers/food_logger.dart';
import '../../features/nutrition/presentation/screens/eat_screen.dart';
import '../../features/nutrition/presentation/screens/food_library_screen.dart';
import '../../features/nutrition/presentation/screens/log_food_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_flow_screen.dart';
import '../../features/profile/presentation/screens/goal_editor_screen.dart';
import '../../features/profile/presentation/screens/personal_details_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/training/presentation/screens/custom_builder_screen.dart';
import '../../features/training/presentation/screens/day_editor_screen.dart';
import '../../features/training/presentation/screens/generate_options_screen.dart';
import '../../features/training/presentation/screens/plan_start_screen.dart';
import '../../features/training/presentation/screens/template_library_screen.dart';
import '../../features/training/presentation/screens/template_preview_screen.dart';
import '../../features/training/presentation/screens/workout_week_screen.dart';
import '../../features/workout/presentation/screens/active_session_screen.dart';
import '../../features/ai/presentation/screens/ai_chat_screen.dart';
import '../../features/health/presentation/screens/health_data_screen.dart';
import '../../features/workout/presentation/screens/history_screen.dart';
import '../../features/workout/presentation/screens/volume_screen.dart';
import '../../features/workout/presentation/screens/session_summary_screen.dart';
import 'app_shell.dart';
import 'guards.dart';

/// Application routes.
///
/// Signed-in life happens inside the app shell (five tabs, bottom bar):
/// TODAY, TRAINING, AI, NUTRITION, PROGRESS. Anything deeper than a tab root
/// — the programme editors, the picker, the library, profile — is pushed on
/// the root navigator above the shell, which hides the bar and gives
/// Android back one obvious answer: pop it.
abstract final class Routes {
  static const String splash = '/splash';
  static const String signIn = '/sign-in';
  static const String signUp = '/sign-up';
  static const String forgotPassword = '/forgot-password';
  static const String onboarding = '/onboarding';
  static const String profile = '/profile';
  static const String goalEditor = '/profile/goal';
  static const String personalDetails = '/profile/details';

  /// Phase 10: diet and allergies, the hard rules for food suggestions.
  static const String profileFood = '/profile/food';
  static const String healthData = '/profile/health';
  static const String exercises = '/exercises';
  static String exerciseDetail(String id) => '/exercises/$id';

  /// Same browser, returning the tapped exercise to the caller.
  static const String exercisePicker = '/exercises/pick';

  // Shell tabs, in bar order.
  static const String today = '/';
  static const String plan = '/plan';
  static const String chat = '/chat';
  static const String nutrition = '/nutrition';

  /// Phase 12: Progress & Recovery (the tab that was Market).
  static const String progress = '/progress';

  // Food library (Phase 7) and logging (Phase 8); root navigator, the bar
  // is hidden. `/nutrition` itself is EAT.
  static const String foodLibrary = '/nutrition/library';
  static const String foodLog = '/nutrition/log';
  static const String foodNew = '/nutrition/foods/new';

  /// Phase 9: the MESS screen (root navigator).
  static const String mess = '/nutrition/mess';
  static String foodDetail(String id) => '/nutrition/foods/$id';

  // Deeper training screens (root navigator; the bar is hidden).
  static const String planNew = '/plan/new';
  static const String planGenerate = '/plan/new/generate';
  static const String planTemplates = '/plan/templates';
  static String planTemplate(String slug) => '/plan/templates/$slug';
  static const String planCustom = '/plan/custom';
  static String planDayEdit(String dayId) => '/plan/days/$dayId/edit';

  // Workout logging (Phase 5). Sessions are addressed by CLIENT id.
  static String session(String clientSessionId) =>
      '/plan/session/$clientSessionId';
  static String sessionSummary(String clientSessionId) =>
      '/plan/session/$clientSessionId/summary';
  static const String history = '/plan/history';
  static const String volume = '/plan/volume';
  static String historyDetail(String serverId) => '/plan/history/$serverId';

  /// Screens a signed-out user may see. Everything else needs a session.
  static const Set<String> authRoutes = {signIn, signUp, forgotPassword};
}

/// The routes, separate from the provider so tests can mount them with
/// their own overrides and the same shell. [rootNavigatorKey] is the
/// router's own root navigator: dialogs, and every screen that hides the
/// bottom bar, are pushed on it.
List<RouteBase> buildRoutes(GlobalKey<NavigatorState> rootNavigatorKey) =>
    <RouteBase>[
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
          GoRoute(
            path: 'health',
            name: 'health-data',
            builder: (context, state) => const HealthDataScreen(),
          ),
          GoRoute(
            path: 'details',
            name: 'personal-details',
            builder: (context, state) => const PersonalDetailsScreen(),
          ),
          GoRoute(
            path: 'food',
            name: 'profile-food',
            builder: (context, state) => const FoodPreferencesScreen(),
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
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.today,
                name: 'today',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.plan,
                name: 'plan',
                builder: (context, state) => const WorkoutWeekScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'new',
                    name: 'plan-new',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) =>
                        const PlanStartScreen(canGoBack: true),
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'generate',
                        name: 'plan-generate',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) =>
                            const GenerateOptionsScreen(),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'templates',
                    name: 'plan-templates',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const TemplateLibraryScreen(),
                    routes: <RouteBase>[
                      GoRoute(
                        path: ':slug',
                        name: 'plan-template',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => TemplatePreviewScreen(
                          slug: state.pathParameters['slug']!,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'custom',
                    name: 'plan-custom',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const CustomBuilderScreen(),
                  ),
                  GoRoute(
                    path: 'days/:dayId/edit',
                    name: 'plan-day-edit',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) =>
                        DayEditorScreen(dayId: state.pathParameters['dayId']!),
                  ),
                  GoRoute(
                    path: 'session/:clientSessionId',
                    name: 'session',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => ActiveSessionScreen(
                      clientSessionId: state.pathParameters['clientSessionId']!,
                    ),
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'summary',
                        name: 'session-summary',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => SessionSummaryScreen(
                          clientSessionId:
                              state.pathParameters['clientSessionId']!,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'volume',
                    name: 'volume',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const VolumeScreen(),
                  ),
                  GoRoute(
                    path: 'history',
                    name: 'history',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const HistoryScreen(),
                    routes: <RouteBase>[
                      GoRoute(
                        path: ':serverId',
                        name: 'history-detail',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => HistoryDetailScreen(
                          serverId: state.pathParameters['serverId']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.chat,
                name: 'chat',
                builder: (context, state) => const AiChatScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.nutrition,
                name: 'nutrition',
                builder: (context, state) => const EatScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'library',
                    name: 'food-library',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const FoodLibraryScreen(),
                  ),
                  GoRoute(
                    path: 'log',
                    name: 'food-log',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => LogFoodScreen(
                      target: state.extra is LogTarget
                          ? state.extra! as LogTarget
                          : null,
                    ),
                  ),
                  GoRoute(
                    path: 'mess',
                    name: 'mess',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const MessScreen(),
                  ),
                  GoRoute(
                    path: 'foods/new',
                    name: 'food-new',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const CustomFoodScreen(),
                  ),
                  // The food travels as `extra`; there is no single-food endpoint.
                  GoRoute(
                    path: 'foods/:id',
                    name: 'food-detail',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => switch (state.extra) {
                      final FoodDetailArgs a => FoodDetailScreen(
                          food: a.food,
                          justCreated: a.justCreated,
                        ),
                      final Food f => FoodDetailScreen(food: f),
                      _ => const FoodDetailScreen(food: null),
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.progress,
                name: 'progress',
                builder: (context, state) => const ProgressScreen(),
              ),
            ],
          ),
        ],
      ),
    ];

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = AuthRefresh(ref);
  ref.onDispose(refresh.dispose);
  final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) =>
        authRedirect(ref.read(authControllerProvider), state.matchedLocation),
    routes: buildRoutes(rootNavigatorKey),
  );
});
