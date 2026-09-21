import '../../../../core/errors/result.dart';
import '../../../exercise/domain/entities/exercise.dart';
import '../entities/workout.dart';

/// How many mutations the server has not confirmed, and how many gave up.
class SyncStatus {
  const SyncStatus({
    required this.pending,
    required this.parked,
    this.lastError,
  });

  final int pending;
  final int parked;
  final String? lastError;

  bool get clean => pending == 0 && parked == 0;

  static const SyncStatus none = SyncStatus(pending: 0, parked: 0);
}

/// Workout logging, local-first (§33): every write lands in the phone's
/// database and the queue before anything touches the network; reads of
/// the session in progress come from the phone. History and "today" are
/// network calls with a cache behind them.
///
/// Sessions are addressed by their CLIENT id everywhere in the app — it
/// exists before the server has heard of the session.
abstract class WorkoutRepository {
  /* --------------------------------------------------------- reading -- */

  /// The session, re-emitted on every local change.
  Stream<WorkoutSession?> watchSession(String clientSessionId);
  Future<WorkoutSession?> session(String clientSessionId);

  /// The session in progress on this phone, if any.
  Future<WorkoutSession?> activeSession();
  Stream<WorkoutSession?> watchActiveSession();

  /// Network first; the last cached answer when offline.
  Future<Result<TodayResponse>> today({int? dayOfWeek});

  Future<Result<SessionListResponse>> history({String? before, int limit = 20});

  /// A completed session by its SERVER id (history detail).
  Future<Result<WorkoutSession>> fetchSession(String serverId);

  /// Phase 6: weekly hard sets per muscle vs the landmarks (current ISO
  /// week + 3); network first, the last cached answer when offline.
  Future<Result<VolumeResponse>> volume();

  /// Phase 6: one lift's last three sessions and its recommendation.
  Future<Result<ProgressionDetail>> progression(String exerciseId);

  /* --------------------------------------------------------- writing -- */

  /// Start a session on the phone now: from a programme day (seeded from
  /// [today], so it works offline) or empty (ad-hoc).
  Future<WorkoutSession> startSession({TodayResponse? day});

  Future<void> logSet(String clientSessionId, LogSetInput set);

  Future<void> updateSet(
    String clientSessionId,
    String clientSetId, {
    SetType? setType,
    double? weightKg,
    bool weightCleared = false,
    int? reps,
    int? rir,
    bool rirCleared = false,
  });

  Future<void> deleteSet(String clientSessionId, String clientSetId);

  Future<String> addExercise(
    String clientSessionId,
    ExerciseSummary exercise, {
    String? plannedExerciseId,
    int? orderIndex,
    int? supersetGroup,
  });

  Future<void> updateExercise(
    String clientSessionId,
    String clientExerciseId, {
    int? orderIndex,
    int? supersetGroup,
    bool supersetCleared = false,
    ExerciseSummary? replaceWith,
    bool removed = false,
  });

  Future<void> complete(String clientSessionId, {String? notes});
  Future<void> abandon(String clientSessionId);

  /// Phase 6 (owner 12.3): a deload is only ever applied by this call.
  /// Online only — it changes what the server plans next.
  Future<Result<DeloadState>> acceptDeload();
  Future<Result<DeloadState>> declineDeload();

  /* ---------------------------------------------------------- syncing -- */

  /// Fires whenever the server's derived view of the user (today, a day,
  /// volume — recommendations, neglect, deload, done-today) may have
  /// moved: a session started, completed or abandoned on this phone, and
  /// every drain that reached the server. The screens that cache that
  /// view refetch on it (Phase 6 refresh fix).
  Stream<void> watchServerChanges();

  Stream<SyncStatus> watchSync();
  Future<SyncStatus> syncStatus();

  /// Drain the queue now (connectivity returned, app resumed, user tapped
  /// Retry). Safe to call at any time; concurrent calls coalesce.
  Future<void> sync();

  /// Put parked mutations back in the queue and drain.
  Future<void> retryParked();

  /// Sign-out: the next user starts from nothing.
  Future<void> clearLocal();
}
