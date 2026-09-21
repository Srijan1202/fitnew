import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';

/// Back that can never throw.
///
/// `context.pop()` throws `GoError: There is nothing to pop` when the
/// current screen is the only entry in its navigator — which is exactly
/// what `context.go('/plan')` leaves behind after a programme is generated,
/// applied or saved. Every back affordance in the app goes through here:
/// pop when there is something to pop, otherwise go to TODAY.
extension SafeNavigation on BuildContext {
  void popOrHome<T extends Object?>([T? result]) {
    if (canPop()) {
      pop<T>(result);
    } else {
      go(Routes.today);
    }
  }
}
