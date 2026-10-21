import 'dart:async';

/// Phase 15 (ADR-021): something the user just did that can make a
/// scheduled reminder pointless — the plan's `cancelOn` events. The places
/// where it happens report it here; the notification coordinator listens
/// and cancels on the phone at once, online or not.
enum ActivityKind {
  workoutStarted('workout-started'),
  workoutCompleted('workout-completed'),
  foodLogged('food-logged'),
  weightLogged('weight-logged'),
  checkinLogged('checkin-logged');

  const ActivityKind(this.wire);
  final String wire;
}

class Activity {
  const Activity(this.kind, this.at);
  final ActivityKind kind;

  /// When it happened (its local day decides which reminders it cancels).
  final DateTime at;
}

/// A broadcast of [Activity]. Reporting with nobody listening is a no-op,
/// so producers need not know whether notifications are set up.
abstract final class ActivitySignal {
  static final StreamController<Activity> _controller =
      StreamController<Activity>.broadcast(sync: true);

  static Stream<Activity> get stream => _controller.stream;

  static void report(ActivityKind kind, {DateTime? at}) =>
      _controller.add(Activity(kind, at ?? DateTime.now()));
}
