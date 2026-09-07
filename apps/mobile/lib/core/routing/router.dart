import 'package:go_router/go_router.dart';

import '../../features/today/presentation/screens/today_placeholder_screen.dart';

/// Application routes.
///
/// One route at Phase 0. Auth guards land in Phase 1, and the remaining
/// destinations (train, eat, mess, progress) with their features.
abstract final class Routes {
  static const String today = '/';
}

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: Routes.today,
    routes: <RouteBase>[
      GoRoute(
        path: Routes.today,
        name: 'today',
        builder: (context, state) => const TodayPlaceholderScreen(),
      ),
    ],
  );
}
