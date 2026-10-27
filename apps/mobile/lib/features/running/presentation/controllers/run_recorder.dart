import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/db/app_database.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../profile/data/profile_repository.dart';
import '../../data/location_source.dart';
import '../../data/run_store.dart';
import '../../domain/coach.dart';
import '../../domain/gps_filter.dart';
import '../../domain/live_stats.dart';
import '../../domain/run.dart';
import '../../domain/track.dart';
import '../../domain/units.dart';
import '../../domain/workout.dart';
import '../../domain/workout_runner.dart';
import 'running_providers.dart';

/// Beta 4.0 (ADR-038): the run being recorded.
///
/// The phone's database is the run's source of truth while it happens: the
/// row holds its state and timer, every stored point is written as it
/// arrives. If Android or a flat battery ends FITOS mid-run, the next start
/// finds the run paused at its last point — nothing recorded is lost.
enum RunStatus { recording, paused, autoPaused, finished }

enum GpsSignal { searching, weak, good, lost }

class LiveRun {
  LiveRun({
    required this.id,
    required this.kind,
    required this.goal,
    required this.status,
    required this.startedAt,
    required this.activeSeconds,
    required this.track,
    required this.gps,
    this.restored = false,
    this.session,
    this.plannedTitle,
  })  : distanceM = track.distanceM,
        splitCount = track.splitSeconds.length;

  final String id;
  final RunKind kind;
  final RunGoal goal;
  final RunStatus status;
  final DateTime startedAt;
  final int activeSeconds;

  /// The live figures (distance, paces, splits, the line on the map).
  final LiveTrack track;
  final GpsSignal gps;

  /// Found after FITOS was closed during the run (shown once on the screen).
  final bool restored;

  /// The distance and completed splits when this state was made ([track]
  /// keeps growing; these do not), so a listener can see what changed.
  final double distanceM;
  final int splitCount;

  /// Beta 4.1: the structured session in progress (null for a steady run).
  final LiveSession? session;

  /// Beta 4.1: the planned run this one does, if any.
  final String? plannedTitle;

  bool get isRunning => status == RunStatus.recording;

  /// Paused by the runner or by auto-pause.
  bool get isPaused =>
      status == RunStatus.paused || status == RunStatus.autoPaused;

  double? get avgPaceSecPerKm =>
      distanceM < 10 ? null : activeSeconds / (distanceM / 1000);

  /// 0–1 towards a distance or time goal; null otherwise.
  double? get progress => goalProgress(
        goalKind: goal.kind.name,
        goalValue: goal.value,
        distanceM: distanceM,
        activeSeconds: activeSeconds,
      );

  bool get goalReached => (progress ?? 0) >= 1;

  LiveRun copyWith({
    RunStatus? status,
    int? activeSeconds,
    GpsSignal? gps,
    bool? restored,
    LiveSession? session,
  }) =>
      LiveRun(
        id: id,
        kind: kind,
        goal: goal,
        status: status ?? this.status,
        startedAt: startedAt,
        activeSeconds: activeSeconds ?? this.activeSeconds,
        track: track,
        gps: gps ?? this.gps,
        restored: restored ?? this.restored,
        session: session ?? this.session,
        plannedTitle: plannedTitle,
      );
}

/// Beta 4.1: where a structured run is, for the screen.
class LiveSession {
  const LiveSession({
    required this.name,
    required this.index,
    required this.count,
    required this.step,
    required this.next,
    required this.metresLeft,
    required this.secondsLeft,
  });

  final String name;

  /// The step in progress (0-based); [count] when the session is done.
  final int index;
  final int count;
  final WorkoutStep? step;
  final WorkoutStep? next;
  final double? metresLeft;
  final int? secondsLeft;

  bool get done => index >= count;
}

class RunRecorder extends Notifier<LiveRun?> {
  StreamSubscription<GpsFix>? _sub;
  Timer? _ticker;
  GpsFilter? _filter;
  final AutoPause _auto = AutoPause();
  int _seq = 0;
  int _segment = 0;
  int _activeMs = 0;
  DateTime? _resumedAt;
  DateTime? _lastFixAt;
  int _lastNotified = -100;
  bool _newSegment = false;
  Future<void> _writes = Future.value();

  // Beta 4.1: the session, the coach and the plan's run.
  WorkoutRunner? _runner;
  Coach? _coach;
  PaceRange? _plannedPace;
  int _lastCountdown = -1;

  RunStore get _store => ref.read(runningRepositoryProvider).store;
  DateTime _now() => ref.read(runClockProvider)();

  @override
  LiveRun? build() {
    // A new user starts with no run (sign-out clears the phone's rows).
    ref.watch(sessionUserIdProvider);
    ref.onDispose(_stopSensors);
    unawaited(Future.microtask(_restore));
    return null;
  }

  /* ------------------------------------------------------------ start -- */

  /// Asks for location (outdoor). The run starts only when it is granted.
  Future<LocationAccess> access() =>
      ref.read(locationSourceProvider).ensureAccess();

  Future<void> start({
    required RunKind kind,
    required RunGoal goal,
    RunWorkout? workout,
    PlannedRun? planned,
  }) async {
    if (state != null) return;
    final now = _now();
    final id = const Uuid().v4();
    // A planned session (intervals, tempo, run/walk) is the workout itself.
    final session = workout ??
        (planned != null && planned.structured
            ? RunWorkout(name: planned.title, steps: planned.steps!)
            : null);
    _runner =
        session == null || kind != RunKind.outdoor && _distanceSteps(session)
            ? null
            : WorkoutRunner(session);
    _plannedPace = planned?.pace;
    _coach = _newCoach();
    _lastCountdown = -1;
    _activeMs = 0;
    _resumedAt = now;
    _seq = 0;
    _segment = 0;
    _newSegment = true;
    _auto.reset();
    await _store.insert(
      LocalRunsCompanion.insert(
        clientRunId: id,
        kind: kind.name,
        status: RunStatus.recording.name,
        goalKind: goal.kind.name,
        goalValue: Value(goal.value),
        startedAt: now.toUtc().toIso8601String(),
        resumedAt: Value(now.toUtc().toIso8601String()),
        updatedAt: now.toUtc().toIso8601String(),
        workoutJson: Value(
          _runner == null ? null : jsonEncode(_runner!.workout.toJson()),
        ),
        plannedRunId: Value(planned?.id),
      ),
    );
    state = LiveRun(
      id: id,
      kind: kind,
      goal: goal,
      status: RunStatus.recording,
      startedAt: now,
      activeSeconds: 0,
      track: _newTrack(),
      gps: kind == RunKind.outdoor ? GpsSignal.searching : GpsSignal.good,
      plannedTitle: planned?.title,
    );
    state = state!.copyWith(session: _sessionNow(0, 0));
    _startSensors(now);
    final first = _runner?.current;
    if (first != null) _say(_coach!.step(first, afterRest: false));
  }

  static bool _distanceSteps(RunWorkout w) =>
      w.steps.any((s) => s.distanceM != null);

  Coach _newCoach() {
    final settings = ref.read(runSettingsProvider);
    return Coach(
      settings: CoachSettings(
        enabled: settings.voice,
        everyHalf: settings.everyHalf,
      ),
      unit: settings.unit,
    );
  }

  void _say(String? text) {
    if (text == null || !ref.read(runSettingsProvider).voice) return;
    unawaited(ref.read(runVoiceProvider).say(text));
  }

  LiveSession? _sessionNow(double distanceM, int activeSeconds) {
    final r = _runner;
    if (r == null) return null;
    final left = r.left(distanceM: distanceM, activeSeconds: activeSeconds);
    return LiveSession(
      name: r.workout.name,
      index: r.index,
      count: r.steps.length,
      step: r.current,
      next: r.next,
      metresLeft: left.metresLeft,
      secondsLeft: left.secondsLeft,
    );
  }

  /// The session and the coach, once a second while running.
  void _guide(LiveRun run, DateTime now) {
    final r = _runner;
    final distance = run.track.distanceM;
    if (r != null && !r.done) {
      final before = r.current;
      final begun = r.update(
        distanceM: distance,
        activeSeconds: run.activeSeconds,
        clockT: clockSecondsOf(run.startedAt, now),
      );
      var previous = before;
      for (final i in begun) {
        _say(
          _coach!
              .step(r.steps[i], afterRest: previous?.kind == StepKind.recover),
        );
        previous = r.steps[i];
      }
      if (begun.isNotEmpty || r.done) _persistLaps();
      if (r.done && before != null) _say(_coach!.workoutDone());
      final step = r.current;
      final left = r
          .left(distanceM: distance, activeSeconds: run.activeSeconds)
          .secondsLeft;
      if (step != null && left != null && left != _lastCountdown) {
        _lastCountdown = left;
        _say(
          _coach!.countdown(
            step,
            left,
            nextIsRep:
                r.next?.kind == StepKind.work && step.kind == StepKind.recover,
          ),
        );
      }
    }
    final coach = _coach;
    if (coach == null) return;
    for (final line in coach.tick(
      CoachInput(
        activeSeconds: run.activeSeconds,
        distanceM: distance,
        avgPaceSecPerKm: run.avgPaceSecPerKm,
        currentPaceSecPerKm: run.track.currentPaceSecPerKm,
        lastSplitSeconds:
            run.track.splitSeconds.isEmpty ? null : run.track.splitSeconds.last,
        goalKind: run.goal.kind.name,
        goalValue: run.goal.value,
        target: targetPace(
          step: r?.current,
          planned: r == null ? _plannedPace : null,
          goalKind: run.goal.kind.name,
          goalValue: run.goal.value,
        ),
      ),
    )) {
      _say(line);
    }
  }

  void _persistLaps() {
    final r = _runner;
    final run = state;
    if (r == null || run == null) return;
    final json = jsonEncode([for (final m in r.marks) m.toJson()]);
    _write(
      () => _store.update(run.id, LocalRunsCompanion(lapsJson: Value(json))),
    );
  }

  /// The runner's "Next step" in a session.
  void nextStep() {
    final run = state;
    final r = _runner;
    if (run == null || r == null || r.done) return;
    final now = _now();
    final i = r.skip(
      distanceM: run.track.distanceM,
      activeSeconds: _activeSecondsAt(now),
      clockT: clockSecondsOf(run.startedAt, now),
    );
    _persistLaps();
    if (i != null) {
      _say(
        _coach!.step(
          r.steps[i],
          afterRest: r.steps[i - 1].kind == StepKind.recover,
        ),
      );
    } else {
      _say(_coach!.workoutDone());
    }
    state = run.copyWith(
      session: _sessionNow(run.track.distanceM, _activeSecondsAt(now)),
    );
  }

  LiveTrack _newTrack() => LiveTrack(
        weightKg:
            ref.read(profileControllerProvider).value?.profile.latestWeightKg,
        splitUnitM: ref.read(runSettingsProvider).unit.metres,
      );

  void _startSensors(DateTime startedAt) {
    final run = state!;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    if (run.kind == RunKind.outdoor) {
      _filter = GpsFilter(startedAt: startedAt);
      _sub = ref.read(locationSourceProvider).fixes().listen(_onFix);
    }
  }

  void _stopSensors() {
    _ticker?.cancel();
    _ticker = null;
    unawaited(_sub?.cancel());
    _sub = null;
  }

  /* ---------------------------------------------------------- the run -- */

  int _activeSecondsAt(DateTime now) {
    final running =
        _resumedAt == null ? 0 : now.difference(_resumedAt!).inMilliseconds;
    return (_activeMs + (running < 0 ? 0 : running)) ~/ 1000;
  }

  void _tick() {
    final run = state;
    if (run == null) return;
    final now = _now();
    var gps = run.gps;
    if (run.kind == RunKind.outdoor &&
        _lastFixAt != null &&
        now.difference(_lastFixAt!) > const Duration(seconds: 10)) {
      gps = GpsSignal.lost;
    }
    state = run.copyWith(activeSeconds: _activeSecondsAt(now), gps: gps);
    if (state!.isRunning) _guide(state!, now);
    state = state!.copyWith(
      session: _sessionNow(state!.track.distanceM, state!.activeSeconds),
    );
    if (state!.activeSeconds - _lastNotified >= 10) unawaited(_notify());
  }

  void _onFix(GpsFix fix) {
    final run = state;
    final filter = _filter;
    if (run == null || filter == null || run.status == RunStatus.finished) {
      return;
    }
    _lastFixAt = _now();
    final gps = fix.accuracyM <= 10 ? GpsSignal.good : GpsSignal.weak;
    final result = filter.add(fix);

    // Auto-pause: only while moving or auto-paused (a runner's pause is theirs).
    // Beta 4.1: never in a session — a standing rest is part of it.
    if (ref.read(runSettingsProvider).autoPause &&
        _runner == null &&
        run.status != RunStatus.paused &&
        _auto.add(fix.at, result.speedMs)) {
      if (_auto.paused) {
        _pauseAt(_now(), RunStatus.autoPaused);
      } else {
        _resumeAt(_now());
      }
    }

    final point = result.point;
    if (point != null && state!.status == RunStatus.recording) {
      final seg = _segment;
      final seq = _seq++;
      final fresh = _newSegment;
      _newSegment = false;
      state!.track.add(point, newSegment: fresh);
      _write(() => _store.addPoints(run.id, seq, seg, [point]));
    }
    state = state!.copyWith(
      gps: gps,
      activeSeconds: _activeSecondsAt(_now()),
    );
  }

  /// Serialises the database writes of one run, in order.
  void _write(Future<void> Function() write) {
    _writes = _writes.then((_) => write()).catchError((Object _) {});
  }

  void _pauseAt(DateTime now, RunStatus status) {
    final run = state;
    if (run == null || run.status != RunStatus.recording) {
      if (run != null && run.isPaused && status != run.status) {
        state = run.copyWith(status: status);
      }
      return;
    }
    _activeMs += now.difference(_resumedAt!).inMilliseconds;
    _resumedAt = null;
    _segment++;
    _newSegment = true;
    _filter?.newSegment();
    state = run.copyWith(status: status, activeSeconds: _activeSecondsAt(now));
    _persist(status);
    unawaited(_notify());
  }

  void _resumeAt(DateTime now) {
    final run = state;
    if (run == null || !run.isPaused) return;
    _resumedAt = now;
    _auto.reset();
    state = run.copyWith(status: RunStatus.recording, restored: false);
    _persist(RunStatus.recording);
    unawaited(_notify());
  }

  void _persist(RunStatus status, {DateTime? endedAt}) {
    final run = state;
    if (run == null) return;
    final now = _now().toUtc().toIso8601String();
    _write(
      () => _store.update(
        run.id,
        LocalRunsCompanion(
          status: Value(status.name),
          activeMs: Value(_activeMs),
          resumedAt: Value(_resumedAt?.toUtc().toIso8601String()),
          segment: Value(_segment),
          endedAt: endedAt == null
              ? const Value.absent()
              : Value(endedAt.toUtc().toIso8601String()),
          updatedAt: Value(now),
        ),
      ),
    );
  }

  /// The runner's pause.
  void pause() {
    final wasRunning = state?.isRunning ?? false;
    _pauseAt(_now(), RunStatus.paused);
    if (wasRunning) _say(_coach?.paused());
  }

  void resume() {
    if (state?.kind == RunKind.outdoor && _sub == null) {
      // After a restore the sensors are off until the runner resumes.
      _filter = GpsFilter(startedAt: state!.startedAt);
      _sub = ref.read(locationSourceProvider).fixes().listen(_onFix);
    }
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    final wasPaused = state?.isPaused ?? false;
    _resumeAt(_now());
    if (wasPaused) _say(_coach?.resumed());
  }

  /// Stops the run; it waits for Save or Discard on the summary.
  Future<void> finish() async {
    final run = state;
    if (run == null || run.status == RunStatus.finished) return;
    final now = _now();
    if (_resumedAt != null) {
      _activeMs += now.difference(_resumedAt!).inMilliseconds;
      _resumedAt = null;
    }
    _stopSensors();
    if (_runner != null && !_runner!.done) {
      _runner!.finish(clockSecondsOf(run.startedAt, now));
      _persistLaps();
    }
    state = run.copyWith(
      status: RunStatus.finished,
      activeSeconds: _activeSecondsAt(now),
    );
    _persist(RunStatus.finished, endedAt: now);
    await _writes;
  }

  /// Throws the run away: nothing is kept.
  Future<void> discard() async {
    final run = state;
    if (run == null) return;
    _stopSensors();
    _runner = null;
    _coach = null;
    state = null;
    await _writes;
    await _store.delete(run.id);
  }

  /// Saves the finished run (queued for the server) and clears the recorder.
  Future<String?> save({
    required String name,
    String? note,
    int? effort,
    double? treadmillDistanceM,
  }) async {
    final run = state;
    if (run == null) return null;
    if (run.status != RunStatus.finished) await finish();
    await _writes;
    await ref.read(runningRepositoryProvider).save(
          run.id,
          name: name,
          note: note,
          effort: effort,
          treadmillDistanceM: treadmillDistanceM,
        );
    _runner = null;
    _coach = null;
    state = null;
    return run.id;
  }

  /// Waits for every point and state change to reach the database (tests).
  Future<void> flush() => _writes;

  /// One second of the run, now (tests drive the clock themselves).
  @visibleForTesting
  void tick() => _tick();

  /* ------------------------------------------------------ notification -- */

  Future<void> _notify() async {
    final run = state;
    if (run == null || run.kind != RunKind.outdoor) return;
    _lastNotified = run.activeSeconds;
    final unit = ref.read(runSettingsProvider).unit;
    final distance =
        '${formatDistance(run.track.distanceM, unit)} ${unit.label}';
    final pace = '${formatPace(run.avgPaceSecPerKm, unit)} ${unit.paceLabel}';
    if (run.status == RunStatus.finished) return;
    await ref.read(runNotificationProvider).show(
          title: run.isRunning ? 'Run in progress' : 'Run paused',
          body: run.isRunning
              ? '$distance · avg $pace'
              : '${formatDuration(run.activeSeconds)} · $distance',
          runningSince: run.isRunning
              ? _now().subtract(Duration(seconds: run.activeSeconds))
              : null,
        );
  }

  /* ----------------------------------------------------------- restore -- */

  Future<void> _restore() async {
    LocalRun? row;
    try {
      row = await _store.current();
    } on Object {
      return;
    }
    if (row == null || !ref.mounted || state != null) return;
    final kind = RunKind.parse(row.kind);
    final stored = await _store.track(row.clientRunId);
    final startedAt = DateTime.parse(row.startedAt);
    final live = _newTrack();
    for (final seg in stored.segments) {
      for (var i = 0; i < seg.length; i++) {
        live.add(seg[i], newSegment: i == 0);
      }
    }
    _seq = await _store.pointCount(row.clientRunId);
    _segment = row.segment;
    _activeMs = row.activeMs;
    var status = RunStatus.values.byName(row.status);
    if (status == RunStatus.recording || status == RunStatus.autoPaused) {
      // FITOS was closed while recording: count the time up to the last
      // point, and wait paused for the runner.
      if (status == RunStatus.recording && row.resumedAt != null) {
        final resumed = DateTime.parse(row.resumedAt!);
        final last = stored.isEmpty
            ? resumed
            : startedAt.add(
                Duration(
                  milliseconds: (stored.segments.last.last.t * 1000).round(),
                ),
              );
        final ms = last.difference(resumed).inMilliseconds;
        if (ms > 0) _activeMs += ms;
      }
      status = RunStatus.paused;
      _segment++;
    }
    _resumedAt = null;
    _newSegment = true;
    _coach = _newCoach();
    _runner = null;
    if (row.workoutJson != null) {
      _runner = WorkoutRunner(
        RunWorkout.fromJson(
          jsonDecode(row.workoutJson!) as Map<String, dynamic>,
        ),
      )..restore(
          row.lapsJson == null
              ? const []
              : [
                  for (final m in jsonDecode(row.lapsJson!) as List)
                    LapMark.fromJson(m as Map<String, dynamic>),
                ],
          distanceM: live.distanceM,
          activeSeconds: _activeMs ~/ 1000,
          clockT: stored.isEmpty ? 0 : stored.segments.last.last.t,
        );
    }
    if (!ref.mounted) return;
    state = LiveRun(
      id: row.clientRunId,
      kind: kind,
      goal: RunGoal(RunGoalKind.parse(row.goalKind), row.goalValue),
      status: status,
      startedAt: startedAt,
      activeSeconds: _activeMs ~/ 1000,
      track: live,
      gps: GpsSignal.searching,
      restored: status != RunStatus.finished,
      session: _sessionNow(live.distanceM, _activeMs ~/ 1000),
    );
    if (status == RunStatus.paused) _persist(status);
  }
}

final runRecorderProvider =
    NotifierProvider<RunRecorder, LiveRun?>(RunRecorder.new);

/// Points in the run being recorded, for the map (the same lists).
List<List<TrackPoint>> livePolyline(LiveRun run) => run.track.segments;
