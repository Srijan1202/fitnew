/// The app's single failure type. Every repository returns these instead of
/// throwing SDK-specific exceptions, so screens never see a `DioException` or
/// a `FirebaseAuthException`.
///
/// Mirrors the §10 error codes where a server error is the cause, and adds
/// the client-side cases the server cannot know about.
sealed class Failure {
  const Failure(this.message);

  /// Human-readable, safe to show. Never a stack trace, never a raw SDK
  /// message — those go to the log.
  final String message;
}

/// Server said 401. The session is gone; sign in again.
final class Unauthenticated extends Failure {
  const Unauthenticated([super.message = 'Sign in to continue.']);
}

/// Server said 422, with the field that failed.
final class Validation extends Failure {
  const Validation(super.message, {this.field});
  final String? field;
}

/// Server said 409: the request is valid but the state moved on (a session
/// already active, a session completed elsewhere). `path` / `issue` are
/// the envelope's first detail, e.g. `activeSessionId` / `<id>`.
final class Conflict extends Failure {
  const Conflict(super.message, {this.path, this.issue});
  final String? path;
  final String? issue;
}

/// Server said 429.
final class RateLimited extends Failure {
  const RateLimited([
    super.message = 'Too many attempts. Wait a minute and try again.',
  ]);
}

/// No network, or it timed out. The action may be retried.
final class Offline extends Failure {
  const Offline([super.message = 'You appear to be offline.']);
}

/// Wrong password, unknown email, weak password — the credential cases
/// Firebase reports. `code` is Firebase's, e.g. `wrong-password`.
final class Credential extends Failure {
  const Credential(super.message, {required this.code});
  final String code;
}

/// Everything else. Logged in full; shown as a generic line.
final class Unknown extends Failure {
  const Unknown([super.message = 'Something went wrong. Please try again.']);
}
